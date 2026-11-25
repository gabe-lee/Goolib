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
const BitTrackedBlocksPoolModule = Root.Pool.BitTrackedBlocksModule;
const BitBlockPool = Root.Pool.BitTrackedBlocksPool;
const AABB2 = Root.AABB2;
const Rect2 = Root.Rect2;
const Vec2 = Root.Vec2;
const Assert = Root.Assert;
const HashMapModule = Root.HashMap.SwissTableHashMapModule;
const HashMap = HashMapModule.SwissHashMap;
const HashMapOverrides = HashMapModule.Overrides;
const LockMode = BitTrackedBlocksPoolModule.LockMode;
const BackPointStrategy = BitTrackedBlocksPoolModule.BackPointStrategy;
const RwLock = std.Io.RwLock;
const Io = std.Io;
const AllocAdapter = Root.Allocator.AllocatorAdapter;
const AllocSource = Root.Allocator.AllocSource;
const LockKind = Root.Threading.LocksModule.LockKind;

const RowPackerModule = @import("./RectPacker_RowPacker.zig");
// pub const PackerDef = RowPackerModule.PackerDef;
pub const ReleaseMode = RowPackerModule.ReleaseMode;
pub const WasteMode = RowPackerModule.WasteMode;
pub const ThresholdMode = RowPackerModule.ThresholdMode;
pub const RotationMode = RowPackerModule.RotationMode;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Cast.num_cast;

comptime {
    if (build.is_test) {
        _ = @import("./RectPacker_LayeredRowPacker_Tests.zig");
    }
}

/// Controls whether a failed claim may append a new array layer.
pub const GrowMode = enum(u8) {
    NEVER_ADD_LAYERS,
    ADD_LAYER_IF_NO_SPACE,
};

const RowKind = enum(u2) {
    CONSTRAINED,
    UNCONSTRAINED,
};

const CandidateKind = enum(u2) {
    NONE,
    HOLE,
    ROW_TAIL,
};

pub const PackerDef = struct {
    SIZE_TYPE: type,
    RECT_IDX: type = u32,
    ROW_IDX: type = u16,
    LAYER_IDX: type = u8,
    RELEASE_MODE: ReleaseMode = .CLAIM_AND_RELEASE,
    ALLOC_SOURCE: AllocSource = .CACHED_ALLOCATOR_INTERFACE,
    LOCK_KIND: LockKind = .NONE,
    LOCK_ASSERTS: bool = false,
    HOLE_POOL_BACK_STRATEGY: BackPointStrategy = .SORTED_BLOCKS_BINARY_SEARCH,
    HOLE_POOL_SLOTS_PER_BLOCK: comptime_int = 64,
    HOLE_POOL_STATE_UINT: type = usize,
    USERDATA_TYPE: type = void,

    pub fn with_alloc(comptime self: PackerDef, comptime ALLOC: AllocSource) PackerDef {
        var out = self;
        out.ALLOC_SOURCE = ALLOC;
        return out;
    }

    pub fn with_no_locks(comptime self: PackerDef) PackerDef {
        return PackerDef{
            .SIZE_TYPE = self.SIZE_TYPE,
            .RECT_IDX = self.RECT_IDX,
            .ROW_IDX = self.ROW_IDX,
            .LAYER_IDX = self.LAYER_IDX,
            .RELEASE_MODE = self.RELEASE_MODE,
            .ALLOC_SOURCE = self.ALLOC_SOURCE,
            .LOCK_KIND = .NONE,
            .LOCK_ASSERTS = false,
            .HOLE_POOL_BACK_STRATEGY = self.HOLE_POOL_BACK_STRATEGY,
            .HOLE_POOL_SLOTS_PER_BLOCK = self.HOLE_POOL_SLOTS_PER_BLOCK,
            .HOLE_POOL_STATE_UINT = self.HOLE_POOL_STATE_UINT,
            .USERDATA_TYPE = self.USERDATA_TYPE,
        };
    }
};

pub const PackerDefNoLocks = struct {
    SIZE_TYPE: type,
    RECT_IDX: type = u32,
    ROW_IDX: type = u16,
    LAYER_IDX: type = u8,
    RELEASE_MODE: ReleaseMode = .CLAIM_AND_RELEASE,
    ALLOC_SOURCE: AllocSource = .CACHED_ALLOCATOR_INTERFACE,
    HOLE_POOL_BACK_STRATEGY: BackPointStrategy = .SORTED_BLOCKS_BINARY_SEARCH,
    HOLE_POOL_SLOTS_PER_BLOCK: comptime_int = 64,
    HOLE_POOL_STATE_UINT: type = usize,
    USERDATA_TYPE: type = void,

    pub fn to_def(self: PackerDefNoLocks) PackerDef {
        return PackerDef{
            .SIZE_TYPE = self.SIZE_TYPE,
            .ALLOC_SOURCE = self.ALLOC_SOURCE,
            .HOLE_POOL_BACK_STRATEGY = self.HOLE_POOL_BACK_STRATEGY,
            .HOLE_POOL_SLOTS_PER_BLOCK = self.HOLE_POOL_SLOTS_PER_BLOCK,
            .HOLE_POOL_STATE_UINT = self.HOLE_POOL_STATE_UINT,
            .RECT_IDX = self.RECT_IDX,
            .ROW_IDX = self.ROW_IDX,
            .LAYER_IDX = self.LAYER_IDX,
            .LOCK_KIND = .NONE,
            .LOCK_ASSERTS = false,
            .RELEASE_MODE = self.RELEASE_MODE,
            .USERDATA_TYPE = self.USERDATA_TYPE,
        };
    }

    pub fn to_def_with_lock(self: PackerDefNoLocks, comptime LOCK_KIND: LockKind, comptime LOCK_ASSERTS: bool) PackerDef {
        return PackerDef{
            .SIZE_TYPE = self.SIZE_TYPE,
            .ALLOC_SOURCE = self.ALLOC_SOURCE,
            .HOLE_POOL_BACK_STRATEGY = self.HOLE_POOL_BACK_STRATEGY,
            .HOLE_POOL_SLOTS_PER_BLOCK = self.HOLE_POOL_SLOTS_PER_BLOCK,
            .HOLE_POOL_STATE_UINT = self.HOLE_POOL_STATE_UINT,
            .RECT_IDX = self.RECT_IDX,
            .ROW_IDX = self.ROW_IDX,
            .LAYER_IDX = self.LAYER_IDX,
            .LOCK_KIND = LOCK_KIND,
            .LOCK_ASSERTS = LOCK_ASSERTS,
            .RELEASE_MODE = self.RELEASE_MODE,
            .USERDATA_TYPE = self.USERDATA_TYPE,
        };
    }

    pub fn with_alloc(comptime self: PackerDefNoLocks, comptime ALLOC: AllocSource) PackerDefNoLocks {
        var out = self;
        out.ALLOC_SOURCE = ALLOC;
        return out;
    }
};

