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
const Alloc = Utils.Alloc;

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
const abs_cast = Root.Cast.abs_cast;
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
pub const SerialKind = ReadWrite.SerialKind;

pub const IntegerPacking = enum(u8) {
    /// If value is 0, serialize zero, else serialize 1
    NON_ZERO_READ_OR_WRITE_1_ELSE_0,
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
/// uses the provided `DataOpBuilderStruct` to build a set of operation needed to serialize the type.
///
/// `SETTINGS.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_COMPTIME_OP_LIST`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomComptimeRoutineOpsBuilder = fn (comptime OP_BUILDER: *DataOpBuilderHighLevel) void;

/// Param `self` is a pointer to the object to serialize, and `settings` is the intended
/// serial settings for this 'type + settings' pair
///
/// `self` calls an arbitrary number of write commands on the `serial_dest`
/// to write its data, then returns
///
/// `settings.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_RUNTIME_SERIALIZE`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomWriteToSerialFunc = fn (self: *const anyopaque, serial_dest: SerialDest, comptime SERIAL_KIND: SerialKind) SerialWriteError!usize;
/// Param `self` is a pointer to the object to serialize, and `settings` is the intended
/// serial settings for this 'type + settings' pair
///
/// `self` calls an arbitrary number of read commands on the `serial_source`
/// to read its data, then returns
///
/// `settings.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE` because that setting has already been evaluated as `.CUSTOM_RUNTIME_SERIALIZE`,
/// and it is overwritten before being passed to this function to prevent an infinite loop or incorrect inheritance by children types
pub const CustomReadFromSerialFunc = fn (self: *anyopaque, serial_source: SerialSource, comptime SERIAL_KIND: SerialKind) SerialReadError!usize;
/// This is a custom user-provided function that can be injected into the middle of the serialization process
/// to alter the native data BEFORE it is serialized.
///
/// This function should only manipulate fields/values that have NOT YET been serialized,
/// as it will have no effect on the ones that already have
///
/// `external_data` is an optional opaque pointer to an arbitrary type that the user
/// provides at runtime, if needed. The same exact object pointer will be provided to ALL calls to any
/// `DataManipulationNativeToSerial` or `DataManipulationSerialToNative`.
///
/// This should *generally* also match the effect of a provided `DataManipulationSerialToNative`,
/// but inverted. For example, if a `DataManipulationSerialToNative` sets 4 bits that
/// are server-side only and the client does not have, this function should clear
/// those 4 bits when this object is being sent out to the client
pub const DataManipulationNativeToSerial = fn (self: *anyopaque, external_data: ?*anyopaque) void;
/// This is a custom user-provided function that can be injected into the middle of the de-serialization process
/// to alter the native data AFTER it has been de-serialized.
///
/// This function should only manipulate fields/values that have ALREADY been de-serialized,
/// as it will have no effect on the ones that have not yet been (they will be overwritten)
///
/// `external_data` is an optional opaque pointer to an arbitrary type that the user
/// provides at runtime, if needed. The same exact object pointer will be provided to ALL calls to any
/// `DataManipulationNativeToSerial` or `DataManipulationSerialToNative`.
///
/// This should *generally* also match the effect of a provided `DataManipulationNativeToSerial`,
/// but inverted. For example, if a `DataManipulationNativeToSerial` clears 4 bits that
/// are server-side only and should not be seen by the client, this function should re-set
/// those 4 bits when this object comes back from the client (probably using `external_data`)
pub const DataManipulationSerialToNative = fn (self: *anyopaque, external_data: ?*anyopaque) void;

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
    ALLOC_NAME_BYTES_BUFFER_MAX_LEN: u32 = 512,
    ALLOC_NAME_LIST_MAX_LEN: u32 = 64,
    SUB_OBJECT_STACK_MAX_LEN: u32 = 32,
    // heirarchy_pool_len: u32 = 512,
    // heirarchy_stack_len: u32 = 64,
    // cycle_eval_list_len: u32 = 64,
};

pub const DataOpKind = enum(u8) {
    // Native Address Control
    ADD_NATIVE_OFFSET,
    // Data Transfer
    TRANSFER_SAME_ENDIAN,
    TRANSFER_SAME_ENDIAN_SAVE_TAG,
    TRANSFER_SAME_ENDIAN_SAVE_LEN,
    TRANSFER_SAME_ENDIAN_SAVE_NULL,
    TRANSFER_SWAP_ENDIAN,
    TRANSFER_SWAP_ENDIAN_SAVE_TAG,
    TRANSFER_SWAP_ENDIAN_SAVE_LEN,
    TRANSFER_SWAP_ENDIAN_SAVE_NULL,
    TRANSFER_VARINT,
    TRANSFER_VARINT_SAVE_TAG,
    TRANSFER_VARINT_SAVE_LEN,
    TRANSFER_VARINT_SAVE_NULL,
    TRANSFER_VARINT_ZIGZAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_LEN,
    TRANSFER_VARINT_ZIGZAG_SAVE_NULL,
    // Optional or Bool Transfer
    NON_ZERO_READ_OR_WRITE_1_ELSE_0,
    NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG,
    NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_LEN,
    NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_NULL,
    // Ref Unique Type Subroutine
    REF_UNIQUE_TYPE,
    // Subroutines
    START_SUBROUTINE_NO_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION,
    START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION,
    START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION,
    START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION,
    // Union Control
    UNION_HEADER,
    UNION_TAG_ID_ONE_FOLLOWING,
    UNION_TAG_ID_TWO_FOLLOWING,
    UNION_TAG_ID_THREE_FOLLOWING,
    UNION_TAG_ID_FOUR_FOLLOWING,
    UNION_TAG_ID_FIVE_FOLLOWING,
    UNION_TAG_ID_SIX_FOLLOWING,
    UNION_TAG_RANGE_ONE_FOLLOWING,
    UNION_TAG_RANGE_TWO_FOLLOWING,
    UNION_TAG_RANGE_THREE_FOLLOWING,
    UNION_TAG_RANGE_FOUR_FOLLOWING,
    UNION_TAG_RANGE_FIVE_FOLLOWING,
    UNION_TAG_RANGE_SIX_FOLLOWING,
    // Pointer Control
    ALLOCATED_POINTER_STATIC_LEN,
    ALLOCATED_POINTER_DYNAMIC_LEN,
    ALLOCATED_POINTER_STATIC_LEN_OR_NULL,
    ALLOCATED_POINTER_DYNAMIC_LEN_OR_NULL,
    ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL,
    ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL,
    ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL_OR_NULL,
    ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL_OR_NULL,
    // POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN,
    // POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN,
    POINTER_SENTINEL,
    // Custom
    FULL_CUSTOM_FUNCTION,
    DATA_MANIPULATION_NATIVE_TO_SERIAL,
    DATA_MANIPULATION_SERIAL_TO_NATIVE,

    pub const NUM_OP_KINDS = @intFromEnum(DataOpKind.DATA_MANIPULATION_SERIAL_TO_NATIVE) + 1;
};

pub const DataOp = extern union {
    // Generic (get kind from ANY payload)
    GENERIC: DataOpGeneric,
    // Native Address Control
    ADD_NATIVE_OFFSET: AddNativeOffset,
    // Data Transfer
    DATA_TRANSFER: DataTransfer,
    // Ref Unique Type for Subroutine
    REF_UNIQUE_TYPE_SUBRS: RefUniqueTypeSubroutine,
    // Subroutines
    SUBROUTINE: SubroutineStart,
    // Unions
    UNION_HEADER: UnionHeader,
    UNION_TAG_ID: UnionTagId,
    UNION_TAG_RANGE: UnionTagRange,
    // Pointers
    POINTER: Pointer,
    SENTINEL: Sentinel,
    // Custom
    FULL_CUSTOM_FUNCTION: CustomFunctions,
    DATA_MANIP_NATIVE_TO_SERIAL: DataManipNativeToSerial,
    DATA_MANIP_SERIAL_TO_NATIVE: DataManipSerialToNative,

    pub fn get_kind(self: DataOp) DataOpKind {
        return self.GENERIC.kind;
    }

    pub fn new_add_native_offset_op(comptime offset: i32) DataOp {
        return DataOp{ .ADD_NATIVE_OFFSET = AddNativeOffset{ .offset = offset } };
    }

    pub fn new_transfer_data_op(comptime native_size: u32, comptime offset_to_next_field: i32, comptime serial_size: u32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .NON_ZERO_READ_OR_WRITE_1_ELSE_0,
            .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_LEN,
            .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG,
            .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_NULL,
            .TRANSFER_SAME_ENDIAN,
            .TRANSFER_SAME_ENDIAN_SAVE_TAG,
            .TRANSFER_SAME_ENDIAN_SAVE_LEN,
            .TRANSFER_SAME_ENDIAN_SAVE_NULL,
            .TRANSFER_SWAP_ENDIAN,
            .TRANSFER_SWAP_ENDIAN_SAVE_TAG,
            .TRANSFER_SWAP_ENDIAN_SAVE_LEN,
            .TRANSFER_SWAP_ENDIAN_SAVE_NULL,
            .TRANSFER_VARINT,
            .TRANSFER_VARINT_SAVE_TAG,
            .TRANSFER_VARINT_SAVE_LEN,
            .TRANSFER_VARINT_SAVE_NULL,
            .TRANSFER_VARINT_ZIGZAG,
            .TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
            .TRANSFER_VARINT_ZIGZAG_SAVE_LEN,
            .TRANSFER_VARINT_ZIGZAG_SAVE_NULL,
            => {},
            else => assert_unreachable(@src(), "cannot create a `DataTransfer` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .DATA_TRANSFER = DataTransfer{ .native_size = native_size, .offset_to_next_field = offset_to_next_field, .serial_size = serial_size, .kind = kind } };
    }

    pub fn new_union_header_op(comptime num_fields: u32) DataOp {
        return DataOp{ .UNION_HEADER = UnionHeader{ .num_fields = num_fields } };
    }

    pub fn new_union_tag_id_op(comptime tag_as_u64_native_endian: u64, comptime num_following_commands: u32) DataOp {
        switch (num_following_commands) {
            1 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_ONE_FOLLOWING } },
            2 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_TWO_FOLLOWING } },
            3 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_THREE_FOLLOWING } },
            4 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_FOUR_FOLLOWING } },
            5 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_FIVE_FOLLOWING } },
            6 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_SIX_FOLLOWING } },
            else => assert_unreachable(@src(), "only union tags with 1-6 following commands are supported, got `{d}`", .{num_following_commands}),
        }
    }

    pub fn new_union_tag_range_op(comptime tag_min_as_u64_native_endian: u64, comptime tag_max_as_u64_native_endian: u64, comptime num_following_commands: u32) DataOp {
        var range = UnionTagRange{
            .max_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_max_as_u64_native_endian) else tag_max_as_u64_native_endian,
        };
        range.set_min_native_endian(tag_min_as_u64_native_endian);
        switch (num_following_commands) {
            1 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_ONE_FOLLOWING },
            2 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_TWO_FOLLOWING },
            3 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_THREE_FOLLOWING },
            4 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_FOUR_FOLLOWING },
            5 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_FIVE_FOLLOWING },
            6 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_SIX_FOLLOWING },
            else => assert_unreachable(@src(), "only union tag ranges with 1-6 following commands are supported, got `{d}`", .{num_following_commands}),
        }
    }

    pub fn new_subroutine_op(comptime subroutine_first_op: u32, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION, .START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION => {},
            else => assert_unreachable(@src(), "cannot create a `SubroutineStart` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .SUBROUTINE = SubroutineStart{ .subroutine_first_op = subroutine_first_op, .subroutine_num_ops = subroutine_num_ops, .subroutine_static_repeat = subroutine_static_repeat, .offset_to_next_field = offset_to_next_field, .kind = kind } };
    }

    pub fn new_ref_unique_struct_and_settings_op(comptime unique_type_index: u32, comptime offset_to_next_field: i32) DataOp {
        return DataOp{ .REF_UNIQUE_TYPE_SUBRS = RefUniqueTypeSubroutine{ .unique_type_index = unique_type_index, .offset_to_next_field = offset_to_next_field } };
    }

    pub fn new_allocated_pointer_op(comptime elem_size: u32, comptime elem_align: u32, comptime alloc_idx: u16, comptime static_len: u32, comptime offset_to_next_field: i32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .ALLOCATED_POINTER_STATIC_LEN, .ALLOCATED_POINTER_DYNAMIC_LEN => {},
            else => assert_unreachable(@src(), "cannot create a `AllocatedPointer` op with kind `{s}`", .{@tagName(kind)}),
        }
        const ptr_align_power = PowerOf2.alignment_power(elem_align);
        return DataOp{ .POINTER = Pointer{ .elem_size = elem_size, .ptr_align_power = ptr_align_power, .alloc_idx = alloc_idx, .static_len = static_len, .offset_to_next_field = offset_to_next_field, .kind = kind } };
    }

    pub fn new_pointer_sentinel_op(comptime elem_size: u32, comptime sentinel_data: *const anyopaque) DataOp {
        return DataOp{ .SENTINEL = Sentinel{ .elem_size = elem_size, .sentinel_data = sentinel_data } };
    }

    // pub fn new_previous_allocation_ref_op(comptime elem_size: u32, comptime static_len: u32, comptime offset_to_next_field: i32, comptime kind: DataOpKind) DataOp {
    //     switch (kind) {
    //         .POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN, .POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN => {},
    //         else => assert_unreachable(@src(), "cannot create a `PreviousAllocationReference` op with kind `{s}`", .{@tagName(kind)}),
    //     }
    //     return DataOp{ .Pointer = Pointer{ .elem_size = elem_size, .static_len = static_len, .offset_to_next_field = offset_to_next_field, .kind = kind } };
    // }

    pub fn new_custom_functions_op(comptime funcs: *const CustomRuntimeSerializeFuncs, comptime offset_to_next_field: i32) DataOp {
        return DataOp{ .FULL_CUSTOM_FUNCTION = CustomFunctions{ .funcs = funcs, .offset_to_next_field = offset_to_next_field } };
    }

    pub fn new_data_manip_native_to_serial_op(comptime func: *const DataManipulationNativeToSerial) DataOp {
        return DataOp{ .DATA_MANIP_NATIVE_TO_SERIAL = DataManipNativeToSerial{ .func = func } };
    }

    pub fn new_data_manip_serial_to_native_op(comptime func: *const DataManipulationSerialToNative) DataOp {
        return DataOp{ .DATA_MANIP_SERIAL_TO_NATIVE = DataManipSerialToNative{ .func = func } };
    }
};

