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

const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;
const read_int = std.mem.readInt;
const DEBUG = std.debug.print;
const DEBUG_CT = Utils.comptime_debug_print;

pub const Simple = @import("./Serializer_Simple.zig");

comptime {
    _ = @import("./Serializer_Simple.zig");
}

// pub const NATIVE_ENDIAN = build.cpu.arch.endian();

// pub const MAX_UNDEFINED_BYTES_TO_COPY_IN_ADJACENT_OPS = 32;

// // pub const DataMoveWithExtra = struct {
// //     native_pos: u32 = 0,
// //     serial_pos: u32 = 0,
// //     len: u32 = 0,
// //     largest_type: u32 = 1,

// //     pub fn native_end(self: DataMoveWithExtra) u32 {
// //         return self.native_pos + self.len;
// //     }
// //     pub fn serial_end(self: DataMoveWithExtra) u32 {
// //         return self.serial_pos + self.len;
// //     }
// // };

// pub const DataMove = struct {
//     native_pos: u32 = 0,
//     serial_pos: u32 = 0,
//     len: u32 = 0,
//     swap: bool = false,

//     pub fn native_end(self: DataMove) u32 {
//         return self.native_pos + self.len;
//     }
//     pub fn serial_end(self: DataMove) u32 {
//         return self.serial_pos + self.len;
//     }

//     pub fn combine_with_field_offset(comptime self: *DataMove, field: FieldOffset) void {
//         const curr_serial_end = self.serial_end();
//         const new_serial_end = field.serial_end();
//         const add_len = new_serial_end - curr_serial_end;
//         self.len += add_len;
//     }
// };

// pub const DataMoveOp = enum(u8) {
//     NO_MOVE_OR_SWAP = 0,
//     MOVE_NO_SWAP = 1,
//     SWAP_IN_PLACE = 2,
//     MOVE_AND_SWAP = 3,
//     EVALUATE_SUB_LAYOUT = 4,
//     UNDEFINED_BYTE = 5,

//     pub fn can_consilidate(self: DataMoveOp) bool {
//         return self == .MOVE_NO_SWAP or self == .NO_MOVE_OR_SWAP;
//     }

//     pub fn should_swap(self: DataMoveOp) bool {
//         return self == .MOVE_AND_SWAP or self == .SWAP_IN_PLACE;
//     }

//     pub fn same_consolidate_mode(self: DataMoveOp, other: DataMoveOp) bool {
//         return self.can_consilidate() and self == other;
//     }
// };

// pub const DataSubLayout = enum(u8) {
//     NO_SUB_LAYOUT = 0,
//     EVALUATE_SUB_LAYOUT = 1,
// };

// pub const Tightness = enum(u8) {
//     NATURALLY_PACKED = 0,
//     TIGHTLY_PACKED = 1,
// };

// pub const TrimEndMode = enum(u8) {
//     DO_NOT_TRIM = 0,
//     TRIM_END = 1,
// };

// pub const RefitMode = enum(u8) {
//     NO_REFIT = 0,
//     REFIT_SMALLER_FIELDS = 1,
// };

// pub const StructPackingMode = enum(u8) {
//     /// Use the exact same layout as the current compilation,
//     /// including the total size of the struct.
//     ///
//     /// This might change from platform to platform, change with
//     /// build settings, or even between compilations.
//     SAME_AS_THE_CURRENT_PLATFORM_AND_BUILD_MODE_SAME_SIZE,
//     /// Use the exact same layout as the current compilation,
//     /// but trim the unused bytes off the end of the struct.
//     ///
//     /// This might change from platform to platform, change with
//     /// build settings, or even between compilations.
//     SAME_AS_THE_CURRENT_PLATFORM_AND_BUILD_MODE_TRIM_END,
//     /// This will match the layout of a C ABI in most cases (`extern struct`)
//     BY_FIELD_ORDER_PROPER_ALIGNMENT_DO_NOT_TRIM,
//     /// This will match the layout of a C ABI in *some* cases (`extern struct`),
//     /// but will trim any wasted bytes off the end of the struct.
//     BY_FIELD_ORDER_PROPER_ALIGNMENT_TRIM_END,
//     /// Re-orders all fields by largest alignment first, but does not
//     /// try to find waste space to pack smaller fields into. Keeps the same
//     /// total size of the struct.
//     REORDER_BY_LARGEST_ALIGNMENT_DO_NOT_TRIM,
//     /// Re-orders all fields by largest alignment first, but does not
//     /// try to find waste space to pack smaller fields into.
//     /// Trims wasted bytes off the end of the struct.
//     REORDER_BY_LARGEST_ALIGNMENT_TRIM_END,
//     /// Re-orders all fields by largest alignment first, and then
//     /// pack smaller aligned fields into the wasted spaces IF that waste
//     /// space can support the alignment and size of the field. Keeps the same
//     /// total size of the struct.
//     REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_DO_NOT_TRIM,
//     /// Re-orders all fields by largest alignment first, and then
//     /// pack smaller aligned fields into the wasted spaces IF that waste
//     /// space can support the alignment and size of the field.
//     /// Trims wasted bytes off the end of the struct.
//     REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_TRIM_END,
//     /// Tightly pack all fields in order as declared, but without
//     /// aligning their offsets to their required alignment.
//     /// Keeps the same total size of the struct, which may result in
//     /// a lot of wasted space on the end that has no purpose.
//     ///
//     /// This mode is not recommended, but provided.
//     BY_FIELD_ORDER_TIGHTLY_PACK_DO_NOT_TRIM,
//     /// Tightly pack all fields in order as declared, but without
//     /// aligning their offsets to their required alignment.
//     /// Trims wasted bytes off the end of the struct.
//     BY_FIELD_ORDER_TIGHTLY_PACK_TRIM_END,
// };

// pub const FieldOffset = struct {
//     name: [:0]const u8,
//     field_type: type,
//     len: u32,
//     serial_offset: u32,
//     native_offset: u32,
//     op: DataMoveOp,