/// Packs rects into horizontal shelves, like `RowPacker`, but over a variable
/// number of equally sized layers.
///
/// Packs rectangles into horizontal rows (shelves), filling each row from smaller x values
/// to larger x values, and starting each new row at a larger y position. If no spot can be found,
/// the user can allow adding an extra layer for more space.
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
pub fn LayeredRowPacker(comptime DEF: PackerDef) type {
    return struct {
        const Self = @This();
        const SIZE_TYPE = DEF.SIZE_TYPE;
        const RECT_IDX = DEF.RECT_IDX;
        const ROW_IDX = DEF.ROW_IDX;
        const LAYER_IDX = DEF.LAYER_IDX;
        const RELEASE_MODE = DEF.RELEASE_MODE;
        const ALLOC_SOURCE = DEF.ALLOC_SOURCE;
        const LOCK_KIND = DEF.LOCK_KIND;
        const LOCK_ASSERT = DEF.LOCK_ASSERTS;
        const HOLE_POOL_BACK_STRATEGY = DEF.HOLE_POOL_BACK_STRATEGY;
        const HOLE_POOL_SLOTS_PER_BLOCK = DEF.HOLE_POOL_SLOTS_PER_BLOCK;
        const HOLE_POOL_STATE_UINT = DEF.HOLE_POOL_STATE_UINT;
        pub const Userdata = DEF.USERDATA_TYPE;

        pub const AABB = AABB2.define_aabb2_type(SIZE_TYPE);
        pub const Rect = Rect2.define_rect2_type(SIZE_TYPE);
        pub const Vec = Vec2.define_vec2_type(SIZE_TYPE);

        const CAN_RELEASE = RELEASE_MODE == .CLAIM_AND_RELEASE;
        const Lock = LOCK_KIND.lock_type(LOCK_ASSERT);
        const LOCK_INIT = LOCK_KIND.init_lock(LOCK_ASSERT);
        const LockIo = LOCK_KIND.io_type();
        const LOCK_IO_INIT = LOCK_KIND.null_io();
        const Alloc = AllocAdapter(DEF.ALLOC_SOURCE);
        const PassedAlloc = Alloc.PassedAlloc;
        const InitAlloc = Alloc.InitAlloc;

        const ROTATION_MASK: ROW_IDX = 0b1;
        const LOCATION_ROW_SHIFT: comptime_int = 1;
        const MAX_ROW_INDEX: ROW_IDX = MathX.max_value(ROW_IDX) >> LOCATION_ROW_SHIFT;
        const NULL_HOLE_IDX: RECT_IDX = HolePool.NULL_SLOT_IDX;
        const MAX_HEIGHT: SIZE_TYPE = MathX.max_value(SIZE_TYPE);

        const RowList = ListFull(Row, ROW_IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, ALLOC_SOURCE);
        const LayerList = ListFull(Layer, LAYER_IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, ALLOC_SOURCE);

        const HolePool = BitBlockPool(.{
            .ELEM = Hole,
            .ALLOC_SOURCE = ALLOC_SOURCE,
            .BACK_POINT_STRATEGY = HOLE_POOL_BACK_STRATEGY,
            .IDX = RECT_IDX,
            .LOCK_MODE = .NO_LOCKS,
            .SLOTS_PER_BLOCK = HOLE_POOL_SLOTS_PER_BLOCK,
            .STATE_UINT = HOLE_POOL_STATE_UINT,
            .ENABLE_STABLE_INDEXING = true,
        });

        alloc: Alloc = .{},
        rows: RowList = .{},
        layers: LayerList = .{},
        holes_pool: if (CAN_RELEASE) HolePool else void = if (CAN_RELEASE) HolePool{} else {},
        base_region: Rect = .{ .pos = .{}, .size = .{} },
        default_height_fit_threshold: ThresholdVal = .threshold_val(0.9, 4),
        total_wasted_area: SIZE_TYPE = 0,
        claim_count: RECT_IDX = 0,
        lock: Lock = LOCK_INIT,
        io: LockIo = LOCK_IO_INIT,

        pub const ThresholdVal = struct {
            percent: f32 = 0.9,
            flat_tolerance: SIZE_TYPE = 10,

            pub fn threshold_val(percent: f32, flat_tolerance: SIZE_TYPE) ThresholdVal {
                return ThresholdVal{
                    .percent = percent,
                    .flat_tolerance = flat_tolerance,
                };
            }
        };

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
            pub inline fn custom_threshold(percent: f32, flat_tolerance: SIZE_TYPE) Threshold {
                return Threshold{ .CUSTOM_THRESHOLD = .threshold_val(percent, flat_tolerance) };
            }
        };

        fn assert_can_release(src: ?std.lang.SourceLocation) void {
            assert_with_reason(CAN_RELEASE, src, "cannot release rects when packer defined as .CLAIM_ONLY", .{});
        }

        pub inline fn lock_for_read(self: *Self) void {
            LOCK_KIND.lock_for_read(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn unlock_for_read(self: *Self) void {
            LOCK_KIND.unlock_for_read(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn lock_for_write(self: *Self) void {
            LOCK_KIND.lock_for_write(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn unlock_for_write(self: *Self) void {
            LOCK_KIND.unlock_for_write(LOCK_ASSERT, &self.lock, self.io);
        }

        pub fn add_layer(self: *Self, alloc: PassedAlloc) LAYER_IDX {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.add_layer_internal(alloc);
        }

        fn add_layer_internal(self: *Self, alloc: PassedAlloc) LAYER_IDX {
            const layer_idx = self.layers.get_len();
            const row_idx = self.append_row(.{
                .kind = .UNCONSTRAINED,
                .layer_idx = layer_idx,
                .pos = self.base_region.pos,
                .width = self.base_region.size.x,
                .used_width = 0,
                .min_height = MAX_HEIGHT,
                .max_height = 0,
                .true_max_height = self.base_region.size.y,
                .num_claimed = 0,
                .next_hole = NULL_HOLE_IDX,
            }, alloc);
            self.layers.append_one(.{ .open_row_idx = row_idx }, alloc);
            return layer_idx;
        }

        fn append_row(self: *Self, row: Row, alloc: PassedAlloc) ROW_IDX {
            const row_idx = self.rows.get_len();
            assert_with_reason(
                row_idx <= MAX_ROW_INDEX,
                @src(),
                "row index {} does not fit in the location index's row bits (max {})",
                .{ row_idx, MAX_ROW_INDEX },
            );
            self.rows.append_one(row, alloc);
            return row_idx;
        }

        pub fn layer_count(self: *Self) LAYER_IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.layers.get_len();
        }

        pub fn row_count(self: *Self) ROW_IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.rows.get_len();
        }

        pub fn init(
            self: *Self,
            row_cap: ROW_IDX,
            hole_cap: RECT_IDX,
            layer_cap: LAYER_IDX,
            region: Rect,
            default_height_fit_threshold: ThresholdVal,
            alloc: InitAlloc,
            io: LockIo,
        ) void {
            self.lock = LOCK_INIT;
            self.io = io;
            self.lock_for_write();
            defer self.unlock_for_write();
            const passed = Alloc.init_to_passed_alloc(alloc);
            self.alloc = Alloc.new_from_init_alloc(alloc);
            self.rows = RowList.allocate_new(row_cap, alloc);
            self.layers = LayerList.allocate_new(layer_cap, alloc);
            self.base_region = region;
            self.default_height_fit_threshold = default_height_fit_threshold;
            self.total_wasted_area = 0;
            self.claim_count = 0;
            if (comptime CAN_RELEASE) {
                self.holes_pool.init(hole_cap, alloc, io);
            }
            _ = self.add_layer_internal(passed);
        }

        pub fn reset(self: *Self, alloc: PassedAlloc) void {
            self.lock_for_write();
            defer self.unlock_for_write();
            self.reset_no_lock(alloc);
        }

        fn reset_no_lock(self: *Self, alloc: PassedAlloc) void {
            self.rows.clear();
            self.layers.clear();
            self.total_wasted_area = 0;
            self.claim_count = 0;
            if (comptime CAN_RELEASE) {
                self.holes_pool.clear_all_blocks();
            }
            _ = self.add_layer_internal(alloc);
        }

        pub fn uninit(self: *Self, alloc: PassedAlloc) void {
            self.lock_for_write();
            self.rows.free_if_non_zero(alloc);
            self.layers.free_if_non_zero(alloc);
            if (comptime CAN_RELEASE) {
                self.holes_pool.uninit(alloc);
            }
            self.unlock_for_write();
            self.* = .{};
        }

        //----------------------------------------------------------------------
        // LOCATION INDEX
        //----------------------------------------------------------------------

        pub inline fn make_location_index(row_idx: ROW_IDX, is_rotated: bool) ROW_IDX {
            const rotation: ROW_IDX = if (is_rotated) ROTATION_MASK else 0;
            return (row_idx << LOCATION_ROW_SHIFT) | rotation;
        }

        pub inline fn location_index_row(location_info: ROW_IDX) ROW_IDX {
            return location_info >> LOCATION_ROW_SHIFT;
        }

        pub inline fn location_index_is_rotated(location_info: ROW_IDX) bool {
            return (location_info & ROTATION_MASK) != 0;
        }

        /// Claims a rect and returns the PackedRect (what is stored internally).
        /// Use `hydrate_rect()` to get the layer index.
        ///
        /// A null result means no existing layer had a suitable spot. If
        /// `grow == .ADD_LAYER`, a new layer is appended and used as a last
        /// resort.
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, a returned rect with
        /// `is_rotated() == true` has its actual `rect.size` swapped relative
        /// to the requested `size`; the consumer should rotate its source
        /// content 90 degrees into that footprint.
        pub fn claim_rect(
            self: *Self,
            size: Vec,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.claim_rect_internal(size, threshold, waste, rotation, grow, alloc, userdata) orelse return null;
        }

        /// Claims a rect and returns the PackedRect (what is stored internally),
        /// and the HydratedRect (for public use)
        ///
        /// A null result means no existing layer had a suitable spot. If
        /// `grow == .ADD_LAYER`, a new layer is appended and used as a last
        /// resort.
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, a returned rect with
        /// `is_rotated() == true` has its actual `rect.size` swapped relative
        /// to the requested `size`; the consumer should rotate its source
        /// content 90 degrees into that footprint.
        pub fn claim_rect_and_hydrated(
            self: *Self,
            size: Vec,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?struct { PackedRect, HydratedRect } {
            self.lock_for_write();
            defer self.unlock_for_write();
            const rect = self.claim_rect_internal(size, threshold, waste, rotation, grow, alloc, userdata) orelse return null;
            const hydr = self.hydrate_rect_no_lock(rect);
            return .{ rect, hydr };
        }

        fn claim_rect_internal(
            self: *Self,
            size: Vec,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            const allow_unrotated = rotation != .ALWAYS_FORCE_90_DEGREE_ROTATION;
            const allow_rotated = switch (rotation) {
                .DO_NOT_ALLOW_ROTATION => false,
                .ALLOW_90_DEGREE_ROTATION => size.x != size.y,
                .ALWAYS_FORCE_90_DEGREE_ROTATION => true,
            };
            const rot_size = size.flip_components();
            const fits_region_unrotated = size.x <= self.base_region.size.x and size.y <= self.base_region.size.y;
            const fits_region_rotated = rot_size.x <= self.base_region.size.x and rot_size.y <= self.base_region.size.y;
            if ((!allow_unrotated or !fits_region_unrotated) and (!allow_rotated or !fits_region_rotated)) return null;

            const threshold_value: ?ThresholdVal = switch (threshold) {
                .IGNORE_THRESHOLD => null,
                .DEFAULT_THRESHOLD => self.default_height_fit_threshold,
                .CUSTOM_THRESHOLD => |t| t,
            };

            var best_any: Candidate = .{};
            var best_threshold: Candidate = .{};

            var row_idx: ROW_IDX = 0;
            while (row_idx < self.rows.get_len()) : (row_idx += 1) {
                const row = self.rows.get_ptr(row_idx);
                if (row.kind != .CONSTRAINED) continue;
                self.evaluate_row(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, alloc, userdata);
                }
            }

            row_idx = 0;
            while (row_idx < self.rows.get_len()) : (row_idx += 1) {
                const row = self.rows.get_ptr(row_idx);
                if (row.kind != .UNCONSTRAINED) continue;
                self.evaluate_row(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, alloc, userdata);
                }
            }

            const selected = if (best_threshold.kind != .NONE) best_threshold else best_any;

            if (best_threshold.kind == .NONE and threshold_value != null) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, alloc, userdata)) |packed_rect| {
                    return packed_rect;
                }
            }

            if (selected.kind == .NONE) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, alloc, userdata)) |packed_rect| {
                    return packed_rect;
                }
                if (grow == .ADD_LAYER_IF_NO_SPACE) {
                    return self.claim_on_new_layer(size, rot_size, allow_unrotated, allow_rotated, alloc, userdata);
                }
                return null;
            }

            if (waste == .LEAST_WASTE and best_threshold.kind == .NONE and selected.kind == .ROW_TAIL) {
                const selected_row = self.rows.get_ptr(selected.row_idx);
                if (selected_row.kind == .UNCONSTRAINED) {
                    const extended_threshold = doubled_threshold(threshold_value orelse self.default_height_fit_threshold);
                    if (selected_row.can_fit_size_on_new_row(selected.size) and
                        !selected_row.new_height_is_within_threshold(extended_threshold, selected.size.y))
                    {
                        if (self.claim_on_new_row_for_layer(selected_row.layer_idx, selected.size, selected.is_rotated, alloc, userdata)) |packed_rect| {
                            return packed_rect;
                        }
                    }
                }
            }

            return self.claim_candidate(selected, alloc, userdata);
        }

        const Candidate = struct {
            kind: CandidateKind = .NONE,
            row_idx: ROW_IDX = 0,
            hole_idx: RECT_IDX = NULL_HOLE_IDX,
            size: Vec = .{},
            is_rotated: bool = false,
            waste: SIZE_TYPE = 0,

            inline fn consider(self: *Candidate, waste_mode: WasteMode, candidate: Candidate) void {
                if (self.kind == .NONE or (waste_mode == .LEAST_WASTE and candidate.waste < self.waste)) {
                    self.* = candidate;
                }
            }
        };

        fn evaluate_row(
            self: *Self,
            row: *Row,
            row_idx: ROW_IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            self.evaluate_holes(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste_mode, threshold_value, best_threshold, best_any);
            self.evaluate_tail(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, waste_mode, threshold_value, best_threshold, best_any);
        }

        fn evaluate_holes(
            self: *Self,
            row: *Row,
            row_idx: ROW_IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            if (comptime CAN_RELEASE) {
                var hole_idx = row.next_hole;
                while (hole_idx != NULL_HOLE_IDX) {
                    const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
                    const next_hole_idx = hole.next;

                    if (allow_unrotated and hole.rect.size.x >= size.x and hole.rect.size.y >= size.y) {
                        const candidate = Candidate{
                            .kind = .HOLE,
                            .row_idx = row_idx,
                            .hole_idx = hole_idx,
                            .size = size,
                            .is_rotated = false,
                            .waste = if (waste_mode == .LEAST_WASTE) hole.wasted_area_if_claimed(size) else 0,
                        };
                        best_any.consider(waste_mode, candidate);
                        if (threshold_value != null) {
                            best_threshold.consider(waste_mode, candidate);
                        }
                    }

                    if (allow_rotated and hole.rect.size.x >= rot_size.x and hole.rect.size.y >= rot_size.y) {
                        const candidate = Candidate{
                            .kind = .HOLE,
                            .row_idx = row_idx,
                            .hole_idx = hole_idx,
                            .size = rot_size,
                            .is_rotated = true,
                            .waste = if (waste_mode == .LEAST_WASTE) hole.wasted_area_if_claimed(rot_size) else 0,
                        };
                        best_any.consider(waste_mode, candidate);
                        if (threshold_value != null) {
                            best_threshold.consider(waste_mode, candidate);
                        }
                    }

                    hole_idx = next_hole_idx;
                }
            }
        }

        fn evaluate_tail(
            self: *Self,
            row: *Row,
            row_idx: ROW_IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            _ = self;

            if (allow_unrotated and row.can_fit_size(size)) {
                const candidate = Candidate{
                    .kind = .ROW_TAIL,
                    .row_idx = row_idx,
                    .hole_idx = NULL_HOLE_IDX,
                    .size = size,
                    .is_rotated = false,
                    .waste = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(size) else 0,
                };
                best_any.consider(waste_mode, candidate);
                if (threshold_value) |t| {
                    if (row.new_height_is_within_threshold(t, size.y)) {
                        best_threshold.consider(waste_mode, candidate);
                    }
                }
            }

            if (allow_rotated and row.can_fit_size(rot_size)) {
                const candidate = Candidate{
                    .kind = .ROW_TAIL,
                    .row_idx = row_idx,
                    .hole_idx = NULL_HOLE_IDX,
                    .size = rot_size,
                    .is_rotated = true,
                    .waste = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(rot_size) else 0,
                };
                best_any.consider(waste_mode, candidate);
                if (threshold_value) |t| {
                    if (row.new_height_is_within_threshold(t, rot_size.y)) {
                        best_threshold.consider(waste_mode, candidate);
                    }
                }
            }
        }

        inline fn first_fit_ready(
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: Candidate,
            best_any: Candidate,
        ) ?Candidate {
            if (waste_mode != .IGNORE_WASTE) return null;
            if (threshold_value == null) {
                return if (best_any.kind == .NONE) null else best_any;
            }
            return if (best_threshold.kind == .NONE) null else best_threshold;
        }

        fn claim_candidate(self: *Self, candidate: Candidate, alloc: PassedAlloc, userdata: Userdata) PackedRect {
            return switch (candidate.kind) {
                .HOLE => if (comptime CAN_RELEASE)
                    self.claim_from_hole(candidate.row_idx, candidate.hole_idx, candidate.size, candidate.is_rotated, alloc, userdata)
                else
                    unreachable,
                .ROW_TAIL => self.claim_from_tail(candidate.row_idx, candidate.size, candidate.is_rotated, alloc, userdata),
                .NONE => unreachable,
            };
        }

        fn claim_from_tail(
            self: *Self,
            row_idx: ROW_IDX,
            size: Vec,
            is_rotated: bool,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
            _ = alloc;
            const row = self.rows.get_ptr(row_idx);
            assert_with_reason(row.can_fit_size(size), @src(), "tail claim does not fit row", .{});

            const pos = row.pos;
            const waste = row.wasted_area_if_claimed(size);

            row.pos.x += size.x;
            row.width -= size.x;
            row.used_width += size.x;
            row.min_height = @min(row.min_height, size.y);
            if (row.kind == .UNCONSTRAINED) {
                row.max_height = @max(row.max_height, size.y);
            }
            row.num_claimed += 1;
            self.claim_count +|= 1;
            self.total_wasted_area += waste;

            return PackedRect{
                .rect = Rect.new(pos, size),
                .location_info = make_location_index(row_idx, is_rotated),
                .userdata = userdata,
            };
        }

        fn claim_from_hole(
            self: *Self,
            row_idx: ROW_IDX,
            hole_idx: RECT_IDX,
            size: Vec,
            is_rotated: bool,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
            const row = self.rows.get_ptr(row_idx);
            const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
            const hole_rect = hole.rect;

            self.remove_hole(row, hole_idx);

            const claimed_rect = Rect.new(hole_rect.pos, size);
            const remaining_width = hole_rect.size.x - size.x;
            const remaining_height = hole_rect.size.y - size.y;

            var reused = false;
            var right_idx: RECT_IDX = NULL_HOLE_IDX;
            var bottom_idx: RECT_IDX = NULL_HOLE_IDX;

            if (remaining_width > 0) {
                const h = if (!reused) blk: {
                    reused = true;
                    break :blk hole;
                } else self.holes_pool.claim_slot(alloc);
                h.rect = Rect.new(
                    Vec.new(hole_rect.pos.x + size.x, hole_rect.pos.y),
                    Vec.new(remaining_width, hole_rect.size.y),
                );
                right_idx = self.holes_pool.slot_index_ignore_locks(h);
            }
            if (remaining_height > 0) {
                const h = if (!reused) blk: {
                    reused = true;
                    break :blk hole;
                } else self.holes_pool.claim_slot(alloc);
                h.rect = Rect.new(
                    Vec.new(hole_rect.pos.x, hole_rect.pos.y + size.y),
                    Vec.new(size.x, remaining_height),
                );
                bottom_idx = self.holes_pool.slot_index_ignore_locks(h);
            }
            if (!reused) {
                self.holes_pool.release_slot(hole);
            }

            var head = row.next_hole;
            if (right_idx != NULL_HOLE_IDX) {
                const h = self.holes_pool.slot_from_index_ignore_locks(right_idx);
                h.next = head;
                head = right_idx;
            }
            if (bottom_idx != NULL_HOLE_IDX) {
                const h = self.holes_pool.slot_from_index_ignore_locks(bottom_idx);
                h.next = head;
                head = bottom_idx;
            }
            row.next_hole = head;

            row.num_claimed += 1;
            self.claim_count +|= 1;

            return PackedRect{
                .rect = claimed_rect,
                .location_info = make_location_index(row_idx, is_rotated),
                .userdata = userdata,
            };
        }

        fn claim_on_new_layer(
            self: *Self,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
            const use_unrotated = allow_unrotated and
                size.x <= self.base_region.size.x and size.y <= self.base_region.size.y;
            if (!use_unrotated) {
                assert_with_reason(allow_rotated, @src(), "rotated new-layer claim was not allowed", .{});
            }
            const claim_size = if (use_unrotated) size else rot_size;
            const is_rotated = !use_unrotated;
            const layer_idx = self.add_layer_internal(alloc);
            return self.claim_on_new_row_for_layer(layer_idx, claim_size, is_rotated, alloc, userdata).?;
        }

        fn try_claim_on_new_row(
            self: *Self,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            var layer_idx: LAYER_IDX = 0;
            while (layer_idx < self.layers.get_len()) : (layer_idx += 1) {
                const open_row = self.rows.get_ptr(self.layers.get_ptr(layer_idx).open_row_idx);
                if (allow_unrotated and open_row.can_fit_size_on_new_row(size)) {
                    return self.claim_on_new_row_for_layer(layer_idx, size, false, alloc, userdata);
                }
                if (allow_rotated and open_row.can_fit_size_on_new_row(rot_size)) {
                    return self.claim_on_new_row_for_layer(layer_idx, rot_size, true, alloc, userdata);
                }
            }
            return null;
        }

        fn claim_on_new_row_for_layer(
            self: *Self,
            layer_idx: LAYER_IDX,
            size: Vec,
            is_rotated: bool,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            const layer = self.layers.get_ptr(layer_idx);
            const open_row = self.rows.get_ptr(layer.open_row_idx);
            if (!open_row.can_fit_size_on_new_row(size)) return null;

            _ = self.close_open_row(layer_idx, alloc);
            const new_row_idx = self.layers.get_ptr(layer_idx).open_row_idx;
            const new_row = self.rows.get_ptr(new_row_idx);
            if (!new_row.can_fit_size(size)) return null;

            return self.claim_from_tail(new_row_idx, size, is_rotated, alloc, userdata);
        }

        fn close_open_row(self: *Self, layer_idx: LAYER_IDX, alloc: PassedAlloc) ROW_IDX {
            const layer = self.layers.get_ptr(layer_idx);
            const old_row_idx = layer.open_row_idx;
            const old_row = self.rows.get_ptr(old_row_idx);
            assert_with_reason(old_row.kind == .UNCONSTRAINED, @src(), "open row is not unconstrained", .{});

            if (old_row.is_empty()) {
                return old_row_idx;
            }

            const old_y = old_row.pos.y;
            const old_max_height = old_row.max_height;
            const old_true_max_height = old_row.true_max_height;

            old_row.kind = .CONSTRAINED;
            old_row.true_max_height = 0;

            const new_row_idx = self.append_row(.{
                .kind = .UNCONSTRAINED,
                .layer_idx = layer_idx,
                .pos = Vec.new(self.base_region.pos.x, old_y + old_max_height),
                .width = self.base_region.size.x,
                .used_width = 0,
                .min_height = MAX_HEIGHT,
                .max_height = 0,
                .true_max_height = old_true_max_height - old_max_height,
                .num_claimed = 0,
                .next_hole = NULL_HOLE_IDX,
            }, alloc);

            self.layers.get_ptr(layer_idx).open_row_idx = new_row_idx;
            return new_row_idx;
        }

        pub fn release_rect(self: *Self, rect: PackedRect, alloc: PassedAlloc) void {
            if (comptime CAN_RELEASE) {
                self.lock_for_write();
                defer self.unlock_for_write();
                self.release_rect_internal(rect, alloc);
            } else {
                assert_can_release(@src());
            }
        }

        fn release_rect_internal(self: *Self, rect: PackedRect, alloc: PassedAlloc) void {
            const row_idx = rect.row_index();
            assert_with_reason(row_idx < self.rows.get_len(), @src(), "row idx for rect is out of bounds for packer", .{});
            assert_with_reason(self.claim_count > 0, @src(), "no rectangles claimed in packer, nothing to release", .{});

            self.claim_count -= 1;
            if (self.claim_count == 0) {
                self.reset_no_lock(alloc);
                return;
            }

            const row = self.rows.get_ptr(row_idx);
            assert_with_reason(row.num_claimed > 0, @src(), "no rects claimed in row, nothing to release", .{});

            row.num_claimed -= 1;
            if (row.num_claimed == 0) {
                self.release_all_holes(row);
                reset_row_after_release(row);
                return;
            }

            self.add_hole(row, rect.rect, alloc);
        }

        fn release_all_holes(self: *Self, row: *Row) void {
            if (comptime CAN_RELEASE) {
                var hole_idx = row.next_hole;
                while (hole_idx != NULL_HOLE_IDX) {
                    const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
                    const next_hole_idx = hole.next;
                    self.holes_pool.release_slot(hole);
                    hole_idx = next_hole_idx;
                }
                row.next_hole = NULL_HOLE_IDX;
            }
        }

        fn reset_row_after_release(row: *Row) void {
            row.min_height = MAX_HEIGHT;
            if (row.kind == .UNCONSTRAINED) {
                row.max_height = 0;
            }
            row.pos.x -= row.used_width;
            row.width += row.used_width;
            row.used_width = 0;
            row.next_hole = NULL_HOLE_IDX;
        }

        fn add_hole(self: *Self, row: *Row, rect: Rect, alloc: PassedAlloc) void {
            if (comptime CAN_RELEASE) {
                const hole = self.holes_pool.claim_slot(alloc);
                const hole_idx = self.holes_pool.slot_index_ignore_locks(hole);
                hole.rect = rect;
                hole.next = row.next_hole;
                row.next_hole = hole_idx;
            }
        }

        fn remove_hole(self: *Self, row: *Row, hole_idx: RECT_IDX) void {
            var link = &row.next_hole;
            while (link.* != NULL_HOLE_IDX) {
                if (link.* == hole_idx) {
                    const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
                    link.* = hole.next;
                    return;
                }
                const node = self.holes_pool.slot_from_index_ignore_locks(link.*);
                link = &node.next;
            }
            assert_unreachable(@src(), "hole was not found in the row's hole list", .{});
        }

        pub fn hydrate_rect(self: *Self, packed_rect: PackedRect) HydratedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.hydrate_rect_no_lock(packed_rect);
        }

        fn hydrate_rect_no_lock(self: *Self, packed_rect: PackedRect) HydratedRect {
            const row_idx = packed_rect.row_index();
            assert_with_reason(row_idx < self.rows.get_len(), @src(), "row idx for rect is out of bounds for packer", .{});
            const row = self.rows.get_ptr(row_idx);
            return HydratedRect{
                .rect = packed_rect.rect,
                .is_rotated = packed_rect.is_rotated(),
                .layer_idx = row.layer_idx,
                .userdata = packed_rect.userdata,
            };
        }

        pub const PackedRect = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            location_info: ROW_IDX = 0,
            userdata: Userdata,

            pub fn new(rect: Rect, location_info: ROW_IDX, userdata: Userdata) PackedRect {
                return PackedRect{
                    .rect = rect,
                    .location_info = location_info,
                    .userdata = userdata,
                };
            }

            pub inline fn hydrate(self: PackedRect, packer: *Self) HydratedRect {
                return packer.hydrate_rect(self);
            }
            inline fn hydrate_no_locks(self: PackedRect, packer: *Self) HydratedRect {
                return packer.hydrate_rect_no_lock(self);
            }

            pub inline fn row_index(self: PackedRect) ROW_IDX {
                return location_index_row(self.location_info);
            }
            pub inline fn is_rotated(self: PackedRect) bool {
                return location_index_is_rotated(self.location_info);
            }

            pub fn top_left(self: PackedRect) Vec {
                if (self.is_rotated()) return self.rect.top_right();
                return self.rect.top_left();
            }
            pub fn top_right(self: PackedRect) Vec {
                if (self.is_rotated()) return self.rect.bot_right();
                return self.rect.top_right();
            }
            pub fn bot_left(self: PackedRect) Vec {
                if (self.is_rotated()) return self.rect.top_left();
                return self.rect.bot_left();
            }
            pub fn bot_right(self: PackedRect) Vec {
                if (self.is_rotated()) return self.rect.bot_left();
                return self.rect.bot_right();
            }

            pub fn equals(self: PackedRect, other: PackedRect) bool {
                return self.rect.equals(other.rect) and self.location_info == other.location_info;
            }
        };

        /// A packed rect after its layer index has been hydrated from its row
        /// index. This is a one-way view for consumers: the row/location index
        /// stays in `PackedRect`, so it cannot be reconstructed from this type.
        pub const HydratedRect = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            is_rotated: bool,
            layer_idx: LAYER_IDX = 0,
            userdata: Userdata,

            pub fn top_left(self: HydratedRect) Vec {
                if (self.is_rotated) return self.rect.top_right();
                return self.rect.top_left();
            }
            pub fn top_right(self: HydratedRect) Vec {
                if (self.is_rotated) return self.rect.bot_right();
                return self.rect.top_right();
            }
            pub fn bot_left(self: HydratedRect) Vec {
                if (self.is_rotated) return self.rect.top_left();
                return self.rect.bot_left();
            }
            pub fn bot_right(self: HydratedRect) Vec {
                if (self.is_rotated) return self.rect.bot_left();
                return self.rect.bot_right();
            }

            pub fn equals(self: HydratedRect, other: HydratedRect) bool {
                return self.rect.equals(other.rect) and
                    self.is_rotated == other.is_rotated and
                    self.layer_idx == other.layer_idx;
            }
        };

        const Row = struct {
            kind: RowKind = .CONSTRAINED,
            layer_idx: LAYER_IDX = 0,
            pos: Vec = .{},
            width: SIZE_TYPE = 0,
            used_width: SIZE_TYPE = 0,
            min_height: SIZE_TYPE = 0,
            max_height: SIZE_TYPE = 0,
            true_max_height: SIZE_TYPE = 0,
            num_claimed: RECT_IDX = 0,
            next_hole: RECT_IDX = NULL_HOLE_IDX,

            inline fn is_empty(self: Row) bool {
                return self.used_width == 0 and self.max_height == 0;
            }

            inline fn can_fit_size(self: Row, size: Vec) bool {
                return switch (self.kind) {
                    .CONSTRAINED => self.width >= size.x and self.max_height >= size.y,
                    .UNCONSTRAINED => self.width >= size.x and self.true_max_height >= size.y,
                };
            }

            inline fn can_fit_size_on_new_row(self: Row, size: Vec) bool {
                return self.kind == .UNCONSTRAINED and
                    self.width + self.used_width >= size.x and
                    self.true_max_height - self.max_height >= size.y;
            }

            fn new_height_is_within_threshold(self: Row, threshold: ThresholdVal, height: SIZE_TYPE) bool {
                switch (self.kind) {
                    .CONSTRAINED => {
                        if (height > self.max_height) return false;
                        const new_min = @min(self.min_height, height);
                        const new_min_f: f32 = num_cast(new_min, f32);
                        const max_f: f32 = num_cast(self.max_height, f32);
                        const within_percent = (new_min_f / max_f) >= threshold.percent;
                        if (within_percent) return true;
                        return self.max_height - new_min <= threshold.flat_tolerance;
                    },
                    .UNCONSTRAINED => {
                        const new_min = @min(self.min_height, height);
                        const new_max = @max(self.max_height, height);
                        const new_min_f: f32 = num_cast(new_min, f32);
                        const new_max_f: f32 = num_cast(new_max, f32);
                        const within_percent = (new_min_f / new_max_f) >= threshold.percent;
                        if (within_percent) return true;
                        return (new_max - new_min) <= threshold.flat_tolerance;
                    },
                }
            }

            fn wasted_area_if_claimed(self: Row, size: Vec) SIZE_TYPE {
                return switch (self.kind) {
                    .CONSTRAINED => (self.max_height - size.y) * size.x,
                    .UNCONSTRAINED => if (size.y > self.max_height)
                        (size.y - self.max_height) * self.used_width
                    else
                        (self.max_height - size.y) * size.x,
                };
            }
        };

        const Layer = struct {
            open_row_idx: ROW_IDX = 0,
        };

        pub const Hole = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            next: RECT_IDX = NULL_HOLE_IDX,

            fn wasted_area_if_claimed(self: Hole, size: Vec) SIZE_TYPE {
                return (self.rect.size.x - size.x) * self.rect.size.y + (self.rect.size.y - size.y) * size.x;
            }
        };

        fn doubled_threshold(value: ThresholdVal) ThresholdVal {
            return switch (@typeInfo(SIZE_TYPE)) {
                .int => ThresholdVal{
                    .flat_tolerance = value.flat_tolerance *| 2,
                    .percent = value.percent * 0.5,
                },
                .float => ThresholdVal{
                    .flat_tolerance = value.flat_tolerance * 2,
                    .percent = value.percent * 0.5,
                },
                else => comptime assert_unreachable(@src(), "LayeredRowPacker requires an integer or floating-point coordinate type", .{}),
            };
        }
    };
}

