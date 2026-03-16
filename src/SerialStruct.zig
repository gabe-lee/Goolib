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
const Endian = std.builtin.Endian;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const read_int = std.mem.readInt;

pub const NATIVE_ENDIAN = build.cpu.arch.endian();

pub const DataMoveWithExtra = struct {
    native_pos: u32 = 0,
    serial_pos: u32 = 0,
    len: u32 = 0,
    largest_type: u32 = 1,

    pub fn native_end(self: DataMoveWithExtra) u32 {
        return self.native_pos + self.len;
    }
    pub fn serial_end(self: DataMoveWithExtra) u32 {
        return self.serial_pos + self.len;
    }
};

pub const DataMove = struct {
    native_pos: u32 = 0,
    serial_pos: u32 = 0,
    len: u32 = 0,
    swap: bool = false,

    pub fn native_end(self: DataMove) u32 {
        return self.native_pos + self.len;
    }
    pub fn serial_end(self: DataMove) u32 {
        return self.serial_pos + self.len;
    }
};

pub const DataMoveOp = enum(u8) {
    NO_MOVE_OR_SWAP = 0,
    MOVE_NO_SWAP = 1,
    SWAP_IN_PLACE = 2,
    MOVE_AND_SWAP = 3,
    EVALUATE_SUB_LAYOUT = 4,
    UNDEFINED_BYTE = 5,
};

pub const DataSubLayout = enum(u8) {
    NO_SUB_LAYOUT = 0,
    EVALUATE_SUB_LAYOUT = 1,
};

pub const TrimEndMode = enum(u8) {
    SAME_TOTAL_SIZE = 0,
    TRIM_END = 1,
};

pub const RefitMode = enum(u8) {
    NO_REFIT = 0,
    REFIT_SMALLER_FIELDS = 1,
};

pub const StructPacking = enum(u8) {
    /// This will match the layout of a C ABI in most cases (`extern struct`)
    BY_FIELD_ORDER_PROPER_ALIGNMENT_SAME_TOTAL_SIZE,
    /// This will match the layout of a C ABI in *some* cases (`extern struct`),
    /// but will trim any wasted bytes off the end of the struct.
    BY_FIELD_ORDER_PROPER_ALIGNMENT_TRIM_END,
    /// Re-orders all fields by largest alignment first, but does not
    /// try to find waste space to pack smaller fields into. Keeps the same
    /// total size of the struct.
    REORDER_BY_LARGEST_ALIGNMENT_SAME_TOTAL_SIZE,
    /// Re-orders all fields by largest alignment first, but does not
    /// try to find waste space to pack smaller fields into.
    /// Trims wasted bytes off the end of the struct.
    REORDER_BY_LARGEST_ALIGNMENT_TRIM_END,
    /// Re-orders all fields by largest alignment first, and then
    /// pack smaller aligned fields into the wasted spaces IF that waste
    /// space can support the alignment and size of the field. Keeps the same
    /// total size of the struct.
    REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_SAME_TOTAL_SIZE,
    /// Re-orders all fields by largest alignment first, and then
    /// pack smaller aligned fields into the wasted spaces IF that waste
    /// space can support the alignment and size of the field.
    /// Trims wasted bytes off the end of the struct.
    REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_TRIM_END,
    /// Tightly pack all fields in order as declared, but without
    /// aligning their offsets to their required alignment.
    /// Keeps the same total size of the struct, which may result in
    /// a lot of wasted space that has no pupose.
    ///
    /// This mode is not recommended, but provided.
    BY_FIELD_ORDER_TIGHTLY_PACK_SAME_TOTAL_SIZE,
    /// Tightly pack all fields in order as declared, but without
    /// aligning their offsets to their required alignment.
    /// Trims wasted bytes off the end of the struct.
    BY_FIELD_ORDER_TIGHTLY_PACK_TRIM_END,
};

