const std = @import("std");
const Type = std.builtin.Type;
const meta = std.meta;
const mem = std.mem;

pub fn CompareFn(comptime T: type) type {
    return *const fn (a: *const T, b: *const T) Order;
}

pub fn MatchFn(comptime T: type) type {
    return *const fn (a: *const T, b: *const T) bool;
}

pub fn a_equals_b(comptime T: type, a: *const T, b: *const T, compare_fn: CompareFn(T)) bool {
    return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_EQUALS_B);
}
pub fn a_less_than_b(comptime T: type, a: *const T, b: *const T, compare_fn: CompareFn(T)) bool {
    return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_LESS_THAN_B);
}
pub fn a_less_than_or_equal_to_b(comptime T: type, a: *const T, b: *const T, compare_fn: CompareFn(T)) bool {
    return @intFromEnum(compare_fn(a, b)) <= @intFromEnum(Order.A_EQUALS_B);
}
pub fn a_greater_than_b(comptime T: type, a: *const T, b: *const T, compare_fn: CompareFn(T)) bool {
    return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_GREATER_THAN_B);
}
pub fn a_greater_than_or_equal_to_b(comptime T: type, a: *const T, b: *const T, compare_fn: CompareFn(T)) bool {
    return @intFromEnum(compare_fn(a, b)) >= @intFromEnum(Order.A_EQUALS_B);
}
pub fn a_deep_equals_b(comptime T: type, a: *const T, b: *const T, equal_fn: MatchFn(T)) bool {
    if (@intFromPtr(a) == @intFromPtr(b)) return true;
    return equal_fn(a, b);
}

pub fn type_compare_package(comptime T: type, comptime compare_fn: CompareFn(T)) type {
    return struct {
        pub fn a_equals_b(a: *const T, b: *const T) bool {
            return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_EQUALS_B);
        }
        pub fn a_less_than_b(a: *const T, b: *const T) bool {
            return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_LESS_THAN_B);
        }
        pub fn a_less_than_or_equal_to_b(a: *const T, b: *const T) bool {
            return @intFromEnum(compare_fn(a, b)) <= @intFromEnum(Order.A_EQUALS_B);
        }
        pub fn a_greater_than_b(a: *const T, b: *const T) bool {
            return @intFromEnum(compare_fn(a, b)) == @intFromEnum(Order.A_GREATER_THAN_B);
        }
        pub fn a_greater_than_or_equal_to_b(a: *const T, b: *const T) bool {
            return @intFromEnum(compare_fn(a, b)) >= @intFromEnum(Order.A_EQUALS_B);
        }
    };
}

pub fn type_deep_equals_package(comptime T: type, comptime equal_fn: MatchFn(T)) type {
    return struct {
        pub fn a_deep_equals_b(a: *const T, b: *const T) bool {
            if (@intFromPtr(a) == @intFromPtr(b)) return true;
            return equal_fn(a, b);
        }
    };
}

pub fn numeric_order_else_always_equal(comptime T: type) CompareFn(T) {
    const container = comptime switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => struct {
            fn func(a: *const T, b: *const T) Order {
                var val: i8 = @intCast(@intFromBool(a.* > b.*));
                val -= @intCast(@intFromBool(a.* < b.*));
                return @enumFromInt(val);
            }
        },
        .pointer => |info| struct {
            fn func(a: *const T, b: *const T) Order {
                const addr_a = switch (info.size) {
                    .c, .one, .many => @intFromPtr(a.*),
                    .slice => @intFromPtr(a.ptr),
                };
                const addr_b = switch (info.size) {
                    .c, .one, .many => @intFromPtr(b.*),
                    .slice => @intFromPtr(b.ptr),
                };
                var val: i8 = @intCast(@intFromBool(addr_a > addr_b));
                val -= @intCast(@intFromBool(addr_a < addr_b));
                return @enumFromInt(val);
            }
        },
        .@"enum" => struct {
            fn func(a: *const T, b: *const T) Order {
                var val: i8 = @intCast(@intFromBool(@intFromEnum(a.*) > @intFromEnum(b.*)));
                val -= @intCast(@intFromBool(@intFromEnum(a.*) < @intFromEnum(b.*)));
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

pub fn shallow_equals_else_never_equal(comptime T: type) MatchFn(T) {
    const container = comptime switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float, .@"enum", .@"struct", .error_union, .@"union", .array, .vector, .pointer, .optional => struct {
            fn func(a: *const T, b: *const T) bool {
                return meta.eql(a.*, b.*);
            }
        },
        else => struct {
            fn func(a: *const T, b: *const T) bool {
                _ = a;
                _ = b;
                return false;
            }
        },
    };
    return container.func;
}

pub const Order = enum(i8) {
    A_LESS_THAN_B = -1,
    A_EQUALS_B = 0,
    A_GREATER_THAN_B = 1,
};

test "Compare" {
    const t = std.testing;
    const _1: u8 = 1;
    const _2: u8 = 2;
    const compare_fn = numeric_order_else_always_equal(u8);
    try t.expect(a_less_than_b(u8, &_1, &_2, compare_fn));
    try t.expect(!a_less_than_b(u8, &_1, &_1, compare_fn));
    try t.expect(!a_less_than_b(u8, &_2, &_2, compare_fn));
    try t.expect(!a_less_than_b(u8, &_2, &_1, compare_fn));
    try t.expect(a_less_than_or_equal_to_b(u8, &_1, &_2, compare_fn));
    try t.expect(a_less_than_or_equal_to_b(u8, &_1, &_1, compare_fn));
    try t.expect(a_less_than_or_equal_to_b(u8, &_2, &_2, compare_fn));
    try t.expect(!a_less_than_or_equal_to_b(u8, &_2, &_1, compare_fn));
    try t.expect(!a_greater_than_b(u8, &_1, &_2, compare_fn));
    try t.expect(!a_greater_than_b(u8, &_1, &_1, compare_fn));
    try t.expect(!a_greater_than_b(u8, &_2, &_2, compare_fn));
    try t.expect(a_greater_than_b(u8, &_2, &_1, compare_fn));
    try t.expect(!a_greater_than_or_equal_to_b(u8, &_1, &_2, compare_fn));
    try t.expect(a_greater_than_or_equal_to_b(u8, &_1, &_1, compare_fn));
    try t.expect(a_greater_than_or_equal_to_b(u8, &_2, &_2, compare_fn));
    try t.expect(a_greater_than_or_equal_to_b(u8, &_2, &_1, compare_fn));
    try t.expect(!a_equals_b(u8, &_1, &_2, compare_fn));
    try t.expect(a_equals_b(u8, &_1, &_1, compare_fn));
    try t.expect(a_equals_b(u8, &_2, &_2, compare_fn));
    try t.expect(!a_equals_b(u8, &_2, &_1, compare_fn));
}
