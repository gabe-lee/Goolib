//! This module is intended to create shader 'contracts' for passing data to and from
//! a shader from the cpu in the correct order/location/alignment
//!
//! `UniformStruct` is designed to follow `std140` alignment conventions
//! for maximum simplicity and portability, and will automatically find the 'best'
//! way to pack a given set of fields for minimal waste.
//!
//! For compatibility reasons, types that are not 32 bits wide are only supported with 'packed' types and must be
//! unpacked on the GPU side either using a provided function or manually. Some platforms allow native 'double' and 'half',
//! types, but those are nut supported by this API.
//!
//! The `GPU_bool` type takes a `Bool32` enum with `.TRUE` and `.FALSE`
//! tags to guarantee compatibility with the expected 32-bit gpu bool
//!
//! Matrices are not directly supported for vertex buffers, but you
//! can pack and unpack one yourself, if you so choose
//!
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
const math = std.math;
const build = @import("builtin");
const config = @import("config");
const init_zero = std.mem.zeroes;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;
const Assert = Root.Assert;
const Vec2 = Root.Vec2;
const Vec3 = Root.Vec3;
const Vec4 = Root.Vec4;
const Matrix = Root.Matrix;
const Common = Root.CommonTypes;
const Bool32 = Common.Bool32;
const Sort = Root.Sort.InsertionSort;
const QuickWriter = Root.QuickWriter;
const IncludeOffests = Common.IncludeOffests;
const SDL3 = Root.SDL3;
const GPU_VertexElementFormat = SDL3.GPU_VertexElementFormat;
const InterfaceSignature = Types.InterfaceSignature;
const MethodDefinition = Types.MethodDefinition;
const ParamDefinition = Types.ParamDefinition;
const SourceLocation = std.builtin.SourceLocation;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_comptime_write_failure = Assert.assert_comptime_write_failure;
const num_cast = Cast.num_cast;
const bit_cast = Cast.bit_cast;

const define_vec2_type = Vec2.define_vec2_type;
const define_vec3_type = Vec3.define_vec3_type;
const define_vec4_type = Vec4.define_vec4_type;
const define_matx_type = Matrix.define_rectangular_RxC_matrix_type;

const DEBUG = std.debug.print;

const BufferSpan = struct {
    offset: usize,
    len: usize,
};
const FieldOrPadKind = enum(u8) {
    FIELD,
    PAD,
};

const FieldOrPad = union(FieldOrPadKind) {
    FIELD: usize,
    PAD: BufferSpan,

    fn field_or_pad_offset_larger(a: FieldOrPad, b: FieldOrPad, field_locations: []const usize) bool {
        const a_off = switch (a) {
            .FIELD => |f| field_locations[f],
            .PAD => |p| p.offset,
        };
        const b_off = switch (b) {
            .FIELD => |f| field_locations[f],
            .PAD => |p| p.offset,
        };
        return a_off > b_off;
    }
};

const PadSize = enum(u8) {
    PAD_1 = 0,
    PAD_2 = 1,
    PAD_4 = 2,
    PAD_8 = 3,
    PAD_16 = 4,

    const COUNT = 5;
};

const SPACE_4 = "    ";
const SEMICOL = ';';
const SPACE = ' ';
const COLON = ':';
const COLON_SPACE = ": ";
const SPACE_COLON_SPACE = " : ";
const SPACE_COLON_SPACE_REGISTER = " : register(";
const HLSL_UNIFORM_REGISTER = 'b';
const HLSL_TEXTURE_REGISTER = 't';
const HLSL_SAMPLER_REGISTER = 's';
const HLSL_UNORDERED_REGISTER = 'u';
const COMMA_SPACE_HLSL_LAYER = ", space";
const OPEN_PAREN = '(';
const CLOSE_PAREN = ')';
const CLOSE_PAREN_NEWLINE = ")\n";
const CLOSE_PAREN_SEMICOL_NEWLINE = ");\n";
const OPEN_BRACKET = '{';
const SPACE_OPEN_BRACKET_NEWLINE = " {\n";
const CLOSE_BRACKET = '}';
const NEWLINE_CLOSE_BRACKET_SEMICOL_NEWLINE = "\n};\n";
const CLOSE_PAREN_SPACE_OPEN_BRACKET_NEWLINE = ") {\n";
const SEMICOL_NEWLINE = ";\n";
const SEMICOL_NEWLINE_4_SPACE = ";\n    ";
const NEWLINE_4_SPACE = "\n    ";
const SEMICOL_SPACE_COMMENT_OFF = "; // off ";
const SEMICOL_SPACE = "; ";
const COMMENT_OFF_SPACE = "// off ";
const COMMENT_SPACE_ENUM_SPACE = "// enum ";
const COMMENT_TOTAL_SIZE = "    // TOTAL = ";
const USED_SIZE = "   USED = ";
const WASTE_SIZE = "   WASTE = ";
const PAREN_PERCENT = " (%";
const SPACE_SIZE_SPACE = "  size ";
const SPACE_PAD_PREFIX = " __pad__";
const HLSL_CBUFFER_SPACE = "cbuffer ";
const HLSL_STRUCTURED_BUFFER = "StructuredBuffer<";
const CLOSE_ANGLE_BRACKET_SPACE = "> ";
const INVALID_STR = "INVALID";
const STRUCT_SPACE = "struct ";
const NEWLINE = '\n';
const DEFINE_SPACE = "#define ";
const UNDERSCORE = '_';
const DOUBLE_UNDERSCORE = "__";

const HLSL_PAD_TYPES = [5]HLSL_NAME{
    HLSL_NAME.uint, // no 1 byte types supported
    HLSL_NAME.uint, // no 2 byte types directly supported
    HLSL_NAME.uint,
    HLSL_NAME.uint2,
    HLSL_NAME.uint4,
};
const LONGEST_GPU_NAME = 15;
const HLSL_STRUCT_LINE_EXTRA = 8;
const LAYOUT_LINE_EXTRA = 22;
const LONGEST_PADDING_NAME_PLUS_TYPE = 17;
const SHORTEST_PADDING_NAME_PLUS_TYPE = 12;

const GPU_CACHE_LINE = 128;
const GPU_UNIFORM_BOUNDARY_ALIGN = 16;

pub const IncludeLayoutInStub = enum(u8) {
    NO_LAYOUT_COMMENTS_IN_SHADER_STUB,
    INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
};

/// A struct field within a `StorageStruct(FIELDS)`
///
/// Follows `std140` packing rules
pub fn StorageStructField(comptime FIELDS: type) type {
    return struct {
        const Self = @This();

        field: FIELDS,
        gpu_type: GPUType,

        pub fn new(comptime field: FIELDS, comptime gpu_type: GPUType) Self {
            return Self{ .field = field, .gpu_type = gpu_type };
        }
    };
}