//     pub fn native_end(comptime self: FieldOffset) u32 {
//         return self.native_offset + self.len;
//     }
//     pub fn serial_end(comptime self: FieldOffset) u32 {
//         return self.serial_offset + self.len;
//     }

//     pub fn sort_smaller_offset_to_the_right(a: FieldOffset, b: FieldOffset, _: void) bool {
//         return a.serial_offset < b.serial_offset;
//     }
//     pub fn sort_smaller_offset_to_the_left(a: FieldOffset, b: FieldOffset, _: void) bool {
//         return a.serial_offset > b.serial_offset;
//     }

//     pub fn to_data_move(comptime self: FieldOffset, comptime swap: bool) DataMove {
//         return DataMove{
//             .native_pos = self.native_offset,
//             .serial_pos = self.serial_offset,
//             .len = @sizeOf(self.field_type),
//             .swap = swap,
//         };
//     }
// };

// pub const FieldSubStructure = struct {
//     name: [:0]const u8,
//     field_type: type,
//     ptr: *anyopaque,
// };

// pub const FieldKind = enum(u8) {
//     OFFSET,
//     SUB_STRUCTURE,
// };

// pub const FieldOffsetOrSubStructure = union(FieldKind) {
//     OFFSET: FieldOffset,
//     SUB_STRUCTURE: FieldSubStructure,

//     pub fn offset(off: FieldOffset) FieldOffsetOrSubStructure {
//         return FieldOffsetOrSubStructure{ .OFFSET = off };
//     }
//     pub fn sub_structure(sub: FieldSubStructure) FieldOffsetOrSubStructure {
//         return FieldOffsetOrSubStructure{ .SUB_STRUCTURE = sub };
//     }
// };

// pub const OffsetAndSpace = struct {
//     offset: usize,
//     space: usize,

//     pub fn sort_larger_spaces_to_the_right(a: OffsetAndSpace, b: OffsetAndSpace, _: void) bool {
//         return a.space > b.space;
//     }
// };

// pub const SerialReadError = error{
//     unknown_read_error,
//     serial_data_source_too_short,
// };
// pub const SerialWriteError = error{
//     unknown_write_error,
//     serial_data_dest_too_short,
// };

// pub fn SerialContract(comptime T: type, comptime NUM_STEPS: comptime_int, comptime STEPS_: []const DataMove) type {
//     comptime var prev_end: u32 = 0;
//     inline for (STEPS_[0..], 0..) |step, s| {
//         assert_with_reason(step.serial_pos >= prev_end, @src(), "`STEPS_` were not in proper order with no overlaps (step {d} failed)", .{s});
//         prev_end = step.serial_end();
//     }
//     return struct {
//         pub const STEPS = build: {
//             var out: [STEPS_.len]DataMove = undefined;
//             @memcpy(out[0..STEPS_.len], STEPS_);
//             break :build out;
//         };
//         pub const LONGEST_STEP: u32 = find: {
//             var longest: u32 = 0;
//             for (STEPS[0..]) |step| {
//                 longest = @max(longest, step.len);
//             }
//             break :find longest;
//         };
//         pub const SERIAL_LEN = STEPS[NUM_STEPS - 1].serial_end();

//         pub fn read_new_from_slice(source: []const u8) SerialReadError!T {
//             var dest: T = undefined;
//             try read_from_slice(source, &dest);
//             return dest;
//         }

//         pub fn read_from_slice(source: []const u8, dest: *T) SerialReadError!void {
//             if (source.len < SERIAL_LEN) return SerialReadError.serial_data_source_too_short;
//             const dest_raw: [*]u8 = @ptrCast(dest);
//             for (STEPS) |step| {
//                 const read_start = step.serial_pos;
//                 const read_end = step.serial_end();
//                 const write_start = step.native_pos;
//                 const write_end = step.native_end();
//                 if (step.swap) {
//                     var r = read_start;
//                     var w = write_end - 1;
//                     while (true) {
//                         dest_raw[w] = source[r];
//                         r += 1;
//                         if (r == read_end) break;
//                         w -= 1;
//                     }
//                 } else {
//                     @memcpy(dest_raw[write_start..write_end], source[read_start..read_end]);
//                 }
//             }
//         }

//         pub fn read_new_from_reader(reader: *Reader) SerialReadError!T {
//             var dest: T = undefined;
//             try read_from_reader(reader, &dest);
//             return dest;
//         }

//         pub fn read_from_reader(reader: *Reader, dest: *T) SerialReadError!void {
//             const dest_raw: [*]u8 = @ptrCast(dest);
//             const dest_size = @sizeOf(T);
//             var prev_pos: u32 = 0;
//             for (STEPS) |step| {
//                 const read_start = step.serial_pos;
//                 const read_end = step.serial_end();
//                 const write_start = step.native_pos;
//                 const write_end = step.native_end();
//                 if (read_start > prev_pos) {
//                     const skip_num = read_start - prev_pos;
//                     reader.discardAll(skip_num) catch |err| switch (err) {
//                         error.EndOfStream => return SerialReadError.serial_data_source_too_short,
//                         else => return SerialReadError.unknown_read_error,
//                     };
//                 }
//                 if (step.swap) {
//                     const max_fill: u32 = @intCast(reader.buffer.len);
//                     var bytes_remaining = step.len;
//                     var fill_left: u32 = undefined;
//                     if (max_fill > 0) {
//                         fill_left = @min(bytes_remaining, max_fill);
//                         reader.fill(@intCast(fill_left)) catch |err| switch (err) {
//                             error.EndOfStream => return SerialReadError.serial_data_source_too_short,
//                             else => return SerialReadError.unknown_read_error,
//                         };
//                     }
//                     var write_idx = write_end - 1;
//                     while (true) {
//                         reader.readSliceAll(dest_raw[write_idx..dest_size][0..1]) catch |err| switch (err) {
//                             error.EndOfStream => return SerialReadError.serial_data_source_too_short,
//                             else => return SerialReadError.unknown_read_error,
//                         };
//                         bytes_remaining -= 1;
//                         if (bytes_remaining == 0) break;
//                         fill_left -= 1;
//                         write_idx -= 1;
//                         if (max_fill > 0 and fill_left == 0) {
//                             fill_left = @min(bytes_remaining, max_fill);
//                             reader.fill(@intCast(fill_left)) catch |err| switch (err) {
//                                 error.EndOfStream => return SerialReadError.serial_data_source_too_short,
//                                 else => return SerialReadError.unknown_read_error,
//                             };
//                         }
//                     }
//                 } else {
//                     reader.readSliceAll(dest_raw[write_start..write_end]) catch |err| switch (err) {
//                         error.EndOfStream => return SerialReadError.serial_data_source_too_short,
//                         else => return SerialReadError.unknown_read_error,
//                     };
//                 }
//                 prev_pos = read_end;
//             }
//         }

