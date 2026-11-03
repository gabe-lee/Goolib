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
const Vec4 = Root.Vec4;
const V = Vec4.define_vec4_type(f32);
const V64 = Vec4.define_vec4_type(i64);

fn expectVecApprox(actual: V, expected: V, epsilon: f32) !void {
    try testing.expectApproxEqAbs(expected.x, actual.x, epsilon);
    try testing.expectApproxEqAbs(expected.y, actual.y, epsilon);
    try testing.expectApproxEqAbs(expected.z, actual.z, epsilon);
    try testing.expectApproxEqAbs(expected.w, actual.w, epsilon);
}

test "Vec4 -> set and set_rgba/set_bgra mutate the vector" {
    var v = V.new(1, 2, 3, 4);

    v.set(.X, 10);
    v.set(.Y, 20);
    v.set(.Z, 30);
    v.set(.W, 40);
    try expectVecApprox(v, V.new(10, 20, 30, 40), 0);

    try testing.expectEqual(@as(f32, 10), v.get(.X));
    try testing.expectEqual(@as(f32, 20), v.get(.Y));
    try testing.expectEqual(@as(f32, 30), v.get(.Z));
    try testing.expectEqual(@as(f32, 40), v.get(.W));

    var rgba = V.new_rgba(1, 2, 3, 4);
    rgba.set_rgba(.R, 11);
    rgba.set_rgba(.G, 22);
    rgba.set_rgba(.B, 33);
    rgba.set_rgba(.A, 44);
    try expectVecApprox(rgba, V.new(11, 22, 33, 44), 0);
    try testing.expectEqual(@as(f32, 11), rgba.get_rgba(.R));
    try testing.expectEqual(@as(f32, 44), rgba.get_rgba(.A));

    var bgra = V.new_bgra(1, 2, 3, 4);
    // Component_BGRA: B = 0, G = 1, R = 2, A = 3 (storage order x,y,z,w)
    bgra.set_bgra(.B, 55);
    bgra.set_bgra(.G, 66);
    bgra.set_bgra(.R, 77);
    bgra.set_bgra(.A, 88);
    try expectVecApprox(bgra, V.new(55, 66, 77, 88), 0);
    try testing.expectEqual(@as(f32, 55), bgra.get_bgra(.B));
    try testing.expectEqual(@as(f32, 77), bgra.get_bgra(.R));

    const p = v.ptr(.Z);
    p.* = 99;
    try testing.expectEqual(@as(f32, 99), v.z);
}

test "Vec4 -> subtract_scale subtracts" {
    const v = V.new(10, 20, 30, 40);
    const sub = V.new(1, 2, 3, 4);
    try expectVecApprox(v.subtract_scale(sub, @as(f32, 2)), V.new(8, 16, 24, 32), 1e-6);
}

test "Vec4 -> change_component_type_normalized uses floating point division for large ints" {
    const half = std.math.maxInt(i64) / 2;
    const v = V64.new(half, 0, std.math.maxInt(i64), 0);
    const normalized = v.change_component_type_normalized(f32);

    try testing.expectApproxEqAbs(@as(f32, 0.5), normalized.x, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 0.0), normalized.y, 0);
    try testing.expectApproxEqAbs(@as(f32, 1.0), normalized.z, 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 0.0), normalized.w, 0);
}

test "Vec4 -> set on a plain float vector keeps all other components" {
    var v = V.new(-1, -2, -3, -4);
    v.set(.Y, 0);
    try expectVecApprox(v, V.new(-1, 0, -3, -4), 0);
}

test "Vec4 -> dot, lerp, and component helpers" {
    const a = V.new(1, 2, 3, 4);
    const b = V.new(5, 6, 7, 8);
    try testing.expectApproxEqAbs(@as(f32, 70), a.dot(b), 1e-6);
    try expectVecApprox(V.lerp(a, b, @as(f32, 0.5)), V.new(3, 4, 5, 6), 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 10), a.component_sum(), 1e-6);
    try expectVecApprox(a.squared(), V.new(1, 4, 9, 16), 1e-6);
    try expectVecApprox(a.negate(), V.new(-1, -2, -3, -4), 0);
    try testing.expect(V.approx_equal_with_epsilon(a, a, V.new_splat(0.01)));
}
