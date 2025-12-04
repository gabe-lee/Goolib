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
const assert_with_reason = Assert.assert_with_reason;

const Math = @This();

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
pub fn clamp(comptime T: type, min: T, val: T, max: T) T {
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
pub fn sign_nonzero(comptime T: type, val: T) T {
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

pub fn define_math_package(comptime T: type) type {
    return struct {
        pub inline fn deg_to_rad(degrees: T) T {
            return Math.deg_to_rad(T, degrees);
        }

        pub inline fn rad_to_deg(radians: T) T {
            return Math.rad_to_deg(T, radians);
        }

        pub inline fn lerp(a: T, b: T, delta: T) T {
            return Math.lerp(T, a, b, delta);
        }

        pub inline fn add_scale(a: T, diff_ba: T, delta: T) T {
            return Math.add_scale(T, a, diff_ba, delta);
        }

        pub inline fn lerp_delta_min_max(a: T, b: T, min_delta: T, max_delta: T, delta: T) T {
            return Math.lerp_delta_min_max(T, a, b, min_delta, max_delta, delta);
        }

        pub inline fn lerp_delta_max(a: T, b: T, max_delta: T, delta: T) T {
            return Math.lerp_delta_max(T, a, b, max_delta, delta);
        }

        pub inline fn scaled_delta(delta: T, delta_add: T, delta_ratio: T) T {
            return Math.scaled_delta(T, delta, delta_add, delta_ratio);
        }

        pub inline fn approx_less_than_or_equal_to(a: T, b: T) bool {
            return Math.approx_greater_than_or_equal_to(T, a, b);
        }

        pub inline fn approx_less_than(a: T, b: T) bool {
            return Math.approx_less_than(T, a, b);
        }

        pub inline fn approx_greater_than_or_equal_to(a: T, b: T) bool {
            return Math.approx_greater_than_or_equal_to(T, a, b);
        }

        pub inline fn approx_greater_than(a: T, b: T) bool {
            return Math.approx_greater_than(T, a, b);
        }

        pub inline fn approx_equal(a: T, b: T) bool {
            return Math.approx_equal(T, a, b);
        }

        pub inline fn change_per_second_required_to_reach_val_at_time(current: T, target: T, time: T) T {
            return Math.change_per_second_required_to_reach_val_at_time(T, current, target, time);
        }

        pub inline fn change_per_second_required_to_reach_val_qt_inverse_time(current: T, target: T, inverse_time: T) T {
            return Math.change_per_second_required_to_reach_val_at_inverse_time(T, current, target, inverse_time);
        }
    };
}