//         pub fn write_to_slice(source: *const T, dest: []u8) SerialWriteError!void {
//             if (dest.len < SERIAL_LEN) return SerialWriteError.serial_data_dest_too_short;
//             const source_raw: [*]const u8 = @ptrCast(source);
//             for (STEPS) |step| {
//                 const read_start = step.native_pos;
//                 const read_end = step.native_end();
//                 const write_start = step.serial_pos;
//                 const write_end = step.serial_end();
//                 if (step.swap) {
//                     var r = read_start;
//                     var w = write_end - 1;
//                     while (true) {
//                         dest[w] = source_raw[r];
//                         r += 1;
//                         if (r == read_end) break;
//                         w -= 1;
//                     }
//                 } else {
//                     @memcpy(dest[write_start..write_end], source_raw[read_start..read_end]);
//                 }
//             }
//         }

//         pub fn write_to_writer(source: *const T, writer: *Writer) SerialWriteError!void {
//             const source_raw: [*]const u8 = @ptrCast(source);
//             var prev_write_end: u32 = 0;
//             for (STEPS) |step| {
//                 const read_start = step.native_pos;
//                 const read_end = step.native_end();
//                 const write_start = step.serial_pos;
//                 const write_end = step.serial_end();
//                 if (write_start > prev_write_end) {
//                     const skip_num = write_start - prev_write_end;
//                     writer.advance(skip_num);
//                 }
//                 if (step.swap) {
//                     var bytes_remaining = step.len;
//                     var read_idx = read_end - 1;
//                     while (true) {
//                         writer.writeByte(source_raw[read_idx]) catch return SerialWriteError.unknown_write_error;
//                         bytes_remaining -= 1;
//                         if (bytes_remaining == 0) break;
//                         read_idx -= 1;
//                     }
//                 } else {
//                     writer.writeAll(source_raw[read_start..read_end]) catch return SerialWriteError.unknown_write_error;
//                 }
//                 prev_write_end = write_end;
//             }
//             writer.flush() catch return SerialWriteError.unknown_write_error;
//         }
//     };
// }

// pub fn StructOffsetsResult(comptime STRUCT: type) type {
//     const MAX_SERIAL_SIZE_HEURISTIC = 2;
//     const INFO = KindInfo.get_kind_info(STRUCT).STRUCT;
//     const FIELDS_LEN = INFO.fields.len;
//     const NATIVE_SIZE = @sizeOf(STRUCT);
//     const MAX_SERIAL_SIZE = NATIVE_SIZE * MAX_SERIAL_SIZE_HEURISTIC;
//     return struct {
//         const Self = @This();

//         fields: [FIELDS_LEN]FieldOffsetOrSubStructure,
//         field_sub_layouts: [FIELDS_LEN]DataSubLayout = @splat(DataSubLayout.NO_SUB_LAYOUT),
//         serial_byte_move_ops: [MAX_SERIAL_SIZE]DataMoveOp = @splat(DataMoveOp.UNDEFINED_BYTE),
//         total_byte_len: usize,
//         total_waste_bytes: usize = NATIVE_SIZE,
//         all_fields_completely_native: bool = true,
//         num_sub_structure_bytes_to_eval: usize = 0,
//         alloc: Allocator = DummyAllocator.allocator_panic_free_noop,
//         flattened: List(FieldOffset) = .{},
//         consolidated: List(DataMove) = .{},

//         pub fn create(comptime TARGET_ENDIAN: Endian, comptime MODE: StructPackingMode, comptime alloc: Allocator) Self {
//             var self = switch (MODE) {
//                 .BY_FIELD_ORDER_PROPER_ALIGNMENT_DO_NOT_TRIM => by_field_order(TARGET_ENDIAN, .NATURALLY_PACKED, .DO_NOT_TRIM),
//                 .BY_FIELD_ORDER_PROPER_ALIGNMENT_TRIM_END => by_field_order(TARGET_ENDIAN, .NATURALLY_PACKED, .TRIM_END),
//                 .BY_FIELD_ORDER_TIGHTLY_PACK_DO_NOT_TRIM => by_field_order(TARGET_ENDIAN, .TIGHTLY_PACKED, .DO_NOT_TRIM),
//                 .BY_FIELD_ORDER_TIGHTLY_PACK_TRIM_END => by_field_order(TARGET_ENDIAN, .TIGHTLY_PACKED, .TRIM_END),
//                 .REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_DO_NOT_TRIM => by_largest_align(TARGET_ENDIAN, .REFIT_SMALLER_FIELDS, .DO_NOT_TRIM),
//                 .REORDER_BY_LARGEST_ALIGNMENT_ALLOW_SMALL_FIELDS_IN_ALIGNED_WASTE_SPACE_TRIM_END => by_largest_align(TARGET_ENDIAN, .REFIT_SMALLER_FIELDS, .TRIM_END),
//                 .REORDER_BY_LARGEST_ALIGNMENT_DO_NOT_TRIM => by_largest_align(TARGET_ENDIAN, .NO_REFIT, .DO_NOT_TRIM),
//                 .REORDER_BY_LARGEST_ALIGNMENT_TRIM_END => by_largest_align(TARGET_ENDIAN, .NO_REFIT, .TRIM_END),
//                 .SAME_AS_THE_CURRENT_PLATFORM_AND_BUILD_MODE_SAME_SIZE => by_current_build(TARGET_ENDIAN, .DO_NOT_TRIM),
//                 .SAME_AS_THE_CURRENT_PLATFORM_AND_BUILD_MODE_TRIM_END => by_current_build(TARGET_ENDIAN, .TRIM_END),
//             };
//             self.flatten_fields(TARGET_ENDIAN, MODE, alloc);
//             self.consolidate(TARGET_ENDIAN);
//             return self;
//         }

