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

const PackerF32 = RectPacker.RowPacker(f32, u16, .CLAIM_ONLY);
const PackerU32 = RectPacker.RowPacker(u32, u8, .CLAIM_ONLY);
const PackerU8 = RectPacker.RowPacker(u8, u8, .CLAIM_ONLY);
const PackerF32Release = RectPacker.RowPacker(f32, u16, .CLAIM_AND_RELEASE);
const PackerU32Release = RectPacker.RowPacker(u32, u8, .CLAIM_AND_RELEASE);

const VecF = Vec2.define_vec2_type(f32);
const RectF = Rect2.define_rect2_type(f32);
const VecU = Vec2.define_vec2_type(u32);
const RectU = Rect2.define_rect2_type(u32);
const VecU8 = Vec2.define_vec2_type(u8);
const RectU8 = Rect2.define_rect2_type(u8);

fn expectRectF(actual: RectF, expected: RectF) !void {
    try std.testing.expectEqual(expected.pos.x, actual.pos.x);
    try std.testing.expectEqual(expected.pos.y, actual.pos.y);
    try std.testing.expectEqual(expected.size.x, actual.size.x);
    try std.testing.expectEqual(expected.size.y, actual.size.y);
}

fn expectRectU(actual: RectU, expected: RectU) !void {
    try std.testing.expectEqual(expected.pos.x, actual.pos.x);
    try std.testing.expectEqual(expected.pos.y, actual.pos.y);
    try std.testing.expectEqual(expected.size.x, actual.size.x);
    try std.testing.expectEqual(expected.size.y, actual.size.y);
}

fn expectVecF(actual: VecF, expected: VecF) !void {
    try std.testing.expectEqual(expected.x, actual.x);
    try std.testing.expectEqual(expected.y, actual.y);
}

fn strictlyOverlaps(a: RectF, b: RectF) bool {
    return a.pos.x < b.pos.x + b.size.x and b.pos.x < a.pos.x + a.size.x and
        a.pos.y < b.pos.y + b.size.y and b.pos.y < a.pos.y + a.size.y;
}

test "RowPacker -> shelf layout" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const c = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const d = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const e = packer.claim_rect(VecF.new(60, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;

    try expectRectF(a.rect, RectF.new_xywh(0, 0, 40, 10));
    try expectRectF(b.rect, RectF.new_xywh(40, 0, 40, 10));
    try expectRectF(c.rect, RectF.new_xywh(80, 0, 20, 10));
    try expectRectF(d.rect, RectF.new_xywh(0, 10, 40, 10));
    try expectRectF(e.rect, RectF.new_xywh(40, 10, 60, 10));

    try std.testing.expectEqual(@as(u16, 5), packer.claim_count);
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());
    try std.testing.expectEqual(@as(f32, 0), packer.total_wasted_area);
}

test "RowPacker -> total_wasted_area accounts for exposed area" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(2, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    _ = packer.claim_rect(VecF.new(50, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(50, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(50, 0, 50, 20));
    // The first 50x10 rect is exposed by 10 units of height.
    try std.testing.expectEqual(@as(f32, 500), packer.total_wasted_area);

    const c = packer.claim_rect(VecF.new(30, 30), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(0, 20, 30, 30));
    try std.testing.expectEqual(@as(f32, 500), packer.total_wasted_area);
}

test "RowPacker -> forced rotation uses existing rows for square rects" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(4, RectF.new_xywh(0, 0, 50, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 20), .ignore_threshold(), .ignore_waste(), .always_force_90_degree_rotation()).?;
    try std.testing.expect(a.is_rotated);
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 20, 40));
    try expectVecF(a.top_left(), VecF.new(20, 0));
    try expectVecF(a.top_right(), VecF.new(20, 40));
    try expectVecF(a.bot_left(), VecF.new(0, 0));
    try expectVecF(a.bot_right(), VecF.new(0, 40));

    // A square under forced rotation must be able to use the open row instead of
    // always falling through to the "new row" path.
    const b = packer.claim_rect(VecF.new(10, 10), .ignore_threshold(), .ignore_waste(), .always_force_90_degree_rotation()).?;
    try std.testing.expect(b.is_rotated);
    try expectRectF(b.rect, RectF.new_xywh(20, 0, 10, 10));
    try std.testing.expectEqual(@as(u16, 0), packer.constrained_rows.get_len());
}

