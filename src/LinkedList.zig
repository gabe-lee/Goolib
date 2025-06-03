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
    stronger_asserts: bool = true,
};

pub const DefaultSet = enum(u8) {
    USED = 0,
    FREE = 1,
};

pub const ElementStateAccess = struct {
    field: []const u8,
    field_type: type,
    state_mask: comptime_int,
    /// This field must provide all flag values for each of the stated enum
    /// values in `linked_set_enum`
    ///
    /// Index 0 represents enum tag value 0, index 1 represents tag value 1, etc
    state_flags: []const comptime_int,
};

pub const Direction = enum {
    FORWARD,
    BACKWARD,
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
        assert_with_reason(options.element_state_access.?.state_mask > 0, @src(), "element state mask == 0, has no bits and cannot isolate state bits", .{});
        assert_with_reason(options.element_state_access.?.state_flags.len == Types.enum_defined_field_count(options.linked_set_enum), @src(), "number of flags provided in `element_state_access.state_flags` doe not match the number of tags in `linked_set_enum`", .{});
        assert_with_reason(Types.enum_is_exhaustive(options.linked_set_enum), @src(), "`linked_set_enum` must be exhaustive", .{});
        const composite_flags = comptime make: {
            var comp: comptime_int = 0;
            for (options.element_state_access.?.state_flags) |flag| {
                comp |= flag;
            }
            break :make comp;
        };
        const inv_composite = ~composite_flags;
        assert_with_reason(options.element_state_access.?.state_mask & inv_composite == 0, @src(), "one of the flags in `options.element_state_access.state_flags` are not covered by `options.element_state_access.state_mask`, cannot isolate all state bits", .{});
    }
    if (C) {
        const C_FIELD = options.element_idx_cache_field.?;
        assert_with_reason(@hasField(options.list_options.element_type, C_FIELD), @src(), "element type `{s}` has no field named `{s}`", .{ @typeName(options.list_options.element_type), C_FIELD });
        const C_TYPE = @FieldType(options.list_options.element_type, C_FIELD);
        assert_with_reason(C_TYPE == options.list_options.index_type, @src(), "element state field `.{s}` on element type `{s}` does not match options.list_options.index_type `{s}`", .{ C_FIELD, @typeName(options.list_options.element_type), @typeName(options.list_options.index_type) });
    }
    const SETS_ARRAY: if (S) [options.element_state_access.?.state_flags.len]options.element_state_access.?.field_type else void = if (S) make: {
        var arr: [options.element_state_access.?.state_flags.len]options.element_state_access.?.field_type = undefined;
        for (0..options.element_state_access.?.state_flags.len) |idx| {
            arr[idx] = options.element_state_access.?.state_flags.ptr[idx];
        }
        break :make arr;
    } else void{};
    return extern struct {
        list: BaseList = BaseList.UNINIT,
        sets: [SET_COUNT]SetData = UNINIT_SETS,

        const SET_COUNT = Types.enum_defined_field_count(options.linked_set_enum);
        const FORWARD = options.forward_linkage != null;
        const HEAD_NO_FORWARD = HEAD and !FORWARD;
        const NEXT_FIELD = if (FORWARD) options.forward_linkage.?.next_index_field else "";
        const BACKWARD = options.backward_linkage != null;
        const TAIL_NO_BACKWARD = TAIL and !BACKWARD;
        const BIDIRECTION = BACKWARD and FORWARD;
        const HEAD = FORWARD or options.force_cache_first_index;
        const TAIL = BACKWARD or options.force_cache_last_index;
        const PREV_FIELD = if (BACKWARD) options.backward_linkage.?.prev_index_field else "";
        const USED = options.linked_sets == .USED_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        const FREE = options.linked_sets == .FREE_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        const STATE = options.element_state_access != null;
        const CACHE = options.element_idx_cache_field != null;
        const CACHE_FIELD = if (CACHE) options.element_idx_cache_field.? else "";
        const T_STATE = if (STATE) options.element_state_access.?.field_type else void;
        const STATE_FIELD = if (STATE) options.element_state_access.?.field else "";
        const UNINIT = List{};
        const RETURN_ERRORS = options.list_options.error_behavior == .RETURN_ERRORS;
        const NULL_IDX = math.maxInt(Idx);
        const STATE_FLAGS = SETS_ARRAY;
        const STATE_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) options.element_state_access.?.state_mask else 0;
        const STATE_CLEAR_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) ~options.element_state_access.?.state_mask else 0b1111111111111111111111111111111111111111111111111111111111111111;
        const HEAD_TAIL: u2 = (@as(u2, @intFromBool(HEAD)) << 1) | @as(u2, @intFromBool(TAIL));
        const HAS_HEAD_HAS_TAIL: u2 = 0b11;
        const HAS_HEAD_NO_TAIL: u2 = 0b10;
        const NO_HEAD_HAS_TAIL: u2 = 0b01;
        const UNINIT_SETS: [SET_COUNT]SetData = build: {
            var sets: [SET_COUNT]SetData = undefined;
            for (0..SET_COUNT) |idx| {
                sets[idx] = SetData{};
            }
            break :build sets;
        };

        const List = @This();
        pub const BaseList = Root.List.define_manual_allocator_list_type(options.list_options);
        pub const Error = Allocator.Error;
        pub const Elem = options.list_options.element_type;
        pub const Idx = options.list_options.index_type;
        pub const Iterator = LinkedListIterator(List);
        pub const LinkSet = options.linked_set_enum;
        pub const SetData = switch (HEAD_TAIL) {
            HAS_HEAD_HAS_TAIL => struct {
                first_idx: Idx = 0,
                last_idx: Idx = 0,
                count: Idx = 0,
            },
            HAS_HEAD_NO_TAIL => struct {
                first_idx: Idx = 0,
                count: Idx = 0,
            },
            NO_HEAD_HAS_TAIL => struct {
                last_idx: Idx = 0,
                count: Idx = 0,
            },
            else => unreachable,
        };
        pub const Item = struct {
            ptr: *Elem = &DUMMY_ELEM,
            idx: Idx = NULL_IDX,
        };
        pub const FirstLastItem = struct {
            first: Item = Item{},
            last: Item = Item{},

            pub fn single(item: Item) FirstLastItem {
                return FirstLastItem{
                    .first = item,
                    .last = item,
                };
            }

            pub fn combine(left: FirstLastItem, right: FirstLastItem) FirstLastItem {
                return FirstLastItem{
                    .first = left.first,
                    .last = right.last,
                };
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
        pub const SetPtr = struct {
            set: LinkSet,
            ptr: *Elem,
        };
        pub const SetItem = struct {
            set: LinkSet,
            item: Item,
        };
        pub const SetIdx = struct {
            set: LinkSet,
            idx: Idx,
        };
        pub const SetIdxList = struct {
            set: LinkSet,
            idxs: []const Idx,
        };
        pub const SetPtrList = struct {
            set: LinkSet,
            ptrs: []const *Elem,
        };
        pub const SetItemList = struct {
            set: LinkSet,
            items: []const Item,
        };
        pub const SetCount = struct {
            set: LinkSet,
            count: Idx,
        };
        var DUMMY_IDX: Idx = NULL_IDX;
        var DUMMY_ELEM: Elem = undefined;

        pub const RemoveMode = enum {
            ONE_NEW,
            FIRST_FROM_SET_ELSE_NEW,
            LAST_FROM_SET_ELSE_NEW,
            FIRST_FROM_SET,
            LAST_FROM_SET,
            ONE_INDEX,
            ONE_PTR,
            ONE_ITEM,
            MANY_NEW,
            FIRST_N_FROM_SET,
            LAST_N_FROM_SET,
            FIRST_N_FROM_SET_ELSE_NEW,
            LAST_N_FROM_SET_ELSE_NEW,
            SPARSE_LIST_OF_INDEXES_FROM_SAME_SET,
            SPARSE_LIST_OF_POINTERS_FROM_SAME_SET,
            SPARSE_LIST_OF_ITEMS_FROM_SAME_SET,
            SPARSE_LIST_OF_INDEXES_FROM_ANY_SET,
            SPARSE_LIST_OF_POINTERS_FROM_ANY_SET,
            SPARSE_LIST_OF_ITEMS_FROM_ANY_SET,
        };

        pub const RemoveLocation = union(RemoveMode) {
            ONE_NEW: void,
            FIRST_FROM_SET_ELSE_NEW: LinkSet,
            LAST_FROM_SET_ELSE_NEW: LinkSet,
            FIRST_FROM_SET: LinkSet,
            LAST_FROM_SET: LinkSet,
            ONE_INDEX: SetIdx,
            ONE_PTR: SetPtr,
            ONE_ITEM: SetItem,
            MANY_NEW: Idx,
            FIRST_N_FROM_SET: SetCount,
            LAST_N_FROM_SET: SetCount,
            FIRST_N_FROM_SET_ELSE_NEW: SetCount,
            LAST_N_FROM_SET_ELSE_NEW: SetCount,
            SPARSE_LIST_OF_INDEXES_FROM_SAME_SET: SetIdxList,
            SPARSE_LIST_OF_POINTERS_FROM_SAME_SET: SetPtrList,
            SPARSE_LIST_OF_ITEMS_FROM_SAME_SET: SetItemList,
            SPARSE_LIST_OF_INDEXES_FROM_ANY_SET: []const SetIdx,
            SPARSE_LIST_OF_POINTERS_FROM_ANY_SET: []const SetPtr,
            SPARSE_LIST_OF_ITEMS_FROM_ANY_SET: []const SetItem,

            pub inline fn one_new() RemoveLocation {
                return RemoveLocation{ .ONE_NEW = void{} };
            }

            pub inline fn first_from_set_else_new(set: LinkSet) RemoveLocation {
                return RemoveLocation{ .FIRST_FROM_SET_ELSE_NEW = set };
            }

            pub inline fn last_from_set_else_new(set: LinkSet) RemoveLocation {
                return RemoveLocation{ .LAST_FROM_SET_ELSE_NEW = set };
            }

            pub inline fn first_from_set(set: LinkSet) RemoveLocation {
                return RemoveLocation{ .FIRST_FROM_SET = set };
            }

            pub inline fn last_from_set(set: LinkSet) RemoveLocation {
                return RemoveLocation{ .LAST_FROM_SET = set };
            }

            pub inline fn one_index(idx_and_set: SetIdx) RemoveLocation {
                return RemoveLocation{ .ONE_INDEX = idx_and_set };
            }

            pub inline fn one_ptr(ptr_and_set: SetPtr) RemoveLocation {
                return RemoveLocation{ .ONE_PTR = ptr_and_set };
            }

            pub inline fn one_item(item_and_set: SetItem) RemoveLocation {
                return RemoveLocation{ .ONE_ITEM = item_and_set };
            }

            pub inline fn many_new(count: Idx) RemoveLocation {
                return RemoveLocation{ .MANY_NEW = count };
            }

            pub inline fn first_n_from_set(set_count: SetCount) RemoveLocation {
                return RemoveLocation{ .FIRST_N_FROM_SET = set_count };
            }

            pub inline fn last_n_from_set(set_count: SetCount) RemoveLocation {
                return RemoveLocation{ .LAST_N_FROM_SET = set_count };
            }

            pub inline fn first_n_from_set_else_new(set_count: SetCount) RemoveLocation {
                return RemoveLocation{ .FIRST_N_FROM_SET_ELSE_NEW = set_count };
            }

            pub inline fn last_n_from_set_else_new(set_count: SetCount) RemoveLocation {
                return RemoveLocation{ .LAST_N_FROM_SET_ELSE_NEW = set_count };
            }

            pub inline fn sparse_list_of_indexes_from_same_set(set_idx_list: SetIdxList) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_INDEXES_FROM_SAME_SET = set_idx_list };
            }

            pub inline fn sparse_list_of_pointers_from_same_set(set_ptr_list: SetPtrList) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_POINTERS_FROM_SAME_SET = set_ptr_list };
            }

            pub inline fn sparse_list_of_items_from_same_set(set_item_list: SetItemList) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_ITEMS_FROM_SAME_SET = set_item_list };
            }

            pub inline fn sparse_list_of_indexes_from_any_set(set_idx_list: []const SetIdx) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_INDEXES_FROM_ANY_SET = set_idx_list };
            }

            pub inline fn sparse_list_of_pointers_from_any_set(set_ptr_list: []const SetPtr) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_POINTERS_FROM_ANY_SET = set_ptr_list };
            }

            pub inline fn sparse_list_of_items_from_any_set(set_item_list: []const SetItem) RemoveLocation {
                return RemoveLocation{ .SPARSE_LIST_OF_ITEMS_FROM_ANY_SET = set_item_list };
            }
        };

        pub const InsertMode = enum {
            AT_BEGINNING_OF_SET,
            AT_END_OF_SET,
            AFTER_INDEX,
            AFTER_PTR,
            AFTER_ITEM,
            BEFORE_INDEX,
            BEFORE_PTR,
            BEFORE_ITEM,
            LEAK_TO_NOWHERE,
        };
        // CHECKPOINT make this a comptime fn that returns a type based on InsertMode
        pub const InsertLocation = union(InsertMode) {
            AT_BEGINNING_OF_SET: LinkSet,
            AT_END_OF_SET: LinkSet,
            AFTER_INDEX: SetIdx,
            AFTER_PTR: SetPtr,
            AFTER_ITEM: SetItem,
            BEFORE_INDEX: SetIdx,
            BEFORE_PTR: SetPtr,
            BEFORE_ITEM: SetItem,
            LEAK_TO_NOWHERE: void,

            pub inline fn at_beginning_head_of_set(set: LinkSet) InsertLocation {
                return InsertLocation{ .AT_BEGINNING_OF_SET = set };
            }

            pub inline fn at_end_tail_of_set(set: LinkSet) InsertLocation {
                return InsertLocation{ .AT_END_OF_SET = set };
            }

            pub inline fn after_index(idx_and_set: SetIdx) InsertLocation {
                return InsertLocation{ .AFTER_INDEX = idx_and_set };
            }

            pub inline fn after_ptr(ptr_and_set: SetPtr) InsertLocation {
                return InsertLocation{ .AFTER_PTR = ptr_and_set };
            }

            pub inline fn after_item(item_and_set: SetItem) InsertLocation {
                return InsertLocation{ .AFTER_ITEM = item_and_set };
            }

            pub inline fn before_index(idx_and_set: SetIdx) InsertLocation {
                return InsertLocation{ .BEFORE_INDEX = idx_and_set };
            }

            pub inline fn before_ptr(ptr_and_set: SetPtr) InsertLocation {
                return InsertLocation{ .BEFORE_PTR = ptr_and_set };
            }

            pub inline fn before_item(item_and_set: SetItem) InsertLocation {
                return InsertLocation{ .BEFORE_ITEM = item_and_set };
            }

            pub inline fn leak_to_nowhere() InsertLocation {
                return InsertLocation{ .LEAK_TO_NOWHERE = void{} };
            }
        };

        /// All functions/structs in this namespace fall in at least one of 3 categories:
        /// - DANGEROUS to use if you do not manually manage and maintain a valid linked list state
        /// - Are only useful for asserting/creating intenal state
        /// - Cover VERY niche use cases (used internally) and are placed here to keep the top-level namespace less polluted
        ///
        /// They are provided here publicly to facilitate special user use cases
        pub const Internal = struct {
            pub inline fn set_next_idx(ptr: *Elem, idx: Idx) void {
                if (FORWARD) @field(ptr, NEXT_FIELD) = idx;
            }

            pub inline fn set_prev_idx(ptr: *Elem, idx: Idx) void {
                if (BACKWARD) @field(ptr, PREV_FIELD) = idx;
            }

            pub inline fn set_idx(ptr: *Elem, idx: Idx) void {
                if (CACHE) @field(ptr, CACHE_FIELD) = idx;
            }

            pub inline fn set_first_index(self: *List, set: LinkSet, idx: Idx) void {
                if (HEAD) self.sets[@intFromEnum(set)].first_idx = idx;
            }

            pub inline fn set_last_index(self: *List, set: LinkSet, idx: Idx) void {
                if (TAIL) self.sets[@intFromEnum(set)].last_idx = idx;
            }

            pub inline fn set_link_set_count(self: *List, set: LinkSet, count: Idx) void {
                self.sets[@intFromEnum(set)].count = count;
            }

            pub inline fn increase_link_set_count(self: *List, set: LinkSet, amount: Idx) void {
                self.sets[@intFromEnum(set)].count += amount;
            }

            pub inline fn decrease_link_set_count(self: *List, set: LinkSet, amount: Idx) void {
                self.sets[@intFromEnum(set)].count -= amount;
            }

            pub inline fn set_link_set(ptr: *Elem, set: LinkSet) void {
                if (STATE) {
                    @field(ptr, STATE_FIELD) &= STATE_CLEAR_MASK;
                    @field(ptr, STATE_FIELD) |= STATE_FLAGS[@intFromEnum(set)];
                }
            }

            pub fn set_link_set_on_items(items: []const Item, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < items.len) : (i += 1) {
                    set_link_set(items[i].ptr, set);
                }
            }

            pub fn set_link_set_on_set_items(items: []const SetItem, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < items.len) : (i += 1) {
                    set_link_set(items[i].item.ptr, set);
                }
            }

            pub fn set_state_on_items_first_last(self: *List, first_item: Item, last_item: Item, comptime forward: bool, set: LinkSet) void {
                if (!STATE) return;
                var idx = if (forward) first_item.idx else last_item.idx;
                var ptr = if (forward) first_item.ptr else last_item.ptr;
                const final_idx = if (forward) last_item.idx else first_item.idx;
                while (true) {
                    set_link_set(ptr, set);
                    if (idx == final_idx) break;
                    idx = if (forward) get_next_idx_from_ptr(self, set, ptr) else get_prev_idx_from_ptr(self, set, ptr);
                    ptr = get_ptr(self, idx);
                }
            }

            pub fn set_link_set_on_ptrs(ptrs: []const *Elem, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < ptrs.len) : (i += 1) {
                    set_link_set(ptrs[i], set);
                }
            }

            pub fn set_link_set_on_set_ptrs(ptrs: []const SetPtr, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < ptrs.len) : (i += 1) {
                    set_link_set(ptrs[i].ptr, set);
                }
            }

            pub fn set_link_set_on_ptrs_first_last(self: *List, first_ptr: *Elem, last_ptr: *Elem, comptime forward: bool, set: LinkSet) void {
                if (!STATE) return;
                var idx = if (forward) get_idx(self, first_ptr) else get_idx(self, last_ptr);
                var ptr = if (forward) first_ptr else last_ptr;
                const final_idx = if (forward) get_idx(self, last_ptr) else get_idx(self, first_ptr);
                while (true) {
                    set_link_set(ptr, set);
                    if (idx == final_idx) break;
                    idx = if (forward) get_next_idx_from_ptr(self, set, ptr) else get_prev_idx_from_ptr(self, set, ptr);
                    ptr = get_ptr(self, idx);
                }
            }

            pub fn set_link_set_on_indexes(self: *const List, indexes: []const Idx, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < indexes.len) : (i += 1) {
                    set_link_set(get_ptr(self, indexes[i]), set);
                }
            }

            pub fn set_link_set_on_set_indexes(self: *const List, indexes: []const SetIdx, set: LinkSet) void {
                if (!STATE) return;
                var i: usize = 0;
                while (i < indexes.len) : (i += 1) {
                    set_link_set(get_ptr(self, indexes[i].idx), set);
                }
            }

            pub fn set_link_set_on_indexes_first_last(self: *List, first_idx: Idx, last_idx: Idx, comptime forward: bool, set: LinkSet) void {
                if (!STATE) return;
                var idx = if (forward) first_idx else last_idx;
                var ptr = if (forward) get_ptr(self, first_idx) else get_ptr(self, last_idx);
                const final_idx = if (forward) last_idx else first_idx;
                while (true) {
                    set_link_set(ptr, set);
                    if (idx == final_idx) break;
                    idx = if (forward) get_next_idx_from_ptr(self, set, ptr) else get_prev_idx_from_ptr(self, set, ptr);
                    ptr = get_ptr(self, idx);
                }
            }

            pub fn link_sparse_item_slice(self: *List, set: LinkSet, items: []const Item) void {
                var i = 1;
                while (i < items.len) : (i += 1) {
                    const left = get_conn_left_from_item(self, set, items[i]);
                    const right = get_conn_right_from_item(self, set, items[i - 1]);
                    connect(left, right);
                }
            }

            pub fn link_sparse_set_item_slice(self: *List, set: LinkSet, items: []const SetItem) void {
                var i = 1;
                while (i < items.len) : (i += 1) {
                    const left = get_conn_left_from_item(self, set, items[i].item);
                    const right = get_conn_right_from_item(self, set, items[i - 1].item);
                    connect(left, right);
                }
            }

            pub fn link_and_set_state_on_new_indexes(self: *List, set: LinkSet, first_idx: Idx, count: Idx) void {
                var left_idx = first_idx;
                var right_idx = first_idx + 1;
                const last_right_idx = left_idx + count - 1;
                set_link_set(&self.list.ptr[left_idx], set);
                while (right_idx < last_right_idx) {
                    const right_item = Item{ .idx = right_idx, .ptr = &self.list.ptr[right_idx] };
                    const left_item = Item{ .idx = left_idx, .ptr = &self.list.ptr[left_idx] };
                    set_link_set(right_item.ptr, set);
                    const left = get_conn_left_from_item(self, set, left_item);
                    const right = get_conn_right_from_item(self, set, right_item);
                    connect(left, right);
                    left_idx += 1;
                    right_idx += 1;
                }
            }

            pub fn link_sparse_index_slice(self: *List, set: LinkSet, indexes: []const Idx) void {
                var i = 1;
                while (i < indexes.len) : (i += 1) {
                    const left = get_conn_left_from_idx(self, set, indexes[i]);
                    const right = get_conn_right_from_idx(set, indexes[i - 1]);
                    connect(left, right);
                }
            }

            pub fn link_sparse_set_index_slice(self: *List, set: LinkSet, indexes: []const SetIdx) void {
                var i = 1;
                while (i < indexes.len) : (i += 1) {
                    const left = get_conn_left_from_idx(self, set, indexes[i].idx);
                    const right = get_conn_right_from_idx(self, set, indexes[i - 1].idx);
                    connect(left, right);
                }
            }

            pub fn link_sparse_ptr_slice(self: *List, ptrs: []const *Elem) void {
                var i = 1;
                while (i < ptrs.len) : (i += 1) {
                    const left = get_conn_left_from_ptr(self, ptrs[i]);
                    const right = get_conn_right_from_ptr(self, ptrs[i - 1]);
                    connect(left, right);
                }
            }

            pub fn link_sparse_set_ptr_slice(self: *List, ptrs: []const SetPtr) void {
                var i = 1;
                while (i < ptrs.len) : (i += 1) {
                    const left = get_conn_left_from_ptr(self, ptrs[i].ptr);
                    const right = get_conn_right_from_ptr(self, ptrs[i - 1].ptr);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_ptr_slice(self: *List, set: LinkSet, ptrs: []const *Elem) void {
                var i = 0;
                while (i < ptrs.len) : (i += 1) {
                    const ptr = ptrs[i];
                    const left_idx = get_prev_idx_from_ptr(self, set, ptr);
                    const right_idx = get_next_idx_from_ptr(self, set, ptr);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_set_ptr_slice(self: *List, ptrs: []const SetPtr) void {
                var i = 0;
                while (i < ptrs.len) : (i += 1) {
                    const ptr = ptrs[i].ptr;
                    const set = ptrs[i].set;
                    const left_idx = get_prev_idx_from_ptr(self, set, ptr);
                    const right_idx = get_next_idx_from_ptr(self, set, ptr);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_index_slice(self: *List, set: LinkSet, indexes: []const Idx) void {
                var i = 0;
                while (i < indexes.len) : (i += 1) {
                    const idx = indexes[i];
                    const left_idx = get_prev_idx_from_idx(self, set, idx);
                    const right_idx = get_next_idx_from_idx(self, set, idx);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_set_index_slice(self: *List, indexes: []const SetIdx) void {
                var i = 0;
                while (i < indexes.len) : (i += 1) {
                    const idx = indexes[i].idx;
                    const set = indexes[i].set;
                    const left_idx = get_prev_idx_from_idx(self, set, idx);
                    const right_idx = get_next_idx_from_idx(self, set, idx);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_item_slice(self: *List, set: LinkSet, items: []const Item) void {
                var i = 0;
                while (i < items.len) : (i += 1) {
                    const ptr = items[i].ptr;
                    const left_idx = get_prev_idx_from_ptr(self, set, ptr);
                    const right_idx = get_next_idx_from_ptr(self, set, ptr);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub fn disconnect_sparse_set_item_slice(self: *List, items: []const SetItem) void {
                var i = 0;
                while (i < items.len) : (i += 1) {
                    const ptr = items[i].item.ptr;
                    const set = items[i].set;
                    const left_idx = get_prev_idx_from_ptr(self, set, ptr);
                    const right_idx = get_next_idx_from_ptr(self, set, ptr);
                    const left = get_conn_left_from_idx(self, set, left_idx);
                    const right = get_conn_right_from_idx(self, set, right_idx);
                    connect(left, right);
                }
            }

            pub inline fn connect_with_insert(left_edge: ConnLeft, first_insert: ConnRight, last_insert: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(left_edge.idx_ptr, first_insert.idx);
                        set_next_idx(last_insert.idx_ptr, right_edge.idx);
                    } else {
                        set_next_idx(left_edge, first_insert);
                        set_next_idx(last_insert, right_edge);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(right_edge.idx_ptr, last_insert.idx);
                        set_prev_idx(first_insert.idx_ptr, left_edge.idx);
                    } else {
                        set_prev_idx(right_edge, last_insert);
                        set_prev_idx(first_insert, left_edge);
                    }
                }
            }

            pub inline fn connect(left_edge: ConnLeft, right_edge: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(left_edge.idx_ptr, right_edge.idx);
                    } else {
                        set_next_idx(left_edge, right_edge);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(right_edge.idx_ptr, left_edge.idx);
                    } else {
                        set_prev_idx(right_edge, left_edge);
                    }
                }
            }

            pub inline fn get_conn_left_from_idx(self: *const List, set: LinkSet, idx: Idx) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .idx_ptr = if (idx == NULL_IDX) get_head_index_ref(self, set) else &@field(get_ptr(self, idx), NEXT_FIELD),
                };
                if (FORWARD) if (idx == NULL_IDX) get_head_index_ref(self, set) else &@field(get_ptr(self, idx), NEXT_FIELD);
                if (BACKWARD) return idx;
            }

            pub inline fn get_conn_left_from_ptr(self: *const List, ptr: *Elem) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = get_idx(self, ptr),
                    .idx_ptr = &@field(ptr, NEXT_FIELD),
                };
                if (FORWARD) return &@field(ptr, NEXT_FIELD);
                if (BACKWARD) return get_idx(self, ptr);
            }

            pub inline fn get_conn_left_from_item(self: *const List, set: LinkSet, item: Item) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = item.idx,
                    .idx_ptr = if (item.idx == NULL_IDX) get_head_index_ref(self, set) else &@field(item.ptr, NEXT_FIELD),
                };
                if (FORWARD) return &@field(item.ptr, NEXT_FIELD);
                if (BACKWARD) return item.idx;
            }

            pub inline fn get_conn_left_from_set_head(self: *List, set: LinkSet) ConnLeft {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_head_index_ref(self, set),
                };
                if (FORWARD) return get_head_index_ref(self, set);
                if (BACKWARD) return NULL_IDX;
            }

            pub inline fn get_conn_right_from_idx(self: *const List, set: LinkSet, idx: Idx) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = idx,
                    .ptr = if (idx == NULL_IDX) get_tail_index_ref(self, set) else &@field(get_ptr(self, idx), PREV_FIELD),
                };
                if (FORWARD) return idx;
                if (BACKWARD) return if (idx == NULL_IDX) get_tail_index_ref(self, set) else &@field(get_ptr(self, idx), PREV_FIELD);
            }

            pub inline fn get_conn_right_from_ptr(self: *const List, ptr: *Elem) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = get_idx(self, ptr),
                    .ptr = &@field(ptr, PREV_FIELD),
                };
                if (FORWARD) return &@field(ptr, PREV_FIELD);
                if (BACKWARD) return ptr;
            }

            pub inline fn get_conn_right_from_item(self: *const List, set: LinkSet, item: Item) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = item.idx,
                    .idx_ptr = if (item.idx == NULL_IDX) get_tail_index_ref(self, set) else &@field(item.ptr, PREV_FIELD),
                };
                if (FORWARD) return item.idx;
                if (BACKWARD) return if (item.idx == NULL_IDX) get_tail_index_ref(self, set) else &@field(item.ptr, PREV_FIELD);
            }

            pub inline fn get_conn_right_from_index_after_ptr(self: *const List, set: LinkSet, ptr: *const Elem) ConnRight {
                const next_idx = get_next_idx_from_ptr(self, set, ptr);
                return get_conn_right_from_idx(self, set, next_idx);
            }

            pub inline fn get_conn_left_from_index_before_ptr(self: *const List, set: LinkSet, ptr: *const Elem) ConnLeft {
                const prev_idx = get_prev_idx_from_ptr(self, set, ptr);
                return get_conn_left_from_idx(self, set, prev_idx);
            }

            pub inline fn get_conn_right_from_set_tail(self: *List, set: LinkSet) ConnRight {
                if (BIDIRECTION) return IdxPtrIdx{
                    .idx = NULL_IDX,
                    .idx_ptr = get_tail_index_ref(self, set),
                };
                if (FORWARD) return NULL_IDX;
                if (BACKWARD) return get_tail_index_ref(self, set);
            }

            pub inline fn get_conn_insert_from_item(self: *const List, set: LinkSet, item: Item) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_item(self, set, item),
                    .last = get_conn_left_from_item(self, set, item),
                };
            }

            pub inline fn get_conn_insert_from_item_first_last(self: *const List, set: LinkSet, items: FirstLastItem) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_item(self, set, items.first),
                    .last = get_conn_left_from_item(self, set, items.last),
                };
            }

            pub inline fn get_conn_insert_from_item_chain_slice(self: *const List, set: LinkSet, item_chain: []const Item) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_item(self, set, item_chain[0]),
                    .last = get_conn_left_from_item(self, set, item_chain[item_chain.len - 1]),
                };
            }

            pub inline fn get_conn_insert_from_item_chain_first_last(self: *const List, set: LinkSet, first_item: Item, last_item: Item) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_item(self, set, first_item),
                    .last = get_conn_left_from_item(self, set, last_item),
                };
            }

            pub inline fn get_conn_insert_from_index_chain_slice(self: *const List, set: LinkSet, index_chain: []const Idx) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_idx(self, set, index_chain[0]),
                    .last = get_conn_left_from_idx(self, set, index_chain[index_chain.len - 1]),
                };
            }

            pub inline fn get_conn_insert_from_index_chain_first_last(self: *const List, set: LinkSet, first_idx: Idx, last_idx: Idx) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_idx(self, set, first_idx),
                    .last = get_conn_left_from_idx(self, set, last_idx),
                };
            }

            pub inline fn get_conn_insert_from_ptr_chain_slice(self: *const List, ptr_chain: []const *Elem) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_ptr(self, ptr_chain[0]),
                    .last = get_conn_left_from_ptr(self, ptr_chain[ptr_chain.len - 1]),
                };
            }

            pub inline fn get_conn_insert_from_ptr_chain_first_last(self: *const List, first_ptr: *Elem, last_ptr: *Elem) ConnInsert {
                return ConnInsert{
                    .first = get_conn_right_from_ptr(self, first_ptr),
                    .last = get_conn_left_from_ptr(self, last_ptr),
                };
            }

            pub inline fn get_next_idx_from_ptr(self: *const List, set: LinkSet, ptr: *const Elem) Idx {
                if (FORWARD) return @field(ptr, NEXT_FIELD);
                const idx = get_idx(self, ptr);
                return traverse_to_find_index_preceding_this_one_in_direction(self, idx, set, .BACKWARD);
            }

            pub inline fn get_prev_idx_from_ptr(self: *const List, set: LinkSet, ptr: *const Elem) Idx {
                if (BACKWARD) return @field(ptr, PREV_FIELD);
                const idx = get_idx(self, ptr);
                return traverse_to_find_index_preceding_this_one_in_direction(self, idx, set, .FORWARD);
            }

            pub inline fn get_next_idx_from_idx(self: *const List, set: LinkSet, idx: Idx) Idx {
                if (FORWARD) {
                    const ptr = get_ptr(self, idx);
                    return @field(ptr, NEXT_FIELD);
                }
                return traverse_to_find_index_preceding_this_one_in_direction(self, idx, set, .BACKWARD);
            }

            pub inline fn get_prev_idx_from_idx(self: *const List, set: LinkSet, idx: Idx) Idx {
                if (BACKWARD) {
                    const ptr = get_ptr(self, idx);
                    return @field(ptr, PREV_FIELD);
                }
                return traverse_to_find_index_preceding_this_one_in_direction(self, idx, set, .FORWARD);
            }

            pub inline fn get_head_index_ref(self: *List, set: LinkSet) *Idx {
                return &self.sets[@intFromEnum(set)].first_idx;
            }

            pub inline fn get_tail_index_ref(self: *List, set: LinkSet) *Idx {
                return &self.sets[@intFromEnum(set)].last_idx;
            }

            pub inline fn get_ptr(self: *const List, idx: Idx) *Elem {
                assert_valid_items_indexes_or_pointers(self, idx, @src());
                return &self.list.ptr[idx];
            }

            pub inline fn get_idx(self: *const List, ptr: *const Elem) Idx {
                assert_valid_items_indexes_or_pointers(self, ptr, @src());
                if (CACHE) return @field(self, CACHE_FIELD);
                const base_addr = @intFromPtr(self.list.ptr);
                const ptr_addr = @intFromPtr(ptr);
                const delta = ptr_addr - base_addr;
                return @intCast(delta / @sizeOf(Elem));
            }

            pub inline fn get_element_ref_from_prev_idx_field_ref(prev_idx_field_ref: *Idx) *Elem {
                assert_with_reason(BACKWARD, @src(), "elements do not cache the previous index, cannnot use a pointer to previous index field to find pointer to `*Elem`", .{});
                return @as(*Elem, @fieldParentPtr(PREV_FIELD, prev_idx_field_ref));
            }

            pub inline fn get_element_index_from_prev_idx_field_ref(self: *const List, prev_idx_field_ref: *Idx) Idx {
                return get_idx(self, get_element_ref_from_prev_idx_field_ref(prev_idx_field_ref));
            }

            pub inline fn get_element_ref_from_next_idx_field_ref(next_idx_field_ref: *Idx) *Elem {
                assert_with_reason(FORWARD, @src(), "elements do not cache the next index, cannnot use a pointer to next index field to find pointer to `*Elem`", .{});
                return @as(*Elem, @fieldParentPtr(NEXT_FIELD, next_idx_field_ref));
            }

            pub inline fn get_element_index_from_next_idx_field_ref(self: *const List, next_idx_field_ref: *Idx) Idx {
                return get_idx(self, get_element_ref_from_next_idx_field_ref(next_idx_field_ref));
            }

            pub inline fn assert_valid_items_indexes_or_pointers(self: *const List, input: anytype, src_loc: ?SourceLocation) void {
                const T = @TypeOf(input);
                switch (T) {
                    Item => assert_idx_and_pointer_reside_in_slice_and_match(Elem, self.list.slice(), input.idx, input.ptr, src_loc),
                    []const Item => for (input) |item| {
                        assert_idx_and_pointer_reside_in_slice_and_match(Elem, self.list.slice(), item.idx, item.ptr, src_loc);
                    },
                    SetItem => assert_idx_and_pointer_reside_in_slice_and_match(Elem, self.list.slice(), input.item.idx, input.item.ptr, src_loc),
                    []const SetItem => for (input) |set_item| {
                        assert_idx_and_pointer_reside_in_slice_and_match(Elem, self.list.slice(), set_item.item.idx, set_item.item.ptr, src_loc);
                    },
                    SetItemList => for (input.items) |item| {
                        assert_idx_and_pointer_reside_in_slice_and_match(Elem, self.list.slice(), item.idx, item.ptr, src_loc);
                    },
                    Idx => assert_idx_less_than_len(input, self.list.len, src_loc),
                    []const Idx => for (input) |idx| {
                        assert_idx_less_than_len(idx, self.list.len, src_loc);
                    },
                    SetIdx => assert_idx_less_than_len(input.idx, self.list.len, src_loc),
                    []const SetIdx => for (input) |setidx| {
                        assert_idx_less_than_len(setidx.idx, self.list.len, src_loc);
                    },
                    SetIdxList => for (input.idxs) |idx| {
                        assert_idx_less_than_len(idx, self.list.len, src_loc);
                    },
                    *Elem, *const Elem => assert_pointer_resides_in_slice(Elem, self.list.slice(), input, src_loc),
                    []const *Elem, []const *const Elem, []*Elem, []*const Elem => for (input) |ptr| {
                        assert_pointer_resides_in_slice(Elem, self.list.slice(), ptr, src_loc);
                    },
                    []Elem, []const Elem => assert_slice_resides_in_slice(Elem, self.list.slice(), input, src_loc),
                    SetPtr => assert_pointer_resides_in_slice(Elem, self.list.slice(), input.ptr, src_loc),
                    []const SetPtr => for (input) |set_ptr| {
                        assert_pointer_resides_in_slice(Elem, self.list.slice(), set_ptr.ptr, src_loc);
                    },
                    SetPtrList => for (input.ptrs) |ptr| {
                        assert_pointer_resides_in_slice(Elem, self.list.slice(), ptr, src_loc);
                    },
                    else => assert_with_reason(false, src_loc, "invalid type {s} is not an Item, *Elem, Idx, []Elem, or helper struct containing one or slice of many", .{@typeName(T)}),
                }
            }

            pub fn traverse_to_get_first_item_in_set(self: *const List, set: LinkSet) Item {
                var ii = Item{};
                var i = self.get_item_from_idx(self.get_first_index_in_set(set));
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_item_count(set) else void{};
                while (i.idx != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = self.get_item_from_idx(get_prev_idx_from_ptr(self, set, i.ptr));
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `BACKWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
                return ii;
            }

            pub fn traverse_to_get_last_item_in_set(self: *const List, set: LinkSet) Item {
                var ii = Item{};
                var i = self.get_item_from_idx(self.get_first_index_in_set(set));
                var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
                const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_item_count(set) else void{};
                while (i.idx != NULL_IDX) {
                    ii = i;
                    if (DEBUG) c += 1;
                    i = self.get_item_from_idx(get_next_idx_from_ptr(self, set, i.ptr));
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `FORWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
                return ii;
            }

            pub fn traverse_and_report_if_found_idx_in_set(self: *const List, set: LinkSet, idx: Idx) bool {
                var i: Idx = if (FORWARD) self.get_first_index_in_set(set) else self.get_first_index_in_set(set);
                var c: Idx = 0;
                const limit: Idx = self.get_item_count(set);
                while (i != NULL_IDX and (if (DEBUG) c < limit else true)) {
                    if (i == idx) return true;
                    i = if (FORWARD) Internal.get_next_idx_from_idx(set, i) else Internal.get_prev_idx_from_idx(self, set, i);
                    if (DEBUG) c += 1;
                }
                if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
                return false;
            }

            pub fn traverse_to_find_index_preceding_this_one_in_direction(self: List, idx: Idx, set: LinkSet, dir: Direction) Idx {
                var curr_idx: Idx = undefined;
                var count: Idx = 0;
                const limit = self.get_item_count(set);
                switch (dir) {
                    .BACKWARD => {
                        assert_with_reason(BACKWARD, @src(), "linked list does not link elements in the backward direction", .{});
                        curr_idx = self.get_last_index_in_set(set);
                    },
                    .FORWARD => {
                        assert_with_reason(FORWARD, @src(), "linked list does not link elements in the forward direction", .{});
                        curr_idx = self.get_first_index_in_set(set);
                    },
                }
                while (curr_idx != NULL_IDX) {
                    if (DEBUG) assert_with_reason(count < limit, @src(), "already traversed {d} (total set count) items in set `{s}`, but there are more non-null indexes after the last", .{ limit, @tagName(set) });
                    assert_with_reason(curr_idx < self.list.len, @src(), "while traversing set `{s}` in direction `{s}`, index {d} was found, which is out of bounds for list.len {d}", .{ @tagName(set), @tagName(dir), curr_idx, self.list.len });
                    const following_idx = switch (dir) {
                        .FORWARD => Internal.get_next_idx_from_idx(self, set, curr_idx),
                        .BACKWARD => Internal.get_prev_idx_from_idx(self, set, curr_idx),
                    };
                    if (following_idx == idx) return curr_idx;
                    curr_idx = following_idx;
                    if (DEBUG) count += 1;
                }
                if (DEBUG) assert_with_reason(count == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})\nALSO: no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ @tagName(set), count, limit, idx, @tagName(set), @tagName(dir) });
                assert_with_reason(false, @src(), "no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ idx, @tagName(set), @tagName(dir) });
            }

            pub inline fn get_state(ptr: *const Elem) T_STATE {
                assert_with_reason(STATE, @src(), "cannot return item state when items do not cache their own state", .{});
                return @field(ptr, STATE_FIELD) & STATE_MASK;
            }
        };

        pub inline fn new_iterator(self: *List) Iterator {
            return Iterator{
                .list_ref = self,
                .next_idx = 0,
            };
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

        pub inline fn get_item_count(self: *List, set: LinkSet) Idx {
            return self.sets[@intFromEnum(set)].count;
        }

        pub inline fn get_item_from_ptr(self: *const List, ptr: *Elem) Item {
            return Item{
                .idx = Internal.get_idx(self, ptr),
                .ptr = ptr,
            };
        }

        pub inline fn get_item_from_idx(self: *const List, idx: Idx) Item {
            return Item{
                .idx = idx,
                .ptr = Internal.get_ptr(self, idx),
            };
        }

        pub fn get_item_with_index_n_in_set_from_start(self: *const List, set: LinkSet, n: Idx) Item {
            assert_with_reason(FORWARD, @src(), "cannot find index {n} in set {s} in the forward direction because items are not linked in the forward direction", .{ n, @tagName(set) });
            const set_count = self.get_item_count(set);
            assert_with_reason(n < set_count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ @tagName(set), n, set_count });
            var c = 0;
            var idx = self.get_first_index_in_set(set);
            while (c != n) : (c += 1) {
                idx = Internal.get_next_idx_from_idx(self, set, idx);
            }
            return idx;
        }

        pub fn get_item_with_index_n_in_set_from_end(self: *const List, set: LinkSet, n: Idx) Item {
            assert_with_reason(BACKWARD, @src(), "cannot find index {n} in set {s} in the backward direction because items are not linked in the backward direction", .{ n, @tagName(set) });
            const set_count = self.get_item_count(set);
            assert_with_reason(n < set_count, @src(), "index {d} is out of bounds for set {s} (len = {d})", .{ @tagName(set), n, set_count });
            var c = 0;
            var idx = self.get_last_index_in_set(set);
            while (c != n) : (c += 1) {
                idx = Internal.get_prev_idx_from_idx(self, set, idx);
            }
            return idx;
        }

        pub inline fn idx_is_in_set(self: *const List, idx: Idx, set: LinkSet) bool {
            if (STATE) {
                const ptr = Internal.get_ptr(self, idx);
                return @field(ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            }
            return Internal.traverse_and_report_if_found_idx_in_set(self, set, idx);
        }

        pub inline fn ptr_is_in_set(self: *const List, ptr: *const Elem, set: LinkSet) bool {
            if (STATE) return @field(ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            const idx = Internal.get_idx(self, ptr);
            return Internal.traverse_and_report_if_found_idx_in_set(self, set, idx);
        }

        pub inline fn item_is_in_set(self: *const List, item: Item, set: LinkSet) bool {
            if (STATE) return @field(item.ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            return Internal.traverse_and_report_if_found_idx_in_set(self, set, item.idx);
        }

        pub inline fn get_first_index_in_set(self: *const List, set: LinkSet) Idx {
            if (HEAD) return self.sets[@intFromEnum(set)].first_idx;
            return Internal.traverse_to_get_first_item_in_set(self, set).idx;
        }

        pub inline fn get_first_item_in_set(self: *const List, set: LinkSet) Item {
            if (HEAD) return self.get_item_from_idx(self.sets[@intFromEnum(set)].first_idx);
            return Internal.traverse_to_get_first_item_in_set(self, set);
        }

        pub inline fn get_last_index_in_set(self: *const List, set: LinkSet) Idx {
            if (TAIL) return self.sets[@intFromEnum(set)].last_idx;
            return Internal.traverse_to_get_last_item_in_set(self, set).idx;
        }

        pub inline fn get_last_item_in_set(self: *const List, set: LinkSet) Item {
            if (TAIL) return self.get_item_from_idx(self.sets[@intFromEnum(set)].last_idx);
            return Internal.traverse_to_get_last_item_in_set(self, set);
        }

        fn get_item_slot_and_insert_at_internal(self: *List, get_from: RemoveLocation, insert_at: InsertLocation, alloc: Allocator, comptime ASSUME_CAP: bool) if (!ASSUME_CAP and RETURN_ERRORS) Error!FirstLastItem else FirstLastItem {
            var insert_edges: ConnLeftRight = undefined;
            var needs_reconnect = true;
            var insert_set: LinkSet = undefined;
            switch (insert_at) {
                .AFTER_INDEX => |after| {
                    Internal.assert_valid_items_indexes_or_pointers(self, after.idx, @src());
                    insert_edges.left = Internal.get_conn_left_from_idx(self, after.set, after.idx);
                    const next_idx = Internal.get_next_idx_from_idx(self, after.set, after.idx);
                    insert_edges.right = Internal.get_conn_right_from_idx(self, after.set, next_idx);
                    insert_set = after.set;
                },
                .AFTER_ITEM => |after| {
                    Internal.assert_valid_items_indexes_or_pointers(self, after.item, @src());
                    self.assert_valid_item(after.item, @src());
                    insert_edges.left = self.get_conn_left_from_item(after.set, after.item);
                    const next_idx = Internal.get_next_idx_from_idx(self, after.set, after.item.idx);
                    insert_edges.right = Internal.get_conn_right_from_idx(self, after.set, next_idx);
                    insert_set = after.set;
                },
                .AFTER_PTR => |after| {
                    Internal.assert_valid_items_indexes_or_pointers(self, after.ptr, @src());
                    insert_edges.left = Internal.get_conn_left_from_ptr(self, after.ptr);
                    const next_idx = Internal.get_next_idx_from_ptr(self, after.set, after.ptr);
                    insert_edges.right = Internal.get_conn_right_from_idx(self, after.set, next_idx);
                    insert_set = after.set;
                },
                .BEFORE_INDEX => |before| {
                    Internal.assert_valid_items_indexes_or_pointers(self, before.idx, @src());
                    insert_edges.right = Internal.get_conn_right_from_idx(self, before.set, before.idx);
                    const prev_idx = Internal.get_prev_idx_from_idx(self, before.set, before.idx);
                    insert_edges.left = Internal.get_conn_left_from_idx(self, before.set, prev_idx);
                    insert_set = before.set;
                },
                .BEFORE_ITEM => |before| {
                    Internal.assert_valid_items_indexes_or_pointers(self, before.item, @src());
                    insert_edges.right = Internal.get_conn_right_from_item(self, before.set, before.item);
                    const prev_idx = Internal.get_prev_idx_from_idx(self, before.set, before.item.idx);
                    insert_edges.left = Internal.get_conn_left_from_idx(self, before.set, prev_idx);
                    insert_set = before.set;
                },
                .BEFORE_PTR => |before| {
                    Internal.assert_valid_items_indexes_or_pointers(self, before.ptr, @src());
                    insert_edges.right = Internal.get_conn_right_from_ptr(self, before.ptr);
                    const prev_idx = Internal.get_prev_idx_from_ptr(self, before.set, before.ptr);
                    insert_edges.left = Internal.get_conn_left_from_idx(self, before.set, prev_idx);
                    insert_set = before.set;
                },
                .AT_BEGINNING_OF_SET => |set| {
                    insert_edges.left = Internal.get_conn_left_from_set_head(self, set);
                    const next_index = self.get_first_index_in_set(set);
                    insert_edges.right = Internal.get_conn_right_from_idx(self, set, next_index);
                    insert_set = set;
                },
                .AT_END_OF_SET => |set| {
                    insert_edges.right = Internal.get_conn_right_from_set_tail(self, set);
                    const prev_index = self.get_last_index_in_set(set);
                    insert_edges.left = Internal.get_conn_left_from_idx(self, set, prev_index);
                    insert_set = set;
                },
                .LEAK_TO_NOWHERE => {
                    needs_reconnect = false;
                },
            }
            var return_items: FirstLastItem = undefined;
            var needs_disconnect = true;
            var disconnect_set: LinkSet = undefined;
            var disconnect_count: Idx = 1;
            var disconnect_edges: ConnLeftRight = undefined;
            var mid_conn: ConnLeftRight = undefined;
            var needs_mid_conn = false;
            var insert_count: Idx = 1;
            rmv: switch (get_from) {
                .ONE_NEW => {
                    return_items = FirstLastItem.single(Item{
                        .idx = self.list.len,
                        .ptr = if (ASSUME_CAP) self.list.append_slot_assume_capacity() else (if (RETURN_ERRORS) try self.list.append_slot(alloc) else self.list.append_slot(alloc)),
                    });
                    needs_disconnect = false;
                },
                .FIRST_FROM_SET, .FIRST_FROM_SET_ELSE_NEW => |set| {
                    const set_count: debug_switch(Idx, void) = debug_switch(self.get_item_count(set), void{});
                    const set_first_idx = self.get_first_index_in_set(set);
                    if (get_from == .FIRST_FROM_SET_ELSE_NEW and (debug_switch(set_count == 0, false) or set_first_idx == NULL_IDX)) {
                        continue :rmv RemoveLocation.one_new();
                    }
                    assert_with_reason(debug_switch(set_count > 0, true) and set_first_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(set), debug_switch(set_count, 0), set_first_idx, self.list.len });
                    return_items = FirstLastItem.single(self.get_item_from_idx(set_first_idx));
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_set = set;
                },
                .LAST_FROM_SET, .LAST_FROM_SET_ELSE_NEW => |set| {
                    const set_count: debug_switch(Idx, void) = debug_switch(self.get_item_count(set), void{});
                    const set_last_idx = self.get_last_index_in_set(set);
                    if (get_from == .LAST_FROM_SET_ELSE_NEW and (debug_switch(set_count == 0, false) or set_last_idx == NULL_IDX)) {
                        continue :rmv RemoveLocation.one_new();
                    }
                    assert_with_reason(debug_switch(set_count > 0, true) and set_last_idx < self.list.len, @src(), "tried to 'get' linked list item from head/beginning of set `{s}`, but that set reports an item count of {d} and the first idx is {d} (list.len = {d})", .{ @tagName(set), debug_switch(set_count, 0), set_last_idx, self.list.len });
                    return_items = FirstLastItem.single(self.get_item_from_idx(set_last_idx));
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_set = set;
                },
                .ONE_INDEX => |using| {
                    Internal.assert_valid_items_indexes_or_pointers(self, using.idx, @src());
                    return_items = FirstLastItem.single(self.get_item_from_idx(using.idx));
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_set = using.set;
                },
                .ONE_ITEM => |using| {
                    Internal.assert_valid_items_indexes_or_pointers(self, using.item, @src());
                    return_items = FirstLastItem.single(using.item);
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_set = using.set;
                },
                .ONE_PTR => |using| {
                    Internal.assert_valid_items_indexes_or_pointers(self, using.ptr, @src());
                    return_items = FirstLastItem.single(self.get_item_from_ptr(using.ptr));
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_set = using.set;
                },
                .MANY_NEW => |count| {
                    assert_with_reason(count > 0, @src(), "cannot insert `0` items", .{});
                    const first_slot_idx = self.list.len;
                    const last_slot_idx = self.list.len + count - 1;
                    _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count) else (if (RETURN_ERRORS) try self.list.append_many_slots(count, alloc) else self.list.append_many_slots(count, alloc));
                    Internal.link_and_set_state_on_new_indexes(self, insert_set, first_slot_idx, count);
                    return_items.first = self.get_item_from_idx(first_slot_idx);
                    return_items.last = self.get_item_from_idx(last_slot_idx);
                    needs_disconnect = false;
                    insert_count = count;
                },
                .FIRST_N_FROM_SET => |set_count| {
                    assert_with_reason(set_count.count > 0, @src(), "cannot insert `0` items", .{});
                    assert_with_reason(self.get_item_count(set_count.set) >= set_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ set_count.count, @tagName(set_count.set), self.get_item_count(disconnect_set) });
                    return_items.first = self.get_first_item_in_set(set_count.set);
                    return_items.last = self.get_item_with_index_n_in_set_from_start(set_count.set, set_count.count - 1);
                    Internal.set_state_on_items_first_last(self, return_items.first, return_items.last, true, set_count.set);
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_count = set_count.count;
                    disconnect_set = set_count.set;
                    insert_count = set_count.count;
                },
                .LAST_N_FROM_SET => |set_count| {
                    assert_with_reason(set_count.count > 0, @src(), "cannot insert `0` items", .{});
                    assert_with_reason(self.get_item_count(set_count.set) >= set_count.count, @src(), "requested {d} items from set {s}, but set only has {d} items", .{ set_count.count, @tagName(set_count.set), self.get_item_count(disconnect_set) });
                    return_items.last = self.get_last_item_in_set(set_count.set);
                    return_items.first = self.get_item_with_index_n_in_set_from_end(set_count.set, set_count.count - 1);
                    Internal.set_state_on_items_first_last(self, return_items.first, return_items.last, false, set_count.set);
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, return_items.last.ptr);
                    disconnect_count = set_count.count;
                    disconnect_set = set_count.set;
                    insert_count = set_count.count;
                },
                .FIRST_N_FROM_SET_ELSE_NEW => |set_count| {
                    assert_with_reason(set_count.count > 0, @src(), "cannot insert `0` items", .{});
                    const count_from_set = @max(self.get_item_count(set_count.set), set_count.count);
                    const count_from_new = set_count.count - count_from_set;
                    if (count_from_new == set_count.count) continue :rmv RemoveLocation.many_new(set_count.count);
                    if (count_from_set == set_count.count) continue :rmv RemoveLocation.first_n_from_set(set_count);
                    // new slots
                    const first_slot_idx = self.list.len;
                    const last_slot_idx = self.list.len + count_from_new - 1;
                    _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                    Internal.link_and_set_state_on_new_indexes(self, insert_set, first_slot_idx, count_from_new);
                    const first_new_item = self.get_item_from_idx(first_slot_idx);
                    return_items.last = self.get_item_from_idx(last_slot_idx);
                    // moved items
                    return_items.first = self.get_first_item_in_set(set_count.set);
                    const last_moved_item = self.get_item_with_index_n_in_set_from_start(set_count.set, count_from_set - 1);
                    Internal.set_state_on_items_first_last(self, return_items.first, last_moved_item, true, set_count.set);
                    mid_conn.left = Internal.get_conn_left_from_item(self, set_count.set, last_moved_item);
                    mid_conn.right = Internal.get_conn_right_from_item(self, set_count.set, first_new_item);
                    needs_mid_conn = true;
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, last_moved_item.ptr);
                    disconnect_count = count_from_set;
                    disconnect_set = set_count.set;
                    insert_count = set_count.count;
                },
                .LAST_N_FROM_SET_ELSE_NEW => |set_count| {
                    assert_with_reason(set_count.count > 0, @src(), "cannot insert `0` items", .{});
                    const count_from_set = @max(self.get_item_count(set_count.set), set_count.count);
                    const count_from_new = set_count.count - count_from_set;
                    if (count_from_new == set_count.count) continue :rmv RemoveLocation.many_new(set_count.count);
                    if (count_from_set == set_count.count) continue :rmv RemoveLocation.last_n_from_set(set_count);
                    // new slots
                    const first_slot_idx = self.list.len;
                    const last_slot_idx = self.list.len + count_from_new - 1;
                    _ = if (ASSUME_CAP) self.list.append_many_slots_assume_capacity(count_from_new) else (if (RETURN_ERRORS) try self.list.append_many_slots(count_from_new, alloc) else self.list.append_many_slots(count_from_new, alloc));
                    Internal.link_and_set_state_on_new_indexes(self, insert_set, first_slot_idx, count_from_new);
                    const first_new_item = self.get_item_from_idx(first_slot_idx);
                    return_items.last = self.get_item_from_idx(last_slot_idx);
                    // moved items
                    return_items.first = self.get_item_with_index_n_in_set_from_end(set_count.set, count_from_set - 1);
                    const last_moved_item = self.get_last_item_in_set(set_count.set);
                    Internal.set_state_on_items_first_last(self, return_items.first, last_moved_item, false, set_count.set);
                    mid_conn.left = Internal.get_conn_left_from_item(self, set_count.set, last_moved_item);
                    mid_conn.right = Internal.get_conn_right_from_item(self, set_count.set, first_new_item);
                    needs_mid_conn = true;
                    disconnect_edges.left = Internal.get_conn_left_from_index_before_ptr(self, disconnect_set, return_items.first.ptr);
                    disconnect_edges.right = Internal.get_conn_right_from_index_after_ptr(self, disconnect_set, last_moved_item.ptr);
                    disconnect_count = count_from_set;
                    disconnect_set = set_count.set;
                    insert_count = set_count.count;
                },
                //CHECKPOINT
                .SPARSE_LIST_OF_INDEXES_FROM_SAME_SET => |set_idx_list| {},
                .SPARSE_LIST_OF_POINTERS_FROM_SAME_SET => |set_ptr_list| {},
                .SPARSE_LIST_OF_ITEMS_FROM_SAME_SET => |set_item_list| {},
                .SPARSE_LIST_OF_INDEXES_FROM_ANY_SET => |set_idx_list| {},
                .SPARSE_LIST_OF_POINTERS_FROM_ANY_SET => |set_ptr_list| {},
                .SPARSE_LIST_OF_ITEMS_FROM_ANY_SET => |set_item_list| {},
            }
            if (needs_disconnect) {
                Internal.connect(disconnect_edges.left, disconnect_edges.right);
                Internal.decrease_link_set_count(self, disconnect_set, disconnect_count);
                if (TAIL_NO_BACKWARD and disconnect_edges.right == NULL_IDX) {
                    const last_rem_idx = if (self.get_item_count(disconnect_set) > 0) Internal.get_element_index_from_next_idx_field_ref(self, disconnect_edges.left) else NULL_IDX;
                    Internal.set_last_index(self, disconnect_set, last_rem_idx);
                }
                if (HEAD_NO_FORWARD and disconnect_edges.left == NULL_IDX) {
                    const first_rem_idx = if (self.get_item_count(disconnect_set) > 0) Internal.get_element_index_from_prev_idx_field_ref(self, disconnect_edges.right) else NULL_IDX;
                    Internal.set_first_index(self, disconnect_set, first_rem_idx);
                }
            }
            if (needs_mid_conn) {
                Internal.connect(mid_conn.left, mid_conn.right);
            }
            if (needs_reconnect) {
                const insert_new = Internal.get_conn_insert_from_item_first_last(self, insert_set, return_items);
                Internal.connect_with_insert(insert_edges.left, insert_new.first, insert_new.last, insert_edges.right);
                Internal.increase_link_set_count(self, insert_set, insert_count);
                if (TAIL_NO_BACKWARD and insert_edges.right == NULL_IDX) {
                    Internal.set_last_index(self, insert_set, return_items.last.idx);
                }
                if (HEAD_NO_FORWARD and insert_edges.left == NULL_IDX) {
                    Internal.set_first_index(self, insert_set, return_items.first.idx);
                }
                return return_items;
            }
        }

        pub fn get_item_slot_and_insert_at_assume_capacity(self: *List, get_slot_from: RemoveLocation, insert_slot_at: InsertLocation) Item {
            return self.get_item_slot_and_insert_at_internal(get_slot_from, insert_slot_at, DummyAllocator.allocator, true);
        }

        pub fn get_item_slot_and_insert_at(self: *List, get_slot_from: RemoveLocation, insert_slot_at: InsertLocation, alloc: Allocator) if (RETURN_ERRORS) Error!Item else Item {
            return self.get_item_slot_and_insert_at_internal(get_slot_from, insert_slot_at, alloc, false);
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

pub fn LinkedListIterator(comptime List: type) type {
    return struct {
        next_idx: List.Idx = 0,
        list_ref: *List,

        const Self = @This();

        pub inline fn reset_index_to_start(self: *Self) void {
            self.next_idx = 0;
        }

        pub inline fn set_index(self: *Self, index: List.Idx) void {
            self.next_idx = index;
        }

        pub inline fn decrease_index_safe(self: *Self, count: List.Idx) void {
            self.next_idx -|= count;
        }
        pub inline fn decrease_index(self: *Self, count: List.Idx) void {
            self.next_idx -= count;
        }
        pub inline fn increase_index(self: *Self, count: List.Idx) void {
            self.next_idx += count;
        }
        pub inline fn increase_index_safe(self: *Self, count: List.Idx) void {
            self.next_idx +|= count;
        }

        pub inline fn has_next(self: Self) bool {
            return self.next_idx < self.list_ref.len;
        }

        pub fn get_next_copy(self: *Self) ?List.Elem {
            if (self.next_idx >= self.list_ref.len) return null;
            const item = self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_copy_guaranteed(self: *Self) List.Elem {
            assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
            const item = self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_ref(self: *Self) ?*List.Elem {
            if (self.next_idx >= self.list_ref.len) return null;
            const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        pub fn get_next_ref_guaranteed(self: *Self) *List.Elem {
            assert_with_reason(self.next_idx < self.list_ref.len, @src(), "interator index ({d}) is out of bounds (list.len = {d})", .{ self.next_idx, self.list_ref.len });
            const item: *List.Elem = &self.list_ref.ptr[self.next_idx];
            self.next_idx += 1;
            return item;
        }

        /// Returns `true` if action was performed at least one time, `false` if iterator had zero items left
        pub fn perform_action_on_remaining_items(self: *Self, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
            var idx: List.Idx = self.next_idx;
            var exec_count: List.Idx = 0;
            var should_continue: bool = true;
            while (should_continue and idx < self.list_ref.len) : (idx += 1) {
                const item: *List.Elem = &self.list_ref.ptr[idx];
                should_continue = callback(self.list_ref, idx, item, userdata);
                exec_count += 1;
            }
            return exec_count > 0;
        }

        /// Returns `true` if action was performed on exactly `count` items, `false` if iterator ran out of items early
        pub fn perform_action_on_next_n_items(self: *Self, count: List.Idx, callback: *const IteratorAction, userdata: ?*anyopaque) bool {
            var idx: List.Idx = self.next_idx;
            const limit = @min(idx + count, self.list_ref.len);
            var exec_count: List.Idx = 0;
            var should_continue: bool = true;
            while (should_continue and idx < limit) : (idx += 1) {
                const item: *List.Elem = &self.list_ref.ptr[idx];
                should_continue = callback(self.list_ref, idx, item, userdata);
                exec_count += 1;
            }
            return exec_count == count;
        }

        /// Should return `true` if iteration should continue, or `false` if iteration should stop
        pub const IteratorAction = fn (list: *List, index: List.Idx, item: *List.Elem, userdata: ?*anyopaque) bool;
    };
}

test "LinkedList.zig" {
    // const t = std.testing;
    // const alloc = std.heap.page_allocator;
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
