//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const build = @import("builtin");
const math = std.math;
const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;
const MathX = Root.Math;
const KindInfo = Types.KindInfo;
const Kind = Types.Kind;
const Endian = Root.CommonTypes.Endian;
const DebugMode = Root.CommonTypes.DebugMode;
const Flags = Root.Flags.Flags;

const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Hash = std.hash.XxHash64;
const PowerOf2 = MathX.PowerOf2;
const Pool = Root.Pool.Simple.SimplePool;
const StackStatic = Root.Stack.StackStatic;
const SliceRangeSmall = Root.CommonTypes.SliceRangeSmall;

const DUMMY_ALLOC = DummyAllocator.allocator_panic_free_noop;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const bit_cast = Root.Cast.bit_cast;
const read_int = std.mem.readInt;
const DEBUG = std.debug.print;
const DEBUG_CT = Utils.comptime_debug_print;
const reverse_slice = Utils.Mem.reverse_slice;
const reverse_array = Utils.Mem.reverse_array;
const array_or_slice_equal = Utils.Mem.array_or_slice_equal;
const ptr_as_bytes = Utils.Mem.ptr_as_bytes;
const zig_zag_encode = MathX.zig_zag_encode;
const zig_zag_decode = MathX.zig_zag_decode;

pub const NATIVE_ENDIAN = Endian.NATIVE;

pub const SerialWriteError = error{
    /// The destination for the serial data ran out of space for the routine to
    /// fully serialize the object
    serial_destination_ran_out_of_space,
    /// A write error occured on the serial destination, but the
    /// destination does not specify exactly what failed
    unknown_write_error,
    /// The union tag in the current native union does not match any valid
    /// tag the serialization routine recorded on the native type at comptime.
    ///
    /// This may indicate that the union was changed, but the routine was not recompiled
    /// with the object containing the new version of the union.
    union_tag_in_native_didnt_match_any_valid_tag,
};

pub const SerialReadError = error{
    /// The source of serial data did not have enough
    /// bytes for the routine to fully deserialize the target
    /// object
    serial_source_ran_out_of_data,
    /// A read error occured on the source, but the source does not specify
    /// exactly what failed
    unknown_read_error,
    /// The union tag in the serial data does not match any valid
    /// tag the serialization routine recorded on the native type
    union_tag_in_serial_didnt_match_any_valid_tag,
    /// The 'magic identifier' bytes at the start of the serial
    /// data did not match the one expected by the serialization routine.
    ///
    /// You may need to use a different serial routine.
    magic_identifier_mismatch,
    /// The serial routine version recorded in the serialized
    /// data does not match the one expected by the serial routine.
    ///
    /// The version recorded in the serial stream is lower than the one expected;
    ///
    /// You may need to use a different serial routine
    serial_version_mismatch_lower,
    /// The serial routine version recorded in the serialized
    /// data does not match the one expected by the serial routine.
    ///
    /// The version recorded in the serial stream is higher than the one expected;
    ///
    /// You may need to use a different serial routine
    serial_version_mismatch_higher,
    /// If the serial stream indicates a VarInt integer, but the native size
    /// is not 2, 4, 8, or 16 it is an error
    varint_unsupported_target_native_size,
    /// VarInts are required to use the smallest possible representation for both security
    /// and memory considerations
    varint_overlong_encoding_or_value_too_large,
    /// Serializtion requires allocating memory, but the provided allocator failed
    allocation_error,
};

pub const SerialKind = enum(u8) {
    SLICE,
    READER_WRITER,
};

pub const SerialSourceSlice = struct {
    data: []const u8,
    cursor: usize,

    pub fn new(data: []const u8) SerialSourceSlice {
        return SerialSourceSlice{
            .data = data,
            .cursor = 0,
        };
    }

    pub fn read_n_bytes(self: *SerialSourceSlice, n: usize, native_dest: [*]u8) SerialReadError!void {
        const source_end = self.cursor + n;
        if (source_end > self.data.len) return SerialReadError.serial_source_ran_out_of_data;
        @memcpy(native_dest[0..n], self.data[self.cursor..source_end]);
        self.cursor = source_end;
    }

    pub fn read_one_byte(self: *SerialSourceSlice, native_dest: [*]u8) SerialReadError!void {
        if (self.cursor >= self.data.len) return SerialReadError.serial_source_ran_out_of_data;
        native_dest[0] = self.data[self.cursor];
        self.cursor += 1;
    }
};
pub const SerialSourceReader = struct {
    reader: *std.Io.Reader,

    pub fn new(reader: *std.Io.Reader) SerialSourceReader {
        return SerialSourceReader{
            .reader = reader,
        };
    }

    pub fn read_n_bytes(self: SerialSourceReader, n: usize, native_dest: [*]u8) SerialReadError!void {
        self.reader.readSliceAll(native_dest[0..n]) catch |err| switch (err) {
            .ReadFailed => return SerialReadError.unknown_read_error,
            .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
        };
    }

    pub fn read_one_byte(self: SerialSourceReader, native_dest: [*]u8) SerialReadError!void {
        self.reader.readSliceAll(native_dest[0..1]) catch |err| switch (err) {
            .ReadFailed => return SerialReadError.unknown_read_error,
            .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
        };
    }
};

