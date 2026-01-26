//! This module is intended to create shader 'contracts' for passing data to and from
//! a shader fron the cpu in the correct order/location/alignment
//!
//! It is designed to follow `std140` alignment conventions and SDL3 rules for resource bindings
//! for maximum simplicity and portability, but can be used to automatically find the 'best'
//! way to pack a given set of fields.
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
const assert = std.debug.assert;

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

const define_vec2_type = Vec2.define_vec2_type;
const define_vec3_type = Vec3.define_vec3_type;
const define_vec4_type = Vec4.define_vec4_type;
const define_matx_type = Matrix.define_rectangular_RxC_matrix_type;

pub fn UniformStruct(comptime FIELDS: type, comptime fields: []const UniformStructField(FIELDS)) type {
    // CHECKPOINT do comptime magic to build the uniform buffer layout given the types and fields
    comptime var _BYTES: usize = 0;
    return struct {
        const Self = @This();

        buffer: [BLOCKS]u64,

        pub fn bytes(self: *Self) *[BYTES]u8 {
            return @ptrCast(@alignCast(self));
        }
        pub fn bytes_unbound(self: *Self) [*]u8 {
            return @ptrCast(@alignCast(self));
        }

        const BLOCKS :usize = std.mem.alignForward(usize, BYTES, 16);
        const BYTES :usize = BLOCKS * 8;
    };
}

pub fn UniformStructField(comptime FIELDS: type) type {
    return struct {
        field: FIELDS,
        type: GPUType,
        // /// Provides a *hint* for whether it would be better to place
        // /// the member closer to the beginning or the end of the struct 
        // cache_locality_hint: usize = 0,
    };
}

pub const GPUType = struct {
    cpu_type: type,
    uniform_size: comptime_int,
    uniform_alignment: comptime_int,
    stream_size: comptime_int = 0,
    stream_alignment: comptime_int = 0,
    hlsl_name: []const u8,
};

