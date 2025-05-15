const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("root");
const BinarySearch = Root.Algorithms.BinarySearch;

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

pub fn is_valid_value_for_enum(comptime ENUM_TYPE: type, int_value: anytype) bool {
    const enum_info = @typeInfo(ENUM_TYPE).@"enum";
    if (!enum_info.is_exhaustive) {
        if (std.math.cast(enum_info.tag_type, int_value) == null) return false;
        return true;
    }

    const ordered_values = comptime make: {
        var arr: [enum_info.fields.len]enum_info.tag_type = undefined;
        var len: usize = 0;
        while (len < enum_info.fields.len) : (len += 1) {
            const ins_idx = BinarySearch.simple_binary_search_insert_index(enum_info.tag_type, false, arr[0..len], enum_info.fields[len].value);
            mem.copyBackwards(enum_info.tag_type, arr[ins_idx + 1 .. len + 1], arr[ins_idx..len]);
            arr[ins_idx] = enum_info.fields[len].value;
        }
        break :make arr;
    };

    if (BinarySearch.simple_binary_search(enum_info.tag_type, ordered_values[0..], int_value) == null) return false;
    return true;
}

pub fn make_slice_from_sentinel_ptr(comptime T: type, comptime S: T, ptr: [*:S]T) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_const_slice_from_sentinel_ptr(comptime T: type, comptime S: T, ptr: [*:S]const T) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_slice_from_sentinel_ptr_max_len(comptime T: type, comptime S: T, ptr: [*:S]T, max_len: usize) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S and i < max_len) : (i += 1) {}
    return ptr[0..i :S];
}

pub fn make_const_slice_from_sentinel_ptr_max_len(comptime T: type, comptime S: T, ptr: [*:S]const T, max_len: usize) [:S]T {
    var i: usize = 0;
    while (ptr[i] != S and i < max_len) : (i += 1) {}
    return ptr[0..i :S];
}

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

pub inline fn assert_with_reason(condition: bool, reason_fmt: []const u8, reason_args: anytype) void {
    if (build.mode == .Debug) {
        if (!condition) {
            std.debug.panic(reason_fmt, reason_args);
            unreachable;
        }
    } else {
        assert(condition);
    }
}
pub inline fn compile_assert_with_reason(condition: bool, reason: []const u8) void {
    if (build.mode == .Debug) {
        if (!condition) {
            @compileError(reason);
        }
    } else {
        assert(condition);
    }
}

pub fn ptr_with_sentinel_has_min_len(comptime T: type, comptime S: T, ptr: [*:S]const T, len: usize) bool {
    var i: usize = 0;
    while (ptr[i] != S) : (i += 1) {
        if (i >= len) return true;
    }
    return false;
}

pub inline fn type_is_vector_or_array_with_child_type(comptime T: type, comptime CHILD: type) bool {
    const INFO = @typeInfo(T);
    if (INFO == .array and INFO.array.child == CHILD) return true;
    if (INFO == .vector and INFO.vector.child == CHILD) return true;
    return false;
}

pub inline fn type_is_pointer_with_child_type(comptime T: type, comptime CHILD: type) bool {
    const INFO = @typeInfo(T);
    return INFO == .pointer and INFO.pointer.child == CHILD;
}

