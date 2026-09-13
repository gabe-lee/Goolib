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
const Utils = Root.Utils;
const infered_less_than = Utils.infered_less_than;
const infered_greater_than = Utils.infered_greater_than;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
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

pub inline fn quicksort(comptime T: type, pivot: Pivot, buffer: []T) void {
    if (buffer.len < 2) return;
    recurse(T, pivot, buffer, 0, buffer.len - 1);
}

fn recurse(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize) void {
    if (hi <= lo) return;
    const mid = partition(T, pivot, buffer, lo, hi);
    recurse(T, pivot, buffer, lo, mid.lo -| 1);
    recurse(T, pivot, buffer, mid.hi + 1, hi);
}

fn partition(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize) Range {
    const pivot_idx = switch (pivot) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (infered_less_than(buffer[lo], buffer[mid])) {
                if (infered_less_than(buffer[mid], buffer[hi])) break :calc mid;
                if (infered_less_than(buffer[lo], buffer[hi])) break :calc hi;
                break :calc lo;
            }
            if (infered_less_than(buffer[lo], buffer[hi])) break :calc lo;
            if (infered_less_than(buffer[mid], buffer[hi])) break :calc hi;
            break :calc mid;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            const t_lo = idx_arr[0];
            const t_mid = idx_arr[1];
            const t_hi = idx_arr[2];
            if (infered_less_than(buffer[t_lo], buffer[t_mid])) {
                if (infered_less_than(buffer[t_mid], buffer[t_hi])) break :calc t_mid;
                if (infered_less_than(buffer[t_lo], buffer[t_hi])) break :calc t_hi;
                break :calc t_lo;
            }
            if (infered_less_than(buffer[t_lo], buffer[t_hi])) break :calc t_lo;
            if (infered_less_than(buffer[t_mid], buffer[t_hi])) break :calc t_hi;
            break :calc t_mid;
        },
    };
    const pivot_val = buffer[pivot_idx];
    var less_idx: usize = lo;
    var equal_idx: usize = lo;
    var more_idx: usize = hi;
    var temp: T = undefined;
    while (equal_idx <= more_idx) {
        if (infered_less_than(buffer[equal_idx], pivot_val)) {
            inline_swap(T, &buffer[equal_idx], &buffer[less_idx], &temp);
            less_idx += 1;
            equal_idx += 1;
        } else if (infered_greater_than(buffer[equal_idx], pivot_val)) {
            inline_swap(T, &buffer[equal_idx], &buffer[more_idx], &temp);
            more_idx -= 1;
        } else {
            equal_idx += 1;
        }
    }
    return Range.new(less_idx, more_idx);
}

pub inline fn quicksort_with_transform(comptime T: type, pivot: Pivot, buffer: []T, comptime TX: type, transform_fn: *const fn (item: T) TX) void {
    if (buffer.len < 2) return;
    recurse_with_transform(T, pivot, buffer, 0, buffer.len - 1, TX, transform_fn);
}

fn recurse_with_transform(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize, comptime TX: type, transform_fn: *const fn (item: T) TX) void {
    if (hi <= lo) return;
    const mid = partition_with_transform(T, pivot, buffer, lo, hi, TX, transform_fn);
    recurse_with_transform(T, pivot, buffer, lo, mid.lo -| 1, TX, transform_fn);
    recurse_with_transform(T, pivot, buffer, mid.hi + 1, hi, TX, transform_fn);
}

fn partition_with_transform(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize, comptime TX: type, transform_fn: *const fn (item: T) TX) Range {
    const pivot_idx = switch (pivot) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (infered_less_than(transform_fn(buffer[lo]), transform_fn(buffer[mid]))) {
                if (infered_less_than(transform_fn(buffer[mid]), transform_fn(buffer[hi]))) break :calc mid;
                if (infered_less_than(transform_fn(buffer[lo]), transform_fn(buffer[hi]))) break :calc hi;
                break :calc lo;
            }
            if (infered_less_than(transform_fn(buffer[lo]), transform_fn(buffer[hi]))) break :calc lo;
            if (infered_less_than(transform_fn(buffer[mid]), transform_fn(buffer[hi]))) break :calc hi;
            break :calc mid;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            const t_lo = idx_arr[0];
            const t_mid = idx_arr[1];
            const t_hi = idx_arr[2];
            if (infered_less_than(transform_fn(buffer[t_lo]), transform_fn(buffer[t_mid]))) {
                if (infered_less_than(transform_fn(buffer[t_mid]), transform_fn(buffer[t_hi]))) break :calc t_mid;
                if (infered_less_than(transform_fn(buffer[t_lo]), transform_fn(buffer[t_hi]))) break :calc t_hi;
                break :calc t_lo;
            }
            if (infered_less_than(transform_fn(buffer[t_lo]), transform_fn(buffer[t_hi]))) break :calc t_lo;
            if (infered_less_than(transform_fn(buffer[t_mid]), transform_fn(buffer[t_hi]))) break :calc t_hi;
            break :calc t_mid;
        },
    };
    const pivot_val = buffer[pivot_idx];
    var less_idx: usize = lo;
    var equal_idx: usize = lo;
    var more_idx: usize = hi;
    var temp: T = undefined;
    while (equal_idx <= more_idx) {
        if (infered_less_than(transform_fn(buffer[equal_idx]), transform_fn(pivot_val))) {
            inline_swap(T, &buffer[equal_idx], &buffer[less_idx], &temp);
            less_idx += 1;
            equal_idx += 1;
        } else if (infered_greater_than(transform_fn(buffer[equal_idx]), transform_fn(pivot_val))) {
            inline_swap(T, &buffer[equal_idx], &buffer[more_idx], &temp);
            more_idx -= 1;
        } else {
            equal_idx += 1;
        }
    }
    return Range.new(less_idx, more_idx);
}

