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

const ExternalGetOrLocalGetSet = GetSetModule.GetOrGetSetDirect;
const ExternalGetOrLocalGetSetIndexed = GetSetModule.GetOrGetSetDirectIndexed;
const ExternalOrLocalGetSetIndexed = GetSetModule.GetSetIndirectOrDirectIndexed;
const ExternalOrLocalGetSet = GetSetModule.GetSetIndirectOrDirect;
const LocalGetSet = GetSetModule.SimpleGetSetDirect;
const LocalGetSetArray = GetSetModule.SimpleGetSetArray;
const ElemReq = GetSetModule.ElemRequirement;
const assert_type_has_indirect_get_and_set = GetSetModule.assert_type_has_indirect_get_and_set;
const assert_type_has_direct_get_and_set = GetSetModule.assert_type_has_direct_get_and_set;
const assert_type_has_indexed_get_only = GetSetModule.assert_type_has_indexed_get_only;
const assert_type_has_get_only = GetSetModule.assert_type_has_get_only;
const assert_getset_has_elem_type = GetSetModule.assert_getset_has_elem_type;
const assert_getset_has_elem_class = GetSetModule.assert_getset_has_elem_class;
const assert_getset_has_elem_class_with_child_type = GetSetModule.assert_getset_has_elem_class_with_child_type;
const assert_getset_has_elem_class_with_child_class = GetSetModule.assert_getset_has_elem_class_with_child_class;
const num_cast = Cast.num_cast;

pub const FrameTimingManagerConfig = struct {
    DESIRED_FRAMERATE_GET_TYPE: ExternalGetOrLocalGetSet,
    LOCKED_MODE_MIN_UPDATES_PER_FRAME_GET_TYPE: ExternalGetOrLocalGetSet,
    UNLOCK_FRAMERATE_GET_TYPE: ExternalGetOrLocalGetSet,
    TICKS_PER_SECOND_GET_TYPE: ExternalGetOrLocalGetSet,
    DISPLAY_FRAMERATE_GET_TYPE: ExternalGetOrLocalGetSet,
    CURR_FRAME_TIME_GET_TYPE: ExternalGetOrLocalGetSet,
    PREV_FRAME_TIME_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    DESIRED_SECONDS_PER_UPDATE_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    DESIRED_TICKS_PER_UPDATE_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    VSYNC_MAX_ERROR_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    SNAP_FREQUENCIES_GETSET_TYPE: ?ExternalOrLocalGetSetIndexed = null,
    DELTA_TICKS_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    TICK_ACCUMULATOR_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    RECENT_DELTAS_LIST_GETSET_TYPE: ?ExternalOrLocalGetSetIndexed = null,
    RECENT_DELTAS_AVERAGE_RESIDUAL_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    RECENT_DELTAS_SUM_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    LOCKED_MODE_MIN_UPDATES_REMAINING_GETSET_TYPE: ?ExternalOrLocalGetSet = null,
    INTEGER_TYPE: type = u64,
    FLOAT_TYPE: type = f64,
    SNAP_FREQUENCIES_LIST_LEN_IF_NOT_PROVIDED: comptime_int = 4,
    TIME_AVERAGER_LIST_LEN_IF_NOT_PROVIDED: comptime_int = 8,
    MAX_ACCUMULATED_UPDATES: comptime_int = 8,
    VSYNC_ERROR_SNAP_RATIO: comptime_float = 0.0002,
    LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1: bool = false,
    INCLUDE_DEBUG_INFO: bool = false,
};

