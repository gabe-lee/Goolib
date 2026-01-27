//! This module is intended to create shader 'contracts' for passing data to and from
//! a shader fron the cpu in the correct order/location/alignment
//!
//! `UniformStruct` is designed to follow `std140` alignment conventions
//! for maximum simplicity and portability, and will automatically find the 'best'
//! way to pack a given set of fields for minimal waste.
//!
//! For compatibility reasons, types that are not 32 bits are only supported with 'packed' types and must be
//! unpacked on the GPU side either using a provided function or manually.
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

const assert_with_reason = Assert.assert_with_reason;
const assert_comptime_write_failure = Assert.assert_comptime_write_failure;
const num_cast = Cast.num_cast;

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
const SPACE_COLON_SPACE_REGISTER = " : register(";
const HLSL_UNIFORM_REGISTER = 'b';
const HLSL_TESTURE_REGISTER = 't';
const HLSL_SAMPLER_REGISTER = 's';
const HLSL_UNORDERED_REGISTER = 'u';
const COMMA_SPACE_HLSL_LAYER = ", space";
const OPEN_PAREN = '(';
const CLOSE_PAREN = ')';
const CLOSE_PAREN_NEWLINE = ")\n";
const OPEN_BRACKET = '{';
const CLOSE_BRACKET = '}';
const NEWLINE_CLOSE_BRACKET_SEMICOL_NEWLINE = "\n};\n";
const CLOSE_PAREN_SPACE_OPEN_BRACKET_NEWLINE = ") {\n";
const SEMICOL_NEWLINE = ";\n";
const SEMICOL_NEWLINE_4_SPACE = ";\n    ";
const NEWLINE_4_SPACE = "\n    ";
const SEMICOL_SPACE_COMMENT_OFF = "; // off ";
const SEMICOL_SPACE = "; ";
const COMMENT_OFF_SPACE = "// off ";
const COMMENT_TOTAL_SIZE = "    // TOTAL = ";
const USED_SIZE = "   USED = ";
const WASTE_SIZE = "   WASTE = ";
const PAREN_PERCENT = " (%";
const SPACE_SIZE_SPACE = "  size ";
const SPACE_PAD_PREFIX = " __pad__";
const HLSL_CBUFFER_SPACE = "cbuffer ";
const INVALID = "INVALID";

const HLSL_PAD_TYPES = [5][]const u8{
    INVALID, // no 1 byte types supported
    HLSL_u32, // FIXME 2 byte types *could* be supported
    HLSL_u32,
    HLSL_u32_2,
    HLSL_u32_4,
};
const LONGEST_GPU_NAME = 15;
const HLSL_STRUCT_LINE_EXTRA = 8;
const LAYOUT_LINE_EXTRA = 22;

const GPU_CACHE_LINE = 128;
const GPU_UNIFORM_BOUNDARY_ALIGN = 16;

pub const IncludeLayoutInStub = enum(u8) {
    NO_LAYOUT_COMMENTS_IN_SHADER_STUB,
    INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
};

