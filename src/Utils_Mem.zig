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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
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
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;

const NON_SIMD_UNROLL_LEN: comptime_int = 8;
const NON_SIMD_UNROLL_LEN_BIT_SHIFT: comptime_int = 3;
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

pub const CopyLenKind = enum(u8) {
    ENTIRE_SOURCE_TO_DEST,
    LIMITED_BY_SMALLER_LEN,
    PROVIDE_LEN_EXACT,
    PROVIDE_LEN_MAX,
    PROVIDE_LEN_MIN,
};

pub const CopyLen = union(CopyLenKind) {
    ENTIRE_SOURCE_TO_DEST: void,
    LIMITED_BY_SMALLER_LEN: void,
    PROVIDE_LEN_EXACT: usize,
    PROVIDE_LEN_MAX: usize,
    PROVIDE_LEN_MIN: usize,

    pub fn copy_entire_source_to_dest() CopyLen {
        return CopyLen{ .SRC_DST_ALWAYS_SAME_SIZE = void{} };
    }
    pub fn copy_as_many_elements_as_possible_from_source_to_dest() CopyLen {
        return CopyLen{ .LIMITED_BY_SMALLER_LEN = void{} };
    }
    pub fn copy_exact_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_EXACT = count };
    }
    pub fn copy_at_most_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_MAX = count };
    }
    pub fn copy_at_least_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_MIN = count };
    }
};

inline fn single_memcopy_swap_as_integer(
    comptime UINT_TYPE: type,
    UINT_PTR: [*]UINT_TYPE,
    comptime DST_ELEM: type,
    DST_PTR: [*]DST_ELEM,
    comptime SRC_ELEM: type,
    SRC_PTR: [*]SRC_ELEM,
) void {
    const UINT_SIZE = @sizeOf(UINT_TYPE);
    const UINT_ALIGN = @alignOf(UINT_TYPE);
    const DST_SIZE = @sizeOf(DST_ELEM);
    const DST_ALIGN = @alignOf(DST_ELEM);
    const SRC_SIZE = @sizeOf(SRC_ELEM);
    const SRC_ALIGN = @alignOf(SRC_ELEM);
    if (SRC_ALIGN == UINT_ALIGN) {
        const src_uint_ptr: *const UINT_TYPE = @ptrCast(SRC_PTR);
        UINT_PTR.* = src_uint_ptr.*;
    } else {
        const src_bytes_ptr: *const [SRC_SIZE]u8 = @ptrCast(SRC_PTR);
        const uint_bytes_ptr: *[UINT_SIZE]u8 = @ptrCast(UINT_PTR);
        @memcpy(uint_bytes_ptr[0..UINT_SIZE], src_bytes_ptr[0..SRC_SIZE]);
    }
    UINT_PTR.* = @byteSwap(UINT_PTR.*);
    if (DST_ALIGN == UINT_ALIGN) {
        const dst_uint_ptr: *UINT_TYPE = @ptrCast(DST_PTR);
        dst_uint_ptr.* = UINT_PTR.*;
    } else {
        const dst_bytes_ptr: *[DST_SIZE]u8 = @ptrCast(DST_PTR);
        const uint_bytes_ptr: *const [UINT_SIZE]u8 = @ptrCast(UINT_PTR);
        @memcpy(dst_bytes_ptr[0..DST_SIZE], uint_bytes_ptr[0..UINT_SIZE]);
    }
}

pub fn memcopy_swap_order_typed(noalias dest: anytype, noalias source: anytype, comptime COPY_LEN: CopyLen) void {
    _ = memcopy_swap_order_typed_get_num_copied(dest, source, COPY_LEN);
}

