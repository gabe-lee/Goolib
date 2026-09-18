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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;
const Random = std.Random;
// const pq = std.PriorityQueue;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;
const Recipes = Utils.DataManipulation.Recipes;

const DataManipulationCore = Utils.DataManipulation.DataManipulationCore;
pub const AllocMode = enum {
    NOT_ALLOCATED,
    ALLOCATED,
};
pub fn ListNoAlloc(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = undefined,
        len: IDX = 0,
        cap: IDX = 0,

        pub const PKG = Utils.DataManipulation.Defaults.classically_indexed_mem_with_cap_not_allocated_package(Self, IDX, T, &.{"ptr"}, &.{"len"}, &.{"cap"});
        pub inline fn data(self: Self) PKG.Wrapper {
            return PKG.Wrapper.new(self, void{});
        }
    };
}
pub fn ListAlloc(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = undefined,
        len: IDX = 0,
        cap: IDX = 0,

        pub const PKG = Utils.DataManipulation.Defaults.classically_indexed_mem_with_cap_allocated_package(Self, IDX, T, &.{"ptr"}, &.{"len"}, &.{"cap"});
        pub inline fn data(self: Self, alloc_info: PKG.AUX_DATA) PKG.Wrapper {
            return PKG.Wrapper.new(self, alloc_info);
        }
    };
}
pub fn SliceAlloc(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = undefined,
        len: IDX = 0,

        pub const PKG = Utils.DataManipulation.Defaults.classically_indexed_mem_allocated_package(Self, IDX, T, &.{"ptr"}, &.{"len"});
        pub inline fn data(self: Self, alloc_info: PKG.AUX_DATA) PKG.Wrapper {
            return PKG.Wrapper.new(self, alloc_info);
        }
    };
}
pub fn SliceNoAlloc(comptime T: type, comptime IDX: type) type {
    return struct {
        const Self = @This();

        ptr: [*]T = undefined,
        len: IDX = 0,

        pub const PKG = Utils.DataManipulation.Defaults.classically_indexed_mem_not_allocated_package(Self, IDX, T, &.{"ptr"}, &.{"len"});
        pub inline fn data(self: Self) PKG.Wrapper {
            return PKG.Wrapper.new(self, void{});
        }
    };
}
