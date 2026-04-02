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

pub const NATIVE_ENDIAN = Endian.NATIVE;

pub const IntegerPacking = enum(u8) {
    /// Serialize integers at their native size, and packed
    /// in the target byte order for the serial routine
    USE_TARGET_ENDIAN,
    /// Serialize integers of the size 2, 4, 8, or 16 bytes
    /// using varints, which can greatly
    /// reduce serial size when integer values are often
    /// smaller than their maximum possible value,
    /// at the cost of additional processing time
    ///
    /// 1-byte integers (and booleans) and integers greater than
    /// 16 bytes in size will use always use target endian mode
    ///
    /// Specifically, this uses the 'PrefixVarint' method in BIG ENDIAN,
    /// where the leading bits of the first byte (or first couple bytes for very large values) to signal the total
    /// number of bytes for the value, and the following bytes are in BIG ENDIAN order
    ///
    /// This reduces the number of CPU branches required to serialize a single value and eliminates
    /// additional bit shifting/masking ops on the data bytes
    USE_VARINTS,
};

/// This is only needed when using integers packed as VarInts,
/// as it signals that signed integers to use zig-zag encoding
/// in addition to the varint encoding
pub const IntegerSign = enum(u8) {
    /// Integer is unsigned. This is only needed when using Integers packed as VarInts
    UNSIGNED,
    /// Integer is signed. This is only needed when using Integers packed as VarInts,
    /// as it causes signed integers to use zig-zag encoding
    SIGNED,
};

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
    varint_overlong_encoding,
};

const SerialKind = enum(u8) {
    SLICE,
    READER_WRITER,
};

