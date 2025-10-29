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
const math = std.math;
const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const _Flags = Root.Flags;
const IteratorState = Root.IList_Iterator.IteratorState;

const Range = Root.IList.Range;
const ListError = Root.IList.ListError;
const CountResult = Root.IList.CountResult;
const CopyResult = Root.IList.CopyResult;
const Utils = Root.Utils;
const IList = Root.IList.IList;

pub fn ConcreteTableValueFuncs(comptime T: type, comptime LIST: type) type {
    return struct {
        get: fn (self: LIST, idx: usize, alloc: Allocator) T,
        get_ptr: fn (self: LIST, idx: usize, alloc: Allocator) *T,
        set: fn (self: LIST, idx: usize, val: T, alloc: Allocator) void,
        move: fn (self: LIST, old_idx: usize, new_idx: usize, alloc: Allocator) void,
        move_range: fn (self: LIST, range: Range, new_first_idx: usize, alloc: Allocator) void,
        try_ensure_free_slots: fn (self: LIST, count: usize, alloc: Allocator) bool,
        shrink_cap_reserve_at_most: fn (self: LIST, reserve_at_most: usize, alloc: Allocator) void,
        insert_slots_assume_capacity: fn (self: LIST, idx: usize, count: usize, alloc: Allocator) Range,
        append_slots_assume_capacity: fn (self: LIST, count: usize, alloc: Allocator) Range,
        delete_range: fn (self: LIST, range: Range, alloc: Allocator) void,
        clear: fn (self: LIST, alloc: Allocator) void,
        free: fn (self: LIST, alloc: Allocator) void,
    };
}

pub fn ConcreteTableIndexFuncs(comptime LIST: type) type {
    return struct {
        always_invalid_idx: fn (self: LIST) usize,
        len: fn (self: LIST) usize,
        cap: fn (self: LIST) usize,
        first_idx: fn (self: LIST) usize,
        last_idx: fn (self: LIST) usize,
        next_idx: fn (self: LIST, this_idx: usize) usize,
        nth_next_idx: fn (self: LIST, this_idx: usize, n: usize) usize,
        prev_idx: fn (self: LIST, this_idx: usize) usize,
        nth_prev_idx: fn (self: LIST, this_idx: usize, n: usize) usize,
        idx_valid: fn (self: LIST, idx: usize) bool,
        range_valid: fn (self: LIST, range: Range) bool,
        idx_in_range: fn (self: LIST, idx: usize, range: Range) bool,
        split_range: fn (self: LIST, range: Range) usize,
        range_len: fn (self: LIST, range: Range) usize,
    };
}

