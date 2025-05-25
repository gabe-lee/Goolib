//! //TODO Documentation
//! #### License: Zlib

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

const Root = @import("root");

pub const OptionalTag = enum(u8) {
    none = 0,
    val = 1,
};

pub fn Optional(comptime TYPE: type) type {
    return union(OptionalTag) {
        none: void,
        val: TYPE,

        const Self = @This();
        pub const T_VAL = TYPE;

        pub inline fn new_none() Self {
            return Self{ .none = void{} };
        }
        pub inline fn new_val(val: TYPE) Self {
            return Self{ .val = val };
        }
        pub inline fn is_none(self: *const Self) bool {
            return self == .none;
        }
        pub inline fn is_val(self: *const Self) bool {
            return self == .val;
        }
        pub inline fn same_none_diff_val_type(self: *const Self, comptime new_val_type: type) Self(new_val_type) {
            return Self(new_val_type){ .none = self.none };
        }
    };
}

const ResultTag = enum(u8) {
    err = 0,
    val = 1,
};

pub fn Result(comptime VAL_TYPE: type, comptime ERR_TYPE: type) type {
    return union(ResultTag) {
        err: ERR_TYPE,
        val: VAL_TYPE,

        const Self = @This();
        pub const T_ERR = ERR_TYPE;
        pub const T_VAL = VAL_TYPE;

        pub inline fn new_err(err: ERR_TYPE) Self {
            return Self{ .err = err };
        }
        pub inline fn new_val(val: VAL_TYPE) Self {
            return Self{ .val = val };
        }
        pub inline fn is_err(self: *const Self) bool {
            return self == .err;
        }
        pub inline fn is_val(self: *const Self) bool {
            return self == .val;
        }
        pub inline fn same_err_diff_val_type(self: *const Self, comptime new_val_type: type) Self(ERR_TYPE, new_val_type) {
            return Self(ERR_TYPE, new_val_type){ .err = self.err };
        }
    };
}

pub const SuccessTag = enum(u8) {
    err = 0,
    ok = 1,
};

pub fn Success(comptime ERR_TYPE: type) type {
    return union(SuccessTag) {
        err: ERR_TYPE,
        ok: void,

        const Self = @This();
        pub const T_ERR = ERR_TYPE;

        pub inline fn new_err(err: ERR_TYPE) Self {
            return Self{ .failure = err };
        }
        pub inline fn new_ok() Self {
            return Self{ .ok = void{} };
        }
        pub inline fn is_err(self: *const Self) bool {
            return self == .err;
        }
        pub inline fn is_ok(self: *const Self) bool {
            return self == .ok;
        }
    };
}
