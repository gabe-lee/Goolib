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
const SliceRange = Root.CommonTypes.SliceRangeSmall;

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

pub const NATIVE_ENDIAN = Endian.NATIVE;

pub const ReadWrite = @import("./Serializer_ReadWrite.zig");

pub const SerialDest = ReadWrite.SerialDest;
pub const SerialDestSlice = ReadWrite.SerialDestSlice;
pub const SerialDestWriter = ReadWrite.SerialDestWriter;
pub const SerialSource = ReadWrite.SerialSource;
pub const SerialSourceSlice = ReadWrite.SerialSourceSlice;
pub const SerialSourceReader = ReadWrite.SerialSourceReader;
pub const SerialWriteError = ReadWrite.SerialWriteError;
pub const SerialReadError = ReadWrite.SerialReadError;

fn crude_assert_slice_mem_leayout() void {
    comptime {
        const A = []u8;
        const B = []std.builtin.Type;

        const A_len_off = @offsetOf(A, "len");
        const A_ptr_off = @offsetOf(A, "ptr");
    }
}

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

pub const CustomSerialRoutineMode = enum(u8) {
    /// Use the default serialization technique
    NO_CUSTOM_ROUTINE,
    /// Use a custom set of DataOp's defined on the type
    CUSTOM_COMPTIME_OP_LIST,
    /// Use a custom serialize/deserialize function at runtime
    CUSTOM_RUNTIME_SERIALIZE,
};

/// A custom function that takes the serial settings for this unique 'type + settings' pair, and
/// appends DataOps to the provided OPS_BUFFER, and returns the total number of ops appended.
///
/// `SETTINGS.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_COMPTIME_OP_LIST`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomComptimeRoutineOpsBuilder = fn (comptime SETTINGS: ObjectSerialSettings, comptime OPS_BUFFER: []DataOp, comptime UNIQUE_TYPE_BUFFER: []const UniqueSerialType) u32;

/// Param `self` is a pointer to the object to serialize, and `settings` is the intended
/// serial settings for this 'type + settings' pair
///
/// `self` calls an arbitrary number of write commands on the `serial_dest`
/// to write its data, then returns
///
/// `settings.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_RUNTIME_SERIALIZE`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomWriteToSerialFunc = fn (self: *const anyopaque, settings: ObjectSerialSettings, serial_dest: SerialDest) SerialWriteError!void;
/// Param `self` is a pointer to the object to serialize, and `settings` is the intended
/// serial settings for this 'type + settings' pair
///
/// `self` calls an arbitrary number of read commands on the `serial_source`
/// to read its data, then returns
///
/// `settings.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_RUNTIME_SERIALIZE`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomReadFromSerialFunc = fn (self: *anyopaque, settings: ObjectSerialSettings, serial_source: SerialSource) SerialReadError!void;

pub const CustomRuntimeSerializeFuncs = struct {
    write_to_serial: *const CustomWriteToSerialFunc,
    read_from_serial: *const CustomReadFromSerialFunc,
};

pub const CustomSerialRoutine = union(CustomSerialRoutineMode) {
    /// Use the default logic for serialization
    NO_CUSTOM_ROUTINE,
    /// Use a custom function to generate comptime serial ops for this 'type + settings' pair
    CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE: CustomComptimeRoutineOpsBuilder,
    /// Run a completely custom function at runtime to serialize this
    /// object, using no comptime-generated bytecode.
    CUSTOM_RUNTIME_SERIALIZE: *const CustomRuntimeSerializeFuncs,

    pub fn equals(a: CustomSerialRoutine, b: CustomSerialRoutine) bool {
        if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
        switch (a) {
            .NO_CUSTOM_ROUTINE => return true,
            .CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE => |func| {
                return func == b.CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE;
            },
            .CUSTOM_RUNTIME_SERIALIZE => |funcs| {
                return ( //
                    funcs.read_from_serial == b.CUSTOM_RUNTIME_SERIALIZE.read_from_serial and
                        funcs.write_to_serial == b.CUSTOM_RUNTIME_SERIALIZE.write_to_serial);
            },
        }
    }
};

