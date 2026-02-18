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
const build = @import("builtin");
const assert = std.debug.assert;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Vec2 = Root.Vec2;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;

const Math = @This();

pub const fsize = Types.fsize;

pub const PI = math.pi;
pub const HALF_PI = math.pi / 2;
pub const TAU = math.tau;
pub const DEG_TO_RAD = math.rad_per_deg;
pub const RAD_TO_DEG = math.deg_per_rad;

pub const MAX_EXACT_INTEGER_F16 = 1 << 11;
pub const MAX_EXACT_INTEGER_F32 = 1 << 24;
pub const MAX_EXACT_INTEGER_F64 = 1 << 53;
pub const MAX_EXACT_INTEGER_F128 = 1 << 113;

pub inline fn minor_major_coord_to_idx(minor: anytype, major: @TypeOf(minor), major_stride: @TypeOf(minor)) @TypeOf(minor) {
    return minor + (major * major_stride);
}
pub fn MinorMajorCoord(comptime T: type) type {
    return struct {
        minor: T,
        major: T,
    };
}
pub inline fn idx_to_minor_major_coord(idx: anytype, major_stride: @TypeOf(idx)) MinorMajorCoord(@TypeOf(idx)) {
    return MinorMajorCoord(@TypeOf(idx)){
        .minor = idx % major_stride,
        .major = idx / major_stride,
    };
}

pub inline fn deg_to_rad(comptime T: type, degrees: T) T {
    return degrees * math.rad_per_deg;
}

pub inline fn rad_to_deg(comptime T: type, radians: T) T {
    return radians * math.deg_per_rad;
}

pub fn lerp(a: anytype, b: @TypeOf(a), delta: @TypeOf(a)) @TypeOf(a) {
    const T = @TypeOf(a);
    if (Types.type_is_float(T)) {
        return @mulAdd(T, delta, b, @mulAdd(T, -delta, a, a));
    } else {
        return ((1 - delta) * a) + (delta * b);
    }
}
pub fn upgrade_lerp(a: anytype, b: anytype, delta: anytype) Upgraded3Numbers(@TypeOf(a), @TypeOf(b), @TypeOf(delta)).T {
    const nums = upgrade_3_numbers_for_math(a, b, delta);
    const T = @FieldType(@TypeOf(nums), "a");
    if (Types.type_is_float(T)) {
        return @mulAdd(T, nums.c, nums.b, @mulAdd(T, -nums.c, nums.a, nums.a));
    } else {
        return ((1 - nums.c) * nums.a) + (nums.c * nums.b);
    }
}
pub fn upgrade_lerp_out(a: anytype, b: anytype, delta: anytype, comptime OUT: type) OUT {
    const nums = upgrade_3_numbers_for_math(a, b, delta);
    const T = @FieldType(@TypeOf(nums), "a");
    const out: T = if (Types.type_is_float(T))
        (@mulAdd(T, nums.c, nums.b, @mulAdd(T, -nums.c, nums.a, nums.a)))
    else
        (((1 - nums.c) * nums.a) + (nums.c * nums.b));
    return num_cast(out, OUT);
}

pub fn log_x_base(x: anytype, base: anytype) @TypeOf(x) {
    return @log2(x) / @log2(base);
}

pub fn median_of_3(comptime T: type, a: T, b: T, c: T) T {
    return @max(@min(a, b), @min(@max(a, b), c));
}

pub fn clamp_0_to_1(val: anytype) @TypeOf(val) {
    return clamp(@as(@TypeOf(val), 0), val, @as(@TypeOf(val), 1));
}
pub fn clamp_neg_1_to_1(val: anytype) @TypeOf(val) {
    return clamp(@as(@TypeOf(val), -1), val, @as(@TypeOf(val), 1));
}
pub fn clamp_0_to_max(val: anytype, max: anytype) @TypeOf(val) {
    return clamp(@as(@TypeOf(val), 0), val, max);
}
pub fn clamp(min: anytype, val: anytype, max: anytype) @TypeOf(val) {
    if (@TypeOf(min) == @TypeOf(val) and @TypeOf(val) == @TypeOf(max)) {
        return @min(@max(min, val), max);
    } else {
        return upgrade_min_out(upgrade_max(min, val), max, @TypeOf(val));
    }
}
/// returns:
///   - -1 if val < 0
///   - 0 if val == 0
///   - 1 if val > 0
pub fn sign(val: anytype) @TypeOf(val) {
    const T = @TypeOf(val);
    const raw = @as(i8, @intCast(@intFromBool(0 < val))) - @as(i8, @intCast(@intFromBool(val < 0)));
    if (Types.type_is_float(T)) {
        return @floatFromInt(raw);
    } else {
        return @intCast(raw);
    }
}
/// returns:
///   - -1 if val < 0
///   - 0 if val == 0
///   - 1 if val > 0
pub fn sign_convert(val: anytype, comptime OUT: type) OUT {
    const raw = @as(i8, @intCast(@intFromBool(0 < val))) - @as(i8, @intCast(@intFromBool(val < 0)));
    return num_cast(raw, OUT);
}

/// returns:
///   - -1 if val < 0
///   - 1 if val >= 0
pub fn sign_nonzero(val: anytype) @TypeOf(val) {
    const T = @TypeOf(val);
    const raw = (2 * @as(i8, @intCast(@intFromBool(val > 0)))) - 1;
    if (Types.type_is_float(T)) {
        return @floatFromInt(raw);
    } else {
        return @intCast(raw);
    }
}
/// returns:
///   - -1 if val < 0
///   - 1 if val >= 0
pub fn sign_nonzero_convert(val: anytype, comptime OUT: type) OUT {
    const raw = (2 * @as(i8, @intCast(@intFromBool(val > 0)))) - 1;
    return num_cast(raw, OUT);
}

pub fn add_scale(comptime T: type, a: T, diff_ba: T, delta: T) T {
    return a + (diff_ba * delta);
}

pub fn lerp_delta_min_max(comptime T: type, a: T, b: T, min_delta: T, max_delta: T, delta: T) T {
    return ((b - a) * ((delta - min_delta) / (max_delta - min_delta))) + a;
}

pub fn lerp_delta_max(comptime T: type, a: T, b: T, max_delta: T, delta: T) T {
    return ((b - a) * (delta / max_delta)) + a;
}

pub fn scaled_delta(comptime T: type, delta: T, delta_add: T, delta_ratio: T) T {
    return delta_add + (delta * delta_ratio);
}

pub fn approx_less_than_or_equal_to(comptime T: type, a: T, b: T) bool {
    return a <= (b + math.floatEpsAt(T, b));
}

pub fn approx_less_than(comptime T: type, a: T, b: T) bool {
    return a < (b + math.floatEpsAt(T, b));
}

pub fn approx_greater_than_or_equal_to(comptime T: type, a: T, b: T) bool {
    return (a + math.floatEpsAt(T, a)) >= b;
}

pub fn approx_greater_than(comptime T: type, a: T, b: T) bool {
    return (a + math.floatEpsAt(T, a)) > b;
}

pub fn approx_equal(comptime T: type, a: T, b: T) bool {
    if (Types.type_is_int(T)) return a == b;
    const a_min: T = a - math.floatEpsAt(T, a);
    const a_max: T = a + math.floatEpsAt(T, a);
    const b_min: T = b - math.floatEpsAt(T, b);
    const b_max: T = b + math.floatEpsAt(T, b);
    return a_max >= b_min and b_max >= a_min;
}
pub fn approx_equal_vec(comptime T: type, a: T, b: T) @Vector(@typeInfo(T).vector.len, bool) {
    const I = @typeInfo(T).vector;
    const CHILD = I.child;
    if (Types.type_is_int(CHILD)) return a == b;
    const eps: @Vector(I.len, CHILD) = @splat(math.floatEps(CHILD));
    return approx_equal_with_epsilon_vec(T, a, b, eps);
}

