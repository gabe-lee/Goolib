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
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Flags = Root.Flags.Flags;
const Utils = Root.Utils;
const Assert = Root.Assert;
const Sort = Root.Sort.InsertionSort;
const Common = Root.CommonTypes;
const Vec4 = Root.Vec4.define_vec4_type;
const Vec3 = Root.Vec3.define_vec3_type;
const Vec2 = Root.Vec2.define_vec2_type;
const GooListSlice = Root.GooListSlice;
const List = GooListSlice.ListAllocated;
const DummyAlloc = Root.DummyAllocator;

const ValidateMode = Common.WarningMode;
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
pub const GPU_VertexAttribute = SDL3.GPU_VertexAttribute;
pub const GPU_IndexTypeSize = SDL3.GPU_IndexTypeSize;
pub const GPU_Fence = SDL3.GPU_Fence;
pub const GPU_BufferBinding = SDL3.GPU_BufferBinding;
pub const GPU_IndirectDrawCommand = SDL3.GPU_IndirectDrawCommand;
pub const GPU_IndexedIndirectDrawCommand = SDL3.GPU_IndexedIndirectDrawCommand;
pub const GPU_BlitInfo = SDL3.GPU_BlitInfo;
pub const GPU_BlitRegion = SDL3.GPU_BlitRegion;
pub const GPU_TextureRegion = SDL3.GPU_TextureRegion;
pub const GPU_TextureTransferInfo = SDL3.GPU_TextureTransferInfo;
pub const GPU_BufferRegion = SDL3.GPU_BufferRegion;
pub const GPU_TextureLocation = SDL3.GPU_TextureLocation;
pub const GPU_CreateOptions = SDL3.GPU_CreateOptions;
pub const GPU_SwapchainTexture = SDL3.GPU_SwapchainTexture;
pub const GPU_CopyPass = SDL3.GPU_CopyPass;
pub const GPU_ColorTargetInfo = SDL3.GPU_ColorTargetInfo;

const ShaderUtils = SDL3.ShaderUtils;
pub const UniformOrStorageStruct = ShaderUtils.UniformOrStorageStruct;
pub const AnyUniformOrStorageStruct = ShaderUtils.AnyUniformOrStorageStruct;
pub const VertexShaderInputStruct = ShaderUtils.VertexShaderInputStruct;
pub const AnyVertexShaderInputStruct = ShaderUtils.AnyVertexShaderInputStruct;
pub const VertexToFragmentStruct = ShaderUtils.VertexToFragmentStruct;
pub const AnyVertexToFragmentStruct = ShaderUtils.AnyVertexToFragmentStruct;
pub const FragmentShaderOutputStruct = ShaderUtils.FragmentShaderOutputStruct;
pub const AnyFragmentShaderOutputStruct = ShaderUtils.AnyFragmentShaderOutputStruct;
pub const GPUType = ShaderUtils.GPUType;
const ErrorBehavior = Common.ErrorBehavior;

const DEBUG = std.debug.print;
const DEBUG_VAL = Root.Utils.DebugPrint.debug_val;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const update_max = Utils.update_max;
const update_min = Utils.update_min;
const num_cast = Cast.num_cast;
const bytes_cast = Cast.bytes_cast;
const element_type = Cast.element_type;

const INVALID_ADDR = math.maxInt(usize);
const TEXTURE_TRANSFER_MIN_ALIGN = 8;

pub const TargetKind = enum(u8) {
    WINDOW,
    TEXTURE,
};

pub const FenceKind = enum(u8) {
    NAMED,
    DIRECT,
};

pub const VertexDrawMode = enum(u8) {
    VERTEX,
    INDEX,

    pub fn indirect_command_size(self: VertexDrawMode) u32 {
        switch (self) {
            .VERTEX => return @sizeOf(GPU_IndirectDrawCommand),
            .INDEX => return @sizeOf(GPU_IndexedIndirectDrawCommand),
        }
    }
};

pub const CopyKind = enum(u8) {
    BUFFER,
    TEXTURE,
};

pub const GPUBufferKind = enum(u8) {
    STORAGE,
    VERTEX,
    INDEX,
    INDIRECT,
};

pub const GPUAssetKind = enum(u8) {
    STORAGE_BUF,
    VERTEX_BUF,
    INDEX_BUF,
    INDIRECT_BUF,
    TEXTURE,
};

pub const TransferBufferKind = enum(u8) {
    UPLOAD,
    DOWNLOAD,
};

pub const CopyMemberKind = enum(u8) {
    TRANSFER_BUF,
    GPU_ASSET,
};

pub const UploadAndCopyCommandKind = enum(u8) {
    APPLICATION_TO_UPLOAD_BUF,
    UPLOAD_BUF_TO_GPU_TEXTURE,
    UPLOAD_BUF_TO_GPU_BUFFER,
};

pub const DownloadAndCopyCommandKind = enum(u8) {
    DOWNLOAD_BUF_TO_APPLICATION,
    GPU_TEXTURE_TO_DOWNLOAD_BUF,
    GPU_BUFFER_TO_DOWNLOAD_BUF,
};

pub const TransferAndCopyCommandKind = enum(u8) {
    APPLICATION_TO_UPLOAD_BUF,
    UPLOAD_BUF_TO_GPU_TEXTURE,
    UPLOAD_BUF_TO_GPU_BUFFER,
    DOWNLOAD_BUF_TO_APPLICATION,
    GPU_TEXTURE_TO_DOWNLOAD_BUF,
    GPU_BUFFER_TO_DOWNLOAD_BUF,
};

pub const BufferGrowMode = enum(u8) {
    NO_GROW,
    GROW_EXACT,
    GROW_BY_ONE_AND_A_QUARTER,
    GROW_BY_ONE_AND_A_HALF,
    GROW_BY_DOUBLE,
};

pub const DefaultCustomKind = enum(u8) {
    DEFAULT,
    CUSTOM,
};

pub const IndirectDrawMode = enum(u8) {
    NORMAL_INDIRECT,
    INDEXED_INDIRECT,

    pub fn elem_type(comptime self: IndirectDrawMode) type {
        return switch (self) {
            .NORMAL_INDIRECT => SDL3.GPU_IndirectDrawCommand,
            .INDEXED_INDIRECT => SDL3.GPU_IndexedIndirectDrawCommand,
        };
    }
    pub fn slice_type(comptime self: IndirectDrawMode) type {
        return switch (self) {
            .NORMAL_INDIRECT => []SDL3.GPU_IndirectDrawCommand,
            .INDEXED_INDIRECT => []SDL3.GPU_IndexedIndirectDrawCommand,
        };
    }
    pub fn const_slice_type(comptime self: IndirectDrawMode) type {
        return switch (self) {
            .NORMAL_INDIRECT => []const SDL3.GPU_IndirectDrawCommand,
            .INDEXED_INDIRECT => []const SDL3.GPU_IndexedIndirectDrawCommand,
        };
    }
};

pub const LifeCycle = enum(u8) {
    UNINITIALIZED,
    READY_FOR_NEXT_COMMAND_CYCLE,
    UPLOAD_TO_GPU,
    WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY,
    RENDER_PASS,
    COPY_PASS,
    COMPUTE_PASS,
    DOWNLOAD_FROM_GPU,
    WAITING_FOR_GPU_COMPLETION_FENCE,

    pub fn assert(self: LifeCycle, comptime need: LifeCycle, comptime src_loc: ?std.builtin.SourceLocation) void {
        assert_with_reason(self == need, src_loc, "need stage {s}, but was in stage {s}", .{ @tagName(need), @tagName(self) });
    }
    pub fn assert_any(self: LifeCycle, comptime needs: []const LifeCycle, comptime src_loc: ?std.builtin.SourceLocation) void {
        inline for (needs) |need| {
            if (need == self) return;
        }
        assert_unreachable(src_loc, "needed one of stages {any}, but was in stage {s}", .{ needs, @tagName(self) });
    }
};

pub const SamplerInitSettings = union(DefaultCustomKind) {
    DEFAULT: void,
    CUSTOM: GPU_SamplerCreateInfo,

    pub fn default_sampler_settings() SamplerInitSettings {
        return SamplerInitSettings{ .DEFAULT = void{} };
    }
    pub fn custom_sampler_settings(settings: GPU_SamplerCreateInfo) SamplerInitSettings {
        return SamplerInitSettings{ .CUSTOM = settings };
    }
};

pub const UploadGrowSettings = struct {
    grow_vertex_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
    grow_index_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
    grow_indirect_draw_call_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
    grow_storage_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
    grow_transfer_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
};

pub const DownloadGrowSettings = struct {
    grow_transfer_buffers: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
};

pub fn PossibleErrorReturn(comptime MODE: ErrorBehavior, comptime T: type) type {
    return switch (MODE) {
        .RETURN_ERRORS => anyerror!T,
        .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => T,
    };
}

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

pub const StorageLayer = enum(u32) {
    VERTEX = 0,
    FRAGMENT = 2,
};

pub const UniformLayer = enum(u32) {
    VERTEX = 1,
    FRAGMENT = 3,
};

pub const AllowedResource = struct {
    register: u32 = 0,
    allowed: bool = false,
};
pub const AllowedResourceGpuCpu = struct {
    gpu_register: u32 = 0,
    cpu_register: u32 = 0,
    allowed: bool = false,

    pub fn registers(self: AllowedResourceGpuCpu) RegisterGpuCpu {
        return RegisterGpuCpu{
            .gpu = self.gpu_register,
            .cpu = self.cpu_register,
        };
    }
};
pub const RegisterGpuCpu = struct {
    gpu: u32 = 0,
    cpu: u32 = 0,
};

pub fn ShaderAllowedUniform(comptime UNIFORM_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();
        uniform: UNIFORM_NAMES_ENUM,
        register: u32,

        pub fn equals_register(a: Self, b: Self) bool {
            return a.register == b.register;
        }
        pub fn register_greater(a: Self, b: Self) bool {
            return a.register > b.register;
        }
    };
}
pub fn ShaderAllowedStorageBuffer(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        buffer: STORAGE_BUFFER_NAMES_ENUM,
        cpu_register: u32,
        gpu_register: u32,

        pub fn equals_cpu_register(a: Self, b: Self) bool {
            return a.cpu_register == b.cpu_register;
        }
        pub fn cpu_register_greater(a: Self, b: Self) bool {
            return a.cpu_register > b.cpu_register;
        }
    };
}
pub fn ShaderAllowedStorageTexture(comptime STORAGE_TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: STORAGE_TEXTURE_NAMES_ENUM,
        cpu_register: u32,
        gpu_register: u32,

        pub fn equals_cpu_register(a: Self, b: Self) bool {
            return a.cpu_register == b.cpu_register;
        }
        pub fn cpu_register_greater(a: Self, b: Self) bool {
            return a.cpu_register > b.cpu_register;
        }
    };
}

pub fn ShaderAllowedSamplePair(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        sampler: SAMPLER_NAMES_ENUM = undefined,
        texture: TEXTURE_NAMES_ENUM = undefined,
        cpu_register: u32 = 0,
        gpu_register: u32 = 0,

        pub fn equals_pair(a: Self, b: Self) bool {
            return a.sampler == b.sampler and a.texture == b.texture;
        }
        pub fn equals_cpu_register(a: Self, b: Self) bool {
            return a.cpu_register == b.cpu_register;
        }
        pub fn cpu_register_greater(a: Self, b: Self) bool {
            return a.cpu_register > b.cpu_register;
        }
    };
}

pub const ShaderCode = struct {
    format: SDL3.GPU_ShaderFormatFlags.Flag = .INVALID,
    code: []const u8,
    entry_func_name: [*:0]const u8,

    pub fn spirv_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .SPIRV,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn dxbc_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .DXBC,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn dxil_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .DXIL,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn msl_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .MSL,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn metallib_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .METALLIB,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn private_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .format = .PRIVATE,
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
};

pub const StorageBufferMode = enum(u8) {
    RENDER_READ_ONLY,
    COMPUTE_READ_WRITE,
};

pub const RenderLinkageRegisterKind = enum(u8) {
    SAMPLED_TEXTURE = 0,
    STORAGE_TEXTURE = 1,
    STORAGE_BUFFER = 2,
    UNIFORM_BUFFER = 3,
    // VERTEX_BUFFER = 4,

    pub fn storage_register_kind(self: RenderLinkageRegisterKind) StorageRegisterKind {
        return @enumFromInt(@intFromEnum(self));
    }
};

pub const StorageRegisterKind = enum(u32) {
    SAMPLED_PAIR = 0,
    STORAGE_TEXTURE = 1,
    STORAGE_BUFFER = 2,
};

pub fn CombinedTextureSamplerTag(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return Types.Combined2EnumInt(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
}

pub fn TextureNameSamplerNamePair(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        tex_name: TEXTURE_NAMES_ENUM,
        samp_name: SAMPLER_NAMES_ENUM,
    };
}

pub fn ShaderResource(comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return union(RenderLinkageRegisterKind) {
        SAMPLED_TEXTURE: TextureNameSamplerNamePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
        STORAGE_TEXTURE: TEXTURE_NAMES_ENUM,
        STORAGE_BUFFER: STORAGE_BUFFER_NAMES_ENUM,
        UNIFORM_BUFFER: UNIFORM_NAMES_ENUM,

        pub fn sampled_texture(comptime tex_name: TEXTURE_NAMES_ENUM, comptime samp_name: SAMPLER_NAMES_ENUM) @This() {
            return @This(){ .SAMPLED_TEXTURE = .{
                .tex_name = tex_name,
                .samp_name = samp_name,
            } };
        }
        pub fn storage_texture(comptime tex_name: TEXTURE_NAMES_ENUM) @This() {
            return @This(){ .STORAGE_TEXTURE = tex_name };
        }
        pub fn storage_buffer(comptime buf_name: STORAGE_BUFFER_NAMES_ENUM) @This() {
            return @This(){ .STORAGE_BUFFER = buf_name };
        }
        pub fn uniform(comptime uni_name: UNIFORM_NAMES_ENUM) @This() {
            return @This(){ .UNIFORM_BUFFER = uni_name };
        }
    };
}

pub fn VertexShaderDefinition(
    comptime VERTEX_SHADER_NAMES_ENUM: type,
    comptime VERTEX_INPUT_STRUCT_NAMES_ENUM: type,
    comptime VERTEX_TO_FRAG_STRUCT_NAMES_ENUM: type,
    comptime UNIFORM_NAMES_ENUM: type,
    comptime STORAGE_BUFFER_NAMES_ENUM: type,
    comptime TEXTURE_NAMES_ENUM: type,
    comptime SAMPLER_NAMES_ENUM: type,
) type {
    return struct {
        vertex_shader: VERTEX_SHADER_NAMES_ENUM,
        /// The input struct type name for the vertex shader
        input_type: VERTEX_INPUT_STRUCT_NAMES_ENUM,
        /// The vertex-to-fragment struct type name for the vertex shader
        ///
        /// This will be validated to match the input on any fragment shader this vertex shader is paired with
        output_type: VERTEX_TO_FRAG_STRUCT_NAMES_ENUM,
        resources_to_link: []const ShaderResource(UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
    };
}

pub fn FragmentShaderDefinition(
    comptime FRAGMENT_SHADER_NAMES_ENUM: type,
    comptime VERTEX_TO_FRAG_STRUCT_NAMES_ENUM: type,
    comptime FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM: type,
    comptime UNIFORM_NAMES_ENUM: type,
    comptime STORAGE_BUFFER_NAMES_ENUM: type,
    comptime TEXTURE_NAMES_ENUM: type,
    comptime SAMPLER_NAMES_ENUM: type,
) type {
    return struct {
        fragment_shader: FRAGMENT_SHADER_NAMES_ENUM,
        /// The input struct type name for the shader
        input_type: VERTEX_TO_FRAG_STRUCT_NAMES_ENUM,
        /// The fragment output struct/layout for the fragment shader
        output_type: FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM,
        resources_to_link: []const ShaderResource(UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
    };
}

pub const ShaderStage = enum(u8) {
    VERTEX = 0,
    FRAGMENT = 1,

    pub fn idx(comptime self: ShaderStage) u8 {
        return @intFromEnum(self);
    }
};

pub fn RenderPipelineDefinition(
    comptime PIPLEINE_NAMES: type,
    comptime VERTEX_SHADER_NAMES: type,
    comptime FRAGMENT_SHADER_NAMES: type,
) type {
    return struct {
        name: PIPLEINE_NAMES,
        vertex: VERTEX_SHADER_NAMES,
        fragment: FRAGMENT_SHADER_NAMES,
        primitive_type: SDL3.GPU_PrimitiveType = .TRIANGLE_LIST,
        rasterizer_options: SDL3.GPU_RasterizerState = .{},
        multisample_options: SDL3.GPU_MultisampleState = .{},
        depth_stencil_options: SDL3.GPU_DepthStencilState = .{},
        target_info: SDL3.GPU_GraphicsPipelineTargetInfo = .{},
    };
}

pub const NumLocationsAndDepthTarget = struct {
    /// for `.VERTEX_IN` and `.VERTEX_OUT_FRAG_IN` shader structs, this is the number of
    /// user paramater locations
    ///
    /// for `.FRAGMENT_OUT` shader structs, this is the number of color targets
    num_locations: u32 = 0,
    /// `true` is only valid for `.FRAGMENT_OUT` shader structs
    has_depth_target: bool = false,
};

pub const UniformOffsetAndSize = struct {
    /// The field offset within the `` type passed to the graphics controller where
    /// this uniform struct starts
    offset: u32 = 0,
    /// The size of this uniform struct
    size: u32 = 0,
};

pub fn VertexInputStructDefinition(comptime VERTEX_INPUT_STRUCT_NAMES_ENUM: type) type {
    return struct {
        name: VERTEX_INPUT_STRUCT_NAMES_ENUM,
        type: type,

        pub fn vertex_input_struct_def(comptime name: VERTEX_INPUT_STRUCT_NAMES_ENUM, comptime t: type) @This() {
            ShaderUtils.assert_type_is_vertex_shader_input_struct(t, @src());
            return @This(){
                .name = name,
                .type = t,
            };
        }
    };
}

pub fn VertexToFragmentStructDefinition(comptime VERTEX_TO_FRAG_STRUCT_NAMES_ENUM: type) type {
    return struct {
        name: VERTEX_TO_FRAG_STRUCT_NAMES_ENUM,
        type: type,

        pub fn vertex_to_frag_struct_def(comptime name: VERTEX_TO_FRAG_STRUCT_NAMES_ENUM, comptime t: type) @This() {
            ShaderUtils.assert_type_is_vertex_to_frag_struct(t, @src());
            return @This(){
                .name = name,
                .type = t,
            };
        }
    };
}

pub fn FragmentOutputStructDefinition(comptime FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM: type) type {
    return struct {
        name: FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM,
        type: type,

        pub fn shader_output_struct_def(comptime name: FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM, comptime t: type) @This() {
            ShaderUtils.assert_type_is_fragment_shader_output_struct(t, @src());
            return @This(){
                .name = name,
                .type = t,
            };
        }
    };
}

pub fn UniformStructDefinition(comptime UNIFORM_STRUCT_NAMES_ENUM: type) type {
    return struct {
        name: UNIFORM_STRUCT_NAMES_ENUM,
        type: type,

        pub fn uniform_struct_def(comptime name: UNIFORM_STRUCT_NAMES_ENUM, comptime t: type) @This() {
            ShaderUtils.assert_type_is_uniform_or_storage_struct(t, @src());
            return @This(){
                .name = name,
                .type = t,
            };
        }
    };
}

pub fn TextureDefinition(comptime TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();
        name: TEXTURE_NAMES_ENUM,
        shape: SDL3.GPU_TextureType = ._2D,
        pixel_format: GPU_TextureFormat = .R8G8B8A8_UNORM_SRGB,
        mipmap_levels: u32 = 1,
        sample_count: SDL3.GPU_SampleCount = ._1,
        usage: GPU_TextureUsageFlags = .flag(.SAMPLE),

        pub fn texture_def_advanced(name: TEXTURE_NAMES_ENUM, shape: GPU_TextureType, format: GPU_TextureFormat, mipmap_levels: u32, sample_count: SDL3.GPU_SampleCount, usage: GPU_TextureUsageFlags) Self {
            return Self{
                .name = name,
                .pixel_format = format,
                .mipmap_levels = mipmap_levels,
                .sample_count = sample_count,
                .shape = shape,
                .usage = usage,
            };
        }
        pub fn texture_def(name: TEXTURE_NAMES_ENUM, format: GPU_TextureFormat, mipmap_levels: u32, usage: GPU_TextureUsageFlags) Self {
            return Self{
                .name = name,
                .pixel_format = format,
                .mipmap_levels = mipmap_levels,
                .sample_count = ._1,
                .shape = ._2D,
                .usage = usage,
            };
        }
    };
}

const TextureDef = struct {
    shape: SDL3.GPU_TextureType = ._2D,
    pixel_format: GPU_TextureFormat = .R8G8B8A8_UNORM_SRGB,
    mipmap_levels: u32 = 1,
    sample_count: SDL3.GPU_SampleCount = ._1,
    usage: GPU_TextureUsageFlags = .flag(.SAMPLE),
};

pub fn SamplerDefinition(comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();
        name: SAMPLER_NAMES_ENUM,
        min_filter: GPU_FilterMode = .LINEAR,
        mag_filter: GPU_FilterMode = .LINEAR,
        mipmap_mode: GPU_SamplerMipmapMode = .LINEAR,
        address_mode_x: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
        address_mode_y: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
        address_mode_z: GPU_SamplerAddressMode = .CLAMP_TO_EDGE,
        mip_lod_bias: f32 = 0,
        max_anisotropy: f32 = 0,
        compare_op: GPU_CompareOp = .INVALID,
        min_lod: f32 = 0,
        max_lod: f32 = 0,
        enable_anisotropy: bool = false,
        enable_compare: bool = false,

        pub fn sdl_info(self: Self, props: PropertiesID) GPU_SamplerCreateInfo {
            return GPU_SamplerCreateInfo{
                .mag_filter = self.mag_filter,
                .min_filter = self.min_filter,
                .address_mode_x = self.address_mode_x,
                .address_mode_y = self.address_mode_y,
                .address_mode_z = self.address_mode_z,
                .compare_op = self.compare_op,
                .enable_anisotropy = self.enable_anisotropy,
                .enable_compare = self.enable_compare,
                .max_anisotropy = self.max_anisotropy,
                .max_lod = self.max_lod,
                .min_lod = self.min_lod,
                .mip_lod_bias = self.mip_lod_bias,
                .mipmap_mode = self.mipmap_mode,
                .props = props,
            };
        }
    };
}

pub fn StorageBufferDefinition(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        name: STORAGE_BUFFER_NAMES_ENUM,
        elem_type: type,
        usage: GPU_BufferUsageFlags,

        pub fn storage_buffer_def(comptime name: STORAGE_BUFFER_NAMES_ENUM, comptime elem_type: type, comptime usage: GPU_BufferUsageFlags) @This() {
            return @This(){
                .name = name,
                .elem_type = elem_type,
                .usage = usage,
            };
        }
    };
}

const StorageDef = struct {
    element_type: type,
    usage: GPU_BufferUsageFlags,
};

pub const ValidationSettings = struct {
    master_error_mode: Common.ErrorBehavior = .RETURN_ERRORS,
    master_assert_mode: Common.AssertBehavior = .PANIC_IN_SAFE_MODES,
    master_warn_mode: Common.WarnBehavior = .WARN_IN_DEBUG,
    mismatched_cpu_types: ValidateMode = .PANIC,
    mismatched_gpu_formats: ValidateMode = .PANIC,
    vertex_buffer_slot_gaps: ValidateMode = .PANIC,
    depth_stencil_zero_bits: ValidateMode = .PANIC,
    depth_texture_non_depth_format: ValidateMode = .PANIC,
    depth_texture_non_stencil_format: ValidateMode = .PANIC,
    color_texture_non_color_format: ValidateMode = .PANIC,
    color_targets_missing: ValidateMode = .PANIC,
    push_unallowed_uniform: ValidateMode = .PANIC,
    transfer_data_type_mismatch: ValidateMode = .PANIC,
    transfer_data_exact_size_match: ValidateMode = .WARN,
};

pub const ExtraControllerSettings = struct {
    allow_resource_handle_aliasing: bool = false,
};

pub fn IndexBufferDef(comptime INDEX_BUFFER_NAMES_ENUM: type) type {
    return struct {
        name: INDEX_BUFFER_NAMES_ENUM,
        index_size: SDL3.GPU_IndexTypeSize,

        pub fn index_buffer_def(comptime name: INDEX_BUFFER_NAMES_ENUM, comptime size: SDL3.GPU_IndexTypeSize) @This() {
            return @This(){
                .name = name,
                .index_size = size,
            };
        }
    };
}

pub fn IndirectDrawBufferDef(comptime INDIRECT_BUFFER_NAMES_ENUM: type) type {
    return struct {
        name: INDIRECT_BUFFER_NAMES_ENUM,
        mode: IndirectDrawMode,

        pub fn indirect_draw_buffer_def(comptime name: INDIRECT_BUFFER_NAMES_ENUM, comptime mode: IndirectDrawMode) @This() {
            return @This(){
                .name = name,
                .mode = mode,
            };
        }
    };
}

