const std = @import("std");
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./root.zig");

pub const Pivot = enum {
    FIRST,
    MIDDLE,
    LAST,
    RANDOM,
    MEDIAN_OF_3,
    MEDIAN_OF_3_RANDOM,
};

pub inline fn quicksort(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime PIVOT: Pivot, buffer: []ELEMENT_TYPE) void {
    if (buffer.len == 0) return;
    recurse(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, PIVOT, buffer, 0, buffer.len - 1);
}

pub fn define_quicksort_package(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime PIVOT: Pivot) type {
    return struct {
        pub inline fn sort(buffer: []ELEMENT_TYPE) void {
            quicksort(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, PIVOT, buffer);
        }
    };
}

fn recurse(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime PIVOT: Pivot, buffer: []ELEMENT_TYPE, lo: usize, hi: usize) void {
    if (lo >= hi) return;
    const pivot_idx = partition(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, PIVOT, buffer, lo, hi);
    recurse(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, PIVOT, buffer, lo, pivot_idx -% 1);
    recurse(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, PIVOT, buffer, pivot_idx + 1, hi);
}

fn partition(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime PIVOT: Pivot, buffer: []ELEMENT_TYPE, lo: usize, hi: usize) usize {
    var temp: ELEMENT_TYPE = undefined;
    const pivot_idx = switch (PIVOT) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.inline_simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (ORDER_FUNC(&buffer[mid]) < ORDER_FUNC(&buffer[lo])) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[mid], &buffer[lo], &temp);
            if (ORDER_FUNC(&buffer[hi] < ORDER_FUNC(&buffer[lo]))) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[hi], &buffer[lo], &temp);
            if (ORDER_FUNC(&buffer[mid] < ORDER_FUNC(&buffer[hi]))) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[mid], &buffer[hi], &temp);
            if (build.mode == .Debug) {
                assert(ORDER_FUNC(&buffer[hi]) <= ORDER_FUNC(&buffer[mid]));
                assert(ORDER_FUNC(&buffer[lo]) <= ORDER_FUNC(&buffer[hi]));
            }
            break :calc hi;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.inline_simple_n_rand_ints(usize, 3, 13, lo, hi);
            if (ORDER_FUNC(&buffer[idx_arr[1]]) < ORDER_FUNC(&buffer[idx_arr[0]])) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[idx_arr[1]], &buffer[idx_arr[0]], &temp);
            if (ORDER_FUNC(&buffer[idx_arr[2]]) < ORDER_FUNC(&buffer[idx_arr[0]])) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[idx_arr[2]], &buffer[idx_arr[0]], &temp);
            if (ORDER_FUNC(&buffer[idx_arr[1]]) < ORDER_FUNC(&buffer[idx_arr[2]])) Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[idx_arr[1]], &buffer[idx_arr[2]], &temp);
            if (build.mode == .Debug) {
                assert(ORDER_FUNC(&buffer[idx_arr[2]]) <= ORDER_FUNC(&buffer[idx_arr[1]]));
                assert(ORDER_FUNC(&buffer[idx_arr[0]]) <= ORDER_FUNC(&buffer[idx_arr[2]]));
            }
            break :calc idx_arr[2];
        },
    };
    const pivot_val = ORDER_FUNC(&buffer[pivot_idx]);
    var left: usize = lo;
    var right: usize = hi;
    while (true) {
        while (ORDER_FUNC(&buffer[left]) < pivot_val) left += 1;
        while (ORDER_FUNC(&buffer[right] > pivot_val)) right -= 1;
        if (left >= right) return right;
        Root.Utils.inline_swap(ELEMENT_TYPE, &buffer[left], &buffer[right], &temp);
    }
}
