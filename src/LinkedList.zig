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

const build = @import("builtin");
const std = @import("std");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const assert_pointer_resides_in_slice = Assert.assert_pointer_resides_in_slice;
const assert_slice_resides_in_slice = Assert.assert_slice_resides_in_slice;
const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
const assert_idx_and_pointer_reside_in_slice_and_match = Assert.assert_idx_and_pointer_reside_in_slice_and_match;
const Utils = Root.Utils;
const debug_switch = Utils.debug_switch;
const safe_switch = Utils.safe_switch;
const comp_switch = Utils.comp_switch;
const Types = Root.Types;
const Iterator = Root.Iterator.Iterator;
const FlexSlice = Root.FlexSlice.FlexSlice;
const Mutability = Root.CommonTypes.Mutability;
const Quicksort = Root.Quicksort;
const Pivot = Quicksort.Pivot;
const InsertionSort = Root.InsertionSort;
const insertion_sort = InsertionSort.insertion_sort;
const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const DummyAllocator = Root.DummyAllocator;
const BinarySearch = Root.BinarySearch;

const DEBUG = build.mode == .Debug;

pub const LinkedListOptions = struct {
    list_options: Root.List.ListOptions,
    forward_linkage: ?[]const u8 = null,
    backward_linkage: ?[]const u8 = null,
    element_list_access: ?ElementStateAccess = null,
    element_idx_cache_field: ?[]const u8 = null,
    force_cache_last_index: bool = true,
    force_cache_first_index: bool = true,
    /// This enum must list all desired linked sets ('used', 'free', etc...)
    /// with tag values starting from 0 and increasing with no gaps
    linked_set_enum: type = DefaultSet,
    /// Inserts additional (usually O(N) time) asserts in comptime, Debug, or ReleaseSafe
    stronger_asserts: bool = false,
};

pub const DefaultSet = enum(u8) {
    USED = 0,
    FREE = 1,
};

pub const ElementStateAccess = struct {
    field: []const u8,
    field_type: type,
    field_bit_offset: comptime_int,
    field_bit_count: comptime_int,
};

pub const Direction = enum {
    FORWARD,
    BACKWARD,
};

pub const IterDirection = enum {
    FORWARD,
    BACKWARD,
    BI_DIRECTIONAL,
};

// const ERR_START_PLUS_COUNT_OOB = "start ({d}) + count ({d}) == {d}, which is out of bounds for list.len ({d})";

