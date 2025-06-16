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
// const Assert = Root.Assert;
// const assert_with_reason = Assert.assert_with_reason;
// const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
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
// const ListOptions = Root.List.ListOptions;
// const ListOptionsWithoutElem = Root.List.ListOptionsWithoutElem;
// const AllocInfal = Root.AllocatorInfallible;
// // const Iterator = Root.Iterator.Iterator;
// // const IterCaps = Root.Iterator.IteratorCapabilities;
// const Traverser = Root.Traverser.Traverser;
// const TraverseCaps = Root.Traverser.TraverserCapabilities;

// pub const HeirarchyListOptions = struct {
//     elem_list_options: ListOptions,
//     children_field: []const u8,
//     iter_stack_list_options: ListOptionsWithoutElem,
// };

// pub fn HeirarchyList(comptime options: HeirarchyListOptions) type {
//     const BaseList = Root.List.List(options.elem_list_options);
//     assert_with_reason(Types.type_has_field_with_type(options.elem_list_options.element_type, options.children_field, BaseList), @src(), "type `{s}` (options.list_options.element_type) did not have the field '{s}' (options.children_field) with type `{s}` (Root.List.List(options.list_options))", .{ @typeName(options.elem_list_options.element_type), options.children_field, @typeName(BaseList) });
//     return struct {
//         const Self = @This();

//         root: List,

//         const CHILDREN_FIELD = options.children_field;
//         pub const List = BaseList;
//         pub const Elem = List.Elem;
//         pub const Idx = List.Idx;

//         pub inline fn new_empty(assert_alloc: Allocator) Self {
//             return Self{ .root = List.new_empty(assert_alloc) };
//         }

//         pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) Self {
//             return Self{ .root = List.new_with_capacity(capacity, alloc) };
//         }

//         pub inline fn clone(self: Self, alloc: Allocator) Self {
//             return Self{ .root = self.root.clone(alloc) };
//         }

//         pub inline fn ensure_total_capacity(self: *Self, capacity: Idx, alloc: Allocator) void {
//             return self.root.ensure_total_capacity(capacity, alloc);
//         }

//         pub inline fn ensure_total_capacity_exact(self: *Self, capacity: Idx, alloc: Allocator) void {
//             return self.root.ensure_total_capacity_exact(capacity, alloc);
//         }

//         pub inline fn ensure_unused_capacity(self: *Self, capacity: Idx, alloc: Allocator) void {
//             return self.root.ensure_unused_capacity(capacity, alloc);
//         }

//         fn get_children(elem: *const Elem) List {
//             return @field(elem, CHILDREN_FIELD);
//         }
//         const PtrIdx = struct {
//             ptr: *Elem,
//             idx: Idx,
//         };
//         fn get_ptr_idx(self: *List, input: anytype) PtrIdx {
//             const T = @TypeOf(input);
//             const idx: Idx = switch (T) {
//                 *Elem, *const Elem => Utils.index_from_pointer(Elem, Idx, self.list.ptr, input),
//                 Idx => input,
//                 else => assert_with_reason(false, @src(), "invalid input type `{s}` for `get_ptr_idx()`", .{@typeName(T)}),
//             };
//             assert_idx_less_than_len(idx, self.list.len, @src());
//             const ptr: *Elem = switch (T) {
//                 *Elem => input,
//                 *const Elem => @constCast(input),
//                 Idx => &self.list.ptr[idx],
//                 else => unreachable,
//             };
//             return PtrIdx{ .idx = idx, .ptr = ptr };
//         }
//         //CHECKPOINT
//         const IterState = struct {
//             list: *List,
//             curr_idx: Idx,
//             parent_ptr: *Elem,
//         };
//         pub const IteratorState = struct {
//             state_stack: IterStateList,
//             allocator: AllocInfal,

//             pub const iter_state_list_opts = Root.List.ListOptions.from_options_without_elem(options.iter_stack_list_options, IterState, null);
//             pub const IterStateList = Root.List.List(iter_state_list_opts);
//             pub const Traverser = Root.Traverser.Traverser(Root.Traverser.TraverserOptions{
//                 .elem_type = *Elem,
//                 .goto_left_children = true,
//                 .goto_right_children = true,
//                 .goto_parent = true,
//                 .goto_right_sibling = true,
//                 .goto_left_sibling = true,
//                 .reset = true,
//                 .state_slots = 0,
//             });

//             const DF_CF = struct {
//                 fn iter_peek_next(self_opaque: *anyopaque) ?IterItem {
//                     const self: *IteratorState = @ptrCast(@alignCast(self_opaque));
//                     if (self.state_stack.len == 0) return null;
//                     var curr_state: IterState = self.state_stack.get_last();
//                     if (curr_state.curr_idx == curr_state.list.len) {
//                         if (self.state_stack.len == 1) return null;
//                         const prev_state: IterState = self.state_stack.ptr[self.state_stack.len - 2];
//                         return IterItem{
//                             .item = curr_state.parent_ptr,
//                             .parent = prev_state.parent_ptr,
//                         };
//                     }
//                     var this = Self.get_ptr_idx(curr_state.list, curr_state.curr_idx);
//                     var children = Self.get_children(this.ptr);
//                     while (children.len > 0) {
//                         self.state_stack.append(IterState{
//                             .curr_idx = 0,
//                             .list = children,
//                             .parent_ptr = this.ptr,
//                         }, self.allocator);
//                         curr_state = self.state_stack.get_last();
//                         this = Self.get_ptr_idx(curr_state.list, curr_state.curr_idx);
//                         children = Self.get_children(this.ptr);
//                     }
//                     return IterItem{
//                         .item = this.ptr,
//                         .parent = curr_state.parent_ptr,
//                     };
//                 }
//                 fn iter_adv_next(self_opaque: *anyopaque) bool {
//                     const self: *IteratorState = @ptrCast(@alignCast(self_opaque));
//                     if (self.state_stack.len == 0) return false;
//                     const curr_state: IterState = self.state_stack.get_last();
//                     if (curr_state.curr_idx == curr_state.list.len) {
//                         self.state_stack.len -= 1;
//                         if (self.state_stack.len == 0) return true;
//                     }
//                     self.state_stack.ptr[self.state_stack.len - 1].curr_idx += 1;
//                     return true;
//                 }
//             };
//             const DF_PF = struct {
//                 fn iter_peek_next(self_opaque: *anyopaque) bool {
//                     _ = self_opaque;
//                     return false;
//                 }
//                 fn iter_adv_next(self_opaque: *anyopaque) bool {
//                     _ = self_opaque;
//                     return false;
//                 }
//             };

//             const DF_CF_VTABLE = Iterator(IterItem).VTable{
//                 .capabilities = iter_caps,
//                 .reset = Iter.NOOP.reset,
//                 .advance_next = DF_CF.iter_adv_next,
//                 .advance_prev = Iter.NOOP.advance_prev,
//                 .peek_next_or_null = DF_CF.iter_peek_next,
//                 .peek_prev_or_null = Iter.NOOP.peek_prev_or_null,
//                 .save_state = Iter.NOOP.save_state,
//                 .load_state = Iter.NOOP.load_state,
//             };

//             pub fn depth_first_children_first_iterator(self: *IteratorState) Iterator(IterItem) {
//                 return Iterator(IterItem){
//                     .implementor = @ptrCast(self),
//                     .vtable = DF_CF_VTABLE,
//                 };
//             }
//         };
//     };
// }
