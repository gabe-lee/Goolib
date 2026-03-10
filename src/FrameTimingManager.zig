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
const math = std.math;
const build = @import("builtin");
const config = @import("config");
const init_zero = std.mem.zeroes;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;
const Assert = Root.Assert;
const Sort = Root.Sort.InsertionSort;
const Common = Root.CommonTypes;
const List = Root.IList.List;
const DummyAlloc = Root.DummyAllocator;
const GetSetModule = Root.GetSetType;
const MathX = Root.Math;

const LocalGetSet = GetSetModule.SimpleGetSetDirect;
const LocalGetSetArray = GetSetModule.SimpleGetSetArray;
const assert_type_has_indirect_get_and_set = GetSetModule.assert_type_has_indirect_get_and_set;
const assert_type_has_direct_get_and_set = GetSetModule.assert_type_has_direct_get_and_set;
const assert_type_has_indexed_get_only = GetSetModule.assert_type_has_indexed_get_only;
const assert_type_has_get_only = GetSetModule.assert_type_has_get_only;
const assert_getset_has_elem_type = GetSetModule.assert_getset_has_elem_type;
const assert_getset_has_elem_class = GetSetModule.assert_getset_has_elem_class;
const assert_getset_has_elem_class_with_child_type = GetSetModule.assert_getset_has_elem_class_with_child_type;
const assert_getset_has_elem_class_with_child_class = GetSetModule.assert_getset_has_elem_class_with_child_class;

pub const LockstepFrameTimingManagerConfig = struct {
    UPDATE_RATE_GETTER_TYPE: type,
    UPDATE_MULTIPLICITY_GETTER_TYPE: type,
    UNLOCK_FRAMERATE_GETTER_TYPE: type,
    CLOCKS_PER_SECOND_GETTER_TYPE: type,
    DISPLAY_FRAMERATE_GETTER_TYPE: type,
    CURR_FRAME_TIME_GETTER_TYPE: type,
    PREV_FRAME_TIME_GETSET_TYPE: ?type = null,
    RESYNC_GETSET_TYPE: ?type = null,
    FIXED_DELTATIME_GETSET_TYPE: ?type = null,
    DESIRED_FRAMETIME_GETSET_TYPE: ?type = null,
    VSYNC_MAX_ERROR_GETSET_TYPE: ?type = null,
    SNAP_HERTZ_GETSET_TYPE: ?type = null,
    SNAP_FREQUENCIES_GETSET_TYPE: ?type = null,
    DELTA_TIME_GETSET_TYPE: ?type = null,
    TIME_ACCUMULATOR_GETSET_TYPE: ?type = null,
    TIMEFRAME_AVERAGE_SET_GETSET_TYPE: ?type = null,
    AVERAGER_RESIDUAL_TYPE: ?type = null,
    AVERAGER_SUM_TYPE: ?type = null,
};

