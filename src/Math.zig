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
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Vec2 = Root.Vec2;
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

pub fn lerp(comptime T: type, a: T, b: T, delta: T) T {
    return ((b - a) * delta) + a;
}

pub fn weighted_average(comptime T: type, a: T, b: T, b_weight: anytype) T {
    const F = @TypeOf(b_weight);
    assert_with_reason(Types.type_is_float(F), @src(), "the type of `b_weight` must be a float type, got type `{s}`", .{@typeName(F)});
    if (Types.type_is_float(T)) {
        return @floatCast(((@as(F, 1.0) - b_weight) * @as(F, @floatCast(a))) + (@as(F, @floatCast(b)) * b_weight));
    } else {
        return @intFromFloat(((@as(F, 1.0) - b_weight) * @as(F, @floatFromInt(a))) + (@as(F, @floatFromInt(b)) * b_weight));
    }
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

pub fn change_per_second_required_to_reach_val_at_time(comptime T: type, current: T, target: T, time: T) T {
    return (target - current) * (1.0 / time);
}

pub fn change_per_second_required_to_reach_val_at_inverse_time(comptime T: type, current: T, target: T, inverse_time: T) T {
    return (target - current) * inverse_time;
}

pub fn ScanlineIntersections(comptime MAX: comptime_int, comptime T: type) type {
    return struct {
        const Self = @This();
        const Point = Vec2.define_vec2_type(T);

        intersections: [MAX]Point,
        intersection_counts: u32,
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

        solution_x_vals: [N]T = @splat(0),
        num_solutions: u32 = 0,
        solutions_mode: SolutionCountMode = .no_solutions,

        pub fn change_polynimial_degree(self: Self, comptime NN: comptime_int) PolynomialSolution(NN, T) {
            var new_solution = PolynomialSolution(NN, T){};
            @memcpy(new_solution.solution_x_vals[0..self.num_solutions], self.solution_x_vals[0..self.num_solutions]);
            new_solution.num_solutions = self.num_solutions;
            new_solution.solutions_mode = self.solutions_mode;
            return new_solution;
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
            result.solutions_mode = .infinite_solutions;
        } else {
            // horizontal line with y != 0
            result.solutions_mode = .no_solutions;
        }
        return result;
    }
    result.solution_deltas[0] = -(b / a);
    result.num_solutions = 1;
    result.solutions_mode = .finite_solutions;
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
        result.num_solutions = 2;
        result.solutions_mode = .finite_solutions;
    } else if (descriminant == 0) {
        const a2 = 2 * a;
        result.solution_x_vals[0] = -(b / a2);
        result.num_solutions = 1;
        result.solutions_mode = .finite_solutions;
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
        result.solution_x_vals[0] = (q * @cos(t / 3)) - third_a;
        result.solution_x_vals[1] = (q * @cos((t + TAU) / 3)) - third_a;
        result.solution_x_vals[3] = (q * @cos((t - TAU) / 3)) - third_a;
        result.num_solutions = 3;
        result.solutions_mode = .finite_solutions;
        return result;
    } else {
        const s: T = if (r < 0) 1 else -1;
        const u = s * math.pow(T, @abs(r) + @sqrt(r_squared - q_cubed), @as(T, 1) / @as(T, 3));
        const v = if (u == 0) 0 else (q / u);
        result.solution_x_vals[0] = (u + v) - third_a;
        result.solutions_mode = .finite_solutions;
        if (u == v or check_estimate: {
            switch (double_root_estimate) {
                .exact => break :check_estimate false,
                .estimate => |ratio| {
                    break :check_estimate @abs(u - v) / @abs(u + v) < ratio;
                },
            }
        }) {
            result.solution_x_vals[1] = (-(u + v) / 2) - third_a;
            result.num_solutions = 2;
        } else {
            result.num_solutions = 1;
        }
        return result;
    }
}
