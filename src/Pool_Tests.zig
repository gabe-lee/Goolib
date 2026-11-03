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
const GlobalMappedKeyPool = Root.Pool.GlobalMappedKeyPool;
const BitTrackedBlocksPool = Root.Pool.BitTrackedBlocksPool;

const TestPool = GlobalMappedKeyPool(.{
    .ELEM = u32,
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
});

test "GlobalMappedKeyPool -> claim, get, set, and release" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const a = TestPool.claim_key();
    const b = TestPool.claim_key();

    try testing.expect(a.is_valid());
    try testing.expect(b.is_valid());
    try testing.expect(a.idx != b.idx);

    a.set(11);
    b.set(22);
    try testing.expectEqual(@as(u32, 11), a.get());
    try testing.expectEqual(@as(u32, 22), b.get());

    a.release();
    try testing.expect(!a.is_valid());
    try testing.expect(b.is_valid());
    try testing.expectEqual(@as(u32, 22), b.get());

    b.release();
    try testing.expect(!b.is_valid());
}

test "GlobalMappedKeyPool -> fresh mappings start in a clean state" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const first = TestPool.claim_key();
    // Generation starts at 0 and is bumped exactly once on claim.
    try testing.expectEqual(@as(u32, 1), first.gen);
    try testing.expectEqual(@as(u32, 0), first.idx);
    try testing.expect(first.is_valid());

    // Generations are per-mapping, so another fresh mapping also starts at 1.
    const second = TestPool.claim_key();
    try testing.expectEqual(@as(u32, 1), second.gen);
    try testing.expectEqual(@as(u32, 1), second.idx);
    try testing.expect(second.is_valid());
}

test "GlobalMappedKeyPool -> releasing a key keeps swap-removed values reachable" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    var keys: [5]TestPool.Key = undefined;
    for (&keys, 0..) |*key, i| {
        key.* = TestPool.claim_key();
        key.set(@intCast(i * 100));
    }

    // Releasing key 0 moves the last value (400) into value slot 0.
    keys[0].release();
    try testing.expect(!keys[0].is_valid());
    for (keys[1..], 1..) |key, i| {
        try testing.expect(key.is_valid());
        try testing.expectEqual(@as(u32, @intCast(i * 100)), key.get());
    }

    // Releasing key 2 moves the current last value (300) into value slot 2.
    keys[2].release();
    for (keys, 0..) |key, i| {
        if (i == 0 or i == 2) {
            try testing.expect(!key.is_valid());
        } else {
            try testing.expect(key.is_valid());
            try testing.expectEqual(@as(u32, @intCast(i * 100)), key.get());
        }
    }
}

test "GlobalMappedKeyPool -> every release order keeps surviving keys correct" {
    const N = 4;
    var permutation = [_]usize{ 0, 1, 2, 3 };

    while (true) {
        TestPool.init(0, testing.allocator, {});
        defer TestPool.uninit();

        var keys: [N]TestPool.Key = undefined;
        for (&keys, 0..) |*key, i| {
            key.* = TestPool.claim_key();
            key.set(@intCast(i + 1));
        }

        var released: [N]bool = @splat(false);
        for (permutation) |release_idx| {
            keys[release_idx].release();
            released[release_idx] = true;

            for (keys, 0..) |key, i| {
                if (released[i]) {
                    try testing.expect(!key.is_valid());
                } else {
                    try testing.expect(key.is_valid());
                    try testing.expectEqual(@as(u32, @intCast(i + 1)), key.get());
                }
            }
        }

        if (!nextPermutation(&permutation)) break;
    }
}

test "GlobalMappedKeyPool -> released mappings are reused with a new generation" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const old = TestPool.claim_key();
    old.set(5);
    const old_idx = old.idx;
    const old_gen = old.gen;
    old.release();

    // The free list is LIFO, so the just-released mapping is reused first.
    const new = TestPool.claim_key();
    try testing.expectEqual(old_idx, new.idx);
    try testing.expectEqual(old_gen +% 2, new.gen);
    try testing.expect(!old.is_valid());
    try testing.expect(new.is_valid());

    new.set(9);
    try testing.expectEqual(@as(u32, 9), new.get());
}

test "GlobalMappedKeyPool -> grows from zero capacity and retains live keys" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const N = 2000;
    var keys: [N]TestPool.Key = undefined;
    for (&keys, 0..) |*key, i| {
        key.* = TestPool.claim_key();
        key.set(@intCast(i));
    }

    for (keys, 0..) |key, i| {
        try testing.expect(key.is_valid());
        try testing.expectEqual(@as(u32, @intCast(i)), key.get());
    }

    // Free every other key; each release swap-removes a value, so this also
    // exercises the fix-up path across multiple capacity growths.
    for (keys, 0..) |key, i| {
        if (i % 2 == 0) key.release();
    }

    for (keys, 0..) |key, i| {
        if (i % 2 == 0) {
            try testing.expect(!key.is_valid());
        } else {
            try testing.expect(key.is_valid());
            try testing.expectEqual(@as(u32, @intCast(i)), key.get());
        }
    }
}