pub const SerialSource = union {
    slice: *SerialSourceSlice,
    reader: SerialSourceReader,

    pub fn new_from_slice(source_slice: *SerialSourceSlice) SerialSource {
        return SerialSource{ .slice = source_slice };
    }
    pub fn new_from_reader(reader: *std.Io.Reader) SerialSource {
        return SerialSource{ .reader = SerialSourceReader.new(reader) };
    }

    pub fn read_n_bytes_in_order(self: SerialSource, comptime KIND: SerialKind, n: usize, native_dest: [*]u8) SerialReadError!void {
        switch (KIND) {
            .SLICE => {
                const ser = self.slice;
                return ser.read_n_bytes(n, native_dest);
            },
            .READER_WRITER => {
                const ser = self.reader;
                return ser.read_n_bytes(n, native_dest);
            },
        }
    }
    pub fn read_one_byte(self: SerialSource, comptime KIND: SerialKind, native_dest: [*]u8) SerialReadError!void {
        switch (KIND) {
            .SLICE => {
                const ser = self.slice;
                return ser.read_one_byte(native_dest);
            },
            .READER_WRITER => {
                const ser = self.reader;
                return ser.read_one_byte(native_dest);
            },
        }
    }
    pub fn read_type_in_order(self: SerialSourceReader, comptime T: type, native_dest: *T) SerialReadError!void {
        const N = @sizeOf(T);
        if (N == 1) {
            return self.read_one_byte(@ptrCast(native_dest));
        } else {
            return self.read_n_bytes(N, @ptrCast(native_dest));
        }
    }
    pub fn read_type_swap_bytes(self: SerialSourceReader, comptime T: type, native_dest: *T) SerialReadError!void {
        const N = @sizeOf(T);
        try self.read_n_bytes(N, @ptrCast(native_dest));
        const UINT_TYPE = Types.UnsignedIntegerWithSameSize(T);
        const native_dest_uint: *UINT_TYPE = @ptrCast(native_dest);
        native_dest_uint.* = @byteSwap(native_dest_uint.*);
    }
    pub fn read_varint(self: SerialSource, comptime KIND: SerialKind, comptime ZIGZAG: bool, comptime T: type, native_dest: *T) SerialReadError!usize {
        const NATIVE_LEN = @sizeOf(T);
        assert_with_reason(NATIVE_LEN == 2 or NATIVE_LEN == 4 or NATIVE_LEN == 8 or NATIVE_LEN == 16, @src(), "VarInts are only upported for 2, 4, 8, or 16 byte types with well-defined memory layouts, got native len {d}", .{NATIVE_LEN});
        const NATIVE_UINT = std.meta.Int(.unsigned, NATIVE_LEN * 8);
        var temp_buffer: [32]u8 align(@alignOf(u128)) = @splat(0);
        const temp_uint: *NATIVE_UINT = @ptrCast(@alignCast(&temp_buffer[16]));
        var additional_bytes_to_read: usize = 0;
        var total_bytes: usize = 0;
        var continue_bytes: usize = 0;
        var temp_start: usize = undefined;
        var b: u8 = undefined;
        try self.read_one_byte(KIND, @ptrCast(&b));
        const LSB: usize = switch (NATIVE_LEN) {
            2 => 17,
            4 => 19,
            8 => 23,
            16 => 31,
            else => unreachable,
        };
        var MSB: usize = LSB;
        check_next_byte: switch (b) {
            0b0_0000000...0b0_1111111 => { // +1 byte
                total_bytes += 1;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
            },
            0b10_000000...0b10_111111 => { // +2 bytes
                b &= 0b00_111111;
                MSB -= 1;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 1;
                total_bytes += 2;
            },
            0b110_00000...0b110_11111 => { // +3 bytes
                b &= 0b000_11111;
                MSB -= 2;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 2;
                total_bytes += 3;
            },
            0b1110_0000...0b1110_1111 => { // +4 bytes
                b &= 0b0000_1111;
                MSB -= 3;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 3;
                total_bytes += 4;
            },
            0b11110_000...0b11110_111 => { // +5 bytes
                b &= 0b00000_111;
                MSB -= 4;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 4;
                total_bytes += 5;
            },
            0b111110_00...0b111110_11 => { // +6 bytes
                b &= 0b000000_11;
                MSB -= 5;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 5;
                total_bytes += 6;
            },
            0b1111110_0...0b1111110_1 => { // +7 bytes
                b &= 0b0000000_1;
                MSB -= 6;
                const pfx_byte = MSB + continue_bytes;
                temp_buffer[pfx_byte] = b;
                temp_start = pfx_byte;
                additional_bytes_to_read += 6;
                total_bytes += 7;
            },
            0b11111110 => { // +8 bytes
                MSB -= 7;
                temp_start = MSB + continue_bytes;
                additional_bytes_to_read += 7;
                total_bytes += 8;
            },
            0b11111111 => {
                if (NATIVE_LEN == 8) {
                    MSB = 15;
                    total_bytes = 9;
                    additional_bytes_to_read = 8;
                    temp_start = MSB;
                    break :check_next_byte;
                }
                MSB -= 8;
                additional_bytes_to_read += 7;
                continue_bytes += 1;
                total_bytes += 8;
                if (MSB < 13) return SerialReadError.varint_overlong_encoding_or_value_too_large_or_value_too_large;
                try self.read_one_byte(KIND, @ptrCast(&b));
                continue :check_next_byte b;
            },
        }
        switch (NATIVE_LEN) {
            2 => if (total_bytes > 3) return SerialReadError.varint_overlong_encoding_or_value_too_large,
            4 => if (total_bytes > 5) return SerialReadError.varint_overlong_encoding_or_value_too_large,
            8 => if (total_bytes > 9) return SerialReadError.varint_overlong_encoding_or_value_too_large,
            16 => if (total_bytes > 19) return SerialReadError.varint_overlong_encoding_or_value_too_large,
            else => unreachable,
        }
        const temp_start_additional = temp_start + 1;
        try self.read_n_bytes_in_order(KIND, additional_bytes_to_read, @ptrCast(&temp_buffer[temp_start_additional]));
        if (NATIVE_ENDIAN == .LITTLE_ENDIAN) {
            temp_uint.* = @byteSwap(temp_uint.*);
        }
        if (ZIGZAG) {
            temp_uint.* = zig_zag_decode(NATIVE_UINT, temp_uint.*);
        }
        @memcpy(native_dest[0..NATIVE_LEN], temp_buffer[16 .. 16 + NATIVE_LEN]);
        return total_bytes;
    }
};

