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
const Vec3 = Root.Vec3;
const V = Vec3.define_vec3_type(f32);

fn expectVecApprox(actual: V, expected: V, epsilon: f32) !void {
    try testing.expectApproxEqAbs(expected.x, actual.x, epsilon);
    try testing.expectApproxEqAbs(expected.y, actual.y, epsilon);
    try testing.expectApproxEqAbs(expected.z, actual.z, epsilon);
}

test "Vec3 -> subtract_scale subtracts" {
    const v = V.new(10, 20, 30);
    const sub = V.new(1, 2, 3);
    try expectVecApprox(v.subtract_scale(sub, @as(f32, 2)), V.new(8, 16, 24), 1e-6);
}

test "Vec3 -> angle_between uses both vector lengths" {
    const a = V.new(1, 0, 0);
    try testing.expectApproxEqAbs(@as(f32, 0), V.angle_between(a, V.new(4, 0, 0), f32), 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0), V.angle_between(V.new(3, 0, 0), a, f32), 1e-5);
    try testing.expectApproxEqAbs(Math.PI / 4.0, V.angle_between(a, V.new(2, 2, 0), f32), 1e-5);
    try testing.expectApproxEqAbs(Math.PI, V.angle_between(a, V.new(-5, 0, 0), f32), 1e-5);
}

test "Vec3 -> triple products" {
    const a = V.new(1, 0, 0);
    const b = V.new(0, 1, 0);
    const c = V.new(1, 2, 3);

    // a . (b x c)
    try testing.expectApproxEqAbs(@as(f32, 3), V.triple_product_scalar(a, b, c), 1e-6);

    // a x (b x c) == b * (a . c) - c * (a . b)
    const expected = b.scale(a.dot(c)).subtract(c.scale(a.dot(b)));
    try expectVecApprox(V.triple_product_vector(a, b, c), expected, 1e-6);
}

test "Vec3 -> shoelace_area_total" {
    const triangle = [_]V{
        V.new(0, 0, 0),
        V.new(1, 0, 0),
        V.new(0, 1, 0),
    };
    try testing.expectApproxEqAbs(@as(f32, 0.5), V.shoelace_area_total(&triangle), 1e-6);

    const square = [_]V{
        V.new(0, 0, 0),
        V.new(2, 0, 0),
        V.new(2, 2, 0),
        V.new(0, 2, 0),
    };
    try testing.expectApproxEqAbs(@as(f32, 4), V.shoelace_area_total(&square), 1e-6);
}

test "Vec3 -> perp_any is perpendicular for all sign combinations" {
    const cases = [_]V{
        V.new(1, 2, 3),
        V.new(-1, 2, 3),
        V.new(1, -2, 3),
        V.new(1, 2, -3),
        V.new(-1, -2, 3),
        V.new(-1, 2, -3),
        V.new(1, -2, -3),
        V.new(-1, -2, -3),
        V.new(0, 5, 0),
        V.new(0, 0, 5),
        V.new(5, 0, 0),
    };
    for (cases) |v| {
        const p = v.perp_any();
        try testing.expect(!p.is_zero());
        try testing.expectApproxEqAbs(@as(f32, 0), v.dot(p), 1e-4);
    }
}

test "Vec3 -> approx_colinear checks the absolute cross product" {
    try testing.expect(V.approx_colinear(V.new(0, 0, 0), V.new(1, 1, 1), V.new(2, 2, 2)));
    try testing.expect(V.approx_colinear(V.new(0, 0, 0), V.new(1, 0, 0), V.new(2, 0, 0)));
    // non-colinear points that produce a negative cross-product component
    try testing.expect(!V.approx_colinear(V.new(0, 0, 0), V.new(1, 0, 0), V.new(0, -1, 0)));
    try testing.expect(!V.approx_colinear_with_epsilon(V.new(0, 0, 0), V.new(1, 0, 0), V.new(0, -1, 0), 0.0001));
}

test "Vec3 -> normalize_may_be_zero" {
    try expectVecApprox(V.ZERO.normalize_may_be_zero(.NORM_ZERO_IS_ZERO), V.ZERO, 0);
    try expectVecApprox(V.ZERO.normalize_may_be_zero(.NORM_ZERO_IS_LAST_COMPONENT_1), V.new(0, 0, 1), 0);
    try expectVecApprox(V.new(0, 3, 0).normalize_may_be_zero(.NORM_ZERO_IS_ZERO), V.new(0, 1, 0), 1e-6);
    try expectVecApprox(V.new(3, 0, 4).normalize_may_be_zero(.NORM_ZERO_IS_ZERO), V.new(0.6, 0, 0.8), 1e-6);
}

