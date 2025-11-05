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
const Random = std.Random;
const math = std.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const fmt = std.fmt;

const SliceAdapter = Root.IList_SliceAdapter.SliceAdapter;
const ArrayListAdapter = Root.IList_ArrayListAdapter.ArrayListAdapter;
const RingList = Root.IList_RingList.RingList;
const List = Root.IList_List.List;
const Assert = Root.Assert;
const Types = Root.Types;
const IList = Root.IList;
const Fuzz = Root.Fuzz;
const Utils = Root.Utils;
const Flags = Root.Flags;

const MICRO_LEN: usize = 64;
const MINI_LEN: usize = 128;
const SMALL_LEN: usize = 256;
const MED_LEN: usize = 1024;
const LARGE_LEN: usize = 4096;
const HUGE_LEN: usize = 16384;
const MONSTER_LEN: usize = 65535;

pub const ONE = 0;
pub const MICRO = 1;
pub const MINI = 2;
pub const SMALL = 3;
pub const MED = 4;
pub const LARGE = 5;
pub const HUGE = 6;
pub const MONSTER = 7;
const SIZE_COUNT = 8;

const LENGTHS = [SIZE_COUNT]usize{
    1,
    MICRO_LEN,
    MINI_LEN,
    SMALL_LEN,
    MED_LEN,
    LARGE_LEN,
    HUGE_LEN,
    MONSTER_LEN,
};

const LENGTH_NAMES = [SIZE_COUNT][]const u8{
    "ONE",
    "MICRO",
    "MINI",
    "SMALL",
    "MED",
    "LARGE",
    "HUGE",
    "MNSTR",
};

pub fn FN_BENCH_MAKER(comptime T: type) type {
    return fn (init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest;
}

pub fn make_bench_table(
    comptime T: type,
    comptime init_val: T,
    comptime OVERIDE_MAX_COPY: ?usize,
    comptime KIND: []const u8,
    comptime bench_makers: []const *const FN_BENCH_MAKER(T),
    comptime op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type,
) [SIZE_COUNT][bench_makers.len]Fuzz.FuzzTest {
    var out: [SIZE_COUNT][bench_makers.len]Fuzz.FuzzTest = undefined;
    var i: usize = 0;
    var j: usize = 0;
    while (i < SIZE_COUNT) {
        j = 0;
        const MAX_C = if (OVERIDE_MAX_COPY) |OVERRIDE| OVERRIDE else LENGTHS[i];
        while (j < bench_makers.len) {
            out[i][j] = bench_makers[j](
                init_val,
                KIND ++ "_" ++ LENGTH_NAMES[i],
                LENGTHS[i],
                MAX_C,
                op_maker,
            );
            j += 1;
        }
        i += 1;
    }
    return out;
}

pub const RAND_GSID_U8 = make_bench_table(u8, 0, null, "RAND_GSID", &BENCH_MAKERS, make_bench_table_random_ins_del_get_set);
pub const Q_DQ_MANY_U8 = make_bench_table(u8, 0, null, "Q_DQ_MANY", &BENCH_MAKERS, make_bench_table_front_back_ins_del);
pub const Q_DQ_ONE_U8 = make_bench_table(u8, 0, 1, "Q_DQ_ONE", &BENCH_MAKERS, make_bench_table_front_back_ins_del);

pub const BENCH_MAKERS = [_]*const FN_BENCH_MAKER(u8){
    make_array_list_interface_bench_maker(u8),
    make_ring_list_interface_bench_maker(u8),
    make_list_interface_bench_maker(u8),
};

pub fn make_slice_interface_bench_maker(comptime T: type) fn (init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
    const proto = struct {
        fn make(init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
            const PROTO = struct {
                const T_IList = Root.IList.IList(T);
                const STATE = struct {
                    test_list: T_IList,
                    slice_arr: [MAX_LEN]u8 = @splat(0),
                    slice: []T = undefined,
                    tmp_val: T = init_val,
                    tmp_range: IList.Range = .{},
                };
                pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                    var state = try alloc.create(STATE);
                    state.slice = state.slice_arr[0..0];
                    state.test_list = SliceAdapter(T).interface_no_alloc(&state.slice);
                    state_opaque.* = @ptrCast(state);
                }
                pub fn START_SEED(rand: Random, state_opaque: *anyopaque, _: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                    var state: *STATE = @ptrCast(@alignCast(state_opaque));
                    state.slice.len = MAX_LEN;
                    rand.bytes(state.slice);
                    return null;
                }

                pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                    const state: *STATE = @ptrCast(@alignCast(state_opaque));
                    alloc.destroy(state);
                }
                const _OPS = op_maker(T, STATE, MAX_LEN, MAX_COPY);
                pub const OPS = _OPS.OPS;
            };
            return Fuzz.FuzzTest{
                .options = Fuzz.FuzzOptions{
                    .name = "IList_" ++ KIND ++ "_" ++ @typeName(T) ++ "_Slice",
                },
                .init_func = PROTO.INIT,
                .start_seed_func = PROTO.START_SEED,
                .op_table = PROTO.OPS[0..],
                .deinit_func = PROTO.DEINIT,
            };
        }
    };
    return proto.make;
}

