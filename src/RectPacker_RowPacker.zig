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
const Cast = Root.Cast;
const MathX = Root.Math;
const ListFull = Root.ListSlice.ListFullDefinition;
const Pool = Root.Pool.Pool;
const AABB2 = Root.AABB2;
const Rect2 = Root.Rect2;
const Vec2 = Root.Vec2;
const Allocator = std.mem.Allocator;
const DummyAlloc = Root.DummyAllocator;
const Assert = Root.Assert;
const CachedAllocMode = Root.CommonTypes.CachedAllocMode;
const HashMapModule = Root.HashMap.SwissTableHashMapModule;
const HashMap = HashMapModule.SwissHashMap;
const HashMapOverrides = HashMapModule.Overrides;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Cast.num_cast;

comptime {
    if (build.is_test) {
        _ = @import("./RectPacker_Tests.zig");
    }
}

pub const ReleaseMode = enum {
    /// Rects can only be claimed. Released rects are not tracked, which keeps the
    /// packer state smaller.
    CLAIM_ONLY,
    /// Rects can be claimed and released. Released rects become reusable holes.
    CLAIM_AND_RELEASE,
};

/// Packs rectangles into horizontal rows (shelves), filling each row from smaller x values
/// to larger x values, and starting each new row at a larger y position.
///
/// The `Threshold` arguments are preferences, not hard limits. When a threshold is
/// requested and no existing row has a compatible height within the threshold, a new row is started if
/// there is vertical room; otherwise the least-waste (or first, depending on
/// `WasteMode`) fitting row is used anyway. This packer works best with groups of
/// rectangles that have relatively similar heights (or similar widths-to-heights
/// and widths-to-widths with the `rotation` settings).
///
/// When constructed with `.CLAIM_AND_RELEASE`, a released rect becomes a hole in its
/// row and later claims will fill holes before extending the row's unused tail.
/// Individual live rects cannot be moved or resized.
pub fn RowPacker(comptime T_SIZE: type, comptime IDX: type, comptime RELEASE_MODE: ReleaseMode, comptime ALLOC: CachedAllocMode) type {
    return struct {
        const Self = @This();
        pub const AABB = AABB2.define_aabb2_type(T_SIZE);
        pub const Rect = Rect2.define_rect2_type(T_SIZE);
        pub const Vec = Vec2.define_vec2_type(T_SIZE);
        const RowList = ListFull(ConstrainedRow, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, .MANUAL_ALLOC);
        const CAN_RELEASE = RELEASE_MODE == .CLAIM_AND_RELEASE;
        const HolePool = Pool(.{
            .LIST_DEF = .{
                .ELEM = Hole,
                .FIELD_LAYOUT = .WHOLE_STRUCTS,
                .IDX = IDX,
                .INDEX_LAYOUT = .SERIAL_INDEXES,
                .OWNERSHIP = .OWNED_ALLOCATED,
            },
            .BLOCK_SIZE = 64,
            .THREADING = .SINGLE_THREADED,
        }, Hole{});
        const MAX_HEIGHT: T_SIZE = MathX.max_value(T_SIZE);

        inline fn doubled_threshold(value: ThresholdVal) ThresholdVal {
            return switch (@typeInfo(T_SIZE)) {
                .int => ThresholdVal{
                    .flat_tolerance = value.flat_tolerance *| 2,
                    .percent = value.percent * 0.5,
                },
                .float => ThresholdVal{
                    .flat_tolerance = value.flat_tolerance * 2,
                    .percent = value.percent * 0.5,
                },
                else => @compileError("RowPacker requires an integer or floating-point coordinate type"),
            };
        }

        cached_alloc: ALLOC.CachedAlloc() = ALLOC.CACHED_ALLOC_DEFAULT(),
        constrained_rows: RowList = .{},
        holes_pool: if (CAN_RELEASE) HolePool else void = if (CAN_RELEASE) HolePool{ .alloc = DummyAlloc.allocator_panic } else {},
        unconstrained_row: UnconstrainedRow = .{},
        full_region: Rect = .{ .pos = .{}, .size = .{} },
        default_height_fit_threshold: ThresholdVal = .threshold_val(0.9, 4),
        total_wasted_area: T_SIZE = 0,
        claim_count: IDX = 0,

        pub const ThresholdVal = struct {
            percent: f32 = 0.9,
            flat_tolerance: T_SIZE = 10,

            pub fn threshold_val(percent: f32, flat_tolerance: T_SIZE) ThresholdVal {
                return ThresholdVal{
                    .percent = percent,
                    .flat_tolerance = flat_tolerance,
                };
            }
        };

        fn assert_can_release(src: ?std.builtin.SourceLocation) void {
            assert_with_reason(CAN_RELEASE, src, "cannot release rects when packer defined as .CLAIM_ONLY", .{});
        }

        pub fn init(cap: IDX, region: Rect, default_height_fit_threshold: ThresholdVal, alloc: Allocator) Self {
            var self = Self{
                .cached_alloc = ALLOC.alloc_to_cached_alloc(alloc),
                .constrained_rows = RowList.allocate_new(cap, alloc),
                .unconstrained_row = UnconstrainedRow.init(region),
                .full_region = region,
                .default_height_fit_threshold = default_height_fit_threshold,
                .total_wasted_area = 0,
                .claim_count = 0,
            };
            if (CAN_RELEASE) {
                self.holes_pool = HolePool{ .alloc = alloc };
            }
            return self;
        }
        pub fn init_empty(region: Rect, default_height_fit_threshold: ThresholdVal, alloc: ALLOC.FuncParamAlloc()) Self {
            var self = Self{
                .cached_alloc = alloc,
                .constrained_rows = RowList{},
                .unconstrained_row = UnconstrainedRow.init(region),
                .full_region = region,
                .default_height_fit_threshold = default_height_fit_threshold,
                .total_wasted_area = 0,
                .claim_count = 0,
            };
            if (CAN_RELEASE) {
                self.holes_pool = HolePool{ .alloc = alloc };
            }
            return self;
        }

        pub fn reset(self: *Self) void {
            self.constrained_rows.clear();
            self.unconstrained_row = UnconstrainedRow.init(self.full_region);
            self.total_wasted_area = 0;
            self.claim_count = 0;
            if (CAN_RELEASE) {
                self.holes_pool.clear_retain_blocks();
            }
        }

        pub fn free(self: *Self, alloc: ALLOC.FuncParamAlloc()) void {
            self.constrained_rows.free_if_non_zero(ALLOC.get_alloc(alloc, self.cached_alloc));
            if (CAN_RELEASE) {
                self.holes_pool.free_pool();
            }
            self.* = .{};
        }

        pub const Threshold = union(ThresholdMode) {
            IGNORE_THRESHOLD: void,
            DEFAULT_THRESHOLD: void,
            CUSTOM_THRESHOLD: ThresholdVal,

            pub inline fn ignore_threshold() Threshold {
                return Threshold{ .IGNORE_THRESHOLD = {} };
            }
            pub inline fn default_threshold() Threshold {
                return Threshold{ .DEFAULT_THRESHOLD = {} };
            }
            pub inline fn custom_threshold(percent: f32, flat_tolerance: T_SIZE) Threshold {
                return Threshold{ .CUSTOM_THRESHOLD = .threshold_val(percent, flat_tolerance) };
            }
        };

        /// A null value indicates there were no available spaces for the given size
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, the returned result's `is_rotated` field indicates whether the space
        /// should be treated as rotated 90 degrees (`rect.size.x == size.y` AND `rect.size.y == size.x`)
        pub fn claim_rect(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode, alloc: ALLOC.FuncParamAlloc()) ?PackedRect {
            if (self.claim_position(size, threshold, waste, rotation, alloc)) |pos_with_rot| {
                return PackedRect{
                    .rect = if (pos_with_rot.is_rotated) Rect{
                        .pos = pos_with_rot.pos,
                        .size = size.flip_components(),
                    } else Rect{
                        .pos = pos_with_rot.pos,
                        .size = size,
                    },
                    .is_rotated = pos_with_rot.is_rotated,
                    .row_idx = pos_with_rot.row_idx,
                };
            }
            return null;
        }

        /// A null value indicates there were no available spaces for the given size
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, the returned result's `is_rotated` field indicates whether the space
        /// should be treated as rotated 90 degrees (`(aabb.x_max - aabb.x_min) == size.y` AND `(aabb.y_max - aabb.y_min) == size.x`)
        pub fn claim_aabb(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode, alloc: ALLOC.FuncParamAlloc()) ?PackedAABB {
            if (self.claim_position(size, threshold, waste, rotation, alloc)) |pos_with_rot| {
                return PackedAABB{
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
                    .row_idx = pos_with_rot.row_idx,
                };
            }
            return null;
        }

        fn claim_position(self: *Self, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode, alloc: ALLOC.FuncParamAlloc()) ?PackedPos {
            const allow_unrotated = rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION;
            const allow_rotated = switch (rotation) {
                .DO_NOT_ALLOW_ROTATION => false,
                .ALLOW_90_DEGREE_ROTATION => size.x != size.y,
                .ALWAYS_FORCE_90_DEGREE_ROTATION => true,
            };

            const fits_region_unrotated = size.x <= self.full_region.size.x and size.y <= self.full_region.size.y;
            const fits_region_rotated = size.y <= self.full_region.size.x and size.x <= self.full_region.size.y;
            if ((!allow_unrotated or !fits_region_unrotated) and (!allow_rotated or !fits_region_rotated)) return null;

            const rot_size = size.flip_components();
            const threshold_value: ?ThresholdVal = switch (threshold) {
                .IGNORE_THRESHOLD => null,
                .DEFAULT_THRESHOLD => self.default_height_fit_threshold,
                .CUSTOM_THRESHOLD => |t| t,
            };

            var best_any: Candidate = .{};
            var best_threshold: Candidate = .{};

            const rows = self.constrained_rows.zig_slice_entire();
            const constrained_row_count = self.constrained_rows.get_len();
            var constrained_row_idx: IDX = 0;
            while (constrained_row_idx < constrained_row_count) : (constrained_row_idx += 1) {
                evaluate_constrained_row(rows[constrained_row_idx], constrained_row_idx, size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, waste);
                }
            }

            evaluate_unconstrained_row(self.unconstrained_row, self.constrained_rows.get_len(), size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
            if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                return self.claim_candidate(candidate, waste);
            }

            const selected = if (best_threshold.kind != .NONE) best_threshold else best_any;
            if (best_threshold.kind == .NONE and threshold_value != null) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, alloc)) |pos| {
                    return pos;
                }
            }
            if (selected.kind == .NONE) {
                if (threshold_value != null) return null;
                return self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, alloc);
            }
            if (waste == .LEAST_WASTE and best_threshold.kind == .NONE and selected.kind == .UNCONSTRAINED and selected.hole == null) {
                const extended_threshold = doubled_threshold(threshold_value orelse self.default_height_fit_threshold);
                if (self.unconstrained_row.can_fit_size_on_new_row(selected.size) and
                    !self.unconstrained_row.new_height_is_within_threshold(extended_threshold, selected.size.y))
                {
                    return self.claim_on_new_row(selected.size, selected.rotated, alloc);
                }
            }

            return self.claim_candidate(selected, waste);
        }

        const RowKind = enum(u2) {
            NONE,
            CONSTRAINED,
            UNCONSTRAINED,
        };

        const Candidate = struct {
            kind: RowKind = .NONE,
            row_idx: IDX = 0,
            size: Vec = .{},
            rotated: bool = false,
            waste: T_SIZE = 0,
            hole: ?*Hole = null,

            inline fn consider(self: *Candidate, waste_mode: WasteMode, kind: RowKind, row_idx: IDX, claim_size: Vec, rotated: bool, candidate_waste: T_SIZE, hole: ?*Hole) void {
                if (self.kind == .NONE or (waste_mode == .LEAST_WASTE and candidate_waste < self.waste)) {
                    self.* = .{
                        .kind = kind,
                        .row_idx = row_idx,
                        .size = claim_size,
                        .rotated = rotated,
                        .waste = candidate_waste,
                        .hole = hole,
                    };
                }
            }
        };

        inline fn evaluate_constrained_row(
            row: ConstrainedRow,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            evaluate_holes(row, .CONSTRAINED, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste_mode, threshold_value, best_threshold, best_any);
            if (allow_unrotated and row.can_fit_size(size)) {
                consider_constrained_claim(row, row_idx, size, false, waste_mode, threshold_value, best_threshold, best_any);
            }
            if (allow_rotated and row.can_fit_size(rot_size)) {
                consider_constrained_claim(row, row_idx, rot_size, true, waste_mode, threshold_value, best_threshold, best_any);
            }
        }

        inline fn evaluate_unconstrained_row(
            row: UnconstrainedRow,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            evaluate_holes(row, .UNCONSTRAINED, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste_mode, threshold_value, best_threshold, best_any);
            if (allow_unrotated and row.can_fit_size(size)) {
                consider_unconstrained_claim(row, row_idx, size, false, waste_mode, threshold_value, best_threshold, best_any);
            }
            if (allow_rotated and row.can_fit_size(rot_size)) {
                consider_unconstrained_claim(row, row_idx, rot_size, true, waste_mode, threshold_value, best_threshold, best_any);
            }
        }

        inline fn evaluate_holes(
            row: anytype,
            row_kind: RowKind,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            var maybe_hole = row.next_hole;
            while (maybe_hole) |hole| : (maybe_hole = hole.next) {
                const hole_size = hole.rect.size;
                if (allow_unrotated and hole_size.x >= size.x and hole_size.y >= size.y) {
                    consider_hole_claim(hole, row_kind, row_idx, size, false, waste_mode, threshold_value, best_threshold, best_any);
                }
                if (allow_rotated and hole_size.x >= rot_size.x and hole_size.y >= rot_size.y) {
                    consider_hole_claim(hole, row_kind, row_idx, rot_size, true, waste_mode, threshold_value, best_threshold, best_any);
                }
            }
        }

        inline fn consider_hole_claim(
            hole: *Hole,
            row_kind: RowKind,
            row_idx: IDX,
            claim_size: Vec,
            rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            const candidate_waste: T_SIZE = if (waste_mode == .LEAST_WASTE) hole.wasted_area_if_claimed(claim_size) else 0;
            best_any.consider(waste_mode, row_kind, row_idx, claim_size, rotated, candidate_waste, hole);
            if (threshold_value != null) {
                best_threshold.consider(waste_mode, row_kind, row_idx, claim_size, rotated, candidate_waste, hole);
            }
        }

        inline fn consider_unconstrained_claim(
            row: UnconstrainedRow,
            row_idx: IDX,
            claim_size: Vec,
            rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            const candidate_waste: T_SIZE = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(claim_size) else 0;
            best_any.consider(waste_mode, .UNCONSTRAINED, row_idx, claim_size, rotated, candidate_waste, null);
            if (threshold_value) |t| {
                if (row.new_height_is_within_threshold(t, claim_size.y)) {
                    best_threshold.consider(waste_mode, .UNCONSTRAINED, row_idx, claim_size, rotated, candidate_waste, null);
                }
            }
        }
        inline fn consider_constrained_claim(
            row: ConstrainedRow,
            row_idx: IDX,
            claim_size: Vec,
            rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            const candidate_waste: T_SIZE = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(claim_size) else 0;
            best_any.consider(waste_mode, .CONSTRAINED, row_idx, claim_size, rotated, candidate_waste, null);
            if (threshold_value) |t| {
                if (row.new_height_is_within_threshold(t, claim_size.y)) {
                    best_threshold.consider(waste_mode, .CONSTRAINED, row_idx, claim_size, rotated, candidate_waste, null);
                }
            }
        }

        inline fn first_fit_ready(waste_mode: WasteMode, threshold_value: ?ThresholdVal, best_threshold: Candidate, best_any: Candidate) ?Candidate {
            if (waste_mode != .IGNORE_WASTE) return null;
            if (threshold_value == null) {
                return if (best_any.kind == .NONE) null else best_any;
            }
            return if (best_threshold.kind == .NONE) null else best_threshold;
        }

        inline fn claim_candidate(self: *Self, candidate: Candidate, waste_mode: WasteMode) PackedPos {
            self.claim_count +|= 1;
            switch (candidate.kind) {
                .CONSTRAINED => {
                    const row = &self.constrained_rows.zig_slice_entire()[candidate.row_idx];
                    if (CAN_RELEASE) {
                        if (candidate.hole) |hole| {
                            return PackedPos.new(claim_from_hole(row, hole, candidate.size, &self.holes_pool), candidate.rotated, candidate.row_idx);
                        }
                    }
                    const pos = if (waste_mode == .LEAST_WASTE)
                        row.claim_pos_known_waste(candidate.size, candidate.waste, &self.total_wasted_area)
                    else
                        row.claim_pos(candidate.size, &self.total_wasted_area);
                    return PackedPos.new(pos, candidate.rotated, candidate.row_idx);
                },
                .UNCONSTRAINED => {
                    if (CAN_RELEASE) {
                        if (candidate.hole) |hole| {
                            return PackedPos.new(claim_from_hole(&self.unconstrained_row, hole, candidate.size, &self.holes_pool), candidate.rotated, candidate.row_idx);
                        }
                    }
                    const pos = if (waste_mode == .LEAST_WASTE)
                        self.unconstrained_row.claim_pos_known_waste(candidate.size, candidate.waste, &self.total_wasted_area)
                    else
                        self.unconstrained_row.claim_pos(candidate.size, &self.total_wasted_area);
                    return PackedPos.new(pos, candidate.rotated, candidate.row_idx);
                },
                .NONE => unreachable,
            }
        }

        fn remove_hole(row: anytype, hole: *Hole) void {
            var link = &row.next_hole;
            while (link.*) |node| {
                if (node == hole) {
                    link.* = node.next;
                    return;
                }
                link = &node.next;
            }
            assert_unreachable(@src(), "hole was not found in the row's hole list", .{});
        }

        /// Removes `hole` from `row` and replaces it with up to two smaller holes
        /// covering the area left over by `size`.
        fn claim_from_hole(row: anytype, hole: *Hole, size: Vec, hole_pool: *HolePool) Vec {
            const hole_rect = hole.rect;
            remove_hole(row, hole);

            const remaining_width = hole_rect.size.x - size.x;
            const remaining_height = hole_rect.size.y - size.y;
            if (remaining_width > 0 and remaining_height > 0) {
                const existing_holes = row.next_hole;
                hole.rect = Rect.new(
                    Vec.new(hole_rect.pos.x + size.x, hole_rect.pos.y),
                    Vec.new(remaining_width, hole_rect.size.y),
                );
                hole.next = existing_holes;

                const bottom_hole = hole_pool.claim();
                bottom_hole.rect = Rect.new(
                    Vec.new(hole_rect.pos.x, hole_rect.pos.y + size.y),
                    Vec.new(size.x, remaining_height),
                );
                bottom_hole.next = hole;
                row.next_hole = bottom_hole;
            } else if (remaining_width > 0) {
                hole.rect = Rect.new(
                    Vec.new(hole_rect.pos.x + size.x, hole_rect.pos.y),
                    Vec.new(remaining_width, hole_rect.size.y),
                );
                hole.next = row.next_hole;
                row.next_hole = hole;
            } else if (remaining_height > 0) {
                hole.rect = Rect.new(
                    Vec.new(hole_rect.pos.x, hole_rect.pos.y + size.y),
                    Vec.new(hole_rect.size.x, remaining_height),
                );
                hole.next = row.next_hole;
                row.next_hole = hole;
            } else {
                hole_pool.release(hole);
            }
            row.num_claimed += 1;
            return hole_rect.pos;
        }

        fn claim_on_new_row(self: *Self, size: Vec, rotated: bool, alloc: ALLOC.FuncParamAlloc()) PackedPos {
            if (!self.unconstrained_row.is_empty()) {
                const closed_row = self.unconstrained_row.extract_constrained_row(self.full_region);
                self.constrained_rows.append_one(closed_row, ALLOC.get_alloc(alloc, self.cached_alloc));
            }
            self.claim_count +|= 1;
            return PackedPos.new(
                self.unconstrained_row.claim_pos_known_waste(size, 0, &self.total_wasted_area),
                rotated,
                self.constrained_rows.get_len(),
            );
        }

        inline fn try_claim_on_new_row(self: *Self, size: Vec, rot_size: Vec, allow_unrotated: bool, allow_rotated: bool, alloc: ALLOC.FuncParamAlloc()) ?PackedPos {
            if (allow_unrotated and self.unconstrained_row.can_fit_size_on_new_row(size)) {
                return self.claim_on_new_row(size, false, alloc);
            }
            if (allow_rotated and self.unconstrained_row.can_fit_size_on_new_row(rot_size)) {
                return self.claim_on_new_row(rot_size, true, alloc);
            }
            return null;
        }

        pub const PackedPos = struct {
            pos: Vec = .{},
            is_rotated: bool = false,
            row_idx: IDX = 0,

            pub fn new(pos: Vec, is_rotated: bool, row_idx: IDX) PackedPos {
                return PackedPos{
                    .pos = pos,
                    .is_rotated = is_rotated,
                    .row_idx = row_idx,
                };
            }
        };
        pub const PackedRect = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            is_rotated: bool = false,
            row_idx: IDX = 0,

            pub fn new(rect: Rect, is_rotated: bool, row_idx: IDX) PackedRect {
                return PackedRect{
                    .rect = rect,
                    .is_rotated = is_rotated,
                    .row_idx = row_idx,
                };
            }
            pub fn to_packed_aabb(self: PackedRect) PackedAABB {
                return PackedAABB{
                    .aabb = self.rect.to_aabb2(),
                    .is_rotated = self.is_rotated,
                    .row_idx = self.row_idx,
                };
            }

            pub fn top_left(self: PackedRect) Vec {
                if (self.is_rotated) {
                    return self.rect.top_right();
                }
                return self.rect.top_left();
            }
            pub fn top_right(self: PackedRect) Vec {
                if (self.is_rotated) {
                    return self.rect.bot_right();
                }
                return self.rect.top_right();
            }
            pub fn bot_left(self: PackedRect) Vec {
                if (self.is_rotated) {
                    return self.rect.top_left();
                }
                return self.rect.bot_left();
            }
            pub fn bot_right(self: PackedRect) Vec {
                if (self.is_rotated) {
                    return self.rect.bot_left();
                }
                return self.rect.bot_right();
            }

            pub fn equals(self: PackedRect, other: PackedRect) bool {
                return self.rect.equals(other.rect) and self.is_rotated == other.is_rotated and self.row_idx == other.row_idx;
            }
        };

        pub const PackedAABB = struct {
            aabb: AABB = .{},
            is_rotated: bool = false,
            row_idx: IDX = 0,

            pub fn new(aabb: AABB, is_rotated: bool, row_idx: IDX) PackedAABB {
                return PackedAABB{
                    .aabb = aabb,
                    .is_rotated = is_rotated,
                    .row_idx = row_idx,
                };
            }
            pub fn to_packed_rect(self: PackedAABB) PackedRect {
                return PackedRect{
                    .rect = self.aabb.to_rect2(),
                    .is_rotated = self.is_rotated,
                    .row_idx = self.row_idx,
                };
            }

            pub fn top_left(self: PackedAABB) Vec {
                if (self.is_rotated) {
                    return self.aabb.top_right();
                }
                return self.aabb.top_left();
            }
            pub fn top_right(self: PackedAABB) Vec {
                if (self.is_rotated) {
                    return self.aabb.bot_right();
                }
                return self.aabb.top_right();
            }
            pub fn bot_left(self: PackedAABB) Vec {
                if (self.is_rotated) {
                    return self.aabb.top_left();
                }
                return self.aabb.bot_left();
            }
            pub fn bot_right(self: PackedAABB) Vec {
                if (self.is_rotated) {
                    return self.aabb.bot_left();
                }
                return self.aabb.bot_right();
            }
            pub fn equals(self: PackedAABB, other: PackedAABB) bool {
                return self.aabb.equals(other.aabb) and self.is_rotated == other.is_rotated and self.row_idx == other.row_idx;
            }
        };

        const ConstrainedRow = struct {
            pos: Vec = .{},
            width: T_SIZE = 0,
            used_width: T_SIZE = 0,
            min_height: T_SIZE = 0,
            max_height: T_SIZE = 0,
            num_claimed: IDX = 0,
            next_hole: ?*Hole = null,

            inline fn can_fit_width(self: ConstrainedRow, width: T_SIZE) bool {
                return self.width >= width;
            }
            inline fn can_fit_height(self: ConstrainedRow, height: T_SIZE) bool {
                return self.max_height >= height;
            }
            inline fn can_fit_size(self: ConstrainedRow, size: Vec) bool {
                return self.width >= size.x and self.max_height >= size.y;
            }
            inline fn claim_pos(self: *ConstrainedRow, size: Vec, total_waste_ptr: *T_SIZE) Vec {
                const waste = self.wasted_area_if_claimed(size);
                return self.claim_pos_known_waste(size, waste, total_waste_ptr);
            }
            inline fn claim_pos_known_waste(self: *ConstrainedRow, size: Vec, waste: T_SIZE, total_waste_pointer: *T_SIZE) Vec {
                const pos = self.pos;
                self.pos.x += size.x;
                self.width -= size.x;
                self.used_width += size.x;
                self.min_height = @min(self.min_height, size.y);
                total_waste_pointer.* += waste;
                self.num_claimed += 1;
                return pos;
            }
            fn new_height_is_within_threshold(self: ConstrainedRow, threshold: ThresholdVal, height: T_SIZE) bool {
                if (height > self.max_height) return false;
                const new_min = @min(self.min_height, height);
                const new_min_f: f32 = num_cast(new_min, f32);
                const max_f = num_cast(self.max_height, f32);
                const within_percent = (new_min_f / max_f) >= threshold.percent;
                if (within_percent) return true;
                return self.max_height - new_min <= threshold.flat_tolerance;
            }
            fn wasted_area_if_claimed(self: ConstrainedRow, size: Vec) T_SIZE {
                return (self.max_height - size.y) * size.x;
            }
            fn release_position(self: *ConstrainedRow, pos: Vec, size: Vec, hole: *Hole, hole_pool: *HolePool) void {
                assert_with_reason(self.num_claimed > 0, @src(), "no rects claimed in row, nothing to release", .{});
                assert_with_reason(
                    pos.y >= self.pos.y and pos.y + size.y <= self.pos.y + self.max_height and
                        pos.x >= (self.pos.x - self.used_width) and pos.x + size.x <= self.pos.x,
                    @src(),
                    "rect to release is not fully within the row, rect: {}, row: {}",
                    .{ Rect.new(pos, size), Rect.new(Vec.new(self.pos.x - self.used_width, self.pos.y), Vec.new(self.width + self.used_width, self.max_height)) },
                );
                self.num_claimed -= 1;
                if (self.num_claimed == 0) {
                    var possible_next_hole = self.next_hole;
                    while (possible_next_hole) |next_hole| {
                        possible_next_hole = next_hole.next;
                        hole_pool.release(next_hole);
                    }
                    hole_pool.release(hole);
                    self.min_height = MAX_HEIGHT;
                    self.pos.x -= self.used_width;
                    self.width += self.used_width;
                    self.used_width = 0;
                    self.next_hole = null;
                    return;
                }
                hole.rect = Rect.new(pos, size);
                hole.next = self.next_hole;
                self.next_hole = hole;
            }
        };

        const UnconstrainedRow = struct {
            pos: Vec = .{},
            width: T_SIZE = 0,
            used_width: T_SIZE = 0,
            min_height: T_SIZE = 0,
            max_height: T_SIZE = 0,
            true_max_height: T_SIZE = 0,
            num_claimed: IDX = 0,
            next_hole: ?*Hole = null,

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
            inline fn is_empty(self: UnconstrainedRow) bool {
                return self.used_width == 0 and self.max_height == 0;
            }
            inline fn can_fit_size(self: UnconstrainedRow, size: Vec) bool {
                return self.width >= size.x and self.true_max_height >= size.y;
            }
            inline fn can_fit_size_on_new_row(self: UnconstrainedRow, size: Vec) bool {
                return self.width + self.used_width >= size.x and self.true_max_height - self.max_height >= size.y;
            }
            inline fn claim_pos(self: *UnconstrainedRow, size: Vec, total_waste_ptr: *T_SIZE) Vec {
                const waste = self.wasted_area_if_claimed(size);
                return self.claim_pos_known_waste(size, waste, total_waste_ptr);
            }
            inline fn claim_pos_known_waste(self: *UnconstrainedRow, size: Vec, waste: T_SIZE, total_waste_ptr: *T_SIZE) Vec {
                const pos = self.pos;
                self.pos.x += size.x;
                self.width -= size.x;
                self.used_width += size.x;
                self.min_height = @min(self.min_height, size.y);
                self.max_height = @max(self.max_height, size.y);
                total_waste_ptr.* += waste;
                self.num_claimed += 1;
                return pos;
            }

            fn new_height_is_within_threshold(self: UnconstrainedRow, threshold: ThresholdVal, height: T_SIZE) bool {
                const new_min: T_SIZE = @min(self.min_height, height);
                const new_max: T_SIZE = @max(self.max_height, height);
                const new_min_f: f32 = num_cast(new_min, f32);
                const new_max_f: f32 = num_cast(new_max, f32);
                const within_percent = (new_min_f / new_max_f) >= threshold.percent;
                if (within_percent) return true;
                return (new_max - new_min) <= threshold.flat_tolerance;
            }
            fn wasted_area_if_claimed(self: UnconstrainedRow, size: Vec) T_SIZE {
                if (size.y > self.max_height) {
                    const delta = size.y - self.max_height;
                    return delta * self.used_width;
                } else {
                    const delta = self.max_height - size.y;
                    return delta * size.x;
                }
            }

            fn extract_constrained_row(self: *UnconstrainedRow, full_region: Rect) ConstrainedRow {
                const row = ConstrainedRow{
                    .pos = self.pos,
                    .min_height = self.min_height,
                    .max_height = self.max_height,
                    .width = self.width,
                    .used_width = self.used_width,
                    .num_claimed = self.num_claimed,
                    .next_hole = self.next_hole,
                };
                self.pos.x = full_region.pos.x;
                self.pos.y += self.max_height;
                self.true_max_height -= self.max_height;
                self.max_height = 0;
                self.min_height = MAX_HEIGHT;
                self.width = full_region.size.x;
                self.used_width = 0;
                self.num_claimed = 0;
                self.next_hole = null;
                return row;
            }

            fn release_position(self: *UnconstrainedRow, pos: Vec, size: Vec, hole: *Hole, hole_pool: *HolePool) void {
                assert_with_reason(self.num_claimed > 0, @src(), "no rects claimed in row, nothing to release", .{});
                assert_with_reason(
                    pos.y >= self.pos.y and pos.y + size.y <= self.pos.y + self.max_height and
                        pos.x >= (self.pos.x - self.used_width) and pos.x + size.x <= self.pos.x,
                    @src(),
                    "rect to release is not fully within the row, rect: {}, row: {}",
                    .{ Rect.new(pos, size), Rect.new(Vec.new(self.pos.x - self.used_width, self.pos.y), Vec.new(self.width + self.used_width, self.max_height)) },
                );
                self.num_claimed -= 1;
                if (self.num_claimed == 0) {
                    var possible_next_hole = self.next_hole;
                    while (possible_next_hole) |next_hole| {
                        possible_next_hole = next_hole.next;
                        hole_pool.release(next_hole);
                    }
                    hole_pool.release(hole);
                    self.min_height = MAX_HEIGHT;
                    self.max_height = 0;
                    self.pos.x -= self.used_width;
                    self.width += self.used_width;
                    self.used_width = 0;
                    self.next_hole = null;
                    return;
                }
                hole.rect = Rect.new(pos, size);
                hole.next = self.next_hole;
                self.next_hole = hole;
            }
        };

        pub const Hole = struct {
            rect: Rect = .{},
            next: ?*Hole = null,

            fn wasted_area_if_claimed(self: Hole, size: Vec) T_SIZE {
                return (self.rect.size.x - size.x) * self.rect.size.y + (self.rect.size.y - size.y) * size.x;
            }
        };

        /// Releases a previously claimed rect so its area can be reused. Only valid
        /// when the packer was constructed with `.CLAIM_AND_RELEASE`.
        pub fn release_rect(self: *Self, rect: PackedRect) void {
            if (CAN_RELEASE) {
                self.release_rect_internal(rect);
            } else {
                assert_can_release(@src());
            }
        }

        fn release_rect_internal(self: *Self, rect: PackedRect) void {
            const released = rect.rect;
            assert_with_reason(released.to_aabb2().fully_within(self.full_region.to_aabb2()), @src(), "rect is not within packer region", .{});
            assert_with_reason(rect.row_idx <= self.constrained_rows.get_len(), @src(), "row idx for rect is out of bounds for packer", .{});
            assert_with_reason(self.claim_count > 0, @src(), "no rectangles claimed in packer, nothing to release", .{});
            self.claim_count -= 1;
            if (self.claim_count == 0) {
                self.reset();
                return;
            }
            const new_hole = self.holes_pool.claim();
            if (rect.row_idx == self.constrained_rows.get_len()) {
                self.unconstrained_row.release_position(released.pos, released.size, new_hole, &self.holes_pool);
                return;
            }
            const row: *ConstrainedRow = self.constrained_rows.get_ptr(rect.row_idx);
            row.release_position(released.pos, released.size, new_hole, &self.holes_pool);
        }

        /// Same as `release_rect`, but accepts the result of `claim_aabb`.
        pub fn release_aabb(self: *Self, aabb: PackedAABB) void {
            if (CAN_RELEASE) {
                self.release_aabb_internal(aabb);
            } else {
                assert_can_release(@src());
            }
        }

        fn release_aabb_internal(self: *Self, aabb: PackedAABB) void {
            const released = Rect.new(aabb.aabb.get_min_point(), aabb.aabb.get_size());
            assert_with_reason(aabb.aabb.fully_within(self.full_region.to_aabb2()), @src(), "aabb is not within packer region", .{});
            assert_with_reason(aabb.row_idx <= self.constrained_rows.get_len(), @src(), "row idx for aabb is out of bounds for packer", .{});
            assert_with_reason(self.claim_count > 0, @src(), "no rectangles claimed in packer, nothing to release", .{});
            self.claim_count -= 1;
            if (self.claim_count == 0) {
                self.reset();
                return;
            }
            const new_hole = self.holes_pool.claim();
            if (aabb.row_idx == self.constrained_rows.get_len()) {
                self.unconstrained_row.release_position(released.pos, released.size, new_hole, &self.holes_pool);
                return;
            }
            const row: *ConstrainedRow = self.constrained_rows.get_ptr(aabb.row_idx);
            row.release_position(released.pos, released.size, new_hole, &self.holes_pool);
        }
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