pub fn approx_equal_with_epsilon(comptime T: type, a: T, b: T, epsilon: T) bool {
    const a_min: T = a - epsilon;
    const a_max: T = a + epsilon;
    const b_min: T = b - epsilon;
    const b_max: T = b + epsilon;
    return a_max >= b_min and b_max >= a_min;
}

pub fn approx_equal_with_epsilon_vec(comptime T: type, a: T, b: T, epsilon: T) @Vector(@typeInfo(T).vector.len, bool) {
    const I = @typeInfo(T).vector;
    const a_min: T = a - epsilon;
    const a_max: T = a + epsilon;
    const b_min: T = b - epsilon;
    const b_max: T = b + epsilon;
    const cond_1 = a_max >= b_min;
    const cond_2 = b_max >= a_min;
    const cond_1_cast: @Vector(I.len, u8) = @bitCast(cond_1);
    const cond_2_cast: @Vector(I.len, u8) = @bitCast(cond_2);
    const final_cond_cast = cond_1_cast & cond_2_cast;
    return @bitCast(final_cond_cast);
}

pub const NumberConversionMode = enum(u2) {
    int_to_int = 0b00,
    int_to_float = 0b01,
    float_to_int = 0b10,
    float_to_float = 0b11,
};

pub const NumberUpgradeMode = enum(u3) {
    same_class_ints_A_large,
    same_class_ints_B_large,
    mixed_class_ints,
    both_float_A_large,
    both_float_B_large,
    upgrade_A_to_float,
    upgrade_B_to_float,
};

pub fn larger_float_type(comptime A: type, comptime B: type) type {
    assert_with_reason(Types.type_is_float(A), @src(), "type `A` must be a float type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_float(B), @src(), "type `B` must be a float type, got type `{s}`", .{@typeName(B)});
    if (@typeInfo(A).float.bits > @typeInfo(B).float.bits) {
        return A;
    } else {
        return B;
    }
}
pub fn larger_unsigned_int_type(comptime A: type, comptime B: type) type {
    assert_with_reason(Types.type_is_unsigned_int(A), @src(), "type `A` must be an unsigned integer type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_unsigned_int(B), @src(), "type `B` must be an unsigned integer type, got type `{s}`", .{@typeName(B)});
    if (@typeInfo(A).int.bits > @typeInfo(B).int.bits) {
        return A;
    } else {
        return B;
    }
}
pub fn larger_signed_int_type(comptime A: type, comptime B: type) type {
    assert_with_reason(Types.type_is_signed_int(A), @src(), "type `A` must be a signed integer type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_signed_int(B), @src(), "type `B` must be a signed integer type, got type `{s}`", .{@typeName(B)});
    if (@typeInfo(A).int.bits > @typeInfo(B).int.bits) {
        return A;
    } else {
        return B;
    }
}
pub fn largest_int_type_for_math_vector(comptime A: type, comptime B: type, comptime ABSOLUTE_MAX_BITS: u16) type {
    assert_with_reason(Types.type_is_vector(A) and Types.type_is_int(@typeInfo(A).vector.child), @src(), "type `A` must be an integer vector type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_vector(B) and Types.type_is_int(@typeInfo(B).vector.child), @src(), "type `B` must be an integer vector type, got type `{s}`", .{@typeName(B)});
    const A_INFO = @typeInfo(A).vector;
    const B_INFO = @typeInfo(B).vector;
    assert_with_reason(A_INFO.len == B_INFO.len, @src(), "type `A` and `B` must be vector types with the same length, got {d} (A) != {d} (B)", .{ A_INFO.len, B_INFO.len });
    const A_CHILD = A_INFO.child;
    const B_CHILD = B_INFO.child;
    const LARGEST_CHILD = largest_int_type_for_math(A_CHILD, B_CHILD, ABSOLUTE_MAX_BITS);
    return @Vector(A_INFO.len, LARGEST_CHILD);
}
pub fn largest_int_type_for_math(comptime A: type, comptime B: type, comptime ABSOLUTE_MAX_BITS: u16) type {
    assert_with_reason(Types.type_is_int(A), @src(), "type `A` must be an integer type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_int(B), @src(), "type `B` must be an integer type, got type `{s}`", .{@typeName(B)});
    const IA = @typeInfo(A).int;
    const IB = @typeInfo(B).int;
    const sign_a_bits = if (IA.signedness == .signed) 1 else 0;
    const max_a_bits = IA.bits - sign_a_bits;
    const sign_b_bits = if (IB.signedness == .signed) 1 else 0;
    const max_b_bits = IB.bits - sign_b_bits;
    const max_val_bits = @max(max_a_bits, max_b_bits);
    const max_sign_bits = @max(sign_a_bits, sign_b_bits);
    const final_signed: std.builtin.Signedness = if (max_sign_bits == 1) .signed else .unsigned;
    const final_bits = @min(max_val_bits + max_sign_bits, ABSOLUTE_MAX_BITS);
    return std.meta.Int(final_signed, final_bits);
}

pub const NumberUpgradeModeAndType = struct {
    mode: NumberUpgradeMode,
    type_A: type,
    type_B: type,
};

pub fn upgrade_mode_and_types_vector(comptime A: type, comptime B: type) NumberUpgradeModeAndType {
    assert_with_reason(Types.type_is_vector(A), @src(), "type `A` must be a vector of a numeric type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_vector(B), @src(), "type `B` must be a vector of a numeric type, got type `{s}`", .{@typeName(B)});
    const A_INFO = @typeInfo(A).vector;
    const B_INFO = @typeInfo(B).vector;
    assert_with_reason(A_INFO.len == B_INFO.len, @src(), "type `A` and `B` must be vector types with the same length, got {d} (A) != {d} (B)", .{ A_INFO.len, B_INFO.len });
    const A_CHILD = A_INFO.child;
    const B_CHILD = B_INFO.child;
    const UP_CHILD = upgrade_mode_and_types(A_CHILD, B_CHILD);
    return NumberUpgradeModeAndType{
        .mode = UP_CHILD.mode,
        .type_A = @Vector(A_INFO.len, UP_CHILD.type_A),
        .type_B = @Vector(B_INFO.len, UP_CHILD.type_B),
    };
}

pub fn upgrade_mode_and_types(comptime A: type, comptime B: type) NumberUpgradeModeAndType {
    assert_with_reason(Types.type_is_numeric(A), @src(), "type `A` must be a numeric type, got type `{s}`", .{@typeName(A)});
    assert_with_reason(Types.type_is_numeric(B), @src(), "type `B` must be a numeric type, got type `{s}`", .{@typeName(B)});
    const AA: type = check: {
        if (Types.type_is_comptime(A)) {
            if (Types.type_is_float(A)) {
                break :check f64;
            } else {
                break :check i64;
            }
        } else {
            break :check A;
        }
    };
    const BB: type = check: {
        if (Types.type_is_comptime(B)) {
            if (Types.type_is_float(B)) {
                break :check f64;
            } else {
                break :check i64;
            }
        } else {
            break :check B;
        }
    };
    comptime var MODE: NumberUpgradeMode = undefined;
    if (Types.type_is_float(AA) != Types.type_is_float(BB)) {
        if (Types.type_is_int(AA)) {
            MODE = .upgrade_A_to_float;
        } else {
            MODE = .upgrade_B_to_float;
        }
    } else {
        if (Types.type_is_float(AA)) {
            const IA = @typeInfo(AA).float;
            const IB = @typeInfo(BB).float;
            if (IA.bits > IB.bits) {
                MODE = .both_float_A_large;
            } else {
                MODE = .both_float_B_large;
            }
        } else {
            const IA = @typeInfo(AA).int;
            const IB = @typeInfo(BB).int;
            if (IA.signedness != IB.signedness) {
                MODE = .mixed_class_ints;
            } else if (IA.bits > IB.bits) {
                MODE = .same_class_ints_A_large;
            } else {
                MODE = .same_class_ints_B_large;
            }
        }
    }
    return NumberUpgradeModeAndType{
        .mode = MODE,
        .type_A = AA,
        .type_B = BB,
    };
}

pub fn Upgraded2Numbers(comptime A: type, comptime B: type) type {
    const A_INFO = @typeInfo(A);
    const B_INFO = @typeInfo(B);
    const VECTOR = A_INFO == .vector or B_INFO == .vector;
    const mode_and_types = if (VECTOR) upgrade_mode_and_types_vector(A, B) else upgrade_mode_and_types(A, B);
    const T_: type = switch (mode_and_types.mode) {
        .same_class_ints_B_large, .both_float_B_large, .upgrade_A_to_float => mode_and_types.type_B,
        .same_class_ints_A_large, .both_float_A_large, .upgrade_B_to_float => mode_and_types.type_A,
        .mixed_class_ints => if (VECTOR) largest_int_type_for_math_vector(A, B, 64) else largest_int_type_for_math(mode_and_types.type_A, mode_and_types.type_B, 64),
    };
    return struct {
        pub const T = T_;
        pub const IS_VECTOR = VECTOR;
        a: T = if (VECTOR) @splat(0) else 0,
        b: T = if (VECTOR) @splat(0) else 0,
    };
}

pub fn upgrade_2_numbers_for_math(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const A_INFO = @typeInfo(A);
    const B_INFO = @typeInfo(B);
    const UPGRADE = if (A_INFO == .vector or B_INFO == .vector) upgrade_mode_and_types_vector(A, B) else upgrade_mode_and_types(A, B);
    const RESULT = Upgraded2Numbers(UPGRADE.type_A, UPGRADE.type_B);
    return RESULT{
        .a = num_cast(a, RESULT.T),
        .b = num_cast(b, RESULT.T),
    };
}

pub fn Upgraded3Numbers(comptime A: type, comptime B: type, comptime C: type) type {
    const AB = Upgraded2Numbers(A, B);
    const ABC = Upgraded2Numbers(AB.T, C);
    return struct {
        pub const T: type = ABC.T;
        pub const IS_VECTOR = ABC.IS_VECTOR;
        a: T = if (IS_VECTOR) @splat(0) else 0,
        b: T = if (IS_VECTOR) @splat(0) else 0,
        c: T = if (IS_VECTOR) @splat(0) else 0,
    };
}

pub fn upgrade_3_numbers_for_math(a: anytype, b: anytype, c: anytype) Upgraded3Numbers(@TypeOf(a), @TypeOf(b), @TypeOf(c)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const C = @TypeOf(c);
    const RESULT = Upgraded3Numbers(A, B, C);
    return RESULT{
        .a = num_cast(a, RESULT.T),
        .b = num_cast(b, RESULT.T),
        .c = num_cast(c, RESULT.T),
    };
}

pub fn upgrade_to_float(val: anytype, comptime UPGRADE_TYPE_IF_NEEDED: type) if (Types.type_is_float(@TypeOf(val))) @TypeOf(val) else UPGRADE_TYPE_IF_NEEDED {
    if (Types.type_is_float(@TypeOf(val))) {
        return val;
    } else {
        return num_cast(val, UPGRADE_TYPE_IF_NEEDED);
    }
}

pub fn upgrade_add_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a + nums.b;
    return num_cast(c, OUT);
}
pub fn upgrade_add(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a + nums.b;
}
pub fn upgrade_subtract_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a - nums.b;
    return num_cast(c, OUT);
}
pub fn upgrade_subtract(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a - nums.b;
}
pub fn upgrade_multiply_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a * nums.b;
    return num_cast(c, OUT);
}
pub fn upgrade_multiply(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a * nums.b;
}
pub fn upgrade_divide_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a / nums.b;
    return num_cast(c, OUT);
}
pub fn upgrade_divide(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a / nums.b;
}
pub fn upgrade_power_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const C = @FieldType(nums, "a");
    const c = math.pow(C, nums.a, nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_power(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return math.pow(@FieldType(nums, "a"), nums.a, nums.b);
}
pub fn upgrade_root_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const C = @FieldType(nums, "a");
    const c = math.pow(C, nums.a, 1 / nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_root(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return math.pow(@FieldType(nums, "a"), nums.a, 1 / nums.b);
}
pub fn upgrade_log_x_base_out(x: anytype, base: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(x, base);
    const c = log_x_base(nums.a, nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_log_x_base(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return log_x_base(nums.a, nums.b);
}
pub fn upgrade_modulo_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @mod(nums.a, nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_modulo(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @mod(nums.a, nums.b);
}
pub fn upgrade_max_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @max(nums.a, nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_max(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @max(nums.a, nums.b);
}
pub fn upgrade_min_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @min(nums.a, nums.b);
    return num_cast(c, OUT);
}
pub fn upgrade_min(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @min(nums.a, nums.b);
}

pub fn upgrade_equal_to(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a == nums.b;
}
pub fn upgrade_equal_to_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a == nums.b, OUT);
}
pub fn upgrade_not_equal_to(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a != nums.b;
}
pub fn upgrade_not_equal_to_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a != nums.b, OUT);
}
pub fn upgrade_less_than(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a < nums.b;
}
pub fn upgrade_less_than_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a < nums.b, OUT);
}
pub fn upgrade_less_than_or_equal(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a <= nums.b;
}
pub fn upgrade_less_than_or_equal_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a <= nums.b, OUT);
}
pub fn upgrade_greater_than(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a > nums.b;
}
pub fn upgrade_greater_than_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a > nums.b, OUT);
}
pub fn upgrade_greater_than_or_equal(a: anytype, b: anytype) BoolOrVectorOfBools(@TypeOf(a)) {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a >= nums.b;
}
pub fn upgrade_greater_than_or_equal_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    return num_cast(nums.a >= nums.b, OUT);
}

