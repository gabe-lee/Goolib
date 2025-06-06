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
    element_state_access: ?ElementStateAccess = null,
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
    const S = options.element_state_access != null;
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
        const S_FIELD = options.element_state_access.?.field;
        assert_with_reason(@hasField(options.list_options.element_type, S_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), S_FIELD });
        const S_TYPE = @FieldType(options.list_options.element_type, S_FIELD);
        assert_with_reason(Types.type_is_int(S_TYPE), @src(), "element state field `.{s}` on element type `{s}` is not an integer type", .{ S_FIELD, @typeName(options.list_options.element_type) });
        assert_with_reason(S_TYPE == options.element_state_access.?.field_type, @src(), "element state field `.{s}` on element type `{s}` does not match stated type {s}", .{ S_FIELD, @typeName(options.list_options.element_type), @typeName(options.element_state_access.?.field_type) });
        const tag_count = Types.enum_max_field_count(options.linked_set_enum);
        const flag_count = 1 << options.element_state_access.?.field_bit_count;
        assert_with_reason(flag_count >= tag_count, @src(), "options.element_state_access.field_bit_count {d} (max val = {d}) cannot hold all tag values for options.linked_set_enum {d}", .{ options.element_state_access.?.field_bit_count, flag_count, tag_count });
    }
    if (C) {
        const C_FIELD = options.element_idx_cache_field.?;
        assert_with_reason(@hasField(options.list_options.element_type, C_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), C_FIELD });
        const C_TYPE = @FieldType(options.list_options.element_type, C_FIELD);
        assert_with_reason(C_TYPE == options.list_options.index_type, @src(), "element state field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ C_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
    }
    return struct {
        list: BaseList = BaseList.UNINIT,
        sets: [SET_COUNT]StateData = UNINIT_SETS,

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
        const STATE = options.element_state_access != null;
        const CACHE = options.element_idx_cache_field != null;
        const CACHE_FIELD = if (CACHE) options.element_idx_cache_field.? else "";
        const T_STATE_FIELD = if (STATE) options.element_state_access.?.field_type else void;
        const STATE_FIELD = if (STATE) options.element_state_access.?.field else "";
        const STATE_OFFSET = if (STATE) options.element_state_access.?.field_bit_offset else 0;
        const UNINIT = List{};
        const RETURN_ERRORS = options.list_options.alloc_error_behavior == .RETURN_ERRORS;
        const NULL_IDX = math.maxInt(Idx);
        const MAX_STATE_TAG = Types.enum_max_value(State);
        const STATE_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) build: {
            const mask_unshifted = 1 << options.element_state_access.?.field_bit_count;
            break :build mask_unshifted << options.element_state_access.?.field_bit_offset;
        } else 0;
        const STATE_CLEAR_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) ~STATE_MASK else 0b1111111111111111111111111111111111111111111111111111111111111111;
        const HEAD_TAIL: u2 = (@as(u2, @intFromBool(HEAD)) << 1) | @as(u2, @intFromBool(TAIL));
        const HAS_HEAD_HAS_TAIL: u2 = 0b11;
        const HAS_HEAD_NO_TAIL: u2 = 0b10;
        const NO_HEAD_HAS_TAIL: u2 = 0b01;
        const UNINIT_SETS: [SET_COUNT]StateData = build: {
            var sets: [SET_COUNT]StateData = undefined;
            for (0..SET_COUNT) |idx| {
                sets[idx] = StateData{};
            }
            break :build sets;
        };

        const List = @This();
        pub const BaseList = Root.List.define_manual_allocator_list_type(options.list_options);
        pub const Error = Allocator.Error;
        pub const Elem = options.list_options.element_type;
        pub const Idx = options.list_options.index_type;
        // pub const Iterator = LinkedListIterator(List);
        pub const State = options.linked_set_enum;
        const StateTag = Types.enum_tag_type(State);
        pub const StateData = switch (HEAD_TAIL) {
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
        pub const FirstLastIdx = struct {
            first: Idx,
            last: Idx,
        };
        pub const StateFirstLastIdx = struct {
            state: State,
            first: Idx,
            last: Idx,
        };
        pub const FirstLastIdxCount = struct {
            first: Idx,
            last: Idx,
            count: Idx,
        };
        pub const StateFirstLastIdxCount = struct {
            state: State,
            first: Idx,
            last: Idx,
            count: Idx,
        };
        pub const StateIdxList = struct {
            state: State,
            idxs: []const Idx,
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
            state: State,
            edges: ConnLeftRight,
            count: Idx,
        };
        pub const StateIdx = struct {
            state: State,
            idx: Idx,
        };
        pub const StateCount = struct {
            state: State,
            count: Idx,
        };
        var DUMMY_IDX: Idx = NULL_IDX;
        var DUMMY_ELEM: Elem = undefined;

        pub const GetMode = enum {
            ONE_NEW,
            FIRST_FROM_SET_ELSE_NEW,
            LAST_FROM_SET_ELSE_NEW,
            FIRST_FROM_SET,
            LAST_FROM_SET,
            ONE_INDEX,
            MANY_NEW,
            FIRST_N_FROM_SET,
            LAST_N_FROM_SET,
            FIRST_N_FROM_SET_ELSE_NEW,
            LAST_N_FROM_SET_ELSE_NEW,
            SPARSE_LIST_FROM_SAME_SET,
            SPARSE_LIST_FROM_ANY_SET,
            SLICE,
            SLICE_ELSE_NEW,
        };

        pub fn GetVal(comptime M: GetMode) type {
            return switch (M) {
                .FIRST_FROM_SET, .FIRST_FROM_SET_ELSE_NEW, .LAST_FROM_SET, .LAST_FROM_SET_ELSE_NEW => State,
                .FIRST_N_FROM_SET, .FIRST_N_FROM_SET_ELSE_NEW, .LAST_N_FROM_SET, .LAST_N_FROM_SET_ELSE_NEW => StateCount,
                .ONE_NEW => void,
                .ONE_INDEX => StateIdx,
                .MANY_NEW => Idx,
                .SLICE => LLSlice,
                .SLICE_ELSE_NEW => LLSupplySlice,
                .SPARSE_LIST_FROM_SAME_SET => StateIdxList,
                .SPARSE_LIST_FROM_ANY_SET => []const StateIdx,
            };
        }

        pub const InsertMode = enum {
            AT_BEGINNING_OF_SET,
            AT_END_OF_SET,
            AFTER_INDEX,
            BEFORE_INDEX,
            AFTER_NTH_ITEM_FROM_END_OF_SET,
            BEFORE_NTH_ITEM_FROM_END_OF_SET,
            AFTER_NTH_ITEM_FROM_START_OF_SET,
            BEFORE_NTH_ITEM_FROM_START_OF_SET,
        };

        pub fn InsertVal(comptime M: InsertMode) type {
            return switch (M) {
                .AT_BEGINNING_OF_SET, .AT_END_OF_SET => State,
                .AFTER_INDEX, .BEFORE_INDEX, .AFTER_NTH_ITEM_FROM_END_OF_SET, .BEFORE_NTH_ITEM_FROM_END_OF_SET, .AFTER_NTH_ITEM_FROM_START_OF_SET, .BEFORE_NTH_ITEM_FROM_START_OF_SET => StateIdx,
            };
        }

        /// Represents a slice of logical items in a Linked List
        ///
        /// Manually altering its internal fields should be considered unsafe if done incorrectly,
        /// use the provided methods on
        pub const LLSlice = struct {
            state: State,
            first: Idx = NULL_IDX,
            last: Idx = NULL_IDX,
            count: Idx = 0,

            pub fn single(state: State, idx: Idx) LLSlice {
                return LLSlice{
                    .state = state,
                    .first = idx,
                    .last = idx,
                    .count = 1,
                };
            }

            pub fn new(state: State, first: Idx, last: Idx, count: Idx) LLSlice {
                return LLSlice{
                    .state = state,
                    .first = first,
                    .last = last,
                    .count = count,
                };
            }

            pub fn to_supply_slice(self: LLSlice, total_needed: Idx) LLSupplySlice {
                return LLSupplySlice{
                    .total_needed = total_needed,
                    .slice = self,
                };
            }

            pub fn to_cursor_slice(self: LLSlice, list_ref: *List) LLCursorSlice {
                return LLCursorSlice{
                    .slice = self,
                    .list_ref = list_ref,
                    .cursor_pos = 0,
                    .cursor_idx = self.first,
                };
            }

            pub fn grow_end_rightward(self: *LLSlice, list: *const List, count: Idx) void {
                const new_last = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.state, self.last, count, false, 0);
                self.count += count;
                self.last = new_last;
            }

            pub fn shrink_end_leftward(self: *LLSlice, list: *const List, count: Idx) void {
                const new_last = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.state, self.last, count, true, self.first);
                self.count += count;
                self.last = new_last;
            }

            pub fn grow_start_leftward(self: *LLSlice, list: *const List, count: Idx) void {
                const new_first = Internal.find_idx_n_places_before_this_one_with_fallback_start(list, self.state, self.first, count, false, 0);
                self.count += count;
                self.first = new_first;
            }

            pub fn shrink_start_rightward(self: *LLSlice, list: *const List, count: Idx) void {
                const new_first = Internal.find_idx_n_places_after_this_one_with_fallback_start(list, self.state, self.first, count, true, self.last);
                self.count += count;
                self.first = new_first;
            }

            pub fn slide_right(self: *LLSlice, list: *const List, count: Idx) void {
                self.grow_end_rightward(list, count);
                self.shrink_start_rightward(list, count);
            }

            pub fn slide_left(self: *LLSlice, list: *const List, count: Idx) void {
                self.grow_start_leftward(list, count);
                self.shrink_end_leftward(list, count);
            }
        };

        /// Variant of `LLSlice` used for the purpose of supplying a function
        /// with arbitrary items to draw from before any new items are created
        pub const LLSupplySlice = struct {
            slice: LLSlice,
            total_needed: Idx,
        };

        /// A variant of `LLSlice` that keeps track of a logical cursor index within the slice
        /// and holds a reference to the list to which it belongs for convenience.
        ///
        /// Users can lookup items based on their logical nth position in the list,
        /// and traversing the list may be faster in some cases by determining if it would
        /// be faster to get there from the current cursor position or from the start/end
        /// of the list
        pub const LLCursorSlice = struct {
            slice: LLSlice,
            list_ref: *List,
            cursor_pos: Idx = NULL_IDX,
            cursor_idx: Idx = NULL_IDX,

            pub fn goto_pos(self: *LLCursorSlice, pos: Idx) void {
                assert_with_reason(pos < self.slice.count, @src(), "pos {d} is out of bounds for LLSlice (count/len = {d})", .{ pos, self.slice.count });
                if (pos > self.cursor_pos) {
                    self.move_forward_n_positions(pos - self.cursor_pos);
                } else {
                    self.move_backward_n_positions(self.cursor_pos - pos);
                }
            }

            pub fn move_forward_n_positions(self: *LLCursorSlice, n: Idx) void {
                assert_with_reason(self.cursor_pos + n < self.slice.count, @src(), "cursor pos {d} (curr {d} + {d}) is out of bounds for slice count/len ({d})", .{ self.cursor_pos + n, self.cursor_pos, n, self.slice.count });
                if (FORWARD) {
                    const from_curr = n;
                    if (BACKWARD) {
                        const from_end = self.slice.count - self.cursor_pos + n;
                        if (from_end < from_curr) {
                            self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.state, self.slice.last, from_end, false, 0);
                        } else {
                            self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.state, self.cursor_idx, from_curr, false, 0);
                        }
                    } else {
                        self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.state, self.cursor_idx, from_curr, false, 0);
                    }
                } else {
                    const from_end = self.slice.count - self.cursor_pos + n;
                    self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.state, self.slice.last, from_end, false, 0);
                }
                self.cursor_pos += n;
            }

            pub fn move_backward_n_positions(self: *LLCursorSlice, n: Idx) void {
                assert_with_reason(self.cursor_pos >= n, @src(), "cursor pos {d} (curr {d} - {d}) is out of bounds for slice count/len ({d})", .{ self.cursor_pos - n, self.cursor_pos, n, self.slice.count });
                if (BACKWARD) {
                    const from_curr = n;
                    if (FORWARD) {
                        const from_start = self.cursor_pos - n;
                        if (from_start < from_curr) {
                            self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.state, self.slice.first, from_start, false, 0);
                        } else {
                            self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.state, self.cursor_idx, from_curr, false, 0);
                        }
                    } else {
                        self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.state, self.cursor_idx, from_curr, false, 0);
                    }
                } else {
                    const from_start = self.cursor_pos - n;
                    self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.state, self.slice.first, from_start, false, 0);
                }
                self.cursor_pos -= n;
            }

            pub fn get_current_ptr(self: LLCursorSlice) *Elem {
                return self.list_ref.get_ptr(self.cursor_idx);
            }

            pub fn grow_end_rightward(self: *LLCursorSlice, count: Idx) void {
                self.slice.grow_end_rightward(self.list_ref, count);
            }

            pub fn shrink_end_leftward(self: *LLCursorSlice, count: Idx) void {
                self.slice.shrink_end_leftward(self.list_ref, count);
                if (self.cursor_pos >= self.slice.count) {
                    self.cursor_pos = self.slice.count - 1;
                    self.cursor_idx = self.slice.last;
                }
            }

            pub fn grow_start_leftward(self: *LLCursorSlice, count: Idx) void {
                self.slice.grow_start_leftward(self.list_ref, count);
                self.cursor_pos += count;
            }

            pub fn shrink_start_rightward(self: *LLCursorSlice, count: Idx) void {
                self.slice.shrink_start_rightward(self.list_ref, count);
                if (self.cursor_pos < count) {
                    self.cursor_pos = 0;
                    self.cursor_idx = self.slice.first;
                } else {
                    self.cursor_pos -= count;
                }
            }

            pub fn slide_right(self: *LLCursorSlice, count: Idx) void {
                self.slice.slide_right(self.list_ref, count);
                if (self.cursor_pos < count) {
                    self.cursor_pos = 0;
                    self.cursor_idx = self.slice.first;
                } else {
                    self.cursor_pos -= count;
                }
            }

            pub fn slide_left(self: *LLCursorSlice, count: Idx) void {
                self.slice.slide_left(self.list_ref, count);
                if (self.slice.count - self.cursor_pos <= count) {
                    self.cursor_pos = self.slice.count - 1;
                    self.cursor_idx = self.slice.last;
                }
            }
        };

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked list state
        /// - Are only useful for asserting/creating intenal state
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate special user use cases
        pub const Internal = struct {
            pub fn find_idx_n_places_after_this_one_with_fallback_start(self: *const List, state: State, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
                if (FORWARD) {
                    return traverse_forward_to_find_idx_n_places_after_this_one(self, state, idx, count);
                } else {
                    return traverse_backward_to_find_idx_n_places_after_this_one_start_at(self, state, idx, count, use_fallback_start, fallback_start_idx);
                }
            }

            pub fn find_idx_n_places_before_this_one_with_fallback_start(self: *const List, state: State, idx: Idx, count: Idx, comptime use_fallback_start: bool, fallback_start_idx: Idx) Idx {
                if (BACKWARD) {
                    return traverse_backward_to_find_idx_n_places_before_this_one(self, state, idx, count);
                } else {
                    return traverse_forward_to_find_idx_n_places_before_this_one_start_at(self, state, idx, count, use_fallback_start, fallback_start_idx);
                }
            }

            pub fn traverse_forward_to_find_idx_n_places_after_this_one(self: *const List, state: State, idx: Idx, count: Idx) Idx {
                var delta: Idx = 0;
                var result: Idx = idx;
                while (delta < count and result != idx and result != NULL_IDX) {
                    result = Internal.get_next_idx_fwd(self, result);
                    delta += 1;
                }
                assert_with_reason(result != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(state) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(state), delta });
                return result;
            }

            pub fn traverse_backward_to_find_idx_n_places_before_this_one(self: *const List, state: State, idx: Idx, count: Idx) Idx {
                var delta: Idx = 0;
                var result: Idx = idx;
                while (delta < count and result != idx and result != NULL_IDX) {
                    result = Internal.get_prev_idx_bkd(self, result);
                    delta += 1;
                }
                assert_with_reason(result != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(state) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(state), delta });
                return result;
            }

            pub fn traverse_backward_to_find_idx_n_places_after_this_one_start_at(self: *const List, state: State, idx: Idx, count: Idx, comptime use_start: bool, start: Idx) Idx {
                var delta: Idx = 0;
                var probe: Idx = if (use_start) start else self.get_last_index_in_state(state);
                var result: Idx = probe;
                while (delta < count and probe != idx and probe != NULL_IDX) {
                    probe = Internal.get_prev_idx_bkd(self, probe);
                    delta += 1;
                }
                assert_with_reason(probe != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(state) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items after idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(state), delta });
                while (probe != idx) {
                    probe = Internal.get_prev_idx_bkd(self, probe);
                    result = Internal.get_prev_idx_bkd(self, result);
                }
                return result;
            }

            pub fn traverse_forward_to_find_idx_n_places_before_this_one_start_at(self: *const List, state: State, idx: Idx, count: Idx, comptime use_start: bool, start: Idx) Idx {
                var delta: Idx = 0;
                var probe: Idx = if (use_start) start else self.get_first_index_in_state(state);
                var result: Idx = probe;
                while (delta < count and probe != idx and probe != NULL_IDX) {
                    probe = Internal.get_next_idx_fwd(self, probe);
                    delta += 1;
                }
                assert_with_reason(probe != NULL_IDX, @src(), "idx {d} was not found in set `{s}`", .{ idx, @tagName(state) });
                assert_with_reason(delta == count, @src(), "there are not {d} more items before idx {d} in set `{s}`, (only {d})", .{ count, idx, @tagName(state), delta });
                while (probe != idx) {
                    probe = Internal.get_next_idx_fwd(self, probe);
                    result = Internal.get_next_idx_fwd(self, result);
                }
                return result;
            }

            pub inline fn set_next_idx(self: *List, any: anytype, idx: Idx) void {
                if (FORWARD) {
                    const T = @TypeOf(any);
                    if (T == Idx) {
                        const ptr = get_ptr(self, any);
                        @field(ptr, NEXT_FIELD) = idx;
                    }
                    if (T == *Elem) {
                        @field(any, NEXT_FIELD) = idx;
                    }
                }
            }

            pub inline fn set_prev_idx(self: *List, any: anytype, idx: Idx) void {
                if (BACKWARD) {
                    const T = @TypeOf(any);
                    if (T == Idx) {
                        const ptr = get_ptr(self, any);
                        @field(ptr, PREV_FIELD) = idx;
                    }
                    if (T == *Elem) {
                        @field(any, PREV_FIELD) = idx;
                    }
                }
            }

            pub inline fn set_idx(ptr: *Elem, idx: Idx) void {
                if (CACHE) @field(ptr, CACHE_FIELD) = idx;
            }

            pub inline fn set_first_index(self: *List, state: State, idx: Idx) void {
                if (HEAD) self.sets[@intFromEnum(state)].first_idx = idx;
            }

            pub inline fn set_last_index(self: *List, state: State, idx: Idx) void {
                if (TAIL) self.sets[@intFromEnum(state)].last_idx = idx;
            }

            pub inline fn set_link_set_count(self: *List, state: State, count: Idx) void {
                self.sets[@intFromEnum(state)].count = count;
            }

            pub inline fn increase_link_set_count(self: *List, state: State, amount: Idx) void {
                self.sets[@intFromEnum(state)].count += amount;
            }

            pub inline fn decrease_link_set_count(self: *List, state: State, amount: Idx) void {
                self.sets[@intFromEnum(state)].count -= amount;
            }

            pub inline fn set_state(ptr: *Elem, state: State) void {
                if (STATE) {
                    @field(ptr, STATE_FIELD) &= STATE_CLEAR_MASK;
                    const new_state: T_STATE_FIELD = @as(T_STATE_FIELD, @intCast(@intFromEnum(state)));
                    const new_state_shifted = new_state << STATE_OFFSET;
                    @field(ptr, STATE_FIELD) |= new_state_shifted;
                }
            }

            pub fn set_state_on_indexes_first_last(self: *List, first_idx: Idx, last_idx: Idx, state: State) void {
                if (!STATE) return;
                var idx = if (FORWARD) first_idx else last_idx;
                const final_idx = if (FORWARD) last_idx else first_idx;
                while (true) {
                    const ptr = get_ptr(self, idx);
                    set_state(ptr, state);
                    if (idx == final_idx) break;
                    idx = if (FORWARD) get_next_idx_fwd(self, idx) else get_prev_idx_bkd(self, idx);
                }
            }

            pub fn link_new_indexes(self: *List, state: State, first_idx: Idx, last_idx: Idx) void {
                var left_idx = first_idx;
                var right_idx = first_idx + 1;
                while (right_idx <= last_idx) {
                    const left = Internal.get_conn_left(self, state, left_idx);
                    const right = Internal.get_conn_right(self, state, right_idx);
                    connect(self, left, right);
                    left_idx += 1;
                    right_idx += 1;
                }
            }

            pub fn disconnect_one(self: *List, state: State, idx: Idx) void {
                const disconn = Internal.get_conn_left_right_before_first_and_after_last(self, idx, idx, state);
                Internal.connect(disconn.left, disconn.right);
                Internal.decrease_link_set_count(self, state, 1);
                if (TAIL_NO_BACKWARD and disconn.right == NULL_IDX) {
                    Internal.set_last_index(self, state, idx);
                }
                if (HEAD_NO_FORWARD and disconn.left == NULL_IDX) {
                    Internal.set_first_index(self, state, idx);
                }
            }

            pub fn disconnect_many_first_last(self: *List, state: State, first_idx: Idx, last_idx: Idx, count: Idx) void {
                const disconn = Internal.get_conn_left_right_before_first_and_after_last(self, first_idx, last_idx, state);
                Internal.connect(disconn.left, disconn.right);
                Internal.decrease_link_set_count(self, disconn.set, count);
                if (TAIL_NO_BACKWARD and disconn.right == NULL_IDX) {
                    Internal.set_last_index(self, state, first_idx);
                }
                if (HEAD_NO_FORWARD and disconn.left == NULL_IDX) {
                    Internal.set_first_index(self, state, last_idx);
                }
            }

            pub inline fn connect_with_insert(self: *List, left_edge: ConnLeft, first_insert: ConnRight, last_insert: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(self, left_edge.idx_ptr, first_insert.idx);
                        set_next_idx(self, last_insert.idx_ptr, right_edge.idx);
                    } else {
                        set_next_idx(self, left_edge, first_insert);
                        set_next_idx(self, last_insert, right_edge);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(self, right_edge.idx_ptr, last_insert.idx);
                        set_prev_idx(self, first_insert.idx_ptr, left_edge.idx);
                    } else {
                        set_prev_idx(self, right_edge, last_insert);
                        set_prev_idx(self, first_insert, left_edge);
                    }
                }
            }

            pub inline fn connect(self: *List, left_edge: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(self, left_edge.idx, right_edge.idx);
                    } else {
                        set_next_idx(self, left_edge, right_edge);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(self, right_edge.idx_ptr, left_edge.idx);
                    } else {
                        set_prev_idx(self, right_edge, left_edge);
                    }
                }
            }

            pub inline fn get_conn_left(self: *List, state: State, idx: Idx) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .idx_ptr = if (idx == NULL_IDX) get_head_index_ref(self, state) else &@field(get_ptr(self, idx), NEXT_FIELD),
                };
                if (FORWARD) if (idx == NULL_IDX) get_head_index_ref(self, state) else &@field(get_ptr(self, idx), NEXT_FIELD);
                if (BACKWARD) return idx;
            }

            pub inline fn get_conn_left_from_set_head(self: *List, state: State) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_head_index_ref(self, state),
                };
                if (FORWARD) return get_head_index_ref(self, state);
                if (BACKWARD) return NULL_IDX;
            }

            pub inline fn get_conn_right(self: *List, state: State, idx: Idx) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .idx_ptr = if (idx == NULL_IDX) get_tail_index_ref(self, state) else &@field(get_ptr(self, idx), PREV_FIELD),
                };
                if (FORWARD) return idx;
                if (BACKWARD) return if (idx == NULL_IDX) get_tail_index_ref(self, state) else &@field(get_ptr(self, idx), PREV_FIELD);
            }

            pub inline fn get_conn_right_from_set_tail(self: *List, state: State) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_tail_index_ref(self, state),
                };
                if (FORWARD) return NULL_IDX;
                if (BACKWARD) return get_tail_index_ref(self, state);
            }

            pub inline fn get_next_idx_fwd(self: *const List, any: anytype) Idx {
                const T = @TypeOf(any);
                if (T == Idx) {
                    assert_idx_less_than_len(any, self.list.len, @src());
                    const ptr = self.get_ptr(any);
                    return @field(ptr, NEXT_FIELD);
                }
                if (T == *Elem or T == *const Elem) {
                    assert_pointer_resides_in_slice(Elem, self.list.slice(), any, @src());
                    return @field(any, NEXT_FIELD);
                }
            }

            pub inline fn get_prev_idx_bkd(self: *const List, any: anytype) Idx {
                const T = @TypeOf(any);
                if (T == Idx) {
                    assert_idx_less_than_len(any, self.list.len, @src());
                    const ptr = self.get_ptr(any);
                    return @field(ptr, PREV_FIELD);
                }
                if (T == *Elem or T == *const Elem) {
                    assert_pointer_resides_in_slice(Elem, self.list.slice(), any, @src());
                    return @field(any, PREV_FIELD);
                }
            }

            pub inline fn get_head_index_ref(self: *List, state: State) *Idx {
                return &self.sets[@intFromEnum(state)].first_idx;
            }

            pub inline fn get_tail_index_ref(self: *List, state: State) *Idx {
                return &self.sets[@intFromEnum(state)].last_idx;
            }

            pub fn get_conn_left_right_directly_before_this(self: *List, this: Idx, state: State) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_right(self, state, this);
                const prev_idx = self.get_next_idx(self, state, this);
                result.right = Internal.get_conn_right(self, state, prev_idx);
                return result;
            }

            pub fn get_conn_left_right_directly_after_this(self: *List, this: Idx, state: State) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_left(self, state, this);
                const next_idx = Internal.get_next_idx(self, state, this);
                result.right = Internal.get_conn_right(self, state, next_idx);
                return result;
            }

            pub fn get_conn_left_right_before_first_and_after_last(self: *List, first: Idx, last: Idx, state: State) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                const left_idx = self.get_prev_idx(state, first);
                result.left = Internal.get_conn_left(self, state, left_idx);
                const next_idx = self.get_next_idx(state, last);
                result.right = Internal.get_conn_right(self, state, next_idx);
                return result;
            }

            pub fn get_conn_left_right_for_tail_of_set(self: *List, state: State) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.right = Internal.get_conn_right_from_set_tail(self, state);
                const last_index = self.get_last_index_in_state(state);
                result.left = Internal.get_conn_left(self, state, last_index);
                return result;
            }

            pub fn get_conn_left_right_for_head_of_set(self: *List, state: State) ConnLeftRight {
                var result: ConnLeftRight = undefined;
                result.left = Internal.get_conn_left_from_set_head(self, state);
                const first_index = self.get_first_index_in_state(state);
                result.right = Internal.get_conn_right(self, state, first_index);
                return result;
            }

            pub fn traverse_to_get_first_idx_in_set(self: *const List, state: State) Idx {
                var ii: Idx = NULL_IDX;
                var i = self.get_last_index_in_state(state);
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_state_count(state) else void{};
                while (i != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = get_prev_idx(self, state, i);
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `BACKWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(state), c, limit });
                return ii;
            }

            pub fn traverse_to_get_last_item_in_set(self: *const List, state: State) Idx {
                var ii: Idx = NULL_IDX;
                var i = self.get_first_index_in_state(state);
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_state_count(state) else void{};
                while (i != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = get_next_idx(self, state, i.ptr);
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `FORWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(state), c, limit });
                return ii;
            }

            pub fn traverse_and_report_if_found_idx_in_set(self: *const List, state: State, idx: Idx) bool {
                var i: Idx = if (FORWARD) self.get_first_index_in_state(state) else self.get_first_index_in_state(state);
                var c: Idx = 0;
                const limit: Idx = self.get_state_count(state);
                while (i != NULL_IDX and (if (DEBUG) c < limit else true)) {
                    if (i == idx) return true;
                    i = if (FORWARD) get_next_idx(self, state, i) else get_prev_idx(self, state, i);
                    if (DEBUG) c += 1;
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(state), c, limit });
                return false;
            }

            pub fn traverse_to_find_index_preceding_this_one_in_direction(self: List, idx: Idx, state: State, comptime dir: Direction) Idx {
                var curr_idx: Idx = undefined;
                var count: Idx = 0;
                const limit = self.get_state_count(state);
                switch (dir) {
                    .BACKWARD => {
                        assert_with_reason(BACKWARD, @src(), "linked list does not link elements in the backward direction", .{});
                        curr_idx = self.get_last_index_in_state(state);
                    },
                    .FORWARD => {
                        assert_with_reason(FORWARD, @src(), "linked list does not link elements in the forward direction", .{});
                        curr_idx = self.get_first_index_in_state(state);
                    },
                }
                while (curr_idx != NULL_IDX) {
                    if (DEBUG) assert_with_reason(count < limit, @src(), "already traversed {d} (total set count) items in set `{s}`, but there are more non-null indexes after the last", .{ limit, @tagName(state) });
                    assert_with_reason(curr_idx < self.list.len, @src(), "while traversing set `{s}` in direction `{s}`, index {d} was found, which is out of bounds for list.len {d}", .{ @tagName(state), @tagName(dir), curr_idx, self.list.len });
                    const following_idx = switch (dir) {
                        .FORWARD => get_next_idx(self, state, curr_idx),
                        .BACKWARD => get_prev_idx(self, state, curr_idx),
                    };
                    if (following_idx == idx) return curr_idx;
                    curr_idx = following_idx;
                    if (DEBUG) count += 1;
                }
                if (DEBUG) assert_with_reason(count == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})\nALSO: no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ @tagName(state), count, limit, idx, @tagName(state), @tagName(dir) });
                assert_with_reason(false, @src(), "no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ idx, @tagName(state), @tagName(dir) });
            }

            pub inline fn get_state_raw(ptr: *const Elem) StateTag {
                return @as(StateTag, @intCast((@field(ptr, STATE_FIELD) & STATE_MASK) >> STATE_OFFSET));
            }

            pub fn assert_valid_state_idx(self: *const List, state_idx: StateIdx, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    assert_idx_less_than_len(state_idx.idx, self.list.len, src_loc);
                    const ptr = get_ptr(self, state_idx.idx);
                    if (STATE) assert_with_reason(get_state_raw(ptr) == @intFromEnum(state_idx.state), src_loc, "set {s} on SetIdx does not match state on elem at idx {d}", .{ @tagName(state_idx.state), state_idx.idx });
                    if (STRONG_ASSERT) {
                        const found_in_list = Internal.traverse_and_report_if_found_idx_in_set(self, state_idx.state, state_idx.idx);
                        assert_with_reason(found_in_list, src_loc, "while verifying idx {d} is in set {s}, the idx was not found when traversing the set", .{ state_idx.idx, @tagName(state_idx.set) });
                    }
                }
            }
            pub fn assert_valid_state_idx_list(self: *const List, set_idx_list: StateIdxList, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    for (set_idx_list.idxs) |idx| {
                        Internal.assert_valid_state_idx(self, StateIdx{ .set = set_idx_list.set, .idx = idx }, src_loc);
                    }
                }
            }
            pub fn assert_valid_list_of_state_idxs(self: *const List, set_idx_list: []const StateIdx, src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
                    for (set_idx_list) |set_idx_| {
                        Internal.assert_valid_state_idx(self, set_idx_, src_loc);
                    }
                }
            }

            pub fn assert_valid_slice(self: *const List, slice: LLSlice, src_loc: ?SourceLocation) void {
                assert_idx_less_than_len(slice.first, self.list.len, src_loc);
                assert_idx_less_than_len(slice.last, self.list.len, src_loc);
                if (!STRONG_ASSERT and STATE) {
                    assert_with_reason(self.idx_is_in_state(slice.first, slice.state), src_loc, "first index {d} is not in state `{s}`", .{ slice.first, @tagName(slice.state) });
                    assert_with_reason(self.idx_is_in_state(slice.last, slice.state), src_loc, "last index {d} is not in state `{s}`", .{ slice.last, @tagName(slice.state) });
                }
                if (STRONG_ASSERT) {
                    var c: Idx = 1;
                    var idx = if (FORWARD) slice.first else slice.last;
                    assert_idx_less_than_len(idx, self.list.len, @src());
                    const state = slice.state;
                    const last_idx = if (FORWARD) slice.last else slice.first;
                    Internal.assert_valid_state_idx(self, StateIdx{ .state = state, .idx = idx }, src_loc);
                    while (idx != last_idx and idx != NULL_IDX) {
                        idx = if (FORWARD) get_next_idx_fwd(self, idx) else get_prev_idx_bkd(self, idx);
                        c += 1;
                        Internal.assert_valid_state_idx(self, StateIdx{ .state = state, .idx = idx }, src_loc);
                    }
                    assert_with_reason(idx == last_idx, src_loc, "idx `first` ({d}) is not linked with idx `last` ({d})", .{ slice.first, slice.last });
                    assert_with_reason(c == slice.count, src_loc, "the slice count {d} did not match the number of traversed items between `first` and `last` ({d})", .{ slice.count, c });
                }
            }
        };

        fn iter_has_next(self: *anyopaque) bool {
            if (FORWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                return iter.right_idx != NULL_IDX;
            }
        }
        fn iter_get_next(self: *anyopaque) *Elem {
            if (FORWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                assert_idx_less_than_len(iter.right_idx, iter.list.list.len, @src());
                const curr_idx = iter.right_idx;
                iter.right_idx = iter.list.get_next_idx(iter.state, iter.right_idx);
                return iter.list.get_ptr(curr_idx);
            }
        }
        fn iter_get_next_or_null(self: *anyopaque) ?*Elem {
            if (FORWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                if (iter.right_idx == NULL_IDX) return null;
                const curr_idx = iter.right_idx;
                iter.right_idx = iter.list.get_next_idx(iter.state, iter.right_idx);
                return iter.list.get_ptr(curr_idx);
            }
        }
        fn iter_has_prev(self: *anyopaque) bool {
            if (BACKWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                return iter.list.get_prev_idx(iter.state, iter.left_idx) != NULL_IDX;
            }
        }
        fn iter_get_prev(self: *anyopaque) *Elem {
            if (BACKWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                const prev_idx = iter.list.get_prev_idx(iter.state, iter.next_idx);
                assert_idx_less_than_len(prev_idx, iter.list.list.len, @src());
                iter.next_idx = prev_idx;
                return iter.list.get_ptr(prev_idx);
            }
        }
        fn iter_get_prev_or_null(self: *anyopaque) ?*Elem {
            if (BACKWARD) {
                const iter: *IteratorState = @ptrCast(@alignCast(self));
                const prev_idx = iter.list.get_prev_idx(iter.state, iter.next_idx);
                if (prev_idx == NULL_IDX) return null;
                iter.next_idx = prev_idx;
                return iter.list.get_ptr(prev_idx);
            }
        }
        fn iter_reset(self: *anyopaque) void {
            const iter: *IteratorState = @ptrCast(@alignCast(self));
            if (FORWARD) {
                iter.right_idx = iter.list.get_first_index_in_state(iter.state);
            } else {
                iter.left_idx = iter.list.get_last_index_in_state(iter.state);
            }
        }

        pub const IteratorState = if (BIDIRECTION) struct {
            list: *List,
            state: State,
            left_idx: Idx,
            right_idx: Idx,

            pub fn iterator(self: *IteratorState) Iterator(Elem, true, true) {
                return Iterator(Elem, true, true){
                    .implementor = @ptrCast(self),
                    .vtable = Iterator(Elem, true, true).VTable{
                        .reset = iter_reset,
                        .has_next = iter_has_next,
                        .get_next = iter_get_next,
                        .get_next_or_null = iter_get_next_or_null,
                        .has_prev = iter_has_next,
                        .get_prev = iter_get_prev,
                        .get_prev_or_null = iter_get_next_or_null,
                    },
                };
            }
        } else if (FORWARD) struct {
            list: *List,
            state: State,
            right_idx: Idx,

            pub fn iterator(self: *IteratorState) Iterator(Elem, false, true) {
                return Iterator(Elem, true, true){
                    .implementor = @ptrCast(self),
                    .vtable = Iterator(Elem, true, true).VTable{
                        .reset = iter_reset,
                        .has_next = iter_has_next,
                        .get_next = iter_get_next,
                        .get_next_or_null = iter_get_next_or_null,
                    },
                };
            }
        } else struct {
            list: *List,
            state: State,
            left_idx: Idx,

            pub fn iterator(self: *IteratorState) Iterator(Elem, false, true) {
                return Iterator(Elem, true, true){
                    .implementor = @ptrCast(self),
                    .vtable = Iterator(Elem, true, true).VTable{
                        .reset = iter_reset,
                        .has_next = iter_has_prev,
                        .get_next = iter_get_prev,
                        .get_next_or_null = iter_get_prev_or_null,
                    },
                };
            }
        };

        pub inline fn new_iterator_state(self: *List, state: State) IteratorState {
            if (BIDIRECTION) {
                return IteratorState{
                    .list = self,
                    .state = state,
                    .left_idx = NULL_IDX,
                    .right_idx = self.get_first_index_in_state(state),
                };
            } else if (FORWARD) {
                return IteratorState{
                    .list = self,
                    .state = state,
                    .right_idx = self.get_first_index_in_state(state),
                };
            } else {
                return IteratorState{
                    .list = self,
                    .state = state,
                    .left_idx = self.get_last_index_in_state(state),
                };
            }
        }

        pub fn new_empty() List {
            return UNINIT;
        }

        pub fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            var self = UNINIT;
            if (RETURN_ERRORS) {
                try self.list.ensure_total_capacity_exact(capacity, alloc);
            } else {
                self.list.ensure_total_capacity_exact(capacity, alloc);
            }
            return self;
        }

        pub fn clone(self: List, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            var new_list = self;
            new_list.list = if (RETURN_ERRORS) try self.list.clone(alloc) else self.list.clone(alloc);
            return new_list;
        }

        pub inline fn get_state_count(self: *List, state: State) Idx {
            return self.sets[@intFromEnum(state)].count;
        }

        pub inline fn get_ptr(self: *const List, idx: Idx) *Elem {
            assert_idx_less_than_len(idx, self.list.len, @src());
            return &self.list.ptr[idx];
        }

        pub inline fn get_prev_idx(self: *const List, state: State, this_idx: Idx) Idx {
            if (BACKWARD) {
                const ptr = get_ptr(self, this_idx);
                return @field(ptr, PREV_FIELD);
            }
            return Internal.traverse_to_find_index_preceding_this_one_in_direction(self, this_idx, state, .FORWARD);
        }

        pub inline fn get_next_idx(self: *const List, state: State, this_idx: Idx) Idx {
            if (FORWARD) {
                const ptr = get_ptr(self, this_idx);
                return @field(ptr, NEXT_FIELD);
            }
            return Internal.traverse_to_find_index_preceding_this_one_in_direction(self, this_idx, state, .BACKWARD);
        }

        pub fn get_nth_idx_from_start_of_state(self: *const List, state: State, n: Idx) Idx {
            const set_count = self.get_state_count(state);
            assert_with_reason(n < set_count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(state), set_count });
            if (FORWARD) {
                var c = 0;
                var idx = self.get_first_index_in_state(state);
                while (c != n) {
                    c += 1;
                    idx = get_next_idx(self, state, idx);
                }
                return idx;
            } else {
                var c: Idx = 0;
                var idx = self.get_last_index_in_state(state);
                const nn = set_count - n;
                while (c < nn) {
                    c += 1;
                    idx = get_prev_idx(self, state, idx);
                }
                return idx;
            }
        }

        pub fn get_nth_idx_from_end_of_state(self: *const List, state: State, n: Idx) Idx {
            const count = self.get_state_count(state);
            assert_with_reason(n < count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ n, @tagName(state), count });
            if (BACKWARD) {
                var c = 0;
                var idx = self.get_last_index_in_state(state);
                while (c != n) {
                    c += 1;
                    idx = get_prev_idx(self, state, idx);
                }
                return idx;
            } else {
                var c: Idx = 0;
                var idx = self.get_first_index_in_state(state);
                const nn = count - n;
                while (c < nn) {
                    c += 1;
                    idx = get_next_idx(self, state, idx);
                }
                return idx;
            }
        }

        pub inline fn idx_is_in_state(self: *const List, idx: Idx, state: State) bool {
            if (STATE) {
                const ptr = get_ptr(self, idx);
                return Internal.get_state_raw(ptr) == @intFromEnum(state);
            }
            return Internal.traverse_and_report_if_found_idx_in_set(self, state, idx);
        }

        pub inline fn find_state_idx_is_in(self: *const List, idx: Idx) State {
            if (STATE) {
                const ptr = self.get_ptr(idx);
                const cached_val: StateTag = @as(StateTag, @intCast((@field(ptr, STATE_FIELD) & STATE_MASK) >> STATE_OFFSET));
                if (STRONG_ASSERT) {
                    var e: StateTag = 0;
                    while (e <= MAX_STATE_TAG) : (e += 1) {
                        const s: State = @enumFromInt(e);
                        var state_idx = if (FORWARD) self.get_first_index_in_state(s) else self.get_last_index_in_state(s);
                        while (state_idx != NULL_IDX) {
                            if (state_idx == idx) assert_with_reason(e == cached_val, @src(), "idx {d} was found in state list `{s}`, but the value cached on the item indicates state `{s}`", .{ idx, @tagName(s), if (cached_val > MAX_STATE_TAG) "(INVALID STATE)" else @tagName(@as(State, @enumFromInt(cached_val))) });
                            state_idx = if (FORWARD) Internal.get_next_idx(self, s, state_idx) else Internal.get_prev_idx(self, s, state_idx);
                        }
                    }
                }
                assert_with_reason(cached_val <= MAX_STATE_TAG, @src(), "idx {d} has an invalid tag for State enum {d}", .{ idx, cached_val });
                return @as(State, @enumFromInt(cached_val));
            }
            var e: StateTag = 0;
            while (e <= MAX_STATE_TAG) : (e += 1) {
                const s: State = @enumFromInt(e);
                var state_idx = if (FORWARD) self.get_first_index_in_state(s) else self.get_last_index_in_state(s);
                while (state_idx != NULL_IDX) {
                    if (state_idx == idx) return s;
                    state_idx = if (FORWARD) Internal.get_next_idx(self, s, state_idx) else Internal.get_prev_idx(self, s, state_idx);
                }
            }
            assert_with_reason(false, @src(), "idx {d} was not found in any state list", .{idx});
        }

        pub inline fn get_first_index_in_state(self: *const List, state: State) Idx {
            if (HEAD) return self.sets[@intFromEnum(state)].first_idx;
            return Internal.traverse_to_get_first_idx_in_set(self, state).idx;
        }

        pub inline fn get_last_index_in_state(self: *const List, state: State) Idx {
            if (TAIL) return self.sets[@intFromEnum(state)].last_idx;
            return Internal.traverse_to_get_last_item_in_set(self, state).idx;
        }

        fn get_items_and_insert_at_internal(self: *List, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime insert_mode: InsertMode, insert_val: InsertVal(insert_mode), alloc: Allocator, comptime ASSUME_CAP: bool) if (!ASSUME_CAP and RETURN_ERRORS) Error!LLSlice else LLSlice {
            var insert_edges: ConnLeftRight = undefined;
            var insert_state: State = undefined;
            switch (insert_mode) {
                .AFTER_INDEX => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    insert_edges = Internal.get_conn_left_right_directly_after_this(self, state_idx.idx, state_idx.state);
                    insert_state = state_idx.state;
                },
                .BEFORE_INDEX => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    insert_edges = Internal.get_conn_left_right_directly_before_this(self, state_idx.idx, state_idx.state);
                    insert_state = state_idx.state;
                },
                .AT_BEGINNING_OF_SET => {
                    const state: State = insert_val;
                    insert_edges = Internal.get_conn_left_right_for_head_of_set(self, state);
                    insert_state = state;
                },
                .AT_END_OF_SET => {
                    const state: State = insert_val;
                    insert_edges = Internal.get_conn_left_right_for_tail_of_set(self, state);
                    insert_state = state;
                },
                .AFTER_NTH_ITEM_FROM_END_OF_SET => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    const nth_idx = self.get_nth_idx_from_end_of_state(state_idx.state, state_idx.idx);
                    insert_edges = Internal.get_conn_left_right_directly_after_this(self, nth_idx, state_idx.state);
                    insert_state = state_idx.state;
                },
                .BEFORE_NTH_ITEM_FROM_END_OF_SET => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    const nth_idx = self.get_nth_idx_from_end_of_state(state_idx.state, state_idx.idx);
                    insert_edges = Internal.get_connect_data_directly_before_this(self, nth_idx, state_idx.state);
                    insert_state = state_idx.state;
                },
                .AFTER_NTH_ITEM_FROM_START_OF_SET => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    const nth_idx = self.get_nth_idx_from_start_of_state(state_idx.state, state_idx.idx);
                    insert_edges = Internal.get_conn_left_right_directly_after_this(self, nth_idx, state_idx.state);
                    insert_state = state_idx.state;
                },
                .BEFORE_NTH_ITEM_FROM_START_OF_SET => {
                    const state_idx: StateIdx = insert_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    const nth_idx = self.get_nth_idx_from_start_of_state(state_idx.state, state_idx.idx);
                    insert_edges = Internal.get_conn_left_right_directly_before_this(self, nth_idx, state_idx.state);
                    insert_state = state_idx.state;
                },
            }
            var return_items: LLSlice = undefined;
            switch (get_mode) {
                .ONE_NEW => {
                    const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                    return_items.first = new_idx;
                    return_items.last = new_idx;
                    return_items.count = 1;
                },
                .FIRST_FROM_SET, .FIRST_FROM_SET_ELSE_NEW => {
                    const state: State = get_val;
                    const state_count: debug_switch(Idx, void) = debug_switch(self.get_state_count(state), void{});
                    const first_idx = self.get_first_index_in_state(state);
                    if (get_mode == .FIRST_FROM_SET_ELSE_NEW and (debug_switch(state_count == 0, false) or first_idx == NULL_IDX)) {
                        const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                        return_items.first = new_idx;
                        return_items.last = new_idx;
                        return_items.count = 1;
                    } else {
                        assert_with_reason(debug_switch(state_count > 0, true) and first_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(state), debug_switch(state_count, 0), first_idx, self.list.len });
                        return_items.first = first_idx;
                        return_items.last = first_idx;
                        return_items.count = 1;
                        Internal.disconnect_one(self, state, first_idx);
                    }
                },
                .LAST_FROM_SET, .LAST_FROM_SET_ELSE_NEW => {
                    const state: State = get_val;
                    const state_count: debug_switch(Idx, void) = debug_switch(self.get_state_count(state), void{});
                    const last_idx = self.get_last_index_in_state(state);
                    if (get_mode == .LAST_FROM_SET_ELSE_NEW and (debug_switch(state_count == 0, false) or last_idx == NULL_IDX)) {
                        const new_idx = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc));
                        return_items.first = new_idx;
                        return_items.last = new_idx;
                        return_items.count = 1;
                    } else {
                        assert_with_reason(debug_switch(state_count > 0, true) and last_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(state), debug_switch(state_count, 0), last_idx, self.list.len });
                        return_items.first = last_idx;
                        return_items.last = last_idx;
                        return_items.count = 1;
                        Internal.disconnect_one(self, state, last_idx);
                    }
                },
                .ONE_INDEX => {
                    const state_idx: StateIdx = get_val;
                    Internal.assert_valid_state_idx(self, state_idx, @src());
                    return_items.first = state_idx.idx;
                    return_items.last = state_idx.idx;
                    return_items.count = 1;
                    Internal.disconnect_one(self, state_idx.set, state_idx.idx);
                },
                .MANY_NEW => {
                    const count: Idx = get_val;

                    assert_with_reason(count > 0, @src(), "cannot get `0` new items", .{});
                    const first_idx = self.list.len;
                    const last_idx = self.list.len + count - 1;
                    _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count) else (if (RETURN_ERRORS) try self.list.append_many_slots(count, alloc) else self.list.append_many_slots(count, alloc));
                    Internal.link_new_indexes(self, insert_state, first_idx, last_idx);
                    return_items.first = first_idx;
                    return_items.last = last_idx;
                    return_items.count = count;
                },
                .FIRST_N_FROM_SET => {
                    const state_count: StateCount = get_val;
                    assert_with_reason(state_count.count > 0, @src(), "cannot get `0` items", .{});
                    assert_with_reason(self.get_state_count(state_count.set) >= state_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ state_count.count, @tagName(state_count.state), self.get_state_count(state_count.state) });
                    return_items.first = self.get_first_index_in_state(state_count.set);
                    return_items.last = self.get_nth_idx_from_start_of_state(state_count.state, state_count.count - 1);
                    return_items.count = state_count.count;
                    Internal.disconnect_many_first_last(self, state_count.state, return_items.first, return_items.last, state_count.count);
                },
                .LAST_N_FROM_SET => {
                    const state_count: StateCount = get_val;
                    assert_with_reason(state_count.count > 0, @src(), "cannot insert `0` items", .{});
                    assert_with_reason(self.get_state_count(state_count.state) >= state_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ state_count.count, @tagName(state_count.state), self.get_state_count(state_count.state) });
                    return_items.last = self.get_last_index_in_state(state_count.state);
                    return_items.first = self.get_nth_idx_from_end_of_state(state_count.state, state_count.count - 1);
                    return_items.count = state_count.count;
                    Internal.disconnect_many_first_last(self, state_count.state, return_items.first, return_items.last, state_count.count);
                },
                .FIRST_N_FROM_SET_ELSE_NEW => {
                    const state_count: StateCount = get_val;
                    assert_with_reason(state_count.count > 0, @src(), "cannot insert `0` items", .{});
                    const count_from_state = @max(self.get_state_count(state_count.state), state_count.count);
                    const count_from_new = state_count.count - count_from_state;
                    var first_new_idx: Idx = undefined;
                    var last_moved_idx: Idx = undefined;
                    const needs_new = count_from_new > 0;
                    const needs_move = count_from_state > 0;
                    if (needs_new) {
                        first_new_idx = self.list.len;
                        const last_new_idx = self.list.len + count_from_new - 1;
                        _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                        Internal.link_new_indexes(self, state_count, first_new_idx, last_new_idx);
                        if (needs_move) {
                            first_new_idx = first_new_idx;
                        } else {
                            return_items.first = first_new_idx;
                        }
                        return_items.last = last_new_idx;
                    }
                    if (needs_move) {
                        return_items.first = self.get_first_index_in_state(state_count.state);
                        if (needs_new) {
                            last_moved_idx = self.get_nth_idx_from_start_of_state(state_count.state, count_from_state - 1);
                            Internal.disconnect_many_first_last(self, state_count.state, return_items.first, last_moved_idx, count_from_state);
                        } else {
                            return_items.last = self.get_nth_idx_from_start_of_state(state_count.state, count_from_state - 1);
                            Internal.disconnect_many_first_last(self, state_count.state, return_items.first, return_items.last, count_from_state);
                        }
                    }
                    if (needs_new and needs_move) {
                        const mid_left = Internal.get_conn_left(self, state_count.state, last_moved_idx);
                        const mid_right = Internal.get_conn_right(self, state_count.state, first_new_idx);
                        Internal.connect(mid_left, mid_right);
                    }
                    return_items.count = state_count.count;
                },
                .LAST_N_FROM_SET_ELSE_NEW => {
                    const state_count: StateCount = get_val;
                    assert_with_reason(state_count.count > 0, @src(), "cannot insert `0` items", .{});
                    const count_from_state = @max(self.get_state_count(state_count.state), state_count.count);
                    const count_from_new = state_count.count - count_from_state;
                    var first_new_idx: Idx = undefined;
                    var last_moved_idx: Idx = undefined;
                    const needs_new = count_from_new > 0;
                    const needs_move = count_from_state > 0;
                    if (needs_new) {
                        first_new_idx = self.list.len;
                        const last_new_idx = self.list.len + count_from_new - 1;
                        _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                        Internal.link_new_indexes(self, state_count, first_new_idx, last_new_idx);
                        if (needs_move) {
                            first_new_idx = first_new_idx;
                        } else {
                            return_items.first = first_new_idx;
                        }
                        return_items.last = last_new_idx;
                    }
                    if (needs_move) {
                        return_items.first = self.get_nth_idx_from_end_of_state(state_count.state, count_from_state - 1);
                        if (needs_new) {
                            last_moved_idx = self.get_last_index_in_state(state_count.state);
                            Internal.disconnect_many_first_last(self, state_count.state, return_items.first, last_moved_idx, count_from_state);
                        } else {
                            return_items.last = self.get_last_index_in_state(state_count.state);
                            Internal.disconnect_items_first_last(self, state_count.state, return_items.first, return_items.last, count_from_state);
                        }
                    }
                    if (needs_new and needs_move) {
                        const mid_left = Internal.get_conn_left(self, state_count.state, last_moved_idx);
                        const mid_right = Internal.get_conn_right(self, state_count.state, first_new_idx);
                        Internal.connect(mid_left, mid_right);
                    }
                },
                .SPARSE_LIST_FROM_SAME_SET => {
                    const state_idx_list: StateIdxList = get_val;
                    Internal.assert_valid_state_idx_list(self, state_idx_list, @src());
                    return_items.first = state_idx_list.idxs[0];
                    Internal.disconnect_one(self, state_idx_list.state, return_items.first);
                    var prev_idx: Idx = return_items.first;
                    for (state_idx_list.idxs[1..]) |this_idx| {
                        Internal.disconnect_one(self, state_idx_list.state, this_idx);
                        const conn_left = Internal.get_conn_left(self, state_idx_list.state, prev_idx);
                        const conn_right = Internal.get_conn_right(self, state_idx_list.state, this_idx);
                        Internal.connect(conn_left, conn_right);
                        prev_idx = this_idx;
                    }
                    return_items.last = prev_idx;
                    return_items.count = @intCast(state_idx_list.idxs.len);
                },
                .SPARSE_LIST_FROM_ANY_SET => {
                    const state_idxs: []const StateIdx = get_val;
                    Internal.assert_valid_list_of_state_idxs(self, state_idxs, @src());
                    return_items.first = state_idxs[0];
                    Internal.disconnect_one(self, state_idxs[0].state, return_items.first);
                    var prev_idx: Idx = return_items.first;
                    for (state_idxs[1..]) |state_idx| {
                        const this_idx = state_idx.idx;
                        Internal.disconnect_one(self, state_idx.state, this_idx.idx);
                        const conn_left = Internal.get_conn_left(self, state_idx.state, prev_idx);
                        const conn_right = Internal.get_conn_right(self, state_idx.state, this_idx);
                        Internal.connect(conn_left, conn_right);
                        prev_idx = this_idx;
                    }
                    return_items.last = prev_idx;
                    return_items.count = @intCast(state_idxs.len);
                },
                .SLICE => {
                    const slice: LLSlice = get_val;
                    Internal.assert_valid_slice(self, slice, @src());
                    return_items.first = slice.first;
                    return_items.last = slice.last;
                    return_items.count = slice.count;
                },
                .SLICE_ELSE_NEW => {
                    const supp_slice: LLSupplySlice = get_val;
                    Internal.assert_valid_slice(self, supp_slice.slice, @src());
                    const count_from_slice = @max(self.get_state_count(supp_slice.slice.count), supp_slice.total_needed);
                    const count_from_new = supp_slice.total_needed - count_from_slice;
                    var first_new_idx: Idx = undefined;
                    var last_moved_idx: Idx = undefined;
                    const needs_new = count_from_new > 0;
                    const needs_move = count_from_slice > 0;
                    if (needs_new) {
                        first_new_idx = self.list.len;
                        const last_new_idx = self.list.len + count_from_new - 1;
                        _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                        Internal.link_new_indexes(self, supp_slice.slice.state, first_new_idx, last_new_idx);
                        if (needs_move) {
                            first_new_idx = first_new_idx;
                        } else {
                            return_items.first = first_new_idx;
                        }
                        return_items.last = last_new_idx;
                    }
                    if (needs_move) {
                        return_items.first = self.get_nth_idx_from_end_of_state(supp_slice.slice.state, count_from_slice - 1);
                        if (needs_new) {
                            last_moved_idx = self.get_last_index_in_state(supp_slice.slice.state);
                            Internal.disconnect_many_first_last(self, supp_slice.slice.state, return_items.first, last_moved_idx, count_from_slice);
                        } else {
                            return_items.last = self.get_last_index_in_state(supp_slice.slice.state);
                            Internal.disconnect_items_first_last(self, supp_slice.slice.state, return_items.first, return_items.last, count_from_slice);
                        }
                    }
                    if (needs_new and needs_move) {
                        const mid_left = Internal.get_conn_left(self, supp_slice.slice.state, last_moved_idx);
                        const mid_right = Internal.get_conn_right(self, supp_slice.slice.state, first_new_idx);
                        Internal.connect(mid_left, mid_right);
                    }
                    return_items.count = supp_slice.total_needed;
                },
            }
            const insert_first = Internal.get_conn_right(self, insert_state, return_items.first);
            const insert_last = Internal.get_conn_left(self, insert_state, return_items.last);
            Internal.connect_with_insert(self, insert_edges.left, insert_first, insert_last, insert_edges.right);
            Internal.increase_link_set_count(self, insert_state, return_items.count);
            if (TAIL_NO_BACKWARD and insert_edges.right == NULL_IDX) {
                Internal.state_last_index(self, insert_state, return_items.last.idx);
            }
            if (HEAD_NO_FORWARD and insert_edges.left == NULL_IDX) {
                Internal.set_first_index(self, insert_state, return_items.first.idx);
            }
            Internal.set_state_on_indexes_first_last(self, return_items.first, return_items.last, insert_state);
            return_items.state = insert_state;
            return return_items;
        }

        pub inline fn get_items_and_insert_at_assume_capacity(self: *List, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime insert_mode: InsertMode, insert_val: InsertVal(insert_mode)) LLSlice {
            return self.get_items_and_insert_at_internal(get_mode, get_val, insert_mode, insert_val, DummyAllocator.allocator, true);
        }

        pub fn get_items_and_insert_at(self: *List, comptime get_mode: GetMode, get_val: GetVal(get_mode), comptime insert_mode: InsertMode, insert_val: InsertVal(insert_mode), alloc: Allocator) if (RETURN_ERRORS) Error!LLSlice else LLSlice {
            return self.get_items_and_insert_at_internal(get_mode, get_val, insert_mode, insert_val, alloc, false);
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
    const t = std.testing;
    t.log_level = .debug;
    const alloc = std.heap.page_allocator;
    const elem = struct {
        prev: u16,
        val: u8,
        idx: u16,
        state: u8,
        next: u16,
    };
    const states = enum(u8) {
        USED,
        FREE,
    };
    const opts = LinkedListOptions{
        .list_options = Root.List.ListOptions{
            .alignment = null,
            .alloc_error_behavior = .ERRORS_PANIC,
            .element_type = elem,
            .growth_model = .GROW_BY_25_PERCENT,
            .index_type = u16,
            .secure_wipe_bytes = true,
        },
        .linked_set_enum = states,
        .forward_linkage = "next",
        .backward_linkage = "prev",
        .element_idx_cache_field = "idx",
        .force_cache_first_index = true,
        .force_cache_last_index = true,
        .element_state_access = ElementStateAccess{
            .field = "state",
            .field_bit_offset = 1,
            .field_bit_count = 2,
            .field_type = u8,
        },
        .stronger_asserts = true,
    };
    const List = define_manual_allocator_linked_list_type(opts);
    var list = List.new_empty();
    _ = list.get_items_and_insert_at(.MANY_NEW, 20, .AT_BEGINNING_OF_SET, .FREE, alloc);
    try t.expectEqual(20, list.get_state_count(.FREE));
    try t.expectEqual(0, list.get_state_count(.USED));
    try t.expectEqual(List.NULL_IDX, list.get_first_index_in_state(.USED));
    try t.expectEqual(List.NULL_IDX, list.get_last_index_in_state(.USED));
    // const opts = ListOptions{
    //     .error_behavior = .ERRORS_PANIC,
    //     .element_type = u8,
    //     .index_type = u32,
    // };
    // const List = define_manual_allocator_list_type(opts);
    // var list = List.new_empty();

    // list.append('H', alloc);
    // list.append('e', alloc);
    // list.append('l', alloc);
    // list.append('l', alloc);
    // list.append('o', alloc);
    // list.append(' ', alloc);
    // list.append_slice("World", alloc);
    // try t.expectEqualStrings("Hello World", list.slice());
    // const letter_l = list.remove(2);
    // try t.expectEqual('l', letter_l);
    // try t.expectEqualStrings("Helo World", list.slice());
    // list.replace_range(3, 3, &.{ 'a', 'b', 'c' }, alloc);
    // try t.expectEqualStrings("Helabcorld", list.slice());
}