test "GlobalMappedKeyPool -> init capacity, uninit, and re-init" {
    TestPool.init(8, testing.allocator, {});
    const old = TestPool.claim_key();
    old.set(7);
    try testing.expectEqual(@as(u32, 7), old.get());
    TestPool.uninit();

    try testing.expect(!old.is_valid());

    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const new = TestPool.claim_key();
    new.set(9);
    try testing.expect(new.is_valid());
    try testing.expectEqual(@as(u32, 9), new.get());
}

test "GlobalMappedKeyPool -> randomized claims and releases match a model" {
    TestPool.init(0, testing.allocator, {});
    defer TestPool.uninit();

    const MAX_LIVE = 64;
    var keys: [MAX_LIVE]TestPool.Key = undefined;
    var vals: [MAX_LIVE]u32 = undefined;
    var live: usize = 0;

    var prng = std.Random.DefaultPrng.init(0x5EED);
    const rand = prng.random();

    var next_val: u32 = 1;
    for (0..5000) |_| {
        const can_claim = live < MAX_LIVE;
        const do_claim = live == 0 or (can_claim and rand.intRangeAtMost(u8, 0, 2) != 0);

        if (do_claim) {
            const key = TestPool.claim_key();
            const val = next_val;
            next_val +%= 1;
            key.set(val);
            keys[live] = key;
            vals[live] = val;
            live += 1;
        } else {
            const i = rand.intRangeLessThan(usize, 0, live);
            try testing.expectEqual(vals[i], keys[i].get());
            keys[i].release();
            live -= 1;
            keys[i] = keys[live];
            vals[i] = vals[live];
        }

        if (rand.intRangeAtMost(u8, 0, 31) == 0) {
            for (keys[0..live], vals[0..live]) |key, val| {
                try testing.expect(key.is_valid());
                try testing.expectEqual(val, key.get());
            }
        }
    }

    for (keys[0..live]) |key| key.release();
}

test "GlobalMappedKeyPool -> mutex modes support claim, get, set, release, and growth" {
    // Without at least one instantiation per mutex mode the threaded code paths are never
    // compiled, which hides both compile errors and locking mistakes.
    inline for (.{ .MASTER_LOCK, .MASTER_AND_BLOCK_LOCK }) |mutex_mode| {
        const ThreadedPool = GlobalMappedKeyPool(.{
            .ELEM = u32,
            .IDX = u32,
            .LOCK_MODE = mutex_mode,
            .LOCK_BLOCK_COVERAGE = 64,
        });

        var threaded: std.Io.Threaded = .init(testing.allocator, .{});
        defer threaded.deinit();

        ThreadedPool.init(0, testing.allocator, threaded.io());
        defer ThreadedPool.uninit();

        var keys: [300]ThreadedPool.Key = undefined;
        for (&keys, 0..) |*key, i| {
            key.* = ThreadedPool.claim_key();
            key.set(@intCast(i));
        }
        for (keys, 0..) |key, i| {
            try testing.expect(key.is_valid());
            try testing.expectEqual(@as(u32, @intCast(i)), key.get());
        }
        for (keys, 0..) |key, i| {
            if (i % 2 == 0) key.release();
        }
        for (keys, 0..) |key, i| {
            if (i % 2 == 0) {
                try testing.expect(!key.is_valid());
            } else {
                try testing.expect(key.is_valid());
                try testing.expectEqual(@as(u32, @intCast(i)), key.get());
            }
        }
        for (keys, 0..) |key, i| {
            if (i % 2 != 0) key.release();
        }
    }
}

fn nextPermutation(items: []usize) bool {
    if (items.len < 2) return false;

    var i: usize = items.len - 1;
    while (i > 0 and items[i - 1] >= items[i]) : (i -= 1) {}
    if (i == 0) return false;

    var j: usize = items.len - 1;
    while (items[j] <= items[i - 1]) : (j -= 1) {}

    std.mem.swap(usize, &items[i - 1], &items[j]);
    std.mem.reverse(usize, items[i..]);
    return true;
}

const StructPool = GlobalMappedKeyPool(.{
    .ELEM = struct {
        x: u32,
        y: i32,
        z: f32,
    },
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
});

const TaggedUnionPool = GlobalMappedKeyPool(.{
    .ELEM = union(enum) {
        int: i32,
        bytes: [4]u8,
    },
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
});

const UntaggedUnionPool = GlobalMappedKeyPool(.{
    .ELEM = union {
        int: i32,
        bytes: [4]u8,
    },
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
});

