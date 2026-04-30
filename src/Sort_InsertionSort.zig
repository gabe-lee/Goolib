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
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const Types = Root.Types;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const inline_swap = Root.Utils.inline_swap;
const Iterator = Root.Iterator;
// const greater_than = Compare.greater_than;

pub fn insertion_sort_implicit(buffer: anytype) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    assert_with_reason(Utils.can_infer_type_order(T), @src(), "cannot inherently order type " ++ @typeName(T), .{});
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (buffer[jj] > x) {
                buffer[j] = buffer[jj];
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        i += 1;
    }
}

/// Sorts using the primary buffer and matches element movement operations on all matching buffers
///
/// `matching_buffers` MUST be a tuple struct type with every field type either a slice, many-item-pointer, array, or vector type
pub fn insertion_sort_implicit_with_matching_buffers(buffer: anytype, matching_buffers: anytype) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    assert_with_reason(Utils.can_infer_type_order(T), @src(), "cannot inherently order type " ++ @typeName(T), .{});
    inline for (@typeInfo(matching_buffers).@"struct".fields) |matching_field| {
        _ = Types.IndexableChild(matching_field.type);
    }
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    const MATCHING = @TypeOf(matching_buffers);
    const matching_temps: Types.make_temp_value_struct_from_struct_type(MATCHING) = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        inline for (matching_buffers, matching_temps) |buf, *matching_temp| {
            matching_temp.* = buf[i];
        }
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (buffer[jj] > x) {
                buffer[j] = buffer[jj];
                inline for (matching_buffers) |buf| {
                    buf[j] = buf[jj];
                }
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        inline for (matching_buffers, matching_temps) |buf, matching_temp| {
            buf[j] = matching_temp;
        }
        i += 1;
    }
}

pub fn insertion_sort_with_func(buffer: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer))) bool) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (greater_than(buffer[jj], x)) {
                buffer[j] = buffer[jj];
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        i += 1;
    }
}

pub fn insertion_sort_with_func_and_matching_buffers(buffer: anytype, matching_buffers: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer))) bool) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    inline for (@typeInfo(matching_buffers).@"struct".fields) |matching_field| {
        _ = Types.IndexableChild(matching_field.type);
    }
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    const MATCHING = @TypeOf(matching_buffers);
    const matching_temps: Types.make_temp_value_struct_from_struct_type(MATCHING) = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        inline for (matching_buffers, matching_temps) |buf, *matching_temp| {
            matching_temp.* = buf[i];
        }
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (greater_than(buffer[jj], x)) {
                buffer[j] = buffer[jj];
                inline for (matching_buffers) |buf| {
                    buf[j] = buf[jj];
                }
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        inline for (matching_buffers, matching_temps) |buf, matching_temp| {
            buf[j] = matching_temp;
        }
        i += 1;
    }
}

pub fn insertion_sort_with_func_and_userdata(buffer: anytype, userdata: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer)), userdata: @TypeOf(userdata)) bool) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (greater_than(buffer[jj], x, userdata)) {
                buffer[j] = buffer[jj];
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        i += 1;
    }
}

pub fn insertion_sort_with_func_userdata_and_matching_buffers(buffer: anytype, matching_buffers: anytype, userdata: anytype, greater_than: *const fn (a: Types.IndexableChild(@TypeOf(buffer)), b: Types.IndexableChild(@TypeOf(buffer)), userdata: @TypeOf(userdata)) bool) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    inline for (@typeInfo(matching_buffers).@"struct".fields) |matching_field| {
        _ = Types.IndexableChild(matching_field.type);
    }
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    const MATCHING = @TypeOf(matching_buffers);
    const matching_temps: Types.make_temp_value_struct_from_struct_type(MATCHING) = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        inline for (matching_buffers, matching_temps) |buf, *matching_temp| {
            matching_temp.* = buf[i];
        }
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (greater_than(buffer[jj], x, userdata)) {
                buffer[j] = buffer[jj];
                inline for (matching_buffers) |buf| {
                    buf[j] = buf[jj];
                }
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        inline for (matching_buffers, matching_temps) |buf, matching_temp| {
            buf[j] = matching_temp;
        }
        i += 1;
    }
}

pub fn insertion_sort_with_transform_to_implicit(buffer: anytype, comptime TRANSFORMED_TYPE: type, transform_fn: *const fn (in: Types.IndexableChild(@TypeOf(buffer))) TRANSFORMED_TYPE) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    assert_with_reason(Utils.can_infer_type_order(TRANSFORMED_TYPE), @src(), "cannot inherently order type " ++ @typeName(TRANSFORMED_TYPE), .{});
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TRANSFORMED_TYPE = undefined;
    var x: T = undefined;
    var xx: TRANSFORMED_TYPE = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        xx = transform_fn(x);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj]);
            if (jj_xx > xx) {
                buffer[j] = buffer[jj];
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        i += 1;
    }
}

