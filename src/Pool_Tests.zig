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

const TestPool = GlobalMappedKeyPool(.{
    .ELEM = u32,
    .IDX = u32,
    .MUTEX_MODE = .NO_MUTEXES,
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
    inline for (.{ .MASTER_MUTEX, .MASTER_AND_BLOCK_MUTEX }) |mutex_mode| {
        const ThreadedPool = GlobalMappedKeyPool(.{
            .ELEM = u32,
            .IDX = u32,
            .MUTEX_MODE = mutex_mode,
            .MUTEX_BLOCK_COVERAGE = 64,
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
