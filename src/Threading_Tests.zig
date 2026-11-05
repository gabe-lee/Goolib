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
const Threading = Root.Threading;
const Locks = Threading.LocksModule;

const LockKind = Locks.LockKind;
const AnyLock = Locks.AnyLock;
const SpinLock = Locks.SpinLock;
const RwSpinLock = Locks.RwSpinLock;
const KeyedSpinLock = Locks.KeyedSpinLock;
const KeyedRwSpinLock = Locks.KeyedRwSpinLock;
const Mutex = Locks.Mutex;
const RwMutex = Locks.RwMutex;
const KeyedMutex = Locks.KeyedMutex;
const KeyedRwMutex = Locks.KeyedRwMutex;

const Io = std.Io;

const ALL_KINDS = [_]LockKind{
    .NONE,
    .SPIN_LOCK,
    .RW_SPIN_LOCK,
    .MUTEX,
    .RW_MUTEX,
    .KEYED_SPIN_LOCK,
    .KEYED_RW_SPIN_LOCK,
    .KEYED_MUTEX,
    .KEYED_RW_MUTEX,
};

/// The kinds that can actually take a write lock. `.NONE` is deliberately excluded.
const WRITE_KINDS = ALL_KINDS[1..];

fn hammer_write_lock(
    comptime KIND: LockKind,
    comptime USE_ASSERTS: bool,
    lock: *KIND.lock_type(USE_ASSERTS),
    io: KIND.io_type(),
    counter: *u64,
    iterations: usize,
) void {
    for (0..iterations) |_| {
        KIND.lock_for_write(USE_ASSERTS, lock, io);
        const current = counter.*;
        std.atomic.spinLoopHint();
        counter.* = current + 1;
        KIND.unlock_for_write(USE_ASSERTS, lock, io);
    }
}

fn expect_mutual_exclusion(comptime KIND: LockKind, comptime USE_ASSERTS: bool, comptime THREAD_COUNT: usize, comptime ITERATIONS: usize) !void {
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();

    const io_value: KIND.io_type() = if (comptime KIND.io_type() == void) {} else threaded.io();
    var lock = KIND.init(USE_ASSERTS);
    var counter: u64 = 0;

    var threads: [THREAD_COUNT]std.Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, hammer_write_lock, .{ KIND, USE_ASSERTS, &lock, io_value, &counter, ITERATIONS });
    }
    for (threads) |thread| thread.join();

    try testing.expectEqual(@as(u64, @intCast(THREAD_COUNT * ITERATIONS)), counter);
}

test "Threading -> spin locks serialize write locks across threads" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        try expect_mutual_exclusion(.SPIN_LOCK, USE_ASSERTS, 4, 2_000);
        try expect_mutual_exclusion(.RW_SPIN_LOCK, USE_ASSERTS, 4, 2_000);
    }
}

test "Threading -> mutex locks serialize write locks across threads" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        try expect_mutual_exclusion(.MUTEX, USE_ASSERTS, 4, 500);
        try expect_mutual_exclusion(.RW_MUTEX, USE_ASSERTS, 4, 500);
    }
}

test "Threading -> keyed locks serialize write locks across threads" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        try expect_mutual_exclusion(.KEYED_SPIN_LOCK, USE_ASSERTS, 4, 2_000);
        try expect_mutual_exclusion(.KEYED_RW_SPIN_LOCK, USE_ASSERTS, 4, 2_000);
        try expect_mutual_exclusion(.KEYED_MUTEX, USE_ASSERTS, 4, 500);
        try expect_mutual_exclusion(.KEYED_RW_MUTEX, USE_ASSERTS, 4, 500);
    }
}

test "Threading -> SpinLock read and write paths share the same lock" {
    var lock = SpinLock{};
    lock.lock_for_read();
    try testing.expectEqual(std.math.maxInt(u32), lock.state);
    lock.unlock_for_read();
    try testing.expectEqual(@as(u32, 0), lock.state);

    lock.lock_for_write();
    try testing.expectEqual(std.math.maxInt(u32), lock.state);
    lock.unlock_for_write();
    try testing.expectEqual(@as(u32, 0), lock.state);
}

