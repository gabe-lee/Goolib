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
const build = @import("builtin");
const assert = std.debug.assert;
const Type = std.lang.Type;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Types = Root.Types;
const Vec2 = Root.Vec2;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const num_cast = Root.Cast.num_cast;
const bit_cast = Root.Cast.bit_cast;
pub const UnsignedIntegerWithSameSize = Types.UnsignedIntegerWithSameSize;
pub const SignedIntegerWithSameSize = Types.SignedIntegerWithSameSize;
const DEBUG = std.debug.print;
const Math = @This();
const Cast = Root.Cast;
const real_cast = Cast.real_cast;
const real_type = Types.real_type;
const real_type_of = Types.real_type_of;
const Io = std.Io;
const IoMutex = std.Io.Mutex;
const IoRwMutex = std.Io.RwLock;
const Threading = Root.Threading;
const get_this_thread_id = Threading.get_this_thread_id;

pub const LockKind = enum {
    NONE,
    SPIN_LOCK,
    RW_SPIN_LOCK,
    MUTEX,
    RW_MUTEX,
    KEYED_SPIN_LOCK,
    KEYED_RW_SPIN_LOCK,
    KEYED_MUTEX,
    KEYED_RW_MUTEX,

    pub inline fn has_lock(self: LockKind) bool {
        return self != .NONE;
    }

    pub fn lock_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => SpinLock,
            .RW_SPIN_LOCK => RwSpinLock,
            .MUTEX => Mutex,
            .RW_MUTEX => RwMutex,
            .KEYED_SPIN_LOCK => KeyedSpinLock(USE_ASSERTS),
            .KEYED_RW_SPIN_LOCK => KeyedRwSpinLock(USE_ASSERTS),
            .KEYED_MUTEX => KeyedMutex(USE_ASSERTS),
            .KEYED_RW_MUTEX => KeyedRwMutex(USE_ASSERTS),
        };
    }
    pub fn lock_ptr_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
            .KEYED_SPIN_LOCK => *KeyedSpinLock(USE_ASSERTS),
            .KEYED_RW_SPIN_LOCK => *KeyedRwSpinLock(USE_ASSERTS),
            .KEYED_MUTEX => *KeyedMutex(USE_ASSERTS),
            .KEYED_RW_MUTEX => *KeyedRwMutex(USE_ASSERTS),
        };
    }
    pub fn opt_lock_ptr_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => ?*SpinLock,
            .RW_SPIN_LOCK => ?*RwSpinLock,
            .MUTEX => ?*Mutex,
            .RW_MUTEX => ?*RwMutex,
            .KEYED_SPIN_LOCK => ?*KeyedSpinLock(USE_ASSERTS),
            .KEYED_RW_SPIN_LOCK => ?*KeyedRwSpinLock(USE_ASSERTS),
            .KEYED_MUTEX => ?*KeyedMutex(USE_ASSERTS),
            .KEYED_RW_MUTEX => ?*KeyedRwMutex(USE_ASSERTS),
        };
    }
    pub fn keyed_read_unlock_ptr_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
            .KEYED_SPIN_LOCK => *KeyedSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_RW_SPIN_LOCK => *KeyedRwSpinLock(USE_ASSERTS).ReadKey,
            .KEYED_MUTEX => *KeyedMutex(USE_ASSERTS).WriteKey,
            .KEYED_RW_MUTEX => *KeyedRwMutex(USE_ASSERTS).ReadKey,
        };
    }
    pub fn keyed_write_unlock_ptr_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
            .KEYED_SPIN_LOCK => *KeyedSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_RW_SPIN_LOCK => *KeyedRwSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_MUTEX => *KeyedMutex(USE_ASSERTS).WriteKey,
            .KEYED_RW_MUTEX => *KeyedRwMutex(USE_ASSERTS).WriteKey,
        };
    }
    pub fn keyed_read_lock_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
            .KEYED_SPIN_LOCK => *KeyedSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_RW_SPIN_LOCK => *KeyedRwSpinLock(USE_ASSERTS).ReadKey,
            .KEYED_MUTEX => *KeyedMutex(USE_ASSERTS).WriteKey,
            .KEYED_RW_MUTEX => *KeyedRwMutex(USE_ASSERTS).ReadKey,
        };
    }
    pub fn keyed_write_lock_type(comptime self: LockKind, comptime USE_ASSERTS: bool) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
            .KEYED_SPIN_LOCK => *KeyedSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_RW_SPIN_LOCK => *KeyedRwSpinLock(USE_ASSERTS).WriteKey,
            .KEYED_MUTEX => *KeyedMutex(USE_ASSERTS).WriteKey,
            .KEYED_RW_MUTEX => *KeyedRwMutex(USE_ASSERTS).WriteKey,
        };
    }
    pub fn io_type(comptime self: LockKind) type {
        return switch (comptime self) {
            .NONE, .RW_SPIN_LOCK, .SPIN_LOCK, .KEYED_SPIN_LOCK, .KEYED_RW_SPIN_LOCK => void,
            .MUTEX, .RW_MUTEX, .KEYED_MUTEX, .KEYED_RW_MUTEX => Io,
        };
    }
    pub fn get_lock_ptr(comptime self: LockKind, comptime USE_ASSERTS: bool, container: anytype, comptime field: []const u8) self.lock_ptr_type(USE_ASSERTS) {
        return switch (comptime self) {
            .NONE => {},
            else => {
                return &@field(container, field);
            },
        };
    }
    pub fn init(comptime self: LockKind, comptime USE_ASSERTS: bool) self.lock_type(USE_ASSERTS) {
        return switch (comptime self) {
            .NONE => {},
            .SPIN_LOCK => SpinLock{},
            .RW_SPIN_LOCK => RwSpinLock{},
            .MUTEX => Mutex{},
            .RW_MUTEX => RwMutex{},
            .KEYED_SPIN_LOCK => KeyedSpinLock(USE_ASSERTS){},
            .KEYED_RW_SPIN_LOCK => KeyedRwSpinLock(USE_ASSERTS){},
            .KEYED_MUTEX => KeyedMutex(USE_ASSERTS){},
            .KEYED_RW_MUTEX => KeyedRwMutex(USE_ASSERTS){},
        };
    }
    pub fn null_opt_ptr(comptime self: LockKind, comptime USE_ASSERTS: bool) self.opt_lock_ptr_type(USE_ASSERTS) {
        return switch (comptime self) {
            .NONE => {},
            .SPIN_LOCK => null,
            .RW_SPIN_LOCK => null,
            .MUTEX => null,
            .RW_MUTEX => null,
            .KEYED_SPIN_LOCK => null,
            .KEYED_RW_SPIN_LOCK => null,
            .KEYED_MUTEX => null,
            .KEYED_RW_MUTEX => null,
        };
    }
    pub fn lock_for_read(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_read(),
            .RW_SPIN_LOCK => lock.lock_for_read(),
            .MUTEX => lock.lock_for_read(io),
            .RW_MUTEX => lock.lock_for_read(io),
            .KEYED_SPIN_LOCK => lock.lock_for_read(),
            .KEYED_RW_SPIN_LOCK => lock.lock_for_read(),
            .KEYED_MUTEX => lock.lock_for_read(io),
            .KEYED_RW_MUTEX => lock.lock_for_read(io),
        }
    }
    pub fn unlock_for_read(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_read(),
            .RW_SPIN_LOCK => lock.unlock_for_read(),
            .MUTEX => lock.unlock_for_read(io),
            .RW_MUTEX => lock.unlock_for_read(io),
            .KEYED_SPIN_LOCK => lock.unlock_for_read(),
            .KEYED_RW_SPIN_LOCK => lock.unlock_for_read(),
            .KEYED_MUTEX => lock.unlock_for_read(io),
            .KEYED_RW_MUTEX => lock.unlock_for_read(io),
        }
    }
    pub fn lock_for_write(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_write(),
            .RW_SPIN_LOCK => lock.lock_for_write(),
            .MUTEX => lock.lock_for_write(io),
            .RW_MUTEX => lock.lock_for_write(io),
            .KEYED_SPIN_LOCK => lock.lock_for_write(),
            .KEYED_RW_SPIN_LOCK => lock.lock_for_write(),
            .KEYED_MUTEX => lock.lock_for_write(io),
            .KEYED_RW_MUTEX => lock.lock_for_write(io),
        }
    }
    pub fn unlock_for_write(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_write(),
            .RW_SPIN_LOCK => lock.unlock_for_write(),
            .MUTEX => lock.unlock_for_write(io),
            .RW_MUTEX => lock.unlock_for_write(io),
            .KEYED_SPIN_LOCK => lock.unlock_for_write(),
            .KEYED_RW_SPIN_LOCK => lock.unlock_for_write(),
            .KEYED_MUTEX => lock.unlock_for_write(io),
            .KEYED_RW_MUTEX => lock.unlock_for_write(io),
        }
    }
    pub fn lock_for_read_io(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_read(),
            .RW_SPIN_LOCK => lock.lock_for_read(),
            .MUTEX => lock.lock_for_read(io),
            .RW_MUTEX => lock.lock_for_read(io),
            .KEYED_SPIN_LOCK => lock.lock_for_read(),
            .KEYED_RW_SPIN_LOCK => lock.lock_for_read(),
            .KEYED_MUTEX => lock.lock_for_read(io),
            .KEYED_RW_MUTEX => lock.lock_for_read(io),
        }
    }
    pub fn unlock_for_read_io(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_read(),
            .RW_SPIN_LOCK => lock.unlock_for_read(),
            .MUTEX => lock.unlock_for_read(io),
            .RW_MUTEX => lock.unlock_for_read(io),
            .KEYED_SPIN_LOCK => lock.unlock_for_read(),
            .KEYED_RW_SPIN_LOCK => lock.unlock_for_read(),
            .KEYED_MUTEX => lock.unlock_for_read(io),
            .KEYED_RW_MUTEX => lock.unlock_for_read(io),
        }
    }
    pub fn lock_for_write_io(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_write(),
            .RW_SPIN_LOCK => lock.lock_for_write(),
            .MUTEX => lock.lock_for_write(io),
            .RW_MUTEX => lock.lock_for_write(io),
            .KEYED_SPIN_LOCK => lock.lock_for_write(),
            .KEYED_RW_SPIN_LOCK => lock.lock_for_write(),
            .KEYED_MUTEX => lock.lock_for_write(io),
            .KEYED_RW_MUTEX => lock.lock_for_write(io),
        }
    }
    pub fn unlock_for_write_io(comptime KIND: LockKind, comptime USE_ASSERTS: bool, lock: KIND.lock_ptr_type(USE_ASSERTS), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_write(),
            .RW_SPIN_LOCK => lock.unlock_for_write(),
            .MUTEX => lock.unlock_for_write(io),
            .RW_MUTEX => lock.unlock_for_write(io),
            .KEYED_SPIN_LOCK => lock.unlock_for_write(),
            .KEYED_RW_SPIN_LOCK => lock.unlock_for_write(),
            .KEYED_MUTEX => lock.unlock_for_write(io),
            .KEYED_RW_MUTEX => lock.unlock_for_write(io),
        }
    }
};