test "RowPacker -> rotated sizes cannot overflow the region on a new row" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(4, RectF.new_xywh(0, 0, 50, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(50, 60), .ignore_threshold(), .ignore_waste(), .allow_90_degree_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 50, 60));

    // Only the rotated orientation (40x80) passes the broad bounds check, but it
    // does not fit the remaining height. The unrotated orientation (80x40) is
    // wider than the region, so this must not fit anywhere.
    try std.testing.expect(packer.claim_rect(VecF.new(80, 40), .ignore_threshold(), .ignore_waste(), .allow_90_degree_rotation()) == null);
    try std.testing.expectEqual(@as(u16, 1), packer.claim_count);

    const c = packer.claim_rect(VecF.new(40, 40), .ignore_threshold(), .ignore_waste(), .allow_90_degree_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(0, 60, 40, 40));
}

test "RowPacker -> threshold starts a new row, constrained rows are reused" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(8, RectF.new_xywh(0, 0, 100, 100), 1, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 20, 10));

    // Much taller than the open row; because no row satisfies the default
    // threshold, a new row is opened and the first one is closed as a
    // constrained row.
    const b = packer.claim_rect(VecF.new(20, 30), .default_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(0, 10, 20, 30));
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());

    // Fits the 10-tall constrained row, and is within the default threshold,
    // while the open 30-tall row is outside of it.
    const c = packer.claim_rect(VecF.new(30, 10), .default_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(20, 0, 30, 10));

    const d = packer.claim_rect(VecF.new(20, 10), .default_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(50, 0, 20, 10));

    try std.testing.expectEqual(@as(f32, 0), packer.total_wasted_area);
}

test "RowPacker -> final-pass heuristic opens a new row when ignoring thresholds" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(4, RectF.new_xywh(0, 0, 100, 100), 1, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 20, 10));

    // The rect fits the open row, but its height is far outside of the row's
    // height range, so the final-pass heuristic starts a new row instead.
    const b = packer.claim_rect(VecF.new(20, 30), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(0, 10, 20, 30));
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());
    try std.testing.expectEqual(@as(f32, 0), packer.total_wasted_area);
}

test "RowPacker -> zero initial capacity grows on demand" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(0, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 40, 10));
    const b = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(40, 0, 40, 10));
    const c = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(0, 10, 40, 10));
    const d = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(40, 10, 40, 10));
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());
}

