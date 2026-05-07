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
const build = @import("builtin");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
const CompareFnUserdata = Utils.Compare.CompareFnUserdata;
const CompareFn = Utils.Compare.CompareFn;
const GetFn = Common.GetFn;
const SetFn = Common.SetFn;
const GetFnUserdata = Common.GetFnUserdata;
const SetFnUserdata = Common.SetFnUserdata;

pub const SearchOrder = enum {
    SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER,
    SEARCH_PARAMS_UNORDERED,
};

const DEBUG = std.debug.print;

pub fn AppendFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, val: ELEM_TYPE, alloc: Allocator) DATA_STRUCTURE;
}
pub fn DequeueFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ELEM_TYPE };
}
pub fn DequeueOrNullFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ?ELEM_TYPE };
}

pub const QUICKSORT_TO_INSERTION_THRESHOLD = 16;

pub const BinarySearchOneFound = enum(u8) {
    NO_DATA_ITEMS,
    NO_SEARCH_ITEMS,
    FOUND,
    NOT_FOUND_ORDERED_WITHIN_RANGE,
    NOT_FOUND_ORDERED_AFTER_GIVEN_RANGE,
    NOT_FOUND_ORDERED_BEFORE_GIVEN_RANGE,
};
pub const LinearSearchOneFound = enum(u8) {
    NO_DATA_ITEMS,
    NO_SEARCH_ITEMS,
    FOUND,
    NOT_FOUND,
};

const SearchEqualityMode = enum(u8) {
    ORDER_EQUAL,
    EXACTLY_EQUAL,
};

pub const ResultsListLimit = enum(u8) {
    SIZE_OF_RESULTS_LIST,
    UNLIMITED_ASSUME_CAPACITY,
    UNLIMITED_REALLOC,
};

pub const ResultsIncludeMode = enum(u8) {
    IDX_ONLY,
    IDX_AND_SEARCH_VAL,
};

pub const SortOrder = enum(u8) {
    NORMAL,
    REVERSE,
};

const BuilderValidation = if (Assert.should_assert()) enum(u8) {
    UNINITIALIZED,
    DEFAULT,
    SET_CUSTOM,
    INVALID,

    pub fn assert_valid(comptime self: @This(), comptime category: []const u8, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self == .DEFAULT or self == .SET_CUSTOM, src, "SearchPackage settings category `{s}` was never initialized or was invalidated by an later setting (`{s}`)", .{ category, @tagName(self) });
    }
} else enum(u0) {
    _NONE = 0,
    pub fn assert_valid(comptime self: @This(), comptime category: []const u8, comptime src: std.builtin.SourceLocation) void {
        _ = self;
        _ = category;
        _ = src;
    }
    const UNINITIALIZED = @This()._NONE;
    const DEFAULT = @This()._NONE;
    const SET_CUSTOM = @This()._NONE;
    const INVALID = @This()._NONE;
};

pub fn ResultItem(comptime DATA_IDX: type, comptime SEARCH_ELEM: type, comptime INCLUDE: ResultsIncludeMode) type {
    return struct {
        data_idx: DATA_IDX = undefined,
        search_val: if (INCLUDE == .IDX_AND_SEARCH_VAL) SEARCH_ELEM else void = if (INCLUDE == .IDX_AND_SEARCH_VAL) undefined else void{},

        pub fn new(data_idx: DATA_IDX, search_val: SEARCH_ELEM) @This() {
            var this = @This(){
                .data_idx = data_idx,
            };
            if (INCLUDE == .IDX_AND_SEARCH_VAL) {
                this.search_val = search_val;
            }
            return this;
        }
    };
}

pub const ManySameOrderExpectation = enum(u8) {
    MANY_ITEMS_WITH_SAME_ORDER_LIKELY,
    MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
};

pub const QuicksortSettings = struct {
    /// `34` (32 + 2) = max list len of 2^32 items,
    /// if you really need more than this you can increase it, each
    /// additional 1 is another power of 2 larger max len
    QUICKSORT_MAX_STACK: usize = 34,
    /// Signals to use a different partitioning scheme depending on whether you
    /// expect the data to have many items with equal order,
    /// or whether it is rare or impossible to occur
    SAME_ORDER_EXPECTATIONS: ManySameOrderExpectation = .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
};

