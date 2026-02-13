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
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const build = @import("builtin");
const Allocator = std.mem.Allocator;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Types = Root.Types;
const ANSI = Root.ANSI;
const Common = Root.CommonTypes;
const MathX = Root.Math;

pub const SHOULD_ASSERT = build.mode == .Debug or build.mode == .ReleaseSafe;

pub fn should_assert() bool {
    return @inComptime() or SHOULD_ASSERT;
}
pub fn should_assert_with_force(comptime FORCE: bool) bool {
    return FORCE or @inComptime() or SHOULD_ASSERT;
}

pub inline fn print_header(comptime BEFORE: []const u8, comptime tag: []const u8, comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8, comptime AFTER: []const u8) []const u8 {
    @setEvalBranchQuota(5000);
    const timing = if (in_comptime) "\n\x1b[1GCOMPTIME " else "\n\x1b[1GRUNTIME ";
    const newline = if (in_comptime) "\n" else "\n\t";
    const loc_prefix = if (src_loc) |s| "Zig → " ++ s.module ++ " → " else "";
    const loc_func = if (src_loc) |s| s.fn_name ++ "(...)" else "";
    const link = if (src_loc) |s| s.file ++ ":" ++ std.fmt.comptimePrint("{d}", .{s.line}) ++ ":" ++ std.fmt.comptimePrint("{d}", .{s.column}) ++ " → " else "";
    return BEFORE ++ timing ++ tag ++ "[" ++ loc_prefix ++ link ++ loc_func ++ "]" ++ newline ++ log ++ AFTER ++ "\n";
}

pub inline fn err_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return print_header(ANSI.FG_RED, "ERROR: ", in_comptime, src_loc, log, ANSI.RESET);
}

pub inline fn warn_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return print_header(ANSI.FG_YELLOW, "WARNING: ", in_comptime, src_loc, log, ANSI.RESET);
}

pub inline fn info_header(comptime in_comptime: bool, comptime src_loc: ?SourceLocation, comptime log: []const u8) []const u8 {
    return print_header("", "INFO: ", in_comptime, src_loc, log, "");
}

pub inline fn assert_with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    const in_comptime = @inComptime();
    if (in_comptime or build.mode == .Debug or build.mode == .ReleaseSafe) {
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
pub inline fn assert_with_reason_always_panic(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    if (!condition) {
        if (@inComptime()) {
            @compileError(std.fmt.comptimePrint(err_header(true, src_loc, reason_fmt), reason_args));
        } else {
            std.debug.panic(err_header(false, src_loc, reason_fmt), reason_args);
        }
        unreachable;
    }
}

pub inline fn warn_with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    const in_comptime = @inComptime();
    if (in_comptime or build.mode == .Debug or build.mode == .ReleaseSafe) {
        if (!condition) {
            if (in_comptime) {
                std.debug.print(std.fmt.comptimePrint(warn_header(in_comptime, src_loc, reason_fmt), reason_args));
            } else {
                std.debug.print(warn_header(in_comptime, src_loc, reason_fmt), reason_args);
            }
        }
    }
}
pub inline fn warn_with_reason_always(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    if (!condition) {
        if (@inComptime()) {
            std.debug.print(std.fmt.comptimePrint(warn_header(true, src_loc, reason_fmt), reason_args));
        } else {
            std.debug.print(warn_header(false, src_loc, reason_fmt), reason_args);
        }
    }
}

pub inline fn warn_unconditional(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    if (@inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe) {
        if (@inComptime()) {
            std.debug.print(std.fmt.comptimePrint(warn_header(true, src_loc, reason_fmt), reason_args));
        } else {
            std.debug.print(warn_header(false, src_loc, reason_fmt), reason_args);
        }
    }
}

pub inline fn warn_unconditional_always(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
    if (@inComptime()) {
        std.debug.print(std.fmt.comptimePrint(warn_header(true, src_loc, reason_fmt), reason_args));
    } else {
        std.debug.print(warn_header(false, src_loc, reason_fmt), reason_args);
    }
}

pub inline fn assert_unreachable(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) noreturn {
    assert_with_reason(false, src_loc, reason_fmt, reason_args);
    unreachable;
}
pub inline fn assert_unreachable_always_panic(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) noreturn {
    assert_with_reason_always_panic(false, src_loc, reason_fmt, reason_args);
    unreachable;
}

