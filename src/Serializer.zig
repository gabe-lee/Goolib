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

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const read_int = std.mem.readInt;
const DEBUG = std.debug.print;
const DEBUG_CT = Utils.comptime_debug_print;

pub const NATIVE_ENDIAN = Endian.NATIVE;

pub const ByteOpKind = enum(u8) {
    NATIVE_TO_SERIAL_NO_SWAP,
    NATIVE_TO_SERIAL_SWAP,
    NATIVE_TO_SERIAL_NO_SWAP_SAVE_TAG,
    NATIVE_TO_SERIAL_SWAP_SAVE_TAG,
    UNION_HEADER,
    UNION_TAG_ID,
    UNION_ROUTINE_START,

    UNION_ROUTINE_END,
};

pub const DataOp = union(ByteOpKind) {
    NATIVE_TO_SERIAL_NO_SWAP: MemCopyMove,
    NATIVE_TO_SERIAL_SWAP: MemCopyMove,
    NATIVE_TO_SERIAL_NO_SWAP_SAVE_TAG: MemCopyMove,
    NATIVE_TO_SERIAL_SWAP_SAVE_TAG: MemCopyMove,
    UNION_HEADER: UnionHeader,
    UNION_TAG_ID: u64,
    UNION_ROUTINE_START: UnionRoutineStart,
    UNION_ROUTINE_END: UnionRoutineEndTemp,

    pub fn mem_move_no_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        return DataOp{ .NATIVE_TO_SERIAL_NO_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_swap(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len > 1, @src(), "mem swap data ops cannot be 1 byte in size, because 1 byte cant be endian swapped", .{});
        return DataOp{ .NATIVE_TO_SERIAL_SWAP = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_no_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len == 1 or copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .NATIVE_TO_SERIAL_NO_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
    }
    pub fn mem_move_swap_save_tag(comptime native_to_serial_delta: i32, comptime copy_len: u32) DataOp {
        assert_with_reason(copy_len > 1, @src(), "mem swap data ops cannot be 1 byte in size, because 1 byte cant be endian swapped", .{});
        assert_with_reason(copy_len == 2 or copy_len == 4 or copy_len == 8, @src(), "'_save_tag()' data ops can only be 1, 2, 4, or 8 bytes in size, got {d}", .{copy_len});
        return DataOp{ .NATIVE_TO_SERIAL_SWAP_SAVE_TAG = .mem_copy_move(native_to_serial_delta, copy_len) };
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
        return DataOp{ .UNION_ROUTINE_END = UnionRoutineEndTemp{
            .delta = RoutineEndDelta{ .true_op_index_of_routine_end = @intCast(current_builder_op_len) },
            .routine_serial_delta_adjustment = this_routine_bytes,
        } };
    }

    pub fn can_combine(comptime prev: DataOp, comptime next: DataOp) ?DataOp {
        if (prev == .NATIVE_TO_SERIAL_NO_SWAP and next == .NATIVE_TO_SERIAL_NO_SWAP) {
            if (prev.NATIVE_TO_SERIAL_NO_SWAP.native_to_serial_delta == next.NATIVE_TO_SERIAL_NO_SWAP.native_to_serial_delta) {
                return DataOp.mem_move_no_swap(prev.NATIVE_TO_SERIAL_NO_SWAP.native_to_serial_delta, prev.NATIVE_TO_SERIAL_NO_SWAP.copy_len + next.NATIVE_TO_SERIAL_NO_SWAP.copy_len);
            }
        }
        return null;
    }
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
            .routine_serial_adjustment = self.routine_serial_delta_adjustment,
        };
    }
};

