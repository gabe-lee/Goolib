//! This module provides matrix structures with aritrary types, sizes, row-column-major-order,
//! and possible padding on the end of each major (on the end of each row for row-major, on end of each col for col-major)
//!
//! All methods are simply convenient wrappers around the `Matrix_Advanced.zig` (exposed as `Advanced` here) module's functions,
//! which provide more flexibility at the cost of a lot more verbosity.
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

const Root = @import("./_root.zig");
const ShapeWinding = Root.CommonTypes.ShapeWinding;
const Assert = Root.Assert;
const MathX = Root.Math;
const SDL3 = Root.SDL3;
const Types = Root.Types;

const assert_is_float = Assert.assert_is_float;
const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

pub fn assert_anytype_is_matrix_and_get_def(val: anytype, src: ?std.builtin.SourceLocation) MatrixDef {
    assert_with_reason(Types.type_has_decl_with_type(@TypeOf(val), "DEF", MatrixDef), src, "type is not a matrix (missing `DEF` declaration with type `MatrixDef`), got type `{s}`", .{@typeName(@TypeOf(val))});
    const MAT = @field(val, "DEF").Matrix();
    assert_with_reason(Types.type_has_field_with_type(@TypeOf(val), "mat", MAT), src, "type is not a matrix (missing `mat` field with type `{s}`), got type `{s}`", .{ @typeName(MAT), @typeName(@TypeOf(val)) });
    return @field(val, "DEF");
}

pub const RowColumnOrder = Root.CommonTypes.RowColumnOrder;
pub const Advanced = @import("./Matrix_Advanced.zig");
pub const MatrixDef = Advanced.MatrixDef;