const SerialSource = union {
    slice: []const u8,
    reader: *std.Io.Reader,

    pub fn read_data_in_order(self: SerialSource, comptime KIND: SerialKind, native_slice: []u8, native_start: usize, native_end: usize, serial_start: usize, serial_end: usize) SerialReadError!void {
        switch (KIND) {
            .SLICE => {
                const serial_data = self.slice;
                if (serial_end > serial_data.len) return SerialReadError.serial_source_ran_out_of_data;
                @memcpy(native_slice[native_start..native_end], serial_data[serial_start..serial_end]);
            },
            .READER_WRITER => {
                const reader = self.reader;
                reader.readSliceAll(native_slice[native_start..native_end]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
            },
        }
    }
    pub fn read_data_swap(self: SerialSource, comptime KIND: SerialKind, native_slice: []u8, native_start: usize, native_end: usize, serial_start: usize, serial_end: usize) SerialReadError!void {
        switch (KIND) {
            .SLICE => {
                const serial_data = self.slice;
                if (serial_end > serial_data.len) return SerialReadError.serial_source_ran_out_of_data;
                var sidx: usize = serial_start;
                var nidx: usize = native_end;
                while (sidx < serial_end) : (sidx += 1) {
                    nidx -= 1;
                    native_slice[nidx] = serial_data[sidx];
                }
            },
            .READER_WRITER => {
                const reader = self.reader;
                reader.readSliceAll(native_slice[native_start..native_end]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                std.mem.reverse(u8, native_slice[native_start..native_end]);
            },
        }
    }
    inline fn read_one_byte(self: SerialSource, comptime KIND: SerialKind, start: *usize) SerialReadError!u8 {
        switch (KIND) {
            .SLICE => {
                const serial = self.slice;
                if (start.* >= serial.len) return SerialReadError.serial_source_ran_out_of_data;
                const val = serial[start.*];
                start.* += 1;
                return val;
            },
            .READER_WRITER => {
                const reader = self.reader;
                var b: [1]u8 = undefined;
                reader.readSliceAll(b[0..1]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                return b[0];
            },
        }
    }
    inline fn read_n_bytes(self: SerialSource, comptime KIND: SerialKind, start: *usize, dest: []u8) SerialReadError!void {
        switch (KIND) {
            .SLICE => {
                const serial = self.slice;
                const end = start.* + dest.len;
                if (end > serial.len) return SerialReadError.serial_source_ran_out_of_data;
                @memcpy(dest, serial[start.*..end]);
                start.* += dest.len;
            },
            .READER_WRITER => {
                const reader = self.reader;
                reader.readSliceAll(dest) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
            },
        }
    }
    pub fn read_varint(self: SerialSource, comptime KIND: SerialKind, comptime ZIGZAG: bool, native_slice: []u8, native_start: usize, native_end: usize, native_len: usize, serial_start: usize) SerialReadError!usize {
        assert_with_reason(native_len == 2 or native_len == 4 or native_len == 8 or native_len == 16, @src(), "VarInts are only upported for 2, 4, 8, or 16 byte integers, got native len {d}", .{native_len});
        var temp_buffer: [32]u8 align(@alignOf(u128)) = @splat(0);
        const val_offset: *align(@alignOf(u128)) u8 = &temp_buffer[16];
        var additional_bytes_to_read: usize = 0;
        var total_bytes: usize = 0;
        var continue_bytes: usize = 0;
        var temp_start: usize = undefined;
        var start: usize = serial_start;
        var b: u8 = try self.read_one_byte(KIND, &start);
        const LSB: usize = switch (native_len) {
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
                if (native_len == 8) {
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
                if (MSB < 13) return SerialReadError.varint_overlong_encoding;
                b = try self.read_one_byte(KIND, &start);
                continue :check_next_byte b;
            },
        }
        switch (native_len) {
            2 => if (total_bytes > 3) return SerialReadError.varint_overlong_encoding,
            4 => if (total_bytes > 5) return SerialReadError.varint_overlong_encoding,
            8 => if (total_bytes > 9) return SerialReadError.varint_overlong_encoding,
            16 => if (total_bytes > 19) return SerialReadError.varint_overlong_encoding,
            else => unreachable,
        }
        const temp_start_additional = temp_start + 1;
        const temp_end = temp_start_additional + additional_bytes_to_read;
        try self.read_n_bytes(KIND, &start, temp_buffer[temp_start_additional..temp_end]);
        if (NATIVE_ENDIAN == .LITTLE_ENDIAN) {
            std.mem.reverse(u8, temp_buffer[16 .. 16 + native_len]);
        }
        if (ZIGZAG) {
            switch (native_len) {
                2 => do_zigzag_adjustment(2, @ptrCast(val_offset), .SERIAL_TO_NATIVE),
                4 => do_zigzag_adjustment(4, @ptrCast(val_offset), .SERIAL_TO_NATIVE),
                8 => do_zigzag_adjustment(8, @ptrCast(val_offset), .SERIAL_TO_NATIVE),
                16 => do_zigzag_adjustment(16, @ptrCast(val_offset), .SERIAL_TO_NATIVE),
                else => unreachable,
            }
        }
        @memcpy(native_slice[native_start..native_end], temp_buffer[16 .. 16 + native_len]);
        return total_bytes;
    }
};

const SerialDest = union {
    slice: []u8,
    writer: *std.Io.Writer,

    pub fn write_data_in_order(self: SerialDest, comptime KIND: SerialKind, native_data: []const u8, native_start: usize, native_end: usize, serial_start: usize, serial_end: usize) SerialWriteError!void {
        switch (KIND) {
            .SLICE => {
                const serial_slice = self.slice;
                @memcpy(serial_slice[serial_start..serial_end], native_data[native_start..native_end]);
            },
            .READER_WRITER => {
                const writer = self.writer;
                writer.writeAll(native_data[native_start..native_end]) catch return SerialWriteError.serial_destination_ran_out_of_space;
            },
        }
    }
    pub fn write_data_swap(self: SerialDest, comptime KIND: SerialKind, native_data: []const u8, native_start: usize, native_end: usize, serial_start: usize, serial_end: usize) SerialWriteError!void {
        _ = native_start;
        switch (KIND) {
            .SLICE => {
                const serial_slice = self.slice;
                var sidx: usize = serial_start;
                var nidx: usize = native_end;
                while (sidx < serial_end) : (sidx += 1) {
                    nidx -= 1;
                    serial_slice[sidx] = native_data[nidx];
                }
            },
            .READER_WRITER => {
                const writer = self.writer;
                var sidx: usize = serial_start;
                var nidx: usize = native_end;
                while (sidx < serial_end) : (sidx += 1) {
                    nidx -= 1;
                    writer.writeByte(native_data[nidx]) catch return SerialWriteError.serial_destination_ran_out_of_space;
                }
            },
        }
    }
    /// NUM_BYTES, LEAST_SIG_IDX, MOST_SIG_IDX
    const NLM = struct { usize, usize, usize };
    pub fn write_varint(self: SerialDest, comptime KIND: SerialKind, comptime ZIGZAG: bool, native_data: []const u8, native_start: usize, native_end: usize, native_len: usize, serial_start: usize) SerialWriteError!usize {
        assert_with_reason(native_len == 2 or native_len == 4 or native_len == 8 or native_len == 16, @src(), "VarInts are only supported for 2, 4, 8, or 16 byte integers, got native len {d}", .{native_len});
        var temp_buffer: [35]u8 align(@alignOf(u128)) = @splat(0);
        const val_offset: *align(@alignOf(u128)) u8 = &temp_buffer[16];
        switch (native_len) {
            2 => @memcpy(temp_buffer[16..18], native_data[native_start..native_end]),
            4 => @memcpy(temp_buffer[16..20], native_data[native_start..native_end]),
            8 => @memcpy(temp_buffer[16..24], native_data[native_start..native_end]),
            16 => @memcpy(temp_buffer[16..32], native_data[native_start..native_end]),
            else => unreachable,
        }
        const num_bytes: usize, const least_sig_byte_with_data: usize, const most_sig_byte_with_data: usize = switch (native_len) {
            2 => get: {
                if (ZIGZAG) do_zigzag_adjustment(2, @ptrCast(val_offset), .NATIVE_TO_SERIAL);
                const uint: *const u16 = @ptrCast(@alignCast(val_offset));
                const LSB: comptime_int = if (NATIVE_ENDIAN == .BIG_ENDIAN) 17 else 16;
                break :get switch (uint.*) {
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
                if (ZIGZAG) do_zigzag_adjustment(4, @ptrCast(val_offset), .NATIVE_TO_SERIAL);
                const uint: *const u32 = @ptrCast(@alignCast(val_offset));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 19 else 16;
                break :get switch (uint.*) {
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
                if (ZIGZAG) do_zigzag_adjustment(8, @ptrCast(val_offset), .NATIVE_TO_SERIAL);
                const uint: *const u64 = @ptrCast(@alignCast(val_offset));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 23 else 16;
                break :get switch (uint.*) {
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
                if (ZIGZAG) do_zigzag_adjustment(16, @ptrCast(val_offset), .NATIVE_TO_SERIAL);
                const uint: *const u128 = @ptrCast(@alignCast(val_offset));
                const LSB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 31 else 16;
                break :get switch (uint.*) {
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
            std.mem.reverse(u8, temp_buffer[first_byte..byte_end]);
        }
        switch (KIND) {
            .SLICE => {
                const serial = self.slice;
                const serial_end = serial_start + num_bytes;
                if (serial_end > serial.len) return SerialWriteError.serial_destination_ran_out_of_space;
                @memcpy(serial[serial_start..serial_end], temp_buffer[first_byte..byte_end]);
            },
            .READER_WRITER => {
                const writer = self.writer;
                writer.writeAll(temp_buffer[first_byte..byte_end]) catch return SerialWriteError.serial_destination_ran_out_of_space;
            },
        }
        return num_bytes;
    }
};

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

pub const OpKind = enum(u8) {
    MOVE_DATA_NO_SWAP,
    MOVE_DATA_SWAP,
    MOVE_DATA_NO_SWAP_SAVE_TAG,
    MOVE_DATA_SWAP_SAVE_TAG,
    MOVE_DATA_NO_SWAP_SAVE_LEN,
    MOVE_DATA_SWAP_SAVE_LEN,
    MOVE_DATA_VARINT_P,
    MOVE_DATA_VARINT_P_SAVE_TAG,
    MOVE_DATA_VARINT_P_SAVE_LEN,
    MOVE_DATA_VARINT_PS,
    MOVE_DATA_VARINT_PS_SAVE_TAG,
    MOVE_DATA_VARINT_PS_SAVE_LEN,
    UNION_HEADER,
    UNION_TAG_ID,
    UNION_ROUTINE_START,
    UNION_ROUTINE_END_TEMP,
    UNION_ROUTINE_END,
    SINGLE_ITEM_POINTER_HEADER,
    MANY_ITEM_POINTER_HEADER,
    NULLABLE_SINGLE_ITEM_POINTER_HEADER,
    NULLABLE_MANY_ITEM_POINTER_HEADER,
    POINTER_ROUTINE_END,
    FULL_CUSTOM_FUNCTION,
};

pub const OpKind2 = Flags(enum(u8) { MOVE_DATA = 0b00000_001, UNION }, enum(u8) {});

pub const DataOp = union(OpKind) {
    MOVE_DATA_NO_SWAP: MemCopyMove,
    MOVE_DATA_SWAP: MemCopyMove,
    MOVE_DATA_NO_SWAP_SAVE_TAG: MemCopyMove,
    MOVE_DATA_SWAP_SAVE_TAG: MemCopyMove,
    MOVE_DATA_NO_SWAP_SAVE_LEN: MemCopyMove,
    MOVE_DATA_SWAP_SAVE_LEN: MemCopyMove,
    MOVE_DATA_VARINT_P: MemCopyMove,
    MOVE_DATA_VARINT_P_SAVE_TAG: MemCopyMove,
    MOVE_DATA_VARINT_P_SAVE_LEN: MemCopyMove,
    MOVE_DATA_VARINT_PS: MemCopyMove,
    MOVE_DATA_VARINT_PS_SAVE_TAG: MemCopyMove,
    MOVE_DATA_VARINT_PS_SAVE_LEN: MemCopyMove,
    UNION_HEADER: UnionHeader,
    UNION_TAG_ID: u64,
    UNION_ROUTINE_START: UnionRoutineStart,
    UNION_ROUTINE_END_TEMP: UnionRoutineEndTemp,
    UNION_ROUTINE_END: UnionRoutineEnd,
    SINGLE_ITEM_POINTER_HEADER: PointerHeader,
    MANY_ITEM_POINTER_HEADER: PointerHeader,
    NULLABLE_SINGLE_ITEM_POINTER_HEADER: PointerHeader,
    NULLABLE_MANY_ITEM_POINTER_HEADER: PointerHeader,
    POINTER_ROUTINE_END,
    FULL_CUSTOM_FUNCTION: *const CustomRuntimeSerializeFuncs,

    pub fn mem_move_no_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_NO_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len > 1, @src(), "mem swap data ops cannot be 1 byte in size, because 1 byte cant be endian swapped", .{});
        return DataOp{ .MOVE_DATA_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_no_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_NO_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len > 1, @src(), "mem swap data ops cannot be 1 byte in size, because 1 byte cant be endian swapped", .{});
        assert_with_reason(copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_no_swap_save_len(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_len()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_NO_SWAP_SAVE_LEN = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_swap_save_len(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len > 1, @src(), "mem swap data ops cannot be 1 byte in size, because 1 byte cant be endian swapped", .{});
        assert_with_reason(copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_len()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_SWAP_SAVE_LEN = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_P = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_P_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p_save_len(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_len()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_P_SAVE_LEN = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_PS = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_PS_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps_save_len(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_len()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_PS_SAVE_LEN = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn union_header(comptime num_fields: usize, comptime tag_type: type) DataOp {
        return DataOp{ .UNION_HEADER = UnionHeader{ .num_fields = @intCast(num_fields), .tag_type = OpaqueUnionTag.from_tag_type(tag_type) } };
    }
    pub fn union_routine_start(comptime offset_to_first_routine_op: u32, comptime total_num_ops: u32) DataOp {
        return DataOp{ .UNION_ROUTINE_START = UnionRoutineStart{
            .offset_to_first_routine_op = offset_to_first_routine_op,
            .total_num_ops = total_num_ops,
        } };
    }
    pub fn union_tag_id(comptime endian_tag_as_u64: u64) DataOp {
        return DataOp{ .UNION_TAG_ID = endian_tag_as_u64 };
    }
    pub fn union_routine_end_temp(comptime current_builder_op_len: usize, comptime this_routine_bytes: u32) DataOp {
        return DataOp{ .UNION_ROUTINE_END_TEMP = UnionRoutineEndTemp{
            .delta = RoutineEndDelta{ .true_op_index_of_routine_end = @intCast(current_builder_op_len) },
            .routine_serial_delta_adjustment = this_routine_bytes,
        } };
    }

    pub fn single_item_pointer_header(comptime allocator_name: []const u8, comptime elem_size: u32, comptime builder: *SerialRoutineBuilder) DataOp {
        const alloc_idx = builder.find_alloc_name_idx(allocator_name);
        return DataOp{ .SINGLE_ITEM_POINTER_HEADER = PointerHeader{
            .elem_size = elem_size,
            .allocator_id = alloc_idx,
        } };
    }

    pub fn many_item_pointer_header(comptime allocator_name: []const u8, comptime elem_size: u32, comptime builder: *SerialRoutineBuilder) DataOp {
        const alloc_idx = builder.find_alloc_name_idx(allocator_name);
        return DataOp{ .MANY_ITEM_POINTER_HEADER = PointerHeader{
            .elem_size = elem_size,
            .allocator_id = alloc_idx,
        } };
    }

    pub fn pointer_routine_end() DataOp {
        return DataOp{.POINTER_ROUTINE_END};
    }

    pub fn fully_custom_functions(funcs: *const CustomRuntimeSerializeFuncs) DataOp {
        return DataOp{ .FULL_CUSTOM_FUNCTION = funcs };
    }

    pub fn can_combine(comptime prev: DataOp, comptime next: DataOp) ?DataOp {
        if (prev == .MOVE_DATA_NO_SWAP and next == .MOVE_DATA_NO_SWAP) {
            if (prev.MOVE_DATA_NO_SWAP.native_to_serial_delta == next.MOVE_DATA_NO_SWAP.native_to_serial_delta) {
                return DataOp.mem_move_no_swap(prev.MOVE_DATA_NO_SWAP.native_to_serial_delta, prev.MOVE_DATA_NO_SWAP.copy_len + next.MOVE_DATA_NO_SWAP.copy_len);
            }
        }
        return null;
    }
};

pub const PointerHeader = struct {
    allocator_id: u32,
    elem_size: u32,
};

pub const UnionRoutineStart = struct {
    offset_to_first_routine_op: u32,
    total_num_ops: u32,
};

pub const UnionRoutineEndTemp = struct {
    delta: RoutineEndDelta,
    routine_serial_delta_adjustment: u32,

    pub fn finalize(comptime self: *UnionRoutineEndTemp, comptime current_builder_op_len: usize) void {
        const old_op_len: usize = @intCast(self.delta.true_op_index_of_routine_end);
        const true_delta = current_builder_op_len - old_op_len;
        self.delta = RoutineEndDelta{ .ops_to_advance_to_exit_union = @intCast(true_delta) };
    }

    pub fn concrete(comptime self: UnionRoutineEndTemp) UnionRoutineEnd {
        return UnionRoutineEnd{
            .ops_to_advance_to_exit_union = self.delta.ops_to_advance_to_exit_union,
            .routine_serial_delta_adjustment = self.routine_serial_delta_adjustment,
        };
    }
};

pub const UnionRoutineEnd = struct {
    ops_to_advance_to_exit_union: u32,
    routine_serial_delta_adjustment: u32,
};

pub const RoutineEndDelta = union {
    true_op_index_of_routine_end: u32,
    ops_to_advance_to_exit_union: u32,
};

pub const MemCopyMove = struct {
    native_to_serial_delta: i32 = 0,
    copy_len: u32 = 0,

    pub inline fn mem_copy_move(comptime native_to_serial_delta: i32, comptime copy_len: u32) MemCopyMove {
        return MemCopyMove{ .native_to_serial_delta = native_to_serial_delta, .copy_len = copy_len };
    }
};

pub const OpaqueUnionTag = enum(u8) {
    U8 = 1,
    U16 = 2,
    U32 = 4,
    U64 = 8,

    pub fn from_union(comptime UNION: type) OpaqueUnionTag {
        const TAG_TYPE = KindInfo.get_kind_info(UNION).UNION.tag_type.?;
        return from_tag_type(TAG_TYPE);
    }
    pub fn from_tag_type(comptime TAG_TYPE: type) OpaqueUnionTag {
        return switch (@sizeOf(TAG_TYPE)) {
            1 => OpaqueUnionTag.U8,
            2 => OpaqueUnionTag.U16,
            4 => OpaqueUnionTag.U32,
            8 => OpaqueUnionTag.U64,
            else => assert_unreachable(@src(), "tag type `{s}` is not supported", .{@typeName(TAG_TYPE)}),
        };
    }
    pub fn from_byte_len(len: usize) OpaqueUnionTag {
        return switch (len) {
            1 => OpaqueUnionTag.U8,
            2 => OpaqueUnionTag.U16,
            4 => OpaqueUnionTag.U32,
            8 => OpaqueUnionTag.U64,
            else => assert_unreachable(@src(), "tag type size `{s}` is not supported", .{len}),
        };
    }

    pub fn bytes(comptime self: OpaqueUnionTag) u8 {
        return @intFromEnum(self);
    }
    pub fn bytes_usize(comptime self: OpaqueUnionTag) usize {
        return @intCast(@intFromEnum(self));
    }

    pub fn opaque_type(comptime self: OpaqueUnionTag) type {
        return switch (self) {
            .U8 => u8,
            .U16 => u16,
            .U32 => u32,
            .U64 => u64,
        };
    }

    pub fn undef(comptime self: OpaqueUnionTag) self.opaque_type() {
        return switch (self) {
            .U8 => 0xAA,
            .U16 => 0xAAAA,
            .U32 => 0xAAAAAAAA,
            .U64 => 0xAAAAAAAAAAAAAAAA,
        };
    }
    pub fn zero(comptime self: OpaqueUnionTag) self.opaque_type() {
        return 0;
    }
    pub fn tag_ptr_from_union_ptr_and_offset(comptime self: OpaqueUnionTag, comptime UNION: type, union_ptr: *UNION, offset: usize) *self.opaque_type() {
        var raw_ptr: [*]u8 = @ptrCast(union_ptr);
        raw_ptr += offset;
        return @ptrCast(@alignCast(raw_ptr));
    }
    pub fn tag_ptr_from_union_ptr_and_offset_const(comptime self: OpaqueUnionTag, comptime UNION: type, union_ptr: *const UNION, offset: usize) *const self.opaque_type() {
        var raw_ptr: [*]const u8 = @ptrCast(union_ptr);
        raw_ptr += offset;
        return @ptrCast(@alignCast(raw_ptr));
    }

    pub fn from_serial_slice(comptime self: OpaqueUnionTag, data: []const u8) self.opaque_type() {
        assert_with_reason(num_cast(self, usize) <= data.len, @src(), "data slice is not long enough for this union tag (need {d} bytes, got {d})", .{ @intFromEnum(self), data.len });
    }

    pub fn cast_union_tag(comptime self: OpaqueUnionTag, any_union: anytype) self.opaque_type() {
        const tag = std.meta.activeTag(any_union);
        return @bitCast(tag);
    }
    pub fn cast_tag(comptime self: OpaqueUnionTag, tag: anytype) self.opaque_type() {
        return @bitCast(@intFromEnum(tag));
    }
    pub fn cast_native_bytes_to_u64_LE(native: []const u8) u64 {
        var u64_bytes: [8]u8 align(8) = @splat(0);
        assert_with_reason(native.len == 1 or native.len == 2 or native.len == 4 or native.len == 8, @src(), "native wrong len", .{});
        @memcpy(u64_bytes[0..native.len], native);
        if (NATIVE_ENDIAN == .BIG_ENDIAN) {
            std.mem.reverse(u8, u64_bytes[0..native.len]);
        }
        return @bitCast(u64_bytes);
    }
};

pub const UnionHeader = struct {
    num_fields: u32,
    tag_type: OpaqueUnionTag,
};

pub const UnionRoutineBuilder = struct {
    meta_data_ops: []DataOp,
    routine_end_op_indexes: []usize,
    parent_field_settings: ?SerialFieldOptionalSettings = null,
    meta_data_ops_root: usize = 0,
    routine_end_slot_idx: usize = 0,
    routine_idx: usize = 0,
    field_count: usize,
    routine_total_ops: usize = 0,
    union_tag_opaque: OpaqueUnionTag,

    fn current_routine_start_op(comptime self: *UnionRoutineBuilder) *UnionRoutineStart {
        return &self.meta_data_ops[(self.routine_idx << 1) + 1].UNION_ROUTINE_START;
    }
    fn current_routine_start_op_true_idx(comptime self: *UnionRoutineBuilder) usize {
        return self.meta_data_ops_root + ((self.routine_idx << 1) + 1);
    }
    fn current_routine_tag_op(comptime self: *UnionRoutineBuilder) *u64 {
        return &self.meta_data_ops[self.routine_idx << 1].UNION_TAG_ID;
    }
    fn current_routine_tag_op_true_idx(comptime self: *UnionRoutineBuilder) usize {
        return self.meta_data_ops_root + (self.routine_idx << 1);
    }
    fn delta_between_current_routine_start_op_idx_and_first_op_in_its_routine(comptime self: *UnionRoutineBuilder, comptime builder: *SerialRoutineBuilder) u32 {
        const true_start = self.current_routine_start_op_true_idx();
        const true_end = builder.ops_len;
        return @intCast(true_end - true_start);
    }

    pub fn add_union_type_provide_settings(comptime self: *UnionRoutineBuilder, comptime builder: *SerialRoutineBuilder, comptime tag_bytes: []const u8, comptime union_native_offset: usize, comptime TYPE: type, comptime settings: SerialFieldSettings) void {
        const prev_serial_offset = builder.curr_serial_offset;
        const prev_routine_ops_idx = builder.ops_len;
        const curr_routine_start = self.current_routine_start_op();
        const curr_tag_id = self.current_routine_tag_op();
        const TAG_OPQ = OpaqueUnionTag.from_byte_len(tag_bytes.len);
        assert_with_reason(TAG_OPQ == self.union_tag_opaque, @src(), "opaque tag param from `tag_value` (`{s}`) does not match the one this union builder was created with (`{s}`)", .{ @tagName(TAG_OPQ), @tagName(self.union_tag_opaque) });
        const tag_u64_le = OpaqueUnionTag.cast_native_bytes_to_u64_LE(tag_bytes);
        curr_routine_start.offset_to_first_routine_op = self.delta_between_current_routine_start_op_idx_and_first_op_in_its_routine(builder);
        curr_tag_id.* = tag_u64_le;
        builder.add_type_provide_settings(union_native_offset, TYPE, settings);
        const this_routine_bytes = builder.curr_serial_offset - prev_serial_offset;
        builder.ensure_space_for_n_more_ops(1);
        builder.ops[builder.ops_len] = .union_routine_end_temp(builder.ops_len, this_routine_bytes);
        self.routine_end_op_indexes[self.routine_end_slot_idx] = @intCast(builder.ops_len);
        builder.ops_len += 1;
        self.routine_end_slot_idx += 1;
        const routine_ops = (builder.ops_len - prev_routine_ops_idx) + 1;
        curr_routine_start.total_num_ops = @intCast(routine_ops);
        self.routine_total_ops += routine_ops;
        self.routine_idx += 1;
        builder.curr_serial_offset = prev_serial_offset;
    }

    pub fn end_union_builder(comptime self: *UnionRoutineBuilder, comptime builder: *SerialRoutineBuilder) void {
        assert_with_reason(self.routine_idx == self.field_count, @src(), "cannot end union serial routine builder: not all field tags had routines specified", .{});
        for (self.routine_end_op_indexes) |routine_end_op_idx| {
            const routine_end: *UnionRoutineEndTemp = &builder.ops[routine_end_op_idx].UNION_ROUTINE_END_TEMP;
            routine_end.finalize(builder.ops_len);
        }
        builder.curr_union_depth -= 1;
        builder.skip_ahead_len -= self.field_count;
        assert_with_reason(builder.subroutines_len > 0 and builder.subroutines[builder.subroutines_len - 1] == .UNION, @src(), "current subroutine was not a union, cannot 'end' a union that isnt started", .{});
        builder.subroutines_len -= 1;
    }
};

pub const RoutineStepKind = enum(u8) {
    BYTE_MOVE,
    UNION_HEADER,
    UNION_SUBROUTINE_OFFSET,
};

pub const PointerMode = enum(u8) {
    /// Pointers in objects to serialize will cause panic at compile time
    DISALLOW_POINTERS,
    /// Pointers in objects to serialize will be ignored and not
    /// serialized
    IGNORE_POINTERS,
    /// Follow pointers and serialize the data they hold, including
    /// any pointers the pointed-to object(s) may contain
    FOLLOW_POINTERS,
};

pub const SaveTagMode = enum(u8) {
    NOT_A_UNION_TAG,
    IS_A_UNION_TAG,
};

pub const SubRoutineMode = enum(u8) {
    UNION,
    SINGLE_POINTER,
    MANY_POINTER,
    SLICE_POINTER,
};

pub const CustomComptimeBuilderRoutineFunc = fn (comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime SETTINGS: SerialFieldSettings) void;
pub const CustomSerializeDecl = "SERIAL_INFO";
pub const CustomSerializeSetting = "OBJECT_SETTINGS";
pub const CustomSerializeFieldSetting = "FIELD_SETTINGS";
pub const SerialFieldOptionalSettingsName = "SerialFieldOptionalSettings";
pub const SerialFieldSettingsName = "SerialFieldSettings";

pub const CustomSerialRoutineMode = enum(u8) {
    NO_CUSTOM_ROUTINE,
    CUSTOM_COMPTIME_BUILDER_ROUTINE,
    CUSTOM_RUNTIME_SERIALIZE,
};

/// Param `self` is a pointer to the object to serialize.
///
/// The return `usize` value is the number of bytes written after `start_index`
pub const CustomWriteToSerialFunc = fn (self: *const anyopaque, serial_dest: SerialDest, start_index: usize) SerialWriteError!usize;
/// Param `self` is a pointer to the object to serialize.
///
/// The return `usize` value is the number of bytes read after `start_index`
pub const CustomReadFromSerialFunc = fn (self: *anyopaque, serial_source: SerialSource, start_index: usize) SerialReadError!usize;

pub const CustomRuntimeSerializeFuncs = struct {
    write_to_serial: *const CustomWriteToSerialFunc,
    read_from_serial: *const CustomReadFromSerialFunc,
};

pub const CustomSerialRoutine = union(CustomSerialRoutineMode) {
    /// Use the default logic for serialization
    NO_CUSTOM_ROUTINE,
    /// Add custom comptime routine builder logic to the `SerialRoutineBuilder`
    CUSTOM_COMPTIME_BUILDER_ROUTINE: CustomComptimeBuilderRoutineFunc,
    /// Run a completely custom function at runtime to serialize this
    /// object, using no comptime-generated bytecode.
    CUSTOM_RUNTIME_SERIALIZE: *const CustomRuntimeSerializeFuncs,
};

pub const SerialFieldOptionalSettings = struct {
    target_endian: ?Endian = null,
    integer_packing: ?IntegerPacking = null,
    allocator_name: ?[]const u8 = null,
    pointer_mode: ?PointerMode = null,
    custom_routine: CustomSerialRoutine = .NO_CUSTOM_ROUTINE,
};

pub fn combine_field_settings(comptime default_settings: SerialFieldSettings, comptime parent_field_settings: ?SerialFieldOptionalSettings, comptime object_settings: ?SerialFieldOptionalSettings) SerialFieldSettings {
    var final_settings = default_settings;
    if (object_settings) |settings| {
        if (settings.allocator_name) |alloc| final_settings.allocator_name = alloc;
        if (settings.integer_packing) |int_pack| final_settings.integer_packing = int_pack;
        if (settings.pointer_mode) |ptr_mode| final_settings.pointer_mode = ptr_mode;
        if (settings.target_endian) |endian| final_settings.target_endian = endian;
        if (settings.custom_routine != .NO_CUSTOM_ROUTINE) final_settings.custom_routine = settings.custom_routine;
    }
    if (parent_field_settings) |settings| {
        if (settings.allocator_name) |alloc| final_settings.allocator_name = alloc;
        if (settings.integer_packing) |int_pack| final_settings.integer_packing = int_pack;
        if (settings.pointer_mode) |ptr_mode| final_settings.pointer_mode = ptr_mode;
        if (settings.target_endian) |endian| final_settings.target_endian = endian;
        if (settings.custom_routine != .NO_CUSTOM_ROUTINE) final_settings.custom_routine = settings.custom_routine;
    }
    return final_settings;
}

pub const SerialFieldSettings = struct {
    target_endian: Endian = .LITTLE_ENDIAN,
    integer_packing: IntegerPacking = .USE_TARGET_ENDIAN,
    allocator_name: []const u8 = DEFAULT_ALLOC_NAME,
    pointer_mode: PointerMode = .DISALLOW_POINTERS,
    custom_routine: CustomSerialRoutine = .NO_CUSTOM_ROUTINE,

    pub fn without_custom_routine(comptime self: SerialFieldSettings) SerialFieldSettings {
        var settings = self;
        settings.custom_routine = .NO_CUSTOM_ROUTINE;
        return settings;
    }
};

pub fn get_on_object_settings(comptime TYPE: type) ?SerialFieldOptionalSettings {
    const KIND = Kind.get_kind(TYPE);
    switch (KIND) {
        .STRUCT, .ENUM, .UNION, .OPAQUE => {
            if (@hasDecl(TYPE, CustomSerializeDecl)) {
                const serial_info = @field(TYPE, CustomSerializeDecl);
                assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_info), @src(), "type `{s}` has a `{s}` declaration, but it is not a structure type (it must be a struct), got type `{s}`", .{ @typeName(TYPE), CustomSerializeDecl, @typeName(@TypeOf(serial_info)) });
                if (@hasDecl(serial_info, CustomSerializeSetting)) {
                    const object_settings = @field(serial_info, CustomSerializeSetting);
                    assert_with_reason(@TypeOf(object_settings) == SerialFieldOptionalSettings, @src(), "type `{s}` has a `{s}.{s}` declaration, but it is not a `SerialFieldSettings`, got type `{s}`", .{ @typeName(TYPE), CustomSerializeDecl, CustomSerializeSetting });
                    return object_settings;
                }
            }
        },
        else => {},
    }
    return null;
}

pub fn get_parent_field_settings(comptime PARENT: ?type, comptime FIELD_ON_PARENT: ?[]const u8) ?SerialFieldOptionalSettings {
    if (PARENT != null or FIELD_ON_PARENT != null) assert_with_reason(PARENT != null and FIELD_ON_PARENT != null, @src(), "if either `PARENT` or `FIELD_ON_PARENT` is not null, the other must also not be null", .{});
    if (PARENT != null and FIELD_ON_PARENT != null and @hasDecl(PARENT.?, CustomSerializeDecl)) {
        const serial_info = @field(PARENT.?, CustomSerializeDecl);
        assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_info), @src(), "type parent `{s}` has a `{s}` declaration, but it is not a structure type (it must be a struct)", .{ @typeName(PARENT.?), CustomSerializeDecl });
        if (@hasDecl(serial_info, CustomSerializeFieldSetting)) {
            const serial_field_settings = @field(serial_info, CustomSerializeFieldSetting);
            assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_field_settings), @src(), "type parent `{s}` has a `{s}.{s}` declaration, but it is not a structure type (it must be a struct, where each decl is of the form `pub const <field on parent>: SerialFieldSettings = <...>;)", .{ @typeName(PARENT.?), CustomSerializeDecl, CustomSerializeFieldSetting });
            if (@hasDecl(serial_field_settings, FIELD_ON_PARENT.?)) {
                const field_settings = @field(serial_field_settings, FIELD_ON_PARENT.?);
                assert_with_reason(@TypeOf(field_settings) == SerialFieldOptionalSettings, @src(), "type parent `{s}` has a `{s}.{s}.{s}` declaration, but it is not a `SerialFieldSettings`, got type `{s}`", .{ @typeName(PARENT.?), CustomSerializeDecl, CustomSerializeFieldSetting, FIELD_ON_PARENT.? });
                return field_settings;
            }
        }
    }
    return null;
}

pub const SerialSettings = struct {
    /// How to pack integers in the serial data.
    ///
    /// When `USE_TARGET_ENDIAN` is chosen, bytes will be packed using the same size as their
    /// native code size, in the target endian byte order.
    ///
    /// When `USE_VARINTS` is chosen, data is compressed such that smaller runtime values require
    /// fewer bytes than the native code type maximum, at the cost of additional processing time.
    INTEGER_BYTE_PACKING: IntegerPacking = .USE_TARGET_ENDIAN,
    /// How to pack float bytes in the serial data. `LITTLE_ENDIAN` is
    /// in most cases the best choice, as most target platforms are natively little-endian, allowing for
    /// faster processing.
    TARGET_ENDIAN: Endian = .LITTLE_ENDIAN,
    /// You may need to set this MUCH higher depending on how complex the object you are serializing
    /// is. A serial routine is created at COMPTIME, and the compiler will tell you with a compiler error
    /// if this needs to be larger.
    ///
    /// This has no effect on the serialization process at runtime.
    COMPTIME_EVAL_QUOTA: u32 = 5000,
    /// For debugging purposes. If you are having issues and you can pinpoint at what byte
    /// serializeation/deserialization is failing, set this to true to maybe get some info back about it
    ADD_ROUTINE_DEBUG_INFO: bool = false,
    /// For debugging purposes. If you are having issues and you can pinpoint at what byte
    /// serializeation/deserialization is failing, you can put that byte index here
    /// to get some info back about it.
    TARGET_DEBUG_INDEX: ?usize = null,
    /// If non-null, include a set of 'magic' bytes at the very start of the serialized data
    /// AND as a constant on the routine serializer
    /// that can be used as a quick identifier for the data being serialized.
    ///
    /// When attempting to read serial data, if the magic id does not match the const
    /// saved on the routine, an `error.magic_identifier_mismatch` will be returned.
    ///
    /// For example, you might use this if you are creating a file format so that
    /// code reading the file data can verify that they are definitely reading the format they are expecting,
    /// OR possibly if a file/network message has multiple possible serial formats
    /// (independant of the format *version*), the consumer can read this value
    /// and choose a code path to evaluate it with using a switch statement.
    ///
    /// (see https://en.wikipedia.org/wiki/List_of_file_signatures)
    ///
    /// You should try to avoid using the same 'magic identifier' as other well-known
    /// magic identifiers *if your format may be used in the same context as those formats*
    /// (if your format will generally not be expected to be used in the same context
    /// as another format with a conflicting identifier, there is no problem using
    /// the same identifier)
    MAGIC_IDENTIFIER: ?[]const u8 = null,
    /// If non-null, this should be the version of the object being serialized,
    /// and this 4-byte version number will be at the beginning of the serial
    /// stream (AFTER the 'magic identifier', if that is also included),
    /// AND will be saved as a constant on the final routine. If there is
    /// a version mismatch between the serial stream and the constant on the
    /// routine, an `error.serial_version_mismatch` will be returned when
    /// deserialization is attempted.
    ///
    /// If you want to support backwards compatibility with older versions,
    /// ANY time you change ANY part of the object to serialize, you should
    /// increase this version number by 1 and retain the old routine
    /// (and probbably the old object too) in your code somewhere.
    ROUTINE_VERSION: ?u32 = null,
    /// Whether to disallow, ignore, or follow pointers and slices:
    ///   - `DISALLOW_POINTERS` = pointers in object to serialize cause panic at comptime
    ///   - `IGNORE_POINTERS` = pointers are ignored and not serialized
    ///   - `FOLLOW_POINTERS` = follow pointers and serialize the data they hold, including
    /// any pointers the pointed-to object(s) may contain
    POINTER_MODE: PointerMode = .DISALLOW_POINTERS,
};

const RefSlice = struct {
    start: u32,
    len: u32,

    pub inline fn hydrate(self: RefSlice, ref_buffer: []u8) []u8 {
        return ref_buffer[self.start..][0..self.len];
    }
};

pub const BuilderBuffers = struct {
    op_buffer: []DataOp,
    union_end_buffer: []usize = &.{},
    alloc_name_buffer: []u8 = &.{},
    alloc_name_list: []RefSlice = &.{},
    subroutine_stack: []SubRoutineMode = &.{},
};

const DEFAULT_ALLOC_NAME = "_DEFAULT_ALLOC_";

pub const SerialRoutineBuilder = struct {
    root_type: ?type = null,
    default_settings: SerialFieldSettings = SerialFieldSettings{
        .target_endian = .LITTLE_ENDIAN,
        .integer_packing = .USE_TARGET_ENDIAN,
        .allocator_name = DEFAULT_ALLOC_NAME,
        .custom_routine = .NO_CUSTOM_ROUTINE,
        .pointer_mode = .DISALLOW_POINTERS,
    },
    alloc_name_buffer: []u8 = &.{},
    alloc_name_buffer_len: usize = 0,
    alloc_name_list: []RefSlice = &.{},
    alloc_name_list_len: usize = 0,
    magic_id: ?[]const u8 = null,
    routine_version: ?u32 = null,
    ops: []DataOp = &.{},
    subroutines: []SubRoutineMode = &.{},
    subroutines_len: usize = 0,
    skip_ahead_stack: []usize = &.{},
    add_debug_info: bool = false,
    debug_stack: []u8 = &.{},
    debug_stack_len: usize = 0,
    debug_target: ?usize = null,
    debug_target_printed: bool = false,
    current_varint_g_bits: u8 = 0,
    prev_varint_g_header_slot: usize = 0,
    ops_len: usize = 0,
    skip_ahead_len: usize = 0,
    curr_serial_offset: usize = 0,
    curr_union_depth: u32 = 0,
    max_union_depth: u32 = 0,
    curr_pointer_depth: u32 = 0,
    max_pointer_depth: u32 = 0,

    pub fn init(comptime buffers: BuilderBuffers) SerialRoutineBuilder {
        return SerialRoutineBuilder{
            .ops = buffers.op_buffer,
            .skip_ahead_stack = buffers.union_end_buffer,
            .alloc_name_buffer = buffers.alloc_name_buffer,
            .alloc_name_list = buffers.alloc_name_list,
            .subroutines = buffers.subroutine_stack,
        };
    }

    pub fn reset(comptime self: *SerialRoutineBuilder) void {
        self.root_type = null;
        self.curr_serial_offset = 0;
        self.skip_ahead_len = 0;
        self.ops_len = 0;
        self.curr_union_depth = 0;
        self.max_union_depth = 0;
        self.debug_stack_len = 0;
        self.debug_target = null;
        self.debug_target_printed = false;
        self.max_union_depth = 0;
        self.curr_union_depth = 0;
        self.routine_version = null;
        self.add_debug_info = false;
        assert_with_reason(self.alloc_name_buffer.len >= DEFAULT_ALLOC_NAME.len, @src(), "`alloc_name_buffer` must be at least {d} bytes in size for the default allocator name `{s}`", .{ DEFAULT_ALLOC_NAME.len, DEFAULT_ALLOC_NAME });
        assert_with_reason(self.alloc_name_list.len >= 1, @src(), "`alloc_name_list` must be at least 1 element in size for the default allocator name `{s}`", .{DEFAULT_ALLOC_NAME});
        @memcpy(self.alloc_name_buffer[0..DEFAULT_ALLOC_NAME.len], DEFAULT_ALLOC_NAME);
        self.alloc_name_list[0] = RefSlice{
            .start = 0,
            .len = @intCast(DEFAULT_ALLOC_NAME.len),
        };
        self.alloc_name_buffer_len = DEFAULT_ALLOC_NAME.len;
        self.alloc_name_list_len = 1;
        self.default_settings.custom_routine = .NO_CUSTOM_ROUTINE;
        self.default_settings.allocator_name = DEFAULT_ALLOC_NAME;
        self.default_settings.pointer_mode = .DISALLOW_POINTERS;
        self.default_settings.target_endian = .LITTLE_ENDIAN;
        self.default_settings.integer_packing = .USE_TARGET_ENDIAN;
    }

    fn d_assert_with_reason(comptime self: *SerialRoutineBuilder, condition: bool, comptime src_loc: ?std.builtin.SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
        if (self.debug_stack_len > 0 and self.debug_stack.len >= self.debug_stack_len) {
            const debug_arg = .{self.debug_stack[0..self.debug_stack_len]};
            assert_with_reason(condition, src_loc, "(DEBUG LOC: {s} )\n" ++ reason_fmt, debug_arg ++ reason_args);
        } else {
            assert_with_reason(condition, src_loc, reason_fmt, reason_args);
        }
    }
    fn d_assert_unreachable(comptime self: *SerialRoutineBuilder, comptime src_loc: ?std.builtin.SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
        if (self.debug_stack_len > 0 and self.debug_stack.len >= self.debug_stack_len) {
            const debug_arg = .{self.debug_stack[0..self.debug_stack_len]};
            assert_unreachable(src_loc, "(DEBUG LOC: {s} )\n" ++ reason_fmt, debug_arg ++ reason_args);
        } else {
            assert_unreachable(src_loc, reason_fmt, reason_args);
        }
    }
    fn print_debug_target(comptime self: *SerialRoutineBuilder, comptime src_loc: ?std.builtin.SourceLocation) void {
        if (!self.debug_target_printed) {
            if (self.debug_target) |target| {
                if (self.curr_serial_offset > target) {
                    self.debug_target_printed = true;
                    assert_unreachable(src_loc, "DEBUG TARGET FOUND:\n\t{s}\n", .{self.debug_stack[0..self.debug_stack_len]});
                }
            }
        }
    }

    fn combine_optional_field_settings(self: *const SerialRoutineBuilder, opt_settings: SerialFieldOptionalSettings) SerialFieldSettings {
        var settings = SerialFieldSettings{};
        settings.target_endian = if (opt_settings.target_endian) |end| end else self.default_settings.target_endian;
        settings.integer_packing = if (opt_settings.integer_packing) |int_pack| int_pack else self.default_settings.integer_packing;
        settings.pointer_mode = if (opt_settings.pointer_mode) |ptr_mode| ptr_mode else self.default_settings.pointer_mode;
        settings.allocator_name = if (opt_settings.allocator_name) |alloc| alloc else self.default_settings.allocator_name;
        settings.custom_routine = if (opt_settings.custom_routine) |routine| routine else self.default_settings.custom_routine;
        return settings;
    }

    fn get_type_settings(self: *const SerialRoutineBuilder, comptime PARENT: ?type, comptime FIELD_ON_PARENT: ?[]const u8, comptime TYPE: type) SerialFieldSettings {
        const parent_field_settings = get_parent_field_settings(PARENT, FIELD_ON_PARENT);
        const on_object_settings = get_on_object_settings(TYPE);
        return combine_field_settings(self.default_settings, parent_field_settings, on_object_settings);
    }

    fn get_type_settings_provide_parent_field_settings(self: *const SerialRoutineBuilder, comptime TYPE: type, comptime PARENT_FIELD_SETTINGS: ?SerialFieldOptionalSettings) SerialFieldSettings {
        const on_object_settings = get_on_object_settings(TYPE);
        return combine_field_settings(self.default_settings, PARENT_FIELD_SETTINGS, on_object_settings);
    }

    fn get_type_settings_provide_on_object_settings(self: *const SerialRoutineBuilder, comptime PARENT: ?type, comptime FIELD_ON_PARENT: ?[]const u8, comptime ON_OBJECT_SETTINGS: ?SerialFieldOptionalSettings) SerialFieldSettings {
        const parent_field_settings = get_parent_field_settings(PARENT, FIELD_ON_PARENT);
        return combine_field_settings(self.default_settings, parent_field_settings, ON_OBJECT_SETTINGS);
    }

    fn find_alloc_name_idx(comptime self: *SerialRoutineBuilder, comptime allocator_name: []const u8) u32 {
        comptime var found_prev: bool = false;
        comptime var alloc_idx: u32 = 0;
        for (self.alloc_name_list[0..self.alloc_name_list_len], 0..) |prev_named_alloc_ref, i| {
            const prev_named_alloc = prev_named_alloc_ref.hydrate(self.alloc_name_buffer);
            if (array_or_slice_equal(prev_named_alloc, allocator_name)) {
                found_prev = true;
                alloc_idx = @intCast(i);
                break;
            }
        }
        if (!found_prev) {
            assert_with_reason(self.alloc_name_list_len < self.alloc_name_list.len, @src(), "ran out of slots for additional named allocators, have {d}, need at least {d}, provide a larger `alloc_name_list` during init", .{ self.alloc_name_list.len, self.alloc_name_list_len + 1 });
            assert_with_reason(self.alloc_name_buffer_len + allocator_name.len <= self.alloc_name_buffer.len, @src(), "ran out of bytes for additional named allocator names, have {d}, need at least {d}, provide a larger `alloc_name_buffer` during init", .{ self.alloc_name_buffer.len, self.alloc_name_buffer_len + allocator_name.len });
            @memcpy(self.alloc_name_buffer[self.alloc_name_buffer_len..][0..allocator_name.len], allocator_name);
            self.alloc_name_list[self.alloc_name_list_len] = RefSlice{
                .start = @intCast(self.alloc_name_buffer_len),
                .len = @intCast(allocator_name.len),
            };
            self.alloc_name_buffer_len += allocator_name.len;
            alloc_idx = @intCast(self.alloc_name_list_len);
            self.alloc_name_list_len += 1;
        }
        return alloc_idx;
    }

    /// This is an un-optimized, comptime-only function that will run the serial/deserial routine on opaque test data to ensure proper operation
    ///
    /// For an optimized runtime method, you must use `SerialRoutineBuilder.finalize()` to produce a concrete serializer type for the current
    /// specific serial object.
    fn test_serialize_internal(comptime self: *SerialRoutineBuilder, comptime native_slice: []u8, comptime serial_slice: []u8, comptime DIRECTION: SER_DIR) usize {
        const serial = if (DIRECTION == .NATIVE_TO_SERIAL) SerialDest{ .slice = serial_slice } else SerialSource{ .slice = serial_slice };
        const num = serial_internal(self.ops_len, self.ops[0..self.ops_len], DIRECTION, .SLICE, native_slice, serial, .ASSERT_DEBUG) catch |err| assert_unreachable_err(@src(), err);
        return num;
    }
    /// This is an un-optimized, comptime-only function that will run the serial routine on opaque test data to ensure proper operation
    ///
    /// For an optimized runtime method, you must use `SerialRoutineBuilder.finalize()` to produce a concrete serializer type for the current
    /// specific serial object.
    pub fn test_serialize(comptime self: *SerialRoutineBuilder, comptime native_bytes: []const u8, comptime serial_slice: []u8) usize {
        const native_slice: []u8 = @constCast(native_bytes);
        return self.test_serialize_internal(native_slice, serial_slice, .NATIVE_TO_SERIAL);
    }
    /// This is an un-optimized, comptime-only function that will run the serial routine on opaque test data to ensure proper operation
    ///
    /// For an optimized runtime method, you must use `SerialRoutineBuilder.finalize()` to produce a concrete serializer type for the current
    /// specific serial object.
    pub fn test_deserialize(comptime self: *SerialRoutineBuilder, comptime serial_bytes: []const u8, comptime native_slice: []u8) usize {
        const serial_slice: []u8 = @constCast(serial_bytes);
        return self.test_serialize_internal(native_slice, serial_slice, .SERIAL_TO_NATIVE);
    }

    pub fn quick_build_and_finalize_serial_routine_for_type(comptime op_buffer: []DataOp, comptime union_end_buffer: []usize, comptime TYPE: type, comptime SETTINGS: SerialSettings) type {
        var builder = init(op_buffer, union_end_buffer);
        return builder.build_and_finalize_serial_routine_for_type(TYPE, SETTINGS);
    }

    pub fn build_routine_for_type(comptime self: *SerialRoutineBuilder, comptime TYPE: type, comptime SETTINGS: SerialSettings) void {
        @setEvalBranchQuota(SETTINGS.COMPTIME_EVAL_QUOTA);
        self.reset();
        self.root_type = TYPE;
        self.debug_target = SETTINGS.TARGET_DEBUG_INDEX;
        self.default_settings.integer_packing = SETTINGS.INTEGER_BYTE_PACKING;
        self.default_settings.target_endian = SETTINGS.TARGET_ENDIAN;
        self.default_settings.pointer_mode = SETTINGS.POINTER_MODE;
        self.add_debug_info = SETTINGS.ADD_ROUTINE_DEBUG_INFO;
        self.magic_id = SETTINGS.MAGIC_IDENTIFIER;
        self.routine_version = SETTINGS.ROUTINE_VERSION;
        self.add_type(0, null, null, TYPE);
    }

    pub fn finalize_routine_for_current_type(comptime self: SerialRoutineBuilder) type {
        comptime var OPS: [self.ops_len]DataOp = undefined;
        @memcpy(OPS[0..], self.ops[0..self.ops_len]);
        for (OPS[0..]) |*op| {
            if (op.* == .UNION_ROUTINE_END_TEMP) {
                op.* = DataOp{ .UNION_ROUTINE_END = op.UNION_ROUTINE_END_TEMP.concrete() };
            }
        }
        const OPS_CONST = OPS;
        return define_serial_routine(self.ops_len, OPS_CONST, self.root_type.?, self.default_settings.target_endian, self.routine_version, self.magic_id);
    }

    pub fn build_and_finalize_serial_routine_for_type(comptime self: *SerialRoutineBuilder, comptime TYPE: type, comptime SETTINGS: SerialSettings) type {
        self.build_routine_for_type(TYPE, SETTINGS);
        return finalize_routine_for_current_type(self.*);
    }

    pub fn ensure_space_for_n_more_ops(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        assert_with_reason(self.ops_len + n <= self.ops.len, @src(), "ran out of space for data ops. Need at least {d} (possibly more), have {d}. provide a larger buffer", .{ self.ops_len + n, self.ops.len });
    }

    pub fn ensure_space_for_n_more_skip_ahead(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        assert_with_reason(self.skip_ahead_len + n <= self.skip_ahead_stack.len, @src(), "ran out of space for skip-ahead index caches. Need at least {d} (possibly more), have {d}. provide a larger buffer", .{ self.skip_ahead_len + n, self.skip_ahead_stack.len });
    }
    pub fn ensure_space_for_n_more_debug_bytes(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        assert_with_reason(self.debug_stack_len + n <= self.debug_stack.len, @src(), "ran out of space for debug info. Need at least {d} bytes (possibly more), have {d}. provide a larger buffer", .{ self.debug_stack_len + n, self.debug_stack.len });
    }

    pub fn add_integer_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime BYTE_LEN: usize, comptime INT_SIGN: IntegerSign, comptime UNION_TAG: SaveTagMode, comptime SETTINGS: SerialFieldSettings) void {
        assert_with_reason(BYTE_LEN > 0, @src(), "cannot add a data type to serialze that has zero size", .{});
        assert_with_reason(BYTE_LEN <= 8129, @src(), "integers can never be larger than 8129 bytes long (65536 bits, 8KiB), got byte len {d}", .{BYTE_LEN});
        with_new_mode: switch (SETTINGS.integer_packing) {
            .USE_TARGET_ENDIAN => {
                self.ensure_space_for_n_more_ops(1);
                const SWAP = NATIVE_ENDIAN != SETTINGS.target_endian;
                const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
                if (SWAP and BYTE_LEN > 1) {
                    switch (UNION_TAG) {
                        .IS_A_UNION_TAG => self.ops[self.ops_len] = .mem_move_swap_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                        .NOT_A_UNION_TAG => self.ops[self.ops_len] = .mem_move_swap(native_to_serial_delta, @intCast(BYTE_LEN)),
                    }
                    self.ops_len += 1;
                    self.curr_serial_offset += num_cast(BYTE_LEN, i32);
                } else {
                    const has_prev = self.ops_len > 0;
                    comptime var prev: DataOp = DataOp.mem_move_swap(0, 2);
                    if (has_prev) {
                        prev = self.ops[self.ops_len - 1];
                    }
                    const next = switch (UNION_TAG) {
                        .IS_A_UNION_TAG => DataOp.mem_move_no_swap_save_tag(native_to_serial_delta, BYTE_LEN),
                        .NOT_A_UNION_TAG => DataOp.mem_move_no_swap(native_to_serial_delta, BYTE_LEN),
                    };
                    if (prev.can_combine(next)) |combined| {
                        self.ops[self.ops_len - 1] = combined;
                    } else {
                        self.ops[self.ops_len] = next;
                        self.ops_len += 1;
                    }
                    self.curr_serial_offset += num_cast(BYTE_LEN, i32);
                }
            },
            .USE_VARINTS => {
                if (BYTE_LEN == 1 or BYTE_LEN == 3 or (BYTE_LEN >= 5 and BYTE_LEN <= 7) or (BYTE_LEN >= 9 and BYTE_LEN <= 15) or BYTE_LEN > 16) {
                    continue :with_new_mode .USE_TARGET_ENDIAN;
                }
                const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
                switch (UNION_TAG) {
                    .IS_A_UNION_TAG => switch (INT_SIGN) {
                        .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                        .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                    },
                    .NOT_A_UNION_TAG => switch (INT_SIGN) {
                        .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p(native_to_serial_delta, @intCast(BYTE_LEN)),
                        .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps(native_to_serial_delta, @intCast(BYTE_LEN)),
                    },
                }
                self.ops_len += 1;
            },
        }
    }

    pub fn add_float_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime BYTE_LEN: usize, comptime SETTINGS: SerialFieldSettings) void {
        assert_with_reason(BYTE_LEN > 0, @src(), "cannot add a data type to serialze that has zero size", .{});
        const ENDIAN = SETTINGS.target_endian;
        self.ensure_space_for_n_more_ops(1);
        const SWAP = NATIVE_ENDIAN != ENDIAN;
        const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
        if (SWAP and BYTE_LEN > 1) {
            self.ops[self.ops_len] = .mem_move_swap(native_to_serial_delta, @intCast(BYTE_LEN));
            self.ops_len += 1;
            self.curr_serial_offset += num_cast(BYTE_LEN, i32);
        } else {
            const has_prev = self.ops_len > 0;
            comptime var prev: DataOp = DataOp.mem_move_swap(0, 2);
            if (has_prev) {
                prev = self.ops[self.ops_len - 1];
            }
            const next = DataOp.mem_move_no_swap(native_to_serial_delta, BYTE_LEN);
            if (prev.can_combine(next)) |combined| {
                self.ops[self.ops_len - 1] = combined;
            } else {
                self.ops[self.ops_len] = next;
                self.ops_len += 1;
            }
            self.curr_serial_offset += num_cast(BYTE_LEN, i32);
        }
    }

    pub fn start_union_routine_builder(comptime self: *SerialRoutineBuilder, comptime tag_native_offset: usize, comptime TAG_TYPE: type, comptime FIELD_COUNT: usize, comptime settings: SerialFieldSettings) UnionRoutineBuilder {
        const UTAG = OpaqueUnionTag.from_tag_type(TAG_TYPE);
        const UTAG_SIZE = UTAG.bytes_usize();
        const META_SLOT_COUNT = (FIELD_COUNT << 1);
        self.ensure_space_for_n_more_ops(2 + META_SLOT_COUNT);
        self.ensure_space_for_n_more_skip_ahead(FIELD_COUNT);
        const skip_ahead_slots: []usize = self.skip_ahead_stack[self.skip_ahead_len..][0..FIELD_COUNT];
        self.skip_ahead_len += FIELD_COUNT;
        self.ops[self.ops_len] = .union_header(FIELD_COUNT, TAG_TYPE);
        self.ops_len += 1;
        const is_signed = Types.type_is_signed_int(std.meta.Tag(TAG_TYPE));
        const SIGN = if (is_signed) IntegerSign.SIGNED else IntegerSign.UNSIGNED;
        self.add_integer_bytes(tag_native_offset, UTAG_SIZE, SIGN, .IS_A_UNION_TAG, settings);
        const meta_slots: []DataOp, const meta_root: usize = self.add_union_meta_slots(META_SLOT_COUNT);
        comptime var tag_to_routine_offset: usize = META_SLOT_COUNT;
        comptime var tag_to_routine_idx: usize = 0;
        while (tag_to_routine_idx < FIELD_COUNT) {
            const real_idx = tag_to_routine_idx << 1;
            meta_slots[real_idx] = .union_tag_id(0);
            meta_slots[real_idx + 1] = .union_routine_start(tag_to_routine_offset - 1, 0);
            tag_to_routine_offset -= 2;
            tag_to_routine_idx += 1;
        }
        self.curr_union_depth += 1;
        self.max_union_depth = @max(self.max_union_depth, self.curr_union_depth);
        assert_with_reason(self.subroutines_len < self.subroutines.len, @src(), "ran out of slots for subroutine tags on the subroutine stack, have capacity for {d}, need at least {d}, provide a larger `subroutine_stack` at init", .{ self.subroutines.len, self.subroutines_len + 1 });
        self.subroutines[self.subroutines_len] = .UNION;
        self.subroutines_len += 1;
        return UnionRoutineBuilder{
            .meta_data_ops = meta_slots,
            .meta_data_ops_root = meta_root,
            .union_tag_opaque = UTAG,
            .field_count = FIELD_COUNT,
            .routine_end_op_indexes = skip_ahead_slots,
        };
    }

    pub fn add_union_meta_slots(comptime self: *SerialRoutineBuilder, comptime COUNT: usize) struct { []DataOp, usize } {
        self.ensure_space_for_n_more_ops(COUNT);
        const start = self.ops_len;
        self.ops_len += COUNT;
        return .{ self.ops.ptr[start..self.ops_len], start };
    }

    pub fn add_type_provide_settings(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime TYPE: type, comptime settings: SerialFieldSettings) void {
        const INFO = KindInfo.get_kind_info(TYPE);
        switch (settings.custom_routine) {
            .CUSTOM_RUNTIME_SERIALIZE => |runtime_funcs| {
                self.ensure_space_for_n_more_ops(1);
                self.ops[self.ops_len] = DataOp.fully_custom_functions(runtime_funcs);
                self.ops_len += 1;
                return;
            },
            .CUSTOM_COMPTIME_BUILDER_ROUTINE => |builder_routine| {
                builder_routine(self, curr_native_offset, settings);
                return;
            },
            .NO_CUSTOM_ROUTINE => {
                re_typed: switch (INFO) {
                    .INT, .BOOL, .ENUM => {
                        // TODO re-implement debug with tree
                        const is_signed = INFO != .BOOL and if (INFO == .INT) Types.type_is_signed_int(TYPE) else Types.type_is_signed_int(std.meta.Tag(TYPE));
                        const SIGN = if (is_signed) IntegerSign.SIGNED else IntegerSign.UNSIGNED;
                        self.add_integer_bytes(curr_native_offset, @sizeOf(TYPE), SIGN, .NOT_A_UNION_TAG, settings);
                    },
                    .FLOAT => {
                        // TODO re-implement debug with tree
                        self.add_float_bytes(curr_native_offset, @sizeOf(TYPE), settings);
                    },
                    .ARRAY, .VECTOR => {
                        const LEN = if (INFO.is_array()) INFO.ARRAY.len else INFO.VECTOR.len;
                        const CHILD = if (INFO.is_array()) INFO.ARRAY.child else INFO.VECTOR.child;
                        const CHILD_SIZE = @sizeOf(CHILD);
                        // TODO re-implement debug with tree
                        comptime var local_native_offset = curr_native_offset;
                        for (0..LEN) |_| {
                            self.add_type(local_native_offset, null, null, CHILD);
                            local_native_offset += CHILD_SIZE;
                        }
                    },
                    .STRUCT => |S| {
                        if (S.backing_integer) |backing_int| {
                            continue :re_typed KindInfo.get_kind_info(backing_int);
                        } else {
                            // TODO re-implement debug with tree
                            inline for (S.fields) |field| {
                                // TODO re-implement debug with tree
                                const local_offset = @offsetOf(TYPE, field.name);
                                const real_offset = curr_native_offset + local_offset;
                                self.add_type(real_offset, TYPE, field.name, field.type);
                            }
                        }
                    },
                    // .POINTER => |PTR| {
                    //     switch (settings.pointer_mode) {
                    //         .DISALLOW_POINTERS => assert_unreachable(@src(), "pointers are not allowed in this serial object according to the pointer mode setting", .{}),
                    //         .IGNORE_POINTERS => return,
                    //         .FOLLOW_POINTERS => {},
                    //     }
                    //     switch (PTR.size) {
                    //         .one => {},
                    //         .c => {},
                    //         .many => {
                    //             assert_with_reason(PTR.sentinel_ptr != null, @src(), "cannot serialize a many-item pointer without a sentinel value, got type `{s}`", .{@typeName(TYPE)});
                    //         },
                    //         .slice => {},
                    //     }
                    // },
                    // .OPTIONAL => |OPT| {
                    //     const CHILD_KIND = Kind.get_kind(OPT.child);
                    //     switch (CHILD_KIND) {
                    //         .POINTER => |PTR| {},
                    //     }
                    // },
                    .UNION => {
                        assert_unreachable(@src(), "unions are not supported for *automatic* serialization. You must do one of the following instead:\n\t- Include a declaration of `{s}.{s}` (type of {s}) on the union, with a `custom_routine` value that is not `.NO_CUSTOM_ROUTINE`\n\t- Include a declaration of `{s}.{s}` (struct type) on the parent object that holds the union (if any), and have a declaration on it that matches this union's field name that is a `{s}` with a `custom_routine` value that is not `.NO_CUSTOM_ROUTINE`\n\t- Use `SerialUnion`, which is an extern struct that implements a custom serialize function", .{ CustomSerializeDecl, CustomSerializeSetting, SerialFieldOptionalSettingsName, CustomSerializeDecl, CustomSerializeFieldSetting, SerialFieldOptionalSettingsName });
                    },
                    else => assert_unreachable(@src(), "type kind `{s}` does not have a serializer (simple) routine, exact type is `{s}`", .{ @tagName(INFO), @typeName(TYPE) }),
                }
            },
        }
    }

    pub fn add_type(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime PARENT: ?type, comptime FIELD_ON_PARENT: ?[]const u8, comptime TYPE: type) void {
        const settings = self.get_type_settings(PARENT, FIELD_ON_PARENT, TYPE);
        return self.add_type_provide_settings(curr_native_offset, TYPE, settings);
    }
};

const SER_DIR = enum(u8) {
    NATIVE_TO_SERIAL,
    SERIAL_TO_NATIVE,
};
const SER_TECH = enum(u8) {
    NORMAL,
    VARINT_P,
};

const TEST_SER_MODE = enum(u8) {
    NORMAL,
    NEED_UNION_TAG_CAPTURE_NEXT,
    NEED_UNION_TAG_ID_NEXT,
    NEED_UNION_START_NEXT,

    fn assert_mode(self: TEST_SER_MODE, need: TEST_SER_MODE, op: OpKind, comptime SHOULD_ASSERT: bool, comptime src: std.builtin.SourceLocation) void {
        if (SHOULD_ASSERT) assert_with_reason(self == need, src, "op `{s}` is not allowed when mode is not `{s}`, got mode `{s}`", .{ @tagName(op), @tagName(need), @tagName(self) });
    }
};

pub const VersionMatch = enum(u8) {
    MATCH,
    SERIAL_VERSION_LOWER,
    SERIAL_VERSION_HIGHER,
};

/// USE WITH CAUTION! This performs NO safety checking/validation and assumes the routine is well-formed
///
/// The normal, safe way to get a concrete serial routine is to use a `SerialRoutineBuilder` and use one of the `finalize()` funcs on it.
pub fn define_serial_routine(comptime TOTAL_OPS_: usize, comptime ROUTINE_: [TOTAL_OPS_]DataOp, comptime TYPE_: type, comptime TARGET_ENDIAN_: Endian, comptime VERSION_: ?u32, comptime MAGIC_: ?[]const u8) type {
    return struct {
        pub const TOTAL_OPS = TOTAL_OPS_;
        pub const TYPE = TYPE_;
        pub const TARGET_ENDIAN = TARGET_ENDIAN_;
        pub const ROUTINE = ROUTINE_;
        pub const VERSION = VERSION_;
        pub const ID_LEN = if (MAGIC_) |ID| ID.len else 0;
        pub const MAGIC_ID: ?[ID_LEN]u8 = build: {
            if (MAGIC_ == null) break :build null;
            var id: [ID_LEN]u8 = undefined;
            @memcpy(id[0..], MAGIC_.?);
            break :build id;
        };
        pub const DATA_START = ID_LEN + (if (VERSION != null) 4 else 0);
        pub const VER_START = (if (MAGIC_ID) |ID| ID.len else 0);

        pub fn id_matches_slice(serial_slice: []const u8) SerialReadError!bool {
            if (MAGIC_ID) |ID| {
                if (serial_slice.len < ID.len) return SerialReadError.serial_source_ran_out_of_data;
                return array_or_slice_equal(ID, serial_slice[0..ID.len]);
            } else {
                return true;
            }
        }
        pub fn version_matches_slice(serial_slice: []const u8) SerialReadError!VersionMatch {
            if (VERSION) |VER| {
                const ver_from_serial = try get_version_from_slice(serial_slice);
                if (VER == ver_from_serial) {
                    return VersionMatch.MATCH;
                } else if (ver_from_serial < VER) {
                    return VersionMatch.SERIAL_VERSION_LOWER;
                } else {
                    return VersionMatch.SERIAL_VERSION_HIGHER;
                }
            } else {
                return VersionMatch.MATCH;
            }
        }
        /// Returns `0` if the routine has no version
        pub fn get_version_from_slice(serial_slice: []const u8) SerialReadError!u32 {
            if (VERSION != null) {
                if (serial_slice.len < VER_START + 4) return SerialReadError.serial_source_ran_out_of_data;
                var ver_from_serial: u32 = undefined;
                var ver_bytes = ptr_as_bytes(&ver_from_serial);
                @memcpy(ver_bytes[0..4], serial_slice[VER_START .. VER_START + 4]);
                if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
                    reverse_array(ver_bytes);
                }
                return ver_from_serial;
            }
            return 0;
        }
        /// Returns `0` if the routine has no version
        ///
        /// Routine must have NO magic identifier, or You MUST have called `get_id_from_reader`
        /// FIRST before calling this, even if you do not use the id value
        pub fn get_version_from_reader(reader: *std.Io.Reader) SerialReadError!u32 {
            if (VERSION != null) {
                const bytes: [DATA_START]u8 = undefined;
                reader.readSliceAll(bytes[VER_START..DATA_START]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                return get_version_from_slice(bytes);
            }
            return 0;
        }

        /// Returns `[0]u8{}` if the routine has no id
        pub fn get_id_from_slice(serial_slice: []const u8) SerialReadError![ID_LEN]u8 {
            if (MAGIC_ID != null) {
                if (serial_slice.len < ID_LEN) return SerialReadError.serial_source_ran_out_of_data;
                var id: [ID_LEN]u8 = undefined;
                @memcpy(id[0..ID_LEN], serial_slice[0..ID_LEN]);
                return id;
            }
            return .{};
        }

        /// Returns `[0]u8{}` if the routine has no id
        ///
        /// You MUST call this before calling `get_version_from_reader`,
        /// even if you do not need to use the value
        pub fn get_id_from_reader(reader: *std.Io.Reader) SerialReadError![ID_LEN]u8 {
            if (MAGIC_ID != null) {
                var id: [ID_LEN]u8 = undefined;
                reader.readSliceAll(id[0..ID_LEN]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                return id;
            }
            return .{};
        }

        pub fn serialize_to_slice(val_ptr: *const TYPE, serial_slice: []u8) SerialWriteError!usize {
            const native: []u8 = @alignCast(@constCast(std.mem.asBytes(val_ptr)));
            if (MAGIC_ID) |ID| {
                @memcpy(serial_slice[0..ID.len], ID[0..]);
            }
            if (VERSION) |VER| {
                var ver_to_serial: u32 = VER;
                var ver_bytes = ptr_as_bytes(&ver_to_serial);
                if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
                    reverse_array(ver_bytes);
                }
                @memcpy(serial_slice[VER_START .. VER_START + 4], ver_bytes[0..4]);
            }
            return DATA_START + try serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .NATIVE_TO_SERIAL, .SLICE, native, SerialDest{ .slice = serial_slice[DATA_START..] }, .NO_DEBUG);
        }
        pub fn serialize_to_writer(val_ptr: *const TYPE, writer: *std.Io.Writer) SerialWriteError!usize {
            const native: []u8 = @alignCast(@constCast(std.mem.asBytes(val_ptr)));
            if (MAGIC_ID) |ID| {
                writer.writeAll(ID) catch return SerialWriteError.serial_destination_ran_out_of_space;
            }
            if (VERSION) |VER| {
                var ver_to_serial: u32 = VER;
                var ver_bytes = ptr_as_bytes(&ver_to_serial);
                if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
                    reverse_array(ver_bytes);
                }
                writer.writeAll(ver_bytes[0..4]) catch return SerialWriteError.serial_destination_ran_out_of_space;
            }
            return DATA_START + try serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .NATIVE_TO_SERIAL, .READER_WRITER, native, SerialDest{ .writer = writer }, .NO_DEBUG);
        }
        pub fn deserialize_from_slice(serial_data: []const u8, val_ptr: *TYPE) SerialReadError!usize {
            const native: []u8 = @alignCast(std.mem.asBytes(val_ptr));
            if (!try id_matches_slice(serial_data)) return SerialReadError.magic_identifier_mismatch;
            switch (try version_matches_slice(serial_data)) {
                .MATCH => {},
                .SERIAL_VERSION_HIGHER => return SerialReadError.serial_version_mismatch_higher,
                .SERIAL_VERSION_LOWER => return SerialReadError.serial_version_mismatch_lower,
            }
            return DATA_START + try serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .SERIAL_TO_NATIVE, .SLICE, native, SerialSource{ .slice = serial_data[DATA_START..] }, .NO_DEBUG);
        }
        pub fn deserialize_from_reader(reader: *std.Io.Reader, val_ptr: *TYPE) SerialReadError!usize {
            var pre_read: [DATA_START]u8 = undefined;
            if (MAGIC_ID != null) {
                reader.readSliceAll(pre_read[0..VER_START]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                if (!(id_matches_slice(pre_read) catch unreachable)) return SerialReadError.magic_identifier_mismatch;
            }
            if (VERSION != null) {
                reader.readSliceAll(pre_read[VER_START..DATA_START]) catch |err| switch (err) {
                    .ReadFailed => return SerialReadError.unknown_read_error,
                    .EndOfStream => return SerialReadError.serial_source_ran_out_of_data,
                };
                switch (version_matches_slice(pre_read) catch unreachable) {
                    .MATCH => {},
                    .SERIAL_VERSION_HIGHER => return SerialReadError.serial_version_mismatch_higher,
                    .SERIAL_VERSION_LOWER => return SerialReadError.serial_version_mismatch_lower,
                }
            }
            const native: []u8 = @alignCast(std.mem.asBytes(val_ptr));
            return DATA_START + try serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .SERIAL_TO_NATIVE, .READER_WRITER, native, SerialSource{ .reader = reader }, .NO_DEBUG);
        }
    };
}

