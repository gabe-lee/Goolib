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
pub const CustomComptimeRoutineOpsBuilder = fn (comptime SETTINGS: ObjectSerialSettings, comptime OP_MANAGER: *DataOpManagerHighLevel) u32;

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
    ALLOC_NAME_BYTES_BUFFER_MAX_LEN: u32 = 512,
    ALLOC_NAME_LIST_MAX_LEN: u32 = 64,
    // subroutine_stack_len: u32 = 128,
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
    TRANSFER_SWAP_ENDIAN,
    TRANSFER_SWAP_ENDIAN_SAVE_TAG,
    TRANSFER_SWAP_ENDIAN_SAVE_LEN,
    TRANSFER_VARINT,
    TRANSFER_VARINT_SAVE_TAG,
    TRANSFER_VARINT_SAVE_LEN,
    TRANSFER_VARINT_ZIGZAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_TAG,
    TRANSFER_VARINT_ZIGZAG_SAVE_LEN,
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
    UNION_TAG_RANGE_ONE_FOLLOWING,
    UNION_TAG_RANGE_TWO_FOLLOWING,
    // Pointer Control
    ALLOCATED_POINTER_STATIC_LEN,
    ALLOCATED_POINTER_DYNAMIC_LEN,
    POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN,
    POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN,
    // Custom
    FULL_CUSTOM_FUNCTION,
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
    // Custom
    FULL_CUSTOM_FUNCTION: CustomFunctions,

    pub fn get_kind(self: DataOp) DataOpKind {
        return self.GENERIC.kind;
    }

    pub fn new_add_native_offset_op(comptime offset: i32) DataOp {
        return DataOp{ .ADD_NATIVE_OFFSET = AddNativeOffset{ .offset = offset } };
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

    pub fn new_union_tag_id_op(comptime tag_as_u64_native_endian: u64, comptime num_following_commands: u8) DataOp {
        switch (num_following_commands) {
            1 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_ONE_FOLLOWING } },
            2 => return DataOp{ .UNION_TAG_ID = UnionTagId{ .tag_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_as_u64_native_endian) else tag_as_u64_native_endian, .kind = .UNION_TAG_ID_TWO_FOLLOWING } },
            else => assert_unreachable(@src(), "only union tags with 1 or 2 following commands are supported, got `{d}`", .{num_following_commands}),
        }
    }

    pub fn new_union_tag_range_op(comptime tag_min_as_u64_native_endian: u64, comptime tag_max_as_u64_native_endian: u64, comptime num_following_commands) DataOp {
        var range = UnionTagRange{
            .max_as_u64_le = if (NATIVE_ENDIAN != .LITTLE_ENDIAN) @byteSwap(tag_max_as_u64_native_endian) else tag_max_as_u64_native_endian,
        };
        range.set_min_native_endian(tag_min_as_u64_native_endian);
        switch (num_following_commands) {
            1 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_ONE_FOLLOWING },
            2 => DataOp{ .UNION_TAG_RANGE = range, .kind = .UNION_TAG_RANGE_TWO_FOLLOWING },
            else => assert_unreachable(@src(), "only union tag ranges with 1 or 2 following commands are supported, got `{d}`", .{num_following_commands}),
        }
    }

    pub fn new_subroutine_op(comptime subroutine_first_op: u32, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .START_SUBROUTINE_NO_REPEAT_CURRENT_REGION, .START_SUBROUTINE_NO_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_STATIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_CURRENT_REGION, .START_SUBROUTINE_STATIC_REPEAT_ALLOCATED_REGION, .START_SUBROUTINE_DYNAMIC_REPEAT_ALLOCATED_REGION => {},
            else => assert_unreachable(@src(), "cannot create a `SubroutineStart` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .SUBROUTINE = SubroutineStart{ .subroutine_first_op = subroutine_first_op, .subroutine_num_ops = subroutine_num_ops, .subroutine_static_repeat = subroutine_static_repeat, .offset_to_next_field = offset_to_next_field, .kind = kind } };
    }

    pub fn new_ref_unique_subrs_op(comptime unique_type_index: u32, comptime offset_to_next_field: i32) DataOp {
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

    pub fn new_previous_allocation_ref_op(comptime elem_size: u32, comptime static_len: u32, comptime offset_to_next_field: i32, comptime kind: DataOpKind) DataOp {
        switch (kind) {
            .POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN, .POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN => {},
            else => assert_unreachable(@src(), "cannot create a `PreviousAllocationReference` op with kind `{s}`", .{@tagName(kind)}),
        }
        return DataOp{ .Pointer = Pointer{ .elem_size = elem_size, .static_len = static_len, .offset_to_next_field = offset_to_next_field, .kind = kind } };
    }

    pub fn new_custom_functions_op(comptime funcs: *const CustomRuntimeSerializeFuncs, comptime offset_to_next_field: i32) DataOp {
        return DataOp{ .FULL_CUSTOM_FUNCTION = CustomFunctions{ .funcs = funcs, .offset_to_next_field = offset_to_next_field } };
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


const CustomFunctions = extern struct {
    /// A pair of serialize and deserialize functions
    /// that are called in place on DataOp bytecode. When
    /// an object defines these, it must handle ANY AND ALL serialization
    /// of all children as well.
    funcs: *const CustomRuntimeSerializeFuncs = undefined,
    offset_to_next_field: i32 = 0,
    __padding: [11 - @sizeOf(usize)]u8 = @splat(0),
    /// The kind tag, used both for determining the union field, and how to handle
    /// union fields with multiple modes
    kind: DataOpKind = .FULL_CUSTOM_FUNCTION,
};

const UniqueSerialType = struct {
    object_type: type,
    object_settings: ObjectSerialSettings,
    routine_start: u32 = 0,
    routine_end: u32 = 0,
    routine_made: bool = false,
    usage_refs: u32 = 0,

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
};

pub const DataOpBuilderLowLevel = struct {
    current_type: type,
    current_kind: Kind,
    current_settings: ObjectSerialSettings,
    unique_types: []const UniqueSerialType,
    ops: []DataOp = &.{},
    ops_len: u32 = 0,
    alloc_buf: []u8 = &.{},
    alloc_buf_len: u32 = 0,
    alloc_names: []SliceRange = &.{},
    alloc_names_len: u32 = 0,
    // subroutine_max_len_to_inline: u8 = 1,

    fn new(comptime current_type: type, comptime current_settings: ObjectSerialSettings, comptime uniques: []const UniqueSerialType, comptime ops: []DataOp) DataOpBuilderLowLevel {
        return DataOpBuilderLowLevel{
            .current_type = current_type,
            .current_kind = Kind.get_kind(current_type),
            .current_settings = current_settings,
            .unique_types = uniques,
            .ops = unused_ops,
        };
    }


    fn assert_ops_space(comptime self: *DataOpBuilderLowLevel, comptime n: u32, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self.ops_len + n <= self.ops.len, src, "ran out of space in ops buffer, need at least len {d}, have len {d}, provide a larger `OP_BUFFER_MAX_LEN` during SerialManager initialization", .{ self.ops_len + n, self.ops.len });
    }

    fn push_op(comptime self: *DataOpBuilderLowLevel, comptime op: DataOp) void {
        self.ops[self.ops_len] = op;
        self.ops_len += 1;
    }

    pub fn add_add_native_offset_op(comptime self: *DataOpBuilderLowLevel, comptime offset: i32) void {
        self.assert_ops_space(1, @src());
        const op = DataOp.new_add_native_offset_op(offset);
        self.push_op(op);
    }

    pub fn add_transfer_data_op(comptime self: *DataOpBuilderLowLevel, comptime native_size: u32, comptime offset_to_next_field: i32, comptime serial_size: u32, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech, comptime CACHE: DataCacheMode) void {
        self.assert_ops_space(1, @src());
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
        self.push_op(op);
    }

    pub fn add_union_header_op(comptime self: *DataOpBuilderLowLevel, comptime num_fields: u32) void {
        self.assert_ops_space(1, @src());
        const op = DataOp.new_union_header_op(num_fields);
        self.push_op(op);
    }

    pub fn add_union_tag_op(comptime self: *DataOpBuilderLowLevel, comptime tag_as_u64_native_endian: u64, comptime num_following_ops: u32) void {
        self.assert_ops_space(1, @src());
        const op = DataOp.new_union_tag_id_op(tag_as_u64_native_endian, num_following_ops);
        self.push_op(op);
    }

    pub fn add_union_range_op(comptime self: *DataOpBuilderLowLevel, comptime min_as_u64_native_endian: u64, comptime max_as_u64_native_endian: u64, comptime num_following_ops: u32) void {
        self.assert_ops_space(1, @src());
        const op = DataOp.new_union_tag_range_op(min_as_u64_native_endian, max_as_u64_native_endian, num_following_ops);
        self.push_op(op);
    }

    pub fn add_subroutine_start_op(comptime self: *DataOpBuilderLowLevel, comptime subroutine_first_op: u32, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime REPEAT: SubroutineRepeatMode, comptime REGION: SubroutineAllocRegionMode) void {
        self.assert_ops_space(1, @src());
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
        self.push_op(op);
    }

    pub fn add_inline_subroutine_start_op(comptime self: *DataOpBuilderLowLevel, comptime subroutine_num_ops: u16, comptime subroutine_static_repeat: u32, comptime offset_to_next_field: i32, comptime REPEAT: SubroutineRepeatMode, comptime REGION: SubroutineAllocRegionMode) void {
        self.assert_ops_space(1, @src());
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
        self.push_op(op);
    }

    pub fn add_ref_unique_type_op(comptime self: *DataOpBuilderLowLevel, comptime unique_type_idx: u32, comptime offset_to_next_field: i32) void {
        // VERIFY I might be able to inline referenced ops if they are already defined?
        // const unique = self.unique_types[unique_type_idx];
        // if (unique.routine_made and (unique.routine_end - unique.routine_start < self.subroutine_max_len_to_inline)) {
        //     for (self.all_ops[unique.routine_start..unique.routine_end]) |inline_op| {
        //         self.push_op(inline_op);
        //     }
        // } else {
        //     const op = DataOp.new_ref_unique_subrs_op(unique_type_idx, offset_to_next_field);
        //     self.push_op(op);
        // }
        self.assert_ops_space(1, @src());
        const op = DataOp.new_ref_unique_subrs_op(unique_type_idx, offset_to_next_field);
        self.push_op(op);
    }

    pub fn add_allocated_pointer_op(comptime self: *DataOpBuilderLowLevel, comptime elem_size: u32, comptime ptr_align: u32, alloc_idx: u16, comptime static_len: u32, comptime offset_to_next_field: i32, comptime LEN_MODE: PointerLenMode) void {
        self.assert_ops_space(1, @src());
        const kind: DataOpKind = switch (LEN_MODE) {
            .STATIC_LEN_POINTER => DataOpKind.ALLOCATED_POINTER_STATIC_LEN,
            .DYNAMIC_LEN_POINTER => DataOpKind.ALLOCATED_POINTER_DYNAMIC_LEN,
        };
        const op = DataOp.new_allocated_pointer_op(elem_size, ptr_align, alloc_idx, static_len, offset_to_next_field, kind);
        self.push_op(op);
    }

    pub fn add_prev_allocation_ref_pointer_op(comptime self: *DataOpBuilderLowLevel, comptime elem_size: u32, comptime ptr_align: u32, alloc_idx: u16, comptime static_len: u32, comptime offset_to_next_field: i32, comptime LEN_MODE: PointerLenMode) void {
        self.assert_ops_space(1, @src());
        const kind: DataOpKind = switch (LEN_MODE) {
            .STATIC_LEN_POINTER => DataOpKind.POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_STATIC_LEN,
            .DYNAMIC_LEN_POINTER => DataOpKind.POINTER_TO_PREVIOUSLY_ALLOCATED_REGION_DYNAMIC_LEN,
        };
        const op = DataOp.new_previous_allocation_ref_op(elem_size, ptr_align, alloc_idx, static_len, offset_to_next_field, kind);
        self.push_op(op);
    }

    pub fn add_custom_functions_op(comptime self: *DataOpBuilderLowLevel, comptime funcs: *const CustomRuntimeSerializeFuncs, comptime offset_to_next_field: i32) void {
        self.assert_ops_space(1, @src());
        const op = DataOp.new_custom_functions_op(funcs, offset_to_next_field);
        self.push_op(op);
    }

    // UTILS

    pub fn locate_unique_type_idx(comptime self: *DataOpBuilderLowLevel, comptime TYPE: type, comptime SETTINGS: ObjectSerialSettings) u32 {
        for (self.unique_types, 0..) |unique_type, i| {
            if (unique_type.object_type == TYPE and unique_type.object_settings.equals(SETTINGS)) return num_cast(i, u32);
        }
        assert_unreachable(@src(), "did not find unique object index for 'type + settings' pair.\nThe likely cause is that during the initial evaluation pass a type was saved with a number of unique `ObjectSerialSettings`,\nbut inside a `CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE` provided by the user, the settings provided to locate the unique pair didn't match any recorded pair:\n\nTYPE: {s}\n\nSETTINGS: {any}", .{ @typeName(TYPE), SETTINGS });
    }

    pub fn get_offset_between_two_fields(comptime self: *DataOpBuilderLowLevel, comptime START_FIELD: ?[]const u8, comptime END_FIELD: ?[]const u8) i32 {
        const start_offset: u32 = if (START_FIELD) |SF| get: {
            assert_with_reason(@hasField(self.current_type, SF), @src(), "current type `{s}` does not have field `{s}`", .{ @typeName(self.current_type), SF });
            break :get @offsetOf(self.current_type, SF);
        } else 0;
        const end_offset: u32 = if (END_FIELD) |EF| get: {
            assert_with_reason(@hasField(self.current_type, EF), @src(), "current type `{s}` does not have field `{s}`", .{ @typeName(self.current_type), EF });
            break :get @offsetOf(self.current_type, EF);
        } else 0;
        if (start_offset > end_offset) {
            return -num_cast(start_offset - end_offset, i32);
        } else {
            return num_cast(end_offset - start_offset, i32);
        }
    }

    pub fn get_final_settings_for_value(comptime self: *DataOpBuilderLowLevel, comptime TYPE: ?type, comptime FIELD: ?[]const u8) ObjectSerialSettings {
        const REAL_TYPE = if (TYPE) |T| T else get: {
            assert_with_reason(self.current_kind == .STRUCT and FIELD != null, @src(), "if `TYPE` is not provided, the current (parent) type must be a stuct and `FIELD` must not be null, got parent kind `{s}`, field `{any}`", .{ @tagName(self.current_kind), FIELD });
            break :get @FieldType(self.current_type, FIELD.?);
        };
        const FIELD_SETTINGS: ?OptionalObjectSerialSettings = if (FIELD != null) get: {
            assert_with_reason(self.current_kind == .STRUCT, @src(), "if `FIELD` is provided, the current (parent) type must be a stuct, got parent kind `{s}`", .{@tagName(self.current_kind)});
            const F_TYPE = @FieldType(self.current_type, FIELD.?);
            assert_with_reason(REAL_TYPE == F_TYPE, @src(), "the type provided does not match the type on field `{s}`, got:\nTYPE = `{s}`\ntype from FIELD = `{s}`", .{ FIELD.?, @typeName(REAL_TYPE), @typeName(F_TYPE) });
            break :get get_field_settings(self.current_type, FIELD.?);
        } else null;
        const OBJECT_SETTINGS = get_object_settings(REAL_TYPE);
        return self.current_settings.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
    }

    pub fn get_tech_for_numeric_type(comptime _: *DataOpBuilderLowLevel, comptime SETTINGS: ObjectSerialSettings, comptime TYPE: type) DataTransferTech {
        const KIND_INFO = KindInfo.get_kind_info(TYPE);
        const TECH = if (@sizeOf(TYPE) <= 1) DataTransferTech.TARGET_ENDIAN_SAME_SIZE else switch (KIND_INFO) {
            .INT, .ENUM, .BOOL, .STRUCT => switch (SETTINGS.INTEGER_PACKING) {
                .USE_TARGET_ENDIAN => DataTransferTech.TARGET_ENDIAN_SAME_SIZE,
                .USE_VARINTS => switch (KIND_INFO) {
                    .INT => |INT| if (INT.signedness == .signed) DataTransferTech.VARINT_ZIGZAG else DataTransferTech.VARINT,
                    .ENUM, .BOOL, .STRUCT => DataTransferTech.VARINT,
                    else => unreachable,
                },
            },
            .FLOAT => DataTransferTech.TARGET_ENDIAN_SAME_SIZE,
            else => assert_unreachable(@src(), "only Ints, Floats, Bools, Enums, or Packed Structs are allowed as numeric field ops, got type `{s}`", .{@typeName(TYPE)}),
        };
        return TECH;
    }

    pub fn get_numeric_elem_type_and_total_len_for_numeric_array_type(comptime _: *DataOpBuilderLowLevel, comptime TYPE: type) struct { type, u32 } {
        const KIND_INFO = KindInfo.get_kind_info(TYPE);
        comptime var CHILD_TYPE: type = undefined;
        comptime var AT_LEAST_ONE_DEEP: bool = false;
        comptime var TOTAL_LEN: u32 = 1;
        find_deeper_element: switch (KIND_INFO) {
            .INT, .ENUM, .BOOL, .STRUCT, .UNION, .FLOAT => {},
            .ARRAY => |ARRAY| {
                AT_LEAST_ONE_DEEP = true;
                TOTAL_LEN *= ARRAY.len;
                const CHILD_KIND = KindInfo.get_kind_info(ARRAY.child);
                CHILD_TYPE = ARRAY.child;
                continue :find_deeper_element CHILD_KIND;
            },
            .VECTOR => |VECTOR| {
                AT_LEAST_ONE_DEEP = true;
                TOTAL_LEN *= VECTOR.len;
                const CHILD_KIND = KindInfo.get_kind_info(VECTOR.child);
                CHILD_TYPE = VECTOR.child;
                continue :find_deeper_element CHILD_KIND;
            },
            else => assert_unreachable(@src(), "only Ints, Floats, Bools, Enums, Packed Structs, or Packed Unions are allowed as child elements of numeric array field ops, got type `{s}`", .{@typeName(CHILD_TYPE)}),
        }
        assert_with_reason(AT_LEAST_ONE_DEEP, @src(), "top-level type was not an Array or Vector, got type `{s}`", .{@typeName(TYPE)});
        return .{ CHILD_TYPE, TOTAL_LEN };
    }

    pub fn re_type_numeric_type(comptime self: *DataOpBuilderLowLevel, comptime IN_TYPE: type) type {
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
            else => assert_with_reason(UNION.layout == .@"extern", @src(), "only Ints, Floats, Bools, Enums, Packed Structs, or Packed Unions can be re-typed as numeric types, got type `{s}`", .{@typeName(IN_TYPE)}),
        }
    }

    pub fn goto_next_field_if_this_type_size_0(comptime self: *DataOpBuilderLowLevel, comptime TYPE: type, comptime OFFSET_TO_NEXT_FIELD: i32) bool {
        if (@sizeOf(TYPE) == 0) {
            if (OFFSET_TO_NEXT_FIELD != 0) {
                self.add_add_native_offset_op(OFFSET_TO_NEXT_FIELD);
            }
            return true;
        }
        return false;
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
};

pub const NO_FIELD_CACHE = "<cached but no field>";

pub const DataOpBuilderStruct = struct {
    low_level: DataOpBuilderLowLevel,
    prev_field: ?[]const u8 = null,
    next_field: ?[]const u8 = null,
    cached_tag_field: ?[]const u8 = null,
    cached_len_field: ?[]const u8 = null,
    union_fields_needed: u32 = 0,
    union_fields_added: u32 = 0,

    fn new(comptime current_type: type, comptime current_settings: ObjectSerialSettings, comptime uniques: []const UniqueSerialType, comptime used_ops: []const DataOp, comptime unused_ops: []DataOp) DataOpBuilderStruct {
        return DataOpBuilderStruct{
            .low_level = DataOpBuilderLowLevel.new(current_type, current_settings, uniques, used_ops, unused_ops),
        };
    }

    fn assert_ops_space(comptime self: *DataOpBuilderStruct, comptime n: u32, comptime src: std.builtin.SourceLocation) void {
        self.low_level.assert_ops_space(n, src);
    }

    fn push_op(comptime self: *DataOpBuilderStruct, comptime op: DataOp) void {
        self.low_level.push_op(op);
    }

    // FIXME This needs to be re-worked
    // pub fn add_normal_routine_for_field(comptime self: *DataOpBuilderStruct, comptime FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8) void {
    //     assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
    //     if (NEXT_FIELD) |NEXT| assert_with_reason(@hasField(self.low_level.current_type, NEXT), @src(), "struct `{s}` does not have NEXT field `{s}`", .{ @typeName(self.low_level.current_type), NEXT });
    //     if (self.prev_field != null) assert_with_reason(self.next_field != null and std.mem.eql(u8, self.next_field.?, FIELD), @src(), "the prev field you added indicated the next field to add was `{s}`, but the next field you actually added was `{s}`: routine offsets will be broken", .{ if (self.next_field) |next| next else "<void, end struct>", FIELD });
    //     const TYPE = @FieldType(self.low_level.current_type, FIELD);
    //     if (self.prev_field == null and @offsetOf(self.low_level.current_type, FIELD) != 0) {
    //         self.low_level.add_add_native_offset_op(@offsetOf(self.low_level.current_type, FIELD));
    //     }
    //     self.prev_field = FIELD;
    //     self.next_field = NEXT_FIELD;
    //     const offset_to_next_field = self.low_level.get_offset_between_two_fields(FIELD, NEXT_FIELD);
    //     const SETTINGS = self.low_level.get_settings_for_sub_type(FIELD, TYPE);
    //     const UNIQUE_IDX = self.low_level.locate_unique_type_idx(TYPE, SETTINGS);
    //     self.low_level.add_ref_unique_type_op(UNIQUE_IDX, offset_to_next_field);
    // }

    /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
    /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    fn _internal_add_numeric_field_with_custom_settings(comptime self: *DataOpBuilderStruct, comptime TYPE: type, comptime TYPE_FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32, comptime TARGET_ENDIAN: Endian, comptime CACHE_DATA: DataCacheMode, comptime TECH: DataTransferTech) void {
        if (self.low_level.goto_next_field_if_this_type_size_0(TYPE, OFFSET_TO_NEXT_VALUE)) {
            return;
        }
        switch (CACHE_DATA) {
            .DONT_CACHE_DATA => {},
            .CACHE_LEN => {
                self.cached_len_field = if (TYPE_FIELD) |F| F else NO_FIELD_CACHE;
            },
            .CACHE_TAG => {
                self.cached_tag_field = if (TYPE_FIELD) |F| F else NO_FIELD_CACHE;
            },
        }
        const INFO = KindInfo.get_kind_info(TYPE);
        const NUMERIC_TYPE = self.low_level.re_type_numeric_type(TYPE);
        const SER_SIZE = if (TECH != .TARGET_ENDIAN_SAME_SIZE) 0 else @sizeOf(TYPE);
        self.low_level.add_transfer_data_op(@sizeOf(TYPE), OFFSET_TO_NEXT_VALUE, SER_SIZE, TARGET_ENDIAN, TECH, CACHE_DATA);
    }

    /// This uses the current settings on the parent struct (if any) and fields settings (if any) for the field to add a data transfer op
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    fn _internal_add_numeric_field(comptime self: *DataOpBuilderStruct, comptime TYPE: type, comptime TYPE_FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32) void {
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, TYPE_FIELD);
        const TECH = self.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
        const ENDIAN = SETTINGS.TARGET_ENDIAN;
        return self._internal_add_numeric_field_with_custom_settings(TYPE, TYPE_FIELD, OFFSET_TO_NEXT_VALUE, ENDIAN, .DONT_CACHE_DATA, TECH);
    }

    /// This uses the current settings on the parent struct (if any) and fields settings (if any) for the field to add a data transfer op
    ///
    /// Allows optional caching of data transfered
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    fn _internal_add_numeric_field_cache_data(comptime self: *DataOpBuilderStruct, comptime TYPE: type, comptime TYPE_FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32, comptime CACHE: DataCacheMode) void {
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, TYPE_FIELD);
        const TECH = self.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
        const ENDIAN = SETTINGS.TARGET_ENDIAN;
        return self._internal_add_numeric_field_with_custom_settings(TYPE, TYPE_FIELD, OFFSET_TO_NEXT_VALUE, ENDIAN, CACHE, TECH);
    }

    /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
    /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    pub fn add_numeric_field_with_custom_settings(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime TARGET_ENDIAN: Endian, comptime CACHE_DATA: DataCacheMode, comptime TECH: DataTransferTech) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        if (NEXT_FIELD) |NEXT| assert_with_reason(@hasField(self.low_level.current_type, NEXT), @src(), "struct `{s}` does not have NEXT field `{s}`", .{ @typeName(self.low_level.current_type), NEXT });
        if (self.prev_field != null) assert_with_reason(self.next_field != null and std.mem.eql(u8, self.next_field.?, FIELD), @src(), "the prev field you added indicated the next field to add was `{s}`, but the next field you actually added was `{s}`: routine offsets will be broken", .{ if (self.next_field) |next| next else "<void, end struct>", FIELD });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        if (self.prev_field == null and @offsetOf(self.low_level.current_type, FIELD) != 0) {
            self.low_level.add_add_native_offset_op(@offsetOf(self.low_level.current_type, FIELD));
        }
        self.prev_field = FIELD;
        self.next_field = NEXT_FIELD;
        const offset_to_next_field = self.low_level.get_offset_between_two_fields(FIELD, NEXT_FIELD);
        self._internal_add_numeric_field_with_custom_settings(TYPE, FIELD, offset_to_next_field, TARGET_ENDIAN, CACHE_DATA, TECH);
    }

    /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
    /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    fn _internal_add_numeric_array_field_with_custom_settings(comptime self: *DataOpBuilderStruct, comptime TYPE: type, comptime TYPE_FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech) void {
        if (self.low_level.goto_next_field_if_this_type_size_0(TYPE, OFFSET_TO_NEXT_VALUE)) {
            return;
        }
        const FINAL_ELEMENT_TYPE: type, const TOTAL_LEN: u32 = self.low_level.get_numeric_elem_type_and_total_len_for_numeric_array_type(TYPE);
        const FINAL_ELEMENT_SIZE = @sizeOf(FINAL_ELEMENT_TYPE);
        if (FINAL_ELEMENT_SIZE == 1) {
            self.low_level.add_transfer_data_op(TOTAL_LEN, OFFSET_TO_NEXT_VALUE, TOTAL_LEN, TARGET_ENDIAN, .TARGET_ENDIAN_SAME_SIZE, .DONT_CACHE_DATA);
        } else {
            self.low_level.add_inline_subroutine_start_op(1, TOTAL_LEN, OFFSET_TO_NEXT_VALUE, .STATIC_REPEAT_OR_NO_REPEAT, .SAME_MEMORY_REGION);
            const PER_ELEMENT_OFFSET: i32 = num_cast(@sizeOf(FINAL_ELEMENT_TYPE), i32);
            const NUMERIC_TYPE = self.low_level.re_type_numeric_type(FINAL_ELEMENT_TYPE);
            const SER_SIZE = if (TECH != .TARGET_ENDIAN_SAME_SIZE) 0 else @sizeOf(NUMERIC_TYPE);
            self.low_level.add_transfer_data_op(@sizeOf(NUMERIC_TYPE), PER_ELEMENT_OFFSET, SER_SIZE, TARGET_ENDIAN, TECH, .DONT_CACHE_DATA);
        }
    }

    /// This uses the current settings on the parent struct (if any) and fields settings (if any) for the field to add a data transfer op
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    fn _internal_add_numeric_array_field(comptime self: *DataOpBuilderStruct, comptime TYPE: type, comptime TYPE_FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32) void {
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, TYPE_FIELD);
        const TECH = self.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
        const ENDIAN = SETTINGS.TARGET_ENDIAN;
        return self._internal_add_numeric_array_field_with_custom_settings(TYPE, TYPE_FIELD, OFFSET_TO_NEXT_VALUE, ENDIAN, .DONT_CACHE_DATA, TECH);
    }

    /// This uses the current settings on the parent struct and fields settings for the field to add a data transfer op
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    pub fn add_numeric_field(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, FIELD);
        const TECH = self.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
        self.add_numeric_field_with_custom_settings(FIELD, NEXT_FIELD, SETTINGS.TARGET_ENDIAN, .DONT_CACHE_DATA, TECH);
    }

    /// This uses the current settings on the parent struct and fields settings for the field to add a data transfer op
    ///
    /// Allows optional caching of data transfered
    ///
    /// Valid field types are:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    pub fn add_numeric_field_and_cache_data(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime CACHE: DataCacheMode) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, FIELD);
        const TECH = self.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
        self.add_numeric_field_with_custom_settings(FIELD, NEXT_FIELD, SETTINGS.TARGET_ENDIAN, CACHE, TECH);
    }

    /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
    /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
    ///
    /// Valid field types are either an Array, Vector,
    /// or any level of nested Arrays and/or Vectors where the final child type is one of:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    pub fn add_numeric_array_field_with_custom_settings(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        if (NEXT_FIELD) |NEXT| assert_with_reason(@hasField(self.low_level.current_type, NEXT), @src(), "struct `{s}` does not have NEXT field `{s}`", .{ @typeName(self.low_level.current_type), NEXT });
        if (self.prev_field != null) assert_with_reason(self.next_field != null and std.mem.eql(u8, self.next_field.?, FIELD), @src(), "the prev field you added indicated the next field to add was `{s}`, but the next field you actually added was `{s}`: routine offsets will be broken", .{ if (self.next_field) |next| next else "<void, end struct>", FIELD });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        if (self.prev_field == null and @offsetOf(self.low_level.current_type, FIELD) != 0) {
            self.low_level.add_add_native_offset_op(@offsetOf(self.low_level.current_type, FIELD));
        }
        self.prev_field = FIELD;
        self.next_field = NEXT_FIELD;
        const offset_to_next_field = self.low_level.get_offset_between_two_fields(FIELD, NEXT_FIELD);
        self._internal_add_numeric_array_field_with_custom_settings(TYPE, FIELD, offset_to_next_field, TARGET_ENDIAN, TECH);
    }

    /// This uses the current settings on the parent struct and fields settings for the field to add a data transfer op
    ///
    /// Valid field types are either an Array, Vector,
    /// or any level of nested Arrays and/or Vectors where the final child type is one of:
    ///   - Integers
    ///   - Bools
    ///   - Enums
    ///   - Floats
    ///   - Packed Structs
    ///   - Packed Unions
    pub fn add_numeric_array_field(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, FIELD);
        const TECH = self.low_level.get_tech_for_numeric_array_type(SETTINGS, TYPE);
        self.add_numeric_array_field_with_custom_settings(FIELD, NEXT_FIELD, SETTINGS.TARGET_ENDIAN, TECH);
    }

    /// Build an extern union subroutine using a tag cached by a previous data transfer op. Note the input parameters:
    ///   - `CACHED_TAG_FIELD` = the field name that was previously cached MUST MATCH the one recorded
    ///   - `TAG_TYPE` = an Enum or Integer type that is used to choose the active union field.
    ///     - These do not necessarily need to correlate 1-to-1 with the union fields,
    /// the builder is responsible for correctly filling in the union data based on tag values
    pub fn start_extern_union_builder_with_cached_tag(comptime self: *DataOpBuilderStruct, comptime CACHED_TAG_FIELD: []const u8, comptime TAG_TYPE: type, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8) DataOpBuilderExternUnion(TAG_TYPE) {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        assert_with_reason(self.cached_tag_field != null and std.mem.eql(u8, self.cached_tag_field.?, CACHED_TAG_FIELD), @src(), "intended field for cached tag: `{s}` is not the one that is recorded as being cached: `{s}`", .{ CACHED_TAG_FIELD, if (self.cached_tag_field) |c| c else "<no tag field cached>" });
        const TYPE = @FieldType(self.low_level.current_type, FIELD);
        const SETTINGS = self.low_level.get_final_settings_for_value(TYPE, FIELD);
        const KIND = KindInfo.get_kind_info(TYPE);
        assert_with_reason(KIND == .UNION and KIND.UNION.tag_type == null and KIND.UNION.layout == .@"extern", @src(), "type of `FIELD` must be an extern union type (it is the only union type with a well defined memory layout for automatic serialization), got type `{s}`", .{@typeName(TYPE)});
        const UNION_BUILDER = DataOpBuilderExternUnion(TAG_TYPE);
        const header_op_idx = self.low_level.ops_len;
        self.low_level.add_union_header_op(0);
        const union_builder = UNION_BUILDER{
            .builder = self,
            .settings = SETTINGS,
            .op_idx_for_header = header_op_idx,
            .union_type = TYPE,
        };
        return union_builder;
    }

    fn _internal_add_pointer_to_single_numeric_value_with_custom_settings(comptime self: *DataOpBuilderStruct, comptime PTR_TYPE: type, comptime FIELD: ?[]const u8, comptime OFFSET_TO_NEXT_VALUE: i32, comptime ALLOC_NAME: ?[]const u8, comptime TARGET_ENDIAN: Endian, comptime CACHE_DATA: DataCacheMode, comptime TECH: DataTransferTech) void {
        const PTR_INFO = KindInfo.get_kind_info(PTR_TYPE);
        assert_with_reason(PTR_INFO == .POINTER and PTR_INFO.POINTER.size != .slice, @src(), "type of field `{s}` on type `{s}` was not a single-item pointer, got type `{s}`", .{FIELD, @typeName(self.low_level.current_type)});
        const ELEM_SIZE = @sizeOf(PTR_INFO.POINTER.child);
        const PTR_ALIGN = PTR_INFO.POINTER.alignment;
        const REAL_ALLOC_NAME = if (ALLOC_NAME) |A_N| A_N else DEFAULT_ALLOC_NAME;
        const alloc_idx = self.low_level.get_or_add_alloc_name_index(REAL_ALLOC_NAME);
        self.low_level.add_pointer_follow_or_allocate_op(ELEM_SIZE, PTR_ALIGN, alloc_idx, 1, OFFSET_TO_NEXT_VALUE, comptime LEN_MODE: PointerLenMode)
        //CHECKPOINT
    }

    pub fn add_pointer_to_single_numeric_value_with_custom_settings(comptime self: *DataOpBuilderStruct, FIELD: []const u8, comptime NEXT_FIELD: ?[]const u8, comptime ALLOC_NAME: ?[]const u8, comptime TARGET_ENDIAN: Endian, comptime CACHE_DATA: DataCacheMode, comptime TECH: DataTransferTech) void {
        assert_with_reason(self.low_level.current_kind == .STRUCT, @src(), "current type kind is not a struct, current kind is `{s}`, real type `{s}`", .{ @tagName(self.low_level.current_kind), @typeName(self.low_level.current_type) });
        assert_with_reason(@hasField(self.low_level.current_type, FIELD), @src(), "struct `{s}` does not have field `{s}`", .{ @typeName(self.low_level.current_type), FIELD });
        const PTR_TYPE = @FieldType(self.low_level.current_type, FIELD);
        if (NEXT_FIELD) |NEXT| assert_with_reason(@hasField(self.low_level.current_type, NEXT), @src(), "struct `{s}` does not have NEXT field `{s}`", .{ @typeName(self.low_level.current_type), NEXT });
        if (self.prev_field != null) assert_with_reason(self.next_field != null and std.mem.eql(u8, self.next_field.?, FIELD), @src(), "the prev field you added indicated the next field to add was `{s}`, but the next field you actually added was `{s}`: routine offsets will be broken", .{ if (self.next_field) |next| next else "<void, end struct>", FIELD });
        if (self.prev_field == null and @offsetOf(self.low_level.current_type, FIELD) != 0) {
            self.low_level.add_add_native_offset_op(@offsetOf(self.low_level.current_type, FIELD));
        }
        self.prev_field = FIELD;
        self.next_field = NEXT_FIELD;
        const offset_to_next_field = self.low_level.get_offset_between_two_fields(FIELD, NEXT_FIELD);
        //CHECKPOINT
        
    }

    // CHECKPOINT pointers/sub-struct types

};