pub fn AnyLock(comptime USE_ASSERT: bool) type {
    return union(LockKind) {
        const Self = @This();

        NONE: void,
        SPIN_LOCK: SpinLock,
        RW_SPIN_LOCK: RwSpinLock,
        MUTEX: Mutex,
        RW_MUTEX: RwMutex,
        KEYED_SPIN_LOCK: KeyedSpinLock(USE_ASSERT),
        KEYED_RW_SPIN_LOCK: KeyedRwSpinLock(USE_ASSERT),
        KEYED_MUTEX: KeyedMutex(USE_ASSERT),
        KEYED_RW_MUTEX: KeyedRwMutex(USE_ASSERT),

        pub fn lock_for_read(self: *Self, io: Io) void {
            switch (self.*) {
                .NONE => {},
                .SPIN_LOCK => |*lock| lock.lock_for_read(),
                .RW_SPIN_LOCK => |*lock| lock.lock_for_read(),
                .MUTEX => |*lock| lock.lock_for_read(io),
                .RW_MUTEX => |*lock| lock.lock_for_read(io),
                .KEYED_SPIN_LOCK => |*lock| lock.lock_for_read(),
                .KEYED_RW_SPIN_LOCK => |*lock| lock.lock_for_read(),
                .KEYED_MUTEX => |*lock| lock.lock_for_read(io),
                .KEYED_RW_MUTEX => |*lock| lock.lock_for_read(io),
            }
        }
        pub fn unlock_for_read(self: *Self, io: Io) void {
            switch (self.*) {
                .NONE => {},
                .SPIN_LOCK => |*lock| lock.unlock_for_read(),
                .RW_SPIN_LOCK => |*lock| lock.unlock_for_read(),
                .MUTEX => |*lock| lock.unlock_for_read(io),
                .RW_MUTEX => |*lock| lock.unlock_for_read(io),
                .KEYED_SPIN_LOCK => |*lock| lock.unlock_for_read(),
                .KEYED_RW_SPIN_LOCK => |*lock| lock.unlock_for_read(),
                .KEYED_MUTEX => |*lock| lock.unlock_for_read(io),
                .KEYED_RW_MUTEX => |*lock| lock.unlock_for_read(io),
            }
        }
        pub fn lock_for_write(self: *Self, io: Io) void {
            switch (self.*) {
                .NONE => {},
                .SPIN_LOCK => |*lock| lock.lock_for_write(),
                .RW_SPIN_LOCK => |*lock| lock.lock_for_write(),
                .MUTEX => |*lock| lock.lock_for_write(io),
                .RW_MUTEX => |*lock| lock.lock_for_write(io),
                .KEYED_SPIN_LOCK => |*lock| lock.lock_for_write(),
                .KEYED_RW_SPIN_LOCK => |*lock| lock.lock_for_write(),
                .KEYED_MUTEX => |*lock| lock.lock_for_write(io),
                .KEYED_RW_MUTEX => |*lock| lock.lock_for_write(io),
            }
        }
        pub fn unlock_for_write(self: *Self, io: Io) void {
            switch (self.*) {
                .NONE => {},
                .SPIN_LOCK => |*lock| lock.unlock_for_write(),
                .RW_SPIN_LOCK => |*lock| lock.unlock_for_write(),
                .MUTEX => |*lock| lock.unlock_for_write(io),
                .RW_MUTEX => |*lock| lock.unlock_for_write(io),
                .KEYED_SPIN_LOCK => |*lock| lock.unlock_for_write(),
                .KEYED_RW_SPIN_LOCK => |*lock| lock.unlock_for_write(),
                .KEYED_MUTEX => |*lock| lock.unlock_for_write(io),
                .KEYED_RW_MUTEX => |*lock| lock.unlock_for_write(io),
            }
        }
    };
}

