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
const Flags = Root.Flags;
const IList = Root.IList.IList;
const List = Root.IList_List.List;
const Range = Root.IList.Range;
const MathX = Root.Math;
const KindInfo = Types.KindInfo;
const Kind = Types.Kind;
const Endian = Root.CommonTypes.Endian;

const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Hash = std.hash.XxHash64;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const bit_cast = Root.Cast.bit_cast;
const read_int = std.mem.readInt;
const DEBUG = std.debug.print;
const DEBUG_CT = Utils.comptime_debug_print;

pub const NATIVE_ENDIAN = Endian.NATIVE;

pub const BytePacking = enum(u8) {
    /// Serialize data in little endian order with the same size
    /// as the native type
    LITTLE_ENDIAN,
    /// Serialize data in big endian order with the same size
    /// as the native type
    BIG_ENDIAN,
    // /// Serialize data using VarInts, which can greatly reduce
    // /// the size of the serialized data at the cost of additional
    // /// processing time.
    // ///
    // /// Specifically, this uses a
    // /// variation of GVE (Group Varint Encoding), where the routine
    // /// inserts varint header ops at comptime where needed,
    // /// and during runtime serialization/deserialization the routine will
    // /// read/write a number of bits from/to the accumulated header byte slots,
    // /// where the bits read/written indicate how many bytes the current value requires.
    // ///
    // /// This reduces the number of CPU branches required to serialize a single value and eliminates
    // /// additional bit shifting/masking ops on the data bytes, but one caveat is that when serializing
    // /// to an `std.Io.Writer`, the routine must seek back its position to update previously written
    // /// header bytes, then seek back to the current write position. Depending on the concrete implementation
    // /// of the `std.Io.Writer`, this may incur a perofrormance penalty, or in some cases may be impossible.
    // VARINT_USING_HEADERS,
    /// Serialize data using VarInts, which can greatly reduce
    /// the size of the serialized data at the cost of additional
    /// processing time.
    ///
    /// Specifically, this uses the 'PrefixVarint' method,
    /// where the leading bits of the first byte (or first couple bytes for very large values) to signal the total
    /// number of bytes for the value, and the following bytes are in LITTLE ENDIAN order
    ///
    /// This reduces the number of CPU branches required to serialize a single value and eliminates
    /// additional bit shifting/masking ops on the data bytes
    VARINT_USING_PREFIX_LITTLE_ENDIAN,
    /// Serialize data using VarInts, which can greatly reduce
    /// the size of the serialized data at the cost of additional
    /// processing time.
    ///
    /// Specifically, this uses the 'PrefixVarint' method,
    /// where the leading bits of the first byte (or first couple bytes for very large values) to signal the total
    /// number of bytes for the value, and the following bytes are in BIG ENDIAN order
    ///
    /// This reduces the number of CPU branches required to serialize a single value and eliminates
    /// additional bit shifting/masking ops on the data bytes
    VARINT_USING_PREFIX_BIG_ENDIAN,
    // /// Serialize data using VarInts, which can greatly reduce
    // /// the size of the serialized data at the cost of additional
    // /// processing time.
    // ///
    // /// Specifically, this uses the traditional VarInt method,
    // /// where each byte encodes 7 bits of real data, and uses the most significant bit to
    // /// signal whether another byte needs to be processed after it.
    // ///
    // /// This method has a small memory footprint and does not require
    // /// seeking back to a previous index of the serial stream like `VARINT_USING_HEADERS`,
    // /// but causes many more CPU branches and requires bit shifting/masking operations to unpack the data
    // VARINT_USING_CONTINUE_BIT,
};

pub const IntegerSign = enum(u8) {
    UNSIGNED,
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
    /// You may need to use a different serial routine
    serial_version_mismatch,
    /// The serial routine hash recorded in the serial data
    /// did not match the one expected by the serial routine.
    ///
    /// If the version DOES match and this does not, it usually indicates
    /// that you changed the native object to be serialized without incrementing
    /// the version counter associated with it.
    serial_routine_hash_mismatch,
};

const SerialKind = enum(u8) { SLICE, READER_WRITER };

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
};

const VarintPrefixInfo = struct {
    data_bytes: usize = 0,
    waste_bytes: usize = 0,
    top_bits_to_trim: usize = 0,
};

pub const OpKind = enum(u8) {
    MOVE_DATA_NO_SWAP,
    MOVE_DATA_SWAP,
    MOVE_DATA_NO_SWAP_SAVE_TAG,
    MOVE_DATA_SWAP_SAVE_TAG,
    // MOVE_DATA_VARINT_G,
    // MOVE_DATA_VARINT_G_SAVE_TAG,
    // MOVE_DATA_VARINT_GS,
    // MOVE_DATA_VARINT_GS_SAVE_TAG,
    // VARINT_G_HEADER,
    MOVE_DATA_VARINT_P,
    MOVE_DATA_VARINT_P_SAVE_TAG,
    MOVE_DATA_VARINT_PS,
    MOVE_DATA_VARINT_PS_SAVE_TAG,
    MOVE_DATA_VARINT_P_SWAP,
    MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
    MOVE_DATA_VARINT_PS_SWAP,
    MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
    UNION_HEADER,
    UNION_TAG_ID,
    UNION_ROUTINE_START,
    UNION_ROUTINE_END_TEMP,
    UNION_ROUTINE_END,
};

