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
// const SourceLocation = builtin.SourceLocation;
// const mem = std.mem;
// const math = std.math;
// const crypto = std.crypto;
// const Allocator = std.mem.Allocator;
// const ArrayListUnmanaged = std.ArrayListUnmanaged;
// const ArrayList = std.ArrayListUnmanaged;
// const Type = std.builtin.Type;

// const Root = @import("./_root.zig");
// const Assert = Root.Assert;
// const assert_with_reason = Assert.assert_with_reason;
// const assert_pointer_resides_in_slice = Assert.assert_pointer_resides_in_slice;
// const assert_slice_resides_in_slice = Assert.assert_slice_resides_in_slice;
// const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
// const assert_idx_and_pointer_reside_in_slice_and_match = Assert.assert_idx_and_pointer_reside_in_slice_and_match;
// const Utils = Root.Utils;
// const debug_switch = Utils.debug_switch;
// const safe_switch = Utils.safe_switch;
// const comp_switch = Utils.comp_switch;
// const Types = Root.Types;
// const Iterator = Root.Iterator.Iterator;
// const IterCaps = Root.Iterator.IteratorCapabilities;
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

// pub const LinkedListManagerOptions = struct {
//     /// options for the underlying `List` that holds all the real memory
//     /// for this `LinkedList`
//     list_options: Root.List.ListOptions,
//     /// The field name on your user type that holds
//     /// the index of the 'next' item in the list.
//     ///
//     /// If set to `null`, the `LinkedList` will not track items in the
//     /// forward/next direction at all,
//     forward_linkage: ?[]const u8 = null,
//     /// The field name on your user type that holds
//     /// the index of the 'previous' item in the list.
//     ///
//     /// If set to `null`, the `LinkedList` will not track items in the
//     /// backward/previous direction at all,
//     backward_linkage: ?[]const u8 = null,
//     /// The field name on your user type that holds
//     /// the index of the first child of the element, if any
//     ///
//     /// If set to `null`, the `LinkedList` will not track children in the forward/next direction,
//     /// even if `force_cache_first_index` is true
//     first_child_linkage: ?[]const u8 = null,
//     /// The field name on your user type that holds
//     /// the index of the last child of the element, if any
//     ///
//     /// If set to `null`, the `LinkedList` will not track children in the backward/prev direction,
//     /// even if `force_cache_last_index` is true
//     last_child_linkage: ?[]const u8 = null,
//     /// The field name on your user type that holds
//     /// the index of the parent of the element, if any
//     ///
//     /// If set to `null`, the `LinkedList` will not track element parents
//     parent_linkage: ?[]const u8 = null,
//     /// The details describing how your user type caches the 'master list'
//     /// state of an item within itself.
//     ///
//     /// If included, the user type can
//     /// determine what master list it belongs to without having to traverse
//     /// through the list to find what list it belongs to.
//     ///
//     /// If set to `null`, the `LinkedList` will not cache
//     /// master list state on the user type.
//     element_list_flag_access: ?ElementStateAccess = null,
//     /// The field name on your user type that holds
//     /// a cached value of the item's real index in the `LinkedList`'s
//     /// underlying memory buffer.
//     ///
//     /// If set to `null`, the `LinkedList` will not cache the items index
//     /// inside the user type.
//     ///
//     /// This is not strictly speaking necessary if memory footprint of the user
//     /// type is a concern, as the index can be calculated from a *pointer* to the
//     /// element in O(1) time with a few additional arithmetic operations.
//     element_idx_cache_field: ?[]const u8 = null,
//     /// Forces the `LinkedList` to cache the last/tail index of lists
//     /// even if the user type items themselves are not linked in the backward/previous
//     /// direction.
//     ///
//     /// This allows appending an item to the tail of a forward singly-linked list
//     force_cache_last_index: bool = true,
//     /// Forces the `LinkedList` to cache the first/head index of lists
//     /// even if the user type items themselves are not linked in the forward/next
//     /// direction.
//     ///
//     /// This allows appending an item to the head of a backward singly-linked list
//     force_cache_first_index: bool = true,
//     /// This enum must list all desired master lists ('used', 'free', 'none', etc...)
//     /// with tag values starting from 0 and increasing with no gaps
//     ///
//     /// The ***LAST*** list tag (largest tag value) is considred the 'untracked'
//     /// or 'leaked' list, meaning the LinkedList does not track the head and/or
//     /// tail index for that list.
//     ///
//     /// That list is intended for isolated lists
//     /// whose head/tail indexes are cached by the user somewhere else, and if the user
//     /// loses those indexes they are essentially 'leaked' until the LinkedList's base
//     /// memory is released back to the allocator.
//     master_list_enum: type = DefaultSet,
//     /// Inserts additional (usually O(N) or O(N^2) time) asserts in comptime, Debug, or ReleaseSafe
//     stronger_asserts: bool = false,
//     /// Allows slower fallback operations when the faster alternative is impossible
//     ///
//     /// For example, if your LinkedList does not link in the backward/previous direction,
//     /// calling `get_prev_index()` can be achieved by traversing forward from the start
//     /// of the list until you find the item that points to the one provided
//     ///
//     /// Setting this to `false` makes slow fallback paths panic
//     allow_slow_fallbacks: bool = false,
// };

// pub const DefaultSet = enum(u8) {
//     USED = 0,
//     FREE = 1,
//     NONE = 2,
// };

// pub const ElementStateAccess = struct {
//     /// The field name of the integer field that holds the
//     /// list state flag. It need not take the entire field,
//     /// only the number of bits required to represent all tags
//     /// in `master_list_enum`
//     field: []const u8,
//     /// The integer type the field should have
//     field_type: type,
//     /// The bit offset to the start of of the
//     /// list state flag data
//     field_bit_offset: comptime_int,
//     /// The number of bits to use, starting from the bit offset,
//     /// for storing the flag state. It is compile-time checked
//     /// to allow sufficient space for all tags in `master_list_enum`
//     field_bit_count: comptime_int,
// };

// pub const Direction = enum {
//     FORWARD,
//     BACKWARD,
// };

// pub fn define_linked_list_manager(comptime options: LinkedListManagerOptions) type {
//     assert_with_reason(options.forward_linkage != null or options.backward_linkage != null, @src(), "either `forward_linkage` or `backward_linkage` must be provided, both cannot be left null", .{});
//     const F = options.forward_linkage != null;
//     const B = options.backward_linkage != null;
//     const S = options.element_list_flag_access != null;
//     const C = options.element_idx_cache_field != null;
//     const FC = options.first_child_linkage != null;
//     const LC = options.last_child_linkage != null;
//     const P = options.parent_linkage != null;
//     assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(options.master_list_enum), @src(), "all enum tag values in linked_set_enum must start from zero and increase with no gaps between values", .{});
//     if (F) {
//         const F_FIELD = options.forward_linkage.?;
//         assert_with_reason(@hasField(options.list_options.element_type, F_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), F_FIELD });
//         const F_TYPE = @FieldType(options.list_options.element_type, F_FIELD);
//         assert_with_reason(Types.type_is_int(F_TYPE), @src(), "next index field `.{s}` on element type `{s}` is not an integer type", .{ F_FIELD, @typeName(options.list_options.element_type) });
//         assert_with_reason(F_TYPE == options.list_options.index_type, @src(), "next index field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ F_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     if (B) {
//         const B_FIELD = options.backward_linkage.?;
//         assert_with_reason(@hasField(options.list_options.element_type, B_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), B_FIELD });
//         const B_TYPE = @FieldType(options.list_options.element_type, B_FIELD);
//         assert_with_reason(Types.type_is_int(B_TYPE), @src(), "prev index field `.{s}` on element type `{s}` is not an integer type", .{ B_FIELD, @typeName(options.list_options.element_type) });
//         assert_with_reason(B_TYPE == options.list_options.index_type, @src(), "prev index field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ B_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     if (S) {
//         const S_FIELD = options.element_list_flag_access.?.field;
//         assert_with_reason(@hasField(options.list_options.element_type, S_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), S_FIELD });
//         const S_TYPE = @FieldType(options.list_options.element_type, S_FIELD);
//         assert_with_reason(Types.type_is_int(S_TYPE), @src(), "element list field `.{s}` on element type `{s}` is not an integer type", .{ S_FIELD, @typeName(options.list_options.element_type) });
//         assert_with_reason(S_TYPE == options.element_list_flag_access.?.field_type, @src(), "element list field `.{s}` on element type `{s}` does not match listd type {s}", .{ S_FIELD, @typeName(options.list_options.element_type), @typeName(options.element_list_flag_access.?.field_type) });
//         const tag_count = Types.enum_max_field_count(options.master_list_enum);
//         const flag_count = 1 << options.element_list_flag_access.?.field_bit_count;
//         assert_with_reason(flag_count >= tag_count, @src(), "options.element_list_access.field_bit_count {d} (max val = {d}) cannot hold all tag values for options.linked_set_enum {d}", .{ options.element_list_flag_access.?.field_bit_count, flag_count, tag_count });
//     }
//     if (C) {
//         const C_FIELD = options.element_idx_cache_field.?;
//         assert_with_reason(@hasField(options.list_options.element_type, C_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), C_FIELD });
//         const C_TYPE = @FieldType(options.list_options.element_type, C_FIELD);
//         assert_with_reason(C_TYPE == options.list_options.index_type, @src(), "element list field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ C_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     if (FC) {
//         const FC_FIELD = options.first_child_linkage.?;
//         assert_with_reason(@hasField(options.list_options.element_type, FC_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), FC_FIELD });
//         const FC_TYPE = @FieldType(options.list_options.element_type, FC_FIELD);
//         assert_with_reason(FC_TYPE == options.list_options.index_type, @src(), "element list field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ FC_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     if (LC) {
//         const LC_FIELD = options.last_child_linkage.?;
//         assert_with_reason(@hasField(options.list_options.element_type, LC_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), LC_FIELD });
//         const LC_TYPE = @FieldType(options.list_options.element_type, LC_FIELD);
//         assert_with_reason(LC_TYPE == options.list_options.index_type, @src(), "element list field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ LC_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     if (P) {
//         const P_FIELD = options.parent_linkage.?;
//         assert_with_reason(@hasField(options.list_options.element_type, P_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), P_FIELD });
//         const P_TYPE = @FieldType(options.list_options.element_type, P_FIELD);
//         assert_with_reason(P_TYPE == options.list_options.index_type, @src(), "element list field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ P_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
//     }
//     return struct {
//         list: BaseList = BaseList.UNINIT,
//         lists: [SET_COUNT]ListData = UNINIT_SETS,
//         assert_alloc: if (ASSERT_ALLOC) Allocator else void = if (ASSERT_ALLOC) DummyAllocator.allocator else void{},

//         const STRONG_ASSERT = options.stronger_asserts;
//         const SET_COUNT = Types.enum_defined_field_count(options.master_list_enum) - 1;
//         const FORWARD = options.forward_linkage != null;
//         const HEAD_NO_FORWARD = HEAD and !FORWARD;
//         const NEXT_FIELD = if (FORWARD) options.forward_linkage.? else "";
//         const BACKWARD = options.backward_linkage != null;
//         const PARENT = options.parent_linkage != null;
//         const PARENT_FIELD = if (PARENT) options.parent_linkage.? else "";
//         const FIRST_CHILD = options.first_child_linkage != null;
//         const FIRST_CHILD_FIELD = if (PARENT) options.first_child_linkage.? else "";
//         const LAST_CHILD = options.last_child_linkage != null;
//         const LAST_CHILD_FIELD = if (PARENT) options.last_child_linkage.? else "";
//         const TAIL_NO_BACKWARD = TAIL and !BACKWARD;
//         const BIDIRECTION = BACKWARD and FORWARD;
//         const HEAD = FORWARD or options.force_cache_first_index;
//         const TAIL = BACKWARD or options.force_cache_last_index;
//         const PREV_FIELD = if (BACKWARD) options.backward_linkage.? else "";
//         const USED = options.linked_sets == .USED_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
//         const FREE = options.linked_sets == .FREE_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
//         const STATE = options.element_list_flag_access != null;
//         const CACHE = options.element_idx_cache_field != null;
//         const CACHE_FIELD = if (CACHE) options.element_idx_cache_field.? else "";
//         const T_STATE_FIELD = if (STATE) options.element_list_flag_access.?.field_type else void;
//         const STATE_FIELD = if (STATE) options.element_list_flag_access.?.field else "";
//         const STATE_OFFSET = if (STATE) options.element_list_flag_access.?.field_bit_offset else 0;
//         const UNINIT = LinkedList{};
//         const RETURN_ERRORS = options.list_options.alloc_error_behavior == .RETURN_ERRORS;
//         const NULL_IDX = math.maxInt(Idx);
//         const MAX_STATE_TAG = Types.enum_max_value(ListTag);
//         const UNTRACKED_LIST: ListTag = @enumFromInt(MAX_STATE_TAG);
//         const UNTRACKED_LIST_RAW: ListTagInt = MAX_STATE_TAG;
//         const STATE_MASK: if (STATE) options.element_list_flag_access.?.field_type else comptime_int = if (STATE) build: {
//             const mask_unshifted = (1 << options.element_list_flag_access.?.field_bit_count) - 1;
//             break :build mask_unshifted << options.element_list_flag_access.?.field_bit_offset;
//         } else 0;
//         const STATE_CLEAR_MASK: if (STATE) options.element_list_flag_access.?.field_type else comptime_int = if (STATE) ~STATE_MASK else 0b1111111111111111111111111111111111111111111111111111111111111111;
//         const HEAD_TAIL: u2 = (@as(u2, @intFromBool(HEAD)) << 1) | @as(u2, @intFromBool(TAIL));
//         const HAS_HEAD_HAS_TAIL: u2 = 0b11;
//         const HAS_HEAD_NO_TAIL: u2 = 0b10;
//         const NO_HEAD_HAS_TAIL: u2 = 0b01;
//         const ALLOW_SLOW = options.allow_slow_fallbacks;
//         const ASSERT_ALLOC = options.assert_correct_allocator;
//         const UNINIT_SETS: [SET_COUNT]ListData = build: {
//             var sets: [SET_COUNT]ListData = undefined;
//             for (0..SET_COUNT) |idx| {
//                 sets[idx] = ListData{};
//             }
//             break :build sets;
//         };

//         const LinkedList = @This();
//         pub const BaseList = Root.List.define_manual_allocator_list_type(options.list_options);
//         pub const Error = Allocator.Error;
//         pub const Elem = options.list_options.element_type;
//         pub const Idx = options.list_options.index_type;
//         // pub const Iterator = LinkedListIterator(List);
//         pub const ListTag = options.master_list_enum;
//         const ListTagInt = Types.enum_tag_type(ListTag);
//         pub const ListData = switch (HEAD_TAIL) {
//             HAS_HEAD_HAS_TAIL => struct {
//                 first_idx: Idx = NULL_IDX,
//                 last_idx: Idx = NULL_IDX,
//                 count: Idx = 0,
//             },
//             HAS_HEAD_NO_TAIL => struct {
//                 first_idx: Idx = NULL_IDX,
//                 count: Idx = 0,
//             },
//             NO_HEAD_HAS_TAIL => struct {
//                 last_idx: Idx = NULL_IDX,
//                 count: Idx = 0,
//             },
//             else => unreachable,
//         };
//         pub const IndexesInSameList = struct {
//             list: ListTag,
//             idxs: []const Idx,

