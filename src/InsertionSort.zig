//! //TODO Documentation
//! #### License: Zlib

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
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const LOG_PREFIX = Root.LOG_PREFIX;
const Utils = Root.Utils;
const assert_with_reason = Utils.assert_with_reason;
const comptime_assert_with_reason = Utils.comptime_assert_with_reason;
const infered_greater_than = Utils.infered_greater_than;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;
const inline_swap = Root.Utils.inline_swap;
// const greater_than = Compare.greater_than;

pub fn insertion_sort(comptime T: type, buffer: []T) void {
    comptime_assert_with_reason(Utils.can_infer_type_order(T), "cannot inherently order type " ++ @typeName(T));
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var x: T = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            if (infered_greater_than(buffer[jj], x)) {
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

pub inline fn insertion_sort_with_transform_and_user_data(comptime T: type, buffer: []T, comptime TX: type, transform_fn: *const fn (in: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) void {
    comptime_assert_with_reason(Utils.can_infer_type_order(TX), "cannot inherently order type " ++ @typeName(TX));
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TX = undefined;
    var x: T = undefined;
    var xx: TX = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        xx = transform_fn(x, user_data);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj], user_data);
            if (infered_greater_than(jj_xx, xx)) {
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

pub inline fn insertion_sort_with_transform(comptime T: type, buffer: []T, comptime TX: type, transform_fn: *const fn (in: T) TX) void {
    comptime_assert_with_reason(Utils.can_infer_type_order(TX), "cannot inherently order type " ++ @typeName(TX));
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TX = undefined;
    var x: T = undefined;
    var xx: TX = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        xx = transform_fn(x);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj]);
            if (infered_greater_than(jj_xx, xx)) {
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
        insertion_sort(u8, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        insertion_sort_with_transform(u8, output[0..case.len], u16, proto.xfrm);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        insertion_sort_with_transform_and_user_data(u8, output[0..case.len], u16, proto.xfrm_user, &secret);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