pub inline fn quicksort_with_transform_and_user_data(comptime T: type, pivot: Pivot, buffer: []T, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) void {
    if (buffer.len < 2) return;
    recurse_with_transform_and_user_data(T, pivot, buffer, 0, buffer.len - 1, TX, transform_fn, user_data);
}

fn recurse_with_transform_and_user_data(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) void {
    if (hi <= lo) return;
    const mid = partition_with_transform_and_user_data(T, pivot, buffer, lo, hi, TX, transform_fn, user_data);
    recurse_with_transform_and_user_data(T, pivot, buffer, lo, mid.lo -| 1, TX, transform_fn, user_data);
    recurse_with_transform_and_user_data(T, pivot, buffer, mid.hi + 1, hi, TX, transform_fn, user_data);
}

fn partition_with_transform_and_user_data(comptime T: type, pivot: Pivot, buffer: []T, lo: usize, hi: usize, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) Range {
    const pivot_idx = switch (pivot) {
        Pivot.FIRST => lo,
        Pivot.MIDDLE => ((hi - lo) >> 1) + lo,
        Pivot.LAST => hi,
        Pivot.RANDOM => Root.Utils.simple_rand_int(usize, lo, hi),
        Pivot.MEDIAN_OF_3 => calc: {
            const mid = ((hi - lo) >> 1) + lo;
            if (infered_less_than(transform_fn(buffer[lo], user_data), transform_fn(buffer[mid], user_data))) {
                if (infered_less_than(transform_fn(buffer[mid], user_data), transform_fn(buffer[hi], user_data))) break :calc mid;
                if (infered_less_than(transform_fn(buffer[lo], user_data), transform_fn(buffer[hi], user_data))) break :calc hi;
                break :calc lo;
            }
            if (infered_less_than(transform_fn(buffer[lo], user_data), transform_fn(buffer[hi], user_data))) break :calc lo;
            if (infered_less_than(transform_fn(buffer[mid], user_data), transform_fn(buffer[hi], user_data))) break :calc hi;
            break :calc mid;
        },
        Pivot.MEDIAN_OF_3_RANDOM => calc: {
            const idx_arr = Root.Utils.simple_n_rand_ints(usize, 3, lo, hi);
            const t_lo = idx_arr[0];
            const t_mid = idx_arr[1];
            const t_hi = idx_arr[2];
            if (infered_less_than(transform_fn(buffer[t_lo], user_data), transform_fn(buffer[t_mid], user_data))) {
                if (infered_less_than(transform_fn(buffer[t_mid], user_data), transform_fn(buffer[t_hi], user_data))) break :calc t_mid;
                if (infered_less_than(transform_fn(buffer[t_lo], user_data), transform_fn(buffer[t_hi], user_data))) break :calc t_hi;
                break :calc t_lo;
            }
            if (infered_less_than(transform_fn(buffer[t_lo], user_data), transform_fn(buffer[t_hi], user_data))) break :calc t_lo;
            if (infered_less_than(transform_fn(buffer[t_mid], user_data), transform_fn(buffer[t_hi], user_data))) break :calc t_hi;
            break :calc t_mid;
        },
    };
    const pivot_val = buffer[pivot_idx];
    var less_idx: usize = lo;
    var equal_idx: usize = lo;
    var more_idx: usize = hi;
    var temp: T = undefined;
    while (equal_idx <= more_idx) {
        if (infered_less_than(transform_fn(buffer[equal_idx], user_data), transform_fn(pivot_val, user_data))) {
            inline_swap(T, &buffer[equal_idx], &buffer[less_idx], &temp);
            less_idx += 1;
            equal_idx += 1;
        } else if (infered_greater_than(transform_fn(buffer[equal_idx], user_data), transform_fn(pivot_val, user_data))) {
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

    for (cases) |case| {
        var output: [10]u8 = case.input;
        quicksort(u8, Pivot.FIRST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, Pivot.MIDDLE, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, Pivot.LAST, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, Pivot.RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, Pivot.MEDIAN_OF_3, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
        output = case.input;
        quicksort(u8, Pivot.MEDIAN_OF_3_RANDOM, output[0..case.len]);
        try t.expectEqualSlices(u8, case.expected_output[0..case.len], output[0..case.len]);
    }
}
