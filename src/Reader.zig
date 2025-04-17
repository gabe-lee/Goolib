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

const Reader = @This();

implementation: struct {
    opaque_ptr: *anyopaque,
    get_buffer: *const fn (*anyopaque) []u8,
    get_byte_index: *const fn (*anyopaque) usize,
    /// Should return `true` if byte index successfully set
    ///
    /// Should return `false` if byte index could not be set to the new index
    /// and remains unchanged
    set_byte_index: *const fn (*anyopaque, new_index: usize) bool,
},

pub inline fn get_byte_index(self: *const Reader) usize {
    return self.implementation.get_byte_index(self.implementation.opaque_ptr);
}

pub inline fn get_byte_address(self: *const Reader) usize {
    return @intFromPtr(self.get_buffer().ptr) + self.get_byte_index();
}

pub fn set_byte_index(self: *const Reader, new_index: usize) ReadSuccess {
    if (self.implementation.set_byte_index(self.implementation.opaque_ptr, new_index)) return ReadSuccess.new_ok();
    return ReadSuccess.new_err(ReadError.new_too_short_err(0, new_index, buf.len));
}

pub inline fn skip_bytes(self: *const Reader, count: usize) ReadSuccess {
    return self.set_byte_index(self.get_byte_index() + count);
}

pub inline fn peek_bytes(self: *const Reader, count: usize) ReadResult([]u8) {
    const rem_buf = self.get_remaining_buffer();
    const start_index = self.get_byte_index();
    if (count > rem_buf.len) return ReadResult([]u8).new_err(ReadError.new_too_short_err(start_index, count, rem_buf.len));
    return ReadResult([]u8).new_val(rem_buf[0..count]);
}

pub inline fn get_buffer(self: *const Reader) []u8 {
    return self.implementation.get_buffer(self.implementation.opaque_ptr);
}

pub inline fn get_remaining_buffer(self: *const Reader) []u8 {
    return self.get_buffer()[self.get_byte_index()..];
}

pub fn read_bytes_in_place(self: *Reader, count: usize) ReadResult([]u8) {
    const buf = self.get_buffer();
    const start_index = self.get_byte_index();
    const end_index = start_index + count;
    const read_success = self.skip_bytes(count);
    if (read_success.is_err()) return ReadResult([]u8).new_err(read_success.err);
    return ReadResult([]u8).new_val(buf[start_index..end_index]);
}

pub fn read_type_in_place(self: *Reader, comptime T: type) ReadResult(*T) {
    const pos = self.get_byte_index();
    const addr = self.get_byte_address();
    if (!mem.isAligned(addr, @alignOf(T))) return ReadResult(*T).new_err(ReadError.new_unaligned_err(pos, addr, @alignOf(T), @as(usize, 1) << @ctz(addr)));
    const t_size = @sizeOf(T);
    const read_success = self.skip_bytes(t_size);
    if (read_success.is_err()) return ReadResult(*T).new_err(read_success.err);
    return ReadResult(*T).new_val(@ptrFromInt(addr));
}

pub fn read_bytes_into_buf(self: *Reader, count: usize, dest_buffer: []u8, comptime options: ReadOptions) ReadSuccess {
    const read_result = self.read_bytes_in_place(count);
    if (read_result.is_err) return ReadSuccess.new_err(read_result.err);
    const bytes = read_result.val;
    if (options.endian == NATIVE_ENDIAN) {
        @memcpy(dest_buffer, bytes);
    } else {
        var i_read = bytes.len - 1;
        var i_write = 0;
        while (i_write < count) {
            dest_buffer[i_write] = bytes[i_read];
            i_read -= 1;
            i_write += 1;
        }
    }
    return ReadSuccess.new_ok();
}