// SCALARS
pub const GPU_bool = GPUType{
    .cpu_type = Bool32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = "bool",
};
pub const GPU_f32 = GPUType{
    .cpu_type = f32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = "float",
};
pub const GPU_u32 = GPUType{
    .cpu_type = u32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_i32 = GPUType{
    .cpu_type = i32,
    .uniform_size = 4,
    .uniform_alignment = 4,
    .stream_size = 4,
    .stream_alignment = 4,
    .hlsl_name = "int",
};

// 2D VECTORS
pub const GPU_f32x2 = GPUType{
    .cpu_type = define_vec2_type(f32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = "float2",
};
pub const GPU_u32x2 = GPUType{
    .cpu_type = define_vec2_type(u32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = "uint2",
};
pub const GPU_i32x2 = GPUType{
    .cpu_type = define_vec2_type(i32),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .stream_size = 8,
    .stream_alignment = 4,
    .hlsl_name = "int2",
};

// 3D VECTORS
pub const GPU_f32x3 = GPUType{
    .cpu_type = define_vec3_type(f32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = "float3",
};
pub const GPU_u32x3 = GPUType{
    .cpu_type = define_vec3_type(u32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = "uint3",
};
pub const GPU_i32x3 = GPUType{
    .cpu_type = define_vec3_type(i32),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .stream_size = 12,
    .stream_alignment = 4,
    .hlsl_name = "int3",
};

// 4D VECTORS
pub const GPU_f32x4 = GPUType{
    .cpu_type = define_vec4_type(f32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = "float4",
};
pub const GPU_u32x4 = GPUType{
    .cpu_type = define_vec4_type(u32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = "uint4",
};
pub const GPU_i32x4 = GPUType{
    .cpu_type = define_vec4_type(i32),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .stream_size = 16,
    .stream_alignment = 4,
    .hlsl_name = "int4",
};

// MATRICES
// -- 1x1
pub const GPU_f32_1x1 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "matrix<float, 1, 1>",
};
pub const GPU_u32_1x1 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "matrix<uint, 1, 1>",
};
pub const GPU_i32_1x1 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "matrix<int, 1, 1>",
};
// ---- 2x1
pub const GPU_f32_2x1 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = "float2x1",
};
pub const GPU_u32_2x1 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = "uint2x1",
};
pub const GPU_i32_2x1 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 8,
    .uniform_alignment = 16,
    .hlsl_name = "int2x1",
};
// ---- 3x1
pub const GPU_f32_3x1 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = "float3x1",
};
pub const GPU_u32_3x1 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = "uint3x1",
};
pub const GPU_i32_3x1 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 12,
    .uniform_alignment = 16,
    .hlsl_name = "int3x1",
};
// ---- 4x1
pub const GPU_f32_4x1 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "float4x1",
};
pub const GPU_u32_4x1 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4x1",
};
pub const GPU_i32_4x1 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 1, .COLUMN_MAJOR, 0),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "int4x1",
};
// ---- 1x2
pub const GPU_f32_1x2 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = "float1x2",
};
pub const GPU_u32_1x2 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = "uint1x2",
};
pub const GPU_i32_1x2 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 2, .COLUMN_MAJOR, 3),
    .uniform_size = 20,
    .uniform_alignment = 16,
    .hlsl_name = "int1x2",
};
// ---- 2x2
pub const GPU_f32_2x2 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = "float2x2",
};
pub const GPU_u32_2x2 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = "uint2x2",
};
pub const GPU_i32_2x2 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 2, .COLUMN_MAJOR, 2),
    .uniform_size = 24,
    .uniform_alignment = 16,
    .hlsl_name = "int2x2",
};
// ---- 3x2
pub const GPU_f32_3x2 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = "float3x2",
};
pub const GPU_u32_3x2 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = "uint3x2",
};
pub const GPU_i32_3x2 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 2, .COLUMN_MAJOR, 1),
    .uniform_size = 28,
    .uniform_alignment = 16,
    .hlsl_name = "int3x2",
};
// ---- 4x2
pub const GPU_f32_4x2 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = "float4x2",
};
pub const GPU_u32_4x2 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = "uint4x2",
};
pub const GPU_i32_4x2 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 2, .COLUMN_MAJOR, 0),
    .uniform_size = 32,
    .uniform_alignment = 16,
    .hlsl_name = "int4x2",
};
// ---- 1x3
pub const GPU_f32_1x3 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = "float1x3",
};
pub const GPU_u32_1x3 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = "uint1x3",
};
pub const GPU_i32_1x3 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 3, .COLUMN_MAJOR, 3),
    .uniform_size = 36,
    .uniform_alignment = 16,
    .hlsl_name = "int1x3",
};
// ---- 2x3
pub const GPU_f32_2x3 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = "float2x3",
};
pub const GPU_u32_2x3 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = "uint2x3",
};
pub const GPU_i32_2x3 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 3, .COLUMN_MAJOR, 2),
    .uniform_size = 40,
    .uniform_alignment = 16,
    .hlsl_name = "int2x3",
};
// ---- 3x3
pub const GPU_f32_3x3 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = "float3x3",
};
pub const GPU_u32_3x3 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = "uint3x3",
};
pub const GPU_i32_3x3 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 3, .COLUMN_MAJOR, 1),
    .uniform_size = 44,
    .uniform_alignment = 16,
    .hlsl_name = "int3x3",
};
// ---- 4x3
pub const GPU_f32_4x3 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = "float4x3",
};
pub const GPU_u32_4x3 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = "uint4x3",
};
pub const GPU_i32_4x3 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 3, .COLUMN_MAJOR, 0),
    .uniform_size = 48,
    .uniform_alignment = 16,
    .hlsl_name = "int4x3",
};
// ---- 1x4
pub const GPU_f32_1x4 = GPUType{
    .cpu_type = define_matx_type(f32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = "float1x4",
};
pub const GPU_u32_1x4 = GPUType{
    .cpu_type = define_matx_type(u32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = "uint1x4",
};
pub const GPU_i32_1x4 = GPUType{
    .cpu_type = define_matx_type(i32, 1, 4, .COLUMN_MAJOR, 3),
    .uniform_size = 52,
    .uniform_alignment = 16,
    .hlsl_name = "int1x4",
};
// ---- 2x4
pub const GPU_f32_2x4 = GPUType{
    .cpu_type = define_matx_type(f32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = "float2x4",
};
pub const GPU_u32_2x4 = GPUType{
    .cpu_type = define_matx_type(u32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = "uint2x4",
};
pub const GPU_i32_2x4 = GPUType{
    .cpu_type = define_matx_type(i32, 2, 4, .COLUMN_MAJOR, 2),
    .uniform_size = 56,
    .uniform_alignment = 16,
    .hlsl_name = "int2x4",
};
// ---- 3x4
pub const GPU_f32_3x4 = GPUType{
    .cpu_type = define_matx_type(f32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = "float3x4",
};
pub const GPU_u32_3x4 = GPUType{
    .cpu_type = define_matx_type(u32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = "uint3x4",
};
pub const GPU_i32_3x4 = GPUType{
    .cpu_type = define_matx_type(i32, 3, 4, .COLUMN_MAJOR, 1),
    .uniform_size = 60,
    .uniform_alignment = 16,
    .hlsl_name = "int3x4",
};
// ---- 4x4
pub const GPU_f32_4x4 = GPUType{
    .cpu_type = define_matx_type(f32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = "float4x4",
};
pub const GPU_u32_4x4 = GPUType{
    .cpu_type = define_matx_type(u32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = "uint4x4",
};
pub const GPU_i32_4x4 = GPUType{
    .cpu_type = define_matx_type(i32, 4, 4, .COLUMN_MAJOR, 0),
    .uniform_size = 64,
    .uniform_alignment = 16,
    .hlsl_name = "int4x4",
};

// PACKED
// -- 4 bytes
pub const GPU_u8_4 = GPUType{
    .cpu_type = define_vec4_type(u8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_i8_4 = GPUType{
    .cpu_type = define_vec4_type(i8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_bool_4 = GPUType{
    .cpu_type = define_vec4_type(bool),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_f16_2 = GPUType{
    .cpu_type = define_vec2_type(f16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_u16_2 = GPUType{
    .cpu_type = define_vec2_type(u16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
pub const GPU_i16_2 = GPUType{
    .cpu_type = define_vec2_type(i16),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint",
};
// -- 8 bytes
pub const GPU_u8_8 = GPUType{
    .cpu_type = define_vec4_type(u8),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_i8_8 = GPUType{
    .cpu_type = define_vec4_type(i8),
    .uniform_size = 4,
    .uniform_alignment = 4,
    .hlsl_name = "uint2",
};
pub const GPU_bool_8 = GPUType{
    .cpu_type = define_vec4_type(bool),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_f16_4 = GPUType{
    .cpu_type = define_vec2_type(f16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_u16_4 = GPUType{
    .cpu_type = define_vec2_type(u16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_i16_4 = GPUType{
    .cpu_type = define_vec2_type(i16),
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_f64 = GPUType{
    .cpu_type = f64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_u64 = GPUType{
    .cpu_type = u64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
pub const GPU_i64 = GPUType{
    .cpu_type = i64,
    .uniform_size = 8,
    .uniform_alignment = 8,
    .hlsl_name = "uint2",
};
// -- 16 bytes
pub const GPU_u8_16 = GPUType{
    .cpu_type = @Vector(16, u8),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_i8_16 = GPUType{
    .cpu_type = @Vector(16, i8),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_bool_16 = GPUType{
    .cpu_type = @Vector(16, bool),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_f16_8 = GPUType{
    .cpu_type = @Vector(8, f16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_u16_8 = GPUType{
    .cpu_type = @Vector(8, u16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_i16_8 = GPUType{
    .cpu_type = @Vector(8, i16),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_f64_2 = GPUType{
    .cpu_type = define_vec2_type(f64),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_u64_2 = GPUType{
    .cpu_type = define_vec2_type(u64),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
pub const GPU_i64_2 = GPUType{
    .cpu_type = define_vec2_type(i64),
    .uniform_size = 16,
    .uniform_alignment = 16,
    .hlsl_name = "uint4",
};
