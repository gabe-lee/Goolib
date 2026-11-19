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
const build = @import("builtin");
const math = std.math;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const PointerModule = Root.Pointer;
const PointerSource = PointerModule.PointerSource;
const PointerFn = PointerModule.Pointer;
const ConstPointerFn = PointerModule.ConstPointer;
const PointerAlignFn = PointerModule.PointerAlign;
const ConstPointerAlignFn = PointerModule.ConstPointerAlign;
const NullablePointerFn = PointerModule.NullablePointer;
const NullablePointerAlignFn = PointerModule.NullablePointerAlign;
const Math = Root.Math;
const num_cast = Root.Cast.num_cast;
pub const PowerOf2 = Math.PowerOf2;

pub const Infallible = @import("./Allocator_Infallible.zig");
pub const Dummy = @import("./Allocator_Dummy.zig");
pub const QuickBucketAlloc = @import("./Allocator_QuickBucket.zig");
pub const BucketSlabs = @import("./Allocator_BucketSlabs.zig");

comptime {
    if (build.is_test) {
        _ = @import("./Allocator_Dummy.zig");
        _ = @import("./Allocator_Infallible.zig");
        _ = @import("./Allocator_QuickBucket.zig");
        _ = @import("./Allocator_BucketSlabs.zig");
        _ = @import("./Allocator_Tests.zig");
    }
}

pub const AllocSourceKind = enum {
    NEVER_ALLOCATES,
    PASSED_ALLOCATOR_INTERFACE,
    CACHED_ALLOCATOR_INTERFACE,
    COMPTIME_ALLOCATOR_INTERFACE_PTR,
    COMPILANT_GLOBAL_ALLOCATOR,
    COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR,
    COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR,
    COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR,
};

pub const CompliantAllocIfaceAdapter = struct {
    alloc: Allocator = Dummy.allocator_panic_free_noop,
};

pub fn is_compliant_goolib_allocator_static(comptime T: type) struct { bool, PointerSource } {
    if (!Types.type_has_decl_with_type(T, "POINTER_SOURCE", PointerSource)) return .{ false, PointerSource.native_pointer() };
    const SOURCE: PointerSource = @field(T, "POINTER_SOURCE");
    const PointerU8 = PointerFn(u8, SOURCE);
    const NullPointerU8 = NullablePointerFn(u8, SOURCE);

    if (!Types.type_has_decl_with_type(T, "free_raw_wrapper", fn (PointerU8, usize, PowerOf2) void)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn free_raw_wrapper(ptr: Pointer(u8, SOURCE), len: usize, alignment: PowerOf2) void` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "remap_raw_wrapper", fn (PointerU8, usize, usize, PowerOf2) NullPointerU8)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn remap_raw_wrapper(ptr: Pointer(u8, SOURCE), old_len: usize, new_len: usize, alignment: PowerOf2) NullablePointer(u8, SOURCE)` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "resize_raw_wrapper", fn (PointerU8, usize, usize, PowerOf2) bool)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn resize_raw_wrapper(ptr: Pointer(u8, SOURCE), old_len: usize, new_len: usize, alignment: PowerOf2) bool` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "alloc_raw_wrapper", fn (usize, PowerOf2) NullPointerU8)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn alloc_raw_wrapper(len: usize, alignment: PowerOf2) NullablePointer(u8, SOURCE)` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    return .{ true, SOURCE };
}

pub fn is_compliant_goolib_allocator_instantiated(comptime T: type) struct { bool, PointerSource } {
    if (!Types.type_has_decl_with_type(T, "POINTER_SOURCE", PointerSource)) return .{ false, PointerSource.native_pointer() };
    const SOURCE: PointerSource = @field(T, "POINTER_SOURCE");
    const PointerU8 = PointerFn(u8, SOURCE);
    const NullPointerU8 = NullablePointerFn(u8, SOURCE);

    if (!Types.type_has_decl_with_type(T, "free_raw_wrapper", fn (PointerU8, usize, PowerOf2) void)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn free_raw_wrapper(allocator: *T, ptr: Pointer(u8, SOURCE), len: usize, alignment: PowerOf2) void` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "remap_raw_wrapper", fn (PointerU8, usize, usize, PowerOf2) NullPointerU8)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn remap_raw_wrapper(allocator: *T, ptr: Pointer(u8, SOURCE), old_len: usize, new_len: usize, alignment: PowerOf2) NullablePointer(u8, SOURCE)` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "resize_raw_wrapper", fn (PointerU8, usize, usize, PowerOf2) bool)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn resize_raw_wrapper(allocator: *T, ptr: Pointer(u8, SOURCE), old_len: usize, new_len: usize, alignment: PowerOf2) bool` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    if (!Types.type_has_decl_with_type(T, "alloc_raw_wrapper", fn (usize, PowerOf2) NullPointerU8)) {
        Assert.warn_unconditional(@src(), "type `{s}` declared a `pub const POINTER_SOURCE: PointerSource` declaration, but was missing a `pub fn alloc_raw_wrapper(allocator: *T, len: usize, alignment: PowerOf2) NullablePointer(u8, SOURCE)` function", .{});
        return .{ false, PointerSource.native_pointer() };
    }
    return .{ true, SOURCE };
}

pub fn assert_type_is_compliant_native_allocator_static(comptime T: type) void {
    assert_with_reason(Types.type_has_decl_with_type(T, "free_raw_native", fn ([]u8, Alignment) void), @src(), "type `{s}` is missing the `pub fn free_raw_native(memory: []u8, alignment: Alignment) void` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "remap_raw_native", fn ([]u8, usize, Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn remap_raw_native(memory: []u8, new_len: usize, alignment: Alignment) ?[*]u8` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "resize_raw_native", fn ([]u8, usize, Alignment) bool), @src(), "type `{s}` is missing the `pub fn resize_raw_native(memory: []u8, new_len: usize, alignment: Alignment) bool` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "alloc_raw_native", fn (usize, Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn alloc_raw_native(size: usize, alignment: Alignment) ?[*]u8` static function", .{@typeName(T)});
}

