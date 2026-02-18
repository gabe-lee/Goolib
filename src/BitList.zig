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
const Types = Root.Types;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;

const num_cast = Root.Cast.num_cast;

const List = Root.IList.List;

const TrueIndex = struct {
    block_index: usize,
    bit_offset: math.Log2Int(usize),
};

pub fn BitList(comptime BITS_PER_INDEX: comptime_int) type {
    Assert.assert_with_reason(BITS_PER_INDEX <= @bitSizeOf(usize), @src(), "`BITS_PER_INDEX` must be less than or equal to the number of bits in a `usize`, got {d} > {d}", .{ BITS_PER_INDEX, @bitSizeOf(usize) });
    return struct {
        const Self = @This();

        list: List(usize) = .{},

        pub const BITS = std.meta.Int(.unsigned, BITS_PER_INDEX);
        const USIZEBITS = @bitSizeOf(usize);
        const EVENLY_DIVISIBLE = USIZEBITS % BITS_PER_INDEX == 0;
        const OFFSHIFT = if (USIZEBITS == 32) 5 else 6;
        const OFFMASK = (1 << OFFSHIFT) - 1;
        const BITMASK = (@as(usize, 1) << BITS_PER_INDEX) - 1;

        fn block_offset(idx: usize) TrueIndex {
            var out: TrueIndex = undefined;
            const bit_idx = idx * BITS_PER_INDEX;
            out.block_index = bit_idx >> OFFSHIFT;
            out.bit_offset = bit_idx & OFFMASK;
            return out;
        }

        pub fn get(self: Self, idx: usize) BITS {
            const index = block_offset(idx);
            if (EVENLY_DIVISIBLE) {
                var value = self.list.ptr[index.block_index];
                value >>= index.bit_offset;
                value &= BITMASK;
                return @intCast(value);
            } else {
                var value = self.list.ptr[index.block_index];
                value >>= index.bit_offset;
                var value_2 = self.list.ptr[index.block_index + 1];
                const offset_2: math.Log2Int(usize) = num_cast((USIZEBITS - 1) - num_cast(index.bit_offset, usize), math.Log2Int(usize));
                value_2 <<= offset_2;
                value_2 <<= 1;
                value |= value_2;
                value &= BITMASK;
                return @intCast(value);
            }
        }

        pub fn set(self: Self, idx: usize, val: BITS) void {
            const index = block_offset(idx);
            if (EVENLY_DIVISIBLE) {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                const mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index] = value;
            } else {
                var block = self.list.ptr[index.block_index];
                var value: usize = @intCast(val);
                var mask = BITMASK << index.bit_offset;
                value <<= index.bit_offset;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index] = value;
                const offset_2: math.Log2Int(usize) = num_cast((USIZEBITS - 1) - num_cast(index.bit_offset, usize), math.Log2Int(usize));
                block = self.list.ptr[index.block_index + 1];
                value = @intCast(val);
                mask = BITMASK >> offset_2;
                mask >>= 1;
                value >>= offset_2;
                value >>= 1;
                block &= ~mask;
                block |= value;
                self.list.ptr[index.block_index + 1] = value;
            }
        }

        pub fn ensure_capacity_and_zero_new(self: *Self, cap: usize, alloc: Allocator) void {
            const old_cap = self.list.cap;
            const index = block_offset(cap - 1);
            const real_cap = if (EVENLY_DIVISIBLE) index.block_index + 1 else index.block_index + 2;
            self.list.ensure_free_slots(real_cap, alloc);
            const new_cap = self.list.cap;
            @memset(self.list.ptr[old_cap..new_cap], 0);
        }
    };
}