pub fn UniformStruct(comptime FIELDS: type, comptime INCLUDE_LAYOUT: IncludeLayoutInStub, comptime fields: []const UniformStructField(FIELDS)) type {
    assert_with_reason(Types.type_is_enum(FIELDS) and Types.all_enum_values_start_from_zero_with_no_gaps(FIELDS), @src(), "type `FIELDS` must be an enum type, and all enum tags in `FIELDS` must start at zero and have no gaps up to the max tag value, got type `{s}`", .{@typeName(FIELDS)});
    const _NUM_FIELDS = Types.enum_defined_field_count(FIELDS);
    assert_with_reason(fields.len == _NUM_FIELDS, @src(), "the number of field names in `FIELDS` must equal the length of field definitions `fields`, got names {d} != {d} len", .{ _NUM_FIELDS, fields.len });
    const _Field = UniformStructField(FIELDS);
    const _LAYOUT = INCLUDE_LAYOUT == .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB;
    comptime var _fields: [_NUM_FIELDS]_Field = undefined;
    @memcpy(_fields[0.._NUM_FIELDS], fields);
    comptime var field_init: [_NUM_FIELDS]bool = @splat(false);
    comptime var field_locations: [_NUM_FIELDS]usize = undefined;
    comptime var field_types: [_NUM_FIELDS]type = undefined;
    comptime var field_sizes: [_NUM_FIELDS]usize = undefined;
    comptime var field_hlsl_names: [_NUM_FIELDS][]const u8 = undefined;
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
    for (_fields) |field| {
        const fidx = @intFromEnum(field.field);
        assert_with_reason(field_init[fidx] == false, @src(), "field `{s}` was defined more than once", .{@tagName(field.field)});
        field_init[fidx] = true;
        comptime var found_empty_space: bool = false;
        comptime var empty_spot_that_fits: usize = 0;
        comptime var empty_spot_offset: usize = math.maxInt(isize);
        comptime var empty_spot_space_after: usize = math.maxInt(isize);
        for (empty_spots[0..empty_spots_len], 0..) |empty, e| {
            if (empty.len >= field.gpu_type.uniform_size) {
                const next_aligned_within_empty = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(empty.offset, field.gpu_type.uniform_size, field.gpu_type.uniform_alignment, GPU_UNIFORM_BOUNDARY_ALIGN);
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
            const next_aligned_offset = Utils.align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(current_max_offset, field.gpu_type.uniform_size, field.gpu_type.uniform_alignment, GPU_UNIFORM_BOUNDARY_ALIGN);
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
        const name_plus_type = @tagName(F).len + field_hlsl_names[fidx].len + 1;
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
                const n1 = comptime_writer.write(field_hlsl_names[fidx]) catch |err| assert_comptime_write_failure(@src(), err);
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
                        const n1 = comptime_writer.write(HLSL_PAD_TYPES[this_size]) catch |err| assert_comptime_write_failure(@src(), err);
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
    const field_hlsl_names_const: [_NUM_FIELDS][]const u8 = field_hlsl_names;
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
            return t_ptr.*;
        }
        pub fn set(self: *Self, comptime field: FIELD, val: type_for_field_name(field)) void {
            const T = type_for_field_name(field);
            const offset = OFFSETS[@intFromEnum(field)];
            const ptr = self.bytes_unbound() + offset;
            const t_ptr: *T = @ptrCast(@alignCast(ptr));
            t_ptr.* = val;
        }

        pub fn write_hlsl_cbuffer_stub(struct_name: []const u8, resgister_num: usize, space_num: usize, writer: *std.Io.Writer) std.Io.Writer.Error!void {
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
    };
}

pub fn UniformStructField(comptime FIELDS: type) type {
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

pub const GPUType = struct {
    cpu_type: type,
    uniform_size: comptime_int,
    uniform_alignment: comptime_int,
    stream_size: comptime_int = -1,
    stream_alignment: comptime_int = -1,
    hlsl_name: []const u8,

    pub fn with_cpu_type(comptime self: GPUType, new_cpu_type: type) GPUType {
        return GPUType{
            .cpu_type = new_cpu_type,
            .uniform_size = self.uniform_size,
            .uniform_alignment = self.uniform_alignment,
            .stream_size = self.stream_size,
            .stream_alignment = self.stream_alignment,
            .hlsl_name = self.hlsl_name,
        };
    }
};

// SCALARS
const HLSL_f32 = "float";
const HLSL_u32 = "uint";
const HLSL_i32 = "int";
const HLSL_bool = "bool";
pub const GPU_bool = GPUType{
    .cpu_type = Bool32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_bool,
};
pub const GPU_f32 = GPUType{
    .cpu_type = f32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_f32,
};
pub const GPU_u32 = GPUType{
    .cpu_type = u32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_i32 = GPUType{
    .cpu_type = i32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = HLSL_i32,
};

// 2D VECTORS
const HLSL_f32_2 = "float2";
const HLSL_u32_2 = "uint2";
const HLSL_i32_2 = "int2";
pub const GPU_f32_2 = GPUType{
    .cpu_type = define_vec2_type(f32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_f32_2,
};
pub const GPU_u32_2 = GPUType{
    .cpu_type = define_vec2_type(u32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_i32_2 = GPUType{
    .cpu_type = define_vec2_type(i32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = HLSL_i32_2,
};

// 3D VECTORS
const HLSL_f32_3 = "float3";
const HLSL_u32_3 = "uint3";
const HLSL_i32_3 = "int3";
pub const GPU_f32_3 = GPUType{
    .cpu_type = define_vec3_type(f32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_f32_3,
};
pub const GPU_u32_3 = GPUType{
    .cpu_type = define_vec3_type(u32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_u32_3,
};
pub const GPU_i32_3 = GPUType{
    .cpu_type = define_vec3_type(i32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = HLSL_i32_3,
};

// 4D VECTORS
const HLSL_f32_4 = "float4";
const HLSL_u32_4 = "uint4";
const HLSL_i32_4 = "int4";
pub const GPU_f32_4 = GPUType{
    .cpu_type = define_vec4_type(f32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = HLSL_f32_4,
};
pub const GPU_u32_4 = GPUType{
    .cpu_type = define_vec4_type(u32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_i32_4 = GPUType{
    .cpu_type = define_vec4_type(i32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = HLSL_i32_4,
};

// MATRICES
// -- 1x1
const HLSL_f32_1x1 = "float1x1";
const HLSL_u32_1x1 = "uint1x1";
const HLSL_i32_1x1 = "int1x1";
pub const GPU_f32_1x1 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_f32_1x1,
};
pub const GPU_u32_1x1 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32_1x1,
};
pub const GPU_i32_1x1 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_i32_1x1,
};
// ---- 2x1
const HLSL_f32_2x1 = "float2x1";
const HLSL_u32_2x1 = "uint2x1";
const HLSL_i32_2x1 = "int2x1";
pub const GPU_f32_2x1 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_2x1,
};
pub const GPU_u32_2x1 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_2x1,
};
pub const GPU_i32_2x1 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_2x1,
};
// ---- 3x1
const HLSL_f32_3x1 = "float3x1";
const HLSL_u32_3x1 = "uint3x1";
const HLSL_i32_3x1 = "int3x1";
pub const GPU_f32_3x1 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_3x1,
};
pub const GPU_u32_3x1 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_3x1,
};
pub const GPU_i32_3x1 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_3x1,
};
// ---- 4x1
const HLSL_f32_4x1 = "float4x1";
const HLSL_u32_4x1 = "uint4x1";
const HLSL_i32_4x1 = "int4x1";
pub const GPU_f32_4x1 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_4x1,
};
pub const GPU_u32_4x1 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4x1,
};
pub const GPU_i32_4x1 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_4x1,
};
// ---- 1x2
const HLSL_f32_1x2 = "float1x2";
const HLSL_u32_1x2 = "uint1x2";
const HLSL_i32_1x2 = "int1x2";
pub const GPU_f32_1x2 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_1x2,
};
pub const GPU_u32_1x2 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_1x2,
};
pub const GPU_i32_1x2 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_1x2,
};
// ---- 2x2
const HLSL_f32_2x2 = "float2x2";
const HLSL_u32_2x2 = "uint2x2";
const HLSL_i32_2x2 = "int2x2";
pub const GPU_f32_2x2 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_2x2,
};
pub const GPU_u32_2x2 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_2x2,
};
pub const GPU_i32_2x2 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_2x2,
};
// ---- 3x2
const HLSL_f32_3x2 = "float3x2";
const HLSL_u32_3x2 = "uint3x2";
const HLSL_i32_3x2 = "int3x2";
pub const GPU_f32_3x2 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_3x2,
};
pub const GPU_u32_3x2 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_3x2,
};
pub const GPU_i32_3x2 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_3x2,
};
// ---- 4x2
const HLSL_f32_4x2 = "float4x2";
const HLSL_u32_4x2 = "uint4x2";
const HLSL_i32_4x2 = "int4x2";
pub const GPU_f32_4x2 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_4x2,
};
pub const GPU_u32_4x2 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4x2,
};
pub const GPU_i32_4x2 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_4x2,
};
// ---- 1x3
const HLSL_f32_1x3 = "float1x3";
const HLSL_u32_1x3 = "uint1x3";
const HLSL_i32_1x3 = "int1x3";
pub const GPU_f32_1x3 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_1x3,
};
pub const GPU_u32_1x3 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_1x3,
};
pub const GPU_i32_1x3 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_1x3,
};
// ---- 2x3
const HLSL_f32_2x3 = "float2x3";
const HLSL_u32_2x3 = "uint2x3";
const HLSL_i32_2x3 = "int2x3";
pub const GPU_f32_2x3 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_2x3,
};
pub const GPU_u32_2x3 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_2x3,
};
pub const GPU_i32_2x3 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_2x3,
};
// ---- 3x3
const HLSL_f32_3x3 = "float3x3";
const HLSL_u32_3x3 = "uint3x3";
const HLSL_i32_3x3 = "int3x3";
pub const GPU_f32_3x3 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_3x3,
};
pub const GPU_u32_3x3 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_3x3,
};
pub const GPU_i32_3x3 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_3x3,
};
// ---- 4x3
const HLSL_f32_4x3 = "float4x3";
const HLSL_u32_4x3 = "uint4x3";
const HLSL_i32_4x3 = "int4x3";
pub const GPU_f32_4x3 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_4x3,
};
pub const GPU_u32_4x3 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4x3,
};
pub const GPU_i32_4x3 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_4x3,
};
// ---- 1x4
const HLSL_f32_1x4 = "float1x4";
const HLSL_u32_1x4 = "uint1x4";
const HLSL_i32_1x4 = "int1x4";
pub const GPU_f32_1x4 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_1x4,
};
pub const GPU_u32_1x4 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_1x4,
};
pub const GPU_i32_1x4 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_1x4,
};
// ---- 2x4
const HLSL_f32_2x4 = "float2x4";
const HLSL_u32_2x4 = "uint2x4";
const HLSL_i32_2x4 = "int2x4";
pub const GPU_f32_2x4 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_2x4,
};
pub const GPU_u32_2x4 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_2x4,
};
pub const GPU_i32_2x4 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_2x4,
};
// ---- 3x4
const HLSL_f32_3x4 = "float3x4";
const HLSL_u32_3x4 = "uint3x4";
const HLSL_i32_3x4 = "int3x4";
pub const GPU_f32_3x4 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_3x4,
};
pub const GPU_u32_3x4 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_3x4,
};
pub const GPU_i32_3x4 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_3x4,
};
// ---- 4x4
const HLSL_f32_4x4 = "float4x4";
const HLSL_u32_4x4 = "uint4x4";
const HLSL_i32_4x4 = "int4x4";
pub const GPU_f32_4x4 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_f32_4x4,
};
pub const GPU_u32_4x4 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4x4,
};
pub const GPU_i32_4x4 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_i32_4x4,
};

