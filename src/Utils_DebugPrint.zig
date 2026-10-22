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

pub const TypeNameMode = enum {
    FULL_TYPE_NAME,
    TYPE_NAME_NO_GENERICS,
    LOCAL_TYPE_NAME,
    LOCAL_TYPE_NAME_NO_GENERICS,
};

pub const OffsetMode = enum {
    NO_OFFSET,
    LOCAL_OFFSET,
    TOTAL_OFFSET,
};

const DEFAULT_DEPTH_LIMIT = 32;
const INDENT_STR = "  ";

pub fn debug_val(name: ?[]const u8, value: anytype) void {
    debug_val_internal(name, value, 0, 32, .TYPE_NAME_NO_GENERICS, .NO_OFFSET, 0);
}
pub fn debug_val_advanced(name: ?[]const u8, value: anytype, depth_limit: usize, comptime TYPE_NAME_MODE: TypeNameMode, comptime OFFSET_MODE: OffsetMode) void {
    debug_val_internal(name, value, 0, depth_limit, TYPE_NAME_MODE, OFFSET_MODE, 0);
}

fn indent(ind: usize) void {
    var i: usize = 0;
    while (i < ind) : (i += 1) {
        std.debug.print(INDENT_STR, .{});
    }
}

fn debug_val_internal(name: ?[]const u8, value: anytype, ind: usize, depth_limit: usize, comptime TMODE: TypeNameMode, comptime OMODE: OffsetMode, offset: usize) void {
    if (ind > depth_limit) {
        indent(ind);
        switch (OMODE) {
            .NO_OFFSET => {},
            .LOCAL_OFFSET, .TOTAL_OFFSET => {
                std.debug.print("{x:_>4}_ ", .{offset});
            },
        }
        if (name) |n| std.debug.print("{s} = ", .{n});
        std.debug.print("... <MORE ITEMS>\n", .{});
        return;
    }

    indent(ind);
    switch (OMODE) {
        .NO_OFFSET => {},
        .LOCAL_OFFSET, .TOTAL_OFFSET => {
            std.debug.print("{x:_>4}_ ", .{offset});
        },
    }
    if (name) |n| {
        std.debug.print("{s} = ", .{n});
    }

    print_payload(value, ind, depth_limit, TMODE, OMODE, offset);
}

