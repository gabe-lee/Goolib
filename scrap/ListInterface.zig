// //! //TODO Documentation
// //! #### License: Zlib

// // zlib license
// //
// // Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
// //
// // This software is provided 'as-is', without any express or implied
// // warranty. In no event will the authors be held liable for any damages
// // arising from the use of this software.
// //
// // Permission is granted to anyone to use this software for any purpose,
// // including commercial applications, and to alter it and redistribute it
// // freely, subject to the following restrictions:
// //
// // 1. The origin of this software must not be misrepresented; you must not
// //    claim that you wrote the original software. If you use this software
// //    in a product, an acknowledgment in the product documentation would be
// //    appreciated but is not required.
// // 2. Altered source versions must be plainly marked as such, and must not be
// //    misrepresented as being the original software.
// // 3. This notice may not be removed or altered from any source distribution.

// const build = @import("builtin");
// const std = @import("std");
// const builtin = std.builtin;
// const mem = std.mem;
// const math = std.math;
// const crypto = std.crypto;
// const Allocator = std.mem.Allocator;
// const ArrayListUnmanaged = std.ArrayListUnmanaged;
// const ArrayList = std.ArrayListUnmanaged;
// const Type = std.builtin.Type;

// const Root = @import("./_root.zig");
// const Utils = Root.Utils;
// const Types = Root.Types;
// const is_err = Types.is_error;
// const no_err = Types.not_error;
// const Assert = Root.Assert;
// const assert_with_reason = Assert.assert_with_reason;
// const FlexSlice = Root.FlexSlice.FlexSlice;
// const Mutability = Root.CommonTypes.Mutability;
// const Quicksort = Root.Quicksort;
// const Pivot = Quicksort.Pivot;
// const InsertionSort = Root.InsertionSort;
// const insertion_sort = InsertionSort.insertion_sort;
// const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
// const GrowthModel = Root.CommonTypes.GrowthModel;
// const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
// const DummyAllocator = Root.DummyAllocator;
// const BinarySearch = Root.BinarySearch;
// const SourceLocation = builtin.SourceLocation;

// pub const DeleteResult = struct {
//     success: bool = true,
//     did_shift_items_down: bool,
//     first_idx_shifted_down: usize,
// };

// pub const TraverseResult = struct {
//     success: bool = true,
//     traverse_count: usize,
//     new_idx: usize,
// };

// pub const Result = struct {
//     success: bool = true,

//     pub const FAILURE = Result{ .success = false };
// };

// pub const NULL_IDX: usize = math.maxInt(usize);

// pub fn GenericList(comptime T: type) type {
//     return struct {
//         implementor: *anyopaque,
//         vtable: *const VTable,

//         const Self = @This();
//         pub const VTable = struct {
//             /// Return the first logical item in the list, or `null` if none exists,
//             get_first_item: *const fn (implementor: *const anyopaque) ?*T,
//             /// Return the last logical item in the list, or `null` if none exists,
//             get_last_item: *const fn (implementor: *const anyopaque) ?*T,
//             /// Return the total number of items in the list
//             get_list_len: *const fn (implementor: *const anyopaque) usize,
//             /// Ensure list implementor has space to add at least `count` more items,
//             /// reallocating if necessary.
//             ///
//             /// Returns an `Allocator.Error` if reallocation was required but failed
//             ensure_additional_capacity: *const fn (implementor: *anyopaque, count: usize, alloc: Allocator) Allocator.Error!void,
//             /// Shrink the capacity of the list implementor while keeping at least `count` spaces for new items,
//             /// remapping/reallocating if neccessary.
//             ///
//             /// The *true* resulting extra capacity for items should be considered equal to
//             /// `@min(old_extra_capacity, keep_extra_capacity)`
//             shrink_capacity_but_keep_n_additional: *const fn (implementor: *anyopaque, keep_extra_capacity: usize, alloc: Allocator) void,
//             /// Insert new items before the item provided, shifting this and all items after it rightward
//             ///
//             /// This function should assume enough capacity exists for new items
//             insert_new_items_before_this_one: *const fn (implementor: *anyopaque, item: *const T, count: usize) InsertResult,
//             /// Insert new items at end/rightmost end of list
//             /// and returning the index of the first (leftmost) new item added
//             ///
//             /// This function should assume enough capacity exists for new items
//             append_new_items: *const fn (implementor: *anyopaque, start_idx: usize, count: usize) AppendResult,
//             /// Delete a range of items from `first_idx` to `last_idx` inclusive, shifting all items after `last_idx` leftward
//             ///
//             /// Returns the index of the first item shifted down, or `null` if no items needed to be shifted down
//             ///
//             /// This function should assume enough capacity exists for new items, and that the index is valid.
//             delete_items_at_idx: *const fn (implementor: *anyopaque, first_idx: usize, last_idx: usize) DeleteResult,
//             /// Returns the index `count` places to the right of the provided index
//             get_idx_n_places_to_the_right: *const fn (implementor: *anyopaque, start_idx: usize, count: usize) TraverseResult,
//             /// Returns the index `count` places to the left of the provided index,
//             /// or an `IndexTraverseError` if something prevented the operation
//             get_idx_n_places_to_the_left: *const fn (implementor: *anyopaque, start_idx: usize, count: usize) TraverseResult,
//             /// Get a mutable pointer to an element at the index
//             get_item_ptr: *const fn (implementor: *anyopaque, idx: usize) GetPtrResult,
//             /// Return references to consecutive items as a slice of items,
//             /// or an `ItemsAsSliceError` if the list cannot return consecutive items as a slice
//             get_many_item_pointers: *const fn (implementor: *anyopaque, start_idx: usize, count: usize, ptr_buf: []*T) GetItemsAsSliceResult,
//             /// Return references to consecutive items as a slice of item slices,
//             /// or an `ItemsAsSliceOfSlicesError` if the list cannot return consecutive items as a slice
//             get_consecutive_item_pointers_as_slice_of_slices: *const fn (implementor: *anyopaque, start_idx: usize, count: usize) GetItemsAsSliceOfSlicesResult,
//             /// Return references to consecutive items as a slice of pointers to the items,
//             /// or an `ItemsAsSliceOfPointersError` if the list cannot return consecutive items as a slice
//             get_consecutive_item_pointers_as_slice_of_ptrs: *const fn (implementor: *anyopaque, start_idx: usize, count: usize) GetItemsAsSliceOfPointersResult,
//         };