pub fn make_array_list_interface_bench_maker(comptime T: type) fn (init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
    const proto = struct {
        fn make(init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
            const PROTO = struct {
                const T_IList = Root.IList.IList(T);
                const STATE = struct {
                    test_list: T_IList,
                    list: ArrayList(T),
                    tmp_val: T = init_val,
                    tmp_range: IList.Range = .{},
                };
                pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                    var state = try alloc.create(STATE);
                    state.list = try ArrayList(T).initCapacity(alloc, MAX_LEN);
                    state.test_list = ArrayListAdapter(T).interface(&state.list, alloc);
                    state_opaque.* = @ptrCast(state);
                }
                pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                    var state: *STATE = @ptrCast(@alignCast(state_opaque));
                    const len = rand.uintLessThan(usize, MAX_LEN);
                    state.list.clearRetainingCapacity();
                    state.list.ensureTotalCapacity(alloc, len) catch |err| return Utils.alloc_fail_err(alloc, @src(), err);
                    state.list.items.len = len;
                    if (len > 0) {
                        rand.bytes(state.list.items);
                    }
                    return null;
                }

                pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                    const state: *STATE = @ptrCast(@alignCast(state_opaque));
                    state.list.clearAndFree(alloc);
                    alloc.destroy(state);
                }

                const _OPS = op_maker(T, STATE, MAX_LEN, MAX_COPY);
                pub const OPS = _OPS.OPS;
            };
            return Fuzz.FuzzTest{
                .options = Fuzz.FuzzOptions{
                    .name = "IList_" ++ KIND ++ "_" ++ @typeName(T) ++ "_ArrayList",
                },
                .init_func = PROTO.INIT,
                .start_seed_func = PROTO.START_SEED,
                .op_table = PROTO.OPS[0..],
                .deinit_func = PROTO.DEINIT,
            };
        }
    };
    return proto.make;
}

pub fn make_list_interface_bench_maker(comptime T: type) fn (init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
    const proto = struct {
        fn make(init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
            const PROTO = struct {
                const T_IList = Root.IList.IList(T);
                pub const STATE = list_interface_state(T, init_val);
                pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                    var state = try alloc.create(STATE);
                    state.list = List(T).init_capacity(MAX_LEN, alloc);
                    state.test_list = state.list.interface(alloc);
                    state_opaque.* = @ptrCast(state);
                }
                pub fn START_SEED(rand: Random, state_opaque: *anyopaque, alloc: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                    var state: *STATE = @ptrCast(@alignCast(state_opaque));
                    const len = rand.uintLessThan(usize, MAX_LEN);
                    const ok = Utils.not_error(state.test_list.try_ensure_free_slots(len));
                    if (!ok) return Utils.alloc_fail_str(alloc, @src(), "failed to ensure free slots", .{});
                    state.list.len = @intCast(len);
                    if (len > 0) {
                        rand.bytes(state.list.ptr[0..len]);
                    }
                    return null;
                }

                pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                    const state: *STATE = @ptrCast(@alignCast(state_opaque));
                    state.list.free(alloc);
                    alloc.destroy(state);
                }

                const _OPS = op_maker(T, STATE, MAX_LEN, MAX_COPY);
                pub const OPS = _OPS.OPS;
            };
            return Fuzz.FuzzTest{
                .options = Fuzz.FuzzOptions{
                    .name = "IList_" ++ KIND ++ "_" ++ @typeName(T) ++ "_List",
                },
                .init_func = PROTO.INIT,
                .start_seed_func = PROTO.START_SEED,
                .op_table = PROTO.OPS[0..],
                .deinit_func = PROTO.DEINIT,
            };
        }
    };
    return proto.make;
}