/// This is the core linked list paradigm, both other paradigms ('static_allocator' and 'cached_allocator')
/// simply call this type's methods and provide their own allocator
pub fn define_manual_allocator_linked_list_type(comptime options: LinkedListOptions) type {
    assert_with_reason(options.forward_linkage != null or options.backward_linkage != null, @src(), "either `forward_linkage` or `backward_linkage` must be provided, both cannot be left null", .{});
    const F = options.forward_linkage != null;
    const B = options.backward_linkage != null;
    const S = options.element_list_access != null;
    const C = options.element_idx_cache_field != null;
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(options.linked_set_enum), @src(), "all enum tag values in linked_set_enum must start from zero and increase with no gaps between values", .{});
    if (F) {
        const F_FIELD = options.forward_linkage.?;
        assert_with_reason(@hasField(options.list_options.element_type, F_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), F_FIELD });
        const F_TYPE = @FieldType(options.list_options.element_type, F_FIELD);
        assert_with_reason(Types.type_is_int(F_TYPE), @src(), "next index field `.{s}` on element type `{s}` is not an integer type", .{ F_FIELD, @typeName(options.list_options.element_type) });
        assert_with_reason(F_TYPE == options.list_options.index_type, @src(), "next index field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ F_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
    }
    if (B) {
        const B_FIELD = options.backward_linkage.?;
        assert_with_reason(@hasField(options.list_options.element_type, B_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), B_FIELD });
        const B_TYPE = @FieldType(options.list_options.element_type, B_FIELD);
        assert_with_reason(Types.type_is_int(B_TYPE), @src(), "prev index field `.{s}` on element type `{s}` is not an integer type", .{ B_FIELD, @typeName(options.list_options.element_type) });
        assert_with_reason(B_TYPE == options.list_options.index_type, @src(), "prev index field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ B_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
    }
    if (S) {
        const S_FIELD = options.element_list_access.?.field;
        assert_with_reason(@hasField(options.list_options.element_type, S_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), S_FIELD });
        const S_TYPE = @FieldType(options.list_options.element_type, S_FIELD);
        assert_with_reason(Types.type_is_int(S_TYPE), @src(), "element list field `.{s}` on element type `{s}` is not an integer type", .{ S_FIELD, @typeName(options.list_options.element_type) });
        assert_with_reason(S_TYPE == options.element_list_access.?.field_type, @src(), "element list field `.{s}` on element type `{s}` does not match listd type {s}", .{ S_FIELD, @typeName(options.list_options.element_type), @typeName(options.element_list_access.?.field_type) });
        const tag_count = Types.enum_max_field_count(options.linked_set_enum);
        const flag_count = 1 << options.element_list_access.?.field_bit_count;
        assert_with_reason(flag_count >= tag_count, @src(), "options.element_list_access.field_bit_count {d} (max val = {d}) cannot hold all tag values for options.linked_set_enum {d}", .{ options.element_list_access.?.field_bit_count, flag_count, tag_count });
    }
    if (C) {
        const C_FIELD = options.element_idx_cache_field.?;
        assert_with_reason(@hasField(options.list_options.element_type, C_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), C_FIELD });
        const C_TYPE = @FieldType(options.list_options.element_type, C_FIELD);
        assert_with_reason(C_TYPE == options.list_options.index_type, @src(), "element list field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ C_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
    }
    return struct {
        list: BaseList = BaseList.UNINIT,
        sets: [SET_COUNT]ListData = UNINIT_SETS,

        const STRONG_ASSERT = options.stronger_asserts;
        const SET_COUNT = Types.enum_defined_field_count(options.linked_set_enum);
        const FORWARD = options.forward_linkage != null;
        const HEAD_NO_FORWARD = HEAD and !FORWARD;
        const NEXT_FIELD = if (FORWARD) options.forward_linkage.? else "";
        const BACKWARD = options.backward_linkage != null;
        const TAIL_NO_BACKWARD = TAIL and !BACKWARD;
        const BIDIRECTION = BACKWARD and FORWARD;
        const HEAD = FORWARD or options.force_cache_first_index;
        const TAIL = BACKWARD or options.force_cache_last_index;
        const PREV_FIELD = if (BACKWARD) options.backward_linkage.? else "";
        const USED = options.linked_sets == .USED_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        const FREE = options.linked_sets == .FREE_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        const STATE = options.element_list_access != null;
        const CACHE = options.element_idx_cache_field != null;
        const CACHE_FIELD = if (CACHE) options.element_idx_cache_field.? else "";
        const T_STATE_FIELD = if (STATE) options.element_list_access.?.field_type else void;
        const STATE_FIELD = if (STATE) options.element_list_access.?.field else "";
        const STATE_OFFSET = if (STATE) options.element_list_access.?.field_bit_offset else 0;
        const UNINIT = LinkedList{};
        const RETURN_ERRORS = options.list_options.alloc_error_behavior == .RETURN_ERRORS;
        const NULL_IDX = math.maxInt(Idx);
        const MAX_STATE_TAG = Types.enum_max_value(List);
        const STATE_MASK: if (STATE) options.element_list_access.?.field_type else comptime_int = if (STATE) build: {
            const mask_unshifted = (1 << options.element_list_access.?.field_bit_count) - 1;
            break :build mask_unshifted << options.element_list_access.?.field_bit_offset;
        } else 0;
        const STATE_CLEAR_MASK: if (STATE) options.element_list_access.?.field_type else comptime_int = if (STATE) ~STATE_MASK else 0b1111111111111111111111111111111111111111111111111111111111111111;
        const HEAD_TAIL: u2 = (@as(u2, @intFromBool(HEAD)) << 1) | @as(u2, @intFromBool(TAIL));
        const HAS_HEAD_HAS_TAIL: u2 = 0b11;
        const HAS_HEAD_NO_TAIL: u2 = 0b10;
        const NO_HEAD_HAS_TAIL: u2 = 0b01;
        const UNINIT_SETS: [SET_COUNT]ListData = build: {
            var sets: [SET_COUNT]ListData = undefined;
            for (0..SET_COUNT) |idx| {
                sets[idx] = ListData{};
            }
            break :build sets;
        };

        const LinkedList = @This();
        pub const BaseList = Root.List.define_manual_allocator_list_type(options.list_options);
        pub const Error = Allocator.Error;
        pub const Elem = options.list_options.element_type;
        pub const Idx = options.list_options.index_type;
        // pub const Iterator = LinkedListIterator(List);
        pub const List = options.linked_set_enum;
        const ListTag = Types.enum_tag_type(List);
        pub const ListData = switch (HEAD_TAIL) {
            HAS_HEAD_HAS_TAIL => struct {
                first_idx: Idx = NULL_IDX,
                last_idx: Idx = NULL_IDX,
                count: Idx = 0,
            },
            HAS_HEAD_NO_TAIL => struct {
                first_idx: Idx = NULL_IDX,
                count: Idx = 0,
            },
            NO_HEAD_HAS_TAIL => struct {
                last_idx: Idx = NULL_IDX,
                count: Idx = 0,
            },
            else => unreachable,
        };
        pub const IndexesInSameList = struct {
            list: List,
            idxs: []const Idx,

            pub inline fn new(list: List, idxs: []const Idx) IndexesInSameList {
                return IndexesInSameList{ .list = list, .idxs = idxs };
            }
        };
        const IdxPtrIdx = struct {
            idx_ptr: *Idx = &DUMMY_IDX,
            idx: Idx = NULL_IDX,
        };
        const ConnLeft = choose: {
            if (BIDIRECTION) break :choose IdxPtrIdx;
            if (FORWARD) break :choose *Idx;
            if (BACKWARD) break :choose Idx;
            unreachable;
        };
        const ConnRight = choose: {
            if (BIDIRECTION) break :choose IdxPtrIdx;
            if (FORWARD) break :choose Idx;
            if (BACKWARD) break :choose *Idx;
            unreachable;
        };
        const ConnLeftRight = struct {
            left: ConnLeft,
            right: ConnRight,

            pub inline fn new(left: ConnLeft, right: ConnRight) ConnLeftRight {
                return ConnLeftRight{ .left = left, .right = right };
            }
        };
        const ConnInsert = struct {
            first: ConnRight,
            last: ConnLeft,

            pub inline fn new(first: ConnRight, last: ConnLeft) ConnInsert {
                return ConnInsert{ .first = first, .last = last };
            }
        };
        const ConnData = struct {
            list: List,
            edges: ConnLeftRight,
            count: Idx,
        };
        pub const IndexInList = struct {
            list: List,
            idx: Idx,

            pub inline fn new(list: List, idx: Idx) IndexInList {
                return IndexInList{ .list = list, .idx = idx };
            }
        };
        pub const CountFromList = struct {
            list: List,
            count: Idx,

            pub inline fn new(list: List, count: Idx) CountFromList {
                return CountFromList{ .list = list, .count = count };
            }
        };
        var DUMMY_IDX: Idx = NULL_IDX;
        var DUMMY_ELEM: Elem = undefined;

        pub const GetMode = enum {
            CREATE_ONE_NEW,
            FIRST_FROM_LIST_ELSE_CREATE_NEW,
            LAST_FROM_LIST_ELSE_CREATE_NEW,
            FIRST_FROM_LIST,
            LAST_FROM_LIST,
            ONE_INDEX,
            CREATE_MANY_NEW,
            FIRST_N_FROM_LIST,
            LAST_N_FROM_LIST,
            FIRST_N_FROM_LIST_ELSE_CREATE_NEW,
            LAST_N_FROM_LIST_ELSE_CREATE_NEW,
            SPARSE_LIST_FROM_SAME_SET,
            SPARSE_LIST_FROM_ANY_SET,
            FROM_SLICE,
            FROM_SLICE_ELSE_CREATE_NEW,
        };

        pub fn GetVal(comptime M: GetMode) type {
            return switch (M) {
                .FIRST_FROM_LIST, .FIRST_FROM_LIST_ELSE_CREATE_NEW, .LAST_FROM_LIST, .LAST_FROM_LIST_ELSE_CREATE_NEW => List,
                .FIRST_N_FROM_LIST, .FIRST_N_FROM_LIST_ELSE_CREATE_NEW, .LAST_N_FROM_LIST, .LAST_N_FROM_LIST_ELSE_CREATE_NEW => CountFromList,
                .CREATE_ONE_NEW => void,
                .ONE_INDEX => IndexInList,
                .CREATE_MANY_NEW => Idx,
                .FROM_SLICE => LLSlice,
                .FROM_SLICE_ELSE_CREATE_NEW => LLSliceWithTotalNeeded,
                .SPARSE_LIST_FROM_SAME_SET => IndexesInSameList,
                .SPARSE_LIST_FROM_ANY_SET => []const IndexInList,
            };
        }

        pub const InsertMode = enum {
            AT_BEGINNING_OF_LIST,
            AT_END_OF_LIST,
            AFTER_INDEX,
            BEFORE_INDEX,
        };

        pub fn InsertVal(comptime M: InsertMode) type {
            return switch (M) {
                .AT_BEGINNING_OF_LIST, .AT_END_OF_LIST => List,
                .AFTER_INDEX, .BEFORE_INDEX => IndexInList,
            };
        }

        /// Represents a slice of logical items in a Linked List
        ///
        /// Manually altering its internal fields should be considered unsafe if done incorrectly,
        /// use the provided methods on
        pub const LLSlice = struct {
            list: List,
            first: Idx = NULL_IDX,
            last: Idx = NULL_IDX,
            count: Idx = 0,

            pub inline fn single(list: List, idx: Idx) LLSlice {
                return LLSlice{
                    .list = list,
                    .first = idx,
                    .last = idx,
                    .count = 1,
                };
            }

            pub inline fn new(list: List, first: Idx, last: Idx, count: Idx) LLSlice {
                return LLSlice{
                    .list = list,
                    .first = first,
                    .last = last,
                    .count = count,
                };
            }

            pub inline fn to_slice_with_total_needed(self: LLSlice, total_needed: Idx) LLSliceWithTotalNeeded {
                return LLSliceWithTotalNeeded{
                    .total_needed = total_needed,
                    .slice = self,
                };
            }

            pub fn grow_end_rightward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                const new_last = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.list, self.last, count, false, 0);
                self.count += count;
                self.last = new_last;
            }

            pub fn shrink_end_leftward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                const new_last = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.list, self.last, count, true, self.first);
                self.count += count;
                self.last = new_last;
            }

            pub fn grow_start_leftward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                const new_first = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.list, self.first, count, false, 0);
                self.count += count;
                self.first = new_first;
            }

            pub fn shrink_start_rightward(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                const new_first = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.list, self.first, count, true, self.last);
                self.count += count;
                self.first = new_first;
            }

            pub fn slide_right(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                self.grow_end_rightward(list, count);
                self.shrink_start_rightward(list, count);
            }

            pub fn slide_left(self: *LLSlice, list: *const LinkedList, count: Idx) void {
                self.grow_start_leftward(list, count);
                self.shrink_end_leftward(list, count);
            }

            pub const SliceIteratorState = struct {
                linked_list: *LinkedList,
                slice: *const LLSlice,
                left_idx: Idx,
                right_idx: Idx,

                pub fn iterator(self: *SliceIteratorState) Iterator(Elem) {
                    return Iterator(Elem){
                        .implementor = @ptrCast(self),
                        .vtable = &Iterator(Elem).VTable{
                            .reset = s_iter_reset,
                            .advance_next = s_iter_advance_next,
                            .peek_next_or_null = s_iter_peek_next_or_null,
                            .advance_prev = s_iter_advance_prev,
                            .peek_prev_or_null = s_iter_peek_prev_or_null,
                        },
                    };
                }
            };

            fn s_iter_peek_prev_or_null(self: *anyopaque) ?*Elem {
                if (!BACKWARD) return false;
                const iter: *SliceIteratorState = @ptrCast(@alignCast(self));
                if (iter.left_idx == NULL_IDX or iter.right_idx == iter.slice.first) return null;
                return iter.linked_list.get_ptr(iter.left_idx);
            }
            fn s_iter_advance_prev(self: *anyopaque) bool {
                if (!BACKWARD) return false;
                const iter: *SliceIteratorState = @ptrCast(@alignCast(self));
                if (iter.left_idx == NULL_IDX or iter.right_idx == iter.slice.first) return false;
                iter.left_idx = iter.linked_list.get_prev_idx(iter.slice.list, iter.left_idx);
                return true;
            }
            fn s_iter_peek_next_or_null(self: *anyopaque) ?*Elem {
                if (!FORWARD) return false;
                const iter: *SliceIteratorState = @ptrCast(@alignCast(self));
                if (iter.right_idx == NULL_IDX or iter.left_idx == iter.slice.last) return null;
                return iter.linked_list.get_ptr(iter.right_idx);
            }
            fn s_iter_advance_next(self: *anyopaque) bool {
                if (!FORWARD) return false;
                const iter: *SliceIteratorState = @ptrCast(@alignCast(self));
                if (iter.right_idx == NULL_IDX or iter.left_idx == iter.slice.last) return false;
                iter.right_idx = iter.linked_list.get_next_idx(iter.slice.list, iter.right_idx);
                return true;
            }
            fn s_iter_reset(self: *anyopaque) void {
                const iter: *SliceIteratorState = @ptrCast(@alignCast(self));
                if (FORWARD) {
                    iter.right_idx = iter.slice.first;
                    iter.left_idx = NULL_IDX;
                } else {
                    iter.left_idx = iter.slice.last;
                    iter.right_idx = NULL_IDX;
                }
            }

            pub inline fn new_iterator_state_at_start_of_slice(self: *const LLSlice, linked_list: *LinkedList) SliceIteratorState {
                return SliceIteratorState{
                    .linked_list = linked_list,
                    .slice = self,
                    .left_idx = NULL_IDX,
                    .right_idx = if (FORWARD) self.first else NULL_IDX,
                };
            }
            pub inline fn new_iterator_state_at_end_of_slice(self: *const LLSlice, linked_list: *LinkedList) SliceIteratorState {
                return SliceIteratorState{
                    .linked_list = linked_list,
                    .slice = self,
                    .left_idx = if (BACKWARD) self.last else NULL_IDX,
                    .right_idx = NULL_IDX,
                };
            }
        };

        /// Variant of `LLSlice` used for the purpose of supplying a function
        /// with arbitrary items to draw from before any new items are created
        pub const LLSliceWithTotalNeeded = struct {
            slice: LLSlice,
            total_needed: Idx,
        };

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked list list
        /// - Are only useful for asserting/creating intenal list
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate special user use cases
        pub const Internal = struct {
            pub fn find_idx_n_places_after_this_one_with_fallback_start(self: *const LinkedList, list: List, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
                if (FORWARD) {
                    return traverse_forward_to_find_idx_n_places_after_this_one(self, list, idx, count);
                } else {
                    return traverse_backward_to_find_idx_n_places_after_this_one_start_at(self, list, idx, count, use_fallback_start, fallback_start_idx);
                }
            }

            pub fn find_idx_n_places_before_this_one_with_fallback_start(self: *const LinkedList, list: List, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
                if (BACKWARD) {
                    return traverse_backward_to_find_idx_n_places_before_this_one(self, list, idx, count);
                } else {
                    return traverse_forward_to_find_idx_n_places_before_this_one_start_at(self, list, idx, count, use_fallback_start, fallback_start_idx);
                }
            }

            pub fn traverse_forward_to_find_idx_n_places_after_this_one(self: *const LinkedList, list: List, idx: Idx, count: Idx) Idx {
                var delta: Idx = 0;
                var result: Idx = idx;
                while (delta < count and result != idx and result != NULL_IDX) {
                    result = self.get_next_idx(result);
                    delta += 1;
                }
                assert_with_reason(result != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(list) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(list), delta });
                return result;
            }

            pub fn traverse_backward_to_find_idx_n_places_before_this_one(self: *const LinkedList, list: List, idx: Idx, count: Idx) Idx {
                var delta: Idx = 0;
                var result: Idx = idx;
                while (delta < count and result != idx and result != NULL_IDX) {
                    result = self.get_prev_idx(result);
                    delta += 1;
                }
                assert_with_reason(result != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(list) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(list), delta });
                return result;
            }

            pub fn traverse_backward_to_find_idx_n_places_after_this_one_start_at(self: *const LinkedList, list: List, idx: Idx, count: Idx, comptime use_start: bool, start: Idx) Idx {
                var delta: Idx = 0;
                var probe: Idx = if (use_start) start else self.get_last_index_in_list(list);
                var result: Idx = probe;
                while (delta < count and probe != idx and probe != NULL_IDX) {
                    probe = Internal.self.get_prev_idx(probe);
                    delta += 1;
                }
                assert_with_reason(probe != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(list) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(list), delta });
                while (probe != idx) {
                    probe = Internal.self.get_prev_idx(probe);
                    result = Internal.self.get_prev_idx(result);
                }
                return result;
            }

            pub fn traverse_forward_to_find_idx_n_places_before_this_one_start_at(self: *const LinkedList, list: List, idx: Idx, count: Idx, comptime use_start: bool, start: Idx) Idx {
                var delta: Idx = 0;
                var probe: Idx = if (use_start) start else self.get_first_index_in_list(list);
                var result: Idx = probe;
                while (delta < count and probe != idx and probe != NULL_IDX) {
                    probe = self.get_next_idx(probe);
                    delta += 1;
                }
                assert_with_reason(probe != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(list) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items before idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(list), delta });
                while (probe != idx) {
                    probe = self.get_next_idx(probe);
                    result = self.get_next_idx(result);
                }
                return result;
            }

            pub inline fn set_idx(ptr: *Elem, idx: Idx) void {
                if (CACHE) @field(ptr, CACHE_FIELD) = idx;
            }

            pub inline fn increase_link_set_count(self: *LinkedList, list: List, amount: Idx) void {
                self.sets[@intFromEnum(list)].count += amount;
            }

            pub inline fn decrease_link_set_count(self: *LinkedList, list: List, amount: Idx) void {
                self.sets[@intFromEnum(list)].count -= amount;
            }

            pub inline fn set_list(ptr: *Elem, list: List) void {
                if (STATE) {
                    @field(ptr, STATE_FIELD) &= STATE_CLEAR_MASK;
                    const new_list: T_STATE_FIELD = @as(T_STATE_FIELD, @intCast(@intFromEnum(list)));
                    const new_list_shifted = new_list << STATE_OFFSET;
                    @field(ptr, STATE_FIELD) |= new_list_shifted;
                }
            }

            pub fn set_list_on_indexes_first_last(self: *LinkedList, first_idx: Idx, last_idx: Idx, list: List) void {
                if (!STATE) return;
                var idx = if (FORWARD) first_idx else last_idx;
                const final_idx = if (FORWARD) last_idx else first_idx;
                while (true) {
                    const ptr = get_ptr(self, idx);
                    set_list(ptr, list);
                    if (idx == final_idx) break;
                    idx = if (FORWARD) self.get_next_idx(list, idx) else self.get_prev_idx(list, idx);
                }
            }

            pub fn link_new_indexes_and_set_idx_cache(self: *LinkedList, list: List, first_idx: Idx, last_idx: Idx) void {
                var left_idx = first_idx;
                var right_idx = first_idx + 1;
                if (CACHE) {
                    const ptr = self.get_ptr(left_idx);
                    set_idx(ptr, left_idx);
                }
                while (right_idx <= last_idx) {
                    if (CACHE) {
                        const ptr = self.get_ptr(right_idx);
                        set_idx(ptr, right_idx);
                    }
                    const left = Internal.get_conn_left(self, list, left_idx);
                    const right = Internal.get_conn_right(self, list, right_idx);
                    connect(left, right);
                    left_idx += 1;
                    right_idx += 1;
                }
            }

            pub fn disconnect_one(self: *LinkedList, list: List, idx: Idx) void {
                const disconn = Internal.get_conn_left_right_before_first_and_after_last(self, idx, idx, list);
                Internal.connect(disconn.left, disconn.right);
                Internal.decrease_link_set_count(self, list, 1);
            }

            pub fn disconnect_many_first_last(self: *LinkedList, list: List, first_idx: Idx, last_idx: Idx, count: Idx) void {
                const disconn = Internal.get_conn_left_right_before_first_and_after_last(self, first_idx, last_idx, list);
                Internal.connect(disconn.left, disconn.right);
                Internal.decrease_link_set_count(self, list, count);
            }

            pub inline fn connect_with_insert(left_edge: ConnLeft, first_insert: ConnRight, last_insert: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        left_edge.idx_ptr.* = first_insert.idx;
                        last_insert.idx_ptr.* = right_edge.idx;
                    } else {
                        left_edge.* = first_insert;
                        last_insert.* = right_edge;
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        right_edge.idx_ptr.* = last_insert.idx;
                        first_insert.idx_ptr.* = left_edge.idx;
                    } else {
                        right_edge.* = last_insert;
                        first_insert.* = left_edge;
                    }
                }
            }

            pub inline fn connect(left_edge: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        left_edge.idx_ptr.* = right_edge.idx;
                    } else {
                        left_edge.* = right_edge;
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        right_edge.idx_ptr.* = left_edge.idx;
                    } else {
                        right_edge.* = left_edge;
                    }
                }
            }

            pub inline fn get_conn_left(self: *LinkedList, list: List, idx: Idx) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .idx_ptr = if (idx == NULL_IDX) get_head_index_ref(self, list) else &@field(get_ptr(self, idx), NEXT_FIELD),
                };
                if (FORWARD) if (idx == NULL_IDX) get_head_index_ref(self, list) else &@field(get_ptr(self, idx), NEXT_FIELD);
                if (BACKWARD) return idx;
            }

            pub inline fn get_conn_left_from_set_head(self: *LinkedList, list: List) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_head_index_ref(self, list),
                };
                if (FORWARD) return get_head_index_ref(self, list);
                if (BACKWARD) return NULL_IDX;
            }

            pub inline fn get_conn_right(self: *LinkedList, list: List, idx: Idx) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .idx_ptr = if (idx == NULL_IDX) get_tail_index_ref(self, list) else &@field(get_ptr(self, idx), PREV_FIELD),
                };
                if (FORWARD) return idx;
                if (BACKWARD) return if (idx == NULL_IDX) get_tail_index_ref(self, list) else &@field(get_ptr(self, idx), PREV_FIELD);
            }

            pub inline fn get_conn_right_from_set_tail(self: *LinkedList, list: List) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_tail_index_ref(self, list),
                };
                if (FORWARD) return NULL_IDX;
                if (BACKWARD) return get_tail_index_ref(self, list);
            }

            pub inline fn get_head_index_ref(self: *LinkedList, list: List) *Idx {
                return &self.sets[@intFromEnum(list)].first_idx;
            }

            pub inline fn get_tail_index_ref(self: *LinkedList, list: List) *Idx {
                return &self.sets[@intFromEnum(list)].last_idx;
            }

            pub fn get_conn_left_right_directly_before_this(self: *LinkedList, this: Idx, list: List) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_right(self, list, this);
                const prev_idx = self.get_next_idx(self, list, this);
                result.right = Internal.get_conn_right(self, list, prev_idx);
                return result;
            }

            pub fn get_conn_left_right_directly_after_this(self: *LinkedList, this: Idx, list: List) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_left(self, list, this);
                const next_idx = Internal.get_next_idx(self, list, this);
                result.right = Internal.get_conn_right(self, list, next_idx);
                return result;
            }

            pub fn get_conn_left_right_before_first_and_after_last(self: *LinkedList, first: Idx, last: Idx, list: List) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                const left_idx = self.get_prev_idx(list, first);
                result.left = Internal.get_conn_left(self, list, left_idx);
                const next_idx = self.get_next_idx(list, last);
                result.right = Internal.get_conn_right(self, list, next_idx);
                return result;
            }

            pub fn get_conn_left_right_for_tail_of_set(self: *LinkedList, list: List) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.right = Internal.get_conn_right_from_set_tail(self, list);
                const last_index = self.get_last_index_in_list(list);
                result.left = Internal.get_conn_left(self, list, last_index);
                return result;
            }

            pub fn get_conn_left_right_for_head_of_set(self: *LinkedList, list: List) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_left_from_set_head(self, list);
                const first_index = self.get_first_index_in_list(list);
                result.right = Internal.get_conn_right(self, list, first_index);
                return result;
            }

            pub fn traverse_to_get_first_idx_in_set(self: *const LinkedList, list: List) Idx {
                var ii: Idx = NULL_IDX;
                var i = self.get_last_index_in_list(list);
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_list_len(list) else void{};
                while (i != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = get_prev_idx(self, list, i);
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `BACKWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(list), c, limit });
                return ii;
            }

            pub fn traverse_to_get_last_item_in_set(self: *const LinkedList, list: List) Idx {
                var ii: Idx = NULL_IDX;
                var i = self.get_first_index_in_list(list);
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_list_len(list) else void{};
                while (i != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = get_next_idx(self, list, i.ptr);
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `FORWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(list), c, limit });
                return ii;
            }

            pub fn traverse_and_report_if_found_idx_in_set(self: *LinkedList, list: List, idx: Idx) bool {
                var i: Idx = if (FORWARD) self.get_first_index_in_list(list) else self.get_last_index_in_list(list);
                var c: Idx = 0;
                const limit: Idx = self.get_list_len(list);
                while (i != NULL_IDX and (if (DEBUG) c < limit else true)) {
                    if (i == idx) return true;
                    i = if (FORWARD) get_next_idx(self, list, i) else get_prev_idx(self, list, i);
                    if (DEBUG) c += 1;
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(list), c, limit });
                return false;
            }

            pub fn traverse_to_find_index_preceding_this_one_in_direction(self: LinkedList, idx: Idx, list: List, comptime dir: Direction) Idx {
                var curr_idx: Idx = undefined;
                var count: Idx = 0;
                const limit = self.get_list_len(list);
                switch (dir) {
                    .BACKWARD => {
                        assert_with_reason(BACKWARD, @src(), "linked list does not link elements in the backward direction", .{});
                        curr_idx = self.get_last_index_in_list(list);
                    },
                    .FORWARD => {
                        assert_with_reason(FORWARD, @src(), "linked list does not link elements in the forward direction", .{});
                        curr_idx = self.get_first_index_in_list(list);
                    },
                }
                while (curr_idx != NULL_IDX) {
                    if (DEBUG) assert_with_reason(count < limit, @src(), "already traversed {d} (total set count) items in set `{s}`, but there are more non-null indexes after the last", .{ limit, @tagName(list) });
                    assert_with_reason(curr_idx < self.list.len, @src(), "while traversing set `{s}` in direction `{s}`, index {d} was found, which is out of bounds for list.len {d}", .{ @tagName(list), @tagName(dir), curr_idx, self.list.len });
                    const following_idx = switch (dir) {
                        .FORWARD => get_next_idx(self, list, curr_idx),
                        .BACKWARD => get_prev_idx(self, list, curr_idx),
                    };
                    if (following_idx == idx) return curr_idx;
                    curr_idx = following_idx;
                    if (DEBUG) count += 1;
                }
                if (DEBUG) assert_with_reason(count == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})\nALSO: no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ @tagName(list), count, limit, idx, @tagName(list), @tagName(dir) });
                assert_with_reason(false, @src(), "no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ idx, @tagName(list), @tagName(dir) });
            }

            pub inline fn get_list_raw(ptr: *const Elem) ListTag {
                return @as(ListTag, @intCast((@field(ptr, STATE_FIELD) & STATE_MASK) >> STATE_OFFSET));
            }

            pub fn assert_valid_list_idx(self: *const LinkedList, list_idx: IndexInList, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    assert_idx_less_than_len(list_idx.idx, self.list.len, src_loc);
                    const ptr = get_ptr(self, list_idx.idx);
                    if (STATE) assert_with_reason(get_list_raw(ptr) == @intFromEnum(list_idx.list), src_loc, "set {s} on SetIdx does not match list on elem at idx {d}", .{ @tagName(list_idx.list), list_idx.idx });
                    if (STRONG_ASSERT) {
                        const found_in_list = Internal.traverse_and_report_if_found_idx_in_set(self, list_idx.list, list_idx.idx);
                        assert_with_reason(found_in_list, src_loc, "while verifying idx {d} is in set {s}, the idx was not found when traversing the set", .{ list_idx.idx, @tagName(list_idx.set) });
                    }
                }
            }
            pub fn assert_valid_list_idx_list(self: *const LinkedList, set_idx_list: IndexesInSameList, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    for (set_idx_list.idxs) |idx| {
                        Internal.assert_valid_list_idx(self, IndexInList{ .set = set_idx_list.set, .idx = idx }, src_loc);
                    }
                }
            }
            pub fn assert_valid_list_of_list_idxs(self: *const LinkedList, set_idx_list: []const IndexInList, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    for (set_idx_list) |set_idx_| {
                        Internal.assert_valid_list_idx(self, set_idx_, src_loc);
                    }
                }
            }

            pub fn assert_valid_slice(self: *const LinkedList, slice: LLSlice, src_loc: ?SourceLocation) void {
                assert_idx_less_than_len(slice.first, self.list.len, src_loc);
                assert_idx_less_than_len(slice.last, self.list.len, src_loc);
                if (!STRONG_ASSERT and STATE) {
                    assert_with_reason(self.idx_is_in_list(slice.first, slice.list), src_loc, "first index {d} is not in list `{s}`", .{ slice.first, @tagName(slice.list) });
                    assert_with_reason(self.idx_is_in_list(slice.last, slice.list), src_loc, "last index {d} is not in list `{s}`", .{ slice.last, @tagName(slice.list) });
                }
                if (STRONG_ASSERT) {
                    var c: Idx = 1;
                    var idx = if (FORWARD) slice.first else slice.last;
                    assert_idx_less_than_len(idx, self.list.len, @src());
                    const list = slice.list;
                    const last_idx = if (FORWARD) slice.last else slice.first;
                    Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
                    while (idx != last_idx and idx != NULL_IDX) {
                        idx = if (FORWARD) self.get_next_idx(idx) else self.get_prev_idx(idx);
                        c += 1;
                        Internal.assert_valid_list_idx(self, IndexInList{ .list = list, .idx = idx }, src_loc);
                    }
                    assert_with_reason(idx == last_idx, src_loc, "idx `first` ({d}) is not linked with idx `last` ({d})", .{ slice.first, slice.last });
                    assert_with_reason(c == slice.count, src_loc, "the slice count {d} did not match the number of traversed items between `first` and `last` ({d})", .{ slice.count, c });
                }
            }

            fn get_items_and_insert_at_internal(self: *LinkedList, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime insert_mode: InsertMode, insert_val: InsertVal(insert_mode), alloc: Allocator, comptime ASSUME_CAP: bool) if (!ASSUME_CAP and RETURN_ERRORS) Error!LLSlice else LLSlice {
                var insert_edges: ConnLeftRight = undefined;
                var insert_list: List = undefined;
                switch (insert_mode) {
                    .AFTER_INDEX => {
                        const list_idx: IndexInList = insert_val;
                        Internal.assert_valid_list_idx(self, list_idx, @src());
                        insert_edges = Internal.get_conn_left_right_directly_after_this(self, list_idx.idx, list_idx.list);
                        insert_list = list_idx.list;
                    },
                    .BEFORE_INDEX => {
                        const list_idx: IndexInList = insert_val;
                        Internal.assert_valid_list_idx(self, list_idx, @src());
                        insert_edges = Internal.get_conn_left_right_directly_before_this(self, list_idx.idx, list_idx.list);
                        insert_list = list_idx.list;
                    },
                    .AT_BEGINNING_OF_LIST => {
                        const list: List = insert_val;
                        insert_edges = Internal.get_conn_left_right_for_head_of_set(self, list);
                        insert_list = list;
                    },
                    .AT_END_OF_LIST => {
                        const list: List = insert_val;
                        insert_edges = Internal.get_conn_left_right_for_tail_of_set(self, list);
                        insert_list = list;
                    },
                }
                var return_items: LLSlice = undefined;
                switch (get_mode) {
                    .CREATE_ONE_NEW => {
                        const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                        return_items.first = new_idx;
                        return_items.last = new_idx;
                        return_items.count = 1;
                    },
                    .FIRST_FROM_LIST, .FIRST_FROM_LIST_ELSE_CREATE_NEW => {
                        const list: List = get_val;
                        const list_count: debug_switch(Idx, void) = debug_switch(self.get_list_len(list), void{});
                        const first_idx = self.get_first_index_in_list(list);
                        if (get_mode == .FIRST_FROM_LIST_ELSE_CREATE_NEW and (debug_switch(list_count == 0, false) or first_idx == NULL_IDX)) {
                            const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                            return_items.first = new_idx;
                            return_items.last = new_idx;
                            return_items.count = 1;
                        } else {
                            assert_with_reason(debug_switch(list_count > 0, true) and first_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), first_idx, self.list.len });
                            return_items.first = first_idx;
                            return_items.last = first_idx;
                            return_items.count = 1;
                            Internal.disconnect_one(self, list, first_idx);
                        }
                    },
                    .LAST_FROM_LIST, .LAST_FROM_LIST_ELSE_CREATE_NEW => {
                        const list: List = get_val;
                        const list_count: debug_switch(Idx, void) = debug_switch(self.get_list_len(list), void{});
                        const last_idx = self.get_last_index_in_list(list);
                        if (get_mode == .LAST_FROM_LIST_ELSE_CREATE_NEW and (debug_switch(list_count == 0, false) or last_idx == NULL_IDX)) {
                            const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                            return_items.first = new_idx;
                            return_items.last = new_idx;
                            return_items.count = 1;
                        } else {
                            assert_with_reason(debug_switch(list_count > 0, true) and last_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(list), debug_switch(list_count, 0), last_idx, self.list.len });
                            return_items.first = last_idx;
                            return_items.last = last_idx;
                            return_items.count = 1;
                            Internal.disconnect_one(self, list, last_idx);
                        }
                    },
                    .ONE_INDEX => {
                        const list_idx: IndexInList = get_val;
                        Internal.assert_valid_list_idx(self, list_idx, @src());
                        return_items.first = list_idx.idx;
                        return_items.last = list_idx.idx;
                        return_items.count = 1;
                        Internal.disconnect_one(self, list_idx.set, list_idx.idx);
                    },
                    .CREATE_MANY_NEW => {
                        const count: Idx = get_val;
                        assert_with_reason(count > 0, @src(), "cannot get `0` new items", .{});
                        const first_idx = self.list.len;
                        const last_idx = self.list.len + count - 1;
                        _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count) else (if (RETURN_ERRORS) try self.list.append_many_slots(count, alloc) else self.list.append_many_slots(count, alloc));
                        Internal.link_new_indexes_and_set_idx_cache(self, insert_list, first_idx, last_idx);
                        return_items.first = first_idx;
                        return_items.last = last_idx;
                        return_items.count = count;
                    },
                    .FIRST_N_FROM_LIST => {
                        const list_count: CountFromList = get_val;
                        assert_with_reason(list_count.count > 0, @src(), "cannot get `0` items", .{});
                        assert_with_reason(self.get_list_len(list_count.list) >= list_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ list_count.count, @tagName(list_count.list), self.get_list_len(list_count.list) });
                        return_items.first = self.get_first_index_in_list(list_count.list);
                        return_items.last = self.get_nth_item_from_start_of_list(list_count.list, list_count.count - 1);
                        return_items.count = list_count.count;
                        Internal.disconnect_many_first_last(self, list_count.list, return_items.first, return_items.last, list_count.count);
                    },
                    .LAST_N_FROM_LIST => {
                        const list_count: CountFromList = get_val;
                        assert_with_reason(list_count.count > 0, @src(), "cannot insert `0` items", .{});
                        assert_with_reason(self.get_list_len(list_count.list) >= list_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ list_count.count, @tagName(list_count.list), self.get_list_len(list_count.list) });
                        return_items.last = self.get_last_index_in_list(list_count.list);
                        return_items.first = self.get_nth_item_from_end_of_list(list_count.list, list_count.count - 1);
                        return_items.count = list_count.count;
                        Internal.disconnect_many_first_last(self, list_count.list, return_items.first, return_items.last, list_count.count);
                    },
                    .FIRST_N_FROM_LIST_ELSE_CREATE_NEW => {
                        const list_count: CountFromList = get_val;
                        assert_with_reason(list_count.count > 0, @src(), "cannot insert `0` items", .{});
                        const count_from_list = @max(self.get_list_len(list_count.list), list_count.count);
                        const count_from_new = list_count.count - count_from_list;
                        var first_new_idx: Idx = undefined;
                        var last_moved_idx: Idx = undefined;
                        const needs_new = count_from_new > 0;
                        const needs_move = count_from_list > 0;
                        if (needs_new) {
                            first_new_idx = self.list.len;
                            const last_new_idx = self.list.len + count_from_new - 1;
                            _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                            Internal.link_new_indexes_and_set_idx_cache(self, list_count, first_new_idx, last_new_idx);
                            if (needs_move) {
                                first_new_idx = first_new_idx;
                            } else {
                                return_items.first = first_new_idx;
                            }
                            return_items.last = last_new_idx;
                        }
                        if (needs_move) {
                            return_items.first = self.get_first_index_in_list(list_count.list);
                            if (needs_new) {
                                last_moved_idx = self.get_nth_item_from_start_of_list(list_count.list, count_from_list - 1);
                                Internal.disconnect_many_first_last(self, list_count.list, return_items.first, last_moved_idx, count_from_list);
                            } else {
                                return_items.last = self.get_nth_item_from_start_of_list(list_count.list, count_from_list - 1);
                                Internal.disconnect_many_first_last(self, list_count.list, return_items.first, return_items.last, count_from_list);
                            }
                        }
                        if (needs_new and needs_move) {
                            const mid_left = Internal.get_conn_left(self, list_count.list, last_moved_idx);
                            const mid_right = Internal.get_conn_right(self, list_count.list, first_new_idx);
                            Internal.connect(mid_left, mid_right);
                        }
                        return_items.count = list_count.count;
                    },
                    .LAST_N_FROM_LIST_ELSE_CREATE_NEW => {
                        const list_count: CountFromList = get_val;
                        assert_with_reason(list_count.count > 0, @src(), "cannot insert `0` items", .{});
                        const count_from_list = @max(self.get_list_len(list_count.list), list_count.count);
                        const count_from_new = list_count.count - count_from_list;
                        var first_new_idx: Idx = undefined;
                        var last_moved_idx: Idx = undefined;
                        const needs_new = count_from_new > 0;
                        const needs_move = count_from_list > 0;
                        if (needs_new) {
                            first_new_idx = self.list.len;
                            const last_new_idx = self.list.len + count_from_new - 1;
                            _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                            Internal.link_new_indexes_and_set_idx_cache(self, list_count, first_new_idx, last_new_idx);
                            if (needs_move) {
                                first_new_idx = first_new_idx;
                            } else {
                                return_items.first = first_new_idx;
                            }
                            return_items.last = last_new_idx;
                        }
                        if (needs_move) {
                            return_items.first = self.get_nth_item_from_end_of_list(list_count.list, count_from_list - 1);
                            if (needs_new) {
                                last_moved_idx = self.get_last_index_in_list(list_count.list);
                                Internal.disconnect_many_first_last(self, list_count.list, return_items.first, last_moved_idx, count_from_list);
                            } else {
                                return_items.last = self.get_last_index_in_list(list_count.list);
                                Internal.disconnect_items_first_last(self, list_count.list, return_items.first, return_items.last, count_from_list);
                            }
                        }
                        if (needs_new and needs_move) {
                            const mid_left = Internal.get_conn_left(self, list_count.list, last_moved_idx);
                            const mid_right = Internal.get_conn_right(self, list_count.list, first_new_idx);
                            Internal.connect(mid_left, mid_right);
                        }
                        return_items.count = list_count.count;
                    },
                    .SPARSE_LIST_FROM_SAME_SET => {
                        const list_idx_list: IndexesInSameList = get_val;
                        Internal.assert_valid_list_idx_list(self, list_idx_list, @src());
                        return_items.first = list_idx_list.idxs[0];
                        Internal.disconnect_one(self, list_idx_list.list, return_items.first);
                        var prev_idx: Idx = return_items.first;
                        for (list_idx_list.idxs[1..]) |this_idx| {
                            Internal.disconnect_one(self, list_idx_list.list, this_idx);
                            const conn_left = Internal.get_conn_left(self, list_idx_list.list, prev_idx);
                            const conn_right = Internal.get_conn_right(self, list_idx_list.list, this_idx);
                            Internal.connect(conn_left, conn_right);
                            prev_idx = this_idx;
                        }
                        return_items.last = prev_idx;
                        return_items.count = @intCast(list_idx_list.idxs.len);
                    },
                    .SPARSE_LIST_FROM_ANY_SET => {
                        const list_idxs: []const IndexInList = get_val;
                        Internal.assert_valid_list_of_list_idxs(self, list_idxs, @src());
                        return_items.first = list_idxs[0];
                        Internal.disconnect_one(self, list_idxs[0].list, return_items.first);
                        var prev_idx: Idx = return_items.first;
                        for (list_idxs[1..]) |list_idx| {
                            const this_idx = list_idx.idx;
                            Internal.disconnect_one(self, list_idx.list, this_idx.idx);
                            const conn_left = Internal.get_conn_left(self, list_idx.list, prev_idx);
                            const conn_right = Internal.get_conn_right(self, list_idx.list, this_idx);
                            Internal.connect(conn_left, conn_right);
                            prev_idx = this_idx;
                        }
                        return_items.last = prev_idx;
                        return_items.count = @intCast(list_idxs.len);
                    },
                    .FROM_SLICE => {
                        const slice: LLSlice = get_val;
                        Internal.assert_valid_slice(self, slice, @src());
                        return_items.first = slice.first;
                        return_items.last = slice.last;
                        return_items.count = slice.count;
                    },
                    .FROM_SLICE_ELSE_CREATE_NEW => {
                        const supp_slice: LLSliceWithTotalNeeded = get_val;
                        Internal.assert_valid_slice(self, supp_slice.slice, @src());
                        const count_from_slice = @max(self.get_list_len(supp_slice.slice.count), supp_slice.total_needed);
                        const count_from_new = supp_slice.total_needed - count_from_slice;
                        var first_new_idx: Idx = undefined;
                        var last_moved_idx: Idx = undefined;
                        const needs_new = count_from_new > 0;
                        const needs_move = count_from_slice > 0;
                        if (needs_new) {
                            first_new_idx = self.list.len;
                            const last_new_idx = self.list.len + count_from_new - 1;
                            _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                            Internal.link_new_indexes_and_set_idx_cache(self, supp_slice.slice.list, first_new_idx, last_new_idx);
                            if (needs_move) {
                                first_new_idx = first_new_idx;
                            } else {
                                return_items.first = first_new_idx;
                            }
                            return_items.last = last_new_idx;
                        }
                        if (needs_move) {
                            return_items.first = self.get_nth_item_from_end_of_list(supp_slice.slice.list, count_from_slice - 1);
                            if (needs_new) {
                                last_moved_idx = self.get_last_index_in_list(supp_slice.slice.list);
                                Internal.disconnect_many_first_last(self, supp_slice.slice.list, return_items.first, last_moved_idx, count_from_slice);
                            } else {
                                return_items.last = self.get_last_index_in_list(supp_slice.slice.list);
                                Internal.disconnect_items_first_last(self, supp_slice.slice.list, return_items.first, return_items.last, count_from_slice);
                            }
                        }
                        if (needs_new and needs_move) {
                            const mid_left = Internal.get_conn_left(self, supp_slice.slice.list, last_moved_idx);
                            const mid_right = Internal.get_conn_right(self, supp_slice.slice.list, first_new_idx);
                            Internal.connect(mid_left, mid_right);
                        }
                        return_items.count = supp_slice.total_needed;
                    },
                }
                const insert_first = Internal.get_conn_right(self, insert_list, return_items.first);
                const insert_last = Internal.get_conn_left(self, insert_list, return_items.last);
                Internal.connect_with_insert(insert_edges.left, insert_first, insert_last, insert_edges.right);
                Internal.increase_link_set_count(self, insert_list, return_items.count);
                Internal.set_list_on_indexes_first_last(self, return_items.first, return_items.last, insert_list);
                return_items.list = insert_list;
                return return_items;
            }

            fn iter_peek_prev_or_null(self: *anyopaque) ?*Elem {
                if (!BACKWARD) return false;
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (iter.left_idx == NULL_IDX) return null;
                return iter.linked_list.get_ptr(iter.left_idx);
            }
            fn iter_advance_prev(self: *anyopaque) bool {
                if (!BACKWARD) return false;
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (iter.left_idx == NULL_IDX) return false;
                iter.left_idx = iter.linked_list.get_prev_idx(iter.list, iter.left_idx);
                return true;
            }
            fn iter_peek_next_or_null(self: *anyopaque) ?*Elem {
                if (!FORWARD) return false;
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (iter.right_idx == NULL_IDX) return null;
                return iter.linked_list.get_ptr(iter.right_idx);
            }
            fn iter_advance_next(self: *anyopaque) bool {
                if (!FORWARD) return false;
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (iter.right_idx == NULL_IDX) return false;
                iter.right_idx = iter.linked_list.get_next_idx(iter.list, iter.right_idx);
                return true;
            }
            fn iter_reset(self: *anyopaque) void {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (FORWARD) {
                    iter.right_idx = iter.linked_list.get_first_index_in_list(iter.list);
                    iter.left_idx = NULL_IDX;
                } else {
                    iter.left_idx = iter.linked_list.get_last_index_in_list(iter.list);
                    iter.right_idx = NULL_IDX;
                }
            }
        };

        pub const IteratorState = struct {
            linked_list: *LinkedList,
            list: List,
            left_idx: Idx,
            right_idx: Idx,

            pub fn iterator(self: *IteratorState) Iterator(Elem, true, true) {
                return Iterator(Elem, true, true){
                    .implementor = @ptrCast(self),
                    .vtable = Iterator(Elem).VTable{
                        .reset = Internal.iter_reset,
                        .advance_next = Internal.iter_advance_next,
                        .peek_next_or_null = Internal.iter_peek_next_or_null,
                        .advance_prev = Internal.iter_advance_prev,
                        .peek_prev_or_null = Internal.iter_peek_prev_or_null,
                    },
                };
            }
        };

        pub inline fn new_iterator_state_at_start_of_list(self: *LinkedList, list: List) IteratorState {
            return IteratorState{
                .linked_list = self,
                .list = list,
                .left_idx = NULL_IDX,
                .right_idx = if (HEAD) self.get_first_index_in_list(list) else NULL_IDX,
            };
        }
        pub inline fn new_iterator_state_at_end_of_list(self: *LinkedList, list: List) IteratorState {
            return IteratorState{
                .linked_list = self,
                .list = list,
                .left_idx = if (TAIL) self.get_last_index_in_list(list) else NULL_IDX,
                .right_idx = NULL_IDX,
            };
        }

        pub fn new_empty() LinkedList {
            return UNINIT;
        }

        pub fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!LinkedList else LinkedList {
            var self = UNINIT;
            if (RETURN_ERRORS) {
                try self.list.ensure_total_capacity_exact(capacity, alloc);
            } else {
                self.list.ensure_total_capacity_exact(capacity, alloc);
            }
            return self;
        }

        pub fn clone(self: LinkedList, alloc: Allocator) if (RETURN_ERRORS) Error!LinkedList else LinkedList {
            var new_list = self;
            new_list.list = if (RETURN_ERRORS) try self.list.clone(alloc) else self.list.clone(alloc);
            return new_list;
        }

        pub inline fn get_list_len(self: *LinkedList, list: List) Idx {
            return self.sets[@intFromEnum(list)].count;
        }

        pub inline fn get_ptr(self: *const LinkedList, idx: Idx) *Elem {
            assert_idx_less_than_len(idx, self.list.len, @src());
            return &self.list.ptr[idx];
        }

        pub inline fn get_prev_idx(self: *const LinkedList, list: List, this_idx: Idx) Idx {
            if (BACKWARD) {
                const ptr = get_ptr(self, this_idx);
                return @field(ptr, PREV_FIELD);
            }
            return Internal.traverse_to_find_index_preceding_this_one_in_direction(self, this_idx, list, .FORWARD);
        }

        pub inline fn get_next_idx(self: *const LinkedList, list: List, this_idx: Idx) Idx {
            if (FORWARD) {
                const ptr = get_ptr(self, this_idx);
                return @field(ptr, NEXT_FIELD);
            }
            return Internal.traverse_to_find_index_preceding_this_one_in_direction(self, this_idx, list, .BACKWARD);
        }

        pub fn get_nth_item_from_start_of_list(self: *LinkedList, list: List, n: Idx) Idx {
            const set_count = self.get_list_len(list);
            assert_with_reason(n < set_count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(list), set_count });
            if (FORWARD) {
                var c: Idx = 0;
                var idx = self.get_first_index_in_list(list);
                while (c != n) {
                    c += 1;
                    idx = get_next_idx(self, list, idx);
                }
                return idx;
            } else {
                var c: Idx = 0;
                var idx = self.get_last_index_in_list(list);
                const nn = set_count - n;
                while (c < nn) {
                    c += 1;
                    idx = get_prev_idx(self, list, idx);
                }
                return idx;
            }
        }

        pub fn get_nth_item_from_end_of_list(self: *LinkedList, list: List, n: Idx) Idx {
            const count = self.get_list_len(list);
            assert_with_reason(n < count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(list), count });
            if (BACKWARD) {
                var c = 0;
                var idx = self.get_last_index_in_list(list);
                while (c != n) {
                    c += 1;
                    idx = get_prev_idx(self, list, idx);
                }
                return idx;
            } else {
                var c: Idx = 0;
                var idx = self.get_first_index_in_list(list);
                const nn = count - n;
                while (c < nn) {
                    c += 1;
                    idx = get_next_idx(self, list, idx);
                }
                return idx;
            }
        }

        pub inline fn idx_is_in_list(self: *LinkedList, idx: Idx, list: List) bool {
            if (STATE) {
                const ptr = get_ptr(self, idx);
                if (STRONG_ASSERT) {
                    if (Internal.get_list_raw(ptr) != @intFromEnum(list)) return false;
                } else {
                    return Internal.get_list_raw(ptr) == @intFromEnum(list);
                }
            }
            return Internal.traverse_and_report_if_found_idx_in_set(self, list, idx);
        }

        pub inline fn get_first_index_in_list(self: *const LinkedList, list: List) Idx {
            if (HEAD) return self.sets[@intFromEnum(list)].first_idx;
            return Internal.traverse_to_get_first_idx_in_set(self, list).idx;
        }

        pub inline fn get_last_index_in_list(self: *const LinkedList, list: List) Idx {
            if (TAIL) return self.sets[@intFromEnum(list)].last_idx;
            return Internal.traverse_to_get_last_item_in_set(self, list).idx;
        }

        pub inline fn get_items_and_insert_at(self: *LinkedList, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime ins_mode: InsertMode, ins_val: InsertVal(ins_mode), alloc: Allocator) if (RETURN_ERRORS) Error!LLSlice else LLSlice {
            return Internal.get_items_and_insert_at_internal(self, get_mode, get_val, ins_mode, ins_val, alloc, false);
        }

        pub inline fn get_items_and_insert_at_assume_capacity(self: *LinkedList, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime ins_mode: InsertMode, ins_val: InsertVal(ins_mode)) LLSlice {
            return Internal.get_items_and_insert_at_internal(self, get_mode, get_val, ins_mode, ins_val, DummyAllocator.allocator, true);
        }

        pub fn list_is_cyclic_forward(self: *LinkedList, list: List) bool {
            if (FORWARD) {
                const start_idx = self.get_first_index_in_list(list);
                if (start_idx == NULL_IDX) return false;
                if (STATE or STRONG_ASSERT) assert_with_reason(self.idx_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
                var slow_idx = start_idx;
                var fast_idx = start_idx;
                var next_fast: Idx = undefined;
                while (true) {
                    next_fast = self.get_next_idx(list, fast_idx);
                    if (next_fast == NULL_IDX) return false;
                    next_fast = self.get_next_idx(list, next_fast);
                    if (next_fast == NULL_IDX) return false;
                    fast_idx = next_fast;
                    slow_idx = self.get_next_idx(list, slow_idx);
                    if (slow_idx == fast_idx) return true;
                }
            } else {
                return false;
            }
        }

        pub fn list_is_cyclic_backward(self: *LinkedList, list: List) bool {
            if (FORWARD) {
                const start_idx = self.get_last_index_in_list(list);
                if (start_idx == NULL_IDX) return false;
                if (STATE or STRONG_ASSERT) assert_with_reason(self.idx_is_in_list(start_idx, list), @src(), "provided idx {d} was not in list `{s}`", .{ start_idx, @tagName(list) });
                var slow_idx = start_idx;
                var fast_idx = start_idx;
                var next_fast: Idx = undefined;
                while (true) {
                    next_fast = self.get_prev_idx(list, fast_idx);
                    if (next_fast == NULL_IDX) return false;
                    next_fast = self.get_prev_idx(list, next_fast);
                    if (next_fast == NULL_IDX) return false;
                    fast_idx = next_fast;
                    slow_idx = self.get_prev_idx(list, slow_idx);
                    if (slow_idx == fast_idx) return true;
                }
            } else {
                return false;
            }
        }

        // pub fn find_idx(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
        //     for (self.slice(), 0..) |*item, idx| {
        //         if (match_fn(param, item)) return @intCast(idx);
        //     }
        //     return null;
        // }

        // pub fn find_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return &self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_const_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return &self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_and_copy(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return self.ptr[idx];
        //     }
        //     return null;
        // }

        // pub fn find_and_remove(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         return self.remove(idx);
        //     }
        //     return null;
        // }

        // pub fn find_and_delete(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
        //     if (self.find_idx(Param, param, match_fn)) |idx| {
        //         self.delete(idx);
        //         return true;
        //     }
        //     return false;
        // }

        // pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
        //     return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
        //     return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        // }

        // pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
        //     assert_with_reason(indexes.len <= self.len, @src(), "more indexes provided ({d}) than exist in list ({d})", .{ indexes.len, self.len });
        //     assert_with_reason(check: {
        //         var i: usize = 1;
        //         while (i < indexes.len) : (i += 1) {
        //             if (indexes[i - 1] >= indexes[i]) break :check false;
        //         }
        //         break :check true;
        //     }, @src(), "not all indexes are in increasing order (with no duplicates) as is required by this function", .{});
        //     assert_with_reason(check: {
        //         var i: usize = 0;
        //         while (i < indexes.len) : (i += 1) {
        //             if (indexes[i] >= self.len) break :check false;
        //         }
        //         break :check true;
        //     }, @src(), "some indexes provided are out of bounds for list len ({d})", .{self.len});
        //     var shift_down: usize = 0;
        //     var i: usize = 0;
        //     var src_start: Idx = undefined;
        //     var src_end: Idx = undefined;
        //     var dst_start: Idx = undefined;
        //     var dst_end: Idx = undefined;
        //     while (i < indexes.len) {
        //         var consecutive: Idx = 1;
        //         var end_index: Idx = i + consecutive;
        //         while (end_index < indexes.len) {
        //             if (indexes[end_index] != indexes[end_index - 1] + 1) break;
        //             consecutive += 1;
        //             end_index += 1;
        //         }
        //         const start_idx = end_index - 1;
        //         shift_down += consecutive;
        //         src_start = indexes[start_idx];
        //         src_end = if (end_index >= indexes.len) self.len else indexes[end_index];
        //         dst_start = src_start - shift_down;
        //         dst_end = src_end - shift_down;
        //         std.mem.copyForwards(Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
        //         i += consecutive;
        //     }
        //     self.len -= indexes.len;
        // }

        // //TODO pub fn insert_slots_at_ordered_indexes()

        // pub inline fn insertion_sort(self: *List) void {
        //     return self.flex_slice(.mutable).insertion_sort();
        // }

        // pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
        //     return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        // }

        // pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
        //     return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // pub inline fn is_sorted(self: *List) bool {
        //     return self.flex_slice(.immutable).is_sorted();
        // }

        // pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
        //     return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        // }

        // pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
        //     return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // pub inline fn is_reverse_sorted(self: *List) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted();
        // }

        // pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        // }

        // pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
        //     return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        // }

        // // pub inline fn insert_one_sorted( self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        // //     return insert_one_sorted_custom(List, self, item, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN, alloc);
        // // }

        // // pub fn insert_one_sorted_custom( self: *List, item: Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        // //     const insert_idx: Idx = @intCast(BinarySearch.binary_search_insert_index(Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
        // //     if (RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
        // //     return insert_idx;
        // // }

        // // pub inline fn find_equal_order_idx_sorted( self: *List, item_to_compare: *const Elem) ?Idx {
        // //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_equal_order_idx_sorted_custom( self: *List, item_to_compare: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem)) ?Idx {
        // //     const insert_idx = BinarySearch.binary_search_by_order(Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
        // //     if (insert_idx) |idx| return @intCast(idx);
        // //     return null;
        // // }

        // // pub inline fn find_matching_item_idx_sorted( self: *List, item_to_find: *const Elem) ?Idx {
        // //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_COMPARE_PKG.equals, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_matching_item_idx_sorted_custom( self: *List, item_to_find: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), exact_match_fn: *const CompareFn(Elem)) ?Idx {
        // //     const insert_idx = BinarySearch.binary_search_exact_match(Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
        // //     if (insert_idx) |idx| return @intCast(idx);
        // //     return null;
        // // }

        // // pub inline fn find_matching_item_idx( self: *List, item_to_find: *const Elem) ?Idx {
        // //     return find_matching_item_idx_custom(List, self, item_to_find, DEFAULT_MATCH_FN);
        // // }

        // // pub fn find_matching_item_idx_custom( self: *List, item_to_find: *const Elem, exact_match_fn: *const CompareFn(Elem)) ?Idx {
        // //     if (self.len == 0) return null;
        // //     const buf = self.ptr[0..self.len];
        // //     var idx: Idx = 0;
        // //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
        // //     const limit = self.len - 1;
        // //     while (!found_exact and idx < limit) {
        // //         idx += 1;
        // //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
        // //     }
        // //     if (found_exact) return idx;
        // //     return null;
        // // }

        // pub fn handle_alloc_error(err: Allocator.Error) if (RETURN_ERRORS) Error else noreturn {
        //     switch (ALLOC_ERROR_BEHAVIOR) {
        //         ErrorBehavior.RETURN_ERRORS => return err,
        //         ErrorBehavior.ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
        //         ErrorBehavior.ERRORS_ARE_UNREACHABLE => unreachable,
        //     }
        // }

        // //**************************
        // // std.io.Writer interface *
        // //**************************
        // const StdWriterHandle = struct {
        //     list: *List,
        //     alloc: Allocator,
        // };
        // const StdWriterHandleNoGrow = struct {
        //     list: *List,
        // };

        // pub const StdWriter = if (Elem != u8)
        //     @compileError("The Writer interface is only defined for child type `u8` " ++
        //         "but the given type is " ++ @typeName(Elem))
        // else
        //     std.io.Writer(StdWriterHandle, Allocator.Error, std_write);

        // pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
        //     return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        // }

        // fn std_write(handle: StdWriterHandle, bytes: []const u8) Allocator.Error!usize {
        //     try handle.list.append_slice(bytes, handle.alloc);
        //     return bytes.len;
        // }

        // pub const StdWriterNoGrow = if (Elem != u8)
        //     @compileError("The Writer interface is only defined for child type `u8` " ++
        //         "but the given type is " ++ @typeName(Elem))
        // else
        //     std.io.Writer(StdWriterHandleNoGrow, Allocator.Error, std_write_no_grow);

        // pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
        //     return StdWriterNoGrow{ .context = .{ .list = self } };
        // }

        // fn std_write_no_grow(handle: StdWriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
        //     const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
        //     if (bytes.len > available_capacity) return error.OutOfMemory;
        //     handle.list.append_slice_assume_capacity(bytes);
        //     return bytes.len;
        // }
    };
}

