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
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;

pub const ClearOldMode = enum(u8) {
    dont_memset_old,
    memset_old_undefined,
    force_memset_old_undefined,
    memset_old_zero,
    force_memset_old_zero,
};
pub const InitNewMode = enum(u8) {
    dont_memset_new,
    memset_new_undefined,
    force_memset_new_undefined,
    memset_new_zero,
    force_memset_new_zero,
    memset_new_custom,
    force_memset_new_custom,
};
pub const CopyMode = enum(u8) {
    dont_copy_data,
    copy_data,
};
pub fn InitNew(comptime T: type) type {
    return union(InitNewMode) {
        const Self = @This();

        dont_memset_new: void,
        memset_new_undefined: void,
        force_memset_new_undefined: void,
        memset_new_zero: void,
        force_memset_new_zero: void,
        memset_new_custom: T,
        force_memset_new_custom: T,

        pub fn init_new_custom_orelse_undefined(val: anytype) Self {
            const V = @TypeOf(val);
            if (Types.type_is_optional(V)) {
                if (val) |v| {
                    assert_with_reason(@TypeOf(v) == T, @src(), "type of `val` was not a T or ?T, got type `{s}`", .{@typeName(@TypeOf(val))});
                    return Self{ .memset_new_custom = v };
                } else {
                    return Self{ .memset_new_undefined = void{} };
                }
            } else {
                assert_with_reason(V == T, @src(), "type of `val` was not a T or ?T, got type `{s}`", .{@typeName(@TypeOf(val))});
                return Self{ .memset_new_undefined = void{} };
            }
        }
        pub fn init_new_custom_orelse_zero(val: anytype) Self {
            const V = @TypeOf(val);
            if (Types.type_is_optional(V)) {
                if (val) |v| {
                    assert_with_reason(@TypeOf(v) == T, @src(), "type of `val` was not a T or ?T, got type `{s}`", .{@typeName(@TypeOf(val))});
                    return Self{ .memset_new_custom = v };
                } else {
                    return Self{ .memset_new_zero = void{} };
                }
            } else {
                assert_with_reason(V == T, @src(), "type of `val` was not a T or ?T, got type `{s}`", .{@typeName(@TypeOf(val))});
                return Self{ .memset_new_zero = void{} };
            }
        }
    };
}

pub const AlignMode = enum(u8) {
    ALIGN_TO_TYPE,
    CUSTOM_ALIGN,
};

pub const Align = union(AlignMode) {
    ALIGN_TO_TYPE: void,
    CUSTOM_ALIGN: usize,

    pub fn align_to_type() Align {
        return Align{ .ALIGN_TO_TYPE = void{} };
    }
    pub fn custom_align(alignment: usize) Align {
        return Align{ .CUSTOM_ALIGN = alignment };
    }

    pub fn get_align(self: Align, type_align: usize) usize {
        return switch (self) {
            .ALIGN_TO_TYPE => type_align,
            .CUSTOM_ALIGN => |a| a,
        };
    }
};

pub fn realloc_custom(alloc: Allocator, old_mem: anytype, new_n: usize, comptime align_mode: Align, copy_mode: CopyMode, init_new_mode: InitNew(@typeInfo(@TypeOf(old_mem)).pointer.child), clear_old_mode: ClearOldMode) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    break :t Allocator.Error![]align(Slice.alignment) Slice.child;
} {
    //COPIED FROM Allocator.zig
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    const ALIGN = comptime align_mode.get_align(Slice.alignment);
    const T = Slice.child;
    if (old_mem.len == 0) {
        return alloc.allocAdvancedWithRetAddr(T, .fromByteUnits(ALIGN), new_n, @returnAddress());
    }
    if (new_n == 0) {
        alloc.free(old_mem);
        const ptr = comptime std.mem.alignBackward(usize, math.maxInt(usize), ALIGN);
        return @as([*]align(ALIGN) T, @ptrFromInt(ptr))[0..0];
    }

    const old_byte_slice = mem.sliceAsBytes(old_mem);
    const byte_count = math.mul(usize, @sizeOf(T), new_n) catch return Allocator.Error.OutOfMemory;
    // Note: can't set shrunk memory to undefined as memory shouldn't be modified on realloc failure
    if (alloc.rawRemap(old_byte_slice, .fromByteUnits(ALIGN), byte_count, @returnAddress())) |p| {
        const new_bytes: []align(ALIGN) u8 = @alignCast(p[0..byte_count]);
        return mem.bytesAsSlice(T, new_bytes);
    }

    const new_mem = alloc.rawAlloc(byte_count, .fromByteUnits(ALIGN), @returnAddress()) orelse
        return error.OutOfMemory;
    const new_bytes: []align(ALIGN) u8 = @alignCast(new_mem[0..byte_count]);
    const new_mem_types = mem.bytesAsSlice(T, new_bytes);
    const copy_len = @min(byte_count, old_byte_slice.len);
    switch (copy_mode) {
        .copy_data => {
            @memcpy(new_mem[0..copy_len], old_byte_slice[0..copy_len]);
        },
        .dont_copy_data => {},
    }
    switch (clear_old_mode) {
        .memset_old_undefined => {
            @memset(old_byte_slice, undefined);
        },
        .force_memset_old_undefined => {
            Utils.secure_memset_undefined(u8, old_byte_slice);
        },
        .memset_old_zero => {
            @memset(old_byte_slice, 0);
        },
        .force_memset_old_zero => {
            Utils.secure_zero(u8, old_byte_slice);
        },
        .dont_memset_old => {},
    }
    switch (init_new_mode) {
        .memset_new_undefined => {
            switch (copy_mode) {
                .copy_data => @memset(new_mem[copy_len..byte_count], undefined),
                .dont_copy_data => @memset(new_mem[0..byte_count], undefined),
            }
        },
        .force_memset_new_undefined => {
            switch (copy_mode) {
                .copy_data => Utils.secure_memset_undefined(u8, new_mem[copy_len..byte_count]),
                .dont_copy_data => Utils.secure_memset_undefined(u8, new_mem[0..byte_count]),
            }
        },
        .memset_new_zero => {
            switch (copy_mode) {
                .copy_data => @memset(new_mem[copy_len..byte_count], 0),
                .dont_copy_data => @memset(new_mem[0..byte_count], 0),
            }
        },
        .force_memset_new_zero => {
            switch (copy_mode) {
                .copy_data => Utils.secure_zero(u8, new_mem[copy_len..byte_count]),
                .dont_copy_data => Utils.secure_zero(u8, new_mem[0..byte_count]),
            }
        },
        .memset_new_custom => |init_val| {
            switch (copy_mode) {
                .copy_data => @memset(new_mem_types[@divExact(copy_len, @sizeOf(T))..@divExact(byte_count, @sizeOf(T))], init_val),
                .dont_copy_data => @memset(new_mem[0..@divExact(byte_count, @sizeOf(T))], init_val),
            }
        },
        .force_memset_new_custom => |init_val| {
            switch (copy_mode) {
                .copy_data => Utils.secure_memset(T, new_mem_types[@divExact(copy_len, @sizeOf(T))..@divExact(byte_count, @sizeOf(T))], init_val),
                .dont_copy_data => Utils.secure_memset(T, new_mem_types[0..@divExact(byte_count, @sizeOf(T))], init_val),
            }
        },
        .dont_memset_new => {},
    }
    alloc.rawFree(old_byte_slice, .fromByteUnits(ALIGN), @returnAddress());
    return new_mem_types;
}
