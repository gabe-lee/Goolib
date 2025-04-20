const std = @import("std");
const build = @import("builtin");
const Type = std.builtin.Type;
const math = std.math;
const meta = std.meta;
const mem = std.mem;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const NumBase = Root.IO.Format.IntBase;
const Bytes = Root.Bytes;

pub fn ByteReaderG(comptime buffer_properties: Bytes.BufferProperties) type {
    return struct {
        buffer: []const u8,
        read_pos: usize,

        pub const READ_ENDIAN = buffer_properties.endianness;
        pub const READ_PACKED = buffer_properties.packed_elements;
        pub const READ_BUF_PROPS = Bytes.BufferProperties{ .endianness = READ_ENDIAN, .packed_elements = READ_PACKED };
        const Self = @This();

        pub fn new(buffer: []const u8, initial_read_pos: usize) Self {
            return Self{
                .buffer = buffer,
                .read_pos = initial_read_pos,
            };
        }

        pub fn make_adapter(comptime T: type, comptime dest_buffer_properties: Bytes.BufferProperties) Bytes.CopyAdapter {
            return Bytes.CopyAdapter.from_type_and_buffer_properties(T, READ_BUF_PROPS, dest_buffer_properties);
        }

        pub fn make_range(count: usize, adapter: Bytes.CopyAdapter) Bytes.CopyRange {
            return Bytes.CopyRange.from_count_and_adapter(count, adapter);
        }

        pub fn peek_range(self: *const Self, comptime T: type, range: Bytes.CopyRange, dst_slice: []T, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            comptime if (T != adapter.element_type) @compileError("`T` must be the same type as `adapter.element_type`");
            const dst_raw_len = dst_slice.len * @sizeOf(T);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(dst_slice.ptr));
            if (range.total_write_len > dst_raw_len) return ReadError.ReadError__destination_slice_too_short;
            if (self.read_pos + range.total_read_len > self.buffer.len) return ReadError.ReadError__read_buffer_too_short;
            Bytes.copy_elements_with_copy_range(dst_raw_ptr[0..dst_raw_len], self.buffer, range, adapter);
        }
        pub fn peek_comptime_range(self: *const Self, comptime T: type, comptime range: Bytes.CopyRange, dst_slice: []T, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            comptime if (T != adapter.element_type) @compileError("`T` must be the same type as `adapter.element_type`");
            const dst_raw_len = dst_slice.len * @sizeOf(T);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(dst_slice.ptr));
            if (range.total_write_len > dst_raw_len) return ReadError.ReadError__destination_slice_too_short;
            if (self.read_pos + range.total_read_len > self.buffer.len) return ReadError.ReadError__read_buffer_too_short;
            Bytes.copy_elements_with_comptime_copy_range(dst_raw_ptr[0..dst_raw_len], self.buffer, range, adapter);
        }
        pub fn skip_range(self: *const Self, comptime T: type, range: Bytes.CopyRange, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            comptime if (T != adapter.element_type) @compileError("`T` must be the same type as `adapter.element_type`");
            if (range.total_read_len > self.buffer.len) return ReadError.ReadError__read_buffer_too_short;
            self.read_pos += range.total_read_len;
        }
        pub fn skip_comptime_range(self: *const Self, comptime T: type, comptime range: Bytes.CopyRange, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            comptime if (T != adapter.element_type) @compileError("`T` must be the same type as `adapter.element_type`");
            if (self.read_pos + range.total_read_len > self.buffer.len) return ReadError.ReadError__read_buffer_too_short;
            self.read_pos += range.total_read_len;
        }
        pub fn read_range(self: *const Self, comptime T: type, range: Bytes.CopyRange, dst_slice: []T, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            try self.peek_with_adapter_and_range(T, dst_slice, range, adapter);
            self.read_pos += range.total_read_len;
        }
        pub fn read_comptime_range(self: *const Self, comptime T: type, comptime range: Bytes.CopyRange, dst_slice: []T, comptime adapter: Bytes.CopyAdapter) ReadError!void {
            try self.peek_with_adapter_and_comptime_range(T, dst_slice, range, adapter);
            self.read_pos += range.total_read_len;
        }
    };
}

pub const ReadError = error{
    ReadError__read_buffer_too_short,
    ReadError__destination_slice_too_short,
};
