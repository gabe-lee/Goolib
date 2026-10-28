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

const std = @import("std");
const SwissTable = @import("./HashMap_SwissTable.zig");

fn hash_i32(key: i32) u64 {
    var h: u64 = @bitCast(@as(i64, key));
    h ^= h >> 33;
    h *%= 0xff51afd7ed558ccd;
    h ^= h >> 33;
    h *%= 0xc4ceb9fe1a85ec53;
    h ^= h >> 33;
    return h;
}

fn hash_zero(_: i32) u64 {
    return 0;
}

fn equal_i32(a: i32, b: i32) bool {
    return a == b;
}

const Map = SwissTable.SwissHashMap(i32, i32, hash_i32, equal_i32, .{});
const MapScalar = SwissTable.SwissHashMap(i32, i32, hash_i32, equal_i32, .{ .OVERRIDE_SIMD_LANE_COUNT = 1 });
const MapColliding = SwissTable.SwissHashMap(i32, i32, hash_zero, equal_i32, .{});
const MapHalfLoad = SwissTable.SwissHashMap(i32, i32, hash_i32, equal_i32, .{
    .OVERRIDE_MAX_LOAD_PERCENT = .{ .numerator = 1, .denominator = 2 },
});

fn testInsertContainsGet(comptime M: type) !void {
    const alloc = std.testing.allocator;
    var map: M = .{};
    defer map.deinit(alloc);

    try std.testing.expect(!map.contains(0));
    try std.testing.expectEqual(@as(?i32, null), map.remove_key_if_exists(0));

    for (0..200) |i| {
        const key: i32 = @intCast(i);
        map.insert(key, key * 10, alloc);
        try std.testing.expect(map.contains(key));
        try std.testing.expectEqual(i + 1, map.len);
    }

    for (0..200) |i| {
        const key: i32 = @intCast(i);
        const idx = map.insert_key_get_idx(key, alloc);
        try std.testing.expectEqual(key, map.keys_list[idx]);
        try std.testing.expectEqual(@as(i32, @intCast(i * 10)), map.val_list[idx]);
    }

    try std.testing.expectEqual(@as(u64, 200), map.len);
}

test "SwissHashMap -> insert, contains, get (simd)" {
    try testInsertContainsGet(Map);
    try testInsertContainsGet(MapHalfLoad);
}

test "SwissHashMap -> insert, contains, get (scalar)" {
    try testInsertContainsGet(MapScalar);
}

test "SwissHashMap -> duplicate key overwrites value and does not grow len" {
    const alloc = std.testing.allocator;
    var map: Map = .{};
    defer map.deinit(alloc);

    map.insert(7, 1, alloc);
    map.insert(7, 2, alloc);
    map.insert(7, 3, alloc);

    try std.testing.expectEqual(@as(u64, 1), map.len);
    const idx = map.insert_key_get_idx(7, alloc);
    try std.testing.expectEqual(@as(i32, 3), map.val_list[idx]);

    try std.testing.expectEqual(@as(?i32, 3), map.remove_key_if_exists(7));
    try std.testing.expectEqual(@as(?i32, null), map.remove_key_if_exists(7));
    try std.testing.expectEqual(@as(u64, 0), map.len);
}

fn testRemoveLeavesTombstones(comptime M: type) !void {
    const alloc = std.testing.allocator;
    var map: M = .{};
    defer map.deinit(alloc);

    for (0..256) |i| {
        const key: i32 = @intCast(i);
        map.insert(key, key, alloc);
    }

    // Removing half of the entries leaves DELETED cells behind. Lookups for the
    // remaining keys must keep probing past those tombstones.
    for (0..256) |i| {
        if (i % 2 != 0) continue;
        const key: i32 = @intCast(i);
        try std.testing.expectEqual(@as(?i32, key), map.remove_key_if_exists(key));
        try std.testing.expect(!map.contains(key));
    }

    try std.testing.expectEqual(@as(u64, 128), map.len);

    for (0..256) |i| {
        const key: i32 = @intCast(i);
        if (i % 2 == 0) {
            try std.testing.expect(!map.contains(key));
            try std.testing.expectEqual(@as(?i32, null), map.remove_key_if_exists(key));
        } else {
            try std.testing.expect(map.contains(key));
            const idx = map.insert_key_get_idx(key, alloc);
            try std.testing.expectEqual(key, map.val_list[idx]);
        }
    }

    for (0..256) |i| {
        const key: i32 = @intCast(i);
        if (i % 2 != 0) try std.testing.expectEqual(@as(?i32, key), map.remove_key_if_exists(key));
    }

    try std.testing.expectEqual(@as(u64, 0), map.len);

    // Reinsert everything after the table has been emptied through tombstones.
    for (0..256) |i| {
        const key: i32 = @intCast(i);
        map.insert(key, key + 1, alloc);
    }
    for (0..256) |i| {
        const key: i32 = @intCast(i);
        const idx = map.insert_key_get_idx(key, alloc);
        try std.testing.expectEqual(key + 1, map.val_list[idx]);
    }
}

test "SwissHashMap -> remove keeps probe chains valid (simd)" {
    try testRemoveLeavesTombstones(Map);
}

