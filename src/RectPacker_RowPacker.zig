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
const build = @import("builtin");

const Root = @import("./_root.zig");
const MathX = Root.Math;
const ListFull = Root.ListSlice.ListFullDefinition;
const AABB2 = Root.AABB2;
const Rect2 = Root.Rect2;
const Vec2 = Root.Vec2;
const Allocator = std.mem.Allocator;
const DummyAlloc = Root.DummyAllocator;

comptime {
    if (build.is_test) {
        _ = @import("./RectPacker_Tests.zig");
    }
}

pub const FINAL_PASS_CREATE_NEW_ROW_THRESHOLD_MULTIPLIER = 2;

/// Packs rectangles into horizontal rows (shelves), filling each row from left to
/// right and starting a new row below the previous one.
///
/// `full_region.pos` is treated as the top-left corner, so rows grow downwards and
/// every returned position is inside `[full_region.pos, full_region.pos + full_region.size]`.
///
/// The `Threshold` arguments are preferences, not hard limits. When a threshold is
/// requested and no existing row has a compatible height, a new row is started if
/// there is vertical room; otherwise the least-waste (or first, depending on
/// `WasteMode`) fitting row is used anyway. This packer works best with groups of
/// rectangles that have relatively similar heights (or similar widths-to-heights
/// and widths-to-widths with the `rotation` settings).
///
/// Only completely unused space is tracked. Individual rect eviction is not
/// supported, but all state (other than allocation capacity) can be reused after
/// calling `reset`.
pub fn RowPacker(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();
        const AABB = AABB2.define_aabb2_type(T);
        const Rect = Rect2.define_rect2_type(T);
        const Vec = Vec2.define_vec2_type(T);
        const RowList = ListFull(ConstrainedRow, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED);
        /// Sentinel used for `min_height` before a row has claimed any rects.
        /// Using the max value (instead of a region size) keeps the threshold
        /// arithmetic valid for unsigned integer component types.
        const MAX_HEIGHT: T = MathX.max_value(T);

        /// Doubles a threshold, saturating for integer component types so values
        /// near `MAX_HEIGHT` cannot overflow in the final-pass heuristic.
        inline fn doubled_threshold(value: T) T {
            return switch (@typeInfo(T)) {
                .int => value *| 2,
                .float => value * 2,
                else => @compileError("RowPacker requires an integer or floating-point coordinate type"),
            };
        }

        alloc: Allocator = DummyAlloc.allocator_panic,
        constrained_rows: RowList = .{},
        unconstrained_row: UnconstrainedRow = .{},
        full_region: Rect = .{ .pos = .{}, .size = .{} },
        default_height_fit_threshold: T = 0,
        total_wasted_area: T = 0,
        claim_count: IDX = 0,

        pub fn init(cap: usize, region: Rect, default_height_fit_threshold: T, alloc: Allocator) Self {
            return Self{
                .alloc = alloc,
                .constrained_rows = RowList.allocate_new(@intCast(cap), alloc),
                .unconstrained_row = UnconstrainedRow.init(region),
                .full_region = region,
                .default_height_fit_threshold = default_height_fit_threshold,
                .total_wasted_area = 0,
                .claim_count = 0,
            };
        }

        pub fn reset(self: *Self) void {
            self.constrained_rows.clear();
            self.unconstrained_row = UnconstrainedRow.init(self.full_region);
            self.total_wasted_area = 0;
            self.claim_count = 0;
        }

        pub fn free(self: *Self) void {
            self.constrained_rows.free_if_non_zero(self.alloc);
            self.* = .{};
        }

        pub const Threshold = union(ThresholdMode) {
            IGNORE_THRESHOLD: void,
            DEFAULT_THRESHOLD: void,
            CUSTOM_THRESHOLD: T,

            pub inline fn ignore_threshold() Threshold {
                return Threshold{ .IGNORE_THRESHOLD = {} };
            }
            pub inline fn default_threshold() Threshold {
                return Threshold{ .DEFAULT_THRESHOLD = {} };
            }
            pub inline fn custom_threshold(threshold: T) Threshold {
                return Threshold{ .CUSTOM_THRESHOLD = threshold };
            }
        };

        /// Same as `claim_position()`, but it automatically builds a `Rect` from the returned position
        ///
        /// A null value indicates there were no available spaces for the given size
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, the returned result's `is_rotated` field indicates whether the space
        /// should be treated as rotated 90 degrees (`rect.size.x == size.y` AND `rect.size.y == size.x`)
        pub fn claim_rect(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode) ?RectWithRotation {
            if (self.claim_position(size, threshold, waste, rotation)) |pos_with_rot| {
                return RectWithRotation{
                    .rect = if (pos_with_rot.is_rotated) Rect{
                        .pos = pos_with_rot.pos,
                        .size = size.flip_components(),
                    } else Rect{
                        .pos = pos_with_rot.pos,
                        .size = size,
                    },
                    .is_rotated = pos_with_rot.is_rotated,
                };
            }
            return null;
        }

        /// Same as `claim_position()`, but it automatically builds an `AABB` from the returned position
        ///
        /// A null value indicates there were no available spaces for the given size
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, the returned result's `is_rotated` field indicates whether the space
        /// should be treated as rotated 90 degrees (`(aabb.x_max - aabb.x_min) == size.y` AND `(aabb.y_max - aabb.y_min) == size.x`)
        pub fn claim_aabb(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode) ?AABB_WithRotation {
            if (self.claim_position(size, threshold, waste, rotation)) |pos_with_rot| {
                return AABB_WithRotation{
                    .aabb = if (pos_with_rot.is_rotated) AABB{
                        .x_min = pos_with_rot.pos.x,
                        .y_min = pos_with_rot.pos.y,
                        .x_max = pos_with_rot.pos.x + size.y,
                        .y_max = pos_with_rot.pos.y + size.x,
                    } else AABB{
                        .x_min = pos_with_rot.pos.x,
                        .y_min = pos_with_rot.pos.y,
                        .x_max = pos_with_rot.pos.x + size.x,
                        .y_max = pos_with_rot.pos.y + size.y,
                    },
                    .is_rotated = pos_with_rot.is_rotated,
                };
            }
            return null;
        }

        /// The returned `Vec`, if not null, is the minimum position of an `AABB` or `Rect` that has the
        /// provided `size`
        ///
        /// A null value indicates there were no available spaces for the given size
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, the returned result's `is_rotated` field indicates whether the space
        /// should be treated as rotated 90 degrees (space width == `size.y` AND space height == `size.x`)
        pub fn claim_position(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode) ?PosWithRotation {
            const allow_unrotated = rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION;
            // Force-rotation must also handle square rects, whose rotated size is
            // identical to their unrotated size.
            const allow_rotated = switch (rotation) {
                .DO_NOT_ALLOW_ROTATION => false,
                .ALLOW_90_DEGREE_ROTATION => size.x != size.y,
                .ALWAYS_FORCE_90_DEGREE_ROTATION => true,
            };

            const fits_region_unrotated = size.x <= self.full_region.size.x and size.y <= self.full_region.size.y;
            const fits_region_rotated = size.y <= self.full_region.size.x and size.x <= self.full_region.size.y;
            if ((!allow_unrotated or !fits_region_unrotated) and (!allow_rotated or !fits_region_rotated)) return null;

            const rot_size = size.flip_components();
            const threshold_value: ?T = switch (threshold) {
                .IGNORE_THRESHOLD => null,
                .DEFAULT_THRESHOLD => self.default_height_fit_threshold,
                .CUSTOM_THRESHOLD => |t| t,
            };

            var best_any: Candidate = .{};
            var best_threshold: Candidate = .{};

            const rows = self.constrained_rows.zig_slice_entire();
            const row_count = self.constrained_rows.get_len();
            var row_idx: IDX = 0;
            while (row_idx < row_count) : (row_idx += 1) {
                evaluate_row(rows[row_idx], .constrained, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, waste);
                }
            }

            evaluate_row(self.unconstrained_row, .unconstrained, 0, size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
            if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                return self.claim_candidate(candidate, waste);
            }

            const selected = if (best_threshold.kind != .none) best_threshold else best_any;
            if (best_threshold.kind == .none and threshold_value != null) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated)) |pos| {
                    return pos;
                }
            }
            if (selected.kind == .none) {
                if (threshold_value != null) return null;
                return self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated);
            }
            if (waste == .LEAST_WASTE and best_threshold.kind == .none and selected.kind == .unconstrained) {
                const extended_threshold = doubled_threshold(threshold_value orelse self.default_height_fit_threshold);
                if (self.unconstrained_row.can_fit_size_on_new_row(selected.size) and
                    !self.unconstrained_row.new_height_is_within_threshold(extended_threshold, selected.size.y))
                {
                    return self.claim_on_new_row(selected.size, selected.rotated);
                }
            }

            return self.claim_candidate(selected, waste);
        }

        const RowKind = enum(u2) {
            none,
            constrained,
            unconstrained,
        };

        const Candidate = struct {
            kind: RowKind = .none,
            row_idx: IDX = 0,
            size: Vec = .{},
            rotated: bool = false,
            waste: T = 0,

            inline fn consider(self: *Candidate, waste_mode: WasteMode, kind: RowKind, row_idx: IDX, claim_size: Vec, rotated: bool, candidate_waste: T) void {
                if (self.kind == .none or (waste_mode == .LEAST_WASTE and candidate_waste < self.waste)) {
                    self.* = .{
                        .kind = kind,
                        .row_idx = row_idx,
                        .size = claim_size,
                        .rotated = rotated,
                        .waste = candidate_waste,
                    };
                }
            }
        };

        inline fn evaluate_row(
            row: anytype,
            row_kind: RowKind,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?T,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            if (allow_unrotated and row.can_fit_size(size)) {
                consider_claim(row, row_kind, row_idx, size, false, waste_mode, threshold_value, best_threshold, best_any);
            }
            if (allow_rotated and row.can_fit_size(rot_size)) {
                consider_claim(row, row_kind, row_idx, rot_size, true, waste_mode, threshold_value, best_threshold, best_any);
            }
        }

        inline fn consider_claim(
            row: anytype,
            row_kind: RowKind,
            row_idx: IDX,
            claim_size: Vec,
            rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?T,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            const candidate_waste: T = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(claim_size) else 0;
            best_any.consider(waste_mode, row_kind, row_idx, claim_size, rotated, candidate_waste);
            if (threshold_value) |t| {
                if (row.new_height_is_within_threshold(t, claim_size.y)) {
                    best_threshold.consider(waste_mode, row_kind, row_idx, claim_size, rotated, candidate_waste);
                }
            }
        }

        inline fn first_fit_ready(waste_mode: WasteMode, threshold_value: ?T, best_threshold: Candidate, best_any: Candidate) ?Candidate {
            if (waste_mode != .IGNORE_WASTE) return null;
            if (threshold_value == null) {
                return if (best_any.kind == .none) null else best_any;
            }
            return if (best_threshold.kind == .none) null else best_threshold;
        }

        inline fn claim_candidate(self: *Self, candidate: Candidate, waste_mode: WasteMode) PosWithRotation {
            self.claim_count +|= 1;
            switch (candidate.kind) {
                .constrained => {
                    const row = &self.constrained_rows.zig_slice_entire()[candidate.row_idx];
                    const pos = if (waste_mode == .LEAST_WASTE)
                        row.claim_pos_known_waste(candidate.size, candidate.waste, &self.total_wasted_area)
                    else
                        row.claim_pos(candidate.size, &self.total_wasted_area);
                    return PosWithRotation.new(pos, candidate.rotated);
                },
                .unconstrained => {
                    const pos = if (waste_mode == .LEAST_WASTE)
                        self.unconstrained_row.claim_pos_known_waste(candidate.size, candidate.waste, &self.total_wasted_area)
                    else
                        self.unconstrained_row.claim_pos(candidate.size, &self.total_wasted_area);
                    return PosWithRotation.new(pos, candidate.rotated);
                },
                .none => unreachable,
            }
        }

        fn claim_on_new_row(self: *Self, size: Vec, rotated: bool) PosWithRotation {
            if (!self.unconstrained_row.is_empty()) {
                const closed_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                self.constrained_rows.append_one(closed_row, self.alloc);
            }
            self.claim_count +|= 1;
            return PosWithRotation.new(
                self.unconstrained_row.claim_pos_known_waste(size, 0, &self.total_wasted_area),
                rotated,
            );
        }

        inline fn try_claim_on_new_row(self: *Self, size: Vec, rot_size: Vec, allow_unrotated: bool, allow_rotated: bool) ?PosWithRotation {
            if (allow_unrotated and self.unconstrained_row.can_fit_size_on_new_row(size)) {
                return self.claim_on_new_row(size, false);
            }
            if (allow_rotated and self.unconstrained_row.can_fit_size_on_new_row(rot_size)) {
                return self.claim_on_new_row(rot_size, true);
            }
            return null;
        }

        pub const PosWithRotation = struct {
            pos: Vec = .{},
            is_rotated: bool = false,

            pub fn new(pos: Vec, is_rotated: bool) PosWithRotation {
                return PosWithRotation{
                    .pos = pos,
                    .is_rotated = is_rotated,
                };
            }
        };
        pub const RectWithRotation = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            is_rotated: bool = false,

            pub fn new(rect: Rect, is_rotated: bool) RectWithRotation {
                return RectWithRotation{
                    .rect = rect,
                    .is_rotated = is_rotated,
                };
            }

            pub fn top_left(self: RectWithRotation) Vec {
                if (self.is_rotated) {
                    return self.rect.top_right();
                }
                return self.rect.top_left();
            }
            pub fn top_right(self: RectWithRotation) Vec {
                if (self.is_rotated) {
                    return self.rect.bot_right();
                }
                return self.rect.top_right();
            }
            pub fn bot_left(self: RectWithRotation) Vec {
                if (self.is_rotated) {
                    return self.rect.top_left();
                }
                return self.rect.bot_left();
            }
            pub fn bot_right(self: RectWithRotation) Vec {
                if (self.is_rotated) {
                    return self.rect.bot_left();
                }
                return self.rect.bot_right();
            }
        };

        pub const AABB_WithRotation = struct {
            aabb: AABB = .{},
            is_rotated: bool = false,

            pub fn new(aabb: AABB, is_rotated: bool) AABB_WithRotation {
                return AABB_WithRotation{
                    .aabb = aabb,
                    .is_rotated = is_rotated,
                };
            }

            pub fn top_left(self: AABB_WithRotation) Vec {
                if (self.is_rotated) {
                    return self.aabb.top_right();
                }
                return self.aabb.top_left();
            }
            pub fn top_right(self: AABB_WithRotation) Vec {
                if (self.is_rotated) {
                    return self.aabb.bot_right();
                }
                return self.aabb.top_right();
            }
            pub fn bot_left(self: AABB_WithRotation) Vec {
                if (self.is_rotated) {
                    return self.aabb.top_left();
                }
                return self.aabb.bot_left();
            }
            pub fn bot_right(self: AABB_WithRotation) Vec {
                if (self.is_rotated) {
                    return self.aabb.bot_left();
                }
                return self.aabb.bot_right();
            }
        };

        const ConstrainedRow = struct {
            pos: Vec = .{},
            width: T = 0,
            min_height: T = 0,
            max_height: T = 0,

            pub inline fn can_fit_width(self: ConstrainedRow, width: T) bool {
                return self.width >= width;
            }
            pub inline fn can_fit_height(self: ConstrainedRow, height: T) bool {
                return self.max_height >= height;
            }
            pub inline fn can_fit_size(self: ConstrainedRow, size: Vec) bool {
                return self.width >= size.x and self.max_height >= size.y;
            }
            pub inline fn claim_pos(self: *ConstrainedRow, size: Vec, total_waste_ptr: *T) Vec {
                const waste = self.wasted_area_if_claimed(size);
                return self.claim_pos_known_waste(size, waste, total_waste_ptr);
            }
            pub inline fn claim_pos_known_waste(self: *ConstrainedRow, size: Vec, waste: T, total_waste_pointer: *T) Vec {
                const pos = self.pos;
                self.pos.x += size.x;
                self.width -= size.x;
                self.min_height = @min(self.min_height, size.y);
                total_waste_pointer.* += waste;
                return pos;
            }
            pub fn new_height_is_within_threshold(self: ConstrainedRow, threshold: T, height: T) bool {
                if (height > self.max_height) return false;
                const new_min = @min(self.min_height, height);
                return self.max_height - new_min <= threshold;
            }
            pub fn wasted_area_if_claimed(self: ConstrainedRow, size: Vec) T {
                return (self.max_height - size.y) * size.x;
            }
        };

        const UnconstrainedRow = struct {
            pos: Vec = .{},
            width: T = 0,
            used_width: T = 0,
            min_height: T = 0,
            max_height: T = 0,
            true_max_height: T = 0,

            fn init(region: Rect) UnconstrainedRow {
                return UnconstrainedRow{
                    .pos = region.pos,
                    .width = region.size.x,
                    .used_width = 0,
                    .min_height = MAX_HEIGHT,
                    .max_height = 0,
                    .true_max_height = region.size.y,
                };
            }
            pub inline fn is_empty(self: UnconstrainedRow) bool {
                return self.used_width == 0 and self.max_height == 0;
            }
            pub inline fn can_fit_size(self: UnconstrainedRow, size: Vec) bool {
                return self.width >= size.x and self.true_max_height >= size.y;
            }
            pub inline fn can_fit_size_on_new_row(self: UnconstrainedRow, size: Vec) bool {
                return self.width + self.used_width >= size.x and self.true_max_height - self.max_height >= size.y;
            }
            pub inline fn claim_pos(self: *UnconstrainedRow, size: Vec, total_waste_ptr: *T) Vec {
                const waste = self.wasted_area_if_claimed(size);
                return self.claim_pos_known_waste(size, waste, total_waste_ptr);
            }
            pub inline fn claim_pos_known_waste(self: *UnconstrainedRow, size: Vec, waste: T, total_waste_ptr: *T) Vec {
                const pos = self.pos;
                self.pos.x += size.x;
                self.width -= size.x;
                self.used_width += size.x;
                self.min_height = @min(self.min_height, size.y);
                self.max_height = @max(self.max_height, size.y);
                total_waste_ptr.* += waste;
                return pos;
            }

            pub fn new_height_is_within_threshold(self: UnconstrainedRow, threshold: T, height: T) bool {
                const new_min = @min(self.min_height, height);
                const new_max = @max(self.max_height, height);
                return new_max - new_min <= threshold;
            }
            pub fn wasted_area_if_claimed(self: UnconstrainedRow, size: Vec) T {
                if (size.y > self.max_height) {
                    // Growing the row exposes the area above the previously claimed,
                    // shorter rects.
                    const delta = size.y - self.max_height;
                    return delta * self.used_width;
                } else {
                    const delta = self.max_height - size.y;
                    return delta * size.x;
                }
            }

            pub fn extract_constrained_row(self: *UnconstrainedRow, full_region: Rect) ConstrainedRow {
                const row = ConstrainedRow{
                    .pos = self.pos,
                    .min_height = self.min_height,
                    .max_height = self.max_height,
                    .width = self.width,
                };
                self.pos.x = full_region.pos.x;
                self.pos.y += self.max_height;
                self.true_max_height -= self.max_height;
                self.max_height = 0;
                self.min_height = MAX_HEIGHT;
                self.width = full_region.size.x;
                self.used_width = 0;
                return row;
            }
        };
    };
}

pub const WasteMode = enum(u8) {
    IGNORE_WASTE,
    LEAST_WASTE,

    pub inline fn ignore_waste() WasteMode {
        return WasteMode.IGNORE_WASTE;
    }
    pub inline fn least_waste() WasteMode {
        return WasteMode.LEAST_WASTE;
    }
};

pub const ThresholdMode = enum(u8) {
    IGNORE_THRESHOLD,
    DEFAULT_THRESHOLD,
    CUSTOM_THRESHOLD,
};

pub const RotationMode = enum(u8) {
    DO_NOT_ALLOW_ROTATION,
    ALLOW_90_DEGREE_ROTATION,
    ALWAYS_FORCE_90_DEGREE_ROTATION,

    pub inline fn do_not_allow_rotation() RotationMode {
        return RotationMode.DO_NOT_ALLOW_ROTATION;
    }
    pub inline fn allow_90_degree_rotation() RotationMode {
        return RotationMode.ALLOW_90_DEGREE_ROTATION;
    }
    pub inline fn always_force_90_degree_rotation() RotationMode {
        return RotationMode.ALWAYS_FORCE_90_DEGREE_ROTATION;
    }
};
