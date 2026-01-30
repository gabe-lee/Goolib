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
const Sort = Root.Sort.InsertionSort;

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

const ShaderContract = SDL3.ShaderContract;
const StorageStructField = ShaderContract.StorageStructField;
const StorageStruct = ShaderContract.StorageStruct;

const assert_with_reason = Assert.assert_with_reason;
const update_max = Utils.update_max;
const update_min = Utils.update_min;

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

pub const AllowedUniform = struct {
    /// `register(b#, ...)` in HLSL
    vertex_register: u32 = 0,
    /// `register(b#, ...)` in HLSL
    fragment_register: u32 = 0,
    /// for asserting correct uniform pushes
    ///
    /// `register(b#, space1)` in HLSL
    allowed_in_vertex: bool = false,
    /// for asserting correct uniform pushes
    ///
    /// `register(b#, space3)` in HLSL
    allowed_in_fragment: bool = false,
};
pub const AllowedStorageBuffer = struct {
    /// `register(t#, ...)` in HLSL
    vertex_register: u32 = 0,
    /// `register(t#, ...)` in HLSL
    fragment_register: u32 = 0,
    /// for asserting correct uniform pushes
    ///
    /// `register(t#, space0)` in HLSL
    bind_in_vertex: bool = false,
    /// for asserting correct uniform pushes
    ///
    /// `register(t#, space2)` in HLSL
    bind_in_fragment: bool = false,
};
pub const AllowedStorageTexture = struct {
    /// `register(t#, ...)` in HLSL
    vertex_register: u32 = 0,
    /// `register(t#, ...)` in HLSL
    fragment_register: u32 = 0,
    /// for asserting correct uniform pushes
    ///
    /// `register(t#, space0)` in HLSL
    bind_in_vertex: bool = false,
    /// for asserting correct uniform pushes
    ///
    /// `register(t#, space2)` in HLSL
    bind_in_fragment: bool = false,
};
pub fn AllowedSamplePair(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        combined_id: Types.Combined2EnumInt(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).combined_type = 0,
        sampler: SAMPLER_NAMES_ENUM = undefined,
        texture: TEXTURE_NAMES_ENUM = undefined,
        /// `register(t#, ...)` in HLSL
        vertex_register: u32 = 0,
        /// `register(t#, ...)` in HLSL
        fragment_register: u32 = 0,
        /// for asserting correct uniform pushes
        ///
        /// `register(t#, space0)` in HLSL
        bind_in_vertex: bool = false,
        /// for asserting correct uniform pushes
        ///
        /// `register(t#, space2)` in HLSL
        bind_in_fragment: bool = false,

        pub fn equals_id(a: Self, b: Self) bool {
            return a.combined_id == b.combined_id;
        }
    };
}
pub const AllowedVertexBuffer = struct {
    register: u32 = 0,
    allowed: bool = false,
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
        vertex_register: VertexRegister = .no_vertex_register(),
        fragment_register: FragmentRegister = .no_fragment_register(),

        pub fn link_uniform(comptime uniform: UNIFORM_NAMES_ENUM, comptime vert_register: VertexRegister, comptime frag_register: FragmentRegister) Self {
            return Self{
                .uniform = uniform,
                .vertex_register = vert_register,
                .fragment_register = frag_register,
            };
        }
    };
}

pub fn StorageBufferRegister(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        buffer: STORAGE_BUFFER_NAMES_ENUM,
        vertex_register: VertexRegister = .no_vertex_register(),
        fragment_register: FragmentRegister = .no_fragment_register(),

        pub fn link_storage_buffer(comptime buffer: STORAGE_BUFFER_NAMES_ENUM, comptime vert_register: VertexRegister, comptime frag_register: FragmentRegister) Self {
            return Self{
                .buffer = buffer,
                .vertex_register = vert_register,
                .fragment_register = frag_register,
            };
        }
    };
}

pub fn ReadOnlyStorageTextureRegister(comptime TEXTURE_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: TEXTURE_NAMES_ENUM,
        vertex_register: VertexRegister = .no_vertex_register(),
        fragment_register: FragmentRegister = .no_fragment_register(),

        pub fn link_read_only_storage_texture(comptime texture: TEXTURE_NAMES_ENUM, comptime vert_register: VertexRegister, comptime frag_register: FragmentRegister) Self {
            return Self{
                .texture = texture,
                .vertex_register = vert_register,
                .fragment_register = frag_register,
            };
        }
    };
}

pub const VertexRegister = struct {
    register: Register = .AUTO,
    allow: bool = false,

    pub fn no_vertex_register() VertexRegister {
        return VertexRegister{ .register = .AUTO, .allow = false };
    }
    pub fn auto_vertex_register() VertexRegister {
        return VertexRegister{ .register = .AUTO, .allow = true };
    }
    pub fn manual_vertex_register(register: u32) VertexRegister {
        return VertexRegister{ .register = .{ .MANUAL = register }, .allow = true };
    }
};
pub const FragmentRegister = struct {
    register: Register = .AUTO,
    allow: bool = false,

    pub fn no_fragment_register() FragmentRegister {
        return FragmentRegister{ .register = .AUTO, .allow = false };
    }
    pub fn auto_fragment_register() FragmentRegister {
        return FragmentRegister{ .register = .AUTO, .allow = true };
    }
    pub fn manual_fragment_register(register: u32) FragmentRegister {
        return FragmentRegister{ .register = .{ .MANUAL = register }, .allow = true };
    }
};

pub fn ReadOnlySampledTextureRegister(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        texture: TEXTURE_NAMES_ENUM,
        sampler: SAMPLER_NAMES_ENUM,
        vertex_register: VertexRegister = .no_vertex_register(),
        fragment_register: FragmentRegister = .no_fragment_register(),

        pub fn link_read_only_sampled_texture(comptime texture: TEXTURE_NAMES_ENUM, comptime sampler: SAMPLER_NAMES_ENUM, comptime vert_register: VertexRegister, comptime frag_register: FragmentRegister) Self {
            return Self{
                .texture = texture,
                .sampler = sampler,
                .vertex_register = vert_register,
                .fragment_register = frag_register,
            };
        }
    };
}

pub fn VertexBufferRegister(comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        buffer: GPU_VERTEX_BUFFER_NAMES_ENUM,
        /// the `buffer_slot` value for the render pipeline
        register: Register = .AUTO,

        pub fn link_vertex_buffer(comptime buffer: GPU_VERTEX_BUFFER_NAMES_ENUM, comptime register: Register) Self {
            return Self{
                .buffer = buffer,
                .register = register,
            };
        }
    };
}

