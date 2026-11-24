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
const AllocSource = Root.Allocator.AllocSource;
const BackPointStrategy = BitTrackedBlocksPoolModule.BackPointStrategy;
const Io = std.Io;
const AllocAdapter = Root.Allocator.AllocatorAdapter;
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
        _ = @import("./RectPacker_LayeredRowPackedAtlas_Tests.zig");
    }
}

/// The number of color channels a claim needs. The packer selects the actual
/// channels from the free mask at the chosen location and reports the used
/// mask through `PackedRect`/`LocatedRect`.
pub const ChannelRequest = enum(u3) {
    ONE = 1,
    TWO = 2,
    THREE = 3,
    FOUR = 4,

    pub inline fn count(self: ChannelRequest) u3 {
        return @backingInt(self);
    }
};

/// Controls whether a failed claim may append a new array layer.
pub const GrowMode = enum(u8) {
    DO_NOT_ADD_LAYER,
    ADD_LAYER,

    pub inline fn do_not_add_layer() GrowMode {
        return GrowMode.DO_NOT_ADD_LAYER;
    }
    pub inline fn add_layer() GrowMode {
        return GrowMode.ADD_LAYER;
    }
};

pub const PackerDef = struct {
    SIZE_TYPE: type,
    IDX: type = u32,
    RELEASE_MODE: ReleaseMode = .CLAIM_AND_RELEASE,
    ALLOC_SOURCE: AllocSource = .CACHED_ALLOCATOR_INTERFACE,
    LOCK_KIND: LockKind = .NONE,
    LOCK_ASSERTS: bool = true,
    HOLE_POOL_BACK_STRATEGY: BackPointStrategy = .SORTED_BLOCKS_BINARY_SEARCH,
    HOLE_POOL_SLOTS_PER_BLOCK: comptime_int = 64,
    HOLE_POOL_STATE_UINT: type = usize,
    USERDATA_TYPE: type = void,
};
pub const PackerDefNoLocks = struct {
    SIZE_TYPE: type,
    IDX: type = u32,
    RELEASE_MODE: ReleaseMode = .CLAIM_AND_RELEASE,
    ALLOC_SOURCE: AllocSource = .CACHED_ALLOCATOR_INTERFACE,
    HOLE_POOL_BACK_STRATEGY: BackPointStrategy = .SORTED_BLOCKS_BINARY_SEARCH,
    HOLE_POOL_SLOTS_PER_BLOCK: comptime_int = 64,
    HOLE_POOL_STATE_UINT: type = usize,
    USERDATA_TYPE: type = void,

    pub fn to_def(comptime self: PackerDefNoLocks) PackerDef {
        return PackerDef{
            .SIZE_TYPE = self.SIZE_TYPE,
            .ALLOC_SOURCE = self.ALLOC_SOURCE,
            .HOLE_POOL_BACK_STRATEGY = self.HOLE_POOL_BACK_STRATEGY,
            .HOLE_POOL_SLOTS_PER_BLOCK = self.HOLE_POOL_SLOTS_PER_BLOCK,
            .HOLE_POOL_STATE_UINT = self.HOLE_POOL_STATE_UINT,
            .IDX = self.IDX,
            .LOCK_ASSERTS = false,
            .LOCK_KIND = .NONE,
            .RELEASE_MODE = self.RELEASE_MODE,
            .USERDATA_TYPE = self.USERDATA_TYPE,
        };
    }
};