pub inline fn pointer_field_child_type(comptime T: type, comptime field: []const u8) type {
    return @typeInfo(@FieldType(T, field)).pointer.child;
}
pub inline fn pointer_child_type(comptime T: type) type {
    return @typeInfo(T).pointer.child;
}
pub inline fn pointer_type_has_sentinel(comptime T: type) bool {
    return @typeInfo(T).pointer.sentinel_ptr != null;
}
pub inline fn pointer_type_sentinel(comptime T: type) *const @typeInfo(T).pointer.child {
    return @ptrCast(@alignCast(@typeInfo(T).pointer.sentinel_ptr.?));
}
pub inline fn pointer_is_c_pointer(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .c;
}
pub inline fn pointer_might_be_zero(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .c or @typeInfo(T).pointer.is_allowzero;
}
pub inline fn pointer_is_zero(ptr: anytype) bool {
    return @intFromPtr(ptr) == 0;
}
pub inline fn type_has_field_with_type(comptime T: type, comptime field: []const u8, comptime T_FIELD: type) bool {
    return @hasField(T, field) and @FieldType(T, field) == T_FIELD;
}
pub inline fn type_has_field_with_any_pointer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .pointer;
}
pub inline fn type_has_field_with_any_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int;
}
pub inline fn type_has_field_with_any_unsigned_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int and @typeInfo(@FieldType(T, field)).int.signedness == .unsigned;
}
pub inline fn type_has_field_with_any_signed_integer_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .int and @typeInfo(@FieldType(T, field)).int.signedness == .signed;
}
pub inline fn type_has_field_with_any_float_type(comptime T: type, comptime field: []const u8) bool {
    return @hasField(T, field) and @typeInfo(@FieldType(T, field)) == .float;
}

pub inline fn type_has_decl_with_type(comptime T: type, comptime decl: []const u8, comptime T_DECL: type) bool {
    return @hasDecl(T, decl) and @TypeOf(@field(T, decl)) == T_DECL;
}
pub inline fn type_has_decl_with_any_pointer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .pointer;
}
pub inline fn type_has_decl_with_any_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int;
}
pub inline fn type_has_decl_with_any_signed_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int and @typeInfo(@TypeOf(@field(T, decl))).int.signedness == .signed;
}
pub inline fn type_has_decl_with_any_unsigned_integer_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .int and @typeInfo(@TypeOf(@field(T, decl))).int.signedness == .unsigned;
}
pub inline fn type_has_decl_with_any_float_type(comptime T: type, comptime decl: []const u8) bool {
    return @hasDecl(T, decl) and @typeInfo(@TypeOf(@field(T, decl))) == .float;
}

pub inline fn type_is_pointer_or_slice(comptime T: type) bool {
    return @typeInfo(T) == .pointer;
}
pub inline fn pointer_is_slice(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .slice;
}
pub inline fn pointer_is_single(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .one;
}
pub inline fn pointer_is_many(comptime T: type) bool {
    return @typeInfo(T).pointer.size == .many;
}
pub inline fn type_is_array_or_vector(comptime T: type) bool {
    return @typeInfo(T) == .array or @typeInfo(T) == .vector;
}
pub inline fn array_or_vector_child_type(comptime T: type) type {
    if (@typeInfo(T) == .array) return @typeInfo(T).array.child;
    return @typeInfo(T).vector.child;
}
pub inline fn pointer_is_mutable(comptime T: type) bool {
    return @typeInfo(T).pointer.is_const == false;
}
pub inline fn pointer_is_immutable(comptime T: type) bool {
    return @typeInfo(T).pointer.is_const == true;
}

