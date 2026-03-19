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

// pub const MAX_UNDEFINED_BYTES_TO_COPY_IN_ADJACENT_OPS = 32;

pub const ByteOpKind = enum(u8) {
    NATIVE_TO_SERIAL_NO_SWAP,
    NATIVE_TO_SERIAL_SWAP,
    UNION_HEADER,
    ROUTINE_OFFSET,
    UNION_TAG_ID_SEGMENT,
};

pub const ByteDataOp = union(ByteOpKind) {
    NATIVE_TO_SERIAL_NO_SWAP: ByteMove,
    NATIVE_TO_SERIAL_SWAP: ByteMove,
    UNION_HEADER: UnionHeader,
    ROUTINE_OFFSET: UnionRoutineOffset,
    UNION_TAG_ID_SEGMENT: UnionTagSegmentInEndian,

    pub fn byte_move_no_swap(comptime native_to_serial: i32) ByteDataOp {
        return ByteDataOp{ .NATIVE_TO_SERIAL_NO_SWAP = ByteMove.new(native_to_serial) };
    }
    pub fn byte_move_swap(comptime native_to_serial: i32) ByteDataOp {
        return ByteDataOp{ .NATIVE_TO_SERIAL_SWAP = ByteMove.new(native_to_serial) };
    }
    pub fn union_header(comptime num_fields: usize, comptime tag_type: type) ByteDataOp {
        return ByteDataOp{ .UNION_HEADER = UnionHeader{ .num_fields = @intCast(num_fields), .tag_type = OpaqueUnionTag.from_tag_type(tag_type) } };
    }
    pub fn routine_offset(offset_to_routine: i32) ByteDataOp {
        return ByteDataOp{ .ROUTINE_OFFSET = UnionRoutineOffset{ .offset_to_routine = offset_to_routine } };
    }
    pub fn union_tag_segment(tag_seg: [4]u8) ByteDataOp {
        return ByteDataOp{ .UNION_TAG_ID_SEGMENT = UnionTagSegmentInEndian{ .tag_seg = tag_seg } };
    }
};