pub const SpinLock = struct {
    state: u32 = 0,

    const WRITE = math.maxInt(u32);

    pub inline fn lock_for_read(self: *SpinLock) void {
        self.lock_for_write();
    }
    pub inline fn unlock_for_read(self: *SpinLock) void {
        self.unlock_for_write();
    }
    pub fn lock_for_write(self: *SpinLock) void {
        while (true) {
            if (@atomicLoad(u32, &self.state, .monotonic) != 0) {
                std.atomic.spinLoopHint();
                continue;
            }
            if (@cmpxchgWeak(u32, &self.state, 0, WRITE, .acquire, .monotonic)) |_| {
                std.atomic.spinLoopHint();
            } else {
                return;
            }
        }
    }
    pub inline fn unlock_for_write(self: *SpinLock) void {
        _ = @atomicRmw(u32, &self.state, .Xchg, 0, .release);
    }
};

pub fn KeyedSpinLock(comptime ENABLE_ASSERTS: bool) type {
    return struct {
        const Self = @This();

        lock: SpinLock = .{},
        write_owner: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

        var next_id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 1 else {};

        pub const WriteKey = struct {
            ptr: ?*Self = null,
            id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

            /// Returns the new key (or same if key already has the same mutex pointer), and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *WriteKey, lock: *Self) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_write();
                    self.ptr = new_key.ptr;
                    self.id = new_key.id;
                    return true;
                }
            }

            pub fn unlock(self: *WriteKey) void {
                if (ENABLE_ASSERTS) {
                    assert_with_reason(self.ptr != null, @src(), "KeyedSpinLock Key was improperly created or was already unlocked", .{});
                    assert_with_reason(self.ptr.?.write_owner == self.id, @src(), "attempted to unlock a KeyedSpinLock with a Key that did not originally lock it", .{});
                    self.id = 0;
                    self.ptr.?.write_owner = 0;
                }
                self.ptr.?.lock.unlock_for_write();
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *WriteKey, needed: bool) void {
                if (needed) {
                    self.unlock();
                }
            }
        };

        pub inline fn keyed_lock_for_read(self: *Self) WriteKey {
            return self.keyed_lock_for_write();
        }
        pub fn keyed_lock_for_write(self: *Self) WriteKey {
            self.lock.lock_for_write();
            if (ENABLE_ASSERTS) {
                Self.next_id +%= 1;
                Self.next_id = @max(1, Self.next_id);
                self.write_owner = Self.next_id;
            }
            return WriteKey{
                .ptr = self,
                .id = if (ENABLE_ASSERTS) self.write_owner else {},
            };
        }

        pub inline fn lock_for_read(self: *Self) void {
            self.lock_for_write();
        }
        pub inline fn lock_for_write(self: *Self) void {
            self.lock.lock_for_write();
        }
        pub inline fn unlock_for_read(self: *Self) void {
            self.unlock_for_write();
        }
        pub inline fn unlock_for_write(self: *Self) void {
            self.lock.unlock_for_write();
        }
    };
}

