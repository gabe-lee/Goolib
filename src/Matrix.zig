//! Defines arbitrary square matrix types with convenient algebra methods
//!
//! All methods are simply convenient wrappers around the `Math.zig` module's 'arbitrary matrix' functions
//!
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
const Types = Root.Types;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

pub fn Mat2x2(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 2);
}

pub fn Mat3x3(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 3);
}

pub fn Mat4x4(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 4);
}

pub fn define_square_NxN_matrix_type(comptime T: type, comptime N: type) type {
    return extern struct {
        const Self = @This();

        mat: [N][N]T = @splat(EMPTY_ROW),

        const EMPTY_ROW: [N]T = @splat(ZERO);
        const ONE: T = if (Types.type_is_vector(T)) @splat(1) else @as(T, 1);
        const ZERO: T = if (Types.type_is_vector(T)) @splat(0) else @as(T, 0);
        const SMALLER_MAT = define_square_NxN_matrix_type(T, N - 1);

        pub const EMPTY = Self{};

        pub const IDENTITY = make: {
            var out = Self{};
            for (0..N) |i| {
                out[i][i] = ONE;
            }
            break :make out;
        };

        pub fn empty() Self {
            return EMPTY;
        }

        pub fn identity() Self {
            return IDENTITY;
        }

        pub fn new(data: [N][N]T) Self {
            return Self{ .mat = data };
        }

        pub fn inverse(self: Self) Self {
            return @bitCast(MathX.inverse_of_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn inverse_using_adjugate_and_determinant(self_adjugate: Self, self_determinant: T) Self {
            return @bitCast(MathX.inverse_of_arbitrary_matrix_using_adjugate_and_determinant(T, N, N, @bitCast(self_adjugate), self_determinant));
        }

        pub fn negate(self: Self) Self {
            return @bitCast(MathX.negate_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn element_minor_matrix(self: Self, row: usize, col: usize) SMALLER_MAT {
            return @bitCast(MathX.minor_sub_matrix_of_arbitrary_matrix_position(T, N, N, @bitCast(self), row, col));
        }

        pub fn minor_matrix_determinants(self: Self) Self {
            return @bitCast(MathX.minor_matrix_determinants_of_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn cofactors_using_minors(self_minors: Self) Self {
            return @bitCast(MathX.cofactors_of_arbitrary_matrix_minors(T, N, N, @bitCast(self_minors)));
        }

        pub fn cofactors(self: Self) Self {
            return @bitCast(MathX.cofactors_of_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn transpose(self: Self) Self {
            return @bitCast(MathX.transpose_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn adjugate(self: Self) Self {
            return @bitCast(MathX.adjugate_of_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn adjugate_using_cofactors(self_cofactors: Self) Self {
            return @bitCast(MathX.adjugate_of_arbitrary_matrix_cofactors(T, N, N, @bitCast(self_cofactors)));
        }

        pub fn determinant(self: Self) T {
            return @bitCast(MathX.determinant_of_arbitrary_matrix(T, N, N, @bitCast(self)));
        }

        pub fn multiply(self: Self, other: Self) Self {
            return @bitCast(MathX.multiply_arbitrary_matrices(T, N, N, @bitCast(self), T, N, N, @bitCast(other), T));
        }

        /// Returns a new 'column' or 'vector'
        pub fn multiply_with_column(self: Self, column: [N]T) [N]T {
            return @bitCast(MathX.multiply_arbitrary_matrices(T, N, N, @bitCast(self), T, N, 1, @bitCast(column), T));
        }

        pub fn divide(self: Self, denominator: Self) Self {
            return @bitCast(MathX.divide_arbitrary_matrices(T, N, N, @bitCast(self), T, N, N, @bitCast(denominator), T));
        }
        pub fn divide_using_inverse_of_denominator(self: Self, denominator_inverse: Self) Self {
            return @bitCast(MathX.divide_arbitrary_matrices_using_inverse_of_denominator_matrix(T, N, N, @bitCast(self), T, N, N, @bitCast(denominator_inverse), T));
        }

        pub fn add(self: Self, other: Self) Self {
            return @bitCast(MathX.add_arbitrary_matrices(T, N, N, @bitCast(self), T, N, N, @bitCast(other), T));
        }

        pub fn subtract(self: Self, other: Self) Self {
            return @bitCast(MathX.subtract_arbitrary_matrices(T, N, N, @bitCast(self), T, N, N, @bitCast(other), T));
        }

        pub fn add_scalar(self: Self, val: anytype) Self {
            return @bitCast(MathX.add_scalar_to_arbitrary_matrix(T, N, N, @bitCast(self), val));
        }
        pub fn subtract_scalar_from_self(self: Self, val: T) Self {
            return @bitCast(MathX.subtract_scalar_from_arbitrary_matrix(T, N, N, @bitCast(self), val));
        }
        pub fn subtract_self_from_scalar(self: Self, val: T) Self {
            return @bitCast(MathX.subtract_arbitrary_matrix_from_scalar(T, N, N, @bitCast(self), val));
        }
        pub fn multiply_scalar(self: Self, val: T) Self {
            return @bitCast(MathX.multiply_arbitrary_matrix_by_scalar(T, N, N, @bitCast(self), val));
        }
        pub fn divide_self_by_scalar(self: Self, val: T) Self {
            return @bitCast(MathX.multiply_arbitrary_matrix_by_scalar(T, N, N, @bitCast(self), val));
        }
        pub fn divide_scalar_by_self(self: Self, val: T) Self {
            return @bitCast(MathX.multiply_arbitrary_matrix_by_scalar(T, N, N, @bitCast(self), val));
        }

        pub fn row_echelon_form(self: Self, leading_mode: MathX.RowEchelonLeadingMode) MathX.RowEchelonResult(T, N, N) {
            return MathX.row_echelon_form_of_arbitrary_matrix(T, leading_mode, N, N, @bitCast(self));
        }
    };
}