fn do_zigzag_adjustment(comptime NATIVE_SIZE: comptime_int, temp_buffer: *align(@alignOf(u128)) [NATIVE_SIZE]u8, comptime DIR: SER_DIR) void {
    assert_with_reason(NATIVE_SIZE == 2 or NATIVE_SIZE == 4 or NATIVE_SIZE == 8 or NATIVE_SIZE == 16, @src(), "zigzag encoding only supported for i16, i32, i64, isize, and i128, got native integer with {d} bytes", .{NATIVE_SIZE});
    switch (DIR) {
        .NATIVE_TO_SERIAL => switch (NATIVE_SIZE) {
            2 => {
                const int: *align(@alignOf(u128)) i16 = @ptrCast(@alignCast(temp_buffer));
                int.* = (int.* >> 15) ^ (int.* << 1);
            },
            4 => {
                const int: *align(@alignOf(u128)) i32 = @ptrCast(@alignCast(temp_buffer));
                int.* = (int.* >> 31) ^ (int.* << 1);
            },
            8 => {
                const int: *align(@alignOf(u128)) i64 = @ptrCast(@alignCast(temp_buffer));
                int.* = (int.* >> 63) ^ (int.* << 1);
            },
            16 => {
                const int: *align(@alignOf(u128)) i128 = @ptrCast(@alignCast(temp_buffer));
                int.* = (int.* >> 127) ^ (int.* << 1);
            },
            else => unreachable,
        },
        .SERIAL_TO_NATIVE => switch (NATIVE_SIZE) {
            2 => {
                const int: *align(@alignOf(u128)) i16 = @ptrCast(@alignCast(temp_buffer));
                const uint: *align(@alignOf(u128)) u16 = @ptrCast(@alignCast(temp_buffer));
                int.* = bit_cast(uint.* >> 1, i16) ^ -(bit_cast(uint.*, i16) & 1);
            },
            4 => {
                const int: *align(@alignOf(u128)) i32 = @ptrCast(@alignCast(temp_buffer));
                const uint: *align(@alignOf(u128)) u32 = @ptrCast(@alignCast(temp_buffer));
                int.* = bit_cast(uint.* >> 1, i32) ^ -(bit_cast(uint.*, i32) & 1);
            },
            8 => {
                const int: *align(@alignOf(u128)) i64 = @ptrCast(@alignCast(temp_buffer));
                const uint: *align(@alignOf(u128)) u64 = @ptrCast(@alignCast(temp_buffer));
                int.* = bit_cast(uint.* >> 1, i64) ^ -(bit_cast(uint.*, i64) & 1);
            },
            16 => {
                const int: *align(@alignOf(u128)) i128 = @ptrCast(@alignCast(temp_buffer));
                const uint: *align(@alignOf(u128)) u128 = @ptrCast(@alignCast(temp_buffer));
                int.* = bit_cast(uint.* >> 1, i128) ^ -(bit_cast(uint.*, i128) & 1);
            },
            else => unreachable,
        },
    }
}