pub const RwSpinLock = struct {
    state: u32 = 0,

    const WRITE = math.maxInt(u32);
    const MAX_READ = WRITE - 1;

    pub fn lock_for_read(self: *RwSpinLock) void {
        var current = @atomicLoad(u32, &self.state, .monotonic);
        while (true) {
            if (current >= MAX_READ) {
                std.atomic.spinLoopHint();
                current = @atomicLoad(u32, &self.state, .monotonic);
                continue;
            }
            if (@cmpxchgWeak(u32, &self.state, current, current + 1, .acquire, .monotonic)) |updated_current| {
                current = updated_current;
                std.atomic.spinLoopHint();
            } else {
                return;
            }
        }
    }
    pub inline fn unlock_for_read(self: *RwSpinLock) void {
        _ = @atomicRmw(u32, &self.state, .Sub, 1, .release);
    }
    pub fn lock_for_write(self: *RwSpinLock) void {
        while (true) {
            if (@atomicLoad(u32, &self.state, .monotonic) != 0) {
                std.atomic.spinLoopHint();
                continue;
            }
            if (@cmpxchgWeak(u32, &self.state, 0, WRITE, .acquire, .monotonic)) |_| {
                std.atomic.spinLoopHint();
            } else {
                return;
            }
        }
    }
    pub inline fn unlock_for_write(self: *RwSpinLock) void {
        _ = @atomicRmw(u32, &self.state, .Xchg, 0, .release);
    }
};

