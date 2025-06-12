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
const mem = std.mem;
const Endian = std.builtin.Endian;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const Iterator = Root.Iterator.Iterator;
const IterCaps = Root.Iterator.IteratorCapabilities;

pub const NATIVE_ENDIAN = build.cpu.arch.endian();

pub const SrcDst = struct {
    src: [*]const u8,
    dst: [*]u8,

    pub inline fn advance(self: SrcDst, src_adv: usize, dst_adv: usize) SrcDst {
        return SrcDst{
            .src = self.src + src_adv,
            .dst = self.dst + dst_adv,
        };
    }
    pub inline fn advance_src(self: SrcDst, src_adv: usize) SrcDst {
        return SrcDst{
            .src = self.src + src_adv,
            .dst = self.dst,
        };
    }
    pub inline fn advance_dst(self: SrcDst, dst_adv: usize) SrcDst {
        return SrcDst{
            .src = self.src,
            .dst = self.dst + dst_adv,
        };
    }
};

/// This function unconditionally coerces the source pointer/slice `src`
/// and destination ptr/slice `dst` to `[*]u8` pointers
///
/// It performs NO safety checks or assertions except that
/// `src` and `dst` must be pointer/slice types
pub fn coerce_src_dst(src: anytype, dst: anytype) SrcDst {
    const S = @TypeOf(src);
    const SI = @typeInfo(S);
    const D = @TypeOf(dst);
    const DI = @typeInfo(D);
    const src_ptr: [*]const u8 = switch (SI) {
        .pointer => |SPI| switch (SPI.size) {
            .one, .c, .many => @ptrFromInt(@intFromPtr(src)),
            .slice => @ptrFromInt(@intFromPtr(src.ptr)),
        },
        else => assert_with_reason(false, @src(), "`src` must be a pointer or slice type, got {s}", .{@typeName(S)}),
    };
    const dst_ptr: [*]u8 = switch (DI) {
        .pointer => |DPI| switch (DPI.size) {
            .one, .c, .many => @ptrFromInt(@intFromPtr(dst)),
            .slice => @ptrFromInt(@intFromPtr(dst.ptr)),
        },
        else => assert_with_reason(false, @src(), "`dst` must be a pointer or slice type, got {s}", .{@typeName(D)}),
    };
    return SrcDst{
        .dst = dst_ptr,
        .src = src_ptr,
    };
}

/// This function unconditionally coerces the source pointer/slice `src`
/// and destination ptr/slice `dst` to `[*]u8` pointers,
/// and writes `byte_count` bytes from `src`  into `dst`,
/// while optionally swapping endianess.
///
/// It performs NO safety checks or assertions except that
/// `src` and `dst` must be pointer/slice types
pub inline fn raw_write(src: anytype, dst: anytype, byte_count: usize, swap_endian: bool) void {
    const ptrs = coerce_src_dst(src, dst);
    raw_write_internal(ptrs, byte_count, swap_endian);
}

fn raw_write_internal(ptrs: SrcDst, byte_count: usize, swap_endian: bool) void {
    if (swap_endian) {
        var s: usize = 0;
        var d: usize = byte_count - 1;
        inline while (s < byte_count) {
            ptrs.dst[d] = ptrs.src[s];
            s += 1;
            d -= 1;
        }
    } else {
        @memcpy(ptrs.dst[0..byte_count], ptrs.src[0..byte_count]);
    }
}

pub inline fn copy_8(src: anytype, dst: anytype) void {
    raw_write(src, dst, 1, false);
}
pub inline fn copy_8_N(src: anytype, dst: anytype, count: usize) void {
    raw_write(src, dst, count, false);
}
pub inline fn copy_8_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize) void {
    var ptrs = coerce_src_dst(src, dst);
    ptrs = ptrs.advance(src_offset, dst_offset);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 1, false);
        ptrs.advance(src_stride, dst_stride);
    }
}

pub inline fn copy_16(src: anytype, dst: anytype, swap_endian: bool) void {
    raw_write(src, dst, 2, swap_endian);
}
pub inline fn copy_16_N(src: anytype, dst: anytype, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 2, swap_endian);
        ptrs.advance(2, 2);
    }
}
pub inline fn copy_16_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    ptrs = ptrs.advance(src_offset, dst_offset);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 2, swap_endian);
        ptrs.advance(src_stride, dst_stride);
    }
}

pub inline fn copy_32(src: anytype, dst: anytype, swap_endian: bool) void {
    raw_write(src, dst, 4, swap_endian);
}
pub inline fn copy_32_N(src: anytype, dst: anytype, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 4, swap_endian);
        ptrs.advance(4, 4);
    }
}
pub inline fn copy_32_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    ptrs = ptrs.advance(src_offset, dst_offset);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 4, swap_endian);
        ptrs.advance(src_stride, dst_stride);
    }
}