pub const UnionRoutineEnd = struct {
    ops_to_advance_to_exit_union: u32,
    routine_serial_adjustment: u32,
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
        const tag_u64 = TAG_OPQ.cast_tag_to_endian_u64(SETTINGS.TARGET_ENDIAN, tag_value);
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
            const routine_end: *UnionRoutineEndTemp = &builder.ops[routine_end_op_idx].UNION_ROUTINE_END;
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
pub const CustomSerializeFnName = "custom_serialize_routine";

pub fn type_has_custom_serialize(comptime T: type) bool {
    if (@hasDecl(T, CustomSerializeFnName)) {
        if (@TypeOf(@field(T, CustomSerializeFnName)) == CustomSerializeFn) {
            return true;
        }
    }
    return false;
}

pub const SerialSettings = struct {
    TARGET_ENDIAN: Endian = .LITTLE_ENDIAN,
    EVAL_QUOTA: u32 = 5000,
    ADD_ROUTINE_DEBUG_INFO: bool = false,
    TARGET_DEBUG_INDEX: ?usize = null,
    // COMPRESS_INT: bool = false,
};

pub const SerialRoutineBuilder = struct {
    ops: []DataOp = &.{},
    skip_ahead_stack: []usize = &.{},
    debug_stack: []u8 = &.{},
    debug_stack_len: usize = 0,
    debug_target: ?usize = null,
    debug_target_printed: bool = false,
    ops_len: usize = 0,
    skip_ahead_len: usize = 0,
    curr_serial_offset: usize = 0,
    curr_union_depth: u32 = 0,
    max_union_depth: u32 = 0,

    pub fn init(comptime op_buffer: []DataOp, comptime skip_ahead_buffer: []usize) SerialRoutineBuilder {
        return SerialRoutineBuilder{
            .ops = op_buffer,
            .skip_ahead_stack = skip_ahead_buffer,
        };
    }

    pub fn reset(comptime self: *SerialRoutineBuilder) void {
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

    const SER_DIR = enum(u8) {
        NATIVE_TO_SERIAL,
        SERIAL_TO_NATIVE,
    };

    const TEST_SER_MODE = enum(u8) {
        NORMAL,
        NEED_UNION_TAG_SERIAL_CAPTURE_NEXT,
        NEED_UNION_TAG_ID_NEXT,
        NEED_UNION_START_NEXT,
    };

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
                .NATIVE_TO_SERIAL_NO_SWAP => |move| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(ser_idx >= move.native_to_serial_delta, @src(), "native_to_serial_delta would cause serial index to go below zero", .{});
                    const native_start: usize = @intCast(ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                    const native_end = native_start + num_cast(move.copy_len, usize);
                    const serial_start = num_cast(ser_idx, usize) + dynamic_serial_adjustment;
                    const serial_end = serial_start + num_cast(move.copy_len, usize);
                    switch (DIRECTION) {
                        .NATIVE_TO_SERIAL => {
                            @memcpy(serial_slice[serial_start..serial_end], native_slice[native_start..native_end]);
                        },
                        .SERIAL_TO_NATIVE => {
                            @memcpy(native_slice[native_start..native_end], serial_slice[serial_start..serial_end]);
                        },
                    }
                    ser_idx += num_cast(move.copy_len, isize);
                    op_idx += 1;
                },
                .NATIVE_TO_SERIAL_SWAP => |move| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(ser_idx > move.native_to_serial_delta, @src(), "native_to_serial_delta would cause serial index to go below zero", .{});
                    const native_start: usize = @intCast(ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                    const native_end = native_start + num_cast(move.copy_len, usize);
                    const serial_start = num_cast(ser_idx, usize) + dynamic_serial_adjustment;
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
                },
                .NATIVE_TO_SERIAL_NO_SWAP_SAVE_TAG => |move| {
                    self.d_assert_with_reason(mode == .NEED_UNION_TAG_SERIAL_CAPTURE_NEXT, @src(), "must be in `.NEED_UNION_TAG_SERIAL_CAPTURE_NEXT` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(ser_idx > move.native_to_serial_delta, @src(), "native_to_serial_delta would cause serial index to go below zero", .{});
                    const native_start: usize = @intCast(ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
                    const native_end = native_start + num_cast(move.copy_len, usize);
                    const serial_start = num_cast(ser_idx, usize) + dynamic_serial_adjustment;
                    const serial_end = serial_start + num_cast(move.copy_len, usize);
                    switch (DIRECTION) {
                        .NATIVE_TO_SERIAL => {
                            @memcpy(serial_slice[serial_start..serial_end], native_slice[native_start..native_end]);
                        },
                        .SERIAL_TO_NATIVE => {
                            @memcpy(native_slice[native_start..native_end], serial_slice[serial_start..serial_end]);
                        },
                    }
                    ser_idx += num_cast(move.copy_len, isize);
                    op_idx += 1;
                    tag_got = OpaqueUnionTag.cast_endian_serial_to_endian_u64_any(serial_slice[serial_start..serial_end]);
                    mode = .NEED_UNION_TAG_ID_NEXT;
                },
                .NATIVE_TO_SERIAL_SWAP_SAVE_TAG => |move| {
                    self.d_assert_with_reason(mode == .NEED_UNION_TAG_SERIAL_CAPTURE_NEXT, @src(), "must be in `.NEED_UNION_TAG_SERIAL_CAPTURE_NEXT` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(ser_idx > move.native_to_serial_delta, @src(), "native_to_serial_delta would cause serial index to go below zero", .{});
                    const native_start: usize = @intCast(ser_idx - (num_cast(move.native_to_serial_delta, isize) + dynamic_serial_adjustment));
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
                    tag_got = OpaqueUnionTag.cast_endian_serial_to_endian_u64_any(serial_slice[serial_start..serial_end]);
                    mode = .NEED_UNION_TAG_ID_NEXT;
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
                .UNION_ROUTINE_END => |routine_end| {
                    self.d_assert_with_reason(mode == .NORMAL, @src(), "must be in `.NORMAL` mode for this op, curr mode is `{s}`", .{@tagName(mode)});
                    self.d_assert_with_reason(allowed_union_ends > 0, @src(), "union ends not allowed here (no union routine has been started)", .{});
                    allowed_union_ends -= 1;
                    op_idx += num_cast(routine_end.delta.ops_to_advance_to_exit_union, u32);
                    dynamic_serial_adjustment += num_cast(routine_end.routine_serial_delta_adjustment, isize);
                },
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

    pub fn build_routine_for_type(comptime self: *SerialRoutineBuilder, comptime TYPE: type, comptime SETTINGS: SerialSettings) void {
        @setEvalBranchQuota(SETTINGS.EVAL_QUOTA);
        self.reset();
        self.debug_target = SETTINGS.TARGET_DEBUG_INDEX;
        self.add_type(0, TYPE, SETTINGS);
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

    pub fn add_endian_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: usize, comptime size: usize, comptime SETTINGS: SerialSettings, comptime UNION_TAG: SaveTagMode) void {
        self.ensure_space_for_n_more_ops(1);
        const SWAP = NATIVE_ENDIAN != SETTINGS.TARGET_ENDIAN;
        const native_to_serial_delta: i32 = if (self.curr_serial_offset >= curr_native_offset) num_cast(self.curr_serial_offset - curr_native_offset, i32) else -num_cast(curr_native_offset - self.curr_serial_offset, i32);
        if (SWAP and size > 1) {
            switch (UNION_TAG) {
                .IS_A_UNION_TAG => self.ops[self.ops_len] = .mem_move_swap_save_tag(native_to_serial_delta, @intCast(size)),
                .NOT_A_UNION_TAG => self.ops[self.ops_len] = .mem_move_swap(native_to_serial_delta, @intCast(size)),
            }
            self.ops_len += 1;
            self.curr_serial_offset += num_cast(size, i32);
        } else {
            const has_prev = self.ops_len > 0;
            comptime var prev: DataOp = DataOp.mem_move_swap(0, 2);
            if (has_prev) {
                prev = self.ops[self.ops_len - 1];
            }
            const next = switch (UNION_TAG) {
                .IS_A_UNION_TAG => DataOp.mem_move_no_swap_save_tag(native_to_serial_delta, size),
                .NOT_A_UNION_TAG => DataOp.mem_move_no_swap(native_to_serial_delta, size),
            };
            if (prev.can_combine(next)) |combined| {
                self.ops[self.ops_len - 1] = combined;
            } else {
                self.ops[self.ops_len] = next;
                self.ops_len += 1;
            }
            self.curr_serial_offset += num_cast(size, i32);
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
        self.add_endian_bytes(tag_native_offset, UTAG_SIZE, SETTINGS, .IS_A_UNION_TAG);
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
            .INT, .FLOAT, .BOOL, .ENUM => {
                if (SETTINGS.ADD_ROUTINE_DEBUG_INFO) {
                    const NAME = @typeName(TYPE);
                    self.ensure_space_for_n_more_debug_bytes(NAME.len + 2);
                    const debug_slice: []u8 = self.debug_stack[self.debug_stack_len..][0 .. NAME.len + 2];
                    @memcpy(debug_slice, "(" ++ NAME ++ ")");
                    self.debug_stack_len += NAME.len + 2;
                }
                self.add_endian_bytes(curr_native_offset, @sizeOf(TYPE), SETTINGS, .NOT_A_UNION_TAG);
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

test SerialRoutineBuilder {
    const Test = Root.Testing;
    comptime {
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
        var test_struct_in = TestStruct.EXAMPLE_1;
        var test_struct_out = TestStruct.EXAMPLE_2;
        var op_buf: [1024]DataOp = undefined;
        var skip_buf: [256]usize = undefined;
        var debug_buf: [1024]u8 = undefined;
        var builder = SerialRoutineBuilder.init(op_buf[0..1024], skip_buf[0..256]);
        builder.debug_stack = debug_buf[0..1024];
        const settings = SerialSettings{
            .TARGET_ENDIAN = .LITTLE_ENDIAN,
            .EVAL_QUOTA = 50000,
            .ADD_ROUTINE_DEBUG_INFO = false,
        };
        builder.build_routine_for_type(TestStruct, settings);
        var test_serial: [1024]u8 = undefined;
        const input_native_bytes = std.mem.asBytes(&test_struct_in);
        const output_native_bytes = std.mem.asBytes(&test_struct_out);
        var serial_len_in: usize = undefined;
        var serial_len_out: usize = undefined;
        const test_cases = [_]TestStruct{
            TestStruct.EXAMPLE_1,
            TestStruct.EXAMPLE_2,
            TestStruct.EXAMPLE_3,
            TestStruct.EXAMPLE_4,
            TestStruct.EXAMPLE_5,
            TestStruct.EXAMPLE_6,
        };
        for (test_cases[0..], 0..) |case_struct, i| {
            test_struct_in = case_struct;
            test_struct_out = TestStruct.EXAMPLE_0;
            serial_len_in = builder.test_serialize(input_native_bytes, test_serial[0..1024]);
            serial_len_out = builder.test_deserialize(test_serial[0..1024], output_native_bytes);
            try Test.expect_equal(serial_len_in, "serial_len_in", serial_len_out, "serial_len_out", "serial mismatch between in and out on same data (test case {d})", .{i});
            try Test.expect_true(Utils.object_equals(test_struct_in, test_struct_out), "Utils.object_equals(test_struct_in, test_struct_out)", "input and output structs didnt have same values for same serial (test case {d})", .{i});
        }
    }
}
