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
const testing = std.testing;

const Root = @import("./_root.zig");
const Math = Root.Math;
const Vec2 = Root.Vec2;
const V = Vec2.define_vec2_type(f32);

fn expectVecApprox(actual: V, expected: V, epsilon: f32) !void {
    try testing.expectApproxEqAbs(expected.x, actual.x, epsilon);
    try testing.expectApproxEqAbs(expected.y, actual.y, epsilon);
}

test "Vec2 -> new_splat_any" {
    const v = V.new_splat_any(@as(i32, 3));
    try expectVecApprox(v, V.new(3, 3), 0);
}

test "Vec2 -> angle_between uses both vector lengths" {
    const a = V.new(1, 0);

    // vectors of unequal length pointing in the same direction have angle 0
    try testing.expectApproxEqAbs(@as(f32, 0), V.angle_between(a, V.new(4, 0), f32), 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0), V.angle_between(V.new(3, 0), a, f32), 1e-5);

    // 45 degree angle with vectors of different lengths
    try testing.expectApproxEqAbs(Math.PI / 4.0, V.angle_between(a, V.new(2, 2), f32), 1e-5);

    // opposite directions
    try testing.expectApproxEqAbs(Math.PI, V.angle_between(a, V.new(-5, 0), f32), 1e-5);
}

test "Vec2 -> non_zero means any component is non-zero" {
    try testing.expect(!V.new(0, 0).non_zero());
    try testing.expect(V.new(0, 5).non_zero());
    try testing.expect(V.new(5, 0).non_zero());
    try testing.expect(V.new(-1, 2).non_zero());
}

test "Vec2 -> length_using_squares and normalize_using_squares" {
    const v = V.new(3, 4);
    const squared = V.new(9, 16);
    try testing.expectApproxEqAbs(@as(f32, 5), V.length_using_squares(squared), 1e-6);
    try expectVecApprox(v.normalize_using_squares(squared), V.new(0.6, 0.8), 1e-6);
}

test "Vec2 -> inverse transforms undo forward transforms" {
    const original = V.new(1.5, -2.25);

    const translate = V.TransformStep.translate(V.new(3.0, -2.0));
    const translated = original.apply_transform(translate);
    try expectVecApprox(translated.apply_inverse_transform(translate), original, 1e-6);

    const translate_x = V.TransformStep.translate_x(@as(f32, 4.0));
    try expectVecApprox(original.apply_transform(translate_x).apply_inverse_transform(translate_x), original, 1e-6);

    const translate_y = V.TransformStep.translate_y(@as(f32, -4.0));
    try expectVecApprox(original.apply_transform(translate_y).apply_inverse_transform(translate_y), original, 1e-6);

    const scale = V.TransformStep.scale(V.new(2.0, 4.0));
    const scaled = original.apply_transform(scale);
    try expectVecApprox(scaled.apply_inverse_transform(scale), original, 1e-6);

    const scale_x = V.TransformStep.scale_x(@as(f32, -3.0));
    try expectVecApprox(original.apply_transform(scale_x).apply_inverse_transform(scale_x), original, 1e-6);

    const rotate = V.TransformStep.rotate_degrees(@as(f32, 37.0));
    const rotated = original.apply_transform(rotate);
    try expectVecApprox(rotated.apply_inverse_transform(rotate), original, 1e-5);
}

test "Vec2 -> rotation and perpendicular helpers" {
    const v = V.new(1, 0);
    try expectVecApprox(v.rotate_degrees(90), V.new(0, 1), 1e-6);
    try expectVecApprox(v.rotate_radians(Math.HALF_PI), V.new(0, 1), 1e-6);

    const p = V.new(3, 4);
    try testing.expectApproxEqAbs(@as(f32, 0), p.dot(p.perp_ccw()), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 0), p.dot(p.perp_cw()), 1e-6);
    try expectVecApprox(p.perp_ccw(), V.new(-4, 3), 0);
    try expectVecApprox(p.perp_cw(), V.new(4, -3), 0);
}

test "Vec2 -> miter_different_widths_with_inner_normal returns a result" {
    const corner = V.new(0, 0);
    const result = corner.miter_different_widths_with_inner_normal(V.new(0, -1), @as(f32, 2), V.new(1, 0), @as(f32, 2));
    try testing.expect(!std.math.isNan(result.inner_point.x));
    try testing.expect(!std.math.isNan(result.inner_point.y));
    try testing.expectApproxEqAbs(@as(f32, 1), result.inner_miter_offset_norm.length(), 1e-5);
}

test "Vec2 -> affine matrix transforms match direct transforms" {
    const p = V.new(2.5, -1.25);
    const steps = [_]V.TransformStep{
        V.TransformStep.translate(V.new(3, -2)),
        V.TransformStep.translate_x(@as(f32, 1.5)),
        V.TransformStep.translate_y(@as(f32, -0.5)),
        V.TransformStep.scale(V.new(2, 0.25)),
        V.TransformStep.scale_x(@as(f32, -3)),
        V.TransformStep.scale_y(@as(f32, 4)),
        V.TransformStep.skew_x_ratio(@as(f32, 0.75)),
        V.TransformStep.skew_y_ratio(@as(f32, -0.5)),
        V.TransformStep.rotate_degrees(@as(f32, 37)),
    };
    for (steps) |step| {
        const direct = p.apply_transform(step);
        const via_matrix = p.apply_affine_matrix_transform(step.to_affine_matrix());
        try expectVecApprox(via_matrix, direct, 1e-5);

        const direct_inverse = p.apply_inverse_transform(step);
        const via_inverse_matrix = p.apply_affine_matrix_transform(step.to_inverse_affine_matrix());
        try expectVecApprox(via_inverse_matrix, direct_inverse, 1e-5);
    }
}

test "Vec2 -> lerp and interpolation" {
    try expectVecApprox(V.lerp(V.new(0, 0), V.new(10, 20), @as(f32, 0.25)), V.new(2.5, 5), 1e-6);
    try expectVecApprox(V.linear_interp(V.new(0, 0), V.new(10, 20), @as(f32, 1.0)), V.new(10, 20), 0);
    try expectVecApprox(V.quadratic_interp(V.new(0, 0), V.new(1, 2), V.new(2, 0), @as(f32, 0.5)), V.new(1, 1), 1e-6);
}