pub fn ConcreteTableIndexFuncsNaturalIndexes(comptime LIST: type, comptime LEN_FIELD: []const u8, comptime CAP_FIELD: []const u8) ConcreteTableIndexFuncs(LIST) {
    const PROTO = struct {
        fn always_invalid_idx(_: LIST) usize {
            return math.maxInt(usize);
        }
        fn len(self: LIST) usize {
            return @intCast(@field(self, LEN_FIELD));
        }
        fn cap(self: LIST) usize {
            return @intCast(@field(self, CAP_FIELD));
        }
        fn first_idx(_: LIST) usize {
            return 0;
        }
        fn last_idx(self: LIST) usize {
            return len(self) - 1;
        }
        fn next_idx(_: LIST, this_idx: usize) usize {
            return this_idx + 1;
        }
        fn nth_next_idx(_: LIST, this_idx: usize, n: usize) usize {
            return this_idx + n;
        }
        fn prev_idx(_: LIST, this_idx: usize) usize {
            return this_idx -% 1;
        }
        fn nth_prev_idx(_: LIST, this_idx: usize, n: usize) usize {
            return this_idx -% n;
        }
        fn idx_valid(self: LIST, idx: usize) bool {
            return idx < len(self);
        }
        fn range_valid(self: LIST, range: Range) bool {
            return range.first_idx <= range.last_idx and range.last_idx < len(self);
        }
        fn idx_in_range(_: LIST, range: Range, idx: usize) bool {
            return range.first_idx <= idx and idx <= range.last_idx;
        }
        fn split_range(_: LIST, range: Range) usize {
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn range_len(_: LIST, range: Range) usize {
            return (range.last_idx - range.first_idx) + 1;
        }
    };
    return ConcreteTableIndexFuncs(LIST){
        .always_invalid_idx = PROTO.always_invalid_idx,
        .len = PROTO.len,
        .cap = PROTO.cap,
        .first_idx = PROTO.first_idx,
        .last_idx = PROTO.last_idx,
        .next_idx = PROTO.next_idx,
        .nth_next_idx = PROTO.nth_next_idx,
        .prev_idx = PROTO.prev_idx,
        .nth_prev_idx = PROTO.nth_prev_idx,
        .idx_valid = PROTO.idx_valid,
        .range_valid = PROTO.range_valid,
        .idx_in_range = PROTO.idx_in_range,
        .split_range = PROTO.split_range,
        .range_len = PROTO.range_len,
    };
}

pub fn DefaultNativeRangeSlice(comptime T: type, comptime LIST: type, comptime PTR_FIELD: []const u8) fn (self: LIST, range: Range) []T {
    const PROTO = struct {
        fn native_slice(self: LIST, range: Range) []T {
            return @field(self, PTR_FIELD)[range.first_idx .. range.last_idx + 1];
        }
    };
    return PROTO.native_slice;
}

pub fn CreateConcretePrototype(comptime T: type, comptime LIST: type, comptime val_funcs: ConcreteTableValueFuncs(T, LIST), comptime idx_funcs: ConcreteTableIndexFuncs(LIST), comptime native_range_slice: ?fn (self: LIST, range: Range) []T) type {
    return struct {
        // Index funcs
        pub const always_invalid_idx = idx_funcs.always_invalid_idx;
        pub const len = idx_funcs.len;
        pub const cap = idx_funcs.cap;
        pub const first_idx = idx_funcs.first_idx;
        pub const last_idx = idx_funcs.last_idx;
        pub const next_idx = idx_funcs.next_idx;
        pub const nth_next_idx = idx_funcs.nth_next_idx;
        pub const prev_idx = idx_funcs.prev_idx;
        pub const nth_prev_idx = idx_funcs.nth_prev_idx;
        pub const idx_valid = idx_funcs.idx_valid;
        pub const range_valid = idx_funcs.range_valid;
        pub const idx_in_range = idx_funcs.idx_in_range;
        pub const split_range = idx_funcs.split_range;
        pub const range_len = idx_funcs.range_len;
        // Value funcs
        pub const get = val_funcs.get;
        pub const get_ptr = val_funcs.get_ptr;
        pub const set = val_funcs.set;
        pub const move = val_funcs.move;
        pub const move_range = val_funcs.move_range;
        pub const try_ensure_free_slots = val_funcs.try_ensure_free_slots;
        pub const shrink_cap_reserve_at_most = val_funcs.shrink_cap_reserve_at_most;
        pub const insert_slots_assume_capacity = val_funcs.insert_slots_assume_capacity;
        pub const append_slots_assume_capacity = val_funcs.append_slots_assume_capacity;
        pub const delete_range = val_funcs.delete_range;
        pub const clear = val_funcs.clear;
        pub const free = val_funcs.free;
        // Derived funcs
        pub fn is_empty(self: LIST) bool {
            return len(self) <= 0;
        }
        pub fn try_move(self: LIST, old_idx: usize, new_idx: usize, alloc: Allocator) ListError!void {
            if (!idx_valid(old_idx) or !idx_valid(self, self, new_idx)) {
                return ListError.invalid_index;
            }
            move(self, old_idx, new_idx, alloc);
        }
        pub fn try_move_range(self: LIST, range: Range, new_first_idx: usize, alloc: Allocator) ListError!void {
            if (!range_valid(self, range)) {
                return ListError.invalid_range;
            }
            if (!idx_valid(new_first_idx)) {
                return ListError.invalid_index;
            }
            const between = range_len(self, range);
            const new_last_idx = nth_next_idx(self, new_first_idx, between - 1);
            if (!idx_valid(self, new_last_idx)) {
                return ListError.index_out_of_bounds;
            }
            move_range(self, range, new_first_idx, alloc);
        }
        pub fn try_get(self: LIST, idx: usize, alloc: Allocator) ListError!T {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_index;
            }
            return get(self, idx, alloc);
        }

        pub fn try_get_ptr(self: LIST, idx: usize, alloc: Allocator) ListError!*T {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_index;
            }
            return get_ptr(self, idx, alloc);
        }

        pub fn try_set(self: LIST, idx: usize, val: T, alloc: Allocator) ListError!void {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_index;
            }
            set(self, idx, val, alloc);
        }

        pub fn try_first_idx(self: LIST) ListError!usize {
            const idx = first_idx(self);
            if (!idx_valid(self, idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }

        pub fn try_last_idx(self: LIST) ListError!usize {
            const idx = last_idx(self);
            if (!idx_valid(self, idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }
        pub fn try_next_idx(self: LIST, this_idx: usize) ListError!usize {
            if (!idx_valid(self, this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = next_idx(self, this_idx);
            if (!idx_valid(self, next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_nth_next_idx(self: LIST, this_idx: usize, n: usize) ListError!usize {
            if (!idx_valid(self, this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = nth_next_idx(self, this_idx, n);
            if (!idx_valid(self, next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_prev_idx(self: LIST, this_idx: usize) ListError!usize {
            if (!idx_valid(self, this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = prev_idx(self, this_idx);
            if (!idx_valid(self, prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn try_nth_prev_idx(self: LIST, this_idx: usize, n: usize) ListError!usize {
            if (!idx_valid(self, this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = nth_prev_idx(self, this_idx, n);
            if (!idx_valid(self, prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn nth_idx(self: LIST, n: usize) usize {
            var idx = first_idx(self);
            idx = nth_next_idx(self, idx, n);
            return idx;
        }
        pub fn try_nth_idx(self: LIST, n: usize) ListError!usize {
            var idx = first_idx(self);
            if (!idx_valid(self, idx)) {
                return ListError.list_is_empty;
            }
            idx = nth_next_idx(self, idx, n);
            if (!idx_valid(self, idx)) {
                return ListError.index_out_of_bounds;
            }
            return idx;
        }
        pub fn nth_idx_from_end(self: LIST, n: usize) usize {
            var idx = last_idx(self);
            idx = nth_prev_idx(self, idx, n);
            return idx;
        }
        pub fn try_nth_idx_from_end(self: LIST, n: usize) ListError!usize {
            var idx = last_idx(self);
            if (!idx_valid(self, idx)) {
                return ListError.list_is_empty;
            }
            idx = nth_prev_idx(self, idx, n);
            if (!idx_valid(self, idx)) {
                return ListError.index_out_of_bounds;
            }
            return idx;
        }
        pub fn get_last(self: LIST, alloc: Allocator) T {
            const idx = last_idx(self);
            return get(self, idx, alloc);
        }
        pub fn try_get_last(self: LIST, alloc: Allocator) ListError!T {
            const idx = try try_last_idx(self);
            return get(self, idx, alloc);
        }
        pub fn get_last_ptr(self: LIST, alloc: Allocator) *T {
            const idx = last_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_last_ptr(self: LIST, alloc: Allocator) ListError!*T {
            const idx = try try_last_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_last(self: LIST, val: T, alloc: Allocator) void {
            const idx = last_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_last(self: LIST, val: T, alloc: Allocator) ListError!void {
            const idx = try try_last_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn get_first(self: LIST, alloc: Allocator) T {
            const idx = first_idx(self);
            return get(self, idx, alloc);
        }
        pub fn try_get_first(self: LIST, alloc: Allocator) ListError!T {
            const idx = try try_first_idx(self);
            return get(self, idx, alloc);
        }
        pub fn get_first_ptr(self: LIST, alloc: Allocator) *T {
            const idx = first_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_first_ptr(self: LIST, alloc: Allocator) ListError!*T {
            const idx = try try_first_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_first(self: LIST, val: T, alloc: Allocator) void {
            const idx = first_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_first(self: LIST, val: T, alloc: Allocator) ListError!void {
            const idx = try try_first_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn get_nth(self: LIST, n: usize, alloc: Allocator) T {
            const idx = nth_idx(self, n);
            return get(self, idx, alloc);
        }
        pub fn try_get_nth(self: LIST, n: usize, alloc: Allocator) ListError!T {
            const idx = try try_nth_idx(self, n);
            return get(self, idx, alloc);
        }
        pub fn get_nth_ptr(self: LIST, n: usize, alloc: Allocator) *T {
            const idx = nth_idx(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_nth_ptr(self: LIST, n: usize, alloc: Allocator) ListError!*T {
            const idx = try try_nth_idx(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_nth(self: LIST, n: usize, val: T, alloc: Allocator) void {
            const idx = nth_idx(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_nth(self: LIST, n: usize, val: T, alloc: Allocator) ListError!void {
            const idx = try try_nth_idx(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn set_from(self: LIST, self_idx: usize, source: LIST, source_idx: usize, alloc: Allocator) void {
            const val = source.get(source_idx);
            set(self, self_idx, val, alloc);
        }
        pub fn try_set_from(self: LIST, self_idx: usize, source: LIST, source_idx: usize, alloc: Allocator) ListError!void {
            const val = try source.try_get(source_idx);
            return try_set(self, self_idx, val, alloc);
        }
        pub fn swap(self: LIST, idx_a: usize, idx_b: usize, alloc: Allocator) void {
            const val_a = get(self, idx_a, alloc);
            const val_b = get(self, idx_b, alloc);
            set(self, idx_a, val_b, alloc);
            set(self, idx_b, val_a, alloc);
        }
        pub fn try_swap(self: LIST, idx_a: usize, idx_b: usize, alloc: Allocator) ListError!void {
            const val_a = try try_get(self, idx_a, alloc);
            const val_b = try try_get(self, idx_b, alloc);
            set(self, idx_a, val_b, alloc);
            set(self, idx_b, val_a, alloc);
        }
        pub fn exchange(self: LIST, self_idx: usize, self_alloc: Allocator, other: LIST, other_idx: usize, other_alloc: Allocator) void {
            const val_self = get(self, self_idx, self_alloc);
            const val_other = get(other, other_idx, other_alloc);
            set(self, self_idx, val_other, self_alloc);
            set(other, other_idx, val_self, other_alloc);
        }
        pub fn try_exchange(self: LIST, self_idx: usize, self_alloc: Allocator, other: LIST, other_idx: usize, other_alloc: Allocator) ListError!void {
            const val_self = try try_get(self, self_idx, self_alloc);
            const val_other = try try_get(other, other_idx, other_alloc);
            set(self, self_idx, val_other);
            set(other, other_idx, val_self);
        }
        pub fn overwrite(self: LIST, source_idx: usize, dest_idx: usize, alloc: Allocator) void {
            const val = get(self, source_idx, alloc);
            set(self, dest_idx, val, alloc);
        }
        pub fn try_overwrite(self: LIST, source_idx: usize, dest_idx: usize, alloc: Allocator) ListError!void {
            const val = try try_get(self, source_idx, alloc);
            set(self, dest_idx, val, alloc);
        }
        pub fn reverse(self: LIST, range: PartialRangeIter, alloc: Allocator) void {
            const range_iter = range.to_iter(self);
            if (native_range_slice) |slice_fn| {
                const slice = slice_fn(self, range_iter.range);
                std.mem.reverse(T, slice);
            } else {
                var left = range_iter.range.first_idx;
                var right = range_iter.range.last_idx;
                if (left == right or !idx_valid(self, left) or !idx_valid(self, right)) {
                    return;
                }
                while (true) {
                    swap(self, left, right, alloc);
                    left = next_idx(self, left);
                    if (left == right) {
                        return;
                    }
                    right = prev_idx(self, right);
                    if (left == right) {
                        return;
                    }
                }
            }
        }

        pub fn rotate(self: LIST, range: PartialRangeIter, delta: isize, alloc: Allocator) void {
            const riter = range.to_iter(self);
            const rlen = range_len(self, riter.range);
            const delta_mod = math.mod(isize, delta, @intCast(rlen)) catch unreachable;
            if (delta_mod == 0) return;
            const new_first_idx = nth_next_idx(self, riter.range.first_idx, @intCast(delta_mod));
            move_range(self, riter.range, new_first_idx, alloc);
        }

        pub fn fill(self: LIST, range: PartialRangeIter, val: T, alloc: Allocator) usize {
            var iter = range.to_iter(self);
            if (native_range_slice) |slice_fn| {
                var slice = slice_fn(self, iter.range);
                if (iter.use_max) {
                    const max_len = @min(slice.len, iter.max_count);
                    if (iter.forward) {
                        slice = slice[0..max_len];
                    } else {
                        slice = slice[slice.len - max_len .. slice.len];
                    }
                }
                @memset(slice, val);
                return slice.len;
            } else {
                while (iter.next_index()) |idx| {
                    set(self, idx, val, alloc);
                }
                return iter.count;
            }
        }

        pub fn copy_to(source: LIST, source_range: PartialRangeIter, source_alloc: Allocator, dest: RangeIter, dest_alloc: Allocator) usize {
            var source_iter = source_range.to_iter(source);
            var dest_iter = dest;
            if (native_range_slice) |slice_fn| {
                var src_slice = slice_fn(source, source_iter.range);
                var dst_slice = slice_fn(dest.list, dest_iter.range);
                var max_src_len = src_slice.len;
                var max_dst_len = dst_slice.len;
                if (source_iter.use_max) {
                    max_src_len = @min(max_src_len, source_iter.max_count);
                }
                if (dest_iter.use_max) {
                    max_dst_len = @min(max_dst_len, dest_iter.max_count);
                }
                const true_max = @min(max_src_len, max_dst_len);
                if (source_iter.forward) {
                    src_slice = src_slice[0..true_max];
                } else {
                    src_slice = src_slice[src_slice.len - true_max .. src_slice.len];
                }
                if (dest_iter.forward) {
                    dst_slice = dst_slice[0..true_max];
                } else {
                    dst_slice = dst_slice[dst_slice.len - true_max .. dst_slice.len];
                }
                if (Utils.slices_overlap(T, src_slice, dst_slice)) {
                    @memmove(dst_slice, src_slice);
                    if (source_iter.forward != dest_iter.forward) {
                        std.mem.reverse(T, dst_slice);
                    }
                } else {
                    if (source_iter.forward != dest_iter.forward) {
                        const last_dst = dst_slice.len - 1;
                        for (0..true_max) |i| {
                            dst_slice[last_dst - i] = src_slice[i];
                        }
                    } else {
                        @memcpy(dst_slice, src_slice);
                    }
                }
                return true_max;
            } else {
                while (source_iter.peek_next_index()) |src_idx| {
                    if (dest_iter.peek_next_index()) |dst_idx| {
                        const val = get(source, src_idx, source_alloc);
                        set(dest.list, dst_idx, val, dest_alloc);
                        source_iter.commit_peeked(src_idx);
                        dest_iter.commit_peeked(dst_idx);
                    } else break;
                }
                return source_iter.count;
            }
        }

        fn _implicit_eq(left: T, right: T) bool {
            return left == right;
        }
        fn _implicit_gt(left: T, right: T) bool {
            return left > right;
        }
        fn _implicit_lt(left: T, right: T) bool {
            return left < right;
        }
        pub const CompareFunc = fn (left_or_this: T, right_or_test: T) bool;

        pub fn is_sorted(self: LIST, range: PartialRangeIter, greater_than: *const CompareFunc, alloc: Allocator) bool {
            const range_iter = range.to_iter(self);
            const real_range = range_iter.range;
            if (range_len(self, real_range) < 2) return true;
            var i: usize = undefined;
            var ii: usize = undefined;
            var left: T = undefined;
            var right: T = undefined;
            i = real_range.first_idx;
            var more = idx_valid(self, i);
            if (!more) {
                return true;
            }
            ii = next_idx(self, i);
            more = idx_valid(self, ii);
            if (!more) {
                return true;
            }
            left = get(self, i, alloc);
            right = get(self, ii, alloc);
            while (more) {
                if (greater_than(left, right)) {
                    return false;
                }
                more = i != real_range.last_idx;
                i = ii;
                ii = next_idx(self, ii);
                more = more and idx_valid(self, ii);
                if (more) {
                    left = right;
                    right = get(self, ii, alloc);
                }
            }
            return true;
        }

        pub fn is_sorted_implicit(self: LIST, range: PartialRangeIter, alloc: Allocator) bool {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "is_sorted_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            return is_sorted(self, range, _implicit_gt, alloc);
        }

        pub fn insertion_sort(self: LIST, range: PartialRangeIter, greater_than: *const CompareFunc, alloc: Allocator) void {
            const range_iter = range.to_iter(self);
            const real_range = range_iter.range;
            var ok: bool = undefined;
            var i: usize = undefined;
            var j: usize = undefined;
            var jj: usize = undefined;
            var move_val: T = undefined;
            var test_val: T = undefined;

            i = real_range.first_idx;
            ok = idx_valid(self, i);
            if (!ok) {
                return;
            }
            i = next_idx(self, i);
            ok = idx_valid(self, i);
            if (!ok) {
                return;
            }
            while (ok) {
                move_val = get(self, i, alloc);
                j = prev_idx(self, i);
                ok = idx_valid(self, j);
                if (ok) {
                    jj = i;
                    test_val = get(self, j, alloc);
                    while (ok and greater_than(test_val, move_val)) {
                        overwrite(self, j, jj, alloc);
                        ok = j != real_range.first_idx;
                        jj = j;
                        j = prev_idx(self, j);
                        ok = ok and idx_valid(self, j);
                        if (ok) {
                            test_val = get(self, j, alloc);
                        }
                    }
                }
                set(self, jj, move_val, alloc);
                ok = i != real_range.last_idx;
                i = next_idx(self, i);
                ok = ok and idx_valid(self, i);
            }
        }

        pub fn insertion_sort_implicit(self: LIST, alloc: Allocator) void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.insertion_sort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            insertion_sort(self, _implicit_gt, alloc);
        }

        pub fn quicksort(self: LIST, range: PartialRangeIter, self_alloc: Allocator, greater_than: *const CompareFunc, less_than: *const CompareFunc, partition_stack: IList(usize)) ListError!void {
            const range_iter = range.to_iter(self);
            const real_range = range_iter.range;
            const rlen = range_len(self, real_range);
            if (rlen < 2) {
                return;
            }
            if (rlen <= 8) {
                insertion_sort(self, range, greater_than, self_alloc);
                return;
            }
            var hi: usize = undefined;
            var lo: usize = undefined;
            var mid: Range = undefined;
            var rng: Range = undefined;
            lo = real_range.first_idx;
            hi = real_range.last_idx;
            partition_stack.clear();
            try partition_stack.try_ensure_free_slots(2);
            partition_stack.append_slots_assume_capacity(2);
            partition_stack.set(rng.first_idx, lo);
            partition_stack.set(rng.last_idx, hi);
            while (partition_stack.len() >= 2) {
                hi = partition_stack.pop();
                lo = partition_stack.pop();
                if (hi == lo or hi == prev_idx(self, lo) or lo == next_idx(self, hi)) {
                    continue;
                }
                mid = _quicksort_partition(self, greater_than, less_than, lo, hi);
                try partition_stack.try_ensure_free_slots(4);
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.first_idx, lo);
                partition_stack.set(rng.first_idx, prev_idx(self, mid.first_idx));
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.last_idx, next_idx(self, mid.last_idx));
                partition_stack.set(rng.last_idx, hi);
            }
        }
        pub fn quicksort_implicit(self: LIST, range: PartialRangeIter, self_alloc: Allocator, partition_stack: IList(usize)) ListError!void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.quicksort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            quicksort(self, range, self_alloc, _implicit_gt, _implicit_lt, partition_stack);
        }
        fn _quicksort_partition(self: LIST, self_alloc: Allocator, greater_than: *const CompareFunc, less_than: *const CompareFunc, lo: usize, hi: usize) Range {
            const pivot_idx: usize = lo;
            const pivot_val = get(self, pivot_idx, self_alloc);
            var less_idx: usize = lo;
            var equal_idx: usize = lo;
            var more_idx: usize = hi;
            var cont: bool = equal_idx != more_idx;
            while (cont) {
                const eq_val: T = get(self, equal_idx, self_alloc);
                if (less_than(eq_val, pivot_val)) {
                    swap(self, equal_idx, less_idx, self_alloc);
                    less_idx = prev_idx(self, less_idx);
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = next_idx(self, equal_idx);
                } else if (greater_than(eq_val, pivot_val)) {
                    swap(self, equal_idx, more_idx, self_alloc);
                    if (equal_idx == more_idx) {
                        cont = false;
                    }
                    more_idx = prev_idx(self, more_idx);
                } else {
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = next_idx(self, equal_idx);
                }
            }
            return Range.new_range(less_idx, more_idx);
        }

        const RANGE_OVERWRITE = enum {
            none,
            first_idx,
            last_idx,
            nth_from_start,
            nth_from_end,
            nth_from_first,
            nth_from_last,
        };

        const IterState = enum(u8) {
            CONSUMED,
            UNCONSUMED,
        };

        pub const PartialRangeIter = struct {
            alloc: Allocator = Root.DummyAllocator.allocator,
            range: Range,
            overwrite_first: RANGE_OVERWRITE = .none,
            overwrite_last: RANGE_OVERWRITE = .none,
            want_count: usize = std.math.maxInt(usize),
            use_max: bool = false,
            forward: bool = true,

            pub fn with_max_count(self: PartialRangeIter, max_count: usize) PartialRangeIter {
                const iter = self;
                self.max_count = max_count;
                self.use_max = true;
                return iter;
            }

            pub fn in_reverse(self: PartialRangeIter) PartialRangeIter {
                const iter = self;
                self.forward = false;
                return iter;
            }

            pub fn with_allocator(self: PartialRangeIter, alloc: Allocator) PartialRangeIter {
                const iter = self;
                self.alloc = alloc;
                return iter;
            }

            pub fn one_index(idx: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = Range.single_idx(idx),
                };
            }
            pub fn new_range(first: usize, last: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(first, last),
                };
            }
            pub fn new_range_max_count(first: usize, last: usize, max_count: usize) PartialRangeIter {
                return new_range(first, last).with_max_count(max_count);
            }
            pub fn use_range(range: Range) PartialRangeIter {
                return PartialRangeIter{
                    .range = range,
                };
            }
            pub fn use_range_max_count(range: Range, max_count: usize) PartialRangeIter {
                return use_range(range).with_max_count(max_count);
            }
            pub fn entire_list() PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(0, 0),
                    .overwrite_first = .first_idx,
                    .overwrite_last = .last_idx,
                };
            }
            pub fn entire_list_max_count(max_count: usize) PartialRangeIter {
                return entire_list().with_max_count(max_count);
            }
            pub fn first_n_items(count: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(0, count - 1),
                    .overwrite_first = .first_idx,
                    .overwrite_last = .nth_from_start,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn last_n_items(count: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(count - 1, 0),
                    .overwrite_first = .nth_from_end,
                    .overwrite_last = .last_idx,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn begin_at_idx_count_total(idx: usize, count: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(idx, count - 1),
                    .overwrite_last = .nth_from_first,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn end_at_idx_count_total(idx: usize, count: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(count - 1, idx),
                    .overwrite_first = .nth_from_last,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn start_to_idx(last: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(0, last),
                    .overwrite_first = .first_idx,
                };
            }
            pub fn start_to_idx_max_count(last: usize, max_count: usize) PartialRangeIter {
                return start_to_idx(last).with_max_count(max_count);
            }
            pub fn idx_to_end(first: usize) PartialRangeIter {
                return PartialRangeIter{
                    .range = .new_range(first, 0),
                    .overwrite_last = .last_idx,
                };
            }
            pub fn idx_to_end_max_count(first: usize, max_count: usize) PartialRangeIter {
                return idx_to_end(first).with_max_count(max_count);
            }
            pub fn one_index_rev(idx: usize) PartialRangeIter {
                return one_index(idx).in_reverse();
            }
            pub fn new_range_rev(first: usize, last: usize) PartialRangeIter {
                return new_range(first, last).in_reverse();
            }
            pub fn new_range_max_count_rev(first: usize, last: usize, max_count: usize) PartialRangeIter {
                return new_range_max_count(first, last, max_count).in_reverse();
            }
            pub fn use_range_rev(range: Range) PartialRangeIter {
                return use_range(range).in_reverse();
            }
            pub fn use_range_max_count_rev(range: Range, max_count: usize) PartialRangeIter {
                return use_range_max_count(range, max_count).in_reverse();
            }
            pub fn entire_list_rev() PartialRangeIter {
                return entire_list().in_reverse();
            }
            pub fn entire_list_max_count_rev(max_count: usize) PartialRangeIter {
                return entire_list_max_count(max_count).in_reverse();
            }
            pub fn first_n_items_rev(count: usize) PartialRangeIter {
                return first_n_items(count).in_reverse();
            }
            pub fn last_n_items_rev(count: usize) PartialRangeIter {
                return last_n_items(count).in_reverse();
            }
            pub fn begin_at_idx_count_total_rev(idx: usize, count: usize) PartialRangeIter {
                return begin_at_idx_count_total(idx, count).in_reverse();
            }
            pub fn end_at_idx_count_total_rev(idx: usize, count: usize) PartialRangeIter {
                return end_at_idx_count_total(idx, count).in_reverse();
            }
            pub fn start_to_idx_rev(last: usize) PartialRangeIter {
                return start_to_idx(last).in_reverse();
            }
            pub fn start_to_idx_max_count_rev(last: usize, max_count: usize) PartialRangeIter {
                return start_to_idx_max_count(last, max_count).in_reverse();
            }
            pub fn idx_to_end_rev(first: usize) PartialRangeIter {
                return idx_to_end_rev(first).in_reverse();
            }
            pub fn idx_to_end_max_count_rev(first: usize, max_count: usize) PartialRangeIter {
                return idx_to_end_max_count(first, max_count).in_reverse();
            }

            pub fn to_iter(self: PartialRangeIter, list: LIST) RangeIter {
                var iter = RangeIter{
                    .list = list,
                    .alloc = self.alloc,
                    .range = self.range,
                    .max_count = self.want_count,
                    .use_max = self.use_max,
                    .forward = self.forward,
                };
                const rng = self.range;
                switch (self.overwrite_first) {
                    .none => {},
                    .first_idx => {
                        iter.range.first_idx = first_idx(list);
                    },
                    .last_idx => {
                        iter.range.first_idx = last_idx(list);
                    },
                    .nth_from_start => {
                        iter.range.first_idx = nth_idx(list, rng.first_idx);
                    },
                    .nth_from_end => {
                        iter.range.first_idx = nth_idx_from_end(list, rng.first_idx);
                    },
                    .nth_from_first => unreachable,
                    .nth_from_last => {
                        iter.range.first_idx = nth_prev_idx(list, rng.last_idx, rng.first_idx);
                    },
                }
                switch (self.overwrite_last) {
                    .none => {},
                    .first_idx => {
                        iter.range.last_idx = first_idx(list);
                    },
                    .last_idx => {
                        iter.range.last_idx = last_idx(list);
                    },
                    .nth_from_start => {
                        iter.range.last_idx = nth_idx(list, rng.last_idx);
                    },
                    .nth_from_end => {
                        iter.range.last_idx = nth_idx_from_end(list, rng.last_idx);
                    },
                    .nth_from_first => {
                        iter.range.last_idx = nth_next_idx(list, rng.first_idx, rng.last_idx);
                    },
                    .nth_from_last => unreachable,
                }
                if (self.forward) {
                    iter.curr = iter.range.first_idx;
                } else {
                    iter.curr = iter.range.last_idx;
                }
                return iter;
            }
        };

        pub const RangeIter = struct {
            list: LIST,
            alloc: Allocator = Root.DummyAllocator.allocator,
            range: Range,
            curr: usize,
            state: IterState = .UNCONSUMED,
            count: usize = 0,
            max_count: usize = std.math.maxInt(usize),
            use_max: bool = false,
            forward: bool = true,

            pub fn peek_next_index(self: *RangeIter) ?usize {
                if (self.use_max and self.count == self.max_count) return null;
                switch (self.state) {
                    .CONSUMED => {
                        @branchHint(.likely);
                        switch (self.forward) {
                            true => {
                                if (self.curr == self.range.last_idx) return null;
                                const next_idx_ = next_idx(self.list, self.curr);
                                if (!idx_valid(self.list, next_idx_)) return null;
                                return next_idx_;
                            },
                            false => {
                                if (self.curr == self.range.first_idx) return null;
                                const prev_idx_ = prev_idx(self.list, self.curr);
                                if (!idx_valid(self.list, prev_idx_)) return null;
                                return prev_idx_;
                            },
                        }
                    },
                    .UNCONSUMED => {
                        @branchHint(.unlikely);
                        if (!idx_valid(self.list, self.curr)) return null;
                        return self.curr;
                    },
                }
            }

            pub fn commit_peeked(self: *RangeIter, peeked_idx: usize) void {
                if (self.state == .UNCONSUMED) {
                    @branchHint(.unlikely);
                    self.state = .CONSUMED;
                }
                self.count += 1;
                self.curr = peeked_idx;
            }

            pub fn next_index(self: *RangeIter) ?usize {
                if (self.use_max and self.count == self.max_count) return null;
                self.count += 1;
                switch (self.state) {
                    .CONSUMED => {
                        @branchHint(.likely);
                        switch (self.forward) {
                            true => {
                                if (self.curr == self.range.last_idx) return null;
                                const next_idx_ = next_idx(self.list, self.curr);
                                if (!idx_valid(self.list, next_idx_)) return null;
                                self.curr = next_idx_;
                                return next_idx_;
                            },
                            false => {
                                if (self.curr == self.range.first_idx) return null;
                                const prev_idx_ = prev_idx(self.list, self.curr);
                                if (!idx_valid(self.list, prev_idx_)) return null;
                                self.curr = prev_idx_;
                                return prev_idx_;
                            },
                        }
                    },
                    .UNCONSUMED => {
                        @branchHint(.unlikely);
                        if (!idx_valid(self.list, self.curr)) return null;
                        self.state = .CONSUMED;
                        return self.curr;
                    },
                }
            }

            pub fn next_value(self: *RangeIter) ?T {
                if (self.next_index()) |idx| {
                    return get(self.list, idx, self.alloc);
                }
                return null;
            }

            pub fn peek_prev_index(self: *RangeIter) ?usize {
                if (self.use_max and self.count == self.max_count) return null;
                Assert.assert_with_reason(self.state == .CONSUMED, @src(), "cannot call peek_prev_index() when next_index() (or peek_next_index() and commit_peeked()) has never been called. If you wanted to iterate in reverse, use one of the reverse constructors instead and call next_index()", .{});
                switch (self.forward) {
                    true => {
                        if (self.curr == self.range.first_idx) return null;
                        const prev_idx_ = prev_idx(self.list, self.curr);
                        if (!idx_valid(self.list, prev_idx_)) return null;
                        return prev_idx_;
                    },
                    false => {
                        if (self.curr == self.range.last_idx) return null;
                        const next_idx_ = next_idx(self.list, self.curr);
                        if (!idx_valid(self.list, next_idx_)) return null;
                        return next_idx_;
                    },
                }
            }

            pub fn prev_index(self: *RangeIter) ?usize {
                if (self.use_max and self.count == self.max_count) return null;
                Assert.assert_with_reason(self.state == .CONSUMED, @src(), "cannot call prev_index() when next_index() (or peek_next_index() and commit_peeked()) has never been called. If you wanted to iterate in reverse, use one of the reverse constructors instead and call next_index()", .{});
                self.count += 1;
                switch (self.forward) {
                    true => {
                        if (self.curr == self.range.first_idx) return null;
                        const prev_idx_ = prev_idx(self.list, self.curr);
                        if (!idx_valid(self.list, prev_idx_)) return null;
                        self.curr = prev_idx_;
                        return prev_idx_;
                    },
                    false => {
                        if (self.curr == self.range.last_idx) return null;
                        const next_idx_ = next_idx(self.list, self.curr);
                        if (!idx_valid(self.list, next_idx_)) return null;
                        self.curr = next_idx_;
                        return next_idx_;
                    },
                }
            }

            pub fn prev_value(self: *RangeIter) ?T {
                if (self.prev_index()) |idx| {
                    return get(self.list, idx, self.alloc);
                }
                return null;
            }

            pub fn with_max_count(self: RangeIter, max_count: usize) RangeIter {
                const iter = self;
                self.max_count = max_count;
                self.use_max = true;
                return iter;
            }

            pub fn in_reverse(self: RangeIter) RangeIter {
                const iter = self;
                iter.curr = self.range.last_idx;
                iter.forward = false;
                return iter;
            }

            pub fn with_alloc(self: RangeIter, alloc: Allocator) RangeIter {
                const iter = self;
                self.alloc = alloc;
                return iter;
            }

            pub fn one_index(list: LIST, idx: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .single_idx(idx),
                    .curr = idx,
                };
            }
            pub fn new_range(list: LIST, first: usize, last: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(first, last),
                    .curr = first,
                };
            }
            pub fn new_range_max_count(list: LIST, first: usize, last: usize, max_count: usize) RangeIter {
                return new_range(list, first, last).with_max_count(max_count);
            }
            pub fn use_range(list: LIST, range: Range) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = range,
                    .curr = range.first_idx,
                };
            }
            pub fn use_range_max_count(list: LIST, range: Range, max_count: usize) RangeIter {
                return use_range(list, range).with_max_count(max_count);
            }
            pub fn entire_list(list: LIST) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(first_idx(list), last_idx(list)),
                    .curr = first_idx(list),
                };
            }
            pub fn entire_list_max_count(list: LIST, max_count: usize) RangeIter {
                return entire_list(list).with_max_count(max_count);
            }
            pub fn first_n_items(list: LIST, count: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(first_idx(list), nth_idx(list, count - 1)),
                    .curr = first_idx(list),
                    .max_count = count,
                    .use_max = true,
                };
            }
            pub fn last_n_items(list: LIST, count: usize) RangeIter {
                const idx = nth_idx_from_end(list, count - 1);
                return RangeIter{
                    .list = list,
                    .range = .new_range(idx, list.last_idx()),
                    .curr = idx,
                    .max_count = count,
                    .use_max = true,
                };
            }
            pub fn start_idx_count_total(list: LIST, idx: usize, count: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(idx, nth_next_idx(list, count - 1)),
                    .curr = idx,
                    .max_count = count,
                    .use_count = true,
                };
            }
            pub fn end_idx_count_total(list: LIST, idx: usize, count: usize) RangeIter {
                const fidx = nth_prev_idx(list, idx, count - 1);
                return RangeIter{
                    .list = list,
                    .range = .new_range(fidx, idx),
                    .curr = fidx,
                    .max_count = count,
                    .use_count = true,
                };
            }
            pub fn start_to_idx(list: LIST, last: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(first_idx(list), last),
                    .curr = first_idx(list),
                };
            }
            pub fn start_to_idx_max_count(list: LIST, last: usize, max_count: usize) RangeIter {
                return start_to_idx(list, last).with_max_count(max_count);
            }
            pub fn idx_to_end(list: LIST, first: usize) RangeIter {
                return RangeIter{
                    .list = list,
                    .range = .new_range(first, last_idx(list)),
                    .curr = first,
                };
            }
            pub fn idx_to_end_max_count(list: LIST, first: usize, max_count: usize) RangeIter {
                return idx_to_end(list, first).with_max_count(max_count);
            }
            pub fn one_index_rev(list: LIST, idx: usize) RangeIter {
                return one_index(list, idx).in_reverse();
            }
            pub fn new_range_rev(list: LIST, first: usize, last: usize) RangeIter {
                return new_range(list, first, last).in_reverse();
            }
            pub fn new_range_max_count_rev(list: LIST, first: usize, last: usize, max_count: usize) RangeIter {
                return new_range_max_count(list, first, last, max_count).in_reverse();
            }
            pub fn use_range_rev(list: LIST, range: Range) RangeIter {
                return use_range(list, range).in_reverse();
            }
            pub fn use_range_max_count_rev(list: LIST, range: Range, max_count: usize) RangeIter {
                return use_range_max_count(list, range, max_count).in_reverse();
            }
            pub fn entire_list_rev(list: LIST) RangeIter {
                return entire_list(list).in_reverse();
            }
            pub fn entire_list_max_count_rev(list: LIST, max_count: usize) RangeIter {
                return entire_list_max_count(list, max_count).in_reverse();
            }
            pub fn first_n_items_rev(list: LIST, count: usize) RangeIter {
                return first_n_items(list, count).in_reverse();
            }
            pub fn last_n_items_rev(list: LIST, count: usize) RangeIter {
                return last_n_items(list, count).in_reverse();
            }
            pub fn start_idx_count_total_rev(list: LIST, idx: usize, count: usize) RangeIter {
                return start_idx_count_total(list, idx, count).in_reverse();
            }
            pub fn end_idx_count_total_rev(list: LIST, idx: usize, count: usize) RangeIter {
                return end_idx_count_total(list, idx, count).in_reverse();
            }
            pub fn start_to_idx_rev(list: LIST, last: usize) RangeIter {
                return start_to_idx(list, last).in_reverse();
            }
            pub fn start_to_idx_max_count_rev(list: LIST, last: usize, max_count: usize) RangeIter {
                return start_to_idx_max_count(list, last, max_count).in_reverse();
            }
            pub fn idx_to_end_rev(list: LIST, first: usize) RangeIter {
                return idx_to_end(list, first).in_reverse();
            }
            pub fn idx_to_end_max_count_rev(list: LIST, first: usize, max_count: usize) RangeIter {
                return idx_to_end_max_count(list, first, max_count).in_reverse();
            }
        };

        //CHECKPOINT

        
        pub fn for_each_advanced(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            userdata: anytype,
            action: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool,
            comptime count_limit: IteratorState.IterCount,
            comptime error_checks: IteratorState.IterCheck,
            comptime filter: IteratorState(T).Filter,
            filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                const cont = action(ok_next_self, userdata);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
                if (!cont) {
                    break;
                }
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }

        pub fn filter_indexes_advanced(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            userdata: anytype,
            filter_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool,
            output_list: IIdxList,
            comptime count_limit: IteratorState.IterCount,
            comptime error_checks: IteratorState.IterCheck,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, .use_filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                if (error_checks == .error_checks) {
                    try output_list.try_ensure_free_slots(1);
                } else {
                    output_list.ensure_free_slots(1);
                }
                const out_idx = output_list.append_slots_assume_capacity(1);
                output_list.set(out_idx, ok_next_self.idx);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, .use_filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }

        pub fn transform_values_advanced(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            userdata: anytype,
            comptime OUT_TYPE: type,
            comptime OUT_PTR: type,
            transform_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) OUT_TYPE,
            output_list: IList(OUT_TYPE, OUT_PTR, usize),
            comptime count_limit: IteratorState.IterCount,
            comptime error_checks: IteratorState.IterCheck,
            comptime filter: IteratorState(T).Filter,
            filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                if (error_checks == .error_checks) {
                    try output_list.try_ensure_free_slots(1);
                } else {
                    output_list.ensure_free_slots(1);
                }
                const out_idx = output_list.append_slots_assume_capacity(1);
                const new_val = transform_func(ok_next_self, userdata);
                output_list.set(out_idx, new_val);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }

        pub fn accumulate_result_advanced(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorState(T).Item, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime count_limit: IteratorState.IterCount,
            comptime error_checks: IteratorState.IterCheck,
            comptime filter: IteratorState(T).Filter,
            filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool,
        ) if (error_checks == .error_checks) ListError!AccumulateResult(@TypeOf(initial_accumulation)) else AccumulateResult(@TypeOf(initial_accumulation)) {
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            var accum = initial_accumulation;
            while (next_self) |ok_next_self| {
                accum = accumulate_func(ok_next_self, accum, userdata);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return AccumulateResult(@TypeOf(initial_accumulation)){
                .count_result = self_iter.count_result(),
                .final_accumulation = accum,
            };
        }
        pub fn ensure_free_slots(self: ILIST, count: usize) void {
            const ok = self.vtable.try_ensure_free_slots(self.object, count, self.alloc);
            Assert.assert_with_reason(ok, @src(), "failed to grow list, current: len = {d}, cap = {d}, need {d} more slots", .{ self.len(), self.cap(), count });
        }
        pub fn append_slots(self: ILIST, count: usize) Range {
            self.ensure_free_slots(count);
            return self.append_slots_assume_capacity(count);
        }
        pub fn try_append_slots(self: ILIST, count: usize) ListError!Range {
            try self.try_ensure_free_slots(count);
            return self.append_slots_assume_capacity(count);
        }
        pub fn append_zig_slice(self: ILIST, slice: []const T) Range {
            self.ensure_free_slots(slice.len);
            return _append_zig_slice(self, slice);
        }
        pub fn try_append_zig_slice(self: ILIST, slice: []const T) ListError!Range {
            try self.try_ensure_free_slots(slice.len);
            return _append_zig_slice(self, slice);
        }
        fn _append_zig_slice(self: ILIST, slice: []const T) Range {
            if (slice.len == 0) return Range.single_idx(self.vtable.always_invalid_idx);
            const append_range = self.append_slots_assume_capacity(slice.len);
            var ii: usize = append_range.first_idx;
            var i: usize = 0;
            while (true) {
                self.set(ii, slice[i]);
                if (ii == append_range.last_idx) break;
                ii = self.next_idx(ii);
                i += 1;
            }
            return append_range;
        }
        pub fn append(self: ILIST, val: T) usize {
            self.ensure_free_slots(1);
            const append_range = self.append_slots_assume_capacity(1);
            self.set(append_range.first_idx, val);
            return append_range.first_idx;
        }
        pub fn try_append(self: ILIST, val: T) ListError!usize {
            try self.try_ensure_free_slots(1);
            const append_range = self.append_slots_assume_capacity(1);
            self.set(append_range.first_idx, val);
            return append_range.first_idx;
        }
        pub fn append_list(self: ILIST, list: ILIST) Range {
            self.ensure_free_slots(list.len);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.entire_list(), .use_range(self, append_range));
            return append_range;
        }
        pub fn try_append_list(self: ILIST, list: ILIST) ListError!Range {
            try self.try_ensure_free_slots(list.len);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.entire_list(), .use_range(self, append_range));
            return append_range;
        }
        pub fn append_list_range(self: ILIST, list: ILIST, list_range: Range) Range {
            self.ensure_free_slots(list.len);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, append_range));
            return append_range;
        }
        pub fn try_append_list_range(self: ILIST, list: ILIST, list_range: Range) ListError!Range {
            try self.try_ensure_free_slots(list.len);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, append_range));
            return append_range;
        }
        pub fn insert_slots(self: ILIST, idx: usize, count: usize) Range {
            self.ensure_free_slots(count);
            return self.insert_slots_assume_capacity(idx, count);
        }
        pub fn try_insert_slots(self: ILIST, idx: usize, count: usize) ListError!Range {
            try self.try_ensure_free_slots(count);
            return self.insert_slots_assume_capacity(idx, count);
        }
        pub fn insert_zig_slice(self: ILIST, idx: usize, slice_: []T) Range {
            self.ensure_free_slots(slice_.len);
            return _insert_zig_slice(self, idx, slice_);
        }
        pub fn try_insert_zig_slice(self: ILIST, idx: usize, slice_: []T) ListError!Range {
            try self.try_ensure_free_slots(slice_.len);
            return _insert_zig_slice(self, idx, slice_);
        }
        fn _insert_zig_slice(self: ILIST, idx: usize, slice_: []T) Range {
            var slice_list = list_from_slice_no_alloc(T, &slice_);
            var slice_iter = slice_list.iterator_state(.entire_list());
            const insert_range = self.insert_slots_assume_capacity(idx, slice_.len);
            var insert_iter = self.iterator_state(.use_range(insert_range));
            while (insert_iter.next()) |to| {
                const from = slice_iter.next();
                to.list.set(to.idx, from.?.val);
            }
            return insert_range;
        }
        pub fn insert(self: ILIST, idx: usize, val: T) usize {
            self.ensure_free_slots(1);
            const insert_range = self.insert_slots_assume_capacity(idx, 1);
            self.set(insert_range.first_idx, val);
            return insert_range.first_idx;
        }
        pub fn try_insert(self: ILIST, idx: usize, val: T) ListError!Range {
            try self.try_ensure_free_slots(1);
            const insert_range = self.insert_slots_assume_capacity(idx, 1);
            self.set(insert_range.first_idx, val);
            return insert_range.first_idx;
        }
        pub fn insert_list(self: ILIST, idx: usize, list: ILIST) Range {
            self.ensure_free_slots(list.len);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.entire_list(), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn try_insert_list(self: ILIST, idx: usize, list: ILIST) ListError!Range {
            try self.try_ensure_free_slots(list.len);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.entire_list(), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn insert_list_range(self: ILIST, idx: usize, list: ILIST, list_range: Range) Range {
            self.ensure_free_slots(list.len);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn try_insert_list_range(self: ILIST, idx: usize, list: ILIST, list_range: Range) ListError!Range {
            try self.try_ensure_free_slots(list.len);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn try_delete_range(self: ILIST, range: Range) ListError!void {
            if (!self.range_valid(range)) {
                return ListError.invalid_range;
            }
            self.delete_range(range);
        }
        pub fn delete(self: ILIST, idx: usize) void {
            self.delete_range(.single_idx(idx));
        }
        pub fn try_delete(self: ILIST, idx: usize) ListError!void {
            return self.try_delete_range(.single_idx(idx));
        }
        pub fn swap_delete(self: ILIST, idx: usize) void {
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
        }
        pub fn try_swap_delete(self: ILIST, idx: usize) ListError!void {
            self.swap(idx, self.last_idx());
            return self.try_delete_range(.single_idx(self.last_idx()));
        }
        pub fn delete_count(self: ILIST, idx: usize, count: usize) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            self.delete_range(rng);
        }
        pub fn try_delete_count(self: ILIST, idx: usize, count: usize) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_delete_range(rng);
        }
        pub fn remove_range(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) void {
            output.clear();
            var self_iter = self.iterator_state(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn try_remove_range(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            output.clear();
            if (!self.range_valid(range)) {
                return ListError.invalid_range;
            }
            var self_iter = self.iterator_state(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn remove_range_append(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) void {
            var self_iter = self.iterator_state(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn try_remove_range_append(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            if (!self.range_valid(range)) {
                return ListError.invalid_range;
            }
            var self_iter = self.iterator_state(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn remove_count(self: ILIST, idx: usize, count: usize, output: ILIST, output_mem_alloc: Allocator) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            self.remove_range(rng, output, output_mem_alloc);
        }
        pub fn try_remove_count(self: ILIST, idx: usize, count: usize, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_remove_range(rng, output, output_mem_alloc);
        }
        pub fn remove_count_append(self: ILIST, idx: usize, count: usize, output: ILIST, output_mem_alloc: Allocator) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.remove_range_append(rng, output, output_mem_alloc);
        }
        pub fn try_remove_count_append(self: ILIST, idx: usize, count: usize, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_remove_range_append(rng, output, output_mem_alloc);
        }
        pub fn remove(self: ILIST, idx: usize) T {
            const val = self.get(idx);
            self.delete_range(.single_idx(idx));
            return val;
        }
        pub fn try_remove(self: ILIST, idx: usize) ListError!T {
            const val = try self.try_get(idx);
            self.delete_range(.single_idx(idx));
            return val;
        }
        pub fn swap_remove(self: ILIST, idx: usize) T {
            const val = self.get(idx);
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
            return val;
        }
        pub fn try_swap_remove(self: ILIST, idx: usize) ListError!T {
            const val = try self.try_get(idx);
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
            return val;
        }
        pub fn replace_advanced(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            source: IteratorState,
            self_mem_alloc: Allocator,
            comptime count_limit: IteratorState.IterCount,
            comptime error_checks: IteratorState.IterCheck,
            comptime self_filter: IteratorState(T).Filter,
            self_userdata: anytype,
            self_filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(self_userdata)) bool,
            comptime src_filter: IteratorState(T).Filter,
            src_userdata: anytype,
            src_filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(src_userdata)) bool,
        ) ListError!void {
            var self_iter = self_range.to_iter(source);
            var source_iter = source;
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, self_filter, self_userdata, self_filter_func);
            var next_source = source_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
            while (next_self != null and next_source != null) {
                const ok_next_dest = next_source.?;
                const ok_next_self = next_self.?;
                ok_next_dest.list.set(ok_next_dest.idx, ok_next_self.val);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, self_filter, self_userdata, self_filter_func);
                next_source = source_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
            }
            if (next_self != null) {
                switch (self_iter.src) {
                    .single => |idx| {
                        const del_range = Range.single_idx(idx);
                        self.delete_range(del_range);
                    },
                    .range => |rng| {
                        const del_range = if (self_iter.forward) Range.new_range(self_iter.curr, rng.last_idx) else Range.new_range(rng.first_idx, self_iter.curr);
                        self.delete_range(del_range);
                    },
                    .list => {
                        while (next_self != null) {
                            const ok_next_self = next_self.?;
                            self.delete(ok_next_self.idx);
                            next_self = self_iter.next_advanced(count_limit, error_checks, .advance, self_filter, self_userdata, self_filter_func);
                        }
                    },
                }
            } else if (next_source != null) {
                if (self_iter.src == .list) {
                    return ListError.replace_dest_idx_list_smaller_than_source;
                }
                switch (source_iter.src) {
                    .single => {
                        const ok_next_source = next_source.?;
                        if (self_iter.forward) {
                            self.insert(self_iter.curr, ok_next_source.val, self_mem_alloc);
                        } else {
                            self.insert(self_iter.prev, ok_next_source.val, self_mem_alloc);
                        }
                    },
                    .range => |rng| {
                        const ins_range = if (source_iter.forward) Range.new_range(source_iter.curr, rng.last_idx) else Range.new_range(rng.first_idx, source_iter.curr);
                        if (self_iter.forward) {
                            self.insert_list_range(self_iter.curr, source.list, ins_range, self_mem_alloc);
                        } else {
                            self.insert_list_range(self_iter.prev, source.list, ins_range, self_mem_alloc);
                        }
                    },
                    .list => {
                        while (next_source != null) {
                            const ok_next_source = next_source.?;
                            if (self_iter.forward) {
                                self_iter.curr = self.insert(self_iter.curr, ok_next_source.val, self_mem_alloc);
                                self_iter.curr = self_iter.list.next_idx(self_iter.curr);
                            } else {
                                self_iter.prev = self.insert(self_iter.prev, ok_next_source.val, self_mem_alloc);
                            }
                            next_source = source_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
                        }
                    },
                }
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
                if (source_iter.err) |err| {
                    return err;
                }
            }
        }

        pub fn pop(self: ILIST) T {
            const last_idx_ = self.last_idx();
            const val = self.get(last_idx_);
            self.delete_range(.single_idx(last_idx_));
            return val;
        }
        pub fn try_pop(self: ILIST) ListError!T {
            const last_idx_ = try self.try_last_idx();
            const val = self.get(last_idx_);
            self.delete_range(.single_idx(last_idx_));
            return val;
        }

        fn _sorted_binary_locate(
            self: ILIST,
            orig_lo: usize,
            orig_hi: usize,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) LocateResult {
            var hi = orig_hi;
            var lo = orig_lo;
            var val: T = undefined;
            var idx: usize = undefined;
            var result = LocateResult{};
            while (true) {
                idx = self.split_range(.new_range(lo, hi));
                val = self.get(idx);
                if (equal_func(val, locate_val)) {
                    result.found = true;
                    result.idx = idx;
                    return result;
                }
                if (greater_than_func(val, locate_val)) {
                    if (idx == lo) {
                        result.exit_lo = idx == orig_lo;
                        result.idx = idx;
                        return result;
                    }
                    hi = self.prev_idx(idx);
                } else {
                    if (idx == hi) {
                        result.exit_hi = idx == orig_hi;
                        if (!result.exit_hi) {
                            idx = self.next_idx(hi);
                        }
                        result.idx = idx;
                        return result;
                    }
                    lo = self.next_idx(idx);
                }
            }
        }
        fn _sorted_linear_locate(
            self: ILIST,
            orig_lo: usize,
            orig_hi: usize,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) LocateResult {
            var val: T = undefined;
            var idx: usize = orig_lo;
            var result = LocateResult{};
            while (true) {
                val = self.get(idx);
                if (equal_func(val, locate_val)) {
                    result.found = true;
                    result.idx = idx;
                    return result;
                }
                if (greater_than_func(val, locate_val)) {
                    result.idx = idx;
                    return result;
                } else {
                    if (idx == orig_hi) {
                        result.exit_hi = true;
                        result.idx = idx;
                        return result;
                    }
                    idx = self.next_idx(idx);
                }
            }
        }

        fn _sorted_binary_locate_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            orig_lo: usize,
            orig_hi: usize,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) LocateResultIndirect {
            var hi = orig_hi;
            var lo = orig_lo;
            var val: T = undefined;
            var idx: usize = undefined;
            var idx_idx: usize = undefined;
            var result = LocateResultIndirect{};
            while (true) {
                idx_idx = idx_list.split_range(.new_range(lo, hi));
                idx = @intCast(idx_list.get(idx_idx));
                val = self.get(idx);
                if (equal_func(val, locate_val)) {
                    result.found = true;
                    result.idx_idx = idx_idx;
                    result.idx = idx;
                    return result;
                }
                if (greater_than_func(val, locate_val)) {
                    if (idx_idx == lo) {
                        result.exit_lo = idx_idx == orig_lo;
                        result.idx_idx = idx_idx;
                        result.idx = idx;
                        return result;
                    }
                    hi = idx_list.prev_idx(idx_idx);
                } else {
                    if (idx_idx == hi) {
                        result.exit_hi = idx_idx == orig_hi;
                        if (!result.exit_hi) {
                            idx_idx = idx_list.next_idx(hi);
                        }
                        result.idx_idx = idx_idx;
                        result.idx = idx;
                        return result;
                    }
                    lo = idx_list.next_idx(idx_idx);
                }
            }
        }
        fn _sorted_linear_locate_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            orig_lo: usize,
            orig_hi: usize,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) LocateResultIndirect {
            var val: T = undefined;
            var idx: usize = undefined;
            var idx_idx: usize = orig_lo;
            var result = LocateResultIndirect{};
            while (true) {
                idx = @intCast(idx_list.get(idx_idx));
                val = self.get(idx);
                if (equal_func(val, locate_val)) {
                    result.found = true;
                    result.idx_idx = idx_idx;
                    result.idx = idx;
                    return result;
                }
                if (greater_than_func(val, locate_val)) {
                    result.idx_idx = idx_idx;
                    result.idx = idx;
                    return result;
                } else {
                    if (idx_idx == orig_hi) {
                        result.exit_hi = true;
                        result.idx_idx = idx_idx;
                        result.idx = idx;
                        return result;
                    }
                    idx_idx = idx_list.next_idx(idx_idx);
                }
            }
        }

        fn _sorted_binary_search(
            self: ILIST,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResult {
            const lo = self.first_idx();
            const hi = self.last_idx();
            const ok = self.idx_valid(lo) and self.idx_valid(hi);
            if (!ok) {
                return SearchResult{};
            }
            const loc_result = _sorted_binary_locate(self, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResult{
                .found = loc_result.found,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_linear_search(
            self: ILIST,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResult {
            const lo = self.first_idx();
            const hi = self.last_idx();
            const ok = self.idx_valid(lo) and self.idx_valid(hi);
            if (!ok) {
                return SearchResult{};
            }
            const loc_result = _sorted_linear_locate(self, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResult{
                .found = loc_result.found,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_binary_search_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResultIndirect {
            const lo = idx_list.first_idx();
            const hi = idx_list.last_idx();
            const ok = idx_list.idx_valid(lo) and idx_list.idx_valid(hi);
            if (!ok) {
                return SearchResultIndirect{};
            }
            const loc_result = _sorted_binary_locate_indirect(self, IDX, idx_list, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResultIndirect{
                .found = loc_result.found,
                .idx = loc_result.idx,
                .idx_idx = loc_result.idx_idx,
            };
        }

        fn _sorted_linear_search_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResultIndirect {
            const lo = idx_list.first_idx();
            const hi = idx_list.last_idx();
            const ok = idx_list.idx_valid(lo) and idx_list.idx_valid(hi);
            if (!ok) {
                return SearchResultIndirect{};
            }
            const loc_result = _sorted_linear_locate_indirect(self, IDX, idx_list, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResultIndirect{
                .found = loc_result.found,
                .idx = loc_result.idx,
                .idx_idx = loc_result.idx_idx,
            };
        }

        fn _sorted_binary_insert_index(
            self: ILIST,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResult {
            const lo = self.first_idx();
            const hi = self.last_idx();
            const ok = self.idx_valid(lo) and self.idx_valid(hi);
            if (!ok) {
                return InsertIndexResult{};
            }
            const loc_result = _sorted_binary_locate(self, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResult{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_linear_insert_index(
            self: ILIST,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResult {
            const lo = self.first_idx();
            const hi = self.last_idx();
            const ok = self.idx_valid(lo) and self.idx_valid(hi);
            if (!ok) {
                return InsertIndexResult{};
            }
            const loc_result = _sorted_linear_locate(self, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResult{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_binary_insert_index_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResultIndirect {
            const lo = idx_list.first_idx();
            const hi = idx_list.last_idx();
            const ok = idx_list.idx_valid(lo) and idx_list.idx_valid(hi);
            if (!ok) {
                return InsertIndexResultIndirect{};
            }
            const loc_result = _sorted_binary_locate_indirect(self, IDX, idx_list, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResultIndirect{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
                .idx_idx = loc_result.idx_idx,
            };
        }

        fn _sorted_linear_insert_index_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResultIndirect {
            const lo = idx_list.first_idx();
            const hi = idx_list.last_idx();
            const ok = idx_list.idx_valid(lo) and idx_list.idx_valid(hi);
            if (!ok) {
                return InsertIndexResultIndirect{};
            }
            const loc_result = _sorted_linear_locate_indirect(self, IDX, idx_list, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResultIndirect{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
                .idx_idx = loc_result.idx_idx,
            };
        }

        fn _sorted_binary_insert(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_binary_insert_index(self, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = self.append(val);
            } else {
                idx = self.insert(ins_result.idx, val);
            }
            return idx;
        }

        fn _sorted_linear_insert(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_linear_insert_index(self, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = self.append(val);
            } else {
                idx = self.insert(ins_result.idx, val);
            }
            return idx;
        }

        fn _sorted_binary_insert_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_binary_insert_index_indirect(self, IDX, idx_list, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = idx_list.append(@intCast(ins_result.idx));
            } else {
                idx = idx_list.insert(ins_result.idx_idx, @intCast(ins_result.idx));
            }
            return idx;
        }

        fn _sorted_linear_insert_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_linear_insert_index_indirect(self, IDX, idx_list, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = idx_list.append(@intCast(ins_result.idx));
            } else {
                idx = idx_list.insert(ins_result.idx_idx, @intCast(ins_result.idx));
            }
            return idx;
        }

        pub fn sorted_insert(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert(val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_insert(val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_insert_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_implicit(self: ILIST, val: T) usize {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert(val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_insert(val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_insert_implicit_indirect(self: ILIST, comptime IDX: type, idx_list: IList(IDX), val: T) usize {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_insert_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_insert_index(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResult {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_index(val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_insert_index(val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_index_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResultIndirect {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_index_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_insert_index_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_index_implicit(self: ILIST, val: T) InsertIndexResult {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_index(val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_insert_index(val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_insert_index_implicit_indirect(self: ILIST, comptime IDX: type, idx_list: IList(IDX), val: T) InsertIndexResultIndirect {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_insert_index_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_insert_index_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            }
        }
        pub fn sorted_search(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResult {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_search(val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_search(val, equal_func, greater_than_func);
            }
        }
        pub fn sorted_search_indirect(
            self: ILIST,
            comptime IDX: type,
            idx_list: IList(IDX),
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResultIndirect {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_search_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            } else {
                return self._sorted_binary_search_indirect(IDX, idx_list, val, equal_func, greater_than_func);
            }
        }
        pub fn sorted_search_implicit(self: ILIST, val: T) SearchResult {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_search(val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_search(val, _implicit_eq, _implicit_gt);
            }
        }
        pub fn sorted_search_implicit_indirect(self: ILIST, comptime IDX: type, idx_list: IList(IDX), val: T) SearchResultIndirect {
            if (self.prefer_linear_ops()) {
                return self._sorted_linear_search_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            } else {
                return self._sorted_binary_search_indirect(IDX, idx_list, val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_set_and_resort(self: ILIST, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            var new_idx = idx;
            var adj_idx = self.next_idx(new_idx);
            var adj_val: T = undefined;
            while (self.idx_valid(adj_idx) and next_is_less: {
                adj_val = self.get(adj_idx);
                break :next_is_less greater_than_func(val, adj_val);
            }) {
                self.set(new_idx, adj_val);
                new_idx = adj_idx;
                adj_idx = self.next_idx(adj_idx);
            }
            adj_idx = self.prev_idx(new_idx);
            while (self.idx_valid(adj_idx) and prev_is_greater: {
                adj_val = self.get(adj_idx);
                break :prev_is_greater greater_than_func(adj_val, val);
            }) {
                self.set(new_idx, adj_val);
                new_idx = adj_idx;
                adj_idx = self.prev_idx(adj_idx);
            }
            self.set(new_idx, val);
            return new_idx;
        }
        pub fn sorted_set_and_resort_implicit(self: ILIST, idx: usize, val: T) usize {
            return self.sorted_set_and_resort(idx, val, _implicit_gt);
        }
        pub fn sorted_set_and_resort_indirect(self: ILIST, comptime IDX: type, idx_list: IList(IDX), idx_idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            var new_idx_idx = idx_idx;
            const real_idx_list: *List(u8) = @ptrCast(@alignCast(idx_list.object)); //DEBUG
            const real_idx: usize = @intCast(idx_list.get(idx_idx));
            std.debug.print("idx_idx : {d}, real_idx: {d}\n", .{ idx_idx, real_idx }); //DEBUG
            var adj_idx_idx = idx_list.next_idx(new_idx_idx);
            var adj_idx: usize = undefined;
            var adj_val: T = undefined;
            while (idx_list.idx_valid(adj_idx_idx) and next_is_less: {
                adj_idx = @intCast(idx_list.get(adj_idx_idx));
                adj_val = self.get(adj_idx);
                // std.debug.print("next_is_less tested:\n", .{}); //DEBUG
                break :next_is_less greater_than_func(val, adj_val);
            }) {
                // std.debug.print("\ttrue, this {d} > {d} next\n", .{ val, adj_val }); //DEBUG
                idx_list.set(new_idx_idx, @intCast(adj_idx));
                new_idx_idx = adj_idx_idx;
                adj_idx_idx = idx_list.next_idx(adj_idx_idx);
            }
            adj_idx_idx = idx_list.prev_idx(new_idx_idx);
            while (idx_list.idx_valid(adj_idx_idx) and prev_is_greater: {
                adj_idx = @intCast(idx_list.get(adj_idx_idx));
                adj_val = self.get(adj_idx);
                // std.debug.print("\nprev_is_greater tested:\n", .{}); //DEBUG
                break :prev_is_greater greater_than_func(adj_val, val);
            }) {
                // std.debug.print("\ttrue, prev {d} > {d} this\n", .{ adj_val, val }); //DEBUG
                idx_list.set(new_idx_idx, @intCast(adj_idx));
                new_idx_idx = adj_idx_idx;
                adj_idx_idx = idx_list.prev_idx(adj_idx_idx);
            }
            std.debug.print("new_idx_idx: {d}, real_idx: {d}\n", .{ new_idx_idx, real_idx }); //DEBUG
            if (idx_idx < new_idx_idx) { //DEBUG
                std.debug.print("new_range:{any}\n", .{real_idx_list.ptr[idx_idx..new_idx_idx]});
                var iii = idx_idx;
                std.debug.print("new_sorted_vals: {{ ", .{});
                while (iii < new_idx_idx) {
                    const idx: usize = @intCast(real_idx_list.ptr[iii]);
                    std.debug.print("{d}, ", .{self.get(idx)});
                    iii += 1;
                }
                std.debug.print("}}\n", .{});
            } else {
                std.debug.print("new_range:{any}\n", .{real_idx_list.ptr[new_idx_idx..idx_idx]});
                var iii = new_idx_idx;
                std.debug.print("new_sorted_vals: {{ ", .{});
                while (iii < idx_idx) {
                    const idx: usize = @intCast(real_idx_list.ptr[iii]);
                    std.debug.print("{d}, ", .{self.get(idx)});
                    iii += 1;
                }
                std.debug.print("}}\n", .{});
            }

            idx_list.set(new_idx_idx, @intCast(real_idx));
            return new_idx_idx;
        }
        pub fn sorted_set_and_resort_implicit_indirect(self: ILIST, comptime IDX: type, idx_list: IList(IDX), idx_idx: usize, val: T) usize {
            return self.sorted_set_and_resort_indirect(IDX, idx_list, idx_idx, val, _implicit_gt);
        }
        pub fn search(self: ILIST, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) SearchResult {
            var val: T = undefined;
            var idx: usize = self.first_idx();
            var ok = self.idx_valid(idx);
            var result = LocateResult{};
            while (ok) {
                val = self.get(idx);
                if (equal_func(val, find_val)) {
                    result.found = true;
                    result.idx = idx;
                    break;
                }
                idx = self.next_idx(idx);
                ok = self.idx_valid(idx);
            }
            return result;
        }
        pub fn search_implicit(self: ILIST, val: T) SearchResult {
            return self.search(val, _implicit_eq);
        }

        pub fn add_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) + val;
        }
        pub fn try_add_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) + val;
        }
        pub fn add_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v + val);
        }
        pub fn try_add_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v + val);
        }

        pub fn subtract_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) - val;
        }
        pub fn try_subtract_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) - val;
        }
        pub fn subtract_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v - val);
        }
        pub fn try_subtract_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v - val);
        }

        pub fn multiply_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) * val;
        }
        pub fn try_multiply_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) * val;
        }
        pub fn multiply_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v * val);
        }
        pub fn try_multiply_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v * val);
        }

        pub fn divide_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) / val;
        }
        pub fn try_divide_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) / val;
        }
        pub fn divide_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v / val);
        }
        pub fn try_divide_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v / val);
        }

        pub fn modulo_get(self: ILIST, idx: usize, val: anytype) T {
            return @mod(self.get(idx), val);
        }
        pub fn try_modulo_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return @mod((try self.try_get(idx)), val);
        }
        pub fn modulo_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, @mod(v, val));
        }
        pub fn try_modulo_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, @mod(v, val));
        }

        pub fn mod_rem_get(self: ILIST, idx: usize, val: anytype) struct { mod: T, rem: T } {
            const v = self.get(idx);
            const mod = @mod(v, val);
            const rem = v - mod;
            return struct { mod: T, rem: T }{ .mod = mod, .rem = rem };
        }
        pub fn try_mod_rem_get(self: ILIST, idx: usize, val: anytype) ListError!struct { mod: T, rem: T } {
            const v = try self.try_get(idx);
            const mod = @mod(v, val);
            const rem = v - mod;
            return struct { mod: T, rem: T }{ .mod = mod, .rem = rem };
        }

        pub fn bit_and_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) & val;
        }
        pub fn try_bit_and_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) & val;
        }
        pub fn bit_and_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v & val);
        }
        pub fn try_bit_and_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v & val);
        }

        pub fn bit_or_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) | val;
        }
        pub fn try_bit_or_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) | val;
        }
        pub fn bit_or_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v | val);
        }
        pub fn try_bit_or_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v | val);
        }

        pub fn bit_xor_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) ^ val;
        }
        pub fn try_bit_xor_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) ^ val;
        }
        pub fn bit_xor_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v ^ val);
        }
        pub fn try_bit_xor_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v ^ val);
        }

        pub fn bit_invert_get(self: ILIST, idx: usize) T {
            return ~self.get(idx);
        }
        pub fn try_bit_invert_get(self: ILIST, idx: usize) ListError!T {
            return ~(try self.try_get(idx));
        }
        pub fn bit_invert_set(self: ILIST, idx: usize) void {
            const v = self.get(idx);
            self.set(idx, ~v);
        }
        pub fn try_bit_invert_set(self: ILIST, idx: usize) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, ~v);
        }

        pub fn bit_l_shift_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) << val;
        }
        pub fn try_bit_l_shift_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) << val;
        }
        pub fn bit_l_shift_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v << val);
        }
        pub fn try_bit_l_shift_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v << val);
        }

        pub fn bit_r_shift_get(self: ILIST, idx: usize, val: anytype) T {
            return self.get(idx) >> val;
        }
        pub fn try_bit_r_shift_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return (try self.try_get(idx)) >> val;
        }
        pub fn bit_r_shift_set(self: ILIST, idx: usize, val: anytype) void {
            const v = self.get(idx);
            self.set(idx, v >> val);
        }
        pub fn try_bit_r_shift_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v = try self.try_get(idx);
            self.set(idx, v >> val);
        }

        pub fn less_than_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) < val;
        }
        pub fn try_less_than_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) < val;
        }

        pub fn less_than_equal_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) <= val;
        }
        pub fn try_less_than_equal_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) <= val;
        }

        pub fn greater_than_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) > val;
        }
        pub fn try_greater_than_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) > val;
        }

        pub fn greater_than_equal_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) >= val;
        }
        pub fn try_greater_than_equal_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) >= val;
        }

        pub fn equals_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) == val;
        }
        pub fn try_equals_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) == val;
        }

        pub fn not_equals_get(self: ILIST, idx: usize, val: anytype) bool {
            return self.get(idx) != val;
        }
        pub fn try_not_equals_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return (try self.try_get(idx)) != val;
        }

        pub fn get_min(self: ILIST, items: IteratorState(T).Partial) T {
            var iter = items.to_iter(self);
            var val = iter.next().?;
            while (iter.next()) |v| {
                val = @min(val, v);
            }
            return val;
        }

        pub fn try_get_min(self: ILIST, items: IteratorState(T).Partial) ListError!T {
            var iter = items.to_iter(self);
            var val: T = undefined;
            if (iter.next_advanced(.use_count_limit, .error_checks, .advance, .no_filter, null, null)) |v| {
                val = v;
            } else {
                return ListError.iterator_is_empty;
            }
            while (iter.next_advanced(.use_count_limit, .error_checks, .advance, .no_filter, null, null)) |v| {
                val = @min(val, v);
            }
            return val;
        }

        pub fn get_max(self: ILIST, items: IteratorState(T).Partial) T {
            var iter = items.to_iter(self);
            var val = iter.next().?;
            while (iter.next()) |v| {
                val = @max(val, v);
            }
            return val;
        }

        pub fn try_get_max(self: ILIST, items: IteratorState(T).Partial) ListError!T {
            var iter = items.to_iter(self);
            var val: T = undefined;
            if (iter.next_advanced(.use_count_limit, .error_checks, .advance, .no_filter, null, null)) |v| {
                val = v;
            } else {
                return ListError.iterator_is_empty;
            }
            while (iter.next_advanced(.use_count_limit, .error_checks, .advance, .no_filter, null, null)) |v| {
                val = @max(val, v);
            }
            return val;
        }

        pub fn get_clamped(self: ILIST, idx: usize, min: T, max: T) T {
            const v = self.get(idx);
            return @min(max, @max(min, v));
        }
        pub fn try_get_clamped(self: ILIST, idx: usize, min: T, max: T) ListError!T {
            const v = try self.try_get(idx);
            return @min(max, @max(min, v));
        }
        pub fn set_clamped(self: ILIST, idx: usize, val: T, min: T, max: T) void {
            const v = @min(max, @max(min, val));
            self.set(idx, v);
        }
        pub fn try_set_clamped(self: ILIST, idx: usize, val: T, min: T, max: T) ListError!void {
            const v = @min(max, @max(min, val));
            return self.try_set(idx, v);
        }

        pub fn set_report_change(self: ILIST, idx: usize, val: T) bool {
            const old = self.get(idx);
            self.set(idx, val);
            return val != old;
        }

        pub fn try_set_report_change(self: ILIST, idx: usize, val: T) ListError!bool {
            const old = try self.try_get(idx);
            self.set(idx, val);
            return val != old;
        }

        pub fn get_unsafe_cast(self: ILIST, idx: usize, comptime TT: type) TT {
            const v = self.get(idx);
            const vv: TT = @as(*TT, @ptrCast(@alignCast(&v))).*;
            return vv;
        }
        pub fn try_get_unsafe_cast(self: ILIST, idx: usize, comptime TT: type) ListError!TT {
            const v = try self.try_get(idx);
            const vv: TT = @as(*TT, @ptrCast(@alignCast(&v))).*;
            return vv;
        }

        pub fn get_unsafe_ptr_cast(self: ILIST, idx: usize, comptime TT: type) *TT {
            const v: *T = self.get_ptr(idx);
            const vv: *TT = @as(*TT, @ptrCast(@alignCast(&v)));
            return vv;
        }
        pub fn try_get_unsafe_ptr_cast(self: ILIST, idx: usize, comptime TT: type) ListError!*TT {
            const v: *T = try self.try_get_ptr(idx);
            const vv: *TT = @as(*TT, @ptrCast(@alignCast(&v)));
            return vv;
        }

        pub fn set_unsafe_cast(self: ILIST, idx: usize, val: anytype) void {
            const v: *T = @ptrCast(@alignCast(&val));
            self.set(idx, v.*);
        }
        pub fn try_set_unsafe_cast(self: ILIST, idx: usize, val: anytype) ListError!void {
            const v: *T = @ptrCast(@alignCast(&val));
            return self.try_set(idx, v.*);
        }

        pub fn set_unsafe_cast_report_change(self: ILIST, idx: usize, val: T) bool {
            const old = self.get(idx);
            const v: *T = @ptrCast(@alignCast(&val));
            self.set(idx, v.*);
            return v.* != old;
        }

        pub fn try_set_unsafe_cast_report_change(self: ILIST, idx: usize, val: T) ListError!bool {
            const old = self.get(idx);
            const v: *T = @ptrCast(@alignCast(&val));
            try self.try_set(idx, v.*);
            return v.* != old;
        }
    };
}
