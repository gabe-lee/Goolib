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
const build = @import("builtin");
const math = std.math;

const Root = @import("./_root.zig");
const FlexSlice = Root.FlexSlice.FlexSlice;
const Assert = Root.Assert;

const assert_unreachable = Assert.assert_unreachable;

/// A placeholder type intended for use in methods that take an `anytype` parameter
///
/// This signals to the function that either:
/// - It should infer the type/value of this parameter based on the types/values of other paremeters provided
/// - It should choose some default type/value for this parameter
pub const Auto = struct {};

/// TODO documentation
pub const ShapeWinding = enum(i8) {
    /// TODO documentation
    COLINEAR = 0,
    /// TODO documentation
    WINDING_CCW = 1,
    /// TODO documentation
    WINDING_CW = -1,
};

pub const Side = enum {
    LEFT,
    RIGHT,
};

/// A type describing a user-defined option for whether a function (or all/some
/// of a type's methods) should return errors when they occur,
/// or whether they should panic or be 'unreachable'
pub const ErrorBehavior = enum {
    /// Errors are returned
    RETURN_ERRORS,
    /// Errors are returned, but when they occur a warning is also written to STDERR
    RETURN_ERRORS_AND_WARN,
    /// Errors *ALWAYS* panic
    ERRORS_PANIC,
    /// Errors only panic in 'safe' modes, otherwise they are 'unreachable'
    ERRORS_ARE_UNREACHABLE,

    pub inline fn handle(comptime self: ErrorBehavior, comptime src: ?std.builtin.SourceLocation, err: anyerror) if (self.does_error()) @TypeOf(err) else noreturn {
        return switch (self) {
            .RETURN_ERRORS => err,
            .RETURN_ERRORS_AND_WARN => warn: {
                Assert.warn_with_reason(false, src, "an error was returned from this function: {s}", .{@errorName(err)});
                break :warn err;
            },
            .ERRORS_PANIC => {
                Assert.assert_unreachable_always_panic(src, "an error was returned from this function: {s}", .{@errorName(err)});
                unreachable;
            },
            .ERRORS_ARE_UNREACHABLE => {
                Assert.assert_unreachable(src, "an error was returned from this function: {s}", .{@errorName(err)});
                unreachable;
            },
        };
    }

    pub inline fn panic(comptime self: ErrorBehavior, comptime src: ?std.builtin.SourceLocation, err: anyerror) noreturn {
        return switch (self) {
            .ERRORS_PANIC => {
                Assert.assert_unreachable_always_panic(src, "an error was returned from this function: {s}", .{@errorName(err)});
                unreachable;
            },
            .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN, .ERRORS_ARE_UNREACHABLE => {
                Assert.assert_unreachable(src, "an error was returned from this function: {s}", .{@errorName(err)});
                unreachable;
            },
        };
    }

    pub inline fn does_error(comptime self: ErrorBehavior) bool {
        return switch (self) {
            .RETURN_ERRORS, .RETURN_ERRORS_AND_WARN => true,
            .ERRORS_PANIC, .ERRORS_ARE_UNREACHABLE => false,
        };
    }
};

pub fn PossibleErrorBuilder(comptime ERRORS: bool) type {
    const PROTO = struct {
        inline fn PossibleError_E(comptime T: type) type {
            return anyerror!T;
        }
        inline fn PossibleError_N(comptime T: type) type {
            return T;
        }
    };
    return if (ERRORS) PROTO.PossibleError_E else PROTO.PossibleError_N;
}
pub fn PossibleErrorBuilderFromMode(comptime ERRORS_MODE: ErrorBehavior) type {
    return PossibleErrorBuilder(comptime ERRORS_MODE.does_error());
}

/// TODO documentation
pub const AssertBehavior = enum {
    /// TODO documentation
    IGNORE,
    /// TODO documentation
    PANIC_IN_SAFE_MODES,
    /// TODO documentation
    ALWAYS_PANIC,
};