pub const SerialManagerArrayLens = struct {
    UNIQUE_TYPE_BUFFER_MAX_LEN: u32 = 128,
    OP_BUFFER_MAX_LEN: u32 = 1024,
    // union_end_buffer_len: u32 = 128,
    // alloc_name_buffer_len: u32 = 512,
    // alloc_name_list_len: u32 = 64,
    // subroutine_stack_len: u32 = 128,
    // heirarchy_pool_len: u32 = 512,
    // heirarchy_stack_len: u32 = 64,
    // cycle_eval_list_len: u32 = 64,
};

pub const DataOpKind = enum(u8) {
    // Data Transfer
    TRANSFER_SAME_ENDIAN,
    TRANSFER_SAME_ENDIAN_SAVE_TAG,
    TRANSFER_SAME_ENDIAN_SAVE_LEN,
    TRANSFER_SWAP_ENDIAN,
    TRANSFER_SWAP_ENDIAN_SAVE_TAG,
    TRANSFER_SWAP_ENDIAN_SAVE_LEN,
    TRANSFER_VARINT,
    TRANSFER_VARINT_SAVE_TAG,
    TRANSFER_VARINT_SAVE_LEN,
    TRANSFER_VARINT_ZIGZAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_LEN,
    // Subroutines
    START_SUBROUTINE_NO_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION,
    START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION,
    START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION,
    // Union Control
    UNION_HEADER,
    UNION_TAG_ID,
    // Pointer Control
    READ_POINTER_OR_ALLOCATE_STATIC_LEN,
    READ_POINTER_OR_ALLOCATE_DYNAMIC_LEN,

    // SINGLE_ITEM_POINTER_HEADER,
    // MANY_ITEM_POINTER_HEADER,

    READ_POINTER_LEN,
    FULL_CUSTOM_FUNCTION,
};

pub const DataOp = extern union {
    GENERIC: DataOpGeneric,
    // Data Transfer
    DATA_TRANSFER: DataTransfer,
    // Subroutines
    SUBROUTINE: SubroutineStart,
    // Mode control
    UNION_HEADER: UnionHeader,
    UNION_TAG_ID: UnionTagId,
    // SUBROUTINE_START,
    // SINGLE_ITEM_POINTER_HEADER,
    // MANY_ITEM_POINTER_HEADER,
    // POINTER_ROUTINE_END,
    // READ_POINTER_LEN,
    // START_SUBROUTINE,
    // FULL_CUSTOM_FUNCTION,

    pub fn get_kind(self: DataOp) DataOpKind {
        return self.GENERIC.kind;
    }

    pub fn new_transfer_data_op(comptime native_size: u32, comptime offset_to_next_field: i32, comptime serial_size: u32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .TRANSFER_SAME_ENDIAN, .TRANSFER_SAME_ENDIAN_SAVE_TAG, .TRANSFER_SAME_ENDIAN_SAVE_LEN, .TRANSFER_SWAP_ENDIAN, .TRANSFER_SWAP_ENDIAN_SAVE_TAG, .TRANSFER_SWAP_ENDIAN_SAVE_LEN, .TRANSFER_VARINT, .TRANSFER_VARINT_SAVE_TAG, .TRANSFER_VARINT_SAVE_LEN, .TRANSFER_VARINT_ZIGZAG, .TRANSFER_VARINT_ZIGZAG_SAVE_TAG, .TRANSFER_VARINT_ZIGZAG_SAVE_LEN => {},
            else => assert_unreachable(@src(), "cannot create a `DataTransfer` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .DATA_TRANSFER = DataTransfer{ .native_size = native_size, .offset_to_next_field = offset_to_next_field, .serial_size = serial_size, .kind = kind } };
    }

    pub fn new_union_header_op(comptime num_fields: u32) DataOp {
        return DataOp{ .UNION_HEADER = UnionHeader{ .num_fields = num_fields } };
    }

    pub fn new_union_tag_id(comptime tag_as_u64_le: u64) DataOp {
        return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = tag_as_u64_le } };
    }

    pub fn new_subroutine_op(comptime subroutine_first_op: u32, comptime subroutine_num_ops: i32, comptime subroutine_static_repeat: u32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION, .START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION => {},
            else => assert_unreachable(@src(), "cannot create a `SubroutineStart` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .SUBROUTINE = SubroutineStart{ .subroutine_first_op = subroutine_first_op, .subroutine_num_ops = subroutine_num_ops, .subroutine_static_repeat = subroutine_static_repeat, .kind = kind } };
    }
};