pub fn insertion_sort_with_transform_to_implicit_and_matching_buffers(buffer: anytype, matching_buffers: anytype, comptime TRANSFORMED_TYPE: type, transform_fn: *const fn (in: Types.IndexableChild(@TypeOf(buffer))) TRANSFORMED_TYPE) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    inline for (@typeInfo(matching_buffers).@"struct".fields) |matching_field| {
        _ = Types.IndexableChild(matching_field.type);
    }
    assert_with_reason(Utils.can_infer_type_order(TRANSFORMED_TYPE), @src(), "cannot inherently order type " ++ @typeName(TRANSFORMED_TYPE), .{});
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TRANSFORMED_TYPE = undefined;
    var x: T = undefined;
    var xx: TRANSFORMED_TYPE = undefined;
    const MATCHING = @TypeOf(matching_buffers);
    const matching_temps: Types.make_temp_value_struct_from_struct_type(MATCHING) = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        inline for (matching_buffers, matching_temps) |buf, *matching_temp| {
            matching_temp.* = buf[i];
        }
        xx = transform_fn(x);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj]);
            if (jj_xx > xx) {
                buffer[j] = buffer[jj];
                inline for (matching_buffers) |buf| {
                    buf[j] = buf[jj];
                }
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        inline for (matching_buffers, matching_temps) |buf, matching_temp| {
            buf[j] = matching_temp;
        }
        i += 1;
    }
}

pub fn insertion_sort_with_transform_to_implicit_and_userdata(buffer: anytype, userdata: anytype, comptime TRANSFORMED_TYPE: type, transform_fn: *const fn (in: Types.IndexableChild(@TypeOf(buffer)), userdata: @TypeOf(userdata)) TRANSFORMED_TYPE) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    assert_with_reason(Utils.can_infer_type_order(TRANSFORMED_TYPE), @src(), "cannot inherently order type " ++ @typeName(TRANSFORMED_TYPE), .{});
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TRANSFORMED_TYPE = undefined;
    var x: T = undefined;
    var xx: TRANSFORMED_TYPE = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        xx = transform_fn(x, userdata);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj], userdata);
            if (jj_xx > xx) {
                buffer[j] = buffer[jj];
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        i += 1;
    }
}

pub fn insertion_sort_with_transform_to_implicit_matching_buffers_and_userdata(buffer: anytype, matching_buffers: anytype, userdata: anytype, comptime TRANSFORMED_TYPE: type, transform_fn: *const fn (in: Types.IndexableChild(@TypeOf(buffer)), userdata: @TypeOf(userdata)) TRANSFORMED_TYPE) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Types.assert_has_len(BUF);
    inline for (@typeInfo(matching_buffers).@"struct".fields) |matching_field| {
        _ = Types.IndexableChild(matching_field.type);
    }
    assert_with_reason(Utils.can_infer_type_order(TRANSFORMED_TYPE), @src(), "cannot inherently order type " ++ @typeName(TRANSFORMED_TYPE), .{});
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TRANSFORMED_TYPE = undefined;
    var x: T = undefined;
    var xx: TRANSFORMED_TYPE = undefined;
    const MATCHING = @TypeOf(matching_buffers);
    const matching_temps: Types.make_temp_value_struct_from_struct_type(MATCHING) = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        inline for (matching_buffers, matching_temps) |buf, *matching_temp| {
            matching_temp.* = buf[i];
        }
        xx = transform_fn(x, userdata);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj], userdata);
            if (jj_xx > xx) {
                buffer[j] = buffer[jj];
                inline for (matching_buffers) |buf| {
                    buf[j] = buf[jj];
                }
                j -= 1;
            } else {
                break :inner;
            }
        }
        buffer[j] = x;
        inline for (matching_buffers, matching_temps) |buf, matching_temp| {
            buf[j] = matching_temp;
        }
        i += 1;
    }
}

test "InsertionSort.zig" {
    const t = std.testing;
    const TestCase = struct {
        input: [10]u8,
        expected_output: [10]u8,
        len: usize,
    };
    const cases = [_]TestCase{
        TestCase{
            .input = .{ 42, 1, 33, 99, 5, 10, 11, 0, 0, 0 },
            .expected_output = .{ 1, 5, 10, 11, 33, 42, 99, 0, 0, 0 },
            .len = 7,
        },
        TestCase{
            .input = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_output = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .len = 0,
        },
        TestCase{
            .input = .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .expected_output = .{ 1, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
            .len = 1,
        },
        TestCase{
            .input = .{ 'H', 'e', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd' },
            .expected_output = .{ ' ', 'H', 'W', 'd', 'e', 'l', 'l', 'o', 'o', 'r' },
            .len = 10,
        },
        TestCase{
            .input = .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            .expected_output = .{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            .len = 10,
        },
    };
    const u8_u8 = [2]u8;
    var secret: u8 = 42;

    const proto = struct {
        fn xfrm_user(a: u8, data: ?*const anyopaque) u16 {
            const secret_ptr: *const u8 = @ptrCast(@alignCast(data));
            return @bitCast(u8_u8{ a, secret_ptr.* });
        }

        fn xfrm(a: u8) u16 {
            return @bitCast(u8_u8{ a, 42 });
        }
    };

    for (cases) |case| {
        var output: [10]u8 = case.input;
        insertion_sort_implicit(u8, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        insertion_sort_with_transform_to_implicit(u8, output[0..case.len], u16, proto.xfrm);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        insertion_sort_with_transform_to_implicit_and_userdata(u8, output[0..case.len], u16, proto.xfrm_user, &secret);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
