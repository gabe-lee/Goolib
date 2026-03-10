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
const GrowthMode = Root.CommonTypes.GrowthModel;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

const CACHE_LINE = std.atomic.cache_line;

const DEBUG = std.debug.print;

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

// pub const ExpandMode = enum(u8) {
//     ALLOC_EXACT_NEEDED,
//     ALLOC_ONE_AND_A_QUARTER_NEEDED,
//     ALLOC_ONE_AND_A_HALF_NEEDED,
//     ALLOC_DOUBLE_NEEDED,
// };

pub fn SmartAllocSettings(comptime CHILD_TYPE: type) type {
    return struct {
        align_mode: Align = .ALIGN_TO_TYPE,
        copy_mode: CopyMode = .COPY_EXISTING_DATA,
        init_new_mode: InitNew(CHILD_TYPE) = .dont_memset_new(),
        clear_old_mode: ClearOldMode = .DONT_MEMSET_OLD,
        grow_mode: GrowthMode = .GROW_EXACT_NEEDED,
    };
}

pub const DebugConditionKind = enum(u8) {
    ALWAYS,
    POINTER_ADDRESS_EQUALS,
    POINTER_ADDRESS_GREATER_THAN_OR_EQUAL,
    CALLSITE_ARG_EQUALS,
};

pub const DebugCondition = union(DebugConditionKind) {
    ALWAYS: void,
    POINTER_ADDRESS_EQUALS: usize,
    POINTER_ADDRESS_GREATER_THAN_OR_EQUAL: usize,
    CALLSITE_ARG_EQUALS: *const anyopaque,

    pub fn always_debug() DebugCondition {
        return DebugCondition{ .ALWAYS = void{} };
    }
    pub fn debug_when_pointer_address_equals(addr: usize) DebugCondition {
        return DebugCondition{ .POINTER_ADDRESS_EQUALS = addr };
    }
    pub fn debug_when_pointer_address_greater_than_or_equal(addr: usize) DebugCondition {
        return DebugCondition{ .POINTER_ADDRESS_GREATER_THAN_OR_EQUAL = addr };
    }
    pub fn debug_when_pointer_address_falls_within_utils_invalid_for_max_align_64() DebugCondition {
        return DebugCondition{ .POINTER_ADDRESS_GREATER_THAN_OR_EQUAL = std.mem.alignBackward(usize, std.math.maxInt(usize), 64) };
    }
    pub fn debug_when_callsite_arg_equals(arg: *const anyopaque) DebugCondition {
        return DebugCondition{ .CALLSITE_ARG_EQUALS = arg };
    }

    pub fn should_debug(comptime self: ?DebugCondition, current_mem: []u8, comptime arg: ?*const anyopaque, comptime arg_type: ?type) bool {
        if (self) |cond| {
            switch (cond) {
                .ALWAYS => {
                    return true;
                },
                .POINTER_ADDRESS_EQUALS => |match_addr| {
                    return match_addr == @intFromPtr(current_mem.ptr);
                },
                .POINTER_ADDRESS_GREATER_THAN_OR_EQUAL => |min_addr| {
                    return @intFromPtr(current_mem.ptr) >= min_addr;
                },
                .CALLSITE_ARG_EQUALS => |match_arg| {
                    const match: *const arg_type.? = @ptrCast(@alignCast(match_arg));
                    const got: *const arg_type.? = @ptrCast(@alignCast(arg.?));
                    return match.* == got.*;
                },
            }
        } else {
            return false;
        }
    }
};