const DataOpGeneric = extern struct {
    __padding: [15]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind,
};

const AddNativeOffset = extern struct {
    offset: i32 = 0,
    __padding: [11]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .ADD_NATIVE_OFFSET,
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
    kind: DataOpKind = .UNION_TAG_ID_ONE_FOLLOWING,

    pub fn tag_matches(self: UnionTagId, value_as_u64_in_native_endian: u64) bool {
        if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
            return self.tag_as_u64_le == @byteSwap(value_as_u64_in_native_endian);
        } else {
            return self.tag_as_u64_le == value_as_u64_in_native_endian;
        }
    }
};

const UnionTagRange = extern struct {
    /// The union tag max value (inclusive) first bitcast to a u64,
    /// then swapped to little-endian order, if needed
    max_as_u64_le: u64 = 0,
    /// The 4 least significant bytes of the min tag value
    /// in little-endian order
    min_as_u64_native_endian_bytes_0_4: u32 = 0,
    /// The next 2 least significant bytes of the min tag value
    /// (after `min_as_u64_le_bytes_0_4`) in little-endian order
    min_as_u64_native_endian_bytes_4_6: u16 = 0,
    /// the most significant byte of the min tag value
    min_as_u64_native_endian_byte_6: u8 = 0,
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .UNION_TAG_RANGE_ONE_FOLLOWING,

    pub fn tag_matches(self: UnionTagRange, value_as_u64_in_native_endian: u64) bool {
        const min_le = self.get_min_le();
        if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
            const val_swapped = @byteSwap(value_as_u64_in_native_endian);
            return min_le <= val_swapped and val_swapped <= self.max_as_u64_le;
        } else {
            return min_le <= value_as_u64_in_native_endian and value_as_u64_in_native_endian <= self.max_as_u64_le;
        }
    }

    pub fn get_min_le(self: UnionTagRange) u64 {
        const val: u64 = num_cast(self.min_as_u64_native_endian_bytes_0_4, u64);
        val |= num_cast(self.min_as_u64_native_endian_bytes_4_6, u64) << 32;
        val |= num_cast(self.min_as_u64_native_endian_byte_6, u64) << 48;
        if (NATIVE_ENDIAN != .LITTLE_ENDIAN) {
            val = @byteSwap(val);
        }
        return val;
    }

    pub fn set_min_native_endian(self: *UnionTagRange, val_in_native_endian: u64) void {
        assert_with_reason(val_in_native_endian < (1 << 54), @src(), "min value too large ({d}). Unfortunately, due to sizing constraints on the SerialManager DataOp type (each DataOp is exactly 16 bytes, and one byte MUST be reserved for the DataOpKind), the minimum tag value of a UnionTagRange MUST be less than {d}. If your use case doesn't work with this constraint, you must use some other serialization technique (possibly custom runtime serial funcs)", .{ val_in_native_endian, 1 << 54 });
        const bytes_0_4: u32 = num_cast(val_in_native_endian & 0x00_0000_FFFFFFFF, u32);
        const bytes_4_6: u16 = num_cast((val_in_native_endian & 0x00_FFFF_00000000) >> 32, u16);
        const byte_6: u16 = num_cast((val_in_native_endian & 0xFF_0000_00000000) >> 48, u8);
        self.min_as_u64_native_endian_bytes_0_4 = bytes_0_4;
        self.min_as_u64_native_endian_bytes_4_6 = bytes_4_6;
        self.min_as_u64_native_endian_byte_6 = byte_6;
    }
};

const RefUniqueTypeSubroutine = extern struct {
    unique_type_index: u32 = 0,
    offset_to_next_field: i32 = 0,
    // subroutine_static_repeat: u32 = 1,
    // intended_kind: DataOpKind = .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION,
    __padding: [7]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .REF_UNIQUE_TYPE,
    //CHECKPOINT make this match `Subroutine` kinds, at comptime must convert this into a subroutine data op,

    // fn to_subroutine_start(comptime self: RefUniqueTypeSubroutine, comptime fully_complete_uniques_list: []const UniqueSerialType) DataOp {
    //     const unique = fully_complete_uniques_list[self.unique_type_index];
    //     return DataOp.new_subroutine_op(unique.routine_start, unique.routine_end - unique.routine_start, self.subroutine_static_repeat, self.intended_kind);
    // }
};

const SubroutineStart = extern struct {
    subroutine_first_op: u32 = 0,
    subroutine_static_repeat: u32 = 1,
    offset_to_next_field: i32 = 0,
    subroutine_num_ops: u16 = 0,
    __padding: [1]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION,
};

const Pointer = extern struct {
    elem_size: u32 = 1,
    static_len: u32 = 1,
    offset_to_next_field: i32 = 0,
    alloc_idx: u16 = 0,
    ptr_align_power: PowerOf2 = ._1,
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .ALLOCATED_POINTER_STATIC_LEN,
};

const Sentinel = extern struct {
    sentinel_data: *const anyopaque,
    elem_size: u32 = 1,
    __padding: [11 - @sizeOf(usize)]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .POINTER_SENTINEL,
};

const CustomFunctions = extern struct {
    /// A pair of serialize and deserialize functions
    /// that are called in place on DataOp bytecode. When
    /// an object defines these, it must handle ANY AND ALL serialization
    /// of all children as well.
    funcs: *const CustomRuntimeSerializeFuncs = undefined,
    offset_to_next_field: i32 = 0,
    neg_offset_to_object_addr_lo: u16 = 0,
    neg_offset_to_object_addr_hi: u8 = 0,
    __padding: [8 - @sizeOf(usize)]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .FULL_CUSTOM_FUNCTION,

    pub fn get_neg_offset_to_object_addr(self: CustomFunctions) u32 {
        return num_cast(self.neg_offset_to_object_addr_lo, u32) | (num_cast(self.neg_offset_to_object_addr_hi, u32) << 16);
    }

    pub fn set_neg_offset_to_object_addr(self: *CustomFunctions, neg_offset: u32) void {
        const lo = num_cast(neg_offset, u16);
        const hi = num_cast(neg_offset >> 16, u8);
        self.neg_offset_to_object_addr_lo = lo;
        self.neg_offset_to_object_addr_hi = hi;
    }
};

const DataManipNativeToSerial = extern struct {
    /// This is a custom user-provided function that can be injected into the
    /// middle of the serialization process to alter the native data BEFORE it is serialized.
    ///
    /// This function should only manipulate fields/values that have NOT YET
    /// been serialized, as it will have no effect on the ones that already have
    func: *const DataManipulationNativeToSerial = undefined,
    offset_to_object_addr: i32 = 0,
    __padding: [11 - @sizeOf(usize)]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .DATA_MANIPULATION_NATIVE_TO_SERIAL,
};

const DataManipSerialToNative = extern struct {
    /// This is a custom user-provided function that can be injected into the middle of the
    /// de-serialization process to alter the native data AFTER it has been de-serialized.
    ///
    /// This function should only manipulate fields/values that have ALREADY been de-serialized,
    /// as it will have no effect on the ones that have not yet been (they will be overwritten)
    func: *const DataManipulationSerialToNative = undefined,
    offset_to_object_addr: i32 = 0,
    __padding: [11 - @sizeOf(usize)]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .DATA_MANIPULATION_SERIAL_TO_NATIVE,
};

const UniqueSerialStructAndSettingsBuild = struct {
    object_type: type,
    object_settings: ObjectSerialSettings,
    routine_start: u32 = 0,
    routine_end: u32 = 0,
    routine_made: bool = false,

    pub fn equals(comptime a: UniqueSerialStructAndSettingsBuild, b: UniqueSerialStructAndSettingsBuild) bool {
        return a.object_type == b.object_type and a.object_settings.equals(b.object_settings);
    }

    pub fn to_final(comptime self: UniqueSerialStructAndSettingsBuild) UniqueSerialStructAndSettingsFinal {
        assert_with_reason(self.routine_made, @src(), "routine for type `{s}`, settings `{any}` was never made (or never recorded as being made), cannot finalize", .{ @typeName(self.object_type), self.object_settings });
        return UniqueSerialStructAndSettingsFinal{
            .object_type = self.object_type,
            .routine_start = self.routine_start,
            .routine_end = self.routine_end,
        };
    }
};

const UniqueSerialStructAndSettingsFinal = struct {
    object_type: type,
    routine_start: u32 = 0,
    routine_end: u32 = 0,
};

pub const DataTransferTech = enum(u8) {
    NON_ZERO_READ_OR_WRITE_1_ELSE_0,
    TARGET_ENDIAN_SAME_SIZE,
    // ENDIAN_TRUNCATE_LARGER,
    VARINT_ZIGZAG,
    VARINT,
};

pub const DataCacheMode = enum(u8) {
    DONT_CACHE_DATA,
    CACHE_TAG,
    CACHE_LEN,
    CACHE_NULL,
};

pub const SubroutineRepeatMode = enum(u8) {
    STATIC_REPEAT_OR_NO_REPEAT,
    DYNAMIC_REPEAT,
};

pub const SubroutineAllocRegionMode = enum(u8) {
    SAME_MEMORY_REGION,
    SUB_ALLOCATED_REGION,
};

pub const PointerLenMode = enum(u8) {
    STATIC_LEN_POINTER,
    DYNAMIC_LEN_POINTER,
    STATIC_LEN_POINTER_OR_NULL,
    DYNAMIC_LEN_POINTER_OR_NULL,
    STATIC_LEN_POINTER_WITH_SENTINEL,
    DYNAMIC_LEN_POINTER_WITH_SENTINEL,
    STATIC_LEN_POINTER_WITH_SENTINEL_OR_NULL,
    DYNAMIC_LEN_POINTER_WITH_SENTINEL_OR_NULL,
};

// pub const InterpretAnyPointerAsSingle = enum(u8) {
//     ALLOW_ANY_NON_SLICE_TO_BE
// };

pub const TypeOpPatternKind = enum(u8) {
    MOVE_TO_NEXT,
    OPTIONAL,
    POINTER,
    POINTER_SUBROUTINE,
    ARRAY,
    FLAT_ARRAY,
    NUMERIC,
    ADD_SENTINEL,
    STRUCT,
};

pub const CompleteTypeSerialInfo = struct {
    TYPE: type = void,
    PTR_CHILD_TYPE: type = void,
    ARR_ELEM_TYPE: type = void,
    RAW_FINAL_TYPE: type = void,
    STRUCT_UNIQUE_IDX: u32 = 0,
    RAW_FINAL_TYPE_SER_SIZE: u32 = 0,
    REAL_DATA_SIZE: u32 = 0,
    REAL_DATA_SER_SIZE: u32 = 0,
    REAL_DATA_SIZE_WITH_SENTINEL: u32 = 0,
    OFFSET_TO_NEXT_FIELD: i32 = 0,
    SETTINGS_BEFORE_OVERRIDE: ObjectSerialSettings = .{},
    SETTINGS_AFTER_OVERRIDE: ObjectSerialSettings = .{},
    NUM_OPS_REQUIRED_TO_SERIALIZE: u32 = 0,
    PTR_SUBROUTINE_LEN: u16 = 0,
    OP_PATTERN: [6]TypeOpPatternKind = @splat(TypeOpPatternKind.MOVE_TO_NEXT),
    OP_PATTERN_OFFSETS_TO_NEXT: [6]i32 = @splat(0),
    TARGET_ENDIAN: Endian = .LITTLE_ENDIAN,
    USIZE_COMPAT: UsizeCompatMode = .USIZE_ALWAYS_VARINT,
    USIZE_SER_SIZE: u32 = 0,
    CACHE_MODE: DataCacheMode = .DONT_CACHE_DATA,
    TECH: DataTransferTech = .TARGET_ENDIAN_SAME_SIZE,
    USIZE_TECH: DataTransferTech = .VARINT,
    TOTAL_ARR_LEN: u32 = 1,
    PTR_ALIGN: comptime_int = 1,
    ALLOC_IDX: u16 = 0xFFFF,
    PTR_IS_NULLABLE: bool = false,
    PTR_LEN_MODE: PointerLenMode = .STATIC_LEN_POINTER,
    IS_POINTER: bool = false,
    DATA_IS_ARRAY: bool = false,
    PTR_SENTINEL: ?*const anyopaque = null,
    HAS_SENTINEL: bool = false,
    ARRAY_CAN_BE_BULK_COPIED: bool = false,
    POINTER_KIND: std.builtin.Type.Pointer.Size = .slice,
    IS_NUMERIC_PATTERN: bool = false,
    IS_STRUCT_PATTERN: bool = false,
    IS_VALID: bool = false,
    NEEDS_CACHED_LEN: bool = false,
};

pub const PointerLen = enum(u8) {
    SINGLE_ITEM,
    MANY_ITEM,
};

pub const SerialSettingsOverride = struct {
    TARGET_ENDIAN: ?Endian = null,
    INTEGER_PACKING: ?IntegerPacking = null,
    USIZE_COMPATABILITY: ?UsizeCompatMode = null,
    POINTER_MODE: ?PointerMode = null,
    POINTER_LEN_MODE: ?PointerLen = null,
    CACHE: ?DataCacheMode = null,
};

