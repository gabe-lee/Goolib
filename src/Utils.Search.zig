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
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
const CompareFuncUserdata = Utils.Compare.CompareFuncUserdata;
const CompareFunc = Utils.Compare.CompareFunc;

pub const LinearSearchOrder = enum {
    SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER,
    SEARCH_PARAMS_UNORDERED,
};

pub fn GetFunc(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE) ELEM_TYPE;
}
pub fn SetFunc(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, val: ELEM_TYPE) void;
}

pub const SearchPackage = struct {
    DATA_CONTAINER: type = undefined,
    DATA_CONTAINER_ELEM: type = undefined,
    DATA_CONTAINER_IDX_TYPE: type = undefined,
    SEARCH_PARAM_CONTAINER: type = undefined,
    SEARCH_PARAM_CONTAINER_ELEM: type = undefined,
    SEARCH_PARAM_CONTAINER_IDX_TYPE: type = undefined,
    RESULT_CONTAINER: type = undefined,
    RESULT_CONTAINER_IDX_TYPE: type = undefined,
    RESULT_CONTAINER_ELEM_TYPE: type = undefined,
    HAS_USERDATA_TYPE: bool = false,
    USERDATA_TYPE: type = void,
    CUSTOM_MATCH: ?*const anyopaque = null,
    CUSTOM_DATA_GET: ?*const anyopaque = null,
    CUSTOM_DATA_SET: ?*const anyopaque = null,
    CUSTOM_SEARCH_GET: ?*const anyopaque = null,
    CUSTOM_GREATER_THAN: ?*const anyopaque = null,
    CUSTOM_LESS_THAN: ?*const anyopaque = null,
    CUSTOM_RESULT_SET: ?*const anyopaque = null,

    pub fn SearchOneInputs(comptime self: SearchPackage) type {
        return struct {
            data: self.DATA_CONTAINER,
            data_start: self.DATA_CONTAINER_IDX_TYPE = 0,
            data_end_exclusive: self.DATA_CONTAINER_IDX_TYPE,
            search_params: self.SEARCH_PARAM_CONTAINER,
            search_idx: self.SEARCH_PARAM_CONTAINER_IDX_TYPE = 0,
            userdata: self.USERDATA_TYPE = undefined,
        };
    }
    pub fn SearchManyInputs(comptime self: SearchPackage) type {
        return struct {
            data: self.DATA_CONTAINER,
            data_start: self.DATA_CONTAINER_IDX_TYPE = 0,
            data_end_exclusive: self.DATA_CONTAINER_IDX_TYPE,
            search_params: self.SEARCH_PARAM_CONTAINER,
            search_start: self.SEARCH_PARAM_CONTAINER_IDX_TYPE = 0,
            search_end_exclusive: self.SEARCH_PARAM_CONTAINER_IDX_TYPE,
            results: self.RESULT_CONTAINER,
            results_start: self.RESULT_CONTAINER_IDX_TYPE = 0,
            results_end_exclusive: self.RESULT_CONTAINER_IDX_TYPE,
            search_order: LinearSearchOrder = .SEARCH_PARAMS_UNORDERED,
            userdata: self.USERDATA_TYPE = if (self.USERDATA_TYPE == void) void{} else undefined,
        };
    }

    pub fn search_for_one(comptime self: SearchPackage, inputs: self.SearchOneInputs()) ?self.RESULT_CONTAINER_IDX_TYPE {
        const DATA_IDX = self.DATA_CONTAINER_IDX_TYPE;
        if (inputs.data_start >= inputs.data_end_exclusive) return 0;
        var data_idx: DATA_IDX = inputs.data_start;
        const search_item = self.get_search_param(inputs.search_params, inputs.search_idx);
        while (data_idx < inputs.data_end_exclusive) : (data_idx += 1) {
            const data_item = self.get_item(inputs.data, data_idx);
            if (self.match_item(inputs.userdata, data_item, search_item)) {
                return @intCast(data_idx);
            }
        }
        return null;
    }

    pub fn search_for_many(comptime self: SearchPackage, inputs: self.SearchManyInputs()) ?self.RESULT_CONTAINER_IDX_TYPE {
        const DATA_IDX = self.DATA_CONTAINER_IDX_TYPE;
        const SEARCH_IDX = self.SEARCH_PARAM_CONTAINER_IDX_TYPE;
        const RESULT_IDX = self.RESULT_CONTAINER_IDX_TYPE;
        if (inputs.search_start >= inputs.search_end_exclusive or inputs.data_start >= inputs.data_end_exclusive) return 0;
        var search_idx: SEARCH_IDX = inputs.search_start;
        var result_idx: RESULT_IDX = inputs.results_start;
        var data_idx: DATA_IDX = undefined;
        var min_data_idx: DATA_IDX = inputs.data_start;
        var search_item: self.SEARCH_PARAM_CONTAINER_ELEM = undefined;
        next_item_to_find: while (search_idx < inputs.search_end_exclusive) : (search_idx += 1) {
            search_item = self.get_search_param(inputs.search_params, search_idx);
            data_idx = @intCast(min_data_idx);
            while (data_idx < inputs.data_end_exclusive) : (data_idx += 1) {
                const data_item = self.get_item(inputs.data, data_idx);
                if (self.match_item(inputs.userdata, data_item, search_item)) {
                    assert_with_reason(result_idx < inputs.results_end_exclusive, @src(), "ran out of space in result container. with `results_start` == {d}, need `results_end_exclusive` >= {d}, got `results_end_exclusive` == {d}", .{ inputs.results_start, result_idx + 1, inputs.results_end_exclusive });
                    self.set_result(inputs.results, result_idx, @intCast(data_idx));
                    result_idx += 1;
                    if (inputs.search_order == .SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER) {
                        min_data_idx = data_idx;
                    }
                    continue :next_item_to_find;
                }
            }
        }
        return result_idx;
    }

    const ContainerSettings = struct {
        CONTAINER_TYPE: type,
        IDX_TYPE: type,
        ELEM_TYPE: type,

        pub fn Getter(comptime self: @This()) type {
            return GetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX_TYPE, self.DATA_CONTAINER_ELEM);
        }
        pub fn Setter(comptime self: @This()) type {
            return SetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX_TYPE, self.DATA_CONTAINER_ELEM);
        }

        pub fn GetterSetter(comptime self: @This()) type {
            return struct {
                getter: ?*const self.Getter() = null,
                setter: ?*const self.Setter() = null,
            };
        }
    };

    pub fn CompareFuncs(comptime self: SearchPackage) type {
        return struct {
            match: ?*const self.Matcher() = null,
            greater: ?*const self.Greater() = null,
            lesser: ?*const self.Lesser() = null,
        };
    }

    pub fn search_package() SearchPackage {
        return SearchPackage{};
    }

    pub fn with_implicit_data_container(comptime self: SearchPackage, comptime DATA_CONTAINER: type) SearchPackage {
        comptime var new_self = self;
        new_self.DATA_CONTAINER = DATA_CONTAINER;
        new_self.DATA_CONTAINER_IDX_TYPE = usize;
        new_self.DATA_CONTAINER_ELEM = Types.IndexableChild(DATA_CONTAINER);
        new_self.CUSTOM_DATA_GET = null;
        new_self.CUSTOM_DATA_SET = null;
        return new_self;
    }

    pub fn with_custom_data_container(comptime self: SearchPackage, comptime SETTINGS: ContainerSettings, comptime GET_SET: SETTINGS.GetterSetter()) SearchPackage {
        comptime var new_self = self;
        new_self.DATA_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.DATA_CONTAINER_IDX_TYPE = SETTINGS.IDX_TYPE;
        new_self.DATA_CONTAINER_ELEM = SETTINGS.ELEM_TYPE;
        new_self.CUSTOM_DATA_GET = @ptrCast(GET_SET.getter);
        new_self.CUSTOM_DATA_SET = @ptrCast(GET_SET.setter);
        return new_self;
    }

    pub fn with_implicit_search_container(comptime self: SearchPackage, comptime SEARCH_CONTAINER: type) SearchPackage {
        comptime var new_self = self;
        new_self.SEARCH_PARAM_CONTAINER = SEARCH_CONTAINER;
        new_self.SEARCH_PARAM_CONTAINER_IDX_TYPE = usize;
        new_self.SEARCH_PARAM_CONTAINER_ELEM = Types.IndexableChild(SEARCH_CONTAINER);
        new_self.CUSTOM_SEARCH_GET = null;
        return new_self;
    }

    pub fn with_custom_search_container(comptime self: SearchPackage, comptime SETTINGS: ContainerSettings, comptime GET: ?*const SETTINGS.Getter()) SearchPackage {
        comptime var new_self = self;
        new_self.SEARCH_PARAM_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.SEARCH_PARAM_CONTAINER_IDX_TYPE = SETTINGS.IDX_TYPE;
        new_self.SEARCH_PARAM_CONTAINER_ELEM = SETTINGS.ELEM_TYPE;
        new_self.CUSTOM_SEARCH_GET = @ptrCast(GET);
        return new_self;
    }
    pub fn with_implicit_result_container(comptime self: SearchPackage, comptime RESULT_CONTAINER: type) SearchPackage {
        comptime var new_self = self;
        new_self.RESULT_CONTAINER = RESULT_CONTAINER;
        new_self.RESULT_CONTAINER_IDX_TYPE = usize;
        new_self.RESULT_CONTAINER_ELEM_TYPE = self.DATA_CONTAINER_IDX_TYPE;
        new_self.CUSTOM_RESULT_SET = null;
        return new_self;
    }

    pub fn with_custom_result_container(comptime self: SearchPackage, comptime SETTINGS: ContainerSettings, comptime SET: ?*const SETTINGS.Setter()) SearchPackage {
        comptime var new_self = self;
        new_self.RESULT_CONTAINER = SETTINGS.CONTAINER_TYPE;
        new_self.RESULT_CONTAINER_IDX_TYPE = SETTINGS.IDX_TYPE;
        new_self.RESULT_CONTAINER_ELEM_TYPE = self.DATA_CONTAINER_IDX_TYPE;
        new_self.CUSTOM_RESULT_SET = @ptrCast(SET);
        return new_self;
    }

    pub fn with_userdata_type(comptime self: SearchPackage, comptime USERDATA: type) SearchPackage {
        comptime var new_self = self;
        new_self.USERDATA_TYPE = USERDATA;
        new_self.HAS_USERDATA_TYPE = true;
        return new_self;
    }

    pub fn with_match_fn(comptime self: SearchPackage, comptime MATCHER: *const self.Matcher()) SearchPackage {
        comptime var new_self = self;
        new_self.CUSTOM_MATCH = @ptrCast(MATCHER);
        return new_self;
    }
    pub fn with_search_item_greater_than_fn(comptime self: SearchPackage, comptime GREATER: *const self.Greater()) SearchPackage {
        comptime var new_self = self;
        new_self.CUSTOM_GREATER_THAN = @ptrCast(GREATER);
        return new_self;
    }
    pub fn with_search_item_less_than_fn(comptime self: SearchPackage, comptime LESSER: *const self.Lesser()) SearchPackage {
        comptime var new_self = self;
        new_self.CUSTOM_LESS_THAN = @ptrCast(LESSER);
        return new_self;
    }

    pub fn get_item(comptime self: SearchPackage, data: self.DATA_CONTAINER, idx: self.DATA_CONTAINER_IDX_TYPE) self.DATA_CONTAINER_ELEM {
        if (self.CUSTOM_DATA_GET) |get_opaque| {
            const get: *const self.DataGetter() = @ptrCast(@alignCast(get_opaque));
            return get(data, idx);
        } else {
            if (Types.is_indexable(self.DATA_CONTAINER)) {
                return data[idx];
            } else if (Types.type_is_single_item_pointer(self.DATA_CONTAINER)) {
                assert_with_reason(idx == 0, @src(), "can only get single-item pointer at index 0", .{});
                return data.*;
            } else {
                assert_with_reason(idx == 0, @src(), "can only get single-item value at index 0", .{});
                return data;
            }
        }
    }
    pub fn set_item(comptime self: SearchPackage, data: self.DATA_CONTAINER, idx: self.DATA_CONTAINER_IDX_TYPE, val: self.DATA_CONTAINER_ELEM) void {
        if (self.CUSTOM_DATA_SET) |set_opaque| {
            const set: *const self.DataSetter() = @ptrCast(@alignCast(set_opaque));
            set(data, idx, val);
        } else {
            if (Types.is_indexable(self.DATA_CONTAINER)) {
                data[idx] = val;
            } else {
                assert_with_reason(idx == 0, @src(), "can only set single-item pointer at index 0", .{});
                data.* = val;
            }
        }
    }
    pub fn get_search_param(comptime self: SearchPackage, search: self.SEARCH_PARAM_CONTAINER, idx: self.SEARCH_PARAM_CONTAINER_IDX_TYPE) self.SEARCH_PARAM_CONTAINER_ELEM {
        if (self.CUSTOM_SEARCH_GET) |get_opaque| {
            const get: *const self.SearchGetter() = @ptrCast(@alignCast(get_opaque));
            return get(search, idx);
        } else {
            if (Types.is_indexable(self.SEARCH_PARAM_CONTAINER)) {
                return search[idx];
            } else if (Types.type_is_single_item_pointer(self.SEARCH_PARAM_CONTAINER)) {
                assert_with_reason(idx == 0, @src(), "can only get single-item pointer at index 0", .{});
                return search.*;
            } else {
                assert_with_reason(idx == 0, @src(), "can only get single-item value at index 0", .{});
                return search;
            }
        }
    }
    pub fn set_result(comptime self: SearchPackage, output: self.RESULT_CONTAINER, idx: self.RESULT_CONTAINER_IDX_TYPE, val: self.RESULT_CONTAINER_ELEM_TYPE) void {
        if (self.CUSTOM_RESULT_SET) |set_opaque| {
            const set: *const self.ResultSetter() = @ptrCast(@alignCast(set_opaque));
            set(output, idx, val);
        } else {
            if (Types.is_indexable(self.RESULT_CONTAINER)) {
                output[idx] = val;
            } else {
                assert_with_reason(idx == 0, @src(), "con only set single-item pointer at index 0", .{});
                output.* = val;
            }
        }
    }
    pub fn match_item(comptime self: SearchPackage, userdata: self.USERDATA_TYPE, data_item: self.DATA_CONTAINER_ELEM, search_item: self.SEARCH_PARAM_CONTAINER_ELEM) bool {
        if (self.CUSTOM_MATCH) |match_opaque| {
            const match: *const self.Matcher() = @ptrCast(@alignCast(match_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return match(search_item, data_item, userdata);
            } else {
                return match(search_item, data_item);
            }
        } else {
            return Utils.shallow_equal(search_item, data_item);
        }
    }
    pub fn search_item_greater_than(comptime self: SearchPackage, userdata: self.USERDATA_TYPE, data_item: self.DATA_CONTAINER_ELEM, search_item: self.SEARCH_PARAM_CONTAINER_ELEM) bool {
        if (self.CUSTOM_GREATER_THAN) |gt_opaque| {
            const greater: *const self.Greater() = @ptrCast(@alignCast(gt_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return greater(search_item, data_item, userdata);
            } else {
                return greater(search_item, data_item);
            }
        } else {
            return Utils.Compare.greater_than(search_item, data_item);
        }
    }
    pub fn search_item_less_than(comptime self: SearchPackage, userdata: self.USERDATA_TYPE, data_item: self.DATA_CONTAINER_ELEM, search_item: self.SEARCH_PARAM_CONTAINER_ELEM) bool {
        if (self.CUSTOM_LESS_THAN) |lt_opaque| {
            const less: *const self.Lesser() = @ptrCast(@alignCast(lt_opaque));
            if (self.HAS_USERDATA_TYPE) {
                return less(search_item, data_item, userdata);
            } else {
                return less(search_item, data_item);
            }
        } else {
            return Utils.Compare.less_than(search_item, data_item);
        }
    }

    pub fn DataGetter(comptime self: SearchPackage) type {
        return GetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX_TYPE, self.DATA_CONTAINER_ELEM);
    }
    pub fn DataSetter(comptime self: SearchPackage) type {
        return SetFunc(self.DATA_CONTAINER, self.DATA_CONTAINER_IDX_TYPE, self.DATA_CONTAINER_ELEM);
    }
    pub fn ResultSetter(comptime self: SearchPackage) type {
        return SetFunc(self.RESULT_CONTAINER, self.RESULT_CONTAINER_IDX_TYPE, self.RESULT_CONTAINER_ELEM_TYPE);
    }
    pub fn SearchGetter(comptime self: SearchPackage) type {
        return GetFunc(self.SEARCH_PARAM_CONTAINER, self.SEARCH_PARAM_CONTAINER_IDX_TYPE, self.SEARCH_PARAM_CONTAINER_ELEM);
    }
    pub fn Matcher(comptime self: SearchPackage) type {
        if (self.HAS_USERDATA_TYPE) {
            return CompareFuncUserdata(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM, self.USERDATA_TYPE);
        } else {
            return CompareFunc(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM);
        }
    }
    pub fn Greater(comptime self: SearchPackage) type {
        if (self.HAS_USERDATA_TYPE) {
            return CompareFuncUserdata(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM, self.USERDATA_TYPE);
        } else {
            return CompareFunc(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM);
        }
    }
    pub fn Lesser(comptime self: SearchPackage) type {
        if (self.HAS_USERDATA_TYPE) {
            return CompareFuncUserdata(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM, self.USERDATA_TYPE);
        } else {
            return CompareFunc(self.SEARCH_PARAM_CONTAINER_ELEM, self.DATA_CONTAINER_ELEM);
        }
    }
};