pub inline fn assert_unreachable_err(comptime src_loc: ?SourceLocation, err: anyerror) noreturn {
    assert_with_reason(false, src_loc, "errors are expected to be unreachable here, got err: {s}", .{@errorName(err)});
    unreachable;
}

pub inline fn assert_unreachable_err_always_panic(comptime src_loc: ?SourceLocation, err: anyerror) noreturn {
    assert_with_reason_always_panic(false, src_loc, "errors are expected to be unreachable here, got err: {s}", .{@errorName(err)});
    unreachable;
}

pub fn assert_pointer_resides_in_slice(comptime T: type, slice: []const T, pointer: *const T, comptime src_loc: ?SourceLocation) void {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const ptr_addr = @intFromPtr(pointer);
    assert_with_reason(start_addr <= ptr_addr and ptr_addr <= end_addr, src_loc, "pointer to `{s}` ({X}) does not reside within slice [{X} -> {X}]", .{ @typeName(T), ptr_addr, start_addr, end_addr });
}

pub fn assert_slice_resides_in_slice(comptime T: type, slice: []const T, sub_slice: []const T, comptime src_loc: ?SourceLocation) void {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const sub_start_addr = @intFromPtr(sub_slice.ptr);
    const sub_end_addr = @intFromPtr(sub_slice.ptr + sub_slice.len - 1);
    assert_with_reason(start_addr <= sub_start_addr and sub_end_addr <= end_addr, src_loc, "sub-slice of `{s}` [{X} -> {X}] does not reside within slice [{X} -> {X}]", .{ @typeName(T), sub_start_addr, sub_end_addr, start_addr, end_addr });
}

pub fn assert_idx_less_than_len(idx: anytype, len: anytype, comptime src_loc: ?SourceLocation) void {
    assert_with_reason(idx < len, src_loc, "index ({d}) out of bounds for slice/list len ({d})", .{ idx, len });
}

pub fn assert_idx_and_pointer_reside_in_slice_and_match(comptime T: type, slice: []const T, idx: usize, pointer: *const T, comptime src_loc: ?SourceLocation) void {
    assert_with_reason(idx < slice.len, src_loc, "index ({d}) out of bounds for slice/list len ({d})", .{ idx, slice.len });
    const idx_addr = @intFromPtr(&slice[idx]);
    const ptr_addr = @intFromPtr(pointer);
    assert_with_reason(idx_addr == ptr_addr, "pointer to `{s}` ({X}) does not match pointer to slice[{d}] ({d})", .{ @typeName(T), ptr_addr, idx, idx_addr });
}

pub inline fn assert_allocation_failure(comptime src: ?SourceLocation, comptime T: type, count: usize, err: anyerror) noreturn {
    assert_with_reason(false, src, "failed to allocate memory for {d} items of type {s} (size needed = {d} bytes), error = {s}", .{ count, @typeName(T), count * @sizeOf(T), @errorName(err) });
    unreachable;
}
pub inline fn assert_allocation_failure_always_panic(comptime src: ?SourceLocation, comptime T: type, count: usize, err: anyerror) noreturn {
    assert_with_reason_always_panic(false, src, "failed to allocate memory for {d} items of type {s} (size needed = {d} bytes), error = {s}", .{ count, @typeName(T), count * @sizeOf(T), @errorName(err) });
    unreachable;
}
pub fn assert_comptime_write_failure(comptime src: ?SourceLocation, err: anyerror) noreturn {
    assert_with_reason(false, src, "a comptime write operation faied, error = {s}", .{@errorName(err)});
    unreachable;
}

pub fn assert_field_is_type(comptime field: std.builtin.Type.StructField, comptime T: type) void {
    assert_with_reason(field.type == T, @src(), "field `{s}` was type `{s}`, but needed to be type `{s}`", .{ field.name, @typeName(field.type), @typeName(T) });
}

pub fn assert_is_type(comptime THIS_T: type, comptime NEED_T: type) void {
    assert_with_reason(THIS_T == NEED_T, @src(), "got type `{s}`, but needed type `{s}`", .{ @typeName(THIS_T), @typeName(NEED_T) });
}

