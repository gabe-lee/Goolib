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
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const IList = Root.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;
const ListError = IList.Concrete.ListError;
const Concrete = IList.Concrete;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub const Meta = @import("./ParamTable_Meta.zig");
pub const Calc = @import("./ParamTable_Calc.zig");

const ListCalcs = List(*const Calc.ParamCalc);
const ListMeta = List(Meta.Metadata);

const RingList = Root.IList.RingList;
const UpdateList = RingList(Meta.ParamId);

const ParamId = Meta.ParamId;
const ParamType = Meta.ParamType;
const Metadata = Meta.Metadata;

const ParamTable = Root.ParamTable;
const Table = ParamTable.Table;

pub fn PTPtr(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: *T = undefined,
        val_changed: bool = false,

        pub fn from_opaque(ptr: *anyopaque) Self {
            return Self{
                .ptr = @ptrCast(@alignCast(ptr)),
                .val_changed = false,
            };
        }
        pub fn to_opaque(self: Self) *anyopaque {
            return @ptrCast(self.ptr);
        }

        pub fn get(self: Self) T {
            return self.ptr.*;
        }

        pub fn set(self: Self, val: T) void {
            if (Types.type_has_equals(T)) {
                if (!Utils.equals_implicit(self.ptr.*, val)) {
                    self.val_changed = true;
                }
            } else {
                self.val_changed = true;
            }
            self.ptr.* = val;
        }
    };
}

pub const PTListOpaque = struct {
    ptr: *anyopaque = undefined,
    len: u32 = 0,
    cap: u32 = 0,
};

const T_NO_ALLOC = void;
const NO_ALLOC = void{};

