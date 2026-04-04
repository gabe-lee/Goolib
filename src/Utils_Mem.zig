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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.object_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;

const NON_SIMD_UNROLL_LEN: comptime_int = 8;
const USIZE_SIZE: comptime_int = @sizeOf(usize);

/// This should match `std.mem.use_vectors`
pub const use_vectors = switch (build.zig_backend) {
    // These backends don't support vectors yet.
    .stage2_aarch64,
    .stage2_powerpc,
    .stage2_riscv64,
    => false,
    // The SPIR-V backend does not support the optimized path yet.
    .stage2_spirv => false,
    else => true,
};

/// This should match `std.mem.reverseVector`
inline fn reverse_vector_slice(comptime N: usize, comptime T: type, a: []T) [N]T {
    var res: [N]T = undefined;
    inline for (0..N) |i| {
        res[i] = a[N - i - 1];
    }
    return res;
}

pub fn reverse_array(arr_ptr: anytype) void {
    const T = @TypeOf(arr_ptr);
    const INFO = KindInfo.get_kind_info(T);
    assert_with_reason(INFO == .POINTER and INFO.POINTER.size == .one and INFO.POINTER.is_const == false, @src(), "`arr_ptr` must be a mutable pointer to an array, got type `{s}`", .{@typeName(T)});
    const PTR_CHILD = INFO.POINTER.child;
    const CHILD_INFO = KindInfo.get_kind_info(PTR_CHILD);
    assert_with_reason(CHILD_INFO == .ARRAY, @src(), "`arr_ptr` must be a mutable pointer to an array, got type `{s}`", .{@typeName(T)});
    const ARR_INFO = CHILD_INFO.ARRAY;
    const TT = ARR_INFO.child;
    const LEN = ARR_INFO.len;
    const LAST = LEN - 1;
    const HALF = LEN >> 1;
    if (HALF <= NON_SIMD_UNROLL_LEN) {
        inline for (0..HALF) |i| {
            const tmp = arr_ptr[i];
            arr_ptr[i] = arr_ptr[LAST - i];
            arr_ptr[LAST - i] = tmp;
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime() and @bitSizeOf(TT) > 0 and std.math.isPowerOfTwo(@bitSizeOf(TT))) {
            if (std.simd.suggestVectorLength(T)) |SIMD_SIZE| {
                if (SIMD_SIZE <= HALF) {
                    const SIMD_END = HALF - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const left_slice = arr_ptr[i .. i + SIMD_SIZE];
                        const right_slice = arr_ptr[LEN - i - SIMD_SIZE .. LEN - i];

                        const left_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, left_slice);
                        const right_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, right_slice);

                        @memcpy(right_slice, &left_shuffled);
                        @memcpy(left_slice, &right_shuffled);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > HALF) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const tmp = arr_ptr[iii];
                arr_ptr[iii] = arr_ptr[LAST - iii];
                arr_ptr[LAST - iii] = tmp;
            }
            i = next_i;
        }
        while (i < HALF) : (i += 1) {
            const tmp = arr_ptr[i];
            arr_ptr[i] = arr_ptr[LAST - i];
            arr_ptr[LAST - i] = tmp;
        }
    }
}