const DataOpGeneric = extern struct {
    __padding: [15]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind,
};

const DataTransfer = extern struct {
    /// The size of the native types (number of bytes to fill)
    native_size: u32 = 0,
    /// The number of bytes to move from the current native field offset
    /// to the offset of the next sibling field to transfer. The
    /// last field should have an offset that moves back to the start of the object
    offset_to_next_field: i32 = 0,
    /// If 0, this indicates VarInt (variable size)
    ///
    /// If non-zero, but not equal to native_size, it indicates the value will be
    /// truncated in one of the serial directions
    serial_size: u32 = 0,
    __padding: [3]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .TRANSFER_SAME_ENDIAN,
};

const UnionHeader = extern struct {
    num_fields: u32 = 0,
    __padding: [11]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .UNION_HEADER,
};

const UnionTagId = extern struct {
    /// The union tag value first bitcast to a u64,
    /// then swapped to little-endian order, if needed
    tag_as_u64_le: u64 = 0,
    __padding: [7]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .UNION_TAG_ID,
};

const SubroutineStart = extern struct {
    subroutine_first_op: u32 = 0,
    subroutine_num_ops: u32 = 0,
    subroutine_static_repeat: u32 = 1,
    __padding: [3]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION,
};

const UniqueSerialType = struct {
    object_type: type,
    object_settings: ObjectSerialSettings,
    routine_start: u32 = 0,
    routine_end: u32 = 0,
    routine_made: bool = false,

    pub fn equals(comptime a: UniqueSerialType, b: UniqueSerialType) bool {
        return a.object_type == b.object_type and a.object_settings.equals(b.object_settings);
    }
};

pub const DataTransferTech = enum(u8) {
    TARGET_ENDIAN_SAME_SIZE,
    // ENDIAN_TRUNCATE_LARGER,
    VARINT_ZIGZAG,
    VARINT,
};

pub const DataCacheMode = enum(u8) {
    DONT_CACHE_DATA,
    CACHE_TAG,
    CACHE_LEN,
};

pub const DataOpManagerLowLevel = struct {
    ops: []DataOp = &.{},
    len: u32 = 0,

    pub fn add_transfer_data_op(comptime self: *DataOpManagerLowLevel, comptime native_size: u32, comptime offset_to_next_field: i32, comptime serial_size: u32, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech, comptime CACHE: DataCacheMode) void {
        assert_with_reason(self.len < self.ops.len, @src(), "", .{});
        comptime var kind: DataOpKind = if (native_size == 1) DataOpKind.TRANSFER_SAME_ENDIAN else switch (TECH) {
            .TARGET_ENDIAN_SAME_SIZE => switch (TARGET_ENDIAN) {
                .BIG_ENDIAN => switch (NATIVE_ENDIAN) {
                    .BIG_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN,
                    .LITTLE_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN,
                },
                .LITTLE_ENDIAN => switch (NATIVE_ENDIAN) {
                    .BIG_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN,
                    .LITTLE_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN,
                },
            },
            .VARINT => DataOpKind.TRANSFER_VARINT,
            .VARINT_ZIGZAG => DataOpKind.TRANSFER_VARINT_ZIGZAG,
        };
        kind = switch (CACHE) {
            .DONT_CACHE_DATA => kind,
            .CACHE_LEN => switch (kind) {
                .TRANSFER_SAME_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN_SAVE_LEN,
                .TRANSFER_SWAP_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN_SAVE_LEN,
                .TRANSFER_VARINT => DataOpKind.TRANSFER_VARINT_SAVE_LEN,
                .TRANSFER_VARINT_ZIGZAG => DataOpKind.TRANSFER_VARINT_ZIGZAG_SAVE_LEN,
                else => unreachable,
            },
            .CACHE_TAG => switch (kind) {
                .TRANSFER_SAME_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN_SAVE_TAG,
                .TRANSFER_SWAP_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN_SAVE_TAG,
                .TRANSFER_VARINT => DataOpKind.TRANSFER_VARINT_SAVE_TAG,
                .TRANSFER_VARINT_ZIGZAG => DataOpKind.TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
                else => unreachable,
            },
        };
        const op = DataOp.new_transfer_data_op(native_size, offset_to_next_field, serial_size, kind);
        self.ops[self.len] = op;
        self.len += 1;
    }

    // CHECKPOINT more add op methods and HighLevel version
};