// pub fn LinkedListIterator(comptime List: type) type {
//     return struct {
//         next_idx: List.Idx = 0,
//         list_ref: *List,

//         const Self = @This();

//         pub inline fn reset_index_to_start(self: *Self) void {
//             self.next_idx = 0;
//         }

//         pub inline fn set_index(self: *Self, index: List.Idx) void {
//             self.next_idx = index;
//         }

//         pub inline fn decrease_index_safe(self: *Self, count: List.Idx) void {
//             self.next_idx -|= count;
//         }
//         pub inline fn decrease_index(self: *Self, count: List.Idx) void {
//             self.next_idx -= count;
//         }
//         pub inline fn increase_index(self: *Self, count: List.Idx) void {
//             self.next_idx += count;
//         }
//         pub inline fn increase_index_safe(self: *Self, count: List.Idx) void {
//             self.next_idx +|= count;
//         }

//         pub inline fn has_next(self: Self) bool {
//             return self.next_idx < self.list_ref.len;
//         }

//         pub fn get_next_copy(self: *Self) ?List.Elem {
//             if (self.next_idx >= self.list_ref.len) return null;
//             const item = self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_copy_guaranteed(self: *Self) List.Elem {
//             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
//             const item = self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_ref(self: *Self) ?*List.Elem {
//             if (self.next_idx >= self.list_ref.len) return null;
//             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         pub fn get_next_ref_guaranteed(self: *Self) *List.Elem {
//             assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
//             const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
//             self.next_idx += 1;
//             return item;
//         }

