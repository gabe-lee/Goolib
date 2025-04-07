const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

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