pub fn make_ring_list_interface_bench_maker(comptime T: type) fn (init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
    const proto = struct {
        fn make(init_val: T, comptime KIND: []const u8, comptime MAX_LEN: usize, comptime MAX_COPY: usize, op_maker: *const fn (comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type) Fuzz.FuzzTest {
            const PROTO = struct {
                const T_IList = Root.IList.IList(T);
                const STATE = struct {
                    test_list: T_IList,
                    ring_list: RingList(T),
                    tmp_val: T = init_val,
                    tmp_range: IList.Range = .{},
                };
                pub fn INIT(state_opaque: **anyopaque, alloc: Allocator) anyerror!void {
                    var state = try alloc.create(STATE);
                    state.ring_list = RingList(T).init_capacity(MAX_LEN, alloc);
                    state.test_list = state.ring_list.interface(alloc);
                    state_opaque.* = @ptrCast(state);
                }
                pub fn START_SEED(rand: Random, state_opaque: *anyopaque, _: Allocator, _: *Fuzz.BenchTime) ?[]const u8 {
                    var state: *STATE = @ptrCast(@alignCast(state_opaque));
                    const len = rand.uintLessThan(usize, MAX_LEN);
                    state.test_list.clear();
                    state.test_list.ensure_free_slots(len);
                    state.ring_list.len = @intCast(len);
                    if (len > 0) {
                        rand.bytes(state.ring_list.ptr[0..len]);
                    }
                    return null;
                }

                pub fn DEINIT(state_opaque: *anyopaque, alloc: Allocator) void {
                    const state: *STATE = @ptrCast(@alignCast(state_opaque));
                    state.test_list.free();
                    alloc.destroy(state);
                }

                const _OPS = op_maker(T, STATE, MAX_LEN, MAX_COPY);
                pub const OPS = _OPS.OPS;
            };
            return Fuzz.FuzzTest{
                .options = Fuzz.FuzzOptions{
                    .name = "IList_" ++ KIND ++ "_" ++ @typeName(T) ++ "_RingList",
                },
                .init_func = PROTO.INIT,
                .start_seed_func = PROTO.START_SEED,
                .op_table = PROTO.OPS[0..],
                .deinit_func = PROTO.DEINIT,
            };
        }
    };
    return proto.make;
}

pub fn list_interface_state(comptime T: type, init_val: T) type {
    return struct {
        test_list: Root.IList.IList(T),
        list: List(T),
        tmp_val: T = init_val,
        tmp_range: IList.Range = .{},
    };
}
pub fn make_bench_table_random_ins_del_get_set(comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type {
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "test_list", IList.IList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `test_list` that is of type `IList({s})`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "tmp_val", T), @src(), "to use this automatic op generator, type `STATE` must have a field named `tmp_val` that is of type `{s}`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "tmp_range", IList.Range), @src(), "to use this automatic op generator, type `STATE` must have a field named `tmp_range` that is of type `IList.Range`", .{@typeName(T)});
    return struct {
        fn get_nth(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return null;
            const n = rand.uintLessThan(usize, len);
            bench.start();
            state.tmp_val = state.test_list.get_nth(n);
            bench.end();
            return null;
        }
        fn set_nth(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return null;
            const n = rand.uintLessThan(usize, len);
            bench.start();
            state.tmp_val = state.test_list.get_nth(n);
            bench.end();
            return null;
        }
        pub fn insert(rand: Random, state_opaque: *anyopaque, alloc: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return append(rand, state_opaque, alloc, bench);
            const count = @min(@max(1, rand.uintLessThan(usize, MAX_COPY)), MAX_LEN - len);
            if (count == 0) return null;
            const n = rand.uintLessThan(usize, len);
            bench.start();
            const idx = state.test_list.nth_idx(n);
            state.tmp_range = state.test_list.insert_slots(idx, count);
            bench.end();
            return null;
        }
        pub fn append(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            const count = @min(@max(1, rand.uintLessThan(usize, MAX_COPY)), MAX_LEN - len);
            if (count == 0) return null;
            bench.start();
            state.tmp_range = state.test_list.append_slots(count);
            bench.end();
            return null;
        }
        pub fn delete(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return null;
            const n1 = rand.uintLessThan(usize, len);
            const leftover = len - n1;
            const n2 = rand.uintLessThan(usize, @min(MAX_COPY, leftover)) + n1;
            const idx_1: usize = state.test_list.nth_idx(n1);
            const idx_2: usize = state.test_list.nth_idx(n2);
            bench.start();
            state.test_list.delete_range(.new_range(idx_1, idx_2));
            bench.end();
            return null;
        }

        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator, bench: *Fuzz.BenchTime) ?[]const u8{
            get_nth,
            set_nth,
            insert,
            append,
            delete,
        };
    };
}