pub const FieldOffset = struct {
    name: [:0]const u8,
    field_type: type,
    serial_offset: usize,
    native_offset: usize,

    pub fn sort_smaller_offset_to_the_right(a: FieldOffset, b: FieldOffset, _: void) bool {
        return a.serial_offset < b.serial_offset;
    }
    pub fn sort_smaller_offset_to_the_left(a: FieldOffset, b: FieldOffset, _: void) bool {
        return a.serial_offset > b.serial_offset;
    }
};
pub const OffsetAndSpace = struct {
    offset: usize,
    space: usize,

    pub fn sort_larger_spaces_to_the_right(a: OffsetAndSpace, b: OffsetAndSpace, _: void) bool {
        return a.space > b.space;
    }
};

pub fn StructOffsetsResult(comptime STRUCT: type) type {
    const INFO = KindInfo.get_kind_info(STRUCT).STRUCT;
    const LEN = INFO.fields.len;
    const SIZE = @sizeOf(STRUCT);
    return struct {
        const Self = @This();

        fields: [LEN]FieldOffset,
        field_sub_layouts: [LEN]DataSubLayout = @splat(DataSubLayout.NO_SUB_LAYOUT),
        serial_byte_move_ops: [SIZE]DataMoveOp = @splat(DataMoveOp.UNDEFINED_BYTE),
        total_byte_len: usize,
        total_waste_bytes: usize = SIZE,
        all_fields_completely_native: bool = true,

        pub fn eval_ops_and_waste(comptime self: *Self, comptime TARGET_ENDIAN: Endian) void {
            const SWAP_ENDIAN = TARGET_ENDIAN != NATIVE_ENDIAN;
            inline for (self.fields, 0..) |field, i| {
                const KIND = KindInfo.get_kind_info(field.field_type);
                const WRONG_OFFSET = field.native_offset != field.serial_offset;
                var fill: DataMoveOp = .UNDEFINED_BYTE;
                if (KIND.is_kind_with_sub_structure()) {
                    fill = .EVALUATE_SUB_LAYOUT;
                    self.field_sub_layouts[i] = .EVALUATE_SUB_LAYOUT;
                } else if (WRONG_OFFSET or SWAP_ENDIAN) {
                    if (WRONG_OFFSET and SWAP_ENDIAN) {
                        fill = .MOVE_AND_SWAP;
                    } else if (WRONG_OFFSET and !SWAP_ENDIAN) {
                        fill = .MOVE_NO_SWAP;
                    } else {
                        fill = .SWAP_IN_PLACE;
                    }
                    self.all_fields_completely_native = false;
                } else {
                    fill = .NO_MOVE_OR_SWAP;
                }
                const F_SIZE = @sizeOf(field.field_type);
                const end = field.serial_offset + F_SIZE;
                @memset(self.serial_byte_move_ops[field.serial_offset..end], fill);
                self.total_waste_bytes -= F_SIZE;
            }
        }
    };
}

pub fn StructOffsetsByFieldOrder(comptime STRUCT: type, comptime TARGET_ENDIAN: Endian, comptime TRIM_END: TrimEndMode) StructOffsetsResult(STRUCT) {
    const INFO = KindInfo.get_kind_info(STRUCT).STRUCT;
    comptime var out_fields: [INFO.fields.len]FieldOffset = undefined;
    comptime var curr_offset: usize = 0;
    inline for (INFO.fields, 0..) |field, i| {
        const ALIGN = @alignOf(field.type);
        const SIZE = @alignOf(field.type);
        curr_offset = std.mem.alignForward(usize, curr_offset, ALIGN);
        out_fields[i] = FieldOffset{
            .name = field.name,
            .field_type = field.type,
            .serial_offset = curr_offset,
            .native_offset = @offsetOf(STRUCT, field.name),
        };
        curr_offset += SIZE;
    }
    var result = StructOffsetsResult(STRUCT){
        .fields = out_fields,
        .total_byte_len = if (TRIM_END) curr_offset else @sizeOf(STRUCT),
    };
    result.eval_ops_and_waste(TARGET_ENDIAN);
    return result;
}

