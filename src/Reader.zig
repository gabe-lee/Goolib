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
const Type = std.builtin.Type;
const math = std.math;
const meta = std.meta;
const mem = std.mem;
const heap = std.heap.ArenaAllocator;
const assert = std.debug.assert;

const Root = @import("root");
const Bytes = Root.Bytes;
const ReadError = Root.CommonTypes.ReadError;
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
    /// Return the slice of bytes that have not yet been read by the ByteReader
    get_unread_buffer: *const fn (_opaque: *anyopaque) []const u8,
    /// Advance the read position of the ByteReader. The implementation may choose to
    /// assert the new read position is valid, but the ByteReader interface performs
    /// the necessary checks before issuing this command
    advance_read_pos: *const fn (_opaque: *anyopaque, count: usize) void,
};

const ByteReader = @This();

/// Create a `CopyAdapter`, used for reading a _specific_ type _from_ this buffer with the specified `buffer_pair.read_properties`,
/// _to_ a destination buffer with the specified `buffer_pair.write_properties`
///
/// All peek/skip/read operations *require* one of these adapters as a parameter
pub fn make_type_adapter(comptime T: type, comptime buffer_properties_pair: BufferPropertiesPair) CopyAdapter {
    return CopyAdapter.from_type_and_buffer_properties_pair(T, buffer_properties_pair);
}

/// Create a `CopyRange` with a runtime-known `element_count` and comptime `CopyAdapter`
///
/// All peek/skip/read operations *require* one of these ranges as a parameter
pub fn make_range(element_count: usize, comptime type_adapter: CopyAdapter) CopyRange {
    return CopyRange.from_count_and_adapter(element_count, type_adapter);
}
/// Create a `CopyRange` with a comptime-known `element_count` and comptime `CopyAdapter`
///
/// All peek/skip/read operations *require* one of these ranges as a parameter
pub fn make_comptime_range(comptime element_count: usize, comptime type_adapter: CopyAdapter) CopyRange {
    return comptime CopyRange.from_count_and_adapter(element_count, type_adapter);
}

/// Copy `range.element_count` instances of type `type_adapter.element_type` into the destination slice, WITHOUT
/// increasing the read position
pub fn peek_range(self: *const ByteReader, comptime type_adapter: CopyAdapter, range: CopyRange, destination: anytype) ReadError!void {
    const dst_type = @TypeOf(destination);
    const dst_raw: []u8 = undefined;
    switch (dst_type) {
        []type_adapter.element_type => {
            const dst_raw_len: usize = destination.len * @sizeOf(type_adapter.element_type);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(destination));
            dst_raw = dst_raw_ptr[0..dst_raw_len];
        },
        *type_adapter.element_type => {
            const dst_raw_len: usize = @sizeOf(type_adapter.element_type);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(destination));
            dst_raw = dst_raw_ptr[0..dst_raw_len];
        },
        else => @compileError("`destination` must be one of the following types:\n\t[]T, *T\nwhere T == `type_adapter.element_type`"),
    }
    if (range.total_write_len > dst_raw.len) return ReadError.destination_too_short_for_given_range;
    const unread_buffer = self._vtable.get_unread_buffer(self._opaque);
    if (range.total_read_len > unread_buffer.len) return ReadError.read_buffer_too_short;
    Bytes.copy_elements_with_range(dst_raw, unread_buffer, range, type_adapter);
}
/// Copy `range.element_count` instances of type `type_adapter.element_type` into the destination slice, WITHOUT
/// increasing the read position
pub fn peek_comptime_range(self: *const ByteReader, comptime type_adapter: CopyAdapter, comptime range: CopyRange, destination: anytype) ReadError!void {
    const dst_type = @TypeOf(destination);
    const dst_raw: []u8 = undefined;
    switch (dst_type) {
        []type_adapter.element_type => {
            const dst_raw_len: usize = destination.len * @sizeOf(type_adapter.element_type);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(destination.ptr));
            dst_raw = dst_raw_ptr[0..dst_raw_len];
        },
        *type_adapter.element_type => {
            const dst_raw_len: usize = @sizeOf(type_adapter.element_type);
            const dst_raw_ptr: [*]u8 = @ptrCast(@alignCast(destination));
            dst_raw = dst_raw_ptr[0..dst_raw_len];
        },
        else => @compileError("`destination` must be type `[]T` or `*T`, where `T == type_adapter.element_type`"),
    }
    if (range.total_write_len > dst_raw.len) return ReadError.destination_too_short_for_given_range;
    const unread_buffer = self._vtable.get_unread_buffer(self._opaque);
    if (self.read_pos + range.total_read_len > unread_buffer.len) return ReadError.read_buffer_too_short;
    Bytes.copy_elements_with_comptime_range(dst_raw, unread_buffer, range, type_adapter);
}

