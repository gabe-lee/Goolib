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

comptime {
    if (build.is_test) {
        _ = @import("./Math_Tests.zig");
    }
}

const std = @import("std");
const math = std.math;
const build = @import("builtin");
const assert = std.debug.assert;
const Type = std.builtin.Type;

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

pub const LockKind = enum {
    NONE,
    SPIN_LOCK,
    RW_SPIN_LOCK,
    MUTEX,
    RW_MUTEX,

    pub inline fn has_lock(self: LockKind) bool {
        return self != .NONE;
    }

    pub fn lock_type(comptime self: LockKind) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => SpinLock,
            .RW_SPIN_LOCK => RwSpinLock,
            .MUTEX => Mutex,
            .RW_MUTEX => RwMutex,
        };
    }
    pub fn lock_ptr_type(comptime self: LockKind) type {
        return switch (comptime self) {
            .NONE => void,
            .SPIN_LOCK => *SpinLock,
            .RW_SPIN_LOCK => *RwSpinLock,
            .MUTEX => *Mutex,
            .RW_MUTEX => *RwMutex,
        };
    }
    pub fn io_type(comptime self: LockKind) type {
        return switch (comptime self) {
            .NONE, .RW_SPIN_LOCK, .SPIN_LOCK => void,
            .MUTEX, .RW_MUTEX => Io,
        };
    }
    pub fn init(comptime self: LockKind) self.lock_type() {
        return switch (comptime self) {
            .NONE => {},
            .SPIN_LOCK => SpinLock{},
            .RW_SPIN_LOCK => RwSpinLock{},
            .MUTEX => Mutex{},
            .RW_MUTEX => RwMutex{},
        };
    }
    pub fn lock_for_read(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_read(),
            .RW_SPIN_LOCK => lock.lock_for_read(),
            .MUTEX => lock.lock_for_read(io),
            .RW_MUTEX => lock.lock_for_read(io),
        }
    }
    pub fn unlock_for_read(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_read(),
            .RW_SPIN_LOCK => lock.unlock_for_read(),
            .MUTEX => lock.unlock_for_read(io),
            .RW_MUTEX => lock.unlock_for_read(io),
        }
    }
    pub fn lock_for_write(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_write(),
            .RW_SPIN_LOCK => lock.lock_for_write(),
            .MUTEX => lock.lock_for_write(io),
            .RW_MUTEX => lock.lock_for_write(io),
        }
    }
    pub fn unlock_for_write(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: KIND.io_type()) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_write(),
            .RW_SPIN_LOCK => lock.unlock_for_write(),
            .MUTEX => lock.unlock_for_write(io),
            .RW_MUTEX => lock.unlock_for_write(io),
        }
    }
    pub fn lock_for_read_io(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_read(),
            .RW_SPIN_LOCK => lock.lock_for_read(),
            .MUTEX => lock.lock_for_read(io),
            .RW_MUTEX => lock.lock_for_read(io),
        }
    }
    pub fn unlock_for_read_io(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_read(),
            .RW_SPIN_LOCK => lock.unlock_for_read(),
            .MUTEX => lock.unlock_for_read(io),
            .RW_MUTEX => lock.unlock_for_read(io),
        }
    }
    pub fn lock_for_write_io(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.lock_for_write(),
            .RW_SPIN_LOCK => lock.lock_for_write(),
            .MUTEX => lock.lock_for_write(io),
            .RW_MUTEX => lock.lock_for_write(io),
        }
    }
    pub fn unlock_for_write_io(comptime KIND: LockKind, lock: KIND.lock_ptr_type(), io: Io) void {
        switch (comptime KIND) {
            .NONE => {},
            .SPIN_LOCK => lock.unlock_for_write(),
            .RW_SPIN_LOCK => lock.unlock_for_write(),
            .MUTEX => lock.unlock_for_write(io),
            .RW_MUTEX => lock.unlock_for_write(io),
        }
    }
};

pub const AnyLock = union(LockKind) {
    NONE: void,
    SPIN_LOCK: SpinLock,
    RW_SPIN_LOCK: RwSpinLock,
    MUTEX: Mutex,
    RW_MUTEX: RwMutex,

    pub fn lock_for_read(self: *AnyLock, io: Io) void {
        switch (self) {
            .NONE => {},
            .SPIN_LOCK => |lock| lock.lock_for_read(),
            .RW_SPIN_LOCK => |lock| lock.lock_for_read(),
            .MUTEX => |lock| lock.lock_for_read(io),
            .RW_MUTEX => |lock| lock.lock_for_read(io),
        }
    }
    pub fn unlock_for_read(self: *AnyLock, io: Io) void {
        switch (self) {
            .NONE => {},
            .SPIN_LOCK => |lock| lock.unlock_for_read(),
            .RW_SPIN_LOCK => |lock| lock.unlock_for_read(),
            .MUTEX => |lock| lock.unlock_for_read(io),
            .RW_MUTEX => |lock| lock.unlock_for_read(io),
        }
    }
    pub fn lock_for_write(self: *AnyLock, io: Io) void {
        switch (self) {
            .NONE => {},
            .SPIN_LOCK => |lock| lock.lock_for_write(),
            .RW_SPIN_LOCK => |lock| lock.lock_for_write(),
            .MUTEX => |lock| lock.lock_for_write(io),
            .RW_MUTEX => |lock| lock.lock_for_write(io),
        }
    }
    pub fn unlock_for_write(self: *AnyLock, io: Io) void {
        switch (self) {
            .NONE => {},
            .SPIN_LOCK => |lock| lock.unlock_for_write(),
            .RW_SPIN_LOCK => |lock| lock.unlock_for_write(),
            .MUTEX => |lock| lock.unlock_for_write(io),
            .RW_MUTEX => |lock| lock.unlock_for_write(io),
        }
    }
};

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