pub const DataOp = union(OpKind) {
    MOVE_DATA_NO_SWAP: MemCopyMove,
    MOVE_DATA_SWAP: MemCopyMove,
    MOVE_DATA_NO_SWAP_SAVE_TAG: MemCopyMove,
    MOVE_DATA_SWAP_SAVE_TAG: MemCopyMove,
    // MOVE_DATA_VARINT_G: MemCopyMove,
    // MOVE_DATA_VARINT_G_SAVE_TAG: MemCopyMove,
    // MOVE_DATA_VARINT_GS: MemCopyMove,
    // MOVE_DATA_VARINT_GS_SAVE_TAG: MemCopyMove,
    // VARINT_G_HEADER: VarInt_G_Header,
    MOVE_DATA_VARINT_P: MemCopyMove,
    MOVE_DATA_VARINT_P_SAVE_TAG: MemCopyMove,
    MOVE_DATA_VARINT_PS: MemCopyMove,
    MOVE_DATA_VARINT_PS_SAVE_TAG: MemCopyMove,
    MOVE_DATA_VARINT_P_SWAP: MemCopyMove,
    MOVE_DATA_VARINT_P_SWAP_SAVE_TAG: MemCopyMove,
    MOVE_DATA_VARINT_PS_SWAP: MemCopyMove,
    MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG: MemCopyMove,
    UNION_HEADER: UnionHeader,
    UNION_TAG_ID: u64,
    UNION_ROUTINE_START: UnionRoutineStart,
    UNION_ROUTINE_END_TEMP: UnionRoutineEndTemp,
    UNION_ROUTINE_END: UnionRoutineEnd,

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
    // pub fn mem_move_varint_g(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
    //     return DataOp{ .MOVE_DATA_VARINT_G = .mem_copy_move(native_to_serial_delta, copy_len) };
    // }
    // pub fn mem_move_varint_g_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
    //     assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
    //     return DataOp{ .MOVE_DATA_VARINT_G_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    // }
    // pub fn mem_move_varint_gs(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
    //     return DataOp{ .MOVE_DATA_VARINT_GS = .mem_copy_move(native_to_serial_delta, copy_len) };
    // }
    // pub fn mem_move_varint_gs_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
    //     assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
    //     return DataOp{ .MOVE_DATA_VARINT_GS_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    // }
    // pub fn varint_g_header(comptime num_following_varint_bytes: u32) DataOp {
    //     assert_with_reason(num_following_varint_bytes > 0 and num_following_varint_bytes <= 4, @src(), "`num_following_varint_bytes` must be more than 0 and less than or equal to 4, got {d}", .{num_following_varint_bytes});
    //     return DataOp{ .VARINT_G_HEADER = VarInt_G_Header{ .number_of_following_header_bytes = num_following_varint_bytes, .offset_to_next_varint_g_header = 0 } };
    // }

    pub fn mem_move_varint_p(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_P = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_P_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_PS = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_PS_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_P_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_p_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .MOVE_DATA_VARINT_PS_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_varint_ps_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
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

    pub fn can_combine(comptime prev: DataOp, comptime next: DataOp) ?DataOp {
        if (prev == .MOVE_DATA_NO_SWAP and next == .MOVE_DATA_NO_SWAP) {
            if (prev.MOVE_DATA_NO_SWAP.native_to_serial_delta == next.MOVE_DATA_NO_SWAP.native_to_serial_delta) {
                return DataOp.mem_move_no_swap(prev.MOVE_DATA_NO_SWAP.native_to_serial_delta, prev.MOVE_DATA_NO_SWAP.copy_len + next.MOVE_DATA_NO_SWAP.copy_len);
            }
        }
        return null;
    }
};

pub const VarInt_G_Header = struct {
    number_of_following_header_bytes: u32,
    offset_to_next_varint_g_header: u32,
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
    pub fn cast_endian_serial_to_endian_u64(comptime self: OpaqueUnionTag, serial: []const u8) u64 {
        var u64_bytes: [8]u8 align(8) = @splat(0);
        assert_with_reason(self.bytes() == serial.len, @src(), "serial wrong len", .{});
        @memcpy(u64_bytes[0..serial.len], serial);
        return @bitCast(u64_bytes);
    }
    pub fn cast_endian_serial_to_endian_u64_any(serial: []const u8) u64 {
        var u64_bytes: [8]u8 align(8) = @splat(0);
        assert_with_reason(serial.len == 1 or serial.len == 2 or serial.len == 4 or serial.len == 8, @src(), "serial wrong len", .{});
        @memcpy(u64_bytes[0..serial.len], serial);
        return @bitCast(u64_bytes);
    }
    pub fn cast_serial_and_swap_to_endian_u64_any(serial: []const u8) u64 {
        var u64_bytes: [8]u8 align(8) = @splat(0);
        assert_with_reason(serial.len == 1 or serial.len == 2 or serial.len == 4 or serial.len == 8, @src(), "serial wrong len", .{});
        @memcpy(u64_bytes[0..serial.len], serial);
        std.mem.reverse(u8, u64_bytes[0..serial.len]);
        return @bitCast(u64_bytes);
    }
    pub fn cast_native_bytes_to_endian_u64_any(native: []const u8, comptime SWAP: bool) u64 {
        var u64_bytes: [8]u8 align(8) = @splat(0);
        assert_with_reason(native.len == 1 or native.len == 2 or native.len == 4 or native.len == 8, @src(), "native wrong len", .{});
        @memcpy(u64_bytes[0..native.len], native);
        if (SWAP) {
            std.mem.reverse(u8, u64_bytes[0..native.len]);
        }
        return @bitCast(u64_bytes);
    }
    pub fn cast_tag_to_endian_u64(comptime self: OpaqueUnionTag, comptime TARGET_ENDIAN: Endian, tag: anytype) u64 {
        const T = @TypeOf(tag);
        assert_with_reason(self.bytes() == @sizeOf(T), @src(), "tag is wrong size", .{});
        assert_with_reason(Types.type_is_enum(T), @src(), "tag must be an enum", .{});
        const SWAP = TARGET_ENDIAN != NATIVE_ENDIAN;
        var u64_bytes: [8]u8 align(8) = @splat(0);
        switch (self) {
            .U8 => {
                const raw: u8 = @bitCast(@intFromEnum(tag));
                u64_bytes[0] = raw;
            },
            .U16 => {
                var raw: [2]u8 = @bitCast(@intFromEnum(tag));
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, raw[0..2]);
                }
                @memcpy(u64_bytes[0..2], raw[0..2]);
            },
            .U32 => {
                var raw: [4]u8 = @bitCast(@intFromEnum(tag));
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, raw[0..4]);
                }
                @memcpy(u64_bytes[0..4], raw[0..4]);
            },
            .U64 => {
                u64_bytes = @bitCast(@intFromEnum(tag));
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, u64_bytes[0..8]);
                }
            },
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

    pub fn add_type(comptime self: *UnionRoutineBuilder, comptime builder: *SerialRoutineBuilder, comptime tag_value: anytype, comptime union_native_offset: usize, comptime TYPE: type, comptime SETTINGS: SerialSettings) void {
        const prev_serial_offset = builder.curr_serial_offset;
        const prev_routine_ops_idx = builder.ops_len;
        const curr_routine_start = self.current_routine_start_op();
        const curr_tag_id = self.current_routine_tag_op();
        // const curr_tag_id_op_true_idx = self.current_routine_tag_op_true_idx();
        const TAG_OPQ = OpaqueUnionTag.from_tag_type(@TypeOf(tag_value));
        builder.d_assert_with_reason(TAG_OPQ == self.union_tag_opaque, @src(), "opaque tag param from `tag_value` (`{s}`) does not match the one this union builder was created with (`{s}`)", .{ @tagName(TAG_OPQ), @tagName(self.union_tag_opaque) });
        const tag_u64 = TAG_OPQ.cast_tag_to_endian_u64(SETTINGS.INTEGER_BYTE_PACKING, tag_value);
        curr_routine_start.offset_to_first_routine_op = self.delta_between_current_routine_start_op_idx_and_first_op_in_its_routine(builder);
        curr_tag_id.* = tag_u64;
        builder.add_type(union_native_offset, TYPE, SETTINGS);
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
        builder.d_assert_with_reason(self.routine_idx == self.field_count, @src(), "cannot end union serial routine builder: not all field tags had routines specified", .{});
        for (self.routine_end_op_indexes) |routine_end_op_idx| {
            const routine_end: *UnionRoutineEndTemp = &builder.ops[routine_end_op_idx].UNION_ROUTINE_END_TEMP;
            routine_end.finalize(builder.ops_len);
        }
        builder.curr_union_depth -= 1;
        builder.skip_ahead_len -= self.field_count;
    }
};

pub const RoutineStepKind = enum(u8) {
    BYTE_MOVE,
    UNION_HEADER,
    UNION_SUBROUTINE_OFFSET,
};

pub const PointerMode = enum(u8) {
    DISALLOW_POINTERS,
    IGNORE_POINTERS,
    FOLLOW_SCALAR_POINTERS,
};

pub const SaveTagMode = enum(u8) {
    NOT_A_UNION_TAG,
    IS_A_UNION_TAG,
};

pub const CustomSerializeFn = fn (comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime SETTINGS: SerialSettings) void;
pub const CustomSerializeFnSig = "fn (comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime SETTINGS: SerialSettings) void";
pub const CustomSerializeFnName = "custom_serialize_routine";

pub fn type_has_custom_serialize(comptime T: type) bool {
    if (@hasDecl(T, CustomSerializeFnName)) {
        if (@TypeOf(@field(T, CustomSerializeFnName)) == CustomSerializeFn) {
            return true;
        } else {
            Assert.warn_unconditional_always(@src(), "type `{s}` has a `{s}` declaration, but it does not match the signature `{s}`", .{ @typeName(T), CustomSerializeFnName, CustomSerializeFnSig });
        }
    }
    return false;
}

