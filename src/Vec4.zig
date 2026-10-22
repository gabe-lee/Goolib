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
const math = std.math;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const Common = Root.CommonTypes;
const Types = Root.Types;
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;
const Vec2Module = Root.Vec2;
const Vec3Module = Root.Vec3;
const Matrix = Root.Matrix;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

pub const PadForGpu = Common.PadForGpu;
pub const PerpendicularZero = Common.PerpendicularZero;
pub const NormalizeZero = Common.NormalizeZero;
pub const Plane3D = Common.Plane3D;
pub const ShouldTranslate = Common.ShouldTranslate;

pub const Component = enum(u8) {
    X = 0,
    Y = 1,
    Z = 2,
    W = 3,
};
pub const Component_RGBA = enum(u8) {
    R = 0,
    G = 1,
    B = 2,
    A = 3,
};
pub const Component_BGRA = enum(u8) {
    B = 0,
    G = 1,
    R = 2,
    A = 3,
};

pub fn define_vec4_type(comptime T: type) type {
    return extern struct {
        const Vec4 = @This();
        const Vec3 = Vec3Module.define_vec3_type(T);
        const Vec2 = Vec2Module.define_vec2_type(T);
        const IS_FLOAT = switch (T) {
            f16, f32, f64, f80, f128, c_longdouble => true,
            else => false,
        };
        const IS_INT = switch (T) {
            i8, i16, i32, i64, i128, isize, u8, u16, u32, u64, u128, usize, c_short, c_int, c_long, c_longlong, c_char, c_ushort, c_uint, c_ulong, c_ulonglong => true,
            else => false,
        };
        const IS_LARGE_INT = switch (T) {
            i64, i128, isize, u64, u128, usize, c_longlong, c_ulonglong => true,
            else => false,
        };
        pub const F = if (IS_FLOAT) T else if (IS_LARGE_INT) f64 else f32;

        x: T = 0,
        y: T = 0,
        z: T = 0,
        w: T = 0,

        pub const VEC: type = @Vector(4, T);
        pub const ZERO = Vec4{ .x = 0, .y = 0, .z = 0, .w = 0 };
        pub const ONE = Vec4{ .x = 1, .y = 1, .z = 1, .w = 1 };
        pub const MIN = Vec4{ .x = MIN_T, .y = MIN_T, .z = MIN_T, .w = MIN_T };
        pub const MAX = Vec4{ .x = MAX_T, .y = MAX_T, .z = MAX_T, .w = MAX_T };
        pub const FILLED_WITH_4 = Vec4{ .x = 4, .y = 4, .z = 4, .w = 4 };
        pub const MIN_T = if (IS_FLOAT) -math.inf(T) else math.minInt(T);
        pub const MAX_T = if (IS_FLOAT) math.inf(T) else math.maxInt(T);
        pub const LAST_COMPONENT_IDX = 3;
        pub const NORM_MAX: T = if (IS_FLOAT) 1 else math.maxInt(T);
        pub const NORM_MAX_F: f64 = num_cast(NORM_MAX, f64);

        pub fn new(x: T, y: T, z: T, w: T) Vec4 {
            return Vec4{ .x = x, .y = y, .z = z, .w = w };
        }
        pub fn new_rgba(r: T, g: T, b: T, a: T) Vec4 {
            return new(r, g, b, a);
        }
        pub fn new_bgra(b: T, g: T, r: T, a: T) Vec4 {
            return new(b, g, r, a);
        }
        pub fn new_splat(val: T) Vec4 {
            return new(val, val, val, val);
        }
        pub fn new_any(x: anytype, y: anytype, z: anytype, w: anytype) Vec4 {
            return new(num_cast(x, T), num_cast(y, T), num_cast(z, T), num_cast(w, T));
        }
        pub fn new_any_rgba(r: anytype, g: anytype, b: anytype, a: anytype) Vec4 {
            return new(num_cast(r, T), num_cast(g, T), num_cast(b, T), num_cast(a, T));
        }
        pub fn new_any_bgra(b: anytype, g: anytype, r: anytype, a: anytype) Vec4 {
            return new(num_cast(b, T), num_cast(g, T), num_cast(r, T), num_cast(a, T));
        }
        pub fn new_splat_any(val: anytype) Vec4 {
            return new_splat(num_cast(val, T));
        }

        pub fn to_vec(self: Vec4) VEC {
            return .{ self.x, self.y, self.z, self.w };
        }
        pub fn from_vec(vec: VEC) Vec4 {
            return .{ .x = vec[0], .y = vec[1], .z = vec[2], .w = vec[3] };
        }
        pub fn vec_ptr(self: *Vec4) *VEC {
            return @ptrCast(@alignCast(self));
        }

        pub inline fn get(self: Vec4, component: Component) T {
            return self.to_vec()[@backingInt(component)];
        }
        pub inline fn get_rgba(self: Vec4, component: Component_RGBA) T {
            return self.to_vec()[@backingInt(component)];
        }
        pub inline fn get_bgra(self: Vec4, component: Component_BGRA) T {
            return self.to_vec()[@backingInt(component)];
        }
        pub inline fn set(self: *Vec4, component: Component, val: T) void {
            self.to_vec()[@backingInt(component)] = val;
        }
        pub inline fn set_rgba(self: *Vec4, component: Component_RGBA, val: T) void {
            self.to_vec()[@backingInt(component)] = val;
        }
        pub inline fn set_bgra(self: *Vec4, component: Component_BGRA, val: T) void {
            self.to_vec()[@backingInt(component)] = val;
        }
        pub inline fn ptr(self: *Vec4, component: Component) *T {
            return &self.vec_ptr()[@backingInt(component)];
        }
        pub inline fn ptr_rgba(self: *Vec4, component: Component_RGBA) *T {
            return &self.vec_ptr()[@backingInt(component)];
        }
        pub inline fn ptr_bgra(self: *Vec4, component: Component_BGRA) *T {
            return &self.vec_ptr()[@backingInt(component)];
        }

        pub fn downgrade_to_vec2(self: Vec4) Vec2 {
            return Vec2{ self.x, self.y };
        }
        pub fn downgrade_to_vec3(self: Vec4) Vec3 {
            return Vec3{ self.x, self.y, self.z };
        }

        pub fn swizzle(self: Vec4, new_x: Component, new_y: Component, new_z: Component, new_w: Component) Vec4 {
            return new(self.to_vec()[@backingInt(new_x)], self.to_vec()[@backingInt(new_y)], self.to_vec()[@backingInt(new_z)], self.to_vec()[@backingInt(new_w)]);
        }
        pub fn swizzle_rgba(self: Vec4, new_r: Component_RGBA, new_g: Component_RGBA, new_b: Component_RGBA, new_a: Component_RGBA) Vec4 {
            return new(self.to_vec()[@backingInt(new_r)], self.to_vec()[@backingInt(new_g)], self.to_vec()[@backingInt(new_b)], self.to_vec()[@backingInt(new_a)]);
        }
        pub fn swizzle_bgra(self: Vec4, new_b: Component_BGRA, new_g: Component_BGRA, new_r: Component_BGRA, new_a: Component_BGRA) Vec4 {
            return new(self.to_vec()[@backingInt(new_b)], self.to_vec()[@backingInt(new_g)], self.to_vec()[@backingInt(new_r)], self.to_vec()[@backingInt(new_a)]);
        }

        pub fn inverse(self: Vec4) Vec4 {
            return .from_vec(ONE.to_vec() / self.to_vec());
        }

        pub fn ceil(self: Vec4) Vec4 {
            if (IS_INT) return self;
            return .from_vec(@ceil(self.to_vec()));
        }

        pub fn floor(self: Vec4) Vec4 {
            if (IS_INT) return self;
            return .from_vec(@floor(self.to_vec()));
        }

        pub fn round(self: Vec4) Vec4 {
            if (IS_INT) return self;
            return .from_vec(@round(self.to_vec()));
        }

        pub fn dot_product(self: Vec4, other: Vec4) T {
            const products = self.to_vec() * other.to_vec();
            return @reduce(.Add, products);
        }
        pub inline fn dot(self: Vec4, other: Vec4) T {
            return self.dot_product(other);
        }
        pub inline fn dot_product_self(self: Vec4) T {
            return self.dot_product(self);
        }
        pub inline fn dot_self(self: Vec4) T {
            return self.dot_product_self();
        }

        pub fn add(self: Vec4, other: Vec4) Vec4 {
            return .from_vec(self.to_vec() + other.to_vec());
        }

        pub fn subtract(self: Vec4, other: Vec4) Vec4 {
            return .from_vec(self.to_vec() - other.to_vec());
        }

        pub fn multiply(self: Vec4, other: Vec4) Vec4 {
            return .from_vec(self.to_vec() * other.to_vec());
        }

        pub fn divide(self: Vec4, other: Vec4) Vec4 {
            assert_with_reason(!@reduce(.Or, other.to_vec() == ZERO.to_vec()), @src(), "cannot divide two vectors when one of the components of the divisor vector is 0, got divisor = {any}", .{other.to_vec()});
            return .from_vec(self.to_vec() / other.to_vec());
        }

        pub fn scale(self: Vec4, val: anytype) Vec4 {
            const val_vec: @Vector(4, @TypeOf(val)) = @splat(val);
            return .from_vec(MathX.upgrade_multiply_out(self.to_vec(), val_vec, VEC));
        }
        pub fn inverse_scale(self: Vec4, val: anytype) Vec4 {
            if (@TypeOf(val) == bool) {
                assert_with_reason(val != false, @src(), "cannot `inverse_scale()` when the scale value is `false`, (divide by zero)", .{});
            } else {
                assert_with_reason(val != 0, @src(), "cannot `inverse_scale()` when the scale value is 0, (divide by zero)", .{});
            }
            const val_vec: @Vector(4, @TypeOf(val)) = @splat(val);
            return .from_vec(MathX.upgrade_divide_out(self.to_vec(), val_vec, VEC));
        }

        pub fn add_scale(self: Vec4, add_vec: Vec4, scale_add_vec_by: anytype) Vec4 {
            return self.add(add_vec.scale(scale_add_vec_by));
        }

        pub fn subtract_scale(self: Vec4, subtract_vec: Vec4, scale_subtract_vec_by: anytype) Vec4 {
            return self.add(subtract_vec.scale(scale_subtract_vec_by));
        }

        pub fn squared(self: Vec4) Vec4 {
            return .from_vec(self.to_vec() * self.to_vec());
        }

        pub fn component_sum(self: Vec4) T {
            return @reduce(.Add, self.to_vec());
        }

        fn lerp_internal(p1: Vec4, p2: Vec4, percent: anytype) Vec4 {
            const delta = if (Types.type_is_vector(@TypeOf(percent))) get: {
                const CHILD = @typeInfo(@TypeOf(percent)).vector.child;
                assert_is_float(CHILD, @src());
                break :get percent;
            } else get: {
                assert_is_float(@TypeOf(percent), @src());
                break :get @as(@Vector(VEC.len, @TypeOf(percent)), @splat(percent));
            };
            const nums = MathX.upgrade_3_numbers_for_math(p1.to_vec(), p2.to_vec(), delta);
            const TU = @FieldType(@TypeOf(nums), "a");
            const result = @mulAdd(TU, nums.c, nums.b, @mulAdd(TU, -nums.c, nums.a, nums.a));
            return .from_vec(num_cast(result, VEC));
        }

        pub fn lerp(p1: Vec4, p2: Vec4, percent: anytype) Vec4 {
            return lerp_internal(p1, p2, percent);
        }
        pub inline fn linear_interp(p1: Vec4, p2: Vec4, percent: anytype) Vec4 {
            return lerp_internal(p1, p2, percent);
        }
        pub fn quadratic_interp(p1: Vec4, p2: Vec4, p3: Vec4, percent: anytype) Vec4 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            return lerp_internal(p12, p23, percent);
        }
        pub fn cubic_interp(p1: Vec4, p2: Vec4, p3: Vec4, p4: Vec4, percent: anytype) Vec4 {
            const p12 = lerp_internal(p1, p2, percent);
            const p23 = lerp_internal(p2, p3, percent);
            const p34 = lerp_internal(p3, p4, percent);
            const p12_23 = lerp_internal(p12, p23, percent);
            const p23_34 = lerp_internal(p23, p34, percent);
            return lerp_internal(p12_23, p23_34, percent);
        }
        pub fn n_bezier_interp(comptime NN: comptime_int, p: [NN]Vec4, percent: anytype) Vec4 {
            var tmp: [2][NN]Vec4 = .{ p, @splat(Vec4{}) };
            var curr: usize = 0;
            var next: usize = 1;
            var curr_points: usize = NN;
            var i: usize = undefined;
            var j: usize = undefined;
            while (curr_points > 1) {
                i = 0;
                j = 1;
                while (j < curr_points) {
                    tmp[next][i] = lerp_internal(tmp[curr][i], tmp[curr][j], percent);
                    i = j;
                    j += 1;
                }
                curr_points -= 1;
                curr = curr ^ 1;
                next = next ^ 1;
            }
            return tmp[curr][0];
        }

        pub fn lerp_delta_range(self: Vec4, other: Vec4, min_delta: anytype, max_delta: anytype, range_delta: anytype) Vec4 {
            const range = MathX.upgrade_subtract(max_delta, min_delta);
            const range_percent = MathX.upgrade_multiply(range, range_delta);
            const percent = MathX.upgrade_add(min_delta, range_percent);
            return lerp_internal(self, other, percent);
        }

        pub fn lerp_delta_delta(self: Vec4, other: Vec4, delta: anytype, delta_delta: anytype) Vec4 {
            const percent = MathX.upgrade_multiply(delta, delta_delta);
            return lerp_internal(self, other, percent);
        }

        pub fn negate(self: Vec4) Vec4 {
            return .from_vec(-self.to_vec());
        }

        pub fn equals(self: Vec4, other: Vec4) bool {
            return @reduce(.And, self.to_vec() == other.to_vec());
        }

        pub fn approx_equal(self: Vec4, other: Vec4) bool {
            return MathX.approx_equal_vec(VEC, self.to_vec(), other.to_vec());
        }
        pub fn approx_equal_with_epsilon(self: Vec4, other: Vec4, epsilon: Vec4) bool {
            return MathX.approx_equal_with_epsilon_vec(VEC, self.to_vec(), other.to_vec(), epsilon);
        }

        pub fn is_zero(self: Vec4) bool {
            return @reduce(.And, self.to_vec() == ZERO.to_vec());
        }
        pub fn non_zero(self: Vec4) bool {
            return !@reduce(.And, self.to_vec() == ZERO.to_vec());
        }

        pub fn rate_required_to_reach_point_at_time(self: Vec4, point: Vec4, time: anytype) Vec4 {
            return point.subtract(self).scale(1 / time);
        }

        pub fn rate_required_to_reach_point_inverse_time(self: Vec4, point: Vec4, inverse_time: anytype) Vec4 {
            return point.subtract(self).scale(inverse_time);
        }

        pub fn change_component_type(self: Vec4, comptime NEW_T: type) define_vec4_type(NEW_T) {
            const V = define_vec4_type(NEW_T);
            return .from_vec(num_cast(self.to_vec(), V.VEC));
        }
        pub fn change_component_type_normalized(self: Vec4, comptime NEW_T: type) define_vec4_type(NEW_T) {
            const V = define_vec4_type(NEW_T);
            if (comptime IS_FLOAT and V.IS_FLOAT) {
                return V.new_any(self.x, self.y, self.z, self.w);
            } else {
                const px: f64, const py: f64, const pz: f64, const pw: f64 = calc: {
                    if (comptime IS_INT and @bitSizeOf(T) > 50) {
                        const px = @max(0.0, @min(1.0, num_cast(self.x / NORM_MAX, f64)));
                        const py = @max(0.0, @min(1.0, num_cast(self.y / NORM_MAX, f64)));
                        const pz = @max(0.0, @min(1.0, num_cast(self.z / NORM_MAX, f64)));
                        const pw = @max(0.0, @min(1.0, num_cast(self.w / NORM_MAX, f64)));
                        break :calc .{ px, py, pz, pw };
                    } else if (comptime IS_INT) {
                        const px = @max(0.0, @min(1.0, num_cast(self.x, f64) / NORM_MAX_F));
                        const py = @max(0.0, @min(1.0, num_cast(self.y, f64) / NORM_MAX_F));
                        const pz = @max(0.0, @min(1.0, num_cast(self.z, f64) / NORM_MAX_F));
                        const pw = @max(0.0, @min(1.0, num_cast(self.w, f64) / NORM_MAX_F));
                        break :calc .{ px, py, pz, pw };
                    } else {
                        const px = @max(0.0, @min(1.0, num_cast(self.x, f64)));
                        const py = @max(0.0, @min(1.0, num_cast(self.y, f64)));
                        const pz = @max(0.0, @min(1.0, num_cast(self.z, f64)));
                        const pw = @max(0.0, @min(1.0, num_cast(self.w, f64)));
                        break :calc .{ px, py, pz, pw };
                    }
                };
                const nx: NEW_T = num_cast(px * V.NORM_MAX_F, NEW_T);
                const ny: NEW_T = num_cast(py * V.NORM_MAX_F, NEW_T);
                const nz: NEW_T = num_cast(pz * V.NORM_MAX_F, NEW_T);
                const nw: NEW_T = num_cast(pw * V.NORM_MAX_F, NEW_T);
                return V.new(nx, ny, nz, nw);
            }
        }
    };
}