// PACKED
// -- 4 bytes
pub const GPU_u8_4 = GPUType{
    .cpu_type = define_vec4_type(u8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_i8_4 = GPUType{
    .cpu_type = define_vec4_type(i8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_bool_4 = GPUType{
    .cpu_type = define_vec4_type(bool),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_f16_2 = GPUType{
    .cpu_type = define_vec2_type(f16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_u16_2 = GPUType{
    .cpu_type = define_vec2_type(u16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
pub const GPU_i16_2 = GPUType{
    .cpu_type = define_vec2_type(i16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32,
};
// -- 8 bytes
pub const GPU_u8_8 = GPUType{
    .cpu_type = define_vec4_type(u8),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_i8_8 = GPUType{
    .cpu_type = define_vec4_type(i8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_bool_8 = GPUType{
    .cpu_type = define_vec4_type(bool),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_f16_4 = GPUType{
    .cpu_type = define_vec2_type(f16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_u16_4 = GPUType{
    .cpu_type = define_vec2_type(u16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_i16_4 = GPUType{
    .cpu_type = define_vec2_type(i16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_f64 = GPUType{
    .cpu_type = f64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_u64 = GPUType{
    .cpu_type = u64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
pub const GPU_i64 = GPUType{
    .cpu_type = i64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = HLSL_u32_2,
};
// -- 16 bytes
pub const GPU_u8_16 = GPUType{
    .cpu_type = @Vector(16, u8),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_i8_16 = GPUType{
    .cpu_type = @Vector(16, i8),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_bool_16 = GPUType{
    .cpu_type = @Vector(16, bool),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_f16_8 = GPUType{
    .cpu_type = @Vector(8, f16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_u16_8 = GPUType{
    .cpu_type = @Vector(8, u16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_i16_8 = GPUType{
    .cpu_type = @Vector(8, i16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = HLSL_u32_4,
};
pub const GPU_f64_2 = GPU_u32_4.with_cpu_type(define_vec2_type(f64));
pub const GPU_u64_2 = GPU_u32_4.with_cpu_type(define_vec2_type(u64));
pub const GPU_i64_2 = GPU_u32_4.with_cpu_type(define_vec2_type(i64));

// SPECIAL
pub fn GPU_enum(comptime ENUM_TYPE: type) GPUType {
    assert_with_reason(Types.type_is_enum(ENUM_TYPE) and Types.enum_tag_type(ENUM_TYPE) == u32, @src(), "type `ENUM_TYPE` must be an enum type with tag type of u32, got type `{s}`", .{@typeName(ENUM_TYPE)});
    return GPU_u32.with_cpu_type(ENUM_TYPE);
}

test "hlsl_uniform_stub" {
    const F = enum(u8) {
        world_pos,
        main_color,
        projection_matrix,
        secondary_color,
        shader_mode,
        hamburgers_good,
    };
    const U = UniformStructField(F);
    const ShaderMode = enum(u32) {
        SPRITE,
        TEXT,
    };
    const MyUniform = UniformStruct(F, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
        U.new(.world_pos, GPU_f32_3),
        U.new(.main_color, GPU_u32),
        U.new(.secondary_color, GPU_u32),
        U.new(.shader_mode, GPU_enum(ShaderMode)),
        U.new(.projection_matrix, GPU_f32_4x4),
        U.new(.hamburgers_good, GPU_bool),
    });
    assert_with_reason(@sizeOf(MyUniform) == 96, @src(), "layout failed", .{});
    assert_with_reason(@alignOf(MyUniform) == 16, @src(), "layout failed", .{});
    try std.fs.cwd().makePath("test_out/SDL3_ShaderContract");
    const file = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/test_stub_1.hlsl", .{});
    defer file.close();
    var file_write_buf: [512]u8 = undefined;
    var file_writer_holder = file.writer(file_write_buf[0..]);
    var writer = &file_writer_holder.interface;
    try MyUniform.write_hlsl_cbuffer_stub("MyUniform", 0, 1, writer);
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
    const U2 = UniformStructField(F2);
    const MyUniform2 = UniformStruct(F2, .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB, &.{
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
    const file2 = try std.fs.cwd().createFile("test_out/SDL3_ShaderContract/test_stub_2.hlsl", .{});
    defer file2.close();
    file_writer_holder = file2.writer(file_write_buf[0..]);
    writer = &file_writer_holder.interface;
    try MyUniform2.write_hlsl_cbuffer_stub("MyUniform2", 0, 1, writer);
    try writer.flush();
    // testing for correctness using the following link for matching field offsets
    // https://maraneshi.github.io/HLSL-ConstantBufferLayoutVisualizer/?visualizer=MYIwrgZhCmBOAEBZAngVQHYEsIHtYFsAmeALnlmgHNMBnAFzgAoQAGAGnhoAcBDYaAIwBKeAG8AUPCnwA9DPgAVAPIKAggBl4AXngDCADmmoAygFEAItt0HpAdVXGFpqy3iMApPBYA6FiyGS0hAANjg8dADMAB4ALPD44QD6AgDc0rLyOFDprpyYAF7Q0gBsLIFSIWF0nMA8wTywyWnScvBZECW5NAVF0jHl8JXhETV1DYkxzRlt2VLFcXmF0noDQ9U0tfWNhFPT7dIA7MVS3Ut9q6HhcRtjjQCsU637UvpdPcvFA5jodAJRxAk6IkdukpE9ZvAAJzHRa9eCEMrpNajLaJYq7cEdXQCGGnOHwfpIy50Yg3VERR6ZWZ6N5nF7iAC+KSAA
}
