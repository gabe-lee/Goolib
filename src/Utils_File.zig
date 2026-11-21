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
const config = @import("config");
const init_zero = std.mem.zeroes;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;
const File = Io.File;
pub const OpenFileOptions = Dir.OpenFileOptions;
pub const CreateFileOptions = Dir.CreateFileOptions;
pub const OpenDirOptions = Dir.OpenOptions;
pub const Permissions = File.Permissions;
pub const CreateDirError = Dir.CreateDirError;
pub const OpenDirError = Dir.OpenError;
pub const OpenFileError = File.OpenError;
pub const CreateDirPathError = Dir.CreateDirPathError;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_unreachable = Assert.assert_unreachable;
const assert_with_reason = Assert.assert_with_reason;

pub const LoadedFile = struct {
    file: std.fs.File,
    data: []u8,

    pub fn close_file(self: LoadedFile) void {
        self.file.close();
    }
    pub fn free_data(self: LoadedFile, alloc: Allocator) void {
        alloc.free(self.data);
    }
    pub fn free_all(self: LoadedFile, alloc: Allocator) void {
        self.file.close();
        alloc.free(self.data);
    }
};

pub const LoadError = std.mem.Allocator.Error || std.fs.File.OpenError || std.fs.File.StatError || std.fs.File.ReadError;

pub fn load_entire_file(path_relative_cwd: []const u8, flags: std.fs.File.OpenFlags, allocator: Allocator) LoadError!LoadedFile {
    const file = try std.fs.cwd().openFile(path_relative_cwd, flags);
    const stat = try file.stat();
    const data = try allocator.alloc(u8, @intCast(stat.size));
    _ = try file.readAll(data);
    return LoadedFile{
        .file = file,
        .data = data,
    };
}

pub const Path = union(enum) {
    ABSOLUTE: struct {
        io: Io,
        path: []const u8,
    },
    RELATIVE_DIR: struct {
        io: Io,
        dir: std.Io.Dir,
        sub_path: []const u8,
    },

    pub fn get_io(self: Path) Io {
        switch (self) {
            .ABSOLUTE => |info| {
                return info.io;
            },
            .RELATIVE_DIR => |info| {
                return info.io;
            },
        }
    }

    pub fn absolute_path(path: []const u8, io: Io) Path {
        return Path{ .ABSOLUTE = .{
            .io = io,
            .path = path,
        } };
    }
    pub fn relative_cwd(sub_path: []const u8, io: Io) Path {
        return Path{ .RELATIVE_DIR = .{
            .io = io,
            .dir = std.Io.Dir.cwd(),
            .sub_path = sub_path,
        } };
    }
    pub fn relative_dir(dir: std.Io.Dir, sub_path: []const u8, io: Io) Path {
        return Path{ .RELATIVE_DIR = .{
            .io = io,
            .dir = dir,
            .sub_path = sub_path,
        } };
    }

    pub fn create_as_file(self: Path, options: CreateFileOptions) File.OpenError!File {
        switch (self) {
            .ABSOLUTE => |path| {
                return Dir.createFileAbsolute(self.io, path, options);
            },
            .RELATIVE_DIR => |info| {
                return info.dir.createFile(self.io, info.sub_path, options);
            },
        }
    }

    pub fn open_as_file(self: Path, options: OpenFileOptions) File.OpenError!File {
        switch (self) {
            .ABSOLUTE => |path| {
                return Dir.openFileAbsolute(self.io, path, options);
            },
            .RELATIVE_DIR => |info| {
                return info.dir.openFile(self.io, info.sub_path, options);
            },
        }
    }

    pub fn append_sub_path_no_alloc(comptime self: Path, comptime sub_path: []const u8) Path {
        switch (self) {
            .ABSOLUTE => |info| {
                return Path{ .ABSOLUTE = .{
                    .io = info.io,
                    .path = info.path ++ Dir.path.sep_str ++ sub_path,
                } };
            },
            .RELATIVE_DIR => |info| {
                return Path{ .RELATIVE_DIR = .{
                    .io = info.io,
                    .dir = info.dir,
                    .sub_path = info.sub_path ++ Dir.path.sep_str ++ sub_path,
                } };
            },
        }
    }

    pub fn open_as_dir(self: Path, options: OpenDirOptions) OpenDirError!Dir {
        switch (self) {
            .ABSOLUTE => |path| {
                return Dir.openDirAbsolute(self.io, path, options);
            },
            .RELATIVE_DIR => |info| {
                return info.dir.openDir(self.io, info.sub_path, options);
            },
        }
    }
    pub fn create_as_dir(self: Path, permissions: Permissions) CreateDirError!void {
        switch (self) {
            .ABSOLUTE => |path| {
                return Dir.createDirAbsolute(self.io, path, permissions);
            },
            .RELATIVE_DIR => |info| {
                return info.dir.createDir(self.io, info.sub_path, permissions);
            },
        }
    }
    pub fn create_dir_path(self: Path) CreateDirPathError!void {
        switch (self) {
            .ABSOLUTE => {
                assert_unreachable(@src(), "not compatible with absolute paths", .{});
            },
            .RELATIVE_DIR => |info| {
                return info.dir.createDirPath(self.io, self.sub);
            },
        }
    }
    pub fn create_dir_path_and_open(self: Path, options: OpenDirOptions) (CreateDirPathError || CreateDirError)!Dir {
        switch (self) {
            .ABSOLUTE => {
                assert_unreachable(@src(), "not compatible with absolute paths", .{});
            },
            .RELATIVE_DIR => |info| {
                try info.dir.createDirPath(self.io, self.sub);
                return self.open_as_dir(options);
            },
        }
    }
    pub fn create_file_path(self: Path) CreateDirPathError!void {
        switch (self) {
            .ABSOLUTE => {
                assert_unreachable(@src(), "not compatible with absolute paths", .{});
            },
            .RELATIVE_DIR => |info| {
                if (Dir.path.dirname(info.sub_path)) |dir_path| {
                    try info.dir.createDirPath(self.io, dir_path);
                }
            },
        }
    }
    pub fn create_file_path_and_open(self: Path, options: CreateFileOptions) (CreateDirPathError || OpenFileError)!File {
        switch (self) {
            .ABSOLUTE => {
                assert_unreachable(@src(), "not compatible with absolute paths", .{});
            },
            .RELATIVE_DIR => |info| {
                if (Dir.path.dirname(info.sub_path)) |dir_path| {
                    try info.dir.createDirPath(self.io, dir_path);
                }
                return self.create_as_file(options);
            },
        }
    }
    pub fn create_as_dir_and_open(self: Path, permissions: Permissions, options: OpenDirOptions) (CreateDirError || OpenDirError)!Dir {
        switch (self) {
            .ABSOLUTE => |path| {
                try Dir.createDirAbsolute(self.io, path, permissions);
            },
            .RELATIVE_DIR => |info| {
                try info.dir.createDir(self.io, info.sub_path, permissions);
            },
        }
        return self.open_as_dir(options);
    }
};
