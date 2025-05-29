//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const mem = std.mem;
const math = std.math;
const Allocator = std.mem.Allocator;
const build = @import("builtin");
const assert = std.debug.assert;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const List = Root.CollectionTypes.StaticAllocList;

pub const Options = struct {
    /// This MUST be an `enum` type, where each enum key is a field name
    /// and each enum value must be in numeric order starting from 0, with no gaps.
    ///
    /// All of these names MUST be in order from largest align of their intended type to smallest
    field_keys: type,
    /// A list of types the correspond to their matching names in the `field_keys` enum
    ///
    /// All of these types MUST be in order from largest align to smallest
    field_types: []const type,
    /// The width of the `@Vector()` returned by the respective functions
    vec_size: comptime_int,
    allocator: *const Allocator,
    alignment: ?u29 = null,
    alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_WITH_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
    default_sorting_algorithm: SortAlgorithm = SortAlgorithm.QUICK_SORT_PIVOT_MEDIAN_OF_3,
};

// pub fn define_vectorized_struct_of_arrays(comptime options: Options) type {
//     if (build.mode == .Debug or build.mode == .ReleaseSafe) {}
//     const ListOptionsU8 = List.ListOptions{
//         .alignment = options.alignment,
//         .alloc_error_behavior = options.alloc_error_behavior,
//         .default_sorting_algorithm = options.default_sorting_algorithm,
//         .element_type = u8,
//         .allocator = options.allocator,
//         .growth_model = options.growth_model,
//         .index_type = usize,
//         .order_value_func_struct = null,
//         .order_value_type = null,
//         .secure_wipe_bytes = false,
//     };
//     if (@typeInfo(options.index_type) != Type.int or @typeInfo(options.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
//     // Check fields for validity and build offset table
//     const field_enum_meta = @typeInfo(options.field_enum_type).@"enum";
//     const field_count = field_enum_meta.fields.len;
//     if (field_count == 0) @panic("must have at least one field\n");
//     if (field_count != options.field_types.len) @panic("field key enum count does not equal field type list count");
//     var offsets: [field_count]usize = undefined;
//     const largest_align: u29 = @alignOf(options.field_types[0]);
//     var last_align: u29 = largest_align;
//     var i: usize = 0;
//     var offset: usize = 0;
//     while (i < field_count) : (i += 1) {
//         if (i != field_enum_meta.fields[i].value) std.debug.panic("enum key value ({s}: index = {d}) does not match index {d}", .{ field_enum_meta.fields[i].name, field_enum_meta.fields[i].value, i });
//         const this_align = @alignOf(options.field_types[i]);
//         if (this_align > last_align) std.debug.panic("fields not in order from largest align to smallest:\n{s}: index = {d}, align = {d}\n{s}: index = {d}, align = {d}\n", .{
//             field_enum_meta.fields[i - 1].name, i - 1, @alignOf(options.field_types[i - 1]),
//             field_enum_meta.fields[i].name,     i,     @alignOf(options.field_types[i]),
//         });
//         last_align = this_align;
//         offsets[i] = offset;
//         offset += @sizeOf(options.field_types[i]);
//     }
//     const const_offsets = make: {
//         const arr: [field_count]usize = undefined;
//         @memcpy(arr, offsets);
//         break :make arr;
//     };
//     const const_types = make: {
//         const arr: [field_count]type = undefined;
//         @memcpy(arr, options.field_types[0..field_count]);
//         break :make arr;
//     };
//     return struct {
//         mem: List(ListOptionsU8) = List(ListOptionsU8){},
//         len: Idx = 0,
//         cap: Idx = 0,
//         offsets: [FIELD_COUNT]usize = @splat(0),

//         const Self = @This();
//         const Idx = options.index_type;
//         const TYPE_TABLE = const_types;
//         const BASE_OFFSET_TABLE = const_offsets;
//         const FIELD_COUNT = field_count;

//         pub inline fn get(self: *const Self, idx: usize) T {
//             return self.array[idx].*;
//         }
//         pub inline fn set(self: *Self, idx: usize, val: T) void {
//             VALIDATION.validate(val);
//             self.array[idx].* = val;
//         }

//         pub inline fn vec_array(self: *Self) *[MAX_VECS]@Vector(VEC_SIZE, T) {
//             return @ptrCast(@alignCast(&self.array));
//         }
//         pub inline fn vec_get(self: *Self, vec_idx: usize) @Vector(VEC_SIZE, T) {
//             return self.vec_array()[vec_idx].*;
//         }
//         pub inline fn vec_set(self: *Self, vec_idx: usize, vec: @Vector(VEC_SIZE, T)) void {
//             VALIDATION.vec_validate(vec);
//             self.vec_array()[vec_idx].* = vec;
//         }
//     };
// }

// pub fn iota_plus_one_last_max(comptime LEN: comptime_int, comptime T: type) [LEN]T {
//     const arr = [LEN]T;
//     var i: T = 0;
//     while (i < LEN - 1) : (i += 1) {
//         arr[i].* = i + 1;
//     }
//     arr[i].* = math.maxInt(T);
//     return arr;
// }