pub fn KeyedRwSpinLock(comptime ENABLE_ASSERTS: bool) type {
    return struct {
        const Self = @This();

        lock: RwSpinLock = .{},
        write_owner_id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 1 else {},

        pub const WriteKey = struct {
            ptr: ?*Self = null,
            id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

            /// Locks the lock an updates the key, and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *WriteKey, lock: *Self) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_write();
                    self.ptr = new_key.ptr;
                    self.id = new_key.id;
                    return true;
                }
            }

            pub fn unlock(self: *WriteKey) void {
                if (ENABLE_ASSERTS) {
                    assert_with_reason(self.ptr != null, @src(), "KeyedRwSpinLock Key was improperly created or was already unlocked", .{});
                    assert_with_reason(self.ptr.?.write_owner_id == self.id, @src(), "attempted to unlock a KeyedRwSpinLock with a Key that did not originally lock it", .{});
                    self.id = 0;
                    self.ptr.?.write_owner_id +%= 1;
                    self.ptr.?.write_owner_id = @max(1, self.ptr.?.write_owner_id);
                }
                self.ptr.?.lock.unlock_for_write();
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *WriteKey, needed: bool) void {
                if (needed) {
                    self.unlock();
                }
            }
        };

        pub const ReadKey = struct {
            ptr: ?*Self = null,

            /// Returns the new key (or same if key already has the same mutex pointer), and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *ReadKey, lock: *Self) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_read();
                    self.ptr = new_key.ptr;
                    return true;
                }
            }

            pub fn unlock(self: *ReadKey) void {
                if (ENABLE_ASSERTS) {
                    assert_with_reason(self.ptr != null, @src(), "KeyedRwSpinLock Key was improperly created or was already unlocked", .{});
                }
                self.ptr.?.lock.unlock_for_read();
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *ReadKey, needed: bool) void {
                if (needed) {
                    self.unlock();
                }
            }
        };

        pub inline fn keyed_lock_for_read(self: *Self) ReadKey {
            self.lock.lock_for_read();
            return ReadKey{
                .ptr = self,
            };
        }
        pub inline fn keyed_lock_for_write(self: *Self) WriteKey {
            self.lock.lock_for_write();
            return WriteKey{
                .ptr = self,
                .id = if (ENABLE_ASSERTS) self.write_owner_id else {},
            };
        }

        pub inline fn lock_for_read(self: *Self) void {
            self.lock.lock_for_read();
        }
        pub inline fn lock_for_write(self: *Self) void {
            self.lock.lock_for_write();
        }
        pub inline fn unlock_for_read(self: *Self) void {
            self.lock.unlock_for_read();
        }
        pub inline fn unlock_for_write(self: *Self) void {
            self.lock.unlock_for_write();
        }
    };
}

