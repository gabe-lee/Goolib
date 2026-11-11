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

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.Allocator.Dummy.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;
const Growth = Common.GrowthModel;
const FuncParamType = Common.FuncParamType;
const ErrorBehavior = Common.ErrorBehavior;
const AllocErr = Utils.Alloc.AllocErr;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const kind_info = KindInfo.get_kind_info;

const GooListSliceModule = Root.ListSlice;
const ListNotAllocatedAdvanced = GooListSliceModule.ListNotAllocatedAdvanced;
const ListAllocatedAdvanced = GooListSliceModule.ListAllocatedAdvanced;
const SliceMutableAdvanced = GooListSliceModule.SliceMutableAdvanced;
const SliceImmutableAdvanced = GooListSliceModule.SliceImmutableAdvanced;
const ListFullDefinition = GooListSliceModule.ListFullDefinition;

/// Asserts that `list` contains exactly `expected`.
fn expectListEqual(
    comptime L: type,
    list: L,
    expected: []const L.LIST_DEF.ELEM,
    comptime src: std.lang.SourceLocation,
    comptime fail_description: []const u8,
    fail_args: anytype,
) !void {
    const IDX = L.LIST_DEF.IDX;
    try Test.expect_equal_src(list.get_len(), @as(IDX, @intCast(expected.len)), src, fail_description, fail_args);
    for (expected, 0..) |e, i| {
        try Test.expect_equal_src(list.get(@intCast(i)), e, src, fail_description, fail_args);
    }
}

test "ListSlice -> basic operations (whole structs)" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Src = SliceImmutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);

    var buf: [32]u32 = undefined;
    var list = L.from_slice_set_empty(buf[0..]);
    try Test.expect_true_src(list.is_empty(), @src(), "new list should be empty", .{});
    try Test.expect_true_src(!list.not_empty(), @src(), "new list should not be non-empty", .{});
    try Test.expect_equal_src(list.get_len(), 0, @src(), "len", .{});
    try Test.expect_equal_src(list.get_cap(), 32, @src(), "cap", .{});
    try Test.expect_equal_src(list.get_unused_space(), 32, @src(), "unused space", .{});

    const src_arr = [_]u32{ 40, 50 };
    const src = Src.from_slice_const_keep_data(src_arr[0..]);
    const src2_arr = [_]u32{ 1, 2 };
    const src2 = Src.from_slice_const_keep_data(src2_arr[0..]);
    const src3_arr = [_]u32{ 7, 8 };
    const src3 = Src.from_slice_const_keep_data(src3_arr[0..]);
    const src4_arr = [_]u32{ 60, 70 };
    const src4 = Src.from_slice_const_keep_data(src4_arr[0..]);

    // Append
    const appended_idx = list.append_one_assume_cap_get_idx(10);
    try Test.expect_equal_src(appended_idx, 0, @src(), "appended idx", .{});
    const appended_ptr = list.append_one_assume_cap_get_ptr(20);
    appended_ptr.* = 21;
    const appended_ptr2, const appended_idx2 = list.append_one_assume_cap_get_ptr_idx(30);
    appended_ptr2.* = 31;
    try Test.expect_equal_src(appended_idx2, 2, @src(), "appended idx 2", .{});
    list.append_many_assume_cap(src);
    try expectListEqual(L, list, &.{ 10, 21, 31, 40, 50 }, @src(), "after appends", .{});

    // Prepend
    list.prepend_one_assume_cap(5);
    list.prepend_many_assume_cap(src2);
    try expectListEqual(L, list, &.{ 1, 2, 5, 10, 21, 31, 40, 50 }, @src(), "after prepends", .{});

    // Insert
    list.insert_one_assume_cap(3, 99);
    list.insert_many_assume_cap(0, src3);
    list.insert_many_assume_cap(list.get_len(), src4);
    try expectListEqual(L, list, &.{ 7, 8, 1, 2, 5, 99, 10, 21, 31, 40, 50, 60, 70 }, @src(), "after inserts", .{});

    // Set / get
    list.set(0, 77);
    list.set_last(88);
    list.set_nth_from_end(1, 66);
    try Test.expect_equal_src(list.get_last(), 88, @src(), "get_last", .{});
    try Test.expect_equal_src(list.get_nth_from_end(1), 66, @src(), "get_nth_from_end", .{});
    list.get_ptr(0).* = 78;
    try Test.expect_equal_src(list.get_ptr_const(0).*, 78, @src(), "get_ptr_const", .{});
    try Test.expect_equal_src(list.get_last_ptr().*, 88, @src(), "get_last_ptr", .{});
    try Test.expect_equal_src(list.get_last_ptr_const().*, 88, @src(), "get_last_ptr_const", .{});
    try Test.expect_equal_src(list.get_nth_from_end_ptr(1).*, 66, @src(), "get_nth_from_end_ptr", .{});
    try Test.expect_equal_src(list.get_nth_from_end_ptr_const(1).*, 66, @src(), "get_nth_from_end_ptr_const", .{});
    try expectListEqual(L, list, &.{ 78, 8, 1, 2, 5, 99, 10, 21, 31, 40, 50, 66, 88 }, @src(), "after set/get", .{});

    // Delete one (ordered)
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4 };
        var l = L.from_slice_keep_data(arr[0..]);
        l.delete_one(0);
        try expectListEqual(L, l, &.{ 1, 2, 3, 4 }, @src(), "delete_one first", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4 };
        l = L.from_slice_keep_data(arr[0..]);
        l.delete_one(2);
        try expectListEqual(L, l, &.{ 0, 1, 3, 4 }, @src(), "delete_one middle", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4 };
        l = L.from_slice_keep_data(arr[0..]);
        try Test.expect_equal_src(l.remove_one(1), 1, @src(), "remove_one return", .{});
        try expectListEqual(L, l, &.{ 0, 2, 3, 4 }, @src(), "remove_one list", .{});
        try Test.expect_equal_src(l.pop(), 4, @src(), "pop return", .{});
        try expectListEqual(L, l, &.{ 0, 2, 3 }, @src(), "pop list", .{});
        try Test.expect_equal_src(l.try_pop(), @as(?u32, 3), @src(), "try_pop return", .{});
        l.clear();
        try Test.expect_true_src(l.is_empty(), @src(), "clear empties list", .{});
        try Test.expect_equal_src(l.try_pop(), @as(?u32, null), @src(), "try_pop empty", .{});
    }

    // Swap delete one
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4 };
        var l = L.from_slice_keep_data(arr[0..]);
        l.swap_delete_one(1);
        try expectListEqual(L, l, &.{ 0, 4, 2, 3 }, @src(), "swap_delete_one", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4 };
        l = L.from_slice_keep_data(arr[0..]);
        try Test.expect_equal_src(l.swap_remove_one(1), 1, @src(), "swap_remove_one return", .{});
        try expectListEqual(L, l, &.{ 0, 4, 2, 3 }, @src(), "swap_remove_one list", .{});
    }

    // Delete/remove ranges
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        var l = L.from_slice_keep_data(arr[0..]);
        l.delete_range(1, 3);
        try expectListEqual(L, l, &.{ 0, 3, 4, 5 }, @src(), "delete_range", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.delete_count(1, 2);
        try expectListEqual(L, l, &.{ 0, 3, 4, 5 }, @src(), "delete_count", .{});

        var dest_buf: [8]u32 = undefined;
        var dest = L.from_slice_set_empty(dest_buf[0..]);
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.remove_range(1, 3, &dest);
        try expectListEqual(L, l, &.{ 0, 3, 4, 5 }, @src(), "remove_range list", .{});
        try expectListEqual(L, dest, &.{ 1, 2 }, @src(), "remove_range dest", .{});

        dest.clear();
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.remove_count(1, 2, &dest);
        try expectListEqual(L, l, &.{ 0, 3, 4, 5 }, @src(), "remove_count list", .{});
        try expectListEqual(L, dest, &.{ 1, 2 }, @src(), "remove_count dest", .{});

        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.swap_delete_range(1, 3);
        try expectListEqual(L, l, &.{ 0, 4, 5, 3 }, @src(), "swap_delete_range", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.swap_delete_count(1, 2);
        try expectListEqual(L, l, &.{ 0, 4, 5, 3 }, @src(), "swap_delete_count", .{});

        dest.clear();
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.swap_remove_range(1, 3, &dest);
        try expectListEqual(L, l, &.{ 0, 4, 5, 3 }, @src(), "swap_remove_range list", .{});
        try expectListEqual(L, dest, &.{ 1, 2 }, @src(), "swap_remove_range dest", .{});

        dest.clear();
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        l = L.from_slice_keep_data(arr[0..]);
        l.swap_remove_count(1, 2, &dest);
        try expectListEqual(L, l, &.{ 0, 4, 5, 3 }, @src(), "swap_remove_count list", .{});
        try expectListEqual(L, dest, &.{ 1, 2 }, @src(), "swap_remove_count dest", .{});
    }
}

