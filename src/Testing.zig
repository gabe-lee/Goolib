const std = @import("std");
const build = @import("builtin");
const testing = std.testing;

const Root = @import("./_root.zig");
const Utils = Root.Utils;

pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (@inComptime()) {
        @compileError(std.fmt.comptimePrint(fmt, args));
    } else if (testing.backend_can_print) {
        std.debug.print(fmt, args);
    }
}

pub const TestError = error{
    test_expected_true,
    test_expected_false,
    test_expected_equal,
    test_expected_not_equal,
    test_expected_greater_than,
    test_expected_less_than,
    test_expected_greater_than_or_equal,
    test_expected_less_than_or_equal,
    test_expected_slices_equal,
    test_expected_deep_equal,
    test_expected_shallow_equal,
};

pub fn expect_true(condition: bool, comptime condition_str: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (!condition) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} == true\n\tACTUAL: {s} == false\n", .{ condition_str, condition_str });
        return TestError.test_expected_true;
    }
}

pub fn expect_false(condition: bool, condition_str: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (condition) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} == false\n\tACTUAL: {s} == true\n", .{ condition_str, condition_str });
        return TestError.test_expected_false;
    }
}

pub fn expect_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a != val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} == {s}\n\tEXPECT: {any} == {any}\n\tACTUAL: {any} != {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_equal;
    }
}

pub fn expect_not_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a == val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} != {s}\n\tEXPECT: {any} != {any}\n\tACTUAL: {any} == {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_not_equal;
    }
}

pub fn expect_greater_than(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a <= val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} > {s}\n\tEXPECT: {any} > {any}\n\tACTUAL: {any} <= {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_greater_than;
    }
}

pub fn expect_greater_than_or_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a < val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} >= {s}\n\tEXPECT: {any} >= {any}\n\tACTUAL: {any} < {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_greater_than_or_equal;
    }
}

pub fn expect_less_than(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a >= val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} < {s}\n\tEXPECT: {any} < {any}\n\tACTUAL: {any} >= {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_less_than;
    }
}

pub fn expect_less_than_or_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (val_a > val_b) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} <= {s}\n\tEXPECT: {any} <= {any}\n\tACTUAL: {any} > {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_less_than_or_equal;
    }
}

pub fn expect_slices_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (!std.mem.eql(@typeInfo(@TypeOf(val_a)).pointer.child, val_a, val_b)) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} == {s}\n\tSLICE A: {any}\n\tSLICE B: {any}\n", .{ str_a, str_b, val_a, val_b });
        return TestError.test_expected_slices_equal;
    }
}

pub fn expect_deep_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (!Utils.deep_equal(val_a, val_b)) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} deep_equals {s}\n\tEXPECT: {any} deep_equals {any}\n\tACTUAL: {any} !deep_equals {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_deep_equal;
    }
}

pub fn expect_shallow_equal(val_a: anytype, str_a: []const u8, val_b: anytype, str_b: []const u8, comptime fail_description: []const u8, fail_args: anytype) !void {
    if (!Utils.shallow_equal(val_a, val_b)) {
        print("\nFAILURE: " ++ fail_description, fail_args);
        print("\n\tEXPECT: {s} shallow_equals {s}\n\tEXPECT: {any} shallow_equals {any}\n\tACTUAL: {any} !shallow_equals {any}\n", .{ str_a, str_b, val_a, val_b, val_a, val_b });
        return TestError.test_expected_shallow_equal;
    }
}