pub inline fn copy_64(src: anytype, dst: anytype, swap_endian: bool) void {
    raw_write(src, dst, 8, swap_endian);
}
pub inline fn copy_64_N(src: anytype, dst: anytype, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 8, swap_endian);
        ptrs.advance(8, 8);
    }
}
pub inline fn copy_64_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    ptrs = ptrs.advance(src_offset, dst_offset);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 8, swap_endian);
        ptrs.advance(src_stride, dst_stride);
    }
}

pub inline fn copy_128(src: anytype, dst: anytype, swap_endian: bool) void {
    raw_write(src, dst, 16, swap_endian);
}
pub inline fn copy_128_N(src: anytype, dst: anytype, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 16, swap_endian);
        ptrs.advance(16, 16);
    }
}
pub inline fn copy_128_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize, swap_endian: bool) void {
    var ptrs = coerce_src_dst(src, dst);
    ptrs = ptrs.advance(src_offset, dst_offset);
    var c: usize = 0;
    while (c < count) : (c += 1) {
        raw_write_internal(ptrs, 16, swap_endian);
        ptrs.advance(src_stride, dst_stride);
    }
}

pub fn CopyElementPkg(comptime element_size: usize) type {
    return struct {
        pub inline fn copy(src: anytype, dst: anytype, swap_endian: bool) void {
            raw_write(src, dst, element_size, swap_endian);
        }
        pub inline fn copy_N(src: anytype, dst: anytype, count: usize, swap_endian: bool) void {
            var ptrs = coerce_src_dst(src, dst);
            var c: usize = 0;
            while (c < count) : (c += 1) {
                raw_write_internal(ptrs, element_size, swap_endian);
                ptrs.advance(element_size, element_size);
            }
        }
        pub inline fn copy_N_sparse(src: anytype, src_offset: usize, src_stride: usize, dst: anytype, dst_offset: usize, dst_stride: usize, count: usize, swap_endian: bool) void {
            var ptrs = coerce_src_dst(src, dst);
            ptrs = ptrs.advance(src_offset, dst_offset);
            var c: usize = 0;
            while (c < count) : (c += 1) {
                raw_write_internal(ptrs, element_size, swap_endian);
                ptrs.advance(src_stride, dst_stride);
            }
        }
    };
}

pub fn CopyOperation(comptime element_size: usize, comptime count: usize, comptime src_offset: usize, comptime src_stride: usize, comptime dst_offset: usize, comptime dst_stride: usize, comptime swap_endian: bool) type {
    return struct {
        pub fn copy(src: anytype, dst: anytype) void {
            var ptrs = coerce_src_dst(src, dst);
            ptrs = ptrs.advance(src_offset, dst_offset);
            var c: usize = 0;
            while (c < count) : (c += 1) {
                raw_write_internal(ptrs, element_size, swap_endian);
                ptrs.advance(src_stride, dst_stride);
            }
        }
    };
}

pub fn CompactSparseBytes(comptime OFFSET: type) type {
    return struct {
        source_ptr: [*]u8,
        offsets: []OFFSET,

        const Self = @This();

        const VTABLE = Iterator(u8).VTable{
            .reset = iter_noop,
            .advance_next = iter_adv_next,
            .peek_next_or_null = iter_adv_next,
            .advance_prev = iter_noop,
            .peek_prev_or_null = iter_noop_ptr,
            .capabilities = iter_caps,
            .load_state = iter_load_save,
            .save_state = iter_load_save,
        };

        fn iter_noop(self_opaque: *anyopaque) bool {
            _ = self_opaque;
            return false;
        }
        fn iter_noop_ptr(self_opaque: *anyopaque) ?*u8 {
            _ = self_opaque;
            return null;
        }
        fn iter_adv_next(self_opaque: *anyopaque) bool {
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            if (self.offsets.len == 0) return false;
            self.offsets.ptr += 1;
            self.offsets.len -= 1;
            return true;
        }
        fn iter_peek_next(self_opaque: *anyopaque) ?*u8 {
            const self: *Self = @ptrCast(@alignCast(self_opaque));
            if (self.offsets.len == 0) return null;
            const base_addr: usize = @intFromPtr(self.source_ptr);
            const offset: usize = @intCast(self.offsets[0]);
            return @ptrFromInt(base_addr + offset);
        }
        fn iter_caps() IterCaps {
            return IterCaps.from_flag(.FORWARD);
        }
        fn iter_load_save(self_opaque: *anyopaque, slot: usize) bool {
            _ = slot;
            _ = self_opaque;
            return false;
        }

        pub fn iterator(self: *Self) Iterator(u8) {
            return Iterator(u8){
                .implementor = @ptrCast(self),
                .vtable = &VTABLE,
            };
        }
    };
}

pub const CompactSparseBytesMicro = CompactSparseBytes(u8);
pub const CompactSparseBytesSmall = CompactSparseBytes(u16);
pub const CompactSparseBytesMedium = CompactSparseBytes(u32);
