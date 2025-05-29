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

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub const ACCESS_MODE = enum {
    CONST,
    VAR,
    COPY,
};

pub fn AccessorReturn(comptime Self: type, comptime T: type) type {
    return struct {
        const_ptr: fn (self: *const Self) *const T,
        var_ptr: fn (self: *Self) *T,
        copy: fn (self: *const Self) T,
    };
}

pub fn build_accessors(comptime container: type, comptime field_chain: []const []const u8, comptime final_type: type) AccessorReturn(container, final_type) {
    comptime assert_with_reason(field_chain.len >= 1, @src(), @This(), "INPUTS:\ncontainer: {s}\nfield_chain = {s}\nfinal_type = {s}\nvvvv\n`field_chain` must have a length >= 1", .{ @typeName(container), field_chain, @typeName(final_type) });
    comptime var offset: usize = 0;
    comptime var current_type: type = container;
    comptime var i: usize = 0;
    inline while (i < field_chain.len) : (i += 1) {
        comptime assert_with_reason(@hasField(current_type, field_chain[i]), @src(), @This(), "INPUTS:\ncontainer: {s}\nfield_chain = {s}\nfinal_type = {s}\nvvvv\nfield `{s}` does not exist in type {s}", .{ @typeName(container), field_chain, @typeName(final_type), field_chain[i], @typeName(current_type) });
        offset += @offsetOf(current_type, field_chain[i]);
        current_type = @FieldType(current_type, field_chain[i]);
    }
    comptime assert_with_reason(current_type == final_type, @src(), @This(), "INPUTS:\ncontainer: {s}\nfield_chain = {s}\nfinal_type = {s}\nvvvv\nreal final type {s} did not match requested final type {s}", .{ @typeName(container), field_chain, @typeName(final_type), @typeName(current_type), @typeName(final_type) });
    comptime assert_with_reason(std.mem.isAligned(offset, @alignOf(field_chain.final_type)), @src(), @This(), "INPUTS:\ncontainer: {s}\nfield_chain = {s}\nfinal_type = {s}\nvvvv\nfinal offset {d} is not aligned to required alignment of final type {s} ({d})", .{ @typeName(container), field_chain, @typeName(final_type), offset, @typeName(final_type), @alignOf(final_type) });
    const prototype = struct {
        fn acc_cnst(self: *const container) *const final_type {
            const base_addr = @intFromPtr(self);
            const final_addr = base_addr + offset;
            return @ptrFromInt(final_addr);
        }

        fn acc_var(self: *container) *final_type {
            const base_addr = @intFromPtr(self);
            const final_addr = base_addr + offset;
            return @ptrFromInt(final_addr);
        }

        fn acc_copy(self: *const container) final_type {
            const base_addr = @intFromPtr(self);
            const final_addr = base_addr + offset;
            return @as(*const final_type, @ptrFromInt(final_addr)).*;
        }
    };
    return AccessorReturn(container, final_type){
        .const_ptr = prototype.acc_cnst,
        .var_ptr = prototype.acc_var,
        .copy = prototype.acc_copy,
    };
}

pub const ExtendedAccessChain = struct {
    container: type,
    ext_field_chain: []const []const u8,
};
