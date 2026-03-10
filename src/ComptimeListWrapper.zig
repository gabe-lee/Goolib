//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const Cast = Root.Cast;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Common = Root.CommonTypes;
const Utils = Root.Utils;

const InterfaceSignature = Types.InterfaceSignature;
const ConstDeclDefinition = Types.ConstDeclDefinition;
const StructFieldDefinition = Types.StructFieldDefinition;
const NamedFuncDefinition = Types.NamedFuncDefinition;
const Growth = Common.GrowthModel;
const ErrorBehavior = Common.ErrorBehavior;
const AssertBehavior = Common.AssertBehavior;
const SourceLocation = std.builtin.SourceLocation;
const Alloc = Utils.Alloc;
const AllocClearOld = Alloc.ClearOldMode;
const AllocInitNew = Alloc.InitNew;

pub const ListInterfaceAdapter = struct {
    GROWTH: Growth = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
    ELEM: type,
    INDEX: type,
    ERROR_BEHAVIOR: ErrorBehavior = .ERRORS_ARE_UNREACHABLE,
    ASSERT_BEHAVIOR: AssertBehavior = .PANIC_IN_SAFE_MODES,
    PTR_FIELD: ?[]const u8 = null,
    LEN_FIELD: ?[]const u8 = null,
    CAP_FIELD: ?[]const u8 = null,
    SECURE_WIPE: bool = false,
    MEMSET_NEW_MEMORY: ?*const anyopaque = null,
    SPECIFIC_ALIGN: ?usize = null,
    OVERRIDE_LEN: bool = false,
    OVERRIDE_CAP: bool = false,
    OVERRIDE_PTR: bool = false,
    OVERRIDE_SLICE: bool = false,
    OVERRIDE_GET: bool = false,
    OVERRIDE_SET: bool = false,
    OVERRIDE_GET_PTR: bool = false,
    OVERRIDE_INIT_EMPTY: bool = false,
    OVERRIDE_INIT_CAPACITY: bool = false,
    OVERRIDE_FREE: bool = false,
    OVERRRIDE_SET_LEN: bool = false,
    OVERRRIDE_ENSURE_CAPACITY: bool = false,
    OVERRRIDE_MOVE: bool = false,
    OVERRRIDE_MOVE_RANGE: bool = false,
    OVERRRIDE_SHRINK_CAP: bool = false,
    OVERRIDE_APPEND_SLOTS_ASSUME_CAP_RETURN_FIRST_IDX: bool = false,
    OVERRIDE_INSERT_SLOTS_ASSUME_CAPACITY_RETURN_FIRST_INDEX: bool = false,
};

const ListDecls = [_]ConstDeclDefinition{
    ConstDeclDefinition{
        .name = "ADAPTER",
        .T = ListInterfaceAdapter,
        .needed_val = null,
    },
};

fn sig__self_idx__val(comptime SELF: type) type {
    return fn (SELF, usize) @field(SELF, "ADAPTER").ELEM;
}
fn sig__self_idx_val__void(comptime SELF: type) type {
    return fn (SELF, usize, @field(SELF, "ADAPTER").ELEM) void;
}

const ListFunctions = [_]NamedFuncDefinition{};

const ListFields = [_]StructFieldDefinition{};

const Interface = Types.InterfaceSignature{
    .interface_name = "List",
    .const_decls = &ListDecls,
    .functions = &ListFunctions,
    .struct_fields = &ListFields,
};

pub const StartMode = enum(u8) {
    OFFSET_FROM_LIST_BEGIN,
    OFFSET_FROM_LIST_END,
    OFFSET_FROM_RANGE_END,
};
pub const LimitMode = enum(u8) {
    OFFSET_FROM_LIST_BEGIN,
    OFFSET_FROM_LIST_END,
    OFFSET_FROM_RANGE_START,
};

