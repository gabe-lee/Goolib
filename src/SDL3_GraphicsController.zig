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
const Common = Root.CommonTypes;

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

const ShaderContract = SDL3.ShaderContract;
const StorageStructField = ShaderContract.StorageStructField;
const StorageStruct = ShaderContract.StorageStruct;
const GPUType = ShaderContract.GPUType;

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

pub const PipelineAllowedResource = struct {
    vertex_register: u32 = 0,
    fragment_register: u32 = 0,
    allowed_in_vertex: bool = false,
    allowed_in_fragment: bool = false,
};
pub const AllowedResource = struct {
    register: u32 = 0,
    allowed: bool = false,
};

pub fn PipelineAllowedUniform(comptime UNIFORM_NAMES_ENUM: type) type {
    return struct {
        uniform: UNIFORM_NAMES_ENUM,
        vertex_register: u32,
        fragmant_register: u32,
        allowed_in_vertex:bool,
        allowed_in_fragment:bool,
    };
}
pub fn ShaderAllowedUniform(comptime UNIFORM_NAMES_ENUM: type) type {
    return struct {
        uniform: UNIFORM_NAMES_ENUM,
        register: u32,
    };
}
pub fn PipelineAllowedStorageBuffer(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        buffer: STORAGE_BUFFER_NAMES_ENUM,
        vertex_register: u32,
        fragmant_register: u32,
        allowed_in_vertex:bool,
        allowed_in_fragment:bool,
    };
}
pub fn ShaderAllowedStorageBuffer(comptime STORAGE_BUFFER_NAMES_ENUM: type) type {
    return struct {
        buffer: STORAGE_BUFFER_NAMES_ENUM,
        register: u32,
    };
}
pub fn PipelineAllowedStorageTexture(comptime STORAGE_TEXTURE_NAMES_ENUM: type) type {
    return struct {
        texture: STORAGE_TEXTURE_NAMES_ENUM,
        vertex_register: u32,
        fragmant_register: u32,
        allowed_in_vertex:bool,
        allowed_in_fragment:bool,
    };
}
pub fn ShaderAllowedStorageTexture(comptime STORAGE_TEXTURE_NAMES_ENUM: type) type {
    return struct {
        texture: STORAGE_TEXTURE_NAMES_ENUM,
        register: u32,
    };
}

