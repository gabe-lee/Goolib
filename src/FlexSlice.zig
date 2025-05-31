//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");
const build = @import("builtin");
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Utils = Root.Utils;
const u_secure_memset = Utils.secure_memset;
const u_secure_memset_const = Utils.secure_memset_const;
const u_secure_zero = Utils.secure_zero;
const u_secure_memset_undefined = Utils.secure_memset_undefined;
const assert_with_reason = Utils.assert_with_reason;
const comptime_assert_with_reason = Utils.comptime_assert_with_reason;
const InsertionSort = Root.InsertionSort;
const BinarySearch = Root.BinarySearch;

const ERR_CANNOT_INCREASE_START = "Slice START_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase start address";
const ERR_CANNOT_DECREASE_START = "Slice START_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease start address";
const ERR_CANNOT_INCREASE_END = "Slice END_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase end address";
const ERR_CANNOT_DECREASE_END = "Slice END_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease end address";
const ERR_CANNOT_GROW_LEN = "Slice LEN_MUTABILITY != .grow_only or .shrink_or_grow, operation would grow length";
const ERR_CANNOT_SHRINK_LEN = "Slice LEN_MUTABILITY != .shrink_only or .shrink_or_grow, operation would shrink length";
const ERR_OPERATE_IMMUTABLE_ELEM = "Slice(ELEM_MUTABILITY = .immutable) attempted to change element value";
const ERR_OPERATE_NULL = "Slice: cannot operate on null ptr";
const ERR_SHRINK_OOB = "Slice: shrink count ({d}) would cause condition `first_address > last_address` (max shrink = len = {d})";
const ERR_START_END_REVERSED = "Slice: provided start ({d}) and end ({s}) indexes would cause condition `first_address > last_address`";
const ERR_INDEX_OOB = "Slice: the largest requested or provided index ({d}) is out of slice bounds (len = {d})";
const ERR_INDEX_CHUNK_OOB = "Slice: requested or provided start + count ({d} + {d} = {d}) would put the resulting sub-slice out of original bounds (len = {d})";
const ERR_SHIFT_OVERLAP = "Slice: a `shift({s}) -> @memcopy` operation isn't shifted far enough to guarantee no overlap (min_shift = len = {d})";

