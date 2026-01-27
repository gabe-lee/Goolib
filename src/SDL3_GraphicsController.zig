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

pub const SDL3 = Root.SDL3;
pub const GPU_Device = SDL3.GPU_Device;
pub const Window = SDL3.Window;
pub const GPU_GraphicsPipeline = SDL3.GPU_GraphicsPipeline;
pub const GPU_ComputePipeline = SDL3.GPU_ComputePipeline;
pub const GPU_ShaderCreateInfo = SDL3.GPU_ShaderCreateInfo;
pub const GPU_ShaderFormatFlags = SDL3.GPU_ShaderFormatFlags;
pub const PropertiesID = SDL3.PropertiesID;
pub const GPU_Shader = SDL3.GPU_Shader;
pub const GPU_GraphicsPipelineCreateInfo = SDL3.GPU_GraphicsPipelineCreateInfo;
pub const GPU_VertexInputState = SDL3.GPU_VertexInputState;
pub const GPU_VertexInputRate = SDL3.GPU_VertexInputRate;
pub const GPU_PrimitiveType = SDL3.GPU_PrimitiveType;
pub const GPU_RasterizerState = SDL3.GPU_RasterizerState;
pub const GPU_MultisampleState = SDL3.GPU_MultisampleState;
pub const GPU_DepthStencilState = SDL3.GPU_DepthStencilState;
pub const GPU_GraphicsPipelineTargetInfo = SDL3.GPU_GraphicsPipelineTargetInfo;
pub const GPU_CommandBuffer = SDL3.GPU_CommandBuffer;
pub const GPU_Texture = SDL3.GPU_Texture;
pub const GPU_TextureCreateInfo = SDL3.GPU_TextureCreateInfo;
pub const CreateWindowOptions = SDL3.CreateWindowOptions;
pub const WindowFlags = SDL3.WindowFlags;
pub const Vec_c_int = SDL3.Vec_c_int;
pub const GPU_TextureType = SDL3.GPU_TextureType;
pub const GPU_TextureFormat = SDL3.GPU_TextureFormat;
pub const GPU_TextureUsageFlags = SDL3.GPU_TextureUsageFlags;
pub const GPU_SampleCount = SDL3.GPU_SampleCount;
pub const GPU_Init = SDL3.GPU_CreateOptions;
pub const GPU_TransferBuffer = SDL3.GPU_TransferBuffer;
pub const GPU_TransferBufferCreateInfo = SDL3.GPU_TransferBufferCreateInfo;
pub const GPU_TransferBufferLocation = SDL3.GPU_TransferBufferLocation;
pub const GPU_TransferBufferUsage = SDL3.GPU_TransferBufferUsage;
pub const GPU_Buffer = SDL3.GPU_Buffer;
pub const GPU_BufferCreateInfo = SDL3.GPU_BufferCreateInfo;
pub const GPU_BufferLocation = SDL3.GPU_BufferLocation;
pub const GPU_BufferUsageFlags = SDL3.GPU_BufferUsageFlags;
pub const GPU_TextureSampler = SDL3.GPU_TextureSampler;
pub const GPU_TextureSamplerBinding = SDL3.GPU_TextureSamplerBinding;
pub const GPU_SamplerCreateInfo = SDL3.GPU_SamplerCreateInfo;
pub const GPU_FilterMode = SDL3.GPU_FilterMode;
pub const GPU_SamplerMipmapMode = SDL3.GPU_SamplerMipmapMode;
pub const GPU_SamplerAddressMode = SDL3.GPU_SamplerAddressMode;
pub const GPU_CompareOp = SDL3.GPU_CompareOp;

const assert_with_reason = Assert.assert_with_reason;

const INVALID_ADDR = math.maxInt(usize);

pub const TargetKind = enum(u8) {
    WINDOW,
    TEXTURE,
};

pub const TextureInitError = SDL3.Error || error{
    texture_already_initialized,
};
pub const SamplerInitError = SDL3.Error || error{
    sampler_already_initialized,
};
pub const WindowInitError = SDL3.Error || error{
    window_already_initialized,
    window_cannot_be_claimed_when_uninitialized,
};
pub const WindowGetError = error{
    window_is_not_initialized,
};
pub const VertShaderInitError = SDL3.Error || error{
    vertex_shader_already_initialized,
};
pub const FragShaderInitError = SDL3.Error || error{
    fragment_shader_already_initialized,
};
pub const RenderPipelineInitError = SDL3.Error || error{
    render_pipeline_already_initialized,
};
pub const TransferBufferInitError = SDL3.Error || error{
    transfer_buffer_already_initialized,
};
pub const GpuBufferInitError = SDL3.Error || error{
    gpu_buffer_already_initialized,
};

