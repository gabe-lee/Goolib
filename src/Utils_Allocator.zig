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
const warn_unconditional = Assert.warn_unconditional;
const assert_unreachable_always_panic = Assert.assert_unreachable_always_panic;
const num_cast = Root.Cast.num_cast;
const KindInfo = Types.KindInfo;

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
    ALIGN_TO_MAX_OF_TYPE_AND_CACHE_LINE,
    CUSTOM_ALIGN,
};

pub const Align = union(AlignMode) {
    ALIGN_TO_TYPE: void,
    ALIGN_TO_MAX_OF_TYPE_AND_CACHE_LINE: void,
    CUSTOM_ALIGN: usize,

    pub fn align_to_type() Align {
        return Align{ .ALIGN_TO_TYPE = void{} };
    }
    pub fn align_to_max_of_type_and_cache_line() Align {
        return Align{ .ALIGN_TO_MAX_OF_TYPE_AND_CACHE_LINE = void{} };
    }
    pub fn custom_align(alignment: usize) Align {
        return Align{ .CUSTOM_ALIGN = alignment };
    }

    pub fn get_align(self: Align, type_align: usize) usize {
        return switch (self) {
            .ALIGN_TO_TYPE => type_align,
            .ALIGN_TO_MAX_OF_TYPE_AND_CACHE_LINE => @max(CACHE_LINE, type_align),
            .CUSTOM_ALIGN => |a| a,
        };
    }
};

pub const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
pub const AllocErr = std.mem.Allocator.Error;

pub fn SmartAllocSettings(comptime CHILD_TYPE: type) type {
    return struct {
        old_align: Align = .ALIGN_TO_TYPE,
        new_align: Align = .ALIGN_TO_TYPE,
        copy_mode: CopyMode = .COPY_EXISTING_DATA,
        init_new_mode: InitNew(CHILD_TYPE) = .dont_memset_new(),
        clear_old_mode: ClearOldMode = .DONT_MEMSET_OLD,
        grow_mode: GrowthMode = .GROW_EXACT_NEEDED,
        trigger_debug_userdata: ?*anyopaque = null,
    };
}

pub const DebugConditionKind = enum(u8) {
    ALWAYS,
    POINTER_ADDRESS_EQUALS,
    POINTER_ADDRESS_GREATER_THAN_OR_EQUAL,
    CALLSITE_ARG_EQUALS,
};

pub const DebugTrigger = fn (state: AllocDebugState) AllocDebugTestResult;

/// These settings will ALWAYS override the ones in `SmartAllocSettings`
pub fn SmartAllocComptimeSettings(comptime CHILD_TYPE: type) type {
    return struct {
        OLD_ALIGN: ?Align = null,
        NEW_ALIGN: ?Align = null,
        COPY_MODE: ?CopyMode = null,
        INIT_NEW_MODE: ?InitNew(CHILD_TYPE) = null,
        CLEAR_OLD_MODE: ?ClearOldMode = null,
        GROW_MODE: ?GrowthMode = null,
        ERROR_MODE: ErrorBehavior = .ERRORS_ARE_UNREACHABLE,
        CALLSITE: ?std.builtin.SourceLocation = null,
        CALLSITE_FMT: ?[]const u8 = null,
        CALLSITE_ARGS_OPAQUE: ?*const anyopaque = null,
        CALLSITE_ARGS_TYPE: ?type = null,
        TRIGGER_DEBUG: ?*const DebugTrigger = null,
    };
}

const SmartAllocStage = enum {
    ALLOC_NEW,
    COPY_OVER,
    MEMSET_OLD_AND_NEW,
    FREE_OLD,
    EVAL_DEBUG,
};

const SmartAllocDebugStage = enum {
    PRINT,
    TEST,
};

