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
const math = std.math;
const Root = @import("./_root.zig");
const Type = std.builtin.Type;
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

pub const Concrete = IList.Concrete;

pub const FilterMode = Concrete.FilterMode;
pub const CountResult = Concrete.CountResult;
pub const CopyResult = Concrete.CopyResult;
pub const LocateResult = Concrete.LocateResult;
pub const SearchResult = Concrete.SearchResult;
pub const InsertIndexResult = Concrete.InsertIndexResult;
pub const ListError = Concrete.ListError;
pub const Range = Concrete.Range;

const NO_ALLOC = DummyAlloc.allocator_panic;

pub fn SliceAdapter(comptime T: type) type {
    return struct {

        //*** BEGIN PROTOTYPE ***
        const P_FUNCS = struct {
            fn p_get(self: *[]T, idx: usize, _: Allocator) T {
                return self.ptr[idx];
            }
            fn p_get_ptr(self: *[]T, idx: usize, _: Allocator) *T {
                return &self.ptr[idx];
            }
            fn p_set(self: *[]T, idx: usize, val: T, _: Allocator) void {
                self.ptr[idx] = val;
            }
            fn p_move(self: *[]T, old_idx: usize, new_idx: usize, _: Allocator) void {
                Utils.slice_move_one(self.ptr[0..self.len], old_idx, new_idx);
            }
            fn p_move_range(self: *[]T, range: IList.Range, new_first_idx: usize, _: Allocator) void {
                Utils.slice_move_many(self.ptr[0..self.len], range.first_idx, range.last_idx, new_first_idx);
            }
            fn p_try_ensure_free_slots(_: *[]T, _: usize, _: Allocator) error{failed_to_grow_list}!void {
                return;
            }
            fn p_shrink_cap_reserve_at_most(_: *[]T, _: usize, _: Allocator) void {
                return;
            }
            fn p_resize(self: *[]T, new_cap: usize, alloc: Allocator) IList.Range {
                const first = self.len;
                if (alloc.remap(self.ptr[0..self.len], new_cap)) |new_mem| {
                    self.* = new_mem;
                    const last = new_mem.len - 1;
                    return IList.Range.new_range(first, last);
                } else {
                    const new_mem = alloc.alloc(T, new_cap) catch |err| Assert.assert_allocation_failure(@src(), T, new_cap, err);
                    @memcpy(new_mem[0..self.len], self.ptr[0..self.len]);
                    const last = new_mem.len - 1;
                    alloc.free(self.ptr[0..self.len]);
                    self.* = new_mem;
                    return IList.Range.new_range(first, last);
                }
            }
            fn p_append_slots_assume_capacity(self: *[]T, count: usize, alloc: Allocator) IList.Range {
                return p_resize(self, self.len + count, alloc);
            }
            fn p_insert_slots_assume_capacity(self: *[]T, idx: usize, count: usize, alloc: Allocator) IList.Range {
                _ = p_resize(self, self.len + count, alloc);
                Utils.mem_insert(self.ptr, &self.len, idx, count);
                return IList.Range.new_range(idx, idx + count - 1);
            }
            fn p_trim_len(self: *[]T, trim_n: usize, alloc: Allocator) void {
                _ = p_resize(self, self.len - trim_n, alloc);
            }
            fn p_delete(self: *[]T, idx: usize, alloc: Allocator) void {
                if (idx != self.len - 1) {
                    Utils.mem_remove(self.ptr, &self.len, idx, 1);
                }
                _ = p_resize(self, self.len - 1, alloc);
            }
            fn p_delete_range(self: *[]T, range: IList.Range, alloc: Allocator) void {
                const rlen = range.consecutive_len();
                if (range.last_idx != self.len - 1) {
                    Utils.mem_remove(self.ptr, &self.len, range.first_idx, rlen);
                }
                _ = p_resize(self, self.len - rlen, alloc);
            }
            fn p_clear(self: *[]T, alloc: Allocator) void {
                alloc.free(self.ptr[0..self.len]);
                self.len = 0;
                self.ptr = undefined;
            }
            fn p_free(self: *[]T, alloc: Allocator) void {
                alloc.free(self.ptr[0..self.len]);
                self.len = 0;
                self.ptr = undefined;
            }
        };
        const PFX = IList.Concrete.ConcreteTableValueFuncs(T, *[]T, Allocator){
            .get = P_FUNCS.p_get,
            .get_ptr = P_FUNCS.p_get_ptr,
            .set = P_FUNCS.p_set,
            .move = P_FUNCS.p_move,
            .move_range = P_FUNCS.p_move_range,
            .try_ensure_free_slots = P_FUNCS.p_try_ensure_free_slots,
            .shrink_cap_reserve_at_most = P_FUNCS.p_shrink_cap_reserve_at_most,
            .append_slots_assume_capacity = P_FUNCS.p_append_slots_assume_capacity,
            .insert_slots_assume_capacity = P_FUNCS.p_insert_slots_assume_capacity,
            .trim_len = P_FUNCS.p_trim_len,
            .delete = P_FUNCS.p_delete,
            .delete_range = P_FUNCS.p_delete_range,
            .clear = P_FUNCS.p_clear,
            .free = P_FUNCS.p_free,
        };
        const P = IList.Concrete.CreateConcretePrototypeNaturalIndexes(T, *[]T, Allocator, null, "ptr", null, "len", null, "len", true, PFX);
        const VTABLE = P.VTABLE(true, true, false, math.maxInt(usize));
        //*** END PROTOTYPE***

        pub fn interface(self: *[]T, alloc: Allocator) IList.IList(T) {
            return IList.IList(T){
                .alloc = alloc,
                .object = @ptrCast(self),
                .vtable = &VTABLE,
            };
        }
        pub fn interface_no_alloc(self: *[]T) IList.IList(T) {
            return IList.IList(T){
                .alloc = DummyAlloc.allocator_panic,
                .object = @ptrCast(self),
                .vtable = &VTABLE,
            };
        }

        /// Return the number of items in the list
        pub fn len_usize(self: *[]T) usize {
            return P.len(self);
        }
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        pub fn trim_len(self: *[]T, trim_n: usize, alloc: Allocator) void {
            return P.trim_len(self, trim_n, alloc);
        }
        /// Return the total number of items the list can hold
        /// without reallocation
        pub fn cap_usize(self: *[]T) usize {
            return P.cap(self);
        }
        /// Return the first index in the list
        pub fn first_idx(self: *[]T) usize {
            return P.first_idx(self);
        }
        /// Return the last valid index in the list
        pub fn last_idx(self: *[]T) usize {
            return P.last_idx(self);
        }
        /// Return the index directly after the given index in the list
        pub fn next_idx(self: *[]T, this_idx: usize) usize {
            return P.next_idx(self, this_idx);
        }
        /// Return the index `n` places after the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_next_idx(self: *[]T, this_idx: usize, n: usize) usize {
            return P.nth_next_idx(self, this_idx, n);
        }
        /// Return the index directly before the given index in the list
        pub fn prev_idx(self: *[]T, this_idx: usize) usize {
            return P.prev_idx(self, this_idx);
        }
        /// Return the index `n` places before the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_prev_idx(self: *[]T, this_idx: usize, n: usize) usize {
            return P.nth_prev_idx(self, this_idx, n);
        }
        /// Return `true` if the index is valid for the current state
        /// of the list, `false` otherwise
        pub fn idx_valid(self: *[]T, idx: usize) bool {
            return P.idx_valid(self, idx);
        }
        /// Return `true` if the range is valid for the current state
        /// of the list, `false` otherwise. The first index must
        /// come before or be equal to the last index, and all
        /// indexes in between must also be valid
        pub fn range_valid(self: *[]T, range: Range) bool {
            return P.range_valid(self, range);
        }
        /// Return whether the given index falls within the given range,
        /// inclusive
        pub fn idx_in_range(self: *[]T, range: Range, idx: usize) bool {
            return P.idx_in_range(self, range, idx);
        }
        /// Split a range roughly in half, returning an index
        /// as close to the true center point as possible.
        /// Implementations may choose not to return an index
        /// close to the actual middle of the range if
        /// finding that middle index is expensive
        pub fn split_range(self: *[]T, range: Range) usize {
            return P.split_range(self, range);
        }
        /// Return the number of indexes included within a range,
        /// inclusive of the last index
        pub fn range_len(self: *[]T, range: Range) usize {
            return P.range_len(self, range);
        }
        /// Return the value at the given index
        pub fn get(self: *[]T, idx: usize) T {
            return P.get(self, idx, NO_ALLOC);
        }
        /// Return a pointer to the value at a given index
        pub fn get_ptr(self: *[]T, idx: usize) *T {
            return P.get_ptr(self, idx, NO_ALLOC);
        }
        /// Set the value at the given index
        pub fn set(self: *[]T, idx: usize, val: T) void {
            return P.set(self, idx, val, NO_ALLOC);
        }
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move(self: *[]T, old_idx: usize, new_idx: usize) void {
            return P.move(self, old_idx, new_idx, NO_ALLOC);
        }
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move_range(self: *[]T, range: Range, new_first_idx: usize) void {
            return P.move_range(self, range, new_first_idx, NO_ALLOC);
        }
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        pub fn try_ensure_free_slots(self: *[]T, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            return P.try_ensure_free_slots(self, count, alloc);
        }
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        pub fn shrink_cap_reserve_at_most(self: *[]T, reserve_at_most: usize) void {
            return P.shrink_cap_reserve_at_most(self, reserve_at_most, NO_ALLOC);
        }
        /// Insert `n` value slots with undefined values at the given index,
        /// moving other items at or after that index to after the new ones.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn insert_slots_assume_capacity(self: *[]T, idx: usize, count: usize, alloc: Allocator) Range {
            return P.insert_slots_assume_capacity(self, idx, count, alloc);
        }
        /// Append `n` value slots with undefined values at the end of the list.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn append_slots_assume_capacity(self: *[]T, count: usize, alloc: Allocator) Range {
            return P.append_slots_assume_capacity(self, count, alloc);
        }
        /// Delete one value at given index
        pub fn delete(self: *[]T, idx: usize, alloc: Allocator) void {
            return P.delete(self, idx, alloc);
        }
        /// Delete many values within given range, inclusive
        pub fn delete_range(self: *[]T, range: Range, alloc: Allocator) void {
            return P.delete_range(self, range, alloc);
        }
        /// Set list to an empty state, but retain existing capacity, if possible
        pub fn clear(self: *[]T, alloc: Allocator) void {
            return P.clear(self, alloc);
        }
        /// Set list to an empty state and return memory to allocator
        pub fn free(self: *[]T, alloc: Allocator) void {
            return P.free(self, alloc);
        }
        pub fn is_empty(self: *[]T) bool {
            return P.is_empty(self);
        }
        pub fn try_first_idx(self: *[]T) ListError!usize {
            return P.try_first_idx(self);
        }
        pub fn try_last_idx(self: *[]T) ListError!usize {
            return P.try_last_idx(self);
        }
        pub fn try_next_idx(self: *[]T, this_idx: usize) ListError!usize {
            return P.try_next_idx(self, this_idx);
        }
        pub fn try_prev_idx(self: *[]T, this_idx: usize) ListError!usize {
            return P.try_prev_idx(self, this_idx);
        }
        pub fn try_nth_next_idx(self: *[]T, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_next_idx(self, this_idx, n);
        }
        pub fn try_nth_prev_idx(self: *[]T, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_prev_idx(self, this_idx, n);
        }
        pub fn try_get(self: *[]T, idx: usize) ListError!T {
            return P.try_get(self, idx, NO_ALLOC);
        }
        pub fn try_get_ptr(self: *[]T, idx: usize) ListError!*T {
            return P.try_get_ptr(self, idx, NO_ALLOC);
        }
        pub fn try_set(self: *[]T, idx: usize, val: T) ListError!void {
            return P.try_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_move(self: *[]T, old_idx: usize, new_idx: usize) ListError!void {
            return P.try_move(self, old_idx, new_idx, NO_ALLOC);
        }
        pub fn try_move_range(self: *[]T, range: Range, new_first_idx: usize) ListError!void {
            return P.try_move_range(self, range, new_first_idx, NO_ALLOC);
        }
        pub fn nth_idx(self: *[]T, n: usize) usize {
            return P.nth_idx(self, n);
        }
        pub fn nth_idx_from_end(self: *[]T, n: usize) usize {
            return P.nth_idx_from_end(self, n);
        }
        pub fn try_nth_idx(self: *[]T, n: usize) ListError!usize {
            return P.try_nth_idx(self, n);
        }
        pub fn try_nth_idx_from_end(self: *[]T, n: usize) ListError!usize {
            return P.try_nth_idx_from_end(self, n);
        }
        pub fn get_last(self: *[]T) T {
            return P.get_last(self, NO_ALLOC);
        }
        pub fn try_get_last(self: *[]T) ListError!T {
            return P.try_get_last(self, NO_ALLOC);
        }
        pub fn get_last_ptr(self: *[]T) *T {
            return P.get_last_ptr(self, NO_ALLOC);
        }
        pub fn try_get_last_ptr(self: *[]T) ListError!*T {
            return P.try_get_last_ptr(self, NO_ALLOC);
        }
        pub fn set_last(self: *[]T, val: T) void {
            return P.set_last(self, val, NO_ALLOC);
        }
        pub fn try_set_last(self: *[]T, val: T) ListError!void {
            return P.try_set_last(self, val, NO_ALLOC);
        }
        pub fn get_first(self: *[]T) T {
            return P.get_first(self, NO_ALLOC);
        }
        pub fn try_get_first(self: *[]T) ListError!T {
            return P.try_get_first(self, NO_ALLOC);
        }
        pub fn get_first_ptr(self: *[]T) *T {
            return P.get_first_ptr(self, NO_ALLOC);
        }
        pub fn try_get_first_ptr(self: *[]T) ListError!*T {
            return P.try_get_first_ptr(self, NO_ALLOC);
        }
        pub fn set_first(self: *[]T, val: T) void {
            return P.set_first(self, val, NO_ALLOC);
        }
        pub fn try_set_first(self: *[]T, val: T) ListError!void {
            return P.try_set_first(self, val, NO_ALLOC);
        }
        pub fn get_nth(self: *[]T, n: usize) T {
            return P.get_nth(self, n, NO_ALLOC);
        }
        pub fn try_get_nth(self: *[]T, n: usize) ListError!T {
            return P.try_get_nth(self, n, NO_ALLOC);
        }
        pub fn get_nth_ptr(self: *[]T, n: usize) *T {
            return P.get_nth_ptr(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_ptr(self: *[]T, n: usize) ListError!*T {
            return P.try_get_nth_ptr(self, n, NO_ALLOC);
        }
        pub fn set_nth(self: *[]T, n: usize, val: T) void {
            return P.set_nth(self, n, val, NO_ALLOC);
        }
        pub fn try_set_nth(self: *[]T, n: usize, val: T) ListError!void {
            return P.try_set_nth(self, n, val, NO_ALLOC);
        }
        pub fn get_nth_from_end(self: *[]T, n: usize) T {
            return P.get_nth_from_end(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_from_end(self: *[]T, n: usize) ListError!T {
            return P.try_get_nth_from_end(self, n, NO_ALLOC);
        }
        pub fn get_nth_ptr_from_end(self: *[]T, n: usize) *T {
            return P.get_nth_ptr_from_end(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_ptr_from_end(self: *[]T, n: usize) ListError!*T {
            return P.try_get_nth_ptr_from_end(self, n, NO_ALLOC);
        }
        pub fn set_nth_from_end(self: *[]T, n: usize, val: T) void {
            return P.set_nth_from_end(self, n, val, NO_ALLOC);
        }
        pub fn try_set_nth_from_end(self: *[]T, n: usize, val: T) ListError!void {
            return P.try_set_nth_from_end(self, n, val, NO_ALLOC);
        }
        pub fn set_from(self: *[]T, self_idx: usize, source: *[]T, source_idx: usize) void {
            return P.set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
        }
        pub fn try_set_from(self: *[]T, self_idx: usize, source: *[]T, source_idx: usize) ListError!void {
            return P.try_set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
        }
        pub fn exchange(self: *[]T, self_idx: usize, other: *[]T, other_idx: usize) void {
            return P.exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
        }
        pub fn try_exchange(self: *[]T, self_idx: usize, other: *[]T, other_idx: usize) ListError!void {
            return P.try_exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
        }
        pub fn overwrite(self: *[]T, source_idx: usize, dest_idx: usize) void {
            return P.overwrite(self, source_idx, dest_idx, NO_ALLOC);
        }
        pub fn try_overwrite(self: *[]T, source_idx: usize, dest_idx: usize) ListError!void {
            return P.try_overwrite(self, source_idx, dest_idx, NO_ALLOC);
        }
        pub fn reverse(self: *[]T, range: P.PartialRangeIter) void {
            return P.reverse(self, range, NO_ALLOC);
        }
        pub fn rotate(self: *[]T, range: P.PartialRangeIter, delta: isize) void {
            return P.rotate(self, range, delta, NO_ALLOC);
        }
        pub fn fill(self: *[]T, range: P.PartialRangeIter, val: T) usize {
            return P.fill(self, range, val, NO_ALLOC);
        }
        pub fn copy(source: P.RangeIter, dest: P.RangeIter) usize {
            return P.copy(source, dest);
        }
        pub fn copy_to(self: *[]T, self_range: P.PartialRangeIter, dest: P.RangeIter) usize {
            return P.copy_to(self, self_range, dest);
        }
        pub fn is_sorted(self: *[]T, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.is_sorted(self, range, greater_than, NO_ALLOC);
        }
        pub fn is_sorted_implicit(self: *[]T, range: P.PartialRangeIter) bool {
            return P.is_sorted_implicit(self, range, NO_ALLOC);
        }
        pub fn insertion_sort(self: *[]T, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.insertion_sort(self, range, greater_than, NO_ALLOC);
        }
        pub fn insertion_sort_implicit(self: *[]T, range: P.PartialRangeIter) bool {
            return P.insertion_sort_implicit(self, range, NO_ALLOC);
        }
        pub fn quicksort(self: *[]T, range: P.PartialRangeIter, greater_than: *const P.CompareFunc, less_than: *const P.CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort(self, range, NO_ALLOC, greater_than, less_than, PARTITION_IDX, partition_stack);
        }
        pub fn quicksort_implicit(self: *[]T, range: P.PartialRangeIter, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort_implicit(self, range, NO_ALLOC, PARTITION_IDX, partition_stack);
        }
        pub fn range_iterator(self: *[]T, range: P.PartialRangeIter) P.RangeIter {
            return P.range_iterator(self, range);
        }
        pub fn for_each(
            self: *[]T,
            range: P.PartialRangeIter,
            userdata: anytype,
            action: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.for_each(self, range, userdata, action, filter, filter_func);
        }
        pub fn filter_indexes(
            self: *[]T,
            range: P.PartialRangeIter,
            userdata: anytype,
            filter_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime OUT_IDX: type,
            out_list: IList(OUT_IDX),
        ) usize {
            return P.filter_indexes(self, range, userdata, filter_func, OUT_IDX, out_list);
        }
        pub fn transform_values(
            self: *[]T,
            range: P.PartialRangeIter,
            userdata: anytype,
            comptime OUT_TYPE: type,
            transform_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            out_list: IList(OUT_TYPE),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.transform_values(self, range, userdata, OUT_TYPE, transform_func, out_list, filter, filter_func);
        }
        pub fn accumulate_result(
            self: *[]T,
            range: P.PartialRangeIter,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: P.IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) @TypeOf(initial_accumulation) {
            return P.accumulate_result(self, range, initial_accumulation, userdata, accumulate_func, filter, filter_func);
        }
        pub fn ensure_free_slots(self: *[]T, count: usize, alloc: Allocator) void {
            return P.ensure_free_slots(self, count, alloc);
        }
        pub fn append_slots(self: *[]T, count: usize, alloc: Allocator) Range {
            return P.append_slots(self, count, alloc);
        }
        pub fn try_append_slots(self: *[]T, count: usize, alloc: Allocator) ListError!Range {
            return P.try_append_slots(self, count, alloc);
        }
        pub fn append_zig_slice(self: *[]T, slice_: []const T, alloc: Allocator) Range {
            return P.append_zig_slice(self, slice_, alloc);
        }
        pub fn try_append_zig_slice(self: *[]T, slice_: []const T, alloc: Allocator) ListError!Range {
            return P.try_append_zig_slice(self, slice_, alloc);
        }
        pub fn append(self: *[]T, val: T, alloc: Allocator) usize {
            return P.append(self, val, alloc);
        }
        pub fn try_append(self: *[]T, val: T, alloc: Allocator) ListError!usize {
            return P.try_append(self, val, alloc);
        }
        pub fn append_many(self: *[]T, list_range: P.RangeIter, alloc: Allocator) Range {
            return P.append_many(self, alloc, list_range);
        }
        pub fn try_append_many(self: *[]T, list_range: P.RangeIter, alloc: Allocator) ListError!Range {
            return P.try_append_many(self, alloc, list_range);
        }
        pub fn insert_slots(self: *[]T, idx: usize, count: usize, alloc: Allocator) Range {
            return P.insert_slots(self, idx, count, alloc);
        }
        pub fn try_insert_slots(self: *[]T, idx: usize, count: usize, alloc: Allocator) ListError!Range {
            return P.try_insert_slots(self, idx, count, alloc);
        }
        pub fn insert_zig_slice(self: *[]T, idx: usize, slice_: []T, alloc: Allocator) Range {
            return P.insert_zig_slice(self, idx, slice_, alloc);
        }
        pub fn try_insert_zig_slice(self: *[]T, idx: usize, slice_: []T, alloc: Allocator) ListError!Range {
            return P.try_insert_zig_slice(self, idx, slice_, alloc);
        }
        pub fn insert(self: *[]T, idx: usize, val: T, alloc: Allocator) usize {
            return P.insert(self, idx, val, alloc);
        }
        pub fn try_insert(self: *[]T, idx: usize, val: T, alloc: Allocator) ListError!usize {
            return P.try_insert(self, idx, val, alloc);
        }
        pub fn insert_many(self: *[]T, idx: usize, alloc: Allocator, list_range: P.RangeIter) Range {
            return P.insert_many(self, idx, alloc, list_range);
        }
        pub fn try_insert_many(self: *[]T, idx: usize, alloc: Allocator, list_range: P.RangeIter) ListError!Range {
            return P.try_insert_many(self, idx, alloc, list_range);
        }
        pub fn try_delete_range(self: *[]T, range: Range, alloc: Allocator) ListError!void {
            return P.try_delete_range(self, range, alloc);
        }
        pub fn delete_many(self: *[]T, range: P.PartialRangeIter, alloc: Allocator) void {
            return P.delete_many(self, range.with_alloc(alloc));
        }
        pub fn try_delete_many(self: *[]T, range: P.PartialRangeIter, alloc: Allocator) ListError!void {
            return P.try_delete_many(self, range.with_alloc(alloc));
        }
        pub fn try_delete(self: *[]T, idx: usize, alloc: Allocator) ListError!void {
            return P.try_delete(self, idx, alloc);
        }
        pub fn swap_delete(self: *[]T, idx: usize, alloc: Allocator) void {
            return P.swap_delete(self, idx, alloc);
        }
        pub fn try_swap_delete(self: *[]T, idx: usize, alloc: Allocator) ListError!void {
            return P.try_swap_delete(self, idx, alloc);
        }
        pub fn swap_delete_many(self: *[]T, range: P.PartialRangeIter) void {
            return P.swap_delete_many(self, range);
        }
        pub fn try_swap_delete_many(self: *[]T, range: P.PartialRangeIter) ListError!void {
            return P.try_swap_delete_many(self, range);
        }
        pub fn remove_many(self: *[]T, self_range: P.PartialRangeIter, dest: *[]T, dest_alloc: Allocator) Range {
            return P.remove_range(self, self_range, dest, dest_alloc);
        }
        pub fn try_remove_many(self: *[]T, self_range: P.PartialRangeIter, dest: *[]T, dest_alloc: Allocator) ListError!Range {
            return P.try_remove_range(self, self_range, dest, dest_alloc);
        }
        pub fn remove(self: *[]T, idx: usize, alloc: Allocator) T {
            return P.remove(self, idx, alloc);
        }
        pub fn try_remove(self: *[]T, idx: usize, alloc: Allocator) ListError!T {
            return P.try_remove(self, idx, alloc);
        }
        pub fn swap_remove(self: *[]T, idx: usize, alloc: Allocator) T {
            return P.swap_remove(self, idx, alloc);
        }
        pub fn try_swap_remove(self: *[]T, idx: usize, alloc: Allocator) ListError!T {
            return P.try_swap_remove(self, idx, alloc);
        }
        pub fn pop(self: *[]T, alloc: Allocator) T {
            return P.pop(self, alloc);
        }
        pub fn try_pop(self: *[]T, alloc: Allocator) ListError!T {
            return P.try_pop(self, alloc);
        }
        pub fn pop_many(self: *[]T, count: usize, alloc: Allocator, dest: *[]T, dest_alloc: Allocator) Range {
            return P.pop_many(self, count, alloc, dest, dest_alloc);
        }
        pub fn try_pop_many(self: *[]T, count: usize, alloc: Allocator, dest: *[]T, dest_alloc: Allocator) ListError!Range {
            return P.try_pop_many(self, count, alloc, dest, dest_alloc);
        }
        pub fn sorted_insert(
            self: *[]T,
            val: T,
            alloc: Allocator,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            return P.sorted_insert(self, alloc, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_implicit(self: *[]T, val: T, alloc: Allocator) usize {
            return P.sorted_insert_implicit(self, val, alloc);
        }
        pub fn sorted_insert_index(
            self: *[]T,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResult {
            return P.sorted_insert_index(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_index_implicit(self: *[]T, val: T) InsertIndexResult {
            return P.sorted_insert_index_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_search(
            self: *[]T,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResult {
            return P.sorted_search(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_search_implicit(self: *[]T, val: T) SearchResult {
            return P.sorted_search_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_set_and_resort(self: *[]T, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            return P.sorted_set_and_resort(self, idx, val, NO_ALLOC, greater_than_func);
        }
        pub fn sorted_set_and_resort_implicit(self: *[]T, idx: usize, val: T) usize {
            return P.sorted_set_and_resort_implicit(self, idx, val, NO_ALLOC);
        }
        pub fn search(self: *[]T, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) SearchResult {
            return P.search(self, find_val, NO_ALLOC, equal_func);
        }
        pub fn search_implicit(self: *[]T, find_val: anytype) SearchResult {
            return P.search_implicit(self, find_val, NO_ALLOC);
        }
        pub fn add_get(self: *[]T, idx: usize, val: anytype) T {
            return P.add_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_add_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_add_get(self, idx, val, NO_ALLOC);
        }
        pub fn add_set(self: *[]T, idx: usize, val: anytype) void {
            return P.add_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_add_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_add_set(self, idx, val, NO_ALLOC);
        }
        pub fn subtract_get(self: *[]T, idx: usize, val: anytype) T {
            return P.subtract_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_subtract_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_subtract_get(self, idx, val, NO_ALLOC);
        }
        pub fn subtract_set(self: *[]T, idx: usize, val: anytype) void {
            return P.subtract_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_subtract_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_subtract_set(self, idx, val, NO_ALLOC);
        }
        pub fn multiply_get(self: *[]T, idx: usize, val: anytype) T {
            return P.multiply_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_multiply_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_multiply_get(self, idx, val, NO_ALLOC);
        }
        pub fn multiply_set(self: *[]T, idx: usize, val: anytype) void {
            return P.multiply_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_multiply_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_multiply_set(self, idx, val, NO_ALLOC);
        }
        pub fn divide_get(self: *[]T, idx: usize, val: anytype) T {
            return P.divide_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_divide_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_divide_get(self, idx, val, NO_ALLOC);
        }
        pub fn divide_set(self: *[]T, idx: usize, val: anytype) void {
            return P.divide_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_divide_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_divide_set(self, idx, val, NO_ALLOC);
        }
        pub fn modulo_get(self: *[]T, idx: usize, val: anytype) T {
            return P.modulo_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_modulo_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_modulo_get(self, idx, val, NO_ALLOC);
        }
        pub fn modulo_set(self: *[]T, idx: usize, val: anytype) void {
            return P.modulo_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_modulo_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_modulo_set(self, idx, val, NO_ALLOC);
        }
        pub fn mod_rem_get(self: *[]T, idx: usize, val: anytype) T {
            return P.mod_rem_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_mod_rem_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_mod_rem_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_and_get(self: *[]T, idx: usize, val: anytype) T {
            return P.bit_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_and_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_bit_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_and_set(self: *[]T, idx: usize, val: anytype) void {
            return P.bit_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_and_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_bit_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_or_get(self: *[]T, idx: usize, val: anytype) T {
            return P.bit_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_or_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_bit_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_or_set(self: *[]T, idx: usize, val: anytype) void {
            return P.bit_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_or_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_bit_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_xor_get(self: *[]T, idx: usize, val: anytype) T {
            return P.bit_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_xor_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_bit_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_xor_set(self: *[]T, idx: usize, val: anytype) void {
            return P.bit_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_xor_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_bit_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_invert_get(self: *[]T, idx: usize) T {
            return P.bit_invert_get(self, idx, NO_ALLOC);
        }
        pub fn try_bit_invert_get(self: *[]T, idx: usize) ListError!T {
            return P.try_bit_invert_get(self, idx, NO_ALLOC);
        }
        pub fn bit_invert_set(self: *[]T, idx: usize) void {
            return P.bit_invert_set(self, idx, NO_ALLOC);
        }
        pub fn try_bit_invert_set(self: *[]T, idx: usize) ListError!void {
            return P.try_bit_invert_set(self, idx, NO_ALLOC);
        }
        pub fn bool_and_get(self: *[]T, idx: usize, val: bool) T {
            return P.bool_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_and_get(self: *[]T, idx: usize, val: bool) ListError!T {
            return P.try_bool_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_and_set(self: *[]T, idx: usize, val: bool) void {
            return P.bool_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_and_set(self: *[]T, idx: usize, val: bool) ListError!void {
            return P.try_bool_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_or_get(self: *[]T, idx: usize, val: bool) T {
            return P.bool_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_or_get(self: *[]T, idx: usize, val: bool) ListError!T {
            return P.try_bool_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_or_set(self: *[]T, idx: usize, val: bool) void {
            return P.bool_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_or_set(self: *[]T, idx: usize, val: bool) ListError!void {
            return P.try_bool_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_xor_get(self: *[]T, idx: usize, val: bool) T {
            return P.bool_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_xor_get(self: *[]T, idx: usize, val: bool) ListError!T {
            return P.try_bool_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_xor_set(self: *[]T, idx: usize, val: bool) void {
            return P.bool_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_xor_set(self: *[]T, idx: usize, val: bool) ListError!void {
            return P.try_bool_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_invert_get(self: *[]T, idx: usize) T {
            return P.bool_invert_get(self, idx, NO_ALLOC);
        }
        pub fn try_bool_invert_get(self: *[]T, idx: usize) ListError!T {
            return P.try_bool_invert_get(self, idx, NO_ALLOC);
        }
        pub fn bool_invert_set(self: *[]T, idx: usize) void {
            return P.bool_invert_set(self, idx, NO_ALLOC);
        }
        pub fn try_bool_invert_set(self: *[]T, idx: usize) ListError!void {
            return P.try_bool_invert_set(self, idx, NO_ALLOC);
        }
        pub fn bit_l_shift_get(self: *[]T, idx: usize, val: anytype) T {
            return P.bit_l_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_l_shift_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_bit_l_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_l_shift_set(self: *[]T, idx: usize, val: anytype) void {
            return P.bit_l_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_l_shift_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_bit_l_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_r_shift_get(self: *[]T, idx: usize, val: anytype) T {
            return P.bit_r_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_r_shift_get(self: *[]T, idx: usize, val: anytype) ListError!T {
            return P.try_bit_r_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_r_shift_set(self: *[]T, idx: usize, val: anytype) void {
            return P.bit_r_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_r_shift_set(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_bit_r_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn less_than_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.less_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_less_than_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn less_than_equal_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.less_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_less_than_equal_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn greater_than_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.greater_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_greater_than_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn greater_than_equal_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.greater_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_greater_than_equal_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn equals_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_equals_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn not_equals_get(self: *[]T, idx: usize, val: anytype) bool {
            return P.not_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_not_equals_get(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_not_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn get_min_in_range(self: *[]T, range: P.PartialRangeIter) P.Item {
            return P.get_min_in_range(self, range);
        }
        pub fn try_get_min_in_range(self: *[]T, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_min_in_range(self, range);
        }
        pub fn get_max_in_range(self: *[]T, range: P.PartialRangeIter) P.Item {
            return P.get_max_in_range(self, range);
        }
        pub fn try_get_max_in_range(self: *[]T, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_max_in_range(self, range);
        }
        pub fn get_clamped(self: *[]T, idx: usize, min: T, max: T) T {
            return P.get_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn try_get_clamped(self: *[]T, idx: usize, min: T, max: T) ListError!T {
            return P.try_get_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn set_clamped(self: *[]T, idx: usize, min: T, max: T) void {
            return P.set_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn try_set_clamped(self: *[]T, idx: usize, min: T, max: T) ListError!void {
            return P.try_set_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn set_report_change(self: *[]T, idx: usize, val: T) bool {
            return P.set_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_report_change(self: *[]T, idx: usize, val: T) bool {
            return P.try_set_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn get_unsafe_cast(self: *[]T, idx: usize, comptime TT: type) TT {
            return P.get_unsafe_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn try_get_unsafe_cast(self: *[]T, idx: usize, comptime TT: type) ListError!TT {
            return P.try_get_unsafe_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn get_unsafe_ptr_cast(self: *[]T, idx: usize, comptime TT: type) *TT {
            return P.get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn try_get_unsafe_ptr_cast(self: *[]T, idx: usize, comptime TT: type) ListError!*TT {
            return P.try_get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn set_unsafe_cast(self: *[]T, idx: usize, val: anytype) void {
            return P.set_unsafe_cast(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_unsafe_cast(self: *[]T, idx: usize, val: anytype) ListError!void {
            return P.try_set_unsafe_cast(self, idx, val, NO_ALLOC);
        }
        pub fn set_unsafe_cast_report_change(self: *[]T, idx: usize, val: anytype) bool {
            return P.set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_unsafe_cast_report_change(self: *[]T, idx: usize, val: anytype) ListError!bool {
            return P.try_set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
        }
    };
}