pub const Mutex = struct {
    mtx: IoMutex = IoMutex.init,

    pub fn lock_for_read(self: *Mutex, io: Io) void {
        self.mtx.lockUncancelable(io);
    }
    pub inline fn unlock_for_read(self: *Mutex, io: Io) void {
        self.mtx.unlock(io);
    }
    pub fn lock_for_write(self: *Mutex, io: Io) void {
        self.mtx.lockUncancelable(io);
    }
    pub inline fn unlock_for_write(self: *Mutex, io: Io) void {
        self.mtx.unlock(io);
    }
};

pub fn KeyedMutex(comptime ENABLE_ASSERTS: bool) type {
    return struct {
        const Self = @This();

        lock: Mutex = .{},
        write_owner_id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 1 else {},
        thread_locked_on: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

        pub const WriteKey = struct {
            ptr: ?*Self = null,
            id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

            /// Locks the lock an updates the key, and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *WriteKey, lock: *Self, io: Io) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_write(io);
                    self.ptr = new_key.ptr;
                    self.id = new_key.id;
                    return true;
                }
            }

            pub fn unlock(self: *WriteKey, io: Io) void {
                if (ENABLE_ASSERTS) {
                    const this_thread_id = get_this_thread_id();
                    assert_with_reason(self.ptr != null, @src(), "KeyedMutex Key was improperly created or was already unlocked", .{});
                    assert_with_reason(@atomicLoad(u32, &self.ptr.?.thread_locked_on, .monotonic) == this_thread_id, @src(), "attempted to unlock a KeyedMutex on a thread it was not originally locked on", .{});
                    assert_with_reason(@atomicLoad(u32, &self.ptr.?.write_owner_id, .monotonic) == self.id, @src(), "attempted to unlock a KeyedMutex with a Key that did not originally lock it", .{});
                    self.id = 0;
                    self.ptr.?.write_owner_id +%= 1;
                    self.ptr.?.write_owner_id = @max(1, self.ptr.?.write_owner_id);
                    self.ptr.?.thread_locked_on = 0;
                }
                self.ptr.?.lock.unlock_for_write(io);
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *WriteKey, needed: bool, io: Io) void {
                if (needed) {
                    self.unlock(io);
                }
            }
        };
        pub inline fn keyed_lock_for_read(self: *Self, io: Io) WriteKey {
            return self.keyed_lock_for_write(io);
        }
        pub inline fn keyed_lock_for_write(self: *Self, io: Io) WriteKey {
            self.lock.lock_for_write(io);
            if (ENABLE_ASSERTS) {
                self.thread_locked_on = get_this_thread_id();
            }
            return WriteKey{
                .ptr = self,
                .id = if (ENABLE_ASSERTS) self.write_owner_id else {},
            };
        }
        pub inline fn lock_for_read(self: *Self, io: Io) void {
            return self.lock_for_write(io);
        }
        pub inline fn lock_for_write(self: *Self, io: Io) void {
            self.lock.lock_for_write(io);
            if (ENABLE_ASSERTS) {
                self.thread_locked_on = get_this_thread_id();
            }
        }
        pub inline fn unlock_for_read(self: *Self, io: Io) void {
            return self.unlock_for_write(io);
        }
        pub inline fn unlock_for_write(self: *Self, io: Io) void {
            if (ENABLE_ASSERTS) {
                const this_thread_id = get_this_thread_id();
                assert_with_reason(self.thread_locked_on == this_thread_id, @src(), "attempted to unlock a KeyedMutex on a thread it was not originally locked on", .{});
                self.thread_locked_on = 0;
            }
            self.lock.unlock_for_write(io);
        }
    };
}