pub const AllocDebugState = struct {
    type_name: []const u8 = undefined,
    old_mem_byte_ptr: [*]u8 = Utils.invalid_ptr_many(u8),
    old_mem_byte_len: usize = 0,
    old_mem_byte_cap: usize = 0,
    old_mem_type_len: usize = 0,
    old_mem_type_cap: usize = 0,
    unused_bytes_in_old: usize = 0,
    unused_elems_in_old: usize = 0,
    old_align: usize = 0,
    growth_mode: GrowthMode = .GROW_EXACT_NEEDED,
    copy_mode: CopyMode = .COPY_EXISTING_DATA,
    init_new_mode: InitNewMode = .DONT_MEMSET_NEW,
    clear_old_mode: ClearOldMode = .DONT_MEMSET_OLD,
    new_mem_byte_ptr: [*]u8 = Utils.invalid_ptr_many(u8),
    new_mem_byte_len: usize = 0,
    new_mem_byte_cap: usize = 0,
    new_mem_type_len: usize = 0,
    new_mem_type_cap: usize = 0,
    unused_bytes_in_new: usize = 0,
    unused_elems_in_new: usize = 0,
    new_align: usize = 0,
    alloc_failure: bool = false,
    alloc_remap: bool = false,
    userdata: ?*anyopaque = null,
};

pub const AllocDebugTestResult = enum(u8) {
    CONTINUE,
    WARN_AND_CONTINUE,
    ALWAYS_PANIC,
    UNREACHABLE,
};

