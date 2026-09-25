//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;
const Growth = Common.GrowthModel;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

pub const FieldMode = enum {
    WHOLE_STRUCTS,
    SPLIT_FIELDS,
};

pub const LayoutMode = enum {
    SERIAL_INDEXES,
    SERIAL_INDEXES_WITH_OFFSET,
};

const AllocMode = enum {
    ASSUME_CAP,
    REALLOC,
};

const GrowthMode = enum {
    DEFAULT_GROWTH,
    CUSTOM_GROWTH,
};

const MoveOneDisplaceMode = enum {
    PRESERVE_VAL,
    IGNORE_VAL,
};

const DeleteMode = enum {
    ORDERED,
    SWAP,
};

const DeleteReturnMode = enum {
    RETURN_VAL,
    IGNORE_VAL,
};

const ReturnMode = enum {
    RETURN_PTR,
    RETURN_PTR_IDX,
    RETURN_IDX,
    RETURN_VOID,

    pub fn returns_ptr(comptime self: ReturnMode) bool {
        return switch (comptime self) {
            .RETURN_PTR, .RETURN_PTR_IDX => true,
            else => false,
        };
    }

    pub fn RetType(comptime self: ReturnMode, comptime PTR: type, comptime IDX: type) type {
        return switch (comptime self) {
            .RETURN_PTR => PTR,
            .RETURN_PTR_IDX => struct { PTR, IDX },
            .RETURN_IDX => IDX,
            .RETURN_VOID => void,
        };
    }
    pub fn ret_val(comptime self: ReturnMode, comptime PTR: type, comptime IDX: type, ptr: PTR, idx: IDX) self.RetType(PTR, IDX) {
        return switch (comptime self) {
            .RETURN_PTR => ptr,
            .RETURN_PTR_IDX => .{ ptr, idx },
            .RETURN_IDX => idx,
            .RETURN_VOID => void{},
        };
    }
};

pub fn List(comptime T: type, comptime FIELD_LAYOUT: FieldMode, comptime INDEX_LAYOUT: LayoutMode) type {
    return ListCustomIdx(T, FIELD_LAYOUT, INDEX_LAYOUT, u32);
}

