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
const Flags = Root.Flags.Flags;
const IteratorState = Root.IList_Iterator.IteratorState;

const Utils = Root.Utils;
const IList = Root.IList.IList;

const NO_ALLOC = DummyAllocator.allocator_panic;

pub fn ConcreteTableValueFuncs(comptime T: type, comptime LIST: type, comptime ALLOC: type) type {
    return struct {
        /// Return the value at the given index
        get: fn (self: LIST, idx: usize, alloc: ALLOC) T,
        /// Return a pointer to the value at a given index
        get_ptr: fn (self: LIST, idx: usize, alloc: ALLOC) *T,
        /// Set the value at the given index
        set: fn (self: LIST, idx: usize, val: T, alloc: ALLOC) void,
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        move: fn (self: LIST, old_idx: usize, new_idx: usize, alloc: ALLOC) void,
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        move_range: fn (self: LIST, range: Range, new_first_idx: usize, alloc: ALLOC) void,
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        try_ensure_free_slots: fn (self: LIST, count: usize, alloc: ALLOC) error{failed_to_grow_list}!void,
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        shrink_cap_reserve_at_most: fn (self: LIST, reserve_at_most: usize, alloc: ALLOC) void,
        /// Insert `n` value slots with undefined values at the given index,
        /// moving other items at or after that index to after the new ones.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        insert_slots_assume_capacity: fn (self: LIST, idx: usize, count: usize, alloc: ALLOC) Range,
        /// Insert `n` value slots with undefined values at the end of the list.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        append_slots_assume_capacity: fn (self: LIST, count: usize, alloc: ALLOC) Range,
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        trim_len: fn (self: LIST, trim_n: usize, alloc: ALLOC) void,
        /// Delete one value at given index
        delete: fn (self: LIST, idx: usize, alloc: ALLOC) void,
        /// Delete many values within given range, inclusive
        delete_range: fn (self: LIST, range: Range, alloc: ALLOC) void,
        /// Set list to an empty state, but retain existing capacity, if possible
        clear: fn (self: LIST, alloc: ALLOC) void,
        /// Set list to an empty state and return memory to allocator
        free: fn (self: LIST, alloc: ALLOC) void,
    };
}

pub fn ConcreteTableIndexFuncs(comptime LIST: type) type {
    return struct {
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
        prefer_linear_ops: fn (self: LIST) bool,
        /// Should hold a constant boolean value describing whether consecutive indexes,
        /// (eg. `0, 1, 2, 3, 4, 5`) are in their logical/proper order (not necessarily sorted)
        ///
        /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        consecutive_indexes_in_order: fn (self: LIST) bool,
        /// Should hold a constant boolean value describing whether all indexes greater-than-or-equal-to
        /// `0` AND less-than `slice.len()` are valid
        ///
        /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        all_indexes_zero_to_len_valid: fn (self: LIST) bool,
        /// If set to `true`, calling `list.try_ensure_free_slots(count)` will not change the result
        /// of `list.cap()`, but a `true` result still indicates that an append or insert is expected
        /// to behave as expected.
        ///
        /// An example of this being true may be an interface for a `File` or slice `[]T`, where
        /// there is no concept of allocated-but-unused memory, but can still be appended to
        /// (with re-allocation)
        ensure_free_doesnt_change_cap: fn (self: LIST) bool,
        /// Should be an index that will ALWAYS result in `idx_valid(always_invalid_idx) == false`
        ///
        /// Used for initialization of some data structures and algorithms
        always_invalid_idx: fn (self: LIST) usize,
        /// Return the number of items in the list
        len: fn (self: LIST) usize,
        /// Return the total number of items the list can hold
        /// without reallocation
        cap: fn (self: LIST) usize,
        /// Return the first index in the list
        first_idx: fn (self: LIST) usize,
        /// Return the last valid index in the list
        last_idx: fn (self: LIST) usize,
        /// Return the index directly after the given index in the list
        next_idx: fn (self: LIST, this_idx: usize) usize,
        /// Return the index `n` places after the given index in the list,
        /// which may be 0 (returning the given index)
        nth_next_idx: fn (self: LIST, this_idx: usize, n: usize) usize,
        /// Return the index directly before the given index in the list
        prev_idx: fn (self: LIST, this_idx: usize) usize,
        /// Return the index `n` places before the given index in the list,
        /// which may be 0 (returning the given index)
        nth_prev_idx: fn (self: LIST, this_idx: usize, n: usize) usize,
        /// Return `true` if the index is valid for the current state
        /// of the list, `false` otherwise
        idx_valid: fn (self: LIST, idx: usize) bool,
        /// Return `true` if the range is valid for the current state
        /// of the list, `false` otherwise. The first index must
        /// come before or be equal to the last index, and all
        /// indexes in between must also be valid
        range_valid: fn (self: LIST, range: Range) bool,
        /// Return whether the given index falls within the given range,
        /// inclusive
        idx_in_range: fn (self: LIST, idx: usize, range: Range) bool,
        /// Split a range roughly in half, returning an index
        /// as close to the true center point as possible.
        /// Implementations may choose not to return an index
        /// close to the actual middle of the range if
        /// finding that middle index is expensive,
        /// but the returned index MUST be contained within the
        /// given range
        split_range: fn (self: LIST, range: Range) usize,
        /// Return the number of indexes included within a range,
        /// inclusive of the last index
        range_len: fn (self: LIST, range: Range) usize,
    };
}

