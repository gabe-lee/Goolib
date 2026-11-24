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

const Root = @import("./_root.zig");
const RectPacker = Root.RectPacker;
const Vec2 = Root.Vec2;
const Rect2 = Root.Rect2;

const PackerU32 = RectPacker.RowArrayPacker(.{
    .SIZE_TYPE = u32,
    .IDX = u16,
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

test "RowArrayPacker -> 4-channel claims use rows across layers" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 100, 100), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const c = packer.claim_rect(VecU.new(20, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;

    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(b.rect, RectU.new_xywh(40, 0, 40, 10));
    try expectRectU(c.rect, RectU.new_xywh(80, 0, 20, 10));

    try std.testing.expect(a.is_full());
    try std.testing.expectEqual(@as(u4, 0b1111), a.channel_mask());
    try std.testing.expectEqual(@as(u3, 4), a.channel_count());
    try std.testing.expectEqual(@as(u16, 0), packer.locate_rect(a).layer_idx);
    try std.testing.expectEqual(@as(u16, 1), packer.layer_count());
}

test "RowArrayPacker -> 1-channel claims stack in the same footprint" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const c = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const d = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;

    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(b.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(c.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(d.rect, RectU.new_xywh(0, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b0001), a.channel_mask());
    try std.testing.expectEqual(@as(u4, 0b0010), b.channel_mask());
    try std.testing.expectEqual(@as(u4, 0b0100), c.channel_mask());
    try std.testing.expectEqual(@as(u4, 0b1000), d.channel_mask());
    try std.testing.expectEqual(@as(u3, 1), d.channel_count());
    try std.testing.expect(!d.is_full());

    // All four channels are occupied at this footprint.
    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);
    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);
}

test "RowArrayPacker -> 2 and 3 channel requests respect the free channel count" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(40, 10), .TWO, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b0011), a.channel_mask());
    try std.testing.expectEqual(@as(u3, 2), a.channel_count());

    // The leftover hole has only two free channels, so a 3-channel claim fails.
    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .THREE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);

    const b = packer.claim_rect(VecU.new(40, 10), .TWO, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(b.rect, RectU.new_xywh(0, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b1100), b.channel_mask());
    try std.testing.expectEqual(@as(u3, 2), b.channel_count());

    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);
}

test "RowArrayPacker -> sparse channel masks are preserved and reusable" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 32, 2, RectU.new_xywh(0, 0, 40, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    _ = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    _ = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;

    // Releasing channel 1 merges with the remaining channel-3 hole, producing
    // a sparse free mask of 0b1010.
    packer.release_rect(b, {});

    const sparse = packer.claim_rect(VecU.new(40, 10), .TWO, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(sparse.rect, RectU.new_xywh(0, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b1010), sparse.channel_mask());
    try std.testing.expectEqual(@as(u3, 2), sparse.channel_count());
    try std.testing.expect(!sparse.is_full());

    // The footprint now has channels 0, 1, 2, and 3 all in use.
    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);
}

test "RowArrayPacker -> releasing all four channels makes a full hole reusable" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(8, 32, 2, RectU.new_xywh(0, 0, 80, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    // Keep one full rect live at x = 0 so row 0 is not reset when the four
    // single-channel rects are released.
    _ = packer.claim_rect(VecU.new(20, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;

    const a = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const c = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    const d = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(20, 0, 40, 10));
    try expectRectU(b.rect, RectU.new_xywh(20, 0, 40, 10));
    try expectRectU(c.rect, RectU.new_xywh(20, 0, 40, 10));
    try expectRectU(d.rect, RectU.new_xywh(20, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b1000), d.channel_mask());

    // The tail is only 20 wide and all four channels at x = 20 are occupied.
    try std.testing.expect(packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);

    packer.release_rect(a, {});
    packer.release_rect(b, {});
    packer.release_rect(c, {});
    packer.release_rect(d, {});

    // Every channel at x = 20 is free again, so a 4-channel claim can use it.
    const full = packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(full.rect, RectU.new_xywh(20, 0, 40, 10));
    try std.testing.expect(full.is_full());
}

test "RowArrayPacker -> 1-channel claims can consume a released full hole" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(8, 32, 2, RectU.new_xywh(0, 0, 80, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    _ = packer.claim_rect(VecU.new(40, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));

    packer.release_rect(a, {});

    const b = packer.claim_rect(VecU.new(40, 10), .ONE, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(b.rect, RectU.new_xywh(0, 0, 40, 10));
    try std.testing.expectEqual(@as(u4, 0b0001), b.channel_mask());
}

test "RowArrayPacker -> grows layers on demand" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 10, 10), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try std.testing.expectEqual(@as(u16, 0), packer.locate_rect(a).layer_idx);
    try std.testing.expect(packer.claim_rect(VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);

    const b = packer.claim_rect(VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .add_layer(), {}, {}).?;
    try std.testing.expectEqual(@as(u16, 1), packer.locate_rect(b).layer_idx);
    try std.testing.expectEqual(@as(u16, 2), packer.layer_count());

    const c = packer.claim_rect(VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .add_layer(), {}, {}).?;
    try std.testing.expectEqual(@as(u16, 2), packer.locate_rect(c).layer_idx);
    try std.testing.expectEqual(@as(u16, 3), packer.layer_count());
}

test "RowArrayPacker -> rotation fits only when allowed" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    // 80x40 does not fit the 40x80 layer unrotated.
    try std.testing.expect(packer.claim_rect(VecU.new(80, 40), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}) == null);

    const a = packer.claim_rect(VecU.new(80, 40), .FOUR, .ignore_threshold(), .least_waste(), .allow_90_degree_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 80));
    try std.testing.expect(a.is_rotated());
    try std.testing.expectEqual(@as(u16, 0), packer.locate_rect(a).layer_idx);
}