//         /// Returns `true` if action was performed at least one time, `false` if iterator had zero items left
//         pub fn perform_action_on_remaining_items(self: *Self, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
//             var idx: List.Idx = self.next_idx;
//             var exec_count: List.Idx = 0;
//             var should_continue: bool = true;
//             while (should_continue and idx < self.list_ref.len) : (idx += 1) {
//                 const item: *List.Elem = &self.list_ref.ptr[idx];
//                 should_continue = callback(self.list_ref, idx, item, userdata);
//                 exec_count += 1;
//             }
//             return exec_count > 0;
//         }

//         /// Returns `true` if action was performed on exactly `count` items, `false` if iterator ran out of items early
//         pub fn perform_action_on_next_n_items(self: *Self, count: List.Idx, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
//             var idx: List.Idx = self.next_idx;
//             const limit = @min(idx + count, self.list_ref.len);
//             var exec_count: List.Idx = 0;
//             var should_continue: bool = true;
//             while (should_continue and idx < limit) : (idx += 1) {
//                 const item: *List.Elem = &self.list_ref.ptr[idx];
//                 should_continue = callback(self.list_ref, idx, item, userdata);
//                 exec_count += 1;
//             }
//             return exec_count == count;
//         }

//         /// Should return `true` if iteration should continue, or `false` if iteration should stop
//         pub const IteratorAction = fn (list: *List, index: List.Idx, item: *List.Elem, userdata: ?*anyopaque) bool;
//     };
// }