pub fn ListWrapper(comptime CONCRETE: type) type {
    Interface.assert_type_fulfills(CONCRETE, @src());
    return struct {
        concrete: CONCRETE,

        const LIST = @This();
        const ADAPTER: ListInterfaceAdapter = @field(CONCRETE, "ADAPTER");
        const GROWTH: Growth = ADAPTER.GROWTH;
        const ELEM: type = ADAPTER.ELEM;
        const INDEX: type = ADAPTER.INDEX;
        const ERROR_MODE: ErrorBehavior = ADAPTER.ERROR_BEHAVIOR;
        const ERRORS = ERROR_MODE.does_error();
        const ASSERT_BEHAVIOR: AssertBehavior = ADAPTER.ASSERT_BEHAVIOR;
        const HAS_PTR_FIELD: bool = ADAPTER.PTR_FIELD != null;
        const PTR_FIELD: []const u8 = if (HAS_PTR_FIELD) ADAPTER.PTR_FIELD.? else "ptr";
        const HAS_LEN_FIELD: bool = ADAPTER.LEN_FIELD != null;
        const LEN_FIELD: []const u8 = if (HAS_LEN_FIELD) ADAPTER.LEN_FIELD.? else "len";
        const HAS_CAP_FIELD: bool = ADAPTER.CAP_FIELD != null;
        const CAP_FIELD: []const u8 = if (HAS_CAP_FIELD) ADAPTER.CAP_FIELD.? else "cap";
        const OVERRIDE_LEN: bool = ADAPTER.OVERRIDE_LEN;
        const OVERRIDE_CAP: bool = ADAPTER.OVERRIDE_CAP;
        const OVERRIDE_PTR: bool = ADAPTER.OVERRIDE_PTR;
        const OVERRIDE_SLICE: bool = ADAPTER.OVERRIDE_SLICE;
        const OVERRIDE_GET: bool = ADAPTER.OVERRIDE_GET;
        const OVERRIDE_SET: bool = ADAPTER.OVERRIDE_SET;
        const OVERRIDE_GET_PTR: bool = ADAPTER.OVERRIDE_GET_PTR;
        const OVERRIDE_INIT_EMPTY: bool = ADAPTER.OVERRIDE_INIT_EMPTY;
        const OVERRIDE_INIT_CAPACITY: bool = ADAPTER.OVERRIDE_INIT_CAPACITY;
        const OVERRIDE_FREE: bool = ADAPTER.OVERRIDE_FREE;
        const OVERRRIDE_SET_LEN: bool = ADAPTER.OVERRRIDE_SET_LEN;
        const OVERRRIDE_ENSURE_CAPACITY: bool = ADAPTER.OVERRRIDE_ENSURE_CAPACITY;
        const OVERRRIDE_MOVE: bool = ADAPTER.OVERRRIDE_MOVE;
        const OVERRRIDE_MOVE_RANGE: bool = ADAPTER.OVERRRIDE_MOVE_RANGE;
        const OVERRRIDE_SHRINK_CAP: bool = ADAPTER.OVERRRIDE_SHRINK_CAP;
        const OVERRIDE_APPEND_SLOTS_ASSUME_CAP_RETURN_FIRST_IDX: bool = ADAPTER.OVERRIDE_APPEND_SLOTS_ASSUME_CAP_RETURN_FIRST_IDX;
        const OVERRIDE_INSERT_SLOTS_ASSUME_CAPACITY_RETURN_FIRST_INDEX: bool = ADAPTER.OVERRIDE_INSERT_SLOTS_ASSUME_CAPACITY_RETURN_FIRST_INDEX;
        const ALIGN: usize = if (ADAPTER.SPECIFIC_ALIGN) |A| A else @alignOf(ELEM);
        const CLEAR_OLD: AllocClearOld = if (ADAPTER.SECURE_WIPE) AllocClearOld.FORCE_MEMSET_OLD_ZERO else AllocClearOld.DONT_MEMSET_OLD;
        const MEMSET_NEW: AllocInitNew(ELEM) = if (ADAPTER.MEMSET_NEW_MEMORY) |MEMSET_PTR| AllocInitNew(ELEM).force_memset_new_custom(@as(*const ELEM, @ptrCast(@alignCast(MEMSET_PTR))).*) else AllocInitNew(ELEM).dont_memset_new();
        const REALLOC_SETTINGS = Alloc.SmartAllocSettings(ELEM){
            .align_mode = .custom_align(ALIGN),
            .clear_old_mode = CLEAR_OLD,
            .copy_mode = .COPY_EXISTING_DATA,
            .grow_mode = GROWTH,
            .init_new_mode = MEMSET_NEW,
        };
        const REALLOC_SETTINGS_COMPTIME = Alloc.SmartAllocComptimeSettings(ELEM){
            .ALIGN_MODE = .custom_align(ALIGN),
            .CLEAR_OLD_MODE = CLEAR_OLD,
            .COPY_MODE = .COPY_EXISTING_DATA,
            .ERROR_MODE = ERROR_MODE,
            .GROW_MODE = GROWTH,
            .INIT_NEW_MODE = MEMSET_NEW,
        };
        /// A return value that will be an error union if the adapter `ERROR_BEHAVIOR` is set to return errors,
        /// or just a plain value otherwise
        pub fn PossibleError(comptime T: type) type {
            return if (ERRORS) !T else T;
        }
        const ASSERT = Assert.AssertHandler(ASSERT_BEHAVIOR);
        const assert_with_reason = ASSERT._with_reason;
        const assert_unreachable = ASSERT._unreachable;
        const assert_allocation_failure = ASSERT._allocation_failure;
        const assert_index_in_range = ASSERT._index_in_range;
        const assert_unreachable_err = ASSERT._unreachable_err;
        const assert_start_before_end = ASSERT._start_before_end;
        const SHOULD_ASSERT = ASSERT._should_assert();
        fn assert_has_all_fields(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_PTR_FIELD and @hasField(CONCRETE, PTR_FIELD), src, "missing pointer field `{s}`, cannot call this function", .{PTR_FIELD});
            comptime assert_with_reason(HAS_LEN_FIELD and @hasField(CONCRETE, LEN_FIELD), src, "missing length field `{s}`, cannot call this function", .{LEN_FIELD});
            comptime assert_with_reason(HAS_CAP_FIELD and @hasField(CONCRETE, CAP_FIELD), src, "missing capacity field `{s}`, cannot call this function", .{CAP_FIELD});
        }
        fn assert_has_ptr(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_PTR_FIELD and @hasField(CONCRETE, PTR_FIELD), src, "missing pointer field `{s}`, cannot call this function", .{PTR_FIELD});
        }
        fn assert_has_len(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_LEN_FIELD and @hasField(CONCRETE, LEN_FIELD), src, "missing length field `{s}`, cannot call this function", .{LEN_FIELD});
        }
        fn assert_has_cap(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_CAP_FIELD and @hasField(CONCRETE, CAP_FIELD), src, "missing capacity field `{s}`, cannot call this function", .{CAP_FIELD});
        }
        fn assert_has_len_cap(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_LEN_FIELD and @hasField(CONCRETE, LEN_FIELD), src, "missing length field `{s}`, cannot call this function", .{LEN_FIELD});
            comptime assert_with_reason(HAS_CAP_FIELD and @hasField(CONCRETE, CAP_FIELD), src, "missing capacity field `{s}`, cannot call this function", .{CAP_FIELD});
        }
        fn assert_has_ptr_cap(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_PTR_FIELD and @hasField(CONCRETE, PTR_FIELD), src, "missing pointer field `{s}`, cannot call this function", .{PTR_FIELD});
            comptime assert_with_reason(HAS_CAP_FIELD and @hasField(CONCRETE, CAP_FIELD), src, "missing capacity field `{s}`, cannot call this function", .{CAP_FIELD});
        }
        fn assert_has_len_ptr(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(HAS_PTR_FIELD and @hasField(CONCRETE, PTR_FIELD), src, "missing pointer field `{s}`, cannot call this function", .{PTR_FIELD});
            comptime assert_with_reason(HAS_LEN_FIELD and @hasField(CONCRETE, LEN_FIELD), src, "missing length field `{s}`, cannot call this function", .{LEN_FIELD});
        }

        fn smart_alloc(self: *LIST, new_cap: usize, alloc: Allocator) PossibleError(void) {
            assert_has_ptr_cap(@src());
            return Alloc.smart_alloc_ptr_ptrs(alloc, &@field(self.concrete, PTR_FIELD), &@field(self.concrete, CAP_FIELD), new_cap, REALLOC_SETTINGS, REALLOC_SETTINGS_COMPTIME);
        }

        /// Return the list length
        pub inline fn len(self: LIST) usize {
            if (OVERRIDE_LEN) {
                return @intCast(self.concrete.len());
            } else {
                assert_has_len(@src());
                return @field(self.concrete, LEN_FIELD);
            }
        }

        /// Return the list capacity
        pub inline fn cap(self: LIST) usize {
            if (OVERRIDE_CAP) {
                return @intCast(self.concrete.cap());
            } else {
                assert_has_cap(@src());
                return @field(self.concrete, CAP_FIELD);
            }
        }

        /// Return the list data pointer
        pub inline fn ptr(self: LIST) [*]ELEM {
            if (OVERRIDE_PTR) {
                return self.concrete.ptr();
            } else {
                assert_has_ptr(@src());
                return @field(self.concrete, PTR_FIELD);
            }
        }

        /// Create a new list with no capacity
        pub fn init_empty() LIST {
            if (OVERRIDE_INIT_EMPTY) {
                return LIST{ .concrete = CONCRETE.init_empty() };
            } else {
                comptime assert_has_all_fields(@src());
                var list: LIST = undefined;
                @field(list.concrete, PTR_FIELD) = Utils.invalid_ptr_many(ELEM);
                @field(list.concrete, LEN_FIELD) = 0;
                @field(list.concrete, CAP_FIELD) = 0;
                return list;
            }
        }

        /// Create a new list with the specified capacity
        pub fn init_capacity(init_cap: usize, alloc: Allocator) PossibleError(LIST) {
            if (OVERRIDE_INIT_CAPACITY) {
                return LIST{ .concrete = CONCRETE.init_capacity(@intCast(init_cap), alloc) };
            } else {
                comptime assert_has_all_fields(@src());
                var list: LIST = undefined;
                @field(list.concrete, PTR_FIELD) = Utils.invalid_ptr_many(ELEM);
                @field(list.concrete, LEN_FIELD) = 0;
                @field(list.concrete, CAP_FIELD) = 0;
                if (ERRORS) ( //
                    try list.smart_alloc(init_cap, alloc)) //
                else list.smart_alloc(init_cap, alloc);
                return list;
            }
        }

        /// Ensure enough capacity exists for specified number of elements
        pub fn ensure_capacity(self: *LIST, need_cap: usize, alloc: Allocator) PossibleError(void) {
            if (OVERRRIDE_ENSURE_CAPACITY) {
                self.concrete.ensure_capacity(@intCast(need_cap), alloc);
            } else {
                assert_has_ptr_cap(@src());
                if (self.cap() < need_cap) {
                    if (ERRORS) ( //
                        try self.smart_alloc(need_cap, alloc)) //
                    else self.smart_alloc(need_cap, alloc);
                }
            }
        }

        /// Ensure enough capacity exists to access specified index
        pub inline fn ensure_capacity_for_idx(self: *LIST, index: usize, alloc: Allocator) PossibleError(void) {
            return self.ensure_capacity(index + 1, alloc);
        }

        /// Set the list len
        pub fn set_len(self: *LIST, new_len: usize) void {
            if (OVERRRIDE_SET_LEN) {
                self.concrete.set_len(@intCast(new_len));
            } else {
                assert_has_len_cap(@src());
                assert_with_reason(new_len <= self.cap(), @src(), "cannot extend length past capacity, cap = {d}, new_len = {d}", .{ self.cap(), new_len });
                @field(self.concrete, LEN_FIELD) = @intCast(new_len);
            }
        }

        /// Return the full slice of the list
        pub inline fn slice(self: LIST) []ELEM {
            if (OVERRIDE_SLICE) {
                return self.concrete.slice();
            } else {
                return self.ptr()[0..self.len()];
            }
        }

        /// Return the value at the given index
        pub inline fn get(self: LIST, idx: usize) ELEM {
            if (OVERRIDE_GET) {
                return self.concrete.get(@intCast(idx));
            } else {
                assert_index_in_range(@src(), idx, self.len());
                return self.ptr()[idx];
            }
        }

        /// Set the value at the given index
        pub inline fn set(self: LIST, idx: usize, val: ELEM) void {
            if (OVERRIDE_GET) {
                self.concrete.set(@intCast(idx), val);
            } else {
                assert_index_in_range(@src(), idx, self.len());
                self.ptr()[idx] = val;
            }
        }

        /// Return a pointer to the value at a given index
        pub inline fn get_ptr(self: LIST, idx: usize) *ELEM {
            if (OVERRIDE_GET_PTR) {
                return self.concrete.get_ptr(@intCast(idx));
            } else {
                return &self.ptr()[idx];
            }
        }

        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub inline fn move(self: LIST, old_idx: usize, new_idx: usize) void {
            if (OVERRRIDE_MOVE) {
                self.concrete.move(@intCast(old_idx), @intCast(new_idx));
            } else {
                Utils.mem_move_one(self.slice(), old_idx, new_idx);
            }
        }

        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub inline fn move_range(self: LIST, old_start_idx: usize, old_end_excluded_idx: usize, new_start_idx: usize) void {
            if (OVERRRIDE_MOVE_RANGE) {
                self.concrete.move_range(@intCast(old_start_idx), @intCast(old_end_excluded_idx), @intCast(new_start_idx));
            } else {
                Utils.mem_move_many(self.slice(), old_start_idx, old_end_excluded_idx);
            }
        }
        /// Shrink capacity while reserving at most `reserve_at_most` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `reserve_at_most` is greater than or equal to the existing free space.
        pub fn shrink_cap_reserve_at_most(self: *LIST, reserve_at_most: usize, alloc: Allocator) PossibleError(void) {
            if (OVERRRIDE_SHRINK_CAP) {
                self.concrete.shrink_cap_reserve_at_most(@intCast(reserve_at_most), alloc);
            } else {
                const space: usize = @intCast(self.cap() - self.len());
                if (space <= reserve_at_most) return;
                const new_cap = self.len() + reserve_at_most;
                self.smart_alloc(new_cap, alloc);
            }
        }

        /// Append free slots to end of list and return the first new index
        ///
        /// Does not reallocate list
        pub fn append_slots_assume_capacity_return_first_idx(self: *LIST, count: usize) usize {
            if (OVERRIDE_APPEND_SLOTS_ASSUME_CAP_RETURN_FIRST_IDX) {
                return @intCast(self.concrete.append_slots_assume_capacity_return_first_idx(@intCast(count)));
            } else {
                const old_len = self.len();
                const new_len = old_len + count;
                self.set_len(new_len);
                return old_len;
            }
        }
        /// Append free slots to end of list
        ///
        /// Does not reallocate list
        pub inline fn append_slots_assume_capacity(self: *LIST, count: usize) void {
            _ = self.append_slots_assume_capacity_return_first_idx(count);
        }
        /// Append free slots to end of list and return the first new index
        pub inline fn append_slots_return_first_idx(self: *LIST, count: usize, alloc: Allocator) usize {
            self.ensure_capacity(self.len() + count, alloc);
            return self.append_slots_assume_capacity_return_first_idx(count);
        }
        /// Append free slots to end of list
        pub inline fn append_slots(self: *LIST, count: usize, alloc: Allocator) usize {
            self.ensure_capacity(self.len() + count, alloc);
            _ = self.append_slots_assume_capacity_return_first_idx(count);
        }

        /// Insert free slots at specific index (existing items at and after index are moved after the new one) and return the first new index
        ///
        /// Does not reallocate list
        pub fn insert_slots_assume_capacity_return_first_idx(self: *LIST, index: usize, count: usize) usize {
            if (index == self.len()) return self.append_slots_assume_capacity_return_first_idx(count);
            if (OVERRIDE_INSERT_SLOTS_ASSUME_CAPACITY_RETURN_FIRST_INDEX) {
                return @intCast(self.concrete.insert_slots_assume_capacity_return_first_idx(@intCast(index), @intCast(count)));
            } else {
                var old_len = self.len();
                const new_len = old_len + count;
                self.set_len(new_len);
                Utils.mem_insert(self.ptr(), &old_len, index, count);
                return index;
            }
        }
        /// Insert free slots at specific index (existing items at and after index are moved after the new one)
        ///
        /// Does not reallocate list
        pub inline fn insert_slots_assume_capacity(self: *LIST, index: usize, count: usize) void {
            _ = self.insert_slots_assume_capacity_return_first_idx(index, count);
        }
        /// Insert free slots at specific index (existing items at and after index are moved after the new one) and return the first new index
        pub inline fn insert_slots_return_first_idx(self: *LIST, index: usize, count: usize, alloc: Allocator) usize {
            self.ensure_capacity(self.len() + count, alloc);
            return self.insert_slots_assume_capacity_return_first_idx(index, count);
        }
        /// Insert free slots at specific index (existing items at and after index are moved after the new one)
        pub inline fn insert_slots(self: *LIST, index: usize, count: usize, alloc: Allocator) usize {
            self.ensure_capacity(self.len() + count, alloc);
            _ = self.insert_slots_assume_capacity_return_first_idx(index, count);
        }
    };
}
