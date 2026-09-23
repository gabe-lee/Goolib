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
const DummyAlloc = Root.DummyAllocator.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

pub const Mode = enum {
    WHOLE_STRUCTS,
    SPLIT_FIELDS,
};

pub fn List(comptime T: type, comptime MODE: Mode) type {
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
        const SPLIT = MODE == .SPLIT_FIELDS;
        pub const Field = _FIELD_ENUM;
        const Ptr = if (SPLIT) [*]u8 else [*]T;

        ptr: Ptr = undefined,
        len: u32 = 0,
        cap: u32 = 0,

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

        fn field_offset(comptime field: Field) u32 {
            return ORDERED_FIELD_OFFETS[@intFromEnum(field)];
        }
        fn FieldType(comptime field: Field) type {
            return ORDERED_FIELD_TYPES[@intFromEnum(field)];
        }

        pub fn set(self: Self, idx: u32, val: T) void {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn set_field(self: Self, comptime field: Field, idx: u32, val: FieldType(field)) void {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn get(self: Self, idx: u32) T {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn get_ptr(self: Self, idx: u32) *T {
            self.assert_valid_idx(idx, @src());
            assert_whole_struct_for_ptr(@src());
            return &self.ptr[idx];
        }
        pub fn get_ptr_const(self: Self, idx: u32) *const T {
            self.assert_valid_idx(idx, @src());
            assert_whole_struct_for_ptr(@src());
            return &self.ptr[idx];
        }
        pub fn get_field(self: Self, comptime field: Field, idx: u32) FieldType(field) {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn get_field_ptr(self: Self, comptime field: Field, idx: u32) *FieldType(field) {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn get_field_ptr_const(self: Self, comptime field: Field, idx: u32) *const FieldType(field) {
            self.assert_valid_idx(idx, @src());
            switch (MODE) {
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
        pub fn slice(self: Self, start: u32, end_exclusive: u32) Self {
            assert_whole_struct_for_slice(@src());
            return Self{
                .ptr = self.ptr + start,
                .len = end_exclusive - start,
                .cap = end_exclusive - start,
            };
        }
        pub fn reverse_range(self: Self, start: u32, end_exclusive: u32) void {
            if (start >= end_exclusive) return;
            switch (MODE) {
                .WHOLE_STRUCTS => {
                    var left: u32 = start;
                    var right: u32 = end_exclusive - 1;
                    var count: u32 = (end_exclusive - start) >> 1;
                    while (count > 0) {
                        const temp = self.ptr[left];
                        self.ptr[left] = self.ptr[right];
                        self.ptr[right] = temp;
                        count -= 1;
                        left += 1;
                        right -= 1;
                    }
                },
                .SPLIT_FIELDS => {
                    const full_count: u32 = (end_exclusive - start) >> 1;
                    inline for (ORDERED_FIELD_OFFETS[0.._NUM_FIELDS], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        var count: u32 = full_count;
                        const base_off = (self.cap * offset);
                        const left_off = base_off + (@sizeOf(t) * start);
                        const right_off = base_off + (@sizeOf(t) * (end_exclusive - 1));
                        const left_opq = self.ptr + left_off;
                        const right_opq = self.ptr + right_off;
                        const ptr_left: [*]t = @ptrCast(@alignCast(left_opq));
                        const ptr_right: [*]t = @ptrCast(@alignCast(right_opq));
                        while (count > 0) {
                            const temp = ptr_left[0];
                            ptr_left[0] = ptr_right[0];
                            ptr_right[0] = temp;
                            count -= 1;
                            ptr_left += 1;
                            ptr_right -= 1;
                        }
                    }
                },
            }
        }
        fn reverse_range_field_idx(self: Self, comptime fidx: u32, full_count: u32, start: u32, end_exclusive: u32) void {
            var count: u32 = full_count;
            const offset = ORDERED_FIELD_OFFETS[fidx];
            const t = ORDERED_FIELD_TYPES[fidx];
            const base_off = (self.cap * offset);
            const left_off = base_off + (@sizeOf(t) * start);
            const right_off = base_off + (@sizeOf(t) * (end_exclusive - 1));
            const left_opq = self.ptr + left_off;
            const right_opq = self.ptr + right_off;
            const ptr_left: [*]t = @ptrCast(@alignCast(left_opq));
            const ptr_right: [*]t = @ptrCast(@alignCast(right_opq));
            while (count > 0) {
                const temp = ptr_left[0];
                ptr_left[0] = ptr_right[0];
                ptr_right[0] = temp;
                count -= 1;
                ptr_left += 1;
                ptr_right -= 1;
            }
        }
        pub fn reverse(self: Self) void {
            self.reverse_range(0, self.len);
        }
        pub fn rotate_range(self: Self, start: u32, end_exclusive: u32, delta: i64) void {
            if (start >= end_exclusive) return;
            const len: i64 = end_exclusive - start;
            const shift: u32 = @intCast(@mod(delta, len));
            self.rotate_range_right(start, end_exclusive, shift);
        }
        pub fn rotate(self: Self, delta: i64) void {
            return self.rotate_range(0, self.len, delta);
        }
        pub fn rotate_range_right(self: Self, start: u32, end_exclusive: u32, count: u32) void {
            if (start >= end_exclusive) return;
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_left(end_exclusive - 1, start);
                return;
            }
            if (shift == len - 1) {
                self.move_one_right(start, end_exclusive - 1);
                return;
            }
            const boundary = end_exclusive - shift;
            switch (MODE) {
                .WHOLE_STRUCTS => {
                    self.reverse_range(start, boundary);
                    self.reverse_range(boundary, end_exclusive);
                    self.reverse_range(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    const start_len = (boundary - start);
                    const end_len = (end_exclusive - boundary);
                    inline for (0..NUM_FIELDS) |i| {
                        self.reverse_range_field_idx(@intCast(i), start_len, start, boundary);
                        self.reverse_range_field_idx(@intCast(i), end_len, boundary, end_exclusive);
                        self.reverse_range_field_idx(@intCast(i), len, start, end_exclusive);
                    }
                },
            }
        }
        pub fn rotate_right(self: Self, count: u32) void {
            self.rotate_range_right(0, self.len, count);
        }
        pub fn rotate_range_left(self: Self, start: u32, end_exclusive: u32, count: u32) void {
            if (start >= end_exclusive) return;
            const len = end_exclusive - start;
            const shift = count % len;
            if (shift == 0) return;
            if (shift == 1) {
                self.move_one_right(start, end_exclusive - 1);
                return;
            }
            if (shift == len - 1) {
                self.move_one_left(end_exclusive - 1, start);
                return;
            }
            const boundary = start + shift;
            switch (MODE) {
                .WHOLE_STRUCTS => {
                    self.reverse_range(start, boundary);
                    self.reverse_range(boundary, end_exclusive);
                    self.reverse_range(start, end_exclusive);
                },
                .SPLIT_FIELDS => {
                    const start_len = (boundary - start);
                    const end_len = (end_exclusive - boundary);
                    inline for (0..NUM_FIELDS) |i| {
                        self.reverse_range_field_idx(@intCast(i), start_len, start, boundary);
                        self.reverse_range_field_idx(@intCast(i), end_len, boundary, end_exclusive);
                        self.reverse_range_field_idx(@intCast(i), len, start, end_exclusive);
                    }
                },
            }
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
            self.rotate_range_left(old_start, new_end_exclusive, block_len);
        }
        pub fn move_block_left_displace(self: Self, old_start: u32, old_end_exclusive: u32, new_start: u32) void {
            self.assert_valid_idx(old_start, @src());
            self.assert_valid_idx(old_end_exclusive, @src());
            self.assert_valid_idx(new_start, @src());
            if (old_start == new_start or old_start == old_end_exclusive) return;
            assert_start_less_end_exclusive(old_start, old_end_exclusive, @src());
            assert_with_reason(old_start > new_start, @src(), "old start must be >= new_start to move block left, got {d} < {d}", .{ old_start, new_start });
            const block_len = old_end_exclusive - old_start;
            self.rotate_range_right(new_start, old_end_exclusive, block_len);
        }

        pub fn move_one(self: Self, old_idx: u32, new_idx: u32) void {
            if (old_idx < new_idx) {
                self.move_one_right(old_idx, new_idx);
            } else {
                self.move_one_left(old_idx, new_idx);
            }
        }
        pub fn move_one_right(self: Self, old_idx: u32, new_idx: u32) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx < new_idx, @src(), "old_idx must be <= new_idx, got {d} > {d}", .{ old_idx, new_idx });
            switch (MODE) {
                .WHOLE_STRUCTS => {
                    const temp = self.ptr[old_idx];
                    @memmove(self.ptr[old_idx..new_idx], self.ptr[(old_idx + 1)..(new_idx + 1)]);
                    self.ptr[new_idx] = temp;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0..], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const raw_offset = (self.cap * offset);
                        const field_ptr: [*]t = @ptrCast(self.ptr + raw_offset);
                        const temp = field_ptr[old_idx];
                        @memmove(field_ptr[old_idx..new_idx], field_ptr[(old_idx + 1)..(new_idx + 1)]);
                        field_ptr[new_idx] = temp;
                    }
                },
            }
        }
        pub fn move_one_left(self: Self, old_idx: u32, new_idx: u32) void {
            self.assert_valid_idx(old_idx, @src());
            self.assert_valid_idx(new_idx, @src());
            if (old_idx == new_idx) return;
            assert_with_reason(old_idx > new_idx, @src(), "old_idx must be >= new_idx, got {d} < {d}", .{ old_idx, new_idx });
            switch (MODE) {
                .WHOLE_STRUCTS => {
                    const temp = self.ptr[old_idx];
                    @memmove(self.ptr[(new_idx + 1)..(old_idx + 1)], self.ptr[new_idx..old_idx]);
                    self.ptr[new_idx] = temp;
                },
                .SPLIT_FIELDS => {
                    inline for (ORDERED_FIELD_OFFETS[0..], ORDERED_FIELD_TYPES[0..]) |offset, t| {
                        const raw_offset = (self.cap * offset);
                        const field_ptr: [*]t = @ptrCast(self.ptr + raw_offset);
                        const temp = field_ptr[old_idx];
                        @memmove(field_ptr[(new_idx + 1)..(old_idx + 1)], field_ptr[new_idx..old_idx]);
                        field_ptr[new_idx] = temp;
                    }
                },
            }
        }
        // TODO: SCRAMBLE
    };
}