/// A struct that is written to a uniform/constant/storage buffer
///
/// Follows `std140` packing rules for SDL cross-compile compatability
pub fn StorageStruct(comptime FIELDS: type, comptime INCLUDE_LAYOUT: IncludeLayoutInStub, comptime fields: []const StorageStructField(FIELDS), comptime EVAL_QUOTA: comptime_int) type {
    @setEvalBranchQuota(EVAL_QUOTA);
    assert_with_reason(Types.type_is_enum(FIELDS) and Types.all_enum_values_start_from_zero_with_no_gaps(FIELDS), @src(), "type `FIELDS` must be an enum type, and all enum tags in `FIELDS` must start at zero and have no gaps up to the max tag value, got type `{s}`", .{@typeName(FIELDS)});
    const _NUM_FIELDS = Types.enum_defined_field_count(FIELDS);
    assert_with_reason(fields.len == _NUM_FIELDS, @src(), "the number of field names in `FIELDS` must equal the length of field definitions `fields`, got names {d} != {d} len", .{ _NUM_FIELDS, fields.len });
    const _Field = StorageStructField(FIELDS);
    const _LAYOUT = INCLUDE_LAYOUT == .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB;
    comptime var _fields: [_NUM_FIELDS]_Field = undefined;
    @memcpy(_fields[0.._NUM_FIELDS], fields);
    comptime var field_init: [_NUM_FIELDS]bool = @splat(false);
    comptime var field_locations: [_NUM_FIELDS]usize = undefined;
    comptime var field_types: [_NUM_FIELDS]type = undefined;
    comptime var field_sizes: [_NUM_FIELDS]usize = undefined;
    comptime var field_hlsl_names: [_NUM_FIELDS]HLSL_NAME = undefined;
    comptime var empty_spots: [_NUM_FIELDS * 2]BufferSpan = undefined;
    comptime var current_max_offset: usize = 0;
    const StorageStructFieldList = Root.GooListSlice.SliceMutableAdvanced(_Field, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    const BufferSpanList = Root.GooListSlice.SliceMutableAdvanced(BufferSpan, .WHOLE_STRUCTS, .SERIAL_INDEXES);
    comptime var _fields_list = StorageStructFieldList.from_slice_keep_data(_fields[0..]);
    comptime var empty_spots_list = BufferSpanList.from_slice_set_empty(empty_spots[0..]);
    const SORT = struct {
        fn align_lesser_then_size_lesser(list: StorageStructFieldList, idx_a: u32, val_b: _Field, _: void, comptime _: void) bool {
            if (list.get(idx_a).gpu_type.uniform_alignment < val_b.gpu_type.uniform_alignment) return true;
            return list.get(idx_a).gpu_type.uniform_size < val_b.gpu_type.uniform_size;
        }
        fn offset_larger(list: BufferSpanList, idx_a: u32, idx_b: u32, _: void, comptime _: void) bool {
            return list.get(idx_a).offset > list.get(idx_b).offset;
        }
    };
    _fields_list.insertion_sort_advanced(void{}, void{}, .COMPTIME_FN_BODY, void{}, SORT.align_lesser_then_size_lesser);
    // PACKING ALGORITHM
    for (_fields) |field| {
        const fidx = @intFromEnum(field.field);
        assert_with_reason(field_init[fidx] == false, @src(), "field `{s}` was defined more than once", .{@tagName(field.field)});
        field_init[fidx] = true;
        comptime var found_empty_space: bool = false;
        comptime var empty_spot_that_fits: usize = 0;
        comptime var empty_spot_offset: usize = math.maxInt(isize);
        comptime var empty_spot_space_after: usize = math.maxInt(isize);
        const needed_align = @max(field.gpu_type.uniform_alignment, field.gpu_type.cpu_align);
        for (empty_spots_list.zig_slice_entire(), 0..) |empty, e| {
            if (empty.len >= field.gpu_type.uniform_size) {
                const next_aligned_within_empty = Utils.Mem.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(empty.offset, field.gpu_type.uniform_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
                const len_lost = next_aligned_within_empty - empty.offset;
                if (len_lost >= empty.len) continue;
                const aligned_len = empty.len - len_lost;
                if (aligned_len >= field.gpu_type.uniform_size) {
                    const space_after = empty.len - len_lost - field.gpu_type.uniform_size;
                    comptime var potential_space_savings: isize = 0;
                    if (found_empty_space) {
                        @branchHint(.likely);
                        potential_space_savings += num_cast(empty_spot_offset, isize) - num_cast(len_lost, isize);
                        potential_space_savings += num_cast(empty_spot_space_after, isize) - num_cast(space_after, isize);
                    } else {
                        potential_space_savings = 1;
                    }
                    if (potential_space_savings > 0) {
                        empty_spot_that_fits = e;
                        empty_spot_offset = len_lost;
                        empty_spot_space_after = space_after;
                        found_empty_space = true;
                    }
                }
            }
        }
        comptime var field_loc: usize = undefined;
        if (found_empty_space) {
            const old_empty = empty_spots_list.get(@intCast(empty_spot_that_fits));
            comptime var overwrite_old_empty = true;
            if (empty_spot_offset > 0) {
                const new_empty_before = BufferSpan{
                    .offset = old_empty.offset,
                    .len = empty_spot_offset,
                };
                empty_spots_list.set(@intCast(empty_spot_that_fits), new_empty_before);
                overwrite_old_empty = false;
            }
            if (empty_spot_space_after > 0) {
                const new_empty_after = BufferSpan{
                    .offset = old_empty.offset + empty_spot_offset + field.gpu_type.uniform_size,
                    .len = empty_spot_space_after,
                };
                if (overwrite_old_empty) {
                    empty_spots_list.set(@intCast(empty_spot_that_fits), new_empty_after);
                    overwrite_old_empty = false;
                } else {
                    empty_spots_list.append_one_assume_cap(new_empty_after);
                }
            }
            if (overwrite_old_empty) {
                empty_spots_list.delete_one(@intCast(empty_spot_that_fits));
            }
            field_loc = old_empty.offset + empty_spot_offset;
        } else {
            const next_aligned_offset = Utils.Mem.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(current_max_offset, field.gpu_type.uniform_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
            const new_empty_len = next_aligned_offset - current_max_offset;
            if (new_empty_len > 0) {
                comptime var combined_with_another_empty: bool = false;
                for (empty_spots_list.zig_slice_entire(), 0..) |empty, e| {
                    if (empty.offset + empty.len == current_max_offset) {
                        empty_spots[e].len += new_empty_len;
                        combined_with_another_empty = true;
                        break;
                    }
                }
                if (combined_with_another_empty == false) {
                    const new_empty = BufferSpan{
                        .offset = current_max_offset,
                        .len = new_empty_len,
                    };
                    empty_spots_list.append_one_assume_cap(new_empty);
                }
            }
            field_loc = next_aligned_offset;
            current_max_offset = next_aligned_offset + field.gpu_type.uniform_size;
        }
        field_locations[fidx] = field_loc;
        field_types[fidx] = field.gpu_type.cpu_type;
        field_hlsl_names[fidx] = field.gpu_type.hlsl_name;
        field_sizes[fidx] = field.gpu_type.uniform_size;
    }
    // END PACKING ALGORITHM
    const _BYTES: usize = std.mem.alignForward(usize, current_max_offset, GPU_UNIFORM_BOUNDARY_ALIGN);
    if (_BYTES > current_max_offset) {
        empty_spots_list.append_one_assume_cap(BufferSpan{
            .len = _BYTES - current_max_offset,
            .offset = current_max_offset,
        });
    }
    comptime var wasted_bytes: usize = 0;
    const SLOT_COUNT = _NUM_FIELDS + empty_spots_list.get_len();
    comptime var all_slots: [SLOT_COUNT]FieldOrPad = undefined;
    comptime var slot_idx: usize = 0;
    for (0.._NUM_FIELDS) |fidx| {
        all_slots[slot_idx] = FieldOrPad{ .FIELD = fidx };
        slot_idx += 1;
    }
    for (empty_spots_list.zig_slice_entire()) |empty| {
        all_slots[slot_idx] = FieldOrPad{ .PAD = empty };
        slot_idx += 1;
    }
    const field_locs_slice: []const usize = field_locations[0.._NUM_FIELDS];
    Sort.insertion_sort_with_func_and_userdata(all_slots[0..SLOT_COUNT], field_locs_slice, FieldOrPad.field_or_pad_offset_larger);
    comptime var total_len_of_field_names: usize = 0;
    comptime var longest_field_name_plus_type: usize = 17;
    comptime var shortest_field_name_plus_type: usize = 12;
    for (0.._NUM_FIELDS) |fidx| {
        const F: FIELDS = @enumFromInt(fidx);
        total_len_of_field_names += @tagName(F).len;
        const name_plus_type = @tagName(F).len + @tagName(field_hlsl_names[fidx]).len + 1;
        if (name_plus_type > longest_field_name_plus_type) {
            longest_field_name_plus_type = name_plus_type;
        }
        if (name_plus_type < shortest_field_name_plus_type) {
            shortest_field_name_plus_type = name_plus_type;
        }
    }
    const SPACE_BEWTEEN_SHORTEST_AND_LONGEST = longest_field_name_plus_type - shortest_field_name_plus_type;
    const HLSL_STUB_INNER_MAX_LEN = (_NUM_FIELDS + (empty_spots_list.get_len() * 4)) * (LONGEST_GPU_NAME + HLSL_STRUCT_LINE_EXTRA + if (_LAYOUT) (LAYOUT_LINE_EXTRA + SPACE_BEWTEEN_SHORTEST_AND_LONGEST) else 0);
    comptime var hlsl_stub_inner: [HLSL_STUB_INNER_MAX_LEN]u8 = undefined;
    comptime var pad_idx: usize = 0;
    comptime var comptime_writer = QuickWriter.writer(hlsl_stub_inner[0..]);
    _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);
    @setEvalBranchQuota(2000);
    for (all_slots[0..]) |slot| {
        switch (slot) {
            .FIELD => |fidx| {
                const fenum: FIELDS = @enumFromInt(fidx);
                const n1 = comptime_writer.write(@tagName(field_hlsl_names[fidx])) catch |err| assert_comptime_write_failure(@src(), err);
                comptime_writer.writeByte(SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                const n2 = comptime_writer.write(@tagName(fenum)) catch |err| assert_comptime_write_failure(@src(), err);
                if (_LAYOUT) {
                    const comment_space = longest_field_name_plus_type - (n1 + n2 + 1);
                    _ = comptime_writer.write(SEMICOL_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                    for (0..comment_space) |_| {
                        comptime_writer.writeByte(' ') catch |err| assert_comptime_write_failure(@src(), err);
                    }
                    _ = comptime_writer.write(COMMENT_OFF_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                    comptime_writer.printInt(field_locations[fidx], 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                    _ = comptime_writer.write(SPACE_SIZE_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                    comptime_writer.printInt(field_sizes[fidx], 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                    _ = comptime_writer.write(NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                } else {
                    _ = comptime_writer.write(SEMICOL_NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                }
            },
            .PAD => |span| {
                assert_with_reason(span.offset > 0, @src(), "somehow the first field in a uniform struct is padding (this should be impossible)", .{});
                assert_with_reason(span.offset % 4 == 0 and span.len % 4 == 0, @src(), "uniform padding must be a multiple of 4 bytes, got offset {d} and len {d}", .{ span.offset, span.len });
                wasted_bytes += span.len;
                comptime var span_remaining = span.len;
                comptime var curr_offset = span.offset;
                while (span_remaining > 0) {
                    const next_boundary = std.mem.alignForward(usize, curr_offset + 1, GPU_UNIFORM_BOUNDARY_ALIGN);
                    const len_to_next_boundary = next_boundary - curr_offset;
                    comptime var this_pad_rem: usize = @min(span_remaining, len_to_next_boundary);
                    span_remaining -= this_pad_rem;
                    while (this_pad_rem > 0) {
                        const this_size_align: math.Log2Int(usize) = @intCast(@ctz(curr_offset));
                        const this_size_span: math.Log2Int(usize) = @intCast(63 - @clz(this_pad_rem));
                        const this_size: math.Log2Int(usize) = @min(this_size_align, this_size_span);
                        assert_with_reason(this_size < PadSize.COUNT, @src(), "somehow `this_size` ({d}) is >= {d} (should not be possible)", .{ this_size, PadSize.COUNT });
                        const this_bytes = @as(usize, 1) << this_size;
                        const n1 = comptime_writer.write(@tagName(HLSL_PAD_TYPES[this_size])) catch |err| assert_comptime_write_failure(@src(), err);
                        const n2 = comptime_writer.write(SPACE_PAD_PREFIX) catch |err| assert_comptime_write_failure(@src(), err);
                        comptime_writer.printInt(pad_idx, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
                        if (_LAYOUT) {
                            const comment_space = longest_field_name_plus_type - (n1 + n2 + 1);
                            _ = comptime_writer.write(SEMICOL_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            for (0..comment_space) |_| {
                                comptime_writer.writeByte(' ') catch |err| assert_comptime_write_failure(@src(), err);
                            }
                            _ = comptime_writer.write(COMMENT_OFF_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            comptime_writer.printInt(curr_offset, 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                            _ = comptime_writer.write(SPACE_SIZE_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            comptime_writer.printInt(this_bytes, 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                            _ = comptime_writer.write(NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            // _ = comptime_writer.write(SEMICOL_SPACE_COMMENT_OFF) catch |err| assert_comptime_write_failure(@src(), err);
                            // comptime_writer.printInt(curr_offset, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
                            // _ = comptime_writer.write(NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                        } else {
                            _ = comptime_writer.write(SEMICOL_NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                        }
                        curr_offset += this_bytes;
                        this_pad_rem -= this_bytes;
                        pad_idx += 1;
                    }
                }
            },
        }
    }
    const hlsl_stub_final_len = comptime_writer.end - if (_LAYOUT) 5 else 6;
    const hlsl_stub_inner_const: [hlsl_stub_final_len]u8 = make_const: {
        var out: [hlsl_stub_final_len]u8 = undefined;
        @memcpy(out[0..hlsl_stub_final_len], hlsl_stub_inner[0..hlsl_stub_final_len]);
        break :make_const out;
    };
    const field_locations_const: [_NUM_FIELDS]usize = field_locations;
    const field_types_const: [_NUM_FIELDS]type = field_types;
    const field_hlsl_names_const: [_NUM_FIELDS]HLSL_NAME = field_hlsl_names;
    const waste_bytes_const = wasted_bytes;
    return extern struct {
        const Self = @This();

        buffer: [BYTES]u8 align(GPU_UNIFORM_BOUNDARY_ALIGN) = @splat(0),

        pub const BYTES: usize = _BYTES;
        pub const WASTE_BYTES: usize = waste_bytes_const;
        pub const USED_BYTES: usize = BYTES - WASTE_BYTES;
        pub const WASTE_PERCENT: f32 = calc: {
            const total_f32 = num_cast(BYTES, f32);
            const waste_f32 = num_cast(WASTE_BYTES, f32);
            break :calc (waste_f32 / total_f32) * 100.0;
        };
        pub const NUM_FIELDS = _NUM_FIELDS;
        pub const TYPES: [NUM_FIELDS]type = field_types_const;
        pub const OFFSETS: [NUM_FIELDS]usize = field_locations_const;
        pub const FIELD = FIELDS;
        pub const HLSL_NAMES: [NUM_FIELDS][]const u8 = field_hlsl_names_const;
        pub const HLSL_STUB_INNER = hlsl_stub_inner_const;

        pub fn bytes(self: *Self) *[BYTES]u8 {
            return &self.buffer;
        }
        pub fn bytes_const(self: *const Self) *const [BYTES]u8 {
            return &self.buffer;
        }
        pub fn bytes_unbound(self: *Self) [*]u8 {
            return @ptrCast(@alignCast(&self.buffer));
        }
        pub fn bytes_unbound_const(self: *const Self) [*]const u8 {
            return @ptrCast(@alignCast(&self.buffer));
        }
        pub fn bytes_slice(self: *Self) []u8 {
            return self.buffer[0..BYTES];
        }
        pub fn bytes_slice_const(self: *const Self) []const u8 {
            return self.buffer[0..BYTES];
        }

        pub fn type_for_field_name(comptime field: FIELD) type {
            return TYPES[@intFromEnum(field)];
        }

        pub fn get(self: *const Self, comptime field: FIELD) type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound_const() + offset;
            const t_ptr: *const T = @ptrCast(@alignCast(ptr));
            return t_ptr.*;
        }
        pub fn get_ptr(self: *Self, comptime field: FIELD) *type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr;
        }
        pub fn get_ptr_const(self: *const Self, comptime field: FIELD) *const type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound_const() + offset;
            const t_ptr: *const T = @ptrCast(@alignCast(ptr));
            return t_ptr;
        }
        pub fn set(self: *Self, comptime field: FIELD, val: type_for_field_name(field)) void {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            t_ptr.* = val;
        }
        pub fn get_from_buffer(buffer: [*]u8, index: usize) *Self {
            const OFFSET = Self.BYTES * index;
            return @ptrCast(@alignCast(buffer + OFFSET));
        }

        pub fn FieldOffsets(comptime OFFSET_INT: type) type {
            return Types.StructWithAllFieldsSameType(FIELD, OFFSET_INT);
        }
        pub fn field_offsets(comptime OFFSET_INT: type) FieldOffsets(OFFSET_INT) {
            var offs: FieldOffsets(OFFSET_INT) = undefined;
            inline for (@typeInfo(FIELD).@"enum".fields) |enum_field| {
                @field(offs, enum_field.name) = @intCast(OFFSETS[enum_field.value]);
            }
            return offs;
        }

        pub fn write_hlsl_uniform_stub(struct_name: []const u8, resgister_num: usize, space_num: usize, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            _ = try writer.write(HLSL_CBUFFER_SPACE);
            _ = try writer.write(struct_name);
            _ = try writer.write(SPACE_COLON_SPACE_REGISTER);
            try writer.writeByte(HLSL_UNIFORM_REGISTER);
            try writer.printInt(resgister_num, 10, .lower, .{});
            _ = try writer.write(COMMA_SPACE_HLSL_LAYER);
            try writer.printInt(space_num, 10, .lower, .{});
            _ = try writer.write(CLOSE_PAREN_SPACE_OPEN_BRACKET_NEWLINE);
            if (_LAYOUT) {
                _ = try writer.write(COMMENT_TOTAL_SIZE);
                try writer.printInt(BYTES, 10, .lower, .{});
                _ = try writer.write(USED_SIZE);
                try writer.printInt(USED_BYTES, 10, .lower, .{});
                _ = try writer.write(WASTE_SIZE);
                try writer.printInt(WASTE_BYTES, 10, .lower, .{});
                _ = try writer.write(PAREN_PERCENT);
                try writer.printFloat(WASTE_PERCENT, .{ .precision = 2, .width = 5 });
                _ = try writer.write(CLOSE_PAREN_NEWLINE);
            }
            _ = try writer.write(HLSL_STUB_INNER[0..]);
            _ = try writer.write(NEWLINE_CLOSE_BRACKET_SEMICOL_NEWLINE);
        }

        pub fn write_hlsl_storage_buffer_stub(struct_name: []const u8, buffer_name: []const u8, resgister_num: usize, space_num: usize, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            _ = try writer.write(STRUCT_SPACE);
            _ = try writer.write(struct_name);
            _ = try writer.write(SPACE_OPEN_BRACKET_NEWLINE);
            if (_LAYOUT) {
                _ = try writer.write(COMMENT_TOTAL_SIZE);
                try writer.printInt(BYTES, 10, .lower, .{});
                _ = try writer.write(USED_SIZE);
                try writer.printInt(USED_BYTES, 10, .lower, .{});
                _ = try writer.write(WASTE_SIZE);
                try writer.printInt(WASTE_BYTES, 10, .lower, .{});
                _ = try writer.write(PAREN_PERCENT);
                try writer.printFloat(WASTE_PERCENT, .{ .precision = 2, .width = 5 });
                _ = try writer.write(CLOSE_PAREN_NEWLINE);
            }
            _ = try writer.write(HLSL_STUB_INNER[0..]);
            _ = try writer.write(NEWLINE_CLOSE_BRACKET_SEMICOL_NEWLINE);
            _ = try writer.write(HLSL_STRUCTURED_BUFFER);
            _ = try writer.write(struct_name);
            _ = try writer.write(CLOSE_ANGLE_BRACKET_SPACE);
            _ = try writer.write(buffer_name);
            _ = try writer.write(SPACE_COLON_SPACE_REGISTER);
            try writer.writeByte(HLSL_TEXTURE_REGISTER);
            try writer.printInt(resgister_num, 10, .lower, .{});
            _ = try writer.write(COMMA_SPACE_HLSL_LAYER);
            try writer.printInt(space_num, 10, .lower, .{});
            _ = try writer.write(CLOSE_PAREN_SEMICOL_NEWLINE);
        }
    };
}

pub const WriteFormat = enum(u8) {
    HLSL,
};

pub const StorageMode = enum(u8) {
    READ_ONLY,
    READ_WRITE,
};

pub const VertexComponentSize = enum(u8) {
    _32_x1 = 1,
    _32_x2 = 2,
    _32_x3 = 3,
    _32_x4 = 4,

    pub fn from_int(val: u8) VertexComponentSize {
        return switch (val) {
            1 => ._32_x1,
            2 => ._32_x2,
            3 => ._32_x3,
            4 => ._32_x4,
            else => assert_unreachable(@src(), "somehow got {d} as a VertexComponentSize input", .{val}),
        };
    }
};

pub const LocationComponentArangement = enum(u4) {
    _4,
    _3_1,
    _2_2,
    _2_1_1,
    _1_1_1_1,
    INVALID,
};

pub const VertexLocationState = struct {
    /// How the components are partitioned for packed values
    arangement: LocationComponentArangement = ._4,
    /// Each bit represents a filled 32-bit component, in order
    used_components: u4 = 0b0000,

    pub const INVALID = VertexLocationState{
        .arangement = .INVALID,
        .used_components = 0b1111,
    };

    /// Returns whether the location can hold the needed component size (possibly by downgrading its arangement),
    /// the resulting state if it is accepted, and the byte offset the needed value should be put within the location
    pub fn can_fill_and_state_after_fill(self: VertexLocationState, need_size: VertexComponentSize) struct { bool, VertexLocationState, u32 } {
        const byte_offset: u32 = @as(u32, @popCount(self.used_components)) * 4;
        switch (self.arangement) {
            ._4 => {
                if (self.used_components == 0b0000) {
                    return switch (need_size) {
                        ._32_x4 => .{ true, .{ .arangement = ._4, .used_components = 0b1111 }, byte_offset },
                        ._32_x3 => .{ true, .{ .arangement = ._3_1, .used_components = 0b0111 }, byte_offset },
                        ._32_x2 => .{ true, .{ .arangement = ._2_2, .used_components = 0b0011 }, byte_offset },
                        ._32_x1 => .{ true, .{ .arangement = ._1_1_1_1, .used_components = 0b0001 }, byte_offset },
                    };
                }
                return .{ false, self, 0 };
            },
            ._3_1 => {
                if (need_size == ._32_x1 and self.used_components == 0b0111) {
                    return .{ true, .{ .arangement = ._3_1, .used_components = 0b1111 }, byte_offset };
                }
                if (need_size == ._32_x3 and self.used_components == 0b0000) {
                    return .{ true, .{ .arangement = ._3_1, .used_components = 0b0111 }, byte_offset };
                }
                return .{ false, self, 0 };
            },
            ._2_2 => {
                if (self.used_components == 0b0011) {
                    if (need_size == ._32_x2) {
                        return .{ true, .{ .arangement = ._2_2, .used_components = 0b1111 }, byte_offset };
                    } else if (need_size == ._32_x1) {
                        // Downgrades to _2_1_1
                        return .{ true, .{ .arangement = ._2_1_1, .used_components = 0b0111 }, byte_offset };
                    }
                } else if (need_size == ._32_x2 and self.used_components == 0b0000) {
                    return .{ true, .{ .arangement = ._2_2, .used_components = 0b0011 }, byte_offset };
                }
                return .{ false, self, 0 };
            },
            ._2_1_1 => {
                if (need_size == ._32_x1) {
                    if (self.used_components == 0b0011) {
                        return .{ true, .{ .arangement = ._2_1_1, .used_components = 0b0111 }, byte_offset };
                    } else if (self.used_components == 0b0111) {
                        return .{ true, .{ .arangement = ._2_1_1, .used_components = 0b1111 }, byte_offset };
                    }
                } else if (need_size == ._32_x2 and self.used_components == 0b0000) {
                    return .{ true, .{ .arangement = ._2_1_1, .used_components = 0b0011 }, byte_offset };
                }
                return .{ false, self, 0 };
            },
            ._1_1_1_1 => {
                if (need_size == ._32_x1) {
                    const next_used: ?u4 = switch (self.used_components) {
                        0b0000 => 0b0001,
                        0b0001 => 0b0011,
                        0b0011 => 0b0111,
                        0b0111 => 0b1111,
                        else => null,
                    };
                    if (next_used) |used| {
                        return .{ true, .{ .arangement = ._1_1_1_1, .used_components = used }, byte_offset };
                    }
                }
                return .{ false, self, 0 };
            },
            .INVALID => return .{ false, INVALID, 0 },
        }
    }
};

pub const GPUType = struct {
    /// The CPU (Zig) type
    cpu_type: type,
    cpu_align: comptime_int,
    uniform_size: comptime_int,
    uniform_alignment: comptime_int,
    sdl_format: GPU_VertexElementFormat = .INVALID,
    hlsl_name: HLSL_NAME,

    fn assert_same_size(comptime self: GPUType, comptime cpu_type: type, comptime src_loc: ?SourceLocation) void {
        assert_with_reason(@sizeOf(cpu_type) == @sizeOf(self.cpu_type), src_loc, "new cpu type `{s}` (size {d}) does not have the same size as the old cpu type size {d}", .{ @typeName(cpu_type), @sizeOf(cpu_type), @sizeOf(self.cpu_type) });
    }

    pub fn with_cpu_type(comptime self: GPUType, comptime new_cpu_type: type) GPUType {
        self.assert_same_size(new_cpu_type, @src());
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = self.cpu_align,
            .sdl_format = self.sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,

            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_type_and_align(comptime self: GPUType, comptime new_cpu_type: type, comptime new_cpu_align: comptime_int) GPUType {
        self.assert_same_size(new_cpu_type, @src());
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = new_cpu_align,
            .sdl_format = self.sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_and_sdl_type(comptime self: GPUType, new_cpu_type: type, comptime new_sdl_format: GPU_VertexElementFormat) GPUType {
        self.assert_same_size(new_cpu_type, @src());
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = self.cpu_align,
            .sdl_format = new_sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_and_sdl_type_and_align(comptime self: GPUType, new_cpu_type: type, comptime new_sdl_format: GPU_VertexElementFormat, comptime new_cpu_align: comptime_int) GPUType {
        self.assert_same_size(new_cpu_type, @src());
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = new_cpu_align,
            .sdl_format = new_sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,

            .hlsl_name = self.hlsl_name,
        };
    }

    pub inline fn equals(self: GPUType, other: GPUType) bool {
        return self.cpu_type == other.cpu_type and
            self.hlsl_name == other.hlsl_name;
    }
    pub inline fn equals_gpu_only(self: GPUType, other: GPUType) bool {
        return self.hlsl_name == other.hlsl_name;
    }

    pub inline fn equals_any(self: GPUType, others: []const GPUType) bool {
        for (others) |other| {
            if (self.equals(other)) return true;
        }
        return false;
    }
    pub inline fn equals_any_gpu_only(self: GPUType, others: []const GPUType) bool {
        for (others) |other| {
            if (self.equals_gpu_only(other)) return true;
        }
        return false;
    }
};

pub const HLSL_NAME = enum {
    bool,
    // float
    float,
    float2,
    float3,
    float4,
    float1x1,
    float1x2,
    float1x3,
    float1x4,
    float2x1,
    float2x2,
    float2x3,
    float2x4,
    float3x1,
    float3x2,
    float3x3,
    float3x4,
    float4x1,
    float4x2,
    float4x3,
    float4x4,
    // uint
    uint,
    uint2,
    uint3,
    uint4,
    uint1x1,
    uint1x2,
    uint1x3,
    uint1x4,
    uint2x1,
    uint2x2,
    uint2x3,
    uint2x4,
    uint3x1,
    uint3x2,
    uint3x3,
    uint3x4,
    uint4x1,
    uint4x2,
    uint4x3,
    uint4x4,
    // int
    int,
    int2,
    int3,
    int4,
    int1x1,
    int1x2,
    int1x3,
    int1x4,
    int2x1,
    int2x2,
    int2x3,
    int2x4,
    int3x1,
    int3x2,
    int3x3,
    int3x4,
    int4x1,
    int4x2,
    int4x3,
    int4x4,
};

pub const MAX_LOCATIONS: usize = 32;
pub const MAX_COMPONENTS: usize = MAX_LOCATIONS * 4; // 128
pub const MAX_TYPES: usize = 128;

pub const BaseType = enum {
    float,
    uint,
    int,
    bool,
};

pub const BaseTypeFamily = enum {
    float,
    integer,

    pub fn from_base_type(base: BaseType) BaseTypeFamily {
        return switch (base) {
            .float => .float,
            .uint, .int, .bool => .integer,
        };
    }

    /// Floats can only pack with floats.
    /// Int, uint, and bool can pack together.
    pub fn can_pack_together(a: BaseType, b: BaseType) bool {
        return from_base_type(a) == from_base_type(b);
    }
};

pub const HLSLInfo = struct {
    base_type: BaseType,
    rows: u8, // components per chunk (1..4)
    cols: u8, // number of chunks (1..4)
};

/// Decodes an HLSL_NAME into its constituent dimensions and scalar type
pub fn get_hlsl_info(name: HLSL_NAME) HLSLInfo {
    const tag: [:0]const u8 = @tagName(name);
    var base: BaseType = .float;
    var num_start: usize = 0;

    if (std.mem.startsWith(u8, tag, "float")) {
        base = .float;
        num_start = 5;
    } else if (std.mem.startsWith(u8, tag, "uint")) {
        base = .uint;
        num_start = 4;
    } else if (std.mem.startsWith(u8, tag, "int")) {
        base = .int;
        num_start = 3;
    } else if (std.mem.eql(u8, tag, "bool")) {
        return .{ .base_type = .bool, .rows = 1, .cols = 1 };
    }
    const tag_rem = tag.len - num_start;

    if (tag_rem == 0) {
        return .{ .base_type = base, .rows = 1, .cols = 1 };
    } else if (tag_rem == 1) {
        return .{ .base_type = base, .rows = tag[num_start] - '0', .cols = 1 };
    } else if (tag_rem == 3 and tag[num_start + 1] == 'x') {
        return .{ .base_type = base, .rows = tag[num_start] - '0', .cols = tag[num_start + 2] - '0' };
    }
    unreachable;
}

pub const Swizzle = struct {
    start: u8,
    count: u8,

    pub fn string(self: Swizzle) []const u8 {
        return switch (self.count) {
            1 => switch (self.start) {
                0 => "x",
                1 => "y",
                2 => "z",
                3 => "w",
                else => "?",
            },
            2 => switch (self.start) {
                0 => "xy",
                1 => "yz",
                2 => "zw",
                else => "??",
            },
            3 => switch (self.start) {
                0 => "xyz",
                1 => "yzw",
                else => "???",
            },
            4 => "xyzw",
            else => "",
        };
    }
};

/// Represents an individual vector chunk inside a single location
pub const PackedChunk = struct {
    location: u8,
    component_start: u8,
    component_count: u8,
    byte_offset: u32,

    pub fn swizzle(self: PackedChunk) Swizzle {
        return .{
            .start = self.component_start,
            .count = self.component_count,
        };
    }
};

/// Reports how a user GPUType is mapped, including shader reassembly instructions
pub const TypePacking = struct {
    gpu_type: GPUType,
    original_index: usize,
    chunk_count: u8,
    chunks: [4]PackedChunk = undefined,

    /// Returns the initial byte offset of this type in the vertex buffer
    pub fn byte_offset(self: TypePacking) u32 {
        return self.chunks[0].byte_offset;
    }

    /// Primary location where this type begins
    pub fn primary_location(self: TypePacking) u8 {
        return self.chunks[0].location;
    }

    // FIXME: I need to be able to print directly to an .hlsl file that SDL_ShaderCross supports,
    // /// Writes the exact HLSL expression to unpack or reassemble this type in the shader.
    // /// Examples:
    // ///   - Single float: "in_loc0.x"
    // ///   - Packed float2: "in_loc0.zw"
    // ///   - Reassembled float4x4: "float4x4(in_loc0, in_loc1, in_loc2, in_loc3)"
    // ///   - Reassembled float2x2: "float2x2(in_loc0.xy, in_loc0.zw)"
    // pub fn write_hlsl_expression(self: TypePacking, writer: anytype) !void {
    //     if (self.chunk_count == 1) {
    //         const c = self.chunks[0];
    //         if (c.component_count == 4) {
    //             try writer.print("in_loc{d}", .{c.location});
    //         } else {
    //             try writer.print("in_loc{d}.{s}", .{ c.location, c.swizzle().string() });
    //         }
    //     } else {
    //         try writer.print("{s}(", .{@tagName(self.gpu_type.hlsl_name)});
    //         for (0..self.chunk_count) |i| {
    //             if (i > 0) try writer.writeAll(", ");
    //             const c = self.chunks[i];
    //             if (c.component_count == 4) {
    //                 try writer.print("in_loc{d}", .{c.location});
    //             } else {
    //                 try writer.print("in_loc{d}.{s}", .{ c.location, c.swizzle().string() });
    //             }
    //         }
    //         try writer.writeAll(")");
    //     }
    // }
};

/// Description of an active GPU vertex buffer location
pub const LocationInfo = struct {
    location: u8,
    format: GPU_VertexElementFormat,
    arangement: LocationComponentArangement,
    used_components: u4,
    byte_offset: u32,
    byte_size: u32,
};

/// The complete packing report
pub const PackedVertexLayout = struct {
    locations: [MAX_LOCATIONS]LocationInfo = undefined,
    location_count: usize = 0,
    types: [MAX_TYPES]TypePacking = undefined,
    type_count: usize = 0,
    total_vertex_stride: u32 = 0,

    pub fn get_active_locations(self: *const PackedVertexLayout) []const LocationInfo {
        return self.locations[0..self.location_count];
    }

    pub fn get_type_packings(self: *const PackedVertexLayout) []const TypePacking {
        return self.types[0..self.type_count];
    }
};

fn resolve_location_format(base: BaseType, component_count: u8) GPU_VertexElementFormat {
    return switch (base) {
        .float => switch (component_count) {
            1 => .F32_x1,
            2 => .F32_x2,
            3 => .F32_x3,
            4 => .F32_x4,
            else => .INVALID,
        },
        .uint, .bool => switch (component_count) {
            1 => .U32_x1,
            2 => .U32_x2,
            3 => .U32_x3,
            4 => .U32_x4,
            else => .INVALID,
        },
        .int => switch (component_count) {
            1 => .I32_x1,
            2 => .I32_x2,
            3 => .I32_x3,
            4 => .I32_x4,
            else => .INVALID,
        },
    };
}

pub const PackError = error{
    too_many_input_types,
    out_of_vertex_locations,
};

/// Takes a list of GPUType and packs them into locations with offsets and packing/unpacking instructions.
pub fn pack_vertex_locations(input_types: []const GPUType) PackError!PackedVertexLayout {
    if (input_types.len > MAX_TYPES) return error.too_many_input_types;

    var result = PackedVertexLayout{};
    result.type_count = input_types.len;

    const ChunkRef = struct {
        type_idx: usize,
        chunk_idx: u8,
        size: VertexComponentSize,
        base_type: BaseType,
    };

    var chunks_to_pack: [MAX_TYPES * 4]ChunkRef = undefined;
    var total_chunks: usize = 0;

    // Calc chunks
    for (input_types, 0..) |gpu_t, i| {
        const info = get_hlsl_info(gpu_t.hlsl_name);
        result.types[i] = .{
            .gpu_type = gpu_t,
            .original_index = i,
            .chunk_count = info.cols,
        };

        for (0..info.cols) |col| {
            chunks_to_pack[total_chunks] = .{
                .type_idx = i,
                .chunk_idx = @intCast(col),
                .size = VertexComponentSize.from_int(info.rows),
                .base_type = info.base_type,
            };
            total_chunks += 1;
        }
    }

    // Sort chunks
    var sorted_chunks: [MAX_TYPES * 4]ChunkRef = undefined;
    var sorted_count: usize = 0;
    var target_size_int: u8 = 4;
    while (target_size_int >= 1) : (target_size_int -= 1) {
        for (chunks_to_pack[0..total_chunks]) |chunk| {
            if (@intFromEnum(chunk.size) == target_size_int) {
                sorted_chunks[sorted_count] = chunk;
                sorted_count += 1;
            }
        }
    }

    // Pack chunks
    var location_states: [MAX_LOCATIONS]VertexLocationState = [_]VertexLocationState{.{}} ** MAX_LOCATIONS;
    var location_base_types: [MAX_LOCATIONS]?BaseType = [_]?BaseType{null} ** MAX_LOCATIONS;
    var active_locations: usize = 0;

    // Temporary storage for location assignment per chunk
    const Placement = struct {
        loc: u8,
        comp_start: u8,
        loc_byte_offset: u32,
    };
    var chunk_placements: [MAX_TYPES][4]Placement = undefined;

    for (sorted_chunks[0..sorted_count]) |chunk| {
        var placed = false;

        // Try existing locations first
        for (0..active_locations) |loc_idx| {
            const did_fit, const new_fitted_state, const fit_offset = location_states[loc_idx].can_fill_and_state_after_fill(chunk.size);
            if (did_fit) {
                const next_state = new_fitted_state;
                const comp_start: u8 = @intCast(fit_offset / 4);

                chunk_placements[chunk.type_idx][chunk.chunk_idx] = .{
                    .loc = @intCast(loc_idx),
                    .comp_start = comp_start,
                    .loc_byte_offset = fit_offset,
                };
                location_states[loc_idx] = next_state;
                if (location_base_types[loc_idx] == null) {
                    location_base_types[loc_idx] = chunk.base_type;
                }
                placed = true;
                break;
            }
        }

        // Open a new location if it didn't fit
        if (!placed) {
            if (active_locations >= MAX_LOCATIONS) return error.out_of_vertex_locations;

            const loc_idx = active_locations;
            active_locations += 1;

            const did_fit, const new_fitted_state, const fit_offset = location_states[loc_idx].can_fill_and_state_after_fill(chunk.size);
            assert_with_reason(did_fit, @src(), "type did not fit into the vertex buffer anywhere, impossible to", .{});

            chunk_placements[chunk.type_idx][chunk.chunk_idx] = .{
                .loc = @intCast(loc_idx),
                .comp_start = 0,
                .loc_byte_offset = fit_offset,
            };
            location_states[loc_idx] = new_fitted_state;
            location_base_types[loc_idx] = chunk.base_type;
        }
    }

    // Calc final offsets
    var current_byte_offset: u32 = 0;
    result.location_count = active_locations;

    for (0..active_locations) |i| {
        const state = location_states[i];
        const num_components: u8 = @intCast(@popCount(state.used_components));
        const format = resolve_location_format(location_base_types[i] orelse .float, num_components);
        const byte_size: u32 = @as(u32, num_components) * 4;

        result.locations[i] = .{
            .location = @intCast(i),
            .format = format,
            .arangement = state.arangement,
            .used_components = state.used_components,
            .byte_offset = current_byte_offset,
            .byte_size = byte_size,
        };

        current_byte_offset += byte_size;
    }
    result.total_vertex_stride = current_byte_offset;

    // Build final report
    for (0..result.type_count) |t_idx| {
        const chunk_count = result.types[t_idx].chunk_count;
        const info = get_hlsl_info(result.types[t_idx].gpu_type.hlsl_name);

        for (0..chunk_count) |c_idx| {
            const placement = chunk_placements[t_idx][c_idx];
            const loc_base_offset = result.locations[placement.loc].byte_offset;

            result.types[t_idx].chunks[c_idx] = .{
                .location = placement.loc,
                .component_start = placement.comp_start,
                .component_count = info.rows,
                .byte_offset = loc_base_offset + placement.loc_byte_offset,
            };
        }
    }

    return result;
}

// SCALARS
pub const GPU_bool = GPUType{
    .cpu_type = Bool32,
    .cpu_align = 4,
    .sdl_format = .U32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.bool,
};
pub const GPU_f32 = GPUType{
    .cpu_type = f32,
    .cpu_align = 4,
    .sdl_format = .F32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.float,
};
pub const GPU_u32 = GPUType{
    .cpu_type = u32,
    .cpu_align = 4,
    .sdl_format = .U32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.uint,
};
pub const GPU_i32 = GPUType{
    .cpu_type = i32,
    .cpu_align = 4,
    .sdl_format = .I32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.int,
};

// 2D VECTORS
pub const GPU_f32_2 = GPUType{
    .cpu_type = define_vec2_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_NAME.float2,
};
pub const GPU_u32_2 = GPUType{
    .cpu_type = define_vec2_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_NAME.uint2,
};
pub const GPU_i32_2 = GPUType{
    .cpu_type = define_vec2_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_NAME.int2,
};

// 3D VECTORS
pub const GPU_f32_3 = GPUType{
    .cpu_type = define_vec3_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float3,
};
pub const GPU_u32_3 = GPUType{
    .cpu_type = define_vec3_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint3,
};
pub const GPU_i32_3 = GPUType{
    .cpu_type = define_vec3_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int3,
};

// 4D VECTORS
pub const GPU_f32_4 = GPUType{
    .cpu_type = define_vec4_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float4,
};
pub const GPU_u32_4 = GPUType{
    .cpu_type = define_vec4_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4,
};
pub const GPU_i32_4 = GPUType{
    .cpu_type = define_vec4_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int4,
};

// MATRICES
// -- 1x1
pub const GPU_f32_1x1 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.float1x1,
};
pub const GPU_u32_1x1 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.uint1x1,
};
pub const GPU_i32_1x1 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_NAME.int1x1,
};
// ---- 2x1
pub const GPU_f32_2x1 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float2x1,
};
pub const GPU_u32_2x1 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint2x1,
};
pub const GPU_i32_2x1 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int2x1,
};
// ---- 3x1
pub const GPU_f32_3x1 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float3x1,
};
pub const GPU_u32_3x1 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint3x1,
};
pub const GPU_i32_3x1 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int3x1,
};
// ---- 4x1
pub const GPU_f32_4x1 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float4x1,
};
pub const GPU_u32_4x1 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4x1,
};
pub const GPU_i32_4x1 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 1, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int4x1,
};
// ---- 1x2
pub const GPU_f32_1x2 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 2, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float1x2,
};
pub const GPU_u32_1x2 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 2, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint1x2,
};
pub const GPU_i32_1x2 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 2, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int1x2,
};
// ---- 2x2
pub const GPU_f32_2x2 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 2, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float2x2,
};
pub const GPU_u32_2x2 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 2, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint2x2,
};
pub const GPU_i32_2x2 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 2, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int2x2,
};
// ---- 3x2
pub const GPU_f32_3x2 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 2, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float3x2,
};
pub const GPU_u32_3x2 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 2, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint3x2,
};
pub const GPU_i32_3x2 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 2, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int3x2,
};
// ---- 4x2
pub const GPU_f32_4x2 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 2, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float4x2,
};
pub const GPU_u32_4x2 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 2, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4x2,
};
pub const GPU_i32_4x2 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 2, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int4x2,
};
// ---- 1x3
pub const GPU_f32_1x3 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 3, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float1x3,
};
pub const GPU_u32_1x3 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 3, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint1x3,
};
pub const GPU_i32_1x3 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 3, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int1x3,
};
// ---- 2x3
pub const GPU_f32_2x3 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 3, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float2x3,
};
pub const GPU_u32_2x3 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 3, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint2x3,
};
pub const GPU_i32_2x3 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 3, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int2x3,
};
// ---- 3x3
pub const GPU_f32_3x3 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 3, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float3x3,
};
pub const GPU_u32_3x3 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 3, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint3x3,
};
pub const GPU_i32_3x3 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 3, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int3x3,
};
// ---- 4x3
pub const GPU_f32_4x3 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 3, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float4x3,
};
pub const GPU_u32_4x3 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 3, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4x3,
};
pub const GPU_i32_4x3 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 3, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int4x3,
};
// ---- 1x4
pub const GPU_f32_1x4 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 4, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float1x4,
};
pub const GPU_u32_1x4 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 4, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint1x4,
};
pub const GPU_i32_1x4 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 4, .COLUMN_MAJOR, 3),
    .cpu_align = 4,
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int1x4,
};
// ---- 2x4
pub const GPU_f32_2x4 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 4, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float2x4,
};
pub const GPU_u32_2x4 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 4, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint2x4,
};
pub const GPU_i32_2x4 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 4, .COLUMN_MAJOR, 2),
    .cpu_align = 4,
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int2x4,
};
// ---- 3x4
pub const GPU_f32_3x4 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 4, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float3x4,
};
pub const GPU_u32_3x4 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 4, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint3x4,
};
pub const GPU_i32_3x4 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 4, .COLUMN_MAJOR, 1),
    .cpu_align = 4,
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int3x4,
};
// ---- 4x4
pub const GPU_f32_4x4 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 4, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.float4x4,
};
pub const GPU_u32_4x4 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 4, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4x4,
};
pub const GPU_i32_4x4 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 4, .COLUMN_MAJOR, 0),
    .cpu_align = 4,
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_NAME.int4x4,
};

