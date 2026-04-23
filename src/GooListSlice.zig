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
const Types = Root.Types;
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Nullability = CommonTypes.Nullability;
const NullPropagation = CommonTypes.NullPropagation;
const NullOperation = CommonTypes.NullOperation;
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
const MatchFunc = Utils.Mem.MatchFunc;
const MatchFuncUserdata = Utils.Mem.MatchFuncUserdata;
const LessThanFunc = Utils.Mem.LessThanFunc;
const LessThanFuncUserdata = Utils.Mem.LessThanFuncUserdata;

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

pub const GooListSliceMode = enum(u1) {
    SLICE,
    LIST,
};

pub const GooListSliceDefinition = struct {
    T: type,
    IDX: type = usize,
    ELEM_MUTABILITY: Mutability = .MUTABLE,
    PTR_NULLABILITY: Nullability = .NOT_NULLABLE,
    MODE: GooListSliceMode = .SLICE,
};

pub fn GooListSlice(comptime DEF: GooListSliceDefinition) type {
    if (@typeInfo(DEF.IDX) != .int) @compileError("type `Idx` must be an integer type");
    return extern struct {
        const Self = @This();
        pub const GOOLIB_TYPE_ID = Types.Id.get_type_id(Self);

        ptr: Ptr = INVALID_DATA_POINTER,
        len: Idx = 0,
        cap: if (IS_LIST) Idx else void = if (IS_LIST) 0 else void{},

        pub const T = DEF.T;
        pub const Idx = DEF.IDX;
        const ELEM_MUTABILITY = DEF.ELEM_MUTABILITY;
        const PTR_NULLABILITY = DEF.PTR_NULLABILITY;
        const MODE = DEF.MODE;
        const IS_LIST = MODE == .LIST;

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
            .MUTABLE => T,
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
        const INVALID_DATA_POINTER: Ptr = switch (PTR_NULLABILITY) {
            .NULLABLE => null,
            .NOT_NULLABLE => switch (ELEM_MUTABILITY) {
                .IMMUTABLE => Utils.invalid_ptr_many_const(T),
                .MUTABLE => Utils.invalid_ptr_many(T),
            },
        };
        const INVALID_ELEM_PTR = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => Utils.invalid_ptr_const(T),
            .MUTABLE => Utils.invalid_ptr(T),
        };

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

        pub fn is_null(self: Self) bool {
            if (NULLABLE) {
                return self.ptr == null;
            }
            return false;
        }

        pub fn is_empty(self: Self) bool {
            return self.len <= 0;
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

        pub fn find_item_idx_implicit(self: Self, find_val: anytype) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx);
        }

        pub fn find_item_ptr_implicit(self: Self, find_val: anytype) ?ElemPtr {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx);
            if (idx) |i| {
                return &self.ptr_never_null()[i];
            }
        }

        pub fn find_item_copy_implicit(self: Self, find_val: anytype) ?T {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx);
            if (idx) |i| {
                return self.ptr_never_null()[i];
            }
        }

        pub fn find_item_idx_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T)) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, Idx);
        }

        pub fn find_item_ptr_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T)) ?ElemPtr {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, usize);
            if (idx) |i| {
                return &self.ptr_never_null()[i];
            }
        }

        pub fn find_item_copy_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T)) ?T {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, usize);
            if (idx) |i| {
                return self.ptr_never_null()[i];
            }
        }

        pub fn find_item_idx_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, Idx);
        }

        pub fn find_item_ptr_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) ?ElemPtr {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, usize);
            if (idx) |i| {
                return &self.ptr_never_null()[i];
            }
        }

        pub fn find_item_copy_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) ?T {
            self.assert_not_null(@src());
            const idx = Utils.Mem.search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, usize);
            if (idx) |i| {
                return self.ptr_never_null()[i];
            }
        }

        pub const BinarySearchResult = Utils.Mem.BinarySerachResult(Idx);
        pub const BinarySearchResultWithPtr = struct {
            result: Utils.Mem.BinarySerachResult(Idx),
            ptr: ElemPtr = INVALID_ELEM_PTR,
        };
        pub const BinarySearchResultWithVal = struct {
            result: Utils.Mem.BinarySerachResult(Idx),
            val: T = undefined,
        };

        pub fn binary_search_item_idx_implicit(self: Self, find_val: anytype) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx);
        }

        pub fn binary_search_item_ptr_implicit(self: Self, find_val: anytype) BinarySearchResultWithPtr {
            self.assert_not_null(@src());
            var result_with_ptr = BinarySearchResultWithPtr{
                .result = Utils.Mem.binary_search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx),
            };
            if (result_with_ptr.result.result == .FOUND) {
                result_with_ptr.ptr = &self.ptr_never_null()[result_with_ptr.result.idx];
            }
            return result_with_ptr;
        }

        pub fn binary_search_item_copy_implicit(self: Self, find_val: anytype) BinarySearchResultWithVal {
            self.assert_not_null(@src());
            var result_with_val = BinarySearchResultWithVal{
                .result = Utils.Mem.binary_search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx),
            };
            if (result_with_val.result.result == .FOUND) {
                result_with_val.val = self.ptr_never_null()[result_with_val.result.idx];
            }
            return result_with_val;
        }

        pub fn binary_search_item_idx_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T), less_than_fn: *const LessThanFunc(@TypeOf(search_param), T)) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, less_than_fn, Idx);
        }

        pub fn binary_search_item_ptr_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T), less_than_fn: *const LessThanFunc(@TypeOf(search_param), T)) BinarySearchResultWithPtr {
            self.assert_not_null(@src());
            var result_with_ptr = BinarySearchResultWithPtr{
                .result = Utils.Mem.binary_search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, less_than_fn, Idx),
            };
            if (result_with_ptr.result.result == .FOUND) {
                result_with_ptr.ptr = &self.ptr_never_null()[result_with_ptr.result.idx];
            }
            return result_with_ptr;
        }

        pub fn binary_search_item_copy_with_func(self: Self, search_param: anytype, match_fn: *const MatchFunc(@TypeOf(search_param), T), less_than_fn: *const LessThanFunc(@TypeOf(search_param), T)) BinarySearchResultWithVal {
            self.assert_not_null(@src());
            var result_with_val = BinarySearchResultWithVal{
                .result = Utils.Mem.binary_search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, less_than_fn, Idx),
            };
            if (result_with_val.result.result == .FOUND) {
                result_with_val.val = self.ptr_never_null()[result_with_val.result.idx];
            }
            return result_with_val;
        }

        pub fn binary_search_item_idx_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata)), less_than_fn: *const LessThanFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, less_than_fn, Idx);
        }

        pub fn binary_search_item_ptr_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata)), less_than_fn: *const LessThanFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) BinarySearchResultWithPtr {
            self.assert_not_null(@src());
            var result_with_ptr = BinarySearchResultWithPtr{
                .result = Utils.Mem.binary_search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, less_than_fn, Idx),
            };
            if (result_with_ptr.result.result == .FOUND) {
                result_with_ptr.ptr = &self.ptr_never_null()[result_with_ptr.result.idx];
            }
            return result_with_ptr;
        }

        pub fn binary_search_item_copy_with_func_and_userdata(self: Self, search_param: anytype, userdata: anytype, match_fn: *const MatchFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata)), less_than_fn: *const LessThanFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) BinarySearchResultWithVal {
            self.assert_not_null(@src());
            var result_with_val = BinarySearchResultWithVal{
                .result = Utils.Mem.binary_search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, less_than_fn, Idx),
            };
            if (result_with_val.result.result == .FOUND) {
                result_with_val.val = self.ptr_never_null()[result_with_val.result.idx];
            }
            return result_with_val;
        }

        pub fn find_exactly_n_item_indexes_from_n_search_params_in_order(self: Self, search_params: anytype, match_fn: *const fn (search_param: Types.IndexableChild(@TypeOf(search_params)), item: T) bool, output_buf: []Idx) bool {
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
