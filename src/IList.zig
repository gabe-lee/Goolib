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

pub const SliceAdapter = @import("./IList_SliceAdapter.zig").SliceAdapter;
pub const ArrayListAdapter = @import("./IList_ArrayListAdapter.zig").ArrayListAdapter;
pub const List = @import("./IList_List.zig").List;
pub const RingList = @import("./IList_RingList.zig").RingList;
pub const MultiSortList = @import("./IList_MultiSortList.zig").MultiSortList;
pub const Concrete = @import("./IList_Concrete.zig");

pub const FilterMode = Concrete.FilterMode;
pub const CountResult = Concrete.CountResult;
pub const CopyResult = Concrete.CopyResult;
pub const LocateResult = Concrete.LocateResult;
pub const SearchResult = Concrete.SearchResult;
pub const InsertIndexResult = Concrete.InsertIndexResult;
pub const ListError = Concrete.ListError;
pub const Range = Concrete.Range;

pub const _Fuzzer = @import("./IList_Fuzz.zig");
pub const _Bencher = @import("./IList_Bench.zig");

pub fn IList(comptime T: type) type {
    return struct {
        const ILIST = @This();

        object: *anyopaque,
        vtable: *const VTable,
        alloc: Allocator,

        pub const VTable = struct {
            /// Should hold a constant boolean value describing whether
            /// certain operations will peform better with linear operations
            /// instead of binary-split operations
            ///
            /// If `range_len()`, `nth_next_idx()`, and `nth_prev_idx()` operate in O(N) time
            /// instead of O(1), this should return true
            ///
            /// An example requiring `true` would be a linked list, where one must
            /// traverse in linear time to find the true index 'n places' after a given index,
            /// or the number of items between two indexes
            ///
            /// Returning the correct value will allow some operations to use alternate,
            /// more efficient algorithms
            prefer_linear_ops: bool = false,
            /// Should hold a constant boolean value describing whether consecutive indexes,
            /// (eg. `0, 1, 2, 3, 4, 5`) are in their logical/proper order (not necessarily sorted)
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            consecutive_indexes_in_order: bool = true,
            /// Should hold a constant boolean value describing whether all indexes greater-than-or-equal-to
            /// `0` AND less-than `slice.len()` are valid
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            all_indexes_zero_to_len_valid: bool = true,
            /// If set to `true`, calling `list.try_ensure_free_slots(count)` will not change the result
            /// of `list.cap()`, but a `true` result still indicates that an append or insert is expected
            /// to behave as expected.
            ///
            /// An example of this being true may be an interface for a `File` or slice `[]T`, where
            /// there is no concept of allocated-but-unused memory, but can still be appended to
            /// (with re-allocation)
            ensure_free_doesnt_change_cap: bool = false,
            /// Should be an index that will ALWAYS result in `IList.idx_valid(always_invalid_idx) == false`
            ///
            /// Used for initialization of some data structures and algorithms
            always_invalid_idx: usize = math.maxInt(usize),
            /// Returns whether the given index is valid for the slice
            idx_valid: *const fn (object: *anyopaque, idx: usize) bool = Types.unimplemented_2_params("IList.vtable.idx_valid", *anyopaque, usize, bool),
            /// Returns whether the given index range is valid for the slice
            ///
            /// The following MUST be true:
            ///   - `first_idx` comes logically before OR is equal to `last_idx`
            ///   - all indexes including and between `first_idx` and `last_idx` are valid for the slice
            range_valid: *const fn (object: *anyopaque, range: Range) bool = Types.unimplemented_2_params("IList.vtable.range_valid", *anyopaque, Range, bool),
            /// Returns whether the given index is within the given range, including
            /// the first and last indexes.
            idx_in_range: *const fn (object: *anyopaque, range: Range, idx: usize) bool = Types.unimplemented_3_params("IList.vtable.range_valid", *anyopaque, Range, usize, bool),
            /// Split an index range (roughly) in half, returning the index in the middle of the range
            ///
            /// Assumes `range_valid(first_idx, last_idx) == true`, and if so,
            /// the returned index MUST also be valid and MUST be between or equal to the first and/or last index
            ///
            /// The implementation should endeavor to return an index as close to the true middle index
            /// as possible, but it is not required to as long as the returned index IS between or equal to
            /// the first and/or last indexes. HOWEVER, some algorithms will have inconsitent performance
            /// if the returned index is far from the true middle index
            split_range: *const fn (object: *anyopaque, range: Range) usize = Types.unimplemented_2_params("IList.vtable.split_range", *anyopaque, Range, usize),
            /// get the value at the provided index
            get: *const fn (object: *anyopaque, idx: usize, alloc: Allocator) T = Types.unimplemented_3_params("IList.vtable.get", *anyopaque, usize, Allocator, T),
            /// get a pointer to the value at the provided index
            get_ptr: *const fn (object: *anyopaque, idx: usize, alloc: Allocator) *T = Types.unimplemented_3_params("IList.vtable.get_ptr", *anyopaque, usize, Allocator, *T),
            /// set the value at the provided index to the given value
            set: *const fn (object: *anyopaque, idx: usize, val: T, alloc: Allocator) void = Types.unimplemented_4_params("IList.vtable.set", *anyopaque, usize, T, Allocator, void),
            /// move the data located at `old_idx` to `new_idx`, shifting all
            /// values in between either up or down
            move: *const fn (object: *anyopaque, old_idx: usize, new_idx: usize, alloc: Allocator) void = Types.unimplemented_4_params("IList.vtable.move", *anyopaque, usize, usize, Allocator, void),
            /// move the data from located between and including `first_idx` and `last_idx`,
            /// to the position `newfirst_idx`, shifting the values at that location out of the way
            ///
            /// This function does not change list length, meaning `new_first_idx` MUST be an index
            /// that is `list.range_len(range) - 1` positions from the end of the list
            move_range: *const fn (object: *anyopaque, range: Range, new_first_idx: usize, alloc: Allocator) void = Types.unimplemented_4_params("IList.vtable.move_range", *anyopaque, Range, usize, Allocator, void),
            /// Return the first index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            first_idx: *const fn (object: *anyopaque) usize = Types.unimplemented_1_params("IList.vtable.first_idx", *anyopaque, usize),
            /// Return the last index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            last_idx: *const fn (object: *anyopaque) usize = Types.unimplemented_1_params("IList.vtable.last_idx", *anyopaque, usize),
            /// Return the next index after the current index in the slice.
            ///
            /// If the given index is invalid or no next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            next_idx: *const fn (object: *anyopaque, this_idx: usize) usize = Types.unimplemented_2_params("IList.vtable.next_idx", *anyopaque, usize, usize),
            /// Return the index `n` places after the current index in the slice.
            ///
            /// If the given index is invalid or no nth next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_next_idx: *const fn (object: *anyopaque, this_idx: usize, n: usize) usize = Types.unimplemented_3_params("IList.vtable.nth_next_idx", *anyopaque, usize, usize, usize),
            /// Return the prev index before the current index in the slice.
            ///
            /// If the given index is invalid or no prev index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            prev_idx: *const fn (object: *anyopaque, this_idx: usize) usize = Types.unimplemented_2_params("IList.vtable.prev_idx", *anyopaque, usize, usize),
            /// Return the index `n` places before the current index in the slice.
            ///
            /// If the given index is invalid or no nth previous index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_prev_idx: *const fn (object: *anyopaque, this_idx: usize, n: usize) usize = Types.unimplemented_3_params("IList.vtable.nth_prev_idx", *anyopaque, usize, usize, usize),
            /// Return the current number of values in the slice/list
            ///
            /// It is not guaranteed that all indexes less than `len` are valid for the list,
            /// but it should be assumed that `list.idx_valid(list.nth_idx(len - 1)) == true`
            len: *const fn (object: *anyopaque) usize = Types.unimplemented_1_params("IList.vtable.len", *anyopaque, usize),
            /// Reduce the number of items in the list by
            /// dropping/deleting them from the end of the list
            trim_len: *const fn (object: *anyopaque, trim_n: usize, alloc: Allocator) void = Types.unimplemented_3_params("IList.vtable.trim_len", *anyopaque, usize, Allocator, void),
            /// Return the number of items between (and including) `first_idx` and `last_idx`
            ///
            /// `slice.range_len(slice.first_idx(), slice.last_idx())` MUST equal `slice.len()`
            range_len: *const fn (object: *anyopaque, range: Range) usize = Types.unimplemented_2_params("IList.vtable.range_len", *anyopaque, Range, usize),
            /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
            /// the memory again or performing any other expensive reorganization procedure
            ///
            /// If free space cannot be ensured and attempting to add `count` more items
            /// will definitely fail or cause undefined behaviour, `ok == false`. If free space
            /// cannot be ensured, BUT attempting to add `count` more items should still pass,
            /// such as an interface for a file that does not have any allocated-but-unused space,
            /// this should still return `true`
            ///
            /// The supplied allocator should be the same one used when creating/allocating the
            /// original concrete implementation object's *memory*
            try_ensure_free_slots: *const fn (object: *anyopaque, count: usize, alloc: Allocator) error{failed_to_grow_list}!void = Types.unimplemented_3_params("IList.vtable.try_ensure_free_slots", *anyopaque, usize, Allocator, error{failed_to_grow_list}!void),
            /// Insert `n` new slots directly before existing index, shifting all existing items
            /// at and after that index forward.
            ///
            /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
            /// not match the insert index, depending on the implementation behavior
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            ///
            /// The supplied allocator may or may not be used dependant on the specific implementation
            insert_slots_assume_capacity: *const fn (object: *anyopaque, idx: usize, count: usize, alloc: Allocator) Range = Types.unimplemented_4_params("IList.vtable.insert_slots_assume_capacity", *anyopaque, usize, usize, Allocator, Range),
            /// Append `n` new slots at the end of the list.
            ///
            /// Returns the first new slot and the last new slot, inclusive
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            ///
            /// The supplied allocator may or may not be used dependant on the specific implementation
            append_slots_assume_capacity: *const fn (object: *anyopaque, count: usize, alloc: Allocator) Range = Types.unimplemented_3_params("IList.vtable.append_slots_assume_capacity", *anyopaque, usize, Allocator, Range),
            /// Delete one item at the given index
            ///
            /// All items after `idx` are shifted backward
            delete: *const fn (object: *anyopaque, idx: usize, alloc: Allocator) void = Types.unimplemented_3_params("IList.vtable.delete", *anyopaque, usize, Allocator, void),
            /// Delete all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
            ///
            /// All items after `last_removed_idx` are shifted backward
            delete_range: *const fn (object: *anyopaque, range: Range, alloc: Allocator) void = Types.unimplemented_3_params("IList.vtable.delete_range", *anyopaque, Range, Allocator, void),
            /// Reset list to an empty state without fully freeing it
            ///
            /// The implementation may choose to retain allocated capacity or not, but the list
            /// must remain in a usable state
            clear: *const fn (object: *anyopaque, alloc: Allocator) void = Types.unimplemented_2_params("IList.vtable.clear", *anyopaque, Allocator, void),
            /// Return the total number of values the slice/list can hold
            cap: *const fn (object: *anyopaque) usize = Types.unimplemented_1_params("IList.vtable.cap", *anyopaque, usize),
            /// Shrink the allocated capacity of the list (using the provded allocator if necessary),
            /// while reserving at most `n_reserved_cap` extra capacity above the list len.
            /// The real resulting free space may be smaller than this if the original free space
            /// was smaller than the `at-most` value
            ///
            /// This may or may not reallocate the list data, dependant on the implementation.
            shrink_cap_reserve_at_most: *const fn (object: *anyopaque, reserve_at_most: usize, alloc: Allocator) void = Types.unimplemented_3_params("IList.vtable.shrink_cap_reserve_n", *anyopaque, usize, Allocator, void),
            /// Free the list's memory, if applicable, and set it to an empty, unusable state.
            /// Attempting to re-use the list should be considered undefined behavior without
            /// calling some other re-initialization method.
            free: *const fn (object: *anyopaque, alloc: Allocator) void = Types.unimplemented_2_params("IList.vtable.free", *anyopaque, Allocator, void),
        };

        // pub const Reader = struct {
        //     src: ILIST,
        //     buf: ?[]T = null,
        //     src_pos: usize,
        //     buf_start: usize = 0,
        //     buf_end: usize = 0,

        //     pub fn new(src: ILIST, buf: ?[]T) Reader {
        //         return Reader{
        //             .src = src,
        //             .buf = buf,
        //             .src_pos = src.first_idx(),
        //         };
        //     }

        //     pub fn read_to(self: *Reader, out: IteratorState(T).Full) CountResult {
        //         var result = CopyResult{};
        //         if (self.buf) |buf| {
        //             var buf_result = CopyResult{};
        //             var count: usize = 0;
        //             while (!result.full_dest_copied and !buf_result.full_source_copied) {
        //                 if (self.buf_start == self.buf_end) {
        //                     self.buf_start = 0;
        //                     const buf_list = list_from_slice_no_alloc(T, &buf);
        //                     buf_result = self.src.copy_from_to(.idx_to_end(self.src_pos), .use_range(buf_list, .new_range(self.buf_start, buf.len - 1)));
        //                     self.src_pos = self.src.next_idx(buf_result.source_range.last_idx);
        //                     self.buf_end = buf_result.dest_range.last_idx + 1;
        //                     if (buf_result.count == 0) {
        //                         return out.count_result();
        //                     }
        //                 }
        //                 result = buf.copy_from_to(.new_range(self.buf_start, self.buf_end - 1), out);
        //                 count += result.count;
        //                 if (result.full_source_copied) {
        //                     self.buf_empty = true;
        //                 }
        //             }
        //             return count;
        //         } else {
        //             result = self.src.copy_from_to(.idx_to_end(self.src_pos), out);
        //             self.src_pos = self.src.next_idx(result.source_range.last_idx);
        //             return out.count_result();
        //         }
        //     }

        //     pub fn peek_to(self: *Reader, out: ILIST) CountResult {
        //         const pos = self.src_pos;
        //         const res = self.read_to(out);
        //         self.src_pos = pos;
        //         self.buf_empty = true;
        //         return res;
        //     }

        //     fn _discard_action(item: IteratorState(T).Item, dd: *_discard_data) bool {
        //         dd.left -= 1;
        //         dd.last = item.idx;
        //         if (dd.left == 0 or item.list.last_idx() == item.idx) {
        //             return false;
        //         }
        //         return true;
        //     }

        //     const _discard_data = struct {
        //         left: usize,
        //         last: usize,
        //     };

        //     pub fn discard(self: *Reader, count: usize) void {
        //         var left: usize = count;

        //         if (self.buf) |buf| {
        //             if (!self.buf_empty) {
        //                 if (buf.prefer_linear_ops()) {
        //                     var dd = _discard_data{ .left = count, .last = self.buf_pos };
        //                     buf.for_each(.idx_to_end(self.buf_pos), &dd, _discard_action);
        //                     left = dd.left;
        //                 } else {}
        //             }
        //         }
        //         self.src_pos = self.src.nth_next_idx(self.src_pos, count);
        //     }
        // };
        pub const CompareFunc = fn (left_or_this: T, right_or_test: T) bool;
        const P = Concrete.CreateConcretePrototypeIList(T);

        /// Return whether the func `native_slice()` can be used
        pub fn has_native_slice(self: ILIST) bool {
            return P.has_native_slice(self);
        }
        /// Return a native zig slice `[]T` that holds
        /// the values in the provided range, without
        /// performing any allocations/copies
        pub fn native_slice(self: ILIST, range: Range) []T {
            Assert.assert_with_reason(self.has_native_slice(), @src(), "cannot use `native_slice()` because consucutive items are not located at consucutive memory addresses", .{});
            return P.native_slice(self, range);
        }
        /// Should hold a constant boolean value describing whether certain operations will peform better with linear operations instead of binary-split operations
        ///
        /// If range_len(), nth_next_idx(), and nth_prev_idx() operate in O(N) time instead of O(1), this should return true
        ///
        /// An example requiring true would be a linked list, where one must traverse in linear time to find the true index 'n places' after a given index, or the number of items between two indexes
        ///
        /// Returning the correct value will allow some operations to use alternate, more efficient algorithms
        pub fn prefer_linear_ops(self: ILIST) bool {
            return P.prefer_linear_ops(self);
        }
        /// Should hold a constant boolean value describing whether all indexes greater-than-or-equal-to 0 AND less-than len() are valid
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        pub fn all_indexes_zero_to_len_valid(self: ILIST) bool {
            return P.all_indexes_zero_to_len_valid(self);
        }
        /// Should hold a constant boolean value describing whether consecutive indexes, (eg. 0, 1, 2, 3, 4, 5)
        /// are located at consecutive memory addresses
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        pub fn consecutive_indexes_in_order(self: ILIST) bool {
            return P.consecutive_indexes_in_order(self);
        }
        /// If this returns true, calling `try_ensure_free_slots(count)` will not change the result of `cap()`,
        /// but a non-error result still indicates that an append or insert is expected to behave as expected.
        ///
        /// An example of this being true may be an interface for a File or slice []T, where there is no concept of allocated-but-unused memory,
        /// but can still be appended to (with re-allocation)
        pub fn ensure_free_doesnt_change_cap(self: ILIST) bool {
            return P.ensure_free_doesnt_change_cap(self);
        }
        /// Return an index that will ALWAYS result in `idx_valid(idx) == false`
        pub fn always_invalid_idx(self: ILIST) usize {
            return P.always_invalid_idx(self);
        }
        /// Return the number of items in the list
        pub fn len(self: ILIST) usize {
            return P.len(self);
        }
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        pub fn trim_len(self: ILIST, trim_n: usize) void {
            return P.trim_len(self, trim_n);
        }
        /// Return the total number of items the list can hold
        /// without reallocation
        pub fn cap(self: ILIST) usize {
            return P.cap(self);
        }
        /// Return the first index in the list
        pub fn first_idx(self: ILIST) usize {
            return P.first_idx(self);
        }
        /// Return the last valid index in the list
        pub fn last_idx(self: ILIST) usize {
            return P.last_idx(self);
        }
        /// Return the index directly after the given index in the list
        pub fn next_idx(self: ILIST, this_idx: usize) usize {
            return P.next_idx(self, this_idx);
        }
        /// Return the index `n` places after the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_next_idx(self: ILIST, this_idx: usize, n: usize) usize {
            return P.nth_next_idx(self, this_idx, n);
        }
        /// Return the index directly before the given index in the list
        pub fn prev_idx(self: ILIST, this_idx: usize) usize {
            return P.prev_idx(self, this_idx);
        }
        /// Return the index `n` places before the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_prev_idx(self: ILIST, this_idx: usize, n: usize) usize {
            return P.nth_prev_idx(self, this_idx, n);
        }
        /// Return `true` if the index is valid for the current state
        /// of the list, `false` otherwise
        pub fn idx_valid(self: ILIST, idx: usize) bool {
            return P.idx_valid(self, idx);
        }
        /// Return `true` if the range is valid for the current state
        /// of the list, `false` otherwise. The first index must
        /// come before or be equal to the last index, and all
        /// indexes in between must also be valid
        pub fn range_valid(self: ILIST, range: Range) bool {
            return P.range_valid(self, range);
        }
        /// Return whether the given index falls within the given range,
        /// inclusive
        pub fn idx_in_range(self: ILIST, range: Range, idx: usize) bool {
            return P.idx_in_range(self, range, idx);
        }
        /// Split a range roughly in half, returning an index
        /// as close to the true center point as possible.
        /// Implementations may choose not to return an index
        /// close to the actual middle of the range if
        /// finding that middle index is expensive
        pub fn split_range(self: ILIST, range: Range) usize {
            return P.split_range(self, range);
        }
        /// Return the number of indexes included within a range,
        /// inclusive of the last index
        pub fn range_len(self: ILIST, range: Range) usize {
            return P.range_len(self, range);
        }
        /// Return the value at the given index
        pub fn get(self: ILIST, idx: usize) T {
            return P.get(self, idx, self.alloc);
        }
        /// Return a pointer to the value at a given index
        pub fn get_ptr(self: ILIST, idx: usize) *T {
            return P.get_ptr(self, idx, self.alloc);
        }
        /// Set the value at the given index
        pub fn set(self: ILIST, idx: usize, val: T) void {
            return P.set(self, idx, val, self.alloc);
        }
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move(self: ILIST, old_idx: usize, new_idx: usize) void {
            return P.move(self, old_idx, new_idx, self.alloc);
        }
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move_range(self: ILIST, range: Range, new_first_idx: usize) void {
            return P.move_range(self, range, new_first_idx, self.alloc);
        }
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        pub fn try_ensure_free_slots(self: ILIST, count: usize) error{failed_to_grow_list}!void {
            return P.try_ensure_free_slots(self, count, self.alloc);
        }
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        pub fn shrink_cap_reserve_at_most(self: ILIST, reserve_at_most: usize) void {
            return P.shrink_cap_reserve_at_most(self, reserve_at_most, self.alloc);
        }
        /// Insert `n` value slots with undefined values at the given index,
        /// moving other items at or after that index to after the new ones.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn insert_slots_assume_capacity(self: ILIST, idx: usize, count: usize) Range {
            return P.insert_slots_assume_capacity(self, idx, count, self.alloc);
        }
        /// Append `n` value slots with undefined values at the end of the list.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn append_slots_assume_capacity(self: ILIST, count: usize) Range {
            return P.append_slots_assume_capacity(self, count, self.alloc);
        }
        /// Delete one value at given index
        pub fn delete(self: ILIST, idx: usize) void {
            return P.delete(self, idx, self.alloc);
        }
        /// Delete many values within given range, inclusive
        pub fn delete_range(self: ILIST, range: Range) void {
            return P.delete_range(self, range, self.alloc);
        }
        /// Set list to an empty state, but retain existing capacity, if possible
        pub fn clear(self: ILIST) void {
            return P.clear(self, self.alloc);
        }
        /// Set list to an empty state and return memory to allocator
        pub fn free(self: ILIST) void {
            return P.free(self, self.alloc);
        }

        pub fn is_empty(self: ILIST) bool {
            return P.is_empty(self, self.alloc);
        }
        pub fn try_first_idx(self: ILIST) ListError!usize {
            return P.try_first_idx(self);
        }
        pub fn try_last_idx(self: ILIST) ListError!usize {
            return P.try_last_idx(self);
        }
        pub fn try_next_idx(self: ILIST, this_idx: usize) ListError!usize {
            return P.try_next_idx(self, this_idx);
        }
        pub fn try_prev_idx(self: ILIST, this_idx: usize) ListError!usize {
            return P.try_prev_idx(self, this_idx);
        }
        pub fn try_nth_next_idx(self: ILIST, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_next_idx(self, this_idx, n);
        }
        pub fn try_nth_prev_idx(self: ILIST, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_prev_idx(self, this_idx, n);
        }
        pub fn try_get(self: ILIST, idx: usize) ListError!T {
            return P.try_get(self, idx, self.alloc);
        }
        pub fn try_get_ptr(self: ILIST, idx: usize) ListError!*T {
            return P.try_get_ptr(self, idx, self.alloc);
        }
        pub fn try_set(self: ILIST, idx: usize, val: T) ListError!void {
            return P.try_set(self, idx, val, self.alloc);
        }
        pub fn try_move(self: ILIST, old_idx: usize, new_idx: usize) ListError!void {
            return P.try_move(self, old_idx, new_idx, self.alloc);
        }
        pub fn try_move_range(self: ILIST, range: Range, new_first_idx: usize) ListError!void {
            return P.try_move_range(self, range, new_first_idx, self.alloc);
        }

        pub fn nth_idx(self: ILIST, n: usize) usize {
            return P.nth_idx(self, n);
        }
        pub fn nth_idx_from_end(self: ILIST, n: usize) usize {
            return P.nth_idx_from_end(self, n);
        }
        pub fn try_nth_idx(self: ILIST, n: usize) ListError!usize {
            return P.try_nth_idx(self, n);
        }
        pub fn try_nth_idx_from_end(self: ILIST, n: usize) ListError!usize {
            return P.try_nth_idx_from_end(self, n);
        }
        pub fn get_last(self: ILIST) T {
            return P.get_last(self, self.alloc);
        }
        pub fn try_get_last(self: ILIST) ListError!T {
            return P.try_get_last(self, self.alloc);
        }
        pub fn get_last_ptr(self: ILIST) *T {
            return P.get_last_ptr(self, self.alloc);
        }
        pub fn try_get_last_ptr(self: ILIST) ListError!*T {
            return P.try_get_last_ptr(self, self.alloc);
        }
        pub fn set_last(self: ILIST, val: T) void {
            return P.set_last(self, val, self.alloc);
        }
        pub fn try_set_last(self: ILIST, val: T) ListError!void {
            return P.try_set_last(self, val, self.alloc);
        }
        pub fn get_first(self: ILIST) T {
            return P.get_first(self, self.alloc);
        }
        pub fn try_get_first(self: ILIST) ListError!T {
            return P.try_get_first(self, self.alloc);
        }
        pub fn get_first_ptr(self: ILIST) *T {
            return P.get_first_ptr(self, self.alloc);
        }
        pub fn try_get_first_ptr(self: ILIST) ListError!*T {
            return P.try_get_first_ptr(self, self.alloc);
        }
        pub fn set_first(self: ILIST, val: T) void {
            return P.set_first(self, val, self.alloc);
        }
        pub fn try_set_first(self: ILIST, val: T) ListError!void {
            return P.try_set_first(self, val, self.alloc);
        }
        pub fn get_nth(self: ILIST, n: usize) T {
            return P.get_nth(self, n, self.alloc);
        }
        pub fn try_get_nth(self: ILIST, n: usize) ListError!T {
            return P.try_get_nth(self, n, self.alloc);
        }
        pub fn get_nth_ptr(self: ILIST, n: usize) *T {
            return P.get_nth_ptr(self, n, self.alloc);
        }
        pub fn try_get_nth_ptr(self: ILIST, n: usize) ListError!*T {
            return P.try_get_nth_ptr(self, n, self.alloc);
        }
        pub fn set_nth(self: ILIST, n: usize, val: T) void {
            return P.set_nth(self, n, val, self.alloc);
        }
        pub fn try_set_nth(self: ILIST, n: usize, val: T) ListError!void {
            return P.try_set_nth(self, n, val, self.alloc);
        }
        pub fn get_nth_from_end(self: ILIST, n: usize) T {
            return P.get_nth_from_end(self, n, self.alloc);
        }
        pub fn try_get_nth_from_end(self: ILIST, n: usize) ListError!T {
            return P.try_get_nth_from_end(self, n, self.alloc);
        }
        pub fn get_nth_ptr_from_end(self: ILIST, n: usize) *T {
            return P.get_nth_ptr_from_end(self, n, self.alloc);
        }
        pub fn try_get_nth_ptr_from_end(self: ILIST, n: usize) ListError!*T {
            return P.try_get_nth_ptr_from_end(self, n, self.alloc);
        }
        pub fn set_nth_from_end(self: ILIST, n: usize, val: T) void {
            return P.set_nth_from_end(self, n, val, self.alloc);
        }
        pub fn try_set_nth_from_end(self: ILIST, n: usize, val: T) ListError!void {
            return P.try_set_nth_from_end(self, n, val, self.alloc);
        }
        pub fn set_from(self: ILIST, self_idx: usize, source: ILIST, source_idx: usize) void {
            return P.set_from(self, self_idx, self.alloc, source, source_idx, source.alloc);
        }
        pub fn try_set_from(self: ILIST, self_idx: usize, source: ILIST, source_idx: usize) ListError!void {
            return P.try_set_from(self, self_idx, self.alloc, source, source_idx, source.alloc);
        }
        pub fn exchange(self: ILIST, self_idx: usize, other: ILIST, other_idx: usize) void {
            return P.exchange(self, self_idx, self.alloc, other, other_idx, other.alloc);
        }
        pub fn try_exchange(self: ILIST, self_idx: usize, other: ILIST, other_idx: usize) ListError!void {
            return P.try_exchange(self, self_idx, self.alloc, other, other_idx, other.alloc);
        }
        pub fn overwrite(self: ILIST, source_idx: usize, dest_idx: usize) void {
            return P.overwrite(self, source_idx, dest_idx, self.alloc);
        }
        pub fn try_overwrite(self: ILIST, source_idx: usize, dest_idx: usize) ListError!void {
            return P.try_overwrite(self, source_idx, dest_idx, self.alloc);
        }
        pub fn reverse(self: ILIST, range: P.PartialRangeIter) void {
            return P.reverse(self, range, self.alloc);
        }
        pub fn rotate(self: ILIST, range: P.PartialRangeIter, delta: isize) void {
            return P.rotate(self, range, delta, self.alloc);
        }
        pub fn fill(self: ILIST, range: P.PartialRangeIter, val: T) usize {
            return P.fill(self, range, val, self.alloc);
        }
        pub fn copy(source: P.RangeIter, dest: P.RangeIter) usize {
            return P.copy(source.with_alloc(source.list.alloc), dest.with_alloc(dest.list.alloc));
        }
        pub fn copy_to(self: ILIST, self_range: P.PartialRangeIter, dest: P.RangeIter) usize {
            return P.copy_to(self, self_range.with_alloc(self.list.alloc), dest.with_alloc(dest.list.alloc));
        }
        pub fn is_sorted(self: ILIST, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.is_sorted(self, range.with_alloc(range.list.alloc), greater_than, self.alloc);
        }
        pub fn is_sorted_implicit(self: ILIST, range: P.PartialRangeIter) bool {
            return P.is_sorted_implicit(self, range.with_alloc(range.list.alloc), self.alloc);
        }
        pub fn insertion_sort(self: ILIST, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.insertion_sort(self, range.with_alloc(range.list.alloc), greater_than, self.alloc);
        }
        pub fn insertion_sort_implici(self: ILIST, range: P.PartialRangeIter) bool {
            return P.insertion_sort_implicit(self, range.with_alloc(range.list.alloc), self.alloc);
        }
        pub fn quicksort(self: ILIST, range: P.PartialRangeIter, greater_than: *const P.CompareFunc, less_than: *const P.CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort(self, range.with_alloc(range.list.alloc), self.alloc, greater_than, less_than, PARTITION_IDX, partition_stack);
        }
        pub fn quicksort_implicit(self: ILIST, range: P.PartialRangeIter, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort_implicit(self, range.with_alloc(range.list.alloc), self.alloc, PARTITION_IDX, partition_stack);
        }
        pub fn range_iterator(self: ILIST, range: P.PartialRangeIter) P.RangeIter {
            return P.range_iterator(self, range.with_alloc(self.alloc));
        }
        pub fn for_each(
            self: ILIST,
            range: P.PartialRangeIter,
            userdata: anytype,
            action: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.for_each(self, range.with_alloc(self.alloc), userdata, action, filter, filter_func);
        }
        pub fn filter_indexes(
            self: ILIST,
            range: P.PartialRangeIter,
            userdata: anytype,
            filter_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime OUT_IDX: type,
            out_list: IList(OUT_IDX),
        ) usize {
            return P.filter_indexes(self, range.with_alloc(self.alloc), userdata, filter_func, OUT_IDX, out_list);
        }
        pub fn transform_values(
            self: ILIST,
            range: P.PartialRangeIter,
            userdata: anytype,
            comptime OUT_TYPE: type,
            transform_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            out_list: IList(OUT_TYPE),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.transform_values(self, range.with_alloc(self.alloc), userdata, OUT_TYPE, transform_func, out_list, filter, filter_func);
        }
        pub fn accumulate_result(
            self: ILIST,
            range: P.PartialRangeIter,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: P.IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) @TypeOf(initial_accumulation) {
            return P.accumulate_result(self, range.with_alloc(self.alloc), initial_accumulation, userdata, accumulate_func, filter, filter_func);
        }
        pub fn ensure_free_slots(self: ILIST, count: usize) void {
            return P.ensure_free_slots(self, count, self.alloc);
        }
        pub fn append_slots(self: ILIST, count: usize) Range {
            return P.append_slots(self, count, self.alloc);
        }
        pub fn try_append_slots(self: ILIST, count: usize) ListError!Range {
            return P.try_append_slots(self, count, self.alloc);
        }
        pub fn append_zig_slice(self: ILIST, slice: []const T) Range {
            return P.append_zig_slice(self, slice, self.alloc);
        }
        pub fn try_append_zig_slice(self: ILIST, slice: []const T) ListError!Range {
            return P.try_append_zig_slice(self, slice, self.alloc);
        }
        pub fn append(self: ILIST, val: T) usize {
            return P.append(self, val, self.alloc);
        }
        pub fn try_append(self: ILIST, val: T) ListError!usize {
            return P.try_append(self, val, self.alloc);
        }
        pub fn append_many(self: ILIST, list_range: P.RangeIter) Range {
            return P.append_many(self, self.alloc, list_range.with_alloc(list_range.list.alloc));
        }
        pub fn try_append_many(self: ILIST, list_range: P.RangeIter) ListError!Range {
            return P.try_append_many(self, self.alloc, list_range.with_alloc(list_range.list.alloc));
        }
        pub fn insert_slots(self: ILIST, idx: usize, count: usize) Range {
            return P.insert_slots(self, idx, count, self.alloc);
        }
        pub fn try_insert_slots(self: ILIST, idx: usize, count: usize) ListError!Range {
            return P.try_insert_slots(self, idx, count, self.alloc);
        }
        pub fn insert_zig_slice(self: ILIST, idx: usize, slice: []T) Range {
            return P.insert_zig_slice(self, idx, slice, self.alloc);
        }
        pub fn try_insert_zig_slice(self: ILIST, idx: usize, slice: []T) ListError!Range {
            return P.try_insert_zig_slice(self, idx, slice, self.alloc);
        }
        pub fn insert(self: ILIST, idx: usize, val: T) usize {
            return P.insert(self, idx, val, self.alloc);
        }
        pub fn try_insert(self: ILIST, idx: usize, val: T) ListError!usize {
            return P.try_insert(self, idx, val, self.alloc);
        }
        pub fn insert_many(self: ILIST, idx: usize, list_range: P.RangeIter) Range {
            return P.insert_many(self, idx, self.alloc, list_range.with_alloc(list_range.list.alloc));
        }
        pub fn try_insert_many(self: ILIST, idx: usize, list_range: P.RangeIter) ListError!Range {
            return P.try_insert_many(self, idx, self.alloc, list_range.with_alloc(list_range.list.alloc));
        }
        pub fn try_delete_range(self: ILIST, range: Range) ListError!void {
            return P.try_delete_range(self, range, self.alloc);
        }
        pub fn delete_many(self: ILIST, range: P.PartialRangeIter) void {
            return P.delete_many(self, range.with_alloc(self.alloc));
        }
        pub fn try_delete_many(self: ILIST, range: P.PartialRangeIter) ListError!void {
            return P.try_delete_many(self, range.with_alloc(self.alloc));
        }
        pub fn try_delete(self: ILIST, idx: usize) ListError!void {
            return P.try_delete(self, idx, self.alloc);
        }
        pub fn swap_delete(self: ILIST, idx: usize) void {
            return P.swap_delete(self, idx, self.alloc);
        }
        pub fn try_swap_delete(self: ILIST, idx: usize) ListError!void {
            return P.try_swap_delete(self, idx, self.alloc);
        }
        pub fn swap_delete_many(self: ILIST, range: P.PartialRangeIter) void {
            return P.swap_delete_many(self, range.with_alloc(self.alloc));
        }
        pub fn try_swap_delete_many(self: ILIST, range: P.PartialRangeIter) ListError!void {
            return P.try_swap_delete_many(self, range.with_alloc(self.alloc));
        }
        pub fn remove_range(self: ILIST, self_range: P.PartialRangeIter, dest: ILIST) Range {
            return P.remove_range(self, self_range.with_alloc(self.alloc), dest, dest.alloc);
        }
        pub fn try_remove_range(self: ILIST, self_range: P.PartialRangeIter, dest: ILIST) ListError!Range {
            return P.try_remove_range(self, self_range.with_alloc(self.alloc), dest, dest.alloc);
        }
        pub fn remove(self: ILIST, idx: usize) T {
            return P.remove(self, idx, self.alloc);
        }
        pub fn try_remove(self: ILIST, idx: usize) ListError!T {
            return P.try_remove(self, idx, self.alloc);
        }
        pub fn swap_remove(self: ILIST, idx: usize) T {
            return P.swap_remove(self, idx, self.alloc);
        }
        pub fn try_swap_remove(self: ILIST, idx: usize) ListError!T {
            return P.try_swap_remove(self, idx, self.alloc);
        }
        pub fn pop(self: ILIST) T {
            return P.pop(self, self.alloc);
        }
        pub fn try_pop(self: ILIST) ListError!T {
            return P.try_pop(self, self.alloc);
        }
        pub fn pop_many(self: ILIST, count: usize, dest: ILIST) Range {
            return P.pop_many(self, count, self.alloc, dest, dest.alloc);
        }
        pub fn try_pop_many(self: ILIST, count: usize, dest: ILIST) ListError!Range {
            return P.try_pop_many(self, count, self.alloc, dest, dest.alloc);
        }
        pub fn sorted_insert(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            return P.sorted_insert(self, self.alloc, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_implicit(self: ILIST, val: T) usize {
            return P.sorted_insert_implicit(self, val, self.alloc);
        }
        pub fn sorted_insert_index(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResult {
            return P.sorted_insert_index(self, self.alloc, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_index_implicit(self: ILIST, val: T) InsertIndexResult {
            return P.sorted_insert_index_implicit(self, val, self.alloc);
        }
        pub fn sorted_search(
            self: ILIST,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResult {
            return P.sorted_search(self, self.alloc, val, equal_func, greater_than_func);
        }
        pub fn sorted_search_implicit(self: ILIST, val: T) SearchResult {
            return P.sorted_search_implicit(self, val, self.alloc);
        }
        pub fn sorted_set_and_resort(self: ILIST, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            return P.sorted_set_and_resort(self, idx, val, self.alloc, greater_than_func);
        }
        pub fn sorted_set_and_resort_implicit(self: ILIST, idx: usize, val: T) usize {
            return P.sorted_set_and_resort_implicit(self, idx, val, self.alloc);
        }
        pub fn search(self: ILIST, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) SearchResult {
            return P.search(self, find_val, self.alloc, equal_func);
        }
        pub fn search_implicit(self: ILIST, find_val: anytype) SearchResult {
            return P.search_implicit(self, find_val, self.alloc);
        }
        pub fn add_get(self: ILIST, idx: usize, val: anytype) T {
            return P.add_get(self, idx, val, self.alloc);
        }
        pub fn try_add_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_add_get(self, idx, val, self.alloc);
        }
        pub fn add_set(self: ILIST, idx: usize, val: anytype) void {
            return P.add_set(self, idx, val, self.alloc);
        }
        pub fn try_add_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_add_set(self, idx, val, self.alloc);
        }
        pub fn subtract_get(self: ILIST, idx: usize, val: anytype) T {
            return P.subtract_get(self, idx, val, self.alloc);
        }
        pub fn try_subtract_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_subtract_get(self, idx, val, self.alloc);
        }
        pub fn subtract_set(self: ILIST, idx: usize, val: anytype) void {
            return P.subtract_set(self, idx, val, self.alloc);
        }
        pub fn try_subtract_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_subtract_set(self, idx, val, self.alloc);
        }
        pub fn multiply_get(self: ILIST, idx: usize, val: anytype) T {
            return P.multiply_get(self, idx, val, self.alloc);
        }
        pub fn try_multiply_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_multiply_get(self, idx, val, self.alloc);
        }
        pub fn multiply_set(self: ILIST, idx: usize, val: anytype) void {
            return P.multiply_set(self, idx, val, self.alloc);
        }
        pub fn try_multiply_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_multiply_set(self, idx, val, self.alloc);
        }
        pub fn divide_get(self: ILIST, idx: usize, val: anytype) T {
            return P.divide_get(self, idx, val, self.alloc);
        }
        pub fn try_divide_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_divide_get(self, idx, val, self.alloc);
        }
        pub fn divide_set(self: ILIST, idx: usize, val: anytype) void {
            return P.divide_set(self, idx, val, self.alloc);
        }
        pub fn try_divide_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_divide_set(self, idx, val, self.alloc);
        }
        pub fn modulo_get(self: ILIST, idx: usize, val: anytype) T {
            return P.modulo_get(self, idx, val, self.alloc);
        }
        pub fn try_modulo_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_modulo_get(self, idx, val, self.alloc);
        }
        pub fn modulo_set(self: ILIST, idx: usize, val: anytype) void {
            return P.modulo_set(self, idx, val, self.alloc);
        }
        pub fn try_modulo_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_modulo_set(self, idx, val, self.alloc);
        }
        pub fn mod_rem_get(self: ILIST, idx: usize, val: anytype) T {
            return P.mod_rem_get(self, idx, val, self.alloc);
        }
        pub fn try_mod_rem_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_mod_rem_get(self, idx, val, self.alloc);
        }
        pub fn bit_and_get(self: ILIST, idx: usize, val: anytype) T {
            return P.bit_and_get(self, idx, val, self.alloc);
        }
        pub fn try_bit_and_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_bit_and_get(self, idx, val, self.alloc);
        }
        pub fn bit_and_set(self: ILIST, idx: usize, val: anytype) void {
            return P.bit_and_set(self, idx, val, self.alloc);
        }
        pub fn try_bit_and_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_bit_and_set(self, idx, val, self.alloc);
        }
        pub fn bit_or_get(self: ILIST, idx: usize, val: anytype) T {
            return P.bit_or_get(self, idx, val, self.alloc);
        }
        pub fn try_bit_or_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_bit_or_get(self, idx, val, self.alloc);
        }
        pub fn bit_or_set(self: ILIST, idx: usize, val: anytype) void {
            return P.bit_or_set(self, idx, val, self.alloc);
        }
        pub fn try_bit_or_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_bit_or_set(self, idx, val, self.alloc);
        }
        pub fn bit_xor_get(self: ILIST, idx: usize, val: anytype) T {
            return P.bit_xor_get(self, idx, val, self.alloc);
        }
        pub fn try_bit_xor_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_bit_xor_get(self, idx, val, self.alloc);
        }
        pub fn bit_xor_set(self: ILIST, idx: usize, val: anytype) void {
            return P.bit_xor_set(self, idx, val, self.alloc);
        }
        pub fn try_bit_xor_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_bit_xor_set(self, idx, val, self.alloc);
        }
        pub fn bit_invert_get(self: ILIST, idx: usize) T {
            return P.bit_invert_get(self, idx, self.alloc);
        }
        pub fn try_bit_invert_get(self: ILIST, idx: usize) ListError!T {
            return P.try_bit_invert_get(self, idx, self.alloc);
        }
        pub fn bit_invert_set(self: ILIST, idx: usize) void {
            return P.bit_invert_set(self, idx, self.alloc);
        }
        pub fn try_bit_invert_set(self: ILIST, idx: usize) ListError!void {
            return P.try_bit_invert_set(self, idx, self.alloc);
        }
        pub fn bool_and_get(self: ILIST, idx: usize, val: bool) T {
            return P.bool_and_get(self, idx, val, self.alloc);
        }
        pub fn try_bool_and_get(self: ILIST, idx: usize, val: bool) ListError!T {
            return P.try_bool_and_get(self, idx, val, self.alloc);
        }
        pub fn bool_and_set(self: ILIST, idx: usize, val: bool) void {
            return P.bool_and_set(self, idx, val, self.alloc);
        }
        pub fn try_bool_and_set(self: ILIST, idx: usize, val: bool) ListError!void {
            return P.try_bool_and_set(self, idx, val, self.alloc);
        }
        pub fn bool_or_get(self: ILIST, idx: usize, val: bool) T {
            return P.bool_or_get(self, idx, val, self.alloc);
        }
        pub fn try_bool_or_get(self: ILIST, idx: usize, val: bool) ListError!T {
            return P.try_bool_or_get(self, idx, val, self.alloc);
        }
        pub fn bool_or_set(self: ILIST, idx: usize, val: bool) void {
            return P.bool_or_set(self, idx, val, self.alloc);
        }
        pub fn try_bool_or_set(self: ILIST, idx: usize, val: bool) ListError!void {
            return P.try_bool_or_set(self, idx, val, self.alloc);
        }
        pub fn bool_xor_get(self: ILIST, idx: usize, val: bool) T {
            return P.bool_xor_get(self, idx, val, self.alloc);
        }
        pub fn try_bool_xor_get(self: ILIST, idx: usize, val: bool) ListError!T {
            return P.try_bool_xor_get(self, idx, val, self.alloc);
        }
        pub fn bool_xor_set(self: ILIST, idx: usize, val: bool) void {
            return P.bool_xor_set(self, idx, val, self.alloc);
        }
        pub fn try_bool_xor_set(self: ILIST, idx: usize, val: bool) ListError!void {
            return P.try_bool_xor_set(self, idx, val, self.alloc);
        }
        pub fn bool_invert_get(self: ILIST, idx: usize) T {
            return P.bool_invert_get(self, idx, self.alloc);
        }
        pub fn try_bool_invert_get(self: ILIST, idx: usize) ListError!T {
            return P.try_bool_invert_get(self, idx, self.alloc);
        }
        pub fn bool_invert_set(self: ILIST, idx: usize) void {
            return P.bool_invert_set(self, idx, self.alloc);
        }
        pub fn try_bool_invert_set(self: ILIST, idx: usize) ListError!void {
            return P.try_bool_invert_set(self, idx, self.alloc);
        }
        pub fn bit_l_shift_get(self: ILIST, idx: usize, val: anytype) T {
            return P.bit_l_shift_get(self, idx, val, self.alloc);
        }
        pub fn try_bit_l_shift_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_bit_l_shift_get(self, idx, val, self.alloc);
        }
        pub fn bit_l_shift_set(self: ILIST, idx: usize, val: anytype) void {
            return P.bit_l_shift_set(self, idx, val, self.alloc);
        }
        pub fn try_bit_l_shift_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_bit_l_shift_set(self, idx, val, self.alloc);
        }
        pub fn bit_r_shift_get(self: ILIST, idx: usize, val: anytype) T {
            return P.bit_r_shift_get(self, idx, val, self.alloc);
        }
        pub fn try_bit_r_shift_get(self: ILIST, idx: usize, val: anytype) ListError!T {
            return P.try_bit_r_shift_get(self, idx, val, self.alloc);
        }
        pub fn bit_r_shift_set(self: ILIST, idx: usize, val: anytype) void {
            return P.bit_r_shift_set(self, idx, val, self.alloc);
        }
        pub fn try_bit_r_shift_set(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_bit_r_shift_set(self, idx, val, self.alloc);
        }
        pub fn less_than_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.less_than_get(self, idx, val, self.alloc);
        }
        pub fn try_less_than_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_get(self, idx, val, self.alloc);
        }
        pub fn less_than_equal_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.less_than_equal_get(self, idx, val, self.alloc);
        }
        pub fn try_less_than_equal_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_equal_get(self, idx, val, self.alloc);
        }
        pub fn greater_than_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.greater_than_get(self, idx, val, self.alloc);
        }
        pub fn try_greater_than_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_get(self, idx, val, self.alloc);
        }
        pub fn greater_than_equal_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.greater_than_equal_get(self, idx, val, self.alloc);
        }
        pub fn try_greater_than_equal_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_equal_get(self, idx, val, self.alloc);
        }
        pub fn equals_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.equals_get(self, idx, val, self.alloc);
        }
        pub fn try_equals_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_equals_get(self, idx, val, self.alloc);
        }
        pub fn not_equals_get(self: ILIST, idx: usize, val: anytype) bool {
            return P.not_equals_get(self, idx, val, self.alloc);
        }
        pub fn try_not_equals_get(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_not_equals_get(self, idx, val, self.alloc);
        }
        pub fn get_min_in_range(self: ILIST, range: P.PartialRangeIter) P.Item {
            return P.get_min_in_range(self, range.with_alloc(self.alloc));
        }
        pub fn try_get_min_in_range(self: ILIST, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_min_in_range(self, range.with_alloc(self.alloc));
        }
        pub fn get_max_in_range(self: ILIST, range: P.PartialRangeIter) P.Item {
            return P.get_max_in_range(self, range.with_alloc(self.alloc));
        }
        pub fn try_get_max_in_range(self: ILIST, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_max_in_range(self, range.with_alloc(self.alloc));
        }
        pub fn get_clamped(self: ILIST, idx: usize, min: T, max: T) T {
            return P.get_clamped(self, idx, min, max, self.alloc);
        }
        pub fn try_get_clamped(self: ILIST, idx: usize, min: T, max: T) ListError!T {
            return P.try_get_clamped(self, idx, min, max, self.alloc);
        }
        pub fn set_clamped(self: ILIST, idx: usize, min: T, max: T) void {
            return P.set_clamped(self, idx, min, max, self.alloc);
        }
        pub fn try_set_clamped(self: ILIST, idx: usize, min: T, max: T) ListError!void {
            return P.try_set_clamped(self, idx, min, max, self.alloc);
        }
        pub fn set_report_change(self: ILIST, idx: usize, val: T) bool {
            return P.set_report_change(self, idx, val, self.alloc);
        }
        pub fn try_set_report_change(self: ILIST, idx: usize, val: T) bool {
            return P.try_set_report_change(self, idx, val, self.alloc);
        }
        pub fn get_unsafe_cast(self: ILIST, idx: usize, comptime TT: type) TT {
            return P.get_unsafe_cast(self, idx, TT, self.alloc);
        }
        pub fn try_get_unsafe_cast(self: ILIST, idx: usize, comptime TT: type) ListError!TT {
            return P.try_get_unsafe_cast(self, idx, TT, self.alloc);
        }
        pub fn get_unsafe_ptr_cast(self: ILIST, idx: usize, comptime TT: type) *TT {
            return P.get_unsafe_ptr_cast(self, idx, TT, self.alloc);
        }
        pub fn try_get_unsafe_ptr_cast(self: ILIST, idx: usize, comptime TT: type) ListError!*TT {
            return P.try_get_unsafe_ptr_cast(self, idx, TT, self.alloc);
        }
        pub fn set_unsafe_cast(self: ILIST, idx: usize, val: anytype) void {
            return P.set_unsafe_cast(self, idx, val, self.alloc);
        }
        pub fn try_set_unsafe_cast(self: ILIST, idx: usize, val: anytype) ListError!void {
            return P.try_set_unsafe_cast(self, idx, val, self.alloc);
        }
        pub fn set_unsafe_cast_report_change(self: ILIST, idx: usize, val: anytype) bool {
            return P.set_unsafe_cast_report_change(self, idx, val, self.alloc);
        }
        pub fn try_set_unsafe_cast_report_change(self: ILIST, idx: usize, val: anytype) ListError!bool {
            return P.try_set_unsafe_cast_report_change(self, idx, val, self.alloc);
        }
    };
}

pub fn list_from_slice_no_alloc(comptime T: type, slice_ptr: *[]T) IList(T) {
    return SliceAdapter(T).interface_no_alloc(slice_ptr);
}
pub fn list_from_slice(comptime T: type, slice_ptr: *[]T, alloc: Allocator) IList(T) {
    return SliceAdapter(T).interface(slice_ptr, alloc);
}

// pub const IndexSourceMode = enum(u8) {
//     range,
//     list,
// };

// pub const IndexSource = union(IndexSourceMode) {
//     range: Range,
//     list: IList(usize),
// };