/// These settings will ALWAYS override the ones in `SmartAllocSettings`
pub fn SmartAllocComptimeSettings(comptime CHILD_TYPE: type) type {
    return struct {
        ALIGN_MODE: ?Align = null,
        COPY_MODE: ?CopyMode = null,
        INIT_NEW_MODE: ?InitNew(CHILD_TYPE) = null,
        CLEAR_OLD_MODE: ?ClearOldMode = null,
        GROW_MODE: ?GrowthMode = null,
        ERROR_MODE: ErrorBehavior = .ERRORS_ARE_UNREACHABLE,
        CALLSITE: ?std.builtin.SourceLocation = null,
        CALLSITE_FMT: ?[]const u8 = null,
        CALLSITE_ARGS_OPAQUE: ?*const anyopaque = null,
        CALLSITE_ARGS_TYPE: ?type = null,
        CONDITIONAL_DEBUG: ?DebugCondition = null,

        pub fn DEBUG(comptime self: @This(), comptime SRC: std.builtin.SourceLocation) @This() {
            return @This(){
                .ALIGN_MODE = self.ALIGN_MODE,
                .COPY_MODE = self.COPY_MODE,
                .INIT_NEW_MODE = self.INIT_NEW_MODE,
                .CLEAR_OLD_MODE = self.CLEAR_OLD_MODE,
                .GROW_MODE = self.GROW_MODE,
                .ERROR_MODE = self.ERROR_MODE,
                .CALLSITE = SRC,
            };
        }
        pub fn DEBUG_COND(comptime self: @This(), comptime SRC: std.builtin.SourceLocation, comptime COND: DebugCondition) @This() {
            return @This(){
                .ALIGN_MODE = self.ALIGN_MODE,
                .COPY_MODE = self.COPY_MODE,
                .INIT_NEW_MODE = self.INIT_NEW_MODE,
                .CLEAR_OLD_MODE = self.CLEAR_OLD_MODE,
                .GROW_MODE = self.GROW_MODE,
                .ERROR_MODE = self.ERROR_MODE,
                .CALLSITE = SRC,
                .CONDITIONAL_DEBUG = COND,
            };
        }

        pub fn DEBUG_WITH_CONTEXT(comptime self: @This(), comptime SRC: std.builtin.SourceLocation, comptime FMT: []const u8, comptime ARGS_OPAQUE: *const anyopaque, comptime ARGS_TYPE: type) @This() {
            return @This(){
                .ALIGN_MODE = self.ALIGN_MODE,
                .COPY_MODE = self.COPY_MODE,
                .INIT_NEW_MODE = self.INIT_NEW_MODE,
                .CLEAR_OLD_MODE = self.CLEAR_OLD_MODE,
                .GROW_MODE = self.GROW_MODE,
                .ERROR_MODE = self.ERROR_MODE,
                .CALLSITE = SRC,
                .CALLSITE_FMT = FMT,
                .CALLSITE_ARGS_OPAQUE = ARGS_OPAQUE,
                .CALLSITE_ARGS_TYPE = ARGS_TYPE,
            };
        }
        pub fn DEBUG_WITH_CONTEXT_COND(comptime self: @This(), comptime SRC: std.builtin.SourceLocation, comptime COND: DebugCondition, comptime FMT: []const u8, comptime ARGS_OPAQUE: *const anyopaque, comptime ARGS_TYPE: type) @This() {
            return @This(){
                .ALIGN_MODE = self.ALIGN_MODE,
                .COPY_MODE = self.COPY_MODE,
                .INIT_NEW_MODE = self.INIT_NEW_MODE,
                .CLEAR_OLD_MODE = self.CLEAR_OLD_MODE,
                .GROW_MODE = self.GROW_MODE,
                .ERROR_MODE = self.ERROR_MODE,
                .CALLSITE = SRC,
                .CALLSITE_FMT = FMT,
                .CALLSITE_ARGS_OPAQUE = ARGS_OPAQUE,
                .CALLSITE_ARGS_TYPE = ARGS_TYPE,
                .CONDITIONAL_DEBUG = COND,
            };
        }
    };
}