pub const RenderLinkageRegisterKind = enum(u8) {
    SAMPLED_TEXTURE,
    STORAGE_TEXTURE,
    STORAGE_BUFFER,
    UNIFORM_BUFFER,
    VERTEX_BUFFER,
};

pub const StorageRegisterKind = enum(u32) {
    SAMPLED_TEXTURE = 0b01 << 30,
    STORAGE_TEXTURE = 0b10 << 30,
    STORAGE_BUFFER = 0b11 << 30,
};

pub fn RenderLinkageRegister(comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type, comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type) type {
    return union(RenderLinkageRegisterKind) {
        SAMPLED_TEXTURE: ReadOnlySampledTextureRegister(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM),
        STORAGE_TEXTURE: ReadOnlyStorageTextureRegister(TEXTURE_NAMES_ENUM),
        STORAGE_BUFFER: StorageBufferRegister(STORAGE_BUFFER_NAMES_ENUM),
        UNIFORM_BUFFER: UniformRegister(UNIFORM_NAMES_ENUM),
        VERTEX_BUFFER: VertexBufferRegister(GPU_VERTEX_BUFFER_NAMES_ENUM),
    };
}

pub fn RenderPipelineLinkages(comptime RENDER_PIPELINE_NAMES_ENUM: type, comptime UNIFORM_NAMES_ENUM: type, comptime STORAGE_BUFFER_NAMES_ENUM: type, comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type, comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type) type {
    return struct {
        render_pipeline: RENDER_PIPELINE_NAMES_ENUM,
        resources_to_link: []const RenderLinkageRegister(UNIFORM_NAMES_ENUM, STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM, GPU_VERTEX_BUFFER_NAMES_ENUM),
    };
}

pub const ShaderStage = enum(u8) {
    VERTEX = 0,
    FRAGMENT = 1,

    pub fn idx(comptime self: ShaderStage) u8 {
        return @intFromEnum(self);
    }
};