/// The 'lowest' level of DataOpBuilder. This holds all the core
/// data fields of a DataOpBuilder, and all the methods not intended to be used
/// by a library consumer.
pub const DataOpBuilderInternal = struct {
    object_type: type = void,
    object_settings: ObjectSerialSettings = .{},
    // object_name_hash: []const u8 = "",
    ops_used_tracker: *[DataOpKind.NUM_OP_KINDS]bool = undefined,
    unique: []UniqueSerialStructAndSettingsBuild = &.{},
    unique_len: u32 = 0,
    ops: []DataOp = &.{},
    ops_len: u32 = 0,
    alloc_buf: []u8 = &.{},
    alloc_buf_len: u32 = 0,
    alloc_names: []SliceRange = &.{},
    alloc_names_len: u32 = 0,
    prev_field: ?[]const u8 = null,
    next_field: ?[]const u8 = null,
    cached_tag_field: ?[]const u8 = null,
    cached_tag_type: type = void,
    cached_len_field: ?[]const u8 = null,
    cached_null_field: ?[]const u8 = null,

    pub fn build_all_type_routines_starting_from_these_root_types(comptime self: *DataOpBuilderInternal, comptime TYPES_FOR_SERIALIZATION: []const type, comptime DEFAULT_SETTINGS: ObjectSerialSettings) void {
        for (TYPES_FOR_SERIALIZATION) |TYPE_TO_SERIALIZE| {
            const OBJECT_SETTINGS = get_object_settings(TYPE_TO_SERIALIZE);
            const SETTINGS = DEFAULT_SETTINGS.with_custom_routine_removed().combined_with_optional(OBJECT_SETTINGS);
            _ = self.locate_or_create_unique_type_idx(TYPE_TO_SERIALIZE, SETTINGS);
        }
        comptime var u: u32 = 0;
        while (u < self.unique_len) : (u += 1) {
            const UNIQUE: *UniqueSerialStructAndSettingsBuild = &self.unique[u];
            self.build_routine_for_unique_type(UNIQUE);
        }
    }

    pub fn build_routine_for_unique_type(comptime self: *DataOpBuilderInternal, comptime UNIQUE: *UniqueSerialStructAndSettingsBuild) void {
        if (!UNIQUE.routine_made) {
            const builder: *DataOpBuilderHighLevel = @ptrCast(self);
            self.object_type = UNIQUE.object_type;
            self.object_settings = UNIQUE.object_settings;
            // self.object_name_hash = Utils.type_hash32_as_hex_string(self.object_type);
            self.prev_field = null;
            self.next_field = null;
            self.cached_len_field = null;
            self.cached_null_field = null;
            self.cached_tag_field = null;
            self.cached_tag_type = void;
            const KIND_INFO = KindInfo.get_kind_info(self.object_type);
            const _STRUCT: ?std.builtin.Type.Struct = if (KIND_INFO == .STRUCT) KIND_INFO.STRUCT else null;
            const routine_start = self.ops_len;
            switch (self.object_settings.CUSTOM_ROUTINE) {
                .CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE => |routine| {
                    self.object_settings = self.object_settings.with_custom_routine_removed();
                    routine(self.object_settings.with_custom_routine_removed(), @ptrCast(self));
                },
                .CUSTOM_RUNTIME_SERIALIZE => |funcs| {
                    self.object_settings = self.object_settings.with_custom_routine_removed();
                    builder.low_level.add_custom_functions_op(funcs, 0);
                },
                .NO_CUSTOM_ROUTINE => {
                    if (_STRUCT) |STRUCT| {
                        inline for (STRUCT.fields, 0..) |field, f| {
                            const next_field: WithNextField = if (f + 1 == STRUCT.fields.len) WithNextField.this_is_last_field() else WithNextField.next_field_is(STRUCT.fields[f + 1].name);
                            builder.add_field(field.name, next_field, .no_len_needed(), .{});
                        }
                    } else {
                        assert_unreachable(@src(), "only Struct types are allowed to have a routine built unconditionaly.\nEnums, Unions, Opaques, and ErrorSets are allowed *ONLY IF A CUSTOM ROUTINE BUILDER OR PAIR OF RUNTIME SERIALIZATION FUNCTIONS ARE PROVIDED BY THEM* (by using a pub const declaration on the type with the name `{s}`)\nGot kind `{s}` without custom serialization procedure, real type `{s}`", .{ @tagName(Kind.get_kind(self.object_type)), @typeName(self.object_type) });
                    }
                },
            }
            const routine_end = self.ops_len;
            UNIQUE.routine_made = true;
            UNIQUE.routine_start = routine_start;
            UNIQUE.routine_end = routine_end;
        }
    }

    pub fn push_op(comptime self: *DataOpBuilderInternal, comptime op: DataOp) void {
        assert_with_reason(self.ops_len < self.ops.len, @src(), "ran out of space in ops buffer, need at least len {d}, have len {d}, provide a larger `OP_BUFFER_MAX_LEN` during SerialManager initialization", .{ self.ops_len + 1, self.ops.len });
        const KIND = op.GENERIC.kind;
        self.ops_used_tracker[@intFromEnum(KIND)] = true;
        self.ops[self.ops_len] = op;
        self.ops_len += 1;
    }

    pub fn locate_or_create_unique_type_idx(comptime self: *DataOpBuilderInternal, comptime TYPE: type, comptime SETTINGS: ObjectSerialSettings) u32 {
        const potential_new_unique = UniqueSerialStructAndSettingsBuild{
            .object_type = TYPE,
            .object_settings = SETTINGS,
        };
        for (self.unique, 0..) |unique_type, i| {
            if (potential_new_unique.equals(unique_type)) return num_cast(i, u32);
        }
        assert_with_reason(self.unique_len < self.unique.len, @src(), "ran out of space in unique type list, need at least {d} slots, have {d} slots, provide a larger `UNIQUE_TYPE_BUFFER_MAX_LEN` at SerializationManager initialization", .{ self.unique_len + 1, self.unique.len });
        self.unique[self.unique_len] = potential_new_unique;
        const idx = self.unique_len;
        self.unique_len += 1;
        return idx;
    }

    pub fn assert_cached_len_match(comptime self: *const DataOpBuilderInternal, comptime EXPECTED_CACHED_LEN: []const u8, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self.cached_len_field != null and std.mem.eql(u8, EXPECTED_CACHED_LEN, self.cached_len_field.?), src, "expected cached len field `{s}` did not match the recorded cached len field `{s}`, logic error likely", .{ EXPECTED_CACHED_LEN, if (self.cached_len_field) |cached| cached else NO_LEN_CACHE });
    }

    pub fn assert_cached_tag_match(comptime self: *const DataOpBuilderInternal, comptime EXPECTED_CACHED_TAG: []const u8, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self.cached_tag_field != null and std.mem.eql(u8, EXPECTED_CACHED_TAG, self.cached_tag_field.?), src, "expected cached tag field `{s}` did not match the recorded cached tag field `{s}`, logic error likely", .{ EXPECTED_CACHED_TAG, if (self.cached_tag_field) |cached| cached else NO_LEN_CACHE });
    }

    pub fn assert_cached_tag_and_type_match(comptime self: *const DataOpBuilderInternal, comptime EXPECTED_CACHED_TAG: []const u8, comptime EXPECTED_TAG_TYPE: type, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self.cached_tag_field != null and std.mem.eql(u8, EXPECTED_CACHED_TAG, self.cached_tag_field.?), src, "expected cached tag field `{s}` did not match the recorded cached tag field `{s}`, logic error likely", .{ EXPECTED_CACHED_TAG, if (self.cached_tag_field) |cached| cached else NO_LEN_CACHE });
        assert_with_reason(self.cached_tag_type == EXPECTED_TAG_TYPE, src, "expected cached tag type `{s}` did not match the recorded cached tag type `{s}`, logic error likely", .{ @typeName(EXPECTED_TAG_TYPE), @typeName(self.cached_tag_type) });
    }

    pub fn assert_cached_null_match(comptime self: *const DataOpBuilderInternal, comptime EXPECTED_CACHED_NULL: []const u8, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self.cached_null_field != null and std.mem.eql(u8, EXPECTED_CACHED_NULL, self.cached_null_field.?), src, "expected cached null field `{s}` did not match the recorded cached null field `{s}`, logic error likely", .{ EXPECTED_CACHED_NULL, if (self.cached_null_field) |cached| cached else NO_NULL_CACHE });
    }

    pub fn handle_cached_values(comptime self: *DataOpBuilderInternal, comptime FIELD: []const u8, comptime COMPLETE_INFO: CompleteTypeSerialInfo) void {
        if (COMPLETE_INFO.PTR_IS_NULLABLE) {
            self.cached_null_field = FIELD;
        }
        switch (COMPLETE_INFO.CACHE_MODE) {
            .DONT_CACHE_DATA => {},
            .CACHE_LEN => {
                self.cached_len_field = FIELD;
            },
            .CACHE_TAG => {
                self.cached_tag_field = FIELD;
                self.cached_tag_type = COMPLETE_INFO.ARR_ELEM_TYPE;
            },
            .CACHE_NULL => {
                self.cached_null_field = FIELD;
            },
        }
    }
};