pub fn DataOpBuilderExternUnion(comptime TAG_TYPE: type) type {
    return struct {
        const Self = @This();

        builder: *DataOpBuilderStruct,
        union_type: type,
        settings: ObjectSerialSettings,
        op_idx_for_header: u32,
        num_branches: u32 = 0,

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
                    const uint: Types.UnsignedIntegerWithSameSize(INT) = @bitCast(val);
                    return num_cast(uint, u64);
                },
                else => assert_unreachable(@src(), "only Enums or Integers are allowed as `TAG_TYPE`, got type `{s}`", .{@typeName(TAG_TYPE)}),
            }
        }

        /// This uses the current settings on the parent union, object settings, and field settings for the field to add a data transfer op
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_single_tag_id_numeric_op(comptime self: *Self, comptime tag: TAG_TYPE, comptime FIELD: []const u8) void {
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FIELD_SETTINGS = get_field_settings(self.union_type, FIELD);
            const OBJECT_SETTINGS = get_object_settings(TYPE);
            const SETTINGS = self.settings.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
            const TECH = self.builder.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
            self.add_single_tag_id_numeric_op_with_custom_settings(tag, FIELD, SETTINGS.TARGET_ENDIAN, .DONT_CACHE_DATA, TECH);
        }

        /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
        /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_single_tag_id_numeric_op_with_custom_settings(comptime self: *Self, comptime tag: TAG_TYPE, comptime FIELD: []const u8, comptime TARGET_ENDIAN: Endian, comptime CACHE: DataCacheMode, comptime TECH: DataTransferTech) void {
            const as_u64 = cast_val_to_u64(tag);
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            self.builder.low_level.add_union_tag_op(as_u64, 1);
            self.builder._internal_add_numeric_field_with_custom_settings(TYPE, FIELD, 0, TARGET_ENDIAN, CACHE, TECH);
            self.num_branches += 1;
        }

        /// This uses the current settings on the parent union, object settings, and field settings for the field to add a data transfer op
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_single_tag_id_numeric_array_op(comptime self: *Self, comptime tag: TAG_TYPE, comptime FIELD: []const u8) void {
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FIELD_SETTINGS = get_field_settings(self.union_type, FIELD);
            const OBJECT_SETTINGS = get_object_settings(TYPE);
            const SETTINGS = self.settings.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
            const TECH = self.builder.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
            self.add_single_tag_id_numeric_array_op_with_custom_settings(tag, FIELD, SETTINGS.TARGET_ENDIAN, TECH);
        }

        /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
        /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_single_tag_id_numeric_array_op_with_custom_settings(comptime self: *Self, comptime tag: TAG_TYPE, comptime FIELD: []const u8, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech) void {
            const as_u64 = cast_val_to_u64(tag);
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FINAL_ELEMENT_TYPE: type, _ = self.builder.low_level.get_numeric_elem_type_and_total_len_for_numeric_array_type(TYPE);
            const NUM_FOLLOWING = if (@sizeOf(FINAL_ELEMENT_TYPE) == 1) 1 else 2;
            self.builder.low_level.add_union_tag_op(as_u64, NUM_FOLLOWING);
            self.builder._internal_add_numeric_array_field_with_custom_settings(TYPE, FIELD, 0, TARGET_ENDIAN, TECH);
            self.num_branches += 1;
        }

        /// This uses the current settings on the parent union, object settings, and field settings for the field to add a data transfer op
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_tag_range_id_numeric_op(comptime self: *Self, comptime tag_min: TAG_TYPE, comptime tag_max: TAG_TYPE, comptime FIELD: []const u8) void {
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FIELD_SETTINGS = get_field_settings(self.union_type, FIELD);
            const OBJECT_SETTINGS = get_object_settings(TYPE);
            const SETTINGS = self.settings.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
            const TECH = self.builder.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
            self.add_tag_range_id_numeric_op_with_custom_settings(tag_min, tag_max, FIELD, SETTINGS.TARGET_ENDIAN, .DONT_CACHE_DATA, TECH);
        }

        /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
        /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_tag_range_id_numeric_op_with_custom_settings(comptime self: *Self, comptime tag_min: TAG_TYPE, comptime tag_max: TAG_TYPE, comptime FIELD: []const u8, comptime TARGET_ENDIAN: Endian, comptime CACHE: DataCacheMode, comptime TECH: DataTransferTech) void {
            const min_as_u64 = cast_val_to_u64(tag_min);
            const max_as_u64 = cast_val_to_u64(tag_max);
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            self.builder.low_level.add_union_range_op(min_as_u64, max_as_u64, 1);
            self.builder._internal_add_numeric_field_with_custom_settings(TYPE, FIELD, 0, TARGET_ENDIAN, CACHE, TECH);
            self.num_branches += 1;
        }

        /// This uses the current settings on the parent union, object settings, and field settings for the field to add a data transfer op
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_tag_range_id_numeric_array_op(comptime self: *Self, comptime tag_min: TAG_TYPE, comptime tag_max: TAG_TYPE, comptime FIELD: []const u8) void {
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FIELD_SETTINGS = get_field_settings(self.union_type, FIELD);
            const OBJECT_SETTINGS = get_object_settings(TYPE);
            const SETTINGS = self.settings.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(FIELD_SETTINGS);
            const TECH = self.builder.low_level.get_tech_for_numeric_type(SETTINGS, TYPE);
            self.add_tag_range_id_numeric_array_op_with_custom_settings(tag_min, tag_max, FIELD, SETTINGS.TARGET_ENDIAN, TECH);
        }

        /// This method ignores ALL inherited `integer_packing` and `target_endian` settings, and allows optional cacheing of data and other
        /// non-standard encodings, such as encoding a float as a varint, and/or encoding an unsigned integer or floats using zig-zag encoding
        ///
        /// Valid field types are:
        ///   - Integers
        ///   - Bools
        ///   - Enums
        ///   - Floats
        ///   - Packed Structs
        ///   - Packed Unions
        pub fn add_tag_range_id_numeric_array_op_with_custom_settings(comptime self: *Self, comptime tag_min: TAG_TYPE, comptime tag_max: TAG_TYPE, comptime FIELD: []const u8, comptime TARGET_ENDIAN: Endian, comptime TECH: DataTransferTech) void {
            const min_as_u64 = cast_val_to_u64(tag_min);
            const max_as_u64 = cast_val_to_u64(tag_max);
            assert_with_reason(@hasField(self.union_type, FIELD), @src(), "union type `{s}` does not have field `{s}`", .{ @typeName(self.union_type), FIELD });
            const TYPE = @FieldType(self.union_type, FIELD);
            const FINAL_ELEMENT_TYPE: type, _ = self.builder.low_level.get_numeric_elem_type_and_total_len_for_numeric_array_type(TYPE);
            const NUM_FOLLOWING = if (@sizeOf(FINAL_ELEMENT_TYPE) == 1) 1 else 2;
            self.builder.low_level.add_union_tag_op(min_as_u64, max_as_u64, NUM_FOLLOWING);
            self.builder._internal_add_numeric_array_field_with_custom_settings(TYPE, FIELD, 0, TARGET_ENDIAN, TECH);
            self.num_branches += 1;
        }

        // CHECKPOINT pointers/subroutine types

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
    native_offset_after_routine: u32,
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
        eval_one_type_to_count_and_record_all_unique_types(TYPE_TO_SERIALIZE, DEFAULT_SETTINGS, null, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
    }
}