pub const SerialInitSettings = struct {
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
    /// If true, also include a 64-bit (8-byte) hash after the 'version'. This is not
    /// a hash of the actual serial data, but a hash of the object type and compiled routine
    ///
    /// This is usually not needed, but can be an additional validation check if there are errors
    /// occuring even when the version matches. If any part of the object type to serialize or the
    /// compiled routine mismatches the hash in the serial data, it indicates that there is
    /// a definite disparity between the code writing the serial data and the code reading it.
    INCLUDE_ROUTINE_HASH_WITH_VERSION: bool = false,
};

pub const SerialSettings = struct {
    /// How to pack integers in the serial data.
    ///
    /// When `LITTLE_ENDIAN` or `BIG_ENDIAN` is chosen, bytes will be packed using the same size as their
    /// native code size, in the specified endian byte order. If this is chosen, `LITTLE_ENDIAN` is
    /// in most cases the best choice, as most target platforms are natively little-endian, allowing for
    /// faster processing.
    ///
    /// When one of the `VARINT_` modes are chosen, data is compressed such that smaller runtime values require
    /// fewer bytes than the native code type maximum, at the cost of additional processing time. When
    /// one of these are desired, `VARINT_USING_HEADERS` is a good choice as long as seeking back
    /// to a previous point in the serial stream to re-write one byte is possible
    INTEGER_BYTE_PACKING: BytePacking = .LITTLE_ENDIAN,
    /// How to pack float bytes in the serial data. `LITTLE_ENDIAN` is
    /// in most cases the best choice, as most target platforms are natively little-endian, allowing for
    /// faster processing.
    ///
    /// Floats are not allowed to be packed as VarInts, because floating point encoding forces all
    /// bytes to be used in almost all cases, which results in nearly-guaranteed wasted processing and
    /// memory footprint.
    FLOAT_BYTE_ORDER: Endian = .LITTLE_ENDIAN,
};