pub fn ConcreteTableIndexFuncsNaturalIndexes(comptime LIST: type, comptime LEN_PARENT_FIELD: ?[]const u8, comptime LEN_FIELD: []const u8, comptime CAP_PARENT_FIELD: ?[]const u8, comptime CAP_FIELD: []const u8, comptime ensure_free_doesnt_change_cap_: bool) ConcreteTableIndexFuncs(LIST) {
    const PROTO = struct {
        fn prefer_linear_ops(_: LIST) bool {
            return false;
        }
        fn all_indexes_zero_to_len_valid(_: LIST) bool {
            return true;
        }
        fn consecutive_indexes_in_order(_: LIST) bool {
            return true;
        }
        fn ensure_free_doesnt_change_cap(_: LIST) bool {
            return ensure_free_doesnt_change_cap_;
        }
        fn always_invalid_idx(_: LIST) usize {
            return math.maxInt(usize);
        }
        fn len(self: LIST) usize {
            if (LEN_PARENT_FIELD) |LEN_PARENT| {
                return @intCast(@field(@field(self, LEN_PARENT), LEN_FIELD));
            } else {
                return @intCast(@field(self, LEN_FIELD));
            }
        }
        fn cap(self: LIST) usize {
            if (CAP_PARENT_FIELD) |CAP_PARENT| {
                return @intCast(@field(@field(self, CAP_PARENT), CAP_FIELD));
            } else {
                return @intCast(@field(self, CAP_FIELD));
            }
        }
        fn first_idx(_: LIST) usize {
            return 0;
        }
        fn last_idx(self: LIST) usize {
            return len(self) -% 1;
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
        fn idx_in_range(_: LIST, idx: usize, range: Range) bool {
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
        .prefer_linear_ops = PROTO.prefer_linear_ops,
        .all_indexes_zero_to_len_valid = PROTO.all_indexes_zero_to_len_valid,
        .consecutive_indexes_in_order = PROTO.consecutive_indexes_in_order,
        .ensure_free_doesnt_change_cap = PROTO.ensure_free_doesnt_change_cap,
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

pub fn ConcreteTableIndexFuncsIList(comptime T: type) ConcreteTableIndexFuncs(IList(T)) {
    const LIST = IList(T);
    const PROTO = struct {
        fn prefer_linear_ops(self: LIST) bool {
            return self.vtable.prefer_linear_ops;
        }
        fn all_indexes_zero_to_len_valid(self: LIST) bool {
            return self.vtable.all_indexes_zero_to_len_valid;
        }
        fn consecutive_indexes_in_order(self: LIST) bool {
            return self.vtable.consecutive_indexes_in_order;
        }
        fn ensure_free_doesnt_change_cap(self: LIST) bool {
            return self.vtable.ensure_free_doesnt_change_cap;
        }
        fn always_invalid_idx(self: LIST) usize {
            return self.vtable.always_invalid_idx;
        }
        fn len(self: LIST) usize {
            return self.vtable.len(self.object);
        }
        fn cap(self: LIST) usize {
            return self.vtable.cap(self.object);
        }
        fn first_idx(self: LIST) usize {
            return self.vtable.first_idx(self.object);
        }
        fn last_idx(self: LIST) usize {
            return self.vtable.last_idx(self.object);
        }
        fn next_idx(self: LIST, this_idx: usize) usize {
            return self.vtable.next_idx(self.object, this_idx);
        }
        fn nth_next_idx(self: LIST, this_idx: usize, n: usize) usize {
            return self.vtable.nth_next_idx(self.object, this_idx, n);
        }
        fn prev_idx(self: LIST, this_idx: usize) usize {
            return self.vtable.prev_idx(self.object, this_idx);
        }
        fn nth_prev_idx(self: LIST, this_idx: usize, n: usize) usize {
            return self.vtable.nth_prev_idx(self.object, this_idx, n);
        }
        fn idx_valid(self: LIST, idx: usize) bool {
            return self.vtable.idx_valid(self.object, idx);
        }
        fn range_valid(self: LIST, range: Range) bool {
            return self.vtable.range_valid(self.object, range);
        }
        fn idx_in_range(self: LIST, idx: usize, range: Range) bool {
            return self.vtable.idx_in_range(self.object, idx, range);
        }
        fn split_range(self: LIST, range: Range) usize {
            return self.vtable.split_range(self.object, range);
        }
        fn range_len(self: LIST, range: Range) usize {
            return self.vtable.range_len(self.object, range);
        }
    };
    return ConcreteTableIndexFuncs(LIST){
        .prefer_linear_ops = PROTO.prefer_linear_ops,
        .all_indexes_zero_to_len_valid = PROTO.all_indexes_zero_to_len_valid,
        .consecutive_indexes_in_order = PROTO.consecutive_indexes_in_order,
        .ensure_free_doesnt_change_cap = PROTO.ensure_free_doesnt_change_cap,
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

pub fn ConcreteTableValueFuncsIList(comptime T: type) ConcreteTableValueFuncs(T, IList(T), Allocator) {
    const LIST = IList(T);
    const PROTO = struct {
        fn get(self: LIST, idx: usize, alloc: Allocator) T {
            return self.vtable.get(self.object, idx, alloc);
        }
        fn get_ptr(self: LIST, idx: usize, alloc: Allocator) *T {
            return self.vtable.get_ptr(self.object, idx, alloc);
        }
        fn set(self: LIST, idx: usize, val: T, alloc: Allocator) void {
            return self.vtable.set(self.object, idx, val, alloc);
        }
        fn move(self: LIST, old_idx: usize, new_idx: usize, alloc: Allocator) void {
            return self.vtable.move(self.object, old_idx, new_idx, alloc);
        }
        fn move_range(self: LIST, range: Range, new_first_idx: usize, alloc: Allocator) void {
            return self.vtable.move_range(self.object, range, new_first_idx, alloc);
        }
        fn try_ensure_free_slots(self: LIST, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            return self.vtable.try_ensure_free_slots(self.object, count, alloc);
        }
        fn shrink_cap_reserve_at_most(self: LIST, reserve_at_most: usize, alloc: Allocator) void {
            return self.vtable.shrink_cap_reserve_at_most(self.object, reserve_at_most, alloc);
        }
        fn append_slots_assume_capacity(self: LIST, count: usize, alloc: Allocator) Range {
            return self.vtable.append_slots_assume_capacity(self.object, count, alloc);
        }
        fn insert_slots_assume_capacity(self: LIST, idx: usize, count: usize, alloc: Allocator) Range {
            return self.vtable.insert_slots_assume_capacity(self.object, idx, count, alloc);
        }
        fn trim_len(self: LIST, trim_n: usize, alloc: Allocator) void {
            return self.vtable.trim_len(self.object, trim_n, alloc);
        }
        fn delete(self: LIST, idx: usize, alloc: Allocator) void {
            return self.vtable.delete(self.object, idx, alloc);
        }
        fn delete_range(self: LIST, range: Range, alloc: Allocator) void {
            return self.vtable.delete_range(self.object, range, alloc);
        }
        fn clear(self: LIST, alloc: Allocator) void {
            return self.vtable.clear(self.object, alloc);
        }
        fn free(self: LIST, alloc: Allocator) void {
            return self.vtable.free(self.object, alloc);
        }
    };
    return ConcreteTableValueFuncs(T, LIST, Allocator){
        .get = PROTO.get,
        .get_ptr = PROTO.get_ptr,
        .set = PROTO.set,
        .move = PROTO.move,
        .move_range = PROTO.move_range,
        .try_ensure_free_slots = PROTO.try_ensure_free_slots,
        .shrink_cap_reserve_at_most = PROTO.shrink_cap_reserve_at_most,
        .append_slots_assume_capacity = PROTO.append_slots_assume_capacity,
        .insert_slots_assume_capacity = PROTO.insert_slots_assume_capacity,
        .trim_len = PROTO.trim_len,
        .delete = PROTO.delete,
        .delete_range = PROTO.delete_range,
        .clear = PROTO.clear,
        .free = PROTO.free,
    };
}

pub fn ConcreteTableNativeSliceFuncs(comptime T: type, comptime LIST: type) type {
    return struct {
        /// Return whether the func `native_slice()` can be used
        has_native_slice: fn (self: LIST) bool,
        /// Return a native zig slice `[]T` that holds
        /// the values in the provided range, without
        /// performing any allocations/copies
        native_slice: fn (self: LIST, range: Range) []T,
    };
}

pub fn NativeRangeSliceNaturalIndexes(comptime T: type, comptime LIST: type, comptime PTR_PARENT_FIELD: ?[]const u8, comptime PTR_FIELD: []const u8) ConcreteTableNativeSliceFuncs(T, LIST) {
    const PROTO = struct {
        fn has_native_slice(_: LIST) bool {
            return true;
        }
        fn native_slice(self: LIST, range: Range) []T {
            if (PTR_PARENT_FIELD) |PTR_PARENT| {
                return @field(@field(self, PTR_PARENT), PTR_FIELD)[range.first_idx .. range.last_idx + 1];
            } else {
                return @field(self, PTR_FIELD)[range.first_idx .. range.last_idx + 1];
            }
        }
    };
    return ConcreteTableNativeSliceFuncs(T, LIST){
        .has_native_slice = PROTO.has_native_slice,
        .native_slice = PROTO.native_slice,
    };
}

pub fn NativeRangeSliceIList(comptime T: type) ConcreteTableNativeSliceFuncs(T, IList(T)) {
    const LIST = IList(T);
    const PROTO = struct {
        fn has_native_slice(self: LIST) bool {
            return self.vtable.allow_native_slice;
        }
        fn native_slice(self: LIST, range: Range) []T {
            const ptr: [*]T = @ptrCast(self.vtable.get_ptr(self.object, range.first_idx, self.alloc));
            const rlen = self.vtable.range_len(self.object, range);
            return ptr[0..rlen];
        }
    };
    return ConcreteTableNativeSliceFuncs(T, LIST){
        .has_native_slice = PROTO.has_native_slice,
        .native_slice = PROTO.native_slice,
    };
}

pub fn CreateConcretePrototypeNaturalIndexes(comptime T: type, comptime LIST: type, comptime ALLOC: type, comptime PTR_PARENT_FIELD: ?[]const u8, comptime PTR_FIELD: []const u8, comptime LEN_PARENT_FIELD: ?[]const u8, comptime LEN_FIELD: []const u8, comptime CAP_PARENT_FIELD: ?[]const u8, comptime CAP_FIELD: []const u8, comptime ensure_free_doesnt_change_cap_: bool, comptime val_funcs: ConcreteTableValueFuncs(T, LIST, ALLOC)) type {
    const idx_funcs = ConcreteTableIndexFuncsNaturalIndexes(LIST, LEN_PARENT_FIELD, LEN_FIELD, CAP_PARENT_FIELD, CAP_FIELD, ensure_free_doesnt_change_cap_);
    const nat_slice = NativeRangeSliceNaturalIndexes(T, LIST, PTR_PARENT_FIELD, PTR_FIELD);
    return CreateConcretePrototype(T, LIST, ALLOC, val_funcs, idx_funcs, nat_slice);
}

pub fn CreateConcretePrototypeIList(comptime T: type) type {
    const idx_funcs = ConcreteTableIndexFuncsIList(T);
    const val_funcs = ConcreteTableValueFuncsIList(T);
    const nat_slice = NativeRangeSliceIList(T);
    return CreateConcretePrototype(T, IList(T), Allocator, val_funcs, idx_funcs, nat_slice);
}

pub fn CreateConcretePrototype(comptime T: type, comptime LIST: type, comptime ALLOC: type, comptime val_funcs: ConcreteTableValueFuncs(T, LIST, ALLOC), comptime idx_funcs: ConcreteTableIndexFuncs(LIST), comptime slice_funcs: ConcreteTableNativeSliceFuncs(T, LIST)) type {
    return struct {
        //*** Native slice funcs ***

        /// Return whether the func `native_slice()` can be used
        pub const has_native_slice = slice_funcs.has_native_slice;
        /// Return a native zig slice `[]T` that holds
        /// the values in the provided range, without
        /// performing any allocations/copies
        pub const native_slice = slice_funcs.native_slice;

        //*** Property funcs ***

        /// Should hold a constant boolean value describing whether certain operations will peform better with linear operations instead of binary-split operations
        ///
        /// If range_len(), nth_next_idx(), and nth_prev_idx() operate in O(N) time instead of O(1), this should return true
        ///
        /// An example requiring true would be a linked list, where one must traverse in linear time to find the true index 'n places' after a given index, or the number of items between two indexes
        ///
        /// Returning the correct value will allow some operations to use alternate, more efficient algorithms
        pub const prefer_linear_ops = idx_funcs.prefer_linear_ops;
        /// Should hold a constant boolean value describing whether all indexes greater-than-or-equal-to 0 AND less-than len() are valid
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        pub const all_indexes_zero_to_len_valid = idx_funcs.all_indexes_zero_to_len_valid;
        /// Should hold a constant boolean value describing whether consecutive indexes, (eg. 0, 1, 2, 3, 4, 5)
        /// are located at consecutive memory addresses
        ///
        /// An example where this would be false is an implementation of a linked list
        ///
        /// This allows some algorithms to use more efficient paths
        pub const consecutive_indexes_in_order = idx_funcs.consecutive_indexes_in_order;
        /// If this returns true, calling `try_ensure_free_slots(count)` will not change the result of `cap()`,
        /// but a non-error result still indicates that an append or insert is expected to behave as expected.
        ///
        /// An example of this being true may be an interface for a File or slice []T, where there is no concept of allocated-but-unused memory,
        /// but can still be appended to (with re-allocation)
        pub const ensure_free_doesnt_change_cap = idx_funcs.ensure_free_doesnt_change_cap;

        //*** Core index funcs ***

        /// Return an index that will ALWAYS result in `idx_valid(idx) == false`
        pub const always_invalid_idx = idx_funcs.always_invalid_idx;
        /// Return the number of items in the list
        pub const len = idx_funcs.len;
        /// Return the total number of items the list can hold
        /// without reallocation
        pub const cap = idx_funcs.cap;
        /// Return the first index in the list
        pub const first_idx = idx_funcs.first_idx;
        /// Return the last valid index in the list
        pub const last_idx = idx_funcs.last_idx;
        /// Return the index directly after the given index in the list
        pub const next_idx = idx_funcs.next_idx;
        /// Return the index `n` places after the given index in the list,
        /// which may be 0 (returning the given index)
        pub const nth_next_idx = idx_funcs.nth_next_idx;
        /// Return the index directly before the given index in the list
        pub const prev_idx = idx_funcs.prev_idx;
        /// Return the index `n` places before the given index in the list,
        /// which may be 0 (returning the given index)
        pub const nth_prev_idx = idx_funcs.nth_prev_idx;
        /// Return `true` if the index is valid for the current state
        /// of the list, `false` otherwise
        pub const idx_valid = idx_funcs.idx_valid;
        /// Return `true` if the range is valid for the current state
        /// of the list, `false` otherwise. The first index must
        /// come before or be equal to the last index, and all
        /// indexes in between must also be valid
        pub const range_valid = idx_funcs.range_valid;
        /// Return whether the given index falls within the given range,
        /// inclusive
        pub const idx_in_range = idx_funcs.idx_in_range;
        /// Split a range roughly in half, returning an index
        /// as close to the true center point as possible.
        /// Implementations may choose not to return an index
        /// close to the actual middle of the range if
        /// finding that middle index is expensive
        pub const split_range = idx_funcs.split_range;
        /// Return the number of indexes included within a range,
        /// inclusive of the last index
        pub const range_len = idx_funcs.range_len;

        //*** Core value funcs ***

        /// Return the value at the given index
        pub const get = val_funcs.get;
        /// Return a pointer to the value at a given index
        pub const get_ptr = val_funcs.get_ptr;
        /// Set the value at the given index
        pub const set = val_funcs.set;
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub const move = val_funcs.move;
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub const move_range = val_funcs.move_range;
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        pub const try_ensure_free_slots = val_funcs.try_ensure_free_slots;
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        pub const shrink_cap_reserve_at_most = val_funcs.shrink_cap_reserve_at_most;
        /// Insert `n` value slots with undefined values at the given index,
        /// moving other items at or after that index to after the new ones.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub const insert_slots_assume_capacity = val_funcs.insert_slots_assume_capacity;
        /// Append `n` value slots with undefined values at the end of the list.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub const append_slots_assume_capacity = val_funcs.append_slots_assume_capacity;
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        pub const trim_len = val_funcs.trim_len;
        /// Delete one value at given index
        pub const delete = val_funcs.delete;
        /// Delete many values within given range, inclusive
        pub const delete_range = val_funcs.delete_range;
        /// Set list to an empty state, but retain existing capacity, if possible
        pub const clear = val_funcs.clear;
        /// Set list to an empty state and return memory to allocator
        pub const free = val_funcs.free;

        pub fn VTABLE(
            comptime allow_native_slice_: bool,
            comptime ensure_free_doesnt_change_cap_: bool,
            comptime prefer_linear_ops_: bool,
            comptime always_invalid_idx_: usize,
        ) IList(T).VTable {
            const IFACE = struct {
                fn iface_get(object: *anyopaque, idx: usize, alloc: ALLOC) T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return get(self, idx, alloc);
                }
                fn iface_get_ptr(object: *anyopaque, idx: usize, alloc: ALLOC) *T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return get_ptr(self, idx, alloc);
                }
                fn iface_set(object: *anyopaque, idx: usize, val: T, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return set(self, idx, val, alloc);
                }
                fn iface_len(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return len(self);
                }
                fn iface_cap(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return cap(self);
                }
                fn iface_trim_len(object: *anyopaque, trim_n: usize, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return trim_len(self, trim_n, alloc);
                }
                fn iface_idx_valid(object: *anyopaque, idx: usize) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_valid(self, idx);
                }
                fn iface_range_valid(object: *anyopaque, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_valid(self, range);
                }
                fn iface_idx_in_range(object: *anyopaque, idx: usize, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_in_range(self, idx, range);
                }
                fn iface_range_len(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_len(self, range);
                }
                fn iface_split_range(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return split_range(self, range);
                }
                fn iface_first_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return first_idx(self);
                }
                fn iface_last_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return last_idx(self);
                }
                fn iface_next_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return next_idx(self, this_idx);
                }
                fn iface_prev_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return prev_idx(self, this_idx);
                }
                fn iface_nth_next_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_next_idx(self, this_idx, n);
                }
                fn iface_nth_prev_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_prev_idx(self, this_idx, n);
                }
                fn iface_move(object: *anyopaque, old_idx: usize, new_idx: usize, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return move(self, old_idx, new_idx, alloc);
                }
                fn iface_move_range(object: *anyopaque, range: Range, new_first_idx: usize, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return move_range(self, range, new_first_idx, alloc);
                }
                fn iface_try_ensure_free_slots(object: *anyopaque, count: usize, alloc: ALLOC) error{failed_to_grow_list}!void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return try_ensure_free_slots(self, count, alloc);
                }
                fn iface_shrink_cap_reserve_at_most(object: *anyopaque, reserve_at_most: usize, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return shrink_cap_reserve_at_most(self, reserve_at_most, alloc);
                }
                fn iface_append_slots_assume_capacity(object: *anyopaque, count: usize, alloc: ALLOC) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return append_slots_assume_capacity(self, count, alloc);
                }
                fn iface_insert_slots_assume_capacity(object: *anyopaque, idx: usize, count: usize, alloc: ALLOC) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return insert_slots_assume_capacity(self, idx, count, alloc);
                }
                fn iface_delete(object: *anyopaque, idx: usize, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return delete(self, idx, alloc);
                }
                fn iface_delete_range(object: *anyopaque, range: Range, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return delete_range(self, range, alloc);
                }
                fn iface_clear(object: *anyopaque, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return clear(self, alloc);
                }
                fn iface_free(object: *anyopaque, alloc: ALLOC) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return free(self, alloc);
                }
            };
            return IList(T).VTable{
                .allow_native_slice = allow_native_slice_,
                .ensure_free_doesnt_change_cap = ensure_free_doesnt_change_cap_,
                .prefer_linear_ops = prefer_linear_ops_,
                .always_invalid_idx = always_invalid_idx_,
                .get = IFACE.iface_get,
                .get_ptr = IFACE.iface_get_ptr,
                .set = IFACE.iface_set,
                .len = IFACE.iface_len,
                .trim_len = IFACE.iface_trim_len,
                .cap = IFACE.iface_cap,
                .idx_valid = IFACE.iface_idx_valid,
                .range_valid = IFACE.iface_range_valid,
                .idx_in_range = IFACE.iface_idx_in_range,
                .range_len = IFACE.iface_range_len,
                .split_range = IFACE.iface_split_range,
                .first_idx = IFACE.iface_first_idx,
                .last_idx = IFACE.iface_last_idx,
                .next_idx = IFACE.iface_next_idx,
                .nth_next_idx = IFACE.iface_nth_next_idx,
                .prev_idx = IFACE.iface_prev_idx,
                .nth_prev_idx = IFACE.iface_nth_prev_idx,
                .move = IFACE.iface_move,
                .move_range = IFACE.iface_move_range,
                .try_ensure_free_slots = IFACE.iface_try_ensure_free_slots,
                .shrink_cap_reserve_at_most = IFACE.iface_shrink_cap_reserve_at_most,
                .append_slots_assume_capacity = IFACE.iface_append_slots_assume_capacity,
                .insert_slots_assume_capacity = IFACE.iface_insert_slots_assume_capacity,
                .delete = IFACE.iface_delete,
                .delete_range = IFACE.iface_delete_range,
                .clear = IFACE.iface_clear,
                .free = IFACE.iface_free,
            };
        }

        pub fn VTABLE_ALLOC_CONVERT(
            comptime allow_native_slice_: bool,
            comptime ensure_free_doesnt_change_cap_: bool,
            comptime prefer_linear_ops_: bool,
            comptime always_invalid_idx_: usize,
            comptime alloc_convert: fn (iface_alloc: Allocator) ALLOC,
        ) IList(T).VTable {
            const IFACE = struct {
                fn iface_get(object: *anyopaque, idx: usize, alloc: Allocator) T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return get(self, idx, alloc_2);
                }
                fn iface_get_ptr(object: *anyopaque, idx: usize, alloc: Allocator) *T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return get_ptr(self, idx, alloc_2);
                }
                fn iface_set(object: *anyopaque, idx: usize, val: T, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return set(self, idx, val, alloc_2);
                }
                fn iface_len(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return len(self);
                }
                fn iface_cap(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return cap(self);
                }
                fn iface_trim_len(object: *anyopaque, trim_n: usize, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return trim_len(self, trim_n, alloc_2);
                }
                fn iface_idx_valid(object: *anyopaque, idx: usize) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_valid(self, idx);
                }
                fn iface_range_valid(object: *anyopaque, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_valid(self, range);
                }
                fn iface_idx_in_range(object: *anyopaque, idx: usize, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_in_range(self, idx, range);
                }
                fn iface_range_len(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_len(self, range);
                }
                fn iface_split_range(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return split_range(self, range);
                }
                fn iface_first_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return first_idx(self);
                }
                fn iface_last_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return last_idx(self);
                }
                fn iface_next_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return next_idx(self, this_idx);
                }
                fn iface_prev_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return prev_idx(self, this_idx);
                }
                fn iface_nth_next_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_next_idx(self, this_idx, n);
                }
                fn iface_nth_prev_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_prev_idx(self, this_idx, n);
                }
                fn iface_move(object: *anyopaque, old_idx: usize, new_idx: usize, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return move(self, old_idx, new_idx, alloc_2);
                }
                fn iface_move_range(object: *anyopaque, range: Range, new_first_idx: usize, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return move_range(self, range, new_first_idx, alloc_2);
                }
                fn iface_try_ensure_free_slots(object: *anyopaque, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return try_ensure_free_slots(self, count, alloc_2);
                }
                fn iface_shrink_cap_reserve_at_most(object: *anyopaque, reserve_at_most: usize, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return shrink_cap_reserve_at_most(self, reserve_at_most, alloc_2);
                }
                fn iface_append_slots_assume_capacity(object: *anyopaque, count: usize, alloc: Allocator) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return append_slots_assume_capacity(self, count, alloc_2);
                }
                fn iface_insert_slots_assume_capacity(object: *anyopaque, idx: usize, count: usize, alloc: Allocator) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return insert_slots_assume_capacity(self, idx, count, alloc_2);
                }
                fn iface_delete(object: *anyopaque, idx: usize, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return delete(self, idx, alloc_2);
                }
                fn iface_delete_range(object: *anyopaque, range: Range, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return delete_range(self, range, alloc_2);
                }
                fn iface_clear(object: *anyopaque, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return clear(self, alloc_2);
                }
                fn iface_free(object: *anyopaque, alloc: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    const alloc_2 = alloc_convert(alloc);
                    return free(self, alloc_2);
                }
            };
            return IList(T).VTable{
                .allow_native_slice = allow_native_slice_,
                .ensure_free_doesnt_change_cap = ensure_free_doesnt_change_cap_,
                .prefer_linear_ops = prefer_linear_ops_,
                .always_invalid_idx = always_invalid_idx_,
                .get = IFACE.iface_get,
                .get_ptr = IFACE.iface_get_ptr,
                .set = IFACE.iface_set,
                .len = IFACE.iface_len,
                .trim_len = IFACE.iface_trim_len,
                .cap = IFACE.iface_cap,
                .idx_valid = IFACE.iface_idx_valid,
                .range_valid = IFACE.iface_range_valid,
                .idx_in_range = IFACE.iface_idx_in_range,
                .range_len = IFACE.iface_range_len,
                .split_range = IFACE.iface_split_range,
                .first_idx = IFACE.iface_first_idx,
                .last_idx = IFACE.iface_last_idx,
                .next_idx = IFACE.iface_next_idx,
                .nth_next_idx = IFACE.iface_nth_next_idx,
                .prev_idx = IFACE.iface_prev_idx,
                .nth_prev_idx = IFACE.iface_nth_prev_idx,
                .move = IFACE.iface_move,
                .move_range = IFACE.iface_move_range,
                .try_ensure_free_slots = IFACE.iface_try_ensure_free_slots,
                .shrink_cap_reserve_at_most = IFACE.iface_shrink_cap_reserve_at_most,
                .append_slots_assume_capacity = IFACE.iface_append_slots_assume_capacity,
                .insert_slots_assume_capacity = IFACE.iface_insert_slots_assume_capacity,
                .delete = IFACE.iface_delete,
                .delete_range = IFACE.iface_delete_range,
                .clear = IFACE.iface_clear,
                .free = IFACE.iface_free,
            };
        }

        pub fn VTABLE_ALLOC_STATIC(
            comptime allow_native_slice_: bool,
            comptime ensure_free_doesnt_change_cap_: bool,
            comptime prefer_linear_ops_: bool,
            comptime always_invalid_idx_: usize,
            comptime alloc: ALLOC,
        ) IList(T).VTable {
            const IFACE = struct {
                fn iface_get(object: *anyopaque, idx: usize, _: Allocator) T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return get(self, idx, alloc);
                }
                fn iface_get_ptr(object: *anyopaque, idx: usize, _: Allocator) *T {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return get_ptr(self, idx, alloc);
                }
                fn iface_set(object: *anyopaque, idx: usize, val: T, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return set(self, idx, val, alloc);
                }
                fn iface_len(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return len(self);
                }
                fn iface_cap(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return cap(self);
                }
                fn iface_trim_len(object: *anyopaque, trim_n: usize, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return trim_len(self, trim_n, alloc);
                }
                fn iface_idx_valid(object: *anyopaque, idx: usize) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_valid(self, idx);
                }
                fn iface_range_valid(object: *anyopaque, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_valid(self, range);
                }
                fn iface_idx_in_range(object: *anyopaque, idx: usize, range: Range) bool {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return idx_in_range(self, idx, range);
                }
                fn iface_range_len(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return range_len(self, range);
                }
                fn iface_split_range(object: *anyopaque, range: Range) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return split_range(self, range);
                }
                fn iface_first_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return first_idx(self);
                }
                fn iface_last_idx(object: *anyopaque) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return last_idx(self);
                }
                fn iface_next_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return next_idx(self, this_idx);
                }
                fn iface_prev_idx(object: *anyopaque, this_idx: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return prev_idx(self, this_idx);
                }
                fn iface_nth_next_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_next_idx(self, this_idx, n);
                }
                fn iface_nth_prev_idx(object: *anyopaque, this_idx: usize, n: usize) usize {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return nth_prev_idx(self, this_idx, n);
                }
                fn iface_move(object: *anyopaque, old_idx: usize, new_idx: usize, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return move(self, old_idx, new_idx, alloc);
                }
                fn iface_move_range(object: *anyopaque, range: Range, new_first_idx: usize, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return move_range(self, range, new_first_idx, alloc);
                }
                fn iface_try_ensure_free_slots(object: *anyopaque, count: usize, _: Allocator) error{failed_to_grow_list}!void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return try_ensure_free_slots(self, count, alloc);
                }
                fn iface_shrink_cap_reserve_at_most(object: *anyopaque, reserve_at_most: usize, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return shrink_cap_reserve_at_most(self, reserve_at_most, alloc);
                }
                fn iface_append_slots_assume_capacity(object: *anyopaque, count: usize, _: Allocator) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return append_slots_assume_capacity(self, count, alloc);
                }
                fn iface_insert_slots_assume_capacity(object: *anyopaque, idx: usize, count: usize, _: Allocator) Range {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return insert_slots_assume_capacity(self, idx, count, alloc);
                }
                fn iface_delete(object: *anyopaque, idx: usize, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return delete(self, idx, alloc);
                }
                fn iface_delete_range(object: *anyopaque, range: Range, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return delete_range(self, range, alloc);
                }
                fn iface_clear(object: *anyopaque, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return clear(self, alloc);
                }
                fn iface_free(object: *anyopaque, _: Allocator) void {
                    const self: LIST = @ptrCast(@alignCast(object));
                    return free(self, alloc);
                }
            };
            return IList(T).VTable{
                .allow_native_slice = allow_native_slice_,
                .ensure_free_doesnt_change_cap = ensure_free_doesnt_change_cap_,
                .prefer_linear_ops = prefer_linear_ops_,
                .always_invalid_idx = always_invalid_idx_,
                .get = IFACE.iface_get,
                .get_ptr = IFACE.iface_get_ptr,
                .set = IFACE.iface_set,
                .len = IFACE.iface_len,
                .trim_len = IFACE.iface_trim_len,
                .cap = IFACE.iface_cap,
                .idx_valid = IFACE.iface_idx_valid,
                .range_valid = IFACE.iface_range_valid,
                .idx_in_range = IFACE.iface_idx_in_range,
                .range_len = IFACE.iface_range_len,
                .split_range = IFACE.iface_split_range,
                .first_idx = IFACE.iface_first_idx,
                .last_idx = IFACE.iface_last_idx,
                .next_idx = IFACE.iface_next_idx,
                .nth_next_idx = IFACE.iface_nth_next_idx,
                .prev_idx = IFACE.iface_prev_idx,
                .nth_prev_idx = IFACE.iface_nth_prev_idx,
                .move = IFACE.iface_move,
                .move_range = IFACE.iface_move_range,
                .try_ensure_free_slots = IFACE.iface_try_ensure_free_slots,
                .shrink_cap_reserve_at_most = IFACE.iface_shrink_cap_reserve_at_most,
                .append_slots_assume_capacity = IFACE.iface_append_slots_assume_capacity,
                .insert_slots_assume_capacity = IFACE.iface_insert_slots_assume_capacity,
                .delete = IFACE.iface_delete,
                .delete_range = IFACE.iface_delete_range,
                .clear = IFACE.iface_clear,
                .free = IFACE.iface_free,
            };
        }

        //*** Derived funcs ***

        pub fn is_empty(self: LIST) bool {
            return len(self) <= 0;
        }
        pub fn try_move(self: LIST, old_idx: usize, new_idx: usize, alloc: ALLOC) ListError!void {
            if (!idx_valid(old_idx) or !idx_valid(self, self, new_idx)) {
                return ListError.invalid_index;
            }
            move(self, old_idx, new_idx, alloc);
        }
        pub fn try_move_range(self: LIST, range: Range, new_first_idx: usize, alloc: ALLOC) ListError!void {
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
        pub fn try_get(self: LIST, idx: usize, alloc: ALLOC) ListError!T {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_index;
            }
            return get(self, idx, alloc);
        }

        pub fn try_get_ptr(self: LIST, idx: usize, alloc: ALLOC) ListError!*T {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_index;
            }
            return get_ptr(self, idx, alloc);
        }

        pub fn try_set(self: LIST, idx: usize, val: T, alloc: ALLOC) ListError!void {
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
        pub fn get_last(self: LIST, alloc: ALLOC) T {
            const idx = last_idx(self);
            return get(self, idx, alloc);
        }
        pub fn try_get_last(self: LIST, alloc: ALLOC) ListError!T {
            const idx = try try_last_idx(self);
            return get(self, idx, alloc);
        }
        pub fn get_last_ptr(self: LIST, alloc: ALLOC) *T {
            const idx = last_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_last_ptr(self: LIST, alloc: ALLOC) ListError!*T {
            const idx = try try_last_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_last(self: LIST, val: T, alloc: ALLOC) void {
            const idx = last_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_last(self: LIST, val: T, alloc: ALLOC) ListError!void {
            const idx = try try_last_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn get_first(self: LIST, alloc: ALLOC) T {
            const idx = first_idx(self);
            return get(self, idx, alloc);
        }
        pub fn try_get_first(self: LIST, alloc: ALLOC) ListError!T {
            const idx = try try_first_idx(self);
            return get(self, idx, alloc);
        }
        pub fn get_first_ptr(self: LIST, alloc: ALLOC) *T {
            const idx = first_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_first_ptr(self: LIST, alloc: ALLOC) ListError!*T {
            const idx = try try_first_idx(self);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_first(self: LIST, val: T, alloc: ALLOC) void {
            const idx = first_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_first(self: LIST, val: T, alloc: ALLOC) ListError!void {
            const idx = try try_first_idx(self);
            return set(self, idx, val, alloc);
        }
        pub fn get_nth(self: LIST, n: usize, alloc: ALLOC) T {
            const idx = nth_idx(self, n);
            return get(self, idx, alloc);
        }
        pub fn try_get_nth(self: LIST, n: usize, alloc: ALLOC) ListError!T {
            const idx = try try_nth_idx(self, n);
            return get(self, idx, alloc);
        }
        pub fn get_nth_ptr(self: LIST, n: usize, alloc: ALLOC) *T {
            const idx = nth_idx(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_nth_ptr(self: LIST, n: usize, alloc: ALLOC) ListError!*T {
            const idx = try try_nth_idx(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_nth(self: LIST, n: usize, val: T, alloc: ALLOC) void {
            const idx = nth_idx(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_nth(self: LIST, n: usize, val: T, alloc: ALLOC) ListError!void {
            const idx = try try_nth_idx(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn get_nth_from_end(self: LIST, n: usize, alloc: ALLOC) T {
            const idx = nth_idx_from_end(self, n);
            return get(self, idx, alloc);
        }
        pub fn try_get_nth_from_end(self: LIST, n: usize, alloc: ALLOC) ListError!T {
            const idx = try try_nth_idx_from_end(self, n);
            return get(self, idx, alloc);
        }
        pub fn get_nth_ptr_from_end(self: LIST, n: usize, alloc: ALLOC) *T {
            const idx = nth_idx_from_end(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn try_get_nth_ptr_from_end(self: LIST, n: usize, alloc: ALLOC) ListError!*T {
            const idx = try try_nth_idx_from_end(self, n);
            return get_ptr(self, idx, alloc);
        }
        pub fn set_nth_from_end(self: LIST, n: usize, val: T, alloc: ALLOC) void {
            const idx = nth_idx_from_end(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn try_set_nth_from_end(self: LIST, n: usize, val: T, alloc: ALLOC) ListError!void {
            const idx = try try_nth_idx_from_end(self, n);
            return set(self, idx, val, alloc);
        }
        pub fn set_from(self: LIST, self_idx: usize, self_alloc: ALLOC, source: LIST, source_idx: usize, source_alloc: ALLOC) void {
            const val = get(source, source_idx, source_alloc);
            set(self, self_idx, val, self_alloc);
        }
        pub fn try_set_from(self: LIST, self_idx: usize, self_alloc: ALLOC, source: LIST, source_idx: usize, source_alloc: ALLOC) ListError!void {
            const val = try try_get(source, source_idx, source_alloc);
            return try_set(self, self_idx, val, self_alloc);
        }
        pub fn swap(self: LIST, idx_a: usize, idx_b: usize, alloc: ALLOC) void {
            const val_a = get(self, idx_a, alloc);
            const val_b = get(self, idx_b, alloc);
            set(self, idx_a, val_b, alloc);
            set(self, idx_b, val_a, alloc);
        }
        pub fn try_swap(self: LIST, idx_a: usize, idx_b: usize, alloc: ALLOC) ListError!void {
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
        pub fn overwrite(self: LIST, source_idx: usize, dest_idx: usize, alloc: ALLOC) void {
            const val = get(self, source_idx, alloc);
            set(self, dest_idx, val, alloc);
        }
        pub fn try_overwrite(self: LIST, source_idx: usize, dest_idx: usize, alloc: ALLOC) ListError!void {
            const val = try try_get(self, source_idx, alloc);
            set(self, dest_idx, val, alloc);
        }
        pub fn reverse(self: LIST, range: PartialRangeIter, alloc: ALLOC) void {
            const range_iter = range.to_iter(self);
            if (has_native_slice(self)) {
                const slice = native_slice(self, range_iter.range);
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

        pub fn rotate(self: LIST, range: PartialRangeIter, delta: isize, alloc: ALLOC) void {
            const riter = range.to_iter(self);
            const rlen = range_len(self, riter.range);
            const delta_mod = math.mod(isize, delta, @intCast(rlen)) catch unreachable;
            if (delta_mod == 0) return;
            const new_first_idx = nth_next_idx(self, riter.range.first_idx, @intCast(delta_mod));
            move_range(self, riter.range, new_first_idx, alloc);
        }

        pub fn fill(self: LIST, range: PartialRangeIter, val: T, alloc: ALLOC) usize {
            var iter = range.to_iter(self);
            if (has_native_slice(self)) {
                var slice = native_slice(self, iter.range);
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

        pub fn copy(source: RangeIter, dest: RangeIter) usize {
            var source_iter = source;
            var dest_iter = dest;
            if (has_native_slice(source.list)) {
                var src_slice = native_slice(source.list, source_iter.range);
                var dst_slice = native_slice(dest.list, dest_iter.range);
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
                        const val = get(source, src_idx, source_iter.alloc);
                        set(dest.list, dst_idx, val, dest_iter.alloc);
                        source_iter.commit_peeked(src_idx);
                        dest_iter.commit_peeked(dst_idx);
                    } else break;
                }
                return source_iter.count;
            }
        }

        pub fn copy_to(source: LIST, source_range: PartialRangeIter, dest: RangeIter) usize {
            return copy(source_range.to_iter(source), dest);
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

        pub fn is_sorted(self: LIST, range: PartialRangeIter, greater_than: *const CompareFunc, alloc: ALLOC) bool {
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

        pub fn is_sorted_implicit(self: LIST, range: PartialRangeIter, alloc: ALLOC) bool {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "is_sorted_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            return is_sorted(self, range, _implicit_gt, alloc);
        }

        pub fn insertion_sort(self: LIST, range: PartialRangeIter, greater_than: *const CompareFunc, alloc: ALLOC) void {
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

        pub fn insertion_sort_implicit(self: LIST, alloc: ALLOC) void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.insertion_sort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            insertion_sort(self, _implicit_gt, alloc);
        }

        pub fn quicksort(self: LIST, range: PartialRangeIter, self_alloc: Allocator, greater_than: *const CompareFunc, less_than: *const CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
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
        pub fn quicksort_implicit(self: LIST, range: PartialRangeIter, self_alloc: Allocator, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "quicksort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            quicksort(self, range, self_alloc, _implicit_gt, _implicit_lt, PARTITION_IDX, partition_stack);
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
            alloc: ALLOC = undefined,
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

            pub fn with_alloc(self: PartialRangeIter, alloc: ALLOC) PartialRangeIter {
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
                    .curr = 0,
                    .list = list,
                    .alloc = self.alloc,
                    .range = self.to_range(list),
                    .max_count = self.want_count,
                    .use_max = self.use_max,
                    .forward = self.forward,
                };
                if (self.forward) {
                    iter.curr = iter.range.first_idx;
                } else {
                    iter.curr = iter.range.last_idx;
                }
                return iter;
            }

            pub fn to_range(self: PartialRangeIter, list: LIST) Range {
                const rng = self.range;
                var out_rng = self.range;
                switch (self.overwrite_first) {
                    .none => {},
                    .first_idx => {
                        out_rng.first_idx = first_idx(list);
                    },
                    .last_idx => {
                        out_rng.first_idx = last_idx(list);
                    },
                    .nth_from_start => {
                        out_rng.first_idx = nth_idx(list, rng.first_idx);
                    },
                    .nth_from_end => {
                        out_rng.first_idx = nth_idx_from_end(list, rng.first_idx);
                    },
                    .nth_from_first => unreachable,
                    .nth_from_last => {
                        out_rng.first_idx = nth_prev_idx(list, rng.last_idx, rng.first_idx);
                    },
                }
                switch (self.overwrite_last) {
                    .none => {},
                    .first_idx => {
                        out_rng.last_idx = first_idx(list);
                    },
                    .last_idx => {
                        out_rng.last_idx = last_idx(list);
                    },
                    .nth_from_start => {
                        out_rng.last_idx = nth_idx(list, rng.last_idx);
                    },
                    .nth_from_end => {
                        out_rng.last_idx = nth_idx_from_end(list, rng.last_idx);
                    },
                    .nth_from_first => {
                        out_rng.last_idx = nth_next_idx(list, rng.first_idx, rng.last_idx);
                    },
                    .nth_from_last => unreachable,
                }
                return out_rng;
            }
        };

        pub const IterItem = struct {
            list: LIST,
            val: T,
            idx: usize,
        };

        pub const RangeIter = struct {
            list: LIST,
            alloc: ALLOC = undefined,
            range: Range,
            curr: usize,
            state: IterState = .UNCONSUMED,
            count: usize = 0,
            max_count: usize = std.math.maxInt(usize),
            use_max: bool = false,
            forward: bool = true,

            pub fn iter_len(self: *const RangeIter) usize {
                return @min(range_len(self.list, self.range), self.max_count);
            }

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

            pub fn next_item(self: *RangeIter) ?IterItem {
                if (self.next_index()) |idx| {
                    return IterItem{
                        .list = self.list,
                        .val = get(self.list, idx, self.alloc),
                        .idx = idx,
                    };
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

            pub fn prev_item(self: *RangeIter) ?IterItem {
                if (self.prev_index()) |idx| {
                    return IterItem{
                        .list = self.list,
                        .val = get(self.list, idx, self.alloc),
                        .idx = idx,
                    };
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

            pub fn with_alloc(self: RangeIter, alloc: ALLOC) RangeIter {
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

        pub fn range_iterator(self: LIST, range: PartialRangeIter) RangeIter {
            return range.to_iter(self);
        }

        pub fn for_each(
            self: LIST,
            range: PartialRangeIter,
            userdata: anytype,
            action: *const fn (item: IterItem, userdata: @TypeOf(userdata)) bool,
            comptime filter: FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            var iter = range.to_iter(self);
            var c: usize = 0;
            while (iter.next_item()) |item| {
                if (filter == .use_filter and !filter_func(item, userdata)) continue;
                c += 1;
                if (!action(item, userdata)) break;
            }
            return c;
        }

        pub fn filter_indexes(
            self: LIST,
            range: PartialRangeIter,
            userdata: anytype,
            filter_func: *const fn (item: IterItem, userdata: @TypeOf(userdata)) bool,
            comptime OUT_IDX: type,
            out_list: IList(OUT_IDX),
        ) usize {
            var iter = range.to_iter(self);
            var c: usize = 0;
            while (iter.next_item()) |item| {
                if (!filter_func(item, userdata)) continue;
                c += 1;
                _ = out_list.append(@intCast(item.idx));
            }
            return c;
        }

        pub fn transform_values(
            self: LIST,
            range: PartialRangeIter,
            userdata: anytype,
            comptime OUT_TYPE: type,
            transform_func: *const fn (item: IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            out_list: IList(OUT_TYPE),
            comptime filter: FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            var iter = range.to_iter(self);
            var c: usize = 0;
            while (iter.next_item()) |item| {
                if (filter == .use_filter and !filter_func(item, userdata)) continue;
                c += 1;
                const out_val = transform_func(item, userdata);
                _ = out_list.append(out_val);
            }
            return c;
        }

        pub fn accumulate_result(
            self: LIST,
            range: PartialRangeIter,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime filter: FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) @TypeOf(initial_accumulation) {
            var iter = range.to_iter(self);
            var accum = initial_accumulation;
            while (iter.next_item()) |item| {
                if (filter == .use_filter and !filter_func(item, userdata)) continue;
                accum = accumulate_func(item, accum, userdata);
            }
            return accum;
        }
        pub fn ensure_free_slots(self: LIST, count: usize, alloc: ALLOC) void {
            const err = try_ensure_free_slots(self, count, alloc);
            Assert.assert_with_reason(Utils.not_error(err), @src(), "failed to grow list, current: len = {d}, cap = {d}, need {d} more slots", .{ len(self), cap(self), count });
        }
        pub fn append_slots(self: LIST, count: usize, alloc: ALLOC) Range {
            ensure_free_slots(self, count, alloc);
            return append_slots_assume_capacity(self, count, alloc);
        }
        pub fn try_append_slots(self: LIST, count: usize, alloc: ALLOC) ListError!Range {
            try try_ensure_free_slots(self, count, alloc);
            return append_slots_assume_capacity(self, count, alloc);
        }
        pub fn append_zig_slice(self: LIST, slice: []const T, alloc: ALLOC) Range {
            ensure_free_slots(self, slice.len, alloc);
            return _append_zig_slice(self, slice, alloc);
        }
        pub fn try_append_zig_slice(self: LIST, slice: []const T, alloc: ALLOC) ListError!Range {
            try try_ensure_free_slots(self, slice.len, alloc);
            return _append_zig_slice(self, slice, alloc);
        }
        fn _append_zig_slice(self: LIST, slice: []const T, alloc: ALLOC) Range {
            if (slice.len == 0) return Range.single_idx(always_invalid_idx(self));
            const append_range = append_slots_assume_capacity(self, slice.len, alloc);
            if (has_native_slice(self)) {
                const slice_dst = native_slice(self, append_range);
                @memcpy(slice_dst, slice);
            } else {
                var ii: usize = append_range.first_idx;
                var i: usize = 0;
                while (true) {
                    set(self, ii, slice[i], alloc);
                    if (ii == append_range.last_idx) break;
                    ii = next_idx(self, ii);
                    i += 1;
                }
            }
            return append_range;
        }
        pub fn append(self: LIST, val: T, alloc: ALLOC) usize {
            ensure_free_slots(self, 1, alloc);
            const append_range = append_slots_assume_capacity(self, 1, alloc);
            set(self, append_range.first_idx, val, alloc);
            return append_range.first_idx;
        }
        pub fn append_assume_capacity(self: LIST, val: T, alloc: ALLOC) usize {
            const append_range = append_slots_assume_capacity(self, 1, alloc);
            set(self, append_range.first_idx, val, alloc);
            return append_range.first_idx;
        }
        pub fn try_append(self: LIST, val: T, alloc: ALLOC) ListError!usize {
            try try_ensure_free_slots(self, 1, alloc);
            const append_range = append_slots_assume_capacity(self, 1, alloc);
            set(self, append_range.first_idx, val, alloc);
            return append_range.first_idx;
        }
        pub fn append_many(self: LIST, self_alloc: Allocator, list_range: RangeIter) Range {
            const rlen = list_range.iter_len();
            ensure_free_slots(self, rlen, self_alloc);
            const append_range = append_slots_assume_capacity(self, rlen, self_alloc);
            _ = copy(list_range, RangeIter.use_range(self, append_range).with_alloc(self_alloc));
            return append_range;
        }
        pub fn try_append_many(self: LIST, self_alloc: Allocator, list_range: RangeIter) ListError!Range {
            const rlen = list_range.iter_len();
            try try_ensure_free_slots(self, rlen, self_alloc);
            const append_range = append_slots_assume_capacity(self, rlen, self_alloc);
            _ = copy(list_range, RangeIter.use_range(self, append_range).with_alloc(self_alloc));
            return append_range;
        }
        pub fn insert_slots(self: LIST, idx: usize, count: usize, alloc: ALLOC) Range {
            ensure_free_slots(self, count, alloc);
            return insert_slots_assume_capacity(self, idx, count, alloc);
        }
        pub fn try_insert_slots(self: LIST, idx: usize, count: usize, alloc: ALLOC) ListError!Range {
            try try_ensure_free_slots(self, count, alloc);
            return insert_slots_assume_capacity(self, idx, count, alloc);
        }
        pub fn insert_zig_slice(self: LIST, idx: usize, slice: []const T, alloc: ALLOC) Range {
            ensure_free_slots(self, slice.len, alloc);
            return _insert_zig_slice(self, idx, slice, alloc);
        }
        pub fn try_insert_zig_slice(self: LIST, idx: usize, slice: []const T, alloc: ALLOC) ListError!Range {
            try try_ensure_free_slots(self, slice.len, alloc);
            return _insert_zig_slice(self, idx, slice, alloc);
        }
        fn _insert_zig_slice(self: LIST, idx: usize, slice: []const T, alloc: ALLOC) Range {
            if (slice.len == 0) return Range.single_idx(always_invalid_idx(self));
            const insert_range = insert_slots_assume_capacity(self, idx, slice.len, alloc);
            if (has_native_slice(self)) {
                const slice_dst = native_slice(self, insert_range);
                @memcpy(slice_dst, slice);
            } else {
                var ii: usize = insert_range.first_idx;
                var i: usize = 0;
                while (true) {
                    set(self, ii, slice[i], alloc);
                    if (ii == insert_range.last_idx) break;
                    ii = next_idx(self, ii);
                    i += 1;
                }
            }
            return insert_range;
        }
        pub fn insert(self: LIST, idx: usize, val: T, alloc: ALLOC) usize {
            ensure_free_slots(self, 1, alloc);
            const insert_range = insert_slots_assume_capacity(self, idx, 1, alloc);
            set(self, insert_range.first_idx, val, alloc);
            return insert_range.first_idx;
        }
        pub fn try_insert(self: LIST, idx: usize, val: T, alloc: ALLOC) ListError!Range {
            try try_ensure_free_slots(self, 1, alloc);
            const insert_range = insert_slots_assume_capacity(self, idx, 1, alloc);
            set(self, insert_range.first_idx, val, alloc);
            return insert_range.first_idx;
        }
        pub fn insert_many(self: LIST, idx: usize, self_alloc: Allocator, list_range: RangeIter) Range {
            const rlen = list_range.iter_len();
            ensure_free_slots(self, rlen, self_alloc);
            const insert_range = insert_slots_assume_capacity(self, idx, rlen, self_alloc);
            _ = copy(list_range, RangeIter.use_range(self, insert_range).with_alloc(self_alloc));
            return insert_range;
        }
        pub fn try_insert_many(self: LIST, idx: usize, self_alloc: Allocator, list_range: RangeIter) ListError!Range {
            const rlen = list_range.iter_len();
            try try_ensure_free_slots(self, rlen, self_alloc);
            const insert_range = insert_slots_assume_capacity(self, idx, rlen, self_alloc);
            _ = copy(list_range, RangeIter.use_range(self, insert_range).with_alloc(self_alloc));
            return insert_range;
        }
        pub fn try_delete_range(self: LIST, range: Range, alloc: ALLOC) ListError!void {
            if (!range_valid(self, range)) {
                return ListError.invalid_range;
            }
            delete_range(self, range, alloc);
        }
        pub fn delete_many(self: LIST, range: PartialRangeIter) void {
            const real_range = range.to_range(self);
            delete_range(self, real_range, range.alloc);
        }
        pub fn try_delete_many(self: LIST, range: PartialRangeIter) ListError!void {
            const real_range = range.to_range(self);
            return try try_delete_range(self, real_range, range.alloc);
        }
        pub fn try_delete(self: LIST, idx: usize, alloc: ALLOC) ListError!void {
            if (!idx_valid(self, idx)) {
                return ListError.invalid_range;
            }
            return delete(self, idx, alloc);
        }
        pub fn swap_delete(self: LIST, idx: usize, alloc: ALLOC) void {
            const last = last_idx(self);
            overwrite(self, last, idx, alloc);
            trim_len(self, 1);
        }
        pub fn try_swap_delete(self: LIST, idx: usize, alloc: ALLOC) ListError!void {
            if (len(self) == 0) return ListError.list_is_empty;
            const last = try try_last_idx(self);
            overwrite(self, last, idx, alloc);
            trim_len(self, 1);
        }
        pub fn swap_delete_many(self: LIST, range: PartialRangeIter) void {
            var del_area = range.to_iter(self);
            const del_len = del_area.iter_len();
            const swap_area = RangeIter.last_n_items(self, del_len).with_alloc(del_area.alloc);
            _ = copy(swap_area, del_area);
            delete_range(self, swap_area.range, swap_area.alloc);
        }
        pub fn try_swap_delete_many(self: LIST, range: PartialRangeIter) ListError!void {
            var del_area = range.to_iter(self);
            const del_len = del_area.iter_len();
            const swap_area = RangeIter.last_n_items(self, del_len).with_alloc(del_area.alloc);
            if (!range_valid(self, del_area.range) or !range_valid(self, swap_area.range)) return ListError.invalid_range;
            _ = copy(swap_area, del_area);
            return try_delete_range(self, swap_area.range, swap_area.alloc);
        }

        pub fn remove_range(self: LIST, self_range: PartialRangeIter, dest: LIST, dest_alloc: ALLOC) Range {
            const self_iter = self_range.to_iter(self);
            const rem_len = self_iter.iter_len();
            const dest_range = append_slots(dest, rem_len, dest_alloc);
            const dest_iter = RangeIter.use_range(dest, dest_range).with_alloc(dest_alloc);
            _ = copy(self_iter, dest_iter);
            delete_range(self, self_iter.range, self_iter.alloc);
            return dest_range;
        }
        pub fn try_remove_range(self: LIST, self_range: PartialRangeIter, dest: LIST, dest_alloc: ALLOC) ListError!Range {
            const self_iter = self_range.to_iter(self);
            if (!range_valid(self, self_iter.range)) return ListError.invalid_range;
            const rem_len = self_iter.iter_len();
            const dest_range = try try_append_slots(dest, rem_len, dest_alloc);
            const dest_iter = RangeIter.use_range(dest, dest_range).with_alloc(dest_alloc);
            _ = copy(self_iter, dest_iter);
            delete_range(self, self_iter.range, self_iter.alloc);
            return dest_range;
        }

        pub fn remove(self: LIST, idx: usize, alloc: ALLOC) T {
            const val = get(self, idx, alloc);
            delete_range(self, .single_idx(idx), alloc);
            return val;
        }
        pub fn try_remove(self: LIST, idx: usize, alloc: ALLOC) ListError!T {
            const val = try try_get(self, idx, alloc);
            delete_range(self, .single_idx(idx), alloc);
            return val;
        }
        pub fn swap_remove(self: LIST, idx: usize, alloc: ALLOC) T {
            const val = get(self, idx, alloc);
            swap_delete(self, idx, alloc);
            return val;
        }
        pub fn try_swap_remove(self: LIST, idx: usize, alloc: ALLOC) ListError!T {
            const val = try try_get(self, idx, alloc);
            try try_swap_delete(self, idx, alloc);
            return val;
        }

        pub fn pop(self: LIST, alloc: ALLOC) T {
            const last_idx_ = last_idx(self);
            const val = get(self, last_idx_, alloc);
            trim_len(self, 1, alloc);
            return val;
        }
        pub fn try_pop(self: LIST, alloc: ALLOC) ListError!T {
            const last_idx_ = try try_last_idx(self);
            const val = get(self, last_idx_, alloc);
            trim_len(self, 1, alloc);
            return val;
        }

        pub fn pop_many(self: LIST, count: usize, alloc: ALLOC, dest: LIST, dest_alloc: ALLOC) Range {
            const last_idx_ = last_idx(self);
            const first_pop_idx = nth_idx_from_end(self, count - 1);
            return remove_range(self, PartialRangeIter.new_range(first_pop_idx, last_idx_).with_alloc(alloc), dest, dest_alloc);
        }

        pub fn try_pop_many(self: LIST, count: usize, alloc: ALLOC, dest: LIST, dest_alloc: ALLOC) ListError!Range {
            const last_idx_ = try try_last_idx(self);
            const first_pop_idx = try try_nth_idx_from_end(self, count - 1);
            return try_remove_range(self, PartialRangeIter.new_range(first_pop_idx, last_idx_).with_alloc(alloc), dest, dest_alloc);
        }

        fn _sorted_binary_locate(
            self: LIST,
            alloc: ALLOC,
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
                idx = split_range(self, .new_range(lo, hi));
                val = get(self, idx, alloc);
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
                    hi = prev_idx(self, idx);
                } else {
                    if (idx == hi) {
                        result.exit_hi = idx == orig_hi;
                        if (!result.exit_hi) {
                            idx = next_idx(self, hi);
                        }
                        result.idx = idx;
                        return result;
                    }
                    lo = next_idx(self, idx);
                }
            }
        }
        fn _sorted_linear_locate(
            self: LIST,
            alloc: ALLOC,
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
                val = get(self, idx, alloc);
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
                    idx = next_idx(self, idx);
                }
            }
        }

        fn _sorted_binary_search(
            self: LIST,
            alloc: ALLOC,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResult {
            const lo = first_idx(self);
            const hi = last_idx(self);
            const ok = len(self) > 0 and idx_valid(self, lo) and idx_valid(self, hi);
            if (!ok) {
                return SearchResult{};
            }
            const loc_result = _sorted_binary_locate(self, alloc, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResult{
                .found = loc_result.found,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_linear_search(
            self: LIST,
            alloc: ALLOC,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) SearchResult {
            const lo = first_idx(self);
            const hi = last_idx(self);
            const ok = len(self) > 0 and idx_valid(self, lo) and idx_valid(self, hi);
            if (!ok) {
                return SearchResult{};
            }
            const loc_result = _sorted_linear_locate(self, alloc, lo, hi, locate_val, equal_func, greater_than_func);
            return SearchResult{
                .found = loc_result.found,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_binary_insert_index(
            self: LIST,
            alloc: ALLOC,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResult {
            const lo = first_idx(self);
            const hi = last_idx(self);
            const ok = len(self) > 0 and idx_valid(self, lo) and idx_valid(self, hi);
            if (!ok) {
                return InsertIndexResult{};
            }
            const loc_result = _sorted_binary_locate(self, alloc, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResult{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_linear_insert_index(
            self: LIST,
            alloc: ALLOC,
            locate_val: anytype,
            equal_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
            greater_than_func: *const fn (this_val: T, find_val: @TypeOf(locate_val)) bool,
        ) InsertIndexResult {
            const lo = first_idx(self);
            const hi = last_idx(self);
            const ok = len(self) > 0 and idx_valid(self, lo) and idx_valid(self, hi);
            if (!ok) {
                return InsertIndexResult{};
            }
            const loc_result = _sorted_linear_locate(self, alloc, lo, hi, locate_val, equal_func, greater_than_func);
            return InsertIndexResult{
                .append = !loc_result.found and loc_result.exit_hi,
                .idx = loc_result.idx,
            };
        }

        fn _sorted_binary_insert(
            self: LIST,
            alloc: ALLOC,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_binary_insert_index(self, alloc, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = append(self, val, alloc);
            } else {
                idx = insert(self, ins_result.idx, val, alloc);
            }
            return idx;
        }

        fn _sorted_linear_insert(
            self: LIST,
            alloc: ALLOC,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            const ins_result = _sorted_linear_insert_index(self, alloc, val, equal_func, greater_than_func);
            var idx: usize = undefined;
            if (ins_result.append) {
                idx = append(self, val, alloc);
            } else {
                idx = insert(self, ins_result.idx, val, alloc);
            }
            return idx;
        }

        pub fn sorted_insert(
            self: LIST,
            alloc: ALLOC,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_insert(self, alloc, val, equal_func, greater_than_func);
            } else {
                return _sorted_binary_insert(self, alloc, val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_implicit(self: LIST, val: T, alloc: ALLOC) usize {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_insert(self, alloc, val, _implicit_eq, _implicit_gt);
            } else {
                return _sorted_binary_insert(self, alloc, val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_insert_index(
            self: LIST,
            alloc: ALLOC,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResult {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_insert_index(self, alloc, val, equal_func, greater_than_func);
            } else {
                return _sorted_binary_insert_index(self, alloc, val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_insert_index_implicit(self: LIST, val: T, alloc: ALLOC) InsertIndexResult {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_insert_index(self, alloc, val, _implicit_eq, _implicit_gt);
            } else {
                return _sorted_binary_insert_index(self, alloc, val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_search(
            self: LIST,
            alloc: ALLOC,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResult {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_search(self, alloc, val, equal_func, greater_than_func);
            } else {
                return _sorted_binary_search(self, alloc, val, equal_func, greater_than_func);
            }
        }

        pub fn sorted_search_implicit(self: LIST, val: T, alloc: ALLOC) SearchResult {
            if (prefer_linear_ops(self)) {
                return _sorted_linear_search(self, alloc, val, _implicit_eq, _implicit_gt);
            } else {
                return _sorted_binary_search(self, alloc, val, _implicit_eq, _implicit_gt);
            }
        }

        pub fn sorted_set_and_resort(self: LIST, idx: usize, val: T, alloc: ALLOC, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            var new_idx = idx;
            var adj_idx = next_idx(self, new_idx);
            var adj_val: T = undefined;
            while (idx_valid(self, adj_idx) and next_is_less: {
                adj_val = get(self, adj_idx, alloc);
                break :next_is_less greater_than_func(val, adj_val);
            }) {
                set(self, new_idx, adj_val, alloc);
                new_idx = adj_idx;
                adj_idx = next_idx(self, adj_idx);
            }
            adj_idx = prev_idx(self, new_idx);
            while (idx_valid(self, adj_idx) and prev_is_greater: {
                adj_val = get(self, adj_idx, alloc);
                break :prev_is_greater greater_than_func(adj_val, val);
            }) {
                set(self, new_idx, adj_val, alloc);
                new_idx = adj_idx;
                adj_idx = prev_idx(self, adj_idx);
            }
            set(self, new_idx, val, alloc);
            return new_idx;
        }
        pub fn sorted_set_and_resort_implicit(self: LIST, idx: usize, val: T, alloc: ALLOC) usize {
            return sorted_set_and_resort(self, idx, val, alloc, _implicit_gt);
        }

        pub fn search(self: LIST, find_val: anytype, alloc: ALLOC, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) SearchResult {
            var val: T = undefined;
            var idx: usize = first_idx(self);
            var ok = idx_valid(self, idx);
            var result = SearchResult{};
            while (ok) {
                val = get(self, idx, alloc);
                if (equal_func(val, find_val)) {
                    result.found = true;
                    result.idx = idx;
                    break;
                }
                idx = next_idx(self, idx);
                ok = idx_valid(self, idx);
            }
            return result;
        }

        pub fn search_implicit(self: LIST, val: T, alloc: ALLOC) SearchResult {
            return search(self, val, alloc, _implicit_eq);
        }

        pub fn add_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) + val;
        }
        pub fn try_add_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) + val;
        }
        pub fn add_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v + val, alloc);
        }
        pub fn try_add_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v + val, alloc);
        }

        pub fn subtract_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) - val;
        }
        pub fn try_subtract_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) - val;
        }
        pub fn subtract_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v - val, alloc);
        }
        pub fn try_subtract_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v - val, alloc);
        }

        pub fn multiply_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) * val;
        }
        pub fn try_multiply_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) * val;
        }
        pub fn multiply_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v * val, alloc);
        }
        pub fn try_multiply_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v * val, alloc);
        }

        pub fn divide_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) / val;
        }
        pub fn try_divide_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) / val;
        }
        pub fn divide_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v / val, alloc);
        }
        pub fn try_divide_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v / val, alloc);
        }

        pub fn modulo_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return @mod(get(self, idx, alloc), val);
        }
        pub fn try_modulo_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return @mod((try try_get(self, idx, alloc)), val);
        }
        pub fn modulo_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, @mod(v, val), alloc);
        }
        pub fn try_modulo_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, @mod(v, val), alloc);
        }

        pub fn mod_rem_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) struct { mod: T, rem: T } {
            const v = get(self, idx, alloc);
            const mod = @mod(v, val);
            const rem = v - mod;
            return struct { mod: T, rem: T }{ .mod = mod, .rem = rem };
        }
        pub fn try_mod_rem_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!struct { mod: T, rem: T } {
            const v = try try_get(self, idx, alloc);
            const mod = @mod(v, val);
            const rem = v - mod;
            return struct { mod: T, rem: T }{ .mod = mod, .rem = rem };
        }

        pub fn bit_and_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) & val;
        }
        pub fn try_bit_and_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) & val;
        }
        pub fn bit_and_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v & val, alloc);
        }
        pub fn try_bit_and_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v & val, alloc);
        }

        pub fn bit_or_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) | val;
        }
        pub fn try_bit_or_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) | val;
        }
        pub fn bit_or_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v | val, alloc);
        }
        pub fn try_bit_or_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v | val, alloc);
        }

        pub fn bit_xor_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) ^ val;
        }
        pub fn try_bit_xor_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) ^ val;
        }
        pub fn bit_xor_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v ^ val, alloc);
        }
        pub fn try_bit_xor_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v ^ val, alloc);
        }

        pub fn bit_invert_get(self: LIST, idx: usize, alloc: ALLOC) T {
            return ~get(self, idx, alloc);
        }
        pub fn try_bit_invert_get(self: LIST, idx: usize, alloc: ALLOC) ListError!T {
            return ~(try try_get(self, idx, alloc));
        }
        pub fn bit_invert_set(self: LIST, idx: usize, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, ~v, alloc);
        }
        pub fn try_bit_invert_set(self: LIST, idx: usize, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, ~v, alloc);
        }

        pub fn bool_and_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) T {
            return get(self, idx, alloc) and val;
        }
        pub fn try_bool_and_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) and val;
        }
        pub fn bool_and_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v and val, alloc);
        }
        pub fn try_bool_and_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v and val, alloc);
        }

        pub fn bool_or_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) T {
            return get(self, idx, alloc) or val;
        }
        pub fn try_bool_or_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) or val;
        }
        pub fn bool_or_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v or val, alloc);
        }
        pub fn try_bool_or_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v or val, alloc);
        }

        pub fn bool_xor_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) T {
            return get(self, idx, alloc) != val;
        }
        pub fn try_bool_xor_get(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) != val;
        }
        pub fn bool_xor_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v != val, alloc);
        }
        pub fn try_bool_xor_set(self: LIST, idx: usize, val: bool, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v != val, alloc);
        }

        pub fn bool_invert_get(self: LIST, idx: usize, alloc: ALLOC) T {
            return !get(self, idx, alloc);
        }
        pub fn try_bool_invert_get(self: LIST, idx: usize, alloc: ALLOC) ListError!T {
            return !(try try_get(self, idx, alloc));
        }
        pub fn bool_invert_set(self: LIST, idx: usize, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, !v, alloc);
        }
        pub fn try_bool_invert_set(self: LIST, idx: usize, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, !v, alloc);
        }

        pub fn bit_l_shift_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) << val;
        }
        pub fn try_bit_l_shift_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) << val;
        }
        pub fn bit_l_shift_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v << val, alloc);
        }
        pub fn try_bit_l_shift_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v << val, alloc);
        }

        pub fn bit_r_shift_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) T {
            return get(self, idx, alloc) >> val;
        }
        pub fn try_bit_r_shift_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!T {
            return (try try_get(self, idx, alloc)) >> val;
        }
        pub fn bit_r_shift_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v = get(self, idx, alloc);
            set(self, idx, v >> val, alloc);
        }
        pub fn try_bit_r_shift_set(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v = try try_get(self, idx, alloc);
            set(self, idx, v >> val, alloc);
        }

        pub fn less_than_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) < val;
        }
        pub fn try_less_than_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) < val;
        }

        pub fn less_than_equal_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) <= val;
        }
        pub fn try_less_than_equal_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) <= val;
        }

        pub fn greater_than_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) > val;
        }
        pub fn try_greater_than_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) > val;
        }

        pub fn greater_than_equal_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) >= val;
        }
        pub fn try_greater_than_equal_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) >= val;
        }

        pub fn equals_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) == val;
        }
        pub fn try_equals_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) == val;
        }

        pub fn not_equals_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            return get(self, idx, alloc) != val;
        }
        pub fn try_not_equals_get(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            return (try try_get(self, idx, alloc)) != val;
        }

        pub const Item = struct {
            val: T,
            idx: usize,
        };

        pub fn get_min_in_range(self: LIST, range: PartialRangeIter) Item {
            var iter = range.to_iter(self);
            var item: Item = undefined;
            if (iter.next_item()) |v| {
                item.val = v.val;
                item.idx = v.idx;
            }
            while (iter.next_item()) |v| {
                if (v.val < item.val) {
                    item.val = v.val;
                    item.idx = v.idx;
                }
            }
            return item;
        }

        pub fn try_get_min_in_range(self: LIST, range: PartialRangeIter) ListError!Item {
            var iter = range.to_iter(self);
            if (!range_valid(self, iter.range)) {
                return ListError.invalid_range;
            }
            var item: Item = undefined;
            if (iter.next_item()) |v| {
                item.val = v.val;
                item.idx = v.idx;
            }
            while (iter.next_item()) |v| {
                if (v.val < item.val) {
                    item.val = v.val;
                    item.idx = v.idx;
                }
            }
            return item;
        }

        pub fn get_max_in_range(self: LIST, range: PartialRangeIter) Item {
            var iter = range.to_iter(self);
            var item: Item = undefined;
            if (iter.next_item()) |v| {
                item.val = v.val;
                item.idx = v.idx;
            }
            while (iter.next_item()) |v| {
                if (v.val > item.val) {
                    item.val = v.val;
                    item.idx = v.idx;
                }
            }
            return item;
        }

        pub fn try_get_max_in_range(self: LIST, range: PartialRangeIter) ListError!Item {
            var iter = range.to_iter(self);
            if (!range_valid(self, iter.range)) {
                return ListError.invalid_range;
            }
            var item: Item = undefined;
            if (iter.next_item()) |v| {
                item.val = v.val;
                item.idx = v.idx;
            }
            while (iter.next_item()) |v| {
                if (v.val > item.val) {
                    item.val = v.val;
                    item.idx = v.idx;
                }
            }
            return item;
        }

        pub fn get_clamped(self: LIST, idx: usize, min: T, max: T, alloc: ALLOC) T {
            const v = get(self, idx, alloc);
            return @min(max, @max(min, v));
        }
        pub fn try_get_clamped(self: LIST, idx: usize, min: T, max: T, alloc: ALLOC) ListError!T {
            const v = try try_get(self, idx, alloc);
            return @min(max, @max(min, v));
        }
        pub fn set_clamped(self: LIST, idx: usize, val: T, min: T, max: T, alloc: ALLOC) void {
            const v = @min(max, @max(min, val));
            set(self, idx, v, alloc);
        }
        pub fn try_set_clamped(self: LIST, idx: usize, val: T, min: T, max: T, alloc: ALLOC) ListError!void {
            const v = @min(max, @max(min, val));
            return try_set(self, idx, v, alloc);
        }

        pub fn set_report_change(self: LIST, idx: usize, val: T, alloc: ALLOC) bool {
            const old = get(self, idx, alloc);
            set(self, idx, val, alloc);
            return val != old;
        }

        pub fn try_set_report_change(self: LIST, idx: usize, val: T, alloc: ALLOC) ListError!bool {
            const old = try try_get(self, idx, alloc);
            set(self, idx, val, alloc);
            return val != old;
        }

        pub fn get_unsafe_cast(self: LIST, idx: usize, comptime TT: type, alloc: ALLOC) TT {
            const v = get(self, idx, alloc);
            const vv: TT = @as(*TT, @ptrCast(@alignCast(&v))).*;
            return vv;
        }
        pub fn try_get_unsafe_cast(self: LIST, idx: usize, comptime TT: type, alloc: ALLOC) ListError!TT {
            const v = try try_get(self, idx, alloc);
            const vv: TT = @as(*TT, @ptrCast(@alignCast(&v))).*;
            return vv;
        }

        pub fn get_unsafe_ptr_cast(self: LIST, idx: usize, comptime TT: type, alloc: ALLOC) *TT {
            const v: *T = get_ptr(self, idx, alloc);
            const vv: *TT = @as(*TT, @ptrCast(@alignCast(&v)));
            return vv;
        }
        pub fn try_get_unsafe_ptr_cast(self: LIST, idx: usize, comptime TT: type, alloc: ALLOC) ListError!*TT {
            const v: *T = try try_get_ptr(self, idx, alloc);
            const vv: *TT = @as(*TT, @ptrCast(@alignCast(&v)));
            return vv;
        }

        pub fn set_unsafe_cast(self: LIST, idx: usize, val: anytype, alloc: ALLOC) void {
            const v: *T = @ptrCast(@alignCast(&val));
            set(self, idx, v.*, alloc);
        }
        pub fn try_set_unsafe_cast(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!void {
            const v: *T = @ptrCast(@alignCast(&val));
            return try_set(self, idx, v.*, alloc);
        }

        pub fn set_unsafe_cast_report_change(self: LIST, idx: usize, val: anytype, alloc: ALLOC) bool {
            const old = get(self, idx, alloc);
            const v: *T = @ptrCast(@alignCast(&val));
            set(self, idx, v.*, alloc);
            return v.* != old;
        }

        pub fn try_set_unsafe_cast_report_change(self: LIST, idx: usize, val: anytype, alloc: ALLOC) ListError!bool {
            const old = get(self, idx, alloc);
            const v: *T = @ptrCast(@alignCast(&val));
            try try_set(self, idx, v.*, alloc);
            return v.* != old;
        }
    };
}