test "Threading -> RwSpinLock allows shared readers and an exclusive writer" {
    var lock = RwSpinLock{};

    lock.lock_for_read();
    try testing.expectEqual(@as(u32, 1), lock.state);
    lock.lock_for_read();
    try testing.expectEqual(@as(u32, 2), lock.state);

    lock.unlock_for_read();
    try testing.expectEqual(@as(u32, 1), lock.state);
    lock.unlock_for_read();
    try testing.expectEqual(@as(u32, 0), lock.state);

    lock.lock_for_write();
    try testing.expectEqual(std.math.maxInt(u32), lock.state);
    lock.unlock_for_write();
    try testing.expectEqual(@as(u32, 0), lock.state);
}

test "Threading -> Mutex and RwMutex read and write paths" {
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var mutex = Mutex{};
    mutex.lock_for_read(io);
    mutex.unlock_for_read(io);
    mutex.lock_for_write(io);
    mutex.unlock_for_write(io);

    var rw_mutex = RwMutex{};
    rw_mutex.lock_for_read(io);
    rw_mutex.lock_for_read(io);
    rw_mutex.unlock_for_read(io);
    rw_mutex.unlock_for_read(io);
    rw_mutex.lock_for_write(io);
    rw_mutex.unlock_for_write(io);
}

test "Threading -> KeyedSpinLock write keys lock lazily" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        const Lock = KeyedSpinLock(USE_ASSERTS);
        var lock: Lock = .{};

        lock.lock_for_read();
        lock.unlock_for_read();
        lock.lock_for_write();
        lock.unlock_for_write();

        var key: Lock.WriteKey = .{};
        try testing.expect(key.lock_if_needed(&lock));
        try testing.expect(!key.lock_if_needed(&lock));
        key.unlock_if_needed(false);
        key.unlock();

        var direct_read = lock.keyed_lock_for_read();
        direct_read.unlock();
        var direct_write = lock.keyed_lock_for_write();
        direct_write.unlock();
    }
}

test "Threading -> KeyedRwSpinLock read and write keys lock lazily" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        const Lock = KeyedRwSpinLock(USE_ASSERTS);
        var lock: Lock = .{};

        lock.lock_for_read();
        lock.unlock_for_read();
        lock.lock_for_write();
        lock.unlock_for_write();

        var read_a: Lock.ReadKey = .{};
        var read_b: Lock.ReadKey = .{};
        try testing.expect(read_a.lock_if_needed(&lock));
        try testing.expect(!read_a.lock_if_needed(&lock));
        try testing.expect(read_b.lock_if_needed(&lock));
        read_a.unlock_if_needed(false);
        read_a.unlock();
        read_b.unlock_if_needed(true);

        var write_key: Lock.WriteKey = .{};
        try testing.expect(write_key.lock_if_needed(&lock));
        try testing.expect(!write_key.lock_if_needed(&lock));
        write_key.unlock_if_needed(true);

        var direct_read = lock.keyed_lock_for_read();
        direct_read.unlock();
        var direct_write = lock.keyed_lock_for_write();
        direct_write.unlock();
    }
}

test "Threading -> KeyedMutex write keys lock lazily" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        var threaded: std.Io.Threaded = .init(testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        const Lock = KeyedMutex(USE_ASSERTS);
        var lock: Lock = .{};

        lock.lock_for_read(io);
        lock.unlock_for_read(io);
        lock.lock_for_write(io);
        lock.unlock_for_write(io);

        var key: Lock.WriteKey = .{};
        try testing.expect(key.lock_if_needed(&lock, io));
        try testing.expect(!key.lock_if_needed(&lock, io));
        key.unlock_if_needed(false, io);
        key.unlock(io);

        var read_key: Lock.WriteKey = .{};
        try testing.expect(read_key.lock_if_needed(&lock, io));
        read_key.unlock(io);

        var direct_read = lock.keyed_lock_for_read(io);
        direct_read.unlock(io);
        var direct_write = lock.keyed_lock_for_write(io);
        direct_write.unlock(io);
    }
}