fn print_payload(value: anytype, ind: usize, depth_limit: usize, comptime TMODE: TypeNameMode, comptime OMODE: OffsetMode, offset: usize) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    switch (info) {
        .@"struct" => |s_info| {
            if (s_info.field_names.len == 0) {
                std.debug.print("{s}{{}}\n", .{type_name(TMODE, T)});
                return;
            }
            std.debug.print("{s}{{\n", .{type_name(TMODE, T)});
            const base_off: usize = switch (comptime OMODE) {
                .NO_OFFSET => 0,
                .LOCAL_OFFSET => 0,
                .TOTAL_OFFSET => offset,
            };
            inline for (s_info.field_names) |field_name| {
                debug_val_internal(field_name, @field(value, field_name), ind + 1, depth_limit, TMODE, OMODE, base_off + @offsetOf(T, field_name));
            }
            indent(ind);
            std.debug.print("}}\n", .{});
        },
        .@"union" => |u_info| {
            if (u_info.tag_type) |_| {
                if (u_info.field_names.len == 0) {
                    std.debug.print("{s}{{}}\n", .{type_name(TMODE, T)});
                    return;
                }
                std.debug.print("{s}{{\n", .{type_name(TMODE, T)});
                const base_off: usize = switch (comptime OMODE) {
                    .NO_OFFSET => 0,
                    .LOCAL_OFFSET => 0,
                    .TOTAL_OFFSET => offset,
                };
                switch (value) {
                    inline else => |payload| {
                        const active_tag_name = @tagName(value);
                        debug_val_internal(active_tag_name, payload, ind + 1, depth_limit, TMODE, OMODE, base_off);
                    },
                }
                indent(ind);
                std.debug.print("}}\n", .{});
            } else {
                std.debug.print("{s} <UNTAGGED UNION CANNOT BE PRINTED> \n", .{type_name(TMODE, T)});
            }
        },
        .int, .comptime_int, .float, .comptime_float => {
            std.debug.print("{d}\n", .{value});
        },
        .bool => {
            std.debug.print("{}\n", .{value});
        },
        .@"enum", .enum_literal => {
            std.debug.print(".{s}\n", .{@tagName(value)});
        },
        .optional => {
            const base_off: usize = switch (comptime OMODE) {
                .NO_OFFSET => 0,
                .LOCAL_OFFSET => 0,
                .TOTAL_OFFSET => offset,
            };
            if (value) |unwrapped| {
                print_payload(unwrapped, ind, depth_limit, TMODE, OMODE, base_off);
            } else {
                std.debug.print("null\n", .{});
            }
        },
        .error_union => {
            const base_off: usize = switch (comptime OMODE) {
                .NO_OFFSET => 0,
                .LOCAL_OFFSET => 0,
                .TOTAL_OFFSET => offset,
            };
            if (value) |payload| {
                print_payload(payload, ind, depth_limit, TMODE, OMODE, base_off);
            } else |err| {
                std.debug.print("error.{s}\n", .{@errorName(err)});
            }
        },
        .error_set => {
            std.debug.print("error.{s}\n", .{@errorName(value)});
        },
        .pointer => |p_info| {
            switch (p_info.size) {
                .slice => {
                    if (p_info.child == u8) {
                        std.debug.print("0x{x} -> {s}\"{s}\"\n", .{ @intFromPtr(value.ptr), if (p_info.is_const) "const " else "", value });
                    } else {
                        if (value.len == 0) {
                            std.debug.print("0x{x} -> [{s}]{s}{s}{{}}\n", .{ @intFromPtr(value.ptr), if (p_info.sentinel_ptr != null) ":<SENTINEL>" else "", if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                        } else {
                            std.debug.print("0x{x} -> [{s}]{s}{s}{{\n", .{ @intFromPtr(value.ptr), if (p_info.sentinel_ptr != null) ":<SENTINEL>" else "", if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                            var off: usize = switch (comptime OMODE) {
                                .NO_OFFSET => 0,
                                .LOCAL_OFFSET => 0,
                                .TOTAL_OFFSET => offset,
                            };

                            for (value, 0..) |item, i| {
                                var buf: [32]u8 = undefined;
                                const idx_name = std.fmt.bufPrint(&buf, "[{d}]", .{i}) catch "[?]";
                                debug_val_internal(idx_name, item, ind + 1, depth_limit, TMODE, OMODE, off);
                                off += @sizeOf(p_info.child);
                            }
                            indent(ind);
                            std.debug.print("}}\n", .{});
                        }
                    }
                },
                .one => {
                    if (p_info.child == anyopaque) {
                        std.debug.print("0x{x} -> &{s}<ANYOPAQUE TYPE>\n", .{ @intFromPtr(value), if (p_info.is_const) "const " else "" });
                    } else if (p_info.child == anyopaque or @typeInfo(p_info.child) == .@"opaque") {
                        std.debug.print("0x{x} -> &{s}{s}<OPAQUE TYPE>\n", .{ @intFromPtr(value), if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                    } else {
                        std.debug.print("0x{x} -> &{s}", .{ @intFromPtr(value), if (p_info.is_const) "const " else "" });
                        print_payload(value.*, ind, depth_limit, TMODE);
                    }
                },
                .many, .c => {
                    if (@intFromPtr(value) == 0) {
                        std.debug.print("null\n", .{});
                    } else {
                        if (p_info.sentinel()) |sentinel| {
                            var i: usize = 0;
                            var v: p_info.child = value[i];
                            if (v == sentinel) {
                                std.debug.print("0x{x} -> [*:]{s}{s}{{}}\n", .{ if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                            } else {
                                std.debug.print("0x{x} -> [*:]{s}{s}{{\n", .{ if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                                var off: usize = switch (comptime OMODE) {
                                    .NO_OFFSET => 0,
                                    .LOCAL_OFFSET => 0,
                                    .TOTAL_OFFSET => offset,
                                };
                                while (v != sentinel) {
                                    var buf: [32]u8 = undefined;
                                    const idx_name = std.fmt.bufPrint(&buf, "[{d}]", .{i}) catch "[?]";
                                    debug_val_internal(idx_name, v, ind + 1, depth_limit, TMODE, OMODE, off);
                                    i += 1;
                                    v = value[i];
                                    off += @sizeOf(p_info.child);
                                }
                                indent(ind);
                                std.debug.print("}}\n", .{});
                            }
                        } else {
                            std.debug.print("0x{x} -> [*]{s}{s} <MANY-ITEMS UNKNOWN LENGTH>\n", .{ @intFromPtr(value), if (p_info.is_const) "const " else "", type_name(TMODE, p_info.child) });
                        }
                    }
                },
            }
        },
        .array => |a_info| {
            if (a_info.child == u8) {
                std.debug.print("\"{s}\"\n", .{&value});
            } else {
                if (value.len == 0) {
                    std.debug.print("[{d}]{s}{{}}\n", .{ a_info.len, type_name(TMODE, a_info.child) });
                } else {
                    std.debug.print("[{d}]{s}{{\n", .{ a_info.len, type_name(TMODE, a_info.child) });
                    var off: usize = switch (comptime OMODE) {
                        .NO_OFFSET => 0,
                        .LOCAL_OFFSET => 0,
                        .TOTAL_OFFSET => offset,
                    };
                    for (value, 0..) |item, i| {
                        var buf: [32]u8 = undefined;
                        const idx_name = std.fmt.bufPrint(&buf, "[{d}]", .{i}) catch "[?]";
                        debug_val_internal(idx_name, item, ind + 1, depth_limit, TMODE, OMODE, off);
                        off += @sizeOf(a_info.child);
                    }
                    indent(ind);
                    std.debug.print("}}\n", .{});
                }
            }
        },
        .vector => |v_info| {
            std.debug.print("@Vector({d}, {s}){{\n", .{ v_info.len, type_name(TMODE, v_info.child) });
            var off: usize = switch (comptime OMODE) {
                .NO_OFFSET => 0,
                .LOCAL_OFFSET => 0,
                .TOTAL_OFFSET => offset,
            };
            inline for (0..v_info.len) |i| {
                var buf: [32]u8 = undefined;
                const idx_name = std.fmt.bufPrint(&buf, "[{d}]", .{i}) catch "[?]";
                debug_val_internal(idx_name, value[i], ind + 1, depth_limit, TMODE, OMODE, off);
                off += @sizeOf(v_info.child);
            }
            indent(ind);
            std.debug.print("}}\n", .{});
        },
        .void => {
            std.debug.print("void\n", .{});
        },
        .null => {
            std.debug.print("null\n", .{});
        },
        .undefined => {
            std.debug.print("undefined\n", .{});
        },
        .type => {
            std.debug.print("type({s})\n", .{type_name(TMODE, value)});
        },
        .@"fn" => {
            std.debug.print("(fn {s})\n", .{type_name(TMODE, T)});
        },
        .@"opaque" => {
            std.debug.print("<OPAQUE TYPE>\n", .{});
        },
        else => {
            std.debug.print("{any}\n", .{value});
        },
    }
}

/// Trims generic parameters from a type name string, replacing `(...)` with `(...)`.
fn trim_name_generics(comptime raw_name: []const u8) []const u8 {
    comptime {
        var out_len: usize = 0;
        var depth: usize = 0;
        for (raw_name) |c| {
            if (c == '(') {
                if (depth == 0) out_len += 5; // "(...)"
                depth += 1;
            } else if (c == ')') {
                if (depth > 0) depth -= 1;
            } else if (depth == 0) {
                out_len += 1;
            }
        }

        var buf: [out_len]u8 = undefined;
        var idx: usize = 0;
        depth = 0;
        for (raw_name) |c| {
            if (c == '(') {
                if (depth == 0) {
                    @memcpy(buf[idx..][0..5], "(...)");
                    idx += 5;
                }
                depth += 1;
            } else if (c == ')') {
                if (depth > 0) depth -= 1;
            } else if (depth == 0) {
                buf[idx] = c;
                idx += 1;
            }
        }

        const final_buf: [out_len]u8 = buf;
        return &final_buf;
    }
}

fn type_name_no_generics(comptime T: type) []const u8 {
    return comptime trim_name_generics(@typeName(T));
}

fn local_type_name_no_generics(comptime T: type) []const u8 {
    comptime {
        const raw_name = @typeName(T);
        var start: usize = 0;
        var depth: usize = 0;

        for (raw_name, 0..) |c, i| {
            if (c == '(') {
                depth += 1;
            } else if (c == ')') {
                if (depth > 0) depth -= 1;
            } else if (depth == 0 and c == '.') {
                start = i + 1;
            }
        }

        return trim_name_generics(raw_name[start..]);
    }
}
fn local_type_name(comptime T: type) []const u8 {
    comptime {
        const raw_name = @typeName(T);
        var start: usize = 0;
        var depth: usize = 0;

        for (raw_name, 0..) |c, i| {
            if (c == '(') {
                depth += 1;
            } else if (c == ')') {
                if (depth > 0) depth -= 1;
            } else if (depth == 0 and c == '.') {
                start = i + 1;
            }
        }

        return raw_name[start..];
    }
}

pub fn type_name(comptime mode: TypeNameMode, comptime T: type) []const u8 {
    return switch (comptime mode) {
        .FULL_TYPE_NAME => @typeName(T),
        .LOCAL_TYPE_NAME => local_type_name(T),
        .LOCAL_TYPE_NAME_NO_GENERICS => local_type_name_no_generics(T),
        .TYPE_NAME_NO_GENERICS => type_name_no_generics(T),
    };
}