pub fn reverse_slice(slice: anytype) void {
    const T = @TypeOf(slice);
    const INFO = KindInfo.get_kind_info(T);
    assert_with_reason(INFO == .POINTER and INFO.POINTER.size == .slice and INFO.POINTER.is_const == false, @src(), "`slice` must be a mutable pointer to a slice, got type `{s}`", .{@typeName(T)});
    const SLICE = INFO.POINTER;
    const TT = SLICE.child;
    const len = slice.len;
    const last = len - 1;
    const half = len >> 1;
    if (half <= NON_SIMD_UNROLL_LEN) {
        switch (half) {
            inline 0...NON_SIMD_UNROLL_LEN => |HALF| {
                inline for (0..HALF) |i| {
                    const tmp = slice[i];
                    slice[i] = slice[last - i];
                    slice[last - i] = tmp;
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime() and @bitSizeOf(TT) > 0 and std.math.isPowerOfTwo(@bitSizeOf(TT))) {
            if (std.simd.suggestVectorLength(T)) |SIMD_SIZE| {
                if (SIMD_SIZE <= half) {
                    const SIMD_END = half - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const left_slice = slice[i .. i + SIMD_SIZE];
                        const right_slice = slice[len - i - SIMD_SIZE .. len - i];
                        const left_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, left_slice);
                        const right_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, right_slice);
                        @memcpy(right_slice, &left_shuffled);
                        @memcpy(left_slice, &right_shuffled);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > half) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const tmp = slice[iii];
                slice[iii] = slice[last - iii];
                slice[last - iii] = tmp;
            }
            i = next_i;
        }
        while (i < half) : (i += 1) {
            const tmp = slice[i];
            slice[i] = slice[last - i];
            slice[last - i] = tmp;
        }
    }
}

