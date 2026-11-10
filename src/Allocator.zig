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

pub fn assert_type_is_compliant_allocator_static(comptime T: type) void {
    assert_with_reason(Types.type_has_decl_with_type(T, "free_raw", fn ([]u8, ?Alignment) void), @src(), "type `{s}` is missing the `pub fn free_raw(memory: []u8, alignment: ?Alignment) void` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "remap_raw", fn ([]u8, usize, ?Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn remap_raw(memory: []u8, new_len: usize, alignment: ?Alignment) ?[*]u8` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "resize_raw", fn ([]u8, usize, ?Alignment) bool), @src(), "type `{s}` is missing the `pub fn resize_raw(memory: []u8, new_len: usize, alignment: ?Alignment) bool` static function", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "alloc_raw", fn (usize, ?Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn alloc_raw(size: usize, alignment: ?Alignment) ?[*]u8` static function", .{@typeName(T)});
}

pub fn assert_type_is_compliant_allocator_local(comptime T: type) void {
    assert_with_reason(Types.type_has_decl_with_type(T, "free_raw", fn (*T, []u8, ?Alignment) void), @src(), "type `{s}` is missing the `pub fn free_raw(self: *Self, memory: []u8, alignment: ?Alignment) void` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "remap_raw", fn (*T, []u8, usize, ?Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn remap_raw(self: *Self, memory: []u8, new_len: usize, alignment: ?Alignment) ?[*]u8` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "resize_raw", fn (*T, []u8, usize, ?Alignment) bool), @src(), "type `{s}` is missing the `pub fn resize_raw(self: *Self, : []u8, new_len: usize, alignment: ?Alignment) bool` method", .{@typeName(T)});
    assert_with_reason(Types.type_has_decl_with_type(T, "alloc_raw", fn (*T, usize, ?Alignment) ?[*]u8), @src(), "type `{s}` is missing the `pub fn alloc_raw(self: *Self, size: usize, alignment: ?Alignment) ?[*]u8` method", .{@typeName(T)});
}

pub const AllocSource = union(AllocSourceKind) {
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
            .PASSED_ALLOCATOR_INTERFACE => void,
            .CACHED_ALLOCATOR_INTERFACE => Allocator,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |TYPE| *TYPE,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => void,
        };
    }
    pub fn FIELD_TYPE_INIT(comptime self: AllocSource) self.FIELD_TYPE() {
        return switch (comptime self) {
            .PASSED_ALLOCATOR_INTERFACE => {},
            .CACHED_ALLOCATOR_INTERFACE => Dummy.allocator_panic_free_noop,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => {},
            .COMPILANT_GLOBAL_ALLOCATOR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |TYPE| Utils.invalid_ptr(TYPE),
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => {},
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {},
        };
    }
    pub fn PARAM_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
            .PASSED_ALLOCATOR_INTERFACE => Allocator,
            .CACHED_ALLOCATOR_INTERFACE => void,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => void,
            .COMPILANT_GLOBAL_ALLOCATOR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => void,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| *T,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => void,
        };
    }
    pub fn COMPLIANT_TYPE(comptime self: AllocSource) type {
        return switch (comptime self) {
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
            .PASSED_ALLOCATOR_INTERFACE => true,
            .CACHED_ALLOCATOR_INTERFACE => false,
            .COMPTIME_ALLOCATOR_INTERFACE_PTR => false,
            .COMPILANT_GLOBAL_ALLOCATOR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => false,
            .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => true,
            .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => false,
        };
    }
};

