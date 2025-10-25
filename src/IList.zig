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

pub const _Fuzzer = @import("./IList_Fuzz.zig");
pub const _Bencher = @import("./IList_Bench.zig");

// pub const Flags = _Flags.Flags(enum(u32) {
//     goto_nth_item_in_constant_time,
//     consecutive_indexes_in_order,
//     all_indexes_zero_to_less_than_len_valid,
// }, enum(u32) {});

pub const ListError = error{
    list_is_empty,
    too_few_items_in_list,
    index_out_of_bounds,
    invalid_index,
    invalid_range,
    no_items_after,
    no_items_before,
    failed_to_grow_list,
    replace_dest_idx_list_smaller_than_source,
    iterator_is_empty,
};

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
            try_ensure_free_slots: *const fn (object: *anyopaque, count: usize, alloc: Allocator) bool = Types.unimplemented_3_params("IList.vtable.try_ensure_free_slots", *anyopaque, usize, Allocator, bool),
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
            /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
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
        pub fn iterator_state(self: ILIST, self_range: IteratorState(T).Partial) IteratorState(T).Full {
            return self_range.to_iter(self);
        }
        pub fn idx_iterator(self: ILIST, range: Range, start: usize) IteratorState(T).IndexIter {
            return IteratorState(T).IndexIter.new(self, range, start);
        }
        pub const Reader = struct {
            src: ILIST,
            buf: ?[]T = null,
            src_pos: usize,
            buf_start: usize = 0,
            buf_end: usize = 0,

            pub fn new(src: ILIST, buf: ?[]T) Reader {
                return Reader{
                    .src = src,
                    .buf = buf,
                    .src_pos = src.first_idx(),
                };
            }

            pub fn read_to(self: *Reader, out: IteratorState(T).Full) CountResult {
                var result = CopyResult{};
                if (self.buf) |buf| {
                    var buf_result = CopyResult{};
                    var count: usize = 0;
                    while (!result.full_dest_copied and !buf_result.full_source_copied) {
                        if (self.buf_start == self.buf_end) {
                            self.buf_start = 0;
                            const buf_list = list_from_slice_no_alloc(T, &buf);
                            buf_result = self.src.copy_from_to(.idx_to_end(self.src_pos), .use_range(buf_list, .new_range(self.buf_start, buf.len - 1)));
                            self.src_pos = self.src.next_idx(buf_result.source_range.last_idx);
                            self.buf_end = buf_result.dest_range.last_idx + 1;
                            if (buf_result.count == 0) {
                                return out.count_result();
                            }
                        }
                        result = buf.copy_from_to(.new_range(self.buf_start, self.buf_end - 1), out);
                        count += result.count;
                        if (result.full_source_copied) {
                            self.buf_empty = true;
                        }
                    }
                    return count;
                } else {
                    result = self.src.copy_from_to(.idx_to_end(self.src_pos), out);
                    self.src_pos = self.src.next_idx(result.source_range.last_idx);
                    return out.count_result();
                }
            }

            pub fn peek_to(self: *Reader, out: ILIST) CountResult {
                const pos = self.src_pos;
                const res = self.read_to(out);
                self.src_pos = pos;
                self.buf_empty = true;
                return res;
            }

            fn _discard_action(item: IteratorState(T).Item, dd: *_discard_data) bool {
                dd.left -= 1;
                dd.last = item.idx;
                if (dd.left == 0 or item.list.last_idx() == item.idx) {
                    return false;
                }
                return true;
            }

            const _discard_data = struct {
                left: usize,
                last: usize,
            };

            pub fn discard(self: *Reader, count: usize) void {
                var left: usize = count;

                if (self.buf) |buf| {
                    if (!self.buf_empty) {
                        if (buf.prefer_linear_ops()) {
                            var dd = _discard_data{ .left = count, .last = self.buf_pos };
                            buf.for_each(.idx_to_end(self.buf_pos), &dd, _discard_action);
                            left = dd.left;
                        } else {}
                    }
                }
                self.src_pos = self.src.nth_next_idx(self.src_pos, count);
            }
        };
        pub const CompareFunc = fn (left_or_this: T, right_or_test: T) bool;
        pub const IIdxList = IList(usize, *usize, usize);
        pub const IListList = IList(ILIST, *ILIST, usize);
        pub fn prefer_linear_ops(self: ILIST) bool {
            return self.vtable.prefer_linear_ops;
        }
        pub fn consecutive_indexes_in_order(self: ILIST) bool {
            return self.vtable.consecutive_indexes_in_order;
        }
        pub fn all_indexes_less_than_len_valid(self: ILIST) bool {
            return self.vtable.all_indexes_zero_to_len_valid;
        }
        pub fn ensure_free_doesnt_change_cap(self: ILIST) bool {
            return self.vtable.ensure_free_doesnt_change_cap;
        }

        /// Return `true` if the given index is a valid index for the list, `false` otherwise
        pub fn idx_valid(self: ILIST, idx: usize) bool {
            return self.vtable.idx_valid(self.object, idx);
        }
        /// Return `true` if the given range (inclusive) is valid for the list, `false` otherwise
        pub fn range_valid(self: ILIST, range: Range) bool {
            return self.vtable.range_valid(self.object, range);
        }
        /// Return `true` if the given index is located within the given range (inclusive of both ends)
        pub fn idx_in_range(self: ILIST, range: Range, idx: usize) bool {
            return self.vtable.idx_in_range(self.object, range, idx);
        }
        /// Split an index range (roughly) in half, returning the index in the middle of the range
        ///
        /// Assumes `range_valid(first_idx, last_idx) == true`, and if so,
        /// the returned index MUST also be valid and MUST be between or equal to the first and/or last index
        ///
        /// The implementation should endeavor to return an index as close to the true middle index
        /// as possible, but it is not required to as long as the returned index IS between or equal to
        /// the first and/or last indexes. HOWEVER, some algorithms will have inconsitent performance
        /// if the returned index is far from the true middle index
        pub fn split_range(self: ILIST, range: Range) usize {
            return self.vtable.split_range(self.object, range);
        }
        /// get the value at the provided index
        pub fn get(self: ILIST, idx: usize) T {
            return self.vtable.get(self.object, idx, self.alloc);
        }
        /// get a pointer to the value at the provided index
        pub fn get_ptr(self: ILIST, idx: usize) *T {
            return self.vtable.get_ptr(self.object, idx, self.alloc);
        }
        /// set the value at the provided index to the given value
        pub fn set(self: ILIST, idx: usize, val: T) void {
            self.vtable.set(self.object, idx, val, self.alloc);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn move(self: ILIST, old_idx: usize, new_idx: usize) void {
            self.vtable.move(self.object, old_idx, new_idx, self.alloc);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn try_move(self: ILIST, old_idx: usize, new_idx: usize) ListError!void {
            if (!self.idx_valid(old_idx) or !self.idx_valid(new_idx)) {
                return ListError.invalid_index;
            }
            self.vtable.move(self.object, old_idx, new_idx);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn move_range(self: ILIST, range: Range, new_first_idx: usize) void {
            self.vtable.move_range(self.object, range, new_first_idx, self.alloc);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn try_move_range(self: ILIST, first_idx_: usize, last_idx_: usize, new_first_idx: usize) ListError!void {
            if (!self.range_valid(first_idx_, last_idx_)) {
                return ListError.invalid_range;
            }
            if (!self.idx_valid(new_first_idx)) {
                return ListError.invalid_index;
            }
            const between = self.range_len(first_idx_, last_idx_);
            const new_last_idx = self.nth_next_idx(new_first_idx, between - 1);
            if (!self.idx_valid(new_last_idx)) {
                return ListError.index_out_of_bounds;
            }
            self.vtable.move_range(self.object, first_idx_, last_idx_, new_first_idx);
        }
        /// Return the first index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn first_idx(self: ILIST) usize {
            return self.vtable.first_idx(self.object);
        }
        /// Return the last index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn last_idx(self: ILIST) usize {
            return self.vtable.last_idx(self.object);
        }
        /// Return the next index after the current index in the slice.
        ///
        /// If the given index is invalid or no next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn next_idx(self: ILIST, this_idx: usize) usize {
            return self.vtable.next_idx(self.object, this_idx);
        }
        /// Return the index `n` places after the current index in the slice.
        ///
        /// If the given index is invalid or no nth next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_next_idx(self: ILIST, this_idx: usize, n: usize) usize {
            return self.vtable.nth_next_idx(self.object, this_idx, n);
        }
        /// Return the prev index before the current index in the slice.
        ///
        /// If the given index is invalid or no prev index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn prev_idx(self: ILIST, this_idx: usize) usize {
            return self.vtable.prev_idx(self.object, this_idx);
        }
        /// Return the index `n` places before the current index in the slice.
        ///
        /// If the given index is invalid or no nth previous index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_prev_idx(self: ILIST, this_idx: usize, n: usize) usize {
            return self.vtable.nth_prev_idx(self.object, this_idx, n);
        }
        /// Return the current number of values in the slice/list
        ///
        /// It is not guaranteed that all indexes less than `len` are valid for the slice,
        /// unless `all_indexes_less_than_len_valid() == true`
        pub fn len(self: ILIST) usize {
            return self.vtable.len(self.object);
        }
        /// Return the number of items between (and including) `first_idx` and `last_idx`
        ///
        /// `slice.range_len(Range{.first_idx: slice.first_idx(), .last_idx: slice.last_idx()})` MUST equal `slice.len()`
        pub fn range_len(self: ILIST, range: Range) usize {
            return self.vtable.range_len(self.object, range);
        }
        /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
        /// the memory or performing any other expensive reorganization procedure
        ///
        /// If free space cannot be ensured and attempting to add `count` more items
        /// will definitely fail or cause undefined behaviour, `ok == false`
        pub fn try_ensure_free_slots(self: ILIST, count: usize) bool {
            return self.vtable.try_ensure_free_slots(self.object, count, self.alloc);
        }
        /// Insert `n` new slots directly before existing index, shifting all existing items
        /// at and after that index forward.
        ///
        /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
        /// not match the insert index, depending on the implementation behavior
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function with a valid insert idx should not fail
        pub fn insert_slots_assume_capacity(self: ILIST, idx: usize, count: usize) Range {
            return self.vtable.insert_slots_assume_capacity(self.object, idx, count, self.alloc);
        }
        /// Append `n` new slots at the end of the list.
        ///
        /// Returns the first new slot and the last new slot, inclusive
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function should not fail
        pub fn append_slots_assume_capacity(self: ILIST, count: usize) Range {
            return self.vtable.append_slots_assume_capacity(self.object, count, self.alloc);
        }
        /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
        ///
        /// All items after `last_removed_idx` are shifted backward
        pub fn delete_range(self: ILIST, range: Range) void {
            self.vtable.delete_range(self.object, range, self.alloc);
        }
        /// Reset list to an empty state. The list's capacity may or may not be retained.
        pub fn clear(self: ILIST) void {
            self.vtable.clear(self.object, self.alloc);
        }
        /// Return the total number of values the slice/list can hold
        pub fn cap(self: ILIST) usize {
            return self.vtable.cap(self.object);
        }
        /// Shrink the allocated capacity of the list,
        /// while reserving at least `n_reserved_cap` extra capacity above the list len.
        ///
        /// This may or may not reallocate the list data, dependant on the implementation.
        pub fn shrink_cap_reserve_at_most(self: ILIST, reserve_at_most: usize) void {
            self.vtable.shrink_cap_reserve_at_most(self.object, reserve_at_most, self.alloc);
        }
        /// Free the list's memory, if applicable, and set it to an uinitialized state
        pub fn free(self: ILIST) void {
            self.vtable.free(self.object, self.alloc);
        }

        pub fn all_idx_valid_zig(self: ILIST, idxs: []usize) bool {
            for (idxs) |idx| {
                if (!self.idx_valid(idx)) {
                    return false;
                }
            }
            return true;
        }
        const _all_idx_valid_struct = struct {
            list: ILIST,
            all_valid: bool = true,
        };
        fn _all_idx_valid_action(item: IteratorState(T).Item, userdata: *_all_idx_valid_struct) bool {
            if (!userdata.list.idx_valid(item.idx)) {
                userdata.all_valid = false;
                return false;
            }
            return true;
        }
        pub fn all_idx_valid(self: ILIST, idxs: IIdxList) bool {
            var result: _all_idx_valid_struct = .{ .list = self };
            idxs.for_each(.entire_list(), &result, _all_idx_valid_action);
            return result.all_valid;
        }
        pub fn is_empty(self: ILIST) bool {
            return self.len() <= 0;
        }

        pub fn try_slice(self: ILIST, first_idx_: usize, last_idx_: usize) ListError!ILIST {
            if (!self.range_valid(first_idx_, last_idx_)) {
                return ListError.invalid_range;
            }
            return self.slice(first_idx_, last_idx_);
        }

        pub fn try_get(self: ILIST, idx: usize) ListError!T {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get(idx);
        }

        pub fn try_get_ptr(self: ILIST, idx: usize) ListError!*T {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get_ptr(idx);
        }

        pub fn try_set(self: ILIST, idx: usize, val: T) ListError!void {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            self.set(idx, val);
        }

        pub fn try_first_idx(self: ILIST) ListError!usize {
            const idx = self.first_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }

        pub fn try_last_idx(self: ILIST) ListError!usize {
            const idx = self.last_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }
        pub fn try_next_idx(self: ILIST, this_idx: usize) ListError!usize {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.next_idx(this_idx);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_nth_next_idx(self: ILIST, this_idx: usize, n: usize) ListError!usize {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.nth_next_idx(this_idx, n);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_prev_idx(self: ILIST, this_idx: usize) ListError!usize {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.prev_idx(this_idx);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn try_nth_prev_idx(self: ILIST, this_idx: usize, n: usize) ListError!usize {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.nth_prev_idx(this_idx, n);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn nth_idx(self: ILIST, n: usize) usize {
            var idx = self.first_idx();
            idx = self.nth_next_idx(idx, n);
            return idx;
        }
        pub fn try_nth_idx(self: ILIST, n: usize) ListError!usize {
            var idx = self.first_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            idx = self.nth_next_idx(idx, n);
            if (!self.idx_valid(idx)) {
                return ListError.index_out_of_bounds;
            }
            return idx;
        }
        pub fn nth_idx_from_end(self: ILIST, n: usize) usize {
            var idx = self.last_idx();
            idx = self.nth_prev_idx(idx, n);
            return idx;
        }
        pub fn try_nth_idx_from_end(self: ILIST, n: usize) ListError!usize {
            var idx = self.last_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            idx = self.nth_prev_idx(idx, n);
            if (!self.idx_valid(idx)) {
                return ListError.index_out_of_bounds;
            }
            return idx;
        }
        pub fn get_last(self: ILIST) T {
            const idx = self.last_idx();
            return self.get(idx);
        }
        pub fn try_get_last(self: ILIST) ListError!T {
            const idx = try self.try_last_idx();
            return self.get(idx);
        }
        pub fn get_last_ptr(self: ILIST) *T {
            const idx = self.last_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_last_ptr(self: ILIST) ListError!*T {
            const idx = try self.try_last_idx();
            return self.get_ptr(idx);
        }
        pub fn set_last(self: ILIST, val: T) void {
            const idx = self.last_idx();
            return self.set(idx, val);
        }
        pub fn try_set_last(self: ILIST, val: T) ListError!void {
            const idx = try self.try_last_idx();
            return self.set(idx, val);
        }
        pub fn get_first(self: ILIST) T {
            const idx = self.first_idx();
            return self.get(idx);
        }
        pub fn try_get_first(self: ILIST) ListError!T {
            const idx = try self.try_first_idx();
            return self.get(idx);
        }
        pub fn get_first_ptr(self: ILIST) *T {
            const idx = self.first_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_first_ptr(self: ILIST) ListError!*T {
            const idx = try self.try_first_idx();
            return self.get_ptr(idx);
        }
        pub fn set_first(self: ILIST, val: T) void {
            const idx = self.first_idx();
            return self.set(idx, val);
        }
        pub fn try_set_first(self: ILIST, val: T) ListError!void {
            const idx = try self.try_first_idx();
            return self.set(idx, val);
        }
        pub fn get_nth(self: ILIST, n: usize) T {
            const idx = self.nth_idx(n);
            return self.get(idx);
        }
        pub fn try_get_nth(self: ILIST, n: usize) ListError!T {
            const idx = try self.try_nth_idx(n);
            return self.get(idx);
        }
        pub fn get_nth_ptr(self: ILIST, n: usize) *T {
            const idx = self.nth_idx(n);
            return self.get_ptr(idx);
        }
        pub fn try_get_nth_ptr(self: ILIST, n: usize) ListError!*T {
            const idx = try self.try_nth_idx(n);
            return self.get_ptr(idx);
        }
        pub fn set_nth(self: ILIST, n: usize, val: T) void {
            const idx = self.nth_idx(n);
            return self.set(idx, val);
        }
        pub fn try_set_nth(self: ILIST, n: usize, val: T) ListError!void {
            const idx = try self.try_nth_idx(n);
            return self.set(idx, val);
        }
        pub fn set_from(self: ILIST, self_idx: usize, source: ILIST, source_idx: usize) void {
            const val = source.get(source_idx);
            self.set(self_idx, val);
        }
        pub fn try_set_from(self: ILIST, self_idx: usize, source: ILIST, source_idx: usize) ListError!void {
            const val = try source.try_get(source_idx);
            return self.try_set(self_idx, val);
        }
        pub fn swap(self: ILIST, idx_a: usize, idx_b: usize) void {
            const val_a = self.get(idx_a);
            const val_b = self.get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn try_swap(self: ILIST, idx_a: usize, idx_b: usize) ListError!void {
            const val_a = try self.try_get(idx_a);
            const val_b = try self.try_get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn exchange(self: ILIST, self_idx: usize, other: ILIST, other_idx: usize) void {
            const val_self = self.get(self_idx);
            const val_other = other.get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn try_exchange(self: ILIST, self_idx: usize, other: ILIST, other_idx: usize) ListError!void {
            const val_self = try self.try_get(self_idx);
            const val_other = try other.try_get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn overwrite(self: ILIST, source_idx: usize, dest_idx: usize) void {
            const val = self.get(source_idx);
            self.set(dest_idx, val);
        }
        pub fn try_overwrite(self: ILIST, source_idx: usize, dest_idx: usize) ListError!void {
            const val = try self.try_get(source_idx);
            self.set(dest_idx, val);
        }
        pub fn reverse(self: ILIST) void {
            var left = self.first_idx();
            var right = self.last_idx();
            if (left == right or !self.idx_valid(left) or !self.idx_valid(right)) {
                return;
            }
            while (true) {
                self.swap(left, right);
                left = self.next_idx(left);
                if (left == right) {
                    return;
                }
                right = self.prev_idx(right);
                if (left == right) {
                    return;
                }
            }
        }
        pub fn fill(self: ILIST, val: T) void {
            var i = self.first_idx();
            var ok = self.idx_valid(i);
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn fill_count(self: ILIST, val: T, count: usize) CountResult {
            var i = self.first_idx();
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok and result.count < count) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_expected = result.count == count;
            return result;
        }
        pub fn fill_at_index(self: ILIST, val: T, index: usize) void {
            var i = index;
            var ok = self.idx_valid(i);
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn try_fill_at_index(self: ILIST, val: T, index: usize) ListError!void {
            var i = index;
            var ok = self.idx_valid(i);
            if (!ok) {
                return ListError.invalid_index;
            }
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn fill_count_at_index(self: ILIST, val: T, index: usize, count: usize) CountResult {
            var i = index;
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_expected = result.count == count;
            return result;
        }
        pub fn try_fill_count_at_index(self: ILIST, val: T, index: usize, count: usize) ListError!CountResult {
            var i = index;
            var ok = self.idx_valid(i);
            if (!ok) {
                return ListError.invalid_index;
            }
            var result = CountResult{};
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_expected = result.count == count;
            return result;
        }
        pub fn fill_range(self: ILIST, val: T, first_idx_: usize, last_idx_: usize) CountResult {
            var i = first_idx_;
            var ok = self.idx_valid(first_idx_);
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_expected = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn try_fill_range(self: ILIST, val: T, first_idx_: usize, last_idx_: usize) ListError!CountResult {
            var i = first_idx_;
            var ok = self.range_valid(first_idx_, last_idx_);
            if (!ok) {
                return ListError.invalid_range;
            }
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_expected = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn copy_from_to(source: ILIST, source_range: IteratorState(T).Partial, dest_range: IteratorState(T).Full) CopyResult {
            return copy_from_to_advanced(source, source_range, dest_range, .no_error_checks, .no_filter, null, null, .no_filter, null, null);
        }
        pub fn try_copy_from_to(source: ILIST, source_range: IteratorState(T).Partial, dest_range: IteratorState(T).Full) ListError!CopyResult {
            return copy_from_to_advanced(source, source_range, dest_range, .error_checks, .no_filter, null, null, .no_filter, null, null);
        }
        pub fn copy_from_to_advanced(
            source: ILIST,
            source_range: IteratorState(T).Partial,
            dest_range: IteratorState(T).Full,
            comptime error_checks: ErrorMode,
            comptime src_filter: FilterMode,
            src_userdata: anytype,
            src_filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(src_userdata)) bool,
            comptime dest_filter: FilterMode,
            dest_userdata: anytype,
            dest_filter_func: ?*const fn (item: IteratorState(T).Item, userdata: @TypeOf(dest_userdata)) bool,
        ) if (error_checks == .error_checks) ListError!CopyResult else CopyResult {
            var self_iter = source_range.to_iter(source);
            var dest_iter = dest_range;
            if (error_checks == .error_checks) {
                try self_iter.check_source();
                try dest_iter.check_source();
            }
            var next_self = self_iter.next_advanced(src_filter, src_userdata, src_filter_func);
            var next_dest = dest_iter.next_advanced(dest_filter, dest_userdata, dest_filter_func);
            var result = CopyResult{};
            if (next_self) |first| {
                result.source_range.first_idx = first.idx;
            }
            if (next_dest) |first| {
                result.dest_range.first_idx = first.idx;
            }
            while (next_self != null and next_dest != null) {
                const ok_next_dest = next_dest.?;
                const ok_next_self = next_self.?;
                result.source_range.last_idx = ok_next_self.idx;
                result.dest_range.last_idx = ok_next_dest.idx;
                ok_next_dest.list.set(ok_next_dest.idx, ok_next_self.val);
                next_self = self_iter.next_advanced(src_filter, src_userdata, src_filter_func);
                next_dest = dest_iter.next_advanced(dest_filter, dest_userdata, dest_filter_func);
            }
            result.count = @min(self_iter.count, dest_iter.count);
            result.count_matches_expected = result.count == dest_iter.max_count or result.count == self_iter.max_count;
            result.full_dest_copied = !dest_iter.more_values;
            result.full_source_copied = !self_iter.more_values;
            return result;
        }
        fn _swizzle_internal(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: usize, comptime force_count: bool, comptime is_try: bool) if (is_try) ListError!SwizzleResult else SwizzleResult {
            var sel_idx = selectors.first_idx();
            var more_selectors: bool = selectors.idx_valid(sel_idx);
            if (is_try) {
                if (!more_selectors) {
                    return ListError.invalid_index;
                }
            }
            var val: T = undefined;
            var source: ILIST = undefined;
            var source_idx: usize = undefined;
            var val_idx: usize = undefined;
            var more_dest = self.idx_valid(range.first_idx);
            if (is_try) {
                if (!self.range_valid(range)) {
                    return ListError.invalid_range;
                }
            }
            var dest_idx = range.first_idx;
            var result = SwizzleResult{};
            while ((!force_count or result.count < count) and more_selectors and more_dest) {
                source_idx = selectors.get(sel_idx);
                if (is_try) {
                    if (!sources.idx_valid(source_idx)) {
                        return ListError.invalid_index;
                    }
                }
                source = sources.get(source_idx);
                val_idx = source.nth_idx(result.count);
                if (is_try) {
                    if (!source.idx_valid(val_idx)) {
                        return ListError.invalid_index;
                    }
                }
                val = source.get(val_idx);
                self.set(dest_idx, val);
                result.count += 1;
                sel_idx = selectors.next_idx(sel_idx);
                more_selectors = selectors.idx_valid(sel_idx);
                result.full_dest_copied = dest_idx == range.last_idx;
                dest_idx = self.next_idx(dest_idx);
                more_dest = self.idx_valid(dest_idx);
            }
            if (force_count) {
                result.count_matches_expected = result.count == count;
            } else {
                result.count_matches_expected = true;
            }
            result.all_selectors_done = !more_selectors;
            result.next_dest_idx = dest_idx;
            return result;
        }
        pub fn swizzle(self: ILIST, range: Range, sources: IListList, selectors: IIdxList) SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, 0, false, false);
        }
        pub fn try_swizzle(self: ILIST, range: Range, sources: IListList, selectors: IIdxList) ListError!SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, 0, false, true);
        }
        pub fn swizzle_count(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: usize) SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, false);
        }
        pub fn try_swizzle_count(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: usize) ListError!SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, true);
        }
        pub fn is_sorted(self: ILIST, greater_than: *const CompareFunc) bool {
            var i: usize = undefined;
            var ii: usize = undefined;
            var left: T = undefined;
            var right: T = undefined;
            i = self.first_idx();
            var more = self.idx_valid(i);
            if (!more) {
                return true;
            }
            ii = self.next_idx(i);
            more = self.idx_valid(ii);
            if (!more) {
                return true;
            }
            left = self.get(i);
            right = self.get(ii);
            while (more) {
                if (greater_than(left, right)) {
                    return false;
                }
                i = ii;
                ii = self.next_idx(ii);
                more = self.idx_valid(ii);
                if (more) {
                    left = right;
                    right = self.get(ii);
                }
            }
            return true;
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
        pub fn is_sorted_implicit(self: ILIST) bool {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.is_sorted_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            return is_sorted(self, _implicit_gt);
        }
        pub fn insertion_sort(self: ILIST, greater_than: *const CompareFunc) void {
            var ok: bool = undefined;
            var i: usize = undefined;
            var j: usize = undefined;
            var jj: usize = undefined;
            var move_val: T = undefined;
            var test_val: T = undefined;
            i = self.first_idx();
            ok = self.idx_valid(i);
            if (!ok) {
                return;
            }
            i = self.next_idx(i);
            ok = self.idx_valid(i);
            if (!ok) {
                return;
            }
            while (ok) {
                move_val = self.get(i);
                j = self.prev_idx(i);
                ok = self.idx_valid(j);
                if (ok) {
                    jj = i;
                    test_val = self.get(j);
                    while (ok and greater_than(test_val, move_val)) {
                        self.overwrite(j, jj);
                        jj = j;
                        j = self.prev_idx(j);
                        ok = self.idx_valid(j);
                        if (ok) {
                            test_val = self.get(j);
                        }
                    }
                }
                self.set(jj, move_val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }

        pub fn insertion_sort_implicit(self: ILIST) void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.insertion_sort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            insertion_sort(self, _implicit_gt);
        }

        pub fn quicksort(self: ILIST, greater_than: *const CompareFunc, less_than: *const CompareFunc, partition_stack: IIdxList) ListError!void {
            if (self.len() < 2) {
                return;
            }
            if (self.len() <= 8) {
                self.insertion_sort(greater_than);
                return;
            }
            var hi: usize = undefined;
            var lo: usize = undefined;
            var mid: Range = undefined;
            var rng: Range = undefined;
            lo = self.first_idx();
            hi = self.last_idx();
            partition_stack.clear();
            try partition_stack.try_ensure_free_slots(2);
            partition_stack.append_slots_assume_capacity(2);
            partition_stack.set(rng.first_idx, lo);
            partition_stack.set(rng.last_idx, hi);
            while (partition_stack.len() >= 2) {
                hi = partition_stack.pop();
                lo = partition_stack.pop();
                if (hi == lo or hi == self.prev_idx(lo) or lo == self.next_idx(hi)) {
                    continue;
                }
                mid = _quicksort_partition(self, greater_than, less_than, lo, hi);
                try partition_stack.try_ensure_free_slots(4);
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.first_idx, lo);
                partition_stack.set(rng.first_idx, self.prev_idx(mid.first_idx));
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.last_idx, self.next_idx(mid.last_idx));
                partition_stack.set(rng.last_idx, hi);
            }
        }
        pub fn quicksort_implicit(self: ILIST, partition_stack: IIdxList) ListError!void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.quicksort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            self.quicksort(_implicit_gt, _implicit_lt, partition_stack);
        }
        fn _quicksort_partition(self: ILIST, greater_than: *const CompareFunc, less_than: *const CompareFunc, lo: usize, hi: usize) Range {
            const pivot_idx: usize = undefined;
            if (self.consecutive_indexes_in_order() and self.all_indexes_less_than_len_valid()) {
                const rng: Range = .new_range(lo, hi);
                if (self.range_len(rng) <= 8) {
                    // use insertion sort for small partitions
                    var sub = self.slice(rng);
                    sub.insertion_sort(greater_than);
                    return Range.single_idx(lo);
                }
                // use median-of-3
                const mid = ((hi - lo) >> 1) + lo;
                const v_lo = self.get(lo);
                const v_hi = self.get(hi);
                const v_mid = self.get(mid);
                if (less_than(v_lo, v_mid)) {
                    if (less_than(v_mid, v_hi)) {
                        pivot_idx = mid;
                    } else if (less_than(v_lo, v_hi)) {
                        pivot_idx = hi;
                    } else {
                        pivot_idx = lo;
                    }
                } else {
                    if (less_than(v_lo, v_hi)) {
                        pivot_idx = lo;
                    } else if (less_than(v_mid, v_hi)) {
                        pivot_idx = hi;
                    } else {
                        pivot_idx = mid;
                    }
                }
            } else {
                // choose lo
                pivot_idx = lo;
            }
            const pivot_val = self.get(pivot_idx);
            var less_idx: usize = lo;
            var equal_idx: usize = lo;
            var more_idx: usize = hi;
            var cont: bool = equal_idx != more_idx;
            while (cont) {
                const eq_val: T = self.get(equal_idx);
                if (less_than(eq_val, pivot_val)) {
                    self.swap(equal_idx, less_idx);
                    less_idx = self.prev_idx(less_idx);
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = self.next_idx(equal_idx);
                } else if (greater_than(eq_val, pivot_val)) {
                    self.swap(equal_idx, more_idx);
                    if (equal_idx == more_idx) {
                        cont = false;
                    }
                    more_idx = self.prev_idx(more_idx);
                } else {
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = self.next_idx(equal_idx);
                }
            }
            return Range.new(less_idx, more_idx);
        }
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
        pub fn for_each(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, action: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool) CountResult {
            return for_each_advanced(self, self_range, userdata, action, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn try_for_each(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, action: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool) ListError!CountResult {
            return for_each_advanced(self, self_range, userdata, action, .use_count_limit, .error_checks, .no_filter, null);
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
        pub fn filter_indexes(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, filter_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool, output_list: IIdxList) CountResult {
            return self.filter_indexes_advanced(self, self_range, userdata, filter_func, output_list, .use_count_limit, .no_error_checks);
        }
        pub fn try_filter_indexes(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, filter_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) bool, output_list: IIdxList) ListError!CountResult {
            return self.filter_indexes_advanced(self, self_range, userdata, filter_func, output_list, .use_count_limit, .error_checks);
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
        pub fn transform_values(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, comptime OUT_TYPE: type, comptime OUT_PTR: type, transform_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) OUT_TYPE, output_list: IList(OUT_TYPE, OUT_PTR, usize)) CountResult {
            return self.transform_values_advanced(self_range, userdata, OUT_TYPE, OUT_PTR, transform_func, output_list, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn try_transform_values(self: ILIST, self_range: IteratorState(T).Partial, userdata: anytype, comptime OUT_TYPE: type, comptime OUT_PTR: type, transform_func: *const fn (item: IteratorState(T).Item, userdata: @TypeOf(userdata)) OUT_TYPE, output_list: IList(OUT_TYPE, OUT_PTR, usize)) ListError!CountResult {
            return self.transform_values_advanced(self_range, userdata, OUT_TYPE, OUT_PTR, transform_func, output_list, .use_count_limit, .error_checks, .no_filter, null);
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
        pub fn accumulate_result(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorState(T).Item, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
        ) AccumulateResult(@TypeOf(initial_accumulation)) {
            return self.accumulate_result_advanced(self_range, initial_accumulation, userdata, accumulate_func, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn try_accumulate_result(
            self: ILIST,
            self_range: IteratorState(T).Partial,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorState(T).Item, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
        ) ListError!AccumulateResult(@TypeOf(initial_accumulation)) {
            return self.accumulate_result_advanced(self_range, initial_accumulation, userdata, accumulate_func, .use_count_limit, .error_checks, .no_filter, null);
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
        pub fn replace(self: ILIST, self_range: IteratorState(T).Partial, source: IteratorState, self_mem_alloc: Allocator) ListError!void {
            return self.replace_advanced(self_range, source, self_mem_alloc, .no_count_limit, .no_error_checks, .no_filter, null, null, .no_filter, null, null);
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

pub fn list_from_slice_no_alloc(comptime T: type, slice_ptr: *[]T) IList(T) {
    return SliceAdapter(T).interface_no_alloc(slice_ptr);
}
pub fn list_from_slice(comptime T: type, slice_ptr: *[]T, alloc: Allocator) IList(T) {
    return SliceAdapter(T).interface(slice_ptr, alloc);
}

pub const Range = struct {
    first_idx: usize = 0,
    last_idx: usize = 0,

    /// Assumes all consecutive increasing indexes between `first_idx` and `last_idx`
    /// represent consecutive items in theri proper order
    pub fn consecutive_len(self: Range) usize {
        return (self.last_idx - self.first_idx) + 1;
    }

    pub fn new_range(first: usize, last: usize) Range {
        return Range{
            .first_idx = first,
            .last_idx = last,
        };
    }
    pub fn single_idx(idx: usize) Range {
        return Range{
            .first_idx = idx,
            .last_idx = idx,
        };
    }
    pub fn entire_list(list: anytype) Range {
        return Range{
            .first_idx = list.first_idx(),
            .last_idx = list.last_idx(),
        };
    }
    pub fn first_idx_to_list_end(list: anytype, first_idx_: usize) Range {
        return Range{
            .first_idx = first_idx_,
            .last_idx = list.last_idx(),
        };
    }
    pub fn list_start_to_last_idx(list: anytype, last_idx_: usize) Range {
        return Range{
            .first_idx = list.first_idx(),
            .last_idx = last_idx_,
        };
    }
};
pub const CountResult = struct {
    count: usize = 0,
    count_matches_expected: bool = false,
    next_idx: usize = 0,
};
pub fn AccumulateResult(comptime out: type) type {
    return struct {
        count_result: CountResult,
        final_accumulation: out,
    };
}
pub const CopyResult = struct {
    count: usize = 0,
    source_range: Range = .{},
    dest_range: Range = .{},
    count_matches_expected: bool = false,
    full_source_copied: bool = false,
    full_dest_copied: bool = false,
};
pub const SwizzleResult = struct {
    count: usize = 0,
    next_dest_idx: usize = 0,
    count_matches_expected: bool = false,
    all_selectors_done: bool = false,
    full_dest_copied: bool = false,
};

pub const ErrorMode = enum(u8) {
    no_error_checks,
    error_checks,
};
pub const FilterMode = enum(u8) {
    no_filter,
    use_filter,
};

const LocateResult = struct {
    idx: usize = 0,
    found: bool = false,
    exit_hi: bool = false,
    exit_lo: bool = false,
};
const LocateResultIndirect = struct {
    idx: usize = 0,
    idx_idx: usize = 0,
    found: bool = false,
    exit_hi: bool = false,
    exit_lo: bool = false,
};
pub const SearchResult = struct {
    idx: usize = 0,
    found: bool = false,
};
pub const SearchResultIndirect = struct {
    idx: usize = 0,
    idx_idx: usize = 0,
    found: bool = false,
};
pub const InsertIndexResult = struct {
    idx: usize = 0,
    append: bool = false,
};
pub const InsertIndexResultIndirect = struct {
    idx: usize = 0,
    idx_idx: usize = 0,
    append: bool = false,
};

pub const SliceAdapter = @import("./IList_SliceAdapter.zig").SliceAdapter;
pub const ArrayListAdapter = @import("./IList_ArrayListAdapter.zig").ArrayListAdapter;
pub const List = @import("./IList_List.zig").List;
pub const RingList = @import("./IList_RingList.zig").RingList;
pub const MultiSortList = @import("./IList_MultiSortList.zig").MultiSortList;