pub fn change_per_unit_time_required_to_reach_val_at_time(comptime T: type, current: T, target: T, time: T) T {
    return (target - current) * (1.0 / time);
}
pub fn BoolOrVectorOfBools(comptime T: type) type {
    return if (Types.type_is_vector(T)) @Vector(@typeInfo(T).vector.len, bool) else bool;
}

pub fn change_per_unit_time_required_to_reach_val_at_inverse_time(comptime T: type, current: T, target: T, inverse_time: T) T {
    return (target - current) * inverse_time;
}

pub const ScanlinePointMode = enum {
    axis_only,
    point,
};
pub const ScanlineSlopeMode = enum {
    exact,
    sign,
};

pub fn ScanlineIntersectionPointType(comptime POINT_MODE: ScanlinePointMode, comptime AXIS_VALUE_TYPE: type) type {
    return switch (POINT_MODE) {
        .point => Vec2.define_vec2_type(AXIS_VALUE_TYPE),
        .axis_only => AXIS_VALUE_TYPE,
    };
}
pub fn ScanlineIntersectionSlopeType(comptime SLOPE_MODE: ScanlineSlopeMode, comptime AXIS_VALUE_TYPE: type, comptime SLOPE_TYPE: type) type {
    return switch (SLOPE_MODE) {
        .exact => AXIS_VALUE_TYPE,
        .sign => SLOPE_TYPE,
    };
}
pub fn ScanlineIntersection(comptime POINT_MODE: ScanlinePointMode, comptime SLOPE_MODE: ScanlineSlopeMode, comptime AXIS_VALUE_TYPE: type, comptime SLOPE_TYPE: type) type {
    const Point = ScanlineIntersectionPointType(POINT_MODE, AXIS_VALUE_TYPE);
    const Slope = ScanlineIntersectionSlopeType(SLOPE_MODE, AXIS_VALUE_TYPE, SLOPE_TYPE);
    return struct {
        const Self = @This();

        point: Point = if (POINT_MODE == .point) .{} else 0,
        slope: Slope = 0,

        pub fn new(point_or_axis_val: Point, slope: Slope) Self {
            return Self{
                .point = point_or_axis_val,
                .slope = slope,
            };
        }
    };
}

