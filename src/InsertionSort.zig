const std = @import("std");
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;
const inline_swap = Root.Utils.inline_swap;
const greater_than = Compare.greater_than;

pub inline fn insertion_sort(comptime T: type, buffer: []T) void {
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

pub inline fn insertion_sort_with_transform(comptime T: type, buffer: []T, comptime TX: type, transform_fn: *const fn (in: T, data: ?*const anyopaque) TX, data: ?*const anyopaque) void {
    var i: usize = 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var jj_xx: TX = undefined;
    var x: T = undefined;
    var xx: TX = undefined;
    while (i < buffer.len) {
        x = buffer[i];
        xx = transform_fn(x, data);
        j = i;
        inner: while (j > 0) {
            jj = j - 1;
            jj_xx = transform_fn(buffer[jj], data);
            if (greater_than(jj_xx, xx)) {
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
    const secret: u8 = 42;
    const proto = struct {
        fn xfrm(a: u8, data: ?*const anyopaque) u8_u8 {
            const secret_ptr: *const u8 = @ptrCast(@alignCast(data));
            return u8_u8{ a, secret_ptr.* };
        }
    };

    for (cases) |case| {
        var output: [10]u8 = case.input;
        insertion_sort(u8, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        insertion_sort_with_transform(u8, output[0..case.len], u8_u8, proto.xfrm, &secret);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