//         fn consolidate(comptime self: *Self) void {
//             self.consolidated = comptime .init_capacity(@intCast(self.flattened.len), self.alloc);
//             const all_fields = self.flattened.slice();
//             if (all_fields.len == 0) return;
//             comptime var curr_field_idx: u32 = 1;
//             comptime var prev_consolidate_mode: DataMoveOp = all_fields[0].op;
//             comptime var prev_move_delta: i32 = num_cast(all_fields[0].native_offset, i32) - num_cast(all_fields[0].serial_offset, i32);
//             comptime var prev_field_offset = all_fields[0];
//             comptime var curr_consolidate: DataMove = prev_field_offset.to_data_move(prev_consolidate_mode.should_swap());
//             if (all_fields.len == 1) {
//                 _ = self.consolidated.append(prev_field_offset.to_data_move(prev_consolidate_mode.should_swap()), self.alloc);
//                 return;
//             }
//             while (curr_field_idx < all_fields.len) {
//                 const curr_field_offset = all_fields[curr_field_idx];
//                 const curr_move_delta: i32 = num_cast(curr_field_offset.native_offset, i32) - num_cast(curr_field_offset.serial_offset, i32);
//                 const curr_consolidate_mode = curr_field_offset.op;
//                 if (prev_consolidate_mode.same_consolidate_mode(curr_consolidate_mode) and prev_move_delta == curr_move_delta and curr_field_offset.serial_offset - prev_field_offset.serial_end() <= MAX_UNDEFINED_BYTES_TO_COPY_IN_ADJACENT_OPS) {
//                     curr_consolidate.combine_with_field_offset(curr_field_offset);
//                 } else {
//                     _ = self.consolidated.append(curr_consolidate, self.alloc);
//                 }
//                 prev_field_offset = curr_field_offset;
//                 prev_consolidate_mode = curr_consolidate_mode;
//                 prev_move_delta = num_cast(prev_field_offset.native_offset, i32) - num_cast(prev_field_offset.serial_offset, i32);
//                 curr_field_idx += 1;
//             }
//         }

//         fn flatten_fields(comptime self: *Self, comptime TARGET_ENDIAN: Endian, comptime MODE: StructPackingMode, comptime alloc: Allocator) void {
//             self.flattened = comptime .init_capacity(@intCast(FIELDS_LEN), alloc);
//             self.flattened_alloc = alloc;
//             comptime var iter = self.new_field_iterator(TARGET_ENDIAN, MODE, alloc);
//             while (comptime iter.next(TARGET_ENDIAN, MODE)) |field_offset| {
//                 _ = comptime self.flattened.append(field_offset, alloc);
//             }
//             self.flattened_len = comptime self.flattened.len;
//         }

//         fn new_field_iterator(comptime self: *Self, comptime TARGET_ENDIAN: Endian, comptime MODE: StructPackingMode, comptime alloc: Allocator) FieldIterator {
//             var iter = FieldIterator{
//                 .ptr = self,
//                 .native_type = STRUCT,
//                 .alloc = alloc,
//             };
//             if (self.fields[0] == .SUB_STRUCTURE) {
//                 iter.init_sub_iterator(self.fields[0].SUB_STRUCTURE, TARGET_ENDIAN, MODE);
//             }
//             return iter;
//         }

//         pub const FieldIterator = struct {
//             ptr: *const Self,
//             native_type: type,
//             sub_iter: ?*anyopaque = null,
//             sub_offsets_result: ?*anyopaque = null,
//             sub_iter_type: type = void,
//             sub_offsets_result_type: type = void,
//             curr_field: usize = 0,
//             is_allocated: bool = false,
//             alloc: Allocator = DummyAllocator.allocator_panic_free_noop,
//             total_field_count: u32 = 0,
//             local_serial_offset: u32 = 0,
//             local_native_offset: u32 = 0,

//             pub fn init_sub_iterator(comptime self: *FieldIterator, comptime sub_structure: FieldSubStructure, comptime TARGET_ENDIAN: Endian, comptime MODE: StructPackingMode) void {
//                 const SUB_KIND = KindInfo.get_kind_info(sub_structure.field_type);
//                 const SUB_OFFSET_TYPE = switch (SUB_KIND) {
//                     .STRUCT => StructOffsetsResult(sub_structure.field_type),
//                     else => assert_unreachable(@src(), " field with kind `{s}` does not have an implemented sub-structure routine", .{@tagName(SUB_KIND)}),
//                 };
//                 const sub_offsets_ptr = comptime self.alloc.create(SUB_OFFSET_TYPE) catch |err| assert_allocation_failure(@src(), SUB_OFFSET_TYPE, 1, err);
//                 sub_offsets_ptr.* = SUB_OFFSET_TYPE.create(TARGET_ENDIAN, MODE);
//                 self.sub_offsets_result = @ptrCast(sub_offsets_ptr);
//                 self.sub_offsets_result_type = SUB_OFFSET_TYPE;
//                 const sub_iter_ptr = comptime self.alloc.create(SUB_OFFSET_TYPE.FieldIterator) catch |err| assert_allocation_failure(@src(), SUB_OFFSET_TYPE.FieldIterator, 1, err);
//                 sub_iter_ptr.* = sub_offsets_ptr.new_field_iterator(TARGET_ENDIAN, MODE, self.alloc);
//                 self.sub_iter = sub_iter_ptr;
//                 self.sub_iter_type = SUB_OFFSET_TYPE.FieldIterator;
//             }