pub const SortPackage = struct {
    CONTAINER: type = undefined,
    ELEM: type = undefined,
    IDX: type = undefined,
    HAS_USERDATA: bool = false,
    USERDATA: type = void,
    CUSTOM_DATA_GET: ?*const anyopaque = null,
    CUSTOM_DATA_SET: ?*const anyopaque = null,
    CUSTOM_GREATER_THAN: ?*const anyopaque = null,
    CUSTOM_LESS_THAN: ?*const anyopaque = null,
    CUSTOM_ORDER_EQUAL: ?*const anyopaque = null,
    SORT_ORDER: SortOrder = .NORMAL,
    QUICKSORT_SETTINGS: QuicksortSettings = .{},
    // Safe modes only
    VALID_CONTAINER: BuilderValidation = .UNINITIALIZED,
    VALID_GET_SET: BuilderValidation = .DEFAULT,
    VALID_COMPARE_FUNCS: BuilderValidation = .DEFAULT,

    fn assert_valid(comptime self: SortPackage, comptime src: std.builtin.SourceLocation) void {
        self.VALID_CONTAINER.assert_valid("DATA_CONTAINER", src);
        self.VALID_GET_SET.assert_valid("GET_SET", src);
        self.VALID_COMPARE_FUNCS.assert_valid("COMPARE_FUNCS", src);
    }

    pub fn SortInputs(comptime self: SortPackage) type {
        return struct {
            data: self.CONTAINER,
            start: self.IDX = 0,
            end_excluded: self.IDX,
            userdata: self.USERDATA = if (self.USERDATA == void) void{} else undefined,
        };
    }

    pub fn SortSubSlice(comptime self: SortPackage) type {
        return struct {
            data: self.CONTAINER,
            lo_idx: self.IDX,
            hi_idx: self.IDX,
            userdata: self.USERDATA = if (self.USERDATA == void) void{} else undefined,
        };
    }

    pub fn SortInputsWithIdxRangeStack(comptime self: SortPackage) type {
        return struct {
            data: self.CONTAINER,
            start: self.IDX = 0,
            end_excluded: self.IDX,
            stack: []self.IDX,
            userdata: self.USERDATA = if (self.USERDATA == void) void{} else undefined,

            pub fn to_simple_sub_slice(this: @This(), start: self.IDX, end: self.IDX) self.SortInputs() {
                return self.SortInputs(){
                    .data = this.data,
                    .start = start,
                    .end = end,
                    .userdata = this.userdata,
                };
            }
        };
    }

    fn median_of_3(comptime self: SortPackage, vals: [3]self.ELEM, idxs: [3]self.IDX, userdata: self.USERDATA) struct { self.IDX, self.ELEM } {
        var idx = idxs;
        var tmp: self.IDX = undefined;
        if (self.order_less_than(vals[idx[1]], vals[idx[0]], userdata)) {
            tmp = idx[1];
            idx[1] = idx[0];
            idx[0] = tmp;
        }
        if (self.order_less_than(vals[idx[2]], vals[idx[0]], userdata)) {
            tmp = idx[2];
            idx[2] = idx[0];
            idx[0] = tmp;
        }
        if (self.order_less_than(vals[idx[2]], vals[idx[1]], userdata)) {
            return .{ idx[2], vals[idx[2]] };
        }
        return .{ idx[1], vals[idx[1]] };
    }

    pub fn is_sorted(comptime self: SortPackage, inputs: self.SortInputs()) bool {
        self.assert_valid(@src());
        if (inputs.end_excluded > inputs.start) {
            @branchHint(.likely);
            var idx_right = inputs.start + 1;
            var val_left: self.ELEM = self.get_item(inputs.data, inputs.start, inputs.userdata);
            var val_right: self.ELEM = undefined;
            while (idx_right < inputs.end_excluded) {
                @branchHint(.likely);
                val_right = self.get_item(inputs.data, idx_right, inputs.userdata);
                if (self.order_greater_than(val_left, val_right, inputs.userdata)) return false;
                val_left = val_right;
                idx_right += 1;
            }
        }
        return true;
    }

    pub fn insertion_sort(comptime self: SortPackage, inputs: self.SortInputs()) self.CONTAINER {
        self.assert_valid(@src());
        var index_to_sort: self.IDX = inputs.start + 1;
        var idx_right: self.IDX = undefined;
        var idx_left: self.IDX = undefined;
        var value_to_sort: self.ELEM = undefined;
        var data = inputs.data;
        while (index_to_sort < inputs.end_excluded) {
            @branchHint(.likely);
            value_to_sort = self.get_item(data, index_to_sort, inputs.userdata);
            idx_right = index_to_sort;
            inner: while (idx_right > inputs.start) {
                @branchHint(.likely);
                idx_left = idx_right - 1;
                const val_left = self.get_item(data, idx_left, inputs.userdata);
                if (self.order_greater_than(val_left, value_to_sort, inputs.userdata)) {
                    data = self.set_item(data, idx_right, val_left, inputs.userdata);
                    idx_right -= 1;
                } else {
                    break :inner;
                }
            }
            data = self.set_item(data, idx_right, value_to_sort, inputs.userdata);
            index_to_sort += 1;
        }
        return data;
    }

    fn assert_stack_can_support_sort_len(comptime self: SortPackage, start: self.IDX, end_excl: self.IDX, comptime src: std.builtin.SourceLocation) void {
        const data_len = end_excl - start;
        const needed_len = num_cast(std.math.log2_int(self.IDX, data_len) + 2, usize);
        assert_with_reason(self.QUICKSORT_MAX_STACK >= needed_len, src, "the provided `.QUICKSORT_MAX_STACK` setting ({d}) is too small, need {d} for given the data len {d}", .{ self.QUICKSORT_MAX_STACK, needed_len, data_len });
    }

    pub fn IndexRange(comptime self: SortPackage) type {
        return struct {
            lo_idx: self.IDX,
            hi_idx: self.IDX,

            pub fn new(lo: self.IDX, hi: self.IDX) @This() {
                return @This(){
                    .lo_idx = lo,
                    .hi_idx = hi,
                };
            }

            pub fn empty(this: @This()) bool {
                return this.lo_idx >= this.hi_idx;
            }

            pub fn len(this: @This()) self.IDX {
                return (this.hi_idx - this.lo_idx) + 1;
            }
        };
    }

    /// Quicksort using a number of optimizations:
    ///   - Use Insertion Sort when partitions become small
    ///   - Median-of-three pivot (not random, always first, middle, last)
    ///   - Choose a partition scheme based on stated expectations about items with equal order
    ///     - Many items same order unlikely = Hoare scheme
    ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
    ///   - No rescursion, only a comptime sized stack of partition index ranges and a while loop
    ///   - Attempts to use branchless techniques where possible, and @branchHint()'s where relevant
    pub fn quicksort(comptime self: SortPackage, inputs: self.SortInputs()) self.CONTAINER {
        if (inputs.end_excluded - inputs.start < 2) {
            @branchHint(.unlikely);
            return inputs.data;
        }
        self.assert_stack_can_support_sort_len(inputs.start, inputs.end_excluded, @src());
        var data = inputs.data;
        var stack: [self.QUICKSORT_MAX_STACK]self.IndexRange() = undefined;
        stack[0] = self.IndexRange().new(inputs.start, inputs.end_excluded - 1);
        var stack_len: u8 = 1;
        next_partition: while (stack_len > 0) {
            @branchHint(.likely);
            stack_len -= 1;
            const partition_range = stack[stack_len];
            assert_with_reason(!partition_range.empty(), @src(), "it should be impossible to have an empty partition here", .{});
            if (partition_range.len() < QUICKSORT_TO_INSERTION_THRESHOLD) {
                data = self.insertion_sort(.{
                    .data = data,
                    .start = partition_range.lo_idx,
                    .end_excluded = partition_range.hi_idx + 1,
                    .userdata = inputs.userdata,
                });
                continue :next_partition;
            }
            data, const partition_pivot_range = switch (self.QUICKSORT_SETTINGS.SAME_ORDER_EXPECTATIONS) {
                .MANY_ITEMS_WITH_SAME_ORDER_LIKELY => self.quicksort_partition_dutch_flag(.{
                    .data = data,
                    .lo_idx = partition_range.lo_idx,
                    .hi_idx = partition_range.hi_idx,
                    .userdata = inputs.userdata,
                }),
                // FIXME
                // CHECKPOINT implement Hoare partition scheme
                .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE => self.quicksort_partition_dutch_flag(.{
                    .data = data,
                    .lo_idx = partition_range.lo_idx,
                    .hi_idx = partition_range.hi_idx,
                    .userdata = inputs.userdata,
                }),
            };
            const left_partition = self.IndexRange().new(partition_range.lo_idx, partition_pivot_range.pivot_region_lo -| 1, partition_range.lo_idx);
            const right_partition = self.IndexRange().new(partition_pivot_range.pivot_region_hi + 1, partition_range.hi_idx, partition_range.hi_idx);
            // branchless order selection by creating an array with both possibilities,
            // then use a boolean to index into it and select the correct version
            const possible_partition_order = [2][2]self.IndexRange(){
                // right is smaller version, left_is_smaller == false == 0
                [2]self.IndexRange(){ left_partition, right_partition },
                // left is smaller version, left_is_smaller == true == 1
                [2]self.IndexRange(){ right_partition, left_partition },
            };
            const left_is_smaller = left_partition.len() < right_partition.len();
            const add_order_idx = @intFromBool(left_is_smaller);
            const partition_order = possible_partition_order[add_order_idx];
            // add partitions larger first, smaller second,
            // using a branchless technique to cull empty partitions
            stack[stack_len] = partition_order[0];
            stack_len = stack_len + 1 - num_cast(@intFromBool(partition_order[0].empty()), u8);
            stack_len[stack_len] = partition_order[1];
            stack_len = stack_len + 1 - num_cast(@intFromBool(partition_order[1].empty()), u8);
        }
        return data;
    }

    fn PartitionResult(comptime self: SortPackage) type {
        return struct {
            pivot_region_lo: self.IDX,
            pivot_region_hi: self.IDX,
        };
    }

    fn quicksort_partition_dutch_flag(comptime self: SortPackage, sub_slice: self.SortSubSlice()) struct { self.CONTAINER, self.PartitionResult() } {
        const len = (sub_slice.hi_idx + 1) - sub_slice.lo_idx;
        const unsorted_idx = [3]self.IDX{ sub_slice.lo_idx, sub_slice.lo_idx + (len >> 1), sub_slice.hi_idx };
        const unsorted_vals = [3]self.ELEM{ self.get_item(sub_slice.data, unsorted_idx[0], sub_slice.userdata), self.get_item(sub_slice.data, unsorted_idx[1], sub_slice.userdata), self.get_item(sub_slice.data, unsorted_idx[2], sub_slice.userdata) };
        const median_idx, const pivot_item = self.median_of_3(unsorted_vals, unsorted_idx, sub_slice.userdata);
        var data = self.swap_items_already_have_b(sub_slice.data, sub_slice.lo_idx, median_idx, pivot_item, sub_slice.userdata);

        var lesser_boundary = sub_slice.lo_idx;
        var check_idx = sub_slice.lo_idx;
        var greater_boundary = sub_slice.hi_idx;

        while (check_idx < greater_boundary) {
            const check_item = self.get_item(sub_slice.data, check_idx, sub_slice.userdata);
            if (self.order_less_than(check_item, pivot_item, sub_slice.userdata)) {
                data = self.swap_items_already_have_b(data, lesser_boundary, check_idx, check_item, sub_slice.userdata);
                lesser_boundary += 1;
                check_idx += 1;
            } else if (self.order_less_than(pivot_item, check_item, sub_slice.userdata)) {
                data = self.swap_items_already_have_b(data, greater_boundary, check_idx, check_item, sub_slice.userdata);
                greater_boundary -|= 1;
            } else {
                check_idx += 1;
            }
        }

        return .{ data, self.PartitionResult(){
            .pivot_region_lo = lesser_boundary,
            .pivot_region_hi = greater_boundary,
        } };
    }

    pub const ContainerSettings = struct {
        CONTAINER: type,
        IDX: type,
        ELEM: type,

        pub fn Getter(comptime self: @This()) type {
            return GetFn(self.CONTAINER, self.IDX, self.ELEM);
        }
        pub fn Setter(comptime self: @This()) type {
            return SetFn(self.CONTAINER, self.IDX, self.ELEM);
        }
        pub fn GetterUserdata(comptime self: @This(), comptime USERDATA: type) type {
            return GetFnUserdata(self.CONTAINER, self.IDX, self.ELEM, USERDATA);
        }
        pub fn SetterUserdata(comptime self: @This(), comptime USERDATA: type) type {
            return SetFnUserdata(self.CONTAINER, self.IDX, self.ELEM, USERDATA);
        }

        pub fn GetterSetter(comptime self: @This(), comptime HAS_USERDATA: bool, comptime USERDATA: type) type {
            if (HAS_USERDATA) {
                return struct {
                    getter: *const self.GetterUserdata(USERDATA),
                    setter: *const self.SetterUserdata(USERDATA),
                };
            } else {
                return struct {
                    getter: *const self.Getter(),
                    setter: *const self.Setter(),
                };
            }
        }
    };

    pub fn sort_package() SortPackage {
        return SortPackage{};
    }

    pub fn with_implicit_container(comptime self: SortPackage, comptime CONTAINER: type) SortPackage {
        comptime var new_self = self;
        new_self.CONTAINER = CONTAINER;
        new_self.ELEM = Types.IndexableChild(CONTAINER);
        new_self.IDX = usize;
        new_self.CUSTOM_DATA_GET = null;
        new_self.CUSTOM_DATA_SET = null;
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_GET_SET = .DEFAULT;
        new_self.VALID_CONTAINER = .DEFAULT;
        return new_self;
    }

    pub fn with_custom_container(comptime self: SortPackage, comptime SETTINGS: ContainerSettings, comptime GET_SET: ?SETTINGS.GetterSetter(self.HAS_USERDATA, self.USERDATA)) SortPackage {
        comptime var new_self = self;
        new_self.CONTAINER = SETTINGS.CONTAINER;
        new_self.IDX = SETTINGS.IDX;
        new_self.ELEM = SETTINGS.ELEM;
        new_self.CUSTOM_DATA_GET = if (GET_SET) |FN| @ptrCast(FN.getter) else null;
        new_self.CUSTOM_DATA_SET = if (GET_SET) |FN| @ptrCast(FN.setter) else null;
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_GET_SET = if (GET_SET != null) .SET_CUSTOM else .DEFAULT;
        new_self.VALID_CONTAINER = .SET_CUSTOM;
        return new_self;
    }

    pub fn with_userdata_type(comptime self: SortPackage, comptime USERDATA: type) SortPackage {
        comptime var new_self = self;
        new_self.USERDATA = USERDATA;
        new_self.HAS_USERDATA = true;
        if (new_self.USERDATA != self.USERDATA or new_self.HAS_USERDATA != self.HAS_USERDATA) {
            new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
            new_self.VALID_GET_SET = if (new_self.VALID_GET_SET != .DEFAULT) .INVALID else .DEFAULT;
        }
        return new_self;
    }
    pub fn with_no_userdata_type(comptime self: SortPackage) SortPackage {
        comptime var new_self = self;
        new_self.USERDATA = void;
        new_self.HAS_USERDATA = false;
        if (new_self.USERDATA != self.USERDATA or new_self.HAS_USERDATA != self.HAS_USERDATA) {
            new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
            new_self.VALID_GET_SET = if (new_self.VALID_GET_SET != .DEFAULT) .INVALID else .DEFAULT;
        }
        return new_self;
    }

    pub fn with_implicit_compare_funcs(comptime self: SortPackage) SortPackage {
        comptime var new_self = self;
        new_self.CUSTOM_GREATER_THAN = null;
        new_self.CUSTOM_LESS_THAN = null;
        new_self.CUSTOM_ORDER_EQUAL = null;
        new_self.CUSTOM_ORDER_MATCH = null;
        new_self.VALID_COMPARE_FUNCS = .DEFAULT;
        return new_self;
    }

    pub fn with_custom_compare_funcs(comptime self: SortPackage, comptime FUNCS: self.CompareFuncs()) SortPackage {
        comptime var new_self = self;
        new_self.CUSTOM_GREATER_THAN = FUNCS.order_greater;
        new_self.CUSTOM_LESS_THAN = FUNCS.order_lesser;
        new_self.CUSTOM_ORDER_EQUAL = FUNCS.exactly_equal;
        new_self.CUSTOM_ORDER_MATCH = FUNCS.order_match;
        new_self.VALID_COMPARE_FUNCS = .SET_CUSTOM;
        return new_self;
    }

    pub fn with_sort_order(comptime self: SortPackage, comptime ORDER: SortOrder) SortPackage {
        comptime var new_self = self;
        new_self.SORT_ORDER = ORDER;
        return new_self;
    }

    pub fn get_item(comptime self: SortPackage, data: self.CONTAINER, idx: self.IDX, userdata: self.USERDATA) self.ELEM {
        if (self.CUSTOM_DATA_GET) |get_opaque| {
            const get: *const self.DataGetter() = @ptrCast(@alignCast(get_opaque));
            if (self.HAS_USERDATA) {
                return get(data, idx, userdata);
            } else {
                return get(data, idx);
            }
        } else {
            return Utils.Mem.get(self.ELEM, data, idx);
        }
    }
    pub fn set_item(comptime self: SortPackage, data: self.CONTAINER, idx: self.IDX, val: self.ELEM, userdata: self.USERDATA) self.CONTAINER {
        if (self.CUSTOM_DATA_SET) |set_opaque| {
            const set: *const self.DataSetter() = @ptrCast(@alignCast(set_opaque));
            if (self.HAS_USERDATA) {
                return set(data, idx, val, userdata);
            } else {
                return set(data, idx, val);
            }
        } else {
            return Utils.Mem.set(data, idx, val);
        }
    }
    pub fn swap_items(comptime self: SortPackage, data: self.CONTAINER, idx_a: self.IDX, idx_b: self.IDX, userdata: self.USERDATA) self.CONTAINER {
        const old_val_b = self.get_item(data, idx_b, userdata);
        const data_2 = self.set_item(data, idx_b, self.get_item(data, idx_a, userdata), userdata);
        return self.set_item(data_2, idx_a, old_val_b, userdata);
    }
    pub fn swap_items_already_have_b(comptime self: SortPackage, data: self.CONTAINER, idx_a: self.IDX, idx_b: self.IDX, old_val_b: self.ELEM, userdata: self.USERDATA) self.CONTAINER {
        const data_2 = self.set_item(data, idx_b, self.get_item(data, idx_a, userdata), userdata);
        return self.set_item(data_2, idx_a, old_val_b, userdata);
    }
    pub fn order_equal(comptime self: SortPackage, a: self.ELEM, b: self.ELEM, userdata: self.USERDATA) bool {
        if (self.CUSTOM_ORDER_EQUAL) |same_order_opaque| {
            const same: *const self.DataCompareFn() = @ptrCast(@alignCast(same_order_opaque));
            if (self.HAS_USERDATA) {
                return same(a, b, userdata);
            } else {
                return same(a, b);
            }
        } else {
            return Utils.shallow_equal(a, b);
        }
    }
    pub fn order_greater_than(comptime self: SortPackage, a: self.ELEM, b: self.ELEM, userdata: self.USERDATA) bool {
        if (self.CUSTOM_GREATER_THAN) |gt_opaque| {
            const greater: *const self.DataCompareFn() = @ptrCast(@alignCast(gt_opaque));
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    if (self.HAS_USERDATA) {
                        return greater(a, b, userdata);
                    } else {
                        return greater(a, b);
                    }
                },
                .REVERSE => {
                    if (self.HAS_USERDATA) {
                        return greater(b, a, userdata);
                    } else {
                        return greater(b, a);
                    }
                },
            }
        } else if (self.CUSTOM_LESS_THAN) |lt_opaque| {
            const less: *const self.DataCompareFn() = @ptrCast(@alignCast(lt_opaque));
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    if (self.HAS_USERDATA) {
                        return less(b, a, userdata);
                    } else {
                        return less(b, a);
                    }
                },
                .REVERSE => {
                    if (self.HAS_USERDATA) {
                        return less(a, b, userdata);
                    } else {
                        return less(a, b);
                    }
                },
            }
        } else {
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    return Utils.Compare.greater_than(a, b);
                },
                .REVERSE => {
                    return Utils.Compare.greater_than(b, a);
                },
            }
        }
    }
    pub fn order_less_than(comptime self: SortPackage, a: self.ELEM, b: self.ELEM, userdata: self.USERDATA) bool {
        if (self.CUSTOM_LESS_THAN) |lt_opaque| {
            const less: *const self.DataCompareFn() = @ptrCast(@alignCast(lt_opaque));
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    if (self.HAS_USERDATA) {
                        return less(a, b, userdata);
                    } else {
                        return less(a, b);
                    }
                },
                .REVERSE => {
                    if (self.HAS_USERDATA) {
                        return less(b, a, userdata);
                    } else {
                        return less(b, a);
                    }
                },
            }
        } else if (self.CUSTOM_GREATER_THAN) |gt_opaque| {
            const greater: *const self.DataCompareFn() = @ptrCast(@alignCast(gt_opaque));
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    if (self.HAS_USERDATA) {
                        return greater(b, a, userdata);
                    } else {
                        return greater(b, a);
                    }
                },
                .REVERSE => {
                    if (self.HAS_USERDATA) {
                        return greater(a, b, userdata);
                    } else {
                        return greater(a, b);
                    }
                },
            }
        } else {
            switch (self.SORT_ORDER) {
                .NORMAL => {
                    return Utils.Compare.less_than(a, b);
                },
                .REVERSE => {
                    return Utils.Compare.less_than(b, a);
                },
            }
        }
    }

    pub fn DataGetter(comptime self: SortPackage) type {
        if (self.HAS_USERDATA) {
            return GetFnUserdata(self.CONTAINER, self.IDX, self.ELEM, self.USERDATA);
        } else {
            return GetFn(self.CONTAINER, self.IDX, self.ELEM);
        }
    }
    pub fn DataSetter(comptime self: SortPackage) type {
        if (self.HAS_USERDATA) {
            return SetFnUserdata(self.CONTAINER, self.IDX, self.ELEM, self.USERDATA);
        } else {
            return SetFn(self.CONTAINER, self.IDX, self.ELEM);
        }
    }
    pub fn DataCompareFn(comptime self: SortPackage) type {
        if (self.HAS_USERDATA) {
            return CompareFn(self.ELEM, self.ELEM, self.USERDATA);
        } else {
            return CompareFn(self.ELEM, self.ELEM);
        }
    }
};