pub fn RowPackedAtlas(
    comptime KEY: type,
    comptime HASH: fn (KEY) u64,
    comptime KEYS_EQUAL: fn (KEY, KEY) bool,
    comptime HASH_MAP_OVERRIDES: HashMapOverrides,
    comptime T_SIZE: type,
    comptime IDX: type,
    comptime RELEASE_MODE: ReleaseMode,
    comptime ALLOC: CachedAllocMode,
) type {
    return struct {
        const Self = @This();
        pub const Packer = RowPacker(T_SIZE, IDX, RELEASE_MODE, .MANUAL_ALLOC);
        pub const Rect = Packer.Rect;
        pub const PackedRect = Packer.PackedRect;
        pub const PackedAABB = Packer.PackedAABB;
        pub const Map = HashMap(KEY, PackedRect, HASH, KEYS_EQUAL, HASH_MAP_OVERRIDES);
        pub const Vec = Packer.Vec;
        pub const AABB = Packer.AABB;
        pub const Threshold = Packer.Threshold;
        pub const ThresholdVal = Packer.ThresholdVal;

        hash_map: Map = .{},
        packer: Packer = .{},
        cached_alloc: ALLOC.CachedAlloc() = ALLOC.CACHED_ALLOC_DEFAULT(),

        pub fn init_capacity(cap: IDX, region: Rect, default_height_fit_threshold: ThresholdVal, alloc: Allocator) Self {
            const h = Map.init_capacity(@intCast(cap), alloc);
            const p = Packer.init(@intCast(cap), region, default_height_fit_threshold, alloc);
            return Self{
                .hash_map = h,
                .packer = p,
                .cached_alloc = ALLOC.alloc_to_cached_alloc(alloc),
            };
        }
        pub fn init_empty(region: Rect, default_height_fit_threshold: ThresholdVal, alloc: ALLOC.Ch()) Self {
            const h = Map.init_empty();
            const p = Packer.init_empty(region, default_height_fit_threshold, alloc);
            return Self{
                .hash_map = h,
                .packer = p,
                .cached_alloc = alloc,
            };
        }

        pub fn uninit(self: *Self, alloc: ALLOC.Fn()) void {
            self.hash_map.uninit(ALLOC.get_alloc(alloc, self.cached_alloc));
            self.packer.free(ALLOC.get_alloc(alloc, self.cached_alloc));
        }

        pub fn claim_rect(self: *Self, key: KEY, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode, alloc: ALLOC.Fn()) ?PackedRect {
            const hash_parts = Map.hash_parts(key);
            assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
            const possible_rect = self.packer.claim_rect(size, threshold, waste, rotation, ALLOC.get_alloc(alloc, self.cached_alloc));
            if (possible_rect) |packed_rect| {
                self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, ALLOC.get_alloc(alloc, self.cached_alloc));
                return packed_rect;
            }
            return null;
        }
        pub fn release_rect(self: *Self, key: KEY) void {
            const packed_rect = self.hash_map.remove_key(key);
            self.packer.release_rect(packed_rect);
        }
        pub fn claim_aabb(self: *Self, key: KEY, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode, alloc: ALLOC.Fn()) ?PackedAABB {
            const hash_parts = Map.hash_parts(key);
            assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
            const possible_rect = self.packer.claim_rect(size, threshold, waste, rotation, ALLOC.get_alloc(alloc, self.cached_alloc));
            if (possible_rect) |packed_rect| {
                self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, ALLOC.get_alloc(alloc, self.cached_alloc));
                return packed_rect.to_packed_aabb();
            }
            return null;
        }
        pub fn release_aabb(self: *Self, key: KEY) void {
            const packed_rect = self.hash_map.remove_key(key);
            self.packer.release_rect(packed_rect);
        }
    };
}