pub fn make_bench_table_front_back_ins_del(comptime T: type, comptime STATE: type, comptime MAX_LEN: usize, comptime MAX_COPY: usize) type {
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "test_list", IList.IList(T)), @src(), "to use this automatic op generator, type `STATE` must have a field named `test_list` that is of type `IList({s})`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "tmp_val", T), @src(), "to use this automatic op generator, type `STATE` must have a field named `tmp_val` that is of type `{s}`", .{@typeName(T)});
    Assert.assert_with_reason(Types.type_has_field_with_type(STATE, "tmp_range", IList.Range), @src(), "to use this automatic op generator, type `STATE` must have a field named `tmp_range` that is of type `IList.Range`", .{@typeName(T)});
    return struct {
        pub fn insert_start(rand: Random, state_opaque: *anyopaque, alloc: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return append_end(rand, state_opaque, alloc, bench);
            const count = @min(@max(1, rand.uintLessThan(usize, MAX_COPY)), MAX_LEN - len);
            if (count == 0) return null;
            bench.start();
            const idx = state.test_list.first_idx();
            state.tmp_range = state.test_list.insert_slots(idx, count);
            bench.end();
            return null;
        }
        pub fn append_end(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            const count = @min(@max(1, rand.uintLessThan(usize, MAX_COPY)), MAX_LEN - len);
            if (count == 0) return null;
            bench.start();
            state.tmp_range = state.test_list.append_slots(count);
            bench.end();
            return null;
        }
        pub fn delete_start(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return null;
            const n2 = rand.uintLessThan(usize, @min(MAX_COPY, len));
            bench.start();
            const idx_1: usize = state.test_list.first_idx();
            const idx_2: usize = state.test_list.nth_idx(n2);
            state.test_list.delete_range(.new_range(idx_1, idx_2));
            bench.end();
            return null;
        }
        pub fn delete_end(rand: Random, state_opaque: *anyopaque, _: Allocator, bench: *Fuzz.BenchTime) ?[]const u8 {
            const state: *STATE = @ptrCast(@alignCast(state_opaque));
            const len = state.test_list.len();
            if (len == 0) return null;
            const n1 = rand.uintLessThan(usize, @min(MAX_COPY, len));
            bench.start();
            const idx_1: usize = state.test_list.nth_idx_from_end(n1);
            const idx_2: usize = state.test_list.last_idx();
            state.test_list.delete_range(.new_range(idx_1, idx_2));
            bench.end();
            return null;
        }

        pub const OPS = [_]*const fn (rand: Random, state_opq: *anyopaque, alloc: Allocator, bench: *Fuzz.BenchTime) ?[]const u8{
            insert_start,
            append_end,
            delete_start,
            delete_end,
        };
    };
}