pub const SerialRoutineBuilder = struct {
    root_type: ?type = null,
    integer_packing: Endian = .NATIVE,
    magic_id: ?[]const u8 = null,
    routine_version: ?u32 = null,
    routine_hash: ?Hash = null,
    ops: []DataOp = &.{},
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

    pub fn init(comptime op_buffer: []DataOp, comptime union_end_buffer: []usize) SerialRoutineBuilder {
        return SerialRoutineBuilder{
            .ops = op_buffer,
            .skip_ahead_stack = union_end_buffer,
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
        self.routine_hash = null;
        self.routine_version = null;
        self.add_debug_info = false;
        self.integer_packing = .LITTLE_ENDIAN;
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

    /// This is an un-optimized, comptime-only function that will run the serial/deserial routine on opaque test data to ensure proper operation
    ///
    /// For an optimized runtime method, you must use `SerialRoutineBuilder.finalize()` to produce a concrete serializer type for the current
    /// specific serial object.
    fn test_serialize_internal(comptime self: *SerialRoutineBuilder, comptime native_slice: []u8, comptime serial_slice: []u8, comptime DIRECTION: SER_DIR) usize {
        comptime var ser_idx: isize = 0;
        comptime var tag_got: u64 = undefined;
        comptime var num_tags_this_union: u32 = 0;
        comptime var tags_checked_this_union: u32 = 0;
        comptime var allowed_union_ends: u32 = 0;
        comptime var op_idx: usize = 0;
        comptime var dynamic_serial_adjustment: isize = 0;
        comptime var mode: TEST_SER_MODE = .NORMAL;
        while (op_idx < self.ops_len) {
            const op = self.ops[op_idx];
            switch (op) {
                .MOVE_DATA_NO_SWAP,
                .MOVE_DATA_NO_SWAP_SAVE_TAG,
                .MOVE_DATA_SWAP,
                .MOVE_DATA_SWAP_SAVE_TAG,
                .MOVE_DATA_VARINT_P,
                .MOVE_DATA_VARINT_P_SAVE_TAG,
                .MOVE_DATA_VARINT_PS,
                .MOVE_DATA_VARINT_PS_SAVE_TAG,
                .MOVE_DATA_VARINT_P_SWAP,
                .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                .MOVE_DATA_VARINT_PS_SWAP,
                .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                => |move| {
                    const native_start_i: isize = ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment);
                    self.d_assert_with_reason(native_start_i >= 0, @src(), "(serial_idx + native_to_serial_delta + dynamic_serial_adjustment) would cause native index to go below zero", .{});
                    const native_start: usize = @intCast(native_start_i);
                    const native_end = native_start + num_cast(move.copy_len, usize);
                    const native_len = native_end - native_start;
                    const serial_start = num_cast(ser_idx, usize);
                    const serial_end = serial_start + num_cast(move.copy_len, usize);
                    const SWAP = switch (op) {
                        .MOVE_DATA_NO_SWAP,
                        .MOVE_DATA_NO_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_P,
                        .MOVE_DATA_VARINT_P_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS,
                        .MOVE_DATA_VARINT_PS_SAVE_TAG,
                        => false,
                        .MOVE_DATA_SWAP,
                        .MOVE_DATA_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SWAP,
                        .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SWAP,
                        .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                        => true,
                        else => unreachable,
                    };
                    const SAVE_TAG = switch (op) {
                        .MOVE_DATA_NO_SWAP,
                        .MOVE_DATA_SWAP,
                        .MOVE_DATA_VARINT_P,
                        .MOVE_DATA_VARINT_P_SWAP,
                        .MOVE_DATA_VARINT_PS,
                        .MOVE_DATA_VARINT_PS_SWAP,
                        => false,
                        .MOVE_DATA_NO_SWAP_SAVE_TAG,
                        .MOVE_DATA_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                        => true,
                        else => unreachable,
                    };
                    const ZIGZAG = switch (op) {
                        .MOVE_DATA_NO_SWAP,
                        .MOVE_DATA_SWAP,
                        .MOVE_DATA_VARINT_P,
                        .MOVE_DATA_VARINT_P_SWAP,
                        .MOVE_DATA_NO_SWAP_SAVE_TAG,
                        .MOVE_DATA_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                        => false,
                        .MOVE_DATA_VARINT_PS,
                        .MOVE_DATA_VARINT_PS_SWAP,
                        .MOVE_DATA_VARINT_PS_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                        // zigzag requires knowing the native size concretely, so only i16, i32, i64, isize, and i128 are supported
                        => move.copy_len == 2 or move.copy_len == 4 or move.copy_len == 8 or move.copy_len == 16,
                        else => unreachable,
                    };
                    comptime var zigzag_temp: [16]u8 = undefined;
                    const TECH = switch (op) {
                        .MOVE_DATA_NO_SWAP,
                        .MOVE_DATA_SWAP,
                        .MOVE_DATA_NO_SWAP_SAVE_TAG,
                        .MOVE_DATA_SWAP_SAVE_TAG,
                        => SER_TECH.NORMAL,
                        .MOVE_DATA_VARINT_P,
                        .MOVE_DATA_VARINT_P_SWAP,
                        .MOVE_DATA_VARINT_P_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS,
                        .MOVE_DATA_VARINT_PS_SWAP,
                        .MOVE_DATA_VARINT_PS_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                        => SER_TECH.VARINT_P,
                        else => unreachable,
                    };
                    switch (TECH) {
                        .NORMAL => comptime do_serial_move_mem(move, &ser_idx, &op_idx, serial_slice, serial_start, serial_end, native_slice, native_start, native_end, SWAP, DIRECTION),
                        .VARINT_P => switch (ZIGZAG) {
                            true => switch (DIRECTION) {
                                .NATIVE_TO_SERIAL => {
                                    @memcpy(zigzag_temp[0..native_len], native_slice[native_start..native_end]);
                                },
                                .SERIAL_TO_NATIVE => {},
                            },
                            false => {},
                        },
                    }
                    switch (op) {
                        .MOVE_DATA_NO_SWAP,
                        .MOVE_DATA_SWAP,
                        .MOVE_DATA_SWAP_SAVE_TAG,
                        .MOVE_DATA_NO_SWAP_SAVE_TAG,
                        => self.do_serial_move_mem(move, &ser_idx, &op_idx, serial_slice, serial_start, serial_end, native_slice, native_start, native_end, SWAP, DIRECTION),
                        .MOVE_DATA_VARINT_P,
                        .MOVE_DATA_VARINT_P_SWAP,
                        .MOVE_DATA_VARINT_P_SAVE_TAG,
                        .MOVE_DATA_VARINT_P_SWAP_SAVE_TAG,
                        => {},
                        .MOVE_DATA_VARINT_PS,
                        .MOVE_DATA_VARINT_PS_SWAP,
                        .MOVE_DATA_VARINT_PS_SAVE_TAG,
                        .MOVE_DATA_VARINT_PS_SWAP_SAVE_TAG,
                        => {
                            // DO SERIAL
                            tag_got = OpaqueUnionTag.cast_native_bytes_to_endian_u64_any(native_slice[serial_start..serial_end]);
                            mode = .NEED_UNION_TAG_ID_NEXT;
                        },
                        else => unreachable,
                    }
                },
                .MOVE_DATA_SWAP, .MOVE_DATA_SWAP_SAVE_TAG => |move| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    const native_start_i: isize = ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment);
                    self.d_assert_with_reason(native_start_i >= 0, @src(), "(serial_idx + native_to_serial_delta + dynamic_serial_adjustment) would cause native index to go below zero", .{});
                    const native_start: usize = @intCast(native_start_i);
                    const native_end = native_start + num_cast(move.copy_len, usize);
                    const serial_start = num_cast(ser_idx, usize);
                    const serial_end = serial_start + num_cast(move.copy_len, usize);
                    comptime var sidx: usize = num_cast(ser_idx, usize);
                    comptime var nidx: usize = native_end;
                    while (sidx < serial_end) : (sidx += 1) {
                        nidx -= 1;
                        switch (DIRECTION) {
                            .NATIVE_TO_SERIAL => {
                                serial_slice[sidx] = native_slice[nidx];
                            },
                            .SERIAL_TO_NATIVE => {
                                native_slice[nidx] = serial_slice[sidx];
                            },
                        }
                    }
                    ser_idx += num_cast(move.copy_len, isize);
                    op_idx += 1;
                    switch (op) {
                        .MOVE_DATA_SWAP_SAVE_TAG => {
                            tag_got = OpaqueUnionTag.cast_endian_serial_to_endian_u64_any(serial_slice[serial_start..serial_end]);
                            mode = .NEED_UNION_TAG_ID_NEXT;
                        },
                        .MOVE_DATA_SWAP => {},
                        else => unreachable,
                    }
                },
                .UNION_HEADER => |header| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    num_tags_this_union = header.num_fields;
                    tags_checked_this_union = 0;
                    op_idx += 1;
                    mode = .NEED_UNION_TAG_SERIAL_CAPTURE_NEXT;
                },
                .UNION_TAG_ID => |tag_match| {
                    self.d_assert_with_reason(mode == .NEED_UNION_TAG_ID_NEXT, @src(), "must be in `.NEED_UNION_TAG_ID_NEXT` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    if (tag_got == tag_match) {
                        mode = .NEED_UNION_START_NEXT;
                        op_idx += 1;
                    } else {
                        op_idx += 2;
                        tags_checked_this_union += 1;
                        self.d_assert_with_reason(tags_checked_this_union < num_tags_this_union, @src(), "did not find a match for the captured union tag. If the provided native tag is valid, there is something wrong with the SerialRoutineBuilder internal logic, otherwise it may be an issue with the test data. At runtime this should never happen, as the data source comes from zig-validated types", .{});
                    }
                },
                .UNION_ROUTINE_START => |routine_start| {
                    self.d_assert_with_reason(mode == .NEED_UNION_START_NEXT, @src(), "must be in `.NEED_UNION_START_NEXT` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    op_idx += routine_start.offset_to_first_routine_op;
                    mode = .NORMAL;
                    allowed_union_ends += 1;
                },
                .UNION_ROUTINE_END_TEMP => |routine_end| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(allowed_union_ends > 0, @src(), "union ends not allowed here (no union routine has been started)", .{});
                    allowed_union_ends -= 1;
                    op_idx += num_cast(routine_end.delta.ops_to_advance_to_exit_union, u32);
                    dynamic_serial_adjustment += num_cast(routine_end.routine_serial_delta_adjustment, isize);
                },
                else => assert_unreachable(@src(), "op `{s}` is not allowed here", .{@tagName(op)}),
            }
        }
        return @intCast(ser_idx);
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

    pub fn build_routine_for_type(comptime self: *SerialRoutineBuilder, comptime TYPE: type, comptime SETTINGS: SerialSettings, comptime INIT_SETTINGS: SerialInitSettings) void {
        @setEvalBranchQuota(SETTINGS.COMPTIME_EVAL_QUOTA);
        self.reset();
        self.root_type = TYPE;
        self.debug_target = INIT_SETTINGS.TARGET_DEBUG_INDEX;
        self.integer_packing = SETTINGS.INTEGER_BYTE_PACKING;
        self.float_packing = SETTINGS.FLOAT_BYTE_ORDER;
        self.add_debug_info = INIT_SETTINGS.ADD_ROUTINE_DEBUG_INFO;
        self.add_type(0, TYPE, SETTINGS);
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
        return define_serial_routine(self.ops_len, OPS_CONST, self.root_type.?, self.integer_packing);
    }

    pub fn build_and_finalize_serial_routine_for_type(comptime self: *SerialRoutineBuilder, comptime TYPE: type, comptime SETTINGS: SerialSettings) type {
        self.build_routine_for_type(TYPE, SETTINGS);
        return finalize_routine_for_current_type(self.*);
    }

    pub fn ensure_space_for_n_more_ops(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        self.d_assert_with_reason(self.ops_len + n <= self.ops.len, @src(), "ran out of space for data ops. Need at least {d} (possibly more), have {d}. provide a larger buffer", .{ self.ops_len + n, self.ops.len });
    }

    pub fn ensure_space_for_n_more_skip_ahead(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        self.d_assert_with_reason(self.skip_ahead_len + n <= self.skip_ahead_stack.len, @src(), "ran out of space for skip-ahead index caches. Need at least {d} (possibly more), have {d}. provide a larger buffer", .{ self.skip_ahead_len + n, self.skip_ahead_stack.len });
    }
    pub fn ensure_space_for_n_more_debug_bytes(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        self.d_assert_with_reason(self.debug_stack_len + n <= self.debug_stack.len, @src(), "ran out of space for debug info. Need at least {d} bytes (possibly more), have {d}. provide a larger buffer", .{ self.debug_stack_len + n, self.debug_stack.len });
    }

    pub fn add_integer_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime BYTE_LEN: usize, comptime INT_SIGN: IntegerSign, comptime SETTINGS: SerialSettings, comptime UNION_TAG: SaveTagMode) void {
        assert_with_reason(BYTE_LEN > 0, @src(), "cannot add a data type to serialze that has zero size", .{});
        assert_with_reason(BYTE_LEN <= 8129, @src(), "integers can never be larger than 8129 bytes long (65536 bits, 8KiB), got byte len {d}", .{BYTE_LEN});
        with_new_mode: switch (SETTINGS.INTEGER_BYTE_PACKING) {
            .LITTLE_ENDIAN, .BIG_ENDIAN => {
                self.ensure_space_for_n_more_ops(1);
                const SWAP = (NATIVE_ENDIAN == .BIG_ENDIAN and SETTINGS.INTEGER_BYTE_PACKING == .LITTLE_ENDIAN) or (NATIVE_ENDIAN == .LITTLE_ENDIAN and SETTINGS.INTEGER_BYTE_PACKING == .BIG_ENDIAN);
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
            // .VARINT_USING_HEADERS => {
            //     if (BYTE_LEN == 1) {
            //         continue :with_new_mode .LITTLE_ENDIAN;
            //     }
            //     self.ensure_space_for_n_more_ops(2);
            //     const max_byte_consume_needed_power = MathX.PowerOf2.round_up_to_power_of_2(BYTE_LEN);
            //     const bits_needed: u8 = @intFromEnum(max_byte_consume_needed_power);
            //     self.current_varint_g_bits += bits_needed;
            //     if (self.current_varint_g_bits > 32) {
            //         const bits_in_next_header = (self.current_varint_g_bits - 32);
            //         const bytes_in_next_header = (bits_in_next_header + 7) >> 3;
            //         self.ops[self.prev_varint_g_header_slot].VARINT_G_HEADER.offset_to_next_varint_g_header = num_cast(self.ops_len - self.prev_varint_g_header_slot, u32);
            //         self.ops[self.ops_len] = .varint_g_header(bytes_in_next_header);
            //         self.prev_varint_g_header_slot = self.ops_len;
            //         self.ops_len += 1;
            //         self.current_varint_g_bits = bits_in_next_header;
            //     }
            //     const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
            //     switch (UNION_TAG) {
            //         .IS_A_UNION_TAG => switch (INT_SIGN) {
            //             .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_g_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
            //             .SIGNED => self.ops[self.ops_len] = .mem_move_varint_gs_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
            //         },
            //         .NOT_A_UNION_TAG => switch (INT_SIGN) {
            //             .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_g(native_to_serial_delta, @intCast(BYTE_LEN)),
            //             .SIGNED => self.ops[self.ops_len] = .mem_move_varint_gs(native_to_serial_delta, @intCast(BYTE_LEN)),
            //         },
            //     }
            //     self.ops_len += 1;
            // },
            .VARINT_USING_PREFIX_LITTLE_ENDIAN, .VARINT_USING_PREFIX_BIG_ENDIAN => {
                if (BYTE_LEN == 1) {
                    continue :with_new_mode .LITTLE_ENDIAN;
                }
                // 0xxxxxxx = 1 byte (< 128)
                // 10xxxxxx = 2 byte (< 16384)
                // 110xxxxx = 3 byte (< 2097152)
                // 1110xxxx = 4 byte (< 268435456)
                // 11110xxx = 5 byte (< 34359738368)
                // 111110xx = 6 byte (< 4398046511104)
                // 1111110x = 7 byte (< 562949953421312)
                // 11111110 = 8 byte (< 72057594037927936)
                // 11111111 = 9+ byte:
                // 11111111 0xxxxxxx = 9 byte  (< 9223372036854775808)
                // 11111111 10xxxxxx = 10 byte
                // 11111111 110xxxxx = 11 byte
                // 11111111 1110xxxx = 12 byte
                // 11111111 11110xxx = 13 byte
                // 11111111 111110xx = 14 byte
                // 11111111 1111110x = 15 byte
                // 11111111 11111110 = 16 byte
                // 11111111 11111111 = 17+ bytes...
                const SWAP = (NATIVE_ENDIAN == .BIG_ENDIAN and SETTINGS.INTEGER_BYTE_PACKING == .VARINT_USING_PREFIX_LITTLE_ENDIAN) or (NATIVE_ENDIAN == .LITTLE_ENDIAN and SETTINGS.INTEGER_BYTE_PACKING == .VARINT_USING_PREFIX_BIG_ENDIAN);
                const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
                switch (SWAP) {
                    true => switch (UNION_TAG) {
                        .IS_A_UNION_TAG => switch (INT_SIGN) {
                            .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p_swap_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                            .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps_swap_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                        },
                        .NOT_A_UNION_TAG => switch (INT_SIGN) {
                            .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p_swap(native_to_serial_delta, @intCast(BYTE_LEN)),
                            .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps_swap(native_to_serial_delta, @intCast(BYTE_LEN)),
                        },
                    },
                    false => switch (UNION_TAG) {
                        .IS_A_UNION_TAG => switch (INT_SIGN) {
                            .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                            .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps_save_tag(native_to_serial_delta, @intCast(BYTE_LEN)),
                        },
                        .NOT_A_UNION_TAG => switch (INT_SIGN) {
                            .UNSIGNED => self.ops[self.ops_len] = .mem_move_varint_p(native_to_serial_delta, @intCast(BYTE_LEN)),
                            .SIGNED => self.ops[self.ops_len] = .mem_move_varint_ps(native_to_serial_delta, @intCast(BYTE_LEN)),
                        },
                    },
                }
                self.ops_len += 1;
            },
        }
    }

    pub fn add_float_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime max_size: usize, comptime SETTINGS: SerialSettings) void {
        self.ensure_space_for_n_more_ops(1);
        const SWAP = NATIVE_ENDIAN != SETTINGS.FLOAT_BYTE_ORDER;
        const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
        if (SWAP and max_size > 1) {
            self.ops[self.ops_len] = .mem_move_swap(native_to_serial_delta, @intCast(max_size));
            self.ops_len += 1;
            self.curr_serial_offset += num_cast(max_size, i32);
        } else {
            const has_prev = self.ops_len > 0;
            comptime var prev: DataOp = DataOp.mem_move_swap(0, 2);
            if (has_prev) {
                prev = self.ops[self.ops_len - 1];
            }
            const next = DataOp.mem_move_no_swap(native_to_serial_delta, max_size);
            if (prev.can_combine(next)) |combined| {
                self.ops[self.ops_len - 1] = combined;
            } else {
                self.ops[self.ops_len] = next;
                self.ops_len += 1;
            }
            self.curr_serial_offset += num_cast(max_size, i32);
        }
    }

    pub fn start_union_routine_builder(comptime self: *SerialRoutineBuilder, comptime tag_native_offset: usize, comptime SETTINGS: SerialSettings, comptime TAG_TYPE: type, comptime FIELD_COUNT: usize) UnionRoutineBuilder {
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
        self.add_integer_bytes(tag_native_offset, UTAG_SIZE, SIGN, SETTINGS, .IS_A_UNION_TAG);
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
    pub fn add_type_with_custom_serializer(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime TYPE: type, comptime SETTINGS: SerialSettings) void {
        self.d_assert_with_reason(type_has_custom_serialize(TYPE), @src(), "type `{s}` does not have a custom serialize function", .{@typeName(TYPE)});
        comptime @call(.auto, @field(TYPE, CustomSerializeFnName), .{ self, curr_native_offset, SETTINGS });
    }

    pub fn add_type(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime TYPE: type, comptime SETTINGS: SerialSettings) void {
        const INFO = KindInfo.get_kind_info(TYPE);
        re_typed: switch (INFO) {
            .INT, .BOOL, .ENUM => {
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    const NAME = @typeName(TYPE);
                    self.ensure_space_for_n_more_debug_bytes(NAME.len + 2);
                    const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0 .. NAME.len + 2];
                    @memcpy(debug_slice, "(" ++ NAME ++ ")");
                    self.debug_stack_len += NAME.len + 2;
                }
                const is_signed = INFO != .BOOL and if (INFO == .INT) Types.type_is_signed_int(TYPE) else Types.type_is_signed_int(std.meta.Tag(TYPE));
                const SIGN = if (is_signed) IntegerSign.SIGNED else IntegerSign.UNSIGNED;
                self.add_integer_bytes(curr_native_offset, @sizeOf(TYPE), SIGN, SETTINGS, .NOT_A_UNION_TAG);
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    self.print_debug_target(@src());
                    const NAME = @typeName(TYPE);
                    self.debug_stack_len -= NAME.len + 2;
                }
            },
            .FLOAT => {
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    const NAME = @typeName(TYPE);
                    self.ensure_space_for_n_more_debug_bytes(NAME.len + 2);
                    const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0 .. NAME.len + 2];
                    @memcpy(debug_slice, "(" ++ NAME ++ ")");
                    self.debug_stack_len += NAME.len + 2;
                }
                self.add_float_bytes(curr_native_offset, @sizeOf(TYPE), SETTINGS, .NOT_A_UNION_TAG);
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    self.print_debug_target(@src());
                    const NAME = @typeName(TYPE);
                    self.debug_stack_len -= NAME.len + 2;
                }
            },
            .ARRAY, .VECTOR => {
                const LEN = if (INFO.is_array()) INFO.ARRAY.len else INFO.VECTOR.len;
                const CHILD = if (INFO.is_array()) INFO.ARRAY.child else INFO.VECTOR.child;
                const CHILD_SIZE = @sizeOf(CHILD);
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    const NAME = if (INFO.is_array()) "[Array]" else "[Vector]";
                    self.ensure_space_for_n_more_debug_bytes(NAME.len);
                    const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0..NAME.len];
                    @memcpy(debug_slice, NAME);
                    self.debug_stack_len += NAME.len;
                }
                comptime var local_native_offset = curr_native_offset;
                for (0..LEN) |_| {
                    self.add_type(local_native_offset, CHILD, SETTINGS);
                    local_native_offset += CHILD_SIZE;
                }
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    self.print_debug_target(@src());
                    const NAME = if (INFO.is_array()) "[Array]" else "[Vector]";
                    self.debug_stack_len -= NAME.len;
                }
            },
            .STRUCT => |S| {
                if (S.backing_integer) |backing_int| {
                    continue :re_typed KindInfo.get_kind_info(backing_int);
                } else {
                    if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                        const NAME = @typeName(TYPE);
                        self.ensure_space_for_n_more_debug_bytes(NAME.len);
                        const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0..NAME.len];
                        @memcpy(debug_slice, NAME);
                        self.debug_stack_len += NAME.len;
                    }
                    if (comptime type_has_custom_serialize(TYPE)) {
                        self.add_type_with_custom_serializer(curr_native_offset, TYPE, SETTINGS);
                    } else {
                        inline for (S.fields) |field| {
                            if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                                const NAME = "\n." ++ field.name ++ ":";
                                self.ensure_space_for_n_more_debug_bytes(NAME.len);
                                const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0..NAME.len];
                                @memcpy(debug_slice, NAME);
                                self.debug_stack_len += NAME.len;
                            }
                            const local_offset = @offsetOf(TYPE, field.name);
                            const real_offset = curr_native_offset + local_offset;
                            self.add_type(real_offset, field.type, SETTINGS);
                            if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                                self.print_debug_target(@src());
                                const NAME = "\n." ++ field.name ++ ":";
                                self.debug_stack_len -= NAME.len;
                            }
                        }
                    }
                    if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                        self.print_debug_target(@src());
                        const NAME = @typeName(TYPE);
                        self.debug_stack_len -= NAME.len;
                    }
                }
            },
            .UNION => {
                if (comptime type_has_custom_serialize(TYPE)) {
                    self.add_type_with_custom_serializer(curr_native_offset, TYPE, SETTINGS);
                } else {
                    assert_unreachable(@src(), "unions are not supported for *automatic* serialization.\n\t- EITHER implement `pub fn {s}(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime SETTINGS: SerialSettings) void` on the type\n\t- OR use `SerialUnion`, which is an extern struct that implements a custom serialize function", .{CustomSerializeFnName});
                }
            },
            else => assert_unreachable(@src(), "type kind `{s}` does not have a serializer (simple) routine, exact type is `{s}`", .{ @tagName(INFO), @typeName(TYPE) }),
        }
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
    NEED_UNION_TAG_SERIAL_CAPTURE_NEXT,
    NEED_UNION_TAG_ID_NEXT,
    NEED_UNION_START_NEXT,
};