pub fn array_or_slice_equal(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const A_INFO = KindInfo.get_kind_info(A);
    const B_INFO = KindInfo.get_kind_info(B);
    assert_with_reason(A_INFO.has_indexable_child_that_matches(B_INFO), @src(), "type of `a` `{s}` and type of `b` `{s}` do not have matching indexable child types (or one of them is not indexable)", .{ @typeName(A), @typeName(B) });
    assert_with_reason(A_INFO.has_len(), @src(), "`a` must have a defined `len` (either be an array, vector, or slice)", .{});
    assert_with_reason(B_INFO.has_len(), @src(), "`b` must have a defined `len` (either be an array, vector, or slice)", .{});
    if (a.len != b.len) return false;
    const LEN = if (A_INFO == .ARRAY or A_INFO == .VECTOR) a.len else b.len;
    if (LEN <= NON_SIMD_UNROLL_LEN) {
        switch (LEN) {
            inline 0...NON_SIMD_UNROLL_LEN => |LEN_2| {
                inline for (0..LEN_2) |i| {
                    if (!object_equals(a[i], b[i])) return false;
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        const ELEM = A_INFO.indexed_child_type();
        const ELEM_INFO = KindInfo.get_kind_info(ELEM);
        if (use_vectors and !@inComptime() and ELEM_INFO.has_impicit_equals()) {
            if (std.simd.suggestVectorLength(ELEM)) |SIMD_SIZE| {
                while (true) {
                    const next_i = i + SIMD_SIZE;
                    if (next_i > LEN) break;
                    const a_vec_ptr: *const @Vector(SIMD_SIZE, ELEM) = @ptrCast(&a[i]);
                    const b_vec_ptr: *const @Vector(SIMD_SIZE, ELEM) = @ptrCast(&b[i]);
                    const a_vec = a_vec_ptr.*;
                    const b_vec = b_vec_ptr.*;
                    if (@reduce(.Or, a_vec != b_vec)) return false;
                    i = next_i;
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > LEN) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                if (!object_equals(a[iii], b[iii])) return false;
            }
            i = next_i;
        }
        while (i < LEN) : (i += 1) {
            if (!object_equals(a[i], b[i])) return false;
        }
    }
    return true;
}

fn CopyPtrAttrs(
    comptime source: type,
    comptime size: std.builtin.Type.Pointer.Size,
    comptime child: type,
) type {
    const info = @typeInfo(source).pointer;
    return @Type(.{
        .pointer = .{
            .size = size,
            .is_const = info.is_const,
            .is_volatile = info.is_volatile,
            .is_allowzero = info.is_allowzero,
            .alignment = info.alignment,
            .address_space = info.address_space,
            .child = child,
            .sentinel_ptr = null,
        },
    });
}

fn PtrAsBytes(comptime PTR: type) type {
    const pointer = @typeInfo(PTR).pointer;
    switch (pointer.size) {
        .one, .c, .many => {
            const size = @sizeOf(pointer.child);
            return CopyPtrAttrs(PTR, .one, [size]u8);
        },
        .slice => {
            return CopyPtrAttrs(PTR, .slice, u8);
        },
    }
}

/// Given a pointer to a single item or slice, returns a slice of the underlying bytes, preserving pointer attributes.
///
/// As a special case, a many-item pointer is interpeted as a single-item pointer
pub fn ptr_as_bytes(ptr: anytype) PtrAsBytes(@TypeOf(ptr)) {
    const PTR = @typeInfo(@TypeOf(ptr)).pointer;
    switch (PTR.size) {
        .one, .c, .many => return @ptrCast(@alignCast(ptr)),
        .slice => {
            const ptr_adjust: CopyPtrAttrs(PTR, .many, u8) = @ptrCast(@alignCast(ptr.ptr));
            const size = @sizeOf(PTR.child) * ptr.len;
            return ptr_adjust[0..size];
        },
    }
}

// const HAS_MOVEBE = build.cpu.has(.x86, std.Target.x86.Feature.movbe);

// fn movebe()

pub fn memcopy_swap_order(byte_len: anytype, noalias dest: anytype, noalias source: anytype) void {
    const real_dest = memcopy_get_dest(byte_len, dest, source);
    reverse_slice(real_dest);
}

pub fn memcopy_swap_order_int(comptime TYPE: type, noalias dest: *align(@alignOf(TYPE)) [@sizeOf(TYPE)]u8, noalias source: *align(@alignOf(TYPE)) const [@sizeOf(TYPE)]u8) void {
    @memcpy(dest, source);
    const UINT_TYPE = Types.UnsignedIntegerWithSameSize(TYPE);
    const dest_int: *UINT_TYPE = @ptrCast(dest);
    dest_int.* = @byteSwap(dest_int.*);
}

fn memcopy_get_dest(byte_len: anytype, noalias dest: anytype, noalias source: anytype) []u8 {
    const DEST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DEST_INFO = KindInfo.get_kind_info(DEST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    const real_dest: []u8 = switch (DEST_INFO) {
        .POINTER => |POINTER| switch (POINTER.size) {
            .one, .c, .many => @as([*]u8, @ptrCast(dest))[0..byte_len],
            .slice => @as([*]u8, @ptrCast(dest.ptr))[0..byte_len],
        },
        .OPTIONAL => |OPTIONAL| check_non_null: {
            assert_with_reason(dest != null, @src(), "cannot copy to a null destination", .{});
            break :check_non_null switch (KindInfo.get_kind_info(OPTIONAL.child)) {
                .POINTER => |POINTER| switch (POINTER.size) {
                    .one, .c, .many => @as([*]u8, @ptrCast(dest.?))[0..byte_len],
                    .slice => @as([*]u8, @ptrCast(dest.?.ptr))[0..byte_len],
                },
                else => assert_unreachable(@src(), "dest must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
            };
        },
        else => assert_unreachable(@src(), "dest must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
    };
    const real_src: []const u8 = switch (SRC_INFO) {
        .POINTER => |POINTER| switch (POINTER.size) {
            .one, .c, .many => @as([*]u8, @ptrCast(source))[0..byte_len],
            .slice => @as([*]u8, @ptrCast(source.ptr))[0..byte_len],
        },
        .OPTIONAL => |OPTIONAL| check_non_null: {
            assert_with_reason(source != null, @src(), "cannot copy from a null source", .{});
            break :check_non_null switch (KindInfo.get_kind_info(OPTIONAL.child)) {
                .POINTER => |POINTER| switch (POINTER.size) {
                    .one, .c, .many => @as([*]u8, @ptrCast(source.?))[0..byte_len],
                    .slice => @as([*]u8, @ptrCast(source.?.ptr))[0..byte_len],
                },
                else => assert_unreachable(@src(), "source must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
            };
        },
        else => assert_unreachable(@src(), "source must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
    };
    @memcpy(real_dest[0..byte_len], real_src[0..byte_len]);
}

pub fn memcopy(byte_len: anytype, noalias dest: anytype, noalias source: anytype) void {
    _ = memcopy_get_dest(byte_len, dest, source);
}