pub fn memcopy_swap_order_typed_get_num_copied(noalias dest: anytype, noalias source: anytype, comptime COPY_LEN: CopyLen) usize {
    const DST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DST_INFO = KindInfo.get_kind_info(DST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    const DST_ELEM, const DST_ELEM_SIZE, const DST_LEN: ?usize, const DST_PTR, _ = switch (DST_INFO) {
        .POINTER => |POINTER| .{
            POINTER.child,
            @sizeOf(POINTER.child),
            switch (POINTER.size) {
                .one, .c => 1,
                .many => null,
                .slice => source.len,
            },
            switch (POINTER.size) {
                .one, .c, .many => @as([*]POINTER.child, @ptrCast(dest)),
                .slice => @as([*]POINTER.child, @ptrCast(dest.ptr)),
            },
            POINTER.alignment,
        },
        else => assert_unreachable(@src(), "only pointers are allowed for `dest` and `source`", .{}),
    };
    const SRC_ELEM, const SRC_ELEM_SIZE, const SRC_LEN: ?usize, const SRC_PTR, _ = switch (SRC_INFO) {
        .POINTER => |POINTER| .{
            POINTER.child,
            @sizeOf(POINTER.child),
            switch (POINTER.size) {
                .one, .c => 1,
                .many => null,
                .slice => source.len,
            },
            switch (POINTER.size) {
                .one, .c, .many => @as([*]POINTER.child, @ptrCast(source)),
                .slice => @as([*]POINTER.child, @ptrCast(source.ptr)),
            },
            POINTER.alignment,
        },
        else => assert_unreachable(@src(), "only pointers are allowed for `dest` and `source`", .{}),
    };
    assert_with_reason(SRC_ELEM_SIZE == DST_ELEM_SIZE, @src(), "the size of the dest element (size {d}, type {s}) does not match the size of the source element (size {d}, type {s})", .{ DST_ELEM_SIZE, @typeName(DST_ELEM), SRC_ELEM_SIZE, @typeName(SRC_ELEM) });
    var TRUE_LEN: usize = if (SRC_LEN == null and DST_LEN == null) switch (COPY_LEN) {
        .PROVIDE_LEN_EXACT => |EXACT| EXACT,
        .PROVIDE_LEN_MIN => |MIN| MIN,
        else => 1,
    } else if (SRC_LEN == null) DST_LEN.? else if (DST_LEN == null) SRC_LEN.? else get: {
        switch (COPY_LEN) {
            .ENTIRE_SOURCE_TO_DEST => {
                assert_with_reason(SRC_LEN.? == DST_LEN.?, @src(), "when both `source` and `dest` specify lengths and COPY_LEN == ENTIRE_SOURCE_TO_DEST, the lengths MUST be equal, got source len {d} != dest len {d}", .{ SRC_LEN.?, DST_LEN.? });
                break :get SRC_LEN.?;
            },
            else => {
                break :get @min(SRC_LEN.?, DST_LEN.?);
            },
        }
    };
    switch (COPY_LEN) {
        .PROVIDE_LEN_EXACT => |EXACT| {
            assert_with_reason(TRUE_LEN >= EXACT, @src(), "required to copy {d} elements, but only {d} elements can be copied", .{ EXACT, TRUE_LEN });
            TRUE_LEN = EXACT;
        },
        .PROVIDE_LEN_MAX => |MAX| {
            TRUE_LEN = @min(TRUE_LEN, MAX);
        },
        .PROVIDE_LEN_MIN => |MIN| {
            assert_with_reason(TRUE_LEN >= MIN, @src(), "required to copy at least {d} elements, but only {d} elements can be copied", .{ MIN, TRUE_LEN });
            TRUE_LEN = @max(TRUE_LEN, MIN);
        },
        else => {},
    }
    if (Types.TryUnsignedIntegerWithSameSize(DST_ELEM)) |UINT_TYPE| {
        var uint_unrolls: [NON_SIMD_UNROLL_LEN]UINT_TYPE = undefined;
        var i: usize = 0;
        const NUM_UNROLLS = TRUE_LEN >> NON_SIMD_UNROLL_LEN_BIT_SHIFT;
        const I_AFTER_UNROLLS = NUM_UNROLLS << NON_SIMD_UNROLL_LEN_BIT_SHIFT;
        while (i < I_AFTER_UNROLLS) : (i += NON_SIMD_UNROLL_LEN) {
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const local_uint_ptr: [*]UINT_TYPE = @ptrCast(&uint_unrolls[ii]);
                const local_src_ptr: [*]const SRC_ELEM = SRC_PTR + iii;
                const local_dst_ptr: [*]DST_ELEM = DST_PTR + iii;
                single_memcopy_swap_as_integer(UINT_TYPE, local_uint_ptr, DST_ELEM, local_dst_ptr, SRC_ELEM, local_src_ptr);
            }
        }
        var ii: usize = 0;
        while (i < TRUE_LEN) : ({
            i += 1;
            ii += 1;
        }) {
            const local_uint_ptr: [*]UINT_TYPE = @ptrCast(&uint_unrolls[ii]);
            const local_src_ptr: [*]const SRC_ELEM = SRC_PTR + i;
            const local_dst_ptr: [*]DST_ELEM = DST_PTR + i;
            single_memcopy_swap_as_integer(UINT_TYPE, local_uint_ptr, DST_ELEM, local_dst_ptr, SRC_ELEM, local_src_ptr);
        }
    } else {}
}