fn more_sig(comptime start: comptime_int, comptime move: comptime_int) comptime_int {
    if (NATIVE_ENDIAN == .BIG_ENDIAN) {
        return start - move;
    } else {
        return start + move;
    }
}
fn less_sig(comptime start: comptime_int, comptime move: comptime_int) comptime_int {
    if (NATIVE_ENDIAN == .BIG_ENDIAN) {
        return start + move;
    } else {
        return start - move;
    }
}

const NNSS = struct { usize, usize, usize, usize };

fn make_starts_and_ends(serial_idx: isize, native_len: u32, native_to_serial_delta: i32, dynamic_serial_adjustment: isize, comptime DEBUG_MODE: DebugMode) NNSS {
    const native_start_i: isize = serial_idx - (num_cast(native_to_serial_delta, isize) + dynamic_serial_adjustment);
    if (DEBUG_MODE == .ASSERT_DEBUG) {
        assert_with_reason(native_start_i >= 0, @src(), "`native_start = serial_idx - (native_to_serial_delta + dynamic_serial_adjustment)` causes `native_start` to be less than zero\n`{d} = {d} - ({d} + {d})`", .{ native_start_i, serial_idx, native_to_serial_delta, dynamic_serial_adjustment });
    }
    const native_start: usize = @intCast(native_start_i);
    const native_end = native_start + num_cast(native_len, usize);
    const serial_start = num_cast(serial_idx, usize);
    const serial_end = serial_start + num_cast(native_len, usize);
    return NNSS{ native_start, native_end, serial_start, serial_end };
}

