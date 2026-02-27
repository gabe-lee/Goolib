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
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const BinarySearch = Root.BinarySearch;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;

pub const _Fuzzer = @import("./Utils_Fuzz.zig");

pub const Alloc = @import("./Utils_Allocator.zig");
pub const File = @import("./Utils_File.zig");
pub const EnumeratedDefs = @import("./Utils_EnumeratedDefs.zig");

pub inline fn inline_swap(comptime T: type, a: *T, b: *T, temp: *T) void {
    temp.* = a.*;
    a.* = b.*;
    b.* = temp.*;
}

pub inline fn simple_rand_int(comptime T: type, min: T, max: T) T {
    return simple_n_rand_ints(T, 1, min, max)[0];
}

pub fn simple_n_rand_ints(comptime T: type, comptime count: comptime_int, min: T, max: T) [count]T {
    if (count <= 0) @compileError("count must greater than zero");
    assert(max >= min);
    const range = max - min;
    var time = @as(u64, @bitCast(std.time.microTimestamp()));
    var arr: [count]T = undefined;
    var r_idx: usize = time % RANDOM_U64_TABLE.len;
    arr[0] = @as(T, @truncate(((time ^ RANDOM_U64_TABLE[r_idx]) % range) + min));
    var idx: usize = 1;
    while (idx < count) : (idx += 1) {
        r_idx = (r_idx + 1) % RANDOM_U64_TABLE.len;
        time += 13;
        arr[idx] = @as(T, @truncate(((time ^ RANDOM_U64_TABLE[r_idx]) % range) + min));
    }
    return arr;
}

pub const RANDOM_U64_TABLE = [_]u64{
    0xc655e7b110faaba4,
    0xd4b78397a1a15d25,
    0xb236e97711ad340d,
    0xf127f61ced23b200,
    0x656b44b28ab483fc,
    0xf2e94724e57cd9b6,
    0x4fa96adb61f4feda,
    0xdaa68d868f398349,
    0x75fc305105d907df,
    0x37f445d3dfa06b7f,
    0x988c9ae35f18847c,
    0xeb844d8faf9e6205,
    0x3976977b2b27cd72,
    0xa0a344a0b433947e,
    0xf1f4dce921a05b8d,
    0x13a3a109aca5ae7d,
};

pub fn c_strings_equal(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (true) : (i += 1) {
        if (a[i] != b[i]) return false;
        if (a[i] == '0') return true;
    }
}

pub fn c_args_to_zig_args(c_args: CArgsList) [][*:0]u8 {
    if (c_args.len == 0 or c_args.ptr == null) {
        const NULL: [0][*:0]u8 = @splat(@ptrFromInt(std.math.maxInt(usize)));
        return NULL[0..0];
    }
    const good_args_list = c_args.ptr.?;
    assert(check_no_early_null: {
        var i: c_int = 0;
        while (i < c_args.len) : (i += 1) {
            if (good_args_list[@intCast(i)] == null) break :check_no_early_null false;
        }
        break :check_no_early_null true;
    });
    const cast_ptr: [*][*:0]u8 = @ptrCast(good_args_list);
    return cast_ptr[0..@intCast(c_args.len)];
}
pub fn zig_args_to_c_args(zig_args: [][*:0]u8) CArgsList {
    const cast_ptr: [*]?[*:0]u8 = @ptrCast(zig_args.ptr);
    assert(cast_ptr[zig_args.len] == null);
    return CArgsList{
        .ptr = @ptrCast(cast_ptr),
        .len = @intCast(zig_args.len),
    };
}
pub const CArgsList = struct {
    ptr: ?[*:null]?[*:0]u8,
    len: c_int,

    pub fn c_args_list(len: c_int, ptr: ?[*:null]?[*:0]u8) CArgsList {
        return CArgsList{ .ptr = ptr, .len = len };
    }
};

pub inline fn secure_zero(comptime T: type, slice: []volatile T) void {
    const raw_len = slice.len * @sizeOf(T);
    const u8_ptr: [*]volatile u8 = @ptrCast(slice.ptr);
    @memset(u8_ptr[0..raw_len], 0);
}
pub inline fn secure_memset_undefined(comptime T: type, slice: []volatile T) void {
    if (build.mode == .Debug or build.mode == .ReleaseSafe) {
        const cast_ptr: [*]volatile u8 = @ptrCast(@alignCast(slice.ptr));
        const byte_len = slice.len * @sizeOf(T);
        const cast_slice: []volatile u8 = cast_ptr[0..byte_len];
        @memset(cast_slice, 0xAA);
    } else {
        @memset(slice, 0);
    }
}
pub inline fn secure_memset_const(comptime T: type, slice: []volatile T, comptime val: T) void {
    @memset(slice, val);
}
pub inline fn secure_memset(comptime T: type, slice: []volatile T, val: T) void {
    @memset(slice, val);
}

pub inline fn can_infer_type_order(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float, .bool, .@"enum" => return true,
        .pointer => |info| {
            if (info.size != .one) return false;
            switch (@typeInfo(info.child)) {
                .int, .comptime_int, .float, .comptime_float, .bool, .@"enum" => return true,
                else => return false,
            }
        },
        else => return false,
    }
}

pub inline fn infered_less_than(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    assert_with_reason(can_infer_type_order(A), @src(), "type of `a` (" ++ @typeName(A) ++ ") cannot infer order", .{});
    assert_with_reason(can_infer_type_order(B), @src(), "type of `b` (" ++ @typeName(B) ++ ") cannot infer order", .{});
    const aa = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const AA = Types.pointer_child_type(A);
        break :unwrap if (Types.type_is_bool(AA)) @intFromBool(a.*) else if (Types.type_is_enum(AA)) @intFromEnum(a.*) else a.*;
    } else if (Types.type_is_bool(A)) @intFromBool(a) else if (Types.type_is_enum(A)) @intFromEnum(a) else a;
    const bb = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const BB = Types.pointer_child_type(B);
        break :unwrap if (Types.type_is_bool(BB)) @intFromBool(b.*) else if (Types.type_is_enum(BB)) @intFromEnum(b.*) else b.*;
    } else if (Types.type_is_bool(B)) @intFromBool(b) else if (Types.type_is_enum(B)) @intFromEnum(b) else b;
    return aa < bb;
}

pub inline fn infered_greater_than(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    assert_with_reason(can_infer_type_order(A), @src(), "type of `a` (" ++ @typeName(A) ++ ") cannot infer order", .{});
    assert_with_reason(can_infer_type_order(B), @src(), "type of `b` (" ++ @typeName(B) ++ ") cannot infer order", .{});
    const aa = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const AA = Types.pointer_child_type(A);
        break :unwrap if (Types.type_is_bool(AA)) @intFromBool(a.*) else if (Types.type_is_enum(AA)) @intFromEnum(a.*) else a.*;
    } else if (Types.type_is_bool(A)) @intFromBool(a) else if (Types.type_is_enum(A)) @intFromEnum(a) else a;
    const bb = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const BB = Types.pointer_child_type(B);
        break :unwrap if (Types.type_is_bool(BB)) @intFromBool(b.*) else if (Types.type_is_enum(BB)) @intFromEnum(b.*) else b.*;
    } else if (Types.type_is_bool(B)) @intFromBool(b) else if (Types.type_is_enum(B)) @intFromEnum(b) else b;
    return aa > bb;
}

pub inline fn infered_less_than_or_equal(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    assert_with_reason(can_infer_type_order(A), @src(), "type of `a` (" ++ @typeName(A) ++ ") cannot infer order", .{});
    assert_with_reason(can_infer_type_order(B), @src(), "type of `b` (" ++ @typeName(B) ++ ") cannot infer order", .{});
    const aa = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const AA = Types.pointer_child_type(A);
        break :unwrap if (Types.type_is_bool(AA)) @intFromBool(a.*) else if (Types.type_is_enum(AA)) @intFromEnum(a.*) else a.*;
    } else if (Types.type_is_bool(A)) @intFromBool(a) else if (Types.type_is_enum(A)) @intFromEnum(a) else a;
    const bb = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const BB = Types.pointer_child_type(B);
        break :unwrap if (Types.type_is_bool(BB)) @intFromBool(b.*) else if (Types.type_is_enum(BB)) @intFromEnum(b.*) else b.*;
    } else if (Types.type_is_bool(B)) @intFromBool(b) else if (Types.type_is_enum(B)) @intFromEnum(b) else b;
    return aa <= bb;
}

