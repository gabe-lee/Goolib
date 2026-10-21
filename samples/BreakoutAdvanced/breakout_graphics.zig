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

const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Goolib = @import("Goolib");
const SDL = Goolib.SDL3;
const AABB = Goolib.AABB2.define_aabb2_type(f32);
const Rect = Goolib.Rect2.define_rect2_type(f32);
const FVec: type = SDL.Vec_f32;
const IVec: type = SDL.Vec_c_int;
const Cast = Goolib.Cast;
const c_strings_equal = Goolib.Utils.c_strings_equal;
const ANSI = Goolib.ANSI;

const GPU_IndexTypeSize = SDL.GPU_IndexTypeSize;

pub const GraphicsControllerModule = Goolib.SDL3.GraphicsController;
pub const ShaderUtilsModule = Goolib.SDL3.ShaderUtils;
pub const GPUType = ShaderUtilsModule.GPUType;
pub const VertexShaderDefinition = GraphicsControllerModule.VertexShaderDefinition(VERTEX_SHADER_NAMES, VERTEX_INPUT_STRUCT_NAMES, VERT_TO_FRAG_STRUCT_NAMES, UNIFORM_NAMES, STORAGE_BUFFER_NAMES, TEXTURE_NAMES, SAMPLER_NAMES);
pub const FragmentShaderDefinition = GraphicsControllerModule.FragmentShaderDefinition(FRAGMENT_SHADER_NAMES, VERT_TO_FRAG_STRUCT_NAMES, FRAGMENT_OUTPUT_STRUCT_NAMES, UNIFORM_NAMES, STORAGE_BUFFER_NAMES, TEXTURE_NAMES, SAMPLER_NAMES);
pub const SamplerDefinition = GraphicsControllerModule.SamplerDefinition(SAMPLER_NAMES);
pub const RenderPipelineDefinition = GraphicsControllerModule.RenderPipelineDefinition(RENDER_PIPELINE_NAMES, VERTEX_SHADER_NAMES, FRAGMENT_SHADER_NAMES);
pub const WINDOW_NAMES = enum(u8) {
    MAIN,
};
pub const FENCE_NAMES = enum(u8) {
    GPU_COMMANDS_COMPLETE,
};
pub const INDEX_BUFFER_NAMES = enum(u8) {
    VERT_INDEXES,
};
pub const INDIRECT_BUFFER_NAMES = enum(u8) {};
pub const UPLOAD_BUFFER_NAMES = enum(u8) {
    MAIN_UPLOAD_BUFFER,
};
pub const DOWNLOAD_BUFFER_NAMES = enum(u8) {
    MAIN_DOWNLOAD_BUFFER,
};
pub const VERTEX_BUFFER_NAMES = enum(u8) {
    VERTEX_POSITIONS,
    SPRITE_VERTEX_INDEXES,
};
pub const VERTEX_INPUT_STRUCT_NAMES = enum(u8) {
    VERTEX_IN,
};
pub const VERT_TO_FRAG_STRUCT_NAMES = enum(u8) {
    VERT_TO_FRAG,
};
pub const FRAGMENT_OUTPUT_STRUCT_NAMES = enum(u8) {
    FRAGMENT_OUT,
};
pub const UNIFORM_NAMES = enum(u8) {
    WINDOW_RENDER_INFO,
};
pub const SAMPLER_NAMES = enum(u8) {
    PIXEL_SAMPLER,
};
pub const STORAGE_BUFFER_NAMES = enum(u8) {
    SPRITE_VERTEX_DATA,
};
pub const TEXTURE_NAMES = enum(u8) {
    SPRITE_TEX,
};
pub const VERTEX_SHADER_NAMES = enum(u8) {
    MAIN_VERTEX_SHADER,
};
pub const FRAGMENT_SHADER_NAMES = enum(u8) {
    MAIN_FRAGMENT_SHADER,
};
pub const RENDER_PIPELINE_NAMES = enum(u8) {
    MAIN_PIPELINE,
};
pub const MAIN_PIPE_COLOR_TARGETS = [_]SDL.GPU_ColorTargetDescription{
    SDL.GPU_ColorTargetDescription{
        .format = .B8G8R8A8_UNORM,
        .blend_state = .{
            .enable_blend = true,
            .color_blend_op = .ADD,
            .alpha_blend_op = .ADD,
            .src_color_blendfactor = .SRC_ALPHA,
            .dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
            .src_alpha_blendfactor = .SRC_ALPHA,
            .dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
        },
    },
};
pub const VertexIn = ShaderUtilsModule.VertexShaderInputStruct(
    "vertex_in",
    enum {
        position,
        sprite_vertex,
    },
    VERTEX_BUFFER_NAMES,
    .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
    &.{
        .vertex_field_advanced(.position, GPUType.GPU_f32_2, .USER, .NO_INTERP, 0, .VERTEX_POSITIONS),
        .vertex_field_advanced(.sprite_vertex, GPUType.GPU_u32, .USER, .NO_INTERP, 1, .SPRITE_VERTEX_INDEXES),
    },
    1000,
);
pub const VertexToFrag = ShaderUtilsModule.VertexToFragmentStruct(
    "vert_to_frag",
    enum {
        vert_pos,
        tex_pos,
    },
    .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
    &.{
        .vert_to_frag_field(.vert_pos, GPUType.GPU_f32_4, .sv_position()),
        .vert_to_frag_field_advanced(.tex_pos, GPUType.GPU_f32_2, .user(0), .LINEAR_NO_PERSPECTIVE),
    },
    1000,
);
pub const FragmentOut = ShaderUtilsModule.FragmentShaderOutputStruct(
    "fragment_out",
    enum {
        color,
    },
    .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
    &.{
        .target(.color, GPUType.GPU_f32_4, 0),
    },
    1000,
);
pub const WindowRenderInfo = ShaderUtilsModule.UniformOrStorageStruct(
    enum {
        camera_offset,
        target_size,
    },
    .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
    &.{
        .uniform_field(.camera_offset, GPUType.GPU_f32_2),
        .uniform_field(.target_size, GPUType.GPU_f32_2),
    },
    100000,
);
pub const SpriteData = ShaderUtilsModule.UniformOrStorageStruct(
    enum {
        texture_uv,
    },
    .INCLUDE_LAYOUT_COMMENTS_IN_SHADER_STUB,
    &.{
        .storage_struct_field(.texture_uv, GPUType.GPU_f32_2),
    },
    100000,
);
pub const Controller = GraphicsControllerModule.GraphicsController(
    .{
        .shader_formats = .flags(&.{ .MSL, .DXIL, .SPIRV }),
        .debug_mode = true,
        .driver_name = switch (build.os.tag) {
            .windows => "direct3d12",
            .linux => "vulkan",
            .macos => "metal",
            else => null,
        },
    },
    WINDOW_NAMES,
    FENCE_NAMES,
    INDEX_BUFFER_NAMES,
    .{
        .index_buffer_def(.VERT_INDEXES, GPU_IndexTypeSize.U16),
    },
    INDIRECT_BUFFER_NAMES,
    .{},
    UPLOAD_BUFFER_NAMES,
    DOWNLOAD_BUFFER_NAMES,
    VERTEX_BUFFER_NAMES,
    VERTEX_INPUT_STRUCT_NAMES,
    .{
        .vertex_input_struct_def(.VERTEX_IN, VertexIn),
    },
    VERT_TO_FRAG_STRUCT_NAMES,
    .{
        .vertex_to_frag_struct_def(.VERT_TO_FRAG, VertexToFrag),
    },
    FRAGMENT_OUTPUT_STRUCT_NAMES,
    .{
        .shader_output_struct_def(.FRAGMENT_OUT, FragmentOut),
    },
    UNIFORM_NAMES,
    .{
        .uniform_struct_def(.WINDOW_RENDER_INFO, WindowRenderInfo),
    },
    SAMPLER_NAMES,
    .{
        SamplerDefinition{
            .name = .PIXEL_SAMPLER,
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
            .mipmap_mode = .NEAREST,
        },
    },
    STORAGE_BUFFER_NAMES,
    .{
        .storage_buffer_def(.SPRITE_VERTEX_DATA, SpriteData, .flag(.GRAPHICS_STORAGE_READ)),
    },
    TEXTURE_NAMES,
    .{
        .texture_def(.SPRITE_TEX, .R8G8B8A8_UNORM, 0, .flag(.SAMPLE)),
    },
    VERTEX_SHADER_NAMES,
    .{
        VertexShaderDefinition{
            .vertex_shader = .MAIN_VERTEX_SHADER,
            .input_type = .VERTEX_IN,
            .output_type = .VERT_TO_FRAG,
            .resources_to_link = &.{
                .uniform(.WINDOW_RENDER_INFO),
                .storage_buffer(.SPRITE_VERTEX_DATA),
            },
        },
    },
    FRAGMENT_SHADER_NAMES,
    .{
        FragmentShaderDefinition{
            .fragment_shader = .MAIN_FRAGMENT_SHADER,
            .input_type = .VERT_TO_FRAG,
            .output_type = .FRAGMENT_OUT,
            .resources_to_link = &.{
                .sampled_texture(.SPRITE_TEX, .PIXEL_SAMPLER),
            },
        },
    },
    RENDER_PIPELINE_NAMES,
    .{RenderPipelineDefinition{
        .name = .MAIN_PIPELINE,
        .vertex = .MAIN_VERTEX_SHADER,
        .fragment = .MAIN_FRAGMENT_SHADER,
        .target_info = .{
            .num_color_targets = @intCast(MAIN_PIPE_COLOR_TARGETS.len),
            .color_target_descriptions = @ptrCast(&MAIN_PIPE_COLOR_TARGETS[0]),
        },
        .rasterizer_options = .{
            .cull_mode = .NONE,
        },
        .primitive_type = .TRIANGLE_LIST,
    }},
    10000,
);