pub fn memcopy_swap_order_builtin_any(comptime TYPE: type, noalias dest: *align(@alignOf(TYPE)) [@sizeOf(TYPE)]u8, noalias source: *align(@alignOf(TYPE)) const [@sizeOf(TYPE)]u8) void {
    @memcpy(dest, source);
    const UINT_TYPE = Types.UnsignedIntegerWithSameSize(TYPE);
    const dest_int: *UINT_TYPE = @ptrCast(dest);
    dest_int.* = @byteSwap(dest_int.*);
}

fn get_real_dest_src(byte_len: anytype, dest: anytype, comptime source: anytype) struct { []u8, []const u8 } {
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
    return .{ real_dest, real_src };
}

pub fn memcopy_exact_byte_len(byte_len: anytype, noalias dest: anytype, noalias source: anytype) []u8 {
    const real_dest: []u8, const real_src: []const u8 = get_real_dest_src(byte_len, dest, source);
    @memcpy(real_dest[0..byte_len], real_src[0..byte_len]);
}

pub fn memcopy_while_reversing_order(noalias dest: anytype, noalias source: anytype) void {
    const DST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DST_INFO = KindInfo.get_kind_info(DST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    assert_with_reason(DST_INFO.has_indexable_child_that_matches(SRC_INFO), @src(), "type of `dest` `{s}` and type of `source` `{s}` do not have matching indexable child types (or one of them is not indexable)", .{ @typeName(DST), @typeName(SRC) });
    assert_with_reason(DST_INFO.is_pointer() and SRC_INFO.is_pointer() and DST_INFO.POINTER.is_const == false, @src(), "both `dest` and `source` must be pointer types that can be indexed, and `dest` must not be const, got invalid dest `{s}` or source `{s}`", .{ @typeName(DST), @typeName(SRC) });
    assert_with_reason(DST_INFO.has_len() or SRC_INFO.has_len(), @src(), "either `dest` or `source` must have a defined `len` (either be an array, vector, or slice)", .{});
    if (DST_INFO.has_len() and SRC_INFO.has_len()) {
        const dest_len = DST_INFO.get_len(dest);
        const source_len = SRC_INFO.get_len(source);
        assert_with_reason(dest_len == source_len, @src(), "dest len {d} does not match source len {d}", .{ dest_len, source_len });
    }
    const CHILD = DST_INFO.indexed_child_type();
    const len = if (DST_INFO.has_len()) DST_INFO.get_len(dest) else SRC_INFO.get_len(source);
    const last = len - 1;
    if (len <= NON_SIMD_UNROLL_LEN) {
        switch (len) {
            inline 0...NON_SIMD_UNROLL_LEN => |LEN| {
                inline for (0..LEN) |i| {
                    dest[i] = source[last - i];
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime()) {
            if (std.simd.suggestVectorLength(CHILD)) |SIMD_SIZE| {
                if (SIMD_SIZE <= len) {
                    const SIMD_END = len - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const dest_chunk = dest[i .. i + SIMD_SIZE];
                        const src_chunk = source[len - i - SIMD_SIZE .. len - i];
                        const src_reversed: [SIMD_SIZE]CHILD = reverse_vector_slice(SIMD_SIZE, CHILD, src_chunk);
                        @memcpy(dest_chunk, &src_reversed);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > len) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                dest[iii] = source[last - iii];
            }
            i = next_i;
        }
        while (i < len) : (i += 1) {
            dest[i] = source[last - i];
        }
    }
}

pub fn memcopy_from_reader_while_reversing_order(dest: anytype, source: *std.Io.Reader) std.Io.Reader.Error!void {
    const DST = @TypeOf(dest);
    const DST_INFO = KindInfo.get_kind_info(DST);
    assert_with_reason(DST_INFO.has_indexable_child_type(u8), @src(), "type of `dest` `{s}` must have an indexable child type of `u8`", .{@typeName(DST)});
    assert_with_reason(DST_INFO.is_pointer() and DST_INFO.POINTER.is_const == false, @src(), "`dest` must be a pointer type that can be indexed, and must not be const, got invalid dest `{s}`", .{@typeName(DST)});
    assert_with_reason(DST_INFO.has_len(), @src(), "`dest` must have a defined `len` (either be an array, vector, or slice)", .{});
    const len = DST_INFO.get_len(dest);
    const last = len - 1;
    var i: usize = 0;
    var byte: [1]u8 = undefined;
    while (i < len) : (i += 1) {
        try source.readSliceAll(byte[0..1]);
        dest[last - i] = byte[0];
    }
}

pub fn memcopy_to_writer_while_reversing_order(dest: *std.Io.Writer, source: anytype) std.Io.Writer.Error!void {
    const SRC = @TypeOf(source);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    assert_with_reason(SRC_INFO.has_indexable_child_type(u8), @src(), "type of `source` `{s}` must have an indexable child type of `u8`", .{@typeName(SRC)});
    assert_with_reason(SRC_INFO.is_pointer(), @src(), "`source` must be a pointer type that can be indexed, got invalid source `{s}`", .{@typeName(SRC)});
    assert_with_reason(SRC_INFO.has_len(), @src(), "`source` must have a defined `len` (either be an array, vector, or slice)", .{});
    const len = SRC_INFO.get_len(source);
    const last = len - 1;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try dest.writeByte(source[last - i]);
    }
}

pub fn copy_arbitrary_length_bytes_in_native_endian_to_typed_pointer(comptime DEST_T: type, noalias dest: *DEST_T, noalias source: []const u8) void {
    const DEST_LEN = @sizeOf(DEST_T);
    assert_with_reason(source.len <= DEST_LEN, @src(), "source bytes (len {d}) are larger than dest pointer child size ({d})", .{ source.len, DEST_LEN });
    const dest_bytes: [*]u8 = @ptrCast(dest);
    const len_diff = DEST_LEN - source.len;
    const copy_start = if (Endian.native_is_little_endian()) 0 else len_diff;
    const copy_end = if (Endian.native_is_little_endian()) source.len else DEST_LEN;
    const zero_start = if (Endian.native_is_little_endian()) source.len else 0;
    const zero_end = if (Endian.native_is_little_endian()) DEST_LEN else len_diff;
    @memset(dest_bytes[zero_start..zero_end], 0);
    @memcpy(dest_bytes[copy_start..copy_end], source);
}
