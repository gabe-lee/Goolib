//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const Endian = std.builtin.Endian;
const Type = std.builtin.Type;
const math = std.math;
const meta = std.meta;
const mem = std.mem;

const Root = @import("./_root.zig");
const Bytes = Root.Bytes;
const WriteError = Root.CommonTypes.WriteError;

pub const SourceKind = enum(u8) {
    Block,
    Clusters,
    Singles,
};

pub const Source = union(SourceKind) {
    Block: []const u8,
    Clusters: []const []const u8,
    Sparse: []const *const u8,
    CompactSparseMicro: []const Bytes.CompactSparseBytesMicro,
    CompactSparseSmall: []const Bytes.CompactSparseBytesSmall,
    CompactSparseMedium: []const Bytes.CompactSparseBytesMedium,
};

/// A type-erased pointer to the object that implements this interface
implementor: *anyopaque,
/// A function pointer table that matches the minimum required interface functions to their implementations
vtable: VTable,

/// A function pointer table that matches the minimum required interface functions to their implementations
pub const VTable = struct {
    /// Attempt to write all bytes provided from `source`
    ///
    /// Must accept any of the possible `Source` kinds
    write_bytes: *const fn (implementor: *anyopaque, source: Source) WriteError,
};