/// A 'low-level' DataOpBuilder. You can add specific ops in any custom order,
/// and it is up to the library consumer to ensure it is correct.
pub const DataOpBuilderLowLevel = struct {
    /// The 'lowest' level of DataOpBuilder. This holds all the core
    /// data fields of a DataOpBuilder, and all the methods not *intended* to be used
    /// by a library consumer, though they are still available if needed.
    internal: DataOpBuilderInternal,

    pub fn add_move_native_offset_op(comptime self: *DataOpBuilderLowLevel, comptime offset: i32) void {
        const op = DataOp.new_add_native_offset_op(offset);
        self.internal.push_op(self, op);
    }

    pub fn add_transfer_data_op(comptime self: *DataOpBuilderLowLevel, comptime native_size: u32, comptime offset_to_next_field: i32, comptime serial_size: u32, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech, comptime CACHE: DataCacheMode) void {
        comptime var kind: DataOpKind = if (TECH == .NON_ZERO_READ_OR_WRITE_1_ELSE_0) DataOpKind.NON_ZERO_READ_OR_WRITE_1_ELSE_0 else if (native_size == 1) DataOpKind.TRANSFER_SAME_ENDIAN else switch (TECH) {
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
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => DataOpKind.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_LEN,
                else => unreachable,
            },
            .CACHE_TAG => switch (kind) {
                .TRANSFER_SAME_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN_SAVE_TAG,
                .TRANSFER_SWAP_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN_SAVE_TAG,
                .TRANSFER_VARINT => DataOpKind.TRANSFER_VARINT_SAVE_TAG,
                .TRANSFER_VARINT_ZIGZAG => DataOpKind.TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => DataOpKind.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG,
                else => unreachable,
            },
            .CACHE_NULL => switch (kind) {
                .TRANSFER_SAME_ENDIAN => DataOpKind.TRANSFER_SAME_ENDIAN_SAVE_TAG,
                .TRANSFER_SWAP_ENDIAN => DataOpKind.TRANSFER_SWAP_ENDIAN_SAVE_TAG,
                .TRANSFER_VARINT => DataOpKind.TRANSFER_VARINT_SAVE_TAG,
                .TRANSFER_VARINT_ZIGZAG => DataOpKind.TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => DataOpKind.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG,
                else => unreachable,
            },
        };
        const op = DataOp.new_transfer_data_op(native_size, offset_to_next_field, serial_size, kind);
        self.internal.push_op(self, op);
    }

    pub fn add_union_header_op(comptime self: *DataOpBuilderLowLevel, comptime num_fields: u32) void {
        const op = DataOp.new_union_header_op(num_fields);
        self.internal.push_op(self, op);
    }

    pub fn add_union_tag_op(comptime self: *DataOpBuilderLowLevel, comptime tag_as_u64_native_endian: u64, comptime num_following_ops: u32) void {
        const op = DataOp.new_union_tag_id_op(tag_as_u64_native_endian, num_following_ops);
        self.internal.push_op(self, op);
    }

    pub fn add_union_range_op(comptime self: *DataOpBuilderLowLevel, comptime min_as_u64_native_endian: u64, comptime max_as_u64_native_endian: u64, comptime num_following_ops: u32) void {
        const op = DataOp.new_union_tag_range_op(min_as_u64_native_endian, max_as_u64_native_endian, num_following_ops);
        self.internal.push_op(self, op);
    }

    pub fn add_subroutine_start_op(comptime self: *DataOpBuilderLowLevel, comptime subroutine_first_op: u32, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime REPEAT: SubroutineRepeatMode, comptime REGION: SubroutineAllocRegionMode) void {
        const kind: DataOpKind = switch (REGION) {
            .SAME_MEMORY_REGION => switch (REPEAT) {
                .DYNAMIC_REPEAT => DataOpKind.START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION,
                .STATIC_REPEAT_OR_NO_REPEAT => if (subroutine_static_repeat <= 1) DataOpKind.START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION else DataOpKind.START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION,
            },
            .SUB_ALLOCATED_REGION => switch (REPEAT) {
                .DYNAMIC_REPEAT => DataOpKind.START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION,
                .STATIC_REPEAT_OR_NO_REPEAT => if (subroutine_static_repeat <= 1) DataOpKind.START_SUBROUTINE_NO_REPEAT_CURRENT_REGION else DataOpKind.START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION,
            },
        };
        const op = DataOp.new_subroutine_op(subroutine_first_op, subroutine_num_ops, subroutine_static_repeat, offset_to_next_field, kind);
        self.internal.push_op(self, op);
    }

    pub fn add_inline_subroutine_start_op(comptime self: *DataOpBuilderLowLevel, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime REPEAT: SubroutineRepeatMode, comptime REGION: SubroutineAllocRegionMode) void {
        const kind: DataOpKind = switch (REGION) {
            .SAME_MEMORY_REGION => switch (REPEAT) {
                .DYNAMIC_REPEAT => DataOpKind.START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION,
                .STATIC_REPEAT_OR_NO_REPEAT => if (subroutine_static_repeat <= 1) DataOpKind.START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION else DataOpKind.START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION,
            },
            .SUB_ALLOCATED_REGION => switch (REPEAT) {
                .DYNAMIC_REPEAT => DataOpKind.START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION,
                .STATIC_REPEAT_OR_NO_REPEAT => if (subroutine_static_repeat <= 1) DataOpKind.START_SUBROUTINE_NO_REPEAT_CURRENT_REGION else DataOpKind.START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION,
            },
        };
        const subroutine_first_op = self.ops_offset + self.ops_len + 1;
        const op = DataOp.new_subroutine_op(subroutine_first_op, subroutine_num_ops, subroutine_static_repeat, offset_to_next_field, kind);
        self.internal.push_op(self, op);
    }

    pub fn add_ref_unique_type_op(comptime self: *DataOpBuilderLowLevel, comptime unique_type_idx: u32, comptime offset_to_next_field: i32) void {
        const op = DataOp.new_ref_unique_struct_and_settings_op(unique_type_idx, offset_to_next_field);
        self.internal.push_op(self, op);
    }

    pub fn add_allocated_pointer_op(comptime self: *DataOpBuilderLowLevel, comptime elem_size: u32, comptime ptr_align: u32, alloc_idx: u16, comptime static_len: u32, comptime offset_to_next_field: i32, comptime LEN_MODE: PointerLenMode) void {
        const kind: DataOpKind = switch (LEN_MODE) {
            .STATIC_LEN_POINTER => DataOpKind.ALLOCATED_POINTER_STATIC_LEN,
            .STATIC_LEN_POINTER_OR_NULL => DataOpKind.ALLOCATED_POINTER_STATIC_LEN_OR_NULL,
            .STATIC_LEN_POINTER_WITH_SENTINEL => DataOpKind.ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL,
            .STATIC_LEN_POINTER_WITH_SENTINEL_OR_NULL => DataOpKind.ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL_OR_NULL,
            .DYNAMIC_LEN_POINTER => DataOpKind.ALLOCATED_POINTER_DYNAMIC_LEN,
            .DYNAMIC_LEN_POINTER_OR_NULL => DataOpKind.ALLOCATED_POINTER_DYNAMIC_LEN_OR_NULL,
            .DYNAMIC_LEN_POINTER_WITH_SENTINEL => DataOpKind.ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL,
            .DYNAMIC_LEN_POINTER_WITH_SENTINEL_OR_NULL => DataOpKind.ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL_OR_NULL,
        };
        const op = DataOp.new_allocated_pointer_op(elem_size, ptr_align, alloc_idx, static_len, offset_to_next_field, kind);
        self.internal.push_op(self, op);
    }

    pub fn add_pointer_sentinel_op(comptime self: *DataOpBuilderLowLevel, comptime elem_size: u32, comptime sentinel_data: *const anyopaque) void {
        const op = DataOp.new_pointer_sentinel_op(elem_size, sentinel_data);
        self.internal.push_op(self, op);
    }

    pub fn add_prev_allocation_ref_pointer_op(comptime self: *DataOpBuilderLowLevel, comptime elem_size: u32, comptime ptr_align: u32, alloc_idx: u16, comptime static_len: u32, comptime offset_to_next_field: i32, comptime LEN_MODE: PointerLenMode) void {
        const kind: DataOpKind = switch (LEN_MODE) {
            .STATIC_LEN_POINTER => DataOpKind.POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN,
            .DYNAMIC_LEN_POINTER => DataOpKind.POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN,
        };
        const op = DataOp.new_previous_allocation_ref_op(elem_size, ptr_align, alloc_idx, static_len, offset_to_next_field, kind);
        self.internal.push_op(self, op);
    }

    pub fn add_custom_functions_op(comptime self: *DataOpBuilderLowLevel, comptime funcs: *const CustomRuntimeSerializeFuncs, comptime offset_to_next_field: i32) void {
        const op = DataOp.new_custom_functions_op(funcs, offset_to_next_field);
        self.internal.push_op(self, op);
    }

    pub fn add_data_manip_serial_to_native_op(comptime self: *DataOpBuilderLowLevel, comptime func: *const DataManipulationSerialToNative) void {
        const op = DataOp.new_data_manip_serial_to_native_op(func);
        self.internal.push_op(self, op);
    }

    pub fn add_data_manip_native_to_serial_op(comptime self: *DataOpBuilderLowLevel, comptime func: *const DataManipulationNativeToSerial) void {
        const op = DataOp.new_data_manip_native_to_serial_op(func);
        self.internal.push_op(self, op);
    }

    // UTILS

    pub fn get_offset_between_two_fields_on_current_type(comptime self: *DataOpBuilderLowLevel, comptime START_FIELD: ?[]const u8, comptime END_FIELD: ?[]const u8) i32 {
        const TYPE = self.internal.object_type;
        const start_offset: u32 = if (START_FIELD) |SF| get: {
            assert_with_reason(@hasField(TYPE, SF), @src(), "current type `{s}` does not have field `{s}`", .{ @typeName(TYPE), SF });
            break :get @offsetOf(TYPE, SF);
        } else 0;
        const end_offset: u32 = if (END_FIELD) |EF| get: {
            assert_with_reason(@hasField(TYPE, EF), @src(), "current type `{s}` does not have field `{s}`", .{ @typeName(TYPE), EF });
            break :get @offsetOf(TYPE, EF);
        } else 0;
        if (start_offset > end_offset) {
            return -num_cast(start_offset - end_offset, i32);
        } else {
            return num_cast(end_offset - start_offset, i32);
        }
    }

    pub fn get_tech_for_numeric_type(comptime SETTINGS: ObjectSerialSettings, comptime TYPE: type) DataTransferTech {
        const KIND_INFO = KindInfo.get_kind_info(TYPE);
        const TECH = if (@sizeOf(TYPE) <= 1) (if (TYPE == bool) DataTransferTech.NON_ZERO_READ_OR_WRITE_1_ELSE_0 else DataTransferTech.TARGET_ENDIAN_SAME_SIZE) else switch (KIND_INFO) {
            .INT, .ENUM, .STRUCT, .UNION => switch (SETTINGS.INTEGER_PACKING) {
                .USE_TARGET_ENDIAN => DataTransferTech.TARGET_ENDIAN_SAME_SIZE,
                .USE_VARINTS => switch (KIND_INFO) {
                    .INT => |INT| if (INT.signedness == .signed) DataTransferTech.VARINT_ZIGZAG else DataTransferTech.VARINT,
                    .ENUM => |ENUM| get_base: {
                        const INT = KindInfo.get_kind_info(ENUM.tag_type).INT;
                        break :get_base if (INT.signedness == .signed) DataTransferTech.VARINT_ZIGZAG else DataTransferTech.VARINT;
                    },
                    .STRUCT, .UNION => DataTransferTech.VARINT,
                    else => unreachable,
                },
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => DataTransferTech.NON_ZERO_READ_OR_WRITE_1_ELSE_0,
            },
            .FLOAT => DataTransferTech.TARGET_ENDIAN_SAME_SIZE,
            else => assert_unreachable(@src(), "only Ints, Floats, Bools, Enums, or Packed Structs are allowed as numeric field ops, got type `{s}`", .{@typeName(TYPE)}),
        };
        if (TYPE == usize or TYPE == isize) {
            TECH = if (TECH == .NON_ZERO_READ_OR_WRITE_1_ELSE_0) TECH else if (TYPE == isize and SETTINGS.USIZE_COMPATABILITY == .USIZE_ALWAYS_VARINT) DataTransferTech.VARINT_ZIGZAG else if (TYPE == usize and SETTINGS.USIZE_COMPATABILITY == .USIZE_ALWAYS_VARINT) DataTransferTech.VARINT else TECH;
        }
        return TECH;
    }

    pub fn re_type_numeric_type(comptime IN_TYPE: type) type {
        const INFO = KindInfo.get_kind_info(IN_TYPE);
        switch (INFO) {
            .INT, .FLOAT => {
                return IN_TYPE;
            },
            .BOOL => {
                return u8;
            },
            .ENUM => |ENUM| {
                return ENUM.tag_type;
            },
            .STRUCT => |STRUCT| {
                assert_with_reason(STRUCT.backing_integer != null, @src(), "only packed structs can be re-typed as numeric types, got type `{s}`", .{@typeName(IN_TYPE)});
                return STRUCT.backing_integer.?;
            },
            .UNION => |UNION| {
                assert_with_reason(UNION.layout == .@"extern", @src(), "only packed unions can be re-typed as numeric types, got type `{s}`", .{@typeName(IN_TYPE)});
                const INT = std.meta.Int(.unsigned, @bitSizeOf(IN_TYPE));
                assert_with_reason(@sizeOf(INT) == @sizeOf(IN_TYPE), @src(), "the size of the input union {d} did not match the size of the infered integer used to back it {d}, this packed union is not eligible for direct numeric inference, but may still be used in a packed struct", .{ @sizeOf(IN_TYPE), @sizeOf(INT) });
                return INT;
            },
            else => assert_unreachable(@src(), "only Ints, Floats, Bools, Enums, Packed Structs, or Packed Unions can be re-typed as numeric types, got type `{s}`", .{@typeName(IN_TYPE)}),
        }
    }

    pub fn get_or_add_alloc_name_index(comptime self: *DataOpBuilderLowLevel, comptime alloc_name: []const u8) u16 {
        for (self.alloc_names[0..self.alloc_names_len], 0..) |existing_name_segment, i| {
            const existing_name = self.alloc_buf[existing_name_segment.start..existing_name_segment.end];
            if (std.mem.eql(u8, existing_name, alloc_name)) return num_cast(i, u32);
        }
        const alloc_name_len_u32 = num_cast(alloc_name.len, u32);
        assert_with_reason(self.alloc_buf_len + alloc_name_len_u32 <= self.alloc_buf.len, @src(), "ran out of space for allocator name bytes, have len {d}, need at least len {d}, provide a larger `ALLOC_NAME_BYTES_BUFFER_MAX_LEN` during initialization", .{ self.alloc_buf.len, self.alloc_buf_len + alloc_name_len_u32 });
        assert_with_reason(self.alloc_names_len < self.alloc_names.len, @src(), "ran out of space for allocator name slots, have len {d}, need at least len {d}, provide a larger `ALLOC_NAME_LIST_MAX_LEN` during initialization", .{ self.alloc_names.len, self.alloc_names_len + 1 });
        self.alloc_names[self.alloc_names_len] = SliceRange.new_with_len(self.alloc_buf_len, alloc_name_len_u32);
        const idx: u16 = @intCast(self.alloc_names_len);
        self.alloc_names_len += 1;
        @memcpy(self.alloc_buf[self.alloc_buf_len .. self.alloc_buf_len + alloc_name_len_u32], alloc_name);
        self.alloc_buf_len += alloc_name_len_u32;
        return idx;
    }

    pub fn get_type_settings_and_offset_from_field_and_next_field(comptime self: *DataOpBuilderLowLevel, comptime FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime OVERRIDES: SerialSettingsOverride) struct { type, ObjectSerialSettings, i32 } {
        const OFFSET_TO_NEXT_FIELD = self.get_offset_between_two_fields_on_current_type(FIELD, NEXT_FIELD);
        const TYPE, const SETTINGS = self.get_type_and_final_settings_for_sub_type_or_field_on_current_type(null, FIELD);
        const FINAL_SETTINGS = SETTINGS.combined_with_overrides(OVERRIDES);
        return .{ TYPE, FINAL_SETTINGS, OFFSET_TO_NEXT_FIELD };
    }

    pub fn get_type_and_final_settings_for_sub_type_or_field_on_current_type(comptime self: *DataOpBuilderLowLevel, comptime TYPE: ?type, comptime FIELD: ?[]const u8) struct { type, ObjectSerialSettings } {
        const PARENT_TYPE = self.internal.object_type;
        const KIND = KindInfo.get_kind_info(PARENT_TYPE);
        const CHILD_TYPE = if (TYPE) |T| T else get: {
            assert_with_reason(KIND == .STRUCT and FIELD != null, @src(), "if `TYPE` is not provided, the current (parent) type must be a struct and `FIELD` must not be null, got parent kind `{s}`, field `{s}`", .{ @tagName(KIND), if (FIELD) |F| F else NO_FIELD_CACHE });
            break :get @FieldType(PARENT_TYPE, FIELD.?);
        };
        const FIELD_SETTINGS: ?OptionalObjectSerialSettings = if (FIELD != null) get: {
            assert_with_reason(KIND == .STRUCT, @src(), "if `FIELD` is provided, the current (parent) type must be a stuct, got parent kind `{s}`", .{@tagName(KIND)});
            const F_TYPE = @FieldType(PARENT_TYPE, FIELD.?);
            assert_with_reason(CHILD_TYPE == F_TYPE, @src(), "the type provided does not match the type on field `{s}`, got:\nTYPE = `{s}`\ntype from FIELD = `{s}`", .{ FIELD.?, @typeName(CHILD_TYPE), @typeName(F_TYPE) });
            break :get get_field_settings(PARENT_TYPE, FIELD.?);
        } else null;
        const OBJECT_SETTINGS = get_object_settings(CHILD_TYPE);
        return .{ CHILD_TYPE, self.internal.object_settings.with_custom_routine_removed().combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS) };
    }

    pub fn handle_field_links_and_get_offset_to_next(comptime self: *DataOpBuilderLowLevel, comptime FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8) i32 {
        const TYPE = self.internal.object_type;
        const KIND = KindInfo.get_kind_info(TYPE);
        assert_with_reason(KIND == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(KIND), @typeName(TYPE) });
        assert_with_reason(KIND.STRUCT.backing_integer == null, @src(), "cannot generate standard DataOps for fields of a Packed Struct, because the field offsets may not match the bit offsets. Either serialize the packed struct as its backing integer type (recommended, always works correctly), or use custom runtime serial/deserial functions", .{});
        assert_with_reason(@hasField(TYPE, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(TYPE), FIELD });
        if (NEXT_FIELD) |NEXT| assert_with_reason(@hasField(TYPE, NEXT), @src(), "struct `{s}` does not have NEXT field `{s}`", .{ @typeName(TYPE), NEXT });
        if (self.internal.prev_field != null) assert_with_reason(self.internal.next_field != null and std.mem.eql(u8, self.internal.next_field.?, FIELD), @src(), "the prev field you added indicated the next field to add was `{s}`, but the next field you actually added was `{s}`: routine offsets will be broken", .{ if (self.internal.next_field) |next| next else NO_FIELD_END_STRUCT, FIELD });
        if (self.internal.prev_field == null and @offsetOf(TYPE, FIELD) != 0) {
            self.add_move_native_offset_op(@offsetOf(TYPE, FIELD));
        }
        self.internal.prev_field = FIELD;
        self.internal.next_field = NEXT_FIELD;
        return self.get_offset_between_two_fields_on_current_type(FIELD, NEXT_FIELD);
    }

    /// This method takes ANY of the following type patterns and serializes them in 1-5 ops:
    ///   - `NUMERIC_OR_STRUCT`
    ///   - `[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `*NUMERIC_OR_STRUCT`
    ///   - `?*NUMERIC_OR_STRUCT`
    ///   - `[*]NUMERIC_OR_STRUCT`
    ///   - `?[*]NUMERIC_OR_STRUCT`
    ///   - `*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///
    /// Where `NUMERIC` is one of the following:
    ///   - Integer
    ///   - Enum
    ///   - Bool
    ///   - Float
    ///   - Packed Struct
    ///   - Packed Union
    ///   - Any zero-size type (Skips field, even pointers to them, since any pointer address is valid)
    ///
    /// Where `STRUCT` must be a non-packed struct (otherwise it will be a numeric)
    pub fn get_complete_type_info_from_field_and_next_field(comptime self: *DataOpBuilderLowLevel, comptime FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime OVERRIDES: SerialSettingsOverride) CompleteTypeSerialInfo {
        const OFFSET_TO_NEXT_FIELD = self.get_offset_between_two_fields_on_current_type(FIELD, NEXT_FIELD);
        const TYPE, const SETTINGS = self.get_type_and_final_settings_for_sub_type_or_field_on_current_type(null, FIELD);
        return self.get_complete_type_info_from_type_settings_and_offset_to_next(TYPE, OFFSET_TO_NEXT_FIELD, SETTINGS, OVERRIDES);
    }

    /// This method takes ANY of the following type patterns and serializes them in 1-6 ops:
    ///   - `NUMERIC_OR_STRUCT`
    ///   - `[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `*NUMERIC_OR_STRUCT`
    ///   - `?*NUMERIC_OR_STRUCT`
    ///   - `[*]NUMERIC_OR_STRUCT`
    ///   - `?[*]NUMERIC_OR_STRUCT`
    ///   - `*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///
    /// Where `NUMERIC` is one of the following:
    ///   - Integer
    ///   - Enum
    ///   - Bool
    ///   - Float
    ///   - Packed Struct
    ///   - Packed Union
    ///   - Any zero-size type (Skips field, even pointers to them, since any pointer address is valid)
    ///
    /// Where `STRUCT` must be a non-packed struct (otherwise it will be a numeric)
    pub fn get_complete_type_info_from_type_settings_and_offset_to_next(comptime self: *DataOpBuilderLowLevel, comptime TYPE: type, comptime OFFSET_TO_NEXT_FIELD: i32, comptime SETTINGS: ObjectSerialSettings, comptime OVERRIDES: SerialSettingsOverride) CompleteTypeSerialInfo {
        comptime var info: CompleteTypeSerialInfo = .{};
        const FINAL_SETTINGS = SETTINGS.combined_with_overrides(OVERRIDES);
        info.SETTINGS_AFTER_OVERRIDE = FINAL_SETTINGS;
        info.SETTINGS_BEFORE_OVERRIDE = SETTINGS;
        info.OFFSET_TO_NEXT_FIELD = OFFSET_TO_NEXT_FIELD;
        info.TYPE = TYPE;
        info.PTR_CHILD_TYPE = TYPE;
        info.ARR_ELEM_TYPE = TYPE;
        info.TARGET_ENDIAN = FINAL_SETTINGS.TARGET_ENDIAN;
        info.USIZE_COMPAT = FINAL_SETTINGS.USIZE_COMPATABILITY;
        info.CACHE_MODE = if (OVERRIDES.CACHE) |CACHE| CACHE else DataCacheMode.DONT_CACHE_DATA;
        info.NUM_OPS_REQUIRED_TO_SERIALIZE = 0;
        const KIND_INFO = KindInfo.get_kind_info(TYPE);
        comptime var POINTER_ALLOWED: bool = true;
        comptime var POINTER_REQUIRED: bool = false;
        comptime var OPTIONAL_ALLOWED: bool = true;
        comptime var T: type = TYPE;
        with_info: switch (KIND_INFO) {
            .VOID => {
                if (POINTER_REQUIRED) break :with_info;
                info.IS_VALID = true;
                info.NUM_OPS_REQUIRED_TO_SERIALIZE = 1;
                info.OP_PATTERN[0] = .MOVE_TO_NEXT;
                info.OP_PATTERN_OFFSETS_TO_NEXT[0] = info.OFFSET_TO_NEXT_FIELD;
                return;
            },
            .INT, .FLOAT, .ENUM, .BOOL => {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) continue :with_info KindInfo.get_kind_info(void);
                info.IS_NUMERIC_PATTERN = true;
                info.IS_VALID = true;
                info.ARR_ELEM_TYPE = T;
                info.RAW_FINAL_TYPE = DataOpBuilderLowLevel.re_type_numeric_type(T);
            },
            .STRUCT => |STRUCT| {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) continue :with_info KindInfo.get_kind_info(void);
                info.IS_VALID = true;
                if (STRUCT.backing_integer == null) {
                    info.IS_STRUCT_PATTERN = true;
                    info.STRUCT_UNIQUE_IDX = self.locate_or_create_unique_type_idx(T, info.SETTINGS_AFTER_OVERRIDE);
                    info.ARR_ELEM_TYPE = T;
                    info.RAW_FINAL_TYPE = T;
                } else {
                    info.IS_NUMERIC_PATTERN = true;
                    info.ARR_ELEM_TYPE = T;
                    info.RAW_FINAL_TYPE = DataOpBuilderLowLevel.re_type_numeric_type(STRUCT.backing_integer.?);
                }
            },
            .UNION => |UNION| {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) continue :with_info KindInfo.get_kind_info(void);
                if (UNION.layout != .@"packed") break :with_info;
                info.IS_NUMERIC_PATTERN = true;
                info.IS_VALID = true;
                info.ARR_ELEM_TYPE = T;
                info.RAW_FINAL_TYPE = DataOpBuilderLowLevel.re_type_numeric_type(Types.UnsignedIntegerWithSameSize(T));
            },
            .ARRAY => |ARRAY| {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) continue :with_info KindInfo.get_kind_info(void);
                info.TOTAL_ARR_LEN *= ARRAY.len;
                info.DATA_IS_ARRAY = true;
                POINTER_ALLOWED = false;
                OPTIONAL_ALLOWED = false;
                T = ARRAY.child;
                continue :with_info KindInfo.get_kind_info(T);
            },
            .VECTOR => |VECTOR| {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) continue :with_info KindInfo.get_kind_info(void);
                info.TOTAL_ARR_LEN *= VECTOR.len;
                info.DATA_IS_ARRAY = true;
                POINTER_ALLOWED = false;
                OPTIONAL_ALLOWED = false;
                T = VECTOR.child;
                continue :with_info KindInfo.get_kind_info(T);
            },
            .POINTER => |POINTER| {
                if (FINAL_SETTINGS.POINTER_MODE == .DISALLOW_POINTERS or POINTER.size == .slice or !POINTER_ALLOWED) break :with_info;
                if (FINAL_SETTINGS.POINTER_MODE == .IGNORE_POINTERS) continue :with_info KindInfo.get_kind_info(void);
                POINTER_REQUIRED = false;
                POINTER_ALLOWED = false;
                OPTIONAL_ALLOWED = false;
                info.IS_POINTER = true;
                info.REAL_DATA_IN_SEPARATE_REGION = true;
                info.PTR_ALIGN = POINTER.alignment;
                info.ALLOC_IDX = self.get_or_add_alloc_name_index(FINAL_SETTINGS.ALLOCATOR_NAME);
                info.PTR_CHILD_TYPE = POINTER.child;
                info.POINTER_KIND = if (POINTER.size == .c) .one else POINTER.size;
                info.PTR_SENTINEL = POINTER.sentinel_ptr;
                if (info.PTR_SENTINEL != null) {
                    info.HAS_SENTINEL = true;
                }
                T = POINTER.child;
                continue :with_info KindInfo.get_kind_info(T);
            },
            .OPTIONAL => |OPTIONAL| {
                if (POINTER_REQUIRED or !OPTIONAL_ALLOWED) break :with_info;
                POINTER_REQUIRED = true;
                OPTIONAL_ALLOWED = false;
                info.PTR_IS_NULLABLE = true;
                T = OPTIONAL.child;
                continue :with_info KindInfo.get_kind_info(T);
            },
            else => {
                if (POINTER_REQUIRED) break :with_info;
                if (@sizeOf(T) == 0) {
                    info.IS_VALID = true;
                    info.NUM_OPS_REQUIRED_TO_SERIALIZE = 1;
                    info.OP_PATTERN[0] = .MOVE_TO_NEXT;
                    info.OP_PATTERN_OFFSETS_TO_NEXT[0] = info.OFFSET_TO_NEXT_FIELD;
                    return;
                }
            },
        }
        assert_with_reason(info.IS_VALID, @src(), "type is not an allowed type for the `get_complete_type_info______________()` funcs.\nAllowed type patterns are:\n\t- NUMERIC_OR_STRUCT\n\t- [ARRAY OR VECTOR]NUMERIC_OR_STRUCT\n\t- [CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT\n\t- *NUMERIC_OR_STRUCT\n\t- [*]NUMERIC_OR_STRUCT\n\t- ?*NUMERIC_OR_STRUCT\n\t- ?[*]NUMERIC_OR_STRUCT\n\t- *[ARRAY OR VECTOR]NUMERIC_OR_STRUCT\n\t- ?*[ARRAY OR VECTOR]NUMERIC_OR_STRUCT\n\t- [*][ARRAY OR VECTOR]NUMERIC_OR_STRUCT\n\t- ?[*][ARRAY OR VECTOR]NUMERIC_OR_STRUCT\n\t- *[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT\n\t- ?*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT\n\t- [*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT\n\t- ?[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT\nWhere `NUMERIC` is one of the following:\n\t- Integer\n\t- Enum\n\t- Bool\n\t- Float\n\t- Packed Struct\n\t- Packed Union\n`STRUCT` must be a non-packed struct (otherwise it will be a numeric)\nGot invalid type `{s}`\n", .{@typeName(TYPE)});
        assert_with_reason(info.CACHE_MODE == .DONT_CACHE_DATA or info.TOTAL_ARR_LEN == 1, @src(), "cannot cache data from arrays or nested arrays whose total flattened length is not EXACTLY 1, got `TOTAL_ARR_LEN` = {d}", .{info.TOTAL_ARR_LEN});
        if (OVERRIDES.POINTER_LEN_MODE) |PTR_LEN_OVERRIDE| {
            switch (PTR_LEN_OVERRIDE) {
                .SINGLE_ITEM => info.POINTER_KIND = .one,
                .MANY_ITEM => info.POINTER_KIND = .many,
            }
        }
        info.NEEDS_CACHED_LEN = info.POINTER_KIND == .many;
        info.PTR_LEN_MODE = switch (info.POINTER_KIND) {
            .one => switch (info.PTR_IS_NULLABLE) {
                true => PointerLenMode.STATIC_LEN_POINTER_OR_NULL,
                false => PointerLenMode.STATIC_LEN_POINTER,
            },
            .many => switch (info.PTR_IS_NULLABLE) {
                true => switch (info.PTR_SENTINEL != null) {
                    true => PointerLenMode.DYNAMIC_LEN_POINTER_WITH_SENTINEL_OR_NULL,
                    false => PointerLenMode.DYNAMIC_LEN_POINTER_OR_NULL,
                },
                false => switch (info.PTR_SENTINEL != null) {
                    true => PointerLenMode.DYNAMIC_LEN_POINTER_WITH_SENTINEL,
                    false => PointerLenMode.DYNAMIC_LEN_POINTER,
                },
            },
            else => unreachable,
        };
        info.REAL_DATA_SIZE = info.TOTAL_ARR_LEN * @sizeOf(info.RAW_FINAL_TYPE);
        info.REAL_DATA_SIZE_WITH_SENTINEL = if (info.HAS_SENTINEL) info.REAL_DATA_SIZE + @sizeOf(info.PTR_CHILD_TYPE) else info.REAL_DATA_SIZE;
        info.REAL_DATA_SER_SIZE = if (info.REAL_DATA_SIZE == 0) 0 else switch (info.TECH) {
            .TARGET_ENDIAN_SAME_SIZE => info.REAL_DATA_SIZE,
            .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => info.TOTAL_ARR_LEN * 1,
            else => 0,
        };
        info.USIZE_TECH = get_tech_for_numeric_type(FINAL_SETTINGS, usize);
        if (info.IS_NUMERIC_PATTERN) {
            info.TECH = get_tech_for_numeric_type(FINAL_SETTINGS, info.RAW_FINAL_TYPE);
            info.RAW_FINAL_TYPE_SER_SIZE = if (info.REAL_DATA_SIZE == 0) 0 else switch (info.TECH) {
                .TARGET_ENDIAN_SAME_SIZE => @sizeOf(info.RAW_FINAL_TYPE),
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => 1,
                else => 0,
            };
            info.USIZE_SER_SIZE = switch (info.USIZE_TECH) {
                .TARGET_ENDIAN_SAME_SIZE => @sizeOf(usize),
                .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => 1,
                else => 0,
            };
            if (info.DATA_IS_ARRAY) {
                if (info.TOTAL_ARR_LEN == 1) {
                    info.DATA_IS_ARRAY = false;
                    info.NUM_OPS_REQUIRED_TO_SERIALIZE -= 1;
                    info.OP_PATTERN[info.NUM_OPS_REQUIRED_TO_SERIALIZE - 1] = .NUMERIC;
                } else if (@sizeOf(info.RAW_FINAL_TYPE) == 1 or (info.TECH == .TARGET_ENDIAN_SAME_SIZE and info.TARGET_ENDIAN == NATIVE_ENDIAN)) {
                    info.NUM_OPS_REQUIRED_TO_SERIALIZE -= 1;
                    info.ARRAY_CAN_BE_BULK_COPIED = true;
                    info.OP_PATTERN[info.NUM_OPS_REQUIRED_TO_SERIALIZE - 1] = .FLAT_ARRAY;
                }
            }
        } else {
            comptime assert_with_reason(info.IS_STRUCT_PATTERN, @src(), "somehow the complete info was `VALID`, but both `IS_NUMERIC_PATTERN` and `IS_STRUCT_PATTERN` were false, internal logic error", .{});
        }
        assert_with_reason(info.REAL_DATA_SIZE > 0, @src(), "somehow a zero-sized element type didnt short-circuit as a `MOVE_NEXT` op", .{});
        comptime var i: usize = 0;
        if (info.PTR_IS_NULLABLE) {
            info.OP_PATTERN[i] = .OPTIONAL;
            info.OP_PATTERN_OFFSETS_TO_NEXT[i] = 0;
            i += 1;
        }
        if (info.IS_POINTER) {
            info.OP_PATTERN[i] = .POINTER;
            info.OP_PATTERN_OFFSETS_TO_NEXT[i] = info.OFFSET_TO_NEXT_FIELD;
            i += 1;
            info.OP_PATTERN[i] = .POINTER_SUBROUTINE;
            info.OP_PATTERN_OFFSETS_TO_NEXT[i] = 0;
            i += 1;
            info.PTR_SUBROUTINE_LEN = 1;
        }
        if (info.DATA_IS_ARRAY) {
            if (info.ARRAY_CAN_BE_BULK_COPIED) {
                info.OP_PATTERN[i] = .FLAT_ARRAY;
                info.OP_PATTERN_OFFSETS_TO_NEXT[i] = if (info.IS_POINTER) info.REAL_DATA_SIZE else info.OFFSET_TO_NEXT_FIELD;
                i += 1;
            } else {
                info.OP_PATTERN[i] = .ARRAY;
                info.OP_PATTERN_OFFSETS_TO_NEXT[i] = if (info.IS_POINTER) info.REAL_DATA_SIZE else info.OFFSET_TO_NEXT_FIELD;
                i += 1;
                info.OP_PATTERN[i] = if (info.IS_NUMERIC_PATTERN) .NUMERIC else .STRUCT;
                info.OP_PATTERN_OFFSETS_TO_NEXT[i] = num_cast(@sizeOf(info.RAW_FINAL_TYPE), i32);
                i += 1;
            }
        } else {
            info.OP_PATTERN[i] = if (info.IS_NUMERIC_PATTERN) .NUMERIC else .STRUCT;
            info.OP_PATTERN_OFFSETS_TO_NEXT[i] = if (info.IS_POINTER) num_cast(@sizeOf(info.PTR_CHILD_TYPE), i32) else info.OFFSET_TO_NEXT_FIELD;
            i += 1;
        }
        if (info.IS_POINTER and info.HAS_SENTINEL) {
            info.OP_PATTERN[i] = .ADD_SENTINEL;
            info.OP_PATTERN_OFFSETS_TO_NEXT[i] = 0;
            info.PTR_SUBROUTINE_LEN += 1;
            i += 1;
        }
        return info;
    }

    /// Be careful, this does not validate the `CompleteTypeSerialInfo` is correct, so if you build one manually and it is incorrect,
    /// this will poison your serial routine.
    pub fn add_ops_for_complete_type_serial_info_and_update_cached_values(comptime self: *DataOpBuilderLowLevel, comptime info: CompleteTypeSerialInfo, comptime FIELD: []const u8) void {
        self.add_ops_for_complete_type_serial_info(info);
        self.internal.handle_cached_values(FIELD, info);
    }

    /// Be careful, this does not validate the `CompleteTypeSerialInfo` is correct, so if you build one manually and it is incorrect,
    /// this will poison your serial routine.
    pub fn add_ops_for_complete_type_serial_info(comptime self: *DataOpBuilderLowLevel, comptime info: CompleteTypeSerialInfo) void {
        for (info.OP_PATTERN[0..info.NUM_OPS_REQUIRED_TO_SERIALIZE], info.OP_PATTERN_OFFSETS_TO_NEXT[0..info.NUM_OPS_REQUIRED_TO_SERIALIZE]) |pattern, offset_to_next| {
            switch (pattern) {
                .OPTIONAL => {
                    self.add_transfer_data_op(@sizeOf(usize), offset_to_next, 1, info.TARGET_ENDIAN, .NON_ZERO_READ_OR_WRITE_1_ELSE_0, .CACHE_NULL);
                },
                .POINTER => {
                    self.add_allocated_pointer_op(@sizeOf(info.PTR_CHILD_TYPE), info.PTR_ALIGN, info.ALLOC_IDX, 1, offset_to_next, info.PTR_LEN_MODE);
                },
                .POINTER_SUBROUTINE => {
                    self.add_inline_subroutine_start_op(info.PTR_SUBROUTINE_LEN, 1, offset_to_next, .STATIC_REPEAT_OR_NO_REPEAT, .SUB_ALLOCATED_REGION);
                },
                .FLAT_ARRAY => {
                    self.add_transfer_data_op(info.REAL_DATA_SIZE, offset_to_next, info.REAL_DATA_SER_SIZE, info.TARGET_ENDIAN, .TARGET_ENDIAN_SAME_SIZE, DataCacheMode.DONT_CACHE_DATA);
                },
                .ARRAY => {
                    self.add_inline_subroutine_start_op(1, info.TOTAL_ARR_LEN, offset_to_next, .STATIC_REPEAT_OR_NO_REPEAT, .SAME_MEMORY_REGION);
                },
                .NUMERIC => {
                    self.add_transfer_data_op(@sizeOf(info.RAW_FINAL_TYPE), offset_to_next, info.RAW_FINAL_TYPE_SER_SIZE, info.TARGET_ENDIAN, info.TECH, info.CACHE_MODE);
                },
                .ADD_SENTINEL => {
                    self.add_pointer_sentinel_op(@sizeOf(info.PTR_CHILD_TYPE), info.PTR_SENTINEL.?);
                },
                .MOVE_TO_NEXT => {
                    self.add_move_native_offset_op(offset_to_next);
                },
                .STRUCT => {
                    self.add_ref_unique_type_op(info.STRUCT_UNIQUE_IDX, offset_to_next);
                },
            }
        }
    }
};