test "SortPackage.median_of_3_index" {
    const IDX = [3]u8{ 0, 1, 2 };
    const Case = struct {
        input: [3]u8,
        med_idxs: []const u8,

        pub fn new(vals: [3]u8, med_idxs: []const u8) @This() {
            return @This(){
                .input = vals,
                .med_idxs = med_idxs,
            };
        }
    };
    const cases = [_]Case{
        Case.new(.{ 1, 2, 3 }, &.{1}),
        Case.new(.{ 1, 3, 2 }, &.{2}),
        Case.new(.{ 2, 1, 3 }, &.{0}),
        Case.new(.{ 2, 3, 1 }, &.{0}),
        Case.new(.{ 3, 1, 2 }, &.{2}),
        Case.new(.{ 3, 2, 1 }, &.{1}),
        Case.new(.{ 3, 3, 3 }, &.{ 0, 1, 2 }),
        Case.new(.{ 1, 1, 2 }, &.{ 0, 1 }),
        Case.new(.{ 1, 2, 2 }, &.{ 1, 2 }),
    };
    const sort = SortPackage.sort_package()
        .with_custom_container(.{ .CONTAINER = void, .ELEM = u8, .IDX = u8 }, null)
        .with_sort_order(.NORMAL);
    next_case: for (cases) |case| {
        const med_idx, const med_val = sort.median_of_3(case.input, IDX, void{});
        for (case.med_idxs) |valid_median_idx| {
            if (med_idx == valid_median_idx) {
                if (med_val != case.input[med_idx]) return error.returned_val_isnt_the_one_at_that_index;
                continue :next_case;
            }
        }
        return error.median_idx_returned_is_incorrect;
    }
}