/// USE WITH CAUTION! This performs NO safety checking/validation and assumes the routine is well-formed
///
/// The normal, safe way to get a concrete serial routine is to use a `SerialRoutineBuilder` and use one of the `finalize()` funcs on it.
pub fn define_serial_routine(comptime TOTAL_OPS_: usize, comptime ROUTINE_: [TOTAL_OPS_]DataOp, comptime TYPE_: type, comptime ENDIAN_: Endian) type {
    return struct {
        pub const TOTAL_OPS = TOTAL_OPS_;
        pub const TYPE = TYPE_;
        pub const ENDIAN = ENDIAN_;
        pub const ROUTINE = ROUTINE_;

        pub fn serialize_to_slice(val_ptr: *const TYPE, serial_slice: []u8) SerialWriteError!usize {
            const native: []u8 = @alignCast(@constCast(std.mem.asBytes(val_ptr)));
            return serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .NATIVE_TO_SERIAL, .SLICE, native, SerialDest{ .slice = serial_slice });
        }
        pub fn serialize_to_writer(val_ptr: *const TYPE, writer: *std.Io.Writer) SerialWriteError!usize {
            const native: []u8 = @alignCast(@constCast(std.mem.asBytes(val_ptr)));
            return serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .NATIVE_TO_SERIAL, .READER_WRITER, native, SerialDest{ .writer = writer });
        }
        pub fn deserialize_from_slice(serial_data: []const u8, val_ptr: *TYPE) SerialReadError!usize {
            const native: []u8 = @alignCast(std.mem.asBytes(val_ptr));
            return serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .SERIAL_TO_NATIVE, .SLICE, native, SerialSource{ .slice = serial_data });
        }
        pub fn deserialize_from_reader(reader: *std.Io.Reader, val_ptr: *TYPE) SerialReadError!usize {
            const native: []u8 = @alignCast(std.mem.asBytes(val_ptr));
            return serial_internal(TOTAL_OPS, ROUTINE[0..TOTAL_OPS], .SERIAL_TO_NATIVE, .READER_WRITER, native, SerialSource{ .reader = reader });
        }
    };
}

