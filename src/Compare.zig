const std = @import("std");
const Type = std.builtin.Type;
const meta = std.meta;
const mem = std.mem;

pub fn CompareFn(comptime T: type) type {
    return fn (a: T, b: T) bool;
}

pub fn ComparePackage(comptime T: type) type {
    const INFO = @typeInfo(T);
    return struct {
        order_less_than: *const fn (a: T, b: T) bool,
        order_less_than_or_equal_to: *const fn (a: T, b: T) bool,
        order_greater_than: *const fn (a: T, b: T) bool,
        order_greater_than_or_equal_to: *const fn (a: T, b: T) bool,
        order_equals: *const fn (a: T, b: T) bool,
        value_equals: *const fn (a: T, b: T) bool,

        const Self = @This();

        pub fn default() Self {
            if (INFO == .int or INFO == .comptime_int or INFO == .float or INFO == .comptime_float) {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return a < b;
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return a <= b;
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return a > b;
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return a >= b;
                    }
                    fn order_equals(a: T, b: T) bool {
                        return a == b;
                    }
                    fn value_equals(a: T, b: T) bool {
                        return a == b;
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            if (INFO == .@"enum") {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return @intFromEnum(a) < @intFromEnum(b);
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return @intFromEnum(a) <= @intFromEnum(b);
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return @intFromEnum(a) > @intFromEnum(b);
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return @intFromEnum(a) >= @intFromEnum(b);
                    }
                    fn order_equals(a: T, b: T) bool {
                        return @intFromEnum(a) == @intFromEnum(b);
                    }
                    fn value_equals(a: T, b: T) bool {
                        return @intFromEnum(a) == @intFromEnum(b);
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            if (INFO == .bool) {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return @intFromBool(a) < @intFromBool(b);
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return @intFromBool(a) <= @intFromBool(b);
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return @intFromBool(a) > @intFromBool(b);
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return @intFromBool(a) >= @intFromBool(b);
                    }
                    fn order_equals(a: T, b: T) bool {
                        return @intFromBool(a) == @intFromBool(b);
                    }
                    fn value_equals(a: T, b: T) bool {
                        return @intFromBool(a) == @intFromBool(b);
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            if (INFO == .pointer and (@typeInfo(INFO.pointer.child) == .int or @typeInfo(INFO.pointer.child) == .comptime_int or @typeInfo(INFO.pointer.child) == .float or @typeInfo(INFO.pointer.child) == .comptime_float)) {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return a.* < b.*;
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return a.* <= b.*;
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return a.* > b.*;
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return a.* >= b.*;
                    }
                    fn order_equals(a: T, b: T) bool {
                        return a.* == b.*;
                    }
                    fn value_equals(a: T, b: T) bool {
                        return a.* == b.*;
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            if (INFO == .pointer and @typeInfo(INFO.pointer.child) == .@"enum") {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return @intFromEnum(a.*) < @intFromEnum(b.*);
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return @intFromEnum(a.*) <= @intFromEnum(b.*);
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return @intFromEnum(a.*) > @intFromEnum(b.*);
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return @intFromEnum(a.*) >= @intFromEnum(b.*);
                    }
                    fn order_equals(a: T, b: T) bool {
                        return @intFromEnum(a.*) == @intFromEnum(b.*);
                    }
                    fn value_equals(a: T, b: T) bool {
                        return @intFromEnum(a.*) == @intFromEnum(b.*);
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            if (INFO == .pointer and @typeInfo(INFO.pointer.child) == .bool) {
                const PROTO = struct {
                    fn order_less_than(a: T, b: T) bool {
                        return @intFromBool(a.*) < @intFromBool(b.*);
                    }
                    fn order_less_than_or_equal_to(a: T, b: T) bool {
                        return @intFromBool(a.*) <= @intFromBool(b.*);
                    }
                    fn order_greater_than(a: T, b: T) bool {
                        return @intFromBool(a.*) > @intFromBool(b.*);
                    }
                    fn order_greater_than_or_equal_to(a: T, b: T) bool {
                        return @intFromBool(a.*) >= @intFromBool(b.*);
                    }
                    fn order_equals(a: T, b: T) bool {
                        return @intFromBool(a.*) == @intFromBool(b.*);
                    }
                    fn value_equals(a: T, b: T) bool {
                        return @intFromBool(a.*) == @intFromBool(b.*);
                    }
                };
                return Self{
                    .order_less_than = PROTO.order_less_than,
                    .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                    .order_greater_than = PROTO.order_greater_than,
                    .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                    .order_equals = PROTO.order_equals,
                    .value_equals = PROTO.value_equals,
                };
            }
            const PROTO = struct {
                fn order_less_than(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return false;
                }
                fn order_less_than_or_equal_to(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return true;
                }
                fn order_greater_than(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return false;
                }
                fn order_greater_than_or_equal_to(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return true;
                }
                fn order_equals(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return true;
                }
                fn value_equals(a: T, b: T) bool {
                    _ = a;
                    _ = b;
                    return true;
                }
            };
            return Self{
                .order_less_than = PROTO.order_less_than,
                .order_less_than_or_equal_to = PROTO.order_less_than_or_equal_to,
                .order_greater_than = PROTO.order_greater_than,
                .order_greater_than_or_equal_to = PROTO.order_greater_than_or_equal_to,
                .order_equals = PROTO.order_equals,
                .value_equals = PROTO.value_equals,
            };
        }
    };
}

pub fn less_than(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    const INFO = @typeInfo(T);
    switch (INFO) {
        .int, .comptime_int, .float, .comptime_float => return a < b,
        .@"enum" => return @intFromEnum(a) < @intFromEnum(b),
        .bool => return @intFromBool(a) < @intFromBool(b),
        .pointer => |PTR_INFO| if (PTR_INFO.is_allowzero) {
            @compileError("cannot infer a 'less than' condition for nullable pointer type: " ++ @typeName(T));
        } else switch (PTR_INFO.size) {
            .one => return if (a == b) false else less_than(a.*, b.*),
            .slice => {
                if (a.ptr == b.ptr) return a.len < b.len;
                var i: usize = 0;
                while (i < a.len) : (i += 1) {
                    if (i >= b.len) return false;
                    if (less_than(a.ptr[i], b.ptr[i])) return true;
                    if (greater_than(a.ptr[i], b.ptr[i])) return false;
                }
                return false;
            },
            .many, .c => if (PTR_INFO.sentinel_ptr) |sent_opq| {
                if (a == b) return false;
                const sent: *const PTR_INFO.child = @ptrCast(@alignCast(sent_opq));
                var i: usize = 0;
                while (a[i] != sent) : (i += 1) {
                    if (b[i] == sent) return false;
                    if (less_than(a[i], b[i])) return true;
                    if (greater_than(a[i], b[i])) return false;
                }
                return false;
            } else @compileError("cannot infer a 'less than' condition for [*]T and [*c]T pointers with no sentinel value: " ++ @typeName(T)),
        },
        .array, .vector => {
            var i: usize = 0;
            while (i < a.len) : (i += 1) {
                if (less_than(a[i], b[i])) return true;
                if (greater_than(a[i], b[i])) return false;
            }
            return false;
        },
        else => @compileError("cannot infer a 'less than' condition for type: " ++ @typeName(T)),
    }
}

pub fn less_than_or_equal(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    const INFO = @typeInfo(T);
    switch (INFO) {
        .int, .comptime_int, .float, .comptime_float => return a <= b,
        .@"enum" => return @intFromEnum(a) <= @intFromEnum(b),
        .bool => return @intFromBool(a) <= @intFromBool(b),
        .pointer => |PTR_INFO| if (PTR_INFO.is_allowzero) {
            @compileError("cannot infer a 'less than or equal' condition for nullable pointer type: " ++ @typeName(T));
        } else switch (PTR_INFO.size) {
            .one => return if (a == b) true else less_than_or_equal(a.*, b.*),
            .slice => {
                if (a.ptr == b.ptr) return a.len <= b.len;
                var i: usize = 0;
                while (i < a.len) : (i += 1) {
                    if (i >= b.len) return false;
                    if (less_than(a.ptr[i], b.ptr[i])) return true;
                    if (greater_than(a.ptr[i], b.ptr[i])) return false;
                }
                return true;
            },
            .many, .c => if (PTR_INFO.sentinel_ptr) |sent_opq| {
                if (a == b) return true;
                const sent: *const PTR_INFO.child = @ptrCast(@alignCast(sent_opq));
                var i: usize = 0;
                while (a[i] != sent) : (i += 1) {
                    if (b[i] == sent) return false;
                    if (less_than(a[i], b[i])) return true;
                    if (greater_than(a[i], b[i])) return false;
                }
                return true;
            } else @compileError("cannot infer a 'less than' condition for [*]T and [*c]T pointers with no sentinel value: " ++ @typeName(T)),
        },
        .array, .vector => {
            var i: usize = 0;
            while (i < a.len) : (i += 1) {
                if (less_than(a[i], b[i])) return true;
                if (greater_than(a[i], b[i])) return false;
            }
            return true;
        },
        else => @compileError("cannot infer a 'less than' condition for type: " ++ @typeName(T)),
    }
}

pub fn greater_than(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    const INFO = @typeInfo(T);
    switch (INFO) {
        .int, .comptime_int, .float, .comptime_float => return a > b,
        .@"enum" => return @intFromEnum(a) > @intFromEnum(b),
        .bool => return @intFromBool(a) > @intFromBool(b),
        .pointer => |PTR_INFO| if (PTR_INFO.is_allowzero) {
            @compileError("cannot infer a 'greater than' condition for nullable pointer type: " ++ @typeName(T));
        } else switch (PTR_INFO.size) {
            .one => return if (a == b) false else greater_than(a.*, b.*),
            .slice => {
                if (a.ptr == b.ptr) return a.len > b.len;
                var i: usize = 0;
                while (i < a.len) : (i += 1) {
                    if (i >= b.len) return true;
                    if (greater_than(a.ptr[i], b.ptr[i])) return true;
                    if (less_than(a.ptr[i], b.ptr[i])) return false;
                }
                return false;
            },
            .many, .c => if (PTR_INFO.sentinel_ptr) |sent_opq| {
                if (a.ptr == b.ptr) return false;
                const sent: *const PTR_INFO.child = @ptrCast(@alignCast(sent_opq));
                var i: usize = 0;
                while (a[i] != sent) : (i += 1) {
                    if (b[i] == sent) return true;
                    if (greater_than(a[i], b[i])) return true;
                    if (less_than(a[i], b[i])) return false;
                }
                return false;
            } else @compileError("cannot infer a 'greater than' condition for [*]T and [*c]T pointers with no sentinel value: " ++ @typeName(T)),
        },
        .array, .vector => {
            var i: usize = 0;
            while (i < a.len) : (i += 1) {
                if (greater_than(a[i], b[i])) return true;
                if (less_than(a[i], b[i])) return false;
            }
            return false;
        },
        else => @compileError("cannot infer a 'greater than' condition for type: " ++ @typeName(T)),
    }
}

pub fn greater_than_or_equal(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    const INFO = @typeInfo(T);
    switch (INFO) {
        .int, .comptime_int, .float, .comptime_float => return a >= b,
        .@"enum" => return @intFromEnum(a) >= @intFromEnum(b),
        .bool => return @intFromBool(a) >= @intFromBool(b),
        .pointer => |PTR_INFO| if (PTR_INFO.is_allowzero) {
            @compileError("cannot infer a 'greater than or equal' condition for nullable pointer type: " ++ @typeName(T));
        } else switch (PTR_INFO.size) {
            .one => return if (a == b) true else greater_than_or_equal(a.*, b.*),
            .slice => {
                if (a.ptr == b.ptr) return a.len >= b.len;
                var i: usize = 0;
                while (i < a.len) : (i += 1) {
                    if (i >= b.len) return true;
                    if (greater_than(a.ptr[i], b.ptr[i])) return true;
                    if (less_than(a.ptr[i], b.ptr[i])) return false;
                }
                return true;
            },
            .many, .c => if (PTR_INFO.sentinel_ptr) |sent_opq| {
                if (a.ptr == b.ptr) return true;
                const sent: *const PTR_INFO.child = @ptrCast(@alignCast(sent_opq));
                var i: usize = 0;
                while (a[i] != sent) : (i += 1) {
                    if (b[i] == sent) return true;
                    if (greater_than(a[i], b[i])) return true;
                    if (less_than(a[i], b[i])) return false;
                }
                return true;
            } else @compileError("cannot infer a 'greater than or equal' condition for [*]T and [*c]T pointers with no sentinel value: " ++ @typeName(T)),
        },
        .array, .vector => {
            var i: usize = 0;
            while (i < a.len) : (i += 1) {
                if (greater_than(a[i], b[i])) return true;
                if (less_than(a[i], b[i])) return false;
            }
            return true;
        },
        else => @compileError("cannot infer a 'greater than or equal' condition for type: " ++ @typeName(T)),
    }
}

pub fn equal(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    const INFO = @typeInfo(T);
    switch (INFO) {
        .int, .comptime_int, .float, .comptime_float, .bool, .@"enum" => return a == b,
        .pointer => |PTR_INFO| if (PTR_INFO.is_allowzero) {
            @compileError("cannot infer an 'equal' condition for nullable pointer type: " ++ @typeName(T));
        } else switch (PTR_INFO.size) {
            .one => return if (a == b) true else equal(a.*, b.*),
            .slice => {
                if (a.len != b.len) return false;
                if (a.ptr == b.ptr) return true;
                var i: usize = 0;
                while (i < a.len) : (i += 1) {
                    if (!equal(a.ptr[i], b.ptr[i])) return false;
                }
                return true;
            },
            .many, .c => if (PTR_INFO.sentinel_ptr) |sent_opq| {
                if (a.ptr == b.ptr) return true;
                const sent: *const PTR_INFO.child = @ptrCast(@alignCast(sent_opq));
                var i: usize = 0;
                while (a[i] != sent) : (i += 1) {
                    if (b[i] == sent) return false;
                    if (!equal(a.ptr[i], b.ptr[i])) return false;
                }
                return true;
            } else @compileError("cannot infer an 'equal' condition for [*]T and [*c]T pointers with no sentinel value: " ++ @typeName(T)),
        },
        .array, .vector => {
            var i: usize = 0;
            while (i < a.len) : (i += 1) {
                if (!equal(a[i], b[i])) return false;
            }
            return true;
        },
        else => @compileError("cannot infer an 'equal' condition for type: " ++ @typeName(T)),
    }
}
