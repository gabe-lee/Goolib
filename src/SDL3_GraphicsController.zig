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
const List = Root.IList.List;
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

const ShaderContract = SDL3.ShaderContract;
const StorageStructField = ShaderContract.StorageStructField;
const StorageStruct = ShaderContract.StorageStruct;
const GPUType = ShaderContract.GPUType;
const ErrorBehavior = Common.ErrorBehavior;

const ct_assert_with_reason = Assert.assert_with_reason;
const ct_assert_unreachable = Assert.assert_unreachable;
const ct_assert_unreachable_err = Assert.assert_unreachable_err;
const update_max = Utils.update_max;
const update_min = Utils.update_min;
const num_cast = Cast.num_cast;
const bytes_cast = Cast.bytes_cast;
const bytes_cast_element_type = Cast.bytes_cast_element_type;

const INVALID_ADDR = math.maxInt(usize);

pub const TargetKind = enum(u8) {
    WINDOW,
    TEXTURE,
};

pub const VertexDrawMode = enum(u8) {
    VERTEX,
    INDEX,
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

// pub const RegisterKind = enum(u8) {
//     TEXTURE, // HLSL 't0'
//     SAMPLER, // HLSL 's0'
//     UNORDERED, // HLSL 'u0'
//     BUFFER, // HLSL 'b0'
// };

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
        register: u32,

        pub fn equals_register(a: Self, b: Self) bool {
            return a.register == b.register;
        }
        pub fn register_greater(a: Self, b: Self) bool {
            return a.register > b.register;
        }
    };
}
pub fn ShaderAllowedStorageTexture(comptime STORAGE_TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: STORAGE_TEXTURE_NAMES_ENUM,
        register: u32,

        pub fn equals_register(a: Self, b: Self) bool {
            return a.register == b.register;
        }
        pub fn register_greater(a: Self, b: Self) bool {
            return a.register > b.register;
        }
    };
}

pub fn ShaderAllowedSamplePair(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        combined_id: Types.Combined2EnumInt(SAMPLER_NAMES_ENUM, TEXTURE_NAMES_ENUM).combined_type = 0,
        sampler: SAMPLER_NAMES_ENUM = undefined,
        texture: TEXTURE_NAMES_ENUM = undefined,
        register: u32 = 0,

        pub fn equals_id(a: Self, b: Self) bool {
            return a.combined_id == b.combined_id;
        }
        pub fn equals_register(a: Self, b: Self) bool {
            return a.register == b.register;
        }
        pub fn register_greater(a: Self, b: Self) bool {
            return a.register > b.register;
        }
    };
}

pub const ShaderCode = struct {
    kind: SDL3.GPU_ShaderFormatFlags = .from_flag(.INVALID),
    code: []const u8,
    entry_func_name: [*:0]const u8,

    pub fn spirv_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.SPIRV),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn dxbc_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.DXBC),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn dxil_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.DXIL),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn msl_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.MSL),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn metallib_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.METALLIB),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
    pub fn private_format(code: []const u8, entry_func_name: [*:0]const u8) ShaderCode {
        return ShaderCode{
            .kind = SDL3.GPU_ShaderFormatFlags.from_flag(.PRIVATE),
            .code = code,
            .entry_func_name = entry_func_name,
        };
    }
};

pub const StorageBufferMode = enum(u8) {
    RENDER_READ_ONLY,
    COMPUTE_READ_WRITE,
};

pub const RegisterMode = enum(u8) {
    MANUAL,
    AUTO,
};

pub const Register = union(RegisterMode) {
    MANUAL: u32,
    AUTO: void,

    pub fn register_num(num: u32) Register {
        return Register{ .MANUAL = num };
    }
    pub fn auto_register() Register {
        return Register{ .AUTO = void{} };
    }
};

pub const StorageRegisterWithSourceAndKind = struct {
    register: Register,
    source: u32,
    kind: StorageRegisterKind,

    pub fn greater_than(a: StorageRegisterWithSourceAndKind, b: StorageRegisterWithSourceAndKind) bool {
        return a.combine() > b.combine();
    }
    pub fn greater_than_only_kind(a: StorageRegisterWithSourceAndKind, b: StorageRegisterWithSourceAndKind) bool {
        return @intFromEnum(a.kind) > @intFromEnum(b.kind);
    }
    pub fn greater_than_only_register(a: StorageRegisterWithSourceAndKind, b: StorageRegisterWithSourceAndKind) bool {
        return a.register.MANUAL > b.register.MANUAL;
    }
    pub fn equals(a: StorageRegisterWithSourceAndKind, b: StorageRegisterWithSourceAndKind) bool {
        return a.combine() == b.combine();
    }

    pub fn combine(self: StorageRegisterWithSourceAndKind) u32 {
        const secondary: u32 = switch (self.register) {
            .AUTO => 0,
            .MANUAL => |r| r + 1,
        };
        return secondary | @intFromEnum(self.kind);
    }
};

pub const RegisterWithSource = struct {
    register: Register,
    source: u32,
};

pub fn UniformRegister(comptime UNIFORM_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        uniform: UNIFORM_NAMES_ENUM,
        register: Register = .AUTO,

        pub fn link_uniform(comptime uniform: UNIFORM_NAMES_ENUM, comptime register: Register) Self {
            return Self{
                .uniform = uniform,
                .register = register,
            };
        }
    };
}

pub fn StorageBufferRegister(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        buffer: STORAGE_BUFFER_NAMES_ENUM,
        register: Register = .AUTO,

        pub fn link_storage_buffer(comptime buffer: STORAGE_BUFFER_NAMES_ENUM, comptime register: Register) Self {
            return Self{
                .buffer = buffer,
                .register = register,
            };
        }
    };
}

pub fn ReadOnlyStorageTextureRegister(comptime TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: TEXTURE_NAMES_ENUM,
        register: Register = .AUTO,

        pub fn link_read_only_storage_texture(comptime texture: TEXTURE_NAMES_ENUM, comptime register: Register) Self {
            return Self{
                .texture = texture,
                .register = register,
            };
        }
    };
}

pub fn ReadOnlySampledTextureRegister(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: TEXTURE_NAMES_ENUM,
        sampler: SAMPLER_NAMES_ENUM,
        register: Register = .AUTO,

        pub fn link_read_only_sampled_texture(comptime texture: TEXTURE_NAMES_ENUM, comptime sampler: SAMPLER_NAMES_ENUM, comptime register: Register) Self {
            return Self{
                .texture = texture,
                .sampler = sampler,
                .register = register,
            };
        }
    };
}

// pub fn VertexBufferRegister(comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type) type {
//     return struct {
//         const Self = @This();

//         buffer: GPU_VERTEX_BUFFER_NAMES_ENUM,
//         /// the `buffer_slot` value for the render pipeline
//         register: Register = .AUTO,

//         pub fn link_vertex_buffer(comptime buffer: GPU_VERTEX_BUFFER_NAMES_ENUM, comptime register: Register) Self {
//             return Self{
//                 .buffer = buffer,
//                 .register = register,
//             };
//         }
//     };
// }

pub const RenderLinkageRegisterKind = enum(u8) {
    SAMPLED_TEXTURE,
    STORAGE_TEXTURE,
    STORAGE_BUFFER,
    UNIFORM_BUFFER,
    VERTEX_BUFFER,
};

pub const StorageRegisterKind = enum(u32) {
    SAMPLED_PAIR = 0b01 << 30,
    STORAGE_TEXTURE = 0b10 << 30,
    STORAGE_BUFFER = 0b11 << 30,
};

pub fn ShaderRegister(comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return union(RenderLinkageRegisterKind) {
        SAMPLED_TEXTURE: ReadOnlySampledTextureRegister(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
        STORAGE_TEXTURE: ReadOnlyStorageTextureRegister(TEXTURE_NAMES_ENUM),
        STORAGE_BUFFER: StorageBufferRegister(STORAGE_BUFFER_NAMES_ENUM),
        UNIFORM_BUFFER: UniformRegister(UNIFORM_NAMES_ENUM),
    };
}

pub fn VertexShaderDefinition(comptime VERTEX_SHADER_NAMES_ENUM: type, comptime SHADER_STRUCT_NAMES_ENUM: type, comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        vertex_shader: VERTEX_SHADER_NAMES_ENUM,
        /// The input struct type name for the shader
        ///
        /// The main purpose of this is to match vertex shader `output_type`
        /// to a fragment shader `input_type` or a vertex shader
        /// `input_type` to the various fields of the bound vertex buffers
        ///
        /// If you use the GraphicsController to automatically
        /// generate shader code stubs, it will use the name of
        /// this type as the name of the shader type, and if
        /// it has a `write_shader_stream_struct(...)` method,
        /// it will call that method when writing the stub to
        /// fill in the fields.
        input_type: SHADER_STRUCT_NAMES_ENUM,
        /// The input struct type name for the shader
        ///
        /// The main purpose is to match vertex shader `output_type`
        /// to a fragment shader `input_type` or a fragment shader
        /// `output_type` to the pixel formats of the color target textures
        ///
        /// If you use the GraphicsController to automatically
        /// generate shader code stubs, it will use the name of
        /// this type as the name of the shader type, and if
        /// it has a `write_shader_stream_struct(...)` method,
        /// it will call that method when writing the stub to
        /// fill in the fields.
        output_type: SHADER_STRUCT_NAMES_ENUM,
        resources_to_link: []const ShaderRegister(UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
    };
}

pub fn FragmentShaderDefinition(comptime FRAGMENT_SHADER_NAMES_ENUM: type, comptime SHADER_STRUCT_NAMES_ENUM: type, comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        fragment_shader: FRAGMENT_SHADER_NAMES_ENUM,
        /// The input struct type name for the shader
        ///
        /// The main purpose of this is to match vertex shader `output_type`
        /// to a fragment shader `input_type` or a vertex shader
        /// `input_type` to the various fields of the bound vertex buffers
        ///
        /// If you use the GraphicsController to automatically
        /// generate shader code stubs, it will use the name of
        /// this type as the name of the shader type, and if
        /// it has a `write_shader_stream_struct(...)` method,
        /// it will call that method when writing the stub to
        /// fill in the fields.
        input_type: SHADER_STRUCT_NAMES_ENUM,
        /// The input struct type name for the shader
        ///
        /// The main purpose is to match vertex shader `output_type`
        /// to a fragment shader `input_type` or a fragment shader
        /// `output_type` to the pixel formats of the color target textures
        ///
        /// If you use the GraphicsController to automatically
        /// generate shader code stubs, it will use the name of
        /// this type as the name of the shader type, and if
        /// it has a `write_shader_stream_struct(...)` method,
        /// it will call that method when writing the stub to
        /// fill in the fields.
        output_type: SHADER_STRUCT_NAMES_ENUM,
        resources_to_link: []const ShaderRegister(UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
    };
}

pub const ShaderStage = enum(u8) {
    VERTEX = 0,
    FRAGMENT = 1,

    pub fn idx(comptime self: ShaderStage) u8 {
        return @intFromEnum(self);
    }
};

pub const ShaderStructUsage = enum(u8) {
    VERTEX_INPUT,
    VERTEX_IN_FRAGMENT_OUT,
    FRAGMENT_OUT,
};

pub fn RenderPipelineDefinition(comptime PIPLEINE_NAMES: type, comptime VERTEX_SHADER_NAMES: type, comptime FRAGMENT_SHADER_NAMES: type, comptime VERTEX_BUFFER_NAMES: type, comptime SHADER_STRUCT_NAMES: type) type {
    return struct {
        pipeline: PIPLEINE_NAMES,
        vertex: VERTEX_SHADER_NAMES,
        fragment: FRAGMENT_SHADER_NAMES,
        vertex_field_maps: []const RenderPipelineVertexFieldMap(VERTEX_BUFFER_NAMES, SHADER_STRUCT_NAMES),
        primitive_type: SDL3.GPU_PrimitiveType = .TRIANGLE_LIST,
        rasterizer_options: SDL3.GPU_RasterizerState = .{},
        multisample_options: SDL3.GPU_MultisampleState = .{},
        depth_stencil_options: SDL3.GPU_DepthStencilState = .{},
        target_info: SDL3.GPU_GraphicsPipelineTargetInfo = .{},
        props: SDL3.PropertiesID = .{},
    };
}

pub fn RenderPipelineVertexFieldMap(comptime VERTEX_BUFFER_NAMES: type) type {
    return struct {
        const Self = @This();
        /// The vertex buffer to take data from
        vertex_buffer: VERTEX_BUFFER_NAMES,
        /// the field of the vertex buffer to take data from
        ///
        /// this MUST match one of the tag names on the `vertex_buffer`'s associated
        /// `VertexBufferDescription.fields` enum type, and the `VertexBufferFieldInfo`
        /// data must match the shader struct `ShaderStructFieldInfo`
        vertex_buffer_field_name: []const u8,
        /// The slot these vertex buffers will be bound to. All field mappings within the same render pipeline
        /// must have exactly one `vertex_buffer` match exactly one `vertex_buffer_bind_slot`,
        /// and all `vertex_buffer_bind_slot`s must start from 0 and increase with no gaps
        vertex_buffer_bind_slot: Register,
        /// Whether this field is supplied per-vertex or per-instance.
        ///
        /// This MUST match the `vertex_field_input_rate` on all other field maps
        /// that reference the same `vertex_buffer_bind_slot`
        vertex_field_input_rate: SDL3.GPU_VertexInputRate,
        /// the field of the shader struct to send data to
        ///
        /// this MUST match one of the tag names on the render pipeline's vertex shader input struct's associated
        /// `ShaderStructDescription.fields` enum type, and the `ShaderStructFieldInfo`
        /// data must match the vertex buffer `VertexBufferFieldInfo`
        shader_struct_field_name: []const u8,
    };
}

/// A description of a vertex buffer, its element type, and the fields on its element type
///
/// Analogous to `SDL3.GPU_VertexBufferDescription` but with more descriptive info
/// and the ability to assert correctness for use with `GraphicsController`
pub const VertexBufferDescription = struct {
    /// MUST be the type the vertex buffer holds in each element position.
    ///
    /// This can be ANY non-opaque type as long as it is properly sized and aligned
    /// for the needed field types and offsets
    element_type: type,
    /// MUST be an enum type describing the name of each field on `type`
    fields: type,
    /// MUST be a struct type with a `pub const <FIELD NAME>: VertexBufferFieldInfo = .{.type = <FIELD TYPE>, .offset = <FIELD OFFSET>, .format = <FIELD SDL3 GPU FORMAT>};` declaration
    /// for EACH of the field names described by `fields`
    fields_info: type,

    pub fn assert_valid(comptime desc: VertexBufferDescription, comptime name: []const u8, comptime src: ?std.builtin.SourceLocation) void {
        const INT_SIZE: u16 = @sizeOf(desc.element_type);
        const INT_SIZE_32: u32 = @intCast(INT_SIZE);
        const INT = std.meta.Int(.unsigned, INT_SIZE);
        comptime var bytes_taken: INT = 0;
        ct_assert_with_reason(Types.type_is_enum(desc.fields) and Types.all_enum_values_start_from_zero_with_no_gaps(desc.fields), src, "vertex buffer `{s}` type of `fields` must be an enum type with all tag values from 0 to max with no gaps, got type `{s}`", .{ name, @typeName(desc.fields) });
        const EINFO = @typeInfo(desc.fields).@"enum";
        inline for (EINFO.fields) |field| {
            ct_assert_with_reason(@hasDecl(desc.fields_info, field.name) and @TypeOf(@field(desc.fields_info, field.name)) == VertexBufferFieldInfo, src, "vertex buffer `{s}` `fields_info` MUST have a declaration of `pub const {s}: VertexBufferFieldInfo = .{...}`, but it was missing or the wrong type", .{ name, field.name });
            const info: VertexBufferFieldInfo = @field(desc.fields_info, field.name);
            ct_assert_with_reason(std.mem.isAligned(@intCast(info.offset), @alignOf(info.field_type)), src, "vertex buffer `{s}` field `{s}` has an offset that is not aligned to its type alignment ({d} not aligned to {d})", .{ name, field.name, info.offset, @alignOf(info.field_type) });
            ct_assert_with_reason(@sizeOf(info.field_type) + info.offset <= INT_SIZE_32, src, "vertex buffer `{s}` field `{s}` has a size and offset that extends beyond the size of the buffer element type", .{ name, field.name });
            const field_bytes = Utils.first_n_bytes_set_inline(INT, @sizeOf(info.field_type)) << @intCast(info.offset);
            const after_or = bytes_taken | field_bytes;
            const after_xor = bytes_taken ^ field_bytes;
            ct_assert_with_reason(after_or == after_xor, src, "vertex buffer `{s}` field `{s}` has a size and offset that overlaps with another field from byte {d} to byte {d}", .{ name, @ctz(bytes_taken & field_bytes), INT_SIZE - @clz(bytes_taken & field_bytes) });
            ct_assert_with_reason(info.gpu_format != .INVALID, src, "vertex buffer `{s}` field `{s}` has an `.INVALID` gpu format", .{ name, field.name });
            ct_assert_with_reason(info.gpu_format.size() == @sizeOf(info.field_type), src, "vertex buffer `{s}` field `{s}` has a gpu format (`{s}` = {d}) that is not the same size as its cpu type (`{s}` = {d})", .{ name, field.name, @tagName(info.gpu_format), info.gpu_format.size(), @typeName(info.field_type), @sizeOf(info.field_type) });
            bytes_taken = after_or;
        }
    }

    pub fn get_info_for_field(comptime desc: VertexBufferDescription, comptime field: desc.fields) VertexBufferFieldInfo {
        return @field(desc.fields_info, @tagName(field));
    }
};

pub const VertexBufferFieldInfo = struct {
    /// The concrete zig type that this field holds. This is what the user
    /// will read/write on the application side
    field_type: type,
    /// The offset from the beginning of the vertex buffer element/struct where the `cpu_type`
    /// can be read/written
    offset: u32,
    /// The SDL3 GPU type format that most closely represents the `cpu_type`
    ///
    /// MUST have the same size as `cpu_type`
    gpu_format: SDL3.GPU_VertexElementFormat,
};

pub const NumLocationsAndDepthTarget = struct {
    /// for `.VERTEX_IN` and `.VERTEX_OUT_FRAG_IN` shader structs, this is the number of
    /// user paramater locations
    ///
    /// for `.FRAGMENT_OUT` shader structs, this is the number of color targets
    num_locations: u32 = 0,
    /// `true` is only valid for `.FRAGMENT_OUT` shader structs
    has_depth_target: bool = false,
};

/// A description of a shader input/output struct
///
/// This is largely used for validation during comptime,
/// but if `struct_type` implements `SDL3_ShaderContract.StreamStructWriterInterface`,
/// it will be used to generate shader code stubs when requested
pub const ShaderStructDescription = struct {
    /// A representation of the type that the vertex shader will take as input.
    ///
    /// The application side does not directly read/write to this (it is fed data
    /// from bound vertex buffers or the GPU itself), but is used for comptime validation
    /// in some scenarios.
    ///
    /// If this type implements `SDL3_ShaderContract.StreamStructWriterInterface`,
    /// it will be used to generate shader code stubs when requested
    struct_type: type,
    /// At what stage this shader struct is used. Changes the way validation occurs.
    struct_usage: ShaderStructUsage,
    /// MUST be an enum type describing the name of each *USER SUPPLIED* field on the vertex struct/input
    /// on the GPU side. Do not include fields from GLSL builtins or HLSL SystemValue semantics, etc.
    fields: type,
    /// MUST be a struct type with a `pub const <FIELD NAME>: ShaderStructFieldInfo = .{.cpu_type = <CPU TYPE>, .location = <FIELD LOCATION>, .format = <FIELD SDL3 GPU FORMAT>};` declaration
    /// for EACH of the field names described by `fields`
    fields_info: type,

    pub fn assert_valid(comptime desc: ShaderStructDescription, comptime name: []const u8, comptime src: ?std.builtin.SourceLocation) NumLocationsAndDepthTarget {
        ct_assert_with_reason(Types.type_is_enum(desc.fields) and Types.all_enum_values_start_from_zero_with_no_gaps(desc.fields), src, "shader struct `{s}` type of `fields` must be an enum type with all tag values from 0 to max with no gaps, got type `{s}`", .{ name, @typeName(desc.fields) });
        const EINFO = @typeInfo(desc.fields).@"enum";
        comptime var locations_init: [EINFO.fields.len]bool = @splat(false);
        comptime var depth_was_init: bool = false;
        comptime var out: NumLocationsAndDepthTarget = .{};
        inline for (EINFO.fields) |field| {
            ct_assert_with_reason(@hasDecl(desc.fields_info, field.name) and @TypeOf(@field(desc.fields_info, field.name)) == ShaderStructFieldInfo, src, "shader struct `{s}` `fields_info` MUST have a declaration of `pub const {s}: ShaderStructFieldInfo = .{...}`, but it was missing or the wrong type", .{ name, field.name });
            const info: ShaderStructFieldInfo = @field(desc.fields_info, field.name);
            ct_assert_with_reason(info.gpu_format != .INVALID, src, "shader struct `{s}` field `{s}` has an `.INVALID` gpu format", .{ name, field.name });
            ct_assert_with_reason(info.gpu_format.size() == @sizeOf(info.cpu_type), src, "shader struct `{s}` field `{s}` has a gpu format size (`{s}` = {d}) that is not the same size as its cpu type (`{s}` = {d})", .{ name, field.name, @tagName(info.gpu_format), info.gpu_format.size(), @typeName(info.cpu_type), @sizeOf(info.cpu_type) });
            switch (info.location_kind) {
                .USER_INPUT_OUTPUT => {
                    ct_assert_with_reason(desc.struct_usage != .FRAGMENT_OUT, src, "shader struct `{s}` has usage mode `.FRAGMENT_OUT`, but field `{s}` has a `.USER_INPUT_OUTPUT` location. Only `.COLOR_TARGET` or `.DEPTH_TARGET` locations are allowed for `.FRAGMENT_OUT` structs (but you can write non-color data to one of the color targets if needed)", .{ name, field.name });
                    ct_assert_with_reason(info.location < EINFO.fields.len, src, "shader struct `{s}` field `{s}` has a location greater than or equal to the number of fields on the struct ({d} >= {d}): All locations must start from 0 and increase with no gaps", .{ name, field.name, info.location, EINFO.fields.len });
                    ct_assert_with_reason(locations_init[info.location] == false, src, "shader struct `{s}` field `{s}` has a duplicate location {d}", .{ name, field.name, info.location });
                    locations_init[info.location] = true;
                    out.num_locations += 1;
                },
                .COLOR_TARGET, .DEPTH_TARGET => {
                    ct_assert_with_reason(desc.struct_usage == .FRAGMENT_OUT, src, "shader struct `{s}` has usage mode `.{s}`, but field `{s}` has a `.{s}` location. Only `.USER_INPUT_OUTPUT` locations are allowed for `.{s}` structs", .{ name, @tagName(desc.struct_usage), field.name, @tagName(info.location_kind), @tagName(desc.struct_usage) });
                    switch (info.location_kind) {
                        .COLOR_TARGET => {
                            ct_assert_with_reason(info.location < EINFO.fields.len, src, "shader struct `{s}` field `{s}` has a color target greater than or equal to the number of fields on the struct ({d} >= {d}): All color targets must start from 0 and increase with no gaps", .{ name, field.name, info.location, EINFO.fields.len });
                            ct_assert_with_reason(info.location < 8, src, "shader struct `{s}` field `{s}` has a color target greater than or equal to 8: only 8 simultaneous color targets are supported (locations 0-7)", .{ name, field.name });
                            ct_assert_with_reason(locations_init[info.location] == false, src, "shader struct `{s}` field `{s}` has a duplicate color target {d}", .{ name, field.name, info.location });
                            locations_init[info.location] = true;
                            out.num_locations += 1;
                        },
                        .DEPTH_TARGET => {
                            ct_assert_with_reason(depth_was_init == false, src, "shader struct `{s}` field `{s}` has a duplicate depth target field: only one depth target is supported", .{ name, field.name });
                            ct_assert_with_reason(locations_init[EINFO.fields.len - 1] == false, src, "shader struct `{s}` field `{s}` has a gap somewhere in its color target locations. All color targets must start at 0 and increase with no gaps.", .{ name, field.name });
                            depth_was_init = true;
                            locations_init[EINFO.fields.len - 1] = true;
                            out.has_depth_target = true;
                        },
                    }
                },
            }
        }
        return out;
    }

    pub fn get_info_for_field(comptime desc: ShaderStructDescription, comptime field: desc.fields) ShaderStructFieldInfo {
        return @field(desc.fields_info, @tagName(field));
    }

    pub fn get_type_and_format_for_location(comptime desc: ShaderStructDescription, comptime location: u32) ?TypeAndFormat {
        const FIELDS_INFO = @typeInfo(desc.fields).@"enum";
        inline for (FIELDS_INFO.fields) |field| {
            const info: ShaderStructFieldInfo = @field(desc.fields_info, field.name);
            if (info.location == location) {
                return TypeAndFormat{
                    .cpu_type = info.cpu_type,
                    .gpu_format = info.gpu_format,
                    .kind = info.location_kind,
                };
            }
        }
        return null;
    }
};

pub const ShaderStructFieldInfo = struct {
    /// This is the type that is being sent from the
    /// application to the GPU, regardless of what
    /// the GPU will interpret it as. This is used for
    /// validation only (matches the `VertexBufferFieldInfo.type`
    /// that supplies it)
    cpu_type: type,
    /// The vertex location data will be sent to.
    ///
    /// If `location_kind == .USER_INPUT_OUTPUT` this MUST be a user provided location, eg.
    /// `layout(location = #)` (GLSL) or `TEXCOORD#` (HLSL)
    ///
    /// If `location_kind == .COLOR_TARGET`, this is a number from 0-7 inclusive
    /// indicating which color target the field writes to (only for fragment
    /// shader outputs).
    ///
    /// If `location_kind == .DEPTH_TARGET`, this location will be ignored,
    /// indicating the field will write to the depth buffer.
    location: u32,
    /// The kind of the location indicated by `location`
    ///
    /// If `location_kind == .USER_INPUT_OUTPUT` location must be a user provided location, eg.
    /// `layout(location = #)` (GLSL) or `TEXCOORD#` (HLSL)
    ///
    /// If `location_kind == .COLOR_TARGET`, location must be a number from 0-7 inclusive
    /// indicating which color target the field writes to (only for fragment
    /// shader outputs).
    ///
    /// If `location_kind == .DEPTH_TARGET`, location will be ignored,
    /// indicating the field will write to the depth buffer.
    location_kind: FieldLocationKind = .USER_INPUT_OUTPUT,
    /// The SDL3 GPU type format that most closely represents the `cpu_type`
    ///
    /// MUST have the same size as `cpu_type`
    gpu_format: SDL3.GPU_VertexElementFormat,
};

pub const TypeAndFormat = struct {
    cpu_type: type,
    gpu_format: SDL3.GPU_VertexElementFormat,
    kind: FieldLocationKind,

    pub fn equals(comptime self: TypeAndFormat, comptime other: TypeAndFormat) bool {
        return self.cpu_type == other.cpu_type and self.gpu_format == other.gpu_format and self.kind == other.kind;
    }
};

pub fn TextureDefinition(comptime TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();
        texture: TEXTURE_NAMES_ENUM,
        shape: SDL3.GPU_TextureType = ._2D,
        pixel_format: GPU_TextureFormat = .R8G8B8A8_UNORM_SRGB,
        mipmap_levels: u32 = 0,
        sample_count: SDL3.GPU_SampleCount = ._1,
        props: SDL3.PropertiesID = .{},

        pub fn define_texture(name: TEXTURE_NAMES_ENUM, shape: GPU_TextureType, format: GPU_TextureFormat, mipmap_levels: u32, sample_count: SDL3.GPU_SampleCount, props: PropertiesID) Self {
            return Self{
                .texture = name,
                .pixel_format = format,
                .mipmap_levels = mipmap_levels,
                .sample_count = sample_count,
                .props = props,
                .shape = shape,
            };
        }
    };
}

