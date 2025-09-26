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
const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;

pub const ListError = error{
    list_is_empty,
    index_out_of_bounds,
    invalid_index,
    invalid_range,
    no_items_after,
    no_items_before,
    failed_to_grow_list,
};

pub fn IList(comptime T: type, comptime PTR: type, comptime IDX: type) type {
    Assert.assert_with_reason(Types.type_is_int(IDX), @src(), ": type IDX must be an integer type, got type {s}", @typeName(IDX));
    return struct {
        const Self = @This();

        object: *anyopaque,
        vtable: *const VTable,

        pub const PartialIterator = struct {
            src: IteratorSource,
            overwrite_first: bool = false,
            overwrite_last: bool = false,
            want_count: IDX = std.math.maxInt(IDX),

            pub fn one_index(idx: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .single = idx },
                    .want_count = 1,
                };
            }
            pub fn new_range(first: IDX, last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn new_range_max_count(first: IDX, last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .want_count = max_count,
                };
            }
            pub fn use_range(range: Range) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn use_range_max_count(range: Range, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = range },
                    .want_count = max_count,
                };
            }
            pub fn entire_list() PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn entire_list_max_count(max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, 0) },
                    .overwrite_first = true,
                    .overwrite_last = true,
                    .want_count = max_count,
                };
            }
            pub fn start_to_idx(last: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn start_to_idx_max_count(last: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(0, last) },
                    .overwrite_first = true,
                    .want_count = max_count,
                };
            }
            pub fn idx_to_end(first: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn idx_to_end_max_count(first: IDX, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .range = .new_range(first, 0) },
                    .overwrite_first = true,
                    .want_count = max_count,
                };
            }
            pub fn index_list(idx_list: IIdxList) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn index_list_max_count(idx_list: IIdxList, max_count: IDX) PartialIterator {
                return PartialIterator{
                    .src = IteratorSource{ .list = idx_list },
                    .want_count = max_count,
                };
            }

            pub fn to_iter(self: PartialIterator, list: Self) Iterator {
                var iter = Iterator{
                    .list = list,
                    .src = self.src,
                    .want_count = self.want_count,
                    .done = self.want_count == 0,
                };
                switch (self.src) {
                    .single => |idx| {
                        iter.curr = idx;
                    },
                    .range => |rng| {
                        var new_rng = rng;
                        if (self.overwrite_first) {
                            new_rng.first_idx = list.first_idx();
                        }
                        if (self.overwrite_last) {
                            new_rng.last_idx = list.last_idx();
                        }
                        iter.src = new_rng;
                        iter.curr = new_rng.first_idx;
                    },
                    .list => |lst| {
                        iter.curr_ref = lst.first_idx();
                    },
                }
            }
        };
        pub const Iterator = struct {
            list: Self,
            src: IteratorSource,
            curr: IDX = 0,
            curr_ref: IDX = 0,
            count: IDX = 0,
            want_count: IDX = std.math.maxInt(IDX),
            done: bool = false,
            more_values: bool = false,
            err: ?ListError = null,

            pub fn one_index(list: Self, idx: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .single = idx },
                    .curr = idx,
                    .want_count = 1,
                };
            }
            pub fn new_range(list: Self, first: IDX, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = first,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn new_range_max_count(list: Self, first: IDX, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, last) },
                    .curr = first,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn use_range(list: Self, range: Range) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.first_idx,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn use_range_max_count(list: Self, range: Range, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = range },
                    .curr = range.first_idx,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn entire_list(list: Self) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn entire_list_max_count(list: Self, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), list.last_idx()) },
                    .curr = list.first_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn start_to_idx(list: Self, last: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn start_to_idx_max_count(list: Self, last: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(list.first_idx(), last) },
                    .curr = list.first_idx(),
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn idx_to_end(list: Self, first: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = first,
                    .want_count = std.math.maxInt(IDX),
                };
            }
            pub fn idx_to_end_max_count(list: Self, first: IDX, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .range = .new_range(first, list.last_idx()) },
                    .curr = first,
                    .want_count = max_count,
                    .done = max_count == 0,
                };
            }
            pub fn index_list(list: Self, idx_list: IIdxList) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.first_idx(),
                    .want_count = std.math.maxInt(IDX),
                    .done = idx_list.len() == 0,
                };
            }
            pub fn index_list_max_count(list: Self, idx_list: IIdxList, max_count: IDX) Iterator {
                return Iterator{
                    .list = list,
                    .src = IteratorSource{ .list = idx_list },
                    .curr_ref = idx_list.first_idx(),
                    .want_count = max_count,
                    .done = @min(idx_list.len(), max_count) == 0,
                };
            }

            pub fn next(self: *Iterator) ?IteratorItem {
                return self.next_advanced(.no_count_limit, .no_error_checks, .advance, .no_filter, null, null);
            }
            pub const IterCount = enum {
                no_count_limit,
                use_count_limit,
            };
            pub const IterCheck = enum {
                no_error_checks,
                error_checks,
            };
            pub const IterFilter = enum { no_filter, use_filter };
            pub const IterAdvance = enum {
                advance,
                dont_advance,
            };
            pub const IterSelect = enum {
                select,
                skip,
                stop_return_null,
                stop_return_item,
            };
            pub fn next_advanced(self: *Iterator, comptime count_limit: IterCount, comptime error_checks: IterCheck, comptime advance: IterAdvance, comptime filter_mode: IterFilter, userdata: anytype, filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) IterSelect) ?IteratorItem {
                switch (self.src) {
                    .single => |idx| {
                        if (!self.done) {
                            if (error_checks == .error_checks and !self.list.idx_valid(idx)) {
                                self.err = ListError.invalid_index;
                                return null;
                            }
                            if (advance == .advance) {
                                self.count = 1;
                                self.done = true;
                                self.more_values = false;
                            }
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = idx,
                                .val = self.list.get(idx),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .select, .stop_return_item => {
                                        return item;
                                    },
                                    .skip, .stop_return_null => {
                                        return null;
                                    },
                                }
                            }
                            return item;
                        }
                        return null;
                    },
                    .range => |rng| {
                        if (error_checks == .error_checks and self.count == 0 and !self.list.range_valid(rng)) {
                            self.err = ListError.invalid_range;
                            return null;
                        }
                        while (!self.done) {
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = self.curr,
                                .val = self.list.get(self.curr),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .skip => {
                                        if (advance == .advance) {
                                            if (self.curr == rng.last_idx) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                            self.curr = self.list.next_idx(self.curr);
                                        }
                                    },
                                    .select,
                                    => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (self.curr == rng.last_idx) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                            if (count_limit == .use_count_limit and self.count == self.want_count) {
                                                self.done = true;
                                            }
                                            self.curr = self.list.next_idx(self.curr);
                                        }
                                        return item;
                                    },
                                    .stop_return_item => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (self.curr == rng.last_idx) {
                                                self.more_values = false;
                                            }
                                            self.curr = self.list.next_idx(self.curr);
                                        }
                                        self.done = true;
                                        return item;
                                    },
                                    .stop_return_null => {
                                        self.done = true;
                                        return null;
                                    },
                                }
                            } else {
                                if (advance == .advance) {
                                    self.count += 1;
                                    if (self.curr == rng.last_idx) {
                                        self.done = true;
                                        self.more_values = false;
                                    }
                                    if (count_limit == .use_count_limit and self.count == self.want_count) {
                                        self.done = true;
                                    }
                                    self.curr = self.list.next_idx(self.curr);
                                }
                                return item;
                            }
                        }
                        return null;
                    },
                    .list => |idx_list| {
                        while (!self.done) {
                            self.curr = idx_list.get(self.curr_ref);
                            if (error_checks == .error_checks and !self.list.idx_valid(self.curr)) {
                                self.err = ListError.invalid_index;
                                return null;
                            }
                            const item = IteratorItem{
                                .list = self.list,
                                .idx = self.curr,
                                .val = self.list.get(self.curr),
                            };
                            if (filter_mode == .use_filter) {
                                const sel = filter_func.?(item, userdata);
                                switch (sel) {
                                    .skip => {
                                        if (advance == .advance) {
                                            self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                        }
                                    },
                                    .select,
                                    => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            if (count_limit == .use_count_limit and self.count == self.want_count) {
                                                self.done = true;
                                            }
                                            self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.done = true;
                                                self.more_values = false;
                                            }
                                        }
                                        return item;
                                    },
                                    .stop_return_item => {
                                        if (advance == .advance) {
                                            self.count += 1;
                                            self.curr_ref = idx_list.next_idx(self.curr_ref);
                                            if (!idx_list.idx_valid(self.curr_ref)) {
                                                self.more_values = false;
                                            }
                                        }
                                        self.done = true;
                                        return item;
                                    },
                                    .stop_return_null => {
                                        self.done = true;
                                        return null;
                                    },
                                }
                            } else {
                                if (advance == .advance) {
                                    self.count += 1;
                                    if (count_limit == .use_count_limit and self.count == self.want_count) {
                                        self.done = true;
                                    }
                                    self.curr_ref = idx_list.next_idx(self.curr_ref);
                                    if (!idx_list.idx_valid(self.curr_ref)) {
                                        self.done = true;
                                        self.more_values = false;
                                    }
                                }
                                return item;
                            }
                        }
                        return null;
                    },
                }
            }
            pub fn count_result(self: Iterator) CountResult {
                return CountResult{
                    .count = self.count,
                    .count_matches_input = self.count == self.want_count,
                    .next_idx = self.curr,
                };
            }
        };
        pub const IteratorSource = union(enum(u8)) {
            single: IDX,
            range: Range,
            list: IIdxList,
        };
        pub const IteratorItem = struct {
            list: Self,
            idx: IDX,
            val: T,
        };
        pub const IndexSourceResult = struct {
            idx: IDX,
            idx_idx: IDX,
            nth: IDX,
            val: T,
            valid: bool,
            err: ListError,
        };
        pub const Range = struct {
            first_idx: IDX = 0,
            last_idx: IDX = 0,

            pub fn new_range(first: IDX, last: IDX) Range {
                return Range{
                    .first_idx = first,
                    .last_idx = last,
                };
            }
            pub fn single_idx(idx: IDX) Range {
                return Range{
                    .first_idx = idx,
                    .last_idx = idx,
                };
            }
            pub fn entire_list(list: Self) Range {
                return Range{
                    .first_idx = list.first_idx(),
                    .last_idx = list.last_idx(),
                };
            }
            pub fn first_idx_to_list_end(list: Self, first_idx_: IDX) Range {
                return Range{
                    .first_idx = first_idx_,
                    .last_idx = list.last_idx(),
                };
            }
            pub fn list_start_to_last_idx(list: Self, last_idx_: IDX) Range {
                return Range{
                    .first_idx = list.first_idx(),
                    .last_idx = last_idx_,
                };
            }
        };
        pub const CountResult = struct {
            count: IDX = 0,
            count_matches_input: bool = false,
            next_idx: IDX = 0,
        };
        pub fn AccumulateResult(comptime out: type) type {
            return struct {
                count_result: CountResult,
                final_accumulation: out,
            };
        }
        pub const CopyResult = struct {
            count: IDX = 0,
            next_source_idx: IDX = 0,
            next_dest_idx: IDX = 0,
            count_matches_input: bool = false,
            full_source_copied: bool = false,
            full_dest_copied: bool = false,
        };
        pub const SwizzleResult = struct {
            count: IDX = 0,
            next_dest_idx: IDX = 0,
            count_matches_input: bool = false,
            all_selectors_done: bool = false,
            full_dest_copied: bool = false,
        };

        pub const CompareFunc = fn (left_or_this: T, right_or_test: T) bool;
        pub const IIdxList = IList(IDX, *IDX, IDX);
        pub const IListList = IList(Self, *Self, IDX);
        fn _fn_none_ret_bool_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn () OUT {
            const proto = struct {
                const func = fn () OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, idx: IDX) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, idx: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, rng: Range) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, rng: Range) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, idx: IDX, idx2: IDX) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, idx: IDX, idx2: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_range_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, rng: Range, idx: IDX) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, rng: Range, idx: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_idx_idx_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, idx: IDX, idx2: IDX, idx3: IDX) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, idx: IDX, idx2: IDX, idx3: IDX) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        fn _fn_self_idx_val_panic(comptime fn_name: []const u8, comptime OUT: type) *const fn (self: *anyopaque, idx: IDX, val: T) OUT {
            const proto = struct {
                const func = fn (self: *anyopaque, idx: IDX, val: T) OUT{@panic("IList." ++ fn_name ++ "(): not implemented")};
            };
            return &proto.func;
        }
        pub const VTable = struct {
            /// Should return a constant boolean value describing whether
            /// certain operations will peform better with linear operations
            /// instead of binary-split operations
            ///
            /// If `range_len()`, `nth_next_idx()`, and `nth_prev_idx()` operate in O(N) time
            /// instead of O(1), this should return true
            ///
            /// An example requiring `true` would be a linked list, where one must
            /// traverse in linear time to find the true index 'n places' after a given index,
            /// or the number of items between two indexes
            ///
            /// Returning the correct value will allow some operations to use alternate,
            /// more efficient algorithms
            prefer_linear_ops: *const fn () bool = _fn_none_ret_bool_panic("prefer_linear_ops", bool),
            /// Should return a constant boolean value describing whether consecutive indexes,
            /// (eg. `0, 1, 2, 3, 4, 5`) are in their logical/proper order (not necessarily sorted)
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            consecutive_indexes_in_order: *const fn () bool = _fn_none_ret_bool_panic("consecutive_indexes_in_order", bool),
            /// Should return a constant boolean value describing whether all indexes greater-than-or-equal-to
            /// `0` AND less-than `slice.len()` are valid
            ///
            /// An example of this being true is the standard slice `[]T` and `SliceAdapter[T]`
            ///
            /// An example where this would be false is an implementation of a linked list
            ///
            /// This allows some algorithms to use more efficient paths
            all_indexes_zero_to_len_valid: *const fn () bool = _fn_none_ret_bool_panic("all_indexes_zero_to_len_valid", bool),
            /// Returns whether the given index is valid for the slice
            idx_valid: *const fn (self: *anyopaque, idx: IDX) bool = _fn_self_idx_panic("idx_valid", bool),
            /// Returns whether the given index range is valid for the slice
            ///
            /// The following MUST be true:
            ///   - `first_idx` comes logically before OR is equal to `last_idx`
            ///   - all indexes including and between `first_idx` and `last_idx` are valid for the slice
            range_valid: *const fn (self: *anyopaque, range: Range) bool = _fn_self_idx_idx_panic("range_valid", bool),
            /// Split an index range (roughly) in half, returning the index in the middle of the range
            ///
            /// Assumes `range_valid(first_idx, last_idx) == true`, and if so,
            /// the returned index MUST also be valid and MUST be between or equal to the first and/or last index
            ///
            /// The implementation should endeavor to return an index as close to the true middle index
            /// as possible, but it is not required to as long as the returned index IS between or equal to
            /// the first and/or last indexes. HOWEVER, some algorithms will have inconsitent performance
            /// if the returned index is far from the true middle index
            split_range: *const fn (self: *anyopaque, range: Range) IDX = _fn_self_range_panic("split_range", IDX),
            /// get the value at the provided index
            get: *const fn (self: *anyopaque, idx: IDX) T = _fn_self_idx_panic("get", T),
            /// get a pointer to the value at the provided index
            get_ptr: *const fn (self: *anyopaque, idx: IDX) PTR = _fn_self_idx_panic("get_ptr", PTR),
            /// set the value at the provided index to the given value
            set: *const fn (self: *anyopaque, idx: IDX, val: T) void = _fn_self_idx_val_panic("set", void),
            /// move the data located at `old_idx` to `new_idx`, shifting all
            /// values in between either up or down
            move: *const fn (self: *anyopaque, old_idx: IDX, new_idx: IDX) void = _fn_self_idx_idx_panic("move", void),
            /// move the data from located between and including `first_idx` and `last_idx`,
            /// to the position `newfirst_idx`, shifting the values at that location out of the way
            move_range: *const fn (self: *anyopaque, range: Range, new_first_idx: IDX) void = _fn_self_range_idx_panic("move_range", void),
            /// Return another `IList(T, PTR, IDX)` that holds values in range [first, last] (inclusive)
            ///
            /// Analogous to slice[first..last+1]
            ///
            /// Returned slice may or may not have full list capabilites, dependant on implementation
            slice: *const fn (self: *anyopaque, range: Range) Self = _fn_self_range_panic("slice", Self),
            /// Return the first index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            first_idx: *const fn (self: *anyopaque) IDX = _fn_self_panic("first_idx", IDX),
            /// Return the last index in the slice.
            ///
            /// If the slice is empty, the index returned should
            /// result in `idx_valid(idx) == false`
            last_idx: *const fn (self: *anyopaque) IDX = _fn_self_panic("last_idx", IDX),
            /// Return the next index after the current index in the slice.
            ///
            /// If the given index is invalid or no next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            next_idx: *const fn (self: *anyopaque, this_idx: IDX) IDX = _fn_self_idx_panic("next_idx", IDX),
            /// Return the index `n` places after the current index in the slice.
            ///
            /// If the given index is invalid or no nth next index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_next_idx: *const fn (self: *anyopaque, this_idx: IDX, n: IDX) IDX = _fn_self_idx_idx_panic("nth_next_idx", IDX),
            /// Return the prev index before the current index in the slice.
            ///
            /// If the given index is invalid or no prev index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            prev_idx: *const fn (self: *anyopaque, this_idx: IDX) IDX = _fn_self_idx_panic("prev_idx", IDX),
            /// Return the index `n` places before the current index in the slice.
            ///
            /// If the given index is invalid or no nth previous index exists,
            /// the index returned should result in `idx_valid(idx) == false`
            nth_prev_idx: *const fn (self: *anyopaque, this_idx: IDX, n: IDX) IDX = _fn_self_idx_idx_panic("nth_prev_idx", IDX),
            /// Return the current number of values in the slice/list
            ///
            /// It is not guaranteed that all indexes less than `len` are valid for the slice
            len: *const fn (self: *anyopaque) IDX = _fn_self_panic("len", IDX),
            /// Return the number of items between (and including) `first_idx` and `last_idx`
            ///
            /// `slice.range_len(slice.first_idx(), slice.last_idx())` MUST equal `slice.len()`
            range_len: *const fn (self: *anyopaque, range: Range) IDX = _fn_self_range_panic("range_len", IDX),
            /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
            /// the memory or performing any other expensive reorganization procedure
            ///
            /// If free space cannot be ensured and attempting to add `n_more_items`
            /// will definitely fail or cause undefined behaviour, `ok == false`
            try_ensure_free_slots: *const fn (self: *anyopaque, n_more_items: IDX) bool = _fn_self_idx_panic("try_ensure_free_slots", bool),
            /// Insert `n` new slots directly before existing index, shifting all existing items
            /// at and after that index forward.
            ///
            /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
            /// not match the insert index, depending on the implementation behavior
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            insert_slots_assume_capacity: *const fn (self: *anyopaque, idx: IDX, count: IDX) Range = _fn_self_idx_idx_panic("insert_slots_assume_capacity", Range),
            /// Append `n` new slots at the end of the list.
            ///
            /// Returns the first new slot and the last new slot, inclusive
            ///
            /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
            /// calling this function with a valid insert idx should not fail
            append_slots_assume_capacity: *const fn (self: *anyopaque, count: IDX) Range = _fn_self_idx_panic("append_slots_assume_capacity", Range),
            /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
            ///
            /// All items after `last_removed_idx` are shifted backward
            delete_range: *const fn (self: *anyopaque, range: Range) void = _fn_self_range_panic("delete_range", void),
            /// Reset list to an empty state. The list's capacity may or may not be retained,
            /// but the list must remain in a usable state
            clear: *const fn (self: *anyopaque) void = _fn_self_panic("clear", void),
            /// Return the total number of values the slice/list can hold
            cap: *const fn (self: *anyopaque) IDX = _fn_self_panic("cap", IDX),
            /// Increment the start location (index/pointer/etc.) of this list by
            /// `n` positions. The new 'first' index in the list should be the index
            /// that would have previously been returned by `list.nth_next_idx(list.first_idx(), n)`
            ///
            /// This action may or may not be reversable (for example using `clear()` or some other implementation specific method)
            increment_start: *const fn (self: *anyopaque, n: IDX) void = _fn_self_idx_panic("increment_start", void),
            /// Free the list's memory, if applicable, and set it to an uinitialized state
            free: *const fn (self: *anyopaque) void = _fn_self_panic("free", void),
        };
        fn prefer_linear_ops(self: Self) bool {
            return self.vtable.prefer_linear_ops();
        }

        fn consecutive_indexes_in_order(self: Self) bool {
            return self.vtable.consecutive_indexes_in_order();
        }
        fn all_indexes_less_than_len_valid(self: Self) bool {
            return self.vtable.all_indexes_zero_to_len_valid();
        }

        /// Return `true` if the given index is a valid index for the list, `false` otherwise
        pub fn idx_valid(self: Self, idx: IDX) bool {
            return self.vtable.idx_valid(self.object, idx);
        }
        /// Return `true` if the given range (inclusive) is valid for the list, `false` otherwise
        pub fn range_valid(self: Self, range: Range) bool {
            return self.vtable.range_valid(self.object, range);
        }
        /// Split an index range (roughly) in half, returning the index in the middle of the range
        ///
        /// Assumes `range_valid(first_idx, last_idx) == true`, and if so,
        /// the returned index MUST also be valid and MUST be between or equal to the first and/or last index
        ///
        /// The implementation should endeavor to return an index as close to the true middle index
        /// as possible, but it is not required to as long as the returned index IS between or equal to
        /// the first and/or last indexes. HOWEVER, some algorithms will have inconsitent performance
        /// if the returned index is far from the true middle index
        pub fn split_range(self: Self, range: Range) IDX {
            return self.vtable.split_range(self.object, range);
        }
        /// get the value at the provided index
        pub fn get(self: Self, idx: IDX) T {
            self.vtable.get(self.object, idx);
        }
        /// get a pointer to the value at the provided index
        pub fn get_ptr(self: Self, idx: IDX) PTR {
            self.vtable.get_ptr(self.object, idx);
        }
        /// set the value at the provided index to the given value
        pub fn set(self: Self, idx: IDX, val: T) void {
            self.vtable.set(self.object, idx, val);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn move(self: Self, old_idx: IDX, new_idx: IDX) void {
            self.vtable.move(self.object, old_idx, new_idx);
        }
        /// move the data located at `old_idx` to `new_idx`, shifting all
        /// values in between either up or down
        pub fn try_move(self: Self, old_idx: IDX, new_idx: IDX) ListError!void {
            if (!self.idx_valid(old_idx) or !self.idx_valid(new_idx)) {
                return ListError.invalid_index;
            }
            self.vtable.move(self.object, old_idx, new_idx);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn move_range(self: Self, first_idx_: IDX, last_idx_: IDX, new_first_idx: IDX) void {
            self.vtable.move_range(self.object, first_idx_, last_idx_, new_first_idx);
        }
        /// move the data from located between and including `first_idx` and `last_idx`,
        /// to the position `new_first_idx`, shifting the values in the way ether forward or backward
        pub fn try_move_range(self: Self, first_idx_: IDX, last_idx_: IDX, new_first_idx: IDX) ListError!void {
            if (!self.range_valid(first_idx_, last_idx_)) {
                return ListError.invalid_range;
            }
            if (!self.idx_valid(new_first_idx)) {
                return ListError.invalid_index;
            }
            const between = self.range_len(first_idx_, last_idx_);
            const new_last_idx = self.nth_next_idx(new_first_idx, between - 1);
            if (!self.idx_valid(new_last_idx)) {
                return ListError.index_out_of_bounds;
            }
            self.vtable.move_range(self.object, first_idx_, last_idx_, new_first_idx);
        }
        /// Return another `IList(T, IDX)` that holds values in range [first, last] (inclusive)
        ///
        /// Analogous to slice[first..last+1]
        pub fn slice(self: Self, range: Range) Self {
            self.vtable.slice(self.object, range);
        }
        /// Return the first index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn first_idx(self: Self) IDX {
            self.vtable.first_idx(self.object);
        }
        /// Return the last index in the slice.
        ///
        /// If the slice is empty, the index returned will
        /// result in `idx_valid(idx) == false`
        pub fn last_idx(self: Self) IDX {
            self.vtable.last_idx(self.object);
        }
        /// Return the next index after the current index in the slice.
        ///
        /// If the given index is invalid or no next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn next_idx(self: Self, this_idx: IDX) IDX {
            self.vtable.next_idx(self.object, this_idx);
        }
        /// Return the index `n` places after the current index in the slice.
        ///
        /// If the given index is invalid or no nth next index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_next_idx(self: Self, this_idx: IDX, n: IDX) IDX {
            self.vtable.nth_next_idx(self.object, this_idx, n);
        }
        /// Return the prev index before the current index in the slice.
        ///
        /// If the given index is invalid or no prev index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn prev_idx(self: Self, this_idx: IDX) IDX {
            self.vtable.prev_idx(self.object, this_idx);
        }
        /// Return the index `n` places before the current index in the slice.
        ///
        /// If the given index is invalid or no nth previous index exists,
        /// the index returned will result in `idx_valid(idx) == false`
        pub fn nth_prev_idx(self: Self, this_idx: IDX, n: IDX) IDX {
            self.vtable.nth_prev_idx(self.object, this_idx, n);
        }
        /// Return the current number of values in the slice/list
        ///
        /// It is not guaranteed that all indexes less than `len` are valid for the slice,
        /// unless `all_indexes_less_than_len_valid() == true`
        pub fn len(self: Self) IDX {
            return self.vtable.len(self.object);
        }
        /// Return the number of items between (and including) `first_idx` and `last_idx`
        ///
        /// `slice.range_len(Range{.first_idx: slice.first_idx(), .last_idx: slice.last_idx()})` MUST equal `slice.len()`
        pub fn range_len(self: Self, range: Range) IDX {
            self.vtable.range_len(self.object, range);
        }
        /// Ensure at least `n` empty capacity spaces exist to add new items without reallocating
        /// the memory or performing any other expensive reorganization procedure
        ///
        /// If free space cannot be ensured and attempting to add `n_more_items`
        /// will definitely fail or cause undefined behaviour, `ok == false`
        pub fn try_ensure_free_slots(self: Self, n_more_items: IDX) bool {
            self.vtable.try_ensure_free_slots(self.object, n_more_items);
        }
        /// Insert `n` new slots directly before existing index, shifting all existing items
        /// at and after that index forward.
        ///
        /// Returns the first new slot and the last new slot, inclusive, but the first new slot might
        /// not match the insert index, depending on the implementation behavior
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function with a valid insert idx should not fail
        pub fn insert_slots_assume_capacity(self: Self, idx: IDX, count: IDX) Range {
            self.vtable.InsertSinsert_slots_assume_capacity(self.object, idx, count);
        }
        /// Append `n` new slots at the end of the list.
        ///
        /// Returns the first new slot and the last new slot, inclusive
        ///
        /// The implementation should assume that as long as `try_ensure_free_slots(count)` returns `true`,
        /// calling this function should not fail
        pub fn append_slots_assume_capacity(self: Self, count: IDX) Range {
            self.vtable.append_slots_assume_capacity(self.object, count);
        }
        /// Remove all items between `firstRemoveIdx` and `last_removed_idx`, inclusive
        ///
        /// All items after `last_removed_idx` are shifted backward
        pub fn delete_range(self: Self, range: Range) void {
            self.vtable.delete_range(self.object, range);
        }
        /// Reset list to an empty state. The list's capacity may or may not be retained.
        pub fn clear(self: Self) void {
            self.vtable.clear(self.object);
        }
        /// Return the total number of values the slice/list can hold
        pub fn cap(self: Self) IDX {
            return self.vtable.cap(self.object);
        }
        /// Increment the start location (index/pointer/etc.) of this list by
        /// `n` positions. The new 'first' item in the queue should be the item
        /// that would have previously been returned by `list.nth_next_idx(list.first_idx(), n)`
        ///
        /// This may or may not irrevertibly consume the first `n` items in the list
        pub fn increment_start(self: Self, n: IDX) void {
            self.vtable.increment_start(self.object, n);
        }
        /// Free the list's memory, if applicable, and set it to an uinitialized state
        pub fn free(self: Self) void {
            self.vtable.free(self.object);
        }

        pub fn all_idx_valid_zig(self: Self, idxs: []IDX) bool {
            for (idxs) |idx| {
                if (!self.idx_valid(idx)) {
                    return false;
                }
            }
            return true;
        }
        pub fn all_idx_valid(_: Self, _: IIdxList) bool {
            // for (idxs) |idx| {
            //     if (!self.idx_valid(idx)) {
            //         return false;
            //     }
            // }
            // return true;
            //FIXME
            @panic("message: []const u8");
        }
        pub fn is_empty(self: Self) bool {
            return self.len() <= 0;
        }

        pub fn try_slice(self: Self, first_idx_: IDX, last_idx_: IDX) ListError!Self {
            if (!self.range_valid(first_idx_, last_idx_)) {
                return ListError.invalid_range;
            }
            return self.slice(first_idx_, last_idx_);
        }

        pub fn try_get(self: Self, idx: IDX) ListError!T {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get(idx);
        }

        pub fn try_get_ptr(self: Self, idx: IDX) ListError!PTR {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            return self.get_ptr(idx);
        }

        pub fn try_set(self: Self, idx: IDX, val: T) ListError!void {
            if (!self.idx_valid(idx)) {
                return ListError.invalid_index;
            }
            self.set(idx, val);
        }

        pub fn try_first_idx(self: Self) ListError!IDX {
            const idx = self.first_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }

        pub fn try_last_idx(self: Self) ListError!IDX {
            const idx = self.last_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            return idx;
        }
        pub fn try_next_idx(self: Self, this_idx: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.next_idx(this_idx);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_nth_next_idx(self: Self, this_idx: IDX, n: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const next_idx_ = self.nth_next_idx(this_idx, n);
            if (!self.idx_valid(next_idx_)) {
                return ListError.no_items_after;
            }
            return next_idx_;
        }
        pub fn try_prev_idx(self: Self, this_idx: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.prev_idx(this_idx);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn try_nth_prev_idx(self: Self, this_idx: IDX, n: IDX) ListError!IDX {
            if (!self.idx_valid(this_idx)) {
                return ListError.invalid_index;
            }
            const prev_idx_ = self.nth_prev_idx(this_idx, n);
            if (!self.idx_valid(prev_idx_)) {
                return ListError.no_items_after;
            }
            return prev_idx_;
        }
        pub fn nth_idx(self: Self, n: IDX) IDX {
            var idx = self.first_idx();
            idx = self.nth_next_idx(idx, n);
            return idx;
        }
        pub fn try_nth_idx(self: Self, n: IDX) ListError!IDX {
            var idx = self.first_idx();
            if (!self.idx_valid(idx)) {
                return ListError.list_is_empty;
            }
            idx = self.nth_next_idx(idx, n);
            if (!self.idx_valid(idx)) {
                return ListError.index_out_of_bounds;
            }
            return idx;
        }
        pub fn get_last(self: Self) T {
            const idx = self.last_idx();
            return self.get(idx);
        }
        pub fn try_get_last(self: Self) ListError!T {
            const idx = try self.try_last_idx();
            return self.get(idx);
        }
        pub fn get_last_ptr(self: Self) PTR {
            const idx = self.last_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_last_ptr(self: Self) ListError!PTR {
            const idx = try self.try_last_idx();
            return self.get_ptr(idx);
        }
        pub fn set_last(self: Self, val: T) void {
            const idx = self.last_idx();
            return self.set(idx, val);
        }
        pub fn try_set_last(self: Self, val: T) ListError!void {
            const idx = try self.try_last_idx();
            return self.set(idx, val);
        }
        pub fn get_first(self: Self) T {
            const idx = self.first_idx();
            return self.get(idx);
        }
        pub fn try_get_first(self: Self) ListError!T {
            const idx = try self.try_first_idx();
            return self.get(idx);
        }
        pub fn get_first_ptr(self: Self) PTR {
            const idx = self.first_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_first_ptr(self: Self) ListError!PTR {
            const idx = try self.try_first_idx();
            return self.get_ptr(idx);
        }
        pub fn set_first(self: Self, val: T) void {
            const idx = self.first_idx();
            return self.set(idx, val);
        }
        pub fn try_set_first(self: Self, val: T) ListError!void {
            const idx = try self.try_first_idx();
            return self.set(idx, val);
        }
        pub fn get_nth(self: Self) T {
            const idx = self.nth_idx();
            return self.get(idx);
        }
        pub fn try_get_nth(self: Self) ListError!T {
            const idx = try self.try_nth_idx();
            return self.get(idx);
        }
        pub fn get_nth_ptr(self: Self) PTR {
            const idx = self.nth_idx();
            return self.get_ptr(idx);
        }
        pub fn try_get_nth_ptr(self: Self) ListError!PTR {
            const idx = try self.try_nth_idx();
            return self.get_ptr(idx);
        }
        pub fn set_nth(self: Self, val: T) void {
            const idx = self.nth_idx();
            return self.set(idx, val);
        }
        pub fn try_set_nth(self: Self, val: T) ListError!void {
            const idx = try self.try_nth_idx();
            return self.set(idx, val);
        }
        pub fn set_from(self: Self, self_idx: IDX, source: Self, source_idx: IDX) void {
            const val = source.get(source_idx);
            self.set(self_idx, val);
        }
        pub fn try_set_from(self: Self, self_idx: IDX, source: Self, source_idx: IDX) ListError!void {
            const val = try source.try_get(source_idx);
            return self.try_set(self_idx, val);
        }
        pub fn swap(self: Self, idx_a: IDX, idx_b: IDX) void {
            const val_a = self.get(idx_a);
            const val_b = self.get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn try_swap(self: Self, idx_a: IDX, idx_b: IDX) ListError!void {
            const val_a = try self.try_get(idx_a);
            const val_b = try self.try_get(idx_b);
            self.set(idx_a, val_b);
            self.set(idx_b, val_a);
        }
        pub fn exchange(self: Self, self_idx: IDX, other: Self, other_idx: IDX) void {
            const val_self = self.get(self_idx);
            const val_other = other.get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn try_exchange(self: Self, self_idx: IDX, other: Self, other_idx: IDX) ListError!void {
            const val_self = try self.try_get(self_idx);
            const val_other = try other.try_get(other_idx);
            self.set(self_idx, val_other);
            other.set(other_idx, val_self);
        }
        pub fn overwrite(self: Self, source_idx: IDX, dest_idx: IDX) void {
            const val = self.get(source_idx);
            self.set(dest_idx, val);
        }
        pub fn try_overwrite(self: Self, source_idx: IDX, dest_idx: IDX) ListError!void {
            const val = try self.try_get(source_idx);
            self.set(dest_idx, val);
        }
        pub fn reverse(self: Self) void {
            var left = self.first_idx();
            var right = self.last_idx();
            if (left == right or !self.idx_valid(left) or !self.idx_valid(right)) {
                return;
            }
            while (true) {
                self.swap(left, right);
                left = self.next_idx(left);
                if (left == right) {
                    return;
                }
                right = self.prev_idx(right);
                if (left == right) {
                    return;
                }
            }
        }
        pub fn fill(self: Self, val: T) void {
            var i = self.first_idx();
            var ok = self.idx_valid(i);
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn fill_count(self: Self, val: T, count: IDX) CountResult {
            var i = self.first_idx();
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok and result.count < count) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn fill_at_index(self: Self, val: T, index: IDX) void {
            var i = index;
            var ok = self.idx_valid(i);
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn try_fill_at_index(self: Self, val: T, index: IDX) ListError!void {
            var i = index;
            var ok = self.idx_valid(i);
            if (!ok) {
                return ListError.invalid_index;
            }
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }
        pub fn fill_count_at_index(self: Self, val: T, index: IDX, count: IDX) CountResult {
            var i = index;
            var ok = self.idx_valid(i);
            var result = CountResult{};
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn try_fill_count_at_index(self: Self, val: T, index: IDX, count: IDX) ListError!CountResult {
            var i = index;
            var ok = self.idx_valid(i);
            if (!ok) {
                return ListError.invalid_index;
            }
            var result = CountResult{};
            while (ok) {
                self.set(i, val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
                result.count += 1;
            }
            result.count_matches_input = result.count == count;
            return result;
        }
        pub fn fill_range(self: Self, val: T, first_idx_: IDX, last_idx_: IDX) CountResult {
            var i = first_idx_;
            var ok = self.idx_valid(first_idx_);
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_input = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn try_fill_range(self: Self, val: T, first_idx_: IDX, last_idx_: IDX) ListError!CountResult {
            var i = first_idx_;
            var ok = self.range_valid(first_idx_, last_idx_);
            if (!ok) {
                return ListError.invalid_range;
            }
            var result: CountResult = CopyResult{};
            while (ok) {
                ok = i != last_idx_;
                result.count_matches_input = !ok;
                self.set(i, val);
                i = self.next_idx(i);
                ok = ok and self.idx_valid(i);
                result.count += 1;
                result.next_idx = i;
            }
            return result;
        }
        pub fn copy_to(self: Self, self_range: Iterator, dest_range: Iterator, comptime count_limit: Iterator.IterCount) CopyResult {
            return copy_to_advanced(self, self_range, dest_range, count_limit, .no_error_checks, .no_filter, null, null, .no_filter, null, null);
        }
        pub fn copy_to_advanced(
            self: Self,
            self_range: PartialIterator,
            dest_range: Iterator,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime src_filter: Iterator.IterFilter,
            src_userdata: anytype,
            src_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(src_userdata)) Iterator.IterSelect,
            comptime dest_filter: Iterator.IterFilter,
            dest_userdata: anytype,
            dest_filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(dest_userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!CopyResult else CopyResult {
            var self_iter = self_range.to_iter(self);
            var dest_iter = dest_range;
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
            var next_dest = dest_iter.next_advanced(count_limit, error_checks, .advance, dest_filter, dest_userdata, dest_filter_func);
            while (next_self != null and next_dest != null) {
                const ok_next_dest = next_dest.?;
                const ok_next_self = next_self.?;
                ok_next_dest.list.set(ok_next_dest.idx, ok_next_self.val);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, src_filter, src_userdata, src_filter_func);
                next_dest = dest_iter.next_advanced(count_limit, error_checks, .advance, dest_filter, dest_userdata, dest_filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
                if (dest_iter.err) |err| {
                    return err;
                }
            }
            var result = CopyResult{};
            result.count = @min(self_iter.count, dest_iter.count);
            result.count_matches_input = result.count == dest_iter.want_count or result.count == self_iter.want_count;
            result.full_dest_copied = !dest_iter.more_values;
            result.full_source_copied = !self_iter.more_values;
            result.next_dest_idx = dest_iter.curr;
            result.next_source_idx = self_iter.curr;
            return result;
        }
        fn _swizzle_internal(self: Self, range: Range, sources: IListList, selectors: IIdxList, count: IDX, comptime force_count: bool, comptime is_try: bool) if (is_try) ListError!SwizzleResult else SwizzleResult {
            var sel_idx = selectors.first_idx();
            var more_selectors: bool = selectors.idx_valid(sel_idx);
            if (is_try) {
                if (!more_selectors) {
                    return ListError.invalid_index;
                }
            }
            var val: T = undefined;
            var source: Self = undefined;
            var source_idx: IDX = undefined;
            var val_idx: IDX = undefined;
            var more_dest = self.idx_valid(range.first_idx);
            if (is_try) {
                if (!self.range_valid(range)) {
                    return ListError.invalid_range;
                }
            }
            var dest_idx = range.first_idx;
            var result = SwizzleResult{};
            while ((!force_count or result.count < count) and more_selectors and more_dest) {
                source_idx = selectors.get(sel_idx);
                if (is_try) {
                    if (!sources.idx_valid(source_idx)) {
                        return ListError.invalid_index;
                    }
                }
                source = sources.get(source_idx);
                val_idx = source.nth_idx(result.count);
                if (is_try) {
                    if (!source.idx_valid(val_idx)) {
                        return ListError.invalid_index;
                    }
                }
                val = source.get(val_idx);
                self.set(dest_idx, val);
                result.count += 1;
                sel_idx = selectors.next_idx(sel_idx);
                more_selectors = selectors.idx_valid(sel_idx);
                result.full_dest_copied = dest_idx == range.last_idx;
                dest_idx = self.next_idx(dest_idx);
                more_dest = self.idx_valid(dest_idx);
            }
            if (force_count) {
                result.count_matches_input = result.count == count;
            } else {
                result.count_matches_input = true;
            }
            result.all_selectors_done = !more_selectors;
            result.next_dest_idx = dest_idx;
            return result;
        }
        pub fn swizzle(self: Self, range: Range, sources: IListList, selectors: IIdxList) SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, 0, false, false);
        }
        pub fn try_swizzle(self: Self, range: Range, sources: IListList, selectors: IIdxList) ListError!SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, 0, false, true);
        }
        pub fn swizzle_count(self: Self, range: Range, sources: IListList, selectors: IIdxList, count: IDX) SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, false);
        }
        pub fn try_swizzle_count(self: Self, range: Range, sources: IListList, selectors: IIdxList, count: IDX) ListError!SwizzleResult {
            return _swizzle_internal(self, range, sources, selectors, count, true, true);
        }
        pub fn is_sorted(self: Self, greater_than: *const CompareFunc) bool {
            var i: IDX = undefined;
            var ii: IDX = undefined;
            var left: T = undefined;
            var right: T = undefined;
            i = self.first_idx();
            var more = self.idx_valid(i);
            if (!more) {
                return true;
            }
            ii = self.next_idx(i);
            more = self.idx_valid(ii);
            if (!more) {
                return true;
            }
            left = self.get(i);
            right = self.get(ii);
            while (more) {
                if (greater_than(left, right)) {
                    return false;
                }
                i = ii;
                ii = self.next_idx(ii);
                more = self.idx_valid(ii);
                if (more) {
                    left = right;
                    right = self.get(ii);
                }
            }
            return true;
        }
        fn _implicit_gt(left: T, right: T) bool {
            return left > right;
        }
        fn _implicit_lt(left: T, right: T) bool {
            return left < right;
        }
        pub fn is_sorted_implicit(self: Self) bool {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.is_sorted_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            return is_sorted(self, _implicit_gt);
        }
        pub fn insertion_sort(self: Self, greater_than: *const CompareFunc) void {
            var ok: bool = undefined;
            var i: IDX = undefined;
            var j: IDX = undefined;
            var jj: IDX = undefined;
            var move_val: T = undefined;
            var test_val: T = undefined;
            i = self.first_idx();
            ok = self.idx_valid(i);
            if (!ok) {
                return;
            }
            i = self.next_idx(i);
            ok = self.idx_valid(i);
            if (!ok) {
                return;
            }
            while (ok) {
                move_val = self.get(i);
                j = self.prev_idx(i);
                ok = self.idx_valid(j);
                if (ok) {
                    jj = i;
                    test_val = self.get(j);
                    while (ok and greater_than(test_val, move_val)) {
                        self.overwrite(j, jj);
                        jj = j;
                        j = self.prev_idx(j);
                        ok = self.idx_valid(j);
                        if (ok) {
                            test_val = self.get(j);
                        }
                    }
                }
                self.set(jj, move_val);
                i = self.next_idx(i);
                ok = self.idx_valid(i);
            }
        }

        pub fn insertion_sort_implicit(self: Self) void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.insertion_sort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            insertion_sort(self, _implicit_gt);
        }

        pub fn quicksort(self: Self, greater_than: *const CompareFunc, less_than: *const CompareFunc, partition_stack: IIdxList) ListError!void {
            if (self.len() < 2) {
                return;
            }
            if (self.len() <= 8) {
                self.insertion_sort(greater_than);
                return;
            }
            var hi: IDX = undefined;
            var lo: IDX = undefined;
            var mid: Range = undefined;
            var rng: Range = undefined;
            var ok: bool = undefined;
            lo = self.first_idx();
            hi = self.last_idx();
            partition_stack.clear();
            ok = partition_stack.try_ensure_free_slots(2);
            if (!ok) {
                return ListError.failed_to_grow_list;
            }
            partition_stack.append_slots_assume_capacity(2);
            partition_stack.set(rng.first_idx, lo);
            partition_stack.set(rng.last_idx, hi);
            while (partition_stack.len() >= 2) {
                hi = partition_stack.pop();
                lo = partition_stack.pop();
                if (hi == lo or hi == self.prev_idx(lo) or lo == self.next_idx(hi)) {
                    continue;
                }
                mid = _quicksort_partition(self, greater_than, less_than, lo, hi);
                ok = partition_stack.try_ensure_free_slots(4);
                if (!ok) {
                    return ListError.failed_to_grow_list;
                }
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.first_idx, lo);
                partition_stack.set(rng.first_idx, self.prev_idx(mid.first_idx));
                rng = partition_stack.append_slots_assume_capacity(2);
                partition_stack.set(rng.last_idx, self.next_idx(mid.last_idx));
                partition_stack.set(rng.last_idx, hi);
            }
        }
        pub fn quicksort_implicit(self: Self, partition_stack: IIdxList) ListError!void {
            Assert.assert_with_reason(Types.type_is_numeric(T), @src(), "IList.quicksort_implicit() can only be used when element type `T` is numeric, got type {s}", @typeName(T));
            self.quicksort(_implicit_gt, _implicit_lt, partition_stack);
        }
        fn _quicksort_partition(self: Self, greater_than: *const CompareFunc, less_than: *const CompareFunc, lo: IDX, hi: IDX) Range {
            const pivot_idx: IDX = undefined;
            if (self.consecutive_indexes_in_order() and self.all_indexes_less_than_len_valid()) {
                const rng: Range = .new_range(lo, hi);
                if (self.range_len(rng) <= 8) {
                    // use insertion sort for small partitions
                    var sub = self.slice(rng);
                    sub.insertion_sort(greater_than);
                    return Range.single_idx(lo);
                }
                // use median-of-3
                const mid = ((hi - lo) >> 1) + lo;
                const v_lo = self.get(lo);
                const v_hi = self.get(hi);
                const v_mid = self.get(mid);
                if (less_than(v_lo, v_mid)) {
                    if (less_than(v_mid, v_hi)) {
                        pivot_idx = mid;
                    } else if (less_than(v_lo, v_hi)) {
                        pivot_idx = hi;
                    } else {
                        pivot_idx = lo;
                    }
                } else {
                    if (less_than(v_lo, v_hi)) {
                        pivot_idx = lo;
                    } else if (less_than(v_mid, v_hi)) {
                        pivot_idx = hi;
                    } else {
                        pivot_idx = mid;
                    }
                }
            } else {
                // choose lo
                pivot_idx = lo;
            }
            const pivot_val = self.get(pivot_idx);
            var less_idx: IDX = lo;
            var equal_idx: IDX = lo;
            var more_idx: IDX = hi;
            var cont: bool = equal_idx != more_idx;
            while (cont) {
                const eq_val: T = self.get(equal_idx);
                if (less_than(eq_val, pivot_val)) {
                    self.swap(equal_idx, less_idx);
                    less_idx = self.prev_idx(less_idx);
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = self.next_idx(equal_idx);
                } else if (greater_than(eq_val, pivot_val)) {
                    self.swap(equal_idx, more_idx);
                    if (equal_idx == more_idx) {
                        cont = false;
                    }
                    more_idx = self.prev_idx(more_idx);
                } else {
                    if (equal_idx == more_idx) {
                        break;
                    }
                    equal_idx = self.next_idx(equal_idx);
                }
            }
            return Range.new(less_idx, more_idx);
        }
        pub fn for_each_advanced(
            self: Self,
            self_range: PartialIterator,
            userdata: anytype,
            action: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) void,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                action(ok_next_self, userdata);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }
        pub fn for_each(self: Self, self_range: PartialIterator, userdata: anytype, action: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) void) CountResult {
            return for_each_advanced(self, self_range, userdata, action, .no_count_limit, .error_checks, .no_filter, null);
        }
        pub fn filter_indexes_advanced(
            self: Self,
            self_range: PartialIterator,
            userdata: anytype,
            filter_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
            output_list: IIdxList,
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, .use_filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                const ok = output_list.try_ensure_free_slots(1);
                if (error_checks == .error_checks and !ok) {
                    return ListError.failed_to_grow_list;
                }
                const out_idx = output_list.append_slots_assume_capacity(1);
                output_list.set(out_idx, ok_next_self.idx);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, .use_filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }
        pub fn filter_indexes(self: Self, self_range: PartialIterator, userdata: anytype, filter_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect, output_list: IIdxList) CountResult {
            return self.filter_indexes_advanced(self, self_range, userdata, filter_func, output_list, .use_count_limit, .no_error_checks);
        }
        pub fn transform_values_advanced(
            self: Self,
            self_range: PartialIterator,
            userdata: anytype,
            comptime OUT_TYPE: type,
            comptime OUT_PTR: type,
            transform_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) OUT_TYPE,
            output_list: IList(OUT_TYPE, OUT_PTR, IDX),
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!CountResult else CountResult {
            output_list.clear();
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            while (next_self) |ok_next_self| {
                const ok = output_list.try_ensure_free_slots(1);
                if (error_checks == .error_checks and !ok) {
                    return ListError.failed_to_grow_list;
                }
                const out_idx = output_list.append_slots_assume_capacity(1);
                const new_val = transform_func(ok_next_self, userdata);
                output_list.set(out_idx, new_val);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return self_iter.count_result();
        }
        pub fn transform_values(self: Self, self_range: PartialIterator, userdata: anytype, comptime OUT_TYPE: type, comptime OUT_PTR: type, transform_func: *const fn (item: IteratorItem, userdata: @TypeOf(userdata)) OUT_TYPE, output_list: IList(OUT_TYPE, OUT_PTR, IDX)) CountResult {
            return self.transform_values_advanced(self_range, userdata, OUT_TYPE, OUT_PTR, transform_func, output_list, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        pub fn accumulate_result_advanced(
            self: Self,
            self_range: PartialIterator,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
            comptime count_limit: Iterator.IterCount,
            comptime error_checks: Iterator.IterCheck,
            comptime filter: Iterator.IterFilter,
            filter_func: ?*const fn (item: IteratorItem, userdata: @TypeOf(userdata)) Iterator.IterSelect,
        ) if (error_checks == .error_checks) ListError!AccumulateResult(@TypeOf(initial_accumulation)) else AccumulateResult(@TypeOf(initial_accumulation)) {
            var self_iter = self_range.to_iter(self);
            var next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            var accum = initial_accumulation;
            while (next_self) |ok_next_self| {
                accum = accumulate_func(ok_next_self, accum, userdata);
                next_self = self_iter.next_advanced(count_limit, error_checks, .advance, filter, userdata, filter_func);
            }
            if (error_checks == .error_checks) {
                if (self_iter.err) |err| {
                    return err;
                }
            }
            return AccumulateResult(@TypeOf(initial_accumulation)){
                .count_result = self_iter.count_result(),
                .final_accumulation = accum,
            };
        }
        pub fn accumulate_result(
            self: Self,
            self_range: PartialIterator,
            initial_accumulation: anytype,
            userdata: anytype,
            accumulate_func: *const fn (item: IteratorItem, old_accumulation: @TypeOf(initial_accumulation), userdata: @TypeOf(userdata)) @TypeOf(initial_accumulation),
        ) AccumulateResult(@TypeOf(initial_accumulation)) {
            return self.accumulate_result_advanced(self_range, initial_accumulation, userdata, accumulate_func, .use_count_limit, .no_error_checks, .no_filter, null);
        }
        //CHECKPOINT list-like funcs
        pub fn pop(self: Self) T {
            const last_idx_ = self.last_idx();
            const val = self.get(last_idx_);
            self.delete_range(.single_idx(last_idx_));
            return val;
        }
    };
}
