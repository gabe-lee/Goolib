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

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
const CompareFuncUserdata = Utils.Compare.CompareFuncUserdata;
const CompareFunc = Utils.Compare.CompareFunc;

pub const SearchOrder = enum {
    SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER,
    SEARCH_PARAMS_UNORDERED,
};

const DEBUG = std.debug.print;

pub fn GetFunc(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE) ELEM_TYPE;
}
pub fn SetFunc(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, val: ELEM_TYPE) void;
}
pub fn AppendFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, val: ELEM_TYPE, alloc: Allocator) DATA_STRUCTURE;
}
pub fn DequeueFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ELEM_TYPE };
}
pub fn DequeueOrNullFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ?ELEM_TYPE };
}

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

pub const SearchPackage = struct {
    DATA_CONTAINER: type = undefined,
    DATA_CONTAINER_ELEM: type = undefined,
    DATA_CONTAINER_IDX: type = undefined,
    SEARCH_PARAM_CONTAINER: type = undefined,
    SEARCH_PARAM_CONTAINER_ELEM: type = undefined,
    SEARCH_PARAM_CONTAINER_IDX: type = undefined,
    RESULT_CONTAINER: type = undefined,
    RESULT_CONTAINER_IDX: type = undefined,
    RESULT_CONTAINER_ELEM: type = undefined,
    HAS_USERDATA_TYPE: bool = false,
    USERDATA_TYPE: type = void,
    CUSTOM_DATA_GET: ?*const anyopaque = null,
    CUSTOM_DATA_SET: ?*const anyopaque = null,
    CUSTOM_SEARCH_DEQUEUE: ?*const anyopaque = null,
    CUSTOM_RESULT_APPEND: ?*const anyopaque = null,
    CUSTOM_ORDER_MATCH: ?*const anyopaque = null,
    CUSTOM_GREATER_THAN: ?*const anyopaque = null,
    CUSTOM_LESS_THAN: ?*const anyopaque = null,
    CUSTOM_EXACT_EQUAL: ?*const anyopaque = null,
    EQUALITY_MODE: SearchEqualityMode = .EXACTLY_EQUAL,
    SEARCH_PARAM_ORDER: SearchOrder = .SEARCH_PARAMS_UNORDERED,
    RESULTS_INCLUDE_MODE: ResultsIncludeMode = .IDX_ONLY,
    // Safe modes only
    VALID_DATA_CONTAINER: BuilderValidation = .UNINITIALIZED,
    VALID_SEARCH_CONTAINER: BuilderValidation = .UNINITIALIZED,
    VALID_RESULT_CONTAINER: BuilderValidation = .UNINITIALIZED,
    VALID_COMPARE_FUNCS: BuilderValidation = .DEFAULT,

    fn assert_valid(comptime self: SearchPackage, comptime src: std.builtin.SourceLocation) void {
        self.VALID_DATA_CONTAINER.assert_valid("DATA_CONTAINER", src);
        self.VALID_SEARCH_CONTAINER.assert_valid("SEARCH_CONTAINER", src);
        self.VALID_RESULT_CONTAINER.assert_valid("RESULT_CONTAINER", src);
        self.VALID_COMPARE_FUNCS.assert_valid("COMPARE_FUNCS", src);
    }

    pub fn SearchOneInputs(comptime self: SearchPackage) type {
        return struct {
            data: self.DATA_CONTAINER,
            data_start: self.DATA_CONTAINER_IDX = 0,
            data_end_exclusive: self.DATA_CONTAINER_IDX,
            search_params: self.SEARCH_PARAM_CONTAINER,
            userdata: self.USERDATA_TYPE = if (self.USERDATA_TYPE == void) void{} else undefined,

            pub fn data_only(inputs: @This()) SearchInputsDataOnly(self) {
                return SearchInputsDataOnly(self){
                    .data = inputs.data,
                    .data_start = inputs.data_start,
                    .data_end_exclusive = inputs.data_end_exclusive,
                    .userdata = inputs.userdata,
                };
            }
        };
    }
    pub fn SearchManyInputs(comptime self: SearchPackage) type {
        return struct {
            data: self.DATA_CONTAINER,
            data_start: self.DATA_CONTAINER_IDX = 0,
            data_end_exclusive: self.DATA_CONTAINER_IDX,
            search_params: self.SEARCH_PARAM_CONTAINER,
            results_buffer: self.RESULT_CONTAINER,
            userdata: self.USERDATA_TYPE = if (self.USERDATA_TYPE == void) void{} else undefined,
            results_alloc: Allocator = Root.DummyAllocator.allocator_panic_free_noop,

            pub fn data_only(inputs: @This()) SearchInputsDataOnly(self) {
                return SearchInputsDataOnly(self){
                    .data = inputs.data,
                    .data_start = inputs.data_start,
                    .data_end_exclusive = inputs.data_end_exclusive,
                    .userdata = inputs.userdata,
                };
            }
        };
    }
    pub fn SearchInputsDataOnly(comptime self: SearchPackage) type {
        return struct {
            data: self.DATA_CONTAINER,
            data_start: self.DATA_CONTAINER_IDX = 0,
            data_end_exclusive: self.DATA_CONTAINER_IDX,
            userdata: self.USERDATA_TYPE = if (self.USERDATA_TYPE == void) void{} else undefined,
        };
    }

    pub fn ManyResults(comptime self: SearchPackage) type {
        return struct {
            locations: self.RESULT_CONTAINER = undefined,
            updated_search: self.SEARCH_PARAM_CONTAINER = undefined,
            results_count: self.RESULT_CONTAINER_IDX = 0,
        };
    }

    pub fn CurrentResultItem(comptime self: SearchPackage) type {
        return ResultItem(self.DATA_CONTAINER_IDX, self.SEARCH_PARAM_CONTAINER_ELEM, self.RESULTS_INCLUDE_MODE);
    }

    fn include_search_val(comptime self: SearchPackage) bool {
        return self.RESULTS_INCLUDE_MODE == .IDX_AND_SEARCH_VAL;
    }

    pub fn BinarySearchOneResult(comptime self: SearchPackage) type {
        return struct {
            location: self.CurrentResultItem() = .{},
            found: BinarySearchOneFound = .NO_SEARCH_ITEMS,
            updated_search: self.SEARCH_PARAM_CONTAINER,
        };
    }

    pub fn LinearSearchOneResult(comptime self: SearchPackage) type {
        return struct {
            location: self.CurrentResultItem() = .{},
            was_found: LinearSearchOneFound = .NO_SEARCH_ITEMS,
            updated_search: self.SEARCH_PARAM_CONTAINER,
        };
    }

    /// Using the provided `SearchPackage` settings and functions, find the first matching item,
    /// starting from the beginning.
    ///
    /// Returns the index of the found item (or null if no matching item was found) and the
    /// updated search params container
    pub fn linear_search_for_one(comptime self: SearchPackage, inputs: self.SearchOneInputs()) self.LinearSearchOneResult() {
        const RESULT = self.LinearSearchOneResult();
        self.assert_valid(@src());
        const DATA_IDX = self.DATA_CONTAINER_IDX;
        if (inputs.data_start >= inputs.data_end_exclusive) return RESULT{
            .was_found = .NO_DATA_ITEMS,
            .updated_search = inputs.search_params,
        };
        var data_idx: DATA_IDX = inputs.data_start;
        const new_search_params, const search_item_or_null = self.next_search_param_if_any(inputs.search_params);
        if (search_item_or_null) |search_item| {
            while (data_idx < inputs.data_end_exclusive) : (data_idx += 1) {
                const data_item = self.get_item(inputs.data, data_idx);
                switch (self.EQUALITY_MODE) {
                    .EXACTLY_EQUAL => {
                        if (self.exactly_equal_item(search_item, data_item, inputs.userdata)) {
                            return RESULT{
                                .location = .new(data_idx, search_item),
                                .was_found = .FOUND,
                                .updated_search = new_search_params,
                            };
                        }
                    },
                    .ORDER_EQUAL => {
                        if (self.order_equal_item(search_item, data_item, inputs.userdata)) {
                            return RESULT{
                                .location = .new(data_idx, search_item),
                                .was_found = .FOUND,
                                .updated_search = new_search_params,
                            };
                        }
                    },
                }
            }
        } else {
            return RESULT{
                .was_found = .NO_SEARCH_ITEMS,
                .updated_search = new_search_params,
            };
        }
        return RESULT{
            .location = .new(inputs.data_start, search_item_or_null.?),
            .was_found = .NOT_FOUND,
            .updated_search = new_search_params,
        };
    }

    /// Using the provided `SearchPackage` settings and functions, find all matching items,
    /// starting from the beginning.
    ///
    /// Appends each found index to the provided results container, and returns the
    /// updated `results` container and the number of results found
    pub fn linear_search_for_many(comptime self: SearchPackage, inputs: self.SearchManyInputs()) self.ManyResults() {
        const RESULTS = self.ManyResults();
        self.assert_valid(@src());
        const DATA_IDX = self.DATA_CONTAINER_IDX;
        const RESULT_IDX = self.RESULT_CONTAINER_IDX;
        if (inputs.data_start >= inputs.data_end_exclusive) return RESULTS{
            .locations = inputs.results_buffer,
            .updated_search = inputs.search_params,
            .results_count = 0,
        };
        var result_count: RESULT_IDX = 0;
        var data_idx: DATA_IDX = undefined;
        var min_data_idx: DATA_IDX = inputs.data_start;
        var new_results = inputs.results_buffer;
        var remaining_search_params, var has_search_item = self.next_search_param_if_any(inputs.search_params);
        next_item_to_find: while (has_search_item) |search_item| {
            data_idx = min_data_idx;
            while (data_idx < inputs.data_end_exclusive) : (data_idx += 1) {
                const data_item = self.get_item(inputs.data, data_idx);
                const match = switch (self.EQUALITY_MODE) {
                    .EXACTLY_EQUAL => self.exactly_equal_item(search_item, data_item, inputs.userdata),
                    .ORDER_EQUAL => self.order_equal_item(search_item, data_item, inputs.userdata),
                };
                if (match) {
                    new_results = self.append_result(new_results, .new(data_idx, search_item), inputs.results_alloc);
                    result_count += 1;
                    if (self.SEARCH_PARAM_ORDER == .SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER) {
                        min_data_idx = data_idx;
                    }
                    remaining_search_params, has_search_item = self.next_search_param_if_any(remaining_search_params);
                    continue :next_item_to_find;
                }
            }
            remaining_search_params, has_search_item = self.next_search_param_if_any(remaining_search_params);
        }
        return self.ManyResults(){
            .locations = new_results,
            .updated_search = remaining_search_params,
            .results_count = result_count,
        };
    }

    pub fn BinaryLocateResult(comptime self: SearchPackage) type {
        return struct {
            data_idx: self.DATA_CONTAINER_IDX,
            found: bool,

            pub fn init(initial_data_idx: self.DATA_CONTAINER_IDX) @This() {
                return @This(){
                    .data_idx = initial_data_idx,
                    .found = false,
                };
            }
        };
    }

    fn binary_locate(comptime self: SearchPackage, inputs: self.SearchInputsDataOnly(), search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_min_idx: self.DATA_CONTAINER_IDX, data_max_idx_excluded: self.DATA_CONTAINER_IDX) BinaryLocateResult(self) {
        var result = BinaryLocateResult(self).init(data_min_idx);
        var len = data_max_idx_excluded - data_min_idx;
        var move_right_mask: self.DATA_CONTAINER_IDX = undefined;
        var data_item: self.DATA_CONTAINER_ELEM = undefined;
        while (len > 1) {
            const half = len >> 1;
            data_item = self.get_item(inputs.data, result.data_idx + half - 1);
            const move_right = self.search_item_greater_than(search_item, data_item, inputs.userdata);
            move_right_mask = @intCast(@intFromBool(move_right));
            move_right_mask = Math.bit_flood_left(move_right_mask);
            result.data_idx += half & move_right_mask;
            len -= half;
        }
        data_item = self.get_item(inputs.data, result.data_idx);
        if (self.search_item_greater_than(search_item, data_item, inputs.userdata)) {
            result.data_idx += 1;
            return result;
        }
        switch (self.EQUALITY_MODE) {
            .ORDER_EQUAL => {
                if (self.order_equal_item(search_item, data_item, inputs.userdata)) {
                    result.found = true;
                    return result;
                }
            },
            .EXACTLY_EQUAL => {
                if (self.exactly_equal_item(search_item, data_item, inputs.userdata)) {
                    result.found = true;
                    return result;
                }
                while (self.order_equal_item(search_item, data_item, inputs.userdata)) {
                    result.data_idx += 1;
                    if (result.data_idx >= data_max_idx_excluded) break;
                    data_item = self.get_item(inputs.data, result.data_idx);
                    if (self.exactly_equal_item(search_item, data_item, inputs.userdata)) {
                        result.found = true;
                        return result;
                    }
                }
            },
        }
        return result;
    }

    /// Using the provided `SearchPackage` settings and functions, find a matching item
    /// within the ordered data by perfoming binary splits
    ///
    /// Returns the last index checked, whether that index matched (and if it didn't, where would a match be ordered), and the
    /// updated search params container
    pub fn binary_search_for_one(comptime self: SearchPackage, inputs: self.SearchOneInputs()) self.BinarySearchOneResult() {
        const RESULT = self.BinarySearchOneResult();
        self.assert_valid(@src());
        if (inputs.data_end_exclusive <= inputs.data_start) {
            @branchHint(.unlikely);
            return RESULT{
                .found = .NO_DATA_ITEMS,
                .updated_search = inputs.search_params,
            };
        }
        const new_search_params, const search_item_or_null = self.next_search_param_if_any(inputs.search_params);
        if (search_item_or_null) |search_item| {
            const location = self.binary_locate(inputs.data_only(), search_item, inputs.data_start, inputs.data_end_exclusive);
            if (location.found) {
                return RESULT{
                    .location = .new(location.data_idx, search_item),
                    .found = .FOUND,
                    .updated_search = new_search_params,
                };
            }
            if (location.data_idx >= inputs.data_end_exclusive) {
                return RESULT{
                    .location = .new(location.data_idx, search_item),
                    .found = .NOT_FOUND_ORDERED_AFTER_GIVEN_RANGE,
                    .updated_search = new_search_params,
                };
            }
            if (location.data_idx <= inputs.data_start) {
                return RESULT{
                    .location = .new(location.data_idx, search_item),
                    .found = .NOT_FOUND_ORDERED_BEFORE_GIVEN_RANGE,
                    .updated_search = new_search_params,
                };
            }
            return RESULT{
                .location = .new(location.data_idx, search_item),
                .found = .NOT_FOUND_ORDERED_WITHIN_RANGE,
                .updated_search = new_search_params,
            };
        } else {
            return RESULT{
                .found = .NO_SEARCH_ITEMS,
                .updated_search = new_search_params,
            };
        }
    }

    /// Using the provided `SearchPackage` settings and functions, find all matching items
    /// within the ordered data by performing binary splits
    ///
    /// Appends each found index to the provided results container, and returns the
    /// updated `results` container and the number of results found
    pub fn binary_search_for_many(comptime self: SearchPackage, inputs: self.SearchManyInputs()) self.ManyResults() {
        self.assert_valid(@src());
        const RESULTS = self.ManyResults();
        const DATA_IDX = self.DATA_CONTAINER_IDX;
        if (inputs.data_end_exclusive <= inputs.data_start) return self.ManyResults(){
            .locations = inputs.results_buffer,
            .updated_search = inputs.search_params,
            .results_count = 0,
        };
        var data_idx: DATA_IDX = inputs.data_start;
        var min_data_idx: DATA_IDX = inputs.data_start;
        var data_len: DATA_IDX = undefined;
        var new_results = inputs.results_buffer;
        var remaining_search_params, var has_search_item = self.next_search_param_if_any(inputs.search_params);
        var results_return = RESULTS{};
        while (has_search_item) |search_item| {
            data_idx = min_data_idx;
            if (inputs.data_end_exclusive <= min_data_idx) break;
            data_len = inputs.data_end_exclusive - min_data_idx;
            const location = self.binary_locate(inputs.data_only(), search_item, min_data_idx, inputs.data_end_exclusive);
            if (location.found) {
                new_results = self.append_result(new_results, .new(location.data_idx, search_item), inputs.results_alloc);
                results_return.results_count += 1;
                if (self.SEARCH_PARAM_ORDER == .SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER) {
                    min_data_idx = location.data_idx;
                }
            } else {
                if (self.SEARCH_PARAM_ORDER == .SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER) {
                    min_data_idx = data_idx;
                }
            }
            remaining_search_params, has_search_item = self.next_search_param_if_any(remaining_search_params);
        }
        results_return.locations = new_results;
        results_return.updated_search = remaining_search_params;
        return results_return;
    }

    pub const DataContainerSettings = struct {
        CONTAINER_TYPE: type,
        IDX_TYPE: type,
        ELEM_TYPE: type,

        pub fn Getter(comptime self: @This()) type {
            return GetFunc(self.CONTAINER_TYPE, self.IDX_TYPE, self.ELEM_TYPE);
        }
        pub fn Setter(comptime self: @This()) type {
            return SetFunc(self.CONTAINER_TYPE, self.IDX_TYPE, self.ELEM_TYPE);
        }

        pub fn GetterSetter(comptime self: @This()) type {
            return struct {
                getter: ?*const self.Getter() = null,
                setter: ?*const self.Setter() = null,
            };
        }
    };

    pub const SearchContainerSettings = struct {
        CONTAINER_TYPE: type,
        ELEM_TYPE: type,

        pub fn Dequeuer(comptime self: @This()) type {
            return DequeueOrNullFunc(self.CONTAINER_TYPE, self.ELEM_TYPE);
        }
    };

    pub const ResultContainerSettings = struct {
        CONTAINER_TYPE: type,
        IDX_TYPE: type,

        pub fn Appender(comptime self: @This(), comptime package: SearchPackage) type {
            return AppendFunc(self.CONTAINER_TYPE, package.CurrentResultItem());
        }
    };

    pub fn CompareFuncs(comptime self: SearchPackage) type {
        return struct {
            order_match: ?*const self.CompareSearchToItemFn() = null,
            order_greater: ?*const self.CompareSearchToItemFn() = null,
            order_lesser: ?*const self.CompareSearchToItemFn() = null,
            exactly_equal: ?*const self.CompareSearchToItemFn() = null,
        };
    }

    pub fn search_package() SearchPackage {
        return SearchPackage{};
    }

    pub const ImplicitPackage = struct {
        DATA_CONTAINER: type,
        SEARCH_PARAM_CONTAINER: type,
        RESULTS_CONTAINER: type,
    };

    pub fn with_implicit_containers(comptime self: SearchPackage, comptime DATA_CONTAINER: type, comptime SEARCH_PARAM_CONTAINER: type, comptime RESULTS_CONTAINER: type) SearchPackage {
        return self.with_implicit_data_container(DATA_CONTAINER)
            .with_implicit_search_container(SEARCH_PARAM_CONTAINER)
            .with_implicit_result_container(RESULTS_CONTAINER);
    }

    pub fn with_implicit_containers_include_search_params_in_results(comptime self: SearchPackage, comptime DATA_CONTAINER: type, comptime SEARCH_PARAM_CONTAINER: type, comptime RESULTS_CONTAINER: type) SearchPackage {
        return self.with_implicit_data_container(DATA_CONTAINER)
            .with_implicit_search_container(SEARCH_PARAM_CONTAINER)
            .with_result_include_search_val_mode(.IDX_AND_SEARCH_VAL)
            .with_implicit_result_container(RESULTS_CONTAINER);
    }
    pub fn with_implicit_containers_do_not_include_search_params_in_results(comptime self: SearchPackage, comptime DATA_CONTAINER: type, comptime SEARCH_PARAM_CONTAINER: type, comptime RESULTS_CONTAINER: type) SearchPackage {
        return self.with_implicit_data_container(DATA_CONTAINER)
            .with_implicit_search_container(SEARCH_PARAM_CONTAINER)
            .with_result_include_search_val_mode(.IDX_ONLY)
            .with_implicit_result_container(RESULTS_CONTAINER);
    }

    pub fn with_implicit_data_container(comptime self: SearchPackage, comptime DATA_CONTAINER: type) SearchPackage {
        comptime var new_self = self;
        new_self.DATA_CONTAINER = DATA_CONTAINER;
        new_self.DATA_CONTAINER_IDX = usize;
        new_self.DATA_CONTAINER_ELEM = Types.IndexableChild(DATA_CONTAINER);
        new_self.CUSTOM_DATA_GET = null;
        new_self.CUSTOM_DATA_SET = null;
        new_self.VALID_RESULT_CONTAINER = .INVALID;
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_DATA_CONTAINER = .DEFAULT;
        return new_self;
    }

    pub fn with_custom_data_container(comptime self: SearchPackage, comptime SETTINGS: DataContainerSettings, comptime GET_SET: SETTINGS.GetterSetter()) SearchPackage {
        comptime var new_self = self;
        new_self.DATA_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.DATA_CONTAINER_IDX = SETTINGS.IDX_TYPE;
        new_self.DATA_CONTAINER_ELEM = SETTINGS.ELEM_TYPE;
        new_self.CUSTOM_DATA_GET = @ptrCast(GET_SET.getter);
        new_self.CUSTOM_DATA_SET = @ptrCast(GET_SET.setter);
        new_self.VALID_RESULT_CONTAINER = .INVALID;
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_DATA_CONTAINER = .SET_CUSTOM;
        return new_self;
    }

    pub fn with_implicit_search_container(comptime self: SearchPackage, comptime SEARCH_CONTAINER: type) SearchPackage {
        comptime var new_self = self;
        new_self.SEARCH_PARAM_CONTAINER = SEARCH_CONTAINER;
        new_self.SEARCH_PARAM_CONTAINER_ELEM = if (Types.is_indexable(SEARCH_CONTAINER)) Types.IndexableChild(SEARCH_CONTAINER) else if (Types.type_is_pointer_or_slice(SEARCH_CONTAINER)) Types.child_type(SEARCH_CONTAINER) else SEARCH_CONTAINER;
        new_self.CUSTOM_SEARCH_DEQUEUE = null;
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_SEARCH_CONTAINER = .DEFAULT;
        if (self.include_search_val() and self.SEARCH_PARAM_CONTAINER_ELEM != new_self.SEARCH_PARAM_CONTAINER_ELEM) new_self.VALID_RESULT_CONTAINER = .INVALID;
        return new_self;
    }

    pub fn with_custom_search_container(comptime self: SearchPackage, comptime SETTINGS: SearchContainerSettings, comptime DEQUEUE: ?*const SETTINGS.Dequeuer()) SearchPackage {
        comptime var new_self = self;
        new_self.SEARCH_PARAM_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.SEARCH_PARAM_CONTAINER_ELEM = SETTINGS.ELEM_TYPE;
        new_self.CUSTOM_SEARCH_DEQUEUE = @ptrCast(DEQUEUE);
        new_self.VALID_COMPARE_FUNCS = if (new_self.VALID_COMPARE_FUNCS != .DEFAULT) .INVALID else .DEFAULT;
        new_self.VALID_SEARCH_CONTAINER = .SET_CUSTOM;
        if (self.include_search_val() and self.SEARCH_PARAM_CONTAINER_ELEM != new_self.SEARCH_PARAM_CONTAINER_ELEM) new_self.VALID_RESULT_CONTAINER = .INVALID;
        return new_self;
    }

    pub fn with_implicit_result_container(comptime self: SearchPackage, comptime RESULT_CONTAINER: type) SearchPackage {
        assert_with_reason(Utils.Mem.ElementTypeOrDefaultForReaderWriter(RESULT_CONTAINER, self.CurrentResultItem()) == self.CurrentResultItem(), @src(), "element type for result container `{s}` is not the needed type `{s}`", .{ @typeName(Utils.Mem.ElementTypeOrDefaultForReaderWriter(RESULT_CONTAINER, self.CurrentResultItem())), @typeName(self.CurrentResultItem()) });
        comptime var new_self = self;
        new_self.RESULT_CONTAINER = RESULT_CONTAINER;
        new_self.RESULT_CONTAINER_ELEM = self.CurrentResultItem();
        new_self.RESULT_CONTAINER_IDX = usize;
        new_self.CUSTOM_RESULT_APPEND = null;
        new_self.VALID_RESULT_CONTAINER = .DEFAULT;
        return new_self;
    }

    pub fn with_custom_result_container(comptime self: SearchPackage, comptime SETTINGS: ResultContainerSettings, comptime APPEND: ?*const SETTINGS.Appender(self)) SearchPackage {
        assert_with_reason(Utils.Mem.ElementTypeOrDefaultForReaderWriter(SETTINGS.CONTAINER_TYPE, self.CurrentResultItem()) == self.CurrentResultItem(), @src(), "element type for result container `{s}` is not the needed type `{s}`", .{ @typeName(Utils.Mem.ElementTypeOrDefaultForReaderWriter(SETTINGS.CONTAINER_TYPE, self.CurrentResultItem())), @typeName(self.CurrentResultItem()) });
        comptime var new_self = self;
        new_self.RESULT_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.RESULT_CONTAINER_ELEM = self.CurrentResultItem();
        new_self.RESULT_CONTAINER_IDX = SETTINGS.IDX_TYPE;
        new_self.CUSTOM_RESULT_APPEND = @ptrCast(APPEND);
        new_self.VALID_RESULT_CONTAINER = .SET_CUSTOM;
        return new_self;
    }

    pub fn with_result_include_search_val_mode(comptime self: SearchPackage, comptime MODE: ResultsIncludeMode) SearchPackage {
        comptime var new_self = self;
        new_self.RESULTS_INCLUDE_MODE = MODE;
        if (self.RESULTS_INCLUDE_MODE != new_self.RESULTS_INCLUDE_MODE) {
            new_self.VALID_RESULT_CONTAINER = .INVALID;
        }
        return new_self;
    }

    pub fn with_userdata_type(comptime self: SearchPackage, comptime USERDATA: type) SearchPackage {
        comptime var new_self = self;
        new_self.USERDATA_TYPE = USERDATA;
        new_self.HAS_USERDATA_TYPE = true;
        if (new_self.USERDATA_TYPE != self.USERDATA_TYPE or new_self.HAS_USERDATA_TYPE != self.HAS_USERDATA_TYPE) {
            new_self.VALID_COMPARE_FUNCS = .INVALID;
        }
        return new_self;
    }
    pub fn with_no_userdata_type(comptime self: SearchPackage) SearchPackage {
        comptime var new_self = self;
        new_self.USERDATA_TYPE = void;
        new_self.HAS_USERDATA_TYPE = false;
        if (new_self.USERDATA_TYPE != self.USERDATA_TYPE or new_self.HAS_USERDATA_TYPE != self.HAS_USERDATA_TYPE) {
            new_self.VALID_COMPARE_FUNCS = .INVALID;
        }
        return new_self;
    }

    pub fn with_implicit_compare_funcs(comptime self: SearchPackage) SearchPackage {
        comptime var new_self = self;
        new_self.CUSTOM_GREATER_THAN = null;
        new_self.CUSTOM_LESS_THAN = null;
        new_self.CUSTOM_EXACT_EQUAL = null;
        new_self.CUSTOM_ORDER_MATCH = null;
        new_self.VALID_COMPARE_FUNCS = .DEFAULT;
        return new_self;
    }

    pub fn with_custom_compare_funcs(comptime self: SearchPackage, comptime FUNCS: self.CompareFuncs()) SearchPackage {
        comptime var new_self = self;
        new_self.CUSTOM_GREATER_THAN = FUNCS.order_greater;
        new_self.CUSTOM_LESS_THAN = FUNCS.order_lesser;
        new_self.CUSTOM_EXACT_EQUAL = FUNCS.exactly_equal;
        new_self.CUSTOM_ORDER_MATCH = FUNCS.order_match;
        new_self.VALID_COMPARE_FUNCS = .SET_CUSTOM;
        return new_self;
    }

    pub fn with_equality_mode(comptime self: SearchPackage, comptime MODE: SearchEqualityMode) SearchPackage {
        comptime var new_self = self;
        new_self.EQUALITY_MODE = MODE;
        return new_self;
    }
    pub fn with_search_param_order(comptime self: SearchPackage, comptime ORDER: SearchOrder) SearchPackage {
        comptime var new_self = self;
        new_self.SEARCH_PARAM_ORDER = ORDER;
        return new_self;
    }

    pub fn has_greater_than(comptime self: SearchPackage) bool {
        return self.CUSTOM_GREATER_THAN != null;
    }
    pub fn has_less_than(comptime self: SearchPackage) bool {
        return self.CUSTOM_LESS_THAN != null;
    }
    pub fn has_order_match(comptime self: SearchPackage) bool {
        return self.CUSTOM_ORDER_MATCH != null or self.CUSTOM_EXACT_EQUAL != null;
    }
    pub fn has_exact_equal(comptime self: SearchPackage) bool {
        return self.CUSTOM_EXACT_EQUAL != null;
    }

    pub fn get_item(comptime self: SearchPackage, data: self.DATA_CONTAINER, idx: self.DATA_CONTAINER_IDX) self.DATA_CONTAINER_ELEM {
        if (self.CUSTOM_DATA_GET) |get_opaque| {
            const get: *const self.DataGetter() = @ptrCast(@alignCast(get_opaque));
            return get(data, idx);
        } else {
            return Utils.Mem.get(self.DATA_CONTAINER_ELEM, data, idx);
        }
    }
    pub fn set_item(comptime self: SearchPackage, data: self.DATA_CONTAINER, idx: self.DATA_CONTAINER_IDX, val: self.DATA_CONTAINER_ELEM) self.DATA_CONTAINER {
        if (self.CUSTOM_DATA_SET) |set_opaque| {
            const set: *const self.DataSetter() = @ptrCast(@alignCast(set_opaque));
            set(data, idx, val);
            return data;
        } else {
            return Utils.Mem.set(data, idx, val);
        }
    }
    pub fn next_search_param_if_any(comptime self: SearchPackage, search: self.SEARCH_PARAM_CONTAINER) struct { self.SEARCH_PARAM_CONTAINER, ?self.SEARCH_PARAM_CONTAINER_ELEM } {
        if (self.CUSTOM_SEARCH_DEQUEUE) |dequeue_opaque| {
            const dequeue: *const self.SearchDequeuer() = @ptrCast(@alignCast(dequeue_opaque));
            return dequeue(search);
        } else {
            return Utils.Mem.dequeue_or_null(self.SEARCH_PARAM_CONTAINER_ELEM, search);
        }
    }
    pub fn append_result(comptime self: SearchPackage, results: self.RESULT_CONTAINER, new_result: self.CurrentResultItem(), alloc: Allocator) self.RESULT_CONTAINER {
        var new_results = results;
        if (self.CUSTOM_RESULT_APPEND) |append_opaque| {
            const append: *const self.ResultAppender() = @ptrCast(@alignCast(append_opaque));
            new_results = append(results, new_result, alloc);
        } else {
            new_results = Utils.Mem.append(new_results, new_result, alloc);
        }
        return new_results;
    }
    pub fn closest_match_item(comptime self: SearchPackage, search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_item: self.DATA_CONTAINER_ELEM, userdata: self.USERDATA_TYPE) bool {
        if (self.CUSTOM_EXACT_EQUAL) |equal_opaque| {
            const equal: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(equal_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return equal(search_item, data_item, userdata);
            } else {
                return equal(search_item, data_item);
            }
        } else if (self.CUSTOM_ORDER_MATCH) |match_opaque| {
            const match: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(match_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return match(search_item, data_item, userdata);
            } else {
                return match(search_item, data_item);
            }
        } else {
            return Utils.shallow_equal(search_item, data_item);
        }
    }
    pub fn order_equal_item(comptime self: SearchPackage, search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_item: self.DATA_CONTAINER_ELEM, userdata: self.USERDATA_TYPE) bool {
        if (self.CUSTOM_ORDER_MATCH) |match_opaque| {
            const match: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(match_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return match(search_item, data_item, userdata);
            } else {
                return match(search_item, data_item);
            }
        } else {
            return Utils.shallow_equal(search_item, data_item);
        }
    }
    pub fn exactly_equal_item(comptime self: SearchPackage, search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_item: self.DATA_CONTAINER_ELEM, userdata: self.USERDATA_TYPE) bool {
        if (self.CUSTOM_EXACT_EQUAL) |equal_opaque| {
            const equal: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(equal_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return equal(search_item, data_item, userdata);
            } else {
                return equal(search_item, data_item);
            }
        } else {
            return Utils.shallow_equal(search_item, data_item);
        }
    }
    pub fn search_item_greater_than(comptime self: SearchPackage, search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_item: self.DATA_CONTAINER_ELEM, userdata: self.USERDATA_TYPE) bool {
        if (self.CUSTOM_GREATER_THAN) |gt_opaque| {
            const greater: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(gt_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return greater(search_item, data_item, userdata);
            } else {
                return greater(search_item, data_item);
            }
        } else if (self.CUSTOM_LESS_THAN != null and self.CUSTOM_ORDER_MATCH != null) {
            const less: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(self.CUSTOM_LESS_THAN.?));
            const match: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(self.CUSTOM_ORDER_MATCH.?));
            if (self.HAS_USERDATA_TYPE) {
                return !match(search_item, data_item, userdata) and less(search_item, data_item, userdata);
            } else {
                return !match(search_item, data_item) and less(search_item, data_item);
            }
        } else {
            return Utils.Compare.greater_than(search_item, data_item);
        }
    }
    pub fn search_item_less_than(comptime self: SearchPackage, search_item: self.SEARCH_PARAM_CONTAINER_ELEM, data_item: self.DATA_CONTAINER_ELEM, userdata: self.USERDATA_TYPE) bool {
        if (self.CUSTOM_LESS_THAN) |lt_opaque| {
            const less: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(lt_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return less(search_item, data_item, userdata);
            } else {
                return less(search_item, data_item);
            }
        } else if (self.CUSTOM_GREATER_THAN != null and self.CUSTOM_ORDER_MATCH != null) {
            const greater: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(self.CUSTOM_GREATER_THAN.?));
            const match: *const self.CompareSearchToItemFn() = @ptrCast(@alignCast(self.CUSTOM_ORDER_MATCH.?));
            if (self.HAS_USERDATA_TYPE) {
                return !match(search_item, data_item, userdata) and greater(search_item, data_item, userdata);
            } else {
                return !match(search_item, data_item) and greater(search_item, data_item);
            }
        } else {
            return Utils.Compare.less_than(search_item, data_item);
        }
    }

    pub fn DataGetter(comptime self: SearchPackage) type {
        return GetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX, self.DATA_CONTAINER_ELEM);
    }
    pub fn DataSetter(comptime self: SearchPackage) type {
        return SetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX, self.DATA_CONTAINER_ELEM);
    }
    pub fn ResultAppender(comptime self: SearchPackage) type {
        return AppendFunc(self.RESULT_CONTAINER, self.CurrentResultItem());
    }
    pub fn SearchDequeuer(comptime self: SearchPackage) type {
        return DequeueOrNullFunc(self.SEARCH_PARAM_CONTAINER, self.SEARCH_PARAM_CONTAINER_ELEM);
    }
    pub fn CompareSearchToItemFn(comptime self: SearchPackage) type {
        if (self.HAS_USERDATA_TYPE) {
            return CompareFuncUserdata(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM, self.USERDATA_TYPE);
        } else {
            return CompareFunc(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM);
        }
    }
};