pub fn ScanlineIntersections(comptime MAX: comptime_int, comptime AXIS_VALUE_TYPE: type, comptime POINT_MODE: ScanlinePointMode, comptime SLOPE_MODE: ScanlineSlopeMode, comptime SLOPE_TYPE: type) type {
    return struct {
        const Self = @This();
        const Point = ScanlineIntersectionPointType(POINT_MODE, AXIS_VALUE_TYPE);
        const Slope = ScanlineIntersectionSlopeType(SLOPE_MODE, AXIS_VALUE_TYPE, SLOPE_TYPE);

        intersections: [MAX]Intersection = @splat(.{}),
        count: u32 = 0,

        pub fn change_max_intersections(self: Self, comptime NEW_MAX: comptime_int) ScanlineIntersections(NEW_MAX, AXIS_VALUE_TYPE, POINT_MODE, SLOPE_MODE, SLOPE_TYPE) {
            var new_scanlines = ScanlineIntersections(NEW_MAX, AXIS_VALUE_TYPE, POINT_MODE, SLOPE_MODE, SLOPE_TYPE){};
            new_scanlines.count = self.count;
            @memcpy(new_scanlines.intersections[0..self.count], self.intersections[0..self.count]);
            return new_scanlines;
        }

        pub const Intersection = ScanlineIntersection(POINT_MODE, SLOPE_MODE, AXIS_VALUE_TYPE, SLOPE_TYPE);
    };
}

pub fn SignedDistance(comptime T: type) type {
    return struct {
        const Self = @This();

        distance: T = -math.floatMax(T),
        dot_product: T = 0,

        pub inline fn new(dist: T, dot: T) Self {
            return Self{
                .distance = dist,
                .dot_product = dot,
            };
        }

        pub inline fn with_percent(self: Self, percent: T) SignedDistanceWithPercent(T) {
            return SignedDistanceWithPercent(T){
                .signed_dist = self,
                .percent = percent,
            };
        }

        pub inline fn equals(a: Self, b: Self) bool {
            return @abs(a.distance) == @abs(b.distance);
        }
        pub inline fn less_than(a: Self, b: Self) bool {
            return @abs(a.distance) < @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot_product < b.dot_product);
        }
        pub inline fn less_than_or_equal(a: Self, b: Self) bool {
            return @abs(a.distance) <= @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot_product <= b.dot_product);
        }
        pub inline fn greater_than(a: Self, b: Self) bool {
            return @abs(a.distance) > @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot_product > b.dot_product);
        }
        pub inline fn greater_than_or_equal(a: Self, b: Self) bool {
            return @abs(a.distance) >= @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot_product >= b.dot_product);
        }
    };
}
pub fn SignedDistanceWithPercent(comptime T: type) type {
    return struct {
        const Self = @This();

        signed_dist: SignedDistance(T) = .{},
        percent: T = 0,

        pub inline fn new(dist: T, dot: T, percent: T) Self {
            return Self{
                .signed_dist = .new(dist, dot),
                .percent = percent,
            };
        }

        pub inline fn distance(self: Self) T {
            return self.signed_dist.distance;
        }
        pub inline fn dot_product(self: Self) T {
            return self.signed_dist.dot_product;
        }
    };
}

pub fn LinearSolution(comptime T: type) type {
    return PolynomialSolution(1, T);
}

pub fn QuadraticSolution(comptime T: type) type {
    return PolynomialSolution(2, T);
}

pub fn CubicSolution(comptime T: type) type {
    return PolynomialSolution(3, T);
}

pub fn PolynomialSolution(comptime N: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();

        vals: [N]T = @splat(0),
        count: u32 = 0,
        mode: SolutionCountMode = .no_solutions,

        pub fn change_polynimial_degree(self: Self, comptime NN: comptime_int) PolynomialSolution(NN, T) {
            var new_solution = PolynomialSolution(NN, T){};
            @memcpy(new_solution.vals[0..self.count], self.vals[0..self.count]);
            new_solution.count = self.count;
            new_solution.mode = self.mode;
            return new_solution;
        }

        pub fn add_solution(self: *Self, x_val: T) void {
            self.vals[self.count] = x_val;
            self.count += 1;
            if (self.mode == .no_solutions) self.mode = .finite_solutions;
        }

        pub fn add_finite_solutions_if_infinite(self: *Self, comptime count: comptime_int, x_vals: [count]T) void {
            if (self.mode == .infinite_solutions) {
                self.count = count;
                @memcpy(self.vals[0..count], x_vals[0..count]);
            }
        }

        pub fn sort_by_val_small_to_large(self: *Self) void {
            Utils.mem_sort_implicit(self.vals[0..self.count].ptr, 0, @intCast(self.count));
        }
    };
}

pub const SolutionCountMode = enum(u8) {
    no_solutions,
    finite_solutions,
    infinite_solutions,
};

pub const EstimateMode = enum(u8) {
    exact,
    estimate,
};

pub fn LinearEstimate(comptime T: type) type {
    return union(EstimateMode) {
        const Self = @This();

        exact: void,
        estimate: T,

        pub fn do_not_estimate_linear() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_linear_when_linear_coeff_more_than_N_times_quadratic(N: T) Self {
            return Self{ .estimate = N };
        }
    };
}

pub fn QuadraticEstimate(comptime T: type) type {
    return union(EstimateMode) {
        const Self = @This();

        exact: void,
        estimate: T,

        pub fn do_not_estimate_quadratic() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(N: T) Self {
            return Self{ .estimate = N };
        }
    };
}

pub fn DoubleRootEstimate(comptime T: type) type {
    return union(EstimateMode) {
        const Self = @This();

        exact: void,
        estimate: T,

        pub fn do_not_estimate_double_roots() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(N: T) Self {
            return Self{ .estimate = N };
        }
    };
}

// polynomial form: a(x) + b
pub fn solve_linear_polynomial_for_zero(a: anytype, b: @TypeOf(a)) LinearSolution(@TypeOf(a)) {
    var result = LinearSolution(@TypeOf(a)){};
    if (a == 0) {
        if (b == 0) {
            // horizontal line with y == 0
            result.mode = .infinite_solutions;
        } else {
            // horizontal line with y != 0
            result.mode = .no_solutions;
        }
        return result;
    }
    result.vals[0] = -(b / a);
    result.count = 1;
    result.mode = .finite_solutions;
    return result;
}

// polynomial form: a(x^2) + b(x) + c
pub fn solve_quadratic_polynomial_for_zeros(a: anytype, b: @TypeOf(a), c: @TypeOf(a)) QuadraticSolution(@TypeOf(a)) {
    return solve_quadratic_polynomial_for_zeros_advanced(a, b, c, .do_not_estimate_linear());
}

// polynomial form: a(x^2) + b(x) + c
pub fn solve_quadratic_polynomial_for_zeros_estimate(a: anytype, b: @TypeOf(a), c: @TypeOf(a)) QuadraticSolution(@TypeOf(a)) {
    return solve_quadratic_polynomial_for_zeros_advanced(a, b, c, .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12));
}