pub const NO_FIELD_CACHE = "<cached but no field>";
pub const NO_LEN_CACHE = "<no cached len>";
pub const NO_TAG_CACHE = "<no cached tag>";
pub const NO_NULL_CACHE = "<no cached null>";
pub const NO_FIELD_END_STRUCT = "<null, end struct>";

pub const WithNextField = struct {
    next: ?[]const u8 = null,

    pub fn next_field_is(field: []const u8) WithNextField {
        return WithNextField{ .next = field };
    }
    pub fn this_is_last_field() WithNextField {
        return WithNextField{ .next = null };
    }
};

pub const UseCachedLen = struct {
    cached: ?[]const u8 = null,

    pub fn use_cached_len_field(field: []const u8) UseCachedLen {
        return UseCachedLen{ .cached = field };
    }
    pub fn no_len_needed() UseCachedLen {
        return UseCachedLen{ .cached = null };
    }
};

/// A 'high-level' DataOpBuilder. This is usually the best choice
/// for most custom serialization solutions, as it generally ensures
/// correct functionality. Only valid when the current type is a struct type,
/// but it provides extensions for building custom union and optional routines.
pub const DataOpBuilderHighLevel = struct {
    /// A 'low-level' DataOpBuilder. You can add specific ops in any custom order,
    /// and it is up to the library consumer to ensure it is correct.
    low_level: DataOpBuilderLowLevel,

    pub fn get_settings(self: *const DataOpBuilderHighLevel) ObjectSerialSettings {
        return self.low_level.internal.object_settings;
    }

    /// Add a struct field using the standard procedure. Supported numeric fields will have
    /// their ops written inline in 1-6 ops, while non-packed structs will
    /// reference their unique 'struct + settings' as recorded in the
    /// `unique_structs: []const UniqueSerialStructAndSettings` list generated by the SerializationManager
    ///
    /// Valid type patterns are:
    ///   - `NUMERIC_OR_STRUCT`
    ///   - `[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `*NUMERIC_OR_STRUCT`
    ///   - `?*NUMERIC_OR_STRUCT`
    ///   - `*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `[*]NUMERIC_OR_STRUCT`
    ///   - `?[*]NUMERIC_OR_STRUCT`
    ///   - `[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `?[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
    ///   - `[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///   - `?[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
    ///
    /// Where `NUMERIC` is one of the following:
    ///   - Integer
    ///   - Enum
    ///   - Bool
    ///   - Float
    ///   - Packed Struct
    ///   - Packed Union
    ///   - Any zero-size type (Skips field, even pointers to them, since any pointer address is valid)
    ///
    /// Where `STRUCT` must be a non-packed struct (otherwise it will be a numeric)
    ///
    /// Other type patterns must be handled with manual `DataOpBuilderLowLevel` calls, manual runtime serialization functions, or using one of the
    /// provided `Serial______` types that have pre-defined custom routines and can behave like their native counterparts:
    ///  - Non-packed unions => `SerialTaggedUnion` or `SerialPunnedUnion`
    ///  - Non-pointer optionals => `SerialOptional`
    ///  - Slices => `SerialSlice`
    ///  - Errors => use an Enum instead
    ///    - error int values are not even compatible across zig binaries, let alone in foreign consumers
    ///  - Error unions => Combine solutions for 'non-packed unions' and 'errors'
    ///    - One union branch is an enum with the error code
    ///    - One union branch with the payload
    ///    - ... or your custom op calls or runtime serial functions
    ///  - Arrays of pointers or pointers to arrays of pointers => Manual op calls or runtime funcs only
    ///    - This may change in the future but greatly complicates serialization
    pub fn add_field(comptime self: *DataOpBuilderHighLevel, comptime FIELD: []const u8, comptime NEXT_FIELD: WithNextField, comptime USE_LEN: UseCachedLen, comptime OVERRIDES: SerialSettingsOverride) CompleteTypeSerialInfo {
        _ = self.low_level.handle_field_links_and_get_offset_to_next(self, FIELD, NEXT_FIELD.next);
        if (USE_LEN.cached != null) {
            self.low_level.internal.assert_cached_len_match(self, USE_LEN.cached.?, @src());
        }
        const COMPLETE_INFO = comptime self.low_level.get_complete_type_info_from_field_and_next_field(FIELD, NEXT_FIELD, OVERRIDES);
        if (USE_LEN.cached != null or COMPLETE_INFO.NEEDS_CACHED_LEN == true) {
            assert_with_reason(USE_LEN.cached != null, @src(), "you must have a cached len at this point. If you know a cached len exists, provide the name of the cached field for validation", .{});
            self.low_level.internal.assert_cached_len_match(self, USE_LEN.cached.?, @src());
            assert_with_reason(COMPLETE_INFO.NEEDS_CACHED_LEN == true, @src(), "it was expected that the type required a cached len, but the complete info indicated it didn't", .{});
        }
        self.low_level.add_ops_for_complete_type_serial_info(COMPLETE_INFO);
        self.low_level.internal.handle_cached_values(self, FIELD, COMPLETE_INFO);
        return COMPLETE_INFO;
    }

    /// Build an extern union subroutine using a tag cached by a previous data transfer op. Note the input parameters:
    ///   - `CACHED_TAG_FIELD` = the field name that was previously cached MUST MATCH the one recorded. This is mainly for validation of expected behavior.
    ///   - `TAG_TYPE` = an Enum or Integer type that is used to choose the active union field.
    ///     - These do not necessarily need to correlate 1-to-1 with the union fields,
    /// the builder is responsible for correctly filling in the union data based on tag values
    pub fn start_extern_union_builder_with_cached_tag(comptime self: *DataOpBuilderHighLevel, comptime FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime CACHED_TAG_FIELD: []const u8, comptime TAG_TYPE: type, comptime OVERRIDES: SerialSettingsOverride) DataOpBuilderExternUnion(TAG_TYPE) {
        self.low_level.internal.assert_cached_tag_and_type_match(self, CACHED_TAG_FIELD, TAG_TYPE, @src());
        _ = self.low_level.handle_field_links_and_get_offset_to_next(self, FIELD, NEXT_FIELD);
        const TYPE, const SETTINGS, const OFFSET_TO_NEXT_FIELD = self.low_level.get_type_settings_and_offset_from_field_and_next_field(FIELD, NEXT_FIELD, OVERRIDES);
        const KIND = KindInfo.get_kind_info(TYPE);
        assert_with_reason(KIND == .UNION and KIND.UNION.tag_type == null and KIND.UNION.layout == .@"extern", @src(), "type of `FIELD` must be an extern union type (it is the only union type with a well defined memory layout for automatic serialization), got type `{s}`", .{@typeName(TYPE)});
        const header_op_idx = self.low_level.internal.ops_len;
        self.low_level.add_union_header_op(0);
        const UNION_BUILDER = DataOpBuilderExternUnion(TAG_TYPE);
        const union_builder = UNION_BUILDER{
            .builder = self,
            .settings = SETTINGS,
            .op_idx_for_header = header_op_idx,
            .union_type = TYPE,
            .union_field = FIELD,
            .offset_to_next_field = OFFSET_TO_NEXT_FIELD,
        };
        return union_builder;
    }
};