// PACKED
// -- 4 bytes
pub const GPU_u8_4 = GPU_u32.with_cpu_and_sdl_type(define_vec4_type(u8), .U8_x4);
pub const GPU_i8_4 = GPU_u32.with_cpu_and_sdl_type(define_vec4_type(i8), .I8_x4);
pub const GPU_bool_4 = GPU_u32.with_cpu_and_sdl_type(define_vec4_type(bool), .U8_x4);
pub const GPU_f16_2 = GPU_u32.with_cpu_and_sdl_type(define_vec2_type(f16), .F16_x2);
pub const GPU_u16_2 = GPU_u32.with_cpu_and_sdl_type(define_vec2_type(u16), .U16_x2);
pub const GPU_i16_2 = GPU_u32.with_cpu_and_sdl_type(define_vec2_type(i16), .I16_x2);
// -- 8 bytes
pub const GPU_u8_8 = GPU_u32_2.with_cpu_and_sdl_type([8]u8, .U32_x2);
pub const GPU_i8_8 = GPU_u32_2.with_cpu_and_sdl_type([8]i8, .U32_x2);
pub const GPU_bool_8 = GPU_u32_2.with_cpu_and_sdl_type([8]bool, .U32_x2);
pub const GPU_f16_4 = GPU_u32_2.with_cpu_and_sdl_type(define_vec4_type(f16), .F16_x4);
pub const GPU_u16_4 = GPU_u32_2.with_cpu_and_sdl_type(define_vec4_type(u16), .U16_x4);
pub const GPU_i16_4 = GPU_u32_2.with_cpu_and_sdl_type(define_vec4_type(i16), .I16_x4);
pub const GPU_f64 = GPU_u32_2.with_cpu_and_sdl_type_and_align(f64, .U32_x2, 8);
pub const GPU_u64 = GPU_u32_2.with_cpu_and_sdl_type_and_align(u64, .U32_x2, 8);
pub const GPU_i64 = GPU_u32_2.with_cpu_and_sdl_type_and_align(i64, .U32_x2, 8);
// -- 16 bytes
pub const GPU_u8_16 = GPU_u32_2.with_cpu_and_sdl_type([16]u8, .U32_x4);
pub const GPU_i8_16 = GPU_u32_2.with_cpu_and_sdl_type([16]i8, .U32_x4);
pub const GPU_bool_16 = GPU_u32_2.with_cpu_and_sdl_type([16]bool, .U32_x4);
pub const GPU_f16_8 = GPU_u32_2.with_cpu_and_sdl_type([8]f16, .U32_x4);
pub const GPU_u16_8 = GPU_u32_2.with_cpu_and_sdl_type([8]u16, .U32_x4);
pub const GPU_i16_8 = GPU_u32_2.with_cpu_and_sdl_type([8]i16, .U32_x4);
pub const GPU_f64_2 = GPU_u32_4.with_cpu_and_sdl_type_and_align(define_vec2_type(f64), .U32_x4, 8);
pub const GPU_u64_2 = GPU_u32_4.with_cpu_and_sdl_type_and_align(define_vec2_type(u64), .U32_x4, 8);
pub const GPU_i64_2 = GPU_u32_4.with_cpu_and_sdl_type_and_align(define_vec2_type(i64), .U32_x4, 8);

