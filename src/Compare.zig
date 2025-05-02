const std = @import("std");
const Type = std.builtin.Type;

pub fn a_equals_b(comptime T: type, a: *const T, b: *const T, order_func: *const fn (a: *const T, b: *const T) Order) bool {
    return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_EQUALS_B);
}
pub fn a_less_than_b(comptime T: type, a: *const T, b: *const T, order_func: *const fn (a: *const T, b: *const T) Order) bool {
    return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_LESS_THAN_B);
}
pub fn a_less_than_or_equal_to_b(comptime T: type, a: *const T, b: *const T, order_func: *const fn (a: *const T, b: *const T) Order) bool {
    return @intFromEnum(order_func(a, b)) <= @intFromEnum(Order.A_EQUALS_B);
}
pub fn a_greater_than_b(comptime T: type, a: *const T, b: *const T, order_func: *const fn (a: *const T, b: *const T) Order) bool {
    return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_GREATER_THAN_B);
}
pub fn a_greater_than_or_equal_to_b(comptime T: type, a: *const T, b: *const T, order_func: *const fn (a: *const T, b: *const T) Order) bool {
    return @intFromEnum(order_func(a, b)) >= @intFromEnum(Order.A_EQUALS_B);
}

pub fn type_package(comptime T: type, order_func: *const fn (a: *const T, b: *const T) Order) type {
    return struct {
        pub fn a_equals_b(a: *const T, b: *const T) bool {
            return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_EQUALS_B);
        }
        pub fn a_less_than_b(a: *const T, b: *const T) bool {
            return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_LESS_THAN_B);
        }
        pub fn a_less_than_or_equal_to_b(a: *const T, b: *const T) bool {
            return @intFromEnum(order_func(a, b)) <= @intFromEnum(Order.A_EQUALS_B);
        }
        pub fn a_greater_than_b(a: *const T, b: *const T) bool {
            return @intFromEnum(order_func(a, b)) == @intFromEnum(Order.A_GREATER_THAN_B);
        }
        pub fn a_greater_than_or_equal_to_b(a: *const T, b: *const T) bool {
            return @intFromEnum(order_func(a, b)) >= @intFromEnum(Order.A_EQUALS_B);
        }
    };
}

pub fn numeric_order_else_always_equal(comptime T: type) *const fn (a: *const T, b: *const T) Order {
    const container = comptime switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => struct {
            fn func(a: *const T, b: *const T) Order {
                var val: i8 = @intCast(@intFromBool(a > b));
                val -= @intCast(@intFromBool(a < b));
                return @enumFromInt(val);
            }
        },
        else => struct {
            fn func(a: *const T, b: *const T) Order {
                _ = a;
                _ = b;
                return Order.A_EQUALS_B;
            }
        },
    };
    return container.func;
}

// pub fn order_always_equal(comptime T: type) type {
//     return struct {
//         fn func(a: *const T, b: *const T) Order {
//             _ = a;
//             _ = b;
//             return Order.A_EQUALS_B;
//         }
//     };
// }

// pub fn order_intrinsic(comptime T: type) type {
//     switch (@typeInfo(T)) {
//         .int, .float, .comptime_int, .comptime_float => {},
//         else => @compileError("can only use intrinsic ordering for integer and float types"),
//     }
//     return struct {
//         fn func(a: *const T, b: *const T) Order {
//             var val: i8 = @intCast(@intFromBool(a > b));
//             val -= @intCast(@intFromBool(a < b));
//             return @enumFromInt(val);
//         }
//     };
// }

// pub fn order_intrinsic_vector(comptime LEN: comptime_int, comptime T: type) type {
//     switch (@typeInfo(T)) {
//         .int, .float, .comptime_int, .comptime_float => {},
//         else => @compileError("can only use vector intrinsic ordering for integer and float base types"),
//     }
//     return struct {
//         fn func(a: *const @Vector(LEN, T), b: *const @Vector(LEN, T)) @Vector(LEN, Order) {
//             const a_greater: @Vector(LEN, i8) = @bitCast(a.* > b.*);
//             const a_lesser: @Vector(LEN, i8) = @bitCast(a.* < b.*);
//             const result: @Vector(LEN, i8) = a_greater - a_lesser;
//             return @bitCast(result);
//         }
//     };
// }

pub const Order = enum(i8) {
    A_LESS_THAN_B = -1,
    A_EQUALS_B = 0,
    A_GREATER_THAN_B = 1,
};
