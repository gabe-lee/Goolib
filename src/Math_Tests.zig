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

test "Math -> sign_nonzero treats zero as non-negative" {
    try testing.expectEqual(@as(i32, -1), Math.sign_nonzero(@as(i32, -5)));
    try testing.expectEqual(@as(i32, -1), Math.sign_nonzero(@as(i32, -1)));
    // documented behavior: -1 if val < 0, 1 if val >= 0
    try testing.expectEqual(@as(i32, 1), Math.sign_nonzero(@as(i32, 0)));
    try testing.expectEqual(@as(i32, 1), Math.sign_nonzero(@as(i32, 1)));
    try testing.expectEqual(@as(i32, 1), Math.sign_nonzero(@as(i32, 5)));

    try testing.expectEqual(@as(f32, -1), Math.sign_nonzero(@as(f32, -0.25)));
    try testing.expectEqual(@as(f32, 1), Math.sign_nonzero(@as(f32, 0)));
    try testing.expectEqual(@as(f32, 1), Math.sign_nonzero(@as(f32, 0.25)));

    try testing.expectEqual(@as(i32, 1), Math.sign_nonzero_convert(@as(i32, 0), i32));
    try testing.expectEqual(@as(i32, -1), Math.sign_nonzero_convert(@as(i32, -2), i32));
}

test "Math -> approx_equal_with_epsilon_vec" {
    const VEC = @Vector(3, f32);
    const a: VEC = .{ 1.0, 2.0, 3.0 };
    const near: VEC = .{ 1.001, 2.001, 3.001 };
    const far: VEC = .{ 1.0, 2.0, 3.1 };
    const eps: VEC = @splat(0.01);

    const near_result = Math.approx_equal_with_epsilon_vec(VEC, a, near, eps);
    try testing.expect(@reduce(.And, near_result));

    const far_result = Math.approx_equal_with_epsilon_vec(VEC, a, far, eps);
    try testing.expect(!@reduce(.And, far_result));

    const exact_result = Math.approx_equal_vec(VEC, a, a);
    try testing.expect(@reduce(.And, exact_result));
}

test "Math -> upgrade_root with integer inputs" {
    // `1 / b` used to be truncated to 0 by integer division, making every root 1
    try testing.expectEqual(@as(i32, 3), Math.upgrade_root(@as(i32, 27), @as(i32, 3)));
    try testing.expectEqual(@as(i32, 2), Math.upgrade_root(@as(i32, 8), @as(i32, 3)));
    try testing.expectEqual(@as(i32, -2), Math.upgrade_root(@as(i32, -8), @as(i32, 3)));
    try testing.expectEqual(@as(i32, 4), Math.upgrade_root_out(@as(i32, 16), @as(i32, 2), i32));
    try testing.expectEqual(@as(u32, 5), Math.upgrade_root_out(@as(u32, 25), @as(u32, 2), u32));

    try testing.expectApproxEqAbs(@as(f64, 3.0), Math.upgrade_root(@as(f64, 27.0), @as(f64, 3.0)), 1e-9);
}

test "Math -> range_trichotomy with a single value in the range" {
    try testing.expectEqual(@as(i32, -1), Math.range_trichotomy(0, 0, 1, i32));
    try testing.expectEqual(@as(i32, -1), Math.range_trichotomy(-5, -5, -4, i32));
}

test "Math -> bezier sin/cos handles negative angles" {
    const rad_angles = [_]f32{ -2.0 * Math.PI, -4.712388, -Math.PI, -1.5707963, -1.0, -0.25, 0.0, 0.25, 1.0, 1.5707963, Math.PI, 4.712388 };
    for (rad_angles) |radians| {
        try testing.expectApproxEqAbs(@sin(radians), Math.sin_bezier_rad(radians), 0.01);
        try testing.expectApproxEqAbs(@cos(radians), Math.cos_bezier_rad(radians), 0.01);

        const sin_cos = Math.sin_cos_bezier_rad(radians);
        try testing.expectApproxEqAbs(@sin(radians), sin_cos[0], 0.01);
        try testing.expectApproxEqAbs(@cos(radians), sin_cos[1], 0.01);

        if (@abs(@cos(radians)) > 0.01) {
            try testing.expectApproxEqAbs(@tan(radians), Math.tan_bezier_rad(radians), 0.02);
        }
    }

    const deg_angles = [_]f32{ -360, -270, -180, -90, -45, 0, 45, 90, 180, 270 };
    for (deg_angles) |degrees| {
        const radians = degrees * Math.DEG_TO_RAD;
        try testing.expectApproxEqAbs(@sin(radians), Math.sin_bezier_deg(degrees), 0.01);
        try testing.expectApproxEqAbs(@cos(radians), Math.cos_bezier_deg(degrees), 0.01);

        const sin_cos = Math.sin_cos_bezier_deg(degrees);
        try testing.expectApproxEqAbs(@sin(radians), sin_cos[0], 0.01);
        try testing.expectApproxEqAbs(@cos(radians), sin_cos[1], 0.01);
    }
}