const RoutineStackFrame = struct {
    routine_start: u32,
    routine_end: u32,
    routine_idx: u32,
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

pub const UsizeCompatMode = enum(u8) {
    /// usize and isize have no compatibility between 64 bit and 32 bit platforms
    NO_USIZE_COMPATIBILITY,
    // /// Forces usize and isize to always be serialized as a u64 for compatibility
    // /// between 64-bit and 32-bit platforms
    // USIZE_ALWAYS_U64,
    /// Forces usize and isize to always be serialized using VarInts for compatibility
    /// between 64-bit and 32-bit platforms
    USIZE_ALWAYS_VARINT,
};

pub const ObjectSerialSettings = struct {
    INTEGER_PACKING: IntegerPacking = .USE_TARGET_ENDIAN,
    TARGET_ENDIAN: Endian = .LITTLE_ENDIAN,
    ALLOCATOR_NAME: []const u8 = DEFAULT_ALLOC_NAME,
    POINTER_MODE: PointerMode = .FOLLOW_POINTERS,
    CUSTOM_ROUTINE: CustomSerialRoutine = .NO_CUSTOM_ROUTINE,
    USIZE_COMPATABILITY: UsizeCompatMode = .USIZE_ALWAYS_VARINT,

    pub fn equals(a: ObjectSerialSettings, b: ObjectSerialSettings) bool {
        return ( //
            a.INTEGER_PACKING == b.INTEGER_PACKING and
                a.TARGET_ENDIAN == b.TARGET_ENDIAN and
                a.POINTER_MODE == b.POINTER_MODE and
                a.USIZE_COMPATABILITY == b.USIZE_COMPATABILITY and
                std.mem.eql(u8, a.ALLOCATOR_NAME, b.ALLOCATOR_NAME) and
                a.CUSTOM_ROUTINE.equals(b.CUSTOM_ROUTINE)
                //
        );
    }

    pub fn combined_with_optional(self: ObjectSerialSettings, optionals: ?OptionalObjectSerialSettings) ObjectSerialSettings {
        var out = self;
        if (optionals) |opt| {
            if (opt.ALLOCATOR_NAME) |alloc_name| out.ALLOCATOR_NAME = alloc_name;
            if (opt.CUSTOM_ROUTINE) |routine| out.CUSTOM_ROUTINE = routine;
            if (opt.INTEGER_PACKING) |int_packing| out.INTEGER_PACKING = int_packing;
            if (opt.POINTER_MODE) |ptr_mode| out.POINTER_MODE = ptr_mode;
            if (opt.TARGET_ENDIAN) |endian| out.TARGET_ENDIAN = endian;
            if (opt.USIZE_COMPATABILITY) |compat| out.USIZE_COMPATABILITY = compat;
        }
        return out;
    }

    pub fn with_custom_routine_removed(self: ObjectSerialSettings) ObjectSerialSettings {
        var out = self;
        out.CUSTOM_ROUTINE = .NO_CUSTOM_ROUTINE;
        return out;
    }
};

pub const OptionalObjectSerialSettings = struct {
    INTEGER_PACKING: ?IntegerPacking = null,
    TARGET_ENDIAN: ?Endian = null,
    ALLOCATOR_NAME: ?[]const u8 = null,
    POINTER_MODE: ?PointerMode = null,
    CUSTOM_ROUTINE: ?CustomSerialRoutine = null,
    USIZE_COMPATABILITY: ?UsizeCompatMode = null,
};

pub const SERIAL_INFO_DECL = "SERIAL_INFO";
pub const OBJECT_SETTINGS_DECL = "OBJECT_SETTINGS";
pub const FIELD_SETTINGS_DECL = "FIELD_SETTINGS";
pub const FIELD_ALLOC_DECL = "FIELD_ALLOCATOR_NAMES";
pub const OPTIONAL_OBJECT_SETTINGS_TYPE_NAME = "OptionalObjectSerialSettings";
pub const OBJECT_SETTINGS_TYPE_NAME = "ObjectSerialSettings";
pub const DEFAULT_ALLOC_NAME = "_DEFAULT_ALLOC_";

fn eval_provided_types_to_count_and_record_all_unique_types(comptime TYPES_FOR_SERIALIZATION: []const type, comptime DEFAULT_SETTINGS: ObjectSerialSettings, comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: *u32) void {
    for (TYPES_FOR_SERIALIZATION) |TYPE_TO_SERIALIZE| {
        eval_one_type_to_count_and_record_all_unique_types(TYPE_TO_SERIALIZE, DEFAULT_SETTINGS, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
    }
}

fn eval_one_type_to_count_and_record_all_unique_types(comptime TYPE: type, comptime ROOT_SETTINGS: ObjectSerialSettings, comptime SETTINGS_FROM_PARENT: ?OptionalObjectSerialSettings, comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: *u32) void {
    const OBJECT_SETTINGS = get_object_settings(TYPE);
    comptime var SETTINGS = ROOT_SETTINGS.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(SETTINGS_FROM_PARENT);
    for (UNIQUE_TYPE_ARRAY[0..UNIQUE_TYPE_ARRAY_LEN.*]) |TYPE_ALREADY_RECORDED| {
        if (TYPE == TYPE_ALREADY_RECORDED.object_type and SETTINGS.equals(TYPE_ALREADY_RECORDED.object_settings)) return;
    }
    assert_with_reason(UNIQUE_TYPE_ARRAY_LEN.* < UNIQUE_TYPE_ARRAY.len, @src(), "ran out of slots for unique types, have {d}, need AT LEAST {d}, provide a larger `ARRAY_LENS.UNIQUE_TYPE_ARRAY_MAX_LEN` value", .{ UNIQUE_TYPE_ARRAY.len, UNIQUE_TYPE_ARRAY_LEN.* + 1 });
    UNIQUE_TYPE_ARRAY[UNIQUE_TYPE_ARRAY_LEN.*] = UniqueSerialType{
        .object_type = TYPE,
        .object_settings = SETTINGS,
    };
    UNIQUE_TYPE_ARRAY_LEN.* += 1;
    const TYPE_INFO = KindInfo.get_kind_info(TYPE);
    switch (TYPE_INFO) {
        .STRUCT => |STRUCT| {
            inline for (STRUCT.fields) |field| {
                const FIELD_SETTINGS = get_field_settings(TYPE, field.name);
                eval_one_type_to_count_and_record_all_unique_types(field.type, SETTINGS, FIELD_SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            }
        },
        .UNION => |UNION| {
            inline for (UNION.fields) |field| {
                const FIELD_SETTINGS = get_field_settings(TYPE, field.name);
                eval_one_type_to_count_and_record_all_unique_types(field.type, SETTINGS, FIELD_SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            }
        },
        else => {},
    }
}

fn get_object_settings(comptime TYPE: type) ?ObjectSerialSettings {
    const KIND = Kind.get_kind(TYPE);
    switch (KIND) {
        .STRUCT, .ENUM, .UNION, .OPAQUE => {
            if (@hasDecl(TYPE, SERIAL_INFO_DECL)) {
                const serial_info = @field(TYPE, SERIAL_INFO_DECL);
                assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_info), @src(), "type `{s}` has a `{s}` declaration, but it is not a struct type (it must be a struct), got type `{s}`", .{ @typeName(TYPE), SERIAL_INFO_DECL, @typeName(@TypeOf(serial_info)) });
                if (@hasDecl(serial_info, OBJECT_SETTINGS_DECL)) {
                    const object_settings = @field(serial_info, OBJECT_SETTINGS_DECL);
                    assert_with_reason(@TypeOf(object_settings) == OptionalObjectSerialSettings, @src(), "type `{s}` has a `{s}.{s}` declaration, but it is not a `{s}`, got type `{s}`", .{ @typeName(TYPE), SERIAL_INFO_DECL, OBJECT_SETTINGS_DECL, @typeName(OptionalObjectSerialSettings), @typeName(@TypeOf(object_settings)) });
                    return object_settings;
                }
            }
        },
        else => {},
    }
    return null;
}

fn get_field_settings(comptime PARENT: type, comptime FIELD_ON_PARENT: []const u8) ?OptionalObjectSerialSettings {
    if (@hasDecl(PARENT, SERIAL_INFO_DECL)) {
        const serial_info = @field(PARENT, SERIAL_INFO_DECL);
        assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_info), @src(), "type parent `{s}` has a `{s}` declaration, but it is not a struct type (it must be a struct)", .{ @typeName(PARENT), SERIAL_INFO_DECL });
        if (@hasDecl(serial_info, FIELD_SETTINGS_DECL)) {
            const serial_field_settings = @field(serial_info, FIELD_SETTINGS_DECL);
            assert_with_reason(Kind.STRUCT.type_is_same_kind(serial_field_settings), @src(), "type parent `{s}` has a `{s}.{s}` declaration, but it is not a struct type (it must be a struct, where each decl is of the form `pub const <field on parent>: SerialFieldSettings = .{...};)", .{ @typeName(PARENT), SERIAL_INFO_DECL, FIELD_SETTINGS_DECL });
            if (@hasDecl(serial_field_settings, FIELD_ON_PARENT)) {
                const field_settings = @field(serial_field_settings, FIELD_ON_PARENT);
                assert_with_reason(@TypeOf(field_settings) == OptionalObjectSerialSettings, @src(), "type parent `{s}` has a `{s}.{s}.{s}` declaration, but it is not a `{s}`, got type `{s}`", .{ @typeName(PARENT.?), SERIAL_INFO_DECL, FIELD_SETTINGS_DECL, FIELD_ON_PARENT, @typeName(OptionalObjectSerialSettings), @typeName(@TypeOf(field_settings)) });
                return field_settings;
            }
        }
    }
    return null;
}

