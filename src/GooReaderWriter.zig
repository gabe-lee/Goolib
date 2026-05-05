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
const build = @import("builtin");
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const Types = Root.Types;
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Nullability = CommonTypes.Nullability;
const NullPropagation = CommonTypes.NullPropagation;
const NullOperation = CommonTypes.NullOperation;
const Utils = Root.Utils;
const Cast = Root.Cast;
const Hash = std.hash.XxHash64;
const Assert = Root.Assert;
const Sort = Root.Sort;
const Allocator = std.mem.Allocator;
const KindInfo = Types.KindInfo;
const StructField = std.builtin.Type.StructField;
const EnumField = std.builtin.Type.EnumField;
const util_secure_memset = Utils.Mem.secure_memset;
const util_secure_zero = Utils.Mem.secure_zero;
const util_secure_memset_undefined = Utils.Mem.secure_memset_undefined;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;

pub const SeekOrigin = enum(u8) {
    FROM_CURRENT_POSITION,
    FROM_START,
    FROM_END,
};

pub const SeekError = error{
    attempt_to_seek_before_start,
    attempt_to_seek_after_end,
    cannot_seek,
    cannot_seek_forward,
    cannot_seek_backward,
};
pub const SeekForwardError = error{
    attempt_to_seek_after_end,
    cannot_seek,
    cannot_seek_forward,
};
pub const CannotSeekForwardError = error{
    cannot_seek,
    cannot_seek_forward,
};
pub const SeekBackwardError = error{
    attempt_to_seek_before_start,
    cannot_seek,
    cannot_seek_backward,
};
pub const CannotSeekBackwardError = error{
    cannot_seek,
    cannot_seek_backward,
};
pub const CannotSeekError = error{
    cannot_seek,
    cannot_seek_forward,
    cannot_seek_backward,
};
pub const ReadError = error{
    too_few_items_available_to_read,
};

pub const SeekResult = struct {
    delta: isize = 0,
    err: ?SeekError = null,
};

pub const ReadResult = struct {
    num: usize = 0,
    err: ?ReadError = null,
};