test "RowArrayPacker -> forced rotation swaps the footprint" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 16, 2, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(20, 40), .FOUR, .ignore_threshold(), .least_waste(), .always_force_90_degree_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 20));
    try std.testing.expect(a.is_rotated());

    // Rotated corner mapping matches RowPacker.
    try std.testing.expectEqual(@as(u32, 40), a.top_left().x);
    try std.testing.expectEqual(@as(u32, 0), a.top_left().y);
}

test "RowArrayPacker -> rotated single-channel claims keep channel and layer data" {
    const alloc = std.testing.allocator;
    var packer: PackerU32 = undefined;
    packer.init(4, 32, 2, RectU.new_xywh(0, 0, 20, 80), .threshold_val(1.0, 1000), alloc, {});
    defer packer.uninit({});

    const a = packer.claim_rect(VecU.new(80, 20), .ONE, .ignore_threshold(), .least_waste(), .allow_90_degree_rotation(), .do_not_add_layer(), {}, {}).?;
    const b = packer.claim_rect(VecU.new(80, 20), .ONE, .ignore_threshold(), .least_waste(), .allow_90_degree_rotation(), .do_not_add_layer(), {}, {}).?;

    try expectRectU(a.rect, RectU.new_xywh(0, 0, 20, 80));
    try expectRectU(b.rect, RectU.new_xywh(0, 0, 20, 80));
    try std.testing.expect(a.is_rotated());
    try std.testing.expect(b.is_rotated());
    try std.testing.expectEqual(@as(u4, 0b0001), a.channel_mask());
    try std.testing.expectEqual(@as(u4, 0b0010), b.channel_mask());
    try std.testing.expectEqual(@as(u16, 0), packer.locate_rect(a).layer_idx);
}

test "RowPackedArrayAtlas -> rotation bit survives storage and lookup" {
    const alloc = std.testing.allocator;
    var atlas: AtlasU32 = undefined;
    atlas.init(8, 8, 32, 4, RectU.new_xywh(0, 0, 40, 80), .threshold_val(1.0, 1000), alloc, {});
    defer atlas.uninit({});

    const a = atlas.claim_rect(1, VecU.new(80, 40), .FOUR, .ignore_threshold(), .least_waste(), .allow_90_degree_rotation(), .do_not_add_layer(), {}, {}).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 80));
    try std.testing.expect(a.is_rotated());
    try std.testing.expectEqual(@as(u16, 0), a.layer_idx);

    const looked_up = atlas.lookup_rect_if_exists(1).?;
    try expectRectU(looked_up.rect, RectU.new_xywh(0, 0, 40, 80));
    try std.testing.expect(looked_up.is_rotated());
    try std.testing.expectEqual(@as(u16, 0), looked_up.layer_idx);
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

const AtlasU32 = RectPacker.RowPackedArrayAtlas(
    i32,
    hashI32,
    equalI32,
    .{},
    .{ .SIZE_TYPE = u32, .IDX = u16 },
    .NONE,
    false,
);

test "RowPackedArrayAtlas -> lookup hydrates layer from location index" {
    const alloc = std.testing.allocator;
    var atlas: AtlasU32 = undefined;
    atlas.init(8, 8, 32, 4, RectU.new_xywh(0, 0, 10, 10), .threshold_val(1.0, 1000), alloc, {});
    defer atlas.uninit({});

    const a = atlas.claim_rect(1, VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .do_not_add_layer(), {}, {}).?;
    try std.testing.expectEqual(@as(u16, 0), a.layer_idx);

    const b = atlas.claim_rect(2, VecU.new(10, 10), .FOUR, .ignore_threshold(), .least_waste(), .do_not_allow_rotation(), .add_layer(), {}, {}).?;
    try std.testing.expectEqual(@as(u16, 1), b.layer_idx);

    // The map stores the compact rect; the layer index is re-hydrated on lookup.
    const looked_up_b = atlas.lookup_rect_if_exists(2).?;
    try std.testing.expectEqual(@as(u16, 1), looked_up_b.layer_idx);
    try expectRectU(looked_up_b.rect, RectU.new_xywh(0, 0, 10, 10));

    atlas.release_rect(1, {});
    try std.testing.expect(atlas.lookup_rect_if_exists(1) == null);
    try std.testing.expect(atlas.lookup_rect_if_exists(2) != null);

    atlas.clear_entire_atlas({});
    try std.testing.expect(atlas.lookup_rect_if_exists(2) == null);
    try std.testing.expectEqual(@as(u16, 0), atlas.packer.claim_count);
    try std.testing.expectEqual(@as(u16, 1), atlas.layer_count());
}