test "ListSlice -> len/cap helpers" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    var buf: [10]u32 = undefined;
    var list = L.from_slice_set_empty(buf[0..]);

    list.set_len(5);
    try Test.expect_equal_src(list.get_len(), 5, @src(), "set_len", .{});
    list.incr_len(2);
    try Test.expect_equal_src(list.get_len(), 7, @src(), "incr_len", .{});
    list.decr_len(1);
    try Test.expect_equal_src(list.get_len(), 6, @src(), "decr_len", .{});
    list.set_len_unchecked(3);
    try Test.expect_equal_src(list.get_len(), 3, @src(), "set_len_unchecked", .{});
    list.set_len_to_cap();
    try Test.expect_equal_src(list.get_len(), 10, @src(), "set_len_to_cap", .{});
    list.decr_len_unchecked(4);
    try Test.expect_equal_src(list.get_len(), 6, @src(), "decr_len_unchecked", .{});
    list.incr_len_unchecked(2);
    try Test.expect_equal_src(list.get_len(), 8, @src(), "incr_len_unchecked", .{});
    list.incr_len_to_cap();
    try Test.expect_equal_src(list.get_len(), 10, @src(), "incr_len_to_cap", .{});
    list.set_len_clamped(20);
    try Test.expect_equal_src(list.get_len(), 10, @src(), "set_len_clamped high", .{});
    list.set_len_clamped(4);
    try Test.expect_equal_src(list.get_len(), 4, @src(), "set_len_clamped low", .{});
    list.incr_len_clamped(100);
    try Test.expect_equal_src(list.get_len(), 10, @src(), "incr_len_clamped", .{});
    list.decr_len_clamped(100);
    try Test.expect_equal_src(list.get_len(), 0, @src(), "decr_len_clamped", .{});

    list.set_len_unchecked(9);
    list.set_root_cap(8);
    try Test.expect_equal_src(list.get_cap(), 8, @src(), "set_root_cap cap", .{});
    try Test.expect_equal_src(list.get_len(), 8, @src(), "set_root_cap clamps len", .{});
    list.incr_root_cap(2);
    try Test.expect_equal_src(list.get_cap(), 10, @src(), "incr_root_cap", .{});
    list.decr_root_cap(3);
    try Test.expect_equal_src(list.get_cap(), 7, @src(), "decr_root_cap", .{});
    try Test.expect_equal_src(list.get_len(), 7, @src(), "decr_root_cap clamps len", .{});
    list.incr_root_cap_clamped(5);
    try Test.expect_equal_src(list.get_cap(), 12, @src(), "incr_root_cap_clamped", .{});
    list.decr_root_cap_clamped(100);
    try Test.expect_equal_src(list.get_cap(), 0, @src(), "decr_root_cap_clamped", .{});
    try Test.expect_equal_src(list.get_len(), 0, @src(), "decr_root_cap_clamped clamps len", .{});
}

test "ListSlice -> slices and references" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const S = SliceMutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const SC = SliceImmutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Src = SliceImmutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);

    var buf: [10]u32 = undefined;
    var base = L.from_slice_keep_data(buf[0..]);
    for (0..10) |i| base.set(@intCast(i), @intCast(i));

    // slice()
    {
        var s = base.slice(2, 5);
        try Test.expect_equal_src(s.get_len(), 3, @src(), "slice len", .{});
        try Test.expect_equal_src(s.get_cap(), 8, @src(), "slice cap", .{});
        try expectListEqual(S, s, &.{ 2, 3, 4 }, @src(), "slice contents", .{});
        s.set(0, 20);
        try Test.expect_equal_src(base.get(2), 20, @src(), "slice set writes through", .{});
        try expectListEqual(S, base.slice_from_start(3), &.{ 0, 1, 20 }, @src(), "slice_from_start", .{});
        try expectListEqual(S, base.slice_to_end(7), &.{ 7, 8, 9 }, @src(), "slice_to_end", .{});
        try expectListEqual(S, base.slice_entire(), &.{ 0, 1, 20, 3, 4, 5, 6, 7, 8, 9 }, @src(), "slice_entire", .{});

        const sc = base.slice_const(1, 4);
        try expectListEqual(SC, sc, &.{ 1, 20, 3 }, @src(), "slice_const", .{});
        try expectListEqual(SC, base.slice_from_start_const(2), &.{ 0, 1 }, @src(), "slice_from_start_const", .{});
        try expectListEqual(SC, base.slice_to_end_const(8), &.{ 8, 9 }, @src(), "slice_to_end_const", .{});
        try expectListEqual(SC, base.slice_entire_const(), &.{ 0, 1, 20, 3, 4, 5, 6, 7, 8, 9 }, @src(), "slice_entire_const", .{});

        // zig slices
        try Test.expect_slices_equal_t_src(u32, &.{ 1, 20, 3 }, base.zig_slice(1, 4), @src(), "zig_slice", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 1, 20, 3 }, base.zig_slice_const(1, 4), @src(), "zig_slice_const", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 0, 1 }, base.zig_slice_from_start(2), @src(), "zig_slice_from_start", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 0, 1 }, base.zig_slice_from_start_const(2), @src(), "zig_slice_from_start_const", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 8, 9 }, base.zig_slice_to_end(8), @src(), "zig_slice_to_end", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 8, 9 }, base.zig_slice_to_end_const(8), @src(), "zig_slice_to_end_const", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 0, 1, 20, 3, 4, 5, 6, 7, 8, 9 }, base.zig_slice_entire(), @src(), "zig_slice_entire", .{});
        try Test.expect_slices_equal_t_src(u32, &.{ 0, 1, 20, 3, 4, 5, 6, 7, 8, 9 }, base.zig_slice_entire_const(), @src(), "zig_slice_entire_const", .{});
    }

    // Reference movement and mutation
    {
        var s = base.slice(2, 5); // [20, 3, 4]
        s.incr_slice_start(1);
        try expectListEqual(S, s, &.{ 3, 4 }, @src(), "incr_slice_start", .{});
        try Test.expect_equal_src(s.get_cap(), 7, @src(), "incr_slice_start cap", .{});
        s.decr_slice_start(1);
        try expectListEqual(S, s, &.{ 20, 3, 4 }, @src(), "decr_slice_start", .{});
        s.incr_slice_end(1);
        try expectListEqual(S, s, &.{ 20, 3, 4, 5 }, @src(), "incr_slice_end", .{});
        s.decr_slice_end(1);
        try expectListEqual(S, s, &.{ 20, 3, 4 }, @src(), "decr_slice_end", .{});
        s.slide_slice_lower(1);
        try expectListEqual(S, s, &.{ 1, 20, 3 }, @src(), "slide_slice_lower", .{});
        s.slide_slice_higher(1);
        try expectListEqual(S, s, &.{ 20, 3, 4 }, @src(), "slide_slice_higher", .{});

        s.append_one_assume_cap(99);
        try expectListEqual(S, s, &.{ 20, 3, 4, 99 }, @src(), "reference append", .{});
        s.prepend_one_assume_cap(88);
        try expectListEqual(S, s, &.{ 88, 20, 3, 4, 99 }, @src(), "reference prepend", .{});
        s.insert_one_assume_cap(2, 77);
        try expectListEqual(S, s, &.{ 88, 20, 77, 3, 4, 99 }, @src(), "reference insert", .{});

        const more_arr = [_]u32{ 7, 8 };
        const more = Src.from_slice_const_keep_data(more_arr[0..]);
        s.append_many_assume_cap(more);
        try expectListEqual(S, s, &.{ 88, 20, 77, 3, 4, 99, 7, 8 }, @src(), "reference append_many", .{});

        s.delete_one(0);
        try expectListEqual(S, s, &.{ 20, 77, 3, 4, 99, 7, 8 }, @src(), "reference delete_one", .{});
        try Test.expect_equal_src(s.pop(), 8, @src(), "reference pop", .{});
        try expectListEqual(S, s, &.{ 20, 77, 3, 4, 99, 7 }, @src(), "reference pop list", .{});
    }

    // split off slices
    {
        const base_vals = [_]u32{ 0, 1, 20, 3, 4, 5, 6, 7, 8, 9 };
        for (base_vals, 0..) |v, i| base.set(@intCast(i), v);
        var s = base.slice(1, 7); // [1, 20, 3, 4, 5, 6]
        const first = s.split_off_slice_from_start(2);
        try expectListEqual(S, first, &.{ 1, 20 }, @src(), "split_off_slice_from_start first", .{});
        try expectListEqual(S, s, &.{ 3, 4, 5, 6 }, @src(), "split_off_slice_from_start rest", .{});
        const last = s.split_off_slice_from_end(1);
        try expectListEqual(S, last, &.{6}, @src(), "split_off_slice_from_end last", .{});
        try expectListEqual(S, s, &.{ 3, 4, 5 }, @src(), "split_off_slice_from_end rest", .{});

        var s2 = base.slice(2, 8); // [20, 3, 4, 5, 6, 7]
        const first_c = s2.split_off_slice_from_start_const(2);
        try expectListEqual(SC, first_c, &.{ 20, 3 }, @src(), "split_off_slice_from_start_const", .{});
        try expectListEqual(S, s2, &.{ 4, 5, 6, 7 }, @src(), "split_off_slice_from_start_const rest", .{});
        const last_c = s2.split_off_slice_from_end_const(1);
        try expectListEqual(SC, last_c, &.{7}, @src(), "split_off_slice_from_end_const", .{});
        try expectListEqual(S, s2, &.{ 4, 5, 6 }, @src(), "split_off_slice_from_end_const rest", .{});

        var s3 = base.slice(1, 6); // [1, 20, 3, 4, 5]
        const zs = s3.split_off_zig_slice_from_start(2);
        try Test.expect_slices_equal_t_src(u32, &.{ 1, 20 }, zs, @src(), "split_off_zig_slice_from_start", .{});
        try expectListEqual(S, s3, &.{ 3, 4, 5 }, @src(), "split_off_zig_slice_from_start rest", .{});
        const ze = s3.split_off_zig_slice_from_end(1);
        try Test.expect_slices_equal_t_src(u32, &.{5}, ze, @src(), "split_off_zig_slice_from_end", .{});
        try expectListEqual(S, s3, &.{ 3, 4 }, @src(), "split_off_zig_slice_from_end rest", .{});

        var s4 = base.slice(1, 6);
        const zsc = s4.split_off_zig_slice_from_start_const(2);
        try Test.expect_slices_equal_t_src(u32, &.{ 1, 20 }, zsc, @src(), "split_off_zig_slice_from_start_const", .{});
        try expectListEqual(S, s4, &.{ 3, 4, 5 }, @src(), "split_off_zig_slice_from_start_const rest", .{});
        const zec = s4.split_off_zig_slice_from_end_const(1);
        try Test.expect_slices_equal_t_src(u32, &.{5}, zec, @src(), "split_off_zig_slice_from_end_const", .{});
        try expectListEqual(S, s4, &.{ 3, 4 }, @src(), "split_off_zig_slice_from_end_const rest", .{});
    }
}