//             pub fn sub_iterator_next(comptime self: *FieldIterator) ?FieldOffset {
//                 if (comptime self.sub_iter) |sub_iter_opaque| {
//                     const sub_iter: *self.sub_iter_type = @ptrCast(@alignCast(sub_iter_opaque));
//                     if (comptime sub_iter.next()) |field_offset| {
//                         var adjusted_field_offset = field_offset;
//                         self.
//                         return field_offset;
//                     } else {
//                         self.total_field_count += sub_iter.total_field_count;
//                         self.ptr.num_sub_structure_bytes_to_eval -= @sizeOf(sub_iter.field_type);
//                         const sub_offsets: *self.sub_offsets_result_type = @ptrCast(@alignCast(self.sub_offsets_result.?));
//                         self.ptr.total_waste_bytes += sub_offsets.total_waste_bytes;
//                         self.alloc.destroy(sub_iter);
//                         self.alloc.destroy(sub_offsets);
//                         self.sub_iter = null;
//                         self.sub_offsets_result = null;
//                         self.curr_field += 1;
//                     }
//                 }
//                 return null;
//             }

//             fn has_next(comptime self: FieldIterator) bool {
//                 return self.curr_field < FIELDS_LEN;
//             }

//             pub fn next(comptime self: *FieldIterator, comptime TARGET_ENDIAN: Endian, comptime MODE: StructPackingMode) ?FieldOffset {
//                 if (self.sub_iterator_next()) |sub_next| {
//                     return sub_next;
//                 }
//                 if (!self.has_next()) return null;
//                 const nxt = self.ptr.fields[self.curr_field];
//                 goto_next: switch (nxt) {
//                     .OFFSET => |field_offset| {
//                         self.curr_field += 1;
//                         self.total_field_count += 1;
//                         return field_offset;
//                     },
//                     .SUB_STRUCTURE => |sub_structure| {
//                         self.init_sub_iterator(sub_structure, TARGET_ENDIAN, MODE);
//                         if (self.sub_iterator_next()) |sub_next| {
//                             return sub_next;
//                         }
//                         if (!self.has_next()) return null;
//                         continue :goto_next self.ptr.fields[self.curr_field];
//                     },
//                 }
//             }
//         };

//         // pub const ReadResult = struct {
//         //     val: STRUCT,
//         //     bytes_read: usize,
//         // };

//         // pub fn num_consolidated_ops(comptime self: Self) usize {
//         //     comptime var total_ops: usize = 0;
//         //     comptime var last_defined_byte: usize = 0;
//         //     comptime var num_undefined_bytes_in_non_swap: usize = 0;
//         //     comptime var continue_op_1: DataMoveOp = .UNDEFINED_BYTE;
//         //     comptime var continue_op_2: DataMoveOp = .UNDEFINED_BYTE;
//         //     for (self.serial_byte_move_ops, 0..) |op, byte_idx| {
//         //         if (op != curr_op) {
//         //             assert_with_reason(op != .EVALUATE_SUB_LAYOUT, @src(), "cannot consolidate ops when there are still un-evaluated sub-stucture bytes", .{});
//         //             if (curr_op == .UNDEFINED_BYTE or op != .UNDEFINED_BYTE) {
//         //                 total_ops += 1;
//         //             }
//         //             curr_op = op;
//         //         }
//         //     }
//         //     return total_ops;
//         // }

//         // pub fn num_consolidated_ops(comptime self: Self) usize {
//         //     comptime var total_ops: usize = 0;
//         //     comptime var last_defined_byte: usize = 0;
//         //     comptime var num_undefined_bytes_in_non_swap: usize = 0;
//         //     comptime var continue_op_1: DataMoveOp = .UNDEFINED_BYTE;
//         //     comptime var continue_op_2: DataMoveOp = .UNDEFINED_BYTE;
//         //     for (self.serial_byte_move_ops, 0..) |op, byte_idx| {
//         //         if (op != curr_op) {
//         //             assert_with_reason(op != .EVALUATE_SUB_LAYOUT, @src(), "cannot consolidate ops when there are still un-evaluated sub-stucture bytes", .{});
//         //             if (curr_op == .UNDEFINED_BYTE or op != .UNDEFINED_BYTE) {
//         //                 total_ops += 1;
//         //             }
//         //             curr_op = op;
//         //         }
//         //     }
//         //     return total_ops;
//         // }

//         // pub fn consolidate_ops(comptime self: Self) [self.num_consolidated_ops()]DataMove {
//         //     comptime var moves: [self.num_consolidated_ops()]DataMove = undefined;
//         //     comptime var op_idx: usize = 0;
//         //     comptime var op_start: u32 = 0;
//         //     comptime var op_end: u32 = 0;
//         //     for (self.serial_byte_move_ops, 0..) |op, byte_idx| {
//         //         if (op != curr_op) {
//         //             if (curr_op == .UNDEFINED_BYTE or op != .UNDEFINED_BYTE) {
//         //                 total_ops += 1;
//         //             }
//         //             curr_op = op;
//         //         }
//         //     }
//         //     return total_ops;
//         // }

//         // pub fn concrete(comptime self: Self) SerialContract(STRUCT, self., comptime STEPS_: [?]DataMove)

//         fn by_field_order(comptime TARGET_ENDIAN: Endian, comptime TIGHTNESS: Tightness, comptime TRIM_END: TrimEndMode) Self {
//             comptime var out_fields: [INFO.fields.len]FieldOffset = undefined;
//             comptime var curr_offset: usize = 0;
//             inline for (INFO.fields, 0..) |field, i| {
//                 const ALIGN = @alignOf(field.type);
//                 const SIZE = @alignOf(field.type);
//                 if (TIGHTNESS == .NATURALLY_PACKED) {
//                     curr_offset = std.mem.alignForward(usize, curr_offset, ALIGN);
//                 }
//                 out_fields[i] = FieldOffset{
//                     .name = field.name,
//                     .field_type = field.type,
//                     .serial_offset = curr_offset,
//                     .native_offset = @offsetOf(STRUCT, field.name),
//                 };
//                 curr_offset += SIZE;
//             }
//             var result = Self{
//                 .fields = out_fields,
//                 .total_byte_len = curr_offset,
//             };
//             if (TRIM_END == .DO_NOT_TRIM) {
//                 result.total_byte_len = @max(result.total_byte_len, @sizeOf(STRUCT));
//             }
//             result.eval_ops_and_waste(TARGET_ENDIAN);
//             return result;
//         }

