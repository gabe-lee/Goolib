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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const fmt = std.fmt;
const math = std.math;

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const BinarySearch = Root.BinarySearch;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;

pub fn realloc_no_memset(alloc: Allocator, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    break :t Allocator.Error![]align(Slice.alignment) Slice.child;
} {
    //COPIED FROM Allocator.zig
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    const T = Slice.child;
    if (old_mem.len == 0) {
        return alloc.allocAdvancedWithRetAddr(T, .fromByteUnits(Slice.alignment), new_n, @returnAddress());
    }
    if (new_n == 0) {
        alloc.free(old_mem);
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), Slice.alignment);
        return @as([*]align(Slice.alignment) T, @ptrFromInt(ptr))[0..0];
    }

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Allocator.Error.OutOfMemory;
    // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
    if (alloc.rawRemap(old_byte_slice, .fromByteUnits(Slice.alignment), byte_count, @returnAddress())) |p| {
        const new_bytes: []align(Slice.alignment) u8 = @alignCast(p[0..byte_count]);
        return mem.bytesAsSlice(T, new_bytes);
    }

    const new_mem = alloc.rawAlloc(byte_count, .fromByteUnits(Slice.alignment), @returnAddress()) orelse
        return error.OutOfMemory;
    const copy_len = @min(byte_count, old_byte_slice.len);
    @memcpy(new_mem[0..copy_len], old_byte_slice[0..copy_len]);
    // @memset(old_byte_slice, undefined);
    alloc.rawFree(old_byte_slice, .fromByteUnits(Slice.alignment), @returnAddress());

    const new_bytes: []align(Slice.alignment) u8 = @alignCast(new_mem[0..byte_count]);
    return mem.bytesAsSlice(T, new_bytes);
}