pub const RwMutex = struct {
    mtx: IoRwMutex = IoRwMutex.init,

    pub fn lock_for_read(self: *RwMutex, io: Io) void {
        self.mtx.lockSharedUncancelable(io);
    }
    pub inline fn unlock_for_read(self: *RwMutex, io: Io) void {
        self.mtx.unlockShared(io);
    }
    pub fn lock_for_write(self: *RwMutex, io: Io) void {
        self.mtx.lockUncancelable(io);
    }
    pub inline fn unlock_for_write(self: *RwMutex, io: Io) void {
        self.mtx.unlock(io);
    }
};

pub fn KeyedRwMutex(comptime ENABLE_ASSERTS: bool) type {
    return struct {
        const Self = @This();

        lock: RwMutex = .{},
        write_owner_id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 1 else {},
        thread_locked_on: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

        pub const WriteKey = struct {
            ptr: ?*Self = null,
            id: if (ENABLE_ASSERTS) u32 else void = if (ENABLE_ASSERTS) 0 else {},

            /// Locks the lock an updates the key, and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *WriteKey, lock: *Self, io: Io) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_write(io);
                    self.ptr = new_key.ptr;
                    self.id = new_key.id;
                    return true;
                }
            }

            pub fn unlock(self: *WriteKey, io: Io) void {
                if (ENABLE_ASSERTS) {
                    const this_thread_id = get_this_thread_id();
                    assert_with_reason(self.ptr != null, @src(), "KeyedRwMutex Key was improperly created or was already unlocked", .{});
                    assert_with_reason(@atomicLoad(u32, &self.ptr.?.thread_locked_on, .monotonic) == this_thread_id, @src(), "attempted to unlock a KeyedRwMutex on a thread it was not originally locked on", .{});
                    assert_with_reason(@atomicLoad(u32, &self.ptr.?.write_owner_id, .monotonic) == self.id, @src(), "attempted to unlock a KeyedRwMutex with a Key that did not originally lock it", .{});
                    self.id = 0;
                    self.ptr.?.write_owner_id +%= 1;
                    self.ptr.?.write_owner_id = @max(1, self.ptr.?.write_owner_id);
                    self.ptr.?.thread_locked_on = 0;
                }
                self.ptr.?.lock.unlock_for_write(io);
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *WriteKey, needed: bool, io: Io) void {
                if (needed) {
                    self.unlock(io);
                }
            }
        };

        pub const ReadKey = struct {
            ptr: ?*Self = null,

            /// Returns the new key (or same if key already has the same mutex pointer), and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: *ReadKey, lock: *Self, io: Io) bool {
                if (self.ptr) |p| {
                    if (ENABLE_ASSERTS) {
                        const this_addr = @intFromPtr(p);
                        const lock_addr = @intFromPtr(lock);
                        assert_with_reason(this_addr == lock_addr, @src(), "attempted to 'lock if needed' a key with a lock pointer that does not match the provided lock pointer: you probably have a logic error somewhere", .{});
                    }
                    return false;
                } else {
                    const new_key = lock.keyed_lock_for_read(io);
                    self.ptr = new_key.ptr;
                    return true;
                }
            }

            pub fn unlock(self: *ReadKey, io: Io) void {
                if (ENABLE_ASSERTS) {
                    assert_with_reason(self.ptr != null, @src(), "KeyedRwMutex Key was improperly created or was already unlocked", .{});
                }
                self.ptr.?.lock.unlock_for_read(io);
                self.ptr = null;
            }

            pub fn unlock_if_needed(self: *ReadKey, needed: bool, io: Io) void {
                if (needed) {
                    self.unlock(io);
                }
            }
        };

        pub inline fn keyed_lock_for_read(self: *Self, io: Io) ReadKey {
            self.lock.lock_for_read(io);
            return ReadKey{
                .ptr = self,
            };
        }

        pub fn keyed_lock_for_write(self: *Self, io: Io) WriteKey {
            self.lock.lock_for_write(io);
            if (ENABLE_ASSERTS) {
                self.thread_locked_on = get_this_thread_id();
            }
            return WriteKey{
                .ptr = self,
                .id = if (ENABLE_ASSERTS) self.write_owner_id else {},
            };
        }

        pub inline fn lock_for_read(self: *Self, io: Io) void {
            self.lock.lock_for_read(io);
        }

        pub inline fn lock_for_write(self: *Self, io: Io) void {
            self.lock.lock_for_write(io);
            if (ENABLE_ASSERTS) {
                self.thread_locked_on = get_this_thread_id();
            }
        }

        pub inline fn unlock_for_read(self: *Self, io: Io) void {
            self.lock.unlock_for_read(io);
        }

        pub inline fn unlock_for_write(self: *Self, io: Io) void {
            if (ENABLE_ASSERTS) {
                const this_thread_id = get_this_thread_id();
                assert_with_reason(self.thread_locked_on == this_thread_id, @src(), "attempted to unlock a KeyedRwMutex on a thread it was not originally locked on", .{});
                self.thread_locked_on = 0;
            }
            self.lock.unlock_for_write(io);
        }
    };
}