fn add_unique_type(comptime TYPE: type, comptime SETTINGS: ObjectSerialSettings, comptime IS_ROOT: bool, comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: *u32) void {
    for (UNIQUE_TYPE_ARRAY[0..UNIQUE_TYPE_ARRAY_LEN.*]) |TYPE_ALREADY_RECORDED| {
        if (TYPE == TYPE_ALREADY_RECORDED.object_type and SETTINGS.equals(TYPE_ALREADY_RECORDED.object_settings)) return;
    }
    assert_with_reason(UNIQUE_TYPE_ARRAY_LEN.* < UNIQUE_TYPE_ARRAY.len, @src(), "ran out of slots for unique types, have {d}, need AT LEAST {d}, provide a larger `ARRAY_LENS.UNIQUE_TYPE_ARRAY_MAX_LEN` value", .{ UNIQUE_TYPE_ARRAY.len, UNIQUE_TYPE_ARRAY_LEN.* + 1 });
    UNIQUE_TYPE_ARRAY[UNIQUE_TYPE_ARRAY_LEN.*] = UniqueSerialType{
        .object_type = TYPE,
        .object_settings = SETTINGS,
        .at_least_usage_ref = IS_ROOT,
    };
    UNIQUE_TYPE_ARRAY_LEN.* += 1;
}