pub fn read_into_ptr(self: *Reader, comptime T: type, ptr: *T, comptime options: ReadOptions) ReadSuccess {
    switch (@typeInfo(T)) {
        .void => &.{},
        .int, .float, .bool => return self.next_cast_from_read_bytes(T, .Bits, endian),
        .@"enum" => return self.next_cast_from_read_bytes(T, .Enum, endian),
        .pointer => return self.next_cast_from_read_bytes(T, .Ptr, endian),
        .optional => |opt_info| {
            const tag = self.read_bytes(1);
            if (tag.len == 0) return ReadResult(T).new_err(self.new_buffer_short_err(1));
            if (tag[0] == TAG_BAD) return ReadResult(T).new_val(null);
            return self.read_endian(endian, opt_info.child);
        },
        .array => |arr_info| {
            var i: usize = 0;
            var arr: [arr_info.len]arr_info.child = undefined;
            while (i < arr.len) : (i += 1) {
                const read_result = self.read_endian(endian, arr_info.child);
                if (read_result.is_err()) return read_result.same_err_diff_val_type(T);
                arr[i] = read_result.val;
            }
            return ReadResult(T).new_val(arr);
        },
        .vector => |vec_info| {
            var i: usize = 0;
            var vec: @Vector(vec_info.len, vec_info.child) = undefined;
            while (i < vec.len) : (i += 1) {
                const read_result = self.read_endian(endian, vec_info.child);
                if (read_result.is_err()) return read_result.same_err_diff_val_type(T);
                vec[i] = read_result.val;
            }
            return ReadResult(T).new_val(vec);
        },
        .@"union" => |union_info| {
            if (union_info.tag_type == null) @compileError("cannot read a union type that does not have a tag_type");
            const tag_type = union_info.tag_type.?;
            const tag_result = self.read_endian(endian, tag_type);
            if (tag_result.is_err()) return tag_result.same_err_diff_val_type(T);
            const tag: tag_type = tag_result.val;
            const field_info: Type.UnionField = meta.fieldInfo(T, tag);
            const val_result = self.read_endian(endian, field_info.type);
            if (val_result.is_err()) return val_result.same_err_diff_val_type(T);
            return ReadResult(T).new_val(@unionInit(T, field_info.name, val_result.val));
        },
        .@"struct" => |struct_info| {
            var total_bytes: usize = 0;
            inline for (struct_info.fields) |field| {
                total_bytes += self.write_complete(endian, follow_pointer_depth, stable_error_write, field.type, @field(val, field.type));
            }
        },
        .comptime_int, .comptime_float => @compileError("Types `comptime_int` and `comptime_float` cannot be read, use a concrete type instead"),
        .error_set, .error_union => @compileError("Types `error_set` and `error_union` do not have stable tag values, use a custom enum/union instead"),
        else => @compileError("Type " ++ @typeName(T) ++ " has no write procedure."),
    }
}

inline fn new_buffer_short_err(self: *Reader, comptime needed: usize) ReadError {
    return ReadError{
        .pos = self.get_byte_index(),
        .kind = .buffer_too_short,
        .bytes_needed = needed,
        .bytes_available = self.get_remaining_buffer().len,
    };
}
inline fn new_unaligned_err(self: *Reader, comptime needed: usize) ReadError {
    return ReadError{
        .pos = self.get_byte_index(),
        .kind = .address_not_aligned_to_type,
        .bytes_needed = needed,
        .bytes_available = self.get_remaining_buffer().len,
    };
}

const CastMode = enum {
    Bits,
    Enum,
    Ptr,
};

pub fn ReadResult(comptime T: type) type {
    return Root.Generic.ReturnWrappers.Result(T, ReadError);
}
pub const ReadSuccess = Root.Generic.ReturnWrappers.Success(ReadError);
pub const ReadErrorKind = enum(u8) {
    buffer_too_short = 0,
    address_not_aligned_to_type = 1,
};
pub const ReadError = union(ReadErrorKind) {
    buffer_too_short: ReadErrorTooShort,
    address_not_aligned_to_type: ReadErrorUnaligned,

    pub inline fn new_too_short_err(pos: usize, needed: usize, available: usize) ReadError {
        return ReadError{ .buffer_too_short = ReadErrorTooShort{
            .pos = pos,
            .needed_bytes = needed,
            .available_bytes = available,
        } };
    }
    pub inline fn new_unaligned_err(pos: usize, addr: usize, needed: usize, real: usize) ReadError {
        return ReadError{ .address_not_aligned_to_type = ReadErrorUnaligned{
            .pos = pos,
            .addr = addr,
            .alignment_needed = needed,
            .alignment_at_addr = real,
        } };
    }
};
pub const ReadErrorTooShort = struct {
    pos: usize,
    needed_bytes: usize,
    available_bytes: usize,
};
pub const ReadErrorUnaligned = struct {
    pos: usize,
    addr: usize,
    alignment_needed: usize,
    alignment_at_addr: usize,
};
pub const ReadOptions = struct {
    endian: Endian = NATIVE_ENDIAN,
};
const TAG_GOOD = 1;
const TAG_BAD = 0;