fn do_zigzag_adjustment(temp_buffer: *[16]u8, native_size: usize, comptime DIR: SER_DIR) void {
    assert_with_reason(native_size == 2 or native_size == 4 or native_size == 8 or native_size == 16, @src(), "zigzag encoding only supported for i16, i32, i64, isize, and i128, got native integer with {d} bytes", .{native_size});
    switch (DIR) {
        .NATIVE_TO_SERIAL => switch (native_size) {
            2 => {
                const bytes: [2]u8 = undefined;
                @memcpy(bytes[0..], temp_buffer[0..2]);
                const i16_int: i16 = @bitCast(bytes);
                const u16_int: u16 = @bitCast((i16_int >> 15) ^ (i16_int << 1));
                bytes = @bitCast(u16_int);
                @memcpy(temp_buffer[0..2], bytes);
            },
            4 => {
                const bytes: [4]u8 = undefined;
                @memcpy(bytes[0..4], temp_buffer[0..4]);
                const i32_int: i32 = @bitCast(bytes);
                const u32_int: u32 = @bitCast((i32_int >> 31) ^ (i32_int << 1));
                bytes = @bitCast(u32_int);
                @memcpy(temp_buffer[0..4], bytes);
            },
            8 => {
                const bytes: [8]u8 = undefined;
                @memcpy(bytes[0..8], temp_buffer[0..8]);
                const i64_int: i64 = @bitCast(bytes);
                const u64_int: u64 = @bitCast((i64_int >> 63) ^ (i64_int << 1));
                bytes = @bitCast(u64_int);
                @memcpy(temp_buffer[0..8], bytes);
            },
            16 => {
                const bytes: [16]u8 = undefined;
                @memcpy(bytes[0..16], temp_buffer[0..16]);
                const i128_int: i128 = @bitCast(bytes);
                const u128_int: u128 = @bitCast((i128_int >> 127) ^ (i128_int << 1));
                bytes = @bitCast(u128_int);
                @memcpy(temp_buffer[0..16], bytes);
            },
            else => unreachable,
        },
        .SERIAL_TO_NATIVE => switch (native_size) {
            2 => {
                const bytes: [2]u8 = undefined;
                @memcpy(bytes[0..], temp_buffer[0..2]);
                const u16_int: u16 = @bitCast(bytes);
                const i16_int: i16 = bit_cast(u16_int >> 1, i16) ^ -(bit_cast(u16_int, i16) & 1);
                bytes = @bitCast(i16_int);
                @memcpy(temp_buffer[0..2], bytes);
            },
            4 => {
                const bytes: [4]u8 = undefined;
                @memcpy(bytes[0..4], temp_buffer[0..4]);
                const u32_int: u32 = @bitCast(bytes);
                const i32_int: i32 = bit_cast(u32_int >> 1, i32) ^ -(bit_cast(u32_int, i32) & 1);
                bytes = @bitCast(i32_int);
                @memcpy(temp_buffer[0..4], bytes);
            },
            8 => {
                const bytes: [8]u8 = undefined;
                @memcpy(bytes[0..8], temp_buffer[0..8]);
                const u64_int: u64 = @bitCast(bytes);
                const i64_int: i64 = bit_cast(u64_int >> 1, i64) ^ -(bit_cast(u64_int, i64) & 1);
                bytes = @bitCast(i64_int);
                @memcpy(temp_buffer[0..8], bytes);
            },
            16 => {
                const bytes: [16]u8 = undefined;
                @memcpy(bytes[0..16], temp_buffer[0..16]);
                const u128_int: u128 = @bitCast(bytes);
                const i128_int: i128 = bit_cast(u128_int >> 1, i128) ^ -(bit_cast(u128_int, i128) & 1);
                bytes = @bitCast(i128_int);
                @memcpy(temp_buffer[0..16], bytes);
            },
            else => unreachable,
        },
    }
}