//             pub inline fn new(list: ListTag, idxs: []const Idx) IndexesInSameList {
//                 return IndexesInSameList{ .list = list, .idxs = idxs };
//             }
//         };
//         const IdxPtrIdx = struct {
//             idx_ptr: *Idx = &DUMMY_IDX,
//             idx: Idx = NULL_IDX,
//         };
//         const ConnLeft = choose: {
//             if (BIDIRECTION) break :choose IdxPtrIdx;
//             if (FORWARD) break :choose *Idx;
//             if (BACKWARD) break :choose Idx;
//             unreachable;
//         };
//         const ConnRight = choose: {
//             if (BIDIRECTION) break :choose IdxPtrIdx;
//             if (FORWARD) break :choose Idx;
//             if (BACKWARD) break :choose *Idx;
//             unreachable;
//         };
//         const ConnLeftRight = struct {
//             left: ConnLeft,
//             right: ConnRight,

//             pub inline fn new(left: ConnLeft, right: ConnRight) ConnLeftRight {
//                 return ConnLeftRight{ .left = left, .right = right };
//             }
//         };
//         const ConnInsert = struct {
//             first: ConnRight,
//             last: ConnLeft,

//             pub inline fn new(first: ConnRight, last: ConnLeft) ConnInsert {
//                 return ConnInsert{ .first = first, .last = last };
//             }
//         };
//         const ConnData = struct {
//             list: ListTag,
//             edges: ConnLeftRight,
//             count: Idx,
//         };
//         pub const IndexInList = struct {
//             list: ListTag,
//             idx: Idx,

//             pub inline fn new(list: ListTag, idx: Idx) IndexInList {
//                 return IndexInList{ .list = list, .idx = idx };
//             }
//         };
//         pub const CountFromList = struct {
//             list: ListTag,
//             count: Idx,

//             pub inline fn new(list: ListTag, count: Idx) CountFromList {
//                 return CountFromList{ .list = list, .count = count };
//             }
//         };
//         var DUMMY_IDX: Idx = NULL_IDX;
//         var DUMMY_ELEM: Elem = undefined;

//         pub const ListIdx = struct {
//             list: ListTag,
//             idx: Idx,
//         };

//         pub const Get = struct {
//             pub const CreateOneNew = struct {};
//             pub const FirstFromList = struct { list: ListTag };
//             pub const LastFromList = struct { list: ListTag };
//             pub const FirstFromListElseCreateNew = struct { list: ListTag };
//             pub const LastFromListElseCreateNew = struct { list: ListTag };
//             pub const FirstCountFromList = struct { list: ListTag, count: Idx };
//             pub const LastCountFromList = struct { list: ListTag, count: Idx };
//             pub const FirstCountFromListElseCreateNew = struct { list: ListTag, count: Idx };
//             pub const LastCountFromListElseCreateNew = struct { list: ListTag, count: Idx };
//             pub const OneIndex = struct { idx: Idx };
//             pub const OneIndexInList = struct { idx: Idx, list: ListTag };
//             pub const CreateManyNew = struct { count: Idx };
//             pub const FromSlice = struct { slice: LLSlice };
//             pub const FromSliceElseCreateNew = struct { slice: LLSlice, total_needed: Idx };
//             pub const SparseIndexes = struct { indexes: []const Idx };
//             pub const SparseIndexesFromSameList = struct { list: ListTag, indexes: []const Idx };
//             pub const SparseIndexesFromAnyList = struct { indexes: []const ListIdx };
//         };

//         pub const Insert = struct {
//             pub const AtBeginningOfList = struct { list: ListTag };
//             pub const AtEndOfList = struct { list: ListTag };
//             pub const AfterIndex = struct { idx: Idx };
//             pub const AfterIndexInList = struct { idx: Idx, list: ListTag };
//             pub const BeforeIndex = struct { idx: Idx };
//             pub const BeforeIndexInList = struct { idx: Idx, list: ListTag };
//             pub const AtBeginningOfChildren = struct { parent_idx: Idx };
//             pub const AtEndOfChildren = struct { parent_idx: Idx };
//             pub const Untracked = struct {};
//         };

//         /// Represents a slice of logical items in a Linked List
//         ///
//         /// Manually altering its internal fields should be considered unsafe if done incorrectly,
//         /// use the provided methods on the `LinkedListManager` or the methods on this type instead
//         pub const LLSlice = struct {
//             list: ListTag,
//             first: Idx = NULL_IDX,
//             last: Idx = NULL_IDX,
//             count: Idx = 0,

//             pub inline fn single(list: ListTag, idx: Idx) LLSlice {
//                 return LLSlice{
//                     .list = list,
//                     .first = idx,
//                     .last = idx,
//                     .count = 1,
//                 };
//             }

//             pub inline fn new(list: ListTag, first: Idx, last: Idx, count: Idx) LLSlice {
//                 return LLSlice{
//                     .list = list,
//                     .first = first,
//                     .last = last,
//                     .count = count,
//                 };
//             }

//             pub inline fn to_slice_with_total_needed(self: LLSlice, total_needed: Idx) LLSliceWithTotalNeeded {
//                 return LLSliceWithTotalNeeded{
//                     .total_needed = total_needed,
//                     .slice = self,
//                 };
//             }

//             pub fn grow_end_rightward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 const new_last = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.list, self.last, count, false, 0);
//                 self.count += count;
//                 self.last = new_last;
//             }

//             pub fn shrink_end_leftward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 const new_last = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.list, self.last, count, true, self.first);
//                 self.count += count;
//                 self.last = new_last;
//             }

//             pub fn grow_start_leftward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 const new_first = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.list, self.first, count, false, 0);
//                 self.count += count;
//                 self.first = new_first;
//             }

//             pub fn shrink_start_rightward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 const new_first = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.list, self.first, count, true, self.last);
//                 self.count += count;
//                 self.first = new_first;
//             }

//             pub fn slide_right(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 self.grow_end_rightward(list, count);
//                 self.shrink_start_rightward(list, count);
//             }

//             pub fn slide_left(self: *LLSlice, list: *const LinkedList, count: Idx) void {
//                 self.grow_start_leftward(list, count);
//                 self.shrink_end_leftward(list, count);
//             }

//             pub fn SliceIteratorState(comptime state_slots: comptime_int) type {
//                 return struct {
//                     linked_list: *LinkedList,
//                     slice: *const LLSlice,
//                     left_idx: Idx,
//                     right_idx: Idx,
//                     state_slots: [state_slots]struct {
//                         left: Idx,
//                         right: Idx,
//                     },

//                     pub fn iterator(self: *SliceIteratorState(state_slots)) Iterator(Elem) {
//                         return Iterator(Elem){
//                             .implementor = @ptrCast(self),
//                             .vtable = &Iterator(Elem).VTable{
//                                 .capabilities = s_iter_caps,
//                                 .reset = s_iter_reset,
//                                 .load_state = s_iter_load,
//                                 .save_state = s_iter_save,
//                                 .advance_next = s_iter_advance_next,
//                                 .peek_next_or_null = s_iter_peek_next_or_null,
//                                 .advance_prev = s_iter_advance_prev,
//                                 .peek_prev_or_null = s_iter_peek_prev_or_null,
//                             },
//                         };
//                     }

//                     fn s_iter_save(self: *anyopaque, slot: usize) bool {
//                         if (slot >= state_slots) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         iter.state_slots[slot].left = iter.left_idx;
//                         iter.state_slots[slot].right = iter.right_idx;
//                         return true;
//                     }

//                     fn s_iter_load(self: *anyopaque, slot: usize) bool {
//                         if (slot >= state_slots) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         iter.left_idx = iter.state_slots[slot].left;
//                         iter.right_idx = iter.state_slots[slot].right;
//                         return true;
//                     }

//                     fn s_iter_peek_prev_or_null(self: *anyopaque) ?*Elem {
//                         if (!BACKWARD) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         if (iter.left_idx == NULL_IDX or iter.right_idx == iter.slice.first) return null;
//                         return iter.linked_list.get_ptr(iter.left_idx);
//                     }
//                     fn s_iter_advance_prev(self: *anyopaque) bool {
//                         if (!BACKWARD) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         if (iter.left_idx == NULL_IDX or iter.right_idx == iter.slice.first) return false;
//                         iter.right_idx = iter.left_idx;
//                         iter.left_idx = iter.linked_list.get_prev_idx(iter.slice.list, iter.left_idx);
//                         return true;
//                     }
//                     fn s_iter_peek_next_or_null(self: *anyopaque) ?*Elem {
//                         if (!FORWARD) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         if (iter.right_idx == NULL_IDX or iter.left_idx == iter.slice.last) return null;
//                         return iter.linked_list.get_ptr(iter.right_idx);
//                     }
//                     fn s_iter_advance_next(self: *anyopaque) bool {
//                         if (!FORWARD) return false;
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         if (iter.right_idx == NULL_IDX or iter.left_idx == iter.slice.last) return false;
//                         iter.left_idx = iter.right_idx;
//                         iter.right_idx = iter.linked_list.get_next_idx(iter.slice.list, iter.right_idx);
//                         return true;
//                     }
//                     fn s_iter_reset(self: *anyopaque) bool {
//                         const iter: *SliceIteratorState(state_slots) = @ptrCast(@alignCast(self));
//                         if (FORWARD) {
//                             iter.right_idx = iter.slice.first;
//                             iter.left_idx = NULL_IDX;
//                         } else {
//                             iter.left_idx = iter.slice.last;
//                             iter.right_idx = NULL_IDX;
//                         }
//                         return true;
//                     }
//                     fn s_iter_caps() IterCaps {
//                         var flags = IterCaps.from_flag(.RESET);
//                         if (FORWARD) flags.set(.FORWARD);
//                         if (BACKWARD) flags.set(.BACKWARD);
//                         const slots: IterCaps.RawInt = @min(state_slots, 7);
//                         flags.set_group_from_int_aligned_at_bit_0_dont_mask(.SAVE_LOAD, slots);
//                         return flags;
//                     }
//                 };
//             }

//             pub inline fn new_iterator_state_at_start_of_slice(self: *const LLSlice, linked_list: *LinkedList, comptime state_slots: comptime_int) SliceIteratorState(state_slots) {
//                 return SliceIteratorState(state_slots){
//                     .linked_list = linked_list,
//                     .slice = self,
//                     .left_idx = NULL_IDX,
//                     .right_idx = if (FORWARD) self.first else NULL_IDX,
//                     .state_slots = undefined,
//                 };
//             }
//             pub inline fn new_iterator_state_at_end_of_slice(self: *const LLSlice, linked_list: *LinkedList, comptime state_slots: comptime_int) SliceIteratorState(state_slots) {
//                 return SliceIteratorState(state_slots){
//                     .linked_list = linked_list,
//                     .slice = self,
//                     .left_idx = if (BACKWARD) self.last else NULL_IDX,
//                     .right_idx = NULL_IDX,
//                     .state_slots = undefined,
//                 };
//             }
//         };

//         /// Variant of `LLSlice` used for the purpose of supplying a function
//         /// with arbitrary items to draw from before any new items are created
//         pub const LLSliceWithTotalNeeded = struct {
//             slice: LLSlice,
//             total_needed: Idx,
//         };

//         /// All functions/structs in this namespace fall in at least one of 3 categories:
//         /// - DANGEROUS to use if you do not manually manage and maintain a valid linked list list
//         /// - Are only useful for asserting/creating intenal list
//         /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
//         ///
//         /// They are provided here publicly to facilitate special user use cases
//         pub const Internal = struct {
//             pub fn find_idx_n_places_after_this_one_with_fallback_start(self: *const LinkedList, list: ListTag, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
//                 if (FORWARD) {
//                     return traverse_forward_to_find_idx_n_places_after_this_one(self, list, idx, count);
//                 } else {
//                     return traverse_backward_to_find_idx_n_places_after_this_one_start_at(self, list, idx, count, use_fallback_start, fallback_start_idx);
//                 }
//             }

//             pub fn find_idx_n_places_before_this_one_with_fallback_start(self: *const LinkedList, list: ListTag, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
//                 if (BACKWARD) {
//                     return traverse_backward_to_find_idx_n_places_before_this_one(self, list, idx, count);
//                 } else {
//                     return traverse_forward_to_find_idx_n_places_before_this_one_start_at(self, list, idx, count, use_fallback_start, fallback_start_idx);
//                 }
//             }

//             pub fn traverse_forward_to_find_idx_n_places_after_this_one(self: *const LinkedList, this_idx: Idx, count: Idx) Idx {
//                 var delta: Idx = 0;
//                 var result: Idx = this_idx;
//                 while (delta < count and result != NULL_IDX) {
//                     result = self.get_next_idx(result);
//                     delta += 1;
//                 }
//                 assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d}, (only {d})", .{ count, this_idx, delta });
//                 return result;
//             }

//             pub fn traverse_backward_to_find_idx_n_places_before_this_one(self: *const LinkedList, this_idx: Idx, count: Idx) Idx {
//                 var delta: Idx = 0;
//                 var result: Idx = this_idx;
//                 while (delta < count and result != NULL_IDX) {
//                     result = self.get_prev_idx(result);
//                     delta += 1;
//                 }
//                 assert_with_reason(delta == count, @src(), "there are not {d} more items before idx {d}, (only {d})", .{ count, this_idx, delta });
//                 return result;
//             }

//             pub fn traverse_backward_to_find_idx_n_places_after_this_one_start_at(self: *const LinkedList, this_idx: Idx, count: Idx, start_idx: Idx) Idx {
//                 var delta: Idx = 0;
//                 var probe: Idx = start_idx;
//                 var result: Idx = probe;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (delta < count and probe != this_idx and probe != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     probe = self.get_prev_idx(probe);
//                     delta += 1;
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d}, (only {d})", .{ count, this_idx, delta });
//                 while (probe != this_idx and (if (STRONG_ASSERT) c <= limit else true)) {
//                     probe = self.get_prev_idx(probe);
//                     result = self.get_prev_idx(result);
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in backward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, this_idx });
//                 return result;
//             }

//             pub fn traverse_forward_to_find_idx_n_places_before_this_one_start_at(self: *const LinkedList, this_idx: Idx, count: Idx, start_idx: Idx) Idx {
//                 var delta: Idx = 0;
//                 var probe: Idx = start_idx;
//                 var result: Idx = probe;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (delta < count and probe != this_idx and probe != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     probe = self.get_next_idx(probe);
//                     delta += 1;
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 assert_with_reason(delta == count, @src(), "there are not {d} more items before idx {d}, (only {d})", .{ count, this_idx, delta });
//                 while (probe != this_idx and (if (STRONG_ASSERT) c <= limit else true)) {
//                     probe = self.get_next_idx(probe);
//                     result = self.get_next_idx(result);
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, this_idx });
//                 return result;
//             }

//             pub inline fn set_idx(ptr: *Elem, idx: Idx) void {
//                 if (CACHE) @field(ptr, CACHE_FIELD) = idx;
//             }

//             pub inline fn increase_link_set_count(self: *LinkedList, list: ListTag, amount: Idx) void {
//                 if (list == UNTRACKED_LIST) return;
//                 self.lists[@intFromEnum(list)].count += amount;
//             }

//             pub inline fn decrease_link_set_count(self: *LinkedList, list: ListTag, amount: Idx) void {
//                 if (list == UNTRACKED_LIST) return;
//                 self.lists[@intFromEnum(list)].count -= amount;
//             }

