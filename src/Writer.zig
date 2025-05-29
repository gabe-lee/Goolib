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

const Root = @import("root");
const Bytes = Root.Bytes;
const WriteError = Root.CommonTypes.WriteError;
const CopyAdapter = Bytes.CopyAdapter;
const CopyRange = Bytes.CopyRange;
const BufferProperties = Bytes.BufferProperties;
const BufferPropertiesPair = Bytes.BufferPropertiesPair;

/// A type-erased pointer to the object that implements this interface
_opaque: *anyopaque,
/// A function pointer table that matches the minimum required interface functions to their implementations
_vtable: VTable,

/// A function pointer table that matches the minimum required interface functions to their implementations
pub const VTable = struct {
    /// Attempt to obtain a slice that can hold at least `count` bytes to write into
    ///
    /// If the full slice size cannot be returned by the implementation, it should return
    /// a zero-length slice instead and NOT advance the write position
    try_get_write_slice: *const fn (_opaque: *anyopaque, byte_count: usize) []u8,
};

const ByteWriter = @This();

/// Create a `CopyAdapter`, used for writing a _specific_ type to a buffer with the specified `write_buffer_properties`
///
/// All write operations *require* one of these adapters as a parameter
pub fn make_type_adapter(comptime T: type, comptime write_buffer_properties: BufferProperties) CopyAdapter {
    return CopyAdapter.from_type_and_buffer_properties(T, BufferProperties{}, write_buffer_properties);
}

/// Create a `CopyRange` with a runtime-known `element_count` and comptime `CopyAdapter`
///
/// All write operations *require* one of these ranges as a parameter
pub fn make_range(element_count: usize, comptime type_adapter: CopyAdapter) CopyRange {
    return CopyRange.from_count_and_adapter(element_count, type_adapter);
}
/// Create a `CopyRange` with a comptime-known `element_count` and comptime `CopyAdapter`
///
/// All write operations *require* one of these ranges as a parameter
pub fn make_comptime_range(comptime element_count: usize, comptime type_adapter: CopyAdapter) CopyRange {
    return comptime CopyRange.from_count_and_adapter(element_count, type_adapter);
}

pub fn write_range(self: *ByteWriter, comptime type_adapter: CopyAdapter, range: CopyRange, source: anytype) WriteError!void {
    const src_type = @TypeOf(source);
    const src_raw: []u8 = undefined;
    switch (src_type) {
        *const type_adapter.element_type, *type_adapter.element_type => {
            const src_raw_len: usize = @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        []const type_adapter.element_type, []type_adapter.element_type => {
            const src_raw_len: usize = source.len * @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        type_adapter.element_type => {
            const src_raw_len: usize = @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(&source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        else => @compileError("`source` must be one of the following types:\n\t[]T, []const T, *T, *const T, T\nwhere T == `type_adapter.element_type`"),
    }
    if (src_raw.len < range.total_read_len) return WriteError.source_too_short_for_given_range;
    const write_slice = self._vtable.try_get_write_slice(self._opaque, range.total_write_len);
    if (write_slice.len < range.total_write_len) return WriteError.write_buffer_too_short;
    Bytes.copy_elements_with_range(write_slice, src_raw, range, type_adapter);
    return;
}

pub fn write_comptime_range(self: *ByteWriter, comptime type_adapter: CopyAdapter, comptime range: CopyRange, source: anytype) WriteError!void {
    const src_type = @TypeOf(source);
    const src_raw: []u8 = undefined;
    switch (src_type) {
        *const type_adapter.element_type, *type_adapter.element_type => {
            const src_raw_len: usize = @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        []const type_adapter.element_type, []type_adapter.element_type => {
            const src_raw_len: usize = source.len * @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        type_adapter.element_type => {
            const src_raw_len: usize = @sizeOf(type_adapter.element_type);
            const src_raw_ptr: [*]u8 = @ptrCast(@alignCast(&source));
            src_raw = src_raw_ptr[0..src_raw_len];
        },
        else => @compileError("`source` must be one of the following types:\n\t[]T, []const T, *T, *const T, T\nwhere T == `type_adapter.element_type`"),
    }
    if (src_raw.len < range.total_read_len) return WriteError.source_too_short_for_given_range;
    const write_slice = self._vtable.try_get_write_slice(self._opaque, range.total_write_len);
    if (write_slice.len < range.total_write_len) return WriteError.write_buffer_too_short;
    Bytes.copy_elements_with_comptime_range(write_slice, src_raw, range, type_adapter);
    return;
}

/// A simple implementation of the ByteWriter interface
///
/// This implementation has no special features, cannot expand its size,
/// and may be invalidated if another function causes the original memory to relocate or shrink
pub const SimpleByteWriter = struct {
    buffer: []u8,
    write_pos: usize,

    /// Instantiate a new SimpleByteWriter using the provided buffer.
    pub fn new(initial_buffer: []const u8) SimpleByteWriter {
        return SimpleByteWriter{
            .buffer = initial_buffer,
            .write_pos = 0,
        };
    }

    pub fn reset(self: *SimpleByteWriter) void {
        self.write_pos = 0;
    }

    /// Get the actual ByteWriter interface object
    pub fn byte_reader(self: *SimpleByteWriter) ByteWriter {
        return ByteWriter{
            ._opaque = @ptrCast(self),
            ._vtable = VTable{
                .try_get_write_slice = try_get_write_slice,
            },
        };
    }

    fn try_get_write_slice(self_opaque: *anyopaque, byte_count: usize) []u8 {
        const self: *SimpleByteWriter = @ptrCast(@alignCast(self_opaque));
        if (self.buffer.len - self.write_pos < byte_count) return &.{};
        const new_write_pos = self.write_pos + byte_count;
        const slice = self.buffer[self.write_pos..new_write_pos];
        self.write_pos = new_write_pos;
        return slice;
    }
};