/// This object defines a comptime type with an API to instantiate and control
/// the entire graphics system with more convenient and carefully controlled
/// methods than the standard SDL3 API. For most applications this will be a good
/// choice for all your graphics needs, as it eliminates many pitfalls at comptime
/// and streamlines the graphics workflow.
///
/// It is designed to work alongside `SDL3_ShaderContract.zig` to automatically
/// layout uniforms, storage buffers, and vertex buffers to conform to
/// the requirements imposed by the SDL3 GPU API, and can be used to automatically
/// generate entire shader source files ready to accept user logic.
///
/// BUT, strictly speaking it is not *required* to use `SDL3_ShaderContract.zig`,
/// as long as you properly manually design the structs for the vertex/uniform/storage buffers
pub fn GraphicsController(
    /// An enum with tag names for each unique window of the application
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
    /// An enum with tag names for each unique transfer buffer used in application
    comptime TRANSFER_BUFFER_NAMES_ENUM: type,
    /// An enum with tag names for each unique vertex buffer used in application
    ///
    /// These are the data buffers holding one or more vertex attributes
    ///
    /// This is not the same as `GPU_VERTEX_STRUCT_NAMES_ENUM`, since a vertex
    /// struct (the thing object/slice actually passed to the vertex shader) can
    /// be mapped/built from *multiple* vertex buffers via the `buffer_slot` field on
    /// `GPU_VertexAttribute`
    comptime GPU_VERTEX_BUFFER_NAMES_ENUM: type,
    /// An enum with tag names for each unique vertex struct used in application
    ///
    /// These are the actual object models passed to the vertex shaders as input parameters
    ///
    /// Each tag name must exactly match a field name in `STRUCT_OF_VERTEX_STRUCT_TYPES`
    ///
    /// This is not the same as `GPU_VERTEX_BUFFER_NAMES_ENUM`, since a vertex
    /// struct (the object/bytes actually passed to the vertex shader) can
    /// be mapped/built from *multiple* vertex buffers via the `buffer_slot` field on
    /// `GPU_VertexAttribute`
    ///
    ///  ### Example
    /// ```zig
    /// pub const VertA = struct { color: u32 };
    /// pub const VertB = struct { color: u32 };
    /// pub const VertNames = enum { // THIS
    ///     VertA,
    ///     VertB,
    /// };
    /// pub const VertStructs = struct {
    ///     VertA: VertA,
    ///     VertB: VertB,
    /// };
    /// ```
    comptime GPU_VERTEX_STRUCT_NAMES_ENUM: type,
    /// This should have each unique `SDL3_ShaderContract.StreamStruct(...)` vertex *TYPE* type as an individial field
    /// (not an instance of the type, as instances will be read/written from a stream)
    ///
    /// Each field name must exactly match a tag name in `GPU_VERTEX_STRUCT_NAMES_ENUM`
    ///
    /// ### Example
    /// ```zig
    /// pub const VertA = struct { color: u32 };
    /// pub const VertB = struct { color: u32 };
    /// pub const VertNames = enum {
    ///     VertA,
    ///     VertB,
    /// };
    /// pub const VertStructs = struct { // <----- THIS
    ///     VertA: VertA,
    ///     VertB: VertB,
    /// };
    /// ```
    comptime STRUCT_OF_VERTEX_STRUCT_TYPES: type,
    /// This MUST be a `union(GPU_VERTEX_BUFFER_NAMES_ENUM)` where each field is
    /// an enum TYPE where each enum tag name is the name of a *user supplied* field
    /// to the matching vertex struct (eg. not an HLSL system value semantic, or GLSL builtin location, etc.)
    ///
    /// These are mapped directly to `GPU_VertexAttribute` inputs during initialization
    ///
    /// ### Example
    /// ```zig
    /// const VertA = const {
    ///     color: Vec4, // `layout(location = 1)` or `TEXCOORD1`
    ///     pos: Vec3, // `layout(location = 0)` or `TEXCOORD0`
    ///     normal: Vec3, // `layout(location = 2)` or `TEXCOORD2`
    /// };
    /// const VertUserFieldsA = enum {
    ///     pos = 0, // `layout(location = 0)` or `TEXCOORD0`
    ///     color = 1, // `layout(location = 1)` or `TEXCOORD1`
    ///     normal = 2, // `layout(location = 2)` or `TEXCOORD2`
    /// };
    /// const VertB = const {
    ///     color: Vec4, // `layout(location = 1)` or `TEXCOORD1`
    ///     pos: Vec3, // `layout(location = 0)` or `TEXCOORD0`
    ///     instance_id: u32, // system/builtin supplied
    /// };
    /// const VertUserFieldsB = enum {
    ///     pos = 0, // `layout(location = 0)` or `TEXCOORD0`
    ///     color = 1, // `layout(location = 1)` or `TEXCOORD1`
    /// };
    /// const VertNames = enum {
    ///     VertA,
    ///     VertB,
    /// };
    /// const VertStructFieldNames = union(VertNames) { // <----- THIS
    ///     VertA: VertUserFieldsA,
    ///     VertB: VertUserFieldsB,
    /// };
    /// ```
    comptime UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM: type,
    /// An enum with tag names for each unique uniform struct used in application
    comptime GPU_UNIFORM_NAMES_ENUM: type,
    /// This should have each unique `SDL3_ShaderContract.StorageStruct(...)` uniform type as an individial field
    ///
    /// Uniforms with the same struct type but different data should be separate fields.
    ///
    /// Each field name must exactly match a tag name in `UNIFORM_NAMES_ENUM`
    comptime STRUCT_OF_UNIFORM_STRUCTS: type,
    /// An enum with tag names for each unique gpu storage buffer used in application
    comptime GPU_STORAGE_BUFFER_NAMES_ENUM: type,
    /// This should have each unique `SDL3_ShaderContract.StorageStruct(...)` storage struct *TYPE* as an individial field
    /// (not an instance of the type, as instances will be read/written from a buffer)
    ///
    /// Each field name must exactly match a tag name in `GPU_STORAGE_BUFFER_NAMES`
    comptime STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES: type,
    /// A list of all the resource bindings for each render pipeline in the application
    comptime RENDER_PIPELINE_LINKAGES: [Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM)]RenderPipelineLinkages(RENDER_PIPELINE_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM),
) type {
    assert_with_reason(Types.type_is_enum(WINDOW_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(WINDOW_NAMES_ENUM), @src(), "type `WINDOW_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(WINDOW_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(VERTEX_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_SHADER_NAMES_ENUM), @src(), "type `VERTEX_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(FRAGMENT_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_SHADER_NAMES_ENUM), @src(), "type `FRAGMENT_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(RENDER_PIPELINE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(RENDER_PIPELINE_NAMES_ENUM), @src(), "type `RENDER_PIPELINE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(RENDER_PIPELINE_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(TEXTURE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TEXTURE_NAMES_ENUM), @src(), "type `TEXTURE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TEXTURE_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(SAMPLER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(SAMPLER_NAMES_ENUM), @src(), "type `SAMPLER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(SAMPLER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TRANSFER_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(GPU_VERTEX_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_VERTEX_BUFFER_NAMES_ENUM), @src(), "type `GPU_VERTEX_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_VERTEX_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(GPU_VERTEX_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_VERTEX_STRUCT_NAMES_ENUM), @src(), "type `GPU_VERTEX_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_VERTEX_STRUCT_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct_with_all_fields_same_type(STRUCT_OF_VERTEX_STRUCT_TYPES, type), @src(), "type `STRUCT_OF_VERTEX_STRUCT_TYPES` must be a struct type that holds all concrete types of the storage buffer structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_VERTEX_STRUCT_TYPES)});
    assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_VERTEX_STRUCT_NAMES_ENUM, STRUCT_OF_VERTEX_STRUCT_TYPES), @src(), "`GPU_VERTEX_STRUCT_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_VERTEX_STRUCT_TYPES`, and each enum tag NAME in `GPU_VERTEX_STRUCT_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_VERTEX_STRUCT_TYPES`", .{});
    assert_with_reason(Types.type_is_enum(GPU_UNIFORM_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_UNIFORM_NAMES_ENUM), @src(), "type `UNIFORM_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_UNIFORM_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct(STRUCT_OF_UNIFORM_STRUCTS), @src(), "type `STRUCT_OF_UNIFORM_STRUCTS` must be a struct type that holds all unique instances of the needed uniform structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_UNIFORM_STRUCTS)});
    assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_UNIFORM_NAMES_ENUM, STRUCT_OF_UNIFORM_STRUCTS), @src(), "`UNIFORM_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_UNIFORM_STRUCTS`, and each enum tag NAME in `UNIFORM_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_UNIFORM_STRUCTS`", .{});
    assert_with_reason(Types.type_is_enum(GPU_STORAGE_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_STORAGE_BUFFER_NAMES_ENUM), @src(), "type `GPU_STORAGE_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_STORAGE_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct_with_all_fields_same_type(STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES, type), @src(), "type `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES` must be a struct type that holds all concrete types of the storage buffer structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES)});
    assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_STORAGE_BUFFER_NAMES_ENUM, STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES), @src(), "`GPU_STORAGE_BUFFER_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`, and each enum tag NAME in `GPU_STORAGE_BUFFER_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`", .{});
    assert_with_reason( //
        Types.type_is_union(UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM) and
            Types.all_enum_names_match_all_object_field_names(GPU_VERTEX_STRUCT_NAMES_ENUM, UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM) and
            Types.type_is_union_with_all_fields_an_enum_type_with_all_tag_values_from_0_to_max_with_no_gaps(UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM), //
        @src(), "`UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM` must be a union type with enum tag type `GPU_VERTEX_STRUCT_NAMES_ENUM` and where each field has an enum type that represents the names of all user-provided fields in that struct and all tag values ranging from 0 to the max value with no gaps, got type `{s}`", .{@typeName(UNION_OF_VERTEX_BUFFER_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_ENUM)});
    const NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
    const NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
    const _NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
    const _NUM_UNIFORM_STRUCTS = Types.enum_defined_field_count(GPU_UNIFORM_NAMES_ENUM);
    const _NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM);
    const _NUM_VERT_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
    const _NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
    // VARIBLE PACKAGE TO PASS TO COMPTIME SUBROUTINES FOR CONVENIENCE
    const VARS = struct {
        const SELF_VARS = @This();
        linkages_defined: [_NUM_RENDER_PIPELINES]bool = @splat(false),
        uniforms_allowed_in_this_pipeline: [_NUM_RENDER_PIPELINES][_NUM_UNIFORM_STRUCTS]AllowedUniform = @splat(@splat(AllowedUniform{})),
        vert_buffers_allowed_in_this_pipeline: [_NUM_RENDER_PIPELINES][_NUM_VERT_BUFFERS]AllowedVertexBuffer = @splat(@splat(AllowedVertexBuffer{})),
        storage_buffers_allowed_in_this_pipeline: [_NUM_RENDER_PIPELINES][_NUM_STORAGE_BUFFERS]AllowedStorageBuffer = @splat(@splat(AllowedStorageBuffer{})),
        storage_textures_allowed_in_this_pipeline: [_NUM_RENDER_PIPELINES][_NUM_TEXTURES]AllowedStorageTexture = @splat(@splat(AllowedStorageTexture{})),
        sample_pairs_allowed_in_this_pipeline: [_NUM_RENDER_PIPELINES][config.SDL_GFX_CONTROLLER_MAX_SAMPLE_PAIRS]AllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM) = @splat(@splat(AllowedSamplePair{})),
        sample_pairs_allowed_in_this_pipeline_len: [_NUM_RENDER_PIPELINES]u32 = @splat(@splat(0)),
        uniform_registers_used_this_pipeline: [2][_NUM_UNIFORM_STRUCTS]RegisterWithSource = undefined,
        uniform_registers_used_this_pipeline_len: [2]u32 = @splat(0),
        uniform_registers_used_this_pipeline_max: [2]u32 = @splat(0),
        uniform_registers_used_this_pipeline_auto_count: [2]u32 = @splat(0),
        uniform_registers_used_this_pipeline_manual_count: [2]u32 = @splat(0),
        next_uniform_register_to_check: [2]u32 = @splat(0),
        storage_registers_used_this_pipeline: [2][config.SDL_GFX_CONTROLLER_MAX_STORAGE_REGISTERS]StorageRegisterWithSourceAndKind = undefined,
        storage_registers_used_this_pipeline_len: [2]u32 = @splat(0),
        storage_registers_used_this_pipeline_max: [2]u32 = @splat(0),
        storage_registers_used_this_pipeline_auto_count: [2]u32 = @splat(0),
        storage_registers_used_this_pipeline_manual_count: [2]u32 = @splat(0),
        next_storage_register_to_check: [2]u32 = @splat(0),
        vertex_registers_used_this_pipeline: [_NUM_VERT_BUFFERS]RegisterWithSource = undefined,
        vertex_registers_used_this_pipeline_len: u32 = @splat(0),
        vertex_registers_used_this_pipeline_max: u32 = @splat(0),
        vertex_registers_used_this_pipeline_auto_count: u32 = @splat(0),
        vertex_registers_used_this_pipeline_manual_count: u32 = @splat(0),
        next_vertex_register_to_check: u32 = 0,

        fn reset_for_next_pipeline(self: *SELF_VARS) void {
            self.uniform_registers_used_this_pipeline_len = @splat(0);
            self.uniform_registers_used_this_pipeline_max = @splat(0);
            self.uniform_registers_used_this_pipeline_auto_count = @splat(0);
            self.uniform_registers_used_this_pipeline_manual_count = @splat(0);
            self.next_uniform_register_to_check = @splat(0);
            self.storage_registers_used_this_pipeline_len = @splat(0);
            self.storage_registers_used_this_pipeline_max = @splat(0);
            self.storage_registers_used_this_pipeline_auto_count = @splat(0);
            self.storage_registers_used_this_pipeline_manual_count = @splat(0);
            self.next_storage_register_to_check = @splat(0);
            self.vertex_registers_used_this_pipeline_len = @splat(0);
            self.vertex_registers_used_this_pipeline_max = @splat(0);
            self.vertex_registers_used_this_pipeline_auto_count = @splat(0);
            self.vertex_registers_used_this_pipeline_manual_count = @splat(0);
            self.next_vertex_register_to_check = 0;
        }
    };
    comptime var vars = VARS{};
    // COMPTIME SUB-ROUTINES ONLY NEEDED FOR THIS BLOCK
    const SUB_ROUTINE = struct {
        const SELF_SUB_ROUTINE = @This();
        fn process_uniform_linkage(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime link: UniformRegister(GPU_UNIFORM_NAMES_ENUM), ridx: u32, stage: ShaderStage) void {
            const uni_idx = @intFromEnum(link.uniform);
            if (stage == .VERTEX) {
                assert_with_reason(v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].allowed_in_vertex == false, @src(), "uniform `{s}` was registered more than once for pipeline `{s}` vertex stage", .{ @tagName(link.uniform), @tagName(pipe) });
                v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].allowed_in_vertex = true;
            } else {
                assert_with_reason(v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].allowed_in_fragment == false, @src(), "uniform `{s}` was registered more than once for pipeline `{s}` fragment stage", .{ @tagName(link.uniform), @tagName(pipe) });
                v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].allowed_in_fragment = true;
            }
            const reg: Register = switch (stage) {
                .VERTEX => link.vertex_register.register,
                .FRAGMENT => link.fragment_register.register,
            };
            switch (reg) {
                .MANUAL => |reg_num| {
                    for (v.uniform_registers_used_this_pipeline[stage.idx()][0..v.uniform_registers_used_this_pipeline_len[stage.idx()]]) |used_register| {
                        switch (used_register.register) {
                            .MANUAL => |used_num| {
                                assert_with_reason(used_num != reg_num, @src(), "in pipeline `{s}` uniform `{s}` tried to bind to an already bound register {d}", .{ @tagName(pipe), @tagName(link.uniform), reg_num });
                            },
                            else => {},
                        }
                    }
                    v.uniform_registers_used_this_pipeline_manual_count[stage.idx()] += 1;
                    update_max(reg_num, &v.uniform_registers_used_this_pipeline_max[stage.idx()]);
                    if (reg_num == v.next_uniform_register_to_check[stage.idx()]) {
                        v.next_uniform_register_to_check[stage.idx()] += 1;
                    }
                    switch (stage) {
                        .VERTEX => v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].vertex_register = reg_num,
                        .FRAGMENT => v.uniforms_allowed_in_this_pipeline[pipe_idx][uni_idx].fragment_register = reg_num,
                    }
                },
                .AUTO => {
                    v.uniform_registers_used_this_pipeline_auto_count[stage.idx()] += 1;
                },
            }
            const reg_source = RegisterWithSource{ .register = reg, .source = @intCast(ridx) };
            v.uniform_registers_used_this_pipeline[stage.idx()][v.uniform_registers_used_this_pipeline_len[stage.idx()]] = reg_source;
            v.uniform_registers_used_this_pipeline_len[stage.idx()] += 1;
        }
        fn process_storage_register(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime reg: StorageRegisterWithSourceAndKind, comptime tag_name: []const u8, tag_idx: ?u32, ridx: u32, stage: ShaderStage, tex: ?TEXTURE_NAMES_ENUM, samp: ?SAMPLER_NAMES_ENUM) void {
            switch (reg.register) {
                .MANUAL => |reg_num| {
                    for (v.storage_registers_used_this_pipeline[stage.idx()][0..v.storage_registers_used_this_pipeline_len[stage.idx()]]) |used_register| {
                        switch (used_register.register) {
                            .MANUAL => |used_num| {
                                assert_with_reason(used_num != reg_num, @src(), "in pipeline `{s}` {s} `{s}` tried to bind to an already bound register {d}", .{ @tagName(pipe), @tagName(reg.kind), tag_name, reg_num });
                            },
                            else => {},
                        }
                    }
                    v.storage_registers_used_this_pipeline_manual_count[stage.idx()] += 1;
                    update_max(reg_num, &v.storage_registers_used_this_pipeline_max[stage.idx()]);
                    if (reg_num == v.next_storage_register_to_check[stage.idx()]) {
                        v.next_storage_register_to_check[stage.idx()] += 1;
                    }
                    switch (reg.kind) {
                        .STORAGE_BUFFER => switch (stage) {
                            .VERTEX => v.storage_buffers_allowed_in_this_pipeline[pipe_idx][tag_idx.?].vertex_register = reg_num,
                            .FRAGMENT => v.storage_buffers_allowed_in_this_pipeline[pipe_idx][tag_idx.?].fragment_register = reg_num,
                        },
                        .STORAGE_TEXTURE => switch (stage) {
                            .VERTEX => v.storage_textures_allowed_in_this_pipeline[pipe_idx][tag_idx.?].vertex_register = reg_num,
                            .FRAGMENT => v.storage_textures_allowed_in_this_pipeline[pipe_idx][tag_idx.?].fragment_register = reg_num,
                        },
                        .SAMPLED_TEXTURE => switch (stage) {
                            .VERTEX => {
                                const id = Types.combine_2_enums(samp.?, tex.?);
                                const did_find_id = Utils.mem_search_implicit(v.sample_pairs_allowed_in_this_pipeline[pipe_idx][0..v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx]].ptr, 0, @intCast(v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx]), id);
                                if (did_find_id) |found_idx| {
                                    assert_with_reason(v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].bind_in_vertex == false, @src(), "in pipeline `{s}`, sample pair `{s}` + `{s}` was bound more than once in vertex stage", .{ @tagName(pipe), @tagName(samp.?), @tagName(tex.?) });
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].bind_in_vertex == true;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].vertex_register == reg_num;
                                } else {
                                    const new_idx = v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx];
                                    v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx] += 1;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].bind_in_vertex == true;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].vertex_register == reg_num;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].combined_id == id;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].sampler == samp.?;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].texture == tex.?;
                                }
                            },
                            .FRAGMENT => {
                                const id = Types.combine_2_enums(samp.?, tex.?);
                                const did_find_id = Utils.mem_search_implicit(v.sample_pairs_allowed_in_this_pipeline[pipe_idx][0..v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx]].ptr, 0, @intCast(v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx]), id);
                                if (did_find_id) |found_idx| {
                                    assert_with_reason(v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].bind_in_fragment == false, @src(), "in pipeline `{s}`, sample pair `{s}` + `{s}` was bound more than once in fragment stage", .{ @tagName(pipe), @tagName(samp.?), @tagName(tex.?) });
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].bind_in_fragment == true;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][found_idx].fragment_register == reg_num;
                                } else {
                                    const new_idx = v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx];
                                    v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx] += 1;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].bind_in_fragment == true;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].fragment_register == reg_num;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].combined_id == id;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].sampler == samp.?;
                                    v.sample_pairs_allowed_in_this_pipeline[pipe_idx][new_idx].texture == tex.?;
                                }
                            },
                        },
                    }
                },
                .AUTO => {
                    v.storage_registers_used_this_pipeline_auto_count[stage.idx()] += 1;
                },
            }
            const reg_source = StorageRegisterWithSourceAndKind{ .register = reg, .source = @intCast(ridx), .kind = .STORAGE_BUFFER };
            v.storage_registers_used_this_pipeline[stage.idx()][v.storage_registers_used_this_pipeline_len[stage.idx()]] = reg_source;
            v.storage_registers_used_this_pipeline_len[stage.idx()] += 1;
        }
        fn process_storage_buffer_linkage(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime link: StorageBufferRegister(GPU_STORAGE_BUFFER_NAMES_ENUM), comptime ridx: u32, comptime stage: ShaderStage) void {
            const buf_idx = @intFromEnum(link.buffer);
            if (stage == .VERTEX) {
                assert_with_reason(v.storage_buffers_allowed_in_this_pipeline[pipe_idx][buf_idx].allowed_in_vertex == false, @src(), "storage buffer `{s}` was registered more than once for pipeline `{s}` vertex stage", .{ @tagName(link.buffer), @tagName(pipe) });
                v.storage_buffers_allowed_in_this_pipeline[pipe_idx][buf_idx].allowed_in_vertex = true;
            } else {
                assert_with_reason(v.storage_buffers_allowed_in_this_pipeline[pipe_idx][buf_idx].allowed_in_fragment == false, @src(), "storage buffer `{s}` was registered more than once for pipeline `{s}` fragment stage", .{ @tagName(link.buffer), @tagName(pipe) });
                v.storage_buffers_allowed_in_this_pipeline[pipe_idx][buf_idx].allowed_in_fragment = true;
            }
            const reg: Register = switch (stage) {
                .VERTEX => link.vertex_register.register,
                .FRAGMENT => link.fragment_register.register,
            };
            const reg_source = StorageRegisterWithSourceAndKind{ .register = reg, .source = @intCast(ridx), .kind = .STORAGE_BUFFER };
            SELF_SUB_ROUTINE.process_storage_register(v, pipe, pipe_idx, reg_source, @tagName(link.buffer), @intCast(@intFromEnum(link.buffer)), ridx, stage, null, null);
        }
        fn process_storage_texture_linkage(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime link: ReadOnlyStorageTextureRegister(TEXTURE_NAMES_ENUM), comptime ridx: u32, comptime stage: ShaderStage) void {
            const tex_idx = @intFromEnum(link.texture);
            if (stage == .VERTEX) {
                assert_with_reason(v.storage_textures_allowed_in_this_pipeline[pipe_idx][tex_idx].bind_in_vertex == false, @src(), "texture `{s}` was registered for read-only storage more than once for pipeline `{s}` vertex stage", .{ @tagName(link.texture), @tagName(pipe) });
                v.storage_textures_allowed_in_this_pipeline[pipe_idx][tex_idx].bind_in_vertex = true;
            } else {
                assert_with_reason(v.storage_textures_allowed_in_this_pipeline[pipe_idx][tex_idx].bind_in_fragment == false, @src(), "texture `{s}` was registered for read-only storage more than once for pipeline `{s}` fragment stage", .{ @tagName(link.texture), @tagName(pipe) });
                v.storage_textures_allowed_in_this_pipeline[pipe_idx][tex_idx].bind_in_fragment = true;
            }
            const reg: Register = switch (stage) {
                .VERTEX => link.vertex_register.register,
                .FRAGMENT => link.fragment_register.register,
            };
            const reg_source = StorageRegisterWithSourceAndKind{ .register = reg, .source = @intCast(ridx), .kind = .STORAGE_TEXTURE };
            SELF_SUB_ROUTINE.process_storage_register(v, pipe, pipe_idx, reg_source, @tagName(link.buffer), @intCast(@intFromEnum(link.buffer)), ridx, stage, null, null);
        }
        fn process_sample_pair_linkage(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime link: ReadOnlySampledTextureRegister(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM), comptime ridx: u32, comptime stage: ShaderStage) void {
            const reg: Register = switch (stage) {
                .VERTEX => link.vertex_register.register,
                .FRAGMENT => link.fragment_register.register,
            };
            const reg_source = StorageRegisterWithSourceAndKind{ .register = reg, .source = @intCast(ridx), .kind = .SAMPLED_TEXTURE };
            SELF_SUB_ROUTINE.process_storage_register(v, pipe, pipe_idx, reg_source, @tagName(link.sampler) ++ "__" ++ @tagName(link.texture), null, ridx, stage, link.texture, link.sampler);
        }
        fn provision_auto_uniform_slots(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime all_linkages: []const RenderPipelineLinkages(RENDER_PIPELINE_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM), comptime register: RegisterWithSource, stage: ShaderStage) void {
            var current_slot_to_check: u32 = v.next_uniform_register_to_check[stage.idx()];
            try_next_num: while (true) : (current_slot_to_check += 1) {
                for (v.uniform_registers_used_this_pipeline[stage.idx()][0..v.uniform_registers_used_this_pipeline_len[stage.idx()]]) |existing_register| {
                    switch (existing_register.register) {
                        .MANUAL => |used_slot| {
                            if (used_slot == current_slot_to_check) continue :try_next_num;
                        },
                        else => {},
                    }
                }
                break :try_next_num;
            }
            const source_linkage: UniformRegister(GPU_UNIFORM_NAMES_ENUM) = find: {
                for (all_linkages) |linkage| {
                    if (linkage.render_pipeline == pipe) {
                        break :find linkage.resources_to_link[register.source].UNIFORM_BUFFER;
                    }
                }
                unreachable;
            };
            switch (stage) {
                .VERTEX => v.uniforms_allowed_in_this_pipeline[pipe_idx][@intFromEnum(source_linkage.uniform)].vertex_register = current_slot_to_check,
                .FRAGMENT => v.uniforms_allowed_in_this_pipeline[pipe_idx][@intFromEnum(source_linkage.uniform)].fragment_register = current_slot_to_check,
            }
            update_max(current_slot_to_check, &v.uniform_registers_used_this_pipeline_max[stage.idx()]);
            v.next_uniform_register_to_check[stage.idx()] = current_slot_to_check + 1;
        }
        fn provision_auto_storage_slots(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime all_linkages: []const RenderPipelineLinkages(RENDER_PIPELINE_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM), comptime register: *StorageRegisterWithSourceAndKind, stage: ShaderStage) void {
            var current_slot_to_check: u32 = v.next_storage_register_to_check[stage.idx()];
            try_next_num: while (true) : (current_slot_to_check += 1) {
                for (v.storage_registers_used_this_pipeline[stage.idx()][0..v.storage_registers_used_this_pipeline_len[stage.idx()]]) |existing_register| {
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
            const source_linkage = find: {
                for (all_linkages) |linkage| {
                    if (linkage.render_pipeline == pipe) {
                        break :find linkage.resources_to_link[register.source];
                    }
                }
                unreachable;
            };
            switch (source_linkage) {
                .STORAGE_TEXTURE => |link| switch (stage) {
                    .VERTEX => v.storage_textures_allowed_in_this_pipeline[pipe_idx][@intFromEnum(link.texture)].vertex_register = current_slot_to_check,
                    .FRAGMENT => v.storage_textures_allowed_in_this_pipeline[pipe_idx][@intFromEnum(link.texture)].fragment_register = current_slot_to_check,
                },
                .STORAGE_BUFFER => |link| switch (stage) {
                    .VERTEX => v.storage_buffers_allowed_in_this_pipeline[pipe_idx][@intFromEnum(link.buffer)].vertex_register = current_slot_to_check,
                    .FRAGMENT => v.storage_buffers_allowed_in_this_pipeline[pipe_idx][@intFromEnum(link.buffer)].fragment_register = current_slot_to_check,
                },
                .SAMPLED_TEXTURE => |link| {
                    const proto_pair = AllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM){
                        .combined_id = Types.combine_2_enums(link.sampler, link.texture),
                    };
                    const found_source = Utils.mem_search_with_func(v.sample_pairs_allowed_in_this_pipeline[pipe_idx][0..v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx]].ptr, 0, v.sample_pairs_allowed_in_this_pipeline_len[pipe_idx], proto_pair, AllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).equals_id);
                    if (found_source) |source_idx| {
                        switch (stage) {
                            .VERTEX => v.sample_pairs_allowed_in_this_pipeline[pipe_idx][source_idx].vertex_register = current_slot_to_check,
                            .FRAGMENT => v.sample_pairs_allowed_in_this_pipeline[pipe_idx][source_idx].fragment_register = current_slot_to_check,
                        }
                    } else {
                        unreachable;
                    }
                },
                else => unreachable,
            }
            update_max(current_slot_to_check, &v.storage_registers_used_this_pipeline_max[stage.idx()]);
            v.next_storage_register_to_check[stage.idx()] = current_slot_to_check + 1;
        }
        inline fn provision_auto_vertex_slots(comptime v: *VARS, comptime pipe: RENDER_PIPELINE_NAMES_ENUM, comptime pipe_idx: Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), comptime all_linkages: []const RenderPipelineLinkages(RENDER_PIPELINE_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM), comptime register: RegisterWithSource) void {
            var current_slot_to_check: u32 = v.next_vertex_register_to_check;
            try_next_num: while (true) : (current_slot_to_check += 1) {
                for (v.vertex_registers_used_this_pipeline[0..v.vertex_registers_used_this_pipeline_len]) |existing_register| {
                    switch (existing_register.register) {
                        .MANUAL => |used_slot| {
                            if (used_slot == current_slot_to_check) continue :try_next_num;
                        },
                        else => {},
                    }
                }
                break :try_next_num;
            }
            const source_linkage: VertexBufferRegister(GPU_VERTEX_BUFFER_NAMES_ENUM) = find: {
                for (all_linkages) |linkage| {
                    if (linkage.render_pipeline == pipe) {
                        break :find linkage.resources_to_link[register.source].VERTEX_BUFFER;
                    }
                }
                unreachable;
            };
            v.vert_buffers_allowed_in_this_pipeline[pipe_idx][@intFromEnum(source_linkage.buffer)].register = current_slot_to_check;
            update_max(current_slot_to_check, &v.vertex_registers_used_this_pipeline_max);
            v.next_vertex_register_to_check = current_slot_to_check + 1;
        }
    };
    // COMPTIME VALIDATION / ORGANIZATION OF RESOURCE BINDINGS
    inline for (RENDER_PIPELINE_LINKAGES[0..]) |linkage| {
        const pipe_idx = @intFromEnum(linkage.render_pipeline);
        assert_with_reason(vars.linkages_defined[pipe_idx] == false, @src(), "linkage for render pipeline `{s}` was defined twice", .{@tagName(linkage.render_pipeline)});
        vars.linkages_defined[pipe_idx] = true;
        vars.reset_for_next_pipeline();
        // FIRST, RECORD ALL BINDINGS AND LOOK FOR ANY DUPLICATES
        for (linkage.resources_to_link, 0..) |resource, ridx| {
            switch (resource) {
                .UNIFORM_BUFFER => |link| {
                    if (link.vertex_register.allow) {
                        SUB_ROUTINE.process_uniform_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .VERTEX);
                    }
                    if (link.fragment_register.allow) {
                        SUB_ROUTINE.process_uniform_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .FRAGMENT);
                    }
                },
                .SAMPLED_TEXTURE => |link| {
                    if (link.vertex_register.allow) {
                        SUB_ROUTINE.process_sample_pair_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .VERTEX);
                    }
                    if (link.fragment_register.allow) {
                        SUB_ROUTINE.process_sample_pair_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .FRAGMENT);
                    }
                },
                .STORAGE_TEXTURE => |link| {
                    if (link.vertex_register.allow) {
                        SUB_ROUTINE.process_storage_texture_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .VERTEX);
                    }
                    if (link.fragment_register.allow) {
                        SUB_ROUTINE.process_storage_texture_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .FRAGMENT);
                    }
                },
                .STORAGE_BUFFER => |link| {
                    if (link.vertex_register.allow) {
                        SUB_ROUTINE.process_storage_buffer_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .VERTEX);
                    }
                    if (link.fragment_register.allow) {
                        SUB_ROUTINE.process_storage_buffer_linkage(&vars, linkage.render_pipeline, pipe_idx, link, @intCast(ridx), .FRAGMENT);
                    }
                },
                .VERTEX_BUFFER => |link| {
                    const vert_idx = @intFromEnum(link.buffer);
                    assert_with_reason(vars.vert_buffers_allowed_in_this_pipeline[pipe_idx][vert_idx].allowed == false, @src(), "vertex buffer `{s}` was registered more than once for pipeline `{s}`", .{ @tagName(link.buffer), @tagName(linkage.render_pipeline) });
                    vars.vert_buffers_allowed_in_this_pipeline[pipe_idx][vert_idx].allowed = true;
                    const reg = link.register;
                    const reg_source = RegisterWithSource{ .register = reg, .source = @intCast(ridx) };
                    switch (reg) {
                        .MANUAL => |reg_num| {
                            for (vars.vertex_registers_used_this_pipeline[0..vars.vertex_registers_used_this_pipeline_len]) |used_register| {
                                switch (used_register.register) {
                                    .MANUAL => |used_num| {
                                        assert_with_reason(used_num != reg_num, @src(), "in pipeline `{s}` vertex buffer `{s}` tried to bind to an already bound register {d}", .{ @tagName(linkage.render_pipeline), @tagName(link.buffer), reg_num });
                                    },
                                    else => {},
                                }
                            }
                            vars.vertex_registers_used_this_pipeline_manual_count += 1;
                            update_max(reg_num, &vars.vertex_registers_used_this_pipeline_max);
                            if (reg_num == vars.next_vertex_register_to_check) {
                                vars.next_vertex_register_to_check += 1;
                            }
                            vars.vert_buffers_allowed_in_this_pipeline[pipe_idx][vert_idx].register = reg_num;
                        },
                        .AUTO => {
                            vars.vertex_registers_used_this_pipeline_auto_count += 1;
                        },
                    }
                    vars.vertex_registers_used_this_pipeline[vars.vertex_registers_used_this_pipeline_len] = reg_source;
                    vars.vertex_registers_used_this_pipeline_len += 1;
                },
            }
        }
        // CHECK IF IT IS DEFINITELY IMPOSSIBLE TO COMPILE (MAX REGISTER FOR A GROUP IS >= TOTAL NUM REGISTERS FOR THAT GROUP = AN EMPTY REGISTER IS INEVITABLE)
        assert_with_reason(vars.uniform_registers_used_this_pipeline_len[0] > vars.uniform_registers_used_this_pipeline_max[0], @src(), "uniform registers for render pipeline `{s}` vertex stage total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.uniform_registers_used_this_pipeline_len[0], vars.uniform_registers_used_this_pipeline_max[0] });
        assert_with_reason(vars.uniform_registers_used_this_pipeline_len[1] > vars.uniform_registers_used_this_pipeline_max[1], @src(), "uniform registers for render pipeline `{s}` fragment stage total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.uniform_registers_used_this_pipeline_len[1], vars.uniform_registers_used_this_pipeline_max[1] });
        assert_with_reason(vars.storage_registers_used_this_pipeline_len[0] > vars.storage_registers_used_this_pipeline_max[0], @src(), "storage registers for render pipeline `{s}` vertex stage total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline_len[0], vars.storage_registers_used_this_pipeline_max[0] });
        assert_with_reason(vars.storage_registers_used_this_pipeline_len[1] > vars.storage_registers_used_this_pipeline_max[1], @src(), "storage registers for render pipeline `{s}` fragment stage total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline_len[1], vars.storage_registers_used_this_pipeline_max[1] });
        assert_with_reason(vars.vertex_registers_used_this_pipeline_len > vars.vertex_registers_used_this_pipeline_max, @src(), "vertex buffer registers for render pipeline `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.vertex_registers_used_this_pipeline_len, vars.vertex_registers_used_this_pipeline_max });
        // SORT STORAGE REGISTERS SO UNUSED SLOTS ARE GIVEN OUT IN THE ORDER: SAMPLE_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_pipeline[0][0..vars.storage_registers_used_this_pipeline_len[0]], StorageRegisterWithSourceAndKind.greater_than);
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_pipeline[1][0..vars.storage_registers_used_this_pipeline_len[1]], StorageRegisterWithSourceAndKind.greater_than);
        // NEXT, GO THROUGH AND RESOLVE ALL 'AUTO' BINDINGS TO FILL UNUSED SLOTS, THEN CHECK IF PROVISIONING RESULTED IN TOTAL == (MAX + 1),
        // WITH STORAGE SLOTS IN CORRECT ORDER (SAMPLES_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS)
        const all_linkages: []const RenderPipelineLinkages(RENDER_PIPELINE_NAMES_ENUM, GPU_UNIFORM_NAMES_ENUM, GPU_STORAGE_BUFFER_NAMES_ENUM, TEXTURE_NAMES_ENUM) = RENDER_PIPELINE_LINKAGES[0..];
        for (vars.uniform_registers_used_this_pipeline[0][0..vars.uniform_registers_used_this_pipeline_len[0]]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, linkage.render_pipeline, pipe_idx, all_linkages, uni_register, .VERTEX);
        }
        assert_with_reason(vars.uniform_registers_used_this_pipeline_len[0] == vars.uniform_registers_used_this_pipeline_max[0] + 1, @src(), "uniform registers for render pipeline `{s}` vertex stage total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.uniform_registers_used_this_pipeline_len[0], vars.uniform_registers_used_this_pipeline_max[0] });
        for (vars.uniform_registers_used_this_pipeline[1][0..vars.uniform_registers_used_this_pipeline_len[1]]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, linkage.render_pipeline, pipe_idx, all_linkages, uni_register, .FRAGMENT);
        }
        assert_with_reason(vars.uniform_registers_used_this_pipeline_len[1] == vars.uniform_registers_used_this_pipeline_max[1] + 1, @src(), "uniform registers for render pipeline `{s}` fragment stage total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.uniform_registers_used_this_pipeline_len[1], vars.uniform_registers_used_this_pipeline_max[1] });
        for (vars.storage_registers_used_this_pipeline[0][0..vars.storage_registers_used_this_pipeline_len[0]]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, linkage.render_pipeline, pipe_idx, all_linkages, storage_register, .VERTEX);
        }
        assert_with_reason(vars.storage_registers_used_this_pipeline_len[0] == vars.storage_registers_used_this_pipeline_max[0] + 1, @src(), "storage registers for render pipeline `{s}` vertex stage total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline_len[0], vars.storage_registers_used_this_pipeline_max[0] });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_pipeline[0][0..vars.storage_registers_used_this_pipeline_len[0]], StorageRegisterWithSourceAndKind.greater_than_only_register);
        assert_with_reason(Utils.mem_is_sorted_with_func(vars.storage_registers_used_this_pipeline[0][0..vars.storage_registers_used_this_pipeline_len[0]].ptr, 0, vars.storage_registers_used_this_pipeline_len[0], StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in pipeline `{s}` vertex stage are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline[0][0..vars.storage_registers_used_this_pipeline_len[0]] });
        for (vars.storage_registers_used_this_pipeline[1][0..vars.storage_registers_used_this_pipeline_len[1]]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, linkage.render_pipeline, pipe_idx, all_linkages, storage_register, .VERTEX);
        }
        assert_with_reason(vars.storage_registers_used_this_pipeline_len[1] == vars.storage_registers_used_this_pipeline_max[1] + 1, @src(), "storage registers for render pipeline `{s}` fragment stage total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline_len[1], vars.storage_registers_used_this_pipeline_max[1] });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_pipeline[1][0..vars.storage_registers_used_this_pipeline_len[1]], StorageRegisterWithSourceAndKind.greater_than_only_register);
        assert_with_reason(Utils.mem_is_sorted_with_func(vars.storage_registers_used_this_pipeline[1][0..vars.storage_registers_used_this_pipeline_len[1]].ptr, 0, vars.storage_registers_used_this_pipeline_len[1], StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in pipeline `{s}` fragment stage are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.render_pipeline), vars.storage_registers_used_this_pipeline[1][0..vars.storage_registers_used_this_pipeline_len[1]] });
        for (vars.vertex_registers_used_this_pipeline[0..vars.vertex_registers_used_this_pipeline_len]) |vertex_register| {
            if (vertex_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_vertex_slots(&vars, linkage.render_pipeline, pipe_idx, all_linkages, vertex_register);
        }
        assert_with_reason(vars.vertex_registers_used_this_pipeline_len == vars.vertex_registers_used_this_pipeline_max + 1, @src(), "vertex buffer registers for render pipeline `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.render_pipeline), vars.vertex_registers_used_this_pipeline_len, vars.vertex_registers_used_this_pipeline_max });
    }
    const uniform_allowed_in_this_pipeline_const = vars.uniforms_allowed_in_this_pipeline;
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
        pub const NUM_GPU_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
        pub const NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);
        pub const ALLOWED_UNIFORM_LINKAGES = uniform_allowed_in_this_pipeline_const;

        pub const WindowName = WINDOW_NAMES_ENUM;
        pub const RenderPipelineName = RENDER_PIPELINE_NAMES_ENUM;
        pub const TextureName = TEXTURE_NAMES_ENUM;
        pub const TransferBufferName = TRANSFER_BUFFER_NAMES_ENUM;
        pub const GpuBufferName = GPU_VERTEX_BUFFER_NAMES_ENUM;
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