test "ListSlice -> memset" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    var buf: [8]u32 = undefined;
    var list = L.from_slice_set_empty(buf[0..]);
    list.set_len_to_cap();

    list.memset_cap(1);
    try expectListEqual(L, list, &.{ 1, 1, 1, 1, 1, 1, 1, 1 }, @src(), "memset_cap", .{});
    list.memset_range(2, 2, 5);
    try expectListEqual(L, list, &.{ 1, 1, 2, 2, 2, 1, 1, 1 }, @src(), "memset_range nonzero start", .{});
    list.memset_len(3);
    try expectListEqual(L, list, &.{ 3, 3, 3, 3, 3, 3, 3, 3 }, @src(), "memset_len", .{});

    list.memset_field_range(.@"$SELF", 4, 1, 3);
    try expectListEqual(L, list, &.{ 3, 4, 4, 3, 3, 3, 3, 3 }, @src(), "memset_field_range", .{});
    list.memset_field_len(.@"$SELF", 5);
    try expectListEqual(L, list, &.{ 5, 5, 5, 5, 5, 5, 5, 5 }, @src(), "memset_field_len", .{});
    list.memset_field_cap(.@"$SELF", 6);
    try expectListEqual(L, list, &.{ 6, 6, 6, 6, 6, 6, 6, 6 }, @src(), "memset_field_cap", .{});
}