fn move_data_no_swap(comptime DIR: SER_DIR, comptime SERIAL: SerialKind, move: MemCopyMove, serial_idx: *isize, dynamic_serial_adjustment: isize, native: []u8, serial: if (DIR == .SERIAL_TO_NATIVE) SerialSource else SerialDest, comptime DEBUG_MODE: DebugMode) (if (DIR == .SERIAL_TO_NATIVE) SerialReadError else SerialWriteError)!NNSS {
    const nnss = make_starts_and_ends(serial_idx.*, move.copy_len, move.native_to_serial_delta, dynamic_serial_adjustment, DEBUG_MODE);
    const native_start: usize, const native_end: usize, const serial_start: usize, const serial_end: usize = nnss;
    switch (DIR) {
        .NATIVE_TO_SERIAL => {
            try serial.write_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
        },
        .SERIAL_TO_NATIVE => {
            try serial.read_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
        },
    }
    serial_idx.* += num_cast(move.copy_len, isize);
    return nnss;
}

fn move_data_swap(comptime DIR: SER_DIR, comptime SERIAL: SerialKind, move: MemCopyMove, serial_idx: *isize, dynamic_serial_adjustment: isize, native: []u8, serial: if (DIR == .SERIAL_TO_NATIVE) SerialSource else SerialDest, comptime DEBUG_MODE: DebugMode) (if (DIR == .SERIAL_TO_NATIVE) SerialReadError else SerialWriteError)!NNSS {
    const nnss = make_starts_and_ends(serial_idx.*, move.copy_len, move.native_to_serial_delta, dynamic_serial_adjustment, DEBUG_MODE);
    const native_start: usize, const native_end: usize, const serial_start: usize, const serial_end: usize = nnss;
    switch (DIR) {
        .NATIVE_TO_SERIAL => {
            try serial.write_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
        },
        .SERIAL_TO_NATIVE => {
            try serial.read_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
        },
    }
    serial_idx.* += num_cast(move.copy_len, isize);
    return nnss;
}