/// Row-major, 0 padding
pub fn Mat2x2(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 2, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat3x3(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 3, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat4x4(comptime T: type) type {
    return define_square_NxN_matrix_type(T, 4, .ROW_MAJOR, 0);
}

/// Row-major, 0 padding
pub fn Mat2x3(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 2, 3, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat2x4(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 2, 4, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat3x2(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 3, 2, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat4x2(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 4, 2, .ROW_MAJOR, 0);
}

/// Row-major, 0 padding
pub fn Mat3x4(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 3, 4, .ROW_MAJOR, 0);
}
/// Row-major, 0 padding
pub fn Mat4x3(comptime T: type) type {
    return define_rectangular_RxC_matrix_type(T, 4, 3, .ROW_MAJOR, 0);
}

pub fn define_square_NxN_matrix_type_from_def(comptime DEF: Advanced.MatrixDef) type {
    assert_with_reason(DEF.ROWS == DEF.COLS, @src(), "cannot define a square matrix type from a non-square matrix def, got {d}x{d}", .{ DEF.ROWS, DEF.COLS });
    return define_square_NxN_matrix_type(DEF.T, DEF.ROWS, DEF.ORDER, DEF.MAJOR_PAD);
}

pub fn define_square_NxN_matrix_type(
    comptime T: type,
    comptime N: comptime_int,
    comptime ORDER: Root.CommonTypes.RowColumnOrder,
    comptime MAJOR_PAD: comptime_int,
) type {
    return define_rectangular_RxC_matrix_type(T, N, N, ORDER, MAJOR_PAD);
}

pub fn define_rectangular_RxC_matrix_type_from_def(comptime DEF: Advanced.MatrixDef) type {
    return define_rectangular_RxC_matrix_type(DEF.T, DEF.ROWS, DEF.COLS, DEF.ORDER, DEF.MAJOR_PAD);
}

pub fn define_rectangular_RxC_matrix_type(
    comptime T: type,
    comptime ROWS: comptime_int,
    comptime COLS: comptime_int,
    comptime ORDER: Root.CommonTypes.RowColumnOrder,
    comptime MAJOR_PAD: comptime_int,
) type {
    return extern struct {
        const Self = @This();

        mat: DEF.Matrix() = @splat(@splat(ZERO)),

        // const EMPTY_MAJOR: [DEF.minor_len()]T = @splat(ZERO);
        const ONE: T = if (Types.type_is_vector(T)) @splat(1) else @as(T, 1);
        const ZERO: T = if (Types.type_is_vector(T)) @splat(0) else @as(T, 0);
        const SMALLER_MAT = define_rectangular_RxC_matrix_type(T, ROWS - 1, COLS - 1, ORDER, 0);
        const IS_SQUARE = ROWS == COLS;
        pub const DEF = Advanced.MatrixDef{
            .T = T,
            .COLS = COLS,
            .ROWS = ROWS,
            .MAJOR_PAD = MAJOR_PAD,
            .ORDER = ORDER,
        };

        pub const EMPTY = Self{};

        pub const IDENTITY = make: {
            var out = Self{};
            if (IS_SQUARE) {
                for (0..ROWS) |i| {
                    out[i][i] = ONE;
                }
            }

            break :make out;
        };

        pub fn empty() Self {
            return EMPTY;
        }

        /// For square matrices this is a matrix filled with all 0's
        /// except on the main diagonal which is all 1's
        ///
        /// for non-square matrices this is filled with all zeroes
        pub fn identity() Self {
            return IDENTITY;
        }

        pub fn new(data: DEF.Matrix()) Self {
            return Self{ .mat = data };
        }

        /// This method copies the data to the destination without touching the
        /// padding bytes. Use this method if other values may be packed into the
        /// memory regions of the padding areas in the destination
        ///
        /// One use case is for writing a matrix into a GPU UniformBuffer,
        /// where fields are allowed to be packed into the last padding
        /// area of the matrix
        ///
        /// If there is no padding this function compiles to `dest.* = src.*;`
        pub inline fn safe_copy_skip_all_pad(src: *const Self, dest: *Self) void {
            Advanced.safe_copy_skip_all_pad(DEF, &src.mat, &dest.mat);
        }

        /// This method copies the data to the destination without touching the
        /// *last* padding bytes. Use this method if other values may be packed into the
        /// memory regions of the last padding area in the destination
        ///
        /// One use case is for writing a matrix into a GPU UniformBuffer,
        /// where fields are allowed to be packed into the last padding
        /// area of the matrix
        ///
        /// If there is no padding this function compiles to `dest.* = src.*;`
        pub inline fn safe_copy_skip_last_pad(src: *const Self, dest: *Self) void {
            Advanced.safe_copy_skip_last_pad(DEF, &src.mat, &dest.mat);
        }

        /// Only valid for square matrices with non-zero determinants
        pub inline fn inverse(self: Self) Self {
            return @bitCast(Advanced.inverse_of_matrix(DEF, self.mat, T));
        }
        /// Only valid for square matrices with non-zero determinants
        pub inline fn inverse_with_new_type(self: Self, comptime NEW_T: type) define_rectangular_RxC_matrix_type(NEW_T, ROWS, COLS, ORDER, MAJOR_PAD) {
            return @bitCast(Advanced.inverse_of_matrix(DEF, self.mat, NEW_T));
        }

        /// Only valid for square matrices with non-zero determinants
        pub inline fn inverse_using_adjugate_and_determinant(self_adjugate: Self, self_determinant: anytype) Self {
            return @bitCast(Advanced.inverse_of_matrix_using_adjugate_and_determinant(DEF, self_adjugate.mat, self_determinant, T));
        }
        /// Only valid for square matrices with non-zero determinants
        pub inline fn inverse_using_adjugate_and_determinant_with_new_type(self_adjugate: Self, self_determinant: anytype, comptime NEW_T: type) define_rectangular_RxC_matrix_type(NEW_T, ROWS, COLS, ORDER, MAJOR_PAD) {
            return @bitCast(Advanced.inverse_of_matrix_using_adjugate_and_determinant(DEF, self_adjugate.mat, self_determinant, NEW_T));
        }

        pub inline fn negate(self: Self) Self {
            return @bitCast(Advanced.negate_matrix_elements(DEF, self.mat, T));
        }
        pub inline fn negate_with_new_type(self: Self, comptime NEW_T: type) define_rectangular_RxC_matrix_type(NEW_T, ROWS, COLS, ORDER, MAJOR_PAD) {
            return @bitCast(Advanced.negate_matrix_elements(DEF, self.mat, NEW_T));
        }

        pub inline fn sub_matrix_excluding_row_and_column(self: Self, row: usize, col: usize) SMALLER_MAT {
            return @bitCast(Advanced.sub_matrix_excluding_row_and_column(DEF, self.mat, row, col));
        }

        pub inline fn cofactors(self: Self) Self {
            return @bitCast(Advanced.cofactors_of_matrix(DEF, self.mat, T));
        }
        pub inline fn cofactors_with_new_type(self: Self, comptime NEW_T: type) define_rectangular_RxC_matrix_type(NEW_T, ROWS, COLS, ORDER, MAJOR_PAD) {
            return @bitCast(Advanced.cofactors_of_matrix(DEF, self.mat, NEW_T));
        }

        pub inline fn transpose(self: Self) Self {
            return @bitCast(Advanced.transpose_matrix(DEF, self.mat));
        }

        pub inline fn adjugate(self: Self) Self {
            return @bitCast(Advanced.adjugate_of_matrix(DEF, self.mat, T));
        }
        pub inline fn adjugate_with_new_type(self: Self, comptime NEW_T: type) define_rectangular_RxC_matrix_type(NEW_T, ROWS, COLS, ORDER, MAJOR_PAD) {
            return @bitCast(Advanced.adjugate_of_matrix(DEF, self.mat, NEW_T));
        }

        pub inline fn adjugate_using_cofactors(self_cofactors: Self) Self {
            return @bitCast(Advanced.adjugate_of_matrix_using_cofactors(DEF, self_cofactors.mat));
        }

        /// Only valid for square matrices
        pub inline fn determinant(self: Self) T {
            return @bitCast(Advanced.determinant_of_matrix(DEF, self.mat, T));
        }
        /// Only valid for square matrices
        pub inline fn determinant_with_type(self: Self, comptime DETERMINANT_T: type) DETERMINANT_T {
            return @bitCast(Advanced.determinant_of_matrix(DEF, self.mat, DETERMINANT_T));
        }

        /// Only valid for square matrices
        pub inline fn determinant_using_precomputed_cofactors(self: Self, known_cofactors: anytype) T {
            const CO_DEF = assert_anytype_is_matrix_and_get_def(known_cofactors, @src());
            return @bitCast(Advanced.determinant_of_matrix_precomputed_cofactors(DEF, self.mat, CO_DEF, known_cofactors.mat, T));
        }
        /// Only valid for square matrices
        pub inline fn determinant_using_precomputed_cofactors_with_type(self: Self, known_cofactors: anytype, comptime DETERMINANT_T: type) DETERMINANT_T {
            const CO_DEF = assert_anytype_is_matrix_and_get_def(known_cofactors, @src());
            return @bitCast(Advanced.determinant_of_matrix_precomputed_cofactors(DEF, self.mat, CO_DEF, known_cofactors.mat, DETERMINANT_T));
        }

        /// Only valid when self columns == other rows
        pub inline fn multiply(self: Self, other: anytype) Self {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.multiply_matrices(DEF, self.mat, OTHER_DEF, other.mat, T, ORDER, MAJOR_PAD));
        }
        /// Only valid when self columns == other rows
        pub inline fn multiply_with_new_layout(self: Self, other: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.Multiplied(DEF, NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.multiply_matrices(DEF, self.mat, OTHER_DEF, other.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        /// Only valid for square matrices with non-zero determinants
        pub inline fn divide(self: Self, denominator: anytype) Self {
            const DENOM_DEF = assert_anytype_is_matrix_and_get_def(denominator, @src());
            return @bitCast(Advanced.divide_matrices(DEF, self.mat, DENOM_DEF, denominator.mat, T, ORDER, MAJOR_PAD));
        }
        /// Only valid for square matrices with non-zero determinants
        pub inline fn divide_with_new_layout(self: Self, denominator: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.Multiplied(DEF, NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const DENOM_DEF = assert_anytype_is_matrix_and_get_def(denominator, @src());
            return @bitCast(Advanced.divide_matrices(DEF, self.mat, DENOM_DEF, denominator.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }
        /// Only valid for square matrices with non-zero determinants
        pub inline fn divide_using_inverse_of_denominator(self: Self, denominator_inverse: anytype) Self {
            const INV_DENOM_DEF = assert_anytype_is_matrix_and_get_def(denominator_inverse, @src());
            return @bitCast(Advanced.divide_matrices_using_inverse_of_denominator_matrix(DEF, self.mat, INV_DENOM_DEF, denominator_inverse.mat, T, ORDER, MAJOR_PAD));
        }
        /// Only valid for square matrices with non-zero determinants
        pub inline fn divide_using_inverse_of_denominator_with_new_layout(self: Self, denominator_inverse: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.Multiplied(DEF, NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const INV_DENOM_DEF = assert_anytype_is_matrix_and_get_def(denominator_inverse, @src());
            return @bitCast(Advanced.divide_matrices_using_inverse_of_denominator_matrix(DEF, self.mat, INV_DENOM_DEF, denominator_inverse.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        /// This simply multiplies each cell in `self` with the matching cell in `other`
        ///
        /// This is NOT the same as a true matrix multiplication
        pub inline fn non_algebraic_multiply(self: Self, other: anytype) Self {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.non_algebraic_multiply_matrices(DEF, self.mat, OTHER_DEF, other.mat, T, ORDER, MAJOR_PAD));
        }
        /// This simply multiplies each cell in `self` with the matching cell in `other`
        ///
        /// This is NOT the same as a true matrix multiplication
        pub inline fn non_algebraic_multiply_with_new_layout(self: Self, other: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type_order_padding(NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.non_algebraic_multiply_matrices(DEF, self.mat, OTHER_DEF, other.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        /// This simply divides each cell in `self` by the matching cell in `other`
        ///
        /// This is NOT the same as a true matrix division (multiplication by inverse)
        pub inline fn non_algebraic_divide(self: Self, other: anytype) Self {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.non_algebraic_divide_matrices(DEF, self.mat, OTHER_DEF, other.mat, T, ORDER, MAJOR_PAD));
        }
        /// This simply divides each cell in `self` by the matching cell in `other`
        ///
        /// This is NOT the same as a true matrix division (multiplication by inverse)
        pub inline fn non_algebraic_divide_with_new_layout(self: Self, other: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type_order_padding(NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.non_algebraic_divide_matrices(DEF, self.mat, OTHER_DEF, other.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        pub inline fn add(self: Self, other: anytype) Self {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.add_matrices(DEF, self.mat, OTHER_DEF, other.mat, T, ORDER, MAJOR_PAD));
        }
        pub inline fn add_with_new_layout(self: Self, other: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type_order_padding(NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.add_matrices(DEF, self.mat, OTHER_DEF, other.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        pub inline fn subtract(self: Self, other: anytype) Self {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.subtract_matrices(DEF, self.mat, OTHER_DEF, other.mat, T, ORDER, MAJOR_PAD));
        }
        pub inline fn subtract_with_new_layout(self: Self, other: anytype, comptime NEW_TYPE: type, comptime NEW_ORDER: type, comptime NEW_PADDING: comptime_int) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type_order_padding(NEW_TYPE, NEW_ORDER, NEW_PADDING)) {
            const OTHER_DEF = assert_anytype_is_matrix_and_get_def(other, @src());
            return @bitCast(Advanced.subtract_matrices(DEF, self.mat, OTHER_DEF, other.mat, NEW_TYPE, NEW_ORDER, NEW_PADDING));
        }

        pub inline fn add_scalar(self: Self, val: anytype) Self {
            return @bitCast(Advanced.add_scalar_to_matrix(DEF, self.mat, val, T));
        }
        pub inline fn add_scalar_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.add_scalar_to_matrix(DEF, self.mat, val, NEW_TYPE));
        }
        pub inline fn subtract_scalar(self: Self, val: anytype) Self {
            return @bitCast(Advanced.subtract_scalar_from_matrix(DEF, self.mat, val, T));
        }
        pub inline fn subtract_scalar_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.subtract_scalar_from_matrix(DEF, self.mat, val, NEW_TYPE));
        }
        pub inline fn subtract_self_from_scalar(self: Self, val: anytype) Self {
            return @bitCast(Advanced.subtract_matrix_from_scalar(DEF, self.mat, val, T));
        }
        pub inline fn subtract_self_from_scalar_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.subtract_matrix_from_scalar(DEF, self.mat, val, NEW_TYPE));
        }
        pub inline fn multiply_by_scalar(self: Self, val: anytype) Self {
            return @bitCast(Advanced.multiply_matrix_by_scalar(DEF, self.mat, val, T));
        }
        pub inline fn multiply_by_scalar_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.multiply_matrix_by_scalar(DEF, self.mat, val, NEW_TYPE));
        }
        pub inline fn divide_by_scalar(self: Self, val: anytype) Self {
            return @bitCast(Advanced.divide_matrix_by_scalar(DEF, self.mat, val, T));
        }
        pub inline fn divide_by_scalar_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.divide_matrix_by_scalar(DEF, self.mat, val, NEW_TYPE));
        }
        pub inline fn divide_scalar_by_self(self: Self, val: anytype) Self {
            return @bitCast(Advanced.divide_scalar_by_matrix(DEF, self.mat, val, T));
        }
        pub inline fn divide_scalar_by_self_with_new_type(self: Self, val: anytype, comptime NEW_TYPE: type) define_rectangular_RxC_matrix_type_from_def(DEF.with_new_type(NEW_TYPE)) {
            return @bitCast(Advanced.divide_scalar_by_matrix(DEF, self.mat, val, NEW_TYPE));
        }

        pub inline fn row_echelon_form(self: Self, mode: Advanced.RowEchelonMode, short_circuit: Advanced.RowEchelonShortCircuitMode, comptime PIVOT_MODE: Advanced.RowEchelonPivotCache) RowEchelonForm(DEF.with_new_type(T), T, T, PIVOT_MODE) {
            return @bitCast(Advanced.row_echelon_form_of_matrix(DEF, self.mat, mode, short_circuit, T, T, PIVOT_MODE));
        }
        pub inline fn row_echelon_form_with_new_type(self: Self, mode: Advanced.RowEchelonMode, short_circuit: Advanced.RowEchelonShortCircuitMode, comptime CELL_TYPE: type, comptime DETERMINANT_TYPE: type, comptime PIVOT_MODE: Advanced.RowEchelonPivotCache) RowEchelonForm(DEF.with_new_type(CELL_TYPE), CELL_TYPE, DETERMINANT_TYPE, PIVOT_MODE) {
            return @bitCast(Advanced.row_echelon_form_of_matrix(DEF, self.mat, mode, short_circuit, CELL_TYPE, DETERMINANT_TYPE, PIVOT_MODE));
        }
    };
}

/// This layout exactly matches the equivalent in `Matrix_Advanced.zig`, but with the `mat` field as a matrix wrapper instead
pub fn RowEchelonForm(comptime _DEF: MatrixDef, comptime CELL_TYPE: type, comptime DETERMINANT_TYPE: type, comptime PIVOT_MODE: Advanced.RowEchelonPivotCache) type {
    return extern struct {
        const Self = @This();
        pub const DEF = _DEF.with_new_type(CELL_TYPE);

        rank: usize = 0,
        determinant_factor: DETERMINANT_TYPE = 1,
        pivots: switch (PIVOT_MODE) {
            .DO_NOT_CACHE_PIVOTS => void,
            .CACHE_PIVOT_X_INDEXES => [DEF.ROWS]usize,
            .CACHE_PIVOT_VALUES => [DEF.ROWS]DEF.T,
        } = switch (PIVOT_MODE) {
            .DO_NOT_CACHE_PIVOTS => void{},
            .CACHE_PIVOT_X_INDEXES => @as([DEF.ROWS]usize, @splat(0)),
            .CACHE_PIVOT_VALUES => @as([DEF.ROWS]CELL_TYPE, @splat(0)),
        },
        mat: define_rectangular_RxC_matrix_type_from_def(DEF),
    };
}
