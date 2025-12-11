//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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

const Math = @This();

pub const PI = math.pi;
pub const TAU = math.tau;

pub fn deg_to_rad(comptime T: type, degrees: T) T {
    return degrees * math.rad_per_deg;
}

pub fn rad_to_deg(comptime T: type, radians: T) T {
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
    const T = @FieldType(nums, "a");
    if (Types.type_is_float(T)) {
        return @mulAdd(T, delta, b, @mulAdd(T, -delta, a, a));
    } else {
        return ((1 - delta) * a) + (delta * b);
    }
}
pub fn upgrade_lerp_out(a: anytype, b: anytype, delta: anytype, comptime OUT: type) OUT {
    const nums = upgrade_3_numbers_for_math(a, b, delta);
    const T = @FieldType(nums, "a");
    const out: T = if (Types.type_is_float(T))
        (@mulAdd(T, delta, b, @mulAdd(T, -delta, a, a)))
    else
        (((1 - delta) * a) + (delta * b));
    return convert_number(out, OUT);
}

pub fn log_x_base(x: anytype, base: anytype) @TypeOf(x) {
    return @log2(x) / @log2(base);
}

pub fn median_of_3(comptime T: type, a: T, b: T, c: T) T {
    return @max(@min(a, b), @min(@max(a, b), c));
}

pub fn clamp_0_to_1(comptime T: type, val: T) T {
    if (val >= 0 and val <= 1) {
        return val;
    } else if (val < 0) {
        return 0;
    } else return 1;
}
pub fn clamp_0_to_max(comptime T: type, val: T, max: T) T {
    if (val >= 0 and val <= max) {
        return val;
    } else if (val < 0) {
        return 0;
    } else return max;
}
pub fn clamp(min: anytype, val: anytype, max: anytype) @TypeOf(val) {
    if (val >= min and val <= max) {
        return val;
    } else if (val < min) {
        return min;
    } else return max;
}
/// returns:
///   - -1 if val < 0
///   - 0 if val == 0
///   - 1 if val > 0
pub fn sign(comptime T: type, val: T) T {
    const raw = @as(i8, @intCast(@intFromBool(0 < val))) - @as(i8, @intCast(@intFromBool(val < 0)));
    if (Types.type_is_float(T)) {
        return @floatFromInt(raw);
    } else {
        return @intCast(raw);
    }
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
    const a_min: T = a - math.floatEpsAt(T, a);
    const a_max: T = a + math.floatEpsAt(T, a);
    const b_min: T = b - math.floatEpsAt(T, b);
    const b_max: T = b + math.floatEpsAt(T, b);
    return a_max >= b_min and b_max >= a_min;
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
    type_b: type,
};

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
    const mode_and_types = upgrade_mode_and_types(A, B);
    const T_: type = switch (mode_and_types.mode) {
        .same_class_ints_B_large, .both_float_B_large, .upgrade_A_to_float => mode_and_types.type_B,
        .same_class_ints_A_large, .both_float_A_large, .upgrade_B_to_float => mode_and_types.type_A,
        .mixed_class_ints => largest_int_type_for_math(mode_and_types.type_A, mode_and_types.type_B, 64),
    };
    return struct {
        pub const T: type = T_;
        a: T = 0,
        b: T = 0,
    };
}

pub fn upgrade_2_numbers_for_math(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const MODE = upgrade_mode_and_types(A, B);
    var result = Upgraded2Numbers(A, B){};
    switch (MODE) {
        .both_float_A_large => {
            result.a = a;
            result.b = @floatCast(b);
        },
        .both_float_B_large => {
            result.a = @floatCast(a);
            result.b = b;
        },
        .same_class_ints_A_large => {
            result.a = a;
            result.b = @intCast(b);
        },
        .same_class_ints_B_large => {
            result.a = @intCast(a);
            result.b = b;
        },
        .mixed_class_ints => {
            result.a = @intCast(a);
            result.b = @intCast(b);
        },
        .upgrade_A_to_float => {
            result.a = @floatFromInt(a);
            result.b = b;
        },
        .upgrade_B_to_float => {
            result.a = a;
            result.b = @floatFromInt(b);
        },
    }
    return result;
}

pub fn Upgraded3Numbers(comptime A: type, comptime B: type, comptime C: type) type {
    const AB = Upgraded2Numbers(A, B);
    const ABC = Upgraded2Numbers(AB.T, C);
    return struct {
        pub const T: type = ABC.T;
        a: T = 0,
        b: T = 0,
        c: T = 0,
    };
}