test "SwissHashMap -> remove keeps probe chains valid (scalar)" {
    try testRemoveLeavesTombstones(MapScalar);
}

test "SwissHashMap -> every key collides on the same h1/h2" {
    const alloc = std.testing.allocator;
    var map: MapColliding = .{};
    defer map.deinit(alloc);

    for (0..200) |i| {
        const key: i32 = @intCast(i);
        map.insert(key, key * 2, alloc);
    }

    for (0..200) |i| {
        const key: i32 = @intCast(i);
        try std.testing.expect(map.contains(key));
        const idx = map.insert_key_get_idx(key, alloc);
        try std.testing.expectEqual(key * 2, map.val_list[idx]);
    }

    for (0..200) |i| {
        if (i % 3 != 0) continue;
        const key: i32 = @intCast(i);
        try std.testing.expectEqual(@as(?i32, key * 2), map.remove_key_if_exists(key));
    }

    for (0..200) |i| {
        const key: i32 = @intCast(i);
        try std.testing.expectEqual(i % 3 != 0, map.contains(key));
    }
}

test "SwissHashMap -> grow" {
    const alloc = std.testing.allocator;
    var map: Map = .{};
    defer map.deinit(alloc);

    map.grow(1000, alloc);
    try std.testing.expect(map.cap >= 1000);

    for (0..1000) |i| {
        const key: i32 = @intCast(i);
        map.insert(key, key, alloc);
    }
    for (0..1000) |i| {
        const key: i32 = @intCast(i);
        try std.testing.expect(map.contains(key));
    }
}

test "SwissHashMap -> miscellaneous public API" {
    const alloc = std.testing.allocator;
    var map: Map = .{};
    defer map.deinit(alloc);

    map.grow(64, alloc);

    const hash_1 = Map.hash(1);
    const parts_1 = Map.hash_parts(1);
    try std.testing.expectEqual(parts_1.code, Map.hash_to_parts(hash_1).code);
    try std.testing.expectEqual(parts_1.state, Map.hash_to_parts(hash_1).state);
    try std.testing.expect(Map.keys_equal(1, 1));

    map.insert_hash_parts_assume_cap(1, 10, Map.hash_parts(1));
    map.insert_hash_parts(2, 20, Map.hash_parts(2), alloc);
    map.insert_hash_assume_cap(3, 30, Map.hash(3));
    map.insert_hash(4, 40, Map.hash(4), alloc);
    map.insert_assume_cap(5, 50);

    map.insert_key_hash_parts_get_ptr_assume_cap(6, Map.hash_parts(6)).* = 60;
    map.insert_key_hash_parts_get_ptr(7, Map.hash_parts(7), alloc).* = 70;
    map.insert_key_hash_get_ptr_assume_cap(8, Map.hash(8)).* = 80;
    map.insert_key_hash_get_ptr(9, Map.hash(9), alloc).* = 90;
    map.insert_key_get_ptr_assume_cap(10).* = 100;
    map.insert_key_get_ptr(11, alloc).* = 110;

    map.val_list[map.insert_key_hash_parts_get_idx_assume_cap(12, Map.hash_parts(12))] = 120;
    map.val_list[map.insert_key_hash_parts_get_idx(13, Map.hash_parts(13), alloc)] = 130;
    map.val_list[map.insert_key_hash_get_idx_assume_cap(14, Map.hash(14))] = 140;
    map.val_list[map.insert_key_hash_get_idx(15, Map.hash(15), alloc)] = 150;
    map.val_list[map.insert_key_get_idx_assume_cap(16)] = 160;
    map.val_list[map.insert_key_get_idx(17, alloc)] = 170;

    try std.testing.expect(map.contains_hash_parts(1, Map.hash_parts(1)));
    try std.testing.expect(map.contains_hash(2, Map.hash(2)));
    try std.testing.expect(map.contains(3));
    try std.testing.expect(map.contains_hash_parts(12, Map.hash_parts(12)));
    try std.testing.expectEqual(@as(i32, 170), map.val_list[map.insert_key_get_idx(17, alloc)]);

    try std.testing.expectEqual(@as(i32, 10), map.remove_key_hash_parts(1, Map.hash_parts(1)));
    try std.testing.expectEqual(@as(i32, 20), map.remove_key_hash(2, Map.hash(2)));
    try std.testing.expectEqual(@as(i32, 30), map.remove_key(3));
    try std.testing.expectEqual(@as(?i32, 40), map.remove_key_hash_parts_if_exists(4, Map.hash_parts(4)));
    try std.testing.expectEqual(@as(?i32, 50), map.remove_key_hash_if_exists(5, Map.hash(5)));
    try std.testing.expectEqual(@as(?i32, 60), map.remove_key_if_exists(6));

    map.delete_key_hash_parts(7, Map.hash_parts(7));
    map.delete_key_hash(8, Map.hash(8));
    map.delete_key(9);

    try std.testing.expect(map.delete_key_hash_parts_report_existed(10, Map.hash_parts(10)));
    try std.testing.expect(map.delete_key_hash_report_existed(11, Map.hash(11)));
    try std.testing.expect(map.delete_key_report_existed(12));
    try std.testing.expect(!map.delete_key_report_existed(9999));
}