pub fn AllocatorAdapter(comptime SOURCE: AllocSource) type {
    switch (comptime SOURCE) {
        .COMPILANT_GLOBAL_ALLOCATOR => |T| assert_type_is_compliant_allocator_static(T),
        .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => |INFO| assert_type_is_compliant_allocator_local(INFO.INSTANTIATED_ALLOC),
        .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => |T| assert_type_is_compliant_allocator_local(T),
        .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => |T| assert_type_is_compliant_allocator_local(T),
        else => {},
    }
    return struct {
        const Self = @This();

        const C: SOURCE.CONST_TYPE() = SOURCE.CONST_TYPE_INIT();
        f: SOURCE.FIELD_TYPE() = SOURCE.FIELD_TYPE_INIT(),

        pub const PassedAlloc = SOURCE.PARAM_TYPE();

        pub const VTABLE: Allocator.VTable = .{
            .alloc = alloc_impl,
            .resize = resize_impl,
            .remap = remap_impl,
            .free = free_impl,
        };

        pub const interface = if (SOURCE.USE_FIELD_TYPE()) struct {
            inline fn get(self: *Self) Allocator {
                return .{ .ptr = @ptrCast(@alignCast(self)), .vtable = &VTABLE };
            }
        }.get else if (SOURCE.USE_PARAM_TYPE()) struct {
            inline fn get() Allocator {
                assert_unreachable(@src(), "cannot get an allocator interface from an AllocatorAdatper that requires an external allocator source to be passed to every function call", .{});
                return Dummy.allocator_panic_free_noop;
            }
        }.get else struct {
            inline fn get() Allocator {
                return .{ .ptr = @ptrFromInt(math.maxInt(usize)), .vtable = &VTABLE };
            }
        }.get;

        pub inline fn passed_source_interface_adapter(alloc_param: SOURCE.PARAM_TYPE()) PassedAllocInterfaceAdapter {
            assert_alloc_param(@src());
            return PassedAllocInterfaceAdapter.new(alloc_param);
        }

        pub const PassedAllocInterfaceAdapter = struct {
            alloc_param: SOURCE.PARAM_TYPE(),

            pub fn new(alloc_param: SOURCE.PARAM_TYPE()) PassedAllocInterfaceAdapter {
                assert_alloc_param(@src());
                return PassedAllocInterfaceAdapter{
                    .alloc_param = alloc_param,
                };
            }
            pub fn interface(self: *PassedAllocInterfaceAdapter) Allocator {
                assert_alloc_param(@src());
                return Allocator{ .ptr = @ptrCast(@alignCast(self)), .vtable = &PassedAllocInterfaceAdapter.VTABLE };
            }

            pub const VTABLE: Allocator.VTable = .{
                .alloc = PassedAllocInterfaceAdapter.alloc_impl,
                .resize = PassedAllocInterfaceAdapter.resize_impl,
                .remap = PassedAllocInterfaceAdapter.remap_impl,
                .free = PassedAllocInterfaceAdapter.free_impl,
            };

            fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocInterfaceAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.alloc_raw(.{}, len, alignment, self.alloc_param);
            }
            fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocInterfaceAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.resize_raw(.{}, memory, new_len, alignment, self.alloc_param);
            }
            fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocInterfaceAdapter = @ptrCast(@alignCast(self_opaque));
                return Self.remap_raw(.{}, memory, new_len, alignment, self.alloc_param);
            }
            fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
                assert_alloc_param(@src());
                _ = ret_addr;
                const self: *PassedAllocInterfaceAdapter = @ptrCast(@alignCast(self_opaque));
                Self.free_raw(.{}, memory, alignment, self.alloc_param);
            }
        };

        pub inline fn init(self: *Self, cached_alloc: SOURCE.FIELD_TYPE()) void {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                self.f = cached_alloc;
            }
        }
        pub inline fn new(cached_alloc: SOURCE.FIELD_TYPE()) Self {
            if (comptime SOURCE.USE_FIELD_TYPE()) {
                return Self{ .f = cached_alloc };
            } else {
                return Self{};
            }
        }

        inline fn get_alloc_iface(self: Self, alloc_param: SOURCE.PARAM_TYPE()) Allocator {
            return switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE => alloc_param,
                .CACHED_ALLOCATOR_INTERFACE => self.f,
                .COMPTIME_ALLOCATOR_INTERFACE_PTR => C.*,
                else => unreachable,
            };
        }
        inline fn get_instantiated_compliant_alloc_ptr(self: Self, alloc_param: SOURCE.PARAM_TYPE()) SOURCE.INSTANTIATED_COMPLIANT_TYPE_PTR() {
            return switch (comptime SOURCE) {
                .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR => self.f,
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR => alloc_param,
                .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => C,
                else => unreachable,
            };
        }

        inline fn assert_no_alloc_param(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(!SOURCE.USE_PARAM_TYPE(), src, "cannot call this function if an allocator needs to be passed in manually", .{});
        }
        inline fn assert_alloc_param(comptime src: ?std.builtin.SourceLocation) void {
            assert_with_reason(SOURCE.USE_PARAM_TYPE(), src, "cannot call this function if an allocator DOES NOT need to be passed in manually", .{});
        }
        //*********
        // ALLOC
        //*********
        pub inline fn alloc_raw(self: Self, size: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[*]u8 {
            switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    const alloc = self.get_alloc_iface(alloc_param);
                    return alloc.rawAlloc(size, alignment orelse Alignment.@"1", @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    return C.alloc_raw(size, alignment);
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    return alloc.alloc_raw(size, alignment);
                },
            }
        }
        fn alloc_impl(self_opaque: *anyopaque, len: usize, alignment: Alignment, ret_addr: usize) ?[*]u8 {
            assert_no_alloc_param(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.alloc_raw(len, alignment, {});
        }
        pub inline fn alloc_types(self: Self, comptime T: type, count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const ptr = self.alloc_raw(@sizeOf(T) * count, Alignment.fromByteUnits(@alignOf(T)), alloc_param) orelse return null;
            const t_ptr: [*]T = @ptrCast(@alignCast(ptr));
            return t_ptr[0..count];
        }
        pub inline fn alloc_types_with_align(self: Self, comptime T: type, count: usize, comptime alignment: Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const ptr = self.alloc_raw(@sizeOf(T) * count, alignment, alloc_param) orelse return null;
            const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(ptr));
            return t_ptr[0..count];
        }
        pub inline fn alloc_bytes(self: Self, size: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            const ptr = self.alloc_raw(size, null, alloc_param) orelse return null;
            return ptr[0..size];
        }
        pub inline fn alloc_bytes_with_align(self: Self, size: usize, comptime alignment: Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            const ptr: [*]align(alignment.toByteUnits()) u8 = @alignCast(self.alloc_raw(size, alignment, alloc_param) orelse return null);
            return ptr[0..size];
        }
        //*********
        // RESIZE
        //*********
        pub inline fn resize_raw(self: Self, memory: []u8, new_len: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) bool {
            switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    const alloc = self.get_alloc_iface(alloc_param);
                    return alloc.rawResize(memory, alignment orelse Alignment.@"1", new_len, @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    return C.resize_raw(memory, new_len, alignment);
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    return alloc.resize_raw(memory, new_len, alignment);
                },
            }
        }
        fn resize_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
            assert_no_alloc_param(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.resize_raw(memory, new_len, alignment, {});
        }
        pub inline fn resize_types(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) bool {
            return self.resize_raw(@as([*]u8, @ptrCast(memory.ptr))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), Alignment.fromByteUnits(@alignOf(T)), alloc_param);
        }
        pub inline fn resize_types_with_align(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) bool {
            return self.resize_raw(@as([*]u8, @ptrCast(@alignCast(memory.ptr)))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), alignment, alloc_param);
        }
        pub inline fn resize_bytes(self: Self, memory: []u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) bool {
            return self.resize_raw(memory, new_len, null, alloc_param);
        }
        pub inline fn resize_bytes_with_align(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) bool {
            return self.resize_raw(@alignCast(memory), new_len, alignment, alloc_param);
        }
        //*********
        // REMAP
        //*********
        pub inline fn remap_raw(self: Self, memory: []u8, new_len: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[*]u8 {
            switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    const alloc = self.get_alloc_iface(alloc_param);
                    return alloc.rawRemap(memory, alignment orelse Alignment.@"1", new_len, @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    return C.remap_raw(memory, new_len, alignment);
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    return alloc.remap_raw(memory, new_len, alignment);
                },
            }
        }
        fn remap_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
            assert_no_alloc_param(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            return self.remap_raw(memory, new_len, alignment, {});
        }
        pub inline fn remap_types(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            if (self.remap_raw(@as([*]u8, @ptrCast(memory.ptr))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const new_cast_mem: [*]T = @ptrCast(@alignCast(new_mem));
                return new_cast_mem[0..new_count];
            }
            return null;
        }
        pub inline fn remap_types_with_align(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            if (self.remap_raw(@as([*]u8, @ptrCast(@alignCast(memory.ptr)))[0 .. memory.len * @sizeOf(T)], new_count * @sizeOf(T), alignment, alloc_param)) |new_mem| {
                const new_cast_mem: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return new_cast_mem[0..new_count];
            }
            return null;
        }
        pub inline fn remap_bytes(self: Self, memory: []u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.remap_raw(memory, new_len, null, alloc_param)) |new_mem| {
                return new_mem[0..new_len];
            }
            return null;
        }
        pub inline fn remap_bytes_with_align(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.remap_raw(@alignCast(memory), new_len, alignment, alloc_param)) |new_mem| {
                const new_cast_mem: [*]align(alignment.toByteUnits()) u8 = @ptrCast(@alignCast(new_mem));
                return new_cast_mem[0..new_len];
            }
            return null;
        }
        //*********
        // FREE
        //*********
        pub inline fn free_raw(self: Self, memory: []u8, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) void {
            switch (comptime SOURCE) {
                .PASSED_ALLOCATOR_INTERFACE, .CACHED_ALLOCATOR_INTERFACE, .COMPTIME_ALLOCATOR_INTERFACE_PTR => {
                    const alloc = self.get_alloc_iface(alloc_param);
                    return alloc.rawFree(memory, alignment orelse Alignment.@"1", @returnAddress());
                },
                .COMPILANT_GLOBAL_ALLOCATOR => {
                    return C.free_raw(memory, alignment);
                },
                .COMPILANT_INSTANTIATED_ALLOCATOR_PASSED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_CACHED_PTR, .COMPILANT_INSTANTIATED_ALLOCATOR_COMPTIME_PTR => {
                    const alloc = self.get_instantiated_compliant_alloc_ptr(alloc_param);
                    alloc.free_raw(memory, alignment);
                },
            }
        }
        fn free_impl(self_opaque: *anyopaque, memory: []u8, alignment: Alignment, ret_addr: usize) void {
            assert_no_alloc_param(@src());
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            self.free_raw(memory, alignment, {});
        }
        pub inline fn free_types(self: Self, comptime T: type, memory: []T, alloc_param: SOURCE.PARAM_TYPE()) void {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len = memory.len * @sizeOf(T);
            self.free_raw(raw_ptr[0..raw_len], Alignment.fromByteUnits(@alignOf(T)), alloc_param);
        }
        pub inline fn free_types_with_align(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, alloc_param: SOURCE.PARAM_TYPE()) void {
            const raw_ptr: [*]u8 = @ptrCast(@alignCast(memory.ptr));
            const raw_len = memory.len * @sizeOf(T);
            self.free_raw(raw_ptr[0..raw_len], alignment, alloc_param);
        }
        pub inline fn free_bytes(self: Self, memory: []u8, alloc_param: SOURCE.PARAM_TYPE()) void {
            self.free_raw(memory, null, alloc_param);
        }
        pub inline fn free_bytes_with_align(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, alloc_param: SOURCE.PARAM_TYPE()) void {
            self.free_raw(@alignCast(memory), alignment, alloc_param);
        }
        //*********
        // REALLOC
        //*********
        pub fn realloc_raw(self: Self, memory: []u8, data_len: usize, new_len: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[*]u8 {
            if (new_len == 0) {
                if (memory.len != 0) self.free_raw(memory, alignment, alloc_param);
                return Utils.invalid_ptr_many_align(u8, if (alignment) |a| a.toByteUnits() else 1);
            }
            if (memory.len == 0) return self.alloc_raw(new_len, alignment, alloc_param);
            if (self.resize_raw(memory, new_len, alignment, alloc_param)) return memory.ptr;
            if (self.alloc_raw(new_len, alignment, alloc_param)) |new_mem| {
                assert_with_reason(data_len <= memory.len, @src(), "`data_len` MUST be <= `memory.len`, got {d} > {d}", .{ data_len, memory.len });
                const copy_len = @min(data_len, new_len);
                @memcpy(new_mem[0..copy_len], memory[0..copy_len]);
                self.free_raw(memory, alignment, alloc_param);
                return new_mem;
            }
            return null;
        }
        pub inline fn realloc_bytes(self: Self, memory: []u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.realloc_raw(memory, memory.len, new_len, null, alloc_param)) |new_mem| {
                return new_mem[0..new_len];
            }
            return null;
        }
        pub inline fn realloc_bytes_with_align(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.realloc_raw(memory, memory.len, new_len, alignment, alloc_param)) |new_mem| {
                return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@alignCast(new_mem)))[0..new_len];
            }
            return null;
        }
        pub fn realloc_types(self: Self, comptime T: type, memory: []T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const new_len = @sizeOf(T) * new_count;
            if (self.realloc_raw(raw_ptr[0..raw_len], raw_len, new_len, Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const t_ptr: [*]T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..new_count];
            }
            return null;
        }
        pub fn realloc_types_with_align(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const new_len = @sizeOf(T) * new_count;
            if (self.realloc_raw(raw_ptr[0..raw_len], raw_len, new_len, alignment, alloc_param)) |new_mem| {
                const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..new_count];
            }
            return null;
        }
        pub inline fn realloc_bytes_custom_data_len(self: Self, memory: []u8, data_len: usize, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.realloc_raw(memory, data_len, new_len, null, alloc_param)) |new_mem| {
                return new_mem[0..new_len];
            }
            return null;
        }
        pub inline fn realloc_bytes_with_align_custom_data_len(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, data_len: usize, new_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.realloc_raw(memory, data_len, new_len, alignment, alloc_param)) |new_mem| {
                return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@alignCast(new_mem)))[0..new_len];
            }
            return null;
        }
        pub fn realloc_types_custom_data_count(self: Self, comptime T: type, memory: []T, data_count: usize, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            const new_len = @sizeOf(T) * new_count;
            if (self.realloc_raw(raw_ptr[0..raw_len], data_len, new_len, Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const t_ptr: [*]T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..new_count];
            }
            return null;
        }
        pub fn realloc_types_with_align_custom_data_count(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, data_count: usize, new_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            const new_len = @sizeOf(T) * new_count;
            if (self.realloc_raw(raw_ptr[0..raw_len], data_len, new_len, alignment, alloc_param)) |new_mem| {
                const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..new_count];
            }
            return null;
        }
        //*********
        // CLONE
        //*********
        pub fn clone_raw(self: Self, memory: []u8, data_len: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[*]u8 {
            if (self.alloc_raw(memory.len, alignment, alloc_param)) |new_mem| {
                const copy_len = @min(memory.len, data_len);
                @memcpy(new_mem[0..copy_len], memory[0..copy_len]);
                return new_mem;
            }
            return null;
        }
        pub fn clone_slim_raw(self: Self, memory: []u8, data_len: usize, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?[*]u8 {
            const copy_len = @min(memory.len, data_len);
            if (self.alloc_raw(copy_len, alignment, alloc_param)) |new_mem| {
                @memcpy(new_mem[0..copy_len], memory[0..copy_len]);
                return new_mem;
            }
            return null;
        }
        pub inline fn clone_bytes(self: Self, memory: []u8, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.clone_raw(memory, memory.len, null, alloc_param)) |new_mem| {
                return new_mem[0..memory.len];
            }
            return null;
        }
        pub inline fn clone_bytes_with_align(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.clone_raw(memory, memory.len, alignment, alloc_param)) |new_mem| {
                return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@alignCast(new_mem)))[0..memory.len];
            }
            return null;
        }
        pub fn clone_types(self: Self, comptime T: type, memory: []T, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            if (self.clone_raw(raw_ptr[0..raw_len], raw_len, Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const t_ptr: [*]T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..memory.len];
            }
            return null;
        }
        pub fn clone_types_with_align(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            if (self.clone_raw(raw_ptr[0..raw_len], raw_len, alignment, alloc_param)) |new_mem| {
                const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..memory.len];
            }
            return null;
        }
        pub inline fn clone_bytes_custom_data_len(self: Self, memory: []u8, data_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.clone_raw(memory, data_len, null, alloc_param)) |new_mem| {
                return new_mem[0..memory.len];
            }
            return null;
        }
        pub inline fn clone_bytes_with_align_custom_data_len(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, data_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.clone_raw(memory, data_len, alignment, alloc_param)) |new_mem| {
                return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@alignCast(new_mem)))[0..memory.len];
            }
            return null;
        }
        pub fn clone_types_custom_data_count(self: Self, comptime T: type, memory: []T, data_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            if (self.clone_raw(raw_ptr[0..raw_len], data_len, Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const t_ptr: [*]T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..memory.len];
            }
            return null;
        }
        pub fn clone_types_with_align_custom_data_count(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, data_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            if (self.clone_raw(raw_ptr[0..raw_len], data_len, alignment, alloc_param)) |new_mem| {
                const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..memory.len];
            }
            return null;
        }
        pub inline fn slim_clone_bytes_custom_data_len(self: Self, memory: []u8, data_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]u8 {
            if (self.clone_slim_raw(memory, data_len, null, alloc_param)) |new_mem| {
                return new_mem[0..@min(data_len, memory.len)];
            }
            return null;
        }
        pub inline fn slim_clone_bytes_with_align_custom_data_len(self: Self, comptime alignment: Alignment, memory: []align(alignment.toByteUnits()) u8, data_len: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) u8 {
            if (self.clone_slim_raw(memory, data_len, alignment, alloc_param)) |new_mem| {
                return @as([*]align(alignment.toByteUnits()) u8, @ptrCast(@alignCast(new_mem)))[0..@min(data_len, memory.len)];
            }
            return null;
        }
        pub fn slim_clone_types_custom_data_count(self: Self, comptime T: type, memory: []T, data_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            if (self.clone_slim_raw(raw_ptr[0..raw_len], data_len, Alignment.fromByteUnits(@alignOf(T)), alloc_param)) |new_mem| {
                const t_ptr: [*]T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..@min(data_count, memory.len)];
            }
            return null;
        }
        pub fn slim_clone_types_with_align_custom_data_count(self: Self, comptime alignment: Alignment, comptime T: type, memory: []align(alignment.toByteUnits()) T, data_count: usize, alloc_param: SOURCE.PARAM_TYPE()) ?[]align(alignment.toByteUnits()) T {
            const raw_ptr: [*]u8 = @ptrCast(memory.ptr);
            const raw_len: usize = @sizeOf(T) * memory.len;
            const data_len = @sizeOf(T) * data_count;
            if (self.clone_slim_raw(raw_ptr[0..raw_len], data_len, alignment, alloc_param)) |new_mem| {
                const t_ptr: [*]align(alignment.toByteUnits()) T = @ptrCast(@alignCast(new_mem));
                return t_ptr[0..@min(data_count, memory.len)];
            }
            return null;
        }
        //*********
        // CREATE/DESTROY
        //*********
        pub inline fn create_with_align(self: Self, comptime T: type, comptime alignment: Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?*align(alignment.toByteUnits()) T {
            if (self.alloc_types_with_align(T, 1, alignment, alloc_param)) |slice| {
                return @ptrCast(slice.ptr);
            }
            return null;
        }
        pub inline fn create(self: Self, comptime T: type, alloc_param: SOURCE.PARAM_TYPE()) ?*T {
            if (self.alloc_types(T, 1, alloc_param)) |slice| {
                return @ptrCast(slice.ptr);
            }
            return null;
        }
        pub inline fn create_raw(self: Self, comptime T: type, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?*T {
            if (self.alloc_raw(@sizeOf(T), alignment, alloc_param)) |ptr| {
                return @ptrCast(@alignCast(ptr));
            }
            return null;
        }
        pub inline fn destroy_with_align(self: Self, comptime alignment: Alignment, comptime T: type, ptr: *align(alignment.toByteUnits()) T, alloc_param: SOURCE.PARAM_TYPE()) void {
            const slice = @as([*]align(alignment.toByteUnits()) T, @ptrCast(ptr))[0..1];
            self.free_types_with_align(alignment, T, slice, alloc_param);
        }
        pub inline fn destroy(self: Self, comptime T: type, ptr: *T, alloc_param: SOURCE.PARAM_TYPE()) void {
            const slice = @as([*]T, @ptrCast(ptr))[0..1];
            self.free_types(T, slice, alloc_param);
        }
        pub inline fn destroy_raw(self: Self, comptime T: type, ptr: *T, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) void {
            const slice = @as([*]u8, @ptrCast(ptr))[0..@sizeOf(T)];
            self.free_raw(slice, alignment, alloc_param);
        }
        pub inline fn clone_one_with_align(self: Self, comptime alignment: Alignment, comptime T: type, ptr: *align(alignment.toByteUnits()) T, alloc_param: SOURCE.PARAM_TYPE()) ?*align(alignment.toByteUnits()) T {
            if (self.create_with_align(T, alignment, alloc_param)) |new_ptr| {
                new_ptr.* = ptr.*;
                return new_ptr;
            }
            return null;
        }
        pub inline fn clone_one(self: Self, comptime T: type, ptr: *T, alloc_param: SOURCE.PARAM_TYPE()) ?*T {
            if (self.create(T, alloc_param)) |new_ptr| {
                new_ptr.* = ptr.*;
                return new_ptr;
            }
            return null;
        }
        pub inline fn clone_one_raw(self: Self, comptime T: type, ptr: *T, alignment: ?Alignment, alloc_param: SOURCE.PARAM_TYPE()) ?*T {
            if (self.create_raw(T, alignment, alloc_param)) |new_ptr| {
                new_ptr.* = ptr.*;
                return new_ptr;
            }
            return null;
        }
    };
}
