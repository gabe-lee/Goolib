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
const testing = std.testing;

const Root = @import("./_root.zig");
const Matrix = Root.Matrix;
const Advanced = Matrix.Advanced;
const MatrixDef = Advanced.MatrixDef;
const RowColOrder = Matrix.RowColumnOrder;

test "Matrix -> row_indices and col_indices return the indices" {
    const DEF = MatrixDef.def(u8, 3, 4, .ROW_MAJOR, 0);
    const rows = DEF.row_indices();
    const cols = DEF.col_indices();
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2 }, &rows);
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2, 3 }, &cols);
}

test "Matrix -> clone_to_new_type" {
    const DEF = MatrixDef.def(i32, 2, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
    };
    const out = DEF.clone_to_new_type(mat, f64);
    for (0..2) |y| {
        for (0..3) |x| {
            try testing.expectEqual(@as(f64, @floatFromInt(mat[y][x])), out[y][x]);
        }
    }
}

test "Matrix -> non_algebraic_divide_matrices divides cell-by-cell" {
    const DEF = MatrixDef.def(i32, 2, 2, .ROW_MAJOR, 0);
    const mat_a: DEF.Matrix() = .{
        .{ 8, 9 },
        .{ 10, 12 },
    };
    const mat_b: DEF.Matrix() = .{
        .{ 2, 3 },
        .{ 5, 4 },
    };
    const out = Advanced.non_algebraic_divide_matrices(DEF, mat_a, DEF, mat_b, i32, .ROW_MAJOR, 0);
    const expected: [2][2]i32 = .{
        .{ 4, 3 },
        .{ 2, 3 },
    };
    const out_flat: [4]i32 = @bitCast(out);
    const expected_flat: [4]i32 = @bitCast(expected);
    try testing.expectEqualSlices(i32, &out_flat, &expected_flat);
}

test "Matrix -> row_or_col_with_fewest_non_zeroes records a dense row" {
    const DEF = MatrixDef.def(f32, 3, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
        .{ 7, 8, 9 },
    };
    const result = Advanced.row_or_col_with_fewest_non_zeroes(DEF, mat);
    try testing.expectEqual(@as(usize, 3), result.non_zero_count);
    try testing.expectEqual(Advanced.RowOrColKind.ROW, result.kind);
    try testing.expectEqualSlices(usize, &[_]usize{ 0, 1, 2 }, result.non_zero_indices[0..result.non_zero_count]);
}

test "Matrix -> determinant_of_matrix_precomputed_cofactors" {
    const DEF = MatrixDef.def(f32, 3, 3, .ROW_MAJOR, 0);
    // clearly invertible 3x3 with a determinant of 1
    const mat: DEF.Matrix() = .{
        .{ 1, 2, 3 },
        .{ 0, 1, 4 },
        .{ 5, 6, 0 },
    };
    const cofactors = Advanced.cofactors_of_matrix(DEF, mat, f32);
    const det = Advanced.determinant_of_matrix_precomputed_cofactors(DEF, mat, DEF, cofactors, f32);
    try testing.expectApproxEqAbs(@as(f32, 1), det, 1e-5);
}

test "Matrix -> row_echelon_form_of_matrix picks the largest pivot" {
    const DEF = MatrixDef.def(f32, 3, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 100, 1, 2 },
        .{ 0.5, 3, 4 },
        .{ 75, 5, 6 },
    };
    const result = Advanced.row_echelon_form_of_matrix(DEF, mat, .ROW_ECHELON_LEADING_NON_ZERO, .STOP_IF_NOT_FULL_RANK, f32, f32, .DO_NOT_CACHE_PIVOTS);
    try testing.expectEqual(@as(usize, 3), result.rank);
    // partial pivoting must move the largest absolute value in the column to the pivot
    try testing.expectApproxEqAbs(@as(f32, 100), result.mat[0][0], 1e-4);
}