fn move_data_varint(comptime DIR: SER_DIR, comptime SERIAL: SerialKind, comptime SIGNED: IntegerSign, move: MemCopyMove, serial_idx: *isize, dynamic_serial_adjustment: *isize, native: []u8, serial: if (DIR == .SERIAL_TO_NATIVE) SerialSource else SerialDest, comptime DEBUG_MODE: DebugMode) (if (DIR == .SERIAL_TO_NATIVE) SerialReadError else SerialWriteError)!NNSS {
    const nnss = make_starts_and_ends(serial_idx.*, move.copy_len, move.native_to_serial_delta, dynamic_serial_adjustment.*, DEBUG_MODE);
    const native_start: usize, const native_end: usize, const serial_start: usize, _ = nnss;
    const num_bytes = switch (DIR) {
        .NATIVE_TO_SERIAL => switch (SIGNED) {
            .SIGNED => try serial.write_varint(SERIAL, true, native, native_start, native_end, @intCast(move.copy_len), serial_start),
            .UNSIGNED => try serial.write_varint(SERIAL, false, native, native_start, native_end, @intCast(move.copy_len), serial_start),
        },
        .SERIAL_TO_NATIVE => switch (SIGNED) {
            .SIGNED => try serial.read_varint(SERIAL, true, native, native_start, native_end, @intCast(move.copy_len), serial_start),
            .UNSIGNED => try serial.read_varint(SERIAL, false, native, native_start, native_end, @intCast(move.copy_len), serial_start),
        },
    };
    serial_idx.* += num_cast(num_bytes, isize);
    dynamic_serial_adjustment.* += num_cast(num_bytes, isize);
    return nnss;
}