test "Threading -> KeyedRwMutex read and write keys lock lazily" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        var threaded: std.Io.Threaded = .init(testing.allocator, .{});
        defer threaded.deinit();
        const io = threaded.io();

        const Lock = KeyedRwMutex(USE_ASSERTS);
        var lock: Lock = .{};

        lock.lock_for_read(io);
        lock.unlock_for_read(io);
        lock.lock_for_write(io);
        lock.unlock_for_write(io);

        var read_a: Lock.ReadKey = .{};
        var read_b: Lock.ReadKey = .{};
        try testing.expect(read_a.lock_if_needed(&lock, io));
        try testing.expect(!read_a.lock_if_needed(&lock, io));
        try testing.expect(read_b.lock_if_needed(&lock, io));
        read_a.unlock_if_needed(false, io);
        read_a.unlock(io);
        read_b.unlock_if_needed(true, io);

        var write_key: Lock.WriteKey = .{};
        try testing.expect(write_key.lock_if_needed(&lock, io));
        try testing.expect(!write_key.lock_if_needed(&lock, io));
        write_key.unlock_if_needed(true, io);

        var direct_read = lock.keyed_lock_for_read(io);
        direct_read.unlock(io);
        var direct_write = lock.keyed_lock_for_write(io);
        direct_write.unlock(io);
    }
}

test "Threading -> AnyLock supports every lock kind" {
    inline for (.{ true, false }) |USE_ASSERTS| {
        inline for (ALL_KINDS) |KIND| {
            var threaded: std.Io.Threaded = .init(testing.allocator, .{});
            defer threaded.deinit();
            const io = threaded.io();

            var any: AnyLock(USE_ASSERTS) = @unionInit(AnyLock(USE_ASSERTS), @tagName(KIND), KIND.init(USE_ASSERTS));
            any.lock_for_read(io);
            any.unlock_for_read(io);
            any.lock_for_write(io);
            any.unlock_for_write(io);
        }
    }
}

test "Threading -> LockKind helper types and initialization" {
    inline for (ALL_KINDS) |KIND| {
        inline for (.{ true, false }) |USE_ASSERTS| {
            const Lock = KIND.lock_type(USE_ASSERTS);
            var lock: Lock = KIND.init(USE_ASSERTS);

            const read_unlock_ptr: KIND.keyed_read_unlock_ptr_type(USE_ASSERTS) = undefined;
            const write_unlock_ptr: KIND.keyed_write_unlock_ptr_type(USE_ASSERTS) = undefined;
            const read_lock: KIND.keyed_read_lock_type(USE_ASSERTS) = undefined;
            const write_lock: KIND.keyed_write_lock_type(USE_ASSERTS) = undefined;
            _ = read_unlock_ptr;
            _ = write_unlock_ptr;
            _ = read_lock;
            _ = write_lock;

            if (comptime KIND.has_lock()) {
                const lock_ptr: KIND.lock_ptr_type(USE_ASSERTS) = &lock;
                _ = lock_ptr;
            } else {
                try testing.expect(Lock == void);
            }
        }
    }
}

test "Threading -> get_this_thread_id is stable and non-zero" {
    const first = Threading.get_this_thread_id();
    try testing.expect(first > 0);
    try testing.expectEqual(first, Threading.get_this_thread_id());

    const ThreadId = struct {
        fn run(id: *u32) void {
            id.* = Threading.get_this_thread_id();
        }
    };

    var other_id: u32 = 0;
    const thread = try std.Thread.spawn(.{}, ThreadId.run, .{&other_id});
    thread.join();

    try testing.expect(other_id > 0);
    try testing.expect(other_id != first);
}
