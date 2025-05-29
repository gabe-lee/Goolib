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
const Type = std.builtin.Type;
const meta = std.meta;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const comptime_assert_with_reason = Utils.comptime_assert_with_reason;

pub fn EnumMap(comptime T: type, comptime Enum: type, comptime MAPPING: []const MapPair(T, Enum)) type {
    const EI = @typeInfo(Enum);
    comptime_assert_with_reason(EI == .@"enum", @src(), "parameter `ENUM` must be an enum type");
    const E_INFO = EI.@"enum";
    comptime_assert_with_reason(@typeInfo(E_INFO.tag_type).int.signedness == .unsigned, @src(), "parameter `ENUM` tag type must be an unsigned integer type");
    comptime_assert_with_reason(E_INFO.fields.len == MAPPING.len, @src(), "`MAPPING.len` must equal the number of tags in `ENUM`");
    comptime_assert_with_reason(Utils.all_enum_values_start_from_zero_with_no_gaps(Enum), @src(), "tags in `ENUM` must cover all values from 0 to the largest tag value with no gaps");
    const M = create: {
        var m: [E_INFO.fields.len]T = undefined;
        var count: [E_INFO.fields.len]usize = undefined;
        for (MAPPING) |map_pair| {
            m[@intCast(@intFromEnum(map_pair.tag))] = map_pair.val;
            count[@intCast(@intFromEnum(map_pair.tag))] += 1;
        }
        for (count) |cnt| {
            comptime_assert_with_reason(cnt == 1, @src(), "Every mapping pair in `MAPPING` must connect every tag in `ENUM` to exactly one value");
        }
        break :create m;
    };
    return extern struct {
        pub const MAP = M;

        pub inline fn val(tag: Enum) T {
            return MAP[@intCast(@intFromEnum(tag))];
        }
    };
}

pub fn AdHocEnumMap(comptime T: type, comptime MAPPING: []const AdHocMapPair(T)) type {
    const AD_MAP = comptime create: {
        var vals: [MAPPING.len]T = undefined;
        var e_fields: [MAPPING.len]Type.EnumField = undefined;
        var i: comptime_int = 0;
        while (i < MAPPING.len) : (i += 1) {
            vals[i] = MAPPING[i].val;
            const str = MAPPING[i].tag;
            var j: usize = 0;
            while (j < i) : (j += 1) {
                comptime_assert_with_reason(!std.mem.eql(u8, e_fields[j].name, str), @src(), "duplicate tag names are not allowed");
            }
            e_fields[i] = Type.EnumField{ .name = str, .value = i };
        }
        break :create AdHocMapComponents(T, MAPPING.len){
            .e_fields = e_fields,
            .vals = vals,
        };
    };
    const tag_type = math.IntFittingRange(0, MAPPING.len - 1);
    const E_TYPE = Type{ .@"enum" = Type.Enum{
        .is_exhaustive = true,
        .tag_type = tag_type,
        .decls = &.{},
        .fields = &AD_MAP.e_fields,
    } };
    return extern struct {
        pub const MAP = AD_MAP.vals;
        pub const Enum = @Type(E_TYPE);

        pub inline fn val(tag: Enum) T {
            return MAP[@intCast(@intFromEnum(tag))];
        }
    };
}

pub fn MapPair(comptime T: type, comptime ENUM: type) type {
    return struct {
        tag: ENUM,
        val: T,
    };
}

pub fn AdHocMapPair(comptime T: type) type {
    return struct {
        tag: [:0]const u8,
        val: T,
    };
}
fn AdHocMapComponents(comptime T: type, comptime LEN: usize) type {
    return struct {
        e_fields: [LEN]Type.EnumField,
        vals: [LEN]T,
    };
}