test "Matrix -> change_matrix_major_order" {
    const DEF_IN = MatrixDef.def(u8, 3, 4, .ROW_MAJOR, 0);
    const DEF_OUT = MatrixDef.def(u8, 3, 4, .COLUMN_MAJOR, 0);
    const vec_in = [12]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    const mat_in: DEF_IN.Matrix() = @bitCast(vec_in);
    const mat_out: DEF_OUT.Matrix() = Advanced.change_matrix_major_order(DEF_IN, mat_in, .COLUMN_MAJOR);
    const vec_out: [12]u8 = @bitCast(mat_out);
    const expect_vec_out = [12]u8{ 1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 };
    const slice_out: []const u8 = vec_out[0..];
    const expect_slice_out: []const u8 = expect_vec_out[0..];
    try Root.Testing.expect_slices_equal(slice_out[0..], "slice_out", expect_slice_out[0..], "expect_slice_out", "resulting in-memory order not as expected", .{});
}

test "Matrix -> multiply_matrices" {
    const DEF_A = MatrixDef.def(i32, 3, 4, .ROW_MAJOR, 0);
    const DEF_B = MatrixDef.def(i32, 4, 3, .ROW_MAJOR, 0);
    const OUT_T = i32;
    const OUT_ORDER = RowColOrder.ROW_MAJOR;
    const OUT_PADDING = 0;
    const MAT_A = DEF_A.Matrix();
    const MAT_B = DEF_B.Matrix();
    const mat_a = MAT_A{
        .{ 7, 2, 9, -1 },
        .{ 3, 8, -6, 5 },
        .{ -4, 6, 1, 8 },
    };
    const mat_b = MAT_B{
        .{ 9, -3, 5 },
        .{ 2, -2, 3 },
        .{ 13, 6, 6 },
        .{ -4, 5, 7 },
    };
    // For calculating via online calculators:
    // {{ 7, 2, 9, -1 },{ 3, 8, -6, 5 },{ -4, 6, 1, 8 }}
    // {{ 9, -3, 5 },{ 2, -2, 3 },{ 13, 6, 6 },{ -4, 5, 7 }}
    // =
    // {{188, 24, 88}, {-55, -36, 38}, {-43, 46, 60}}
    const expected_mat_out = [3][3]i32{
        .{ 188, 24, 88 },
        .{ -55, -36, 38 },
        .{ -43, 46, 60 },
    };
    const expected_out_flat: *const [9]i32 = @ptrCast(&expected_mat_out);
    const expected_out_slice: []const i32 = expected_out_flat[0..9];
    const real_out: [3][3]i32 = Advanced.multiply_matrices(DEF_A, mat_a, DEF_B, mat_b, OUT_T, OUT_ORDER, OUT_PADDING);
    const real_out_flat: *const [9]i32 = @ptrCast(&real_out);
    const real_out_slice: []const i32 = real_out_flat[0..9];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

test "Matrix -> add_matrices" {
    const DEF_A = MatrixDef.def(i32, 3, 4, .ROW_MAJOR, 0);
    const DEF_B = MatrixDef.def(i32, 3, 4, .ROW_MAJOR, 0);
    const OUT_T = i32;
    const OUT_ORDER = RowColOrder.ROW_MAJOR;
    const OUT_PADDING = 0;
    const MAT_A = DEF_A.Matrix();
    const MAT_B = DEF_B.Matrix();
    const mat_a = MAT_A{
        .{ 7, 2, 9, -1 },
        .{ 3, 8, -6, 5 },
        .{ -4, 6, 1, 8 },
    };
    const mat_b = MAT_B{
        .{ 9, -3, 5, -4 },
        .{ 2, -2, 3, 5 },
        .{ 13, 6, 6, 7 },
    };
    // For calculating via online calculators:
    // {{ 7, 2, 9, -1 },{ 3, 8, -6, 5 },{ -4, 6, 1, 8 }}
    // {{ 9, -3, 5, -4 },{ 2, -2, 3, 5 },{ 13, 6, 6, 7 }}
    // =
    // {{16, -1, 14, -5}, {5, 6, -3, 10}, {9, 12, 7, 15}}
    const expected_mat_out = [3][4]i32{
        .{ 16, -1, 14, -5 },
        .{ 5, 6, -3, 10 },
        .{ 9, 12, 7, 15 },
    };
    const expected_out_flat: *const [12]i32 = @ptrCast(&expected_mat_out);
    const expected_out_slice: []const i32 = expected_out_flat[0..12];
    const real_out: [3][4]i32 = Advanced.add_matrices(DEF_A, mat_a, DEF_B, mat_b, OUT_T, OUT_ORDER, OUT_PADDING);
    const real_out_flat: *const [12]i32 = @ptrCast(&real_out);
    const real_out_slice: []const i32 = real_out_flat[0..12];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

test "Matrix -> transpose_matrix" {
    const DEF_A = MatrixDef.def(u8, 3, 4, .ROW_MAJOR, 0);
    const MAT_A = DEF_A.Matrix();
    const mat_a = MAT_A{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
    };
    const expected_mat_out = [4][3]u8{
        .{ 1, 5, 9 },
        .{ 2, 6, 10 },
        .{ 3, 7, 11 },
        .{ 4, 8, 12 },
    };
    const expected_out_flat: *const [12]u8 = @ptrCast(&expected_mat_out);
    const expected_out_slice: []const u8 = expected_out_flat[0..12];
    const real_out: DEF_A.Transposed().Matrix() = Advanced.transpose_matrix(DEF_A, mat_a);
    const real_out_flat: *const [12]u8 = @ptrCast(&real_out);
    const real_out_slice: []const u8 = real_out_flat[0..12];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

test "Matrix -> inverse_of_matrix" {
    const Mat3 = Matrix.Mat3x3(f32);
    const mat = Mat3{ .mat = .{
        .{ 1, 2, 3 },
        .{ 0, 1, 4 },
        .{ 5, 6, 0 },
    } };
    const inverse_mat = Advanced.inverse_of_matrix(Mat3.DEF, mat.mat, f32);
    const product = Advanced.multiply_matrices(Mat3.DEF, mat.mat, Mat3.DEF, inverse_mat, f32, .ROW_MAJOR, 0);
    for (0..3) |y| {
        for (0..3) |x| {
            const expected: f32 = if (x == y) 1 else 0;
            try testing.expectApproxEqAbs(expected, product[y][x], 1e-5);
        }
    }
}

test "Matrix -> divide_matrices multiplies by the inverse" {
    const DEF = MatrixDef.def(f32, 2, 2, .ROW_MAJOR, 0);
    const mat_a: DEF.Matrix() = .{
        .{ 4, 2 },
        .{ 2, 4 },
    };
    const mat_b: DEF.Matrix() = .{
        .{ 2, 0 },
        .{ 0, 2 },
    };
    const out = Advanced.divide_matrices(DEF, mat_a, DEF, mat_b, f32, .ROW_MAJOR, 0);
    try testing.expectApproxEqAbs(@as(f32, 2), out[0][0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 1), out[0][1], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 1), out[1][0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 2), out[1][1], 1e-6);
}

test "Matrix -> multiply_matrices with column-major and padding" {
    const DEF_A = MatrixDef.def(f32, 2, 2, .ROW_MAJOR, 0);
    const DEF_B = MatrixDef.def(f32, 2, 2, .COLUMN_MAJOR, 1);
    const OUT_DEF = MatrixDef.def(f32, 2, 2, .COLUMN_MAJOR, 1);

    const mat_a: DEF_A.Matrix() = .{
        .{ 1, 2 },
        .{ 3, 4 },
    };
    var mat_b: DEF_B.Matrix() = undefined;
    DEF_B.set_cell(&mat_b, 0, 0, 5);
    DEF_B.set_cell(&mat_b, 0, 1, 6);
    DEF_B.set_cell(&mat_b, 1, 0, 7);
    DEF_B.set_cell(&mat_b, 1, 1, 8);

    const out = Advanced.multiply_matrices(DEF_A, mat_a, DEF_B, mat_b, f32, .COLUMN_MAJOR, 1);

    const expected: [2][2]f32 = .{
        .{ 19, 22 },
        .{ 43, 50 },
    };
    for (0..2) |y| {
        for (0..2) |x| {
            try testing.expectApproxEqAbs(expected[y][x], OUT_DEF.get_cell(&out, y, x), 1e-6);
        }
    }
}

test "Matrix -> determinant_of_matrix" {
    const Test = Root.Testing;
    const DEF_2x2 = MatrixDef.def(f32, 2, 2, .ROW_MAJOR, 0);
    const MAT_2x2 = DEF_2x2.Matrix();
    const DEF_3x3 = MatrixDef.def(f32, 3, 3, .ROW_MAJOR, 0);
    const MAT_3x3 = DEF_3x3.Matrix();
    const DEF_4x4 = MatrixDef.def(f32, 4, 4, .ROW_MAJOR, 0);
    const MAT_4x4 = DEF_4x4.Matrix();
    const DEF_5x5 = MatrixDef.def(f32, 5, 5, .ROW_MAJOR, 0);
    const MAT_5x5 = DEF_5x5.Matrix();
    // {{ 3.1415, 1.965 },{ 4.44, 123.456 }}
    // determinant should be 379.112424
    const mat_2x2 = MAT_2x2{
        .{ 3.1415, 1.965 },
        .{ 4.44, 123.456 },
    };
    const expect_2x2_a: f32 = 379.112424;
    var result = Advanced.determinant_of_matrix(DEF_2x2, mat_2x2, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_2x2_a, "expect_2x2_a", "wrong result", .{});
    // {{ 2, 0, 1 },{ 4, 0, 1 },{ 2, -1, 2 }}
    // determinant should be -2
    var mat_3x3 = MAT_3x3{
        .{ 2, 0, 1 },
        .{ 4, 0, 1 },
        .{ 2, -1, 2 },
    };
    const expect_3x3_a: f32 = -2;
    result = Advanced.determinant_of_matrix(DEF_3x3, mat_3x3, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_3x3_a, "expect_3x3_a", "wrong result", .{});
    // {{ 7, -4, 2 },{ 3, 1, -5 },{ 2, 2, -5 }}
    // determinant should be 23
    mat_3x3 = MAT_3x3{
        .{ 7, -4, 2 },
        .{ 3, 1, -5 },
        .{ 2, 2, -5 },
    };
    const expect_3x3_b: f32 = 23;
    result = Advanced.determinant_of_matrix(DEF_3x3, mat_3x3, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_3x3_b, "expect_3x3_b", "wrong result", .{});
    // {{ 1, 3, 5, 9 },{ 1, 2.8, 1, 7 },{ 4, 3, 9, 7 },{ 5, 2, 0, 9 }}
    // determinant should be -310.2
    var mat_4x4 = MAT_4x4{
        .{ 1, 3, 5, 9 },
        .{ 1, 2.8, 1, 7 },
        .{ 4, 3, 9, 7 },
        .{ 5, 2, 0, 9 },
    };
    const expect_4x4_a = -310.2;
    result = Advanced.determinant_of_matrix(DEF_4x4, mat_4x4, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_4x4_a, "expect_4x4_a", "wrong result", .{});
    // {{ 7.57, 7.00, 6.49, 7.11 },{ 3.60, 2.03, 6.85, 0.27 },{ 7.63, 7.21, 0.69, 2.98 },{ 5.19, 1.63, 4.37, 5.93 }}
    // determinant should be 874.39659797
    mat_4x4 = MAT_4x4{
        .{ 7.57, 7.00, 6.49, 7.11 },
        .{ 3.60, 2.03, 6.85, 0.27 },
        .{ 7.63, 7.21, 0.69, 2.98 },
        .{ 5.19, 1.63, 4.37, 5.93 },
    };
    const expect_4x4_b = 874.39659797;
    result = Advanced.determinant_of_matrix(DEF_4x4, mat_4x4, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_4x4_b, "expect_4x4_b", "wrong result", .{});
    // {{ 7.57, 0, 6.49, 7.11 },{ 3.60, 0, 6.85, 0.27 },{ 7.63, 0, 0.69, 2.98 },{ 5.19, 0, 4.37, 5.93 }}
    // determinant should be 0
    mat_4x4 = MAT_4x4{
        .{ 7.57, 0, 6.49, 7.11 },
        .{ 3.60, 0, 6.85, 0.27 },
        .{ 7.63, 0, 0.69, 2.98 },
        .{ 5.19, 0, 4.37, 5.93 },
    };
    const expect_4x4_c = 0;
    result = Advanced.determinant_of_matrix(DEF_4x4, mat_4x4, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_4x4_c, "expect_4x4_c", "wrong result", .{});
    // {{ 7.57, 7.00, 6.49, -7.11, 9.12 },{ 3.60, -2.03, 6.85, 0.27, 0.45 },{ 7.63, 7.21, 0.69, 2.98, 3.89 },{ -5.19, 1.63, 4.37, 5.93, 1.13 },{ 8.43, 7.23, 4.41, -5.82, 3.67 }}
    // determinant should be -29986.9677224892
    var mat_5x5 = MAT_5x5{
        .{ 7.57, 7.00, 6.49, -7.11, 9.12 },
        .{ 3.60, -2.03, 6.85, 0.27, 0.45 },
        .{ 7.63, 7.21, 0.69, 2.98, 3.89 },
        .{ -5.19, 1.63, 4.37, 5.93, 1.13 },
        .{ 8.43, 7.23, 4.41, -5.82, 3.67 },
    };
    const expect_5x5_a = -29986.9677224892;
    result = Advanced.determinant_of_matrix(DEF_5x5, mat_5x5, f32);
    try Test.expect_approx_equal(result, "result", 0.001, "0.001", expect_5x5_a, "expect_5x5_a", "wrong result", .{});
    // {{ 7.57, 7.00, 6.49, -7.11, 9.12 },{ 0, 0, 0, 0, 0 },{ 7.63, 7.21, 0.69, 2.98, 3.89 },{ -5.19, 1.63, 4.37, 5.93, 1.13 },{ 8.43, 7.23, 4.41, -5.82, 3.67 }}
    // determinant should be 0
    mat_5x5 = MAT_5x5{
        .{ 7.57, 7.00, 6.49, -7.11, 9.12 },
        .{ 0, 0, 0, 0, 0 },
        .{ 7.63, 7.21, 0.69, 2.98, 3.89 },
        .{ -5.19, 1.63, 4.37, 5.93, 1.13 },
        .{ 8.43, 7.23, 4.41, -5.82, 3.67 },
    };
    const expect_5x5_b = 0;
    result = Advanced.determinant_of_matrix(DEF_5x5, mat_5x5, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_5x5_b, "expect_5x5_b", "wrong result", .{});
}

test "Matrix -> row_echelon_form_of_matrix" {
    const DEF_A = MatrixDef.def(f32, 4, 4, .ROW_MAJOR, 0);
    const MAT_A = DEF_A.Matrix();
    // {{ 1, 3, 5, 9 },{ 1, 2.8, 1, 7 },{ 4, 3, 9, 7 },{ 5, 2, 0, 9 }}
    // determinant should be -310.2
    var mat_a = MAT_A{
        .{ 1, 3, 5, 9 },
        .{ 1, 2.8, 1, 7 },
        .{ 4, 3, 9, 7 },
        .{ 5, 2, 0, 9 },
    };
    // const expected_out_flat: *const [16]f32 = @ptrCast(&expected_mat_out);
    // const expected_out_slice: []const f32 = expected_out_flat[0..16];
    var result = Advanced.row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .STOP_IF_NOT_FULL_RANK, f32, f32, .CACHE_PIVOT_X_INDEXES);
    // const real_out_flat: *const [16]f32 = @ptrCast(&result.mat);
    // const real_out_slice: []const f32 = real_out_flat[0..16];
    // try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
    try Root.Testing.expect_approx_equal(result.determinant_factor, "result.determinant_factor", 0.0001, "0.0001", -310.2, "-310.2", "wrong result", .{});
    try Root.Testing.expect_equal(result.rank, "result.rank", 4, "4", "wrong result", .{});
    // {{ 7.57, 7.00, 6.49, 7.11 },{ 3.60, 2.03, 6.85, 0.27 },{ 7.63, 7.21, 0.69, 2.98 },{ 5.19, 1.63, 4.37, 5.93 }}
    mat_a = MAT_A{
        .{ 7.57, 7.00, 6.49, 7.11 },
        .{ 3.60, 2.03, 6.85, 0.27 },
        .{ 7.63, 7.21, 0.69, 2.98 },
        .{ 5.19, 1.63, 4.37, 5.93 },
    };
    // determinant should be 874.39659797
    result = Advanced.row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .STOP_IF_NOT_FULL_RANK, f32, f32, .CACHE_PIVOT_X_INDEXES);
    try Root.Testing.expect_approx_equal(result.determinant_factor, "result.determinant_factor", 0.0001, "0.0001", 874.39659797, "874.39659797", "wrong result", .{});
    try Root.Testing.expect_equal(result.rank, "result.rank", 4, "4", "wrong result", .{});
    // {{ 7.57, 0, 6.49, 7.11 },{ 3.60, 0, 6.85, 0.27 },{ 7.63, 0, 0.69, 2.98 },{ 5.19, 0, 4.37, 5.93 }}
    mat_a = MAT_A{
        .{ 7.57, 0, 6.49, 7.11 },
        .{ 3.60, 0, 6.85, 0.27 },
        .{ 7.63, 0, 0.69, 2.98 },
        .{ 5.19, 0, 4.37, 5.93 },
    };
    // determinant should be 0
    result = Advanced.row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .DO_NOT_STOP_IF_NOT_FULL_RANK, f32, f32, .CACHE_PIVOT_X_INDEXES);
    try Root.Testing.expect_approx_equal(result.determinant_factor, "result.determinant_factor", 0.0001, "0.0001", 0, "0", "wrong result", .{});
    try Root.Testing.expect_equal(result.rank, "result.rank", 3, "3", "wrong result", .{});
}