test "GlobalMappedKeyPool -> struct field access" {
    StructPool.init(0, testing.allocator, {});
    defer StructPool.uninit();

    const key = StructPool.claim_key();
    key.set(.{ .x = 1, .y = -2, .z = 3.5 });

    try testing.expectEqual(@as(u32, 1), key.get_field(.x));
    try testing.expectEqual(@as(i32, -2), key.get_field(.y));
    try testing.expectEqual(@as(f32, 3.5), key.get_field(.z));

    key.set_field(.x, 10);
    key.set_field(.y, 20);
    key.set_field(.z, 30.5);

    try testing.expectEqual(@as(u32, 10), key.get_field(.x));
    try testing.expectEqual(@as(i32, 20), key.get_field(.y));
    try testing.expectEqual(@as(f32, 30.5), key.get_field(.z));

    const whole = key.get();
    try testing.expectEqual(@as(u32, 10), whole.x);
    try testing.expectEqual(@as(i32, 20), whole.y);
    try testing.expectEqual(@as(f32, 30.5), whole.z);
}

test "GlobalMappedKeyPool -> struct field access survives swap-remove" {
    StructPool.init(0, testing.allocator, {});
    defer StructPool.uninit();

    var keys: [3]StructPool.Key = undefined;
    for (&keys, 0..) |*key, i| {
        key.* = StructPool.claim_key();
        key.set(.{ .x = @intCast(i), .y = @intCast(i), .z = @floatFromInt(i) });
    }

    // Releasing the first key moves the last value into its slot and updates
    // the mapping of the last key.
    keys[0].release();
    try testing.expect(!keys[0].is_valid());

    try testing.expectEqual(@as(u32, 1), keys[1].get_field(.x));
    try testing.expectEqual(@as(i32, 1), keys[1].get_field(.y));
    try testing.expectEqual(@as(f32, 1.0), keys[1].get_field(.z));

    try testing.expectEqual(@as(u32, 2), keys[2].get_field(.x));
    try testing.expectEqual(@as(i32, 2), keys[2].get_field(.y));
    try testing.expectEqual(@as(f32, 2.0), keys[2].get_field(.z));
}

test "GlobalMappedKeyPool -> tagged union field access checks and updates the tag" {
    TaggedUnionPool.init(0, testing.allocator, {});
    defer TaggedUnionPool.uninit();

    const key = TaggedUnionPool.claim_key();
    key.set(.{ .int = -7 });
    try testing.expectEqual(@as(i32, -7), key.get_field(.int));
    try testing.expect(std.meta.activeTag(key.get()) == .int);

    // Setting a different field switches the tag, just like assigning
    // `key.set(.{ .bytes = ... })` would.
    key.set_field(.bytes, .{ 1, 2, 3, 4 });
    try testing.expectEqual([4]u8{ 1, 2, 3, 4 }, key.get_field(.bytes));
    try testing.expect(std.meta.activeTag(key.get()) == .bytes);

    // Setting the original field back switches the tag again.
    key.set_field(.int, 42);
    try testing.expectEqual(@as(i32, 42), key.get_field(.int));
    try testing.expect(std.meta.activeTag(key.get()) == .int);
}

test "GlobalMappedKeyPool -> untagged union field access" {
    UntaggedUnionPool.init(0, testing.allocator, {});
    defer UntaggedUnionPool.uninit();

    const key = UntaggedUnionPool.claim_key();
    key.set(.{ .int = -7 });
    try testing.expectEqual(@as(i32, -7), key.get_field(.int));

    key.set_field(.int, 42);
    try testing.expectEqual(@as(i32, 42), key.get_field(.int));
    try testing.expectEqual(@as(i32, 42), key.get().int);
}

test "GlobalMappedKeyPool -> separate declarations with the same def have same memory" {
    TestPool.init(5, testing.allocator, {});
    defer TestPool.uninit();
    const TestPoolClone = GlobalMappedKeyPool(.{
        .ELEM = u32,
        .IDX = u32,
        .LOCK_MODE = .NO_LOCKS,
    });

    const key = TestPool.claim_key();
    key.set(777);
    const val_idx = key.val_index();
    const key_clone = TestPoolClone.key_for_value_index(val_idx);
    try testing.expectEqual(key_clone.get(), key.get());
}

test "GlobalMappedKeyPool -> separate declarations with separate discriminant have different memory" {
    TestPool.init(5, testing.allocator, {});
    defer TestPool.uninit();
    const TestPoolDiff = GlobalMappedKeyPool(.{
        .ELEM = u32,
        .IDX = u32,
        .LOCK_MODE = .NO_LOCKS,
        .GLOBAL_POOL_NAME = "SEPARATE LIST",
    });
    TestPoolDiff.init(5, testing.allocator, {});
    defer TestPoolDiff.uninit();

    const key = TestPool.claim_key();
    key.set(777);
    try testing.expectEqual(TestPool.total_item_len(), 1);
    try testing.expectEqual(TestPoolDiff.total_item_len(), 0);
    const key_diff = TestPoolDiff.claim_key();
    key_diff.set(666);
    try testing.expectEqual(key.get(), 777);
    try testing.expectEqual(key_diff.get(), 666);
}

const BitTrackedBasicPool = BitTrackedBlocksPool(.{
    .ELEM = u32,
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
    .SLOTS_PER_BLOCK = 64,
});

