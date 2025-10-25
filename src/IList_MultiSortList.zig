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
const Flags = Root.Flags;

const List = Root.IList_List.List;

pub fn MultiSortList(comptime T: type, comptime UNINIT: T, comptime IDX: type, comptime SORT_NAMES: type) type {
    Assert.assert_with_reason(Types.type_is_enum(SORT_NAMES), @src(), "type `SORT_NAMES` must be an enum type, got `{s}`", .{@typeName(SORT_NAMES)});
    Assert.assert_with_reason(Types.enum_is_exhaustive(SORT_NAMES), @src(), "type `SORT_NAMES` must be an EXHAUSTIVE enum type", .{});
    Assert.assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(SORT_NAMES), @src(), "type `SORT_NAMES` must have all tag values satisfy the condition `0 <= tag_val < tag_count` with no gaps", .{});
    Assert.assert_with_reason(Types.type_is_unsigned_int(IDX), @src(), "type `IDX` must be an unsigned integer type, got `{s}`", .{@typeName(IDX)});
    const SORT_INFO = @typeInfo(SORT_NAMES).@"enum";
    Assert.assert_with_reason(SORT_INFO.fields.len > 0, @src(), "type `SORT_NAMES` must have at least one tag (with value 0, the primary sort name)", .{});
    const SORT_COUNT = SORT_INFO.fields.len;
    return struct {
        const Self = @This();

        primary_list: List(T) = .{},
        exact_equal: *const fn (a: T, b: T) bool = noop_compare_true,
        sort_lists: [SORT_COUNT]SortList = @splat(SortList{}),

        const IdxList = List(IDX);

        const SortList = struct {
            idx_list: IdxList = .{},
            greater_than: *const fn (left_or_this: T, right_or_find: T) bool = noop_compare_false,
            equal: *const fn (left_or_this: T, right_or_find: T) bool = noop_compare_true,
            filter: *const fn (item: T) bool = noop_true,
        };

        pub const SortInit = struct {
            name: SORT_NAMES,
            greater_than: *const fn (left_or_this: T, right_or_find: T) bool,
            equal: *const fn (left_or_this: T, right_or_find: T) bool,
            filter: *const fn (item: T) bool = noop_true,
        };

        pub const SortIdx = struct {
            sort_name: SORT_NAMES,
            sort_list_idx: usize,
            real_idx: usize,
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

        pub fn find_idx_for_value_using_sort(self: *Self, val: T, sort_name: SORT_NAMES) ?SortIdx {
            const self_iface = self.primary_list.interface_no_alloc();
            const sort = self.sort_lists[0..][@intFromEnum(sort_name)];
            const sort_iface = sort.idx_list.interface_no_alloc();
            const location = self_iface.sorted_search_indirect(u32, sort_iface, val, sort.equal, sort.greater_than);
            if (location.found) {
                return SortIdx{
                    .real_idx = location.idx,
                    .sort_list_idx = location.idx_idx,
                    .sort_name = sort_name,
                };
            }
            return null;
        }

        pub fn next_idx_indirect(self: *Self, curr_sort_idx: SortIdx) ?SortIdx {
            const sort = self.sort_lists[0..][@intFromEnum(curr_sort_idx.sort_name)];
            const next = curr_sort_idx.sort_list_idx + 1;
            if (next >= self.sort_lists[0..].len) return null;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[next]),
                .sort_list_idx = next,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn nth_next_idx_indirect(self: *Self, curr_sort_idx: SortIdx, n: usize) ?SortIdx {
            const sort = self.sort_lists[0..][@intFromEnum(curr_sort_idx.sort_name)];
            const next = curr_sort_idx.sort_list_idx + n;
            if (next >= self.sort_lists[0..].len) return null;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[next]),
                .sort_list_idx = next,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn prev_idx_indirect(self: *Self, curr_sort_idx: SortIdx) ?SortIdx {
            const sort = self.sort_lists[0..][@intFromEnum(curr_sort_idx.sort_name)];
            if (curr_sort_idx.sort_list_idx < 1) return null;
            const prev = curr_sort_idx.sort_list_idx - 1;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[prev]),
                .sort_list_idx = prev,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn nth_prev_idx_indirect(self: *Self, curr_sort_idx: SortIdx, n: usize) ?SortIdx {
            const sort = self.sort_lists[0..][@intFromEnum(curr_sort_idx.sort_name)];
            if (curr_sort_idx.sort_list_idx < n) return null;
            const prev = curr_sort_idx.sort_list_idx - n;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[prev]),
                .sort_list_idx = prev,
                .sort_name = curr_sort_idx.sort_name,
            };
        }

        const SET_REMOVE_FROM_SORT: comptime_int = 0b10;
        const SET_ADD_TO_SORT: comptime_int = 0b01;
        const SET_ALTER_SORT: comptime_int = 0b11;
        const SET_UNCHANGED_SORT: comptime_int = 0b00;

        pub fn init_empty(exact_equal: *const fn (a: T, b: T) bool, sort_inits: []const SortInit) Self {
            var s = Self{
                .primary_list = List(T).init_empty(),
                .exact_equal = exact_equal,
            };
            for (sort_inits) |sinit| {
                const idx = @intFromEnum(sinit.name);
                var ex_sort: *SortList = &s.sort_lists[idx];
                ex_sort.idx_list = List(IDX).init_empty();
                ex_sort.equal = sinit.equal;
                ex_sort.greater_than = sinit.greater_than;
                ex_sort.filter = sinit.filter;
            }
            return s;
        }

        pub fn init_capacity(cap: usize, sort_cap: usize, alloc: Allocator, exact_equal: *const fn (a: T, b: T) bool, sort_inits: []const SortInit) Self {
            var s = Self{
                .primary_list = List(T).init_capacity(cap, alloc),
                .exact_equal = exact_equal,
            };
            for (sort_inits) |sinit| {
                const idx = @intFromEnum(sinit.name);
                var ex_sort: *SortList = &s.sort_lists[idx];
                ex_sort.idx_list = List(IDX).init_capacity(sort_cap, alloc);
                ex_sort.equal = sinit.equal;
                ex_sort.greater_than = sinit.greater_than;
                ex_sort.filter = sinit.filter;
            }
            return s;
        }

        pub fn free(self: *Self, alloc: Allocator) void {
            self.primary_list.free(alloc);
            for (self.sort_lists[0..]) |*ex_sort| {
                ex_sort.idx_list.free(alloc);
            }
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
            .idx_in_range = impl.impl_idx_in_range,
            .idx_valid = impl.impl_idx_valid,
            .range_valid = impl.impl_range_valid,
            .split_range = impl.impl_split_range,
            .range_len = impl.impl_range_len,
            .len = impl.impl_len,
            .cap = impl.impl_cap,
            .get = impl.impl_get,
            .set = impl.impl_set,
            .move = impl.impl_move,
            .move_range = impl.impl_move_range,
            .first_idx = impl.impl_first,
            .last_idx = impl.impl_last,
            .next_idx = impl.impl_next,
            .nth_next_idx = impl.impl_nth_next,
            .prev_idx = impl.impl_prev,
            .nth_prev_idx = impl.impl_nth_prev,
            .try_ensure_free_slots = impl.impl_ensure_free,
            .append_slots_assume_capacity = impl.impl_append,
            .insert_slots_assume_capacity = impl.impl_insert,
            .delete_range = impl.impl_delete,
            .clear = impl.impl_clear,
            .free = impl.impl_free,
            .shrink_cap_reserve_at_most = impl.impl_shrink_reserve,
        };

        fn split_range(first: usize, last: usize) usize {
            return ((last - first) >> 1) + first;
        }

        const InsertIdx = struct {
            idx: usize = 0,
            idx_idx: usize = 0,
            append_idx_idx: bool = false,
        };

        const MatchIdx = struct {
            idx: usize = 0,
            idx_idx: usize = 0,
            found: bool = true,
        };

        fn true_greater_than(sort: *SortList, a_val: T, a_idx: usize, b_val: T, b_idx: usize) bool {
            if (sort.greater_than(a_val, b_val)) return true;
            if (sort.equal(a_val, b_val)) return a_idx > b_idx;
            return false;
        }

        const MatchDirection = enum(u8) {
            SPLIT_LEFT,
            MATCH,
            SPLIT_RIGHT,
        };

        const InsertDirection = enum(u8) {
            SPLIT_LEFT,
            INSERT_HERE,
            APPEND_TO_END,
            SPLIT_RIGHT,
        };

        const SortListReport = struct {
            smallest: usize = 0,
            largest: usize = 0,
            at_least_one: bool = false,

            fn add_idx(self: *SortListReport, idx: usize) void {
                if (self.at_least_one) {
                    @branchHint(.likely);
                    self.largest = idx;
                } else {
                    @branchHint(.unlikely);
                    self.at_least_one = true;
                    self.smallest = idx;
                    self.largest = idx;
                }
            }
        };
        const SortListReportWithInsertRange = struct {
            smallest: usize = 0,
            largest: usize = 0,
            at_least_one: bool = false,
            smallest_insert: usize = 0,
            largest_insert: usize = 0,
            has_insert: bool = false,

            fn add_changed_idx(self: *SortListReportWithInsertRange, idx: usize) void {
                if (self.at_least_one) {
                    @branchHint(.likely);
                    self.largest = idx;
                } else {
                    @branchHint(.unlikely);
                    self.at_least_one = true;
                    self.smallest = idx;
                    self.largest = idx;
                }
            }

            fn add_insert_range(self: *SortListReportWithInsertRange, range: IList.Range) void {
                self.has_insert = true;
                self.smallest_insert = range.first_idx;
                self.largest_insert = range.last_idx;
            }
        };

        fn resort_up_many(self: *Self, sort: *SortList, idx_idx: usize) bool {
            var this_idx_idx = idx_idx;
            const this_idx = sort.idx_list.ptr[idx_idx];
            var this_val = self.primary_list.ptr[this_idx];
            var next_idx_idx = idx_idx + 1;
            var next_idx: usize = undefined;
            var next_val: T = undefined;
            var moved: bool = false;
            while (next_idx_idx < sort.idx_list.len) {
                next_idx = @intCast(sort.idx_list.ptr[next_idx_idx]);
                next_val = self.primary_list.ptr[next_idx];
                if (sort.greater_than(next_val, this_val) or next_idx >= this_idx) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx);
                this_val = next_val;
                this_idx_idx = next_idx_idx;
                next_idx_idx += 1;
                moved = true;
            }
            sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
            return moved;
        }
        fn resort_up_one(self: *Self, sort: *SortList, idx_idx: usize) bool {
            const this_idx_idx = idx_idx;
            const this_idx = sort.idx_list.ptr[idx_idx];
            const this_val = self.primary_list.ptr[this_idx];
            const next_idx_idx = idx_idx + 1;
            if (next_idx_idx >= sort.idx_list.len) return false;
            const next_idx = sort.idx_list.ptr[next_idx_idx];
            const next_val: T = self.primary_list.ptr[next_idx];
            if (sort.greater_than(next_val, this_val) or next_idx >= this_idx) return false;
            sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx);
            sort.idx_list.ptr[next_idx_idx] = @intCast(this_idx);
            return true;
        }

        fn resort_down_many(self: *Self, sort: *SortList, idx_idx: usize) bool {
            var this_idx_idx = idx_idx;
            const this_idx = sort.idx_list.ptr[idx_idx];
            var this_val = self.primary_list.ptr[this_idx];
            var prev_idx_idx = idx_idx;
            var prev_idx: usize = undefined;
            var prev_val: T = undefined;
            var moved: bool = false;
            while (this_idx_idx > 0) {
                prev_idx_idx -= 1;
                prev_idx = @intCast(sort.idx_list.ptr[prev_idx_idx]);
                prev_val = self.primary_list.ptr[prev_idx];
                if (sort.greater_than(this_val, prev_val) or prev_idx <= this_idx) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx);
                this_val = prev_val;
                this_idx_idx = prev_idx_idx;
                moved = true;
            }
            sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
            return moved;
        }

        fn resort_down_one(self: *Self, sort: *SortList, this_idx_idx: usize) bool {
            if (this_idx_idx == 0) return false;
            const this_idx = sort.idx_list.ptr[this_idx_idx];
            const this_val = self.primary_list.ptr[this_idx];
            const prev_idx_idx = this_idx_idx - 1;
            const prev_idx = sort.idx_list.ptr[prev_idx_idx];
            const prev_val: T = self.primary_list.ptr[prev_idx];
            if (sort.greater_than(this_val, prev_val) or prev_idx <= this_idx) return false;
            sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx);
            sort.idx_list.ptr[prev_idx_idx] = @intCast(this_idx);
            return true;
        }

        fn move_one_indirect_indexes(sort: *SortList, one_idx: usize, delta: usize, smallest_other_idx: usize, largest_other_idx: usize, dir: ShiftDirection) SortListReport {
            var result = SortListReport{};
            for (sort.idx_list.ptr[0..sort.idx_list.len], 0..) |idx, idx_idx| {
                if (smallest_other_idx <= idx and idx <= largest_other_idx) {
                    if (result.at_least_one) {
                        @branchHint(.likely);
                        result.largest = idx_idx;
                    } else {
                        @branchHint(.unlikely);
                        result.at_least_one = true;
                        result.smallest = idx_idx;
                        result.largest = idx_idx;
                    }
                    switch (dir) {
                        .this_down__other_up => {
                            sort.idx_list.ptr[idx_idx] += 1;
                        },
                        .this_up__other_down => {
                            sort.idx_list.ptr[idx_idx] -= 1;
                        },
                    }
                } else if (idx == one_idx) {
                    if (result.at_least_one) {
                        @branchHint(.likely);
                        result.largest = idx_idx;
                    } else {
                        @branchHint(.unlikely);
                        result.at_least_one = true;
                        result.smallest = idx_idx;
                        result.largest = idx_idx;
                    }
                    switch (dir) {
                        .this_down__other_up => {
                            sort.idx_list.ptr[idx_idx] -= @intCast(delta);
                        },
                        .this_up__other_down => {
                            sort.idx_list.ptr[idx_idx] += @intCast(delta);
                        },
                    }
                }
            }
            return result;
        }

        fn move_range_indirect_indexes(sort: *SortList, smallest_up_idx: usize, largest_up_idx: usize, delta_up: usize, smallest_down_idx: usize, largest_down_idx: usize, delta_down: usize) SortListReport {
            var result = SortListReport{};
            // std.debug.print("smallest_up_idx: {d}, largest_up_idx: {d}, delta_up: {d}\nsmallest_down_idx: {d}, largest_down_idx: {d}, delta_down:{d}\n", .{ smallest_up_idx, largest_up_idx, delta_up, smallest_down_idx, largest_down_idx, delta_down }); //DEBUG
            for (sort.idx_list.ptr[0..sort.idx_list.len], 0..) |idx, idx_idx| {
                if (smallest_up_idx <= idx and idx <= largest_up_idx) {
                    result.add_idx(idx_idx);
                    sort.idx_list.ptr[idx_idx] += @intCast(delta_up);
                } else if (smallest_down_idx <= idx and idx <= largest_down_idx) {
                    result.add_idx(idx_idx);
                    sort.idx_list.ptr[idx_idx] -= @intCast(delta_down);
                }
            }
            return result;
        }

        // const MoveOneIndirectResortActionData = struct {
        //     smallest_other_idx: usize,
        //     largest_other_idx: usize,
        //     moved_idx: usize,
        //     dir: ShiftDirection,
        //     list: *Self,
        //     sort: *SortList,
        // };

        // fn move_one_indirect_resort_action(_: []IDX, idx: IDX, idx_idx: usize, data: MoveOneIndirectResortActionData) Utils.ForEachControl {
        //     var control = Utils.ForEachControl{};
        //     if (data.smallest_other_idx <= idx and idx <= data.largest_other_idx) {
        //         switch (data.dir) {
        //             .this_down__other_up => {
        //                 if (data.list.resort_up_one(data.sort, idx_idx)) {
        //                     control.index_delta = 0;
        //                 }
        //             },
        //             .this_up__other_down => {
        //                 data.list.resort_down_one(data.sort, idx_idx);
        //             },
        //         }
        //     } else if (idx == data.moved_idx) {
        //         switch (data.dir) {
        //             .this_down__other_up => {
        //                 data.list.resort_down_many(data.sort, idx_idx);
        //             },
        //             .this_up__other_down => {
        //                 if (data.list.resort_up_many(data.sort, idx_idx)) {
        //                     control.index_delta = 0;
        //                 }
        //             },
        //         }
        //     }
        //     return control;
        // }

        fn move_one_indirect_resort(self: *Self, sort: *SortList, list_report: SortListReport, moved_idx: usize, smallest_other_idx: usize, largest_other_idx: usize, dir: ShiftDirection) void {
            var idx_idx: usize = list_report.smallest;
            var incr: usize = 1;
            while (idx_idx < list_report.largest) {
                const idx = sort.idx_list.ptr[idx_idx];
                incr = 1;
                if (smallest_other_idx <= idx and idx <= largest_other_idx) {
                    switch (dir) {
                        .this_down__other_up => {
                            if (self.resort_up_one(sort, idx_idx)) {
                                incr = 0;
                            }
                        },
                        .this_up__other_down => {
                            _ = self.resort_down_one(sort, idx_idx);
                        },
                    }
                } else if (idx == moved_idx) {
                    switch (dir) {
                        .this_down__other_up => {
                            _ = self.resort_down_many(sort, idx_idx);
                        },
                        .this_up__other_down => {
                            if (self.resort_up_many(sort, idx_idx)) {
                                incr = 0;
                            }
                        },
                    }
                }
                idx_idx += incr;
            }

            // if (list_report.at_least_one) {
            //     const data = MoveOneIndirectResortActionData{
            //         .dir = dir,
            //         .largest_other_idx = largest_other_idx,
            //         .smallest_other_idx = smallest_other_idx,
            //         .moved_idx = moved_idx,
            //         .list = self,
            //         .sort = sort,
            //     };
            //     Utils.for_each_special(IDX, sort.idx_list.slice(), list_report.smallest, list_report.largest, data, move_one_indirect_resort_action);
            // }
        }

        fn move_range_indirect_resort(self: *Self, sort: *SortList, list_report: SortListReport, smallest_up_idx: usize, largest_up_idx: usize, smallest_down_idx: usize, largest_down_idx: usize) void {
            var idx_idx: usize = list_report.smallest;
            var incr: usize = 1;
            while (idx_idx < list_report.largest) {
                const idx = sort.idx_list.ptr[idx_idx];
                incr = 1;
                if (smallest_down_idx <= idx and idx <= largest_down_idx) {
                    _ = self.resort_down_many(sort, idx_idx);
                } else if (smallest_up_idx <= idx and idx <= largest_up_idx) {
                    if (self.resort_up_many(sort, idx_idx)) {
                        incr = 0;
                    }
                }
                idx_idx += incr;
            }
        }

        // fn fix_indirect_index_grew_by_n(self: *Self, sort: *SortList, this_val: T, old_idx: usize, grow: usize, idx_idx: usize) void {
        //     const this_idx = old_idx + grow;
        //     var this_idx_idx = idx_idx;
        //     var next_idx_idx = idx_idx + 1;
        //     var next_idx: usize = undefined;
        //     var next_val: T = undefined;
        //     while (next_idx_idx < sort.idx_list.len) {
        //         next_idx = @intCast(sort.idx_list.ptr[next_idx_idx]);
        //         next_val = self.primary_list.ptr[next_idx];
        //         if (sort.greater_than(next_val, this_val) or next_idx >= this_idx) break;
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx);
        //         this_idx_idx = next_idx_idx;
        //         next_idx_idx += 1;
        //     }
        //     sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
        //     debug_assert_all_in_order(self, @src()); //DEBUG
        // }
        // fn fix_indirect_index_grew_by_1(self: *Self, sort: *SortList, this_val: T, old_idx: usize, idx_idx: usize) void {
        //     const this_idx = old_idx + 1;
        //     const this_idx_idx = idx_idx;
        //     const next_idx_idx = idx_idx + 1;
        //     if (next_idx_idx >= sort.idx_list.len) {
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
        //         return;
        //     }
        //     const next_idx: usize = @intCast(sort.idx_list.ptr[next_idx_idx]);
        //     const next_val: T = self.primary_list.ptr[next_idx];
        //     if (sort.greater_than(next_val, this_val) or next_idx >= this_idx) {
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
        //         return;
        //     }
        //     sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx);
        //     sort.idx_list.ptr[next_idx_idx] = @intCast(this_idx);
        //     debug_assert_all_in_order(self, @src()); //DEBUG
        // }
        // fn fix_indirect_index_shrunk_by_n(self: *Self, sort: *SortList, this_val: T, old_idx: usize, shrink: usize, idx_idx: usize) void {
        //     const this_idx = old_idx - shrink;
        //     var this_idx_idx = idx_idx;
        //     var prev_idx_idx = idx_idx;
        //     var prev_idx: usize = undefined;
        //     var prev_val: T = undefined;
        //     while (this_idx_idx > 0) {
        //         prev_idx_idx -= 1;
        //         prev_idx = @intCast(sort.idx_list.ptr[prev_idx_idx]);
        //         prev_val = self.primary_list.ptr[prev_idx];
        //         if (sort.greater_than(this_val, prev_val)) break;
        //         if (prev_idx <= this_idx) break;
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx);
        //         this_idx_idx = prev_idx_idx;
        //     }
        //     sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
        //     debug_assert_all_in_order(self, @src()); //DEBUG
        // }
        // fn fix_indirect_index_shrunk_by_1(self: *Self, sort: *SortList, this_val: T, old_idx: usize, idx_idx: usize) void {
        //     const new_idx = old_idx - 1;
        //     const this_idx_idx = idx_idx;
        //     if (this_idx_idx == 0) {
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(new_idx);
        //         return;
        //     }
        //     const prev_idx_idx = idx_idx - 1;
        //     const prev_idx: usize = @intCast(sort.idx_list.ptr[prev_idx_idx]);
        //     const prev_val: T = self.primary_list.ptr[prev_idx];
        //     if (sort.greater_than(this_val, prev_val) or prev_idx <= new_idx) {
        //         sort.idx_list.ptr[this_idx_idx] = @intCast(new_idx);
        //         return;
        //     }
        //     sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx);
        //     sort.idx_list.ptr[prev_idx_idx] = @intCast(new_idx);
        //     debug_assert_all_in_order(self, @src()); //DEBUG
        // }
        fn fix_indirect_value_changed(self: *Self, sort: *SortList, new_val: T, this_idx: usize, idx_idx: usize) void {
            var this_idx_idx = idx_idx;
            var adjacent_idx_idx: usize = undefined;
            var adjacent_idx: usize = undefined;
            var adjacent_val: T = undefined;
            const max_idx_idx = sort.idx_list.len - 1;
            while (this_idx_idx < max_idx_idx) {
                adjacent_idx_idx = this_idx_idx + 1;
                adjacent_idx = @intCast(sort.idx_list.ptr[adjacent_idx_idx]);
                adjacent_val = self.primary_list.ptr[adjacent_idx];
                if (!true_greater_than(sort, new_val, this_idx, adjacent_val, adjacent_idx)) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(adjacent_idx);
                this_idx_idx = adjacent_idx_idx;
            }
            while (this_idx_idx > 0) {
                adjacent_idx_idx = this_idx_idx - 1;
                adjacent_idx = @intCast(sort.idx_list.ptr[adjacent_idx_idx]);
                adjacent_val = self.primary_list.ptr[adjacent_idx];
                if (!true_greater_than(sort, adjacent_val, adjacent_idx, new_val, this_idx)) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(adjacent_idx);
                this_idx_idx = adjacent_idx_idx;
            }
            sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
        }

        fn match_by_index_direction(sort: *SortList, list_val: T, list_idx: usize, test_val: T, test_idx: usize) MatchDirection {
            if (list_idx == test_idx) return .MATCH;
            if (sort.greater_than(list_val, test_val)) return .SPLIT_LEFT;
            if (sort.greater_than(test_val, list_val)) return .SPLIT_RIGHT;
            if (list_idx > test_idx) return .SPLIT_LEFT;
            return .SPLIT_RIGHT;
        }

        fn match_by_value_direction(self: *Self, sort: *SortList, list_val: T, test_val: T) MatchDirection {
            if (self.exact_equal(list_val, test_val)) return .MATCH;
            if (sort.greater_than(list_val, test_val)) return .SPLIT_LEFT;
            return .SPLIT_RIGHT;
        }

        fn order_by_val_and_index_direction(sort: *SortList, list_val: T, list_idx: usize, list_idx_idx: usize, test_val: T, test_idx: usize) InsertDirection {
            if (sort.equal(list_val, test_val)) {
                if (test_idx <= list_idx) {
                    if (list_idx_idx == 0 or sort.idx_list.ptr[list_idx_idx - 1] <= test_idx) {
                        return .INSERT_HERE;
                    } else return .SPLIT_LEFT;
                } else {
                    if (list_idx_idx == sort.idx_list.len - 1) {
                        return .APPEND_TO_END;
                    } else return .SPLIT_RIGHT;
                }
            }
            if (sort.greater_than(list_val, test_val)) return .SPLIT_LEFT;
            return .SPLIT_RIGHT;
        }

        fn match_by_index_indirect(self: *Self, sort: *SortList, find_val: T, find_idx: usize) MatchIdx {
            if (sort.idx_list.len == 0) Assert.assert_unreachable(@src(), "sort list was empty but should not have been", .{});
            var lo_idx_idx: usize = 0;
            // const orig_hi_idx_idx = sort.idx_list.len - 1;
            var hi_idx_idx: usize = sort.idx_list.len - 1;
            var list_idx_idx: usize = undefined;
            var list_idx: usize = undefined;
            var list_val: T = undefined;
            var dir: MatchDirection = undefined;
            // std.debug.print("match_by_index_indirect()\n", .{}); //DEBUG
            while (true) {
                list_idx_idx = split_range(lo_idx_idx, hi_idx_idx);
                list_idx = @intCast(sort.idx_list.ptr[list_idx_idx]);
                list_val = self.primary_list.ptr[list_idx];
                dir = match_by_index_direction(sort, list_val, list_idx, find_val, find_idx);
                switch (dir) {
                    .MATCH => return MatchIdx{ .idx = list_idx, .idx_idx = list_idx_idx },
                    .SPLIT_LEFT => {
                        // std.debug.print("[????<____]: lo = {d}, mid = {d}, hi = {d}, list_val {d} (i {d}) > {d} (i {d}) find_val\n", .{ lo_idx_idx, list_idx_idx, hi_idx_idx, list_val, list_idx, find_val, find_idx }); //DEBUG
                        if (list_idx_idx == lo_idx_idx) Assert.assert_unreachable(@src(), "val {any}, idx {d} was not found in sorted list when it should have been found", .{ find_val, find_idx });
                        hi_idx_idx = list_idx_idx - 1;
                    },
                    .SPLIT_RIGHT => {
                        // std.debug.print("[____>????]: lo = {d}, mid = {d}, hi = {d}, list_val {d}(i {d}) < {d} (i {d}) find_val\n", .{ lo_idx_idx, list_idx_idx, hi_idx_idx, list_val, list_idx, find_val, find_idx }); //DEBUG
                        if (list_idx_idx == hi_idx_idx) Assert.assert_unreachable(@src(), "val {any}, idx {d} was not found in sorted list when it should have been found", .{ find_val, find_idx });
                        lo_idx_idx = list_idx_idx + 1;
                    },
                }
            }
        }

        fn locate_insert_indirect(self: *Self, sort: *SortList, insert_val: T, insert_idx: usize) InsertIdx {
            if (sort.idx_list.len == 0) return InsertIdx{ .idx = insert_idx, .idx_idx = 0, .append_idx_idx = true };
            var lo_idx_idx: usize = 0;
            const orig_hi_idx_idx = sort.idx_list.len - 1;
            var hi_idx_idx: usize = orig_hi_idx_idx;
            var mid_idx_idx: usize = undefined;
            var mid_idx: usize = undefined;
            var mid_val: T = undefined;
            var dir: InsertDirection = undefined;
            // std.debug.print("locate_insert_indirect()\n", .{}); //DEBUG
            while (true) {
                mid_idx_idx = split_range(lo_idx_idx, hi_idx_idx);
                mid_idx = @intCast(sort.idx_list.ptr[mid_idx_idx]);
                mid_val = self.primary_list.ptr[mid_idx];
                dir = order_by_val_and_index_direction(sort, mid_val, mid_idx, mid_idx_idx, insert_val, insert_idx);
                switch (dir) {
                    .INSERT_HERE => return InsertIdx{ .idx = insert_idx, .idx_idx = mid_idx_idx },
                    .APPEND_TO_END => return InsertIdx{ .idx = insert_idx, .idx_idx = mid_idx_idx + 1, .append_idx_idx = true },
                    .SPLIT_LEFT => {
                        // std.debug.print("split low: lo = {d}, mid = {d}, hi = {d}, mid_val {d} (i {d}) > {d} (i {d}) find_val\n", .{ lo_idx_idx, mid_idx_idx, hi_idx_idx, mid_val, mid_idx, insert_val, insert_idx }); //DEBUG
                        if (mid_idx_idx == lo_idx_idx) return InsertIdx{ .idx = insert_idx, .idx_idx = mid_idx_idx };
                        hi_idx_idx = mid_idx_idx - 1;
                    },
                    .SPLIT_RIGHT => {
                        // std.debug.print("split hi: lo = {d}, mid = {d}, hi = {d}, mid_val {d}(i {d}) < {d} (i {d}) find_val\n", .{ lo_idx_idx, mid_idx_idx, hi_idx_idx, mid_val, mid_idx, insert_val, insert_idx }); //DEBUG
                        if (mid_idx_idx == hi_idx_idx) return InsertIdx{ .idx = insert_idx, .idx_idx = mid_idx_idx + 1 };
                        lo_idx_idx = mid_idx_idx + 1;
                    },
                }
            }
        }

        const SortListChange = enum(u8) {
            NEITHER_IN_SORT = 0b00,
            ADD_TO_SORT = 0b10,
            REMOVE_FROM_SORT = 0b01,
            SET_AND_RESORT = 0b11,

            fn filter_old_new(old: bool, new: bool) SortListChange {
                const old_bit: u8 = @as(u8, @intCast(@intFromBool(old)));
                const new_bit: u8 = @as(u8, @intCast(@intFromBool(new))) << 1;
                return @enumFromInt(old_bit | new_bit);
            }
        };

        fn debug_check_for_oob_sort_idx(self: *Self, comptime src: ?std.builtin.SourceLocation) void {
            for (self.sort_lists[0..], 0..) |*sort, sort_tag| {
                for (sort.idx_list.ptr[0..sort.idx_list.len]) |this_idx| {
                    Assert.assert_with_reason(this_idx < self.primary_list.len, src, "sort `{s}` had index `{d} that was out of bound for primary list (len = {d})`", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), this_idx, self.primary_list.len });
                }
            }
        }

        fn debug_assert_all_in_order(self: *Self, comptime src: ?std.builtin.SourceLocation) void {
            var last_val: T = undefined;
            var last_idx_idx: usize = 0;
            var last_idx: usize = 0;
            var this_val: T = undefined;
            var should_be_in_sort: usize = 0;
            for (self.sort_lists[0..], 0..) |*sort, sort_tag| {
                should_be_in_sort = 0;
                for (self.primary_list.ptr[0..self.primary_list.len]) |val| {
                    if (sort.filter(val)) should_be_in_sort += 1;
                }
                Assert.assert_with_reason(sort.idx_list.len == should_be_in_sort, src, "sort `{s}` had incorrect number of items: needed {d}, had {d}", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), should_be_in_sort, sort.idx_list.len });
                if (sort.idx_list.len < 2) continue;
                var idx_check_list = std.ArrayList(IDX).initCapacity(std.heap.page_allocator, sort.idx_list.len) catch unreachable;
                last_idx_idx = 0;
                last_idx = @intCast(sort.idx_list.ptr[0]);
                idx_check_list.append(std.heap.page_allocator, @intCast(last_idx)) catch unreachable;
                last_val = self.primary_list.ptr[last_idx];
                for (sort.idx_list.ptr[1..sort.idx_list.len], 1..) |this_idx, this_idx_idx| {
                    Assert.assert_with_reason(this_idx < self.primary_list.len, src, "sort `{s}` had index `{d} that was out of bound for primary list (len = {d})`", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), this_idx, self.primary_list.len });
                    Assert.assert_with_reason(!std.mem.containsAtLeastScalar(IDX, idx_check_list.items, 1, this_idx), src, "sort `{s}` had duplicate of index {d}", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), this_idx });
                    idx_check_list.append(std.heap.page_allocator, this_idx) catch unreachable;
                    this_val = self.primary_list.ptr[this_idx];
                    Assert.assert_with_reason(!sort.greater_than(last_val, this_val) and (!sort.equal(last_val, this_val) or last_idx < this_idx), src, "in sort `{s}`, the following values were out of order:\nIII: {d: >4} {d: >4}\nIDX: {d: >4} {d: >4}\nVAL: {d: >4} {d: >4}\n", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), last_idx_idx, this_idx_idx, last_idx, this_idx, last_val, this_val });
                    last_idx_idx = this_idx_idx;
                    last_idx = this_idx;
                    last_val = this_val;
                }
                idx_check_list.deinit(std.heap.page_allocator);
            }
        }

        fn debug_dump_nearby_indirect(self: *Self, comptime context: []const u8, sort: *SortList, idx_idx: usize) void {
            const COUNT = 7;
            const HALF = COUNT >> 1;
            const start = idx_idx -| HALF;
            var iii = start;
            var c: usize = 0;
            std.debug.print("\x1b[33mDEBUG_DUMP: {s}\nIII: ", .{context});
            while (c < COUNT) {
                std.debug.print("{d: >4} ", .{iii});
                c += 1;
                iii += 1;
            }
            iii = start;
            c = 0;
            std.debug.print("\nIDX: ", .{});
            while (c < COUNT) {
                std.debug.print("{d: >4} ", .{sort.idx_list.ptr[iii]});
                c += 1;
                iii += 1;
            }
            iii = start;
            c = 0;
            std.debug.print("\nVAL: ", .{});
            while (c < COUNT) {
                std.debug.print("{d: >4} ", .{self.primary_list.ptr[sort.idx_list.ptr[iii]]});
                c += 1;
                iii += 1;
            }
            std.debug.print("\x1b[0m\n", .{});
        }

        fn set_and_resort_indirect(self: *Self, sort: *SortList, old_val: T, new_val: T, idx: usize, alloc: Allocator) void {
            const change = SortListChange.filter_old_new(sort.filter(old_val), sort.filter(new_val));
            switch (change) {
                .NEITHER_IN_SORT => {
                    return;
                },
                .ADD_TO_SORT => {
                    const index = self.find_insert_location_indirect(sort, idx, new_val);
                    var sort_iface = sort.idx_list.interface(alloc);
                    if (index.append) {
                        _ = sort_iface.append(@intCast(idx));
                    } else {
                        _ = sort_iface.insert(index.idx_idx, @intCast(idx));
                    }
                },
                .REMOVE_FROM_SORT => {
                    const index = self.match_by_index_indirect(sort, old_val, idx);
                    var sort_iface = sort.idx_list.interface(alloc);
                    sort_iface.delete(index.idx_idx);
                },
                .SET_AND_RESORT => {
                    // std.debug.print("set_and_resort_indirect:\nidx: {d}\nold_val: {d}, in_list: {any}\nnew_val: {d}, in_list: {any}\n", .{ idx, old_val, sort.filter(old_val), new_val, sort.filter(new_val) }); //DEBUG
                    if (sort.equal(old_val, new_val)) return;
                    const old_location = self.match_by_index_indirect(sort, old_val, idx);
                    self.fix_indirect_value_changed(sort, new_val, idx, old_location.idx_idx);
                },
            }
        }

        fn debug_check_number_of_items(self: *Self, comptime src: std.builtin.SourceLocation) void {
            var expected: usize = 0;
            for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                expected = 0;
                for (self.primary_list.slice()) |val| {
                    if (sort.filter(val)) {
                        expected += 1;
                    }
                }
                Assert.assert_with_reason(sort.idx_list.len == expected, src, "sort `{s}` didn't have the correct number of indexes according to its filter func:\nEXP: {d} items\nGOT: {d} items\n", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_idx))), expected, sort.idx_list.len });
            }
        }

        fn initialize_new_indexes_in_sort(sort: *SortList, primary_range: IList.Range, sort_range: IList.Range) void {
            var val = primary_range.first_idx;
            var idx = sort_range.first_idx;
            while (true) {
                sort.idx_list.ptr[idx] = @intCast(val);
                if (idx == sort_range.last_idx) break;
                val += 1;
                idx += 1;
            }
        }

        const IndirectInsertLoc = struct {
            idx_idx: usize = 0,
            append: bool = false,
        };

        fn find_insert_location_indirect(self: *Self, sort: *SortList, primary_idx: usize, primary_val: T) IndirectInsertLoc {
            var loc = IndirectInsertLoc{};
            if (sort.idx_list.len == 0) {
                loc.append = true;
                return loc;
            }
            var lo: usize = 0;
            const max_hi: usize = Types.intcast(sort.idx_list.len - 1, usize);
            var hi: usize = max_hi;
            var this_idx_idx: usize = undefined;
            var this_idx: usize = 0;
            var this_val: T = undefined;
            const test_val = primary_val;
            const test_idx = primary_idx;
            while (true) {
                this_idx_idx = ((hi - lo) >> 1) + lo;
                this_idx = sort.idx_list.ptr[this_idx_idx];
                this_val = self.primary_list.ptr[this_idx];
                if (sort.greater_than(this_val, test_val)) {
                    if (this_idx_idx == lo) {
                        loc.idx_idx = this_idx_idx;
                        return loc;
                    }
                    hi = this_idx_idx - 1;
                } else if (sort.greater_than(test_val, this_val)) {
                    if (this_idx_idx == hi) {
                        if (this_idx_idx == max_hi) {
                            loc.append = true;
                        } else {
                            loc.idx_idx = this_idx_idx + 1;
                        }
                        return loc;
                    }
                    lo = this_idx_idx + 1;
                } else {
                    if (this_idx < test_idx) {
                        if (this_idx_idx == hi) {
                            if (this_idx_idx == max_hi) {
                                loc.append = true;
                            } else {
                                loc.idx_idx = this_idx_idx + 1;
                            }
                            return loc;
                        }
                        lo = this_idx_idx + 1;
                    } else if (this_idx > test_idx) {
                        if (this_idx_idx == lo) {
                            loc.idx_idx = this_idx_idx;
                            return loc;
                        }
                        hi = this_idx_idx - 1;
                    } else {
                        loc.idx_idx = this_idx_idx;
                        return loc;
                    }
                }
            }
        }

        fn add_uninit_range_indirect_indexes(self: *Self, sort: *SortList, insert_idx: usize, count: usize, alloc: Allocator) SortListReportWithInsertRange {
            var report = SortListReportWithInsertRange{};
            const do_add = sort.filter(UNINIT);
            for (sort.idx_list.slice(), 0..) |idx, idx_idx| {
                if (idx >= insert_idx) {
                    sort.idx_list.ptr[idx_idx] = idx + Types.intcast(count, IDX);
                    report.add_changed_idx(idx_idx);
                }
            }
            //CHECKPOINT //FIXME something is wrong in this logic and the subsequent _resort() logic
            if (do_add) {
                const sort_iface = sort.idx_list.interface(alloc);
                Assert.assert_with_reason(sort_iface.try_ensure_free_slots(count), @src(), "failed to allocate space for {d} new sorted indexes of type {s}", .{ count, @typeName(IDX) });
                const add_location = self.find_insert_location_indirect(sort, insert_idx, UNINIT);
                var range: IList.Range = undefined;
                if (add_location.append) {
                    range = sort_iface.append_slots_assume_capacity(count);
                } else {
                    range = sort_iface.insert_slots_assume_capacity(add_location.idx_idx, count);
                    if (report.at_least_one) {
                        if (add_location.idx_idx <= report.smallest) {
                            report.smallest += count;
                        }
                        if (add_location.idx_idx <= report.largest) {
                            report.largest += count;
                        }
                    }
                }
                report.add_insert_range(range);
                // for (uninit_range.first_idx..uninit_range.last_idx + 1, range.first_idx..range.last_idx + 1) |idx, idx_idx| {
                //     sort.idx_list.ptr[idx_idx] = @intCast(idx);
                // }
            }
            return report;
        }

        fn add_uninit_range_indirect_resort(self: *Self, sort: *SortList, sort_report: SortListReportWithInsertRange, uninit_range: IList.Range) void {
            if (sort_report.has_insert) {
                for (uninit_range.first_idx..uninit_range.last_idx + 1, sort_report.smallest_insert..sort_report.largest_insert + 1) |idx, idx_idx| {
                    sort.idx_list.ptr[idx_idx] = @intCast(idx);
                }
            }
            var idx_idx: usize = sort_report.smallest;
            var incr: usize = 1;
            std.debug.print("uninit_range: [{d}, {d}]\nsort_report: [{d}, {d}]\nsort_report_insert: [{d}, {d}]\n", .{ uninit_range.first_idx, uninit_range.last_idx, sort_report.smallest, sort_report.largest, sort_report.smallest_insert, sort_report.largest_insert }); //DEBUG
            while (idx_idx < sort_report.largest) {
                const idx = sort.idx_list.ptr[idx_idx];
                incr = 1;
                if (idx >= uninit_range.first_idx) {
                    if (self.resort_up_many(sort, idx_idx)) {
                        incr = 0;
                    }
                }
                idx_idx += incr;
            }
        }

        fn append_uninit_range_indirect(self: *Self, sort: *SortList, uninit_range: IList.Range, count: usize, alloc: Allocator) void {
            if (!sort.filter(UNINIT)) return;
            var self_iface = self.primary_list.interface(alloc);
            const sort_iface = sort.idx_list.interface(alloc);
            const idx = self_iface.sorted_insert_index_indirect(IDX, sort_iface, UNINIT, sort.equal, sort.greater_than);
            const sort_range = if (idx.append) sort_iface.append_slots(count) else sort_iface.insert_slots(idx.idx_idx, count);
            initialize_new_indexes_in_sort(sort, uninit_range, sort_range);
            self.debug_assert_all_in_order(@src()); //DEBUG
        }

        fn insert_uninit_range_indirect(self: *Self, sort: *SortList, uninit_range: IList.Range, count: usize, alloc: Allocator) void {
            const do_insert = sort.filter(UNINIT);
            var self_iface = self.primary_list.interface(alloc);
            const sort_iface = sort.idx_list.interface(alloc);
            const idx = if (do_insert) self_iface.sorted_insert_index_indirect(IDX, sort_iface, UNINIT, sort.equal, sort.greater_than) else IList.InsertIndexResultIndirect{};
            var i: usize = 0;
            var u: usize = 0;
            const incr_max = self.primary_list.len - uninit_range.last_idx - 1;
            while (i < sort.idx_list.len and u < incr_max) {
                var real_idx = sort.idx_list.ptr[i];
                if (real_idx > uninit_range.last_idx) {
                    real_idx += @intCast(count);
                    sort.idx_list.ptr[i] = real_idx;
                    u += 1;
                }
                i += 1;
            }
            if (!do_insert) return;
            const sort_range = if (idx.append) sort_iface.append_slots(count) else sort_iface.insert_slots(idx.idx_idx, count);
            initialize_new_indexes_in_sort(sort, uninit_range, sort_range);
            self.debug_assert_all_in_order(@src()); //DEBUG
        }

        // fn smallest_idx_idx_in_range_indirect(self: *Self, sort: *SortList, real_range: IList.Range) ?usize {
        //     var range_idx = real_range.first_idx;
        //     var smallest: ?usize = null;
        //     const sort_iface = sort.idx_list.interface_no_alloc();
        //     var self_iface = self.primary_list.interface_no_alloc();
        //     while (true) {
        //         const val = self.primary_list.ptr[range_idx];
        //         if (sort.filter(val)) {
        //             const result = self_iface.sorted_search_indirect(IDX, sort_iface, val, sort.equal, sort.greater_than);
        //             if (result.found and (smallest == null or result.idx_idx < smallest.?)) {
        //                 smallest = result.idx_idx;
        //             }
        //         }
        //         if (range_idx == real_range.last_idx) break;
        //         range_idx += 1;
        //     }
        //     return smallest;
        // }

        fn delete_range_indirect_indexes(sort: *SortList, delete_range: IList.Range, delete_count: usize) SortListReport {
            var result = SortListReport{};
            var write_idx_idx: usize = 0;
            var deleted: usize = 0;
            for (sort.idx_list.ptr[0..sort.idx_list.len]) |idx| {
                if (delete_range.first_idx <= idx and idx <= delete_range.last_idx) {
                    deleted += 1;
                } else {
                    var new_idx: IDX = idx;
                    if (idx > delete_range.last_idx) {
                        result.add_idx(write_idx_idx);
                        new_idx -= @intCast(delete_count);
                    }
                    sort.idx_list.ptr[write_idx_idx] = new_idx;
                    write_idx_idx += 1;
                }
            }
            sort.idx_list.len -= @intCast(deleted);
            return result;
        }
        fn delete_range_indirect_resort(self: *Self, sort: *SortList, sort_report: SortListReport, delete_range: IList.Range) void {
            for (sort.idx_list.ptr[sort_report.smallest .. sort_report.largest + 1], sort_report.smallest..) |idx, idx_idx| {
                if (idx >= delete_range.first_idx) {
                    _ = self.resort_down_many(sort, idx_idx);
                }
            }
        }
        // fn delete_range_indirect(self: *Self, sort: *SortList, real_range: IList.Range) void {
        //     // var sort_read_idx: usize = self.smallest_idx_idx_in_range_indirect(sort, real_range);

        //     self.debug_dump_nearby_indirect("delete_range_indirect()", &self.sort_lists[0], 270); //DEBUG
        //     std.debug.print("delete_range_indirect({d}, {d})", .{ real_range.first_idx, real_range.last_idx }); //DEBUG
        //     self.debug_assert_all_in_order(@src()); //DEBUG
        // }

        const ShiftDirection = enum(u8) {
            this_up__other_down,
            this_down__other_up,
        };

        pub const impl = struct {
            pub fn impl_idx_valid(object: *anyopaque, idx: usize) bool {
                const self: *Self = @ptrCast(@alignCast(object));
                return idx < self.primary_list.len;
            }
            pub fn impl_range_valid(object: *anyopaque, range: IList.Range) bool {
                const self: *Self = @ptrCast(@alignCast(object));
                return range.first_idx <= range.last_idx and range.last_idx < self.primary_list.len;
            }
            pub fn impl_idx_in_range(_: *anyopaque, range: IList.Range, idx: usize) bool {
                return range.first_idx <= idx and idx <= range.last_idx;
            }
            pub fn impl_split_range(_: *anyopaque, range: IList.Range) usize {
                return ((range.last_idx - range.first_idx) >> 1) + range.first_idx;
            }
            pub fn impl_range_len(_: *anyopaque, range: IList.Range) usize {
                return range.consecutive_len();
            }
            pub fn impl_get(object: *anyopaque, idx: usize, _: Allocator) T {
                const self: *Self = @ptrCast(@alignCast(object));
                Assert.assert_idx_less_than_len(idx, Types.intcast(self.primary_list.len, usize), @src());
                return self.primary_list.ptr[idx];
            }
            pub fn impl_set(object: *anyopaque, idx: usize, val: T, alloc: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                Assert.assert_idx_less_than_len(idx, Types.intcast(self.primary_list.len, usize), @src());
                self.debug_check_number_of_items(@src()); //DEBUG
                const old_val = self.primary_list.ptr[idx];
                for (self.sort_lists[0..]) |*sort| {
                    self.set_and_resort_indirect(sort, old_val, val, idx, alloc);
                }
                self.primary_list.ptr[idx] = val;
                self.debug_assert_all_in_order(@src()); //DEBUG
            }
            pub fn impl_move(object: *anyopaque, old_idx: usize, new_idx: usize, _: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                if (old_idx == new_idx) return;
                var smallest_other: usize = undefined;
                var largest_other: usize = undefined;
                var dir: ShiftDirection = undefined;
                var delta: usize = undefined;
                if (old_idx < new_idx) {
                    smallest_other = old_idx + 1;
                    largest_other = new_idx;
                    delta = new_idx - old_idx;
                    dir = .this_up__other_down;
                } else {
                    smallest_other = new_idx;
                    largest_other = old_idx - 1;
                    delta = old_idx - new_idx;
                    dir = .this_down__other_up;
                }
                // std.debug.print("direction: {s}, move_one(old_idx = {d}, new_idx = {d})\nother = [{d}, {d}], delta = {d}\n", .{ @tagName(dir), old_idx, new_idx, smallest_other, largest_other, delta }); //DEBUG

                var sort_reports: [SORT_COUNT]SortListReport = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    // self.debug_dump_nearby_indirect("impl_move indexes before", sort, 25); //DEBUG
                    sort_reports[sort_idx] = move_one_indirect_indexes(sort, old_idx, delta, smallest_other, largest_other, dir);
                    // self.debug_dump_nearby_indirect("impl_move indexes after", sort, 25); //DEBUG
                }
                Utils.slice_move_one(self.primary_list.ptr[0..self.primary_list.len], old_idx, new_idx);
                switch (dir) {
                    .this_up__other_down => {
                        smallest_other -= 1;
                        largest_other -= 1;
                    },
                    .this_down__other_up => {
                        smallest_other += 1;
                        largest_other += 1;
                    },
                }
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    // self.debug_dump_nearby_indirect("impl_move resort before", sort, 25); //DEBUG
                    self.move_one_indirect_resort(sort, sort_reports[sort_idx], new_idx, smallest_other, largest_other, dir);
                    // self.debug_dump_nearby_indirect("impl_move resort after", sort, 25); //DEBUG
                }
                self.debug_assert_all_in_order(@src()); //DEBUG
            }
            pub fn impl_move_range(object: *anyopaque, range: IList.Range, new_first_idx: usize, _: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                if (range.first_idx == new_first_idx) return;
                const range_len: usize = range.consecutive_len();
                var smallest_shifted_down: usize = undefined;
                var largest_shifted_down: usize = undefined;
                var smallest_shifted_up: usize = undefined;
                var largest_shifted_up: usize = undefined;
                var delta_up: usize = undefined;
                var delta_down: usize = undefined;
                if (range.first_idx < new_first_idx) {
                    smallest_shifted_up = range.first_idx;
                    largest_shifted_up = range.last_idx;
                    smallest_shifted_down = range.last_idx + 1;
                    largest_shifted_down = (new_first_idx + range_len) - 1;
                    delta_up = (largest_shifted_down - smallest_shifted_down) + 1;
                    delta_down = range_len;
                } else {
                    smallest_shifted_up = new_first_idx;
                    largest_shifted_up = range.first_idx - 1;
                    smallest_shifted_down = range.first_idx;
                    largest_shifted_down = range.last_idx;
                    delta_up = range_len;
                    delta_down = (largest_shifted_up - smallest_shifted_up) + 1;
                }
                var sort_reports: [SORT_COUNT]SortListReport = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = move_range_indirect_indexes(sort, smallest_shifted_up, largest_shifted_up, delta_up, smallest_shifted_down, largest_shifted_down, delta_down);
                }
                // self.debug_check_for_oob_sort_idx(@src()); //DEBUG
                Utils.slice_move_many(self.primary_list.ptr[0..self.primary_list.len], range.first_idx, range.last_idx, new_first_idx);
                // self.debug_check_for_oob_sort_idx(@src()); //DEBUG
                smallest_shifted_down -= delta_down;
                largest_shifted_down -= delta_down;
                smallest_shifted_up += delta_up;
                largest_shifted_up += delta_up;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    self.move_range_indirect_resort(sort, sort_reports[sort_idx], smallest_shifted_up, largest_shifted_up, smallest_shifted_down, largest_shifted_down);
                }
                self.debug_assert_all_in_order(@src()); //DEBUG
            }
            pub fn impl_first(object: *anyopaque) usize {
                _ = object;
                return 0;
            }
            pub fn impl_next(object: *anyopaque, idx: usize) usize {
                _ = object;
                return idx + 1;
            }
            pub fn impl_nth_next(object: *anyopaque, idx: usize, n: usize) usize {
                _ = object;
                return idx + n;
            }
            pub fn impl_last(object: *anyopaque) usize {
                const self: *Self = @ptrCast(@alignCast(object));
                return @intCast(self.primary_list.len -% 1);
            }
            pub fn impl_prev(object: *anyopaque, idx: usize) usize {
                _ = object;
                return idx -% 1;
            }
            pub fn impl_nth_prev(object: *anyopaque, idx: usize, n: usize) usize {
                _ = object;
                return idx -% n;
            }
            pub fn impl_len(object: *anyopaque) usize {
                const self: *Self = @ptrCast(@alignCast(object));
                return @intCast(self.primary_list.len);
            }
            pub fn impl_ensure_free(object: *anyopaque, count: usize, alloc: Allocator) bool {
                const self: *Self = @ptrCast(@alignCast(object));
                return List(T).impl.impl_ensure_free(@ptrCast(&self.primary_list), count, alloc);
            }
            pub fn impl_append(object: *anyopaque, count: usize, alloc: Allocator) IList.Range {
                const self: *Self = @ptrCast(@alignCast(object));
                var sort_reports: [SORT_COUNT]SortListReportWithInsertRange = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = self.add_uninit_range_indirect_indexes(sort, self.primary_list.len, count, alloc);
                }
                const range = List(T).impl.impl_append(@ptrCast(&self.primary_list), count, alloc);
                @memset(self.primary_list.ptr[range.first_idx .. range.last_idx + 1], UNINIT);
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    self.add_uninit_range_indirect_resort(sort, sort_reports[sort_idx], range);
                }
                self.debug_assert_all_in_order(@src()); //DEBUG
                return range;
            }
            pub fn impl_insert(object: *anyopaque, idx: usize, count: usize, alloc: Allocator) IList.Range {
                std.debug.print("\nimpl_insert(idx = {d}, count = {d})\n", .{ idx, count }); //DEBUG
                const self: *Self = @ptrCast(@alignCast(object));
                self.debug_assert_all_in_order(@src()); //DEBUG
                var sort_reports: [SORT_COUNT]SortListReportWithInsertRange = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = self.add_uninit_range_indirect_indexes(sort, idx, count, alloc);
                }
                const range = List(T).impl.impl_insert(@ptrCast(&self.primary_list), idx, count, alloc);
                @memset(self.primary_list.ptr[range.first_idx .. range.last_idx + 1], UNINIT);
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    self.add_uninit_range_indirect_resort(sort, sort_reports[sort_idx], range);
                }

                self.debug_assert_all_in_order(@src()); //DEBUG
                return range;
            }
            pub fn impl_delete(object: *anyopaque, range: IList.Range, alloc: Allocator) void {
                _ = alloc;
                const self: *Self = @ptrCast(@alignCast(object));
                const delete_count = range.consecutive_len();
                var sort_reports: [SORT_COUNT]SortListReport = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = delete_range_indirect_indexes(sort, range, delete_count);
                }
                Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, range.first_idx, delete_count);
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    self.delete_range_indirect_resort(sort, sort_reports[sort_idx], range);
                }
                self.debug_assert_all_in_order(@src()); //DEBUG
            }
            pub fn impl_shrink_reserve(object: *anyopaque, reserve_at_most: usize, alloc: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                List(T).impl.impl_shrink_reserve(@ptrCast(&self.primary_list), reserve_at_most, alloc);
                for (self.sort_lists[0..]) |*sort| {
                    List(IDX).impl.impl_shrink_reserve(@ptrCast(&sort.idx_list), reserve_at_most, alloc);
                }
            }
            pub fn impl_clear(object: *anyopaque, alloc: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                List(T).impl.impl_clear(@ptrCast(&self.primary_list), alloc);
                for (self.sort_lists[0..]) |*sort| {
                    List(IDX).impl.impl_clear(@ptrCast(&sort.idx_list), alloc);
                }
            }
            pub fn impl_cap(object: *anyopaque) usize {
                const self: *Self = @ptrCast(@alignCast(object));
                return self.primary_list.cap;
            }
            pub fn impl_free(object: *anyopaque, alloc: Allocator) void {
                const self: *Self = @ptrCast(@alignCast(object));
                self.free(alloc);
            }
        };
    };
}
