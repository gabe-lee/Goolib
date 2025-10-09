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
const Root = @import("./_root.zig");
const opts = @import("opts");
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fmt = std.fmt;

const SliceAdapter = Root.IList_SliceAdapter.SliceAdapter;
const ArrayListAdapter = Root.IList_ArrayListAdapter.ArrayListAdapter;
const Assert = Root.Assert;
const Types = Root.Types;
const IList = Root.IList;
const Fuzz = Root.Fuzz;
const Utils = Root.Utils;

const LARGEST_LEN: usize = 1024;
const SMALL_LEN: usize = 256;
const LARGEST_COPY: usize = 128;

pub const SLICE_ADAPTER_U8_ALLOC = make_slice_adapter_alloc_test(u8);
pub const SLICE_ADAPTER_U8_NO_ALLOC = make_slice_adapter_test(u8);
pub const ARRAY_LIST_ADAPTER_U8 = make_array_list_adapter_test(u8);

pub fn make_slice_adapter_alloc_test(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        const T_IList = Root.IList.IList(T);
        const T_List = std.ArrayList(T);
        const STATE = struct {
            ref_list: T_List,
            test_list: T_IList,
            slice_adapter: SliceAdapter(T).AdapterWithAlloc,
        };
        pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
            var state = try alloc.create(STATE);
            state.ref_list = try T_List.initCapacity(alloc, LARGEST_LEN);
            var s: []T = undefined;
            s.len = 0;
            state.slice_adapter = SliceAdapter(T).adapt_with_alloc(s, alloc);
            state.test_list = state.slice_adapter.interface();
            state_opaque.* = @ptrCast(state);
        }
        pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = rand.uintLessThan(usize, SMALL_LEN);
            state.ref_list.clearRetainingCapacity();
            if (alloc.remap(state.slice_adapter.slice, len)) |new| {
                state.slice_adapter.slice = new;
            } else {
                alloc.free(state.slice_adapter.slice);
                state.slice_adapter.slice = alloc.alloc(u8, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            }
            state.ref_list.ensureTotalCapacity(alloc, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            state.ref_list.items.len = len;
            if (len > 0) {
                rand.bytes(state.ref_list.items);
                @memcpy(state.slice_adapter.slice[0..len], state.ref_list.items[0..len]);
            }
            return _OPS.verify_whole_state(state, "start_seed", 0, 0, 0, alloc);
        }

        pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearAndFree(alloc);
            alloc.free(state.slice_adapter.slice);
            alloc.destroy(state);
        }

        const _OPS = make_op_table(T, STATE, 0, true, false);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "IList_SliceAdapter_alloc_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}
pub fn make_slice_adapter_test(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        const T_IList = Root.IList.IList(T);
        const T_List = std.ArrayList(T);
        const STATE = struct {
            ref_list: T_List,
            test_list: T_IList,
            slice_arr: [SMALL_LEN]u8 = @splat(0),
            slice_adapter: SliceAdapter(T).Adapter,
            last_op: usize = math.maxInt(usize),
            this_op: usize = math.maxInt(usize),
        };
        pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
            var state = try alloc.create(STATE);
            state.ref_list = try T_List.initCapacity(alloc, SMALL_LEN);
            state.slice_adapter = SliceAdapter(T).adapt(state.slice_arr[0..SMALL_LEN]);
            state.test_list = state.slice_adapter.interface();
            state_opaque.* = @ptrCast(state);
        }
        pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.items.len = SMALL_LEN;
            state.slice_adapter.slice.len = SMALL_LEN;
            rand.bytes(state.ref_list.items);
            @memcpy(state.slice_adapter.slice[0..SMALL_LEN], state.ref_list.items[0..SMALL_LEN]);
            return _OPS.verify_whole_state(state, "start_seed", 0, 0, 0, alloc);
        }

        pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearAndFree(alloc);
            alloc.destroy(state);
        }
        const _OPS = make_op_table(T, STATE, 0, false, false);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "IList_SliceAdapter_no_alloc_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}