fn smart_alloc_internal(alloc: Allocator, comptime T: type, old_ptr: [*]T, old_len: usize, old_cap: usize, new_cap: usize, settings: SmartAllocSettings(T), comptime comptime_settings: SmartAllocComptimeSettings(T)) t: {
    const PTR = @typeInfo(@TypeOf(old_ptr)).pointer;
    switch (comptime_settings.ERROR_MODE) {
        .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => {
            break :t AllocErr![]align(PTR.alignment) PTR.child;
        },
        .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => {
            break :t []align(PTR.alignment) PTR.child;
        },
    }
} {
    if (old_cap == new_cap) return old_ptr[0..old_cap];
    const INFO = @typeInfo(@TypeOf(old_ptr)).pointer;
    const SIZE = @sizeOf(T);
    const SLICE = []align(INFO.alignment) T;
    const GROW = if (comptime_settings.GROW_MODE) |MODE| MODE else settings.grow_mode;
    const OLD_ALIGN = if (comptime_settings.OLD_ALIGN) |A| A.get_align(INFO.alignment) else settings.old_align.get_align(INFO.alignment);
    const NEW_ALIGN = if (comptime_settings.NEW_ALIGN) |A| A.get_align(INFO.alignment) else settings.new_align.get_align(INFO.alignment);
    const COPY = if (comptime_settings.COPY_MODE) |MODE| MODE else settings.copy_mode;
    const INIT_NEW = if (comptime_settings.INIT_NEW_MODE) |MODE| MODE else settings.init_new_mode;
    const CLEAR_OLD = if (comptime_settings.CLEAR_OLD_MODE) |MODE| MODE else settings.clear_old_mode;
    const old_byte_cap = @sizeOf(T) * old_cap;
    const real_new_cap = if (old_cap < new_cap) switch (GROW) {
        .GROW_EXACT_NEEDED => new_cap,
        .GROW_BY_25_PERCENT => new_cap + (new_cap >> 2),
        .GROW_BY_50_PERCENT => new_cap + (new_cap >> 1),
        .GROW_BY_100_PERCENT => new_cap << 1,
    } else new_cap;
    const old_byte_len = @sizeOf(T) * old_cap;
    const new_byte_len = @sizeOf(T) * real_new_cap;
    const copy_len = @min(old_cap, real_new_cap);
    const copy_byte_len = @sizeOf(T) * copy_len;
    const old_byte_ptr: [*]u8 = @ptrCast(@alignCast(old_ptr));
    const old_byte_slice = old_byte_ptr[0..old_byte_len];
    var new_mem_byte_ptr: [*]u8 = Utils.invalid_ptr_many(u8);
    var new_mem_used: SLICE = &.{};
    var new_mem_unused: SLICE = &.{};
    var new_mem_unused_bytes: []u8 = &.{};
    var new_mem_total: SLICE = &.{};
    var failure: bool = false;
    var remap: bool = false;
    next_stage: switch (SmartAllocStage.ALLOC_NEW) {
        .ALLOC_NEW => {
            if (new_byte_len == 0) continue :next_stage .MEMSET_OLD_AND_NEW;
            if (alloc.rawRemap(old_byte_slice, .fromByteUnits(NEW_ALIGN), new_byte_len, @returnAddress())) |new_ptr| {
                remap = true;
                new_mem_byte_ptr = new_ptr;
                const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_ptr));
                new_mem_total = new_ptr_cast[0..real_new_cap];
                switch (COPY) {
                    .COPY_EXISTING_DATA => {
                        new_mem_used = new_ptr_cast[0..copy_len];
                        new_mem_unused = new_ptr_cast[copy_len..real_new_cap];
                        new_mem_unused_bytes = new_ptr[copy_byte_len..new_byte_len];
                        continue :next_stage .MEMSET_OLD_AND_NEW;
                    },
                    .DONT_COPY_EXISTING_DATA => {
                        new_mem_used = new_ptr_cast[0..0];
                        new_mem_unused = new_ptr_cast[0..real_new_cap];
                        new_mem_unused_bytes = new_ptr[0..new_byte_len];
                        continue :next_stage .MEMSET_OLD_AND_NEW;
                    },
                }
            }
            new_mem_byte_ptr = alloc.rawAlloc(new_byte_len, .fromByteUnits(NEW_ALIGN), @returnAddress()) orelse {
                failure = true;
                continue :next_stage .EVAL_DEBUG;
            };
            const new_ptr_cast: [*]T = @ptrCast(@alignCast(new_mem_byte_ptr));
            new_mem_total = new_ptr_cast[0..real_new_cap];
            switch (COPY) {
                .COPY_EXISTING_DATA => {
                    new_mem_used = new_ptr_cast[0..copy_len];
                    new_mem_unused = new_ptr_cast[copy_len..real_new_cap];
                    new_mem_unused_bytes = new_mem_byte_ptr[copy_byte_len..new_byte_len];
                    continue :next_stage .COPY_OVER;
                },
                .DONT_COPY_EXISTING_DATA => {
                    new_mem_used = new_ptr_cast[0..0];
                    new_mem_unused = new_ptr_cast[0..real_new_cap];
                    new_mem_unused_bytes = new_mem_byte_ptr[0..new_byte_len];
                    continue :next_stage .MEMSET_OLD_AND_NEW;
                },
            }
        },
        .COPY_OVER => {
            const old_mem_used: SLICE = old_ptr[0..copy_len];
            @memcpy(new_mem_used, old_mem_used);
            continue :next_stage .MEMSET_OLD_AND_NEW;
        },
        .MEMSET_OLD_AND_NEW => {
            const old_mem_bytes_ptr: [*]u8 = @ptrCast(old_ptr);
            const old_mem_bytes: []u8 = old_mem_bytes_ptr[0..old_byte_cap];
            switch (CLEAR_OLD) {
                .MEMSET_OLD_UNDEFINED => {
                    @memset(old_mem_bytes, undefined);
                },
                .FORCE_MEMSET_OLD_UNDEFINED => {
                    Utils.Mem.secure_memset_undefined(u8, old_mem_bytes);
                },
                .MEMSET_OLD_ZERO => {
                    @memset(old_mem_bytes, 0);
                },
                .FORCE_MEMSET_OLD_ZERO => {
                    Utils.Mem.secure_zero(u8, old_mem_bytes);
                },
                .DONT_MEMSET_OLD => {},
            }
            if (new_byte_len > old_byte_cap) {
                switch (INIT_NEW) {
                    .MEMSET_NEW_UNDEFINED => {
                        @memset(new_mem_unused_bytes, 0xAA);
                    },
                    .FORCE_MEMSET_NEW_UNDEFINED => {
                        Utils.Mem.secure_memset_undefined(u8, new_mem_unused_bytes);
                    },
                    .MEMSET_NEW_ZERO => {
                        @memset(new_mem_unused_bytes, 0);
                    },
                    .FORCE_MEMSET_NEW_ZERO => {
                        Utils.Mem.secure_zero(u8, new_mem_unused_bytes);
                    },
                    .MEMSET_NEW_CUSTOM => |init_val| {
                        @memset(new_mem_unused, init_val);
                    },
                    .FORCE_MEMSET_NEW_CUSTOM => |init_val| {
                        Utils.Mem.secure_memset(T, new_mem_unused, init_val);
                    },
                    .DONT_MEMSET_NEW => {},
                }
            }
            continue :next_stage .FREE_OLD;
        },
        .FREE_OLD => {
            if (old_byte_len > 0) {
                alloc.rawFree(old_byte_slice, .fromByteUnits(OLD_ALIGN), @returnAddress());
            }
            continue :next_stage .EVAL_DEBUG;
        },
        .EVAL_DEBUG => {
            if (comptime_settings.TRIGGER_DEBUG) |trigger| {
                const state = AllocDebugState{
                    .type_name = @typeName(T),
                    .alloc_failure = failure,
                    .old_align = OLD_ALIGN,
                    .new_align = NEW_ALIGN,
                    .old_mem_byte_ptr = @intCast(old_byte_ptr),
                    .old_mem_byte_cap = @intCast(old_byte_cap),
                    .old_mem_type_cap = @intCast(old_cap),
                    .old_mem_byte_len = @intCast(old_byte_len),
                    .old_mem_type_len = @intCast(old_len),
                    .copy_mode = COPY,
                    .clear_old_mode = CLEAR_OLD,
                    .growth_mode = GROW,
                    .init_new_mode = std.meta.activeTag(INIT_NEW),
                    .userdata = settings.trigger_debug_userdata,
                    .new_mem_byte_ptr = new_mem_byte_ptr,
                    .new_mem_byte_cap = new_mem_total.len * SIZE,
                    .new_mem_type_cap = new_mem_total.len,
                    .new_mem_byte_len = @intCast(copy_byte_len),
                    .new_mem_type_len = @intCast(copy_len),
                    .alloc_remap = remap,
                    .unused_bytes_in_new = new_mem_unused.len * SIZE,
                    .unused_bytes_in_old = num_cast(old_cap - old_len, usize) * SIZE,
                    .unused_elems_in_new = new_mem_total.len - copy_len,
                    .unused_elems_in_old = num_cast(old_cap - old_len, usize),
                };
                const trigger_result = trigger(state);
                switch (trigger_result) {
                    .CONTINUE => {},
                    .WARN_AND_CONTINUE => {
                        if (comptime_settings.CALLSITE_FMT) |FMT| {
                            warn_unconditional(if (comptime_settings.CALLSITE) |site| site else @src(), FMT ++ "\nTRIGGERING STATE: {any}\n", Utils.dereference_opaque(comptime_settings.CALLSITE_ARGS_OPAQUE.?, comptime_settings.CALLSITE_ARGS_TYPE.?) ++ .{state});
                        } else {
                            warn_unconditional(if (comptime_settings.CALLSITE) |site| site else @src(), "\nsmart_alloc debug triggered\nTRIGGERING STATE: {any}\n", .{state});
                        }
                    },
                    .ALWAYS_PANIC => {
                        if (comptime_settings.CALLSITE_FMT) |FMT| {
                            assert_unreachable_always_panic(if (comptime_settings.CALLSITE) |site| site else @src(), FMT ++ "\nTRIGGERING STATE: {any}\n", Utils.dereference_opaque(comptime_settings.CALLSITE_ARGS_OPAQUE.?, comptime_settings.CALLSITE_ARGS_TYPE.?) ++ .{state});
                        } else {
                            assert_unreachable_always_panic(if (comptime_settings.CALLSITE) |site| site else @src(), "\nsmart_alloc debug triggered\nTRIGGERING STATE: {any}\n", .{state});
                        }
                    },
                    .UNREACHABLE => {
                        if (comptime_settings.CALLSITE_FMT) |FMT| {
                            assert_unreachable(if (comptime_settings.CALLSITE) |site| site else @src(), FMT ++ "\nTRIGGERING STATE: {any}\n", Utils.dereference_opaque(comptime_settings.CALLSITE_ARGS_OPAQUE.?, comptime_settings.CALLSITE_ARGS_TYPE.?) ++ .{state});
                        } else {
                            assert_unreachable(if (comptime_settings.CALLSITE) |site| site else @src(), "\nsmart_alloc debug triggered\nTRIGGERING STATE: {any}\n", .{state});
                        }
                    },
                }
            }
        },
    }
    return new_mem_total;
}

