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
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");
const build = @import("builtin");
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Nullability = CommonTypes.Nullability;
const Utils = Root.Utils;
const Assert = Root.Assert;
const u_secure_memset = Utils.secure_memset;
const u_secure_memset_const = Utils.secure_memset_const;
const u_secure_zero = Utils.secure_zero;
const u_secure_memset_undefined = Utils.secure_memset_undefined;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
// const InsertionSort = Root.InsertionSort;
// const BinarySearch = Root.BinarySearch;

const STRUCT_NAME = "GooSlice";
const ERR_CANNOT_INCREASE_START = "START_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase start address";
const ERR_CANNOT_DECREASE_START = "START_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease start address";
const ERR_CANNOT_INCREASE_END = "END_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase end address";
const ERR_CANNOT_DECREASE_END = "END_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease end address";
const ERR_CANNOT_GROW_LEN = "LEN_MUTABILITY != .grow_only or .shrink_or_grow, operation would grow length";
const ERR_CANNOT_SHRINK_LEN = "LEN_MUTABILITY != .shrink_only or .shrink_or_grow, operation would shrink length";
const ERR_OPERATE_IMMUTABLE_ELEM = STRUCT_NAME ++ "(ELEM_MUTABILITY = .immutable) attempted to change element value";
const ERR_OPERATE_NULL = "cannot operate on null ptr";
const ERR_SHRINK_OOB = "shrink count ({d}) would cause condition `first_address > last_address` (max shrink = len = {d})";
const ERR_START_END_REVERSED = "provided start ({d}) and end ({s}) indexes would cause condition `first_address > last_address`";
const ERR_INDEX_OOB = "the largest requested or provided index ({d}) is out of slice bounds (len = {d})";
const ERR_LEN_ZERO = "the slice length is zero, cannot index any element";
const ERR_IMMUTABLE = "the slice was declared immutable and its elements cannot be altered. if you absolutely need to mutate it, use `.change_mutablility(.MUTABLE)` or access the pointer manually with `@constCast()`";
const ERR_INDEX_CHUNK_OOB = "requested or provided start + count ({d} + {d} = {d}) would put the resulting sub-slice out of original bounds (len = {d})";
const ERR_SHIFT_OVERLAP = "a `shift({s}) -> @memcopy` operation isn't shifted far enough to guarantee no overlap (min_shift = len = {d})";

