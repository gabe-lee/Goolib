//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
//
// This software is provided 'as-is', without any implied
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
const RectPacker = Root.RectPacker;
const Vec2 = Root.Vec2;
const Rect2 = Root.Rect2;

const PackerU32 = RectPacker.LayeredRowPacker(.{
    .SIZE_TYPE = u32,
    .RECT_IDX = u16,
    .RELEASE_MODE = .CLAIM_AND_RELEASE,
    .ALLOC_SOURCE = .CACHED_ALLOCATOR_INTERFACE,
});

const PackerU32RwLock = RectPacker.LayeredRowPacker(.{
    .SIZE_TYPE = u32,
    .RECT_IDX = u16,
    .RELEASE_MODE = .CLAIM_AND_RELEASE,
    .ALLOC_SOURCE = .CACHED_ALLOCATOR_INTERFACE,
    .LOCK_KIND = .RW_SPIN_LOCK,
});

/// Exercises index types where the hole index is wider than the row index.
const PackerMixedIdx = RectPacker.LayeredRowPacker(.{
    .SIZE_TYPE = u32,
    .RECT_IDX = u32,
    .ROW_IDX = u16,
    .LAYER_IDX = u16,
    .RELEASE_MODE = .CLAIM_AND_RELEASE,
    .ALLOC_SOURCE = .CACHED_ALLOCATOR_INTERFACE,
});

const VecU = Vec2.define_vec2_type(u32);
const RectU = Rect2.define_rect2_type(u32);

fn expectRectU(actual: RectU, expected: RectU) !void {
    try std.testing.expectEqual(expected.pos.x, actual.pos.x);
    try std.testing.expectEqual(expected.pos.y, actual.pos.y);
    try std.testing.expectEqual(expected.size.x, actual.size.x);
    try std.testing.expectEqual(expected.size.y, actual.size.y);
}

fn strictlyOverlapsU(a: RectU, b: RectU) bool {
    return a.pos.x < b.pos.x + b.size.x and b.pos.x < a.pos.x + a.size.x and
        a.pos.y < b.pos.y + b.size.y and b.pos.y < a.pos.y + a.size.y;
}

test "LayeredRowPacker -> claims use rows across layers" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 100, 100), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const c = packer.claim_rect(VecU.new(20, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;

    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(b.rect, RectU.new_xywh(40, 0, 40, 10));
    try expectRectU(c.rect, RectU.new_xywh(80, 0, 20, 10));

    try std.testing.expectEqual(@as(u16, 0), packer.hydrate_rect(a).layer_idx);
    try std.testing.expectEqual(@as(u16, 1), packer.layer_count());
}

test "LayeredRowPacker -> releasing a rect reuses its hole" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(8, 32, 2, RectU.new_xywh(0, 0, 80, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(20, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const c = packer.claim_rect(VecU.new(20, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 20, 10));
    try expectRectU(b.rect, RectU.new_xywh(20, 0, 40, 10));
    try expectRectU(c.rect, RectU.new_xywh(60, 0, 20, 10));

    packer.release_rect(b, {});

    const d = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(d.rect, RectU.new_xywh(20, 0, 40, 10));
}

test "LayeredRowPacker -> grows layers on demand" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 10, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try std.testing.expectEqual(@as(u16, 0), packer.hydrate_rect(a).layer_idx);
    try std.testing.expect(packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}) == null);

    const b = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .ADD_LAYER_IF_NO_SPACE, {}, {}).?;
    try std.testing.expectEqual(@as(u16, 1), packer.hydrate_rect(b).layer_idx);
    try std.testing.expectEqual(@as(u16, 2), packer.layer_count());

    const c = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .ADD_LAYER_IF_NO_SPACE, {}, {}).?;
    try std.testing.expectEqual(@as(u16, 2), packer.hydrate_rect(c).layer_idx);
    try std.testing.expectEqual(@as(u16, 3), packer.layer_count());
}

