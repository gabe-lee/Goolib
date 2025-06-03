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
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const ANSI = Root.ANSI;
const BinarySearch = Root.BinarySearch;
const Assert = Root.Assert;
const Types = Root.Types;
const assert_with_reason = Assert.assert_with_reason;

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
    @memset(slice, 0);
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