pub inline fn infered_greater_than_or_equal(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    assert_with_reason(can_infer_type_order(A), @src(), "type of `a` (" ++ @typeName(A) ++ ") cannot infer order", .{});
    assert_with_reason(can_infer_type_order(B), @src(), "type of `b` (" ++ @typeName(B) ++ ") cannot infer order", .{});
    const aa = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const AA = Types.pointer_child_type(A);
        break :unwrap if (Types.type_is_bool(AA)) @intFromBool(a.*) else if (Types.type_is_enum(AA)) @intFromEnum(a.*) else a.*;
    } else if (Types.type_is_bool(A)) @intFromBool(a) else if (Types.type_is_enum(A)) @intFromEnum(a) else a;
    const bb = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const BB = Types.pointer_child_type(B);
        break :unwrap if (Types.type_is_bool(BB)) @intFromBool(b.*) else if (Types.type_is_enum(BB)) @intFromEnum(b.*) else b.*;
    } else if (Types.type_is_bool(B)) @intFromBool(b) else if (Types.type_is_enum(B)) @intFromEnum(b) else b;
    return aa >= bb;
}

pub inline fn infered_equal(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    assert_with_reason(can_infer_type_order(A), @src(), "type of `a` (" ++ @typeName(A) ++ ") cannot infer order", .{});
    assert_with_reason(can_infer_type_order(B), @src(), "type of `b` (" ++ @typeName(B) ++ ") cannot infer order", .{});
    const aa = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const AA = Types.pointer_child_type(A);
        break :unwrap if (Types.type_is_bool(AA)) @intFromBool(a.*) else if (Types.type_is_enum(AA)) @intFromEnum(a.*) else a.*;
    } else if (Types.type_is_bool(A)) @intFromBool(a) else if (Types.type_is_enum(A)) @intFromEnum(a) else a;
    const bb = if (Types.type_is_pointer_or_slice(A)) unwrap: {
        const BB = Types.pointer_child_type(B);
        break :unwrap if (Types.type_is_bool(BB)) @intFromBool(b.*) else if (Types.type_is_enum(BB)) @intFromEnum(b.*) else b.*;
    } else if (Types.type_is_bool(B)) @intFromBool(b) else if (Types.type_is_enum(B)) @intFromEnum(b) else b;
    return aa == bb;
}

