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

const Root = @import("./_root.zig");
const Types = Root.Types;
const Math = Root.Math;

pub const Order = enum(i8) {
    A_LESS_THAN_B = -1,
    A_EQUAL_B = 0,
    A_GREATER_THAN_B = 1,
};

pub inline fn less_than(a: anytype, b: anytype) bool {
    return Math.upgrade_less_than(a, b);
}

pub inline fn greater_than(a: anytype, b: anytype) bool {
    return Math.upgrade_greater_than(a, b);
}

pub inline fn less_than_or_equal(a: anytype, b: anytype) bool {
    return Math.upgrade_less_than_or_equal(a, b);
}

pub inline fn greater_than_or_equal(a: anytype, b: anytype) bool {
    return Math.upgrade_greater_than_or_equal(a, b);
}

pub inline fn equal(a: anytype, b: anytype) bool {
    return Math.upgrade_equal_to(a, b);
}

pub inline fn not_equal(a: anytype, b: anytype) bool {
    return !Math.upgrade_equal_to(a, b);
}

pub fn order(a: anytype, b: anytype) Order {
    if (less_than(a, b)) {
        return .A_LESS_THAN_B;
    } else if (greater_than(a, b)) {
        return .A_GREATER_THAN_B;
    } else return .A_EQUAL_B;
}

pub inline fn less_than_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_less_than(aa, bb);
}

pub inline fn greater_than_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_greater_than(aa, bb);
}

pub inline fn less_than_or_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_less_than_or_equal(aa, bb);
}

pub inline fn greater_than_or_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_greater_than_or_equal(aa, bb);
}

pub inline fn equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return Math.upgrade_equal_to(aa, bb);
}

pub inline fn not_equal_follow_pointers(a: anytype, b: anytype) bool {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    return !Math.upgrade_equal_to(aa, bb);
}

pub fn order_follow_pointers(a: anytype, b: anytype) Order {
    const aa = Types.unrwap_all_pointers(a);
    const bb = Types.unrwap_all_pointers(b);
    if (less_than(aa, bb)) {
        return .A_LESS_THAN_B;
    } else if (greater_than(aa, bb)) {
        return .A_GREATER_THAN_B;
    } else return .A_EQUAL_B;
}
