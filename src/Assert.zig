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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const build = @import("builtin");

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;

pub inline fn generic_header(comptime BEFORE: []const u8, comptime tag: []const u8, comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8, comptime AFTER: []const u8) []const u8 {
    const timing = if (in_comptime) "\n\x1b[1GCOMPTIME " else "\n\x1b[1GRUNTIME ";
    const newline = if (in_comptime) "\n" else "\n\t";
    const loc_prefix = if (src_loc) |s| "Zig → " ++ s.module ++ " → " else "";
    const loc_func = if (src_loc) |s| s.fn_name ++ "(...)" else "";
    const link = if (src_loc) |s| s.file ++ ":" ++ std.fmt.comptimePrint("{d}", .{s.line}) ++ ":" ++ std.fmt.comptimePrint("{d}", .{s.column}) ++ " → " else "";
    return BEFORE ++ timing ++ tag ++ "[" ++ loc_prefix ++ link ++ loc_func ++ "]" ++ newline ++ log ++ AFTER ++ "\n";
}

pub inline fn err_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return generic_header(ANSI.FG_RED, "ERROR: ", in_comptime, src_loc, log, ANSI.RESET);
}

pub inline fn warn_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return generic_header(ANSI.FG_YELLOW, "WARNING: ", in_comptime, src_loc, log, ANSI.RESET);
}

pub inline fn info_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return generic_header("", "", in_comptime, src_loc, log, "");
}

pub inline fn assert_with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    const in_comptime = @inComptime();
    if (in_comptime or build.mode == .Debug) {
        if (!condition) {
            if (in_comptime) {
                @compileError(std.fmt.comptimePrint(err_header(in_comptime, src_loc, reason_fmt), reason_args));
            } else {
                std.debug.panic(err_header(in_comptime, src_loc, reason_fmt), reason_args);
            }
            unreachable;
        }
    } else {
        if (!condition) {
            unreachable;
        }
    }
}

pub fn assert_pointer_resides_in_slice(comptime T: type, slice: []const T, pointer: *const T, comptime src_loc: ?SourceLocation) void {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const ptr_addr = @intFromPtr(pointer);
    assert_with_reason(start_addr <= ptr_addr and ptr_addr <= end_addr, src_loc, "pointer to `{s}` ({X}) does not reside within slice [{X} -> {X}]", .{ @typeName(T), ptr_addr, start_addr, end_addr });
}

pub fn assert_idx_less_than_len(idx: anytype, len: anytype, src_loc: ?SourceLocation) void {
    assert_with_reason(idx < len, src_loc, "index ({s}) out of bounds for slice/list len ({s})", .{ idx, len });
}