// test "Utils.Mem search for one item funcs" {
//     var rand_core = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
//     const rand = rand_core.random();
//     const NUM_ITERATIONS = 5;
//     var buf_1: [1]u32 = undefined;
//     var buf_8: [8]u32 = undefined;
//     var buf_9: [9]u32 = undefined;
//     const search = SearchPackage.search_package()
//         .with_implicit_data_container([]const u32)
//         .with_implicit_search_container(u32)
//         .with_implicit_result_container(*usize);
//     const empty_always_null_idx = search.search_for_one(.{
//         .data = buf_1[0..1],
//         .data_start = 0,
//         .data_end_exclusive = 0,
//         .search_params = 0,
//     });
//     try Test.expect_null(empty_always_null_idx, "empty_always_null_idx", "fail", .{});
//     const PROTO = struct {
//         fn do_search_tests(buf: []u8) anyerror!void {
//             const N = buf.len;
//             for (0..NUM_ITERATIONS) |_| {
//                 for (0..N) |i| {
//                     buf[i] = rand.int(u32);
//                 }
//                 Root.Sort.InsertionSort.insertion_sort_implicit(buf[0..]);
//                 var should_not_find: u32 = undefined;
//                 find_another_val_not_in_list: while (true) {
//                     should_not_find = rand.int(u32);
//                     for (buf[0..]) |good_val| {
//                         if (good_val == should_not_find) continue :find_another_val_not_in_list;
//                     }
//                     break :find_another_val_not_in_list;
//                 }
//                 const should_not_find_idx_linear = search.search_for_one(.{
//                     .data = buf[0..],
//                     .data_start = 0,
//                     .data_end_exclusive = N,
//                     .search_params = should_not_find,
//                 });
//                 try Test.expect_null(should_not_find_idx_linear, "should_not_find_idx_linear", "fail", .{});
//                 const should_not_find_tag = if (should_not_find < buf[0]) BinarySearchResultKind.NOT_FOUND_BELOW_MIN else if (should_not_find > buf[N - 1]) BinarySearchResultKind.NOT_FOUND_ABOVE_MAX else BinarySearchResultKind.NOT_FOUND_WITHIN_RANGE;
//                 const should_not_find_idx_binary = binary_search_implicit(buf[0..], 0, N, should_not_find, usize);
//                 try Test.expect_equal(should_not_find_idx_binary.result, "should_not_find_idx_binary.result", should_not_find_tag, @tagName(should_not_find_tag), "fail", .{});
//                 for (buf[0..], 0..) |should_find, i| {
//                     const should_find_idx_linear = search_implicit(buf[0..], 0, N, should_find, usize);
//                     try Test.expect_not_null(should_find_idx_linear, "should_find_idx_linear", "fail", .{});
//                     try Test.expect_equal(should_find_idx_linear.?, "should_find_idx_linear.?", i, "i", "fail", .{});
//                     const should_find_idx_binary = binary_search_implicit(buf[0..], 0, N, should_find, usize);
//                     try Test.expect_equal(should_find_idx_binary.result, "should_find_idx_binary.result", BinarySearchResultKind.FOUND, ".FOUND", "fail", .{});
//                     try Test.expect_equal(should_find_idx_binary.idx, "should_find_idx_binary.idx", i, "i", "fail", .{});
//                 }
//             }
//         }
//     };
//     try PROTO.do_search_tests(buf_1[0..]);
//     try PROTO.do_search_tests(buf_8[0..]);
//     try PROTO.do_search_tests(buf_9[0..]);
// }
