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

pub fn define_matrix_3x3_type(comptime T: type) type {
    return struct {
        const Self = @This();
        const EMPTY_ROW: [3]T = @splat(0);
        const Vec2 = Root.Vec2.define_vec2_type(T);
        const Mat2x2 = Root.Mat2x2.define_matrix_2x2_type(T);
        const ONE: T = @as(T, 1);

        data: [3][3]T = @splat(EMPTY_ROW),

        pub const IDENTITY = Self{
            .data = .{
                .{ 1, 0, 0 },
                .{ 0, 1, 0 },
                .{ 0, 0, 1 },
            },
        };

        pub fn identity() Self {
            return IDENTITY;
        }

        pub fn new(row_1: [3]T, row_2: [3]T, row_3: [3]T) Self {
            return Self{
                .data = .{
                    row_1,
                    row_2,
                    row_3,
                },
            };
        }

        pub fn inverse(self: Self) Self {
            const _adjugate = self.adjugate();
            const dtr = self.determinant();
            return _adjugate.inverse_using_adjugate_and_determinant(dtr);
        }

        pub fn inverse_using_adjugate_and_determinant(self_adjugate: Self, self_determinant: T) Self {
            const inv_dtr = ONE / self_determinant;
            return self_adjugate.multiply_scalar(inv_dtr);
        }

        pub fn negate(self: Self) Self {
            return Self{
                .data = .{
                    .{ -self.data[0][0], -self.data[0][1], -self.data[0][2] },
                    .{ -self.data[1][0], -self.data[1][1], -self.data[1][2] },
                    .{ -self.data[2][0], -self.data[2][1], -self.data[2][2] },
                },
            };
        }

        pub fn element_minor_matrix(self: Self, row: usize, col: usize) Mat2x2 {
            var out: Mat2x2 = .{};
            var out_row: usize = 0;
            var out_col: usize = 0;
            inline for (0..3) |in_row| {
                if (row == in_row) continue;
                out_col = 0;
                inline for (0..3) |in_col| {
                    if (col == in_col) continue;
                    out.data[out_row][out_col] = self.data[in_row][in_col];
                    out_col += 1;
                }
                out_row += 1;
            }
            return out;
        }

        pub fn minor_matrix_determinants(self: Self) Self {
            return Self{
                .data = .{
                    .{ self.element_minor_matrix(0, 0).determinant(), self.element_minor_matrix(0, 1).determinant(), self.element_minor_matrix(0, 2).determinant() },
                    .{ self.element_minor_matrix(1, 0).determinant(), self.element_minor_matrix(1, 1).determinant(), self.element_minor_matrix(1, 2).determinant() },
                    .{ self.element_minor_matrix(2, 0).determinant(), self.element_minor_matrix(2, 1).determinant(), self.element_minor_matrix(2, 2).determinant() },
                },
            };
        }

        pub fn cofactors_using_minors(self_minors: Self) Self {
            var _cofactors = self_minors;
            inline for (0..3) |y| {
                const yy = y + 1;
                inline for (0..3) |x| {
                    const xx = x + 1;
                    if ((yy + xx) & 1 == 1) {
                        _cofactors[y][x] = -_cofactors[y][x];
                    }
                }
            }
            return _cofactors;
        }

        pub fn cofactors(self: Self) Self {
            var minors = self.minor_matrix_determinants();
            return minors.cofactors_using_minors();
        }

        pub fn transpose(self: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0], self.data[1][0], self.data[2][0] },
                    .{ self.data[0][1], self.data[1][1], self.data[2][1] },
                    .{ self.data[0][2], self.data[1][2], self.data[2][2] },
                },
            };
        }

        pub fn adjugate(self: Self) Self {
            const _cofactors = self.cofactors();
            return _cofactors.adjugate_using_cofactors();
        }

        pub fn adjugate_using_cofactors(self_cofactors: Self) Self {
            return self_cofactors.transpose();
        }

        pub fn determinant(self: Self) T {
            return (self.data[0][0] * ((self.data[1][1] * self.data[2][2]) - (self.data[1][2] * self.data[2][1]))) -
                (self.data[0][1] * ((self.data[1][0] * self.data[2][2]) - (self.data[1][2] * self.data[2][0]))) +
                (self.data[0][2] * ((self.data[1][0] * self.data[2][1]) - (self.data[1][1] * self.data[2][0])));
        }

        pub fn multiply(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{
                        (self.data[0][0] * other.data[0][0]) + (self.data[0][1] * other.data[1][0]) + (self.data[0][2] * other.data[2][0]),
                        (self.data[0][0] * other.data[0][1]) + (self.data[0][1] * other.data[1][1]) + (self.data[0][2] * other.data[2][1]),
                        (self.data[0][0] * other.data[0][2]) + (self.data[0][1] * other.data[1][2]) + (self.data[0][2] * other.data[2][2]),
                    },
                    .{
                        (self.data[1][0] * other.data[0][0]) + (self.data[1][1] * other.data[1][0]) + (self.data[1][2] * other.data[2][0]),
                        (self.data[1][0] * other.data[0][1]) + (self.data[1][1] * other.data[1][1]) + (self.data[1][2] * other.data[2][1]),
                        (self.data[1][0] * other.data[0][2]) + (self.data[1][1] * other.data[1][2]) + (self.data[1][2] * other.data[2][2]),
                    },
                    .{
                        (self.data[2][0] * other.data[0][0]) + (self.data[2][1] * other.data[1][0]) + (self.data[2][2] * other.data[2][0]),
                        (self.data[2][0] * other.data[0][1]) + (self.data[2][1] * other.data[1][1]) + (self.data[2][2] * other.data[2][1]),
                        (self.data[2][0] * other.data[0][2]) + (self.data[2][1] * other.data[1][2]) + (self.data[2][2] * other.data[2][2]),
                    },
                },
            };
        }

        /// Returns a new 'column' or 'vector'
        pub fn multiply_with_column(self: Self, column: [3]T) [3]T {
            return [3]T{
                (self.data[0][0] * column[0]) + (self.data[0][1] * column[1]) + (self.data[0][2] * column[2]),
                (self.data[1][0] * column[0]) + (self.data[1][1] * column[1]) + (self.data[1][2] * column[2]),
                (self.data[2][0] * column[0]) + (self.data[2][1] * column[1]) + (self.data[2][2] * column[2]),
            };
        }

        pub fn divide(self: Self, other: Self) Self {
            return self.multiply(other.inverse());
        }
        pub fn divide_using_other_adjugate_and_determinant(self: Self, other_adjugate: Self, other_determinant: T) Self {
            return self.multiply(other_adjugate.inverse_using_adjugate_and_determinant(other_determinant));
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] + other.data[0][0], self.data[0][1] + other.data[0][1], self.data[0][2] + other.data[0][2] },
                    .{ self.data[1][0] + other.data[1][0], self.data[1][1] + other.data[1][1], self.data[1][2] + other.data[1][2] },
                    .{ self.data[2][0] + other.data[2][0], self.data[2][1] + other.data[2][1], self.data[2][2] + other.data[2][2] },
                },
            };
        }

        pub fn subtract(self: Self, other: Self) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] - other.data[0][0], self.data[0][1] - other.data[0][1], self.data[0][2] - other.data[0][2] },
                    .{ self.data[1][0] - other.data[1][0], self.data[1][1] - other.data[1][1], self.data[1][2] - other.data[1][2] },
                    .{ self.data[2][0] - other.data[2][0], self.data[2][1] - other.data[2][1], self.data[2][2] - other.data[2][2] },
                },
            };
        }

        pub fn add_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] + val, self.data[0][1] + val, self.data[0][2] + val },
                    .{ self.data[1][0] + val, self.data[1][1] + val, self.data[1][2] + val },
                    .{ self.data[2][0] + val, self.data[2][1] + val, self.data[2][2] + val },
                },
            };
        }
        pub fn subtract_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] - val, self.data[0][1] - val, self.data[0][2] - val },
                    .{ self.data[1][0] - val, self.data[1][1] - val, self.data[1][2] - val },
                    .{ self.data[2][0] - val, self.data[2][1] - val, self.data[2][2] - val },
                },
            };
        }
        pub fn multiply_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] * val, self.data[0][1] * val, self.data[0][2] * val },
                    .{ self.data[1][0] * val, self.data[1][1] * val, self.data[1][2] * val },
                    .{ self.data[2][0] * val, self.data[2][1] * val, self.data[2][2] * val },
                },
            };
        }
        pub fn divide_scalar(self: Self, val: T) Self {
            return Self{
                .data = .{
                    .{ self.data[0][0] / val, self.data[0][1] / val, self.data[0][2] / val },
                    .{ self.data[1][0] / val, self.data[1][1] / val, self.data[1][2] / val },
                    .{ self.data[2][0] / val, self.data[2][1] / val, self.data[2][2] / val },
                },
            };
        }
    };
}