// SPECIAL
pub fn GPU_enum32(comptime ENUM_TYPE: type) GPUType {
    assert_with_reason(Types.type_is_enum(ENUM_TYPE) and Types.enum_tag_type(ENUM_TYPE) == u32, @src(), "type `ENUM_TYPE` must be an enum type with tag type of u32, got type `{s}`", .{@typeName(ENUM_TYPE)});
    return GPU_u32.with_cpu_type(ENUM_TYPE);
}
pub fn GPU_enum16_2(comptime ENUM_TYPE_1: type, comptime ENUM_TYPE_2: type, comptime STRUCT: type) GPUType {
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_1) and Types.enum_tag_type(ENUM_TYPE_1) == u16, @src(), "type `ENUM_TYPE_1` must be an enum type with tag type of u16, got type `{s}`", .{@typeName(ENUM_TYPE_1)});
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_2) and Types.enum_tag_type(ENUM_TYPE_2) == u16, @src(), "type `ENUM_TYPE_2` must be an enum type with tag type of u16, got type `{s}`", .{@typeName(ENUM_TYPE_2)});
    assert_with_reason(Types.type_has_exactly_all_field_types(STRUCT, &.{ ENUM_TYPE_1, ENUM_TYPE_2 }), @src(), "type `STRUCT` must have exactly 1 field with type `ENUM_TYPE_1` (`{s}`) and exactly 1 field with type `ENUM_TYPE_2` (`{s}`), got type `{s}`", .{ @typeName(ENUM_TYPE_1), @typeName(ENUM_TYPE_2), @typeName(STRUCT) });
    assert_with_reason(@sizeOf(STRUCT) == 4 and @alignOf(STRUCT) == 2, @src(), "type `STRUCT` must have size = 4 and align = 2, got type `{s}` (size = {d}, align = {d})", .{ @typeName(STRUCT), @sizeOf(STRUCT), @alignOf(STRUCT) });
    return GPU_u16_2.with_cpu_type(STRUCT);
}
pub fn GPU_enum8_4(comptime ENUM_TYPE_1: type, comptime ENUM_TYPE_2: type, comptime ENUM_TYPE_3: type, comptime ENUM_TYPE_4: type, comptime STRUCT: type) GPUType {
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_1) and Types.enum_tag_type(ENUM_TYPE_1) == u8, @src(), "type `ENUM_TYPE_1` must be an enum type with tag type of u8, got type `{s}`", .{@typeName(ENUM_TYPE_1)});
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_2) and Types.enum_tag_type(ENUM_TYPE_2) == u8, @src(), "type `ENUM_TYPE_2` must be an enum type with tag type of u8, got type `{s}`", .{@typeName(ENUM_TYPE_2)});
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_3) and Types.enum_tag_type(ENUM_TYPE_3) == u8, @src(), "type `ENUM_TYPE_3` must be an enum type with tag type of u8, got type `{s}`", .{@typeName(ENUM_TYPE_3)});
    assert_with_reason(Types.type_is_enum(ENUM_TYPE_4) and Types.enum_tag_type(ENUM_TYPE_4) == u8, @src(), "type `ENUM_TYPE_4` must be an enum type with tag type of u8, got type `{s}`", .{@typeName(ENUM_TYPE_4)});
    assert_with_reason(Types.type_has_exactly_all_field_types(STRUCT, &.{ ENUM_TYPE_1, ENUM_TYPE_2, ENUM_TYPE_3, ENUM_TYPE_4 }), @src(), "type `STRUCT` must have exactly 1 field with each type `ENUM_TYPE_1` (`{s}`), `ENUM_TYPE_2` (`{s}`), `ENUM_TYPE_3` (`{s}`), and `ENUM_TYPE_4` (`{s}`), got type `{s}`", .{ @typeName(ENUM_TYPE_1), @typeName(ENUM_TYPE_2), @typeName(ENUM_TYPE_3), @typeName(ENUM_TYPE_4), @typeName(STRUCT) });
    assert_with_reason(@sizeOf(STRUCT) == 4 and @alignOf(STRUCT) == 1, @src(), "type `STRUCT` must have size = 4 and align = 1, got type `{s}` (size = {d}, align = {d})", .{ @typeName(STRUCT), @sizeOf(STRUCT), @alignOf(STRUCT) });
    return GPU_u8_4.with_cpu_type(STRUCT);
}