pub const FilterMode = enum(u8) {
    no_filter,
    use_filter,
};

pub const Range = struct {
    first_idx: usize = 0,
    last_idx: usize = 0,

    /// Assumes all consecutive increasing indexes between `first_idx` and `last_idx`
    /// represent consecutive items in their proper order
    pub fn consecutive_len(self: Range) usize {
        return (self.last_idx - self.first_idx) + 1;
    }

    /// Assumes all consecutive increasing indexes between `first_idx` and `last_idx`
    /// represent consecutive items in their proper order
    pub fn consecutive_split(self: Range) usize {
        return ((self.last_idx - self.first_idx) >> 1) + self.first_idx;
    }

    pub fn from_idx_count(idx: usize, count: usize) Range {
        return Range{
            .first_idx = idx,
            .last_idx = idx + count - 1,
        };
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

pub const LocateResult = struct {
    idx: usize = 0,
    found: bool = false,
    exit_hi: bool = false,
    exit_lo: bool = false,
};
pub const SearchResult = struct {
    idx: usize = 0,
    found: bool = false,
};
pub const InsertIndexResult = struct {
    idx: usize = 0,
    append: bool = false,
};

pub const CountResult = struct {
    count: usize = 0,
    count_matches_expected: bool = false,
    next_idx: usize = 0,
};
pub const CopyResult = struct {
    count: usize = 0,
    source_range: Range = .{},
    dest_range: Range = .{},
    count_matches_expected: bool = false,
    full_source_copied: bool = false,
    full_dest_copied: bool = false,
};

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