test "LayeredRowPacker -> rw spin lock variant claims and releases" {
    const alloc = std.testing.allocator;
    var packer: PackerU32RwLock = undefined;
    packer.init(8, 16, 2, RectU.new_xywh(0, 0, 80, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(20, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 20, 10));
    try expectRectU(b.rect, RectU.new_xywh(20, 0, 40, 10));

    packer.release_rect(b, {});
    const c = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(c.rect, RectU.new_xywh(20, 0, 40, 10));
    try std.testing.expectEqual(@as(u16, 2), packer.claim_count);
}

test "LayeredRowPacker -> mixed index widths support release and hydration" {
    const alloc = std.testing.allocator;
    var packer: PackerMixedIdx = undefined;
    packer.init(8, 16, 2, RectU.new_xywh(0, 0, 80, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(20, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 20, 10));
    try expectRectU(b.rect, RectU.new_xywh(20, 0, 40, 10));

    packer.release_rect(b, {});
    const c = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(c.rect, RectU.new_xywh(20, 0, 40, 10));
    try std.testing.expectEqual(@as(u16, 0), packer.hydrate_rect(c).layer_idx);
}

test "LayeredRowPacker -> hydration carries layer and rotation" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const result = packer.claim_rect_and_hydrated(VecU.new(80, 40), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const packed_rect = result[0];
    const hydrated = result[1];

    try std.testing.expectEqual(@as(u16, 0), PackerU32.location_index_row(packed_rect.location_info));
    try std.testing.expect(PackerU32.location_index_is_rotated(packed_rect.location_info));
    try std.testing.expectEqual(@as(u16, 0), hydrated.layer_idx);
    try std.testing.expect(hydrated.is_rotated);
    try expectRectU(hydrated.rect, packed_rect.rect);
    try std.testing.expect(hydrated.equals(packed_rect.hydrate(&packer)));
}

test "LayeredRowPacker -> reset restores a single empty layer" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 10, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    _ = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    _ = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .ADD_LAYER_IF_NO_SPACE, {}, {}).?;
    try std.testing.expectEqual(@as(u16, 2), packer.layer_count());

    packer.reset({});
    try std.testing.expectEqual(@as(u16, 1), packer.layer_count());
    try std.testing.expectEqual(@as(u16, 1), packer.row_count());
    try std.testing.expectEqual(@as(u16, 0), packer.claim_count);

    const a = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 10, 10));
    try std.testing.expectEqual(@as(u16, 0), packer.hydrate_rect(a).layer_idx);
}

test "LayeredRowPacker -> ignoring thresholds still prefers a lower-waste hole" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 100, 100), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    const b = packer.claim_rect(VecU.new(20, 20), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 10, 10));
    try expectRectU(b.rect, RectU.new_xywh(10, 0, 20, 20));
    packer.release_rect(a, {});

    // The 10x10 hole has zero waste, while the open row's 20-tall tail would
    // waste 100 units. No threshold is set, so the hole must still win.
    const c = packer.claim_rect(VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(c.rect, RectU.new_xywh(0, 0, 10, 10));
    try std.testing.expectEqual(@as(u32, 100), packer.total_wasted_area);
}

test "LayeredRowPacker -> randomized release and reclaim invariants" {
    const alloc = std.testing.allocator;
    const region = RectU.new_xywh(10, 20, 100, 100);
    var prng = std.Random.DefaultPrng.init(0x1A7E);
    const random = prng.random();

    const rotations = [_]RectPacker.LayeredRowPackerModule.RotationMode{
        .DO_NOT_ALLOW_ROTATION,
        .ALLOW_90_DEGREE_ROTATION,
        .ALWAYS_FORCE_90_DEGREE_ROTATION,
    };
    const wastes = [_]RectPacker.LayeredRowPackerModule.WasteMode{
        .IGNORE_WASTE,
        .LEAST_WASTE,
    };
    const thresholds = [_]PackerU32.Threshold{
        .ignore_threshold(),
        .default_threshold(),
        .custom_threshold(1.0, 4),
    };

    for (rotations) |rotation| {
        for (wastes) |waste| {
            for (thresholds) |threshold| {
                var packer: PackerU32 = undefined;
                packer.init(0, 0, 3, region, .threshold_val(1.0, 6), alloc, {});
                defer packer.uninit({});

                var live: [64]PackerU32.PackedRect = undefined;
                var live_count: usize = 0;

                for (0..400) |_| {
                    if (live_count > 0 and random.boolean()) {
                        const release_idx = random.intRangeLessThan(usize, 0, live_count);
                        packer.release_rect(live[release_idx], {});
                        live[release_idx] = live[live_count - 1];
                        live_count -= 1;
                        try std.testing.expectEqual(live_count, packer.claim_count);
                        continue;
                    }

                    const size = VecU.new(
                        random.intRangeAtMost(u32, 1, 60),
                        random.intRangeAtMost(u32, 1, 40),
                    );
                    const claimed = packer.claim_rect(size, threshold, waste, rotation, .ADD_LAYER_IF_NO_SPACE, {}, {}) orelse continue;
                    const hydrated = claimed.hydrate(&packer);

                    try std.testing.expect(hydrated.layer_idx < packer.layer_count());
                    try expectRectU(hydrated.rect, claimed.rect);
                    try std.testing.expectEqual(claimed.is_rotated(), hydrated.is_rotated);
                    try std.testing.expect(hydrated.rect.pos.x >= region.pos.x);
                    try std.testing.expect(hydrated.rect.pos.y >= region.pos.y);
                    try std.testing.expect(hydrated.rect.pos.x + hydrated.rect.size.x <= region.pos.x + region.size.x);
                    try std.testing.expect(hydrated.rect.pos.y + hydrated.rect.size.y <= region.pos.y + region.size.y);
                    for (live[0..live_count]) |other| {
                        const other_hydrated = other.hydrate(&packer);
                        if (other_hydrated.layer_idx != hydrated.layer_idx) continue;
                        try std.testing.expect(!strictlyOverlapsU(hydrated.rect, other_hydrated.rect));
                    }

                    if (live_count == live.len) {
                        packer.release_rect(claimed, {});
                    } else {
                        live[live_count] = claimed;
                        live_count += 1;
                    }
                    try std.testing.expectEqual(live_count, packer.claim_count);
                }

                while (live_count > 0) {
                    live_count -= 1;
                    packer.release_rect(live[live_count], {});
                }
                try std.testing.expectEqual(@as(u16, 0), packer.claim_count);
                try std.testing.expectEqual(@as(u16, 1), packer.layer_count());
            }
        }
    }
}