fn save_tag(tag_got: *u64, native: []u8, native_start: usize, native_end: usize) void {
    tag_got.* = OpaqueUnionTag.cast_native_bytes_to_u64_LE(native[native_start..native_end]);
}

fn serial_internal(comptime NUM_OPS: usize, comptime ROUTINE: []const DataOp, comptime DIR: SER_DIR, comptime SERIAL: SerialKind, native: []u8, serial: if (DIR == .SERIAL_TO_NATIVE) SerialSource else SerialDest, comptime DEBUG_MODE: DebugMode) (if (DIR == .SERIAL_TO_NATIVE) SerialReadError else SerialWriteError)!usize {
    var serial_idx: isize = 0;
    var tag_got: u64 = undefined;
    var num_tags_this_union: u32 = 0;
    var tags_checked_this_union: u32 = 0;
    var op_idx: usize = 0;
    var dynamic_serial_adjustment: isize = 0;
    const DO_DEBUG = DEBUG_MODE == .ASSERT_DEBUG;
    var MODE: if (DO_DEBUG) TEST_SER_MODE else void = if (DO_DEBUG) .NORMAL else void{};
    var union_ends_allowed: if (DO_DEBUG) usize else void = if (DO_DEBUG) 0 else void{};
    while (op_idx < NUM_OPS) {
        const op = ROUTINE[op_idx];
        switch (op) {
            .MOVE_DATA_NO_SWAP => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .MOVE_DATA_NO_SWAP, DO_DEBUG, @src());
                }
                _ = try move_data_no_swap(DIR, SERIAL, move, &serial_idx, dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                op_idx += 1;
            },
            .MOVE_DATA_NO_SWAP_SAVE_TAG => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_TAG_CAPTURE_NEXT, .MOVE_DATA_NO_SWAP_SAVE_TAG, DO_DEBUG, @src());
                }
                const native_start: usize, const native_end: usize, _, _ = try move_data_no_swap(DIR, SERIAL, move, &serial_idx, dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                save_tag(&tag_got, native, native_start, native_end);
                op_idx += 1;
                if (DO_DEBUG) {
                    MODE = .NEED_UNION_TAG_ID_NEXT;
                }
            },
            .MOVE_DATA_SWAP => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .MOVE_DATA_SWAP, DO_DEBUG, @src());
                }
                _ = try move_data_swap(DIR, SERIAL, move, &serial_idx, dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                op_idx += 1;
            },
            .MOVE_DATA_SWAP_SAVE_TAG => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_TAG_CAPTURE_NEXT, .MOVE_DATA_SWAP_SAVE_TAG, DO_DEBUG, @src());
                }
                const native_start: usize, const native_end: usize, _, _ = try move_data_swap(DIR, SERIAL, move, &serial_idx, dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                save_tag(&tag_got, native, native_start, native_end);
                op_idx += 1;
                if (DO_DEBUG) {
                    MODE = .NEED_UNION_TAG_ID_NEXT;
                }
            },
            .MOVE_DATA_VARINT_P => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .MOVE_DATA_VARINT_P, DO_DEBUG, @src());
                }
                _ = try move_data_varint(DIR, SERIAL, .UNSIGNED, move, &serial_idx, &dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                op_idx += 1;
            },
            .MOVE_DATA_VARINT_P_SAVE_TAG => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_TAG_CAPTURE_NEXT, .MOVE_DATA_VARINT_P_SAVE_TAG, DO_DEBUG, @src());
                }
                const native_start: usize, const native_end: usize, _, _ = try move_data_varint(DIR, SERIAL, .UNSIGNED, move, &serial_idx, &dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                save_tag(&tag_got, native, native_start, native_end);
                op_idx += 1;
                if (DO_DEBUG) {
                    MODE = .NEED_UNION_TAG_ID_NEXT;
                }
            },
            .MOVE_DATA_VARINT_PS => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .MOVE_DATA_VARINT_PS, DO_DEBUG, @src());
                }
                _ = try move_data_varint(DIR, SERIAL, .SIGNED, move, &serial_idx, &dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                op_idx += 1;
            },
            .MOVE_DATA_VARINT_PS_SAVE_TAG => |move| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_TAG_CAPTURE_NEXT, .MOVE_DATA_VARINT_PS_SAVE_TAG, DO_DEBUG, @src());
                }
                const native_start: usize, const native_end: usize, _, _ = try move_data_varint(DIR, SERIAL, .SIGNED, move, &serial_idx, &dynamic_serial_adjustment, native, serial, DEBUG_MODE);
                save_tag(&tag_got, native, native_start, native_end);
                op_idx += 1;
                if (DO_DEBUG) {
                    MODE = .NEED_UNION_TAG_ID_NEXT;
                }
            },
            .UNION_HEADER => |header| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .UNION_HEADER, DO_DEBUG, @src());
                }
                num_tags_this_union = header.num_fields;
                tags_checked_this_union = 0;
                op_idx += 1;
                if (DO_DEBUG) {
                    MODE = .NEED_UNION_TAG_CAPTURE_NEXT;
                }
            },
            .UNION_TAG_ID => |tag_match| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_TAG_ID_NEXT, .UNION_TAG_ID, DO_DEBUG, @src());
                }

                if (tag_got == tag_match) {
                    op_idx += 1;
                    if (DO_DEBUG) {
                        MODE = .NEED_UNION_START_NEXT;
                    }
                } else {
                    op_idx += 2;
                    tags_checked_this_union += 1;
                    if (tags_checked_this_union >= num_tags_this_union) switch (DIR) {
                        .NATIVE_TO_SERIAL => return SerialWriteError.union_tag_in_native_didnt_match_any_valid_tag,
                        .SERIAL_TO_NATIVE => return SerialReadError.union_tag_in_serial_didnt_match_any_valid_tag,
                    };
                }
            },
            .UNION_ROUTINE_START => |routine_start| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NEED_UNION_START_NEXT, .UNION_ROUTINE_START, DO_DEBUG, @src());
                }
                op_idx += routine_start.offset_to_first_routine_op;
                if (DO_DEBUG) {
                    union_ends_allowed += 1;
                    MODE = .NORMAL;
                }
            },
            .UNION_ROUTINE_END => |routine_end| {
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .UNION_ROUTINE_END, DO_DEBUG, @src());
                    assert_with_reason(union_ends_allowed > 0, @src(), "union ends not allowed here (no union routine has been started)", .{});
                    union_ends_allowed -= 1;
                }
                op_idx += num_cast(routine_end.ops_to_advance_to_exit_union, u32);
                dynamic_serial_adjustment += num_cast(routine_end.routine_serial_delta_adjustment, isize);
            },
            .UNION_ROUTINE_END_TEMP => |routine_end| {
                assert_with_reason(DO_DEBUG, @src(), "op `UNION_ROUTINE_END_TEMP` is only allowed during debug", .{});
                if (DO_DEBUG) {
                    MODE.assert_mode(.NORMAL, .UNION_ROUTINE_END, DO_DEBUG, @src());
                    assert_with_reason(union_ends_allowed > 0, @src(), "union ends not allowed here (no union routine has been started)", .{});
                    union_ends_allowed -= 1;
                    op_idx += num_cast(routine_end.delta.ops_to_advance_to_exit_union, u32);
                    dynamic_serial_adjustment += num_cast(routine_end.routine_serial_delta_adjustment, isize);
                } else {
                    unreachable;
                }
            },
            else => unreachable, //FIXME //CHECKPOINT add pointer ops
        }
    }
    return @intCast(serial_idx);
}