pub fn assert_is_float(comptime T: type, comptime src: ?SourceLocation) void {
    assert_with_reason(Types.type_is_float(T), src, "type must be a float type, got type `{s}`", .{@typeName(T)});
}
pub fn assert_is_int(comptime T: type, comptime src: ?SourceLocation) void {
    assert_with_reason(Types.type_is_int(T), src, "type must be an integer type, got type `{s}`", .{@typeName(T)});
}
pub fn assert_is_unsigned_int(comptime T: type, comptime src: ?SourceLocation) void {
    assert_with_reason(Types.type_is_unsigned_int(T), src, "type must be an unsigned integer type, got type `{s}`", .{@typeName(T)});
}
pub fn assert_is_signed_int(comptime T: type, comptime src: ?SourceLocation) void {
    assert_with_reason(Types.type_is_signed_int(T), src, "type must be a signed integer type, got type `{s}`", .{@typeName(T)});
}

pub fn warn_experimental(comptime src: SourceLocation, comptime msg: [:0]const u8, args: anytype) void {
    warn_with_reason(SHOULD_ASSERT, src, "USING EXPERIMENTAL FEATURE: " ++ msg, args);
}
pub fn warn_untested(comptime src: SourceLocation, comptime msg: [:0]const u8, args: anytype) void {
    warn_with_reason(SHOULD_ASSERT, src, "USING FEATURE WITH NO TESTS: " ++ msg, args);
}
pub fn warn_has_bug_somewhere(comptime src: SourceLocation, comptime msg: [:0]const u8, args: anytype) void {
    warn_with_reason(SHOULD_ASSERT, src, "FEATURE HAS UNLOCATED BUG: " ++ msg, args);
}

pub fn AssertHandler(comptime MODE: Common.AssertBehavior) type {
    return switch (MODE) {
        .IGNORE => struct {
            const Self = @This();

            pub inline fn _should_assert() bool {
                return false;
            }

            pub inline fn _with_reason(_: bool, comptime _: ?SourceLocation, _: []const u8, _: anytype) void {
                return;
            }
            pub inline fn _unreachable(comptime _: ?SourceLocation, _: []const u8, _: anytype) noreturn {
                unreachable;
            }
            pub inline fn _unreachable_err(comptime _: ?SourceLocation, _: anyerror) noreturn {
                unreachable;
            }
            pub inline fn _allocation_failure(comptime _: ?SourceLocation, comptime _: type, _: usize, _: anyerror) noreturn {
                unreachable;
            }

            pub inline fn _start_before_end(comptime _: ?SourceLocation, _: anytype, _: anytype) void {
                return;
            }
            pub inline fn _index_in_range(comptime _: ?SourceLocation, _: anytype, _: anytype) void {
                return;
            }
        },
        .PANIC_IN_SAFE_MODES => struct {
            const Self = @This();

            pub inline fn _should_assert() bool {
                return @inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe;
            }

            pub inline fn _with_reason(cond: bool, comptime src: ?SourceLocation, reason_fmt: []const u8, args: anytype) void {
                assert_with_reason(cond, src, reason_fmt, args);
            }
            pub inline fn _unreachable(comptime src: ?SourceLocation, reason_fmt: []const u8, args: anytype) noreturn {
                assert_unreachable(src, reason_fmt, args);
            }
            pub inline fn _unreachable_err(comptime src: ?SourceLocation, err: anyerror) noreturn {
                assert_unreachable_err(src, err);
            }
            pub inline fn _allocation_failure(comptime src: ?SourceLocation, comptime T: type, count: usize, err: anyerror) noreturn {
                assert_allocation_failure(src, T, count, err);
            }
            pub inline fn _start_before_end(comptime src: ?SourceLocation, start: anytype, end: anytype) void {
                assert_with_reason_always_panic(MathX.upgrade_less_than_or_equal(start, end), src, "start location ({d}) MUST come before or be equal to end location ({d})", .{ start, end });
            }
            pub inline fn _index_in_range(comptime src: ?SourceLocation, idx: anytype, len: anytype) void {
                assert_with_reason_always_panic(MathX.upgrade_less_than(idx, len), src, "index ({d}) MUST be less than len ({d})", .{ idx, len });
            }
        },
        .ALWAYS_PANIC => struct {
            const Self = @This();

            pub inline fn _should_assert() bool {
                return true;
            }

            pub inline fn _with_reason(cond: bool, comptime src: ?SourceLocation, reason_fmt: []const u8, args: anytype) void {
                assert_with_reason_always_panic(cond, src, reason_fmt, args);
            }
            pub inline fn _unreachable(comptime src: ?SourceLocation, reason_fmt: []const u8, args: anytype) noreturn {
                assert_unreachable_always_panic(src, reason_fmt, args);
            }
            pub inline fn _unreachable_err(comptime src: ?SourceLocation, err: anyerror) noreturn {
                assert_unreachable_err_always_panic(src, err);
            }
            pub inline fn _allocation_failure(comptime src: ?SourceLocation, comptime T: type, count: usize, err: anyerror) noreturn {
                assert_allocation_failure_always_panic(src, T, count, err);
            }
            pub inline fn _start_before_end(comptime src: ?SourceLocation, start: anytype, end: anytype) void {
                assert_with_reason(MathX.upgrade_less_than_or_equal(start, end), src, "start location ({d}) MUST come before or be equal to end location ({d})", .{});
            }
            pub inline fn _index_in_range(comptime src: ?SourceLocation, idx: anytype, len: anytype) void {
                assert_with_reason(MathX.upgrade_less_than(idx, len), src, "index ({d}) MUST be less than len ({d})", .{ idx, len });
            }
        },
    };
}

