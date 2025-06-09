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
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const infered_greater_than = Utils.infered_greater_than;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const inline_swap = Root.Utils.inline_swap;
const Iterator = Root.Iterator;
const IterCaps = Iterator.IteratorCapabilities;
// const greater_than = Compare.greater_than;

pub fn insertion_sort(comptime T: type, buffer: []T) void {
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
    assert_with_reason(Utils.can_infer_type_order(TX), @src(), "cannot inherently order type " ++ @typeName(TX), .{});
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
    assert_with_reason(Utils.can_infer_type_order(TX), @src(), "cannot inherently order type " ++ @typeName(TX), .{});
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

pub fn insertion_sort_iterator(comptime T: type, iter: Iterator.Iterator(T), move_data_fn: *const fn (from_item: *const T, to_item: *T, userdata: ?*anyopaque) void, greater_than_fn: *const fn (a: *const T, b: *const T, userdata: ?*anyopaque) bool, userdata: ?*anyopaque) void {
    const caps = iter.capabilities();
    assert_with_reason(caps.has_entire_group_set(IterCaps.Group.DIRECTION), @src(), "iterator must support `FORWARD` and `BACKWARD` capabilities", .{});
    assert_with_reason(caps.isolate_group_as_int_aligned_to_bit_0(IterCaps.Group.SAVE_LOAD) >= 1,  @src(), "iterator must support at least 1 save/load slot (`SAVE_LOAD_1_SLOT`)", .{});
    _ = iter.reset();
    var x: T = undefined;
    var prev_item: ?*T = null;
    _ = iter.skip_next();
    var this_item: ?*T = iter.peek_next_or_null();
    if (this_item == null) return;
    while (this_item != null) {
        assert_with_reason(iter.save_state(0), @src(), "iterator save state to slot `0` failed", .{});
        move_data_fn(this_item.?, &x, userdata);
        prev_item = iter.get_prev_or_null();
        inner: while (prev_item != null) {
            if (greater_than_fn(prev_item.?, &x, userdata)) {
                move_data_fn(prev_item.?, this_item.?, userdata);
                this_item = prev_item;
                prev_item = iter.get_prev_or_null();
            } else break :inner;
        }
        move_data_fn(&x, this_item.?, userdata);
        assert_with_reason(iter.load_state(0), @src(), "iterator load state from slot `0` failed", .{});
        _ = iter.skip_next();
        this_item = iter.peek_next_or_null();
    }
    // while (i < buffer.len) {
    //     x = buffer[i];
    //     j = i;
    //     inner: while (j > 0) {
    //         jj = j - 1;
    //         if (infered_greater_than(buffer[jj], x)) {
    //             buffer[j] = buffer[jj];
    //             j -= 1;
    //         } else {
    //             break :inner;
    //         }
    //     }
    //     buffer[j] = x;
    //     i += 1;
    // }
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