const BitTrackedSimdPool = BitTrackedBlocksPool(.{
    .ELEM = u32,
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
    .SLOTS_PER_BLOCK = 192,
});
const BitTrackedSimdPoolU16 = BitTrackedBlocksPool(.{
    .ELEM = u32,
    .IDX = u32,
    .STATE_UINT = u16,
    .LOCK_MODE = .NO_LOCKS,
    .SLOTS_PER_BLOCK = 192,
});

const BitTrackedCachedPool = BitTrackedBlocksPool(.{
    .ELEM = u32,
    .IDX = u32,
    .LOCK_MODE = .NO_LOCKS,
    .SLOTS_PER_BLOCK = 64,
    .ALLOC_MODE = .CACHED_ALLOC,
});

test "BitTrackedBlocksPool -> SLOTS_PER_BLOCK drives size and vals alignment" {
    const SuperPool = BitTrackedBlocksPool(.{
        .ELEM = u32,
        .IDX = u32,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 64,
        .BACK_POINT_STRATEGY = .SUPER_ALIGN_AND_MASK,
    });
    try testing.expectEqual(@as(u32, 64), SuperPool.DATA_BLOCK_SLOT_LENGTH);
    try testing.expectEqual(@as(usize, 256), SuperPool.DATA_BLOCK_ALIGNMENT);
    try testing.expectEqual(@as(usize, 512), SuperPool.DATA_BLOCK_BYTE_SIZE);

    const OddPool = BitTrackedBlocksPool(.{
        .ELEM = u8,
        .IDX = u16,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 192,
        .BACK_POINT_STRATEGY = .SUPER_ALIGN_AND_MASK,
    });
    try testing.expectEqual(@as(u16, 192), OddPool.DATA_BLOCK_SLOT_LENGTH);
    try testing.expectEqual(@as(usize, 256), OddPool.DATA_BLOCK_ALIGNMENT);
    try testing.expectEqual(@as(usize, 256), OddPool.DATA_BLOCK_BYTE_SIZE);
}

test "BitTrackedBlocksPool -> every back-pointer strategy reverses slots correctly" {
    const N = 400;

    inline for (.{ 64, 192 }) |slots_per_block| {
        inline for (.{ .SUPER_ALIGN_AND_MASK, .AUXILLIARY_INDEX_FIELD, .SORTED_BLOCKS_BINARY_SEARCH }) |strategy| {
            const Pool = BitTrackedBlocksPool(.{
                .ELEM = u32,
                .IDX = u32,
                .LOCK_MODE = .NO_LOCKS,
                .SLOTS_PER_BLOCK = slots_per_block,
                .BACK_POINT_STRATEGY = strategy,
            });
            const Slot = *Pool.ELEM;
            const BLOCK_SLOTS: usize = Pool.DATA_BLOCK_SLOT_LENGTH;
            const EXPECTED_BLOCKS = (N + BLOCK_SLOTS - 1) / BLOCK_SLOTS;

            var pool: Pool = .{};
            pool.init(0, testing.allocator, {});
            defer pool.uninit(testing.allocator);

            var slots: [N]Slot = undefined;
            for (&slots, 0..) |*slot, i| {
                slot.* = pool.claim_slot(testing.allocator);
                slot.*.* = @intCast(i + 1);
            }

            // Every claimed slot must reverse back to this pool and its own block.
            for (slots, 0..) |slot, i| {
                try testing.expect(pool.slot_pool(slot) == &pool);
                pool.assert_slot_valid(slot, @src());
                try testing.expectEqual(@as(u32, @intCast(i + 1)), slot.*);
            }

            // Release every other slot, then make sure the survivors are still valid
            // and reachable through their back-pointers.
            for (slots, 0..) |slot, i| {
                if (i % 2 == 0) pool.release_slot(slot);
            }
            for (slots, 0..) |slot, i| {
                if (i % 2 == 1) {
                    try testing.expectEqual(@as(u32, @intCast(i + 1)), slot.*);
                    pool.assert_slot_valid(slot, @src());
                }
            }

            // Reuse the released slots and verify their metadata was refreshed.
            var reused: [N / 2]Slot = undefined;
            for (&reused, 0..) |*slot, i| {
                slot.* = pool.claim_slot(testing.allocator);
                slot.*.* = @intCast(1000 + i);
            }
            for (reused, 0..) |slot, i| {
                try testing.expectEqual(@as(u32, @intCast(1000 + i)), slot.*);
                try testing.expect(pool.slot_pool(slot) == &pool);
                pool.assert_slot_valid(slot, @src());
            }

            for (reused) |slot| pool.release_slot(slot);
            for (slots, 0..) |slot, i| {
                if (i % 2 == 1) pool.release_slot(slot);
            }
            try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK_SLOTS)), pool.get_num_free());
        }
    }
}