pub fn StroageBufferDefinition(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        name: STORAGE_BUFFER_NAMES_ENUM,
        element_type: type,
    };
}

pub const FieldLocationKind = enum(u8) {
    USER_INPUT_OUTPUT,
    COLOR_TARGET,
    DEPTH_TARGET,
};

pub const ValidationSettings = struct {
    master_error_mode: Common.ErrorBehavior = .RETURN_ERRORS,
    master_assert_mode: Common.AssertBehavior = .UNREACHABLE,
    mismatched_cpu_types: ValidateMode = .PANIC,
    mismatched_gpu_formats: ValidateMode = .PANIC,
    vertex_buffer_slot_gaps: ValidateMode = .PANIC,
    depth_stencil_zero_bits: ValidateMode = .PANIC,
    depth_texture_non_depth_format: ValidateMode = .PANIC,
    depth_texture_non_stencil_format: ValidateMode = .PANIC,
    color_texture_non_color_format: ValidateMode = .PANIC,
    color_targets_missing: ValidateMode = .PANIC,
    push_unallowed_uniform: ValidateMode = .PANIC,
};

pub fn IndexBufferDef(comptime INDEX_BUFFER_NAMES_ENUM: type) type {
    return struct {
        buffer: INDEX_BUFFER_NAMES_ENUM,
        index_size: SDL3.GPU_IndexTypeSize,
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
    /// An enum with tag names for each unique window of the application
    ///
    /// Non-named windows are allowed, but must be handled using the standard SDL3 api
    comptime WINDOW_NAMES_ENUM: type,
    /// An enum with tag names for each unique vertex shader used in application
    comptime VERTEX_SHADER_NAMES_ENUM: type,
    /// An enum with tag names for each unique fragment shader used in application
    comptime FRAGMENT_SHADER_NAMES_ENUM: type,
    /// An enum with tag names for each unique render (graphics) pipeline used in application
    comptime RENDER_PIPELINE_NAMES_ENUM: type,
    /// An enum with tag names for each unique texture used in application
    comptime TEXTURE_NAMES_ENUM: type,
    /// An enum with tag names for each unique texture *sampler* used in application
    comptime SAMPLER_NAMES_ENUM: type,
    /// An enum for named gpu fences. When a fence is requested, it must be sent
    /// to a named fence slot, and waited on by name.
    comptime FENCE_NAMES_ENUM: type,
    /// An enum with names for each index buffer to be used
    comptime INDEX_BUFFER_NAMES: type,
    /// An enum with names for each indirect draw buffer
    comptime INDIRECT_BUFFER_NAMES: type,
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
    /// one vertex buffer can feed a single vertex shader struct/input, if desired
    comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type,
    /// An struct filled with declarations in the format:
    /// ```zig
    /// pub const <BUFFER NAME> = VertexBufferDescription{
    ///     .element_type = <ELEMENT TYPE>,
    ///     .fields = enum {
    ///         <FIELD NAMES ...>,
    ///     },
    ///     .fields_info = struct {
    ///         pub const <FIELD NAME> = VertexBufferFieldInfo{<INFO>};
    ///     },
    ///     .slot = <SLOT NUMBER>,
    ///     .input_rate = <INPUT RATE>,
    /// };
    /// ```
    /// ### Example
    /// ```zig
    /// pub const VertBufferNames = enum {
    ///     VertPosition,
    ///     VertColorAndRotation,
    /// };
    ///
    /// pub const VertBufferDescriptions = struct { // <----- THIS
    ///     pub const VertPosition =  VertexBufferDescription{
    ///         .element_type = Vec3(f32),
    ///         .fields = enum {
    ///             pos,
    ///         },
    ///         .fields_info = struct{
    ///             pub const pos = FieldInfo{
    ///                 .field_type = Vec3(f32),
    ///                 .offset = 0,
    ///                 .gpu_format = .F32_x3,
    ///             };
    ///         },
    ///         .slot = 0,
    ///         .input_rate = .VERTEX,
    ///     };
    ///     pub const VertColorAndRotation = VertexBufferDescription{
    ///         .element_type = [8]u8, // opaque array of 8 bytes
    ///         .fields = enum{
    ///             color,
    ///             rotation,
    ///         },
    ///         .fields_info = struct{
    ///             pub const color = FieldInfo{
    ///                 .field_type = u32,
    ///                 .offset = 0,
    ///                 .gpu_format = .U32_x1,
    ///             };
    ///             pub const rotation = FieldInfo{
    ///                 .field_type = f32,
    ///                 .offset = 4,
    ///                 .gpu_format = .F32_x1,
    ///             };
    ///         },
    ///         .slot = 1,
    ///         .input_rate = .INSTANCE,
    ///     };
    /// };
    /// ```
    comptime STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS: type,
    /// An enum with tag names for each unique shader struct used in the application
    ///
    /// These are the actual object models passed to the shaders as input/output parameters,
    /// and in the case of vertex structs, they can be fed data from more than one vertex buffer, if
    /// desired
    ///
    /// Each tag name must exactly match a declaration name in `STRUCT_OF_SHADER_STRUCT_DEFINITIONS`
    ///
    /// ### Example
    /// ```zig
    /// pub const ShaderStructNames = enum { // <----- THIS
    ///     VertexIn,
    ///     VertexOutFragIn,
    ///     FragOut
    /// };
    /// pub const ShaderStructs = struct {
    ///     pub const VertexIn = ShaderStructDescription{
    ///         .struct_type = struct {pos: Vec3(f32), color: u32 }, // this struct could be defined elsewhere
    ///         .fields = enum { // this enum could be defined elsewhere
    ///             pos,
    ///             color,
    ///         },
    ///         .fields_info = struct {  // this struct could be defined elsewhere
    ///             pub const pos = ShaderStructFieldInfo{
    ///                 .cpu_type = Vec3(f32),
    ///                 .location = 0,
    ///                 .gpu_format = .F32_x3,
    ///             };
    ///             pub const color = ShaderStructFieldInfo{
    ///                 .cpu_type = u32,
    ///                 .location = 1,
    ///                 .gpu_format = .U32_x1,
    ///             };
    ///         };
    ///     };
    ///     pub const VertexOutFragIn = ShaderStructDescription{
    ///         .struct_type = struct{pos: Vec4(f32), color: Vec4(f32)}, // this struct could be defined elsewhere
    ///         .fields = enum { // this enum could be defined elsewhere
    ///             color,
    ///             // position is provided by a builtin/system-value-semantic
    ///         },
    ///         .fields_info = struct { // this struct could be defined elsewhere
    ///             pub const color = ShaderStructFieldInfo{
    ///                 .cpu_type = Vec4(f32),
    ///                 .location = 0,
    ///                 .gpu_format = .F32_x4,
    ///             };
    ///         };
    ///     };
    ///     pub const FragOut = ShaderStructDescription{
    ///         .struct_type = struct{color: Vec4(f32), depth: f32}, // this struct could be defined elsewhere
    ///         .fields = enum {}, // all outputs sent to builtins/system-value-semantics in this case
    ///         .fields_info = struct {}; // all outputs sent to builtins/system-value-semantics in this case
    ///     };
    /// };
    /// ```
    comptime GPU_SHADER_STRUCT_NAMES_ENUM: type,
    /// This should have each unique shader struct concrete type and fields enum as a
    /// `pub const <STRUCT NAME> = ShaderStructDescription{...};` declaration
    ///
    /// Each declaration name must exactly match a tag name in `GPU_SHADER_STRUCT_NAMES_ENUM`
    ///
    /// ### Example
    /// ```zig
    /// pub const ShaderStructNames = enum {
    ///     VertexIn,
    ///     VertexOutFragIn,
    ///     FragOut
    /// };
    /// pub const ShaderStructs = struct { // <----- THIS
    ///     pub const VertexIn = ShaderStructDescription{
    ///         .struct_type = struct {pos: Vec3(f32), color: u32 }, // this struct could be defined elsewhere
    ///         .fields = enum { // this enum could be defined elsewhere
    ///             pos,
    ///             color,
    ///         },
    ///         .fields_info = struct {  // this struct could be defined elsewhere
    ///             pub const pos = ShaderStructFieldInfo{
    ///                 .cpu_type = Vec3(f32),
    ///                 .location = 0,
    ///                 .gpu_format = .F32_x3,
    ///             };
    ///             pub const color = ShaderStructFieldInfo{
    ///                 .cpu_type = u32,
    ///                 .location = 1,
    ///                 .gpu_format = .U32_x1,
    ///             };
    ///         };
    ///     };
    ///     pub const VertexOutFragIn = ShaderStructDescription{
    ///         .struct_type = struct{pos: Vec4(f32), color: Vec4(f32)}, // this struct could be defined elsewhere
    ///         .fields = enum { // this enum could be defined elsewhere
    ///             color,
    ///             // position is provided by a builtin/system-value-semantic
    ///         },
    ///         .fields_info = struct { // this struct could be defined elsewhere
    ///             pub const color = ShaderStructFieldInfo{
    ///                 .cpu_type = Vec4(f32),
    ///                 .location = 0,
    ///                 .gpu_format = .F32_x4,
    ///             };
    ///         };
    ///     };
    ///     pub const FragOut = ShaderStructDescription{
    ///         .struct_type = struct{color: Vec4(f32), depth: f32}, // this struct could be defined elsewhere
    ///         .fields = enum {}, // all outputs sent to builtins/system-value-semantics in this case
    ///         .fields_info = struct {}; // all outputs sent to builtins/system-value-semantics in this case
    ///     };
    /// };
    /// ```
    comptime STRUCT_OF_SHADER_STRUCT_DEFINITIONS: type,
    /// An enum with tag names for each unique uniform struct used in application
    comptime GPU_UNIFORM_NAMES_ENUM: type,
    /// This should have each unique uniform as an individial field
    ///
    /// Uniforms with the same struct type but different data should be separate fields.
    ///
    /// Each field name must exactly match a tag name in `UNIFORM_NAMES_ENUM`
    comptime STRUCT_OF_UNIFORM_STRUCTS: type,
    /// An enum with tag names for each unique gpu storage buffer used in application
    comptime GPU_STORAGE_BUFFER_NAMES_ENUM: type,
    /// This is a list of descriptions of storage buffer element types
    ///
    /// Each name in `GPU_STORAGE_BUFFER_NAMES_ENUM` must be represented exactly once
    comptime GPU_STORAGE_BUFFER_DEFINITIONS: [Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM)]StroageBufferDefinition(GPU_STORAGE_BUFFER_NAMES_ENUM),
    /// A list of all texture definitions for each of the named textures
    comptime TEXTURE_DEFINITIONS: [Types.enum_defined_field_count(TEXTURE_NAMES_ENUM)]TextureDefinition(TEXTURE_NAMES_ENUM),
    /// A list of all the resource bindings for each vertex shader in the application
    comptime VERTEX_SHADER_DEFINITIONS: [Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM)]VertexShaderDefinition(VERTEX_SHADER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
    /// A list of all the resource bindings for each fragment shader in the application
    comptime FRAGMENT_SHADER_DEFINITIONS: [Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM)]FragmentShaderDefinition(FRAGMENT_SHADER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
    /// A list of all render pipelines and their associated vertex/fragment shaders
    comptime RENDER_PIPELINE_DEFINITIONS: [Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM)]RenderPipelineDefinition(RENDER_PIPELINE_NAMES_ENUM, VERTEX_SHADER_NAMES_ENUM, FRAGMENT_SHADER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM),
    /// Additional settings for optional validation steps
    comptime VALIDATION: ValidationSettings,
) type {
    // CONVENIENCE CONSTS
    const _UniformRegister = UniformRegister(GPU_UNIFORM_NAMES_ENUM);
    const _StorageBufferRegister = StorageBufferRegister(GPU_STORAGE_BUFFER_NAMES_ENUM);
    const _ReadOnlyStorageTextureRegister = ReadOnlyStorageTextureRegister(TEXTURE_NAMES_ENUM);
    const _ReadOnlySampledTextureRegister = ReadOnlySampledTextureRegister(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _VertexShaderDefinition = VertexShaderDefinition(VERTEX_SHADER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM);
    const _FragmentShaderDefinition = FragmentShaderDefinition(FRAGMENT_SHADER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM);
    const _RenderPipelineDefinition = RenderPipelineDefinition(RENDER_PIPELINE_NAMES_ENUM, VERTEX_SHADER_NAMES_ENUM, FRAGMENT_SHADER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM, GPU_SHADER_STRUCT_NAMES_ENUM);
    const _TextureDefinition = TextureDefinition(TEXTURE_NAMES_ENUM);
    // const _PipelineAllowedUniform = PipelineAllowedUniform(GPU_UNIFORM_NAMES_ENUM);
    // const _PipelineAllowedSamplePair = PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    // const _PipelineAllowedStorageBuffer = PipelineAllowedStorageBuffer(GPU_STORAGE_BUFFER_NAMES_ENUM);
    // const _PipelineAllowedStorageTexture = PipelineAllowedStorageTexture(TEXTURE_NAMES_ENUM);
    const _ShaderAllowedUniform = ShaderAllowedUniform(GPU_UNIFORM_NAMES_ENUM);
    const _ShaderAllowedSamplePair = ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _ShaderAllowedStorageBuffer = ShaderAllowedStorageBuffer(GPU_STORAGE_BUFFER_NAMES_ENUM);
    const _ShaderAllowedStorageTexture = ShaderAllowedStorageTexture(TEXTURE_NAMES_ENUM);
    const vertex_linkages: []const _VertexShaderDefinition = VERTEX_SHADER_DEFINITIONS[0..];
    const fragment_linkages: []const _FragmentShaderDefinition = FRAGMENT_SHADER_DEFINITIONS[0..];
    // VALIDATE SIMPLE ENUMS
    ct_assert_with_reason(Types.type_is_enum(WINDOW_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(WINDOW_NAMES_ENUM), @src(), "type `WINDOW_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(WINDOW_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(VERTEX_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_SHADER_NAMES_ENUM), @src(), "type `VERTEX_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_SHADER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(FRAGMENT_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_SHADER_NAMES_ENUM), @src(), "type `FRAGMENT_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_SHADER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(RENDER_PIPELINE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(RENDER_PIPELINE_NAMES_ENUM), @src(), "type `RENDER_PIPELINE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(RENDER_PIPELINE_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(SAMPLER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(SAMPLER_NAMES_ENUM), @src(), "type `SAMPLER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(SAMPLER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `UPLOAD_TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(FENCE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FENCE_NAMES_ENUM), @src(), "type `FENCE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FENCE_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_enum(INDIRECT_BUFFER_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(INDIRECT_BUFFER_NAMES), @src(), "type `INDIRECT_BUFFER_NAMES` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(INDIRECT_BUFFER_NAMES)});
    ct_assert_with_reason(Types.type_is_enum(INDEX_BUFFER_NAMES) and Types.all_enum_values_start_from_zero_with_no_gaps(INDEX_BUFFER_NAMES), @src(), "type `INDEX_BUFFER_NAMES` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(INDEX_BUFFER_NAMES)});
    const _NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
    const _NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
    const _NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
    // VALIDATE TEXTURES
    ct_assert_with_reason(Types.type_is_enum(TEXTURE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TEXTURE_NAMES_ENUM), @src(), "type `TEXTURE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TEXTURE_NAMES_ENUM)});
    const _NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
    comptime var ordered_texture_definitions: [_NUM_TEXTURES]_TextureDefinition = undefined;
    comptime var textures_defined: [_NUM_TEXTURES]bool = @splat(false);
    inline for (TEXTURE_DEFINITIONS) |texture_def| {
        const tex_id = @intFromEnum(texture_def.texture);
        ct_assert_with_reason(textures_defined[tex_id] == false, @src(), "texture `{s}` was defined more than once", .{@tagName(texture_def.texture)});
        textures_defined[tex_id] = true;
        ct_assert_with_reason(texture_def.pixel_format != .INVALID, @src(), "texture `{s}` had an `.INVALID` pixel format", .{@tagName(texture_def.texture)});
        ct_assert_with_reason(texture_def.width != 0 and texture_def.height != 0, @src(), "texture `{s}` had zero size (WxH = {d}x{d})", .{ @tagName(texture_def.texture), texture_def.width, texture_def.height });
        ct_assert_with_reason(texture_def.layers_or_depth != 0, @src(), "texture `{s}` had zero size (layers/depth = 0)", .{@tagName(texture_def.texture)});
        ordered_texture_definitions[tex_id] = texture_def;
    }
    const ordered_texture_definitions_const = ordered_texture_definitions;
    // VALIDATE VERTEX BUFFERS
    ct_assert_with_reason(Types.type_is_enum(GPU_VERTEX_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_VERTEX_BUFFER_NAMES_ENUM), @src(), "type `GPU_VERTEX_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_VERTEX_BUFFER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_struct_with_all_decls_same_type(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, VertexBufferDescription), @src(), "type `STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS` must be a struct type that holds all `GPU_VERTEX_BUFFER_NAMES_ENUM` names as const declarations of type `ShaderStructDescription`, got type `{s}`", .{@typeName(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS)});
    ct_assert_with_reason(Types.all_enum_names_match_an_object_decl_name(GPU_VERTEX_BUFFER_NAMES_ENUM, STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS), @src(), "each tag in `GPU_VERTEX_BUFFER_NAMES_ENUM` must have a matching pub const declaration with the same name in `STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS`", .{});
    const _NUM_VERT_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
    const ordered_vertex_buffer_descriptions: [_NUM_VERT_BUFFERS]VertexBufferDescription = undefined;
    inline for (@typeInfo(GPU_VERTEX_BUFFER_NAMES_ENUM).@"enum".fields) |vert_buffer| {
        const desc: VertexBufferDescription = @field(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, vert_buffer.name);
        desc.assert_valid(vert_buffer.name, @src());
        ordered_vertex_buffer_descriptions[vert_buffer.value] = desc;
    }
    const ordered_vertex_buffer_descriptions_const = ordered_vertex_buffer_descriptions;
    // VALIDATE SHADER STRUCTS
    ct_assert_with_reason(Types.type_is_enum(GPU_SHADER_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_SHADER_STRUCT_NAMES_ENUM), @src(), "type `GPU_SHADER_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_SHADER_STRUCT_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_struct_with_all_decls_same_type(STRUCT_OF_SHADER_STRUCT_DEFINITIONS, ShaderStructDescription), @src(), "type `STRUCT_OF_SHADER_STRUCT_DEFINITIONS` must be a struct type that holds all `GPU_SHADER_STRUCT_NAMES_ENUM` names as const declarations of type `ShaderStructDescription`, got type `{s}`", .{@typeName(STRUCT_OF_SHADER_STRUCT_DEFINITIONS)});
    ct_assert_with_reason(Types.all_enum_names_match_an_object_decl_name(GPU_SHADER_STRUCT_NAMES_ENUM, STRUCT_OF_SHADER_STRUCT_DEFINITIONS), @src(), "each tag in `GPU_SHADER_STRUCT_NAMES_ENUM` must have a matching pub const declaration with the same name in `STRUCT_OF_SHADER_STRUCT_DEFINITIONS`", .{});

    const _NUM_SHADER_STRUCTS = Types.enum_defined_field_count(GPU_SHADER_STRUCT_NAMES_ENUM);
    comptime var ordered_shader_struct_locations_quick_info: [_NUM_SHADER_STRUCTS]NumLocationsAndDepthTarget = @splat(.{});
    inline for (@typeInfo(GPU_SHADER_STRUCT_NAMES_ENUM).@"enum".fields) |shader_struct| {
        const desc: ShaderStructDescription = @field(STRUCT_OF_SHADER_STRUCT_DEFINITIONS, shader_struct.name);
        const locs = desc.assert_valid(shader_struct.name, @src());
        ordered_shader_struct_locations_quick_info[shader_struct.value] = locs;
    }
    const ordered_shader_struct_locations_quick_info_const = ordered_shader_struct_locations_quick_info;
    // VAIDATE UNIFORMS
    ct_assert_with_reason(Types.type_is_enum(GPU_UNIFORM_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_UNIFORM_NAMES_ENUM), @src(), "type `GPU_UNIFORM_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_UNIFORM_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_struct(STRUCT_OF_UNIFORM_STRUCTS), @src(), "type `STRUCT_OF_UNIFORM_STRUCTS` must be a struct type that holds all unique instances of the needed uniform structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_UNIFORM_STRUCTS)});
    ct_assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_UNIFORM_NAMES_ENUM, STRUCT_OF_UNIFORM_STRUCTS), @src(), "`GPU_UNIFORM_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_UNIFORM_STRUCTS`, and each enum tag NAME in `GPU_UNIFORM_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_UNIFORM_STRUCTS`", .{});
    const _NUM_UNIFORM_STRUCTS = Types.enum_defined_field_count(GPU_UNIFORM_NAMES_ENUM);
    // VALIDATE STORAGE BUFFERS
    ct_assert_with_reason(Types.type_is_enum(GPU_STORAGE_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_STORAGE_BUFFER_NAMES_ENUM), @src(), "type `GPU_STORAGE_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_STORAGE_BUFFER_NAMES_ENUM)});
    ct_assert_with_reason(Types.type_is_struct_with_all_fields_same_type(GPU_STORAGE_BUFFER_DEFINITIONS, type), @src(), "type `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES` must be a struct type that holds all concrete types of the storage buffer structs as fields, got type `{s}`", .{@typeName(GPU_STORAGE_BUFFER_DEFINITIONS)});
    ct_assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_STORAGE_BUFFER_NAMES_ENUM, GPU_STORAGE_BUFFER_DEFINITIONS), @src(), "`GPU_STORAGE_BUFFER_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`, and each enum tag NAME in `GPU_STORAGE_BUFFER_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`", .{});
    const _NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM);
    comptime var ordered_storage_buffer_element_types: [_NUM_STORAGE_BUFFERS]type = undefined;
    comptime var storage_buffers_init: [_NUM_STORAGE_BUFFERS]bool = @splat(false);
    inline for (GPU_STORAGE_BUFFER_DEFINITIONS[0..]) |def| {
        const def_idx = @intFromEnum(def.name);
        ct_assert_with_reason(storage_buffers_init[def_idx] == false, @src(), "storage buffer `{s}` was defined more than once", .{@tagName(def.name)});
        storage_buffers_init[def_idx] = true;
        ordered_storage_buffer_element_types[def_idx] = def.element_type;
    }
    const ordered_storage_buffer_element_types_const = ordered_storage_buffer_element_types;
    // VALIDATE SHADER REGISTERS STARTING HERE
    // ORGANISE PIPELINE TO SHADERS MAP
    comptime var ordered_pipeline_definitions: [_NUM_RENDER_PIPELINES]_RenderPipelineDefinition = undefined;
    comptime var pipeline_definitions_mapped: [_NUM_RENDER_PIPELINES]bool = @splat(false);
    inline for (RENDER_PIPELINE_DEFINITIONS) |def| {
        const pipe_idx = @intFromEnum(def.pipeline);
        ct_assert_with_reason(pipeline_definitions_mapped[pipe_idx] == false, @src(), "render pipeline `{s}` was already mapped to its shaders once, attmepted a second time", .{@tagName(def.pipeline)});
        pipeline_definitions_mapped[pipe_idx] = true;
        ordered_pipeline_definitions[pipe_idx] = def;
    }
    const ordered_pipeline_definitions_const = ordered_pipeline_definitions;
    // VARIBLE PACKAGE TO PASS TO COMPTIME SUBROUTINES FOR CONVENIENCE
    const VARS = struct {
        const SELF_VARS = @This();
        linkages_defined: [_NUM_RENDER_PIPELINES]bool = @splat(false),
        uniforms_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_UNIFORM_STRUCTS]AllowedResource = @splat(@splat(AllowedResource{})),
        uniforms_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = 0,
        uniforms_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_UNIFORM_STRUCTS]AllowedResource = @splat(@splat(AllowedResource{})),
        uniforms_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = 0,
        storage_buffers_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_STORAGE_BUFFERS]AllowedResource = @splat(@splat(AllowedResource{})),
        storage_buffers_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = 0,
        storage_buffers_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_STORAGE_BUFFERS]AllowedResource = @splat(@splat(AllowedResource{})),
        storage_buffers_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = 0,
        storage_textures_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][_NUM_TEXTURES]AllowedResource = @splat(@splat(AllowedResource{})),
        storage_textures_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = 0,
        storage_textures_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][_NUM_TEXTURES]AllowedResource = @splat(@splat(AllowedResource{})),
        storage_textures_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = 0,
        sample_pairs_allowed_in_vertex_shaders: [_NUM_VERTEX_SHADERS][config.SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS]_ShaderAllowedSamplePair = @splat(@splat(_ShaderAllowedSamplePair{})),
        sample_pairs_allowed_in_vertex_shaders_len: [_NUM_VERTEX_SHADERS]u32 = @splat(0),
        sample_pairs_allowed_in_fragment_shaders: [_NUM_FRAGMENT_SHADERS][config.SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS]_ShaderAllowedSamplePair = @splat(@splat(_ShaderAllowedSamplePair{})),
        sample_pairs_allowed_in_fragment_shaders_len: [_NUM_FRAGMENT_SHADERS]u32 = @splat(0),
        uniform_registers_used_this_shader: [_NUM_UNIFORM_STRUCTS]RegisterWithSource = undefined,
        uniform_registers_used_this_shader_len: u32 = 0,
        uniform_registers_used_this_shader_max: u32 = 0,
        uniform_registers_used_this_shader_auto_count: u32 = 0,
        uniform_registers_used_this_shader_manual_count: u32 = 0,
        next_uniform_register_to_check: u32 = 0,
        storage_registers_used_this_shader: [config.SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS]StorageRegisterWithSourceAndKind = undefined,
        storage_registers_used_this_shader_len: u32 = 0,
        storage_registers_used_this_shader_max: u32 = 0,
        storage_registers_used_this_shader_auto_count: u32 = 0,
        storage_registers_used_this_shader_manual_count: u32 = 0,
        next_storage_register_to_check: u32 = 0,

        fn reset_for_next_linkage(self: *SELF_VARS) void {
            self.uniform_registers_used_this_shader_len = 0;
            self.uniform_registers_used_this_shader_max = 0;
            self.uniform_registers_used_this_shader_auto_count = 0;
            self.uniform_registers_used_this_shader_manual_count = 0;
            self.next_uniform_register_to_check = 0;
            self.storage_registers_used_this_shader_len = 0;
            self.storage_registers_used_this_shader_max = 0;
            self.storage_registers_used_this_shader_auto_count = 0;
            self.storage_registers_used_this_shader_manual_count = 0;
            self.next_storage_register_to_check = 0;
        }
    };
    comptime var vars = VARS{};
    // COMPTIME SUB-ROUTINES ONLY NEEDED FOR THIS BLOCK
    const SUB_ROUTINE = struct {
        const SELF_SUB_ROUTINE = @This();
        fn process_uniform_linkage(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime link: _UniformRegister,
            comptime ridx: u32,
            comptime stage: ShaderStage,
        ) void {
            const uni_idx = @intFromEnum(link.uniform);
            switch (stage) {
                .VERTEX => {
                    ct_assert_with_reason(v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.uniform), shader_name });
                    v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed = true;
                },
                .FRAGMENT => {
                    ct_assert_with_reason(v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.uniform), shader_name });
                    v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed = true;
                },
            }
            switch (link.register) {
                .MANUAL => |reg_num| {
                    for (v.uniform_registers_used_this_shader[0..v.uniform_registers_used_this_shader_len]) |used_register| {
                        switch (used_register.register) {
                            .MANUAL => |used_num| {
                                ct_assert_with_reason(used_num != reg_num, @src(), "in {s} shader `{s}` uniform `{s}` tried to bind to an already bound register {d}", .{ @tagName(stage), shader_name, @tagName(link.uniform), reg_num });
                            },
                            else => {},
                        }
                    }
                    v.uniform_registers_used_this_shader_manual_count += 1;
                    update_max(reg_num, &v.uniform_registers_used_this_shader_max);
                    if (reg_num == v.next_uniform_register_to_check) {
                        v.next_uniform_register_to_check += 1;
                    }
                },
                .AUTO => {
                    v.uniform_registers_used_this_shader_auto_count += 1;
                },
            }
            const reg_source = RegisterWithSource{ .register = link.register, .source = @intCast(ridx) };
            v.uniform_registers_used_this_shader[v.uniform_registers_used_this_shader_len] = reg_source;
            v.uniform_registers_used_this_shader_len += 1;
        }
        fn process_storage_register(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime reg: StorageRegisterWithSourceAndKind,
            comptime tag_name: []const u8,
            comptime tag_idx: ?u32,
            comptime stage: ShaderStage,
            comptime tex: ?TEXTURE_NAMES_ENUM,
            comptime samp: ?SAMPLER_NAMES_ENUM,
        ) void {
            switch (reg.register) {
                .MANUAL => |reg_num| {
                    for (v.storage_registers_used_this_shader[0..v.storage_registers_used_this_shader_len]) |used_register| {
                        switch (used_register.register) {
                            .MANUAL => |used_num| {
                                ct_assert_with_reason(used_num != reg_num, @src(), "in {s} shader `{s}` {s} `{s}` tried to bind to an already bound register {d}", .{ @tagName(stage), shader_name, @tagName(reg.kind), tag_name, reg_num });
                            },
                            else => {},
                        }
                    }
                    v.storage_registers_used_this_shader_manual_count += 1;
                    update_max(reg_num, &v.storage_registers_used_this_shader_max);
                    if (reg_num == v.next_storage_register_to_check) {
                        v.next_storage_register_to_check += 1;
                    }
                    switch (reg.kind) {
                        .STORAGE_BUFFER => switch (stage) {
                            .VERTEX => v.storage_buffers_allowed_in_vertex_shaders[shader_idx][tag_idx.?].register = reg_num,
                            .FRAGMENT => v.storage_buffers_allowed_in_fragment_shaders[shader_idx][tag_idx.?].register = reg_num,
                        },
                        .STORAGE_TEXTURE => switch (stage) {
                            .VERTEX => v.storage_textures_allowed_in_vertex_shaders[shader_idx][tag_idx.?].register = reg_num,
                            .FRAGMENT => v.storage_textures_allowed_in_fragment_shaders[shader_idx][tag_idx.?].register = reg_num,
                        },
                        .SAMPLED_PAIR => switch (stage) {
                            .VERTEX => {
                                const id = Types.combine_2_enums(samp.?, tex.?);
                                const did_find_id = Utils.mem_search_implicit(@ptrCast(&v.sample_pairs_allowed_in_vertex_shaders[shader_idx]), 0, @intCast(v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx]), id);
                                if (did_find_id) |found_idx| {
                                    ct_assert_with_reason(v.sample_pairs_allowed_in_vertex_shaders[shader_idx][found_idx].allowed == false, @src(), "in vertex shader `{s}`, sample pair `{s}` + `{s}` was bound more than once", .{ shader_name, @tagName(samp.?), @tagName(tex.?) });
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][found_idx].allowed == true;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][found_idx].register == reg_num;
                                } else {
                                    const new_idx = v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx];
                                    v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx] += 1;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][new_idx].allowed == true;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][new_idx].register == reg_num;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][new_idx].combined_id == id;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][new_idx].sampler == samp.?;
                                    v.sample_pairs_allowed_in_vertex_shaders[shader_idx][new_idx].texture == tex.?;
                                }
                            },
                            .FRAGMENT => {
                                const id = Types.combine_2_enums(samp.?, tex.?);
                                const did_find_id = Utils.mem_search_implicit(@ptrCast(&v.sample_pairs_allowed_in_fragment_shaders[shader_idx]), 0, @intCast(v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx]), id);
                                if (did_find_id) |found_idx| {
                                    ct_assert_with_reason(v.sample_pairs_allowed_in_fragment_shaders[shader_idx][found_idx].allowed == false, @src(), "in fragment shader `{s}`, sample pair `{s}` + `{s}` was bound more than once", .{ shader_name, @tagName(samp.?), @tagName(tex.?) });
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][found_idx].allowed == true;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][found_idx].register == reg_num;
                                } else {
                                    const new_idx = v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx];
                                    v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx] += 1;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][new_idx].allowed == true;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][new_idx].register == reg_num;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][new_idx].combined_id == id;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][new_idx].sampler == samp.?;
                                    v.sample_pairs_allowed_in_fragment_shaders[shader_idx][new_idx].texture == tex.?;
                                }
                            },
                        },
                    }
                },
                .AUTO => {
                    v.storage_registers_used_this_shader_auto_count += 1;
                },
            }
            v.storage_registers_used_this_shader[v.storage_registers_used_this_shader_len] = reg;
            v.storage_registers_used_this_shader_len += 1;
        }
        fn process_storage_buffer_linkage(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime link: _StorageBufferRegister,
            comptime ridx: u32,
            comptime stage: ShaderStage,
        ) void {
            const buf_idx = @intFromEnum(link.buffer);
            if (stage == .VERTEX) {
                ct_assert_with_reason(v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.buffer), shader_name });
                v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed = true;
            } else {
                ct_assert_with_reason(v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.buffer), shader_name });
                v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].allowed = true;
            }
            const reg_source = StorageRegisterWithSourceAndKind{ .register = link.register, .source = @intCast(ridx), .kind = .STORAGE_BUFFER };
            SELF_SUB_ROUTINE.process_storage_register(v, shader_idx, shader_name, reg_source, @tagName(link.buffer), @intCast(@intFromEnum(link.buffer)), ridx, stage, null, null);
        }
        fn process_storage_texture_linkage(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime link: _ReadOnlyStorageTextureRegister,
            comptime ridx: u32,
            comptime stage: ShaderStage,
        ) void {
            const tex_idx = @intFromEnum(link.texture);
            if (stage == .VERTEX) {
                ct_assert_with_reason(v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.texture), shader_name });
                v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed = true;
            } else {
                ct_assert_with_reason(v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.texture), shader_name });
                v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].allowed = true;
            }
            const reg_source = StorageRegisterWithSourceAndKind{ .register = link.register, .source = @intCast(ridx), .kind = .STORAGE_BUFFER };
            SELF_SUB_ROUTINE.process_storage_register(v, shader_idx, shader_name, reg_source, @tagName(link.buffer), @intCast(@intFromEnum(link.buffer)), ridx, stage, null, null);
        }
        fn process_sample_pair_linkage(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime shader_name: []const u8,
            comptime link: _ReadOnlySampledTextureRegister,
            comptime ridx: u32,
            comptime stage: ShaderStage,
        ) void {
            const reg_source = StorageRegisterWithSourceAndKind{ .register = link.register, .source = @intCast(ridx), .kind = .SAMPLED_PAIR };
            SELF_SUB_ROUTINE.process_storage_register(v, shader_idx, shader_name, reg_source, @tagName(link.sampler) ++ "__" ++ @tagName(link.texture), null, ridx, stage, link.texture, link.sampler);
        }
        fn provision_auto_uniform_slots(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime vert_linkages: []const VertexShaderDefinition(VERTEX_SHADER_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
            comptime frag_linkages: []const FragmentShaderDefinition(FRAGMENT_SHADER_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
            comptime register: RegisterWithSource,
            comptime stage: ShaderStage,
        ) void {
            var current_slot_to_check: u32 = v.next_uniform_register_to_check;
            try_next_num: while (true) : (current_slot_to_check += 1) {
                for (v.uniform_registers_used_this_shader[0..v.uniform_registers_used_this_shader_len]) |existing_register| {
                    switch (existing_register.register) {
                        .MANUAL => |used_slot| {
                            if (used_slot == current_slot_to_check) continue :try_next_num;
                        },
                        else => {},
                    }
                }
                break :try_next_num;
            }
            switch (stage) {
                .VERTEX => {
                    const source_linkage: _UniformRegister = find: {
                        for (vert_linkages) |linkage| {
                            if (@intFromEnum(linkage.vertex_shader) == shader_idx) {
                                break :find linkage.resources_to_link[register.source].UNIFORM_BUFFER;
                            }
                        }
                        unreachable;
                    };
                    v.uniforms_allowed_in_vertex_shaders[shader_idx][@intFromEnum(source_linkage.uniform)].register = current_slot_to_check;
                    update_max(current_slot_to_check, &v.uniform_registers_used_this_shader_max);
                    v.next_uniform_register_to_check = current_slot_to_check + 1;
                },
                .FRAGMENT => {
                    const source_linkage: _UniformRegister = find: {
                        for (frag_linkages) |linkage| {
                            if (@intFromEnum(linkage.fragment_shader) == shader_idx) {
                                break :find linkage.resources_to_link[register.source].UNIFORM_BUFFER;
                            }
                        }
                        unreachable;
                    };
                    v.uniforms_allowed_in_fragment_shaders[shader_idx][@intFromEnum(source_linkage.uniform)].register = current_slot_to_check;
                    update_max(current_slot_to_check, &v.uniform_registers_used_this_shader_max);
                    v.next_uniform_register_to_check = current_slot_to_check + 1;
                },
            }
        }
        fn provision_auto_storage_slots(
            comptime v: *VARS,
            comptime shader_idx: u32,
            comptime vert_linkages: []const VertexShaderDefinition(VERTEX_SHADER_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
            comptime frag_linkages: []const FragmentShaderDefinition(FRAGMENT_SHADER_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
            comptime register: *StorageRegisterWithSourceAndKind,
            comptime stage: ShaderStage,
        ) void {
            var current_slot_to_check: u32 = v.next_storage_register_to_check;
            try_next_num: while (true) : (current_slot_to_check += 1) {
                for (v.storage_registers_used_this_shader[0..v.storage_registers_used_this_shader_len]) |existing_register| {
                    switch (existing_register.register) {
                        .MANUAL => |used_slot| {
                            if (used_slot == current_slot_to_check) continue :try_next_num;
                        },
                        else => {},
                    }
                }
                break :try_next_num;
            }
            register.register = .register_num(current_slot_to_check);
            switch (stage) {
                .VERTEX => {
                    const source_linkage = find: {
                        for (vert_linkages) |linkage| {
                            if (@intFromEnum(linkage.vertex_shader) == shader_idx) {
                                break :find linkage.resources_to_link[register.source];
                            }
                        }
                        unreachable;
                    };
                    switch (source_linkage) {
                        .STORAGE_TEXTURE => |link| v.storage_textures_allowed_in_vertex_shaders[shader_idx][@intFromEnum(link.texture)].register = current_slot_to_check,
                        .STORAGE_BUFFER => |link| v.storage_buffers_allowed_in_vertex_shaders[shader_idx][@intFromEnum(link.buffer)].register = current_slot_to_check,
                        .SAMPLED_TEXTURE => |link| {
                            const proto_pair = ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM){
                                .combined_id = Types.combine_2_enums(link.sampler, link.texture),
                            };
                            const found_source = Utils.mem_search_with_func(@ptrCast(&v.sample_pairs_allowed_in_vertex_shaders[shader_idx]), 0, v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx], proto_pair, ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).equals_id);
                            if (found_source) |source_idx| {
                                v.sample_pairs_allowed_in_vertex_shaders[shader_idx][source_idx].register = current_slot_to_check;
                            } else {
                                unreachable;
                            }
                        },
                        else => unreachable,
                    }
                    update_max(current_slot_to_check, &v.storage_registers_used_this_shader_max);
                    v.next_storage_register_to_check = current_slot_to_check + 1;
                },
                .FRAGMENT => {
                    const source_linkage = find: {
                        for (frag_linkages) |linkage| {
                            if (@intFromEnum(linkage.fragment_shader) == shader_idx) {
                                break :find linkage.resources_to_link[register.source];
                            }
                        }
                        unreachable;
                    };
                    switch (source_linkage) {
                        .STORAGE_TEXTURE => |link| v.storage_textures_allowed_in_fragment_shaders[shader_idx][@intFromEnum(link.texture)].register = current_slot_to_check,
                        .STORAGE_BUFFER => |link| v.storage_buffers_allowed_in_fragment_shaders[shader_idx][@intFromEnum(link.buffer)].register = current_slot_to_check,
                        .SAMPLED_TEXTURE => |link| {
                            const proto_pair = ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM){
                                .combined_id = Types.combine_2_enums(link.sampler, link.texture),
                            };
                            const found_source = Utils.mem_search_with_func(@ptrCast(&v.sample_pairs_allowed_in_fragment_shaders[shader_idx]), 0, v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx], proto_pair, ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).equals_id);
                            if (found_source) |source_idx| {
                                v.sample_pairs_allowed_in_fragment_shaders[shader_idx][source_idx].register = current_slot_to_check;
                            } else {
                                unreachable;
                            }
                        },
                        else => unreachable,
                    }
                    update_max(current_slot_to_check, &v.storage_registers_used_this_shader_max);
                    v.next_storage_register_to_check = current_slot_to_check + 1;
                },
            }
        }
    };
    // COMPTIME VALIDATION / ORGANIZATION OF VERTEX SHADER BINDINGS
    comptime var vertex_linkages_defined: [_NUM_VERTEX_SHADERS]bool = @splat(false);
    comptime var ordered_vertex_shader_definitions: [_NUM_VERTEX_SHADERS]_VertexShaderDefinition = undefined;
    inline for (VERTEX_SHADER_DEFINITIONS[0..]) |linkage| {
        const vert_idx = @intFromEnum(linkage.vertex_shader);
        ct_assert_with_reason(vertex_linkages_defined[vert_idx] == false, @src(), "linkage for vertex shader `{s}` was defined twice", .{@tagName(linkage.vertex_shader)});
        vertex_linkages_defined[vert_idx] = true;
        ordered_vertex_shader_definitions[vert_idx] = linkage;
        vars.reset_for_next_linkage();
        // LOG REGISTERS FOR VARIOUS RESOURCES
        for (linkage.resources_to_link, 0..) |resource, ridx| {
            switch (resource) {
                .UNIFORM_BUFFER => |link| {
                    SUB_ROUTINE.process_uniform_linkage(&vars, @intCast(vert_idx), @tagName(linkage.vertex_shader), link, @intCast(ridx), .VERTEX);
                },
                .SAMPLED_TEXTURE => |link| {
                    SUB_ROUTINE.process_sample_pair_linkage(&vars, @intCast(vert_idx), @tagName(linkage.vertex_shader), link, @intCast(ridx), .VERTEX);
                },
                .STORAGE_TEXTURE => |link| {
                    SUB_ROUTINE.process_storage_texture_linkage(&vars, @intCast(vert_idx), @tagName(linkage.vertex_shader), link, @intCast(ridx), .VERTEX);
                },
                .STORAGE_BUFFER => |link| {
                    SUB_ROUTINE.process_storage_buffer_linkage(&vars, @intCast(vert_idx), @tagName(linkage.vertex_shader), link, @intCast(ridx), .VERTEX);
                },
            }
        }
        // CHECK IF IT IS DEFINITELY IMPOSSIBLE TO COMPILE (MAX REGISTER FOR A GROUP IS >= TOTAL NUM REGISTERS FOR THAT GROUP = AN EMPTY REGISTER IS INEVITABLE)
        ct_assert_with_reason(vars.uniform_registers_used_this_shader_len > vars.uniform_registers_used_this_shader_max, @src(), "uniform registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        ct_assert_with_reason(vars.storage_registers_used_this_shader_len > vars.storage_registers_used_this_shader_max, @src(), "storage registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        // SORT STORAGE REGISTERS SO UNUSED SLOTS ARE GIVEN OUT IN THE ORDER: SAMPLE_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than);
        // NEXT, GO THROUGH AND RESOLVE ALL 'AUTO' BINDINGS TO FILL UNUSED SLOTS, THEN CHECK IF PROVISIONING RESULTED IN TOTAL == (MAX + 1),
        // WITH STORAGE SLOTS IN CORRECT ORDER (SAMPLED_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS)
        for (vars.uniform_registers_used_this_shader[0..vars.uniform_registers_used_this_shader_len]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, @intCast(vert_idx), vertex_linkages, fragment_linkages, uni_register, .VERTEX);
        }
        ct_assert_with_reason(vars.uniform_registers_used_this_shader_len == vars.uniform_registers_used_this_shader_max + 1, @src(), "uniform registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        for (vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, @intCast(vert_idx), vertex_linkages, fragment_linkages, storage_register, .VERTEX);
        }
        ct_assert_with_reason(vars.storage_registers_used_this_shader_len == vars.storage_registers_used_this_shader_max + 1, @src(), "storage registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than_only_register);
        ct_assert_with_reason(Utils.mem_is_sorted_with_func(@ptrCast(&vars.storage_registers_used_this_shader), 0, vars.storage_registers_used_this_shader_len, StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in vertex shader `{s}` are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len] });
    }
    const ordered_vertex_shader_definitions_const = ordered_vertex_shader_definitions;
    // COMPTIME VALIDATION / ORGANIZATION OF FRAGMENT SHADER BINDINGS
    comptime var fragment_linkages_defined: [_NUM_FRAGMENT_SHADERS]bool = @splat(false);
    comptime var ordered_fragment_shader_definitions: [_NUM_VERTEX_SHADERS]_FragmentShaderDefinition = undefined;
    inline for (FRAGMENT_SHADER_DEFINITIONS[0..]) |linkage| {
        const frag_idx = @intFromEnum(linkage.fragment_shader);
        ct_assert_with_reason(fragment_linkages_defined[frag_idx] == false, @src(), "linkage for fragment shader `{s}` was defined twice", .{@tagName(linkage.fragment_shader)});
        fragment_linkages_defined[frag_idx] = true;
        ordered_fragment_shader_definitions[frag_idx] = linkage;
        vars.reset_for_next_linkage();
        // LOG REGISTERS FOR VARIOUS RESOURCES
        for (linkage.resources_to_link, 0..) |resource, ridx| {
            switch (resource) {
                .UNIFORM_BUFFER => |link| {
                    SUB_ROUTINE.process_uniform_linkage(&vars, @intCast(frag_idx), @tagName(linkage.fragment_shader), link, @intCast(ridx), .FRAGMENT);
                },
                .SAMPLED_TEXTURE => |link| {
                    SUB_ROUTINE.process_sample_pair_linkage(&vars, @intCast(frag_idx), @tagName(linkage.fragment_shader), link, @intCast(ridx), .FRAGMENT);
                },
                .STORAGE_TEXTURE => |link| {
                    SUB_ROUTINE.process_storage_texture_linkage(&vars, @intCast(frag_idx), @tagName(linkage.fragment_shader), link, @intCast(ridx), .FRAGMENT);
                },
                .STORAGE_BUFFER => |link| {
                    SUB_ROUTINE.process_storage_buffer_linkage(&vars, @intCast(frag_idx), @tagName(linkage.fragment_shader), link, @intCast(ridx), .FRAGMENT);
                },
            }
        }
        // CHECK IF IT IS DEFINITELY IMPOSSIBLE TO COMPILE (MAX REGISTER FOR A GROUP IS >= TOTAL NUM REGISTERS FOR THAT GROUP = AN EMPTY REGISTER IS INEVITABLE)
        ct_assert_with_reason(vars.uniform_registers_used_this_shader_len > vars.uniform_registers_used_this_shader_max, @src(), "uniform registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        ct_assert_with_reason(vars.storage_registers_used_this_shader_len > vars.storage_registers_used_this_shader_max, @src(), "storage registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        // SORT STORAGE REGISTERS SO UNUSED SLOTS ARE GIVEN OUT IN THE ORDER: SAMPLE_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than);
        // NEXT, GO THROUGH AND RESOLVE ALL 'AUTO' BINDINGS TO FILL UNUSED SLOTS, THEN CHECK IF PROVISIONING RESULTED IN TOTAL == (MAX + 1),
        // WITH STORAGE SLOTS IN CORRECT ORDER (SAMPLED_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS)
        for (vars.uniform_registers_used_this_shader[0..vars.uniform_registers_used_this_shader_len]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, @intCast(frag_idx), vertex_linkages, fragment_linkages, uni_register, .VERTEX);
        }
        ct_assert_with_reason(vars.uniform_registers_used_this_shader_len == vars.uniform_registers_used_this_shader_max + 1, @src(), "uniform registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        for (vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, @intCast(frag_idx), vertex_linkages, fragment_linkages, storage_register, .VERTEX);
        }
        ct_assert_with_reason(vars.storage_registers_used_this_shader_len == vars.storage_registers_used_this_shader_max + 1, @src(), "storage registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than_only_register);
        ct_assert_with_reason(Utils.mem_is_sorted_with_func(@ptrCast(&vars.storage_registers_used_this_shader), 0, vars.storage_registers_used_this_shader_len, StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in vertex shader `{s}` are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len] });
    }
    const ordered_fragment_shader_definitions_const = ordered_fragment_shader_definitions;
    // COMPILE A CONDENSED LIST OF ALLOWED UNIFORMS
    comptime var total_num_allowed_uniforms_vert: u32 = 0;
    comptime var total_num_allowed_uniforms_frag: u32 = 0;
    comptime var uniform_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var uniform_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        uniform_starts_vert[v] = total_num_allowed_uniforms_vert;
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_vertex_shaders[v][u].allowed) {
                total_num_allowed_uniforms_vert += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        uniform_starts_frag[f] = total_num_allowed_uniforms_frag;
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_fragment_shaders[f][u].allowed) {
                total_num_allowed_uniforms_frag += 1;
            }
        }
    }
    uniform_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_uniforms_vert;
    uniform_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_uniforms_frag;
    comptime var all_allowed_uniforms_flat_vert: [total_num_allowed_uniforms_vert]_ShaderAllowedUniform = undefined;
    comptime var all_allowed_uniforms_flat_frag: [total_num_allowed_uniforms_frag]_ShaderAllowedUniform = undefined;
    comptime var vi: u32 = 0;
    comptime var fi: u32 = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = vi;
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_vertex_shaders[v][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .uniform = @enumFromInt(@as(Types.enum_tag_type(GPU_UNIFORM_NAMES_ENUM), @intCast(u))),
                    .register = vars.uniforms_allowed_in_vertex_shaders[v][u].register,
                };
                all_allowed_uniforms_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedUniform, all_allowed_uniforms_flat_vert[start..vi], _ShaderAllowedUniform.register_greater);
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = fi;
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_fragment_shaders[f][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .uniform = @enumFromInt(@as(Types.enum_tag_type(GPU_UNIFORM_NAMES_ENUM), @intCast(u))),
                    .register = vars.uniforms_allowed_in_fragment_shaders[f][u].register,
                };
                all_allowed_uniforms_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedUniform, all_allowed_uniforms_flat_frag[start..fi], _ShaderAllowedUniform.register_greater);
    }
    const uniform_starts_vert_const = uniform_starts_vert;
    const uniform_starts_frag_const = uniform_starts_frag;
    const all_allowed_uniforms_flat_vert_const = all_allowed_uniforms_flat_vert;
    const all_allowed_uniforms_flat_frag_const = all_allowed_uniforms_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED STORAGE BUFFERS
    comptime var total_num_allowed_storage_buffers_vert: u32 = 0;
    comptime var total_num_allowed_storage_buffers_frag: u32 = 0;
    comptime var longest_storage_buffer_set_vert: u32 = 0;
    comptime var longest_storage_buffer_set_frag: u32 = 0;
    comptime var storage_buffer_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_buffer_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_buffer_starts_vert[v] = total_num_allowed_storage_buffers_vert;
        comptime var num_allowed_this_shader: u32 = 0;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_buffer_set_vert = @max(longest_storage_buffer_set_vert, num_allowed_this_shader);
        total_num_allowed_storage_buffers_vert += num_allowed_this_shader;
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_buffer_starts_frag[f] = total_num_allowed_storage_buffers_frag;
        comptime var num_allowed_this_shader: u32 = 0;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
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
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = vi;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@as(Types.enum_tag_type(GPU_STORAGE_BUFFER_NAMES_ENUM), @intCast(sb))),
                    .register = vars.storage_buffers_allowed_in_vertex_shaders[v][sb].register,
                };
                all_allowed_storage_buffers_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedStorageBuffer, all_allowed_storage_buffers_flat_vert[start..vi], _ShaderAllowedStorageBuffer.register_greater);
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = fi;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_fragment_shaders[f][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@as(Types.enum_tag_type(GPU_STORAGE_BUFFER_NAMES_ENUM), @intCast(sb))),
                    .register = vars.storage_buffers_allowed_in_fragment_shaders[f][sb].register,
                };
                all_allowed_storage_buffers_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedStorageBuffer, all_allowed_storage_buffers_flat_frag[start..vi], _ShaderAllowedStorageBuffer.register_greater);
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
    comptime var longest_storage_texture_set_vert: u32 = 0;
    comptime var longest_storage_texture_set_frag: u32 = 0;
    comptime var storage_texture_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_texture_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_texture_starts_vert[v] = total_num_allowed_storage_textures_vert;
        comptime var num_allowed_this_shader: u32 = 0;
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                num_allowed_this_shader += 1;
            }
        }
        longest_storage_texture_set_vert = @max(longest_storage_texture_set_vert, num_allowed_this_shader);
        total_num_allowed_storage_textures_vert += num_allowed_this_shader;
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_texture_starts_frag[f] = total_num_allowed_storage_textures_frag;
        comptime var num_allowed_this_shader: u32 = 0;
        inline for (0.._NUM_TEXTURES) |t| {
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
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        const start = vi;
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                    .register = vars.storage_textures_allowed_in_vertex_shaders[v][t].register,
                };
                all_allowed_storage_textures_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedStorageTexture, all_allowed_storage_textures_flat_vert[start..vi], _ShaderAllowedStorageTexture.register_greater);
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        const start = fi;
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_fragment_shaders[f][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .texture = @enumFromInt(@as(Types.enum_tag_type(TEXTURE_NAMES_ENUM), @intCast(t))),
                    .register = vars.storage_textures_allowed_in_fragment_shaders[f][t].register,
                };
                all_allowed_storage_textures_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
        Sort.insertion_sort_with_func(_ShaderAllowedStorageTexture, all_allowed_storage_textures_flat_frag[start..fi], _ShaderAllowedStorageTexture.register_greater);
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
    comptime var sample_pair_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var sample_pair_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        sample_pair_starts_vert[v] = total_num_allowed_sample_pairs_vert;
        total_num_allowed_sample_pairs_vert += vars.sample_pairs_allowed_in_vertex_shaders_len[v];
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        sample_pair_starts_frag[f] = total_num_allowed_sample_pairs_frag;
        total_num_allowed_sample_pairs_frag += vars.sample_pairs_allowed_in_fragment_shaders_len[f];
    }
    sample_pair_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_sample_pairs_vert;
    sample_pair_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_sample_pairs_frag;
    comptime var longest_sample_pair_set_vert: u32 = 0;
    comptime var longest_sample_pair_set_frag: u32 = 0;
    comptime var all_allowed_sample_pairs_flat_vert: [total_num_allowed_sample_pairs_vert]_ShaderAllowedSamplePair = undefined;
    comptime var all_allowed_sample_pairs_flat_frag: [total_num_allowed_sample_pairs_frag]_ShaderAllowedSamplePair = undefined;
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        longest_sample_pair_set_vert = @max(longest_sample_pair_set_vert, vars.sample_pairs_allowed_in_vertex_shaders_len[v]);
        Sort.insertion_sort_with_func(_ShaderAllowedSamplePair, vars.sample_pairs_allowed_in_vertex_shaders[v][0..vars.sample_pairs_allowed_in_vertex_shaders_len[v]], _ShaderAllowedSamplePair.register_greater);
        inline for (vars.sample_pairs_allowed_in_vertex_shaders[v][0..vars.sample_pairs_allowed_in_vertex_shaders_len[v]]) |samp| {
            all_allowed_sample_pairs_flat_vert[vi] = samp;
            vi += 1;
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        longest_sample_pair_set_frag = @max(longest_sample_pair_set_frag, vars.sample_pairs_allowed_in_fragment_shaders_len[f]);
        Sort.insertion_sort_with_func(_ShaderAllowedSamplePair, vars.sample_pairs_allowed_in_fragment_shaders[f][0..vars.sample_pairs_allowed_in_fragment_shaders_len[f]], _ShaderAllowedSamplePair.register_greater);
        inline for (vars.sample_pairs_allowed_in_fragment_shaders[f][0..vars.sample_pairs_allowed_in_fragment_shaders_len[f]]) |samp| {
            all_allowed_sample_pairs_flat_frag[fi] = samp;
            fi += 1;
        }
    }
    const longest_sample_pair_set_vert_const = longest_sample_pair_set_vert;
    const longest_sample_pair_set_frag_const = longest_sample_pair_set_frag;
    const sample_pair_starts_vert_const = sample_pair_starts_vert;
    const sample_pair_starts_frag_const = sample_pair_starts_frag;
    const all_allowed_sample_pairs_flat_vert_const = all_allowed_sample_pairs_flat_vert;
    const all_allowed_sample_pairs_flat_frag_const = all_allowed_sample_pairs_flat_frag;
    // VALIDATE RENDER PIPELINES
    comptime var total_num_vertex_buffers_to_bind: u32 = 0;
    comptime var total_num_field_mappings: u32 = 0;
    comptime var vertex_buffers_to_bind_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
    comptime var vertex_attribute_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
    comptime var longest_set_of_vertex_buffers: u32 = 0;
    // FIRST PASS ROUGH VALIDATION AND COUNTS
    inline for (0.._NUM_RENDER_PIPELINES) |pipe_idx| {
        comptime var vertex_buffer_count_this_pipeline: u32 = 0;
        comptime var vertex_buffers_for_this_pipeline: [_NUM_VERT_BUFFERS]bool = @splat(false);
        const pipe_name: RENDER_PIPELINE_NAMES_ENUM = @enumFromInt(@as(Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), @intCast(pipe_idx)));
        const pipe_def = ordered_pipeline_definitions_const[pipe_idx];
        const vert_idx = @intFromEnum(pipe_def.vertex);
        const frag_idx = @intFromEnum(pipe_def.fragment);
        const vert_def = ordered_vertex_shader_definitions_const[vert_idx];
        const frag_def = ordered_fragment_shader_definitions_const[frag_idx];
        const vert_struct_in_idx = @intFromEnum(vert_def.input_type);
        const frag_struct_out_idx = @intFromEnum(frag_def.output_type);
        ct_assert_with_reason(vert_def.output_type == frag_def.input_type, @src(), "for render pipeline `{s}` the vertex shader output type `{s}` does not match the fragment shader input type `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), @tagName(pipe_def.fragment) });
        ct_assert_with_reason(pipe_def.vertex_field_maps.len == ordered_shader_struct_locations_quick_info_const[vert_struct_in_idx].num_locations, @src(), "for render pipeline `{s}` the vertex shader has {d} input loacations, but {d} vertex field mappings", .{ @tagName(pipe_name), ordered_shader_struct_locations_quick_info_const[vert_struct_in_idx].num_locations, pipe_def.vertex_field_maps.len });
        ct_assert_with_reason(pipe_def.target_info.num_color_targets == ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].num_locations, @src(), "for render pipeline `{s}` the fragment shader has {d} color targets, but `target_info.num_color_targets` = {d}", .{ @tagName(pipe_name), ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].num_locations, pipe_def.target_info.num_color_targets });
        if (VALIDATION.color_texture_non_color_format and pipe_def.target_info.num_color_targets > 0) {
            ct_assert_with_reason(pipe_def.target_info.color_target_descriptions != null, @src(), "for render pipeline `{s}` `target_info.num_color_targets == {d}` but `target_info.color_target_descriptions == null`", .{ @tagName(pipe_name), pipe_def.target_info.num_color_targets });
            inline for (pipe_def.target_info.color_target_descriptions.?[0..pipe_def.target_info.num_color_targets], 0..) |target, t| {
                ct_assert_with_reason(!target.format.is_depth_format(), @src(), "for render pipeline `{s}` color target {d}, the texture format is not a COLOR format, got `{s}`", .{ @tagName(pipe_name), @tagName(target.format) });
                ct_assert_with_reason(target.blend_state.none_invalid_if_option_enabled(), @src(), "for render pipeline `{s}` color target {d}, `blend_state` options are enabled, but have one or more `.INVALID` modes or a blank color write mask", .{ @tagName(pipe_name), t });
            }
        }
        ct_assert_with_reason(pipe_def.target_info.has_depth_stencil_target == ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].has_depth_target, @src(), "for render pipeline `{s}` the depth buffer enable setting `{any}` does not match the fragment shader `{s}` depth target state `{any}`", .{ @tagName(pipe_name), pipe_def.target_info.has_depth_stencil_target, @tagName(pipe_def.fragment), ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].has_depth_target });
        if (pipe_def.target_info.has_depth_stencil_target) {
            ct_assert_with_reason(pipe_def.target_info.depth_stencil_format.is_depth_format(), @src(), "for render pipeline `{s}`, `target_info.has_depth_stencil_target == true` but the `target_info.depth_stencil_format` is is not a depth format, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
            ct_assert_with_reason(!pipe_def.depth_stencil_options.enable_depth_test or pipe_def.depth_stencil_options.compare_op != .INVALID, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_depth_test == true` while `depth_stencil_options.compare_op == .INVALID`", .{@tagName(pipe_name)});
            ct_assert_with_reason(!pipe_def.depth_stencil_options.enable_stencil_test or (pipe_def.depth_stencil_options.back_stencil_state.none_invalid() and pipe_def.depth_stencil_options.front_stencil_state.none_invalid()), @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while either `depth_stencil_options.front_stencil_state` or `depth_stencil_options.back_stencil_state` has `.INVALID` entries", .{@tagName(pipe_name)});
            if (VALIDATION.depth_texture_non_stencil_format and pipe_def.depth_stencil_options.enable_stencil_test) {
                ct_assert_with_reason(pipe_def.target_info.depth_stencil_format.has_depth_stencil(), @src(), "for render pipeline `{s}`, `depth_stencil_options.enable_stencil_test == true` but the `target_info.depth_stencil_format` is does not have a stencil, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
            }
            if (VALIDATION.depth_stencil_zero_bits and pipe_def.depth_stencil_options.enable_stencil_test) {
                ct_assert_with_reason(pipe_def.depth_stencil_options.compare_mask != 0 and pipe_def.depth_stencil_options.write_mask != 0, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while `depth_stencil_options.write_mask` or `depth_stencil_options.compare_mask` equal zero (in effect no depth stencil will be compared or written)", .{@tagName(pipe_name)});
            }
        }
        vertex_buffers_to_bind_start_locs[pipe_idx] = total_num_vertex_buffers_to_bind;
        vertex_attribute_start_locs[pipe_idx] = total_num_field_mappings;
        inline for (pipe_def.vertex_field_maps) |field_map| {
            const vert_buf_idx = @intFromEnum(field_map.vertex_buffer);
            if (vertex_buffers_for_this_pipeline[vert_buf_idx] == false) {
                vertex_buffer_count_this_pipeline += 1;
                vertex_buffers_for_this_pipeline[vert_buf_idx] = true;
            }
            total_num_field_mappings += 1;
        }
        longest_set_of_vertex_buffers = @max(longest_set_of_vertex_buffers, vertex_buffer_count_this_pipeline);
        total_num_vertex_buffers_to_bind += vertex_buffer_count_this_pipeline;
    }
    vertex_buffers_to_bind_start_locs[_NUM_RENDER_PIPELINES] = total_num_vertex_buffers_to_bind;
    vertex_attribute_start_locs[_NUM_RENDER_PIPELINES] = total_num_field_mappings;
    comptime var vertex_buffer_names_to_bind_per_render_pipeline: [total_num_vertex_buffers_to_bind]GPU_VERTEX_BUFFER_NAMES_ENUM = undefined;
    comptime var vertex_buffers_to_bind_per_render_pipeline: [total_num_vertex_buffers_to_bind]SDL3.GPU_VertexBufferDescription = undefined;
    comptime var vertex_attributes_to_bind_per_render_pipeline: [total_num_field_mappings]SDL3.GPU_VertexAttribute = undefined;
    // SECOND PASS FULL VALIDATION
    inline for (0.._NUM_RENDER_PIPELINES) |pipe_idx| {
        comptime var slots_used: [_NUM_VERT_BUFFERS]u32 = undefined;
        comptime var buffers_used: [_NUM_VERT_BUFFERS]Types.enum_tag_type(GPU_VERTEX_BUFFER_NAMES_ENUM) = undefined;
        comptime var rates_used: [_NUM_VERT_BUFFERS]SDL3.GPU_VertexInputRate = undefined;
        comptime var slots_used_len: u32 = 0;
        comptime var vertex_buffers_for_this_pipeline: [_NUM_VERT_BUFFERS]bool = @splat(false);
        comptime var vertex_buffer_slots_for_this_pipeline: [_NUM_VERT_BUFFERS]Register = @splat(Register.auto_register());
        comptime var vertex_buffer_rates_for_this_pipeline: [_NUM_VERT_BUFFERS]SDL3.GPU_VertexInputRate = @splat(.VERTEX);
        comptime var max_slot_used: u32 = 0;
        const pipe_name: RENDER_PIPELINE_NAMES_ENUM = @enumFromInt(@as(Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), @intCast(pipe_idx)));
        const pipe_def = ordered_pipeline_definitions_const[pipe_idx];
        const vert_idx = @intFromEnum(pipe_def.vertex);
        const vert_def = ordered_vertex_shader_definitions_const[vert_idx];
        const vert_struct_in: ShaderStructDescription = @field(STRUCT_OF_SHADER_STRUCT_DEFINITIONS, @tagName(vert_def.input_type));
        const vert_struct_quick_info = ordered_shader_struct_locations_quick_info_const[@intFromEnum(vert_def.input_type)];
        comptime var locations_used: [vert_struct_quick_info.num_locations]bool = @splat(false);
        comptime var next_slot_to_check_for_use: u32 = 0;
        inline for (pipe_def.vertex_field_maps) |field_map| {
            const vert_buf_idx = @intFromEnum(field_map.vertex_buffer);
            const vert_buf_info: VertexBufferDescription = @field(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, @tagName(field_map.vertex_buffer));
            if (vertex_buffers_for_this_pipeline[vert_buf_idx] == true) {
                ct_assert_with_reason(vertex_buffer_rates_for_this_pipeline[vert_buf_idx] == field_map.vertex_field_input_rate, @src(), "in render pipeline `{s}`, vertex buffer `{s}` had both `.VERTEX` and `.INSTANCE` input rates specified: a vertex buffer can only be bound at one input rate, if you need 2 fields with different rates, they must be on separate vertex buffers", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer) });
            } else {
                vertex_buffers_for_this_pipeline[vert_buf_idx] = true;
                vertex_buffer_rates_for_this_pipeline[vert_buf_idx] = field_map.vertex_field_input_rate;
            }
            switch (field_map.vertex_buffer_bind_slot) {
                .AUTO => {},
                .MANUAL => |new_slot| switch (vertex_buffer_slots_for_this_pipeline[vert_buf_idx]) {
                    .AUTO => {
                        vertex_buffer_slots_for_this_pipeline[vert_buf_idx] = Register.register_num(new_slot);
                        if (Utils.mem_search_implicit(@ptrCast(&slots_used), 0, @intCast(slots_used_len), new_slot)) |found_used_slot_idx| {
                            ct_assert_with_reason(vert_buf_idx == buffers_used[found_used_slot_idx], @src(), "in render pipeline `{s}`, vertex buffer `{s}` was bound to slot {d}, but that slot was already bound to another vertex buffer (`{s}`)", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), new_slot, @tagName(@as(GPU_VERTEX_BUFFER_NAMES_ENUM, @enumFromInt(buffers_used[found_used_slot_idx]))) });
                        } else {
                            if (new_slot == next_slot_to_check_for_use) {
                                next_slot_to_check_for_use += 1;
                            }
                            max_slot_used = @max(max_slot_used, new_slot);
                            slots_used[slots_used_len] = new_slot;
                            buffers_used[slots_used_len] = vert_buf_idx;
                            rates_used[slots_used_len] = field_map.vertex_field_input_rate;
                            slots_used_len += 1;
                        }
                    },
                    .MANUAL => |old_slot| {
                        ct_assert_with_reason(new_slot == old_slot, @src(), "in render pipeline `{s}`, vertex buffer `{s}` was bound to both slots {d} and {d}: only one slot is allowed per vertex buffer per render pipeline", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), new_slot, old_slot });
                    },
                },
            }
            ct_assert_with_reason(@hasDecl(vert_buf_info.fields_info, field_map.vertex_buffer_field_name), @src(), "in render pipeline `{s}`, vertex buffer `{s}` does not have field `{s}` (from `RenderPipelineVertexFieldMap.vertex_buffer_field_name`), available fields are: {any}", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @typeInfo(vert_buf_info.fields_info).@"struct".decls });
            ct_assert_with_reason(@hasDecl(vert_struct_in.fields_info, field_map.shader_struct_field_name), @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` does not have field `{s}` (from `RenderPipelineVertexFieldMap.shader_struct_field_name`), available fields are: {any}", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, @typeInfo(vert_struct_in.fields_info).@"struct".decls });
            const vert_struct_in_field_info: ShaderStructFieldInfo = @field(vert_struct_in.fields_info, field_map.shader_struct_field_name);
            const vert_buf_out_field_info: VertexBufferFieldInfo = @field(vert_buf_info.fields_info, field_map.vertex_buffer_field_name);
            ct_assert_with_reason(locations_used[vert_struct_in_field_info.location] == false, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) was mapped more than once", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location });
            locations_used[vert_struct_in_field_info.location] = true;
            if (VALIDATION.mismatched_gpu_formats) {
                ct_assert_with_reason(vert_struct_in_field_info.gpu_format == vert_buf_out_field_info.gpu_format, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) gpu format `{s}` was mapped from vertex buffer `{s}` field `{s}` gpu format `{s}`: gpu formats MUST match", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location, @tagName(vert_struct_in_field_info.gpu_format), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @tagName(vert_buf_out_field_info.gpu_format) });
            }
            if (VALIDATION.mismatched_cpu_types) {
                ct_assert_with_reason(vert_struct_in_field_info.cpu_type == vert_buf_out_field_info.field_type, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) cpu type `{s}` was mapped from vertex buffer `{s}` field `{s}` field type `{s}`: zig types MUST match", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location, @typeName(vert_struct_in_field_info.cpu_type), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @typeName(vert_buf_out_field_info.field_type) });
            }
        }
        // PROVISION 'AUTO' BUFFER SLOTS
        inline for (0.._NUM_VERT_BUFFERS) |vb| {
            if (vertex_buffers_for_this_pipeline[vb] == true) {
                if (vertex_buffer_slots_for_this_pipeline[vb] == .AUTO) {
                    comptime var s: u32 = 0;
                    inline while (s < slots_used_len) {
                        if (slots_used[s] == next_slot_to_check_for_use) {
                            next_slot_to_check_for_use += 1;
                            s = 0;
                        } else {
                            s += 1;
                        }
                    }
                    max_slot_used = @max(max_slot_used, next_slot_to_check_for_use);
                    slots_used[slots_used_len] = next_slot_to_check_for_use;
                    vertex_buffer_slots_for_this_pipeline[vb] = Register.register_num(next_slot_to_check_for_use);
                    rates_used[slots_used_len] = vertex_buffer_rates_for_this_pipeline[vb];
                    buffers_used[slots_used_len] = vb;
                    slots_used_len += 1;
                    next_slot_to_check_for_use += 1;
                }
            }
        }
        if (VALIDATION.vertex_buffer_slot_gaps) {
            ct_assert_with_reason(max_slot_used + 1 == slots_used_len, @src(), "in render pipeline `{s}`, the max vertex buffer slot used is {d}, but the number of vertex buffer slots used is {d} (a gap exists somewhere): vertex buffer slots must start from 0 and increase with no gaps", .{ @tagName(pipe_name), max_slot_used, slots_used_len });
        }
        // COMPILE VERTEX BUFFER BINDINGS TO FINAL ARRAY
        inline for (0..slots_used_len) |s| {
            const ss: u32 = @intCast(s);
            const buffer_idx = buffers_used[s];
            const buffer_name = @as(GPU_VERTEX_BUFFER_NAMES_ENUM, @enumFromInt(buffers_used[s]));
            const bind = SDL3.GPU_VertexBufferDescription{
                .input_rate = rates_used[s],
                .slot = slots_used[s],
                .stride = @sizeOf(ordered_vertex_buffer_descriptions_const[buffer_idx].element_type),
            };
            vertex_buffer_names_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss] = buffer_name;
            vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss] = bind;
        }
        Sort.insertion_sort_with_func_and_matching_buffers(
            SDL3.GPU_VertexBufferDescription,
            vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx]..vertex_buffers_to_bind_start_locs[pipe_idx + 1]],
            vert_def_slot_greater,
            .{vertex_buffer_names_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx]..vertex_buffers_to_bind_start_locs[pipe_idx + 1]]},
        );
        switch (VALIDATION.vertex_buffer_slot_gaps) {
            .IGNORE => {},
            .PANIC => for (0..slots_used_len) |s| {
                const ss: u32 = @intCast(s);
                ct_assert_with_reason(vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss].slot == ss, @src(), "for render pipleine `{s}`, vertex buffer slots are not in order: index {d} = slot {d}", .{ @tagName(pipe_name), ss, vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss].slot });
            },
            .WARN => for (0..slots_used_len) |s| {
                const ss: u32 = @intCast(s);
                Assert.warn_with_reason(vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss].slot == ss, @src(), "for render pipleine `{s}`, vertex buffer slots are not in order: index {d} = slot {d}", .{ @tagName(pipe_name), ss, vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[pipe_idx] + ss].slot });
            },
        }
        // COMPILE VERTEX ATTRIBUTE BINDINGS TO FINAL ARRAY
        inline for (pipe_def.vertex_field_maps, 0..) |field_map, f| {
            const ff: u32 = @intCast(f);
            const vert_buf_idx = @intFromEnum(field_map.vertex_buffer);
            const vert_buf_info: VertexBufferDescription = @field(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, @tagName(field_map.vertex_buffer));
            const vert_struct_in_field_info: ShaderStructFieldInfo = @field(vert_struct_in.fields_info, field_map.shader_struct_field_name);
            const vert_buf_out_field_info: VertexBufferFieldInfo = @field(vert_buf_info.fields_info, field_map.vertex_buffer_field_name);
            vertex_attributes_to_bind_per_render_pipeline[vertex_attribute_start_locs[pipe_idx] + ff] = SDL3.GPU_VertexAttribute{
                .buffer_slot = vertex_buffer_slots_for_this_pipeline[vert_buf_idx].MANUAL,
                .format = vert_buf_out_field_info.gpu_format,
                .location = vert_struct_in_field_info.location,
                .offset = vert_buf_out_field_info.offset,
            };
        }
    }
    const vertex_buffer_names_to_bind_per_render_pipeline_const = vertex_buffer_names_to_bind_per_render_pipeline;
    const vertex_buffers_to_bind_per_render_pipeline_const = vertex_buffers_to_bind_per_render_pipeline;
    const vertex_attributes_to_bind_per_render_pipeline_const = vertex_attributes_to_bind_per_render_pipeline;
    const vertex_buffers_to_bind_start_locs_const = vertex_buffers_to_bind_start_locs;
    const vertex_attribute_start_locs_const = vertex_attribute_start_locs;
    const longest_set_of_vertex_buffers_const = longest_set_of_vertex_buffers;
    return struct {
        const Controller = @This();

        gpu: *GPU_Device = @ptrCast(INVALID_ADDR),
        windows: [INTERNAL.NUM_WINDOWS]*Window = @splat(@as(*Window, @ptrFromInt(INVALID_ADDR))),
        windows_init: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        windows_claimed: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        render_pipelines: [INTERNAL.NUM_RENDER_PIPELINES]*GPU_GraphicsPipeline = @splat(@as(*GPU_GraphicsPipeline, @ptrFromInt(INVALID_ADDR))),
        render_pipelines_init: [INTERNAL.NUM_RENDER_PIPELINES]bool = @splat(false),
        current_render_pipeline: RenderPipelineName = undefined,
        textures: [INTERNAL.NUM_TEXTURES]*GPU_Texture = @splat(@as(*GPU_GraphicsPipeline, @ptrFromInt(INVALID_ADDR))),
        textures_init: [INTERNAL.NUM_TEXTURES]bool = @splat(false),
        textures_own_memory: [INTERNAL.NUM_TEXTURES]bool = @splat(false),
        textures_sizes: [INTERNAL.NUM_TEXTURES]Vec3(u32) = @splat(Vec3(u32).ZERO),
        upload_transfer_buffers: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(@as(*GPU_TransferBuffer, @ptrFromInt(INVALID_ADDR))),
        upload_transfer_buffers_init: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        upload_transfer_buffers_own_memory: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        upload_transfer_buffer_lens: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        download_transfer_buffers: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(@as(*GPU_TransferBuffer, @ptrFromInt(INVALID_ADDR))),
        download_transfer_buffers_init: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        download_transfer_buffers_own_memory: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
        download_transfer_buffer_lens: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
        vertex_buffers: [INTERNAL.NUM_VERTEX_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrFromInt(INVALID_ADDR))),
        vertex_buffers_init: [INTERNAL.NUM_VERTEX_BUFFERS]bool = @splat(false),
        vertex_buffers_own_memory: [INTERNAL.NUM_VERTEX_BUFFERS]bool = @splat(false),
        vertex_buffer_lens: [INTERNAL.NUM_VERTEX_BUFFERS]u32 = @splat(0),
        storage_buffers: [INTERNAL.NUM_STORAGE_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrFromInt(INVALID_ADDR))),
        storage_buffers_init: [INTERNAL.NUM_STORAGE_BUFFERS]bool = @splat(false),
        storage_buffers_own_memory: [INTERNAL.NUM_STORAGE_BUFFERS]bool = @splat(false),
        storage_buffers_usage: [INTERNAL.NUM_STORAGE_BUFFERS]GPU_BufferUsageFlags = @splat(GPU_BufferUsageFlags.from_flag(.VERTEX)),
        storage_buffer_lens: [INTERNAL.NUM_STORAGE_BUFFERS]u32 = @splat(0),
        samplers: [INTERNAL.NUM_SAMPLERS]*GPU_TextureSampler = @splat(@as(*GPU_TextureSampler, @ptrFromInt(INVALID_ADDR))),
        samplers_init: [INTERNAL.NUM_SAMPLERS]bool = @splat(false),
        samplers_own_memory: [INTERNAL.NUM_SAMPLERS]bool = @splat(false),
        fences: [INTERNAL.NUM_FENCES]*GPU_Fence = @splat(@as(*GPU_Fence, @ptrFromInt(INVALID_ADDR))),
        fences_init: [INTERNAL.NUM_FENCES]bool = @splat(false),
        index_buffers: [INTERNAL.NUM_INDEX_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrFromInt(INVALID_ADDR))),
        index_buffers_init: [INTERNAL.NUM_INDEX_BUFFERS]bool = @splat(false),
        index_buffers_own_memory: [INTERNAL.NUM_INDEX_BUFFERS]bool = @splat(false),
        index_buffer_lens: [INTERNAL.NUM_INDEX_BUFFERS]u32 = @splat(0),
        index_buffer_types: [INTERNAL.NUM_INDEX_BUFFERS]GPU_IndexTypeSize = @splat(GPU_IndexTypeSize.U32),
        indirect_draw_buffers: [INTERNAL.NUM_INDIRECT_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrFromInt(INVALID_ADDR))),
        indirect_draw_buffers_init: [INTERNAL.NUM_INDIRECT_BUFFERS]bool = @splat(false),
        indirect_draw_buffers_own_memory: [INTERNAL.NUM_INDIRECT_BUFFERS]bool = @splat(false),
        indirect_draw_buffer_lens: [INTERNAL.NUM_INDIRECT_BUFFERS]u32 = @splat(0),
        indirect_draw_buffer_modes: [INTERNAL.NUM_INDIRECT_BUFFERS]VertexDrawMode = @splat(VertexDrawMode.VERTEX),
        uniforms: UniformCollection = undefined,
        command_buffer_active: bool = false,
        download_pass_active: bool = false,
        upload_pass_active: bool = false,
        copy_pass_active: bool = false,
        render_pass_active: bool = false,
        render_pass_with_pipeline_active: bool = false,
        compute_pass_active: bool = false,
        list_alloc: Allocator = DummyAlloc.allocator_panic,
        upload_list: List(CopyUploadDetails) = .{},
        download_list: List(CopyDownloadDetails) = .{},
        grow_copy_delete_list: List(GrowCopyDeleteDetails) = .{},
        delete_buffers_list: List(DeleteBufferDetails) = .{},

        const _ASSERT = Assert.AssertHandler(VALIDATION.master_assert_mode);
        const assert_with_reason = _ASSERT._with_reason;
        const assert_unreachable = _ASSERT._unreachable;
        const assert_unreachable_err = _ASSERT._unreachable_err;
        const assert_allocation_failure = _ASSERT._allocation_failure;

        const ERROR_MODE = VALIDATION.master_error_mode;
        const ERRORS = ERROR_MODE.does_error();
        pub fn PossibleError(comptime T: type) type {
            return switch (ERROR_MODE) {
                .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => anyerror!T,
                .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => T,
            };
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
        pub inline fn get_upload_transfer_buffer(self: *const Controller, name: UploadTransferBufferName) *GPU_TransferBuffer {
            assert_with_reason(self.upload_transfer_buffers_init[@intFromEnum(name)], @src(), "upload transfer buffer `{s}` not initialized", .{@tagName(name)});
            return self.upload_transfer_buffers[@intFromEnum(name)];
        }
        pub inline fn get_download_transfer_buffer(self: *const Controller, name: DownloadTransferBufferName) *GPU_TransferBuffer {
            assert_with_reason(self.download_transfer_buffers_init[@intFromEnum(name)], @src(), "download transfer buffer `{s}` not initialized", .{@tagName(name)});
            return self.download_transfer_buffers[@intFromEnum(name)];
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
            assert_with_reason(self.indirect_draw_buffers_init[@intFromEnum(name)], @src(), "indirect draw buffer `{s}` not initialized", .{@tagName(name)});
            return self.indirect_draw_buffers[@intFromEnum(name)];
        }
        pub inline fn get_uniform_ptr(self: *Controller, name: UniformName) *@FieldType(UniformCollection, @tagName(name)) {
            return &@field(self.uniforms, @tagName(name));
        }
        pub inline fn get_uniform_ptr_const(self: *const Controller, name: UniformName) *const @FieldType(UniformCollection, @tagName(name)) {
            return &@field(self.uniforms, @tagName(name));
        }

        pub fn copy_named_texture_pointer_to(self: *Controller, from: TextureName, to: TextureName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.textures_own_memory[to_idx] == false, @src(), "cannot copy a texture pointer (`{s}`) to a texture name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.textures[to_idx] = self.textures[from_idx];
            self.textures_init[to_idx] = self.textures_init[from_idx];
        }
        pub fn copy_named_upload_transfer_buffer_pointer_to(self: *Controller, from: UploadTransferBufferName, to: UploadTransferBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.upload_transfer_buffers_own_memory[to_idx] == false, @src(), "cannot copy an upload transfer buffer pointer (`{s}`) to an upload transfer buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.upload_transfer_buffers[to_idx] = self.upload_transfer_buffers[from_idx];
            self.upload_transfer_buffers_init[to_idx] = self.upload_transfer_buffers_init[from_idx];
        }
        pub fn copy_named_download_transfer_buffer_pointer_to(self: *Controller, from: DownloadTransferBufferName, to: DownloadTransferBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.download_transfer_buffers_init[to_idx] == false, @src(), "cannot copy a download transfer buffer pointer (`{s}`) to a download transfer buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.download_transfer_buffers[to_idx] = self.download_transfer_buffers[from_idx];
            self.download_transfer_buffers_init[to_idx] = self.download_transfer_buffers_init[from_idx];
        }
        pub fn copy_named_storage_buffer_pointer_to(self: *Controller, from: StorageBufferName, to: StorageBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            // TODO assert matching types
            assert_with_reason(self.storage_buffers_own_memory[to_idx] == false, @src(), "cannot copy a storage buffer pointer (`{s}`) to a storage buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.storage_buffers[to_idx] = self.storage_buffers[from_idx];
            self.storage_buffers_init[to_idx] = self.storage_buffers_init[from_idx];
        }
        pub fn copy_named_vertex_buffer_pointer_to(self: *Controller, from: VertexBufferName, to: VertexBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(INTERNAL.VERTEX_BUFFER_DEFS[to_idx].element_type == INTERNAL.VERTEX_BUFFER_DEFS[from_idx].element_type, @src(), "cannot copy a vertex buffer pointer (`{s}`) to a vertex buffer name (`{s}`) that has a different element type, got `{s}` != `{s}`", .{ @tagName(from), @tagName(to), @typeName(INTERNAL.VERTEX_BUFFER_DEFS[from_idx].element_type), @typeName(INTERNAL.VERTEX_BUFFER_DEFS[to_idx].element_type) });
            assert_with_reason(self.vertex_buffers_own_memory[to_idx] == false, @src(), "cannot copy a vertex buffer pointer (`{s}`) to a vertex buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.vertex_buffers[to_idx] = self.vertex_buffers[from_idx];
            self.vertex_buffers_init[to_idx] = self.vertex_buffers_init[from_idx];
        }
        pub fn copy_named_sampler_pointer_to(self: *Controller, from: SamplerName, to: SamplerName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.samplers_own_memory[to_idx] == false, @src(), "cannot copy a sampler pointer (`{s}`) to a sampler name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.samplers[to_idx] = self.samplers[from_idx];
            self.samplers_init[to_idx] = self.samplers_init[from_idx];
        }
        pub fn copy_named_index_buffer_pointer_to(self: *Controller, from: IndexBufferName, to: IndexBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.index_buffers_own_memory[to_idx] == false, @src(), "cannot copy an index buffer (`{s}`) to an index buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.index_buffers[to_idx] = self.index_buffers[from_idx];
            self.index_buffers_init[to_idx] = self.index_buffers_init[from_idx];
            self.index_buffer_types[to_idx] = self.index_buffer_types[from_idx];
        }
        pub fn copy_named_indirect_draw_buffer_pointer_to(self: *Controller, from: IndirectDrawBufferName, to: IndirectDrawBufferName) void {
            const from_idx = @intFromEnum(from);
            const to_idx = @intFromEnum(to);
            assert_with_reason(self.indirect_draw_buffers_own_memory[to_idx] == false, @src(), "cannot copy an indirect draw buffer (`{s}`) to an indirect draw buffer name that owns its memory (`{s}`): will cause memory leak", .{ @tagName(from), @tagName(to) });
            self.indirect_draw_buffers[to_idx] = self.indirect_draw_buffers[from_idx];
            self.indirect_draw_buffers_init[to_idx] = self.indirect_draw_buffers_init[from_idx];
            self.indirect_draw_buffer_modes[to_idx] = self.indirect_draw_buffer_modes[from_idx];
        }

        fn point_is_within_texture(self: *Controller, tex: TextureName, point: Vec3(u32)) bool {
            const tex_idx = @intFromEnum(tex);
            const size = self.textures_sizes[tex_idx];
            return point.x < size.x and point.y < size.y and point.z < size.z;
        }

        pub const Target = union(TargetKind) {
            WINDOW: WindowName,
            TEXTURE: TextureName,

            pub fn window(win: WindowName) Target {
                return Target{ .WINDOW = win };
            }
            pub fn texture(tex: TextureName) Target {
                return Target{ .TEXTURE = tex };
            }

            pub fn get_texture(self: Target, cmd: CommandBuffer) *GPU_Texture {
                return switch (self) {
                    .TEXTURE => |t| cmd.controller.get_texture(t),
                    .WINDOW => |w| cmd.wait_and_get_swapchain_texture_for_window(w),
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

            pub fn to_sdl(self: ColorTarget, command_buf: CommandBuffer) SDL3.GPU_ColorTargetInfo {
                return SDL3.GPU_ColorTargetInfo{
                    .texture = self.target.get_texture(command_buf),
                    .mip_level = self.mip_level,
                    .clear_color = @bitCast(self.clear_color),
                    .load_op = self.load_op,
                    .store_op = self.store_op,
                    .resolve_texture = if (self.resolve_target) |res_target| res_target.get_texture(command_buf) else null,
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

            pub fn to_sdl(self: DepthTarget, command_buf: CommandBuffer) SDL3.GPU_DepthStencilTargetInfo {
                return SDL3.GPU_DepthStencilTargetInfo{
                    .texture = if (self.texture) |t| command_buf.controller.get_texture(t) else null,
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

        pub const VertexBufferBinding = struct {
            buffer: VertexBufferName,
            data_offset: u32,

            pub fn vertex_buffer_binding(buffer: VertexBufferName, offset: u32) VertexBufferBinding {
                return VertexBufferBinding{
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

            pub fn to_sdl(self: BlitRegion, command_buffer: CommandBuffer) GPU_BlitRegion {
                return GPU_BlitRegion{
                    .texture = self.target.get_texture(command_buffer),
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

            pub fn to_sdl(self: BlitInfo, command_buffer: CommandBuffer) GPU_BlitInfo {
                return GPU_BlitInfo{
                    .source = self.source.to_sdl(command_buffer),
                    .destination = self.destination.to_sdl(command_buffer),
                    .clear_color = self.clear_color,
                    .load_op = self.load_op,
                    .filter = self.filter,
                    .flip_mode = self.flip_mode,
                    .cycle = self.cycle,
                };
            }
        };

        pub const TextureUploadInfo = struct {
            transfer_buffer: UploadTransferBufferName,
            offset: u32 = 0,
            pixels_per_row: u32 = 0,
            rows_per_layer: u32 = 0,

            pub fn texture_upload_info(buffer: UploadTransferBufferName, offset: u32, pixels_per_row: u32, rows_per_layer: u32) TextureUploadInfo {
                return TextureUploadInfo{
                    .transfer_buffer = buffer,
                    .offset = offset,
                    .pixels_per_row = pixels_per_row,
                    .rows_per_layer = rows_per_layer,
                };
            }

            pub fn to_sdl(self: TextureUploadInfo, command_buffer: CommandBuffer) GPU_TextureTransferInfo {
                return GPU_TextureTransferInfo{
                    .transfer_buffer = command_buffer.controller.get_upload_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                    .pixels_per_row = self.pixels_per_row,
                    .rows_per_layer = self.rows_per_layer,
                };
            }
        };

        pub const TextureDownloadInfo = struct {
            transfer_buffer: DownloadTransferBufferName,
            offset: u32 = 0,
            pixels_per_row: u32 = 0,
            rows_per_layer: u32 = 0,

            pub fn texture_download_info(buffer: DownloadTransferBufferName, offset: u32, pixels_per_row: u32, rows_per_layer: u32) TextureDownloadInfo {
                return TextureDownloadInfo{
                    .transfer_buffer = buffer,
                    .offset = offset,
                    .pixels_per_row = pixels_per_row,
                    .rows_per_layer = rows_per_layer,
                };
            }

            pub fn to_sdl(self: TextureDownloadInfo, command_buffer: CommandBuffer) GPU_TextureTransferInfo {
                return GPU_TextureTransferInfo{
                    .transfer_buffer = command_buffer.controller.get_upload_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                    .pixels_per_row = self.pixels_per_row,
                    .rows_per_layer = self.rows_per_layer,
                };
            }
        };

        pub const UploadTransferBufferLocation = struct {
            transfer_buffer: UploadTransferBufferName,
            offset: u32 = 0,

            pub fn upload_buffer_loc(name: UploadTransferBufferName, offset: u32) UploadTransferBufferLocation {
                return UploadTransferBufferLocation{
                    .transfer_buffer = name,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: UploadTransferBufferLocation, cmd: CommandBuffer) GPU_TransferBufferLocation {
                return GPU_TransferBufferLocation{
                    .transfer_buffer = cmd.controller.get_upload_transfer_buffer(self.transfer_buffer),
                    .offset = self.offset,
                };
            }
        };

        pub const CopyUploadDetails = struct {
            dest: GPUAssetRegion,
            transfer_buf: UploadTransferBufferName,
            transfer_buf_offset: u32,
            transfer_buf_len: u32,
        };

        pub const CopyDownloadDetails = struct {
            dest: []u8,
            transfer_buf: DownloadTransferBufferName,
            transfer_buf_offset: u32,
            transfer_buf_len: u32,
        };

        pub const DownloadTransferBufferLocation = struct {
            transfer_buffer: DownloadTransferBufferName,
            offset: u32 = 0,

            pub fn download_buffer_loc(name: DownloadTransferBufferName, offset: u32) DownloadTransferBufferLocation {
                return DownloadTransferBufferLocation{
                    .transfer_buffer = name,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: DownloadTransferBufferLocation, cmd: CommandBuffer) GPU_TransferBufferLocation {
                return GPU_TransferBufferLocation{
                    .transfer_buffer = cmd.controller.get_upload_transfer_buffer(self.transfer_buffer),
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
            pub fn storage_buffer_match_slice(name: StorageBufferName, offset: u32, match_slice: anytype) GPUAssetRegion {
                const size: u32 = @intCast(bytes_cast(match_slice).len);
                // TODO assert type matches `match_slice`
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
            pub fn vertex_buffer_match_slice(name: VertexBufferName, offset: u32, match_slice: anytype) GPUAssetRegion {
                const size: u32 = @intCast(bytes_cast(match_slice).len);
                // TODO assert type matches `match_slice`
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
            pub fn index_buffer_match_slice(name: IndexBufferName, offset: u32, match_slice: anytype) GPUAssetRegion {
                const size: u32 = @intCast(bytes_cast(match_slice).len);
                // TODO assert type matches `match_slice`
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
            pub fn indirect_draw_buffer_match_slice(name: IndirectDrawBufferName, offset: u32, match_slice: anytype) GPUAssetRegion {
                const size: u32 = @intCast(bytes_cast(match_slice).len);
                // TODO assert type matches `match_slice`
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

            pub fn to_sdl(self: BufferRegion, cmd: CommandBuffer) GPU_BufferRegion {
                return GPU_BufferRegion{
                    .buffer = self.buffer.get_buffer(cmd.controller),
                    .offset = self.offset,
                    .size = self.size,
                };
            }
        };

        pub const BufferLocation = struct {
            buffer: AnyGPUBuffer,
            offset: u32 = u32,

            pub fn buffer_location(buffer: AnyGPUBuffer, offset: u32) BufferLocation {
                return BufferLocation{
                    .buffer = buffer,
                    .offset = offset,
                };
            }

            pub fn to_sdl(self: BufferLocation, controller: *Controller) GPU_BufferLocation {
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

            pub fn texture_region(target: Target, mip_layer: u32, layer: u32, pos: Vec3(u32), size: Vec3(u32)) TextureRegion {
                return TextureRegion{
                    .target = target,
                    .mip_layer = mip_layer,
                    .layer = layer,
                    .pos = pos,
                    .size = size,
                };
            }

            pub fn to_sdl(self: TextureRegion, command: CommandBuffer) GPU_TextureRegion {
                return GPU_TextureRegion{
                    .texture = self.target.get_texture(command),
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

            pub fn to_sdl(self: TextureLocation, cmd: CommandBuffer) GPU_TextureLocation {
                return GPU_TextureLocation{
                    .texture = self.target.get_texture(cmd),
                    .layer = self.layer,
                    .mip_level = self.mip_level,
                    .x = self.pos.x,
                    .y = self.pos.y,
                    .z = self.pos.z,
                };
            }
        };

        pub fn begin_upload_pass(self: *Controller, cycle_transfer_buffers: bool, grow_mode: BufferGrowMode) UploadPass {
            assert_with_reason(!self.upload_pass_active and !self.command_buffer_active, @src(), "cannot begin an UploadPass when another UploadPass or CommandBuffer is active", .{});
            self.upload_pass_active = true;
            return UploadPass{
                .controller = self,
                .should_cycle_first = cycle_transfer_buffers,
                .grow_mode = grow_mode,
            };
        }

        pub const UploadPass = struct {
            controller: *Controller,
            mapped: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]bool = @splat(false),
            slices: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS][]u8 = @splat(@as([*]u8, @ptrFromInt(INVALID_ADDR))[0..0]),
            bytes_written: [INTERNAL.NUM_UPLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
            should_cycle_first: bool = true,

            /// Sets or overrides the number of 'written' bytes in the transfer buffer (for *this* transfer pass), from the beginning
            pub fn set_written_bytes(self: *UploadPass, buffer: UploadTransferBufferName, written_bytes: u32) void {
                const idx = @intFromEnum(buffer);
                self.bytes_written[idx] = written_bytes;
            }
            /// Adds to the number of 'written' bytes in the transfer buffer (for *this* transfer pass), from the beginning
            pub fn add_written_bytes(self: *UploadPass, buffer: UploadTransferBufferName, written_bytes: u32) void {
                const idx = @intFromEnum(buffer);
                self.bytes_written[idx] += written_bytes;
            }
            pub fn get_written_bytes(self: *const UploadPass, buffer: UploadTransferBufferName) u32 {
                const idx = @intFromEnum(buffer);
                return self.bytes_written[idx];
            }

            pub fn get_upload_slice(self: *UploadPass, buffer: UploadTransferBufferName, start: u32, end_excluded: u32) PossibleError([]u8) {
                const idx = @intFromEnum(buffer);
                const buf = self.controller.get_upload_transfer_buffer(buffer);
                if (self.mapped[idx] == false) {
                    const ptr = self.controller.gpu.map_transfer_buffer(buf, self.should_cycle_first) catch |err| return ERROR_MODE.handle(@src(), err);
                    self.slices[idx] = ptr[0..self.controller.upload_transfer_buffer_lens[idx]];
                    self.mapped[idx] == true;
                }
                return self.slices[idx][start..end_excluded];
            }
            /// returns the slice and the byte offset it started from (for use in a CopyPass)
            pub fn get_upload_slice_after_last_written_slice(self: *UploadPass, buffer: UploadTransferBufferName, num_bytes: u32) PossibleError(.{ []u8, u32 }) {
                const idx = @intFromEnum(buffer);
                const start = self.bytes_written[idx];
                self.bytes_written[idx] = start + num_bytes;
                const slice = if (ERRORS) ( //
                    try self.get_upload_slice(buffer, start, start + num_bytes)) //
                    else self.get_upload_slice(buffer, start, start + num_bytes) catch |err| ERROR_MODE.panic(@src(), err);
                return .{ slice, start };
            }
            pub fn get_typed_upload_slice(self: *UploadPass, buffer: UploadTransferBufferName, comptime T: type, start_offset: u32, num_elements: u32) PossibleError([]T) {
                const num_bytes = @sizeOf(T) * num_elements;
                const slice_raw = self.get_upload_slice(buffer, start_offset, start_offset + num_bytes) catch |err| return ERROR_MODE.handle(@src(), err);
                return std.mem.bytesAsSlice(T, slice_raw);
            }
            /// returns the slice and the byte offset it started from (for use in a CopyPass)
            pub fn get_typed_upload_slice_after_last_written_slice(self: *UploadPass, buffer: UploadTransferBufferName, comptime T: type, num_elements: u32) PossibleError(.{ []T, u32 }) {
                const idx = @intFromEnum(buffer);
                const start = self.bytes_written[idx];
                const start_aligned = std.mem.alignForward(u32, start, @alignOf(T));
                const num_bytes = (@sizeOf(T) * num_elements) + (start_aligned - start);
                self.bytes_written[idx] = start + num_bytes;
                const slice = self.get_typed_upload_slice(buffer, T, start_aligned, num_elements) catch |err| return ERROR_MODE.handle(@src(), err);
                return .{ slice, start_aligned };
            }

            pub fn end_upload_pass(self: *UploadPass) void {
                for (self.mapped[0..], 0..) |is_mapped, i| {
                    if (is_mapped) {
                        const buffer: UploadTransferBufferName = num_cast(i, UploadTransferBufferName);
                        const buf = self.controller.get_upload_transfer_buffer(buffer);
                        self.controller.gpu.unmap_transfer_buffer(buf);
                    }
                }
                self.controller.upload_pass_active = false;
                self.* = undefined;
            }
        };

        pub fn begin_download_pass(self: *Controller, cycle_transfer_buffers: bool) DownloadPass {
            assert_with_reason(!self.download_pass_active and !self.command_buffer_active, @src(), "cannot begin a DownloadPass when another DownloadPass or CommandBuffer is active", .{});
            self.download_pass_active = true;
            return DownloadPass{
                .controller = self,
                .should_cycle_first = cycle_transfer_buffers,
            };
        }

        pub const DownloadPass = struct {
            cmd: CommandBuffer,
            mapped: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]bool = @splat(false),
            slices: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS][]u8 = @splat(@as([*]u8, @ptrFromInt(INVALID_ADDR))[0..0]),
            bytes_read: [INTERNAL.NUM_DOWNLOAD_TRANSFER_BUFFERS]u32 = @splat(0),
            should_cycle_first: bool = true,

            /// Sets or overrides the number of 'read' bytes in the transfer buffer (for *this* transfer pass), from the beginning
            pub fn set_read_bytes(self: *DownloadPass, buffer: DownloadTransferBufferName, read_bytes: u32) void {
                const idx = @intFromEnum(buffer);
                self.bytes_read[idx] = read_bytes;
            }
            /// Adds to the number of 'read' bytes in the transfer buffer (for *this* transfer pass), from the beginning
            pub fn add_read_bytes(self: *DownloadPass, buffer: DownloadTransferBufferName, written_bytes: u32) void {
                const idx = @intFromEnum(buffer);
                self.bytes_read[idx] += written_bytes;
            }
            pub fn get_read_bytes(self: *const DownloadPass, buffer: DownloadTransferBufferName) u32 {
                const idx = @intFromEnum(buffer);
                return self.bytes_read[idx];
            }

            pub fn get_download_slice(self: *DownloadPass, buffer: DownloadTransferBufferName, start: u32, end_excluded: u32) []u8 {
                const idx = @intFromEnum(buffer);
                const buf = self.cmd.controller.get_download_transfer_buffer(buffer);
                if (self.mapped[idx] == false) {
                    const ptr = self.cmd.controller.gpu.map_transfer_buffer(buf, self.should_cycle_first) catch |err| ct_assert_unreachable_err(@src(), err);
                    self.slices[idx] = ptr[0..self.cmd.controller.upload_transfer_buffer_lens[idx]];
                    self.mapped[idx] == true;
                }
                return self.slices[idx][start..end_excluded];
            }
            /// returns the slice and the byte offset it started from
            pub fn get_download_slice_after_last_read_slice(self: *DownloadPass, buffer: DownloadTransferBufferName, num_bytes: u32) .{ []u8, u32 } {
                const idx = @intFromEnum(buffer);
                const start = self.bytes_read[idx];
                self.bytes_read[idx] = start + num_bytes;
                return .{ self.get_download_slice(buffer, start, start + num_bytes), start };
            }
            pub fn get_typed_download_slice(self: *DownloadPass, buffer: DownloadTransferBufferName, comptime T: type, start_offset: u32, num_elements: u32) []T {
                const num_bytes = @sizeOf(T) * num_elements;
                const slice_raw = self.get_download_slice(buffer, start_offset, start_offset + num_bytes);
                return std.mem.bytesAsSlice(T, slice_raw);
            }
            /// returns the slice and the byte offset it started from
            pub fn get_typed_download_slice_after_last_read_slice(self: *DownloadPass, buffer: DownloadTransferBufferName, comptime T: type, num_elements: u32) .{ []T, u32 } {
                const idx = @intFromEnum(buffer);
                const start = self.bytes_read[idx];
                const start_aligned = std.mem.alignForward(u32, start, @alignOf(T));
                const num_bytes = (@sizeOf(T) * num_elements) + (start_aligned - start);
                self.bytes_read[idx] = start + num_bytes;
                return .{ self.get_typed_download_slice(buffer, T, start_aligned, num_elements), start_aligned };
            }

            pub fn end_download_pass(self: *DownloadPass) void {
                for (self.mapped[0..], 0..) |is_mapped, i| {
                    if (is_mapped) {
                        const buffer: DownloadTransferBufferName = num_cast(i, DownloadTransferBufferName);
                        const buf = self.cmd.controller.get_download_transfer_buffer(buffer);
                        self.cmd.controller.gpu.unmap_transfer_buffer(buf);
                    }
                }
                self.cmd.controller.download_pass_active = false;
                self.* = undefined;
            }
        };

        pub const GrowCopyDeleteDetails = struct {
            idx: u32,
            kind: GPUBufferKind,
            copy_len: u32,
            new_len: u32,
        };

        pub fn begin_pre_command_upload_pass(self: *Controller, cycle_transfer_buffers: bool, grow_settings: UploadGrowSettings) PreCommandUploadPass {
            assert_with_reason(!self.command_buffer_active and !self.upload_pass_active, @src(), "cannot begin a PreCommandUploadPass when a CommandPass or UploadPass is active", .{});
            self.upload_list.clear();
            self.grow_copy_delete_list.clear();
            return PreCommandUploadPass{
                .controller = self,
                .upload = self.begin_upload_pass(cycle_transfer_buffers),
                .grow_settings = grow_settings,
            };
        }

        /// Wraps an `UploadPass` that prepares uploads for immediate copy via a new `CommandBuffer` and `CopyPass` after this pass is submitted
        ///
        /// Provides additional assertions about data transfer types and sizes, and can automatically grow both transfer and gpu buffers if needed
        ///
        /// This is the recommended way to upload data to the GPU and then begin a `CommandBuffer`
        pub const PreCommandUploadPass = struct {
            controller: *Controller,
            upload: UploadPass,
            grow_settings: UploadGrowSettings = .{},

            pub fn handle_possible_transfer_buffer_grow(self: *PreCommandUploadPass, buf: UploadTransferBufferName, offset: u32, len: u32, curr_size: u32, need_size: u32) PossibleError(void) {
                var transfer_grow: u32 = 0;
                switch (self.grow_settings.grow_transfer_buffers) {
                    .NO_GROW => {
                        assert_with_reason(need_size <= curr_size, @src(), "copying {d} bytes to upload transfer buffer `{s}` at offset {d} exceeds the total length of the transfer buffer ({d}). Either manually grow the transfer buffer, or use an automatic grow setting", .{ len, @tagName(buf), offset, curr_size });
                    },
                    .GROW_EXACT => if (need_size > curr_size) {
                        transfer_grow = need_size;
                    },
                    .GROW_BY_ONE_AND_A_QUARTER => if (need_size > curr_size) {
                        transfer_grow = need_size + (need_size >> 2);
                    },
                    .GROW_BY_ONE_AND_A_HALF => if (need_size > curr_size) {
                        transfer_grow = need_size + (need_size >> 1);
                    },
                    .GROW_BY_DOUBLE => if (need_size > curr_size) {
                        transfer_grow = need_size << 1;
                    },
                }
                if (transfer_grow > 0) {
                    if (ERRORS) ( //
                        try self.grow_transfer_buffer(buf, curr_size, transfer_grow)) //
                    else self.grow_transfer_buffer(buf, curr_size, transfer_grow) catch |err| ERROR_MODE.panic(@src(), err);
                }
            }

            pub fn grow_transfer_buffer(self: *PreCommandUploadPass, buf: UploadTransferBufferName, curr_size: u32, new_size: u32) PossibleError(void) {
                const buf_idx = @intFromEnum(buf);
                assert_with_reason(self.controller.upload_transfer_buffers_own_memory[buf_idx], @src(), "cannot grow a transfer buffer name (`{s}`) that does not own its own memory", .{@tagName(buf)});
                const new_transfer = self.controller.gpu.create_transfer_buffer(GPU_TransferBufferCreateInfo{
                    .usage = .UPLOAD,
                    .size = new_size,
                    .props = .{},
                }) catch |err| return ERROR_MODE.handle(@src(), err);
                const new_ptr = self.controller.gpu.map_transfer_buffer(new_transfer, false) catch |err| return ERROR_MODE.handle(@src(), err);
                const old_slice = if (ERRORS) ( //
                    try self.upload.get_upload_slice(buf, 0, curr_size)) //
                    else self.upload.get_upload_slice(buf, 0, curr_size) catch |err| ERROR_MODE.panic(@src(), err);
                @memcpy(new_ptr[0..old_slice.len], old_slice);
                self.controller.gpu.unmap_transfer_buffer(self.controller.upload_transfer_buffers[buf_idx]);
                self.controller.gpu.release_transfer_buffer(self.controller.upload_transfer_buffers[buf_idx]);
                self.controller.upload_transfer_buffers[buf_idx] = new_transfer;
                self.controller.upload_transfer_buffer_lens[buf_idx] = new_size;
                self.upload.slices[buf_idx] = new_ptr[0..new_size];
            }

            pub fn handle_possible_gpu_buffer_grow(self: *PreCommandUploadPass, comptime kind: GPUBufferKind, buf_name: []const u8, buf_idx: u32, offset: u32, len: u32, curr_size: u32, need_size: u32) PossibleError(void) {
                var gpu_grow: u32 = 0;
                switch (switch (kind) {
                    .STORAGE => self.grow_settings.grow_storage_buffers,
                    .VERTEX => self.grow_settings.grow_vertex_buffers,
                    .INDEX => self.grow_settings.grow_index_buffers,
                    .INDIRECT => self.grow_settings.grow_indirect_draw_call_buffers,
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
                    if (ERRORS) ( //
                        try self.grow_gpu_buffer(kind, buf_name, buf_idx, curr_size, gpu_grow)) //
                    else self.grow_gpu_buffer(kind, buf_name, buf_idx, curr_size, gpu_grow) catch |err| ERROR_MODE.panic(@src(), err);
                }
            }

            pub fn grow_gpu_buffer(self: *PreCommandUploadPass, comptime kind: GPUBufferKind, buf_name: []const u8, buf_idx: u32, curr_size: u32, new_size: u32) PossibleError(void) {
                assert_with_reason(switch (kind) {
                    .STORAGE => self.controller.storage_buffers_own_memory[buf_idx],
                    .VERTEX => self.controller.vertex_buffers_own_memory[buf_idx],
                    .INDEX => self.controller.index_buffers_own_memory[buf_idx],
                    .INDIRECT => self.controller.indirect_draw_buffers_own_memory[buf_idx],
                }, @src(), "cannot grow a gpu buffer name (`{s}`) that does not own its own memory", .{buf_name});
                for (self.controller.grow_copy_delete_list.slice()) |*prev_grow| {
                    if (prev_grow.idx == buf_idx and prev_grow.kind == kind) {
                        prev_grow.new_len = @max(prev_grow.new_len, new_size);
                        return;
                    }
                }
                const details = GrowCopyDeleteDetails{
                    .kind = kind,
                    .idx = buf_idx,
                    .copy_len = curr_size,
                    .new_len = new_size,
                };
                _ = self.controller.grow_copy_delete_list.append(details, self.controller.list_alloc);
            }

            pub fn upload_to_vertex_buffer(self: *PreCommandUploadPass, source: anytype, dest: VertexBufferName, dest_index_of_first_vertex: u32, transfer_buf: UploadTransferBufferName) PossibleError(void) {
                const source_bytes: []const u8 = bytes_cast(source);
                const source_element_type = bytes_cast_element_type(@TypeOf(source));
                const dest_idx = @intFromEnum(dest);
                const transfer_idx = @intFromEnum(transfer_buf);
                const dest_type = INTERNAL.VERTEX_BUFFER_DEFS[dest_idx].element_type;
                assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest vertex buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_vertex;
                const transfer_offset = self.upload.get_written_bytes(transfer_buf);
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                if (ERRORS) ( //
                    try self.handle_possible_gpu_buffer_grow(.VERTEX, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.vertex_buffer_lens[dest_idx], buffer_end)) //
                else self.handle_possible_gpu_buffer_grow(.VERTEX, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.vertex_buffer_lens[dest_idx], buffer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.upload.add_written_bytes(transfer_buf, transfer_len);
                const details = CopyUploadDetails{
                    .dest = .vertex_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.upload_list.append(details, self.controller.list_alloc);
                const transfer_slice = self.upload.get_upload_slice(transfer_buf, transfer_offset, transfer_offset + transfer_len);
                @memcpy(transfer_slice, source_bytes);
            }
            pub fn upload_to_index_buffer(self: *PreCommandUploadPass, source: anytype, dest: IndexBufferName, dest_index_of_first_index: u32, transfer_buf: UploadTransferBufferName) PossibleError(void) {
                const source_bytes: []const u8 = bytes_cast(source);
                const source_element_type = bytes_cast_element_type(@TypeOf(source));
                const dest_idx = @intFromEnum(dest);
                const transfer_idx = @intFromEnum(transfer_buf);
                const dest_type = switch (self.cmd.controller.index_buffer_types[dest_idx]) {
                    GPU_IndexTypeSize.U16 => u16,
                    GPU_IndexTypeSize.U32 => u32,
                };
                assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest index buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_index;
                const transfer_offset = self.upload.get_written_bytes(transfer_buf);
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                if (ERRORS) ( //
                    try self.handle_possible_gpu_buffer_grow(.INDEX, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.index_buffer_lens[dest_idx], buffer_end)) //
                else self.handle_possible_gpu_buffer_grow(.INDEX, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.index_buffer_lens[dest_idx], buffer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.upload.add_written_bytes(transfer_buf, transfer_len);
                const details = CopyUploadDetails{
                    .dest = .index_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.upload_list.append(details, self.controller.list_alloc);
                const transfer_slice = self.upload.get_upload_slice(transfer_buf, transfer_offset, transfer_offset + transfer_len);
                @memcpy(transfer_slice, source_bytes);
            }
            pub fn upload_to_indirect_draw_call_buffer(self: *PreCommandUploadPass, source: anytype, dest: IndirectDrawBufferName, dest_index_of_first_draw_call: u32, transfer_buf: UploadTransferBufferName) PossibleError(void) {
                const source_bytes: []const u8 = bytes_cast(source);
                const source_element_type = bytes_cast_element_type(@TypeOf(source));
                const dest_idx = @intFromEnum(dest);
                const transfer_idx = @intFromEnum(transfer_buf);
                const dest_type = switch (self.cmd.controller.indirect_draw_buffer_modes[dest_idx]) {
                    VertexDrawMode.INDEX => GPU_IndexedIndirectDrawCommand,
                    VertexDrawMode.VERTEX => GPU_IndirectDrawCommand,
                };
                assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest indirect draw call buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_draw_call;
                const transfer_offset = self.upload.get_written_bytes(transfer_buf);
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                if (ERRORS) ( //
                    try self.handle_possible_gpu_buffer_grow(.INDIRECT, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.indirect_draw_buffer_lens[dest_idx], buffer_end)) //
                else self.handle_possible_gpu_buffer_grow(.INDIRECT, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.indirect_draw_buffer_lens[dest_idx], buffer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.upload.add_written_bytes(transfer_buf, transfer_len);
                const details = CopyUploadDetails{
                    .dest = .indirect_draw_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.upload_list.append(details, self.controller.list_alloc);
                const transfer_slice = self.upload.get_upload_slice(transfer_buf, transfer_offset, transfer_offset + transfer_len);
                @memcpy(transfer_slice, source_bytes);
            }
            pub fn upload_to_storage_buffer(self: *PreCommandUploadPass, source: anytype, dest: StorageBufferName, dest_index_of_first_element: u32, transfer_buf: UploadTransferBufferName) PossibleError(void) {
                const source_bytes: []const u8 = bytes_cast(source);
                const source_element_type = bytes_cast_element_type(@TypeOf(source));
                const dest_idx = @intFromEnum(dest);
                const transfer_idx = @intFromEnum(transfer_buf);
                const dest_type = INTERNAL.STORAGE_BUFFER_TYPES[dest_idx];
                assert_with_reason(source_element_type == dest_type, @src(), "source element type must be the same as the dest storage buffer element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_type) });
                const dest_offset = @sizeOf(dest_type) * dest_index_of_first_element;
                const transfer_offset = self.upload.get_written_bytes(transfer_buf);
                const transfer_len: u32 = @intCast(source_bytes.len);
                const buffer_end = dest_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                if (ERRORS) ( //
                    try self.handle_possible_gpu_buffer_grow(.STORAGE, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.storage_buffer_lens[dest_idx], buffer_end)) //
                else self.handle_possible_gpu_buffer_grow(.STORAGE, @tagName(dest), dest_idx, dest_offset, transfer_len, self.controller.storage_buffer_lens[dest_idx], buffer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.upload.add_written_bytes(transfer_buf, transfer_len);
                const details = CopyUploadDetails{
                    .dest = .storage_buffer(dest, dest_offset, transfer_len),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.upload_list.append(details, self.controller.list_alloc);
                const transfer_slice = self.upload.get_upload_slice(transfer_buf, transfer_offset, transfer_offset + transfer_len);
                @memcpy(transfer_slice, source_bytes);
            }
            pub fn upload_to_texture(self: *PreCommandUploadPass, source: anytype, dest: TextureName, dest_pos: Vec3(u32), dest_size: Vec3(u32), dest_mip_level: u32, dest_layer: u32, transfer_buf: UploadTransferBufferName) PossibleError(void) {
                const source_bytes: []const u8 = bytes_cast(source);
                const transfer_len: u32 = @intCast(source_bytes.len);
                const transfer_idx = @intFromEnum(transfer_buf);
                const source_element_type = bytes_cast_element_type(@TypeOf(source));
                const dest_idx = @intFromEnum(dest);
                const dest_texel_size = INTERNAL.TEXTURE_DEFS[dest_idx].pixel_format.texel_block_size();
                const dest_copy_size = dest_size.x * dest_size.y * dest_size.z * dest_texel_size;
                assert_with_reason(@sizeOf(source_element_type) == dest_texel_size, @src(), "source element type must be the same SIZE as the dest texture texel block size, but `{d}` != `{d}`", .{ @sizeOf(source_element_type), dest_texel_size });
                assert_with_reason(transfer_len <= dest_copy_size, @src(), "source byte len {d} is larger than texture destination size {d} ({d} * {any}) (cannot automatically resize textures)", .{ transfer_len, dest_copy_size, dest_texel_size, dest_size });
                const transfer_offset = self.upload.get_written_bytes(transfer_buf);
                const transfer_end = transfer_offset + transfer_len;
                const texture_extent = dest_pos.add(dest_size);
                assert_with_reason(self.controller.point_is_within_texture(dest, texture_extent), @src(), "uplod max extent {any} is outside the max size of texture `{s}` ({any})", .{ texture_extent, @tagName(dest), self.controller.textures_sizes[dest_idx] });
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.upload_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.upload.add_written_bytes(transfer_buf, transfer_len);
                const details = CopyUploadDetails{
                    .dest = .texture(dest, dest_pos, dest_size, dest_mip_level, dest_layer),
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.upload_list.append(details, self.controller.list_alloc);
                const transfer_slice = self.upload.get_upload_slice(transfer_buf, transfer_offset, transfer_offset + transfer_len);
                @memcpy(transfer_slice, source_bytes);
            }

            pub fn end_upload_pass_and_start_command_buffer(self: *PreCommandUploadPass, cycle_gpu_buffers: bool) PossibleError(CommandBuffer) {
                const cmd: CommandBuffer, const copy: CopyPass = if (ERRORS) ( //
                    try self.end_upload_pass_and_start_command_buffer_with_active_copy_pass(cycle_gpu_buffers)) //
                    else self.end_upload_pass_and_start_command_buffer_with_active_copy_pass(cycle_gpu_buffers) catch |err| ERROR_MODE.panic(@src(), err);
                copy.end_copy_pass();
                return cmd;
            }
            pub fn end_upload_pass_and_start_command_buffer_with_active_copy_pass(self: *PreCommandUploadPass, cycle_gpu_buffers: bool) PossibleError(.{ CommandBuffer, CopyPass }) {
                self.upload.end_upload_pass();
                var cmd: CommandBuffer = if (ERRORS) ( //
                    try self.controller.begin_command_buffer()) //
                    else self.controller.begin_command_buffer() catch |err| ERROR_MODE.panic(@src(), err);
                const copy: CopyPass = if (ERRORS) ( //
                    try cmd.begin_copy_pass()) //
                    else cmd.begin_copy_pass() catch |err| ERROR_MODE.panic(@src(), err);
                for (self.controller.grow_copy_delete_list.slice()) |grow| {
                    const old_buf = switch (grow.kind) {
                        .STORAGE => self.controller.storage_buffers[grow.idx],
                        .VERTEX => self.controller.vertex_buffers[grow.idx],
                        .INDEX => self.controller.index_buffers[grow.idx],
                        .INDIRECT => self.controller.indirect_draw_buffers[grow.idx],
                    };
                    const new_buf = self.controller.gpu.create_buffer(GPU_BufferCreateInfo{
                        .size = grow.new_len,
                        .props = .{},
                        .usage = switch (grow.kind) {
                            .STORAGE => self.controller.storage_buffers_usage[grow.idx],
                            .VERTEX => GPU_BufferUsageFlags.from_flag(.VERTEX),
                            .INDEX => GPU_BufferUsageFlags.from_flag(.INDEX),
                            .INDIRECT => GPU_BufferUsageFlags.from_flag(.INDIRECT),
                        },
                    }) catch |err| return ERROR_MODE.handle(@src(), err);
                    copy.pass.copy_from_gpu_buffer_to_gpu_buffer(.{ .buffer = old_buf, .offset = 0 }, .{ .buffer = new_buf, .offset = 0 }, grow.copy_len, cycle_gpu_buffers);
                    _ = self.controller.delete_buffers_list.append(DeleteBufferDetails{ .buf = old_buf }, self.controller.list_alloc);
                    switch (grow.kind) {
                        .STORAGE => {
                            self.controller.storage_buffers[grow.idx] = new_buf;
                            self.controller.storage_buffer_lens[grow.idx] = grow.new_len;
                        },
                        .VERTEX => {
                            self.controller.vertex_buffers[grow.idx] = new_buf;
                            self.controller.vertex_buffer_lens[grow.idx] = grow.new_len;
                        },
                        .INDEX => {
                            self.controller.index_buffers[grow.idx] = new_buf;
                            self.controller.index_buffer_lens[grow.idx] = grow.new_len;
                        },
                        .INDIRECT => {
                            self.controller.indirect_draw_buffers[grow.idx] = new_buf;
                            self.controller.indirect_draw_buffer_lens[grow.idx] = grow.new_len;
                        },
                    }
                }
                for (self.controller.upload_list.slice()) |upload| {
                    switch (upload.dest) {
                        .STORAGE_BUF => |details| {
                            copy.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.storage_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .VERTEX_BUF => |details| {
                            copy.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.vertex_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .INDEX_BUF => |details| {
                            copy.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.index_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .INDIRECT_BUF => |details| {
                            copy.copy_from_upload_buffer_to_gpu_buffer(.upload_buffer_loc(upload.transfer_buf, upload.transfer_buf_offset), .buffer_region(.indirect_draw_buffer(details.name), details.offset, details.size), cycle_gpu_buffers);
                        },
                        .TEXTURE => |details| {
                            copy.copy_from_upload_buffer_to_gpu_texture(.texture_upload_info(upload.transfer_buf, upload.transfer_buf_offset, details.size.x, details.size.y), .texture_region(details.target, details.mip_level, details.layer, details.pos, details.size), cycle_gpu_buffers);
                        },
                    }
                }
                return .{ cmd, copy };
            }
        };

        pub fn begin_command_buffer(self: *Controller) PossibleError(CommandBuffer) {
            assert_with_reason(!self.upload_pass_active and !self.download_pass_active and !self.command_buffer_active, @src(), "cannot begin a CommandBuffer while another CommandBuffer, UploadPass, or DownloadPass is active", .{});
            const cmd = CommandBuffer{
                .command = self.gpu.acquire_command_buffer() catch |err| return ERROR_MODE.handle(@src(), err),
                .controller = self,
            };
            self.delete_buffers_list.clear();
            self.command_buffer_active = true;
            return cmd;
        }

        pub const DeleteBufferDetails = struct {
            buf: *GPU_Buffer,
        };

        pub const CommandBuffer = struct {
            controller: *Controller,
            command: *SDL3.GPU_CommandBuffer,
            delete_buffers_list: List(DeleteBufferDetails),
            delete_buffers_alloc: Allocator = DummyAlloc.allocator_panic,
            owns_delete_list: bool = false,

            pub fn insert_debug_label(self: CommandBuffer, label: [*:0]const u8) void {
                self.command.insert_debug_label(label);
            }

            pub fn push_debug_group(self: CommandBuffer, name: [*:0]const u8) void {
                self.command.push_debug_group(name);
            }

            pub fn pop_debug_group(self: CommandBuffer) void {
                self.command.pop_debug_group();
            }

            //TODO
            // pub fn push_compute_uniform_data(self: *GPU_CommandBuffer, slot_index: u32, data_ptr: anytype) void {
            //     const data_raw = Utils.raw_slice_cast_const(data_ptr);
            //     C.SDL_PushGPUComputeUniformData(self.to_c_ptr(), slot_index, data_raw.ptr, @intCast(data_raw.len));
            // }

            pub fn get_swapchain_texture_for_window(self: CommandBuffer, window_name: WindowName) PossibleError(*GPU_Texture) {
                const win = self.controller.get_claimed_window(window_name);
                const swap = self.command.aquire_swapchain_texture(win) catch |err| return ERROR_MODE.handle(@src(), err);
                return swap.texture;
            }
            pub fn wait_and_get_swapchain_texture_for_window(self: CommandBuffer, window_name: WindowName) PossibleError(*GPU_Texture) {
                const win = self.controller.get_claimed_window(window_name);
                const swap = self.command.wait_and_aquire_swapchain_texture(win) catch |err| return ERROR_MODE.handle(@src(), err);
                return swap.texture;
            }

            pub fn begin_copy_pass(self: CommandBuffer) PossibleError(CopyPass) {
                assert_with_reason(self.controller.command_buffer_active and !self.controller.render_pass_active and !self.controller.copy_pass_active and !self.controller.upload_pass_active and !self.controller.download_pass_active, @src(), "cannot begin a copy pass when another pass is already in progress", .{});
                const pass = self.command.begin_copy_pass() catch |err| return ERROR_MODE.handle(@src(), err);
                self.controller.copy_pass_active = true;
                return CopyPass{
                    .cmd = self,
                    .pass = pass,
                };
            }

            pub fn begin_copy_pass_gpu_only(self: CommandBuffer) PossibleError(CopyPassGPUOnly) {
                assert_with_reason(self.controller.render_pass_active == false and self.controller.copy_pass_active == false and self.controller.upload_pass_active == false and self.controller.download_pass_active == false, @src(), "cannot begin a copy pass when another pass is already in progress", .{});
                const pass = self.command.begin_copy_pass() catch |err| return ERROR_MODE.handle(@src(), err);
                self.controller.copy_pass_active = true;
                return CopyPassGPUOnly{
                    .cmd = self,
                    .pass = pass,
                };
            }

            pub fn begin_render_pass(self: CommandBuffer, color_targets: []const ColorTarget, depth_target: DepthTarget) PossibleError(RenderPass) {
                assert_with_reason(self.controller.render_pass_active == false and self.controller.copy_pass_active == false and self.controller.upload_pass_active == false, @src(), "cannot begin a render pass when another pass is already in progress", .{});
                assert_with_reason(color_targets.len <= 8, @src(), "GraphicsController only supports up to 8 color targets, got {d}", .{color_targets.len});
                for (color_targets, 0..) |target, t| {
                    self.controller.current_render_pass_color_targets[t] = target.to_sdl(self);
                }
                self.controller.current_render_pass_color_targets_len = @intCast(color_targets.len);
                self.controller.current_render_pass_depth_target = depth_target.to_sdl(self);
                self.controller.render_pass_active = true;
                const pass = self.command.begin_render_pass(self.controller.current_render_pass_color_targets[0..color_targets.len], &self.controller.current_render_pass_depth_target) catch |err| return ERROR_MODE.handle(@src(), err);
                return RenderPass{
                    .controller = self.controller,
                    .command = self.command,
                    .pass = pass,
                };
            }

            pub fn generate_mipmaps_for_texture(self: CommandBuffer, texture_name: TextureName) void {
                self.command.generate_mipmaps_for_texture(self.controller.get_texture(texture_name));
            }

            pub fn blit_texture(self: CommandBuffer, blit_info: BlitInfo) void {
                var blit_sdl = blit_info.to_sdl(self);
                self.command.blit_texture(&blit_sdl);
            }
            pub fn submit_commands(self: *CommandBuffer) PossibleError(void) {
                assert_with_reason(self.controller.command_buffer_active and !self.controller.render_pass_active and !self.controller.copy_pass_active and !self.controller.compute_pass_active, @src(), "cannot submit a command buffer when either no command buffer is active, or a render, copy, or compute pass is still active", .{});
                self.command.submit_commands() catch |err| return ERROR_MODE.handle(@src(), err);
                for (self.delete_buffers_list.slice()) |to_delete| {
                    self.controller.gpu.release_buffer(to_delete);
                }
                if (self.owns_delete_list) {
                    self.delete_buffers_list.free(self.delete_buffers_alloc);
                }
                self.controller.command_buffer_active = false;
                self.* = undefined;
            }
            pub fn submit_commands_and_aquire_fence(self: *CommandBuffer, fence_name: FenceName) PossibleError(void) {
                assert_with_reason(self.controller.command_buffer_active and !self.controller.render_pass_active and !self.controller.copy_pass_active and !self.controller.compute_pass_active, @src(), "cannot submit a command buffer when either no command buffer is active, or a render, copy, or compute pass is still active", .{});
                const fence_idx = @intFromEnum(fence_name);
                assert_with_reason(self.controller.fences_init[fence_idx] == false, @src(), "fence `{s}` is already initialized and waiting to be released", .{@tagName(fence_name)});
                self.controller.fences[fence_idx] = self.command.submit_commands_and_aquire_fence() catch |err| return ERROR_MODE.handle(@src(), err);
                self.controller.fences_init[fence_idx] = true;
                for (self.delete_buffers_list.slice()) |to_delete| {
                    self.controller.gpu.release_buffer(to_delete);
                }
                if (self.owns_delete_list) {
                    self.delete_buffers_list.free(self.delete_buffers_alloc);
                }
                self.controller.command_buffer_active = false;
                self.* = undefined;
            }
            pub fn submit_commands_and_aquire_fenced_post_command_download_pass(self: *CommandBuffer, cycle_transfer_buffers: bool, transfer_buffer_grow_mode: BufferGrowMode) PossibleError(FencedPostCommandDownloadPass) {
                assert_with_reason(self.controller.command_buffer_active and !self.controller.render_pass_active and !self.controller.copy_pass_active and !self.controller.compute_pass_active, @src(), "cannot submit a command buffer when either no command buffer is active, or a render, copy, or compute pass is still active", .{});
                const fenced_pass = FencedPostCommandDownloadPass{
                    .controller = self.controller,
                    .cycle_transfer_buffers = cycle_transfer_buffers,
                    .transfer_grow_mode = transfer_buffer_grow_mode,
                    .fence = self.command.submit_commands_and_aquire_fence() catch |err| return ERROR_MODE.handle(@src(), err),
                };
                for (self.delete_buffers_list.slice()) |to_delete| {
                    self.controller.gpu.release_buffer(to_delete);
                }
                if (self.owns_delete_list) {
                    self.delete_buffers_list.free(self.delete_buffers_alloc);
                }
                self.controller.command_buffer_active = false;
                self.* = undefined;
                return fenced_pass;
            }
            pub fn submit_commands_and_immediately_wait_to_begin_post_command_download_pass(self: *CommandBuffer, cycle_transfer_buffers: bool, transfer_buffer_grow_mode: BufferGrowMode) PossibleError(PostCommandDownloadPass) {
                assert_with_reason(self.controller.command_buffer_active and !self.controller.render_pass_active and !self.controller.copy_pass_active and !self.controller.compute_pass_active, @src(), "cannot submit a command buffer when either no command buffer is active, or a render, copy, or compute pass is still active", .{});
                var fenced_pass = FencedPostCommandDownloadPass{
                    .controller = self.controller,
                    .cycle_transfer_buffers = cycle_transfer_buffers,
                    .transfer_grow_mode = transfer_buffer_grow_mode,
                    .fence = self.command.submit_commands_and_aquire_fence() catch |err| return ERROR_MODE.handle(@src(), err),
                };
                for (self.delete_buffers_list.slice()) |to_delete| {
                    self.controller.gpu.release_buffer(to_delete);
                }
                if (self.owns_delete_list) {
                    self.delete_buffers_list.free(self.delete_buffers_alloc);
                }
                self.controller.command_buffer_active = false;
                self.* = undefined;
                const down_pass: PostCommandDownloadPass = if (ERRORS) ( //
                    try fenced_pass.wait_for_fence_and_begin_post_command_download_pass()) //
                    else fenced_pass.wait_for_fence_and_begin_post_command_download_pass() catch |err| ERROR_MODE.panic(@src(), err);
                return down_pass;
            }
            pub fn cancel_commands(self: *CommandBuffer) PossibleError(void) {
                self.command.cancel_commands() catch |err| return ERROR_MODE.handle(@src(), err);
                self.* = undefined;
            }
        };

        pub const FencedPostCommandDownloadPass = struct {
            controller: *Controller,
            fence: *GPU_Fence,
            cycle_transfer_buffers: bool = true,
            transfer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,

            pub fn wait_for_fence_and_begin_post_command_download_pass(self: *FencedPostCommandDownloadPass) PossibleError(PostCommandDownloadPass) {
                const fence = [1]*GPU_Fence{self.fence};
                self.controller.gpu.wait_for_gpu_fences(true, fence[0..1]) catch |err| return ERROR_MODE.handle(@src(), err);
                self.controller.gpu.release_fence(self.fence);
                const post_pass = PostCommandDownloadPass{
                    .controller = self.controller,
                    .download = self.controller.begin_download_pass(self.cycle_transfer_buffers),
                };
                self.* = undefined;
                return post_pass;
            }
        };

        pub const PostCommandDownloadPass = struct {
            controller: *Controller,
            command_buffer: CommandBuffer,
            copy_pass: CopyPass,
            download: DownloadPass,
            cycle_transfer_buffers: bool = true,
            transfer_grow_mode: BufferGrowMode = .GROW_BY_ONE_AND_A_QUARTER,

            pub fn handle_possible_transfer_buffer_grow(self: *PostCommandDownloadPass, buf: DownloadTransferBufferName, offset: u32, len: u32, curr_size: u32, need_size: u32) PossibleError(void) {
                var transfer_grow: u32 = 0;
                switch (self.transfer_grow_mode) {
                    .NO_GROW => {
                        assert_with_reason(need_size <= curr_size, @src(), "copying {d} bytes to download transfer buffer `{s}` at offset {d} exceeds the total length of the transfer buffer ({d}). Either manually grow the transfer buffer, or use an automatic grow setting", .{ len, @tagName(buf), offset, curr_size });
                    },
                    .GROW_EXACT => if (need_size > curr_size) {
                        transfer_grow = need_size;
                    },
                    .GROW_BY_ONE_AND_A_QUARTER => if (need_size > curr_size) {
                        transfer_grow = need_size + (need_size >> 2);
                    },
                    .GROW_BY_ONE_AND_A_HALF => if (need_size > curr_size) {
                        transfer_grow = need_size + (need_size >> 1);
                    },
                    .GROW_BY_DOUBLE => if (need_size > curr_size) {
                        transfer_grow = need_size << 1;
                    },
                }
                if (transfer_grow > 0) {
                    if (ERRORS) ( //
                        try self.grow_transfer_buffer(buf, curr_size, transfer_grow)) //
                    else self.grow_transfer_buffer(buf, curr_size, transfer_grow) catch |err| ERROR_MODE.panic(@src(), err);
                }
            }

            pub fn grow_transfer_buffer(self: *PostCommandDownloadPass, buf: DownloadTransferBufferName, curr_size: u32, new_size: u32) PossibleError(void) {
                const buf_idx = @intFromEnum(buf);
                assert_with_reason(self.controller.upload_transfer_buffers_own_memory[buf_idx], @src(), "cannot grow a download transfer buffer name (`{s}`) that does not own its own memory", .{@tagName(buf)});
                const new_transfer = self.controller.gpu.create_transfer_buffer(GPU_TransferBufferCreateInfo{
                    .usage = .DOWNLOAD,
                    .size = new_size,
                    .props = .{},
                }) catch |err| return ERROR_MODE.handle(@src(), err);
                const new_ptr = self.controller.gpu.map_transfer_buffer(new_transfer, false) catch |err| return ERROR_MODE.handle(@src(), err);
                const old_slice = if (ERRORS) ( //
                    try self.download.get_download_slice(buf, 0, curr_size)) //
                    else self.download.get_download_slice(buf, 0, curr_size) catch |err| ERROR_MODE.panic(@src(), err);
                @memcpy(new_ptr[0..old_slice.len], old_slice);
                self.controller.gpu.unmap_transfer_buffer(self.controller.download_transfer_buffers[buf_idx]);
                self.controller.gpu.release_transfer_buffer(self.controller.download_transfer_buffers[buf_idx]);
                self.controller.download_transfer_buffers[buf_idx] = new_transfer;
                self.controller.download_transfer_buffer_lens[buf_idx] = new_size;
                self.download.slices[buf_idx] = new_ptr[0..new_size];
            }

            pub fn download_from_vertex_buffer(self: *PostCommandDownloadPass, source: VertexBufferName, source_index_of_first_element: u32, source_element_count: u32, dest: anytype, transfer_buf: DownloadTransferBufferName) PossibleError(void) {
                const dest_bytes: []u8 = bytes_cast(dest);
                const dest_element_type = bytes_cast_element_type(@TypeOf(dest));
                const source_idx = @intFromEnum(source);
                const transfer_idx = @intFromEnum(transfer_buf);
                const source_element_type = INTERNAL.VERTEX_BUFFER_DEFS[source_idx].element_type;
                assert_with_reason(source_element_type == dest_element_type, @src(), "source vertex buffer element type must be the same as the dest element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_element_type) });
                const source_offset = @sizeOf(source_element_type) * source_index_of_first_element;
                const transfer_offset = self.download.get_read_bytes(transfer_buf);
                const transfer_len: u32 = @sizeOf(source_element_type) * source_element_count;
                const buffer_end = source_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                assert_with_reason(self.controller.vertex_buffer_lens[source_idx] >= buffer_end, @src(), "source vertex buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_element_count, @typeName(source_element_type), source_offset, buffer_end, self.controller.vertex_buffer_lens[source_idx] });
                assert_with_reason(num_cast(dest_bytes.len, u32) >= transfer_len, @src(), "destination slice cannot hold {d} items of type {s} ({d} bytes), len is {d} bytes", .{ source_element_count, @typeName(source_element_type), transfer_len, dest_bytes.len });
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.download.add_read_bytes(transfer_buf, transfer_len);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.download_list.append(details, self.controller.list_alloc);
                self.copy_pass.copy_from_gpu_buffer_to_download_buffer(.buffer_region(.vertex_buffer(source), source_offset, transfer_len), .download_buffer_loc(transfer_buf, transfer_offset));
            }
            pub fn download_from_index_buffer(self: *PostCommandDownloadPass, source: IndexBufferName, source_index_of_first_index: u32, source_index_count: u32, dest: anytype, transfer_buf: DownloadTransferBufferName) PossibleError(void) {
                const dest_bytes: []u8 = bytes_cast(dest);
                const dest_element_type = bytes_cast_element_type(@TypeOf(dest));
                const source_idx = @intFromEnum(source);
                const transfer_idx = @intFromEnum(transfer_buf);
                const source_element_type = switch (self.controller.index_buffer_types[source_idx]) {
                    .U16 => u16,
                    .U32 => u32,
                };
                assert_with_reason(source_element_type == dest_element_type, @src(), "source index buffer element type must be the same as the dest element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_element_type) });
                const source_offset = @sizeOf(source_element_type) * source_index_of_first_index;
                const transfer_offset = self.download.get_read_bytes(transfer_buf);
                const transfer_len: u32 = @sizeOf(source_element_type) * source_index_count;
                const buffer_end = source_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                assert_with_reason(self.controller.index_buffer_lens[source_idx] >= buffer_end, @src(), "source index buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_index_count, @typeName(source_element_type), source_offset, buffer_end, self.controller.index_buffer_lens[source_idx] });
                assert_with_reason(num_cast(dest_bytes.len, u32) >= transfer_len, @src(), "destination slice cannot hold {d} items of type {s} ({d} bytes), len is {d} bytes", .{ source_index_count, @typeName(source_element_type), transfer_len, dest_bytes.len });
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.download.add_read_bytes(transfer_buf, transfer_len);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.download_list.append(details, self.controller.list_alloc);
                self.copy_pass.copy_from_gpu_buffer_to_download_buffer(.buffer_region(.index_buffer(source), source_offset, transfer_len), .download_buffer_loc(transfer_buf, transfer_offset));
            }
            pub fn download_from_indirect_draw_call_buffer(self: *PostCommandDownloadPass, source: IndirectDrawBufferName, source_index_of_first_draw_call: u32, source_draw_call_count: u32, dest: anytype, transfer_buf: DownloadTransferBufferName) PossibleError(void) {
                const dest_bytes: []u8 = bytes_cast(dest);
                const dest_element_type = bytes_cast_element_type(@TypeOf(dest));
                const source_idx = @intFromEnum(source);
                const transfer_idx = @intFromEnum(transfer_buf);
                const source_element_type = switch (self.controller.indirect_draw_buffer_modes[source_idx]) {
                    .INDEX => GPU_IndexedIndirectDrawCommand,
                    .VERTEX => GPU_IndirectDrawCommand,
                };
                assert_with_reason(source_element_type == dest_element_type, @src(), "source index buffer element type must be the same as the dest element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_element_type) });
                const source_offset = @sizeOf(source_element_type) * source_index_of_first_draw_call;
                const transfer_offset = self.download.get_read_bytes(transfer_buf);
                const transfer_len: u32 = @sizeOf(source_element_type) * source_draw_call_count;
                const buffer_end = source_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                assert_with_reason(self.controller.indirect_draw_buffer_lens[source_idx] >= buffer_end, @src(), "source index buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_draw_call_count, @typeName(source_element_type), source_offset, buffer_end, self.controller.indirect_draw_buffer_lens[source_idx] });
                assert_with_reason(num_cast(dest_bytes.len, u32) >= transfer_len, @src(), "destination slice cannot hold {d} items of type {s} ({d} bytes), len is {d} bytes", .{ source_draw_call_count, @typeName(source_element_type), transfer_len, dest_bytes.len });
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.download.add_read_bytes(transfer_buf, transfer_len);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.download_list.append(details, self.controller.list_alloc);
                self.copy_pass.copy_from_gpu_buffer_to_download_buffer(.buffer_region(.indirect_draw_buffer(source), source_offset, transfer_len), .download_buffer_loc(transfer_buf, transfer_offset));
            }
            pub fn download_from_storage_buffer(self: *PostCommandDownloadPass, source: StorageBufferName, source_index_of_first_element: u32, source_element_count: u32, dest: anytype, transfer_buf: DownloadTransferBufferName) PossibleError(void) {
                const dest_bytes: []u8 = bytes_cast(dest);
                const dest_element_type = bytes_cast_element_type(@TypeOf(dest));
                const source_idx = @intFromEnum(source);
                const transfer_idx = @intFromEnum(transfer_buf);
                const source_element_type = INTERNAL.STORAGE_BUFFER_TYPES[source_idx];
                assert_with_reason(source_element_type == dest_element_type, @src(), "source storage buffer element type must be the same as the dest element type, but `{s}` != `{s}`", .{ @typeName(source_element_type), @typeName(dest_element_type) });
                const source_offset = @sizeOf(source_element_type) * source_index_of_first_element;
                const transfer_offset = self.download.get_read_bytes(transfer_buf);
                const transfer_len: u32 = @sizeOf(source_element_type) * source_element_count;
                const buffer_end = source_offset + transfer_len;
                const transfer_end = transfer_offset + transfer_len;
                assert_with_reason(self.controller.storage_buffer_lens[source_idx] >= buffer_end, @src(), "source stroage buffer `{s}` does not hold {d} items of type {s} at offset {d} (endpoint byte {d}), length is {d} bytes", .{ @tagName(source), source_element_count, @typeName(source_element_type), source_offset, buffer_end, self.controller.storage_buffer_lens[source_idx] });
                assert_with_reason(num_cast(dest_bytes.len, u32) >= transfer_len, @src(), "destination slice cannot hold {d} items of type {s} ({d} bytes), len is {d} bytes", .{ source_element_count, @typeName(source_element_type), transfer_len, dest_bytes.len });
                if (ERRORS) ( //
                    try self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end)) //
                else self.handle_possible_transfer_buffer_grow(transfer_buf, transfer_offset, transfer_len, self.controller.download_transfer_buffer_lens[transfer_idx], transfer_end) catch |err| ERROR_MODE.panic(@src(), err);
                self.download.add_read_bytes(transfer_buf, transfer_len);
                const details = CopyDownloadDetails{
                    .dest = dest_bytes,
                    .transfer_buf = transfer_buf,
                    .transfer_buf_offset = transfer_offset,
                    .transfer_buf_len = transfer_len,
                };
                _ = self.controller.download_list.append(details, self.controller.list_alloc);
                self.copy_pass.copy_from_gpu_buffer_to_download_buffer(.buffer_region(.storage_buffer(source), source_offset, transfer_len), .download_buffer_loc(transfer_buf, transfer_offset));
            }
            pub fn download_from_texture(self: *PostCommandDownloadPass, source: TextureName, source_index_of_first_element: u32, source_element_count: u32, dest: anytype, transfer_buf: DownloadTransferBufferName) PossibleError(void) {
                //CHECKPOINT
            }
        };

        pub const CopyPass = struct {
            cmd: CommandBuffer,
            pass: *SDL3.GPU_CopyPass,

            pub fn copy_from_upload_buffer_to_gpu_texture(self: CopyPass, source: TextureUploadInfo, dest: TextureRegion, cycle: bool) void {
                self.pass.upload_from_transfer_buffer_to_gpu_texture(source.to_sdl(self.cmd), dest.to_sdl(self.cmd), cycle);
            }
            pub fn copy_from_upload_buffer_to_gpu_buffer(self: CopyPass, source: UploadTransferBufferLocation, dest: BufferRegion, cycle: bool) void {
                self.pass.upload_from_transfer_buffer_to_gpu_buffer(source.to_sdl(self.cmd), dest.to_sdl(self.cmd), cycle);
            }
            pub fn copy_from_gpu_texture_to_gpu_texture(self: CopyPass, source: TextureLocation, dest: TextureLocation, size: Vec3(u32), cycle: bool) void {
                self.pass.copy_from_gpu_texture_to_gpu_texture(source.to_sdl(self.cmd), dest.to_sdl(self.cmd), size, cycle);
            }
            pub fn copy_from_gpu_buffer_to_gpu_buffer(self: CopyPass, source: BufferLocation, dest: BufferLocation, copy_len: u32, cycle: bool) void {
                return self.pass.copy_from_gpu_buffer_to_gpu_buffer(source.to_sdl(self.cmd.controller), dest.to_sdl(self.cmd.controller), copy_len, cycle);
            }
            pub fn copy_from_gpu_texture_to_download_buffer(self: CopyPass, source: TextureRegion, dest: TextureDownloadInfo) void {
                self.pass.download_from_gpu_texture_to_transfer_buffer(source.to_sdl(self.cmd), dest.to_sdl(self.cmd));
            }
            pub fn copy_from_gpu_buffer_to_download_buffer(self: CopyPass, source: BufferRegion, dest: DownloadTransferBufferLocation) void {
                self.pass.download_from_gpu_buffer_to_transfer_buffer(source.to_sdl(self.cmd), dest.to_sdl(self.cmd));
            }
            pub fn end_copy_pass(self: CopyPass) void {
                self.cmd.controller.copy_pass_active = false;
                self.pass.end_copy_pass();
            }
        };

        pub const CopyPassGPUOnly = struct {
            cmd: CommandBuffer,
            pass: *SDL3.GPU_CopyPass,

            pub fn copy_from_gpu_texture_to_gpu_texture(self: CopyPass, source: TextureLocation, dest: TextureLocation, size: Vec3(u32), cycle: bool) void {
                self.pass.copy_from_gpu_texture_to_gpu_texture(source.to_sdl(self.cmd), dest.to_sdl(self.cmd), size, cycle);
            }
            pub fn copy_from_gpu_buffer_to_gpu_buffer(self: CopyPass, source: BufferLocation, dest: BufferLocation, copy_len: u32, cycle: bool) void {
                return self.pass.copy_from_gpu_buffer_to_gpu_buffer(source.to_sdl(self.cmd.controller), dest.to_sdl(self.cmd.controller), copy_len, cycle);
            }
            pub fn end_copy_pass(self: CopyPass) void {
                self.cmd.controller.copy_pass_active = false;
                self.pass.end_copy_pass();
            }
        };

        pub const RenderPass = struct {
            controller: *Controller,
            command: *SDL3.GPU_CommandBuffer,
            pass: *SDL3.GPU_RenderPass,

            pub fn begin_render_pipeline_pass(self: RenderPass, pipeline: RenderPipelineName) RenderPassWithPipeline {
                assert_with_reason(self.controller.render_pass_active, @src(), "no render pass is active, cannot start pipeline pass `{s}`", .{@tagName(pipeline)});
                assert_with_reason(!self.controller.render_pass_with_pipeline_active, @src(), "a pipeline pass (`{s}`) is already active, cannot start 2 pipleine passes simultaneously (`{s}`)", .{ @tagName(self.controller.current_render_pipeline), @tagName(pipeline) });
                self.pass.bind_graphics_pipeline(self.controller.get_render_pipeline(pipeline));
                self.controller.render_pass_with_pipeline_active = true;
                self.controller.current_render_pipeline = pipeline;
                return RenderPassWithPipeline{
                    .controller = self.controller,
                    .command = self.command,
                    .pass = self.pass,
                    .pipeline = pipeline,
                };
            }

            pub fn set_viewport(self: RenderPass, viewport: SDL3.GPU_Viewport) void {
                self.pass.set_viewport(viewport);
            }
            pub fn clear_viewport(self: RenderPass) void {
                self.pass.clear_viewport();
            }
            pub fn set_scissor(self: RenderPass, scissor_rect: SDL3.Rect_c_int) void {
                self.pass.set_scissor(scissor_rect);
            }
            pub fn clear_scissor(self: RenderPass) void {
                self.pass.clear_scissor();
            }
            pub fn set_blend_constants(self: RenderPass, blend_constants: SDL3.Color_RGBA_f32) void {
                self.pass.set_blend_constants(blend_constants);
            }
            pub fn set_stencil_reference_val(self: RenderPass, ref_val: u8) void {
                self.pass.set_stencil_reference_val(ref_val);
            }

            pub fn end_render_pass(self: *RenderPass) void {
                assert_with_reason(self.controller.render_pass_with_pipeline_active == false, @src(), "you must end the current `RenderPassWithPipeline` before you end the current `RenderPass`", .{});
                self.pass.end_render_pass();
                self.controller.render_pass_active = false;
                self.* = undefined;
            }
        };

        pub const RenderPassWithPipeline = struct {
            controller: *Controller,
            command: *SDL3.GPU_CommandBuffer,
            pass: *SDL3.GPU_RenderPass,
            pipeline: RenderPipelineName,
            index_buffer_bound: bool = false,

            /// Notably this does not bind index buffers, since there is no prescribed index buffer for any specific pipeline
            pub fn bind_all_resources_and_push_all_uniforms(self: RenderPassWithPipeline, default_vertex_buffer_offset: u32, specific_vertex_buffer_offsets: []const VertexBufferBinding) void {
                self.push_all_uniform_data();
                self.bind_all_vertex_buffers(default_vertex_buffer_offset, specific_vertex_buffer_offsets);
                self.bind_all_sampler_pairs();
                self.bind_all_storage_textures();
                self.bind_all_storage_buffers();
            }

            pub fn push_all_uniform_data(self: RenderPassWithPipeline) void {
                const info = INTERNAL.get_render_pipeline_info(self.pipeline);
                const allowed_vert = INTERNAL.allowed_uniforms_for_vert_shader(info.vertex);
                const allowed_frag = INTERNAL.allowed_uniforms_for_vert_shader(info.fragment);
                for (allowed_vert) |vert| {
                    const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(vert.uniform)));
                    const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(vert.uniform)));
                    self.command.push_vertex_uniform_data(vert.register, ptr, len);
                }
                for (allowed_frag) |frag| {
                    const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(frag.uniform)));
                    const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(frag.uniform)));
                    self.command.push_fragment_uniform_data(frag.register, ptr, len);
                }
            }

            pub fn push_single_vertex_uniform_data(self: RenderPassWithPipeline, unform_name: UniformName) void {
                const register = INTERNAL.uniform_register_for_pipeline_stage(self.pipeline, unform_name, .VERTEX) orelse ct_assert_unreachable(@src(), "uniform `{s}` is disallowed/unrelated to current render pipeline `{s}` vertex shader, cannot push data", .{ @tagName(unform_name), @tagName(self.pipeline) });
                const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(unform_name)));
                const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(unform_name)));
                self.command.push_vertex_uniform_data(register, ptr, len);
            }
            pub fn push_single_fragment_uniform_data(self: RenderPassWithPipeline, unform_name: UniformName) void {
                const register = INTERNAL.uniform_register_for_pipeline_stage(self.pipeline, unform_name, .FRAGMENT) orelse ct_assert_unreachable(@src(), "uniform `{s}` is disallowed/unrelated to current render pipeline `{s}` fragment shader, cannot push data", .{ @tagName(unform_name), @tagName(self.pipeline) });
                const ptr: *const anyopaque = @ptrCast(&@field(self.controller.uniforms, @tagName(unform_name)));
                const len: u32 = @sizeOf(@FieldType(UniformCollection, @tagName(unform_name)));
                self.command.push_fragment_uniform_data(register, ptr, len);
            }

            pub fn bind_all_vertex_buffers(self: RenderPassWithPipeline, default_offset: u32, specific_offsets: []const VertexBufferBinding) void {
                assert_with_reason(num_cast(specific_offsets.len, u32) <= INTERNAL.LONGEST_VERTEX_BUFFER_SET, @src(), "length of `specific_offsets` ({d}) is longer than the longest recorded set of allowed vertex buffers ({d})", .{ specific_offsets.len, INTERNAL.LONGEST_VERTEX_BUFFER_SET });
                const all_vert_buffer_names = INTERNAL.allowed_vertex_buffer_names_for_pipeline(self.pipeline);
                const all_vert_buffer_defs = INTERNAL.allowed_vertex_buffer_defs_for_pipeline(self.pipeline);
                const len: u32 = @intCast(all_vert_buffer_defs.len);
                self.controller.current_vertex_buffers_bound_len = len;
                var vertex_buffer_bindings: [INTERNAL.LONGEST_VERTEX_BUFFER_SET]SDL3.GPU_BufferBinding = undefined;
                for (all_vert_buffer_names, 0..) |name, i| {
                    vertex_buffer_bindings[i].buffer = self.controller.get_vertex_buffer(name);
                    vertex_buffer_bindings[i].offset = default_offset;
                }
                for (specific_offsets) |offset| {
                    const idx = INTERNAL.vertex_buffer_local_index_for_pipeline(self.pipeline, offset.buffer) orelse ct_assert_unreachable(@src(), "vertex buffer `{s}` is not allowed in render pipeline `{s}`", .{ @tagName(offset.buffer), @tagName(self.pipeline) });
                    vertex_buffer_bindings[idx].offset = offset.data_offset;
                }
                if (VALIDATION.vertex_buffer_slot_gaps == .PANIC) {
                    self.pass.bind_vertex_buffers_to_consecutive_slots(0, vertex_buffer_bindings[0..len]);
                } else {
                    var i: u32 = 0;
                    var ii: u32 = 1;
                    var first_slot: u32 = undefined;
                    var prev_slot: u32 = undefined;
                    while (i < len) {
                        first_slot = all_vert_buffer_defs[i].slot;
                        prev_slot = prev_slot;
                        while (ii < len) {
                            const next_slot = all_vert_buffer_defs[ii].slot;
                            if (next_slot == prev_slot + 1) {
                                prev_slot = next_slot;
                                ii += 1;
                            } else {
                                break;
                            }
                        }
                        self.pass.bind_vertex_buffers_to_consecutive_slots(first_slot, vertex_buffer_bindings[i..ii]);
                        i = ii;
                        ii += 1;
                    }
                }
            }

            pub fn bind_specific_vertex_buffers(self: RenderPassWithPipeline, bindings: []const VertexBufferBinding) void {
                const all_vert_defs = INTERNAL.allowed_vertex_buffer_defs_for_pipeline(self.pipeline);
                var sdl_bindings: [INTERNAL.LONGEST_VERTEX_BUFFER_SET]SDL3.GPU_BufferBinding = undefined;
                const len: u32 = @intCast(bindings.len);
                for (bindings, 0..) |bind, i| {
                    sdl_bindings[i] = SDL3.GPU_BufferBinding{
                        .buffer = self.controller.get_vertex_buffer(bind.buffer),
                        .offset = bind.data_offset,
                    };
                }
                var local_i: u32 = 0;
                var local_ii: u32 = 1;
                var first_slot: u32 = undefined;
                var prev_slot: u32 = undefined;
                while (local_i < len) {
                    const i = INTERNAL.vertex_buffer_local_index_for_pipeline(self.pipeline, bindings[local_i].buffer) orelse ct_assert_unreachable(@src(), "vertex buffer `{s}` is not allowed in render pipeline `{s}`", .{ @tagName(bindings[local_i].buffer), @tagName(self.pipeline) });
                    first_slot = all_vert_defs[i].slot;
                    prev_slot = first_slot;
                    while (local_ii < len) {
                        const ii = INTERNAL.vertex_buffer_local_index_for_pipeline(self.pipeline, bindings[local_ii].buffer) orelse ct_assert_unreachable(@src(), "vertex buffer `{s}` is not allowed in render pipeline `{s}`", .{ @tagName(bindings[local_ii].buffer), @tagName(self.pipeline) });
                        const next_slot = all_vert_defs[ii].slot;
                        if (next_slot == prev_slot + 1) {
                            prev_slot = next_slot;
                            local_ii += 1;
                        } else {
                            break;
                        }
                    }
                    self.pass.bind_vertex_buffers_to_consecutive_slots(first_slot, sdl_bindings[local_i..local_ii]);
                    local_i = local_ii;
                    local_ii += 1;
                }
            }

            pub fn bind_all_sampler_pairs(self: RenderPassWithPipeline) void {
                const info = INTERNAL.get_render_pipeline_info(self.pipeline);
                const allowed_vert = INTERNAL.allowed_sample_pairs_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_SAMPLE_PAIR_SET_VERT]SDL3.GPU_TextureSamplerBinding = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = SDL3.GPU_TextureSamplerBinding{
                            .sampler = self.controller.get_sampler(vert.sampler),
                            .texture = self.controller.get_texture(vert.texture),
                        };
                    }
                    const first_slot_vert = allowed_vert[0].register;
                    self.pass.bind_vertex_samplers_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
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
                    const first_slot_frag = allowed_frag[0].register;
                    self.pass.bind_fragment_samplers_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_one_sampler_pair(self: RenderPassWithPipeline, comptime stage: ShaderStage, sampler: SamplerName, texture: TextureName) void {
                const register = INTERNAL.sample_pair_register_for_render_pipeline_stage(self.pipeline, sampler, texture, stage) orelse ct_assert_unreachable(@src(), "sample pair `{s}` + `{s}` is not allowed for render pipeline `{s}` {s} stage", .{ @tagName(sampler), @tagName(texture), @tagName(self.pipeline), @tagName(stage) });
                const bind = [1]SDL3.GPU_TextureSamplerBinding{SDL3.GPU_TextureSamplerBinding{
                    .sampler = self.controller.get_sampler(sampler),
                    .texture = self.controller.get_texture(texture),
                }};
                switch (stage) {
                    .VERTEX => {
                        self.pass.bind_vertex_samplers_to_consecutive_slots(register, bind[0..1]);
                    },
                    .FRAGMENT => {
                        self.pass.bind_fragment_samplers_to_consecutive_slots(register, bind[0..1]);
                    },
                }
            }

            pub fn bind_all_storage_textures(self: RenderPassWithPipeline) void {
                const info = INTERNAL.get_render_pipeline_info(self.pipeline);
                const allowed_vert = INTERNAL.allowed_storage_textures_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_STORAGE_TEXTURE_SET_VERT]*SDL3.GPU_Texture = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = self.controller.get_texture(vert.texture);
                    }
                    const first_slot_vert = allowed_vert[0].register;
                    self.pass.bind_vertex_storage_textures_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
                }
                const allowed_frag = INTERNAL.allowed_storage_textures_for_frag_shaders(info.fragment);
                if (allowed_frag.len > 0) {
                    var frag_bindings: [INTERNAL.LONGEST_STORAGE_TEXTURE_SET_FRAG]*SDL3.GPU_Texture = undefined;
                    for (allowed_frag, 0..) |frag, f| {
                        frag_bindings[f] = self.controller.get_texture(frag.texture);
                    }
                    const first_slot_frag = allowed_frag[0].register;
                    self.pass.bind_fragment_storage_textures_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_one_storage_texture(self: RenderPassWithPipeline, comptime stage: ShaderStage, texture: TextureName) void {
                const register = INTERNAL.storage_texture_register_for_render_pipeline_stage(self.pipeline, texture, stage) orelse ct_assert_unreachable(@src(), "storage texture `{s}` is not allowed for render pipeline `{s}` {s} stage", .{ @tagName(texture), @tagName(self.pipeline), @tagName(stage) });
                const bind = [1]*SDL3.GPU_Texture{self.controller.get_texture(texture)};
                switch (stage) {
                    .VERTEX => {
                        self.pass.bind_vertex_storage_textures_to_consecutive_slots(register, bind[0..1]);
                    },
                    .FRAGMENT => {
                        self.pass.bind_fragment_storage_textures_to_consecutive_slots(register, bind[0..1]);
                    },
                }
            }

            pub fn bind_all_storage_buffers(self: RenderPassWithPipeline) void {
                const info = INTERNAL.get_render_pipeline_info(self.pipeline);
                const allowed_vert = INTERNAL.allowed_storage_buffers_for_vert_shaders(info.vertex);
                if (allowed_vert.len > 0) {
                    var vert_bindings: [INTERNAL.LONGEST_STORAGE_BUFFER_SET_VERT]*SDL3.GPU_Buffer = undefined;
                    for (allowed_vert, 0..) |vert, v| {
                        vert_bindings[v] = self.controller.get_storage_buffer(vert.buffer);
                    }
                    const first_slot_vert = allowed_vert[0].register;
                    self.pass.bind_vertex_storage_buffers_to_consecutive_slots(first_slot_vert, vert_bindings[0..allowed_vert.len]);
                }
                const allowed_frag = INTERNAL.allowed_storage_buffers_for_frag_shaders(info.fragment);
                if (allowed_frag.len > 0) {
                    var frag_bindings: [INTERNAL.LONGEST_STORAGE_BUFFER_SET_FRAG]*SDL3.GPU_Buffer = undefined;
                    for (allowed_frag, 0..) |frag, f| {
                        frag_bindings[f] = self.controller.get_storage_buffer(frag.buffer);
                    }
                    const first_slot_frag = allowed_frag[0].register;
                    self.pass.bind_fragment_storage_buffers_to_consecutive_slots(first_slot_frag, frag_bindings[0..allowed_frag.len]);
                }
            }

            pub fn bind_one_storage_buffer(self: RenderPassWithPipeline, comptime stage: ShaderStage, buffer: StorageBufferName) void {
                const register = INTERNAL.storage_buffer_register_for_render_pipeline_stage(self.pipeline, buffer, stage) orelse ct_assert_unreachable(@src(), "storage buffer `{s}` is not allowed for render pipeline `{s}` {s} stage", .{ @tagName(buffer), @tagName(self.pipeline), @tagName(stage) });
                const bind = [1]*SDL3.GPU_Buffer{self.controller.get_storage_buffer(buffer)};
                switch (stage) {
                    .VERTEX => {
                        self.pass.bind_vertex_storage_buffers_to_consecutive_slots(register, bind[0..1]);
                    },
                    .FRAGMENT => {
                        self.pass.bind_fragment_storage_buffers_to_consecutive_slots(register, bind[0..1]);
                    },
                }
            }

            pub fn bind_index_buffer(self: RenderPassWithPipeline, buffer: IndexBufferName, offset: u32) void {
                const buf_idx = @intFromEnum(buffer);
                var bind = GPU_BufferBinding{
                    .buffer = self.controller.get_index_buffer(buffer),
                    .offset = offset,
                };
                const size = self.controller.index_buffer_types[buf_idx];
                self.pass.bind_index_buffer(&bind, size);
                self.index_buffer_bound = true;
            }

            pub fn draw_primitives(self: RenderPassWithPipeline, first_vertex: u32, num_vertices: u32, first_instance: u32, num_instances: u32) void {
                self.pass.draw_primitives(first_vertex, num_vertices, first_instance, num_instances);
            }
            pub fn draw_primitives_indirect(self: RenderPassWithPipeline, indirect_draw_buffer: IndirectDrawBufferName, draw_call_offset: u32, num_draw_calls: u32) void {
                const buf_idx = @intFromEnum(indirect_draw_buffer);
                const buf = self.controller.get_indirect_draw_buffer(indirect_draw_buffer);
                assert_with_reason(self.controller.indirect_draw_buffer_modes[buf_idx] == .VERTEX, @src(), "indirect draw call buffer `{s}` is staged to contain per-index draw calls (GPU_IndexedIndirectDrawCommand), not per-vertex draw calls (GPU_IndirectDrawCommand)", .{@tagName(indirect_draw_buffer)});
                self.pass.draw_primitives_indirect(buf, draw_call_offset, num_draw_calls);
            }

            pub fn draw_indexed_primitives(self: RenderPassWithPipeline, vertex_offset_per_index: i32, first_index: u32, num_indices: u32, first_instance: u32, num_instances: u32) void {
                assert_with_reason(self.index_buffer_bound, @src(), "cannot draw indexed data when no index buffer is bound", .{});
                self.pass.draw_indexed_primitives(vertex_offset_per_index, first_index, num_indices, first_instance, num_instances);
            }
            pub fn draw_indexed_primitives_indirect(self: RenderPassWithPipeline, indirect_draw_buffer: IndirectDrawBufferName, draw_call_offset: u32, num_draw_calls: u32) void {
                const buf_idx = @intFromEnum(indirect_draw_buffer);
                const buf = self.controller.get_indirect_draw_buffer(indirect_draw_buffer);
                assert_with_reason(self.controller.indirect_draw_buffer_modes[buf_idx] == .INDEX, @src(), "indirect draw call buffer `{s}` is staged to contain per-vertex draw calls (GPU_IndirectDrawCommand), not per-index draw calls (GPU_IndexedIndirectDrawCommand)", .{@tagName(indirect_draw_buffer)});
                self.pass.draw_indexed_primitives_indirect(buf, draw_call_offset, num_draw_calls);
            }

            pub fn end_pipeline_pass(self: *RenderPassWithPipeline) void {
                self.controller.render_pass_with_pipeline_active = false;
                self.* = undefined;
                return;
            }
        };

        pub const INTERNAL = struct {
            pub const NUM_WINDOWS = Types.enum_defined_field_count(WINDOW_NAMES_ENUM);
            pub const NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
            pub const NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
            pub const NUM_UPLOAD_TRANSFER_BUFFERS = Types.enum_defined_field_count(UPLOAD_TRANSFER_BUFFER_NAMES_ENUM);
            pub const NUM_DOWNLOAD_TRANSFER_BUFFERS = Types.enum_defined_field_count(DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM);
            pub const NUM_VERTEX_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
            pub const NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);
            pub const NUM_VERTEX_STRUCTS = Types.enum_defined_field_count(GPU_SHADER_STRUCT_NAMES_ENUM);
            pub const NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM);
            pub const NUM_FENCES = Types.enum_defined_field_count(FENCE_NAMES_ENUM);
            pub const NUM_INDEX_BUFFERS = Types.enum_defined_field_count(INDEX_BUFFER_NAMES);
            pub const NUM_INDIRECT_BUFFERS = Types.enum_defined_field_count(INDEX_BUFFER_NAMES);

            pub const TEXTURE_DEFS = ordered_texture_definitions_const;
            pub const STORAGE_BUFFER_TYPES = ordered_storage_buffer_element_types_const;

            pub const LONGEST_VERTEX_BUFFER_SET = longest_set_of_vertex_buffers_const;
            pub const LONGEST_STORAGE_BUFFER_SET_VERT = longest_storage_buffer_set_vert_const;
            pub const LONGEST_STORAGE_BUFFER_SET_FRAG = longest_storage_buffer_set_frag_const;
            pub const LONGEST_STORAGE_TEXTURE_SET_VERT = longest_storage_texture_set_vert_const;
            pub const LONGEST_STORAGE_TEXTURE_SET_FRAG = longest_storage_texture_set_frag_const;
            pub const LONGEST_SAMPLE_PAIR_SET_VERT = longest_sample_pair_set_vert_const;
            pub const LONGEST_SAMPLE_PAIR_SET_FRAG = longest_sample_pair_set_frag_const;

            pub const PIPELINE_DEFS = ordered_pipeline_definitions_const;
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
                            if (allowed.buffer == buffer) return allowed.register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_storage_buffers_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.buffer == buffer) return allowed.register;
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
            pub fn storage_texture_register_for_render_pipeline_stage(pipeline: RenderPipelineName, texture: TextureName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_storage_textures_for_vert_shaders(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.texture == texture) return allowed.register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_storage_textures_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.texture == texture) return allowed.register;
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
            pub fn sample_pair_register_for_render_pipeline_stage(pipeline: RenderPipelineName, sampler: SamplerName, texture: TextureName, comptime stage: ShaderStage) ?u32 {
                const info = get_render_pipeline_info(pipeline);
                const combined = Types.combine_2_enums(sampler, texture);
                switch (stage) {
                    .VERTEX => {
                        const allowed_for_vert = allowed_sample_pairs_for_vert_shaders(info.vertex);
                        for (allowed_for_vert) |allowed| {
                            if (allowed.combined_id == combined) return allowed.register;
                        }
                    },
                    .FRAGMENT => {
                        const allowed_for_frag = allowed_sample_pairs_for_frag_shaders(info.fragment);
                        for (allowed_for_frag) |allowed| {
                            if (allowed.combined_id == combined) return allowed.register;
                        }
                    },
                }
                return null;
            }

            pub const ALLOWED_VERTEX_BUFFER_NAMES_FOR_PIPELINE_FLAT = vertex_buffer_names_to_bind_per_render_pipeline_const;
            pub const ALLOWED_VERTEX_BUFFER_DEFS_FOR_PIPELINE_FLAT = vertex_buffers_to_bind_per_render_pipeline_const;
            pub const VERTEX_BUFFER_NAMES_DEFS_START_LOCS = vertex_buffers_to_bind_start_locs_const;
            pub const ALLOWED_VERTEX_ATTRIBUTES_FOR_PIPELINE_FLAT = vertex_attributes_to_bind_per_render_pipeline_const;
            pub const VERTEX_ATTRIBUTE_START_LOCS = vertex_attribute_start_locs_const;
            pub const VERTEX_BUFFER_DEFS = ordered_vertex_buffer_descriptions_const;
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
        };

        pub const WindowName = WINDOW_NAMES_ENUM;
        pub const RenderPipelineName = RENDER_PIPELINE_NAMES_ENUM;
        pub const TextureName = TEXTURE_NAMES_ENUM;
        pub const UploadTransferBufferName = UPLOAD_TRANSFER_BUFFER_NAMES_ENUM;
        pub const DownloadTransferBufferName = DOWNLOAD_TRANSFER_BUFFER_NAMES_ENUM;
        pub const SamplerName = SAMPLER_NAMES_ENUM;
        pub const VertexBufferName = GPU_VERTEX_BUFFER_NAMES_ENUM;
        pub const VertexStructName = GPU_SHADER_STRUCT_NAMES_ENUM;
        pub const StorageBufferName = GPU_STORAGE_BUFFER_NAMES_ENUM;
        pub const UniformName = GPU_UNIFORM_NAMES_ENUM;
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

            pub fn create_info(self: WindowInit) CreateWindowOptions {
                return CreateWindowOptions{
                    .flags = self.flags,
                    .size = self.size,
                    .title = self.title,
                };
            }
        };

        pub const VertexShaderInit = struct {
            name: VertexShaderName,
            code: ShaderCode,
            props: PropertiesID = .{},

            fn create_info(self: VertexShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.ptr,
                    .code_size = self.code.len,
                    .entrypoint_func = self.entry_func_name,
                    .format = self.format,
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

            fn create_info(self: FragmentShaderInit) GPU_ShaderCreateInfo {
                return GPU_ShaderCreateInfo{
                    .code = self.code.code.ptr,
                    .code_size = self.code.code.len,
                    .entrypoint_func = self.entry_func_name,
                    .format = self.format,
                    .num_samplers = INTERNAL.num_sample_pairs_for_frag_shader(self.name),
                    .num_storage_buffers = INTERNAL.num_storage_buffers_for_frag_shader(self.name),
                    .num_storage_textures = INTERNAL.num_storage_textures_for_frag_shader(self.name),
                    .num_uniform_buffers = INTERNAL.num_uniforms_for_frag_shader(self.name),
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

            pub fn create_info(self: RenderPipelineInit, vert_shaders: [_NUM_VERTEX_SHADERS]*GPU_Shader, frag_shaders: [_NUM_FRAGMENT_SHADERS]*GPU_Shader) GPU_GraphicsPipelineCreateInfo {
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
            props: PropertiesID = .{},

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

        pub const UploadBufferInit = struct {
            name: UploadTransferBufferName,
            max_byte_size: u32 = 0,
            props: PropertiesID = .{},

            pub fn create_info(self: UploadBufferInit) GPU_TransferBufferCreateInfo {
                return GPU_TransferBufferCreateInfo{
                    .props = self.props,
                    .size = self.max_byte_size,
                    .usage = .UPLOAD,
                };
            }
        };

        pub const DownloadBufferInit = struct {
            name: DownloadTransferBufferName,
            max_byte_size: u32 = 0,
            props: PropertiesID = .{},

            pub fn create_info(self: DownloadBufferInit) GPU_TransferBufferCreateInfo {
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

            pub fn create_info(self: VertexBufferInit) GPU_BufferCreateInfo {
                const idx = @intFromEnum(self.name);
                const SIZE = @sizeOf(INTERNAL.VERTEX_BUFFER_DEFS[idx].element_type);
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_element_count * SIZE,
                    .usage = GPU_BufferUsageFlags.from_flag(.VERTEX),
                };
            }
        };

        pub const IndexBufferInit = struct {
            name: IndexBufferName,
            index_kind: GPU_IndexTypeSize = .U16,
            max_indices: u32 = 0,
            props: PropertiesID = .{},

            pub fn create_info(self: IndexBufferInit) GPU_BufferCreateInfo {
                const SIZE: u32 = switch (self.index_kind) {
                    .U32 => 4,
                    .U16 => 2,
                };
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_indices * SIZE,
                    .usage = GPU_BufferUsageFlags.from_flag(.INDEX),
                };
            }
        };
        pub const IndirectDrawBufferInit = struct {
            name: IndirectDrawBufferName,
            draw_mode: VertexDrawMode = .VERTEX,
            max_indirect_draw_calls: u32 = 0,
            props: PropertiesID = .{},

            pub fn create_info(self: IndirectDrawBufferInit) GPU_BufferCreateInfo {
                const SIZE: u32 = switch (self.draw_mode) {
                    .VERTEX => @sizeOf(GPU_IndirectDrawCommand),
                    .INDEX => @sizeOf(GPU_IndexedIndirectDrawCommand),
                };
                return GPU_BufferCreateInfo{
                    .props = self.props,
                    .size = self.max_indirect_draw_calls * SIZE,
                    .usage = GPU_BufferUsageFlags.from_flag(.INDIRECT),
                };
            }
        };

        // pub fn create(options: GPU_CreateOptions) !Controller {
        //     // CONTROLLER AND GPU
        //     var controller: Controller = .{};
        //     controller.gpu = try GPU_Device.create(options);
        //     errdefer controller.gpu.destroy();
        //     // WINDOWS
        //     errdefer {
        //         inline for (0..NUM_WINDOWS) |w| {
        //             const w_settings = init.window_settings[w];
        //             const window_idx = @intFromEnum(w_settings.name);
        //             if (controller.windows_claimed[window_idx]) {
        //                 controller.gpu.release_window(controller.windows[window_idx]);
        //             }
        //             if (controller.windows_init[window_idx]) {
        //                 controller.windows[window_idx].destroy();
        //             }
        //         }
        //     }
        //     inline for (0..NUM_WINDOWS) |w| {
        //         const w_settings = init.window_settings[w];
        //         const window_idx = @intFromEnum(w_settings.name);
        //         if (controller.windows_init[window_idx]) return WindowInitError.window_already_initialized;
        //         if (w_settings.should_init) {
        //             const create_info = w_settings.create_info();
        //             controller.windows[window_idx] = try Window.create(create_info);
        //             controller.windows_init[window_idx] = true;
        //             if (w_settings.claim_on_init) {
        //                 try controller.gpu.claim_window(controller.windows[window_idx]);
        //                 controller.windows_claimed[window_idx] = true;
        //             }
        //         }
        //     }
        //     // VERT_SHADERS
        //     var vert_shaders: [_NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
        //     var vert_shaders_init: [_NUM_VERTEX_SHADERS]bool = @splat(false);
        //     defer {
        //         inline for (0.._NUM_VERTEX_SHADERS) |v| {
        //             const v_settings = init.vertex_shader_settings[v];
        //             const shader_idx = @intFromEnum(v_settings.name);
        //             if (vert_shaders_init[shader_idx]) {
        //                 controller.gpu.release_shader(vert_shaders[shader_idx]);
        //             }
        //         }
        //     }
        //     inline for (0.._NUM_VERTEX_SHADERS) |v| {
        //         const v_settings = init.vertex_shader_settings[v];
        //         const shader_idx = @intFromEnum(v_settings.name);
        //         if (vert_shaders_init[shader_idx]) return VertShaderInitError.vertex_shader_already_initialized;
        //         var create_info = v_settings.create_info();
        //         vert_shaders[shader_idx] = try controller.gpu.create_shader(&create_info);
        //         vert_shaders_init[shader_idx] = true;
        //     }
        //     // FRAG SHADERS
        //     var frag_shaders: [_NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
        //     var frag_shaders_init: [_NUM_VERTEX_SHADERS]bool = @splat(false);
        //     defer {
        //         inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        //             const f_settings = init.fragment_shader_settings[f];
        //             const shader_idx = @intFromEnum(f_settings.name);
        //             if (frag_shaders_init[shader_idx]) {
        //                 controller.gpu.release_shader(frag_shaders[shader_idx]);
        //             }
        //         }
        //     }
        //     inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        //         const f_settings = init.fragment_shader_settings[f];
        //         const shader_idx = @intFromEnum(f_settings.name);
        //         if (frag_shaders_init[shader_idx]) return FragShaderInitError.fragment_shader_already_initialized;
        //         var create_info = f_settings.create_info();
        //         frag_shaders[shader_idx] = try controller.gpu.create_shader(&create_info);
        //         frag_shaders_init[shader_idx] = true;
        //     }
        //     // RENDER PIPELINES
        //     errdefer {
        //         inline for (0..NUM_RENDER_PIPELINES) |r| {
        //             const r_settings = init.render_pipeline_settings[r];
        //             const pipe_idx = @intFromEnum(r_settings.name);
        //             if (controller.render_pipelines_init[pipe_idx]) {
        //                 controller.gpu.release_graphics_pipeline(controller.render_pipelines[pipe_idx]);
        //             }
        //         }
        //     }
        //     inline for (0..NUM_RENDER_PIPELINES) |r| {
        //         const r_settings = init.render_pipeline_settings[r];
        //         const pipe_idx = @intFromEnum(r_settings.name);
        //         if (controller.render_pipelines_init[pipe_idx]) return RenderPipelineInitError.render_pipeline_already_initialized;
        //         if (r_settings.should_init) {
        //             var create_info = r_settings.create_info(vert_shaders, frag_shaders);
        //             controller.render_pipelines[pipe_idx] = try controller.gpu.create_graphics_pipeline(&create_info);
        //             controller.render_pipelines_init[pipe_idx] = true;
        //         }
        //     }
        //     // TEXTURES
        //     errdefer {
        //         inline for (0..NUM_TEXTURES) |t| {
        //             const t_settings = init.texture_settings[t];
        //             const tex_idx = @intFromEnum(t_settings.name);
        //             if (controller.textures_init[tex_idx]) {
        //                 controller.gpu.release_texture(controller.textures[tex_idx]);
        //             }
        //         }
        //     }
        //     inline for (0..NUM_TEXTURES) |t| {
        //         const t_settings = init.texture_settings[t];
        //         const tex_idx = @intFromEnum(t_settings.name);
        //         if (controller.textures_init[tex_idx]) return TextureInitError.texture_already_initialized;
        //         if (t_settings.should_init) {
        //             var create_info = t_settings.create_info();
        //             controller.textures[tex_idx] = try controller.gpu.create_texture(&create_info);
        //             controller.textures_init[tex_idx] = true;
        //         }
        //     }
        //     // SAMPLERS
        //     errdefer {
        //         inline for (0..NUM_SAMPLERS) |s| {
        //             const s_settings = init.sampler_settings[s];
        //             const samp_idx = @intFromEnum(s_settings.name);
        //             if (controller.samplers_init[samp_idx]) {
        //                 controller.gpu.release_texture_sampler(controller.samplers[samp_idx]);
        //             }
        //         }
        //     }
        //     inline for (0..NUM_SAMPLERS) |s| {
        //         const s_settings = init.texture_settings[s];
        //         const samp_idx = @intFromEnum(s_settings.name);
        //         if (controller.samplers_init[samp_idx]) return SamplerInitError.sampler_already_initialized;
        //         if (s_settings.should_init) {
        //             var create_info = s_settings.create_info();
        //             controller.samplers[samp_idx] = try controller.gpu.create_texture_sampler(&create_info);
        //             controller.samplers_init[samp_idx] = true;
        //         }
        //     }
        //     // TRANSFER BUFFERS
        //     errdefer {
        //         inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
        //             const tb_settings = init.transfer_buffer_settings[tb];
        //             const trans_buf_idx = @intFromEnum(tb_settings.name);
        //             if (controller.upload_transfer_buffers_init[trans_buf_idx]) {
        //                 controller.gpu.release_transfer_buffer(controller.upload_transfer_buffers[trans_buf_idx]);
        //             }
        //         }
        //     }
        //     inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
        //         const tb_settings = init.transfer_buffer_settings[tb];
        //         const trans_buf_idx = @intFromEnum(tb_settings.name);
        //         if (controller.upload_transfer_buffers_init[trans_buf_idx]) return TransferBufferInitError.transfer_buffer_already_initialized;
        //         if (tb_settings.should_init) {
        //             var create_info = tb_settings.create_info();
        //             controller.upload_transfer_buffers[trans_buf_idx] = try controller.gpu.create_transfer_buffer(&create_info);
        //             controller.upload_transfer_buffers_init[trans_buf_idx] = true;
        //         }
        //     }
        //     // GPU BUFFERS
        //     errdefer {
        //         inline for (0..NUM_GPU_BUFFERS) |gb| {
        //             const gb_settings = init.gpu_buffer_settings[gb];
        //             const gpu_buf_idx = @intFromEnum(gb_settings.name);
        //             if (controller.vertex_buffers_init[gpu_buf_idx]) {
        //                 controller.gpu.release_buffer(controller.vertex_buffers[gpu_buf_idx]);
        //             }
        //         }
        //     }
        //     inline for (0..NUM_GPU_BUFFERS) |gb| {
        //         const gb_settings = init.gpu_buffer_settings[gb];
        //         const gpu_buf_idx = @intFromEnum(gb_settings.name);
        //         if (controller.vertex_buffers_init[gpu_buf_idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
        //         if (gb_settings.should_init) {
        //             var create_info = gb_settings.create_info();
        //             controller.vertex_buffers[gpu_buf_idx] = try controller.gpu.create_buffer(&create_info);
        //             controller.vertex_buffers_init[gpu_buf_idx] = true;
        //         }
        //     }
        //     return controller;
        // }

        // // pub fn destroy(self: *Controller) void {
        // //     inline for (0..NUM_GPU_BUFFERS) |gb| {
        // //         if (self.vertex_buffers_init[gb]) {
        // //             self.gpu.release_buffer(self.vertex_buffers[gb]);
        // //         }
        // //     }
        // //     inline for (0..NUM_TRANSFER_BUFFERS) |tb| {
        // //         if (self.upload_transfer_buffers_init[tb]) {
        // //             self.gpu.release_transfer_buffer(self.upload_transfer_buffers[tb]);
        // //         }
        // //     }
        // //     inline for (0..NUM_SAMPLERS) |s| {
        // //         if (self.samplers_init[s]) {
        // //             self.gpu.release_texture_sampler(self.samplers[s]);
        // //         }
        // //     }
        // //     inline for (0..NUM_TEXTURES) |t| {
        // //         if (self.textures_init[t]) {
        // //             self.gpu.release_texture(self.textures[t]);
        // //         }
        // //     }
        // //     inline for (0..NUM_RENDER_PIPELINES) |r| {
        // //         if (self.render_pipelines_init[r]) {
        // //             self.gpu.release_graphics_pipeline(self.render_pipelines[r]);
        // //         }
        // //     }
        // //     inline for (0..NUM_WINDOWS) |w| {
        // //         if (self.windows_claimed[w]) {
        // //             self.gpu.release_window(self.controller.windows[w]);
        // //         }
        // //         if (self.windows_init[w]) {
        // //             self.windows[w].destroy();
        // //         }
        // //     }
        // //     self.gpu.destroy();
        // //     self.* = undefined;
        // // }

        // // pub fn create_window(self: *Controller, window_name: WindowName, init: CreateWindowOptions) WindowInitError!void {
        // //     const idx = @intFromEnum(window_name);
        // //     if (self.windows_init[idx]) return WindowInitError.window_already_initialized;
        // //     self.windows[idx] = try Window.create(init);
        // //     self.windows_init[idx] = true;
        // // }
        // // pub fn destroy_window(self: *Controller, window_name: WindowName) void {
        // //     const idx = @intFromEnum(window_name);
        // //     if (self.windows_claimed[idx]) {
        // //         self.gpu.release_window(self.windows[idx]);
        // //         self.windows_claimed[idx] = false;
        // //     }
        // //     if (self.windows_init[idx]) {
        // //         self.windows[idx].destroy();
        // //         self.windows_init[idx] = false;
        // //     }
        // // }
        // // pub fn claim_window(self: *Controller, window_name: WindowName) WindowInitError!void {
        // //     const idx = @intFromEnum(window_name);
        // //     if (!self.windows_init[idx]) return WindowInitError.window_cannot_be_claimed_when_uninitialized;
        // //     try self.gpu.claim_window(self.windows[idx]);
        // //     self.windows_claimed[idx] = true;
        // // }
        // // pub fn release_window(self: *Controller, window_name: WindowName) void {
        // //     const idx = @intFromEnum(window_name);
        // //     if (!self.windows_claimed[idx]) return;
        // //     self.gpu.release_window(self.windows[idx]);
        // //     self.windows_claimed[idx] = false;
        // // }
        // // pub fn create_and_claim_window(self: *Controller, window_name: WindowName, init: CreateWindowOptions) WindowInitError!void {
        // //     try self.create_window(window_name, init);
        // //     try self.claim_window(window_name);
        // // }
        // // pub fn release_and_destroy_window(self: *Controller, window_name: WindowName) void {
        // //     self.release_window(window_name);
        // //     self.destroy_window(window_name);
        // // }

        // // pub fn create_render_pipeline(self: *Controller, pipeline_name: RenderPipelineName, vertex_shader_info: *GPU_ShaderCreateInfo, fragment_shader_info: *GPU_ShaderCreateInfo, pipeline_info: *GPU_GraphicsPipelineCreateInfo) RenderPipelineInitError!void {
        // //     const idx = @intFromEnum(pipeline_name);
        // //     if (self.render_pipelines_init[idx]) return RenderPipelineInitError.render_pipeline_already_initialized;
        // //     const vert_shader = try self.gpu.create_shader(vertex_shader_info);
        // //     defer self.gpu.release_shader(vert_shader);
        // //     const frag_shader = try self.gpu.create_shader(fragment_shader_info);
        // //     defer self.gpu.release_shader(frag_shader);
        // //     self.render_pipelines[idx] = try self.gpu.create_graphics_pipeline(pipeline_info);
        // //     self.render_pipelines_init[idx] = true;
        // // }
        // // pub fn destroy_render_pipeline(self: *Controller, pipeline_name: RenderPipelineName) void {
        // //     const idx = @intFromEnum(pipeline_name);
        // //     if (!self.render_pipelines_init[idx]) return;
        // //     self.gpu.release_graphics_pipeline(self.render_pipelines[idx]);
        // //     self.render_pipelines_init[idx] = false;
        // // }

        // // pub fn create_texture_sampler(self: *Controller, sampler_name: SamplerName, sampler_info: *GPU_SamplerCreateInfo) SamplerInitError!void {
        // //     const idx = @intFromEnum(sampler_name);
        // //     if (self.samplers_init[idx]) return SamplerInitError.sampler_already_initialized;
        // //     self.samplers[idx] = try self.gpu.create_texture_sampler(sampler_info);
        // //     self.samplers_init[idx] = true;
        // // }
        // // pub fn destroy_texture_sampler(self: *Controller, sampler_name: SamplerName) void {
        // //     const idx = @intFromEnum(sampler_name);
        // //     if (!self.samplers_init[idx]) return;
        // //     self.gpu.release_texture_sampler(self.samplers[idx]);
        // //     self.samplers_init[idx] = false;
        // // }

        // // pub fn create_texture(self: *Controller, texture_name: TextureName, texture_info: *GPU_TextureCreateInfo) TextureInitError!void {
        // //     const idx = @intFromEnum(texture_name);
        // //     if (self.textures_init[idx]) return TextureInitError.texture_already_initialized;
        // //     self.textures[idx] = try self.gpu.create_texture(texture_info);
        // //     self.textures_init[idx] = true;
        // // }
        // // pub fn destroy_texture(self: *Controller, texture_name: TextureName) void {
        // //     const idx = @intFromEnum(texture_name);
        // //     if (!self.textures_init[idx]) return;
        // //     self.gpu.release_texture(self.textures[idx]);
        // //     self.textures_init[idx] = false;
        // // }

        // // pub fn create_transfer_buffer(self: *Controller, transfer_buffer_name: UploadTransferBufferName, buffer_info: *GPU_TransferBufferCreateInfo) TransferBufferInitError!void {
        // //     const idx = @intFromEnum(transfer_buffer_name);
        // //     if (self.upload_transfer_buffers_init[idx]) return TransferBufferInitError.transfer_buffer_already_initialized;
        // //     self.upload_transfer_buffers[idx] = try self.gpu.create_transfer_buffer(buffer_info);
        // //     self.upload_transfer_buffers_init[idx] = true;
        // // }
        // // pub fn destroy_transfer_buffer(self: *Controller, transfer_buffer_name: UploadTransferBufferName) void {
        // //     const idx = @intFromEnum(transfer_buffer_name);
        // //     if (!self.upload_transfer_buffers_init[idx]) return;
        // //     self.gpu.release_transfer_buffer(self.upload_transfer_buffers[idx]);
        // //     self.upload_transfer_buffers_init[idx] = false;
        // // }

        // // pub fn create_gpu_buffer(self: *Controller, gpu_buffer_name: GpuBufferName, buffer_info: *GPU_BufferCreateInfo) GpuBufferInitError!void {
        // //     const idx = @intFromEnum(gpu_buffer_name);
        // //     if (self.vertex_buffers_init[idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
        // //     self.vertex_buffers[idx] = try self.gpu.create_buffer(buffer_info);
        // //     self.vertex_buffers_init[idx] = true;
        // // }
        // // pub fn destroy_gpu_buffer(self: *Controller, gpu_buffer_name: GpuBufferName) void {
        // //     const idx = @intFromEnum(gpu_buffer_name);
        // //     if (!self.vertex_buffers_init[idx]) return;
        // //     self.gpu.release_buffer(self.vertex_buffers[idx]);
        // //     self.vertex_buffers_init[idx] = false;
        // // }

        // pub fn begin_commands(self: *Controller, delete_buffer_list: List(DeleteBufferDetails), delete_buffer_list_alloc: Allocator) PossibleError(CommandBuffer) {
        //     return CommandBuffer{
        //         .controller = self,
        //         .command = self.gpu.acquire_command_buffer() catch |err| return ERROR_MODE.handle(@src(), err),
        //         .delete_buffers_list = delete_buffer_list,
        //         .delete_buffers_alloc = delete_buffer_list_alloc,
        //     };
        // }
    };
}

fn vert_def_slot_greater(a: SDL3.GPU_VertexBufferDescription, b: SDL3.GPU_VertexBufferDescription) bool {
    return a.slot > b.slot;
}