test "Matrix -> change_matrix_major_order accepts a matrix reference" {
    const DEF = MatrixDef.def(u8, 2, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
    };

    // same order, pointer input (must clone rather than return the pointer)
    const same = Advanced.change_matrix_major_order(DEF, &mat, .ROW_MAJOR);
    try testing.expectEqualSlices(u8, &mat[0], &same[0]);
    try testing.expectEqualSlices(u8, &mat[1], &same[1]);

    // different order, pointer input
    const transposed_order = Advanced.change_matrix_major_order(DEF, &mat, .COLUMN_MAJOR);
    for (0..2) |y| {
        for (0..3) |x| {
            try testing.expectEqual(DEF.get_cell(mat, y, x), DEF.with_new_order(.COLUMN_MAJOR).get_cell(transposed_order, y, x));
        }
    }
}

test "Matrix -> negate_matrix_elements" {
    const DEF = MatrixDef.def(i32, 2, 2, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 1, -2 },
        .{ 3, -4 },
    };
    const out = Advanced.negate_matrix_elements(DEF, mat, i32);
    const expected: [2][2]i32 = .{
        .{ -1, 2 },
        .{ -3, 4 },
    };
    const out_flat: [4]i32 = @bitCast(out);
    const expected_flat: [4]i32 = @bitCast(expected);
    try testing.expectEqualSlices(i32, &out_flat, &expected_flat);
}

test "Matrix -> sub_matrix_excluding_row_and_column" {
    const DEF = MatrixDef.def(i32, 3, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
        .{ 7, 8, 9 },
    };
    const minor = Advanced.sub_matrix_excluding_row_and_column(DEF, mat, 1, 1);
    const expected: [2][2]i32 = .{
        .{ 1, 3 },
        .{ 7, 9 },
    };
    try testing.expectEqualSlices(i32, &expected[0], &minor[0]);
    try testing.expectEqualSlices(i32, &expected[1], &minor[1]);
}

test "Matrix -> determinant_of_matrix for integer matrices" {
    const DEF = MatrixDef.def(i32, 3, 3, .ROW_MAJOR, 0);
    const mat: DEF.Matrix() = .{
        .{ 7, -4, 2 },
        .{ 3, 1, -5 },
        .{ 2, 2, -5 },
    };
    try testing.expectEqual(@as(i64, 23), Advanced.determinant_of_matrix(DEF, mat, i64));
}