pub fn DataOpBuilderExternUnion(comptime TAG_TYPE: type) type {
    return struct {
        const Self = @This();
        builder: *DataOpBuilderHighLevel,
        union_type: type,
        union_field: []const u8,
        settings: ObjectSerialSettings,
        op_idx_for_header: u32,
        num_branches: u32 = 0,
        union_fields_needed: u32 = 0,
        union_fields_added: u32 = 0,
        offset_to_next_field: i32 = 0,

        fn cast_val_to_u64(comptime val: TAG_TYPE) u64 {
            const INFO = KindInfo.get_kind_info(TAG_TYPE);
            switch (INFO) {
                .ENUM => |ENUM| {
                    const INT = ENUM.tag_type;
                    const int = @intFromEnum(val);
                    const uint: Types.UnsignedIntegerWithSameSize(INT) = @bitCast(int);
                    return num_cast(uint, u64);
                },
                .INT => {
                    const uint: Types.UnsignedIntegerWithSameSize(TAG_TYPE) = @bitCast(val);
                    return num_cast(uint, u64);
                },
                else => assert_unreachable(@src(), "only Enums or Integers are allowed as `TAG_TYPE`, got type `{s}`", .{@typeName(TAG_TYPE)}),
            }
        }

        pub const TagMode = union(enum) {
            SINGLE_TAG_VALUE: TAG_TYPE,
            RANGE_OF_TAG_VALUES: struct { min: TAG_TYPE, max: TAG_TYPE },

            pub fn single_tag_value(val: TAG_TYPE) TagMode {
                return TagMode{ .SINGLE_TAG_VALUE = val };
            }
            pub fn range_of_tag_values(min: TAG_TYPE, max: TAG_TYPE) TagMode {
                return TagMode{ .RANGE_OF_TAG_VALUES = .{ .min = min, .max = max } };
            }
        };

        /// Add an extern union field using the standard procedure. Supported numeric fields will have
        /// their ops written inline in 1-6 ops, while non-packed structs will
        /// reference their unique 'struct + settings' subroutine as recorded in the
        /// `unique_structs: []const UniqueSerialStructAndSettings` list generated by the SerializationManager
        ///
        /// Valid type patterns are:
        ///   - `NUMERIC_OR_STRUCT`
        ///   - `[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
        ///   - `[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
        ///   - `*NUMERIC_OR_STRUCT`
        ///   - `?*NUMERIC_OR_STRUCT`
        ///   - `*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
        ///   - `?*[ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
        ///   - `*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
        ///   - `?*[CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
        ///   - `[*]NUMERIC_OR_STRUCT`
        ///   - `?[*]NUMERIC_OR_STRUCT`
        ///   - `[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
        ///   - `?[*][ARRAY_OR_VECTOR]NUMERIC_OR_STRUCT`
        ///   - `[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
        ///   - `?[*][CHAIN][OF][NESTED][ARRAYS][OR][VECTORS]NUMERIC_OR_STRUCT`
        ///
        /// Where `NUMERIC` is one of the following:
        ///   - Integer
        ///   - Enum
        ///   - Bool
        ///   - Float
        ///   - Packed Struct
        ///   - Packed Union
        ///   - Any zero-size type (Skips field, even pointers to them, since any pointer address is valid)
        ///
        /// Where `STRUCT` must be a non-packed struct (otherwise it will be a numeric)
        ///
        /// Other type patterns must be handled with manual `DataOpBuilderLowLevel` calls, manual runtime serialization functions, or using one of the
        /// provided `Serial______` types that have pre-defined custom routines and can behave like their native counterparts:
        ///  - Non-packed unions => `SerialTaggedUnion` or `SerialPunnedUnion`
        ///  - Non-pointer optionals => `SerialOptional`
        ///  - Slices => `SerialSlice`
        ///  - Errors => use an Enum instead
        ///    - error int values are not even compatible across zig binaries, let alone in foreign consumers
        ///  - Error unions => Combine solutions for 'non-packed unions' and 'errors'
        ///    - One union branch is an enum with the error code
        ///    - One union branch with the payload
        ///    - ... or your custom op calls or runtime serial functions
        ///  - Arrays of pointers or pointers to arrays of pointers => Manual op calls or runtime funcs only
        ///    - This may change in the future but greatly complicates serialization
        pub fn add_field(comptime self: *Self, comptime TAG: TagMode, comptime FIELD: []const u8, comptime USE_LEN: DataOpBuilderHighLevel.UseCachedLen, comptime OVERRIDES: SerialSettingsOverride) CompleteTypeSerialInfo {
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FIELD_SETTINGS = get_field_settings(self.union_type, FIELD);
            const OBJECT_SETTINGS = get_object_settings(TYPE);
            const SETTINGS = self.settings.with_custom_routine_removed().combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
            if (USE_LEN.cached != null) {
                DataOpBuilderHighLevel.INTERNAL.assert_cached_len_match(self.builder, USE_LEN.cached.?, @src());
            }
            const COMPLETE_INFO = comptime self.builder.low_level.get_complete_type_info_from_type_settings_and_offset_to_next(TYPE, self.offset_to_next_field, SETTINGS, OVERRIDES);
            if (USE_LEN.cached != null or COMPLETE_INFO.NEEDS_CACHED_LEN == true) {
                assert_with_reason(USE_LEN.cached != null, @src(), "you must have a cached len at this point. If you know a cached len exists, provide the name of the cached field for validation", .{});
                DataOpBuilderHighLevel.INTERNAL.assert_cached_len_match(self, USE_LEN.cached.?, @src());
                assert_with_reason(COMPLETE_INFO.NEEDS_CACHED_LEN == true, @src(), "it was expected that the type required a cached len, but the complete info indicated it didn't", .{});
            }
            switch (TAG) {
                .SINGLE_TAG_VALUE => |val| {
                    const as_u64 = cast_val_to_u64(val);
                    self.builder.low_level.add_union_tag_op(as_u64, COMPLETE_INFO.NUM_OPS_REQUIRED_TO_SERIALIZE);
                },
                .RANGE_OF_TAG_VALUES => |range| {
                    const min_as_u64 = cast_val_to_u64(range.min);
                    const max_as_u64 = cast_val_to_u64(range.max);
                    self.builder.low_level.add_union_range_op(min_as_u64, max_as_u64, COMPLETE_INFO.NUM_OPS_REQUIRED_TO_SERIALIZE);
                },
            }
            self.builder.low_level.add_ops_for_complete_type_serial_info(COMPLETE_INFO);
            DataOpBuilderHighLevel.INTERNAL.handle_cached_values(self.builder, self.union_field ++ "." ++ FIELD, COMPLETE_INFO);
            self.num_branches += 1;
            return COMPLETE_INFO;
        }

        pub fn finalize(comptime self: *Self) void {
            self.builder.low_level.ops[self.op_idx_for_header].UNION_HEADER.num_fields = self.num_branches;
            self.* = undefined;
        }
    };
}

