//! This module defines a plethora of methods for operating on
//! matrices of any type, size, row-column major order,
//! and with possible padding on the end of each row/column (depending on major order)
//!
//! It makes heavy use of comptime, inline, and assertions to facilitate the fastest possible
//! operations, but conversely may cause bloat in the final binary size if
//! many, many different matrix types are all used in the same source program.
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
const build = @import("builtin");
const Type = std.builtin.Type;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Utils = Root.Utils;
const MathX = Root.Math;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;
const RowColOrder = Root.CommonTypes.RowColumnOrder;

/// A comptime definition for any matrix
pub const MatrixDef = struct {
    /// The element type of each matrix cell
    T: type,
    /// The number of logical rows
    ROWS: comptime_int,
    /// The number of logical columns
    COLS: comptime_int,
    /// The in-memory order of the data
    ORDER: RowColOrder = .ROW_MAJOR,
    /// The number of padding cells at the end of each major line (for ROW_MAJOR padding at end of each row, for COLUMN_MAJOR padding at the end of each column)
    ///
    /// These values are not used except when a math operation can be performed by flattening the matrix into a `@Vector()` for SIMD,
    /// but operations done on them do not affect the logical state of the matrix
    ///
    /// One reason to use padding is for direct compatibility with GPU shader layouts
    MAJOR_PAD: comptime_int = 0,

    pub inline fn zero_val(comptime DEF: MatrixDef) DEF.T {
        return @as(DEF.T, 0);
    }
    pub inline fn one_val(comptime DEF: MatrixDef) DEF.T {
        return @as(DEF.T, 1);
    }
    pub inline fn neg_one_val(comptime DEF: MatrixDef) DEF.T {
        return @as(DEF.T, -1);
    }
    pub inline fn one_and_neg_one(comptime DEF: MatrixDef) [2]DEF.T {
        return [2]DEF.T{ @as(DEF.T, 1), @as(DEF.T, -1) };
    }

    pub inline fn larger_of_cols_or_rows(comptime DEF: MatrixDef) comptime_int {
        return @max(DEF.COLS, DEF.ROWS);
    }

    pub inline fn col_indices(comptime DEF: MatrixDef) [DEF.COLS]usize {
        comptime var out: [DEF.COLS]usize = undefined;
        inline for (0..DEF.COLS) |i| {
            out[i] = i;
        }
    }
    pub inline fn row_indices(comptime DEF: MatrixDef) [DEF.ROWS]usize {
        comptime var out: [DEF.ROWS]usize = undefined;
        inline for (0..DEF.ROWS) |i| {
            out[i] = i;
        }
    }

    pub inline fn def(comptime T: type, comptime ROWS: comptime_int, comptime COLS: comptime_int, comptime ORDER: RowColOrder, comptime MAJOR_PAD: comptime_int) MatrixDef {
        return MatrixDef{
            .T = T,
            .ROWS = ROWS,
            .COLS = COLS,
            .ORDER = ORDER,
            .MAJOR_PAD = MAJOR_PAD,
        };
    }

    pub inline fn clone(comptime DEF: MatrixDef, mat: anytype) DEF.Matrix() {
        return switch (comptime DEF.matrix_anytype_kind(@TypeOf(mat))) {
            .VALUE => mat,
            .POINTER, .CONST_POINTER => mat.*,
        };
    }
    pub inline fn clone_to_new_type(comptime DEF: MatrixDef, mat: anytype, comptime NEW_TYPE: type) DEF.with_new_type(NEW_TYPE).Matrix() {
        if (DEF.T == NEW_TYPE) return DEF.clone(mat);
        const OUT = DEF.with_new_type(NEW_TYPE);
        var out: OUT.Matrix() = undefined;
        for (0..OUT.major_len()) |major| {
            for (0..OUT.minor_len()) |minor| {
                OUT.set_cell_mm(&out, major, minor, num_cast(DEF.get_cell_mm(mat, major, minor), NEW_TYPE));
            }
        }
    }

    pub inline fn matrix_ref_from_slice(comptime DEF: MatrixDef, slice: []DEF.T) DEF.MatrixRef() {
        assert_with_reason(slice.len == DEF.total_cells(), @src(), "in order to cast a slice to a matrix pointer, the slice length must equal the matrix `total_cells()`, got slice len {d} != {d} matrix total cells", .{ slice.len, DEF.total_cells() });
        return @ptrCast(slice.ptr);
    }
    pub inline fn matrix_ref_const_from_slice(comptime DEF: MatrixDef, slice: []const DEF.T) DEF.MatrixRefConst() {
        assert_with_reason(slice.len == DEF.total_cells(), @src(), "in order to cast a slice to a matrix pointer, the slice length must equal the matrix `total_cells()`, got slice len {d} != {d} matrix total cells", .{ slice.len, DEF.total_cells() });
        return @ptrCast(slice.ptr);
    }
    pub inline fn major_len(comptime DEF: MatrixDef) comptime_int {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => DEF.ROWS,
            .COLUMN_MAJOR => DEF.COLS,
        };
    }
    pub inline fn minor_len(comptime DEF: MatrixDef) comptime_int {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => DEF.COLS,
            .COLUMN_MAJOR => DEF.ROWS,
        };
    }
    pub inline fn major_minor_to_y_x(comptime DEF: MatrixDef, major: usize, minor: usize) struct { usize, usize } {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => .{ major, minor },
            .COLUMN_MAJOR => .{ minor, major },
        };
    }
    pub inline fn y_x_to_major_minor(comptime DEF: MatrixDef, y: usize, x: usize) struct { usize, usize } {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => .{ y, x },
            .COLUMN_MAJOR => .{ x, y },
        };
    }

    pub inline fn Transposed(comptime DEF: MatrixDef) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = DEF.COLS,
            .COLS = DEF.ROWS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = 0,
        };
    }

    pub inline fn Multiplied(comptime DEF: MatrixDef, comptime OTHER_DEF: MatrixDef, comptime NEW_TYPE: type, comptime NEW_ORDER: RowColOrder, comptime NEW_PADDING: comptime_int) MatrixDef {
        return MatrixDef{
            .T = NEW_TYPE,
            .ROWS = DEF.ROWS,
            .COLS = OTHER_DEF.COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = NEW_PADDING,
        };
    }

    pub inline fn TransposedWithPad(comptime DEF: MatrixDef, comptime NEW_MAJOR_PAD: comptime_int) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = DEF.COLS,
            .COLS = DEF.ROWS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = NEW_MAJOR_PAD,
        };
    }

    pub fn Matrix(comptime DEF: MatrixDef) type {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => [DEF.ROWS][DEF.COLS + DEF.MAJOR_PAD]DEF.T,
            .COLUMN_MAJOR => [DEF.COLS][DEF.ROWS + DEF.MAJOR_PAD]DEF.T,
        };
    }
    pub fn MatrixRef(comptime DEF: MatrixDef) type {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => *[DEF.ROWS][DEF.COLS + DEF.MAJOR_PAD]DEF.T,
            .COLUMN_MAJOR => *[DEF.COLS][DEF.ROWS + DEF.MAJOR_PAD]DEF.T,
        };
    }
    pub fn MatrixRefConst(comptime DEF: MatrixDef) type {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => *const [DEF.ROWS][DEF.COLS + DEF.MAJOR_PAD]DEF.T,
            .COLUMN_MAJOR => *const [DEF.COLS][DEF.ROWS + DEF.MAJOR_PAD]DEF.T,
        };
    }
    pub fn Major(comptime DEF: MatrixDef) type {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => [DEF.COLS]DEF.T,
            .COLUMN_MAJOR => [DEF.ROWS]DEF.T,
        };
    }
    pub fn MajorSlice(comptime DEF: MatrixDef) type {
        return []DEF.T;
    }
    pub fn MajorSliceConst(comptime DEF: MatrixDef) type {
        return []const DEF.T;
    }
    pub fn MajorRef(comptime DEF: MatrixDef) type {
        return *DEF.Major();
    }
    pub fn MajorRefConst(comptime DEF: MatrixDef) type {
        return *const DEF.Major();
    }
    pub fn FlatVec(comptime DEF: MatrixDef) type {
        return @Vector(DEF.total_cells(), DEF.T);
    }
    pub inline fn get_flat_vec(comptime DEF: MatrixDef, mat: anytype) DEF.FlatVec() {
        assert_is_matrix(DEF, @src(), mat);
        return @as(DEF.FlatVec(), @bitCast(switch (comptime DEF.matrix_anytype_kind(@TypeOf(mat))) {
            .VALUE => mat,
            .POINTER, .CONST_POINTER => mat.*,
        }));
    }
    pub inline fn total_cells(comptime DEF: MatrixDef) comptime_int {
        return switch (DEF.ORDER) {
            .ROW_MAJOR => (DEF.ROWS) * (DEF.COLS + DEF.MAJOR_PAD),
            .COLUMN_MAJOR => (DEF.COLS) * (DEF.ROWS + DEF.MAJOR_PAD),
        };
    }
    pub inline fn total_size(comptime DEF: MatrixDef) comptime_int {
        return DEF.total_cells() * @sizeOf(DEF.T);
    }
    pub inline fn can_multiply(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef) bool {
        return DEF_A.COLS == DEF_B.ROWS;
    }
    pub inline fn can_add(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef) bool {
        return DEF_A.ROWS == DEF_B.ROWS and DEF_A.COLS == DEF_B.COLS;
    }
    pub inline fn same_row_column_order(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef) bool {
        return DEF_A.ORDER == DEF_B.ORDER;
    }
    pub inline fn same_flat_memory_layout(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef) bool {
        return DEF_A.ROWS == DEF_B.ROWS and DEF_A.COLS == DEF_B.COLS and DEF_A.ORDER == DEF_B.ORDER and DEF_A.MAJOR_PAD == DEF_B.MAJOR_PAD;
    }
    pub inline fn can_get_matrix_one_size_smaller(comptime DEF: MatrixDef) bool {
        return DEF.COLS > 1 and DEF.ROWS > 1;
    }
    pub inline fn can_get_determinant(comptime DEF: MatrixDef) bool {
        return DEF.is_square();
    }
    pub inline fn can_possibly_invert(comptime DEF: MatrixDef) bool {
        return DEF.is_square();
    }
    pub inline fn is_square(comptime DEF: MatrixDef) bool {
        return DEF.ROWS == DEF.COLS;
    }
    pub inline fn is_same_size(comptime DEF: MatrixDef, comptime OTHER_DEF: MatrixDef) bool {
        return DEF.ROWS == OTHER_DEF.ROWS and DEF.COLS == OTHER_DEF.COLS;
    }

    pub inline fn with_new_padding(comptime DEF: MatrixDef, comptime NEW_PAD: comptime_int) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = NEW_PAD,
        };
    }
    pub inline fn with_new_order(comptime DEF: MatrixDef, comptime NEW_ORDER: RowColOrder) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_type(comptime DEF: MatrixDef, comptime NEW_T: type) MatrixDef {
        return MatrixDef{
            .T = NEW_T,
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_size(comptime DEF: MatrixDef, comptime NEW_ROWS: comptime_int, comptime NEW_COLS: comptime_int) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = NEW_ROWS,
            .COLS = NEW_COLS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_type_and_size(comptime DEF: MatrixDef, comptime NEW_T: type, comptime NEW_ROWS: comptime_int, comptime NEW_COLS: comptime_int) MatrixDef {
        return MatrixDef{
            .T = NEW_T,
            .ROWS = NEW_ROWS,
            .COLS = NEW_COLS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_type_and_order(comptime DEF: MatrixDef, comptime NEW_T: type, comptime NEW_ORDER: RowColOrder) MatrixDef {
        return MatrixDef{
            .T = NEW_T,
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_size_and_order(comptime DEF: MatrixDef, comptime NEW_ROWS: comptime_int, comptime NEW_COLS: comptime_int, comptime NEW_ORDER: RowColOrder) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = NEW_ROWS,
            .COLS = NEW_COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_type_size_order(comptime DEF: MatrixDef, comptime NEW_T: type, comptime NEW_ROWS: comptime_int, comptime NEW_COLS: comptime_int, comptime NEW_ORDER: RowColOrder) MatrixDef {
        return MatrixDef{
            .T = NEW_T,
            .ROWS = NEW_ROWS,
            .COLS = NEW_COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = DEF.MAJOR_PAD,
        };
    }
    pub inline fn with_new_type_order_padding(comptime DEF: MatrixDef, comptime NEW_T: type, comptime NEW_ORDER: RowColOrder, comptime NEW_MAJOR_PAD: comptime_int) MatrixDef {
        return MatrixDef{
            .T = NEW_T,
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = NEW_ORDER,
            .MAJOR_PAD = NEW_MAJOR_PAD,
        };
    }
    pub inline fn with_size_minus_one(comptime DEF: MatrixDef) MatrixDef {
        return MatrixDef{
            .T = DEF.T,
            .ROWS = DEF.ROWS - 1,
            .COLS = DEF.COLS - 1,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = 0,
        };
    }
    pub inline fn matrix_of_matrices_one_size_smaller(comptime DEF: MatrixDef) MatrixDef {
        return MatrixDef{
            .T = DEF.with_size_minus_one().Matrix(),
            .ROWS = DEF.ROWS,
            .COLS = DEF.COLS,
            .ORDER = DEF.ORDER,
            .MAJOR_PAD = 0,
        };
    }
    pub fn matrix_anytype_kind(comptime DEF: MatrixDef, comptime MAT: type) Root.CommonTypes.ParamRefType {
        return switch (MAT) {
            DEF.Matrix() => Root.CommonTypes.ParamRefType.VALUE,
            DEF.MatrixRef() => Root.CommonTypes.ParamRefType.POINTER,
            DEF.MatrixRefConst() => Root.CommonTypes.ParamRefType.CONST_POINTER,
            else => assert_unreachable(@src(), "invalid matrix payload type `{s}`", .{@typeName(MAT)}),
        };
    }
    pub fn assert_is_matrix(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, mat: anytype) void {
        const MAT = @TypeOf(mat);
        switch (MAT) {
            DEF.Matrix(), DEF.MatrixRef(), DEF.MatrixRefConst() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable matrix ([{d}][{d}]T or *[{d}][{d}]T or *const [{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.ROWS, DEF.COLS, DEF.ROWS, DEF.COLS, DEF.ROWS, DEF.COLS, @typeName(MAT) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable matrix ([{d}][{d}]T or *[{d}][{d}]T or *const [{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.COLS, DEF.ROWS, DEF.COLS, DEF.ROWS, DEF.COLS, DEF.ROWS, @typeName(MAT) }),
            },
        }
    }
    pub fn assert_is_matrix_ref(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, mat: anytype) void {
        const MAT = @TypeOf(mat);
        switch (MAT) {
            DEF.MatrixRef(), DEF.MatrixRefConst() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable matrix reference ( *[{d}][{d}]T or *const [{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.ROWS, DEF.COLS, DEF.ROWS, DEF.COLS, @typeName(MAT) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable matrix reference ( *[{d}][{d}]T or *const [{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.COLS, DEF.ROWS, DEF.COLS, DEF.ROWS, @typeName(MAT) }),
            },
        }
    }
    pub fn assert_is_matrix_ref_mutable(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, mat: anytype) void {
        const MAT = @TypeOf(mat);
        switch (MAT) {
            DEF.MatrixRef() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable matrix mutable reference ( *[{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.ROWS, DEF.COLS, @typeName(MAT) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable matrix mutable reference ( *[{d}][{d}]T) got an incompatible type `{s}`", .{ DEF.COLS, DEF.ROWS, @typeName(MAT) }),
            },
        }
    }
    pub fn assert_is_major(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, major: anytype) void {
        const MAJOR = @TypeOf(major);
        switch (MAJOR) {
            DEF.Major(), *DEF.Major(), *const DEF.Major(), DEF.MajorSlice(), DEF.MajorSliceConst() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable major ([{d}]T or [{d}]T or *const [{d}]T or []T or []const T) got an incompatible type `{s}`", .{ DEF.COLS, DEF.COLS, DEF.COLS, @typeName(MAJOR) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable major ([{d}]T or [{d}]T or *const [{d}]T or []T or []const T) got an incompatible type `{s}`", .{ DEF.ROWS, DEF.ROWS, DEF.ROWS, @typeName(MAJOR) }),
            },
        }
    }
    pub fn assert_is_major_ref(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, major: anytype) void {
        const MAJOR = @TypeOf(major);
        switch (MAJOR) {
            *DEF.Major(), *const DEF.Major(), DEF.MajorSlice(), DEF.MajorSliceConst() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable major reference ( *[{d}]T or *const [{d}]T or []T or []const T) got an incompatible type `{s}`", .{ DEF.COLS, DEF.COLS, @typeName(MAJOR) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable major reference (*[{d}]T or *const [{d}]T or []T or []const T) got an incompatible type `{s}`", .{ DEF.ROWS, DEF.ROWS, @typeName(MAJOR) }),
            },
        }
    }
    pub fn assert_is_major_ref_mutable(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation, major: anytype) void {
        const MAJOR = @TypeOf(major);
        switch (MAJOR) {
            *DEF.Major(), DEF.MajorSlice() => {},
            else => switch (DEF.ORDER) {
                .ROW_MAJOR => assert_unreachable(src, "input expecting an indexable major mutable mutable reference ( *[{d}]T or []T) got an incompatible type `{s}`", .{ DEF.COLS, @typeName(MAJOR) }),
                .COLUMN_MAJOR => assert_unreachable(src, "input expecting an indexable major mutable mutable reference (*[{d}]T or  []T) got an incompatible type `{s}`", .{ DEF.ROWS, @typeName(MAJOR) }),
            },
        }
    }
    pub fn assert_can_multiply_or_divide(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(DEF_A.can_multiply(DEF_B), src, "matrix algebraic mutiplication/division is only possible when A_COLS == B_ROWS, got {d} != {d}", .{ DEF_A.COLS, DEF_B.ROWS });
    }
    pub fn assert_can_add_sub_or_flat_mult_div(comptime DEF_A: MatrixDef, comptime DEF_B: MatrixDef, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(DEF_A.can_add(DEF_B), src, "matrix addition/subtraction/'flat multiply'/'flat divide' is only possible when A_COLS {d} == {d} B_COLS and A_ROWS {d} == {d} B_ROWS", .{ DEF_A.COLS, DEF_B.COLS, DEF_A.ROWS, DEF_B.ROWS });
    }
    pub fn assert_can_get_matrix_one_size_smaller(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(DEF.can_get_matrix_one_size_smaller(), src, "matrix must be at least 2x2 in size in order to get a matrix one size smaller, got {d}x{d}", .{ DEF.ROWS, DEF.COLS });
    }
    pub fn assert_can_get_determinant(comptime DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(DEF.can_get_matrix_one_size_smaller(), src, "matrix must be at least 2x2 in size in order to get a matrix one size smaller, got {d}x{d}", .{ DEF.ROWS, DEF.COLS });
    }
    pub fn assert_same_size(comptime DEF: MatrixDef, comptime OTHER_DEF: MatrixDef, comptime src: ?std.builtin.SourceLocation) void {
        assert_with_reason(DEF.is_same_size(OTHER_DEF), src, "matrices must be same size, got {d}x{d} != {d}x{d}", .{ DEF.ROWS, DEF.COLS, OTHER_DEF.ROWS, OTHER_DEF.COLS });
    }
    pub fn assert_no_vals_zero_flat(comptime DEF: MatrixDef, mat_flat: DEF.FlatVec(), comptime src: ?std.builtin.SourceLocation, reason: []const u8) void {
        const zero_vec: DEF.FlatVec() = @splat(0);
        assert_with_reason(!@reduce(.Or, mat_flat == zero_vec), src, reason, .{});
    }

    pub inline fn set_cell(comptime DEF: MatrixDef, mat: *DEF.Matrix(), y: usize, x: usize, val: DEF.T) void {
        switch (DEF.ORDER) {
            .ROW_MAJOR => {
                mat[y][x] = val;
            },
            .COLUMN_MAJOR => {
                mat[x][y] = val;
            },
        }
    }
    pub inline fn set_cell_mm(comptime DEF: MatrixDef, mat: *DEF.Matrix(), major: usize, minor: usize, val: DEF.T) void {
        mat[major][minor] = val;
    }
    pub inline fn get_cell(comptime DEF: MatrixDef, mat: anytype, y: usize, x: usize) DEF.T {
        DEF.assert_is_matrix(@src(), mat);
        switch (DEF.ORDER) {
            .ROW_MAJOR => {
                return mat[y][x];
            },
            .COLUMN_MAJOR => {
                return mat[x][y];
            },
        }
    }
    pub inline fn get_cell_mm(comptime DEF: MatrixDef, mat: anytype, major: usize, minor: usize) DEF.T {
        DEF.assert_is_matrix(@src(), mat);
        return mat[major][minor];
    }
    pub inline fn get_cell_ptr_const(comptime DEF: MatrixDef, mat: anytype, y: usize, x: usize) *const DEF.T {
        DEF.assert_is_matrix_ref(@src(), mat);
        switch (DEF.ORDER) {
            .ROW_MAJOR => {
                return &mat[y][x];
            },
            .COLUMN_MAJOR => {
                return &mat[x][y];
            },
        }
    }
    pub inline fn get_cell_ptr_const_mm(comptime DEF: MatrixDef, mat: anytype, major: usize, minor: usize) *const DEF.T {
        DEF.assert_is_matrix_ref(@src(), mat);
        return &mat[major][minor];
    }
    pub inline fn get_cell_ptr(comptime DEF: MatrixDef, mat: *DEF.Matrix(), y: usize, x: usize) *DEF.T {
        switch (DEF.ORDER) {
            .ROW_MAJOR => {
                return &mat[y][x];
            },
            .COLUMN_MAJOR => {
                return &mat[x][y];
            },
        }
    }
    pub inline fn get_cell_ptr_mm(comptime DEF: MatrixDef, mat: *DEF.Matrix(), major: usize, minor: usize) *DEF.T {
        return &mat[major][minor];
    }

    pub inline fn swap_rows(comptime DEF: MatrixDef, mat: *DEF.Matrix(), row_a: usize, row_b: usize) void {
        if (DEF.ORDER == .ROW_MAJOR) {
            const tmp = mat[row_a];
            mat[row_a] = mat[row_b];
            mat[row_b] = tmp;
        } else {
            var tmp: DEF.T = undefined;
            for (0..DEF.COLS) |x| {
                tmp = DEF.get_cell(mat, row_a, x);
                DEF.set_cell(mat, row_a, x, DEF.get_cell(mat, row_b, x));
                DEF.set_cell(mat, row_b, x, tmp);
            }
        }
    }

    pub inline fn fill_flat_padding_with_val(comptime DEF: MatrixDef, flat_mat: *DEF.FlatVec(), val: DEF.T) void {
        if (DEF.MAJOR_PAD == 0) return;
        const ptr: [*]DEF.T = @ptrCast(flat_mat);
        const MAJOR, const STRIDE, var offset: usize = switch (DEF.ORDER) {
            .ROW_MAJOR => .{ DEF.ROWS, DEF.COLS + DEF.MAJOR_PAD, DEF.COLS },
            .COLUMN_MAJOR => .{ DEF.COLS, DEF.ROWS + DEF.MAJOR_PAD, DEF.ROWS },
        };
        for (0..MAJOR) |_| {
            for (0..DEF.MAJOR_PAD) |p| {
                ptr[offset + p] = val;
            }
            offset += STRIDE;
        }
    }

    pub fn RowEchelonResult(comptime _DEF: MatrixDef, comptime CELL_TYPE: type, comptime DETERMINANT_TYPE: type, comptime PIVOT_MODE: RowEchelonPivotCache) type {
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
            mat: DEF.Matrix(),
        };
    }

    pub fn RowOrColNonZeroes(comptime DEF: MatrixDef) type {
        return struct {
            kind: RowOrColKind = .ROW,
            idx: usize = 0,
            non_zero_count: usize = DEF.larger_of_cols_or_rows(),
            non_zero_indices: [DEF.larger_of_cols_or_rows()]usize = @splat(0),
        };
    }
};

pub const RowEchelonPivotCache = enum(u8) {
    DO_NOT_CACHE_PIVOTS,
    CACHE_PIVOT_X_INDEXES,
    CACHE_PIVOT_VALUES,
};

/// No-Op if the orders already match
pub fn change_matrix_major_order(
    comptime DEF: MatrixDef,
    mat: anytype,
    comptime OUT_ORDER: RowColOrder,
) DEF.with_new_order(OUT_ORDER).Matrix() {
    if (DEF.ORDER == OUT_ORDER) return mat;
    const OUT = DEF.with_new_order(OUT_ORDER);
    var out: OUT.Matrix() = undefined;
    for (0..OUT.major_len()) |major| {
        for (0..OUT.minor_len()) |minor| {
            const y, const x = OUT.major_minor_to_y_x(major, minor);
            OUT.set_cell(&out, y, x, DEF.get_cell(mat, y, x));
        }
    }
    return out;
}

test "change_matrix_major_order" {
    const DEF_IN = MatrixDef.def(u8, 3, 4, .ROW_MAJOR, 0);
    const DEF_OUT = MatrixDef.def(u8, 3, 4, .COLUMN_MAJOR, 0);
    const vec_in = [12]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
    const mat_in: DEF_IN.Matrix() = @bitCast(vec_in);
    const mat_out: DEF_OUT.Matrix() = change_matrix_major_order(DEF_IN, mat_in, .COLUMN_MAJOR);
    const vec_out: [12]u8 = @bitCast(mat_out);
    const expect_vec_out = [12]u8{ 1, 5, 9, 2, 6, 10, 3, 7, 11, 4, 8, 12 };
    const slice_out: []const u8 = vec_out[0..];
    const expect_slice_out: []const u8 = expect_vec_out[0..];
    try Root.Testing.expect_slices_equal(slice_out[0..], "slice_out", expect_slice_out[0..], "expect_slice_out", "resulting in-memory order not as expected", .{});
}

pub fn multiply_matrices(
    comptime DEF_A: MatrixDef,
    mat_a: anytype,
    comptime DEF_B: MatrixDef,
    mat_b: anytype,
    comptime T_OUT: type,
    comptime OUT_ORDER: RowColOrder,
    comptime OUT_PADDING: comptime_int,
) MatrixDef.Multiplied(DEF_A, DEF_B, T_OUT, OUT_ORDER, OUT_PADDING).Matrix() {
    DEF_A.assert_is_matrix(@src(), mat_a);
    DEF_B.assert_is_matrix(@src(), mat_b);
    DEF_A.assert_can_multiply_or_divide(DEF_B, @src());
    const UPGRADE = MathX.Upgraded2Numbers(DEF_A.T, DEF_B.T);
    const OUT = MatrixDef.Multiplied(DEF_A, DEF_B, T_OUT, OUT_ORDER, OUT_PADDING);
    var out: OUT.Matrix() = undefined;
    for (0..OUT.major_len()) |major| {
        for (0..OUT.minor_len()) |minor| {
            const y, const x = OUT.major_minor_to_y_x(major, minor);
            var sum: UPGRADE.T = if (UPGRADE.IS_VECTOR) @splat(0) else 0;
            for (0..DEF_A.COLS) |i| {
                sum += MathX.upgrade_multiply(DEF_A.get_cell(mat_a, y, i), DEF_B.get_cell(mat_b, i, x));
            }
            OUT.set_cell(&out, y, x, num_cast(sum, OUT.T));
        }
    }
    return out;
}

test "multiply_matrices" {
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
    const real_out: [3][3]i32 = multiply_matrices(DEF_A, mat_a, DEF_B, mat_b, OUT_T, OUT_ORDER, OUT_PADDING);
    const real_out_flat: *const [9]i32 = @ptrCast(&real_out);
    const real_out_slice: []const i32 = real_out_flat[0..9];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

/// Exactly the same as just using `multiply_matrices(DEF_NUMER, mat_numer, DEF_DENOM_INV, mat_denom_inverse, ...)`,
/// but this signature clearly describes what is being done
pub fn divide_matrices_using_inverse_of_denominator_matrix(comptime DEF_NUMER: MatrixDef, mat_numer: anytype, comptime DEF_DENOM_INV: MatrixDef, mat_denom_inverse: anytype, comptime T_OUT: type, comptime OUT_ORDER: RowColOrder, comptime OUT_PADDING: comptime_int) MatrixDef.def(T_OUT, DEF_NUMER.ROWS, DEF_DENOM_INV.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    return multiply_matrices(DEF_NUMER, mat_numer, DEF_DENOM_INV, mat_denom_inverse, T_OUT, OUT_ORDER, OUT_PADDING);
}

pub fn divide_matrices(comptime DEF_NUMER: MatrixDef, mat_numer: anytype, comptime DEF_DENOM: MatrixDef, mat_denom: anytype, comptime T_OUT: type, comptime OUT_ORDER: RowColOrder, comptime OUT_PADDING: comptime_int) MatrixDef.def(T_OUT, DEF_NUMER.ROWS, DEF_DENOM.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    const inverse_denom = inverse_of_matrix(DEF_DENOM, mat_denom, T_OUT);
    const DEF_DENOM_INV = DEF_DENOM.with_new_type(T_OUT);
    return multiply_matrices(DEF_NUMER, mat_numer, DEF_DENOM_INV, inverse_denom, T_OUT, OUT_ORDER, OUT_PADDING);
}

//TODO test "divide_matrices" {}

pub fn add_matrices(
    comptime DEF_A: MatrixDef,
    mat_a: anytype,
    comptime DEF_B: MatrixDef,
    mat_b: anytype,
    comptime T_OUT: type,
    comptime OUT_ORDER: RowColOrder,
    comptime OUT_PADDING: comptime_int,
) MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    DEF_A.assert_is_matrix(@src(), mat_a);
    DEF_B.assert_is_matrix(@src(), mat_b);
    DEF_A.assert_can_add_sub_or_flat_mult_div(DEF_B, @src());
    const DEF_OUT = MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING);
    if (comptime DEF_A.same_flat_memory_layout(DEF_B) and DEF_A.same_flat_memory_layout(DEF_OUT)) {
        const vec_a: DEF_A.FlatVec() = DEF_A.get_flat_vec(mat_a);
        const vec_b: DEF_B.FlatVec() = DEF_B.get_flat_vec(mat_b);
        const vec_out: DEF_OUT.FlatVec() = MathX.upgrade_add_out(vec_a, vec_b, DEF_OUT.FlatVec());
        return change_matrix_major_order(DEF_OUT, @as(DEF_OUT.Matrix(), @bitCast(vec_out)), OUT_ORDER);
    } else {
        var out: DEF_OUT.Matrix() = undefined;
        for (0..DEF_OUT.major_len()) |major| {
            for (0..DEF_OUT.minor_len()) |minor| {
                const y, const x = DEF_OUT.major_minor_to_y_x(major, minor);
                DEF_OUT.set_cell(&out, y, x, MathX.upgrade_add_out(DEF_A.get_cell(mat_a, y, x), DEF_B.get_cell(mat_b, y, x), DEF_OUT.T));
            }
        }
        return out;
    }
}

test "add_matrices" {
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
    const real_out: [3][4]i32 = add_matrices(DEF_A, mat_a, DEF_B, mat_b, OUT_T, OUT_ORDER, OUT_PADDING);
    const real_out_flat: *const [12]i32 = @ptrCast(&real_out);
    const real_out_slice: []const i32 = real_out_flat[0..12];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

pub fn subtract_matrices(
    comptime DEF_A: MatrixDef,
    mat_a: anytype,
    comptime DEF_B: MatrixDef,
    mat_b: anytype,
    comptime T_OUT: type,
    comptime OUT_ORDER: RowColOrder,
    comptime OUT_PADDING: comptime_int,
) MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    DEF_A.assert_is_matrix(@src(), mat_a);
    DEF_B.assert_is_matrix(@src(), mat_b);
    DEF_A.assert_can_add_sub_or_flat_mult_div(DEF_B, @src());
    const DEF_OUT = MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING);
    if (comptime DEF_A.same_flat_memory_layout(DEF_B) and DEF_A.same_flat_memory_layout(DEF_OUT)) {
        const vec_a: DEF_A.FlatVec() = DEF_A.get_flat_vec(mat_a);
        const vec_b: DEF_B.FlatVec() = DEF_B.get_flat_vec(mat_b);
        const vec_out: DEF_OUT.FlatVec() = MathX.upgrade_subtract_out(vec_a, vec_b, DEF_OUT.FlatVec());
        return change_matrix_major_order(DEF_OUT, @as(DEF_OUT.Matrix(), @bitCast(vec_out)), OUT_ORDER);
    } else {
        var out: DEF_OUT.Matrix() = undefined;
        for (0..DEF_OUT.major_len()) |major| {
            for (0..DEF_OUT.minor_len()) |minor| {
                const y, const x = DEF_OUT.major_minor_to_y_x(major, minor);
                DEF_OUT.set_cell(&out, y, x, MathX.upgrade_subtract_out(DEF_A.get_cell(mat_a, y, x), DEF_B.get_cell(mat_b, y, x), DEF_OUT.T));
            }
        }
        return out;
    }
}

/// This simply multiplies each cell in `mat_a` with the matching cell in `mat_b`
///
/// This is NOT the same as a true matrix multiplication
pub fn non_algebraic_multiply_matrices(
    comptime DEF_A: MatrixDef,
    mat_a: anytype,
    comptime DEF_B: MatrixDef,
    mat_b: anytype,
    comptime T_OUT: type,
    comptime OUT_ORDER: RowColOrder,
    comptime OUT_PADDING: comptime_int,
) MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    DEF_A.assert_is_matrix(@src(), mat_a);
    DEF_B.assert_is_matrix(@src(), mat_b);
    DEF_A.assert_can_add_sub_or_flat_mult_div(DEF_B, @src());
    const DEF_OUT = MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING);
    if (comptime DEF_A.same_flat_memory_layout(DEF_B) and DEF_A.same_flat_memory_layout(DEF_OUT)) {
        const vec_a: DEF_A.FlatVec() = DEF_A.get_flat_vec(mat_a);
        const vec_b: DEF_B.FlatVec() = DEF_B.get_flat_vec(mat_b);
        const vec_out: DEF_OUT.FlatVec() = MathX.upgrade_multiply_out(vec_a, vec_b, DEF_OUT.FlatVec());
        return @bitCast(vec_out);
    } else {
        var out: DEF_OUT.Matrix() = undefined;
        for (0..DEF_OUT.major_len()) |major| {
            for (0..DEF_OUT.minor_len()) |minor| {
                const y, const x = DEF_OUT.major_minor_to_y_x(major, minor);
                DEF_OUT.set_cell(&out, y, x, MathX.upgrade_multiply_out(DEF_A.get_cell(mat_a, y, x), DEF_B.get_cell(mat_b, y, x), DEF_OUT.T));
            }
        }
        return out;
    }
}

//TODO test "non_algebraic_multiply_matrices" {}

/// This simply divides each cell in `mat_a` by the matching cell in `mat_b`
///
/// This is NOT the same as a true matrix division (multiplication by inverse matrix)
pub fn non_algebraic_divide_matrices(
    comptime DEF_A: MatrixDef,
    mat_a: anytype,
    comptime DEF_B: MatrixDef,
    mat_b: anytype,
    comptime T_OUT: type,
    comptime OUT_ORDER: RowColOrder,
    comptime OUT_PADDING: comptime_int,
) MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING).Matrix() {
    DEF_A.assert_is_matrix(@src(), mat_a);
    DEF_B.assert_is_matrix(@src(), mat_b);
    DEF_A.assert_can_add_sub_or_flat_mult_div(DEF_B, @src());
    const DEF_OUT = MatrixDef.def(T_OUT, DEF_A.ROWS, DEF_A.COLS, OUT_ORDER, OUT_PADDING);
    if (comptime DEF_A.same_flat_memory_layout(DEF_B) and DEF_A.same_flat_memory_layout(DEF_OUT)) {
        const vec_a: DEF_A.FlatVec() = DEF_A.get_flat_vec(mat_a);
        const vec_b: DEF_B.FlatVec() = DEF_B.get_flat_vec(mat_b);
        const vec_out: DEF_OUT.FlatVec() = MathX.upgrade_multiply_out(vec_a, vec_b, DEF_OUT.FlatVec());
        return @bitCast(vec_out);
    } else {
        var out: DEF_OUT.Matrix() = undefined;
        for (0..DEF_OUT.major_len()) |major| {
            for (0..DEF_OUT.minor_len()) |minor| {
                const y, const x = DEF_OUT.major_minor_to_y_x(major, minor);
                DEF_OUT.set_cell(&out, y, x, MathX.upgrade_multiply_out(DEF_A.get_cell(mat_a, y, x), DEF_B.get_cell(mat_b, y, x), DEF_OUT.T));
            }
        }
        return out;
    }
}

//TODO test "non_algebraic_divide_matrices" {}

pub fn transpose_matrix(comptime DEF: MatrixDef, mat: anytype) DEF.Transposed().Matrix() {
    const OUT = DEF.Transposed();
    var out: DEF.Transposed().Matrix() = undefined;
    for (0..OUT.major_len()) |major| {
        for (0..OUT.minor_len()) |minor| {
            const y, const x = OUT.major_minor_to_y_x(major, minor);
            OUT.set_cell(&out, y, x, DEF.get_cell(mat, x, y));
        }
    }
    return out;
}

test "transpose_matrix" {
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
    const expected_out_flat: *const [12]i32 = @ptrCast(&expected_mat_out);
    const expected_out_slice: []const i32 = expected_out_flat[0..12];
    const real_out: [3][4]i32 = transpose_matrix(DEF_A, mat_a);
    const real_out_flat: *const [12]i32 = @ptrCast(&real_out);
    const real_out_slice: []const i32 = real_out_flat[0..12];
    try Root.Testing.expect_slices_equal(real_out_slice, "real_out_slice", expected_out_slice, "expected_out_slice", "wrong result", .{});
}

pub const RowOrColKind = enum(u8) {
    ROW,
    COL,
};

/// Usefull for finding best row or column for cofactor expansion, or short-circuiting a determinant of 0
/// if a row/col is found with no non-zero vals
pub fn row_or_col_with_fewest_non_zeroes(comptime DEF: MatrixDef, mat: anytype) DEF.RowOrColNonZeroes() {
    DEF.assert_is_matrix(@src(), mat);
    var result = DEF.RowOrColNonZeroes(){};
    var current_non_zeroes: usize = undefined;
    var possible_non_zero_indices: [DEF.larger_of_cols_or_rows()]usize = undefined;
    for (0..DEF.ROWS) |y| {
        current_non_zeroes = 0;
        for (0..DEF.COLS) |x| {
            if (DEF.get_cell(mat, y, x) != 0) {
                possible_non_zero_indices[current_non_zeroes] = x;
                current_non_zeroes += 1;
            }
        }
        if (current_non_zeroes < result.non_zero_count) {
            result.non_zero_count = current_non_zeroes;
            result.idx = y;
            result.kind = .ROW;
            result.non_zero_indices = possible_non_zero_indices;
            if (result.non_zero_count == 0) return result;
        }
    }
    for (0..DEF.COLS) |x| {
        current_non_zeroes = 0;
        for (0..DEF.ROWS) |y| {
            if (DEF.get_cell(mat, y, x) != 0) {
                possible_non_zero_indices[current_non_zeroes] = y;
                current_non_zeroes += 1;
            }
        }
        if (current_non_zeroes < result.non_zero_count) {
            result.non_zero_count = current_non_zeroes;
            result.idx = x;
            result.kind = .COL;
            result.non_zero_indices = possible_non_zero_indices;
            if (result.non_zero_count == 0) return result;
        }
    }
    return result;
}

//TODO test "row_or_col_with_fewest_non_zeroes" {}

/// Useful for finding best row or column for determinant caclulation when the cofactors are pre-computed,
/// or short-circuiting a determinant of 0 if a row/col is found with no non-zero vals
pub fn row_or_col_with_fewest_non_zeroes_using_cofactors(comptime DEF: MatrixDef, mat: anytype, comptime CO_DEF: MatrixDef, cofactor_mat: anytype) DEF.RowOrColNonZeroes() {
    DEF.assert_is_matrix(@src(), mat);
    CO_DEF.assert_is_matrix(@src(), cofactor_mat);
    var result = DEF.RowOrColNonZeroes(){};
    var current_non_zeroes: usize = undefined;
    var possible_non_zero_indices: [DEF.larger_of_cols_or_rows()]usize = undefined;
    for (0..DEF.ROWS) |y| {
        current_non_zeroes = 0;
        for (0..DEF.COLS) |x| {
            if (DEF.get_cell(mat, y, x) != 0 and CO_DEF.get_cell(cofactor_mat, y, x) != 0) {
                possible_non_zero_indices[current_non_zeroes] = x;
                current_non_zeroes += 1;
            }
        }
        if (current_non_zeroes < result.non_zero_count) {
            result.non_zero_count = current_non_zeroes;
            result.idx = y;
            result.kind = .ROW;
            result.non_zero_indices = possible_non_zero_indices;
            if (result.non_zero_count == 0) return result;
        }
    }
    for (0..DEF.COLS) |x| {
        current_non_zeroes = 0;
        for (0..DEF.ROWS) |y| {
            if (DEF.get_cell(mat, y, x) != 0 and CO_DEF.get_cell(cofactor_mat, y, x) != 0) {
                possible_non_zero_indices[current_non_zeroes] = y;
                current_non_zeroes += 1;
            }
        }
        if (current_non_zeroes < result.non_zero_count) {
            result.non_zero_count = current_non_zeroes;
            result.idx = x;
            result.kind = .COL;
            result.non_zero_indices = possible_non_zero_indices;
            if (result.non_zero_count == 0) return result;
        }
    }
    return result;
}

//TODO test "row_or_col_with_fewest_non_zeroes_using_cofactors" {}

pub fn cofactor_sign(comptime T: type, major: usize, minor: usize) T {
    const outs = [2]T{ @as(T, 1), @as(T, -1) };
    const sum = major + minor;
    const idx = sum & 1;
    return outs[idx];
}
pub fn cofactor_val_signed(comptime T: type, major: usize, minor: usize, cell_or_minor_determinant_val: T) T {
    const outs = [2]T{ @as(T, cell_or_minor_determinant_val), @as(T, -cell_or_minor_determinant_val) };
    const sum = major + minor;
    const idx = sum & 1;
    return outs[idx];
}

/// 1x1, 2x2, and 3x3 matrices use a static formula with only multiplies, adds, and subtractions,
/// so the `DETERMINANT_TYPE` can be the same as the cell type, or one integer size larger if the cell values are large
/// for their current type (and upgrade an unsigned int to a signed int in most cases)
///
/// 4x4 (sometimes), 5x5 (often), and larger matrices (always) use Row Echelon Form, which can result in many fractions
/// during the calculation process, so upgrading the determinant type to a float is recommended.
///
/// Note: the hueristics used to choose when to use static-formula vs cofactor-expansion vs row-echelon-form
/// have not been benchmarked, but all cases should be fairly performant. Some additional optimizations might be made
/// with large-scale benchmarks of random matrices with random element types using all 3 methods to adjust the hueristics,
/// particularly in the 3x3, 4x4, 5x5, and 6x6 range. Anything 7x7 or larger is probably *always* fastest with row-echelon form,
/// even if the best cofactor expansion row/col for that matrix has only 1 non-zero val (it would still require finding at least
/// one 6x6 determinant and 1 multiply)
///
/// Another possible avenue for optimization is to implement a hybrid approach, using `basic row operations` to
/// manipulate the input to artificially create a row or column with only a few non-zero values, then
/// using cofactor expansion on that row/col and re-applying the determinant factor changes from the row ops.
pub fn determinant_of_matrix(comptime DEF: MatrixDef, mat: anytype, comptime DETERMINANT_TYPE: type) DETERMINANT_TYPE {
    DEF.assert_can_get_determinant(@src());
    DEF.assert_is_matrix(@src(), mat);
    switch (DEF.ROWS) {
        1 => {
            return num_cast(mat[0][0], DETERMINANT_TYPE);
        },
        2 => {
            return MathX.upgrade_subtract_out(MathX.upgrade_multiply(DEF.get_cell(mat, 0, 0), DEF.get_cell(mat, 1, 1)), MathX.upgrade_multiply(DEF.get_cell(mat, 0, 1), DEF.get_cell(mat, 1, 0)), DETERMINANT_TYPE);
        },
        3 => {
            // Always choose static formula (cofactor expansion of row 1) because looping through each row and column to
            // find one with the fewest non-zero vals has more overhead than just doing a few extra multiplies and adds
            // This also prevents additional recusrsions down to 2x2 minor determinants when finding minor determinants from 4x4, 5x5, and 6x6 matrices
            const ei_fh = MathX.upgrade_subtract(MathX.upgrade_multiply(DEF.get_cell(mat, 1, 1), DEF.get_cell(mat, 2, 2)), MathX.upgrade_multiply(DEF.get_cell(mat, 1, 2), DEF.get_cell(mat, 2, 1)));
            const di_fg = MathX.upgrade_subtract(MathX.upgrade_multiply(DEF.get_cell(mat, 1, 0), DEF.get_cell(mat, 2, 2)), MathX.upgrade_multiply(DEF.get_cell(mat, 1, 2), DEF.get_cell(mat, 2, 0)));
            const dh_eg = MathX.upgrade_subtract(MathX.upgrade_multiply(DEF.get_cell(mat, 1, 0), DEF.get_cell(mat, 2, 1)), MathX.upgrade_multiply(DEF.get_cell(mat, 1, 1), DEF.get_cell(mat, 2, 0)));
            const a = MathX.upgrade_multiply(DEF.get_cell(mat, 0, 0), ei_fh);
            const b = MathX.upgrade_multiply(DEF.get_cell(mat, 0, 1), di_fg);
            const c = MathX.upgrade_multiply(DEF.get_cell(mat, 0, 2), dh_eg);
            const a_b = MathX.upgrade_subtract(a, b);
            return MathX.upgrade_add_out(a_b, c, DETERMINANT_TYPE);
        },
        else => {
            // dont even bother looping through all rows and columns looking for one with all 0's if
            // the size is very large. The possible savings wont be worth the time required, and
            // we can use a short-circuit in the row-echelon-form calculation anyway
            if (DEF.ROWS <= 6) {
                const fewest_non_zero = row_or_col_with_fewest_non_zeroes(DEF, mat);
                if (fewest_non_zero.non_zero_count == 0) return 0;
                // heuristics for choosing cofactor expansion
                if ((DEF.ROWS == 4 and fewest_non_zero.non_zero_count <= 3) or (DEF.ROWS == 5 and fewest_non_zero.non_zero_count <= 2) or (DEF.ROWS == 6 and fewest_non_zero.non_zero_count == 1)) {
                    switch (fewest_non_zero.kind) {
                        .ROW => {
                            const y = fewest_non_zero.idx;
                            var sum: DETERMINANT_TYPE = 0;
                            for (0..fewest_non_zero.non_zero_count) |i| {
                                const x = fewest_non_zero.non_zero_indices[i];
                                const cell_signed = cofactor_val_signed(DETERMINANT_TYPE, y, x, num_cast(DEF.get_cell(mat, y, x), DETERMINANT_TYPE));
                                const minor = sub_matrix_excluding_row_and_column(DEF, mat, y, x);
                                const minor_det = determinant_of_matrix(DEF.with_size_minus_one(), minor, DETERMINANT_TYPE);
                                sum += cell_signed * minor_det;
                            }
                            return sum;
                        },
                        .COL => {
                            const x = fewest_non_zero.idx;
                            var sum: DETERMINANT_TYPE = 0;
                            for (0..fewest_non_zero.non_zero_count) |i| {
                                const y = fewest_non_zero.non_zero_indices[i];
                                const cell_signed = cofactor_val_signed(DETERMINANT_TYPE, y, x, num_cast(DEF.get_cell(mat, y, x), DETERMINANT_TYPE));
                                const minor = sub_matrix_excluding_row_and_column(DEF, mat, y, x);
                                const minor_det = determinant_of_matrix(DEF.with_size_minus_one(), minor, DETERMINANT_TYPE);
                                sum += cell_signed * minor_det;
                            }
                            return sum;
                        },
                    }
                }
            }
            // using `.ROW_ECHELON_LEADING_NON_ZERO` and `.CACHE_PIVOT_VALUES` for multiplication
            // will take less multiplications overall when we only care about the determinant
            // for example a full-rank 4x4 matrix takes 9 fewer mults, a full-rank 5x5 takes 14 fewer, etc.
            const row_echelon_result = row_echelon_form_of_matrix(DEF, mat, .ROW_ECHELON_LEADING_NON_ZERO, .STOP_IF_NOT_FULL_RANK, DETERMINANT_TYPE, DETERMINANT_TYPE, .CACHE_PIVOT_VALUES);
            if (row_echelon_result.rank != DEF.ROWS) return 0;
            var pivot_products = row_echelon_result.pivots[0];
            for (1..DEF.ROWS) |p| {
                pivot_products *= row_echelon_result.pivots[p];
            }
            return MathX.upgrade_multiply_out(row_echelon_result.determinant_factor, pivot_products, DETERMINANT_TYPE);
        },
    }
}

test "determinant_of_matrix" {
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
    var result = determinant_of_matrix(DEF_2x2, mat_2x2, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_2x2_a, "expect_2x2_a", "wrong result", .{});
    // {{ 2, 0, 1 },{ 4, 0, 1 },{ 2, -1, 2 }}
    // determinant should be -2
    var mat_3x3 = MAT_3x3{
        .{ 2, 0, 1 },
        .{ 4, 0, 1 },
        .{ 2, -1, 2 },
    };
    const expect_3x3_a: f32 = -2;
    result = determinant_of_matrix(DEF_3x3, mat_3x3, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_3x3_a, "expect_3x3_a", "wrong result", .{});
    // {{ 7, -4, 2 },{ 3, 1, -5 },{ 2, 2, -5 }}
    // determinant should be 23
    mat_3x3 = MAT_3x3{
        .{ 7, -4, 2 },
        .{ 3, 1, -5 },
        .{ 2, 2, -5 },
    };
    const expect_3x3_b: f32 = 23;
    result = determinant_of_matrix(DEF_3x3, mat_3x3, f32);
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
    result = determinant_of_matrix(DEF_4x4, mat_4x4, f32);
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
    result = determinant_of_matrix(DEF_4x4, mat_4x4, f32);
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
    result = determinant_of_matrix(DEF_4x4, mat_4x4, f32);
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
    result = determinant_of_matrix(DEF_5x5, mat_5x5, f32);
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
    result = determinant_of_matrix(DEF_5x5, mat_5x5, f32);
    try Test.expect_approx_equal(result, "result", 0.0001, "0.0001", expect_5x5_b, "expect_5x5_b", "wrong result", .{});
}

/// If you have already computed the matrix of cofactors for a matrix
/// (for example in preparation for finding the inverse of an invertable matrix),
/// you can use this method to find the determinant faster than without precomputed cofactors
///
/// The worst-case operational cost 'roughly' becomes O(N) where N is the smaller of `ROWS` and `COLS`
///
/// 1x1 and 2x2 matrices still use the static formula to skip programatic overhead
///
/// For 3x3 to 5x5 matrices a O(n^2) pass is first done to find the row or column with the fewest places where both
/// the 'original cell' and 'cofactor cell' are non-zero and using that best row/col for the calculation. This heuristic may
/// need investigation and tweaking to determine what size matrix is not worth finding the easiest row/col, or if it *always* is
pub fn determinant_of_matrix_precomputed_cofactors(comptime DEF: MatrixDef, mat: anytype, comptime CO_DEF: MatrixDef, cofactor_mat: anytype, comptime DETERMINANT_TYPE: type) DETERMINANT_TYPE {
    DEF.assert_is_matrix(@src(), mat);
    CO_DEF.assert_is_matrix(@src(), cofactor_mat);
    DEF.assert_same_size(CO_DEF, @src());
    DEF.assert_can_get_determinant(@src());
    // 1x1 and 2x2 are so simple we might as well just use the static formulas
    // in order to skip the overhead of finding the best row/col and looping over the
    // non-zero elements
    switch (DEF.ROWS) {
        1 => {
            return num_cast(mat[0][0], DETERMINANT_TYPE);
        },
        2 => {
            return MathX.upgrade_subtract_out(MathX.upgrade_multiply(DEF.get_cell(mat, 0, 0), DEF.get_cell(mat, 1, 1)), MathX.upgrade_multiply(DEF.get_cell(mat, 0, 1), DEF.get_cell(mat, 1, 0)), DETERMINANT_TYPE);
        },
        else => {
            // initialize to compute ALL vals in row 1,
            // which will always be the case for 6x6 and larger
            var fewest_non_zero = DEF.RowOrColNonZeroes(){
                .kind = .ROW,
                .idx = 0,
                .non_zero_count = DEF.ROWS,
                .non_zero_indices = comptime DEF.row_indices(),
            };
            // for sizes 3x3 to 5x5, find the actual row/col with the fewest needed computations
            if (DEF.ROWS <= 5) {
                fewest_non_zero = row_or_col_with_fewest_non_zeroes_using_cofactors(DEF, mat, CO_DEF, cofactor_mat);
                if (fewest_non_zero.non_zero_count == 0) return 0;
            }
            switch (fewest_non_zero.kind) {
                .ROW => {
                    const y = fewest_non_zero.idx;
                    var sum: DETERMINANT_TYPE = 0;
                    for (0..fewest_non_zero.non_zero_count) |i| {
                        const x = fewest_non_zero.non_zero_indices[i];
                        const cofactor_signed = CO_DEF.get_cell(cofactor_mat, y, x);
                        const cell = DEF.get_cell(mat, y, x);
                        sum += cell * cofactor_signed;
                    }
                    return sum;
                },
                .COL => {
                    const x = fewest_non_zero.idx;
                    var sum: DETERMINANT_TYPE = 0;
                    for (0..fewest_non_zero.non_zero_count) |i| {
                        const y = fewest_non_zero.non_zero_indices[i];
                        const cofactor_signed = CO_DEF.get_cell(cofactor_mat, y, x);
                        const cell = DEF.get_cell(mat, y, x);
                        sum += cell * cofactor_signed;
                    }
                    return sum;
                },
            }
        },
    }
}

//TODO test "determinant_of_matrix_precomputed_cofactors" {}

pub const RowEchelonMode = enum(u8) {
    ROW_ECHELON_LEADING_NON_ZERO,
    ROW_ECHELON_LEADING_1,
    // REDUCED_ROW_ECHELON_LEADING_1,
};

pub const RowEchelonShortCircuitMode = enum(u8) {
    DO_NOT_STOP_IF_NOT_FULL_RANK,
    STOP_IF_NOT_FULL_RANK,
};

/// Does not handle Vector element types (since each element of the vector type could require a different row operation)
///
/// If `.STOP_IF_NOT_FULL_RANK` is used, calculation ends as soon as it is determined that
/// the matrix is not a full 'rank' and the `.determinant_factor` is set to 0. In this case the resulting
/// matrix, rank, and pivot columns will be incomplete, but allows optimization for cases where non-full rank
/// can be handled with a special case (for example immediately returning a determinant of 0)
///
/// Does not produce *Reduced* Row Echelon Form (yet)
///
/// Note that it is very difficult to verify the correctness of the returned matrix when using
/// `.ROW_ECHELON_LEADING_NON_ZERO` or `.ROW_ECHELON_LEADING_1`,
/// as there are MANY possible correct outcomes, as opposed to `REDUCED_ROW_ECHELON_LEADING_1` which only has one
/// correct result for any given matrix. However the results are curently tested against the known determinant and rank
/// for correct operation.
pub fn row_echelon_form_of_matrix(comptime DEF: MatrixDef, mat: anytype, mode: RowEchelonMode, short_circuit: RowEchelonShortCircuitMode, comptime CELL_TYPE: type, comptime DETERMINANT_TYPE: type, comptime PIVOT_MODE: RowEchelonPivotCache) DEF.RowEchelonResult(CELL_TYPE, DETERMINANT_TYPE, PIVOT_MODE) {
    const OUT = DEF.RowEchelonResult(CELL_TYPE, DETERMINANT_TYPE, PIVOT_MODE).DEF;
    var out: DEF.RowEchelonResult(CELL_TYPE, DETERMINANT_TYPE, PIVOT_MODE) = .{ .mat = DEF.clone_to_new_type(mat, CELL_TYPE) };
    var pivot_y: usize = 0;
    var pivot_x: usize = 0;
    var largest_pivot_y: usize = undefined;
    var largest_pivot: OUT.T = undefined;
    var factor: OUT.T = undefined;
    var allowed_cols_with_no_pivots_for_full_rank: isize = DEF.larger_of_cols_or_rows() - DEF.ROWS;
    while (pivot_y < OUT.ROWS and pivot_x < OUT.COLS) {
        largest_pivot_y = pivot_y;
        largest_pivot = 0;
        for (pivot_y..OUT.ROWS) |test_y| {
            if (@abs(OUT.get_cell(out.mat, test_y, pivot_x)) > largest_pivot) {
                largest_pivot_y = test_y;
            }
        }
        if (OUT.get_cell(out.mat, largest_pivot_y, pivot_x) == 0) {
            if (short_circuit == .STOP_IF_NOT_FULL_RANK) {
                if (allowed_cols_with_no_pivots_for_full_rank <= 0) {
                    out.determinant_factor = 0;
                    return out;
                }
                allowed_cols_with_no_pivots_for_full_rank -= 1;
            }
            pivot_x += 1;
        } else {
            if (largest_pivot_y != pivot_y) {
                // SWAP ROWS FOR BEST PIVOT
                OUT.swap_rows(&out.mat, pivot_y, largest_pivot_y);
                out.determinant_factor = -out.determinant_factor;
                // END SWAP ROWS FOR BEST PIVOT
            }
            if (mode == .ROW_ECHELON_LEADING_1) {
                // SCALE PIVOT ROW
                factor = OUT.get_cell(out.mat, pivot_y, pivot_x);
                OUT.set_cell(&out.mat, pivot_y, pivot_x, 1);
                for ((pivot_x + 1)..OUT.COLS) |col_after_pivot_x| {
                    const old_val = OUT.get_cell(out.mat, pivot_y, col_after_pivot_x);
                    if (Types.type_is_signed_int(OUT.T)) {
                        OUT.set_cell(&out.mat, pivot_y, col_after_pivot_x, @divTrunc(old_val, factor));
                    } else {
                        OUT.set_cell(&out.mat, pivot_y, col_after_pivot_x, old_val / factor);
                    }
                }
                out.determinant_factor *= factor;
                // END SCALE PIVOT ROW
            }
            for ((pivot_y + 1)..OUT.ROWS) |row_below_pivot_y| {
                // SUBTRACT ROWS BELOW BY MULTIPLE OF PIVOT ROW
                factor = OUT.get_cell(out.mat, row_below_pivot_y, pivot_x);
                if (mode != .ROW_ECHELON_LEADING_1) {
                    if (Types.type_is_signed_int(OUT.T)) {
                        factor = @divTrunc(factor, OUT.get_cell(out.mat, pivot_y, pivot_x));
                    } else {
                        factor = factor / OUT.get_cell(out.mat, pivot_y, pivot_x);
                    }
                }
                // this is the same as `out[row_below_pivot_y][pivot_x] -= out[pivot_y][pivot_x] * factor`
                OUT.set_cell(&out.mat, row_below_pivot_y, pivot_x, 0);
                for ((pivot_x + 1)..OUT.COLS) |col_after_pivot_x| {
                    const scaled_from_pivot_row = OUT.get_cell(out.mat, pivot_y, col_after_pivot_x) * factor;
                    const old_val = OUT.get_cell(out.mat, row_below_pivot_y, col_after_pivot_x);
                    OUT.set_cell(&out.mat, row_below_pivot_y, col_after_pivot_x, old_val - scaled_from_pivot_row);
                }
                // END SUBTRACT ROWS BELOW BY MULTIPLE OF PIVOT ROW
            }
            switch (PIVOT_MODE) {
                .DO_NOT_CACHE_PIVOTS => {},
                .CACHE_PIVOT_X_INDEXES => {
                    out.pivots[pivot_y] = pivot_x;
                },
                .CACHE_PIVOT_VALUES => {
                    out.pivots[pivot_y] = OUT.get_cell(out.mat, pivot_y, pivot_x);
                },
            }
            pivot_y += 1;
            pivot_x += 1;
            out.rank += 1;
        }
    }
    if (out.rank != DEF.ROWS) {
        out.determinant_factor = 0;
    }
    return out;
}

test "row_echelon_form_of_matrix" {
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
    var result = row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .STOP_IF_NOT_FULL_RANK, f32, f32);
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
    result = row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .STOP_IF_NOT_FULL_RANK, f32, f32);
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
    result = row_echelon_form_of_matrix(DEF_A, mat_a, .ROW_ECHELON_LEADING_1, .DO_NOT_STOP_IF_NOT_FULL_RANK, f32, f32);
    try Root.Testing.expect_approx_equal(result.determinant_factor, "result.determinant_factor", 0.0001, "0.0001", 0, "0", "wrong result", .{});
    try Root.Testing.expect_equal(result.rank, "result.rank", 3, "3", "wrong result", .{});
}

pub fn sub_matrix_excluding_row_and_column(comptime DEF: MatrixDef, mat: anytype, row: usize, col: usize) DEF.with_size_minus_one().Matrix() {
    DEF.assert_can_get_matrix_one_size_smaller(@src());
    const OUT = DEF.with_size_minus_one();
    var out: OUT.Matrix() = undefined;
    var out_major: usize = 0;
    var out_minor: usize = 0;
    const discard_major, const discard_minor = DEF.y_x_to_major_minor(row, col);
    for (0..DEF.major_len()) |in_major| {
        if (in_major == discard_major) continue;
        out_minor = 0;
        for (0..DEF.minor_len()) |in_minor| {
            if (in_minor == discard_minor) continue;
            OUT.set_cell_mm(&out, out_major, out_minor, DEF.get_cell_mm(mat, in_major, in_minor));
            out_minor += 1;
        }
        out_major += 1;
    }
    return out;
}

pub fn cofactors_of_matrix(comptime DEF: MatrixDef, mat: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_can_get_determinant(@src());
    DEF.assert_is_matrix(@src(), mat);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const MIN = DEF.with_size_minus_one();
    var out: OUT.Matrix() = undefined;
    if (DEF.ROWS == 1) {
        out[0][0] = num_cast(mat[0][0], NEW_CELL_TYPE);
        return out;
    }
    DEF.assert_can_get_matrix_one_size_smaller(@src());
    for (0..DEF.major_len()) |major| {
        for (0..DEF.minor_len()) |minor| {
            const y, const x = DEF.major_minor_to_y_x(major, minor);
            const minor_mat = sub_matrix_excluding_row_and_column(DEF, mat, y, x);
            const minor_determinant = determinant_of_matrix(MIN, minor_mat, NEW_CELL_TYPE);
            const signed_cofactor = cofactor_val_signed(NEW_CELL_TYPE, y, x, minor_determinant);
            OUT.set_cell_mm(&out, major, minor, signed_cofactor);
        }
    }
    return out;
}

/// Exactly the same as just using `transpose_matrix(CO_DEF, mat_cofactors)`,
/// but this signature clearly describes what is being done
pub fn adjugate_of_matrix_using_cofactors(comptime CO_DEF: MatrixDef, mat_cofactors: anytype) CO_DEF.Transposed().Matrix() {
    return transpose_matrix(CO_DEF, mat_cofactors);
}
pub fn adjugate_of_matrix(comptime DEF: MatrixDef, mat: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Transposed().Matrix() {
    const CO_DEF = DEF.with_new_type(NEW_CELL_TYPE);
    const cofactors = cofactors_of_matrix(DEF, mat, NEW_CELL_TYPE);
    return transpose_matrix(CO_DEF, cofactors);
}

pub fn inverse_of_matrix_using_adjugate_and_determinant(comptime ADJ_DEF: MatrixDef, mat_adjugate: anytype, determinant: anytype, comptime NEW_CELL_TYPE: type) ADJ_DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    return divide_matrix_by_scalar(ADJ_DEF, mat_adjugate, determinant, NEW_CELL_TYPE);
}
pub fn inverse_of_matrix(comptime DEF: MatrixDef, mat: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    const determinant = determinant_of_matrix(DEF, mat, NEW_CELL_TYPE);
    const ADJ_DEF = DEF.with_new_type(NEW_CELL_TYPE);
    const adjugate = adjugate_of_matrix(DEF, mat, NEW_CELL_TYPE);
    return divide_matrix_by_scalar(ADJ_DEF, adjugate, determinant);
}

//TODO test "inverse_of_matrix" {}

/// Mat * Scalar = NewMat
pub fn multiply_matrix_by_scalar(comptime DEF: MatrixDef, mat: anytype, determinant: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(determinant)) = @splat(determinant);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_multiply_out(in_flat, scalar_flat, OUT_FLAT));
}
/// Mat / Scalar = NewMat
pub fn divide_matrix_by_scalar(comptime DEF: MatrixDef, mat: anytype, scalar: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    assert_with_reason(scalar != 0, @src(), "divide by zero", .{});
    const in_flat = DEF.get_flat_vec(mat);
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(scalar)) = @splat(scalar);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_divide_out(in_flat, scalar_flat, OUT_FLAT));
}
/// Scalar / Mat = NewMat
pub fn divide_scalar_by_matrix(comptime DEF: MatrixDef, mat: anytype, scalar: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    DEF.fill_flat_padding_with_val(&in_flat, 1);
    DEF.assert_no_vals_zero_flat(in_flat, @src(), "divide by zero");
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(scalar)) = @splat(scalar);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_divide_out(scalar_flat, in_flat, OUT_FLAT));
}
/// Mat + Scalar = NewMat
pub fn add_scalar_to_matrix(comptime DEF: MatrixDef, mat: anytype, scalar: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(scalar)) = @splat(scalar);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_add_out(in_flat, scalar_flat, OUT_FLAT));
}
/// Mat - Scalar = NewMat
pub fn subtract_scalar_from_matrix(comptime DEF: MatrixDef, mat: anytype, scalar: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(scalar)) = @splat(scalar);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_subtract_out(in_flat, scalar_flat, OUT_FLAT));
}
/// Scalar - Mat = NewMat
pub fn subtract_matrix_from_scalar(comptime DEF: MatrixDef, mat: anytype, scalar: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    const scalar_flat: @Vector(DEF.total_cells(), @TypeOf(scalar)) = @splat(scalar);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(MathX.upgrade_subtract_out(scalar_flat, in_flat, OUT_FLAT));
}
pub fn negate_matrix_elements(comptime DEF: MatrixDef, mat: anytype, comptime NEW_CELL_TYPE: type) DEF.with_new_type(NEW_CELL_TYPE).Matrix() {
    DEF.assert_is_matrix(@src(), mat);
    const in_flat = DEF.get_flat_vec(mat);
    const OUT = DEF.with_new_type(NEW_CELL_TYPE);
    const OUT_FLAT = OUT.FlatVec();
    return @bitCast(-num_cast(in_flat, comptime OUT_FLAT));
}

//TODO test "negate_matrix_elements" {}
