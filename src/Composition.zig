//! //TODO Documentation
//! #### License: Zlib

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

pub const FieldAccessChain = struct {
    top_level_type: type,
    final_type: type,
    field_chain: []const []const u8,

    fn comptime_print(comptime self: FieldAccessChain) []const u8 {
        return std.fmt.comptimePrint("FieldAccessChain{{\n\t.top_level_type = {s},\n\t.final_type = {s},\n\t.field_chain = {s}\n}}", .{ @typeName(self.top_level_type), @typeName(self.final_type), self.field_chain });
    }

    pub fn build_accessor(comptime chain: FieldAccessChain, comptime mutability: ACCESS) if (mutability == .CONST) fn (self: *const chain.top_level_type) *const chain.final_type else fn (self: *chain.top_level_type) *chain.final_type {
        comptime assert_with_reason(chain.field_chain.len >= 1, @src(), @This(), "{s}\n`self` must provide a `field_chain` with length >= 1", .{ chain.comptime_print(), chain });
        comptime var offset: usize = 0;
        comptime var current_type: type = chain.top_level_type;
        comptime var i: usize = 0;
        inline while (i < chain.field_chain.len) : (i += 1) {
            comptime assert_with_reason(@hasField(current_type, chain.field_chain[i]), @src(), @This(), "{s}\nfield `{s}` does not exist in type {s}", .{ chain.comptime_print(), chain.field_chain[i], @typeName(current_type) });
            offset += @offsetOf(current_type, chain.field_chain[i]);
            current_type = @FieldType(current_type, chain.field_chain[i]);
        }
        comptime assert_with_reason(current_type == chain.final_type, @src(), @This(), "{s}\nfinal type {s} did not match requested final type {s}", .{ chain.comptime_print(), @typeName(current_type), @typeName(chain.final_type) });
        comptime assert_with_reason(std.mem.isAligned(offset, @alignOf(chain.final_type)), @src(), @This(), "{s}\nfinal offset {d} is not aligned to required alignment of final type {s} ({d})", .{ chain.comptime_print(), offset, @typeName(chain.final_type), @alignOf(chain.final_type) });
        const prototype = if (mutability == .CONST) struct {
            pub fn access(self: *const chain.top_level_type) *const chain.final_type {
                const base_addr = @intFromPtr(self);
                const final_addr = base_addr + offset;
                return @ptrFromInt(final_addr);
            }
        } else struct {
            pub fn access(self: *chain.top_level_type) *chain.final_type {
                const base_addr = @intFromPtr(self);
                const final_addr = base_addr + offset;
                return @ptrFromInt(final_addr);
            }
        };
        return prototype.access;
    }

    pub fn extend_chain(comptime access_chain: FieldAccessChain, comptime ext_access_chain: ExtendedAccessChain) FieldAccessChain {
        return FieldAccessChain{
            .top_level_type = ext_access_chain.container,
            .final_type = access_chain.final_type,
            .field_chain = ext_access_chain.ext_field_chain ++ access_chain.field_chain,
        };
    }

    pub const ACCESS = enum {
        CONST,
        VAR,
    };
};

pub const ExtendedAccessChain = struct {
    container: type,
    ext_field_chain: []const []const u8,
};