pub fn StructOffsetsByLargestAlign(comptime STRUCT: type, comptime TARGET_ENDIAN: Endian, comptime REFIT: RefitMode, comptime TRIM_END: TrimEndMode) StructOffsetsResult(STRUCT) {
    const INFO = KindInfo.get_kind_info(STRUCT).STRUCT;
    const LEN = INFO.fields.len;
    const MAX_EMPTY_LEN = LEN * 4;
    comptime var out_fields: [LEN]FieldOffset = undefined;
    comptime var empty_spaces: if (REFIT == .REFIT_SMALLER_FIELDS) [MAX_EMPTY_LEN]OffsetAndSpace else void = undefined;
    comptime var empty_spaces_len: if (REFIT == .REFIT_SMALLER_FIELDS) usize else u0 = 0;
    comptime var largest_align: usize = 1;
    comptime var first_smallest_align_idx: usize = 0;
    inline for (INFO.fields, 0..) |field, i| {
        const ALIGN = @alignOf(field.type);
        if (ALIGN == largest_align) {
            first_smallest_align_idx += 1;
        } else if (ALIGN > largest_align) {
            largest_align = ALIGN;
            first_smallest_align_idx = 1;
        }
        out_fields[i] = FieldOffset{
            .name = field.name,
            .field_type = field.type,
            .serial_offset = ALIGN,
            .native_offset = @offsetOf(STRUCT, field.name),
        };
    }
    Utils.mem_sort(@ptrCast(&out_fields[0]), 0, LEN, void{}, FieldOffset.sort_smaller_offset_to_the_right);
    comptime var curr_offset: usize = 0;
    inline for (out_fields[0..], 0..) |*field, i| {
        const TYPE = @FieldType(STRUCT, field.name);
        const ALIGN = field.serial_offset;
        assert_with_reason(ALIGN <= largest_align, @src(), "sorting did not put fields in order by align", .{});
        largest_align = ALIGN;
        const SIZE = @sizeOf(TYPE);
        if (i > 0) {
            const old_curr_offset = curr_offset;
            curr_offset = std.mem.alignForward(usize, curr_offset, ALIGN);
            if (REFIT == .REFIT_SMALLER_FIELDS) {
                const waste = curr_offset - old_curr_offset;
                if (waste > 0) {
                    empty_spaces[empty_spaces_len] = OffsetAndSpace{
                        .offset = old_curr_offset,
                        .space = waste,
                    };
                    empty_spaces_len += 1;
                }
            }
        }
        field.serial_offset = curr_offset;
        curr_offset += SIZE;
    }
    if (REFIT == .REFIT_SMALLER_FIELDS) {
        Utils.mem_sort(@ptrCast(&empty_spaces[0]), 0, empty_spaces_len, void{}, OffsetAndSpace.sort_larger_spaces_to_the_right);
        inline for (out_fields[first_smallest_align_idx..]) |*field| {
            inline for (empty_spaces[0..empty_spaces_len], 0..) |*empty, e| {
                const TYPE = @FieldType(STRUCT, field.name);
                const ALIGN = @alignOf(TYPE);
                const SIZE = @sizeOf(TYPE);
                if (empty.space >= SIZE) {
                    const old_empty_offset = empty.offset;
                    const aligned_empty_offset = std.mem.alignForward(usize, old_empty_offset, ALIGN);
                    const new_waste_before = aligned_empty_offset - old_empty_offset;
                    const aligned_space = empty.space - new_waste_before;
                    if (aligned_space >= SIZE) {
                        field.serial_offset = aligned_empty_offset;
                        const new_waste_after = empty.space - new_waste_before - SIZE;
                        if (new_waste_before == 0 and new_waste_after == 0) {
                            Utils.mem_remove(@ptrCast(&empty_spaces[0]), &empty_spaces_len, e, 1);
                        } else if (new_waste_before == 0) {
                            const new_empty_offset = old_empty_offset + SIZE;
                            empty.offset = new_empty_offset;
                            empty.space = new_waste_after;
                        } else if (new_waste_after == 0) {
                            empty.space = new_waste_before;
                        } else {
                            empty.space = new_waste_before;
                            empty_spaces[empty_spaces_len] = OffsetAndSpace{
                                .offset = aligned_empty_offset + SIZE,
                                .space = new_waste_after,
                            };
                            empty_spaces_len += 1;
                            Utils.mem_sort(@ptrCast(&empty_spaces[0]), 0, empty_spaces_len, void{}, OffsetAndSpace.sort_larger_spaces_to_the_right);
                        }
                        break;
                    }
                }
            }
        }
        Utils.mem_sort(@ptrCast(&out_fields[0]), 0, LEN, void{}, FieldOffset.sort_smaller_offset_to_the_left);
    }
    curr_offset = 0;
    inline for (out_fields[0..], 0..) |field, i| {
        const TYPE = @FieldType(STRUCT, field.name);
        const SIZE = @sizeOf(TYPE);
        const ALIGN = @alignOf(TYPE);
        assert_with_reason(field.serial_offset >= curr_offset, @src(), "layout caused field `{s}` and field `{s}` to have overlapping memory", .{ out_fields[i - 1].name, field.name });
        assert_with_reason(std.mem.isAligned(field.serial_offset, ALIGN), @src(), "layout caused field `{s}` to be mis-aligned for its type", .{field.name});
        curr_offset = field.serial_offset + SIZE;
    }
    var result = StructOffsetsResult(STRUCT){
        .fields = out_fields,
        .total_byte_len = if (TRIM_END) curr_offset else @sizeOf(STRUCT),
    };
    result.eval_ops_and_waste(TARGET_ENDIAN);
    return result;
}