pub fn TypeReader(comptime T: type) type {
    return struct {
        object: *anyopaque,
        vtable: *const VTABLE,

        pub const VTABLE = struct {
            seek: *const fn (object: *anyopaque, origin: SeekOrigin, delta: isize) SeekResult,
            peek_n: *const fn (object: *anyopaque, n: usize, dest: [*]T) ReadResult,
            read_n: *const fn (object: *anyopaque, n: usize, dest: [*]T) ReadResult,
        };
        const Self = @This();

        pub fn seek_raw(self: Self, origin: SeekOrigin, delta: isize) SeekResult {
            return self.vtable.seek(self.object, origin, delta);
        }
        pub fn seek_get_delta(self: Self, origin: SeekOrigin, delta: isize) SeekError!isize {
            const raw = self.seek_raw(origin, delta);
            if (raw.err) |err| return err;
            return raw.delta;
        }
        pub fn seek(self: Self, origin: SeekOrigin, delta: isize) SeekError!void {
            const raw = self.seek_raw(origin, delta);
            if (raw.err) |err| return err;
        }
        pub fn seek_constrained_get_delta(self: Self, origin: SeekOrigin, delta: isize) CannotSeekError!isize {
            const raw = self.seek_raw(origin, delta);
            if (raw.err) |err| switch (err) {
                SeekError.attempt_to_seek_after_end, SeekError.attempt_to_seek_before_start => {},
                else => |e| return @errorCast(e),
            };
            return raw.delta;
        }
        pub fn seek_constrained(self: Self, origin: SeekOrigin, delta: isize) CannotSeekError!void {
            const raw = self.seek_raw(origin, delta);
            if (raw.err) |err| switch (err) {
                SeekError.attempt_to_seek_after_end, SeekError.attempt_to_seek_before_start => {},
                else => |e| return @errorCast(e),
            };
        }
        pub fn advance_one(self: Self) SeekForwardError!void {
            self.seek(.FROM_CURRENT_POSITION, 1) catch |err| return @errorCast(err);
        }
        pub fn advance_one_constrained(self: Self) CannotSeekForwardError!void {
            self.seek_constrained(.FROM_CURRENT_POSITION, 1) catch |err| return @errorCast(err);
        }
        pub fn advance_one_constrained_get_delta(self: Self) CannotSeekForwardError!usize {
            const delta = self.seek_constrained_get_delta(.FROM_CURRENT_POSITION, 1) catch |err| return @errorCast(err);
            return @intCast(delta);
        }
        pub fn advance_n(self: Self, n: usize) SeekForwardError!void {
            self.seek(.FROM_CURRENT_POSITION, num_cast(n, isize)) catch |err| return @errorCast(err);
        }
        pub fn advance_n_constrained(self: Self, n: usize) CannotSeekForwardError!void {
            self.seek_constrained(.FROM_CURRENT_POSITION, num_cast(n, isize)) catch |err| return @errorCast(err);
        }
        pub fn advance_n_constrained_get_delta(self: Self, n: usize) CannotSeekForwardError!void {
            const delta = self.seek_constrained_get_delta(.FROM_CURRENT_POSITION, num_cast(n, isize)) catch |err| return @errorCast(err);
            return @intCast(delta);
        }
        pub fn rollback_one(self: Self) SeekBackwardError!void {
            self.seek(.FROM_CURRENT_POSITION, -1) catch |err| return @errorCast(err);
        }
        pub fn rollback_one_constrained(self: Self) CannotSeekBackwardError!void {
            self.seek_constrained(.FROM_CURRENT_POSITION, -1) catch |err| return @errorCast(err);
        }
        pub fn rollback_one_constrained_get_delta(self: Self) CannotSeekBackwardError!usize {
            const delta = self.seek_constrained_get_delta(.FROM_CURRENT_POSITION, -1) catch |err| return @errorCast(err);
            return @intCast(-delta);
        }
        pub fn rollback_n(self: Self, n: usize) SeekBackwardError!void {
            self.seek(.FROM_CURRENT_POSITION, -num_cast(n, isize)) catch |err| return @errorCast(err);
        }
        pub fn rollback_n_constrained(self: Self, n: usize) CannotSeekBackwardError!void {
            self.seek_constrained(.FROM_CURRENT_POSITION, -num_cast(n, isize)) catch |err| return @errorCast(err);
        }
        pub fn rollback_n_constrained_get_delta(self: Self, n: usize) CannotSeekBackwardError!usize {
            const delta = self.seek_constrained(.FROM_CURRENT_POSITION, -num_cast(n, isize)) catch |err| return @errorCast(err);
            return @intCast(-delta);
        }
        pub fn peek_raw(self: Self, n: usize, dest: [*]T) ReadResult {
            return self.vtable.peek_n(self.object, n, dest);
        }
        pub fn peek_one(self: Self) ReadError!T {
            var val: T = undefined;
            const result = self.peek_raw(1, @ptrCast(&val));
            if (result.err) |err| return err;
            return val;
        }
        pub fn peek_n(self: Self, n: usize, dest: [*]T) ReadError!void {
            const result = self.peek_raw(n, dest);
            if (result.err) |err| return err;
        }
        pub fn peek_zero_or_one(self: Self) ?T {
            var val: T = undefined;
            const result = self.peek_raw(1, @ptrCast(&val));
            if (result.num == 0) return null;
            return val;
        }
        pub fn peek_up_to_n(self: Self, n: usize, dest: [*]T) usize {
            const result = self.peek_raw(n, dest);
            return result.num;
        }
        pub fn read_raw(self: Self, n: usize, dest: [*]T) struct { ReadResult, SeekResult } {
            const p = self.peek_raw(n, dest);
            if (p.err != null) return .{ p, .{} };
            const s = self.seek_raw(.FROM_CURRENT_POSITION, num_cast(n, isize));
            return .{ p, s };
        }
        pub fn read_one(self: Self) ReadError!T {
            if (self.peek_one()) |val| {
                self.advance_one() catch |err| return @errorCast(err);
                return val;
            } else |err| {
                return @errorCast(err);
            }
        }
        pub fn read_n(self: Self, n: usize, dest: [*]T) ReadError!void {
            if (self.peek_n(n, dest)) |_| {
                self.advance_n(n) catch |err| return @errorCast(err);
            } else |err| {
                return @errorCast(err);
            }
        }
        pub fn read_zero_or_one(self: Self) ?T {
            if (self.peek_one()) |val| {
                self.advance_one() catch |err| return @errorCast(err);
                return val;
            } else |err| {
                return @errorCast(err);
            }
        }
        pub fn read_up_to_n(self: Self, n: usize, dest: [*]T) ReadError!usize {
            const result = self.peek_raw(n, dest);
            if (result.err) |err| return err;
            return result.num;
        }
    };
}
