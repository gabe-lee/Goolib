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
const assert_idx_less_than_len = Assert.assert_idx_less_than_len;
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
    /// Index 0 represents enum tag value 0, index 1 represents tag 1, etc
    state_flags: []const comptime_int,
};

pub const Direction = enum {
    FORWARD,
    BACKWARD,
};

// const ERR_START_PLUS_COUNT_OOB = "start ({d}) + count ({d}) == {d}, which is out of bounds for list.len ({d})";

/// This is the core linked list paradigm, both other paradigms ('static_allocator' and 'cached_allocator')
/// simply call this type's methods and provide their own allocator
pub fn define_manual_allocator_inked_list_type(comptime options: LinkedListOptions) type {
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

        pub const SET_COUNT = Types.enum_defined_field_count(options.linked_set_enum);
        pub const FORWARD = options.forward_linkage != null;
        pub const NEXT_FIELD = if (FORWARD) options.forward_linkage.?.next_index_field else "";
        pub const BACKWARD = options.backward_linkage != null;
        pub const BIDIRECTION = BACKWARD and FORWARD;
        pub const HEAD = FORWARD or options.force_cache_first_index;
        pub const TAIL = BACKWARD or options.force_cache_last_index;
        pub const PREV_FIELD = if (BACKWARD) options.backward_linkage.?.prev_index_field else "";
        pub const USED = options.linked_sets == .USED_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        pub const FREE = options.linked_sets == .FREE_SET_ONLY or options.linked_sets == .USED_AND_FREE_SETS;
        pub const STATE = options.element_state_access != null;
        pub const CACHE = options.element_idx_cache_field != null;
        pub const CACHE_FIELD = if (CACHE) options.element_idx_cache_field.? else "";
        pub const T_STATE = if (STATE) options.element_state_access.?.field_type else void;
        pub const STATE_FIELD = if (STATE) options.element_state_access.?.field else "";
        pub const UNINIT = List{};
        pub const RETURN_ERRORS = options.list_options.error_behavior == .RETURN_ERRORS;
        pub const NULL_IDX = math.maxInt(Idx);
        pub const STATE_FLAGS = SETS_ARRAY;
        pub const STATE_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) options.element_state_access.?.state_mask else 0;
        pub const STATE_CLEAR_MASK: if (STATE) options.element_state_access.?.field_type else comptime_int = if (STATE) ~options.element_state_access.?.state_mask else 0b1111111111111111111111111111111111111111111111111111111111111111;
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
            ptr: *Elem = @ptrFromInt(mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem))),
            idx: Idx = 0,
        };
        pub const StartEnd = struct {
            start: Idx = 0,
            end: Idx = 0,
        };
        pub const IdxPtrIdx = struct {
            idx_ptr: *Idx = &DUMMY_IDX,
            idx: Idx = 0,
        };
        pub const ConnLeft = choose: {
            if (BIDIRECTION) break :choose IdxPtrIdx;
            if (FORWARD) break :choose *Idx;
            if (BACKWARD) break :choose Idx;
            unreachable;
        };
        pub const ConnRight = choose: {
            if (BIDIRECTION) break :choose IdxPtrIdx;
            if (FORWARD) break :choose Idx;
            if (BACKWARD) break :choose *Idx;
            unreachable;
        };
        pub const ConnLeftRight = struct {
            left: ConnLeft,
            right: ConnRight,
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
        var DUMMY_IDX: Idx = 0;

        pub const GetMode = enum {
            BRAND_NEW,
            TRY_FIRST_HEAD_FROM_SET_ELSE_NEW,
            TRY_LAST_TAIL_FROM_SET_ELSE_NEW,
            FIRST_FROM_SET_HEAD,
            LAST_FROM_SET_TAIL,
            USING_INDEX,
            USING_PTR,
            USING_ITEM,
        };

        pub const GetSlot = union(GetMode) {
            BRAND_NEW: void,
            TRY_FIRST_HEAD_FROM_SET_ELSE_NEW: LinkSet,
            TRY_LAST_TAIL_FROM_SET_ELSE_NEW: LinkSet,
            FIRST_FROM_SET_HEAD: LinkSet,
            LAST_FROM_SET_TAIL: LinkSet,
            USING_INDEX: SetIdx,
            USING_PTR: SetPtr,
            USING_ITEM: SetItem,

            pub inline fn brand_new() GetSlot {
                return GetSlot{ .BRAND_NEW = void{} };
            }

            pub inline fn try_first_head_from_set_else_new(set: LinkSet) GetSlot {
                return GetSlot{ .TRY_FIRST_HEAD_FROM_SET_ELSE_NEW = set };
            }

            pub inline fn try_last_tail_from_set_else_new(set: LinkSet) GetSlot {
                return GetSlot{ .TRY_LAST_TAIL_FROM_SET_ELSE_NEW = set };
            }

            pub inline fn first_from_set(set: LinkSet) GetSlot {
                return GetSlot{ .FIRST_FROM_SET_HEAD = set };
            }

            pub inline fn last_from_set(set: LinkSet) GetSlot {
                return GetSlot{ .LAST_FROM_SET_TAIL = set };
            }

            pub inline fn using_index(idx_and_set: SetIdx) GetSlot {
                return GetSlot{ .USING_INDEX = idx_and_set };
            }

            pub inline fn using_ptr(ptr_and_set: SetPtr) GetSlot {
                return GetSlot{ .USING_PTR = ptr_and_set };
            }

            pub inline fn using_item(item_and_set: SetItem) GetSlot {
                return GetSlot{ .USING_ITEM = item_and_set };
            }
        };

        pub const InsertMode = enum {
            AT_BEGINNING_HEAD_OF_SET,
            AT_END_TAIL_OF_SET,
            AFTER_INDEX,
            AFTER_PTR,
            AFTER_ITEM,
            BEFORE_INDEX,
            BEFORE_PTR,
            BEFORE_ITEM,
            DESTROY,
        };

        pub const InsertSlot = union(InsertMode) {
            AT_BEGINNING_HEAD_OF_SET: LinkSet,
            AT_END_TAIL_OF_SET: LinkSet,
            AFTER_INDEX: SetIdx,
            AFTER_PTR: SetPtr,
            AFTER_ITEM: SetItem,
            BEFORE_INDEX: SetIdx,
            BEFORE_PTR: SetPtr,
            BEFORE_ITEM: SetItem,

            pub inline fn at_beginning_head_of_set(set: LinkSet) InsertSlot {
                return InsertSlot{ .AT_BEGINNING_HEAD_OF_SET = set };
            }

            pub inline fn at_end_tail_of_set(set: LinkSet) InsertSlot {
                return InsertSlot{ .AT_END_TAIL_OF_SET = set };
            }

            pub inline fn after_index(idx_and_set: SetIdx) InsertSlot {
                return InsertSlot{ .AFTER_INDEX = idx_and_set };
            }

            pub inline fn after_ptr(ptr_and_set: SetPtr) InsertSlot {
                return InsertSlot{ .AFTER_PTR = ptr_and_set };
            }

            pub inline fn after_item(item_and_set: SetItem) InsertSlot {
                return InsertSlot{ .AFTER_ITEM = item_and_set };
            }

            pub inline fn before_index(idx_and_set: SetIdx) InsertSlot {
                return InsertSlot{ .BEFORE_INDEX = idx_and_set };
            }

            pub inline fn before_ptr(ptr_and_set: SetPtr) InsertSlot {
                return InsertSlot{ .BEFORE_PTR = ptr_and_set };
            }

            pub inline fn before_item(item_and_set: SetItem) InsertSlot {
                return InsertSlot{ .BEFORE_ITEM = item_and_set };
            }
        };

        /// All functions in this namespace should be considered DANGEROUS to use
        /// if you do not manually manage and maintain a valid linked list state
        ///
        /// They are provided here to facilitate special user use cases
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

            pub fn link_item_chain(items: []const Item) void {
                var i = 1;
                while (i < items.len) : (i += 1) {
                    const this_item = items[i];
                    const prev_item = items[i - 1];
                    connect_two_items_on_same_set(prev_item, this_item);
                }
            }

            pub inline fn connect_one_before(prev_item: ConnLeft, this_item: ConnRight, new_item: Item) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(prev_item.idx_ptr, new_item.idx);
                        set_next_idx(new_item.ptr, this_item.idx);
                    } else {
                        set_next_idx(prev_item, new_item.idx);
                        set_next_idx(new_item.ptr, this_item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(this_item.idx_ptr, new_item.idx);
                        set_prev_idx(new_item.ptr, prev_item.idx);
                    } else {
                        set_prev_idx(this_item, new_item.idx);
                        set_prev_idx(new_item.ptr, prev_item);
                    }
                }
            }

            pub inline fn connect_chain_before(prev_item: ConnLeft, this_item: ConnRight, first_new_item: ConnRight, last_new_item: ConnLeft) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(prev_item.idx_ptr, first_new_item.idx);
                        set_next_idx(last_new_item.idx_ptr, this_item.idx);
                    } else {
                        set_next_idx(prev_item, first_new_item);
                        set_next_idx(last_new_item, this_item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(this_item.idx_ptr, last_new_item.idx);
                        set_prev_idx(first_new_item.idx_ptr, prev_item.idx);
                    } else {
                        set_prev_idx(this_item, last_new_item);
                        set_prev_idx(first_new_item, prev_item);
                    }
                }
            }

            pub inline fn connect_one_after(this_item: ConnLeft, next_item: ConnRight, new_item: Item) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(this_item.idx_ptr, new_item.idx);
                        set_next_idx(new_item.ptr, next_item.idx);
                    } else {
                        set_next_idx(this_item, new_item.idx);
                        set_next_idx(new_item.ptr, next_item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(next_item.idx_ptr, new_item.idx);
                        set_prev_idx(new_item.ptr, this_item.idx);
                    } else {
                        set_prev_idx(next_item, new_item.idx);
                        set_prev_idx(new_item.ptr, this_item);
                    }
                }
            }

            pub inline fn connect_chain_after(this_item: ConnLeft, next_item: ConnRight, first_new_item: ConnRight, last_new_item: ConnLeft) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(this_item.idx_ptr, first_new_item.idx);
                        set_next_idx(last_new_item.idx_ptr, next_item.idx);
                    } else {
                        set_next_idx(this_item, first_new_item);
                        set_next_idx(last_new_item, next_item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(next_item.idx_ptr, last_new_item.idx);
                        set_prev_idx(first_new_item.idx_ptr, this_item.idx);
                    } else {
                        set_prev_idx(next_item, last_new_item);
                        set_prev_idx(first_new_item, this_item);
                    }
                }
            }

            pub fn connect_to_head(self: *List, set: LinkSet, item: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_first_index(self, set, item.idx);
                    } else {
                        set_first_index(self, set, item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(item.idx_ptr, NULL_IDX);
                    } else {
                        set_prev_idx(item, NULL_IDX);
                    }
                }
            }

            pub fn connect_to_tail(self: *List, set: LinkSet, item: ConnLeft) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(item.idx_ptr, NULL_IDX);
                    } else {
                        set_next_idx(item, NULL_IDX);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_last_index(self, set, item.idx);
                    } else {
                        set_last_index(self, set, item);
                    }
                }
            }

            pub inline fn connect_two_items_on_same_set(left_item: ConnLeft, right_item: ConnRight) void {
                if (FORWARD) {
                    if (BIDIRECTION) {
                        set_next_idx(left_item.idx_ptr, right_item.idx);
                    } else {
                        set_next_idx(left_item, right_item);
                    }
                }
                if (BACKWARD) {
                    if (BIDIRECTION) {
                        set_prev_idx(right_item.idx_ptr, left_item.idx);
                    } else {
                        set_prev_idx(right_item, left_item);
                    }
                }
            }
        };

        pub inline fn get_item_from_ptr(self: *const List, ptr: *Elem) Item {
            return Item{
                .idx = self.get_idx(ptr),
                .ptr = ptr,
            };
        }

        pub inline fn get_item_from_idx(self: *const List, idx: Idx) Item {
            return Item{
                .idx = idx,
                .ptr = self.get_ptr(idx),
            };
        }

        pub inline fn get_conn_left_from_idx(self: *const List, idx: Idx) ConnLeft {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = idx,
                .idx_ptr = &@field(self.get_ptr(idx), NEXT_FIELD),
            };
            if (FORWARD) return &@field(self.get_ptr(idx), NEXT_FIELD);
            if (BACKWARD) return idx;
        }

        pub inline fn get_conn_left_from_ptr(self: *const List, ptr: *Elem) ConnLeft {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = self.get_idx(ptr),
                .idx_ptr = &@field(ptr, NEXT_FIELD),
            };
            if (FORWARD) return &@field(ptr, NEXT_FIELD);
            if (BACKWARD) return self.get_idx(ptr);
        }

        pub inline fn get_conn_left_from_item(item: Item) ConnLeft {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = item.idx,
                .idx_ptr = &@field(item.ptr, NEXT_FIELD),
            };
            if (FORWARD) return &@field(item.ptr, NEXT_FIELD);
            if (BACKWARD) return item.idx;
        }
        pub inline fn get_conn_left_from_set_head(self: *List, set: LinkSet) ConnLeft {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = NULL_IDX,
                .idx_ptr = self.get_first_index_ref(set),
            };
            if (FORWARD) return self.get_first_index_ref(set);
            if (BACKWARD) return NULL_IDX;
        }

        pub inline fn get_conn_right_from_idx(self: *const List, idx: Idx) ConnRight {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = idx,
                .ptr = &@field(self.get_ptr(idx), PREV_FIELD),
            };
            if (FORWARD) return idx;
            if (BACKWARD) return &@field(self.get_ptr(idx), PREV_FIELD);
        }

        pub inline fn get_conn_right_from_ptr(self: *const List, ptr: *Elem) ConnRight {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = self.get_idx(ptr),
                .ptr = &@field(ptr, PREV_FIELD),
            };
            if (FORWARD) return &@field(ptr, PREV_FIELD);
            if (BACKWARD) return ptr;
        }

        pub inline fn get_conn_right_from_item(item: Item) ConnRight {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = item.idx,
                .idx_ptr = &@field(item.ptr, PREV_FIELD),
            };
            if (FORWARD) return item.idx;
            if (BACKWARD) return &@field(item.ptr, PREV_FIELD);
        }

        pub inline fn get_conn_right_set_tail(self: *List, set: LinkSet) ConnRight {
            if (BIDIRECTION) return IdxPtrIdx{
                .idx = NULL_IDX,
                .idx_ptr = self.get_last_index_ref(set),
            };
            if (FORWARD) return NULL_IDX;
            if (BACKWARD) return self.get_last_index_ref(set);
        }

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
                try self.ensure_total_capacity_exact(capacity, alloc);
            } else {
                self.ensure_total_capacity_exact(capacity, alloc);
            }
            return self;
        }

        pub fn clone(self: List, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            var new_list = self;
            new_list.list = if (RETURN_ERRORS) try self.list.clone(alloc) else self.list.clone(alloc);
            return new_list;
        }

        pub inline fn get_next_idx_from_ptr(self: *const List, set: LinkSet, ptr: *const Elem) Idx {
            if (FORWARD) return @field(ptr, NEXT_FIELD);
            const idx = self.get_idx(ptr);
            return self.traverse_to_find_item_index_preceding_this_one_in_direction(idx, set, .BACKWARD);
        }

        pub inline fn get_prev_idx_from_ptr(self: *const List, set: LinkSet, ptr: *const Elem) Idx {
            if (BACKWARD) return @field(ptr, PREV_FIELD);
            const idx = self.get_idx(ptr);
            return self.traverse_to_find_item_index_preceding_this_one_in_direction(idx, set, .FORWARD);
        }

        pub inline fn get_next_idx_from_idx(self: *const List, set: LinkSet, idx: Idx) Idx {
            if (FORWARD) {
                const ptr = self.get_ptr(idx);
                return @field(ptr, NEXT_FIELD);
            }
            return self.traverse_to_find_item_index_preceding_this_one_in_direction(idx, set, .BACKWARD);
        }

        pub inline fn get_prev_idx_from_idx(self: *const List, set: LinkSet, idx: Idx) Idx {
            if (BACKWARD) {
                const ptr = self.get_ptr(idx);
                return @field(ptr, PREV_FIELD);
            }
            return self.traverse_to_find_item_index_preceding_this_one_in_direction(idx, set, .FORWARD);
        }

        pub inline fn get_ptr(self: *const List, idx: Idx) *Elem {
            assert_idx_less_than_len(idx, self.list.len, @src());
            return &self.list.ptr[idx];
        }

        pub inline fn get_idx(self: *const List, ptr: *const Elem) Idx {
            Assert.assert_pointer_resides_in_slice(Elem, self.list.slice(), ptr, @src());
            if (CACHE) return @field(self, CACHE_FIELD);
            const base_addr = @intFromPtr(self.list.ptr);
            const ptr_addr = @intFromPtr(ptr);
            const delta = ptr_addr - base_addr;
            return @intCast(delta / @sizeOf(Elem));
        }

        pub inline fn get_head_index(self: *List, set: LinkSet) Idx {
            assert_with_reason(HEAD, @src(), "linked list does not cache the first/head index", .{});
            return self.sets[@intFromEnum(set)].first_idx;
        }

        pub inline fn get_first_index_ref(self: *List, set: LinkSet) *Idx {
            assert_with_reason(HEAD, @src(), "linked list does not cache the first/head index", .{});
            return &self.sets[@intFromEnum(set)].first_idx;
        }

        pub inline fn get_tail_index(self: *List, set: LinkSet) Idx {
            assert_with_reason(TAIL, @src(), "linked list does not cache the last/tail index", .{});
            return self.sets[@intFromEnum(set)].last_idx;
        }

        pub inline fn get_last_index_ref(self: *List, set: LinkSet) *Idx {
            assert_with_reason(TAIL, @src(), "linked list does not cache the last/tail index", .{});
            return &self.sets[@intFromEnum(set)].last_idx;
        }

        pub inline fn get_link_set_count(self: *List, set: LinkSet) Idx {
            return self.sets[@intFromEnum(set)].count;
        }

        pub inline fn get_state(ptr: *const Elem) T_STATE {
            assert_with_reason(STATE, @src(), "cannot return item state when items do not cache their own state", .{});
            return @field(ptr, STATE_FIELD) & STATE_MASK;
        }

        pub fn traverse_and_report_if_found_idx_in_set(self: *const List, set: LinkSet, idx: Idx) bool {
            var i: Idx = if (FORWARD) self.get_head_index(set) else self.get_tail_index(set);
            var c: Idx = 0;
            const limit: Idx = self.get_link_set_count(set);
            while (i != NULL_IDX and (if (DEBUG) c < limit else true)) {
                if (i == idx) return true;
                const i_item = self.get_item(i);
                i = if (FORWARD) self.get_n(set, i_item) else self.get_prev_idx(set, i_item);
                if (DEBUG) c += 1;
            }
            if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
            return false;
        }

        pub inline fn idx_is_in_set(self: *const List, idx: Idx, set: LinkSet) bool {
            if (STATE) {
                const ptr = self.get_ptr(idx);
                return @field(ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            }
            return self.traverse_and_report_if_found_idx_in_set(set, idx);
        }

        pub inline fn ptr_is_in_set(self: *const List, ptr: *const Elem, set: LinkSet) bool {
            if (STATE) return @field(ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            const idx = self.get_idx(ptr);
            return self.traverse_and_report_if_found_idx_in_set(set, idx);
        }
        pub inline fn item_is_in_set(self: *const List, item: Item, set: LinkSet) bool {
            if (STATE) return @field(item.ptr, STATE_FIELD) & STATE_MASK == STATE_FLAGS[@intFromEnum(set)];
            return self.traverse_and_report_if_found_idx_in_set(set, item.idx);
        }

        pub fn traverse_to_find_index_preceding_this_one_in_direction(self: List, idx: Idx, set: LinkSet, dir: Direction) Idx {
            var curr_idx: Idx = undefined;
            var count: Idx = 0;
            const limit = self.get_link_set_count(set);
            switch (dir) {
                .BACKWARD => {
                    assert_with_reason(BACKWARD, @src(), "linked list does not link elements in the backward direction", .{});
                    curr_idx = self.get_tail_index(set);
                },
                .FORWARD => {
                    assert_with_reason(FORWARD, @src(), "linked list does not link elements in the forward direction", .{});
                    curr_idx = self.get_head_index(set);
                },
            }
            while (curr_idx != NULL_IDX) {
                if (DEBUG) assert_with_reason(count < limit, @src(), "already traversed {d} (total set count) items in set `{s}`, but there are more non-null indexes after the last", .{ limit, @tagName(set) });
                assert_with_reason(curr_idx < self.list.len, @src(), "while traversing set `{s}` in direction `{s}`, index {d} was found, which is out of bounds for list.len {d}", .{ @tagName(set), @tagName(dir), curr_idx, self.list.len });
                const following_idx = switch (dir) {
                    .FORWARD => get_next_idx_from_idx(curr_idx),
                    .BACKWARD => get_prev_idx_from_idx(curr_idx),
                };
                if (following_idx == idx) return curr_idx;
                curr_idx = following_idx;
                if (DEBUG) count += 1;
            }
            if (DEBUG) assert_with_reason(count == limit, @src(), "found null-index in set `{s}`, but the number of traversed items ({d}) does not match the total in that set ({d})\nALSO: no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ @tagName(set), count, limit, idx, @tagName(set), @tagName(dir) });
            assert_with_reason(false, @src(), "no item found referencing index {d} in set `{s}` direction `{s}`: broken list or item in wrong set", .{ idx, @tagName(set), @tagName(dir) });
        }

        pub fn get_first_item_in_set(self: *const List, set: LinkSet) Item {
            if (HEAD) return self.get_head_index(set);
            var ii = Item{};
            var i = self.get_item_from_idx(self.get_tail_index(set));
            var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
            const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_link_set_count(set) else void{};
            while (i.idx != NULL_IDX) {
                ii = i;
                if (DEBUG) c += 1;
                i = self.get_item_from_idx(self.get_prev_idx_from_ptr(set, i.ptr));
            }
            if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `BACKWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
            return ii;
        }

        pub fn get_last_item_in_set(self: *const List, set: LinkSet) Item {
            if (TAIL) return self.get_tail_index(set);
            var ii = Item{};
            var i = self.get_item_from_idx(self.get_head_index(set));
            var c: if (DEBUG) Idx else void = if (DEBUG) 0 else void{};
            const limit: if (DEBUG) Idx else void = if (DEBUG) self.get_link_set_count(set) else void{};
            while (i.idx != NULL_IDX) {
                ii = i;
                if (DEBUG) c += 1;
                i = self.get_item_from_idx(self.get_next_idx_from_ptr(set, i.ptr));
            }
            if (DEBUG) assert_with_reason(c == limit, @src(), "found null-index in set `{s}` while traversing in `FORWARD` direction, but the number of traversed items ({d}) does not match the total in that set ({d})", .{ @tagName(set), c, limit });
            return ii;
        }

        pub fn get_item_slot_and_insert_at_assume_capacity(self: *List, get_slot_from: GetSlot, insert_slot_at: InsertSlot) Item {
            var conn: ConnLeftRight = undefined;
            switch (insert_slot_at) {
                .AFTER_INDEX => |after| {
                    conn.left = self.get_conn_left_from_idx(after.idx);
                    const next_idx = self.get_next_idx_from_idx(after.set, after.idx);
                    conn.right = self.get_conn_right_from_idx(next_idx);
                },
                .AFTER_ITEM => |after| {
                    conn.left = self.get_conn_left_from_item(after.item);
                    const next_idx = self.get_next_idx_from_idx(after.set, after.item.idx);
                    conn.right = self.get_conn_right_from_idx(next_idx);
                },
                .AFTER_PTR => |after| {
                    conn.left = self.get_conn_left_from_item(after.ptr);
                    const next_idx = self.get_next_idx_from_ptr(after.set, after.ptr);
                    conn.right = self.get_conn_right_from_idx(next_idx);
                },
                .BEFORE_INDEX => |before| {
                    conn.right = self.get_conn_right_from_idx(before.idx);
                    const prev_idx = self.get_prev_idx_from_idx(before.set, before.idx);
                    conn.left = self.get_conn_left_from_idx(prev_idx);
                },
                .BEFORE_ITEM => |before| {
                    conn.right = self.get_conn_right_from_item(before.item);
                    const prev_idx = self.get_prev_idx_from_idx(before.set, before.item.idx);
                    conn.left = self.get_conn_left_from_idx(prev_idx);
                },
                .BEFORE_PTR => |before| {
                    conn.right = self.get_conn_right_from_item(before.ptr);
                    const prev_idx = self.get_prev_idx_from_ptr(before.set, before.ptr);
                    conn.left = self.get_conn_left_from_idx(prev_idx);
                },
                .AT_BEGINNING_HEAD_OF_SET => |set| {
                    conn.left = self.get_conn_left_from_set_head(set);
                    const next_item = self.get_first_item_in_set(set);
                    conn.right = self.get_conn_right_from_item(next_item);
                },
                .AT_END_TAIL_OF_SET => |set| {
                    conn.right = self.get_conn_right_set_tail(set);
                    const prev_item = self.get_last_item_in_set(set);
                    conn.left = self.get_conn_left_from_item(prev_item);
                },
            }
            //CHECKPOINT finish function
            switch (get_slot_from) {
                .BRAND_NEW => {},
                .FIRST_FROM_SET_HEAD => |set| {},
                .LAST_FROM_SET_TAIL => |set| {},
                .TRY_FIRST_HEAD_FROM_SET_ELSE_NEW => |set| {},
                .TRY_LAST_TAIL_FROM_SET_ELSE_NEW => |set| {},
                .USING_INDEX => |using| {},
                .USING_ITEM => |using| {},
                .USING_PTR => |using| {},
            }
        }

        pub fn insert_slot_after_ptr_assume_capacity(self: *List, ptr: *Elem) *Elem {
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn insert(self: *List, idx: Idx, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const ptr = if (RETURN_ERRORS) try self.insert_slot(idx, alloc) else self.insert_slot(idx, alloc);
            ptr.* = item;
        }

        pub fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            const ptr = self.insert_slot_assume_capacity(idx);
            ptr.* = item;
        }

        pub fn insert_many_slots(self: *List, idx: Idx, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
            if (RETURN_ERRORS) {
                try self.ensure_unused_capacity(count, alloc);
            } else {
                self.ensure_unused_capacity(count, alloc);
            }
            return self.insert_many_slots_assume_capacity(idx, count);
        }

        pub fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            assert_with_reason(idx + count <= self.len, @src(), ERR_START_PLUS_COUNT_OOB, .{ idx, count, idx + count, self.len });
            mem.copyBackwards(Elem, self.ptr[idx + count .. self.len + count], self.ptr[idx..self.len]);
            self.len += count;
            return self.ptr[idx .. idx + count];
        }

        pub fn insert_slice(self: *List, idx: Idx, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.insert_many_slots(idx, @intCast(items.len), alloc) else self.insert_many_slots(idx, @intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            const slots = self.insert_many_slots_assume_capacity(idx, @intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (new_items.len > length) {
                const additional_needed: Idx = @as(Idx, @intCast(new_items.len)) - length;
                if (RETURN_ERRORS) {
                    try self.ensure_unused_capacity(additional_needed, alloc);
                } else {
                    self.ensure_unused_capacity(additional_needed, alloc);
                }
            }
            self.replace_range_assume_capacity(start, length, new_items);
        }

        pub fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            const end_of_range = start + length;
            assert_with_reason(end_of_range <= self.len, @src(), ERR_LAST_IDX_GREATER_LEN, .{ end_of_range, self.len });
            const range = self.ptr[start..end_of_range];
            if (range.len == new_items.len)
                @memcpy(range[0..new_items.len], new_items)
            else if (range.len < new_items.len) {
                const within_range = new_items[0..range.len];
                const leftover = new_items[range.len..];
                @memcpy(range[0..within_range.len], within_range);
                const new_slots = self.insert_many_slots_assume_capacity(end_of_range, @intCast(leftover.len));
                @memcpy(new_slots, leftover);
            } else {
                const unused_slots: Idx = @intCast(range.len - new_items.len);
                @memcpy(range[0..new_items.len], new_items);
                std.mem.copyForwards(Elem, self.ptr[end_of_range - unused_slots .. self.len], self.ptr[end_of_range..self.len]);
                if (SECURE_WIPE) {
                    crypto.secureZero(Elem, self.ptr[self.len - unused_slots .. self.len]);
                }
                self.len -= unused_slots;
            }
        }

        pub fn append(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const slot = if (RETURN_ERRORS) try self.append_slot(alloc) else self.append_slot(alloc);
            slot.* = item;
        }

        pub fn append_assume_capacity(self: *List, item: Elem) void {
            const slot = self.append_slot_assume_capacity();
            slot.* = item;
        }

        pub fn remove(self: *List, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.delete(idx);
            return val;
        }

        pub fn swap_remove(self: *List, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.swap_delete(idx);
            return val;
        }

        pub fn delete(self: *List, idx: Idx) void {
            assert_with_reason(idx < self.len, @src(), ERR_IDX_GREATER_EQL_LEN, .{ idx, self.len });
            std.mem.copyForwards(Elem, self.ptr[idx..self.len], self.ptr[idx + 1 .. self.len]);
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn delete_range(self: *List, start: Idx, length: Idx) void {
            const end_of_range = start + length;
            assert_with_reason(end_of_range <= self.len, @src(), ERR_LAST_IDX_GREATER_LEN, .{ end_of_range, self.len });
            std.mem.copyForwards(Elem, self.ptr[start..self.len], self.ptr[end_of_range..self.len]);
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - length .. self.len]);
            }
            self.len -= length;
        }

        pub fn swap_delete(self: *List, idx: Idx) void {
            assert_with_reason(idx < self.len, @src(), ERR_IDX_GREATER_EQL_LEN, .{ idx, self.len });
            self.ptr[idx] = self.ptr[self.list.items.len - 1];
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn append_slice(self: *List, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(@intCast(items.len), alloc) else self.append_many_slots(@intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned(self: *List, items: []align(1) const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(@intCast(items.len), alloc) else self.append_many_slots(@intCast(items.len), alloc);
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(count, alloc) else self.append_many_slots(count, alloc);
            @memset(slots, value);
        }

        pub fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            const slots = self.append_many_slots_assume_capacity(count);
            @memset(slots, value);
        }

        pub fn resize(self: *List, new_len: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (RETURN_ERRORS) {
                try self.ensure_total_capacity(new_len, alloc);
            } else {
                self.ensure_total_capacity(new_len, alloc);
            }
            if (SECURE_WIPE and new_len < self.len) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn shrink_and_free(self: *List, new_len: Idx, alloc: Allocator) void {
            assert_with_reason(new_len <= self.len, @src(), ERR_NEW_LEN_GREATER_LEN, .{ new_len, self.len });
            if (@sizeOf(Elem) == 0) {
                self.len = new_len;
                return;
            }

            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_len)) |new_items| {
                self.ptr = new_items.ptr;
                self.len = new_items.len;
                self.cap = new_items.len;
                return;
            }

            const new_memory = alloc.alignedAlloc(Elem, ALIGN, new_len) catch |err| return handle_alloc_error(err);

            @memcpy(new_memory, self.ptr[0..new_len]);
            alloc.free(old_memory);
            self.ptr = new_memory.ptr;
            self.len = new_memory.len;
            self.cap = new_memory.len;
        }

        pub fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            assert_with_reason(new_len <= self.len, @src(), ERR_NEW_LEN_GREATER_LEN, .{ new_len, self.len });
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn clear_retaining_capacity(self: *List) void {
            if (SECURE_WIPE) {
                std.crypto.secureZero(Elem, self.ptr[0..self.len]);
            }
            self.len = 0;
        }

        pub fn clear_and_free(self: *List, alloc: Allocator) void {
            if (SECURE_WIPE) {
                std.crypto.secureZero(Elem, self.ptr[0..self.len]);
            }
            alloc.free(self.ptr[0..self.cap]);
            self.* = UNINIT;
        }

        pub fn ensure_total_capacity(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (self.cap >= new_capacity) return;
            return self.ensure_total_capacity_exact(true_capacity_for_grow(self.cap, new_capacity), alloc);
        }

        pub fn ensure_total_capacity_exact(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (@sizeOf(Elem) == 0) {
                self.cap = math.maxInt(Idx);
                return;
            }

            if (self.cap >= new_capacity) return;

            if (new_capacity < self.len) {
                if (SECURE_WIPE) crypto.secureZero(Elem, self.ptr[new_capacity..self.len]);
                self.len = new_capacity;
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_capacity)) |new_memory| {
                self.ptr = new_memory.ptr;
                self.cap = @intCast(new_memory.len);
            } else {
                const new_memory = alloc.alignedAlloc(Elem, ALIGN, new_capacity) catch |err| return handle_alloc_error(err);
                @memcpy(new_memory[0..self.len], self.ptr[0..self.len]);
                if (SECURE_WIPE) crypto.secureZero(Elem, self.ptr[0..self.len]);
                alloc.free(old_memory);
                self.ptr = new_memory.ptr;
                self.cap = @as(Idx, @intCast(new_memory.len));
            }
        }

        pub fn ensure_unused_capacity(self: *List, additional_count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            const new_total_cap = if (RETURN_ERRORS) try add_or_error(self.len, additional_count) else add_or_error(self.len, additional_count);
            return self.ensure_total_capacity(new_total_cap, alloc);
        }

        pub fn expand_to_capacity(self: *List) void {
            self.len = self.cap;
        }

        pub fn append_slot(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
            const new_len = self.len + 1;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len, alloc) else self.ensure_total_capacity(new_len, alloc);
            return self.append_slot_assume_capacity();
        }

        pub fn append_slot_assume_capacity(self: *List) *Elem {
            assert_with_reason(self.len < self.cap, @src(), ERR_LEN_EQUALS_CAP, .{ self.len, self.cap });
            const idx = self.len;
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn append_many_slots(self: *List, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
            const new_len = self.len + count;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len, alloc) else self.ensure_total_capacity(new_len, alloc);
            return self.append_many_slots_assume_capacity(count);
        }

        pub fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            const new_len = self.len + count;
            assert_with_reason(new_len <= self.cap, @src(), ERR_LEN_PLUS_COUNT_GREATER_CAP, .{ self.len, count, self.len + count, self.cap });
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn append_many_slots_as_array(self: *List, comptime count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            const new_len = self.len + count;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len, alloc) else self.ensure_total_capacity(new_len, alloc);
            return self.append_many_slots_as_array_assume_capacity(count);
        }

        pub fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            const new_len = self.len + count;
            assert_with_reason(new_len <= self.cap, @src(), ERR_LEN_PLUS_COUNT_GREATER_CAP, .{ self.len, count, self.len + count, self.cap });
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn pop(self: *List) Elem {
            assert_with_reason(self.len > 0, @src(), ERR_LIST_EMPTY, .{});
            const new_len = self.len - 1;
            self.len = new_len;
            return self.ptr[new_len];
        }

        pub fn pop_or_null(self: *List) ?Elem {
            if (self.len == 0) return null;
            return self.pop();
        }

        pub fn get_last(self: List) Elem {
            assert_with_reason(self.len > 0, @src(), ERR_LIST_EMPTY, .{});
            return self.ptr[self.len - 1];
        }

        pub fn get_last_or_null(self: List) ?Elem {
            if (self.len == 0) return null;
            return self.get_last();
        }

        pub fn add_or_error(a: Idx, b: Idx) if (RETURN_ERRORS) error{OutOfMemory}!Idx else Idx {
            if (!RETURN_ERRORS) return a + b;
            const result, const overflow = @addWithOverflow(a, b);
            if (overflow != 0) return error.OutOfMemory;
            return result;
        }

        pub fn true_capacity_for_grow(current: Idx, minimum: Idx) Idx {
            switch (GROWTH) {
                GrowthModel.GROW_EXACT_NEEDED => {
                    return minimum;
                },
                GrowthModel.GROW_EXACT_NEEDED_ATOMIC_PADDING => {
                    return minimum + ATOMIC_PADDING;
                },
                else => {
                    var new = current;
                    while (true) {
                        switch (GROWTH) {
                            GrowthModel.GROW_BY_100_PERCENT => {
                                new +|= new;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_100_PERCENT_ATOMIC_PADDING => {
                                new +|= new;
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_50_PERCENT => {
                                new +|= new / 2;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_50_PERCENT_ATOMIC_PADDING => {
                                new +|= new / 2;
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_25_PERCENT => {
                                new +|= new / 4;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_25_PERCENT_ATOMIC_PADDING => {
                                new +|= new / 4;
                                const new_with_padding = new +| ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        }

        pub fn find_idx(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
            for (self.slice(), 0..) |*item, idx| {
                if (match_fn(param, item)) return @intCast(idx);
            }
            return null;
        }

        pub fn find_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return &self.ptr[idx];
            }
            return null;
        }

        pub fn find_const_ptr(self: List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return &self.ptr[idx];
            }
            return null;
        }

        pub fn find_and_copy(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return self.ptr[idx];
            }
            return null;
        }

        pub fn find_and_remove(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                return self.remove(idx);
            }
            return null;
        }

        pub fn find_and_delete(self: *List, comptime Param: type, param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
            if (self.find_idx(Param, param, match_fn)) |idx| {
                self.delete(idx);
                return true;
            }
            return false;
        }

        pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
            return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            assert_with_reason(indexes.len <= self.len, @src(), "more indexes provided ({d}) than exist in list ({d})", .{ indexes.len, self.len });
            assert_with_reason(check: {
                var i: usize = 1;
                while (i < indexes.len) : (i += 1) {
                    if (indexes[i - 1] >= indexes[i]) break :check false;
                }
                break :check true;
            }, @src(), "not all indexes are in increasing order (with no duplicates) as is required by this function", .{});
            assert_with_reason(check: {
                var i: usize = 0;
                while (i < indexes.len) : (i += 1) {
                    if (indexes[i] >= self.len) break :check false;
                }
                break :check true;
            }, @src(), "some indexes provided are out of bounds for list len ({d})", .{self.len});
            var shift_down: usize = 0;
            var i: usize = 0;
            var src_start: Idx = undefined;
            var src_end: Idx = undefined;
            var dst_start: Idx = undefined;
            var dst_end: Idx = undefined;
            while (i < indexes.len) {
                var consecutive: Idx = 1;
                var end_index: Idx = i + consecutive;
                while (end_index < indexes.len) {
                    if (indexes[end_index] != indexes[end_index - 1] + 1) break;
                    consecutive += 1;
                    end_index += 1;
                }
                const start_idx = end_index - 1;
                shift_down += consecutive;
                src_start = indexes[start_idx];
                src_end = if (end_index >= indexes.len) self.len else indexes[end_index];
                dst_start = src_start - shift_down;
                dst_end = src_end - shift_down;
                std.mem.copyForwards(Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
                i += consecutive;
            }
            self.len -= indexes.len;
        }

        //TODO pub fn insert_slots_at_ordered_indexes()

        pub inline fn insertion_sort(self: *List) void {
            return self.flex_slice(.mutable).insertion_sort();
        }

        pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        }

        pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_sorted();
        }

        pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_reverse_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_reverse_sorted();
        }

        pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        // pub inline fn insert_one_sorted( self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return insert_one_sorted_custom(List, self, item, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN, alloc);
        // }

        // pub fn insert_one_sorted_custom( self: *List, item: Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
        //     const insert_idx: Idx = @intCast(BinarySearch.binary_search_insert_index(Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
        //     if (RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
        //     return insert_idx;
        // }

        // pub inline fn find_equal_order_idx_sorted( self: *List, item_to_compare: *const Elem) ?Idx {
        //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_MATCH_FN);
        // }

        // pub fn find_equal_order_idx_sorted_custom( self: *List, item_to_compare: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem)) ?Idx {
        //     const insert_idx = BinarySearch.binary_search_by_order(Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
        //     if (insert_idx) |idx| return @intCast(idx);
        //     return null;
        // }

        // pub inline fn find_matching_item_idx_sorted( self: *List, item_to_find: *const Elem) ?Idx {
        //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, DEFAULT_COMPARE_PKG.greater_than, DEFAULT_COMPARE_PKG.equals, DEFAULT_MATCH_FN);
        // }

        // pub fn find_matching_item_idx_sorted_custom( self: *List, item_to_find: *const Elem, greater_than_fn: *const CompareFn(Elem), equal_order_fn: *const CompareFn(Elem), exact_match_fn: *const CompareFn(Elem)) ?Idx {
        //     const insert_idx = BinarySearch.binary_search_exact_match(Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
        //     if (insert_idx) |idx| return @intCast(idx);
        //     return null;
        // }

        // pub inline fn find_matching_item_idx( self: *List, item_to_find: *const Elem) ?Idx {
        //     return find_matching_item_idx_custom(List, self, item_to_find, DEFAULT_MATCH_FN);
        // }

        // pub fn find_matching_item_idx_custom( self: *List, item_to_find: *const Elem, exact_match_fn: *const CompareFn(Elem)) ?Idx {
        //     if (self.len == 0) return null;
        //     const buf = self.ptr[0..self.len];
        //     var idx: Idx = 0;
        //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
        //     const limit = self.len - 1;
        //     while (!found_exact and idx < limit) {
        //         idx += 1;
        //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
        //     }
        //     if (found_exact) return idx;
        //     return null;
        // }

        pub fn handle_alloc_error(err: Allocator.Error) if (RETURN_ERRORS) Error else noreturn {
            switch (ALLOC_ERROR_BEHAVIOR) {
                ErrorBehavior.RETURN_ERRORS => return err,
                ErrorBehavior.ERRORS_PANIC => std.debug.panic("List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
                ErrorBehavior.ERRORS_ARE_UNREACHABLE => unreachable,
            }
        }

        //**************************
        // std.io.Writer interface *
        //**************************
        const StdWriterHandle = struct {
            list: *List,
            alloc: Allocator,
        };
        const StdWriterHandleNoGrow = struct {
            list: *List,
        };

        pub const StdWriter = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(StdWriterHandle, Allocator.Error, std_write);

        pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
            return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
        }

        fn std_write(handle: StdWriterHandle, bytes: []const u8) Allocator.Error!usize {
            try handle.list.append_slice(bytes, handle.alloc);
            return bytes.len;
        }

        pub const StdWriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(StdWriterHandleNoGrow, Allocator.Error, std_write_no_grow);

        pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
            return StdWriterNoGrow{ .context = .{ .list = self } };
        }

        fn std_write_no_grow(handle: StdWriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }
    };
}

pub fn define_static_allocator_list_type(comptime options: ListOptions, comptime alloc_ptr: *const Allocator) type {
    const opt = comptime check: {
        var opts = options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,

        pub const ALLOC = alloc_ptr;
        pub const ALIGN = options.alignment;
        pub const ALLOC_ERROR_BEHAVIOR = options.error_behavior;
        pub const GROWTH = options.growth_model;
        pub const RETURN_ERRORS = options.error_behavior == .RETURN_ERRORS;
        pub const SECURE_WIPE = options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const UNINIT = List{
            .ptr = UNINIT_PTR,
            .len = 0,
            .cap = 0,
        };

        const List = @This();
        const ManualList = define_manual_allocator_list_type(options);
        pub const Error = Allocator.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }

        pub inline fn to_manually_managed_list(self: List) ManualList {
            return @bitCast(self);
        }
        pub inline fn as_manually_managed_list(self: *List) *ManualList {
            return @ptrCast(@alignCast(self));
        }
        pub inline fn from_manually_managed_list(list: ManualList) List {
            return @bitCast(list);
        }

        pub const Iterator = ListIterator(List);

        pub inline fn new_iterator(self: *List) Iterator {
            return Iterator{
                .list_ref = self,
                .next_idx = 0,
            };
        }

        pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return self.as_manually_managed_list_const().flex_slice(mutability);
        }

        pub inline fn slice(self: List) Slice {
            return self.as_manually_managed_list_const().slice();
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return self.as_manually_managed_list_const().array_ptr(start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return self.as_manually_managed_list_const().vector_ptr(start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return self.as_manually_managed_list_const().slice_with_sentinel(sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return self.as_manually_managed_list_const().slice_full_capacity();
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            return self.as_manually_managed_list_const().slice_unused_capacity();
        }

        pub inline fn set_len(self: *List, new_len: Idx) void {
            return self.as_manually_managed_list().set_len(new_len);
        }

        pub inline fn new_empty() List {
            return UNINIT;
        }

        pub inline fn new_with_capacity(capacity: Idx) if (RETURN_ERRORS) Error!List else List {
            if (RETURN_ERRORS) {
                return from_manually_managed_list(try ManualList.new_with_capacity(capacity, ALLOC.*));
            } else {
                return from_manually_managed_list(ManualList.new_with_capacity(capacity, ALLOC.*));
            }
        }

        pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
            if (RETURN_ERRORS) {
                return from_manually_managed_list(try self.to_manually_managed_list().clone(ALLOC.*));
            } else {
                return from_manually_managed_list(self.to_manually_managed_list().clone(ALLOC.*));
            }
        }

        pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
            return self.as_manually_managed_list().to_owned_slice(ALLOC.*);
        }

        pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            return self.as_manually_managed_list().to_owned_slice_sentinel(sentinel, ALLOC.*);
        }

        pub inline fn from_owned_slice(from_slice: Slice) List {
            return from_manually_managed_list(ManualList.from_owned_slice(from_slice));
        }

        pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return from_manually_managed_list(ManualList.from_owned_slice_sentinel(sentinel, from_slice));
        }

        pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return self.as_manually_managed_list().insert_slot(idx, ALLOC.*);
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return self.as_manually_managed_list().insert_slot_assume_capacity(idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().insert(idx, item, ALLOC.*);
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return self.as_manually_managed_list().insert_assume_capacity(idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return self.as_manually_managed_list().insert_many_slots(idx, count, ALLOC.*);
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            return self.as_manually_managed_list().insert_many_slots_assume_capacity(idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().insert_slice(idx, items, ALLOC.*);
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return self.as_manually_managed_list().insert_slice_assume_capacity(idx, items);
        }

        pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().replace_range(start, length, new_items, ALLOC.*);
        }

        pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            return self.as_manually_managed_list().replace_range_assume_capacity(start, length, new_items);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().append(item, ALLOC.*);
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return self.as_manually_managed_list().append_assume_capacity(item);
        }

        pub inline fn remove(self: *List, idx: Idx) Elem {
            return self.as_manually_managed_list().remove(idx);
        }

        pub inline fn swap_remove(self: *List, idx: Idx) Elem {
            return self.as_manually_managed_list().swap_remove(idx);
        }

        pub inline fn delete(self: *List, idx: Idx) void {
            return self.as_manually_managed_list().delete(idx);
        }

        pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
            return self.as_manually_managed_list().delete_range(start, length);
        }

        pub inline fn swap_delete(self: *List, idx: Idx) void {
            return self.as_manually_managed_list().swap_delete(idx);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().append_slice(items, ALLOC.*);
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return self.as_manually_managed_list().append_slice_assume_capacity(items);
        }

        pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().append_slice_unaligned(items, ALLOC.*);
        }

        pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            return self.as_manually_managed_list().append_slice_unaligned_assume_capacity(items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().append_n_times(value, count, ALLOC.*);
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return self.as_manually_managed_list().append_n_times_assume_capacity(value, count);
        }

        pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().resize(new_len, ALLOC.*);
        }

        pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
            return self.as_manually_managed_list().shrink_and_free(new_len, ALLOC.*);
        }

        pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            return self.as_manually_managed_list().shrink_retaining_capacity(new_len);
        }

        pub inline fn clear_retaining_capacity(self: *List) void {
            return self.as_manually_managed_list().clear_retaining_capacity();
        }

        pub inline fn clear_and_free(self: *List) void {
            return self.as_manually_managed_list().clear_and_free(ALLOC.*);
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().ensure_total_capacity(new_capacity, ALLOC.*);
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().ensure_total_capacity_exact(new_capacity, ALLOC.*);
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manually_managed_list().ensure_unused_capacity(additional_count, ALLOC.*);
        }

        pub inline fn expand_to_capacity(self: *List) void {
            return self.as_manually_managed_list().expand_to_capacity();
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return self.as_manually_managed_list().append_slot(ALLOC.*);
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return self.as_manually_managed_list().append_slot_assume_capacity();
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return self.as_manually_managed_list().append_many_slots(count, ALLOC.*);
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            return self.as_manually_managed_list().append_many_slots_assume_capacity(count);
        }

        pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            return self.as_manually_managed_list().append_many_slots_as_array(count, ALLOC.*);
        }

        pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            return self.as_manually_managed_list().append_many_slots_as_array_assume_capacity(count);
        }

        pub inline fn pop_or_null(self: *List) ?Elem {
            return self.as_manually_managed_list().pop_or_null();
        }

        pub inline fn pop(self: *List) Elem {
            return self.as_manually_managed_list().pop();
        }

        pub inline fn get_last(self: List) Elem {
            return self.to_manually_managed_list().get_last();
        }

        pub inline fn get_last_or_null(self: List) ?Elem {
            return self.to_manually_managed_list().get_last_or_null();
        }

        pub inline fn find_idx(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
            return self.to_manually_managed_list().find_idx(Param, match_param, match_fn);
        }

        pub inline fn find_ptr(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
            return self.to_manually_managed_list().find_ptr(Param, match_param, match_fn);
        }

        pub inline fn find_const_ptr(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
            return self.to_manually_managed_list().find_const_ptr(Param, match_param, match_fn);
        }

        pub inline fn find_and_copy(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            return self.to_manually_managed_list().find_and_copy(Param, match_param, match_fn);
        }

        pub inline fn find_and_remove(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            return self.to_manually_managed_list().find_and_remove(Param, match_param, match_fn);
        }

        pub inline fn find_and_delete(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
            return self.to_manually_managed_list().find_and_delete(Param, match_param, match_fn);
        }

        pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
            return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            return self.as_manually_managed_list().delete_ordered_indexes(indexes);
        }

        //TODO pub fn insert_slots_at_ordered_indexes()

        pub inline fn insertion_sort(self: *List) void {
            return self.flex_slice(.mutable).insertion_sort();
        }

        pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        }

        pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_sorted();
        }

        pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_reverse_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_reverse_sorted();
        }

        pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted(List, self, item, ALLOC.*);
        // }

        // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, ALLOC.*);
        // }

        // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
        //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
        // }

        // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
        // }

        // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        pub fn get_std_writer(self: *List) ManualList.StdWriter {
            return self.as_manually_managed_list().get_std_writer(ALLOC.*);
        }

        pub fn get_std_writer_no_grow(self: *List) ManualList.StdWriterNoGrow {
            return self.as_manually_managed_list().get_std_writer_no_grow();
        }
    };
}

pub fn define_cached_allocator_list_type(comptime options: ListOptions) type {
    const opt = comptime check: {
        var opts = options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,
        alloc_ptr: *anyopaque,
        alloc_vtable: *const Allocator.VTable,

        pub const ALIGN = options.alignment;
        pub const ALLOC_ERROR_BEHAVIOR = options.error_behavior;
        pub const GROWTH = options.growth_model;
        pub const RETURN_ERRORS = options.error_behavior == .RETURN_ERRORS;
        pub const SECURE_WIPE = options.secure_wipe_bytes;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
        pub const UNINIT = List{
            .ptr = UNINIT_PTR,
            .alloc_ptr = DummyAllocator.allocator.ptr,
            .alloc_vtable = DummyAllocator.allocator.vtable,
            .len = 0,
            .cap = 0,
        };

        const List = @This();
        pub const ManualList = define_manual_allocator_list_type(options);
        pub const Error = Allocator.Error;
        pub const Elem = options.element_type;
        pub const Idx = options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }

        pub inline fn to_manual_alloc_list(self: List) ManualList {
            return ManualList{
                .ptr = self.ptr,
                .len = self.len,
                .cap = self.cap,
            };
        }
        pub inline fn as_manual_alloc_list(self: *List) *ManualList {
            return @ptrCast(@alignCast(self));
        }
        pub inline fn from_manual_alloc_list(list: ManualList, alloc: Allocator) List {
            return List{
                .ptr = list.ptr,
                .len = list.len,
                .cap = list.cap,
                .alloc_ptr = alloc.ptr,
                .alloc_vtable = alloc.vtable,
            };
        }

        pub const Iterator = ListIterator(List);

        pub inline fn new_iterator(self: *List) Iterator {
            return Iterator{
                .list_ref = self,
                .next_idx = 0,
            };
        }

        pub inline fn get_alloc(self: List) Allocator {
            return Allocator{
                .ptr = self.alloc_ptr,
                .vtable = self.alloc_vtable,
            };
        }

        pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
            return self.to_manual_alloc_list().flex_slice(mutability);
        }

        pub inline fn slice(self: List) Slice {
            return self.to_manual_alloc_list().slice();
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return self.to_manual_alloc_list().array_ptr(start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return self.to_manual_alloc_list().vector_ptr(start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return self.to_manual_alloc_list().slice_with_sentinel(sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return self.to_manual_alloc_list().slice_full_capacity();
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            return self.to_manual_alloc_list().slice_unused_capacity();
        }

        pub inline fn set_len(self: *List, new_len: Idx) void {
            return self.as_manual_alloc_list().set_len(new_len);
        }

        pub inline fn new_empty(alloc: Allocator) List {
            var list = UNINIT;
            list.alloc_ptr = alloc.ptr;
            list.alloc_vtable = alloc.vtable;
            return list;
        }

        pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
            var list: List = undefined;
            if (RETURN_ERRORS) {
                list = from_manual_alloc_list(try ManualList.new_with_capacity(capacity, alloc));
            } else {
                list = from_manual_alloc_list(ManualList.new_with_capacity(capacity, alloc));
            }
            list.alloc_ptr = alloc.ptr;
            list.alloc_vtable = alloc.vtable;
        }

        pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
            if (RETURN_ERRORS) {
                return from_manual_alloc_list(try self.to_manual_alloc_list().clone(self.get_alloc()));
            } else {
                return from_manual_alloc_list(self.to_manual_alloc_list().clone(self.get_alloc()));
            }
        }

        pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
            return self.as_manual_alloc_list().to_owned_slice(self.get_alloc());
        }

        pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            return self.as_manual_alloc_list().to_owned_slice_sentinel(sentinel, self.get_alloc());
        }

        pub inline fn from_owned_slice(from_slice: Slice) List {
            return from_manual_alloc_list(ManualList.from_owned_slice(from_slice));
        }

        pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return from_manual_alloc_list(ManualList.from_owned_slice_sentinel(sentinel, from_slice));
        }

        pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return self.as_manual_alloc_list().insert_slot(idx, self.get_alloc());
        }

        pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            return self.as_manual_alloc_list().insert_slot_assume_capacity(idx);
        }

        pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().insert(idx, item, self.get_alloc());
        }

        pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            return self.as_manual_alloc_list().insert_assume_capacity(idx, item);
        }

        pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return self.as_manual_alloc_list().insert_many_slots(idx, count, self.get_alloc());
        }

        pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            return self.as_manual_alloc_list().insert_many_slots_assume_capacity(idx, count);
        }

        pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().insert_slice(idx, items, self.get_alloc());
        }

        pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
            return self.as_manual_alloc_list().insert_slice_assume_capacity(idx, items);
        }

        pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().replace_range(start, length, new_items, self.get_alloc());
        }

        pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            return self.as_manual_alloc_list().replace_range_assume_capacity(start, length, new_items);
        }

        pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().append(item, self.get_alloc());
        }

        pub inline fn append_assume_capacity(self: *List, item: Elem) void {
            return self.as_manual_alloc_list().append_assume_capacity(item);
        }

        pub inline fn remove(self: *List, idx: Idx) Elem {
            return self.as_manual_alloc_list().remove(idx);
        }

        pub inline fn swap_remove(self: *List, idx: Idx) Elem {
            return self.as_manual_alloc_list().swap_remove(idx);
        }

        pub inline fn delete(self: *List, idx: Idx) void {
            return self.as_manual_alloc_list().delete(idx);
        }

        pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
            return self.as_manual_alloc_list().delete_range(start, length);
        }

        pub inline fn swap_delete(self: *List, idx: Idx) void {
            return self.as_manual_alloc_list().swap_delete(idx);
        }

        pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().append_slice(items, self.get_alloc());
        }

        pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            return self.as_manual_alloc_list().append_slice_assume_capacity(items);
        }

        pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().append_slice_unaligned(items, self.get_alloc());
        }

        pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            return self.as_manual_alloc_list().append_slice_unaligned_assume_capacity(items);
        }

        pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().append_n_times(value, count, self.get_alloc());
        }

        pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            return self.as_manual_alloc_list().append_n_times_assume_capacity(value, count);
        }

        pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().resize(new_len, self.get_alloc());
        }

        pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
            return self.as_manual_alloc_list().shrink_and_free(new_len, self.get_alloc());
        }

        pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            return self.as_manual_alloc_list().shrink_retaining_capacity(new_len);
        }

        pub inline fn clear_retaining_capacity(self: *List) void {
            return self.as_manual_alloc_list().clear_retaining_capacity();
        }

        pub inline fn clear_and_free(self: *List) void {
            return self.as_manual_alloc_list().clear_and_free(self.get_alloc());
        }

        pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().ensure_total_capacity(new_capacity, self.get_alloc());
        }

        pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().ensure_total_capacity_exact(new_capacity, self.get_alloc());
        }

        pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            return self.as_manual_alloc_list().ensure_unused_capacity(additional_count, self.get_alloc());
        }

        pub inline fn expand_to_capacity(self: *List) void {
            return self.as_manual_alloc_list().expand_to_capacity();
        }

        pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            return self.as_manual_alloc_list().append_slot(self.get_alloc());
        }

        pub inline fn append_slot_assume_capacity(self: *List) *Elem {
            return self.as_manual_alloc_list().append_slot_assume_capacity();
        }

        pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            return self.as_manual_alloc_list().append_many_slots(count, self.get_alloc());
        }

        pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            return self.as_manual_alloc_list().append_many_slots_assume_capacity(count);
        }

        pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            return self.as_manual_alloc_list().append_many_slots_as_array(count, self.get_alloc());
        }

        pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            return self.as_manual_alloc_list().append_many_slots_as_array_assume_capacity(count);
        }

        pub inline fn pop_or_null(self: *List) ?Elem {
            return self.as_manual_alloc_list().pop_or_null();
        }

        pub inline fn pop(self: *List) Elem {
            return self.as_manual_alloc_list().pop();
        }

        pub inline fn get_last(self: List) Elem {
            return self.to_manual_alloc_list().get_last();
        }

        pub inline fn get_last_or_null(self: List) ?Elem {
            return self.to_manual_alloc_list().get_last_or_null();
        }

        pub inline fn find_idx(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Idx {
            return self.to_manual_alloc_list().find_idx(Param, match_param, match_fn);
        }

        pub inline fn find_ptr(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*Elem {
            return self.to_manual_alloc_list().find_ptr(Param, match_param, match_fn);
        }

        pub inline fn find_const_ptr(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?*const Elem {
            return self.to_manual_alloc_list().find_const_ptr(Param, match_param, match_fn);
        }

        pub inline fn find_and_copy(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            return self.to_manual_alloc_list().find_and_copy(Param, match_param, match_fn);
        }

        pub inline fn find_and_remove(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) ?Elem {
            return self.to_manual_alloc_list().find_and_remove(Param, match_param, match_fn);
        }

        pub inline fn find_and_delete(self: List, comptime Param: type, match_param: Param, match_fn: *const fn (param: Param, item: *const Elem) bool) bool {
            return self.to_manual_alloc_list().find_and_delete(Param, match_param, match_fn);
        }

        pub inline fn find_exactly_n_item_indexes_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Idx) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_indexes_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*Elem) bool {
            return self.flex_slice(.mutable).find_exactly_n_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_const_item_pointers_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []*const Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_const_item_pointers_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub inline fn find_exactly_n_item_copies_from_n_params_in_order(self: List, comptime Param: type, params: []const Param, match_fn: *const fn (param: Param, item: *const Elem) bool, output_buf: []Elem) bool {
            return self.flex_slice(.immutable).find_exactly_n_item_copies_from_n_params_in_order(Param, params, match_fn, output_buf);
        }

        pub fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
            return self.as_manual_alloc_list().delete_ordered_indexes(indexes);
        }

        //TODO pub fn insert_slots_at_ordered_indexes()

        pub inline fn insertion_sort(self: *List) void {
            return self.flex_slice(.mutable).insertion_sort();
        }

        pub inline fn insertion_sort_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform(TX, transform_fn);
        }

        pub inline fn insertion_sort_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) void {
            return self.flex_slice(.mutable).insertion_sort_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_sorted();
        }

        pub inline fn is_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        pub inline fn is_reverse_sorted(self: *List) bool {
            return self.flex_slice(.immutable).is_reverse_sorted();
        }

        pub inline fn is_reverse_sorted_with_transform(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem) TX) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform(TX, transform_fn);
        }

        pub inline fn is_reverse_sorted_with_transform_and_user_data(self: *List, comptime TX: type, transform_fn: *const fn (item: Elem, userdata: ?*anyopaque) TX, userdata: ?*anyopaque) bool {
            return self.flex_slice(.immutable).is_reverse_sorted_with_transform_and_user_data(TX, transform_fn, userdata);
        }

        // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted(List, self, item, self.get_alloc());
        // }

        // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
        //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, self.get_alloc());
        // }

        // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
        //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
        // }

        // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
        // }

        // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
        //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
        // }

        // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
        //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
        // }

        //**************************
        // std.io.Writer interface *
        //**************************
        pub fn get_std_writer(self: *List) ManualList.StdWriter {
            return self.as_manual_alloc_list().get_std_writer(self.get_alloc());
        }

        pub fn get_std_writer_no_grow(self: *List) ManualList.StdWriterNoGrow {
            return self.as_manual_alloc_list().get_std_writer_no_grow();
        }
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
