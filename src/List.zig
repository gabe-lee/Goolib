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
const CommonTypes = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
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

pub fn List(comptime T: type, comptime FIELD_LAYOUT: FieldMode, comptime INDEX_LAYOUT: LayoutMode) type {
    const _NUM_FIELDS: usize = switch (@typeInfo(T)) {
        .@"struct" => |s| s.fields.len,
        else => 1,
    };
    const _NUM_BITS_FOR_FIELDS: usize = get: {
        const invertd_num_fields = ~_NUM_FIELDS;
        break :get @ctz(invertd_num_fields);
    };
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
                const e_int = std.meta.Int(.unsigned, @intCast(_NUM_BITS_FOR_FIELDS));
                var e_val: [_NUM_FIELDS]e_int = undefined;
                var off: [_NUM_FIELDS + 1]u32 = undefined;
                var off_total: u32 = 0;
                inline for (info.field_types[0..], 0..) |t, i| {
                    e_val[i] = @intCast(i);
                    off[i] = off_total;
                    off_total += @sizeOf(t);
                }
                off[_NUM_FIELDS] = off_total;
                break :get .{ info.field_names, info.field_types, off, @Enum(u8, .exhaustive, info.names[0..], e_val[0..]) };
            },
            .@"union" => {
                const info = Type.extract_union_info(T);
                var off: [_NUM_FIELDS + 1]u32 = @splat(0);
                off[_NUM_FIELDS] = @sizeOf(T);
                break :get .{ info.field_names, info.field_types, off, info.tag_type.? };
            },
            else => break :get .{ [0][]const u8, [0]Type{}, [0]u32{}, @Enum(u0, .exhaustive, &.{}, &.{}) },
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
        const MAX_ALIGN = @alignOf(T);
        const SERIAL_IDXS = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES, .SERIAL_INDEXES_WITH_OFFSET => true,
            else => false,
        };
        const IDX_OFFSET = switch (INDEX_LAYOUT) {
            .SERIAL_INDEXES => false,
            .SERIAL_INDEXES_WITH_OFFSET => true,
        };
        pub const Field = _FIELD_ENUM;
        const Ptr = if (SPLIT) [*]align(MAX_ALIGN) u8 else [*]T;

        ptr: Ptr = undefined,
        len: u32 = 0,
        cap: u32 = 0,
        start_offset: if (IDX_OFFSET) u32 else void = if (IDX_OFFSET) 0 else void{},

        fn assert_valid_idx(self: Self, idx: u32, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(idx < self.len, src, "index `{d}` is out of bounds", .{idx});
        }
        fn assert_whole_struct_for_ptr(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get whole struct pointer in .SPLIT_FIELDS mode", .{});
        }
        fn assert_whole_struct_for_slice(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SPLIT, src, "cannot get normal slice in .SPLIT_FIELDS mode", .{});
        }
        fn assert_start_less_end_exclusive(start: u32, end_excl: u32, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start < end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_start_less_or_equal_end_exclusive(start: u32, end_excl: u32, src: ?std.builtin.SourceLocation) void {
            assert_with_reason(start <= end_excl, src, "start must be <= end_exclusive, got {d} > {d}", .{ start, end_excl });
        }
        fn assert_serial_indexes(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(SERIAL_IDXS, src, "indexes must be serially in order at this point", .{});
        }

        fn field_offset(comptime field: Field) u32 {
            return ORDERED_FIELD_OFFETS[@intFromEnum(field)];
        }
        fn FieldType(comptime field: Field) type {
            return ORDERED_FIELD_TYPES[@intFromEnum(field)];
        }

        fn true_idx(self: Self, idx: u32) u32 {
            switch (comptime INDEX_LAYOUT) {
                .SERIAL_INDEXES => return idx,
                .SERIAL_INDEXES_WITH_OFFSET => return idx + self.start_offset,
            }
        }
        fn set_true_idx(self: Self, idx: u32, val: T) void {
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
        pub fn set(self: Self, idx: u32, val: T) void {
            self.assert_valid_idx(idx, @src());
            self.set_true_idx(self.true_idx(idx), val);
        }
        fn set_field_internal(self: Self, comptime field: Field, idx: u32, val: FieldType(field)) void {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    @field(&self.ptr[idx], @tagName(field)) = val;
                },
                .SPLIT_FIELDS => {
                    const name = @tagName(field);
                    const offset = field_offset(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    ptr.* = @field(val, name);
                },
            }
        }
        pub fn set_field(self: Self, comptime field: Field, idx: u32, val: FieldType(field)) void {
            self.assert_valid_idx(idx, @src());
            self.set_field_internal(field, self.true_idx(idx), val);
        }
        fn get_true_idx(self: Self, idx: u32) T {
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
        pub fn get(self: Self, idx: u32) T {
            self.assert_valid_idx(idx, @src());
            return self.get_true_idx(self.true_idx(idx));
        }
        fn get_ptr_internal(self: Self, idx: u32) *T {
            return &self.ptr[idx];
        }
        pub fn get_ptr(self: Self, idx: u32) *T {
            self.assert_valid_idx(idx, @src());
            assert_whole_struct_for_ptr(@src());
            return self.get_ptr_internal(self.true_idx(idx));
        }
        fn get_ptr_const_internal(self: Self, idx: u32) *const T {
            return &self.ptr[idx];
        }
        pub fn get_ptr_const(self: Self, idx: u32) *const T {
            self.assert_valid_idx(idx, @src());
            assert_whole_struct_for_ptr(@src());
            return self.get_ptr_const_internal(self.true_idx(idx));
        }
        fn get_field_true_idx(self: Self, comptime field: Field, idx: u32) FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_offset(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    return ptr.*;
                },
            }
        }
        pub fn get_field(self: Self, comptime field: Field, idx: u32) FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field(field, self.true_idx(idx));
        }
        fn get_field_ptr_internal(self: Self, comptime field: Field, idx: u32) *FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_offset(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *t = @ptrCast(@alignCast(ptr_opq));
                    return ptr;
                },
            }
        }
        pub fn get_field_ptr(self: Self, comptime field: Field, idx: u32) *FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_ptr_internal(field, self.true_idx(idx));
        }
        fn get_field_ptr_const_internal(self: Self, comptime field: Field, idx: u32) *const FieldType(field) {
            switch (FIELD_LAYOUT) {
                .WHOLE_STRUCTS => {
                    return @field(&self.ptr[idx], @tagName(field));
                },
                .SPLIT_FIELDS => {
                    const offset = field_offset(field);
                    const t = FieldType(field);
                    const full_off = (self.cap * offset) + (@sizeOf(t) * idx);
                    const ptr_opq = self.ptr + full_off;
                    const ptr: *const t = @ptrCast(@alignCast(ptr_opq));
                    return ptr;
                },
            }
        }
        pub fn get_field_ptr_const(self: Self, comptime field: Field, idx: u32) *const FieldType(field) {
            self.assert_valid_idx(idx, @src());
            return self.get_field_ptr_const_internal(field, self.true_idx(idx));
        }
        pub fn get_len(self: Self) u32 {
            return self.len;
        }
        pub fn set_len(self: *Self, new_len: u32) void {
            self.len = new_len;
        }
        pub fn incr_len(self: *Self, count: u32) void {
            self.len += count;
        }
        pub fn decr_len(self: *Self, count: u32) void {
            self.len -= count;
        }
        pub fn get_cap(self: Self) u32 {
            return self.cap;
        }
        pub fn set_cap(self: *Self, new_cap: u32) void {
            self.cap = new_cap;
        }
        pub fn incr_cap(self: *Self, count: u32) void {
            self.cap += count;
        }
        pub fn decr_cap(self: *Self, count: u32) void {
            self.cap -= count;
        }
        // pub fn slice(self: Self, start: u32, end_exclusive: u32) Self {
        //     assert_whole_struct_for_slice(@src());
        //     return Self{
        //         .ptr = self.ptr + start,
        //         .len = end_exclusive - start,
        //         .cap = end_exclusive - start,
        //     };
        // }
        fn reverse_range_internal(self: Self, start: u32, end_exclusive: u32) void {
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
        pub fn reverse_range(self: Self, start: u32, end_exclusive: u32) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.reverse_range_internal(start, end_exclusive);
        }
        fn reverse_range_field_idx(self: Self, comptime fidx: usize, start: u32, end_exclusive: u32) void {
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
        fn rotate_range_internal(self: Self, start: u32, end_exclusive: u32, delta: i64) void {
            const len: i64 = end_exclusive - start;
            const shift: u32 = @intCast(@mod(delta, len));
            self.rotate_range_right_internal(start, end_exclusive, shift);
        }
        pub fn rotate_range(self: Self, start: u32, end_exclusive: u32, delta: i64) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.rotate_range_internal(start, end_exclusive, delta);
        }
        pub fn rotate(self: Self, delta: i64) void {
            return self.rotate_range(0, self.len, delta);
        }
        fn rotate_range_right_internal(self: Self, start: u32, end_exclusive: u32, count: u32) void {
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
        pub fn rotate_range_right(self: Self, start: u32, end_exclusive: u32, count: u32) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            return self.rotate_range_right_internal(start, end_exclusive, count);
        }
        pub fn rotate_right(self: Self, count: u32) void {
            self.rotate_range_right(0, self.len, count);
        }
        fn rotate_range_left_internal(self: Self, start: u32, end_exclusive: u32, count: u32) void {
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
        pub fn rotate_range_left(self: Self, start: u32, end_exclusive: u32, count: u32) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (start == end_exclusive or count == 0) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            return self.rotate_range_left_internal(start, end_exclusive, count);
        }
        pub fn rotate_left(self: Self, count: u32) void {
            self.rotate_range_left(0, self.len, count);
        }
        pub fn move_block_displace(self: Self, old_start: u32, old_end_exclusive: u32, new_start: u32) void {
            if (old_start < new_start) {
                self.move_block_right_displace(old_start, old_end_exclusive, new_start);
            } else {
                self.move_block_left_displace(old_start, old_end_exclusive, new_start);
            }
        }
        pub fn move_block_right_displace(self: Self, old_start: u32, old_end_exclusive: u32, new_start: u32) void {
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
        pub fn move_block_left_displace(self: Self, old_start: u32, old_end_exclusive: u32, new_start: u32) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start > new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            const block_len = old_end_exclusive - old_start;
            self.rotate_range_right_internal(new_start, old_end_exclusive, block_len);
        }

        pub fn move_one_displace(self: Self, old_idx: u32, new_idx: u32) void {
            if (old_idx < new_idx) {
                self.move_one_right_displace(old_idx, new_idx);
            } else {
                self.move_one_left_displace(old_idx, new_idx);
            }
        }
        fn move_one_right_displace_internal(self: Self, old_idx: u32, new_idx: u32) void {
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
        pub fn move_one_right_displace(self: Self, old_idx: u32, new_idx: u32) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx < new_idx, @src(), "old_idx must be <= new_idx, got {d} > {d}", .{ old_idx, new_idx });
            self.move_one_right_displace_internal(old_idx, new_idx);
        }
        fn move_one_left_displace_internal(self: Self, old_idx: u32, new_idx: u32) void {
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
        pub fn move_one_left_displace(self: Self, old_idx: u32, new_idx: u32) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx > new_idx, @src(), "old_idx must be >= new_idx, got {d} < {d}", .{ old_idx, new_idx });
            self.move_one_left_displace_internal(old_idx, new_idx);
        }
        fn move_one_overwrite_true_idx(self: Self, old_idx: u32, new_idx: u32) void {
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
        fn move_one_overwrite(self: Self, old_idx: u32, new_idx: u32) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            self.move_one_overwrite_true_idx(self.true_idx(old_idx), self.true_idx(new_idx));
        }
        fn swap_true_idx(self: Self, idx_a: u32, idx_b: u32) void {
            const tmp = self.ptr[idx_a];
            self.ptr[idx_a] = self.ptr[idx_b];
            self.ptr[idx_b] = tmp;
        }
        fn swap(self: Self, idx_a: u32, idx_b: u32) void {
            self.assert_valid_idx(idx_a, @src());
            self.assert_valid_idx(idx_b, @src());
            self.swap_true_idx(self.true_idx(idx_a), self.true_idx(idx_b));
        }
        fn scramble_range_internal(self: Self, start: u32, end_exclusive: u32, iterations: u32, rand: Random) void {
            const len = end_exclusive - start;
            if (len <= 1) return;
            if (len == 2) {
                if (rand.boolean()) {
                    self.swap_true_idx(self.true_idx(start), self.true_idx(end_exclusive));
                }
                return;
            }
            var n: u32 = 0;
            const first_idx = rand.intRangeLessThan(u32, start, end_exclusive);
            var empty_idx: u32 = first_idx;
            var empty_true_idx: u32 = self.true_idx(first_idx);
            const first_val = self.get_true_idx(empty_true_idx);
            while (n < iterations) : (n += 1) {
                const move_idx = find_different_idx: {
                    while (true) {
                        const possible_different_idx = rand.intRangeLessThan(u32, start, end_exclusive);
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
        pub fn scramble_range(self: Self, start: u32, end_exclusive: u32, iterations: u32, rand: Random) void {
            self.assert_valid_idx(start, @src());
            self.assert_valid_idx(end_exclusive, @src());
            if (iterations == 0 or start == end_exclusive) return;
            assert_start_less_end_exclusive(start, end_exclusive, @src());
            self.scramble_range_internal(start, end_exclusive, iterations, rand);
        }
        pub fn scramble(self: Self, iterations: u32, rand: Random) void {
            self.scramble_range(0, self.len, iterations, rand);
        }
        //CHECKPOINT Realloc etc...
    };
}
