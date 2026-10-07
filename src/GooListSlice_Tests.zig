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
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
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

const GooListSliceModule = Root.GooListSlice;
const ListNotAllocatedAdvanced = GooListSliceModule.ListNotAllocatedAdvanced;
const ListAllocatedAdvanced = GooListSliceModule.ListAllocatedAdvanced;
const SliceMutableAdvanced = GooListSliceModule.SliceMutableAdvanced;
const SliceImmutableAdvanced = GooListSliceModule.SliceImmutableAdvanced;
const ListFullDefinition = GooListSliceModule.ListFullDefinition;

test "GooListSlice -> Traverser" {
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
    const TravList = ListFullDefinition(Node, u8, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_NOT_ALLOCATED);
    const TravListDual = ListFullDefinition(NodeDual, u8, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_NOT_ALLOCATED);
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
    try trav.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, null, .RUNTIME_FN_PTR, PROTO.act_rt, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav.do_action_on_all_nodes(.PARENTS_FIRST, .all_child_paths(), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabchdef", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, null, .COMPTIME_FN_BODY, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .all_child_paths(), I, &out, void{}, null, .RUNTIME_FN_PTR, PROTO.act_dual_rt, void{});
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcABCgdefDEFhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .all_child_paths(), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "igabcABChdefDEF", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .only_child_paths(&.{.first_child_lower}), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .exclude_child_paths(&.{.first_child_lower}), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.PARENTS_FIRST, .only_child_paths(&.{.first_child_upper}), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "i", "expected", "", .{});
    out.idx = 0;
    try trav_dual.do_action_on_all_nodes(.CHILDREN_FIRST, .exclude_child_paths(&.{.first_child_upper}), I, &out, void{}, null, .COMPTIME_FN_PTR, void{}, PROTO.act_dual);
    try Test.expect_strings_equal(out.buf[0..out.idx], "result", "abcgdefhi", "expected", "", .{});
    out.idx = 0;
}

test "GooListSlice -> median_of_3_indexes" {
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

test "GooListSlice -> sorting algorithms" {
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