pub fn FlexSlice(comptime T: type, comptime Idx: type, ELEM_MUTABILITY: Mutability) type {
    if (@typeInfo(Idx) != .int and @typeInfo(Idx) != .comptime_int) @compileError("type `Idx` must be an integer type");
    const Ptr = if (ELEM_MUTABILITY == .mutable) ?[*]T else ?[*]const T;
    return extern struct {
        ptr: Ptr,
        len: Idx,

        const Self = @This();
        const MUTABLE = ELEM_MUTABILITY == .mutable;

        pub const NULL = Self{ .ptr = null, .len = 0 };

        pub inline fn is_empty(self: Self) bool {
            return self.len == 0;
        }
        pub inline fn is_null(self: Self) bool {
            return self.ptr == null;
        }

        // pub inline fn from(native_pointer_or_slice: anytype) Self {
        //     if (Utils.type_is_optional(native_pointer_or_slice) and native_pointer_or_slice == null) return Self.NULL;
        //     const NAT_PTR = if (Utils.type_is_optional(native_pointer_or_slice)) Utils.optional_type_child(native_pointer_or_slice) else @TypeOf(native_pointer_or_slice);
        //     const unwrapped_ptr: NAT_PTR = if (Utils.type_is_optional(native_pointer_or_slice)) native_pointer_or_slice.? else native_pointer_or_slice;
        //     if (Utils.type_is_pointer_or_slice(NAT_PTR) and Utils.pointer_is_mutable(NAT_PTR)) {
        //         const CHILD = Utils.pointer_child_type(NAT_PTR);
        //         if (Utils.pointer_is_slice(NAT_PTR)) {
        //             if (CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
        //             if (CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
        //             return Self{ .ptr = unwrapped_ptr.ptr, .len = @intCast(unwrapped_ptr.len) };
        //         } else if (Utils.pointer_is_single(NAT_PTR)) {
        //             if (Utils.type_is_array_or_vector(CHILD)) {
        //                 const ARR_CHILD = Utils.array_or_vector_child_type(CHILD);
        //                 if (ARR_CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(ARR_CHILD));
        //                 return Self{ .ptr = @ptrCast(@alignCast(&unwrapped_ptr[0])), .len = @intCast(unwrapped_ptr.len) };
        //             } else {
        //                 if (CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
        //                 return Self{ .ptr = unwrapped_ptr, .len = 1 };
        //             }
        //         } else if (Utils.pointer_is_many(NAT_PTR)) {
        //             if (CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
        //             const sentinel = Utils.pointer_type_sentinel(NAT_PTR);
        //             const sent_slice = Utils.make_slice_from_sentinel_ptr(CHILD, sentinel.*, unwrapped_ptr);
        //             return Self{ .ptr = sent_slice.ptr, .len = @intCast(sent_slice.len) };
        //         } else {
        //             if (CHILD != T) @compileError(LOG_PREFIX ++ "Slice(" ++ @typeName(T) ++ ").from(" ++ @typeName(native_pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
        //             if (@intFromPtr(unwrapped_ptr) == 0) return Self.NULL;
        //             return Self{ .ptr = @ptrCast(@alignCast(unwrapped_ptr)), .len = 1 };
        //         }
        //     } else @compileError(LOG_PREFIX ++ "cannot create a Slice from non-pointer type or non-mutable pointer type");
        // }

        pub inline fn from_slice(slice: if (MUTABLE) ?[]T else ?[]const T) Self {
            if (slice) |s| {
                return Self{
                    .ptr = s.ptr,
                    .len = s.len,
                };
            }
            return Self{
                .ptr = null,
                .len = 0,
            };
        }

        pub inline fn to_slice(self: Self) if (MUTABLE) []T else []const T {
            assert_with_reason(self.ptr != null, @src(), "cannot cast Slice({s}).ptr == `null` to native zig slice []{s}", .{ @typeName(T), @typeName(T) });
            return self.ptr.?[0..@intCast(self.len)];
        }

        pub inline fn to_nullable_slice(self: Self) if (MUTABLE) ?[]T else ?[]const T {
            if (self.ptr == null) return null;
            return self.ptr.?[0..@intCast(self.len)];
        }

        pub inline fn change_mutability(self: Self, comptime elem_mutability: Mutability) FlexSlice(T, Idx, elem_mutability) {
            if (elem_mutability == ELEM_MUTABILITY) return self;
            return FlexSlice(T, Idx, elem_mutability){
                .ptr = if (elem_mutability == .mutable and ELEM_MUTABILITY == .immutable) @constCast(self.ptr) else self.ptr,
                .len = self.len,
            };
        }

        pub inline fn new(ptr: [*]T, len: Idx) Self {
            return Self{ .ptr = ptr, .len = len };
        }
        pub inline fn new_with_start_end(ptr: [*]T, start: Idx, end: Idx) Self {
            assert_with_reason(end >= start, @src(), ERR_START_END_REVERSED, .{ start, end });
            return Self{ .ptr = ptr + start, .len = end - start };
        }

        pub inline fn grow_right(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr, .len = self.len + count };
        }

        pub inline fn grow_left(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr.? - count, .len = self.len + count };
        }

        pub inline fn shrink_right(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len >= count, @src(), ERR_SHRINK_OOB, .{ count, self.len });
            return Self{ .ptr = self.ptr, .len = self.len - count };
        }

        pub inline fn shrink_left(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len >= count, @src(), ERR_SHRINK_OOB, .{ count, self.len });
            return Self{ .ptr = self.ptr.? + count, .len = self.len - count };
        }

        pub inline fn shift_right(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr.? + count, .len = self.len };
        }

        pub inline fn shift_left(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr.? - count, .len = self.len };
        }

        pub inline fn sub_slice_start_len(self: Self, start: Idx, len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(start + len <= self.len, @src(), ERR_INDEX_CHUNK_OOB, .{ start, len, start + len, self.len });
            return Self{ .ptr = self.ptr.? + start, .len = len };
        }

        pub inline fn sub_slice_start_end(self: Self, start: Idx, end: Idx) Self {
            assert_with_reason(end >= start, @src(), ERR_START_END_REVERSED, .{ start, end });
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(end <= self.len, @src(), ERR_INDEX_CHUNK_OOB, .{ start, end - start, end, self.len });
            return Self{ .ptr = self.ptr.? + start, .len = end - start };
        }

        pub inline fn sub_slice_from_start(self: Self, len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(len <= self.len, @src(), ERR_INDEX_CHUNK_OOB, .{ 0, len, len, self.len });
            return Self{ .ptr = self.ptr, .len = len };
        }

        pub inline fn sub_slice_from_end(self: Self, len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(len <= self.len, @src(), ERR_INDEX_CHUNK_OOB, .{ self.len - len, len, self.len, self.len });
            const diff = self.len - len;
            return Self{ .ptr = self.ptr.? + diff, .len = len };
        }

        pub inline fn with_new_len(self: Self, new_len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr, .len = new_len };
        }

        pub inline fn with_new_ptr(self: Self, new_ptr: ?[*]T) Self {
            return Self{ .ptr = new_ptr, .len = self.len };
        }

        pub inline fn new_slice_adjacent_before(self: Self, len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr.? - len, .len = len };
        }

        pub inline fn new_slice_adjacent_after(self: Self, len: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            return Self{ .ptr = self.ptr.? + self.len, .len = len };
        }

        pub inline fn get_item_ptr(self: Self, idx: Idx) *T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return &self.ptr.?[idx];
        }

        pub inline fn get_last_item_ptr(self: Self) *T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ -1, self.len });
            return &self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item_ptr(self: Self) *T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ 0, self.len });
            return &self.ptr.?[0];
        }

        pub inline fn get_item_const_ptr(self: Self, idx: Idx) *const T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return &self.ptr.?[idx];
        }

        pub inline fn get_last_item_const_ptr(self: Self) *const T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ -1, self.len });
            return &self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item_const_ptr(self: Self) *const T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ 0, self.len });
            return &self.ptr.?[0];
        }

        pub inline fn get_item(self: Self, idx: Idx) T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return self.ptr.?[idx];
        }

        pub inline fn get_last_item(self: Self) T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ -1, self.len });
            return self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item(self: Self) T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ 0, self.len });
            return self.ptr.?[0];
        }

        pub inline fn get_item_ptr_from_end(self: Self, idx: Idx) *T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return &self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn get_item_const_ptr_from_end(self: Self, idx: Idx) *const T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return &self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn get_item_from_end(self: Self, idx: Idx) T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            return self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn set_item(self: Self, idx: Idx, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            self.ptr.?[idx] = val;
        }

        pub inline fn set_last_item(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ -1, self.len });
            self.ptr.?[self.len - 1] = val;
        }

        pub inline fn set_first_item(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(self.len > 0, @src(), ERR_INDEX_OOB, .{ 0, self.len });
            self.ptr.?[0] = val;
        }

        pub inline fn set_item_from_end(self: Self, idx: Idx, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert_with_reason(idx < self.len, @src(), ERR_INDEX_OOB, .{ idx, self.len });
            self.ptr.?[self.len - 1 - idx] = val;
        }

        pub inline fn memcopy_to(self: Self, other: anytype) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            Utils.memcopy(self.ptr.?, other, @intCast(self.len));
        }

        pub inline fn memcopy_from(self: Self, other: anytype) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            Utils.memcopy(other, self.ptr.?, self.len);
        }

        pub inline fn memset(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            @memset(self.to_slice(), val);
        }

        pub inline fn secure_zero(self: Self) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            u_secure_zero(T, self.ptr.?[0..self.len]);
        }

        pub inline fn secure_memset_undefined(self: Self) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            u_secure_memset_undefined(T, self.ptr.?[0..self.len]);
        }

        pub inline fn secure_memset(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            u_secure_memset(T, self.ptr.?[0..self.len], val);
        }

        pub inline fn secure_memset_const(self: Self, comptime val: T) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            u_secure_memset_const(T, self.ptr.?[0..self.len], val);
        }

        pub fn copy_rightward(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            const new_slice = self.shift_right(count);
            if (count > self.len) {
                @memcpy(new_slice.to_slice(), self.to_slice());
            } else {
                std.mem.copyBackwards(T, new_slice.to_slice(), self.to_slice());
            }
            return new_slice;
        }

        pub fn copy_rightward_and_zero_old(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            const new_slice = self.shift_right(count);
            if (count > self.len) {
                @memcpy(new_slice.to_slice(), self.to_slice());
            } else {
                std.mem.copyBackwards(T, new_slice.to_slice(), self.to_slice());
            }
            self.sub_slice_from_start(count).secure_zero();
            return new_slice;
        }

        pub fn copy_leftward(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            const new_slice = self.shift_left(count);
            if (count > self.len) {
                @memcpy(new_slice.to_slice(), self.to_slice());
            } else {
                std.mem.copyForwards(T, new_slice.to_slice(), self.to_slice());
            }
            return new_slice;
        }

        pub fn copy_leftward_and_zero_old(self: Self, count: Idx) Self {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            const new_slice = self.shift_left(count);
            if (count > self.len) {
                @memcpy(new_slice.to_slice(), self.to_slice());
            } else {
                std.mem.copyForwards(T, new_slice.to_slice(), self.to_slice());
            }
            self.sub_slice_from_end(count).secure_zero();
            return new_slice;
        }

        pub inline fn swap(self: *Self, idx_a: Idx, idx_b: Idx) void {
            const a_val: T = self.get_item(idx_a);
            self.set_item(idx_a, self.get_item(idx_b));
            self.set_item(idx_b, a_val);
        }

        pub fn reverse(self: *Self) void {
            var l: Idx = 0;
            var r: Idx = self.len - 1;
            while (l < r) {
                self.swap(l, r);
                l += 1;
                r += 1;
            }
        }

        pub fn find_item_idx(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?Idx {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(param, item)) return i;
            }
            return null;
        }

        pub fn find_item_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?*T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(param, item)) return item;
            }
            return null;
        }

        pub fn find_item_const_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?*const T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(param, item)) return item;
            }
            return null;
        }

        pub fn find_item_and_copy(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?T {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(param, item)) return item.*;
            }
            return null;
        }

        pub fn find_exactly_n_item_indexes_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []Idx) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = i;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*T) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*const T) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_item_copies_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*const T) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr.?[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item.*;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn insertion_sort(self: *Self) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            InsertionSort.insertion_sort(T, self.ptr.?[0..self.len]);
        }

        pub fn insertion_sort_with_transform(self: *Self, comptime TX: type, transform_fn: *const fn (item: T) TX) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            InsertionSort.insertion_sort_with_transform(T, self.ptr.?[0..self.len], TX, transform_fn);
        }

        pub fn insertion_sort_with_transform_and_user_data(self: *Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) void {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            InsertionSort.insertion_sort_with_transform_and_user_data(T, self.ptr.?[0..self.len], TX, transform_fn, user_data);
        }

        pub fn is_sorted(self: Self) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(self.ptr.?[i], self.ptr.?[i - 1])) return false;
            }
            return true;
        }

        pub fn is_sorted_with_transform(self: Self, comptime TX: type, transform_fn: *const fn (item: T) TX) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(transform_fn(self.ptr.?[i]), transform_fn(self.ptr.?[i - 1]))) return false;
            }
            return true;
        }

        pub fn is_sorted_with_transform_and_user_data(self: Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(transform_fn(self.ptr.?[i], user_data), transform_fn(self.ptr.?[i - 1], user_data))) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted(self: Self) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(self.ptr.?[i], self.ptr.?[i - 1])) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted_with_transform(self: Self, comptime TX: type, transform_fn: *const fn (item: T) TX) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(transform_fn(self.ptr.?[i]), transform_fn(self.ptr.?[i - 1]))) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted_with_transform_and_user_data(self: Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) bool {
            assert_with_reason(self.ptr != null, @src(), ERR_OPERATE_NULL, .{});
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(transform_fn(self.ptr.?[i], user_data), transform_fn(self.ptr.?[i - 1], user_data))) return false;
            }
            return true;
        }

        pub fn sorted_binary_search_insert_idx_for_item(self: Self, item: T) Idx {
            return @intCast(BinarySearch.binary_search_insert_index(T, item, self.to_slice()));
        }

        pub fn sorted_binary_search_insert_idx_for_item_with_transform(self: Self, item: T, comptime TX: type, transform_fn: *const fn (item: T) TX) Idx {
            return @intCast(BinarySearch.binary_search_insert_index_with_transform(T, item, self.to_slice(), TX, transform_fn));
        }

        pub fn sorted_binary_search_insert_idx_for_item_with_transform_and_user_data(self: Self, item: T, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) Idx {
            return @intCast(BinarySearch.binary_search_insert_index_with_transform_and_user_data(T, item, self.to_slice(), TX, transform_fn, user_data));
        }
    };
}