pub const ByteMove = struct {
    native_to_serial_delta: i32 = 0,

    pub inline fn new(native_to_serial: i32) ByteMove {
        return ByteMove{ .native_to_serial_delta = native_to_serial };
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

    pub fn num_segments(comptime self: OpaqueUnionTag) u8 {
        return switch (self) {
            .U8, .U16, .U32 => 1,
            .U64 => 2,
        };
    }

    pub fn real_type(comptime self: OpaqueUnionTag) type {
        return switch (self) {
            .U8 => u8,
            .U16 => u16,
            .U32 => u32,
            .U64 => u64,
        };
    }

    pub fn undef(comptime self: OpaqueUnionTag) self.real_type() {
        return switch (self) {
            .U8 => 0xAA,
            .U16 => 0xAAAA,
            .U32 => 0xAAAAAAAA,
            .U64 => 0xAAAAAAAAAAAAAAAA,
        };
    }
    pub fn zero(comptime self: OpaqueUnionTag) self.real_type() {
        return 0;
    }
    pub fn tag_ptr_from_union_ptr_and_offset(comptime self: OpaqueUnionTag, comptime UNION: type, union_ptr: *UNION, offset: usize) *self.real_type() {
        var raw_ptr: [*]u8 = @ptrCast(union_ptr);
        raw_ptr += offset;
        return @ptrCast(@alignCast(raw_ptr));
    }
    pub fn tag_ptr_from_union_ptr_and_offset_const(comptime self: OpaqueUnionTag, comptime UNION: type, union_ptr: *const UNION, offset: usize) *const self.real_type() {
        var raw_ptr: [*]const u8 = @ptrCast(union_ptr);
        raw_ptr += offset;
        return @ptrCast(@alignCast(raw_ptr));
    }

    pub fn from_serial_slice(comptime self: OpaqueUnionTag, data: []const u8) self.real_type() {
        assert_with_reason(num_cast(self, usize) <= data.len, @src(), "data slice is not long enough for this union tag (need {d} bytes, got {d})", .{ @intFromEnum(self), data.len });
    }

    pub fn cast_union_tag(comptime self: OpaqueUnionTag, any_union: anytype) self.real_type() {
        const tag = std.meta.activeTag(any_union);
        return @bitCast(tag);
    }
};

pub const TagBytes = struct {
    segs: [2]UnionTagSegmentInEndian,
    num_segs: u8,
    seg_1_len: u8 = 0,
    seg_2_len: u8 = 0,

    pub fn from_val(val: anytype, comptime TARGET_ENDIAN: Endian) TagBytes {
        const SWAP = TARGET_ENDIAN != NATIVE_ENDIAN;
        const T = @TypeOf(val);
        const SIZE = @sizeOf(T);
        assert_with_reason(Types.type_is_enum(T), @src(), "only enum types with byte size 1, 2, 4, or 8 are allowed, got type `{s}`", .{@typeName(T)});
        assert_with_reason(SIZE == 1 or SIZE == 2 or SIZE == 4 or SIZE == 8, @src(), "only enum types with byte size 1, 2, 4, or 8 are allowed, got type `{s}`", .{@typeName(T)});
        switch (SIZE) {
            1 => {
                const val_raw: u8 = @bitCast(@intFromEnum(val));
                const seg: [4]u8 = .{ val_raw, 0, 0, 0 };
                return TagBytes{
                    .segs = .{ .new(seg), .new(@splat(0)) },
                    .num_segs = 1,
                    .seg_1_len = 1,
                };
            },
            2 => {
                const val_raw: [2]u8 = @bitCast(@intFromEnum(val));
                var seg: [4]u8 = .{ val_raw[0], val_raw[1], 0, 0 };
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, seg[0..2]);
                }
                return TagBytes{
                    .segs = .{ .new(seg), .new(@splat(0)) },
                    .num_segs = 1,
                    .seg_1_len = 2,
                };
            },
            4 => {
                var seg: [4]u8 = @bitCast(@intFromEnum(val));
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, seg[0..4]);
                }
                return TagBytes{
                    .segs = .{ .new(seg), .new(@splat(0)) },
                    .num_segs = 1,
                    .seg_1_len = 4,
                };
            },
            8 => {
                var val_raw: [8]u8 = @bitCast(@intFromEnum(val));
                if (SWAP) {
                    std.mem.byteSwapAllElements(u8, val_raw[0..8]);
                }
                const seg_1: [4]u8 = undefined;
                const seg_2: [4]u8 = undefined;
                @memcpy(seg_1[0..4], val_raw[0..4]);
                @memcpy(seg_2[0..4], val_raw[4..8]);
                return TagBytes{
                    .segs = .{ .new(seg_1), .new(seg_2) },
                    .num_segs = 2,
                    .seg_1_len = 4,
                    .seg_2_len = 4,
                };
            },
            else => unreachable,
        }
    }
};

pub const UnionHeader = struct {
    num_fields: u16,
    tag_type: OpaqueUnionTag,
};

pub const UnionRoutineOffset = struct {
    offset_to_routine: i32,
};

pub const UnionTagSegmentInEndian = struct {
    tag_seg: [4]u8,

    pub fn new(tag_seg: [4]u8) UnionTagSegmentInEndian {
        return UnionTagSegmentInEndian{ .tag_seg = tag_seg };
    }
};