pub fn WarnHandler(comptime MODE: Common.WarnBehavior) type {
    return switch (MODE) {
        .IGNORE => struct {
            const Self = @This();

            pub inline fn _should_warn() bool {
                return false;
            }

            pub inline fn _with_reason(_: bool, comptime _: ?SourceLocation, _: []const u8, _: anytype) void {
                return;
            }
            pub inline fn _unconditional(comptime _: ?SourceLocation, _: []const u8, _: anytype) void {
                return;
            }
            pub inline fn _exact_size_mismatch(_: anytype, _: anytype, comptime _: ?SourceLocation, _: []const u8, _: anytype) void {
                return;
            }
        },
        .WARN_IN_DEBUG => struct {
            const Self = @This();

            pub inline fn _should_warn() bool {
                return @inComptime() or build.mode == .Debug;
            }

            pub inline fn _with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                if (@inComptime() or build.mode == .Debug) {
                    warn_with_reason(condition, src_loc, reason_fmt, reason_args);
                }
            }
            pub inline fn _unconditional(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                if (@inComptime() or build.mode == .Debug) {
                    warn_unconditional(src_loc, reason_fmt, reason_args);
                }
            }
            pub inline fn _exact_size_mismatch(a: anytype, b: anytype, comptime src_loc: ?SourceLocation) void {
                if (@inComptime() or build.mode == .Debug) {
                    warn_with_reason(MathX.upgrade_equal_to(a, b), src_loc, "left input 'a' ({d}) does not match right input 'b' ({d})", .{ a, b });
                }
            }
        },
        .WARN_IN_SAFE_MODES => struct {
            const Self = @This();

            pub inline fn _should_warn() bool {
                return @inComptime() or build.mode == .Debug or build.mode == .ReleaseSafe;
            }

            pub inline fn _with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                warn_with_reason(condition, src_loc, reason_fmt, reason_args);
            }
            pub inline fn _unconditional(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                warn_unconditional(src_loc, reason_fmt, reason_args);
            }
            pub inline fn _exact_size_mismatch(a: anytype, b: anytype, comptime src_loc: ?SourceLocation) void {
                warn_with_reason(MathX.upgrade_equal_to(a, b), src_loc, "left input 'a' ({d}) does not match right input 'b' ({d})", .{ a, b });
            }
        },
        .ALWAYS_WARN => struct {
            const Self = @This();

            pub inline fn _should_warn() bool {
                return true;
            }

            pub inline fn _with_reason(condition: bool, comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                warn_with_reason_always(condition, src_loc, reason_fmt, reason_args);
            }
            pub inline fn _unconditional(comptime src_loc: ?SourceLocation, reason_fmt: []const u8, reason_args: anytype) void {
                warn_unconditional_always(src_loc, reason_fmt, reason_args);
            }
            pub inline fn _exact_size_mismatch(a: anytype, b: anytype, comptime src_loc: ?SourceLocation) void {
                warn_with_reason_always(MathX.upgrade_equal_to(a, b), src_loc, "left input 'a' ({d}) does not match right input 'b' ({d})", .{ a, b });
            }
        },
    };
}