pub fn write_hlsl_enum_stub(comptime ENUM_TYPE: type, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    assert_with_reason(Types.type_is_enum(ENUM_TYPE) and Types.enum_tag_type(ENUM_TYPE) == u32, @src(), "type `ENUM_TYPE` must be an enum type with tag type of u32, got type `{s}`", .{@typeName(ENUM_TYPE)});
    const LOCAL = comptime Utils.local_type_name(ENUM_TYPE);
    _ = try writer.write(COMMENT_SPACE_ENUM_SPACE);
    _ = try writer.write(LOCAL);
    try writer.writeByte(NEWLINE);
    const INFO = @typeInfo(ENUM_TYPE).@"enum";
    inline for (INFO.fields) |field| {
        _ = try writer.write(DEFINE_SPACE);
        _ = try writer.write(LOCAL);
        _ = try writer.write(DOUBLE_UNDERSCORE);
        _ = try writer.write(field.name);
        try writer.writeByte(SPACE);
        try writer.printInt(field.value, 10, .lower, .{});
        try writer.writeByte(NEWLINE);
    }
}

pub const HLSL_INTERP_KIND = enum(u8) {
    DEFAULT = 0,
    NO_INTERP = 1,
    CONSTANT = 2,
    LINEAR = 3,
    LINEAR_CENTROID = 4,
    NO_PERSPECTIVE = 5,
    NO_PERSPECTIVE_CENTROID = 6,
    LINEAR_NO_PERSPECTIVE = 7,
    LINEAR_NO_PERSPECTIVE_CENTROID = 8,
    SAMPLE = 9,

    const _COUNT = 10;

    const NAMES = [_COUNT][]const u8{
        "",
        "nointerpolation ",
        "constant ",
        "linear ",
        "linear centroid ",
        "noperspective ",
        "noperspective centroid ",
        "linear_no_perspective ",
        "linear_no_perspective centroid ",
        "sample ",
    };

    pub fn print_len(self: HLSL_INTERP_KIND) usize {
        return NAMES[@intFromEnum(self)].len;
    }
};

pub const HLSL_SEMANTIC_KIND = enum(u8) {
    // SYSTEM VALUE
    SV_ClipDistance = 0,
    SV_CullDistance = 1,
    SV_Coverage = 2,
    SV_Depth = 3,
    SV_DepthGreaterEqual = 4,
    SV_DepthLessEqual = 5,
    SV_DispatchThreadID = 6,
    SV_DomainLocation = 7,
    SV_GroupID = 8,
    SV_GroupIndex = 9,
    SV_GroupThreadID = 10,
    SV_GSInstanceID = 11,
    SV_InnerCoverage = 12,
    SV_InsideTessFactor = 13,
    SV_InstanceID = 14,
    SV_IsFrontFace = 15,
    SV_OutputControlPointID = 16,
    SV_Position = 17,
    SV_PrimitiveID = 18,
    SV_RenderTargetArrayIndex = 19,
    SV_SampleIndex = 20,
    SV_StencilRef = 21,
    SV_Target = 22,
    SV_TessFactor = 23,
    SV_VertexID = 24,
    SV_ViewportArrayIndex = 25,
    SV_ShadingRate = 26,
    // USER VALUES
    USER = 27,
    // INTERNAL VALUES
    _PADDING = 28,

    pub const _COUNT = 29;
    pub const _LONGEST_SEMANTIC_NAME_LEN = 26;
    pub const _SHORTEST_SEMANTIC_NAME_LEN = 4;
    pub const _LAST_SV_SEMANTIC = 26;
};

pub const HLSL_SemanticNumTracker = struct {
    SV_ClipDistance: u32 = 0,
    SV_CullDistance: u32 = 0,
    SV_Target: u4 = 0,
    USER: u32 = 0,
    _PADDING: u32 = 0,
};

pub const HLSL_Semantic = union(HLSL_SEMANTIC_KIND) {
    // SYSTEM VALUE
    SV_ClipDistance: u32,
    SV_CullDistance: u32,
    SV_Coverage,
    SV_Depth,
    SV_DepthGreaterEqual,
    SV_DepthLessEqual,
    SV_DispatchThreadID,
    SV_DomainLocation,
    SV_GroupID,
    SV_GroupIndex,
    SV_GroupThreadID,
    SV_GSInstanceID,
    SV_InnerCoverage,
    SV_InsideTessFactor,
    SV_InstanceID,
    SV_IsFrontFace,
    SV_OutputControlPointID,
    SV_Position,
    SV_PrimitiveID,
    SV_RenderTargetArrayIndex,
    SV_SampleIndex,
    SV_StencilRef,
    SV_Target: u3,
    SV_TessFactor,
    SV_VertexID,
    SV_ViewportArrayIndex,
    SV_ShadingRate,
    // USER
    USER: u32,
    _PADDING: u32,

    pub fn get_num(self: HLSL_Semantic) ?u32 {
        switch (self) {
            .SV_ClipDistance,
            .SV_CullDistance,
            .USER,
            ._PADDING,
            => |nn| return nn,
            .SV_Target => |nn| return @intCast(nn),
            else => return null,
        }
    }

    pub fn sv_clip_distance(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .SV_ClipDistance = n };
    }
    pub fn sv_clip_distance_auto(tracker: *HLSL_SemanticNumTracker) HLSL_Semantic {
        const n = tracker.SV_ClipDistance;
        tracker.SV_ClipDistance += 1;
        return HLSL_Semantic{ .SV_ClipDistance = n };
    }
    pub fn sv_cull_distance(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .SV_CullDistance = n };
    }
    pub fn sv_cull_distance_auto(tracker: *HLSL_SemanticNumTracker) HLSL_Semantic {
        const n = tracker.SV_CullDistance;
        tracker.SV_CullDistance += 1;
        return HLSL_Semantic{ .SV_CullDistance = n };
    }
    pub fn sv_coverage() HLSL_Semantic {
        return HLSL_Semantic{ .SV_Coverage = void{} };
    }
    pub fn sv_depth() HLSL_Semantic {
        return HLSL_Semantic{ .SV_Depth = void{} };
    }
    pub fn sv_depth_greater_or_equal() HLSL_Semantic {
        return HLSL_Semantic{ .SV_DepthGreaterEqual = void{} };
    }
    pub fn sv_depth_lesser_or_equal() HLSL_Semantic {
        return HLSL_Semantic{ .SV_DepthLessEqual = void{} };
    }
    pub fn sv_dispatch_thread_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_DispatchThreadID = void{} };
    }
    pub fn sv_domain_location() HLSL_Semantic {
        return HLSL_Semantic{ .SV_DomainLocation = void{} };
    }
    pub fn sv_group_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_GroupID = void{} };
    }
    pub fn sv_group_index() HLSL_Semantic {
        return HLSL_Semantic{ .SV_GroupIndex = void{} };
    }
    pub fn sv_group_thread_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_GroupThreadID = void{} };
    }
    pub fn sv_gs_instance_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_GSInstanceID = void{} };
    }
    pub fn sv_inner_coverage() HLSL_Semantic {
        return HLSL_Semantic{ .SV_InnerCoverage = void{} };
    }
    pub fn sv_inside_tess_factor() HLSL_Semantic {
        return HLSL_Semantic{ .SV_InsideTessFactor = void{} };
    }
    pub fn sv_instance_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_InstanceID = void{} };
    }
    pub fn sv_is_front_face() HLSL_Semantic {
        return HLSL_Semantic{ .SV_IsFrontFace = void{} };
    }
    pub fn sv_output_control_point_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_OutputControlPointID = void{} };
    }
    pub fn sv_position() HLSL_Semantic {
        return HLSL_Semantic{ .SV_Position = void{} };
    }
    pub fn sv_primitive_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_PrimitiveID = void{} };
    }
    pub fn sv_render_target_array_index() HLSL_Semantic {
        return HLSL_Semantic{ .SV_RenderTargetArrayIndex = void{} };
    }
    pub fn sv_sample_index() HLSL_Semantic {
        return HLSL_Semantic{ .SV_SampleIndex = void{} };
    }
    pub fn sv_stencil_ref() HLSL_Semantic {
        return HLSL_Semantic{ .SV_StencilRef = void{} };
    }
    pub fn sv_target(n: u3) HLSL_Semantic {
        return HLSL_Semantic{ .SV_Target = n };
    }
    pub fn sv_target_auto(tracker: *HLSL_SemanticNumTracker) HLSL_Semantic {
        const n = tracker.SV_Target;
        tracker.SV_Target += 1;
        return HLSL_Semantic{ .SV_Target = @intCast(n) };
    }
    pub fn sv_tess_factor() HLSL_Semantic {
        return HLSL_Semantic{ .SV_TessFactor = void{} };
    }
    pub fn sv_vertex_id() HLSL_Semantic {
        return HLSL_Semantic{ .SV_VertexID = void{} };
    }
    pub fn sv_viewport_array_index() HLSL_Semantic {
        return HLSL_Semantic{ .SV_ViewportArrayIndex = void{} };
    }
    pub fn sv_shading_rate() HLSL_Semantic {
        return HLSL_Semantic{ .SV_ShadingRate = void{} };
    }
    pub fn user(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .USER = n };
    }
    pub fn user_auto(tracker: *HLSL_SemanticNumTracker) HLSL_Semantic {
        const n = tracker.USER;
        tracker.USER += 1;
        return HLSL_Semantic{ .USER = n };
    }
    pub fn padding(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ ._PADDING = n };
    }

    pub fn print(self: HLSL_Semantic, writer: *std.Io.Writer) std.Io.Writer.Error!usize {
        var n: usize = 0;
        n += try writer.write(@tagName(self));
        switch (self) {
            .SV_ClipDistance,
            .SV_CullDistance,
            .USER,
            ._PADDING,
            => |nn| {
                try writer.printInt(nn, 10, .lower, .{});
                n += Utils.print_len_of_uint(nn);
            },
            .SV_Target => |nn| {
                try writer.printInt(num_cast(nn, u8), 10, .lower, .{});
                n += Utils.print_len_of_uint(nn);
            },
            else => {},
        }
        return n;
    }

    pub fn print_len(self: HLSL_Semantic) usize {
        var n: usize = 3; // includes ' : ' prefix
        n += @tagName(self).len;
        switch (self) {
            .SV_ClipDistance,
            .SV_CullDistance,
            .USER,
            ._PADDING,
            => |nn| {
                n += Utils.print_len_of_uint(nn);
            },
            .SV_Target => |nn| {
                n += Utils.print_len_of_uint(nn);
            },
            else => {},
        }
        return n;
    }

    pub fn assert_has_allowed_type(self: HLSL_Semantic, gpu_type: GPUType, interp: HLSL_INTERP_KIND, comptime field_name: []const u8, comptime src: ?std.builtin.SourceLocation) void {
        if (Assert.should_assert()) {
            const allowed = ALLOWED_TYPES[@intFromEnum(self)];
            if (allowed.len > 0) {
                var found_valid_type = false;
                for (allowed) |gpu_t| {
                    if (gpu_type.equals_gpu_only(gpu_t)) {
                        found_valid_type = true;
                        break;
                    }
                }
                assert_with_reason(found_valid_type, src, "field `{s}` with semantic `{s}` must have one of the types `{any}`, but got type `{any}`", .{ field_name, @tagName(self), allowed, gpu_type });
            }
            switch (interp) {
                .DEFAULT, .NO_INTERP => {},
                else => {
                    const found_valid_interp = !gpu_type.equals_any_gpu_only(&.{
                        GPU_u32,
                        GPU_u32_2,
                        GPU_u32_3,
                        GPU_u32_4,
                        GPU_i32,
                        GPU_i32_2,
                        GPU_i32_3,
                        GPU_i32_4,
                    });
                    assert_with_reason(found_valid_interp, src, "field `{s}` with type `{s}` cannot have interpolation mode `{s}`", .{ field_name, gpu_type, HLSL_INTERP_KIND.NAMES[@intFromEnum(interp)] });
                },
            }
        }
    }

    pub const ALLOWED_TYPES = [HLSL_SEMANTIC_KIND._COUNT][]const GPUType{
        &.{GPU_f32}, // SV_ClipDistance = 0,
        &.{GPU_f32}, // SV_CullDistance = 1,
        &.{GPU_u32}, // SV_Coverage = 2,
        &.{GPU_f32}, // SV_Depth = 3,
        &.{GPU_f32}, // SV_DepthGreaterEqual = 4,
        &.{GPU_f32}, // SV_DepthLessEqual = 5,
        &.{GPU_u32_3}, // SV_DispatchThreadID = 6,
        &.{ GPU_f32_2, GPU_f32_3 }, // SV_DomainLocation = 7,
        &.{GPU_u32_3}, // SV_GroupID = 8,
        &.{GPU_u32}, // SV_GroupIndex = 9,
        &.{GPU_u32_3}, // SV_GroupThreadID = 10,
        &.{GPU_u32}, // SV_GSInstanceID = 11,
        &.{GPU_u32}, // SV_InnerCoverage = 12,
        &.{ GPU_f32, GPU_f32_2 }, // SV_InsideTessFactor = 13,
        &.{GPU_u32}, // SV_InstanceID = 14,
        &.{GPU_bool}, // SV_IsFrontFace = 15,
        &.{GPU_u32}, // SV_OutputControlPointID = 16,
        &.{GPU_f32_4}, // SV_Position = 17,
        &.{GPU_u32}, // SV_PrimitiveID = 18,
        &.{GPU_u32}, // SV_RenderTargetArrayIndex = 19,
        &.{GPU_u32}, // SV_SampleIndex = 20,
        &.{GPU_u32}, // SV_StencilRef = 21,
        &.{ GPU_f32_2, GPU_f32_3, GPU_f32_4 }, // SV_Target = 22,
        &.{ GPU_f32_2, GPU_f32_3, GPU_f32_4 }, // SV_TessFactor = 23,
        &.{GPU_u32}, // SV_VertexID = 24,
        &.{GPU_u32}, // SV_ViewportArrayIndex = 25,
        &.{GPU_u32}, // SV_ShadingRate = 26,
        &.{}, // USER = 27,
        &.{}, // _PADDING = 28,
    };
};

pub fn VertexShaderInputStructField(comptime STRUCT_FIELD_ENUM: type) type {
    return struct {
        field_name: STRUCT_FIELD_ENUM,
        gpu_type: GPUType,
        semantic: HLSL_SEMANTIC_KIND,
        interpolation: HLSL_INTERP_KIND = .NO_INTERP,
        from_vertex_buffer_slot: u32 = 0,

        pub fn new_advanced(comptime field_name: STRUCT_FIELD_ENUM, comptime gpu_type: GPUType, comptime semantic: HLSL_SEMANTIC_KIND, comptime interpolation: HLSL_INTERP_KIND, comptime from_vertex_buffer_slot: u32) @This() {
            return @This(){
                .field_name = field_name,
                .gpu_type = gpu_type,
                .semantic = semantic,
                .interpolation = interpolation,
                .from_vertex_buffer_slot = from_vertex_buffer_slot,
            };
        }
        pub fn new(comptime field_name: STRUCT_FIELD_ENUM, comptime gpu_type: GPUType, comptime semantic: HLSL_SEMANTIC_KIND) @This() {
            return @This(){
                .field_name = field_name,
                .gpu_type = gpu_type,
                .semantic = semantic,
                .interpolation = .NO_INTERP,
                .from_vertex_buffer_slot = 0,
            };
        }
    };
}