pub fn FrameTimingManager(comptime CONFIG: FrameTimingManagerConfig) type {
    const INTEGER_REQ: ElemReq = .exact_type(CONFIG.INTEGER_TYPE);
    const FLOAT_REQ: ElemReq = .exact_type(CONFIG.FLOAT_TYPE);
    const BOOL_REQ: ElemReq = .exact_type(bool);
    CONFIG.DESIRED_FRAMERATE_GET_TYPE.with_requirements(FLOAT_REQ).assert_valid(@src());
    CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_GET_TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    CONFIG.UNLOCK_FRAMERATE_GET_TYPE.with_requirements(BOOL_REQ).assert_valid(@src());
    CONFIG.TICKS_PER_SECOND_GET_TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    CONFIG.DISPLAY_FRAMERATE_GET_TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    CONFIG.CURR_FRAME_TIME_GET_TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    if (CONFIG.PREV_FRAME_TIME_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.DESIRED_SECONDS_PER_UPDATE_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(FLOAT_REQ).assert_valid(@src());
    }
    if (CONFIG.DESIRED_TICKS_PER_UPDATE_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.VSYNC_MAX_ERROR_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.SNAP_FREQUENCIES_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.DELTA_TICKS_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.TICK_ACCUMULATOR_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.RECENT_DELTAS_LIST_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.RECENT_DELTAS_AVERAGE_RESIDUAL_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.RECENT_DELTAS_SUM_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    if (CONFIG.LOCKED_MODE_MIN_UPDATES_REMAINING_GETSET_TYPE) |TYPE| {
        TYPE.with_requirements(INTEGER_REQ).assert_valid(@src());
    }
    return struct {
        const Self = @This();

        desired_framerate: CONFIG.DESIRED_FRAMERATE_GET_TYPE.unrwap_type(),
        locked_mode_min_updates_per_frame: if (!CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1) CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_GET_TYPE.unrwap_type() else void,
        unlock_framerate: CONFIG.UNLOCK_FRAMERATE_GET_TYPE.unrwap_type(),
        ticks_per_second: CONFIG.TICKS_PER_SECOND_GET_TYPE.unrwap_type(),
        display_framerate: CONFIG.DISPLAY_FRAMERATE_GET_TYPE.unrwap_type(),
        curr_frame_time: CONFIG.CURR_FRAME_TIME_GET_TYPE.unrwap_type(),
        prev_frame_time: if (CONFIG.PREV_FRAME_TIME_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        desired_seconds_per_update: if (CONFIG.DESIRED_SECONDS_PER_UPDATE_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.FLOAT_TYPE),
        desired_ticks_per_update: if (CONFIG.DESIRED_TICKS_PER_UPDATE_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        vsync_max_error: if (CONFIG.VSYNC_MAX_ERROR_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        snap_ticks_list: if (CONFIG.SNAP_FREQUENCIES_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSetArray(CONFIG.INTEGER_TYPE, CONFIG.SNAP_FREQUENCIES_LIST_LEN_IF_NOT_PROVIDED),
        delta_ticks: if (CONFIG.DELTA_TICKS_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        tick_accumulator: if (CONFIG.TICK_ACCUMULATOR_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        recent_deltas_list: if (CONFIG.RECENT_DELTAS_LIST_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSetArray(CONFIG.INTEGER_TYPE, CONFIG.TIME_AVERAGER_LIST_LEN_IF_NOT_PROVIDED),
        recent_deltas_idx: CONFIG.INTEGER_TYPE = 0,
        locked_mode_min_updates_remaining: if (!CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1) usize else void = if (!CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1) 0 else void{},
        recent_deltas_average_residual: if (CONFIG.RECENT_DELTAS_AVERAGE_RESIDUAL_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        recent_deltas_sum: if (CONFIG.RECENT_DELTAS_SUM_GETSET_TYPE) |TYPE| TYPE.unrwap_type() else LocalGetSet(CONFIG.INTEGER_TYPE),
        should_resync: bool = false,
        debug_info: if (CONFIG.INCLUDE_DEBUG_INFO) DebugInfo else void = if (CONFIG.INCLUDE_DEBUG_INFO) DebugInfo{} else void{},

        pub const DebugInfo = struct {
            num_times_time_added: u64 = 0,
            total_time_added: u64 = 0,
            times_snapped_to_ticks: u64 = 0,
            time_drift_due_to_snap: i64 = 0,
            num_times_resynced: u64 = 0,
            total_time_lost_to_resync: u64 = 0,
            sum_of_absolute_drift_due_to_snap: u64 = 0,
            num_times_time_returned_for_use: u64 = 0,
            total_fixed_time_returned: u64 = 0,
            total_variable_time_returned: u64 = 0,
            num_times_variable_time_did_not_equal_fixed_time_returned: u64 = 0,
            sum_of_difference_between_variable_and_fixed_time: u64 = 0,
            current_total_variable_time: u64 = 0,
            sum_of_total_variable_time_when_variable_time_did_not_equal_fixed_time: u64 = 0,
            recent_frame_deltas: [64]u64 = @splat(0),
            recent_frame_delta_sum: u64 = 0,
            recent_frame_idx: u8 = 0,
        };
        pub const InitializeSettings = struct {
            INITIALIZE_RESYNC_AND_PREV_FRAME: bool = false,
            INITIALIZE_DESIRED_SECONDS_AND_TICKS_PER_UPDATE: bool = false,
            INITIALIZE_TICK_SNAPS_AND_VSYNC_ERROR: bool = false,
            INITIALIZE_RECENT_DELTAS: bool = false,
            INITIALIZE_DEBUG_INFO: bool = false,

            pub const ALL = InitializeSettings{
                .INITIALIZE_RESYNC_AND_PREV_FRAME = true,
                .INITIALIZE_DESIRED_SECONDS_AND_TICKS_PER_UPDATE = true,
                .INITIALIZE_TICK_SNAPS_AND_VSYNC_ERROR = true,
                .INITIALIZE_RECENT_DELTAS = true,
                .INITIALIZE_DEBUG_INFO = true,
            };
        };

        /// Initialize values that are automatically calculated from the core parameters
        ///
        /// This requires that the core parameters must be initialized already, either externally or locally
        ///
        /// The core parameters are:
        ///   - desired_framerate
        ///   - locked_mode_min_updates_per_frame
        ///     - only if LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1 == false
        ///   - unlock_framerate
        ///   - ticks_per_second
        ///   - display_framerate
        ///   - curr_frame_time
        ///
        /// You can use the settings to select which portions to initialze or skip. The first
        /// initialization shoul initialize all parts, but subsequent updates (if one of the core params changes)
        /// can target certain parts without affecting unrelated state.
        pub fn initialize(self: *Self, comptime SETTINGS: InitializeSettings) void {
            if (SETTINGS.INITIALIZE_DEBUG_INFO and CONFIG.INCLUDE_DEBUG_INFO) {
                self.debug_info = DebugInfo{};
            }
            if (SETTINGS.INITIALIZE_RESYNC_AND_PREV_FRAME) {
                if (!CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1) {
                    self.locked_mode_min_updates_remaining = 0;
                }
                const initial_time = self.curr_frame_time.get();
                self.prev_frame_time.set(initial_time);
                self.should_resync = false;
                self.delta_ticks.set(0);
                self.tick_accumulator.set(0);
            }
            if (SETTINGS.INITIALIZE_DESIRED_SECONDS_AND_TICKS_PER_UPDATE) {
                const desired_framerate = self.desired_framerate.get();
                const ticks_per_second = self.ticks_per_second.get();
                const desired_seconds_per_update = 1.0 / desired_framerate;
                const desired_ticks_per_update = MathX.upgrade_divide_out(ticks_per_second, desired_framerate, CONFIG.INTEGER_TYPE);
                self.desired_seconds_per_update.set(desired_seconds_per_update);
                self.desired_ticks_per_update.set(desired_ticks_per_update);
            }
            if (SETTINGS.INITIALIZE_TICK_SNAPS_AND_VSYNC_ERROR) {
                const display_framerate: CONFIG.INTEGER_TYPE = self.desired_framerate.get();
                const snap_hertz: CONFIG.INTEGER_TYPE = if (display_framerate == 0) 60 else display_framerate;
                const snap_ticks_list_len = self.snap_ticks_list.len();
                const ticks_per_second = self.ticks_per_second.get();
                for (0..snap_ticks_list_len) |i| {
                    const this_snap = (ticks_per_second / snap_hertz) * num_cast(i + 1, CONFIG.INTEGER_TYPE);
                    self.snap_ticks_list.set(@intCast(i), this_snap);
                }
                const vsync_max_error = MathX.upgrade_multiply_out(CONFIG.VSYNC_ERROR_SNAP_RATIO, snap_hertz, CONFIG.INTEGER_TYPE);
                self.vsync_max_error.set(vsync_max_error);
            }
            if (SETTINGS.INITIALIZE_RECENT_DELTAS) {
                self.recent_deltas_idx = 0;
                const desired_ticks_per_update = self.desired_ticks_per_update.get();
                const recent_deltas_list_len = self.recent_deltas_list.len();
                const initial_sum = desired_ticks_per_update * recent_deltas_list_len;
                self.recent_deltas_sum.set(initial_sum);
                for (0..recent_deltas_list_len) |i| {
                    self.recent_deltas_list.set(@intCast(i), desired_ticks_per_update);
                }
                self.recent_deltas_average_residual.set(0);
            }
        }

        /// Add time to the timing manager based on the timestamp of the previous frame
        /// and the timestamp of the current frame.
        ///
        /// This must be called AFTER the logic that updates the variable in `curr_frame_time`
        pub fn add_time(self: *Self) void {
            const curr_time: CONFIG.INTEGER_TYPE = self.curr_frame_time.get();
            const prev_time: CONFIG.INTEGER_TYPE = self.prev_frame_time.get();
            var delta_ticks: CONFIG.INTEGER_TYPE = @intCast(MathX.upgrade_subtract(curr_time, prev_time));
            if (CONFIG.INCLUDE_DEBUG_INFO) {
                self.debug_info.num_times_time_added += 1;
                self.debug_info.total_time_added += num_cast(delta_ticks, u64);
                const oldest_recent_delta = self.debug_info.recent_frame_deltas[self.debug_info.recent_frame_idx];
                self.debug_info.recent_frame_delta_sum -= oldest_recent_delta;
                self.debug_info.recent_frame_delta_sum += delta_ticks;
                self.debug_info.recent_frame_deltas[self.debug_info.recent_frame_idx] = delta_ticks;
                self.debug_info.recent_frame_idx += 1;
                self.debug_info.recent_frame_idx %= 64;
            }
            self.prev_frame_time.set(curr_time);
            const desired_ticks_per_update: CONFIG.INTEGER_TYPE = self.desired_ticks_per_update.get();
            delta_ticks = MathX.clamp(0, delta_ticks, desired_ticks_per_update * CONFIG.MAX_ACCUMULATED_UPDATES);
            const snap_ticks_len = self.snap_ticks_list.len();
            const vsync_max_error = self.vsync_max_error.get();
            for (0..snap_ticks_len) |i| {
                const snap_tick = self.snap_ticks_list.get(@intCast(i));
                const abs_diff = MathX.abs_difference(delta_ticks, snap_tick);
                if (abs_diff < vsync_max_error) {
                    if (CONFIG.INCLUDE_DEBUG_INFO) {
                        const drift: i64 = num_cast(snap_tick, i64) - num_cast(delta_ticks, i64);
                        self.debug_info.times_snapped_to_ticks += 1;
                        self.debug_info.sum_of_absolute_drift_due_to_snap += abs_diff;
                        self.debug_info.time_drift_due_to_snap += drift;
                    }
                    delta_ticks = snap_tick;
                }
            }
            const recent_deltas_list_len: CONFIG.INTEGER_TYPE = @intCast(self.recent_deltas_list.len());
            const oldest_delta = self.recent_deltas_list.get(@intCast(self.recent_deltas_idx));
            var new_average_sum = self.recent_deltas_sum.get();
            new_average_sum -= oldest_delta;
            self.recent_deltas_list.set(@intCast(self.recent_deltas_idx), delta_ticks);
            new_average_sum += delta_ticks;
            self.recent_deltas_sum.set(new_average_sum);
            self.recent_deltas_idx += 1;
            self.recent_deltas_idx %= recent_deltas_list_len;
            delta_ticks = new_average_sum / recent_deltas_list_len;
            var new_residual = self.recent_deltas_average_residual.get();
            new_residual += new_average_sum % recent_deltas_list_len;
            delta_ticks += new_residual / recent_deltas_list_len;
            new_residual = new_residual % recent_deltas_list_len;
            self.recent_deltas_average_residual.set(new_residual);
            var accumulated_ticks = self.tick_accumulator.get();
            accumulated_ticks += delta_ticks;
            if (accumulated_ticks > desired_ticks_per_update * CONFIG.MAX_ACCUMULATED_UPDATES) {
                self.should_resync = true;
            }
            if (self.should_resync) {
                if (CONFIG.INCLUDE_DEBUG_INFO) {
                    self.debug_info.num_times_resynced += 1;
                    const time_lost = accumulated_ticks - desired_ticks_per_update;
                    self.debug_info.total_time_lost_to_resync += num_cast(time_lost, u64);
                }
                accumulated_ticks = desired_ticks_per_update;
                delta_ticks = desired_ticks_per_update;
                self.should_resync = false;
            }
            self.tick_accumulator.set(accumulated_ticks);
            self.delta_ticks.set(delta_ticks);
        }

        /// Returns the next time deltas to use for fixed and/or variable updates, if any
        ///
        /// Normally each step of time to use will be equally sized
        /// to exactly `desired_ticks_per_update` and `desired_seconds_per_update`,
        /// and `render_interp_ratio` will equal 1.0, and `full_fixed_update` will be true,
        ///
        /// When `unlock_framerate == true`, there a few additional things to note about the LAST
        /// instance of returned TimeToUse in the frame:
        ///   - TimeToUse will have whatever remnant of
        /// variable time is left for the variable update after the previous variable updates.
        ///   - If full_fixed_update is false, it indicates the fixed time delta did not fill a full `desired_ticks_per_update`.
        /// In this case it should not be used for the fixed time update, but may be used for rendering interpolation (see below)
        ///   - If full_fixed_update is false, `render_interp_ratio` will be less than 1.0. If you are using interpolation for the
        /// leftover fixed time that did not fill a full `desired_ticks_per_update`, this is how far to interpolate rendering.
        /// It is based on the remnant of unused fixed time ticks to use divided by the desired fixed ticks per update.
        /// Interpolated values should be rolled back next frame for a real calculation using the next block of fixed time.
        pub fn has_more_time_to_use(self: *Self) ?TimeToUse {
            if (CONFIG.INCLUDE_DEBUG_INFO) {
                self.debug_info.num_times_time_returned_for_use += 1;
            }
            var ticks_left = self.tick_accumulator.get();
            const desired_ticks_per_update = self.desired_ticks_per_update.get();
            const desired_seconds_per_update = self.desired_seconds_per_update.get();
            const unlocked_mode = self.unlock_framerate.get();
            if (unlocked_mode) {
                var variable_ticks_left = self.delta_ticks.get();
                if (ticks_left >= desired_ticks_per_update) {
                    var to_use = TimeToUse{
                        .fixed_seconds = desired_seconds_per_update,
                        .fixed_ticks = desired_ticks_per_update,
                    };
                    ticks_left -= desired_ticks_per_update;
                    self.tick_accumulator.set(ticks_left);
                    if (variable_ticks_left > desired_ticks_per_update) {
                        variable_ticks_left -= desired_ticks_per_update;
                        self.delta_ticks.set(variable_ticks_left);
                        to_use.variable_seconds = desired_seconds_per_update;
                        to_use.variable_ticks = desired_ticks_per_update;
                        if (CONFIG.INCLUDE_DEBUG_INFO) {
                            self.debug_info.current_total_variable_time += desired_ticks_per_update;
                            self.debug_info.total_variable_time_returned += num_cast(desired_ticks_per_update, u64);
                        }
                    }
                    if (CONFIG.INCLUDE_DEBUG_INFO) {
                        self.debug_info.total_fixed_time_returned += num_cast(to_use.fixed_ticks, u64);
                    }
                    return to_use;
                } else if (variable_ticks_left > 0) {
                    if (CONFIG.INCLUDE_DEBUG_INFO) {
                        self.debug_info.current_total_variable_time += variable_ticks_left;
                        self.debug_info.num_times_variable_time_did_not_equal_fixed_time_returned += 1;
                        self.debug_info.sum_of_difference_between_variable_and_fixed_time += num_cast(ticks_left, u64);
                        self.debug_info.sum_of_total_variable_time_when_variable_time_did_not_equal_fixed_time += self.debug_info.current_total_variable_time;
                        self.debug_info.total_variable_time_returned += num_cast(variable_ticks_left, u64);
                    }
                    const to_use = TimeToUse{
                        .variable_seconds = MathX.upgrade_to_float(variable_ticks_left, CONFIG.FLOAT_TYPE) / MathX.upgrade_to_float(self.ticks_per_second.get(), CONFIG.FLOAT_TYPE),
                        .variable_ticks = variable_ticks_left,
                        .render_interp_ratio = MathX.upgrade_to_float(ticks_left, CONFIG.FLOAT_TYPE) / MathX.upgrade_to_float(desired_ticks_per_update, CONFIG.FLOAT_TYPE),
                    };
                    variable_ticks_left = 0;
                    self.delta_ticks.set(variable_ticks_left);
                    return to_use;
                } else if (CONFIG.INCLUDE_DEBUG_INFO) {
                    self.debug_info.current_total_variable_time = 0;
                }
            } else {
                if (CONFIG.LOCKED_MODE_MIN_UPDATES_PER_FRAME_IS_ALWAYS_1) {
                    var locked_mode_min_remaining = self.locked_mode_min_updates_remaining.get();
                    if (locked_mode_min_remaining > 0) {
                        locked_mode_min_remaining -= 1;
                        self.locked_mode_min_updates_remaining.set(locked_mode_min_remaining);
                        return TimeToUse{
                            .fixed_seconds = desired_seconds_per_update,
                            .fixed_ticks = desired_ticks_per_update,
                            .variable_seconds = desired_seconds_per_update,
                            .variable_ticks = desired_ticks_per_update,
                        };
                    }
                    const locked_mode_min_updates_per_frame = self.locked_mode_min_updates_per_frame.get();
                    const ticks_left_min_block = desired_ticks_per_update * locked_mode_min_updates_per_frame;
                    if (ticks_left >= ticks_left_min_block) {
                        locked_mode_min_remaining = locked_mode_min_updates_per_frame - 1;
                        self.locked_mode_min_updates_remaining.set(locked_mode_min_remaining);
                        ticks_left -= ticks_left_min_block;
                        self.tick_accumulator.set(ticks_left);
                        return TimeToUse{
                            .fixed_seconds = desired_seconds_per_update,
                            .fixed_ticks = desired_ticks_per_update,
                            .variable_seconds = desired_seconds_per_update,
                            .variable_ticks = desired_ticks_per_update,
                        };
                    }
                } else {
                    if (ticks_left >= desired_ticks_per_update) {
                        ticks_left -= desired_ticks_per_update;
                        self.tick_accumulator.set(ticks_left);
                        return TimeToUse{
                            .fixed_seconds = desired_seconds_per_update,
                            .fixed_ticks = desired_ticks_per_update,
                            .variable_seconds = desired_seconds_per_update,
                            .variable_ticks = desired_ticks_per_update,
                        };
                    }
                }
            }
            return null;
        }

        pub fn print_debug_info(self: Self) void {
            if (CONFIG.INCLUDE_DEBUG_INFO) {
                const average_ticks_per_frame = num_cast(self.debug_info.total_time_added, f64) / num_cast(self.debug_info.num_times_time_added, f64);
                const ticks_per_sec = self.ticks_per_second.get();
                const average_sec_per_frame = average_ticks_per_frame / num_cast(ticks_per_sec, f64);
                const total_average_fps = 1.0 / average_sec_per_frame;
                const average_ms_per_frame = average_sec_per_frame * 1000.0;
                const recent_average_ticks_per_frame = num_cast(self.debug_info.recent_frame_delta_sum, f64) / 64.0;
                const recent_average_sec_per_frame = recent_average_ticks_per_frame / num_cast(ticks_per_sec, f64);
                const recent_average_fps = 1.0 / recent_average_sec_per_frame;
                const recent_average_ms_per_frame = recent_average_sec_per_frame * 1000.0;
                //CHECKPOINT
            }
        }

        pub const TimeToUse = struct {
            fixed_seconds: CONFIG.FLOAT_TYPE = 0,
            fixed_ticks: CONFIG.INTEGER_TYPE = 0,
            variable_seconds: CONFIG.FLOAT_TYPE = 0,
            variable_ticks: CONFIG.INTEGER_TYPE = 0,
            render_interp_ratio: CONFIG.FLOAT_TYPE = 1.0,
            full_fixed_update: bool = false,
        };
    };
}
