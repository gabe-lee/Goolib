const std = @import("std");
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const CompareFn = Compare.CompareFn;
const ComparePackage = Compare.ComparePackage;
const inline_swap = Root.Utils.inline_swap;

pub const Pivot = enum(u8) {
    FIRST,
    MIDDLE,
    LAST,
    RANDOM,
    MEDIAN_OF_3,
    MEDIAN_OF_3_RANDOM,

    pub fn from_sort_algorithm(algorithm: SortAlgorithm) Pivot {
        switch (algorithm) {
            SortAlgorithm.QUICK_SORT_PIVOT_FIRST => Pivot.FIRST,
            SortAlgorithm.QUICK_SORT_PIVOT_LAST => Pivot.LAST,
            SortAlgorithm.QUICK_SORT_PIVOT_MIDDLE => Pivot.MIDDLE,
            SortAlgorithm.QUICK_SORT_PIVOT_RANDOM => Pivot.RANDOM,
            SortAlgorithm.QUICK_SORT_PIVOT_MEDIAN_OF_3 => Pivot.MEDIAN_OF_3,
            SortAlgorithm.QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM => Pivot.MEDIAN_OF_3_RANDOM,
            else => Pivot.FIRST,
        }
    }
};

pub inline fn quicksort(comptime T: type, greater_than_fn: *const CompareFn(T), less_than_fn: *const CompareFn(T), pivot: Pivot, buffer: []T) void {
    if (buffer.len < 2) return;
    recurse(T, greater_than_fn, less_than_fn, pivot, buffer, 0, buffer.len - 1);
}

fn recurse(comptime T: type, greater_than_fn: *const CompareFn(T), less_than_fn: *const CompareFn(T), pivot: Pivot, buffer: []T, lo: usize, hi: usize) void {
    if (hi <= lo) return;
    const mid = partition(T, greater_than_fn, less_than_fn, pivot, buffer, lo, hi);
    recurse(T, greater_than_fn, less_than_fn, pivot, buffer, lo, mid.lo -| 1);
    recurse(T, greater_than_fn, less_than_fn, pivot, buffer, mid.hi + 1, hi);
}

fn partition(comptime T: type, greater_than_fn: *const CompareFn(T), less_than_fn: *const CompareFn(T), pivot: Pivot, buffer: []T, lo: usize, hi: usize) Range {
    const pivot_idx = switch (pivot) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (less_than_fn(buffer[lo], buffer[mid])) {
                if (less_than_fn(buffer[mid], buffer[hi])) break :calc mid;
                if (less_than_fn(buffer[lo], buffer[hi])) break :calc hi;
                break :calc lo;
            }
            if (less_than_fn(buffer[lo], buffer[hi])) break :calc lo;
            if (less_than_fn(buffer[mid], buffer[hi])) break :calc hi;
            break :calc mid;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            const t_lo = idx_arr[0];
            const t_mid = idx_arr[1];
            const t_hi = idx_arr[2];
            if (less_than_fn(buffer[t_lo], buffer[t_mid])) {
                if (less_than_fn(buffer[t_mid], buffer[t_hi])) break :calc t_mid;
                if (less_than_fn(buffer[t_lo], buffer[t_hi])) break :calc t_hi;
                break :calc t_lo;
            }
            if (less_than_fn(buffer[t_lo], buffer[t_hi])) break :calc t_lo;
            if (less_than_fn(buffer[t_mid], buffer[t_hi])) break :calc t_hi;
            break :calc t_mid;
        },
    };
    const pivot_val = buffer[pivot_idx];
    var less_idx: usize = lo;
    var equal_idx: usize = lo;
    var more_idx: usize = hi;
    var temp: T = undefined;
    while (equal_idx <= more_idx) {
        if (less_than_fn(buffer[equal_idx], pivot_val)) {
            inline_swap(T, &buffer[equal_idx], &buffer[less_idx], &temp);
            less_idx += 1;
            equal_idx += 1;
        } else if (greater_than_fn(buffer[equal_idx], pivot_val)) {
            inline_swap(T, &buffer[equal_idx], &buffer[more_idx], &temp);
            more_idx -= 1;
        } else {
            equal_idx += 1;
        }
    }
    return Range.new(less_idx, more_idx);
}

const Range = extern struct {
    lo: usize = 0,
    hi: usize = 0,

    inline fn new(lo: usize, hi: usize) Range {
        return Range{
            .lo = lo,
            .hi = hi,
        };
    }
};

test "Quicksort.zig" {
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
    const compare_pkg = ComparePackage(u8).default();

    for (cases) |case| {
        var output: [10]u8 = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.FIRST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.MIDDLE, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.LAST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.MEDIAN_OF_3, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_pkg.order_greater_than, compare_pkg.order_less_than, Pivot.MEDIAN_OF_3_RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