pub fn make_array_list_adapter_test(comptime T: type) Fuzz.FuzzTest {
    const PROTO = struct {
        const T_IList = Root.IList.IList(T);
        const T_List = std.ArrayList(T);
        const STATE = struct {
            ref_list: T_List,
            test_list: T_IList,
            list_adapter: ArrayListAdapter(T).Adapter,
        };
        pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
            var state = try alloc.create(STATE);
            state.ref_list = try T_List.initCapacity(alloc, LARGEST_LEN);
            const l = try ArrayList(T).initCapacity(alloc, LARGEST_LEN);
            state.list_adapter = ArrayListAdapter(T).adapt(l, alloc);
            state.test_list = state.list_adapter.interface();
            state_opaque.* = @ptrCast(state);
        }
        pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            var state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = rand.uintLessThan(usize, SMALL_LEN);
            state.ref_list.clearRetainingCapacity();
            state.list_adapter.list.clearRetainingCapacity();
            state.ref_list.ensureTotalCapacity(alloc, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            state.list_adapter.list.ensureTotalCapacity(alloc, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            state.ref_list.items.len = len;
            state.list_adapter.list.items.len = len;
            if (len > 0) {
                rand.bytes(state.ref_list.items);
                @memcpy(state.list_adapter.list.items[0..len], state.ref_list.items[0..len]);
            }
            return _OPS.verify_whole_state(state, "start_seed", 0, 0, 0, alloc);
        }

        pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearAndFree(alloc);
            state.list_adapter.list.clearAndFree(alloc);
            alloc.destroy(state);
        }

        const _OPS = make_op_table(T, STATE, 0, true, false);
        pub const OPS = _OPS.OPS;
    };
    return Fuzz.FuzzTest{
        .options = Fuzz.FuzzOptions{
            .name = "IList_ArrayListAdapter_" ++ @typeName(T),
        },
        .init_func = PROTO.INIT,
        .start_seed_func = PROTO.START_SEED,
        .op_table = PROTO.OPS[0..],
        .deinit_func = PROTO.DEINIT,
    };
}