pub fn smart_alloc(alloc: Allocator, old_mem_slice: anytype, new_cap: usize, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_mem_slice))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_type(@TypeOf(old_mem_slice)))) t: {
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
    const Slice = @typeInfo(@TypeOf(old_mem_slice)).pointer;
    const GROW = if (comptime_settings.GROW_MODE) |MODE| MODE else settings.grow_mode;
    const ALIGN = if (comptime_settings.ALIGN_MODE) |MODE| MODE.get_align(Slice.alignment) else settings.align_mode.get_align(Slice.alignment);
    const COPY = if (comptime_settings.COPY_MODE) |MODE| MODE else settings.copy_mode;
    const INIT_NEW = if (comptime_settings.INIT_NEW_MODE) |MODE| MODE else settings.init_new_mode;
    const CLEAR_OLD = if (comptime_settings.CLEAR_OLD_MODE) |MODE| MODE else settings.clear_old_mode;
    if (old_mem_slice.len == new_cap) return old_mem_slice;
    const T = Slice.child;
    const real_new_cap = if (old_mem_slice.len < new_cap) switch (GROW) {
        .GROW_EXACT_NEEDED => new_cap,
        .GROW_EXACT_NEEDED_ATOMIC_PADDING => new_cap + CACHE_LINE,
        .GROW_BY_25_PERCENT => new_cap + (new_cap >> 2),
        .GROW_BY_25_PERCENT_ATOMIC_PADDING => new_cap + (new_cap >> 2) + CACHE_LINE,
        .GROW_BY_50_PERCENT => new_cap + (new_cap >> 1),
        .GROW_BY_50_PERCENT_ATOMIC_PADDING => new_cap + (new_cap >> 1) + CACHE_LINE,
        .GROW_BY_100_PERCENT => new_cap << 1,
        .GROW_BY_100_PERCENT_ATOMIC_PADDING => (new_cap << 1) + CACHE_LINE,
    } else new_cap;
    const old_byte_len = @sizeOf(T) * old_mem_slice.len;
    const new_byte_len = @sizeOf(T) * real_new_cap;
    if (old_byte_len == 0) {
        const new_ptr: [*]u8 = alloc.rawAlloc(new_byte_len, .fromByteUnits(ALIGN), @returnAddress()) orelse return comptime_settings.ERROR_MODE.handle(@src(), AllocErr.OutOfMemory);
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..real_new_cap];
    }
    const old_byte_slice = mem.sliceAsBytes(old_mem_slice);
    if (DebugCondition.should_debug(comptime_settings.CONDITIONAL_DEBUG, old_byte_slice, comptime_settings.CALLSITE_ARGS_OPAQUE, comptime_settings.CALLSITE_ARGS_TYPE)) {
        if (comptime_settings.CALLSITE_FMT) |FMT| {
            assert_unreachable(if (comptime_settings.CALLSITE) |site| site else @src(), FMT, Utils.dereference_opaque(comptime_settings.CALLSITE_ARGS_OPAQUE.?, comptime_settings.CALLSITE_ARGS_TYPE.?));
        } else {
            assert_unreachable(if (comptime_settings.CALLSITE) |site| site else @src(), "\nsmart_alloc debug triggered: {any}\n", .{comptime_settings.CONDITIONAL_DEBUG.?});
        }
    }
    if (new_byte_len == 0) {
        alloc.rawFree(old_byte_slice, .fromByteUnits(ALIGN), @returnAddress());
        return Utils.invalid_slice(T);
    }

    if (alloc.rawRemap(old_byte_slice, .fromByteUnits(ALIGN), new_byte_len, @returnAddress())) |new_ptr| {
        const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
        return new_ptr_cast[0..real_new_cap];
    }

    const new_ptr: [*]u8 = alloc.rawAlloc(new_byte_len, .fromByteUnits(ALIGN), @returnAddress()) orelse return comptime_settings.ERROR_MODE.handle(@src(), AllocErr.OutOfMemory);
    const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
    const new_mem: []T = new_ptr_cast[0..real_new_cap];
    const copy_len = @min(new_byte_len, old_byte_len);
    switch (COPY) {
        .COPY_EXISTING_DATA => {
            @memcpy(new_ptr[0..copy_len], old_byte_slice[0..copy_len]);
            if (new_byte_len > copy_len) {
                switch (INIT_NEW) {
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
            switch (INIT_NEW) {
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
    switch (CLEAR_OLD) {
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

pub fn smart_alloc_ptr_ptrs(alloc: Allocator, old_mem_ptr_ptr: anytype, old_mem_cap_ptr: anytype, new_cap: usize, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_mem_ptr_ptr.*))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_type(@TypeOf(old_mem_ptr_ptr.*)))) switch (comptime_settings.ERROR_MODE) {
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
