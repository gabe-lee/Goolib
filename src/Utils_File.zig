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
const config = @import("config");
const init_zero = std.mem.zeroes;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Utils = Root.Utils;
const Assert = Root.Assert;
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