//             pub inline fn set_list(ptr: *Elem, list: ListTag) void {
//                 if (STATE) {
//                     @field(ptr, STATE_FIELD) &= STATE_CLEAR_MASK;
//                     const new_list: T_STATE_FIELD = @as(T_STATE_FIELD, @intCast(@intFromEnum(list)));
//                     const new_list_shifted = new_list << STATE_OFFSET;
//                     @field(ptr, STATE_FIELD) |= new_list_shifted;
//                 }
//             }

//             pub inline fn set_first_child(ptr: *Elem, first_child: Idx) void {
//                 if (FIRST_CHILD) @field(ptr, FIRST_CHILD_FIELD) = first_child;
//             }

//             pub inline fn set_last_child(ptr: *Elem, last_child: Idx) void {
//                 if (LAST_CHILD) @field(ptr, LAST_CHILD_FIELD) = last_child;
//             }

//             pub inline fn set_parent(ptr: *Elem, parent: Idx) void {
//                 if (PARENT) @field(ptr, PARENT_FIELD) = parent;
//             }

//             pub fn initialize_element(ptr: *Elem, comptime init_list: bool, list: ListTag, comptime init_idx: bool, idx: Idx, comptime init_parent: bool, parent: Idx) void {
//                 if (init_idx) Internal.set_idx(ptr, idx);
//                 if (init_parent) Internal.set_parent(ptr, parent);
//                 if (init_list) Internal.set_list(ptr, list);
//             }

//             pub fn initialize_concurrent_indexes(self: *LinkedList, first_idx: Idx, last_idx: Idx, comptime init_link: bool, comptime init_list: bool, list: ListTag, comptime init_idx: bool, comptime init_parent: bool, parent: Idx) void {
//                 var left_idx = first_idx;
//                 var right_idx = first_idx + 1;
//                 const left_ptr = self.get_ptr(left_idx);
//                 var right_ptr = undefined;
//                 Internal.initialize_element(left_ptr, init_list, list, init_idx, left_idx, init_parent, parent);
//                 while (right_idx <= last_idx) {
//                     right_ptr = self.get_ptr(right_idx);
//                     Internal.initialize_element(right_ptr, init_list, list, init_idx, right_idx, init_parent, parent);
//                     if (init_link) {
//                         const left = Internal.get_conn_left(self, list, left_idx);
//                         const right = Internal.get_conn_right(self, list, right_idx);
//                         connect(left, right);
//                     }
//                     left_idx += 1;
//                     right_idx += 1;
//                 }
//             }

//             pub fn disconnect_one(self: *LinkedList, list: ListTag, idx: Idx) void {
//                 const disconn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, idx, idx, list);
//                 Internal.connect(disconn.left, disconn.right);
//                 Internal.decrease_link_set_count(self, list, 1);
//             }

//             pub fn disconnect_many_first_last(self: *LinkedList, list: ListTag, first_idx: Idx, last_idx: Idx, count: Idx) void {
//                 const disconn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, first_idx, last_idx, list);
//                 Internal.connect(disconn.left, disconn.right);
//                 Internal.decrease_link_set_count(self, list, count);
//             }

//             pub inline fn connect_with_insert(left_edge: ConnLeft, first_insert: ConnRight, last_insert: ConnLeft, right_edge: ConnRight) void {
//                 if (FORWARD) {
//                     if (BIDIRECTION) {
//                         left_edge.idx_ptr.* = first_insert.idx;
//                         last_insert.idx_ptr.* = right_edge.idx;
//                     } else {
//                         left_edge.* = first_insert;
//                         last_insert.* = right_edge;
//                     }
//                 }
//                 if (BACKWARD) {
//                     if (BIDIRECTION) {
//                         right_edge.idx_ptr.* = last_insert.idx;
//                         first_insert.idx_ptr.* = left_edge.idx;
//                     } else {
//                         right_edge.* = last_insert;
//                         first_insert.* = left_edge;
//                     }
//                 }
//             }

//             pub inline fn connect(left_edge: ConnLeft, right_edge: ConnRight) void {
//                 if (FORWARD) {
//                     if (BIDIRECTION) {
//                         left_edge.idx_ptr.* = right_edge.idx;
//                     } else {
//                         left_edge.* = right_edge;
//                     }
//                 }
//                 if (BACKWARD) {
//                     if (BIDIRECTION) {
//                         right_edge.idx_ptr.* = left_edge.idx;
//                     } else {
//                         right_edge.* = left_edge;
//                     }
//                 }
//             }

//             pub inline fn get_conn_left(self: *LinkedList, list: ListTag, left_idx: Idx, idx_on_same_list: Idx) ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or FORWARD) {
//                     if (left_idx == NULL_IDX) {
//                         if (list == UNTRACKED_LIST) {
//                             if (PARENT and FIRST_CHILD and (left_idx != NULL_IDX or idx_on_same_list != NULL_IDX)) {
//                                 const parent_idx = if (left_idx != NULL_IDX) self.get_parent_idx(left_idx) else self.get_parent_idx(idx_on_same_list);
//                                 if (parent_idx != NULL_IDX) {
//                                     conn.idx_ptr = &@field(self.get_ptr(parent_idx), FIRST_CHILD_FIELD);
//                                 } else {
//                                     conn.idx_ptr = &DUMMY_IDX;
//                                 }
//                             } else {
//                                 conn.idx_ptr = &DUMMY_IDX;
//                             }
//                         } else {
//                             conn.idx_ptr = &self.lists[@intFromEnum(list)].first_idx;
//                         }
//                     } else {
//                         conn.idx_ptr = &@field(get_ptr(self, left_idx), NEXT_FIELD);
//                     }
//                 }
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx = left_idx;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_left_from_first_child(self: *LinkedList, parent_idx: Idx) ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx_ptr = &@field(get_ptr(self, parent_idx), FIRST_CHILD_FIELD);
//                 }
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_left_from_list_head(self: *LinkedList, list: ListTag) ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx_ptr = &self.lists[@intFromEnum(list)].first_idx;
//                 }
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_left_dummy_end() ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx_ptr = &DUMMY_IDX;
//                 }
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_left_valid_index(self: *LinkedList, left_idx: Idx) ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx_ptr = &@field(get_ptr(self, left_idx), NEXT_FIELD);
//                 }
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx = left_idx;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_right(self: *LinkedList, list: ListTag, right_idx: Idx, idx_on_same_list: Idx) ConnLeft {
//                 var conn: ConnLeft = undefined;
//                 if (BIDIRECTION or BACKWARD) {
//                     if (right_idx == NULL_IDX) {
//                         if (list == UNTRACKED_LIST) {
//                             if (PARENT and LAST_CHILD and (right_idx != NULL_IDX or idx_on_same_list != NULL_IDX)) {
//                                 const parent_idx = if (right_idx != NULL_IDX) self.get_parent_idx(right_idx) else self.get_parent_idx(idx_on_same_list);
//                                 if (parent_idx != NULL_IDX) {
//                                     conn.idx_ptr = &@field(self.get_ptr(parent_idx), LAST_CHILD_FIELD);
//                                 } else {
//                                     conn.idx_ptr = &DUMMY_IDX;
//                                 }
//                             } else {
//                                 conn.idx_ptr = &DUMMY_IDX;
//                             }
//                         } else {
//                             conn.idx_ptr = &self.lists[@intFromEnum(list)].last_idx;
//                         }
//                     } else {
//                         conn.idx_ptr = &@field(get_ptr(self, right_idx), PREV_FIELD);
//                     }
//                 }
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx = right_idx;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_right_from_last_child(self: *LinkedList, parent_idx: Idx) ConnRight {
//                 var conn: ConnRight = undefined;
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx_ptr = &@field(get_ptr(self, parent_idx), LAST_CHILD_FIELD);
//                 }
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_right_from_list_tail(self: *LinkedList, list: ListTag) ConnRight {
//                 var conn: ConnRight = undefined;
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx_ptr = &self.lists[@intFromEnum(list)].last_idx;
//                 }
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_right_dummy_end() ConnRight {
//                 var conn: ConnRight = undefined;
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx_ptr = &DUMMY_IDX;
//                 }
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx = NULL_IDX;
//                 }
//                 return conn;
//             }

//             pub inline fn get_conn_right_valid_index(self: *LinkedList, right_idx: Idx) ConnRight {
//                 var conn: ConnRight = undefined;
//                 if (BIDIRECTION or BACKWARD) {
//                     conn.idx_ptr = &@field(get_ptr(self, right_idx), PREV_FIELD);
//                 }
//                 if (BIDIRECTION or FORWARD) {
//                     conn.idx = right_idx;
//                 }
//                 return conn;
//             }

//             pub fn get_conn_left_right_directly_before_this_valid_index(self: *LinkedList, this_idx: Idx, list: ListTag) ConnLeftRight {
//                 var result: ConnLeftRight = undefined;
//                 const prev_idx = self.get_prev_idx(this_idx);
//                 result.right = Internal.get_conn_right_valid_index(self, this_idx);
//                 result.left = Internal.get_conn_left(self, list, prev_idx, this_idx);
//                 return result;
//             }

//             pub fn get_conn_left_right_from_first_child_position(self: *LinkedList, parent_idx: Idx) ConnLeftRight {
//                 var result: ConnLeftRight = undefined;
//                 result.left = Internal.get_conn_left_from_first_child(self, parent_idx);
//                 const first_child_idx = self.get_first_child(parent_idx);
//                 if (first_child_idx != NULL_IDX) {
//                     result.right = Internal.get_conn_right_valid_index(self, first_child_idx);
//                 } else if (LAST_CHILD) {
//                     result.right = Internal.get_conn_right_from_last_child(self, parent_idx);
//                 } else {
//                     result.right = Internal.get_conn_right_dummy_end();
//                 }
//                 return result;
//             }

//             pub fn get_conn_left_right_from_last_child_position(self: *LinkedList, parent_idx: Idx) ConnLeftRight {
//                 var result: ConnLeftRight = undefined;
//                 result.right = Internal.get_conn_right_from_last_child(self, parent_idx);
//                 const last_child_idx = self.get_last_child(parent_idx);
//                 if (last_child_idx != NULL_IDX) {
//                     result.left = Internal.get_conn_left_valid_index(self, last_child_idx);
//                 } else if (FIRST_CHILD) {
//                     result.left = Internal.get_conn_left_from_first_child(self, parent_idx);
//                 } else {
//                     result.left = Internal.get_conn_left_dummy_end();
//                 }
//                 return result;
//             }

//             pub fn get_conn_left_right_directly_after_this_valid_index(self: *LinkedList, this_idx: Idx, list: ListTag) ConnLeftRight {
//                 var result: ConnLeftRight = undefined;
//                 const next_idx = self.get_next_idx(this_idx);
//                 result.left = Internal.get_conn_left_valid_index(self, this_idx);
//                 result.right = Internal.get_conn_right(self, list, next_idx, this_idx);
//                 return result;
//             }

//             pub fn get_conn_left_right_before_first_and_after_last_valid_indexes(self: *LinkedList, first_idx: Idx, last_idx: Idx, list: ListTag) ConnLeftRight {
//                 var result: ConnLeftRight = undefined;
//                 const left_idx = self.get_prev_idx(list, first_idx);
//                 const right_idx = self.get_next_idx(list, last_idx);
//                 result.left = Internal.get_conn_left(self, list, left_idx, first_idx);
//                 result.right = Internal.get_conn_right(self, list, right_idx, last_idx);
//                 return result;
//             }

//             pub fn get_conn_left_right_for_tail_of_list(self: *LinkedList, list: ListTag) ConnLeftRight {
//                 const last_index = self.get_last_index_in_list(list);
//                 var conn: ConnLeftRight = undefined;
//                 conn.right = Internal.get_conn_right_from_list_tail(self, list);
//                 if (last_index != NULL_IDX) {
//                     conn.left = Internal.get_conn_left_valid_index(self, last_index);
//                 } else {
//                     conn.left = Internal.get_conn_left_from_list_head(self, list);
//                 }
//                 return conn;
//             }

//             pub fn get_conn_left_right_for_head_of_list(self: *LinkedList, list: ListTag) ConnLeftRight {
//                 const first_index = self.get_first_index_in_list(list);
//                 var conn: ConnLeftRight = undefined;
//                 conn.left = Internal.get_conn_left_from_list_head(self, list);
//                 if (first_index != NULL_IDX) {
//                     conn.right = Internal.get_conn_right_valid_index(self, first_index);
//                 } else {
//                     conn.right = Internal.get_conn_right_from_list_tail(self, list);
//                 }
//                 return conn;
//             }

//             pub fn traverse_backward_to_get_first_index_in_list_from_start_index(self: *const LinkedList, start_idx: Idx) Idx {
//                 var first_idx: Idx = NULL_IDX;
//                 var curr_idx = start_idx;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (curr_idx != NULL_IDX) {
//                     first_idx = curr_idx;
//                     if (STRONG_ASSERT) c += 1;
//                     curr_idx = get_prev_idx(self, curr_idx.ptr);
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in backward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx });
//                 return first_idx;
//             }

//             pub fn traverse_forward_to_get_last_index_in_list_from_start_index(self: *const LinkedList, start_idx: Idx) Idx {
//                 var last_idx: Idx = NULL_IDX;
//                 var curr_idx = start_idx;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (curr_idx != NULL_IDX) {
//                     last_idx = curr_idx;
//                     if (STRONG_ASSERT) c += 1;
//                     curr_idx = get_next_idx(self, curr_idx.ptr);
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx });
//                 return last_idx;
//             }

//             pub fn traverse_forward_from_idx_and_report_if_found_target_idx(self: *LinkedList, start_idx: Idx, target_idx: Idx) bool {
//                 var curr_idx: Idx = start_idx;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     if (curr_idx == target_idx) return true;
//                     curr_idx = get_next_idx(self, curr_idx);
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding target index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, target_idx });
//                 return false;
//             }

//             pub fn traverse_all_lists_forward_and_report_list_found_in(self: *LinkedList, this_idx: Idx) ListTag {
//                 var t: ListTagInt = 0;
//                 var idx: Idx = undefined;
//                 while (t < UNTRACKED_LIST_RAW) : (t += 1) {
//                     idx = self.get_first_index_in_list(@enumFromInt(t));
//                     while (idx != NULL_IDX) {
//                         if (idx == this_idx) return @enumFromInt(t);
//                         idx = self.get_next_idx(idx);
//                     }
//                 }
//                 return UNTRACKED_LIST;
//             }
//             pub fn traverse_all_lists_backward_and_report_list_found_in(self: *LinkedList, this_idx: Idx) ListTag {
//                 var t: ListTagInt = 0;
//                 var idx: Idx = undefined;
//                 while (t < UNTRACKED_LIST_RAW) : (t += 1) {
//                     idx = self.get_last_index_in_list(@enumFromInt(t));
//                     while (idx != NULL_IDX) {
//                         if (idx == this_idx) return @enumFromInt(t);
//                         idx = self.get_prev_idx(idx);
//                     }
//                 }
//                 return UNTRACKED_LIST;
//             }

//             pub fn traverse_backward_from_idx_and_report_if_found_target_idx(self: *LinkedList, start_idx: Idx, target_idx: Idx) bool {
//                 var curr_idx: Idx = start_idx;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     if (curr_idx == target_idx) return true;
//                     curr_idx = get_prev_idx(self, curr_idx);
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in forward direction without finding target index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, start_idx, target_idx });
//                 return false;
//             }

