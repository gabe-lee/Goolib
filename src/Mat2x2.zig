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
const math = std.math;
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

pub fn define_matrix_2x2_type(comptime T: type) type {
    return struct {
        const Self = @This();
        const EMPTY_ROW: [3]T = @splat(0);
        const Vec2 = Root.Vec2.define_vec2_type(T);
        const ONE: T = @as(T, 1);

        data: [2][2]T = @splat(EMPTY_ROW),

        pub const IDENTITY = Self{
            .data = .{
                .{ 1, 0 },
                .{ 0, 1 },
            },
        };

        pub fn identity() Self {
            return IDENTITY;
        }

        pub fn new(row_1: [2]T, row_2: [2]T) Self {
            return Self{
                .data = .{
                    row_1,
                    row_2,
                },
            };
        }

        pub fn inverse(self: Self) Self {
            const adj = self.adjugate();
            const dtr = self.determinant();
            const inv_dtr = ONE / dtr;
            return adj.multiply_scalar(inv_dtr);
        }

        pub fn negate(self: Self) Self {
            return Self{
                .data = .{
                    .{ -self.data[0][0], -self.data[0][1] },
                    .{ -self.data[1][0], -self.data[1][1] },
                },
            };
        }

        pub fn transpose(self: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0], self.data[1][0] },
                    .{ self.data[0][1], self.data[1][1] },
                },
            };
        }

        pub fn adjugate(self: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[1][1], -self.data[0][1] },
                    .{ -self.data[1][0], self.data[0][0] },
                },
            };
        }

        pub fn determinant(self: Self) T {
            return (self.data[0][0] * self.data[1][1]) - (self.data[0][1] * self.data[1][0]);
        }

        pub fn multiply(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{
                        (self.data[0][0] * other.data[0][0]) + (self.data[0][1] * other.data[1][0]),
                        (self.data[0][0] * other.data[0][1]) + (self.data[0][1] * other.data[1][1]),
                    },
                    .{
                        (self.data[1][0] * other.data[0][0]) + (self.data[1][1] * other.data[1][0]),
                        (self.data[1][0] * other.data[0][1]) + (self.data[1][1] * other.data[1][1]),
                    },
                },
            };
        }

        /// Returns a new 'column' or 'vector'
        pub fn multiply_with_column(self: Self, column: [2]T) [2]T {
            return [2]T{
                (self.data[0][0] * column[0]) + (self.data[0][1] * column[1]),
                (self.data[1][0] * column[0]) + (self.data[1][1] * column[1]),
            };
        }

        pub fn add_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] + val, self.data[0][1] + val },
                    .{ self.data[1][0] + val, self.data[1][1] + val },
                },
            };
        }
        pub fn subtract_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] - val, self.data[0][1] - val },
                    .{ self.data[1][0] - val, self.data[1][1] - val },
                },
            };
        }
        pub fn multiply_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] * val, self.data[0][1] * val },
                    .{ self.data[1][0] * val, self.data[1][1] * val },
                },
            };
        }
        pub fn divide_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] / val, self.data[0][1] / val },
                    .{ self.data[1][0] / val, self.data[1][1] / val },
                },
            };
        }

        pub fn divide(self: Self, other: Self) Self {
            return self.multiply(other.inverse());
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] + other.data[0][0], self.data[0][1] + other.data[0][1] },
                    .{ self.data[1][0] + other.data[1][0], self.data[1][1] + other.data[1][1] },
                },
            };
        }

        pub fn subtract(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] - other.data[0][0], self.data[0][1] - other.data[0][1] },
                    .{ self.data[1][0] - other.data[1][0], self.data[1][1] - other.data[1][1] },
                },
            };
        }
    };
}
