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
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const _Flags = Root.Flags;
const IList = Root.IList;
const Range = IList.Range;

const PITER_OVERWRITE = enum {
    none,
    first_idx,
    last_idx,
    nth_from_start,
    nth_from_end,
    nth_from_first,
    nth_from_last,
};

pub fn IteratorState(comptime T: type) type {
    return struct {
        const T_LIST = IList.IList(T);
        const IDX_LIST = IList.IList(usize);
        pub const Partial = struct {
            src: Source,
            overwrite_first: PITER_OVERWRITE = .none,
            overwrite_last: PITER_OVERWRITE = .none,
            want_count: usize = std.math.maxInt(usize),
            use_max: bool = false,
            forward: bool = true,

            pub fn with_max_count(self: Partial, max_count: usize) Partial {
                const iter = self;
                self.max_count = max_count;
                self.use_max = true;
                return iter;
            }

            pub fn in_reverse(self: Partial) Partial {
                const iter = self;
                self.forward = false;
                return iter;
            }

            pub fn one_index(idx: usize) Partial {
                return Partial{
                    .src = Source{ .range = .single_idx(idx) },
                };
            }
            pub fn new_range(first: usize, last: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(first, last) },
                };
            }
            pub fn new_range_max_count(first: usize, last: usize, max_count: usize) Partial {
                return new_range(first, last).with_max_count(max_count);
            }
            pub fn use_range(range: Range) Partial {
                return Partial{
                    .src = Source{ .range = range },
                };
            }
            pub fn use_range_max_count(range: Range, max_count: usize) Partial {
                return use_range(range).with_max_count(max_count);
            }
            pub fn entire_list() Partial {
                return Partial{
                    .src = Source{ .range = .new_range(0, 0) },
                    .overwrite_first = .first_idx,
                    .overwrite_last = .last_idx,
                };
            }
            pub fn entire_list_max_count(max_count: usize) Partial {
                return entire_list().with_max_count(max_count);
            }
            pub fn first_n_items(count: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(0, count - 1) },
                    .overwrite_first = .first_idx,
                    .overwrite_last = .nth_from_start,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn last_n_items(count: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(count - 1, 0) },
                    .overwrite_first = .nth_from_end,
                    .overwrite_last = .last_idx,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn start_idx_count_total(idx: usize, count: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(idx, count - 1) },
                    .overwrite_last = .nth_from_first,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn end_idx_count_total(idx: usize, count: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(count - 1, idx) },
                    .overwrite_first = .nth_from_last,
                    .want_count = count,
                    .use_max = true,
                };
            }
            pub fn start_to_idx(last: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(0, last) },
                    .overwrite_first = .first_idx,
                };
            }
            pub fn start_to_idx_max_count(last: usize, max_count: usize) Partial {
                return start_to_idx(last).with_max_count(max_count);
            }
            pub fn idx_to_end(first: usize) Partial {
                return Partial{
                    .src = Source{ .range = .new_range(first, 0) },
                    .overwrite_last = .last_idx,
                };
            }
            pub fn idx_to_end_max_count(first: usize, max_count: usize) Partial {
                return idx_to_end(first).with_max_count(max_count);
            }
            pub fn index_list(idx_list: IDX_LIST) Partial {
                return Partial{
                    .src = Source{ .list = idx_list },
                };
            }
            pub fn index_list_max_count(idx_list: IDX_LIST, max_count: usize) Partial {
                return index_list(idx_list).with_max_count(max_count);
            }
            pub fn zig_index_list(idx_list: *[]const usize) Partial {
                return Partial{
                    .src = Source{ .list = IList.list_from_slice(usize, idx_list) },
                };
            }
            pub fn zig_index_list_max_count(idx_list: *[]const usize, max_count: usize) Partial {
                return zig_index_list(idx_list).with_max_count(max_count);
            }
            pub fn one_index_rev(idx: usize) Partial {
                return one_index(idx).in_reverse();
            }
            pub fn new_range_rev(first: usize, last: usize) Partial {
                return new_range(first, last).in_reverse();
            }
            pub fn new_range_max_count_rev(first: usize, last: usize, max_count: usize) Partial {
                return new_range_max_count(first, last, max_count).in_reverse();
            }
            pub fn use_range_rev(range: Range) Partial {
                return use_range(range).in_reverse();
            }
            pub fn use_range_max_count_rev(range: Range, max_count: usize) Partial {
                return use_range_max_count(range, max_count).in_reverse();
            }
            pub fn entire_list_rev() Partial {
                return entire_list().in_reverse();
            }
            pub fn entire_list_max_count_rev(max_count: usize) Partial {
                return entire_list_max_count(max_count).in_reverse();
            }
            pub fn first_n_items_rev(count: usize) Partial {
                return first_n_items(count).in_reverse();
            }
            pub fn last_n_items_rev(count: usize) Partial {
                return last_n_items(count).in_reverse();
            }
            pub fn start_idx_count_total_rev(idx: usize, count: usize) Partial {
                return start_idx_count_total(idx, count).in_reverse();
            }
            pub fn end_idx_count_total_rev(idx: usize, count: usize) Partial {
                return end_idx_count_total(idx, count).in_reverse();
            }
            pub fn start_to_idx_rev(last: usize) Partial {
                return start_to_idx(last).in_reverse();
            }
            pub fn start_to_idx_max_count_rev(last: usize, max_count: usize) Partial {
                return start_to_idx_max_count(last, max_count).in_reverse();
            }
            pub fn idx_to_end_rev(first: usize) Partial {
                return idx_to_end_rev(first).in_reverse();
            }
            pub fn idx_to_end_max_count_rev(first: usize, max_count: usize) Partial {
                return idx_to_end_max_count(first, max_count).in_reverse();
            }
            pub fn index_list_rev(idx_list: IDX_LIST) Partial {
                return index_list(idx_list).in_reverse();
            }
            pub fn index_list_max_count_rev(idx_list: IDX_LIST, max_count: usize) Partial {
                return index_list_max_count(idx_list, max_count).in_reverse();
            }
            pub fn zig_index_list_rev(idx_list: *[]const usize) Partial {
                return zig_index_list(idx_list).in_reverse();
            }
            pub fn zig_index_list_max_count_rev(idx_list: *[]const usize, max_count: usize) Partial {
                return zig_index_list_max_count(idx_list, max_count).in_reverse();
            }

            pub fn to_iter(self: Partial, list: T_LIST) Full {
                var iter = Full{
                    .list = list,
                    .src = self.src,
                    .max_count = self.want_count,
                    .use_max = self.use_max,
                    .done = self.use_max and self.want_count == 0,
                    .forward = self.forward,
                    .prev_idx = list.vtable.always_invalid_idx,
                };
                switch (self.src) {
                    .range => |rng| {
                        var new_rng = rng;
                        switch (self.overwrite_first) {
                            .none => {},
                            .first_idx => {
                                new_rng.first_idx = list.first_idx();
                            },
                            .last_idx => {
                                new_rng.first_idx = list.last_idx();
                            },
                            .nth_from_start => {
                                new_rng.first_idx = list.nth_idx(rng.first_idx);
                            },
                            .nth_from_end => {
                                new_rng.first_idx = list.nth_idx_from_end(rng.first_idx);
                            },
                            .nth_from_first => {
                                new_rng.first_idx = list.nth_next_idx(rng.first_idx, rng.first_idx);
                            },
                            .nth_from_last => {
                                new_rng.first_idx = list.nth_prev_idx(rng.last_idx, rng.first_idx);
                            },
                        }
                        switch (self.overwrite_last) {
                            .none => {},
                            .first_idx => {
                                new_rng.last_idx = list.first_idx();
                            },
                            .last_idx => {
                                new_rng.last_idx = list.last_idx();
                            },
                            .nth_from_start => {
                                new_rng.last_idx = list.nth_idx(rng.last_idx);
                            },
                            .nth_from_end => {
                                new_rng.last_idx = list.nth_idx_from_end(rng.last_idx);
                            },
                            .nth_from_first => {
                                new_rng.last_idx = list.nth_next_idx(rng.first_idx, rng.last_idx);
                            },
                            .nth_from_last => {
                                new_rng.last_idx = list.nth_prev_idx(rng.last_idx, rng.last_idx);
                            },
                        }
                        iter.src = new_rng;
                        if (self.forward) {
                            iter.curr_idx = new_rng.first_idx;
                        } else {
                            iter.curr_idx = new_rng.last_idx;
                        }
                    },
                    .list => |lst| {
                        if (self.forward) {
                            iter.curr_idx = lst.first_idx();
                        } else {
                            iter.curr_idx = lst.last_idx();
                        }
                        iter.done = iter.done or lst.len() == 0;
                    },
                }
            }
        };

        pub const Full = struct {
            list: T_LIST,
            src: Source,
            curr_idx: usize = 0,
            prev_idx: usize = 0,
            count: usize = 0,
            max_count: usize = std.math.maxInt(usize),
            err: ?IList.ListError = null,
            use_max: bool = false,
            forward: bool = true,

            pub fn with_max_count(self: Full, max_count: usize) Full {
                const iter = self;
                self.max_count = max_count;
                self.use_max = true;
                return iter;
            }

            pub fn in_reverse(self: Full) Full {
                const iter = self;
                self.forward = false;
                return iter;
            }

            pub fn one_index(list: T_LIST, idx: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .single_idx(idx) },
                    .curr = idx,
                };
            }
            pub fn new_range(list: T_LIST, first: usize, last: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(first, last) },
                    .curr = first,
                };
            }
            pub fn new_range_max_count(list: T_LIST, first: usize, last: usize, max_count: usize) Full {
                return new_range(list, first, last).with_max_count(max_count);
            }
            pub fn use_range(list: T_LIST, range: Range) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = range },
                    .curr = range.first_idx,
                };
            }
            pub fn use_range_max_count(list: T_LIST, range: Range, max_count: usize) Full {
                return use_range(list, range).with_max_count(max_count);
            }
            pub fn entire_list(list: T_LIST) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.first_idx(),
                };
            }
            pub fn entire_list_max_count(list: T_LIST, max_count: usize) Full {
                return entire_list(list).with_max_count(max_count);
            }
            pub fn first_n_items(list: T_LIST, count: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(list.first_idx(), list.nth_idx(count - 1)) },
                    .curr = list.first_idx(),
                    .max_count = count,
                    .use_max = true,
                };
            }
            pub fn last_n_items(list: T_LIST, count: usize) Full {
                const idx = list.nth_idx_from_end(count - 1);
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(idx, list.last_idx()) },
                    .curr = idx,
                    .max_count = count,
                    .use_max = true,
                };
            }
            pub fn start_idx_count_total(list: T_LIST, idx: usize, count: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(idx, list.nth_next_idx(count - 1)) },
                    .curr = idx,
                    .max_count = count,
                    .use_count = true,
                };
            }
            pub fn end_idx_count_total(list: T_LIST, idx: usize, count: usize) Full {
                const fidx = list.nth_prev_idx(idx, count - 1);
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(fidx, idx) },
                    .curr = fidx,
                    .max_count = count,
                    .use_count = true,
                };
            }
            pub fn start_to_idx(list: T_LIST, last: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(list.first_idx(), last) },
                    .curr = list.first_idx(),
                };
            }
            pub fn start_to_idx_max_count(list: T_LIST, last: usize, max_count: usize) Full {
                return start_to_idx(list, last).with_max_count(max_count);
            }
            pub fn idx_to_end(list: T_LIST, first: usize) Full {
                return Full{
                    .list = list,
                    .src = Source{ .range = .new_range(first, list.last_idx()) },
                    .curr = first,
                };
            }
            pub fn idx_to_end_max_count(list: T_LIST, first: usize, max_count: usize) Full {
                return idx_to_end(list, first).with_max_count(max_count);
            }
            pub fn index_list(list: T_LIST, idx_list: IDX_LIST) Full {
                return Full{
                    .list = list,
                    .src = Source{ .list = idx_list },
                    .curr_ref = idx_list.first_idx(),
                    .done = idx_list.len() == 0,
                };
            }
            pub fn index_list_max_count(list: T_LIST, idx_list: IDX_LIST, max_count: usize) Full {
                return index_list(list, idx_list).with_max_count(max_count);
            }
            pub fn zig_index_list(list: T_LIST, idx_list: *[]const usize) Full {
                var llist = IList.list_from_slice(usize, idx_list);
                return Full{
                    .list = list,
                    .src = Source{ .list = llist },
                    .curr_ref = llist.first_idx(),
                    .done = llist.len() == 0,
                };
            }
            pub fn zig_index_list_max_count(list: T_LIST, idx_list: *[]const usize, max_count: usize) Full {
                return zig_index_list(list, idx_list).with_max_count(max_count);
            }
            pub fn one_index_rev(list: T_LIST, idx: usize) Full {
                return one_index(list, idx).in_reverse();
            }
            pub fn new_range_rev(list: T_LIST, first: usize, last: usize) Full {
                return new_range(list, first, last).in_reverse();
            }
            pub fn new_range_max_count_rev(list: T_LIST, first: usize, last: usize, max_count: usize) Full {
                return new_range_max_count(list, first, last, max_count).in_reverse();
            }
            pub fn use_range_rev(list: T_LIST, range: Range) Full {
                return use_range(list, range).in_reverse();
            }
            pub fn use_range_max_count_rev(list: T_LIST, range: Range, max_count: usize) Full {
                return use_range_max_count(list, range, max_count).in_reverse();
            }
            pub fn entire_list_rev(list: T_LIST) Full {
                return entire_list(list).in_reverse();
            }
            pub fn entire_list_max_count_rev(list: T_LIST, max_count: usize) Full {
                return entire_list_max_count(list, max_count).in_reverse();
            }
            pub fn first_n_items_rev(list: T_LIST, count: usize) Full {
                return first_n_items(list, count).in_reverse();
            }
            pub fn last_n_items_rev(list: T_LIST, count: usize) Full {
                return last_n_items(list, count).in_reverse();
            }
            pub fn start_idx_count_total_rev(list: T_LIST, idx: usize, count: usize) Full {
                return start_idx_count_total(list, idx, count).in_reverse();
            }
            pub fn end_idx_count_total_rev(list: T_LIST, idx: usize, count: usize) Full {
                return end_idx_count_total(list, idx, count).in_reverse();
            }
            pub fn start_to_idx_rev(list: T_LIST, last: usize) Full {
                return start_to_idx(list, last).in_reverse();
            }
            pub fn start_to_idx_max_count_rev(list: T_LIST, last: usize, max_count: usize) Full {
                return start_to_idx_max_count(list, last, max_count).in_reverse();
            }
            pub fn idx_to_end_rev(list: T_LIST, first: usize) Full {
                return idx_to_end(list, first).in_reverse();
            }
            pub fn idx_to_end_max_count_rev(list: T_LIST, first: usize, max_count: usize) Full {
                return idx_to_end_max_count(list, first, max_count).in_reverse();
            }
            pub fn index_list_rev(list: T_LIST, idx_list: IDX_LIST) Full {
                return index_list(list, idx_list).in_reverse();
            }
            pub fn index_list_max_count_rev(list: T_LIST, idx_list: IDX_LIST, max_count: usize) Full {
                return index_list_max_count(list, idx_list, max_count).in_reverse();
            }
            pub fn zig_index_list_rev(list: T_LIST, idx_list: *[]const usize) Full {
                return zig_index_list(list, idx_list).in_reverse();
            }
            pub fn zig_index_list_max_count_rev(list: T_LIST, idx_list: *[]const usize, max_count: usize) Full {
                return zig_index_list_max_count(list, idx_list, max_count).in_reverse();
            }

            pub fn first_idx(self: *Full) usize {
                switch (self.src) {
                    .range => |rng| {
                        return rng.first_idx;
                    },
                    .list => |lst| {
                        return lst.get_first();
                    },
                }
            }
            pub fn last_idx(self: *Full) usize {
                switch (self.src) {
                    .range => |rng| {
                        return rng.last_idx;
                    },
                    .list => |lst| {
                        return lst.get_last();
                    },
                }
            }

            // pub fn has_next(self: *Full) bool {
            //     switch (self.src) {
            //         .range => {
            //             return self.list.idx_valid(self.curr_idx);
            //         },
            //         .list => |lst| {
            //             return self.list.idx_valid(lst.get(self.curr_idx));
            //         },
            //     }
            // }

            // pub fn has_prev(self: *Full) bool {
            //     switch (self.src) {
            //         .range => {
            //             return self.list.idx_valid(self.list.prev_idx(self.curr_idx));
            //         },
            //         .list => |lst| {
            //             return self.list.idx_valid(lst.get(lst.prev_idx(self.curr_idx)));
            //         },
            //     }
            //     return self.list.idx_valid(self.list.prev_idx(self.curr_idx));
            // }

            pub fn next(self: *Full) ?Item {
                return self.next_advanced(.no_filter, null, null);
            }
            fn _check_source_list(item: Item, userdata: _check_source_data) bool {
                if (item.list.idx_valid(!userdata.list.idx_valid(item.val))) {
                    userdata.valid = false;
                    return false;
                }
                return true;
            }
            const _check_source_data = struct {
                valid: *bool,
                list: T_LIST,
            };
            pub fn check_source(self: *Full) IList.ListError!void {
                switch (self.src) {
                    .range => |rng| {
                        if (!self.list.range_valid(rng)) {
                            return IList.ListError.invalid_range;
                        }
                    },
                    .list => |lst| {
                        var valid: bool = true;
                        const data = _check_source_data{
                            .valid = &valid,
                            .list = self.list,
                        };
                        lst.for_each(.entire_list(), data, _check_source_list);
                        if (!valid) {
                            return IList.ListError.invalid_index;
                        }
                    },
                }
            }
            pub fn next_advanced(self: *Full, comptime filter_mode: IList.FilterMode, userdata: anytype, filter_func: ?*const fn (item: Item, userdata: @TypeOf(userdata)) bool) ?Item {
                var val_idx: usize = undefined;
                var got_item: bool = false;
                var item: Item = undefined;
                while (!got_item) {
                    switch (self.src) {
                        .range => |rng| {
                            if (!self.list.idx_valid(self.curr_idx)) {
                                return null;
                            }
                            if (self.list.idx_valid(self.prev_idx)) {
                                if (self.forward) {
                                    if (self.prev_idx == rng.last_idx) {
                                        return null;
                                    }
                                } else {
                                    if (self.prev_idx == rng.first_idx) {
                                        return null;
                                    }
                                }
                            }
                            val_idx = self.curr_idx;
                            self.prev_idx = self.curr_idx;
                            if (self.forward) {
                                self.curr_idx = self.list.next_idx(self.curr_idx);
                            } else {
                                self.curr_idx = self.list.prev_idx(self.curr_idx);
                            }
                        },
                        .list => |idx_list| {
                            if (!idx_list.idx_valid(self.curr_idx)) {
                                return null;
                            }
                            if (idx_list.idx_valid(self.prev_idx)) {
                                if (self.forward) {
                                    if (self.prev_idx == idx_list.last_idx()) {
                                        return null;
                                    }
                                } else {
                                    if (self.prev_idx == idx_list.first_idx()) {
                                        return null;
                                    }
                                }
                            }
                            val_idx = idx_list.get(self.curr_idx);
                            if (!self.list.idx_valid(val_idx)) {
                                return null;
                            }
                            self.prev_idx = self.curr_idx;
                            if (self.forward) {
                                self.curr_idx = idx_list.next_idx(self.curr_idx);
                            } else {
                                self.curr_idx = idx_list.prev_idx(self.curr_idx);
                            }
                        },
                    }
                    item = Item{
                        .list = self.list,
                        .idx = val_idx,
                        .val = self.list.get(val_idx),
                    };
                    if (filter_mode == .use_filter) {
                        if (filter_func) |filter| {
                            got_item = filter(item, userdata);
                        } else {
                            @panic("filter_mode == .use_filter, but filter_func == null");
                        }
                    } else {
                        got_item = true;
                    }
                }
                return item;
            }
            pub fn count_result(self: Full) IList.CountResult {
                return IList.CountResult{
                    .count = self.count,
                    .count_matches_expected = self.count == self.max_count,
                    .next_idx = self.curr,
                };
            }
        };
        pub const Source = union(enum(u8)) {
            range: Range,
            list: IDX_LIST,
        };
        pub const Item = struct {
            list: T_LIST,
            idx: usize,
            val: T,
        };
    };
}