//             pub fn traverse_to_find_index_before_this_one_forward_from_known_idx_before(self: LinkedList, this_idx: Idx, known_prev: Idx) Idx {
//                 var curr_idx: Idx = known_prev;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     assert_with_reason(curr_idx < self.list.len, @src(), "while traversing forward from index {d}, index {d} was found, which is out of bounds for list.len {d}, but is not NULL_IDX", .{ known_prev, curr_idx, self.list.len });
//                     const next_idx = self.get_next_idx(curr_idx);
//                     if (next_idx == this_idx) return curr_idx;
//                     curr_idx = next_idx;
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from 'known prev' index {d} in forward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, known_prev, this_idx });
//                 assert_with_reason(false, @src(), "no item found referencing index {d} while traversing from index {d} in forward direction: broken list or `known_prev` wasn't actually before `idx`", .{ this_idx, known_prev });
//             }

//             pub fn traverse_to_find_index_after_this_one_backward_from_known_idx_after(self: LinkedList, this_idx: Idx, known_next: Idx) Idx {
//                 var curr_idx: Idx = undefined;
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 curr_idx = known_next;
//                 while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                     assert_with_reason(curr_idx < self.list.len, @src(), "while traversing backward from index {d}, index {d} was found, which is out of bounds for list.len {d}, but is not NULL_IDX", .{ known_next, curr_idx, self.list.len });
//                     const prev_idx = self.get_prev_idx(curr_idx);
//                     if (prev_idx == this_idx) return curr_idx;
//                     curr_idx = prev_idx;
//                     if (STRONG_ASSERT) c += 1;
//                 }
//                 if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) starting from 'known next' index {d} in backward direction without finding this index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, known_next, this_idx });
//                 assert_with_reason(false, @src(), "no item found referencing index {d} while traversing from index {d} in backward direction: broken list or `known_next` wasn't actually after `idx`", .{ this_idx, known_next });
//             }

//             pub inline fn get_list_tag_raw(ptr: *const Elem) ListTagInt {
//                 return @as(ListTagInt, @intCast((@field(ptr, STATE_FIELD) & STATE_MASK) >> STATE_OFFSET));
//             }

//             pub fn assert_valid_list_idx(self: *LinkedList, idx: Idx, list: ListTag, comptime src_loc: ?SourceLocation) void {
//                 if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
//                     assert_idx_less_than_len(idx, self.list.len, src_loc);
//                     const ptr = get_ptr(self, idx);
//                     if (STATE) assert_with_reason(get_list_tag_raw(ptr) == @intFromEnum(list), src_loc, "set {s} on SetIdx does not match list on elem at idx {d}", .{ @tagName(list), idx });
//                     if (STRONG_ASSERT) {
//                         const found_in_list = if (FORWARD) Internal.traverse_forward_from_idx_and_report_if_found_target_idx(self, self.get_first_index_in_list(list), idx) else Internal.traverse_backward_from_idx_and_report_if_found_target_idx(self, self.get_last_index_in_list(list), idx);
//                         assert_with_reason(found_in_list, src_loc, "while verifying idx {d} is in set {s}, the idx was not found when traversing the set", .{ idx, @tagName(list) });
//                     }
//                 }
//             }
//             pub fn assert_valid_list_idx_list(self: *LinkedList, list: ListTag, indexes: []const Idx, comptime src_loc: ?SourceLocation) void {
//                 if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
//                     for (indexes) |idx| {
//                         Internal.assert_valid_list_idx(self, idx, list, src_loc);
//                     }
//                 }
//             }
//             pub fn assert_valid_list_of_list_idxs(self: *LinkedList, set_idx_list: []const ListIdx, comptime src_loc: ?SourceLocation) void {
//                 if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
//                     for (set_idx_list) |list_idx| {
//                         Internal.assert_valid_list_idx(self, list_idx.idx, list_idx.list, src_loc);
//                     }
//                 }
//             }

//             pub fn assert_valid_slice(self: *LinkedList, slice: LLSlice, comptime src_loc: ?SourceLocation) void {
//                 assert_idx_less_than_len(slice.first, self.list.len, src_loc);
//                 assert_idx_less_than_len(slice.last, self.list.len, src_loc);
//                 if (!STRONG_ASSERT and STATE) {
//                     assert_with_reason(self.index_is_in_list(slice.first, slice.list), src_loc, "first index {d} is not in list `{s}`", .{ slice.first, @tagName(slice.list) });
//                     assert_with_reason(self.index_is_in_list(slice.last, slice.list), src_loc, "last index {d} is not in list `{s}`", .{ slice.last, @tagName(slice.list) });
//                 }
//                 if (STRONG_ASSERT) {
//                     var c: Idx = 1;
//                     var idx = if (FORWARD) slice.first else slice.last;
//                     assert_idx_less_than_len(idx, self.list.len, @src());
//                     const list = slice.list;
//                     const last_idx = if (FORWARD) slice.last else slice.first;
//                     Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
//                     while (idx != last_idx and idx != NULL_IDX) {
//                         idx = if (FORWARD) self.get_next_idx(slice.list, idx) else self.get_prev_idx(idx);
//                         c += 1;
//                         Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
//                     }
//                     assert_with_reason(idx == last_idx, src_loc, "idx `first` ({d}) is not linked with idx `last` ({d})", .{ slice.first, slice.last });
//                     assert_with_reason(c == slice.count, src_loc, "the slice count {d} did not match the number of traversed items between `first` and `last` ({d})", .{ slice.count, c });
//                 }
//             }

//             fn get_items_and_insert_at_internal(self: *LinkedList, get_from: anytype, insert_to: anytype, alloc: Allocator, comptime ASSUME_CAP: bool) if (!ASSUME_CAP and RETURN_ERRORS) Error!LLSlice else LLSlice {
//                 const FROM = @TypeOf(get_from);
//                 const TO = @TypeOf(insert_to);
//                 var insert_edges: ConnLeftRight = undefined;
//                 var insert_list: ListTag = undefined;
//                 var insert_untracked: bool = false;
//                 var insert_parent: Idx = NULL_IDX;
//                 switch (TO) {
//                     Insert.AfterIndex => {
//                         const idx: Idx = insert_to.idx;
//                         assert_idx_less_than_len(idx, self.list.len, @src());
//                         const list: ListTag = self.get_list_tag(idx);
//                         insert_edges = Internal.get_conn_left_right_directly_after_this_valid_index(self, idx, list);
//                         insert_list = list;
//                         insert_parent = self.get_parent_idx(idx);
//                     },
//                     Insert.AfterIndexInList => {
//                         const idx: Idx = insert_to.idx;
//                         const list: Idx = insert_to.list;
//                         assert_valid_list_idx(self, idx, list, @src());
//                         insert_edges = Internal.get_conn_left_right_directly_after_this_valid_index(self, idx, list);
//                         insert_list = list;
//                         insert_parent = self.get_parent_idx(idx);
//                     },
//                     Insert.BeforeIndex => {
//                         const idx: Idx = insert_to.idx;
//                         assert_idx_less_than_len(idx, self.list.len, @src());
//                         const list: ListTag = self.get_list_tag(idx);
//                         insert_edges = Internal.get_conn_left_right_directly_before_this_valid_index(self, idx, list);
//                         insert_list = list;
//                         insert_parent = self.get_parent_idx(idx);
//                     },
//                     Insert.BeforeIndexInList => {
//                         const idx: Idx = insert_to.idx;
//                         const list: Idx = insert_to.list;
//                         assert_valid_list_idx(self, idx, list, @src());
//                         insert_edges = Internal.get_conn_left_right_directly_before_this_valid_index(self, idx, list);
//                         insert_list = list;
//                         insert_parent = self.get_parent_idx(idx);
//                     },
//                     Insert.AtBeginningOfList => {
//                         const list: ListTag = insert_to.list;
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot insert to beginning of the 'untracked' list (it has no begining or end)", .{});
//                         insert_edges = Internal.get_conn_left_right_for_head_of_list(self, list);
//                         insert_list = list;
//                     },
//                     Insert.AtEndOfList => {
//                         const list: ListTag = insert_to.list;
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot insert to end of the 'untracked' list (it has no begining or end)", .{});
//                         insert_edges = Internal.get_conn_left_right_for_tail_of_list(self, list);
//                         insert_list = list;
//                     },
//                     Insert.AtBeginningOfChildren => {
//                         assert_with_reason(FIRST_CHILD or (LAST_CHILD and BACKWARD), @src(), "cannot insert at beginning of children when items do not cache either the first child index, or last child index and is also linked in backward direction", .{});
//                         const parent_idx: Idx = insert_to.parent_idx;
//                         assert_idx_less_than_len(parent_idx, self.list.len, @src());
//                         insert_parent = parent_idx;
//                         if (FIRST_CHILD) {
//                             insert_edges = Internal.get_conn_left_right_from_first_child_position(self, parent_idx);
//                             insert_list = UNTRACKED_LIST;
//                         } else {
//                             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks not allowed", .{});
//                             const last_child_idx = self.get_last_child(parent_idx);
//                             const first_child_idx = Internal.traverse_backward_to_get_first_index_in_list_from_start_index(self, last_child_idx);
//                             insert_edges.left = Internal.get_conn_left_dummy_end();
//                             insert_edges.right = if (first_child_idx != NULL_IDX) Internal.get_conn_right_valid_index(self, first_child_idx) else Internal.get_conn_right_from_last_child(self, parent_idx);
//                             insert_list = UNTRACKED_LIST;
//                         }
//                     },
//                     Insert.AtEndOfChildren => {
//                         assert_with_reason(LAST_CHILD or (FIRST_CHILD and FORWARD), @src(), "cannot insert children when items do not cache either the first child index, or last child index and is also linked in backward direction", .{});
//                         const parent_idx: Idx = insert_to.parent_idx;
//                         assert_idx_less_than_len(parent_idx, self.list.len, @src());
//                         insert_parent = parent_idx;
//                         if (LAST_CHILD) {
//                             insert_edges = Internal.get_conn_left_right_from_last_child_position(self, parent_idx);
//                             insert_list = UNTRACKED_LIST;
//                         } else {
//                             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks not allowed", .{});
//                             const first_child_idx = self.get_first_child(parent_idx);
//                             const last_child_idx = Internal.traverse_forward_to_get_last_index_in_list_from_start_index(self, first_child_idx);
//                             insert_edges.right = Internal.get_conn_right_dummy_end();
//                             insert_edges.left = if (last_child_idx != NULL_IDX) Internal.get_conn_left_valid_index(self, last_child_idx) else Internal.get_conn_left_from_first_child(self, parent_idx);
//                             insert_list = UNTRACKED_LIST;
//                         }
//                     },
//                     Insert.Untracked => {
//                         insert_list = UNTRACKED_LIST;
//                         insert_untracked = true;
//                     },
//                     else => assert_with_reason(false, @src(), "invalid type `{s}` input for parameter `insert_to`. All valid input types are contained in `Insert`", .{@typeName(TO)}),
//                 }
//                 var return_items: LLSlice = undefined;
//                 switch (FROM) {
//                     Get.CreateOneNew => {
//                         const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
//                         return_items.first = new_idx;
//                         return_items.last = new_idx;
//                         return_items.count = 1;
//                     },
//                     Get.FirstFromList, Get.FirstFromListElseCreateNew => {
//                         const list: ListTag = get_from.list;
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
//                         const list_count: debug_switch(Idx, void) = debug_switch(self.get_list_len(list), void{});
//                         const first_idx = self.get_first_index_in_list(list);
//                         if (FROM == Get.FirstFromListElseCreateNew and (debug_switch(list_count == 0, false) or first_idx == NULL_IDX)) {
//                             const new_idx = self.list.len;
//                             _ = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
//                             return_items.first = new_idx;
//                             return_items.last = new_idx;
//                             return_items.count = 1;
//                         } else {
//                             assert_with_reason(debug_switch(list_count > 0, true) and first_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), first_idx, self.list.len });
//                             return_items.first = first_idx;
//                             return_items.last = first_idx;
//                             return_items.count = 1;
//                             Internal.disconnect_one(self, list, first_idx);
//                         }
//                     },
//                     Get.LastFromList, Get.LastFromListElseCreateNew => {
//                         const list: ListTag = get_from.list;
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
//                         const list_count: debug_switch(Idx, void) = debug_switch(self.get_list_len(list), void{});
//                         const last_idx = self.get_last_index_in_list(list);
//                         if (FROM == Get.LastFromListElseCreateNew and (debug_switch(list_count == 0, false) or last_idx == NULL_IDX)) {
//                             const new_idx = self.list.len;
//                             _ = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
//                             return_items.first = new_idx;
//                             return_items.last = new_idx;
//                             return_items.count = 1;
//                         } else {
//                             assert_with_reason(debug_switch(list_count > 0, true) and last_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), last_idx, self.list.len });
//                             return_items.first = last_idx;
//                             return_items.last = last_idx;
//                             return_items.count = 1;
//                             Internal.disconnect_one(self, list, last_idx);
//                         }
//                     },
//                     Get.OneIndex => {
//                         const idx: Idx = get_from.idx;
//                         assert_idx_less_than_len(idx, self.list.len, @src());
//                         const list: ListTag = self.get_list_tag(idx);
//                         return_items.first = idx;
//                         return_items.last = idx;
//                         return_items.count = 1;
//                         Internal.disconnect_one(self, list, idx);
//                     },
//                     Get.OneIndexInList => {
//                         const idx: Idx = get_from.idx;
//                         const list: ListTag = get_from.list;
//                         assert_valid_list_idx(self, idx, list, @src());
//                         return_items.first = idx;
//                         return_items.last = idx;
//                         return_items.count = 1;
//                         Internal.disconnect_one(self, list, idx);
//                     },
//                     Get.CreateManyNew => {
//                         const count: Idx = get_from.count;
//                         assert_with_reason(count > 0, @src(), "cannot create `0` new items", .{});
//                         const first_idx = self.list.len;
//                         const last_idx = self.list.len + count - 1;
//                         _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count) else (if (RETURN_ERRORS) try self.list.append_many_slots(count, alloc) else self.list.append_many_slots(count, alloc));
//                         Internal.initialize_concurrent_indexes(self, first_idx, last_idx, true, false, insert_list, false, NULL_IDX);
//                         return_items.first = first_idx;
//                         return_items.last = last_idx;
//                         return_items.count = count;
//                     },
//                     Get.FirstCountFromList => {
//                         const list: ListTag = get_from.list;
//                         const count: Idx = get_from.count;
//                         assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
//                         assert_with_reason(self.get_list_len(list) >= count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ count, @tagName(list), self.get_list_len(list) });
//                         return_items.first = self.get_first_index_in_list(list);
//                         return_items.last = self.get_nth_index_from_start_of_list(list, count - 1);
//                         return_items.count = count;
//                         Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count);
//                     },
//                     Get.LastCountFromList => {
//                         const list: ListTag = get_from.list;
//                         const count: Idx = get_from.count;
//                         assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
//                         assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot get items from the 'untracked' list without specific indexes", .{});
//                         assert_with_reason(self.get_list_len(list) >= count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ count, @tagName(list), self.get_list_len(list) });
//                         return_items.last = self.get_last_index_in_list(list);
//                         return_items.first = self.get_nth_index_from_end_of_list(list, count - 1);
//                         return_items.count = count;
//                         Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count);
//                     },
//                     Get.FirstCountFromListElseCreateNew => {
//                         const list: ListTag = get_from.list;
//                         const count: Idx = get_from.count;
//                         assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
//                         const count_from_list = @min(self.get_list_len(list), count);
//                         const count_from_new = count - count_from_list;
//                         var first_new_idx: Idx = undefined;
//                         var last_moved_idx: Idx = undefined;
//                         const needs_new = count_from_new > 0;
//                         const needs_move = count_from_list > 0;
//                         if (needs_new) {
//                             first_new_idx = self.list.len;
//                             const last_new_idx = self.list.len + count_from_new - 1;
//                             _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
//                             Internal.initialize_concurrent_indexes(self, first_new_idx, last_new_idx, true, false, insert_list, false, NULL_IDX);
//                             if (needs_move) {
//                                 first_new_idx = first_new_idx;
//                             } else {
//                                 return_items.first = first_new_idx;
//                             }
//                             return_items.last = last_new_idx;
//                         }
//                         if (needs_move) {
//                             return_items.first = self.get_first_index_in_list(list);
//                             if (needs_new) {
//                                 last_moved_idx = self.get_nth_index_from_start_of_list(list, count_from_list - 1);
//                                 Internal.disconnect_many_first_last(self, list, return_items.first, last_moved_idx, count_from_list);
//                             } else {
//                                 return_items.last = self.get_nth_index_from_start_of_list(list, count_from_list - 1);
//                                 Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count_from_list);
//                             }
//                         }
//                         if (needs_new and needs_move) {
//                             const mid_conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, last_moved_idx, first_new_idx, list);
//                             Internal.connect(mid_conn.left, mid_conn.right);
//                         }
//                         return_items.count = count;
//                     },
//                     Get.LastCountFromListElseCreateNew => {
//                         const list: ListTag = get_from.list;
//                         const count: Idx = get_from.count;
//                         assert_with_reason(count > 0, @src(), "cannot get `0` items", .{});
//                         const count_from_list = @min(self.get_list_len(list), count);
//                         const count_from_new = count - count_from_list;
//                         var first_new_idx: Idx = undefined;
//                         var last_moved_idx: Idx = undefined;
//                         const needs_new = count_from_new > 0;
//                         const needs_move = count_from_list > 0;
//                         if (needs_new) {
//                             first_new_idx = self.list.len;
//                             const last_new_idx = self.list.len + count_from_new - 1;
//                             _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
//                             Internal.initialize_concurrent_indexes(self, first_new_idx, last_new_idx, true, false, insert_list, false, NULL_IDX);
//                             if (needs_move) {
//                                 first_new_idx = first_new_idx;
//                             } else {
//                                 return_items.first = first_new_idx;
//                             }
//                             return_items.last = last_new_idx;
//                         }
//                         if (needs_move) {
//                             return_items.first = self.get_nth_index_from_end_of_list(list, count_from_list - 1);
//                             if (needs_new) {
//                                 last_moved_idx = self.get_last_index_in_list(list);
//                                 Internal.disconnect_many_first_last(self, list, return_items.first, last_moved_idx, count_from_list);
//                             } else {
//                                 return_items.last = self.get_last_index_in_list(list);
//                                 Internal.disconnect_many_first_last(self, list, return_items.first, return_items.last, count_from_list);
//                             }
//                         }
//                         if (needs_new and needs_move) {
//                             const mid_conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, last_moved_idx, first_new_idx, list);
//                             Internal.connect(mid_conn.left, mid_conn.right);
//                         }
//                         return_items.count = count;
//                     },
//                     Get.SparseIndexesFromSameList => {
//                         const list: ListTag = get_from.list;
//                         const indexes: []const Idx = get_from.indexes;
//                         Internal.assert_valid_list_idx_list(self, list, indexes, @src());
//                         return_items.first = indexes[0];
//                         Internal.disconnect_one(self, list, return_items.first);
//                         var prev_idx: Idx = return_items.first;
//                         for (indexes[1..]) |this_idx| {
//                             const conn = Internal.get_conn_left_right_before_first_and_after_last_valid_indexes(self, prev_idx, this_idx, list);
//                             Internal.disconnect_one(self, list, this_idx);
//                             Internal.connect(conn.left, conn.right);
//                             prev_idx = this_idx;
//                         }
//                         return_items.last = prev_idx;
//                         return_items.count = @intCast(indexes.len);
//                     },
//                     Get.SparseIndexes => {
//                         const indexes: []const Idx = get_from.indexes;
//                         assert_with_reason(indexes.len > 0, @src(), "cannot get 0 items", .{});
//                         assert_idx_less_than_len(indexes[0], self.list.len, @src());
//                         var list = self.get_list_tag(indexes[0]);
//                         Internal.disconnect_one(self, list, indexes[0]);
//                         return_items.first = indexes[0];
//                         var prev_idx = indexes[0];
//                         for (indexes[1..]) |idx| {
//                             assert_idx_less_than_len(idx, self.list.len, @src());
//                             list = self.get_list_tag(idx);
//                             const conn_left = Internal.get_conn_left(self, list, prev_idx, idx);
//                             const conn_right = Internal.get_conn_right(self, list, idx, prev_idx);
//                             Internal.disconnect_one(self, list, idx);
//                             Internal.connect(conn_left, conn_right);
//                             prev_idx = idx;
//                         }
//                         return_items.last = prev_idx;
//                         return_items.count = @intCast(indexes.len);
//                     },
//                     Get.SparseIndexesFromAnyList => {
//                         const indexes: []const ListIdx = get_from.indexes;
//                         Internal.assert_valid_list_of_list_idxs(self, indexes, @src());
//                         return_items.first = indexes[0].idx;
//                         Internal.disconnect_one(self, indexes[0].list, return_items.first);
//                         var prev_idx: Idx = return_items.first;
//                         for (indexes[1..]) |list_idx| {
//                             const this_idx = list_idx.idx;
//                             Internal.disconnect_one(self, list_idx.list, this_idx);
//                             const conn_left = Internal.get_conn_left(self, list_idx.list, prev_idx);
//                             const conn_right = Internal.get_conn_right(self, list_idx.list, this_idx);
//                             Internal.connect(conn_left, conn_right);
//                             prev_idx = this_idx;
//                         }
//                         return_items.last = prev_idx;
//                         return_items.count = @intCast(indexes.len);
//                     },
//                     //CHECKPOINT
//                     .FROM_SLICE => {
//                         const slice: LLSlice = get_val;
//                         Internal.assert_valid_slice(self, slice, @src());
//                         return_items.first = slice.first;
//                         return_items.last = slice.last;
//                         return_items.count = slice.count;
//                     },
//                     .FROM_SLICE_ELSE_CREATE_NEW => {
//                         const supp_slice: LLSliceWithTotalNeeded = get_val;
//                         Internal.assert_valid_slice(self, supp_slice.slice, @src());
//                         const count_from_slice = @min(supp_slice.slice.count, supp_slice.total_needed);
//                         const count_from_new = supp_slice.total_needed - count_from_slice;
//                         var first_new_idx: Idx = undefined;
//                         var last_moved_idx: Idx = undefined;
//                         const needs_new = count_from_new > 0;
//                         const needs_move = count_from_slice > 0;
//                         if (needs_new) {
//                             first_new_idx = self.list.len;
//                             const last_new_idx = self.list.len + count_from_new - 1;
//                             _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
//                             Internal.initialize_new_indexes(self, supp_slice.slice.list, first_new_idx, last_new_idx);
//                             if (needs_move) {
//                                 first_new_idx = first_new_idx;
//                             } else {
//                                 return_items.first = first_new_idx;
//                             }
//                             return_items.last = last_new_idx;
//                         }
//                         if (needs_move) {
//                             return_items.first = supp_slice.slice.first;
//                             if (needs_new) {
//                                 last_moved_idx = supp_slice.slice.last;
//                             } else {
//                                 return_items.last = supp_slice.slice.last;
//                             }
//                             Internal.disconnect_many_first_last(self, supp_slice.slice.list, supp_slice.slice.first, supp_slice.slice.last, count_from_slice);
//                         }
//                         if (needs_new and needs_move) {
//                             const mid_left = Internal.get_conn_left(self, supp_slice.slice.list, last_moved_idx);
//                             const mid_right = Internal.get_conn_right(self, supp_slice.slice.list, first_new_idx);
//                             Internal.connect(mid_left, mid_right);
//                         }
//                         return_items.count = supp_slice.total_needed;
//                     },
//                 }
//                 const insert_first = Internal.get_conn_right(self, insert_list, return_items.first);
//                 const insert_last = Internal.get_conn_left(self, insert_list, return_items.last);
//                 Internal.connect_with_insert(insert_edges.left, insert_first, insert_last, insert_edges.right);
//                 Internal.increase_link_set_count(self, insert_list, return_items.count);
//                 Internal.set_list_on_indexes_first_last(self, return_items.first, return_items.last, insert_list);
//                 return_items.list = insert_list;
//                 return return_items;
//             }