pub fn type_is_optional(comptime T: type) bool {
    return @typeInfo(T) == .optional;
}
pub fn optional_type_child(comptime T: type) type {
    return @typeInfo(T).optional.child;
}
pub fn memcopy(from_src: anytype, to_dst: anytype, count: usize) void {
    if (count == 0) return;
    if (type_is_optional(@TypeOf(from_src)) and from_src == null) std.debug.panic("memcopy `from_src` optional type {s} is `null`, but `count` != 0", .{@typeName(@TypeOf(from_src))});
    if (type_is_optional(@TypeOf(to_dst)) and to_dst == null) std.debug.panic("memcopy `to_dst` optional type {s} is `null`, but `count` != 0", .{@typeName(@TypeOf(to_dst))});
    const FROM = if (type_is_optional(@TypeOf(from_src))) optional_type_child(from_src) else @TypeOf(from_src);
    const TO = if (type_is_optional(@TypeOf(to_dst))) optional_type_child(to_dst) else @TypeOf(to_dst);
    const from_src_not_null = if (type_is_optional(@TypeOf(from_src))) from_src.? else from_src;
    const to_dst_not_null = if (type_is_optional(@TypeOf(to_dst))) to_dst.? else to_dst;
    var raw_from: [*]const u8 = undefined;
    var raw_to: [*]u8 = undefined;
    comptime var copy_type: type = undefined;
    if (type_is_array_or_vector(FROM)) {
        assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
        copy_type = array_or_vector_child_type(FROM);
        raw_from = @ptrCast(@alignCast(from_src_not_null[0..count].ptr));
    } else if (type_is_pointer_or_slice(FROM)) {
        const ptr_type = FROM;
        const child_type = pointer_child_type(ptr_type);
        if (pointer_is_slice(ptr_type)) {
            assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
            copy_type = child_type;
            raw_from = @ptrCast(@alignCast(from_src_not_null.ptr));
        } else if (pointer_is_single(ptr_type)) {
            if (type_is_array_or_vector(child_type)) {
                assert_with_reason(from_src_not_null.len >= count, "memcopy `from_src` ({s}) cannot provide {d} items (has {d} items)", .{ @typeName(FROM), count, from_src_not_null.len });
                copy_type = array_or_vector_child_type(FROM);
                raw_from = @ptrCast(@alignCast(from_src_not_null));
            } else {
                assert_with_reason(count == 1, "memcopy `from_src` ({s}) cannot provide {d} items (has 1 item, single item pointer to non-array/vector)", .{ @typeName(FROM), count });
                copy_type = child_type;
                raw_from = @ptrCast(@alignCast(from_src_not_null));
            }
        } else if (pointer_is_many(ptr_type)) {
            if (pointer_type_has_sentinel(ptr_type) and (build.mode == .Debug or build.mode == .ReleaseSafe)) {
                const sentinel = pointer_type_sentinel(ptr_type);
                const len_check_slice = make_const_slice_from_sentinel_ptr_max_len(child_type, sentinel.*, from_src_not_null, count);
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
    if (type_is_pointer_or_slice(TO) and pointer_is_mutable(TO)) {
        const ptr_type = TO;
        const child_type = pointer_child_type(ptr_type);
        if (pointer_is_slice(ptr_type)) {
            assert_with_reason(to_dst_not_null.len >= count, "memcopy `to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
            compile_assert_with_reason(child_type == copy_type, "memcopy `to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
            raw_to = @ptrCast(@alignCast(to_dst_not_null.ptr));
        } else if (pointer_is_single(ptr_type)) {
            if (type_is_array_or_vector(child_type)) {
                assert_with_reason(to_dst_not_null.len >= count, "memcopy `to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
                compile_assert_with_reason(array_or_vector_child_type(child_type) == copy_type, "memcopy `to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
                raw_to = @ptrCast(@alignCast(to_dst_not_null));
            } else {
                assert_with_reason(count == 1, "memcopy `to_dst` ({s}) cannot recieve {d} items (has 1 item capacity, single item pointer to non-array/vector)", .{ @typeName(TO), count });
                compile_assert_with_reason(child_type == copy_type, "memcopy `to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
                raw_to = @ptrCast(@alignCast(to_dst_not_null));
            }
        } else if (pointer_is_many(ptr_type)) {
            if (pointer_type_has_sentinel(ptr_type) and (build.mode == .Debug or build.mode == .ReleaseSafe)) {
                const sentinel = pointer_type_sentinel(ptr_type);
                const len_check_slice = make_const_slice_from_sentinel_ptr_max_len(child_type, sentinel.*, to_dst_not_null, count);
                assert_with_reason(len_check_slice.len >= count, "memcopy `to_dst` ({s}) cannot recieve {d} items (has {d} capacity)", .{ @typeName(TO), count, to_dst_not_null.len });
            }
            compile_assert_with_reason(child_type == copy_type, "memcopy `to_dst` (" ++ @typeName(TO) ++ ") does not have a matching child type for `from_src` (" ++ @typeName(FROM) ++ ")");
            raw_to = @ptrCast(@alignCast(to_dst_not_null));
        }
    } else @compileError("memcopy `to_dst` must be a mutable pointer type");
    @memcpy(raw_to[0..raw_count], raw_from[0..raw_count]);
}
