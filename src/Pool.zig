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
const math = std.math;
const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

const assert_with_reason = Assert.assert_with_reason;
const assert_allocation_failure = Assert.assert_allocation_failure;
const num_cast = Root.Cast.num_cast;

const List = Root.IList_List.List;

pub fn Pool(comptime T: type, comptime T_DEFAULT: T, comptime IDX_TYPE: type, comptime BLOCK_SIZE: comptime_int, comptime THREADING: Root.CommonTypes.ThreadingMode) type {
    assert_with_reason(Types.type_is_unsigned_int(IDX_TYPE), @src(), "type `IDX_TYPE` must be an unsigned integer type, got type `{s}`", .{@typeName(IDX_TYPE)});
    return struct {
        const Self = @This();

        const NEEDS_LOCK = THREADING == .MULTI_THREAD_SAFE;

        blocks: List(BlockPtr) = .{},
        alloc: Allocator,
        block_with_unused: u32 = 0,
        next_unused_idx_in_block: u32 = 0,
        first_free: IDX_TYPE = 0,
        free_count: IDX_TYPE = 0,
        lock: if (NEEDS_LOCK) std.Thread.Mutex else void = if (NEEDS_LOCK) std.Thread.Mutex{} else void{},

        pub const Slot = union {
            item: T,
            next_free: IDX_TYPE,
        };

        pub const BlockPtr = *[BLOCK_SIZE]Slot;
        pub const Block = [BLOCK_SIZE]Slot;
        // pub const ITEM_PTR_OFFSET_FROM_SLOT = @offsetOf(Slot, "item");

        pub fn init_empty(alloc: Allocator) Self {
            return Self{
                .blocks = List(BlockPtr).init_empty(),
                .alloc = alloc,
            };
        }

        pub fn init_cap(cap: usize, alloc: Allocator) Self {
            var real_cap = cap / BLOCK_SIZE;
            if (real_cap * BLOCK_SIZE < cap) real_cap += 1;
            var self = Self{
                .blocks = List(BlockPtr).init_capacity(real_cap, alloc),
                .alloc = alloc,
            };
            self.blocks.len = @intCast(real_cap);
            for (self.blocks.slice()) |*block| {
                block.* = alloc.create(Block) catch |err| assert_allocation_failure(@src(), Block, 1, err);
            }
            return self;
        }

        pub fn claim(self: *Self) *T {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            if (self.free_count > 0) {
                const first_free_idx = self.first_free;
                const first_free_idx_block = first_free_idx / BLOCK_SIZE;
                const first_free_idx_sub_idx = first_free_idx % BLOCK_SIZE;
                var slot_ptr: *Slot = &self.blocks.ptr[first_free_idx_block][first_free_idx_sub_idx];
                const next_free_idx = slot_ptr.next_free;
                self.first_free = next_free_idx;
                self.free_count -= 1;
                slot_ptr.* = Slot{ .item = T_DEFAULT };
                if (NEEDS_LOCK) {
                    self.lock.unlock();
                }
                return &slot_ptr.item;
            }
            if (self.block_with_unused >= self.blocks.len) {
                const new_block = self.alloc.create(Block) catch |err| assert_allocation_failure(@src(), Block, 1, err);
                _ = self.blocks.append(new_block, self.alloc);
            }
            var slot_ptr: *Slot = &self.blocks.ptr[self.block_with_unused][self.next_unused_idx_in_block];
            self.next_unused_idx_in_block += 1;
            if (self.next_unused_idx_in_block >= BLOCK_SIZE) {
                self.block_with_unused += 1;
                self.next_unused_idx_in_block = 0;
            }
            slot_ptr.* = Slot{ .item = T_DEFAULT };
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
            return &slot_ptr.item;
        }

        pub fn release(self: *Self, ptr: *T) void {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            const slot_addr = @intFromPtr(ptr);
            for (self.blocks.slice(), 0..) |block, block_idx| {
                const block_addr = @intFromPtr(block);
                const block_addr_limit = block_addr + @sizeOf(Block);
                if (slot_addr >= block_addr and slot_addr < block_addr_limit) {
                    const idx_delta = slot_addr - block_addr;
                    const sub_idx = idx_delta / @sizeOf(Slot);
                    const free_idx = num_cast((block_idx * BLOCK_SIZE) + sub_idx, IDX_TYPE);
                    block[sub_idx] = Slot{ .next_free = self.first_free };
                    self.first_free = free_idx;
                    self.free_count += 1;
                    if (NEEDS_LOCK) {
                        self.lock.unlock();
                    }
                    return;
                }
            }
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
        }

        pub fn clear_retain_blocks(self: *Self) void {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            self.block_with_unused = 0;
            self.next_unused_idx_in_block = 0;
            self.first_free = 0;
            self.free_count = 0;
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
        }

        pub fn clear_and_free_blocks(self: *Self) void {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            self.clear_retain_blocks();
            for (self.blocks.slice()) |block| {
                self.alloc.destroy(block);
            }
            self.blocks.clear();
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
        }

        pub fn free_items_then_free_pool(self: *Self, comptime SUB_FREE_USERDATA: type, sub_free_func: *const fn (item: *T, sub_free_userdata: SUB_FREE_USERDATA) void, sub_free_userdata: SUB_FREE_USERDATA) void {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            self.clear_retain_blocks();
            for (self.blocks.slice(), 0..) |block, block_idx| {
                const block_slice: []Slot = if (block_idx < self.block_with_unused) block[0..BLOCK_SIZE] else block[0..self.next_unused_idx_in_block];
                for (block_slice, 0..) |*item, sub_idx| {
                    const true_idx = num_cast((block_idx * BLOCK_SIZE) + sub_idx, IDX_TYPE);
                    var f: u32 = 0;
                    var this_free = self.first_free;
                    var was_free = false;
                    while (f < self.free_count) : (f += 1) {
                        if (this_free == true_idx) {
                            was_free = true;
                            break;
                        }
                        const this_free_block = f / BLOCK_SIZE;
                        const this_free_sub_idx = f % BLOCK_SIZE;
                        this_free = self.blocks.ptr[this_free_block][this_free_sub_idx].next_free;
                    }
                    if (!was_free) {
                        const used_item: *T = &item.item;
                        sub_free_func(used_item, sub_free_userdata);
                    }
                }
                self.alloc.destroy(block);
            }
            self.blocks.free(self.alloc);
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
        }

        pub fn free_pool(self: *Self) void {
            if (NEEDS_LOCK) {
                self.lock.lock();
            }
            self.clear_retain_blocks();
            for (self.blocks.slice()) |block| {
                self.alloc.destroy(block);
            }
            self.blocks.free(self.alloc);
            if (NEEDS_LOCK) {
                self.lock.unlock();
            }
        }
    };
}