//             fn iter_peek_prev_or_null(self: *anyopaque) ?*Elem {
//                 if (!BACKWARD) return false;
//                 const iter: *IteratorState = @ptrCast(@alignCast(self));
//                 if (iter.left_idx == NULL_IDX) return null;
//                 return iter.linked_list.get_ptr(iter.left_idx);
//             }
//             fn iter_advance_prev(self: *anyopaque) bool {
//                 if (!BACKWARD) return false;
//                 const iter: *IteratorState = @ptrCast(@alignCast(self));
//                 if (iter.left_idx == NULL_IDX) return false;
//                 iter.right_idx = iter.left_idx;
//                 iter.left_idx = iter.linked_list.get_prev_idx(iter.list, iter.left_idx);
//                 return true;
//             }
//             fn iter_peek_next_or_null(self: *anyopaque) ?*Elem {
//                 if (!FORWARD) return false;
//                 const iter: *IteratorState = @ptrCast(@alignCast(self));
//                 if (iter.right_idx == NULL_IDX) return null;
//                 return iter.linked_list.get_ptr(iter.right_idx);
//             }
//             fn iter_advance_next(self: *anyopaque) bool {
//                 if (!FORWARD) return false;
//                 const iter: *IteratorState = @ptrCast(@alignCast(self));
//                 if (iter.right_idx == NULL_IDX) return false;
//                 iter.left_idx = iter.right_idx;
//                 iter.right_idx = iter.linked_list.get_next_idx(iter.list, iter.right_idx);
//                 return true;
//             }
//             fn iter_reset(self: *anyopaque) bool {
//                 const iter: *IteratorState = @ptrCast(@alignCast(self));
//                 if (FORWARD) {
//                     iter.right_idx = iter.linked_list.get_first_index_in_list(iter.list);
//                     iter.left_idx = NULL_IDX;
//                 } else {
//                     iter.left_idx = iter.linked_list.get_last_index_in_list(iter.list);
//                     iter.right_idx = NULL_IDX;
//                 }
//                 return true;
//             }

//             pub fn traverse_to_find_what_list_idx_is_in(self: *LinkedList, idx: Idx) ListTag {
//                 var c: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) 0 else void{};
//                 const limit: if (STRONG_ASSERT) Idx else void = if (STRONG_ASSERT) @as(Idx, @intCast(self.list.len)) else void{};
//                 if ((FORWARD and TAIL) or (BACKWARD and HEAD)) {
//                     var left_idx: Idx = idx;
//                     var right_idx: Idx = idx;
//                     while (if (STRONG_ASSERT) c <= limit else true) {
//                         if (BACKWARD and HEAD) {
//                             const next_left = self.get_prev_idx(left_idx);
//                             if (left_idx != NULL_IDX) {
//                                 left_idx = next_left;
//                             } else {
//                                 for (self.lists, 0..) |list, tag_raw| {
//                                     if (list.first_idx == left_idx) return @enumFromInt(@as(ListTagInt, @intCast(tag_raw)));
//                                 }
//                                 return UNTRACKED_LIST;
//                             }
//                         }
//                         if (FORWARD and TAIL) {
//                             const next_right = self.get_next_idx(left_idx);
//                             if (right_idx != NULL_IDX) {
//                                 right_idx = next_right;
//                             } else {
//                                 for (self.lists, 0..) |list, tag_raw| {
//                                     if (list.last_idx == left_idx) return @enumFromInt(@as(ListTagInt, @intCast(tag_raw)));
//                                 }
//                                 return UNTRACKED_LIST;
//                             }
//                         }
//                         if (STRONG_ASSERT) c += 1;
//                     }
//                     assert_with_reason(false, @src(), "traversed more than {d} elements (total len of underlying element list) starting from index {d} in either forward or backward direction without finding a NULL_IDX: list is cyclic and using this function will create an infinite loop", .{ limit, idx });
//                 } else {
//                     for (self.lists, 0..) |list, tag_raw| {
//                         const list_tag = @as(ListTag, @enumFromInt(@as(ListTagInt, @intCast(tag_raw))));
//                         if (FORWARD) {
//                             var curr_idx: Idx = self.get_first_index_in_list(list);
//                             while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                                 if (curr_idx == idx) return list_tag;
//                                 curr_idx = self.get_next_idx(curr_idx);
//                                 c += 1;
//                             }
//                         } else {
//                             var curr_idx: Idx = self.get_last_index_in_list(list);
//                             while (curr_idx != NULL_IDX and (if (STRONG_ASSERT) c <= limit else true)) {
//                                 if (curr_idx == idx) return list_tag;
//                                 curr_idx = self.get_next_idx(curr_idx);
//                                 c += 1;
//                             }
//                         }
//                     }
//                     if (STRONG_ASSERT) assert_with_reason(c <= limit, @src(), "traversed more than {d} elements (total len of underlying element list) through all lists without finding index {d}: list is cyclic and using this function will create an infinite loop", .{ limit, idx });
//                     return UNTRACKED_LIST;
//                 }
//             }

//             pub inline fn get_parent_idx(self: *const LinkedList, this_idx: Idx) Idx {
//                 assert_idx_less_than_len(this_idx, self.list.len, @src());
//                 if (PARENT) return @field(self.get_ptr(this_idx), PARENT_FIELD);
//                 return NULL_IDX;
//             }
//             pub inline fn get_first_child_idx_ref(self: *const LinkedList, this_idx: Idx) *Idx {
//                 assert_idx_less_than_len(this_idx, self.list.len, @src());
//                 assert_with_reason(FIRST_CHILD, @src(), "items do not cache their first child index", .{});
//                 return &@field(self.get_ptr(this_idx), FIRST_CHILD_FIELD);
//             }
//             pub inline fn get_last_child_idx_ref(self: *const LinkedList, this_idx: Idx) *Idx {
//                 assert_idx_less_than_len(this_idx, self.list.len, @src());
//                 assert_with_reason(LAST_CHILD, @src(), "items do not cache their last child index", .{});
//                 return &@field(self.get_ptr(this_idx), LAST_CHILD_FIELD);
//             }
//         };

//         pub const IteratorState = struct {
//             linked_list: *LinkedList,
//             list: ListTag,
//             left_idx: Idx,
//             right_idx: Idx,

//             pub fn iterator(self: *IteratorState) Iterator(Elem, true, true) {
//                 return Iterator(Elem, true, true){
//                     .implementor = @ptrCast(self),
//                     .vtable = Iterator(Elem).VTable{
//                         .reset = Internal.iter_reset,
//                         .advance_forward = Internal.iter_advance_next,
//                         .peek_next_or_null = Internal.iter_peek_next_or_null,
//                         .advance_prev = Internal.iter_advance_prev,
//                         .peek_prev_or_null = Internal.iter_peek_prev_or_null,
//                     },
//                 };
//             }
//         };