//         fn by_largest_align(comptime TARGET_ENDIAN: Endian, comptime REFIT: RefitMode, comptime TRIM_END: TrimEndMode) Self {
//             const MAX_EMPTY_LEN = FIELDS_LEN * 4;
//             comptime var out_fields: [FIELDS_LEN]FieldOffset = undefined;
//             comptime var empty_spaces: if (REFIT == .REFIT_SMALLER_FIELDS) [MAX_EMPTY_LEN]OffsetAndSpace else void = undefined;
//             comptime var empty_spaces_len: if (REFIT == .REFIT_SMALLER_FIELDS) usize else u0 = 0;
//             comptime var largest_align: usize = 1;
//             comptime var first_smallest_align_idx: usize = 0;
//             inline for (INFO.fields, 0..) |field, i| {
//                 const ALIGN = @alignOf(field.type);
//                 if (ALIGN == largest_align) {
//                     first_smallest_align_idx += 1;
//                 } else if (ALIGN > largest_align) {
//                     largest_align = ALIGN;
//                     first_smallest_align_idx = 1;
//                 }
//                 out_fields[i] = FieldOffset{
//                     .name = field.name,
//                     .field_type = field.type,
//                     .serial_offset = ALIGN,
//                     .native_offset = @offsetOf(STRUCT, field.name),
//                 };
//             }
//             Utils.mem_sort(@ptrCast(&out_fields[0]), 0, FIELDS_LEN, void{}, FieldOffset.sort_smaller_offset_to_the_right);
//             comptime var curr_offset: usize = 0;
//             inline for (out_fields[0..], 0..) |*field, i| {
//                 const TYPE = @FieldType(STRUCT, field.name);
//                 const ALIGN = field.serial_offset;
//                 assert_with_reason(ALIGN <= largest_align, @src(), "sorting did not put fields in order by align", .{});
//                 largest_align = ALIGN;
//                 const SIZE = @sizeOf(TYPE);
//                 if (i > 0) {
//                     const old_curr_offset = curr_offset;
//                     curr_offset = std.mem.alignForward(usize, curr_offset, ALIGN);
//                     if (REFIT == .REFIT_SMALLER_FIELDS) {
//                         const waste = curr_offset - old_curr_offset;
//                         if (waste > 0) {
//                             empty_spaces[empty_spaces_len] = OffsetAndSpace{
//                                 .offset = old_curr_offset,
//                                 .space = waste,
//                             };
//                             empty_spaces_len += 1;
//                         }
//                     }
//                 }
//                 field.serial_offset = curr_offset;
//                 curr_offset += SIZE;
//             }
//             if (REFIT == .REFIT_SMALLER_FIELDS) {
//                 Utils.mem_sort(@ptrCast(&empty_spaces[0]), 0, empty_spaces_len, void{}, OffsetAndSpace.sort_larger_spaces_to_the_right);
//                 inline for (out_fields[first_smallest_align_idx..]) |*field| {
//                     inline for (empty_spaces[0..empty_spaces_len], 0..) |*empty, e| {
//                         const TYPE = @FieldType(STRUCT, field.name);
//                         const ALIGN = @alignOf(TYPE);
//                         const SIZE = @sizeOf(TYPE);
//                         if (empty.space >= SIZE) {
//                             const old_empty_offset = empty.offset;
//                             const aligned_empty_offset = std.mem.alignForward(usize, old_empty_offset, ALIGN);
//                             const new_waste_before = aligned_empty_offset - old_empty_offset;
//                             const aligned_space = empty.space - new_waste_before;
//                             if (aligned_space >= SIZE) {
//                                 field.serial_offset = aligned_empty_offset;
//                                 const new_waste_after = empty.space - new_waste_before - SIZE;
//                                 if (new_waste_before == 0 and new_waste_after == 0) {
//                                     Utils.mem_remove(@ptrCast(&empty_spaces[0]), &empty_spaces_len, e, 1);
//                                 } else if (new_waste_before == 0) {
//                                     const new_empty_offset = old_empty_offset + SIZE;
//                                     empty.offset = new_empty_offset;
//                                     empty.space = new_waste_after;
//                                 } else if (new_waste_after == 0) {
//                                     empty.space = new_waste_before;
//                                 } else {
//                                     empty.space = new_waste_before;
//                                     empty_spaces[empty_spaces_len] = OffsetAndSpace{
//                                         .offset = aligned_empty_offset + SIZE,
//                                         .space = new_waste_after,
//                                     };
//                                     empty_spaces_len += 1;
//                                     Utils.mem_sort(@ptrCast(&empty_spaces[0]), 0, empty_spaces_len, void{}, OffsetAndSpace.sort_larger_spaces_to_the_right);
//                                 }
//                                 break;
//                             }
//                         }
//                     }
//                 }
//                 Utils.mem_sort(@ptrCast(&out_fields[0]), 0, FIELDS_LEN, void{}, FieldOffset.sort_smaller_offset_to_the_left);
//             }
//             curr_offset = 0;
//             inline for (out_fields[0..], 0..) |field, i| {
//                 const TYPE = @FieldType(STRUCT, field.name);
//                 const SIZE = @sizeOf(TYPE);
//                 const ALIGN = @alignOf(TYPE);
//                 assert_with_reason(field.serial_offset >= curr_offset, @src(), "layout caused field `{s}` and field `{s}` to have overlapping memory", .{ out_fields[i - 1].name, field.name });
//                 assert_with_reason(std.mem.isAligned(field.serial_offset, ALIGN), @src(), "layout caused field `{s}` to be mis-aligned for its type", .{field.name});
//                 curr_offset = field.serial_offset + SIZE;
//             }
//             var result = StructOffsetsResult(STRUCT){
//                 .fields = out_fields,
//                 .total_byte_len = curr_offset,
//             };
//             if (TRIM_END == .DO_NOT_TRIM) {
//                 result.total_byte_len = @max(result.total_byte_len, @sizeOf(STRUCT));
//             }
//             result.eval_ops_and_waste(TARGET_ENDIAN);
//             return result;
//         }