// polynomial form: a(x^2) + b(x) + c
pub fn solve_quadratic_polynomial_for_zeros_advanced(a: anytype, b: @TypeOf(a), c: @TypeOf(a), linear_estimate: LinearEstimate(@TypeOf(a))) QuadraticSolution(@TypeOf(a)) {
    // if a == 0 (or b is greater than a by many orders of magnitude and linear estimates are enabled), its linear
    if (a == 0 or check_estimate: {
        switch (linear_estimate) {
            .exact => break :check_estimate false,
            .estimate => |ratio| {
                break :check_estimate @abs(b) / @abs(a) > ratio;
            },
        }
    }) {
        return solve_linear_polynomial_for_zero(b, c).change_polynimial_degree(2);
    }
    var result = QuadraticSolution(@TypeOf(a)){};
    const descriminant = (b * b) - (4 * a * c);
    if (descriminant > 0) {
        const a2 = 2 * a;
        const sqrt_descriminant = @sqrt(descriminant);
        result.vals[0] = (-b + sqrt_descriminant) / a2;
        result.vals[1] = (-b - sqrt_descriminant) / a2;
        result.count = 2;
        result.mode = .finite_solutions;
        return result;
    } else if (descriminant == 0) {
        const a2 = 2 * a;
        result.vals[0] = -(b / a2);
        result.count = 1;
        result.mode = .finite_solutions;
        return result;
    } else {
        return result;
    }
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) CubicSolution(@TypeOf(a)) {
    return solve_cubic_polynomial_for_zeros_advanced(a, b, c, d, .do_not_estimate_double_roots(), .do_not_estimate_quadratic(), .do_not_estimate_linear());
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros_estimate(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) CubicSolution(@TypeOf(a)) {
    return solve_cubic_polynomial_for_zeros_advanced(a, b, c, d, .estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(1e-12), .estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(1e6), .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12));
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros_advanced(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a), double_root_estimate: DoubleRootEstimate(@TypeOf(a)), quadratic_estimate: QuadraticEstimate(@TypeOf(a)), linear_estimate: LinearEstimate(@TypeOf(a))) CubicSolution(@TypeOf(a)) {
    const T = @TypeOf(a);
    // if a == 0 (or b is greater than a by many orders of magnitude and quadratic estimates are enabled), its quadratic
    if (a == 0 or check_estimate: {
        switch (quadratic_estimate) {
            .exact => break :check_estimate false,
            .estimate => |ratio| {
                break :check_estimate @abs(b) / @abs(a) > ratio;
            },
        }
    }) {
        return solve_quadratic_polynomial_for_zeros_advanced(b, c, d, linear_estimate).change_polynimial_degree(3);
    }
    var result = CubicSolution(@TypeOf(a)){};
    const a2 = a * a;
    var q = (a2 - (3 * b)) / 9;
    const r = ((a * ((2 * a2) - (9 * b))) + (27 * c)) / 54;
    const r_squared = r * r;
    const q_cubed = q * q * q;
    const third_a = a / 3;
    if (r_squared < q_cubed) {
        var t = r / @sqrt(q_cubed);
        t = clamp(-1, t, 1);
        t = math.acos(t);
        q = @sqrt(q) * -2;
        result.vals[0] = (q * @cos(t / 3)) - third_a;
        result.vals[1] = (q * @cos((t + TAU) / 3)) - third_a;
        result.vals[2] = (q * @cos((t - TAU) / 3)) - third_a;
        result.count = 3;
        result.mode = .finite_solutions;
        return result;
    } else {
        const s: T = if (r < 0) 1 else -1;
        const u = s * math.pow(T, @abs(r) + @sqrt(r_squared - q_cubed), @as(T, 1) / @as(T, 3));
        const v = if (u == 0) 0 else (q / u);
        result.vals[0] = (u + v) - third_a;
        result.mode = .finite_solutions;
        if (u == v or check_estimate: {
            switch (double_root_estimate) {
                .exact => break :check_estimate false,
                .estimate => |ratio| {
                    break :check_estimate @abs(u - v) / @abs(u + v) < ratio;
                },
            }
        }) {
            result.vals[1] = (-(u + v) / 2) - third_a;
            result.count = 2;
        } else {
            result.count = 1;
        }
        return result;
    }
}

/// For any value where `low <= value <= (high - 1)`, returns:
///   - `-1` if the value is closest to `low`
///   - `0` if the value is closest to the midpoint of `low` and `high`
///   - `1` if the value is closest to `high`
///
/// It is guaranteed for integer values, that adding together the results of all values in the range `low <= value <= (high - 1)`
/// will always equal 0. (It is symetrical, the number of `-1` results will always equal the number of `1` results)
pub fn range_trichotomy(low: anytype, value: anytype, high: anytype, comptime OUT: type) OUT {
    const hi = high - low;
    const val = value - low;
    const hi_minus_1 = upgrade_subtract(hi, @as(f32, 1.0));
    const ratio = upgrade_divide(val, hi_minus_1);
    const scaled_ratio = upgrade_multiply(@as(f32, 2.875), ratio);
    const result_unadjusted = @floor(3 + scaled_ratio - 1.4375 + 0.5);
    return num_cast(result_unadjusted, OUT) - 3;
}

test range_trichotomy {
    const t = std.testing;

    try t.expectEqual(-1, range_trichotomy(0, 0, 10, i32));
    try t.expectEqual(-1, range_trichotomy(0, 1, 10, i32));
    try t.expectEqual(-1, range_trichotomy(0, 2, 10, i32));
    try t.expectEqual(0, range_trichotomy(0, 3, 10, i32));
    try t.expectEqual(0, range_trichotomy(0, 4, 10, i32));
    try t.expectEqual(0, range_trichotomy(0, 5, 10, i32));
    try t.expectEqual(0, range_trichotomy(0, 6, 10, i32));
    try t.expectEqual(1, range_trichotomy(0, 7, 10, i32));
    try t.expectEqual(1, range_trichotomy(0, 8, 10, i32));
    try t.expectEqual(1, range_trichotomy(0, 9, 10, i32));
    try t.expectEqual(-1, range_trichotomy(0, 0, 11, i32));
    try t.expectEqual(-1, range_trichotomy(0, 1, 11, i32));
    try t.expectEqual(-1, range_trichotomy(0, 2, 11, i32));
    try t.expectEqual(-1, range_trichotomy(0, 3, 11, i32));
    try t.expectEqual(0, range_trichotomy(0, 4, 11, i32));
    try t.expectEqual(0, range_trichotomy(0, 5, 11, i32));
    try t.expectEqual(0, range_trichotomy(0, 6, 11, i32));
    try t.expectEqual(1, range_trichotomy(0, 7, 11, i32));
    try t.expectEqual(1, range_trichotomy(0, 8, 11, i32));
    try t.expectEqual(1, range_trichotomy(0, 9, 11, i32));
    try t.expectEqual(1, range_trichotomy(0, 10, 11, i32));
    try t.expectEqual(-1, range_trichotomy(0, 0, 1000000, i32));
    try t.expectEqual(-1, range_trichotomy(0, 100000, 1000000, i32));
    try t.expectEqual(-1, range_trichotomy(0, 200000, 1000000, i32));
    try t.expectEqual(-1, range_trichotomy(0, 300000, 1000000, i32));
    try t.expectEqual(0, range_trichotomy(0, 400000, 1000000, i32));
    try t.expectEqual(0, range_trichotomy(0, 500000, 1000000, i32));
    try t.expectEqual(0, range_trichotomy(0, 600000, 1000000, i32));
    try t.expectEqual(1, range_trichotomy(0, 700000, 1000000, i32));
    try t.expectEqual(1, range_trichotomy(0, 800000, 1000000, i32));
    try t.expectEqual(1, range_trichotomy(0, 900000, 1000000, i32));
    var total: i32 = 0;
    var v: u32 = 0;
    while (v < 1000000) {
        total += range_trichotomy(0, v, 1000000, i32);
        v += 1;
    }
    try t.expectEqual(0, total); // symetric
    total = 0;
    v = 0;
    while (v < 1000003) {
        total += range_trichotomy(0, v, 1000003, i32);
        v += 1;
    }
    try t.expectEqual(0, total); // symetric
}

pub fn extract_partial_rand_from_rand(rand: anytype, val_less_than: anytype, comptime OUT: type) OUT {
    assert_with_reason(Types.type_is_pointer_with_child_unsigned_int_type(@TypeOf(rand)), @src(), "type of `rand` must be a pointer to an unsigned integer type, got type `{s}", .{@typeName(@TypeOf(rand))});
    assert_with_reason(Types.type_is_comptime_or_unsigned_int(@TypeOf(val_less_than)), @src(), "type of `val_less_than` must be an unsigned integer type, got type `{s}", .{@typeName(@TypeOf(val_less_than))});
    const r = rand.* % val_less_than;
    rand.* = rand.* / val_less_than;
    return num_cast(r, OUT);
}