//         pub const OutputRange = union(RangeKind) {
//             Slice: []const T,
//             SliceOfSlices: []const []const T,
//             SliceOfPointers: []const *const T,
//             FirstAndLast: FirstLast,
//         };

//         pub const FirstLast = struct {
//             first_idx: usize,
//             last_idx: usize,
//         };

//         pub const InsertResult = struct {
//             success: bool = true,
//             first_new_idx: usize,
//             last_new_idx: usize,
//             did_shift_items_up: bool,
//             first_idx_shifted_up: usize,

//             pub const FAILURE = InsertResult{
//                 .success = false,
//                 .first_new_idx = NULL_IDX,
//                 .last_new_idx = NULL_IDX,
//                 .did_shift_items_up = false,
//                 .first_idx_shifted_up = NULL_IDX,
//             };
//         };

//         pub const AppendResult = struct {
//             success: bool = true,
//             first_new_idx: usize,
//             last_new_idx: usize,
//         };

//         pub const GetPtrResult = struct {
//             success: bool = true,
//             ptr: *T,

//             pub const FAILURE = GetPtrResult{
//                 .success = false,
//                 .ptr = undefined,
//             };
//         };

//         pub const GetManyPointersResult = struct {
//             success: bool = true,
//             pointers: []*T,

//             pub const FAILURE = GetItemsAsSliceResult{
//                 .success = false,
//                 .slice = undefined,
//             };
//         };
//         pub const GetItemsAsSliceOfSlicesResult = struct {
//             success: bool = true,
//             slices: []const []T,

//             pub const FAILURE = GetItemsAsSliceOfSlicesResult{
//                 .success = false,
//                 .slices = undefined,
//             };
//         };
//         pub const GetItemsAsSliceOfPointersResult = struct {
//             success: bool = true,
//             pointers: []*T,

//             pub const FAILURE = GetItemsAsSliceOfPointersResult{
//                 .success = false,
//                 .pointers = undefined,
//             };
//         };

//         pub inline fn ensure_additional_capacity(self: Self, count: usize, alloc: Allocator) void {
//             assert_with_reason(no_err(self.vtable.ensure_additional_capacity(self.implementor, count, alloc)), @src(), "allocator out of memory for {d} more items", .{count});
//         }

//         pub inline fn ensure_additional_capacity_or_error(self: Self, count: usize, alloc: Allocator) Allocator.Error!void {
//             return self.vtable.ensure_additional_capacity(self.implementor, count, alloc);
//         }

//         pub inline fn insert_slot(self: Self, idx: usize, alloc: Allocator) InsertResult {
//             const alloc_result = self.vtable.ensure_additional_capacity(self.implementor, 1, alloc);
//             assert_with_reason(no_err(alloc_result), @src(), "allocation error while attempting to add 1 item", .{});
//             return self.vtable.insert_new_items_at_idx(self.implementor, idx, 1);
//         }
//         pub inline fn insert_slot_assume_capacity(self: Self, idx: usize) InsertResult {
//             return self.vtable.insert_new_items_at_idx(self.implementor, idx, 1);
//         }
//     };
// }