pub fn memcopy(from_src: anytype, to_dst: anytype, count: usize) void {
    if (count == 0) return;
    if (Types.type_is_optional(@TypeOf(from_src)) and from_src == null) std.debug.panic("memcopy `from_src` optional type {s} is `null`, but `count` != 0", .{@typeName(@TypeOf(from_src))});
    if (Types.type_is_optional(@TypeOf(to_dst)) and to_dst == null) std.debug.panic("memcopy `to_dst` optional type {s} is `null`, but `count` != 0", .{@typeName(@TypeOf(to_dst))});
    const FROM = if (Types.type_is_optional(@TypeOf(from_src))) Types.optional_type_child(from_src) else @TypeOf(from_src);
    const TO = if (Types.type_is_optional(@TypeOf(to_dst))) Types.optional_type_child(to_dst) else @TypeOf(to_dst);
    const from_src_not_null = if (Types.type_is_optional(@TypeOf(from_src))) from_src.? else from_src;
    const to_dst_not_null = if (Types.type_is_optional(@TypeOf(to_dst))) to_dst.? else to_dst;
    var raw_from: [*]const u8 = undefined;
    var raw_to: [*]u8 = undefined;
    comptime var copy_type: type = undefined;
    if (Types.type_is_array_or_vector(FROM)) {
        assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
        copy_type = Types.array_or_vector_child_type(FROM);
        raw_from = @ptrCast(@alignCast(from_src_not_null[0..count].ptr));
    } else if (Types.type_is_pointer_or_slice(FROM)) {
        const ptr_type = FROM;
        const child_type = Types.pointer_child_type(ptr_type);
        if (Types.pointer_is_slice(ptr_type)) {
            assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
            copy_type = child_type;
            raw_from = @ptrCast(@alignCast(from_src_not_null.ptr));
        } else if (Types.pointer_is_single(ptr_type)) {
            if (Types.type_is_array_or_vector(child_type)) {
                assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
                copy_type = Types.array_or_vector_child_type(FROM);
                raw_from = @ptrCast(@alignCast(from_src_not_null));
            } else {
                assert_with_reason(count == 1, "memcopy `from_src` ({s}) cannot provide {d} items (has 1 item, single item pointer to non-array/vector)", .{ @typeName(FROM), count });
                copy_type = child_type;
                raw_from = @ptrCast(@alignCast(from_src_not_null));
            }
        } else if (Types.pointer_is_many(ptr_type)) {
            if (Types.pointer_type_has_sentinel(ptr_type) and (build.mode == .Debug or build.mode == .ReleaseSafe)) {
                const sentinel = Types.pointer_type_sentinel(ptr_type);
                const len_check_slice = Types.make_const_slice_from_sentinel_ptr_max_len(child_type, sentinel.*, from_src_not_null, count);
                assert_with_reason(len_check_slice.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, len_check_slice.len });
            }
            copy_type = child_type;
            raw_from = @ptrCast(@alignCast(from_src_not_null));
        }
    } else {
        copy_type = FROM;
        raw_from = @ptrCast(@alignCast(&from_src_not_null));
    }
    const raw_count = count * @sizeOf(copy_type);
    if (Types.type_is_pointer_or_slice(TO) and Types.pointer_is_mutable(TO)) {
        const ptr_type = TO;
        const child_type = Types.pointer_child_type(ptr_type);
        if (Types.pointer_is_slice(ptr_type)) {
            assert_with_reason(to_dst_not_null.len >= count, @src(), "`to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
            assert_with_reason(child_type == copy_type, @src(), "`to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
            raw_to = @ptrCast(@alignCast(to_dst_not_null.ptr));
        } else if (Types.pointer_is_single(ptr_type)) {
            if (Types.type_is_array_or_vector(child_type)) {
                assert_with_reason(to_dst_not_null.len >= count, "memcopy `to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
                assert_with_reason(Types.array_or_vector_child_type(child_type) == copy_type, @src(), "`to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
                raw_to = @ptrCast(@alignCast(to_dst_not_null));
            } else {
                assert_with_reason(count == 1, @src(), "`to_dst` ({s}) cannot recieve {d} items (has 1 item capacity, single item pointer to non-array/vector)", .{ @typeName(TO), count });
                assert_with_reason(child_type == copy_type, @src(), "`to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
                raw_to = @ptrCast(@alignCast(to_dst_not_null));
            }
        } else if (Types.pointer_is_many(ptr_type)) {
            if (Types.pointer_type_has_sentinel(ptr_type) and (build.mode == .Debug or build.mode == .ReleaseSafe)) {
                const sentinel = Types.pointer_type_sentinel(ptr_type);
                const len_check_slice = Types.make_const_slice_from_sentinel_ptr_max_len(child_type, sentinel.*, to_dst_not_null, count);
                assert_with_reason(len_check_slice.len >= count, @src(), "`to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
            }
            assert_with_reason(child_type == copy_type, @src(), "`to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
            raw_to = @ptrCast(@alignCast(to_dst_not_null));
        }
    } else @compileError("memcopy `to_dst` must be a mutable pointer type");
    @memcpy(raw_to[0..raw_count], raw_from[0..raw_count]);
}

pub inline fn matches_any(comptime T: type, val: T, set: []const T) bool {
    for (set) |item| {
        if (val == item) return true;
    }
    return false;
}

pub inline fn debug_switch(debug_val: anytype, else_val: anytype) if (build.mode == .Debug) @TypeOf(debug_val) else @TypeOf(else_val) {
    return if (build.mode == .Debug) debug_val else else_val;
}

pub inline fn safe_switch(debug_rel_safe_val: anytype, else_val: anytype) if (build.mode == .Debug or build.mode == .ReleaseSafe) @TypeOf(debug_rel_safe_val) else @TypeOf(else_val) {
    return if (build.mode == .Debug or build.mode == .ReleaseSafe) debug_rel_safe_val else else_val;
}

pub inline fn comp_switch(comptime cond: bool, true_val: anytype, false_val: anytype) if (cond) @TypeOf(true_val) else @TypeOf(false_val) {
    if (cond) return true_val;
    return false_val;
}

pub fn pointer_resides_in_slice(comptime T: type, slice: []const T, pointer: *const T) bool {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const ptr_addr = @intFromPtr(pointer);
    return start_addr <= ptr_addr and ptr_addr <= end_addr;
}

pub fn slice_resides_in_slice(comptime T: type, slice: []const T, sub_slice: []const T) bool {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const sub_start_addr = @intFromPtr(sub_slice.ptr);
    const sub_end_addr = @intFromPtr(sub_slice.ptr + sub_slice.len - 1);
    return start_addr <= sub_start_addr and sub_end_addr <= end_addr;
}

pub fn deep_equal(val_a: anytype, val_b: anytype) bool {
    const A = @TypeOf(val_a);
    const B = @TypeOf(val_b);
    const INFO_A = @typeInfo(A);
    const INFO_B = @typeInfo(B);
    const NAME_A = @typeName(A);
    switch (INFO_A) {
        .noreturn,
        .@"opaque",
        .frame,
        .@"anyframe",
        .undefined,
        .null,
        .void,
        => @compileError("values of type " ++ NAME_A ++ " cannot be equal"),

        .type,
        .bool,
        .int,
        .float,
        .comptime_float,
        .comptime_int,
        .enum_literal,
        .@"enum",
        .@"fn",
        .error_set,
        => return val_a == val_b,

        .pointer => {
            if (INFO_A.pointer.child != INFO_B.pointer.child) return false;
            switch (INFO_A.pointer.size) {
                .c, .many => return val_a == val_b,
                .one => {
                    switch (@typeInfo(INFO_A.pointer.child)) {
                        .@"fn", .@"opaque" => return val_a == val_b,
                        else => return deep_equal(val_a.*, val_b.*),
                    }
                },
                .slice => {
                    if (val_a.len != val_b.len) return false;
                    var i: usize = 0;
                    while (i < val_a.len) : (i += 1) {
                        if (!deep_equal(val_a[i], val_b[i])) return false;
                    }
                    return true;
                },
            }
        },

        .array, .vector => {
            const child_a = if (INFO_A == .vector) INFO_A.vector.child else INFO_A.array.child;
            const child_b = if (INFO_B == .vector) INFO_B.vector.child else INFO_B.array.child;
            if (child_a != child_b) return false;
            const len_a = if (INFO_A == .vector) INFO_A.vector.len else INFO_A.array.len;
            const len_b = if (INFO_B == .vector) INFO_B.vector.len else INFO_B.array.len;
            if (len_a != len_b) return false;
            var i: usize = 0;
            while (i < val_a.len) : (i += 1) {
                if (!deep_equal(val_a[i], val_b[i])) return false;
            }
            return true;
        },

        .@"struct" => |s_info| {
            if (A != B) return false;
            inline for (s_info.fields) |field| {
                if (!deep_equal(@field(val_a, field.name), @field(val_b, field.name))) return false;
            }
            return true;
        },

        .@"union" => |union_info| {
            if (A != B) return false;
            if (union_info.tag_type == null) {
                @compileError("Unable to compare untagged union values for type " ++ NAME_A);
            }

            const Tag = std.meta.Tag(A);

            const tag_a = @as(Tag, val_a);
            const tag_b = @as(Tag, val_b);

            if (tag_a != tag_b) return false;

            // we only reach this switch if the tags are equal
            switch (val_a) {
                inline else => |val, tag| {
                    if (!deep_equal(val, @field(val_b, @tagName(tag)))) return false;
                },
            }
            return true;
        },

        .optional => {
            if (val_a) |payload_a| {
                if (val_b) |payload_b| {
                    if (A != B) return false;
                    return deep_equal(payload_a, payload_b);
                } else {
                    return false;
                }
            } else {
                if (val_b) |_| {
                    return false;
                } else {
                    return true;
                }
            }
        },

        .error_union => {
            if (val_a) |payload_a| {
                if (val_b) |payload_b| {
                    if (A != B) return false;
                    return deep_equal(payload_a, payload_b);
                } else |_| {
                    return false;
                }
            } else |error_a| {
                if (val_b) |_| {
                    return false;
                } else |error_b| {
                    return deep_equal(error_a, error_b);
                }
            }
        },
    }
}

pub fn shallow_equal(val_a: anytype, val_b: anytype) bool {
    const A = @TypeOf(val_a);
    const B = @TypeOf(val_b);
    const INFO_A = @typeInfo(A);
    const INFO_B = @typeInfo(B);
    const NAME_A = @typeName(A);
    switch (INFO_A) {
        .noreturn,
        .@"opaque",
        .frame,
        .@"anyframe",
        .undefined,
        .null,
        .void,
        => @compileError("values of type " ++ NAME_A ++ " cannot be equal"),

        .type,
        .bool,
        .int,
        .float,
        .comptime_float,
        .comptime_int,
        .enum_literal,
        .@"enum",
        .@"fn",
        .error_set,
        => return val_a == val_b,

        .pointer => {
            if (INFO_A.pointer.child != INFO_B.pointer.child) return false;
            switch (INFO_A.pointer.size) {
                .one, .c, .many => return val_a == val_b,
                .slice => {
                    if (val_a.len != val_b.len) return false;
                    var i: usize = 0;
                    while (i < val_a.len) : (i += 1) {
                        if (!shallow_equal(val_a[i], val_b[i])) return false;
                    }
                    return true;
                },
            }
        },

        .array, .vector => {
            const child_a = if (INFO_A == .vector) INFO_A.vector.child else INFO_A.array.child;
            const child_b = if (INFO_B == .vector) INFO_B.vector.child else INFO_B.array.child;
            if (child_a != child_b) return false;
            const len_a = if (INFO_A == .vector) INFO_A.vector.len else INFO_A.array.len;
            const len_b = if (INFO_B == .vector) INFO_B.vector.len else INFO_B.array.len;
            if (len_a != len_b) return false;
            var i: usize = 0;
            while (i < val_a.len) : (i += 1) {
                if (!shallow_equal(val_a[i], val_b[i])) return false;
            }
            return true;
        },

        .@"struct" => {
            if (A != B) return false;
            inline for (INFO_A.@"struct".fields) |field| {
                if (!shallow_equal(@field(val_a, field.name), @field(val_b, field.name))) return false;
            }
            return true;
        },

        .@"union" => {
            if (A != B) return false;
            if (INFO_A.@"union".tag_type == null) {
                @compileError("Unable to compare untagged union values for type " ++ NAME_A);
            }

            const Tag = std.meta.Tag(A);

            const tag_a = @as(Tag, val_a);
            const tag_b = @as(Tag, val_b);

            if (tag_a != tag_b) return false;

            // we only reach this switch if the tags are equal
            switch (val_a) {
                inline else => |val, tag| {
                    if (!shallow_equal(val, @field(val_b, @tagName(tag)))) return false;
                },
            }
            return true;
        },

        .optional => {
            if (val_a) |payload_a| {
                if (val_b) |payload_b| {
                    if (A != B) return false;
                    return shallow_equal(payload_a, payload_b);
                } else {
                    return false;
                }
            } else {
                if (val_b) |_| {
                    return false;
                } else {
                    return true;
                }
            }
        },

        .error_union => {
            if (val_a) |payload_a| {
                if (val_b) |payload_b| {
                    if (A != B) return false;
                    return shallow_equal(payload_a, payload_b);
                } else |_| {
                    return false;
                }
            } else |error_a| {
                if (val_b) |_| {
                    return false;
                } else |error_b| {
                    return shallow_equal(error_a, error_b);
                }
            }
        },
    }
}

pub fn index_from_pointer(comptime T: type, comptime IDX: type, base_ptr: [*]const T, elem_ptr: *const T) IDX {
    const base_addr = @intFromPtr(base_ptr);
    const elem_addr = @intFromPtr(elem_ptr);
    assert_with_reason(elem_addr >= base_addr, @src(), "elem_addr {x} < base_addr {x}, pointer cannot possibly be part of the base collection", .{ elem_addr, base_addr });
    const addr_delta = @intFromPtr(elem_ptr) - @intFromPtr(base_ptr);
    return @intCast(addr_delta / @sizeOf(T));
}

pub fn bools_to_switchable_integer(comptime count: comptime_int, bools: [count]bool) std.meta.Int(.unsigned, count) {
    const RESULT = std.meta.Int(.unsigned, count);
    var result: RESULT = 0;
    inline for (bools, 0..) |b, shift| {
        result |= @as(RESULT, @intCast(@intFromBool(b))) << @intCast(shift);
    }
    return result;
}

// pub const NamedBool = struct {};

// fn bools_to_named_switchable_enum_output(comptime IN_STRUCT: type) type {
//     assert_with_reason(Types.type_is_struct(IN_STRUCT), @src(), "type `IN_STRUCT` must be a struct type, got type `{s}`", .{@typeName(IN_STRUCT)});
//     assert_with_reason(Types.type_is_struct_with_all_fields_same_type(IN_STRUCT, bool), @src(), "type `IN_STRUCT` must be a struct type with all `bool` fields, got type `{s}`", .{@typeName(IN_STRUCT)});
//     const bits :u16= @intCast(@typeInfo(@TypeOf(bools_struct)).@"struct".fields.len);
//     const int = std.meta.Int(.unsigned, bits);

// }

// pub fn bools_to_named_switchable_enum(bools_struct: anytype) enum(std.meta.Int(.unsigned, )) {
//     const RESULT = std.meta.Int(.unsigned, count);
//     var result: RESULT = 0;
//     inline for (bools, 0..) |b, shift| {
//         result |= @as(RESULT, @intCast(@intFromBool(b))) << @intCast(shift);
//     }
//     return result;
// }

pub fn slice_move_one(slice: anytype, old_idx: usize, new_idx: usize) void {
    Assert.assert_with_reason(Types.type_is_slice(@TypeOf(slice)), @src(), "type of `slice` was not a slice type, got {s}", .{@typeName(@TypeOf(slice))});
    const T = @typeInfo(@TypeOf(slice)).pointer.child;
    var widx: isize = @intCast(old_idx);
    const step: isize = if (new_idx > old_idx) 1 else -1;
    var ridx: isize = widx + step;
    const val: T = slice[old_idx];
    while (widx != new_idx) {
        slice[@intCast(widx)] = slice[@intCast(ridx)];
        widx = ridx;
        ridx += step;
    }
    slice[@intCast(widx)] = val;
}

pub fn slice_move_many(slice: anytype, old_first: usize, old_last_inclusive: usize, new_first: usize) void {
    Assert.assert_with_reason(Types.type_is_slice(@TypeOf(slice)), @src(), "type of `slice` was not a slice type, got {s}", .{@typeName(@TypeOf(slice))});
    const T = @typeInfo(@TypeOf(slice)).pointer.child;
    Assert.assert_with_reason(old_first <= old_last_inclusive, @src(), "`old_first` MUST be <= `old_last_inclusive`, got ({d}, {d})", .{ old_first, old_last_inclusive });
    const len_a = (old_last_inclusive - old_first) + 1;
    const slice_a = slice[old_first .. old_first + len_a];
    var total_range: []T = undefined;
    var slice_b: []T = undefined;
    if (new_first < old_first) {
        total_range = slice[new_first .. old_last_inclusive + 1];
        slice_b = slice[new_first..old_first];
    } else {
        total_range = slice[old_first .. new_first + len_a];
        slice_b = slice[old_last_inclusive + 1 .. new_first + len_a];
    }
    slice_reverse(T, slice_a);
    slice_reverse(T, slice_b);
    slice_reverse(T, total_range);
}

pub fn slice_reverse(comptime T: type, slice: []T) void {
    if (slice.len == 0) return;
    var left: usize = 0;
    var right: usize = slice.len - 1;
    var tmp: T = undefined;
    while (left < right) {
        tmp = slice[right];
        slice[right] = slice[left];
        slice[left] = tmp;
        left += 1;
        right -= 1;
    }
}

const HEX = [16]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };
const HEX_MASK = 0b00001111;
const HEX_SHIFT = 4;
const QHEX_OFFSET: u8 = 'A';

const DEC = [10]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' };

pub fn quick_hex(val: anytype) [@sizeOf(@TypeOf(val)) * 2]u8 {
    const T = @TypeOf(val);
    const I = @typeInfo(T);
    var out: [@sizeOf(T) * 2]u8 = undefined;
    var uval: u64 = undefined;
    const LIMIT = @sizeOf(T);
    assert_with_reason(LIMIT > 0 and LIMIT <= 8, @src(), "can only quick_hex() on types with size > 0 and size <= 8, got type {s} (size = {d})", .{ @typeName(T), LIMIT });
    switch (I) {
        .int, .float, .@"enum", .pointer => {
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @bitCast(val);
            uval = @intCast(uint);
        },
        .comptime_int => {
            uval = val;
        },
        .comptime_float => {
            const flt: f64 = val;
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @bitCast(flt);
            uval = @intCast(uint);
        },
        .bool => {
            uval = @intCast(@intFromBool(val));
        },
        else => {
            assert_with_reason(false, @src(), "invalid type for quick_hex(): {s}", .{@typeName(T)});
        },
    }
    var i: usize = LIMIT * 2;
    while (i > 0) {
        i -= 1;
        var h = uval & HEX_MASK;
        out[i] = HEX[h];
        uval >>= HEX_SHIFT;
        i -= 1;
        h = uval & HEX_MASK;
        out[i] = HEX[h];
        uval >>= HEX_SHIFT;
    }
    return out;
}

pub fn quick_unhex(bytes: []const u8, comptime T: type) T {
    var val: u64 = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const b = bytes[i];
        const v = switch (b) {
            '0'...'9' => b - '0',
            'A'...'F' => (b - 'A') + 10,
            'a'...'f' => (b - 'a') + 10,
            else => 0,
        };
        val <<= HEX_SHIFT;
        val |= v;
        i += 1;
    }
    const I = @typeInfo(T);
    switch (I) {
        .int, .float, .@"enum", .pointer => {
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @intCast(val);
            return @bitCast(uint);
        },
        .bool => {
            return val > 0;
        },
        else => {
            assert_with_reason(false, @src(), "invalid type for quick_unhex(): {s}", .{@typeName(T)});
            unreachable;
        },
    }
}

pub const QuickDecResult = struct {
    data: [20]u8 = @splat(' '),
    start: u8 = 20,

    pub fn bytes(self: *const QuickDecResult) []const u8 {
        return self.data[self.start..20];
    }
};

pub fn quick_dec(val: anytype) QuickDecResult {
    var out = QuickDecResult{};
    var uval: u64 = undefined;
    const T = @TypeOf(val);
    const I = @typeInfo(T);
    const LIMIT = @sizeOf(T);
    assert_with_reason(LIMIT > 0 and LIMIT <= 8, @src(), "can only quick_dec() on types with size > 0 and size <= 8, got type {s} (size = {d})", .{ @typeName(T), LIMIT });
    switch (I) {
        .int, .float, .@"enum", .pointer => {
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @bitCast(val);
            uval = @intCast(uint);
        },
        .comptime_int => {
            uval = val;
        },
        .comptime_float => {
            const flt: f64 = val;
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @bitCast(flt);
            uval = @intCast(uint);
        },
        .bool => {
            uval = @intCast(@intFromBool(val));
        },
        else => {
            assert_with_reason(false, @src(), "invalid type for quick_dec(): {s}", .{@typeName(T)});
        },
    }
    while (out.start > 0 and (uval > 0 or out.start >= 20)) {
        out.start -= 1;
        const b = @as(u8, @intCast(uval % 10));
        uval = uval / 10;
        out.data[out.start] = DEC[b];
    }
    return out;
}

pub fn quick_undec(bytes: []const u8, comptime T: type) T {
    var val: u64 = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const b = bytes[i];
        const v = switch (b) {
            '0'...'9' => b - '0',
            else => 0,
        };
        val *= 10;
        val += v;
        i += 1;
    }
    const I = @typeInfo(T);
    switch (I) {
        .int, .float, .@"enum", .pointer => {
            const uint: @Type(.{ .int = .{ .bits = @bitSizeOf(T), .signedness = .unsigned } }) = @intCast(val);
            return @bitCast(uint);
        },
        .bool => {
            return val > 0;
        },
        else => {
            assert_with_reason(false, @src(), "invalid type for quick_unhex(): {s}", .{@typeName(T)});
            unreachable;
        },
    }
}

pub const SrcFmt = struct {
    src: builtin.SourceLocation,

    pub fn new(src: builtin.SourceLocation) SrcFmt {
        return SrcFmt{ .src = src };
    }

    pub fn format(self: SrcFmt, writer: *Writer) !void {
        _ = try writer.write(self.src.file);
        _ = try writer.write(":");
        try writer.printInt(self.src.line, 10, .lower, .{});
        _ = try writer.write(":");
        try writer.printInt(self.src.column, 10, .lower, .{});
    }
};

pub fn alloc_fail_err(alloc: Allocator, comptime src: builtin.SourceLocation, err: anyerror) []const u8 {
    return fmt.allocPrint(alloc, "{f} -> {s}", .{ SrcFmt.new(src), @errorName(err) }) catch return @errorName(err);
}

pub fn alloc_fail_str(alloc: Allocator, comptime src: builtin.SourceLocation, comptime str: []const u8, args: anytype) []const u8 {
    const fullargs = .{SrcFmt.new(src)} ++ args;
    return fmt.allocPrint(alloc, "{f} -> " ++ str, fullargs) catch return str;
}

/// This function aligns an address forward, with the additional condition that the object
/// memory span cannot cross some *larger* boundary alignment, *UNLESS* the original offset
/// was also already aligned to the larger boundary offset. If the aligned address would cause
/// the object to cross the boundary alignment *AND* it was not already aligned to the boundary
/// alignment, it instead returns an address aligned to the larger boundary alignment.
pub fn align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(offset: usize, len: usize, object_align: usize, boundary_align: usize) usize {
    assert_with_reason(object_align <= boundary_align, @src(), "object_align must be <= boundary_align to use this function, got {d} > {d}", .{ object_align, boundary_align });
    const initial_align = std.mem.alignForward(usize, offset, object_align);
    const initial_delta = initial_align - offset;
    if (initial_delta == 0 or object_align == boundary_align) return initial_align;
    const start_boundary_align = std.mem.alignBackward(usize, initial_align, boundary_align);
    const end_minus_one_boundary_align = std.mem.alignBackward(usize, initial_align + len - 1, boundary_align);
    if (start_boundary_align == end_minus_one_boundary_align) return initial_align;
    return std.mem.alignForward(usize, offset, boundary_align);
}

/// Searches a memory slice for a matching item using the native `==` operator
///
/// returns the index found, else `null` if  not found
pub fn mem_search_implicit(data_ptr: anytype, start: usize, end_exclusive: usize, find_val: anytype) ?usize {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    for (data_ptr[start..end_exclusive], 0..) |item, i| {
        if (item == find_val) return i;
    }
    return null;
}
/// Searches a memory slice for a matching item using an equality function
///
/// returns the index found, else `null` if  not found
pub fn mem_search_with_func(data_ptr: anytype, start: usize, end_exclusive: usize, find_val: anytype, equals: *const fn (a: @typeInfo(@TypeOf(data_ptr)).pointer.child, b: @TypeOf(find_val)) bool) ?usize {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    for (data_ptr[start..end_exclusive], 0..) |item, i| {
        if (equals(item, find_val)) return i;
    }
    return null;
}
/// Searches a memory slice for a matching item using an equality function with userdata
///
/// returns the index found, else `null` if  not found
pub fn mem_search_with_func_and_userdata(data_ptr: anytype, start: usize, end_exclusive: usize, find_val: anytype, userdata: anytype, equals: *const fn (a: @typeInfo(@TypeOf(data_ptr)).pointer.child, b: @TypeOf(find_val), userdata: @TypeOf(userdata)) bool) ?usize {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    for (data_ptr[start..end_exclusive], 0..) |item, i| {
        if (equals(item, find_val, userdata)) return i;
    }
    return null;
}

/// Sorts a portion of a memory region using the provided `greater_than` function
/// and the `insertion sort` algorithm
///
/// Assumes `data_ptr[0..end_exclusive]` is a valid slice (sufficient memory is allocated)
pub fn mem_sort(_data_ptr: anytype, start: usize, end_exclusive: usize, userdata: anytype, greater_than: *const fn (a: @typeInfo(@TypeOf(_data_ptr)).pointer.child, b: @typeInfo(@TypeOf(_data_ptr)).pointer.child, userdata: @TypeOf(userdata)) bool) void {
    const PTR = @TypeOf(_data_ptr);
    assert_with_reason(Types.type_is_pointer_or_slice(PTR), @src(), "type of `data_ptr` must be a pointer or slice, got type {s}", .{@typeName(PTR)});
    const T = @typeInfo(@TypeOf(_data_ptr)).pointer.child;
    var data_ptr = Root.Cast.any_ptr_to_many_item_ptr(_data_ptr);
    var i: usize = start + 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var move_val: T = undefined;
    var test_val: T = undefined;
    while (i < end_exclusive) {
        move_val = data_ptr[i];
        j = i - 1;
        jj = i;
        while (greater_than(test_val, move_val, userdata)) {
            test_val = data_ptr[j];
            data_ptr[jj] = data_ptr[j];
            if (j == start) break;
            jj = j;
            j -= 1;
        }
        data_ptr[jj] = move_val;
        i += 1;
    }
}

/// Sorts a portion of a memory region using the `>` operator
/// and the `insertion sort` algorithm
///
/// Assumes `data_ptr[0..end_exclusive]` is a valid slice (sufficient memory is allocated)
pub fn mem_sort_implicit(data_ptr: anytype, start: usize, end_exclusive: usize) void {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    const T = @typeInfo(@TypeOf(data_ptr)).pointer.child;
    var i: usize = start + 1;
    var j: usize = undefined;
    var jj: usize = undefined;
    var move_val: T = undefined;
    var test_val: T = undefined;
    while (i < end_exclusive) {
        move_val = data_ptr[i];
        j = i - 1;
        jj = i;
        while (test_val > move_val) {
            test_val = data_ptr[j];
            data_ptr[jj] = data_ptr[j];
            if (j == start) break;
            jj = j;
            j -= 1;
        }
        data_ptr[jj] = move_val;
        i += 1;
    }
}

pub fn mem_is_sorted_implicit(data_ptr: anytype, start: usize, end_exclusive: usize) bool {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (data_ptr[i] > data_ptr[ii]) return false;
        i = ii;
        ii += 1;
    }
    return true;
}
pub fn mem_is_sorted_with_func(data_ptr: anytype, start: usize, end_exclusive: usize, greater_than: *const fn (a: @typeInfo(@TypeOf(data_ptr)).pointer.child, b: @typeInfo(@TypeOf(data_ptr)).pointer.child) bool) bool {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (greater_than(data_ptr[i], data_ptr[ii])) return false;
        i = ii;
        ii += 1;
    }
    return true;
}
pub fn mem_is_sorted_with_func_and_userdata(data_ptr: anytype, start: usize, end_exclusive: usize, userdata: anytype, greater_than: *const fn (a: @typeInfo(@TypeOf(data_ptr)).pointer.child, b: @typeInfo(@TypeOf(data_ptr)).pointer.child, userdata: @TypeOf(userdata)) bool) bool {
    const PTR = @TypeOf(data_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    var i = start;
    var ii = start + 1;
    while (ii < end_exclusive) {
        if (greater_than(data_ptr[i], data_ptr[ii], userdata)) return false;
        i = ii;
        ii += 1;
    }
    return true;
}

/// This method moves all items at `data_ptr[start..]` up `n` places,
/// and alters `len_ptr` to reflect the new length
///
/// Assumes `data_ptr[0..(len_ptr.* + n)]` is a valid slice (sufficient memory is allocated)
pub fn mem_insert(data_ptr: anytype, len_ptr: anytype, start: usize, n: usize) void {
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const new_start = start + n;
    const move_len: usize = @as(usize, @intCast(len_ptr.*)) - start;
    @memmove(data_ptr[new_start .. new_start + move_len], data_ptr[start .. start + move_len]);
    len_ptr.* += @intCast(n);
}

/// This method moves all items at `data_ptr[start+n..]` down `n` places,
/// and alters `len_ptr` to reflect the new length
pub fn mem_remove(data_ptr: anytype, len_ptr: anytype, start: usize, n: usize) void {
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const new_start = start + n;
    const move_len: usize = @as(usize, @intCast(len_ptr.*)) - new_start;
    @memmove(data_ptr[start .. start + move_len], data_ptr[new_start .. new_start + move_len]);
    len_ptr.* -= @intCast(n);
}

/// This method deletes all of the indexes from the provided list (sorted low to high)
/// by moving all indexes above the first on in the list and not ALSO included in the list,
/// down.
pub fn mem_remove_sparse_by_indexes_sorted_low_to_high(data_ptr: anytype, len_ptr: anytype, sorted_indexes: []const usize) void {
    if (sorted_indexes.len == 0 or sorted_indexes[0] >= len_ptr.*) return;
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    const PTR_INFO = @typeInfo(PTR).pointer;
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    var read_idx: usize = sorted_indexes[0] + 1;
    var write_idx: usize = sorted_indexes[0];
    var del_idx_idx: usize = 1;
    var del_idx: usize = undefined;
    const slice: []PTR_INFO.child = data_ptr[0..@as(usize, @intCast(len_ptr.*))];
    while (del_idx_idx < sorted_indexes.len) {
        del_idx = sorted_indexes[del_idx_idx];
        while (read_idx < del_idx) {
            slice[write_idx] = slice[read_idx];
            read_idx += 1;
            write_idx += 1;
        }
        read_idx += 1;
        del_idx_idx += 1;
    }
    while (read_idx < slice.len) {
        slice[write_idx] = slice[read_idx];
        read_idx += 1;
        write_idx += 1;
    }
    len_ptr.* -= @intCast(del_idx_idx);
}

/// This method deletes all of the indexes from the provided list (sorted low to high)
/// by moving all indexes above the first on in the list and not ALSO included in the list,
/// down.
pub fn mem_remove_sparse_by_values_in_list_order(comptime T: type, data_ptr: [*]T, len_ptr: anytype, known_start_index: usize, equality_func: *const fn (a: T, b: T) bool, values_in_order: []const T) void {
    if (values_in_order.len == 0) return;
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    var read_idx: usize = known_start_index;
    var write_idx: usize = known_start_index;
    var del_val_idx: usize = 0;
    var del_val: T = values_in_order[0];
    var found_at_least_one: bool = false;
    const slice: []T = data_ptr[0..@as(usize, @intCast(len_ptr.*))];
    while (read_idx < slice.len) {
        const this_val = slice[read_idx];
        if (equality_func(this_val, del_val)) {
            del_val_idx += 1;
            if (del_val_idx < values_in_order.len) {
                del_val = values_in_order[del_val_idx];
            }
            write_idx = read_idx;
            read_idx += 1;
            found_at_least_one = true;
            break;
        } else {
            read_idx += 1;
        }
    }
    while (read_idx < slice.len and del_val_idx < values_in_order.len) {
        const this_val = slice[read_idx];
        if (equality_func(this_val, del_val)) {
            del_val_idx += 1;
            read_idx += 1;
            if (del_val_idx < values_in_order.len) {
                del_val = values_in_order[del_val_idx];
            }
        } else {
            slice[write_idx] = slice[read_idx];
            read_idx += 1;
            write_idx += 1;
        }
    }
    if (!found_at_least_one) return;
    while (read_idx < slice.len) {
        slice[write_idx] = slice[read_idx];
        read_idx += 1;
        write_idx += 1;
    }
    len_ptr.* -= @intCast(del_val_idx);
}

pub const FilterResult = struct {
    is_true: bool = false,
    more_items: bool = true,

    pub fn new(cond: bool, more: bool) FilterResult {
        return FilterResult{
            .is_true = cond,
            .more_items = more,
        };
    }

    pub fn cond_continue(cond: bool) FilterResult {
        return FilterResult{
            .is_true = cond,
            .more_items = true,
        };
    }
    pub fn cond_stop(cond: bool) FilterResult {
        return FilterResult{
            .is_true = cond,
            .more_items = false,
        };
    }
    pub fn true_continue() FilterResult {
        return FilterResult{
            .is_true = true,
            .more_items = true,
        };
    }
    pub fn true_stop() FilterResult {
        return FilterResult{
            .is_true = true,
            .more_items = false,
        };
    }
    pub fn false_continue() FilterResult {
        return FilterResult{
            .is_true = false,
            .more_items = true,
        };
    }
    pub fn false_stop() FilterResult {
        return FilterResult{
            .is_true = false,
            .more_items = false,
        };
    }
};

/// This method deletes all of the indexes from the provided list where
/// the value at that index results in `filter_func(val) == true`
pub fn mem_remove_sparse_by_filter_func(comptime T: type, data_ptr: [*]T, len_ptr: anytype, start_index: usize, userdata: anytype, filter_func: *const fn (val: T, userdata: @TypeOf(userdata)) FilterResult) void {
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    var read_idx: usize = start_index;
    var write_idx: usize = start_index;
    var delete_count: usize = 0;
    var filter_result = FilterResult{};
    const slice: []T = data_ptr[0..@as(usize, @intCast(len_ptr.*))];
    while (read_idx < slice.len and filter_result.more_items) {
        const this_val = slice[read_idx];
        filter_result = filter_func(this_val, userdata);
        if (filter_result.is_true) {
            write_idx = read_idx;
            read_idx += 1;
            delete_count += 1;
            break;
        } else {
            read_idx += 1;
        }
    }
    while (read_idx < slice.len and filter_result.more_items) {
        const this_val = slice[read_idx];
        filter_result = filter_func(this_val, userdata);
        if (filter_result.is_true) {
            read_idx += 1;
            delete_count += 1;
        } else {
            slice[write_idx] = slice[read_idx];
            read_idx += 1;
            write_idx += 1;
        }
    }
    if (delete_count == 0) return;
    while (read_idx < slice.len) {
        slice[write_idx] = slice[read_idx];
        read_idx += 1;
        write_idx += 1;
    }
    len_ptr.* -= @intCast(delete_count);
}

test mem_remove_sparse_by_filter_func {
    const P = struct {
        fn val_is_odd(v: u8, _: @TypeOf(null)) FilterResult {
            return .cond_continue(v % 2 == 1);
        }
        fn val_is_even(v: u8, c: *usize) FilterResult {
            var result: FilterResult = .cond_continue(v % 2 == 0);
            if (result.is_true) c.* -= 1;
            result.more_items = c.* > 0;
            return result;
        }
        fn count_evens(slice: []u8) usize {
            var c: usize = 0;
            for (slice) |v| {
                if (v % 2 == 0) c += 1;
            }
            return c;
        }
        fn count_odds(slice: []u8) usize {
            var c: usize = 0;
            for (slice) |v| {
                if (v % 2 == 1) c += 1;
            }
            return c;
        }
        fn all_vals_even_and_match_count(slice: []u8, count: usize) bool {
            var c: usize = 0;
            for (slice) |v| {
                if (v % 2 == 1) return false;
                c += 1;
            }
            return c == count;
        }
        fn all_vals_odd_and_match_count(slice: []u8, count: usize) bool {
            var c: usize = 0;
            for (slice) |v| {
                if (v % 2 == 0) return false;
                c += 1;
            }
            return c == count;
        }
    };
    var ARR: [128]u8 = undefined;
    var buf: []u8 = ARR[0..];
    var r = std.Random.DefaultPrng.init(@bitCast(std.time.microTimestamp()));
    var rand = r.random();
    var c: usize = undefined;
    const CHECK_COUNT = 16;
    for (0..CHECK_COUNT) |_| {
        buf = ARR[0..];
        rand.bytes(buf);
        c = P.count_evens(buf);
        mem_remove_sparse_by_filter_func(u8, buf.ptr, &buf.len, 0, null, P.val_is_odd);
        try Test.expect_true(P.all_vals_even_and_match_count(buf, c), "P.all_vals_even_and_match_count(buf)", "mem_remove_sparse_by_filter_func(..., val_is_odd) did not remove all odd values or removed some even values", .{});
        buf = ARR[0..];
        rand.bytes(buf);
        c = P.count_odds(buf);
        var cc = ARR.len - c;
        mem_remove_sparse_by_filter_func(u8, buf.ptr, &buf.len, 0, &cc, P.val_is_even);
        try Test.expect_true(P.all_vals_odd_and_match_count(buf, c), "P.all_vals_odd_and_match_count(buf)", "mem_remove_sparse_by_filter_func(..., val_is_even) did not remove all even values or removed some odd values", .{});
    }
}

pub fn mem_realloc(comptime T: type, comptime I: type, ptr: *[*]T, len: I, cap: *I, new_cap: I, alloc: Allocator, comptime RET_BOOL: bool) if (RET_BOOL) bool else void {
    assert_with_reason(Types.type_is_unsigned_int(I), @src(), "type `I` was not an unsigned integer type, got {s}", .{@typeName(I)});
    const old_slice = ptr.*[0..cap.*];
    if (alloc.remap(old_slice, @intCast(new_cap))) |new_mem| {
        ptr.* = new_mem.ptr;
        cap.* = @intCast(new_mem.len);
    } else {
        const new_mem = alloc.alloc(T, @intCast(new_cap)) catch |err| {
            if (RET_BOOL) return false;
            Assert.assert_allocation_failure(@src(), T, new_cap, err);
            unreachable;
        };
        @memcpy(new_mem[0..len], ptr.*[0..len]);
        alloc.free(old_slice);
        ptr.* = new_mem.ptr;
        cap.* = @intCast(new_mem.len);
    }
    if (RET_BOOL) return true;
}

pub const ForEachControl = struct {
    end_exclusive_delta: isize = 0,
    start_delta: isize = 0,
    index_delta: isize = 1,
    keep_going: bool = true,
};

pub fn for_each(comptime T: type, slice: []T, start: usize, end_exclusive: usize, userdata: anytype, action: fn (slice: []T, val: T, idx: usize, userdata: @TypeOf(userdata)) void) void {
    var idx: usize = start;
    while (idx < end_exclusive) {
        action(slice, slice[idx], idx, userdata);
        idx += 1;
    }
}
pub fn for_each_reverse(comptime T: type, slice: []T, start: usize, end_exclusive: usize, userdata: anytype, action: fn (slice: []T, val: T, idx: usize, userdata: @TypeOf(userdata)) void) void {
    var idx: usize = end_exclusive;
    while (idx > start) {
        idx -= 1;
        action(slice, slice[idx], idx, userdata);
    }
}
pub fn for_each_special(comptime T: type, slice: []T, start: usize, end_exclusive: usize, userdata: anytype, action: fn (slice: []T, val: T, idx: usize, userdata: @TypeOf(userdata)) ForEachControl) void {
    var slice_start: usize = start;
    var slice_end: usize = end_exclusive;
    var idx: usize = start;
    var control: ForEachControl = undefined;
    while (control.keep_going and idx < slice_end) {
        control = action(slice, slice[idx], idx, userdata);
        slice_start = @intCast(Types.intcast(slice_start, isize) + control.start_delta);
        slice_end = @intCast(Types.intcast(slice_end, isize) + control.end_exclusive_delta);
        idx = @intCast(Types.intcast(idx, isize) + control.index_delta);
    }
}
pub fn for_each_special_reverse(comptime T: type, slice: []T, start: usize, end_exclusive: usize, userdata: anytype, action: fn (slice: []T, val: T, idx: usize, userdata: @TypeOf(userdata)) ForEachControl) void {
    var slice_start: usize = start;
    var slice_end: usize = end_exclusive;
    var idx: usize = end_exclusive;
    var control: ForEachControl = undefined;
    while (control.keep_going and idx > slice_start) {
        idx = @intCast(Types.intcast(idx, isize) - control.index_delta);
        control = action(slice, slice[idx], idx, userdata);
        slice_start = @intCast(Types.intcast(slice_start, isize) + control.start_delta);
        slice_end = @intCast(Types.intcast(slice_end, isize) + control.end_exclusive_delta);
    }
}

pub fn slices_overlap(comptime T: type, a: []const T, b: []const T) bool {
    const a1 = @intFromPtr(a.ptr);
    const a2 = @intFromPtr(a.ptr + a.len);
    const b1 = @intFromPtr(b.ptr);
    const b2 = @intFromPtr(b.ptr + b.len);
    return a2 > b1 and b2 > a1;
}

pub fn not_error(err_union: anyerror!void) bool {
    if (err_union) |_| {
        return true;
    } else |_| {
        return false;
    }
}
pub fn is_error(err_union: anyerror!void) bool {
    if (err_union) |_| {
        return false;
    } else |_| {
        return true;
    }
}

pub inline fn print_src_location(comptime src_loc: SourceLocation) []const u8 {
    const link = src_loc.file ++ ":" ++ std.fmt.comptimePrint("{d}", .{src_loc.line}) ++ ":" ++ std.fmt.comptimePrint("{d}", .{src_loc.column});
    return link;
}

pub fn replace_key_value_in_buffer(comptime T: type, buf: []T, key_val: T, replace_val: T) void {
    var rem_buf = buf;
    while (rem_buf.len >= 8) {
        if (rem_buf[0] == key_val) rem_buf[0] = replace_val;
        if (rem_buf[1] == key_val) rem_buf[1] = replace_val;
        if (rem_buf[2] == key_val) rem_buf[2] = replace_val;
        if (rem_buf[3] == key_val) rem_buf[3] = replace_val;
        if (rem_buf[4] == key_val) rem_buf[4] = replace_val;
        if (rem_buf[5] == key_val) rem_buf[5] = replace_val;
        if (rem_buf[6] == key_val) rem_buf[6] = replace_val;
        if (rem_buf[7] == key_val) rem_buf[7] = replace_val;
        rem_buf = rem_buf[8..];
    }
    var i: usize = 0;
    while (i < rem_buf.len) {
        if (rem_buf[i] == key_val) rem_buf[i] = replace_val;
        i += 1;
    }
}

pub fn equals_implicit(a: anytype, b: @TypeOf(a)) bool {
    const T = @TypeOf(a);
    switch (Types.type_equals_mode(T)) {
        .native => {
            return a == b;
        },
        .method => {
            return a.equals(b);
        },
        .slice => {
            const C = Types.child_type(T);
            return std.mem.eql(C, a[0..], b[0..]);
        },
        .none => {
            Assert.assert_unreachable(@src(), "type `{s}` does not have an implicit equality mode", .{@typeName(T)});
        },
    }
}

pub fn scalar_ptr_as_single_item_slice(ptr: anytype) []@typeInfo(@TypeOf(ptr)).pointer.child {
    const P = @TypeOf(ptr);
    assert_with_reason(Types.type_is_single_item_pointer(P), @src(), "input `ptr` must be a pointer type, got type `{s}`", .{@typeName(P)});
    const T = @typeInfo(P).pointer.child;
    return @as([*]T, @ptrCast(@alignCast(ptr)))[0..1];
}
pub fn scalar_ptr_as_byte_slice(ptr: anytype) []u8 {
    return std.mem.sliceAsBytes(scalar_ptr_as_single_item_slice(ptr));
}

pub fn real_int_type(comptime T: type) type {
    const I = @typeInfo(T);
    switch (I) {
        .int => |info| {
            comptime var bits = info.bits;
            const sign = info.signedness;
            bits -= 1;
            bits |= bits >> 1;
            bits |= bits >> 2;
            bits |= bits >> 4;
            bits |= bits >> 8;
            bits += 1;
            return std.meta.Int(sign, bits);
        },
        .comptime_int => return u64,
        else => assert_unreachable(@src(), "type `{s}` cannot be converted to a real int type", .{@typeName(T)}),
    }
}
pub fn real_float_type(comptime T: type) type {
    const I = @typeInfo(T);
    switch (I) {
        .float => return T,
        .comptime_float => return f64,
        else => assert_unreachable(@src(), "type `{s}` cannot be converted to a real float type", .{@typeName(T)}),
    }
}
pub fn real_type(comptime T: type) type {
    const I = @typeInfo(T);
    switch (I) {
        .float => return T,
        .comptime_float => return f64,
        .int => |info| {
            comptime var bits = info.bits;
            const sign = info.signedness;
            bits -= 1;
            bits |= bits >> 1;
            bits |= bits >> 2;
            bits |= bits >> 4;
            bits |= bits >> 8;
            bits += 1;
            return std.meta.Int(sign, bits);
        },
        .comptime_int => return u64,
        else => assert_unreachable(@src(), "type `{s}` cannot be converted to a real float type", .{@typeName(T)}),
    }
}

pub fn print_len_of_uint(val: anytype) usize {
    const V = @TypeOf(val);
    const VV = real_int_type(V);
    switch (VV) {
        u8 => {
            return switch (val) {
                0...9 => 1,
                10...99 => 2,
                100...255 => 3,
                1000...9999 => 4,
                10000...99999 => 5,
            };
        },
        u16 => {
            return switch (val) {
                0...9 => 1,
                10...99 => 2,
                100...999 => 3,
                1000...9999 => 4,
                10000...65535 => 5,
            };
        },
        u32 => {
            return switch (val) {
                0...9 => 1,
                10...99 => 2,
                100...999 => 3,
                1000...9999 => 4,
                10000...99999 => 5,
                100000...999999 => 6,
                1000000...9999999 => 7,
                10000000...99999999 => 8,
                100000000...999999999 => 9,
                1000000000...4294967295 => 10,
            };
        },
        u64 => {
            return switch (val) {
                0...9 => 1,
                10...99 => 2,
                100...999 => 3,
                1000...9999 => 4,
                10000...99999 => 5,
                100000...999999 => 6,
                1000000...9999999 => 7,
                10000000...99999999 => 8,
                100000000...999999999 => 9,
                1000000000...9999999999 => 10,
                10000000000...99999999999 => 11,
                100000000000...999999999999 => 12,
                1000000000000...9999999999999 => 13,
                10000000000000...99999999999999 => 14,
                100000000000000...999999999999999 => 15,
                1000000000000000...9999999999999999 => 16,
                10000000000000000...99999999999999999 => 17,
                100000000000000000...999999999999999999 => 18,
                1000000000000000000...9999999999999999999 => 19,
                10000000000000000000...18446744073709551615 => 20,
            };
        },
        else => assert_unreachable(@src(), "type `{s}` is not supported for `print_len_of_uint()`", .{@typeName(V)}),
    }
}

pub fn local_type_name(comptime T: type) []const u8 {
    comptime {
        const FULL = @typeName(T);
        var idx = FULL.len;
        while (idx > 0) {
            idx -= 1;
            if (FULL[idx] == '.') {
                return FULL[idx + 1 .. FULL.len];
            }
        }
        return FULL;
    }
}

pub inline fn update_max(val: anytype, current_max: *@TypeOf(val)) void {
    if (val > current_max.*) {
        current_max = val;
    }
}
pub inline fn update_min(val: anytype, current_min: *@TypeOf(val)) void {
    if (val < current_min.*) {
        current_min = val;
    }
}

pub fn first_n_bits_set(comptime T: type, n: std.math.Log2IntCeil(T)) T {
    if (n == 0) return 0;
    var left: std.math.Log2IntCeil(T) = n - 1;
    var out: T = 1;
    var step: std.math.Log2Int(T) = 1;
    while (left >= step) {
        out |= out << step;
        left -= step;
        step <<= 1;
    }
    if (left > 0) {
        out |= out << @intCast(left);
    }
    return out;
}
pub fn first_n_bits_set_inline(comptime T: type, comptime n: std.math.Log2IntCeil(T)) T {
    if (n == 0) return 0;
    comptime var left: std.math.Log2IntCeil(T) = n - 1;
    comptime var out: T = 1;
    comptime var step: std.math.Log2Int(T) = 1;
    comptime while (left >= step) {
        out |= out << step;
        left -= step;
        step <<= 1;
    };
    if (left > 0) {
        out |= out << @intCast(left);
    }
    return out;
}

test "first_n_bits_set" {
    try Test.expect_equal(first_n_bits_set(u64, 0), "first_n_bits_set(u64, 0)", 0, "0", "fail", .{});
    try Test.expect_equal(first_n_bits_set(u64, 1), "first_n_bits_set(u64, 1)", 1, "1", "fail", .{});
    try Test.expect_equal(first_n_bits_set(u64, 4), "first_n_bits_set(u64, 4)", 15, "15", "fail", .{});
    try Test.expect_equal(first_n_bits_set(u64, 5), "first_n_bits_set(u64, 5)", 31, "31", "fail", .{});
    try Test.expect_equal(first_n_bits_set(u64, 11), "first_n_bits_set(u64, 1)", 2047, "2047", "fail", .{});
    try Test.expect_equal(comptime first_n_bits_set_inline(u64, 0), "first_n_bits_set_inline(u64, 0)", 0, "0", "fail", .{});
    try Test.expect_equal(comptime first_n_bits_set_inline(u64, 1), "first_n_bits_set_inline(u64, 1)", 1, "1", "fail", .{});
    try Test.expect_equal(comptime first_n_bits_set_inline(u64, 4), "first_n_bits_set_inline(u64, 4)", 15, "15", "fail", .{});
    try Test.expect_equal(comptime first_n_bits_set_inline(u64, 5), "first_n_bits_set_inline(u64, 5)", 31, "31", "fail", .{});
    try Test.expect_equal(comptime first_n_bits_set_inline(u64, 11), "first_n_bits_set_inline(u64, 1)", 2047, "2047", "fail", .{});
}

pub fn invalid_ptr(comptime T: type) *T {
    const addr = std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T));
    return @ptrFromInt(addr);
}
pub fn invalid_ptr_const(comptime T: type) *const T {
    const addr = std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T));
    return @ptrFromInt(addr);
}
pub fn invalid_ptr_many(comptime T: type) [*]T {
    const addr = std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T));
    return @ptrFromInt(addr);
}
pub fn invalid_ptr_many_const(comptime T: type) [*]const T {
    const addr = std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T));
    return @ptrFromInt(addr);
}
pub fn invalid_slice(comptime T: type) []T {
    return invalid_ptr_many(T)[0..0];
}
pub fn invalid_slice_const(comptime T: type) []const T {
    return invalid_ptr_many(T)[0..0];
}

pub fn comptime_debug_print(comptime _fmt: []const u8, args: anytype) void {
    std.debug.print("{s}", .{std.fmt.comptimePrint(_fmt, args)});
}