// test SortPackage {
//     var rand_core = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
//     const rand = rand_core.random();
//     const NUM_ITERATIONS = 10;
//     var buf_1: [1]u32 = undefined;
//     var buf_8: [8]u32 = undefined;
//     var buf_9: [9]u32 = undefined;
//     var searches: [10]u32 = undefined;
//     var search_idxs: [10]usize = undefined;
//     var results: [10]ResultItem(usize, u32, .IDX_AND_SEARCH_VAL) = undefined;
//     const search = SortPackage.sort_package()
//         .with_implicit_data_container([]const u32)
//         .with_implicit_search_container(u32)
//         .with_implicit_result_container(*ResultItem(usize, u32, .IDX_ONLY))
//         .with_equality_mode(.EXACTLY_EQUAL);
//     const search_many = SortPackage.sort_package()
//         .with_implicit_data_container([]const u32)
//         .with_implicit_search_container([]const u32)
//         .with_result_include_search_val_mode(.IDX_AND_SEARCH_VAL)
//         .with_implicit_result_container([]ResultItem(usize, u32, .IDX_AND_SEARCH_VAL))
//         .with_equality_mode(.EXACTLY_EQUAL);
//     const empty_always_null_idx = search.linear_search_for_one(.{
//         .data = buf_1[0..1],
//         .data_start = 0,
//         .data_end_exclusive = 0,
//         .search_params = 0,
//     });
//     try Test.expect_equal_src(empty_always_null_idx.was_found, LinearSearchOneFound.NO_DATA_ITEMS, @src(), "", .{});
//     const PROTO = struct {
//         const FillStage = enum(u8) {
//             FIND,
//             ADD,
//         };
//         fn do_single_search_tests(buf: []u32, rand_: std.Random) anyerror!void {
//             const N = buf.len;
//             for (0..NUM_ITERATIONS) |_| {
//                 for (0..N) |i| {
//                     buf[i] = rand_.int(u32);
//                 }
//                 Root.Sort.InsertionSort.insertion_sort_implicit(buf[0..]);
//                 var should_not_find: u32 = undefined;
//                 find_another_val_not_in_list: while (true) {
//                     should_not_find = rand_.int(u32);
//                     for (buf[0..]) |good_val| {
//                         if (good_val == should_not_find) continue :find_another_val_not_in_list;
//                     }
//                     break :find_another_val_not_in_list;
//                 }
//                 const should_not_find_idx_linear = search.linear_search_for_one(.{
//                     .data = buf[0..],
//                     .data_start = 0,
//                     .data_end_exclusive = N,
//                     .search_params = should_not_find,
//                 });
//                 try Test.expect_equal_src(should_not_find_idx_linear.was_found, LinearSearchOneFound.NOT_FOUND, @src(), "", .{});
//                 const should_not_find_tag = if (should_not_find < buf[0]) BinarySearchOneFound.NOT_FOUND_ORDERED_BEFORE_GIVEN_RANGE else if (should_not_find > buf[N - 1]) BinarySearchOneFound.NOT_FOUND_ORDERED_AFTER_GIVEN_RANGE else BinarySearchOneFound.NOT_FOUND_ORDERED_WITHIN_RANGE;
//                 const should_not_find_idx_binary = search.binary_search_for_one(.{
//                     .data = buf[0..],
//                     .data_start = 0,
//                     .data_end_exclusive = N,
//                     .search_params = should_not_find,
//                 });
//                 try Test.expect_equal_src(should_not_find_idx_binary.found, should_not_find_tag, @src(), "", .{});
//                 for (buf[0..], 0..) |should_find, i| {
//                     const should_find_idx_linear = search.linear_search_for_one(.{
//                         .data = buf[0..],
//                         .data_start = 0,
//                         .data_end_exclusive = N,
//                         .search_params = should_find,
//                     });
//                     try Test.expect_equal_src(should_find_idx_linear.was_found, LinearSearchOneFound.FOUND, @src(), "", .{});
//                     try Test.expect_equal_src(should_find_idx_linear.location.data_idx, i, @src(), "", .{});
//                     const should_find_idx_binary = search.binary_search_for_one(.{
//                         .data = buf[0..],
//                         .data_start = 0,
//                         .data_end_exclusive = N,
//                         .search_params = should_find,
//                     });
//                     try Test.expect_equal_src(should_find_idx_binary.found, BinarySearchOneFound.FOUND, @src(), "", .{});
//                     try Test.expect_equal_src(should_find_idx_binary.location.data_idx, i, @src(), "", .{});
//                 }
//             }
//         }
//         fn do_multi_search_tests(buf: []u32, search_idxs_: []usize, searches_: []u32, results_: []ResultItem(usize, u32, .IDX_AND_SEARCH_VAL), rand_: std.Random) anyerror!void {
//             const N = buf.len;
//             for (0..NUM_ITERATIONS) |_| {
//                 var num_filled: usize = 0;
//                 try_another_unused_number: while (num_filled < N) {
//                     const rand_val = rand_.int(u32);
//                     for (0..num_filled) |ii| {
//                         if (buf[ii] == rand_val) continue :try_another_unused_number;
//                     }
//                     buf[num_filled] = rand_val;
//                     num_filled += 1;
//                 }
//                 Root.Sort.InsertionSort.insertion_sort_implicit(buf[0..]);
//                 var updated_searches = searches_;
//                 var updated_search_idxs = search_idxs_;
//                 // var updated_results = results_;
//                 const num_to_find = rand_.intRangeAtMost(usize, 0, N);
//                 const num_to_not_find = rand_.intRangeAtMost(usize, 0, N - num_to_find);
//                 const search_total = num_to_find + num_to_not_find;
//                 try_another_index_to_find: while (updated_search_idxs.len < num_to_find) {
//                     const find_idx = rand_.uintLessThan(usize, buf.len);
//                     for (updated_search_idxs[0..]) |already_added_idx_to_find| {
//                         if (find_idx == already_added_idx_to_find) continue :try_another_index_to_find;
//                     }
//                     updated_search_idxs = Utils.Mem.append_assume_capacity(updated_search_idxs, find_idx);
//                     updated_searches = Utils.Mem.append_assume_capacity(updated_searches, buf[find_idx]);
//                 }
//                 try_another_idx_to_NOT_find: while (updated_searches.len < search_total) {
//                     const dont_find_val = rand_.int(u32);
//                     for (updated_searches[0..]) |good_val| {
//                         if (dont_find_val == good_val) continue :try_another_idx_to_NOT_find;
//                     }
//                     updated_searches = Utils.Mem.append_assume_capacity(updated_searches, dont_find_val);
//                 }
//                 updated_searches = Utils.Mem.scramble(u32, updated_searches, 0, search_total, rand_, 5);
//                 const linear_results = search_many.linear_search_for_many(.{
//                     .data = buf[0..],
//                     .data_start = 0,
//                     .data_end_exclusive = N,
//                     .search_params = updated_searches,
//                     .results_buffer = results_,
//                 });
//                 try Test.expect_equal_src(linear_results.results_count, num_to_find, @src(), "fail", .{});
//                 for (linear_results.locations) |location_| {
//                     const location: search_many.CurrentResultItem() = location_;
//                     const found_val = buf[location.data_idx];
//                     try Test.expect_equal_src(found_val, location.search_val, @src(), "fail", .{});
//                 }
//                 const binary_results = search_many.binary_search_for_many(.{
//                     .data = buf[0..],
//                     .data_start = 0,
//                     .data_end_exclusive = N,
//                     .search_params = updated_searches,
//                     .results_buffer = results_,
//                 });
//                 try Test.expect_equal_src(binary_results.results_count, num_to_find, @src(), "fail", .{});
//                 for (binary_results.locations) |location_| {
//                     const location: search_many.CurrentResultItem() = location_;
//                     const found_val = buf[location.data_idx];
//                     try Test.expect_equal_src(found_val, location.search_val, @src(), "fail", .{});
//                 }
//             }
//         }
//     };
//     try PROTO.do_single_search_tests(buf_1[0..], rand);
//     try PROTO.do_single_search_tests(buf_8[0..], rand);
//     try PROTO.do_single_search_tests(buf_9[0..], rand);
//     try PROTO.do_multi_search_tests(buf_1[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
//     try PROTO.do_multi_search_tests(buf_8[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
//     try PROTO.do_multi_search_tests(buf_9[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
// }