//         pub inline fn new_iterator_state_at_start_of_list(self: *LinkedList, list: ListTag) IteratorState {
//             return IteratorState{
//                 .linked_list = self,
//                 .list = list,
//                 .left_idx = NULL_IDX,
//                 .right_idx = if (HEAD) self.get_first_index_in_list(list) else NULL_IDX,
//             };
//         }
//         pub inline fn new_iterator_state_at_end_of_list(self: *LinkedList, list: ListTag) IteratorState {
//             return IteratorState{
//                 .linked_list = self,
//                 .list = list,
//                 .left_idx = if (TAIL) self.get_last_index_in_list(list) else NULL_IDX,
//                 .right_idx = NULL_IDX,
//             };
//         }

//         pub fn new_empty(assert_alloc: Allocator) LinkedList {
//             var uninit = UNINIT;
//             uninit.list = BaseList.new_empty(assert_alloc);
//             return uninit;
//         }

//         pub fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!LinkedList else LinkedList {
//             var self = UNINIT;
//             if (RETURN_ERRORS) {
//                 try self.list.ensure_total_capacity_exact(capacity, alloc);
//             } else {
//                 self.list.ensure_total_capacity_exact(capacity, alloc);
//             }
//             return self;
//         }

//         pub fn clone(self: *const LinkedList, alloc: Allocator) if (RETURN_ERRORS) Error!LinkedList else LinkedList {
//             var new_list = self.*;
//             new_list.list = if (RETURN_ERRORS) try self.list.clone(alloc) else self.list.clone(alloc);
//             return new_list;
//         }

//         pub inline fn get_list_len(self: *LinkedList, list: ListTag) Idx {
//             if (list == UNTRACKED_LIST) return 0;
//             return self.lists[@intFromEnum(list)].count;
//         }

//         pub inline fn get_ptr(self: *const LinkedList, idx: Idx) *Elem {
//             assert_idx_less_than_len(idx, self.list.len, @src());
//             return &self.list.ptr[idx];
//         }

//         pub fn get_prev_idx(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_idx_less_than_len(this_idx, self.lists.len, @src());
//             assert_with_reason(BACKWARD or STATE or (PARENT and FIRST_CHILD), @src(), "cannot use `get_prev_idx()`, provide an option for `backward_linkage` when defining a LinkedListManager or allow items to cache their own list, or use `get_prev_idx_fallback()` instead", .{});
//             if (BACKWARD) {
//                 const ptr = get_ptr(self, this_idx);
//                 return @field(ptr, PREV_FIELD);
//             }
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//             if (STATE) {
//                 const list = self.get_list_tag(this_idx);
//                 if (list != UNTRACKED_LIST) {
//                     const first_in_list = self.get_first_index_in_list(list);
//                     return Internal.traverse_to_find_index_before_this_one_forward_from_known_idx_before(self, this_idx, first_in_list);
//                 }
//             }
//             const parent_idx = self.get_parent_idx(this_idx);
//             assert_with_reason(PARENT and FIRST_CHILD and parent_idx != NULL_IDX, @src(), "cannot find a previous index if items arent linked in the backward direction OR items dont cache the list they belong to and are not in an 'untracked' list, OR they don't cache both their parent and first-child and their parent idx != NULL_IDX", .{});
//             const known_prev_idx = @field(self.get_ptr(parent_idx), FIRST_CHILD_FIELD);
//             assert_with_reason(known_prev_idx != NULL_IDX, @src(), "parent idx wasn't NULL_IDX, but parent ptr 'first child' field had a value of NULL_IDX, broken list", .{});
//             return Internal.traverse_to_find_index_before_this_one_forward_from_known_idx_before(self, this_idx, known_prev_idx);
//         }

//         pub inline fn get_prev_idx_fallback(self: *const LinkedList, this_idx: Idx, known_idx_before_this: Idx) Idx {
//             if (BACKWARD) return self.get_prev_idx(this_idx);
//             assert_idx_less_than_len(this_idx, self.list.len, @src());
//             assert_idx_less_than_len(known_idx_before_this, self.list.len, @src());
//             return Internal.traverse_to_find_index_before_this_one_forward_from_known_idx_before(self, this_idx, known_idx_before_this);
//         }

//         pub fn get_next_idx(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_idx_less_than_len(this_idx, self.lists.len, @src());
//             assert_with_reason(FORWARD or STATE or (PARENT and LAST_CHILD), @src(), "cannot use `get_next_idx()`, provide an option for `forward_linkage` when defining a LinkedListManager or allow items to cache their own list, or use `get_next_idx_fallback()` instead", .{});
//             if (FORWARD) {
//                 const ptr = get_ptr(self, this_idx);
//                 return @field(ptr, NEXT_FIELD);
//             }
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//             if (STATE) {
//                 const list = self.get_list_tag(this_idx);
//                 if (list != UNTRACKED_LIST) {
//                     const last_in_list = self.get_last_index_in_list(list);
//                     return Internal.traverse_to_find_index_after_this_one_backward_from_known_idx_after(self, this_idx, last_in_list);
//                 }
//             }
//             const parent_idx = self.get_parent_idx(this_idx);
//             assert_with_reason(PARENT and LAST_CHILD and parent_idx != NULL_IDX, @src(), "cannot find a next index if items arent linked in the forward direction OR items dont cache the list they belong to and are not in an 'untracked' list, OR they don't cache both their parent and last-child and their parent idx != NULL_IDX", .{});
//             const known_next_idx = @field(self.get_ptr(parent_idx), LAST_CHILD_FIELD);
//             assert_with_reason(known_next_idx != NULL_IDX, @src(), "parent idx wasn't NULL_IDX, but parent ptr 'last child' field had a value of NULL_IDX, broken list", .{});
//             return Internal.traverse_to_find_index_after_this_one_backward_from_known_idx_after(self, this_idx, known_next_idx);
//         }

//         pub inline fn get_next_idx_fallback(self: *const LinkedList, this_idx: Idx, known_idx_after_this: Idx) Idx {
//             if (FORWARD) return self.get_next_idx(this_idx);
//             assert_idx_less_than_len(this_idx, self.list.len, @src());
//             assert_idx_less_than_len(known_idx_after_this, self.list.len, @src());
//             return Internal.traverse_to_find_index_after_this_one_backward_from_known_idx_after(self, this_idx, known_idx_after_this);
//         }

//         pub inline fn get_list_tag(self: *const LinkedList, this_idx: Idx) ListTag {
//             if (STATE) return @enumFromInt(Internal.get_list_tag_raw(self.get_ptr(this_idx)));
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks not allowed", .{});
//             return Internal.traverse_to_find_what_list_idx_is_in(self, this_idx);
//         }
//         pub inline fn get_parent_idx(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_idx_less_than_len(this_idx, self.list.len, @src());
//             if (PARENT) return @field(self.get_ptr(this_idx), PARENT_FIELD);
//             return NULL_IDX;
//         }
//         pub inline fn get_first_child(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_idx_less_than_len(this_idx, self.list.len, @src());
//             if (FIRST_CHILD) return @field(self.get_ptr(this_idx), FIRST_CHILD_FIELD);
//             return NULL_IDX;
//         }
//         pub inline fn get_last_child(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_idx_less_than_len(this_idx, self.list.len, @src());
//             if (LAST_CHILD) return @field(self.get_ptr(this_idx), LAST_CHILD_FIELD);
//             return NULL_IDX;
//         }

//         pub fn get_nth_index_from_start_of_list(self: *LinkedList, list: ListTag, n: Idx) Idx {
//             const set_count = self.get_list_len(list);
//             assert_with_reason(n < set_count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(list), set_count });
//             if (FORWARD) {
//                 var c: Idx = 0;
//                 var idx = self.get_first_index_in_list(list);
//                 while (c != n) {
//                     c += 1;
//                     idx = get_next_idx(self, list, idx);
//                 }
//                 return idx;
//             } else {
//                 var c: Idx = 0;
//                 var idx = self.get_last_index_in_list(list);
//                 const nn = set_count - n;
//                 while (c < nn) {
//                     c += 1;
//                     idx = get_prev_idx(self, list, idx);
//                 }
//                 return idx;
//             }
//         }

//         pub fn get_nth_index_from_end_of_list(self: *LinkedList, list: ListTag, n: Idx) Idx {
//             const count = self.get_list_len(list);
//             assert_with_reason(n < count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(list), count });
//             if (BACKWARD) {
//                 var c: Idx = 0;
//                 var idx = self.get_last_index_in_list(list);
//                 while (c != n) {
//                     c += 1;
//                     idx = get_prev_idx(self, list, idx);
//                 }
//                 return idx;
//             } else {
//                 var c: Idx = 0;
//                 var idx = self.get_first_index_in_list(list);
//                 const nn = count - n;
//                 while (c < nn) {
//                     c += 1;
//                     idx = get_next_idx(self, list, idx);
//                 }
//                 return idx;
//             }
//         }

//         pub inline fn index_is_in_list(self: *LinkedList, idx: Idx, list: ListTag) bool {
//             if (STATE) {
//                 const ptr = get_ptr(self, idx);
//                 if (STRONG_ASSERT) {
//                     if (Internal.get_list_tag_raw(ptr) != @intFromEnum(list)) return false;
//                 } else {
//                     return Internal.get_list_tag_raw(ptr) == @intFromEnum(list);
//                 }
//             }
//             if (list == UNTRACKED_LIST) {
//                 if (ALLOW_SLOW) return true; //TODO iterate ALL lists and verify its not in any?
//                 return true;
//             }
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//             if (FORWARD) {
//                 return Internal.traverse_forward_from_idx_and_report_if_found_target_idx(self, self.get_first_index_in_list(list), idx);
//             } else {
//                 return Internal.traverse_backward_from_idx_and_report_if_found_target_idx(self, self.get_last_index_in_list(list), idx);
//             }
//         }

//         pub inline fn get_first_index_in_list(self: *const LinkedList, list: ListTag) Idx {
//             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot find first index in the 'untracked' list (list with larget enum tag value) without an indx to start from", .{});
//             if (HEAD) return self.lists[@intFromEnum(list)].first_idx;
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//             return Internal.traverse_backward_to_get_first_index_in_list_from_start_index(self, self.get_last_index_in_list(list));
//         }

//         pub inline fn get_first_index_in_same_list_as_this_index(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_with_reason(this_idx != NULL_IDX, @src(), "cannot find first index in same list as NULL_IDX, it has no list association", .{});
//             if (STATE) {
//                 const list = self.get_list_tag(this_idx);
//                 if (list != UNTRACKED_LIST) {
//                     if (HEAD) return self.get_first_index_in_list(list);
//                 } else if (PARENT and FIRST_CHILD) {
//                     const parent_idx = self.get_parent_idx(this_idx);
//                     const parent_ptr = self.get_ptr(parent_idx);
//                     return @field(parent_ptr, FIRST_CHILD_FIELD);
//                 }
//             }
//             if (BACKWARD) {
//                 return Internal.traverse_backward_to_get_first_index_in_list_from_start_index(self, this_idx);
//             } else {
//                 assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//                 const list = Internal.traverse_all_lists_forward_and_report_list_found_in(self, this_idx);
//                 assert_with_reason(list != UNTRACKED_LIST, @src(), "final fallback failed: items not linked in backward direction and item not in any tracked list", .{});
//                 return self.get_first_index_in_list(list);
//             }
//         }

//         pub inline fn get_last_index_in_list(self: *const LinkedList, list: ListTag) Idx {
//             assert_with_reason(list != UNTRACKED_LIST, @src(), "cannot find last index in the 'untracked' list (list with larget enum tag value) without an indx to start from", .{});
//             if (TAIL) return self.lists[@intFromEnum(list)].last_idx;
//             assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//             return Internal.traverse_forward_to_get_last_index_in_list_from_start_index(self, self.get_first_index_in_list(list));
//         }

//         pub inline fn get_last_index_in_same_list_as_this_index(self: *const LinkedList, this_idx: Idx) Idx {
//             assert_with_reason(this_idx != NULL_IDX, @src(), "cannot find last index in same list as NULL_IDX, it has no list association", .{});
//             if (STATE) {
//                 const list = self.get_list_tag(this_idx);
//                 if (list != UNTRACKED_LIST) {
//                     if (TAIL) return self.get_last_index_in_list(list);
//                 } else if (PARENT and LAST_CHILD) {
//                     const parent_idx = self.get_parent_idx(this_idx);
//                     const parent_ptr = self.get_ptr(parent_idx);
//                     return @field(parent_ptr, LAST_CHILD_FIELD);
//                 }
//             }
//             if (FORWARD) {
//                 return Internal.traverse_forward_to_get_last_index_in_list_from_start_index(self, this_idx);
//             } else {
//                 assert_with_reason(ALLOW_SLOW, @src(), "slow fallbacks disallowed", .{});
//                 const list = Internal.traverse_all_lists_forward_and_report_list_found_in(self, this_idx);
//                 assert_with_reason(list != UNTRACKED_LIST, @src(), "final fallback failed: items not linked in forward direction and item not in any tracked list", .{});
//                 return self.get_last_index_in_list(list);
//             }
//         }

//         pub inline fn get_items_and_insert_at(self: *LinkedList, get_from: anytype, insert_to: anytype, alloc: Allocator) if (RETURN_ERRORS) Error!LLSlice else LLSlice {
//             return Internal.get_items_and_insert_at_internal(self, get_from, insert_to, alloc, false);
//         }

//         pub inline fn get_items_and_insert_at_assume_capacity(self: *LinkedList, get_from: anytype, insert_to: anytype) LLSlice {
//             return Internal.get_items_and_insert_at_internal(self, get_from, insert_to, DummyAllocator.allocator, true);
//         }

//         pub fn list_is_cyclic_forward(self: *LinkedList, list: ListTag) bool {
//             if (FORWARD) {
//                 const start_idx = self.get_first_index_in_list(list);
//                 if (start_idx == NULL_IDX) return false;
//                 if (STATE or STRONG_ASSERT) assert_with_reason(self.index_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
//                 var slow_idx = start_idx;
//                 var fast_idx = start_idx;
//                 var next_fast: Idx = undefined;
//                 while (true) {
//                     next_fast = self.get_next_idx(list, fast_idx);
//                     if (next_fast == NULL_IDX) return false;
//                     next_fast = self.get_next_idx(list, next_fast);
//                     if (next_fast == NULL_IDX) return false;
//                     fast_idx = next_fast;
//                     slow_idx = self.get_next_idx(list, slow_idx);
//                     if (slow_idx == fast_idx) return true;
//                 }
//             } else {
//                 return false;
//             }
//         }

//         pub fn list_is_cyclic_backward(self: *LinkedList, list: ListTag) bool {
//             if (FORWARD) {
//                 const start_idx = self.get_last_index_in_list(list);
//                 if (start_idx == NULL_IDX) return false;
//                 if (STATE or STRONG_ASSERT) assert_with_reason(self.index_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
//                 var slow_idx = start_idx;
//                 var fast_idx = start_idx;
//                 var next_fast: Idx = undefined;
//                 while (true) {
//                     next_fast = self.get_prev_idx(list, fast_idx);
//                     if (next_fast == NULL_IDX) return false;
//                     next_fast = self.get_prev_idx(list, next_fast);
//                     if (next_fast == NULL_IDX) return false;
//                     fast_idx = next_fast;
//                     slow_idx = self.get_prev_idx(list, slow_idx);
//                     if (slow_idx == fast_idx) return true;
//                 }
//             } else {
//                 return false;
//             }
//         }