test "ListSlice -> reverse/rotate/move/swap/shuffle" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Src = SliceImmutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);

    // reverse
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4 };
        var list = L.from_slice_keep_data(arr[0..]);
        list.reverse_range(1, 4);
        try expectListEqual(L, list, &.{ 0, 3, 2, 1, 4 }, @src(), "reverse_range", .{});
        list.reverse();
        try expectListEqual(L, list, &.{ 4, 1, 2, 3, 0 }, @src(), "reverse", .{});
    }

    // rotate
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4 };
        var list = L.from_slice_keep_data(arr[0..]);
        list.rotate(2);
        try expectListEqual(L, list, &.{ 3, 4, 0, 1, 2 }, @src(), "rotate right", .{});
        list.rotate(-1);
        try expectListEqual(L, list, &.{ 4, 0, 1, 2, 3 }, @src(), "rotate left", .{});
        list.rotate_range(1, 4, 1);
        try expectListEqual(L, list, &.{ 4, 2, 0, 1, 3 }, @src(), "rotate_range", .{});

        arr = [_]u32{ 0, 1, 2, 3, 4 };
        list = L.from_slice_keep_data(arr[0..]);
        list.rotate_range_right(0, 5, 2);
        try expectListEqual(L, list, &.{ 3, 4, 0, 1, 2 }, @src(), "rotate_range_right", .{});
        list.rotate_range_left(0, 5, 2);
        try expectListEqual(L, list, &.{ 0, 1, 2, 3, 4 }, @src(), "rotate_range_left", .{});
        list.rotate_right(1);
        try expectListEqual(L, list, &.{ 4, 0, 1, 2, 3 }, @src(), "rotate_right", .{});
        list.rotate_left(1);
        try expectListEqual(L, list, &.{ 0, 1, 2, 3, 4 }, @src(), "rotate_left", .{});
    }

    // move block
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        var list = L.from_slice_keep_data(arr[0..]);
        list.move_block_displace(1, 3, 4);
        try expectListEqual(L, list, &.{ 0, 3, 4, 5, 1, 2 }, @src(), "move_block_displace right", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_block_right_displace(1, 3, 4);
        try expectListEqual(L, list, &.{ 0, 3, 4, 5, 1, 2 }, @src(), "move_block_right_displace", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_block_left_displace(4, 6, 1);
        try expectListEqual(L, list, &.{ 0, 4, 5, 1, 2, 3 }, @src(), "move_block_left_displace", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_block_right_overwrite(1, 3, 4);
        try expectListEqual(L, list, &.{ 0, 1, 2, 3, 1, 2 }, @src(), "move_block_right_overwrite", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_block_left_overwrite(4, 6, 1);
        try expectListEqual(L, list, &.{ 0, 4, 5, 3, 4, 5 }, @src(), "move_block_left_overwrite", .{});
    }

    // move one / swap
    {
        var arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        var list = L.from_slice_keep_data(arr[0..]);
        list.move_one_displace(1, 4);
        try expectListEqual(L, list, &.{ 0, 2, 3, 4, 1, 5 }, @src(), "move_one_displace right", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_one_displace(4, 1);
        try expectListEqual(L, list, &.{ 0, 4, 1, 2, 3, 5 }, @src(), "move_one_displace left", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_one_right_displace(0, 2);
        try expectListEqual(L, list, &.{ 1, 2, 0, 3, 4, 5 }, @src(), "move_one_right_displace", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_one_left_displace(3, 1);
        try expectListEqual(L, list, &.{ 0, 3, 1, 2, 4, 5 }, @src(), "move_one_left_displace", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.move_one_overwrite(5, 0);
        try expectListEqual(L, list, &.{ 5, 1, 2, 3, 4, 5 }, @src(), "move_one_overwrite", .{});
        arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
        list = L.from_slice_keep_data(arr[0..]);
        list.swap(0, 5);
        try expectListEqual(L, list, &.{ 5, 1, 2, 3, 4, 0 }, @src(), "swap", .{});
        const val_b = list.get(5);
        list.swap_already_have_b(0, 5, val_b);
        try expectListEqual(L, list, &.{ 0, 1, 2, 3, 4, 5 }, @src(), "swap_already_have_b", .{});
    }

    // shuffle preserves the multiset
    {
        const N = 16;
        var arr: [N]u32 = undefined;
        for (0..N) |i| arr[i] = @intCast(i);
        var rand_impl = Root.Rand.create_new_default_prng_seeded_from_time(Test.io);
        const rand = rand_impl.random();

        var list = L.from_slice_keep_data(arr[0..]);
        list.shuffle_unbiased_once(rand);
        try expectMultiset(L, list, N, @src(), "shuffle_unbiased_once", .{});
        list.shuffle_unbiased(3, rand);
        try expectMultiset(L, list, N, @src(), "shuffle_unbiased", .{});
        list.shuffle_range_unbiased(0, N, 2, rand);
        try expectMultiset(L, list, N, @src(), "shuffle_range_unbiased", .{});
        list.shuffle_range_unbiased_once(2, N - 2, rand);
        try expectMultiset(L, list, N, @src(), "shuffle_range_unbiased_once", .{});
        list.shuffle_biased(5, rand);
        try expectMultiset(L, list, N, @src(), "shuffle_biased", .{});
        list.shuffle_range_biased(2, N - 2, 5, rand);
        try expectMultiset(L, list, N, @src(), "shuffle_range_biased", .{});

        const empty_src = [_]u32{};
        const empty = Src.from_slice_const_keep_data(empty_src[0..]);
        _ = empty;
    }
}

fn expectMultiset(comptime L: type, list: L, comptime N: usize, comptime src: std.lang.SourceLocation, comptime fail_description: []const u8, fail_args: anytype) !void {
    var seen: [N]u8 = @splat(0);
    for (0..list.get_len()) |i| {
        const v = list.get(@intCast(i));
        try Test.expect_true_src(v < N, src, fail_description ++ " (value out of range)", fail_args);
        try Test.expect_equal_src(seen[v], 0, src, fail_description ++ " (duplicate value)", fail_args);
        seen[v] = 1;
    }
    for (seen) |s| {
        try Test.expect_equal_src(s, 1, src, fail_description ++ " (missing value)", fail_args);
    }
}

test "ListSlice -> Traverser" {
    //    I
    //   / \
    //  G   H
    // /|\ /|\
    // ABC DEF
    const I: u8 = 0;
    const G: u8 = 1;
    const H: u8 = 2;
    const A: u8 = 3;
    const B: u8 = 4;
    const C: u8 = 5;
    const D: u8 = 6;
    const E: u8 = 7;
    const F: u8 = 8;
    const AA: u8 = 9;
    const BB: u8 = 10;
    const CC: u8 = 11;
    const DD: u8 = 12;
    const EE: u8 = 13;
    const FF: u8 = 14;
    const NULL: u8 = 255;
    const Node = struct {
        char: u8,
        first_child: u8,
        next_sibling: u8,
    };
    const NodeDual = struct {
        char: u8,
        first_child_lower: u8,
        first_child_upper: u8,
        next_sibling: u8,
    };
    var mem: [9]Node = undefined;
    var mem_dual: [15]NodeDual = undefined;
    mem[I] = Node{
        .char = 'i',
        .first_child = G,
        .next_sibling = NULL,
    };
    mem[G] = Node{
        .char = 'g',
        .first_child = A,
        .next_sibling = H,
    };
    mem[H] = Node{
        .char = 'h',
        .first_child = D,
        .next_sibling = NULL,
    };
    mem[A] = Node{
        .char = 'a',
        .first_child = NULL,
        .next_sibling = B,
    };
    mem[B] = Node{
        .char = 'b',
        .first_child = NULL,
        .next_sibling = C,
    };
    mem[C] = Node{
        .char = 'c',
        .first_child = NULL,
        .next_sibling = NULL,
    };
    mem[D] = Node{
        .char = 'd',
        .first_child = NULL,
        .next_sibling = E,
    };
    mem[E] = Node{
        .char = 'e',
        .first_child = NULL,
        .next_sibling = F,
    };
    mem[F] = Node{
        .char = 'f',
        .first_child = NULL,
        .next_sibling = NULL,
    };
    mem_dual[I] = NodeDual{
        .char = 'i',
        .first_child_lower = G,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[G] = NodeDual{
        .char = 'g',
        .first_child_lower = A,
        .first_child_upper = AA,
        .next_sibling = H,
    };
    mem_dual[H] = NodeDual{
        .char = 'h',
        .first_child_lower = D,
        .first_child_upper = DD,
        .next_sibling = NULL,
    };
    mem_dual[A] = NodeDual{
        .char = 'a',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = B,
    };
    mem_dual[B] = NodeDual{
        .char = 'b',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = C,
    };
    mem_dual[C] = NodeDual{
        .char = 'c',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[D] = NodeDual{
        .char = 'd',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = E,
    };
    mem_dual[E] = NodeDual{
        .char = 'e',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = F,
    };
    mem_dual[F] = NodeDual{
        .char = 'f',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[AA] = NodeDual{
        .char = 'A',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = BB,
    };
    mem_dual[BB] = NodeDual{
        .char = 'B',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = CC,
    };
    mem_dual[CC] = NodeDual{
        .char = 'C',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    mem_dual[DD] = NodeDual{
        .char = 'D',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = EE,
    };
    mem_dual[EE] = NodeDual{
        .char = 'E',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = FF,
    };
    mem_dual[FF] = NodeDual{
        .char = 'F',
        .first_child_lower = NULL,
        .first_child_upper = NULL,
        .next_sibling = NULL,
    };
    const Out = struct {
        buf: [15]u8 = undefined,
        idx: u8 = 0,
    };
    const TravList = ListFullDefinition(Node, u8, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_NOT_ALLOCATED, .PASSED_ALLOCATOR_INTERFACE);
    const TravListDual = ListFullDefinition(NodeDual, u8, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_NOT_ALLOCATED, .PASSED_ALLOCATOR_INTERFACE);
    const Trav = TravList.ForwardLinkedTraverser(&.{TravList.Field.first_child}, TravList.Field.next_sibling, .MAX_STACK_LEN_NOT_IMPORTANT);
    const TravDual = TravListDual.ForwardLinkedTraverser(&.{ TravListDual.Field.first_child_lower, TravListDual.Field.first_child_upper }, TravListDual.Field.next_sibling, .MAX_STACK_LEN_NOT_IMPORTANT);
    const PROTO = struct {
        fn act(list: TravList, idx: u8, out: *Out, comptime _: void) void {
            out.buf[out.idx] = list.get(idx).char;
            out.idx += 1;
        }
        fn act_rt(list: TravList, idx: u8, out: *Out, _: void) void {
            out.buf[out.idx] = list.get(idx).char;
            out.idx += 1;
        }
        fn act_dual(list: TravListDual, idx: u8, out: *Out, comptime _: void) void {
            out.buf[out.idx] = list.get(idx).char;
            out.idx += 1;
        }
        fn act_dual_rt(list: TravListDual, idx: u8, out: *Out, _: void) void {
            out.buf[out.idx] = list.get(idx).char;
            out.idx += 1;
        }
    };
    var stack_mem: [4]Trav.StackFrame = undefined;
    var stack_mem_dual: [4]TravDual.StackFrame = undefined;
    const stack = Trav.Stack.from_slice_set_empty(stack_mem[0..]);
    const stack_dual = TravDual.Stack.from_slice_set_empty(stack_mem_dual[0..]);
    const nodes = TravList.from_slice_keep_data(mem[0..]);
    const nodes_dual = TravListDual.from_slice_keep_data(mem_dual[0..]);
    var out = Out{};
    var trav = Trav.init_static_stack(nodes, stack);
    var trav_dual = TravDual.init_static_stack(nodes_dual, stack_dual);
    try trav.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, {}, null, .RUNTIME_FN_PTR, PROTO.act_rt, {});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav.do_action_on_all_nodes(.PARENTS_FIRST, .all_child_paths(), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabchdef", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, {}, null, .COMPTIME_FN_BODY, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, {}, null, .RUNTIME_FN_PTR, PROTO.act_dual_rt, {});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .all_child_paths(), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabcABChdefDEF", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .only_child_paths(&.{.first_child_lower}), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .exclude_child_paths(&.{.first_child_lower}), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .only_child_paths(&.{.first_child_upper}), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .exclude_child_paths(&.{.first_child_upper}), I, &out, {}, null, .COMPTIME_FN_PTR, {}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
}

test "ListSlice -> median_of_3_indexes" {
    const STATIC_IDS = [3]u32{ 0, 1, 2 };
    const Case = struct {
        input: [3]u8,
        med_idxs: []const u32,

        pub fn new(vals: [3]u8, med_idxs: []const u32) @This() {
            return @This(){
                .input = vals,
                .med_idxs = med_idxs,
            };
        }
    };
    const cases = [_]Case{
        Case.new(.{ 1, 2, 3 }, &.{1}),
        Case.new(.{ 1, 3, 2 }, &.{2}),
        Case.new(.{ 2, 1, 3 }, &.{0}),
        Case.new(.{ 2, 3, 1 }, &.{0}),
        Case.new(.{ 3, 1, 2 }, &.{2}),
        Case.new(.{ 3, 2, 1 }, &.{1}),
        Case.new(.{ 3, 3, 3 }, &.{ 0, 1, 2 }),
        Case.new(.{ 1, 1, 2 }, &.{ 0, 1 }),
        Case.new(.{ 1, 2, 2 }, &.{ 1, 2 }),
    };
    const U8List = SliceImmutableAdvanced(u8, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const SORT = struct {
        fn u8_greater_than_idx_idx(self: U8List, idx_a: u32, idx_b: u32, _: void, _: void) bool {
            return self.get(idx_a) > self.get(idx_b);
        }
    };
    next_case: for (cases) |case| {
        const list = U8List.from_slice_const_keep_data(&case.input);
        const med_idx = list.median_index_of_3(STATIC_IDS, SORT.u8_greater_than_idx_idx);
        const med_val = list.get(med_idx);
        for (case.med_idxs) |valid_median_idx| {
            if (med_idx == valid_median_idx) {
                try Test.expect_equal(med_val, "med_val", case.input[med_idx], "case.input[med_idx]", "", .{});
                continue :next_case;
            }
        }
        return error.median_idx_returned_is_incorrect;
    }
}

test "ListSlice -> sorting algorithms" {
    const SORT_TEST_CASES = struct {
        pub const Case = struct {
            input: []const u8,
            expected_output: []const u8,
        };

        const in01 = [_]u8{};
        const ex01 = [_]u8{};

        const in02 = [_]u8{42};
        const ex02 = [_]u8{42};

        const in03 = [_]u8{ 1, 2 };
        const ex03 = [_]u8{ 1, 2 };

        const in04 = [_]u8{ 2, 1 };
        const ex04 = [_]u8{ 1, 2 };

        const in05 = [_]u8{ 7, 7 };
        const ex05 = [_]u8{ 7, 7 };

        const in06 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
        const ex06 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

        const in07 = [_]u8{ 8, 7, 6, 5, 4, 3, 2, 1 };
        const ex07 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

        const in08 = [_]u8{ 0, 0, 0, 0, 0 };
        const ex08 = [_]u8{ 0, 0, 0, 0, 0 };

        const in09 = [_]u8{ 255, 255, 255, 255, 255 };
        const ex09 = [_]u8{ 255, 255, 255, 255, 255 };

        const in10 = [_]u8{ 0, 255, 0, 255, 0, 255, 0, 255 };
        const ex10 = [_]u8{ 0, 0, 0, 0, 255, 255, 255, 255 };

        const in11 = [_]u8{ 255, 0, 128, 0, 255, 128 };
        const ex11 = [_]u8{ 0, 0, 128, 128, 255, 255 };

        const in12 = [_]u8{ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 };
        const ex12 = [_]u8{ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 };

        const in13 = [_]u8{ 1, 2, 1, 2, 1, 2, 1, 2 };
        const ex13 = [_]u8{ 1, 1, 1, 1, 2, 2, 2, 2 };

        const in14 = [_]u8{ 3, 1, 2, 3, 1, 2, 3, 1, 2, 3 };
        const ex14 = [_]u8{ 1, 1, 1, 2, 2, 2, 3, 3, 3, 3 };

        const in15 = [_]u8{ 9, 9, 9, 1, 9, 9, 9, 9, 9, 9 };
        const ex15 = [_]u8{ 1, 9, 9, 9, 9, 9, 9, 9, 9, 9 };

        const in16 = [_]u8{ 9, 1, 2, 3, 4, 5, 6, 7, 8 };
        const ex16 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };

        const in17 = [_]u8{ 2, 3, 4, 5, 6, 7, 8, 9, 1 };
        const ex17 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };

        const in18 = [_]u8{ 1, 2, 3, 5, 4, 6, 7, 8 };
        const ex18 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

        const in19 = [_]u8{ 1, 3, 5, 7, 8, 6, 4, 2 };
        const ex19 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

        const in20 = [_]u8{ 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3 };
        const ex20 = [_]u8{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };

        const in21 = [_]u8{ 5, 6, 7, 8, 1, 2, 3, 4 };
        const ex21 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };

        const in22 = [_]u8{ 200, 100, 100, 100, 100, 100, 50 };
        const ex22 = [_]u8{ 50, 100, 100, 100, 100, 100, 200 };

        const in23 = [_]u8{ 10, 30, 20, 10, 30, 20, 10, 30, 20 };
        const ex23 = [_]u8{ 10, 10, 10, 20, 20, 20, 30, 30, 30 };

        const in24 = [_]u8{
            32, 31, 30, 29, 28, 27, 26, 25,
            24, 23, 22, 21, 20, 19, 18, 17,
            16, 15, 14, 13, 12, 11, 10, 9,
            8,  7,  6,  5,  4,  3,  2,  1,
        };
        const ex24 = [_]u8{
            1,  2,  3,  4,  5,  6,  7,  8,
            9,  10, 11, 12, 13, 14, 15, 16,
            17, 18, 19, 20, 21, 22, 23, 24,
            25, 26, 27, 28, 29, 30, 31, 32,
        };

        const in25 = [_]u8{
            255, 254, 253, 252, 251, 250, 249, 248,
            247, 246, 245, 244, 243, 242, 241, 240,
            128, 127, 126, 125, 3,   2,   1,   0,
        };
        const ex25 = [_]u8{
            0,   1,   2,   3,   125, 126, 127, 128,
            240, 241, 242, 243, 244, 245, 246, 247,
            248, 249, 250, 251, 252, 253, 254, 255,
        };

        const CASES = [_]Case{
            Case{ .input = in01[0..], .expected_output = ex01[0..] },
            Case{ .input = in02[0..], .expected_output = ex02[0..] },
            Case{ .input = in03[0..], .expected_output = ex03[0..] },
            Case{ .input = in04[0..], .expected_output = ex04[0..] },
            Case{ .input = in05[0..], .expected_output = ex05[0..] },
            Case{ .input = in06[0..], .expected_output = ex06[0..] },
            Case{ .input = in07[0..], .expected_output = ex07[0..] },
            Case{ .input = in08[0..], .expected_output = ex08[0..] },
            Case{ .input = in09[0..], .expected_output = ex09[0..] },
            Case{ .input = in10[0..], .expected_output = ex10[0..] },
            Case{ .input = in11[0..], .expected_output = ex11[0..] },
            Case{ .input = in12[0..], .expected_output = ex12[0..] },
            Case{ .input = in13[0..], .expected_output = ex13[0..] },
            Case{ .input = in14[0..], .expected_output = ex14[0..] },
            Case{ .input = in15[0..], .expected_output = ex15[0..] },
            Case{ .input = in16[0..], .expected_output = ex16[0..] },
            Case{ .input = in17[0..], .expected_output = ex17[0..] },
            Case{ .input = in18[0..], .expected_output = ex18[0..] },
            Case{ .input = in19[0..], .expected_output = ex19[0..] },
            Case{ .input = in20[0..], .expected_output = ex20[0..] },
            Case{ .input = in21[0..], .expected_output = ex21[0..] },
            Case{ .input = in22[0..], .expected_output = ex22[0..] },
            Case{ .input = in23[0..], .expected_output = ex23[0..] },
            Case{ .input = in24[0..], .expected_output = ex24[0..] },
            Case{ .input = in25[0..], .expected_output = ex25[0..] },
        };
        const LONGEST_CASE = find: {
            var longest: usize = 0;
            for (CASES[0..]) |case| {
                longest = @max(longest, case.input.len);
            }
            break :find longest;
        };
        const NUM_RANDOM_TESTS: usize = 50;
    };
    const BUF_MAX_LEN: usize = @max(SORT_TEST_CASES.LONGEST_CASE, 50);
    const U8ListWhole = ListNotAllocatedAdvanced(u8, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    // const U8ListSplit = ListNotAllocated(u8, .SPLIT_FIELDS, .SERIAL_INDEXES);
    var rand_impl = Root.Rand.create_new_default_prng_seeded_from_time(Test.io);
    const rand = rand_impl.random();
    const SORT = struct {
        fn u8_less_than_idx_val(list: U8ListWhole, idx_a: u32, val_b: u8, _: void, _: void) bool {
            return list.get(idx_a) < val_b;
        }
        fn u8_greater_than_idx_val(list: U8ListWhole, idx_a: u32, val_b: u8, _: void, _: void) bool {
            return list.get(idx_a) > val_b;
        }
        fn u8_greater_than_idx_idx(list: U8ListWhole, idx_a: u32, idx_b: u32, _: void, _: void) bool {
            return list.get(idx_a) > list.get(idx_b);
        }
        fn u8_equal_idx_val(list: U8ListWhole, idx_a: u32, val_b: u8, _: void, _: void) bool {
            return list.get(idx_a) == val_b;
        }
    };
    {
        var buf_whole: [BUF_MAX_LEN]u8 = undefined;
        var list_whole = U8ListWhole.from_slice_set_empty(buf_whole[0..]);
        // var buf_whole: [BUF_MAX_LEN]u8 = undefined;
        // var list_split = U8ListSplit.from_slice_set_empty(buf[0..]);
        var is_sorted: bool = false;
        for (SORT_TEST_CASES.CASES[0..], 0..) |case, c| {
            list_whole.set_len_unchecked(@intCast(case.input.len));
            const buf_slice = list_whole.zig_slice_entire();
            // Insertion Sort
            @memcpy(buf_slice, case.input);
            list_whole.insertion_sort(SORT.u8_greater_than_idx_val);
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "static case {d} failed on Insertion Sort", .{c + 1});
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort
            @memcpy(buf_slice, case.input);
            list_whole.quicksort(SORT.u8_less_than_idx_val, SORT.u8_greater_than_idx_idx, SORT.u8_greater_than_idx_val, SORT.u8_equal_idx_val);
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "static case {d} failed on Quick Sort", .{c + 1});
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort
            @memcpy(buf_slice, case.input);
            list_whole.heapsort(SORT.u8_greater_than_idx_idx, SORT.u8_greater_than_idx_val);
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "static case {d} failed on on Heap Sort", .{c + 1});
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
        for (0..SORT_TEST_CASES.NUM_RANDOM_TESTS) |_| {
            const buf_len = rand.intRangeAtMost(usize, 2, BUF_MAX_LEN);
            list_whole.set_len_unchecked(@intCast(buf_len));
            const buf_slice = list_whole.zig_slice_entire();
            // Insertion Sort Random
            for (0..buf_len) |i| {
                buf_slice[i] = rand.int(u8);
            }
            list_whole.insertion_sort(SORT.u8_greater_than_idx_val);
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort Random
            for (0..buf_len) |i| {
                buf_slice[i] = rand.int(u8);
            }
            list_whole.quicksort(SORT.u8_less_than_idx_val, SORT.u8_greater_than_idx_idx, SORT.u8_greater_than_idx_val, SORT.u8_equal_idx_val);
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort Random
            for (0..buf_len) |i| {
                buf_slice[i] = rand.int(u8);
            }
            list_whole.heapsort(SORT.u8_greater_than_idx_idx, SORT.u8_greater_than_idx_val);
            is_sorted = list_whole.is_sorted(SORT.u8_greater_than_idx_idx);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
    }
}

test "ListSlice -> copy to" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    var src_buf = [_]u32{ 0, 1, 2, 3, 4, 5 };
    var dst_buf: [8]u32 = @splat(99);
    const src = L.from_slice_keep_data(src_buf[0..]);
    var dst = L.from_slice_keep_data(dst_buf[0..]);

    src.copy_self_range_to_dest_range(1, 4, &dst, 2);
    try expectListEqual(L, dst, &.{ 99, 99, 1, 2, 3, 99, 99, 99 }, @src(), "copy_self_range_to_dest_range", .{});

    dst_buf = @splat(99);
    src.copy_self_range_to_dest_start(1, 4, &dst);
    try expectListEqual(L, dst, &.{ 1, 2, 3, 99, 99, 99, 99, 99 }, @src(), "copy_self_range_to_dest_start", .{});

    dst_buf = @splat(99);
    src.copy_self_range_to_dest_end(1, 4, &dst);
    try expectListEqual(L, dst, &.{ 99, 99, 99, 99, 99, 1, 2, 3 }, @src(), "copy_self_range_to_dest_end", .{});

    dst_buf = @splat(99);
    src.copy_self_start_to_dest_range(3, &dst, 1);
    try expectListEqual(L, dst, &.{ 99, 0, 1, 2, 99, 99, 99, 99 }, @src(), "copy_self_start_to_dest_range", .{});

    dst_buf = @splat(99);
    src.copy_self_start_to_dest_start(3, &dst);
    try expectListEqual(L, dst, &.{ 0, 1, 2, 99, 99, 99, 99, 99 }, @src(), "copy_self_start_to_dest_start", .{});

    dst_buf = @splat(99);
    src.copy_self_start_to_dest_end(3, &dst);
    try expectListEqual(L, dst, &.{ 99, 99, 99, 99, 99, 0, 1, 2 }, @src(), "copy_self_start_to_dest_end", .{});

    dst_buf = @splat(99);
    src.copy_self_end_to_dest_range(2, &dst, 0);
    try expectListEqual(L, dst, &.{ 4, 5, 99, 99, 99, 99, 99, 99 }, @src(), "copy_self_end_to_dest_range", .{});

    dst_buf = @splat(99);
    src.copy_self_end_to_dest_start(2, &dst);
    try expectListEqual(L, dst, &.{ 4, 5, 99, 99, 99, 99, 99, 99 }, @src(), "copy_self_end_to_dest_start", .{});

    dst_buf = @splat(99);
    src.copy_self_end_to_dest_end(2, &dst);
    try expectListEqual(L, dst, &.{ 99, 99, 99, 99, 99, 99, 4, 5 }, @src(), "copy_self_end_to_dest_end", .{});

    dst_buf = @splat(99);
    src.copy_entire_self_to_dest_range(&dst, 2);
    try expectListEqual(L, dst, &.{ 99, 99, 0, 1, 2, 3, 4, 5 }, @src(), "copy_entire_self_to_dest_range", .{});

    dst_buf = @splat(99);
    src.copy_entire_self_to_dest_start(&dst);
    try expectListEqual(L, dst, &.{ 0, 1, 2, 3, 4, 5, 99, 99 }, @src(), "copy_entire_self_to_dest_start", .{});

    dst_buf = @splat(99);
    src.copy_entire_self_to_dest_end(&dst);
    try expectListEqual(L, dst, &.{ 99, 99, 0, 1, 2, 3, 4, 5 }, @src(), "copy_entire_self_to_dest_end", .{});
}

test "ListSlice -> find / binary search / binary insert" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Cmp = struct {
        fn equal(list: L, idx: u32, val: u32, _: void, _: void) bool {
            return list.get(idx) == val;
        }
        fn greater(list: L, idx: u32, val: u32, _: void, _: void) bool {
            return list.get(idx) > val;
        }
        fn less(list: L, idx: u32, val: u32, _: void, _: void) bool {
            return list.get(idx) < val;
        }
    };
    var buf: [8]u32 = undefined;
    var list = L.from_slice_set_empty(buf[0..]);
    const init = [_]u32{ 1, 3, 3, 5, 7 };
    list.set_len_unchecked(@intCast(init.len));
    @memcpy(list.zig_slice_entire(), init[0..]);

    try Test.expect_equal_src(list.find_first_implicit(3), @as(?u32, 1), @src(), "find_first_implicit duplicate", .{});
    try Test.expect_equal_src(list.find_last_implicit(3), @as(?u32, 2), @src(), "find_last_implicit duplicate", .{});
    try Test.expect_equal_src(list.find_first_implicit(9), @as(?u32, null), @src(), "find_first_implicit missing", .{});
    try Test.expect_equal_src(list.find_first_in_range_implicit(3, 2, 5), @as(?u32, 2), @src(), "find_first_in_range_implicit", .{});
    try Test.expect_equal_src(list.find_last_in_range_implicit(3, 0, 2), @as(?u32, 1), @src(), "find_last_in_range_implicit", .{});
    try Test.expect_equal_src(list.find_first(3, Cmp.equal), @as(?u32, 1), @src(), "find_first runtime", .{});
    try Test.expect_equal_src(list.find_last(3, Cmp.equal), @as(?u32, 2), @src(), "find_last runtime", .{});

    try Test.expect_equal_src(list.binary_search_implicit(5), @as(?u32, 3), @src(), "binary_search_implicit", .{});
    try Test.expect_equal_src(list.binary_search_implicit(9), @as(?u32, null), @src(), "binary_search_implicit missing", .{});
    const found_dup = list.binary_search_implicit(3);
    try Test.expect_true_src(found_dup != null and list.get(found_dup.?) == 3, @src(), "binary_search_implicit duplicate", .{});
    try Test.expect_equal_src(list.binary_search(5, Cmp.equal, Cmp.greater), @as(?u32, 3), @src(), "binary_search runtime", .{});

    try Test.expect_equal_src(list.binary_insert_location_implicit(4), 3, @src(), "binary_insert_location_implicit", .{});
    try Test.expect_equal_src(list.binary_insert_location_advanced_left_bias(3, 0, 5, {}, {}, .RUNTIME_FN_PTR, Cmp.less, {}), 1, @src(), "binary_insert_location left bias", .{});
    try Test.expect_equal_src(list.binary_insert_location_advanced_right_bias(3, 0, 5, {}, {}, .RUNTIME_FN_PTR, Cmp.greater, {}), 3, @src(), "binary_insert_location right bias", .{});

    try Test.expect_equal_src(list.binary_insert_implicit_assume_cap(4), 3, @src(), "binary_insert_implicit_assume_cap", .{});
    try expectListEqual(L, list, &.{ 1, 3, 3, 4, 5, 7 }, @src(), "after binary insert", .{});
    try Test.expect_equal_src(list.binary_insert_assume_cap(3, Cmp.greater), 3, @src(), "binary_insert_assume_cap", .{});
    try expectListEqual(L, list, &.{ 1, 3, 3, 3, 4, 5, 7 }, @src(), "after right-biased binary insert", .{});
    try Test.expect_equal_src(list.binary_insert_in_range_implicit_assume_cap(3, 0, 7), 4, @src(), "binary_insert_in_range_implicit_assume_cap", .{});
    try expectListEqual(L, list, &.{ 1, 3, 3, 3, 3, 4, 5, 7 }, @src(), "after left-biased binary insert", .{});

    // The reallocating binary insert variants require an allocated list.
    const LA = ListAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Src = SliceImmutableAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const CmpA = struct {
        fn greater(lst: LA, idx: u32, val: u32, _: void, _: void) bool {
            return lst.get(idx) > val;
        }
        fn less(lst: LA, idx: u32, val: u32, _: void, _: void) bool {
            return lst.get(idx) < val;
        }
    };
    const alloc = std.testing.allocator;
    var alist = LA.allocate_new(8, alloc);
    defer alist.free(alloc);
    const init_src = Src.from_slice_const_keep_data(init[0..]);
    alist.append_many_assume_cap(init_src);
    try Test.expect_equal_src(alist.binary_insert_advanced_right_bias(3, 0, 5, alloc, .GROW_BY_100_PERCENT, {}, {}, .RUNTIME_FN_PTR, CmpA.greater, {}), 3, @src(), "binary_insert_advanced_right_bias", .{});
    try expectListEqual(LA, alist, &.{ 1, 3, 3, 3, 5, 7 }, @src(), "allocated after right-biased binary insert", .{});
    try Test.expect_equal_src(alist.binary_insert_advanced_left_bias(3, 0, 6, alloc, .GROW_BY_100_PERCENT, {}, {}, .RUNTIME_FN_PTR, CmpA.less, {}), 1, @src(), "binary_insert_advanced_left_bias", .{});
    try expectListEqual(LA, alist, &.{ 1, 3, 3, 3, 3, 5, 7 }, @src(), "allocated after left-biased binary insert", .{});
}

test "ListSlice -> allocated and cached alloc" {
    const alloc = std.testing.allocator;
    const L = ListAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    var list = L.allocate_new(2, alloc);
    defer list.free_if_non_zero(alloc);
    try Test.expect_equal_src(list.get_cap(), 2, @src(), "allocated initial cap", .{});
    list.append_one(10, alloc);
    list.append_one(20, alloc);
    try expectListEqual(L, list, &.{ 10, 20 }, @src(), "allocated appends", .{});
    list.append_one(30, alloc);
    try Test.expect_true_src(list.get_cap() >= 3, @src(), "allocated grew", .{});
    try expectListEqual(L, list, &.{ 10, 20, 30 }, @src(), "allocated after growth", .{});
    list.prepend_one(5, alloc);
    list.insert_one(2, 15, alloc);
    try expectListEqual(L, list, &.{ 5, 10, 15, 20, 30 }, @src(), "allocated prepend/insert", .{});

    list.grow(16, .GROW_EXACT_NEEDED, alloc);
    try Test.expect_equal_src(list.get_cap(), 16, @src(), "grow exact", .{});
    list.shrink_capacity_to_at_most(8, alloc);
    try Test.expect_equal_src(list.get_cap(), 8, @src(), "shrink to at most", .{});
    list.shrink_capacity_reserve_at_most_n_free_space(1, alloc);
    try Test.expect_equal_src(list.get_cap(), 6, @src(), "shrink reserve free space", .{});
    try list.grow_capacity_if_needed_for_n_more_elems_might_error(4, .GROW_BY_100_PERCENT, alloc);
    try Test.expect_equal_src(list.get_cap(), 18, @src(), "grow if needed might error", .{});
    try list.resize_capacity_exact_might_error(12, alloc);
    try Test.expect_equal_src(list.get_cap(), 12, @src(), "resize exact might error", .{});
    list.free(alloc);

    const LC = ListFullDefinition(u32, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .CACHED_ALLOCATOR_INTERFACE);
    var cached = LC.allocate_new(2, alloc);
    cached.append_one(1, {});
    cached.append_one(2, {});
    cached.append_one(3, {});
    cached.prepend_one(0, {});
    try expectListEqual(LC, cached, &.{ 0, 1, 2, 3 }, @src(), "cached alloc operations", .{});
    cached.grow(8, .GROW_EXACT_NEEDED, {});
    try Test.expect_equal_src(cached.get_cap(), 8, @src(), "cached grow", .{});
    cached.free({});
}

test "ListSlice -> split fields" {
    const Item = struct {
        a: u32,
        b: u16,
        c: u8,
    };
    const L = ListNotAllocatedAdvanced(Item, .SPLIT_FIELDS, .SERIAL_INDEXES);
    var buf: [6]Item = undefined;
    var list = L.from_slice_set_empty(buf[0..]);
    list.set_len_unchecked(3);
    list.set(0, .{ .a = 1, .b = 2, .c = 3 });
    list.set(1, .{ .a = 4, .b = 5, .c = 6 });
    list.set(2, .{ .a = 7, .b = 8, .c = 9 });
    try expectListEqual(L, list, &.{ Item{ .a = 1, .b = 2, .c = 3 }, Item{ .a = 4, .b = 5, .c = 6 }, Item{ .a = 7, .b = 8, .c = 9 } }, @src(), "split fields set/get", .{});

    try Test.expect_equal_src(list.get_field(.a, 1), 4, @src(), "split get_field a", .{});
    try Test.expect_equal_src(list.get_field(.b, 2), 8, @src(), "split get_field b", .{});
    list.set_field(.c, 0, 30);
    try Test.expect_equal_src(list.get_field(.c, 0), 30, @src(), "split set_field c", .{});
    list.get_field_ptr(.a, 1).* = 40;
    try Test.expect_equal_src(list.get_field(.a, 1), 40, @src(), "split get_field_ptr a", .{});

    try Test.expect_slices_equal_t_src(u32, &.{ 1, 40, 7 }, list.get_field_zig_slice(.a), @src(), "split field zig slice a", .{});
    try Test.expect_slices_equal_t_src(u16, &.{ 2, 5, 8 }, list.get_field_zig_slice_const(.b), @src(), "split field zig slice const b", .{});
    try Test.expect_equal_src(list.get_field_many_item_ptr(.c, 1)[0], 6, @src(), "split field many item ptr", .{});
    try Test.expect_equal_src(list.get_field_many_item_ptr_const(.c, 2)[0], 9, @src(), "split field many item ptr const", .{});

    list.memset_field_len(.c, 0xAB);
    try Test.expect_slices_equal_t_src(u8, &.{ 0xAB, 0xAB, 0xAB }, list.get_field_zig_slice_const(.c), @src(), "split memset_field_len", .{});
    list.set_len_to_cap();
    list.memset_field_cap(.b, 0x1234);
    try Test.expect_slices_equal_t_src(u16, &.{ 0x1234, 0x1234, 0x1234, 0x1234, 0x1234, 0x1234 }, list.get_field_zig_slice_const(.b), @src(), "split memset_field_cap", .{});

    const alloc = std.testing.allocator;
    const LA = ListAllocatedAdvanced(Item, .SPLIT_FIELDS, .SERIAL_INDEXES);
    var alist = LA.allocate_new(2, alloc);
    defer alist.free(alloc);
    alist.append_one(.{ .a = 10, .b = 11, .c = 12 }, alloc);
    alist.append_one(.{ .a = 20, .b = 21, .c = 22 }, alloc);
    alist.append_one(.{ .a = 30, .b = 31, .c = 32 }, alloc);
    try expectListEqual(LA, alist, &.{ Item{ .a = 10, .b = 11, .c = 12 }, Item{ .a = 20, .b = 21, .c = 22 }, Item{ .a = 30, .b = 31, .c = 32 } }, @src(), "split fields allocated realloc", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 10, 20, 30 }, alist.get_field_zig_slice_const(.a), @src(), "split fields allocated field slice", .{});
}

test "ListSlice -> filtered deletes" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const F = struct {
        fn isEven(list: L, idx: u32, _: void, _: void) bool {
            return list.get(idx) % 2 == 0;
        }
        fn isOdd(list: L, idx: u32, _: void, _: void) bool {
            return list.get(idx) % 2 == 1;
        }
    };

    var arr = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    var list = L.from_slice_keep_data(arr[0..]);
    try Test.expect_equal_src(list.delete_filtered({}, {}, .RUNTIME_FN_PTR, F.isEven, {}), 4, @src(), "delete_filtered count", .{});
    try expectListEqual(L, list, &.{ 1, 3, 5, 7 }, @src(), "delete_filtered list", .{});

    var dest_buf: [8]u32 = undefined;
    var dest = L.from_slice_set_empty(dest_buf[0..]);
    arr = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    list = L.from_slice_keep_data(arr[0..]);
    try Test.expect_equal_src(list.remove_filtered_assume_dest_cap(&dest, {}, {}, .RUNTIME_FN_PTR, F.isEven, {}), 4, @src(), "remove_filtered_assume_dest_cap count", .{});
    try expectListEqual(L, list, &.{ 1, 3, 5, 7 }, @src(), "remove_filtered_assume_dest_cap list", .{});
    try expectListEqual(L, dest, &.{ 0, 2, 4, 6 }, @src(), "remove_filtered_assume_dest_cap dest", .{});

    const LD = ListAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const alloc_dest = std.testing.allocator;
    var allocated_dest = LD.allocate_new(8, alloc_dest);
    defer allocated_dest.free(alloc_dest);
    arr = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    list = L.from_slice_keep_data(arr[0..]);
    try Test.expect_equal_src(list.remove_filtered(&allocated_dest, .PASSED_ALLOCATOR_INTERFACE, alloc_dest, .GROW_EXACT_NEEDED, {}, {}, .RUNTIME_FN_PTR, F.isEven, {}), 4, @src(), "remove_filtered count", .{});
    try expectListEqual(L, list, &.{ 1, 3, 5, 7 }, @src(), "remove_filtered list", .{});
    try expectListEqual(LD, allocated_dest, &.{ 0, 2, 4, 6 }, @src(), "remove_filtered dest", .{});

    arr = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    list = L.from_slice_keep_data(arr[0..]);
    try Test.expect_equal_src(list.swap_delete_filtered({}, {}, .RUNTIME_FN_PTR, F.isEven, {}), 4, @src(), "swap_delete_filtered count", .{});
    try Test.expect_equal_src(list.get_len(), 4, @src(), "swap_delete_filtered len", .{});
    for (0..4) |i| {
        try Test.expect_equal_src(list.get(@intCast(i)) % 2, 1, @src(), "swap_delete_filtered kept odd", .{});
    }

    dest.clear();
    arr = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7 };
    list = L.from_slice_keep_data(arr[0..]);
    try Test.expect_equal_src(list.swap_remove_filtered_assume_dest_cap(&dest, {}, {}, .RUNTIME_FN_PTR, F.isEven, {}), 4, @src(), "swap_remove_filtered_assume_dest_cap count", .{});
    try Test.expect_equal_src(dest.get_len(), 4, @src(), "swap_remove_filtered_assume_dest_cap dest len", .{});
    for (0..4) |i| {
        try Test.expect_equal_src(dest.get(@intCast(i)) % 2, 0, @src(), "swap_remove_filtered_assume_dest_cap dest even", .{});
    }
}

test "ListSlice -> for_each" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const Ctx = struct {
        order: [8]u32 = undefined,
        len: usize = 0,
    };
    const F = struct {
        fn record(list: L, idx: u32, ctx: *Ctx, _: void) void {
            ctx.order[ctx.len] = list.get(idx);
            ctx.len += 1;
        }
        fn addToSum(list: L, idx: u32, ctx: *u32, _: void) void {
            ctx.* += list.get(idx);
        }
        fn isOddCtx(list: L, idx: u32, _: *Ctx, _: void) bool {
            return list.get(idx) % 2 == 1;
        }
        fn isEvenCtx(list: L, idx: u32, _: *Ctx, _: void) bool {
            return list.get(idx) % 2 == 0;
        }
    };
    var arr = [_]u32{ 0, 1, 2, 3, 4, 5 };
    var list = L.from_slice_keep_data(arr[0..]);
    var ctx = Ctx{};

    var sum: u32 = 0;
    try Test.expect_equal_src(list.for_each_with_context(16, &sum, F.addToSum), 6, @src(), "for_each count", .{});
    try Test.expect_equal_src(sum, 15, @src(), "for_each sum", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_with_context(2, &ctx, F.record), 2, @src(), "for_each max_count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 0, 1 }, ctx.order[0..ctx.len], @src(), "for_each max_count order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_in_range_with_context(1, 4, 10, &ctx, F.record), 3, @src(), "for_each_in_range count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 1, 2, 3 }, ctx.order[0..ctx.len], @src(), "for_each_in_range order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_reverse_with_context(3, &ctx, F.record), 3, @src(), "for_each_reverse count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 5, 4, 3 }, ctx.order[0..ctx.len], @src(), "for_each_reverse order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_in_range_reverse_with_context(3, 0, 10, &ctx, F.record), 3, @src(), "for_each_in_range_reverse count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 3, 2, 1 }, ctx.order[0..ctx.len], @src(), "for_each_in_range_reverse order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_filtered_with_context(10, &ctx, F.record, F.isOddCtx), 3, @src(), "for_each_filtered count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 1, 3, 5 }, ctx.order[0..ctx.len], @src(), "for_each_filtered order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_filtered_reverse_with_context(10, &ctx, F.record, F.isOddCtx), 3, @src(), "for_each_filtered_reverse count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 5, 3, 1 }, ctx.order[0..ctx.len], @src(), "for_each_filtered_reverse order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_in_range_filtered_with_context(0, 6, 10, &ctx, F.record, F.isEvenCtx), 3, @src(), "for_each_in_range_filtered count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 0, 2, 4 }, ctx.order[0..ctx.len], @src(), "for_each_in_range_filtered order", .{});

    ctx.len = 0;
    try Test.expect_equal_src(list.for_each_in_range_filtered_reverse_with_context(5, 1, 10, &ctx, F.record, F.isEvenCtx), 2, @src(), "for_each_in_range_filtered_reverse count", .{});
    try Test.expect_slices_equal_t_src(u32, &.{ 4, 2 }, ctx.order[0..ctx.len], @src(), "for_each_in_range_filtered_reverse order", .{});
}

test "ListSlice -> flat tree and pointer helpers" {
    const L = ListNotAllocatedAdvanced(u32, .WHOLE_STRUCTS, .SERIAL_INDEXES);

    var tree_buf = [_]u32{ 0, 1, 2, 3, 4, 5, 6 };
    var tree = L.from_slice_keep_data(tree_buf[0..]);
    try Test.expect_equal_src(tree.root_tree__parent_idx_unchecked(1, 2), 0, @src(), "root parent unchecked 1", .{});
    try Test.expect_equal_src(tree.root_tree__parent_idx_unchecked(4, 2), 1, @src(), "root parent unchecked 4", .{});
    try Test.expect_equal_src(tree.root_tree__parent_idx_if_exists(0, 2), @as(?u32, null), @src(), "root parent null", .{});
    try Test.expect_equal_src(tree.root_tree__parent_idx_if_exists(6, 2), @as(?u32, 2), @src(), "root parent exists", .{});
    try Test.expect_equal_src(tree.root_tree__nth_child_idx_unchecked(1, 2, 0), 3, @src(), "root nth child unchecked", .{});
    try Test.expect_equal_src(tree.root_tree__nth_child_idx_if_exists(2, 2, 1), @as(?u32, 6), @src(), "root nth child exists", .{});
    try Test.expect_equal_src(tree.root_tree__nth_child_idx_if_exists(2, 2, 0), @as(?u32, 5), @src(), "root nth child exists 2", .{});
    try Test.expect_equal_src(tree.root_tree__first_child_idx_unchecked(0, 2), 1, @src(), "root first child", .{});
    try Test.expect_equal_src(tree.root_tree__last_child_idx_unchecked(0, 2), 2, @src(), "root last child", .{});
    try Test.expect_equal_src(tree.root_tree__first_child_idx_if_exists(1, 2), @as(?u32, 3), @src(), "root first child exists", .{});
    try Test.expect_equal_src(tree.root_tree__last_child_idx_if_exists(1, 2), @as(?u32, 4), @src(), "root last child exists", .{});

    var slice = tree.slice(2, 7); // local indices 0..4 correspond to root indices 2..6
    try Test.expect_equal_src(slice.local_tree__parent_idx_unchecked(1, 2), 0, @src(), "local parent unchecked 1", .{});
    try Test.expect_equal_src(slice.local_tree__parent_idx_unchecked(4, 2), 1, @src(), "local parent unchecked 4", .{});
    try Test.expect_equal_src(slice.local_tree__parent_idx_if_exists(0, 2), @as(?u32, null), @src(), "local parent null", .{});
    try Test.expect_equal_src(slice.local_tree__parent_idx_if_exists(3, 2), @as(?u32, 1), @src(), "local parent exists", .{});
    try Test.expect_equal_src(slice.local_tree__nth_child_idx_unchecked(0, 2, 1), 2, @src(), "local nth child unchecked", .{});
    try Test.expect_equal_src(slice.local_tree__nth_child_idx_if_exists(1, 2, 1), @as(?u32, 4), @src(), "local nth child exists", .{});
    try Test.expect_equal_src(slice.local_tree__nth_child_idx_if_exists(2, 2, 0), @as(?u32, null), @src(), "local nth child null", .{});
    try Test.expect_equal_src(slice.local_tree__first_child_idx_unchecked(1, 2), 3, @src(), "local first child", .{});
    try Test.expect_equal_src(slice.local_tree__last_child_idx_unchecked(1, 2), 4, @src(), "local last child", .{});
    try Test.expect_equal_src(slice.local_tree__first_child_idx_if_exists(1, 2), @as(?u32, 3), @src(), "local first child exists", .{});
    try Test.expect_equal_src(slice.local_tree__last_child_idx_if_exists(2, 2), @as(?u32, null), @src(), "local last child null", .{});

    var buf = [_]u32{ 10, 20, 30, 40 };
    var list = L.from_slice_keep_data(buf[0..]);
    const p = list.get_many_item_ptr(1);
    try Test.expect_equal_src(p[0], 20, @src(), "many ptr", .{});
    try Test.expect_equal_src(p[2], 40, @src(), "many ptr offset", .{});
    try Test.expect_equal_src(L.incr_many_item_pointer(p, 2)[0], 40, @src(), "incr many ptr", .{});
    try Test.expect_equal_src(L.decr_many_item_pointer(p, 1)[0], 10, @src(), "decr many ptr", .{});
    try Test.expect_equal_src(L.move_many_item_pointer(p, 2)[0], 40, @src(), "move many ptr forward", .{});
    try Test.expect_equal_src(L.move_many_item_pointer(p, -1)[0], 10, @src(), "move many ptr back", .{});

    const pc = list.get_many_item_ptr_const(1);
    try Test.expect_equal_src(pc[0], 20, @src(), "many ptr const", .{});
    try Test.expect_equal_src(L.incr_many_item_pointer_const(pc, 2)[0], 40, @src(), "incr many ptr const", .{});
    try Test.expect_equal_src(L.decr_many_item_pointer_const(pc, 1)[0], 10, @src(), "decr many ptr const", .{});
    try Test.expect_equal_src(L.move_many_item_pointer_const(pc, 2)[0], 40, @src(), "move many ptr const forward", .{});
    try Test.expect_equal_src(L.move_many_item_pointer_const(pc, -1)[0], 10, @src(), "move many ptr const back", .{});

    try Test.expect_equal_src(L.cast_many_item_ptr_to_ptr(L.incr_many_item_pointer(p, 1)).*, 30, @src(), "cast many to one", .{});
    try Test.expect_equal_src(L.cast_many_item_ptr_to_ptr_const(pc).*, 20, @src(), "cast many to one const", .{});
    try Test.expect_equal_src(L.cast_ptr_to_many_item_ptr(list.get_ptr(2))[0], 30, @src(), "cast one to many", .{});
    try Test.expect_equal_src(L.cast_ptr_to_many_item_ptr_const(list.get_ptr_const(2))[0], 30, @src(), "cast one const to many", .{});
}