fn build_op_routines_for_all_unique_types(comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_ARRAY_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: u32, comptime OP_BUFFER: *[ARRAY_LENS.OP_BUFFER_MAX_LEN]DataOp, comptime OP_BUFFER_LEN: *u32) void {
    for (UNIQUE_TYPE_ARRAY[0..UNIQUE_TYPE_ARRAY_LEN]) |*TYPE_TO_SERIALIZE| {
        build_op_routine_for_type(TYPE_TO_SERIALIZE, ARRAY_LENS, OP_BUFFER, OP_BUFFER_LEN);
    }
}

fn build_op_routine_for_type(comptime UNIQUE_TYPE: *UniqueSerialType, comptime ARRAY_LENS: SerialManagerArrayLens, comptime OP_BUFFER: *[ARRAY_LENS.OP_BUFFER_MAX_LEN]DataOp, comptime OP_BUFFER_LEN: *u32) void {
    if (UNIQUE_TYPE.routine_made) return;
}

pub fn SerializationManager(comptime TYPES_FOR_SERIALIZATION: []const type, comptime DEFAULT_SERIAL_SETTINGS: ObjectSerialSettings, comptime ARRAY_MAX_LENS: SerialManagerArrayLens) type {
    comptime var _UNIQUE_TYPE_ARRAY: [ARRAY_MAX_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialType = undefined;
    comptime var _UNIQUE_TYPE_ARRAY_LEN: u32 = 0;
    eval_provided_types_to_count_and_record_all_unique_types(TYPES_FOR_SERIALIZATION, DEFAULT_SERIAL_SETTINGS, ARRAY_MAX_LENS, &_UNIQUE_TYPE_ARRAY, &_UNIQUE_TYPE_ARRAY_LEN);
    comptime var _OP_BUFFER: [ARRAY_MAX_LENS.OP_BUFFER_MAX_LEN]DataOp = undefined;
    comptime var _OP_BUFFER_LEN: u32 = 0;
    build_op_routines_for_all_unique_types(ARRAY_MAX_LENS, &_UNIQUE_TYPE_ARRAY, _UNIQUE_TYPE_ARRAY_LEN, &_OP_BUFFER, &_OP_BUFFER_LEN);
    return struct {
        const Self = @This();
    };
}

test SerializationManager {
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