pub fn assert_type_is_compliant_native_allocator_instantiated(comptime T: type) void {
    assert_with_reason(Types.type_has_decl_with_type(T, "free_raw_native", fn (*T, []u8, Alignment) void), @src(), "type `{s}` is missing the `pub fn free_raw_native(self: *Self, memory: []u8, alignment: Alignment) void` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "remap_raw_native", fn (*T, []u8, usize, Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn remap_raw_native(self: *Self, memory: []u8, new_len: usize, alignment: Alignment) ?[*]u8` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "resize_raw_native", fn (*T, []u8, usize, Alignment) bool), @src(), "type `{s}` is missing the `pub fn resize_raw_native(self: *Self, : []u8, new_len: usize, alignment: Alignment) bool` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "alloc_raw_native", fn (*T, usize, Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn alloc_raw_native(self: *Self, size: usize, alignment: Alignment) ?[*]u8` method", .{@typeName(T)});
}

pub const AllocSource = union(AllocSourceKind) {
    NEVER_ALLOCATES: void,
    PASSED_ALLOCATOR_INTERFACE: void,
    CACHED_ALLOCATOR_INTERFACE: void,
    COMPTIME_ALLOCATOR_INTERFACE_PTR: *const Allocator,
    COMPILANT_GLOBAL_ALLOCATOR: type,
    COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR: type,
    COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR: type,
    COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR: struct {
        INSTANTIATED_ALLOC: type,
        INSTANTIATED_ALLOC_PTR: *anyopaque,
    },

    pub fn never_allocates() AllocSource {
        return AllocSource{ .NEVER_ALLOCATES = {} };
    }
    pub fn passed_allocator_interface() AllocSource {
        return AllocSource{ .PASSED_ALLOCATOR_INTERFACE = {} };
    }
    pub fn cached_allocator_interface() AllocSource {
        return AllocSource{ .CACHED_ALLOCATOR_INTERFACE = {} };
    }
    pub fn comptime_allocator_interface_ptr(comptime ptr: *const Allocator) AllocSource {
        return AllocSource{ .COMPTIME_ALLOCATOR_INTERFACE_PTR = ptr };
    }
    pub fn compliant_global_allocator(comptime GLOBAL_ALLOC: type) AllocSource {
        return AllocSource{ .COMPILANT_GLOBAL_ALLOCATOR = GLOBAL_ALLOC };
    }
    pub fn compliant_instantiated_allocator_cached_ptr(comptime INSTANTIATED_ALLOC: type) AllocSource {
        return AllocSource{ .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR = INSTANTIATED_ALLOC };
    }
    pub fn compliant_instantiated_allocator_passed_ptr(comptime INSTANTIATED_ALLOC: type) AllocSource {
        return AllocSource{ .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR = INSTANTIATED_ALLOC };
    }
    pub fn compliant_instantiated_allocator_comptime_ptr(comptime INSTANTIATED_ALLOC: type, comptime PTR: *INSTANTIATED_ALLOC) AllocSource {
        return AllocSource{ .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR = .{ .INSTANTIATED_ALLOC = INSTANTIATED_ALLOC, .INSTANTIATED_ALLOC_PTR = PTR } };
    }

    pub fn CONST_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => void,
            .CACHED_ALLOCATOR_INTERFACE => void,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => *const Allocator,
            .COMPILANT_GLOBAL_ALLOCATOR => type,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| *INFO.INSTANTIATED_ALLOC,
        };
    }
    pub fn CONST_TYPE_INIT(comptime self: AllocSource) self.CONST_TYPE() {
        return switch (comptime self) {
            .NEVER_ALLOCATES => {},
            .PASSED_ALLOCATOR_INTERFACE => {},
            .CACHED_ALLOCATOR_INTERFACE => {},
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => |PTR| PTR,
            .COMPILANT_GLOBAL_ALLOCATOR => |TYPE| TYPE,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| @as(*INFO.INSTANTIATED_ALLOC, @ptrCast(@alignCast(INFO.INSTANTIATED_ALLOC_PTR))),
        };
    }
    pub fn FIELD_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => void,
            .CACHED_ALLOCATOR_INTERFACE => Allocator,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => void,
        };
    }
    pub fn FIELD_TYPE_INIT(comptime self: AllocSource) self.FIELD_TYPE() {
        return switch (comptime self) {
            .NEVER_ALLOCATES => {},
            .PASSED_ALLOCATOR_INTERFACE => {},
            .CACHED_ALLOCATOR_INTERFACE => Dummy.allocator_panic_free_noop,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => {},
            .COMPILANT_GLOBAL_ALLOCATOR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |TYPE| Utils.invalid_ptr(TYPE),
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {},
        };
    }
    pub fn INIT_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => Allocator,
            .CACHED_ALLOCATOR_INTERFACE => Allocator,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => void,
        };
    }
    pub fn NIL_INIT_TYPE(comptime self: AllocSource) self.INIT_TYPE() {
        return switch (comptime self) {
            .NEVER_ALLOCATES => {},
            .PASSED_ALLOCATOR_INTERFACE => Dummy.allocator_panic,
            .CACHED_ALLOCATOR_INTERFACE => Dummy.allocator_panic,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => {},
            .COMPILANT_GLOBAL_ALLOCATOR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| Utils.invalid_ptr(T),
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| Utils.invalid_ptr(T),
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {},
        };
    }
    pub fn PARAM_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => Allocator,
            .CACHED_ALLOCATOR_INTERFACE => void,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => void,
        };
    }
    pub fn PARAM_NIL(comptime self: AllocSource) self.PARAM_TYPE() {
        return switch (comptime self) {
            .NEVER_ALLOCATES => {},
            .PASSED_ALLOCATOR_INTERFACE => Root.Allocator.Dummy.allocator_panic_free_noop,
            .CACHED_ALLOCATOR_INTERFACE => {},
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => {},
            .COMPILANT_GLOBAL_ALLOCATOR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| Utils.invalid_ptr(T),
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {},
        };
    }
    pub fn COMPLIANT_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => void,
            .CACHED_ALLOCATOR_INTERFACE => void,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => |T| T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| INFO.INSTANTIATED_ALLOC,
        };
    }
    pub fn INSTANTIATED_COMPLIANT_TYPE_PTR(comptime self: AllocSource) type {
        return switch (comptime self) {
            .NEVER_ALLOCATES => void,
            .PASSED_ALLOCATOR_INTERFACE => void,
            .CACHED_ALLOCATOR_INTERFACE => void,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| *INFO.INSTANTIATED_ALLOC,
        };
    }
    pub fn USE_FIELD_TYPE(comptime self: AllocSource) bool {
        return switch (comptime self) {
            .NEVER_ALLOCATES => false,
            .PASSED_ALLOCATOR_INTERFACE => false,
            .CACHED_ALLOCATOR_INTERFACE => true,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => false,
            .COMPILANT_GLOBAL_ALLOCATOR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => false,
        };
    }
    pub fn USE_CONST_TYPE(comptime self: AllocSource) bool {
        return switch (comptime self) {
            .NEVER_ALLOCATES => false,
            .PASSED_ALLOCATOR_INTERFACE => false,
            .CACHED_ALLOCATOR_INTERFACE => false,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => true,
            .COMPILANT_GLOBAL_ALLOCATOR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => true,
        };
    }
    pub fn USE_PARAM_TYPE(comptime self: AllocSource) bool {
        return switch (comptime self) {
            .NEVER_ALLOCATES => false,
            .PASSED_ALLOCATOR_INTERFACE => true,
            .CACHED_ALLOCATOR_INTERFACE => false,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => false,
            .COMPILANT_GLOBAL_ALLOCATOR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => false,
        };
    }
    pub inline fn CAN_NEVER_ALLOCATE(comptime self: AllocSource) bool {
        return self == .NEVER_ALLOCATES;
    }

    pub fn equals(comptime self: AllocSource, other: AllocSource) bool {
        if (@backingInt(self) != @backingInt(other)) return false;
        return switch (comptime self) {
            .NEVER_ALLOCATES => true,
            .PASSED_ALLOCATOR_INTERFACE => true,
            .CACHED_ALLOCATOR_INTERFACE => true,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => |SELF_PTR| SELF_PTR == other.COMPTIME_ALLOCATOR_INTERFACE_PTR,
            .COMPILANT_GLOBAL_ALLOCATOR => |SELF_T| SELF_T == other.COMPILANT_GLOBAL_ALLOCATOR,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |SELF_INFO| (SELF_INFO.INSTANTIATED_ALLOC == other.COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR.INSTANTIATED_ALLOC) and (SELF_INFO.INSTANTIATED_ALLOC_PTR == other.COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR.INSTANTIATED_ALLOC_PTR),
        };
    }

    pub fn debug_str(comptime self: AllocSource) []const u8 {
        return @tagName(self) ++ switch (comptime self) {
            .NEVER_ALLOCATES => "",
            .PASSED_ALLOCATOR_INTERFACE => "",
            .CACHED_ALLOCATOR_INTERFACE => "",
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => |SELF_PTR| std.fmt.comptimePrint("{*}", .{SELF_PTR}),
            .COMPILANT_GLOBAL_ALLOCATOR => |SELF_T| SELF_T == std.fmt.comptimePrint("{s}", .{@typeName(SELF_T)}),
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => "",
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => "",
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |SELF_INFO| std.fmt.comptimePrint("{*}", .{@as(*SELF_INFO.INSTANTIATED_ALLOC, @ptrCast(@alignCast(SELF_INFO.INSTANTIATED_ALLOC_PTR)))}),
        };
    }
};

pub noinline fn ALLOCATOR_ADAPTER_GENERIC_ID() u64 {
    return comptime Utils.src_loc_hash(@src());
}
pub fn AllocatorAdapter(comptime SOURCE: AllocSource) type {
    comptime var PTR_SRC: PointerSource = PointerSource.native_pointer();
    comptime var HAS_SRC: bool = false;
    switch (comptime SOURCE) {
        .COMPILANT_GLOBAL_ALLOCATOR => |T| {
            HAS_SRC, PTR_SRC = is_compliant_goolib_allocator_static(T);
            if (!HAS_SRC) {
                assert_type_is_compliant_native_allocator_static(T);
            }
        },
        .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| {
            HAS_SRC, PTR_SRC = is_compliant_goolib_allocator_instantiated(INFO.INSTANTIATED_ALLOC);
            if (!HAS_SRC) {
                assert_type_is_compliant_native_allocator_instantiated(INFO.INSTANTIATED_ALLOC);
            }
        },
        .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| {
            HAS_SRC, PTR_SRC = is_compliant_goolib_allocator_instantiated(T);
            if (!HAS_SRC) {
                assert_type_is_compliant_native_allocator_instantiated(T);
            }
        },
        .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| {
            HAS_SRC, PTR_SRC = is_compliant_goolib_allocator_instantiated(T);
            if (!HAS_SRC) {
                assert_type_is_compliant_native_allocator_instantiated(T);
            }
        },
        else => {},
    }
    const PTR_SRC_ = PTR_SRC;
    const HAS_SRC_ = HAS_SRC;
    return struct {
        const Self = @This();
        pub const GENERIC_ID = ALLOCATOR_ADAPTER_GENERIC_ID();

        const C: ConstAlloc = ConstAllocInit;
        f: CachedAlloc = CachedAllocInit,

        pub const PassedAlloc = SOURCE.PARAM_TYPE();
        pub const NilPassedAlloc = SOURCE.PARAM_NIL();
        pub const CachedAlloc = SOURCE.FIELD_TYPE();
        pub const CachedAllocInit = SOURCE.FIELD_TYPE_INIT();
        pub const ConstAlloc = SOURCE.CONST_TYPE();
        pub const ConstAllocInit = SOURCE.CONST_TYPE_INIT();
        pub const InitAlloc = SOURCE.INIT_TYPE();
        pub const NilInitAlloc = SOURCE.NIL_INIT_TYPE();
        pub const POINTER_SOURCE = PTR_SRC_;
        const HAS_PTR_SRC = HAS_SRC_;
        pub const POINTER_SOURCE_IS_NATIVE = POINTER_SOURCE == .NATIVE;
        // inline fn as_wrapper_u8(ptr: anytype) PointerU8 {
        //     const T = @TypeOf(ptr);
        //     if (T == PointerU8) return ptr;
        //     with_error: switch (comptime @typeInfo(T)) {
        //         .pointer => |P| {
        //             if (P.child != u8)
        //         },
        //         else => break :with_error,
        //     }
        //     if (T == []u8 or T == []const u8) return PointerOpaque.new_from_native(ptr.ptr);
        //     if (@typeInfo(T) == .pointer) return PointerOpaque.new_from_native(ptr);
        //     @compileError("expected a PointerOpaque, a byte slice, or a pointer, found " ++ @typeName(T));
        // }
        pub const PointerU8 = PointerFn(u8, POINTER_SOURCE);
        pub const NullablePointerU8 = NullablePointerFn(u8, POINTER_SOURCE);
        pub fn PointerU8Align(comptime A: PowerOf2) type {
            return PointerAlignFn(u8, A, POINTER_SOURCE);
        }
        pub fn NullablePointerU8Align(comptime A: PowerOf2) type {
            return NullablePointerAlignFn(u8, A, POINTER_SOURCE);
        }

        pub fn Pointer(comptime T: type) type {
            return PointerFn(T, POINTER_SOURCE);
        }
        pub fn NullablePointer(comptime T: type) type {
            return NullablePointerFn(T, POINTER_SOURCE);
        }
        pub fn PointerAlign(comptime T: type, comptime A: PowerOf2) type {
            return PointerAlignFn(T, A, POINTER_SOURCE);
        }
        pub fn NullablePointerAlign(comptime T: type, comptime A: PowerOf2) type {
            return NullablePointerAlignFn(T, A, POINTER_SOURCE);
        }

        pub const ConstPointerU8 = ConstPointerFn(u8, POINTER_SOURCE);
        pub fn ConstPointerU8Align(comptime A: PowerOf2) type {
            return ConstPointerAlignFn(u8, A, POINTER_SOURCE);
        }
        pub fn ConstPointer(comptime T: type) type {
            return ConstPointerFn(T, POINTER_SOURCE);
        }
        pub fn ConstPointerAlign(comptime T: type, comptime A: PowerOf2) type {
            return ConstPointerAlignFn(T, A, POINTER_SOURCE);
        }

        pub const VTABLE: Allocator.VTable = .{
            .alloc = alloc_impl,
            .resize = resize_impl,
            .remap = remap_impl,
            .free = free_impl,
        };

        pub const interface = if (SOURCE.USE_FIELD_TYPE()) ( //
            struct {
                inline fn get(self: *Self) Allocator {
                    return .{ .ptr = @ptrCast(@alignCast(self)), .vtable = &VTABLE };
                }
            }.get //
        ) else if (SOURCE.USE_PARAM_TYPE()) ( //
            struct {
                inline fn get() Allocator {
                    assert_unreachable(@src(), "cannot get an allocator interface from an AllocatorAdatper that requires an external allocator source to be passed to every function call", .{});
                    return Dummy.allocator_panic_free_noop;
                }
            }.get //
        ) else ( //
            struct {
                inline fn get() Allocator {
                    return .{ .ptr = @ptrFromInt(math.maxInt(usize)), .vtable = &VTABLE };
                }
            }.get //
        );

        pub inline fn passed_source_interface_adapter(alloc_param: PassedAlloc) PassedAllocAdapter {
            assert_alloc_param(@src());
            return PassedAllocAdapter.new(alloc_param);
        }

        fn init_to_cached_alloc(init_alloc: InitAlloc) CachedAlloc {
            if (CachedAlloc == InitAlloc) return init_alloc;
            return CachedAllocInit;
        }
        fn init_to_passed_alloc(init_alloc: InitAlloc) PassedAlloc {
            if (PassedAlloc == InitAlloc) return init_alloc;
            return NilPassedAlloc;
        }

        pub const PassedAllocAdapter = struct {
            alloc_param: PassedAlloc = NilPassedAlloc,

            pub fn new(alloc_param: PassedAlloc) PassedAllocAdapter {
                assert_alloc_param(@src());
                return PassedAllocAdapter{
                    .alloc_param = alloc_param,
                };
            }
            pub fn interface(self: *PassedAllocAdapter) Allocator {
                assert_alloc_param(@src());
                return Allocator{ .ptr = @ptrCast(@alignCast(self)), .vtable = &PassedAllocAdapter.VTABLE };
            }

            pub const VTABLE: Allocator.VTable = .{
                .alloc = PassedAllocAdapter.alloc_impl,
                .resize = PassedAllocAdapter.resize_impl,
                .remap = PassedAllocAdapter.remap_impl,
                .free = PassedAllocAdapter.free_impl,
            };

            fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
                if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return null;
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.alloc_raw(.{}, len, PowerOf2.from_std_align(alignment), self.alloc_param);
            }
            fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
                if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return false;
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.resize_raw(.{}, memory, new_len, PowerOf2.from_std_align(alignment), self.alloc_param);
            }
            fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
                if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return null;
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.remap_raw(.{}, memory, new_len, PowerOf2.from_std_align(alignment), self.alloc_param);
            }
            fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
                if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return;
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocAdapter = @ptrCast(@alignCast(self_opaque));
                Self.free_raw(.{}, memory, PowerOf2.from_std_align(alignment), self.alloc_param);
            }
        };

        pub inline fn init(self: *Self, cached_alloc: CachedAlloc) void {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                self.f = cached_alloc;
            }
        }
        pub inline fn init_from_init_alloc(self: *Self, init_alloc: InitAlloc) void {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                self.f = init_to_cached_alloc(init_alloc);
            }
        }
        pub inline fn new(cached_alloc: CachedAlloc) Self {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                return Self{ .f = cached_alloc };
            } else {
                return Self{};
            }
        }
        pub inline fn new_from_init_alloc(init_alloc: InitAlloc) Self {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                return Self{ .f = init_to_cached_alloc(init_alloc) };
            } else {
                return Self{};
            }
        }

        inline fn get_alloc_internal(self: Self, alloc_param: PassedAlloc) Allocator {
            return switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE => alloc_param,
                .CACHED_ALLOCATOR_INTERFACE => self.f,
                .COMPTIME_ALLOCATOR_INTERFACE_PTR => C.*,
                else => unreachable,
            };
        }

        pub inline fn get_alloc(self: *Self, alloc_param: PassedAlloc) Allocator {
            return switch (comptime SOURCE) {
                .NEVER_ALLOCATES,
                .COMPILANT_GLOBAL_ALLOCATOR,
                .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR,
                .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR,
                => self.interface(),
                .CACHED_ALLOCATOR_INTERFACE => self.f,
                .COMPTIME_ALLOCATOR_INTERFACE_PTR => C.*,
                .PASSED_ALLOCATOR_INTERFACE => alloc_param,
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => @compileError("cannot get a `std.mem.Allocator` interface from an `AllocatorAdapter` whose allocator source is passed as a compliant pointer; pass the pointer to the adapter methods instead"),
            };
        }
        inline fn get_instantiated_compliant_alloc_ptr(self: Self, alloc_param: PassedAlloc) SOURCE.INSTANTIATED_COMPLIANT_TYPE_PTR() {
            return switch (comptime SOURCE) {
                .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => self.f,
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => alloc_param,
                .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => C,
                else => unreachable,
            };
        }
        inline fn assert_native_source(comptime src: ?std.lang.SourceLocation) void {
            comptime assert_with_reason(POINTER_SOURCE_IS_NATIVE, src, "cannot call this function if the PointerSource is not native", .{});
        }
        inline fn assert_no_alloc_param(comptime src: ?std.lang.SourceLocation) void {
            comptime assert_with_reason(!SOURCE.USE_PARAM_TYPE(), src, "cannot call this function if an allocator needs to be passed in manually", .{});
        }
        inline fn assert_alloc_param(comptime src: ?std.lang.SourceLocation) void {
            comptime assert_with_reason(SOURCE.USE_PARAM_TYPE(), src, "cannot call this function if an allocator DOES NOT need to be passed in manually", .{});
        }
        //*********
        // ALLOC
        //*********
        pub inline fn alloc_raw(self: Self, size: usize, alignment: PowerOf2, alloc_param: PassedAlloc) NullablePointerU8 {
            switch (comptime SOURCE) {
                .NEVER_ALLOCATES => return NullablePointerU8.new_null(),
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    assert_native_source(@src());
                    const alloc = self.get_alloc_internal(alloc_param);
                    const p = alloc.rawAlloc(size, alignment.to_std_align(), @returnAddress());
                    return NullablePointerU8{ .internal = p };
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    if (comptime HAS_PTR_SRC) {
                        return C.alloc_raw_wrapper(size, alignment);
                    } else {
                        return NullablePointerU8{ .internal = C.alloc_raw_native(size, alignment.to_std_align()) };
                    }
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    if (comptime HAS_PTR_SRC) {
                        return alloc.alloc_raw_wrapper(size, alignment);
                    } else {
                        return NullablePointerU8{ .internal = alloc.alloc_raw_native(size, alignment.to_std_align()) };
                    }
                },
            }
        }
        fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
            if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return null;
            assert_no_alloc_param(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.alloc_raw(len, alignment, {}).ptr_many_or_null();
        }
        pub inline fn alloc_types(self: Self, comptime T: type, count: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.alloc_raw(@sizeOf(T) * count, PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn alloc_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, count: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.alloc_raw(@sizeOf(T) * count, alignment, alloc_param).to_element_aligned(T, alignment);
        }
        pub inline fn alloc_bytes(self: Self, size: anytype, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.alloc_raw(size, ._1, alloc_param);
        }
        pub inline fn alloc_bytes_with_align(self: Self, comptime alignment: PowerOf2, size: anytype, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.alloc_raw(size, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn alloc_types_native(self: Self, comptime T: type, count: usize, alloc_param: PassedAlloc) ?[*]T {
            return self.alloc_types(T, count, alloc_param).ptr_many();
        }
        pub inline fn alloc_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, count: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            return self.alloc_types_with_align(T, count, PowerOf2.from_std_align(alignment), alloc_param).ptr_many();
        }
        pub inline fn alloc_bytes_native(self: Self, size: anytype, alloc_param: PassedAlloc) ?[*]u8 {
            return self.alloc_bytes(size, alloc_param).ptr_many();
        }
        pub inline fn alloc_bytes_with_align_native(self: Self, comptime alignment: Alignment, size: anytype, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            return self.alloc_bytes_with_align(size, PowerOf2.from_std_align(alignment), alloc_param).ptr_many();
        }
        //*********
        // RESIZE
        //*********
        pub inline fn resize_raw(self: Self, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) bool {
            switch (comptime SOURCE) {
                .NEVER_ALLOCATES => return false,
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    const alloc = self.get_alloc_internal(alloc_param);
                    return alloc.rawResize(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    if (comptime HAS_PTR_SRC) {
                        return C.resize_raw_wrapper(ptr, old_len, new_len, alignment);
                    } else {
                        return C.resize_raw_native(ptr.slice(old_len), new_len, alignment.to_std_align());
                    }
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    if (comptime HAS_PTR_SRC) {
                        return alloc.resize_raw_wrapper(ptr, old_len, new_len, alignment);
                    } else {
                        return alloc.resize_raw_native(ptr.slice(old_len), new_len, alignment);
                    }
                },
            }
        }
        fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
            if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return false;
            assert_no_alloc_param(@src());
            assert_native_source(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.resize_raw(PointerU8.new_from(memory.ptr), memory.len, new_len, PowerOf2.from_std_align(alignment), {});
        }
        pub inline fn resize_types(self: Self, comptime T: type, ptr: Pointer(T), old_count: usize, new_count: usize, alloc_param: PassedAlloc) bool {
            return self.resize_raw(ptr.to_element(u8), old_count * @sizeOf(T), num_cast(new_count * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param));
        }
        pub inline fn resize_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), old_count: usize, new_count: usize, alloc_param: PassedAlloc) bool {
            return self.resize_raw(ptr.to_element(u8), old_count * @sizeOf(T), num_cast(new_count * @sizeOf(T), alignment, alloc_param));
        }
        pub inline fn resize_bytes(self: Self, ptr: PointerU8, old_len: usize, new_len: usize, alloc_param: PassedAlloc) bool {
            return self.resize_raw(ptr, old_len, new_len, ._1, alloc_param);
        }
        pub inline fn resize_bytes_with_align(self: Self, comptime alignment: PowerOf2, ptr: PointerU8Align(alignment), old_len: usize, new_len: usize, alloc_param: PassedAlloc) bool {
            return self.resize_raw(ptr.to_native_align(), old_len, new_len, alignment, alloc_param);
        }
        pub inline fn resize_types_native(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: PassedAlloc) bool {
            assert_native_source(@src());
            return self.resize_types(T, Pointer(T).new_from(memory.ptr), memory.len, new_count, alloc_param);
        }
        pub inline fn resize_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: PassedAlloc) bool {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            return self.resize_types_with_align(A, T, PointerAlign(T, A).new_from(memory.ptr), memory.len, new_count, alloc_param);
        }
        pub inline fn resize_bytes_native(self: Self, memory: []u8, new_len: usize, alloc_param: PassedAlloc) bool {
            assert_native_source(@src());
            return self.resize_bytes(PointerU8.new_from(memory.ptr), memory.len, new_len, alloc_param);
        }
        pub inline fn resize_bytes_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: PassedAlloc) bool {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            return self.resize_bytes_with_align(A, PointerU8Align(A).new_from(memory.ptr), memory.len, new_len, alloc_param);
        }
        //*********
        // REMAP
        //*********
        pub inline fn remap_raw(self: Self, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) NullablePointerU8 {
            switch (comptime SOURCE) {
                .NEVER_ALLOCATES => return NullablePointerU8.new_null(),
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    assert_native_source(@src());
                    const alloc = self.get_alloc_internal(alloc_param);
                    const p = alloc.rawRemap(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress());
                    return NullablePointerU8{ .internal = p };
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    if (comptime HAS_PTR_SRC) {
                        return C.remap_raw_wrapper(ptr, old_len, new_len, alignment);
                    } else {
                        return NullablePointerU8{ .internal = C.remap_raw_native(ptr.slice(old_len), new_len, alignment) };
                    }
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    if (comptime HAS_PTR_SRC) {
                        return alloc.remap_raw_wrapper(ptr, old_len, new_len, alignment);
                    } else {
                        return NullablePointerU8{ .internal = alloc.remap_raw_native(ptr.slice(old_len), new_len, alignment) };
                    }
                },
            }
        }
        fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return null;
            assert_no_alloc_param(@src());
            assert_native_source(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.remap_raw(PointerU8.new_from(memory.ptr), memory.len, new_len, alignment, {}).ptr_many();
        }
        pub inline fn remap_types(self: Self, comptime T: type, ptr: Pointer(T), old_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.remap_raw(ptr.to_element(u8), old_count * @sizeOf(T), num_cast(new_count * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param)).to_element(T);
        }
        pub inline fn remap_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), old_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.remap_raw(ptr.to_element(u8), old_count * @sizeOf(T), num_cast(new_count * @sizeOf(T), alignment, alloc_param)).to_element_aligned(T, alignment);
        }
        pub inline fn remap_bytes(self: Self, ptr: PointerU8, old_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.remap_raw(ptr, old_len, new_len, ._1, alloc_param);
        }
        pub inline fn remap_bytes_with_align(self: Self, comptime alignment: PowerOf2, ptr: PointerU8Align(alignment), old_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.remap_raw(ptr.to_native_align(), old_len, new_len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn remap_types_native(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            return self.remap_types(T, Pointer(T).new_from(memory.ptr), memory.len, new_count, alloc_param).ptr_many();
        }
        pub inline fn remap_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: PassedAlloc) ?[]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            return self.remap_types_with_align(A, T, PointerAlign(T, A).new_from(memory.ptr), memory.len, new_count, alloc_param).ptr_many();
        }
        pub inline fn remap_bytes_native(self: Self, memory: []u8, new_len: usize, alloc_param: PassedAlloc) ?[]u8 {
            assert_native_source(@src());
            return self.remap_bytes(PointerU8.new_from(memory.ptr), memory.len, new_len, alloc_param).ptr_many();
        }
        pub inline fn remap_bytes_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: PassedAlloc) ?[]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            return self.remap_bytes_with_align(PointerU8Align(A).new_from(memory.ptr), memory.len, new_len, alloc_param).ptr_many();
        }
        //*********
        // FREE
        //*********
        pub inline fn free_raw(self: Self, ptr: PointerU8, len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) void {
            switch (comptime SOURCE) {
                .NEVER_ALLOCATES => return,
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    assert_native_source(@src());
                    const alloc = self.get_alloc_internal(alloc_param);
                    alloc.rawFree(ptr.slice(len), alignment.to_std_align(), @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    if (comptime HAS_PTR_SRC) {
                        C.free_raw_wrapper(ptr, len, alignment);
                    } else {
                        C.free_raw_native(ptr.slice(len), alignment);
                    }
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    if (comptime HAS_PTR_SRC) {
                        alloc.free_raw_wrapper(ptr, len, alignment);
                    } else {
                        alloc.free_raw_native(ptr.slice(len), alignment);
                    }
                },
            }
        }
        fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
            if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return;
            assert_no_alloc_param(@src());
            assert_native_source(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            self.free_raw(PointerU8.new_from(memory.ptr), memory.len, PowerOf2.from_std_align(alignment), {});
        }
        pub inline fn free_types(self: Self, comptime T: type, ptr: Pointer(T), len: usize, alloc_param: PassedAlloc) void {
            self.free_raw(ptr.to_element(u8), len * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param);
        }
        pub inline fn free_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), len: usize, alloc_param: PassedAlloc) void {
            self.free_raw(ptr.to_element(u8), len * @sizeOf(T), alignment, alloc_param);
        }
        pub inline fn free_bytes(self: Self, ptr: PointerU8, len: usize, alloc_param: PassedAlloc) void {
            self.free_raw(ptr, len, ._1, alloc_param);
        }
        pub inline fn free_bytes_with_align(self: Self, comptime alignment: PowerOf2, ptr: PointerU8Align(alignment), len: usize, alloc_param: PassedAlloc) void {
            self.free_raw(ptr.to_native_align(), len, alignment, alloc_param);
        }
        pub inline fn free_types_native(self: Self, comptime T: type, memory: []T, alloc_param: PassedAlloc) void {
            assert_native_source(@src());
            self.free_types(T, Pointer(T).new_from(memory.ptr), memory.len, alloc_param);
        }
        pub inline fn free_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, alloc_param: PassedAlloc) void {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            self.free_types_with_align(A, T, PointerAlign(T, A).new_from(memory.ptr), memory.len, alloc_param);
        }
        pub inline fn free_bytes_native(self: Self, memory: []u8, alloc_param: PassedAlloc) void {
            assert_native_source(@src());
            self.free_bytes(PointerU8.new_from(memory.ptr), memory.len, alloc_param);
        }
        pub inline fn free_bytes_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, alloc_param: PassedAlloc) void {
            assert_native_source(@src());
            const A = comptime PowerOf2.from_std_align(alignment);
            self.free_bytes_with_align(A, PointerU8Align(A).new_from(memory.ptr), memory.len, alloc_param);
        }
        //*********
        // REALLOC
        //*********
        pub fn realloc_raw(self: Self, ptr: PointerU8, old_len: usize, data_len: usize, new_len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) NullablePointerU8 {
            if (comptime SOURCE.CAN_NEVER_ALLOCATE()) return NullablePointerU8.new_null();
            if (new_len == 0) {
                if (old_len != 0) self.free_raw(ptr, ptr.len, alignment, alloc_param);
                // At this point either the pointer was freed, or the unallocated pointer remains unchanged
                // We dont return null here because null indicates an allocation failure. Instead just return
                // the same pointer address and put the burden on the caller to never dereference it.
                return ptr.to_nullable();
            }
            if (old_len == 0) return self.alloc_raw(new_len, alignment, alloc_param);
            if (self.resize_raw(ptr, old_len, new_len, alignment, alloc_param)) return ptr.to_nullable();
            const remapped_mem = self.remap_raw(ptr, old_len, new_len, alignment, alloc_param);
            if (remapped_mem.not_null()) return remapped_mem;
            const allocated_mem = self.alloc_raw(new_len, alignment, alloc_param);
            if (allocated_mem.is_null()) return allocated_mem;
            assert_with_reason(data_len <= old_len, @src(), "`data_len` MUST be <= `old_len`, got {d} > {d}", .{ data_len, old_len });
            const copy_len = @min(data_len, new_len);
            allocated_mem.memcopy_from(ptr.slice(copy_len));
            self.free_raw(ptr, old_len, alignment, alloc_param);
            return allocated_mem;
        }
        pub inline fn realloc_bytes(self: Self, ptr: PointerU8, old_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.realloc_raw(ptr, old_len, old_len, new_len, ._1, alloc_param);
        }
        pub inline fn realloc_bytes_with_align(self: Self, comptime alignment: PowerOf2, ptr: PointerU8Align(alignment), old_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.realloc_raw(ptr.to_native_align(), old_len, old_len, new_len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn realloc_types(self: Self, comptime T: type, ptr: Pointer(T), old_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.realloc_raw(ptr.to_element(u8), old_count * @sizeOf(T), old_count * @sizeOf(T), new_count * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn realloc_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), old_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.realloc_raw(ptr.to_element(u8), old_count * @sizeOf(T), old_count * @sizeOf(T), new_count * @sizeOf(T), alignment, alloc_param).to_element_aligned(T, alignment);
        }
        pub inline fn realloc_bytes_custom_data_len(self: Self, ptr: PointerU8, old_len: usize, data_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.realloc_raw(ptr, old_len, data_len, new_len, ._1, alloc_param);
        }
        pub inline fn realloc_bytes_custom_data_len_with_align(self: Self, comptime alignment: PowerOf2, ptr: PointerU8Align(alignment), old_len: usize, data_len: usize, new_len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.realloc_raw(ptr.to_native_align(), old_len, data_len, new_len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn realloc_types_custom_data_len(self: Self, comptime T: type, ptr: Pointer(T), old_count: usize, data_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.realloc_raw(ptr.to_element(u8), old_count * @sizeOf(T), data_count * @sizeOf(T), new_count * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn realloc_types_custom_data_len_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), old_count: usize, data_count: usize, new_count: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.realloc_raw(ptr.to_element(u8), old_count * @sizeOf(T), data_count * @sizeOf(T), new_count * @sizeOf(T), alignment, alloc_param).to_element_aligned(T, alignment);
        }

        pub inline fn realloc_bytes_native(self: Self, memory: []u8, new_len: usize, alloc_param: PassedAlloc) ?[*]u8 {
            assert_native_source(@src());
            self.realloc_bytes(PointerU8.new_from(memory.ptr), memory.len, new_len, alloc_param).ptr_many();
        }
        pub inline fn realloc_bytes_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            self.realloc_bytes_with_align(A, PointerU8Align(A).new_from(memory.ptr), memory.len, new_len, alloc_param).ptr_many();
        }
        pub inline fn realloc_types_native(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            self.realloc_types(T, Pointer(T).new_from(memory.ptr), memory.len, new_count, alloc_param).ptr_many();
        }
        pub inline fn realloc_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            self.realloc_types_with_align(A, T, PointerAlign(T, A).new_from(memory.ptr), memory.len, new_count, alloc_param).ptr_many();
        }

        pub inline fn realloc_bytes_custom_data_len_native(self: Self, memory: []u8, data_len: usize, new_len: usize, alloc_param: PassedAlloc) ?[*]u8 {
            assert_native_source(@src());
            self.realloc_bytes_custom_data_len(PointerU8.new_from(memory.ptr), memory.len, data_len, new_len, alloc_param).ptr_many();
        }
        pub inline fn realloc_bytes_custom_data_len_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, data_len: usize, new_len: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            self.realloc_bytes_custom_data_len_with_align(A, PointerU8Align(A).new_from(memory.ptr), memory.len, data_len, new_len, alloc_param).ptr_many();
        }
        pub inline fn realloc_types_custom_data_len_native(self: Self, comptime T: type, memory: []T, data_count: usize, new_count: usize, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            self.realloc_types_custom_data_len(T, Pointer(T).new_from(memory.ptr), memory.len, data_count, new_count, alloc_param).ptr_many();
        }
        pub inline fn realloc_types_custom_data_len_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, data_count: usize, new_count: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            self.realloc_types_custom_data_len_with_align(A, T, PointerAlign(T, A).new_from(memory.ptr), memory.len, data_count, new_count, alloc_param).ptr_many();
        }
        //*********
        // CLONE
        //*********
        pub fn clone_raw(self: Self, ptr: ConstPointerU8, len: usize, data_len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) NullablePointerU8 {
            assert_with_reason(data_len <= len, @src(), "`data_len` MUST be <= `len`, got {d} > {d}", .{ data_len, len });
            const allocated_mem = self.alloc_raw(len, alignment, alloc_param);
            if (allocated_mem.is_null()) return NullablePointerU8.new_null();
            allocated_mem.memcopy_from(ptr.slice(data_len));
            return allocated_mem;
        }
        pub fn clone_slim_raw(self: Self, ptr: ConstPointerU8, len: usize, data_len: usize, alignment: PowerOf2, alloc_param: PassedAlloc) NullablePointerU8 {
            assert_with_reason(data_len <= len, @src(), "`data_len` MUST be <= `len`, got {d} > {d}", .{ data_len, len });
            const allocated_mem = self.alloc_raw(data_len, alignment, alloc_param);
            if (allocated_mem.is_null()) return NullablePointerU8.new_null();
            allocated_mem.memcopy_from(ptr.slice(data_len));
            return allocated_mem;
        }
        pub inline fn clone_bytes(self: Self, ptr: ConstPointerU8, len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.clone_raw(ptr, len, len, ._1, alloc_param);
        }
        pub inline fn clone_bytes_with_align(self: Self, comptime alignment: PowerOf2, ptr: ConstPointerU8, len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.clone_raw(ptr.to_native_align(), len, len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn clone_types(self: Self, comptime T: type, ptr: ConstPointer(T), len: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.clone_raw(ptr.to_element(u8), len * @sizeOf(T), len * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn clone_types_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: ConstPointerAlign(T, alignment), len: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.clone_raw(ptr.to_element(u8), len * @sizeOf(T), len * @sizeOf(T), alignment, alloc_param).to_element_aligned(T, alignment);
        }

        pub inline fn clone_bytes_custom_data_len(self: Self, ptr: ConstPointerU8, len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.clone_raw(ptr, len, data_len, ._1, alloc_param);
        }
        pub inline fn clone_bytes_with_align_custom_data_len(self: Self, comptime alignment: PowerOf2, ptr: ConstPointerU8, len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.clone_raw(ptr.to_native_align(), len, data_len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn clone_types_custom_data_len(self: Self, comptime T: type, ptr: ConstPointer(T), len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.clone_raw(ptr.to_element(u8), len * @sizeOf(T), data_len * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn clone_types_with_align_custom_data_len(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: ConstPointerAlign(T, alignment), len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.clone_raw(ptr.to_element(u8), len * @sizeOf(T), data_len * @sizeOf(T), alignment, alloc_param).to_element_aligned(T, alignment);
        }

        pub inline fn slim_clone_bytes_custom_data_len(self: Self, ptr: ConstPointerU8, len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerU8 {
            return self.clone_slim_raw(ptr, len, data_len, ._1, alloc_param);
        }
        pub inline fn slim_clone_bytes_with_align_custom_data_len(self: Self, comptime alignment: PowerOf2, ptr: ConstPointerU8, len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerU8Align(alignment) {
            return self.clone_slim_raw(ptr.to_native_align(), len, data_len, alignment, alloc_param).to_specific_align(alignment);
        }
        pub inline fn slim_clone_types_custom_data_len(self: Self, comptime T: type, ptr: ConstPointer(T), len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.clone_slim_raw(ptr.to_element(u8), len * @sizeOf(T), data_len * @sizeOf(T), PowerOf2.align_of_type(T), alloc_param).to_element(T);
        }
        pub inline fn slim_clone_types_with_align_custom_data_len(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: ConstPointerAlign(T, alignment), len: usize, data_len: usize, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.clone_slim_raw(ptr.to_element(u8), len * @sizeOf(T), data_len * @sizeOf(T), alignment, alloc_param).to_element_aligned(T, alignment);
        }

        pub inline fn clone_bytes_native(self: Self, memory: []const u8, alloc_param: PassedAlloc) ?[*]u8 {
            assert_native_source(@src());
            return self.clone_bytes(ConstPointerU8.new_from(memory.ptr), memory.len, alloc_param).ptr_many();
        }
        pub inline fn clone_bytes_with_align_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) const u8, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.clone_bytes_with_align(A, ConstPointerU8Align(A).new_from(memory.ptr), memory.len, alloc_param).ptr_many();
        }
        pub inline fn clone_types_native(self: Self, comptime T: type, memory: []const T, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            self.clone_types(T, ConstPointer(T).new_from(memory.ptr), memory.len, alloc_param).ptr_many();
        }
        pub inline fn clone_types_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) const T, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.clone_types_with_align(A, T, ConstPointerAlign(T, A).new_from(memory.ptr), memory.len, alloc_param).ptr_many();
        }
        pub inline fn clone_bytes_custom_data_len_native(self: Self, memory: []const u8, data_len: usize, alloc_param: PassedAlloc) ?[*]u8 {
            assert_native_source(@src());
            return self.clone_bytes_custom_data_len(ConstPointerU8.new_from(memory.ptr), memory.len, data_len, alloc_param).ptr_many();
        }
        pub inline fn clone_bytes_with_align_custom_data_len_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) const u8, data_len: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.clone_bytes_with_align_custom_data_len(A, ConstPointerU8Align(A).new_from(memory.ptr), memory.len, data_len, alloc_param).ptr_many();
        }
        pub inline fn clone_types_custom_data_count_native(self: Self, comptime T: type, memory: []const T, data_count: usize, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            return self.clone_types_custom_data_len(T, ConstPointer(T).new_from(memory.ptr), memory.len, data_count, alloc_param).ptr_many();
        }
        pub inline fn clone_types_with_align_custom_data_count_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) const T, data_count: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.clone_types_with_align_custom_data_len(A, T, ConstPointerAlign(T, A).new_from(memory.ptr), memory.len, data_count, alloc_param).ptr_many();
        }
        pub inline fn slim_clone_bytes_custom_data_len_native(self: Self, memory: []const u8, data_len: usize, alloc_param: PassedAlloc) ?[*]u8 {
            assert_native_source(@src());
            return self.slim_clone_bytes_custom_data_len(ConstPointerU8.new_from(memory.ptr), memory.len, data_len, alloc_param).ptr_many();
        }
        pub inline fn slim_clone_bytes_with_align_custom_data_len_native(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) const u8, data_len: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) u8 {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.slim_clone_bytes_with_align_custom_data_len(A, ConstPointerU8Align(A).new_from(memory.ptr), memory.len, data_len, alloc_param).ptr_many();
        }
        pub inline fn slim_clone_types_custom_data_count_native(self: Self, comptime T: type, memory: []const T, data_count: usize, alloc_param: PassedAlloc) ?[*]T {
            assert_native_source(@src());
            return self.slim_clone_types_custom_data_len(T, ConstPointer(T).new_from(memory.ptr), memory.len, data_count, alloc_param).ptr_many();
        }
        pub inline fn slim_clone_types_with_align_custom_data_count_native(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) const T, data_count: usize, alloc_param: PassedAlloc) ?[*]align(alignment.toByteUnits()) T {
            assert_native_source(@src());
            const A = PowerOf2.from_std_align(alignment);
            return self.slim_clone_types_with_align_custom_data_len(A, T, ConstPointerAlign(T, A).new_from(memory.ptr), memory.len, data_count, alloc_param).ptr_many();
        }
        //*********
        // CREATE/DESTROY
        //*********
        pub inline fn create_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            return self.alloc_types_with_align(alignment, T, 1, alloc_param);
        }
        pub inline fn create(self: Self, comptime T: type, alloc_param: PassedAlloc) NullablePointer(T) {
            return self.alloc_types(T, 1, alloc_param);
        }
        pub inline fn create_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, alloc_param: PassedAlloc) ?*align(alignment.toByteUnits()) T {
            return self.alloc_types_with_align_native(alignment, T, 1, alloc_param);
        }
        pub inline fn create_native(self: Self, comptime T: type, alloc_param: PassedAlloc) ?*T {
            return self.alloc_types(T, 1, alloc_param).ptr();
        }
        pub inline fn destroy_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: PointerAlign(T, alignment), alloc_param: PassedAlloc) void {
            self.free_types_with_align(alignment, T, ptr, 1, alloc_param);
        }
        pub inline fn destroy(self: Self, comptime T: type, ptr: Pointer(T), alloc_param: PassedAlloc) void {
            self.free_types(T, ptr, 1, alloc_param);
        }
        pub inline fn destroy_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, ptr: *align(alignment.toByteUnits()) T, alloc_param: PassedAlloc) void {
            self.free_types_with_align_native(alignment, T, @as([*]align(alignment.toByteUnits()) T, @ptrCast(ptr))[0..1], alloc_param);
        }
        pub inline fn destroy_native(self: Self, comptime T: type, ptr: Pointer(T), alloc_param: PassedAlloc) void {
            self.free_types_native(T, @as([*]T, @ptrCast(ptr))[0..1], alloc_param);
        }
        pub inline fn clone_one_with_align(self: Self, comptime alignment: PowerOf2, comptime T: type, ptr: ConstPointerAlign(T, alignment), alloc_param: PassedAlloc) NullablePointerAlign(T, alignment) {
            const cloned_mem = self.create_with_align(alignment, T, alloc_param);
            if (cloned_mem.is_null()) return cloned_mem;
            cloned_mem.set(ptr.get());
            return cloned_mem;
        }
        pub inline fn clone_one(self: Self, comptime T: type, ptr: ConstPointer(T), alloc_param: PassedAlloc) NullablePointer(T) {
            const cloned_mem = self.create(T, alloc_param);
            if (cloned_mem.is_null()) return cloned_mem;
            cloned_mem.set(ptr.get());
            return cloned_mem;
        }
        pub inline fn clone_one_native(self: Self, comptime T: type, ptr: *const T, alloc_param: PassedAlloc) ?*T {
            const cloned_mem = self.create_native(T, alloc_param);
            if (cloned_mem) |cloned_mem_not_null| {
                cloned_mem_not_null.* = ptr.*;
            }
            return cloned_mem;
        }
        pub inline fn clone_one_with_align_native(self: Self, comptime alignment: Alignment, comptime T: type, ptr: *align(alignment.toByteUnits()) const T, alloc_param: PassedAlloc) ?*align(alignment.toByteUnits()) T {
            const cloned_mem = self.create_with_align_native(alignment, T, alloc_param);
            if (cloned_mem) |cloned_mem_not_null| {
                cloned_mem_not_null.* = ptr.*;
            }
            return cloned_mem;
        }
    };
}