test "Math -> polynomial roots" {
    const linear = Math.solve_linear_polynomial_for_zero(@as(f64, 2), @as(f64, 4));
    try testing.expectEqual(@as(u32, 1), linear.count);
    try testing.expectEqual(Math.SolutionCountMode.finite_solutions, linear.mode);
    try testing.expectApproxEqAbs(@as(f64, -2), linear.vals[0], 1e-12);

    const quadratic = Math.solve_quadratic_polynomial_for_zeros(@as(f64, 1), @as(f64, -5), @as(f64, 6));
    try testing.expectEqual(@as(u32, 2), quadratic.count);
    var quad_sorted = quadratic;
    quad_sorted.sort_by_val_small_to_large();
    try testing.expectApproxEqAbs(@as(f64, 2), quad_sorted.vals[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), quad_sorted.vals[1], 1e-12);

    const no_real_roots = Math.solve_quadratic_polynomial_for_zeros(@as(f64, 1), @as(f64, 0), @as(f64, 1));
    try testing.expectEqual(@as(u32, 0), no_real_roots.count);
    try testing.expectEqual(Math.SolutionCountMode.no_solutions, no_real_roots.mode);

    const cubic = Math.solve_cubic_polynomial_for_zeros(@as(f64, 1), @as(f64, -6), @as(f64, 11), @as(f64, -6));
    try testing.expectEqual(@as(u32, 3), cubic.count);
    var cubic_sorted = cubic;
    cubic_sorted.sort_by_val_small_to_large();
    try testing.expectApproxEqAbs(@as(f64, 1), cubic_sorted.vals[0], 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 2), cubic_sorted.vals[1], 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 3), cubic_sorted.vals[2], 1e-9);
}

test "Math -> basic scalar helpers" {
    try testing.expectEqual(@as(i32, 2), Math.median_of_3(i32, 1, 3, 2));
    try testing.expectEqual(@as(i32, 4), Math.median_of_3(i32, 5, 3, 4));
    try testing.expectEqual(@as(i32, 2), Math.median_of_3(i32, 3, 1, 2));

    try testing.expectEqual(@as(i32, 3), Math.abs_difference(@as(i32, 7), @as(i32, 4)));
    try testing.expectEqual(@as(i32, 3), Math.abs_difference(@as(i32, 4), @as(i32, 7)));

    try testing.expectEqual(@as(i32, 5), Math.clamp(@as(i32, 0), @as(i32, 5), @as(i32, 10)));
    try testing.expectEqual(@as(i32, 0), Math.clamp(@as(i32, 0), @as(i32, -5), @as(i32, 10)));
    try testing.expectEqual(@as(i32, 10), Math.clamp(@as(i32, 0), @as(i32, 15), @as(i32, 10)));

    try testing.expectApproxEqAbs(@as(f64, 5.0), Math.lerp(@as(f64, 0), @as(f64, 10), @as(f64, 0.5)), 1e-12);
    try testing.expectEqual(@as(i32, 10), Math.lerp(@as(i32, 0), @as(i32, 10), @as(i32, 1)));
}

