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
    DONT_MEMSET_OLD,
    MEMSET_OLD_UNDEFINED,
    FORCE_MEMSET_OLD_UNDEFINED,
    MEMSET_OLD_ZERO,
    FORCE_MEMSET_OLD_ZERO,
};
pub const InitNewMode = enum(u8) {
    DONT_MEMSET_NEW,
    MEMSET_NEW_UNDEFINED,
    FORCE_MEMSET_NEW_UNDEFINED,
    MEMSET_NEW_ZERO,
    FORCE_MEMSET_NEW_ZERO,
    MEMSET_NEW_CUSTOM,
    FORCE_MEMSET_NEW_CUSTOM,
};
pub const CopyMode = enum(u8) {
    DONT_COPY_EXISTING_DATA,
    COPY_EXISTING_DATA,
};
pub fn InitNew(comptime T: type) type {
    return union(InitNewMode) {
        const Self = @This();

        DONT_MEMSET_NEW: void,
        MEMSET_NEW_UNDEFINED: void,
        FORCE_MEMSET_NEW_UNDEFINED: void,
        MEMSET_NEW_ZERO: void,
        FORCE_MEMSET_NEW_ZERO: void,
        MEMSET_NEW_CUSTOM: T,
        FORCE_MEMSET_NEW_CUSTOM: T,

        pub inline fn dont_memset_new() Self {
            return Self{ .DONT_MEMSET_NEW = void{} };
        }
        pub inline fn memset_new_undefined() Self {
            return Self{ .MEMSET_NEW_UNDEFINED = void{} };
        }
        pub inline fn force_memset_new_undefined() Self {
            return Self{ .FORCE_MEMSET_NEW_UNDEFINED = void{} };
        }
        pub inline fn memset_new_zero() Self {
            return Self{ .MEMSET_NEW_ZERO = void{} };
        }
        pub inline fn force_memset_new_zero() Self {
            return Self{ .FORCE_MEMSET_NEW_ZERO = void{} };
        }
        pub inline fn memset_new_custom(val: T) Self {
            return Self{ .MEMSET_NEW_CUSTOM = val };
        }
        pub inline fn force_memset_new_custom(val: T) Self {
            return Self{ .FORCE_MEMSET_NEW_CUSTOM = val };
        }

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

pub const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
pub const MemError = std.mem.Allocator.Error;

pub fn smart_alloc(alloc: Allocator, old_mem_slice: anytype, new_cap: usize, align_mode: Align, copy_mode: CopyMode, init_new_mode: InitNew(@typeInfo(@TypeOf(old_mem_slice)).pointer.child), clear_old_mode: ClearOldMode, comptime ERROR_MODE: ErrorBehavior) t: {
    const Slice = @typeInfo(@TypeOf(old_mem_slice)).pointer;
    switch (ERROR_MODE) {
        .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => {
            break :t Allocator.Error![]align(Slice.alignment) Slice.child;
        },
        .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => {
            break :t []align(Slice.alignment) Slice.child;
        },
    }
} {
    if (old_mem_slice.len == new_cap) return old_mem_slice;
    const Slice = @typeInfo(@TypeOf(old_mem_slice)).pointer;
    const ALIGN = align_mode.get_align(Slice.alignment);
    const T = Slice.child;
    const OLD_BYTE_LEN = @sizeOf(T) * old_mem_slice.len;
    const NEW_BYTE_LEN = @sizeOf(T) * new_cap;
    if (OLD_BYTE_LEN == 0) {
        const new_ptr: [*]u8 = alloc.rawAlloc(NEW_BYTE_LEN, .fromByteUnits(ALIGN), @returnAddress()) orelse return ERROR_MODE.handle(@src(), MemError.OutOfMemory);
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..new_cap];
    }
    if (NEW_BYTE_LEN == 0) {
        alloc.free(old_mem_slice);
        return Utils.invalid_slice(T);
    }
    const old_byte_slice = mem.sliceAsBytes(old_mem_slice);

    if (alloc.rawRemap(old_byte_slice, .fromByteUnits(ALIGN), NEW_BYTE_LEN, @returnAddress())) |new_ptr| {
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..new_cap];
    }

    const new_ptr: [*]u8 = alloc.rawAlloc(NEW_BYTE_LEN, .fromByteUnits(ALIGN), @returnAddress()) orelse return ERROR_MODE.handle(@src(), MemError.OutOfMemory);
    const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
    const new_mem: []T = new_ptr_cast[0..new_cap];
    const copy_len = @min(NEW_BYTE_LEN, OLD_BYTE_LEN);
    switch (copy_mode) {
        .COPY_EXISTING_DATA => {
            @memcpy(new_ptr[0..copy_len], old_byte_slice[0..copy_len]);
        },
        .DONT_COPY_EXISTING_DATA => {},
    }
    switch (clear_old_mode) {
        .MEMSET_OLD_UNDEFINED => {
            @memset(old_byte_slice, undefined);
        },
        .FORCE_MEMSET_OLD_UNDEFINED => {
            Utils.secure_memset_undefined(u8, old_byte_slice);
        },
        .MEMSET_OLD_ZERO => {
            @memset(old_byte_slice, 0);
        },
        .FORCE_MEMSET_OLD_ZERO => {
            Utils.secure_zero(u8, old_byte_slice);
        },
        .DONT_MEMSET_OLD => {},
    }
    switch (init_new_mode) {
        .MEMSET_NEW_UNDEFINED => {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => @memset(new_ptr[copy_len..NEW_BYTE_LEN], undefined),
                .DONT_COPY_EXISTING_DATA => @memset(new_ptr[0..NEW_BYTE_LEN], undefined),
            }
        },
        .FORCE_MEMSET_NEW_UNDEFINED => {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => Utils.secure_memset_undefined(u8, new_ptr[copy_len..NEW_BYTE_LEN]),
                .DONT_COPY_EXISTING_DATA => Utils.secure_memset_undefined(u8, new_ptr[0..NEW_BYTE_LEN]),
            }
        },
        .MEMSET_NEW_ZERO => {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => @memset(new_ptr[copy_len..NEW_BYTE_LEN], 0),
                .DONT_COPY_EXISTING_DATA => @memset(new_ptr[0..NEW_BYTE_LEN], 0),
            }
        },
        .FORCE_MEMSET_NEW_ZERO => {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => Utils.secure_zero(u8, new_ptr[copy_len..NEW_BYTE_LEN]),
                .DONT_COPY_EXISTING_DATA => Utils.secure_zero(u8, new_ptr[0..NEW_BYTE_LEN]),
            }
        },
        .MEMSET_NEW_CUSTOM => |init_val| {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => @memset(new_mem[@divExact(copy_len, @sizeOf(T))..@divExact(NEW_BYTE_LEN, @sizeOf(T))], init_val),
                .DONT_COPY_EXISTING_DATA => @memset(new_mem[0..@divExact(NEW_BYTE_LEN, @sizeOf(T))], init_val),
            }
        },
        .FORCE_MEMSET_NEW_CUSTOM => |init_val| {
            switch (copy_mode) {
                .COPY_EXISTING_DATA => Utils.secure_memset(T, new_mem[@divExact(copy_len, @sizeOf(T))..@divExact(NEW_BYTE_LEN, @sizeOf(T))], init_val),
                .DONT_COPY_EXISTING_DATA => Utils.secure_memset(T, new_mem[0..@divExact(NEW_BYTE_LEN, @sizeOf(T))], init_val),
            }
        },
        .DONT_MEMSET_NEW => {},
    }
    alloc.rawFree(old_byte_slice, .fromByteUnits(ALIGN), @returnAddress());
    return new_mem;
}

pub fn smart_alloc_ptr_ptrs(alloc: Allocator, old_mem_ptr_ptr: anytype, old_mem_cap_ptr: anytype, new_n: usize, align_mode: Align, copy_mode: CopyMode, init_new_mode: InitNew(@typeInfo(@typeInfo(@TypeOf(old_mem_ptr_ptr)).pointer.child).pointer.child), clear_old_mode: ClearOldMode, comptime ERROR_MODE: ErrorBehavior) switch (ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => MemError!void,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => void,
} {
    const old_mem = old_mem_ptr_ptr.*[0..old_mem_cap_ptr.*];
    const new_mem = if (comptime ERROR_MODE.does_error()) ( //
        smart_alloc(alloc, old_mem, new_n, align_mode, copy_mode, init_new_mode, clear_old_mode, ERROR_MODE) catch |err| ERROR_MODE.panic(@src(), err)) //
        else smart_alloc(alloc, old_mem, new_n, align_mode, copy_mode, init_new_mode, clear_old_mode, ERROR_MODE);
    old_mem_ptr_ptr.* = new_mem.ptr;
    old_mem_cap_ptr.* = @intCast(new_mem.len);
    return;
}