/// Skip `range.total_read_len` bytes, which represent `range.element_count` instances of the type `adapter.element_type` the range was created with
pub fn skip_range(self: *const ByteReader, range: CopyRange) ReadError!void {
    const unread_buffer = self._vtable.get_unread_buffer(self._opaque);
    if (range.total_read_len > unread_buffer.len) return ReadError.read_buffer_too_short;
    self._vtable.advance_read_pos(self._opaque, range.total_read_len);
}
/// Skip `range.total_read_len` bytes, which represent `range.element_count` instances of the type `adapter.element_type` the range was created with
pub fn skip_comptime_range(self: *const ByteReader, comptime range: CopyRange) ReadError!void {
    const unread_buffer = self._vtable.get_unread_buffer(self._opaque);
    if (self.read_pos + range.total_read_len > unread_buffer.len) return ReadError.read_buffer_too_short;
    self._vtable.advance_read_pos(self._opaque, range.total_read_len);
}

/// Copy `range.element_count` instances of type `type_adapter.element_type` into the destination slice,
/// and increase the read position by `range.total_read_len` bytes
pub fn read_range(self: *const ByteReader, comptime type_adapter: CopyAdapter, range: CopyRange, destination: anytype) ReadError!void {
    try self.peek_range(type_adapter, range, destination);
    self._vtable.advance_read_pos(self._opaque, range.total_read_len);
}
/// Copy `range.element_count` instances of type `type_adapter.element_type` into the destination slice,
/// and increase the read position by `range.total_read_len` bytes
pub fn read_comptime_range(self: *const ByteReader, comptime type_adapter: CopyAdapter, comptime range: CopyRange, destination: anytype) ReadError!void {
    try self.peek_comptime_range(type_adapter, range, destination);
    self._vtable.advance_read_pos(self._opaque, range.total_read_len);
}

/// A simple implementation of the ByteReader interface
///
/// This implementation has no special features, cannot expand its size,
/// and may be invalidated if another function causes the original memory to relocate or shrink
pub const SimpleByteReader = struct {
    buffer: []const u8,
    read_pos: usize,

    /// Instantiate a new SimpleByteReader using the provided buffer.
    pub fn new(initial_buffer: []const u8) SimpleByteReader {
        return SimpleByteReader{
            .buffer = initial_buffer,
            .read_pos = 0,
        };
    }

    pub fn reset(self: *SimpleByteReader) void {
        self.read_pos = 0;
    }

    /// Get the actual ByteReader interface object
    pub fn byte_reader(self: *SimpleByteReader) ByteReader {
        return ByteReader{
            ._opaque = @ptrCast(self),
            ._vtable = VTable{
                .get_unread_buffer = get_unread_buffer,
                .advance_read_pos = advance_read_pos,
            },
        };
    }

    fn get_unread_buffer(self_opaque: *anyopaque) []const u8 {
        const self: *SimpleByteReader = @ptrCast(@alignCast(self_opaque));
        return self.buffer[self.read_pos..];
    }

    fn advance_read_pos(self_opaque: *anyopaque, byte_count: usize) void {
        const self: *SimpleByteReader = @ptrCast(@alignCast(self_opaque));
        const new_read_pos = self.read_pos + byte_count;
        assert(new_read_pos <= self.buffer.len);
        self.read_pos = new_read_pos;
    }
};
