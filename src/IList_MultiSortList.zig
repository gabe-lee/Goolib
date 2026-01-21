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
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const Flags = Root.Flags;

const List = Root.IList_List.List;

const DummyAlloc = Root.DummyAllocator;

pub const Concrete = IList.Concrete;

pub const FilterMode = Concrete.FilterMode;
pub const CountResult = Concrete.CountResult;
pub const CopyResult = Concrete.CopyResult;
pub const LocateResult = Concrete.LocateResult;
pub const SearchResult = Concrete.SearchResult;
pub const InsertIndexResult = Concrete.InsertIndexResult;
pub const ListError = Concrete.ListError;
pub const Range = Concrete.Range;

const NO_ALLOC = DummyAlloc.allocator_panic;

pub fn MultiSortList(comptime T: type, comptime UNINIT: T, comptime IDX: type, comptime SORT_NAMES: type, comptime FN_USERDATA_TYPE: type) type {
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
        exact_equal: *const COMPARE_FN = noop_compare_true,
        sort_lists: [SORT_COUNT]SortList = @splat(SortList{}),
        userdata: USERDATA,

        const IdxList = List(IDX);

        pub const COMPARE_FN = fn (a: T, b: T, userdata: USERDATA) bool;
        pub const TEST_FN = fn (val: T, userdata: USERDATA) bool;
        pub const USERDATA = FN_USERDATA_TYPE;

        const SortList = struct {
            idx_list: IdxList = .{},
            greater_than: ?*const COMPARE_FN = noop_compare_false,
            equal: *const COMPARE_FN = noop_compare_true,
            filter: *const TEST_FN = noop_true,
        };

        pub const SortInit = struct {
            name: SORT_NAMES,
            greater_than: ?*const COMPARE_FN,
            equal: *const COMPARE_FN,
            filter: *const TEST_FN = noop_true,
        };

        pub const SortIdx = struct {
            sort_name: SORT_NAMES,
            sort_list_idx: usize,
            real_idx: usize,
        };

        fn noop_compare_false(_: T, _: T, _: USERDATA) bool {
            return false;
        }
        fn noop_compare_true(_: T, _: T, _: USERDATA) bool {
            return true;
        }
        fn noop_true(_: T, _: USERDATA) bool {
            return true;
        }

        pub fn find_idx_for_exact_value_using_sort(self: *Self, sort_name: SORT_NAMES, find_val: T) ?SortIdx {
            return self.find_idx_for_value_using_sort(sort_name, find_val, self.exact_equal);
        }

        pub fn lookup_real_idx_from_sort_idx(self: *Self, sort_name: SORT_NAMES, sort_idx: usize) usize {
            const real_idx = self.sort_lists[@intFromEnum(sort_name)].idx_list.ptr[sort_idx];
            return @intCast(real_idx);
        }

        pub fn get_sort_list_len(self: *Self, sort_name: SORT_NAMES) usize {
            return @intCast(self.sort_lists[@intFromEnum(sort_name)].idx_list.len);
        }

        pub fn find_idx_for_value_using_sort(self: *Self, sort_name: SORT_NAMES, find_val: T, equal_func: *const fn (a: T, b: T) bool) ?SortIdx {
            const sort = self.sort_lists[@intFromEnum(sort_name)];
            if (sort.greater_than == null) {
                var i: usize = 0;
                while (i < sort.idx_list.len) {
                    const this_idx = sort.idx_list.ptr[i];
                    const this_val = self.primary_list.ptr[this_idx];
                    if (equal_func(this_val, find_val)) {
                        return SortIdx{
                            .sort_name = sort_name,
                            .real_idx = this_idx,
                            .sort_list_idx = i,
                        };
                    }
                    i += 1;
                }
                return null;
            }
            if (sort.idx_list.len == 0) {
                return null;
            }
            var lo: usize = 0;
            var hi: usize = sort.idx_list.len - 1;
            var this_idx_idx: usize = undefined;
            var this_idx: usize = 0;
            var this_val: T = undefined;
            while (true) {
                this_idx_idx = ((hi - lo) >> 1) + lo;
                this_idx = sort.idx_list.ptr[this_idx_idx];
                this_val = self.primary_list.ptr[this_idx];
                if (equal_func(this_val, find_val)) {
                    return SortIdx{
                        .sort_name = sort_name,
                        .real_idx = this_idx,
                        .sort_list_idx = this_idx_idx,
                    };
                } else if (sort.greater_than.?(this_val, find_val)) {
                    if (this_idx_idx == lo) return null;
                    hi = this_idx_idx - 1;
                } else if (sort.greater_than.?(find_val, this_val)) {
                    if (this_idx_idx == hi) return null;
                    lo = this_idx_idx + 1;
                } else return null;
            }
        }

        pub fn first_sorted_idx(self: *Self, sort: SORT_NAMES) ?SortIdx {
            const sort_ = self.sort_lists[@intFromEnum(sort)];
            if (sort_.idx_list.len == 0) return null;
            return SortIdx{
                .sort_name = sort,
                .sort_list_idx = 0,
                .real_idx = @intCast(sort_.idx_list.ptr[0]),
            };
        }

        pub fn last_sorted_idx(self: *Self, sort: SORT_NAMES) ?SortIdx {
            const sort_ = self.sort_lists[@intFromEnum(sort)];
            if (sort_.idx_list.len == 0) return null;
            const last = sort_.idx_list.len - 1;
            return SortIdx{
                .sort_name = sort,
                .sort_list_idx = last,
                .real_idx = @intCast(sort_.idx_list.ptr[last]),
            };
        }

        pub fn next_sorted_idx(self: *Self, curr_sort_idx: SortIdx) ?SortIdx {
            const sort = self.sort_lists[@intFromEnum(curr_sort_idx.sort_name)];
            const next = curr_sort_idx.sort_list_idx + 1;
            if (next >= sort.idx_list.len) return null;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[next]),
                .sort_list_idx = next,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn nth_next_sorted_idx(self: *Self, curr_sort_idx: SortIdx, n: usize) ?SortIdx {
            const sort = self.sort_lists[@intFromEnum(curr_sort_idx.sort_name)];
            const next = curr_sort_idx.sort_list_idx + n;
            if (next >= sort.idx_list.len) return null;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[next]),
                .sort_list_idx = next,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn prev_sorted_idx(self: *Self, curr_sort_idx: SortIdx) ?SortIdx {
            const sort = self.sort_lists[@intFromEnum(curr_sort_idx.sort_name)];
            if (curr_sort_idx.sort_list_idx == 0 or sort.idx_list.len == 0) return null;
            const prev = curr_sort_idx.sort_list_idx - 1;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[prev]),
                .sort_list_idx = prev,
                .sort_name = curr_sort_idx.sort_name,
            };
        }
        pub fn nth_prev_sorted_idx(self: *Self, curr_sort_idx: SortIdx, n: usize) ?SortIdx {
            const sort = self.sort_lists[@intFromEnum(curr_sort_idx.sort_name)];
            if (curr_sort_idx.sort_list_idx < n or sort.idx_list.len <= n) return null;
            const prev = curr_sort_idx.sort_list_idx - n;
            return SortIdx{
                .real_idx = @intCast(sort.idx_list.ptr[prev]),
                .sort_list_idx = prev,
                .sort_name = curr_sort_idx.sort_name,
            };
        }

        pub fn sorted_slice(self: *Self, sort: SORT_NAMES) []IDX {
            const sort_ = self.sort_lists[@intFromEnum(sort)];
            return sort_.idx_list.ptr[0..sort_.idx_list.len];
        }

        const SET_REMOVE_FROM_SORT: comptime_int = 0b10;
        const SET_ADD_TO_SORT: comptime_int = 0b01;
        const SET_ALTER_SORT: comptime_int = 0b11;
        const SET_UNCHANGED_SORT: comptime_int = 0b00;

        pub fn init_empty(exact_equal: *const COMPARE_FN, userdata: USERDATA, sort_inits: []const SortInit) Self {
            var s = Self{
                .primary_list = List(T).init_empty(),
                .exact_equal = exact_equal,
                .userdata = userdata,
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

        pub fn init_capacity(cap: usize, sort_cap: usize, alloc: Allocator, exact_equal: *const COMPARE_FN, userdata: USERDATA, sort_inits: []const SortInit) Self {
            var s = Self{
                .primary_list = List(T).init_capacity(cap, alloc),
                .exact_equal = exact_equal,
                .userdata = userdata,
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

        pub fn append_initialized_slots_assume_capacity(self: *Self, count: usize, init_val: T, alloc: Allocator) IList.Range {
            Assert.assert_with_reason(count <= self.primary_list.cap - self.primary_list.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.primary_list.len, self.primary_list.cap, self.primary_list.cap - self.primary_list.len, count, count });
            const range = self.primary_list.append_slots_assume_capacity(count);
            @memset(self.primary_list.ptr[range.first_idx .. range.last_idx + 1], init_val);
            for (self.sort_lists[0..]) |*sort| {
                self.add_uninit_range_indirect_insert(sort, range.first_idx, count, alloc);
            }
            return range;
        }
        pub fn insert_initialized_slots_assume_capacity(self: *Self, idx: usize, count: usize, init_val: T, alloc: Allocator) IList.Range {
            if (idx == self.primary_list.len) {
                return append_initialized_slots_assume_capacity(self, count, init_val, alloc);
            }
            Assert.assert_with_reason(count <= self.primary_list.cap - self.primary_list.len, @src(), "not enough unused capacity (len = {d}, cap = {d}, free = {d}, need = {d}): use IList.try_ensure_free_slots({d}) first", .{ self.primary_list.len, self.primary_list.cap, self.primary_list.cap - self.primary_list.len, count, count });
            for (self.sort_lists[0..]) |*sort| {
                add_uninit_range_indirect_indexes(sort, idx, count);
            }
            const range = self.primary_list.insert_slots_assume_capacity(idx, count);
            @memset(self.primary_list.ptr[range.first_idx .. range.last_idx + 1], init_val);
            for (self.sort_lists[0..]) |*sort| {
                self.add_uninit_range_indirect_insert(sort, idx, count, alloc);
            }
            return range;
        }

        pub fn append_1_initialized(self: *Self, val: T, alloc: Allocator) usize {
            self.primary_list.ensure_free_slots(1, alloc);
            const range = self.primary_list.append_slots_assume_capacity(1);
            self.primary_list.ptr[range.first_idx] = val;
            for (self.sort_lists[0..]) |*sort| {
                self.add_one_init_indirect_insert(sort, range.first_idx, val, alloc);
            }
            self.debug_assert_all_in_order(@src()); //DEBUG
            return range.first_idx;
        }
        pub fn insert_1_initialized(self: *Self, idx: usize, val: T, alloc: Allocator) usize {
            self.primary_list.ensure_free_slots(1, alloc);
            for (self.sort_lists[0..]) |*sort| {
                add_uninit_range_indirect_indexes(sort, self.primary_list.len, 1);
            }
            const range = self.primary_list.insert_slots_assume_capacity(idx, 1);
            self.primary_list.ptr[range.first_idx] = val;
            for (self.sort_lists[0..]) |*sort| {
                self.add_one_init_indirect_insert(sort, range.first_idx, val, alloc);
            }
            self.debug_assert_all_in_order(@src()); //DEBUG
            return range;
        }

        pub fn append_2_initialized(self: *Self, val1: T, val2: T, alloc: Allocator) usize {
            self.primary_list.ensure_free_slots(2, alloc);
            const range = self.primary_list.append_slots_assume_capacity(2);
            self.primary_list.ptr[range.first_idx] = val1;
            self.primary_list.ptr[range.last_idx] = val2;
            for (self.sort_lists[0..]) |*sort| {
                self.add_two_init_indirect_insert(sort, range.first_idx, range.last_idx, val1, val2, alloc);
            }
            self.debug_assert_all_in_order(@src()); //DEBUG
            return range;
        }
        pub fn insert_2_initialized(self: *Self, idx: usize, val1: T, val2: T, alloc: Allocator) usize {
            self.primary_list.ensure_free_slots(2, alloc);
            for (self.sort_lists[0..]) |*sort| {
                add_uninit_range_indirect_indexes(sort, self.primary_list.len, 2);
            }
            const range = self.primary_list.insert_slots_assume_capacity(idx, 2);
            self.primary_list.ptr[range.first_idx] = val1;
            self.primary_list.ptr[range.last_idx] = val2;
            for (self.sort_lists[0..]) |*sort| {
                self.add_two_init_indirect_insert(sort, range.first_idx, range.last_idx, val1, val2, alloc);
            }
            self.debug_assert_all_in_order(@src()); //DEBUG
            return range;
        }

        const OUT_IS_KNOWN: u2 = 0b00;
        const OUT_BEFORE_KNOWN: u2 = 0b10;
        const OUT_AFTER_KNOWN: u2 = 0b01;

        /// Uses a known 'RealIndex' + 'SortIndex' + 'SortName' to set and resort a value, and returns the NEW
        /// 'SortIndex' for the desired 'SortName' after it is resorted, which may be different than the input 'SortName'.
        pub fn set_1_with_sort_idx(self: *Self, idx: SortIdx, set_val: T, comptime out_sort_name: SORT_NAMES, alloc: Allocator) ?usize {
            Assert.assert_idx_less_than_len(idx.real_idx, Types.intcast(self.primary_list.len, usize), @src());
            const sort_idx: usize = @intCast(@intFromEnum(idx.sort_name));
            const out_sort_idx: usize = @intCast(@intFromEnum(out_sort_name));
            const out_before: u2 = @as(u2, @intCast(@intFromBool(out_sort_idx < sort_idx))) << 1;
            const out_after: u2 = @as(u2, @intCast(@intFromBool(out_sort_idx > sort_idx)));
            const branch = out_before | out_after;
            const old_val = self.primary_list.ptr[idx.real_idx];
            var new_sort_idx: ?usize = undefined;
            switch (branch) {
                OUT_IS_KNOWN => {
                    for (self.sort_lists[0..sort_idx]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                    new_sort_idx = self.set_and_resort_indirect_known_sort_idx_with_result(&self.sort_lists[sort_idx], old_val, set_val, idx.real_idx, idx.sort_list_idx);
                    for (self.sort_lists[sort_idx + 1 ..]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                },
                OUT_BEFORE_KNOWN => {
                    for (self.sort_lists[0..out_sort_idx]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                    new_sort_idx = self.set_and_resort_indirect_with_result(&self.sort_lists[out_sort_idx], old_val, set_val, idx.real_idx, alloc);
                    for (self.sort_lists[out_sort_idx + 1 .. sort_idx]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                    self.set_and_resort_indirect_known_sort_idx(&self.sort_lists[sort_idx], old_val, set_val, idx.real_idx, idx.sort_list_idx);
                    for (self.sort_lists[sort_idx + 1 ..]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                },
                OUT_AFTER_KNOWN => {
                    for (self.sort_lists[0..sort_idx]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                    self.set_and_resort_indirect_known_sort_idx(&self.sort_lists[sort_idx], old_val, set_val, idx.real_idx, idx.sort_list_idx);
                    for (self.sort_lists[sort_idx + 1 .. out_sort_idx]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                    new_sort_idx = self.set_and_resort_indirect_with_result(&self.sort_lists[out_sort_idx], old_val, set_val, idx.real_idx, alloc);
                    for (self.sort_lists[out_sort_idx + 1 ..]) |*sort| {
                        self.set_and_resort_indirect(sort, old_val, set_val, idx.real_idx, alloc);
                    }
                },
                else => unreachable,
            }
            self.debug_assert_all_in_order(@src()); //DEBUG;
            return new_sort_idx;
        }

        pub fn set_1_delete_1(self: *Self, set_idx: usize, set_val: T, del_idx: usize, alloc: Allocator) void {
            Assert.assert_idx_less_than_len(set_idx, Types.intcast(self.primary_list.len, usize), @src());
            Assert.assert_idx_less_than_len(del_idx, Types.intcast(self.primary_list.len, usize), @src());
            for (self.sort_lists[0..]) |*sort| {
                delete_1_indirect_indexes(sort, del_idx);
            }
            if (del_idx == self.primary_list.len - 1) {
                self.primary_list.len -= 1;
            } else {
                Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, del_idx, 1);
            }
            const set_idx_adjusted = if (set_idx > del_idx) set_idx - 1 else set_idx;
            const old_val = self.primary_list.ptr[set_idx_adjusted];
            for (self.sort_lists[0..]) |*sort| {
                self.set_and_resort_indirect(sort, old_val, set_val, set_idx_adjusted, alloc);
            }
            self.primary_list.ptr[set_idx_adjusted] = set_val;
            self.debug_assert_all_in_order(@src()); //DEBUG;
        }

        pub fn set_1_delete_2(self: *Self, set_idx: usize, set_val: T, del_idx_1: usize, del_idx_2: usize, alloc: Allocator) void {
            Assert.assert_idx_less_than_len(set_idx, Types.intcast(self.primary_list.len, usize), @src());
            Assert.assert_idx_less_than_len(del_idx_1, Types.intcast(self.primary_list.len, usize), @src());
            Assert.assert_idx_less_than_len(del_idx_2, Types.intcast(self.primary_list.len, usize), @src());
            for (self.sort_lists[0..]) |*sort| {
                delete_2_indirect_indexes(sort, del_idx_1, del_idx_2);
            }
            var d_idx_1: usize = del_idx_1;
            var d_idx_2: usize = del_idx_2;
            if (del_idx_2 < del_idx_1) {
                d_idx_1 = del_idx_2;
                d_idx_2 = del_idx_1;
            }
            if (del_idx_2 == self.primary_list.len - 1) {
                self.primary_list.len -= 1;
                if (del_idx_1 == self.primary_list.len - 1) {
                    self.primary_list.len -= 1;
                } else {
                    Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, del_idx_1, 1);
                }
            } else {
                Utils.mem_remove_sparse_by_indexes_sorted_low_to_high(self.primary_list.ptr, &self.primary_list.len, &[2]usize{ d_idx_1, d_idx_2 });
            }
            var set_idx_adjusted = set_idx;
            if (set_idx > d_idx_1) set_idx_adjusted -= 1;
            if (set_idx > d_idx_2) set_idx_adjusted -= 1;
            const old_val = self.primary_list.ptr[set_idx_adjusted];
            for (self.sort_lists[0..]) |*sort| {
                self.set_and_resort_indirect(sort, old_val, set_val, set_idx_adjusted, alloc);
            }
            self.primary_list.ptr[set_idx_adjusted] = set_val;
            self.debug_assert_all_in_order(@src()); //DEBUG;
        }

        //*** BEGIN PROTOTYPE ***
        const P_FUNCS = struct {
            fn p_get(self: *Self, idx: usize, _: Allocator) T {
                return self.primary_list.ptr[idx];
            }
            fn p_get_ptr(_: *Self, _: usize, _: Allocator) *T {
                Assert.assert_unreachable(@src(), "using `get_ptr()` on a MultiSortList is not allowed: Making changes via a pointer does not propogate sorting updates.\nIf a pointer is absolutely needed, use `&ms_list.primary_list.ptr[idx]` instead", .{});
            }
            fn p_set(self: *Self, idx: usize, val: T, alloc: Allocator) void {
                Assert.assert_idx_less_than_len(idx, Types.intcast(self.primary_list.len, usize), @src());
                const old_val = self.primary_list.ptr[idx];
                for (self.sort_lists[0..]) |*sort| {
                    self.set_and_resort_indirect(sort, old_val, val, idx, alloc);
                }
                self.primary_list.ptr[idx] = val;
            }
            fn p_move(self: *Self, old_idx: usize, new_idx: usize, _: Allocator) void {
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

                var sort_reports: [SORT_COUNT]SortListReport = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = move_one_indirect_indexes(sort, old_idx, delta, smallest_other, largest_other, dir);
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
                    self.move_one_indirect_resort(sort, sort_reports[sort_idx], new_idx, smallest_other, largest_other, dir);
                }
            }
            fn p_move_range(self: *Self, range: IList.Range, new_first_idx: usize, _: Allocator) void {
                if (range.first_idx == new_first_idx) return;
                const rlen: usize = range.consecutive_len();
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
                    largest_shifted_down = (new_first_idx + rlen) - 1;
                    delta_up = (largest_shifted_down - smallest_shifted_down) + 1;
                    delta_down = rlen;
                } else {
                    smallest_shifted_up = new_first_idx;
                    largest_shifted_up = range.first_idx - 1;
                    smallest_shifted_down = range.first_idx;
                    largest_shifted_down = range.last_idx;
                    delta_up = rlen;
                    delta_down = (largest_shifted_up - smallest_shifted_up) + 1;
                }
                var sort_reports: [SORT_COUNT]SortListReport = undefined;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    sort_reports[sort_idx] = move_range_indirect_indexes(sort, smallest_shifted_up, largest_shifted_up, delta_up, smallest_shifted_down, largest_shifted_down, delta_down);
                }
                Utils.slice_move_many(self.primary_list.ptr[0..self.primary_list.len], range.first_idx, range.last_idx, new_first_idx);
                smallest_shifted_down -= delta_down;
                largest_shifted_down -= delta_down;
                smallest_shifted_up += delta_up;
                largest_shifted_up += delta_up;
                for (self.sort_lists[0..], 0..) |*sort, sort_idx| {
                    self.move_range_indirect_resort(sort, sort_reports[sort_idx], smallest_shifted_up, largest_shifted_up, smallest_shifted_down, largest_shifted_down);
                }
            }
            fn p_try_ensure_free_slots(self: *Self, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
                return self.primary_list.try_ensure_free_slots(count, alloc);
            }
            fn p_shrink_cap_reserve_at_most(self: *Self, reserve_at_most: usize, alloc: Allocator) void {
                self.primary_list.shrink_cap_reserve_at_most(reserve_at_most, alloc);
                for (self.sort_lists[0..]) |*sort| {
                    sort.idx_list.shrink_cap_reserve_at_most(reserve_at_most, alloc);
                }
            }
            fn p_append_slots_assume_capacity(self: *Self, count: usize, alloc: Allocator) IList.Range {
                return append_initialized_slots_assume_capacity(self, count, UNINIT, alloc);
            }
            fn p_insert_slots_assume_capacity(self: *Self, idx: usize, count: usize, alloc: Allocator) IList.Range {
                return insert_initialized_slots_assume_capacity(self, idx, count, UNINIT, alloc);
            }
            fn p_trim_len(self: *Self, trim_n: usize, _: Allocator) void {
                for (self.sort_lists[0..]) |*sort| {
                    delete_range_indirect_indexes(sort, .new_range(self.primary_list.len - trim_n, self.primary_list.len - 1), trim_n);
                }
                self.primary_list.len -= @intCast(trim_n);
            }
            fn p_delete(self: *Self, idx: usize, alloc: Allocator) void {
                if (idx == self.primary_list.len - 1) {
                    p_trim_len(self, 1, alloc);
                    return;
                }
                const range = Range.single_idx(idx);
                for (self.sort_lists[0..]) |*sort| {
                    delete_range_indirect_indexes(sort, range, 1);
                }
                Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, idx, 1);
            }
            fn p_delete_range(self: *Self, range: IList.Range, alloc: Allocator) void {
                const rlen = range.consecutive_len();
                if (range.last_idx == self.primary_list.len - 1) {
                    p_trim_len(self, rlen, alloc);
                    return;
                }
                const delete_count = range.consecutive_len();
                for (self.sort_lists[0..]) |*sort| {
                    delete_range_indirect_indexes(sort, range, delete_count);
                }
                Utils.mem_remove(self.primary_list.ptr, &self.primary_list.len, range.first_idx, delete_count);
            }
            fn p_clear(self: *Self, _: Allocator) void {
                self.primary_list.clear();
                for (self.sort_lists[0..]) |*sort| {
                    sort.idx_list.clear();
                }
            }
            fn p_free(self: *Self, alloc: Allocator) void {
                self.primary_list.free(alloc);
                for (self.sort_lists[0..]) |*sort| {
                    sort.idx_list.free(alloc);
                }
            }
        };
        const PFX = IList.Concrete.ConcreteTableValueFuncs(T, *Self, Allocator){
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
        const P = IList.Concrete.CreateConcretePrototypeNaturalIndexes(T, *Self, Allocator, "primary_list", "ptr", "primary_list", "len", "primary_list", "cap", false, PFX);
        const VTABLE = P.VTABLE(false, false, false, math.maxInt(usize));
        //*** END PROTOTYPE***

        pub fn interface(self: *Self, alloc: Allocator) IList.IList(T) {
            return IList.IList(T){
                .alloc = alloc,
                .object = @ptrCast(self),
                .vtable = &VTABLE,
            };
        }
        pub fn interface_no_alloc(self: *Self) IList.IList(T) {
            return IList.IList(T){
                .alloc = DummyAlloc.allocator_panic,
                .object = @ptrCast(self),
                .vtable = &VTABLE,
            };
        }

        /// Return the number of items in the list
        pub fn len_usize(self: *Self) usize {
            return P.len(self);
        }
        /// Reduce the number of items in the list by
        /// dropping/deleting them from the end of the list
        pub fn trim_len(self: *Self, trim_n: usize, alloc: Allocator) void {
            return P.trim_len(self, trim_n, alloc);
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
            return P.get(self, idx, NO_ALLOC);
        }
        /// Return a pointer to the value at a given index
        pub fn get_ptr(self: *Self, idx: usize) *T {
            return P.get_ptr(self, idx, NO_ALLOC);
        }
        /// Set the value at the given index
        pub fn set(self: *Self, idx: usize, val: T, alloc: Allocator) void {
            return P.set(self, idx, val, alloc);
        }
        /// Move one value to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move(self: *Self, old_idx: usize, new_idx: usize) void {
            return P.move(self, old_idx, new_idx, NO_ALLOC);
        }
        /// Move a range of values to a new location within the list,
        /// moving the values in between the old and new location
        /// out of the way while maintaining their order
        pub fn move_range(self: *Self, range: Range, new_first_idx: usize) void {
            return P.move_range(self, range, new_first_idx, NO_ALLOC);
        }
        /// Attempt to ensure at least 'n' free slots exist for adding new items,
        /// returning error `failed_to_grow_list` if adding `n` new items will
        /// definitely cause undefined behavior or some other error
        pub fn try_ensure_free_slots(self: *Self, count: usize, alloc: Allocator) error{failed_to_grow_list}!void {
            return P.try_ensure_free_slots(self, count, alloc);
        }
        /// Shrink capacity while reserving at most `n` free slots
        /// for new items. Will not shrink below list length, and
        /// does nothing if `n`is greater than the existing free space.
        pub fn shrink_cap_reserve_at_most(self: *Self, reserve_at_most: usize) void {
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
        pub fn free(self: *Self, alloc: Allocator) void {
            return P.free(self, alloc);
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
        pub fn ensure_free_slots(self: *Self, count: usize, alloc: Allocator) void {
            return P.ensure_free_slots(self, count, alloc);
        }
        pub fn append_slots(self: *Self, count: usize, alloc: Allocator) Range {
            return P.append_slots(self, count, alloc);
        }
        pub fn try_append_slots(self: *Self, count: usize, alloc: Allocator) ListError!Range {
            return P.try_append_slots(self, count, alloc);
        }
        pub fn append_zig_slice(self: *Self, alloc: Allocator, source: []const T) Range {
            return P.append_zig_slice(self, source, alloc);
        }
        pub fn try_append_zig_slice(self: *Self, alloc: Allocator, source: []const T) ListError!Range {
            return P.try_append_zig_slice(self, source, alloc);
        }
        pub fn append(self: *Self, val: T, alloc: Allocator) usize {
            return P.append(self, val, alloc);
        }
        pub fn try_append(self: *Self, val: T, alloc: Allocator) ListError!usize {
            return P.try_append(self, val, alloc);
        }
        pub fn append_many(self: *Self, alloc: Allocator, source: P.RangeIter) Range {
            return P.append_many(self, alloc, source);
        }
        pub fn try_append_many(self: *Self, alloc: Allocator, source: P.RangeIter) ListError!Range {
            return P.try_append_many(self, alloc, source);
        }
        pub fn insert_slots(self: *Self, idx: usize, count: usize, alloc: Allocator) Range {
            return P.insert_slots(self, idx, count, alloc);
        }
        pub fn try_insert_slots(self: *Self, idx: usize, count: usize, alloc: Allocator) ListError!Range {
            return P.try_insert_slots(self, idx, count, alloc);
        }
        pub fn insert_zig_slice(self: *Self, idx: usize, alloc: Allocator, source: []T) Range {
            return P.insert_zig_slice(self, idx, source, alloc);
        }
        pub fn try_insert_zig_slice(self: *Self, idx: usize, alloc: Allocator, source: []T) ListError!Range {
            return P.try_insert_zig_slice(self, idx, source, alloc);
        }
        pub fn insert(self: *Self, idx: usize, val: T, alloc: Allocator) usize {
            return P.insert(self, idx, val, alloc);
        }
        pub fn try_insert(self: *Self, idx: usize, val: T, alloc: Allocator) ListError!usize {
            return P.try_insert(self, idx, val, alloc);
        }
        pub fn insert_many(self: *Self, idx: usize, alloc: Allocator, source: P.RangeIter) Range {
            return P.insert_many(self, idx, alloc, source);
        }
        pub fn try_insert_many(self: *Self, idx: usize, alloc: Allocator, source: P.RangeIter) ListError!Range {
            return P.try_insert_many(self, idx, alloc, source);
        }
        pub fn try_delete_range(self: *Self, range: Range) ListError!void {
            return P.try_delete_range(self, range, NO_ALLOC);
        }
        pub fn delete_many(self: *Self, range: P.PartialRangeIter) void {
            return P.delete_many(self, range);
        }
        pub fn try_delete_many(self: *Self, range: P.PartialRangeIter) ListError!void {
            return P.try_delete_many(self, range);
        }
        pub fn try_delete(self: *Self, idx: usize) ListError!void {
            return P.try_delete(self, idx, NO_ALLOC);
        }
        pub fn swap_delete(self: *Self, idx: usize) void {
            return P.swap_delete(self, idx, NO_ALLOC);
        }
        pub fn try_swap_delete(self: *Self, idx: usize) ListError!void {
            return P.try_swap_delete(self, idx, NO_ALLOC);
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
            return P.remove(self, idx, NO_ALLOC);
        }
        pub fn try_remove(self: *Self, idx: usize) ListError!T {
            return P.try_remove(self, idx, NO_ALLOC);
        }
        pub fn swap_remove(self: *Self, idx: usize) T {
            return P.swap_remove(self, idx, NO_ALLOC);
        }
        pub fn try_swap_remove(self: *Self, idx: usize) ListError!T {
            return P.try_swap_remove(self, idx, NO_ALLOC);
        }
        pub fn pop(self: *Self) T {
            return P.pop(self, NO_ALLOC);
        }
        pub fn try_pop(self: *Self) ListError!T {
            return P.try_pop(self, NO_ALLOC);
        }
        pub fn pop_many(self: *Self, count: usize, dest: *Self, dest_alloc: Allocator) Range {
            return P.pop_many(self, count, NO_ALLOC, dest, dest_alloc);
        }
        pub fn try_pop_many(self: *Self, count: usize, dest: *Self, dest_alloc: Allocator) ListError!Range {
            return P.try_pop_many(self, count, NO_ALLOC, dest, dest_alloc);
        }
        pub fn sorted_insert(
            self: *Self,
            val: T,
            alloc: Allocator,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) usize {
            return P.sorted_insert(self, alloc, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_implicit(self: *Self, val: T, alloc: Allocator) usize {
            return P.sorted_insert_implicit(self, val, alloc);
        }
        pub fn sorted_insert_index(
            self: *Self,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) InsertIndexResult {
            return P.sorted_insert_index(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_insert_index_implicit(self: *Self, val: T) InsertIndexResult {
            return P.sorted_insert_index_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_search(
            self: *Self,
            val: T,
            equal_func: *const fn (this_val: T, find_val: T) bool,
            greater_than_func: *const fn (this_val: T, find_val: T) bool,
        ) SearchResult {
            return P.sorted_search(self, NO_ALLOC, val, equal_func, greater_than_func);
        }
        pub fn sorted_search_implicit(self: *Self, val: T) SearchResult {
            return P.sorted_search_implicit(self, val, NO_ALLOC);
        }
        pub fn sorted_set_and_resort(self: *Self, idx: usize, val: T, greater_than_func: *const fn (this_val: T, find_val: T) bool) usize {
            return P.sorted_set_and_resort(self, idx, val, NO_ALLOC, greater_than_func);
        }
        pub fn sorted_set_and_resort_implicit(self: *Self, idx: usize, val: T) usize {
            return P.sorted_set_and_resort_implicit(self, idx, val, NO_ALLOC);
        }
        pub fn search(self: *Self, find_val: anytype, equal_func: *const fn (this_val: T, find_val: @TypeOf(find_val)) bool) SearchResult {
            return P.search(self, find_val, NO_ALLOC, equal_func);
        }
        pub fn search_implicit(self: *Self, find_val: anytype) SearchResult {
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

        fn true_greater_than(self: *Self, sort: *SortList, a_val: T, a_idx: usize, b_val: T, b_idx: usize) bool {
            if (sort.greater_than.?(a_val, b_val, self.userdata)) return true;
            if (sort.equal(a_val, b_val, self.userdata)) return a_idx > b_idx;
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

        fn resort_up_many(self: *Self, sort: *SortList, idx_idx: usize) bool {
            var this_idx_idx = idx_idx;
            const this_idx = sort.idx_list.ptr[idx_idx];
            var this_val = self.primary_list.ptr[this_idx];
            var next_idx_idx = idx_idx + 1;
            var next_idx_: usize = undefined;
            var next_val: T = undefined;
            var moved: bool = false;
            while (next_idx_idx < sort.idx_list.len) {
                next_idx_ = @intCast(sort.idx_list.ptr[next_idx_idx]);
                next_val = self.primary_list.ptr[next_idx_];
                if (sort.greater_than.?(next_val, this_val, self.userdata) or next_idx_ >= this_idx) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx_);
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
            const next_idx_ = sort.idx_list.ptr[next_idx_idx];
            const next_val: T = self.primary_list.ptr[next_idx_];
            if (sort.greater_than.?(next_val, this_val, self.userdata) or next_idx_ >= this_idx) return false;
            sort.idx_list.ptr[this_idx_idx] = @intCast(next_idx_);
            sort.idx_list.ptr[next_idx_idx] = @intCast(this_idx);
            return true;
        }

        fn resort_down_many(self: *Self, sort: *SortList, idx_idx: usize) bool {
            var this_idx_idx = idx_idx;
            const this_idx = sort.idx_list.ptr[idx_idx];
            var this_val = self.primary_list.ptr[this_idx];
            var prev_idx_idx = idx_idx;
            var prev_idx_: usize = undefined;
            var prev_val: T = undefined;
            var moved: bool = false;
            while (this_idx_idx > 0) {
                prev_idx_idx -= 1;
                prev_idx_ = @intCast(sort.idx_list.ptr[prev_idx_idx]);
                prev_val = self.primary_list.ptr[prev_idx_];
                if (sort.greater_than.?(this_val, prev_val, self.userdata) or prev_idx_ <= this_idx) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx_);
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
            const prev_idx_ = sort.idx_list.ptr[prev_idx_idx];
            const prev_val: T = self.primary_list.ptr[prev_idx_];
            if (sort.greater_than.?(this_val, prev_val, self.userdata) or prev_idx_ <= this_idx) return false;
            sort.idx_list.ptr[this_idx_idx] = @intCast(prev_idx_);
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

        fn move_one_indirect_resort(self: *Self, sort: *SortList, list_report: SortListReport, moved_idx: usize, smallest_other_idx: usize, largest_other_idx: usize, dir: ShiftDirection) void {
            if (sort.greater_than == null) return;
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
        }

        fn move_range_indirect_resort(self: *Self, sort: *SortList, list_report: SortListReport, smallest_up_idx: usize, largest_up_idx: usize, smallest_down_idx: usize, largest_down_idx: usize) void {
            if (sort.greater_than == null) return;
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

        fn fix_indirect_value_changed(self: *Self, sort: *SortList, new_val: T, this_idx: usize, idx_idx: usize) usize {
            if (sort.greater_than == null) return idx_idx;
            var this_idx_idx = idx_idx;
            var adjacent_idx_idx: usize = undefined;
            var adjacent_idx: usize = undefined;
            var adjacent_val: T = undefined;
            const max_idx_idx = sort.idx_list.len - 1;
            while (this_idx_idx < max_idx_idx) {
                adjacent_idx_idx = this_idx_idx + 1;
                adjacent_idx = @intCast(sort.idx_list.ptr[adjacent_idx_idx]);
                adjacent_val = self.primary_list.ptr[adjacent_idx];
                if (!self.true_greater_than(sort, new_val, this_idx, adjacent_val, adjacent_idx)) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(adjacent_idx);
                this_idx_idx = adjacent_idx_idx;
            }
            while (this_idx_idx > 0) {
                adjacent_idx_idx = this_idx_idx - 1;
                adjacent_idx = @intCast(sort.idx_list.ptr[adjacent_idx_idx]);
                adjacent_val = self.primary_list.ptr[adjacent_idx];
                if (!self.true_greater_than(sort, adjacent_val, adjacent_idx, new_val, this_idx)) break;
                sort.idx_list.ptr[this_idx_idx] = @intCast(adjacent_idx);
                this_idx_idx = adjacent_idx_idx;
            }
            sort.idx_list.ptr[this_idx_idx] = @intCast(this_idx);
            return this_idx_idx;
        }

        fn match_by_index_direction(self: *Self, sort: *SortList, list_val: T, list_idx: usize, test_val: T, test_idx: usize) MatchDirection {
            if (list_idx == test_idx) return .MATCH;
            if (sort.greater_than.?(list_val, test_val, self.userdata)) return .SPLIT_LEFT;
            if (sort.greater_than.?(test_val, list_val, self.userdata)) return .SPLIT_RIGHT;
            if (list_idx > test_idx) return .SPLIT_LEFT;
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
            if (sort.greater_than == null) {
                var i: usize = 0;
                while (i < sort.idx_list.len) {
                    const this_idx = sort.idx_list.ptr[i];
                    if (this_idx == find_idx) {
                        return MatchIdx{ .idx = this_idx, .idx_idx = i, .found = true };
                    }
                    i += 1;
                }
                return MatchIdx{ .found = false };
            }
            var lo_idx_idx: usize = 0;
            var hi_idx_idx: usize = sort.idx_list.len - 1;
            var list_idx_idx: usize = undefined;
            var list_idx: usize = undefined;
            var list_val: T = undefined;
            var dir: MatchDirection = undefined;
            while (true) {
                list_idx_idx = Range.new_range(lo_idx_idx, hi_idx_idx).consecutive_split();
                list_idx = @intCast(sort.idx_list.ptr[list_idx_idx]);
                list_val = self.primary_list.ptr[list_idx];
                dir = self.match_by_index_direction(sort, list_val, list_idx, find_val, find_idx);
                switch (dir) {
                    .MATCH => return MatchIdx{ .idx = list_idx, .idx_idx = list_idx_idx },
                    .SPLIT_LEFT => {
                        if (list_idx_idx == lo_idx_idx) Assert.assert_unreachable(@src(), "val {any}, idx {d} was not found in sorted list when it should have been found", .{ find_val, find_idx });
                        hi_idx_idx = list_idx_idx - 1;
                    },
                    .SPLIT_RIGHT => {
                        if (list_idx_idx == hi_idx_idx) Assert.assert_unreachable(@src(), "val {any}, idx {d} was not found in sorted list when it should have been found", .{ find_val, find_idx });
                        lo_idx_idx = list_idx_idx + 1;
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
            var last_idx_: usize = 0;
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
                last_idx_ = @intCast(sort.idx_list.ptr[0]);
                idx_check_list.append(std.heap.page_allocator, @intCast(last_idx_)) catch unreachable;
                last_val = self.primary_list.ptr[last_idx_];
                for (sort.idx_list.ptr[1..sort.idx_list.len], 1..) |this_idx, this_idx_idx| {
                    Assert.assert_with_reason(this_idx < self.primary_list.len, src, "sort `{s}` had index `{d} that was out of bound for primary list (len = {d})`", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), this_idx, self.primary_list.len });
                    Assert.assert_with_reason(!std.mem.containsAtLeastScalar(IDX, idx_check_list.items, 1, this_idx), src, "sort `{s}` had duplicate of index {d}", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), this_idx });
                    idx_check_list.append(std.heap.page_allocator, this_idx) catch unreachable;
                    this_val = self.primary_list.ptr[this_idx];
                    if (T == u8) {
                        Assert.assert_with_reason(!sort.greater_than(last_val, this_val) and (!sort.equal(last_val, this_val) or last_idx_ < this_idx), src, "in sort `{s}`, the following values were out of order:\nIII: {d: >4} {d: >4}\nIDX: {d: >4} {d: >4}\nVAL: {d: >4} {d: >4}\n", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), last_idx_idx, this_idx_idx, last_idx_, this_idx, last_val, this_val });
                    } else {
                        Assert.assert_with_reason(!sort.greater_than(last_val, this_val) and (!sort.equal(last_val, this_val) or last_idx_ < this_idx), src, "in sort `{s}`, the following values were out of order:\nIII: {d: >4} {d: >4}\nIDX: {d: >4} {d: >4}\nVAL: {any} {any}\n", .{ @tagName(@as(SORT_NAMES, @enumFromInt(sort_tag))), last_idx_idx, this_idx_idx, last_idx_, this_idx, last_val, this_val });
                    }

                    last_idx_idx = this_idx_idx;
                    last_idx_ = this_idx;
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

        fn set_and_resort_indirect_with_result(self: *Self, sort: *SortList, old_val: T, new_val: T, idx: usize, alloc: Allocator) ?usize {
            const change = SortListChange.filter_old_new(sort.filter(old_val, self.userdata), sort.filter(new_val, self.userdata));
            switch (change) {
                .NEITHER_IN_SORT => {
                    return null;
                },
                .ADD_TO_SORT => {
                    const index = self.find_insert_location_indirect(sort, idx, new_val);
                    if (index.append) {
                        return sort.idx_list.append(@intCast(idx), alloc);
                    } else {
                        return sort.idx_list.insert(index.idx_idx, @intCast(idx), alloc);
                    }
                },
                .REMOVE_FROM_SORT => {
                    const index = self.match_by_index_indirect(sort, old_val, idx);
                    var sort_iface = sort.idx_list.interface(alloc);
                    sort_iface.delete(index.idx_idx);
                    return null;
                },
                .SET_AND_RESORT => {
                    if (sort.equal(old_val, new_val, self.userdata)) {
                        const location = self.match_by_index_indirect(sort, old_val, idx);
                        return location.idx_idx;
                    }
                    const old_location = self.match_by_index_indirect(sort, old_val, idx);
                    return self.fix_indirect_value_changed(sort, new_val, idx, old_location.idx_idx);
                },
            }
        }

        fn set_and_resort_indirect(self: *Self, sort: *SortList, old_val: T, new_val: T, idx: usize, alloc: Allocator) void {
            _ = self.set_and_resort_indirect_with_result(sort, old_val, new_val, idx, alloc);
        }

        fn set_and_resort_indirect_known_sort_idx_with_result(self: *Self, sort: *SortList, old_val: T, new_val: T, idx: usize, sort_idx: usize) ?usize {
            const change = SortListChange.filter_old_new(sort.filter(old_val), sort.filter(new_val));
            switch (change) {
                .REMOVE_FROM_SORT => {
                    sort.idx_list.delete(sort_idx);
                    return null;
                },
                .SET_AND_RESORT => {
                    if (sort.equal(old_val, new_val)) {
                        return sort_idx;
                    }
                    return self.fix_indirect_value_changed(sort, new_val, idx, sort_idx);
                },
                else => Assert.assert_unreachable(@src(), "expected known sort idx to be within sort list, but filter indicated it wasn't", .{}),
            }
        }

        fn set_and_resort_indirect_known_sort_idx(self: *Self, sort: *SortList, old_val: T, new_val: T, idx: usize, sort_idx: usize) void {
            _ = self.set_and_resort_indirect_known_sort_idx_with_result(sort, old_val, new_val, idx, sort_idx);
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
            if (sort.greater_than == null) return IndirectInsertLoc{
                .append = true,
                .idx_idx = sort.idx_list.len,
            };
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
                if (sort.greater_than.?(this_val, test_val, self.userdata)) {
                    if (this_idx_idx == lo) {
                        loc.idx_idx = this_idx_idx;
                        return loc;
                    }
                    hi = this_idx_idx - 1;
                } else if (sort.greater_than.?(test_val, this_val, self.userdata)) {
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

        fn add_uninit_range_indirect_indexes(sort: *SortList, insert_idx: usize, count: usize) void {
            for (sort.idx_list.slice(), 0..) |idx, idx_idx| {
                if (idx >= insert_idx) {
                    sort.idx_list.ptr[idx_idx] = idx + Types.intcast(count, IDX);
                }
            }
        }

        fn add_one_init_indirect_insert(self: *Self, sort: *SortList, insert_idx: usize, val: T, alloc: Allocator) void {
            if (sort.filter(val)) {
                const insert_idx_idx = self.find_insert_location_indirect(sort, insert_idx, val);
                const sort_iface = sort.idx_list.interface(alloc);
                var range: IList.Range = undefined;
                if (insert_idx_idx.append) {
                    range = sort_iface.append_slots(1);
                } else {
                    range = sort_iface.insert_slots(insert_idx_idx.idx_idx, 1);
                }
                sort.idx_list.ptr[range.first_idx] = @intCast(insert_idx);
            }
        }

        fn add_two_init_indirect_insert(self: *Self, sort: *SortList, idx1: usize, idx2: usize, val1: T, val2: T, alloc: Allocator) void {
            add_one_init_indirect_insert(self, sort, idx1, val1, alloc);
            add_one_init_indirect_insert(self, sort, idx2, val2, alloc);
        }

        fn add_uninit_range_indirect_insert(self: *Self, sort: *SortList, insert_idx: usize, count: usize, alloc: Allocator) void {
            if (sort.filter(UNINIT, self.userdata)) {
                const insert_idx_idx = self.find_insert_location_indirect(sort, insert_idx, UNINIT);
                const sort_iface = sort.idx_list.interface(alloc);
                var range: IList.Range = undefined;
                if (insert_idx_idx.append) {
                    range = sort_iface.append_slots(count);
                } else {
                    range = sort_iface.insert_slots(insert_idx_idx.idx_idx, count);
                }
                for (insert_idx..insert_idx + count, range.first_idx..range.last_idx + 1) |idx, idx_idx| {
                    sort.idx_list.ptr[idx_idx] = @intCast(idx);
                }
            }
        }

        // fn append_uninit_range_indirect(self: *Self, sort: *SortList, uninit_range: IList.Range, count: usize, alloc: Allocator) void {
        //     if (!sort.filter(UNINIT)) return;
        //     var self_iface = self.primary_list.interface(alloc);
        //     const sort_iface = sort.idx_list.interface(alloc);
        //     const idx = self_iface.sorted_insert_index_indirect(IDX, sort_iface, UNINIT, sort.equal, sort.greater_than);
        //     const sort_range = if (idx.append) sort_iface.append_slots(count) else sort_iface.insert_slots(idx.idx_idx, count);
        //     initialize_new_indexes_in_sort(sort, uninit_range, sort_range);
        // }

        fn delete_range_indirect_indexes(sort: *SortList, delete_range_: IList.Range, delete_count: usize) void {
            var write_idx_idx: usize = 0;
            var deleted: usize = 0;
            for (sort.idx_list.ptr[0..sort.idx_list.len]) |idx| {
                if (delete_range_.first_idx <= idx and idx <= delete_range_.last_idx) {
                    deleted += 1;
                } else {
                    var new_idx: IDX = idx;
                    if (idx > delete_range_.last_idx) {
                        new_idx -= @intCast(delete_count);
                    }
                    sort.idx_list.ptr[write_idx_idx] = new_idx;
                    write_idx_idx += 1;
                }
            }
            sort.idx_list.len -= @intCast(deleted);
        }

        fn delete_2_indirect_indexes(sort: *SortList, del_idx_1: usize, del_idx_2: usize) void {
            var write_idx_idx: usize = 0;
            var deleted: usize = 0;
            for (sort.idx_list.ptr[0..sort.idx_list.len]) |idx| {
                if (del_idx_1 == idx or del_idx_2 == idx) {
                    deleted += 1;
                } else {
                    var new_idx: IDX = idx;
                    if (idx > del_idx_1) {
                        new_idx -= 1;
                    }
                    if (idx > del_idx_2) {
                        new_idx -= 1;
                    }
                    sort.idx_list.ptr[write_idx_idx] = new_idx;
                    write_idx_idx += 1;
                }
            }
            sort.idx_list.len -= @intCast(deleted);
        }
        fn delete_1_indirect_indexes(sort: *SortList, del_idx_1: usize) void {
            var write_idx_idx: usize = 0;
            var deleted: usize = 0;
            for (sort.idx_list.ptr[0..sort.idx_list.len]) |idx| {
                if (del_idx_1 == idx) {
                    deleted += 1;
                } else {
                    var new_idx: IDX = idx;
                    if (idx > del_idx_1) {
                        new_idx -= 1;
                    }
                    sort.idx_list.ptr[write_idx_idx] = new_idx;
                    write_idx_idx += 1;
                }
            }
            sort.idx_list.len -= @intCast(deleted);
        }

        const ShiftDirection = enum(u8) {
            this_up__other_down,
            this_down__other_up,
        };
    };
}
