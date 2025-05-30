//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const FileBuffer = std.ArrayList(u8);
const io = std.io;
const fs = std.fs;
const process = std.process;
const DirOpenOptions = fs.Dir.OpenOptions;
const FileCreateFlags = fs.File.CreateFlags;
const File = fs.File;
const FileOpenMode = fs.File.OpenMode;
const FileOpenFlags = fs.File.OpenFlags;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Path = Root.CommonTypes.Path;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const Types = Root.Types;

const Self = @This();
const CREATE_FLAGS = FileCreateFlags{
    .exclusive = false,
    .lock = .exclusive,
    .lock_nonblocking = false,
    .read = false,
    .truncate = true,
    .mode = fs.File.default_mode,
};

path: Path,
file: File,
buffer: FileBuffer,
is_open: bool,

pub fn create(allocator: Allocator) anyerror!Self {
    return Self{
        .file = undefined,
        .buffer = FileBuffer.initCapacity(allocator, std.heap.page_size_min),
        .path = .{ .ABSOLUTE = "" },
        .is_open = false,
    };
}

pub fn destroy(self: *Self) anyerror!void {
    assert_with_reason(!self.is_open, @src(), @This(), "cannot destroy filegen while a file is open", .{});
    self.buffer.deinit();
}

pub fn create_filegen_and_start_generating_file(path: Path, allocator: Allocator) anyerror!Self {
    const file = try switch (path) {
        .ABSOLUTE => |abs| fs.createFileAbsolute(abs, CREATE_FLAGS),
        .RELATIVE_CWD => |rel| fs.cwd().createFile(rel, CREATE_FLAGS),
    };
    return Self{
        .file = file,
        .buffer = FileBuffer.initCapacity(allocator, std.heap.page_size_min),
        .path = path,
        .is_open = true,
    };
}

pub fn stage_bytes(self: *Self, bytes: []const u8) anyerror!void {
    assert_with_reason(self.is_open, @src(), @This(), "no file is open", .{});
    try self.buffer.appendSlice(bytes);
}

pub fn commit_bytes(self: *Self) anyerror!void {
    assert_with_reason(self.is_open, @src(), @This(), "no file is open", .{});
    try self.file.writeAll(self.buffer.items);
    self.buffer.clearRetainingCapacity();
}

pub fn finish_generating_file(self: *Self) anyerror!void {
    assert_with_reason(self.is_open, @src(), @This(), "no file is open", .{});
    if (self.buffer.items.len > 0) {
        try self.file.writeAll(self.buffer.items);
        self.buffer.clearRetainingCapacity();
    }
    self.file.close();
    self.is_open = false;
}

pub fn start_generating_file(self: *Self, path: Path) anyerror!void {
    assert_with_reason(!self.is_open, @src(), @This(), "cannot create new file while a file is already open", .{});
    self.file = try switch (path) {
        .ABSOLUTE => |abs| fs.createFileAbsolute(abs, CREATE_FLAGS),
        .RELATIVE_CWD => |rel| fs.cwd().createFile(rel, CREATE_FLAGS),
    };
    self.is_open = true;
    self.path = path;
}

pub fn foreach_field_stage_formatted(self: *Self, comptime fmt: []const u8, payload: anytype) anyerror!void {
    assert_with_reason(self.is_open, @src(), @This(), "no file is open", .{});
    const T_PAYLOADS = @TypeOf(payload);
    assert_with_reason(Types.type_is_tuple(T_PAYLOADS), @src(), @This(), "`payload` must be a tuple type", .{});
    const INFO = @typeInfo(T_PAYLOADS).@"struct";
    var writer = self.buffer.writer();
    inline for (INFO.fields) |field| {
        try writer.print(fmt, @field(payload, field.name));
    }
}

pub fn stage_if_true_else(self: *Self, condition: bool, comptime true_fmt: []const u8, true_payload: anytype, comptime false_fmt: []const u8, false_payload: anytype) anyerror!void {
    var writer = self.buffer.writer();
    if (condition) {
        try writer.print(true_fmt, true_payload);
    } else {
        try writer.print(false_fmt, false_payload);
    }
}