pub fn upgrade_3_numbers_for_math(a: anytype, b: anytype, c: anytype) Upgraded3Numbers(@TypeOf(a), @TypeOf(b), @TypeOf(c)) {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const C = @TypeOf(c);
    const RESULT = Upgraded3Numbers(A, B, C);
    var result = RESULT{};
    result.a = convert_number(a, RESULT.T);
    result.b = convert_number(b, RESULT.T);
    result.c = convert_number(c, RESULT.T);
    return result;
}

pub fn conversion_mode(comptime IN: type, comptime OUT: type) NumberConversionMode {
    assert_with_reason(Types.type_is_numeric(IN), @src(), "type `IN` must be a numeric type, got type `{s}`", .{@typeName(IN)});
    assert_with_reason(Types.type_is_numeric(OUT), @src(), "type `OUT` must be a numeric type, got type `{s}`", .{@typeName(OUT)});
    if (Types.type_is_int(IN) and Types.type_is_int(OUT)) {
        return .int_to_int;
    } else if (Types.type_is_int(IN) and Types.type_is_float(OUT)) {
        return .int_to_float;
    } else if (Types.type_is_float(IN) and Types.type_is_float(OUT)) {
        return .float_to_float;
    } else {
        return .float_to_int;
    }
}

pub fn convert_number(in: anytype, comptime OUT: type) OUT {
    switch (conversion_mode(@TypeOf(in), OUT)) {
        .int_to_int => return @intCast(in),
        .float_to_float => return @floatCast(in),
        .int_to_float => return @floatFromInt(in),
        .float_to_int => return @intFromFloat(in),
    }
}