pub fn normalized_float_to_int(float: anytype, comptime INT: type) INT {
    const INT_INT = if (INT == bool) u1 else INT;
    const MAX_I: @TypeOf(float) = math.maxInt(INT_INT);
    const MIN_I: @TypeOf(float) = math.minInt(INT_INT);
    const f = clamp(MIN_I, @round(float * MAX_I), MAX_I);
    const i = @as(INT_INT, @intFromFloat(f));
    return if (INT == bool) @bitCast(i) else i;
}
pub fn int_to_normalized_float(int: anytype, comptime FLOAT: type) FLOAT {
    const int_cast = if (@TypeOf(int) == bool) @intFromBool(int) else int;
    const MAX_I: FLOAT = math.maxInt(@TypeOf(int_cast));
    const f: FLOAT = @floatFromInt(int_cast);
    if (Types.type_is_signed_int(@TypeOf(int_cast))) {
        return clamp_neg_1_to_1(f / MAX_I);
    } else {
        return clamp_0_to_1(f / MAX_I);
    }
}
/// Performs a numeric cast with the following conventions:
///   - bools are treated as u1 integers (ether 0 or 1)
///   - int to float converts using `int_val / MAX_POSITIVE_INT_VAL` resulting in range 0.0 to 1.0 for unsigned integers, or -1.0 to 1.0 for signed integers
///   - float to int converts using `round(clamp(-1.0, float_val, 1.0) * MAX_POSITIVE_INT_VAL)`
///     - if the input is negtive and the output cannot be negative, the output is clamped to 0
///   - int to int converts using `(input_int_val / MAX_POSITIVE_INPUT_INT_VAL) * MAX_POSITIVE_OUTPUT_INT_VAL`
///      - if the input is negtive and the output cannot be negative, the output is clamped to 0
///   - float to float simply converts using `@floatCast(input_float_val)` and does not clamp the result between -1.0 and 1.0
pub fn normalized_num_cast(from: anytype, comptime TO: type) TO {
    const FROM = @TypeOf(from);
    const FROM_CAST = if (FROM == bool) u1 else FROM;
    const TO_CAST = if (TO == bool) u1 else TO;
    const from_cast: FROM_CAST = if (FROM == bool) @intFromBool(from) else from;
    const FROM_INT = Types.type_is_int(FROM_CAST);
    const TO_INT = Types.type_is_int(TO_CAST);
    if (!FROM_INT and !TO_INT) {
        return @floatCast(from);
    }
    const FROM_FLOAT_TYPE = if (FROM_INT) Types.FloatSizeForMaxIntExact(FROM_CAST) else FROM_CAST;
    const TO_FLOAT_TYPE = if (TO_INT) Types.FloatSizeForMaxIntExact(TO_CAST) else TO_CAST;
    const ABS_MAX_FROM_FLOAT: FROM_FLOAT_TYPE = if (FROM_INT) math.maxInt(FROM_CAST) else 1.0;
    const from_float: FROM_FLOAT_TYPE = if (FROM_INT) @floatFromInt(from_cast) else from_cast;
    const ABS_MAX_TO_FLOAT: TO_FLOAT_TYPE = if (TO_INT) math.maxInt(TO_CAST) else 1.0;
    const MIN_TO_FLOAT: TO_FLOAT_TYPE = if (TO_INT) math.minInt(TO_CAST) else -1.0;
    const from_ratio = clamp(@as(FROM_FLOAT_TYPE, -1.0), from_float / ABS_MAX_FROM_FLOAT, @as(FROM_FLOAT_TYPE, 1.0));
    const to_float = upgrade_max(MIN_TO_FLOAT, upgrade_multiply(from_ratio, ABS_MAX_TO_FLOAT));
    const to_float_rounded = if (TO_INT) @round(to_float) else to_float;
    return if (TO_INT) (if (TO == bool) @bitCast(@as(u1, @intFromFloat(to_float_rounded))) else @intFromFloat(to_float_rounded)) else @floatCast(to_float);
}

pub fn max_value(comptime T: type) T {
    assert_with_reason(Types.type_is_numeric_not_comptime(T), @src(), "`max_value` cannot be called with non-numeric (or comptime numeric) type `{s}`", .{@typeName(T)});
    if (Types.type_is_int(T)) {
        return math.maxInt(T);
    } else {
        return math.floatMax(T);
    }
}

pub fn min_value(comptime T: type) T {
    assert_with_reason(Types.type_is_numeric_not_comptime(T), @src(), "`min_value` cannot be called with non-numeric (or comptime numeric) type `{s}`", .{@typeName(T)});
    if (Types.type_is_int(T)) {
        return math.minInt(T);
    } else {
        return -math.floatMax(T);
    }
}

const BezierSineCos = struct {
    const A = 1.00005507808;
    const B = 0.55342925736;
    const C = 0.99873327689;
    const F32 = struct {
        const X = [4][4]f32{ .{ A, C, B, 0 }, .{ 0, -B, -C, -A }, .{ -A, -C, -B, 0 }, .{ 0, B, C, A } };
        const Y = [4][4]f32{ .{ 0, B, C, A }, .{ A, C, B, 0 }, .{ 0, -B, -C, -A }, .{ -A, -C, -B, 0 } };
    };
    const F64 = struct {
        const X = [4][4]f64{ .{ A, C, B, 0 }, .{ 0, -B, -C, -A }, .{ -A, -C, -B, 0 }, .{ 0, B, C, A } };
        const Y = [4][4]f64{ .{ 0, B, C, A }, .{ A, C, B, 0 }, .{ 0, -B, -C, -A }, .{ -A, -C, -B, 0 } };
    };
};

pub fn sin_bezier_rad(radians: anytype) @TypeOf(radians) {
    const T = @TypeOf(radians);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(radians / HALF_PI);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = radians - (sector_f * HALF_PI);
            const percent: f32 = rem / HALF_PI;
            const y: [4]f32 = BezierSineCos.F32.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return lerp(y01_12, y12_23, percent);
        },
        f64 => {
            const sector_f: f64 = @floor(radians / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return lerp(y01_12, y12_23, percent);
        },
        else => {
            const radians_f = num_cast(radians, f64);
            const sector_f: f64 = @floor(radians_f / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians_f - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return num_cast(lerp(y01_12, y12_23, percent), T);
        },
    }
}

pub fn cos_bezier_rad(radians: anytype) @TypeOf(radians) {
    const T = @TypeOf(radians);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(radians / HALF_PI);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = radians - (sector_f * HALF_PI);
            const percent: f32 = rem / HALF_PI;
            const x: [4]f32 = BezierSineCos.F32.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return lerp(x01_12, x12_23, percent);
        },
        f64 => {
            const sector_f: f64 = @floor(radians / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return lerp(x01_12, x12_23, percent);
        },
        else => {
            const radians_f = num_cast(radians, f64);
            const sector_f: f64 = @floor(radians_f / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians_f - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return num_cast(lerp(x01_12, x12_23, percent), T);
        },
    }
}

pub fn sin_cos_bezier_rad(radians: anytype) .{ @TypeOf(radians), @TypeOf(radians) } {
    const T = @TypeOf(radians);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(radians / HALF_PI);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = radians - (sector_f * HALF_PI);
            const percent: f32 = rem / HALF_PI;
            const y: [4]f32 = BezierSineCos.F32.Y[sector];
            const x: [4]f32 = BezierSineCos.F32.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const y_final = lerp(y01_12, y12_23, percent);
            const x_final = lerp(x01_12, x12_23, percent);
            return .{ y_final, x_final };
        },
        f64 => {
            const sector_f: f64 = @floor(radians / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const y_final = lerp(y01_12, y12_23, percent);
            const x_final = lerp(x01_12, x12_23, percent);
            return .{ y_final, x_final };
        },
        else => {
            const radians_f = num_cast(radians, f64);
            const sector_f: f64 = @floor(radians_f / HALF_PI);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians_f - (sector_f * HALF_PI);
            const percent: f64 = rem / HALF_PI;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const y_final = lerp(y01_12, y12_23, percent);
            const x_final = lerp(x01_12, x12_23, percent);
            return .{ num_cast(y_final, T), num_cast(x_final, T) };
        },
    }
}

