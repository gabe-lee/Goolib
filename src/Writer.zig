const std = @import("std");
const build = @import("builtin");
const Endian = std.builtin.Endian;
pub const NATIVE_ENDIAN = build.cpu.arch.endian();
const Type = std.builtin.Type;
const math = std.math;
const meta = std.meta;
const mem = std.mem;

const Root = @import("./_root.zig");
const NumBase = Root.IO.Format.IntBase;

const Writer = @This();

implementation: struct {
    opaque_ptr: *anyopaque,
    buffer: *const fn (*anyopaque) []u8,
    get_pos: *const fn (*anyopaque) usize,
    set_pos: *const fn (*anyopaque, pos: usize) bool,
    write_bytes: *const fn (*anyopaque, bytes: []const u8) usize,
},

pub inline fn get_pos(self: *const Writer) usize {
    return self.implementation.get_pos(self.implementation.opaque_ptr);
}

pub inline fn set_pos(self: *const Writer, pos: usize) bool {
    return self.implementation.set_pos(self.implementation.opaque_ptr, pos);
}

pub inline fn buffer(self: *const Writer) []u8 {
    return self.implementation.buffer(self.implementation.opaque_ptr);
}

pub fn write_complete(self: *Writer, comptime endian: Endian, comptime follow_pointer_depth: usize, comptime stable_error_write: bool, comptime T: type, val: T) usize {
    switch (@typeInfo(T)) {
        .void => return 0,
        .int, .float, .bool, .@"enum" => return self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(T, @sizeOf(T), endian, val)),
        .comptime_int, .comptime_float => @compileError("Types comptime_int and comptime_float must be explicitly cast to a concrete type to write"),
        .pointer => |ptr| {
            if (follow_pointer_depth > 0) {
                return self.write_complete(endian, follow_pointer_depth - 1, stable_error_write, ptr.child, val.*);
            } else {
                return self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(usize, @sizeOf(usize), endian, @intFromPtr(val)));
            }
        },
        .optional => |opt| {
            const tag: u8 = if (val != null) 1 else 0;
            var total_bytes = self.implementation.write_bytes(self.implementation.opaque_ptr, &[1]u8{tag});
            if (tag == 1) total_bytes += self.write_complete(endian, follow_pointer_depth, stable_error_write, opt.child, val.?);
            return total_bytes;
        },
        .array => |arr| {
            var i: usize = 0;
            var total: usize = 0;
            while (i < arr.len) : (i += 1) {
                total += self.write_complete(endian, follow_pointer_depth, stable_error_write, arr.child, val[i]);
            }
            return total;
        },
        .vector => |vec| {
            var i: usize = 0;
            var total: usize = 0;
            while (i < vec.len) : (i += 1) {
                total += self.write_complete(endian, follow_pointer_depth, stable_error_write, vec.child, val[i]);
            }
            return total;
        },
        .error_set => {
            if (stable_error_write) {
                const name = @errorName(val);
                return self.implementation.write_bytes(self.implementation.opaque_ptr, name);
            } else {
                const tag = @intFromError(val);
                const TT = @TypeOf(tag);
                return self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(TT, @sizeOf(TT), endian, tag));
            }
        },
        .error_union => |err_uni| {
            if (val) |ok_val| {
                const tag = 1;
                var total_bytes = self.implementation.write_bytes(self.implementation.opaque_ptr, &[1]u8{tag});
                total_bytes += self.write_complete(endian, follow_pointer_depth, stable_error_write, err_uni.payload, ok_val);
                return total_bytes;
            } else |err_val| {
                const tag = 0;
                var total_bytes = self.implementation.write_bytes(self.implementation.opaque_ptr, &[1]u8{tag});
                const e_tag = @intFromError(err_val);
                const TT = @TypeOf(e_tag);
                total_bytes += self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(TT, @sizeOf(TT), endian, e_tag));
                return total_bytes;
            }
        },
        .@"union" => {
            switch (val) {
                inline else => |inner_val, tag| {
                    const TT = @TypeOf(tag);
                    var total_bytes = self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(TT, @sizeOf(TT), endian, tag));
                    total_bytes += self.write_complete(endian, follow_pointer_depth, stable_error_write, @TypeOf(inner_val), inner_val);
                    return total_bytes;
                },
            }
        },
        .@"struct" => |struct_info| {
            var total_bytes: usize = 0;
            inline for (struct_info.fields) |field| {
                total_bytes += self.write_complete(endian, follow_pointer_depth, stable_error_write, field.type, @field(val, field.type));
            }
        },
        else => @compileError("Type " ++ @typeName(T) ++ " has no write procedure."),
    }
}

pub inline fn write_endian(self: *Writer, comptime endian: Endian, val: anytype) usize {
    return self.write_complete(endian, 0, @TypeOf(val), val);
}

pub inline fn write(self: *Writer, val: anytype) usize {
    return self.write_complete(NATIVE_ENDIAN, 0, @TypeOf(val), val);
}

fn to_bytes(comptime T: type, comptime N: comptime_int, comptime E: Endian, val: T) [N]u8 {
    var raw: [N]u8 = @bitCast(val);
    if (N == 1 or NATIVE_ENDIAN == E) return raw;
    var left: usize = 0;
    var right: usize = N - 1;
    var temp: u8 = 0;
    while (left < right) {
        temp = raw[left];
        raw[left] = raw[right];
        raw[right] = temp;
        left += 1;
        right -= 1;
    }
    return raw;
}
