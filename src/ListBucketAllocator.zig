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
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;
const testing = std.testing;
const Test = Root.Testing;

const List = Root.IList_List.List;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

const Block = struct {
    start: u32,
    len: u32,
};

fn bucket_for_len(len: usize) usize {
    assert_with_reason(len != 0, @src(), "len cannot be 0", .{});
    const log2 = 63 - @clz(len);
    const add_one = @as(usize, @intCast(@intFromBool(log2 > 0)));
    return (log2 >> 1) + add_one;
}

// 8 = 0
// 16 = 1
// 32 = 2
// 64 = 3
// 128 = 4
// 256 = 5
// 512 = 6
// 1024 = 7

test bucket_for_len {
    // 0-1 = 0
    try Test.expect_equal(bucket_for_len(1), "bucket_for_len(1)", 0, "0", "wrong result", .{});
    // 2-3 = 1
    try Test.expect_equal(bucket_for_len(2), "bucket_for_len(2)", 1, "1", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(3), "bucket_for_len(3)", 1, "1", "wrong result", .{});
    // 4-15 = 2
    try Test.expect_equal(bucket_for_len(4), "bucket_for_len(4)", 2, "2", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(15), "bucket_for_len(15)", 2, "2", "wrong result", .{});
    // 16-63 = 3
    try Test.expect_equal(bucket_for_len(16), "bucket_for_len(16)", 3, "3", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(63), "bucket_for_len(63)", 3, "3", "wrong result", .{});
    // 64-255 = 4
    try Test.expect_equal(bucket_for_len(64), "bucket_for_len(64)", 4, "4", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(255), "bucket_for_len(255)", 4, "4", "wrong result", .{});
    // 256-1023 = 5
    try Test.expect_equal(bucket_for_len(256), "bucket_for_len(256)", 5, "5", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(1023), "bucket_for_len(1023)", 5, "5", "wrong result", .{});
    // 1024-4095 = 6
    try Test.expect_equal(bucket_for_len(1024), "bucket_for_len(1024)", 6, "6", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(4095), "bucket_for_len(4095)", 6, "6", "wrong result", .{});
    // 4096-16383 = 7
    try Test.expect_equal(bucket_for_len(4096), "bucket_for_len(4096)", 7, "7", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(16383), "bucket_for_len(16383)", 7, "7", "wrong result", .{});
    // 16384-65535 = 8
    try Test.expect_equal(bucket_for_len(16384), "bucket_for_len(16384)", 8, "8", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(65535), "bucket_for_len(65535)", 8, "8", "wrong result", .{});
    // 65536-262143 = 9
    try Test.expect_equal(bucket_for_len(65536), "bucket_for_len(65536)", 9, "9", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(262143), "bucket_for_len(262143)", 9, "9", "wrong result", .{});
    // 262144-1048575 = 10
    try Test.expect_equal(bucket_for_len(262144), "bucket_for_len(262144)", 10, "10", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(1048575), "bucket_for_len(1048575)", 10, "10", "wrong result", .{});
    // 1048576-4194303 = 11
    try Test.expect_equal(bucket_for_len(1048576), "bucket_for_len(1048576)", 11, "11", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(4194303), "bucket_for_len(4194303)", 11, "11", "wrong result", .{});
    // 4194304-16777215 = 12
    try Test.expect_equal(bucket_for_len(4194304), "bucket_for_len(4194304)", 12, "12", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(16777215), "bucket_for_len(16777215)", 12, "12", "wrong result", .{});
    // 16777216-67108863 = 13
    try Test.expect_equal(bucket_for_len(16777216), "bucket_for_len(16777216)", 13, "13", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(67108863), "bucket_for_len(67108863)", 13, "13", "wrong result", .{});
    // 67108864-268435455 = 14
    try Test.expect_equal(bucket_for_len(67108864), "bucket_for_len(67108864)", 14, "14", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(268435455), "bucket_for_len(268435455)", 14, "14", "wrong result", .{});
    // 268435456-1073741823 = 15
    try Test.expect_equal(bucket_for_len(268435456), "bucket_for_len(268435456)", 15, "15", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(1073741823), "bucket_for_len(1073741823)", 15, "15", "wrong result", .{});
    // 1073741824-4294967295 = 16
    try Test.expect_equal(bucket_for_len(1073741824), "bucket_for_len(1073741824)", 16, "16", "wrong result", .{});
    try Test.expect_equal(bucket_for_len(4294967295), "bucket_for_len(4294967295)", 16, "16", "wrong result", .{});
}

pub fn ListBucketAllocator(comptime T: type) type {
    return struct {
        data: DataList,
        buckets: [8]BlockList,

        const DataList = List(T);
        const BlockList = List(Block);
    };
}
