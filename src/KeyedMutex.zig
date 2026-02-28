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

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const SHOULD_ASSERT = Assert.SHOULD_ASSERT;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

/// A mutex with additional safety features in `.Debug` and `.ReleaseSafe` modes.
///
/// When locked it returns a `Key` that is the only way to unlock the mutex.
pub fn KeyedMutex(comptime ENABLE: bool) type {
    return struct {
        const SelfMutex = @This();

        mutex: if (ENABLE) std.Thread.Mutex else void = .{},
        key_owner: if (ENABLE and SHOULD_ASSERT) usize else void = if (ENABLE and SHOULD_ASSERT) 0 else void{},
        thread_locked_on: if (ENABLE and SHOULD_ASSERT) u32 else void = if (ENABLE and SHOULD_ASSERT) 0 else void{},

        var thread_id_counter: if (ENABLE and SHOULD_ASSERT) u32 else void = if (ENABLE and SHOULD_ASSERT) 1 else void{};
        threadlocal var this_thread_id: if (ENABLE and SHOULD_ASSERT) ?u32 else void = if (ENABLE and SHOULD_ASSERT) null else void{};

        pub fn lock(self: *SelfMutex) Key {
            if (ENABLE) {
                if (SHOULD_ASSERT) {
                    if (this_thread_id == null) {
                        this_thread_id = @atomicRmw(u32, &thread_id_counter, .Add, 1, .monotonic);
                    }
                    assert_with_reason(self.thread_locked_on != this_thread_id.?, @src(), "attempted to re-lock a mutex on the same thread it was already locked on: you have deadlocked your program", .{});
                }
                self.mutex.lock();
                if (SHOULD_ASSERT) {
                    self.key_owner +%= 1;
                    self.thread_locked_on = this_thread_id.?;
                }
                return Key{
                    .ptr = self,
                    .id = if (SHOULD_ASSERT) self.key_owner else void{},
                };
            } else {
                return .{};
            }
        }
        pub fn try_lock(self: *SelfMutex) ?Key {
            if (ENABLE) {
                if (SHOULD_ASSERT) {
                    if (this_thread_id == null) {
                        this_thread_id = @atomicRmw(u32, &thread_id_counter, .Add, 1, .monotonic);
                    }
                }
                if (self.mutex.tryLock()) {
                    if (SHOULD_ASSERT) {
                        self.key_owner +%= 1;
                        self.thread_locked_on = this_thread_id.?;
                    }
                    return Key{
                        .ptr = self,
                        .id = if (SHOULD_ASSERT) self.key_owner else void{},
                    };
                }
                return null;
            } else {
                return Key{};
            }
        }

        pub const Key = struct {
            ptr: if (ENABLE) ?*SelfMutex else void = if (ENABLE) null else void{},
            id: if (ENABLE and SHOULD_ASSERT) usize else void = if (ENABLE and SHOULD_ASSERT) 0 else void{},

            /// Returns the new key (or same if key already has the same mutex pointer), and a bool
            /// descibing whether the lock was needed
            pub fn lock_if_needed(self: Key, mutex: *SelfMutex) struct { Key, bool } {
                if (ENABLE) {
                    if (self.ptr) |p| {
                        if (SHOULD_ASSERT) {
                            const this_addr = @intFromPtr(p);
                            const mutex_addr = @intFromPtr(mutex);
                            assert_with_reason(this_addr == mutex_addr, @src(), "attempted to 'lock if needed' a key with a mutex pointer that does not match the provided mutex: you probably have a logic error somewhere", .{});
                        }
                        return .{ self, false };
                    } else {
                        const new_key = mutex.lock();
                        return .{ new_key, true };
                    }
                } else {
                    return .{ self, false };
                }
            }

            pub fn unlock(self: *Key) void {
                if (ENABLE) {
                    if (SHOULD_ASSERT) {
                        if (this_thread_id == null) {
                            this_thread_id = @atomicRmw(u32, &thread_id_counter, .Add, 1, .monotonic);
                        }
                        assert_with_reason(self.ptr != null, @src(), "KeyedMutex Key was improperly created or was already unlocked", .{});
                        assert_with_reason(self.ptr.?.thread_locked_on == this_thread_id, @src(), "attempted to unlock a KeyedMutex on a thread it was not originally locked on", .{});
                        assert_with_reason(self.ptr.?.key_owner == self.id, @src(), "attempted to unlock a KeyedMutex with a Key that did did not originally lock it", .{});
                        self.id = 0;
                        self.ptr.?.thread_locked_on = 0;
                        self.ptr.?.key_owner +%= 1;
                    }
                    self.ptr.?.mutex.unlock();
                    self.ptr = null;
                    if (SHOULD_ASSERT) {
                        self.* = undefined;
                    }
                }
            }

            pub fn unlock_if_needed(self: *Key, needed: bool) void {
                if (ENABLE) {
                    if (needed) {
                        self.unlock();
                    }
                }
            }
        };
    };
}