test "LayeredRowPacker -> rotation fits only when allowed" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    // 80x40 does not fit the 40x80 layer unrotated.
    try std.testing.expect(packer.claim_rect(VecU.new(80, 40), .ignore_threshold(), .LEAST_WASTE, .DO_NOT_ALLOW_ROTATION, .NEVER_ADD_LAYERS, {}, {}) == null);

    const a = packer.claim_rect(VecU.new(80, 40), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 80));
    try std.testing.expect(a.is_rotated());
    try std.testing.expectEqual(@as(u16, 0), packer.hydrate_rect(a).layer_idx);
}

test "LayeredRowPacker -> forced rotation swaps the footprint" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(20, 40), .ignore_threshold(), .LEAST_WASTE, .ALWAYS_FORCE_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 20));
    try std.testing.expect(a.is_rotated());

    // Rotated corner mapping matches RowPacker.
    try std.testing.expectEqual(@as(u32, 40), a.top_left().x);
    try std.testing.expectEqual(@as(u32, 0), a.top_left().y);
}

const hashI32 = struct {
    fn hash(key: i32) u64 {
        var h: u64 = @bitCast(@as(i64, key));
        h ^= h >> 33;
        h *%= 0xff51afd7ed558ccd;
        h ^= h >> 33;
        h *%= 0xc4ceb9fe1a85ec53;
        h ^= h >> 33;
        return h;
    }
}.hash;

fn equalI32(a: i32, b: i32) bool {
    return a == b;
}

const AtlasU32 = RectPacker.LayeredRowPackedAtlas(
    i32,
    hashI32,
    equalI32,
    .{},
    .{ .SIZE_TYPE = u32, .RECT_IDX = u16 },
);

test "LayeredRowPackedAtlas -> lookup hydrates layer and rotation" {
    const alloc = std.testing.allocator;
    var atlas: AtlasU32 = undefined;
    atlas.init(8, 8, 32, 4, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer atlas.uninit({});

    const a = atlas.claim_rect(1, VecU.new(80, 40), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .NEVER_ADD_LAYERS, {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 80));
    try std.testing.expect(a.is_rotated);
    try std.testing.expectEqual(@as(u16, 0), a.layer_idx);

    const b = atlas.claim_rect(2, VecU.new(10, 10), .ignore_threshold(), .LEAST_WASTE, .ALLOW_90_DEGREE_ROTATION, .ADD_LAYER_IF_NO_SPACE, {}, {}).?;
    try std.testing.expectEqual(@as(u16, 1), b.layer_idx);

    const looked_up_b = atlas.lookup_rect_if_exists(2).?;
    try std.testing.expectEqual(@as(u16, 1), looked_up_b.layer_idx);
    try expectRectU(looked_up_b.rect, RectU.new_xywh(0, 0, 10, 10));

    const looked_up_a = atlas.lookup_rect_if_exists(1).?;
    try std.testing.expect(looked_up_a.is_rotated);

    atlas.release_rect(1, {});
    try std.testing.expect(atlas.lookup_rect_if_exists(1) == null);
    try std.testing.expect(atlas.lookup_rect_if_exists(2) != null);

    atlas.clear_entire_atlas({});
    try std.testing.expect(atlas.lookup_rect_if_exists(2) == null);
    try std.testing.expectEqual(@as(u16, 0), atlas.packer.claim_count);
    try std.testing.expectEqual(@as(u16, 1), atlas.layer_count());
}
