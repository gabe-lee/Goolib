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
const build = @import("builtin");
const math = std.math;

const Root = @import("./_root.zig");
const FlexSlice = Root.FlexSlice.FlexSlice;

/// A placeholder type intended for use in methods that take an `anytype` parameter
///
/// This signals to the function that either:
/// - It should infer the type/value of this parameter based on the types/values of other paremeters provided
/// - It should choose some default type/value for this parameter
pub const Auto = struct {};

/// TODO documentation
pub const PointOrientation = enum {
    /// TODO documentation
    COLINEAR,
    /// TODO documentation
    WINDING_CCW,
    /// TODO documentation
    WINDING_CW,
};

pub const Side = enum {
    LEFT,
    RIGHT,
};

/// TODO documentation
pub const ErrorBehavior = enum {
    /// TODO documentation
    RETURN_ERRORS,
    /// TODO documentation
    ERRORS_PANIC,
    /// TODO documentation
    ERRORS_ARE_UNREACHABLE,
};

/// TODO documentation
pub const GrowthModel = enum {
    /// TODO documentation
    GROW_EXACT_NEEDED,
    /// TODO documentation
    GROW_EXACT_NEEDED_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_100_PERCENT,
    /// TODO documentation
    GROW_BY_100_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_50_PERCENT,
    /// TODO documentation
    GROW_BY_50_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_25_PERCENT,
    /// TODO documentation
    GROW_BY_25_PERCENT_ATOMIC_PADDING,
};

/// TODO documentation
pub const SortAlgorithm = enum {
    // BUBBlE_SORT,
    // HEAP_SORT,
    ///TODO documentation
    INSERTION_SORT,
    /// TODO documentation
    QUICK_SORT_PIVOT_FIRST,
    /// TODO documentation
    QUICK_SORT_PIVOT_MIDDLE,
    /// TODO documentation
    QUICK_SORT_PIVOT_LAST,
    /// TODO documentation
    QUICK_SORT_PIVOT_RANDOM,
    /// TODO documentation
    QUICK_SORT_PIVOT_MEDIAN_OF_3,
    /// TODO documentation
    QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM,
};

/// TODO documentation
pub const ReadError = error{
    /// TODO documentation
    read_buffer_too_short,
    /// TODO documentation
    destination_too_short_for_given_range,
};

/// TODO documentation
pub const WriteError = error{
    write_buffer_too_short,
};

pub const Mutability = enum {
    immutable,
    mutable,
};

pub const LenMutability = enum {
    immutable,
    shrink_only,
    grow_only,
    shrink_or_grow,
};

pub const PosMutability = enum {
    immutable,
    increase_only,
    decrease_only,
    increase_or_decrease,
};

pub const PathKind = enum(u8) {
    ABSOLUTE,
    RELATIVE_CWD,
};

pub const Path = union(PathKind) {
    ABSOLUTE: []const u8,
    RELATIVE_CWD: []const u8,
};

pub const TuplePointer = struct { tuple_type: type, opaque_ptr: *anyopaque };

pub fn ArrayLen(comptime N: comptime_int, comptime T: type) type {
    return struct {
        arr: [N]T,
        len: usize,

        const Self = @This();

        pub inline fn slice(self: *Self) []T {
            return self.arr[0..self.len];
        }
        pub inline fn slice_const(self: *const Self) []const T {
            return self.arr[0..self.len];
        }

        pub inline fn flex_slice(self: *Self) FlexSlice(T, math.IntFittingRange(0, N), .mutable) {
            return FlexSlice(T, math.IntFittingRange(0, N), .mutable){
                .ptr = &self.arr[0],
                .len = self.len,
            };
        }

        pub inline fn flex_slice_const(self: *const Self) FlexSlice(T, math.IntFittingRange(0, N), .immutable) {
            return FlexSlice(T, math.IntFittingRange(0, N), .immutable){
                .ptr = &self.arr[0],
                .len = self.len,
            };
        }
    };
}