pub fn LayeredRowPackedAtlas(
    comptime KEY: type,
    comptime HASH: fn (KEY) u64,
    comptime KEYS_EQUAL: fn (KEY, KEY) bool,
    comptime HASH_MAP_OVERRIDES: HashMapOverrides,
    comptime PACKER_DEF: PackerDef,
) type {
    return struct {
        const Self = @This();
        pub const Packer = LayeredRowPacker(PACKER_DEF.with_no_locks());
        pub const Rect = Packer.Rect;
        pub const PackedRect = Packer.PackedRect;
        pub const HydratedRect = Packer.HydratedRect;
        pub const Vec = Packer.Vec;
        pub const AABB = Packer.AABB;
        pub const Threshold = Packer.Threshold;
        pub const ThresholdVal = Packer.ThresholdVal;
        pub const Map = HashMap(KEY, PackedRect, HASH, KEYS_EQUAL, HASH_MAP_OVERRIDES);

        const RECT_IDX = PACKER_DEF.RECT_IDX;
        const ROW_IDX = PACKER_DEF.ROW_IDX;
        const LAYER_IDX = PACKER_DEF.LAYER_IDX;
        const LOCK_KIND = PACKER_DEF.LOCK_KIND;
        const LOCK_ASSERT = PACKER_DEF.LOCK_ASSERTS;
        const Lock = LOCK_KIND.lock_type(LOCK_ASSERT);
        const LOCK_INIT = LOCK_KIND.init_lock(LOCK_ASSERT);
        const LockIo = LOCK_KIND.io_type();
        const LOCK_IO_INIT = LOCK_KIND.null_io();
        pub const Alloc = AllocAdapter(PACKER_DEF.ALLOC_SOURCE);
        pub const PassedAlloc = Alloc.PassedAlloc;
        pub const InitAlloc = Alloc.InitAlloc;

        hash_map: Map = .{},
        packer: Packer = .{},
        alloc: Alloc = .{},
        lock: Lock = LOCK_INIT,
        io: LockIo = LOCK_IO_INIT,

        pub inline fn lock_for_read(self: *Self) void {
            LOCK_KIND.lock_for_read(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn unlock_for_read(self: *Self) void {
            LOCK_KIND.unlock_for_read(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn lock_for_write(self: *Self) void {
            LOCK_KIND.lock_for_write(LOCK_ASSERT, &self.lock, self.io);
        }
        pub inline fn unlock_for_write(self: *Self) void {
            LOCK_KIND.unlock_for_write(LOCK_ASSERT, &self.lock, self.io);
        }

        pub fn init(
            self: *Self,
            hash_map_cap: RECT_IDX,
            row_cap: ROW_IDX,
            hole_cap: RECT_IDX,
            layer_cap: LAYER_IDX,
            region: Rect,
            default_height_fit_threshold: ThresholdVal,
            alloc: InitAlloc,
            io: LockIo,
        ) void {
            self.lock = LOCK_INIT;
            self.io = io;
            self.lock_for_write();
            defer self.unlock_for_write();
            self.alloc = Alloc.new_from_init_alloc(alloc);
            self.hash_map = Map.init_capacity(@intCast(hash_map_cap), self.alloc.get_alloc(Alloc.init_to_passed_alloc(alloc)));
            self.packer.init(@intCast(row_cap), hole_cap, layer_cap, region, default_height_fit_threshold, alloc, io);
        }

        pub fn clear_entire_atlas(self: *Self, alloc: PassedAlloc) void {
            self.lock_for_write();
            defer self.unlock_for_write();
            self.hash_map.clear();
            self.packer.reset(alloc);
        }

        pub fn uninit(self: *Self, alloc: PassedAlloc) void {
            self.lock_for_write();
            defer self.unlock_for_write();
            self.hash_map.uninit(self.alloc.get_alloc(alloc));
            self.packer.uninit(alloc);
        }

        pub fn claim_rect(
            self: *Self,
            key: KEY,
            size: Vec,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Packer.Userdata,
        ) ?HydratedRect {
            self.lock_for_write();
            defer self.unlock_for_write();
            const hash_parts = Map.hash_parts(key);
            assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
            const possible_rect = self.packer.claim_rect(size, threshold, waste, rotation, grow, alloc, userdata);
            if (possible_rect) |packed_rect| {
                self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, self.alloc.get_alloc(alloc));
                return self.packer.hydrate_rect(packed_rect);
            }
            return null;
        }

        pub fn lookup_rect_if_exists(self: *Self, key: KEY) ?HydratedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            if (self.hash_map.get_if_exists(key)) |packed_rect| {
                return self.packer.hydrate_rect(packed_rect);
            }
            return null;
        }

        pub fn lookup_rect(self: *Self, key: KEY) HydratedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.packer.hydrate_rect(self.hash_map.get(key));
        }

        pub fn release_rect(self: *Self, key: KEY, alloc: PassedAlloc) void {
            self.lock_for_write();
            defer self.unlock_for_write();
            const packed_rect = self.hash_map.remove_key(key);
            self.packer.release_rect(packed_rect, alloc);
        }

        pub fn add_layer(self: *Self, alloc: PassedAlloc) LAYER_IDX {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.packer.add_layer(alloc);
        }

        pub fn layer_count(self: *Self) LAYER_IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.packer.layer_count();
        }
    };
}