// pub fn MultiRowPackedAtlas(comptime KEY: type, comptime HASH: fn (KEY) u64, comptime KEYS_EQUAL: fn (KEY, KEY) bool, comptime OVERRIDES: HashMapOverrides, comptime T_SIZE: type, comptime IDX: type, comptime RELEASE_MODE: ReleaseMode) type {
//     return struct {
//         const Self = @This();
//         pub const Packer = RowPacker(T_SIZE, IDX, RELEASE_MODE);
//         pub const Rect = Packer.Rect;
//         pub const PackedRect = Packer.PackedRect;
//         pub const PackedAABB = Packer.PackedAABB;
//         pub const Map = HashMap(KEY, PackedRect, HASH, KEYS_EQUAL, OVERRIDES);
//         pub const Vec = Packer.Vec;
//         pub const AABB = Packer.AABB;
//         pub const Threshold = Packer.Threshold;
//         pub const ThresholdVal = Packer.ThresholdVal;

//         hash_map: Map = .{},
//         packer: Packer = .{},

//         pub fn init_capacity(cap: IDX, region: Rect, default_height_fit_threshold: ThresholdVal, alloc: Allocator) Self {
//             const h = Map.init_capacity(@intCast(cap), alloc);
//             const p = Packer.init(@intCast(cap), region, default_height_fit_threshold, alloc);
//             return Self{
//                 .hash_map = h,
//                 .packer = p,
//             };
//         }
//         pub fn init_empty(region: Rect, default_height_fit_threshold: ThresholdVal, alloc: Allocator) Self {
//             const h = Map.init_empty();
//             const p = Packer.init_empty(region, default_height_fit_threshold, alloc);
//             return Self{
//                 .hash_map = h,
//                 .packer = p,
//             };
//         }