pub fn sin_bezier_deg(degrees: anytype) @TypeOf(degrees) {
    const T = @TypeOf(degrees);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(degrees / 90);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = degrees - (sector_f * 90);
            const percent: f32 = rem / 90;
            const y: [4]f32 = BezierSineCos.F32.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return lerp(y01_12, y12_23, percent);
        },
        f64 => {
            const sector_f: f64 = @floor(degrees / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = degrees - (sector_f * 90);
            const percent: f64 = rem / 90;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return lerp(y01_12, y12_23, percent);
        },
        else => {
            const radians_f = num_cast(degrees, f64);
            const sector_f: f64 = @floor(radians_f / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians_f - (sector_f * 90);
            const percent: f64 = rem / 90;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            return num_cast(lerp(y01_12, y12_23, percent), T);
        },
    }
}

pub fn cos_bezier_deg(degrees: anytype) @TypeOf(degrees) {
    const T = @TypeOf(degrees);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(degrees / 90);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = degrees - (sector_f * 90);
            const percent: f32 = rem / 90;
            const x: [4]f32 = BezierSineCos.F32.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return lerp(x01_12, x12_23, percent);
        },
        f64 => {
            const sector_f: f64 = @floor(degrees / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = degrees - (sector_f * 90);
            const percent: f64 = rem / 90;
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return lerp(x01_12, x12_23, percent);
        },
        else => {
            const radians_f = num_cast(degrees, f64);
            const sector_f: f64 = @floor(radians_f / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = radians_f - (sector_f * 90);
            const percent: f64 = rem / 90;
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            return num_cast(lerp(x01_12, x12_23, percent), T);
        },
    }
}