//         fn by_current_build(comptime TARGET_ENDIAN: Endian, comptime TRIM_END: TrimEndMode) Self {
//             comptime var out_fields: [FIELDS_LEN]FieldOffset = undefined;
//             inline for (INFO.fields, 0..) |field, i| {
//                 out_fields[i] = FieldOffset{
//                     .name = field.name,
//                     .field_type = field.type,
//                     .serial_offset = @offsetOf(STRUCT, field.name),
//                     .native_offset = @offsetOf(STRUCT, field.name),
//                 };
//             }
//             Utils.mem_sort(@ptrCast(&out_fields[0]), 0, FIELDS_LEN, void{}, FieldOffset.sort_smaller_offset_to_the_left);
//             var result = StructOffsetsResult(STRUCT){
//                 .fields = out_fields,
//                 .total_byte_len = (out_fields[FIELDS_LEN - 1].native_offset + @sizeOf(out_fields[FIELDS_LEN - 1].field_type)),
//             };
//             if (TRIM_END == .DO_NOT_TRIM) {
//                 result.total_byte_len = @max(result.total_byte_len, @sizeOf(STRUCT));
//             }
//             result.eval_ops_and_waste(TARGET_ENDIAN);
//             return result;
//         }

//         fn eval_ops_and_waste(comptime self: *Self, comptime TARGET_ENDIAN: Endian) void {
//             self.total_waste_bytes = self.total_byte_len;
//             const SWAP_ENDIAN = TARGET_ENDIAN != NATIVE_ENDIAN;
//             inline for (self.fields, 0..) |field, i| {
//                 const SIZE = @sizeOf(field.field_type);
//                 const KIND = KindInfo.get_kind_info(field.field_type);
//                 const WRONG_OFFSET = field.native_offset != field.serial_offset;
//                 var fill: DataMoveOp = .UNDEFINED_BYTE;
//                 if (KIND.is_kind_with_sub_structure()) {
//                     fill = .EVALUATE_SUB_LAYOUT;
//                     self.field_sub_layouts[i] = .EVALUATE_SUB_LAYOUT;
//                     self.num_sub_structure_bytes_to_eval += SIZE;
//                 } else if (WRONG_OFFSET or (SIZE > 1 and SWAP_ENDIAN)) {
//                     if (WRONG_OFFSET and (SIZE > 1 and SWAP_ENDIAN)) {
//                         fill = .MOVE_AND_SWAP;
//                     } else if (WRONG_OFFSET and !(SIZE > 1 and SWAP_ENDIAN)) {
//                         fill = .MOVE_NO_SWAP;
//                     } else { // !WRONG_OFFSET and (SIZE > 1 and SWAP_ENDIAN)
//                         fill = .SWAP_IN_PLACE;
//                     }
//                     self.all_fields_completely_native = false;
//                 } else {
//                     fill = .NO_MOVE_OR_SWAP;
//                 }
//                 const end = field.serial_offset + SIZE;
//                 for (self.serial_byte_move_ops[field.serial_offset..end], field.serial_offset..) |curr_op, b| {
//                     assert_with_reason(curr_op == .UNDEFINED_BYTE, @src(), "serial layout caused field `{s}` had overlapping data at byte {d}", .{ field.name, b });
//                 }
//                 @memset(self.serial_byte_move_ops[field.serial_offset..end], fill);
//                 self.total_waste_bytes -= SIZE;
//             }
//         }
//     };
// }

// test StructOffsetsResult {
//     const TEST = Root.Testing;
//     const STRUCT_1 = struct {
//         a: f32 = 3.1415,
//         b: bool = true,
//         c: u16 = 6969,
//         d: u8 = 42,
//     };
//     const STRUCT_1_LAYOUT = comptime StructOffsetsResult(STRUCT_1).create(NATIVE_ENDIAN, .BY_FIELD_ORDER_PROPER_ALIGNMENT_DO_NOT_TRIM);
//     try TEST.expect_strings_equal(STRUCT_1_LAYOUT.fields[0].name, "STRUCT_1_LAYOUT.fields[0].name", "a", "'a'", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.fields[0].serial_offset, "STRUCT_1_LAYOUT.fields[0].serial_offset", 0, "0", "fail", .{});
//     try TEST.expect_strings_equal(STRUCT_1_LAYOUT.fields[1].name, "STRUCT_1_LAYOUT.fields[1].name", "b", "'b'", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.fields[1].serial_offset, "STRUCT_1_LAYOUT.fields[1].serial_offset", 4, "4", "fail", .{});
//     try TEST.expect_strings_equal(STRUCT_1_LAYOUT.fields[2].name, "STRUCT_1_LAYOUT.fields[2].name", "c", "'c'", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.fields[2].serial_offset, "STRUCT_1_LAYOUT.fields[2].serial_offset", 6, "6", "fail", .{});
//     try TEST.expect_strings_equal(STRUCT_1_LAYOUT.fields[3].name, "STRUCT_1_LAYOUT.fields[3].name", "d", "'d'", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.fields[3].serial_offset, "STRUCT_1_LAYOUT.fields[3].serial_offset", 8, "8", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.all_fields_completely_native, "STRUCT_1_LAYOUT.all_fields_completely_native", false, "false", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.total_byte_len, "STRUCT_1_LAYOUT.total_byte_len", 9, "9", "fail", .{});
//     try TEST.expect_equal(STRUCT_1_LAYOUT.total_waste_bytes, "STRUCT_1_LAYOUT.total_waste_bytes", 1, "1", "fail", .{});
// }

// // pub const SubBuildResult = struct {
// //     start: u32,
// //     end: u32,
// // };

// // pub const DataMoveBuilder = struct {
// //     ptr: [*]DataMoveWithExtra = Utils.invalid_ptr_many(DataMoveWithExtra),
// //     len: u32 = 0,
// //     cap: u32 = 0,
// //     max_align: u32 = 1,
// //     alloc: Allocator,
// //     swap_endian: bool,
// //     tightly_pack: bool,
// //     complete_layout_match: bool = true,