const RoutineStackFrame = struct {
    routine_start: u32,
    routine_end: u32,
    routine_idx: u32,
    routine_repeat_left: u32,
    native_offset_after_routine: i32,
    pop_mem_region_after_complete: bool = false,
};

const MemRegionStackFrame = struct {
    min_addr: usize,
    max_addr: usize,
    native_ptr: [*]u8,

    pub fn move_ptr(self: *MemRegionStackFrame, delta: i32) void {
        if (delta < 0) {
            self.native_ptr -= abs_cast(delta, usize);
        } else {
            self.native_ptr += num_cast(delta, usize);
        }
        if (Assert.should_assert()) {
            const native_addr = @intFromPtr(self.native_ptr);
            assert_with_reason(self.min_addr <= native_addr and native_addr < self.max_addr, @src(), "native pointer offset caused the native pointer to escape its memory region: ptr address {s}", .{if (self.min_addr > native_addr) "too low" else "too high"});
        }
    }
    pub fn move_ptr_backward(self: *MemRegionStackFrame, delta: u32) void {
        self.native_ptr -= num_cast(delta, usize);
        if (Assert.should_assert()) {
            const native_addr = @intFromPtr(self.native_ptr);
            assert_with_reason(self.min_addr <= native_addr and native_addr < self.max_addr, @src(), "native pointer offset caused the native pointer to escape its memory region: ptr address {s}", .{if (self.min_addr > native_addr) "too low" else "too high"});
        }
    }
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

    pub fn combined_with_overrides(self: ObjectSerialSettings, overrides: SerialSettingsOverride) ObjectSerialSettings {
        var out = self;
        if (overrides.INTEGER_PACKING) |int_packing| out.INTEGER_PACKING = int_packing;
        if (overrides.POINTER_MODE) |ptr_mode| out.POINTER_MODE = ptr_mode;
        if (overrides.TARGET_ENDIAN) |endian| out.TARGET_ENDIAN = endian;
        if (overrides.USIZE_COMPATABILITY) |compat| out.USIZE_COMPATABILITY = compat;
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

fn get_object_settings(comptime TYPE: type) ?OptionalObjectSerialSettings {
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

pub fn SerializationManager(comptime MAIN_TYPES_FOR_SERIALIZATION: []const type, comptime DEFAULT_SERIAL_SETTINGS: ObjectSerialSettings, comptime ARRAY_MAX_LENS: SerialManagerArrayLens) type {
    comptime var _UNIQUE_TYPE_ARRAY: [ARRAY_MAX_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialStructAndSettingsBuild = undefined;
    comptime var _OP_BUFFER: [ARRAY_MAX_LENS.OP_BUFFER_MAX_LEN]DataOp = undefined;
    comptime var _ALLOC_NAME_BUFFER: [ARRAY_MAX_LENS.ALLOC_NAME_BYTES_BUFFER_MAX_LEN]u8 = undefined;
    comptime var _ALLOC_NAME_LIST: [ARRAY_MAX_LENS.ALLOC_NAME_LIST_MAX_LEN]SliceRange = undefined;
    comptime var _OP_USED_TRACKER: [DataOpKind.NUM_OP_KINDS]bool = @splat(false);
    comptime var _BUILDER = DataOpBuilderHighLevel{
        .low_level = DataOpBuilderLowLevel{
            .internal = DataOpBuilderInternal{
                .ops_used_tracker = &_OP_USED_TRACKER,
                .unique = _UNIQUE_TYPE_ARRAY[0..],
                .ops = _OP_BUFFER[0..],
                .alloc_buf = _ALLOC_NAME_BUFFER[0..],
                .alloc_names = _ALLOC_NAME_LIST[0..],
            },
        },
    };
    _BUILDER.low_level.internal.build_all_type_routines_starting_from_these_root_types(MAIN_TYPES_FOR_SERIALIZATION, DEFAULT_SERIAL_SETTINGS);
    comptime var _FINAL_OPS_LIST: [_BUILDER.low_level.internal.ops_len]DataOp = undefined;
    comptime var _FINAL_UNIQUE_LIST: [_BUILDER.low_level.internal.unique_len]UniqueSerialStructAndSettingsFinal = undefined;
    comptime var _FINAL_UNIQUE_LIST_ROOT: [MAIN_TYPES_FOR_SERIALIZATION.len]UniqueSerialStructAndSettingsFinal = undefined;
    // comptime var _FINAL_ALLOC_NAME_BUFFER: [_BUILDER.low_level.internal.alloc_buf_len]u8 = undefined;
    // comptime var _FINAL_ALLOC_NAME_LIST: [_BUILDER.low_level.internal.alloc_names_len]SliceRange = undefined;
    comptime {
        @memcpy(_FINAL_OPS_LIST[0..], _OP_BUFFER[0.._BUILDER.low_level.internal.ops_len]);
        // @memcpy(_FINAL_ALLOC_NAME_BUFFER[0..], _ALLOC_NAME_BUFFER[0.._BUILDER.low_level.internal.alloc_buf_len]);
        // @memcpy(_FINAL_ALLOC_NAME_LIST[0..], _ALLOC_NAME_LIST[0.._BUILDER.low_level.internal.alloc_names_len]);
        for (_UNIQUE_TYPE_ARRAY[0.._BUILDER.low_level.internal.unique_len], 0..) |unique, u| {
            _FINAL_UNIQUE_LIST[u] = unique.to_final();
            if (u < MAIN_TYPES_FOR_SERIALIZATION.len) {
                _FINAL_UNIQUE_LIST_ROOT[u] = _FINAL_UNIQUE_LIST[u];
            }
        }
    }
    const _FINAL_OPS_LIST_CONST = _FINAL_OPS_LIST;
    const _FINAL_UNIQUE_LIST_CONST = _FINAL_UNIQUE_LIST;
    const _FINAL_UNIQUE_LIST_ROOT_CONST = _FINAL_UNIQUE_LIST_ROOT;
    // const _FINAL_ALLOC_NAME_BUFFER_CONST = _FINAL_ALLOC_NAME_BUFFER;
    // const _FINAL_ALLOC_NAME_LIST_CONST = _FINAL_ALLOC_NAME_LIST;
    const _FINAL_OP_USED_TRACKER_CONST = _OP_USED_TRACKER;
    const _FINAL_NUM_ALLOCS = _BUILDER.low_level.internal.alloc_names_len;
    const _FINAL_ALLOC_STRUCT_FIELDS = comptime make: {
        var fields: [_FINAL_NUM_ALLOCS]std.builtin.Type.StructField = undefined;
        for (_ALLOC_NAME_LIST[0.._FINAL_NUM_ALLOCS], 0..) |name_slice, f| {
            const name: []const u8 = _ALLOC_NAME_BUFFER[name_slice.start..name_slice.end];
            fields[f] = std.builtin.Type.StructField{
                .alignment = @alignOf(Allocator),
                .default_value_ptr = @ptrCast(&DummyAllocator.allocator_panic_free_noop),
                .is_comptime = false,
                .name = name,
                .type = Allocator,
            };
        }
        break :make fields;
    };
    return struct {
        const Self = @This();
        pub const OPS = _FINAL_OPS_LIST_CONST;
        pub const UNIQUES = _FINAL_UNIQUE_LIST_CONST;
        pub const ROOT_TYPES = _FINAL_UNIQUE_LIST_ROOT_CONST;
        const OP_USED = _FINAL_OP_USED_TRACKER_CONST;
        const A_FIELDS = _FINAL_ALLOC_STRUCT_FIELDS;
        const NUM_ALLOCS = _FINAL_NUM_ALLOCS;
        pub const AllocatorsStruct: type = @Type(std.builtin.Type{ .@"struct" = std.builtin.Type.Struct{
            .backing_integer = null,
            .decls = &.{},
            .is_tuple = false,
            .layout = .auto,
            .fields = A_FIELDS[0..],
        } });

        routine_stack_ptr: [*]RoutineStackFrame = Utils.invalid_ptr_many(RoutineStackFrame),
        routine_stack_len: u32 = 0,
        routine_stack_cap: u32 = 0,
        native_mem_stack_ptr: [*]MemRegionStackFrame = Utils.invalid_ptr_many(MemRegionStackFrame),
        native_mem_stack_len: u32 = 0,
        native_mem_stack_cap: u32 = 0,
        curr_routine: *RoutineStackFrame = Utils.invalid_ptr(RoutineStackFrame),
        curr_region: *MemRegionStackFrame = Utils.invalid_ptr(MemRegionStackFrame),
        cache_len: usize = 0,
        has_len: bool = false,
        cache_tag: u64 = 0,
        has_tag: bool = false,
        cache_null: bool = false,
        has_null: bool = false,
        obj_allocs: [NUM_ALLOCS]Allocator = @splat(DummyAllocator.allocator_panic_free_noop),
        self_alloc: Allocator = DummyAllocator.allocator_panic_free_noop,
        byte_count: usize = 0,

        pub fn init(initial_routine_stack_capacity: u32, initial_mem_region_capacity: u32, allocator: Allocator) Self {
            var self = Self{
                .self_alloc = allocator,
            };
            Utils.Alloc.smart_alloc_ptr_ptrs(allocator, &self.routine_stack_ptr, &self.routine_stack_cap, @intCast(initial_routine_stack_capacity), .{}, .{});
            Utils.Alloc.smart_alloc_ptr_ptrs(allocator, &self.native_mem_stack_ptr, &self.routine_stack_cap, @intCast(initial_mem_region_capacity), .{}, .{});
            return self;
        }

        fn reset(self: *Self) void {
            self.routine_stack_len = 0;
            self.native_mem_stack_len = 0;
            self.cache_len = 0;
            self.has_len = false;
            self.cache_null = false;
            self.has_null = false;
            self.cache_tag = 0;
            self.has_tag = false;
            self.curr_region = Utils.invalid_ptr(MemRegionStackFrame);
            self.curr_routine = Utils.invalid_ptr(RoutineStackFrame);
            self.obj_allocs = @splat(DummyAllocator.allocator_panic_free_noop);
            self.byte_count = 0;
        }

        const SERDIR = enum {
            NATIVE_TO_SERIAL,
            SERIAL_TO_NATIVE,

            fn serial_type(comptime self: SERDIR) type {
                switch (self) {
                    .NATIVE_TO_SERIAL => SerialDest,
                    .SERIAL_TO_NATIVE => SerialSource,
                }
            }

            fn error_type(comptime self: SERDIR) type {
                switch (self) {
                    .NATIVE_TO_SERIAL => ReadWrite.SerialWriteError,
                    .SERIAL_TO_NATIVE => ReadWrite.SerialReadError,
                }
            }
        };

        fn alloc_array(allocs: AllocatorsStruct) [NUM_ALLOCS]Allocator {
            var arr: [NUM_ALLOCS]Allocator = undefined;
            inline for (@typeInfo(AllocatorsStruct).@"struct".fields, 0..) |field, f| {
                arr[f] = @field(allocs, field.name);
            }
            return arr;
        }

        fn push_routine_frame_from_unique(self: *Self, unique: UniqueSerialStructAndSettingsFinal, num_repeat: u32, offset_after: i32, pop_region_after: bool) void {
            const routine = RoutineStackFrame{
                .native_offset_after_routine = offset_after,
                .routine_start = unique.routine_start,
                .routine_end = unique.routine_end,
                .routine_idx = unique.routine_start,
                .routine_repeat_left = num_repeat,
                .pop_mem_region_after_complete = pop_region_after,
            };
            Alloc.smart_push_to_list_many_ptr(&self.routine_stack_ptr, &self.routine_stack_len, &self.routine_stack_cap, routine, self.self_alloc, .{}, .{});
            self.curr_routine = &self.routine_stack_ptr[self.routine_stack_len - 1];
        }
        fn push_routine_frame_from_unique_ref(self: *Self, ref: RefUniqueTypeSubroutine, num_repeat: bool, pop_region_after: bool) void {
            const unique = UNIQUES[ref.unique_type_index];
            const routine = RoutineStackFrame{
                .native_offset_after_routine = ref.offset_to_next_field,
                .routine_start = unique.routine_start,
                .routine_end = unique.routine_end,
                .routine_idx = unique.routine_start,
                .routine_repeat_left = num_repeat,
                .pop_mem_region_after_complete = pop_region_after,
            };
            Alloc.smart_push_to_list_many_ptr(&self.routine_stack_ptr, &self.routine_stack_len, &self.routine_stack_cap, routine, self.self_alloc, .{}, .{});
            self.curr_routine = &self.routine_stack_ptr[self.routine_stack_len - 1];
        }
        fn push_routine_frame_from_subrs(self: *Self, subrs: SubroutineStart, static_repeat: bool, dynamic_repeat: u32, pop_region_after: bool) void {
            const routine = RoutineStackFrame{
                .native_offset_after_routine = subrs.offset_to_next_field,
                .routine_start = subrs.subroutine_first_op,
                .routine_end = subrs.subroutine_first_op + subrs.subroutine_num_ops,
                .routine_idx = subrs.subroutine_first_op,
                .routine_repeat_left = if (static_repeat) subrs.subroutine_static_repeat else dynamic_repeat,
                .pop_mem_region_after_complete = pop_region_after,
            };
            Alloc.smart_push_to_list_many_ptr(&self.routine_stack_ptr, &self.routine_stack_len, &self.routine_stack_cap, routine, self.self_alloc, .{}, .{});
            self.curr_routine = &self.routine_stack_ptr[self.routine_stack_len - 1];
        }
        fn pop_routine_frame(self: *Self) void {
            assert_with_reason(self.routine_stack_len > 0, @src(), "no routine stack to pop, something went wrong in the internal logic", .{});
            self.routine_stack_len -= 1;
            if (self.routine_stack_len > 0) {
                self.curr_routine = &self.routine_stack_ptr[self.routine_stack_len - 1];
            }
        }

        fn push_mem_region_frame(self: *Self, ptr: [*]u8, len: usize) void {
            const region = MemRegionStackFrame{
                .native_ptr = ptr,
                .min_addr = @intFromPtr(ptr),
                .max_addr = @intFromPtr(ptr) + len,
            };
            Alloc.smart_push_to_list_many_ptr(&self.native_mem_stack_ptr, &self.native_mem_stack_len, &self.native_mem_stack_cap, region, self.self_alloc, .{}, .{});
            self.curr_region = &self.native_mem_stack_ptr[self.native_mem_stack_len - 1];
        }
        fn pop_mem_region_frame(self: *Self) void {
            assert_with_reason(self.native_mem_stack_len > 0, @src(), "no memory region to pop, something went wrong in the internal logic", .{});
            self.native_mem_stack_len -= 1;
            if (self.native_mem_stack_len > 0) {
                @branchHint(.likely);
                self.curr_region = &self.native_mem_stack_ptr[self.native_mem_stack_len - 1];
            }
        }

        fn handle_alloc_pointer(self: *Self, comptime DIR: SERDIR, ptr_op: Pointer, comptime need_cached_len: bool, comptime need_cached_null: bool) void {
            const len = if (need_cached_len) get: {
                assert_with_reason(self.has_len, @src(), "no len cached for dynamic pointer", .{});
                break :get num_cast(ptr_op.elem_size, usize) * self.cache_len;
            } else num_cast(ptr_op.elem_size * ptr_op.static_len, usize);
            const is_null: bool = if (need_cached_null) get: {
                assert_with_reason(self.has_null, @src(), "no cached null for nullable pointer", .{});
                break :get self.cache_null;
            } else false;

            if (!is_null) {
                switch (DIR) {
                    .NATIVE_TO_SERIAL => {
                        const addr_of_native_pointer_slot: *usize = @ptrCast(@alignCast(self.curr_region.native_ptr));
                        const new_native_ptr_region: [*]u8 = @ptrFromInt(addr_of_native_pointer_slot.*);
                        self.curr_region.move_ptr(ptr_op.offset_to_next_field);
                        self.push_mem_region_frame(new_native_ptr_region, len);
                    },
                    .SERIAL_TO_NATIVE => {
                        const addr_of_native_pointer_slot: *usize = @ptrCast(@alignCast(self.curr_region.native_ptr));
                        self.curr_region.move_ptr(ptr_op.offset_to_next_field);
                        self.push_mem_region_frame(Utils.invalid_ptr_many(u8), 0);
                        const alloc = self.obj_allocs[ptr_op.alloc_idx];
                        var temp_len: usize = 0;
                        Alloc.smart_alloc_ptr_ptrs(alloc, &self.curr_region.native_ptr, &temp_len, len, .{}, .{});
                        self.curr_region.max_addr += temp_len;
                        addr_of_native_pointer_slot.* = @intFromPtr(self.curr_region.native_ptr);
                    },
                }
            }
        }

        fn handle_non_zero_read_write_1_else_0(self: *Self, comptime DIR: SERDIR, comptime SER: ReadWrite.SerialKind, comptime CACHE: DataCacheMode, data: DataTransfer, serial: DIR.serial_type()) DIR.error_type()!void {
            const ptr = self.curr_region.native_ptr;
            const slice = ptr[0..data.native_size];
            var val: u8 = 0;
            switch (DIR) {
                .NATIVE_TO_SERIAL => {
                    const ser: SerialDest = serial;
                    for (slice) |byte| {
                        val |= byte;
                    }
                    val |= val >> 1;
                    val |= val >> 2;
                    val |= val >> 4;
                    val &= 1;
                    try ser.write_one_byte(SER, @ptrCast(&val));
                },
                .SERIAL_TO_NATIVE => {
                    const ser: SerialSource = serial;
                    try ser.read_one_byte(SER, @ptrCast(&val));
                    val |= val >> 1;
                    val |= val >> 2;
                    val |= val >> 4;
                    val &= 1;
                    @memset(slice, 0);
                    if (NATIVE_ENDIAN == .LITTLE_ENDIAN) {
                        slice[0] = val;
                    } else {
                        slice[slice.len - 1] = val;
                    }
                },
            }
            switch (CACHE) {
                .CACHE_LEN => {
                    self.cache_len = num_cast(val, usize);
                    self.has_len = true;
                },
                .CACHE_NULL => {
                    self.cache_null = val > 0;
                    self.has_null = true;
                },
                .CACHE_TAG => {
                    self.cache_tag = num_cast(val, u64);
                    self.has_tag = true;
                },
            }
            self.byte_count += 1;
            self.curr_routine.routine_idx += 1;
            self.curr_region.move_ptr(data.offset_to_next_field);
        }

        fn op_isnt_ever_used(comptime OP_KIND: DataOpKind) bool {
            return comptime !OP_USED[@intFromEnum(OP_KIND)];
        }

        fn serialize_internal(self: *Self, object: anytype, comptime DIR: SERDIR, comptime SER: ReadWrite.SerialKind, native: [*]u8, native_size: usize, serial: DIR.serial_type(), allocs: [NUM_ALLOCS]Allocator, external: ?*anyopaque) DIR.error_type()!usize {
            const T = @TypeOf(object);
            const UNIQUE = comptime find: {
                for (ROOT_TYPES[0..]) |root| {
                    if (root.object_type == T) break :find root;
                }
                assert_unreachable(@src(), "type `{s}` was not provided as one of the 'main' types to serialize. If you want to serialize this type, include it in the `MAIN_TYPES_FOR_SERIALIZATION` parameter during `SerializationManager` type definition", .{@typeName(T)});
            };
            self.reset();
            self.push_routine_frame_from_unique(UNIQUE, 1, 0, true);
            self.push_mem_region_frame(native, native_size);
            var byte_count: usize = 0;
            serial_loop: while (true) {
                if (self.curr_routine.routine_idx >= self.curr_routine.routine_end) {
                    if (self.curr_routine.pop_mem_region_after_complete) {
                        self.pop_mem_region_frame();
                    }
                    self.routine_stack_len -= 1;
                    if (self.routine_stack_len == 0) break :serial_loop;
                    self.curr_routine = &self.routine_stack_ptr[self.routine_stack_len - 1];
                }
                const op = OPS[self.curr_routine.routine_idx];
                const kind = op.GENERIC.kind;
                switch (kind) {
                    .ADD_NATIVE_OFFSET => {
                        if (op_isnt_ever_used(.ADD_NATIVE_OFFSET)) unreachable;
                        const delta = op.ADD_NATIVE_OFFSET.offset;
                        self.curr_region.move_ptr(delta);
                        self.curr_routine.routine_idx += 1;
                    },
                    .ALLOCATED_POINTER_DYNAMIC_LEN => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_DYNAMIC_LEN)) unreachable;
                        const data = op.POINTER;
                        self.handle_alloc_pointer(DIR, data, true, false);
                    },
                    .ALLOCATED_POINTER_DYNAMIC_LEN_OR_NULL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_DYNAMIC_LEN_OR_NULL)) unreachable;
                        const data = op.POINTER;
                        self.handle_alloc_pointer(DIR, data, true, true);
                    },
                    .ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL)) unreachable;
                        @panic("unimplemented");
                    },
                    .ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL_OR_NULL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_DYNAMIC_LEN_WITH_SENTINEL_OR_NULL)) unreachable;
                        @panic("unimplemented");
                    },
                    .ALLOCATED_POINTER_STATIC_LEN => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_STATIC_LEN)) unreachable;
                        const data = op.POINTER;
                        self.handle_alloc_pointer(DIR, data, false, false);
                    },
                    .ALLOCATED_POINTER_STATIC_LEN_OR_NULL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_STATIC_LEN_OR_NULL)) unreachable;
                        const data = op.POINTER;
                        self.handle_alloc_pointer(DIR, data, false, true);
                    },
                    .ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL)) unreachable;
                        @panic("unimplemented");
                    },
                    .ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL_OR_NULL => {
                        if (op_isnt_ever_used(.ALLOCATED_POINTER_STATIC_LEN_WITH_SENTINEL_OR_NULL)) unreachable;
                        @panic("unimplemented");
                    },
                    .DATA_MANIPULATION_NATIVE_TO_SERIAL => {
                        if (op_isnt_ever_used(.DATA_MANIPULATION_NATIVE_TO_SERIAL)) unreachable;
                        if (DIR == .NATIVE_TO_SERIAL) {
                            const data = op.DATA_MANIP_NATIVE_TO_SERIAL;
                            var cloned_region = self.curr_region.*;
                            cloned_region.move_ptr(data.offset_to_object_addr);
                            data.func(@ptrCast(cloned_region.native_ptr), external);
                        }
                    },
                    .DATA_MANIPULATION_SERIAL_TO_NATIVE => {
                        if (op_isnt_ever_used(.DATA_MANIPULATION_SERIAL_TO_NATIVE)) unreachable;
                        if (DIR == .SERIAL_TO_NATIVE) {
                            const data = op.DATA_MANIP_SERIAL_TO_NATIVE;
                            var cloned_region = self.curr_region.*;
                            cloned_region.move_ptr(data.offset_to_object_addr);
                            data.func(@ptrCast(cloned_region.native_ptr), external);
                        }
                    },
                    .FULL_CUSTOM_FUNCTION => {
                        if (op_isnt_ever_used(.FULL_CUSTOM_FUNCTION)) unreachable;
                        const data = op.FULL_CUSTOM_FUNCTION;
                        var cloned_region = self.curr_region.*;
                        cloned_region.move_ptr_backward(data.get_neg_offset_to_object_addr());
                        switch (DIR) {
                            .NATIVE_TO_SERIAL => {
                                const bytes_written = try data.funcs.write_to_serial(@ptrCast(cloned_region.native_ptr), serial);
                                byte_count += bytes_written;
                            },
                            .SERIAL_TO_NATIVE => {
                                const bytes_read = try data.funcs.write_to_serial(@ptrCast(cloned_region.native_ptr), serial);
                                byte_count += bytes_read;
                            },
                        }
                    },
                    .NON_ZERO_READ_OR_WRITE_1_ELSE_0 => {
                        if (op_isnt_ever_used(.NON_ZERO_READ_OR_WRITE_1_ELSE_0)) unreachable;
                        const data = op.DATA_TRANSFER;
                        self.handle_non_zero_read_write_1_else_0(DIR, SER, .DONT_CACHE_DATA, data, serial);
                    },
                    .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_LEN => {
                        if (op_isnt_ever_used(.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_LEN)) unreachable;
                        const data = op.DATA_TRANSFER;
                        self.handle_non_zero_read_write_1_else_0(DIR, SER, .CACHE_LEN, data, serial);
                    },
                    .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_NULL => {
                        if (op_isnt_ever_used(.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_NULL)) unreachable;
                        const data = op.DATA_TRANSFER;
                        self.handle_non_zero_read_write_1_else_0(DIR, SER, .CACHE_NULL, data, serial);
                    },
                    .NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG => {
                        if (op_isnt_ever_used(.NON_ZERO_READ_OR_WRITE_1_ELSE_0_SAVE_TAG)) unreachable;
                        const data = op.DATA_TRANSFER;
                        self.handle_non_zero_read_write_1_else_0(DIR, SER, .CACHE_TAG, data, serial);
                    },
                    .POINTER_SENTINEL => {
                        if (op_isnt_ever_used(.POINTER_SENTINEL)) unreachable;
                        const data = op.SENTINEL;
                        const sentinel_bytes_ptr: [*]const u8 = @ptrCast(data.sentinel_data);
                        const sentinel_bytes = sentinel_bytes_ptr[0..data.elem_size];
                        const native_bytes = self.curr_region.native_ptr[0..data.elem_size];
                        @memcpy(native_bytes, sentinel_bytes);
                        self.curr_routine.routine_idx += 1;
                    },
                    .REF_UNIQUE_TYPE => {
                        if (op_isnt_ever_used(.REF_UNIQUE_TYPE)) unreachable;
                        const ref = op.REF_UNIQUE_TYPE_SUBRS;
                        self.push_routine_frame_from_unique_ref(ref, num_repeat: bool, pop_region_after: bool)
                        //CHECKPOINT something is wrong here... I need a repeat count from static or dynamic len, but `RefUniqueTypeSubroutine` has neither
                    },
                }
            }
        }
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
        var alloc_name_list: [32]SliceRange = undefined;
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