pub fn VertexShaderInputStruct(
    comptime NAME: []const u8,
    comptime STRUCT_FIELD_ENUM: type,
    comptime INCLUDE_LAYOUT: IncludeLayoutInStub,
    comptime fields: []const VertexShaderInputStructField(STRUCT_FIELD_ENUM),
    comptime EVAL_QUOTA: comptime_int,
) type {
    @setEvalBranchQuota(EVAL_QUOTA);

    assert_with_reason(Types.type_is_enum(STRUCT_FIELD_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(STRUCT_FIELD_ENUM), @src(), "type `STRUCT_FIELD_ENUM` must be an enum type starting at 0 with no gaps, got `{s}`", .{@typeName(STRUCT_FIELD_ENUM)});

    const _NUM_FIELDS = Types.enum_defined_field_count(STRUCT_FIELD_ENUM);
    assert_with_reason(fields.len == _NUM_FIELDS, @src(), "(VertexShaderInputStruct '{s}') the number of fields in `STRUCT_FIELD_ENUM` ({d}) must match the field definitions ({d})", .{ _NUM_FIELDS, fields.len });

    const _LAYOUT = INCLUDE_LAYOUT == .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB;

    // Verify all fields are uniquely defined
    comptime var field_defined: [_NUM_FIELDS]bool = @splat(false);
    for (fields) |f| {
        const idx = @intFromEnum(f.field_name);
        assert_with_reason(!field_defined[idx], @src(), "(VertexShaderInputStruct '{s}') field `{s}` defined more than once", .{@tagName(f.field_name)});
        field_defined[idx] = true;
    }

    // Determine unique buffer slots used
    comptime var max_slot: u32 = 0;
    for (fields) |f| {
        if (f.from_vertex_buffer_slot > max_slot) max_slot = f.from_vertex_buffer_slot;
    }
    const NUM_SLOTS = max_slot + 1;

    // Internal tracker for packing items
    const ChunkToPack = struct {
        field_idx: usize,
        chunk_idx: u8,
        size: VertexComponentSize,
        base_type: BaseType,
        slot: u32,
    };

    // Deconstruct all fields into 32-bit vector chunks
    comptime var total_chunks: usize = 0;
    for (fields) |f| {
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        total_chunks += info.cols;
    }

    comptime var chunks_to_pack: [total_chunks]ChunkToPack = undefined;
    comptime var c_idx: usize = 0;
    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        for (0..info.cols) |col| {
            chunks_to_pack[c_idx] = .{
                .field_idx = fidx,
                .chunk_idx = @intCast(col),
                .size = VertexComponentSize.from_int(info.rows),
                .base_type = info.base_type,
                .slot = f.from_vertex_buffer_slot,
            };
            c_idx += 1;
        }
    }

    // Sort chunks in descending order of size (4 -> 3 -> 2 -> 1) per slot
    comptime var sorted_chunks: [total_chunks]ChunkToPack = undefined;
    comptime var sorted_count: usize = 0;

    for (0..NUM_SLOTS) |slot| {
        var size_scan: u8 = 4;
        while (size_scan >= 1) : (size_scan -= 1) {
            for (chunks_to_pack) |chk| {
                if (chk.slot == slot and @intFromEnum(chk.size) == size_scan) {
                    sorted_chunks[sorted_count] = chk;
                    sorted_count += 1;
                }
            }
        }
    }

    // Bin pack chunks into vertex locations
    comptime var location_states: [MAX_LOCATIONS]VertexLocationState = [_]VertexLocationState{.{}} ** MAX_LOCATIONS;
    comptime var location_slots: [MAX_LOCATIONS]u32 = @splat(0);
    comptime var location_base_types: [MAX_LOCATIONS]?BaseType = [_]?BaseType{null} ** MAX_LOCATIONS;
    comptime var active_locations: usize = 0;

    const ChunkPlacement = struct {
        loc: u8,
        comp_start: u8,
        comp_count: u8,
        loc_byte_offset: u32,
    };

    comptime var field_placements: [_NUM_FIELDS][4]ChunkPlacement = undefined;
    comptime var field_chunk_counts: [_NUM_FIELDS]u8 = undefined;

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        field_chunk_counts[fidx] = info.cols;
    }

    for (sorted_chunks) |chk| {
        var placed = false;

        // Try existing locations for this buffer slot
        for (0..active_locations) |l_idx| {
            if (location_slots[l_idx] != chk.slot) continue;

            // HYBRID CHECK: Floats only with Floats; Ints with Uints
            if (location_base_types[l_idx]) |loc_base| {
                if (!BaseTypeFamily.can_pack_together(loc_base, chk.base_type)) continue;
            }

            const did_fit, const new_state, const fit_offset = location_states[l_idx].can_fill_and_state_after_fill(chk.size);
            if (did_fit) {
                field_placements[chk.field_idx][chk.chunk_idx] = .{
                    .loc = @intCast(l_idx),
                    .comp_start = @intCast(fit_offset / 4),
                    .comp_count = @intFromEnum(chk.size),
                    .loc_byte_offset = fit_offset,
                };
                location_states[l_idx] = new_state;

                // If an integer location mixes int and uint, promote the container to `uint`
                if (location_base_types[l_idx] == null or chk.base_type == .uint or chk.base_type == .bool) {
                    location_base_types[l_idx] = if (chk.base_type == .float) .float else .uint;
                }
                placed = true;
                break;
            }
        }

        if (!placed) {
            assert_with_reason(active_locations < MAX_LOCATIONS, @src(), "(VertexShaderInputStruct '{s}') exceeded maximum of {d} vertex locations", .{MAX_LOCATIONS});
            const l_idx = active_locations;
            active_locations += 1;

            location_slots[l_idx] = chk.slot;
            const did_fit, const new_state, const fit_offset = location_states[l_idx].can_fill_and_state_after_fill(chk.size);
            assert_with_reason(did_fit, @src(), "(VertexShaderInputStruct '{s}') fresh location could not fit chunk", .{});

            field_placements[chk.field_idx][chk.chunk_idx] = .{
                .loc = @intCast(l_idx),
                .comp_start = 0,
                .comp_count = @intFromEnum(chk.size),
                .loc_byte_offset = fit_offset,
            };
            location_states[l_idx] = new_state;
            location_base_types[l_idx] = chk.base_type;
        }
    }

    // Calculate byte offsets and sizes per location and per slot
    comptime var slot_strides: [NUM_SLOTS]u32 = @splat(0);
    comptime var location_byte_offsets: [MAX_LOCATIONS]u32 = undefined;
    comptime var location_formats: [MAX_LOCATIONS]GPU_VertexElementFormat = undefined;

    for (0..active_locations) |l_idx| {
        const slot = location_slots[l_idx];
        const num_comps: u8 = @intCast(@popCount(location_states[l_idx].used_components));
        const loc_bytes: u32 = @as(u32, num_comps) * 4;

        location_formats[l_idx] = resolve_location_format(location_base_types[l_idx] orelse .float, num_comps);
        location_byte_offsets[l_idx] = slot_strides[slot];
        slot_strides[slot] += loc_bytes;
    }

    // Compute absolute field byte offsets within their respective vertex buffer slots
    comptime var field_offsets: [_NUM_FIELDS]usize = undefined;
    comptime var field_types: [_NUM_FIELDS]type = undefined;

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const placement = field_placements[fidx][0];
        field_offsets[fidx] = location_byte_offsets[placement.loc] + placement.loc_byte_offset;
        field_types[fidx] = f.gpu_type.cpu_type;
    }

    // Build Comptime HLSL Stub Code
    const TOTAL_STRIDE: usize = if (NUM_SLOTS > 0) slot_strides[0] else 0;
    const HLSL_BUFFER_MAX_LEN = 16384;
    comptime var hlsl_buffer: [HLSL_BUFFER_MAX_LEN]u8 = undefined;
    comptime var comptime_writer = QuickWriter.writer(hlsl_buffer[0..]);

    // Track user semantics
    comptime var next_texcoord: u32 = 0;
    const PACKED_NAME = NAME ++ "_PACKED";

    // --- Generate HLSL Input Struct ---
    _ = comptime_writer.write("struct " ++ PACKED_NAME ++ " {\n") catch |err| assert_comptime_write_failure(@src(), err);

    for (0..active_locations) |l_idx| {
        _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);
        const num_comps: u8 = @intCast(@popCount(location_states[l_idx].used_components));
        const base = location_base_types[l_idx] orelse .float;

        // Print raw type (e.g. float4, uint2)
        const type_str = switch (base) {
            .float => switch (num_comps) {
                1 => "float ",
                2 => "float2",
                3 => "float3",
                4 => "float4",
                else => "float4",
            },
            .uint, .bool => switch (num_comps) {
                1 => "uint  ",
                2 => "uint2 ",
                3 => "uint3 ",
                4 => "uint4 ",
                else => "uint4 ",
            },
            .int => switch (num_comps) {
                1 => "int   ",
                2 => "int2  ",
                3 => "int3  ",
                4 => "int4  ",
                else => "int4  ",
            },
        };
        _ = comptime_writer.write(type_str) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" in_loc") catch |err| assert_comptime_write_failure(@src(), err);
        comptime_writer.printInt(l_idx, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" : TEXCOORD") catch |err| assert_comptime_write_failure(@src(), err);
        comptime_writer.printInt(next_texcoord, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
        next_texcoord += 1;

        if (_LAYOUT) {
            _ = comptime_writer.write("; // slot ") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(location_slots[l_idx], 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(", off ") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(location_byte_offsets[l_idx], 10, .lower, .{ .alignment = .right, .width = 3 }) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(", arange ") catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(@tagName(location_states[l_idx].arangement)) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write("\n") catch |err| assert_comptime_write_failure(@src(), err);
        } else {
            _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
        }
    }
    _ = comptime_writer.write("};\n\n") catch |err| assert_comptime_write_failure(@src(), err);

    // --- Generate Unpacked HLSL Struct ---
    _ = comptime_writer.write("struct " ++ NAME ++ " {\n") catch |err| assert_comptime_write_failure(@src(), err);
    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.gpu_type.hlsl_name)) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.writeByte(' ') catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.field_name)) catch |err| assert_comptime_write_failure(@src(), err);

        if (_LAYOUT) {
            _ = comptime_writer.write("; // off ") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(field_offsets[fidx], 10, .lower, .{ .alignment = .right, .width = 3 }) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(" (slot ") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(f.from_vertex_buffer_slot, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(")\n") catch |err| assert_comptime_write_failure(@src(), err);
        } else {
            _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
        }
    }
    _ = comptime_writer.write("};\n\n") catch |err| assert_comptime_write_failure(@src(), err);

    // --- Generate Unpack/Reassembly Function ---
    _ = comptime_writer.write(NAME ++ " unpack_vs_input(" ++ PACKED_NAME ++ " input) {\n") catch |err| assert_comptime_write_failure(@src(), err);
    _ = comptime_writer.write("    " ++ NAME ++ " v;\n") catch |err| assert_comptime_write_failure(@src(), err);

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const count = field_chunk_counts[fidx];
        const field_info = get_hlsl_info(f.gpu_type.hlsl_name);

        _ = comptime_writer.write("    v.") catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.field_name)) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" = ") catch |err| assert_comptime_write_failure(@src(), err);

        if (count == 1) {
            const plc = field_placements[fidx][0];
            const num_loc_comps: u8 = @intCast(@popCount(location_states[plc.loc].used_components));
            const reg_base = location_base_types[plc.loc] orelse .float;

            write_unpack_expr(
                &comptime_writer,
                "input.in_loc",
                plc.loc,
                plc.comp_start,
                plc.comp_count,
                num_loc_comps,
                reg_base,
                field_info.base_type,
            ) catch |err| assert_comptime_write_failure(@src(), err);
        } else {
            // Multi-column matrix reconstruction
            _ = comptime_writer.write(@tagName(f.gpu_type.hlsl_name)) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.writeByte('(') catch |err| assert_comptime_write_failure(@src(), err);

            for (0..count) |col| {
                if (col > 0) _ = comptime_writer.write(", ") catch |err| assert_comptime_write_failure(@src(), err);
                const plc = field_placements[fidx][col];
                const num_loc_comps: u8 = @intCast(@popCount(location_states[plc.loc].used_components));
                const reg_base = location_base_types[plc.loc] orelse .float;

                write_unpack_expr(
                    &comptime_writer,
                    "input.in_loc",
                    plc.loc,
                    plc.comp_start,
                    plc.comp_count,
                    num_loc_comps,
                    reg_base,
                    field_info.base_type,
                ) catch |err| assert_comptime_write_failure(@src(), err);
            }
            _ = comptime_writer.writeByte(')') catch |err| assert_comptime_write_failure(@src(), err);
        }
        _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
    }
    _ = comptime_writer.write("    return v;\n}\n") catch |err| assert_comptime_write_failure(@src(), err);

    const hlsl_stub_final_len = comptime_writer.end;
    const hlsl_stub_inner_const: [hlsl_stub_final_len]u8 = make_const: {
        var out: [hlsl_stub_final_len]u8 = undefined;
        @memcpy(out[0..hlsl_stub_final_len], hlsl_buffer[0..hlsl_stub_final_len]);
        break :make_const out;
    };

    const field_offsets_const = field_offsets;
    const field_types_const = field_types;
    const active_locs_const = active_locations;
    const loc_slots_const = location_slots;
    const loc_offsets_const = location_byte_offsets;
    const loc_formats_const = location_formats;
    const slot_strides_const = slot_strides;

    return extern struct {
        const Self = @This();

        buffer: [BYTES]u8 align(16) = @splat(0),

        pub const BYTES: usize = TOTAL_STRIDE;
        pub const NUM_FIELDS = _NUM_FIELDS;
        pub const NUM_LOCATIONS: usize = active_locs_const;
        pub const TYPES: [NUM_FIELDS]type = field_types_const;
        pub const OFFSETS: [NUM_FIELDS]usize = field_offsets_const;
        pub const FIELD = STRUCT_FIELD_ENUM;
        pub const HLSL_VERTEX_STUB = hlsl_stub_inner_const;
        pub const SLOT_STRIDES = slot_strides_const;

        // CPU Buffer accessors
        pub fn bytes(self: *Self) *[BYTES]u8 {
            return &self.buffer;
        }
        pub fn bytes_const(self: *const Self) *const [BYTES]u8 {
            return &self.buffer;
        }
        pub fn bytes_slice(self: *Self) []u8 {
            return self.buffer[0..BYTES];
        }
        pub fn bytes_slice_const(self: *const Self) []const u8 {
            return self.buffer[0..BYTES];
        }

        pub fn type_for_field_name(comptime field: FIELD) type {
            return TYPES[@intFromEnum(field)];
        }

        pub fn get(self: *const Self, comptime field: FIELD) type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = @as([*]const u8, @ptrCast(&self.buffer)) + offset;
            const t_ptr: *const T = @ptrCast(@alignCast(ptr));
            return t_ptr.*;
        }

        pub fn get_ptr(self: *Self, comptime field: FIELD) *type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = @as([*]u8, @ptrCast(&self.buffer)) + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr;
        }

        pub fn set(self: *Self, comptime field: FIELD, val: type_for_field_name(field)) void {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = @as([*]u8, @ptrCast(&self.buffer)) + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            t_ptr.* = val;
        }

        /// Returns vertex buffer descriptions for SDL3/GPU pipeline creation
        pub fn get_sdl_vertex_buffer_descriptions() [NUM_SLOTS]SDL3.SDL_GPUVertexBufferDescription {
            var descs: [NUM_SLOTS]SDL3.SDL_GPUVertexBufferDescription = undefined;
            inline for (0..NUM_SLOTS) |s| {
                descs[s] = .{
                    .slot = @intCast(s),
                    .pitch = slot_strides_const[s],
                    .input_rate = SDL3.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                    .instance_step_rate = 0,
                };
            }
            return descs;
        }

        /// Returns vertex attributes for SDL3/GPU pipeline creation
        pub fn get_sdl_vertex_attributes() [NUM_LOCATIONS]SDL3.SDL_GPUVertexAttribute {
            var attrs: [NUM_LOCATIONS]SDL3.SDL_GPUVertexAttribute = undefined;
            inline for (0..NUM_LOCATIONS) |l| {
                attrs[l] = .{
                    .location = @intCast(l),
                    .buffer_slot = loc_slots_const[l],
                    .format = loc_formats_const[l].to_c(),
                    .offset = loc_offsets_const[l],
                };
            }
            return attrs;
        }

        pub fn write_hlsl_vertex_stub(writer: *std.Io.Writer) std.Io.Writer.Error!void {
            _ = try writer.write(HLSL_VERTEX_STUB[0..]);
        }
    };
}