//         // pub fn find_idx(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
//         //     for (self.slice(), 0..) |*item, idx| {
//         //         if (match_fn(param, item)) return @intCast(idx);
//         //     }
//         //     return null;
//         // }

//         // pub fn find_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
//         //     if (self.find_idx(Param, param, match_fn)) |idx| {
//         //         return &self.ptr[idx];
//         //     }
//         //     return null;
//         // }

//         // pub fn find_const_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
//         //     if (self.find_idx(Param, param, match_fn)) |idx| {
//         //         return &self.ptr[idx];
//         //     }
//         //     return null;
//         // }

//         // pub fn find_and_copy(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
//         //     if (self.find_idx(Param, param, match_fn)) |idx| {
//         //         return self.ptr[idx];
//         //     }
//         //     return null;
//         // }

//         // pub fn find_and_remove(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
//         //     if (self.find_idx(Param, param, match_fn)) |idx| {
//         //         return self.remove(idx);
//         //     }
//         //     return null;
//         // }

//         // pub fn find_and_delete(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
//         //     if (self.find_idx(Param, param, match_fn)) |idx| {
//         //         self.delete(idx);
//         //         return true;
//         //     }
//         //     return false;
//         // }

//         // pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
//         //     return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
//         // }

//         // pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
//         //     return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
//         // }

//         // pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
//         //     return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
//         // }

//         // pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
//         //     return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
//         // }

//         // pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
//         //     assert_with_reason(indexes.len <= self.len, @src(), "more indexes provided ({d}) than exist in list ({d})", .{ indexes.len, self.len });
//         //     assert_with_reason(check: {
//         //         var i: usize = 1;
//         //         while (i < indexes.len) : (i += 1) {
//         //             if (indexes[i - 1] >= indexes[i]) break :check false;
//         //         }
//         //         break :check true;
//         //     }, @src(), "not all indexes are in increasing order (with no duplicates) as is required by this function", .{});
//         //     assert_with_reason(check: {
//         //         var i: usize = 0;
//         //         while (i < indexes.len) : (i += 1) {
//         //             if (indexes[i] >= self.len) break :check false;
//         //         }
//         //         break :check true;
//         //     }, @src(), "some indexes provided are out of bounds for list len ({d})", .{self.len});
//         //     var shift_down: usize = 0;
//         //     var i: usize = 0;
//         //     var src_start: Idx = undefined;
//         //     var src_end: Idx = undefined;
//         //     var dst_start: Idx = undefined;
//         //     var dst_end: Idx = undefined;
//         //     while (i < indexes.len) {
//         //         var consecutive: Idx = 1;
//         //         var end_index: Idx = i + consecutive;
//         //         while (end_index < indexes.len) {
//         //             if (indexes[end_index] != indexes[end_index - 1] + 1) break;
//         //             consecutive += 1;
//         //             end_index += 1;
//         //         }
//         //         const start_idx = end_index - 1;
//         //         shift_down += consecutive;
//         //         src_start = indexes[start_idx];
//         //         src_end = if (end_index >= indexes.len) self.len else indexes[end_index];
//         //         dst_start = src_start - shift_down;
//         //         dst_end = src_end - shift_down;
//         //         std.mem.copyForwards(Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
//         //         i += consecutive;
//         //     }
//         //     self.len -= indexes.len;
//         // }

//         // //TODO pub fn insert_slots_at_ordered_indexes()

//         // pub inline fn insertion_sort(self: *List) void {
//         //     return self.flex_slice(.mutable).insertion_sort();
//         // }

//         // pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
//         //     return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
//         // }

//         // pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
//         //     return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
//         // }

//         // pub inline fn is_sorted(self: *List) bool {
//         //     return self.flex_slice(.immutable).is_sorted();
//         // }

//         // pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
//         //     return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
//         // }

//         // pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
//         //     return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
//         // }

//         // pub inline fn is_reverse_sorted(self: *List) bool {
//         //     return self.flex_slice(.immutable).is_reverse_sorted();
//         // }

//         // pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
//         //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
//         // }

//         // pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
//         //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
//         // }

//         // // pub inline fn insert_one_sorted( self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
//         // //     return insert_one_sorted_custom(List, self, item, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN, alloc);
//         // // }

//         // // pub fn insert_one_sorted_custom( self: *List, item: Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
//         // //     const insert_idx: Idx = @intCast(BinarySearch.binary_search_insert_index(Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
//         // //     if (RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
//         // //     return insert_idx;
//         // // }

//         // // pub inline fn find_equal_order_idx_sorted( self: *List, item_to_compare: *const Elem) ?Idx {
//         // //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN);
//         // // }

//         // // pub fn find_equal_order_idx_sorted_custom( self: *List, item_to_compare: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem)) ?Idx {
//         // //     const insert_idx = BinarySearch.binary_search_by_order(Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
//         // //     if (insert_idx) |idx| return @intCast(idx);
//         // //     return null;
//         // // }

//         // // pub inline fn find_matching_item_idx_sorted( self: *List, item_to_find: *const Elem) ?Idx {
//         // //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_COMPARE_PKG.equals, DEFAULT_MATCH_FN);
//         // // }

//         // // pub fn find_matching_item_idx_sorted_custom( self: *List, item_to_find: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), exact_match_fn: *const CompareFn(Elem)) ?Idx {
//         // //     const insert_idx = BinarySearch.binary_search_exact_match(Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
//         // //     if (insert_idx) |idx| return @intCast(idx);
//         // //     return null;
//         // // }

//         // // pub inline fn find_matching_item_idx( self: *List, item_to_find: *const Elem) ?Idx {
//         // //     return find_matching_item_idx_custom(List, self, item_to_find, DEFAULT_MATCH_FN);
//         // // }

//         // // pub fn find_matching_item_idx_custom( self: *List, item_to_find: *const Elem, exact_match_fn: *const CompareFn(Elem)) ?Idx {
//         // //     if (self.len == 0) return null;
//         // //     const buf = self.ptr[0..self.len];
//         // //     var idx: Idx = 0;
//         // //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
//         // //     const limit = self.len - 1;
//         // //     while (!found_exact and idx < limit) {
//         // //         idx += 1;
//         // //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
//         // //     }
//         // //     if (found_exact) return idx;
//         // //     return null;
//         // // }

//         // pub fn handle_alloc_error(err: Allocator.Error) if (RETURN_ERRORS) Error else noreturn {
//         //     switch (ALLOC_ERROR_BEHAVIOR) {
//         //         ErrorBehavior.RETURN_ERRORS => return err,
//         //         ErrorBehavior.ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
//         //         ErrorBehavior.ERRORS_ARE_UNREACHABLE => unreachable,
//         //     }
//         // }

//         // //**************************
//         // // std.io.Writer interface *
//         // //**************************
//         // const StdWriterHandle = struct {
//         //     list: *List,
//         //     alloc: Allocator,
//         // };
//         // const StdWriterHandleNoGrow = struct {
//         //     list: *List,
//         // };

//         // pub const StdWriter = if (Elem != u8)
//         //     @compileError("The Writer interface is only defined for child type `u8` " ++
//         //         "but the given type is " ++ @typeName(Elem))
//         // else
//         //     std.io.Writer(StdWriterHandle, Allocator.Error, std_write);

//         // pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
//         //     return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
//         // }

//         // fn std_write(handle: StdWriterHandle, bytes: []const u8) Allocator.Error!usize {
//         //     try handle.list.append_slice(bytes, handle.alloc);
//         //     return bytes.len;
//         // }

//         // pub const StdWriterNoGrow = if (Elem != u8)
//         //     @compileError("The Writer interface is only defined for child type `u8` " ++
//         //         "but the given type is " ++ @typeName(Elem))
//         // else
//         //     std.io.Writer(StdWriterHandleNoGrow, Allocator.Error, std_write_no_grow);

//         // pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
//         //     return StdWriterNoGrow{ .context = .{ .list = self } };
//         // }

//         // fn std_write_no_grow(handle: StdWriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
//         //     const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
//         //     if (bytes.len > available_capacity) return error.OutOfMemory;
//         //     handle.list.append_slice_assume_capacity(bytes);
//         //     return bytes.len;
//         // }
//     };
// }

// // pub fn LinkedListIterator(comptime List: type) type {
// //     return struct {
// //         next_idx: List.Idx = 0,
// //         list_ref: *List,

// //         const Self = @This();

// //         pub inline fn reset_index_to_start(self: *Self) void {
// //             self.next_idx = 0;
// //         }

// //         pub inline fn set_index(self: *Self, index: List.Idx) void {
// //             self.next_idx = index;
// //         }

// //         pub inline fn decrease_index_safe(self: *Self, count: List.Idx) void {
// //             self.next_idx -|= count;
// //         }
// //         pub inline fn decrease_index(self: *Self, count: List.Idx) void {
// //             self.next_idx -= count;
// //         }
// //         pub inline fn increase_index(self: *Self, count: List.Idx) void {
// //             self.next_idx += count;
// //         }
// //         pub inline fn increase_index_safe(self: *Self, count: List.Idx) void {
// //             self.next_idx +|= count;
// //         }

// //         pub inline fn has_next(self: Self) bool {
// //             return self.next_idx < self.list_ref.len;
// //         }

// //         pub fn get_next_copy(self: *Self) ?List.Elem {
// //             if (self.next_idx >= self.list_ref.len) return null;
// //             const item = self.list_ref.ptr[self.next_idx];
// //             self.next_idx += 1;
// //             return item;
// //         }

// //         pub fn get_next_copy_guaranteed(self: *Self) List.Elem {
// //             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
// //             const item = self.list_ref.ptr[self.next_idx];
// //             self.next_idx += 1;
// //             return item;
// //         }

// //         pub fn get_next_ref(self: *Self) ?*List.Elem {
// //             if (self.next_idx >= self.list_ref.len) return null;
// //             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
// //             self.next_idx += 1;
// //             return item;
// //         }

// //         pub fn get_next_ref_guaranteed(self: *Self) *List.Elem {
// //             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
// //             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
// //             self.next_idx += 1;
// //             return item;
// //         }

// //         /// Returns `true` if action was performed at least one time, `false` if iterator had zero items left
// //         pub fn perform_action_on_remaining_items(self: *Self, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
// //             var idx: List.Idx = self.next_idx;
// //             var exec_count: List.Idx = 0;
// //             var should_continue: bool = true;
// //             while (should_continue and idx < self.list_ref.len) : (idx += 1) {
// //                 const item: *List.Elem = &self.list_ref.ptr[idx];
// //                 should_continue = callback(self.list_ref, idx, item, userdata);
// //                 exec_count += 1;
// //             }
// //             return exec_count > 0;
// //         }

// //         /// Returns `true` if action was performed on exactly `count` items, `false` if iterator ran out of items early
// //         pub fn perform_action_on_next_n_items(self: *Self, count: List.Idx, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
// //             var idx: List.Idx = self.next_idx;
// //             const limit = @min(idx + count, self.list_ref.len);
// //             var exec_count: List.Idx = 0;
// //             var should_continue: bool = true;
// //             while (should_continue and idx < limit) : (idx += 1) {
// //                 const item: *List.Elem = &self.list_ref.ptr[idx];
// //                 should_continue = callback(self.list_ref, idx, item, userdata);
// //                 exec_count += 1;
// //             }
// //             return exec_count == count;
// //         }

// //         /// Should return `true` if iteration should continue, or `false` if iteration should stop
// //         pub const IteratorAction = fn (list: *List, index: List.Idx, item: *List.Elem, userdata: ?*anyopaque) bool;
// //     };
// // }

