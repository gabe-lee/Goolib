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

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const MathX = Root.Math;
const List = Root.IList.List;
const AABB2 = Root.AABB2;
const Rect2 = Root.Rect2;
const Vec2 = Root.Vec2;
const Allocator = std.mem.Allocator;
const DummyAlloc = Root.DummyAllocator;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

pub const FINAL_PASS_CREATE_NEW_ROW_THRESHOLD_MULTIPLIER = 2;

/// This packer works best with groups of rects that have relatively similar heights
/// (or similar widths to heights and/or widths to widths with the `rotation` settings)
pub fn RowPacker(comptime T: type) type {
    return struct {
        const Self = @This();
        const AABB = AABB2.define_aabb2_type(T);
        const Rect = Rect2.define_rect2_type(T);
        const Vec = Vec2.define_vec2_type(T);

        alloc: Allocator = DummyAlloc.allocator_panic,
        constrained_rows: List(ConstrainedRow) = .{},
        unconstrained_row: UnconstrainedRow = .{},
        full_region: Rect = .{},
        default_height_fit_threshold: T = 0,
        total_wasted_area: T = 0,

        pub fn init(cap: usize, region: Rect, default_height_fit_threshold: T, alloc: Allocator) Self {
            return Self{
                .alloc = alloc,
                .constrained_rows = .init_capacity(cap, alloc),
                .unconstrained_row = UnconstrainedRow{
                    .max_height = 0,
                    .min_height = region.h,
                    .true_max_height = region.h,
                    .pos = Vec.new(region.x, region.y),
                    .used_width = 0,
                    .width = region.w,
                },
                .full_region = region,
                .default_height_fit_threshold = default_height_fit_threshold,
                .total_wasted_area = 0,
            };
        }

        pub fn reset(self: *Self) void {
            self.constrained_rows.clear();
            self.unconstrained_row = UnconstrainedRow{
                .max_height = 0,
                .min_height = self.full_region.h,
                .true_max_height = self.full_region.h,
                .pos = Vec.new(self.full_region.x, self.full_region.y),
                .used_width = 0,
                .width = self.full_region.w,
            };
            self.total_wasted_area = 0;
        }

        pub fn free(self: *Self) void {
            self.constrained_rows.free(self.alloc);
            self.* = .{};
        }

        pub const Threshold = union(ThresholdMode) {
            IGNORE_THRESHOLD: void,
            DEFAULT_THRESHOLD: void,
            CUSTOM_THRESHOLD: T,

            pub inline fn ignore_threshold() Threshold {
                return Threshold{ .IGNORE_THRESHOLD = void{} };
            }
            pub inline fn default_threshold() Threshold {
                return Threshold{ .DEFAULT_THRESHOLD = void{} };
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
        /// should be treated as rotated 90 degrees (`rect.w == size.y` AND `rect.h == size.x`)
        pub fn claim_rect(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode) ?RectWithRotation {
            if (self.claim_position(size, threshold, waste)) |pos_with_rot| {
                return RectWithRotation{
                    .rect = if (pos_with_rot.is_rotated) Rect{
                        .x = pos_with_rot.x,
                        .y = pos_with_rot.y,
                        .w = size.y,
                        .h = size.x,
                    } else Rect{
                        .x = pos_with_rot.x,
                        .y = pos_with_rot.y,
                        .w = size.x,
                        .h = size.y,
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
                        .x_min = pos_with_rot.x,
                        .y_min = pos_with_rot.y,
                        .x_max = pos_with_rot.x + size.y,
                        .y_max = pos_with_rot.y + size.x,
                    } else AABB{
                        .x_min = pos_with_rot.x,
                        .y_min = pos_with_rot.y,
                        .x_max = pos_with_rot.x + size.x,
                        .y_max = pos_with_rot.y + size.y,
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
            if (size.x > self.full_region.w or size.y > self.full_region.h) return null;
            const rot_size = Vec.new(size.y, size.x);
            var row_idx: u32 = 0;
            var best_row_idx: u32 = 0;
            var best_row_waste: T = MathX.max_value(T);
            var found_row: FoundRowResult = .DID_NOT_FIND_ROW;
            var best_is_rotated: bool = false;
            recheck: switch (threshold) {
                else => |thresh| {
                    while (row_idx < self.constrained_rows.len) : (row_idx += 1) {
                        const row = self.constrained_rows.ptr[row_idx];
                        if (rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION) {
                            const can_fit = switch (thresh) {
                                .CUSTOM_THRESHOLD => |t| row.can_fit_size(size) and row.new_height_is_within_threshold(t, size.y),
                                .DEFAULT_THRESHOLD => row.can_fit_size(size) and row.new_height_is_within_threshold(self.default_height_fit_threshold, size.y),
                                .IGNORE_THRESHOLD => row.can_fit_size(size),
                            };
                            if (can_fit) {
                                switch (waste) {
                                    .IGNORE_WASTE => {
                                        return PosWithRotation.new(self.constrained_rows.ptr[row_idx].claim_pos(size, &self.total_wasted_area), false);
                                    },
                                    .LEAST_WASTE => {
                                        const this_waste = row.wasted_area_if_claimed(size);
                                        best_is_rotated = false;
                                        switch (found_row) {
                                            .DID_NOT_FIND_ROW => {
                                                @branchHint(.unlikely);
                                                best_row_idx = row_idx;
                                                best_row_waste = this_waste;
                                                found_row = .FOUND_CONSTRAINED_ROW;
                                            },
                                            else => {
                                                if (this_waste < best_row_waste) {
                                                    best_row_idx = row_idx;
                                                    best_row_waste = this_waste;
                                                }
                                            },
                                        }
                                    },
                                }
                            }
                        }
                        if (rotation != .DO_NOT_ALLOW_ROTATION) {
                            const can_fit = switch (thresh) {
                                .CUSTOM_THRESHOLD => |t| row.can_fit_size(rot_size) and row.new_height_is_within_threshold(t, rot_size.y),
                                .DEFAULT_THRESHOLD => row.can_fit_size(rot_size) and row.new_height_is_within_threshold(self.default_height_fit_threshold, rot_size.y),
                                .IGNORE_THRESHOLD => row.can_fit_size(rot_size),
                            };
                            if (can_fit) {
                                switch (waste) {
                                    .IGNORE_WASTE => {
                                        return PosWithRotation.new(self.constrained_rows.ptr[row_idx].claim_pos(rot_size, &self.total_wasted_area), true);
                                    },
                                    .LEAST_WASTE => {
                                        const this_waste = row.wasted_area_if_claimed(rot_size);
                                        best_is_rotated = true;
                                        switch (found_row) {
                                            .DID_NOT_FIND_ROW => {
                                                @branchHint(.unlikely);
                                                best_row_idx = row_idx;
                                                best_row_waste = this_waste;
                                                found_row = .FOUND_CONSTRAINED_ROW;
                                            },
                                            else => {
                                                if (this_waste < best_row_waste) {
                                                    best_row_idx = row_idx;
                                                    best_row_waste = this_waste;
                                                }
                                            },
                                        }
                                    },
                                }
                            }
                        }
                    }
                    if (rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION) {
                        const can_fit = switch (thresh) {
                            .CUSTOM_THRESHOLD => |t| self.unconstrained_row.can_fit_size(size) and self.unconstrained_row.new_height_is_within_threshold(t, size.y),
                            .DEFAULT_THRESHOLD => self.unconstrained_row.can_fit_size(size) and self.unconstrained_row.new_height_is_within_threshold(self.default_height_fit_threshold, size.y),
                            .IGNORE_THRESHOLD => self.unconstrained_row.can_fit_size(size),
                        };
                        if (can_fit) {
                            switch (waste) {
                                .IGNORE_WASTE => {
                                    return self.unconstrained_row.claim_pos(size, &self.total_wasted_area);
                                },
                                .LEAST_WASTE => {
                                    const this_waste = self.unconstrained_row.wasted_area_if_claimed(size);
                                    best_is_rotated = false;
                                    switch (found_row) {
                                        .DID_NOT_FIND_ROW => {
                                            @branchHint(.unlikely);
                                            best_row_waste = this_waste;
                                            found_row = .FOUND_UNCONSTRAINED_ROW;
                                        },
                                        else => {
                                            if (this_waste < best_row_waste) {
                                                best_row_waste = this_waste;
                                                found_row = .FOUND_UNCONSTRAINED_ROW;
                                            }
                                        },
                                    }
                                },
                            }
                        }
                    }
                    if (rotation != .DO_NOT_ALLOW_ROTATION) {
                        const can_fit = switch (thresh) {
                            .CUSTOM_THRESHOLD => |t| self.unconstrained_row.can_fit_size(rot_size) and self.unconstrained_row.new_height_is_within_threshold(t, rot_size.y),
                            .DEFAULT_THRESHOLD => self.unconstrained_row.can_fit_size(rot_size) and self.unconstrained_row.new_height_is_within_threshold(self.default_height_fit_threshold, rot_size.y),
                            .IGNORE_THRESHOLD => self.unconstrained_row.can_fit_size(rot_size),
                        };
                        if (can_fit) {
                            switch (waste) {
                                .IGNORE_WASTE => {
                                    return self.unconstrained_row.claim_pos(rot_size, &self.total_wasted_area);
                                },
                                .LEAST_WASTE => {
                                    const this_waste = self.unconstrained_row.wasted_area_if_claimed(rot_size);
                                    best_is_rotated = true;
                                    switch (found_row) {
                                        .DID_NOT_FIND_ROW => {
                                            @branchHint(.unlikely);
                                            best_row_waste = this_waste;
                                            found_row = .FOUND_UNCONSTRAINED_ROW;
                                        },
                                        else => {
                                            if (this_waste < best_row_waste) {
                                                best_row_waste = this_waste;
                                                found_row = .FOUND_UNCONSTRAINED_ROW;
                                            }
                                        },
                                    }
                                },
                            }
                        }
                    }
                    switch (thresh) {
                        .DEFAULT_THRESHOLD, .CUSTOM_THRESHOLD => switch (found_row) {
                            .DID_NOT_FIND_ROW => {
                                if (rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION and self.unconstrained_row.can_fit_size_on_new_row(size)) {
                                    const new_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                                    const new_row_idx = self.constrained_rows.append(new_row, self.alloc);
                                    return PosWithRotation.new(self.constrained_rows.ptr[new_row_idx].claim_pos_known_waste(size, 0, &self.total_wasted_area), false);
                                }
                                if (rotation != .DO_NOT_ALLOW_ROTATION and self.unconstrained_row.can_fit_size_on_new_row(rot_size)) {
                                    const new_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                                    const new_row_idx = self.constrained_rows.append(new_row, self.alloc);
                                    return PosWithRotation.new(self.constrained_rows.ptr[new_row_idx].claim_pos_known_waste(rot_size, 0, &self.total_wasted_area), true);
                                }
                                row_idx = 0;
                                continue :recheck Threshold.ignore_threshold();
                            },
                            .FOUND_CONSTRAINED_ROW => {
                                if (best_is_rotated) {
                                    return PosWithRotation.new(self.constrained_rows.ptr[best_row_idx].claim_pos_known_waste(rot_size, best_row_waste, &self.total_wasted_area), true);
                                } else {
                                    return PosWithRotation.new(self.constrained_rows.ptr[best_row_idx].claim_pos_known_waste(size, best_row_waste, &self.total_wasted_area), false);
                                }
                            },
                            .FOUND_UNCONSTRAINED_ROW => {
                                if (best_is_rotated) {
                                    return PosWithRotation.new(self.unconstrained_row.claim_pos_known_waste(rot_size, best_row_waste, &self.total_wasted_area), true);
                                } else {
                                    return PosWithRotation.new(self.unconstrained_row.claim_pos_known_waste(size, best_row_waste, &self.total_wasted_area), false);
                                }
                            },
                        },
                        .IGNORE_THRESHOLD => switch (found_row) {
                            .DID_NOT_FIND_ROW => {
                                return null;
                            },
                            .FOUND_CONSTRAINED_ROW => {
                                if (best_is_rotated) {
                                    return PosWithRotation.new(self.constrained_rows.ptr[best_row_idx].claim_pos_known_waste(rot_size, best_row_waste, &self.total_wasted_area), true);
                                } else {
                                    return PosWithRotation.new(self.constrained_rows.ptr[best_row_idx].claim_pos_known_waste(size, best_row_waste, &self.total_wasted_area), false);
                                }
                            },
                            .FOUND_UNCONSTRAINED_ROW => {
                                // This optimization can help when `waste == .LEAST_WASTE` and `threshold == .IGNORE_THRESHOLD`
                                // and the height is *significantly* greater than or less than the current unconstrained row max height...
                                //
                                // Starting a new row may result in less waste than forcing an overly large/small rect into the current
                                // unconstrained row.
                                if (waste == .LEAST_WASTE) {
                                    const extended_threshold = self.default_height_fit_threshold * FINAL_PASS_CREATE_NEW_ROW_THRESHOLD_MULTIPLIER;
                                    if (rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION and self.unconstrained_row.can_fit_size_on_new_row(size) and !self.unconstrained_row.new_height_is_within_threshold(extended_threshold, size.y)) {
                                        const new_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                                        const new_row_idx = self.constrained_rows.append(new_row, self.alloc);
                                        return PosWithRotation.new(self.constrained_rows.ptr[new_row_idx].claim_pos_known_waste(size, 0, &self.total_wasted_area), false);
                                    }
                                    if (rotation != .DO_NOT_ALLOW_ROTATION and self.unconstrained_row.can_fit_size_on_new_row(rot_size) and !self.unconstrained_row.new_height_is_within_threshold(extended_threshold, rot_size.y)) {
                                        const new_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                                        const new_row_idx = self.constrained_rows.append(new_row, self.alloc);
                                        return PosWithRotation.new(self.constrained_rows.ptr[new_row_idx].claim_pos_known_waste(rot_size, 0, &self.total_wasted_area), true);
                                    }
                                }
                                if (best_is_rotated) {
                                    return PosWithRotation.new(self.unconstrained_row.claim_pos_known_waste(rot_size, best_row_waste, &self.total_wasted_area), true);
                                } else {
                                    return PosWithRotation.new(self.unconstrained_row.claim_pos_known_waste(size, best_row_waste, &self.total_wasted_area), false);
                                }
                            },
                        },
                    }
                },
            }
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
            rect: Rect = .{},
            is_rotated: bool = false,

            pub fn new(rect: Rect, is_rotated: bool) RectWithRotation {
                return RectWithRotation{
                    .rect = rect,
                    .is_rotated = is_rotated,
                };
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
                const new_min = @min(self.min_height, height);
                const new_range = self.max_height - new_min;
                return new_range <= threshold;
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

            pub inline fn can_fit_size(self: UnconstrainedRow, size: Vec) bool {
                return self.width >= size.x and self.true_max_height >= size.y;
            }
            // assumes that a broad check asserting `size.x <= full_region.w` has already been done
            pub inline fn can_fit_size_on_new_row(self: UnconstrainedRow, size: Vec) bool {
                const new_true_max_height = self.true_max_height - self.max_height;
                return new_true_max_height >= size.y;
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
                const new_range = new_max - new_min;
                return new_range <= threshold;
            }
            pub fn wasted_area_if_claimed(self: UnconstrainedRow, size: Vec) T {
                if (size.y > self.max_height) {
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
                self.pos.x = full_region.x;
                self.pos.y = self.max_height;
                self.true_max_height -= self.max_height;
                self.max_height = 0;
                self.min_height = self.true_max_height;
                self.width = full_region.w;
                self.used_width = 0;
                return row;
            }

            // pub fn range_growth_for_new_height(self: UnconstrainedRow, new_height: T) T {
            //     const curr_range = self.max_height - self.min_height;
            //     const new_range
            // }
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

const ThresholdWasteMode = enum(u8) {
    IGNORE_T_IGNORE_W,
    IGNORE_T_LEAST_W,
    USE_T_IGNORE_W,
    USE_T_LEAST_W,
};

const FoundRowResult = enum(u8) {
    DID_NOT_FIND_ROW,
    FOUND_CONSTRAINED_ROW,
    FOUND_UNCONSTRAINED_ROW,
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
    pub inline fn always_force_90_degree_roation() RotationMode {
        return RotationMode.ALWAYS_FORCE_90_DEGREE_ROTATION;
    }
};