test "BitTrackedBlocksPool -> claim, write, release, and reuse" {
    const Slot = *BitTrackedBasicPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedBasicPool.DATA_BLOCK_SLOT_LENGTH;

    var pool: BitTrackedBasicPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    try testing.expectEqual(@as(u32, 0), pool.get_num_free());

    var slots: [10]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(i);
    }

    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS - 10)), pool.get_num_free());
    for (slots, 0..) |slot, i| {
        for (slots[0..i]) |other| {
            try testing.expect(slot != other);
        }
        try testing.expect(pool.slot_pool(slot) == &pool);
        pool.assert_slot_valid(slot, @src());
        try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
    }

    var released_ptrs: [5]Slot = undefined;
    for (slots[0..5], 0..) |slot, i| {
        released_ptrs[i] = slot;
        pool.release_slot(slot);
    }
    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS - 5)), pool.get_num_free());
    for (slots[5..], 5..) |slot, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
        pool.assert_slot_valid(slot, @src());
    }

    var reused: [5]Slot = undefined;
    for (&reused, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(100 + i);
        var was_released = false;
        for (released_ptrs) |old| {
            if (slot.* == old) was_released = true;
        }
        try testing.expect(was_released);
    }

    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS - 10)), pool.get_num_free());
    for (slots[5..], 5..) |slot, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
    }

    for (reused) |slot| pool.release_slot(slot);
    for (slots[5..]) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> growth keeps values intact and release works across blocks" {
    const Slot = *BitTrackedBasicPool.ELEM;
    const N = 200;
    const BLOCK: usize = BitTrackedBasicPool.DATA_BLOCK_SLOT_LENGTH;
    const EXPECTED_BLOCKS = (N + BLOCK - 1) / BLOCK;

    var pool: BitTrackedBasicPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [N]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(i + 1);
    }

    try testing.expectEqual(@as(u32, @intCast((EXPECTED_BLOCKS * BLOCK) - N)), pool.get_num_free());

    for (&slots, 0..) |*slot, i| {
        if (i % 2 == 0) pool.release_slot(slot.*);
    }
    try testing.expectEqual(@as(u32, @intCast((EXPECTED_BLOCKS * BLOCK) - (N / 2))), pool.get_num_free());

    for (slots, 0..) |slot, i| {
        if (i % 2 == 1) {
            try testing.expectEqual(@as(u32, @intCast(i + 1)), slot.*);
            pool.assert_slot_valid(slot, @src());
        }
    }

    var extra: [N / 2]Slot = undefined;
    for (&extra, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(1000 + i);
    }
    try testing.expectEqual(@as(u32, @intCast((EXPECTED_BLOCKS * BLOCK) - N)), pool.get_num_free());

    for (slots, 0..) |slot, i| {
        if (i % 2 == 1) {
            try testing.expectEqual(@as(u32, @intCast(i + 1)), slot.*);
        }
    }
    for (extra, 0..) |slot, i| {
        try testing.expectEqual(@as(u32, @intCast(1000 + i)), slot.*);
    }

    for (&slots, 0..) |*slot, i| {
        if (i % 2 == 1) pool.release_slot(slot.*);
    }
    for (extra) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> small IDX and ELEM types" {
    const Pool = BitTrackedBlocksPool(.{
        .ELEM = u8,
        .IDX = u16,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 64,
    });
    const Slot = *Pool.ELEM;

    var pool: Pool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    const N = 1000;
    var slots: [N]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @truncate(i);
    }

    const total_capacity: u16 = pool.get_num_free() + @as(u16, N);

    for (&slots, 0..) |*slot, i| {
        try testing.expectEqual(@as(u8, @truncate(i)), slot.*.*);
        if (i % 2 == 0) pool.release_slot(slot.*);
    }

    for (&slots, 0..) |*slot, i| {
        if (i % 2 == 1) {
            try testing.expectEqual(@as(u8, @truncate(i)), slot.*.*);
            pool.release_slot(slot.*);
        }
    }

    try testing.expectEqual(total_capacity, pool.get_num_free());
}