// test "LinkedList.zig - Linear Doubly Linked" {
//     const t = Root.Testing;
//     const alloc = std.heap.page_allocator;
//     const TestElem = struct {
//         prev: u16,
//         val: u8,
//         idx: u16,
//         list: u8,
//         next: u16,
//     };
//     const TestState = enum(u8) {
//         USED,
//         FREE,
//         INVALID,
//         NONE,
//     };
//     const uninit_val = TestElem{
//         .idx = 0xAAAA,
//         .prev = 0xAAAA,
//         .next = 0xAAAA,
//         .list = 0xAA,
//         .val = 0,
//     };
//     const opts = LinkedListManagerOptions{
//         .list_options = Root.List.ListOptions{
//             .alignment = null,
//             .alloc_error_behavior = .ERRORS_PANIC,
//             .element_type = TestElem,
//             .growth_model = .GROW_BY_25_PERCENT,
//             .index_type = u16,
//             .secure_wipe_bytes = true,
//             .memset_uninit_val = &uninit_val,
//         },
//         .master_list_enum = TestState,
//         .forward_linkage = "next",
//         .backward_linkage = "prev",
//         .element_idx_cache_field = "idx",
//         .force_cache_first_index = true,
//         .force_cache_last_index = true,
//         .element_list_flag_access = ElementStateAccess{
//             .field = "list",
//             .field_bit_offset = 1,
//             .field_bit_count = 2,
//             .field_type = u8,
//         },
//         .stronger_asserts = true,
//     };
//     const Action = struct {
//         fn set_value_from_string(elem: *TestElem, userdata: ?*anyopaque) void {
//             const string: *[]const u8 = @ptrCast(@alignCast(userdata.?));
//             elem.val = string.*[0];
//             string.* = string.*[1..];
//         }
//         fn move_data(from_item: *const TestElem, to_item: *TestElem, userdata: ?*anyopaque) void {
//             _ = userdata;
//             to_item.val = from_item.val;
//         }
//         fn greater_than(a: *const TestElem, b: *const TestElem, userdata: ?*anyopaque) bool {
//             _ = userdata;
//             return a.val > b.val;
//         }
//     };
//     const List = define_linked_list_manager(opts);
//     const expect = struct {
//         fn list_is_valid(linked_list: *List, list: TestState, case_indexes: []const u16, case_vals: []const u8) !void {
//             errdefer debug_list(linked_list, list);
//             var i: List.Idx = 0;
//             var c: List.Idx = 0;
//             const list_count = linked_list.get_list_len(list);
//             try t.expect_equal(case_indexes.len, "indexes.len", case_vals.len, "vals.len", "text case indexes and vals have different len", .{});
//             try t.expect_equal(list_count, "list_count", case_vals.len, "vals.len", "list {s} count mismatch with test case vals len", .{@tagName(list)});
//             //FORWARD
//             var start_idx = linked_list.get_first_index_in_list(list);
//             if (start_idx == List.NULL_IDX) {
//                 try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//             } else {
//                 try t.expect_true(linked_list.index_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
//                 var slow_idx = start_idx;
//                 var fast_idx = start_idx;
//                 var fast_ptr = linked_list.get_ptr(fast_idx);
//                 var prev_fast_idx: List.Idx = List.NULL_IDX;
//                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
//                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
//                 try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached prev isnt NULL_IDX", .{ @tagName(list), start_idx });
//                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                 i = 1;
//                 c = 1;
//                 check: while (true) {
//                     prev_fast_idx = fast_idx;
//                     fast_idx = linked_list.get_next_idx(list, fast_idx);
//                     if (fast_idx == List.NULL_IDX) {
//                         try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//                         break :check;
//                     }
//                     try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
//                     fast_ptr = linked_list.get_ptr(fast_idx);
//                     try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
//                     try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                     try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                     try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                     i += 1;
//                     c += 1;
//                     prev_fast_idx = fast_idx;
//                     fast_idx = linked_list.get_next_idx(list, fast_idx);
//                     if (fast_idx == List.NULL_IDX) {
//                         try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//                         break :check;
//                     }
//                     fast_ptr = linked_list.get_ptr(fast_idx);
//                     try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
//                     try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                     try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                     try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                     i += 1;
//                     c += 1;
//                     slow_idx = linked_list.get_next_idx(list, slow_idx);
//                     try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
//                 }
//             }
//             //BACKWARD
//             i = @intCast(case_indexes.len -| 1);
//             c = 0;
//             start_idx = linked_list.get_last_index_in_list(list);
//             if (start_idx == List.NULL_IDX) {
//                 try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//             } else {
//                 try t.expect_true(linked_list.index_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
//                 var slow_idx = start_idx;
//                 var fast_idx = start_idx;
//                 var fast_ptr = linked_list.get_ptr(fast_idx);
//                 var prev_fast_idx: List.Idx = List.NULL_IDX;
//                 try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
//                 try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
//                 try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached next isnt NULL_IDX", .{ @tagName(list), start_idx });
//                 try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                 try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                 try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                 i -|= 1;
//                 c = 1;
//                 check: while (true) {
//                     prev_fast_idx = fast_idx;
//                     fast_idx = linked_list.get_prev_idx(list, fast_idx);
//                     if (fast_idx == List.NULL_IDX) {
//                         try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//                         break :check;
//                     }
//                     try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
//                     fast_ptr = linked_list.get_ptr(fast_idx);
//                     try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached next isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
//                     try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                     try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                     try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                     i -|= 1;
//                     c += 1;
//                     prev_fast_idx = fast_idx;
//                     fast_idx = linked_list.get_prev_idx(list, fast_idx);
//                     if (fast_idx == List.NULL_IDX) {
//                         try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
//                         break :check;
//                     }
//                     fast_ptr = linked_list.get_ptr(fast_idx);
//                     try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_tag_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
//                     try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
//                     try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
//                     try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
//                     try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
//                     i -|= 1;
//                     c += 1;
//                     slow_idx = linked_list.get_prev_idx(list, slow_idx);
//                     try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
//                 }
//             }
//         }
//         fn full_ll_state(list: *List, used_indexes: []const u16, used_vals: []const u8, free_indexes: []const u16, free_vals: []const u8, invalid_indexes: []const u16, invalid_vals: []const u8) !void {
//             try list_is_valid(list, .FREE, free_indexes, free_vals);
//             try list_is_valid(list, .USED, used_indexes, used_vals);
//             try list_is_valid(list, .INVALID, invalid_indexes, invalid_vals);
//             if (list.get_list_len(.FREE) == 0) {
//                 try t.expect_equal(list.get_first_index_in_list(.FREE), "list.get_first_index_in_list(.FREE)", List.NULL_IDX, "List.NULL_IDX", "empty list `FREE` does not have NULL_IDX for first index", .{});
//                 try t.expect_equal(list.get_last_index_in_list(.FREE), "list.get_last_index_in_list(.FREE)", List.NULL_IDX, "List.NULL_IDX", "empty list `FREE` does not have NULL_IDX for last index", .{});
//             }
//             if (list.get_list_len(.USED) == 0) {
//                 try t.expect_equal(list.get_first_index_in_list(.USED), "list.get_first_index_in_list(.USED)", List.NULL_IDX, "List.NULL_IDX", "empty list `USED` does not have NULL_IDX for first index", .{});
//                 try t.expect_equal(list.get_last_index_in_list(.USED), "list.get_last_index_in_list(.USED)", List.NULL_IDX, "List.NULL_IDX", "empty list `USED` does not have NULL_IDX for last index", .{});
//             }
//             if (list.get_list_len(.INVALID) == 0) {
//                 try t.expect_equal(list.get_first_index_in_list(.INVALID), "list.get_first_index_in_list(.INVALID)", List.NULL_IDX, "List.NULL_IDX", "empty list `INVALID` does not have NULL_IDX for first index", .{});
//                 try t.expect_equal(list.get_last_index_in_list(.INVALID), "list.get_last_index_in_list(.INVALID)", List.NULL_IDX, "List.NULL_IDX", "empty list `INVALID` does not have NULL_IDX for last index", .{});
//             }
//             const total_count = list.get_list_len(.USED) + list.get_list_len(.FREE) + list.get_list_len(.INVALID);
//             try t.expect_equal(total_count, "total_count", list.list.len, "list.list.len", "total list list counts did not equal underlying list len (leaked indexes)", .{});
//         }
//         fn debug_list(linked_list: *List, list: TestState) void {
//             t.print("\nERROR STATE: {s}\ncount:     {d: >2}\nfirst_idx: {d: >2}\nlast_idx:  {d: >2}\n", .{
//                 @tagName(list),
//                 linked_list.get_list_len(list),
//                 linked_list.get_first_index_in_list(list),
//                 linked_list.get_last_index_in_list(list),
//             });
//             var idx = linked_list.get_first_index_in_list(list);
//             var ptr: *List.Elem = undefined;
//             t.print("forward:      ", .{});
//             while (idx != List.NULL_IDX) {
//                 ptr = linked_list.get_ptr(idx);
//                 t.print("{d} -> ", .{idx});
//                 idx = @field(ptr, List.NEXT_FIELD);
//             }

//             t.print("NULL\n", .{});
//             idx = linked_list.get_first_index_in_list(list);
//             t.print("forward str:  ", .{});
//             while (idx != List.NULL_IDX) {
//                 ptr = linked_list.get_ptr(idx);
//                 t.print("{c}", .{@field(ptr, "val")});
//                 idx = @field(ptr, List.NEXT_FIELD);
//             }
//             t.print("\n", .{});
//             idx = linked_list.get_last_index_in_list(list);
//             t.print("backward:     ", .{});
//             while (idx != List.NULL_IDX) {
//                 ptr = linked_list.get_ptr(idx);
//                 t.print("{d} -> ", .{idx});
//                 idx = @field(ptr, List.PREV_FIELD);
//             }
//             t.print("NULL\n", .{});
//             idx = linked_list.get_last_index_in_list(list);
//             t.print("backward str: ", .{});
//             while (idx != List.NULL_IDX) {
//                 ptr = linked_list.get_ptr(idx);
//                 t.print("{c}", .{@field(ptr, "val")});
//                 idx = @field(ptr, List.PREV_FIELD);
//             }
//             t.print("\n", .{});
//         }
//     };
//     var linked_list = List.new_empty();
//     var slice_result = linked_list.get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc)", List.LLSlice{ .count = 20, .first = 0, .last = 19, .list = .FREE }, "List.LLSlice{.count = 20, .first = 0, .last = 19, .list = .FREE}", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{}, // used_indexes
//         &.{}, // used_vals
//         &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
//         &.{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
//         &.{}, // invalid_indexes
//         &.{}, // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }, "List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
//         &.{ 0, 0, 0, 0, 0, 0, 0, 0}, // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
//         &.{}, // invalid_indexes
//         &.{}, // invalid_vals
//     );
//     // zig fmt: on
//     var slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
//     try t.expect_shallow_equal(slice_iter_state, "slice_result.new_iterator_state_at_start_of_slice(&linked_list)", List.LLSlice.SliceIteratorState(0){ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result, .state_slots = undefined }, "SliceIteratorState{ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result }", "unexpected result from function", .{});
//     var slice_iter = slice_iter_state.iterator();
//     var str: []const u8 = "abcdefgh";
//     const bool_result = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
//     try t.expect_true(bool_result, "slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, &\"abcdefghijklmnopqrst\");", "iterator set values failed", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
//         "abcdefgh", // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
//         &.{}, // invalid_indexes
//         &.{}, // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.USED, 3), .AT_BEGINNING_OF_LIST, .INVALID, alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.USED, 3), .AT_BEGINNING_OF_LIST, .INVALID, alloc)", List.LLSlice{ .count = 3, .first = 5, .last = 7, .list = .INVALID }, "LLSlice{ .count = 3, .first = 5, .last = 7, .list = .INVALID }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 0, 1, 2, 3, 4}, // used_indexes
//         "abcde", // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
//         &.{5, 6, 7}, // invalid_indexes
//         "fgh", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST, List.CountFromList.new(.FREE, 5), .AFTER_INDEX, List.IndexInList.new(.USED, 2), alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST, 5, .AFTER_INDEX, List.IndexInList.new(.USED, 2), alloc)", List.LLSlice{ .count = 5, .first = 15, .last = 19, .list = .USED }, "LLSlice{ .count = 5, .first = 15, .last = 19, .list = .USED }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 0, 1, 2, 15, 16, 17, 18, 19, 3, 4}, // used_indexes
//         "abc\x00\x00\x00\x00\x00de", // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
//         &.{5, 6, 7}, // invalid_indexes
//         "fgh", // invalid_vals
//     );
//     // zig fmt: on
//     slice_iter_state = slice_result.new_iterator_state_at_end_of_slice(&linked_list, 0);
//     slice_iter = slice_iter_state.iterator();
//     str = "ijklm";
//     _ = slice_iter.perform_action_on_all_prev_items(Action.set_value_from_string, @ptrCast(&str));
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 0, 1, 2, 15, 16, 17, 18, 19, 3, 4}, // used_indexes
//         "abcmlkjide", // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
//         &.{5, 6, 7}, // invalid_indexes
//         "fgh", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.SPARSE_LIST_FROM_SAME_SET, List.IndexesInSameList.new(.USED, &.{ 18, 2, 15, 0 }), .BEFORE_INDEX, List.IndexInList.new(.INVALID, 6), alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.SPARSE_LIST_FROM_SAME_SET, List.IndexesInSameList.new(.USED, &.{ 18, 2, 15, 0 }), .BEFORE_INDEX, List.IndexInList.new(.INVALID, 6), alloc)", List.LLSlice{ .count = 4, .first = 18, .last = 0, .list = .INVALID }, "LLSlice{ .count = 4, .first = 18, .last = 0, .list = .INVALID }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 1, 16, 17, 19, 3, 4}, // used_indexes
//         "blkide", // used_vals
//         &.{ 8, 9, 10, 11, 12, 13, 14 }, // free_indexes
//         &.{ 0, 0, 0,  0,  0,  0,  0 },  // free_vals
//         &.{5, 18, 2, 15, 0, 6, 7}, // invalid_indexes
//         "fjcmagh", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.SPARSE_LIST_FROM_ANY_SET, &.{ List.IndexInList.new(.USED, 19), List.IndexInList.new(.FREE, 11), List.IndexInList.new(.INVALID, 7), List.IndexInList.new(.FREE, 8) }, .AT_BEGINNING_OF_LIST, .USED, alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.SPARSE_LIST_FROM_ANY_SET, &.{ List.IndexInList.new(.USED, 19), List.IndexInList.new(.FREE, 11), List.IndexInList.new(.INVALID, 7), List.IndexInList.new(.FREE, 8) }, .AT_BEGINNING_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 4, .first = 19, .last = 8, .list = .USED }, "LLSlice{ .count = 4, .first = 19, .last = 8, .list = .USED }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4}, // used_indexes
//         "i\x00h\x00blkde", // used_vals
//         &.{ 9, 10, 12, 13, 14 }, // free_indexes
//         &.{ 0, 0,  0,  0,  0 },  // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
//     slice_iter = slice_iter_state.iterator();
//     str = "wxyz";
//     _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4}, // used_indexes
//         "wxyzblkde", // used_vals
//         &.{ 9, 10, 12, 13, 14 }, // free_indexes
//         &.{ 0, 0,  0,  0,  0 },  // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.FIRST_FROM_LIST_ELSE_CREATE_NEW, .FREE, .AT_END_OF_LIST, .USED, alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FIRST_FROM_LIST_ELSE_CREATE_NEW, .FREE, .AT_END_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 1, .first = 9, .last = 9, .list = .USED }, "LLSlice{ .count = 1, .first = 9, .last = 9, .list = .USED }", "unexpected result from function", .{});
//     linked_list.list.ptr[slice_result.first].val = 'v';
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 3, 4, 9}, // used_indexes
//         "wxyzblkdev", // used_vals
//         &.{ 10, 12, 13, 14 }, // free_indexes
//         &.{ 0,  0,  0,  0 },  // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = linked_list.get_items_and_insert_at(.LAST_N_FROM_LIST_ELSE_CREATE_NEW, List.CountFromList.new(.FREE, 6), .AFTER_INDEX, List.IndexInList.new(.USED, 17), alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.LAST_N_FROM_LIST_ELSE_CREATE_NEW, List.CountFromList.new(.FREE, 6), .AFTER_INDEX, List.IndexInList.new(.USED, 17), alloc)", List.LLSlice{ .count = 6, .first = 10, .last = 21, .list = .USED }, "LLSlice{ .count = 6, .first = 10, .last = 21, .list = .USED }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzblk\x00\x00\x00\x00\x00\x00dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
//     slice_iter = slice_iter_state.iterator();
//     str = "123456";
//     _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzblk123456dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result.slide_left(&linked_list, 1);
//     _ = slice_iter.reset();
//     str = "123456";
//     _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzbl1234566dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 18, 2, 15, 0, 6}, // invalid_indexes
//         "fjcmag", // invalid_vals
//     );
//     // zig fmt: on
//     slice_result = List.LLSlice{ .count = 3, .first = 18, .last = 15, .list = .INVALID };
//     slice_result = linked_list.get_items_and_insert_at(.FROM_SLICE_ELSE_CREATE_NEW, List.LLSliceWithTotalNeeded{ .slice = slice_result, .total_needed = 4 }, .AFTER_INDEX, List.IndexInList.new(.USED, 10), alloc);
//     try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FROM_SLICE_ELSE_CREATE_NEW, List.LLSliceWithTotalNeeded{ .slice = slice_result, .total_needed = 4 }, .AFTER_INDEX, List.IndexInList.new(.USED, 10), alloc)", List.LLSlice{ .count = 4, .first = 18, .last = 22, .list = .USED }, "LLSlice{ .count = 4, .first = 18, .last = 22, .list = .USED }", "unexpected result from function", .{});
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzbl12jcm\x0034566dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 0, 6}, // invalid_indexes
//         &.{102, 97, 103}, // invalid_vals
//     );
//     // zig fmt: on
//     slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 0);
//     slice_iter = slice_iter_state.iterator();
//     str = "7890";
//     _ = slice_iter.perform_action_on_all_next_items(Action.set_value_from_string, @ptrCast(&str));
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzbl12789034566dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 0, 6}, // invalid_indexes
//         &.{102, 97, 103}, // invalid_vals
//     );
//     // zig fmt: on
//     slice_result.slide_left(&linked_list, 2);
//     slice_result.grow_end_rightward(&linked_list, 7);
//     var slice_iter_state_with_slot = slice_result.new_iterator_state_at_start_of_slice(&linked_list, 1);
//     slice_iter = slice_iter_state_with_slot.iterator();
//     InsertionSort.insertion_sort_iterator(TestElem, slice_iter, Action.move_data, Action.greater_than, null);
//     // zig fmt: off
//     try expect.full_ll_state(
//         &linked_list,
//         &.{ 19, 11, 7, 8, 1, 16, 17, 10, 18, 2, 15, 22, 12, 13, 14, 20, 21, 3, 4, 9}, // used_indexes
//         "wxyzbl01234566789dev", // used_vals
//         &.{ }, // free_indexes
//         &.{ }, // free_vals
//         &.{5, 0, 6}, // invalid_indexes
//         &.{102, 97, 103}, // invalid_vals
//     );
//     // zig fmt: on
// }
