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
const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;

pub const ListError = error{
    list_is_empty,
    index_out_of_bounds,
    invalid_index,
    invalid_range,
    no_items_after,
    no_items_before,
    failed_to_grow_list,
    replace_dest_idx_list_smaller_than_source,
};

pub fn IList(comptime T: type, comptime PTR: type, comptime IDX: type) type {
    Assert.assert_with_reason(Types.type_is_int(IDX), @src(), ": type IDX must be an integer type, got type {s}", @typeName(IDX));
    return struct {
        const ILIST = @This();

        object: *anyopaque,
        vtable: *const VTable,

        fn _fn_none_ret_bool_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn () OUT {
            const proto = struct {
                const func = fn () OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_alloc_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, alloc: Allocator) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, alloc: Allocator) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_alloc_alloc_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, alloc: Allocator, alloc2: Allocator) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, alloc: Allocator, alloc2: Allocator) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, idx: IDX) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, idx: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_alloc_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, idx: IDX, alloc: Allocator) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, idx: IDX, alloc: Allocator) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, rng: Range) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, rng: Range) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_alloc_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, rng: Range, alloc: Allocator) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, rng: Range, alloc: Allocator) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_alloc_alloc_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, rng: Range, alloc: Allocator, alloc2: Allocator) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, rng: Range, alloc: Allocator, alloc2: Allocator) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, idx: IDX, idx2: IDX) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, idx: IDX, idx2: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, rng: Range, idx: IDX) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, rng: Range, idx: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_idx_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, idx: IDX, idx2: IDX, idx3: IDX) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, idx: IDX, idx2: IDX, idx3: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_val_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (object: *anyopaque, idx: IDX, val: T) OUT {
            const proto = struct {
                const func = fn (object: *anyopaque, idx: IDX, val: T) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        pub const VTable = struct {
            /// Should return a constant boolean value describing whether
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
            prefer_linear_ops: *const fn () bool = _fn_none_ret_bool_panic("prefer_linear_ops", bool),
            /// Should return a constant boolean value describing whether consecutive indexes,
            /// (eg. `0, 1, 2, 3, 4, 5`) are in their logical/proper order (not necessarily sorted)
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            consecutive_indexes_in_order: *const fn () bool = _fn_none_ret_bool_panic("consecutive_indexes_in_order", bool),
            /// Should return a constant boolean value describing whether all indexes greater-than-or-equal-to
            /// `0` AND less-than `slice.len()` are valid
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            all_indexes_zero_to_len_valid: *const fn () bool = _fn_none_ret_bool_panic("all_indexes_zero_to_len_valid", bool),
            /// Returns whether the given index is valid for the slice
            idx_valid: *const fn (object: *anyopaque, idx: IDX) bool = _fn_self_idx_panic("idx_valid", bool),
            /// Returns whether the given index range is valid for the slice
            ///
            /// The following MUST be true:
            ///   - `first_idx` comes logically before OR is equal to `last_idx`
            ///   - all indexes including and between `first_idx` and `last_idx` are valid for the slice
            range_valid: *const fn (object: *anyopaque, range: Range) bool = _fn_self_idx_idx_panic("range_valid", bool),
            /// Split an index range (roughly) in half, returning the index in the middle of the range
            ///
            /// Assumes `range_valid(first_idx, last_idx) == true`, and if so,
            /// the returned index MUST also be valid and MUST be between or equal to the first and/or last index
            ///
            /// The implementation should endeavor to return an index as close to the true middle index
            /// as possible, but it is not required to as long as the returned index IS between or equal to
            /// the first and/or last indexes. HOWEVER, some algorithms will have inconsitent performance
            /// if the returned index is far from the true middle index
            split_range: *const fn (object: *anyopaque, range: Range) IDX = _fn_self_range_panic("split_range", IDX),
            /// get the value at the provided index
            get: *const fn (object: *anyopaque, idx: IDX) T = _fn_self_idx_panic("get", T),
            /// get a pointer to the value at the provided index
            get_ptr: *const fn (object: *anyopaque, idx: IDX) PTR = _fn_self_idx_panic("get_ptr", PTR),
            /// set the value at the provided index to the given value
            set: *const fn (object: *anyopaque, idx: IDX, val: T) void = _fn_self_idx_val_panic("set", void),
            /// move the data located at `old_idx` to `new_idx`, shifting all
            /// values in between either up or down
            move: *const fn (object: *anyopaque, old_idx: IDX, new_idx: IDX) void = _fn_self_idx_idx_panic("move", void),
            /// move the data from located between and including `first_idx` and `last_idx`,
            /// to the position `newfirst_idx`, shifting the values at that location out of the way
            move_range: *const fn (object: *anyopaque, range: Range, new_first_idx: IDX) void = _fn_self_range_idx_panic("move_range", void),
            /// Return another `IList(T, PTR, IDX)` that holds values in range [first, last] (inclusive),
            /// and should reference the same values as this one. Any changes in the new slice should be reflected in this one.
            ///
            /// Returned slice may or may not have full list capabilites, dependant on implementation
            ///
            /// The supplied `obj_alloc` allocator is used to create the object pointed to by `IList.object`,
            /// which may allocate on the stack or heap. The `mem_alloc` Allocator to use for the new IList should be the same
            /// one used to originally allocate *this* IList.object's *memory*.
            slice: *const fn (object: *anyopaque, range: Range, obj_alloc: Allocator) ILIST = _fn_self_range_alloc_panic("slice", ILIST),
            /// Return another `IList(T, PTR, IDX)` that holds a copy of the values in range [first, last] (inclusive),
            /// and should reference new memory. Any changes in the new slice should not affect this one.
            ///
            /// Returned slice may or may not have full list capabilites, dependant on implementation
            ///
            /// The supplied `obj_alloc` allocator is used to create the object pointed to by `IList.object`,
            /// while `mem_alloc` is the allocator used to allocate the *memory* needed by the concrete object. They may be the same allocator,
            /// an may allocate on the stack or the heap.
            clone: *const fn (object: *anyopaque, range: Range, obj_alloc: Allocator, mem_alloc: Allocator) ILIST = _fn_self_range_alloc_alloc_panic("clone", ILIST),
            /// Return the first index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            first_idx: *const fn (object: *anyopaque) IDX = _fn_self_panic("first_idx", IDX),
            /// Return the last index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            last_idx: *const fn (object: *anyopaque) IDX = _fn_self_panic("last_idx", IDX),
            /// Return the next index after the current index in the slice.
            ///
            /// If the given index is invalid or no next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            next_idx: *const fn (object: *anyopaque, this_idx: IDX) IDX = _fn_self_idx_panic("next_idx", IDX),
            /// Return the index `n` places after the current index in the slice.
            ///
            /// If the given index is invalid or no nth next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_next_idx: *const fn (object: *anyopaque, this_idx: IDX, n: IDX) IDX = _fn_self_idx_idx_panic("nth_next_idx", IDX),
            /// Return the prev index before the current index in the slice.
            ///
            /// If the given index is invalid or no prev index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            prev_idx: *const fn (object: *anyopaque, this_idx: IDX) IDX = _fn_self_idx_panic("prev_idx", IDX),
            /// Return the index `n` places before the current index in the slice.
            ///
            /// If the given index is invalid or no nth previous index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_prev_idx: *const fn (object: *anyopaque, this_idx: IDX, n: IDX) IDX = _fn_self_idx_idx_panic("nth_prev_idx", IDX),
            /// Return the current number of values in the slice/list
            ///
            /// It is not guaranteed that all indexes less than `len` are valid for the slice
            len: *const fn (object: *anyopaque) IDX = _fn_self_panic("len", IDX),
            /// Return the number of items between (and including) `first_idx` and `last_idx`
            ///
            /// `slice.range_len(slice.first_idx(), slice.last_idx())` MUST equal `slice.len()`
            range_len: *const fn (object: *anyopaque, range: Range) IDX = _fn_self_range_panic("range_len", IDX),
            /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
            /// the memory or performing any other expensive reorganization procedure
            ///
            /// If free space cannot be ensured and attempting to add `count` more items
            /// will definitely fail or cause undefined behaviour, `ok == false`
            ///
            /// The supplied `mem_alloc` allocator should be the same one used when creating/allocating the
            /// original concrete implementation object's *memory*, not the one used to create `IList.object`, if any
            try_ensure_free_slots: *const fn (object: *anyopaque, count: IDX, mem_alloc: Allocator) bool = _fn_self_idx_alloc_panic("try_ensure_free_slots", bool),
            /// Insert `n` new slots directly before existing index, shifting all existing items
            /// at and after that index forward.
            ///
            /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
            /// not match the insert index, depending on the implementation behavior
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            insert_slots_assume_capacity: *const fn (object: *anyopaque, idx: IDX, count: IDX) Range = _fn_self_idx_idx_panic("insert_slots_assume_capacity", Range),
            /// Append `n` new slots at the end of the list.
            ///
            /// Returns the first new slot and the last new slot, inclusive
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            append_slots_assume_capacity: *const fn (object: *anyopaque, count: IDX) Range = _fn_self_idx_panic("append_slots_assume_capacity", Range),
            /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
            ///
            /// All items after `last_removed_idx` are shifted backward
            delete_range: *const fn (object: *anyopaque, range: Range) void = _fn_self_range_panic("delete_range", void),
            /// Reset list to an empty state. The list's capacity may or may not be retained,
            /// but the list must remain in a usable state
            clear: *const fn (object: *anyopaque) void = _fn_self_panic("clear", void),
            /// Return the total number of values the slice/list can hold
            cap: *const fn (object: *anyopaque) IDX = _fn_self_panic("cap", IDX),
            /// Increment the start location (index/pointer/etc.) of this list by
            /// `n` positions. The new 'first' index in the list should be the index
            /// that would have previously been returned by `list.nth_next_idx(list.first_idx(), n)`
            ///
            /// This action may or may not be reversable (for example using `clear()` or some other implementation specific method)
            increment_start: *const fn (object: *anyopaque, n: IDX) void = _fn_self_idx_panic("increment_start", void),
            /// Free the list's memory, if applicable, and set it to an empty state
            ///
            /// The supplied `mem_alloc` allocator should be the same one used when creating/allocating the
            /// original concrete implementation object's *memory*, not the one used to create `IList.object`, if any
            free: *const fn (object: *anyopaque, mem_alloc: Allocator) void = _fn_self_alloc_panic("free", void),
            /// Free the list's implementation object (*not* its memory), if applicable. This should only be done after calling
            /// `free()` if needed, and attempting to use the IList after calling this should be considered
            /// undefined behavior.
            ///
            /// The supplied `obj_alloc` allocator should be the same one used when creating/allocating the
            /// original concrete implementation object, if any, not the one used to create the object's *memory*, if any
            destroy: *const fn (object: *anyopaque, obj_alloc: Allocator) void = _fn_self_alloc_panic("destroy", void),
        };
        pub const PartialIterator = struct {
            src: IteratorSource,
            overwrite_first: bool = false,
            overwrite_last: bool = false,
            want_count: IDX = std.math.maxInt(IDX),
            forward: bool = true,

            pub fn one_index(idx: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .single = idx },
                    .want_count = 1,
                };
            }
            pub fn new_range(first: IDX, last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn new_range_max_count(first: IDX, last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = max_count,
                };
            }
            pub fn use_range(range: Range) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn use_range_max_count(range: Range, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = max_count,
                };
            }
            pub fn entire_list() PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn entire_list_max_count(max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = max_count,
                };
            }
            pub fn start_to_idx(last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn start_to_idx_max_count(last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = max_count,
                };
            }
            pub fn idx_to_end(first: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn idx_to_end_max_count(first: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = max_count,
                };
            }
            pub fn index_list(idx_list: IIdxList) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn index_list_max_count(idx_list: IIdxList, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = max_count,
                };
            }
            pub fn one_index_rev(idx: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .single = idx },
                    .want_count = 1,
                    .forward = false,
                };
            }
            pub fn new_range_rev(first: IDX, last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn new_range_max_count_rev(first: IDX, last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = max_count,
                    .forward = false,
                };
            }
            pub fn use_range_rev(range: Range) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn use_range_max_count_rev(range: Range, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = max_count,
                    .forward = false,
                };
            }
            pub fn entire_list_rev() PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn entire_list_max_count_rev(max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = max_count,
                    .forward = false,
                };
            }
            pub fn start_to_idx_rev(last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn start_to_idx_max_count_rev(last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = max_count,
                    .forward = false,
                };
            }
            pub fn idx_to_end_rev(first: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn idx_to_end_max_count_rev(first: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = max_count,
                    .forward = false,
                };
            }
            pub fn index_list_rev(idx_list: IIdxList) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn index_list_max_count_rev(idx_list: IIdxList, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = max_count,
                    .forward = false,
                };
            }

            pub fn to_iter(self: PartialIterator, list: ILIST) Iterator {
                var iter = Iterator{
                    .list = list,
                    .src = self.src,
                    .want_count = self.want_count,
                    .done = self.want_count == 0,
                    .forward = self.forward,
                };
                switch (self.src) {
                    .single => |idx| {
                        iter.curr = idx;
                    },
                    .range => |rng| {
                        var new_rng = rng;
                        if (self.overwrite_first) {
                            new_rng.first_idx = list.first_idx();
                        }
                        if (self.overwrite_last) {
                            new_rng.last_idx = list.last_idx();
                        }
                        iter.src = new_rng;
                        if (self.forward) {
                            iter.curr = new_rng.first_idx;
                        } else {
                            iter.curr = new_rng.last_idx;
                        }
                    },
                    .list => |lst| {
                        if (self.forward) {
                            iter.curr_ref = lst.first_idx();
                        } else {
                            iter.curr_ref = lst.last_idx();
                        }
                    },
                }
            }
        };
        pub fn iterator(self: ILIST, self_range: PartialIterator) Iterator {
            return self_range.to_iter(self);
        }
        pub const Iterator = struct {
            list: ILIST,
            src: IteratorSource,
            curr: IDX = 0,
            prev: IDX = 0,
            curr_ref: IDX = 0,
            count: IDX = 0,
            want_count: IDX = std.math.maxInt(IDX),
            done: bool = false,
            more_values: bool = false,
            forward: bool = true,
            err: ?ListError = null,

            pub fn one_index(list: ILIST, idx: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .single = idx },
                    .curr = idx,
                    .prev = idx,
                    .want_count = 1,
                };
            }
            pub fn new_range(list: ILIST, first: IDX, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = first,
                    .prev = first,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn new_range_max_count(list: ILIST, first: IDX, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = first,
                    .prev = first,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn use_range(list: ILIST, range: Range) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.first_idx,
                    .prev = range.first_idx,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn use_range_max_count(list: ILIST, range: Range, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.first_idx,
                    .prev = range.first_idx,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn entire_list(list: ILIST) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.first_idx(),
                    .prev = list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn entire_list_max_count(list: ILIST, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.first_idx(),
                    .prev = list.first_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn start_to_idx(list: ILIST, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = list.first_idx(),
                    .prev = list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn start_to_idx_max_count(list: ILIST, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = list.first_idx(),
                    .prev = list.first_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn idx_to_end(list: ILIST, first: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = first,
                    .prev = first,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn idx_to_end_max_count(list: ILIST, first: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = first,
                    .prev = first,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn index_list(list: ILIST, idx_list: IIdxList) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.first_idx(),
                    .prev_ref = idx_list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                    .done = idx_list.len() == 0,
                };
            }
            pub fn index_list_max_count(list: ILIST, idx_list: IIdxList, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.first_idx(),
                    .prev_ref = idx_list.first_idx(),
                    .want_count = max_count,
                    .done = @min(idx_list.len(), max_count) == 0,
                };
            }
            pub fn one_index_rev(list: ILIST, idx: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .single = idx },
                    .curr = idx,
                    .prev = idx,
                    .want_count = 1,
                    .forward = false,
                };
            }
            pub fn new_range_rev(list: ILIST, first: IDX, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = last,
                    .prev = last,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn new_range_max_count_rev(list: ILIST, first: IDX, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = last,
                    .prev = last,
                    .want_count = max_count,
                    .done = max_count == 0,
                    .forward = false,
                };
            }
            pub fn use_range_rev(list: ILIST, range: Range) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.last_idx,
                    .prev = range.last_idx,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn use_range_max_count_rev(list: ILIST, range: Range, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.last_idx,
                    .prev = range.last_idx,
                    .want_count = max_count,
                    .done = max_count == 0,
                    .forward = false,
                };
            }
            pub fn entire_list_rev(list: ILIST) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.last_idx(),
                    .prev = list.last_idx(),
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn entire_list_max_count_rev(list: ILIST, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.last_idx(),
                    .prev = list.last_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                    .forward = false,
                };
            }
            pub fn start_to_idx_rev(list: ILIST, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = last,
                    .prev = last,
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn start_to_idx_max_count_rev(list: ILIST, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = last,
                    .prev = last,
                    .want_count = max_count,
                    .done = max_count == 0,
                    .forward = false,
                };
            }
            pub fn idx_to_end_rev(list: ILIST, first: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = list.last_idx(),
                    .prev = list.last_idx(),
                    .want_count = std.math.maxInt(IDX),
                    .forward = false,
                };
            }
            pub fn idx_to_end_max_count_rev(list: ILIST, first: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = list.last_idx(),
                    .prev = list.last_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                    .forward = false,
                };
            }
            pub fn index_list_rev(list: ILIST, idx_list: IIdxList) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.last_idx(),
                    .prev_ref = idx_list.last_idx(),
                    .want_count = std.math.maxInt(IDX),
                    .done = idx_list.len() == 0,
                    .forward = false,
                };
            }
            pub fn index_list_max_count_rev(list: ILIST, idx_list: IIdxList, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.last_idx(),
                    .prev_ref = idx_list.last_idx(),
                    .want_count = max_count,
                    .done = @min(idx_list.len(), max_count) == 0,
                    .forward = false,
                };
            }

            pub fn first_idx(self: *Iterator) IDX {
                switch (self.src) {
                    .single => |idx| {
                        return idx;
                    },
                    .range => |rng| {
                        return rng.first_idx;
                    },
                    .list => |lst| {
                        return lst.get_first();
                    },
                }
            }
            pub fn last_idx(self: *Iterator) IDX {
                switch (self.src) {
                    .single => |idx| {
                        return idx;
                    },
                    .range => |rng| {
                        return rng.last_idx;
                    },
                    .list => |lst| {
                        return lst.get_last();
                    },
                }
            }

            pub fn next(self: *Iterator) ?IteratorItem {
                return self.next_advanced(.no_count_limit, .no_error_checks, .advance, .no_filter, null, null);
            }
            pub const IterCount = enum {
                no_count_limit,
                use_count_limit,
            };
            pub const IterCheck = enum {
                no_error_checks,
                error_checks,
            };
            pub const IterFilter = enum {
                no_filter,
                use_filter,
            };
            pub const IterAdvance = enum {
                advance,
                dont_advance,
            };
            pub const IterSelect = enum {
                select,
                skip,
                stop_return_null,
                stop_return_item,
            };
            pub fn next_advanced(self: *Iterator, comptime count_limit: IterCount, comptime error_checks: IterCheck, comptime advance: IterAdvance, comptime filter_mode: IterFilter, userdata: anytype, filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) IterSelect) ?IteratorItem {
                switch (self.src) {
                    .single => |idx| {
                        if (!self.done) {
                            if (error_checks == .error_checks and !self.list.idx_valid(idx)) {
                                self.err = ListError.invalid_index;
                                return null;
                            }
                            if (advance == .advance) {
                                self.count = 1;
                                self.done = true;
                                self.more_values = false;
                                self.prev = self.curr;
                                if (self.forward) {
                                    self.curr = self.list.next_idx(self.curr);
                                } else {
                                    self.curr = self.list.prev_idx(self.curr);
                                }
                            }
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = idx,
                                .val = self.list.get(idx),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .select, .stop_return_item => {
                                        return item;
                                    },
                                    .skip, .stop_return_null => {
                                        return null;
                                    },
                                }
                            }
                            return item;
                        }
                        return null;
                    },
                    .range => |rng| {
                        if (error_checks == .error_checks and self.count == 0 and !self.list.range_valid(rng)) {
                            self.err = ListError.invalid_range;
                            return null;
                        }
                        while (!self.done) {
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = self.curr,
                                .val = self.list.get(self.curr),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .skip => {
                                        if (advance == .advance) {
                                            self.prev = self.curr;
                                            if (self.forward) {
                                                if (self.curr == rng.last_idx) {
                                                    self.done = true;
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.next_idx(self.curr);
                                            } else {
                                                if (self.curr == rng.first_idx) {
                                                    self.done = true;
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.prev_idx(self.curr);
                                            }
                                        }
                                    },
                                    .select => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (count_limit == .use_count_limit and self.count == self.want_count) {
                                                self.done = true;
                                            }
                                            self.prev = self.curr;
                                            if (self.forward) {
                                                if (self.curr == rng.last_idx) {
                                                    self.done = true;
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.next_idx(self.curr);
                                            } else {
                                                if (self.curr == rng.first_idx) {
                                                    self.done = true;
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.prev_idx(self.curr);
                                            }
                                        }
                                        return item;
                                    },
                                    .stop_return_item => {
                                        if (advance == .advance) {
                                            self.count += 1;

                                            self.prev = self.curr;
                                            if (self.forward) {
                                                if (self.curr == rng.last_idx) {
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.next_idx(self.curr);
                                            } else {
                                                if (self.curr == rng.first_idx) {
                                                    self.more_values = false;
                                                }
                                                self.curr = self.list.prev_idx(self.curr);
                                            }
                                        }
                                        self.done = true;
                                        return item;
                                    },
                                    .stop_return_null => {
                                        self.done = true;
                                        return null;
                                    },
                                }
                            } else {
                                if (advance == .advance) {
                                    self.count += 1;
                                    if (count_limit == .use_count_limit and self.count == self.want_count) {
                                        self.done = true;
                                    }
                                    self.prev = self.curr;
                                    if (self.forward) {
                                        if (self.curr == rng.last_idx) {
                                            self.done = true;
                                            self.more_values = false;
                                        }
                                        self.curr = self.list.next_idx(self.curr);
                                    } else {
                                        if (self.curr == rng.first_idx) {
                                            self.done = true;
                                            self.more_values = false;
                                        }
                                        self.curr = self.list.prev_idx(self.curr);
                                    }
                                }
                                return item;
                            }
                        }
                        return null;
                    },
                    .list => |idx_list| {
                        while (!self.done) {
                            self.prev = self.curr;
                            self.curr = idx_list.get(self.curr_ref);
                            if (error_checks == .error_checks and !self.list.idx_valid(self.curr)) {
                                self.err = ListError.invalid_index;
                                return null;
                            }
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = self.curr,
                                .val = self.list.get(self.curr),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .skip => {
                                        if (advance == .advance) {
                                            if (self.forward) {
                                                self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            } else {
                                                self.curr_ref = idx_list.prev_idx(self.curr_ref);
                                            }
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                        }
                                    },
                                    .select => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (count_limit == .use_count_limit and self.count == self.want_count) {
                                                self.done = true;
                                            }
                                            if (self.forward) {
                                                self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            } else {
                                                self.curr_ref = idx_list.prev_idx(self.curr_ref);
                                            }
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                        }
                                        return item;
                                    },
                                    .stop_return_item => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (self.forward) {
                                                self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            } else {
                                                self.curr_ref = idx_list.prev_idx(self.curr_ref);
                                            }
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.more_values = false;
                                            }
                                        }
                                        self.done = true;
                                        return item;
                                    },
                                    .stop_return_null => {
                                        self.done = true;
                                        return null;
                                    },
                                }
                            } else {
                                if (advance == .advance) {
                                    self.count += 1;
                                    if (count_limit == .use_count_limit and self.count == self.want_count) {
                                        self.done = true;
                                    }
                                    if (self.forward) {
                                        self.curr_ref = idx_list.next_idx(self.curr_ref);
                                    } else {
                                        self.curr_ref = idx_list.prev_idx(self.curr_ref);
                                    }
                                    if (!idx_list.idx_valid(self.curr_ref)) {
                                        self.done = true;
                                        self.more_values = false;
                                    }
                                }
                                return item;
                            }
                        }
                        return null;
                    },
                }
            }
            pub fn count_result(self: Iterator) CountResult {
                return CountResult{
                    .count = self.count,
                    .count_matches_input = self.count == self.want_count,
                    .next_idx = self.curr,
                };
            }
        };
        pub const IteratorSource = union(enum(u8)) {
            single: IDX,
            range: Range,
            list: IIdxList,
        };
        pub const IteratorItem = struct {
            list: ILIST,
            idx: IDX,
            val: T,
        };
        pub const IndexSourceResult = struct {
            idx: IDX,
            idx_idx: IDX,
            nth: IDX,
            val: T,
            valid: bool,
            err: ListError,
        };
        pub const Range = struct {
            first_idx: IDX = 0,
            last_idx: IDX = 0,

            pub fn new_range(first: IDX, last: IDX) Range {
                return Range{
                    .first_idx = first,
                    .last_idx = last,
                };
            }
            pub fn single_idx(idx: IDX) Range {
                return Range{
                    .first_idx = idx,
                    .last_idx = idx,
                };
            }
            pub fn entire_list(list: ILIST) Range {
                return Range{
                    .first_idx = list.first_idx(),
                    .last_idx = list.last_idx(),
                };
            }
            pub fn first_idx_to_list_end(list: ILIST, first_idx_: IDX) Range {
                return Range{
                    .first_idx = first_idx_,
                    .last_idx = list.last_idx(),
                };
            }
            pub fn list_start_to_last_idx(list: ILIST, last_idx_: IDX) Range {
                return Range{
                    .first_idx = list.first_idx(),
                    .last_idx = last_idx_,
                };
            }
        };
        pub const CountResult = struct {
            count: IDX = 0,
            count_matches_input: bool = false,
            next_idx: IDX = 0,
        };
        pub fn AccumulateResult(comptime out: type) type {
            return struct {
                count_result: CountResult,
                final_accumulation: out,
            };
        }
        pub const CopyResult = struct {
            count: IDX = 0,
            next_source_idx: IDX = 0,
            next_dest_idx: IDX = 0,
            count_matches_input: bool = false,
            full_source_copied: bool = false,
            full_dest_copied: bool = false,
        };
        pub const SwizzleResult = struct {
            count: IDX = 0,
            next_dest_idx: IDX = 0,
            count_matches_input: bool = false,
            all_selectors_done: bool = false,
            full_dest_copied: bool = false,
        };

        pub const CompareFunc = fn (left_or_this: T, right_or_test: T) bool;
        pub const IIdxList = IList(IDX, *IDX, IDX);
        pub const IListList = IList(ILIST, *ILIST, IDX);
        fn prefer_linear_ops(self: ILIST) bool {
            return self.vtable.prefer_linear_ops();
        }
        fn consecutive_indexes_in_order(self: ILIST) bool {
            return self.vtable.consecutive_indexes_in_order();
        }
        fn all_indexes_less_than_len_valid(self: ILIST) bool {
            return self.vtable.all_indexes_zero_to_len_valid();
        }

        /// Return `true` if the given index is a valid index for the list, `false` otherwise
        pub fn idx_valid(self: ILIST, idx: IDX) bool {
            return self.vtable.idx_valid(self.object, idx);
        }
        /// Return `true` if the given range (inclusive) is valid for the list, `false` otherwise
        pub fn range_valid(self: ILIST, range: Range) bool {
            return self.vtable.range_valid(self.object, range);
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
        pub fn split_range(self: ILIST, range: Range) IDX {
            return self.vtable.split_range(self.object, range);
        }
        /// get the value at the provided index
        pub fn get(self: ILIST, idx: IDX) T {
            self.vtable.get(self.object, idx);
        }
        /// get a pointer to the value at the provided index
        pub fn get_ptr(self: ILIST, idx: IDX) PTR {
            self.vtable.get_ptr(self.object, idx);
        }
        /// set the value at the provided index to the given value
        pub fn set(self: ILIST, idx: IDX, val: T) void {
            self.vtable.set(self.object, idx, val);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn move(self: ILIST, old_idx: IDX, new_idx: IDX) void {
            self.vtable.move(self.object, old_idx, new_idx);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn try_move(self: ILIST, old_idx: IDX, new_idx: IDX) ListError!void {
            if (!self.idx_valid(old_idx) or !self.idx_valid(new_idx)) {
                return ListError.invalid_index;
            }
            self.vtable.move(self.object, old_idx, new_idx);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn move_range(self: ILIST, first_idx_: IDX, last_idx_: IDX, new_first_idx: IDX) void {
            self.vtable.move_range(self.object, first_idx_, last_idx_, new_first_idx);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn try_move_range(self: ILIST, first_idx_: IDX, last_idx_: IDX, new_first_idx: IDX) ListError!void {
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
        /// Return another `IList(T, IDX)` that holds values in range [first, last] (inclusive)
        ///
        /// Analogous to slice[first..last+1]
        pub fn slice(self: ILIST, range: Range, obj_alloc: Allocator) ILIST {
            self.vtable.slice(self.object, range, obj_alloc);
        }
        /// Return another `IList(T, IDX)` that holds values in range [first, last] (inclusive)
        ///
        /// Analogous to slice[first..last+1]
        pub fn clone(self: ILIST, range: Range, obj_alloc: Allocator, mem_alloc: Allocator) ILIST {
            self.vtable.clone(self.object, range, obj_alloc, mem_alloc);
        }
        /// Return the first index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn first_idx(self: ILIST) IDX {
            self.vtable.first_idx(self.object);
        }
        /// Return the last index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn last_idx(self: ILIST) IDX {
            self.vtable.last_idx(self.object);
        }
        /// Return the next index after the current index in the slice.
        ///
        /// If the given index is invalid or no next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn next_idx(self: ILIST, this_idx: IDX) IDX {
            self.vtable.next_idx(self.object, this_idx);
        }
        /// Return the index `n` places after the current index in the slice.
        ///
        /// If the given index is invalid or no nth next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_next_idx(self: ILIST, this_idx: IDX, n: IDX) IDX {
            self.vtable.nth_next_idx(self.object, this_idx, n);
        }
        /// Return the prev index before the current index in the slice.
        ///
        /// If the given index is invalid or no prev index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn prev_idx(self: ILIST, this_idx: IDX) IDX {
            self.vtable.prev_idx(self.object, this_idx);
        }
        /// Return the index `n` places before the current index in the slice.
        ///
        /// If the given index is invalid or no nth previous index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_prev_idx(self: ILIST, this_idx: IDX, n: IDX) IDX {
            self.vtable.nth_prev_idx(self.object, this_idx, n);
        }
        /// Return the current number of values in the slice/list
        ///
        /// It is not guaranteed that all indexes less than `len` are valid for the slice,
        /// unless `all_indexes_less_than_len_valid() == true`
        pub fn len(self: ILIST) IDX {
            return self.vtable.len(self.object);
        }
        /// Return the number of items between (and including) `first_idx` and `last_idx`
        ///
        /// `slice.range_len(Range{.first_idx: slice.first_idx(), .last_idx: slice.last_idx()})` MUST equal `slice.len()`
        pub fn range_len(self: ILIST, range: Range) IDX {
            return self.vtable.range_len(self.object, range);
        }
        /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
        /// the memory or performing any other expensive reorganization procedure
        ///
        /// If free space cannot be ensured and attempting to add `count` more items
        /// will definitely fail or cause undefined behaviour, `ok == false`
        pub fn try_ensure_free_slots(self: ILIST, count: IDX, mem_alloc: Allocator) ListError!void {
            const ok = self.vtable.try_ensure_free_slots(self.object, count, mem_alloc);
            if (!ok) {
                return ListError.failed_to_grow_list;
            }
            return void{};
        }
        /// Insert `n` new slots directly before existing index, shifting all existing items
        /// at and after that index forward.
        ///
        /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
        /// not match the insert index, depending on the implementation behavior
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function with a valid insert idx should not fail
        pub fn insert_slots_assume_capacity(self: ILIST, idx: IDX, count: IDX) Range {
            return self.vtable.insert_slots_assume_capacity(self.object, idx, count);
        }
        /// Append `n` new slots at the end of the list.
        ///
        /// Returns the first new slot and the last new slot, inclusive
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function should not fail
        pub fn append_slots_assume_capacity(self: ILIST, count: IDX) Range {
            return self.vtable.append_slots_assume_capacity(self.object, count);
        }
        /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
        ///
        /// All items after `last_removed_idx` are shifted backward
        pub fn delete_range(self: ILIST, range: Range) void {
            self.vtable.delete_range(self.object, range);
        }
        /// Reset list to an empty state. The list's capacity may or may not be retained.
        pub fn clear(self: ILIST) void {
            self.vtable.clear(self.object);
        }
        /// Return the total number of values the slice/list can hold
        pub fn cap(self: ILIST) IDX {
            return self.vtable.cap(self.object);
        }
        /// Increment the start location (index/pointer/etc.) of this list by
        /// `n` positions. The new 'first' item in the queue should be the item
        /// that would have previously been returned by `list.nth_next_idx(list.first_idx(), n)`
        ///
        /// This may or may not irrevertibly consume the first `n` items in the list
        pub fn increment_start(self: ILIST, n: IDX) void {
            self.vtable.increment_start(self.object, n);
        }
        /// Free the list's memory, if applicable, and set it to an uinitialized state
        pub fn free(self: ILIST, mem_alloc: Allocator) void {
            self.vtable.free(self.object, mem_alloc);
        }
        /// Free the list's memory, if applicable, and set it to an uinitialized state
        pub fn destroy(self: ILIST, obj_alloc: Allocator) void {
            self.vtable.destroy(self.object, obj_alloc);
        }
        pub fn free_and_destroy(self: ILIST, mem_alloc: Allocator, obj_alloc: Allocator) void {
            self.vtable.free(self.object, mem_alloc);
            self.vtable.destroy(self.object, obj_alloc);
        }

        pub fn all_idx_valid_zig(self: ILIST, idxs: []IDX) bool {
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
        fn _all_idx_valid_action(item: IteratorItem, userdata: *_all_idx_valid_struct) bool {
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

        pub fn try_slice(self: ILIST, first_idx_: IDX, last_idx_: IDX) ListError!ILIST {
            if (!self.range_valid(first_idx_, last_idx_)) {
                return ListError.invalid_range;
            }
            return self.slice(first_idx_, last_idx_);
        }

        pub fn try_get(self: ILIST, idx: IDX) ListError!T {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get(idx);
        }

        pub fn try_get_ptr(self: ILIST, idx: IDX) ListError!PTR {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get_ptr(idx);
        }

        pub fn try_set(self: ILIST, idx: IDX, val: T) ListError!void {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            self.set(idx, val);
        }

        pub fn try_first_idx(self: ILIST) ListError!IDX {
            const idx = self.first_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }

        pub fn try_last_idx(self: ILIST) ListError!IDX {
            const idx = self.last_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }
        pub fn try_next_idx(self: ILIST, this_idx: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.next_idx(this_idx);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_nth_next_idx(self: ILIST, this_idx: IDX, n: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.nth_next_idx(this_idx, n);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_prev_idx(self: ILIST, this_idx: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.prev_idx(this_idx);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn try_nth_prev_idx(self: ILIST, this_idx: IDX, n: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.nth_prev_idx(this_idx, n);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn nth_idx(self: ILIST, n: IDX) IDX {
            var idx = self.first_idx();
            idx = self.nth_next_idx(idx, n);
            return idx;
        }
        pub fn try_nth_idx(self: ILIST, n: IDX) ListError!IDX {
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
        pub fn get_last(self: ILIST) T {
            const idx = self.last_idx();
            return self.get(idx);
        }
        pub fn try_get_last(self: ILIST) ListError!T {
            const idx = try self.try_last_idx();
            return self.get(idx);
        }
        pub fn get_last_ptr(self: ILIST) PTR {
            const idx = self.last_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_last_ptr(self: ILIST) ListError!PTR {
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
        pub fn get_first_ptr(self: ILIST) PTR {
            const idx = self.first_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_first_ptr(self: ILIST) ListError!PTR {
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
        pub fn get_nth(self: ILIST) T {
            const idx = self.nth_idx();
            return self.get(idx);
        }
        pub fn try_get_nth(self: ILIST) ListError!T {
            const idx = try self.try_nth_idx();
            return self.get(idx);
        }
        pub fn get_nth_ptr(self: ILIST) PTR {
            const idx = self.nth_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_nth_ptr(self: ILIST) ListError!PTR {
            const idx = try self.try_nth_idx();
            return self.get_ptr(idx);
        }
        pub fn set_nth(self: ILIST, val: T) void {
            const idx = self.nth_idx();
            return self.set(idx, val);
        }
        pub fn try_set_nth(self: ILIST, val: T) ListError!void {
            const idx = try self.try_nth_idx();
            return self.set(idx, val);
        }
        pub fn set_from(self: ILIST, self_idx: IDX, source: ILIST, source_idx: IDX) void {
            const val = source.get(source_idx);
            self.set(self_idx, val);
        }
        pub fn try_set_from(self: ILIST, self_idx: IDX, source: ILIST, source_idx: IDX) ListError!void {
            const val = try source.try_get(source_idx);
            return self.try_set(self_idx, val);
        }
        pub fn swap(self: ILIST, idx_a: IDX, idx_b: IDX) void {
            const val_a = self.get(idx_a);
            const val_b = self.get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn try_swap(self: ILIST, idx_a: IDX, idx_b: IDX) ListError!void {
            const val_a = try self.try_get(idx_a);
            const val_b = try self.try_get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn exchange(self: ILIST, self_idx: IDX, other: ILIST, other_idx: IDX) void {
            const val_self = self.get(self_idx);
            const val_other = other.get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn try_exchange(self: ILIST, self_idx: IDX, other: ILIST, other_idx: IDX) ListError!void {
            const val_self = try self.try_get(self_idx);
            const val_other = try other.try_get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn overwrite(self: ILIST, source_idx: IDX, dest_idx: IDX) void {
            const val = self.get(source_idx);
            self.set(dest_idx, val);
        }
        pub fn try_overwrite(self: ILIST, source_idx: IDX, dest_idx: IDX) ListError!void {
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
        pub fn fill_count(self: ILIST, val: T, count: IDX) CountResult {
            var i = self.first_idx();
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok and result.count < count) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn fill_at_index(self: ILIST, val: T, index: IDX) void {
            var i = index;
            var ok = self.idx_valid(i);
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn try_fill_at_index(self: ILIST, val: T, index: IDX) ListError!void {
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
        pub fn fill_count_at_index(self: ILIST, val: T, index: IDX, count: IDX) CountResult {
            var i = index;
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn try_fill_count_at_index(self: ILIST, val: T, index: IDX, count: IDX) ListError!CountResult {
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
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn fill_range(self: ILIST, val: T, first_idx_: IDX, last_idx_: IDX) CountResult {
            var i = first_idx_;
            var ok = self.idx_valid(first_idx_);
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_input = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn try_fill_range(self: ILIST, val: T, first_idx_: IDX, last_idx_: IDX) ListError!CountResult {
            var i = first_idx_;
            var ok = self.range_valid(first_idx_, last_idx_);
            if (!ok) {
                return ListError.invalid_range;
            }
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_input = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn copy_from_to(source: ILIST, source_range: PartialIterator, dest_range: Iterator) CopyResult {
            return copy_from_to_advanced(source, source_range, dest_range, .use_count_limit, .no_error_checks, .no_filter, null, null, .no_filter, null, null);
        }
        pub fn copy_from_to_advanced(
            source: ILIST,
            source_range: PartialIterator,
            dest_range: Iterator,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime src_filter: Iterator.IterFilter,
            src_userdata: anytype,
            src_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(src_userdata)) Iterator.IterSelect,
            comptime dest_filter: Iterator.IterFilter,
            dest_userdata: anytype,
            dest_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(dest_userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!CopyResult else CopyResult {
            var self_iter = source_range.to_iter(source);
            var dest_iter = dest_range;
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
            var next_dest = dest_iter.next_advanced(count_limit, error_checks, .advance, dest_filter, dest_userdata, dest_filter_func);
            while (next_self != null and next_dest != null) {
                const ok_next_dest = next_dest.?;
                const ok_next_self = next_self.?;
                ok_next_dest.list.set(ok_next_dest.idx, ok_next_self.val);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
                next_dest = dest_iter.next_advanced(count_limit, error_checks, .advance, dest_filter, dest_userdata, dest_filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
                if (dest_iter.err) |err| {
                    return err;
                }
            }
            var result = CopyResult{};
            result.count = @min(self_iter.count, dest_iter.count);
            result.count_matches_input = result.count == dest_iter.want_count or result.count == self_iter.want_count;
            result.full_dest_copied = !dest_iter.more_values;
            result.full_source_copied = !self_iter.more_values;
            result.next_dest_idx = dest_iter.curr;
            result.next_source_idx = self_iter.curr;
            return result;
        }
        fn _swizzle_internal(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: IDX, comptime force_count: bool, comptime is_try: bool) if (is_try) ListError!SwizzleResult else SwizzleResult {
            var sel_idx = selectors.first_idx();
            var more_selectors: bool = selectors.idx_valid(sel_idx);
            if (is_try) {
                if (!more_selectors) {
                    return ListError.invalid_index;
                }
            }
            var val: T = undefined;
            var source: ILIST = undefined;
            var source_idx: IDX = undefined;
            var val_idx: IDX = undefined;
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
                result.count_matches_input = result.count == count;
            } else {
                result.count_matches_input = true;
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
        pub fn swizzle_count(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: IDX) SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, false);
        }
        pub fn try_swizzle_count(self: ILIST, range: Range, sources: IListList, selectors: IIdxList, count: IDX) ListError!SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, true);
        }
        pub fn is_sorted(self: ILIST, greater_than: *const CompareFunc) bool {
            var i: IDX = undefined;
            var ii: IDX = undefined;
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
            var i: IDX = undefined;
            var j: IDX = undefined;
            var jj: IDX = undefined;
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
            var hi: IDX = undefined;
            var lo: IDX = undefined;
            var mid: Range = undefined;
            var rng: Range = undefined;
            var ok: bool = undefined;
            lo = self.first_idx();
            hi = self.last_idx();
            partition_stack.clear();
            ok = partition_stack.try_ensure_free_slots(2);
            if (!ok) {
                return ListError.failed_to_grow_list;
            }
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
                ok = partition_stack.try_ensure_free_slots(4);
                if (!ok) {
                    return ListError.failed_to_grow_list;
                }
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
        fn _quicksort_partition(self: ILIST, greater_than: *const CompareFunc, less_than: *const CompareFunc, lo: IDX, hi: IDX) Range {
            const pivot_idx: IDX = undefined;
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
            var less_idx: IDX = lo;
            var equal_idx: IDX = lo;
            var more_idx: IDX = hi;
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
            self_range: PartialIterator,
            userdata: anytype,
            action: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) bool,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
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
        pub fn for_each(self: ILIST, self_range: PartialIterator, userdata: anytype, action: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) bool) CountResult {
            return for_each_advanced(self, self_range, userdata, action, .no_count_limit, .error_checks, .no_filter, null);
        }
        pub fn filter_indexes_advanced(
            self: ILIST,
            self_range: PartialIterator,
            userdata: anytype,
            filter_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
            output_list: IIdxList,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, .use_filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                const ok = output_list.try_ensure_free_slots(1);
                if (error_checks == .error_checks and !ok) {
                    return ListError.failed_to_grow_list;
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
        pub fn filter_indexes(self: ILIST, self_range: PartialIterator, userdata: anytype, filter_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect, output_list: IIdxList) CountResult {
            return self.filter_indexes_advanced(self, self_range, userdata, filter_func, output_list, .use_count_limit, .no_error_checks);
        }
        pub fn transform_values_advanced(
            self: ILIST,
            self_range: PartialIterator,
            userdata: anytype,
            comptime OUT_TYPE: type,
            comptime OUT_PTR: type,
            transform_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            output_list: IList(OUT_TYPE, OUT_PTR, IDX),
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                const ok = output_list.try_ensure_free_slots(1);
                if (error_checks == .error_checks and !ok) {
                    return ListError.failed_to_grow_list;
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
        pub fn transform_values(self: ILIST, self_range: PartialIterator, userdata: anytype, comptime OUT_TYPE: type, comptime OUT_PTR: type, transform_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) OUT_TYPE, output_list: IList(OUT_TYPE, OUT_PTR, IDX)) CountResult {
            return self.transform_values_advanced(self_range, userdata, OUT_TYPE, OUT_PTR, transform_func, output_list, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn accumulate_result_advanced(
            self: ILIST,
            self_range: PartialIterator,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
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
            self_range: PartialIterator,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
        ) AccumulateResult(@TypeOf(initial_accumulation)) {
            return self.accumulate_result_advanced(self_range, initial_accumulation, userdata, accumulate_func, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn ensure_free_slots(self: ILIST, count: IDX, mem_alloc: Allocator) void {
            self.try_ensure_free_slots(count, mem_alloc);
        }
        pub fn append_slots(self: ILIST, count: IDX, mem_alloc: Allocator) Range {
            self.ensure_free_slots(count, mem_alloc);
            return self.append_slots_assume_capacity(count);
        }
        pub fn try_append_slots(self: ILIST, count: IDX, mem_alloc: Allocator) ListError!Range {
            const ok = self.try_ensure_free_slots(count, mem_alloc);
            if (!ok) {
                return ListError.failed_to_grow_list;
            }
            return self.append_slots_assume_capacity(count);
        }
        pub fn append_zig_slice(self: ILIST, slice_: []T, mem_alloc: Allocator) Range {
            self.ensure_free_slots(slice_.len, mem_alloc);
            return _append_zig_slice(self, slice_);
        }
        pub fn try_append_zig_slice(self: ILIST, slice_: []T, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(slice_.len, mem_alloc);
            return _append_zig_slice(self, slice_);
        }
        fn _append_zig_slice(self: ILIST, slice_: []T) Range {
            var slice_list = from_slice(T, &slice_);
            var slice_iter = slice_list.iterator(.entire_list());
            const append_range = self.append_slots_assume_capacity(slice_.len);
            var append_iter = self.iterator(.use_range(append_range));
            while (append_iter.next()) |to| {
                const from = slice_iter.next();
                to.list.set(to.idx, from.?.val);
            }
            return append_range;
        }
        pub fn append(self: ILIST, val: T, mem_alloc: Allocator) IDX {
            self.ensure_free_slots(1, mem_alloc);
            const append_range = self.append_slots_assume_capacity(1);
            self.set(append_range.first_idx, val);
            return append_range.first_idx;
        }
        pub fn try_append(self: ILIST, val: T, mem_alloc: Allocator) ListError!IDX {
            try self.try_ensure_free_slots(1, mem_alloc);
            const append_range = self.append_slots_assume_capacity(1);
            self.set(append_range.first_idx, val);
            return append_range.first_idx;
        }
        pub fn append_list(self: ILIST, list: ILIST, mem_alloc: Allocator) Range {
            self.ensure_free_slots(list.len, mem_alloc);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.entire_list(), .use_range(self, append_range));
            return append_range;
        }
        pub fn try_append_list(self: ILIST, list: ILIST, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(list.len, mem_alloc);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.entire_list(), .use_range(self, append_range));
            return append_range;
        }
        pub fn append_list_range(self: ILIST, list: ILIST, list_range: Range, mem_alloc: Allocator) Range {
            self.ensure_free_slots(list.len, mem_alloc);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, append_range));
            return append_range;
        }
        pub fn try_append_list_range(self: ILIST, list: ILIST, list_range: Range, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(list.len, mem_alloc);
            const append_range = self.append_slots_assume_capacity(list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, append_range));
            return append_range;
        }
        pub fn insert_slots(self: ILIST, idx: IDX, count: IDX, mem_alloc: Allocator) Range {
            self.ensure_free_slots(count, mem_alloc);
            return self.insert_slots_assume_capacity(idx, count);
        }
        pub fn try_insert_slots(self: ILIST, idx: IDX, count: IDX, mem_alloc: Allocator) ListError!Range {
            const ok = self.try_ensure_free_slots(count, mem_alloc);
            if (!ok) {
                return ListError.failed_to_grow_list;
            }
            return self.insert_slots_assume_capacity(idx, count);
        }
        pub fn insert_zig_slice(self: ILIST, idx: IDX, slice_: []T, mem_alloc: Allocator) Range {
            self.ensure_free_slots(slice_.len, mem_alloc);
            return _insert_zig_slice(self, idx, slice_);
        }
        pub fn try_insert_zig_slice(self: ILIST, idx: IDX, slice_: []T, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(slice_.len, mem_alloc);
            return _insert_zig_slice(self, idx, slice_);
        }
        fn _insert_zig_slice(self: ILIST, idx: IDX, slice_: []T) Range {
            var slice_list = from_slice(T, &slice_);
            var slice_iter = slice_list.iterator(.entire_list());
            const insert_range = self.insert_slots_assume_capacity(idx, slice_.len);
            var insert_iter = self.iterator(.use_range(insert_range));
            while (insert_iter.next()) |to| {
                const from = slice_iter.next();
                to.list.set(to.idx, from.?.val);
            }
            return insert_range;
        }
        pub fn insert(self: ILIST, idx: IDX, val: T, mem_alloc: Allocator) IDX {
            self.ensure_free_slots(1, mem_alloc);
            const insert_range = self.insert_slots_assume_capacity(idx, 1);
            self.set(insert_range.first_idx, val);
            return insert_range.first_idx;
        }
        pub fn try_insert(self: ILIST, idx: IDX, val: T, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(1, mem_alloc);
            const insert_range = self.insert_slots_assume_capacity(idx, 1);
            self.set(insert_range.first_idx, val);
            return insert_range.first_idx;
        }
        pub fn insert_list(self: ILIST, idx: IDX, list: ILIST, mem_alloc: Allocator) Range {
            self.ensure_free_slots(list.len, mem_alloc);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.entire_list(), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn try_insert_list(self: ILIST, idx: IDX, list: ILIST, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(list.len, mem_alloc);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.entire_list(), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn insert_list_range(self: ILIST, idx: IDX, list: ILIST, list_range: Range, mem_alloc: Allocator) Range {
            self.ensure_free_slots(list.len, mem_alloc);
            const insert_range = self.insert_slots_assume_capacity(idx, list.len);
            list.copy_from_to(.use_range(list_range), .use_range(self, insert_range));
            return insert_range;
        }
        pub fn try_insert_list_range(self: ILIST, idx: IDX, list: ILIST, list_range: Range, mem_alloc: Allocator) ListError!Range {
            try self.try_ensure_free_slots(list.len, mem_alloc);
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
        pub fn delete(self: ILIST, idx: IDX) void {
            self.delete_range(.single_idx(idx));
        }
        pub fn try_delete(self: ILIST, idx: IDX) ListError!void {
            return self.try_delete_range(.single_idx(idx));
        }
        pub fn swap_delete(self: ILIST, idx: IDX) void {
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
        }
        pub fn try_swap_delete(self: ILIST, idx: IDX) ListError!void {
            self.swap(idx, self.last_idx());
            return self.try_delete_range(.single_idx(self.last_idx()));
        }
        pub fn delete_count(self: ILIST, idx: IDX, count: IDX) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            self.delete_range(rng);
        }
        pub fn try_delete_count(self: ILIST, idx: IDX, count: IDX) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_delete_range(rng);
        }
        pub fn remove_range(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) void {
            output.clear();
            var self_iter = self.iterator(.use_range(range));
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
            var self_iter = self.iterator(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn remove_range_append(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) void {
            var self_iter = self.iterator(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn try_remove_range_append(self: ILIST, range: Range, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            if (!self.range_valid(range)) {
                return ListError.invalid_range;
            }
            var self_iter = self.iterator(.use_range(range));
            while (self_iter.next()) |out_val| {
                output.append(out_val.val, output_mem_alloc);
            }
            self.delete_range(range);
        }
        pub fn remove_count(self: ILIST, idx: IDX, count: IDX, output: ILIST, output_mem_alloc: Allocator) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            self.remove_range(rng, output, output_mem_alloc);
        }
        pub fn try_remove_count(self: ILIST, idx: IDX, count: IDX, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_remove_range(rng, output, output_mem_alloc);
        }
        pub fn remove_count_append(self: ILIST, idx: IDX, count: IDX, output: ILIST, output_mem_alloc: Allocator) void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.remove_range_append(rng, output, output_mem_alloc);
        }
        pub fn try_remove_count_append(self: ILIST, idx: IDX, count: IDX, output: ILIST, output_mem_alloc: Allocator) ListError!void {
            const rng = Range.new_range(idx, self.nth_next_idx(idx, count - 1));
            return self.try_remove_range_append(rng, output, output_mem_alloc);
        }
        pub fn remove(self: ILIST, idx: IDX) T {
            const val = self.get(idx);
            self.delete_range(.single_idx(idx));
            return val;
        }
        pub fn try_remove(self: ILIST, idx: IDX) ListError!T {
            const val = try self.try_get(idx);
            self.delete_range(.single_idx(idx));
            return val;
        }
        pub fn swap_remove(self: ILIST, idx: IDX) T {
            const val = self.get(idx);
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
            return val;
        }
        pub fn try_swap_remove(self: ILIST, idx: IDX) ListError!T {
            const val = try self.try_get(idx);
            self.swap(idx, self.last_idx());
            self.delete_range(.single_idx(self.last_idx()));
            return val;
        }
        pub fn replace_advanced(
            self: ILIST,
            self_range: PartialIterator,
            source: Iterator,
            self_mem_alloc: Allocator,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime self_filter: Iterator.IterFilter,
            self_userdata: anytype,
            self_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(self_userdata)) Iterator.IterSelect,
            comptime src_filter: Iterator.IterFilter,
            src_userdata: anytype,
            src_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(src_userdata)) Iterator.IterSelect,
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
        pub fn replace(self: ILIST, self_range: PartialIterator, source: Iterator, self_mem_alloc: Allocator) ListError!void {
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
        //CHECKPOINT queue-like funcs
    };
}

pub fn from_slice(comptime T: type, slice_ptr: *[]T) IList(T, *T, usize) {
    return SliceAdapter.SliceAdapter(T).adapt(slice_ptr);
}