fn do_serial_move_mem(move: MemCopyMove, ser_idx: *isize, op_idx: *usize, serial: []u8, serial_start: usize, serial_end: usize, native: []u8, native_start: usize, native_end: usize, comptime SWAP: bool, comptime DIR: SER_DIR) void {
    switch (SWAP) {
        true => {
            comptime var sidx: usize = num_cast(ser_idx.*, usize);
            comptime var nidx: usize = native_end;
            while (sidx < serial_end) : (sidx += 1) {
                nidx -= 1;
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        serial[sidx] = native[nidx];
                    },
                    .SERIAL_TO_NATIVE => {
                        native[nidx] = serial[sidx];
                    },
                }
            }
        },
        false => switch (DIR) {
            .NATIVE_TO_SERIAL => {
                @memcpy(serial[serial_start..serial_end], native[native_start..native_end]);
            },
            .SERIAL_TO_NATIVE => {
                @memcpy(native[native_start..native_end], serial[serial_start..serial_end]);
            },
        },
    }
    ser_idx.* += num_cast(move.copy_len, isize);
    op_idx.* += 1;
}

fn do_varint_p_move_mem(move: MemCopyMove, ser_idx: *isize, op_idx: usize, serial: []u8, serial_start: usize, serial_end: usize, native: []u8, native_start: usize, native_end: usize, native_len: usize, zigzag: bool, comptime SWAP: bool, comptime DIR: SER_DIR) void {
    // 0xxxxxxx = 1 byte (< 128)
    // 10xxxxxx = 2 byte (< 16384)
    // 110xxxxx = 3 byte (< 2097152)
    // 1110xxxx = 4 byte (< 268435456)
    // 11110xxx = 5 byte (< 34359738368)
    // 111110xx = 6 byte (< 4398046511104)
    // 1111110x = 7 byte (< 562949953421312)
    // 11111110 = 8 byte (< 72057594037927936)
    // 11111111 = 9+ byte:
    // 11111111 0xxxxxxx = 9 byte  (< 9223372036854775808)
    // 11111111 10xxxxxx = 10 byte
    // 11111111 110xxxxx = 11 byte
    // 11111111 1110xxxx = 12 byte
    // 11111111 11110xxx = 13 byte
    // 11111111 111110xx = 14 byte
    // 11111111 1111110x = 15 byte
    // 11111111 11111110 = 16 byte
    var temp_buffer: [16]u8 = undefined;
    assert_with_reason(native_len == 2 or native_len == 4 or native_len == 8 or native_len == 16, @src(), "VarInts are only upported for 2, 4, 8, or 16 byte integers, got native len {d}", .{native_len});
    switch (DIR) {
        .NATIVE_TO_SERIAL => {
            switch (native_len) {
                2 => @memcpy(temp_buffer[0..2], native[native_start..native_end]),
                4 => @memcpy(temp_buffer[0..4], native[native_start..native_end]),
                8 => @memcpy(temp_buffer[0..8], native[native_start..native_end]),
                16 => @memcpy(temp_buffer[0..16], native[native_start..native_end]),
                else => unreachable,
            }
            if (zigzag) {
                do_zigzag_adjustment(&temp_buffer, native_len, DIR);
            }
            const num_bytes = switch (native_len) {
                2 => get: {
                    var u16_bytes: [2]u8 = undefined;
                    @memcpy(u16_bytes[0..2], temp_buffer[0..2]);
                    const u16_int: u16 = @bitCast(u16_bytes);
                    break :get switch (u16_int) {
                        0...127 => 1,
                        128...16383 => 2,
                        16384...0xFFFF => 3,
                    };
                },
                4 => get: {
                    var u32_bytes: [4]u8 = undefined;
                    @memcpy(u32_bytes[0..4], temp_buffer[0..4]);
                    const u32_int: u32 = @bitCast(u32_bytes);
                    break :get switch (u32_int) {
                        0...127 => 1,
                        128...16383 => 2,
                        16384...2097151 => 3,
                        2097152...268435455 => 4,
                        268435456...0xFFFFFFFF => 5,
                    };
                },
                8 => @memcpy(temp_buffer[0..8], native[native_start..native_end]), //CHECKPOINT
                16 => @memcpy(temp_buffer[0..16], native[native_start..native_end]),
                else => unreachable,
            };
            const MOST_SIG_BYTE = if (NATIVE_ENDIAN == .BIG_ENDIAN) native_start else native_end - 1;
            const LEAST_SIG_BYTE = if (NATIVE_ENDIAN == .LITTLE_ENDIAN) native_start else native_end - 1;
            const STEP_ADD = if (NATIVE_ENDIAN == .BIG_ENDIAN) 0 else 1;
            const STEP_SUB = if (NATIVE_ENDIAN == .BIG_ENDIAN) 1 else 0;
            var num_bytes: usize = 0;
            var waste_bytes: usize = 0;
            var trim_bits: usize = 0;
            var i: usize = MOST_SIG_BYTE;
            var b: u8 = native[i];
            check_next_byte: switch (b) {
                0b0_0000000...0b0_1111111 => {
                    num_bytes += 1;
                    trim_bits = 1;
                },
                0b10_000000...0b10_111111 => {
                    num_bytes += 2;
                    trim_bits = 2;
                },
                0b110_00000...0b110_11111 => {
                    num_bytes += 3;
                    trim_bits = 3;
                },
                0b1110_0000...0b1110_1111 => {
                    num_bytes += 4;
                    trim_bits = 4;
                },
                0b11110_000...0b11110_111 => {
                    num_bytes += 5;
                    trim_bits = 5;
                },
                0b111110_00...0b111110_11 => {
                    num_bytes += 6;
                    trim_bits = 6;
                },
                0b1111110_0...0b1111110_1 => {
                    num_bytes += 7;
                    trim_bits = 7;
                },
                0b11111110 => {
                    num_bytes += 8;
                    waste_bytes += 1;
                },
                0b11111111 => {
                    num_bytes += 8;
                    waste_bytes += 1;
                    i = i + STEP_ADD - STEP_SUB;
                    b = native[i];
                    continue :check_next_byte b;
                },
            }
        },
        .SERIAL_TO_NATIVE => {},
    }
    switch (SWAP) {
        true => {
            comptime var sidx: usize = num_cast(ser_idx.*, usize);
            comptime var nidx: usize = native_end;
            while (sidx < serial_end) : (sidx += 1) {
                nidx -= 1;
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        serial[sidx] = native[nidx];
                    },
                    .SERIAL_TO_NATIVE => {
                        native[nidx] = serial[sidx];
                    },
                }
            }
        },
        false => switch (DIR) {
            .NATIVE_TO_SERIAL => {
                @memcpy(serial[serial_start..serial_end], native[native_start..native_end]);
            },
            .SERIAL_TO_NATIVE => {
                @memcpy(native[native_start..native_end], serial[serial_start..serial_end]);
            },
        },
    }
    ser_idx.* += num_cast(move.copy_len, isize);
    op_idx.* += 1;
}