/// TODO documentation
pub const WarnBehavior = enum {
    /// TODO documentation
    IGNORE,
    /// TODO documentation
    WARN_IN_DEBUG,
    /// TODO documentation
    WARN_IN_SAFE_MODES,
    /// TODO documentation
    ALWAYS_WARN,
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

pub const Alignment = enum(u64) {
    _1 = 1 << 0,
    _2 = 1 << 1,
    _4 = 1 << 2,
    _8 = 1 << 3,
    _16 = 1 << 4,
    _32 = 1 << 5,
    _64 = 1 << 6,
    _128 = 1 << 7,
    _256 = 1 << 8,
    _512 = 1 << 9,
    _1024 = 1 << 10,
    _2048 = 1 << 11,
    _4096 = 1 << 12,
    _8192 = 1 << 13,
    _16384 = 1 << 14,
    _32768 = 1 << 15,
    _65536 = 1 << 16,
    _L_17 = 1 << 17,
    _L_18 = 1 << 18,
    _L_19 = 1 << 19,
    _L_20 = 1 << 20,
    _L_21 = 1 << 21,
    _L_22 = 1 << 22,
    _L_23 = 1 << 23,
    _L_24 = 1 << 24,
    _L_25 = 1 << 25,
    _L_26 = 1 << 26,
    _L_27 = 1 << 27,
    _L_28 = 1 << 28,
    _L_29 = 1 << 29,
    _L_30 = 1 << 30,
    _L_31 = 1 << 31,
    _L_32 = 1 << 32,
    _L_33 = 1 << 33,
    _L_34 = 1 << 34,
    _L_35 = 1 << 35,
    _L_36 = 1 << 36,
    _L_37 = 1 << 37,
    _L_38 = 1 << 38,
    _L_39 = 1 << 39,
    _L_40 = 1 << 40,
    _L_41 = 1 << 41,
    _L_42 = 1 << 42,
    _L_43 = 1 << 43,
    _L_44 = 1 << 44,
    _L_45 = 1 << 45,
    _L_46 = 1 << 46,
    _L_47 = 1 << 47,
    _L_48 = 1 << 48,
    _L_49 = 1 << 49,
    _L_50 = 1 << 50,
    _L_51 = 1 << 51,
    _L_52 = 1 << 52,
    _L_53 = 1 << 53,
    _L_54 = 1 << 54,
    _L_55 = 1 << 55,
    _L_56 = 1 << 56,
    _L_57 = 1 << 57,
    _L_58 = 1 << 58,
    _L_59 = 1 << 59,
    _L_60 = 1 << 60,
    _L_61 = 1 << 61,
    _L_62 = 1 << 62,
    _L_63 = 1 << 63,

    pub fn from_address(addr: usize) Alignment {
        return @enumFromInt(@as(u64, 1) << @as(math.Log2Int(u64), @intCast(@ctz(addr))));
    }
    pub fn from_pointer(ptr: anytype) Alignment {
        return @enumFromInt(@as(u64, 1) << @as(math.Log2Int(u64), @intCast(@ctz(@intFromPtr(ptr)))));
    }
    pub fn to_usize(self: Alignment) usize {
        return @intCast(@intFromEnum(self));
    }
    pub fn to_uint(self: Alignment, comptime T: type) T {
        return @intCast(@intFromEnum(self));
    }
    pub fn to_std_align(self: Alignment) std.mem.Alignment {
        const raw: usize = @intCast(@intFromEnum(self));
        const log2: math.Log2Int(usize) = @intCast(63 - @clz(raw));
        return @enumFromInt(log2);
    }
    pub fn from_uint(alignment: anytype) Alignment {
        return @enumFromInt(@as(u64, @intCast(alignment)));
    }
    pub fn from_std_align(alignment: std.mem.Alignment) Alignment {
        const log2: math.Log2Int(usize) = @intFromEnum(alignment);
        const raw: usize = @as(usize, 1) << log2;
        return @enumFromInt(@as(u64, @intCast(raw)));
    }
    pub fn from_type(comptime T: type) Alignment {
        return @enumFromInt(@as(u64, @alignOf(T)));
    }
    pub fn align_address_forward(self: Alignment, addr: anytype) @TypeOf(addr) {
        const T = @TypeOf(addr);
        const alignment: T = self.to_uint(T);
        return std.mem.alignForward(T, addr, alignment);
    }
    pub fn align_address_backward(self: Alignment, addr: anytype) @TypeOf(addr) {
        const T = @TypeOf(addr);
        const alignment: T = self.to_uint(T);
        return std.mem.alignBackward(T, addr, alignment);
    }
};

pub const Endian = enum(u8) {
    LITTLE = 0,
    BIG = 1,

    pub const NATIVE = if (build.cpu.arch.endian() == .little) Endian.LITTLE else Endian.BIG;
    pub fn to_zig(self: Endian) std.builtin.Endian {
        return switch (self) {
            .LITTLE => std.builtin.Endian.little,
            .BIG => std.builtin.Endian.big,
        };
    }
};

pub const AngleType = enum(u8) {
    RADIANS,
    DEGREES,
};

pub const FillRule = enum {
    NONZERO,
    EVEN,
    ODD,
    POSITIVE,
    NEGATIVE,

    pub fn should_be_filled(self: FillRule, sum_of_intersection_slopes: anytype) bool {
        return switch (self) {
            .NONZERO => sum_of_intersection_slopes != 0,
            .EVEN => sum_of_intersection_slopes & 1 == 1,
            .ODD => sum_of_intersection_slopes & 1 == 0,
            .POSITIVE => sum_of_intersection_slopes > 0,
            .NEGATIVE => sum_of_intersection_slopes < 0,
        };
    }
};

pub const ThreadingMode = enum(u8) {
    SINGLE_THREADED,
    MULTI_THREAD_SAFE,
};

pub const PerpendicularZero = enum(u8) {
    PERP_ZERO_IS_ZERO,
    PERP_ZERO_IS_LAST_COMPONENT_1,
};
pub const NormalizeZero = enum(u8) {
    NORM_ZERO_IS_ZERO,
    NORM_ZERO_IS_LAST_COMPONENT_1,
};
pub const Plane3D = enum(u8) {
    XY,
    YZ,
    XZ,
};

pub const PadForGpu = enum(u8) {
    NO_PADDING,
    PAD_FOR_GPU,
};

pub const RowColumnOrder = enum(u8) {
    ROW_MAJOR,
    COLUMN_MAJOR,
};

pub const ParamRefType = enum(u8) {
    VALUE,
    POINTER,
    CONST_POINTER,
};

pub const ShouldTranslate = enum(u8) {
    IGNORE_TRANSLATIONS,
    PREFORM_TRANSLATIONS,
};

pub const Bool32 = enum(u32) {
    FALSE = 0,
    TRUE = 1,
};

pub const IncludeOffests = enum(u8) {
    DO_NOT_INCLUDE_OFFSETS,
    INCLUDE_OFFSETS,
};

pub const ArchSize = enum(u8) {
    _32,
    _64,

    pub const THIS_SIZE: ArchSize = if (@sizeOf(usize) == 4) ._32 else ._64;
};

pub const WarningMode = enum(u8) {
    IGNORE,
    WARN,
    PANIC,
};
pub const ContinueMode = enum(u8) {
    CONTINUE,
    STOP,
};
pub const ContinueModeWithUnreachable = enum(u8) {
    CONTINUE,
    STOP,
    UNREACHABLE,
};