// //     pub fn curr_move(self: *DataMoveBuilder) *DataMoveWithExtra {
// //         if (self.len == 0) return self.add_move();
// //         return &self.ptr[self.len - 1];
// //     }

// // pub fn init(comptime target_endian: Endian, comptime packing: StructPacking, comptime init_move_cap: u32, comptime alloc: Allocator) DataMoveBuilder {
// //     var self = DataMoveBuilder{
// //         .swap_endian = target_endian != NATIVE_ENDIAN,
// //         .tightly_pack = packing == .TIGHTLY_PACK,
// //         .alloc = alloc,
// //     };
// //     Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.ptr, &self.cap, @intCast(init_move_cap), .{}, .{});
// //     return self;
// // }

// // pub fn add_move(comptime self: *DataMoveBuilder) *DataMoveWithExtra {
// //     if (self.len >= self.cap) {
// //         Utils.Alloc.smart_alloc_ptr_ptrs(self.alloc, &self.ptr, &self.cap, @intCast(self.len + 1), .{}, .{});
// //     }
// //     const ptr: *DataMoveWithExtra = &self.ptr[self.len];
// //     ptr.native_pos = if (self.len == 0) 0 else self.curr_move().native_end();
// //     ptr.serial_pos = if (self.len == 0) 0 else self.curr_move().serial_end();
// //     ptr.len = 0;
// //     self.len += 1;
// //     return ptr;
// // }

// // pub fn sub_build(comptime self: *DataMoveBuilder, comptime serial_offset: u32, comptime parent_root_offset: u32, comptime field_offset: u32, comptime TYPE: type) void {
// //     const KIND = KindInfo.get_kind_info(TYPE);
// //     switch (KIND) {
// //         .BOOL, .INT, .FLOAT, .ENUM => {
// //             if (serial_offset == parent_root_offset + field_offset) {
// //                 const move = self.curr_move();
// //             }
// //         },
// //         else => {},
// //     }
// // }

// // pub fn build(comptime self: *DataMoveBuilder, comptime ROOT_TYPE: type) void {
// //     const INFO = KindInfo.get_kind_info(ROOT_TYPE);
// //     var serial_pos: u32 = 0;
// //     var parent_root: u32 = 0;
// //     var field_offset: u32 = 0;
// //     inline for (INFO.fields) |field| {
// //         const field_offset = @offsetOf(ROOT_TYPE, field.name);
// //         //CHECKPOINT
// //     }
// // }

// // pub fn build(comptime self: *DataMoveBuilder, comptime parent_offset: u32, comptime TYPE: type) void {
// //     const INFO = KindInfo.get_kind_info(TYPE);
// //     const SIZE = @sizeOf(TYPE);
// //     const ALIGN = @alignOf(TYPE);
// //     if (SIZE == 0) return;
// //     var move: *DataMoveWithExtra = if (self.len == 0) self.add_move() else self.curr_move();
// //     var curr_native = move.native_end();
// //     var curr_serial = move.serial_end();
// //     var req_native =  curr_native
// //     re_eval: switch (INFO) {
// //         .BOOL, .INT, .FLOAT, .ENUM => {

// //             if (!self.tightly_pack and !std.mem.isAligned(@intCast(curr_serial), ALIGN)) {
// //                 move = self.add_move();
// //                 move.serial_pos = std.mem.alignForward(u32, move.serial_pos, ALIGN);
// //                 move.serial_pos = move.native_pos;
// //             } else if (!(SIZE == 1 and move.largest_type == 1) and self.swap_endian) {
// //                 move = self.add_move();
// //                 move.serial_pos = move.native_pos;
// //             } else if ()
// //             move.serial_pos += SIZE;
// //             move.len += SIZE;
// //             self.max_align = @max(self.max_align, ALIGN);
// //         },
// //         .POINTER => {
// //             assert_unreachable(@src(), "pointer types cannot be serialized, got `{s}`", .{@typeName(TYPE)});
// //         },
// //         .ARRAY, .VECTOR => {
// //             const CHILD = if (INFO == .ARRAY) INFO.ARRAY.child else INFO.VECTOR.child;
// //             const CHILD_SIZE = @sizeOf(CHILD);
// //             const LEN = if (INFO == .ARRAY) INFO.ARRAY.len else INFO.VECTOR.len;
// //             if (LEN or CHILD_SIZE == 0) return;
// //             if (LEN == 1) continue :re_eval KindInfo.get_kind_info(CHILD);
// //             const prev_move_len = self.len;
// //             self.build(CHILD);
// //             if (prev_move_len != self.len) {
// //                 const delta = self.total_offset - prev_move_offset;
// //                 const add_delta = delta * (I.len - 1);
// //                 self.curr_move().serial_pos += add_delta;
// //                 return .NATIVE;
// //             } else {}
// //         },
// //     }
// // }

// //     pub fn stats(comptime builder: DataMoveBuilder) DataMoveStats {
// //         return DataMoveStats{
// //             .len = builder.len,
// //             .swap_endian = builder.swap_endian,
// //         };
// //     }
// // };

// // const DataMoveStats = struct {
// //     len: u32,
// //     swap_endian: bool,
// // };

// // pub fn DataMoveRoutine(comptime stats: DataMoveStats) type {
// //     return struct {
// //         moves: [stats.len]DataMoveWithExtra,
// //         swap_endian: bool,
// //     };
// // }

// // pub fn SerialTypeAdapter(comptime TARGET_TYPE: type) type {
// //     comptime var total_bytes: usize = 0;
// //     comptime var max_align: usize = 1;
// //     const INFO = KindInfo.get_kind_info(TARGET_TYPE);
// //     switch (INFO) {
// //         .BOOL => {
// //             total_bytes = 1;
// //         },
// //         .INT => {
// //             total_bytes = @sizeOf(TARGET_TYPE);
// //             max_align = @alignOf(TARGET_TYPE);
// //         },
// //     }
// //     const total_bytes_const = total_bytes;
// //     const max_align_const = max_align;
// //     return extern struct {
// //         bytes: [total_bytes_const]u8 align(max_align_const),
// //     };
// // }