test "BitTrackedBlocksPool -> ensure_free_slots grows without claiming" {
    const Slot = *BitTrackedBasicPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedBasicPool.DATA_BLOCK_SLOT_LENGTH;
    const NEEDED = 200;
    const EXPECTED_BLOCKS = (NEEDED + BLOCK_SLOTS - 1) / BLOCK_SLOTS;

    var pool: BitTrackedBasicPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    pool.ensure_free_slots(NEEDED, testing.allocator);
    try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK_SLOTS)), pool.get_num_free());

    var slots: [NEEDED]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(i);
    }
    try testing.expectEqual(@as(u32, @intCast((EXPECTED_BLOCKS * BLOCK_SLOTS) - NEEDED)), pool.get_num_free());

    for (slots) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> val, ptr, and const_ptr iterators visit exactly the used slots" {
    inline for (.{ 64, 192 }) |slots_per_block| {
        const Pool = BitTrackedBlocksPool(.{
            .ELEM = u32,
            .IDX = u32,
            .LOCK_MODE = .NO_LOCKS,
            .SLOTS_PER_BLOCK = slots_per_block,
        });
        const Slot = *Pool.ELEM;

        var pool: Pool = .{};
        pool.init(0, testing.allocator, {});
        defer pool.uninit(testing.allocator);

        const N = 150;
        var slots: [N]Slot = undefined;
        for (&slots, 0..) |*slot, i| {
            slot.* = pool.claim_slot(testing.allocator);
            slot.*.* = @intCast(i + 1);
        }

        var expected_used = @as([N]bool, @splat(false));
        var expected_count: usize = 0;
        for (&slots, 0..) |*slot, i| {
            if (i % 3 == 0) {
                pool.release_slot(slot.*);
            } else {
                expected_used[i] = true;
                expected_count += 1;
            }
        }

        var seen_val = @as([N]bool, @splat(false));
        var val_count: usize = 0;
        var val_iter = pool.val_iterator();
        while (val_iter.next()) |val| {
            try testing.expect(val > 0 and val <= N);
            const i = val - 1;
            try testing.expect(!seen_val[i]);
            seen_val[i] = true;
            val_count += 1;
        }
        val_iter.deinit_and_unlock();
        try testing.expectEqual(expected_count, val_count);
        try testing.expectEqualSlices(bool, &expected_used, &seen_val);

        var seen_ptr = @as([N]bool, @splat(false));
        var ptr_count: usize = 0;
        var ptr_iter = pool.ptr_iterator();
        while (ptr_iter.next()) |slot| {
            try testing.expect(slot.* > 0 and slot.* <= N);
            const i = slot.* - 1;
            try testing.expect(!seen_ptr[i]);
            seen_ptr[i] = true;
            slot.* += 1000;
            ptr_count += 1;
        }
        ptr_iter.deinit_and_unlock();
        try testing.expectEqual(expected_count, ptr_count);
        try testing.expectEqualSlices(bool, &expected_used, &seen_ptr);

        var seen_const = @as([N]bool, @splat(false));
        var const_count: usize = 0;
        var const_iter = pool.const_ptr_iterator();
        while (const_iter.next()) |slot| {
            try testing.expect(slot.* > 1000 and slot.* <= N + 1000);
            const i = slot.* - 1001;
            try testing.expect(!seen_const[i]);
            seen_const[i] = true;
            const_count += 1;
        }
        const_iter.deinit_and_unlock();
        try testing.expectEqual(expected_count, const_count);
        try testing.expectEqualSlices(bool, &expected_used, &seen_const);

        for (&slots, 0..) |*slot, i| {
            if (i % 3 != 0) pool.release_slot(slot.*);
        }
    }
}

test "BitTrackedBlocksPool -> ignore-lock advanced claim, release, and iterators" {
    const Slot = *BitTrackedBasicPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedBasicPool.DATA_BLOCK_SLOT_LENGTH;

    var pool: BitTrackedBasicPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [20]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot_advanced(testing.allocator, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS);
        slot.*.* = @intCast(i + 1);
    }

    var seen = @as([20]bool, @splat(false));
    var count: usize = 0;
    var iter = pool.val_iterator_ignore_locks();
    while (iter.next()) |val| {
        try testing.expect(val > 0 and val <= slots.len);
        const i = val - 1;
        try testing.expect(!seen[i]);
        seen[i] = true;
        count += 1;
    }
    iter.deinit_and_unlock();
    try testing.expectEqual(slots.len, count);

    for (slots) |slot| {
        pool.release_slot_advanced(slot, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS);
    }
    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> CACHED_ALLOC mode works without passing an allocator" {
    const Slot = *BitTrackedCachedPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedCachedPool.DATA_BLOCK_SLOT_LENGTH;
    const N = 300;
    const EXPECTED_BLOCKS = (N + BLOCK_SLOTS - 1) / BLOCK_SLOTS;

    var pool: BitTrackedCachedPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit({});

    var slots: [N]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot({});
        slot.*.* = @intCast(i);
    }

    for (slots, 0..) |slot, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
    }

    for (slots) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> slot lookup and release variants" {
    const Slot = *BitTrackedBasicPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedBasicPool.DATA_BLOCK_SLOT_LENGTH;

    var pool: BitTrackedBasicPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [BLOCK_SLOTS + 1]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(i + 1);
        try testing.expect(pool.slot_pool(slot.*) == &pool);
        pool.assert_slot_valid(slot.*, @src());
    }

    // Releasing a slot makes it available to the next claim.
    const free_before = pool.get_num_free();
    const held = slots[0];
    pool.release_slot(held);
    try testing.expectEqual(free_before + 1, pool.get_num_free());

    // Claiming again should pick the just-freed slot in the first block.
    const reused = pool.claim_slot(testing.allocator);
    try testing.expectEqual(held, reused);
    reused.* = 999;

    // The advanced release path uses the same slot metadata.
    const free_before_adv = pool.get_num_free();
    pool.release_slot_advanced(reused, .IGNORE_POOL_LOCKS, .IGNORE_BLOCK_LOCKS);
    try testing.expectEqual(free_before_adv + 1, pool.get_num_free());

    for (slots[1..]) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(2 * BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> mutex modes support claim, release, block locks, and iterators" {
    inline for (.{ .MASTER_LOCK, .MASTER_AND_BLOCK_LOCK }) |mutex_mode| {
        const Pool = BitTrackedBlocksPool(.{
            .ELEM = u32,
            .IDX = u32,
            .LOCK_MODE = mutex_mode,
            .SLOTS_PER_BLOCK = 64,
        });

        var threaded: std.Io.Threaded = .init(testing.allocator, .{});
        defer threaded.deinit();

        const Slot = *Pool.ELEM;
        const BLOCK_SLOTS: usize = Pool.DATA_BLOCK_SLOT_LENGTH;
        const N = 200;
        const EXPECTED_BLOCKS = (N + BLOCK_SLOTS - 1) / BLOCK_SLOTS;

        var pool: Pool = .{};
        pool.init(0, testing.allocator, threaded.io());
        defer pool.uninit(testing.allocator);

        var slots: [N]Slot = undefined;
        for (&slots, 0..) |*slot, i| {
            slot.* = pool.claim_slot(testing.allocator);
            slot.*.* = @intCast(i);
        }

        // Slot lookup routes through the data block's cached pool back-pointer.
        const first = slots[0];
        try testing.expect(pool.slot_pool(first) == &pool);
        try testing.expectEqual(@as(u32, 0), first.*);
        first.* = 1234;
        try testing.expectEqual(@as(u32, 1234), first.*);
        first.* = 0;

        var iter_count: usize = 0;
        var iter = pool.const_ptr_iterator();
        while (iter.next()) |slot| {
            try testing.expect(slot.* < slots.len);
            iter_count += 1;
        }
        iter.deinit_and_unlock();
        try testing.expectEqual(slots.len, iter_count);

        var ignore_iter = pool.val_iterator_ignore_locks();
        var ignore_count: usize = 0;
        while (ignore_iter.next()) |_| ignore_count += 1;
        ignore_iter.deinit_and_unlock();
        try testing.expectEqual(slots.len, ignore_count);

        for (slots, 0..) |slot, i| {
            try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
        }
        for (slots) |slot| pool.release_slot(slot);
        try testing.expectEqual(@as(u32, @intCast(EXPECTED_BLOCKS * BLOCK_SLOTS)), pool.get_num_free());
    }
}