pub fn upgrade_add_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a + nums.b;
    convert_number(c, OUT);
}
pub fn upgrade_add(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a + nums.b;
}
pub fn upgrade_subtract_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a - nums.b;
    convert_number(c, OUT);
}
pub fn upgrade_subtract(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a - nums.b;
}
pub fn upgrade_multiply_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a * nums.b;
    convert_number(c, OUT);
}
pub fn upgrade_multiply(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a * nums.b;
}
pub fn upgrade_divide_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = nums.a / nums.b;
    convert_number(c, OUT);
}
pub fn upgrade_divide(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return nums.a / nums.b;
}
pub fn upgrade_power_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const C = @FieldType(nums, "a");
    const c = math.pow(C, nums.a, nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_power(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return math.pow(@FieldType(nums, "a"), nums.a, nums.b);
}
pub fn upgrade_root_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const C = @FieldType(nums, "a");
    const c = math.pow(C, nums.a, 1 / nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_root(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return math.pow(@FieldType(nums, "a"), nums.a, 1 / nums.b);
}
pub fn upgrade_log_x_base_out(x: anytype, base: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(x, base);
    const c = log_x_base(nums.a, nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_log_x_base(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return log_x_base(nums.a, nums.b);
}
pub fn upgrade_modulo_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @mod(nums.a, nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_modulo(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @mod(nums.a, nums.b);
}
pub fn upgrade_max_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @max(nums.a, nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_max(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @max(nums.a, nums.b);
}
pub fn upgrade_min_out(a: anytype, b: anytype, comptime OUT: type) OUT {
    const nums = upgrade_2_numbers_for_math(a, b);
    const c = @min(nums.a, nums.b);
    convert_number(c, OUT);
}
pub fn upgrade_min(a: anytype, b: anytype) Upgraded2Numbers(@TypeOf(a), @TypeOf(b)).T {
    const nums = upgrade_2_numbers_for_math(a, b);
    return @min(nums.a, nums.b);
}

pub fn change_per_unit_time_required_to_reach_val_at_time(comptime T: type, current: T, target: T, time: T) T {
    return (target - current) * (1.0 / time);
}

pub fn change_per_unit_time_required_to_reach_val_at_inverse_time(comptime T: type, current: T, target: T, inverse_time: T) T {
    return (target - current) * inverse_time;
}

pub fn ScanlineIntersections(comptime MAX: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        const Point = Vec2.define_vec2_type(T);

        points: [MAX]Point = @splat(.{}),
        slopes: [MAX]T = @splat(0),
        count: u32 = 0,

        pub fn change_max_intersections(self: Self, comptime NEW_MAX: comptime_int) ScanlineIntersections(NEW_MAX, T) {
            var new_scanlines = ScanlineIntersections(NEW_MAX, T){};
            new_scanlines.count = self.count;
            @memcpy(new_scanlines.points[0..self.count], self.points[0..self.count]);
            @memcpy(new_scanlines.slopes[0..self.count], self.slopes[0..self.count]);
            return new_scanlines;
        }
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

        pub inline fn equals(a: Self, b: Self) bool {
            return @abs(a.distance) == @abs(b.distance);
        }
        pub inline fn less_than(a: Self, b: Self) bool {
            return @abs(a.distance) < @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot < b.dot);
        }
        pub inline fn less_than_or_equal(a: Self, b: Self) bool {
            return @abs(a.distance) <= @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot <= b.dot);
        }
        pub inline fn greater_than(a: Self, b: Self) bool {
            return @abs(a.distance) > @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot > b.dot);
        }
        pub inline fn greater_than_or_equal(a: Self, b: Self) bool {
            return @abs(a.distance) >= @abs(b.distance) or (@abs(a.distance) == @abs(b.distance) and a.dot >= b.dot);
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
        raito: T,

        pub fn do_not_estimate_linear() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_linear_when_linear_coeff_more_than_N_times_quadratic(N: T) Self {
            return Self{ .raito = N };
        }
    };
}

pub fn QuadraticEstimate(comptime T: type) type {
    return union(EstimateMode) {
        const Self = @This();

        exact: void,
        raito: T,

        pub fn do_not_estimate_quadratic() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(N: T) Self {
            return Self{ .raito = N };
        }
    };
}

pub fn DoubleRootEstimate(comptime T: type) type {
    return union(EstimateMode) {
        const Self = @This();

        exact: void,
        raito: T,

        pub fn do_not_estimate_double_roots() Self {
            return Self{ .exact = void{} };
        }
        pub fn estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(N: T) Self {
            return Self{ .raito = N };
        }
    };
}

// polynomial form: a(x) + b
pub fn solve_linear_polynomial_for_zero(a: anytype, b: @TypeOf(a)) LinearSolution(@TypeOf(a)) {
    const result = LinearSolution(@TypeOf(a)){};
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
    result.solution_deltas[0] = -(b / a);
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
pub fn solve_quadratic_polynomial_for_zeros_advanced(a: anytype, b: @TypeOf(a), c: @TypeOf(a), comptime linear_estimate: LinearEstimate(@TypeOf(a))) QuadraticSolution(@TypeOf(a)) {
    // if a == 0 (or b is greater than a by many orders of magnitude and linear estimates are enabled), its linear
    if (a == 0 or check_estimate: {
        switch (linear_estimate) {
            .exact => break :check_estimate false,
            .raito => |ratio| {
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
        result.solution_deltas[0] = (-b + sqrt_descriminant) / a2;
        result.solution_deltas[1] = (-b - sqrt_descriminant) / a2;
        result.count = 2;
        result.mode = .finite_solutions;
    } else if (descriminant == 0) {
        const a2 = 2 * a;
        result.vals[0] = -(b / a2);
        result.count = 1;
        result.mode = .finite_solutions;
    } else {
        return result;
    }
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) QuadraticSolution(@TypeOf(a)) {
    return solve_cubic_polynomial_for_zeros_advanced(a, b, c, d, .do_not_estimate_double_roots(), .do_not_estimate_quadratic(), .do_not_estimate_linear());
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros_estimate(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a)) QuadraticSolution(@TypeOf(a)) {
    return solve_cubic_polynomial_for_zeros_advanced(a, b, c, d, .estimate_double_roots_when_u_minus_v_less_than_N_times_u_plus_v(1e-12), .estimate_quadratic_when_quadratic_coeff_more_than_N_times_cubic(1e6), .estimate_linear_when_linear_coeff_more_than_N_times_quadratic(1e12));
}

// polynomial form: a(x^3) + b(x^2) + c(x) + d
pub fn solve_cubic_polynomial_for_zeros_advanced(a: anytype, b: @TypeOf(a), c: @TypeOf(a), d: @TypeOf(a), comptime double_root_estimate: DoubleRootEstimate(@TypeOf(a)), comptime quadratic_estimate: QuadraticEstimate(@TypeOf(a)), comptime linear_estimate: LinearEstimate(@TypeOf(a))) QuadraticSolution(@TypeOf(a)) {
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
        clamp(-1, t, 1);
        t = math.acos(t);
        q = @sqrt(q) * -2;
        result.vals[0] = (q * @cos(t / 3)) - third_a;
        result.vals[1] = (q * @cos((t + TAU) / 3)) - third_a;
        result.vals[3] = (q * @cos((t - TAU) / 3)) - third_a;
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