pub const SerialDestSlice = struct {
    data: []u8,
    cursor: usize,

    pub fn new(data: []u8) SerialDestSlice {
        return SerialDestSlice{
            .data = data,
            .cursor = 0,
        };
    }

    pub fn write_n_bytes(self: *SerialDestSlice, n: usize, native_src: [*]const u8) SerialWriteError!void {
        const dest_end = self.cursor + n;
        if (dest_end > self.data.len) return SerialWriteError.serial_destination_ran_out_of_space;
        @memcpy(self.data[self.cursor..dest_end], native_src[0..n]);
        self.cursor = dest_end;
    }

    pub fn write_one_byte(self: *SerialDestSlice, native_src: [*]u8) SerialWriteError!void {
        if (self.cursor >= self.data.len) return SerialWriteError.serial_destination_ran_out_of_space;
        self.data[self.cursor] = native_src[0];
        self.cursor += 1;
    }
};

pub const SerialDestWriter = struct {
    writer: *std.Io.Writer,

    pub fn new(writer: *std.Io.Writer) SerialDestWriter {
        return SerialDestWriter{
            .writer = writer,
        };
    }

    pub fn write_n_bytes(self: SerialDestWriter, n: usize, native_src: [*]u8) SerialWriteError!void {
        self.writer.writeAll(native_src[0..n]) catch return SerialWriteError.serial_destination_ran_out_of_space;
    }

    pub fn write_one_byte(self: SerialDestWriter, native_src: [*]u8) SerialWriteError!void {
        self.writer.writeByte(native_src[0]) catch return SerialWriteError.serial_destination_ran_out_of_space;
    }

    pub fn flush(self: SerialDestWriter) SerialWriteError!void {
        self.writer.flush() catch return SerialWriteError.serial_destination_ran_out_of_space;
    }
};

