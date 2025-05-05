const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

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

pub fn c_strings_equal(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (true) : (i += 1) {
        if (a[i] != b[i]) return false;
        if (a[i] == '0') return true;
    }
}