pub fn ListCustomIdx(comptime T: type, comptime FIELD_LAYOUT: FieldMode, comptime INDEX_LAYOUT: LayoutMode, comptime IDX: type) type {
    assert_with_reason(Type.type_is_unsigned_int(IDX), @src(), "IDX type must be an unsigned integer, got type `{s}`", .{@typeName(IDX)});
    const _NUM_FIELDS: usize = switch (@typeInfo(T)) {
        .@"struct" => |s| s.fields.len,
        else => 1,
    };
    const _NUM_BITS_FOR_FIELDS: usize = get: {
        const invertd_num_fields = ~_NUM_FIELDS;
        break :get @ctz(invertd_num_fields);
    };
    const _E_INT = std.meta.Int(.unsigned, @intCast(_NUM_BITS_FOR_FIELDS));
    const _PROTO = struct {
        fn order_by_align(a: type, b: type) bool {
            return @alignOf(a) < @alignOf(b);
        }
    };
    const _ORDERED_FIELD_NAMES, const _ORDERED_FIELD_TYPES, const _ORDERED_FIELD_OFFETS, const _FIELD_ENUM = get: {
        switch (@typeInfo(T)) {
            .@"struct" => {
                var info = Type.extract_struct_info(T);
                Root.Sort.InsertionSort.insertion_sort_with_func_and_matching_buffers(info.field_types[0..], &.{ info.field_names[0..], info.field_attrs[0..] }, _PROTO.order_by_align);
                var e_val: [_NUM_FIELDS]_E_INT = undefined;
                var off: [_NUM_FIELDS + 1]IDX = undefined;
                var off_total: IDX = 0;
                inline for (info.field_types[0..], 0..) |t, i| {
                    e_val[i] = @intCast(i);
                    off[i] = off_total;
                    off_total += @sizeOf(t);
                }
                off[_NUM_FIELDS] = off_total;
                break :get .{ info.field_names, info.field_types, off, @Enum(_E_INT, .exhaustive, info.names[0..], e_val[0..]) };
            },
            .@"union" => {
                const info = Type.extract_union_info(T);
                var off: [_NUM_FIELDS + 1]IDX = @splat(0);
                off[_NUM_FIELDS] = @sizeOf(T);
                break :get .{ info.field_names, info.field_types, off, info.tag_type.? };
            },
            else => break :get .{ [0][]const u8, [0]Type{}, [0]IDX{}, @Enum(u0, .exhaustive, &.{}, &.{}) },
        }
    };
    // const _Y = _FIELD_INFO.
    return struct {
        const Self = @This();
        const NUM_FIELDS = _NUM_FIELDS;
        const ORDERED_FIELD_NAMES = _ORDERED_FIELD_NAMES;
        const ORDERED_FIELD_TYPES = _ORDERED_FIELD_TYPES;
        const ORDERED_FIELD_OFFETS = _ORDERED_FIELD_OFFETS;
        const SPLIT = FIELD_LAYOUT == .SPLIT_FIELDS;
        const IS_STRUCT = Type.type_is_struct(T);
        const IS_UNION = Type.type_is_union(T);
        const MAX_ALIGN = @alignOf(T);
        const SERIAL_IDXS = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => true,
            else => false,
        };
        const IDX_OFFSET = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES => false,
            .SERIAL_INDEXES_WITH_OFFSET => true,
        };
        const ENUM_INT = _E_INT;
        pub const Field = _FIELD_ENUM;
        const MemPtr = if (SPLIT) [*]align(MAX_ALIGN) u8 else [*]T;
        const ElemPtr = if (SPLIT) build: {
            if (IS_STRUCT) {
                const old_info = Type.extract_struct_info(T);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{}, old_t, null);
                    new_attr.* = .{};
                }
                const PtrStruct = new_info.build_struct_type();
                break :build PtrStruct;
            } else if (IS_UNION) {
                const old_info = Type.extract_union_info(T);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{}, old_t, null);
                    new_attr.* = .{};
                }
                const UnionStruct = new_info.build_union_type();
                break :build UnionStruct;
            } else {
                break :build *T;
            }
        } else *T;
        const ElemPtrConst = if (SPLIT) build: {
            if (IS_STRUCT) {
                const old_info = Type.extract_struct_info(T);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{ .@"const" = true }, old_t, null);
                    new_attr.* = .{};
                }
                const PtrStruct = new_info.build_struct_type();
                break :build PtrStruct;
            } else if (IS_UNION) {
                const old_info = Type.extract_union_info(T);
                var new_info = old_info;
                for (old_info.field_types[0..], new_info.field_types[0..], new_info.field_attrs[0..]) |old_t, *new_t, *new_attr| {
                    new_t.* = @Pointer(.one, .{ .@"const" = true }, old_t, null);
                    new_attr.* = .{};
                }
                const UnionStruct = new_info.build_union_type();
                break :build UnionStruct;
            } else {
                break :build *const T;
            }
        } else *const T;

        ptr: MemPtr = undefined,
        len: IDX = 0,
        cap: IDX = 0,
        start_offset: IDX = 0,
        owns_memory: bool = true,

        fn assert_valid_idx(self: Self, idx: IDX, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(idx < self.len, src, "index `{d}` is out of bounds", .{idx});
        }
        fn assert_whole_struct_for_ptr(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get whole struct pointer in .SPLIT_FIELDS mode", .{});
        }
        fn assert_whole_struct_for_slice(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get normal slice in .SPLIT_FIELDS mode", .{});
        }
        fn assert_start_less_end_exclusive(start: IDX, end_excl: IDX, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start < end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_start_less_or_equal_end_exclusive(start: IDX, end_excl: IDX, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start <= end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_serial_indexes(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(SERIAL_IDXS, src, "indexes must be serially in order at this point", .{});
        }

        inline fn end_stride() IDX {
            return ORDERED_FIELD_OFFETS[NUM_FIELDS];
        }
        inline fn field_begin_stride(comptime field: Field) IDX {
            return ORDERED_FIELD_OFFETS[@intFromEnum(field)];
        }
        inline fn field_begin_stride_fidx(comptime fidx: usize) IDX {
            return ORDERED_FIELD_OFFETS[fidx];
        }
        inline fn FieldType(comptime field: Field) type {
            return ORDERED_FIELD_TYPES[@intFromEnum(field)];
        }
        inline fn FieldTypeFidx(comptime fidx: usize) type {
            return ORDERED_FIELD_TYPES[fidx];
        }

        inline fn true_idx(self: Self, idx: IDX) IDX {
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => return idx,
                .SERIAL_INDEXES_WITH_OFFSET => return idx + self.start_offset,
            }
        }
        fn assign_val_to_elem_ptr(elem_ptr: ElemPtr, val: T) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    elem_ptr.* = val;
                    return elem_ptr;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_NAMES[0..]) |fname| {
                        @field(elem_ptr, fname).* = @field(val, fname);
                    }
                    return elem_ptr;
                },
            }
        }
        fn set_true_idx(self: Self, idx: IDX, val: T) void {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.ptr[idx] = val;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_NAMES[0..], ORDERED_FIELD_OFFETS[0.._NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |name, offset, t| {
                        const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                        const ptr_opq = self.ptr + full_off;
                        const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                        ptr.* = @field(val, name);
                    }
                },
            }
        }
        pub fn set(self: Self, idx: IDX, val: T) void {
            self.assert_valid_idx(idx, @src());
            self.set_true_idx(self.true_idx(idx), val);
        }
        fn set_field_internal(self: Self, comptime field: Field, idx: IDX, val: FieldType(field)) void {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    @field(&self.ptr[idx], @tagName(field)) = val;
                },
                .SPLIT_FIELDS => {
                    const name = @tagName(field);
                    const offset = field_begin_stride(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    ptr.* = @field(val, name);
                },
            }
        }
        pub fn set_field(self: Self, comptime field: Field, idx: IDX, val: FieldType(field)) void {
            self.assert_valid_idx(idx, @src());
            self.set_field_internal(field, self.true_idx(idx), val);
        }
        fn get_true_idx(self: Self, idx: IDX) T {
            self.assert_valid_idx(idx, @src());
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return self.ptr[idx];
                },
                .SPLIT_FIELDS => {
                    var val: T = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..], ORDERED_FIELD_OFFETS[0.._NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |name, offset, t| {
                        const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                        const ptr_opq = self.ptr + full_off;
                        const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                        @field(val, name) = ptr.*;
                    }
                },
            }
        }
        pub fn get(self: Self, idx: IDX) T {
            self.assert_valid_idx(idx, @src());
            return self.get_true_idx(self.true_idx(idx));
        }
        fn get_ptr_true_idx(self: Self, idx: IDX) ElemPtr {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return &self.ptr[idx];
                },
                .SPLIT_FIELDS => {
                    var ptr_container: ElemPtr = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..NUM_FIELDS], 0..) |f_name, fidx| {
                        @field(ptr_container, f_name) = self.get_field_ptr_true_idx(@enumFromInt(fidx), idx);
                    }
                    return ptr_container;
                },
            }
        }
        pub fn get_ptr(self: Self, idx: IDX) *T {
            self.assert_valid_idx(idx, @src());
            return self.get_ptr_true_idx(self.true_idx(idx));
        }
        fn get_ptr_const_internal(self: Self, idx: IDX) ElemPtrConst {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return &self.ptr[idx];
                },
                .SPLIT_FIELDS => {
                    var ptr_container: ElemPtrConst = undefined;
                    inline for (ORDERED_FIELD_NAMES[0..NUM_FIELDS], 0..) |f_name, fidx| {
                        @field(ptr_container, f_name) = self.get_field_ptr_const_true_idx(@enumFromInt(fidx), idx);
                    }
                    return ptr_container;
                },
            }
        }
        pub fn get_ptr_const(self: Self, idx: IDX) *const T {
            self.assert_valid_idx(idx, @src());
            return self.get_ptr_const_internal(self.true_idx(idx));
        }
        fn get_field_true_idx(self: Self, comptime field: Field, idx: IDX) FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_begin_stride(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    return ptr.*;
                },
            }
        }
        pub fn get_field(self: Self, comptime field: Field, idx: IDX) FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field(field, self.true_idx(idx));
        }
        fn get_field_ptr_true_idx(self: Self, comptime field: Field, idx: IDX) *FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_begin_stride(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    return ptr;
                },
            }
        }
        pub fn get_field_ptr(self: Self, comptime field: Field, idx: IDX) *FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_ptr_true_idx(field, self.true_idx(idx));
        }
        fn get_field_ptr_const_true_idx(self: Self, comptime field: Field, idx: IDX) *const FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_begin_stride(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *const t = @ptrCast(@alignCast(ptr_opq));
                    return ptr;
                },
            }
        }
        pub fn get_field_ptr_const(self: Self, comptime field: Field, idx: IDX) *const FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_ptr_const_true_idx(field, self.true_idx(idx));
        }
        pub fn get_len(self: Self) IDX {
            return self.len;
        }
        pub fn set_len(self: *Self, new_len: IDX) void {
            self.len = new_len;
            assert_with_reason(self.len <= self.cap, @src(), "set len greater than cap ({d} > {d})", .{ self.len, self.cap });
        }
        pub fn incr_len(self: *Self, count: IDX) void {
            self.len += count;
            assert_with_reason(self.len <= self.cap, @src(), "set len greater than cap ({d} > {d})", .{ self.len, self.cap });
        }
        pub fn set_len_unchecked(self: *Self, new_len: IDX) void {
            self.len = new_len;
        }
        pub fn incr_len_unchecked(self: *Self, count: IDX) void {
            self.len += count;
        }
        pub fn set_len_clamped(self: *Self, new_len: IDX) void {
            self.len = @min(new_len, self.cap);
        }
        pub fn incr_len_clamped(self: *Self, count: IDX) void {
            self.len +|= count;
            self.len = @min(self.len, self.cap);
        }
        pub fn decr_len(self: *Self, count: IDX) void {
            self.len -= count;
        }
        pub fn decr_len_clamped(self: *Self, count: IDX) void {
            self.len -|= count;
        }
        pub fn get_cap(self: Self) IDX {
            return self.cap;
        }
        pub fn set_cap_no_alloc(self: *Self, new_cap: IDX) void {
            self.cap = new_cap;
            self.len = @min(self.len, self.cap);
        }
        pub fn incr_cap_no_alloc(self: *Self, count: IDX) void {
            self.cap += count;
        }
        pub fn incr_cap_no_alloc_clamped(self: *Self, count: IDX) void {
            self.cap +|= count;
        }
        pub fn decr_cap_no_alloc(self: *Self, count: IDX) void {
            self.cap -= count;
            self.len = @min(self.len, self.cap);
        }
        pub fn decr_cap_no_alloc_clamped(self: *Self, count: IDX) void {
            self.cap -|= count;
            self.len = @min(self.len, self.cap);
        }
        // TODO implement slicing
        // pub fn slice(self: Self, start: IDX, end_exclusive: IDX) Self {
        //     assert_whole_struct_for_slice(@src());
        //     return Self{
        //         .ptr = self.ptr + start,
        //         .len = end_exclusive - start,
        //         .cap = end_exclusive - start,
        //     };
        // }
        fn reverse_range_internal(self: Self, start: IDX, end_exclusive: IDX) void {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => {
                            std.mem.reverse(T, self.ptr[start..end_exclusive]);
                        },
                        .SERIAL_INDEXES_WITH_OFFSET => {
                            std.mem.reverse(T, (self.ptr + self.start_offset)[start..end_exclusive]);
                        },
                        else => unreachable,
                    }
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0.._NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const field_ptr: [*]t = @ptrCast(self.ptr + (self.cap * offset));
                        switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => {
                                std.mem.reverse(T, field_ptr[start..end_exclusive]);
                            },
                            .SERIAL_INDEXES_WITH_OFFSET => {
                                std.mem.reverse(T, (field_ptr + self.start_offset)[start..end_exclusive]);
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        }
        pub fn reverse_range(self: Self, start: IDX, end_exclusive: IDX) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.reverse_range_internal(start, end_exclusive);
        }
        fn reverse_range_field_idx(self: Self, comptime fidx: usize, start: IDX, end_exclusive: IDX) void {
            const offset = ORDERED_FIELD_OFFETS[fidx];
            const t = ORDERED_FIELD_TYPES[fidx];
            const field_ptr: [*]t = @ptrCast(self.ptr + (self.cap * offset));
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => {
                    std.mem.reverse(T, field_ptr[start..end_exclusive]);
                },
                .SERIAL_INDEXES_WITH_OFFSET => {
                    std.mem.reverse(T, (field_ptr + self.start_offset)[start..end_exclusive]);
                },
                else => unreachable,
            }
        }
        pub fn reverse(self: Self) void {
            self.reverse_range(0, self.len);
        }
        fn rotate_range_internal(self: Self, start: IDX, end_exclusive: IDX, delta: i64) void {
            const len: i64 = end_exclusive - start;
            const shift: IDX = @intCast(@mod(delta, len));
            self.rotate_range_right_internal(start, end_exclusive, shift);
        }
        pub fn rotate_range(self: Self, start: IDX, end_exclusive: IDX, delta: i64) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.rotate_range_internal(start, end_exclusive, delta);
        }
        pub fn rotate(self: Self, delta: i64) void {
            return self.rotate_range(0, self.len, delta);
        }
        fn rotate_range_right_internal(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_left_displace_internal(end_exclusive - 1, start);
                return;
            }
            if (shift == len - 1) {
                self.move_one_right_displace_internal(start, end_exclusive - 1);
                return;
            }
            const boundary = end_exclusive - shift;
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.reverse_range_internal(start, boundary);
                    self.reverse_range_internal(boundary, end_exclusive);
                    self.reverse_range_internal(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |FIDX| {
                        self.reverse_range_field_idx(FIDX, start, boundary);
                        self.reverse_range_field_idx(FIDX, boundary, end_exclusive);
                        self.reverse_range_field_idx(FIDX, start, end_exclusive);
                    }
                },
            }
        }
        pub fn rotate_range_right(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            return self.rotate_range_right_internal(start, end_exclusive, count);
        }
        pub fn rotate_right(self: Self, count: IDX) void {
            self.rotate_range_right(0, self.len, count);
        }
        fn rotate_range_left_internal(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_right_displace(start, end_exclusive - 1);
                return;
            }
            if (shift == len - 1) {
                self.move_one_left_displace(end_exclusive - 1, start);
                return;
            }
            const boundary = start + shift;
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.reverse_range_internal(start, boundary);
                    self.reverse_range_internal(boundary, end_exclusive);
                    self.reverse_range_internal(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    inline for (0..NUM_FIELDS) |FIDX| {
                        self.reverse_range_field_idx(FIDX, start, boundary);
                        self.reverse_range_field_idx(FIDX, boundary, end_exclusive);
                        self.reverse_range_field_idx(FIDX, start, end_exclusive);
                    }
                },
            }
        }
        pub fn rotate_range_left(self: Self, start: IDX, end_exclusive: IDX, count: IDX) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            return self.rotate_range_left_internal(start, end_exclusive, count);
        }
        pub fn rotate_left(self: Self, count: IDX) void {
            self.rotate_range_left(0, self.len, count);
        }
        pub fn move_block_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            if (old_start < new_start) {
                self.move_block_right_displace(old_start, old_end_exclusive, new_start);
            } else {
                self.move_block_left_displace(old_start, old_end_exclusive, new_start);
            }
        }
        pub fn move_block_right_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start < new_start, @src(), "old start must be <= new_start to move block right, got {d} > {d}", .{ old_start, new_start });
            const block_len = old_end_exclusive - old_start;
            const new_end_exclusive = new_start + block_len;
            assert_with_reason(new_end_exclusive <= self.len, @src(), "end of block will exceed list length, len = {d}, new_end_exclusive = {d}", .{ self.len, new_end_exclusive });
            self.rotate_range_left_internal(old_start, new_end_exclusive, block_len);
        }
        pub fn move_block_left_displace(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start > new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            const block_len = old_end_exclusive - old_start;
            self.rotate_range_right_internal(new_start, old_end_exclusive, block_len);
        }
        fn move_block_overwrite_internal(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            const len = old_end_exclusive - old_start;
            const new_end_exclusive = new_start + len;
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                    switch (comptime FIELD_LAYOUT) {
                        .WHOLE_STRUCTS => {
                            @memmove(self.ptr[self.true_idx(new_start)..self.true_idx(new_end_exclusive)], self.ptr[self.true_idx(old_start)..self.true_idx(old_end_exclusive)]);
                        },
                        .SPLIT_FIELDS => {
                            const t_old_start = self.true_idx(old_start);
                            const t_old_end_exclusive = self.true_idx(old_end_exclusive);
                            const t_new_start = self.true_idx(new_start);
                            const t_new_end_exclusive = self.true_idx(new_end_exclusive);
                            inline for (ORDERED_FIELD_OFFETS[0..NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                                const field_ptr: [*]t = @ptrCast(@alignCast(self.ptr + (offset * self.cap)));
                                @memmove(field_ptr[t_new_start..t_new_end_exclusive], field_ptr[t_old_start..t_old_end_exclusive]);
                            }
                        },
                    }
                },
            }
        }
        pub fn move_block_right_overwrite(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start < new_start, @src(), "old start must be <= new_start to move block right, got {d} > {d}", .{ old_start, new_start });
            self.move_block_overwrite_internal(old_start, old_end_exclusive, new_start);
        }
        pub fn move_block_left_overwrite(self: Self, old_start: IDX, old_end_exclusive: IDX, new_start: IDX) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start > new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            self.move_block_overwrite_internal(old_start, old_end_exclusive, new_start);
        }

        pub fn move_one_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            if (old_idx < new_idx) {
                self.move_one_right_displace(old_idx, new_idx);
            } else {
                self.move_one_left_displace(old_idx, new_idx);
            }
        }
        fn move_one_right_displace_internal(
            self: Self,
            old_idx: IDX,
            new_idx: IDX,
        ) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    const offset_ptr = switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => self.ptr,
                        .SERIAL_INDEXES_WITH_OFFSET => self.ptr + self.start_offset,
                    };
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                            const temp = self.ptr[old_idx];
                            @memmove(offset_ptr[old_idx..new_idx], offset_ptr[(old_idx + 1)..(new_idx + 1)]);
                            offset_ptr[new_idx] = temp;
                        },
                        else => unreachable,
                    }
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0..], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const raw_offset = (self.cap * offset);
                        const field_ptr: [*]t = switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => @ptrCast(@alignCast(self.ptr + raw_offset)),
                            .SERIAL_INDEXES_WITH_OFFSET => @as([*]t, @ptrCast(@alignCast(self.ptr + raw_offset))) + self.start_offset,
                        };
                        const temp = field_ptr[old_idx];
                        @memmove(field_ptr[old_idx..new_idx], field_ptr[(old_idx + 1)..(new_idx + 1)]);
                        field_ptr[new_idx] = temp;
                    }
                },
            }
        }
        pub fn move_one_right_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx < new_idx, @src(), "old_idx must be <= new_idx, got {d} > {d}", .{ old_idx, new_idx });
            self.move_one_right_displace_internal(old_idx, new_idx);
        }
        fn move_one_left_displace_internal(self: Self, old_idx: IDX, new_idx: IDX) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    const offset_ptr = switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES => self.ptr,
                        .SERIAL_INDEXES_WITH_OFFSET => self.ptr + self.start_offset,
                    };
                    switch (comptime INDEX_LAYOUT) {
                        .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                            const temp = self.ptr[old_idx];
                            @memmove(offset_ptr[(old_idx + 1)..(new_idx + 1)], offset_ptr[old_idx..new_idx]);
                            offset_ptr[new_idx] = temp;
                        },
                        else => unreachable,
                    }
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0..], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const raw_offset = (self.cap * offset);
                        const field_ptr: [*]t = switch (comptime INDEX_LAYOUT) {
                            .SERIAL_INDEXES => @ptrCast(@alignCast(self.ptr + raw_offset)),
                            .SERIAL_INDEXES_WITH_OFFSET => @as([*]t, @ptrCast(@alignCast(self.ptr + raw_offset))) + self.start_offset,
                        };
                        const temp = field_ptr[old_idx];
                        @memmove(field_ptr[(old_idx + 1)..(new_idx + 1)], field_ptr[old_idx..new_idx]);
                        field_ptr[new_idx] = temp;
                    }
                },
            }
        }
        pub fn move_one_left_displace(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx > new_idx, @src(), "old_idx must be >= new_idx, got {d} < {d}", .{ old_idx, new_idx });
            self.move_one_left_displace_internal(old_idx, new_idx);
        }
        fn move_one_overwrite_true_idx(self: Self, old_idx: IDX, new_idx: IDX) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    self.ptr[new_idx] = self.ptr[old_idx];
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0..NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const field_ptr: [*]t = @ptrCast(self.ptr + (self.cap * offset));
                        field_ptr[new_idx] = field_ptr[old_idx];
                    }
                },
            }
        }
        fn move_one_overwrite(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            self.move_one_overwrite_true_idx(self.true_idx(old_idx), self.true_idx(new_idx));
        }
        fn swap_true_idx(self: Self, idx_a: IDX, idx_b: IDX) void {
            const tmp = self.ptr[idx_a];
            self.ptr[idx_a] = self.ptr[idx_b];
            self.ptr[idx_b] = tmp;
        }
        fn swap(self: Self, idx_a: IDX, idx_b: IDX) void {
            self.assert_valid_idx(idx_a, @src());
            self.assert_valid_idx(idx_b, @src());
            self.swap_true_idx(self.true_idx(idx_a), self.true_idx(idx_b));
        }
        fn scramble_range_internal(self: Self, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            const len = end_exclusive - start;
            if (len <= 1) return;
            if (len == 2) {
                if (rand.boolean()) {
                    self.swap_true_idx(self.true_idx(start), self.true_idx(end_exclusive));
                }
                return;
            }
            var n: IDX = 0;
            const first_idx = rand.intRangeLessThan(IDX, start, end_exclusive);
            var empty_idx: IDX = first_idx;
            var empty_true_idx: IDX = self.true_idx(first_idx);
            const first_val = self.get_true_idx(empty_true_idx);
            while (n < iterations) : (n += 1) {
                const move_idx = find_different_idx: {
                    while (true) {
                        const possible_different_idx = rand.intRangeLessThan(IDX, start, end_exclusive);
                        if (possible_different_idx != empty_idx) break :find_different_idx possible_different_idx;
                    }
                };
                const move_true_idx = self.true_idx(move_idx);
                self.move_one_overwrite_true_idx(move_true_idx, empty_true_idx);
                empty_idx = move_idx;
                empty_true_idx = move_true_idx;
            }
            self.set_true_idx(empty_true_idx, first_val);
        }
        pub fn scramble_range(self: Self, start: IDX, end_exclusive: IDX, iterations: IDX, rand: Random) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (iterations == 0 or start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.scramble_range_internal(start, end_exclusive, iterations, rand);
        }
        pub fn scramble(self: Self, iterations: IDX, rand: Random) void {
            self.scramble_range(0, self.len, iterations, rand);
        }
        fn realloc_internal(self: *Self, new_exact_cap: IDX, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot realloc non-owned memory", .{});
            self.len = @min(self.len, new_exact_cap);
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    if (self.len > 0) {
                        if (alloc.remap(self.ptr[0..self.cap], new_exact_cap)) |new_mem| {
                            self.ptr = new_mem.ptr;
                            self.cap = @intCast(new_mem.len);
                            return;
                        }
                    }
                    const new_mem = alloc.alloc(T, new_exact_cap) catch |e| assert_unreachable_err(@src(), e);
                    @memcpy(new_mem, self.ptr[0..self.len]);
                    alloc.free(self.ptr[0..self.cap]);
                    self.ptr = new_mem.ptr;
                    self.cap = @intCast(new_mem.len);
                },
                .SPLIT_FIELDS => {
                    const old_byte_cap = end_stride() * self.cap;
                    const new_byte_cap = end_stride() * new_exact_cap;
                    // remap would require doing a @memmove on each field region to correctly reposition them,
                    // so might as well just alloc and go for the potentially faster @memcpy
                    const new_mem = alloc.alloc(T, new_byte_cap) catch |e| assert_unreachable_err(@src(), e);
                    inline for (ORDERED_FIELD_OFFETS[0..NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const field_start_offset_old = offset * self.cap;
                        const field_start_offset_new = offset * new_exact_cap;
                        const field_ptr_old: [*]t = @ptrCast(@alignCast(self.ptr + field_start_offset_old));
                        const field_ptr_new: [*]t = @ptrCast(@alignCast(new_mem.ptr + field_start_offset_new));
                        @memcpy(field_ptr_new[0..self.len], field_ptr_old[0..self.len]);
                    }
                    alloc.free(self.ptr[0..old_byte_cap]);
                    self.ptr = new_mem.ptr;
                    self.cap = new_exact_cap;
                },
            }
        }
        pub fn grow_capacity_if_needed(self: *Self, need_capacity: IDX, growth: Growth, alloc: Allocator) void {
            if (self.cap < need_capacity) {
                const adjusted_need_capacity = growth.calc(need_capacity);
                self.realloc_internal(adjusted_need_capacity, alloc);
            }
        }
        pub fn grow_capacity_if_needed_for_n_more_elems(self: *Self, count: IDX, growth: Growth, alloc: Allocator) void {
            const need_cap = self.len + count;
            self.grow_capacity_if_needed(need_cap, growth, alloc);
        }
        pub fn shrink_capacity_to_at_most(self: *Self, new_max_cap: IDX, alloc: Allocator) void {
            if (self.cap > new_max_cap) {
                self.realloc_internal(new_max_cap, alloc);
            }
        }
        pub fn shrink_capacity_reserve_at_most_n_free_space(self: *Self, at_most_n_free_space: IDX, alloc: Allocator) void {
            const curr_free_space = self.cap - self.len;
            if (curr_free_space > at_most_n_free_space) {
                const new_cap = self.len + at_most_n_free_space;
                self.realloc_internal(new_cap, alloc);
            }
        }
        pub fn resize_capacity_exact(self: *Self, exact_cap: IDX, alloc: Allocator) void {
            if (self.cap == exact_cap) return;
            self.realloc_internal(exact_cap, alloc);
        }
        fn free_internal(self: *Self, alloc: Allocator) void {
            switch (comptime FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    alloc.free(self.ptr[0..self.cap]);
                    self.ptr = undefined;
                    self.len = 0;
                    self.cap = 0;
                    self.start_offset = 0;
                    self.owns_memory = true;
                },
                .SPLIT_FIELDS => {
                    const byte_cap = end_stride() * self.cap;
                    alloc.free(self.ptr[0..byte_cap]);
                    self.ptr = undefined;
                    self.len = 0;
                    self.cap = 0;
                    self.start_offset = 0;
                    self.owns_memory = true;
                },
            }
        }
        pub fn free(self: *Self, alloc: Allocator) void {
            assert_with_reason(self.owns_memory, @src(), "cannot free non-owned memory", .{});
            self.free_internal(alloc);
        }
        pub fn free_if_owned(self: *Self, alloc: Allocator) void {
            if (self.owns_memory) {
                self.free_internal(alloc);
            }
        }
        fn append_idxs_internal(self: *Self, n: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth) IDX {
            switch (ALLOC) {
                .ASSUME_CAP => {
                    assert_with_reason(self.len + n <= self.cap, @src(), "appending {d} slots would exceed capacity, len = {d}, cap = {d}", .{ n, self.len, self.cap });
                },
                .REALLOC => {
                    self.grow_capacity_if_needed_for_n_more_elems(n, if (GROWTH_MODE == .CUSTOM_GROWTH) growth else Growth.GROW_BY_25_PERCENT, alloc);
                },
            }
            const first_idx = self.len;
            self.len += n;
            return first_idx;
        }
        fn append_one_slot_internal(self: *Self, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            const last_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {},
            }
            return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(last_idx) else undefined, last_idx);
        }
        pub inline fn append_one_slot_assume_cap_get_ptr(self: *Self) ElemPtr {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
        }
        pub inline fn append_one_slot_with_growth_get_ptr(self: *Self, growth: Growth, alloc: Allocator) ElemPtr {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
        }
        pub inline fn append_one_slot_get_ptr(self: *Self, alloc: Allocator) ElemPtr {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
        }
        pub inline fn append_one_slot_assume_cap_get_ptr_idx(self: *Self) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_IDX);
        }
        pub inline fn append_one_slot_with_growth_get_ptr_idx(self: *Self, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_IDX);
        }
        pub inline fn append_one_slot_get_ptr_idx(self: *Self, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_IDX);
        }
        pub inline fn append_one_slot_assume_cap_get_idx(self: *Self) IDX {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
        }
        pub inline fn append_one_slot_with_growth_get_idx(self: *Self, growth: Growth, alloc: Allocator) IDX {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
        }
        pub inline fn append_one_slot_get_idx(self: *Self, alloc: Allocator) IDX {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
        }
        pub inline fn append_one_slot_assume_cap(self: *Self) void {
            return self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn append_one_slot_with_growth(self: *Self, growth: Growth, alloc: Allocator) void {
            return self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn append_one_slot(self: *Self, alloc: Allocator) void {
            return self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub inline fn append_one_assume_cap_get_ptr(self: *Self, val: T) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn append_one_with_growth_get_ptr(self: *Self, val: T, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn append_one_get_ptr(self: *Self, val: T, alloc: Allocator) ElemPtr {
            const elem_ptr = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn append_one_assume_cap_get_ptr_idx(self: *Self, val: T) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn append_one_with_growth_get_ptr_idx(self: *Self, val: T, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn append_one_get_ptr_idx(self: *Self, val: T, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn append_one_assume_cap_get_idx(self: *Self, val: T) IDX {
            const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn append_one_with_growth_get_idx(self: *Self, val: T, growth: Growth, alloc: Allocator) IDX {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn append_one_get_idx(self: *Self, val: T, alloc: Allocator) IDX {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn append_one_assume_cap(self: *Self, val: T) void {
            const slot_idx = self.append_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub inline fn append_one_with_growth(self: *Self, val: T, growth: Growth, alloc: Allocator) void {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub inline fn append_one(self: *Self, val: T, alloc: Allocator) void {
            const slot_idx = self.append_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        // TODO: Append many
        fn prepend_one_slot_internal(self: *Self, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            const last_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                    self.move_one_left_displace_internal(last_idx, 0);
                },
            }
            return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(0) else undefined, 0);
        }
        pub inline fn prepend_one_slot_assume_cap_get_ptr(self: *Self) ElemPtr {
            return self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
        }
        pub inline fn prepend_one_slot_with_growth_get_ptr(self: *Self, growth: Growth, alloc: Allocator) ElemPtr {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
        }
        pub inline fn prepend_one_slot_get_ptr(self: *Self, alloc: Allocator) ElemPtr {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
        }
        pub inline fn prepend_one_slot_assume_cap(self: *Self) void {
            return self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn prepend_one_slot_with_growth(self: *Self, growth: Growth, alloc: Allocator) void {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn prepend_one_slot(self: *Self, alloc: Allocator) void {
            return self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub inline fn prepend_one_assume_cap_get_ptr(self: *Self, val: T) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn prepend_one_with_growth_get_ptr(self: *Self, val: T, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn prepend_one_get_ptr(self: *Self, val: T, alloc: Allocator) ElemPtr {
            const elem_ptr = self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn prepend_one_assume_cap(self: *Self, val: T) void {
            self.prepend_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        pub inline fn prepend_one_with_growth(self: *Self, val: T, growth: Growth, alloc: Allocator) void {
            self.prepend_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        pub inline fn prepend_one(self: *Self, val: T, alloc: Allocator) void {
            self.prepend_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
            self.set_true_idx(self.true_idx(0), val);
        }
        // TODO: Prepend many
        fn insert_one_slot_internal(self: *Self, idx: IDX, comptime ALLOC: AllocMode, alloc: Allocator, comptime GROWTH_MODE: GrowthMode, growth: Growth, comptime RETURN: ReturnMode) RETURN.RetType(ElemPtr, IDX) {
            if (idx == self.len) {
                return self.append_one_slot_internal(ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else if (idx == 0) {
                self.assert_valid_idx(idx, @src());
                return self.prepend_one_slot_internal(ALLOC, alloc, GROWTH_MODE, growth, RETURN);
            } else {
                self.assert_valid_idx(idx, @src());
                const last_idx = self.append_idxs_internal(1, ALLOC, alloc, GROWTH_MODE, growth);
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                        self.move_one_left_displace_internal(last_idx, idx);
                    },
                }
                return RETURN.ret_val(ElemPtr, IDX, if (comptime RETURN.returns_ptr()) self.get_ptr(last_idx) else undefined, idx);
            }
        }
        pub inline fn insert_one_slot_assume_cap_get_ptr(self: *Self) ElemPtr {
            return self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
        }
        pub inline fn insert_one_slot_with_growth_get_ptr(self: *Self, growth: Growth, alloc: Allocator) ElemPtr {
            return self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
        }
        pub inline fn insert_one_slot_get_ptr(self: *Self, alloc: Allocator) ElemPtr {
            return self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
        }
        pub inline fn insert_one_slot_assume_cap_get_ptr_idx(self: *Self) struct { ElemPtr, IDX } {
            return self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_IDX);
        }
        pub inline fn insert_one_slot_with_growth_get_ptr_idx(self: *Self, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_IDX);
        }
        pub inline fn insert_one_slot_get_ptr_idx(self: *Self, alloc: Allocator) struct { ElemPtr, IDX } {
            return self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_IDX);
        }
        pub inline fn insert_one_slot_assume_cap_get_idx(self: *Self) IDX {
            return self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
        }
        pub inline fn insert_one_slot_with_growth_get_idx(self: *Self, growth: Growth, alloc: Allocator) IDX {
            return self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
        }
        pub inline fn insert_one_slot_get_idx(self: *Self, alloc: Allocator) IDX {
            return self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
        }
        pub inline fn insert_one_slot_assume_cap(self: *Self) void {
            return self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_VOID);
        }
        pub inline fn insert_one_slot_with_growth(self: *Self, growth: Growth, alloc: Allocator) void {
            return self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_VOID);
        }
        pub inline fn insert_one_slot(self: *Self, alloc: Allocator) void {
            return self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_VOID);
        }
        pub inline fn insert_one_assume_cap_get_ptr(self: *Self, val: T) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn insert_one_with_growth_get_ptr(self: *Self, val: T, growth: Growth, alloc: Allocator) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn insert_one_get_ptr(self: *Self, val: T, alloc: Allocator) ElemPtr {
            const elem_ptr = self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR);
            assign_val_to_elem_ptr(elem_ptr, val);
            return elem_ptr;
        }
        pub inline fn insert_one_assume_cap_get_ptr_idx(self: *Self, val: T) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn insert_one_with_growth_get_ptr_idx(self: *Self, val: T, growth: Growth, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn insert_one_get_ptr_idx(self: *Self, val: T, alloc: Allocator) struct { ElemPtr, IDX } {
            const elem_ptr, const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_PTR_IDX);
            assign_val_to_elem_ptr(elem_ptr, val);
            return .{ elem_ptr, slot_idx };
        }
        pub inline fn insert_one_assume_cap_get_idx(self: *Self, val: T) IDX {
            const slot_idx = self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn insert_one_with_growth_get_idx(self: *Self, val: T, growth: Growth, alloc: Allocator) IDX {
            const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn insert_one_get_idx(self: *Self, val: T, alloc: Allocator) IDX {
            const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
            return slot_idx;
        }
        pub inline fn insert_one_assume_cap(self: *Self, val: T) void {
            const slot_idx = self.insert_one_slot_internal(.ASSUME_CAP, dummy_alloc, .DEFAULT_GROWTH, .GROW_EXACT_NEEDED, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub inline fn insert_one_with_growth(self: *Self, val: T, growth: Growth, alloc: Allocator) void {
            const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .CUSTOM_GROWTH, growth, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        pub inline fn insert_one(self: *Self, val: T, alloc: Allocator) void {
            const slot_idx = self.insert_one_slot_internal(.REALLOC, alloc, .DEFAULT_GROWTH, .GROW_BY_25_PERCENT, .RETURN_IDX);
            self.set_true_idx(self.true_idx(slot_idx), val);
        }
        //TODO insert many
        fn delete_one_internal(self: *Self, idx: IDX, comptime STRATEGY: DeleteMode, comptime RETURN: DeleteReturnMode) if (RETURN == .RETURN_VAL) T else void {
            self.assert_valid_idx(idx, @src());
            const val_or_void: if (RETURN == .RETURN_VAL) T else void = if (RETURN == .RETURN_VAL) self.get(idx) else void{};
            if (idx == self.len - 1) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {},
                }
            } else if (idx == 0) {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                        const last_idx = self.len - 1;
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(1, last_idx, 0);
                            },
                            .SWAP => {
                                self.move_one_overwrite(last_idx, 0);
                            },
                        }
                    },
                }
            } else {
                switch (comptime INDEX_LAYOUT) {
                    .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => {
                        const last_idx = self.len - 1;
                        switch (comptime STRATEGY) {
                            .ORDERED => {
                                self.move_block_overwrite_internal(idx + 1, last_idx, idx);
                            },
                            .SWAP => {
                                self.move_one_overwrite(last_idx, idx);
                            },
                        }
                    },
                }
            }
            self.len -= 1;
            return val_or_void;
        }
        pub fn delete_one(self: *Self, idx: IDX) void {
            self.assert_valid_idx(idx, @src());
            self.delete_one_internal(idx, .ORDERED, .IGNORE_VAL);
        }
        pub fn remove_one(self: *Self, idx: IDX) T {
            self.assert_valid_idx(idx, @src());
            return self.delete_one_internal(idx, .ORDERED, .RETURN_VAL);
        }
        pub fn swap_delete_one(self: *Self, idx: IDX) void {
            self.assert_valid_idx(idx, @src());
            self.delete_one_internal(idx, .SWAP, .IGNORE_VAL);
        }
        pub fn swap_remove_one(self: *Self, idx: IDX) T {
            self.assert_valid_idx(idx, @src());
            return self.delete_one_internal(idx, .SWAP, .RETURN_VAL);
        }
        //TODO: Delete many
    };
}
