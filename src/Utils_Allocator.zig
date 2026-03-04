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
pub const AllocErr = std.mem.Allocator.Error;

pub const ExpandMode = enum(u8) {
    ALLOC_EXACT_NEEDED,
    ALLOC_ONE_AND_A_QUARTER_NEEDED,
    ALLOC_ONE_AND_A_HALF_NEEDED,
    ALLOC_DOUBLE_NEEDED,
};

pub fn SmartAllocSettings(comptime CHILD_TYPE: type) type {
    return struct {
        align_mode: Align = .ALIGN_TO_TYPE,
        copy_mode: CopyMode = .COPY_EXISTING_DATA,
        init_new_mode: InitNew(CHILD_TYPE) = .dont_memset_new(),
        clear_old_mode: ClearOldMode = .DONT_MEMSET_OLD,
        expand_mode: ExpandMode = .ALLOC_EXACT_NEEDED,
    };
}

pub const SmartAllocComptimeSettings = struct {
    ERROR_MODE: ErrorBehavior = .ERRORS_ARE_UNREACHABLE,
};

pub fn smart_alloc(alloc: Allocator, old_mem_slice: anytype, new_cap: usize, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_mem_slice))), comptime comptime_settings: SmartAllocComptimeSettings) t: {
    const Slice = @typeInfo(@TypeOf(old_mem_slice)).pointer;
    switch (comptime_settings.ERROR_MODE) {
        .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => {
            break :t AllocErr![]align(Slice.alignment) Slice.child;
        },
        .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => {
            break :t []align(Slice.alignment) Slice.child;
        },
    }
} {
    if (old_mem_slice.len == new_cap) return old_mem_slice;
    const Slice = @typeInfo(@TypeOf(old_mem_slice)).pointer;
    const ALIGN = settings.align_mode.get_align(Slice.alignment);
    const T = Slice.child;
    const old_byte_len = @sizeOf(T) * old_mem_slice.len;
    const new_byte_len = @sizeOf(T) * new_cap;
    if (old_byte_len == 0) {
        const new_ptr: [*]u8 = alloc.rawAlloc(new_byte_len, .fromByteUnits(ALIGN), @returnAddress()) orelse return comptime_settings.ERROR_MODE.handle(@src(), AllocErr.OutOfMemory);
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..new_cap];
    }
    if (new_byte_len == 0) {
        alloc.free(old_mem_slice);
        return Utils.invalid_slice(T);
    }
    const old_byte_slice = mem.sliceAsBytes(old_mem_slice);

    if (alloc.rawRemap(old_byte_slice, .fromByteUnits(ALIGN), new_byte_len, @returnAddress())) |new_ptr| {
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..new_cap];
    }

    const new_ptr: [*]u8 = alloc.rawAlloc(new_byte_len, .fromByteUnits(ALIGN), @returnAddress()) orelse return comptime_settings.ERROR_MODE.handle(@src(), AllocErr.OutOfMemory);
    const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
    const new_mem: []T = new_ptr_cast[0..new_cap];
    const copy_len = @min(new_byte_len, old_byte_len);
    switch (settings.copy_mode) {
        .COPY_EXISTING_DATA => {
            @memcpy(new_ptr[0..copy_len], old_byte_slice[0..copy_len]);
            if (new_byte_len > copy_len) {
                switch (settings.init_new_mode) {
                    .MEMSET_NEW_UNDEFINED => {
                        @memset(new_ptr[copy_len..new_byte_len], undefined);
                    },
                    .FORCE_MEMSET_NEW_UNDEFINED => {
                        Utils.secure_memset_undefined(u8, new_ptr[copy_len..new_byte_len]);
                    },
                    .MEMSET_NEW_ZERO => {
                        @memset(new_ptr[copy_len..new_byte_len], 0);
                    },
                    .FORCE_MEMSET_NEW_ZERO => {
                        Utils.secure_zero(u8, new_ptr[copy_len..new_byte_len]);
                    },
                    .MEMSET_NEW_CUSTOM => |init_val| {
                        @memset(new_mem[@divExact(copy_len, @sizeOf(T))..@divExact(new_byte_len, @sizeOf(T))], init_val);
                    },
                    .FORCE_MEMSET_NEW_CUSTOM => |init_val| {
                        Utils.secure_memset(T, new_mem[@divExact(copy_len, @sizeOf(T))..@divExact(new_byte_len, @sizeOf(T))], init_val);
                    },
                    .DONT_MEMSET_NEW => {},
                }
            }
        },
        .DONT_COPY_EXISTING_DATA => {
            switch (settings.init_new_mode) {
                .MEMSET_NEW_UNDEFINED => {
                    @memset(new_ptr[0..new_byte_len], undefined);
                },
                .FORCE_MEMSET_NEW_UNDEFINED => {
                    Utils.secure_memset_undefined(u8, new_ptr[0..new_byte_len]);
                },
                .MEMSET_NEW_ZERO => {
                    @memset(new_ptr[0..new_byte_len], 0);
                },
                .FORCE_MEMSET_NEW_ZERO => {
                    Utils.secure_zero(u8, new_ptr[0..new_byte_len]);
                },
                .MEMSET_NEW_CUSTOM => |init_val| {
                    @memset(new_mem[0..@divExact(new_byte_len, @sizeOf(T))], init_val);
                },
                .FORCE_MEMSET_NEW_CUSTOM => |init_val| {
                    Utils.secure_memset(T, new_mem[0..@divExact(new_byte_len, @sizeOf(T))], init_val);
                },
                .DONT_MEMSET_NEW => {},
            }
        },
    }
    switch (settings.clear_old_mode) {
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
    alloc.rawFree(old_byte_slice, .fromByteUnits(ALIGN), @returnAddress());
    return new_mem;
}

pub fn smart_alloc_ptr_ptrs(alloc: Allocator, old_mem_ptr_ptr: anytype, old_mem_cap_ptr: anytype, new_cap: usize, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_mem_ptr_ptr.*))), comptime comptime_settings: SmartAllocComptimeSettings) switch (comptime_settings.ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => AllocErr!void,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => void,
} {
    const old_mem = old_mem_ptr_ptr.*[0..old_mem_cap_ptr.*];
    const new_mem = if (comptime comptime_settings.ERROR_MODE.does_error()) ( //
        try smart_alloc(alloc, old_mem, new_cap, settings, comptime_settings)) //
        else smart_alloc(alloc, old_mem, new_cap, settings, comptime_settings);
    old_mem_ptr_ptr.* = new_mem.ptr;
    old_mem_cap_ptr.* = @intCast(new_mem.len);
    return;
}