pub const RegisterKind = enum(u8) {
    TEXTURE, // HLSL 't0'
    SAMPLER, // HLSL 's0'
    UNORDERED, // HLSL 'u0'
    BUFFER, // HLSL 'b0'
};

pub const RegisterLocation = struct {};

pub fn GraphicsController(
    comptime WINDOW_NAMES_ENUM: type,
    comptime VERTEX_SHADER_NAMES_ENUM: type,
    comptime FRAGMENT_SHADER_NAMES_ENUM: type,
    comptime RENDER_PIPELINE_NAMES_ENUM: type,
    comptime TEXTURE_NAMES_ENUM: type,
    comptime SAMPLER_NAMES_ENUM: type,
    comptime GPU_BUFFER_NAMES_ENUM: type,
    comptime TRANSFER_BUFFER_NAMES_ENUM: type,
) type {
    assert_with_reason(Types.type_is_enum(WINDOW_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(WINDOW_NAMES_ENUM), @src(), "type `WINDOW_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(WINDOW_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(VERTEX_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_SHADER_NAMES_ENUM), @src(), "type `VERTEX_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(FRAGMENT_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_SHADER_NAMES_ENUM), @src(), "type `FRAGMENT_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(RENDER_PIPELINE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(RENDER_PIPELINE_NAMES_ENUM), @src(), "type `RENDER_PIPELINE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(RENDER_PIPELINE_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(TEXTURE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TEXTURE_NAMES_ENUM), @src(), "type `TEXTURE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TEXTURE_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(SAMPLER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(SAMPLER_NAMES_ENUM), @src(), "type `SAMPLER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(SAMPLER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(GPU_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_BUFFER_NAMES_ENUM), @src(), "type `GPU_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TRANSFER_BUFFER_NAMES_ENUM)});
    const NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
    const NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
    return struct {
        const Self = @This();

        gpu: *GPU_Device = @ptrCast(INVALID_ADDR),
        windows: [NUM_WINDOWS]*Window = @splat(@as(*Window, @ptrCast(INVALID_ADDR))),
        windows_init: [NUM_WINDOWS]bool = @splat(false),
        windows_claimed: [NUM_WINDOWS]bool = @splat(false),
        render_pipelines: [NUM_RENDER_PIPELINES]*GPU_GraphicsPipeline = @splat(@as(*GPU_GraphicsPipeline, @ptrCast(INVALID_ADDR))),
        render_pipelines_init: [NUM_RENDER_PIPELINES]bool = @splat(false),
        current_render_pipeline: RENDER_PIPE_TAG_TYPE = 0,
        textures: [NUM_TEXTURES]*GPU_Texture = @splat(@as(*GPU_GraphicsPipeline, @ptrCast(INVALID_ADDR))),
        textures_init: [NUM_TEXTURES]bool = @splat(false),
        transfer_buffers: [NUM_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(@as(*GPU_TransferBuffer, @ptrCast(INVALID_ADDR))),
        transfer_buffers_init: [NUM_TRANSFER_BUFFERS]bool = @splat(false),
        gpu_buffers: [NUM_GPU_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrCast(INVALID_ADDR))),
        gpu_buffers_init: [NUM_GPU_BUFFERS]bool = @splat(false),
        gpu_buffers_bound: [NUM_GPU_BUFFERS]bool = @splat(false),
        samplers: [NUM_SAMPLERS]*GPU_TextureSampler = @splat(@as(*GPU_TextureSampler, @ptrCast(INVALID_ADDR))),
        samplers_init: [NUM_SAMPLERS]bool = @splat(false),

        pub const NUM_WINDOWS = Types.enum_defined_field_count(WINDOW_NAMES_ENUM);
        pub const NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
        pub const RENDER_PIPE_TAG_TYPE = Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM);
        pub const NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
        pub const NUM_TRANSFER_BUFFERS = Types.enum_defined_field_count(TRANSFER_BUFFER_NAMES_ENUM);
        pub const NUM_GPU_BUFFERS = Types.enum_defined_field_count(GPU_BUFFER_NAMES_ENUM);
        pub const NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);

        pub const WindowName = WINDOW_NAMES_ENUM;
        pub const RenderPipelineName = RENDER_PIPELINE_NAMES_ENUM;
        pub const TextureName = TEXTURE_NAMES_ENUM;
        pub const TransferBufferName = TRANSFER_BUFFER_NAMES_ENUM;
        pub const GpuBufferName = GPU_BUFFER_NAMES_ENUM;
        pub const SamplerName = SAMPLER_NAMES_ENUM;

        pub const WindowInit = struct {
            name: WindowName,
            title: [:0]const u8 = "New Window",
            flags: WindowFlags = WindowFlags{},
            size: Vec_c_int = Vec_c_int.new(800, 600),
            should_init: bool = true,
            should_claim: bool = true,

            pub fn do_not_init(name: WindowName) WindowInit {
                return WindowInit{
                    .name = name,
                    .should_init = false,
                };
            }

            fn create_info(self: WindowInit) CreateWindowOptions {
                return CreateWindowOptions{
                    .flags = self.flags,
                    .size = self.size,
                    .title = self.title,
                };
            }
        };

        pub const VertexShaderInit = struct {
            name: VERTEX_SHADER_NAMES_ENUM,
            code: []const u8,
            entry_func_name: [*:0]const u8,
            format: GPU_ShaderFormatFlags,
            num_samplers: u32 = 0,
            num_storage_textures: u32 = 0,
            num_storage_buffers: u32 = 0,
            num_uniform_buffers: u32 = 0,
            extension_props: PropertiesID = .{},

            fn create_info(self: VertexShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.ptr,
                    .code_size = self.code.len,
                    .entrypoint_func = self.entry_func_name,
                    .format = self.format,
                    .num_samplers = self.num_samplers,
                    .num_storage_buffers = self.num_storage_buffers,
                    .num_storage_textures = self.num_storage_textures,
                    .num_uniform_buffers = self.num_uniform_buffersm,
                    .props = self.extension_props,
                    .stage = .VERTEX,
                };
            }
        };

        pub const FragmentShaderInit = struct {
            name: FRAGMENT_SHADER_NAMES_ENUM,
            code: []const u8,
            entry_func_name: [*:0]const u8,
            format: GPU_ShaderFormatFlags,
            num_samplers: u32 = 0,
            num_storage_textures: u32 = 0,
            num_storage_buffers: u32 = 0,
            num_uniform_buffers: u32 = 0,
            props: PropertiesID = .{},

            fn create_info(self: FragmentShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.ptr,
                    .code_size = self.code.len,
                    .entrypoint_func = self.entry_func_name,
                    .format = self.format,
                    .num_samplers = self.num_samplers,
                    .num_storage_buffers = self.num_storage_buffers,
                    .num_storage_textures = self.num_storage_textures,
                    .num_uniform_buffers = self.num_uniform_buffersm,
                    .props = self.props,
                    .stage = .FRAGMENT,
                };
            }
        };

        pub const RenderPipelineInit = struct {
            name: RenderPipelineName,
            vertex_shader: VERTEX_SHADER_NAMES_ENUM,
            fragment_shader: FRAGMENT_SHADER_NAMES_ENUM,
            vertex_input_state: GPU_VertexInputState = .{},
            primitive_type: GPU_PrimitiveType = .TRIANGLE_LIST,
            rasterizer_state: GPU_RasterizerState = .{},
            multisample_state: GPU_MultisampleState = .{},
            depth_stencil_state: GPU_DepthStencilState = .{},
            target_info: GPU_GraphicsPipelineTargetInfo = .{},
            props: PropertiesID = .{},
            should_init: bool = true,

            pub fn do_not_init(name: RENDER_PIPELINE_NAMES_ENUM) RenderPipelineInit {
                return RenderPipelineInit{
                    .name = name,
                    .vertex_shader = @enumFromInt(0),
                    .fragment_shader = @enumFromInt(0),
                    .should_init = false,
                };
            }

            pub fn create_info(self: RenderPipelineInit, vert_shaders: [NUM_VERTEX_SHADERS]*GPU_Shader, frag_shaders: [NUM_FRAGMENT_SHADERS]*GPU_Shader) GPU_GraphicsPipelineCreateInfo {
                return GPU_GraphicsPipelineCreateInfo{
                    .vertex_shader = vert_shaders[@intFromEnum(self.vertex_shader)],
                    .fragment_shader = frag_shaders[@intFromEnum(self.fragment_shader)],
                    .depth_stencil_state = self.depth_stencil_state,
                    .multisample_state = self.multisample_state,
                    .primitive_type = self.primitive_type,
                    .rasterizer_state = self.rasterizer_state,
                    .target_info = self.target_info,
                    .vertex_input_state = self.vertex_input_state,
                    .props = self.props,
                };
            }
        };

        pub const TextureInit = struct {
            name: TextureName,
            type: GPU_TextureType = ._2D,
            format: GPU_TextureFormat = .INVALID,
            usage: GPU_TextureUsageFlags = .blank(),
            width: u32 = 0,
            height: u32 = 0,
            layer_count_or_depth: u32 = 1,
            num_mip_levels: u32 = 0,
            sample_count: GPU_SampleCount = ._1,
            props: PropertiesID = .NULL,
            should_init: bool = true,

            pub fn do_not_init(name: TEXTURE_NAMES_ENUM) TextureInit {
                return TextureInit{
                    .name = name,
                    .should_init = false,
                };
            }

            pub fn create_info(self: TextureInit) GPU_TextureCreateInfo {
                return GPU_TextureCreateInfo{
                    .format = self.format,
                    .height = self.height,
                    .width = self.width,
                    .layer_count_or_depth = self.layer_count_or_depth,
                    .num_mip_levels = self.num_mip_levels,
                    .props = self.props,
                    .sample_count = self.sample_count,
                    .type = self.type,
                    .usage = self.usage,
                };
            }
        };

        pub const SamplerInit = struct {
            name: SamplerName,
            should_init: bool = true,
            min_filter: GPU_FilterMode = .LINEAR,
            mag_filter: GPU_FilterMode = .LINEAR,
            mipmap_mode: GPU_SamplerMipmapMode = .LINEAR,
            address_mode_u: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
            address_mode_v: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
            address_mode_w: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
            mip_lod_bias: f32 = 0,
            max_anisotropy: f32 = 0,
            compare_op: GPU_CompareOp = .INVALID,
            min_lod: f32 = @import("std").mem.zeroes(f32),
            max_lod: f32 = @import("std").mem.zeroes(f32),
            enable_anisotropy: bool = false,
            enable_compare: bool = false,
            props: PropertiesID = .{},

            pub fn do_not_init(name: SamplerName) SamplerInit {
                return SamplerInit{
                    .name = name,
                    .should_init = false,
                };
            }

            pub fn create_info(self: SamplerInit) GPU_SamplerCreateInfo {
                return GPU_SamplerCreateInfo{
                    .address_mode_u = self.address_mode_u,
                    .address_mode_v = self.address_mode_v,
                    .address_mode_w = self.address_mode_w,
                    .compare_op = self.compare_op,
                    .enable_anisotropy = self.enable_anisotropy,
                    .enable_compare = self.enable_compare,
                    .mag_filter = self.mag_filter,
                    .max_anisotropy = self.max_anisotropy,
                    .max_lod = self.max_lod,
                    .min_filter = self.min_filter,
                    .min_lod = self.min_lod,
                    .mip_lod_bias = self.mip_lod_bias,
                    .mipmap_mode = self.mipmap_mode,
                    .props = self.props,
                };
            }
        };

        pub const TransferBufferInit = struct {
            name: TransferBufferName,
            usage: GPU_TransferBufferUsage = .UPLOAD,
            size: u32 = 0,
            props: PropertiesID = .{},
            should_init: bool = true,

            pub fn do_not_init(name: TransferBufferName) TransferBufferInit {
                return TransferBufferInit{
                    .name = name,
                    .should_init = false,
                };
            }

            pub fn create_info(self: TransferBufferInit) GPU_TransferBufferCreateInfo {
                return GPU_TransferBufferCreateInfo{
                    .props = self.props,
                    .size = self.size,
                    .usage = self.usage,
                };
            }
        };

        pub const GpuBufferInit = struct {
            name: GpuBufferName,
            usage: GPU_BufferUsageFlags = .blank(),
            size: u32 = 0,
            props: PropertiesID = .{},
            should_init: bool = true,

            pub fn do_not_init(name: TransferBufferName) GpuBufferInit {
                return GpuBufferInit{
                    .name = name,
                    .should_init = false,
                };
            }

            pub fn create_info(self: GpuBufferInit) GPU_BufferCreateInfo {
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.size,
                    .usage = self.usage,
                };
            }
        };

        pub const RenderTarget = union(TargetKind) {
            WINDOW: WindowName,
            TEXTURE: TextureName,

            pub fn window_target(target: WindowName) RenderTarget {
                return RenderTarget{ .WINDOW = target };
            }
            pub fn texture_target(target: TextureName) RenderTarget {
                return RenderTarget{ .TEXTURE = target };
            }
        };

        pub const ControllerInit = struct {
            gpu_settings: GPU_Init,
            window_settings: [NUM_WINDOWS]WindowInit,
            vertex_shader_settings: [NUM_VERTEX_SHADERS]VertexShaderInit,
            fragment_shader_settings: [NUM_VERTEX_SHADERS]FragmentShaderInit,
            render_pipeline_settings: [NUM_RENDER_PIPELINES]RenderPipelineInit,
            texture_settings: [NUM_TEXTURES]TextureInit,
            sampler_settings: [NUM_SAMPLERS]SamplerInit,
            transfer_buffer_settings: [NUM_TRANSFER_BUFFERS]TransferBufferInit,
            gpu_buffer_settings: [NUM_GPU_BUFFERS]GpuBufferInit,
        };

        pub fn create(init: ControllerInit) !Self {
            // CONTROLLER AND GPU
            var controller: Self = .{};
            controller.gpu = try GPU_Device.create(init.gpu_settings);
            errdefer controller.gpu.destroy();
            // WINDOWS
            errdefer {
                inline for (0..NUM_WINDOWS) |w| {
                    const w_settings = init.window_settings[w];
                    const window_idx = @intFromEnum(w_settings.name);
                    if (controller.windows_claimed[window_idx]) {
                        controller.gpu.release_window(controller.windows[window_idx]);
                    }
                    if (controller.windows_init[window_idx]) {
                        controller.windows[window_idx].destroy();
                    }
                }
            }
            inline for (0..NUM_WINDOWS) |w| {
                const w_settings = init.window_settings[w];
                const window_idx = @intFromEnum(w_settings.name);
                if (controller.windows_init[window_idx]) return WindowInitError.window_already_initialized;
                if (w_settings.should_init) {
                    const create_info = w_settings.create_info();
                    controller.windows[window_idx] = try Window.create(create_info);
                    controller.windows_init[window_idx] = true;
                    if (w_settings.should_claim) {
                        try controller.gpu.claim_window(controller.windows[window_idx]);
                        controller.windows_claimed[window_idx] = true;
                    }
                }
            }
            // VERT_SHADERS
            var vert_shaders: [NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
            var vert_shaders_init: [NUM_VERTEX_SHADERS]bool = @splat(false);
            defer {
                inline for (0..NUM_VERTEX_SHADERS) |v| {
                    const v_settings = init.vertex_shader_settings[v];
                    const shader_idx = @intFromEnum(v_settings.name);
                    if (vert_shaders_init[shader_idx]) {
                        controller.gpu.release_shader(vert_shaders[shader_idx]);
                    }
                }
            }
            inline for (0..NUM_VERTEX_SHADERS) |v| {
                const v_settings = init.vertex_shader_settings[v];
                const shader_idx = @intFromEnum(v_settings.name);
                if (vert_shaders_init[shader_idx]) return VertShaderInitError.vertex_shader_already_initialized;
                var create_info = v_settings.create_info();
                vert_shaders[shader_idx] = try controller.gpu.create_shader(&create_info);
                vert_shaders_init[shader_idx] = true;
            }
            // FRAG SHADERS
            var frag_shaders: [NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
            var frag_shaders_init: [NUM_VERTEX_SHADERS]bool = @splat(false);
            defer {
                inline for (0..NUM_FRAGMENT_SHADERS) |f| {
                    const f_settings = init.fragment_shader_settings[f];
                    const shader_idx = @intFromEnum(f_settings.name);
                    if (frag_shaders_init[shader_idx]) {
                        controller.gpu.release_shader(frag_shaders[shader_idx]);
                    }
                }
            }
            inline for (0..NUM_FRAGMENT_SHADERS) |f| {
                const f_settings = init.fragment_shader_settings[f];
                const shader_idx = @intFromEnum(f_settings.name);
                if (frag_shaders_init[shader_idx]) return FragShaderInitError.fragment_shader_already_initialized;
                var create_info = f_settings.create_info();
                frag_shaders[shader_idx] = try controller.gpu.create_shader(&create_info);
                frag_shaders_init[shader_idx] = true;
            }
            // RENDER PIPELINES
            errdefer {
                inline for (0..NUM_RENDER_PIPELINES) |r| {
                    const r_settings = init.render_pipeline_settings[r];
                    const pipe_idx = @intFromEnum(r_settings.name);
                    if (controller.render_pipelines_init[pipe_idx]) {
                        controller.gpu.release_graphics_pipeline(controller.render_pipelines[pipe_idx]);
                    }
                }
            }
            inline for (0..NUM_RENDER_PIPELINES) |r| {
                const r_settings = init.render_pipeline_settings[r];
                const pipe_idx = @intFromEnum(r_settings.name);
                if (controller.render_pipelines_init[pipe_idx]) return RenderPipelineInitError.render_pipeline_already_initialized;
                if (r_settings.should_init) {
                    var create_info = r_settings.create_info(vert_shaders, frag_shaders);
                    controller.render_pipelines[pipe_idx] = try controller.gpu.create_graphics_pipeline(&create_info);
                    controller.render_pipelines_init[pipe_idx] = true;
                }
            }
            // TEXTURES
            errdefer {
                inline for (0..NUM_TEXTURES) |t| {
                    const t_settings = init.texture_settings[t];
                    const tex_idx = @intFromEnum(t_settings.name);
                    if (controller.textures_init[tex_idx]) {
                        controller.gpu.release_texture(controller.textures[tex_idx]);
                    }
                }
            }
            inline for (0..NUM_TEXTURES) |t| {
                const t_settings = init.texture_settings[t];
                const tex_idx = @intFromEnum(t_settings.name);
                if (controller.textures_init[tex_idx]) return TextureInitError.texture_already_initialized;
                if (t_settings.should_init) {
                    var create_info = t_settings.create_info();
                    controller.textures[tex_idx] = try controller.gpu.create_texture(&create_info);
                    controller.textures_init[tex_idx] = true;
                }
            }
            // SAMPLERS
            errdefer {
                inline for (0..NUM_SAMPLERS) |s| {
                    const s_settings = init.sampler_settings[s];
                    const samp_idx = @intFromEnum(s_settings.name);
                    if (controller.samplers_init[samp_idx]) {
                        controller.gpu.release_texture_sampler(controller.samplers[samp_idx]);
                    }
                }
            }
            inline for (0..NUM_SAMPLERS) |s| {
                const s_settings = init.texture_settings[s];
                const samp_idx = @intFromEnum(s_settings.name);
                if (controller.samplers_init[samp_idx]) return SamplerInitError.sampler_already_initialized;
                if (s_settings.should_init) {
                    var create_info = s_settings.create_info();
                    controller.samplers[samp_idx] = try controller.gpu.create_texture_sampler(&create_info);
                    controller.samplers_init[samp_idx] = true;
                }
            }
            // TRANSFER BUFFERS
            errdefer {
                inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
                    const tb_settings = init.transfer_buffer_settings[tb];
                    const trans_buf_idx = @intFromEnum(tb_settings.name);
                    if (controller.transfer_buffers_init[trans_buf_idx]) {
                        controller.gpu.release_transfer_buffer(controller.transfer_buffers[trans_buf_idx]);
                    }
                }
            }
            inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
                const tb_settings = init.transfer_buffer_settings[tb];
                const trans_buf_idx = @intFromEnum(tb_settings.name);
                if (controller.transfer_buffers_init[trans_buf_idx]) return TransferBufferInitError.transfer_buffer_already_initialized;
                if (tb_settings.should_init) {
                    var create_info = tb_settings.create_info();
                    controller.transfer_buffers[trans_buf_idx] = try controller.gpu.create_transfer_buffer(&create_info);
                    controller.transfer_buffers_init[trans_buf_idx] = true;
                }
            }
            // GPU BUFFERS
            errdefer {
                inline for (0..NUM_GPU_BUFFERS) |gb| {
                    const gb_settings = init.gpu_buffer_settings[gb];
                    const gpu_buf_idx = @intFromEnum(gb_settings.name);
                    if (controller.gpu_buffers_init[gpu_buf_idx]) {
                        controller.gpu.release_buffer(controller.gpu_buffers[gpu_buf_idx]);
                    }
                }
            }
            inline for (0..NUM_GPU_BUFFERS) |gb| {
                const gb_settings = init.gpu_buffer_settings[gb];
                const gpu_buf_idx = @intFromEnum(gb_settings.name);
                if (controller.gpu_buffers_init[gpu_buf_idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
                if (gb_settings.should_init) {
                    var create_info = gb_settings.create_info();
                    controller.gpu_buffers[gpu_buf_idx] = try controller.gpu.create_buffer(&create_info);
                    controller.gpu_buffers_init[gpu_buf_idx] = true;
                }
            }
            return controller;
        }

        pub fn destroy(self: *Self) void {
            inline for (0..NUM_GPU_BUFFERS) |gb| {
                if (self.gpu_buffers_init[gb]) {
                    self.gpu.release_buffer(self.gpu_buffers[gb]);
                }
            }
            inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
                if (self.transfer_buffers_init[tb]) {
                    self.gpu.release_transfer_buffer(self.transfer_buffers[tb]);
                }
            }
            inline for (0..NUM_SAMPLERS) |s| {
                if (self.samplers_init[s]) {
                    self.gpu.release_texture_sampler(self.samplers[s]);
                }
            }
            inline for (0..NUM_TEXTURES) |t| {
                if (self.textures_init[t]) {
                    self.gpu.release_texture(self.textures[t]);
                }
            }
            inline for (0..NUM_RENDER_PIPELINES) |r| {
                if (self.render_pipelines_init[r]) {
                    self.gpu.release_graphics_pipeline(self.render_pipelines[r]);
                }
            }
            inline for (0..NUM_WINDOWS) |w| {
                if (self.windows_claimed[w]) {
                    self.gpu.release_window(self.controller.windows[w]);
                }
                if (self.windows_init[w]) {
                    self.windows[w].destroy();
                }
            }
            self.gpu.destroy();
            self.* = undefined;
        }

        pub fn create_window(self: *Self, window_name: WindowName, init: CreateWindowOptions) WindowInitError!void {
            const idx = @intFromEnum(window_name);
            if (self.windows_init[idx]) return WindowInitError.window_already_initialized;
            self.windows[idx] = try Window.create(init);
            self.windows_init[idx] = true;
        }
        pub fn destroy_window(self: *Self, window_name: WindowName) void {
            const idx = @intFromEnum(window_name);
            if (self.windows_claimed[idx]) {
                self.gpu.release_window(self.windows[idx]);
                self.windows_claimed[idx] = false;
            }
            if (self.windows_init[idx]) {
                self.windows[idx].destroy();
                self.windows_init[idx] = false;
            }
        }
        pub fn get_window(self: *Self, window_name: WindowName) WindowGetError!*Window {
            const idx = @intFromEnum(window_name);
            if (!self.windows_init[idx]) return WindowGetError.window_is_not_initialized;
            return self.windows[idx];
        }
        pub fn claim_window(self: *Self, window_name: WindowName) WindowInitError!void {
            const idx = @intFromEnum(window_name);
            if (!self.windows_init[idx]) return WindowInitError.window_cannot_be_claimed_when_uninitialized;
            try self.gpu.claim_window(self.windows[idx]);
            self.windows_claimed[idx] = true;
        }
        pub fn release_window(self: *Self, window_name: WindowName) void {
            const idx = @intFromEnum(window_name);
            if (!self.windows_claimed[idx]) return;
            self.gpu.release_window(self.windows[idx]);
            self.windows_claimed[idx] = false;
        }
        pub fn create_and_claim_window(self: *Self, window_name: WindowName, init: CreateWindowOptions) WindowInitError!void {
            try self.create_window(window_name, init);
            try self.claim_window(window_name);
        }
        pub fn release_and_destroy_window(self: *Self, window_name: WindowName) void {
            self.release_window(window_name);
            self.destroy_window(window_name);
        }

        pub fn create_render_pipeline(self: *Self, pipeline_name: RenderPipelineName, vertex_shader_info: *GPU_ShaderCreateInfo, fragment_shader_info: *GPU_ShaderCreateInfo, pipeline_info: *GPU_GraphicsPipelineCreateInfo) RenderPipelineInitError!void {
            const idx = @intFromEnum(pipeline_name);
            if (self.render_pipelines_init[idx]) return RenderPipelineInitError.render_pipeline_already_initialized;
            const vert_shader = try self.gpu.create_shader(vertex_shader_info);
            defer self.gpu.release_shader(vert_shader);
            const frag_shader = try self.gpu.create_shader(fragment_shader_info);
            defer self.gpu.release_shader(frag_shader);
            self.render_pipelines[idx] = try self.gpu.create_graphics_pipeline(pipeline_info);
            self.render_pipelines_init[idx] = true;
        }
        pub fn destroy_render_pipeline(self: *Self, pipeline_name: RenderPipelineName) void {
            const idx = @intFromEnum(pipeline_name);
            if (!self.render_pipelines_init[idx]) return;
            self.gpu.release_graphics_pipeline(self.render_pipelines[idx]);
            self.render_pipelines_init[idx] = false;
        }

        pub fn create_texture_sampler(self: *Self, sampler_name: SamplerName, sampler_info: *GPU_SamplerCreateInfo) SamplerInitError!void {
            const idx = @intFromEnum(sampler_name);
            if (self.samplers_init[idx]) return SamplerInitError.sampler_already_initialized;
            self.samplers[idx] = try self.gpu.create_texture_sampler(sampler_info);
            self.samplers_init[idx] = true;
        }
        pub fn destroy_texture_sampler(self: *Self, sampler_name: SamplerName) void {
            const idx = @intFromEnum(sampler_name);
            if (!self.samplers_init[idx]) return;
            self.gpu.release_texture_sampler(self.samplers[idx]);
            self.samplers_init[idx] = false;
        }

        pub fn create_texture(self: *Self, texture_name: TextureName, texture_info: *GPU_TextureCreateInfo) TextureInitError!void {
            const idx = @intFromEnum(texture_name);
            if (self.textures_init[idx]) return TextureInitError.texture_already_initialized;
            self.textures[idx] = try self.gpu.create_texture(texture_info);
            self.textures_init[idx] = true;
        }
        pub fn destroy_texture(self: *Self, texture_name: TextureName) void {
            const idx = @intFromEnum(texture_name);
            if (!self.textures_init[idx]) return;
            self.gpu.release_texture(self.textures[idx]);
            self.textures_init[idx] = false;
        }

        pub fn create_transfer_buffer(self: *Self, transfer_buffer_name: TransferBufferName, buffer_info: *GPU_TransferBufferCreateInfo) TransferBufferInitError!void {
            const idx = @intFromEnum(transfer_buffer_name);
            if (self.transfer_buffers_init[idx]) return TransferBufferInitError.transfer_buffer_already_initialized;
            self.transfer_buffers[idx] = try self.gpu.create_transfer_buffer(buffer_info);
            self.transfer_buffers_init[idx] = true;
        }
        pub fn destroy_transfer_buffer(self: *Self, transfer_buffer_name: TransferBufferName) void {
            const idx = @intFromEnum(transfer_buffer_name);
            if (!self.transfer_buffers_init[idx]) return;
            self.gpu.release_transfer_buffer(self.transfer_buffers[idx]);
            self.transfer_buffers_init[idx] = false;
        }

        pub fn create_gpu_buffer(self: *Self, gpu_buffer_name: GpuBufferName, buffer_info: *GPU_BufferCreateInfo) GpuBufferInitError!void {
            const idx = @intFromEnum(gpu_buffer_name);
            if (self.gpu_buffers_init[idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
            self.gpu_buffers[idx] = try self.gpu.create_buffer(buffer_info);
            self.gpu_buffers_init[idx] = true;
        }
        pub fn destroy_gpu_buffer(self: *Self, gpu_buffer_name: GpuBufferName) void {
            const idx = @intFromEnum(gpu_buffer_name);
            if (!self.gpu_buffers_init[idx]) return;
            self.gpu.release_buffer(self.gpu_buffers[idx]);
            self.gpu_buffers_init[idx] = false;
        }

        pub fn begin_commands(self: *Self) !CommandBuffer {
            return CommandBuffer{
                .controller = self,
                .sdl = try self.gpu.acquire_command_buffer(),
            };
        }

        pub const CommandBuffer = struct {
            controller: *Self,
            sdl: *GPU_CommandBuffer,

            pub fn insert_debug_label(self: CommandBuffer, label: [*:0]const u8) void {
                self.sdl.insert_debug_label(label);
            }

            pub fn push_debug_group(self: CommandBuffer, name: [*:0]const u8) void {
                self.sdl.push_debug_group(name);
            }

            pub fn pop_debug_group(self: CommandBuffer) void {
                self.sdl.pop_debug_group();
            }
        };
    };
}