test "Math -> power of 2 helpers" {
    const p8: Math.PowerOf2 = ._8;
    try testing.expectEqual(@as(u64, 8), p8.value());
    try testing.expectEqual(@as(u8, 4), p8.num_bits());
    try testing.expectEqual(@as(u8, 3), p8.bit_shift());
    try testing.expectEqual(@as(u32, 8), p8.value_as_type(u32));

    try testing.expectEqual(Math.PowerOf2._8, Math.PowerOf2.round_up_to_power_of_2(@as(u32, 7)));
    try testing.expectEqual(Math.PowerOf2._8, Math.PowerOf2.round_up_to_power_of_2(@as(u32, 8)));
    try testing.expectEqual(Math.PowerOf2._16, Math.PowerOf2.round_up_to_power_of_2(@as(u32, 9)));

    try testing.expectEqual(Math.PowerOf2._8, Math.PowerOf2.round_down_to_power_of_2(@as(u32, 8)));
    try testing.expectEqual(Math.PowerOf2._4, Math.PowerOf2.round_down_to_power_of_2(@as(u32, 7)));
    try testing.expectEqual(Math.PowerOf2._8, Math.PowerOf2.round_down_to_power_of_2(@as(u32, 9)));
    try testing.expectEqual(Math.PowerOf2._1, Math.PowerOf2.round_down_to_power_of_2(@as(u32, 1)));

    try testing.expectEqual(Math.PowerOf2._8, Math.PowerOf2.round_up_to_power_of_2_at_least(Math.PowerOf2._1, @as(u32, 8)));

    try testing.expectEqual(Math.PowerOf2._1, Math.PowerOf2.alignment_power(@as(u32, 9)));
    try testing.expectEqual(Math.PowerOf2._32, Math.PowerOf2.alignment_power(@as(u32, 32)));
}

test "Math -> range_trichotomy" {
    const t = std.testing;
    const EXTENDED_TEST = false;
    try t.expectEqual(-1, Math.range_trichotomy(0, 0, 10, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 1, 10, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 2, 10, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 3, 10, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 4, 10, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 5, 10, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 6, 10, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 7, 10, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 8, 10, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 9, 10, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 0, 11, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 1, 11, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 2, 11, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 3, 11, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 4, 11, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 5, 11, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 6, 11, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 7, 11, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 8, 11, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 9, 11, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 10, 11, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 0, 1000000, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 100000, 1000000, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 200000, 1000000, i32));
    try t.expectEqual(-1, Math.range_trichotomy(0, 300000, 1000000, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 400000, 1000000, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 500000, 1000000, i32));
    try t.expectEqual(0, Math.range_trichotomy(0, 600000, 1000000, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 700000, 1000000, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 800000, 1000000, i32));
    try t.expectEqual(1, Math.range_trichotomy(0, 900000, 1000000, i32));
    if (EXTENDED_TEST) {
        var total: i32 = 0;
        var v: u32 = 0;
        while (v < 1000000) {
            total += Math.range_trichotomy(0, v, 1000000, i32);
            v += 1;
        }
        try t.expectEqual(0, total); // symetric
        total = 0;
        v = 0;
        while (v < 1000003) {
            total += Math.range_trichotomy(0, v, 1000003, i32);
            v += 1;
        }
        try t.expectEqual(0, total); // symetric
    }
}

test "Math -> zig_zag_encoding" {
    const Test = Root.Testing;
    const I_CASES = [_]i32{ 0, -1, -2, 1, 2 };
    const U_CASES = [_]u32{ 0, 1, 3, 2, 4 };
    var rand_core = Root.Rand.create_new_default_prng_seeded_from_time(std.testing.io);
    const rand = rand_core.random();
    const NUM_RAND = 100;
    for (I_CASES[0..], U_CASES[0..]) |i, u| {
        const uu = Math.zig_zag_encode(i);
        try Test.expect_equal(u, "expected_uint", uu, "zig_zag_encode(i)", "fail", .{});
        const ii = Math.zig_zag_decode(i32, uu);
        try Test.expect_equal(i, "expected_int", ii, "zig_zag_decode(i32, zig_zag_encode(i))", "fail", .{});
    }
    for (0..NUM_RAND) |_| {
        const i = rand.int(i32);
        const u = Math.zig_zag_encode(i);
        const ii = Math.zig_zag_decode(i32, u);
        try Test.expect_equal(i, "original_int", ii, "zig_zag_decode(i32, zig_zag_encode(original_int))", "fail", .{});
    }
}
