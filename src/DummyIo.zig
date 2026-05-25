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
const Io = std.Io;
const Root = @import("_root.zig");
const Assert = Root.Assert;
const assert_unreachable = Assert.assert_unreachable;
const AnyFuture = Io.AnyFuture;
const Batch = Io.Batch;
const Cancelable = Io.Cancelable;
const Timeout = Io.Timeout;
const Clock = Io.Clock;
const Duration = Io.Duration;
const ConcurrentError = Io.ConcurrentError;
const Dir = Io.Dir;

// pub const io_unreachable_panic = Io{
//     .userdata = null,
//     .vtable = &unreach.vtable,
// };

pub const io_undefined = Io{
    .userdata = null,
    .vtable = &undef.vtable,
};

const undef = struct {
    const vtable = Io.VTable{
        .async = undefined,
        .await = undefined,
        .batchAwaitAsync = undefined,
        .batchAwaitConcurrent = undefined,
        .batchCancel = undefined,
        .cancel = undefined,
        .checkCancel = undefined,
        .childKill = undefined,
        .childWait = undefined,
        .clockResolution = undefined,
        .concurrent = undefined,
        .crashHandler = undefined,
        .dirAccess = undefined,
        .dirClose = undefined,
        .dirCreateDir = undefined,
        .dirCreateDirPath = undefined,
        .dirCreateDirPathOpen = undefined,
        .dirCreateFile = undefined,
        .dirCreateFileAtomic = undefined,
        .dirDeleteDir = undefined,
        .dirDeleteFile = undefined,
        .dirHardLink = undefined,
        .dirOpenDir = undefined,
        .dirOpenFile = undefined,
        .dirRead = undefined,
        .dirReadLink = undefined,
        .dirRealPath = undefined,
        .dirRealPathFile = undefined,
        .dirRename = undefined,
        .dirRenamePreserve = undefined,
        .dirSetFileOwner = undefined,
        .dirSetFilePermissions = undefined,
        .dirSetOwner = undefined,
        .dirSetPermissions = undefined,
        .dirSetTimestamps = undefined,
        .dirStat = undefined,
        .dirStatFile = undefined,
        .dirSymLink = undefined,
        .fileClose = undefined,
        .fileDowngradeLock = undefined,
        .fileEnableAnsiEscapeCodes = undefined,
        .fileHardLink = undefined,
        .fileIsTty = undefined,
        .fileLength = undefined,
        .fileLock = undefined,
        .fileMemoryMapCreate = undefined,
        .fileMemoryMapDestroy = undefined,
        .fileMemoryMapRead = undefined,
        .fileMemoryMapSetLength = undefined,
        .fileMemoryMapWrite = undefined,
        .fileReadPositional = undefined,
        .fileRealPath = undefined,
        .fileSeekBy = undefined,
        .fileSeekTo = undefined,
        .fileSetLength = undefined,
        .fileSetOwner = undefined,
        .fileSetPermissions = undefined,
        .fileSetTimestamps = undefined,
        .fileStat = undefined,
        .fileSupportsAnsiEscapeCodes = undefined,
        .fileSync = undefined,
        .fileTryLock = undefined,
        .fileUnlock = undefined,
        .fileWriteFilePositional = undefined,
        .fileWriteFileStreaming = undefined,
        .fileWritePositional = undefined,
        .futexWait = undefined,
        .futexWaitUncancelable = undefined,
        .futexWake = undefined,
        .groupAsync = undefined,
        .groupAwait = undefined,
        .groupCancel = undefined,
        .groupConcurrent = undefined,
        .lockStderr = undefined,
        .netAccept = undefined,
        .netBindIp = undefined,
        .netClose = undefined,
        .netConnectIp = undefined,
        .netConnectUnix = undefined,
        .netInterfaceName = undefined,
        .netInterfaceNameResolve = undefined,
        .netListenIp = undefined,
        .netListenUnix = undefined,
        .netLookup = undefined,
        .netRead = undefined,
        .netSend = undefined,
        .netShutdown = undefined,
        .netSocketCreatePair = undefined,
        .netWrite = undefined,
        .netWriteFile = undefined,
        .now = undefined,
        .operate = undefined,
        .processCurrentPath = undefined,
        .processExecutableOpen = undefined,
        .processExecutablePath = undefined,
        .processReplace = undefined,
        .processReplacePath = undefined,
        .processSetCurrentDir = undefined,
        .processSetCurrentPath = undefined,
        .processSpawn = undefined,
        .processSpawnPath = undefined,
        .progressParentFile = undefined,
        .random = undefined,
        .randomSecure = undefined,
        .recancel = undefined,
        .sleep = undefined,
        .swapCancelProtection = undefined,
        .tryLockStderr = undefined,
        .unlockStderr = undefined,
    };
};

// const unreach = struct {
//     const vtable = Io.VTable{
//         .async = async,
//         .await = await,
//         .batchAwaitAsync = batchAwaitAsync,
//         .batchAwaitConcurrent = batchAwaitConcurrent,
//         .batchCancel = batchCancel,
//         .cancel = cancel,
//         .checkCancel = checkCancel,
//         .childKill = childKill,
//         .childWait = childWait,
//         .clockResolution = clockResolution,
//         .concurrent = concurrent,
//         .crashHandler = crashHandler,
//         .dirAccess = dirAccess,
//         .dirClose = dirClose,
//     };

//     fn async(
//         _: ?*anyopaque,
//         _: []u8,
//         _: std.mem.Alignment,
//         _: []const u8,
//         _: std.mem.Alignment,
//         _: *const fn (context: *const anyopaque, result: *anyopaque) void,
//     ) ?*AnyFuture {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }

//     fn await(
//         _: ?*anyopaque,
//         _: *AnyFuture,
//         _: []u8,
//         _: std.mem.Alignment,
//     ) void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }

//     fn batchAwaitAsync(_: ?*anyopaque, _: *Batch) Cancelable!void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn batchAwaitConcurrent(_: ?*anyopaque, _: *Batch, _: Timeout) Batch.AwaitConcurrentError!void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn batchCancel(_: ?*anyopaque, _: *Batch) void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn cancel(
//         _: ?*anyopaque,
//         _: *AnyFuture,
//         _: []u8,
//         _: std.mem.Alignment,
//     ) void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn checkCancel(_: ?*anyopaque) Cancelable!void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn childKill(_: ?*anyopaque, _: *std.process.Child) void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn childWait(_: ?*anyopaque, _: *std.process.Child) std.process.Child.WaitError!std.process.Child.Term {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn clockResolution(_: ?*anyopaque, _: Clock) Clock.ResolutionError!Duration {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn concurrent(
//         _: ?*anyopaque,
//         _: usize,
//         _: std.mem.Alignment,
//         _: []const u8,
//         _: std.mem.Alignment,
//         _: *const fn (context: *const anyopaque, result: *anyopaque) void,
//     ) ConcurrentError!*AnyFuture {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn crashHandler(_: ?*anyopaque) void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn dirAccess(_: ?*anyopaque, _: Dir, _: []const u8, _: Dir.AccessOptions) Dir.AccessError!void {
//         assert_unreachable(@src(), "no Io interface provided", .{});
//     }
//     fn dirClose(?*anyopaque, []const Dir) void {}
// };