pub const UnionRoutineBuilder = struct {
    tag_to_routine_offsets: []ByteDataOp,
    offset_stride: usize = 1,
    routine_idx: usize = 0,
    field_count: usize = 0,
    routine_total: i32 = 0,
    union_tag_opaque: OpaqueUnionTag,
    tag_seg_1_len: u8 = 1,

    fn routine_offset_slot(comptime self: *UnionRoutineBuilder) *UnionRoutineOffset {
        return &self.tag_to_routine_offsets[self.routine_idx * self.offset_stride].ROUTINE_OFFSET;
    }
    fn tag_segment_slot_1(comptime self: *UnionRoutineBuilder) *UnionTagSegmentInEndian {
        return &self.tag_to_routine_offsets[(self.routine_idx * self.offset_stride) + 1].UNION_TAG_ID_SEGMENT;
    }
    fn tag_segment_slot_2(comptime self: *UnionRoutineBuilder) *UnionTagSegmentInEndian {
        return &self.tag_to_routine_offsets[(self.routine_idx * self.offset_stride) + 2].UNION_TAG_ID_SEGMENT;
    }
    fn final_routine_offset_slot(comptime self: *UnionRoutineBuilder) *UnionRoutineOffset {
        return &self.tag_to_routine_offsets[self.tag_to_routine_offsets.len - 1].ROUTINE_OFFSET;
    }

    pub fn add_type(comptime self: *UnionRoutineBuilder, comptime builder: *SerialRoutineBuilder, comptime tag_value: anytype, comptime curr_native_offset_: i32, comptime TARGET_ENDIAN: Endian, comptime TYPE: type, comptime EVAL_QUOTA: u32) void {
        @setEvalBranchQuota(EVAL_QUOTA);
        const prev_serial_offset = builder.curr_serial_offset;
        const routine_offset = self.routine_offset_slot();
        const tag_slot_1 = self.tag_segment_slot_1();
        const tag_segs = TagBytes.from_val(tag_value, TARGET_ENDIAN);
        const TAG_OPQ = OpaqueUnionTag.from_tag_type(@TypeOf(tag_value));
        assert_with_reason(TAG_OPQ == self.union_tag_opaque, @src(), "opaque tag param from `tag_value` (`{s}`) does not match the one this union builder was created with (`{s}`)", .{ @tagName(TAG_OPQ), @tagName(self.union_tag_opaque) });
        routine_offset.offset_to_routine += self.routine_total;
        tag_slot_1.tag_seg = tag_segs.segs[0].tag_seg;
        if (self.offset_stride == 3) {
            const tag_slot_2 = self.tag_segment_slot_2();
            tag_slot_2.tag_seg = tag_segs.segs[1].tag_seg;
        }
        builder.add_type(curr_native_offset_, TARGET_ENDIAN, TYPE);
        const routine_size = builder.curr_serial_offset - prev_serial_offset;
        self.routine_total += routine_size;
        self.routine_idx += 1;
    }

    pub fn end_union_builder(comptime self: *UnionRoutineBuilder) void {
        assert_with_reason(self.routine_idx == self.field_count, @src(), "cannot end union serial routine builder: not all field tags had routines specified", .{});
        const routine_offset = self.final_routine_offset_slot();
        routine_offset.offset_to_routine += self.routine_total;
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

pub const CustomSerializeFn = fn (comptime self: *SerialRoutineBuilder, comptime curr_native_offset: i32, comptime TARGET_ENDIAN: Endian) void;
pub const CustomSerializeFnName = "custom_serialize_routine";

pub fn type_has_custom_serialize(comptime T: type) bool {
    if (@hasDecl(T, CustomSerializeFnName)) {
        if (@TypeOf(@field(T, CustomSerializeFnName)) == CustomSerializeFn) {
            return true;
        }
    }
    return false;
}

pub const SerialRoutineBuilder = struct {
    ops: []ByteDataOp = &.{},
    ops_len: usize = 0,
    curr_serial_offset: i32 = 0,

    pub fn init(buffer: []ByteDataOp) SerialRoutineBuilder {
        return SerialRoutineBuilder{
            .ops = buffer,
        };
    }

    pub fn reset(comptime self: *SerialRoutineBuilder) void {
        self.curr_serial_offset = 0;
        self.ops_len = 0;
    }

    pub fn ensure_space_for_n_more_ops(comptime self: *SerialRoutineBuilder, comptime n: usize) void {
        assert_with_reason(self.ops_len + n <= self.ops.len, @src(), "ran out of space for data ops. Need at least {d} (possibly more), have {d}. provide a larger buffer", .{ self.ops_len + n, self.ops.len });
    }

    pub fn add_endian_bytes(comptime self: *SerialRoutineBuilder, comptime curr_native_offset_: i32, comptime size: usize, comptime TARGET_ENDIAN: Endian) void {
        self.ensure_space_for_n_more_ops(size);
        const SWAP = NATIVE_ENDIAN != TARGET_ENDIAN;
        comptime var curr_native_offset: i32 = curr_native_offset_;
        comptime var local_byte_idx: usize = 0;
        if (SWAP) {
            curr_native_offset += size;
            while (local_byte_idx < size) : (local_byte_idx += 1) {
                curr_native_offset -= 1;
                const native_to_serial_delta = self.curr_serial_offset - curr_native_offset;
                self.ops[self.ops_len] = .byte_move_swap(native_to_serial_delta);
                self.ops_len += 1;
                self.curr_serial_offset += 1;
            }
        } else {
            while (local_byte_idx < size) : (local_byte_idx += 1) {
                const native_to_serial_delta = self.curr_serial_offset - curr_native_offset;
                self.ops[self.ops_len] = .byte_move_no_swap(native_to_serial_delta);
                self.ops_len += 1;
                self.curr_serial_offset += 1;
                curr_native_offset += 1;
            }
        }
    }

    pub fn add_union_header(comptime self: *SerialRoutineBuilder, comptime TAG_TYPE: type, comptime FIELD_COUNT: usize) void {
        self.ensure_space_for_n_more_ops(1);
        self.ops[self.ops_len] = .union_header(FIELD_COUNT, TAG_TYPE);
        self.ops_len += 1;
    }
    pub fn start_union_routine_builder(comptime self: *SerialRoutineBuilder, comptime tag_native_offset: i32, comptime TARGET_ENDIAN: Endian, comptime TAG_TYPE: type, comptime FIELD_COUNT: usize) UnionRoutineBuilder {
        const UTAG = OpaqueUnionTag.from_tag_type(TAG_TYPE);
        const UTAG_SIZE = UTAG.bytes_usize();
        const SEG_COUNT = UTAG.num_segments();
        const OFFSET_STRIDE: usize = @intCast(SEG_COUNT + 1);
        const SLOT_COUNT = (FIELD_COUNT * OFFSET_STRIDE) + 1;
        self.ensure_space_for_n_more_ops(1 + UTAG_SIZE + SLOT_COUNT);
        self.ops[self.ops_len] = .union_header(FIELD_COUNT, TAG_TYPE);
        self.ops_len += 1;
        self.add_endian_bytes(tag_native_offset, UTAG_SIZE, TARGET_ENDIAN);
        const tag_to_routine_slots = self.add_many_union_tag_routine_offset_slots(SLOT_COUNT);
        comptime var tag_to_routine_offset: i32 = SLOT_COUNT;
        comptime var tag_to_routine_idx: usize = 0;
        while (tag_to_routine_idx < FIELD_COUNT) {
            const real_idx = tag_to_routine_idx * OFFSET_STRIDE;
            tag_to_routine_slots[real_idx] = .routine_offset(tag_to_routine_offset);
            tag_to_routine_slots[real_idx + 1] = .union_tag_segment(@splat(0));
            if (SEG_COUNT == 2) {
                tag_to_routine_slots[real_idx + 2] = .union_tag_segment(@splat(0));
            }
            tag_to_routine_offset -= num_cast(OFFSET_STRIDE, i32);
            tag_to_routine_idx += 1;
        }
        tag_to_routine_slots[tag_to_routine_slots.len - 1] = .routine_offset(tag_to_routine_offset);
        return UnionRoutineBuilder{
            .tag_to_routine_offsets = tag_to_routine_slots,
            .union_tag_opaque = UTAG,
            .offset_stride = OFFSET_STRIDE,
            .field_count = FIELD_COUNT,
        };
    }
    pub fn add_union_tag_routine_offset(comptime self: *SerialRoutineBuilder, comptime OFFSET_TO_ROUTINE: i32) void {
        self.ensure_space_for_n_more_ops(1);
        self.ops[self.ops_len] = .routine_offset(OFFSET_TO_ROUTINE);
        self.ops_len += 1;
    }
    pub fn add_many_union_tag_routine_offset_slots(comptime self: *SerialRoutineBuilder, comptime COUNT: usize) []ByteDataOp {
        self.ensure_space_for_n_more_ops(COUNT);
        const start = self.ops_len;
        self.ops_len += COUNT;
        return self.ops.ptr[start..self.ops_len];
    }
    pub fn add_type_with_custom_serializer(comptime self: *SerialRoutineBuilder, comptime curr_native_offset_: i32, comptime TARGET_ENDIAN: Endian, comptime TYPE: type) void {
        assert_with_reason(type_has_custom_serialize(TYPE), @src(), "type `{s}` does not have a custom serialize function", .{@typeName(TYPE)});
        comptime @call(.auto, @field(TYPE, CustomSerializeFnName), .{ self, curr_native_offset_, TARGET_ENDIAN });
    }

    pub fn add_type(comptime self: *SerialRoutineBuilder, comptime curr_native_offset_: i32, comptime TARGET_ENDIAN: Endian, comptime TYPE: type) void {
        const INFO = KindInfo.get_kind_info(TYPE);
        const SIZE = @sizeOf(TYPE);
        comptime var curr_native_offset: i32 = curr_native_offset_;
        re_typed: switch (INFO) {
            .INT, .FLOAT, .BOOL, .ENUM => {
                self.add_endian_bytes(curr_native_offset, @sizeOf(TYPE), TARGET_ENDIAN);
            },
            .ARRAY, .VECTOR => {
                const LEN = if (INFO.is_array()) INFO.ARRAY.len else INFO.VECTOR.len;
                const CHILD = if (INFO.is_array()) INFO.ARRAY.child else INFO.VECTOR.child;
                for (0..LEN) |_| {
                    self.add_type(curr_native_offset, TARGET_ENDIAN, CHILD);
                    curr_native_offset += SIZE;
                }
            },
            .STRUCT => |S| {
                if (S.backing_integer) |backing_int| {
                    continue :re_typed KindInfo.get_kind_info(backing_int);
                } else if (comptime type_has_custom_serialize(TYPE)) {
                    self.add_type_with_custom_serializer(curr_native_offset, TARGET_ENDIAN, TYPE);
                } else {
                    inline for (S.fields) |field| {
                        const local_offset = @offsetOf(TYPE, field.name);
                        const real_offset = curr_native_offset + local_offset;
                        self.add_type(real_offset, TARGET_ENDIAN, field.type);
                    }
                }
            },
            .UNION => {
                if (comptime type_has_custom_serialize(TYPE)) {
                    self.add_type_with_custom_serializer(curr_native_offset, TARGET_ENDIAN, TYPE);
                } else {
                    assert_unreachable(@src(), "unions are not supported for *automatic* serialization.\n\t- EITHER implement `pub fn {s}(comptime self: *SerialRoutineBuilder, comptime curr_native_offset: i32, comptime TARGET_ENDIAN: Endian) void` on the type\n\t- OR use `Types.HybridUnion`, which is an extern struct that implements a custom serialize function", .{CustomSerializeFnName});
                }
            },
            else => assert_unreachable(@src(), "type kind `{s}` does not have a serializer (simple) routine, exact type is `{s}`", .{ @tagName(INFO), @typeName(TYPE) }),
        }
    }
};

test SerialRoutineBuilder {
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

            pub const Hybrid = Root.HybridUnion.HybridUnion(@This(), struct {}, .EXTERN);

            pub const EXAMPLE_1 = Hybrid.new(.DOG, Dog.EXAMPLE_1);
            pub const EXAMPLE_2 = Hybrid.new(.DOG, Dog.EXAMPLE_2);
            pub const EXAMPLE_3 = Hybrid.new(.CAT, Cat.EXAMPLE_1);
            pub const EXAMPLE_4 = Hybrid.new(.CAT, Cat.EXAMPLE_2);
        };
        const PetOrPerson = union(MsgKind) {
            PERSON: Person,
            PET: DogOrCat.Hybrid,

            pub const Hybrid = Root.HybridUnion.HybridUnion(@This(), struct {}, .EXTERN);

            pub const EXAMPLE_1 = Hybrid.new(.PERSON, Person.EXAMPLE_1);
            pub const EXAMPLE_2 = Hybrid.new(.PERSON, Person.EXAMPLE_2);
            pub const EXAMPLE_3 = Hybrid.new(.PET, DogOrCat.EXAMPLE_1);
            pub const EXAMPLE_4 = Hybrid.new(.PET, DogOrCat.EXAMPLE_2);
            pub const EXAMPLE_5 = Hybrid.new(.PET, DogOrCat.EXAMPLE_3);
            pub const EXAMPLE_6 = Hybrid.new(.PET, DogOrCat.EXAMPLE_4);
        };
        const TestStruct = struct {
            version: u32 = 1,
            timestamp: i64 = 1999_12_01,
            msg: PetOrPerson.Hybrid = PetOrPerson.EXAMPLE_1,
        };
        var op_buf: [1024]ByteDataOp = undefined;
        var builder = SerialRoutineBuilder.init(op_buf[0..1024]);
        builder.add_type(0, NATIVE_ENDIAN, TestStruct);
    }
}