pub fn sin_cos_bezier_deg(degrees: anytype) .{ @TypeOf(degrees), @TypeOf(degrees) } {
    const T = @TypeOf(degrees);
    switch (T) {
        f32 => {
            const sector_f: f32 = @floor(degrees / 90);
            const sector_i: u32 = @intFromFloat(sector_f);
            const sector: u32 = sector_i & 0b11;
            const rem: f32 = degrees - (sector_f * 90);
            const percent: f32 = rem / 90;
            const y: [4]f32 = BezierSineCos.F32.Y[sector];
            const x: [4]f32 = BezierSineCos.F32.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const sin = lerp(y01_12, y12_23, percent);
            const cos = lerp(x01_12, x12_23, percent);
            return .{ sin, cos };
        },
        f64 => {
            const sector_f: f64 = @floor(degrees / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = degrees - (sector_f * 90);
            const percent: f64 = rem / 90;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const sin = lerp(y01_12, y12_23, percent);
            const cos = lerp(x01_12, x12_23, percent);
            return .{ sin, cos };
        },
        else => {
            const degrees_f = num_cast(degrees, f64);
            const sector_f: f64 = @floor(degrees_f / 90);
            const sector_i: u64 = @intFromFloat(sector_f);
            const sector: u64 = sector_i & 0b11;
            const rem: f64 = degrees_f - (sector_f * 90);
            const percent: f64 = rem / 90;
            const y: [4]f64 = BezierSineCos.F64.Y[sector];
            const x: [4]f64 = BezierSineCos.F64.X[sector];
            const y01 = lerp(y[0], y[1], percent);
            const y12 = lerp(y[1], y[2], percent);
            const y23 = lerp(y[2], y[3], percent);
            const x01 = lerp(x[0], x[1], percent);
            const x12 = lerp(x[1], x[2], percent);
            const x23 = lerp(x[2], x[3], percent);
            const y01_12 = lerp(y01, y12, percent);
            const y12_23 = lerp(y12, y23, percent);
            const x01_12 = lerp(x01, x12, percent);
            const x12_23 = lerp(x12, x23, percent);
            const sin = lerp(y01_12, y12_23, percent);
            const cos = lerp(x01_12, x12_23, percent);
            return .{ num_cast(sin, T), num_cast(cos, T) };
        },
    }
}

/// In the case of `cos == 0`, if the type of `sin` is a float type, returns infinity,
/// if `sin` is an integer type, returns the maximum value of that int, which may
/// not be a good mathematical representation of `tan`, but is better than throwing
/// an error or panicing
pub fn tan_from_sin_cos(sin: anytype, cos: anytype) @TypeOf(sin) {
    if (cos == 0) {
        switch (@typeInfo(@TypeOf(sin))) {
            .float => return math.inf(@TypeOf(sin)),
            .comptime_float => return @floatCast(math.inf(f64)),
            .int => return math.maxInt(@TypeOf(sin)),
            .comptime_int => return @intCast(math.maxInt(u64)),
            else => assert_unreachable(@src(), "type of `sin` was not a numeric type, got type `{s}`", .{@typeName(@TypeOf(sin))}),
        }
    }
    const sin_f = upgrade_to_float(sin, f64);
    const cos_f = upgrade_to_float(cos, f64);
    return upgrade_divide_out(sin_f, cos_f, @TypeOf(sin));
}

/// In the case of `cos(radians) == 0`, if the type of `radians` is a float type, returns infinity,
/// if `sin` is an integer type, returns the maximum value of that int, which may
/// not be a good mathematical representation of `tan`, but is better than throwing
/// an error or panicing
pub fn tan_bezier_rad(radians: anytype) @TypeOf(radians) {
    const sin, const cos = sin_cos_bezier_rad(radians);
    return tan_from_sin_cos(sin, cos);
}
/// In the case of `cos(degrees) == 0`, if the type of `degrees` is a float type, returns infinity,
/// if `sin` is an integer type, returns the maximum value of that int, which may
/// not be a good mathematical representation of `tan`, but is better than throwing
/// an error or panicing
pub fn tan_bezier_deg(degrees: anytype) @TypeOf(degrees) {
    const sin, const cos = sin_cos_bezier_deg(degrees);
    return tan_from_sin_cos(sin, cos);
}

pub const PowerOf2 = enum(u8) {
    _1 = 0,
    _2 = 1,
    _4 = 2,
    _8 = 3,
    _16 = 4,
    _32 = 5,
    _64 = 6,
    _128 = 7,
    _256 = 8,
    _512 = 9,
    _1_024 = 10,
    _2_048 = 11,
    _4_096 = 12,
    _8_192 = 13,
    _16_384 = 14,
    _32_768 = 15,
    _65_536 = 16,
    _131_072 = 17,
    _262_144 = 18,
    _524_288 = 19,
    _1_048_576 = 20,
    _2_097_152 = 21,
    _4_194_304 = 22,
    _8_388_608 = 23,
    _16_777_216 = 24,
    _33_554_432 = 25,
    _67_108_864 = 26,
    _134_217_728 = 27,
    _268_435_456 = 28,
    _536_870_912 = 29,
    _1_073_741_824 = 30,
    _2_147_483_648 = 31,
    _4_294_967_296 = 32,
    _8_589_934_592 = 33,
    _17_179_869_184 = 34,
    _34_359_738_368 = 35,
    _68_719_476_736 = 36,
    _137_438_953_472 = 37,
    _274_877_906_944 = 38,
    _549_755_813_888 = 39,
    _1_099_511_627_776 = 40,
    _2_199_023_255_552 = 41,
    _4_398_046_511_104 = 42,
    _8_796_093_022_208 = 43,
    _17_592_186_044_416 = 44,
    _35_184_372_088_832 = 45,
    _70_368_744_177_664 = 46,
    _140_737_488_355_328 = 47,
    _281_474_976_710_656 = 48,
    _562_949_953_421_312 = 49,
    _1_125_899_906_842_624 = 50,
    _2_251_799_813_685_248 = 51,
    _4_503_599_627_370_496 = 52,
    _9_007_199_254_740_992 = 53,
    _18_014_398_509_481_984 = 54,
    _36_028_797_018_963_968 = 55,
    _72_057_594_037_927_936 = 56,
    _144_115_188_075_855_872 = 57,
    _288_230_376_151_711_744 = 58,
    _576_460_752_303_423_488 = 59,
    _1_152_921_504_606_846_976 = 60,
    _2_305_843_009_213_693_952 = 61,
    _4_611_686_018_427_387_904 = 62,
    _9_223_372_036_854_775_808 = 63,
    _18_446_744_073_709_551_616 = 64,
    _,

    pub fn num_bits(power: PowerOf2) u8 {
        return @intFromEnum(power) + 1;
    }

    pub fn bit_shift(power: PowerOf2) u8 {
        return @intFromEnum(power);
    }

    pub fn unsigned_integer_type_that_holds_all_values_less_than(comptime limit: PowerOf2) type {
        return std.meta.Int(.unsigned, @intCast(@intFromEnum(limit)));
    }
    pub fn unsigned_integer_type_that_holds_all_values_up_to_and_including(comptime power: PowerOf2) type {
        return std.meta.Int(.unsigned, @intCast(@intFromEnum(power) + 1));
    }
    pub fn signed_integer_type_that_holds_all_values_less_than(comptime limit: PowerOf2) type {
        return std.meta.Int(.signed, @intCast(@intFromEnum(limit) + 1));
    }
    pub fn signed_integer_type_that_holds_all_values_up_to_and_including(comptime power: PowerOf2) type {
        return std.meta.Int(.signed, @intCast(@intFromEnum(power) + 2));
    }
    pub fn composite_unsigned_integer_type_that_holds_unsigned_integer_types_with_values_less_than(comptime limits: []const PowerOf2) type {
        comptime var total_limit: u16 = 0;
        inline for (limits) |lim| {
            total_limit += @as(u16, @intCast(@intFromEnum(lim)));
        }
        return std.meta.Int(.unsigned, total_limit);
    }

    pub fn alignment(int_or_ptr: anytype) PowerOf2 {
        const T = @TypeOf(int_or_ptr);
        const INFO = @typeInfo(T);
        switch (INFO) {
            .int => {
                const i = @abs(int_or_ptr);
                const tz = @ctz(i);
                return @enumFromInt(tz);
            },
            .@"enum" => {
                const i = @abs(@intFromEnum(int_or_ptr));
                const tz = @ctz(i);
                return @enumFromInt(tz);
            },
            .pointer => {
                const i = @intFromPtr(int_or_ptr);
                const tz = @ctz(i);
                return @enumFromInt(tz);
            },
            else => assert_unreachable(@src(), "type `{s}` not a valid input type", .{@typeName(T)}),
        }
    }
    pub inline fn at_least_aligned_to(int_or_ptr: anytype, min_align: PowerOf2) bool {
        return min_align.value_is_aligned_at_least(int_or_ptr);
    }
    pub fn value_is_aligned_at_least(self: PowerOf2, int_or_ptr: anytype) bool {
        const val_align = alignment(int_or_ptr);
        return @intFromEnum(val_align) >= @intFromEnum(self);
    }
    pub inline fn exactly_aligned_to(int_or_ptr: anytype, min_align: PowerOf2) bool {
        return min_align.value_is_aligned_exactly(int_or_ptr);
    }
    pub fn value_is_aligned_exactly(self: PowerOf2, int_or_ptr: anytype) bool {
        const val_align = alignment(int_or_ptr);
        return @intFromEnum(val_align) == @intFromEnum(self);
    }
    pub fn power_of_2(n: anytype) PowerOf2 {
        const T = @TypeOf(n);
        const INFO = @typeInfo(T);
        const i: u8 = switch (INFO) {
            .int => @intCast(@abs(n)),
            .@"enum" => @intCast(@abs(@intFromEnum(n))),
            else => assert_unreachable(@src(), "type `{s}` not a valid input type", .{@typeName(T)}),
        };
        return @enumFromInt(i);
    }
    pub fn value(self: PowerOf2) u64 {
        @as(u64, 1) << @intCast(@intFromEnum(self));
    }
    pub fn value_as_type(self: PowerOf2, comptime INT: type) INT {
        @as(INT, 1) << @intCast(@intFromEnum(self));
    }
    pub fn value_large(comptime self: PowerOf2) ValueLarge(self) {
        const INT = ValueLarge(self);
        return @as(INT, 1) << @intCast(@intFromEnum(self));
    }
    pub fn ValueLarge(comptime self: PowerOf2) type {
        const bits: u16 = @as(u16, @intCast(@intFromEnum(self))) + 1;
        return std.meta.Int(.unsigned, bits);
    }
    pub fn round_up_to_power_of_2(int_or_ptr: anytype) PowerOf2 {
        const T = @TypeOf(int_or_ptr);
        const INFO = @typeInfo(T);
        var i = switch (INFO) {
            .int => @abs(int_or_ptr),
            .@"enum" => @abs(@intFromEnum(int_or_ptr)),
            .pointer => @intFromPtr(int_or_ptr),
            else => assert_unreachable(@src(), "type `{s}` not a valid input type", .{@typeName(T)}),
        };
        const BITS = @typeInfo(@TypeOf(i)).int.bits;
        i = i -% 1;
        if (comptime BITS > 1) i |= i >> 1;
        if (comptime BITS > 2) i |= i >> 2;
        if (comptime BITS > 4) i |= i >> 4;
        if (comptime BITS > 8) i |= i >> 8;
        if (comptime BITS > 16) i |= i >> 16;
        if (comptime BITS > 32) i |= i >> 32;
        if (comptime BITS > 64) i |= i >> 64;
        if (comptime BITS > 128) i |= i >> 128;
        if (comptime BITS > 256) assert_unreachable(@src(), "integers with bit lengths greater than 256 are not supported, got bit width {d}", .{BITS});
        i = i +% 1;
        return @enumFromInt(@ctz(i));
    }

    pub fn round_up_to_power_of_2_value_type(int_or_ptr: anytype) @TypeOf(int_or_ptr) {
        const T = @TypeOf(int_or_ptr);
        const INFO = @typeInfo(T);
        const pow = round_up_to_power_of_2(int_or_ptr);
        switch (INFO) {
            .int => return @as(T, 1) << @intCast(@intFromEnum(pow)),
            .@"enum" => return @enumFromInt(@as(Types.enum_tag_type(T), 1) << @intCast(@intFromEnum(pow))),
            .pointer => return @ptrFromInt(@as(usize, 1) << @intCast(@intFromEnum(pow))),
        }
    }

    pub fn round_down_to_power_of_2(int_or_ptr: anytype) PowerOf2 {
        const pow = round_up_to_power_of_2(int_or_ptr);
        const lower = @intFromEnum(pow) - 1;
        return @intFromEnum(lower);
    }

    pub fn round_down_to_power_of_2_value_type(int_or_ptr: anytype) @TypeOf(int_or_ptr) {
        const T = @TypeOf(int_or_ptr);
        const INFO = @typeInfo(T);
        const pow = round_down_to_power_of_2(int_or_ptr);
        switch (INFO) {
            .int => return @as(T, 1) << @intCast(@intFromEnum(pow)),
            .@"enum" => return @enumFromInt(@as(Types.enum_tag_type(T), 1) << @intCast(@intFromEnum(pow))),
            .pointer => return @ptrFromInt(@as(usize, 1) << @intCast(@intFromEnum(pow))),
        }
    }
};