/// Packs rects into horizontal shelves, exactly like `RowPacker`, but over a
/// variable number of equally sized texture-array layers.
///
/// The key differences from `RowPacker`:
///
/// * Every layer owns one active (unconstrained) shelf row.
/// * Closed shelves from every layer are stored in one `rows` list. A closed
///   shelf keeps its owning `layer_idx`.
/// * Rows are addressed by a stable index. A packed rect stores only a
///   `location_index`:
///   `(row_idx << 5) | (is_rotated << 4) | channel_mask`.
/// * The 4-bit channel mask records exactly which channels the claim used.
///   A claim may request 1..4 channels and the chosen channels do not need to
///   be contiguous.
/// * New row tails have an implicit free mask of `0b1111`. Holes carry their
///   existing free mask, and claims check it with `@popCount`.
/// * The rotation bit means the claimed area is rotated 90 degrees: the
///   returned rect holds the actual footprint, and the consumer rotates its
///   source content into it.
/// * A row index therefore identifies both the shelf and its layer. The layer
///   index is hydrated through `rows[row_idx].layer_idx` when a rect is
///   looked up, instead of being stored in the packed rect.
/// * Claiming a 1-channel rect reserves the full 2D footprint in its row, then
///   pushes the unused channels into a `Hole` whose rect is exactly the
///   claimed rect. Releasing the single-channel rects at that footprint merges
///   their channel masks back into a full 4-channel hole.
/// * Holes carry a channel mask. A hole can satisfy a 4-channel claim only when
///   its mask is `0b1111`; it can satisfy a 1-channel claim when any bit is set.
pub fn RowArrayPacker(comptime DEF: PackerDef) type {
    return struct {
        const Self = @This();
        const SIZE_TYPE = DEF.SIZE_TYPE;
        const IDX = DEF.IDX;
        const RELEASE_MODE = DEF.RELEASE_MODE;
        const ALLOC_SOURCE = DEF.ALLOC_SOURCE;
        const LOCK_KIND = DEF.LOCK_KIND;
        const LOCK_ASSERTS = DEF.LOCK_ASSERTS;
        const HOLE_POOL_BACK_STRATEGY = DEF.HOLE_POOL_BACK_STRATEGY;
        const HOLE_POOL_SLOTS_PER_BLOCK = DEF.HOLE_POOL_SLOTS_PER_BLOCK;
        const HOLE_POOL_STATE_UINT = DEF.HOLE_POOL_STATE_UINT;
        pub const Userdata = DEF.USERDATA_TYPE;

        pub const AABB = AABB2.define_aabb2_type(SIZE_TYPE);
        pub const Rect = Rect2.define_rect2_type(SIZE_TYPE);
        pub const Vec = Vec2.define_vec2_type(SIZE_TYPE);

        const CAN_RELEASE = RELEASE_MODE == .CLAIM_AND_RELEASE;
        const Lock = LOCK_KIND.lock_type(LOCK_ASSERTS);
        const LOCK_INIT = LOCK_KIND.init(LOCK_ASSERTS);
        const LockIo = LOCK_KIND.io_type();
        const LOCK_IO_INIT = LOCK_KIND.null_io();
        const Alloc = AllocAdapter(DEF.ALLOC_SOURCE);
        const PassedAlloc = Alloc.PassedAlloc;
        const InitAlloc = Alloc.InitAlloc;

        pub const NUM_CHANNELS: comptime_int = 4;
        pub const FULL_CHANNEL_MASK: u4 = 0b1111;

        const CHANNEL_MASK_LOW_BITS: IDX = 0b1111;
        const ROTATION_MASK: IDX = 0b1_0000;
        const LOCATION_ROW_SHIFT: comptime_int = 5;
        const MAX_ROW_INDEX: IDX = MathX.max_value(IDX) >> LOCATION_ROW_SHIFT;
        const NULL_HOLE_IDX: IDX = HolePool.NULL_SLOT_IDX;
        const MAX_HEIGHT: SIZE_TYPE = MathX.max_value(SIZE_TYPE);

        const RowList = ListFull(Row, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, ALLOC_SOURCE);
        const LayerList = ListFull(Layer, IDX, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, ALLOC_SOURCE);

        const HolePool = BitBlockPool(.{
            .ELEM = Hole,
            .ALLOC_SOURCE = ALLOC_SOURCE,
            .BACK_POINT_STRATEGY = HOLE_POOL_BACK_STRATEGY,
            .IDX = IDX,
            .LOCK_MODE = .NO_LOCKS,
            .SLOTS_PER_BLOCK = HOLE_POOL_SLOTS_PER_BLOCK,
            .STATE_UINT = HOLE_POOL_STATE_UINT,
        });

        alloc: Alloc = .{},
        rows: RowList = .{},
        layers: LayerList = .{},
        holes_pool: if (CAN_RELEASE) HolePool else void = if (CAN_RELEASE) HolePool{} else {},
        layer_region: Rect = .{ .pos = .{}, .size = .{} },
        default_height_fit_threshold: ThresholdVal = .threshold_val(0.9, 4),
        total_wasted_area: SIZE_TYPE = 0,
        claim_count: IDX = 0,
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
            LOCK_KIND.lock_for_read(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn unlock_for_read(self: *Self) void {
            LOCK_KIND.unlock_for_read(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn lock_for_write(self: *Self) void {
            LOCK_KIND.lock_for_write(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn unlock_for_write(self: *Self) void {
            LOCK_KIND.unlock_for_write(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }

        pub fn add_layer(self: *Self, alloc: PassedAlloc) IDX {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.add_layer_internal(alloc);
        }

        fn add_layer_internal(self: *Self, alloc: PassedAlloc) IDX {
            const layer_idx = self.layers.get_len();
            const row_idx = self.append_row(.{
                .kind = .UNCONSTRAINED,
                .layer_idx = layer_idx,
                .pos = self.layer_region.pos,
                .width = self.layer_region.size.x,
                .used_width = 0,
                .min_height = MAX_HEIGHT,
                .max_height = 0,
                .true_max_height = self.layer_region.size.y,
                .num_claimed = 0,
                .next_hole = NULL_HOLE_IDX,
            }, alloc);
            self.layers.append_one(.{ .open_row_idx = row_idx }, alloc);
            return layer_idx;
        }

        fn append_row(self: *Self, row: Row, alloc: PassedAlloc) IDX {
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

        pub fn layer_count(self: *Self) IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.layers.get_len();
        }

        pub fn row_count(self: *Self) IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.rows.get_len();
        }

        pub fn init(
            self: *Self,
            row_cap: IDX,
            hole_cap: IDX,
            layer_cap: IDX,
            region: Rect,
            default_height_fit_threshold: ThresholdVal,
            alloc: InitAlloc,
            io: LockIo,
        ) void {
            self.io = io;
            self.lock_for_write();
            defer self.unlock_for_write();
            const passed = Alloc.init_to_passed_alloc(alloc);
            self.alloc = Alloc.new_from_init_alloc(alloc);
            self.rows = RowList.allocate_new(row_cap, alloc);
            self.layers = LayerList.allocate_new(layer_cap, alloc);
            self.layer_region = region;
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
            defer self.unlock_for_write();
            self.rows.free_if_non_zero(alloc);
            self.layers.free_if_non_zero(alloc);
            if (comptime CAN_RELEASE) {
                self.holes_pool.uninit(alloc);
            }
            self.* = .{};
        }

        //----------------------------------------------------------------------
        // LOCATION INDEX
        //----------------------------------------------------------------------

        pub inline fn make_location_index(row_idx: IDX, used_channel_mask: u4, is_rotated: bool) IDX {
            const rotation: IDX = if (is_rotated) ROTATION_MASK else 0;
            return (row_idx << LOCATION_ROW_SHIFT) | rotation | @as(IDX, used_channel_mask);
        }

        pub inline fn location_index_row(location_index: IDX) IDX {
            return location_index >> LOCATION_ROW_SHIFT;
        }

        pub inline fn location_index_is_rotated(location_index: IDX) bool {
            return (location_index & ROTATION_MASK) != 0;
        }

        pub inline fn location_index_channel_mask(location_index: IDX) u4 {
            return @intCast(location_index & CHANNEL_MASK_LOW_BITS);
        }

        pub inline fn location_index_is_full(location_index: IDX) bool {
            return location_index_channel_mask(location_index) == FULL_CHANNEL_MASK;
        }

        inline fn choose_channel_mask(available: u4, count: u3) ?u4 {
            const free_count: u4 = @popCount(available);
            if (free_count < @as(u4, count)) return null;

            var remaining: u4 = count;
            var mask = available;
            var used: u4 = 0;
            while (remaining > 0) : (remaining -= 1) {
                const bit_index: u2 = @intCast(@ctz(mask));
                const bit: u4 = @as(u4, 1) << bit_index;
                used |= bit;
                mask &= mask - 1;
            }
            return used;
        }

        //----------------------------------------------------------------------
        // CLAIM
        //----------------------------------------------------------------------

        /// Claims a rect. `channels` requests between one and four color
        /// channels. The packer selects the lowest free channels at the chosen
        /// location, and the used mask is reported by
        /// `PackedRect.channel_mask()`. The mask may be sparse.
        ///
        /// If `rotation != .DO_NOT_ALLOW_ROTATION`, a returned rect with
        /// `is_rotated() == true` has its actual `rect.size` swapped relative
        /// to the requested `size`; the consumer should rotate its source
        /// content 90 degrees into that footprint.
        ///
        /// A null result means no existing layer had a suitable spot. If
        /// `grow == .ADD_LAYER`, a new layer is appended and used as a last
        /// resort. The returned `PackedRect` does not store the layer index;
        /// use `locate_rect` (or the atlas wrapper) to hydrate it.
        pub fn claim_rect(
            self: *Self,
            size: Vec,
            channels: ChannelRequest,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.claim_rect_internal(size, channels, threshold, waste, rotation, grow, alloc, userdata);
        }

        fn claim_rect_internal(
            self: *Self,
            size: Vec,
            channels: ChannelRequest,
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
            const fits_region_unrotated = size.x <= self.layer_region.size.x and size.y <= self.layer_region.size.y;
            const fits_region_rotated = rot_size.x <= self.layer_region.size.x and rot_size.y <= self.layer_region.size.y;
            if ((!allow_unrotated or !fits_region_unrotated) and (!allow_rotated or !fits_region_rotated)) return null;

            const threshold_value: ?ThresholdVal = switch (threshold) {
                .IGNORE_THRESHOLD => null,
                .DEFAULT_THRESHOLD => self.default_height_fit_threshold,
                .CUSTOM_THRESHOLD => |t| t,
            };

            var best_any: Candidate = .{};
            var best_threshold: Candidate = .{};

            var row_idx: IDX = 0;
            while (row_idx < self.rows.get_len()) : (row_idx += 1) {
                const row = self.rows.get_ptr(row_idx);
                if (row.kind != .CONSTRAINED) continue;
                self.evaluate_row(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, channels, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, alloc, userdata);
                }
            }

            row_idx = 0;
            while (row_idx < self.rows.get_len()) : (row_idx += 1) {
                const row = self.rows.get_ptr(row_idx);
                if (row.kind != .UNCONSTRAINED) continue;
                self.evaluate_row(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, channels, waste, threshold_value, &best_threshold, &best_any);
                if (first_fit_ready(waste, threshold_value, best_threshold, best_any)) |candidate| {
                    return self.claim_candidate(candidate, alloc, userdata);
                }
            }

            const selected = if (best_threshold.kind != .NONE) best_threshold else best_any;

            if (best_threshold.kind == .NONE and threshold_value != null) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, channels, alloc, userdata)) |packed_rect| {
                    return packed_rect;
                }
            }

            if (selected.kind == .NONE) {
                if (self.try_claim_on_new_row(size, rot_size, allow_unrotated, allow_rotated, channels, alloc, userdata)) |packed_rect| {
                    return packed_rect;
                }
                if (grow == .ADD_LAYER) {
                    return self.claim_on_new_layer(size, rot_size, allow_unrotated, allow_rotated, channels, alloc, userdata);
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
                        if (self.claim_on_new_row_for_layer(selected_row.layer_idx, selected.size, selected.is_rotated, channels, alloc, userdata)) |packed_rect| {
                            return packed_rect;
                        }
                    }
                }
            }

            return self.claim_candidate(selected, alloc, userdata);
        }

        const RowKind = enum(u2) {
            CONSTRAINED,
            UNCONSTRAINED,
        };

        const CandidateKind = enum(u2) {
            NONE,
            HOLE,
            ROW_TAIL,
        };

        const Candidate = struct {
            kind: CandidateKind = .NONE,
            row_idx: IDX = 0,
            hole_idx: IDX = NULL_HOLE_IDX,
            size: Vec = .{},
            is_rotated: bool = false,
            used_channel_mask: u4 = 0,
            waste: SIZE_TYPE = 0,
            threshold_ok: bool = false,

            inline fn consider(self: *Candidate, waste_mode: WasteMode, candidate: Candidate) void {
                if (self.kind == .NONE or (waste_mode == .LEAST_WASTE and candidate.waste < self.waste)) {
                    self.* = candidate;
                }
            }
        };

        fn evaluate_row(
            self: *Self,
            row: *Row,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            channels: ChannelRequest,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            self.evaluate_holes(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, channels, waste_mode, threshold_value, best_threshold, best_any);
            self.evaluate_tail(row, row_idx, size, rot_size, allow_unrotated, allow_rotated, channels, waste_mode, threshold_value, best_threshold, best_any);
        }

        fn evaluate_holes(
            self: *Self,
            row: *Row,
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            channels: ChannelRequest,
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

                    const used_channel_mask = choose_channel_mask(hole.channel_mask, channels.count()) orelse {
                        hole_idx = next_hole_idx;
                        continue;
                    };

                    if (allow_unrotated and hole.rect.size.x >= size.x and hole.rect.size.y >= size.y) {
                        const candidate = Candidate{
                            .kind = .HOLE,
                            .row_idx = row_idx,
                            .hole_idx = hole_idx,
                            .size = size,
                            .is_rotated = false,
                            .used_channel_mask = used_channel_mask,
                            .waste = if (waste_mode == .LEAST_WASTE) hole.wasted_area_if_claimed(size) else 0,
                            .threshold_ok = true,
                        };
                        best_any.consider(waste_mode, candidate);
                        if (threshold_value != null) {
                            // Holes are existing usable space, so they are always
                            // threshold-compatible, matching RowPacker.
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
                            .used_channel_mask = used_channel_mask,
                            .waste = if (waste_mode == .LEAST_WASTE) hole.wasted_area_if_claimed(rot_size) else 0,
                            .threshold_ok = true,
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
            row_idx: IDX,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            channels: ChannelRequest,
            waste_mode: WasteMode,
            threshold_value: ?ThresholdVal,
            best_threshold: *Candidate,
            best_any: *Candidate,
        ) void {
            _ = self;
            const used_channel_mask = choose_channel_mask(FULL_CHANNEL_MASK, channels.count()) orelse return;

            if (allow_unrotated and row.can_fit_size(size)) {
                const threshold_ok = if (threshold_value) |t| row.new_height_is_within_threshold(t, size.y) else true;
                const candidate = Candidate{
                    .kind = .ROW_TAIL,
                    .row_idx = row_idx,
                    .hole_idx = NULL_HOLE_IDX,
                    .size = size,
                    .is_rotated = false,
                    .used_channel_mask = used_channel_mask,
                    .waste = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(size) else 0,
                    .threshold_ok = threshold_ok,
                };
                best_any.consider(waste_mode, candidate);
                if (threshold_ok) {
                    best_threshold.consider(waste_mode, candidate);
                }
            }

            if (allow_rotated and row.can_fit_size(rot_size)) {
                const threshold_ok = if (threshold_value) |t| row.new_height_is_within_threshold(t, rot_size.y) else true;
                const candidate = Candidate{
                    .kind = .ROW_TAIL,
                    .row_idx = row_idx,
                    .hole_idx = NULL_HOLE_IDX,
                    .size = rot_size,
                    .is_rotated = true,
                    .used_channel_mask = used_channel_mask,
                    .waste = if (waste_mode == .LEAST_WASTE) row.wasted_area_if_claimed(rot_size) else 0,
                    .threshold_ok = threshold_ok,
                };
                best_any.consider(waste_mode, candidate);
                if (threshold_ok) {
                    best_threshold.consider(waste_mode, candidate);
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
                    self.claim_from_hole(candidate.row_idx, candidate.hole_idx, candidate.size, candidate.is_rotated, candidate.used_channel_mask, alloc, userdata)
                else
                    unreachable,
                .ROW_TAIL => self.claim_from_tail(candidate.row_idx, candidate.size, candidate.is_rotated, candidate.used_channel_mask, alloc, userdata),
                .NONE => unreachable,
            };
        }

        fn claim_from_tail(
            self: *Self,
            row_idx: IDX,
            size: Vec,
            is_rotated: bool,
            used_mask: u4,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
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

            const leftover_mask = FULL_CHANNEL_MASK & ~used_mask;
            if (comptime CAN_RELEASE) {
                if (leftover_mask != 0) {
                    const hole = self.holes_pool.claim_slot(alloc);
                    const hole_idx = self.holes_pool.slot_index_ignore_locks(hole);
                    hole.rect = Rect.new(pos, size);
                    hole.channel_mask = leftover_mask;
                    hole.next = row.next_hole;
                    row.next_hole = hole_idx;
                }
            }

            return PackedRect{
                .rect = Rect.new(pos, size),
                .location_index = make_location_index(row_idx, used_mask, is_rotated),
                .userdata = userdata,
            };
        }

        fn claim_from_hole(
            self: *Self,
            row_idx: IDX,
            hole_idx: IDX,
            size: Vec,
            is_rotated: bool,
            used_mask: u4,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
            const row = self.rows.get_ptr(row_idx);
            const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
            const hole_rect = hole.rect;
            const hole_mask = hole.channel_mask;

            self.remove_hole(row, hole_idx);

            const claimed_rect = Rect.new(hole_rect.pos, size);
            const remaining_width = hole_rect.size.x - size.x;
            const remaining_height = hole_rect.size.y - size.y;

            // Reuse the existing hole slot for the first remainder we need,
            // then allocate pool slots for the rest.
            var reused = false;
            var leftover_idx: IDX = NULL_HOLE_IDX;
            var right_idx: IDX = NULL_HOLE_IDX;
            var bottom_idx: IDX = NULL_HOLE_IDX;

            const leftover_mask = hole_mask & ~used_mask;
            if (leftover_mask != 0) {
                hole.rect = claimed_rect;
                hole.channel_mask = leftover_mask;
                leftover_idx = hole_idx;
                reused = true;
            }
            if (remaining_width > 0) {
                const h = if (!reused) blk: {
                    reused = true;
                    break :blk hole;
                } else self.holes_pool.claim_slot(alloc);
                h.rect = Rect.new(
                    Vec.new(hole_rect.pos.x + size.x, hole_rect.pos.y),
                    Vec.new(remaining_width, hole_rect.size.y),
                );
                h.channel_mask = hole_mask;
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
                h.channel_mask = hole_mask;
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
            if (leftover_idx != NULL_HOLE_IDX) {
                const h = self.holes_pool.slot_from_index_ignore_locks(leftover_idx);
                h.next = head;
                head = leftover_idx;
            }
            row.next_hole = head;

            row.num_claimed += 1;
            self.claim_count +|= 1;

            return PackedRect{
                .rect = claimed_rect,
                .location_index = make_location_index(row_idx, used_mask, is_rotated),
                .userdata = userdata,
            };
        }

        fn claim_on_new_layer(
            self: *Self,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            channels: ChannelRequest,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) PackedRect {
            const use_unrotated = allow_unrotated and
                size.x <= self.layer_region.size.x and size.y <= self.layer_region.size.y;
            if (!use_unrotated) {
                assert_with_reason(allow_rotated, @src(), "rotated new-layer claim was not allowed", .{});
            }
            const claim_size = if (use_unrotated) size else rot_size;
            const is_rotated = !use_unrotated;
            const layer_idx = self.add_layer_internal(alloc);
            return self.claim_on_new_row_for_layer(layer_idx, claim_size, is_rotated, channels, alloc, userdata).?;
        }

        fn try_claim_on_new_row(
            self: *Self,
            size: Vec,
            rot_size: Vec,
            allow_unrotated: bool,
            allow_rotated: bool,
            channels: ChannelRequest,
            alloc: PassedAlloc,
            userdata: Userdata,
        ) ?PackedRect {
            var layer_idx: IDX = 0;
            while (layer_idx < self.layers.get_len()) : (layer_idx += 1) {
                const open_row = self.rows.get_ptr(self.layers.get_ptr(layer_idx).open_row_idx);
                if (allow_unrotated and open_row.can_fit_size_on_new_row(size)) {
                    return self.claim_on_new_row_for_layer(layer_idx, size, false, channels, alloc, userdata);
                }
                if (allow_rotated and open_row.can_fit_size_on_new_row(rot_size)) {
                    return self.claim_on_new_row_for_layer(layer_idx, rot_size, true, channels, alloc, userdata);
                }
            }
            return null;
        }

        fn claim_on_new_row_for_layer(
            self: *Self,
            layer_idx: IDX,
            size: Vec,
            is_rotated: bool,
            channels: ChannelRequest,
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

            const used_mask = choose_channel_mask(FULL_CHANNEL_MASK, channels.count()) orelse return null;
            return self.claim_from_tail(new_row_idx, size, is_rotated, used_mask, alloc, userdata);
        }

        /// Closes a layer's current unconstrained shelf in place, then appends
        /// a fresh unconstrained shelf for the layer. Returns the new row index.
        fn close_open_row(self: *Self, layer_idx: IDX, alloc: PassedAlloc) IDX {
            const layer = self.layers.get_ptr(layer_idx);
            const old_row_idx = layer.open_row_idx;
            const old_row = self.rows.get_ptr(old_row_idx);
            assert_with_reason(old_row.kind == .UNCONSTRAINED, @src(), "open row is not unconstrained", .{});

            if (old_row.is_empty()) {
                return old_row_idx;
            }

            // Copy everything we need before appending can reallocate `rows`.
            const old_y = old_row.pos.y;
            const old_max_height = old_row.max_height;
            const old_true_max_height = old_row.true_max_height;

            old_row.kind = .CONSTRAINED;
            old_row.true_max_height = 0;

            const new_row_idx = self.append_row(.{
                .kind = .UNCONSTRAINED,
                .layer_idx = layer_idx,
                .pos = Vec.new(self.layer_region.pos.x, old_y + old_max_height),
                .width = self.layer_region.size.x,
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

        //----------------------------------------------------------------------
        // RELEASE
        //----------------------------------------------------------------------

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

            self.add_hole(row, rect.rect, rect.channel_mask(), alloc);
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

        fn add_hole(self: *Self, row: *Row, rect: Rect, channel_mask: u4, alloc: PassedAlloc) void {
            if (comptime CAN_RELEASE) {
                if (channel_mask == 0) return;

                // Releasing the same rect that produced a 1-channel hole will
                // coalesce channel masks. When every channel is present again
                // the hole becomes a full 4-channel hole and can satisfy `.FOUR`.
                var hole_idx = row.next_hole;
                while (hole_idx != NULL_HOLE_IDX) {
                    const hole = self.holes_pool.slot_from_index_ignore_locks(hole_idx);
                    if (hole.rect.equals(rect)) {
                        hole.channel_mask |= channel_mask;
                        return;
                    }
                    hole_idx = hole.next;
                }

                const hole = self.holes_pool.claim_slot(alloc);
                const new_hole_idx = self.holes_pool.slot_index_ignore_locks(hole);
                hole.rect = rect;
                hole.channel_mask = channel_mask;
                hole.next = row.next_hole;
                row.next_hole = new_hole_idx;
            }
        }

        fn remove_hole(self: *Self, row: *Row, hole_idx: IDX) void {
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

        //----------------------------------------------------------------------
        // RETRIEVAL
        //----------------------------------------------------------------------

        /// Hydrates a stored packed rect with its layer index. This does not
        /// mutate the packed rect and does not require the atlas hash map.
        pub fn locate_rect(self: *Self, packed_rect: PackedRect) LocatedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.locate_rect_no_lock(packed_rect);
        }

        fn locate_rect_no_lock(self: *Self, packed_rect: PackedRect) LocatedRect {
            const row_idx = packed_rect.row_index();
            assert_with_reason(row_idx < self.rows.get_len(), @src(), "row idx for rect is out of bounds for packer", .{});
            const row = self.rows.get_ptr(row_idx);
            return LocatedRect{
                .rect = packed_rect.rect,
                .location_index = packed_rect.location_index,
                .layer_idx = row.layer_idx,
                .userdata = packed_rect.userdata,
            };
        }

        //----------------------------------------------------------------------
        // TYPES
        //----------------------------------------------------------------------

        pub const PackedRect = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            /// `(row_idx << 5) | (is_rotated << 4) | channel_mask`.
            location_index: IDX = 0,
            userdata: Userdata,

            pub fn new(rect: Rect, location_index: IDX, userdata: Userdata) PackedRect {
                return PackedRect{
                    .rect = rect,
                    .location_index = location_index,
                    .userdata = userdata,
                };
            }

            pub fn to_located(self: PackedRect, packer: *Self) LocatedRect {
                return packer.locate_rect(self);
            }

            pub inline fn row_index(self: PackedRect) IDX {
                return location_index_row(self.location_index);
            }
            pub inline fn is_rotated(self: PackedRect) bool {
                return location_index_is_rotated(self.location_index);
            }
            /// The color channels used by this claim. May be sparse.
            pub inline fn channel_mask(self: PackedRect) u4 {
                return location_index_channel_mask(self.location_index);
            }
            pub inline fn channel_count(self: PackedRect) u3 {
                return @popCount(self.channel_mask());
            }
            pub inline fn is_full(self: PackedRect) bool {
                return self.channel_mask() == FULL_CHANNEL_MASK;
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
                return self.rect.equals(other.rect) and self.location_index == other.location_index;
            }
        };

        /// A packed rect after its layer index has been hydrated from its row
        /// index. The layer index is deliberately not part of `PackedRect`.
        pub const LocatedRect = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            location_index: IDX = 0,
            layer_idx: IDX = 0,
            userdata: Userdata,

            pub fn to_packed(self: LocatedRect) PackedRect {
                return PackedRect{
                    .rect = self.rect,
                    .location_index = self.location_index,
                    .userdata = self.userdata,
                };
            }

            pub inline fn row_index(self: LocatedRect) IDX {
                return location_index_row(self.location_index);
            }
            pub inline fn is_rotated(self: LocatedRect) bool {
                return location_index_is_rotated(self.location_index);
            }
            /// The color channels used by this claim. May be sparse.
            pub inline fn channel_mask(self: LocatedRect) u4 {
                return location_index_channel_mask(self.location_index);
            }
            pub inline fn channel_count(self: LocatedRect) u3 {
                return @popCount(self.channel_mask());
            }
            pub inline fn is_full(self: LocatedRect) bool {
                return self.channel_mask() == FULL_CHANNEL_MASK;
            }
            pub inline fn layer_index(self: LocatedRect) IDX {
                return self.layer_idx;
            }

            pub fn top_left(self: LocatedRect) Vec {
                if (self.is_rotated()) return self.rect.top_right();
                return self.rect.top_left();
            }
            pub fn top_right(self: LocatedRect) Vec {
                if (self.is_rotated()) return self.rect.bot_right();
                return self.rect.top_right();
            }
            pub fn bot_left(self: LocatedRect) Vec {
                if (self.is_rotated()) return self.rect.top_left();
                return self.rect.bot_left();
            }
            pub fn bot_right(self: LocatedRect) Vec {
                if (self.is_rotated()) return self.rect.bot_left();
                return self.rect.bot_right();
            }

            pub fn equals(self: LocatedRect, other: LocatedRect) bool {
                return self.rect.equals(other.rect) and
                    self.location_index == other.location_index and
                    self.layer_idx == other.layer_idx;
            }
        };

        /// One shelf. A row is either a closed constrained shelf or a layer's
        /// active unconstrained shelf. The layout of the common fields matches
        /// RowPacker's `ConstrainedRow`/`UnconstrainedRow`.
        const Row = struct {
            kind: RowKind = .CONSTRAINED,
            layer_idx: IDX = 0,
            /// Current tail x and shelf y, in layer-local coordinates.
            pos: Vec = .{},
            width: SIZE_TYPE = 0,
            used_width: SIZE_TYPE = 0,
            min_height: SIZE_TYPE = 0,
            max_height: SIZE_TYPE = 0,
            /// Only meaningful for `.UNCONSTRAINED`: remaining vertical room
            /// from the current shelf start, including the current shelf.
            true_max_height: SIZE_TYPE = 0,
            num_claimed: IDX = 0,
            /// Pool index of the first hole in this row, or `NULL_HOLE_IDX`.
            next_hole: IDX = NULL_HOLE_IDX,

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
            /// Stable index of this layer's active unconstrained row.
            open_row_idx: IDX = 0,
        };

        pub const Hole = struct {
            rect: Rect = .{ .pos = .{}, .size = .{} },
            /// The color channels that are still free in `rect`.
            channel_mask: u4 = FULL_CHANNEL_MASK,
            /// Pool index of the next hole in this row, or `NULL_HOLE_IDX`.
            next: IDX = NULL_HOLE_IDX,

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
                else => @compileError("RowArrayPacker requires an integer or floating-point coordinate type"),
            };
        }
    };
}

/// Hash-map wrapper around `RowArrayPacker`
///
/// The map stores the compact `PackedRect` (no layer index). Every lookup
/// hydrates the layer index from the stored location index's row bits before
/// returning a `LocatedRect`.
pub fn RowPackedArrayAtlas(
    comptime KEY: type,
    comptime HASH: fn (KEY) u64,
    comptime KEYS_EQUAL: fn (KEY, KEY) bool,
    comptime HASH_MAP_OVERRIDES: HashMapOverrides,
    comptime PACKER_DEF: PackerDefNoLocks,
    comptime LOCK_KIND: LockKind,
    comptime LOCK_ASSERTS: bool,
) type {
    return struct {
        const Self = @This();
        pub const Packer = RowArrayPacker(PACKER_DEF.to_def());
        pub const Rect = Packer.Rect;
        pub const PackedRect = Packer.PackedRect;
        pub const LocatedRect = Packer.LocatedRect;
        pub const Vec = Packer.Vec;
        pub const AABB = Packer.AABB;
        pub const Threshold = Packer.Threshold;
        pub const ThresholdVal = Packer.ThresholdVal;
        pub const Map = HashMap(KEY, PackedRect, HASH, KEYS_EQUAL, HASH_MAP_OVERRIDES);

        const ALLOC_SOURCE = PACKER_DEF.ALLOC_SOURCE;
        const IDX = PACKER_DEF.IDX;
        const Lock = LOCK_KIND.lock_type(LOCK_ASSERTS);
        const LOCK_INIT = LOCK_KIND.init(LOCK_ASSERTS);
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
            LOCK_KIND.lock_for_read(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn unlock_for_read(self: *Self) void {
            LOCK_KIND.unlock_for_read(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn lock_for_write(self: *Self) void {
            LOCK_KIND.lock_for_write(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }
        pub inline fn unlock_for_write(self: *Self) void {
            LOCK_KIND.unlock_for_write(LOCK_ASSERTS, if (LOCK_KIND.has_lock()) &self.lock else {}, self.io);
        }

        pub fn init(
            self: *Self,
            hash_map_cap: IDX,
            row_pack_cap: IDX,
            hole_cap: IDX,
            layer_cap: IDX,
            region: Rect,
            default_height_fit_threshold: ThresholdVal,
            alloc: InitAlloc,
            io: LockIo,
        ) void {
            self.io = io;
            self.lock_for_write();
            defer self.unlock_for_write();
            self.alloc = Alloc.new_from_init_alloc(alloc);
            self.hash_map = Map.init_capacity(@intCast(hash_map_cap), self.alloc.get_alloc(Alloc.init_to_passed_alloc(alloc)));
            self.packer.init(@intCast(row_pack_cap), hole_cap, layer_cap, region, default_height_fit_threshold, alloc, io);
        }

        /// Resets packing state and drops all keys. `PackedRect` values obtained
        /// before this call are no longer valid.
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
            channels: ChannelRequest,
            threshold: Threshold,
            waste: WasteMode,
            rotation: RotationMode,
            grow: GrowMode,
            alloc: PassedAlloc,
            userdata: Packer.Userdata,
        ) ?LocatedRect {
            self.lock_for_write();
            defer self.unlock_for_write();
            const hash_parts = Map.hash_parts(key);
            assert_with_reason(!self.hash_map.contains_hash_parts(key, hash_parts), @src(), "key `{}` is already claimed in the atlas", .{key});
            const possible_rect = self.packer.claim_rect(size, channels, threshold, waste, rotation, grow, alloc, userdata);
            if (possible_rect) |packed_rect| {
                self.hash_map.insert_hash_parts(key, packed_rect, hash_parts, self.alloc.get_alloc(alloc));
                return self.packer.locate_rect(packed_rect);
            }
            return null;
        }

        pub fn lookup_rect_if_exists(self: *Self, key: KEY) ?LocatedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            if (self.hash_map.get_if_exists(key)) |packed_rect| {
                return self.packer.locate_rect(packed_rect);
            }
            return null;
        }

        pub fn lookup_rect(self: *Self, key: KEY) LocatedRect {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.packer.locate_rect(self.hash_map.get(key));
        }

        pub fn release_rect(self: *Self, key: KEY, alloc: PassedAlloc) void {
            self.lock_for_write();
            defer self.unlock_for_write();
            const packed_rect = self.hash_map.remove_key(key);
            self.packer.release_rect(packed_rect, alloc);
        }

        pub fn add_layer(self: *Self, alloc: PassedAlloc) IDX {
            self.lock_for_write();
            defer self.unlock_for_write();
            return self.packer.add_layer(alloc);
        }

        pub fn layer_count(self: *Self) IDX {
            self.lock_for_read();
            defer self.unlock_for_read();
            return self.packer.layer_count();
        }
    };
}