//CHECKPOINT implement 'tightly packed' and 'this platform layout' modes

pub const SubBuildResult = struct {
    start: u32,
    end: u32,
};

pub const DataMoveBuilder = struct {
    ptr: [*]DataMoveWithExtra = Utils.invalid_ptr_many(DataMoveWithExtra),
    len: u32 = 0,
    cap: u32 = 0,
    max_align: u32 = 1,
    alloc: Allocator,
    swap_endian: bool,
    tightly_pack: bool,
    complete_layout_match: bool = true,

    pub fn curr_move(self: *DataMoveBuilder) *DataMoveWithExtra {
        if (self.len == 0) return self.add_move();
        return &self.ptr[self.len - 1];
    }

    pub fn init(comptime target_endian: Endian, comptime packing: StructPacking, comptime init_move_cap: u32, comptime alloc: Allocator) DataMoveBuilder {
        var self = DataMoveBuilder{
            .swap_endian = target_endian != NATIVE_ENDIAN,
            .tightly_pack = packing == .TIGHTLY_PACK,
            .alloc = alloc,
        };
        Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.ptr, &self.cap, @intCast(init_move_cap), .{}, .{});
        return self;
    }

    pub fn add_move(comptime self: *DataMoveBuilder) *DataMoveWithExtra {
        if (self.len >= self.cap) {
            Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.ptr, &self.cap, @intCast(self.len + 1), .{}, .{});
        }
        const ptr: *DataMoveWithExtra = &self.ptr[self.len];
        ptr.native_pos = if (self.len == 0) 0 else self.curr_move().native_end();
        ptr.serial_pos = if (self.len == 0) 0 else self.curr_move().serial_end();
        ptr.len = 0;
        self.len += 1;
        return ptr;
    }

    pub fn sub_build(comptime self: *DataMoveBuilder, comptime serial_offset: u32, comptime parent_root_offset: u32, comptime field_offset: u32, comptime TYPE: type) void {
        const KIND = KindInfo.get_kind_info(TYPE);
        switch (KIND) {
            .BOOL, .INT, .FLOAT, .ENUM => {
                if (serial_offset == parent_root_offset + field_offset) {
                    const move = self.curr_move();
                }
            },
            else => {},
        }
    }

    pub fn build(comptime self: *DataMoveBuilder, comptime ROOT_TYPE: type) void {
        const INFO = KindInfo.get_kind_info(ROOT_TYPE);
        var serial_pos: u32 = 0;
        var parent_root: u32 = 0;
        var field_offset: u32 = 0;
        inline for (INFO.fields) |field| {
            const field_offset = @offsetOf(ROOT_TYPE, field.name);
            //CHECKPOINT
        }
    }

    // pub fn build(comptime self: *DataMoveBuilder, comptime parent_offset: u32, comptime TYPE: type) void {
    //     const INFO = KindInfo.get_kind_info(TYPE);
    //     const SIZE = @sizeOf(TYPE);
    //     const ALIGN = @alignOf(TYPE);
    //     if (SIZE == 0) return;
    //     var move: *DataMoveWithExtra = if (self.len == 0) self.add_move() else self.curr_move();
    //     var curr_native = move.native_end();
    //     var curr_serial = move.serial_end();
    //     var req_native =  curr_native
    //     re_eval: switch (INFO) {
    //         .BOOL, .INT, .FLOAT, .ENUM => {

    //             if (!self.tightly_pack and !std.mem.isAligned(@intCast(curr_serial), ALIGN)) {
    //                 move = self.add_move();
    //                 move.serial_pos = std.mem.alignForward(u32, move.serial_pos, ALIGN);
    //                 move.serial_pos = move.native_pos;
    //             } else if (!(SIZE == 1 and move.largest_type == 1) and self.swap_endian) {
    //                 move = self.add_move();
    //                 move.serial_pos = move.native_pos;
    //             } else if ()
    //             move.serial_pos += SIZE;
    //             move.len += SIZE;
    //             self.max_align = @max(self.max_align, ALIGN);
    //         },
    //         .POINTER => {
    //             assert_unreachable(@src(), "pointer types cannot be serialized, got `{s}`", .{@typeName(TYPE)});
    //         },
    //         .ARRAY, .VECTOR => {
    //             const CHILD = if (INFO == .ARRAY) INFO.ARRAY.child else INFO.VECTOR.child;
    //             const CHILD_SIZE = @sizeOf(CHILD);
    //             const LEN = if (INFO == .ARRAY) INFO.ARRAY.len else INFO.VECTOR.len;
    //             if (LEN or CHILD_SIZE == 0) return;
    //             if (LEN == 1) continue :re_eval KindInfo.get_kind_info(CHILD);
    //             const prev_move_len = self.len;
    //             self.build(CHILD);
    //             if (prev_move_len != self.len) {
    //                 const delta = self.total_offset - prev_move_offset;
    //                 const add_delta = delta * (I.len - 1);
    //                 self.curr_move().serial_pos += add_delta;
    //                 return .NATIVE;
    //             } else {}
    //         },
    //     }
    // }

    pub fn stats(comptime builder: DataMoveBuilder) DataMoveStats {
        return DataMoveStats{
            .len = builder.len,
            .swap_endian = builder.swap_endian,
        };
    }
};

const DataMoveStats = struct {
    len: u32,
    swap_endian: bool,
};

pub fn DataMoveRoutine(comptime stats: DataMoveStats) type {
    return struct {
        moves: [stats.len]DataMoveWithExtra,
        swap_endian: bool,
    };
}

pub fn SerialTypeAdapter(comptime TARGET_TYPE: type) type {
    comptime var total_bytes: usize = 0;
    comptime var max_align: usize = 1;
    const INFO = KindInfo.get_kind_info(TARGET_TYPE);
    switch (INFO) {
        .BOOL => {
            total_bytes = 1;
        },
        .INT => {
            total_bytes = @sizeOf(TARGET_TYPE);
            max_align = @alignOf(TARGET_TYPE);
        },
    }
    const total_bytes_const = total_bytes;
    const max_align_const = max_align;
    return extern struct {
        bytes: [total_bytes_const]u8 align(max_align_const),
    };
}