pub fn smart_alloc(alloc: Allocator, old_ptr: anytype, old_len: anytype, old_cap: anytype, new_cap: usize, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_ptr))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_type(@TypeOf(old_ptr)))) t: {
    const PTR = @typeInfo(@TypeOf(old_ptr)).pointer;
    switch (comptime_settings.ERROR_MODE) {
        .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => {
            break :t AllocErr![]align(PTR.alignment) PTR.child;
        },
        .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => {
            break :t []align(PTR.alignment) PTR.child;
        },
    }
} {
    const T = Types.pointer_child_type(@TypeOf(old_ptr));
    return smart_alloc_internal(alloc, T, old_ptr, @intCast(old_len), @intCast(old_cap), @intCast(new_cap), settings, comptime_settings);
}

pub fn smart_alloc_ptr_ptrs(alloc: Allocator, old_ptr_ptr: anytype, old_len: anytype, old_cap_ptr: anytype, new_cap: anytype, settings: SmartAllocSettings(Types.pointer_child_type(@TypeOf(old_ptr_ptr.*))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_type(@TypeOf(old_ptr_ptr.*)))) switch (comptime_settings.ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => AllocErr!void,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => void,
} {
    const new_mem = if (comptime comptime_settings.ERROR_MODE.does_error()) ( //
        try smart_alloc(alloc, old_ptr_ptr.*, old_len, old_cap_ptr.*, new_cap, settings, comptime_settings)) //
        else smart_alloc(alloc, old_ptr_ptr.*, old_len, old_cap_ptr.*, new_cap, settings, comptime_settings);
    old_ptr_ptr.* = new_mem.ptr;
    old_cap_ptr.* = @intCast(new_mem.len);
    return;
}

