const std = @import("std");
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;
const CompareFn = Compare.CompareFn;
const inline_swap = Root.Utils.inline_swap;
const a_less_than_b = Compare.a_less_than_b;
const a_greater_than_b = Compare.a_greater_than_b;
const a_less_than_or_equal_to_b = Compare.a_less_than_or_equal_to_b;

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

pub inline fn quicksort(comptime T: type, compare_fn: CompareFn(T), pivot: Pivot, buffer: []T) void {
    if (buffer.len < 2) return;
    recurse(T, compare_fn, pivot, buffer, 0, buffer.len - 1);
}

pub fn define_quicksort_package(comptime T: type, comptime compare_fn: CompareFn(T), comptime pivot: Pivot) type {
    return struct {
        pub inline fn sort(buffer: []T) void {
            quicksort(T, compare_fn, pivot, buffer);
        }
    };
}

fn recurse(comptime T: type, compare_fn: CompareFn(T), pivot: Pivot, buffer: []T, lo: usize, hi: usize) void {
    if (hi <= lo) return;
    const mid = partition(T, compare_fn, pivot, buffer, lo, hi);
    recurse(T, compare_fn, pivot, buffer, lo, mid.lo -| 1);
    recurse(T, compare_fn, pivot, buffer, mid.hi + 1, hi);
}

fn partition(comptime T: type, compare_fn: CompareFn(T), pivot: Pivot, buffer: []T, lo: usize, hi: usize) Range {
    const pivot_idx = switch (pivot) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (a_less_than_or_equal_to_b(T, &buffer[lo], &buffer[mid], compare_fn)) {
                if (a_less_than_or_equal_to_b(T, &buffer[mid], &buffer[hi], compare_fn)) break :calc mid;
            } else if (a_less_than_or_equal_to_b(T, &buffer[lo], &buffer[hi], compare_fn)) {
                break :calc lo;
            }
            break :calc hi;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            if (a_less_than_or_equal_to_b(T, &buffer[idx_arr[0]], &buffer[idx_arr[1]], compare_fn)) {
                if (a_less_than_or_equal_to_b(T, &buffer[idx_arr[1]], &buffer[idx_arr[2]], compare_fn)) break :calc idx_arr[1];
            } else if (a_less_than_or_equal_to_b(T, &buffer[idx_arr[0]], &buffer[idx_arr[2]], compare_fn)) {
                break :calc idx_arr[0];
            }
            break :calc idx_arr[2];
        },
    };
    const pivot_val = buffer[pivot_idx];
    var less_idx: usize = lo;
    var equal_idx: usize = lo;
    var more_idx: usize = hi;
    var temp: T = undefined;
    while (equal_idx <= more_idx) {
        if (a_less_than_b(T, &buffer[equal_idx], &pivot_val, compare_fn)) {
            inline_swap(T, &buffer[equal_idx], &buffer[less_idx], &temp);
            less_idx += 1;
            equal_idx += 1;
        } else if (a_greater_than_b(T, &buffer[equal_idx], &pivot_val, compare_fn)) {
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

test "quicksort" {
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
    const compare_fn = Compare.numeric_order_else_always_equal(u8);

    for (cases) |case| {
        var output: [10]u8 = case.input;
        quicksort(u8, compare_fn, Pivot.FIRST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_fn, Pivot.MIDDLE, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_fn, Pivot.LAST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_fn, Pivot.RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_fn, Pivot.MEDIAN_OF_3, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, compare_fn, Pivot.MEDIAN_OF_3_RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
