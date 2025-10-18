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
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

const List = Root.IList_List.List;

pub fn MultiSortList(comptime T: type, comptime IDX: type, comptime EXTRA_SORT_NAMES: type) type {
    Assert.assert_with_reason(Types.type_is_enum(EXTRA_SORT_NAMES), @src(), "type `EXTRA_SORT_NAMES` must be an enum type, got `{s}`", .{@typeName(EXTRA_SORT_NAMES)});
    Assert.assert_with_reason(Types.enum_is_exhaustive(EXTRA_SORT_NAMES), @src(), "type `EXTRA_SORT_NAMES` must be an EXHAUSTIVE enum type", .{});
    Assert.assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(EXTRA_SORT_NAMES), @src(), "type `EXTRA_SORT_NAMES` must have all tag values satisfy the condition `0 <= tag_val < tag_count` with no gaps", .{});
    Assert.assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned integer type, got `{s}`", .{@typeName(IDX)});
    const EX_INFO = @typeInfo(EXTRA_SORT_NAMES).@"enum";
    const EX_COUNT = EX_INFO.fields.len;
    return struct {
        const Self = @This();

        primary_list: List(T) = .{},
        extra_sorts: [EX_COUNT]ExtraSort = @splat(ExtraSort{}),

        const IdxList = List(IDX);

        const ExtraSort = struct {
            idx_list: IdxList = .{},
            greater_than: *const fn (left_or_this: T, right_or_find: T) bool = noop_compare_false,
            equal: *const fn (left_or_this: T, right_or_find: T) bool = noop_compare_true,
            filter: *const fn (item: T) bool = noop_true,
        };

        pub const SortInit = struct {
            name: EXTRA_SORT_NAMES,
            greater_than: *const fn (left_or_this: T, right_or_find: T) bool,
            equal: *const fn (left_or_this: T, right_or_find: T) bool,
            filter: *const fn (item: T) bool = noop_true,
        };

        fn noop_compare_false(_: T, _: T) bool {
            return false;
        }
        fn noop_compare_true(_: T, _: T) bool {
            return true;
        }
        fn noop_true(_: T) bool {
            return true;
        }

        pub fn find_idx_for_value_using_sort(self: *Self, val: T, sort_name: EXTRA_SORT_NAMES) ?usize {
            const self_iface = self.primary_list.interface_no_alloc();
            const sort = self.extra_sorts[@intFromEnum(sort_name)];
            const sort_iface = sort.idx_list.interface_no_alloc();
            const location = self_iface.sorted_search_indirect(u32, sort_iface, val, sort.equal, sort.greater_than);
            if (location.found) {
                return location.idx;
            }
            return null;
        }

        const SET_REMOVE_FROM_SORT: comptime_int = 0b10;
        const SET_ADD_TO_SORT: comptime_int = 0b01;
        const SET_ALTER_SORT: comptime_int = 0b11;
        const SET_UNCHANGED_SORT: comptime_int = 0b00;

        pub fn set(self: *Self, idx: usize, val: T, alloc: Allocator) void {}

        pub fn init_empty(sort_inits: []const SortInit) Self {
            var s = Self{};
            for (sort_inits) |sinit| {
                var ex_sort: *ExtraSort = &s.extra_sorts[@intFromEnum(sinit.name)];
                ex_sort.equal = sinit.equal;
                ex_sort.greater_than = sinit.greater_than;
                ex_sort.filter = sinit.filter;
            }
            return s;
        }

        pub fn init_capacity(cap: usize, alloc: Allocator, sort_inits: []const SortInit) Self {
            const mem = alloc.alloc(T, cap) catch |err| Assert.assert_allocation_failure(@src(), T, cap, err);
            var s = Self{
                .ptr = mem.ptr,
                .cap = @intCast(mem.len),
                .len = 0,
            };
            for (sort_inits) |sinit| {
                var ex_sort: *ExtraSort = &s.extra_sorts[@intFromEnum(sinit.name)];
                ex_sort.equal = sinit.equal;
                ex_sort.greater_than = sinit.greater_than;
                ex_sort.filter = sinit.filter;
            }
            return s;
        }

        pub fn free(self: *Self, alloc: Allocator) void {
            alloc.free(self.primary_list.ptr[0..self.primary_list.cap]);
            self.primary_list.len = 0;
            self.primary_list.cap = 0;
        }

        pub fn interface(self: *Self, alloc: Allocator) ILIST {
            return ILIST{
                .alloc = alloc,
                .object = @ptrCast(self),
                .vtable = &ILIST_VTABLE,
            };
        }
        pub fn interface_no_alloc(self: *Self) ILIST {
            return ILIST{
                .alloc = DummyAlloc.allocator_shrink_only,
                .object = @ptrCast(self),
                .vtable = &ILIST_VTABLE,
            };
        }

        const ILIST = IList.IList(T);
        const ILIST_VTABLE = ILIST.VTable{
            .all_indexes_zero_to_len_valid = true,
            .consecutive_indexes_in_order = true,
            .ensure_free_doesnt_change_cap = false,
            .prefer_linear_ops = false,
            .always_invalid_idx = math.maxInt(usize),
            .idx_valid = impl_idx_valid,
            .range_valid = impl_range_valid,
            .split_range = impl_split_range,
            .range_len = impl_range_len,
            .len = impl_len,
            .cap = impl_cap,
            .get = impl_get,
            .set = impl_set,
            .move = impl_move,
            .move_range = impl_move_range,
            .first_idx = impl_first,
            .last_idx = impl_last,
            .next_idx = impl_next,
            .nth_next_idx = impl_nth_next,
            .prev_idx = impl_prev,
            .nth_prev_idx = impl_nth_prev,
            .try_ensure_free_slots = impl_ensure_free,
            .append_slots_assume_capacity = impl_append,
            .insert_slots_assume_capacity = impl_insert,
            .delete_range = impl_delete,
            .clear = impl_clear,
            .free = impl_free,
            .shrink_cap_reserve_at_most = impl_shrink_reserve,
        };

        fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return idx < self.primary_list.len;
        }
        fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            return range.first_idx <= range.last_idx and range.last_idx < self.primary_list.len;
        }
        fn impl_split_range(_: *anyopaque, range: IList.Range) usize {
            return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
        }
        fn impl_range_len(_: *anyopaque, range: IList.Range) usize {
            return range.consecutive_len();
        }
        fn impl_get(object: *anyopaque, idx: usize, _: Allocator) T {
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_idx_less_than_len(idx, Types.intcast(self.primary_list.len, usize), @src());
            return self.primary_list.ptr[idx];
        }
        fn impl_set(object: *anyopaque, idx: usize, val: T, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_idx_less_than_len(idx, Types.intcast(self.primary_list.len, usize), @src());
            const old_val = self.self.primary_list.ptr[idx];
            self.primary_list.ptr[idx] = val;
            for (self.extra_sorts) |*ex_sort| {
                const change = Utils.bools_to_switchable_integer(2, [2]bool{ ex_sort.filter(old_val), ex_sort.filter(val) });
                switch (change) {
                    SET_ADD_TO_SORT => {
                        const ex_sort_iface = ex_sort.idx_list.interface(alloc);
                        _ = self.interface_no_alloc().sorted_insert_indirect(IDX, ex_sort_iface, val, ex_sort.equal, ex_sort.greater_than);
                    },
                    SET_ALTER_SORT => {
                        if (ex_sort.equal(old_val, val)) continue;
                        const ex_sort_iface = ex_sort.idx_list.interface(alloc);
                        const self_iface = self.interface_no_alloc();
                        const old_location = self_iface.sorted_search_indirect(IDX, ex_sort_iface, old_val, ex_sort.equal, ex_sort.greater_than);
                        if (old_location.found) {
                            _ = self_iface.sorted_set_and_resort_indirect(IDX, ex_sort_iface, old_location.idx_idx, val, ex_sort.greater_than);
                        }
                    },
                    SET_REMOVE_FROM_SORT => {
                        const ex_sort_iface = ex_sort.idx_list.interface(alloc);
                        const self_iface = self.interface_no_alloc();
                        const old_location = self_iface.sorted_search_indirect(IDX, ex_sort_iface, old_val, ex_sort.equal, ex_sort.greater_than);
                        if (old_location.found) {
                            ex_sort_iface.delete(old_location.idx_idx);
                        }
                    },
                    SET_UNCHANGED_SORT => continue,
                    else => unreachable,
                }
            }
        }
        fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            if (old_idx == new_idx) return;
            Utils.slice_move_one(self.primary_list.ptr[0..self.primary_list.len], old_idx, new_idx);
            var smallest_shifted: usize = undefined;
            var largest_shifted: usize = undefined;
            var delta: isize = undefined;
            if (old_idx < new_idx) {
                smallest_shifted = old_idx + 1;
                largest_shifted = new_idx;
                delta = -1;
            } else {
                smallest_shifted = new_idx;
                largest_shifted = old_idx - 1;
                delta = 1;
            }
            for (self.extra_sorts) |ex_sort| {
                var ex_sort_iface = ex_sort.idx_list.interface_no_alloc();
                var idx_iter = ex_sort_iface.idx_iterator(.entire_list(ex_sort_iface), ex_sort_iface.first_idx());
                while (idx_iter.next()) |idx_idx| {
                    var idx = ex_sort_iface.get(idx_idx);
                    if (idx >= smallest_shifted and idx <= largest_shifted) {
                        idx = @intCast(Types.intcast(idx, isize) + delta);
                        ex_sort_iface.set(idx_idx, idx);
                    } else if (idx == old_idx) {
                        ex_sort_iface.set(idx_idx, new_idx);
                    }
                }
            }
        }
        //CHECKPOINT fix move range for indirect extra sorts
        fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize, _: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            Utils.slice_move_many(self.primary_list.ptr[0..self.primary_list.len], range.first_idx, range.last_idx, new_first_idx);
        }
        fn impl_first(object: *anyopaque) usize {
            _ = object;
            return 0;
        }
        fn impl_next(object: *anyopaque, idx: usize) usize {
            _ = object;
            return idx + 1;
        }
        fn impl_nth_next(object: *anyopaque, idx: usize, n: usize) usize {
            _ = object;
            return idx + n;
        }
        fn impl_last(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.primary_list.len -% 1);
        }
        fn impl_prev(object: *anyopaque, idx: usize) usize {
            _ = object;
            return idx -% 1;
        }
        fn impl_nth_prev(object: *anyopaque, idx: usize, n: usize) usize {
            _ = object;
            return idx -% n;
        }
        fn impl_len(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return @intCast(self.primary_list.len);
        }
        fn impl_ensure_free(object: *anyopaque, count: usize, alloc: Allocator) bool {
            const self: *Self = @ptrCast(@alignCast(object));
            const have = self.primary_list.cap - self.primary_list.len;
            if (have >= count) {
                return true;
            }
            const new_cap = (self.primary_list.len + count);
            const new_cap_with_extra = new_cap + (new_cap >> 2);
            if (alloc.remap(self.primary_list.ptr[0..self.primary_list.cap], new_cap_with_extra)) |new_mem| {
                self.primary_list.ptr = new_mem.ptr;
                self.primary_list.cap = @intCast(new_mem.len);
            } else {
                const new_mem = alloc.alloc(T, new_cap_with_extra) catch {
                    return false;
                };
                @memcpy(new_mem.ptr[0..self.primary_list.len], self.primary_list.ptr[0..self.primary_list.len]);
                alloc.free(self.primary_list.ptr[0..self.primary_list.cap]);
                self.primary_list.ptr = new_mem.ptr;
                self.primary_list.cap = @intCast(new_mem.len);
            }
            return true;
        }
        fn impl_append(object: *anyopaque, count: usize, alloc: Allocator) IList.Range {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            Assert.assert_with_reason(count <= self.primary_list.cap - self.primary_list.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.primary_list.len, self.primary_list.cap, self.primary_list.cap - self.primary_list.len, count, count });
            const first: usize = @intCast(self.primary_list.len);
            self.primary_list.len += @intCast(count);
            return IList.Range.new_range(first, @intCast(self.primary_list.len - 1));
        }
        fn impl_insert(object: *anyopaque, idx: usize, count: usize, alloc: Allocator) IList.Range {
            const self: *Self = @ptrCast(@alignCast(object));
            if (idx == self.primary_list.len) {
                return impl_append(object, count, alloc);
            }
            Assert.assert_with_reason(count <= self.primary_list.cap - self.primary_list.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.primary_list.len, self.primary_list.cap, self.primary_list.cap - self.primary_list.len, count, count });
            Utils.mem_insert(self.primary_list.ptr, &self.primary_list.len, idx, count);
            return IList.Range.new_range(idx, idx + count - 1);
        }
        fn impl_delete(object: *anyopaque, range: IList.Range, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            const rlen = range.consecutive_len();
            Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, range.first_idx, rlen);
        }
        fn impl_shrink_reserve(object: *anyopaque, reserve_at_most: usize, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            const space: usize = @intCast(self.primary_list.cap - self.primary_list.len);
            if (space <= reserve_at_most) return;
            const new_cap = Types.intcast(self.primary_list.len, usize) + reserve_at_most;
            if (alloc.remap(self.primary_list.ptr[0..self.primary_list.cap], new_cap)) |new_mem| {
                self.primary_list.ptr = new_mem.ptr;
                self.primary_list.cap = @intCast(new_mem.len);
            } else {
                const new_mem = alloc.alloc(T, new_cap) catch return;
                @memcpy(new_mem[0..self.primary_list.len], self.primary_list.ptr[0..self.primary_list.len]);
                alloc.free(self.primary_list.ptr[0..self.primary_list.cap]);
                self.primary_list.ptr = new_mem.ptr;
                self.primary_list.cap = @intCast(new_mem.len);
            }
        }
        fn impl_clear(object: *anyopaque, alloc: Allocator) void {
            _ = alloc;
            const self: *Self = @ptrCast(@alignCast(object));
            self.primary_list.len = 0;
        }
        fn impl_cap(object: *anyopaque) usize {
            const self: *Self = @ptrCast(@alignCast(object));
            return self.primary_list.cap;
        }
        fn impl_free(object: *anyopaque, alloc: Allocator) void {
            const self: *Self = @ptrCast(@alignCast(object));
            self.free(alloc);
        }
    };
}