pub fn VertexToFragmentField(comptime STRUCT_FIELD_ENUM: type) type {
    return struct {
        field_name: STRUCT_FIELD_ENUM,
        gpu_type: GPUType,
        semantic: HLSL_Semantic,
        interpolation: HLSL_INTERP_KIND = .DEFAULT,

        pub fn new(
            comptime field_name: STRUCT_FIELD_ENUM,
            comptime gpu_type: GPUType,
            comptime semantic: HLSL_Semantic,
        ) @This() {
            return @This(){
                .field_name = field_name,
                .gpu_type = gpu_type,
                .semantic = semantic,
                .interpolation = .DEFAULT,
            };
        }

        pub fn new_interp(
            comptime field_name: STRUCT_FIELD_ENUM,
            comptime gpu_type: GPUType,
            comptime semantic: HLSL_Semantic,
            comptime interpolation: HLSL_INTERP_KIND,
        ) @This() {
            return @This(){
                .field_name = field_name,
                .gpu_type = gpu_type,
                .semantic = semantic,
                .interpolation = interpolation,
            };
        }
    };
}

pub fn VertexToFragmentStruct(
    comptime NAME: []const u8,
    comptime STRUCT_FIELD_ENUM: type,
    comptime INCLUDE_LAYOUT: IncludeLayoutInStub,
    comptime fields: []const VertexToFragmentField(STRUCT_FIELD_ENUM),
    comptime EVAL_QUOTA: comptime_int,
) type {
    @setEvalBranchQuota(EVAL_QUOTA);

    assert_with_reason(
        Types.type_is_enum(STRUCT_FIELD_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(STRUCT_FIELD_ENUM),
        @src(),
        "type `STRUCT_FIELD_ENUM` must be an enum type starting at 0 with no gaps, got `{s}`",
        .{@typeName(STRUCT_FIELD_ENUM)},
    );

    const _NUM_FIELDS = Types.enum_defined_field_count(STRUCT_FIELD_ENUM);
    assert_with_reason(
        fields.len == _NUM_FIELDS,
        @src(),
        "the number of fields in `STRUCT_FIELD_ENUM` ({d}) must match field definitions ({d})",
        .{ _NUM_FIELDS, fields.len },
    );

    const _LAYOUT = INCLUDE_LAYOUT == .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB;
    const PACKED_NAME = NAME ++ "_PACKED";

    // Validate semantics and types
    for (fields) |f| {
        f.semantic.assert_has_allowed_type(f.gpu_type, f.interpolation, @tagName(f.field_name), @src());
    }

    const ChunkToPack = struct {
        field_idx: usize,
        chunk_idx: u8,
        size: VertexComponentSize,
        base_type: BaseType,
        interp: HLSL_INTERP_KIND,
        is_system_value: bool,
        system_semantic: ?HLSL_Semantic,
    };

    comptime var total_chunks: usize = 0;
    for (fields) |f| {
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        total_chunks += info.cols;
    }

    comptime var chunks_to_pack: [total_chunks]ChunkToPack = undefined;
    comptime var c_idx: usize = 0;

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        const is_sys = f.semantic != .USER and f.semantic != ._PADDING;

        for (0..info.cols) |col| {
            chunks_to_pack[c_idx] = .{
                .field_idx = fidx,
                .chunk_idx = @intCast(col),
                .size = VertexComponentSize.from_int(info.rows),
                .base_type = info.base_type,
                .interp = f.interpolation,
                .is_system_value = is_sys,
                .system_semantic = if (is_sys) f.semantic else null,
            };
            c_idx += 1;
        }
    }

    // Sort: Dedicated System Values first, then descending by component size (4 -> 3 -> 2 -> 1)
    comptime var sorted_chunks: [total_chunks]ChunkToPack = undefined;
    comptime var sorted_count: usize = 0;

    for (chunks_to_pack) |chk| {
        if (chk.is_system_value) {
            sorted_chunks[sorted_count] = chk;
            sorted_count += 1;
        }
    }

    var size_scan: u8 = 4;
    while (size_scan >= 1) : (size_scan -= 1) {
        for (chunks_to_pack) |chk| {
            if (!chk.is_system_value and @intFromEnum(chk.size) == size_scan) {
                sorted_chunks[sorted_count] = chk;
                sorted_count += 1;
            }
        }
    }

    // State tracking for interpolator registers
    const StageRegister = struct {
        state: VertexLocationState = .{},
        base_type: BaseType = .float,
        interp: HLSL_INTERP_KIND = .DEFAULT,
        is_dedicated: bool = false,
        semantic: ?HLSL_Semantic = null,
        user_texcoord_idx: u32 = 0,
    };

    comptime var stage_registers: [MAX_LOCATIONS]StageRegister = [_]StageRegister{.{}} ** MAX_LOCATIONS;
    comptime var active_registers: usize = 0;
    comptime var next_texcoord: u32 = 0;

    const ChunkPlacement = struct {
        reg: u8,
        comp_start: u8,
        comp_count: u8,
    };

    comptime var field_placements: [_NUM_FIELDS][4]ChunkPlacement = undefined;
    comptime var field_chunk_counts: [_NUM_FIELDS]u8 = undefined;

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const info = get_hlsl_info(f.gpu_type.hlsl_name);
        field_chunk_counts[fidx] = info.cols;
    }

    for (sorted_chunks) |chk| {
        var placed = false;

        // System values must go into a dedicated register
        if (chk.is_system_value) {
            assert_with_reason(active_registers < MAX_LOCATIONS, @src(), "exceeded maximum inter-stage locations", .{});
            const r_idx = active_registers;
            active_registers += 1;

            const did_fit, const new_state, _ = stage_registers[r_idx].state.can_fill_and_state_after_fill(chk.size);
            assert_with_reason(did_fit, @src(), "failed to fit system value into fresh register", .{});

            stage_registers[r_idx] = .{
                .state = new_state,
                .base_type = chk.base_type,
                .interp = chk.interp,
                .is_dedicated = true,
                .semantic = chk.system_semantic,
                .user_texcoord_idx = 0,
            };

            field_placements[chk.field_idx][chk.chunk_idx] = .{
                .reg = @intCast(r_idx),
                .comp_start = 0,
                .comp_count = @intFromEnum(chk.size),
            };
            continue;
        }

        // Try existing packable registers: interpolation modes AND base scalar types must match
        for (0..active_registers) |r_idx| {
            if (stage_registers[r_idx].is_dedicated) continue;
            if (stage_registers[r_idx].interp != chk.interp) continue;
            if (stage_registers[r_idx].base_type != chk.base_type) continue;

            const did_fit, const new_state, const fit_offset = stage_registers[r_idx].state.can_fill_and_state_after_fill(chk.size);
            if (did_fit) {
                stage_registers[r_idx].state = new_state;
                field_placements[chk.field_idx][chk.chunk_idx] = .{
                    .reg = @intCast(r_idx),
                    .comp_start = @intCast(fit_offset / 4),
                    .comp_count = @intFromEnum(chk.size),
                };
                placed = true;
                break;
            }
        }

        // Open a new register
        if (!placed) {
            assert_with_reason(active_registers < MAX_LOCATIONS, @src(), "exceeded maximum inter-stage locations", .{});
            const r_idx = active_registers;
            active_registers += 1;

            const did_fit, const new_state, const fit_offset = stage_registers[r_idx].state.can_fill_and_state_after_fill(chk.size);
            assert_with_reason(did_fit, @src(), "fresh register could not accept chunk", .{});

            stage_registers[r_idx] = .{
                .state = new_state,
                .base_type = chk.base_type,
                .interp = chk.interp,
                .is_dedicated = false,
                .semantic = null,
                .user_texcoord_idx = next_texcoord,
            };
            next_texcoord += 1;

            field_placements[chk.field_idx][chk.chunk_idx] = .{
                .reg = @intCast(r_idx),
                .comp_start = @intCast(fit_offset / 4),
                .comp_count = @intFromEnum(chk.size),
            };
        }
    }

    // --- Build HLSL Stubs ---
    const HLSL_BUFFER_MAX_LEN = 32768;
    comptime var hlsl_buffer: [HLSL_BUFFER_MAX_LEN]u8 = undefined;
    comptime var comptime_writer = QuickWriter.writer(hlsl_buffer[0..]);

    // Unpacked Intermediate Struct
    _ = comptime_writer.write("struct " ++ NAME ++ " {\n") catch |err| assert_comptime_write_failure(@src(), err);
    for (fields) |f| {
        _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.gpu_type.hlsl_name)) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.writeByte(' ') catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.field_name)) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
    }
    _ = comptime_writer.write("};\n\n") catch |err| assert_comptime_write_failure(@src(), err);

    // Hardware Packed Stage Output / Input Struct
    _ = comptime_writer.write("struct " ++ PACKED_NAME ++ " {\n") catch |err| assert_comptime_write_failure(@src(), err);
    for (0..active_registers) |r_idx| {
        const reg = stage_registers[r_idx];
        const num_comps: u8 = @intCast(@popCount(reg.state.used_components));

        _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);

        // Interpolation qualifier
        if (reg.interp != .DEFAULT) {
            _ = comptime_writer.write(HLSL_INTERP_KIND.NAMES[@intFromEnum(reg.interp)]) catch |err| assert_comptime_write_failure(@src(), err);
        }

        // HLSL Type
        const type_str = switch (reg.base_type) {
            .float => switch (num_comps) {
                1 => "float ",
                2 => "float2",
                3 => "float3",
                4 => "float4",
                else => "float4",
            },
            .uint, .bool => switch (num_comps) {
                1 => "uint  ",
                2 => "uint2 ",
                3 => "uint3 ",
                4 => "uint4 ",
                else => "uint4 ",
            },
            .int => switch (num_comps) {
                1 => "int   ",
                2 => "int2  ",
                3 => "int3  ",
                4 => "int4  ",
                else => "int4  ",
            },
        };
        _ = comptime_writer.write(type_str) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" reg") catch |err| assert_comptime_write_failure(@src(), err);
        comptime_writer.printInt(r_idx, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" : ") catch |err| assert_comptime_write_failure(@src(), err);

        if (reg.is_dedicated and reg.semantic != null) {
            _ = comptime_writer.write(@tagName(reg.semantic.?)) catch |err| assert_comptime_write_failure(@src(), err);
            if (reg.semantic.?.get_num()) |num| {
                comptime_writer.printInt(num, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
            }
        } else {
            _ = comptime_writer.write("TEXCOORD") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(reg.user_texcoord_idx, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
        }

        if (_LAYOUT) {
            _ = comptime_writer.write("; // arange ") catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(@tagName(reg.state.arangement)) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write("\n") catch |err| assert_comptime_write_failure(@src(), err);
        } else {
            _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
        }
    }
    _ = comptime_writer.write("};\n\n") catch |err| assert_comptime_write_failure(@src(), err);

    // 3. Vertex Shader Packing Function
    _ = comptime_writer.write("" ++ PACKED_NAME ++ " PackVertexOutput(" ++ NAME ++ " v) {\n") catch |err| assert_comptime_write_failure(@src(), err);
    _ = comptime_writer.write("    " ++ PACKED_NAME ++ " stage;\n") catch |err| assert_comptime_write_failure(@src(), err);

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const count = field_chunk_counts[fidx];

        for (0..count) |col| {
            const plc = field_placements[fidx][col];
            const swz = Swizzle{ .start = plc.comp_start, .count = plc.comp_count };

            _ = comptime_writer.write("    stage.reg") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(plc.reg, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.writeByte('.') catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(swz.string()) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(" = v.") catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.write(@tagName(f.field_name)) catch |err| assert_comptime_write_failure(@src(), err);

            if (count > 1) {
                _ = comptime_writer.write("[") catch |err| assert_comptime_write_failure(@src(), err);
                comptime_writer.printInt(col, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
                _ = comptime_writer.write("]") catch |err| assert_comptime_write_failure(@src(), err);
            }
            _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
        }
    }
    _ = comptime_writer.write("    return stage;\n}\n\n") catch |err| assert_comptime_write_failure(@src(), err);

    // 4. Pixel Shader Unpacking Function
    _ = comptime_writer.write("" ++ NAME ++ " UnpackFragmentInput(" ++ PACKED_NAME ++ " stage) {\n") catch |err| assert_comptime_write_failure(@src(), err);
    _ = comptime_writer.write("    " ++ NAME ++ " v;\n") catch |err| assert_comptime_write_failure(@src(), err);

    for (fields) |f| {
        const fidx = @intFromEnum(f.field_name);
        const count = field_chunk_counts[fidx];

        _ = comptime_writer.write("    v.") catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(@tagName(f.field_name)) catch |err| assert_comptime_write_failure(@src(), err);
        _ = comptime_writer.write(" = ") catch |err| assert_comptime_write_failure(@src(), err);

        if (count == 1) {
            const plc = field_placements[fidx][0];
            const swz = Swizzle{ .start = plc.comp_start, .count = plc.comp_count };
            const reg = stage_registers[plc.reg];
            const num_comps: u8 = @intCast(@popCount(reg.state.used_components));

            _ = comptime_writer.write("stage.reg") catch |err| assert_comptime_write_failure(@src(), err);
            comptime_writer.printInt(plc.reg, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);

            if (plc.comp_count < num_comps or plc.comp_count < 4) {
                _ = comptime_writer.writeByte('.') catch |err| assert_comptime_write_failure(@src(), err);
                _ = comptime_writer.write(swz.string()) catch |err| assert_comptime_write_failure(@src(), err);
            }
        } else {
            _ = comptime_writer.write(@tagName(f.gpu_type.hlsl_name)) catch |err| assert_comptime_write_failure(@src(), err);
            _ = comptime_writer.writeByte('(') catch |err| assert_comptime_write_failure(@src(), err);

            for (0..count) |col| {
                if (col > 0) _ = comptime_writer.write(", ") catch |err| assert_comptime_write_failure(@src(), err);
                const plc = field_placements[fidx][col];
                const swz = Swizzle{ .start = plc.comp_start, .count = plc.comp_count };
                const reg = stage_registers[plc.reg];
                const num_comps: u8 = @intCast(@popCount(reg.state.used_components));

                _ = comptime_writer.write("stage.reg") catch |err| assert_comptime_write_failure(@src(), err);
                comptime_writer.printInt(plc.reg, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);

                if (plc.comp_count < num_comps or plc.comp_count < 4) {
                    _ = comptime_writer.writeByte('.') catch |err| assert_comptime_write_failure(@src(), err);
                    _ = comptime_writer.write(swz.string()) catch |err| assert_comptime_write_failure(@src(), err);
                }
            }
            _ = comptime_writer.writeByte(')') catch |err| assert_comptime_write_failure(@src(), err);
        }
        _ = comptime_writer.write(";\n") catch |err| assert_comptime_write_failure(@src(), err);
    }
    _ = comptime_writer.write("    return v;\n}\n") catch |err| assert_comptime_write_failure(@src(), err);

    const hlsl_stub_final_len = comptime_writer.end;
    const hlsl_stub_const: [hlsl_stub_final_len]u8 = make_const: {
        var out: [hlsl_stub_final_len]u8 = undefined;
        @memcpy(out[0..hlsl_stub_final_len], hlsl_buffer[0..hlsl_stub_final_len]);
        break :make_const out;
    };

    return struct {
        pub const NUM_FIELDS = _NUM_FIELDS;
        pub const NUM_REGISTERS = active_registers;
        pub const HLSL_STUB = hlsl_stub_const;

        pub fn write_hlsl_stub(writer: *std.Io.Writer) std.Io.Writer.Error!void {
            _ = try writer.write(HLSL_STUB[0..]);
        }
    };
}

/// Writes an unpack expression, inserting bitcast intrinsics when types differ.
pub fn write_unpack_expr(
    writer: anytype,
    container_name: []const u8, // e.g. "input.in_loc" or "stage.reg"
    reg_idx: u8,
    comp_start: u8,
    comp_count: u8,
    num_loc_comps: u8,
    reg_base: BaseType,
    field_base: BaseType,
) !void {
    const needs_cast = reg_base != field_base;

    // Bitcast wrapper start
    if (needs_cast) {
        switch (field_base) {
            .int => _ = try writer.write("asint("),
            .uint, .bool => _ = try writer.write("asuint("),
            .float => _ = try writer.write("asfloat("),
        }
    }

    // Access location and swizzle
    try writer.print("{s}{d}", .{ container_name, reg_idx });
    if (comp_count < num_loc_comps or comp_count < 4) {
        const swz = Swizzle{ .start = comp_start, .count = comp_count };
        try writer.print(".{s}", .{swz.string()});
    }

    // Bitcast wrapper end
    if (needs_cast) {
        _ = try writer.writeByte(')');
    }
}

/// Writes a pack assignment expression (for Vertex-to-Fragment output).
pub fn write_pack_expr(
    writer: anytype,
    field_expr: []const u8, // e.g. "v.my_field"
    reg_base: BaseType,
    field_base: BaseType,
) !void {
    const needs_cast = reg_base != field_base;

    if (needs_cast) {
        switch (reg_base) {
            .uint, .bool => _ = try writer.write("asuint("),
            .int => _ = try writer.write("asint("),
            .float => _ = try writer.write("asfloat("),
        }
    }

    _ = try writer.write(field_expr);

    if (needs_cast) {
        _ = try writer.writeByte(')');
    }
}

test "SDL_GraphicsController_TypeUtils => Enum Stubs" {
    const RENDER_MODE = enum(u32) {
        TEXT_NORMAL,
        TEXT_OUTLINE,
        SPRITE,
        SPRITE_PALETTED,
    };
    try std.Io.Dir.cwd().createDirPath(std.testing.io, "test_out/SDL3_ShaderContract");
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/enum_stub_1.hlsl", .{});
    defer file.close(std.testing.io);
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(std.testing.io, file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try write_hlsl_enum_stub(RENDER_MODE, writer);
    try writer.flush();
}

test "SDL_GraphicsController_TypeUtils => Uniform Layout/Stubs" {
    const F = enum(u8) {
        world_pos,
        main_color,
        projection_matrix,
        secondary_color,
        shader_mode,
        hamburgers_good,
    };
    const U = StorageStructField(F);
    const ShaderMode = enum(u32) {
        SPRITE,
        TEXT,
    };
    const MyUniform = StorageStruct(F, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
        U.new(.world_pos, GPU_f32_3),
        U.new(.main_color, GPU_u32),
        U.new(.secondary_color, GPU_u32),
        U.new(.shader_mode, GPU_enum32(ShaderMode)),
        U.new(.projection_matrix, GPU_f32_4x4),
        U.new(.hamburgers_good, GPU_bool),
    }, 100000);
    // assert_with_reason(@sizeOf(MyUniform) == 96, @src(), "layout failed", .{});
    // assert_with_reason(@alignOf(MyUniform) == 16, @src(), "layout failed", .{});
    try std.Io.Dir.cwd().createDirPath(std.testing.io, "test_out/SDL3_ShaderContract");
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/uniform_stub_1.hlsl", .{});
    defer file.close(std.testing.io);
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(std.testing.io, file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try MyUniform.write_hlsl_uniform_stub("MyUniform", 0, 1, writer);
    try writer.flush();
    // testing for correctness using the following link for matching field offsets
    // https://maraneshi.github.io/HLSL-ConstantBufferLayoutVisualizer/?visualizer=MYIwrgZhCmBOAEBZAngVQHYEsIHtYFt4AueWaAc0wGcAXOAChAAYAaeKgBwENhoBGAJTwA3gCh4E+AHop8ACoB5OQEEAMvAC88AJwA2SagDKAUQAimnQCZJAdWWG5xiwBZ49AKTxnAOj4B2AXFJCAAbHC4aAGZ4AHc8EIATAH0OHCoAbkksrJl4HCgspgkqTAAvaEk+SyCJMEx0Gnh8Lnqk4Bww2Ezsntz8iErrdjKKyWca+FDwmmcAD1cOWBwAK2hgGkwcdCTmmlhMWcy+gok+fWHyyV1xrLqG9jWthK5YZDaOvG7s44GJAA4ihdRhIbpI7o0qAALLgJOA7HCwr49CQ-SR-VxArKgiQgHAdeDQ-DgWDkOBUJLkPEJJGSVH-P7FEZYibg+BJFIw9lMGnIlGyfqSbRDEqXMaiAC+6SAA
    const F2 = enum(u8) {
        scalar_1,
        scalar_2,
        scalar_3,
        mat_1,
        scalar_4,
        scalar_5,
        mat_2,
        scalar_6,
    };
    const U2 = StorageStructField(F2);
    const MyUniform2 = StorageStruct(F2, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
        U2.new(.scalar_1, GPU_f32),
        U2.new(.scalar_2, GPU_f32),
        U2.new(.scalar_3, GPU_f32_2),
        U2.new(.mat_1, GPU_f32_3x4),
        U2.new(.scalar_4, GPU_f32_3),
        U2.new(.scalar_5, GPU_f32_4),
        U2.new(.mat_2, GPU_i32_1x2),
        U2.new(.scalar_6, GPU_f32),
    }, 100000);
    assert_with_reason(@sizeOf(MyUniform2) == 128, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyUniform2) == 16, @src(), "layout failed", .{});
    const file2 = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/uniform_stub_2.hlsl", .{});
    defer file2.close(std.testing.io);
    file_writer_holder = file2.writer(std.testing.io, file_write_buf[0..]);
    writer = &file_writer_holder.interface;
    try MyUniform2.write_hlsl_uniform_stub("MyUniform2", 0, 1, writer);
    try writer.flush();
    // testing for correctness using the following link for matching field offsets
    // https://maraneshi.github.io/HLSL-ConstantBufferLayoutVisualizer/?visualizer=MYIwrgZhCmBOAEBZAngVQHYEsIHtYFsAmeALnlmgHNMBnAFzgAoQAGAGnhoAcBDYaAIwBKeAG8AUPCnwA9DPgAVAPIKAggBl4AXngDCADmmoAygFEAItt0HpAdVXGFpqy3iMApPBYA6FiyGS0hAANjg8dADMAB4ALPD44QD6AgDc0rLyOFDprpyYAF7Q0gBsLIFSIWF0nMA8wTywyWnScvBZECW5NAVF0jHl8JXhETV1DYkxzRlt2VLFcXmF0noDQ9U0tfWNhFPT7dIA7MVS3Ut9q6HhcRtjjQCsU637UvpdPcvFA5jodAJRxAk6IkdukpE9ZvAAJzHRa9eCEMrpNajLaJYq7cEdXQCGGnOHwfpIy50Yg3VERR6ZWZ6N5nF7iAC+KSAA
}