test "RowPacker -> unsigned integer coordinates" {
    const alloc = std.testing.allocator;
    var packer = PackerU32.init(4, RectU.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    _ = packer.claim_rect(VecU.new(50, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecU.new(50, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectU(b.rect, RectU.new_xywh(50, 0, 50, 20));
    try std.testing.expectEqual(@as(u32, 500), packer.total_wasted_area);

    const c = packer.claim_rect(VecU.new(30, 30), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectU(c.rect, RectU.new_xywh(0, 20, 30, 30));
    try std.testing.expectEqual(@as(u32, 500), packer.total_wasted_area);
}

test "RowPacker -> respects the region position" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(2, RectF.new_xywh(10, 20, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(60, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(10, 20, 60, 10));

    const b = packer.claim_rect(VecF.new(60, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(10, 30, 60, 10));
}

test "RowPacker -> claim_aabb rotates with the rect" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(2, RectF.new_xywh(0, 0, 50, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_aabb(VecF.new(80, 40), .ignore_threshold(), .ignore_waste(), .allow_90_degree_rotation()).?;
    try std.testing.expect(a.is_rotated);
    try std.testing.expectEqual(@as(f32, 0), a.aabb.x_min);
    try std.testing.expectEqual(@as(f32, 0), a.aabb.y_min);
    try std.testing.expectEqual(@as(f32, 40), a.aabb.x_max);
    try std.testing.expectEqual(@as(f32, 80), a.aabb.y_max);
}

test "RowPacker -> reset clears all state" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(2, RectF.new_xywh(10, 20, 100, 100), 1000, alloc);
    defer packer.free();

    _ = packer.claim_rect(VecF.new(60, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    _ = packer.claim_rect(VecF.new(60, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try std.testing.expectEqual(@as(u16, 2), packer.claim_count);
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());

    packer.reset();
    try std.testing.expectEqual(@as(u16, 0), packer.claim_count);
    try std.testing.expectEqual(@as(u16, 0), packer.constrained_rows.get_len());
    try std.testing.expectEqual(@as(f32, 0), packer.total_wasted_area);

    const a = packer.claim_rect(VecF.new(10, 10), .ignore_threshold(), .ignore_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(10, 20, 10, 10));
}

test "RowPacker -> least waste picks between constrained rows and the open row" {
    const alloc = std.testing.allocator;
    var packer = PackerF32.init(8, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    // Build two constrained rows with different heights plus an open row.
    _ = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(20, 30), .custom_threshold(1), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(b.rect, RectF.new_xywh(0, 10, 20, 30));
    const d = packer.claim_rect(VecF.new(20, 20), .custom_threshold(1), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(0, 40, 20, 20));
    try std.testing.expectEqual(@as(u16, 2), packer.constrained_rows.get_len());

    // Zero waste in the 10-tall constrained row beats the 30-tall constrained
    // row (400) and the 20-tall open row (200).
    const e = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(e.rect, RectF.new_xywh(20, 0, 20, 10));

    // The 10-tall row is now too narrow. The open row has less waste (800)
    // than the 30-tall constrained row (1600).
    const f = packer.claim_rect(VecF.new(80, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(f.rect, RectF.new_xywh(20, 40, 80, 10));
    try std.testing.expectEqual(@as(f32, 800), packer.total_wasted_area);
}

test "RowPacker -> final-pass threshold doubling saturates for small ints" {
    const alloc = std.testing.allocator;
    // A default threshold above half of `u8`'s range used to overflow when the
    // final-pass heuristic doubled it.
    var packer = PackerU8.init(2, RectU8.new_xywh(0, 0, 100, 100), 200, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecU8.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try std.testing.expectEqual(@as(u8, 0), a.rect.pos.x);
    try std.testing.expectEqual(@as(u8, 0), a.rect.pos.y);

    const b = packer.claim_rect(VecU8.new(20, 12), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try std.testing.expectEqual(@as(u8, 20), b.rect.pos.x);
    try std.testing.expectEqual(@as(u8, 0), b.rect.pos.y);
    try std.testing.expectEqual(@as(u8, 40), packer.total_wasted_area);
    try std.testing.expectEqual(@as(u8, 0), packer.constrained_rows.get_len());
}

test "RowPacker -> randomized invariants across modes" {
    const alloc = std.testing.allocator;
    const region = RectF.new_xywh(-10, 25, 200, 150);
    var prng = std.Random.DefaultPrng.init(0x5EED);
    const random = prng.random();

    const rotations = [_]RectPacker.RowPackerModule.RotationMode{
        .do_not_allow_rotation(),
        .allow_90_degree_rotation(),
        .always_force_90_degree_rotation(),
    };
    const wastes = [_]RectPacker.RowPackerModule.WasteMode{
        .ignore_waste(),
        .least_waste(),
    };
    const thresholds = [_]PackerF32.Threshold{
        .ignore_threshold(),
        .default_threshold(),
        .custom_threshold(4),
    };

    for (rotations) |rotation| {
        for (wastes) |waste| {
            for (thresholds) |threshold| {
                var packer = PackerF32.init(0, region, 6, alloc);
                defer packer.free();

                var claimed: [40]RectF = undefined;
                var count: usize = 0;
                for (0..claimed.len) |_| {
                    const size = VecF.new(
                        @floatFromInt(random.intRangeAtMost(u32, 1, 60)),
                        @floatFromInt(random.intRangeAtMost(u32, 1, 40)),
                    );
                    const result = packer.claim_rect(size, threshold, waste, rotation) orelse continue;
                    const rect = result.rect;
                    try std.testing.expect(rect.pos.x >= region.pos.x);
                    try std.testing.expect(rect.pos.y >= region.pos.y);
                    try std.testing.expect(rect.pos.x + rect.size.x <= region.pos.x + region.size.x);
                    try std.testing.expect(rect.pos.y + rect.size.y <= region.pos.y + region.size.y);
                    for (claimed[0..count]) |other| {
                        try std.testing.expect(!strictlyOverlaps(rect, other));
                    }
                    claimed[count] = rect;
                    count += 1;
                }
                try std.testing.expect(count > 0);
                try std.testing.expectEqual(count, packer.claim_count);
            }
        }
    }
}

test "RowPacker -> claimed rects stay in bounds and do not overlap" {
    const alloc = std.testing.allocator;
    const region = RectF.new_xywh(5, 7, 100, 100);
    var packer = PackerF32.init(16, region, 1000, alloc);
    defer packer.free();

    const sizes = [_]VecF{
        VecF.new(30, 10),
        VecF.new(20, 12),
        VecF.new(50, 10),
        VecF.new(15, 11),
        VecF.new(40, 10),
        VecF.new(10, 12),
        VecF.new(60, 10),
        VecF.new(25, 11),
        VecF.new(33, 10),
        VecF.new(18, 12),
        VecF.new(45, 10),
        VecF.new(12, 11),
    };

    var claimed: [sizes.len]RectF = undefined;
    var count: usize = 0;
    for (sizes) |size| {
        const result = packer.claim_rect(size, .default_threshold(), .least_waste(), .do_not_allow_rotation()) orelse return error.DidNotFit;
        const rect = result.rect;
        try std.testing.expect(rect.pos.x >= region.pos.x);
        try std.testing.expect(rect.pos.y >= region.pos.y);
        try std.testing.expect(rect.pos.x + rect.size.x <= region.pos.x + region.size.x);
        try std.testing.expect(rect.pos.y + rect.size.y <= region.pos.y + region.size.y);
        for (claimed[0..count]) |other| {
            try std.testing.expect(!strictlyOverlaps(rect, other));
        }
        claimed[count] = rect;
        count += 1;
    }
    try std.testing.expectEqual(sizes.len, count);
}

test "RowPacker -> released rect is reused from its hole in the open row" {
    const alloc = std.testing.allocator;
    var packer = PackerF32Release.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const c = packer.claim_rect(VecF.new(20, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 40, 10));
    try expectRectF(b.rect, RectF.new_xywh(40, 0, 40, 10));
    try expectRectF(c.rect, RectF.new_xywh(80, 0, 20, 10));

    packer.release_rect(b);
    try std.testing.expectEqual(@as(u16, 2), packer.claim_count);

    // The row tail is full, so the only fitting space is the released hole.
    const d = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(40, 0, 40, 10));
    try std.testing.expectEqual(@as(u16, 3), packer.claim_count);
}

test "RowPacker -> claiming a smaller rect splits a hole into reusable remainders" {
    const alloc = std.testing.allocator;
    var packer = PackerF32Release.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(40, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const c = packer.claim_rect(VecF.new(20, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 40, 20));
    try expectRectF(b.rect, RectF.new_xywh(40, 0, 40, 20));
    try expectRectF(c.rect, RectF.new_xywh(80, 0, 20, 20));

    packer.release_rect(b);

    const d = packer.claim_rect(VecF.new(10, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(40, 0, 10, 10));

    // The 40x20 hole was split into a 30x20 right strip and a 10x10 bottom strip.
    const e = packer.claim_rect(VecF.new(30, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(e.rect, RectF.new_xywh(50, 0, 30, 20));

    const f = packer.claim_rect(VecF.new(10, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(f.rect, RectF.new_xywh(40, 10, 10, 10));

    // All space in the first shelf is occupied again; the next claim starts a new row.
    const g = packer.claim_rect(VecF.new(1, 1), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(g.rect, RectF.new_xywh(0, 20, 1, 1));
}

test "RowPacker -> holes survive when the open row becomes a constrained row" {
    const alloc = std.testing.allocator;
    var packer = PackerF32Release.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(a.rect, RectF.new_xywh(0, 0, 40, 10));
    try expectRectF(b.rect, RectF.new_xywh(40, 0, 40, 10));
    packer.release_rect(b);

    // Force the open row to close; its hole must move to the constrained row.
    const c = packer.claim_rect(VecF.new(100, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(0, 10, 100, 20));
    try std.testing.expectEqual(@as(u16, 1), c.row_idx);
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());

    const d = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(40, 0, 40, 10));
}

test "RowPacker -> releasing every rect in a constrained row makes the shelf reusable" {
    const alloc = std.testing.allocator;
    var packer = PackerF32Release.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const c = packer.claim_rect(VecF.new(40, 20), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(c.rect, RectF.new_xywh(0, 10, 40, 20));
    try std.testing.expectEqual(@as(u16, 1), packer.constrained_rows.get_len());

    packer.release_rect(a);
    packer.release_rect(b);
    try std.testing.expectEqual(@as(u16, 1), packer.claim_count);

    const d = packer.claim_rect(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectF(d.rect, RectF.new_xywh(0, 0, 40, 10));
}

test "RowPacker -> release_aabb fills its hole" {
    const alloc = std.testing.allocator;
    var packer = PackerF32Release.init(4, RectF.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_aabb(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_aabb(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try std.testing.expectEqual(@as(f32, 0), a.aabb.x_min);
    try std.testing.expectEqual(@as(f32, 40), b.aabb.x_min);

    packer.release_aabb(b);
    const c = packer.claim_aabb(VecF.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try std.testing.expectEqual(@as(f32, 40), c.aabb.x_min);
    try std.testing.expectEqual(@as(f32, 0), c.aabb.y_min);
    try std.testing.expectEqual(@as(f32, 80), c.aabb.x_max);
    try std.testing.expectEqual(@as(f32, 10), c.aabb.y_max);
}

test "RowPacker -> release works with unsigned coordinates" {
    const alloc = std.testing.allocator;
    var packer = PackerU32Release.init(2, RectU.new_xywh(0, 0, 100, 100), 1000, alloc);
    defer packer.free();

    const a = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    const b = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectU(a.rect, RectU.new_xywh(0, 0, 40, 10));
    try expectRectU(b.rect, RectU.new_xywh(40, 0, 40, 10));

    packer.release_rect(b);
    const c = packer.claim_rect(VecU.new(40, 10), .ignore_threshold(), .least_waste(), .do_not_allow_rotation()).?;
    try expectRectU(c.rect, RectU.new_xywh(40, 0, 40, 10));
}

test "RowPacker -> randomized release and reclaim invariants" {
    const alloc = std.testing.allocator;
    const region = RectF.new_xywh(-10, 25, 200, 150);
    var prng = std.Random.DefaultPrng.init(0xC0FFEE);
    const random = prng.random();

    const rotations = [_]RectPacker.RowPackerModule.RotationMode{
        .do_not_allow_rotation(),
        .allow_90_degree_rotation(),
        .always_force_90_degree_rotation(),
    };
    const wastes = [_]RectPacker.RowPackerModule.WasteMode{
        .ignore_waste(),
        .least_waste(),
    };
    const thresholds = [_]PackerF32Release.Threshold{
        .ignore_threshold(),
        .default_threshold(),
        .custom_threshold(4),
    };

    for (rotations) |rotation| {
        for (wastes) |waste| {
            for (thresholds) |threshold| {
                var packer = PackerF32Release.init(0, region, 6, alloc);
                defer packer.free();

                var live: [64]PackerF32Release.RectResult = undefined;
                var live_count: usize = 0;

                for (0..300) |_| {
                    const should_release = live_count > 0 and random.intRangeAtMost(u8, 0, 1) == 0;
                    if (should_release) {
                        const release_idx = random.intRangeLessThan(usize, 0, live_count);
                        packer.release_rect(live[release_idx]);
                        live[release_idx] = live[live_count - 1];
                        live_count -= 1;
                        try std.testing.expectEqual(live_count, packer.claim_count);
                        continue;
                    }

                    const size = VecF.new(
                        @floatFromInt(random.intRangeAtMost(u32, 1, 60)),
                        @floatFromInt(random.intRangeAtMost(u32, 1, 40)),
                    );
                    const result = packer.claim_rect(size, threshold, waste, rotation) orelse continue;
                    const rect = result.rect;
                    try std.testing.expect(rect.pos.x >= region.pos.x);
                    try std.testing.expect(rect.pos.y >= region.pos.y);
                    try std.testing.expect(rect.pos.x + rect.size.x <= region.pos.x + region.size.x);
                    try std.testing.expect(rect.pos.y + rect.size.y <= region.pos.y + region.size.y);
                    for (live[0..live_count]) |other| {
                        try std.testing.expect(!strictlyOverlaps(rect, other.rect));
                    }

                    if (live_count == live.len) {
                        packer.release_rect(result);
                    } else {
                        live[live_count] = result;
                        live_count += 1;
                    }
                    try std.testing.expectEqual(live_count, packer.claim_count);
                }

                while (live_count > 0) {
                    live_count -= 1;
                    packer.release_rect(live[live_count]);
                }
                try std.testing.expectEqual(@as(u16, 0), packer.claim_count);
            }
        }
    }
}