fn eval_one_type_to_count_and_record_all_unique_types(comptime TYPE: type, comptime ROOT_SETTINGS: ObjectSerialSettings, comptime PARENT_TYPE: ?type, comptime FIELD_ON_PARENT: ?[]const u8, comptime SETTINGS_FROM_PARENT: ?OptionalObjectSerialSettings, comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_BUFFER_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: *u32) void {
    const OBJECT_SETTINGS = get_object_settings(TYPE);
    const SETTINGS = ROOT_SETTINGS.combined_with_optional(OBJECT_SETTINGS).combined_with_optional(SETTINGS_FROM_PARENT);
    const TYPE_INFO = KindInfo.get_kind_info(TYPE);
    const IS_ROOT = PARENT_TYPE != null;
    // if (@sizeOf(TYPE) == 0) return;
    // if (SETTINGS.CUSTOM_ROUTINE == .CUSTOM_RUNTIME_SERIALIZE) {
    //     add_unique_type(TYPE, SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
    //     return;
    // }
    switch (TYPE_INFO) {
        .INT, .FLOAT, .BOOL, .ENUM, .COMPTIME_INT, .COMPTIME_FLOAT, .ERROR_SET, .VOID, .TYPE, .FRAME, .ANYFRAME, .FUNCTION, .NO_RETURN, .UNDEFINED, .ENUM_LITERAL, .NULL, .OPAQUE => {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
        // .COMPTIME_INT, .COMPTIME_FLOAT => {
        //     add_unique_type(TYPE, SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        //     // assert_unreachable(@src(), "`comptime_int` and `comptime_float` types are not allowed for serialization without a `SETTINGS.CUSTOM_ROUTINE == .CUSTOM_RUNTIME_SERIALIZE`, as they have no fixed size and no runtime memory address", .{});
        // },
        .ERROR_UNION => |ERROR_UNION| {
            // if (SETTINGS.CUSTOM_ROUTINE == .NO_CUSTOM_ROUTINE) {
            //     assert_unreachable(@src(), "`error` and `error_union` types are not allowed for serialization *WITHOUT A CUSTOM ROUTINE*, because their numeric values are not well-defined (the compiler arbitrarily picks unique integers for each unique error, and code completely unrelated to the serialized types can cause the numeric assignments to change, or the numeric assignments can change from target platform to platform even if the source code is the same)", .{});
            // }
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            eval_one_type_to_count_and_record_all_unique_types(ERROR_UNION.payload, SETTINGS, TYPE, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
        // .TYPE, .FRAME, .ANYFRAME, .FUNCTION, .NO_RETURN, .UNDEFINED, .ENUM_LITERAL, .NULL => {
        //     add_unique_type(TYPE, SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        //     // assert_unreachable(@src(), "type kind `{s}` is not allowed for serialization without `SETTINGS.CUSTOM_ROUTINE == .CUSTOM_RUNTIME_SERIALIZE`, because it is either a comptime-only type, or is a value that only has relevance in the specific compiled binary it belongs to", .{@tagName(TYPE_INFO)});
        // },
        .POINTER => |POINTER| {
            // switch (SETTINGS.POINTER_MODE) {
            //     .FOLLOW_POINTERS => {},
            //     .IGNORE_POINTERS => {
            //         return;
            //     },
            //     .DISALLOW_POINTERS => {
            //         assert_unreachable(@src(), "pointers are not allowed at this object heirarchy location per the serial settings inherited (in priority order):\n\t(1) Field settings for `{s}` on parent type `{s}`: {s}\n\t(2) Object settings on pointer: (null, pointers cannot have object settings)\n\t(3) Root settings inherited from heirarchy: {s}", .{ if (FIELD_ON_PARENT) |F| F else "<none>", if (PARENT_TYPE) |P| @typeName(P) else "<no parent>", if (SETTINGS_FROM_PARENT) |S| (if (S.POINTER_MODE) |SP| @tagName(SP) else "null") else "<no setting>", @tagName(ROOT_SETTINGS.POINTER_MODE) });
            //     },
            // }
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            eval_one_type_to_count_and_record_all_unique_types(POINTER.child, SETTINGS, TYPE, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
        .STRUCT => |STRUCT| {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            inline for (STRUCT.fields) |field| {
                const FIELD_SETTINGS = get_field_settings(TYPE, field.name);
                eval_one_type_to_count_and_record_all_unique_types(field.type, SETTINGS, TYPE, field.name, FIELD_SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            }
        },
        .UNION => |UNION| {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            inline for (UNION.fields) |field| {
                const FIELD_SETTINGS = get_field_settings(TYPE, field.name);
                eval_one_type_to_count_and_record_all_unique_types(field.type, SETTINGS, TYPE, field.name, FIELD_SETTINGS, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            }
        },
        .ARRAY => |ARRAY| {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            eval_one_type_to_count_and_record_all_unique_types(ARRAY.child, SETTINGS, TYPE, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
        .VECTOR => |VECTOR| {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            eval_one_type_to_count_and_record_all_unique_types(VECTOR.child, SETTINGS, TYPE, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
        .OPTIONAL => |OPTIONAL| {
            add_unique_type(TYPE, SETTINGS, IS_ROOT, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
            eval_one_type_to_count_and_record_all_unique_types(OPTIONAL.child, SETTINGS, TYPE, null, null, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN);
        },
    }
}

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

fn build_op_routines_for_all_unique_types(comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_ARRAY_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: u32, comptime OP_BUFFER: *[ARRAY_LENS.OP_BUFFER_MAX_LEN]DataOp, comptime OP_BUFFER_LEN: *u32) void {
    for (UNIQUE_TYPE_ARRAY[0..UNIQUE_TYPE_ARRAY_LEN]) |*TYPE_TO_SERIALIZE| {
        build_op_routine_for_type(TYPE_TO_SERIALIZE, ARRAY_LENS, UNIQUE_TYPE_ARRAY, UNIQUE_TYPE_ARRAY_LEN, OP_BUFFER, OP_BUFFER_LEN);
    }
}

fn build_op_routine_for_type(comptime UNIQUE_TYPE: *UniqueSerialType, comptime ARRAY_LENS: SerialManagerArrayLens, comptime UNIQUE_TYPE_ARRAY: *[ARRAY_LENS.UNIQUE_TYPE_ARRAY_MAX_LEN]UniqueSerialType, comptime UNIQUE_TYPE_ARRAY_LEN: u32, comptime OP_BUFFER: *[ARRAY_LENS.OP_BUFFER_MAX_LEN]DataOp, comptime OP_BUFFER_LEN: *u32) void {
    if (UNIQUE_TYPE.routine_made) return;
    UNIQUE_TYPE.routine_made = true;
    const first_op = OP_BUFFER_LEN.*;
    comptime var op_manager = DataOpManagerHighLevel.new(UNIQUE_TYPE_ARRAY[0..UNIQUE_TYPE_ARRAY_LEN], OP_BUFFER[first_op..ARRAY_LENS.OP_BUFFER_MAX_LEN]);
    const CUSTOM_MODE = UNIQUE_TYPE.object_settings.CUSTOM_ROUTINE;
    const SETTINGS_WITHOUT_CUSTOM = UNIQUE_TYPE.object_settings.with_custom_routine_removed();
    switch (CUSTOM_MODE) {
        .CUSTOM_COMPTIME_MANAGER_OPS_ROUTINE => |add_custom_ops| {
            add_custom_ops(SETTINGS_WITHOUT_CUSTOM, &op_manager);
        },
        .CUSTOM_RUNTIME_SERIALIZE => |funcs| {
            op_manager.low_level.add_custom_functions_op(funcs);
        },
        .NO_CUSTOM_ROUTINE => {
            //FIXME
        },
    }
    //CHECKPOINT
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