pub fn make_op_table(comptime T: type, comptime STATE: type, comptime UNINIT: T, comptime LIST_LIKE: bool, comptime QUEUE_LIKE: bool) type {
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "ref_list", std.ArrayList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `ref_list` that is of type `ArrayList({s})`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "test_list", IList.IList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `test_list` that is of type `IList({s})`", .{@typeName(T)});
    return struct {
        fn val_mismatch(state: *STATE, comptime src: std.builtin.SourceLocation, comptime op_name: []const u8, alloc: Allocator, comptime context: []const u8, curr_n: usize, curr_idx: usize, param_1: usize, param_2: usize, param_3: usize) []const u8 {
            return Utils.alloc_fail_str(alloc, src, op_name ++ "({d}, {d}, {d}): mismatched values " ++ context ++ ":\nN={d}, IDX={d}, LEN={d}\nIDX:{d} {d} {d} {d} {d}\nREF:{any} {any} {any} {any} {any}\nTES:{any} {any} {any} {any} {any}\nIDX:{d} {d} {d} {d} {d}\n", .{
                param_1,
                param_2,
                param_3,
                curr_n,
                curr_idx,
                state.ref_list.items.len,
                @as(isize, @intCast(curr_n)) - 2,
                @as(isize, @intCast(curr_n)) - 1,
                curr_n,
                curr_n + 1,
                curr_n + 2,
                if (curr_n < 2) UNINIT else state.ref_list.items[curr_n - 2],
                if (curr_n < 1) UNINIT else state.ref_list.items[curr_n - 1],
                state.ref_list.items[curr_n],
                if (curr_n > state.ref_list.items.len - 2) UNINIT else state.ref_list.items[curr_n + 1],
                if (curr_n > state.ref_list.items.len - 3) UNINIT else state.ref_list.items[curr_n + 2],
                if (curr_n < 2) UNINIT else state.test_list.get(state.test_list.nth_prev_idx(curr_idx, 2)),
                if (curr_n < 1) UNINIT else state.test_list.get(state.test_list.nth_prev_idx(curr_idx, 1)),
                state.test_list.get(curr_idx),
                if (curr_n > state.ref_list.items.len - 2) UNINIT else state.test_list.get(state.test_list.nth_next_idx(curr_idx, 1)),
                if (curr_n > state.ref_list.items.len - 3) UNINIT else state.test_list.get(state.test_list.nth_next_idx(curr_idx, 2)),
                state.test_list.nth_prev_idx(curr_idx, 2),
                state.test_list.nth_prev_idx(curr_idx, 1),
                curr_idx,
                state.test_list.nth_next_idx(curr_idx, 1),
                state.test_list.nth_next_idx(curr_idx, 2),
            });
        }
        fn verify_whole_state(state: *STATE, comptime op_name: []const u8, param_1: usize, param_2: usize, param_3: usize, alloc: Allocator) ?[]const u8 {
            if (state.ref_list.items.len != state.test_list.len()) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": ref len != test len ({d} != {d})", .{ state.ref_list.items.len, state.test_list.len() });
            if (state.test_list.cap() < state.test_list.len()) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": cap < len ({d} < {d})", .{ state.test_list.cap(), state.test_list.len() });
            if (state.ref_list.items.len == 0) {
                if (state.test_list.idx_valid(state.test_list.first_idx())) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": list is empty, but first idx ({d}) was `valid`", .{state.test_list.first_idx()});
                if (state.test_list.idx_valid(state.test_list.last_idx())) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": list is empty, but last idx ({d}) was `valid`", .{state.test_list.last_idx()});
            } else {
                if (!state.test_list.idx_valid(state.test_list.first_idx())) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": list is not empty, but first idx ({d}) was `invalid`", .{state.test_list.first_idx()});
                if (!state.test_list.idx_valid(state.test_list.last_idx())) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": list is not empty, but last idx ({d}) was `invalid`", .{state.test_list.last_idx()});
            }
            var curr_idx = state.test_list.first_idx();
            var curr_n: usize = 0;
            while (curr_n < state.ref_list.items.len) {
                if (!state.test_list.idx_valid(curr_idx)) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": found invalid idx in middle of list while traversing forward: N={d}, IDX={d}, LEN = {d}", .{ curr_n, curr_idx, state.ref_list.items.len });
                const exp_val = state.ref_list.items[curr_n];
                const got_val = state.test_list.get(curr_idx);
                if (exp_val != got_val) return val_mismatch(state, @src(), op_name, alloc, "traversing forward", curr_n, curr_idx, param_1, param_2, param_3);
                curr_n = curr_n + 1;
                curr_idx = state.test_list.next_idx(curr_idx);
            }
            if (state.test_list.idx_valid(curr_idx)) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": found `valid` idx beyond the end of the list while traversing forward: N={d}, IDX={d}, LEN = {d}", .{ curr_n, curr_idx, state.ref_list.items.len });
            curr_idx = state.test_list.last_idx();
            while (curr_n > 0) {
                curr_n = curr_n - 1;
                if (!state.test_list.idx_valid(curr_idx)) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": found invalid idx in middle of list while traversing backward: N={d}, IDX={d}, LEN = {d}", .{ curr_n, curr_idx, state.ref_list.items.len });
                const exp_val = state.ref_list.items[curr_n];
                const got_val = state.test_list.get(curr_idx);
                if (exp_val != got_val) return val_mismatch(state, @src(), op_name, alloc, "traversing backward", curr_n, curr_idx, param_1, param_2, param_3);
                curr_idx = state.test_list.prev_idx(curr_idx);
            }
            if (state.test_list.idx_valid(curr_idx)) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": found `valid` idx before the start of the list while traversing backward: N={d}, IDX={d}, LEN = {d}", .{ curr_n, curr_idx, state.ref_list.items.len });
            curr_idx = state.test_list.first_idx();
            curr_n = 0;
            if (state.test_list.idx_valid(state.test_list.vtable.always_invalid_idx)) return Utils.alloc_fail_str(alloc, @src(), op_name ++ ": `always invalid` index reported as valid ({d})", .{state.test_list.vtable.always_invalid_idx});
            return null;
        }

        fn get_nth(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const exp_val = state.ref_list.items[n];
            const got_val = state.test_list.get(idx);
            if (exp_val != got_val) return val_mismatch(state, @src(), "get_nth", alloc, "at nth position", n, idx, idx, 0, 0);
            return verify_whole_state(state, "get_nth", idx, 0, 0, alloc);
        }
        fn get_nth_ptr(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const exp_val = state.ref_list.items[n];
            const got_ptr = state.test_list.get_ptr(idx);
            const got_val = got_ptr.*;
            if (exp_val != got_val) return val_mismatch(state, @src(), "get_nth_ptr", alloc, "at nth position", n, idx, idx, 0, 0);
            got_ptr.* = UNINIT;
            const got_val_2 = state.test_list.get(idx);
            if (got_val_2 != UNINIT) return Utils.alloc_fail_str(alloc, @src(), "get_nth_ptr(): setting value to pointer didn't affect value returned by get(): N={d}, IDX={d}, SET={any}, GOT={any}", .{ n, idx, UNINIT, got_val_2 });
            got_ptr.* = exp_val;
            const got_val_3 = state.test_list.get(idx);
            if (got_val_3 != exp_val) return Utils.alloc_fail_str(alloc, @src(), "get_nth_ptr(): setting value to pointer didn't affect value returned by get(): N={d}, IDX={d}, SET={any}, GOT={any}", .{ n, idx, exp_val, got_val_3 });
            return verify_whole_state(state, "get_nth_ptr", idx, 0, 0, alloc);
        }
        fn set_nth(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            var b: [1]u8 = undefined;
            rand.bytes(b[0..1]);
            const idx = state.test_list.nth_idx(n);
            state.ref_list.items[n] = b[0];
            state.test_list.set(idx, b[0]);
            return verify_whole_state(state, "set_nth", idx, @intCast(b[0]), 0, alloc);
        }
        fn check_nth_idx(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const n = rand.uintLessThan(usize, 1 + (state.ref_list.items.len * 2));
            const idx_1 = state.test_list.nth_idx(n);
            const idx_2 = state.test_list.nth_idx_from_end(n);
            if (n >= state.ref_list.items.len) {
                if (state.test_list.idx_valid(idx_1)) return Utils.alloc_fail_str(alloc, @src(), "check_nth_idx(): valid idx beyond list end: N={d}, IDX={d}, LEN={d}", .{ n, idx_1, state.ref_list.items.len });
                if (state.test_list.idx_valid(idx_2)) return Utils.alloc_fail_str(alloc, @src(), "check_nth_idx(): valid idx before list start: N={d}, IDX={d}, LEN={d}", .{ @as(isize, @intCast(state.ref_list.items.len)) - 1 - @as(isize, @intCast(n)), idx_2, state.ref_list.items.len });
            } else {
                if (!state.test_list.idx_valid(idx_1)) return Utils.alloc_fail_str(alloc, @src(), "check_nth_idx(): invalid nth idx from start of list: N={d}, IDX={d}, LEN={d}", .{ n, idx_1, state.ref_list.items.len });
                if (!state.test_list.idx_valid(idx_2)) return Utils.alloc_fail_str(alloc, @src(), "check_nth_idx(): invalid nth idx from end of list: N={d}, N_REAL={d} IDX={d}, LEN={d}", .{ n, state.ref_list.items.len - 1 - n, idx_1, state.ref_list.items.len });
            }
            return verify_whole_state(state, "check_nth_idx", idx_1, idx_2, 0, alloc);
        }
        pub fn idx_range_valid(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const n1 = rand.uintAtMost(usize, state.ref_list.items.len * 2);
            const n2 = rand.uintAtMost(usize, state.ref_list.items.len * 2);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            if (n1 >= state.ref_list.items.len and state.test_list.idx_valid(idx_1)) {
                return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): valid idx beyond list end: N={d}, IDX={d}, LEN={d}", .{ n1, idx_1, state.ref_list.items.len });
            } else if (n1 < state.ref_list.items.len and !state.test_list.idx_valid(idx_1)) {
                return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): invalid idx within list: N={d}, IDX={d}, LEN={d}", .{ n1, idx_1, state.ref_list.items.len });
            }
            if (n2 >= state.ref_list.items.len and state.test_list.idx_valid(idx_2)) {
                return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): valid idx beyond list end: N={d}, IDX={d}, LEN={d}", .{ n2, idx_2, state.ref_list.items.len });
            } else if (n2 < state.ref_list.items.len and !state.test_list.idx_valid(idx_2)) {
                return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): invalid idx within list: N={d}, IDX={d}, LEN={d}", .{ n2, idx_2, state.ref_list.items.len });
            }
            if (n1 > n2 or n1 >= state.ref_list.items.len or n2 >= state.ref_list.items.len) {
                if (state.test_list.range_valid(.new_range(idx_1, idx_2))) return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): invalid range reported valid: N1={d}, N2={d} IDX1={d}, IDX2={d} LEN={d}", .{ n1, n2, idx_1, idx_2, state.ref_list.items.len });
            } else if (n1 <= n2 and n1 < state.ref_list.items.len and n2 < state.ref_list.items.len) {
                if (!state.test_list.range_valid(.new_range(idx_1, idx_2))) return Utils.alloc_fail_str(alloc, @src(), "idx_range_valid(): valid range reported invalid: N1={d}, N2={d} IDX1={d}, IDX2={d} LEN={d}", .{ n1, n2, idx_1, idx_2, state.ref_list.items.len });
            }
            return verify_whole_state(state, "idx_range_valid", idx_1, idx_2, 0, alloc);
        }
        pub fn split_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_3: usize = state.test_list.nth_idx(n2);
            const idx_2: usize = state.test_list.split_range(.new_range(idx_1, idx_3));
            var idx_x = idx_1;
            while (true) {
                if (idx_x == idx_2) break;
                if (idx_x == idx_3) return Utils.alloc_fail_str(alloc, @src(), "split_range(): returned index wasnt between ends (reached last_idx before finding middle_idx): N1={d}, N2=??, N3={d} IDX1={d}, IDX2={d}, IDX3={d}, LEN={d}", .{ n1, n2, idx_1, idx_2, idx_3, state.ref_list.items.len });
                idx_x = state.test_list.next_idx(idx_x);
                if (!state.test_list.idx_valid(idx_x)) return Utils.alloc_fail_str(alloc, @src(), "split_range(): returned index wasnt between ends (reached invalid idx before finding middle_idx or last_idx): N1={d}, N2=??, N3={d} IDX1={d}, IDX2={d}, IDX3={d}, LEN={d}", .{ n1, n2, idx_1, idx_2, idx_3, state.ref_list.items.len });
            }
            return verify_whole_state(state, "split_range", idx_1, idx_3, 0, alloc);
        }
        pub fn move(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            const n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            Utils.slice_move_one(state.ref_list.items, n1, n2);
            state.test_list.move(idx_1, idx_2);
            return verify_whole_state(state, "move", idx_1, idx_2, 0, alloc);
        }
        pub fn move_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);

            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const delta = n2 - n1;
            const n3 = rand.uintLessThan(usize, state.ref_list.items.len - delta);
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            const idx_3: usize = state.test_list.nth_idx(n3);
            Utils.slice_move_many(state.ref_list.items, n1, n2, n3);
            state.test_list.move_range(.new_range(idx_1, idx_2), idx_3);
            return verify_whole_state(state, "move_range", idx_1, idx_2, idx_3, alloc);
        }
        pub fn range_len(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            const rlen = state.test_list.range_len(.new_range(idx_1, idx_2));
            if (rlen != ((n2 - n1) + 1)) return Utils.alloc_fail_str(alloc, @src(), "range_len(): returned len  was incorrect got_len({d}) != exp_len({d}) ((({d} - {d}) + 1)))", .{ rlen, ((n2 - n1) + 1), n2, n1 });
            return verify_whole_state(state, "range_len", idx_1, idx_2, 0, alloc);
        }
        pub fn ensure_free_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const count = @min(@max(1, rand.uintLessThan(usize, LARGEST_COPY)), LARGEST_LEN - state.ref_list.items.len);
            if (count == 0) return null;
            state.ref_list.ensureUnusedCapacity(alloc, count) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            const did_ensure = state.test_list.try_ensure_free_slots(count);
            if (did_ensure and !state.test_list.ensure_free_doesnt_change_cap() and (state.test_list.cap() - state.test_list.len() < count)) return Utils.alloc_fail_str(alloc, @src(), "ensure_free_slots(): try_ensure_free_slots() didnt provide enough capacity: WANT={d}, CAP={d}, LEN={d}, HAVE={d}", .{ count, state.test_list.cap(), state.test_list.len(), state.test_list.cap() - state.test_list.len() });
            return verify_whole_state(state, "ensure_free_slots", count, 0, 0, alloc);
        }
        pub fn append_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const count = @min(@max(1, rand.uintLessThan(usize, LARGEST_COPY)), LARGEST_LEN - state.ref_list.items.len);
            if (count == 0) return null;
            const ref_append = state.ref_list.addManyAt(alloc, state.ref_list.items.len, count) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            @memset(ref_append, UNINIT);
            const prev_len = state.ref_list.items.len;
            const test_append = state.test_list.append_slots(count);
            if (!state.test_list.range_valid(test_append)) return Utils.alloc_fail_str(alloc, @src(), "append_slots(): append returned invalid range: PREV_LEN={d}, IDX1={d}, IDX2={d}, LEN={d}", .{ prev_len, test_append.first_idx, test_append.last_idx, state.ref_list.items.len });
            var idx_1 = test_append.first_idx;
            const idx_2 = test_append.last_idx;
            while (true) {
                state.test_list.set(idx_1, UNINIT);
                if (idx_1 == idx_2) break;
                idx_1 = state.test_list.next_idx(idx_1);
            }
            return verify_whole_state(state, "append_slots", count, 0, 0, alloc);
        }
        pub fn insert_slots(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return append_slots(rand, state, alloc);
            const count = @min(@max(1, rand.uintLessThan(usize, LARGEST_COPY)), LARGEST_LEN - state.ref_list.items.len);
            if (count == 0) return null;
            const n = rand.uintLessThan(usize, state.ref_list.items.len);
            const idx = state.test_list.nth_idx(n);
            const prev_len = state.ref_list.items.len;
            const ref_insert = state.ref_list.addManyAt(alloc, n, count) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
            @memset(ref_insert, UNINIT);
            const test_insert = state.test_list.insert_slots(idx, count);
            if (!state.test_list.range_valid(test_insert)) return Utils.alloc_fail_str(alloc, @src(), "insert_slots(): insert returned invalid range: N={D}, IDX={d}, PREV_LEN={d}, IDX1={d}, IDX2={d}, LEN={d}", .{ n, idx, prev_len, test_insert.first_idx, test_insert.last_idx, state.ref_list.items.len });
            var idx_1 = test_insert.first_idx;
            const idx_2 = test_insert.last_idx;
            while (true) {
                state.test_list.set(idx_1, UNINIT);
                if (idx_1 == idx_2) break;
                idx_1 = state.test_list.next_idx(idx_1);
            }
            return verify_whole_state(state, "insert_slots", idx, count, 0, alloc);
        }
        pub fn delete_range(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            var n1 = rand.uintLessThan(usize, state.ref_list.items.len);
            var n2 = rand.uintLessThan(usize, state.ref_list.items.len);
            if (n1 > n2) {
                const tmp = n2;
                n2 = n1;
                n1 = tmp;
            }
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            std.mem.copyForwards(T, state.ref_list.items[n1..], state.ref_list.items[n2 + 1 ..]);
            state.ref_list.items.len -= ((n2 - n1) + 1);
            state.test_list.delete_range(.new_range(idx_1, idx_2));
            return verify_whole_state(state, "delete_range", idx_1, idx_2, 0, alloc);
        }
        pub fn increment_start(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            if (state.ref_list.items.len == 0) return null;
            const n = @min(@max(1, rand.uintAtMost(usize, LARGEST_COPY)), state.ref_list.items.len);
            state.ref_list.replaceRange(alloc, 0, n, &.{});
            state.test_list.increment_start(n);
            return verify_whole_state(state, "increment_start", n, 0, 0, alloc);
        }
        pub fn clear(rand: Random, state_opaque: *anyopaque, alloc: Allocator) ?[]const u8 {
            _ = rand;
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            state.ref_list.clearRetainingCapacity();
            state.test_list.clear();
            return verify_whole_state(state, "clear", 0, 0, 0, alloc);
        }

        pub const IDX = struct {
            pub const GET_NTH = 0;
            pub const GET_NTH_PTR = 1;
            pub const SET_NTH = 2;
            pub const CHECK_NTH_IDX = 3;
            pub const IDX_RANGE_VALID = 4;
            pub const SPLIT_RANGE = 5;
            pub const MOVE = 6;
            pub const MOVE_RANGE = 7;
            pub const RANGE_LEN = 8;
            pub const ENSURE_FREE_SLOTS = 9;
            pub const APPEND_SLOTS = 10;
            pub const INSERT_SLOTS = 11;
            pub const DELETE_RANGE = 12;
            pub const INCREASE_START = 13;
            pub const CLEAR = 14;
        };

        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator) ?[]const u8{
            get_nth,
            get_nth_ptr,
            set_nth,
            check_nth_idx,
            idx_range_valid,
            split_range,
            move,
            move_range,
            range_len,
            if (LIST_LIKE) ensure_free_slots else get_nth,
            if (LIST_LIKE) append_slots else set_nth,
            if (LIST_LIKE) insert_slots else check_nth_idx,
            if (LIST_LIKE) delete_range else idx_range_valid,
            if (QUEUE_LIKE) increment_start else move,
            if (LIST_LIKE) clear else move_range,
        };
    };
}
