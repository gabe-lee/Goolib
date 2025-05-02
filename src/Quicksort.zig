const std = @import("std");
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;

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

pub inline fn quicksort(comptime ELEMENT_TYPE: type, ORDER_FUNC: *const fn (a: *const ELEMENT_TYPE, b: *const ELEMENT_TYPE) Compare.Order, PIVOT: Pivot, buffer: []ELEMENT_TYPE) void {
    if (buffer.len == 0) return;
    recurse(ELEMENT_TYPE, ORDER_FUNC, PIVOT, buffer, 0, buffer.len - 1);
}

pub fn define_quicksort_package(comptime ELEMENT_TYPE: type, comptime ORDER_FUNC: *const fn (a: *const ELEMENT_TYPE, b: *const ELEMENT_TYPE) Compare.Order, comptime PIVOT: Pivot) type {
    return struct {
        pub inline fn sort(buffer: []ELEMENT_TYPE) void {
            quicksort(ELEMENT_TYPE, ORDER_FUNC, ORDER_FUNC, PIVOT, buffer);
        }
    };
}

fn recurse(comptime ELEMENT_TYPE: type, ORDER_FUNC: *const fn (a: *const ELEMENT_TYPE, b: *const ELEMENT_TYPE) Compare.Order, PIVOT: Pivot, buffer: []ELEMENT_TYPE, lo: usize, hi: usize) void {
    if (lo >= hi) return;
    const pivot_idx = partition(ELEMENT_TYPE, ORDER_FUNC, PIVOT, buffer, lo, hi);
    recurse(ELEMENT_TYPE, ORDER_FUNC, PIVOT, buffer, lo, pivot_idx -| 1);
    recurse(ELEMENT_TYPE, ORDER_FUNC, PIVOT, buffer, pivot_idx + 1, hi);
}

fn partition(comptime T: type, ORDER_FUNC: *const fn (a: *const T, b: *const T) Compare.Order, comptime PIVOT: Pivot, buffer: []T, lo: usize, hi: usize) usize {
    const pivot_idx = switch (PIVOT) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (Compare.a_less_than_or_equal_to_b(T, &buffer[lo], &buffer[mid], ORDER_FUNC)) {
                if (Compare.a_less_than_or_equal_to_b(T, &buffer[mid], &buffer[hi], ORDER_FUNC)) break :calc mid;
            } else if (Compare.a_less_than_or_equal_to_b(T, &buffer[lo], &buffer[hi], ORDER_FUNC)) {
                break :calc lo;
            }
            break :calc hi;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            if (Compare.a_less_than_or_equal_to_b(T, &buffer[idx_arr[0]], &buffer[idx_arr[1]], ORDER_FUNC)) {
                if (Compare.a_less_than_or_equal_to_b(T, &buffer[idx_arr[1]], &buffer[idx_arr[2]], ORDER_FUNC)) break :calc idx_arr[1];
            } else if (Compare.a_less_than_or_equal_to_b(T, &buffer[idx_arr[0]], &buffer[idx_arr[2]], ORDER_FUNC)) {
                break :calc idx_arr[0];
            }
            break :calc idx_arr[2];
        },
    };
    const pivot_val = buffer[pivot_idx];
    var left: usize = lo;
    var right: usize = hi;
    var temp: T = undefined;
    while (true) {
        while (Compare.a_less_than_b(T, &buffer[left], &pivot_val, ORDER_FUNC)) left += 1;
        while (Compare.a_greater_than_b(T, &buffer[right], &pivot_val, ORDER_FUNC)) right -= 1;
        if (left >= right) return right;
        Root.Utils.inline_swap(T, &buffer[left], &buffer[right], &temp);
    }
}

test "quicksort" {
    const t = std.testing;
    const TestCase = struct {
        input: [10]usize,
        expected_output: [10]usize,
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
    };
    const order = struct {
        fn func(element: *const usize) usize {
            return element.*;
        }
    };

    for (cases) |case| {
        var output: [10]usize = case.input;
        quicksort(usize, usize, order.func, Pivot.FIRST, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(usize, usize, order.func, Pivot.MIDDLE, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(usize, usize, order.func, Pivot.LAST, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(usize, usize, order.func, Pivot.RANDOM, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(usize, usize, order.func, Pivot.MEDIAN_OF_3, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(usize, usize, order.func, Pivot.MEDIAN_OF_3_RANDOM, output[0..case.len]);
        try t.expectEqualSlices(usize, case.expected_output[0..case.len], output[0..case.len]);
    }
}