test "BitTrackedBlocksPool -> init, uninit, and re-init" {
    var pool: BitTrackedBasicPool = .{};
    pool.init(16, testing.allocator, {});
    const first = pool.claim_slot(testing.allocator);
    try testing.expect(pool.slot_pool(first) == &pool);
    first.* = 7;
    try testing.expectEqual(@as(u32, 7), first.*);
    pool.uninit(testing.allocator);
    try testing.expectEqual(@as(u32, 0), pool.get_num_free());

    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    const second = pool.claim_slot(testing.allocator);
    try testing.expect(pool.slot_pool(second) == &pool);
    second.* = 9;
    try testing.expectEqual(@as(u32, 9), second.*);
}

test "BitTrackedBlocksPool -> struct elements" {
    const Struct = struct {
        x: u32,
        y: i32,
        z: f32,
    };
    const Pool = BitTrackedBlocksPool(.{
        .ELEM = Struct,
        .IDX = u32,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 320,
        .ALLOC_MODE = .MANUAL_ALLOC,
    });

    var pool: Pool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [20]*Struct = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = .{ .x = @intCast(i), .y = -@as(i32, @intCast(i)), .z = @floatFromInt(i) };
    }

    for (slots, 0..) |slot, i| {
        const val = slot.*;
        try testing.expectEqual(@as(u32, @intCast(i)), val.x);
        try testing.expectEqual(-@as(i32, @intCast(i)), val.y);
        try testing.expectEqual(@as(f32, @floatFromInt(i)), val.z);
    }

    for (slots) |slot| pool.release_slot(slot);
}

test "BitTrackedBlocksPool -> struct elements (u16 state int)" {
    const Struct = struct {
        x: u32,
        y: i32,
        z: f32,
    };
    const Pool = BitTrackedBlocksPool(.{
        .ELEM = Struct,
        .IDX = u32,
        .STATE_UINT = u16,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 320,
        .ALLOC_MODE = .MANUAL_ALLOC,
    });

    var pool: Pool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [20]*Struct = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = .{ .x = @intCast(i), .y = -@as(i32, @intCast(i)), .z = @floatFromInt(i) };
    }

    for (slots, 0..) |slot, i| {
        const val = slot.*;
        try testing.expectEqual(@as(u32, @intCast(i)), val.x);
        try testing.expectEqual(-@as(i32, @intCast(i)), val.y);
        try testing.expectEqual(@as(f32, @floatFromInt(i)), val.z);
    }

    for (slots) |slot| pool.release_slot(slot);
}