pub const SerialDest = union {
    slice: *SerialDestSlice,
    writer: SerialDestWriter,

    pub fn new_from_slice(dest_slice: *SerialDestSlice) SerialDest {
        return SerialDest{ .slice = dest_slice };
    }
    pub fn new_from_writer(writer: *std.Io.Writer) SerialDest {
        return SerialDest{ .writer = SerialDestWriter.new(writer) };
    }

    pub fn finalize(self: SerialDest, comptime KIND: SerialKind) SerialWriteError!void {
        switch (KIND) {
            .SLICE => {},
            .READER_WRITER => {
                const ser = self.writer;
                return ser.flush();
            },
        }
    }

    pub fn write_n_bytes_in_order(self: SerialDest, comptime KIND: SerialKind, n: usize, native_src: [*]u8) SerialWriteError!void {
        switch (KIND) {
            .SLICE => {
                const ser = self.slice;
                return ser.write_n_bytes(n, native_src);
            },
            .READER_WRITER => {
                const ser = self.writer;
                return ser.write_n_bytes(n, native_src);
            },
        }
    }
    pub fn write_one_byte(self: SerialDest, comptime KIND: SerialKind, native_src: [*]u8) SerialWriteError!void {
        switch (KIND) {
            .SLICE => {
                const ser = self.slice;
                return ser.write_one_byte(native_src);
            },
            .READER_WRITER => {
                const ser = self.writer;
                return ser.write_one_byte(native_src);
            },
        }
    }
    pub fn write_type_in_order(self: SerialDest, comptime T: type, native_src: *T) SerialWriteError!void {
        const N = @sizeOf(T);
        if (N == 1) {
            return self.write_one_byte(@ptrCast(native_src));
        } else {
            return self.write_n_bytes_in_order(N, @ptrCast(native_src));
        }
    }
    pub fn write_type_swap_bytes(self: SerialDest, comptime T: type, native_src: *T) SerialWriteError!void {
        try self.write_type_in_order(T, native_src);
        const UINT_TYPE = Types.UnsignedIntegerWithSameSize(T);
        const native_src_uint: *UINT_TYPE = @ptrCast(native_src);
        native_src_uint.* = @byteSwap(native_src_uint.*);
    }

    /// NUM_BYTES, LEAST_SIG_IDX, MOST_SIG_IDX
    const NLM = struct { usize, usize, usize };

    pub fn write_varint(self: SerialDest, comptime KIND: SerialKind, comptime ZIGZAG: bool, comptime T: type, native_src: *const T) SerialWriteError!usize {
        const NATIVE_LEN = @sizeOf(T);
        assert_with_reason(NATIVE_LEN == 2 or NATIVE_LEN == 4 or NATIVE_LEN == 8 or NATIVE_LEN == 16, @src(), "VarInts are only supported for 2, 4, 8, or 16 byte data types with a well-defined memory layout, got native len {d}", .{NATIVE_LEN});
        var temp_buffer: [35]u8 align(@alignOf(u128)) = @splat(0);
        const NATIVE_UINT = std.meta.Int(.unsigned, NATIVE_LEN * 8);
        const temp_uint: *NATIVE_UINT = @ptrCast(@alignCast(&temp_buffer[16]));
        temp_uint.* = @bitCast(native_src.*);
        const num_bytes: usize, const least_sig_byte_with_data: usize, const most_sig_byte_with_data: usize = switch (NATIVE_LEN) {
            2 => get: {
                if (ZIGZAG) temp_uint.* = @bitCast(zig_zag_encode(temp_uint.*));
                const LSB: comptime_int = if (NATIVE_ENDIAN == .BIG_ENDIAN) 17 else 16;
                break :get switch (temp_uint.*) {
                    0...127 => NLM{ 1, LSB, LSB },
                    128...16383 => add_prefix: {
                        temp_buffer[more_sig(LSB, 1)] |= 0b10_000000;
                        break :add_prefix NLM{ 2, LSB, more_sig(LSB, 1) };
                    },
                    16384...0xFFFF => add_prefix: {
                        temp_buffer[more_sig(LSB, 2)] |= 0b110_00000;
                        break :add_prefix NLM{ 3, LSB, more_sig(LSB, 2) };
                    },
                };
            },
            4 => get: {
                if (ZIGZAG) temp_uint.* = @bitCast(zig_zag_encode(temp_uint.*));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 19 else 16;
                break :get switch (temp_uint.*) {
                    0...127 => NLM{ 1, LSB, LSB },
                    128...16383 => add_prefix: {
                        temp_buffer[more_sig(LSB, 1)] |= 0b10_000000;
                        break :add_prefix NLM{ 2, LSB, more_sig(LSB, 1) };
                    },
                    16384...2097151 => add_prefix: {
                        temp_buffer[more_sig(LSB, 2)] |= 0b110_00000;
                        break :add_prefix NLM{ 3, LSB, more_sig(LSB, 2) };
                    },
                    2097152...268435455 => add_prefix: {
                        temp_buffer[more_sig(LSB, 3)] |= 0b1110_0000;
                        break :add_prefix NLM{ 4, LSB, more_sig(LSB, 3) };
                    },
                    268435456...0xFFFFFFFF => add_prefix: {
                        temp_buffer[more_sig(LSB, 4)] |= 0b11110_000;
                        break :add_prefix NLM{ 5, LSB, more_sig(LSB, 4) };
                    },
                };
            },
            8 => get: {
                if (ZIGZAG) temp_uint.* = @bitCast(zig_zag_encode(temp_uint.*));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 23 else 16;
                break :get switch (temp_uint.*) {
                    0...127 => NLM{ 1, LSB, LSB },
                    128...16383 => add_prefix: {
                        temp_buffer[more_sig(LSB, 1)] |= 0b10_000000;
                        break :add_prefix NLM{ 2, LSB, more_sig(LSB, 1) };
                    },
                    16384...2097151 => add_prefix: {
                        temp_buffer[more_sig(LSB, 2)] |= 0b110_00000;
                        break :add_prefix NLM{ 3, LSB, more_sig(LSB, 2) };
                    },
                    2097152...268435455 => add_prefix: {
                        temp_buffer[more_sig(LSB, 3)] |= 0b1110_0000;
                        break :add_prefix NLM{ 4, LSB, more_sig(LSB, 3) };
                    },
                    268435456...34359738367 => add_prefix: {
                        temp_buffer[more_sig(LSB, 4)] |= 0b11110_000;
                        break :add_prefix NLM{ 5, LSB, more_sig(LSB, 4) };
                    },
                    34359738368...4398046511103 => add_prefix: {
                        temp_buffer[more_sig(LSB, 5)] |= 0b111110_00;
                        break :add_prefix NLM{ 6, LSB, more_sig(LSB, 5) };
                    },
                    4398046511104...562949953421311 => add_prefix: {
                        temp_buffer[more_sig(LSB, 6)] |= 0b1111110_0;
                        break :add_prefix NLM{ 7, LSB, more_sig(LSB, 6) };
                    },
                    562949953421312...72057594037927935 => add_prefix: {
                        temp_buffer[more_sig(LSB, 7)] |= 0b11111110;
                        break :add_prefix NLM{ 8, LSB, more_sig(LSB, 7) };
                    },
                    72057594037927936...0xFFFFFFFFFFFFFFFF => add_prefix: {
                        temp_buffer[more_sig(LSB, 8)] |= 0b11111111;
                        break :add_prefix NLM{ 9, LSB, more_sig(LSB, 8) };
                    },
                };
            },
            16 => get: {
                if (ZIGZAG) temp_uint.* = @bitCast(zig_zag_encode(temp_uint.*));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 31 else 16;
                break :get switch (temp_uint.*) {
                    0...127 => NLM{ 1, LSB, LSB },
                    128...16383 => add_prefix: {
                        temp_buffer[more_sig(LSB, 1)] |= 0b10_000000;
                        break :add_prefix NLM{ 2, LSB, more_sig(LSB, 1) };
                    },
                    16384...2097151 => add_prefix: {
                        temp_buffer[more_sig(LSB, 2)] |= 0b110_00000;
                        break :add_prefix NLM{ 3, LSB, more_sig(LSB, 2) };
                    },
                    2097152...268435455 => add_prefix: {
                        temp_buffer[more_sig(LSB, 3)] |= 0b1110_0000;
                        break :add_prefix NLM{ 4, LSB, more_sig(LSB, 3) };
                    },
                    268435456...34359738367 => add_prefix: {
                        temp_buffer[more_sig(LSB, 4)] |= 0b11110_000;
                        break :add_prefix NLM{ 5, LSB, more_sig(LSB, 4) };
                    },
                    34359738368...4398046511103 => add_prefix: {
                        temp_buffer[more_sig(LSB, 5)] |= 0b111110_00;
                        break :add_prefix NLM{ 6, LSB, more_sig(LSB, 5) };
                    },
                    4398046511104...562949953421311 => add_prefix: {
                        temp_buffer[more_sig(LSB, 6)] |= 0b1111110_0;
                        break :add_prefix NLM{ 7, LSB, more_sig(LSB, 6) };
                    },
                    562949953421312...72057594037927935 => add_prefix: {
                        temp_buffer[more_sig(LSB, 7)] |= 0b11111110;
                        break :add_prefix NLM{ 8, LSB, more_sig(LSB, 7) };
                    },
                    72057594037927936...9223372036854775807 => add_prefix: {
                        temp_buffer[more_sig(LSB, 8)] |= 0b11111111;
                        // temp_buffer[more_sig(LSB, 7)] |= 0b0_0000000;
                        break :add_prefix NLM{ 9, LSB, more_sig(LSB, 8) };
                    },
                    9223372036854775808...1180591620717411303423 => add_prefix: {
                        temp_buffer[more_sig(LSB, 9)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 8)] |= 0b10_000000;
                        break :add_prefix NLM{ 10, LSB, more_sig(LSB, 9) };
                    },
                    1180591620717411303424...151115727451828646838271 => add_prefix: {
                        temp_buffer[more_sig(LSB, 10)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 9)] |= 0b110_00000;
                        break :add_prefix NLM{ 11, LSB, more_sig(LSB, 10) };
                    },
                    151115727451828646838272...19342813113834066795298815 => add_prefix: {
                        temp_buffer[more_sig(LSB, 11)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 10)] |= 0b1110_0000;
                        break :add_prefix NLM{ 12, LSB, more_sig(LSB, 11) };
                    },
                    19342813113834066795298816...2475880078570760549798248447 => add_prefix: {
                        temp_buffer[more_sig(LSB, 12)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 11)] |= 0b11110_000;
                        break :add_prefix NLM{ 13, LSB, more_sig(LSB, 12) };
                    },
                    2475880078570760549798248448...316912650057057350374175801343 => add_prefix: {
                        temp_buffer[more_sig(LSB, 13)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 12)] |= 0b111110_00;
                        break :add_prefix NLM{ 14, LSB, more_sig(LSB, 13) };
                    },
                    316912650057057350374175801344...40564819207303340847894502572031 => add_prefix: {
                        temp_buffer[more_sig(LSB, 14)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 13)] |= 0b1111110_0;
                        break :add_prefix NLM{ 15, LSB, more_sig(LSB, 14) };
                    },
                    40564819207303340847894502572032...5192296858534827628530496329220095 => add_prefix: {
                        temp_buffer[more_sig(LSB, 15)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 14)] |= 0b11111110;
                        break :add_prefix NLM{ 16, LSB, more_sig(LSB, 15) };
                    },
                    5192296858534827628530496329220096...664613997892457936451903530140172287 => add_prefix: {
                        temp_buffer[more_sig(LSB, 16)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 15)] |= 0b11111111;
                        // temp_buffer[more_sig(LSB, 14)] |= 0b0_0000000;
                        break :add_prefix NLM{ 17, LSB, more_sig(LSB, 16) };
                    },
                    664613997892457936451903530140172288...85070591730234615865843651857942052863 => add_prefix: {
                        temp_buffer[more_sig(LSB, 17)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 16)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 15)] |= 0b10_000000;
                        break :add_prefix NLM{ 18, LSB, more_sig(LSB, 17) };
                    },
                    85070591730234615865843651857942052864...0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF => add_prefix: {
                        temp_buffer[more_sig(LSB, 18)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 17)] |= 0b11111111;
                        temp_buffer[more_sig(LSB, 16)] |= 0b110_00000;
                        break :add_prefix NLM{ 19, LSB, more_sig(LSB, 18) };
                    },
                };
            },
            else => unreachable,
        };
        const first_byte = if (NATIVE_ENDIAN == .BIG_ENDIAN) most_sig_byte_with_data else least_sig_byte_with_data;
        const byte_end = if (NATIVE_ENDIAN == .BIG_ENDIAN) least_sig_byte_with_data + 1 else most_sig_byte_with_data + 1;
        if (NATIVE_ENDIAN != .BIG_ENDIAN) {
            Utils.Mem.reverse_slice(temp_buffer[first_byte..byte_end]);
        }
        switch (KIND) {
            .SLICE => {
                const ser = self.slice;
                try ser.write_n_bytes(num_bytes, @ptrCast(&temp_buffer[first_byte]));
            },
            .READER_WRITER => {
                const ser = self.writer;
                try ser.write_n_bytes(num_bytes, @ptrCast(&temp_buffer[first_byte]));
            },
        }
        return num_bytes;
    }
};
// VARINT EXAMPLES:
//
// 1 byte (< 128)
// ________ ________ ________┃0AAAAAAA
// 2 byte (< 16384)          ┃
// ________ ________ ________┃10AAAAAA xxxxxxxx
// 3 byte (< 2097152)        ┃
// ________ ________ ________┃110AAAAA xxxxxxxx xxxxxxxx
// 4 byte (< 268435456)      ┃
// ________ ________ ________┃1110AAAA xxxxxxxx xxxxxxxx xxxxxxxx
// 5 byte (< 34359738368)    ┃
// ________ ________ ________┃11110AAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 6 byte (< 4398046511104)  ┃
// ________ ________ ________┃111110AA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 7 byte (< 562949953421312)┃
// ________ ________ ________┃1111110A xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 8 byte (< 72057594037927936)
// ________ ________ ________┃11111110 AAAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 9 byte for u64:           ┃
// ________ ________ 11111111┃AAAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 9 byte for u128 (< 9223372036854775808)
// ________ ________ ________┃11111111 0AAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 10 byte (< 1180591620717411303424)
// ________ ________ ________┃11111111 10AAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 11 byte (< 151115727451828646838272)
// ________ ________ ________┃11111111 110AAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 12 byte (< 19342813113834066795298816)
// ________ ________ ________┃11111111 1110AAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 13 byte (< 2475880078570760549798248448)
// ________ ________ ________┃11111111 11110AAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 14 byte (< 316912650057057350374175801344)
// ________ ________ ________┃11111111 111110AA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 15 byte (< 40564819207303340847894502572032)
// ________ ________ ________┃11111111 1111110A xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 16 byte (< 5192296858534827628530496329220096)
// ________ ________ ________┃11111111 11111110 AAAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 17 bytes (< 664613997892457936451903530140172288)
// ________ ________ 11111111┃11111111 0AAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 18 bytes (< 85070591730234615865843651857942052864)
// ________ 11111111 11111111┃10AAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 19 bytes (<= 340282366920938463463374607431768211455)
// 11111111 11111111 110_____┃AAAAAAAA xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
//                      ^^^^^ If any of these bits are not 0, it is an error if you are
//                            strict on non-canonical reps, but they have no effect on the
//                            final value either way.