pub fn smart_alloc_new(alloc: Allocator, comptime T: type, new_cap: usize, settings: SmartAllocSettings(T), comptime comptime_settings: SmartAllocComptimeSettings(T)) switch (comptime_settings.ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => AllocErr![]T,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => []T,
} {
    var ptr: [*]T = Utils.invalid_ptr_many(T);
    var len: usize = 0;
    if (comptime comptime_settings.ERROR_MODE.does_error()) ( //
        try smart_alloc_ptr_ptrs(alloc, &ptr, &len, new_cap, settings, comptime_settings)) //
    else smart_alloc_ptr_ptrs(alloc, &ptr, &len, new_cap, settings, comptime_settings);
    return ptr[0..len];
}

pub fn smart_push_to_list_many_ptr(ptr_to_data_pointer: anytype, ptr_to_len: anytype, ptr_to_cap: anytype, val: Types.pointer_child_child_type(@TypeOf(ptr_to_data_pointer)), alloc: Allocator, settings: SmartAllocSettings(Types.pointer_child_child_type(@TypeOf(ptr_to_data_pointer))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_child_type(@TypeOf(ptr_to_data_pointer)))) switch (comptime_settings.ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => AllocErr!void,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => void,
} {
    if (ptr_to_len.* >= ptr_to_cap.*) {
        if (comptime comptime_settings.ERROR_MODE.does_error()) ( //
            try smart_alloc_ptr_ptrs(alloc, ptr_to_data_pointer, ptr_to_cap, @intCast(ptr_to_len.* + 1), settings, comptime_settings)) //
        else smart_alloc_ptr_ptrs(alloc, ptr_to_data_pointer, ptr_to_cap, @intCast(ptr_to_len.* + 1), settings, comptime_settings);
    }
    ptr_to_data_pointer.*[ptr_to_len.*] = val;
    ptr_to_len.* += 1;
}

pub fn smart_push_to_list_slice(ptr_to_slice: anytype, ptr_to_cap: anytype, val: Types.pointer_child_child_type(@TypeOf(ptr_to_slice)), alloc: Allocator, settings: SmartAllocSettings(Types.pointer_child_child_type(@TypeOf(ptr_to_slice))), comptime comptime_settings: SmartAllocComptimeSettings(Types.pointer_child_child_type(@TypeOf(ptr_to_slice)))) switch (comptime_settings.ERROR_MODE) {
    .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => AllocErr!void,
    .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => void,
} {
    if (ptr_to_slice.*.len >= ptr_to_cap.*) {
        const new_mem = if (comptime comptime_settings.ERROR_MODE.does_error()) ( //
            try smart_alloc(alloc, ptr_to_slice.*.ptr[0..ptr_to_cap.*], @intCast(ptr_to_slice.*.len + 1), settings, comptime_settings)) //
            else smart_alloc(alloc, ptr_to_slice.*.ptr[0..ptr_to_cap.*], @intCast(ptr_to_slice.*.len + 1), settings, comptime_settings);
        ptr_to_cap.* = @intCast(new_mem.len);
        ptr_to_slice.* = new_mem[0..ptr_to_slice.*.len];
    }
    ptr_to_slice.*.ptr[ptr_to_slice.*.len] = val;
    ptr_to_slice.*.len += 1;
}