test "BitTrackedBlocksPool -> u8 state int supports more slots than maxInt(u8)" {
    const Pool = BitTrackedBlocksPool(.{
        .ELEM = u32,
        .IDX = u32,
        .STATE_UINT = u8,
        .LOCK_MODE = .NO_LOCKS,
        .SLOTS_PER_BLOCK = 320,
    });
    const Slot = *Pool.ELEM;
    const BLOCK_SLOTS: usize = Pool.DATA_BLOCK_SLOT_LENGTH;

    var pool: Pool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    var slots: [100]Slot = undefined;
    for (&slots, 0..) |*slot, i| {
        slot.* = pool.claim_slot(testing.allocator);
        slot.*.* = @intCast(i);
    }

    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS - slots.len)), pool.get_num_free());
    for (slots, 0..) |slot, i| {
        try testing.expectEqual(@as(u32, @intCast(i)), slot.*);
        pool.assert_slot_valid(slot, @src());
    }

    for (slots) |slot| pool.release_slot(slot);
    try testing.expectEqual(@as(u32, @intCast(BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> randomized claims and releases match a model" {
    const Slot = *BitTrackedSimdPool.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedSimdPool.DATA_BLOCK_SLOT_LENGTH;

    var pool: BitTrackedSimdPool = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    const MAX_LIVE = 300;
    var slots: [MAX_LIVE]Slot = undefined;
    var vals: [MAX_LIVE]u32 = undefined;
    var live: usize = 0;
    var max_live: usize = 0;

    var prng = std.Random.DefaultPrng.init(0xB17_7AC);
    const rand = prng.random();

    var next_val: u32 = 1;
    for (0..10000) |_| {
        const can_claim = live < MAX_LIVE;
        const do_claim = live == 0 or (can_claim and rand.intRangeAtMost(u8, 0, 2) != 0);

        if (do_claim) {
            const slot = pool.claim_slot(testing.allocator);
            const val = next_val;
            next_val +%= 1;
            slot.* = val;
            slots[live] = slot;
            vals[live] = val;
            live += 1;
            max_live = @max(max_live, live);
        } else {
            const i = rand.intRangeLessThan(usize, 0, live);
            try testing.expectEqual(vals[i], slots[i].*);
            try testing.expect(pool.slot_pool(slots[i]) == &pool);
            pool.release_slot(slots[i]);
            live -= 1;
            slots[i] = slots[live];
            vals[i] = vals[live];
        }

        if (rand.intRangeAtMost(u8, 0, 63) == 0) {
            for (slots[0..live], vals[0..live]) |slot, val| {
                try testing.expectEqual(val, slot.*);
            }
        }
    }

    for (slots[0..live], vals[0..live]) |slot, val| {
        try testing.expectEqual(val, slot.*);
    }
    for (slots[0..live]) |slot| pool.release_slot(slot);
    const expected_blocks = (max_live + BLOCK_SLOTS - 1) / BLOCK_SLOTS;
    try testing.expectEqual(@as(u32, @intCast(expected_blocks * BLOCK_SLOTS)), pool.get_num_free());
}

test "BitTrackedBlocksPool -> randomized claims and releases match a model (u16 state int)" {
    const Slot = *BitTrackedSimdPoolU16.ELEM;
    const BLOCK_SLOTS: usize = BitTrackedSimdPoolU16.DATA_BLOCK_SLOT_LENGTH;

    var pool: BitTrackedSimdPoolU16 = .{};
    pool.init(0, testing.allocator, {});
    defer pool.uninit(testing.allocator);

    const MAX_LIVE = 300;
    var slots: [MAX_LIVE]Slot = undefined;
    var vals: [MAX_LIVE]u32 = undefined;
    var live: usize = 0;
    var max_live: usize = 0;

    var prng = std.Random.DefaultPrng.init(0xB17_7AC);
    const rand = prng.random();

    var next_val: u32 = 1;
    for (0..10000) |_| {
        const can_claim = live < MAX_LIVE;
        const do_claim = live == 0 or (can_claim and rand.intRangeAtMost(u8, 0, 2) != 0);

        if (do_claim) {
            const slot = pool.claim_slot(testing.allocator);
            const val = next_val;
            next_val +%= 1;
            slot.* = val;
            slots[live] = slot;
            vals[live] = val;
            live += 1;
            max_live = @max(max_live, live);
        } else {
            const i = rand.intRangeLessThan(usize, 0, live);
            try testing.expectEqual(vals[i], slots[i].*);
            try testing.expect(pool.slot_pool(slots[i]) == &pool);
            pool.release_slot(slots[i]);
            live -= 1;
            slots[i] = slots[live];
            vals[i] = vals[live];
        }

        if (rand.intRangeAtMost(u8, 0, 63) == 0) {
            for (slots[0..live], vals[0..live]) |slot, val| {
                try testing.expectEqual(val, slot.*);
            }
        }
    }

    for (slots[0..live], vals[0..live]) |slot, val| {
        try testing.expectEqual(val, slot.*);
    }
    for (slots[0..live]) |slot| pool.release_slot(slot);
    const expected_blocks = (max_live + BLOCK_SLOTS - 1) / BLOCK_SLOTS;
    try testing.expectEqual(@as(u32, @intCast(expected_blocks * BLOCK_SLOTS)), pool.get_num_free());
}