test "LinkedList.zig" {
    const t = Root.Testing;
    const alloc = std.heap.page_allocator;
    const TestElem = struct {
        prev: u16,
        val: u8,
        idx: u16,
        list: u8,
        next: u16,
    };
    const TestState = enum(u8) {
        USED,
        FREE,
        INVALID,
    };
    const uninit_val = TestElem{
        .idx = 0xAAAA,
        .prev = 0xAAAA,
        .next = 0xAAAA,
        .list = 0xAA,
        .val = 0,
    };
    const opts = LinkedListOptions{
        .list_options = Root.List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = .ERRORS_PANIC,
            .element_type = TestElem,
            .growth_model = .GROW_BY_25_PERCENT,
            .index_type = u16,
            .secure_wipe_bytes = true,
            .memset_uninit_val = &uninit_val,
        },
        .linked_set_enum = TestState,
        .forward_linkage = "next",
        .backward_linkage = "prev",
        .element_idx_cache_field = "idx",
        .force_cache_first_index = true,
        .force_cache_last_index = true,
        .element_list_access = ElementStateAccess{
            .field = "list",
            .field_bit_offset = 1,
            .field_bit_count = 2,
            .field_type = u8,
        },
        .stronger_asserts = true,
    };
    const Action = struct {
        fn set_value_from_string(elem: *TestElem, userdata: ?*anyopaque) void {
            const string: *[]const u8 = @ptrCast(@alignCast(userdata.?));
            elem.val = string.*[0];
            string.* = string.*[1..];
        }
    };
    const List = define_manual_allocator_linked_list_type(opts);
    const expect = struct {
        fn list_is_valid(linked_list: *List, list: TestState, case_indexes: []const u16, case_vals: []const u8) !void {
            errdefer debug_list(linked_list, list);
            var i: List.Idx = 0;
            var c: List.Idx = 0;
            const list_count = linked_list.get_list_len(list);
            try t.expect_equal(case_indexes.len, "indexes.len", case_vals.len, "vals.len", "text case indexes and vals have different len", .{});
            try t.expect_equal(list_count, "list_count", case_vals.len, "vals.len", "list {s} count mismatch with test case vals len", .{@tagName(list)});
            //FORWARD
            var start_idx = linked_list.get_first_index_in_list(list);
            if (start_idx == List.NULL_IDX) {
                try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
            } else {
                try t.expect_true(linked_list.idx_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
                var slow_idx = start_idx;
                var fast_idx = start_idx;
                var fast_ptr = linked_list.get_ptr(fast_idx);
                var prev_fast_idx: List.Idx = List.NULL_IDX;
                try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
                try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
                try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached prev isnt NULL_IDX", .{ @tagName(list), start_idx });
                try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                i = 1;
                c = 1;
                check: while (true) {
                    prev_fast_idx = fast_idx;
                    fast_idx = linked_list.get_next_idx(list, fast_idx);
                    if (fast_idx == List.NULL_IDX) {
                        try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
                        break :check;
                    }
                    try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
                    fast_ptr = linked_list.get_ptr(fast_idx);
                    try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
                    try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                    try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                    try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                    i += 1;
                    c += 1;
                    prev_fast_idx = fast_idx;
                    fast_idx = linked_list.get_next_idx(list, fast_idx);
                    if (fast_idx == List.NULL_IDX) {
                        try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
                        break :check;
                    }
                    fast_ptr = linked_list.get_ptr(fast_idx);
                    try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@field(fast_ptr, List.PREV_FIELD), "@field(fast_ptr, List.PREV_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
                    try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                    try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                    try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                    i += 1;
                    c += 1;
                    slow_idx = linked_list.get_next_idx(list, slow_idx);
                    try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
                }
            }
            //BACKWARD
            i = @intCast(case_indexes.len -| 1);
            c = 0;
            start_idx = linked_list.get_last_index_in_list(list);
            if (start_idx == List.NULL_IDX) {
                try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
            } else {
                try t.expect_true(linked_list.idx_is_in_list(start_idx, list), "list.idx_is_in_list(start_idx, list)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
                var slow_idx = start_idx;
                var fast_idx = start_idx;
                var fast_ptr = linked_list.get_ptr(fast_idx);
                var prev_fast_idx: List.Idx = List.NULL_IDX;
                try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(start_ptr, List.CACHE_FIELD)", "list list {s} first idx {d} cached idx mismatch", .{ @tagName(list), start_idx });
                try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(start_idx)", "list list {s} first idx {d} cached list mismatch", .{ @tagName(list), start_idx });
                try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} first idx {d} cached next isnt NULL_IDX", .{ @tagName(list), start_idx });
                try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                i -|= 1;
                c = 1;
                check: while (true) {
                    prev_fast_idx = fast_idx;
                    fast_idx = linked_list.get_prev_idx(list, fast_idx);
                    if (fast_idx == List.NULL_IDX) {
                        try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
                        break :check;
                    }
                    try t.expect_greater_than(linked_list.list.len, "list.list.len", fast_idx, "fast_idx", "list list {s} next idx out of bounds but not NULL_IDX", .{@tagName(list)});
                    fast_ptr = linked_list.get_ptr(fast_idx);
                    try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached next isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
                    try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                    try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                    try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                    i -|= 1;
                    c += 1;
                    prev_fast_idx = fast_idx;
                    fast_idx = linked_list.get_prev_idx(list, fast_idx);
                    if (fast_idx == List.NULL_IDX) {
                        try t.expect_equal(list_count, "list_count", c, "real_count", "list list {s} mismatch count", .{@tagName(list)});
                        break :check;
                    }
                    fast_ptr = linked_list.get_ptr(fast_idx);
                    try t.expect_equal(fast_idx, "fast_idx", @field(fast_ptr, List.CACHE_FIELD), "@field(fast_ptr, List.CACHE_FIELD)", "list list {s} idx {d} cached idx mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@intFromEnum(list), "@intFromEnum(list)", List.Internal.get_list_raw(fast_ptr), "List.Internal.get_list_raw(fast_ptr)", "list list {s} idx {d} cached list mismatch", .{ @tagName(list), fast_idx });
                    try t.expect_equal(@field(fast_ptr, List.NEXT_FIELD), "@field(fast_ptr, List.NEXT_FIELD)", prev_fast_idx, "prev_fast_idx", "list list {s} idx {d} cached prev isnt previous fast idx {d}", .{ @tagName(list), fast_idx, prev_fast_idx });
                    try t.expect_less_than(i, "i", case_vals.len, " case_vals.len", "list list {s} current position {d} out of bounds for test case vals", .{ @tagName(list), i });
                    try t.expect_equal(fast_idx, "fast_idx", case_indexes[i], "case_indexes[i]", "list list {s} element at pos {d} idx mismatch", .{ @tagName(list), i });
                    try t.expect_equal(@field(fast_ptr, "val"), "@field(fast_ptr, \"val\")", case_vals[i], "case_vals[i]", "list list {s} element at pos {d} val mismatch", .{ @tagName(list), i });
                    i -|= 1;
                    c += 1;
                    slow_idx = linked_list.get_prev_idx(list, slow_idx);
                    try t.expect_not_equal(fast_idx, "fast_idx", slow_idx, "slow_idx", "list list {s} was cyclic", .{@tagName(list)});
                }
            }
        }
        fn full_ll_list(list: *List, used_indexes: []const u16, used_vals: []const u8, free_indexes: []const u16, free_vals: []const u8, invalid_indexes: []const u16, invalid_vals: []const u8) !void {
            try list_is_valid(list, .FREE, free_indexes, free_vals);
            try list_is_valid(list, .USED, used_indexes, used_vals);
            try list_is_valid(list, .INVALID, invalid_indexes, invalid_vals);
            const total_count = list.get_list_len(.USED) + list.get_list_len(.FREE) + list.get_list_len(.INVALID);
            try t.expect_equal(total_count, "total_count", list.list.len, "list.list.len", "total list list counts did not equal underlying list len (leaked indexes)", .{});
        }
        fn debug_list(linked_list: *List, list: TestState) void {
            t.print("\nERROR STATE: {s}\ncount:     {d: >2}\nfirst_idx: {d: >2}\nlast_idx:  {d: >2}\n", .{
                @tagName(list),
                linked_list.get_list_len(list),
                linked_list.get_first_index_in_list(list),
                linked_list.get_last_index_in_list(list),
            });
            var idx = linked_list.get_first_index_in_list(list);
            var ptr: *List.Elem = undefined;
            t.print("forward:      ", .{});
            while (idx != List.NULL_IDX) {
                ptr = linked_list.get_ptr(idx);
                t.print("{d} -> ", .{idx});
                idx = @field(ptr, List.NEXT_FIELD);
            }
            t.print("NULL\n", .{});
            idx = linked_list.get_first_index_in_list(list);
            t.print("forward str:  ", .{});
            while (idx != List.NULL_IDX) {
                ptr = linked_list.get_ptr(idx);
                t.print("{c}", .{@field(ptr, "val")});
                idx = @field(ptr, List.NEXT_FIELD);
            }
            t.print("\n", .{});
            idx = linked_list.get_last_index_in_list(list);
            t.print("backward:     ", .{});
            while (idx != List.NULL_IDX) {
                ptr = linked_list.get_ptr(idx);
                t.print("{d} -> ", .{idx});
                idx = @field(ptr, List.PREV_FIELD);
            }
            t.print("NULL\n", .{});
            idx = linked_list.get_last_index_in_list(list);
            t.print("backward str: ", .{});
            while (idx != List.NULL_IDX) {
                ptr = linked_list.get_ptr(idx);
                t.print("{c}", .{@field(ptr, "val")});
                idx = @field(ptr, List.PREV_FIELD);
            }
            t.print("\n", .{});
        }
    };
    var linked_list = List.new_empty();
    var slice_result = linked_list.get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc);
    try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.CREATE_MANY_NEW, 20, .AT_BEGINNING_OF_LIST, .FREE, alloc)", List.LLSlice{ .count = 20, .first = 0, .last = 19, .list = .FREE }, "List.LLSlice{.count = 20, .first = 0, .last = 19, .list = .FREE}", "unexpected result from function", .{});
    // zig fmt: off
    try expect.full_ll_list(
        &linked_list,
        &.{}, // used_indexes
        &.{}, // used_vals
        &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
        &.{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
        &.{}, // invalid_indexes
        &.{}, // invalid_vals
    );
    // zig fmt: on
    slice_result = linked_list.get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc);
    try t.expect_shallow_equal(slice_result, "get_items_and_insert_at(.FIRST_N_FROM_LIST, List.CountFromList.new(.FREE, 8), .AT_BEGINNING_OF_LIST, .USED, alloc)", List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }, "List.LLSlice{ .count = 8, .first = 0, .last = 7, .list = .USED }", "unexpected result from function", .{});
    // zig fmt: off
    try expect.full_ll_list(
        &linked_list,
        &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
        &.{ 0, 0, 0, 0, 0, 0, 0, 0}, // used_vals
        &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
        &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
        &.{}, // invalid_indexes
        &.{}, // invalid_vals
    );
    // zig fmt: on
    var slice_iter_state = slice_result.new_iterator_state_at_start_of_slice(&linked_list);
    try t.expect_shallow_equal(slice_iter_state, "slice_result.new_iterator_state_at_start_of_slice(&linked_list)", List.LLSlice.SliceIteratorState{ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result }, "SliceIteratorState{ .linked_list = &linked_list, .left_idx = List.NULL_IDX, .right_idx = slice_result.first, .slice = &slice_result }", "unexpected result from function", .{});
    var slice_iter = slice_iter_state.iterator();
    var str: []const u8 = "abcdefgh";
    const bool_result = slice_iter.perform_action_on_each_next_item(Action.set_value_from_string, @ptrCast(&str));
    try t.expect_true(bool_result, "slice_iter.perform_action_on_each_next_item(Action.set_value_from_string, &\"abcdefghijklmnopqrst\");", "iterator set values failed", .{});
    // zig fmt: off
    try expect.full_ll_list(
        &linked_list,
        &.{ 0, 1, 2, 3, 4, 5, 6, 7}, // used_indexes
        "abcdefgh", // used_vals
        &.{ 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }, // free_indexes
        &.{ 0, 0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0 },  // free_vals
        &.{}, // invalid_indexes
        &.{}, // invalid_vals
    );
    // zig fmt: on
}