test SearchPackage {
    var rand_core = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    const rand = rand_core.random();
    const NUM_ITERATIONS = 10;
    var buf_1: [1]u32 = undefined;
    var buf_8: [8]u32 = undefined;
    var buf_9: [9]u32 = undefined;
    var searches: [10]u32 = undefined;
    var search_idxs: [10]usize = undefined;
    var results: [10]ResultItem(usize, u32, .IDX_AND_SEARCH_VAL) = undefined;
    const search = SearchPackage.search_package()
        .with_implicit_data_container([]const u32)
        .with_implicit_search_container(u32)
        .with_implicit_result_container(*ResultItem(usize, u32, .IDX_ONLY))
        .with_equality_mode(.EXACTLY_EQUAL);
    const search_many = SearchPackage.search_package()
        .with_implicit_data_container([]const u32)
        .with_implicit_search_container([]const u32)
        .with_result_include_search_val_mode(.IDX_AND_SEARCH_VAL)
        .with_implicit_result_container([]ResultItem(usize, u32, .IDX_AND_SEARCH_VAL))
        .with_equality_mode(.EXACTLY_EQUAL);
    const empty_always_null_idx = search.linear_search_for_one(.{
        .data = buf_1[0..1],
        .data_start = 0,
        .data_end_exclusive = 0,
        .search_params = 0,
    });
    try Test.expect_equal_src(empty_always_null_idx.was_found, LinearSearchOneFound.NO_DATA_ITEMS, @src(), "", .{});
    const PROTO = struct {
        const FillStage = enum(u8) {
            FIND,
            ADD,
        };
        fn do_single_search_tests(buf: []u32, rand_: std.Random) anyerror!void {
            const N = buf.len;
            for (0..NUM_ITERATIONS) |_| {
                for (0..N) |i| {
                    buf[i] = rand_.int(u32);
                }
                Root.Sort.InsertionSort.insertion_sort_implicit(buf[0..]);
                var should_not_find: u32 = undefined;
                find_another_val_not_in_list: while (true) {
                    should_not_find = rand_.int(u32);
                    for (buf[0..]) |good_val| {
                        if (good_val == should_not_find) continue :find_another_val_not_in_list;
                    }
                    break :find_another_val_not_in_list;
                }
                const should_not_find_idx_linear = search.linear_search_for_one(.{
                    .data = buf[0..],
                    .data_start = 0,
                    .data_end_exclusive = N,
                    .search_params = should_not_find,
                });
                try Test.expect_equal_src(should_not_find_idx_linear.was_found, LinearSearchOneFound.NOT_FOUND, @src(), "", .{});
                const should_not_find_tag = if (should_not_find < buf[0]) BinarySearchOneFound.NOT_FOUND_ORDERED_BEFORE_GIVEN_RANGE else if (should_not_find > buf[N - 1]) BinarySearchOneFound.NOT_FOUND_ORDERED_AFTER_GIVEN_RANGE else BinarySearchOneFound.NOT_FOUND_ORDERED_WITHIN_RANGE;
                const should_not_find_idx_binary = search.binary_search_for_one(.{
                    .data = buf[0..],
                    .data_start = 0,
                    .data_end_exclusive = N,
                    .search_params = should_not_find,
                });
                try Test.expect_equal_src(should_not_find_idx_binary.found, should_not_find_tag, @src(), "", .{});
                for (buf[0..], 0..) |should_find, i| {
                    const should_find_idx_linear = search.linear_search_for_one(.{
                        .data = buf[0..],
                        .data_start = 0,
                        .data_end_exclusive = N,
                        .search_params = should_find,
                    });
                    try Test.expect_equal_src(should_find_idx_linear.was_found, LinearSearchOneFound.FOUND, @src(), "", .{});
                    try Test.expect_equal_src(should_find_idx_linear.location.data_idx, i, @src(), "", .{});
                    const should_find_idx_binary = search.binary_search_for_one(.{
                        .data = buf[0..],
                        .data_start = 0,
                        .data_end_exclusive = N,
                        .search_params = should_find,
                    });
                    try Test.expect_equal_src(should_find_idx_binary.found, BinarySearchOneFound.FOUND, @src(), "", .{});
                    try Test.expect_equal_src(should_find_idx_binary.location.data_idx, i, @src(), "", .{});
                }
            }
        }
        fn do_multi_search_tests(buf: []u32, search_idxs_: []usize, searches_: []u32, results_: []ResultItem(usize, u32, .IDX_AND_SEARCH_VAL), rand_: std.Random) anyerror!void {
            const N = buf.len;
            for (0..NUM_ITERATIONS) |_| {
                var num_filled: usize = 0;
                try_another_unused_number: while (num_filled < N) {
                    const rand_val = rand_.int(u32);
                    for (0..num_filled) |ii| {
                        if (buf[ii] == rand_val) continue :try_another_unused_number;
                    }
                    buf[num_filled] = rand_val;
                    num_filled += 1;
                }
                Root.Sort.InsertionSort.insertion_sort_implicit(buf[0..]);
                var updated_searches = searches_;
                var updated_search_idxs = search_idxs_;
                // var updated_results = results_;
                const num_to_find = rand_.intRangeAtMost(usize, 0, N);
                const num_to_not_find = rand_.intRangeAtMost(usize, 0, N - num_to_find);
                const search_total = num_to_find + num_to_not_find;
                try_another_index_to_find: while (updated_search_idxs.len < num_to_find) {
                    const find_idx = rand_.uintLessThan(usize, buf.len);
                    for (updated_search_idxs[0..]) |already_added_idx_to_find| {
                        if (find_idx == already_added_idx_to_find) continue :try_another_index_to_find;
                    }
                    updated_search_idxs = Utils.Mem.append_assume_capacity(updated_search_idxs, find_idx);
                    updated_searches = Utils.Mem.append_assume_capacity(updated_searches, buf[find_idx]);
                }
                try_another_idx_to_NOT_find: while (updated_searches.len < search_total) {
                    const dont_find_val = rand_.int(u32);
                    for (updated_searches[0..]) |good_val| {
                        if (dont_find_val == good_val) continue :try_another_idx_to_NOT_find;
                    }
                    updated_searches = Utils.Mem.append_assume_capacity(updated_searches, dont_find_val);
                }
                updated_searches = Utils.Mem.scramble(u32, updated_searches, 0, search_total, rand_, 5);
                const linear_results = search_many.linear_search_for_many(.{
                    .data = buf[0..],
                    .data_start = 0,
                    .data_end_exclusive = N,
                    .search_params = updated_searches,
                    .results_buffer = results_,
                });
                try Test.expect_equal_src(linear_results.results_count, num_to_find, @src(), "fail", .{});
                for (linear_results.locations) |location_| {
                    const location: search_many.CurrentResultItem() = location_;
                    const found_val = buf[location.data_idx];
                    try Test.expect_equal_src(found_val, location.search_val, @src(), "fail", .{});
                }
                const binary_results = search_many.binary_search_for_many(.{
                    .data = buf[0..],
                    .data_start = 0,
                    .data_end_exclusive = N,
                    .search_params = updated_searches,
                    .results_buffer = results_,
                });
                try Test.expect_equal_src(binary_results.results_count, num_to_find, @src(), "fail", .{});
                for (binary_results.locations) |location_| {
                    const location: search_many.CurrentResultItem() = location_;
                    const found_val = buf[location.data_idx];
                    try Test.expect_equal_src(found_val, location.search_val, @src(), "fail", .{});
                }
            }
        }
    };
    try PROTO.do_single_search_tests(buf_1[0..], rand);
    try PROTO.do_single_search_tests(buf_8[0..], rand);
    try PROTO.do_single_search_tests(buf_9[0..], rand);
    try PROTO.do_multi_search_tests(buf_1[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
    try PROTO.do_multi_search_tests(buf_8[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
    try PROTO.do_multi_search_tests(buf_9[0..], search_idxs[0..0], searches[0..0], results[0..0], rand);
}
