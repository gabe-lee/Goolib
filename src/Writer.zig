const std = @import("std");
const build = @import("builtin");
const Endian = std.builtin.Endian;
const Type = std.builtin.Type;
const math = std.math;
const meta = std.meta;
const mem = std.mem;

const Root = @import("./_root.zig");
const NumBase = Root.IO.Format.IntBase;

const Writer = @This();

implementation: struct {
    opaque_ptr: *anyopaque,
    get_buffer: *const fn (*anyopaque) []u8,
    get_byte_index: *const fn (*anyopaque) usize,
    set_byte_index: *const fn (*anyopaque, pos: usize) bool,
    write_bytes: *const fn (*anyopaque, bytes: []const u8) bool,
},

pub inline fn get_byte_index(self: *const Writer) usize {
    return self.implementation.get_byte_index(self.implementation.opaque_ptr);
}

pub inline fn set_byte_index(self: *const Writer, pos: usize) bool {
    return self.implementation.set_byte_index(self.implementation.opaque_ptr, pos);
}

pub inline fn get_buffer(self: *const Writer) []u8 {
    return self.implementation.get_buffer(self.implementation.opaque_ptr);
}

pub inline fn get_remaining_buffer(self: *const Writer) []u8 {
    return self.get_buffer()[self.get_byte_index()..];
}

pub fn write(self: *Writer, val: anytype, comptime endian: EndianMode) WriteResult {
    const T = @TypeOf(val);
    switch (@typeInfo(T)) {
        .void => return 0,
        .int, .float, .bool, .@"enum" => {
            const write_success = self.implementation.write_bytes(self.implementation.opaque_ptr, &to_bytes(T, @sizeOf(T), endian, val));
            if (write_success) return WriteResult.new_ok();
            return WriteResult.new_err(WriteErrorKind.buffer_too_short);
        },
        .pointer => |ptr_info| {
            switch (ptr_info.size) {
                .one => {
                    return self.write(val.*, endian);
                },
                .slice => {
                    const len = val.len;
                    var i: usize = 0;
                    const len_result = self.write(len, endian);
                    if (len_result.is_err()) return len_result;
                    while (i < len) : (i += 1) {
                        const val_result = self.write(val[i], endian);
                        if (val_result.is_err()) return val_result;
                    }
                    return WriteResult.new_ok();
                },
                .many, .c => @compileError("Cannot implicitly write `[*]T` or `[*c]T` pointers with an unknown length. Instead manually slice these with a length when writing."),
            }
        },
        .optional => {
            const tag: u8 = if (val != null) TAG_GOOD else TAG_BAD;
            const tag_success = self.implementation.write_bytes(self.implementation.opaque_ptr, &[1]u8{tag});
            if (!tag_success) return WriteResult.new_err(WriteErrorKind.buffer_too_short);
            if (tag == 0) return WriteResult.new_ok();
            return self.write(val.?, endian);
        },
        .array => |arr| {
            var i: usize = 0;
            while (i < arr.len) : (i += 1) {
                const write_result = self.write(val[i], endian);
                if (write_result.is_err()) return write_result;
            }
            return WriteResult.new_ok();
        },
        .vector => |vec| {
            var i: usize = 0;
            while (i < vec.len) : (i += 1) {
                const write_result = self.write(val[i], endian);
                if (write_result.is_err()) return write_result;
            }
            return WriteResult.new_ok();
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
        .comptime_int, .comptime_float => @compileError("Types comptime_int and comptime_float must be explicitly cast to a concrete type to write"),
        else => @compileError("Type " ++ @typeName(T) ++ " has no write procedure."),
    }
}

fn to_bytes(comptime T: type, comptime N: comptime_int, comptime E: EndianMode, val: T) [N]u8 {
    var raw: [N]u8 = @bitCast(val);
    if (N == 1 or E.is_native()) return raw;
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

// pub const WriteResult = Root.Generic.ReturnWrappers.Result(usize, WriteErrorKind);
pub const WriteResult = Root.Generic.ReturnWrappers.Success(WriteErrorKind);
pub const WriteErrorKind = enum(u8) {
    buffer_too_short = 0,
};
// pub const WriteError = union(WriteErrorKind) {
//     buffer_too_short: WriteErrorTooShort,

//     pub inline fn new_too_short_err(pos: usize, needed: usize, available: usize) WriteError {
//         return WriteError{ .buffer_too_short = WriteErrorTooShort{
//             .pos = pos,
//             .needed_bytes = needed,
//             .available_bytes = available,
//         } };
//     }
// };
// pub const WriteErrorTooShort = struct {
//     pos: usize,
//     needed_bytes: usize,
//     available_bytes: usize,
// };
pub const NATIVE_ENDIAN = Root.CommonTypes.NATIVE_ENDIAN;
pub const EndianMode = Root.CommonTypes.EndianMode;
const TAG_GOOD = 1;
const TAG_BAD = 0;