test "Vec3 -> z-axis rotation transform uses the z axis" {
    const rz = V.TransformStep.rotate_around_z_axis_degrees(@as(f32, 90));
    try expectVecApprox(V.new(1, 0, 0).apply_transform(rz), V.new(0, 1, 0), 1e-5);
    try expectVecApprox(V.new(1, 0, 0).apply_inverse_transform(rz), V.new(0, -1, 0), 1e-5);

    const rx = V.TransformStep.rotate_around_x_axis_degrees(@as(f32, 90));
    try expectVecApprox(V.new(0, 1, 0).apply_transform(rx), V.new(0, 0, 1), 1e-5);

    const ry = V.TransformStep.rotate_around_y_axis_degrees(@as(f32, 90));
    try expectVecApprox(V.new(0, 0, 1).apply_transform(ry), V.new(1, 0, 0), 1e-5);
}

test "Vec3 -> inverse transforms undo forward transforms" {
    const original = V.new(1.5, -2.25, 3.75);

    const translate = V.TransformStep.translate(V.new(3, -2, 5));
    try expectVecApprox(original.apply_transform(translate).apply_inverse_transform(translate), original, 1e-6);

    const translate_xy = V.TransformStep.translate_xy(@as(f32, 2), @as(f32, -4));
    try expectVecApprox(original.apply_transform(translate_xy).apply_inverse_transform(translate_xy), original, 1e-6);

    const scale = V.TransformStep.scale(V.new(2, 4, 0.5));
    try expectVecApprox(original.apply_transform(scale).apply_inverse_transform(scale), original, 1e-6);

    const scale_yz = V.TransformStep.scale_yz(@as(f32, 3), @as(f32, -2));
    try expectVecApprox(original.apply_transform(scale_yz).apply_inverse_transform(scale_yz), original, 1e-6);

    const rotate = V.TransformStep.rotate_around_z_axis_degrees(@as(f32, 37));
    try expectVecApprox(original.apply_transform(rotate).apply_inverse_transform(rotate), original, 1e-5);
}

test "Vec3 -> forms_corner_dot_or_cross_product_threshold" {
    const x = V.new(1, 0, 0);
    try testing.expect(!x.forms_corner_dot_or_cross_product_threshold(V.new(1, 0, 0), @as(f32, 0)));
    try testing.expect(x.forms_corner_dot_or_cross_product_threshold(V.new(0, 1, 0), @as(f32, 0)));
    try testing.expect(x.forms_corner_dot_or_cross_product_threshold(V.new(-1, 0, 0), @as(f32, 0)));
}

test "Vec3 -> affine matrix transforms match direct transforms" {
    const p = V.new(2.5, -1.25, 3.5);
    const steps = [_]V.TransformStep{
        V.TransformStep.translate(V.new(3, -2, 1)),
        V.TransformStep.translate_xz(@as(f32, 1), @as(f32, 3)),
        V.TransformStep.scale(V.new(2, 0.25, -1.5)),
        V.TransformStep.scale_yz(@as(f32, 3), @as(f32, -2)),
        V.TransformStep.skew_x_away_from_y_ratio(@as(f32, 0.75)),
        V.TransformStep.skew_y_away_from_z_ratio(@as(f32, -0.5)),
        V.TransformStep.skew_z_away_from_x_ratio(@as(f32, 0.25)),
        V.TransformStep.rotate_around_x_axis_degrees(@as(f32, 21)),
        V.TransformStep.rotate_around_y_axis_degrees(@as(f32, -42)),
        V.TransformStep.rotate_around_z_axis_degrees(@as(f32, 73)),
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

test "Vec3 -> slope" {
    const v = V.new(3, 4, 12);
    try testing.expectApproxEqAbs(@as(f32, 12.0 / 5.0), v.slope(.XY), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 5.0 / 12.0), v.slope_inverse(.XY), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 3.0 / @sqrt(160.0)), v.slope(.YZ), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 4.0 / @sqrt(153.0)), v.slope(.XZ), 1e-6);
}