pub fn LockstepFrameTimingManager(comptime CONFIG: LockstepFrameTimingManagerConfig) type {
    assert_type_has_get_only(CONFIG.UPDATE_RATE_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UPDATE_RATE_GETTER_TYPE, Types.TypeId.float, @src());
    assert_type_has_get_only(CONFIG.UPDATE_MULTIPLICITY_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UPDATE_RATE_GETTER_TYPE, Types.TypeId.int, @src());
    assert_type_has_get_only(CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE, Types.TypeId.bool, @src());
    assert_type_has_get_only(CONFIG.CLOCKS_PER_SECOND_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE, Types.TypeId.int, @src());
    assert_type_has_get_only(CONFIG.DISPLAY_FRAMERATE_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE, Types.TypeId.int, @src());
    assert_type_has_get_only(CONFIG.CURR_FRAME_TIME_GETTER_TYPE, @src());
    assert_getset_has_elem_class(CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE, Types.TypeId.int, @src());
    if (CONFIG.PREV_FRAME_TIME_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.RESYNC_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.bool, @src());
    }
    if (CONFIG.FIXED_DELTATIME_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.float, @src());
    }
    if (CONFIG.DESIRED_FRAMETIME_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.VSYNC_MAX_ERROR_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.SNAP_HERTZ_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.SNAP_FREQUENCIES_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class_with_child_class(TYPE, Types.TypeId.array, Types.TypeId.int, @src());
    }
    if (CONFIG.DELTA_TIME_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.TIME_ACCUMULATOR_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.TIMEFRAME_AVERAGE_SET_GETSET_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class_with_child_class(TYPE, Types.TypeId.array, Types.TypeId.int, @src());
    }
    if (CONFIG.AVERAGER_RESIDUAL_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    if (CONFIG.AVERAGER_SUM_TYPE) |TYPE| {
        assert_type_has_indirect_get_and_set(TYPE, @src());
        assert_getset_has_elem_class(TYPE, Types.TypeId.int, @src());
    }
    return struct {
        const Self = @This();

        update_rate: CONFIG.UPDATE_RATE_GETTER_TYPE,
        update_multiplicity: CONFIG.UPDATE_MULTIPLICITY_GETTER_TYPE,
        unlock_framerate: CONFIG.UNLOCK_FRAMERATE_GETTER_TYPE,
        clocks_per_second: CONFIG.CLOCKS_PER_SECOND_GETTER_TYPE,
        display_framerate: CONFIG.DISPLAY_FRAMERATE_GETTER_TYPE,
        curr_frame_time: CONFIG.CURR_FRAME_TIME_GETTER_TYPE,
        prev_frame_time: if (CONFIG.PREV_FRAME_TIME_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        should_resync: if (CONFIG.RESYNC_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(bool),
        fixed_deltatime: if (CONFIG.FIXED_DELTATIME_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(f32),
        desired_frametime: if (CONFIG.DESIRED_FRAMETIME_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        vsync_max_error: if (CONFIG.VSYNC_MAX_ERROR_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        snap_hertz: if (CONFIG.SNAP_HERTZ_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        snap_frequencies: if (CONFIG.SNAP_FREQUENCIES_GETSET_TYPE) |TYPE| TYPE else LocalGetSetArray(i64, 4),
        delta_time: if (CONFIG.DELTA_TIME_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        time_accumulator: if (CONFIG.TIME_ACCUMULATOR_GETSET_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        timeframe_average_set: if (CONFIG.TIMEFRAME_AVERAGE_SET_GETSET_TYPE) |TYPE| TYPE else LocalGetSetArray(i64, 4),
        timeframe_average_set_idx: u8 = 0,
        averager_residual: if (CONFIG.AVERAGER_RESIDUAL_TYPE) |TYPE| TYPE else LocalGetSet(i64),
        averager_sum: if (CONFIG.AVERAGER_SUM_TYPE) |TYPE| TYPE else LocalGetSet(i64),

        pub fn add_time(self: *Self) void {
            const curr_time = self.curr_frame_time.get();
            const prev_time = self.prev_frame_time.get();
            var delta: @field(@FieldType(Self, "delta_time"), "ELEM") = @intCast(MathX.upgrade_subtract(curr_time, prev_time));
            self.delta_time.set(delta);
            self.prev_frame_time.set(curr_time);
            const desired_frametime = self.desired_frametime.get();
            if (delta > desired_frametime * EXTRA_SLOW_MULTIPLIER) {
                delta = desired_frametime;
            }
            if (delta < 0) {
                delta = 0;
            }
            const snap_freqs_len = self.snap_frequencies.len();
            const max_error = self.vsync_max_error.get();
            for (0..snap_freqs_len) |i| {
                const snap = self.snap_frequencies.get(@intCast(i));
                if (@abs(delta - snap) < max_error) {
                    delta = snap;
                }
            }
            const timeframe_average_set_len = self.timeframe_average_set.len();
            const overwrite_old_time = self.timeframe_average_set.get(@intCast(self.timeframe_average_set_idx));
            var new_average_sum = self.averager_sum.get();
            new_average_sum -= overwrite_old_time;
            self.timeframe_average_set.set(@intCast(self.timeframe_average_set_idx), delta);
            new_average_sum += delta;
            self.averager_sum.set(new_average_sum);
            self.timeframe_average_set_idx += 1;
            self.timeframe_average_set_idx %= timeframe_average_set_len;
            delta = new_average_sum / timeframe_average_set_len;
            var new_residual = self.averager_residual.get();
            new_residual += new_average_sum % timeframe_average_set_len;
            delta += new_residual / timeframe_average_set_len;
            new_residual = new_residual % timeframe_average_set_len;
            self.averager_residual.set(new_residual);
            var accumulated_time = self.time_accumulator.get();
            accumulated_time += delta;
            if (accumulated_time > desired_frametime * 8) {
                self.should_resync.set(true);
            }
            if (self.should_resync.get()) {
                accumulated_time = desired_frametime;
                delta = desired_frametime;
                self.should_resync.set(false);
            }
            self.time_accumulator.set(accumulated_time);
            self.delta_time.set(delta);
        }
        pub fn use_time(self: *Self) bool {
            var time_left = self.time_accumulator.get();
            var time_per_frame = self.desired_frametime.get();
            //CHECKPOINT
        }
    };
}

const EXTRA_SLOW_MULTIPLIER = 8;
const SNAP_RATIO = 0.0002;