/// This object defines a comptime type with an API to instantiate and control
/// the entire graphics system with more convenient and carefully controlled
/// methods than the standard SDL3 API. For most applications this will be a good
/// choice for all your graphics needs, as it eliminates many pitfalls at comptime
/// and streamlines the graphics workflow.
///
/// It is also possible to use this for a *portion* of your graphics workload,
/// and use the standard functions to support it where needed.
///
/// It is designed to work alongside `SDL3_ShaderContract.zig` to automatically
/// layout uniforms, storage buffers, and vertex buffers/structs to conform to
/// the requirements imposed by the SDL3 GPU API, and can be used to automatically
/// generate entire shader source files ready to accept user logic.
///
/// BUT, strictly speaking it is not *required* to use `SDL3_ShaderContract.zig`,
/// as long as you properly manually design the structs/info for the vertex/uniform/storage buffers
pub fn GraphicsController(
    /// Specifies allowed shader formats, debug mode, and driver name
    comptime GPU_OPTIONS: GPU_CreateOptions,
    /// An enum with tag names for each unique window of the application
    ///
    /// Non-named windows are allowed, but must be handled using the standard SDL3 api
    comptime WINDOW_NAMES_ENUM: type,
    /// An enum for named gpu fences. When a fence is requested, it must be sent
    /// to a named fence slot, and waited on by name.
    comptime FENCE_NAMES_ENUM: type,
    /// An enum with names for each index buffer to be used
    comptime INDEX_BUFFER_NAMES: type,
    /// A list of all index buffer definitions
    ///
    /// Each name in `INDEX_BUFFER_NAMES` must be represented exactly once
    comptime INDEX_BUFFER_DEFINITIONS: [Types.enum_defined_field_count(INDEX_BUFFER_NAMES)]IndexBufferDef(INDEX_BUFFER_NAMES),
    /// An enum with names for each indirect draw buffer
    comptime INDIRECT_BUFFER_NAMES: type,
    /// A list of all indirect draw call buffer definitions
    ///
    /// Each name in `INDIRECT_BUFFER_NAMES` must be represented exactly once
    comptime INDIRECT_BUFFER_DEFINITIONS: [Types.enum_defined_field_count(INDIRECT_BUFFER_NAMES)]IndirectDrawBufferDef(INDIRECT_BUFFER_NAMES),
    /// An enum with tag names for each unique `UPLOAD` transfer buffer used in application
    ///
    /// Upload transfer buffers are used to move data from the Application to the GPU
    comptime UPLOAD_TRANSFER_BUFFER_NAMES_ENUM: type,
    /// An enum with tag names for each unique `DOWNLOAD` transfer buffer used in application
    ///
    /// Download transfer buffers are used to move data from the GPU back to the Application
    comptime DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM: type,
    /// An enum with tag names for each unique vertex buffer used in application
    ///
    /// These are the data buffers holding one or more vertex attributes, and more than
    /// one vertex buffer can feed a single vertex shader struct/input, if desired. The
    /// actual vertx buffer element types are automatically generated/validated at compile time
    /// based on the various defined `VertexInputStructDefinition`
    comptime VERTEX_BUFFER_NAMES_ENUM: type,
    /// An enum with tag names for each unique vertex input struct used in the application
    comptime VERTEX_INPUT_STRUCT_NAMES_ENUM: type,
    /// A list of all `VertexInputStructDefinition` used in the application
    ///
    /// Every name in `VERTEX_INPUT_STRUCT_NAMES_ENUM` must be represented exactly once
    comptime VERTEX_INPUT_STRUCT_DEFINITIONS: [Types.enum_defined_field_count(VERTEX_INPUT_STRUCT_NAMES_ENUM)]VertexInputStructDefinition(VERTEX_INPUT_STRUCT_NAMES_ENUM),
    /// An enum with tag names for each unique vertex-to-fragment shader struct used in the application
    /// (GPU side only, but used for validation and shader templating)
    comptime VERTEX_TO_FRAG_STRUCT_NAMES_ENUM: type,
    /// A list of all `VertexToFragmentStructDefinition` used in the application
    ///
    /// Every name in `VERTEX_TO_FRAG_STRUCT_NAMES_ENUM` must be represented exactly once
    comptime VERTEX_TO_FRAG_STRUCT_DEFINITIONS: [Types.enum_defined_field_count(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM)]VertexToFragmentStructDefinition(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM),
    /// An enum with tag names for each unique fragment shader output struct used in the application
    /// (GPU oside only, but used for shader templating and validation)
    comptime FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM: type,
    /// A list of all `FragmentOutputStructDefinition` used in the application
    ///
    /// Every name in `FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM` must be represented exactly once
    comptime FRAGMENT_OUTPUT_STRUCT_DEFINITIONS: [Types.enum_defined_field_count(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM)]FragmentOutputStructDefinition(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM),
    /// An enum with tag names for each unique uniform struct used in application
    comptime UNIFORM_NAMES_ENUM: type,
    /// A list of all `UniformStructDefinition` used in the application
    ///
    /// Every name in `UNIFORM_NAMES_ENUM` must be represented exactly once
    comptime UNIFORM_STRUCT_DEFINITIONS: [Types.enum_defined_field_count(UNIFORM_NAMES_ENUM)]UniformStructDefinition(UNIFORM_NAMES_ENUM),
    /// An enum with tag names for each unique texture *sampler* used in application
    comptime SAMPLER_NAMES_ENUM: type,
    /// A list of all sampler definitions
    ///
    /// Each name in `SAMPLER_NAMES_ENUM` must be represented exactly once
    comptime SAMPLER_DEFINITIONS: [Types.enum_defined_field_count(SAMPLER_NAMES_ENUM)]SamplerDefinition(SAMPLER_NAMES_ENUM),
    /// An enum with tag names for each unique gpu storage buffer used in application
    comptime STORAGE_BUFFER_NAMES_ENUM: type,
    /// This is a list of descriptions of storage buffer element types
    ///
    /// Each name in `GPU_STORAGE_BUFFER_NAMES_ENUM` must be represented exactly once
    comptime STORAGE_BUFFER_DEFINITIONS: [Types.enum_defined_field_count(STORAGE_BUFFER_NAMES_ENUM)]StorageBufferDefinition(STORAGE_BUFFER_NAMES_ENUM),
    /// An enum with tag names for each unique texture used in application
    comptime TEXTURE_NAMES_ENUM: type,
    /// A list of all texture definitions for each of the named textures
    comptime TEXTURE_DEFINITIONS: [Types.enum_defined_field_count(TEXTURE_NAMES_ENUM)]TextureDefinition(TEXTURE_NAMES_ENUM),
    /// An enum with tag names for each unique vertex shader used in application
    comptime VERTEX_SHADER_NAMES_ENUM: type,
    /// A list of all the resource bindings for each vertex shader in the application
    comptime VERTEX_SHADER_DEFINITIONS: [Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM)]VertexShaderDefinition(
        VERTEX_SHADER_NAMES_ENUM,
        VERTEX_INPUT_STRUCT_NAMES_ENUM,
        VERTEX_TO_FRAG_STRUCT_NAMES_ENUM,
        UNIFORM_NAMES_ENUM,
        STORAGE_BUFFER_NAMES_ENUM,
        TEXTURE_NAMES_ENUM,
        SAMPLER_NAMES_ENUM,
    ),
    /// An enum with tag names for each unique fragment shader used in application
    comptime FRAGMENT_SHADER_NAMES_ENUM: type,
    /// A list of all the resource bindings for each fragment shader in the application
    comptime FRAGMENT_SHADER_DEFINITIONS: [Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM)]FragmentShaderDefinition(
        FRAGMENT_SHADER_NAMES_ENUM,
        VERTEX_TO_FRAG_STRUCT_NAMES_ENUM,
        FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM,
        UNIFORM_NAMES_ENUM,
        STORAGE_BUFFER_NAMES_ENUM,
        TEXTURE_NAMES_ENUM,
        SAMPLER_NAMES_ENUM,
    ),
    /// An enum with tag names for each unique render (graphics) pipeline used in application
    comptime RENDER_PIPELINE_NAMES_ENUM: type,
    /// A list of all render pipelines and their associated vertex/fragment shaders
    comptime RENDER_PIPELINE_DEFINITIONS: [Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM)]RenderPipelineDefinition(
        RENDER_PIPELINE_NAMES_ENUM,
        VERTEX_SHADER_NAMES_ENUM,
        FRAGMENT_SHADER_NAMES_ENUM,
    ),
    comptime EVAL_QUOTA: comptime_int,
) type {
    @setEvalBranchQuota(EVAL_QUOTA);
    // CONVENIENCE CONSTS
    const _VertexShaderDefinition = VertexShaderDefinition(VERTEX_SHADER_NAMES_ENUM, VERTEX_INPUT_STRUCT_NAMES_ENUM, VERTEX_TO_FRAG_STRUCT_NAMES_ENUM, UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _FragmentShaderDefinition = FragmentShaderDefinition(FRAGMENT_SHADER_NAMES_ENUM, VERTEX_TO_FRAG_STRUCT_NAMES_ENUM, FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM, UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _RenderPipelineDefinition = RenderPipelineDefinition(RENDER_PIPELINE_NAMES_ENUM, VERTEX_SHADER_NAMES_ENUM, FRAGMENT_SHADER_NAMES_ENUM);
    // const _TextureDefinition = TextureDefinition(TEXTURE_NAMES_ENUM);
    const _ShaderAllowedUniform = ShaderAllowedUniform(UNIFORM_NAMES_ENUM);
    const _ShaderAllowedSamplePair = ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _ShaderAllowedStorageBuffer = ShaderAllowedStorageBuffer(STORAGE_BUFFER_NAMES_ENUM);
    const _ShaderAllowedStorageTexture = ShaderAllowedStorageTexture(TEXTURE_NAMES_ENUM);
    // const _UniformStructDefinition = UniformStructDefinition(UNIFORM_NAMES_ENUM);
    // VALIDATE SIMPLE ENUMS
    assert_with_reason(Types.type_is_enum(WINDOW_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(WINDOW_NAMES_ENUM), @src(), "type `WINDOW_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(WINDOW_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(VERTEX_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_SHADER_NAMES_ENUM), @src(), "type `VERTEX_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(FRAGMENT_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_SHADER_NAMES_ENUM), @src(), "type `FRAGMENT_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `UPLOAD_TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(FENCE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FENCE_NAMES_ENUM), @src(), "type `FENCE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FENCE_NAMES_ENUM)});
    const _NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
    const _NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
    // ORDER AND VALIDATE INDEX BUFFERS
    assert_with_reason(Types.type_is_enum(INDEX_BUFFER_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(INDEX_BUFFER_NAMES), @src(), "type `INDEX_BUFFER_NAMES` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(INDEX_BUFFER_NAMES)});
    const _NUM_INDEX_BUFFERS = Types.enum_defined_field_count(INDEX_BUFFER_NAMES);
    const _INDEX_BUFFER_TAGS, const _INDEX_BUFFER_TYPES, const _INDEX_BUFFER_SIZES = comptime make: {
        var tags_: [_NUM_INDEX_BUFFERS]SDL3.GPU_IndexTypeSize = undefined;
        var types_: [_NUM_INDEX_BUFFERS]type = undefined;
        var sizes_: [_NUM_INDEX_BUFFERS]u32 = undefined;
        var defined_: [_NUM_INDEX_BUFFERS]bool = @splat(false);
        for (INDEX_BUFFER_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined_[idx] == false, @src(), "index buffer `{s}` was defined more than once", .{@tagName(def.name)});
            defined_[idx] = true;
            tags_[idx] = def.index_size;
            types_[idx] = switch (def.index_size) {
                .U16 => u16,
                .U32 => u32,
            };
            sizes_[idx] = def.index_size.size();
        }
        break :make .{ tags_, types_, sizes_ };
    };
    // ORDER AND VALIDATE INDIRECT DRAW BUFFERS
    assert_with_reason(Types.type_is_enum(INDIRECT_BUFFER_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(INDIRECT_BUFFER_NAMES), @src(), "type `INDIRECT_BUFFER_NAMES` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(INDIRECT_BUFFER_NAMES)});
    const _NUM_INDIRECT_BUFFERS = Types.enum_defined_field_count(INDIRECT_BUFFER_NAMES);
    const _INDIRECT_BUFFER_TYPES, const _INDIRECT_BUFFER_MODES, const _INDIRECT_BUFFER_SIZES = comptime make: {
        var types: [_NUM_INDIRECT_BUFFERS]type = undefined;
        var sizes: [_NUM_INDIRECT_BUFFERS]u32 = undefined;
        var modes: [_NUM_INDIRECT_BUFFERS]IndirectDrawMode = undefined;
        var defined: [_NUM_INDIRECT_BUFFERS]bool = @splat(false);
        for (INDIRECT_BUFFER_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "indirect draw buffer `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            types[idx] = def.mode.elem_type();
            modes[idx] = def.mode;
            sizes[idx] = @sizeOf(def.mode.elem_type());
        }
        break :make .{ types, modes, sizes };
    };
    // ORDER AND VALIDATE SAMPLERS
    assert_with_reason(Types.type_is_enum(SAMPLER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(SAMPLER_NAMES_ENUM), @src(), "type `SAMPLER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(SAMPLER_NAMES_ENUM)});
    const _NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);
    const _SAMPLER_DEFS = comptime make: {
        var defs: [_NUM_SAMPLERS]GPU_SamplerCreateInfo = undefined;
        var defined: [_NUM_SAMPLERS]bool = @splat(false);
        for (SAMPLER_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "sampler `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            defs[idx] = def.sdl_info(.{});
        }
        break :make defs;
    };
    // ORDER AND VALIDATE TEXTURES
    assert_with_reason(Types.type_is_enum(TEXTURE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TEXTURE_NAMES_ENUM), @src(), "type `TEXTURE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TEXTURE_NAMES_ENUM)});
    const _NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
    const _TEXTURE_DEFS = comptime make: {
        var defs: [_NUM_TEXTURES]TextureDef = undefined;
        var defined: [_NUM_TEXTURES]bool = @splat(false);
        for (TEXTURE_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "texture `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            assert_with_reason(def.pixel_format != .INVALID, @src(), "texture `{s}` had an `.INVALID` pixel format", .{@tagName(def.name)});
            defs[idx] = TextureDef{
                .shape = def.shape,
                .sample_count = def.sample_count,
                .usage = def.usage,
                .mipmap_levels = def.mipmap_levels,
                .pixel_format = def.pixel_format,
            };
        }
        break :make defs;
    };
    // ORDER AND VALIDATE UNIFORMS
    assert_with_reason(Types.type_is_enum(UNIFORM_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(UNIFORM_NAMES_ENUM), @src(), "type `UNIFORM_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(UNIFORM_NAMES_ENUM)});
    const _NUM_UNIFORM_STRUCTS = Types.enum_defined_field_count(UNIFORM_NAMES_ENUM);
    const _UNIFORM_TYPES, const _UNIFORM_SIZES, const _UNIFORM_OFFSETS, const STRUCT_OF_UNIFORM_STRUCTS = comptime make: {
        var sizes: [_NUM_UNIFORM_STRUCTS]u32 = undefined;
        var defined: [_NUM_UNIFORM_STRUCTS]bool = @splat(false);
        var types: [_NUM_UNIFORM_STRUCTS]type = undefined;
        var names: [_NUM_UNIFORM_STRUCTS][:0]const u8 = undefined;
        var offsets: [_NUM_UNIFORM_STRUCTS]u32 = undefined;
        const attrs: [_NUM_UNIFORM_STRUCTS]std.builtin.Type.StructField.Attributes = @splat(.{});
        for (UNIFORM_STRUCT_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "uniform `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            sizes[idx] = @sizeOf(def.type);
            types[idx] = def.type;
            names[idx] = @tagName(def.name);
        }
        const AllUniformsWrapper = @Struct(.auto, null, names[0..], types[0..], attrs[0..]);
        for (names, 0..) |name, idx| {
            offsets[idx] = @offsetOf(AllUniformsWrapper, name);
        }
        break :make .{ types, sizes, offsets, AllUniformsWrapper };
    };
    // ORDER AND VALIDATE VERTEX INPUT STRUCTS
    assert_with_reason(Types.type_is_enum(VERTEX_INPUT_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_INPUT_STRUCT_NAMES_ENUM), @src(), "type `VERTEX_INPUT_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_INPUT_STRUCT_NAMES_ENUM)});
    const _NUM_VERTEX_INPUT_STRUCTS = Types.enum_defined_field_count(VERTEX_INPUT_STRUCT_NAMES_ENUM);
    const _VERTEX_INPUT_STRUCT_TYPES = comptime make: {
        var defined: [_NUM_VERTEX_INPUT_STRUCTS]bool = @splat(false);
        var types: [_NUM_VERTEX_INPUT_STRUCTS]type = undefined;
        for (VERTEX_INPUT_STRUCT_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "vertex input struct `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            types[idx] = def.type;
        }
        break :make types;
    };
    // VALIDATE VERTEX BUFFERS EXACTLY MATCH FOR ALL VERTEX INPUT STRUCT DEFINITIONS
    assert_with_reason(Types.type_is_enum(VERTEX_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_BUFFER_NAMES_ENUM), @src(), "type `VERTEX_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_BUFFER_NAMES_ENUM)});
    const _NUM_VERTEX_BUFFERS = Types.enum_defined_field_count(VERTEX_BUFFER_NAMES_ENUM);
    const _VERTEX_BUFFER_TYPES, const _VERTEX_BUFFER_SIZES = comptime make: {
        var types: [_NUM_VERTEX_BUFFERS]type = undefined;
        var sizes: [_NUM_VERTEX_BUFFERS]u32 = undefined;
        var defined: [_NUM_VERTEX_BUFFERS]bool = @splat(false);
        var num_defined: u32 = 0;
        for (_VERTEX_INPUT_STRUCT_TYPES) |vert_input| {
            const VERT_INPUT = AnyVertexShaderInputStruct(vert_input, VERTEX_BUFFER_NAMES_ENUM);
            for (VERT_INPUT.ACTIVE_SLOT_TYPES, VERT_INPUT.ACTIVE_SLOT_PAIRS) |need_type, pair| {
                const idx = @intFromEnum(pair.slot_name);
                if (defined[idx]) {
                    const need_info = @typeInfo(need_type).@"struct";
                    const cached_info = @typeInfo(types[idx]).@"struct";
                    assert_with_reason(need_info.layout == .@"extern" and cached_info.layout == .@"extern", @src(), "vertex buffer `{s}` is not declared as `extern` on all vertex input struct definitions", .{@tagName(pair.slot_name)});
                    assert_with_reason(need_info.fields.len == cached_info.fields.len, @src(), "mismatch bewteen the number of fields on the struct types for the vertex buffer `{s}`: need {d} fields, cached {d} fields", .{ @tagName(pair.slot_name), need_info.fields.len, cached_info.fields.len });
                    next_cached: for (cached_info.fields) |cached_field| {
                        for (need_info.fields) |need_field| {
                            if (std.mem.eql(u8, need_field.name, cached_field.name)) {
                                assert_with_reason(need_field.type == cached_field.type, @src(), "the type for field `{s}` on vertex buffer `{s}` does not match: cached = `{s}`, need = `{s}`", .{ cached_field.name, @tagName(pair.slot_name), @typeName(cached_field.type), @typeName(need_field.type) });
                                assert_with_reason(@offsetOf(need_type, cached_field.name) == @offsetOf(types[idx], cached_field.name), @src(), "the field `{s}` on vertex buffer `{s}` has mismatching offsets when calculated from two different vertex input structs: cached = `{d}`, need = `{d}`", .{ cached_field.name, @tagName(pair.slot_name), @offsetOf(types[idx], cached_field.name), @offsetOf(need_type, cached_field.name) });
                                continue :next_cached;
                            }
                        }
                        assert_unreachable(@src(), "cached struct for vertex buffer `{s}` has field `{s}`, but another vertex input struct did not define this field for this vertex buffer", .{ @tagName(pair.slot_name), cached_field.name });
                    }
                } else {
                    defined[idx] = true;
                    types[idx] = need_type;
                    sizes[idx] = @sizeOf(need_type);
                    num_defined += 1;
                    assert_with_reason(@typeInfo(need_type).@"struct".layout == .@"extern", @src(), "vertex buffer `{s}` is not declared as `extern`", .{@tagName(pair.slot_name)});
                }
            }
        }
        for (0.._NUM_VERTEX_BUFFERS) |buf_idx| {
            if (!defined[buf_idx]) {
                const e: VERTEX_BUFFER_NAMES_ENUM = num_cast(buf_idx, VERTEX_BUFFER_NAMES_ENUM);
                assert_unreachable(@src(), "vertex buffer `{s}` is not used by any vertex input struct, and therefore is not used in any render pipeline", .{@tagName(e)});
            }
        }
        break :make .{ types, sizes };
    };
    // ORDER AND VALIDATE VERTEX TO FRAG STRUCTS
    assert_with_reason(Types.type_is_enum(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM), @src(), "type `VERTEX_TO_FRAG_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM)});
    const _NUM_VERTEX_TO_FRAG_STRUCTS = Types.enum_defined_field_count(VERTEX_TO_FRAG_STRUCT_NAMES_ENUM);
    const _VERTEX_TO_FRAG_STRUCT_TYPES = comptime make: {
        var defined: [_NUM_VERTEX_TO_FRAG_STRUCTS]bool = @splat(false);
        var types: [_NUM_VERTEX_TO_FRAG_STRUCTS]type = undefined;
        for (VERTEX_TO_FRAG_STRUCT_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "vertex-to-frag struct `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            types[idx] = def.type;
        }
        break :make types;
    };
    // ORDER AND VALIDATE VERTEX TO FRAG STRUCTS
    assert_with_reason(Types.type_is_enum(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM), @src(), "type `FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM)});
    const _NUM_FRAGMENT_OUTPUT_STRUCTS = Types.enum_defined_field_count(FRAGMENT_OUTPUT_STRUCT_NAMES_ENUM);
    const _FRAGMENT_OUTPUT_STRUCT_TYPES = comptime make: {
        var defined: [_NUM_FRAGMENT_OUTPUT_STRUCTS]bool = @splat(false);
        var types: [_NUM_FRAGMENT_OUTPUT_STRUCTS]type = undefined;
        for (FRAGMENT_OUTPUT_STRUCT_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "fragment output struct `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            types[idx] = def.type;
        }
        break :make types;
    };
    // ORDER AND VALIDATE STORAGE BUFFERS
    assert_with_reason(Types.type_is_enum(STORAGE_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(STORAGE_BUFFER_NAMES_ENUM), @src(), "type `STORAGE_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(STORAGE_BUFFER_NAMES_ENUM)});
    const _NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(STORAGE_BUFFER_NAMES_ENUM);
    const _STORAGE_BUFFER_TYPES, const _STORAGE_BUFFER_SIZES, const _STORAGE_BUFFER_USAGES = comptime make: {
        var types: [_NUM_STORAGE_BUFFERS]type = undefined;
        var sizes: [_NUM_STORAGE_BUFFERS]u32 = undefined;
        var usages: [_NUM_STORAGE_BUFFERS]GPU_BufferUsageFlags = undefined;
        var defined: [_NUM_STORAGE_BUFFERS]bool = @splat(false);
        for (STORAGE_BUFFER_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "storage buffer `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            types[idx] = def.elem_type;
            sizes[idx] = @sizeOf(def.elem_type);
            usages[idx] = def.usage;
        }
        break :make .{ types, sizes, usages };
    };
    // ORDER RENDER PIPELINES
    assert_with_reason(Types.type_is_enum(RENDER_PIPELINE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(RENDER_PIPELINE_NAMES_ENUM), @src(), "type `RENDER_PIPELINE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(RENDER_PIPELINE_NAMES_ENUM)});
    const _NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
    const _RENDER_PIPELINE_DEFS = comptime make: {
        var defined: [_NUM_RENDER_PIPELINES]bool = @splat(false);
        var defs: [_NUM_RENDER_PIPELINES]_RenderPipelineDefinition = undefined;
        for (RENDER_PIPELINE_DEFINITIONS) |def| {
            const idx = @intFromEnum(def.name);
            assert_with_reason(defined[idx] == false, @src(), "render pipeline `{s}` was defined more than once", .{@tagName(def.name)});
            defined[idx] = true;
            defs[idx] = def;
        }
        break :make defs;
    };
    // VALIDATE RENDER PIPELINES STARTING HERE
    // VARIBLE PACKAGE TO PASS TO COMPTIME SUBROUTINES FOR CONVENIENCE
    const VARS = struct {
        const SELF_VARS = @This();
        linkages_defined: [_NUM_RENDER_PIPELINES]bool = @splat(false),
        uniforms_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_UNIFORM_STRUCTS]AllowedResource = @splat(@splat(AllowedResource{})),
        uniforms_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        uniforms_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_UNIFORM_STRUCTS]AllowedResource = @splat(@splat(AllowedResource{})),
        uniforms_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        next_storage_gpu_register_in_vertex_shaders: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        next_storage_gpu_register_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        storage_buffers_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_STORAGE_BUFFERS]AllowedResourceGpuCpu = @splat(@splat(AllowedResourceGpuCpu{})),
        storage_buffers_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        storage_buffers_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_STORAGE_BUFFERS]AllowedResourceGpuCpu = @splat(@splat(AllowedResourceGpuCpu{})),
        storage_buffers_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        storage_textures_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_TEXTURES]AllowedResourceGpuCpu = @splat(@splat(AllowedResourceGpuCpu{})),
        storage_textures_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        storage_textures_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_TEXTURES]AllowedResourceGpuCpu = @splat(@splat(AllowedResourceGpuCpu{})),
        storage_textures_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        sample_pairs_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_TEXTURES][_NUM_SAMPLERS]AllowedResourceGpuCpu = @splat(@splat(@splat(AllowedResourceGpuCpu{}))),
        sample_pairs_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        sample_pairs_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_TEXTURES][_NUM_SAMPLERS]AllowedResourceGpuCpu = @splat(@splat(@splat(AllowedResourceGpuCpu{}))),
        sample_pairs_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        max_enum_types_in_vertex_shaders: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        max_enum_types_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
    };
    comptime var vars = VARS{};
    // COMPTIME SUB-ROUTINES ONLY NEEDED FOR THIS BLOCK
    const SUB_ROUTINE = struct {
        const SELF_SUB_ROUTINE = @This();
        fn process_uniform_def(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime uniform_name: UNIFORM_NAMES_ENUM,
            comptime stage: ShaderStage,
        ) void {
            const uni_idx = @intFromEnum(uniform_name);
            switch (comptime stage) {
                .VERTEX => {
                    assert_with_reason(v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(uniform_name), shader_name });
                    v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed = true;
                    v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].register = v.uniforms_allowed_in_vertex_shaders_len[shader_idx];
                    v.uniforms_allowed_in_vertex_shaders_len[shader_idx] += 1;
                    const UNI_TYPE = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                    v.max_enum_types_in_vertex_shaders[shader_idx] += @intCast(UNI_TYPE.ENUMS.len);
                },
                .FRAGMENT => {
                    assert_with_reason(v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(uniform_name), shader_name });
                    v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed = true;
                    v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].register = v.uniforms_allowed_in_fragment_shaders_len[shader_idx];
                    v.uniforms_allowed_in_fragment_shaders_len[shader_idx] += 1;
                    const UNI_TYPE = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                    v.max_enum_types_in_fragment_shaders[shader_idx] += @intCast(UNI_TYPE.ENUMS.len);
                },
            }
        }
        fn process_storage_buffer_def(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime buffer_name: STORAGE_BUFFER_NAMES_ENUM,
            comptime stage: ShaderStage,
        ) void {
            const buf_idx = @intFromEnum(buffer_name);
            if (comptime stage == .VERTEX) {
                assert_with_reason(v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(buffer_name), shader_name });
                v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed = true;
                v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].gpu_register = v.next_storage_gpu_register_in_vertex_shaders[shader_idx];
                v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].cpu_register = v.storage_buffers_allowed_in_vertex_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_vertex_shaders[shader_idx] += 1;
                v.storage_buffers_allowed_in_vertex_shaders_len[shader_idx] += 1;
                const STORE_TYPE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buffer_name)]);
                v.max_enum_types_in_vertex_shaders[shader_idx] += @intCast(STORE_TYPE.ENUMS.len);
            } else {
                assert_with_reason(v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(buffer_name), shader_name });
                v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].allowed = true;
                v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].gpu_register = v.next_storage_gpu_register_in_fragment_shaders[shader_idx];
                v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].cpu_register = v.storage_buffers_allowed_in_fragment_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_fragment_shaders[shader_idx] += 1;
                v.storage_buffers_allowed_in_fragment_shaders_len[shader_idx] += 1;
                const STORE_TYPE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buffer_name)]);
                v.max_enum_types_in_fragment_shaders[shader_idx] += @intCast(STORE_TYPE.ENUMS.len);
            }
        }
        fn process_storage_texture_def(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime texture_name: TEXTURE_NAMES_ENUM,
            comptime stage: ShaderStage,
        ) void {
            const tex_idx = @intFromEnum(texture_name);
            if (comptime stage == .VERTEX) {
                assert_with_reason(v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(texture_name), shader_name });
                v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed = true;
                v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].gpu_register = v.next_storage_gpu_register_in_vertex_shaders[shader_idx];
                v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].cpu_register = v.storage_textures_allowed_in_vertex_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_vertex_shaders[shader_idx] += 1;
                v.storage_textures_allowed_in_vertex_shaders_len[shader_idx] += 1;
            } else {
                assert_with_reason(v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(texture_name), shader_name });
                v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].allowed = true;
                v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].gpu_register = v.next_storage_gpu_register_in_fragment_shaders[shader_idx];
                v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].cpu_register = v.storage_textures_allowed_in_fragment_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_fragment_shaders[shader_idx] += 1;
                v.storage_textures_allowed_in_fragment_shaders_len[shader_idx] += 1;
            }
        }
        fn process_sample_pair_def(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime tex_name: TEXTURE_NAMES_ENUM,
            comptime samp_name: SAMPLER_NAMES_ENUM,
            comptime stage: ShaderStage,
        ) void {
            const tex_idx = @intFromEnum(tex_name);
            const samp_idx = @intFromEnum(samp_name);
            if (comptime stage == .VERTEX) {
                assert_with_reason(v.sample_pairs_allowed_in_vertex_shaders[shader_idx][tex_idx][samp_idx].allowed == false, @src(), "sampler pair `{s} + {s}` was registered more than once for vertex shader `{s}`", .{ @tagName(tex_name), @tagName(samp_name), shader_name });
                v.sample_pairs_allowed_in_vertex_shaders[shader_idx][tex_idx][samp_idx].allowed = true;
                v.sample_pairs_allowed_in_vertex_shaders[shader_idx][tex_idx][samp_idx].gpu_register = v.next_storage_gpu_register_in_vertex_shaders[shader_idx];
                v.sample_pairs_allowed_in_vertex_shaders[shader_idx][tex_idx][samp_idx].cpu_register = v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_vertex_shaders[shader_idx] += 1;
                v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx] += 1;
            } else {
                assert_with_reason(v.sample_pairs_allowed_in_fragment_shaders[shader_idx][tex_idx][samp_idx].allowed == false, @src(), "sampler pair `{s} + {s}` was registered more than once for fragment shader `{s}`", .{ @tagName(tex_name), @tagName(samp_name), shader_name });
                v.sample_pairs_allowed_in_fragment_shaders[shader_idx][tex_idx][samp_idx].allowed = true;
                v.sample_pairs_allowed_in_fragment_shaders[shader_idx][tex_idx][samp_idx].gpu_register = v.next_storage_gpu_register_in_fragment_shaders[shader_idx];
                v.sample_pairs_allowed_in_fragment_shaders[shader_idx][tex_idx][samp_idx].cpu_register = v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx];
                v.next_storage_gpu_register_in_fragment_shaders[shader_idx] += 1;
                v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx] += 1;
            }
        }
        fn combine_unique_enums(comptime LIST: []type, comptime LEN: *u32, comptime ADD: []const type) void {
            next_to_add: inline for (ADD) |add_enum_type| {
                inline for (LIST[0..LEN.*]) |unique_enum| {
                    if (add_enum_type == unique_enum) continue :next_to_add;
                }
                LIST[LEN.*] = add_enum_type;
                LEN.* += 1;
            }
        }
    };
    // COMPTIME VALIDATION / ORGANIZATION OF VERTEX SHADER BINDINGS
    const _VERTEX_SHADER_DEFS, const _VERTEX_SHADER_UNIQUE_ENUM_STARTS = comptime make: {
        var defined: [_NUM_VERTEX_SHADERS]bool = @splat(false);
        var defs: [_NUM_VERTEX_SHADERS]_VertexShaderDefinition = undefined;
        var total_unique_enum_sets_len: u32 = 0;
        var unique_enum_starts: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
        for (VERTEX_SHADER_DEFINITIONS[0..]) |def| {
            const idx = @intFromEnum(def.vertex_shader);
            assert_with_reason(defined[idx] == false, @src(), "for vertex shader `{s}` was defined twice", .{@tagName(def.vertex_shader)});
            defined[idx] = true;
            defs[idx] = def;
            // LOG REGISTERS FOR VARIOUS RESOURCES
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        SUB_ROUTINE.process_uniform_def(&vars, @intCast(idx), @tagName(def.vertex_shader), uniform_name, .VERTEX);
                    },
                    else => {},
                }
            }
            // NOTABLY, PROCESS STORAGE RESOURCES IN THE ORDER: SAMPLERS -> TEXTURES -> BUFFERS, TO CORRECTLY PROVISION GPU REGISTER SLOTS
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .SAMPLED_TEXTURE => |tex_samp_pair| {
                        SUB_ROUTINE.process_sample_pair_def(&vars, @intCast(idx), @tagName(def.vertex_shader), tex_samp_pair.tex_name, tex_samp_pair.samp_name, .VERTEX);
                    },
                    else => {},
                }
            }
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .STORAGE_TEXTURE => |tex_name| {
                        SUB_ROUTINE.process_storage_texture_def(&vars, @intCast(idx), @tagName(def.vertex_shader), tex_name, .VERTEX);
                    },
                    else => {},
                }
            }
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .STORAGE_BUFFER => |buf_name| {
                        assert_with_reason(_STORAGE_BUFFER_USAGES[@intFromEnum(buf_name)].has_flag(.GRAPHICS_STORAGE_READ), @src(), "cannot bind storage buffer `{s}` to vertex shader `{s}` because is does not have the `.GRAPHICS_STORAGE_READ` usage flag", .{ @tagName(buf_name), @tagName(def.vertex_shader) });
                        SUB_ROUTINE.process_storage_buffer_def(&vars, @intCast(idx), @tagName(def.vertex_shader), buf_name, .VERTEX);
                    },
                    else => {},
                }
            }
            const IN = AnyVertexShaderInputStruct(_VERTEX_INPUT_STRUCT_TYPES[@intFromEnum(def.input_type)], VERTEX_BUFFER_NAMES_ENUM);
            const OUT = AnyVertexToFragmentStruct(_VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.output_type)]);
            vars.max_enum_types_in_vertex_shaders[@as(usize, @intCast(idx))] += @intCast(IN.ENUMS.len + OUT.ENUMS.len);
            const MAX_ENUMS = vars.max_enum_types_in_vertex_shaders[@as(usize, @intCast(idx))];
            var unique_enums: [MAX_ENUMS]type = undefined;
            @memcpy(unique_enums[0..IN.ENUMS.len], IN.ENUMS[0..]);
            var unique_enums_len: u32 = @intCast(IN.ENUMS.len);
            SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, OUT.ENUMS[0..]);
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        const UNI = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, UNI.ENUMS[0..]);
                    },
                    .STORAGE_BUFFER => |buf_name| {
                        const STORE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buf_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, STORE.ENUMS[0..]);
                    },
                    else => {},
                }
            }
            unique_enum_starts[idx] = total_unique_enum_sets_len;
            total_unique_enum_sets_len += unique_enums_len;
        }
        unique_enum_starts[_NUM_VERTEX_SHADERS] = total_unique_enum_sets_len;
        break :make .{ defs, unique_enum_starts };
    };
    const _VERTEX_SHADER_UNIQUE_ENUMS = comptime make: {
        var all_unique_vertex_enums: [_VERTEX_SHADER_UNIQUE_ENUM_STARTS[_NUM_VERTEX_SHADERS]]type = undefined;
        for (_VERTEX_SHADER_DEFS[0..], 0..) |def, idx| {
            const start = _VERTEX_SHADER_UNIQUE_ENUM_STARTS[idx];
            const end = _VERTEX_SHADER_UNIQUE_ENUM_STARTS[idx + 1];
            const IN = AnyVertexShaderInputStruct(_VERTEX_INPUT_STRUCT_TYPES[@intFromEnum(def.input_type)], VERTEX_BUFFER_NAMES_ENUM);
            const OUT = AnyVertexToFragmentStruct(_VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.output_type)]);
            var unique_enums = all_unique_vertex_enums[start..end];
            @memcpy(unique_enums[0..IN.ENUMS.len], IN.ENUMS[0..]);
            var unique_enums_len: u32 = @intCast(IN.ENUMS.len);
            SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, OUT.ENUMS[0..]);
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        const UNI = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, UNI.ENUMS[0..]);
                    },
                    .STORAGE_BUFFER => |buf_name| {
                        const STORE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buf_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, STORE.ENUMS[0..]);
                    },
                    else => {},
                }
            }
        }
        break :make all_unique_vertex_enums;
    };
    // COMPTIME VALIDATION / ORGANIZATION OF FRAGMENT SHADER BINDINGS
    const _FRAGMENT_SHADER_DEFS, const _FRAGMENT_SHADER_UNIQUE_ENUM_STARTS = comptime make: {
        var defined: [_NUM_FRAGMENT_SHADERS]bool = @splat(false);
        var defs: [_NUM_FRAGMENT_SHADERS]_FragmentShaderDefinition = undefined;
        var total_unique_enum_sets_len: u32 = 0;
        var unique_enum_starts: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
        for (FRAGMENT_SHADER_DEFINITIONS[0..]) |def| {
            const idx = @intFromEnum(def.fragment_shader);
            assert_with_reason(defined[idx] == false, @src(), "fragment shader `{s}` was defined twice", .{@tagName(def.fragment_shader)});
            defined[idx] = true;
            defs[idx] = def;
            // LOG REGISTERS FOR VARIOUS RESOURCES
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        SUB_ROUTINE.process_uniform_def(&vars, @intCast(idx), @tagName(def.fragment_shader), uniform_name, .FRAGMENT);
                    },
                    else => {},
                }
            }
            // NOTABLY, PROCESS STORAGE RESOURCES IN THE ORDER: SAMPLERS -> TEXTURES -> BUFFERS, TO CORRECTLY PROVISION GPU REGISTER SLOTS
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .SAMPLED_TEXTURE => |tex_samp_pair| {
                        SUB_ROUTINE.process_sample_pair_def(&vars, @intCast(idx), @tagName(def.fragment_shader), tex_samp_pair.tex_name, tex_samp_pair.samp_name, .FRAGMENT);
                    },
                    else => {},
                }
            }
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .STORAGE_TEXTURE => |tex_name| {
                        SUB_ROUTINE.process_storage_texture_def(&vars, @intCast(idx), @tagName(def.fragment_shader), tex_name, .FRAGMENT);
                    },
                    else => {},
                }
            }
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .STORAGE_BUFFER => |buf_name| {
                        assert_with_reason(_STORAGE_BUFFER_USAGES[@intFromEnum(buf_name)].contains(.GRAPHICS_STORAGE_READ), @src(), "cannot bind storage buffer `{s}` to fragment shader `{s}` because is does not have the `.GRAPHICS_STORAGE_READ` usage flag", .{ @tagName(buf_name), @tagName(def.fragment_shader) });
                        SUB_ROUTINE.process_storage_buffer_def(&vars, @intCast(idx), @tagName(def.fragment_shader), buf_name, .FRAGMENT);
                    },
                    else => {},
                }
            }
            const IN = AnyVertexToFragmentStruct(_VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.input_type)]);
            const OUT = AnyFragmentShaderOutputStruct(_FRAGMENT_OUTPUT_STRUCT_TYPES[@intFromEnum(def.output_type)]);
            vars.max_enum_types_in_fragment_shaders[@as(usize, @intCast(idx))] += @intCast(IN.ENUMS.len + OUT.ENUMS.len);
            const MAX_ENUMS = vars.max_enum_types_in_fragment_shaders[@as(usize, @intCast(idx))];
            var unique_enums: [MAX_ENUMS]type = undefined;
            @memcpy(unique_enums[0..IN.ENUMS.len], IN.ENUMS[0..]);
            var unique_enums_len: u32 = @intCast(IN.ENUMS.len);
            SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, OUT.ENUMS[0..]);
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        const UNI = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, UNI.ENUMS[0..]);
                    },
                    .STORAGE_BUFFER => |buf_name| {
                        const STORE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buf_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, STORE.ENUMS[0..]);
                    },
                    else => {},
                }
            }
            unique_enum_starts[idx] = total_unique_enum_sets_len;
            total_unique_enum_sets_len += unique_enums_len;
        }
        unique_enum_starts[_NUM_FRAGMENT_SHADERS] = total_unique_enum_sets_len;
        break :make .{ defs, unique_enum_starts };
    };
    const _FRAGMENT_SHADER_UNIQUE_ENUMS = comptime make: {
        var all_unique_fragment_enums: [_FRAGMENT_SHADER_UNIQUE_ENUM_STARTS[_NUM_FRAGMENT_SHADERS]]type = undefined;
        for (_FRAGMENT_SHADER_DEFS[0..], 0..) |def, idx| {
            const start = _FRAGMENT_SHADER_UNIQUE_ENUM_STARTS[idx];
            const end = _FRAGMENT_SHADER_UNIQUE_ENUM_STARTS[idx + 1];
            const IN = AnyVertexToFragmentStruct(_VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.input_type)]);
            const OUT = AnyFragmentShaderOutputStruct(_FRAGMENT_OUTPUT_STRUCT_TYPES[@intFromEnum(def.output_type)]);
            var unique_enums = all_unique_fragment_enums[start..end];
            @memcpy(unique_enums[0..IN.ENUMS.len], IN.ENUMS[0..]);
            var unique_enums_len: u32 = @intCast(IN.ENUMS.len);
            SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, OUT.ENUMS[0..]);
            for (def.resources_to_link) |resource| {
                switch (resource) {
                    .UNIFORM_BUFFER => |uniform_name| {
                        const UNI = AnyUniformOrStorageStruct(_UNIFORM_TYPES[@intFromEnum(uniform_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, UNI.ENUMS[0..]);
                    },
                    .STORAGE_BUFFER => |buf_name| {
                        const STORE = AnyUniformOrStorageStruct(_STORAGE_BUFFER_TYPES[@intFromEnum(buf_name)]);
                        SUB_ROUTINE.combine_unique_enums(unique_enums[0..], &unique_enums_len, STORE.ENUMS[0..]);
                    },
                    else => {},
                }
            }
        }
        break :make all_unique_fragment_enums;
    };
    // COMPILE A CONDENSED LIST OF ALLOWED UNIFORMS
    comptime var total_num_allowed_uniforms_vert: u32 = 0;
    comptime var total_num_allowed_uniforms_frag: u32 = 0;
    comptime var uniform_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var uniform_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        uniform_starts_vert[v] = total_num_allowed_uniforms_vert;
        for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_vertex_shaders[v][u].allowed) {
                total_num_allowed_uniforms_vert += 1;
            }
        }
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        uniform_starts_frag[f] = total_num_allowed_uniforms_frag;
        for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_fragment_shaders[f][u].allowed) {
                total_num_allowed_uniforms_frag += 1;
            }
        }
    }
    uniform_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_uniforms_vert;
    uniform_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_uniforms_frag;
    comptime var all_allowed_uniforms_flat_vert: [total_num_allowed_uniforms_vert]_ShaderAllowedUniform = undefined;
    comptime var all_allowed_uniforms_flat_frag: [total_num_allowed_uniforms_frag]_ShaderAllowedUniform = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = uniform_starts_vert[v];
        const end = uniform_starts_vert[v + 1];
        comptime var idx = start;
        for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_vertex_shaders[v][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .uniform = @enumFromInt(@as(Types.enum_tag_type(UNIFORM_NAMES_ENUM), @intCast(u))),
                    .register = vars.uniforms_allowed_in_vertex_shaders[v][u].register,
                };
                all_allowed_uniforms_flat_vert[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_uniforms_flat_vert[start..end], _ShaderAllowedUniform.register_greater);
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = uniform_starts_frag[f];
        const end = uniform_starts_frag[f + 1];
        comptime var idx = start;
        for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_fragment_shaders[f][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .uniform = @enumFromInt(@as(Types.enum_tag_type(UNIFORM_NAMES_ENUM), @intCast(u))),
                    .register = vars.uniforms_allowed_in_fragment_shaders[f][u].register,
                };
                all_allowed_uniforms_flat_frag[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_uniforms_flat_frag[start..end], _ShaderAllowedUniform.register_greater);
    }
    const uniform_starts_vert_const = uniform_starts_vert;
    const uniform_starts_frag_const = uniform_starts_frag;
    const all_allowed_uniforms_flat_vert_const = all_allowed_uniforms_flat_vert;
    const all_allowed_uniforms_flat_frag_const = all_allowed_uniforms_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED STORAGE BUFFERS
    comptime var total_num_allowed_storage_buffers_vert: u32 = 0;
    comptime var total_num_allowed_storage_buffers_frag: u32 = 0;
    comptime var longest_storage_buffer_set_vert: u32 = 1;
    comptime var longest_storage_buffer_set_frag: u32 = 1;
    comptime var storage_buffer_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_buffer_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_buffer_starts_vert[v] = total_num_allowed_storage_buffers_vert;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_buffer_set_vert = @max(longest_storage_buffer_set_vert, num_allowed_this_shader);
        total_num_allowed_storage_buffers_vert += num_allowed_this_shader;
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_buffer_starts_frag[f] = total_num_allowed_storage_buffers_frag;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_fragment_shaders[f][sb].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_buffer_set_frag = @max(longest_storage_buffer_set_frag, num_allowed_this_shader);
        total_num_allowed_storage_buffers_frag += num_allowed_this_shader;
    }
    storage_buffer_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_storage_buffers_vert;
    storage_buffer_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_storage_buffers_frag;
    comptime var all_allowed_storage_buffers_flat_vert: [total_num_allowed_storage_buffers_vert]_ShaderAllowedStorageBuffer = undefined;
    comptime var all_allowed_storage_buffers_flat_frag: [total_num_allowed_storage_buffers_frag]_ShaderAllowedStorageBuffer = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = storage_buffer_starts_vert[v];
        const end = storage_buffer_starts_vert[v + 1];
        comptime var idx = start;
        for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@as(Types.enum_tag_type(STORAGE_BUFFER_NAMES_ENUM), @intCast(sb))),
                    .cpu_register = vars.storage_buffers_allowed_in_vertex_shaders[v][sb].cpu_register,
                    .gpu_register = vars.storage_buffers_allowed_in_vertex_shaders[v][sb].gpu_register,
                };
                all_allowed_storage_buffers_flat_vert[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_storage_buffers_flat_vert[start..end], _ShaderAllowedStorageBuffer.cpu_register_greater);
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = storage_buffer_starts_frag[f];
        const end = storage_buffer_starts_frag[f + 1];
        comptime var idx = start;
        for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_fragment_shaders[f][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@as(Types.enum_tag_type(STORAGE_BUFFER_NAMES_ENUM), @intCast(sb))),
                    .cpu_register = vars.storage_buffers_allowed_in_fragment_shaders[f][sb].cpu_register,
                    .gpu_register = vars.storage_buffers_allowed_in_fragment_shaders[f][sb].gpu_register,
                };
                all_allowed_storage_buffers_flat_frag[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_storage_buffers_flat_frag[start..end], _ShaderAllowedStorageBuffer.cpu_register_greater);
    }
    const longest_storage_buffer_set_frag_const = longest_storage_buffer_set_frag;
    const longest_storage_buffer_set_vert_const = longest_storage_buffer_set_vert;
    const storage_buffer_starts_vert_const = storage_buffer_starts_vert;
    const storage_buffer_starts_frag_const = storage_buffer_starts_frag;
    const all_allowed_storage_buffers_flat_vert_const = all_allowed_storage_buffers_flat_vert;
    const all_allowed_storage_buffers_flat_frag_const = all_allowed_storage_buffers_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED STORAGE TEXTURES
    comptime var total_num_allowed_storage_textures_vert: u32 = 0;
    comptime var total_num_allowed_storage_textures_frag: u32 = 0;
    comptime var longest_storage_texture_set_vert: u32 = 1;
    comptime var longest_storage_texture_set_frag: u32 = 1;
    comptime var storage_texture_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_texture_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_texture_starts_vert[v] = total_num_allowed_storage_textures_vert;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_texture_set_vert = @max(longest_storage_texture_set_vert, num_allowed_this_shader);
        total_num_allowed_storage_textures_vert += num_allowed_this_shader;
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_texture_starts_frag[f] = total_num_allowed_storage_textures_frag;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_fragment_shaders[f][t].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_texture_set_frag = @max(longest_storage_texture_set_frag, num_allowed_this_shader);
        total_num_allowed_storage_textures_frag += num_allowed_this_shader;
    }
    storage_texture_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_storage_textures_vert;
    storage_texture_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_storage_textures_frag;
    comptime var all_allowed_storage_textures_flat_vert: [total_num_allowed_storage_textures_vert]_ShaderAllowedStorageTexture = undefined;
    comptime var all_allowed_storage_textures_flat_frag: [total_num_allowed_storage_textures_frag]_ShaderAllowedStorageTexture = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = storage_texture_starts_vert[v];
        const end = storage_texture_starts_vert[v + 1];
        comptime var idx = start;
        for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                    .cpu_register = vars.storage_textures_allowed_in_vertex_shaders[v][t].cpu_register,
                    .gpu_register = vars.storage_textures_allowed_in_vertex_shaders[v][t].gpu_register,
                };
                all_allowed_storage_textures_flat_vert[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_storage_textures_flat_vert[start..end], _ShaderAllowedStorageTexture.cpu_register_greater);
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = storage_texture_starts_frag[f];
        const end = storage_texture_starts_frag[f + 1];
        comptime var idx = start;
        for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_fragment_shaders[f][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                    .cpu_register = vars.storage_textures_allowed_in_fragment_shaders[f][t].cpu_register,
                    .gpu_register = vars.storage_textures_allowed_in_fragment_shaders[f][t].gpu_register,
                };
                all_allowed_storage_textures_flat_frag[idx] = allowed;
                idx += 1;
            }
        }
        Sort.insertion_sort_with_func(all_allowed_storage_textures_flat_frag[start..end], _ShaderAllowedStorageTexture.cpu_register_greater);
    }
    const longest_storage_texture_set_frag_const = longest_storage_texture_set_frag;
    const longest_storage_texture_set_vert_const = longest_storage_texture_set_vert;
    const storage_texture_starts_vert_const = storage_texture_starts_vert;
    const storage_texture_starts_frag_const = storage_texture_starts_frag;
    const all_allowed_storage_textures_flat_vert_const = all_allowed_storage_textures_flat_vert;
    const all_allowed_storage_textures_flat_frag_const = all_allowed_storage_textures_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED SAMPLER PAIRS
    comptime var total_num_allowed_sample_pairs_vert: u32 = 0;
    comptime var total_num_allowed_sample_pairs_frag: u32 = 0;
    comptime var longest_sample_pair_set_vert: u32 = 1;
    comptime var longest_sample_pair_set_frag: u32 = 1;
    comptime var sample_pair_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var sample_pair_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    for (0.._NUM_VERTEX_SHADERS) |v| {
        sample_pair_starts_vert[v] = total_num_allowed_sample_pairs_vert;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_TEXTURES) |t| {
            for (0.._NUM_SAMPLERS) |s| {
                if (vars.sample_pairs_allowed_in_vertex_shaders[v][t][s].allowed) {
                    num_allowed_this_shader += 1;
                }
            }
        }
        longest_sample_pair_set_vert = @max(longest_sample_pair_set_vert, num_allowed_this_shader);
        total_num_allowed_sample_pairs_vert += num_allowed_this_shader;
    }
    for (0.._NUM_FRAGMENT_SHADERS) |f| {
        sample_pair_starts_frag[f] = total_num_allowed_sample_pairs_frag;
        comptime var num_allowed_this_shader: u32 = 0;
        for (0.._NUM_TEXTURES) |t| {
            for (0.._NUM_SAMPLERS) |s| {
                if (vars.sample_pairs_allowed_in_fragment_shaders[f][t][s].allowed) {
                    num_allowed_this_shader += 1;
                }
            }
        }
        longest_sample_pair_set_frag = @max(longest_sample_pair_set_frag, num_allowed_this_shader);
        total_num_allowed_sample_pairs_frag += num_allowed_this_shader;
    }
    sample_pair_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_sample_pairs_vert;
    sample_pair_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_sample_pairs_frag;
    comptime var all_allowed_sample_pairs_flat_vert: [total_num_allowed_sample_pairs_vert]_ShaderAllowedSamplePair = undefined;
    comptime var all_allowed_sample_pairs_flat_frag: [total_num_allowed_sample_pairs_frag]_ShaderAllowedSamplePair = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = sample_pair_starts_vert[v];
        const end = sample_pair_starts_vert[v + 1];
        comptime var idx = start;
        for (0.._NUM_TEXTURES) |t| {
            for (0.._NUM_SAMPLERS) |s| {
                if (vars.sample_pairs_allowed_in_vertex_shaders[v][t][s].allowed) {
                    const allowed = _ShaderAllowedSamplePair{
                        .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                        .sampler = @enumFromInt(@as(Types.enum_tag_type(SAMPLER_NAMES_ENUM), @intCast(s))),
                        .cpu_register = vars.sample_pairs_allowed_in_vertex_shaders[v][t][s].cpu_register,
                        .gpu_register = vars.sample_pairs_allowed_in_vertex_shaders[v][t][s].gpu_register,
                    };
                    all_allowed_sample_pairs_flat_vert[idx] = allowed;
                    idx += 1;
                }
            }
        }
        Sort.insertion_sort_with_func(all_allowed_sample_pairs_flat_vert[start..end], _ShaderAllowedSamplePair.cpu_register_greater);
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = sample_pair_starts_frag[f];
        const end = sample_pair_starts_frag[f + 1];
        comptime var idx = start;
        for (0.._NUM_TEXTURES) |t| {
            for (0.._NUM_SAMPLERS) |s| {
                if (vars.sample_pairs_allowed_in_fragment_shaders[f][t][s].allowed) {
                    const allowed = _ShaderAllowedSamplePair{
                        .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                        .sampler = @enumFromInt(@as(Types.enum_tag_type(SAMPLER_NAMES_ENUM), @intCast(s))),
                        .cpu_register = vars.sample_pairs_allowed_in_fragment_shaders[f][t][s].cpu_register,
                        .gpu_register = vars.sample_pairs_allowed_in_fragment_shaders[f][t][s].gpu_register,
                    };
                    all_allowed_sample_pairs_flat_frag[idx] = allowed;
                    idx += 1;
                }
            }
        }
        Sort.insertion_sort_with_func(all_allowed_sample_pairs_flat_frag[start..end], _ShaderAllowedSamplePair.cpu_register_greater);
    }
    const longest_sample_pair_set_vert_const = longest_sample_pair_set_vert;
    const longest_sample_pair_set_frag_const = longest_sample_pair_set_frag;
    const sample_pair_starts_vert_const = sample_pair_starts_vert;
    const sample_pair_starts_frag_const = sample_pair_starts_frag;
    const all_allowed_sample_pairs_flat_vert_const = all_allowed_sample_pairs_flat_vert;
    const all_allowed_sample_pairs_flat_frag_const = all_allowed_sample_pairs_flat_frag;
    // VALIDATE RENDER PIPELINES
    const _VERTEX_BUFFER_NAMES_FOR_RENDER_PIPELINE, const _VERTEX_BUFFERS_TO_BIND_FOR_RENDER_PIPELINE, const _VERTEX_ATTRS_TO_BIND_FOR_RENDER_PIPELINE, const _VERTEX_BUFFERS_TO_BIND_START_LOCS, const _VERTEX_ATTRS_TO_BIND_START_LOCS, const _LONGEST_SET_OF_VERTEX_BUFFERS, const _RENDER_PIPELINE_VERT_SHADERS, const _RENDER_PIPELINE_FRAG_SHADERS = comptime make: {
        var total_num_vertex_buffers_to_bind: u32 = 0;
        var total_num_vert_atributes_across_all_pipes: u32 = 0;
        var vertex_buffers_to_bind_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
        var vertex_attribute_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
        var longest_set_of_vertex_buffers: u32 = 0;
        var vert_shaders: [_NUM_RENDER_PIPELINES]VERTEX_SHADER_NAMES_ENUM = undefined;
        var frag_shaders: [_NUM_RENDER_PIPELINES]FRAGMENT_SHADER_NAMES_ENUM = undefined;
        // FIRST PASS ROUGH VALIDATION AND COUNTS
        for (_RENDER_PIPELINE_DEFS, 0..) |pipe_def, pipe_idx| {
            vert_shaders[pipe_idx] = pipe_def.vertex;
            frag_shaders[pipe_idx] = pipe_def.fragment;
            const pipe_name = pipe_def.name;
            const vert_idx = @intFromEnum(pipe_def.vertex);
            const frag_idx = @intFromEnum(pipe_def.fragment);
            const vert_def = _VERTEX_SHADER_DEFS[vert_idx];
            const frag_def = _FRAGMENT_SHADER_DEFS[frag_idx];
            const VERT_IN = AnyVertexShaderInputStruct(_VERTEX_INPUT_STRUCT_TYPES[@intFromEnum(vert_def.input_type)], VERTEX_BUFFER_NAMES_ENUM);
            // const VERT_TO_FRAG = AnyVertexToFragmentStruct(_VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(vert_def.output_type)]);
            const FRAG_OUT = AnyFragmentShaderOutputStruct(_FRAGMENT_OUTPUT_STRUCT_TYPES[@intFromEnum(frag_def.output_type)]);
            assert_with_reason(vert_def.output_type == frag_def.input_type, @src(), "for render pipeline `{s}` the vertex shader output type `{s}` does not match the fragment shader input type `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), @tagName(pipe_def.fragment) });
            assert_with_reason(pipe_def.target_info.num_color_targets == FRAG_OUT.NUM_COLOR_TARGETS, @src(), "for render pipeline `{s}` the fragment shader has {d} color targets, but `target_info.num_color_targets` = {d}", .{ @tagName(pipe_name), FRAG_OUT.NUM_COLOR_TARGETS, pipe_def.target_info.num_color_targets });
            if (pipe_def.target_info.num_color_targets > 0) {
                assert_with_reason(pipe_def.target_info.color_target_descriptions != null, @src(), "for render pipeline `{s}` `target_info.num_color_targets == {d}` but `target_info.color_target_descriptions == null`", .{ @tagName(pipe_name), pipe_def.target_info.num_color_targets });
                for (pipe_def.target_info.color_target_descriptions.?[0..pipe_def.target_info.num_color_targets], 0..) |target, t| {
                    assert_with_reason(!target.format.is_depth_format(), @src(), "for render pipeline `{s}` color target {d}, the texture format is not a COLOR format, got `{s}`", .{ @tagName(pipe_name), t, @tagName(target.format) });
                    assert_with_reason(target.blend_state.none_invalid_if_option_enabled(), @src(), "for render pipeline `{s}` color target {d}, `blend_state` options are enabled, but have one or more `.INVALID` modes or a blank color write mask", .{ @tagName(pipe_name), t });
                }
            }
            assert_with_reason(pipe_def.target_info.has_depth_stencil_target == FRAG_OUT.HAS_DEPTH_OUTPUT, @src(), "for render pipeline `{s}` the depth buffer enable setting `{any}` does not match the fragment shader `{s}` depth target state `{any}`", .{ @tagName(pipe_name), pipe_def.target_info.has_depth_stencil_target, @tagName(pipe_def.fragment), FRAG_OUT.HAS_DEPTH_OUTPUT });
            if (pipe_def.target_info.has_depth_stencil_target) {
                assert_with_reason(pipe_def.target_info.depth_stencil_format.is_depth_format(), @src(), "for render pipeline `{s}`, `target_info.has_depth_stencil_target == true` but the `target_info.depth_stencil_format` is is not a depth format, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
                assert_with_reason(!pipe_def.depth_stencil_options.enable_depth_test or pipe_def.depth_stencil_options.compare_op != .INVALID, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_depth_test == true` while `depth_stencil_options.compare_op == .INVALID`", .{@tagName(pipe_name)});
                assert_with_reason(!pipe_def.depth_stencil_options.enable_stencil_test or (pipe_def.depth_stencil_options.back_stencil_state.none_invalid() and pipe_def.depth_stencil_options.front_stencil_state.none_invalid()), @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while either `depth_stencil_options.front_stencil_state` or `depth_stencil_options.back_stencil_state` has `.INVALID` entries", .{@tagName(pipe_name)});
                if (pipe_def.depth_stencil_options.enable_stencil_test) {
                    assert_with_reason(pipe_def.target_info.depth_stencil_format.has_depth_stencil(), @src(), "for render pipeline `{s}`, `depth_stencil_options.enable_stencil_test == true` but the `target_info.depth_stencil_format` is does not have a stencil, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
                }
                if (pipe_def.depth_stencil_options.enable_stencil_test) {
                    assert_with_reason(pipe_def.depth_stencil_options.compare_mask != 0 and pipe_def.depth_stencil_options.write_mask != 0, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while `depth_stencil_options.write_mask` or `depth_stencil_options.compare_mask` equal zero (in effect no depth stencil will be compared or written)", .{@tagName(pipe_name)});
                }
            }
            vertex_buffers_to_bind_start_locs[pipe_idx] = total_num_vertex_buffers_to_bind;
            vertex_attribute_start_locs[pipe_idx] = total_num_vert_atributes_across_all_pipes;

            longest_set_of_vertex_buffers = @max(longest_set_of_vertex_buffers, VERT_IN.NUM_BUFFER_SLOTS);
            total_num_vertex_buffers_to_bind += VERT_IN.NUM_BUFFER_SLOTS;
            total_num_vert_atributes_across_all_pipes += VERT_IN.NUM_ATTRIBUTES;
        }
        vertex_buffers_to_bind_start_locs[_NUM_RENDER_PIPELINES] = total_num_vertex_buffers_to_bind;
        vertex_attribute_start_locs[_NUM_RENDER_PIPELINES] = total_num_vert_atributes_across_all_pipes;
        var vertex_buffer_names_to_bind_per_render_pipeline: [total_num_vertex_buffers_to_bind]VERTEX_BUFFER_NAMES_ENUM = undefined;
        var vertex_buffers_to_bind_per_render_pipeline: [total_num_vertex_buffers_to_bind]SDL3.GPU_VertexBufferDescription = undefined;
        var vertex_attributes_to_bind_per_render_pipeline: [total_num_vert_atributes_across_all_pipes]SDL3.GPU_VertexAttribute = undefined;
        // SECOND PASS FILL RUNTIME BUFFERS
        for (_RENDER_PIPELINE_DEFS, 0..) |pipe_def, pipe_idx| {
            const vert_idx = @intFromEnum(pipe_def.vertex);
            const vert_def = _VERTEX_SHADER_DEFS[vert_idx];
            const VERT_IN = AnyVertexShaderInputStruct(_VERTEX_INPUT_STRUCT_TYPES[@intFromEnum(vert_def.input_type)], VERTEX_BUFFER_NAMES_ENUM);
            const bufs_start = vertex_buffers_to_bind_start_locs[pipe_idx];
            const bufs_end = vertex_buffers_to_bind_start_locs[pipe_idx + 1];
            const attrs_start = vertex_attribute_start_locs[pipe_idx];
            const attrs_end = vertex_attribute_start_locs[pipe_idx + 1];
            const V_IN_ATTRS = VERT_IN.get_sdl_vertex_attributes();
            @memcpy(vertex_attributes_to_bind_per_render_pipeline[attrs_start..attrs_end], V_IN_ATTRS[0..]);
            const V_IN_BUFS = VERT_IN.get_sdl_vertex_buffer_descriptions();
            @memcpy(vertex_buffers_to_bind_per_render_pipeline[bufs_start..bufs_end], V_IN_BUFS[0..]);
            @memcpy(vertex_buffer_names_to_bind_per_render_pipeline[bufs_start..bufs_end], VERT_IN.ACTIVE_SLOT_NAMES[0..]);
        }
        break :make .{ vertex_buffer_names_to_bind_per_render_pipeline, vertex_buffers_to_bind_per_render_pipeline, vertex_attributes_to_bind_per_render_pipeline, vertex_buffers_to_bind_start_locs, vertex_attribute_start_locs, longest_set_of_vertex_buffers, vert_shaders, frag_shaders };
    };
    return struct {
        const Controller = @This();

        /// USER ACCESS ALLOWED
        gpu: *GPU_Device = @ptrFromInt(INVALID_ADDR),
        /// USER ACCESS NOT RECOMMENDED
        windows: [INTERNAL.NUM_WINDOWS]*Window = @splat(Utils.invalid_ptr(Window)),
        /// USER ACCESS NOT RECOMMENDED
        windows_init: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        windows_claimed: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        swapchain_cache: [INTERNAL.NUM_WINDOWS]GPU_SwapchainTexture = undefined,
        /// USER ACCESS NOT RECOMMENDED
        swapchain_is_cached: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        render_pipelines_init: [INTERNAL.NUM_RENDER_PIPELINES]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        render_pipelines: [INTERNAL.NUM_RENDER_PIPELINES]*GPU_GraphicsPipeline = @splat(Utils.invalid_ptr(GPU_GraphicsPipeline)),
        /// USER ACCESS NOT RECOMMENDED
        current_render_pipeline: RenderPipelineName = undefined,
        /// USER ACCESS NOT RECOMMENDED
        textures: [INTERNAL.NUM_TEXTURES]*GPU_Texture = @splat(Utils.invalid_ptr(GPU_Texture)),
        /// USER ACCESS NOT RECOMMENDED
        textures_init: [INTERNAL.NUM_TEXTURES]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        textures_sizes: [INTERNAL.NUM_TEXTURES]Vec3(u32) = @splat(Vec3(u32).ZERO),
        /// USER ACCESS NOT RECOMMENDED
        upload_buffers: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(Utils.invalid_ptr(GPU_TransferBuffer)),
        /// USER ACCESS NOT RECOMMENDED
        upload_buffers_init: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        upload_buffer_byte_caps: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        upload_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        download_buffers: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(Utils.invalid_ptr(GPU_TransferBuffer)),
        /// USER ACCESS NOT RECOMMENDED
        download_buffers_init: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        download_buffer_byte_caps: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        download_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        vertex_buffers: [INTERNAL.NUM_VERTEX_BUFFERS]*GPU_Buffer = @splat(Utils.invalid_ptr(GPU_Buffer)),
        /// USER ACCESS NOT RECOMMENDED
        vertex_buffers_init: [INTERNAL.NUM_VERTEX_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        vertex_buffer_byte_caps: [INTERNAL.NUM_VERTEX_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        vertex_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        storage_buffers: [INTERNAL.NUM_STORAGE_BUFFERS]*GPU_Buffer = @splat(Utils.invalid_ptr(GPU_Buffer)),
        /// USER ACCESS NOT RECOMMENDED
        storage_buffers_init: [INTERNAL.NUM_STORAGE_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        storage_buffer_byte_caps: [INTERNAL.NUM_STORAGE_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        storage_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        samplers: [INTERNAL.NUM_SAMPLERS]*GPU_TextureSampler = @splat(Utils.invalid_ptr(GPU_TextureSampler)),
        /// USER ACCESS NOT RECOMMENDED
        samplers_init: [INTERNAL.NUM_SAMPLERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        fences: [INTERNAL.NUM_FENCES]*GPU_Fence = @splat(Utils.invalid_ptr(GPU_Fence)),
        /// USER ACCESS NOT RECOMMENDED
        fences_init: [INTERNAL.NUM_FENCES]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        index_buffers: [INTERNAL.NUM_INDEX_BUFFERS]*GPU_Buffer = @splat(Utils.invalid_ptr(GPU_Buffer)),
        /// USER ACCESS NOT RECOMMENDED
        index_buffers_init: [INTERNAL.NUM_INDEX_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        index_buffer_byte_caps: [INTERNAL.NUM_INDEX_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        index_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        indirect_draw_buffers: [INTERNAL.NUM_INDIRECT_BUFFERS]*GPU_Buffer = @splat(Utils.invalid_ptr(GPU_Buffer)),
        /// USER ACCESS NOT RECOMMENDED
        indirect_draw_buffers_init: [INTERNAL.NUM_INDIRECT_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        indirect_draw_buffer_byte_caps: [INTERNAL.NUM_INDIRECT_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        indirect_draw_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
        /// USER ACCESS NOT RECOMMENDED
        mapped_upload_buffers: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        upload_slices: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS][]u8 = @splat(Utils.invalid_slice(u8)),
        /// USER ACCESS NOT RECOMMENDED
        upload_bytes_written: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        /// USER ACCESS NOT RECOMMENDED
        mapped_download_buffers: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        /// USER ACCESS NOT RECOMMENDED
        download_slices: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS][]const u8 = @splat(Utils.invalid_slice_const(u8)),
        /// USER ACCESS NOT RECOMMENDED
        download_bytes_read: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        /// USER ACCESS ALLOWED
        cycle_unmapped_upload_buffers: bool = true,
        /// USER ACCESS ALLOWED
        uniforms: UniformCollection = undefined,
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        list_alloc: Allocator = DummyAlloc.allocator_panic,
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        upload_list: List(CopyUploadDetails) = .{},
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        download_list: List(CopyDownloadDetails) = .{},
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        grow_and_copy_gpu_buffer_list: List(GrowAndCopyGPUBufferDetails) = .{},
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        grow_and_copy_download_transfer_list: List(GrowAndCopyDownloadTransferDetails) = .{},
        /// USER ACCESS NOT RECOMMENDED (except to initialize)
        release_buffers_list: List(DeleteBufferDetails) = .{},
        /// USER ACCESS NOT RECOMMENDED
        sdl_copy_pass: *SDL3.GPU_CopyPass = undefined,
        /// USER ACCESS NOT RECOMMENDED
        sdl_cmd_buf: *SDL3.GPU_CommandBuffer = undefined,
        /// USER ACCESS NOT RECOMMENDED
        sdl_render_pass: *SDL3.GPU_RenderPass = undefined,
        /// USER ACCESS NOT RECOMMENDED
        download_occured: bool = false,
        /// USER ACCESS NOT RECOMMENDED
        index_buffer_bound: bool = false,
        /// USER ACCESS NOT RECOMMENDED
        bound_index_buffer: IndexBufferName = undefined,
        /// USER ACCESS NOT RECOMMENDED
        previous_gpu_fence: ?*GPU_Fence = null,
        /// USER ACCESS NOT RECOMMENDED
        stage: LifeCycle = .UNINITIALIZED,

        fn goo_cmd_buf(self: *Controller) CommandBuffer {
            return CommandBuffer{ .controller = self };
        }
        fn goo_render_pass(self: *Controller) RenderPass {
            return RenderPass{ .controller = self };
        }
        fn goo_download_pass(self: *Controller) DownloadPass {
            return DownloadPass{ .controller = self };
        }

        pub inline fn get_window(self: *const Controller, name: WindowName) *Window {
            assert_with_reason(self.windows_init[@intFromEnum(name)], @src(), "window `{s}` not initialized", .{@tagName(name)});
            return self.windows[@intFromEnum(name)];
        }
        pub inline fn get_claimed_window(self: *const Controller, name: WindowName) *Window {
            assert_with_reason(self.windows_init[@intFromEnum(name)], @src(), "window `{s}` not initialized", .{@tagName(name)});
            assert_with_reason(self.windows_claimed[@intFromEnum(name)], @src(), "window `{s}` not claimed (no swapchain texture)", .{@tagName(name)});
            return self.windows[@intFromEnum(name)];
        }
        pub inline fn get_render_pipeline(self: *const Controller, name: RenderPipelineName) *GPU_GraphicsPipeline {
            assert_with_reason(self.render_pipelines_init[@intFromEnum(name)], @src(), "render pipeline `{s}` not initialized", .{@tagName(name)});
            return self.render_pipelines[@intFromEnum(name)];
        }
        pub inline fn get_texture(self: *const Controller, name: TextureName) *GPU_Texture {
            assert_with_reason(self.textures_init[@intFromEnum(name)], @src(), "texture `{s}` not initialized", .{@tagName(name)});
            return self.textures[@intFromEnum(name)];
        }
        pub inline fn get_upload_transfer_buffer(self: *const Controller, name: UploadBufferName) *GPU_TransferBuffer {
            assert_with_reason(self.upload_buffers_init[@intFromEnum(name)], @src(), "upload transfer buffer `{s}` not initialized", .{@tagName(name)});
            return self.upload_buffers[@intFromEnum(name)];
        }
        pub inline fn get_download_transfer_buffer(self: *const Controller, name: DownloadBufferName) *GPU_TransferBuffer {
            assert_with_reason(self.download_buffers_init[@intFromEnum(name)], @src(), "download transfer buffer `{s}` not initialized", .{@tagName(name)});
            return self.download_buffers[@intFromEnum(name)];
        }
        pub inline fn get_storage_buffer(self: *const Controller, name: StorageBufferName) *GPU_Buffer {
            assert_with_reason(self.storage_buffers_init[@intFromEnum(name)], @src(), "storage buffer `{s}` not initialized", .{@tagName(name)});
            return self.storage_buffers[@intFromEnum(name)];
        }
        pub inline fn get_vertex_buffer(self: *const Controller, name: VertexBufferName) *GPU_Buffer {
            assert_with_reason(self.vertex_buffers_init[@intFromEnum(name)], @src(), "vertex buffer `{s}` not initialized", .{@tagName(name)});
            return self.vertex_buffers[@intFromEnum(name)];
        }
        pub inline fn get_sampler(self: *const Controller, name: SamplerName) *GPU_TextureSampler {
            assert_with_reason(self.samplers_init[@intFromEnum(name)], @src(), "sampler `{s}` not initialized", .{@tagName(name)});
            return self.samplers[@intFromEnum(name)];
        }
        pub inline fn get_fence(self: *const Controller, name: FenceName) *GPU_Fence {
            assert_with_reason(self.fences_init[@intFromEnum(name)], @src(), "fence `{s}` not initialized", .{@tagName(name)});
            return self.fences[@intFromEnum(name)];
        }
        pub inline fn get_index_buffer(self: *const Controller, name: IndexBufferName) *GPU_Buffer {
            assert_with_reason(self.index_buffers_init[@intFromEnum(name)], @src(), "index buffer `{s}` not initialized", .{@tagName(name)});
            return self.index_buffers[@intFromEnum(name)];
        }
        pub inline fn get_indirect_draw_buffer(self: *const Controller, name: IndirectDrawBufferName) *GPU_Buffer {
            assert_with_reason(INTERNAL.HAS_INDIRECT_BUFS, @src(), "no indirect dra buffers defined", .{});
            assert_with_reason(self.indirect_draw_buffers_init[@intFromEnum(name)], @src(), "indirect draw buffer `{s}` not initialized", .{@tagName(name)});
            return self.indirect_draw_buffers[@intFromEnum(name)];
        }
        pub inline fn get_uniform_ptr(self: *Controller, comptime name: UniformName) *@FieldType(UniformCollection, @tagName(name)) {
            return &@field(self.uniforms, @tagName(name));
        }
        pub inline fn get_uniform_ptr_const(self: *const Controller, comptime name: UniformName) *const @FieldType(UniformCollection, @tagName(name)) {
            return &@field(self.uniforms, @tagName(name));
        }

        fn point_is_within_target(self: *Controller, tex: TextureName, point: Vec3(u32)) bool {
            const tex_idx = @intFromEnum(tex);
            const size = self.textures_sizes[tex_idx];
            return point.x < size.x and point.y < size.y and point.z < size.z;
        }

        pub fn get_window_texture_format(self: *Controller, window: WindowName) GPU_TextureFormat {
            return self.gpu.get_swapchain_texture_format(self.get_claimed_window(window));
        }

        fn clean_up_after_command_submission(self: *Controller) void {
            for (self.release_buffers_list.zig_slice_entire()) |to_release| {
                self.gpu.release_buffer(to_release.buf);
            }
            self.release_buffers_list.clear();
            self.swapchain_is_cached = @splat(false);
        }

        pub fn wait_for_previous_gpu_fence(self: *Controller) !void {
            self.stage.assert(.WAITING_FOR_GPU_COMPLETION_FENCE, @src());
            if (self.previous_gpu_fence) |fence| {
                const fence_arr = [1]*GPU_Fence{fence};
                try self.gpu.wait_for_gpu_fences(true, fence_arr[0..]);
                self.gpu.release_fence(fence);
                self.previous_gpu_fence = null;
            }
            for (self.download_list.zig_slice_entire()) |dl| {
                const dest_slice = dl.dest;
                const dl_transfer_buf_end_excluded = dl.transfer_buf_offset + dl.transfer_buf_len;
                const source_slice: []const u8 = try self.goo_download_pass().get_download_slice(dl.transfer_buf, dl.transfer_buf_offset, dl_transfer_buf_end_excluded);
                @memcpy(dest_slice[0..source_slice.len], source_slice);
            }
            self.download_list.clear();
            for (self.mapped_download_buffers[0..], 0..) |mapped, i| {
                if (mapped) {
                    self.gpu.unmap_transfer_buffer(self.download_buffers[i]);
                    self.mapped_download_buffers[i] = false;
                    self.download_slices[i] = &.{};
                    self.download_bytes_read[i] = 0;
                }
            }
            self.stage = .READY_FOR_NEXT_COMMAND_CYCLE;
        }
        pub fn wait_for_previous_gpu_fence_if_any(self: *Controller) !void {
            if (self.stage == .WAITING_FOR_GPU_COMPLETION_FENCE) {
                try self.wait_for_previous_gpu_fence();
            }
        }

        pub const Fence = union(FenceKind) {
            NAMED: FenceName,
            DIRECT: *GPU_Fence,

            pub fn named_fence(name: FenceName) Fence {
                return Fence{ .NAMED = name };
            }
            pub fn direct_fence(fence: *GPU_Fence) Fence {
                return Fence{ .DIRECT = fence };
            }
            pub fn wait(self: Fence, controller: *Controller) !void {
                const fence: [1]*GPU_Fence = .{switch (self) {
                    .NAMED => |n| controller.get_fence(n),
                    .DIRECT => |f| f,
                }};
                try controller.gpu.wait_for_gpu_fences(true, fence[0..1]);
            }
        };

        pub const Target = union(TargetKind) {
            WINDOW: WindowName,
            TEXTURE: TextureName,

            pub fn window(win: WindowName) Target {
                return Target{ .WINDOW = win };
            }
            pub fn texture(tex: TextureName) Target {
                return Target{ .TEXTURE = tex };
            }

            pub fn tag_name(self: Target) []const u8 {
                return switch (self) {
                    .TEXTURE => |t| @tagName(t),
                    .WINDOW => |w| @tagName(w),
                };
            }

            pub fn get_texture(self: Target, controller: *Controller) !?*GPU_Texture {
                return switch (self) {
                    .TEXTURE => |t| controller.get_texture(t),
                    .WINDOW => |w| try controller.goo_cmd_buf().wait_and_get_swapchain_texture_for_window(w),
                };
            }
        };

        pub const ColorTarget = struct {
            target: Target,
            mip_level: u32 = 0,
            layer_or_depth_plane: u32 = 0,
            clear_color: Vec4(f32) = .new_rgba(0, 0, 0, 1),
            load_op: SDL3.GPU_LoadOp = .LOAD,
            store_op: SDL3.GPU_StoreOp = .STORE,
            resolve_target: ?Target = null,
            resolve_mip_level: u32 = 0,
            resolve_layer: u32 = 0,
            cycle: bool = false,
            cycle_resolve_texture: bool = false,

            pub fn to_sdl(self: ColorTarget, controller: *Controller) !SDL3.GPU_ColorTargetInfo {
                return SDL3.GPU_ColorTargetInfo{
                    .texture = try self.target.get_texture(controller),
                    .mip_level = self.mip_level,
                    .clear_color = @bitCast(self.clear_color),
                    .load_op = self.load_op,
                    .store_op = self.store_op,
                    .resolve_texture = if (self.resolve_target) |res_target| try res_target.get_texture(controller) else null,
                    .layer_or_depth_plane = self.layer_or_depth_plane,
                    .resolve_layer = self.resolve_layer,
                    .resolve_mip_level = self.resolve_mip_level,
                    .cycle = self.cycle,
                    .cycle_resolve_texture = self.cycle_resolve_texture,
                };
            }
        };

        pub const DepthTarget = struct {
            texture: ?TextureName = null,
            clear_depth: f32 = 0,
            load_op: SDL3.GPU_LoadOp = .LOAD,
            store_op: SDL3.GPU_StoreOp = .STORE,
            stencil_load_op: SDL3.GPU_LoadOp = .LOAD,
            stencil_store_op: SDL3.GPU_StoreOp = .STORE,
            cycle: bool = false,
            clear_stencil: u8 = 0,

            pub fn no_depth_target() DepthTarget {
                return DepthTarget{};
            }

            pub fn to_sdl(self: DepthTarget, controller: *const Controller) SDL3.GPU_DepthStencilTargetInfo {
                return SDL3.GPU_DepthStencilTargetInfo{
                    .texture = if (self.texture) |t| controller.get_texture(t) else null,
                    .clear_depth = self.clear_depth,
                    .load_op = self.load_op,
                    .store_op = self.store_op,
                    .stencil_load_op = self.stencil_load_op,
                    .stencil_store_op = self.stencil_store_op,
                    .clear_stencil = self.clear_stencil,
                    .cycle = self.cycle,
                };
            }
        };

        pub const VertexBufferBindingOffset = struct {
            buffer: VertexBufferName,
            data_offset: u32,

            pub fn vertex_buffer_binding(buffer: VertexBufferName, offset: u32) VertexBufferBindingOffset {
                return VertexBufferBindingOffset{
                    .buffer = buffer,
                    .data_offset = offset,
                };
            }
        };

        pub const BlitRegion = struct {
            target: Target,
            mip_level: u32 = 0,
            layer_or_depth_plane: u32 = 0,
            pos: Vec2(u32) = .ZERO,
            size: Vec2(u32) = .ZERO,

            pub fn to_sdl(self: BlitRegion, controller: *Controller) !GPU_BlitRegion {
                return GPU_BlitRegion{
                    .texture = try self.target.get_texture(controller),
                    .mip_level = self.mip_level,
                    .layer_or_depth_plane = self.layer_or_depth_plane,
                    .x = self.pos.x,
                    .y = self.pos.y,
                    .w = self.size.x,
                    .h = self.size.y,
                };
            }
        };

        pub const BlitInfo = struct {
            source: BlitRegion,
            destination: BlitRegion,
            load_op: SDL3.GPU_LoadOp = .LOAD,
            clear_color: Vec4(f32) = .new_any_rgba(0, 0, 0, 1),
            flip_mode: SDL3.FlipMode = .NONE,
            filter: GPU_FilterMode = .LINEAR,
            cycle: bool = false,

            pub fn to_sdl(self: BlitInfo, controller: *Controller) !GPU_BlitInfo {
                return GPU_BlitInfo{
                    .source = try self.source.to_sdl(controller),
                    .destination = try self.destination.to_sdl(controller),
                    .clear_color = @bitCast(self.clear_color),
                    .load_op = self.load_op,
                    .filter = self.filter,
                    .flip_mode = self.flip_mode,
                    .cycle = self.cycle,
                };
            }
        };

        pub const TextureUploadInfo = struct {
            transfer_buffer: UploadBufferName,
            offset: u32 = 0,
            pixels_per_row: u32 = 0,
            rows_per_layer: u32 = 0,

            pub fn texture_upload_info(buffer: UploadBufferName, offset: u32, pixels_per_row: u32, rows_per_layer: u32) TextureUploadInfo {
                return TextureUploadInfo{
                    .transfer_buffer = buffer,
                    .offset = offset,
                    .pixels_per_row = pixels_per_row,
                    .rows_per_layer = rows_per_layer,
                };
            }

            pub fn to_sdl(self: TextureUploadInfo, controller: *const Controller) GPU_TextureTransferInfo {
                return GPU_TextureTransferInfo{
                    .transfer_buffer = controller.get_upload_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                    .pixels_per_row = self.pixels_per_row,
                    .rows_per_layer = self.rows_per_layer,
                };
            }
        };

        pub const TextureDownloadInfo = struct {
            transfer_buffer: DownloadBufferName,
            offset: u32 = 0,
            pixels_per_row: u32 = 0,
            rows_per_layer: u32 = 0,

            pub fn texture_download_info(buffer: DownloadBufferName, offset: u32, pixels_per_row: u32, rows_per_layer: u32) TextureDownloadInfo {
                return TextureDownloadInfo{
                    .transfer_buffer = buffer,
                    .offset = offset,
                    .pixels_per_row = pixels_per_row,
                    .rows_per_layer = rows_per_layer,
                };
            }

            pub fn to_sdl(self: TextureDownloadInfo, controller: *const Controller) GPU_TextureTransferInfo {
                return GPU_TextureTransferInfo{
                    .transfer_buffer = controller.get_download_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                    .pixels_per_row = self.pixels_per_row,
                    .rows_per_layer = self.rows_per_layer,
                };
            }
        };

        pub const UploadTransferBufferLocation = struct {
            transfer_buffer: UploadBufferName,
            offset: u32 = 0,

            pub fn upload_buffer_loc(name: UploadBufferName, offset: u32) UploadTransferBufferLocation {
                return UploadTransferBufferLocation{
                    .transfer_buffer = name,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: UploadTransferBufferLocation, controller: *const Controller) GPU_TransferBufferLocation {
                return GPU_TransferBufferLocation{
                    .transfer_buffer = controller.get_upload_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                };
            }
        };

        pub const CopyUploadDetails = struct {
            dest: GPUAssetRegion,
            transfer_buf: UploadBufferName,
            transfer_buf_offset: u32,
            transfer_buf_len: u32,
        };

        pub const QueuedDownloadCopy = union(CopyKind) {
            BUFFER: struct {
                from: BufferRegion,
                to: DownloadTransferBufferLocation,
            },
            TEXTURE: struct {
                from: TextureRegion,
                to: TextureDownloadInfo,
            },
        };

        pub const CopyDownloadDetails = struct {
            dest: []u8,
            queued_copy: QueuedDownloadCopy,
            transfer_buf: DownloadBufferName,
            transfer_buf_offset: u32,
            transfer_buf_len: u32,
        };

        pub const DownloadTransferBufferLocation = struct {
            transfer_buffer: DownloadBufferName,
            offset: u32 = 0,

            pub fn download_buffer_loc(name: DownloadBufferName, offset: u32) DownloadTransferBufferLocation {
                return DownloadTransferBufferLocation{
                    .transfer_buffer = name,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: DownloadTransferBufferLocation, controller: *const Controller) GPU_TransferBufferLocation {
                return GPU_TransferBufferLocation{
                    .transfer_buffer = controller.get_download_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                };
            }
        };

        pub const AnyGPUBuffer = union(GPUBufferKind) {
            STORAGE: StorageBufferName,
            VERTEX: VertexBufferName,
            INDEX: IndexBufferName,
            INDIRECT: IndirectDrawBufferName,

            pub fn storage_buffer(name: StorageBufferName) AnyGPUBuffer {
                return AnyGPUBuffer{ .STORAGE = name };
            }
            pub fn vertex_buffer(name: VertexBufferName) AnyGPUBuffer {
                return AnyGPUBuffer{ .VERTEX = name };
            }
            pub fn index_buffer(name: IndexBufferName) AnyGPUBuffer {
                return AnyGPUBuffer{ .INDEX = name };
            }
            pub fn indirect_draw_buffer(name: IndirectDrawBufferName) AnyGPUBuffer {
                return AnyGPUBuffer{ .INDIRECT = name };
            }

            pub fn get_buffer(self: AnyGPUBuffer, controller: *const Controller) *GPU_Buffer {
                return switch (self) {
                    .STORAGE => |name| controller.get_storage_buffer(name),
                    .VERTEX => |name| controller.get_vertex_buffer(name),
                    .INDEX => |name| controller.get_index_buffer(name),
                    .INDIRECT => |name| controller.get_indirect_draw_buffer(name),
                };
            }
        };

        pub const GPUAssetRegion = union(GPUAssetKind) {
            STORAGE_BUF: struct {
                name: StorageBufferName,
                offset: u32,
                size: u32,
            },
            VERTEX_BUF: struct {
                name: VertexBufferName,
                offset: u32,
                size: u32,
            },
            INDEX_BUF: struct {
                name: IndexBufferName,
                offset: u32,
                size: u32,
            },
            INDIRECT_BUF: struct {
                name: IndirectDrawBufferName,
                offset: u32,
                size: u32,
            },
            TEXTURE: struct {
                target: Target,
                mip_level: u32 = 0,
                layer: u32 = 0,
                pos: Vec3(u32),
                size: Vec3(u32),
            },

            pub fn storage_buffer(name: StorageBufferName, offset: u32, size: u32) GPUAssetRegion {
                return GPUAssetRegion{ .STORAGE_BUF = .{
                    .name = name,
                    .offset = offset,
                    .size = size,
                } };
            }
            pub fn vertex_buffer(name: VertexBufferName, offset: u32, size: u32) GPUAssetRegion {
                return GPUAssetRegion{ .VERTEX_BUF = .{
                    .name = name,
                    .offset = offset,
                    .size = size,
                } };
            }
            pub fn index_buffer(name: IndexBufferName, offset: u32, size: u32) GPUAssetRegion {
                return GPUAssetRegion{ .INDEX_BUF = .{
                    .name = name,
                    .offset = offset,
                    .size = size,
                } };
            }
            pub fn indirect_draw_buffer(name: IndirectDrawBufferName, offset: u32, size: u32) GPUAssetRegion {
                return GPUAssetRegion{ .INDIRECT_BUF = .{
                    .name = name,
                    .offset = offset,
                    .size = size,
                } };
            }
            pub fn texture(name: TextureName, pos: Vec3(u32), size: Vec3(u32), mip_level: u32, layer: u32) GPUAssetRegion {
                return GPUAssetRegion{ .TEXTURE = .{
                    .target = Target{ .TEXTURE = name },
                    .pos = pos,
                    .size = size,
                    .mip_level = mip_level,
                    .layer = layer,
                } };
            }
            pub fn window_swap_texture(name: WindowName, pos: Vec3(u32), size: Vec3(u32), mip_level: u32, layer: u32) GPUAssetRegion {
                return GPUAssetRegion{ .TEXTURE = .{
                    .target = Target{ .WINDOW = name },
                    .pos = pos,
                    .size = size,
                    .mip_level = mip_level,
                    .layer = layer,
                } };
            }
        };

        pub const BufferRegion = struct {
            buffer: AnyGPUBuffer,
            offset: u32 = 0,
            size: u32 = 0,

            pub fn buffer_region(buffer: AnyGPUBuffer, offset: u32, size: u32) BufferRegion {
                return BufferRegion{
                    .buffer = buffer,
                    .offset = offset,
                    .size = size,
                };
            }

            pub fn to_sdl(self: BufferRegion, controller: *const Controller) GPU_BufferRegion {
                return GPU_BufferRegion{
                    .buffer = self.buffer.get_buffer(controller),
                    .offset = self.offset,
                    .size = self.size,
                };
            }
        };

        pub const BufferLocation = struct {
            buffer: AnyGPUBuffer,
            offset: u32 = 0,

            pub fn buffer_location(buffer: AnyGPUBuffer, offset: u32) BufferLocation {
                return BufferLocation{
                    .buffer = buffer,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: BufferLocation, controller: *const Controller) GPU_BufferLocation {
                return GPU_BufferLocation{
                    .buffer = self.buffer.get_buffer(controller),
                    .offset = self.offset,
                };
            }
        };

        pub const TextureRegion = struct {
            target: Target,
            mip_level: u32 = 0,
            layer: u32 = 0,
            pos: Vec3(u32) = .ZERO,
            size: Vec3(u32) = .ZERO,

            pub fn texture_region(target: Target, mip_level: u32, layer: u32, pos: Vec3(u32), size: Vec3(u32)) TextureRegion {
                return TextureRegion{
                    .target = target,
                    .mip_level = mip_level,
                    .layer = layer,
                    .pos = pos,
                    .size = size,
                };
            }

            pub fn to_sdl(self: TextureRegion, controller: *Controller) !GPU_TextureRegion {
                return GPU_TextureRegion{
                    .texture = try self.target.get_texture(controller),
                    .mip_level = self.mip_level,
                    .layer = self.layer,
                    .x = self.pos.x,
                    .y = self.pos.y,
                    .z = self.pos.z,
                    .w = self.size.x,
                    .h = self.size.y,
                    .d = self.size.z,
                };
            }
        };

        pub const TextureLocation = struct {
            target: Target,
            mip_level: u32 = 0,
            layer: u32 = 0,
            pos: Vec3(u32) = .ZERO,

            pub fn texture_location(target: Target, mip_level: u32, layer: u32, pos: Vec3(u32)) TextureLocation {
                return TextureLocation{
                    .target = target,
                    .mip_level = mip_level,
                    .layer = layer,
                    .pos = pos,
                };
            }

            pub fn to_sdl(self: TextureLocation, controller: *Controller) GPU_TextureLocation {
                return GPU_TextureLocation{
                    .texture = self.target.get_texture(controller),
                    .layer = self.layer,
                    .mip_level = self.mip_level,
                    .x = self.pos.x,
                    .y = self.pos.y,
                    .z = self.pos.z,
                };
            }
        };
        fn assert_no_downloads_occured_for_submit(self: *const Controller, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!self.download_occured, src, "no download must have occured during the command buffer when calling this function", .{});
        }
        fn assert_window_initialized(self: *const Controller, name: WindowName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.windows_init[@intFromEnum(name)] == true, src, "window `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_window_NOT_initialized(self: *const Controller, name: WindowName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.windows_init[@intFromEnum(name)] == false, src, "window `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_window_claimed(self: *const Controller, name: WindowName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.windows_claimed[@intFromEnum(name)] == true, src, "window `{s}` was not claimed", .{@tagName(name)});
        }
        fn assert_window_NOT_claimed(self: *const Controller, name: WindowName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.windows_claimed[@intFromEnum(name)] == false, src, "window `{s}` was already claimed", .{@tagName(name)});
        }
        fn assert_vert_buffer_initialized(self: *const Controller, name: VertexBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.vertex_buffers_init[@intFromEnum(name)] == true, src, "vertex buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_vert_buffer_NOT_initialized(self: *const Controller, name: VertexBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.vertex_buffers_init[@intFromEnum(name)] == false, src, "vertex buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_storage_buffer_initialized(self: *const Controller, name: StorageBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.storage_buffers_init[@intFromEnum(name)] == true, src, "storage buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_storage_buffer_NOT_initialized(self: *const Controller, name: StorageBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.storage_buffers_init[@intFromEnum(name)] == false, src, "storage buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_index_buffer_initialized(self: *const Controller, name: IndexBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.index_buffers_init[@intFromEnum(name)] == true, src, "index buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_index_buffer_NOT_initialized(self: *const Controller, name: IndexBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.index_buffers_init[@intFromEnum(name)] == false, src, "index buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_indirect_buffer_initialized(self: *const Controller, name: IndirectDrawBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.indirect_draw_buffers_init[@intFromEnum(name)] == true, src, "indirect draw buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_indirect_buffer_NOT_initialized(self: *const Controller, name: IndirectDrawBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.indirect_draw_buffers_init[@intFromEnum(name)] == false, src, "indirect draw buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_download_buffer_initialized(self: *const Controller, name: DownloadBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.download_buffers_init[@intFromEnum(name)] == true, src, "download transfer buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_download_buffer_NOT_initialized(self: *const Controller, name: DownloadBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.download_buffers_init[@intFromEnum(name)] == false, src, "download transfer buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_upload_buffer_initialized(self: *const Controller, name: UploadBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.upload_buffers_init[@intFromEnum(name)] == true, src, "upload transfer buffer `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_upload_buffer_NOT_initialized(self: *const Controller, name: UploadBufferName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.upload_buffers_init[@intFromEnum(name)] == false, src, "upload transfer buffer `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_texture_initialized(self: *const Controller, name: TextureName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.textures_init[@intFromEnum(name)] == true, src, "texture `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_texture_NOT_initialized(self: *const Controller, name: TextureName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.textures_init[@intFromEnum(name)] == false, src, "texture `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_sampler_initialized(self: *const Controller, name: SamplerName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.samplers_init[@intFromEnum(name)] == true, src, "sampler `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_sampler_NOT_initialized(self: *const Controller, name: SamplerName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.samplers_init[@intFromEnum(name)] == false, src, "sampler `{s}` was already initialized", .{@tagName(name)});
        }
        fn assert_fence_initialized(self: *const Controller, name: FenceName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.fences_init[@intFromEnum(name)] == true, src, "fence `{s}` was not initialized", .{@tagName(name)});
        }
        fn assert_fence_NOT_initialized(self: *const Controller, name: FenceName, comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(self.fences_init[@intFromEnum(name)] == false, src, "fence `{s}` was already initialized", .{@tagName(name)});
        }

        pub const GrowAndCopyGPUBufferDetails = struct {
            idx: u32,
            kind: GPUBufferKind,
            copy_len: u32,
            new_len: u32,
        };

        pub const GrowAndCopyDownloadTransferDetails = struct {
            idx: u32,
            copy_len: u32,
            new_len: u32,
        };

        pub fn begin_upload_pass(self: *Controller) UploadPass {
            self.stage.assert(.READY_FOR_NEXT_COMMAND_CYCLE, @src());
            self.stage = .UPLOAD_TO_GPU;
            self.upload_list.clear();
            self.upload_bytes_written = @splat(0);
            self.upload_slices = @splat(Utils.invalid_slice(u8));
            return UploadPass{ .controller = self };
        }

        pub const UploadPass = struct {
            controller: *Controller,

            fn ensure_upload_buffer_capacity(self: UploadPass, buf: UploadBufferName, need_byte_cap: u32) !void {
                const idx = @intFromEnum(buf);
                const curr_byte_cap = self.controller.upload_buffer_byte_caps[idx];
                if (need_byte_cap <= curr_byte_cap) return;

                var new_cap: u32 = 0;
                switch (self.controller.upload_buffer_grow_mode) {
                    .NO_GROW => {
                        assert_with_reason(need_byte_cap <= curr_byte_cap, @src(), "Upload transfer buffer `{s}` capacity ({d}) exceeded by request ({d}).", .{ @tagName(buf), curr_byte_cap, need_byte_cap });
                    },
                    .GROW_EXACT => new_cap = need_byte_cap,
                    .GROW_BY_ONE_AND_A_QUARTER => new_cap = need_byte_cap + (need_byte_cap >> 2),
                    .GROW_BY_ONE_AND_A_HALF => new_cap = need_byte_cap + (need_byte_cap >> 1),
                    .GROW_BY_DOUBLE => new_cap = need_byte_cap << 1,
                }

                const new_transfer = try self.controller.gpu.create_transfer_buffer(GPU_TransferBufferCreateInfo{
                    .usage = .UPLOAD,
                    .size = new_cap,
                    .props = .{},
                });
                errdefer self.controller.gpu.release_transfer_buffer(new_transfer);

                const new_ptr = try self.controller.gpu.map_transfer_buffer(new_transfer, false);

                // If the old buffer was already mapped and contains staged data, copy it across
                if (self.controller.mapped_upload_buffers[idx]) {
                    const written = self.controller.upload_bytes_written[idx];
                    if (written > 0) {
                        @memcpy(new_ptr[0..written], self.controller.upload_slices[idx][0..written]);
                    }
                    self.controller.gpu.unmap_transfer_buffer(self.controller.upload_buffers[idx]);
                }
                self.controller.gpu.release_transfer_buffer(self.controller.upload_buffers[idx]);

                self.controller.upload_buffers[idx] = new_transfer;
                self.controller.upload_buffer_byte_caps[idx] = new_cap;
                self.controller.upload_slices[idx] = new_ptr[0..new_cap];
                self.controller.mapped_upload_buffers[idx] = true;
            }

            /// returns the slice and the byte offset it started from (for use in a CopyPass)
            fn get_next_unused_upload_slice(self: UploadPass, buffer: UploadBufferName, num_bytes: u32, optional_texel_size: ?u32) !struct { []u8, u32 } {
                const idx = @intFromEnum(buffer);
                const start = self.controller.upload_bytes_written[idx];
                const aligned_start = if (optional_texel_size) |texel_block_size| std.mem.alignForward(u32, start, @max(TEXTURE_TRANSFER_MIN_ALIGN, texel_block_size)) else start;
                const end = aligned_start + num_bytes;
                try self.ensure_upload_buffer_capacity(buffer, end);
                if (!self.controller.mapped_upload_buffers[idx]) {
                    const ptr = try self.controller.gpu.map_transfer_buffer(
                        self.controller.upload_buffers[idx],
                        self.controller.cycle_unmapped_upload_buffers,
                    );
                    self.controller.upload_slices[idx] = ptr[0..self.controller.upload_buffer_byte_caps[idx]];
                    self.controller.mapped_upload_buffers[idx] = true;
                }

                self.controller.upload_bytes_written[idx] = end;
                return .{ self.controller.upload_slices[idx][aligned_start..end], aligned_start };
            }
            fn grow_gpu_buffer(self: UploadPass, comptime kind: GPUBufferKind, buf_idx: u32, curr_size: u32, new_size: u32) void {
                for (self.controller.grow_and_copy_gpu_buffer_list.zig_slice_entire()) |*prev_grow| {
                    if (prev_grow.idx == buf_idx and prev_grow.kind == kind) {
                        prev_grow.new_len = @max(prev_grow.new_len, new_size);
                        return;
                    }
                }
                const details = GrowAndCopyGPUBufferDetails{
                    .kind = kind,
                    .idx = buf_idx,
                    .copy_len = curr_size,
                    .new_len = new_size,
                };
                self.controller.grow_and_copy_gpu_buffer_list.append_one(details, self.controller.list_alloc);
            }

            fn handle_possible_gpu_buffer_grow(self: UploadPass, comptime kind: GPUBufferKind, buf_name: []const u8, buf_idx: u32, offset: u32, len: u32, need_size: u32) !void {
                var gpu_grow: u32 = 0;
                const curr_size = switch (kind) {
                    .STORAGE => self.controller.storage_buffer_byte_caps[buf_idx],
                    .VERTEX => self.controller.vertex_buffer_byte_caps[buf_idx],
                    .INDEX => self.controller.index_buffer_byte_caps[buf_idx],
                    .INDIRECT => self.controller.indirect_draw_buffer_byte_caps[buf_idx],
                };
                switch (switch (kind) {
                    .STORAGE => self.controller.storage_buffer_grow_mode,
                    .VERTEX => self.controller.vertex_buffer_grow_mode,
                    .INDEX => self.controller.index_buffer_grow_mode,
                    .INDIRECT => self.controller.indirect_draw_buffer_grow_mode,
                }) {
                    .NO_GROW => {
                        assert_with_reason(need_size <= curr_size, @src(), "copying {d} bytes to {s} buffer `{s}` at offset {d} exceeds the total length of the transfer buffer ({d}). Either manually grow the gpu buffer, or use an automatic grow setting", .{ len, @tagName(kind), buf_name, offset, curr_size });
                    },
                    .GROW_EXACT => if (need_size > curr_size) {
                        gpu_grow = need_size;
                    },
                    .GROW_BY_ONE_AND_A_QUARTER => if (need_size > curr_size) {
                        gpu_grow = need_size + (need_size >> 2);
                    },
                    .GROW_BY_ONE_AND_A_HALF => if (need_size > curr_size) {
                        gpu_grow = need_size + (need_size >> 1);
                    },
                    .GROW_BY_DOUBLE => if (need_size > curr_size) {
                        gpu_grow = need_size << 1;
                    },
                }
                if (gpu_grow > 0) {
                    grow_gpu_buffer(self, kind, buf_idx, curr_size, gpu_grow);
                }
            }

            fn upload_to_vertex_buffer_internal(self: UploadPass, comptime dest: VertexBufferName, dest_index_of_first_vertex: u32, transfer_buf: UploadBufferName, source: anytype, comptime TYPE_CHECK: bool) !void {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const source_bytes: []const u8 = bytes_cast(source);
                const dest_idx = @intFromEnum(dest);
                const dest_type = INTERNAL.VERTEX_BUFFER_TYPES[dest_idx];
                if (TYPE_CHECK) {
                    const source_element_type = element_type(@TypeOf(source));
                    assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest vertex buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                }
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_vertex;
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                try self.handle_possible_gpu_buffer_grow(.VERTEX, @tagName(dest), dest_idx, dest_offset, transfer_len, buffer_end);
                const transfer_slice, const transfer_offset = try self.get_next_unused_upload_slice(transfer_buf, transfer_len, null);
                @memcpy(transfer_slice, source_bytes);
                const details = CopyUploadDetails{
                    .dest = GPUAssetRegion.vertex_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.upload_list.append_one(details, self.controller.list_alloc);
            }

            pub fn upload_to_vertex_buffer(self: UploadPass, comptime dest: VertexBufferName, dest_index_of_first_vertex: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_vertex_buffer_internal(dest, dest_index_of_first_vertex, transfer_buf, source, true);
            }
            pub fn upload_to_vertex_buffer_no_type_check(self: UploadPass, comptime dest: VertexBufferName, dest_index_of_first_vertex: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_vertex_buffer_internal(dest, dest_index_of_first_vertex, transfer_buf, source, false);
            }
            pub fn upload_to_vertex_buffer_typed(self: UploadPass, comptime dest: VertexBufferName, dest_index_of_first_vertex: u32, transfer_buf: UploadBufferName, source: []const INTERNAL.VERTEX_BUFFER_TYPES[@intFromEnum(dest)]) !void {
                return self.upload_to_vertex_buffer_internal(dest, dest_index_of_first_vertex, transfer_buf, source, true);
            }
            pub fn upload_to_index_buffer(self: UploadPass, comptime dest: IndexBufferName, dest_index_of_first_index: u32, transfer_buf: UploadBufferName, source: []const INTERNAL.INDEX_BUFFER_TYPES[@intFromEnum(dest)]) !void {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const source_bytes: []const u8 = bytes_cast(source);
                const dest_idx = @intFromEnum(dest);
                const ELEM = INTERNAL.INDEX_BUFFER_TYPES[dest_idx];
                const dest_offset = @sizeOf(ELEM) * dest_index_of_first_index;
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                try self.handle_possible_gpu_buffer_grow(.INDEX, @tagName(dest), dest_idx, dest_offset, transfer_len, buffer_end);
                const transfer_slice, const transfer_offset = try self.get_next_unused_upload_slice(transfer_buf, transfer_len, null);
                @memcpy(transfer_slice, source_bytes);
                const details = CopyUploadDetails{
                    .dest = GPUAssetRegion.index_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.upload_list.append_one(details, self.controller.list_alloc);
            }
            pub fn upload_to_indirect_draw_call_buffer(self: UploadPass, comptime dest: IndirectDrawBufferName, dest_index_of_first_draw_call: u32, transfer_buf: UploadBufferName, source: []const INTERNAL.INDIRECT_BUFFER_TYPES[@intFromEnum(dest)]) !void {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const source_bytes: []const u8 = bytes_cast(source);
                const dest_idx = @intFromEnum(dest);
                const ELEM = INTERNAL.INDIRECT_BUFFER_TYPES[dest_idx];
                const dest_offset = @sizeOf(ELEM) * dest_index_of_first_draw_call;
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                try self.handle_possible_gpu_buffer_grow(.INDIRECT, @tagName(dest), dest_idx, dest_offset, transfer_len, buffer_end);
                const transfer_slice, const transfer_offset = try self.get_next_unused_upload_slice(transfer_buf, transfer_len, null);
                @memcpy(transfer_slice, source_bytes);
                const details = CopyUploadDetails{
                    .dest = GPUAssetRegion.indirect_draw_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.upload_list.append_one(details, self.controller.list_alloc);
            }
            fn upload_to_storage_buffer_internal(self: UploadPass, comptime dest: StorageBufferName, dest_index_of_first_element: u32, transfer_buf: UploadBufferName, source: anytype, comptime TYPE_CHECK: bool) !void {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const source_bytes: []const u8 = bytes_cast(source);
                const dest_idx = @intFromEnum(dest);
                const dest_type = INTERNAL.STORAGE_BUFFER_TYPES[dest_idx];
                if (TYPE_CHECK) {
                    const source_element_type = element_type(@TypeOf(source));
                    assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest storage buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                }
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_element;
                const transfer_len: u32 = @intCast(source_bytes.len);
                const dest_buffer_end = dest_offset + transfer_len;
                try self.handle_possible_gpu_buffer_grow(.STORAGE, @tagName(dest), dest_idx, dest_offset, transfer_len, dest_buffer_end);
                const transfer_slice, const transfer_offset = try self.get_next_unused_upload_slice(transfer_buf, transfer_len, null);
                @memcpy(transfer_slice, source_bytes);
                const details = CopyUploadDetails{
                    .dest = GPUAssetRegion.storage_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.upload_list.append_one(details, self.controller.list_alloc);
            }
            pub fn upload_to_storage_buffer(self: UploadPass, comptime dest: StorageBufferName, dest_index_of_first_element: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_storage_buffer_internal(dest, dest_index_of_first_element, transfer_buf, source, true);
            }
            pub fn upload_to_storage_buffer_no_type_check(self: UploadPass, comptime dest: StorageBufferName, dest_index_of_first_element: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_storage_buffer_internal(dest, dest_index_of_first_element, transfer_buf, source, false);
            }
            pub fn upload_to_storage_buffer_typed(self: UploadPass, comptime dest: StorageBufferName, dest_index_of_first_element: u32, transfer_buf: UploadBufferName, source: []const INTERNAL.STORAGE_BUFFER_TYPES[@intFromEnum(dest)]) !void {
                return self.upload_to_storage_buffer_internal(dest, dest_index_of_first_element, transfer_buf, source, true);
            }
            fn upload_to_texture_internal(self: UploadPass, comptime dest: TextureName, dest_pos: Vec3(u32), dest_size: Vec3(u32), dest_mip_level: u32, dest_layer: u32, transfer_buf: UploadBufferName, source: anytype, comptime TYPE_CHECK: bool) !void {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const source_bytes: []const u8 = bytes_cast(source);
                const source_len: u32 = @intCast(source_bytes.len);
                const dest_idx = @intFromEnum(dest);
                const dest_texel_size = INTERNAL.TEXTURE_DEFS[dest_idx].pixel_format.texel_block_size();
                const dest_byte_size = dest_size.x * dest_size.y * dest_size.z * dest_texel_size;
                if (TYPE_CHECK) {
                    const source_element_type = element_type(@TypeOf(source));
                    assert_with_reason(@sizeOf(source_element_type) == dest_texel_size, @src(), "source element type must be the same SIZE as the dest texture texel block size, but `{d}` != `{d}`", .{ @sizeOf(source_element_type), dest_texel_size });
                }
                assert_with_reason(source_len == dest_byte_size, @src(), "source byte len {d} does not equal texture destination size {d} ({d} * {any}) (cannot automatically resize textures)", .{ source_len, dest_byte_size, dest_texel_size, dest_size });
                const texture_extent = dest_pos.add(dest_size);
                assert_with_reason(texture_extent.all_components_less_than_or_equal(self.controller.textures_sizes[dest_idx]), @src(), "max extent of destination texture {any} is out of bounds for texture size {any}", .{ texture_extent, self.controller.textures_sizes[dest_idx] });
                const transfer_slice, const transfer_offset = try self.get_next_unused_upload_slice(transfer_buf, source_len, dest_texel_size);
                @memcpy(transfer_slice, source_bytes);
                const details = CopyUploadDetails{
                    .dest = GPUAssetRegion.texture(dest, dest_pos, dest_size, dest_mip_level, dest_layer),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = source_len,
                };
                self.controller.upload_list.append_one(details, self.controller.list_alloc);
            }
            pub fn upload_to_texture(self: UploadPass, comptime dest: TextureName, dest_pos: Vec3(u32), dest_size: Vec3(u32), dest_mip_level: u32, dest_layer: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_texture_internal(dest, dest_pos, dest_size, dest_mip_level, dest_layer, transfer_buf, source, true);
            }
            pub fn upload_to_texture_no_type_check(self: UploadPass, comptime dest: TextureName, dest_pos: Vec3(u32), dest_size: Vec3(u32), dest_mip_level: u32, dest_layer: u32, transfer_buf: UploadBufferName, source: anytype) !void {
                return self.upload_to_texture_internal(dest, dest_pos, dest_size, dest_mip_level, dest_layer, transfer_buf, source, false);
            }
            pub fn upload_to_texture_typed(self: UploadPass, comptime dest: TextureName, dest_pos: Vec3(u32), dest_size: Vec3(u32), dest_mip_level: u32, dest_layer: u32, transfer_buf: UploadBufferName, source: []const INTERNAL.TEXTURE_DEFS[@intFromEnum(dest)].pixel_format.struct_type()) !void {
                return self.upload_to_texture_internal(dest, dest_pos, dest_size, dest_mip_level, dest_layer, transfer_buf, source, false);
            }

            pub fn end_upload_pass_and_start_command_buffer(self: UploadPass, cycle_gpu_buffers: bool) !CommandBuffer {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                const cmd: CommandBuffer, const copy: CopyPass = try self.end_upload_pass_and_start_command_buffer_with_active_copy_pass(cycle_gpu_buffers);
                copy.end_copy_pass();
                return cmd;
            }
            pub fn end_upload_pass_and_start_command_buffer_with_active_copy_pass(self: UploadPass, cycle_gpu_buffers: bool) !struct { CommandBuffer, CopyPass } {
                self.controller.stage.assert(.UPLOAD_TO_GPU, @src());
                for (self.controller.mapped_upload_buffers[0..], 0..) |is_mapped, i| {
                    if (is_mapped) {
                        self.controller.gpu.unmap_transfer_buffer(self.controller.upload_buffers[i]);
                        self.controller.mapped_upload_buffers[i] = false;
                        self.controller.upload_slices[i] = Utils.invalid_slice(u8);
                        self.controller.upload_bytes_written[i] = 0;
                    }
                }
                self.controller.sdl_cmd_buf = try self.controller.gpu.acquire_command_buffer();
                self.controller.sdl_copy_pass = try self.controller.sdl_cmd_buf.begin_copy_pass();
                self.controller.stage = .COPY_PASS;
                for (self.controller.grow_and_copy_gpu_buffer_list.zig_slice_entire()) |grow| {
                    switch (grow.kind) {
                        .STORAGE => {
                            assert_with_reason(INTERNAL.NUM_STORAGE_BUFFERS > 0, @src(), "", .{});
                            self.controller.assert_storage_buffer_initialized(num_cast(grow.idx, StorageBufferName), @src());
                            const old_buf = self.controller.storage_buffers[grow.idx];
                            const new_buf = try self.controller.gpu.create_buffer(GPU_BufferCreateInfo{
                                .size = grow.new_len,
                                .props = .{},
                                .usage = INTERNAL.STORAGE_BUFFER_USAGES[grow.idx],
                            });
                            if (grow.copy_len > 0) {
                                self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(.{ .buffer = old_buf, .offset = 0 }, .{ .buffer = new_buf, .offset = 0 }, grow.copy_len, cycle_gpu_buffers);
                            }
                            self.controller.storage_buffer_byte_caps[grow.idx] = grow.new_len;
                            self.controller.storage_buffers[grow.idx] = new_buf;
                            self.controller.release_buffers_list.append_one(DeleteBufferDetails{ .buf = old_buf }, self.controller.list_alloc);
                        },
                        .VERTEX => {
                            assert_with_reason(INTERNAL.NUM_VERTEX_BUFFERS > 0, @src(), "", .{});
                            self.controller.assert_vert_buffer_initialized(num_cast(grow.idx, VertexBufferName), @src());
                            const old_buf = self.controller.vertex_buffers[grow.idx];
                            const new_buf = try self.controller.gpu.create_buffer(GPU_BufferCreateInfo{
                                .size = grow.new_len,
                                .props = .{},
                                .usage = GPU_BufferUsageFlags.flag(.VERTEX),
                            });
                            if (grow.copy_len > 0) {
                                self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(.{ .buffer = old_buf, .offset = 0 }, .{ .buffer = new_buf, .offset = 0 }, grow.copy_len, cycle_gpu_buffers);
                            }
                            self.controller.vertex_buffer_byte_caps[grow.idx] = grow.new_len;
                            self.controller.vertex_buffers[grow.idx] = new_buf;
                            self.controller.release_buffers_list.append_one(DeleteBufferDetails{ .buf = old_buf }, self.controller.list_alloc);
                        },
                        .INDEX => {
                            assert_with_reason(INTERNAL.NUM_INDEX_BUFFERS > 0, @src(), "", .{});
                            self.controller.assert_index_buffer_initialized(num_cast(grow.idx, IndexBufferName), @src());
                            const old_buf = self.controller.index_buffers[grow.idx];
                            const new_buf = try self.controller.gpu.create_buffer(GPU_BufferCreateInfo{
                                .size = grow.new_len,
                                .props = .{},
                                .usage = GPU_BufferUsageFlags.flag(.INDEX),
                            });
                            if (grow.copy_len > 0) {
                                self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(.{ .buffer = old_buf, .offset = 0 }, .{ .buffer = new_buf, .offset = 0 }, grow.copy_len, cycle_gpu_buffers);
                            }
                            self.controller.index_buffer_byte_caps[grow.idx] = grow.new_len;
                            self.controller.index_buffers[grow.idx] = new_buf;
                            self.controller.release_buffers_list.append_one(DeleteBufferDetails{ .buf = old_buf }, self.controller.list_alloc);
                        },
                        .INDIRECT => {
                            assert_with_reason(INTERNAL.NUM_INDIRECT_BUFFERS > 0, @src(), "", .{});
                            self.controller.assert_indirect_buffer_initialized(num_cast(grow.idx, IndirectDrawBufferName), @src());
                            const old_buf = self.controller.indirect_draw_buffers[grow.idx];
                            const new_buf = try self.controller.gpu.create_buffer(GPU_BufferCreateInfo{
                                .size = grow.new_len,
                                .props = .{},
                                .usage = GPU_BufferUsageFlags.flag(.INDIRECT),
                            });
                            if (grow.copy_len > 0) {
                                self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(.{ .buffer = old_buf, .offset = 0 }, .{ .buffer = new_buf, .offset = 0 }, grow.copy_len, cycle_gpu_buffers);
                            }
                            self.controller.indirect_draw_buffer_byte_caps[grow.idx] = grow.new_len;
                            self.controller.indirect_draw_buffers[grow.idx] = new_buf;
                            self.controller.release_buffers_list.append_one(DeleteBufferDetails{ .buf = old_buf }, self.controller.list_alloc);
                        },
                    }
                }
                for (self.controller.upload_list.zig_slice_entire()) |upload| {
                    switch (upload.dest) {
                        .STORAGE_BUF => |details| {
                            self.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.storage_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .VERTEX_BUF => |details| {
                            self.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.vertex_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .INDEX_BUF => |details| {
                            self.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.index_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .INDIRECT_BUF => |details| {
                            self.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.indirect_draw_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .TEXTURE => |details| {
                            try self.copy_from_upload_buffer_to_gpu_texture(.texture_upload_info(upload.transfer_buf, upload.transfer_buf_offset, details.size.x, details.size.y), TextureRegion.texture_region(details.target, details.mip_level, details.layer, details.pos, details.size), cycle_gpu_buffers);
                        },
                    }
                }
                self.controller.upload_list.clear();
                self.controller.grow_and_copy_gpu_buffer_list.clear();
                const gpu_copy = CopyPass{ .controller = self.controller };
                const cmd = CommandBuffer{ .controller = self.controller };
                return .{ cmd, gpu_copy };
            }

            fn copy_from_upload_buffer_to_gpu_buffer(self: UploadPass, from: UploadTransferBufferLocation, to: BufferRegion, cycle_buffer: bool) void {
                self.controller.sdl_copy_pass.upload_from_transfer_buffer_to_gpu_buffer(from.to_sdl(self.controller), to.to_sdl(self.controller), cycle_buffer);
            }
            fn copy_from_upload_buffer_to_gpu_texture(self: UploadPass, from: TextureUploadInfo, to: TextureRegion, cycle_buffer: bool) !void {
                self.controller.sdl_copy_pass.upload_from_transfer_buffer_to_gpu_texture(from.to_sdl(self.controller), try to.to_sdl(self.controller), cycle_buffer);
            }

            pub fn end_upload_pass_then_create_and_submit_new_command_buffer(self: UploadPass, cycle_gpu_buffers: bool) !void {
                var cmd: CommandBuffer = try self.end_upload_pass_and_start_command_buffer(cycle_gpu_buffers);
                try cmd.submit_commands();
            }
            pub fn end_upload_pass_then_create_and_submit_new_command_buffer_with_fence(self: UploadPass, cycle_gpu_buffers: bool) !void {
                var cmd: CommandBuffer = try self.end_upload_pass_and_start_command_buffer(cycle_gpu_buffers);
                try cmd.submit_commands_and_aquire_fence();
            }
            pub fn end_upload_pass_then_create_and_submit_new_command_buffer_and_immediately_wait_on_fence(self: UploadPass, cycle_gpu_buffers: bool) !void {
                var cmd: CommandBuffer = try self.end_upload_pass_and_start_command_buffer(cycle_gpu_buffers);
                try cmd.submit_commands_and_immediately_wait_on_fence();
            }
            pub fn end_upload_pass_then_create_and_new_command_buffer_and_begin_download_pass(self: UploadPass, cycle_gpu_buffers: bool) !DownloadPass {
                _, const copy = try self.end_upload_pass_and_start_command_buffer_with_active_copy_pass(cycle_gpu_buffers);
                return copy.end_copy_pass_and_begin_download_pass();
            }
        };

        /// Creates a CommandBuffer and CopyPass to move data from the gpu to the application
        ///
        /// Ending the DownloadPass will submit the CommandBuffer and provide a PendingFinalDownloadHandle
        /// that can be used to move the data from the transfer buffers to the staged application memory slices
        /// when the GPU is done processing the commands (possibly by using an optional fence)
        ///
        /// If you want to download data after a CommandBuffer that does some other work, use the associated method on the CommandBuffer
        /// to start the DownloadPass instead.
        pub fn begin_standalone_download_pass(self: *Controller) !DownloadPass {
            const cmd = try self.begin_command_buffer();
            const copy = try cmd.begin_gpu_copy_pass();
            return copy.end_copy_pass_and_begin_download_pass();
        }

        pub const DownloadPass = struct {
            controller: *Controller,

            fn get_download_slice(self: DownloadPass, buffer: DownloadBufferName, start: u32, end_excluded: u32) ![]const u8 {
                const idx = @intFromEnum(buffer);
                assert_with_reason(start < end_excluded, @src(), "invalid slice for download", .{});
                if (!self.controller.mapped_download_buffers[idx]) {
                    const ptr = try self.controller.gpu.map_transfer_buffer(self.controller.get_download_transfer_buffer(buffer), false);
                    self.controller.download_slices[idx] = ptr[0..self.controller.download_buffer_byte_caps[idx]];
                    self.controller.mapped_download_buffers[idx] = true;
                }
                return self.controller.download_slices[idx][start..end_excluded];
            }

            /// returns the byte offset the slice will start from (for use in a CopyPass)
            fn get_next_unused_download_slice_offset(self: DownloadPass, buffer: DownloadBufferName, num_bytes: u32, optional_texel_size: ?u32) !u32 {
                const idx = @intFromEnum(buffer);
                const start = self.controller.download_bytes_read[idx];
                const aligned_start = if (optional_texel_size) |texel_block_size| std.mem.alignForward(u32, start, @max(TEXTURE_TRANSFER_MIN_ALIGN, texel_block_size)) else start;
                const end = aligned_start + num_bytes;
                try handle_possible_transfer_buffer_grow(self, buffer, aligned_start, num_bytes, end);
                self.controller.download_bytes_read[idx] = end;
                return aligned_start;
            }

            fn handle_possible_transfer_buffer_grow(self: DownloadPass, buf: DownloadBufferName, offset: u32, len: u32, need_cap: u32) !void {
                var grow_cap: u32 = 0;
                const idx = @intFromEnum(buf);
                const curr_cap = self.controller.download_buffer_byte_caps[idx];
                switch (self.controller.download_buffer_grow_mode) {
                    .NO_GROW => {
                        assert_with_reason(need_cap <= curr_cap, @src(), "copying {d} bytes to download transfer buffer `{s}` at offset {d} exceeds the total length of the transfer buffer ({d}). Either manually grow the transfer buffer, or use an automatic grow setting", .{ len, @tagName(buf), offset, curr_cap });
                    },
                    .GROW_EXACT => if (need_cap > curr_cap) {
                        grow_cap = need_cap;
                    },
                    .GROW_BY_ONE_AND_A_QUARTER => if (need_cap > curr_cap) {
                        grow_cap = need_cap + (need_cap >> 2);
                    },
                    .GROW_BY_ONE_AND_A_HALF => if (need_cap > curr_cap) {
                        grow_cap = need_cap + (need_cap >> 1);
                    },
                    .GROW_BY_DOUBLE => if (need_cap > curr_cap) {
                        grow_cap = need_cap << 1;
                    },
                }
                if (grow_cap > 0) {
                    try queue_grow_transfer_buffer(self, buf, curr_cap, grow_cap);
                }
            }

            fn queue_grow_transfer_buffer(self: DownloadPass, buf: DownloadBufferName, curr_size: u32, new_size: u32) !void {
                const buf_idx = @intFromEnum(buf);
                for (self.controller.grow_and_copy_download_transfer_list.zig_slice_entire()) |*prev_grow| {
                    if (prev_grow.idx == buf_idx) {
                        prev_grow.new_len = @max(prev_grow.new_len, new_size);
                        return;
                    }
                }
                const details = GrowAndCopyDownloadTransferDetails{
                    .idx = buf_idx,
                    .copy_len = curr_size,
                    .new_len = new_size,
                };
                self.controller.grow_and_copy_download_transfer_list.append_one(details, self.controller.list_alloc);
            }

            fn handle_queued_gpu_to_transfer_copies(self: DownloadPass) !void {
                for (self.controller.grow_and_copy_download_transfer_list.zig_slice_entire()) |grow_details| {
                    const new_download = try self.controller.gpu.create_transfer_buffer(GPU_TransferBufferCreateInfo{
                        .size = grow_details.new_len,
                        .usage = .DOWNLOAD,
                        .props = .{},
                    });
                    self.controller.gpu.release_transfer_buffer(self.controller.download_buffers[grow_details.idx]);
                    self.controller.download_buffers[grow_details.idx] = new_download;
                    self.controller.download_buffer_byte_caps[grow_details.idx] = grow_details.new_len;
                    self.controller.mapped_download_buffers[grow_details.idx] = false;
                    self.controller.download_slices[grow_details.idx] = &.{};
                }
                self.controller.grow_and_copy_download_transfer_list.clear();
                for (self.controller.download_list.zig_slice_entire()) |download_details| {
                    switch (download_details.queued_copy) {
                        .BUFFER => |details| {
                            self.copy_from_gpu_buffer_to_download_buffer(details.from, details.to);
                        },
                        .TEXTURE => |details| {
                            try self.copy_from_gpu_texture_to_download_buffer(details.from, details.to);
                        },
                    }
                }
            }

            fn copy_from_gpu_buffer_to_download_buffer(self: DownloadPass, from: BufferRegion, to: DownloadTransferBufferLocation) void {
                self.controller.sdl_copy_pass.download_from_gpu_buffer_to_transfer_buffer(from.to_sdl(self.controller), to.to_sdl(self.controller));
            }
            fn copy_from_gpu_texture_to_download_buffer(self: DownloadPass, from: TextureRegion, to: TextureDownloadInfo) !void {
                self.controller.sdl_copy_pass.download_from_gpu_texture_to_transfer_buffer(try from.to_sdl(self.controller), to.to_sdl(self.controller));
            }

            fn download_from_vertex_buffer_internal(self: DownloadPass, comptime source: VertexBufferName, source_index_of_first_element: u32, source_element_count: u32, transfer_buf: DownloadBufferName, dest: anytype, comptime TYPE_CHECK: bool) ![]element_type(@TypeOf(dest)) {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                const dest_bytes: []u8 = bytes_cast(dest);
                const source_idx = @intFromEnum(source);
                const ELEM = INTERNAL.VERTEX_BUFFER_TYPES[source_idx];
                const source_offset = @sizeOf(ELEM) * source_index_of_first_element;
                if (comptime TYPE_CHECK) {
                    const DEST_ELEM = element_type(@TypeOf(dest));
                    assert_with_reason(ELEM == DEST_ELEM, @src(), "source element type must be the same as the dest vertex buffer element type, but `{s}` != `{s}`", .{ @typeName(ELEM), @typeName(DEST_ELEM) });
                }
                const transfer_len: u32 = @sizeOf(ELEM) * source_element_count;
                const buffer_end = source_offset + transfer_len;
                assert_with_reason(self.controller.vertex_buffer_byte_caps[source_idx] >= buffer_end, @src(), "source vertex buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_element_count, @typeName(ELEM), source_offset, buffer_end, self.controller.vertex_buffer_byte_caps[source_idx] });
                const transfer_offset: u32 = try self.get_next_unused_download_slice_offset(transfer_buf, transfer_len, null);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .queued_copy = .{ .BUFFER = .{
                        .from = .buffer_region(.vertex_buffer(source), source_offset, transfer_len),
                        .to = .download_buffer_loc(transfer_buf, transfer_offset),
                    } },
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.download_list.append_one(details, self.controller.list_alloc);
                self.controller.download_occured = true;
                return Cast.bytes_as_elems_aligned(element_type(@TypeOf(dest)), dest_bytes[0..transfer_len]);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_vertex_buffer(self: DownloadPass, comptime source: VertexBufferName, source_index_of_first_element: u32, source_element_count: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_vertex_buffer_internal(source, source_index_of_first_element, source_element_count, transfer_buf, dest, true);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_vertex_buffer_no_type_check(self: DownloadPass, comptime source: VertexBufferName, source_index_of_first_element: u32, source_element_count: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_vertex_buffer_internal(source, source_index_of_first_element, source_element_count, transfer_buf, dest, false);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_vertex_buffer_typed(self: DownloadPass, comptime source: VertexBufferName, source_index_of_first_element: u32, source_element_count: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_vertex_buffer_internal(source, source_index_of_first_element, source_element_count, transfer_buf, dest, true);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the Fence or PendingFinalDownloadHandle is completed
            fn download_from_index_buffer_internal(self: DownloadPass, comptime source: IndexBufferName, source_index_of_first_index: u32, source_index_count: u32, transfer_buf: DownloadBufferName, dest: anytype, comptime TYPE_CHECK: bool) ![]element_type(@TypeOf(dest)) {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                const dest_bytes: []u8 = bytes_cast(dest);
                const source_idx = @intFromEnum(source);
                const ELEM = INTERNAL.INDEX_BUFFER_TYPES[@intFromEnum(source)];
                if (comptime TYPE_CHECK) {
                    const DEST_ELEM = element_type(@TypeOf(dest));
                    assert_with_reason(ELEM == DEST_ELEM, @src(), "source element type must be the same as the dest index buffer element type, but `{s}` != `{s}`", .{ @typeName(ELEM), @typeName(DEST_ELEM) });
                }
                const source_offset = @sizeOf(ELEM) * source_index_of_first_index;
                const transfer_len: u32 = @sizeOf(ELEM) * source_index_count;
                const buffer_end = source_offset + transfer_len;
                assert_with_reason(self.controller.index_buffer_byte_caps[source_idx] >= buffer_end, @src(), "source index buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_index_count, @typeName(ELEM), source_offset, buffer_end, self.controller.index_buffer_byte_caps[source_idx] });
                const transfer_offset: u32 = try self.get_next_unused_download_slice_offset(transfer_buf, transfer_len, null);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .queued_copy = .{ .BUFFER = .{
                        .from = .buffer_region(.index_buffer(source), source_offset, transfer_len),
                        .to = .download_buffer_loc(transfer_buf, transfer_offset),
                    } },
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.download_list.append_one(details, self.controller.list_alloc);
                self.controller.download_occured = true;
                return Cast.bytes_as_elems_aligned(element_type(@TypeOf(dest)), dest_bytes[0..transfer_len]);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the Fence or PendingFinalDownloadHandle is completed
            pub fn download_from_index_buffer(self: DownloadPass, comptime source: IndexBufferName, source_index_of_first_index: u32, source_index_count: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_index_buffer_internal(source, source_index_of_first_index, source_index_count, transfer_buf, dest, true);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the Fence or PendingFinalDownloadHandle is completed
            pub fn download_from_index_buffer_no_type_check(self: DownloadPass, comptime source: IndexBufferName, source_index_of_first_index: u32, source_index_count: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_index_buffer_internal(source, source_index_of_first_index, source_index_count, transfer_buf, dest, false);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the Fence or PendingFinalDownloadHandle is completed
            pub fn download_from_index_buffer_typed(self: DownloadPass, comptime source: IndexBufferName, source_index_of_first_index: u32, source_index_count: u32, transfer_buf: DownloadBufferName, dest: []INTERNAL.INDEX_BUFFER_TYPES[@intFromEnum(source)]) ![]INTERNAL.INDEX_BUFFER_TYPES[@intFromEnum(source)] {
                return self.download_from_index_buffer_internal(source, source_index_of_first_index, source_index_count, transfer_buf, dest, true);
            }
            //TODO flexible funcs for other buffers
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_indirect_draw_call_buffer(self: DownloadPass, comptime source: IndirectDrawBufferName, source_index_of_first_draw_call: u32, source_draw_call_count: u32, transfer_buf: DownloadBufferName, dest: []INTERNAL.INDIRECT_BUFFER_TYPES[@intFromEnum(source)]) ![]INTERNAL.INDIRECT_BUFFER_TYPES[@intFromEnum(source)] {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                const dest_bytes: []u8 = bytes_cast(dest);
                const source_idx = @intFromEnum(source);
                const ELEM = INTERNAL.INDIRECT_BUFFER_TYPES[@intFromEnum(source)];
                const source_offset = @sizeOf(ELEM) * source_index_of_first_draw_call;
                const transfer_len: u32 = @sizeOf(ELEM) * source_draw_call_count;
                const buffer_end = source_offset + transfer_len;
                assert_with_reason(self.controller.indirect_draw_buffer_byte_caps[source_idx] >= buffer_end, @src(), "source index buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_draw_call_count, @typeName(ELEM), source_offset, buffer_end, self.controller.indirect_draw_buffer_byte_caps[source_idx] });
                const transfer_offset: u32 = try self.get_next_unused_download_slice_offset(transfer_buf, transfer_len, null);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .queued_copy = .{ .BUFFER = .{
                        .from = .buffer_region(.indirect_draw_buffer(source), source_offset, transfer_len),
                        .to = .download_buffer_loc(transfer_buf, transfer_offset),
                    } },
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.download_list.append_one(details, self.controller.list_alloc);
                self.controller.download_occured = true;
                return Cast.bytes_as_elems_aligned(ELEM, dest_bytes[0..transfer_len]);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_storage_buffer(self: DownloadPass, comptime source: StorageBufferName, source_index_of_first_element: u32, source_element_count: u32, transfer_buf: DownloadBufferName, dest: []INTERNAL.STORAGE_BUFFER_TYPES[@intFromEnum(source)]) ![]INTERNAL.STORAGE_BUFFER_TYPES[@intFromEnum(source)] {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                const dest_bytes: []u8 = bytes_cast(dest);
                const source_idx = @intFromEnum(source);
                const ELEM = INTERNAL.STORAGE_BUFFER_TYPES[@intFromEnum(source)];
                const source_offset = @sizeOf(ELEM) * source_index_of_first_element;
                const transfer_len: u32 = @sizeOf(ELEM) * source_element_count;
                const buffer_end = source_offset + transfer_len;
                assert_with_reason(self.controller.storage_buffer_byte_caps[source_idx] >= buffer_end, @src(), "source stroage buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_element_count, @typeName(ELEM), source_offset, buffer_end, self.controller.storage_buffer_byte_caps[source_idx] });
                const transfer_offset: u32 = try self.get_next_unused_download_slice_offset(transfer_buf, transfer_len, null);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .queued_copy = .{ .BUFFER = .{
                        .from = .buffer_region(.storage_buffer(source), source_offset, transfer_len),
                        .to = .download_buffer_loc(transfer_buf, transfer_offset),
                    } },
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.download_list.append_one(details, self.controller.list_alloc);
                self.controller.download_occured = true;
                return Cast.bytes_as_elems_aligned(ELEM, dest_bytes[0..transfer_len]);
            }

            fn download_from_texture_internal(self: DownloadPass, comptime source_tex_name: TextureName, source_pos: Vec3(u32), source_size: Vec3(u32), source_mip_level: u32, source_layer: u32, transfer_buf: DownloadBufferName, dest: anytype, comptime TYPE_CHECK: bool) ![]element_type(@TypeOf(dest)) {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                const dest_bytes: []u8 = bytes_cast(dest);
                const ELEM = element_type(@TypeOf(dest));
                var source_format: GPU_TextureFormat = undefined;
                var source_full_size: Vec3(u32) = undefined;
                const tex_idx = @intFromEnum(source_tex_name);
                const def = INTERNAL.TEXTURE_DEFS[tex_idx];
                source_format = def.pixel_format;
                source_full_size = self.controller.textures_sizes[tex_idx];
                const source_texel_size = source_format.texel_block_size();
                const transfer_texels = source_size.x * source_size.y * source_size.z;
                const transfer_len = transfer_texels * source_texel_size;
                if (comptime TYPE_CHECK) {
                    assert_with_reason(@sizeOf(ELEM) == source_texel_size, @src(), "source texture texel block SIZE must be the same size as the dest slice element size, but `{d}` != `{d}`", .{ source_texel_size, @sizeOf(ELEM) });
                }
                const source_max_extent = source_pos.add(source_size);
                assert_with_reason(source_max_extent.all_components_less_than_or_equal(source_full_size), @src(), "source texture/window `{s}` has a full size of {any}, but the furthest extent of the source region requested is {any} (outside full size)", .{ @tagName(source_tex_name), source_full_size, source_max_extent });
                assert_with_reason(num_cast(dest_bytes.len, u32) >= transfer_len, @src(), "destination slice cannot hold {d} items of texel size {d} ({d} bytes), len is {d} bytes", .{ transfer_texels, source_texel_size, transfer_len, dest_bytes.len });
                const transfer_offset: u32 = try self.get_next_unused_download_slice_offset(transfer_buf, transfer_len, source_texel_size);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .queued_copy = .{ .TEXTURE = .{
                        .from = TextureRegion.texture_region(Target.texture(source_tex_name), source_mip_level, source_layer, source_pos, source_size),
                        .to = TextureDownloadInfo.texture_download_info(transfer_buf, transfer_offset, source_size.x, source_size.y),
                    } },
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                self.controller.download_list.append_one(details, self.controller.list_alloc);
                self.controller.download_occured = true;
                return Cast.bytes_as_elems_aligned(ELEM, dest_bytes[0..transfer_len]);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_texture(self: DownloadPass, comptime source_tex_name: TextureName, source_pos: Vec3(u32), source_size: Vec3(u32), source_mip_level: u32, source_layer: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_texture_internal(source_tex_name, source_pos, source_size, source_mip_level, source_layer, transfer_buf, dest, true);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_texture_no_type_check(self: DownloadPass, comptime source_tex_name: TextureName, source_pos: Vec3(u32), source_size: Vec3(u32), source_mip_level: u32, source_layer: u32, transfer_buf: DownloadBufferName, dest: anytype) ![]element_type(@TypeOf(dest)) {
                return self.download_from_texture_internal(source_tex_name, source_pos, source_size, source_mip_level, source_layer, transfer_buf, dest, false);
            }
            /// `dest` MUST exist until the fence returned by the command buffer is signaled
            ///
            /// Returns the actual slice of `dest` that WILL BE written to when the pass is ended and submitted (in case it is smaller than the provided slice)
            ///
            /// dest slice will not contain the expected data until the PendingFinalDownloadHandle is submitted
            pub fn download_from_texture_typed(self: DownloadPass, comptime source_tex_name: TextureName, source_pos: Vec3(u32), source_size: Vec3(u32), source_mip_level: u32, source_layer: u32, transfer_buf: DownloadBufferName, dest: []INTERNAL.TEXTURE_DEFS[@intFromEnum(source_tex_name)].pixel_format.struct_type()) ![]INTERNAL.TEXTURE_DEFS[@intFromEnum(source_tex_name)].pixel_format.struct_type() {
                return self.download_from_texture_internal(source_tex_name, source_pos, source_size, source_mip_level, source_layer, transfer_buf, dest, false);
            }

            pub fn end_download_pass_with_no_downloads_and_submit_command_buffer(self: DownloadPass) !void {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                self.controller.assert_no_downloads_occured_for_submit(@src());
                self.controller.sdl_copy_pass.end_copy_pass();
                try self.controller.sdl_cmd_buf.submit_commands();
                self.controller.clean_up_after_command_submission();
                self.controller.stage = .READY_FOR_NEXT_COMMAND_CYCLE;
            }
            pub fn end_download_pass_submit_command_buffer_and_aquire_fence(self: DownloadPass) !void {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                try self.handle_queued_gpu_to_transfer_copies();
                self.controller.sdl_copy_pass.end_copy_pass();
                self.controller.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
                try self.controller.goo_cmd_buf().submit_commands_and_aquire_fence();
            }
            pub fn end_download_pass_submit_command_buffer_and_immedieately_wait_on_fence_to_complete_downloads(self: DownloadPass) !void {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                try self.handle_queued_gpu_to_transfer_copies();
                self.controller.sdl_copy_pass.end_copy_pass();
                self.controller.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
                try self.controller.goo_cmd_buf().submit_commands_and_immediately_wait_on_fence();
            }
            pub fn cancel_download_pass_and_cancel_commands(self: DownloadPass) !void {
                self.controller.stage.assert(.DOWNLOAD_FROM_GPU, @src());
                try self.handle_queued_gpu_to_transfer_copies();
                self.controller.sdl_copy_pass.end_copy_pass();
                self.controller.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
                try self.controller.goo_cmd_buf().cancel_commands();
            }
        };

        pub fn begin_command_buffer(self: *Controller) !CommandBuffer {
            self.stage.assert(.READY_FOR_NEXT_COMMAND_CYCLE, @src());
            self.sdl_cmd_buf = try self.gpu.acquire_command_buffer();
            self.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
            return CommandBuffer{ .controller = self };
        }

        pub const DeleteBufferDetails = struct {
            buf: *GPU_Buffer,
        };

        pub const CommandBuffer = struct {
            controller: *Controller,

            pub fn insert_debug_label(self: CommandBuffer, label: [*:0]const u8) void {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                self.controller.sdl_cmd_buf.insert_debug_label(label);
            }

            pub fn push_debug_group(self: CommandBuffer, name: [*:0]const u8) void {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                self.controller.sdl_cmd_buf.push_debug_group(name);
            }

            pub fn pop_debug_group(self: CommandBuffer) void {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                self.controller.sdl_cmd_buf.pop_debug_group();
            }

            //TODO
            // pub fn push_compute_uniform_data(self: *GPU_CommandBuffer, slot_index: u32, data_ptr: anytype) void {
            //     const data_raw = Utils.raw_slice_cast_const(data_ptr);
            //     C.SDL_PushGPUComputeUniformData(self.to_c_ptr(), slot_index, data_raw.ptr, @intCast(data_raw.len));
            // }

            pub fn get_swapchain_texture_for_window(self: CommandBuffer, window_name: WindowName) !?*GPU_Texture {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                const win_idx = @intFromEnum(window_name);
                if (self.controller.swapchain_is_cached[win_idx]) {
                    return self.controller.swapchain_cache[win_idx].texture;
                } else {
                    const win = self.controller.get_claimed_window(window_name);
                    const swap = try self.controller.sdl_cmd_buf.aquire_swapchain_texture(win);
                    self.controller.swapchain_cache[win_idx] = swap;
                    self.controller.swapchain_is_cached[win_idx] = true;
                    return swap.texture;
                }
            }
            pub fn get_swapchain_texture_and_size_for_window(self: CommandBuffer, window_name: WindowName) !GPU_SwapchainTexture {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                const win_idx = @intFromEnum(window_name);
                if (self.controller.swapchain_is_cached[win_idx]) {
                    return self.controller.swapchain_cache[win_idx];
                } else {
                    const win = self.controller.get_claimed_window(window_name);
                    const swap = try self.controller.sdl_cmd_buf.aquire_swapchain_texture(win);
                    self.controller.swapchain_cache[win_idx] = swap;
                    self.controller.swapchain_is_cached[win_idx] = true;
                    return swap;
                }
            }
            pub fn wait_and_get_swapchain_texture_for_window(self: CommandBuffer, window_name: WindowName) !?*GPU_Texture {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                const win_idx = @intFromEnum(window_name);
                if (self.controller.swapchain_is_cached[win_idx]) {
                    return self.controller.swapchain_cache[win_idx].texture;
                } else {
                    const win = self.controller.get_claimed_window(window_name);
                    const swap = try self.controller.sdl_cmd_buf.wait_and_aquire_swapchain_texture(win);
                    self.controller.swapchain_cache[win_idx] = swap;
                    self.controller.swapchain_is_cached[win_idx] = true;
                    return swap.texture;
                }
            }
            pub fn wait_and_get_swapchain_texture_and_size_for_window(self: CommandBuffer, window_name: WindowName) !GPU_SwapchainTexture {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                const win_idx = @intFromEnum(window_name);
                if (self.controller.swapchain_is_cached[win_idx]) {
                    return self.controller.swapchain_cache[win_idx];
                } else {
                    const win = self.controller.get_claimed_window(window_name);
                    const swap = try self.controller.sdl_cmd_buf.wait_and_aquire_swapchain_texture(win);
                    self.controller.swapchain_cache[win_idx] = swap;
                    self.controller.swapchain_is_cached[win_idx] = true;
                    return swap;
                }
            }

            pub fn begin_gpu_copy_pass(self: CommandBuffer) !CopyPass {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                const sdl_pass = try self.controller.sdl_cmd_buf.begin_copy_pass();
                self.controller.sdl_copy_pass = sdl_pass;
                self.controller.stage = .COPY_PASS;
                return CopyPass{ .controller = self.controller };
            }

            pub fn begin_render_pass(self: CommandBuffer, comptime pipeline: RenderPipelineName, color_targets: []const ColorTarget, opt_depth_target: ?DepthTarget) !?RenderPass {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                assert_with_reason(color_targets.len <= 8, @src(), "GraphicsController only supports up to 8 color targets, got {d}", .{color_targets.len});
                const DEF = INTERNAL.PIPELINE_DEFS[@intFromEnum(pipeline)];
                assert_with_reason(DEF.target_info.num_color_targets == num_cast(color_targets.len, u32), @src(), "mismatched number of color targets for render pipeline `{s}`, need {d}, got {d}", .{ @tagName(pipeline), DEF.target_info.num_color_targets, color_targets.len });
                assert_with_reason(DEF.depth_stencil_options.enable_depth_test == (opt_depth_target != null), @src(), "render pipeline `{s}`, needs {d} depth targets, got {d}", .{ @tagName(pipeline), if (DEF.depth_stencil_options.enable_depth_test) @as(u8, 1) else @as(u8, 0), if (opt_depth_target != null) @as(u8, 1) else @as(u8, 0) });
                var targets: [8]GPU_ColorTargetInfo = undefined;
                for (color_targets, 0..) |target, t| {
                    const sdl_target = try target.to_sdl(self.controller);
                    if (sdl_target.texture == null) return null;
                    targets[t] = sdl_target;
                }
                const depth: ?SDL3.GPU_DepthStencilTargetInfo = if (opt_depth_target) |depth_target| depth_target.to_sdl(self.controller) else null;
                const sdl_pass = try self.controller.sdl_cmd_buf.begin_render_pass(targets[0..color_targets.len], depth);
                self.controller.sdl_render_pass = sdl_pass;
                self.controller.sdl_render_pass.bind_graphics_pipeline(self.controller.get_render_pipeline(pipeline));
                self.controller.current_render_pipeline = pipeline;
                self.controller.stage = .RENDER_PASS;
                return RenderPass{ .controller = self.controller };
            }

            pub fn generate_mipmaps_for_texture(self: CommandBuffer, texture_name: TextureName) void {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                self.controller.sdl_cmd_buf.generate_mipmaps_for_texture(self.controller.get_texture(texture_name));
            }

            pub fn blit_texture(self: CommandBuffer, blit_info: BlitInfo) !void {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                const blit_sdl = try blit_info.to_sdl(self.controller);
                self.controller.sdl_cmd_buf.blit_texture(&blit_sdl);
            }
            pub fn submit_commands(self: CommandBuffer) !void {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                self.controller.assert_no_downloads_occured_for_submit(@src());
                try self.controller.sdl_cmd_buf.submit_commands();
                self.controller.clean_up_after_command_submission();
                self.controller.stage = .READY_FOR_NEXT_COMMAND_CYCLE;
            }
            pub fn submit_commands_and_aquire_fence(self: CommandBuffer) !void {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                assert_with_reason(self.controller.previous_gpu_fence == null, @src(), "the previous GPU command fence is still valid and waiting to be released", .{});
                self.controller.previous_gpu_fence = try self.controller.sdl_cmd_buf.submit_commands_and_aquire_fence();
                self.controller.clean_up_after_command_submission();
                self.controller.stage = .WAITING_FOR_GPU_COMPLETION_FENCE;
            }
            pub fn submit_commands_and_immediately_wait_on_fence(self: CommandBuffer) !void {
                try self.submit_commands_and_aquire_fence();
                try self.controller.wait_for_previous_gpu_fence();
            }
            pub fn begin_download_pass(self: CommandBuffer) !DownloadPass {
                self.controller.stage.assert(.WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, @src());
                self.controller.sdl_copy_pass = try self.controller.sdl_cmd_buf.begin_copy_pass();
                self.controller.grow_and_copy_download_transfer_list.clear();
                self.controller.download_list.clear();
                self.controller.stage = .DOWNLOAD_FROM_GPU;
                return DownloadPass{ .controller = self.controller };
            }
            pub fn cancel_commands(self: CommandBuffer) !void {
                self.controller.stage.assert_any(&.{ .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY, .COPY_PASS, .RENDER_PASS, .COMPUTE_PASS }, @src());
                switch (self.controller.stage) {
                    .COPY_PASS => {
                        self.controller.sdl_copy_pass.end_copy_pass();
                    },
                    .RENDER_PASS => {
                        self.controller.sdl_render_pass.end_render_pass();
                    },
                    .COMPUTE_PASS => {
                        //TODO
                    },
                    else => {},
                }
                try self.controller.sdl_cmd_buf.cancel_commands();
                self.controller.clean_up_after_command_submission();
                self.controller.stage = .READY_FOR_NEXT_COMMAND_CYCLE;
            }
        };

        pub const CopyPass = struct {
            controller: *Controller,

            fn assert_same_buffer_kind(source: BufferLocation, dest: BufferLocation, comptime src: ?std.builtin.SourceLocation) void {
                const src_kind: GPUBufferKind = std.meta.activeTag(source.buffer);
                const dst_kind: GPUBufferKind = std.meta.activeTag(dest.buffer);
                assert_with_reason(src_kind == dst_kind, src, "cannot copy from a `{s}` buffer to a `{s}` buffer", .{ @tagName(src_kind), @tagName(dst_kind) });
            }

            pub fn copy_from_gpu_texture_to_gpu_texture(self: CopyPass, source: TextureLocation, dest: TextureLocation, size: Vec3(u32), cycle: bool) void {
                self.controller.stage.assert(.COPY_PASS, @src());
                self.controller.sdl_copy_pass.copy_from_gpu_texture_to_gpu_texture(source.to_sdl(self.controller), dest.to_sdl(self.controller), size, cycle);
            }
            pub fn copy_from_gpu_buffer_to_gpu_buffer(self: CopyPass, source: BufferLocation, dest: BufferLocation, copy_len: u32, cycle: bool) void {
                self.controller.stage.assert(.COPY_PASS, @src());
                assert_same_buffer_kind(source, dest, @src());
                const source_sdl = source.to_sdl(self.controller);
                const dest_sdl = dest.to_sdl(self.controller);
                return self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(source_sdl, dest_sdl, copy_len, cycle);
            }
            pub fn copy_from_gpu_buffer_to_gpu_buffer_no_check(self: CopyPass, source: BufferLocation, dest: BufferLocation, copy_len: u32, cycle: bool) void {
                self.controller.stage.assert(.COPY_PASS, @src());
                const source_sdl = source.to_sdl(self.controller);
                const dest_sdl = dest.to_sdl(self.controller);
                return self.controller.sdl_copy_pass.copy_from_gpu_buffer_to_gpu_buffer(source_sdl, dest_sdl, copy_len, cycle);
            }
            pub fn end_copy_pass(self: CopyPass) void {
                self.controller.stage.assert(.COPY_PASS, @src());
                self.controller.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
                self.controller.sdl_copy_pass.end_copy_pass();
            }
            pub fn end_copy_pass_and_begin_download_pass(self: CopyPass) DownloadPass {
                self.controller.stage.assert(.COPY_PASS, @src());
                self.controller.stage = .DOWNLOAD_FROM_GPU;
                return DownloadPass{ .controller = self.controller };
            }
        };

        pub const RenderPass = struct {
            controller: *Controller,

            pub fn set_viewport(self: RenderPass, viewport: SDL3.GPU_Viewport) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.set_viewport(viewport);
            }
            pub fn clear_viewport(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.clear_viewport();
            }
            pub fn set_scissor(self: RenderPass, scissor_rect: SDL3.Rect_c_int) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.set_scissor(scissor_rect);
            }
            pub fn clear_scissor(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.clear_scissor();
            }
            pub fn set_blend_constants(self: RenderPass, blend_constants: SDL3.Color_RGBA_f32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.set_blend_constants(blend_constants);
            }
            pub fn set_stencil_reference_val(self: RenderPass, ref_val: u8) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.set_stencil_reference_val(ref_val);
            }

            fn assert_valid_idx_buffer_end(self: RenderPass, first_idx: u32, num_indexes: u32, comptime src: ?std.builtin.SourceLocation) void {
                const end_index_excl = first_idx + num_indexes;
                const byte_end_exclusive = INTERNAL.INDEX_BUFFER_TAGS[@intFromEnum(self.controller.bound_index_buffer)].size() * (end_index_excl);
                assert_with_reason(self.controller.index_buffer_byte_caps[@intFromEnum(self.controller.bound_index_buffer)] >= byte_end_exclusive, src, "index buffer `{s}` does not have at least {d} indexes (start {d} + count {d})", .{ @tagName(self.controller.bound_index_buffer), end_index_excl, first_idx, num_indexes });
            }

            /// Notably this does not bind index buffers, since there is no prescribed index buffer for any specific pipeline
            pub fn bind_all_resources_and_push_all_uniforms(self: RenderPass, default_vertex_buffer_offset: u32, specific_vertex_buffer_offsets: []const VertexBufferBindingOffset) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.push_all_uniform_data();
                self.bind_all_vertex_buffers(default_vertex_buffer_offset, specific_vertex_buffer_offsets);
                self.bind_all_sampler_pairs();
                self.bind_all_storage_textures();
                self.bind_all_storage_buffers();
            }

            pub fn push_all_uniform_data(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const info = INTERNAL.get_render_pipeline_info(self.controller.current_render_pipeline);
                const allowed_vert_uniforms = INTERNAL.allowed_uniforms_for_vert_shader(info.vertex);
                const allowed_frag_uniforms = INTERNAL.allowed_uniforms_for_frag_shader(info.fragment);
                for (allowed_vert_uniforms) |uniform| {
                    const uni_idx = @intFromEnum(uniform.uniform);
                    var ptr: [*]const u8 = @ptrCast(&self.controller.uniforms);
                    const uni_size = INTERNAL.UNIFORM_SIZES[uni_idx];
                    const uni_offset = INTERNAL.UNIFORM_OFFSETS[uni_idx];
                    ptr += uni_offset;
                    self.controller.sdl_cmd_buf.push_vertex_uniform_data(uniform.register, @ptrCast(ptr), uni_size);
                }
                for (allowed_frag_uniforms) |uniform| {
                    const uni_idx = @intFromEnum(uniform.uniform);
                    var ptr: [*]const u8 = @ptrCast(&self.controller.uniforms);
                    const uni_size = INTERNAL.UNIFORM_SIZES[uni_idx];
                    const uni_offset = INTERNAL.UNIFORM_OFFSETS[uni_idx];
                    ptr += uni_offset;
                    self.controller.sdl_cmd_buf.push_fragment_uniform_data(uniform.register, @ptrCast(ptr), uni_size);
                }
            }

            pub fn push_single_vertex_uniform_data(self: RenderPass, comptime unform_name: UniformName) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const register = INTERNAL.uniform_register_for_pipeline_stage(self.controller.current_render_pipeline, unform_name, .VERTEX) orelse assert_unreachable(@src(), "uniform `{s}` is disallowed/unrelated to current render pipeline `{s}` vertex shader, cannot push data", .{ @tagName(unform_name), @tagName(self.controller.current_render_pipeline) });
                const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(unform_name)));
                const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(unform_name)));
                self.controller.sdl_cmd_buf.push_vertex_uniform_data(register, ptr, len);
            }
            pub fn push_single_fragment_uniform_data(self: RenderPass, comptime unform_name: UniformName) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const register = INTERNAL.uniform_register_for_pipeline_stage(self.controller.current_render_pipeline, unform_name, .FRAGMENT) orelse assert_unreachable(@src(), "uniform `{s}` is disallowed/unrelated to current render pipeline `{s}` fragment shader, cannot push data", .{ @tagName(unform_name), @tagName(self.controller.current_render_pipeline) });
                const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(unform_name)));
                const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(unform_name)));
                self.controller.sdl_cmd_buf.push_fragment_uniform_data(register, ptr, len);
            }

            pub fn bind_all_vertex_buffers(self: RenderPass, default_offset: u32, specific_offsets: []const VertexBufferBindingOffset) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                assert_with_reason(num_cast(specific_offsets.len, u32) <= INTERNAL.LONGEST_VERTEX_BUFFER_SET, @src(), "length of `specific_offsets` ({d}) is longer than the longest recorded set of allowed vertex buffers ({d})", .{ specific_offsets.len, INTERNAL.LONGEST_VERTEX_BUFFER_SET });
                const all_vert_buffer_defs = INTERNAL.allowed_vertex_buffer_defs_for_pipeline(self.controller.current_render_pipeline);
                const len: u32 = @intCast(all_vert_buffer_defs.len);
                if (len > 0) {
                    const all_vert_buffer_names_for_pipeline = INTERNAL.allowed_vertex_buffer_names_for_pipeline(self.controller.current_render_pipeline);
                    var vertex_buffer_bindings: [INTERNAL.LONGEST_VERTEX_BUFFER_SET]SDL3.GPU_BufferBinding = undefined;
                    for (all_vert_buffer_names_for_pipeline, 0..) |name, i| {
                        vertex_buffer_bindings[i].buffer = self.controller.get_vertex_buffer(name);
                        vertex_buffer_bindings[i].offset = default_offset;
                    }
                    for (specific_offsets) |offset| {
                        const idx = INTERNAL.vertex_buffer_local_index_for_pipeline(self.controller.current_render_pipeline, offset.buffer) orelse assert_unreachable(@src(), "vertex buffer `{s}` is not allowed in render pipeline `{s}`", .{ @tagName(offset.buffer), @tagName(self.controller.current_render_pipeline) });
                        vertex_buffer_bindings[idx].offset = offset.data_offset;
                    }
                    self.controller.sdl_render_pass.bind_vertex_buffers_to_consecutive_slots(0, vertex_buffer_bindings[0..len]);
                }
            }

            pub fn bind_all_sampler_pairs(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const info = INTERNAL.get_render_pipeline_info(self.controller.current_render_pipeline);
                const allowed_vert = INTERNAL.allowed_sample_pairs_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_SAMPLE_PAIR_SET_VERT]SDL3.GPU_TextureSamplerBinding = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = SDL3.GPU_TextureSamplerBinding{
                            .sampler = self.controller.get_sampler(vert.sampler),
                            .texture = self.controller.get_texture(vert.texture),
                        };
                    }
                    const first_slot_vert = allowed_vert[0].cpu_register;
                    self.controller.sdl_render_pass.bind_vertex_samplers_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
                }
                const allowed_frag = INTERNAL.allowed_sample_pairs_for_frag_shaders(info.fragment);
                if (allowed_frag.len > 0) {
                    var frag_bindings: [INTERNAL.LONGEST_SAMPLE_PAIR_SET_FRAG]SDL3.GPU_TextureSamplerBinding = undefined;
                    for (allowed_frag, 0..) |frag, f| {
                        frag_bindings[f] = SDL3.GPU_TextureSamplerBinding{
                            .sampler = self.controller.get_sampler(frag.sampler),
                            .texture = self.controller.get_texture(frag.texture),
                        };
                    }
                    const first_slot_frag = allowed_frag[0].cpu_register;
                    self.controller.sdl_render_pass.bind_fragment_samplers_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_all_storage_textures(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const info = INTERNAL.get_render_pipeline_info(self.controller.current_render_pipeline);
                const allowed_vert = INTERNAL.allowed_storage_textures_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_STORAGE_TEXTURE_SET_VERT]*SDL3.GPU_Texture = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = self.controller.get_texture(vert.texture);
                    }
                    const first_slot_vert = allowed_vert[0].cpu_register;
                    self.controller.sdl_render_pass.bind_vertex_storage_textures_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
                }
                const allowed_frag = INTERNAL.allowed_storage_textures_for_frag_shaders(info.fragment);
                if (allowed_frag.len > 0) {
                    var frag_bindings: [INTERNAL.LONGEST_STORAGE_TEXTURE_SET_FRAG]*SDL3.GPU_Texture = undefined;
                    for (allowed_frag, 0..) |frag, f| {
                        frag_bindings[f] = self.controller.get_texture(frag.texture);
                    }
                    const first_slot_frag = allowed_frag[0].cpu_register;
                    self.controller.sdl_render_pass.bind_fragment_storage_textures_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_all_storage_buffers(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const info = INTERNAL.get_render_pipeline_info(self.controller.current_render_pipeline);
                const allowed_vert = INTERNAL.allowed_storage_buffers_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_STORAGE_BUFFER_SET_VERT]*SDL3.GPU_Buffer = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = self.controller.get_storage_buffer(vert.buffer);
                    }
                    const first_slot_vert = allowed_vert[0].cpu_register;
                    self.controller.sdl_render_pass.bind_vertex_storage_buffers_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
                }
                const allowed_frag = INTERNAL.allowed_storage_buffers_for_frag_shaders(info.fragment);
                if (allowed_frag.len > 0) {
                    var frag_bindings: [INTERNAL.LONGEST_STORAGE_BUFFER_SET_FRAG]*SDL3.GPU_Buffer = undefined;
                    for (allowed_frag, 0..) |frag, f| {
                        frag_bindings[f] = self.controller.get_storage_buffer(frag.buffer);
                    }
                    const first_slot_frag = allowed_frag[0].cpu_register;
                    self.controller.sdl_render_pass.bind_fragment_storage_buffers_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_index_buffer(self: RenderPass, buffer: IndexBufferName, offset: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const buf_idx = @intFromEnum(buffer);
                var bind = GPU_BufferBinding{
                    .buffer = self.controller.get_index_buffer(buffer),
                    .offset = offset,
                };
                const size = INTERNAL.INDEX_BUFFER_TAGS[buf_idx];
                self.controller.sdl_render_pass.bind_index_buffer(&bind, size);
                self.controller.index_buffer_bound = true;
                self.controller.bound_index_buffer = buffer;
            }

            pub fn draw_primitives(self: RenderPass, first_vertex: u32, num_vertices: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.draw_primitives(first_vertex, num_vertices, 0, 1);
            }
            pub fn draw_primitives_instanced(self: RenderPass, first_vertex: u32, num_vertices: u32, first_instance: u32, num_instances: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.draw_primitives(first_vertex, num_vertices, first_instance, num_instances);
            }
            pub fn draw_primitives_indirect(self: RenderPass, indirect_draw_buffer: IndirectDrawBufferName, first_draw_call_index: u32, num_draw_calls: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                const buf_idx = @intFromEnum(indirect_draw_buffer);
                const buf = self.controller.get_indirect_draw_buffer(indirect_draw_buffer);
                assert_with_reason(INTERNAL.INDIRECT_BUFFER_MODES[buf_idx] == .NORMAL_INDIRECT, @src(), "indirect draw call buffer `{s}` is staged to contain per-index draw calls (GPU_IndexedIndirectDrawCommand), not per-vertex draw calls (GPU_IndirectDrawCommand)", .{@tagName(indirect_draw_buffer)});
                //TODO assert each indirect draw is valid
                self.controller.sdl_render_pass.draw_primitives_indirect(buf, first_draw_call_index, num_draw_calls);
            }

            pub fn draw_indexed_primitives(self: RenderPass, vertex_offset_per_index: i32, first_index: u32, num_indices: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                assert_with_reason(self.controller.index_buffer_bound, @src(), "cannot draw indexed data when no index buffer is bound", .{});
                self.assert_valid_idx_buffer_end(first_index, num_indices, @src());
                self.controller.sdl_render_pass.draw_indexed_primitives(vertex_offset_per_index, first_index, num_indices, 0, 1);
            }
            pub fn draw_indexed_primitives_instanced(self: RenderPass, vertex_offset_per_index: i32, first_index: u32, num_indices: u32, first_instance: u32, num_instances: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                assert_with_reason(self.controller.index_buffer_bound, @src(), "cannot draw indexed data when no index buffer is bound", .{});
                self.assert_valid_idx_buffer_end(first_index, num_indices, @src());
                self.controller.sdl_render_pass.draw_indexed_primitives(vertex_offset_per_index, first_index, num_indices, first_instance, num_instances);
            }
            pub fn draw_indexed_primitives_indirect(self: RenderPass, indirect_draw_buffer: IndirectDrawBufferName, first_draw_call_index: u32, num_draw_calls: u32) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                assert_with_reason(self.controller.index_buffer_bound, @src(), "cannot draw indexed data when no index buffer is bound", .{});
                const buf_idx = @intFromEnum(indirect_draw_buffer);
                const buf = self.controller.get_indirect_draw_buffer(indirect_draw_buffer);
                assert_with_reason(INTERNAL.INDIRECT_BUFFER_MODES[buf_idx] == .INDEXED_INDIRECT, @src(), "indirect draw call buffer `{s}` is staged to contain per-vertex draw calls (GPU_IndirectDrawCommand), not per-index draw calls (GPU_IndexedIndirectDrawCommand)", .{@tagName(indirect_draw_buffer)});
                //TODO assert each indirect draw is valid
                self.controller.sdl_render_pass.draw_indexed_primitives_indirect(buf, first_draw_call_index, num_draw_calls);
            }

            pub fn end_render_pass(self: RenderPass) void {
                self.controller.stage.assert(.RENDER_PASS, @src());
                self.controller.sdl_render_pass.end_render_pass();
                self.controller.stage = .WAITING_FOR_RENDER_COMPUTE_OR_GPU_COPY;
                self.controller.index_buffer_bound = false;
            }
        };

        pub const INTERNAL = struct {
            pub const NUM_WINDOWS = Types.enum_defined_field_count(WINDOW_NAMES_ENUM);
            pub const NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
            pub const NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
            pub const NUM_UPLOAD_TRANSFER_BUFFERS = Types.enum_defined_field_count(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM);
            pub const NUM_DOWNLOAD_TRANSFER_BUFFERS = Types.enum_defined_field_count(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM);
            pub const NUM_VERTEX_BUFFERS = Types.enum_defined_field_count(VERTEX_BUFFER_NAMES_ENUM);
            pub const NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);
            pub const NUM_VERTEX_STRUCTS = Types.enum_defined_field_count(VERTEX_INPUT_STRUCT_NAMES_ENUM);
            pub const NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(STORAGE_BUFFER_NAMES_ENUM);
            pub const NUM_FENCES = Types.enum_defined_field_count(FENCE_NAMES_ENUM);
            pub const NUM_INDEX_BUFFERS = Types.enum_defined_field_count(INDEX_BUFFER_NAMES);
            pub const NUM_INDIRECT_BUFFERS = Types.enum_defined_field_count(INDIRECT_BUFFER_NAMES);
            pub const NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
            pub const NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
            pub const CREATE_OPTIONS = GPU_OPTIONS;

            pub const HAS_INDIRECT_BUFS = NUM_INDIRECT_BUFFERS > 0;
            pub const HAS_INDEX_BUFS = NUM_INDEX_BUFFERS > 0;
            pub const HAS_UPLOAD_BUFS = NUM_UPLOAD_TRANSFER_BUFFERS > 0;
            pub const HAS_DOWNLOAD_BUFS = NUM_DOWNLOAD_TRANSFER_BUFFERS > 0;
            pub const HAS_STORAGE_BUFS = NUM_STORAGE_BUFFERS > 0;
            pub const HAS_FENCES = NUM_FENCES > 0;
            pub const HAS_VERTEX_BUFFERS = NUM_VERTEX_BUFFERS > 0;

            pub const VERTEX_SHADER_DEFS = _VERTEX_SHADER_DEFS;
            pub const FRAGMENT_SHADER_DEFS = _FRAGMENT_SHADER_DEFS;

            pub const VERTEX_SHADER_UNIQUE_ENUM_STARTS = _VERTEX_SHADER_UNIQUE_ENUM_STARTS;
            pub const FRAGMENT_SHADER_UNIQUE_ENUM_STARTS = _FRAGMENT_SHADER_UNIQUE_ENUM_STARTS;
            pub const VERTEX_SHADER_UNIQUE_ENUMS = _VERTEX_SHADER_UNIQUE_ENUMS;
            pub const FRAGMENT_SHADER_UNIQUE_ENUMS = _FRAGMENT_SHADER_UNIQUE_ENUMS;

            pub const VERTEX_INPUT_STRUCT_TYPES = _VERTEX_INPUT_STRUCT_TYPES;
            pub const FRAGMENT_OUTPUT_STRUCT_TYPES = _FRAGMENT_OUTPUT_STRUCT_TYPES;
            pub const VERTEX_TO_FRAG_STRUCT_TYPES = _VERTEX_TO_FRAG_STRUCT_TYPES;

            pub const UNIFORM_TYPES = _UNIFORM_TYPES;
            pub const UNIFORM_SIZES = _UNIFORM_SIZES;
            pub const UNIFORM_OFFSETS = _UNIFORM_OFFSETS;

            pub const TEXTURE_DEFS = _TEXTURE_DEFS;
            pub const SAMPLER_DEFS = _SAMPLER_DEFS;
            pub const STORAGE_BUFFER_TYPES = _STORAGE_BUFFER_TYPES;
            pub const STORAGE_BUFFER_ELEM_SIZES = _STORAGE_BUFFER_SIZES;
            pub const STORAGE_BUFFER_USAGES = _STORAGE_BUFFER_USAGES;

            pub const LONGEST_VERTEX_BUFFER_SET = _LONGEST_SET_OF_VERTEX_BUFFERS;
            pub const LONGEST_STORAGE_BUFFER_SET_VERT = longest_storage_buffer_set_vert_const;
            pub const LONGEST_STORAGE_BUFFER_SET_FRAG = longest_storage_buffer_set_frag_const;
            pub const LONGEST_STORAGE_TEXTURE_SET_VERT = longest_storage_texture_set_vert_const;
            pub const LONGEST_STORAGE_TEXTURE_SET_FRAG = longest_storage_texture_set_frag_const;
            pub const LONGEST_SAMPLE_PAIR_SET_VERT = longest_sample_pair_set_vert_const;
            pub const LONGEST_SAMPLE_PAIR_SET_FRAG = longest_sample_pair_set_frag_const;

            pub const PIPELINE_DEFS = _RENDER_PIPELINE_DEFS;
            pub inline fn get_render_pipeline_info(pipeline: RenderPipelineName) _RenderPipelineDefinition {
                return PIPELINE_DEFS[@intFromEnum(pipeline)];
            }

            pub const ALLOWED_UNIFORMS_FLAT_FRAG = all_allowed_uniforms_flat_frag_const;
            pub const ALLOWED_UNIFORMS_FLAT_VERT = all_allowed_uniforms_flat_vert_const;
            pub const UNIFORMS_STARTS_FRAG = uniform_starts_frag_const;
            pub const UNIFORMS_STARTS_VERT = uniform_starts_vert_const;
            pub inline fn num_uniforms_for_frag_shader(frag_shader: FragmentShaderName) u32 {
                const idx = @intFromEnum(frag_shader);
                return UNIFORMS_STARTS_FRAG[idx + 1] - UNIFORMS_STARTS_FRAG[idx];
            }
            pub inline fn num_uniforms_for_vert_shader(vert_shader: VertexShaderName) u32 {
                const idx = @intFromEnum(vert_shader);
                return UNIFORMS_STARTS_VERT[idx + 1] - UNIFORMS_STARTS_VERT[idx];
            }
            pub inline fn allowed_uniforms_for_frag_shader(frag_shader: FragmentShaderName) []const _ShaderAllowedUniform {
                const idx = @intFromEnum(frag_shader);
                return ALLOWED_UNIFORMS_FLAT_FRAG[UNIFORMS_STARTS_FRAG[idx]..UNIFORMS_STARTS_FRAG[idx + 1]];
            }
            pub inline fn allowed_uniforms_for_vert_shader(vert_shader: VertexShaderName) []const _ShaderAllowedUniform {
                const idx = @intFromEnum(vert_shader);
                return ALLOWED_UNIFORMS_FLAT_VERT[UNIFORMS_STARTS_VERT[idx]..UNIFORMS_STARTS_VERT[idx + 1]];
            }
            pub fn uniform_register_for_pipeline_stage(pipeline: RenderPipelineName, uniform: UniformName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_uniforms_for_vert_shader(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.uniform == uniform) return allowed.register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_uniforms_for_frag_shader(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.uniform == uniform) return allowed.register;
                        }
                    },
                }
                return null;
            }

            pub const ALLOWED_STORAGE_BUFFERS_FLAT_FRAG = all_allowed_storage_buffers_flat_frag_const;
            pub const ALLOWED_STORAGE_BUFFERS_FLAT_VERT = all_allowed_storage_buffers_flat_vert_const;
            pub const STORAGE_BUFFERS_STARTS_FRAG = storage_buffer_starts_frag_const;
            pub const STORAGE_BUFFERS_STARTS_VERT = storage_buffer_starts_vert_const;
            pub inline fn num_storage_buffers_for_frag_shader(frag_shader: FragmentShaderName) u32 {
                const idx = @intFromEnum(frag_shader);
                return STORAGE_BUFFERS_STARTS_FRAG[idx + 1] - STORAGE_BUFFERS_STARTS_FRAG[idx];
            }
            pub inline fn num_storage_buffers_for_vert_shader(vert_shader: VertexShaderName) u32 {
                const idx = @intFromEnum(vert_shader);
                return STORAGE_BUFFERS_STARTS_VERT[idx + 1] - STORAGE_BUFFERS_STARTS_VERT[idx];
            }
            pub inline fn allowed_storage_buffers_for_frag_shaders(frag_shader: FragmentShaderName) []const _ShaderAllowedStorageBuffer {
                const idx = @intFromEnum(frag_shader);
                return ALLOWED_STORAGE_BUFFERS_FLAT_FRAG[STORAGE_BUFFERS_STARTS_FRAG[idx]..STORAGE_BUFFERS_STARTS_FRAG[idx + 1]];
            }
            pub inline fn allowed_storage_buffers_for_vert_shaders(vert_shader: VertexShaderName) []const _ShaderAllowedStorageBuffer {
                const idx = @intFromEnum(vert_shader);
                return ALLOWED_STORAGE_BUFFERS_FLAT_VERT[STORAGE_BUFFERS_STARTS_VERT[idx]..STORAGE_BUFFERS_STARTS_VERT[idx + 1]];
            }
            pub fn storage_buffer_register_for_render_pipeline_stage(pipeline: RenderPipelineName, buffer: StorageBufferName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_storage_buffers_for_vert_shaders(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.buffer == buffer) return allowed.cpu_register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_storage_buffers_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.buffer == buffer) return allowed.cpu_register;
                        }
                    },
                }
                return null;
            }

            pub const ALLOWED_STORAGE_TEXTURES_FLAT_FRAG = all_allowed_storage_textures_flat_frag_const;
            pub const ALLOWED_STORAGE_TEXTURES_FLAT_VERT = all_allowed_storage_textures_flat_vert_const;
            pub const STORAGE_TEXTURES_STARTS_FRAG = storage_texture_starts_frag_const;
            pub const STORAGE_TEXTURES_STARTS_VERT = storage_texture_starts_vert_const;
            pub inline fn num_storage_textures_for_frag_shader(frag_shader: FragmentShaderName) u32 {
                const idx = @intFromEnum(frag_shader);
                return STORAGE_TEXTURES_STARTS_FRAG[idx + 1] - STORAGE_TEXTURES_STARTS_FRAG[idx];
            }
            pub inline fn num_storage_textures_for_vert_shader(vert_shader: VertexShaderName) u32 {
                const idx = @intFromEnum(vert_shader);
                return STORAGE_TEXTURES_STARTS_VERT[idx + 1] - STORAGE_TEXTURES_STARTS_VERT[idx];
            }
            pub inline fn allowed_storage_textures_for_frag_shaders(frag_shader: FragmentShaderName) []const _ShaderAllowedStorageTexture {
                const idx = @intFromEnum(frag_shader);
                return ALLOWED_STORAGE_TEXTURES_FLAT_FRAG[STORAGE_TEXTURES_STARTS_FRAG[idx]..STORAGE_TEXTURES_STARTS_FRAG[idx + 1]];
            }
            pub inline fn allowed_storage_textures_for_vert_shaders(vert_shader: VertexShaderName) []const _ShaderAllowedStorageTexture {
                const idx = @intFromEnum(vert_shader);
                return ALLOWED_STORAGE_TEXTURES_FLAT_VERT[STORAGE_TEXTURES_STARTS_VERT[idx]..STORAGE_TEXTURES_STARTS_VERT[idx + 1]];
            }
            pub fn storage_texture_cpu_register_for_render_pipeline_stage(pipeline: RenderPipelineName, texture: TextureName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_storage_textures_for_vert_shaders(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.texture == texture) return allowed.cpu_register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_storage_textures_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.texture == texture) return allowed.cpu_register;
                        }
                    },
                }
                return null;
            }

            pub const ALLOWED_SAMPLERS_FLAT_FRAG = all_allowed_sample_pairs_flat_frag_const;
            pub const ALLOWED_SAMPLERS_FLAT_VERT = all_allowed_sample_pairs_flat_vert_const;
            pub const SAMPLERS_STARTS_FRAG = sample_pair_starts_frag_const;
            pub const SAMPLERS_STARTS_VERT = sample_pair_starts_vert_const;
            pub inline fn num_sample_pairs_for_frag_shader(frag_shader: FragmentShaderName) u32 {
                const idx = @intFromEnum(frag_shader);
                return SAMPLERS_STARTS_FRAG[idx + 1] - SAMPLERS_STARTS_FRAG[idx];
            }
            pub inline fn num_sample_pairs_for_vert_shader(vert_shader: VertexShaderName) u32 {
                const idx = @intFromEnum(vert_shader);
                return SAMPLERS_STARTS_VERT[idx + 1] - SAMPLERS_STARTS_VERT[idx];
            }
            pub inline fn allowed_sample_pairs_for_frag_shaders(frag_shader: FragmentShaderName) []const _ShaderAllowedSamplePair {
                const idx = @intFromEnum(frag_shader);
                return ALLOWED_SAMPLERS_FLAT_FRAG[SAMPLERS_STARTS_FRAG[idx]..SAMPLERS_STARTS_FRAG[idx + 1]];
            }
            pub inline fn allowed_sample_pairs_for_vert_shaders(vert_shader: VertexShaderName) []const _ShaderAllowedSamplePair {
                const idx = @intFromEnum(vert_shader);
                return ALLOWED_SAMPLERS_FLAT_VERT[SAMPLERS_STARTS_VERT[idx]..SAMPLERS_STARTS_VERT[idx + 1]];
            }
            pub fn sample_pair_cpu_register_for_render_pipeline_stage(pipeline: RenderPipelineName, sampler: SamplerName, texture: TextureName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_sample_pairs_for_vert_shaders(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.sampler == sampler and allowed.texture == texture) return allowed.cpu_register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_sample_pairs_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.sampler == sampler and allowed.texture == texture) return allowed.cpu_register;
                        }
                    },
                }
                return null;
            }

            pub const ALLOWED_VERTEX_BUFFER_NAMES_FOR_PIPELINE_FLAT = _VERTEX_BUFFER_NAMES_FOR_RENDER_PIPELINE;
            pub const ALLOWED_VERTEX_BUFFER_DEFS_FOR_PIPELINE_FLAT = _VERTEX_BUFFERS_TO_BIND_FOR_RENDER_PIPELINE;
            pub const VERTEX_BUFFER_NAMES_DEFS_START_LOCS = _VERTEX_BUFFERS_TO_BIND_START_LOCS;
            pub const ALLOWED_VERTEX_ATTRIBUTES_FOR_PIPELINE_FLAT = _VERTEX_ATTRS_TO_BIND_FOR_RENDER_PIPELINE;
            pub const RENDER_PIPELINE_VERT_SHADERS = _RENDER_PIPELINE_VERT_SHADERS;
            pub const RENDER_PIPELINE_FRAG_SHADERS = _RENDER_PIPELINE_FRAG_SHADERS;
            pub const VERTEX_ATTRIBUTE_START_LOCS = _VERTEX_ATTRS_TO_BIND_START_LOCS;
            pub const VERTEX_BUFFER_TYPES = _VERTEX_BUFFER_TYPES;
            pub const VERTEX_BUFFER_ELEM_SIZES = _VERTEX_BUFFER_SIZES;
            pub inline fn allowed_vertex_buffer_names_for_pipeline(pipeline: RenderPipelineName) []const VertexBufferName {
                const idx = @intFromEnum(pipeline);
                return ALLOWED_VERTEX_BUFFER_NAMES_FOR_PIPELINE_FLAT[VERTEX_BUFFER_NAMES_DEFS_START_LOCS[idx]..VERTEX_BUFFER_NAMES_DEFS_START_LOCS[idx + 1]];
            }
            pub inline fn allowed_vertex_buffer_defs_for_pipeline(pipeline: RenderPipelineName) []const SDL3.GPU_VertexBufferDescription {
                const idx = @intFromEnum(pipeline);
                return ALLOWED_VERTEX_BUFFER_DEFS_FOR_PIPELINE_FLAT[VERTEX_BUFFER_NAMES_DEFS_START_LOCS[idx]..VERTEX_BUFFER_NAMES_DEFS_START_LOCS[idx + 1]];
            }
            pub inline fn allowed_vertex_buffer_attributes_for_pipeline(pipeline: RenderPipelineName) []const SDL3.GPU_VertexAttribute {
                const idx = @intFromEnum(pipeline);
                return ALLOWED_VERTEX_ATTRIBUTES_FOR_PIPELINE_FLAT[VERTEX_ATTRIBUTE_START_LOCS[idx]..VERTEX_ATTRIBUTE_START_LOCS[idx + 1]];
            }
            pub fn vertex_buffer_def_for_buffer_name_for_pipeline(pipeline: RenderPipelineName, name: VertexBufferName) ?SDL3.GPU_VertexBufferDescription {
                if (vertex_buffer_local_index_for_pipeline(pipeline, name)) |idx| {
                    const allowed = allowed_vertex_buffer_defs_for_pipeline(pipeline);
                    return allowed[idx];
                }
                return null;
            }
            pub fn vertex_buffer_local_index_for_pipeline(pipeline: RenderPipelineName, name: VertexBufferName) ?u32 {
                const allowed = allowed_vertex_buffer_names_for_pipeline(pipeline);
                //TODO cache a map of vert buffer names to their indices in the allowed set to skip searching for them in this loop
                for (allowed, 0..) |allowed_name, a| {
                    if (allowed_name == name) {
                        return @intCast(a);
                    }
                }
                return null;
            }

            const INDEX_BUFFER_TAGS = _INDEX_BUFFER_TAGS;
            const INDEX_BUFFER_TYPES = _INDEX_BUFFER_TYPES;
            const INDEX_BUFFER_SIZES = _INDEX_BUFFER_SIZES;
            const INDIRECT_BUFFER_TYPES = _INDIRECT_BUFFER_TYPES;
            const INDIRECT_BUFFER_SIZES = _INDIRECT_BUFFER_SIZES;
            const INDIRECT_BUFFER_MODES = _INDIRECT_BUFFER_MODES;
        };

        pub const WindowName = WINDOW_NAMES_ENUM;
        pub const RenderPipelineName = RENDER_PIPELINE_NAMES_ENUM;
        pub const TextureName = TEXTURE_NAMES_ENUM;
        pub const UploadBufferName = UPLOAD_TRANSFER_BUFFER_NAMES_ENUM;
        pub const DownloadBufferName = DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM;
        pub const SamplerName = SAMPLER_NAMES_ENUM;
        pub const VertexBufferName = VERTEX_BUFFER_NAMES_ENUM;
        pub const VertexStructName = VERTEX_INPUT_STRUCT_NAMES_ENUM;
        pub const StorageBufferName = STORAGE_BUFFER_NAMES_ENUM;
        pub const UniformName = UNIFORM_NAMES_ENUM;
        pub const VertexShaderName = VERTEX_SHADER_NAMES_ENUM;
        pub const FragmentShaderName = FRAGMENT_SHADER_NAMES_ENUM;
        pub const UniformCollection = STRUCT_OF_UNIFORM_STRUCTS;
        pub const FenceName = FENCE_NAMES_ENUM;
        pub const IndexBufferName = INDEX_BUFFER_NAMES;
        pub const IndirectDrawBufferName = INDIRECT_BUFFER_NAMES;

        pub const WindowInit = struct {
            name: WindowName,
            title: [:0]const u8 = "New Window",
            flags: WindowFlags = WindowFlags{},
            size: Vec_c_int = Vec_c_int.new(800, 600),
            claim_on_init: bool = true,

            pub fn sdl_info(self: WindowInit) CreateWindowOptions {
                return CreateWindowOptions{
                    .flags = self.flags,
                    .size = self.size,
                    .title = self.title,
                };
            }
        };

        pub const RenderPipeInit = struct {
            name: RenderPipelineName,
            props: PropertiesID = .{},
        };

        pub const VertexShaderInit = struct {
            name: VertexShaderName,
            code: ShaderCode,
            props: PropertiesID = .{},

            pub fn sdl_info(self: VertexShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.code.ptr,
                    .code_size = self.code.code.len,
                    .entrypoint_func = self.code.entry_func_name,
                    .format = self.code.format,
                    .num_samplers = INTERNAL.num_sample_pairs_for_vert_shader(self.name),
                    .num_storage_buffers = INTERNAL.num_storage_buffers_for_vert_shader(self.name),
                    .num_storage_textures = INTERNAL.num_storage_textures_for_vert_shader(self.name),
                    .num_uniform_buffers = INTERNAL.num_uniforms_for_vert_shader(self.name),
                    .props = self.props,
                    .stage = .VERTEX,
                };
            }
        };

        pub const FragmentShaderInit = struct {
            name: FragmentShaderName,
            code: ShaderCode,
            props: PropertiesID = .{},

            fn sdl_info(self: FragmentShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.code.ptr,
                    .code_size = self.code.code.len,
                    .entrypoint_func = self.code.entry_func_name,
                    .format = self.code.format,
                    .num_samplers = INTERNAL.num_sample_pairs_for_frag_shader(self.name),
                    .num_storage_buffers = INTERNAL.num_storage_buffers_for_frag_shader(self.name),
                    .num_storage_textures = INTERNAL.num_storage_textures_for_frag_shader(self.name),
                    .num_uniform_buffers = INTERNAL.num_uniforms_for_frag_shader(self.name),
                    .props = self.props,
                    .stage = .FRAGMENT,
                };
            }
        };

        pub const TextureInit = struct {
            name: TextureName,
            width: u32 = 0,
            height: u32 = 0,
            layer_count_or_depth: u32 = 1,
            props: PropertiesID = .{},

            pub fn sdl_info(self: TextureInit) GPU_TextureCreateInfo {
                const tex_idx = @intFromEnum(self.name);
                const def = INTERNAL.TEXTURE_DEFS[tex_idx];
                return GPU_TextureCreateInfo{
                    .format = def.pixel_format,
                    .height = self.height,
                    .width = self.width,
                    .layer_count_or_depth = self.layer_count_or_depth,
                    .num_mip_levels = @max(def.mipmap_levels, 1),
                    .props = self.props,
                    .sample_count = def.sample_count,
                    .type = def.shape,
                    .usage = def.usage,
                };
            }
        };

        pub const SamplerInit = struct {
            name: SamplerName,
            settings: SamplerInitSettings = .default_sampler_settings(),
            props: PropertiesID = .{},

            pub fn sdl_info(self: SamplerInit) GPU_SamplerCreateInfo {
                switch (self.settings) {
                    .DEFAULT => {
                        const def = INTERNAL.SAMPLER_DEFS[@intFromEnum(self.name)];
                        return GPU_SamplerCreateInfo{
                            .address_mode_x = def.address_mode_x,
                            .address_mode_y = def.address_mode_y,
                            .address_mode_z = def.address_mode_z,
                            .compare_op = def.compare_op,
                            .enable_anisotropy = def.enable_anisotropy,
                            .enable_compare = def.enable_compare,
                            .mag_filter = def.mag_filter,
                            .max_anisotropy = def.max_anisotropy,
                            .max_lod = def.max_lod,
                            .min_filter = def.min_filter,
                            .min_lod = def.min_lod,
                            .mip_lod_bias = def.mip_lod_bias,
                            .mipmap_mode = def.mipmap_mode,
                            .props = self.props,
                        };
                    },
                    .CUSTOM => |set| {
                        return set;
                    },
                }
            }
        };

        pub const UploadBufferInit = struct {
            name: UploadBufferName,
            max_byte_size: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: UploadBufferInit) GPU_TransferBufferCreateInfo {
                return GPU_TransferBufferCreateInfo{
                    .props = self.props,
                    .size = self.max_byte_size,
                    .usage = .UPLOAD,
                };
            }
        };

        pub const DownloadBufferInit = struct {
            name: DownloadBufferName,
            max_byte_size: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: DownloadBufferInit) GPU_TransferBufferCreateInfo {
                return GPU_TransferBufferCreateInfo{
                    .props = self.props,
                    .size = self.max_byte_size,
                    .usage = .DOWNLOAD,
                };
            }
        };

        pub const VertexBufferInit = struct {
            name: VertexBufferName,
            max_element_count: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: VertexBufferInit) GPU_BufferCreateInfo {
                const idx = @intFromEnum(self.name);
                const SIZE = INTERNAL.VERTEX_BUFFER_ELEM_SIZES[idx];
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_element_count * SIZE,
                    .usage = GPU_BufferUsageFlags.flag(.VERTEX),
                };
            }
        };

        pub const StorageBufferInit = struct {
            name: StorageBufferName,
            max_element_count: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: StorageBufferInit) GPU_BufferCreateInfo {
                const idx = @intFromEnum(self.name);
                const SIZE = INTERNAL.STORAGE_BUFFER_ELEM_SIZES[idx];
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_element_count * SIZE,
                    .usage = INTERNAL.STORAGE_BUFFER_USAGES[idx],
                };
            }
        };

        pub const IndexBufferInit = struct {
            name: IndexBufferName,
            max_indices: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: IndexBufferInit) GPU_BufferCreateInfo {
                const SIZE: u32 = switch (INTERNAL.INDEX_BUFFER_TAGS[@intFromEnum(self.name)]) {
                    .U32 => 4,
                    .U16 => 2,
                };
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_indices * SIZE,
                    .usage = GPU_BufferUsageFlags.flag(.INDEX),
                };
            }
        };
        pub const IndirectDrawBufferInit = struct {
            name: IndirectDrawBufferName,
            draw_mode: VertexDrawMode = .VERTEX,
            max_indirect_draw_calls: u32 = 0,
            props: PropertiesID = .{},

            pub fn sdl_info(self: IndirectDrawBufferInit) GPU_BufferCreateInfo {
                const SIZE: u32 = switch (self.draw_mode) {
                    .VERTEX => @sizeOf(GPU_IndirectDrawCommand),
                    .INDEX => @sizeOf(GPU_IndexedIndirectDrawCommand),
                };
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_indirect_draw_calls * SIZE,
                    .usage = GPU_BufferUsageFlags.flag(.INDIRECT),
                };
            }
        };

        pub const CreateOptions = struct {
            vertex_shaders: [INTERNAL.NUM_VERTEX_SHADERS]VertexShaderInit,
            fragment_shaders: [INTERNAL.NUM_FRAGMENT_SHADERS]FragmentShaderInit,
            uniforms_init: UniformCollection,
            render_pipeline_init: []const RenderPipeInit = &.{},
            init_windows: []const WindowInit = &.{},
            init_samplers: []const SamplerInit = &.{},
            init_textures: []const TextureInit = &.{},
            init_vertex_buffers: []const VertexBufferInit = &.{},
            init_storage_buffers: []const StorageBufferInit = &.{},
            init_index_buffers: []const IndexBufferInit = &.{},
            init_indirect_buffers: []const IndirectDrawBufferInit = &.{},
            init_download_buffers: []const DownloadBufferInit = &.{},
            init_upload_buffers: []const UploadBufferInit = &.{},
            upload_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            download_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            vertex_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            storage_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            index_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            indirect_buffer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,
            cycle_unmapped_transfer_buffers_on_first_map_of_pass: bool = true,
            /// The allocator to use for internal state lists
            ///
            /// All lists must either NEVER run out of provided stack memory, or
            /// be allocated from this allocator
            internal_lists_alloc: Allocator = DummyAlloc.allocator_panic,
            /// IF provided, will initialize this internal list with the memory region
            ///
            /// If this is stack memory, it must never run out of space, or the provided Allocator
            /// must know how to deal with the stack memory
            ///
            /// If this is heap memory, it must have been allocated by the provided `internal_lists_alloc`
            upload_list_init_memory: ?[]CopyUploadDetails = null,
            /// IF provided, will initialize this internal list with the memory region
            ///
            /// If this is stack memory, it must never run out of space, or the provided Allocator
            /// must know how to deal with the stack memory
            ///
            /// If this is heap memory, it must have been allocated by the provided `internal_lists_alloc`
            download_list_init_memory: ?[]CopyDownloadDetails = null,
            /// IF provided, will initialize this internal list with the memory region
            ///
            /// If this is stack memory, it must never run out of space, or the provided Allocator
            /// must know how to deal with the stack memory
            ///
            /// If this is heap memory, it must have been allocated by the provided `internal_lists_alloc`
            grow_and_copy_gpu_buffer_list_init_memory: ?[]GrowAndCopyGPUBufferDetails = null,
            /// IF provided, will initialize this internal list with the memory region
            ///
            /// If this is stack memory, it must never run out of space, or the provided Allocator
            /// must know how to deal with the stack memory
            ///
            /// If this is heap memory, it must have been allocated by the provided `internal_lists_alloc`
            grow_and_copy_download_transfer_list_init_memory: ?[]GrowAndCopyDownloadTransferDetails = null,
            /// IF provided, will initialize this internal list with the memory region
            ///
            /// If this is stack memory, it must never run out of space, or the provided Allocator
            /// must know how to deal with the stack memory
            ///
            /// If this is heap memory, it must have been allocated by the provided `internal_lists_alloc`
            delete_buffers_list_init_memory: ?[]DeleteBufferDetails = null,
        };

        pub fn create(options: CreateOptions) !Controller {
            // CONTROLLER AND GPU
            var controller: Controller = .{};
            controller.gpu = try GPU_Device.create(INTERNAL.CREATE_OPTIONS);
            errdefer controller.gpu.destroy();
            // WINDOWS
            errdefer {
                for (0..INTERNAL.NUM_WINDOWS) |w| {
                    if (controller.windows_claimed[w]) {
                        controller.gpu.unclaim_window(controller.windows[w]);
                    }
                    if (controller.windows_init[w]) {
                        controller.windows[w].destroy();
                    }
                }
            }
            for (options.init_windows) |win| {
                const win_idx = @intFromEnum(win.name);
                controller.assert_window_NOT_initialized(win.name, @src());
                controller.assert_window_NOT_claimed(win.name, @src());
                const sdl_info = win.sdl_info();
                controller.windows[win_idx] = try Window.create(sdl_info);
                controller.windows_init[win_idx] = true;
                if (win.claim_on_init) {
                    try controller.gpu.claim_window(controller.windows[win_idx]);
                    controller.windows_claimed[win_idx] = true;
                }
            }
            // VERT_SHADERS
            var vert_shaders: [INTERNAL.NUM_VERTEX_SHADERS]*GPU_Shader = @splat(Utils.invalid_ptr(GPU_Shader));
            var vert_shaders_init: [INTERNAL.NUM_VERTEX_SHADERS]bool = @splat(false);
            defer {
                for (0..INTERNAL.NUM_VERTEX_SHADERS) |v| {
                    if (vert_shaders_init[v]) {
                        controller.gpu.release_shader(vert_shaders[v]);
                    }
                }
            }
            for (options.vertex_shaders[0..]) |vert| {
                const vert_idx = @intFromEnum(vert.name);
                assert_with_reason(vert_shaders_init[vert_idx] == false, @src(), "vertex shader `{s}` was initialized more than once", .{@tagName(vert.name)});
                assert_with_reason(INTERNAL.CREATE_OPTIONS.shader_formats.has_flag(vert.code.format), @src(), "vertex shader `{s}` has incompatible code format `{s}`", .{ @tagName(vert.name), @tagName(vert.code.format) });
                const sdl_info = vert.sdl_info();
                vert_shaders[vert_idx] = try controller.gpu.create_shader(sdl_info);
                vert_shaders_init[vert_idx] = true;
            }
            // FRAG SHADERS
            var frag_shaders: [INTERNAL.NUM_FRAGMENT_SHADERS]*GPU_Shader = @splat(Utils.invalid_ptr(GPU_Shader));
            var frag_shaders_init: [INTERNAL.NUM_FRAGMENT_SHADERS]bool = @splat(false);
            defer {
                for (0..INTERNAL.NUM_FRAGMENT_SHADERS) |f| {
                    if (frag_shaders_init[f]) {
                        controller.gpu.release_shader(frag_shaders[f]);
                    }
                }
            }
            for (options.fragment_shaders[0..]) |frag| {
                const frag_idx = @intFromEnum(frag.name);
                assert_with_reason(frag_shaders_init[frag_idx] == false, @src(), "fragment shader `{s}` was initialized more than once", .{@tagName(frag.name)});
                assert_with_reason(INTERNAL.CREATE_OPTIONS.shader_formats.has_flag(frag.code.format), @src(), "fragment shader `{s}` has incompatible code format `{s}`", .{ @tagName(frag.name), @tagName(frag.code.format) });
                const sdl_info = frag.sdl_info();
                frag_shaders[frag_idx] = try controller.gpu.create_shader(sdl_info);
                frag_shaders_init[frag_idx] = true;
            }
            // RENDER PIPELINES
            var pipelines_init: [INTERNAL.NUM_RENDER_PIPELINES]bool = @splat(false);
            var pipeline_props: [INTERNAL.NUM_RENDER_PIPELINES]PropertiesID = @splat(.{});
            var pipelines_props_init: [INTERNAL.NUM_RENDER_PIPELINES]bool = @splat(false);
            errdefer {
                for (0..INTERNAL.NUM_RENDER_PIPELINES) |r| {
                    if (pipelines_init[r]) {
                        controller.gpu.release_graphics_pipeline(controller.render_pipelines[r]);
                    }
                }
            }
            for (options.render_pipeline_init) |props| {
                const idx = @intFromEnum(props.name);
                assert_with_reason(pipelines_props_init[idx] == false, @src(), "render pipeline `{s}` was given props more than once", .{@tagName(props.name)});
                pipelines_props_init[idx] = true;
                pipeline_props[idx] = props.props;
            }
            for (0..INTERNAL.NUM_RENDER_PIPELINES) |r| {
                const def = INTERNAL.PIPELINE_DEFS[r];
                const vert = vert_shaders[@intFromEnum(def.vertex)];
                const frag = frag_shaders[@intFromEnum(def.fragment)];
                const attrs = INTERNAL.allowed_vertex_buffer_attributes_for_pipeline(@enumFromInt(r));
                const bufs = INTERNAL.allowed_vertex_buffer_defs_for_pipeline(@enumFromInt(r));
                const in_state = GPU_VertexInputState{
                    .vertex_attributes = attrs.ptr,
                    .num_vertex_attributes = @intCast(attrs.len),
                    .vertex_buffer_descriptions = bufs.ptr,
                    .num_vertex_buffers = @intCast(bufs.len),
                };
                const sdl_info = GPU_GraphicsPipelineCreateInfo{
                    .vertex_shader = vert,
                    .fragment_shader = frag,
                    .target_info = def.target_info,
                    .depth_stencil_state = def.depth_stencil_options,
                    .multisample_state = def.multisample_options,
                    .primitive_type = def.primitive_type,
                    .rasterizer_state = def.rasterizer_options,
                    .vertex_input_state = in_state,
                    .props = pipeline_props[r],
                };
                controller.render_pipelines[r] = try controller.gpu.create_graphics_pipeline(sdl_info);
                pipelines_init[r] = true;
                controller.render_pipelines_init[r] = true;
            }
            // TEXTURES
            if (comptime INTERNAL.NUM_TEXTURES > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_TEXTURES) |t| {
                        if (controller.textures_init[t]) {
                            controller.gpu.release_texture(controller.textures[t]);
                        }
                    }
                }
                for (options.init_textures) |tex| {
                    const tex_idx = @intFromEnum(tex.name);
                    controller.assert_texture_NOT_initialized(tex.name, @src());
                    const sdl_info = tex.sdl_info();
                    controller.textures[tex_idx] = try controller.gpu.create_texture(sdl_info);
                    controller.textures_init[tex_idx] = true;
                    controller.textures_sizes[tex_idx] = .new(tex.width, tex.height, tex.layer_count_or_depth);
                }
            }
            // SAMPLERS
            if (comptime INTERNAL.NUM_SAMPLERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_SAMPLERS) |s| {
                        if (controller.samplers_init[s]) {
                            controller.gpu.release_texture_sampler(controller.samplers[s]);
                        }
                    }
                }
                for (options.init_samplers) |init| {
                    const idx = @intFromEnum(init.name);
                    const sdl_info = init.sdl_info();
                    controller.samplers[idx] = try controller.gpu.create_texture_sampler(sdl_info);
                    controller.samplers_init[idx] = true;
                }
            }
            // UPLOAD BUFFERS
            if (comptime INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS) |ub| {
                        if (controller.upload_buffers_init[ub]) {
                            controller.gpu.release_transfer_buffer(controller.upload_buffers[ub]);
                        }
                    }
                }
                for (options.init_upload_buffers) |buf| {
                    const buf_idx = @intFromEnum(buf.name);
                    controller.assert_upload_buffer_NOT_initialized(buf.name, @src());
                    const sdl_info = buf.sdl_info();
                    controller.upload_buffers[buf_idx] = try controller.gpu.create_transfer_buffer(sdl_info);
                    controller.upload_buffers_init[buf_idx] = true;
                    controller.upload_buffer_byte_caps[buf_idx] = buf.max_byte_size;
                }
            }

            // DOWNLOAD BUFFERS
            if (comptime INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS) |db| {
                        if (controller.download_buffers_init[db]) {
                            controller.gpu.release_transfer_buffer(controller.download_buffers[db]);
                        }
                    }
                }
                for (options.init_download_buffers) |buf| {
                    const buf_idx = @intFromEnum(buf.name);
                    controller.assert_download_buffer_NOT_initialized(buf.name, @src());
                    const sdl_info = buf.sdl_info();
                    controller.download_buffers[buf_idx] = try controller.gpu.create_transfer_buffer(sdl_info);
                    controller.download_buffers_init[buf_idx] = true;
                    controller.download_buffer_byte_caps[buf_idx] = buf.max_byte_size;
                }
            }
            // VERTEX BUFFERS
            errdefer {
                for (0..INTERNAL.NUM_VERTEX_BUFFERS) |vb| {
                    if (controller.vertex_buffers_init[vb]) {
                        controller.gpu.release_buffer(controller.vertex_buffers[vb]);
                    }
                }
            }
            for (options.init_vertex_buffers) |buf| {
                const buf_idx = @intFromEnum(buf.name);
                controller.assert_vert_buffer_NOT_initialized(buf.name, @src());
                const sdl_info = buf.sdl_info();
                controller.vertex_buffers[buf_idx] = try controller.gpu.create_buffer(sdl_info);
                controller.vertex_buffers_init[buf_idx] = true;
                controller.vertex_buffer_byte_caps[buf_idx] = sdl_info.size;
            }
            // STORAGE BUFFERS
            if (comptime INTERNAL.NUM_STORAGE_BUFFERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_STORAGE_BUFFERS) |sb| {
                        if (controller.storage_buffers_init[sb]) {
                            controller.gpu.release_buffer(controller.storage_buffers[sb]);
                        }
                    }
                }
                for (options.init_storage_buffers) |buf| {
                    const buf_idx = @intFromEnum(buf.name);
                    controller.assert_storage_buffer_NOT_initialized(buf.name, @src());
                    const sdl_info = buf.sdl_info();
                    controller.storage_buffers[buf_idx] = try controller.gpu.create_buffer(sdl_info);
                    controller.storage_buffers_init[buf_idx] = true;
                    controller.storage_buffer_byte_caps[buf_idx] = sdl_info.size;
                }
            }
            // INDEX BUFFERS
            if (comptime INTERNAL.NUM_INDEX_BUFFERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_INDEX_BUFFERS) |ib| {
                        if (controller.index_buffers_init[ib]) {
                            controller.gpu.release_buffer(controller.index_buffers[ib]);
                        }
                    }
                }
                for (options.init_index_buffers) |buf| {
                    const buf_idx = @intFromEnum(buf.name);
                    controller.assert_index_buffer_NOT_initialized(buf.name, @src());
                    const sdl_info = buf.sdl_info();
                    controller.index_buffers[buf_idx] = try controller.gpu.create_buffer(sdl_info);
                    controller.index_buffers_init[buf_idx] = true;
                    controller.index_buffer_byte_caps[buf_idx] = sdl_info.size;
                }
            }
            // INDIRECT BUFFERS
            if (comptime INTERNAL.NUM_INDIRECT_BUFFERS > 0) {
                errdefer {
                    for (0..INTERNAL.NUM_INDIRECT_BUFFERS) |ib| {
                        if (controller.indirect_draw_buffers_init[ib]) {
                            controller.gpu.release_buffer(controller.indirect_draw_buffers[ib]);
                        }
                    }
                }
                for (options.init_indirect_buffers) |buf| {
                    const buf_idx = @intFromEnum(buf.name);
                    controller.assert_indirect_buffer_NOT_initialized(buf.name, @src());
                    const sdl_info = buf.sdl_info();
                    controller.indirect_draw_buffers[buf_idx] = try controller.gpu.create_buffer(sdl_info);
                    controller.indirect_draw_buffers_init[buf_idx] = true;
                    controller.indirect_draw_buffer_byte_caps[buf_idx] = sdl_info.size;
                }
            }
            // UNIFORMS
            controller.uniforms = options.uniforms_init;
            // GROW MODES
            controller.cycle_unmapped_upload_buffers = options.cycle_unmapped_transfer_buffers_on_first_map_of_pass;
            controller.index_buffer_grow_mode = options.index_buffer_grow_mode;
            controller.vertex_buffer_grow_mode = options.vertex_buffer_grow_mode;
            controller.upload_buffer_grow_mode = options.upload_buffer_grow_mode;
            controller.download_buffer_grow_mode = options.download_buffer_grow_mode;
            controller.indirect_draw_buffer_grow_mode = options.indirect_buffer_grow_mode;
            // LISTS
            controller.list_alloc = options.internal_lists_alloc;
            if (options.upload_list_init_memory) |mem| {
                controller.upload_list = .from_slice_keep_data(mem);
            }
            if (options.download_list_init_memory) |mem| {
                controller.download_list = .from_slice_keep_data(mem);
            }
            if (options.grow_and_copy_download_transfer_list_init_memory) |mem| {
                controller.grow_and_copy_download_transfer_list = .from_slice_keep_data(mem);
            }
            if (options.grow_and_copy_gpu_buffer_list_init_memory) |mem| {
                controller.grow_and_copy_gpu_buffer_list = .from_slice_keep_data(mem);
            }
            if (options.delete_buffers_list_init_memory) |mem| {
                controller.release_buffers_list = .from_slice_keep_data(mem);
            }
            controller.stage = .READY_FOR_NEXT_COMMAND_CYCLE;
            return controller;
        }

        pub fn destroy(self: *Controller) void {
            for (0..INTERNAL.NUM_VERTEX_BUFFERS) |vb| {
                if (self.vertex_buffers_init[vb]) {
                    self.gpu.release_buffer(self.vertex_buffers[vb]);
                }
            }
            for (0..INTERNAL.NUM_STORAGE_BUFFERS) |sb| {
                if (self.storage_buffers_init[sb]) {
                    self.gpu.release_buffer(self.storage_buffers[sb]);
                }
            }
            for (0..INTERNAL.NUM_INDEX_BUFFERS) |ib| {
                if (self.index_buffers_init[ib]) {
                    self.gpu.release_buffer(self.index_buffers[ib]);
                }
            }
            for (0..INTERNAL.NUM_INDIRECT_BUFFERS) |idb| {
                if (self.indirect_draw_buffers_init[idb]) {
                    self.gpu.release_buffer(self.indirect_draw_buffers[idb]);
                }
            }
            for (0..INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS) |db| {
                if (self.mapped_download_buffers[db]) {
                    self.gpu.unmap_transfer_buffer(self.download_buffers[db]);
                }
                if (self.download_buffers_init[db]) {
                    self.gpu.release_transfer_buffer(self.download_buffers[db]);
                }
            }
            for (0..INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS) |ub| {
                if (self.mapped_upload_buffers[ub]) {
                    self.gpu.unmap_transfer_buffer(self.upload_buffers[ub]);
                }
                if (self.upload_buffers_init[ub]) {
                    self.gpu.release_transfer_buffer(self.upload_buffers[ub]);
                }
            }
            for (0..INTERNAL.NUM_SAMPLERS) |s| {
                if (self.samplers_init[s]) {
                    self.gpu.release_texture_sampler(self.samplers[s]);
                }
            }
            for (0..INTERNAL.NUM_TEXTURES) |t| {
                if (self.textures_init[t]) {
                    self.gpu.release_texture(self.textures[t]);
                }
            }
            for (0..INTERNAL.NUM_RENDER_PIPELINES) |r| {
                if (self.render_pipelines_init[r]) {
                    self.gpu.release_graphics_pipeline(self.render_pipelines[r]);
                }
            }
            for (0..INTERNAL.NUM_WINDOWS) |w| {
                if (self.windows_claimed[w]) {
                    self.gpu.unclaim_window(self.windows[w]);
                }
                if (self.windows_init[w]) {
                    self.windows[w].destroy();
                }
            }
            for (0..INTERNAL.NUM_FENCES) |f| {
                if (self.fences_init[f]) {
                    self.gpu.release_fence(self.fences[f]);
                    self.fences_init[f] = false;
                }
            }
            for (self.release_buffers_list.zig_slice_entire()) |to_delete| {
                self.gpu.release_buffer(to_delete.buf);
            }
            self.upload_list.free_if_non_zero(self.list_alloc);
            self.download_list.free_if_non_zero(self.list_alloc);
            self.grow_and_copy_download_transfer_list.free_if_non_zero(self.list_alloc);
            self.grow_and_copy_gpu_buffer_list.free_if_non_zero(self.list_alloc);
            self.release_buffers_list.free_if_non_zero(self.list_alloc);
            self.gpu.destroy();
            self.stage = .UNINITIALIZED;
            self.* = undefined;
        }

        pub fn create_window(self: *Controller, init: WindowInit) !void {
            self.assert_window_NOT_initialized(init.name, @src());
            self.assert_window_NOT_claimed(init.name, @src());
            const idx = @intFromEnum(init.name);
            self.windows[idx] = try Window.create(init.sdl_info());
            self.windows_init[idx] = true;
        }
        pub fn destroy_window(self: *Controller, name: WindowName) void {
            self.assert_window_initialized(name, @src());
            const idx = @intFromEnum(name);
            if (self.windows_claimed[idx]) {
                self.gpu.unclaim_window(self.windows[idx]);
                self.windows_claimed[idx] = false;
            }
            self.windows[idx].destroy();
            self.windows_init[@intFromEnum(name)] = false;
        }
        pub fn claim_window(self: *Controller, name: WindowName) !void {
            self.assert_window_initialized(name, @src());
            const idx = @intFromEnum(name);
            if (self.windows_claimed[idx]) return;
            try self.gpu.claim_window(self.windows[idx]);
            self.windows_claimed[idx] = true;
        }
        pub fn unclaim_window(self: *Controller, name: WindowName) void {
            self.assert_window_initialized(name, @src());
            const idx = @intFromEnum(name);
            if (!self.windows_claimed[idx]) return;
            self.gpu.unclaim_window(self.windows[idx]);
            self.windows_claimed[idx] = false;
        }
        pub fn create_and_claim_window(self: *Controller, init: WindowInit) !void {
            try self.create_window(init);
            try self.claim_window(init.name);
        }
        pub fn release_and_destroy_window(self: *Controller, name: WindowName) void {
            self.unclaim_window(name);
            self.destroy_window(name);
        }

        pub fn create_sampler(self: *Controller, init: SamplerInit) !void {
            self.assert_sampler_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.samplers[idx] = try self.gpu.create_texture_sampler(sdl_info);
            self.samplers_init[idx] = true;
        }
        pub fn destroy_sampler(self: *Controller, name: SamplerName) void {
            self.assert_sampler_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_texture_sampler(self.samplers[idx]);
            self.samplers_init[idx] = false;
        }

        pub fn create_texture(self: *Controller, init: TextureInit) !void {
            self.assert_texture_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.textures[idx] = try self.gpu.create_texture(sdl_info);
            self.textures_init[idx] = true;
            self.textures_sizes[idx] = .new(init.width, init.height, init.layer_count_or_depth);
        }
        pub fn destroy_texture(self: *Controller, name: TextureName) void {
            self.assert_texture_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_texture(self.textures[idx]);
            self.textures_init[idx] = false;
            self.textures_sizes[idx] = .ZERO;
        }

        pub fn create_vertex_buffer(self: *Controller, init: VertexBufferInit) !void {
            self.assert_vert_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.vertex_buffers[idx] = try self.gpu.create_buffer(sdl_info);
            self.vertex_buffers_init[idx] = true;
            self.vertex_buffer_byte_caps[idx] = sdl_info.size;
        }
        pub fn destroy_vertex_buffer(self: *Controller, name: VertexBufferName) void {
            self.assert_vert_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_buffer(self.vertex_buffers[idx]);
            self.vertex_buffers_init[idx] = false;
            self.vertex_buffer_byte_caps[idx] = 0;
        }

        pub fn create_storage_buffer(self: *Controller, init: StorageBufferInit) !void {
            self.assert_storage_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.storage_buffers[idx] = try self.gpu.create_buffer(sdl_info);
            self.storage_buffers_init[idx] = true;
            self.storage_buffer_byte_caps[idx] = sdl_info.size;
        }
        pub fn destroy_storage_buffer(self: *Controller, name: StorageBufferName) void {
            self.assert_storage_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_buffer(self.storage_buffers[idx]);
            self.storage_buffers_init[idx] = false;
            self.storage_buffer_byte_caps[idx] = 0;
        }

        pub fn create_index_buffer(self: *Controller, init: IndexBufferInit) !void {
            self.assert_index_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.index_buffers[idx] = try self.gpu.create_buffer(sdl_info);
            self.index_buffers_init[idx] = true;
            self.index_buffer_byte_caps[idx] = sdl_info.size;
        }
        pub fn destroy_index_buffer(self: *Controller, name: IndexBufferName) void {
            self.assert_index_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_buffer(self.index_buffers[idx]);
            self.index_buffers_init[idx] = false;
            self.index_buffer_byte_caps[idx] = 0;
        }

        pub fn create_indirect_draw_call_buffer(self: *Controller, init: IndirectDrawBufferInit) !void {
            self.assert_indirect_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.indirect_draw_buffers[idx] = try self.gpu.create_buffer(sdl_info);
            self.indirect_draw_buffers_init[idx] = true;
            self.indirect_draw_buffer_byte_caps[idx] = sdl_info.size;
        }
        pub fn destroy_indirect_draw_call_buffer(self: *Controller, name: IndirectDrawBufferName) void {
            self.assert_indirect_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_buffer(self.indirect_draw_buffers[idx]);
            self.indirect_draw_buffers_init[idx] = false;
            self.indirect_draw_buffer_byte_caps[idx] = 0;
        }

        pub fn create_upload_buffer(self: *Controller, init: UploadBufferInit) !void {
            self.assert_upload_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.upload_buffers[idx] = try self.gpu.create_transfer_buffer(sdl_info);
            self.upload_buffers_init[idx] = true;
            self.upload_buffer_byte_caps[idx] = init.max_byte_size;
        }
        pub fn destroy_upload_buffer(self: *Controller, name: UploadBufferName) void {
            self.assert_upload_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_transfer_buffer(self.upload_buffers[idx]);
            self.upload_buffers_init[idx] = false;
            self.upload_buffer_byte_caps[idx] = 0;
        }

        pub fn create_download_buffer(self: *Controller, init: DownloadBufferInit) !void {
            self.assert_download_buffer_NOT_initialized(init.name, @src());
            const idx = @intFromEnum(init.name);
            const sdl_info = init.sdl_info();
            self.download_buffers[idx] = try self.gpu.create_transfer_buffer(sdl_info);
            self.download_buffers_init[idx] = true;
            self.download_buffer_byte_caps[idx] = init.max_byte_size;
        }
        pub fn destroy_download_buffer(self: *Controller, name: DownloadBufferName) void {
            self.assert_download_buffer_initialized(name, @src());
            const idx = @intFromEnum(name);
            self.gpu.release_transfer_buffer(self.download_buffers[idx]);
            self.download_buffers_init[idx] = false;
            self.download_buffer_byte_caps[idx] = 0;
        }

        pub fn destroy_fence(self: *Controller, fence: FenceName) void {
            self.assert_fence_initialized(fence, @src());
            const idx = @intFromEnum(fence);
            self.gpu.release_fence(self.fences[idx]);
            self.fences_init[idx] = false;
        }

        pub fn write_all_shader_templates(template_folder_relative_path: []const u8, io: std.Io) anyerror!void {
            try std.Io.Dir.cwd().createDirPath(io, template_folder_relative_path);
            const dir = try std.Io.Dir.cwd().openDir(io, template_folder_relative_path, .{});
            var write_buf: [1024]u8 = undefined;
            var shell_write_buf: [1024]u8 = undefined;
            const shell_file = try dir.createFile(io, "compile_shaders.sh", .{
                .permissions = .executable_file,
            });
            defer shell_file.close(io);
            var shell_writer_impl = shell_file.writer(io, shell_write_buf[0..]);
            var shell_writer = &shell_writer_impl.interface;
            inline for (INTERNAL.VERTEX_SHADER_DEFS) |def| {
                const BASE_NAME: [:0]const u8 = "vert_" ++ @tagName(def.vertex_shader);
                const HLSL_NAME: [:0]const u8 = BASE_NAME ++ ".hlsl";
                const TEMP_NAME: [:0]const u8 = HLSL_NAME ++ ".template";
                var tag_iter = GPU_OPTIONS.shader_formats.iterator();
                next_tag: while (tag_iter.next()) |tag| {
                    switch (tag) {
                        .DXBC => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d DXBC -t vertex -e \"main\" -o " ++ BASE_NAME ++ ".dxbc\n");
                        },
                        .DXIL => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d DXIL -t vertex -e \"main\" -o " ++ BASE_NAME ++ ".dxil\n");
                        },
                        .MSL => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d MSL -t vertex -e \"main\" -o " ++ BASE_NAME ++ ".msl\n");
                        },
                        .SPIRV => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d SPIRV -t vertex -e \"main\" -o " ++ BASE_NAME ++ ".spv\n");
                        },
                        else => {
                            continue :next_tag;
                        },
                    }
                }
                const file = try dir.createFile(io, TEMP_NAME, .{});
                defer file.close(io);
                var writer_impl = file.writer(io, write_buf[0..]);
                var writer = &writer_impl.interface;
                const V_IN = AnyVertexShaderInputStruct(INTERNAL.VERTEX_INPUT_STRUCT_TYPES[@intFromEnum(def.input_type)], VERTEX_BUFFER_NAMES_ENUM);
                const V_OUT = AnyVertexToFragmentStruct(INTERNAL.VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.output_type)]);
                const enum_start = INTERNAL.VERTEX_SHADER_UNIQUE_ENUM_STARTS[@intFromEnum(def.vertex_shader)];
                const enum_end = INTERNAL.VERTEX_SHADER_UNIQUE_ENUM_STARTS[@intFromEnum(def.vertex_shader) + 1];
                inline for (INTERNAL.VERTEX_SHADER_UNIQUE_ENUMS[enum_start..enum_end]) |enum_type| {
                    try ShaderUtils.write_hlsl_enum_stub(enum_type, writer);
                }
                try writer.writeByte('\n');
                inline for (INTERNAL.allowed_sample_pairs_for_vert_shaders(def.vertex_shader)) |pair| {
                    try write_sampled_texture_pair(writer, pair, .VERTEX);
                }
                inline for (INTERNAL.allowed_storage_textures_for_vert_shaders(def.vertex_shader)) |storage_tex| {
                    try write_read_only_storage_texture(writer, storage_tex, .VERTEX);
                }
                inline for (INTERNAL.allowed_storage_buffers_for_vert_shaders(def.vertex_shader)) |storage_buf| {
                    try write_storage_buffer(writer, storage_buf, .VERTEX);
                }
                inline for (INTERNAL.allowed_uniforms_for_vert_shader(def.vertex_shader)) |uniform| {
                    try write_uniform(writer, uniform, .VERTEX);
                }
                try V_IN.write_hlsl_vertex_stub(writer);
                try V_OUT.write_hlsl_vert_stub(writer);
                try writer.writeAll(V_OUT.STRUCT_NAME_PACKED ++ " main(" ++ V_IN.STRUCT_NAME_PACKED ++ " pck) {\n    " ++ V_IN.STRUCT_NAME ++ " vert_in = unpack_vertex_input(pck);\n    " ++ V_OUT.STRUCT_NAME ++ " vert_out;\n    // SHADER LOGIC\n    return pack_vertex_output(vert_out);\n}");
                try writer.flush();
            }
            inline for (INTERNAL.FRAGMENT_SHADER_DEFS) |def| {
                const BASE_NAME: [:0]const u8 = "frag_" ++ @tagName(def.fragment_shader);
                const HLSL_NAME: [:0]const u8 = BASE_NAME ++ ".hlsl";
                const TEMP_NAME: [:0]const u8 = HLSL_NAME ++ ".template";
                var tag_iter = GPU_OPTIONS.shader_formats.iterator();
                next_tag: while (tag_iter.next()) |tag| {
                    switch (tag) {
                        .DXBC => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d DXBC -t fragment -e \"main\" -o " ++ BASE_NAME ++ ".dxbc\n");
                        },
                        .DXIL => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d DXIL -t fragment -e \"main\" -o " ++ BASE_NAME ++ ".dxil\n");
                        },
                        .MSL => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d MSL -t fragment -e \"main\" -o " ++ BASE_NAME ++ ".msl\n");
                        },
                        .SPIRV => {
                            try shell_writer.writeAll("shadercross " ++ HLSL_NAME ++ " -s HLSL -d SPIRV -t fragment -e \"main\" -o " ++ BASE_NAME ++ ".spv\n");
                        },
                        else => {
                            continue :next_tag;
                        },
                    }
                }
                const file = try dir.createFile(io, TEMP_NAME, .{});
                defer file.close(io);
                var writer_impl = file.writer(io, write_buf[0..]);
                var writer = &writer_impl.interface;
                const F_IN = AnyVertexToFragmentStruct(INTERNAL.VERTEX_TO_FRAG_STRUCT_TYPES[@intFromEnum(def.input_type)]);
                const F_OUT = AnyFragmentShaderOutputStruct(INTERNAL.FRAGMENT_OUTPUT_STRUCT_TYPES[@intFromEnum(def.output_type)]);
                const enum_start = INTERNAL.FRAGMENT_SHADER_UNIQUE_ENUM_STARTS[@intFromEnum(def.fragment_shader)];
                const enum_end = INTERNAL.FRAGMENT_SHADER_UNIQUE_ENUM_STARTS[@intFromEnum(def.fragment_shader) + 1];
                inline for (INTERNAL.FRAGMENT_SHADER_UNIQUE_ENUMS[enum_start..enum_end]) |enum_type| {
                    try ShaderUtils.write_hlsl_enum_stub(enum_type, writer);
                }
                try writer.writeByte('\n');
                inline for (INTERNAL.allowed_sample_pairs_for_frag_shaders(def.fragment_shader)) |pair| {
                    try write_sampled_texture_pair(writer, pair, .FRAGMENT);
                }
                inline for (INTERNAL.allowed_storage_textures_for_frag_shaders(def.fragment_shader)) |storage_tex| {
                    try write_read_only_storage_texture(writer, storage_tex, .FRAGMENT);
                }
                inline for (INTERNAL.allowed_storage_buffers_for_frag_shaders(def.fragment_shader)) |storage_buf| {
                    try write_storage_buffer(writer, storage_buf, .FRAGMENT);
                }
                inline for (INTERNAL.allowed_uniforms_for_frag_shader(def.fragment_shader)) |uniform| {
                    try write_uniform(writer, uniform, .FRAGMENT);
                }
                try F_IN.write_hlsl_frag_stub(writer);
                try F_OUT.write_hlsl_fragment_output_structs(writer);
                try writer.writeAll(F_OUT.STRUCT_NAME_PACKED ++ " main(" ++ F_IN.STRUCT_NAME_PACKED ++ " pck) {\n    " ++ F_IN.STRUCT_NAME ++ " frag_in = unpack_frag_input(pck);\n    " ++ F_OUT.STRUCT_NAME ++ " frag_out;\n    // SHADER LOGIC\n    return pack_fragment_output(frag_out);\n}");
                try writer.flush();
            }
            try shell_writer.flush();
        }

        fn write_sampled_texture_pair(writer: *std.Io.Writer, comptime pair: _ShaderAllowedSamplePair, comptime stage: ShaderStage) std.Io.Writer.Error!void {
            const space = comptime switch (stage) {
                .VERTEX => "space0",
                .FRAGMENT => "space2",
            };
            const TEX_DEF = INTERNAL.TEXTURE_DEFS[@intFromEnum(pair.texture)];
            const TEX_TYPE = switch (TEX_DEF.shape) {
                ._2D => "Texture2D<",
                ._2D_ARRAY => "Texture2DArray<",
                ._3D => "Texture3D<",
                .CUBE => "TextureCube<",
                .CUBE_ARRAY => "TextureCubeArray<",
            };
            const TEX_SUB_TYPE = comptime if (std.mem.endsWith(u8, @tagName(TEX_DEF.pixel_format), "_INT")) "int4> " else if (std.mem.endsWith(u8, @tagName(TEX_DEF.pixel_format), "_UINT")) "uint4> " else "float4> ";
            try writer.writeAll(TEX_TYPE ++ TEX_SUB_TYPE ++ @tagName(pair.texture) ++ " : register(t");
            try writer.printInt(pair.gpu_register, 10, .lower, .{});
            try writer.writeAll(", " ++ space ++ ");\nSamplerState " ++ @tagName(pair.sampler) ++ " : register(s");
            try writer.printInt(pair.gpu_register, 10, .lower, .{});
            try writer.writeAll(", " ++ space ++ ");\n\n");
        }

        fn write_read_only_storage_texture(writer: *std.Io.Writer, comptime def: _ShaderAllowedStorageTexture, comptime stage: ShaderStage) std.Io.Writer.Error!void {
            const space = comptime switch (stage) {
                .VERTEX => "space0",
                .FRAGMENT => "space2",
            };
            const TEX_DEF = INTERNAL.TEXTURE_DEFS[@intFromEnum(def.texture)];
            const TEX_TYPE = switch (TEX_DEF.shape) {
                ._2D => "Texture2D<",
                ._2D_ARRAY => "Texture2DArray<",
                ._3D => "Texture3D<",
                .CUBE => "TextureCube<",
                .CUBE_ARRAY => "TextureCubeArray<",
            };
            const TEX_SUB_TYPE = comptime if (std.mem.endsWith(u8, @tagName(TEX_DEF.pixel_format), "_INT")) "int4> " else if (std.mem.endsWith(u8, @tagName(TEX_DEF.pixel_format), "_UINT")) "uint4> " else "float4> ";
            try writer.writeAll(TEX_TYPE ++ TEX_SUB_TYPE ++ @tagName(def.texture) ++ " : register(t");
            try writer.printInt(def.gpu_register, 10, .lower, .{});
            try writer.writeAll(", " ++ space ++ ");\n\n");
        }

        fn write_storage_buffer(writer: *std.Io.Writer, comptime def: _ShaderAllowedStorageBuffer, comptime stage: ShaderStage) std.Io.Writer.Error!void {
            const space = comptime switch (stage) {
                .VERTEX => 0,
                .FRAGMENT => 2,
            };
            const STORAGE = AnyUniformOrStorageStruct(INTERNAL.STORAGE_BUFFER_TYPES[@intFromEnum(def.buffer)]);
            try STORAGE.write_hlsl_storage_buffer_stub(@tagName(def.buffer), @tagName(def.buffer) ++ "_BUFFER", @intCast(def.gpu_register), space, writer);
            try writer.writeByte('\n');
        }

        fn write_uniform(writer: *std.Io.Writer, comptime def: _ShaderAllowedUniform, comptime stage: ShaderStage) std.Io.Writer.Error!void {
            const space = comptime switch (stage) {
                .VERTEX => 1,
                .FRAGMENT => 3,
            };
            const UNI = AnyUniformOrStorageStruct(INTERNAL.UNIFORM_TYPES[@intFromEnum(def.uniform)]);
            try UNI.write_hlsl_uniform_stub(@tagName(def.uniform), @intCast(def.register), space, writer);
            try writer.writeByte('\n');
        }
    };
}

pub const SurfaceWrapper = struct {
    s: *SDL3.Surface,
};
