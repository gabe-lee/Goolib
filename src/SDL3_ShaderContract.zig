//! This module is intended to create shader 'contracts' for passing data to and from
//! a shader fron the cpu in the correct order/location/alignment
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
const NamedFuncDefinition = Types.NamedFuncDefinition;
const ParamDefinition = Types.ParamDefinition;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_comptime_write_failure = Assert.assert_comptime_write_failure;
const num_cast = Cast.num_cast;
const bit_cast = Cast.bit_cast;

const define_vec2_type = Vec2.define_vec2_type;
const define_vec3_type = Vec3.define_vec3_type;
const define_vec4_type = Vec4.define_vec4_type;
const define_matx_type = Matrix.define_rectangular_RxC_matrix_type;

const BufferSpan = struct {
    offset: usize,
    len: usize,
    // cache_line: usize,
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
const INVALID = "INVALID";
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
const MAX_SHADER_STAGE_IN_OUT_SIZE = 16 * GPU_f32_4.stream_size;

pub const IncludeLayoutInStub = enum(u8) {
    NO_LAYOUT_COMMENTS_IN_SHADER_STUB,
    INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
};

pub const HLSL_RelaxedSemantics = enum(u8) {
    NO_HLSL_SEMANTIC_REQUIREMENTS_FOR_NON_SYSTEM_VALUES,
    ENFORCE_STRICT_HLSL_TYPE_SEMANTICS,
};

pub const HLSL_NonSVSemantics = enum(u8) {
    ENFORCE_SINGLE_NON_SYSTEM_VALUE_SEMANTIC,
    ALLOW_ALL_NON_SYSTEM_VALUE_SEMANTICS,
};

pub const NonSystemSemantics = union(HLSL_NonSVSemantics) {
    ENFORCE_SINGLE_NON_SYSTEM_VALUE_SEMANTIC: HLSL_SEMANTIC_KIND,
    ALLOW_ALL_NON_SYSTEM_VALUE_SEMANTICS,

    pub fn allow_all_non_system_value_semantics() NonSystemSemantics {
        return NonSystemSemantics{ .ALLOW_ALL_NON_SYSTEM_VALUE_SEMANTICS = void{} };
    }
    pub fn enforce_single_non_system_semantic(semantic: HLSL_SEMANTIC_KIND) NonSystemSemantics {
        return NonSystemSemantics{ .ENFORCE_SINGLE_NON_SYSTEM_VALUE_SEMANTIC = semantic };
    }
};

/// A struct field within a `StorageStruct(FIELDS)`
///
/// Follows `std140` packing rules
pub fn StorageStructField(comptime FIELDS: type) type {
    return struct {
        const Self = @This();

        field: FIELDS,
        gpu_type: GPUType,
        // /// Provides a *hint* for whether it would be better to place
        // /// the member closer to the beginning or the end of the struct
        // cache_locality_hint: usize = 0,

        pub fn new(comptime field: FIELDS, comptime gpu_type: GPUType) Self {
            return Self{ .field = field, .gpu_type = gpu_type };
        }
    };
}

/// A struct that is written to a uniform/constant/storage buffer
///
/// Follows `std140` packing rules
pub fn StorageStruct(comptime FIELDS: type, comptime INCLUDE_LAYOUT: IncludeLayoutInStub, comptime fields: []const StorageStructField(FIELDS)) type {
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
    comptime var empty_spots_len: usize = 0;
    comptime var current_max_offset: usize = 0;
    const SORT = struct {
        fn align_lesser_then_size_lesser(a: _Field, b: _Field) bool {
            if (a.gpu_type.uniform_alignment < b.gpu_type.uniform_alignment) return true;
            return a.gpu_type.uniform_size < a.gpu_type.uniform_size;
        }
        fn offset_larger(a: BufferSpan, b: BufferSpan) bool {
            return a.offset > b.offset;
        }
    };
    Sort.insertion_sort_with_func(_Field, _fields[0.._NUM_FIELDS], SORT.align_lesser_then_size_lesser);
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
        for (empty_spots[0..empty_spots_len], 0..) |empty, e| {
            if (empty.len >= field.gpu_type.uniform_size) {
                const next_aligned_within_empty = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(empty.offset, field.gpu_type.uniform_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
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
            const old_empty = empty_spots[empty_spot_that_fits];
            comptime var overwrite_old_empty = true;
            if (empty_spot_offset > 0) {
                const new_empty_before = BufferSpan{
                    .offset = old_empty.offset,
                    .len = empty_spot_offset,
                };
                empty_spots[empty_spot_that_fits] = new_empty_before;
                overwrite_old_empty = false;
            }
            if (empty_spot_space_after > 0) {
                const new_empty_after = BufferSpan{
                    .offset = empty_spot_offset + field.gpu_type.uniform_size,
                    .len = empty_spot_space_after,
                };
                if (overwrite_old_empty) {
                    empty_spots[empty_spot_that_fits] = new_empty_after;
                    overwrite_old_empty = false;
                } else {
                    empty_spots[empty_spots_len] = new_empty_after;
                    empty_spots_len += 1;
                }
            }
            if (overwrite_old_empty) {
                Utils.mem_remove(empty_spots[0..empty_spots_len].ptr, &empty_spots_len, empty_spot_that_fits, 1);
            }
            field_loc = old_empty.offset + empty_spot_offset;
        } else {
            const next_aligned_offset = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(current_max_offset, field.gpu_type.uniform_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
            const new_empty_len = next_aligned_offset - current_max_offset;
            if (new_empty_len > 0) {
                comptime var combined_with_another_empty: bool = false;
                for (empty_spots[0..empty_spots_len], 0..) |empty, e| {
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
                    empty_spots[empty_spots_len] = new_empty;
                    empty_spots_len += 1;
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
        empty_spots[empty_spots_len] = BufferSpan{
            .len = _BYTES - current_max_offset,
            .offset = current_max_offset,
        };
        empty_spots_len += 1;
    }
    comptime var wasted_bytes: usize = 0;
    const SLOT_COUNT = _NUM_FIELDS + empty_spots_len;
    comptime var all_slots: [SLOT_COUNT]FieldOrPad = undefined;
    comptime var slot_idx: usize = 0;
    for (0.._NUM_FIELDS) |fidx| {
        all_slots[slot_idx] = FieldOrPad{ .FIELD = fidx };
        slot_idx += 1;
    }
    for (empty_spots[0..empty_spots_len]) |empty| {
        all_slots[slot_idx] = FieldOrPad{ .PAD = empty };
        slot_idx += 1;
    }
    const field_locs_slice: []const usize = field_locations[0.._NUM_FIELDS];
    Sort.insertion_sort_with_func_and_userdata(FieldOrPad, all_slots[0..SLOT_COUNT], field_locs_slice, FieldOrPad.field_or_pad_offset_larger);
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
    const HLSL_STUB_INNER_MAX_LEN = (_NUM_FIELDS + (empty_spots_len * 4)) * (LONGEST_GPU_NAME + HLSL_STRUCT_LINE_EXTRA + if (_LAYOUT) (LAYOUT_LINE_EXTRA + SPACE_BEWTEEN_SHORTEST_AND_LONGEST) else 0);
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
    const hlsl_stub_final_len = comptime_writer.end - 5;
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
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr.*;
        }
        pub fn get_ptr(self: *Self, comptime field: FIELD) *type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr;
        }
        pub fn get_ptr_const(self: *Self, comptime field: FIELD) *const type_for_field_name(field) {
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

/// A field inside a `StreamStruct(FIELDS)`
pub fn StreamStructField(comptime FIELDS: type) type {
    return struct {
        const Self = @This();

        field: FIELDS,
        gpu_type: GPUType,
        semantic: HLSL_Semantic,
        interp: HLSL_INTERP_KIND,

        pub fn new(comptime field: FIELDS, comptime gpu_type: GPUType, semantic: HLSL_Semantic) Self {
            return Self{ .field = field, .gpu_type = gpu_type, .semantic = semantic, .interp = HLSL_INTERP_KIND.DEFAULT };
        }
        pub fn new_with_interp_mode(comptime field: FIELDS, comptime gpu_type: GPUType, semantic: HLSL_Semantic, interp: HLSL_INTERP_KIND) Self {
            return Self{ .field = field, .gpu_type = gpu_type, .semantic = semantic, .interp = interp };
        }

        pub fn assert_has_allowed_type(self: Self, comptime relaxed: HLSL_RelaxedSemantics, comptime src: ?std.builtin.SourceLocation) void {
            self.semantic.assert_has_allowed_type(self.gpu_type, self.interp, relaxed, @tagName(self.field), src);
        }
    };
}

/// A struct that is used as an input/output of
/// a vertex/fragment/geometry/compute shader
pub fn StreamStruct(comptime FIELDS: type, comptime INCLUDE_LAYOUT: IncludeLayoutInStub, comptime RELAXED: HLSL_RelaxedSemantics, comptime NON_SYSTEM_SEMANTICS: NonSystemSemantics, comptime fields: []const StreamStructField(FIELDS)) type {
    assert_with_reason(Types.type_is_enum(FIELDS) and Types.all_enum_values_start_from_zero_with_no_gaps(FIELDS), @src(), "type `FIELDS` must be an enum type, and all enum tags in `FIELDS` must start at zero and have no gaps up to the max tag value, got type `{s}`", .{@typeName(FIELDS)});
    const _NUM_FIELDS = Types.enum_defined_field_count(FIELDS);
    assert_with_reason(fields.len == _NUM_FIELDS, @src(), "the number of field names in `FIELDS` must equal the length of field definitions `fields`, got names {d} != {d} len", .{ _NUM_FIELDS, fields.len });
    const _Field = StreamStructField(FIELDS);
    const _LAYOUT = INCLUDE_LAYOUT == .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB;
    comptime var _fields: [_NUM_FIELDS]_Field = undefined;
    @memcpy(_fields[0.._NUM_FIELDS], fields);
    comptime var field_init: [_NUM_FIELDS]bool = @splat(false);
    comptime var field_locations: [_NUM_FIELDS]usize = undefined;
    comptime var field_types: [_NUM_FIELDS]type = undefined;
    comptime var field_sizes: [_NUM_FIELDS]usize = undefined;
    comptime var field_semantics: [_NUM_FIELDS]HLSL_Semantic = undefined;
    comptime var field_interps: [_NUM_FIELDS]HLSL_INTERP_KIND = undefined;
    comptime var field_hlsl_names: [_NUM_FIELDS]HLSL_NAME = undefined;
    comptime var single_non_system_semantics_num: [_NUM_FIELDS]?u32 = @splat(null);
    comptime var empty_spots: [_NUM_FIELDS * 2]BufferSpan = undefined;
    comptime var empty_spots_len: usize = 0;
    comptime var current_max_offset: usize = 0;
    const SORT = struct {
        fn align_lesser_then_size_lesser(a: _Field, b: _Field) bool {
            if (a.gpu_type.stream_alignment < b.gpu_type.stream_alignment) return true;
            return a.gpu_type.stream_size < a.gpu_type.stream_size;
        }
        fn offset_larger(a: BufferSpan, b: BufferSpan) bool {
            return a.offset > b.offset;
        }
    };
    Sort.insertion_sort_with_func(_Field, _fields[0.._NUM_FIELDS], SORT.align_lesser_then_size_lesser);
    comptime var used_semantics: [128]u64 = undefined;
    comptime var used_semantic_len: usize = 0;
    comptime var issued_too_many_semantic_warning: bool = false;
    // PACKING ALGORITHM
    for (_fields[0..]) |*field| {
        const fidx = @intFromEnum(field.field);
        assert_with_reason(field_init[fidx] == false, @src(), "field `{s}` was defined more than once", .{@tagName(field.field)});
        field_init[fidx] = true;
        switch (NON_SYSTEM_SEMANTICS) {
            .ALLOW_ALL_NON_SYSTEM_VALUE_SEMANTICS => {},
            .ENFORCE_SINGLE_NON_SYSTEM_VALUE_SEMANTIC => |match| {
                assert_with_reason(field.semantic == match, @src(), "semantic for field `{s}` must match `{s}`, got `{s}`", .{ @tagName(field.field), @tagName(match), @tagName(field.semantic) });
            },
        }
        if (!issued_too_many_semantic_warning) {
            if (used_semantic_len >= 128) {
                issued_too_many_semantic_warning = true;
                Assert.warn_with_reason(false, @src(), "StreamStruct({s}) had too many semantics (> 128) to fully check for duplicates", .{@typeName(FIELDS)});
            } else {
                const hash_or_null = field.semantic.get_simple_hash_if_needed();
                if (hash_or_null) |hash| {
                    for (used_semantics[0..used_semantic_len]) |used| {
                        assert_with_reason(hash != used, @src(), "StreamStruct({s}) has duplicate numbered semantic: {any}", .{ @typeName(FIELDS), field.semantic });
                    }
                    used_semantics[used_semantic_len] = hash;
                    used_semantic_len += 1;
                }
            }
        }
        single_non_system_semantics_num[fidx] = field.semantic.get_num();
        field.assert_has_allowed_type(RELAXED, @src());
        comptime var found_empty_space: bool = false;
        comptime var empty_spot_that_fits: usize = 0;
        comptime var empty_spot_offset: usize = math.maxInt(isize);
        comptime var empty_spot_space_after: usize = math.maxInt(isize);
        const needed_align = @max(field.gpu_type.stream_alignment, field.gpu_type.cpu_align);
        for (empty_spots[0..empty_spots_len], 0..) |empty, e| {
            if (empty.len >= field.gpu_type.stream_size) {
                const next_aligned_within_empty = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(empty.offset, field.gpu_type.stream_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
                const len_lost = next_aligned_within_empty - empty.offset;
                if (len_lost >= empty.len) continue;
                const aligned_len = empty.len - len_lost;
                if (aligned_len >= field.gpu_type.stream_size) {
                    const space_after = empty.len - len_lost - field.gpu_type.stream_size;
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
            const old_empty = empty_spots[empty_spot_that_fits];
            comptime var overwrite_old_empty = true;
            if (empty_spot_offset > 0) {
                const new_empty_before = BufferSpan{
                    .offset = old_empty.offset,
                    .len = empty_spot_offset,
                };
                empty_spots[empty_spot_that_fits] = new_empty_before;
                overwrite_old_empty = false;
            }
            if (empty_spot_space_after > 0) {
                const new_empty_after = BufferSpan{
                    .offset = empty_spot_offset + field.gpu_type.stream_size,
                    .len = empty_spot_space_after,
                };
                if (overwrite_old_empty) {
                    empty_spots[empty_spot_that_fits] = new_empty_after;
                    overwrite_old_empty = false;
                } else {
                    empty_spots[empty_spots_len] = new_empty_after;
                    empty_spots_len += 1;
                }
            }
            if (overwrite_old_empty) {
                Utils.mem_remove(empty_spots[0..empty_spots_len].ptr, &empty_spots_len, empty_spot_that_fits, 1);
            }
            field_loc = old_empty.offset + empty_spot_offset;
        } else {
            const next_aligned_offset = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(current_max_offset, field.gpu_type.stream_size, needed_align, GPU_UNIFORM_BOUNDARY_ALIGN);
            const new_empty_len = next_aligned_offset - current_max_offset;
            if (new_empty_len > 0) {
                comptime var combined_with_another_empty: bool = false;
                for (empty_spots[0..empty_spots_len], 0..) |empty, e| {
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
                    empty_spots[empty_spots_len] = new_empty;
                    empty_spots_len += 1;
                }
            }
            field_loc = next_aligned_offset;
            current_max_offset = next_aligned_offset + field.gpu_type.stream_size;
        }
        field_locations[fidx] = field_loc;
        field_types[fidx] = field.gpu_type.cpu_type;
        field_hlsl_names[fidx] = field.gpu_type.hlsl_name;
        field_sizes[fidx] = field.gpu_type.stream_size;
        field_semantics[fidx] = field.semantic;
        field_interps[fidx] = field.interp;
    }
    // END PACKING ALGORITHM
    const _BYTES: usize = std.mem.alignForward(usize, current_max_offset, GPU_UNIFORM_BOUNDARY_ALIGN);
    assert_with_reason(_BYTES <= MAX_SHADER_STAGE_IN_OUT_SIZE, @src(), "a shader stage can only take a maximum of 16 x (32bit x 4) vectors as an input or output ({d} bytes), got {d} bytes", .{ MAX_SHADER_STAGE_IN_OUT_SIZE, _BYTES });
    if (_BYTES > current_max_offset) {
        empty_spots[empty_spots_len] = BufferSpan{
            .len = _BYTES - current_max_offset,
            .offset = current_max_offset,
        };
        empty_spots_len += 1;
    }
    comptime var wasted_bytes: usize = 0;
    const SLOT_COUNT = _NUM_FIELDS + empty_spots_len;
    comptime var all_slots: [SLOT_COUNT]FieldOrPad = undefined;
    comptime var slot_idx: usize = 0;
    for (0.._NUM_FIELDS) |fidx| {
        all_slots[slot_idx] = FieldOrPad{ .FIELD = fidx };
        slot_idx += 1;
    }
    for (empty_spots[0..empty_spots_len]) |empty| {
        all_slots[slot_idx] = FieldOrPad{ .PAD = empty };
        slot_idx += 1;
    }
    const field_locs_slice: []const usize = field_locations[0.._NUM_FIELDS];
    Sort.insertion_sort_with_func_and_userdata(FieldOrPad, all_slots[0..SLOT_COUNT], field_locs_slice, FieldOrPad.field_or_pad_offset_larger);
    comptime var total_len_of_field_names: usize = 0;
    comptime var longest_field_name_plus_type: usize = LONGEST_PADDING_NAME_PLUS_TYPE + HLSL_SEMANTIC_KIND._LONGEST_SEMANTIC_NAME_LEN;
    comptime var shortest_field_name_plus_type: usize = SHORTEST_PADDING_NAME_PLUS_TYPE + HLSL_SEMANTIC_KIND._SHORTEST_SEMANTIC_NAME_LEN;
    for (0.._NUM_FIELDS) |fidx| {
        const F: FIELDS = @enumFromInt(fidx);
        const name_plus_type = field_interps[fidx].print_len() + @tagName(F).len + @tagName(field_hlsl_names[fidx]).len + field_semantics[fidx].print_len();
        total_len_of_field_names += name_plus_type;
        if (name_plus_type > longest_field_name_plus_type) {
            longest_field_name_plus_type = name_plus_type;
        }
        if (name_plus_type < shortest_field_name_plus_type) {
            shortest_field_name_plus_type = name_plus_type;
        }
    }
    const SPACE_BEWTEEN_SHORTEST_AND_LONGEST = longest_field_name_plus_type - shortest_field_name_plus_type;
    const HLSL_STUB_INNER_MAX_LEN = (_NUM_FIELDS + (empty_spots_len * 4)) * (LONGEST_GPU_NAME + HLSL_STRUCT_LINE_EXTRA + if (_LAYOUT) (LAYOUT_LINE_EXTRA + SPACE_BEWTEEN_SHORTEST_AND_LONGEST) else 0);
    comptime var hlsl_stub_inner: [HLSL_STUB_INNER_MAX_LEN]u8 = undefined;
    comptime var pad_idx: usize = 0;
    comptime var comptime_writer = QuickWriter.writer(hlsl_stub_inner[0..]);
    _ = comptime_writer.write(SPACE_4) catch |err| assert_comptime_write_failure(@src(), err);
    @setEvalBranchQuota(2000);
    for (all_slots[0..]) |slot| {
        switch (slot) {
            .FIELD => |fidx| {
                const fenum: FIELDS = @enumFromInt(fidx);
                const n0 = comptime_writer.write(HLSL_INTERP_KIND.NAMES[@intFromEnum(field_interps[fidx])]) catch |err| assert_comptime_write_failure(@src(), err);
                const n1 = comptime_writer.write(@tagName(field_hlsl_names[fidx])) catch |err| assert_comptime_write_failure(@src(), err);
                comptime_writer.writeByte(SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                const n2 = comptime_writer.write(@tagName(fenum)) catch |err| assert_comptime_write_failure(@src(), err);
                _ = comptime_writer.write(SPACE_COLON_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                const n3 = field_semantics[fidx].print(&comptime_writer) catch |err| assert_comptime_write_failure(@src(), err);
                if (_LAYOUT) {
                    const comment_space = longest_field_name_plus_type - (n0 + n1 + n2 + n3 + 4);
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
                        const n0 = comptime_writer.write(HLSL_INTERP_KIND.NAMES[@intFromEnum(HLSL_INTERP_KIND.NO_INTERP)]) catch |err| assert_comptime_write_failure(@src(), err);
                        const n1 = comptime_writer.write(@tagName(HLSL_PAD_TYPES[this_size])) catch |err| assert_comptime_write_failure(@src(), err);
                        const n2 = comptime_writer.write(SPACE_PAD_PREFIX) catch |err| assert_comptime_write_failure(@src(), err);
                        const n3 = Utils.print_len_of_uint(pad_idx);
                        comptime_writer.printInt(pad_idx, 10, .lower, .{}) catch |err| assert_comptime_write_failure(@src(), err);
                        _ = comptime_writer.write(SPACE_COLON_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                        const n4 = HLSL_Semantic.padding(pad_idx).print(&comptime_writer) catch |err| assert_comptime_write_failure(@src(), err);
                        if (_LAYOUT) {
                            const comment_space = longest_field_name_plus_type - (n0 + n1 + n2 + n3 + n4 + 3);
                            _ = comptime_writer.write(SEMICOL_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            for (0..comment_space) |_| {
                                comptime_writer.writeByte(' ') catch |err| assert_comptime_write_failure(@src(), err);
                            }
                            _ = comptime_writer.write(COMMENT_OFF_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            comptime_writer.printInt(curr_offset, 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                            _ = comptime_writer.write(SPACE_SIZE_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
                            comptime_writer.printInt(this_bytes, 10, .lower, .{ .alignment = .right, .width = 4 }) catch |err| assert_comptime_write_failure(@src(), err);
                            _ = comptime_writer.write(NEWLINE_4_SPACE) catch |err| assert_comptime_write_failure(@src(), err);
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
    const hlsl_stub_final_len = comptime_writer.end - 5;
    const hlsl_stub_inner_const: [hlsl_stub_final_len]u8 = make_const: {
        var out: [hlsl_stub_final_len]u8 = undefined;
        @memcpy(out[0..hlsl_stub_final_len], hlsl_stub_inner[0..hlsl_stub_final_len]);
        break :make_const out;
    };
    const field_locations_const: [_NUM_FIELDS]usize = field_locations;
    const field_types_const: [_NUM_FIELDS]type = field_types;
    const field_hlsl_names_const: [_NUM_FIELDS]HLSL_NAME = field_hlsl_names;
    const field_semanitcs_const: [_NUM_FIELDS]HLSL_Semantic = field_semantics;
    const field_interps_const: [_NUM_FIELDS]HLSL_INTERP_KIND = field_interps;
    const single_non_system_semantics_num_const: [_NUM_FIELDS]?u32 = single_non_system_semantics_num;
    const waste_bytes_const = wasted_bytes;
    return extern struct {
        const Self = @This();

        element: [BYTES]u8 align(GPU_UNIFORM_BOUNDARY_ALIGN) = @splat(0),

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
        pub const SEMANTICS: [NUM_FIELDS]HLSL_Semantic = field_semanitcs_const;
        pub const INTERPOLATIONS: [NUM_FIELDS]HLSL_INTERP_KIND = field_interps_const;
        pub const FIELD = FIELDS;
        pub const HLSL_NAMES: [NUM_FIELDS][]const u8 = field_hlsl_names_const;
        pub const HLSL_STUB_INNER = hlsl_stub_inner_const;
        pub const SINGLE_NON_SYSTEM_SEMANTIC_LOCATIONS = single_non_system_semantics_num_const;

        pub fn bytes(self: *Self) *[BYTES]u8 {
            return &self.element;
        }
        pub fn bytes_const(self: *const Self) *const [BYTES]u8 {
            return &self.element;
        }
        pub fn bytes_unbound(self: *Self) [*]u8 {
            return @ptrCast(@alignCast(&self.element));
        }
        pub fn bytes_unbound_const(self: *const Self) [*]const u8 {
            return @ptrCast(@alignCast(&self.element));
        }
        pub fn bytes_slice(self: *Self) []u8 {
            return self.element[0..BYTES];
        }
        pub fn bytes_slice_const(self: *const Self) []const u8 {
            return self.element[0..BYTES];
        }

        pub fn type_for_field_name(comptime field: FIELD) type {
            return TYPES[@intFromEnum(field)];
        }

        pub fn get_location(comptime field: FIELD) ?u32 {
            return SINGLE_NON_SYSTEM_SEMANTIC_LOCATIONS[@intFromEnum(field)];
        }
        pub fn get_offset(comptime field: FIELD) usize {
            return OFFSETS[@intFromEnum(field)];
        }
        pub fn get_size(comptime field: FIELD) usize {
            return @sizeOf(TYPES[@intFromEnum(field)]);
        }
        pub fn get(self: *const Self, comptime field: FIELD) type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound_const() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr.*;
        }
        pub fn get_ptr(self: *Self, comptime field: FIELD) *type_for_field_name(field) {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            return t_ptr.*;
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

        pub fn write_stream_struct(format: WriteFormat, struct_name: []const u8, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            switch (format) {
                .HLSL => {
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
                },
            }
        }
    };
}

fn StreamStructWriter_FuncSignatureBuilder(comptime T: type) type {
    _ = T;
    return fn (WriteFormat, []const u8, *std.Io.Writer) std.Io.Writer.Error!void;
}

const StreamStructWriter_InterfaceSignature = InterfaceSignature{
    .interface_name = "StreamStructWriter",
    .functions = &.{
        NamedFuncDefinition.define_func_with_builder(
            "write_stream_struct",
            StreamStructWriter_FuncSignatureBuilder,
        ),
    },
};

/// INTERFACE:
///   - `pub fn write_stream_struct(format: WriteFormat, struct_name: []const u8, writer: *std.Io.Writer) std.Io.Writer.Error!void`
pub const StreamStructWriterInterface = struct {
    pub fn assert_interface(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
        StreamStructWriter_InterfaceSignature.assert_type_fulfills(T, src);
    }

    pub fn write_stream_struct(comptime T: type, format: WriteFormat, struct_name: []const u8, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        const method = @field(T, "write_stream_struct");
        return method(format, struct_name, writer);
    }
};

fn StreamStructDefinition_LocationBuilder(comptime T: type) type {
    _ = T;
    return fn (comptime []const u8) u32;
}
fn StreamStructDefinition_CPUTypeBuilder(comptime T: type) type {
    _ = T;
    return fn (comptime []const u8) type;
}
fn StreamStructDefinition_UserFieldsBuilder(comptime T: type) type {
    _ = T;
    return fn () type;
}

const StreamStructDefinition_InterfaceSignature = InterfaceSignature{
    .interface_name = "StreamStructDefinition",
    .functions = &.{
        NamedFuncDefinition.define_func_with_builder(
            "get_field_location",
            StreamStructDefinition_LocationBuilder,
        ),
        NamedFuncDefinition.define_func_with_builder(
            "get_field_cpu_type",
            StreamStructDefinition_CPUTypeBuilder,
        ),
        NamedFuncDefinition.define_func_with_builder(
            "get_user_supplied_fields",
            StreamStructDefinition_UserFieldsBuilder,
        ),
    },
};

/// INTERFACE:
///   - `pub fn get_field_location(comptime field_name: []const u8) u32`
///   - `pub fn get_field_cpu_type(comptime field_name: []const u8) type`
///   - `pub fn get_user_supplied_fields() type`
///     - where return value is an `enum` type
///     - each enum tag name is a valid input for the other two required funcs
pub const StreamStructDefinitionInterface = struct {
    pub fn assert_interface(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
        StreamStructDefinition_InterfaceSignature.assert_type_fulfills(T, src);
    }

    pub fn get_field_location(comptime T: type, comptime field_name: []const u8) u32 {
        const method = @field(T, "get_field_location");
        return method(field_name);
    }

    pub fn get_field_cpu_type(comptime T: type, comptime field_name: []const u8) type {
        const method = @field(T, "get_field_cpu_type");
        return method(field_name);
    }

    pub fn get_user_supplied_fields(comptime T: type) type {
        const method = @field(T, "get_user_supplied_fields");
        return method();
    }
};

pub const WriteFormat = enum(u8) {
    HLSL,
};

pub const GPUType = struct {
    cpu_type: type,
    cpu_align: comptime_int,
    uniform_size: comptime_int,
    uniform_alignment: comptime_int,
    stream_size: comptime_int = -1,
    stream_alignment: comptime_int = -1,
    sdl_format: GPU_VertexElementFormat = .INVALID,
    hlsl_name: HLSL_NAME,

    pub fn with_cpu_type(comptime self: GPUType, comptime new_cpu_type: type) GPUType {
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = self.cpu_align,
            .sdl_format = self.sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .stream_size = self.stream_size,
            .stream_alignment = self.stream_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_type_and_align(comptime self: GPUType, comptime new_cpu_type: type, comptime new_cpu_align: comptime_int) GPUType {
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = new_cpu_align,
            .sdl_format = self.sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .stream_size = self.stream_size,
            .stream_alignment = self.stream_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_and_sdl_type(comptime self: GPUType, new_cpu_type: type, comptime new_sdl_format: GPU_VertexElementFormat) GPUType {
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = self.cpu_align,
            .sdl_format = new_sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .stream_size = self.stream_size,
            .stream_alignment = self.stream_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
    pub fn with_cpu_and_sdl_type_and_align(comptime self: GPUType, new_cpu_type: type, comptime new_sdl_format: GPU_VertexElementFormat, comptime new_cpu_align: comptime_int) GPUType {
        return GPUType{
            .cpu_type = new_cpu_type,
            .cpu_align = new_cpu_align,
            .sdl_format = new_sdl_format,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .stream_size = self.stream_size,
            .stream_alignment = self.stream_alignment,
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

// SCALARS
pub const GPU_bool = GPUType{
    .cpu_type = Bool32,
    .cpu_align = 4,
    .sdl_format = .U32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.bool,
};
pub const GPU_f32 = GPUType{
    .cpu_type = f32,
    .cpu_align = 4,
    .sdl_format = .F32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.float,
};
pub const GPU_u32 = GPUType{
    .cpu_type = u32,
    .cpu_align = 4,
    .sdl_format = .U32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.uint,
};
pub const GPU_i32 = GPUType{
    .cpu_type = i32,
    .cpu_align = 4,
    .sdl_format = .I32_x1,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.int,
};

// 2D VECTORS
pub const GPU_f32_2 = GPUType{
    .cpu_type = define_vec2_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.float2,
};
pub const GPU_u32_2 = GPUType{
    .cpu_type = define_vec2_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.uint2,
};
pub const GPU_i32_2 = GPUType{
    .cpu_type = define_vec2_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x2,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.int2,
};

// 3D VECTORS
pub const GPU_f32_3 = GPUType{
    .cpu_type = define_vec3_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.float3,
};
pub const GPU_u32_3 = GPUType{
    .cpu_type = define_vec3_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.uint3,
};
pub const GPU_i32_3 = GPUType{
    .cpu_type = define_vec3_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x3,
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_NAME.int3,
};

// 4D VECTORS
pub const GPU_f32_4 = GPUType{
    .cpu_type = define_vec4_type(f32),
    .cpu_align = 4,
    .sdl_format = .F32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 16,
    .hlsl_name = HLSL_NAME.float4,
};
pub const GPU_u32_4 = GPUType{
    .cpu_type = define_vec4_type(u32),
    .cpu_align = 4,
    .sdl_format = .U32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 16,
    .hlsl_name = HLSL_NAME.uint4,
};
pub const GPU_i32_4 = GPUType{
    .cpu_type = define_vec4_type(i32),
    .cpu_align = 4,
    .sdl_format = .I32_x4,
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 16,
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

test "hlsl_enum_stub" {
    const RENDER_MODE = enum(u32) {
        TEXT_NORMAL,
        TEXT_OUTLINE,
        SPRITE,
        SPRITE_PALETTED,
    };
    try std.fs.cwd().makePath("test_out/SDL3_ShaderContract");
    const file = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/enum_stub_1.hlsl", .{});
    defer file.close();
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try write_hlsl_enum_stub(RENDER_MODE, writer);
    try writer.flush();
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
    // SEMI_ARBITRARY
    BINORMAL = 27,
    BLENDINDICES = 28,
    BLENDWEIGHT = 29,
    COLOR = 30,
    NORMAL = 31,
    POSITION = 32,
    POSITIONT = 33,
    PSIZE = 34,
    TANGENT = 35,
    TEXCOORD = 36,
    FOG = 37,
    TESSFACTOR = 38,
    VFACE = 39,
    VPOS = 40,
    DEPTH = 41,
    // USER
    USER = 42,
    _PADDING = 43,

    pub const _COUNT = 44;
    pub const _LONGEST_SEMANTIC_NAME_LEN = 26;
    pub const _SHORTEST_SEMANTIC_NAME_LEN = 4;
    pub const _LAST_SV_SEMANTIC = 26;
};

const UserSemantic = struct {
    kind: []const u8,
    n: u32,

    pub fn new(kind: []const u8, n: u32) UserSemantic {
        return UserSemantic{ .kind = kind, .n = n };
    }
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
    // SEMI_ARBITRARY
    BINORMAL: u32,
    BLENDINDICES: u32,
    BLENDWEIGHT: u32,
    COLOR: u32,
    NORMAL: u32,
    POSITION: u32,
    POSITIONT,
    PSIZE: u32,
    TANGENT: u32,
    TEXCOORD: u32,
    FOG,
    TESSFACTOR: u32,
    VFACE,
    VPOS,
    DEPTH: u32,
    // USER
    USER: UserSemantic,
    _PADDING: u32,

    pub fn get_num(self: HLSL_Semantic) ?u32 {
        switch (self) {
            .BINORMAL,
            .BLENDINDICES,
            .BLENDWEIGHT,
            .COLOR,
            .NORMAL,
            .POSITION,
            .PSIZE,
            .TANGENT,
            .TEXCOORD,
            .SV_ClipDistance,
            .SV_CullDistance,
            .TESSFACTOR,
            ._PADDING,
            .DEPTH,
            => |nn| return nn,
            .SV_Target => |nn| return @intCast(nn),
            .USER => |sem| return sem.n,
            else => return null,
        }
    }

    pub fn get_simple_hash_if_needed(self: HLSL_Semantic) ?u64 {
        const n: u64 = switch (self) {
            .BINORMAL,
            .BLENDINDICES,
            .BLENDWEIGHT,
            .COLOR,
            .NORMAL,
            .POSITION,
            .PSIZE,
            .TANGENT,
            .TEXCOORD,
            .SV_ClipDistance,
            .SV_CullDistance,
            .TESSFACTOR,
            ._PADDING,
            .DEPTH,
            => |nn| @intCast(nn),
            .SV_Target => |nn| @intCast(nn),
            .USER => |sem| make: {
                const nn: u64 = @intCast(sem.n);
                var aa: [8]u8 = @splat(0);
                var bb: [8]u8 = @splat(0);
                for (0..@min(sem.kind.len, 5)) |i| {
                    aa[i] = sem.kind[i];
                    bb[i] = sem.kind[sem.kind.len - i - 1];
                }
                break :make nn ^ bit_cast(aa, u64) ^ bit_cast(bb, u64);
            },
            else => return null,
        };
        const t: u64 = @intCast(@intFromEnum(self));
        return (t << 55) | n;
    }

    pub fn sv_clip_distance(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .SV_ClipDistance = n };
    }
    pub fn sv_cull_distance(n: u32) HLSL_Semantic {
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
    pub fn binormal(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .BINORMAL = n };
    }
    pub fn blend_indices(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .BLENDINDICES = n };
    }
    pub fn blend_weight(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .BLENDWEIGHT = n };
    }
    pub fn color(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .COLOR = n };
    }
    pub fn normal(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .NORMAL = n };
    }
    pub fn position(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .POSITION = n };
    }
    pub fn position_transformed() HLSL_Semantic {
        return HLSL_Semantic{ .POSITION = void{} };
    }
    pub fn point_size(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .PSIZE = n };
    }
    pub fn tangent(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .TANGENT = n };
    }
    pub fn tex_coord(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .TEXCOORD = n };
    }
    pub fn fog() HLSL_Semantic {
        return HLSL_Semantic{ .FOG = void{} };
    }
    pub fn tess_factor(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .TESSFACTOR = n };
    }
    pub fn vert_face() HLSL_Semantic {
        return HLSL_Semantic{ .VFACE = void{} };
    }
    pub fn vert_pos() HLSL_Semantic {
        return HLSL_Semantic{ .VPOS = void{} };
    }
    pub fn depth(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .DEPTH = n };
    }
    pub fn user(kind: []const u8, n: u32) HLSL_Semantic {
        return HLSL_Semantic{ .USER = UserSemantic.new(kind, n) };
    }
    pub fn padding(n: u32) HLSL_Semantic {
        return HLSL_Semantic{ ._PADDING = n };
    }

    pub fn print(self: HLSL_Semantic, writer: *std.Io.Writer) std.Io.Writer.Error!usize {
        var n: usize = 0;
        switch (self) {
            .USER => |sem| {
                n += try writer.write(sem.kind);
                try writer.printInt(sem.n, 10, .lower, .{});
                n += Utils.print_len_of_uint(sem.n);
            },
            else => {
                n += try writer.write(@tagName(self));
                switch (self) {
                    .SV_ClipDistance,
                    .SV_CullDistance,
                    .BINORMAL,
                    .BLENDINDICES,
                    .BLENDWEIGHT,
                    .COLOR,
                    .NORMAL,
                    .POSITION,
                    .PSIZE,
                    .TANGENT,
                    .TEXCOORD,
                    .TESSFACTOR,
                    .DEPTH,
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
            },
        }
        return n;
    }

    pub fn print_len(self: HLSL_Semantic) usize {
        var n: usize = 3;
        switch (self) {
            .USER => |sem| {
                n += sem.kind.len;
                n += Utils.print_len_of_uint(sem.n);
            },
            else => {
                n += @tagName(self).len;
                switch (self) {
                    .SV_ClipDistance,
                    .SV_CullDistance,
                    .BINORMAL,
                    .BLENDINDICES,
                    .BLENDWEIGHT,
                    .COLOR,
                    .NORMAL,
                    .POSITION,
                    .PSIZE,
                    .TANGENT,
                    .TEXCOORD,
                    .TESSFACTOR,
                    .DEPTH,
                    => |nn| {
                        n += Utils.print_len_of_uint(nn);
                    },
                    .SV_Target => |nn| {
                        n += Utils.print_len_of_uint(nn);
                    },
                    else => {},
                }
            },
        }
        return n;
    }

    pub fn assert_has_allowed_type(self: HLSL_Semantic, gpu_type: GPUType, interp: HLSL_INTERP_KIND, comptime relaxed: HLSL_RelaxedSemantics, comptime field_name: []const u8, comptime src: ?std.builtin.SourceLocation) void {
        if (Assert.should_assert()) {
            const sem_idx = @intFromEnum(self);
            const allowed = ALLOWED_TYPES[@intFromEnum(self)];
            if (allowed.len == 0 or (relaxed == .NO_HLSL_SEMANTIC_REQUIREMENTS_FOR_NON_SYSTEM_VALUES and sem_idx > HLSL_SEMANTIC_KIND._LAST_SV_SEMANTIC)) {
                const found_valid_type = !gpu_type.equals_any_gpu_only(&.{
                    GPU_f32_1x1,
                    GPU_u32_1x1,
                    GPU_i32_1x1,
                    GPU_f32_1x2,
                    GPU_u32_1x2,
                    GPU_i32_1x2,
                    GPU_f32_1x3,
                    GPU_u32_1x3,
                    GPU_i32_1x3,
                    GPU_f32_1x4,
                    GPU_u32_1x4,
                    GPU_i32_1x4,
                    GPU_f32_2x1,
                    GPU_u32_2x1,
                    GPU_i32_2x1,
                    GPU_f32_2x2,
                    GPU_u32_2x2,
                    GPU_i32_2x2,
                    GPU_f32_2x3,
                    GPU_u32_2x3,
                    GPU_i32_2x3,
                    GPU_f32_2x4,
                    GPU_u32_2x4,
                    GPU_i32_2x4,
                    GPU_f32_3x1,
                    GPU_u32_3x1,
                    GPU_i32_3x1,
                    GPU_f32_3x2,
                    GPU_u32_3x2,
                    GPU_i32_3x2,
                    GPU_f32_3x3,
                    GPU_u32_3x3,
                    GPU_i32_3x3,
                    GPU_f32_3x4,
                    GPU_u32_3x4,
                    GPU_i32_3x4,
                    GPU_f32_4x1,
                    GPU_u32_4x1,
                    GPU_i32_4x1,
                    GPU_f32_4x2,
                    GPU_u32_4x2,
                    GPU_i32_4x2,
                    GPU_f32_4x3,
                    GPU_u32_4x3,
                    GPU_i32_4x3,
                    GPU_f32_4x4,
                    GPU_u32_4x4,
                    GPU_i32_4x4,
                });
                assert_with_reason(found_valid_type, src, "types field `{s}` with semantic `{s}` cannot be a matrix type, got `{s}`", .{ field_name, @tagName(self), gpu_type });
            } else {
                var found_valid_type = false;
                for (allowed) |gpu_t| {
                    if (gpu_type.equals_gpu_only(gpu_t)) {
                        found_valid_type = true;
                        break;
                    }
                }
                assert_with_reason(found_valid_type, src, "field `{s}` with semantic `{s}` must have one of the types `{any}`, but got type `{any}`", .{ field_name, @tagName(self), allowed, gpu_type });
            }
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
        &.{GPU_f32_4}, // BINORMAL = 27,
        &.{GPU_u32}, // BLENDINDICES = 28,
        &.{GPU_f32}, // BLENDWEIGHT = 29,
        &.{GPU_f32_4}, // COLOR = 30,
        &.{GPU_f32_4}, // NORMAL = 31,
        &.{GPU_f32_4}, // POSITION = 32,
        &.{GPU_f32_4}, // POSITIONT = 33,
        &.{GPU_f32}, // PSIZE = 34,
        &.{GPU_f32_4}, // TANGENT = 35,
        &.{GPU_f32_4}, // TEXCOORD = 36,
        &.{GPU_f32}, // FOG = 37,
        &.{GPU_f32}, // TESSFACTOR = 38,
        &.{GPU_f32}, // VFACE = 39,
        &.{GPU_f32_2}, // VPOS = 40,
        &.{GPU_f32}, // DEPTH = 41,
        &.{}, // USER = 42,
        &.{}, // _PADDING = 44,
    };
};

test "hlsl_uniform_stub" {
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
    });
    assert_with_reason(@sizeOf(MyUniform) == 96, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyUniform) == 16, @src(), "layout failed", .{});
    try std.fs.cwd().makePath("test_out/SDL3_ShaderContract");
    const file = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/uniform_stub_1.hlsl", .{});
    defer file.close();
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(file_write_buf[0..]);
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
    });
    assert_with_reason(@sizeOf(MyUniform2) == 128, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyUniform2) == 16, @src(), "layout failed", .{});
    const file2 = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/uniform_stub_2.hlsl", .{});
    defer file2.close();
    file_writer_holder = file2.writer(file_write_buf[0..]);
    writer = &file_writer_holder.interface;
    try MyUniform2.write_hlsl_uniform_stub("MyUniform2", 0, 1, writer);
    try writer.flush();
    // testing for correctness using the following link for matching field offsets
    // https://maraneshi.github.io/HLSL-ConstantBufferLayoutVisualizer/?visualizer=MYIwrgZhCmBOAEBZAngVQHYEsIHtYFsAmeALnlmgHNMBnAFzgAoQAGAGnhoAcBDYaAIwBKeAG8AUPCnwA9DPgAVAPIKAggBl4AXngDCADmmoAygFEAItt0HpAdVXGFpqy3iMApPBYA6FiyGS0hAANjg8dADMAB4ALPD44QD6AgDc0rLyOFDprpyYAF7Q0gBsLIFSIWF0nMA8wTywyWnScvBZECW5NAVF0jHl8JXhETV1DYkxzRlt2VLFcXmF0noDQ9U0tfWNhFPT7dIA7MVS3Ut9q6HhcRtjjQCsU637UvpdPcvFA5jodAJRxAk6IkdukpE9ZvAAJzHRa9eCEMrpNajLaJYq7cEdXQCGGnOHwfpIy50Yg3VERR6ZWZ6N5nF7iAC+KSAA
}

test "hlsl_storage_buffer_stub" {
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
    });
    assert_with_reason(@sizeOf(MyStruct) == 96, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyStruct) == 16, @src(), "layout failed", .{});
    try std.fs.cwd().makePath("test_out/SDL3_ShaderContract");
    const file = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/storage_stub_1.hlsl", .{});
    defer file.close();
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(file_write_buf[0..]);
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
    });
    assert_with_reason(@sizeOf(MyStruct2) == 128, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyStruct2) == 16, @src(), "layout failed", .{});
    const file2 = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/uniform_stub_2.hlsl", .{});
    defer file2.close();
    file_writer_holder = file2.writer(file_write_buf[0..]);
    writer = &file_writer_holder.interface;
    try MyStruct2.write_hlsl_storage_buffer_stub("MyStruct2", "MyStorageBuffer2", 0, 1, writer);
    try writer.flush();
}

test "build and write stream struct" {
    const F = enum(u8) {
        world_pos,
        color,
        face_normal,
        vert_normal,
        blend_mode,
    };
    const S = StreamStructField(F);
    const BlendMode = enum(u32) {
        NONE,
        SURFACE,
        FACE_ONLY,
    };
    const MyVertex = StreamStruct(F, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, .ENFORCE_STRICT_HLSL_TYPE_SEMANTICS, .ALLOW_ALL_NON_SYSTEM_VALUE_SEMANTICS, &.{
        S.new_with_interp_mode(.world_pos, GPU_f32_4, .sv_position(), .LINEAR),
        S.new(.color, GPU_f32_4, .color(0)),
        S.new(.face_normal, GPU_f32_4, .normal(0)),
        S.new(.vert_normal, GPU_f32_4, .normal(1)),
        S.new(.blend_mode, GPU_enum32(BlendMode), .user("BLENDMODE", 0)),
    });
    StreamStructWriterInterface.assert_interface(MyVertex, @src());
    // assert_with_reason(@sizeOf(MyUniform) == 96, @src(), "layout failed", .{});
    // assert_with_reason(@alignOf(MyUniform) == 16, @src(), "layout failed", .{});
    try std.fs.cwd().makePath("test_out/SDL3_ShaderContract");
    const file = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/stream_struct_1.hlsl", .{});
    defer file.close();
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try StreamStructWriterInterface.write_stream_struct(MyVertex, .HLSL, "MyStruct", writer);
    try writer.flush();
}