inline fn more_sig(comptime start: comptime_int, comptime move: comptime_int) comptime_int {
    if (NATIVE_ENDIAN == .BIG_ENDIAN) {
        return start - move;
    } else {
        return start + move;
    }
}
inline fn less_sig(comptime start: comptime_int, comptime move: comptime_int) comptime_int {
    if (NATIVE_ENDIAN == .BIG_ENDIAN) {
        return start + move;
    } else {
        return start - move;
    }
}

test "VarInt round trip equality" {
    const Test = Root.Testing;
    var rand_core = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    const rand = rand_core.random();
    const EXTENDED = false;
    const ITERS_PER_TYPE = if (EXTENDED) 100000 else 100;
    var serial_buf: [32]u8 = undefined;
    const src = SerialSource{ .slice = serial_buf[0..32] };
    const dst = SerialDest{ .slice = serial_buf[0..32] };

    { // static u128
        const static_exp: u128 = 0xF1_0F_0E_0D_0C_0B_0A_09_08_07_06_05_04_03_02_01;
        const static_exp_bytes: [*]align(@alignOf(u128)) const u8 = @ptrCast(&static_exp);
        var static_got: u128 = undefined;
        var static_got_bytes: [*]align(@alignOf(u128)) u8 = @ptrCast(&static_got);
        const len = try dst.write_varint(.SLICE, false, static_exp_bytes[0..16], 0, 16, 16, 0);
        try Test.expect_equal(len, "len", 19, "19", "len encode wrong", .{});
        try Test.expect_slices_equal_t(u8, serial_buf[0..19], "serial_buf[0..19]", &.{ 0xFF, 0xFF, 0b110_00000, 0xF1, 0x0F, 0x0E, 0x0D, 0x0C, 0x0B, 0x0A, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 }, "{ 0xFF, 0xFF, 0b110_00000, 0xF1, 0x0F, 0x0E, 0x0D, 0x0C, 0x0B, 0x0A, 0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 }", "static expected byte order mismatch", .{});
        const len_2 = try src.read_varint(.SLICE, false, static_got_bytes[0..16], 0, 16, 16, 0);
        try Test.expect_equal(len_2, "len_2", 19, "19", "len decode wrong", .{});
        try Test.expect_equal(static_got, "static_got", static_got, "static_got", "static mismatch", .{});
    }
    { // static u64
        const static_exp: u64 = 0xF8_07_06_05_04_03_02_01;
        const static_exp_bytes: [*]align(@alignOf(u64)) const u8 = @ptrCast(&static_exp);
        var static_got: u64 = undefined;
        var static_got_bytes: [*]align(@alignOf(u64)) u8 = @ptrCast(&static_got);
        const len = try dst.write_varint(.SLICE, false, static_exp_bytes[0..8], 0, 8, 8, 0);
        try Test.expect_equal(len, "len", 9, "9", "len encode wrong", .{});
        try Test.expect_slices_equal_t(u8, serial_buf[0..9], "serial_buf[0..9]", &.{ 0xFF, 0xF8, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 }, "{ 0xFF, 0xF8, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 }", "static expected byte order mismatch", .{});
        const len_2 = try src.read_varint(.SLICE, false, static_got_bytes[0..8], 0, 8, 8, 0);
        try Test.expect_equal(len_2, "len_2", 9, "9", "len decode wrong", .{});
        try Test.expect_equal(static_got, "static_got", static_got, "static_got", "static mismatch", .{});
    }
    { // static u32
        const static_exp: u32 = 0xF4_03_02_01;
        const static_exp_bytes: [*]align(@alignOf(u32)) const u8 = @ptrCast(&static_exp);
        var static_got: u32 = undefined;
        var static_got_bytes: [*]align(@alignOf(u32)) u8 = @ptrCast(&static_got);
        const len = try dst.write_varint(.SLICE, false, static_exp_bytes[0..4], 0, 4, 4, 0);
        try Test.expect_equal(len, "len", 5, "5", "len encode wrong", .{});
        try Test.expect_slices_equal_t(u8, serial_buf[0..5], "serial_buf[0..5]", &.{ 0b11110_000, 0xF4, 0x03, 0x02, 0x01 }, "{ 0b11110_000, 0xF4, 0x03, 0x02, 0x01 }", "static expected byte order mismatch", .{});
        const len_2 = try src.read_varint(.SLICE, false, static_got_bytes[0..4], 0, 4, 4, 0);
        try Test.expect_equal(len_2, "len_2", 5, "5", "len decode wrong", .{});
        try Test.expect_equal(static_got, "static_got", static_got, "static_got", "static mismatch", .{});
    }
    { // static u16
        const static_exp: u32 = 0xF2_01;
        const static_exp_bytes: [*]align(@alignOf(u16)) const u8 = @ptrCast(&static_exp);
        var static_got: u16 = undefined;
        var static_got_bytes: [*]align(@alignOf(u16)) u8 = @ptrCast(&static_got);
        const len = try dst.write_varint(.SLICE, false, static_exp_bytes[0..2], 0, 2, 2, 0);
        try Test.expect_equal(len, "len", 3, "3", "len encode wrong", .{});
        try Test.expect_slices_equal_t(u8, serial_buf[0..3], "serial_buf[0..3]", &.{ 0b110_00000, 0xF2, 0x01 }, "{ 0b110_00000, 0xF2, 0x01 }", "static expected byte order mismatch", .{});
        const len_2 = try src.read_varint(.SLICE, false, static_got_bytes[0..2], 0, 2, 2, 0);
        try Test.expect_equal(len_2, "len_2", 3, "3", "len decode wrong", .{});
        try Test.expect_equal(static_got, "static_got", static_got, "static_got", "static mismatch", .{});
    }

    for (0..ITERS_PER_TYPE) |_| {
        // u16
        const val_orig: u16 = rand.int(u16);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: u16 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, false, val_orig_bytes[0..2], 0, 2, 2, 0);
        const r = try src.read_varint(.SLICE, false, val_decoded_bytes[0..2], 0, 2, 2, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // i16
        const val_orig: i16 = rand.int(i16);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: i16 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, true, val_orig_bytes[0..2], 0, 2, 2, 0);
        const r = try src.read_varint(.SLICE, true, val_decoded_bytes[0..2], 0, 2, 2, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // u32
        const val_orig: u32 = rand.int(u32);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: u32 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, false, val_orig_bytes[0..4], 0, 4, 4, 0);
        const r = try src.read_varint(.SLICE, false, val_decoded_bytes[0..4], 0, 4, 4, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // i32
        const val_orig: i32 = rand.int(i32);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: i32 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, true, val_orig_bytes[0..4], 0, 4, 4, 0);
        const r = try src.read_varint(.SLICE, true, val_decoded_bytes[0..4], 0, 4, 4, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // u64
        const val_orig: u64 = rand.int(u64);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: u64 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, false, val_orig_bytes[0..8], 0, 8, 8, 0);
        const r = try src.read_varint(.SLICE, false, val_decoded_bytes[0..8], 0, 8, 8, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // i64
        const val_orig: i64 = rand.int(i64);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: i64 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, true, val_orig_bytes[0..8], 0, 8, 8, 0);
        const r = try src.read_varint(.SLICE, true, val_decoded_bytes[0..8], 0, 8, 8, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // u128
        const val_orig: u128 = rand.int(u128);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: u128 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, false, val_orig_bytes[0..16], 0, 16, 16, 0);
        const r = try src.read_varint(.SLICE, false, val_decoded_bytes[0..16], 0, 16, 16, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
    for (0..ITERS_PER_TYPE) |_| {
        // i128
        const val_orig: i128 = rand.int(i128);
        const val_orig_bytes: [*]const u8 = @ptrCast(&val_orig);
        var val_decoded: i128 = undefined;
        const val_decoded_bytes: [*]u8 = @ptrCast(&val_decoded);
        const w = try dst.write_varint(.SLICE, true, val_orig_bytes[0..16], 0, 16, 16, 0);
        const r = try src.read_varint(.SLICE, true, val_decoded_bytes[0..16], 0, 16, 16, 0);
        try Test.expect_equal(val_decoded, "val_decoded", val_orig, "val_orig", "varint round-trip value mismatch\n\tGOT {b:0>16}\n\tEXP {b:0>16}", .{ val_decoded, val_orig });
        try Test.expect_equal(w, "bytes written", r, "bytes read", "varint round-trip bytes written/read mismatch", .{});
    }
}