//         pub fn uninit(self: *Self) void {
//             self.hash_map.uninit(self.packer.alloc);
//             self.packer.free();
//         }

//         pub fn claim_rect(self: *Self, key: KEY, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode) ?PackedRect {
//             const hash_parts = Map.hash_parts(key);
//             assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
//             const possible_rect = self.packer.claim_rect(size, threshold, waste, rotation);
//             if (possible_rect) |packed_rect| {
//                 self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, self.packer.alloc);
//                 return packed_rect;
//             }
//             return null;
//         }
//         pub fn release_rect(self: *Self, key: KEY) void {
//             const packed_rect = self.hash_map.remove_key(key);
//             self.packer.release_rect(packed_rect);
//         }
//         pub fn claim_aabb(self: *Self, key: KEY, size: Vec, threshold: Threshold, waste: WasteMode, rotation: RotationMode) ?PackedAABB {
//             const hash_parts = Map.hash_parts(key);
//             assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
//             const possible_rect = self.packer.claim_rect(size, threshold, waste, rotation);
//             if (possible_rect) |packed_rect| {
//                 self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, self.packer.alloc);
//                 return packed_rect.to_packed_aabb();
//             }
//             return null;
//         }
//         pub fn release_aabb(self: *Self, key: KEY) void {
//             const packed_rect = self.hash_map.remove_key(key);
//             self.packer.release_rect(packed_rect);
//         }
//     };
// }