fn get_num_varint_prefix_info(serial: []u8, serial_start: usize, native: []u8, native_start: usize, native_end: usize, SIGN: IntegerSign, comptime DIR: SER_DIR) VarintPrefixInfo {
    var out: VarintPrefixInfo = .{};
    switch (DIR) {
        .NATIVE_TO_SERIAL => {
            const native_size = native_end - native_start;
            switch (native_size) {
                2 => {},
            }
        },
        .SERIAL_TO_NATIVE => {},
    }
}

fn serial_internal(comptime NUM_OPS: usize, comptime ROUTINE: []const DataOp, comptime DIR: SER_DIR, comptime SERIAL: SerialKind, native: []u8, serial: if (DIR == .SERIAL_TO_NATIVE) SerialSource else SerialDest) (if (DIR == .SERIAL_TO_NATIVE) SerialReadError else SerialWriteError)!usize {
    var serial_idx: isize = 0;
    var tag_got: u64 = undefined;
    var num_tags_this_union: u32 = 0;
    var tags_checked_this_union: u32 = 0;
    var op_idx: usize = 0;
    var dynamic_serial_adjustment: isize = 0;
    while (op_idx < NUM_OPS) {
        const op = ROUTINE[op_idx];
        switch (op) {
            .MOVE_DATA_NO_SWAP => |move| {
                const native_start: usize = @intCast(serial_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                const native_end = native_start + num_cast(move.copy_len, usize);
                const serial_start = num_cast(serial_idx, usize);
                const serial_end = serial_start + num_cast(move.copy_len, usize);
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        try serial.write_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                    .SERIAL_TO_NATIVE => {
                        try serial.read_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                }
                serial_idx += num_cast(move.copy_len, isize);
                op_idx += 1;
            },
            .MOVE_DATA_SWAP => |move| {
                const native_start: usize = @intCast(serial_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                const native_end = native_start + num_cast(move.copy_len, usize);
                const serial_start = num_cast(serial_idx, usize);
                const serial_end = serial_start + num_cast(move.copy_len, usize);
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        try serial.write_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                    .SERIAL_TO_NATIVE => {
                        try serial.read_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                }
                serial_idx += num_cast(move.copy_len, isize);
                op_idx += 1;
            },
            .MOVE_DATA_NO_SWAP_SAVE_TAG => |move| {
                const native_start: usize = @intCast(serial_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                const native_end = native_start + num_cast(move.copy_len, usize);
                const serial_start = num_cast(serial_idx, usize);
                const serial_end = serial_start + num_cast(move.copy_len, usize);
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        try serial.write_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                    .SERIAL_TO_NATIVE => {
                        try serial.read_data_in_order(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                }
                serial_idx += num_cast(move.copy_len, isize);
                op_idx += 1;
                tag_got = OpaqueUnionTag.cast_endian_serial_to_endian_u64_any(native[native_start..native_end]);
            },
            .MOVE_DATA_SWAP_SAVE_TAG => |move| {
                const native_start: usize = @intCast(serial_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                const native_end = native_start + num_cast(move.copy_len, usize);
                const serial_start = num_cast(serial_idx, usize);
                const serial_end = serial_start + num_cast(move.copy_len, usize);
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        try serial.write_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                    .SERIAL_TO_NATIVE => {
                        try serial.read_data_swap(SERIAL, native, native_start, native_end, serial_start, serial_end);
                    },
                }
                serial_idx += num_cast(move.copy_len, isize);
                op_idx += 1;
                tag_got = OpaqueUnionTag.cast_serial_and_swap_to_endian_u64_any(native[native_start..native_end]);
            },
            .UNION_HEADER => |header| {
                num_tags_this_union = header.num_fields;
                tags_checked_this_union = 0;
                op_idx += 1;
            },
            .UNION_TAG_ID => |tag_match| {
                if (tag_got == tag_match) {
                    op_idx += 1;
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
                op_idx += routine_start.offset_to_first_routine_op;
            },
            .UNION_ROUTINE_END => |routine_end| {
                op_idx += num_cast(routine_end.ops_to_advance_to_exit_union, u32);
                dynamic_serial_adjustment += num_cast(routine_end.routine_serial_delta_adjustment, isize);
            },
            else => unreachable,
        }
    }
    return @intCast(serial_idx);
}

test SerialRoutineBuilder {
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

        pub const Serial = Root.SerialUnion.SerialUnion(@This(), struct {}, .EXTERN);

        pub const EXAMPLE_1 = Serial.new(.DOG, Dog.EXAMPLE_1);
        pub const EXAMPLE_2 = Serial.new(.DOG, Dog.EXAMPLE_2);
        pub const EXAMPLE_3 = Serial.new(.CAT, Cat.EXAMPLE_1);
        pub const EXAMPLE_4 = Serial.new(.CAT, Cat.EXAMPLE_2);
    };
    const PetOrPerson = union(MsgKind) {
        PERSON: Person,
        PET: DogOrCat.Serial,

        pub const Serial = Root.SerialUnion.SerialUnion(@This(), struct {}, .EXTERN);

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
        var skip_buf: [256]usize = undefined;
        var debug_buf: [1024]u8 = undefined;
        var builder = SerialRoutineBuilder.init(op_buf[0..1024], skip_buf[0..256]);
        builder.debug_stack = debug_buf[0..1024];
        const settings = SerialSettings{
            .INTEGER_BYTE_PACKING = .LITTLE_ENDIAN,
            .COMPTIME_EVAL_QUOTA = 50000,
            .ADD_ROUTINE_DEBUG_INFO = false,
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
    for (test_cases[0..], 0..) |case_struct, i| {
        test_struct_in = case_struct;
        test_struct_out = TestStruct.EXAMPLE_0;
        serial_len_in = try CONCRETE.serialize_to_slice(&test_struct_in, test_serial[0..1024]);
        serial_len_out = try CONCRETE.deserialize_from_slice(test_serial[0..1024], &test_struct_out);
        try Test.expect_equal(serial_len_in, "serial_len_in", serial_len_out, "serial_len_out", "serial mismatch between in and out on same data (test case {d})", .{i});
        try Test.expect_true(Utils.object_equals(test_struct_in, test_struct_out), "Utils.object_equals(test_struct_in, test_struct_out)", "input and output structs didnt have same values for same serial (test case {d})", .{i});
    }
}