pub fn PipelineAllowedSamplePair(comptime TEXTURE_NAMES_ENUM: type, comptime SAMPLER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        combined_id: Types.Combined2EnumInt(SAMPLER_NAMES_ENUM, TEXTURE_NAMES_ENUM).combined_type = 0,
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

pub fn RenderPipelineVertexFieldMap(comptime VERTEX_BUFFER_NAMES: type, comptime SHADER_STRUCT_NAMES: type) type {
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
        assert_with_reason(Types.type_is_enum(desc.fields) and Types.all_enum_values_start_from_zero_with_no_gaps(desc.fields), src, "vertex buffer `{s}` type of `fields` must be an enum type with all tag values from 0 to max with no gaps, got type `{s}`", .{ name, @typeName(desc.fields) });
        const EINFO = @typeInfo(desc.fields).@"enum";
        inline for (EINFO.fields) |field| {
            assert_with_reason(@hasDecl(desc.fields_info, field.name) and @TypeOf(@field(desc.fields_info, field.name)) == VertexBufferFieldInfo, src, "vertex buffer `{s}` `fields_info` MUST have a declaration of `pub const {s}: VertexBufferFieldInfo = .{...}`, but it was missing or the wrong type", .{ name, field.name });
            const info: VertexBufferFieldInfo = @field(desc.fields_info, field.name);
            assert_with_reason(std.mem.isAligned(@intCast(info.offset), @alignOf(info.field_type)), src, "vertex buffer `{s}` field `{s}` has an offset that is not aligned to its type alignment ({d} not aligned to {d})", .{ name, field.name, info.offset, @alignOf(info.field_type) });
            assert_with_reason(@sizeOf(info.field_type) + info.offset <= INT_SIZE_32, src, "vertex buffer `{s}` field `{s}` has a size and offset that extends beyond the size of the buffer element type", .{ name, field.name });
            const field_bytes = Utils.first_n_bytes_set_inline(INT, @sizeOf(info.field_type)) << @intCast(info.offset);
            const after_or = bytes_taken | field_bytes;
            const after_xor = bytes_taken ^ field_bytes;
            assert_with_reason(after_or == after_xor, src, "vertex buffer `{s}` field `{s}` has a size and offset that overlaps with another field from byte {d} to byte {d}", .{ name, @ctz(bytes_taken & field_bytes), INT_SIZE - @clz(bytes_taken & field_bytes) });
            assert_with_reason(info.gpu_format != .INVALID, src, "vertex buffer `{s}` field `{s}` has an `.INVALID` gpu format", .{ name, field.name });
            assert_with_reason(info.gpu_format.size() == @sizeOf(info.field_type), src, "vertex buffer `{s}` field `{s}` has a gpu format (`{s}` = {d}) that is not the same size as its cpu type (`{s}` = {d})", .{ name, field.name, @tagName(info.gpu_format), info.gpu_format.size(), @typeName(info.field_type), @sizeOf(info.field_type) });
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
        assert_with_reason(Types.type_is_enum(desc.fields) and Types.all_enum_values_start_from_zero_with_no_gaps(desc.fields), src, "shader struct `{s}` type of `fields` must be an enum type with all tag values from 0 to max with no gaps, got type `{s}`", .{ name, @typeName(desc.fields) });
        const EINFO = @typeInfo(desc.fields).@"enum";
        comptime var locations_init: [EINFO.fields.len]bool = @splat(false);
        comptime var depth_was_init: bool = false;
        comptime var out: NumLocationsAndDepthTarget = .{};
        inline for (EINFO.fields) |field| {
            assert_with_reason(@hasDecl(desc.fields_info, field.name) and @TypeOf(@field(desc.fields_info, field.name)) == ShaderStructFieldInfo, src, "shader struct `{s}` `fields_info` MUST have a declaration of `pub const {s}: ShaderStructFieldInfo = .{...}`, but it was missing or the wrong type", .{ name, field.name });
            const info: ShaderStructFieldInfo = @field(desc.fields_info, field.name);
            assert_with_reason(info.gpu_format != .INVALID, src, "shader struct `{s}` field `{s}` has an `.INVALID` gpu format", .{ name, field.name });
            assert_with_reason(info.gpu_format.size() == @sizeOf(info.cpu_type), src, "shader struct `{s}` field `{s}` has a gpu format size (`{s}` = {d}) that is not the same size as its cpu type (`{s}` = {d})", .{ name, field.name, @tagName(info.gpu_format), info.gpu_format.size(), @typeName(info.cpu_type), @sizeOf(info.cpu_type) });
            switch (info.location_kind) {
                .USER_INPUT_OUTPUT => {
                    assert_with_reason(desc.struct_usage != .FRAGMENT_OUT, src, "shader struct `{s}` has usage mode `.FRAGMENT_OUT`, but field `{s}` has a `.USER_INPUT_OUTPUT` location. Only `.COLOR_TARGET` or `.DEPTH_TARGET` locations are allowed for `.FRAGMENT_OUT` structs (but you can write non-color data to one of the color targets if needed)", .{ name, field.name });
                    assert_with_reason(info.location < EINFO.fields.len, src, "shader struct `{s}` field `{s}` has a location greater than or equal to the number of fields on the struct ({d} >= {d}): All locations must start from 0 and increase with no gaps", .{ name, field.name, info.location, EINFO.fields.len });
                    assert_with_reason(locations_init[info.location] == false, src, "shader struct `{s}` field `{s}` has a duplicate location {d}", .{ name, field.name, info.location });
                    locations_init[info.location] = true;
                    out.num_locations += 1;
                },
                .COLOR_TARGET, .DEPTH_TARGET => {
                    assert_with_reason(desc.struct_usage == .FRAGMENT_OUT, src, "shader struct `{s}` has usage mode `.{s}`, but field `{s}` has a `.{s}` location. Only `.USER_INPUT_OUTPUT` locations are allowed for `.{s}` structs", .{ name, @tagName(desc.struct_usage), field.name, @tagName(info.location_kind), @tagName(desc.struct_usage) });
                    switch (info.location_kind) {
                        .COLOR_TARGET => {
                            assert_with_reason(info.location < EINFO.fields.len, src, "shader struct `{s}` field `{s}` has a color target greater than or equal to the number of fields on the struct ({d} >= {d}): All color targets must start from 0 and increase with no gaps", .{ name, field.name, info.location, EINFO.fields.len });
                            assert_with_reason(info.location < 8, src, "shader struct `{s}` field `{s}` has a color target greater than or equal to 8: only 8 simultaneous color targets are supported (locations 0-7)", .{ name, field.name });
                            assert_with_reason(locations_init[info.location] == false, src, "shader struct `{s}` field `{s}` has a duplicate color target {d}", .{ name, field.name, info.location });
                            locations_init[info.location] = true;
                            out.num_locations += 1;
                        },
                        .DEPTH_TARGET => {
                            assert_with_reason(depth_was_init == false, src, "shader struct `{s}` field `{s}` has a duplicate depth target field: only one depth target is supported", .{ name, field.name });
                            assert_with_reason(locations_init[EINFO.fields.len - 1] == false, src, "shader struct `{s}` field `{s}` has a gap somewhere in its color target locations. All color targets must start at 0 and increase with no gaps.", .{ name, field.name });
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
        dimension_type: SDL3.GPU_TextureType = ._2D,
        pixel_format: SDL3.GPU_TextureFormat = .R8G8B8A8_UNORM_SRGB,
        layers_or_depth: u32 = 1,
        width: u32,
        height: u32,
        mipmap_levels: u32 = 0,
        sample_count: SDL3.GPU_SampleCount = ._1,
        props: SDL3.PropertiesID = .{},

        pub fn define_texture_2D(name: TEXTURE_NAMES_ENUM, width: u32, height: u32, layers: u32, mipmap_levels: u32, sample_count: SDL3.GPU_SampleCount) Self {
            return Self{
                .texture = name,
                .width = width,
                .height = height,
                .layers_or_depth = layers,
                .mipmap_levels = mipmap_levels,
                .sample_count = sample_count,
                .dimension_type = if (layers > 1) SDL3.GPU_TextureType._2D_ARRAY else SDL3.GPU_TextureType._2D,
            };
        }
    };
}

pub fn VertexBufferBinding(comptime VERTEX_BUFFER_NAMES_ENUM: type) type {
    return struct {
        const Self = @This();

        buffer: VERTEX_BUFFER_NAMES_ENUM,
        binding: SDL3.GPU_VertexBufferDescription,
    };
}

pub const FieldLocationKind = enum(u8) {
    USER_INPUT_OUTPUT,
    COLOR_TARGET,
    DEPTH_TARGET,
};

pub const ValidationSettings = struct {
    mismatched_cpu_types: ValidateMode = .PANIC,
    mismatched_gpu_formats: ValidateMode = .PANIC,
    vertex_buffer_slot_gaps: ValidateMode = .PANIC,
    depth_stencil_zero_bits: ValidateMode = .PANIC,
    depth_texture_non_depth_format: ValidateMode = .PANIC,
    depth_texture_non_stencil_format: ValidateMode = .PANIC,
    color_texture_non_color_format: ValidateMode = .PANIC,
    color_targets_missing: ValidateMode = .PANIC,
};

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
    /// An enum with tag names for each unique transfer buffer used in application
    ///
    /// Transfer buffers are used to move data from the Application to the GPU
    comptime TRANSFER_BUFFER_NAMES_ENUM: type,
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
    /// This should have each unique storage struct *TYPE* as an individial field
    /// (not an instance of the type, as instances will be read/written from a buffer)
    ///
    /// Each field name must exactly match a tag name in `GPU_STORAGE_BUFFER_NAMES`
    comptime STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES: type,
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
    const _VertexBufferBinding = VertexBufferBinding(GPU_VERTEX_BUFFER_NAMES_ENUM);
    const _PipelineAllowedUniform = PipelineAllowedUniform(GPU_UNIFORM_NAMES_ENUM);
    const _PipelineAllowedSamplePair = PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _PipelineAllowedStorageBuffer = PipelineAllowedStorageBuffer(GPU_STORAGE_BUFFER_NAMES_ENUM);
    const _PipelineAllowedStorageTexture = PipelineAllowedStorageTexture(TEXTURE_NAMES_ENUM);
    const _ShaderAllowedUniform = ShaderAllowedUniform(GPU_UNIFORM_NAMES_ENUM);
    const _ShaderAllowedSamplePair = ShaderAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM);
    const _ShaderAllowedStorageBuffer = ShaderAllowedStorageBuffer(GPU_STORAGE_BUFFER_NAMES_ENUM);
    const _ShaderAllowedStorageTexture = ShaderAllowedStorageTexture(TEXTURE_NAMES_ENUM);
    const vertex_linkages: []const _VertexShaderDefinition = VERTEX_SHADER_DEFINITIONS[0..];
    const fragment_linkages: []const _FragmentShaderDefinition = FRAGMENT_SHADER_DEFINITIONS[0..];
    // VALIDATE SIMPLE ENUMS
    assert_with_reason(Types.type_is_enum(WINDOW_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(WINDOW_NAMES_ENUM), @src(), "type `WINDOW_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(WINDOW_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(VERTEX_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(VERTEX_SHADER_NAMES_ENUM), @src(), "type `VERTEX_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(VERTEX_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(FRAGMENT_SHADER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(FRAGMENT_SHADER_NAMES_ENUM), @src(), "type `FRAGMENT_SHADER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(FRAGMENT_SHADER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(RENDER_PIPELINE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(RENDER_PIPELINE_NAMES_ENUM), @src(), "type `RENDER_PIPELINE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(RENDER_PIPELINE_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(SAMPLER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(SAMPLER_NAMES_ENUM), @src(), "type `SAMPLER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(SAMPLER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_enum(TRANSFER_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TRANSFER_BUFFER_NAMES_ENUM), @src(), "type `TRANSFER_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TRANSFER_BUFFER_NAMES_ENUM)});
    // const _NUM_WINDOWS = Types.enum_defined_field_count(WINDOW_NAMES_ENUM);
    const _NUM_VERTEX_SHADERS = Types.enum_defined_field_count(VERTEX_SHADER_NAMES_ENUM);
    const _NUM_FRAGMENT_SHADERS = Types.enum_defined_field_count(FRAGMENT_SHADER_NAMES_ENUM);
    const _NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
    // const _NUM_TRANSFER_BUFFERS = Types.enum_defined_field_count(TRANSFER_BUFFER_NAMES_ENUM);
    // VALIDATE TEXTURES
    assert_with_reason(Types.type_is_enum(TEXTURE_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(TEXTURE_NAMES_ENUM), @src(), "type `TEXTURE_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(TEXTURE_NAMES_ENUM)});
    const _NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
    comptime var ordered_texture_definitions: [_NUM_TEXTURES]_TextureDefinition = undefined;
    comptime var textures_defined: [_NUM_TEXTURES]bool = @splat(false);
    inline for (TEXTURE_DEFINITIONS) |texture_def| {
        const tex_id = @intFromEnum(texture_def.texture);
        assert_with_reason(textures_defined[tex_id] == false, @src(), "texture `{s}` was defined more than once", .{@tagName(texture_def.texture)});
        textures_defined[tex_id] = true;
        assert_with_reason(texture_def.pixel_format != .INVALID, @src(), "texture `{s}` had an `.INVALID` pixel format", .{@tagName(texture_def.texture)});
        assert_with_reason(texture_def.width != 0 and texture_def.height != 0, @src(), "texture `{s}` had zero size (WxH = {d}x{d})", .{ @tagName(texture_def.texture), texture_def.width, texture_def.height });
        assert_with_reason(texture_def.layers_or_depth != 0, @src(), "texture `{s}` had zero size (layers/depth = 0)", .{@tagName(texture_def.texture)});
        ordered_texture_definitions[tex_id] = texture_def;
    }
    const ordered_texture_definitions_const = ordered_texture_definitions;
    // VALIDATE VERTEX BUFFERS
    assert_with_reason(Types.type_is_enum(GPU_VERTEX_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_VERTEX_BUFFER_NAMES_ENUM), @src(), "type `GPU_VERTEX_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_VERTEX_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct_with_all_decls_same_type(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, VertexBufferDescription), @src(), "type `STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS` must be a struct type that holds all `GPU_VERTEX_BUFFER_NAMES_ENUM` names as const declarations of type `ShaderStructDescription`, got type `{s}`", .{@typeName(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS)});
    assert_with_reason(Types.all_enum_names_match_an_object_decl_name(GPU_VERTEX_BUFFER_NAMES_ENUM, STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS), @src(), "each tag in `GPU_VERTEX_BUFFER_NAMES_ENUM` must have a matching pub const declaration with the same name in `STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS`", .{});
    const _NUM_VERT_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
    const ordered_vertex_buffer_descriptions: [_NUM_VERT_BUFFERS]VertexBufferDescription = undefined;
    inline for (@typeInfo(GPU_VERTEX_BUFFER_NAMES_ENUM).@"enum".fields) |vert_buffer| {
        const desc: VertexBufferDescription = @field(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, vert_buffer.name);
        desc.assert_valid(vert_buffer.name, @src());
        ordered_vertex_buffer_descriptions[vert_buffer.value] = desc;
    }
    const ordered_vertex_buffer_descriptions_const = ordered_vertex_buffer_descriptions;
    // VALIDATE SHADER STRUCTS
    assert_with_reason(Types.type_is_enum(GPU_SHADER_STRUCT_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_SHADER_STRUCT_NAMES_ENUM), @src(), "type `GPU_SHADER_STRUCT_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_SHADER_STRUCT_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct_with_all_decls_same_type(STRUCT_OF_SHADER_STRUCT_DEFINITIONS, ShaderStructDescription), @src(), "type `STRUCT_OF_SHADER_STRUCT_DEFINITIONS` must be a struct type that holds all `GPU_SHADER_STRUCT_NAMES_ENUM` names as const declarations of type `ShaderStructDescription`, got type `{s}`", .{@typeName(STRUCT_OF_SHADER_STRUCT_DEFINITIONS)});
    assert_with_reason(Types.all_enum_names_match_an_object_decl_name(GPU_SHADER_STRUCT_NAMES_ENUM, STRUCT_OF_SHADER_STRUCT_DEFINITIONS), @src(), "each tag in `GPU_SHADER_STRUCT_NAMES_ENUM` must have a matching pub const declaration with the same name in `STRUCT_OF_SHADER_STRUCT_DEFINITIONS`", .{});

    const _NUM_SHADER_STRUCTS = Types.enum_defined_field_count(GPU_SHADER_STRUCT_NAMES_ENUM);
    comptime var ordered_shader_struct_locations_quick_info: [_NUM_SHADER_STRUCTS]NumLocationsAndDepthTarget = @splat(.{});
    inline for (@typeInfo(GPU_SHADER_STRUCT_NAMES_ENUM).@"enum".fields) |shader_struct| {
        const desc: ShaderStructDescription = @field(STRUCT_OF_SHADER_STRUCT_DEFINITIONS, shader_struct.name);
        const locs = desc.assert_valid(shader_struct.name, @src());
        ordered_shader_struct_locations_quick_info[shader_struct.value] = locs;
    }
    const ordered_shader_struct_locations_quick_info_const = ordered_shader_struct_locations_quick_info;
    // VAIDATE UNIFORMS
    assert_with_reason(Types.type_is_enum(GPU_UNIFORM_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_UNIFORM_NAMES_ENUM), @src(), "type `GPU_UNIFORM_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_UNIFORM_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct(STRUCT_OF_UNIFORM_STRUCTS), @src(), "type `STRUCT_OF_UNIFORM_STRUCTS` must be a struct type that holds all unique instances of the needed uniform structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_UNIFORM_STRUCTS)});
    assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_UNIFORM_NAMES_ENUM, STRUCT_OF_UNIFORM_STRUCTS), @src(), "`GPU_UNIFORM_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_UNIFORM_STRUCTS`, and each enum tag NAME in `GPU_UNIFORM_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_UNIFORM_STRUCTS`", .{});
    const _NUM_UNIFORM_STRUCTS = Types.enum_defined_field_count(GPU_UNIFORM_NAMES_ENUM);
    // VALIDATE STORAGE BUFFERS
    assert_with_reason(Types.type_is_enum(GPU_STORAGE_BUFFER_NAMES_ENUM) and Types.all_enum_values_start_from_zero_with_no_gaps(GPU_STORAGE_BUFFER_NAMES_ENUM), @src(), "type `GPU_STORAGE_BUFFER_NAMES_ENUM` MUST be an enum type with tag values starting at zero and no gaps between 0 and the max tag value, got type `{s}`", .{@typeName(GPU_STORAGE_BUFFER_NAMES_ENUM)});
    assert_with_reason(Types.type_is_struct_with_all_fields_same_type(STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES, type), @src(), "type `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES` must be a struct type that holds all concrete types of the storage buffer structs as fields, got type `{s}`", .{@typeName(STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES)});
    assert_with_reason(Types.all_enum_names_match_all_object_field_names(GPU_STORAGE_BUFFER_NAMES_ENUM, STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES), @src(), "`GPU_STORAGE_BUFFER_NAMES_ENUM` must have the same number of tags as the number of fields in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`, and each enum tag NAME in `GPU_STORAGE_BUFFER_NAMES_ENUM` must EXACTLY match a field in `STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES`", .{});
    const _NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM);
    // VALIDATE SHADER REGISTERS STARTING HERE
    // ORGANISE PIPELINE TO SHADERS MAP
    comptime var ordered_pipeline_definitions: [_NUM_RENDER_PIPELINES]_RenderPipelineDefinition = undefined;
    comptime var pipeline_definitions_mapped: [_NUM_RENDER_PIPELINES]bool = @splat(false);
    inline for (RENDER_PIPELINE_DEFINITIONS) |def| {
        const pipe_idx = @intFromEnum(def.pipeline);
        assert_with_reason(pipeline_definitions_mapped[pipe_idx] == false, @src(), "render pipeline `{s}` was already mapped to its shaders once, attmepted a second time", .{@tagName(def.pipeline)});
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
        // vert_buffers_allowed_in_vertex_shaders: [NUM_VERTEX_SHADERS][_NUM_VERT_BUFFERS]AllowedResource = @splat(@splat(AllowedResource{})),
        // vert_buffers_allowed_in_vertex_shaders_len: [NUM_VERTEX_SHADERS]u32 = 0,
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
        // vertex_registers_used_this_pipeline: [_NUM_VERT_BUFFERS]RegisterWithSource = undefined,
        // vertex_registers_used_this_pipeline_len: u32 = 0,
        // vertex_registers_used_this_pipeline_max: u32 = 0,
        // vertex_registers_used_this_pipeline_auto_count: u32 = 0,
        // vertex_registers_used_this_pipeline_manual_count: u32 = 0,
        // next_vertex_register_to_check: u32 = 0,

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
            // self.vertex_registers_used_this_pipeline_len = 0;
            // self.vertex_registers_used_this_pipeline_max = 0;
            // self.vertex_registers_used_this_pipeline_auto_count = 0;
            // self.vertex_registers_used_this_pipeline_manual_count = 0;
            // self.next_vertex_register_to_check = 0;
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
                    assert_with_reason(v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.uniform), shader_name });
                    v.uniforms_allowed_in_vertex_shaders[shader_idx][uni_idx].allowed = true;
                },
                .FRAGMENT => {
                    assert_with_reason(v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed == false, @src(), "uniform `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.uniform), shader_name });
                    v.uniforms_allowed_in_fragment_shaders[shader_idx][uni_idx].allowed = true;
                },
            }
            switch (link.register) {
                .MANUAL => |reg_num| {
                    for (v.uniform_registers_used_this_shader[0..v.uniform_registers_used_this_shader_len]) |used_register| {
                        switch (used_register.register) {
                            .MANUAL => |used_num| {
                                assert_with_reason(used_num != reg_num, @src(), "in {s} shader `{s}` uniform `{s}` tried to bind to an already bound register {d}", .{ @tagName(stage), shader_name, @tagName(link.uniform), reg_num });
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
                                assert_with_reason(used_num != reg_num, @src(), "in {s} shader `{s}` {s} `{s}` tried to bind to an already bound register {d}", .{ @tagName(stage), shader_name, @tagName(reg.kind), tag_name, reg_num });
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
                                    assert_with_reason(v.sample_pairs_allowed_in_vertex_shaders[shader_idx][found_idx].allowed == false, @src(), "in vertex shader `{s}`, sample pair `{s}` + `{s}` was bound more than once", .{ shader_name, @tagName(samp.?), @tagName(tex.?) });
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
                                    assert_with_reason(v.sample_pairs_allowed_in_fragment_shaders[shader_idx][found_idx].allowed == false, @src(), "in fragment shader `{s}`, sample pair `{s}` + `{s}` was bound more than once", .{ shader_name, @tagName(samp.?), @tagName(tex.?) });
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
                assert_with_reason(v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.buffer), shader_name });
                v.storage_buffers_allowed_in_vertex_shaders[shader_idx][buf_idx].allowed = true;
            } else {
                assert_with_reason(v.storage_buffers_allowed_in_fragment_shaders[shader_idx][buf_idx].allowed == false, @src(), "storage buffer `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.buffer), shader_name });
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
                assert_with_reason(v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for vertex shader `{s}`", .{ @tagName(link.texture), shader_name });
                v.storage_textures_allowed_in_vertex_shaders[shader_idx][tex_idx].allowed = true;
            } else {
                assert_with_reason(v.storage_textures_allowed_in_fragment_shaders[shader_idx][tex_idx].allowed == false, @src(), "storage texture `{s}` was registered more than once for fragment shader `{s}`", .{ @tagName(link.texture), shader_name });
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
                            const proto_pair = PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM){
                                .combined_id = Types.combine_2_enums(link.sampler, link.texture),
                            };
                            const found_source = Utils.mem_search_with_func(@ptrCast(&v.sample_pairs_allowed_in_vertex_shaders[shader_idx]), 0, v.sample_pairs_allowed_in_vertex_shaders_len[shader_idx], proto_pair, PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).equals_id);
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
                            const proto_pair = PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM){
                                .combined_id = Types.combine_2_enums(link.sampler, link.texture),
                            };
                            const found_source = Utils.mem_search_with_func(@ptrCast(&v.sample_pairs_allowed_in_fragment_shaders[shader_idx]), 0, v.sample_pairs_allowed_in_fragment_shaders_len[shader_idx], proto_pair, PipelineAllowedSamplePair(TEXTURE_NAMES_ENUM, SAMPLER_NAMES_ENUM).equals_id);
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
        assert_with_reason(vertex_linkages_defined[vert_idx] == false, @src(), "linkage for vertex shader `{s}` was defined twice", .{@tagName(linkage.vertex_shader)});
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
        assert_with_reason(vars.uniform_registers_used_this_shader_len > vars.uniform_registers_used_this_shader_max, @src(), "uniform registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        assert_with_reason(vars.storage_registers_used_this_shader_len > vars.storage_registers_used_this_shader_max, @src(), "storage registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        // SORT STORAGE REGISTERS SO UNUSED SLOTS ARE GIVEN OUT IN THE ORDER: SAMPLE_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than);
        // NEXT, GO THROUGH AND RESOLVE ALL 'AUTO' BINDINGS TO FILL UNUSED SLOTS, THEN CHECK IF PROVISIONING RESULTED IN TOTAL == (MAX + 1),
        // WITH STORAGE SLOTS IN CORRECT ORDER (SAMPLED_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS)
        for (vars.uniform_registers_used_this_shader[0..vars.uniform_registers_used_this_shader_len]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, @intCast(vert_idx), vertex_linkages, fragment_linkages, uni_register, .VERTEX);
        }
        assert_with_reason(vars.uniform_registers_used_this_shader_len == vars.uniform_registers_used_this_shader_max + 1, @src(), "uniform registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        for (vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, @intCast(vert_idx), vertex_linkages, fragment_linkages, storage_register, .VERTEX);
        }
        assert_with_reason(vars.storage_registers_used_this_shader_len == vars.storage_registers_used_this_shader_max + 1, @src(), "storage registers for vertex shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than_only_register);
        assert_with_reason(Utils.mem_is_sorted_with_func(@ptrCast(&vars.storage_registers_used_this_shader), 0, vars.storage_registers_used_this_shader_len, StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in vertex shader `{s}` are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.vertex_shader), vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len] });
    }
    const ordered_vertex_shader_definitions_const = ordered_vertex_shader_definitions;
    // COMPTIME VALIDATION / ORGANIZATION OF FRAGMENT SHADER BINDINGS
    comptime var fragment_linkages_defined: [_NUM_FRAGMENT_SHADERS]bool = @splat(false);
    comptime var ordered_fragment_shader_definitions: [_NUM_VERTEX_SHADERS]_FragmentShaderDefinition = undefined;
    inline for (FRAGMENT_SHADER_DEFINITIONS[0..]) |linkage| {
        const frag_idx = @intFromEnum(linkage.fragment_shader);
        assert_with_reason(fragment_linkages_defined[frag_idx] == false, @src(), "linkage for fragment shader `{s}` was defined twice", .{@tagName(linkage.fragment_shader)});
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
        assert_with_reason(vars.uniform_registers_used_this_shader_len > vars.uniform_registers_used_this_shader_max, @src(), "uniform registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        assert_with_reason(vars.storage_registers_used_this_shader_len > vars.storage_registers_used_this_shader_max, @src(), "storage registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there will be an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        // SORT STORAGE REGISTERS SO UNUSED SLOTS ARE GIVEN OUT IN THE ORDER: SAMPLE_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than);
        // NEXT, GO THROUGH AND RESOLVE ALL 'AUTO' BINDINGS TO FILL UNUSED SLOTS, THEN CHECK IF PROVISIONING RESULTED IN TOTAL == (MAX + 1),
        // WITH STORAGE SLOTS IN CORRECT ORDER (SAMPLED_TEXTURES => STORAGE_TEXTURES => STORAGE_BUFFERS)
        for (vars.uniform_registers_used_this_shader[0..vars.uniform_registers_used_this_shader_len]) |uni_register| {
            if (uni_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_uniform_slots(&vars, @intCast(frag_idx), vertex_linkages, fragment_linkages, uni_register, .VERTEX);
        }
        assert_with_reason(vars.uniform_registers_used_this_shader_len == vars.uniform_registers_used_this_shader_max + 1, @src(), "uniform registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.uniform_registers_used_this_shader_len, vars.uniform_registers_used_this_shader_max });
        for (vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len]) |*storage_register| {
            if (storage_register.register == .MANUAL) continue;
            SUB_ROUTINE.provision_auto_storage_slots(&vars, @intCast(frag_idx), vertex_linkages, fragment_linkages, storage_register, .VERTEX);
        }
        assert_with_reason(vars.storage_registers_used_this_shader_len == vars.storage_registers_used_this_shader_max + 1, @src(), "storage registers for fragment shader `{s}` total to {d}, but the largest register is {d}: there is an empty register somewhere which is disallowed (all registers must start at 0 and continue to the max register num with no gaps)", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader_len, vars.storage_registers_used_this_shader_max });
        Sort.insertion_sort_with_func(StorageRegisterWithSourceAndKind, vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len], StorageRegisterWithSourceAndKind.greater_than_only_register);
        assert_with_reason(Utils.mem_is_sorted_with_func(@ptrCast(&vars.storage_registers_used_this_shader), 0, vars.storage_registers_used_this_shader_len, StorageRegisterWithSourceAndKind.greater_than_only_kind), @src(), "not all storage registers in vertex shader `{s}` are in correct order (all sampled textures must come first, then all storage textures, then all storage buffers with increasing registers), got: {any}", .{ @tagName(linkage.fragment_shader), vars.storage_registers_used_this_shader[0..vars.storage_registers_used_this_shader_len] });
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
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_vertex_shaders[v][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .buffer = @enumFromInt(@intCast(u)),
                    .register = vars.uniforms_allowed_in_vertex_shaders[v][u].register,
                };
                all_allowed_uniforms_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        inline for (0.._NUM_UNIFORM_STRUCTS) |u| {
            if (vars.uniforms_allowed_in_fragment_shaders[f][u].allowed) {
                const allowed = _ShaderAllowedUniform{
                    .buffer = @enumFromInt(@intCast(u)),
                    .register = vars.uniforms_allowed_in_fragment_shaders[v][u].register,
                };
                all_allowed_uniforms_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
    }
    const uniform_starts_vert_const = uniform_starts_vert;
    const uniform_starts_frag_const = uniform_starts_frag;
    const all_allowed_uniforms_flat_vert_const = all_allowed_uniforms_flat_vert;
    const all_allowed_uniforms_flat_frag_const = all_allowed_uniforms_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED STORAGE BUFFERS
    comptime var total_num_allowed_storage_buffers_vert: u32 = 0;
    comptime var total_num_allowed_storage_buffers_frag: u32 = 0;
    comptime var storage_buffer_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_buffer_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_buffer_starts_vert[v] = total_num_allowed_storage_buffers_vert;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                total_num_allowed_storage_buffers_vert += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_buffer_starts_frag[f] = total_num_allowed_storage_buffers_frag;
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_fragment_shaders[f][sb].allowed) {
                total_num_allowed_storage_buffers_frag += 1;
            }
        }
    }
    storage_buffer_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_storage_buffers_vert;
    storage_buffer_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_storage_buffers_frag;
    comptime var all_allowed_storage_buffers_flat_vert: [total_num_allowed_storage_buffers_vert]_ShaderAllowedStorageBuffer = undefined;
    comptime var all_allowed_storage_buffers_flat_frag: [total_num_allowed_storage_buffers_frag]_ShaderAllowedStorageBuffer = undefined;
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_vertex_shaders[v][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@intCast(sb)),
                    .register = vars.storage_buffers_allowed_in_vertex_shaders[v][sb].register,
                };
                all_allowed_storage_buffers_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        inline for (0.._NUM_STORAGE_BUFFERS) |sb| {
            if (vars.storage_buffers_allowed_in_fragment_shaders[f][sb].allowed) {
                const allowed = _ShaderAllowedStorageBuffer{
                    .buffer = @enumFromInt(@intCast(sb)),
                    .register = vars.storage_buffers_allowed_in_fragment_shaders[v][sb].register,
                };
                all_allowed_storage_buffers_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
    }
    const storage_buffer_starts_vert_const = storage_buffer_starts_vert;
    const storage_buffer_starts_frag_const = storage_buffer_starts_frag;
    const all_allowed_storage_buffers_flat_vert_const = all_allowed_storage_buffers_flat_vert;
    const all_allowed_storage_buffers_flat_frag_const = all_allowed_storage_buffers_flat_frag;
    // COMPILE A CONDENSED LIST OF ALLOWED STORAGE TEXTURES
    comptime var total_num_allowed_storage_textures_vert: u32 = 0;
    comptime var total_num_allowed_storage_textures_frag: u32 = 0;
    comptime var storage_texture_starts_vert: [_NUM_VERTEX_SHADERS + 1]u32 = undefined;
    comptime var storage_texture_starts_frag: [_NUM_FRAGMENT_SHADERS + 1]u32 = undefined;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        storage_texture_starts_vert[v] = total_num_allowed_storage_textures_vert;
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                total_num_allowed_storage_textures_vert += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        storage_texture_starts_frag[f] = total_num_allowed_storage_textures_frag;
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_fragment_shaders[f][t].allowed) {
                total_num_allowed_storage_textures_frag += 1;
            }
        }
    }
    storage_texture_starts_vert[_NUM_VERTEX_SHADERS] = total_num_allowed_storage_textures_vert;
    storage_texture_starts_frag[_NUM_FRAGMENT_SHADERS] = total_num_allowed_storage_textures_frag;
    comptime var all_allowed_storage_textures_flat_vert: [total_num_allowed_storage_textures_vert]_ShaderAllowedStorageTexture = undefined;
    comptime var all_allowed_storage_textures_flat_frag: [total_num_allowed_storage_textures_frag]_ShaderAllowedStorageTexture = undefined;
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_vertex_shaders[v][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .buffer = @enumFromInt(@intCast(t)),
                    .register = vars.storage_textures_allowed_in_vertex_shaders[v][t].register,
                };
                all_allowed_storage_textures_flat_vert[vi] = allowed;
                vi += 1;
            }
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        inline for (0.._NUM_TEXTURES) |t| {
            if (vars.storage_textures_allowed_in_fragment_shaders[f][t].allowed) {
                const allowed = _ShaderAllowedStorageTexture{
                    .buffer = @enumFromInt(@intCast(t)),
                    .register = vars.storage_textures_allowed_in_fragment_shaders[v][t].register,
                };
                all_allowed_storage_textures_flat_frag[fi] = allowed;
                fi += 1;
            }
        }
    }
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
    comptime var all_allowed_sample_pairs_flat_vert: [total_num_allowed_sample_pairs_vert]_ShaderAllowedSamplePair = undefined;
    comptime var all_allowed_sample_pairs_flat_frag: [total_num_allowed_sample_pairs_frag]_ShaderAllowedSamplePair = undefined;
    vi = 0;
    fi = 0;
    inline for (0.._NUM_VERTEX_SHADERS) |v| {
        inline for (vars.sample_pairs_allowed_in_vertex_shaders[v][0..vars.sample_pairs_allowed_in_vertex_shaders_len[v]]) |samp| {
            all_allowed_sample_pairs_flat_vert[vi] = samp;
            vi += 1;
        }
    }
    inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
        inline for (vars.sample_pairs_allowed_in_fragment_shaders[f][0..vars.sample_pairs_allowed_in_fragment_shaders_len[f]]) |samp| {
            all_allowed_sample_pairs_flat_frag[fi] = samp;
            fi += 1;
        }
    }
    const sample_pair_starts_vert_const = sample_pair_starts_vert;
    const sample_pair_starts_frag_const = sample_pair_starts_frag;
    const all_allowed_sample_pairs_flat_vert_const = all_allowed_sample_pairs_flat_vert;
    const all_allowed_sample_pairs_flat_frag_const = all_allowed_sample_pairs_flat_frag;
    // VALIDATE RENDER PIPELINES
    comptime var total_num_vertex_buffers_to_bind: u32 = 0;
    comptime var total_num_field_mappings: u32 = 0;
    comptime var vertex_buffers_to_bind_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
    comptime var vertex_mapping_start_locs: [_NUM_RENDER_PIPELINES + 1]u32 = undefined;
    // FIRST PASS ROUGH VALIDATION AND COUNTS
    inline for (0.._NUM_RENDER_PIPELINES) |pipe_idx| {
        comptime var vertex_buffers_for_this_pipeline: [_NUM_VERT_BUFFERS]bool = @splat(false);
        const pipe_name: RENDER_PIPELINE_NAMES_ENUM = @enumFromInt(@as(Types.enum_tag_type(RENDER_PIPELINE_NAMES_ENUM), @intCast(pipe_idx)));
        const pipe_def = ordered_pipeline_definitions_const[pipe_idx];
        const vert_idx = @intFromEnum(pipe_def.vertex);
        const frag_idx = @intFromEnum(pipe_def.fragment);
        const vert_def = ordered_vertex_shader_definitions_const[vert_idx];
        const frag_def = ordered_fragment_shader_definitions_const[frag_idx];
        const vert_struct_in_idx = @intFromEnum(vert_def.input_type);
        const frag_struct_out_idx = @intFromEnum(frag_def.output_type);
        assert_with_reason(vert_def.output_type == frag_def.input_type, @src(), "for render pipeline `{s}` the vertex shader output type `{s}` does not match the fragment shader input type `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), @tagName(pipe_def.fragment) });
        assert_with_reason(pipe_def.vertex_field_maps.len == ordered_shader_struct_locations_quick_info_const[vert_struct_in_idx].num_locations, @src(), "for render pipeline `{s}` the vertex shader has {d} input loacations, but {d} vertex field mappings", .{ @tagName(pipe_name), ordered_shader_struct_locations_quick_info_const[vert_struct_in_idx].num_locations, pipe_def.vertex_field_maps.len });
        assert_with_reason(pipe_def.target_info.num_color_targets == ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].num_locations, @src(), "for render pipeline `{s}` the fragment shader has {d} color targets, but `target_info.num_color_targets` = {d}", .{ @tagName(pipe_name), ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].num_locations, pipe_def.target_info.num_color_targets });
        if (VALIDATION.color_texture_non_color_format and pipe_def.target_info.num_color_targets > 0) {
            assert_with_reason(pipe_def.target_info.color_target_descriptions != null, @src(), "for render pipeline `{s}` `target_info.num_color_targets == {d}` but `target_info.color_target_descriptions == null`", .{ @tagName(pipe_name), pipe_def.target_info.num_color_targets });
            inline for (pipe_def.target_info.color_target_descriptions.?[0..pipe_def.target_info.num_color_targets], 0..) |target, t| {
                assert_with_reason(!target.format.is_depth_format(), @src(), "for render pipeline `{s}` color target {d}, the texture format is not a COLOR format, got `{s}`", .{ @tagName(pipe_name), @tagName(target.format) });
                assert_with_reason(target.blend_state.none_invalid_if_option_enabled(), @src(), "for render pipeline `{s}` color target {d}, `blend_state` options are enabled, but have one or more `.INVALID` modes or a blank color write mask", .{ @tagName(pipe_name), t });
            }
        }
        assert_with_reason(pipe_def.target_info.has_depth_stencil_target == ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].has_depth_target, @src(), "for render pipeline `{s}` the depth buffer enable setting `{any}` does not match the fragment shader `{s}` depth target state `{any}`", .{ @tagName(pipe_name), pipe_def.target_info.has_depth_stencil_target, @tagName(pipe_def.fragment), ordered_shader_struct_locations_quick_info_const[frag_struct_out_idx].has_depth_target });
        if (pipe_def.target_info.has_depth_stencil_target) {
            assert_with_reason(pipe_def.target_info.depth_stencil_format.is_depth_format(), @src(), "for render pipeline `{s}`, `target_info.has_depth_stencil_target == true` but the `target_info.depth_stencil_format` is is not a depth format, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
            assert_with_reason(!pipe_def.depth_stencil_options.enable_depth_test or pipe_def.depth_stencil_options.compare_op != .INVALID, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_depth_test == true` while `depth_stencil_options.compare_op == .INVALID`", .{@tagName(pipe_name)});
            assert_with_reason(!pipe_def.depth_stencil_options.enable_stencil_test or (pipe_def.depth_stencil_options.back_stencil_state.none_invalid() and pipe_def.depth_stencil_options.front_stencil_state.none_invalid()), @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while either `depth_stencil_options.front_stencil_state` or `depth_stencil_options.back_stencil_state` has `.INVALID` entries", .{@tagName(pipe_name)});
            if (VALIDATION.depth_texture_non_stencil_format and pipe_def.depth_stencil_options.enable_stencil_test) {
                assert_with_reason(pipe_def.target_info.depth_stencil_format.has_depth_stencil(), @src(), "for render pipeline `{s}`, `depth_stencil_options.enable_stencil_test == true` but the `target_info.depth_stencil_format` is does not have a stencil, got format `{s}`", .{ @tagName(pipe_name), @tagName(pipe_def.target_info.depth_stencil_format) });
            }
            if (VALIDATION.depth_stencil_zero_bits and pipe_def.depth_stencil_options.enable_stencil_test) {
                assert_with_reason(pipe_def.depth_stencil_options.compare_mask != 0 and pipe_def.depth_stencil_options.write_mask != 0, @src(), "for render pipeline `{s}` the depth buffer is enabled as a render target, but options `depth_stencil_options.enable_stencil_test == true` while `depth_stencil_options.write_mask` or `depth_stencil_options.compare_mask` equal zero (in effect no depth stencil will be compared or written)", .{@tagName(pipe_name)});
            }
        }
        total_num_vert_sampler_pairs = vars.
        vertex_buffers_to_bind_start_locs[pipe_idx] = total_num_vertex_buffers_to_bind;
        vertex_mapping_start_locs[pipe_idx] = total_num_field_mappings;
        inline for (pipe_def.vertex_field_maps) |field_map| {
            const vert_buf_idx = @intFromEnum(field_map.vertex_buffer);
            if (vertex_buffers_for_this_pipeline[vert_buf_idx] == false) {
                total_num_vertex_buffers_to_bind += 1;
                vertex_buffers_for_this_pipeline[vert_buf_idx] = true;
            }
            total_num_field_mappings += 1;
        }
    }
    vertex_buffers_to_bind_start_locs[_NUM_RENDER_PIPELINES] = total_num_vertex_buffers_to_bind;
    vertex_mapping_start_locs[_NUM_RENDER_PIPELINES] = total_num_field_mappings;
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
                assert_with_reason(vertex_buffer_rates_for_this_pipeline[vert_buf_idx] == field_map.vertex_field_input_rate, @src(), "in render pipeline `{s}`, vertex buffer `{s}` had both `.VERTEX` and `.INSTANCE` input rates specified: a vertex buffer can only be bound at one input rate, if you need 2 fields with different rates, they must be on separate vertex buffers", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer) });
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
                            assert_with_reason(vert_buf_idx == buffers_used[found_used_slot_idx], @src(), "in render pipeline `{s}`, vertex buffer `{s}` was bound to slot {d}, but that slot was already bound to another vertex buffer (`{s}`)", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), new_slot, @tagName(@as(GPU_VERTEX_BUFFER_NAMES_ENUM, @enumFromInt(buffers_used[found_used_slot_idx]))) });
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
                        assert_with_reason(new_slot == old_slot, @src(), "in render pipeline `{s}`, vertex buffer `{s}` was bound to both slots {d} and {d}: only one slot is allowed per vertex buffer per render pipeline", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), new_slot, old_slot });
                    },
                },
            }
            assert_with_reason(@hasDecl(vert_buf_info.fields_info, field_map.vertex_buffer_field_name), @src(), "in render pipeline `{s}`, vertex buffer `{s}` does not have field `{s}` (from `RenderPipelineVertexFieldMap.vertex_buffer_field_name`), available fields are: {any}", .{ @tagName(pipe_name), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @typeInfo(vert_buf_info.fields_info).@"struct".decls });
            assert_with_reason(@hasDecl(vert_struct_in.fields_info, field_map.shader_struct_field_name), @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` does not have field `{s}` (from `RenderPipelineVertexFieldMap.shader_struct_field_name`), available fields are: {any}", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, @typeInfo(vert_struct_in.fields_info).@"struct".decls });
            const vert_struct_in_field_info: ShaderStructFieldInfo = @field(vert_struct_in.fields_info, field_map.shader_struct_field_name);
            const vert_buf_out_field_info: VertexBufferFieldInfo = @field(vert_buf_info.fields_info, field_map.vertex_buffer_field_name);
            assert_with_reason(locations_used[vert_struct_in_field_info.location] == false, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) was mapped more than once", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location });
            locations_used[vert_struct_in_field_info.location] = true;
            if (VALIDATION.mismatched_gpu_formats) {
                assert_with_reason(vert_struct_in_field_info.gpu_format == vert_buf_out_field_info.gpu_format, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) gpu format `{s}` was mapped from vertex buffer `{s}` field `{s}` gpu format `{s}`: gpu formats MUST match", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location, @tagName(vert_struct_in_field_info.gpu_format), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @tagName(vert_buf_out_field_info.gpu_format) });
            }
            if (VALIDATION.mismatched_cpu_types) {
                assert_with_reason(vert_struct_in_field_info.cpu_type == vert_buf_out_field_info.field_type, @src(), "in render pipeline `{s}`, vertex shader input struct `{s}` field `{s}` (location {d}) cpu type `{s}` was mapped from vertex buffer `{s}` field `{s}` field type `{s}`: zig types MUST match", .{ @tagName(pipe_name), @tagName(pipe_def.vertex), field_map.shader_struct_field_name, vert_struct_in_field_info.location, @typeName(vert_struct_in_field_info.cpu_type), @tagName(field_map.vertex_buffer), field_map.vertex_buffer_field_name, @typeName(vert_buf_out_field_info.field_type) });
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
            assert_with_reason(max_slot_used + 1 == slots_used_len, @src(), "in render pipeline `{s}`, the max vertex buffer slot used is {d}, but the number of vertex buffer slots used is {d} (a gap exists somewhere): vertex buffer slots must start from 0 and increase with no gaps", .{ @tagName(pipe_name), max_slot_used, slots_used_len });
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
            vertex_buffer_names_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[buffer_idx] + ss] = buffer_name;
            vertex_buffers_to_bind_per_render_pipeline[vertex_buffers_to_bind_start_locs[buffer_idx] + ss] = bind;
        }
        // COMPILE VERTEX ATTRIBUTE BINDINGS TO FINAL ARRAY
        inline for (pipe_def.vertex_field_maps, 0..) |field_map, f| {
            const ff: u32 = @intCast(f);
            const vert_buf_idx = @intFromEnum(field_map.vertex_buffer);
            const vert_buf_info: VertexBufferDescription = @field(STRUCT_OF_GPU_VERTEX_BUFFER_DEFINITIONS, @tagName(field_map.vertex_buffer));
            const vert_struct_in_field_info: ShaderStructFieldInfo = @field(vert_struct_in.fields_info, field_map.shader_struct_field_name);
            const vert_buf_out_field_info: VertexBufferFieldInfo = @field(vert_buf_info.fields_info, field_map.vertex_buffer_field_name);
            vertex_attributes_to_bind_per_render_pipeline[vertex_mapping_start_locs[pipe_idx] + ff] = SDL3.GPU_VertexAttribute{
                .buffer_slot = vertex_buffer_slots_for_this_pipeline[vert_buf_idx].MANUAL,
                .format = vert_buf_out_field_info.gpu_format,
                .location = vert_struct_in_field_info.location,
                .offset = vert_buf_out_field_info.offset,
            };
        }
        //CHECKPOINT
    }
    
    return struct {
        const Self = @This();
        gpu: *GPU_Device = @ptrCast(INVALID_ADDR),
        windows: [INTERNAL.NUM_WINDOWS]*Window = @splat(@as(*Window, @ptrCast(INVALID_ADDR))),
        windows_init: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        windows_claimed: [INTERNAL.NUM_WINDOWS]bool = @splat(false),
        render_pipelines: [INTERNAL.NUM_RENDER_PIPELINES]*GPU_GraphicsPipeline = @splat(@as(*GPU_GraphicsPipeline, @ptrCast(INVALID_ADDR))),
        render_pipelines_init: [INTERNAL.NUM_RENDER_PIPELINES]bool = @splat(false),
        current_render_pipeline: RenderPipelineName = undefined,
        render_pipeline_active: bool = false,
        textures: [INTERNAL.NUM_TEXTURES]*GPU_Texture = @splat(@as(*GPU_GraphicsPipeline, @ptrCast(INVALID_ADDR))),
        textures_init: [INTERNAL.NUM_TEXTURES]bool = @splat(false),
        transfer_buffers: [INTERNAL.NUM_TRANSFER_BUFFERS]*GPU_TransferBuffer = @splat(@as(*GPU_TransferBuffer, @ptrCast(INVALID_ADDR))),
        transfer_buffers_init: [INTERNAL.NUM_TRANSFER_BUFFERS]bool = @splat(false),
        vertex_buffers: [INTERNAL.NUM_VERTEX_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrCast(INVALID_ADDR))),
        vertex_buffers_init: [INTERNAL.NUM_VERTEX_BUFFERS]bool = @splat(false),
        vertex_buffers_bound: [INTERNAL.NUM_VERTEX_BUFFERS]bool = @splat(false),
        storage_buffers: [INTERNAL.NUM_STORAGE_BUFFERS]*GPU_Buffer = @splat(@as(*GPU_Buffer, @ptrCast(INVALID_ADDR))),
        storage_buffers_init: [INTERNAL.NUM_STORAGE_BUFFERS]bool = @splat(false),
        storage_buffers_bound: [INTERNAL.NUM_STORAGE_BUFFERS]bool = @splat(false),
        samplers: [INTERNAL.NUM_SAMPLERS]*GPU_TextureSampler = @splat(@as(*GPU_TextureSampler, @ptrCast(INVALID_ADDR))),
        samplers_init: [INTERNAL.NUM_SAMPLERS]bool = @splat(false),
        uniforms: STRUCT_OF_UNIFORM_STRUCTS = undefined,

        pub const INTERNAL = struct {
            pub const NUM_WINDOWS = Types.enum_defined_field_count(WINDOW_NAMES_ENUM);
            pub const NUM_RENDER_PIPELINES = Types.enum_defined_field_count(RENDER_PIPELINE_NAMES_ENUM);
            pub const NUM_TEXTURES = Types.enum_defined_field_count(TEXTURE_NAMES_ENUM);
            pub const NUM_TRANSFER_BUFFERS = Types.enum_defined_field_count(TRANSFER_BUFFER_NAMES_ENUM);
            pub const NUM_VERTEX_BUFFERS = Types.enum_defined_field_count(GPU_VERTEX_BUFFER_NAMES_ENUM);
            pub const NUM_SAMPLERS = Types.enum_defined_field_count(SAMPLER_NAMES_ENUM);
            pub const NUM_VERTEX_STRUCTS = Types.enum_defined_field_count(GPU_SHADER_STRUCT_NAMES_ENUM);
            pub const NUM_STORAGE_BUFFERS = Types.enum_defined_field_count(GPU_STORAGE_BUFFER_NAMES_ENUM);
            pub const ALLOWED_UNIFORMS_FLAT = all_allowed_uniforms_flat_const;
            pub const ALLOWED_UNIFORMS_STARTS = allowed_uniform_starts_const;
            pub const ALLOWED_UNIFORMS_PER_PIPELINE = allowed_uniforms_per_pipeline_indices_const;
            pub inline fn allowed_uniforms(comptime PIPELINE: RenderPipelineName) []const PipelineAllowedResource {
                const idx = @intFromEnum(PIPELINE);
                return ALLOWED_UNIFORMS_FLAT[ALLOWED_UNIFORMS_STARTS[idx]..ALLOWED_UNIFORMS_STARTS[idx + 1]];
            }
            pub inline fn uniform_allowed_info(comptime PIPELINE: RenderPipelineName, comptime UNIFORM: UniformName) ?PipelineAllowedResource {
                const pipe_idx = @intFromEnum(PIPELINE);
                const uni_idx = @intFromEnum(UNIFORM);
                const map_idx = ALLOWED_UNIFORMS_PER_PIPELINE[pipe_idx][uni_idx];
                if (comptime map_idx >= ALLOWED_UNIFORMS_FLAT.len) return null;
                return ALLOWED_UNIFORMS_FLAT[map_idx];
            }
            pub const ALLOWED_STORAGE_BUFFERS_FLAT = all_allowed_storage_buffers_flat_const;
            pub const ALLOWED_STORAGE_BUFFERS_STARTS = allowed_storage_buffer_starts_const;
            pub const ALLOWED_STORAGE_BUFFERS_PER_PIPELINE = allowed_storage_buffers_per_pipeline_indices_const;
            pub inline fn allowed_storage_buffers(comptime PIPELINE: RenderPipelineName) []const PipelineAllowedResource {
                const idx = @intFromEnum(PIPELINE);
                return ALLOWED_STORAGE_BUFFERS_FLAT[ALLOWED_STORAGE_BUFFERS_STARTS[idx]..ALLOWED_STORAGE_BUFFERS_STARTS[idx + 1]];
            }
            pub inline fn storage_buffer_allowed_info(comptime PIPELINE: RenderPipelineName, comptime BUFFER: StorageBufferName) ?PipelineAllowedResource {
                const pipe_idx = @intFromEnum(PIPELINE);
                const buf_idx = @intFromEnum(BUFFER);
                const map_idx = ALLOWED_STORAGE_BUFFERS_PER_PIPELINE[pipe_idx][buf_idx];
                if (comptime map_idx >= ALLOWED_STORAGE_BUFFERS_FLAT.len) return null;
                return ALLOWED_STORAGE_BUFFERS_FLAT[map_idx];
            }
            pub const ALLOWED_STORAGE_TEXTURES_FLAT = all_allowed_storage_textures_flat_const;
            pub const ALLOWED_STORAGE_TEXTURES_STARTS = allowed_storage_texture_starts_const;
            pub const ALLOWED_STORAGE_TEXTURES_PER_PIPELINE = allowed_storage_textures_per_pipeline_indices_const;
            pub inline fn allowed_storage_textures(comptime PIPELINE: RenderPipelineName) []const PipelineAllowedResource {
                const idx = @intFromEnum(PIPELINE);
                return ALLOWED_STORAGE_TEXTURES_FLAT[ALLOWED_STORAGE_TEXTURES_STARTS[idx]..ALLOWED_STORAGE_TEXTURES_STARTS[idx + 1]];
            }
            pub inline fn storage_texture_allowed_info(comptime PIPELINE: RenderPipelineName, comptime TEXTURE: TextureName) ?PipelineAllowedResource {
                const pipe_idx = @intFromEnum(PIPELINE);
                const tex_idx = @intFromEnum(TEXTURE);
                const map_idx = ALLOWED_STORAGE_TEXTURES_PER_PIPELINE[pipe_idx][tex_idx];
                if (comptime map_idx >= ALLOWED_STORAGE_TEXTURES_FLAT.len) return null;
                return ALLOWED_STORAGE_TEXTURES_FLAT[map_idx];
            }
            pub const ALLOWED_SAMPLERS_FLAT = all_allowed_sampler_pair_flat_const;
            pub const ALLOWED_SAMPLERS_STARTS = allowed_sampler_pair_starts_const;
            pub inline fn allowed_sample_pairs(comptime PIPELINE: RenderPipelineName) []const PipelineAllowedSamplePair(TextureName, SamplerName) {
                const idx = @intFromEnum(PIPELINE);
                return ALLOWED_SAMPLERS_FLAT[ALLOWED_SAMPLERS_STARTS[idx]..ALLOWED_SAMPLERS_STARTS[idx + 1]];
            }
            pub inline fn sample_pair_allowed_info(comptime PIPELINE: RenderPipelineName, comptime SAMPLER: SamplerName, comptime TEXTURE: TextureName) ?PipelineAllowedSamplePair(TextureName, SamplerName) {
                const combined = Types.combine_2_enums(SAMPLER, TEXTURE);
                const allowed_in_pipe = allowed_sample_pairs(PIPELINE);
                for (allowed_in_pipe) |allowed_info| {
                    if (allowed_info.combined_id == combined) {
                        return allowed_info;
                    }
                }
                return null;
            }
            pub const ALLOWED_VERTEX_BUFFERS_FLAT = all_allowed_vertex_buffers_flat_const;
            pub const ALLOWED_VERTEX_BUFFERS_STARTS = allowed_vertex_buffer_starts_const;
            pub const ALLOWED_VERTEX_BUFFERS_PER_PIPELINE = allowed_vertex_buffers_per_pipeline_indices_const;
            pub inline fn allowed_vertex_buffers(comptime PIPELINE: RenderPipelineName) []const AllowedResuorce {
                const idx = @intFromEnum(PIPELINE);
                return ALLOWED_VERTEX_BUFFERS_FLAT[ALLOWED_VERTEX_BUFFERS_STARTS[idx]..ALLOWED_VERTEX_BUFFERS_STARTS[idx + 1]];
            }
            pub inline fn vertex_buffer_is_allowed(comptime PIPELINE: RenderPipelineName, comptime BUFFER: VertexBufferName) ?AllowedResuorce {
                const pipe_idx = @intFromEnum(PIPELINE);
                const buf_idx = @intFromEnum(BUFFER);
                const map_idx = ALLOWED_VERTEX_BUFFERS_PER_PIPELINE[pipe_idx][buf_idx];
                if (comptime map_idx >= ALLOWED_VERTEX_BUFFERS_FLAT.len) return null;
                return ALLOWED_VERTEX_BUFFERS_FLAT[map_idx];
            }
            pub const VERTEX_STRUCT_TYPES = STRUCT_OF_SHADER_STRUCT_TYPES;
            pub const STORAGE_STRUCT_TYPES = STRUCT_OF_STORAGE_BUFFER_STRUCT_TYPES;
            pub const VERTEX_STRUCT_USER_FIELDS = STRUCT_OF_VERTEX_STRUCT_NAMES_WITH_USER_SUPPLIED_VERTEX_FIELD_NAMES_AND_LOCATIONS_ENUMS;
        };

        pub const WindowName = WINDOW_NAMES_ENUM;
        pub const RenderPipelineName = RENDER_PIPELINE_NAMES_ENUM;
        pub const TextureName = TEXTURE_NAMES_ENUM;
        pub const TransferBufferName = TRANSFER_BUFFER_NAMES_ENUM;
        pub const SamplerName = SAMPLER_NAMES_ENUM;
        pub const VertexBufferName = GPU_VERTEX_BUFFER_NAMES_ENUM;
        pub const VertexStructName = GPU_SHADER_STRUCT_NAMES_ENUM;
        pub const StorageBufferName = GPU_STORAGE_BUFFER_NAMES_ENUM;
        pub const UniformName = GPU_UNIFORM_NAMES_ENUM;
        pub const VertexShaderName = VERTEX_SHADER_NAMES_ENUM;
        pub const FragmentShaderName = FRAGMENT_SHADER_NAMES_ENUM;

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
            vertex_shader_settings: [_NUM_VERTEX_SHADERS]VertexShaderInit,
            fragment_shader_settings: [_NUM_VERTEX_SHADERS]FragmentShaderInit,
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
            var vert_shaders: [_NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
            var vert_shaders_init: [_NUM_VERTEX_SHADERS]bool = @splat(false);
            defer {
                inline for (0.._NUM_VERTEX_SHADERS) |v| {
                    const v_settings = init.vertex_shader_settings[v];
                    const shader_idx = @intFromEnum(v_settings.name);
                    if (vert_shaders_init[shader_idx]) {
                        controller.gpu.release_shader(vert_shaders[shader_idx]);
                    }
                }
            }
            inline for (0.._NUM_VERTEX_SHADERS) |v| {
                const v_settings = init.vertex_shader_settings[v];
                const shader_idx = @intFromEnum(v_settings.name);
                if (vert_shaders_init[shader_idx]) return VertShaderInitError.vertex_shader_already_initialized;
                var create_info = v_settings.create_info();
                vert_shaders[shader_idx] = try controller.gpu.create_shader(&create_info);
                vert_shaders_init[shader_idx] = true;
            }
            // FRAG SHADERS
            var frag_shaders: [_NUM_VERTEX_SHADERS]*GPU_Shader = @splat(@as(*GPU_Shader, @ptrCast(INVALID_ADDR)));
            var frag_shaders_init: [_NUM_VERTEX_SHADERS]bool = @splat(false);
            defer {
                inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
                    const f_settings = init.fragment_shader_settings[f];
                    const shader_idx = @intFromEnum(f_settings.name);
                    if (frag_shaders_init[shader_idx]) {
                        controller.gpu.release_shader(frag_shaders[shader_idx]);
                    }
                }
            }
            inline for (0.._NUM_FRAGMENT_SHADERS) |f| {
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
                    if (controller.vertex_buffers_init[gpu_buf_idx]) {
                        controller.gpu.release_buffer(controller.vertex_buffers[gpu_buf_idx]);
                    }
                }
            }
            inline for (0..NUM_GPU_BUFFERS) |gb| {
                const gb_settings = init.gpu_buffer_settings[gb];
                const gpu_buf_idx = @intFromEnum(gb_settings.name);
                if (controller.vertex_buffers_init[gpu_buf_idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
                if (gb_settings.should_init) {
                    var create_info = gb_settings.create_info();
                    controller.vertex_buffers[gpu_buf_idx] = try controller.gpu.create_buffer(&create_info);
                    controller.vertex_buffers_init[gpu_buf_idx] = true;
                }
            }
            return controller;
        }

        pub fn destroy(self: *Self) void {
            inline for (0..NUM_GPU_BUFFERS) |gb| {
                if (self.vertex_buffers_init[gb]) {
                    self.gpu.release_buffer(self.vertex_buffers[gb]);
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
            if (self.vertex_buffers_init[idx]) return GpuBufferInitError.gpu_buffer_already_initialized;
            self.vertex_buffers[idx] = try self.gpu.create_buffer(buffer_info);
            self.vertex_buffers_init[idx] = true;
        }
        pub fn destroy_gpu_buffer(self: *Self, gpu_buffer_name: GpuBufferName) void {
            const idx = @intFromEnum(gpu_buffer_name);
            if (!self.vertex_buffers_init[idx]) return;
            self.gpu.release_buffer(self.vertex_buffers[idx]);
            self.vertex_buffers_init[idx] = false;
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