pub fn PTList(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = undefined,
        len: u32 = 0,
        cap: u32 = 0,
        vals_changed: bool = false,
        table: *Table,

        pub fn to_opaque(self: Self) PTListOpaque {
            return PTListOpaque{
                .ptr = @ptrCast(self.ptr),
                .len = self.len,
                .cap = self.cap,
            };
        }

        pub fn from_opaque(list: PTListOpaque, table: *Table) Self {
            return Self{
                .ptr = @ptrCast(@alignCast(list.ptr)),
                .len = list.len,
                .cap = list.cap,
                .table = table,
            };
        }

        pub fn init_empty() Self {
            return Self{};
        }

        pub fn init_capacity(cap: usize, table: *Table) Self {
            const mem = table.alloc.alloc(T, cap) catch |err| Assert.assert_allocation_failure(@src(), T, cap, err);
            return Self{
                .ptr = mem.ptr,
                .cap = @intCast(mem.len),
                .len = 0,
            };
        }

        pub fn slice(self: Self) []T {
            return self.ptr[0..self.len];
        }

        //*** BEGIN PROTOTYPE ***
        const P_FUNCS = struct {
            fn p_get(self: *Self, idx: usize, _: T_NO_ALLOC) T {
                return self.ptr[idx];
            }
            fn p_get_ptr(self: *Self, idx: usize, _: T_NO_ALLOC) *T {
                return &self.ptr[idx];
            }
            fn p_set(self: *Self, idx: usize, val: T, _: T_NO_ALLOC) void {
                if (Types.type_has_equals(T)) {
                    if (!Utils.equals_implicit(self.ptr.*, val)) {
                        self.val_changed = true;
                    }
                } else {
                    self.val_changed = true;
                }
                self.ptr[idx] = val;
            }
            fn p_move(self: *Self, old_idx: usize, new_idx: usize, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                Utils.slice_move_one(self.ptr[0..self.len], old_idx, new_idx);
            }
            fn p_move_range(self: *Self, range: IList.Range, new_first_idx: usize, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                Utils.slice_move_many(self.ptr[0..self.len], range.first_idx, range.last_idx, new_first_idx);
            }
            fn p_try_ensure_free_slots(self: *Self, count: usize, _: T_NO_ALLOC) error{failed_to_grow_list}!void {
                const have = self.cap - self.len;
                if (have >= count) {
                    return;
                }
                const new_cap = (self.len + count);
                const new_cap_with_extra = new_cap + (new_cap >> 2);
                if (self.table.alloc.remap(self.ptr[0..self.cap], new_cap_with_extra)) |new_mem| {
                    self.ptr = new_mem.ptr;
                    self.cap = @intCast(new_mem.len);
                } else {
                    const new_mem = self.table.alloc.alloc(T, new_cap_with_extra) catch {
                        return error{failed_to_grow_list}.failed_to_grow_list;
                    };
                    @memcpy(new_mem.ptr[0..self.len], self.ptr[0..self.len]);
                    self.table.alloc.free(self.ptr[0..self.cap]);
                    self.ptr = new_mem.ptr;
                    self.cap = @intCast(new_mem.len);
                }
                return;
            }
            fn p_shrink_cap_reserve_at_most(self: *Self, reserve_at_most: usize, _: T_NO_ALLOC) void {
                const space: usize = @intCast(self.cap - self.len);
                if (space <= reserve_at_most) return;
                const new_cap = Types.intcast(self.len, usize) + reserve_at_most;
                if (self.table.alloc.remap(self.ptr[0..self.cap], new_cap)) |new_mem| {
                    self.ptr = new_mem.ptr;
                    self.cap = @intCast(new_mem.len);
                } else {
                    const new_mem = self.table.alloc.alloc(T, new_cap) catch return;
                    @memcpy(new_mem[0..self.len], self.ptr[0..self.len]);
                    self.table.alloc.free(self.ptr[0..self.cap]);
                    self.ptr = new_mem.ptr;
                    self.cap = @intCast(new_mem.len);
                }
            }
            fn p_append_slots_assume_capacity(self: *Self, count: usize, _: T_NO_ALLOC) IList.Range {
                self.vals_changed = true;
                Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
                const first: usize = @intCast(self.len);
                self.len += @intCast(count);
                return IList.Range.new_range(first, @intCast(self.len - 1));
            }
            fn p_insert_slots_assume_capacity(self: *Self, idx: usize, count: usize, _: T_NO_ALLOC) IList.Range {
                self.vals_changed = true;
                if (idx == self.len) {
                    return p_append_slots_assume_capacity(self, count, self.table.alloc);
                }
                Assert.assert_with_reason(count <= self.cap - self.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.len, self.cap, self.cap - self.len, count, count });
                Utils.mem_insert(self.ptr, &self.len, idx, count);
                return IList.Range.new_range(idx, idx + count - 1);
            }
            fn p_trim_len(self: *Self, trim_n: usize, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                self.len -= @intCast(trim_n);
            }
            fn p_delete(self: *Self, idx: usize, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                if (idx == self.len - 1) {
                    self.len -= 1;
                    return;
                }
                Utils.mem_remove(self.ptr, &self.len, idx, 1);
            }
            fn p_delete_range(self: *Self, range: IList.Range, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                const rlen = range.consecutive_len();
                if (range.last_idx == self.len - 1) {
                    self.len -= @intCast(rlen);
                    return;
                }
                Utils.mem_remove(self.ptr, &self.len, range.first_idx, rlen);
            }
            fn p_clear(self: *Self, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                self.len = 0;
            }
            fn p_free(self: *Self, _: T_NO_ALLOC) void {
                self.vals_changed = true;
                self.table.alloc.free(self.ptr[0..self.cap]);
                self.len = 0;
                self.cap = 0;
                self.ptr = undefined;
            }
        };
        const PFX = IList.Concrete.ConcreteTableValueFuncs(T, *Self, T_NO_ALLOC){
            .get = P_FUNCS.p_get,
            .get_ptr = P_FUNCS.p_get_ptr,
            .set = P_FUNCS.p_set,
            .move = P_FUNCS.p_move,
            .move_range = P_FUNCS.p_move_range,
            .try_ensure_free_slots = P_FUNCS.p_try_ensure_free_slots,
            .shrink_cap_reserve_at_most = P_FUNCS.p_shrink_cap_reserve_at_most,
            .append_slots_assume_capacity = P_FUNCS.p_append_slots_assume_capacity,
            .insert_slots_assume_capacity = P_FUNCS.p_insert_slots_assume_capacity,
            .trim_len = P_FUNCS.p_trim_len,
            .delete = P_FUNCS.p_delete,
            .delete_range = P_FUNCS.p_delete_range,
            .clear = P_FUNCS.p_clear,
            .free = P_FUNCS.p_free,
        };
        const P = IList.Concrete.CreateConcretePrototypeNaturalIndexes(T, *Self, T_NO_ALLOC, null, "ptr", null, "len", null, "cap", false, PFX);
        //*** END PROTOTYPE***

        /// Return the number of items in the list
        pub fn len_usize(self: *Self) usize {
            return P.len(self);
        }
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        pub fn trim_len(self: *Self, trim_n: usize, _: T_NO_ALLOC) void {
            return P.trim_len(self, trim_n, self.table.alloc);
        }
        /// Return the total number of items the list can hold
        /// without reallocation
        pub fn cap_usize(self: *Self) usize {
            return P.cap(self);
        }
        /// Return the first index in the list
        pub fn first_idx(self: *Self) usize {
            return P.first_idx(self);
        }
        /// Return the last valid index in the list
        pub fn last_idx(self: *Self) usize {
            return P.last_idx(self);
        }
        /// Return the index directly after the given index in the list
        pub fn next_idx(self: *Self, this_idx: usize) usize {
            return P.next_idx(self, this_idx);
        }
        /// Return the index `n` places after the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_next_idx(self: *Self, this_idx: usize, n: usize) usize {
            return P.nth_next_idx(self, this_idx, n);
        }
        /// Return the index directly before the given index in the list
        pub fn prev_idx(self: *Self, this_idx: usize) usize {
            return P.prev_idx(self, this_idx);
        }
        /// Return the index `n` places before the given index in the list,
        /// which may be 0 (returning the given index)
        pub fn nth_prev_idx(self: *Self, this_idx: usize, n: usize) usize {
            return P.nth_prev_idx(self, this_idx, n);
        }
        /// Return `true` if the index is valid for the current state
        /// of the list, `false` otherwise
        pub fn idx_valid(self: *Self, idx: usize) bool {
            return P.idx_valid(self, idx);
        }
        /// Return `true` if the range is valid for the current state
        /// of the list, `false` otherwise. The first index must
        /// come before or be equal to the last index, and all
        /// indexes in between must also be valid
        pub fn range_valid(self: *Self, range: Range) bool {
            return P.range_valid(self, range);
        }
        /// Return whether the given index falls within the given range,
        /// inclusive
        pub fn idx_in_range(self: *Self, range: Range, idx: usize) bool {
            return P.idx_in_range(self, range, idx);
        }
        /// Split a range roughly in half, returning an index
        /// as close to the true center point as possible.
        /// Implementations may choose not to return an index
        /// close to the actual middle of the range if
        /// finding that middle index is expensive
        pub fn split_range(self: *Self, range: Range) usize {
            return P.split_range(self, range);
        }
        /// Return the number of indexes included within a range,
        /// inclusive of the last index
        pub fn range_len(self: *Self, range: Range) usize {
            return P.range_len(self, range);
        }
        /// Return the value at the given index
        pub fn get(self: *Self, idx: usize) T {
            return P.get(self, idx, T_NO_ALLOC);
        }
        /// Return a pointer to the value at a given index
        pub fn get_ptr(self: *Self, idx: usize) *T {
            return P.get_ptr(self, idx, T_NO_ALLOC);
        }
        /// Set the value at the given index
        pub fn set(self: *Self, idx: usize, val: T) void {
            return P.set(self, idx, val, T_NO_ALLOC);
        }
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move(self: *Self, old_idx: usize, new_idx: usize) void {
            return P.move(self, old_idx, new_idx, T_NO_ALLOC);
        }
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move_range(self: *Self, range: Range, new_first_idx: usize) void {
            return P.move_range(self, range, new_first_idx, T_NO_ALLOC);
        }
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        pub fn try_ensure_free_slots(self: *Self, count: usize, _: NO_ALLOC) error{failed_to_grow_list}!void {
            return P.try_ensure_free_slots(self, count, NO_ALLOC);
        }
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        pub fn shrink_cap_reserve_at_most(self: *Self, reserve_at_most: usize, _: NO_ALLOC) void {
            return P.shrink_cap_reserve_at_most(self, reserve_at_most, NO_ALLOC);
        }
        /// Insert `n` value slots with undefined values at the given index,
        /// moving other items at or after that index to after the new ones.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn insert_slots_assume_capacity(self: *Self, idx: usize, count: usize) Range {
            return P.insert_slots_assume_capacity(self, idx, count, NO_ALLOC);
        }
        /// Append `n` value slots with undefined values at the end of the list.
        /// Assumes free space has already been ensured, though the allocator may
        /// be used for some auxilliary purpose
        pub fn append_slots_assume_capacity(self: *Self, count: usize) Range {
            return P.append_slots_assume_capacity(self, count, NO_ALLOC);
        }
        /// Delete one value at given index
        pub fn delete(self: *Self, idx: usize) void {
            return P.delete(self, idx, NO_ALLOC);
        }
        /// Delete many values within given range, inclusive
        pub fn delete_range(self: *Self, range: Range) void {
            return P.delete_range(self, range, NO_ALLOC);
        }
        /// Set list to an empty state, but retain existing capacity, if possible
        pub fn clear(self: *Self) void {
            return P.clear(self, NO_ALLOC);
        }
        /// Set list to an empty state and return memory to allocator
        pub fn free(self: *Self, _: NO_ALLOC) void {
            return P.free(self, NO_ALLOC);
        }
        pub fn is_empty(self: *Self) bool {
            return P.is_empty(self);
        }
        pub fn try_first_idx(self: *Self) ListError!usize {
            return P.try_first_idx(self);
        }
        pub fn try_last_idx(self: *Self) ListError!usize {
            return P.try_last_idx(self);
        }
        pub fn try_next_idx(self: *Self, this_idx: usize) ListError!usize {
            return P.try_next_idx(self, this_idx);
        }
        pub fn try_prev_idx(self: *Self, this_idx: usize) ListError!usize {
            return P.try_prev_idx(self, this_idx);
        }
        pub fn try_nth_next_idx(self: *Self, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_next_idx(self, this_idx, n);
        }
        pub fn try_nth_prev_idx(self: *Self, this_idx: usize, n: usize) ListError!usize {
            return P.try_nth_prev_idx(self, this_idx, n);
        }
        pub fn try_get(self: *Self, idx: usize) ListError!T {
            return P.try_get(self, idx, NO_ALLOC);
        }
        pub fn try_get_ptr(self: *Self, idx: usize) ListError!*T {
            return P.try_get_ptr(self, idx, NO_ALLOC);
        }
        pub fn try_set(self: *Self, idx: usize, val: T) ListError!void {
            return P.try_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_move(self: *Self, old_idx: usize, new_idx: usize) ListError!void {
            return P.try_move(self, old_idx, new_idx, NO_ALLOC);
        }
        pub fn try_move_range(self: *Self, range: Range, new_first_idx: usize) ListError!void {
            return P.try_move_range(self, range, new_first_idx, NO_ALLOC);
        }
        pub fn nth_idx(self: *Self, n: usize) usize {
            return P.nth_idx(self, n);
        }
        pub fn nth_idx_from_end(self: *Self, n: usize) usize {
            return P.nth_idx_from_end(self, n);
        }
        pub fn try_nth_idx(self: *Self, n: usize) ListError!usize {
            return P.try_nth_idx(self, n);
        }
        pub fn try_nth_idx_from_end(self: *Self, n: usize) ListError!usize {
            return P.try_nth_idx_from_end(self, n);
        }
        pub fn get_last(self: *Self) T {
            return P.get_last(self, NO_ALLOC);
        }
        pub fn try_get_last(self: *Self) ListError!T {
            return P.try_get_last(self, NO_ALLOC);
        }
        pub fn get_last_ptr(self: *Self) *T {
            return P.get_last_ptr(self, NO_ALLOC);
        }
        pub fn try_get_last_ptr(self: *Self) ListError!*T {
            return P.try_get_last_ptr(self, NO_ALLOC);
        }
        pub fn set_last(self: *Self, val: T) void {
            return P.set_last(self, val, NO_ALLOC);
        }
        pub fn try_set_last(self: *Self, val: T) ListError!void {
            return P.try_set_last(self, val, NO_ALLOC);
        }
        pub fn get_first(self: *Self) T {
            return P.get_first(self, NO_ALLOC);
        }
        pub fn try_get_first(self: *Self) ListError!T {
            return P.try_get_first(self, NO_ALLOC);
        }
        pub fn get_first_ptr(self: *Self) *T {
            return P.get_first_ptr(self, NO_ALLOC);
        }
        pub fn try_get_first_ptr(self: *Self) ListError!*T {
            return P.try_get_first_ptr(self, NO_ALLOC);
        }
        pub fn set_first(self: *Self, val: T) void {
            return P.set_first(self, val, NO_ALLOC);
        }
        pub fn try_set_first(self: *Self, val: T) ListError!void {
            return P.try_set_first(self, val, NO_ALLOC);
        }
        pub fn get_nth(self: *Self, n: usize) T {
            return P.get_nth(self, n, NO_ALLOC);
        }
        pub fn try_get_nth(self: *Self, n: usize) ListError!T {
            return P.try_get_nth(self, n, NO_ALLOC);
        }
        pub fn get_nth_ptr(self: *Self, n: usize) *T {
            return P.get_nth_ptr(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_ptr(self: *Self, n: usize) ListError!*T {
            return P.try_get_nth_ptr(self, n, NO_ALLOC);
        }
        pub fn set_nth(self: *Self, n: usize, val: T) void {
            return P.set_nth(self, n, val, NO_ALLOC);
        }
        pub fn try_set_nth(self: *Self, n: usize, val: T) ListError!void {
            return P.try_set_nth(self, n, val, NO_ALLOC);
        }
        pub fn get_nth_from_end(self: *Self, n: usize) T {
            return P.get_nth_from_end(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_from_end(self: *Self, n: usize) ListError!T {
            return P.try_get_nth_from_end(self, n, NO_ALLOC);
        }
        pub fn get_nth_ptr_from_end(self: *Self, n: usize) *T {
            return P.get_nth_ptr_from_end(self, n, NO_ALLOC);
        }
        pub fn try_get_nth_ptr_from_end(self: *Self, n: usize) ListError!*T {
            return P.try_get_nth_ptr_from_end(self, n, NO_ALLOC);
        }
        pub fn set_nth_from_end(self: *Self, n: usize, val: T) void {
            return P.set_nth_from_end(self, n, val, NO_ALLOC);
        }
        pub fn try_set_nth_from_end(self: *Self, n: usize, val: T) ListError!void {
            return P.try_set_nth_from_end(self, n, val, NO_ALLOC);
        }
        pub fn set_from(self: *Self, self_idx: usize, source: *Self, source_idx: usize) void {
            return P.set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
        }
        pub fn try_set_from(self: *Self, self_idx: usize, source: *Self, source_idx: usize) ListError!void {
            return P.try_set_from(self, self_idx, NO_ALLOC, source, source_idx, NO_ALLOC);
        }
        pub fn exchange(self: *Self, self_idx: usize, other: *Self, other_idx: usize) void {
            return P.exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
        }
        pub fn try_exchange(self: *Self, self_idx: usize, other: *Self, other_idx: usize) ListError!void {
            return P.try_exchange(self, self_idx, NO_ALLOC, other, other_idx, NO_ALLOC);
        }
        pub fn overwrite(self: *Self, source_idx: usize, dest_idx: usize) void {
            return P.overwrite(self, source_idx, dest_idx, NO_ALLOC);
        }
        pub fn try_overwrite(self: *Self, source_idx: usize, dest_idx: usize) ListError!void {
            return P.try_overwrite(self, source_idx, dest_idx, NO_ALLOC);
        }
        pub fn reverse(self: *Self, range: P.PartialRangeIter) void {
            return P.reverse(self, range, NO_ALLOC);
        }
        pub fn rotate(self: *Self, range: P.PartialRangeIter, delta: isize) void {
            return P.rotate(self, range, delta, NO_ALLOC);
        }
        pub fn fill(self: *Self, range: P.PartialRangeIter, val: T) usize {
            return P.fill(self, range, val, NO_ALLOC);
        }
        pub fn copy(source: P.RangeIter, dest: P.RangeIter) usize {
            return P.copy(source, dest);
        }
        pub fn copy_to(self: *Self, self_range: P.PartialRangeIter, dest: P.RangeIter) usize {
            return P.copy_to(self, self_range, dest);
        }
        pub fn is_sorted(self: *Self, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.is_sorted(self, range, greater_than, NO_ALLOC);
        }
        pub fn is_sorted_implicit(self: *Self, range: P.PartialRangeIter) bool {
            return P.is_sorted_implicit(self, range, NO_ALLOC);
        }
        pub fn insertion_sort(self: *Self, range: P.PartialRangeIter, greater_than: *const P.CompareFunc) bool {
            return P.insertion_sort(self, range, greater_than, NO_ALLOC);
        }
        pub fn insertion_sort_implicit(self: *Self, range: P.PartialRangeIter) bool {
            return P.insertion_sort_implicit(self, range, NO_ALLOC);
        }
        pub fn quicksort(self: *Self, range: P.PartialRangeIter, greater_than: *const P.CompareFunc, less_than: *const P.CompareFunc, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort(self, range, NO_ALLOC, greater_than, less_than, PARTITION_IDX, partition_stack);
        }
        pub fn quicksort_implicit(self: *Self, range: P.PartialRangeIter, comptime PARTITION_IDX: type, partition_stack: IList(PARTITION_IDX)) ListError!void {
            return P.quicksort_implicit(self, range, NO_ALLOC, PARTITION_IDX, partition_stack);
        }
        pub fn range_iterator(self: *Self, range: P.PartialRangeIter) P.RangeIter {
            return P.range_iterator(self, range);
        }
        pub fn for_each(
            self: *Self,
            range: P.PartialRangeIter,
            userdata: anytype,
            action: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.for_each(self, range, userdata, action, filter, filter_func);
        }
        pub fn filter_indexes(
            self: *Self,
            range: P.PartialRangeIter,
            userdata: anytype,
            filter_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool,
            comptime OUT_IDX: type,
            out_list: IList(OUT_IDX),
        ) usize {
            return P.filter_indexes(self, range, userdata, filter_func, OUT_IDX, out_list);
        }
        pub fn transform_values(
            self: *Self,
            range: P.PartialRangeIter,
            userdata: anytype,
            comptime OUT_TYPE: type,
            transform_func: *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            out_list: IList(OUT_TYPE),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) usize {
            return P.transform_values(self, range, userdata, OUT_TYPE, transform_func, out_list, filter, filter_func);
        }
        pub fn accumulate_result(
            self: *Self,
            range: P.PartialRangeIter,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: P.IterItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime filter: Concrete.FilterMode,
            filter_func: if (filter == .use_filter) *const fn (item: P.IterItem, userdata: @TypeOf(userdata)) bool else null,
        ) @TypeOf(initial_accumulation) {
            return P.accumulate_result(self, range, initial_accumulation, userdata, accumulate_func, filter, filter_func);
        }
        pub fn ensure_free_slots(self: *Self, count: usize, _: NO_ALLOC) void {
            return P.ensure_free_slots(self, count, NO_ALLOC);
        }
        pub fn append_slots(self: *Self, count: usize, _: NO_ALLOC) Range {
            return P.append_slots(self, count, NO_ALLOC);
        }
        pub fn try_append_slots(self: *Self, count: usize, _: NO_ALLOC) ListError!Range {
            return P.try_append_slots(self, count, NO_ALLOC);
        }
        pub fn append_zig_slice(self: *Self, _: NO_ALLOC, source: []const T) Range {
            return P.append_zig_slice(self, source, NO_ALLOC);
        }
        pub fn try_append_zig_slice(self: *Self, _: NO_ALLOC, source: []const T) ListError!Range {
            return P.try_append_zig_slice(self, source, NO_ALLOC);
        }
        pub fn append(self: *Self, val: T, _: NO_ALLOC) usize {
            return P.append(self, val, NO_ALLOC);
        }
        pub fn try_append(self: *Self, val: T, _: NO_ALLOC) ListError!usize {
            return P.try_append(self, val, NO_ALLOC);
        }
        pub fn append_many(self: *Self, _: NO_ALLOC, source: P.RangeIter) Range {
            return P.append_many(self, NO_ALLOC, source);
        }
        pub fn try_append_many(self: *Self, _: NO_ALLOC, source: P.RangeIter) ListError!Range {
            return P.try_append_many(self, NO_ALLOC, source);
        }
        pub fn insert_slots(self: *Self, idx: usize, count: usize, _: NO_ALLOC) Range {
            return P.insert_slots(self, idx, count, NO_ALLOC);
        }
        pub fn try_insert_slots(self: *Self, idx: usize, count: usize, _: NO_ALLOC) ListError!Range {
            return P.try_insert_slots(self, idx, count, NO_ALLOC);
        }
        pub fn insert_zig_slice(self: *Self, idx: usize, _: NO_ALLOC, source: []T) Range {
            return P.insert_zig_slice(self, idx, source, NO_ALLOC);
        }
        pub fn try_insert_zig_slice(self: *Self, idx: usize, _: NO_ALLOC, source: []T) ListError!Range {
            return P.try_insert_zig_slice(self, idx, source, NO_ALLOC);
        }
        pub fn insert(self: *Self, idx: usize, val: T, _: NO_ALLOC) usize {
            return P.insert(self, idx, val, NO_ALLOC);
        }
        pub fn try_insert(self: *Self, idx: usize, val: T, _: NO_ALLOC) ListError!usize {
            return P.try_insert(self, idx, val, NO_ALLOC);
        }
        pub fn insert_many(self: *Self, idx: usize, _: NO_ALLOC, source: P.RangeIter) Range {
            return P.insert_many(self, idx, NO_ALLOC, source);
        }
        pub fn try_insert_many(self: *Self, idx: usize, _: NO_ALLOC, source: P.RangeIter) ListError!Range {
            return P.try_insert_many(self, idx, NO_ALLOC, source);
        }
        pub fn try_delete_range(self: *Self, range: Range) ListError!void {
            return P.try_delete_range(self, range, T_NO_ALLOC);
        }
        pub fn delete_many(self: *Self, range: P.PartialRangeIter) void {
            return P.delete_many(self, range);
        }
        pub fn try_delete_many(self: *Self, range: P.PartialRangeIter) ListError!void {
            return P.try_delete_many(self, range);
        }
        pub fn try_delete(self: *Self, idx: usize) ListError!void {
            return P.try_delete(self, idx, T_NO_ALLOC);
        }
        pub fn swap_delete(self: *Self, idx: usize) void {
            return P.swap_delete(self, idx, T_NO_ALLOC);
        }
        pub fn try_swap_delete(self: *Self, idx: usize) ListError!void {
            return P.try_swap_delete(self, idx, T_NO_ALLOC);
        }
        pub fn swap_delete_many(self: *Self, range: P.PartialRangeIter) void {
            return P.swap_delete_many(self, range);
        }
        pub fn try_swap_delete_many(self: *Self, range: P.PartialRangeIter) ListError!void {
            return P.try_swap_delete_many(self, range);
        }
        pub fn remove_range(self: *Self, self_range: P.PartialRangeIter, dest: *Self, dest_alloc: Allocator) Range {
            return P.remove_range(self, self_range, dest, dest_alloc);
        }
        pub fn try_remove_range(self: *Self, self_range: P.PartialRangeIter, dest: *Self, dest_alloc: Allocator) ListError!Range {
            return P.try_remove_range(self, self_range, dest, dest_alloc);
        }
        pub fn remove(self: *Self, idx: usize) T {
            return P.remove(self, idx, T_NO_ALLOC);
        }
        pub fn try_remove(self: *Self, idx: usize) ListError!T {
            return P.try_remove(self, idx, T_NO_ALLOC);
        }
        pub fn swap_remove(self: *Self, idx: usize) T {
            return P.swap_remove(self, idx, T_NO_ALLOC);
        }
        pub fn try_swap_remove(self: *Self, idx: usize) ListError!T {
            return P.try_swap_remove(self, idx, T_NO_ALLOC);
        }
        pub fn pop(self: *Self) T {
            return P.pop(self, T_NO_ALLOC);
        }
        pub fn try_pop(self: *Self) ListError!T {
            return P.try_pop(self, T_NO_ALLOC);
        }
        pub fn pop_many(self: *Self, count: usize, dest: *Self, dest_alloc: Allocator) Range {
            return P.pop_many(self, count, T_NO_ALLOC, dest, dest_alloc);
        }
        pub fn try_pop_many(self: *Self, count: usize, dest: *Self, dest_alloc: Allocator) ListError!Range {
            return P.try_pop_many(self, count, T_NO_ALLOC, dest, dest_alloc);
        }
        pub fn sorted_insert(
            self: *Self,
            val: T,
            _: NO_ALLOC,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            return P.sorted_insert(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_implicit(self: *Self, val: T, _: NO_ALLOC) usize {
            return P.sorted_insert_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_insert_index(
            self: *Self,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) Concrete.InsertIndexResult {
            return P.sorted_insert_index(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_index_implicit(self: *Self, val: T) Concrete.InsertIndexResult {
            return P.sorted_insert_index_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_search(
            self: *Self,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) Concrete.SearchResult {
            return P.sorted_search(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_search_implicit(self: *Self, val: T) Concrete.SearchResult {
            return P.sorted_search_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_set_and_resort(self: *Self, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            return P.sorted_set_and_resort(self, idx, val, NO_ALLOC, greater_than_func);
        }
        pub fn sorted_set_and_resort_implicit(self: *Self, idx: usize, val: T) usize {
            return P.sorted_set_and_resort_implicit(self, idx, val, NO_ALLOC);
        }
        pub fn search(self: *Self, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) Concrete.SearchResult {
            return P.search(self, find_val, NO_ALLOC, equal_func);
        }
        pub fn search_implicit(self: *Self, find_val: anytype) Concrete.SearchResult {
            return P.search_implicit(self, find_val, NO_ALLOC);
        }
        pub fn add_get(self: *Self, idx: usize, val: anytype) T {
            return P.add_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_add_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_add_get(self, idx, val, NO_ALLOC);
        }
        pub fn add_set(self: *Self, idx: usize, val: anytype) void {
            return P.add_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_add_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_add_set(self, idx, val, NO_ALLOC);
        }
        pub fn subtract_get(self: *Self, idx: usize, val: anytype) T {
            return P.subtract_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_subtract_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_subtract_get(self, idx, val, NO_ALLOC);
        }
        pub fn subtract_set(self: *Self, idx: usize, val: anytype) void {
            return P.subtract_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_subtract_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_subtract_set(self, idx, val, NO_ALLOC);
        }
        pub fn multiply_get(self: *Self, idx: usize, val: anytype) T {
            return P.multiply_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_multiply_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_multiply_get(self, idx, val, NO_ALLOC);
        }
        pub fn multiply_set(self: *Self, idx: usize, val: anytype) void {
            return P.multiply_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_multiply_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_multiply_set(self, idx, val, NO_ALLOC);
        }
        pub fn divide_get(self: *Self, idx: usize, val: anytype) T {
            return P.divide_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_divide_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_divide_get(self, idx, val, NO_ALLOC);
        }
        pub fn divide_set(self: *Self, idx: usize, val: anytype) void {
            return P.divide_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_divide_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_divide_set(self, idx, val, NO_ALLOC);
        }
        pub fn modulo_get(self: *Self, idx: usize, val: anytype) T {
            return P.modulo_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_modulo_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_modulo_get(self, idx, val, NO_ALLOC);
        }
        pub fn modulo_set(self: *Self, idx: usize, val: anytype) void {
            return P.modulo_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_modulo_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_modulo_set(self, idx, val, NO_ALLOC);
        }
        pub fn mod_rem_get(self: *Self, idx: usize, val: anytype) T {
            return P.mod_rem_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_mod_rem_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_mod_rem_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_and_get(self: *Self, idx: usize, val: anytype) T {
            return P.bit_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_and_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_bit_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_and_set(self: *Self, idx: usize, val: anytype) void {
            return P.bit_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_and_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_bit_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_or_get(self: *Self, idx: usize, val: anytype) T {
            return P.bit_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_or_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_bit_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_or_set(self: *Self, idx: usize, val: anytype) void {
            return P.bit_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_or_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_bit_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_xor_get(self: *Self, idx: usize, val: anytype) T {
            return P.bit_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_xor_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_bit_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_xor_set(self: *Self, idx: usize, val: anytype) void {
            return P.bit_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_xor_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_bit_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_invert_get(self: *Self, idx: usize) T {
            return P.bit_invert_get(self, idx, NO_ALLOC);
        }
        pub fn try_bit_invert_get(self: *Self, idx: usize) ListError!T {
            return P.try_bit_invert_get(self, idx, NO_ALLOC);
        }
        pub fn bit_invert_set(self: *Self, idx: usize) void {
            return P.bit_invert_set(self, idx, NO_ALLOC);
        }
        pub fn try_bit_invert_set(self: *Self, idx: usize) ListError!void {
            return P.try_bit_invert_set(self, idx, NO_ALLOC);
        }
        pub fn bool_and_get(self: *Self, idx: usize, val: bool) T {
            return P.bool_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_and_get(self: *Self, idx: usize, val: bool) ListError!T {
            return P.try_bool_and_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_and_set(self: *Self, idx: usize, val: bool) void {
            return P.bool_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_and_set(self: *Self, idx: usize, val: bool) ListError!void {
            return P.try_bool_and_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_or_get(self: *Self, idx: usize, val: bool) T {
            return P.bool_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_or_get(self: *Self, idx: usize, val: bool) ListError!T {
            return P.try_bool_or_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_or_set(self: *Self, idx: usize, val: bool) void {
            return P.bool_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_or_set(self: *Self, idx: usize, val: bool) ListError!void {
            return P.try_bool_or_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_xor_get(self: *Self, idx: usize, val: bool) T {
            return P.bool_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_xor_get(self: *Self, idx: usize, val: bool) ListError!T {
            return P.try_bool_xor_get(self, idx, val, NO_ALLOC);
        }
        pub fn bool_xor_set(self: *Self, idx: usize, val: bool) void {
            return P.bool_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bool_xor_set(self: *Self, idx: usize, val: bool) ListError!void {
            return P.try_bool_xor_set(self, idx, val, NO_ALLOC);
        }
        pub fn bool_invert_get(self: *Self, idx: usize) T {
            return P.bool_invert_get(self, idx, NO_ALLOC);
        }
        pub fn try_bool_invert_get(self: *Self, idx: usize) ListError!T {
            return P.try_bool_invert_get(self, idx, NO_ALLOC);
        }
        pub fn bool_invert_set(self: *Self, idx: usize) void {
            return P.bool_invert_set(self, idx, NO_ALLOC);
        }
        pub fn try_bool_invert_set(self: *Self, idx: usize) ListError!void {
            return P.try_bool_invert_set(self, idx, NO_ALLOC);
        }
        pub fn bit_l_shift_get(self: *Self, idx: usize, val: anytype) T {
            return P.bit_l_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_l_shift_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_bit_l_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_l_shift_set(self: *Self, idx: usize, val: anytype) void {
            return P.bit_l_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_l_shift_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_bit_l_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn bit_r_shift_get(self: *Self, idx: usize, val: anytype) T {
            return P.bit_r_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_r_shift_get(self: *Self, idx: usize, val: anytype) ListError!T {
            return P.try_bit_r_shift_get(self, idx, val, NO_ALLOC);
        }
        pub fn bit_r_shift_set(self: *Self, idx: usize, val: anytype) void {
            return P.bit_r_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn try_bit_r_shift_set(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_bit_r_shift_set(self, idx, val, NO_ALLOC);
        }
        pub fn less_than_get(self: *Self, idx: usize, val: anytype) bool {
            return P.less_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_less_than_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn less_than_equal_get(self: *Self, idx: usize, val: anytype) bool {
            return P.less_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_less_than_equal_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_less_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn greater_than_get(self: *Self, idx: usize, val: anytype) bool {
            return P.greater_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_greater_than_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_get(self, idx, val, NO_ALLOC);
        }
        pub fn greater_than_equal_get(self: *Self, idx: usize, val: anytype) bool {
            return P.greater_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_greater_than_equal_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_greater_than_equal_get(self, idx, val, NO_ALLOC);
        }
        pub fn equals_get(self: *Self, idx: usize, val: anytype) bool {
            return P.equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_equals_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn not_equals_get(self: *Self, idx: usize, val: anytype) bool {
            return P.not_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn try_not_equals_get(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_not_equals_get(self, idx, val, NO_ALLOC);
        }
        pub fn get_min_in_range(self: *Self, range: P.PartialRangeIter) P.Item {
            return P.get_min_in_range(self, range);
        }
        pub fn try_get_min_in_range(self: *Self, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_min_in_range(self, range);
        }
        pub fn get_max_in_range(self: *Self, range: P.PartialRangeIter) P.Item {
            return P.get_max_in_range(self, range);
        }
        pub fn try_get_max_in_range(self: *Self, range: P.PartialRangeIter) ListError!P.Item {
            return P.try_get_max_in_range(self, range);
        }
        pub fn get_clamped(self: *Self, idx: usize, min: T, max: T) T {
            return P.get_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn try_get_clamped(self: *Self, idx: usize, min: T, max: T) ListError!T {
            return P.try_get_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn set_clamped(self: *Self, idx: usize, min: T, max: T) void {
            return P.set_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn try_set_clamped(self: *Self, idx: usize, min: T, max: T) ListError!void {
            return P.try_set_clamped(self, idx, min, max, NO_ALLOC);
        }
        pub fn set_report_change(self: *Self, idx: usize, val: T) bool {
            return P.set_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_report_change(self: *Self, idx: usize, val: T) bool {
            return P.try_set_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn get_unsafe_cast(self: *Self, idx: usize, comptime TT: type) TT {
            return P.get_unsafe_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn try_get_unsafe_cast(self: *Self, idx: usize, comptime TT: type) ListError!TT {
            return P.try_get_unsafe_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn get_unsafe_ptr_cast(self: *Self, idx: usize, comptime TT: type) *TT {
            return P.get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn try_get_unsafe_ptr_cast(self: *Self, idx: usize, comptime TT: type) ListError!*TT {
            return P.try_get_unsafe_ptr_cast(self, idx, TT, NO_ALLOC);
        }
        pub fn set_unsafe_cast(self: *Self, idx: usize, val: anytype) void {
            return P.set_unsafe_cast(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_unsafe_cast(self: *Self, idx: usize, val: anytype) ListError!void {
            return P.try_set_unsafe_cast(self, idx, val, NO_ALLOC);
        }
        pub fn set_unsafe_cast_report_change(self: *Self, idx: usize, val: anytype) bool {
            return P.set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
        }
        pub fn try_set_unsafe_cast_report_change(self: *Self, idx: usize, val: anytype) ListError!bool {
            return P.try_set_unsafe_cast_report_change(self, idx, val, NO_ALLOC);
        }
    };
}
