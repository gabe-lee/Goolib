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

const build = @import("builtin");
const std = @import("std");
const mem = std.mem;
const math = std.math;
const meta = std.meta;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const Assert = Root.Assert;

const assert_with_reason = Assert.assert_with_reason;

pub fn define_generational_id_type(comptime gen_bits: comptime_int, comptime id_bits: comptime_int) type {
    const total_bits = gen_bits + id_bits;
    assert_with_reason(gen_bits > 0, @src(), "gen bits ({d}) must be > 0", .{gen_bits});
    assert_with_reason(id_bits > 0, @src(), "id bits ({d}) must be > 0", .{id_bits});
    return struct {
        raw: Raw,

        const Self = @This();
        pub const Gen = meta.Int(.unsigned, gen_bits);
        pub const Id = meta.Int(.unsigned, id_bits);
        pub const Raw = meta.Int(.unsigned, total_bits);

        pub const GEN_CLEAR: Raw = math.maxInt(Id);
        pub const GEN_ONE: Raw = 1 << id_bits;
        pub const ID_CLEAR: Raw = math.maxInt(Gen) << id_bits;

        pub inline fn new(gen: Gen, id: Id) Self {
            return Self{
                .raw = @as(Raw, @intCast(id)) | (@as(Raw, @intCast(gen)) << id_bits),
            };
        }

        pub inline fn get_gen(self: Self) Gen {
            return @intCast(self.raw >> id_bits);
        }
        pub inline fn set_gen(self: *Self, gen: Gen) void {
            self.raw &= GEN_CLEAR;
            self.raw |= (@as(Raw, @intCast(gen)) << id_bits);
        }
        pub inline fn increment_gen(self: *Self) void {
            self.raw += GEN_ONE;
        }

        pub inline fn get_id(self: Self) Id {
            return @intCast(self.raw & GEN_CLEAR);
        }
        pub inline fn set_id(self: *Self, id: Id) void {
            self.raw &= ID_CLEAR;
            self.raw |= @as(Raw, @intCast(id));
        }

        pub inline fn equals(self: Self, other: Self) bool {
            return self.raw == other.raw;
        }
        pub inline fn gen_equals(self: Self, other: Self) bool {
            return (self.raw & ID_CLEAR) == (other.raw & ID_CLEAR);
        }
        pub inline fn gen_is_greater_than(self: Self, other: Self) bool {
            return (self.raw & ID_CLEAR) > (other.raw & ID_CLEAR);
        }
        pub inline fn gen_is_less_than(self: Self, other: Self) bool {
            return (self.raw & ID_CLEAR) < (other.raw & ID_CLEAR);
        }
        pub inline fn gen_is_greater_than_or_equals(self: Self, other: Self) bool {
            return (self.raw & ID_CLEAR) >= (other.raw & ID_CLEAR);
        }
        pub inline fn gen_is_less_than_or_equals(self: Self, other: Self) bool {
            return (self.raw & ID_CLEAR) <= (other.raw & ID_CLEAR);
        }
        pub inline fn id_equals(self: Self, other: Self) bool {
            return (self.raw & GEN_CLEAR) == (other.raw & GEN_CLEAR);
        }
        pub inline fn id_is_greater_than(self: Self, other: Self) bool {
            return (self.raw & GEN_CLEAR) > (other.raw & GEN_CLEAR);
        }
        pub inline fn id_is_less_than(self: Self, other: Self) bool {
            return (self.raw & GEN_CLEAR) < (other.raw & GEN_CLEAR);
        }
        pub inline fn id_is_greater_than_or_equals(self: Self, other: Self) bool {
            return (self.raw & GEN_CLEAR) >= (other.raw & GEN_CLEAR);
        }
        pub inline fn id_is_less_than_or_equals(self: Self, other: Self) bool {
            return (self.raw & GEN_CLEAR) <= (other.raw & GEN_CLEAR);
        }
    };
}