test SerialRoutineBuilder {
    const PRINT_SERIAL_SIZE: bool = false;
    const Test = Root.Testing;
    const Color = enum(u32) {
        INVIS = 0x00_00_00_00,
        BLACK = 0x00_00_00_FF,
        WHITE = 0xFF_FF_FF_FF,
        RED = 0xFF_00_00_FF,
        GREEN = 0x00_FF_00_FF,
        BLUE = 0x00_00_FF_FF,
    };
    const MsgKind = enum(u8) {
        PERSON,
        PET,
    };
    const PetKind = enum(u8) {
        DOG,
        CAT,
    };
    const Kitten = extern struct {
        name: [8]u8 = @splat(' '),
        age: u8 = 0,
        color: Color = .BLACK,

        pub const EXAMPLE_1 = @This(){
            .name = .{ 'M', 'i', 't', 'z', 'y', ' ', ' ', ' ' },
            .age = 1,
            .color = .RED,
        };
        pub const EXAMPLE_2 = @This(){
            .name = .{ 'H', 'e', 'n', 'r', 'y', ' ', ' ', ' ' },
            .age = 2,
            .color = .BLUE,
        };
        pub const EXAMPLE_3 = @This(){
            .name = .{ 'S', 'c', 'a', 'm', 'p', 'e', 'r', ' ' },
            .age = 1,
            .color = .INVIS,
        };
    };
    const Cat = extern struct {
        name: [8]u8 = @splat(' '),
        age: u8 = 0,
        color: Color = .WHITE,
        street_fights_win_loss: i64 = 0,
        kittens: [4]Kitten = @splat(.{}),
        num_kittens: u8 = 0,

        pub const EXAMPLE_1 = @This(){
            .name = .{ 'O', 'p', 'a', 'l', ' ', ' ', ' ', ' ' },
            .age = 5,
            .color = .GREEN,
            .street_fights_win_loss = 999,
            .kittens = .{
                Kitten.EXAMPLE_1,
                Kitten.EXAMPLE_2,
                Kitten.EXAMPLE_3,
                .{},
            },
            .num_kittens = 3,
        };
        pub const EXAMPLE_2 = @This(){
            .name = .{ 'T', 'a', 'b', 'b', 'y', ' ', ' ', ' ' },
            .age = 10,
            .color = .RED,
            .street_fights_win_loss = 69420,
            .kittens = .{
                .{},
                .{},
                .{},
                .{},
            },
            .num_kittens = 0,
        };
    };
    const Puppy = extern struct {
        name: [8]u8 = @splat(' '),
        age: u8 = 0,
        color: Color = .BLACK,

        pub const EXAMPLE_1 = @This(){
            .name = .{ 'R', 'a', 's', 'c', 'a', 'l', ' ', ' ' },
            .age = 1,
            .color = .BLACK,
        };
        pub const EXAMPLE_2 = @This(){
            .name = .{ 'F', 'i', 'f', 'i', ' ', ' ', ' ', ' ' },
            .age = 1,
            .color = .WHITE,
        };
        pub const EXAMPLE_3 = @This(){
            .name = .{ 'D', 'e', 's', 't', 'r', 'o', 'y', ' ' },
            .age = 2,
            .color = .INVIS,
        };
    };
    const Dog = extern struct {
        name: [8]u8 = @splat(' '),
        bones_eaten: u64 = 0,
        age: u8 = 0,
        color: Color = .BLACK,
        puppies: [5]Puppy = @splat(.{}),
        puppies_len: u8 = 0,

        pub const EXAMPLE_1 = @This(){
            .name = .{ 'F', 'i', 'd', 'o', ' ', ' ', ' ', ' ' },
            .age = 8,
            .color = .BLACK,
            .bones_eaten = 305,
            .puppies = .{
                Puppy.EXAMPLE_1,
                Puppy.EXAMPLE_2,
                Puppy.EXAMPLE_3,
                .{},
                .{},
            },
            .puppies_len = 3,
        };
        pub const EXAMPLE_2 = @This(){
            .name = .{ 'S', 'p', 'o', 't', 'i', 'c', 'u', 's' },
            .age = 6,
            .color = .RED,
            .bones_eaten = 1024,
            .puppies = .{
                Puppy.EXAMPLE_3,
                .{},
                .{},
                .{},
                .{},
            },
            .puppies_len = 1,
        };
    };
    const Person = extern struct {
        money: f32 = 0.0,
        age: u8 = 0,
        name: [12]u8 = @splat(' '),

        pub const EXAMPLE_1 = @This(){
            .money = 3.1415,
            .age = 24,
            .name = .{ 'T', 'i', 'm', 'o', 't', 'h', 'y', ' ', ' ', ' ', ' ', ' ' },
        };
        pub const EXAMPLE_2 = @This(){
            .money = 0.45,
            .age = 30,
            .name = .{ 'G', 'a', 'b', 'e', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
        };
    };
    const DogOrCat = union(PetKind) {
        DOG: Dog,
        CAT: Cat,

        pub const Serial = Root.SerialUnion.SerialUnion(@This(), struct {}, .EXTERN, null);

        pub const EXAMPLE_1 = Serial.new(.DOG, Dog.EXAMPLE_1);
        pub const EXAMPLE_2 = Serial.new(.DOG, Dog.EXAMPLE_2);
        pub const EXAMPLE_3 = Serial.new(.CAT, Cat.EXAMPLE_1);
        pub const EXAMPLE_4 = Serial.new(.CAT, Cat.EXAMPLE_2);
    };
    const PetOrPerson = union(MsgKind) {
        PERSON: Person,
        PET: DogOrCat.Serial,

        pub const Serial = Root.SerialUnion.SerialUnion(@This(), struct {}, .EXTERN, null);

        pub const EXAMPLE_1 = Serial.new(.PERSON, Person.EXAMPLE_1);
        pub const EXAMPLE_2 = Serial.new(.PERSON, Person.EXAMPLE_2);
        pub const EXAMPLE_3 = Serial.new(.PET, DogOrCat.EXAMPLE_1);
        pub const EXAMPLE_4 = Serial.new(.PET, DogOrCat.EXAMPLE_2);
        pub const EXAMPLE_5 = Serial.new(.PET, DogOrCat.EXAMPLE_3);
        pub const EXAMPLE_6 = Serial.new(.PET, DogOrCat.EXAMPLE_4);
    };
    const MAGIC: [4]u8 = .{ '1', '2', '3', '4' };
    const TestStruct = extern struct {
        version: u32 = 1,
        timestamp: i64 = 1999_12_01,
        msg: PetOrPerson.Serial = PetOrPerson.EXAMPLE_1,
        magic: [4]u8 = MAGIC,
        msg_2: PetOrPerson.Serial = PetOrPerson.EXAMPLE_3,
        magic_2: [4]u8 = MAGIC,

        pub const EXAMPLE_0 = @This(){ .msg = PetOrPerson.EXAMPLE_1, .msg_2 = PetOrPerson.EXAMPLE_1, .timestamp = 1234_56_78 };
        pub const EXAMPLE_1 = @This(){ .msg = PetOrPerson.EXAMPLE_1, .msg_2 = PetOrPerson.EXAMPLE_3, .timestamp = 1999_12_01 };
        pub const EXAMPLE_2 = @This(){ .msg = PetOrPerson.EXAMPLE_2, .msg_2 = PetOrPerson.EXAMPLE_4, .timestamp = 1999_12_02 };
        pub const EXAMPLE_3 = @This(){ .msg = PetOrPerson.EXAMPLE_3, .msg_2 = PetOrPerson.EXAMPLE_5, .timestamp = 1999_12_03 };
        pub const EXAMPLE_4 = @This(){ .msg = PetOrPerson.EXAMPLE_4, .msg_2 = PetOrPerson.EXAMPLE_6, .timestamp = 1999_12_04 };
        pub const EXAMPLE_5 = @This(){ .msg = PetOrPerson.EXAMPLE_5, .msg_2 = PetOrPerson.EXAMPLE_1, .timestamp = 1999_12_05 };
        pub const EXAMPLE_6 = @This(){ .msg = PetOrPerson.EXAMPLE_6, .msg_2 = PetOrPerson.EXAMPLE_2, .timestamp = 1999_12_06 };
    };
    const test_cases = [_]TestStruct{
        TestStruct.EXAMPLE_1,
        TestStruct.EXAMPLE_2,
        TestStruct.EXAMPLE_3,
        TestStruct.EXAMPLE_4,
        TestStruct.EXAMPLE_5,
        TestStruct.EXAMPLE_6,
    };
    const CONCRETE = comptime build: {
        var test_struct_in = TestStruct.EXAMPLE_1;
        var test_struct_out = TestStruct.EXAMPLE_2;
        var op_buf: [1024]DataOp = undefined;
        var union_end_buf: [256]usize = undefined;
        var debug_buf: [1024]u8 = undefined;
        var alloc_name_buf: [256]u8 = undefined;
        var alloc_name_list: [32]RefSlice = undefined;
        var subrs_stack: [64]SubRoutineMode = undefined;
        const bufs = BuilderBuffers{
            .alloc_name_buffer = alloc_name_buf[0..],
            .alloc_name_list = alloc_name_list[0..],
            .op_buffer = op_buf[0..],
            .subroutine_stack = subrs_stack[0..],
            .union_end_buffer = union_end_buf[0..],
        };
        var builder = SerialRoutineBuilder.init(bufs);
        builder.debug_stack = debug_buf[0..1024];
        const settings = SerialSettings{
            .INTEGER_BYTE_PACKING = .USE_TARGET_ENDIAN,
            .TARGET_ENDIAN = .BIG_ENDIAN,
            .COMPTIME_EVAL_QUOTA = 50000,
            .ADD_ROUTINE_DEBUG_INFO = false,
            .MAGIC_IDENTIFIER = "TeSt",
            .ROUTINE_VERSION = 1,
            .POINTER_MODE = .DISALLOW_POINTERS,
        };
        builder.build_routine_for_type(TestStruct, settings);
        var test_serial: [1024]u8 = undefined;
        const input_native_bytes = std.mem.asBytes(&test_struct_in);
        const output_native_bytes = std.mem.asBytes(&test_struct_out);
        var serial_len_in: usize = undefined;
        var serial_len_out: usize = undefined;
        for (test_cases[0..], 0..) |case_struct, i| {
            test_struct_in = case_struct;
            test_struct_out = TestStruct.EXAMPLE_0;
            serial_len_in = builder.test_serialize(input_native_bytes, test_serial[0..1024]);
            serial_len_out = builder.test_deserialize(test_serial[0..1024], output_native_bytes);
            try Test.expect_equal(serial_len_in, "serial_len_in", serial_len_out, "serial_len_out", "serial mismatch between in and out on same data (test case {d})", .{i});
            try Test.expect_true(Utils.object_equals(test_struct_in, test_struct_out), "Utils.object_equals(test_struct_in, test_struct_out)", "input and output structs didnt have same values for same serial (test case {d})", .{i});
        }
        break :build builder.finalize_routine_for_current_type();
    };
    var test_struct_in = TestStruct.EXAMPLE_1;
    var test_struct_out = TestStruct.EXAMPLE_2;
    var test_serial: [1024]u8 = undefined;
    var serial_len_in: usize = undefined;
    var serial_len_out: usize = undefined;
    if (PRINT_SERIAL_SIZE) {
        std.debug.print("Serializer Tests: {s} {s}\n", .{ @tagName(CONCRETE.INT_PACKING), @tagName(CONCRETE.TARGET_ENDIAN) });
    }
    for (test_cases[0..], 0..) |case_struct, i| {
        test_struct_in = case_struct;
        test_struct_out = TestStruct.EXAMPLE_0;
        serial_len_in = try CONCRETE.serialize_to_slice(&test_struct_in, test_serial[0..1024]);
        serial_len_out = try CONCRETE.deserialize_from_slice(test_serial[0..1024], &test_struct_out);
        try Test.expect_equal(serial_len_in, "serial_len_in", serial_len_out, "serial_len_out", "serial mismatch between in and out on same data (test case {d})", .{i});
        try Test.expect_true(Utils.object_equals(test_struct_in, test_struct_out), "Utils.object_equals(test_struct_in, test_struct_out)", "input and output structs didnt have same values for same serial (test case {d})", .{i});
        if (PRINT_SERIAL_SIZE) {
            std.debug.print("Case {d}: SIZE = {d}\n", .{ i, serial_len_in });
        }
    }
}