test "SDL_GraphicsController_TypeUtils => Storage Layout/Stubs" {
    const F = enum(u8) {
        world_pos,
        main_color,
        projection_matrix,
        secondary_color,
        shader_mode,
        hamburgers_good,
    };
    const U = StorageStructField(F);
    const ShaderMode = enum(u32) {
        SPRITE,
        TEXT,
    };
    const MyStruct = StorageStruct(F, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
        U.new(.world_pos, GPU_f32_3),
        U.new(.main_color, GPU_u32),
        U.new(.secondary_color, GPU_u32),
        U.new(.shader_mode, GPU_enum32(ShaderMode)),
        U.new(.projection_matrix, GPU_f32_4x4),
        U.new(.hamburgers_good, GPU_bool),
    }, 100000);
    assert_with_reason(@sizeOf(MyStruct) == 96, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyStruct) == 16, @src(), "layout failed", .{});
    try std.Io.Dir.cwd().createDirPath(std.testing.io, "test_out/SDL3_ShaderContract");
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/storage_stub_1.hlsl", .{});
    defer file.close(std.testing.io);
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(std.testing.io, file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try MyStruct.write_hlsl_storage_buffer_stub("MyStruct", "MyStorageBuffer", 0, 1, writer);
    try writer.flush();
    const F2 = enum(u8) {
        scalar_1,
        scalar_2,
        scalar_3,
        mat_1,
        scalar_4,
        scalar_5,
        mat_2,
        scalar_6,
    };
    const U2 = StorageStructField(F2);
    const MyStruct2 = StorageStruct(F2, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
        U2.new(.scalar_1, GPU_f32),
        U2.new(.scalar_2, GPU_f32),
        U2.new(.scalar_3, GPU_f32_2),
        U2.new(.mat_1, GPU_f32_3x4),
        U2.new(.scalar_4, GPU_f32_3),
        U2.new(.scalar_5, GPU_f32_4),
        U2.new(.mat_2, GPU_i32_1x2),
        U2.new(.scalar_6, GPU_f32),
    }, 100000);
    assert_with_reason(@sizeOf(MyStruct2) == 128, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyStruct2) == 16, @src(), "layout failed", .{});
    const file2 = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/storage_stub_2.hlsl", .{});
    defer file2.close(std.testing.io);
    file_writer_holder = file2.writer(std.testing.io, file_write_buf[0..]);
    writer = &file_writer_holder.interface;
    try MyStruct2.write_hlsl_storage_buffer_stub("MyStruct2", "MyStorageBuffer2", 0, 1, writer);
    try writer.flush();
}

test "SDL_GraphicsController_TypeUtils => Vertex Layout/Stubs" {
    const F = enum(u8) {
        transform,
        world_pos,
        color,
        face_normal,
        vert_normal,
        blend_mode,
    };
    const S = VertexShaderInputStructField(F);
    const BlendMode = enum(u32) {
        NONE,
        SURFACE,
        FACE_ONLY,
    };
    const MyVertex = VertexShaderInputStruct(
        "MyVertex",
        F,
        .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
        &.{
            S.new(.transform, GPU_f32_4x4, .USER),
            S.new_advanced(.world_pos, GPU_f32_3, .SV_Position, .LINEAR, 0),
            S.new(.color, GPU_f32_4, .USER),
            S.new(.face_normal, GPU_f32_3, .USER),
            S.new(.vert_normal, GPU_f32_2, .USER),
            S.new(.blend_mode, GPU_enum32(BlendMode), .USER),
        },
        100000,
    );

    try std.Io.Dir.cwd().createDirPath(std.testing.io, "test_out/SDL3_ShaderContract");
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/vertex_stub_1.hlsl", .{});
    defer file.close(std.testing.io);
    var file_write_buf: [2048]u8 = undefined;
    var file_writer_holder = file.writer(std.testing.io, file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try MyVertex.write_hlsl_vertex_stub(writer);
    try writer.flush();
}

test "SDL_GraphicsController_TypeUtils => Vertex-To-Fragment Layout/Stubs" {
    const V2F = enum(u8) {
        clip_pos,
        uv,
        world_normal,
        instance_id,
        tint_strength,
    };
    const Field = VertexToFragmentField(V2F);

    const MyV2FContract = VertexToFragmentStruct(
        "MyVertexToFragment",
        V2F,
        .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
        &.{
            // System value: Must get its own dedicated register
            Field.new(.clip_pos, GPU_f32_4, HLSL_Semantic.sv_position()),

            // Smooth linear floats: uv (vec2) + tint_strength (scalar) should PACK together
            Field.new_interp(.uv, GPU_f32_2, HLSL_Semantic.user(0), .LINEAR),
            Field.new_interp(.world_normal, GPU_f32_3, HLSL_Semantic.user(1), .LINEAR_CENTROID),
            Field.new_interp(.tint_strength, GPU_f32, HLSL_Semantic.user(2), .LINEAR),

            // Flat integer: must NOT pack with linear floats
            Field.new_interp(.instance_id, GPU_u32, HLSL_Semantic.user(3), .NO_INTERP),
        },
        100000,
    );

    try std.Io.Dir.cwd().createDirPath(std.testing.io, "test_out/SDL3_ShaderContract");
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, "test_out/SDL3_ShaderContract/vert_to_frag_1.hlsl", .{});
    defer file.close(std.testing.io);

    var file_write_buf: [4096]u8 = undefined;
    var file_writer_holder = file.writer(std.testing.io, file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try MyV2FContract.write_hlsl_stub(writer);
    try writer.flush();
}
