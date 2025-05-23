const std = @import("std");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const LOG_PREFIX = Root.LOG_PREFIX ++ "[Utils] ";
const BinarySearch = Root.BinarySearch;

pub inline fn err_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime this: ?type, comptime log: []const u8) []const u8 {
    const timing = if (in_comptime) "COMPTIME " else "RUNTIME ";
    const ident_pfx = if (src_loc != null or this != null) "[" else "";
    const ident_sfx = if (src_loc != null or this != null) "]\n\t" else "\n\t";
    const type_chain = if (this) |t| @typeName(t) ++ "." else "";
    const loc_prefix = if (src_loc) |s| "Zig." ++ s.module ++ "." else "";
    const loc_func = if (src_loc) |s| s.fn_name ++ "(...)" else "";
    return ANSI.BEGIN ++ ANSI.FG_RED ++ ANSI.END ++ timing ++ "ERROR: " ++ ident_pfx ++ loc_prefix ++ type_chain ++ loc_func ++ ident_sfx ++ log ++ ANSI.BEGIN ++ ANSI.RESET ++ ANSI.END ++ "\n";
}

pub inline fn warn_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime this: ?type, comptime log: []const u8) []const u8 {
    const timing = if (in_comptime) "COMPTIME " else "RUNTIME ";
    const ident_pfx = if (src_loc != null or this != null) "[" else "";
    const ident_sfx = if (src_loc != null or this != null) "]\n\t" else "\n\t";
    const type_chain = if (this) |t| @typeName(t) ++ "." else "";
    const loc_prefix = if (src_loc) |s| "Zig." ++ s.module ++ "." else "";
    const loc_func = if (src_loc) |s| s.fn_name ++ "(...)" else "";
    return ANSI.BEGIN ++ ANSI.FG_YELLOW ++ ANSI.END ++ timing ++ "WARNING: " ++ ident_pfx ++ loc_prefix ++ type_chain ++ loc_func ++ ident_sfx ++ log ++ ANSI.BEGIN ++ ANSI.RESET ++ ANSI.END ++ "\n";
}

pub inline fn info_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime this: ?type, comptime log: []const u8) []const u8 {
    const timing = if (in_comptime) "COMPTIME " else "RUNTIME ";
    const ident_pfx = if (src_loc != null or this != null) "[" else "";
    const ident_sfx = if (src_loc != null or this != null) "]\n\t" else "\n\t";
    const type_chain = if (this) |t| @typeName(t) ++ "." else "";
    const loc_prefix = if (src_loc) |s| "Zig." ++ s.module ++ "." else "";
    const loc_func = if (src_loc) |s| s.fn_name ++ "(...)" else "";
    return timing ++ "INFO: " ++ ident_pfx ++ loc_prefix ++ type_chain ++ loc_func ++ ident_sfx ++ log ++ "\n";
}

pub inline fn assert_with_reason(condition: bool, comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime this: ?type, reason_fmt: []const u8, reason_args: anytype) void {
    if (build.mode == .Debug) {
        if (!condition) {
            if (in_comptime) {
                @compileError(std.fmt.comptimePrint(err_header(in_comptime, src_loc, this, reason_fmt), reason_args));
            } else {
                std.debug.panic(err_header(in_comptime, src_loc, this, reason_fmt), reason_args);
            }
            unreachable;
        }
    } else {
        assert(condition);
    }
}