pub fn GooSlice(comptime T: type, comptime Idx: type, comptime ELEM_MUTABILITY: Mutability, comptime PTR_NULLABILITY: Nullability) type {
    if (@typeInfo(Idx) != .int) @compileError("type `Idx` must be an integer type");
    return extern struct {
        const Self = @This();

        ptr: Ptr = PTR_DEFAULT,
        len: Idx = 0,

        pub const Ptr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]const T,
                .NULLABLE => ?[*]const T,
            },
            .MUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]T,
                .NULLABLE => ?[*]T,
            },
        };
        pub const PtrNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]const T,
            .MUTABLE => [*]T,
        };
        pub const ElemPtr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => *const T,
            .MUTABLE => *T,
        };
        pub const ZigSlice = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => []const T,
                .NULLABLE => ?[]const T,
            },
            .MUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => []T,
                .NULLABLE => ?[]T,
            },
        };
        pub const ZigSliceNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => []const T,
            .MUTABLE => []T,
        };
        const MUTABLE = ELEM_MUTABILITY == .MUTABLE;
        const NULLABLE = PTR_NULLABILITY == .NULLABLE;
        const PTR_DEFAULT: Ptr = switch (PTR_NULLABILITY) {
            .NULLABLE => null,
            .NOT_NULLABLE => switch (ELEM_MUTABILITY) {
                .IMMUTABLE => Utils.invalid_ptr_many_const(T),
                .MUTABLE => Utils.invalid_ptr_many(T),
            },
        };

        pub fn is_empty(self: Self) bool {
            return self.len == 0;
        }
        pub fn is_null(self: Self) bool {
            if (NULLABLE) {
                return false;
            } else {
                return self.ptr == null;
            }
        }

        pub fn from_slice(slice: ZigSlice) Self {
            var out = Self{};
            if (NULLABLE and slice != null) {
                if (slice != null) {
                    out.ptr = slice.?.ptr;
                    out.len = @intCast(slice.?.len);
                }
            } else {
                out.ptr = slice.ptr;
                out.len = @intCast(slice.len);
            }
            return out;
        }

        pub fn to_slice(self: Self) ZigSlice {
            if (NULLABLE) {
                if (self.ptr == null) return null;
                return self.ptr_never_null()[0..self.len];
            } else {
                return self.ptr[0..self.len];
            }
        }
        pub fn to_slice_never_null(self: Self) ZigSliceNeverNull {
            self.assert_not_null(@src());
            self.ptr_never_null()[0..self.len];
        }

        pub fn change_mutability(self: Self, comptime new_elem_mutability: Mutability) GooSlice(T, Idx, new_elem_mutability, PTR_NULLABILITY) {
            if (new_elem_mutability == ELEM_MUTABILITY) return self;
            return GooSlice(T, Idx, new_elem_mutability, PTR_NULLABILITY){
                .ptr = if (new_elem_mutability == .MUTABLE) @constCast(self.ptr) else self.ptr,
                .len = self.len,
            };
        }
        pub fn change_nullability(self: Self, comptime new_ptr_nullability: Nullability) GooSlice(T, Idx, ELEM_MUTABILITY, new_ptr_nullability) {
            if (new_ptr_nullability == PTR_NULLABILITY) return self;
            return GooSlice(T, Idx, ELEM_MUTABILITY, new_ptr_nullability){
                .ptr = if (new_ptr_nullability == .NULLABLE) self.ptr else self.ptr_never_null(),
                .len = self.len,
            };
        }

        fn assert_not_null(self: Self, comptime src: std.builtin.SourceLocation) void {
            if (NULLABLE) {
                assert_with_reason(self.ptr != null, src, ERR_OPERATE_NULL, .{});
            }
        }
        fn assert_start_and_end_in_order(start: Idx, end: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(end >= start, src, ERR_START_END_REVERSED, .{ start, end });
        }
        fn assert_len_great_or_equal_count(self: Self, count: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(self.len >= count, src, ERR_SHRINK_OOB, .{ count, self.len });
        }
        fn assert_start_plus_len_in_range(self: Self, start: Idx, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(start + len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ start, len, start + len, self.len });
        }
        fn assert_len_in_range(self: Self, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ 0, len, len, self.len });
        }
        fn assert_len_in_range_from_end(self: Self, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ self.len - len, len, self.len, self.len });
        }
        fn assert_idx_in_range(self: Self, idx: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(idx < self.len, src, ERR_INDEX_OOB, .{ idx, self.len });
        }
        fn assert_len_non_zero(self: Self, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(self.len > 0, src, ERR_LEN_ZERO, .{});
        }
        fn assert_mutable(comptime src: std.builtin.SourceLocation) void {
            if (!MUTABLE) {
                assert_unreachable(src, ERR_IMMUTABLE, .{});
            }
        }

        pub fn new(ptr: Ptr, len: Idx) Self {
            return Self{ .ptr = ptr, .len = len };
        }
        pub fn new_with_start_and_end(root_ptr: Ptr, start: Idx, end_excluded: Idx) Self {
            assert_start_and_end_in_order(start, end_excluded, @src());
            return Self{ .ptr = root_ptr + start, .len = end_excluded - start };
        }

        pub fn ptr_never_null(self: Self) PtrNeverNull {
            self.assert_not_null(@src());
            if (NULLABLE) {
                return self.ptr.?;
            } else {
                return self.ptr;
            }
        }

        pub fn grow_right(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr, .len = self.len + count };
        }

        pub fn grow_left(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr_never_null() - count, .len = self.len + count };
        }

        pub fn shrink_right(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            self.assert_len_great_or_equal_count(count, @src());
            return Self{ .ptr = self.ptr, .len = self.len - count };
        }

        pub fn shrink_left(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            self.assert_len_great_or_equal_count(count, @src());
            return Self{ .ptr = self.ptr_never_null() + count, .len = self.len - count };
        }

        pub fn shift_right(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr_never_null() + count, .len = self.len };
        }

        pub fn shift_left(self: Self, count: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr_never_null() - count, .len = self.len };
        }

        pub fn sub_slice_start_len(self: Self, start: Idx, len: Idx) Self {
            self.assert_not_null(@src());
            self.assert_start_plus_len_in_range(start, len, @src());
            return Self{ .ptr = self.ptr_never_null() + start, .len = len };
        }

        pub fn sub_slice_start_end(self: Self, start: Idx, end_excluded: Idx) Self {
            self.assert_not_null(@src());
            assert_start_and_end_in_order(start, end_excluded, @src());
            const len = end_excluded - start;
            self.assert_start_plus_len_in_range(start, len, @src());
            return Self{ .ptr = self.ptr_never_null() + start, .len = len };
        }

        pub fn sub_slice_from_start(self: Self, len: Idx) Self {
            self.assert_not_null(@src());
            self.assert_len_in_range(len, @src());
            return Self{ .ptr = self.ptr, .len = len };
        }

        pub fn sub_slice_from_end(self: Self, len: Idx) Self {
            self.assert_not_null(@src());
            self.assert_len_in_range_from_end(len, @src());
            const diff = self.len - len;
            return Self{ .ptr = self.ptr_never_null() + diff, .len = len };
        }

        pub fn with_new_len(self: Self, new_len: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr, .len = new_len };
        }

        pub fn with_new_ptr(self: Self, new_ptr: Ptr) Self {
            return Self{ .ptr = new_ptr, .len = self.len };
        }

        pub fn new_slice_immediately_before(self: Self, len: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr_never_null() - len, .len = len };
        }

        pub fn new_slice_immediately_after(self: Self, len: Idx) Self {
            self.assert_not_null(@src());
            return Self{ .ptr = self.ptr_never_null() + self.len, .len = len };
        }

        pub fn get_item_ptr(self: Self, idx: Idx) ElemPtr {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            return &self.ptr_never_null()[idx];
        }

        pub fn get_last_item_ptr(self: Self) ElemPtr {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return &self.ptr_never_null()[self.len - 1];
        }

        pub fn get_first_item_ptr(self: Self) ElemPtr {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return &self.ptr_never_null()[0];
        }

        pub fn get_item_ptr_nth_from_end(self: Self, nth_from_end: Idx) ElemPtr {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            return &self.ptr_never_null()[self.len - 1 - nth_from_end];
        }

        pub fn get_item(self: Self, idx: Idx) T {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            return self.ptr_never_null()[idx];
        }

        pub fn get_last_item(self: Self) T {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return self.ptr_never_null()[self.len - 1];
        }

        pub fn get_first_item(self: Self) T {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return self.ptr_never_null()[0];
        }

        pub fn get_item_nth_from_end(self: Self, nth_from_end: Idx) T {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            return self.ptr_never_null()[self.len - 1 - nth_from_end];
        }

        pub fn set_item(self: Self, idx: Idx, val: T) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            assert_mutable(@src());
            self.ptr_never_null()[idx] = val;
        }

        pub fn set_last_item(self: Self, val: T) void {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            assert_mutable(@src());
            self.ptr_never_null()[self.len - 1] = val;
        }

        pub fn set_first_item(self: Self, val: T) void {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            assert_mutable(@src());
            self.ptr_never_null()[0] = val;
        }

        pub fn set_item_nth_from_end(self: Self, nth_from_end: Idx, val: T) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            assert_mutable(@src());
            self.ptr_never_null()[self.len - 1 - nth_from_end] = val;
        }

        pub fn memcopy_to(self: Self, dest: anytype) void {
            self.assert_not_null(@src());
            @memcpy(dest, self.to_slice_never_null());
        }

        pub fn memcopy_from(self: Self, source: anytype) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            @memcpy(self.to_slice_never_null(), source);
        }

        pub fn memset(self: Self, val: T) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            @memset(self.to_slice_never_null(), val);
        }

        pub fn secure_memset_zero(self: Self) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            u_secure_zero(T, self.to_slice_never_null());
        }

        pub fn secure_memset_undefined(self: Self) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            u_secure_memset_undefined(T, self.to_slice_never_null());
        }

        pub fn secure_memset(self: Self, val: T) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            u_secure_memset(T, self.to_slice_never_null(), val);
        }

        pub fn copy_rightward(self: Self, n_positions_to_the_right: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_right(n_positions_to_the_right);
            if (n_positions_to_the_right > self.len) {
                @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_slice.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_slice;
        }
        pub fn copy_rightward_never_overlaps(self: Self, n_positions_to_the_right: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_right(n_positions_to_the_right);
            @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }
        pub fn copy_rightward_always_overlaps(self: Self, n_positions_to_the_right: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_right(n_positions_to_the_right);
            @memmove(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }

        pub fn copy_leftward(self: Self, n_positions_to_the_left: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_left(n_positions_to_the_left);
            if (n_positions_to_the_left > self.len) {
                @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_slice.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_slice;
        }
        pub fn copy_leftward_never_overlaps(self: Self, n_positions_to_the_left: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_left(n_positions_to_the_left);
            @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }
        pub fn copy_leftward_always_overlaps(self: Self, n_positions_to_the_left: Idx) Self {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_left(n_positions_to_the_left);
            @memmove(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }

        pub fn swap(self: *Self, idx_a: Idx, idx_b: Idx) void {
            const a_val: T = self.get_item(idx_a);
            self.set_item(idx_a, self.get_item(idx_b));
            self.set_item(idx_b, a_val);
        }

        pub fn reverse(self: *Self) void {
            self.assert_not_null(@src());
            Utils.Mem.reverse_slice(self.to_slice_never_null());
        }
        //CHECKPOINT update mem manipulation funcs

        pub fn find_item_idx(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?Idx {
            Utils.mem
            self.assert_not_null(@src());
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(param, item)) return i;
            }
            return null;
        }

        pub fn find_item_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?*T {
            self.assert_not_null(@src());
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(param, item)) return item;
            }
            return null;
        }

        pub fn find_item_const_ptr(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?*const T {
            self.assert_not_null(@src());
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(param, item)) return item;
            }
            return null;
        }

        pub fn find_item_and_copy(self: Self, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const T) bool) ?T {
            self.assert_not_null(@src());
            var i: Idx = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(param, item)) return item.*;
            }
            return null;
        }

        pub fn find_exactly_n_item_indexes_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []Idx) bool {
            self.assert_not_null(@src());
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = i;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*T) bool {
            self.assert_not_null(@src());
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*const T) bool {
            self.assert_not_null(@src());
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn find_exactly_n_item_copies_from_n_params_in_order(self: Self, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const T) bool, output_buf: []*const T) bool {
            self.assert_not_null(@src());
            assert(output_buf.len >= params.len);
            var i: usize = 0;
            var o: usize = 0;
            while (i < self.len) : (i += 1) {
                const item: *const T = &(self.ptr_never_null()[@intCast(i)]);
                if (match_fn(params[o], item)) {
                    output_buf[o] = item.*;
                    o += 1;
                    if (o == params.len) return true;
                }
            }
            return false;
        }

        pub fn insertion_sort(self: *Self) void {
            self.assert_not_null(@src());
            InsertionSort.insertion_sort(T, self.ptr_never_null()[0..self.len]);
        }

        pub fn insertion_sort_with_transform(self: *Self, comptime TX: type, transform_fn: *const fn (item: T) TX) void {
            self.assert_not_null(@src());
            InsertionSort.insertion_sort_with_transform(T, self.ptr_never_null()[0..self.len], TX, transform_fn);
        }

        pub fn insertion_sort_with_transform_and_user_data(self: *Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) void {
            self.assert_not_null(@src());
            InsertionSort.insertion_sort_with_transform_and_user_data(T, self.ptr_never_null()[0..self.len], TX, transform_fn, user_data);
        }

        pub fn is_sorted(self: Self) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(self.ptr_never_null()[i], self.ptr_never_null()[i - 1])) return false;
            }
            return true;
        }

        pub fn is_sorted_with_transform(self: Self, comptime TX: type, transform_fn: *const fn (item: T) TX) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(transform_fn(self.ptr_never_null()[i]), transform_fn(self.ptr_never_null()[i - 1]))) return false;
            }
            return true;
        }

        pub fn is_sorted_with_transform_and_user_data(self: Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_less_than(transform_fn(self.ptr_never_null()[i], user_data), transform_fn(self.ptr_never_null()[i - 1], user_data))) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted(self: Self) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(self.ptr_never_null()[i], self.ptr_never_null()[i - 1])) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted_with_transform(self: Self, comptime TX: type, transform_fn: *const fn (item: T) TX) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(transform_fn(self.ptr_never_null()[i]), transform_fn(self.ptr_never_null()[i - 1]))) return false;
            }
            return true;
        }

        pub fn is_reverse_sorted_with_transform_and_user_data(self: Self, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) bool {
            self.assert_not_null(@src());
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                if (Utils.infered_greater_than(transform_fn(self.ptr_never_null()[i], user_data), transform_fn(self.ptr_never_null()[i - 1], user_data))) return false;
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
