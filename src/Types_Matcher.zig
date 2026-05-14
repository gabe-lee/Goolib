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
const math = std.math;
const assert = std.debug.assert;
const build = @import("builtin");

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const Utils = Root.Utils;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_in_comptime = Assert.assert_in_comptime;

const DEBUG = std.debug.print;

pub const Type = std.builtin.Type;
pub const TypeId = std.builtin.TypeId;

pub const Kind = Root.Types.Kind;
pub const KindInfo = Root.Types.KindInfo;

const MatchMode = enum(u8) {
    NONE,
    IS,
    IS_ANY_OF,
    NOT,
    IS_NONE_OF,
};

const MatchModeNotNone = enum(u8) {
    IS,
    IS_ANY_OF,
    NOT,
    IS_NONE_OF,
};

const MatchFieldMode = enum(u8) {
    NONE,
    HAS_ALL_OF,
    HAS_ANY_OF,
    HAS_NONE_OF,
    IS_EXACTLY,
};

const Ctx = enum(u8) {
    is_exact_type,
    is_kind,
    TYPE,
    VOID,
    BOOL,
    NO_RETURN,
    INT,
    FLOAT,
    POINTER,
    ARRAY,
    STRUCT,
    COMPTIME_FLOAT,
    COMPTIME_INT,
    UNDEFINED,
    NULL,
    OPTIONAL,
    ERROR_UNION,
    ERROR_SET,
    ENUM,
    UNION,
    FUNCTION,
    OPAQUE,
    FRAME,
    ANYFRAME,
    VECTOR,
    ENUM_LITERAL,
};

const MatchResult = struct {
    state: u2 = 0,

    pub const INIT: u2 = 0b00;
    pub const PASS: u2 = 0b10;
    pub const FAIL: u2 = 0b01;
    pub const PASS_FAIL: u2 = 0b11;

    pub fn new(state: u2) MatchResult {
        return MatchResult{ .state = state };
    }

    pub fn uninit() MatchResult {
        return .new(INIT);
    }

    pub fn is_failing(comptime self: MatchResult) bool {
        return (self.state & FAIL) == FAIL;
    }
    pub fn has_any_pass(comptime self: MatchResult) bool {
        return (self.state & PASS) == PASS;
    }
    pub fn is_passing(comptime self: MatchResult) bool {
        return self.state == PASS;
    }

    pub fn combine(comptime self: MatchResult, comptime other: MatchResult) MatchResult {
        var new_self = self;
        new_self.state |= other.state;
        return new_self;
    }

    pub fn combine_passed(comptime self: MatchResult) MatchResult {
        return self.combine(.new(PASS));
    }
    pub fn combine_failed(comptime self: MatchResult) MatchResult {
        return self.combine(.new(FAIL));
    }

    pub fn and_must_be_false(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (!cond) return self.combine_passed();
        return self.combine_failed();
    }
    pub fn and_must_be_true(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (cond) return self.combine_passed();
        return self.combine_failed();
    }
    pub fn and_pass_if_true(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (cond) return self.combine_passed();
        return self;
    }
    pub fn and_pass_if_false(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (!cond) return self.combine_passed();
        return self;
    }
    pub fn and_fail_if_true(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (cond) return self.combine_failed();
        return self;
    }
    pub fn and_fail_if_false(comptime self: MatchResult, comptime cond: bool) MatchResult {
        if (!cond) return self.combine_failed();
        return self;
    }

    pub fn final_match(comptime self: MatchResult) bool {
        return self.state == PASS;
    }
};

pub fn MinMax(comptime T: type) type {
    return struct {
        min: T,
        max: T,
    };
}

pub const OpaqueVal = struct {
    ptr: *const anyopaque,
    byte_len: usize,

    pub fn match(comptime self: OpaqueVal, comptime ptr: *const anyopaque) bool {
        const self_bytes: [*]const u8 = @ptrCast(self.ptr);
        const ptr_bytes: [*]const u8 = @ptrCast(ptr);
        return std.mem.eql(u8, self_bytes[0..self.byte_len], ptr_bytes[0..self.byte_len]);
    }
};

pub fn ValCondition(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        NONE: void,
        NOT_EQUAL: T,
        EQUAL: T,
        LESS_THAN: T,
        LESS_THAN_OR_EQUAL: T,
        GREATER_THAN: T,
        GREATER_THAN_OR_EQUAL: T,
        BETWEEN_INCLUDE_BOTH: MinMax(T),
        BEWTEEN_EXCLUDE_MAX: MinMax(T),
        BEWTEEN_EXCLUDE_MIN: MinMax(T),
        BEWTEEN_EXCLUDE_BOTH: MinMax(T),
        CUSTOM: *const fn (val: T) bool,
        EQUALS_STRING: []const u8,
        EQUALS_OPAQUE_PTR: OpaqueVal,
        EQUALS_STRING_OPAQUE_PTR: []const u8,

        pub fn no_cond() Self {
            return Self{ .NONE = void{} };
        }
        pub fn equals(val: T) Self {
            return Self{ .EQUAL = val };
        }
        pub fn not_equal(val: T) Self {
            return Self{ .NOT_EQUAL = val };
        }
        pub fn less_than(val: T) Self {
            return Self{ .LESS_THAN = val };
        }
        pub fn less_than_or_equal(val: T) Self {
            return Self{ .LESS_THAN_OR_EQUAL = val };
        }
        pub fn greater_than(val: T) Self {
            return Self{ .GREATER_THAN = val };
        }
        pub fn greater_than_or_equal(val: T) Self {
            return Self{ .GREATER_THAN_OR_EQUAL = val };
        }
        pub fn bewteen_include_min_and_max(min: T, max: T) Self {
            return Self{ .BETWEEN_INCLUDE_BOTH = .{ .min = min, .max = max } };
        }
        pub fn bewteen_include_min_exclude_max(min: T, max: T) Self {
            return Self{ .BEWTEEN_EXCLUDE_MAX = .{ .min = min, .max = max } };
        }
        pub fn bewteen_exclude_min_include_max(min: T, max: T) Self {
            return Self{ .BEWTEEN_EXCLUDE_MIN = .{ .min = min, .max = max } };
        }
        pub fn bewteen_exclude_min_and_max(min: T, max: T) Self {
            return Self{ .BEWTEEN_EXCLUDE_BOTH = .{ .min = min, .max = max } };
        }
        pub fn has_custom_condition(cond: *const fn (val: T) bool) Self {
            return Self{ .CUSTOM = cond };
        }
        pub fn equals_string(str: []const u8) Self {
            return Self{ .EQUALS_STRING = str };
        }
        pub fn equals_string_opaque(str: []const u8) Self {
            return Self{ .EQUALS_STRING_OPAQUE_PTR = str };
        }
        pub fn opaque_ptr_equals_this_ptr_val(ptr: anytype) Self {
            const TT = @TypeOf(ptr);
            const SIZE = @sizeOf(TT);
            const opq = OpaqueVal{
                .byte_len = SIZE,
                .ptr = @ptrCast(ptr),
            };
            return Self{ .EQUALS_OPAQUE_PTR = opq };
        }

        pub fn is_true(comptime self: Self, val: T) bool {
            return switch (comptime self) {
                .NONE => true,
                .EQUAL => |v| v == val,
                .NOT_EQUAL => |v| v != val,
                .LESS_THAN => |v| val < v,
                .LESS_THAN_OR_EQUAL => |v| val <= v,
                .GREATER_THAN => |v| val > v,
                .GREATER_THAN_OR_EQUAL => |v| val >= v,
                .BETWEEN_INCLUDE_BOTH => |v| v.min <= val and val <= v.max,
                .BEWTEEN_EXCLUDE_MAX => |v| v.min <= val and val < v.max,
                .BEWTEEN_EXCLUDE_MIN => |v| v.min < val and val <= v.max,
                .BEWTEEN_EXCLUDE_BOTH => |v| v.min < val and val < v.max,
                .CUSTOM => |cond| cond(val),
                .EQUALS_STRING => |str| std.mem.eql(u8, str, val),
                .EQUALS_STRING_OPAQUE_PTR => |str| std.mem.eql(u8, str, @as(*const []const u8, @ptrCast(@alignCast(val))).*),
                .EQUALS_OPAQUE_PTR => |opq| opq.match(@ptrCast(val)),
            };
        }
    };
}

pub fn NullCondition(comptime T: type) type {
    return union(enum) {
        const Self = @This();
        const Child = KindInfo.get_kind_info(T).OPTIONAL.child;

        IS_NULL: void,
        NOT_NULL: ValCondition(Child),

        pub fn is_null() Self {
            return Self{ .IS_NULL = void{} };
        }
        pub fn not_null() Self {
            return Self{ .NOT_NULL = .no_cond() };
        }
        pub fn not_null_with_cond(comptime cond: ValCondition(Child)) Self {
            return Self{ .NOT_NULL = cond };
        }

        pub fn is_true(comptime self: Self, val: T) bool {
            return switch (comptime self) {
                .IS_NULL => return val == null,
                .NOT_NULL => |cond| {
                    if (val == null) return false;
                    return cond.is_true(val.?);
                },
            };
        }
    };
}

const ValErr = error{
    did_not_match_specific_value,
    did_not_match_any_valid_value,
    matched_specific_invalid_value,
    matched_one_of_the_invalid_values,
};

pub fn MatchSlice(comptime T: type) type {
    return union(MatchMode) {
        const Self = @This();

        NONE: void,
        IS: []const T,
        IS_ANY_OF: []const []const T,
        NOT: []const T,
        IS_NONE_OF: []const []const T,

        pub fn no_requirement() Self {
            return Self{ .NONE = void{} };
        }

        pub fn is(comptime val: []const T) Self {
            return Self{ .IS = val };
        }
        pub fn is_any_of(comptime val: []const []const T) Self {
            return Self{ .IS_ANY_OF = val };
        }
        pub fn is_not(comptime val: []const T) Self {
            return Self{ .NOT = val };
        }
        pub fn is_none_of(comptime val: []const []const T) Self {
            return Self{ .IS_NONE_OF = val };
        }

        pub fn match(comptime self: Self, comptime val: []const T) bool {
            switch (self) {
                .NONE => return true,
                .IS => |match_val| return std.mem.eql(T, match_val, val),
                .IS_ANY_OF => |match_vals| {
                    inline for (match_vals) |match_val| {
                        if (std.mem.eql(T, match_val, val)) return true;
                    }
                    return false;
                },
                .NOT => |match_val| return !std.mem.eql(T, match_val, val),
                .IS_NONE_OF => |match_vals| {
                    inline for (match_vals) |match_val| {
                        if (std.mem.eql(T, match_val, val)) return false;
                    }
                    return true;
                },
            }
        }
    };
}

pub fn MatchValue(comptime T: type) type {
    return union(MatchMode) {
        const Self = @This();

        NONE: void,
        IS: ValCondition(T),
        IS_ANY_OF: []const ValCondition(T),
        NOT: ValCondition(T),
        IS_NONE_OF: []const ValCondition(T),

        pub fn no_requirement() Self {
            return Self{ .NONE = void{} };
        }

        pub fn equals(val: T) Self {
            return Self{ .IS = .equals(val) };
        }
        pub fn equals_opaque_ptr(ptr: anytype) Self {
            return Self{ .IS = .equals(@ptrCast(ptr)) };
        }
        pub fn not_equal(val: T) Self {
            return Self{ .IS = .not_equal(val) };
        }
        pub fn less_than(val: T) Self {
            return Self{ .IS = .less_than(val) };
        }
        pub fn less_than_or_equal(val: T) Self {
            return Self{ .IS = .less_than_or_equal(val) };
        }
        pub fn greater_than(val: T) Self {
            return Self{ .IS = .greater_than(val) };
        }
        pub fn greater_than_or_equal(val: T) Self {
            return Self{ .IS = .greater_than_or_equal(val) };
        }
        pub fn bewteen_include_min_and_max(min: T, max: T) Self {
            return Self{ .IS = .bewteen_include_min_and_max(min, max) };
        }
        pub fn bewteen_include_min_exclude_max(min: T, max: T) Self {
            return Self{ .IS = .bewteen_include_min_exclude_max(min, max) };
        }
        pub fn bewteen_exclude_min_include_max(min: T, max: T) Self {
            return Self{ .IS = .bewteen_exclude_min_include_max(min, max) };
        }
        pub fn bewteen_exclude_min_and_max(min: T, max: T) Self {
            return Self{ .IS = .bewteen_exclude_min_and_max(min, max) };
        }
        pub fn has_custom_condition(cond: *const fn (val: T) bool) Self {
            return Self{ .IS = .has_custom_condition(cond) };
        }

        pub fn is(comptime cond: ValCondition(T)) Self {
            return Self{ .IS = cond };
        }
        pub fn is_any_of(comptime conds: []const ValCondition(T)) Self {
            return Self{ .IS_ANY_OF = conds };
        }
        pub fn is_not(comptime cond: ValCondition(T)) Self {
            return Self{ .NOT = cond };
        }
        pub fn is_none_of(comptime conds: []const ValCondition(T)) Self {
            return Self{ .IS_NONE_OF = conds };
        }

        pub fn match(comptime self: Self, comptime val: T) bool {
            switch (self) {
                .NONE => return true,
                .IS => |cond| return cond.is_true(val),
                .IS_ANY_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return true;
                    }
                    return false;
                },
                .NOT => |cond| return !cond.is_true(val),
                .IS_NONE_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return false;
                    }
                    return true;
                },
            }
        }
    };
}

pub fn MatchOptionalValue(comptime T: type) type {
    return union(MatchMode) {
        const Self = @This();
        const Child = @typeInfo(T).optional.child;

        NONE: void,
        IS: NullCondition(T),
        IS_ANY_OF: []const NullCondition(T),
        NOT: NullCondition(T),
        IS_NONE_OF: []const NullCondition(T),

        pub fn no_requirement() Self {
            return Self{ .NONE = void{} };
        }

        pub fn is_null() Self {
            return Self.is(.is_null());
        }
        pub fn not_null() Self {
            return Self.is(.not_null());
        }
        pub fn not_null_with_condition(comptime cond: ValCondition(Child)) Self {
            return Self.is(.not_null_with_cond(cond));
        }

        pub fn is(comptime cond: NullCondition(T)) Self {
            return Self{ .IS = cond };
        }
        pub fn is_any_of(comptime conds: []const NullCondition(T)) Self {
            return Self{ .IS_ANY_OF = conds };
        }
        pub fn is_not(comptime cond: NullCondition(T)) Self {
            return Self{ .NOT = cond };
        }
        pub fn is_none_of(comptime conds: []const NullCondition(T)) Self {
            return Self{ .IS_NONE_OF = conds };
        }

        pub fn match(comptime self: Self, comptime val: T) bool {
            switch (self) {
                .NONE => return true,
                .IS => |cond| return cond.is_true(val),
                .IS_ANY_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return true;
                    }
                    return false;
                },
                .NOT => |cond| return !cond.is_true(val),
                .IS_NONE_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return false;
                    }
                    return true;
                },
            }
        }
    };
}

pub const MatchKindInfo = union(MatchModeNotNone) {
    IS: KindInfoMatcher,
    IS_ANY_OF: []const KindInfoMatcher,
    NOT: KindInfoMatcher,
    IS_NONE_OF: []const KindInfoMatcher,

    pub fn is(comptime matcher: KindInfoMatcher) MatchKindInfo {
        return MatchKindInfo{ .IS = matcher };
    }
    pub fn is_any_of(comptime matcher: []const KindInfoMatcher) MatchKindInfo {
        return MatchKindInfo{ .IS_ANY_OF = matcher };
    }
    pub fn is_not(comptime matcher: KindInfoMatcher) MatchKindInfo {
        return MatchKindInfo{ .NOT = matcher };
    }
    pub fn is_none_of(comptime matcher: []const KindInfoMatcher) MatchKindInfo {
        return MatchKindInfo{ .IS_NONE_OF = matcher };
    }

    pub fn match(comptime self: MatchKindInfo, comptime TYPE: type, comptime info: KindInfo) bool {
        switch (self) {
            .IS => |matcher| return matcher.match(TYPE, info),
            .IS_ANY_OF => |matchers| {
                inline for (matchers) |matcher| {
                    if (matcher.match(TYPE, info)) return true;
                }
                return false;
            },
            .NOT => |matcher| return !matcher.match(TYPE, info),
            .IS_NONE_OF => |matchers| {
                inline for (matchers) |matcher| {
                    if (matcher.match(TYPE, info)) return false;
                }
                return true;
            },
        }
    }
};

pub const KindConditionMode = enum(u8) {
    MUST_NOT_BE = 0,
    CAN_BE = 1,
    MUST_BE = 2,
};

pub const MatchState = enum(u8) {
    NONE = 0,
    PASS = 1,
    FAIL = 2,
};

pub const MatchFailure = struct {
    ctx: []const u8 = "",
    state: MatchState = .NONE,

    pub fn done(comptime self: MatchFailure) ?MatchFailure {
        if (self.state != .NONE) return self;
        return null;
    }

    pub fn must_be_true_else_return(comptime self: MatchFailure, comptime cond: bool, comptime fmt: []const u8, comptime args: anytype) ?MatchFailure {
        if (!cond) {
            return self.add_fail_context(fmt, args);
        }
    }

    pub fn add_context(comptime self: MatchFailure, comptime fmt: []const u8, comptime args: anytype) MatchFailure {
        if (build.mode == .Debug) {
            comptime var new_self = self;
            new_self.ctx = self.ctx ++ std.fmt.comptimePrint(fmt, args);
            return new_self;
        } else {
            return self;
        }
    }
    pub fn add_pass_context(comptime self: MatchFailure, comptime fmt: []const u8, comptime args: anytype) MatchFailure {
        if (build.mode == .Debug) {
            comptime var new_self = self;
            new_self.ctx = self.ctx ++ std.fmt.comptimePrint(fmt, args);
            new_self.state = .PASS;
            return new_self;
        } else {
            comptime var new_self = self;
            new_self.state = .PASS;
            return new_self;
        }
    }
    pub fn add_fail_context(comptime self: MatchFailure, comptime fmt: []const u8, comptime args: anytype) MatchFailure {
        if (build.mode == .Debug) {
            comptime var new_self = self;
            new_self.ctx = self.ctx ++ std.fmt.comptimePrint(fmt, args);
            new_self.state = .FAIL;
            return new_self;
        } else {
            comptime var new_self = self;
            new_self.state = .FAIL;
            return new_self;
        }
    }

    pub fn did_pass(comptime self: MatchFailure) bool {
        return self.state == .PASS;
    }
    pub fn did_not_pass(comptime self: MatchFailure) bool {
        return self.state != .PASS;
    }
    pub fn did_fail(comptime self: MatchFailure) bool {
        return self.state == .FAIL;
    }
    pub fn did_not_fail(comptime self: MatchFailure) bool {
        return self.state != .FAIL;
    }
    pub fn undefined_result(comptime self: MatchFailure) bool {
        return self.state == .NONE;
    }
    pub fn did_pass_or_fail(comptime self: MatchFailure) bool {
        return self.state != .NONE;
    }
};

pub const KindInfoMatcher = union(enum) {
    TYPE: void,
    VOID: void,
    BOOL: void,
    NO_RETURN: void,
    INT: IntMatcher,
    FLOAT: FloatMatcher,
    POINTER: PointerMatcher,
    ARRAY: ArrayMatcher,
    STRUCT: StructMatcher,
    COMPTIME_FLOAT: void,
    COMPTIME_INT: void,
    UNDEFINED: void,
    NULL: void,
    OPTIONAL: OptionalMatcher,
    ERROR_UNION: void, // FIXME
    ERROR_SET: void, // FIXME
    ENUM: void, // FIXME
    UNION: void, // FIXME
    FUNCTION: void, // FIXME
    OPAQUE: void, // FIXME
    FRAME: void, // FIXME
    ANYFRAME: void, // FIXME
    VECTOR: VectorMatcher,
    ENUM_LITERAL: void,

    pub fn type_kind() KindInfoMatcher {
        return KindInfoMatcher{ .TYPE = void{} };
    }
    pub fn void_kind() KindInfoMatcher {
        return KindInfoMatcher{ .VOID = void{} };
    }
    pub fn bool_kind() KindInfoMatcher {
        return KindInfoMatcher{ .BOOL = void{} };
    }
    pub fn noreturn_kind() KindInfoMatcher {
        return KindInfoMatcher{ .NO_RETURN = void{} };
    }
    pub fn int_kind(comptime matcher: IntMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .INT = matcher };
    }
    pub fn float_kind(comptime matcher: FloatMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .FLOAT = matcher };
    }
    pub fn pointer_kind(comptime matcher: PointerMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .POINTER = matcher };
    }
    pub fn array_kind(comptime matcher: ArrayMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .ARRAY = matcher };
    }
    pub fn vector_kind(comptime matcher: VectorMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .VECTOR = matcher };
    }
    pub fn struct_kind(comptime matcher: StructMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .STRUCT = matcher };
    }
    pub fn optional_kind(comptime matcher: OptionalMatcher) KindInfoMatcher {
        return KindInfoMatcher{ .OPTIONAL = matcher };
    }

    pub fn match(comptime self: KindInfoMatcher, comptime TYPE: type, info: KindInfo) bool {
        switch (self) {
            .TYPE => return info == .TYPE,
            .VOID => return info == .VOID,
            .BOOL => return info == .BOOL,
            .NO_RETURN => return info == .NO_RETURN,
            .INT => |matcher| {
                if (info != .INT) return false;
                return matcher.match(info.INT);
            },
            .FLOAT => |matcher| {
                if (info != .FLOAT) return false;
                return matcher.match(info.FLOAT);
            },
            .POINTER => |matcher| {
                if (info != .POINTER) return false;
                return matcher.match(info.POINTER);
            },
            .ARRAY => |matcher| {
                if (info != .ARRAY) return false;
                return matcher.match(info.ARRAY);
            },
            .STRUCT => |matcher| {
                if (info != .STRUCT) return false;
                return matcher.match(TYPE, info.STRUCT);
            },
            .COMPTIME_FLOAT => return info == .COMPTIME_FLOAT,
            .COMPTIME_INT => return info == .COMPTIME_INT,
            .UNDEFINED => return info == .UNDEFINED,
            .NULL => return info == .NULL,
            .OPTIONAL => |matcher| {
                if (info != .OPTIONAL) return false;
                return matcher.match(info.OPTIONAL);
            },
            .ERROR_UNION => {}, // FIXME //CHECKPOINT
            .ERROR_SET => {}, // FIXME
            .ENUM => {}, // FIXME
            .UNION => {}, // FIXME
            .FUNCTION => {}, // FIXME
            .OPAQUE => {}, // FIXME
            .FRAME => {}, // FIXME
            .ANYFRAME => {}, // FIXME
            .VECTOR => |matcher| {
                if (info != .VECTOR) return false;
                return matcher.match(info.VECTOR);
            },
            .ENUM_LITERAL => return info == .ENUM_LITERAL,
        }
        return false;
    }
};

pub const IntMatcher = struct {
    bits: MatchValue(u16) = .no_requirement(),
    signedness: MatchValue(builtin.Signedness) = .no_requirement(),

    pub fn with_bits(comptime bits: MatchValue(u16)) IntMatcher {
        return IntMatcher{
            .bits = bits,
        };
    }
    pub fn and_with_bits(comptime self: IntMatcher, comptime bits: MatchValue(u16)) IntMatcher {
        comptime var new_self = self;
        new_self.bits = bits;
        return new_self;
    }
    pub fn with_signedness(comptime signedness: MatchValue(builtin.Signedness)) IntMatcher {
        return IntMatcher{
            .signedness = signedness,
        };
    }
    pub fn and_with_signedness(comptime self: IntMatcher, comptime signedness: MatchValue(builtin.Signedness)) IntMatcher {
        comptime var new_self = self;
        new_self.signedness = signedness;
        return new_self;
    }

    pub fn match(comptime self: IntMatcher, comptime val: Type.Int) bool {
        return self.bits.match(val.bits) //
        and self.signedness.match(val.signedness);
    }
};

pub const FloatMatcher = struct {
    bits: MatchValue(u16) = .no_requirement(),

    pub fn match(comptime self: FloatMatcher, comptime val: Type.Float) bool {
        return self.bits.match(val.bits);
    }
};

pub const PointerMatcher = struct {
    size: MatchValue(Type.Pointer.Size) = .no_requirement(),
    is_const: MatchValue(bool) = .no_requirement(),
    is_volatile: MatchValue(bool) = .no_requirement(),
    alignment: MatchOptionalValue(?usize) = .no_requirement(),
    address_space: MatchValue(builtin.AddressSpace) = .no_requirement(),
    child: *const TypeMatcher = &TypeMatcher.NO_REQ,
    is_allowzero: MatchValue(bool) = .no_requirement(),
    sentinel_ptr: MatchOptionalValue(?*const anyopaque) = .no_requirement(),

    pub fn match(comptime self: PointerMatcher, comptime val: Type.Pointer) bool {
        return self.size.match(val.size) //
        and self.is_const.match(val.is_const) //
        and self.is_volatile.match(val.is_volatile) //
        and self.alignment.match(val.alignment) //
        and self.address_space.match(val.address_space) //
        and self.is_allowzero.match(val.is_allowzero) //
        and self.child.match(val.child) //
        and self.sentinel_ptr.match(val.sentinel_ptr);
    }
};

pub const ArrayMatcher = struct {
    len: MatchValue(usize) = .no_requirement(),
    child: *const TypeMatcher = &TypeMatcher.NO_REQ,
    sentinel_ptr: MatchOptionalValue(?*const anyopaque) = .no_requirement(),

    pub fn match(comptime self: ArrayMatcher, comptime val: Type.Array) bool {
        return self.len.match(val.len) //
        and self.child.match(val.child) //
        and self.sentinel_ptr.match(val.sentinel_ptr);
    }
};

pub const VectorMatcher = struct {
    len: MatchValue(usize) = .no_requirement(),
    child: *const TypeMatcher = &TypeMatcher.NO_REQ,

    pub fn match(comptime self: VectorMatcher, comptime val: Type.Vector) bool {
        return self.len.match(val.len) //
        and self.child.match(val.child);
    }
};

pub const OptionalMatcher = struct {
    child: *const TypeMatcher = &TypeMatcher.NO_REQ,

    pub fn match(comptime self: VectorMatcher, comptime val: Type.Optional) bool {
        return self.child.match(val.child);
    }
};

pub const StructMatcher = struct {
    layout: MatchValue(Type.ContainerLayout) = .no_requirement(),
    backing_integer: MatchOptionalValue(?type) = .no_requirement(),
    is_tuple: MatchValue(bool) = .no_requirement(),
    fields: AllStructFieldsMatcher = .no_requirement(),
    decls: AllDeclsMatcher = .no_requirement(),

    pub fn match(comptime self: StructMatcher, comptime STRUCT_TYPE: type, comptime val: Type.Struct) bool {
        // _ = STRUCT_TYPE;
        const result = self.layout.match(val.layout) //
            and self.backing_integer.match(val.backing_integer) //
            and self.is_tuple.match(val.is_tuple) //
            and self.fields.match(STRUCT_TYPE, val.fields) //
            and self.decls.match(STRUCT_TYPE, val.decls); //
        return result;
    }
};

pub const FlexFieldMatchers = struct {
    /// This is tested first, and any matched fields are removed from the
    /// available fields to match
    first_has_all_of: []const StructFieldMatcher = &.{},
    /// This is tested second, and any matched fields are removed from the
    /// available fields to match. It will not test any of the fields
    /// matched by `first_has_all_of` (if any)
    then_has_any_of: []const StructFieldMatcher = &.{},
    /// This is tested third. It will not test any of the fields
    /// matched by `first_has_all_of` (if any) or any of the fields matched
    /// by `second_has_any_of` (if any)
    finally_has_none_of: []const StructFieldMatcher = &.{},
};
pub const AllStructFieldsMatcher = union(enum) {
    NONE: void,
    EXACT: []const StructFieldMatcher,
    FLEX: FlexFieldMatchers,

    pub fn no_requirement() AllStructFieldsMatcher {
        return AllStructFieldsMatcher{ .NONE = void{} };
    }

    pub fn with_exactly_these_fields(comptime field_matchers: []const StructFieldMatcher) AllStructFieldsMatcher {
        return AllStructFieldsMatcher{ .EXACT = field_matchers };
    }
    pub fn with_flexible_field_conditions(comptime field_matchers: FlexFieldMatchers) AllStructFieldsMatcher {
        return AllStructFieldsMatcher{ .FLEX = field_matchers };
    }

    pub fn match(comptime self: AllStructFieldsMatcher, comptime STRUCT_TYPE: type, comptime fields: []const Type.StructField) bool {
        switch (self) {
            .NONE => {},
            .EXACT => |matchers| {
                if (matchers.len != fields.len) return false;
                comptime var matched_fields: [fields.len]bool = @splat(false);
                comptime var num_matched: usize = 0;
                next_match: inline for (matchers) |matcher| {
                    next_field: inline for (fields, 0..) |field, f| {
                        if (matched_fields[f]) continue :next_field;
                        if (matcher.match(STRUCT_TYPE, field)) {
                            matched_fields[f] = true;
                            num_matched += 1;
                            continue :next_match;
                        }
                    }
                }
                if (num_matched != matchers.len) return false;
            },
            .FLEX => |cond| {
                comptime var matched_fields: [fields.len]bool = @splat(false);
                if (cond.first_has_all_of.len > 0) {
                    if (fields.len < cond.first_has_all_of.len) return false;
                    comptime var num_matched: usize = 0;
                    next_match: inline for (cond.first_has_all_of) |matcher| {
                        next_field: inline for (fields, 0..) |field, f| {
                            if (matched_fields[f]) continue :next_field;
                            if (matcher.match(STRUCT_TYPE, field)) {
                                matched_fields[f] = true;
                                num_matched += 1;
                                continue :next_match;
                            }
                        }
                    }
                    if (num_matched != cond.first_has_all_of.len) return false;
                }
                if (cond.then_has_any_of.len > 0) {
                    comptime var found_match: bool = false;
                    next_match: inline for (cond.then_has_any_of) |matcher| {
                        next_field: inline for (fields, 0..) |field, f| {
                            if (matched_fields[f]) continue :next_field;
                            if (matcher.match(STRUCT_TYPE, field)) {
                                matched_fields[f] = true;
                                found_match = true;
                                continue :next_match;
                            }
                        }
                    }
                    if (!found_match) return false;
                }
                if (cond.finally_has_none_of.len > 0) {
                    inline for (cond.finally_has_none_of) |matcher| {
                        next_field: inline for (fields, 0..) |field, f| {
                            if (matched_fields[f]) continue :next_field;
                            if (matcher.match(STRUCT_TYPE, field)) {
                                return false;
                            }
                        }
                    }
                }
            },
        }
        return true;
    }
};

pub const StructFieldMatcher = struct {
    offset: MatchValue(usize) = .no_requirement(),
    bit_offset: MatchValue(usize) = .no_requirement(),
    name: MatchSlice(u8) = .no_requirement(),
    type: *const TypeMatcher = &TypeMatcher.NO_REQ,
    default_value_ptr: MatchOptionalValue(?*const anyopaque) = .no_requirement(),
    is_comptime: MatchValue(bool) = .no_requirement(),
    alignment: MatchOptionalValue(?usize) = .no_requirement(),

    pub fn field_name(comptime name: []const u8) StructFieldMatcher {
        return StructFieldMatcher{
            .name = .is(name),
        };
    }
    pub fn field_name_and_type(comptime name: []const u8, comptime T: type) StructFieldMatcher {
        return StructFieldMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is(T),
        };
    }
    pub fn field_name_and_kind(comptime name: []const u8, comptime matcher: MatchKindInfo) StructFieldMatcher {
        return StructFieldMatcher{
            .name = .is(name),
            .type = &TypeMatcher.kind(matcher),
        };
    }
    pub fn field_name_type_and_default(comptime name: []const u8, comptime T: type, default: *const T) StructFieldMatcher {
        return StructFieldMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is(T),
            .default_value_ptr = .not_null_with_condition(.opaque_ptr_equals_this_ptr_val(default)),
        };
    }
    pub fn field_name_type_and_default_string(comptime name: []const u8, default: []const u8) StructFieldMatcher {
        return StructFieldMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is([]const u8),
            .default_value_ptr = .not_null_with_condition(.equals_string_opaque(default)),
        };
    }

    pub fn match(comptime self: StructFieldMatcher, comptime STRUCT: type, comptime field: Type.StructField) bool {
        const result = self.name.match(field.name) //
            and self.is_comptime.match(field.is_comptime) //
            and self.alignment.match(field.alignment) //
            and self.type.match(field.type) //
            and self.default_value_ptr.match(field.default_value_ptr) //
            and self.offset.match(@offsetOf(STRUCT, field.name)) //
            and self.bit_offset.match(@bitOffsetOf(STRUCT, field.name));
        return result;
    }
};

pub const FlexDeclMatchers = struct {
    /// This is tested first, and any matched decls are removed from the
    /// available decls to match
    first_has_all_of: []const DeclMatcher = &.{},
    /// This is tested second, and any matched decls are removed from the
    /// available decls to match. It will not test any of the decls
    /// matched by `first_has_all_of` (if any)
    then_has_any_of: []const DeclMatcher = &.{},
    /// This is tested third. It will not test any of the decls
    /// matched by `first_has_all_of` (if any) or any of the decls matched
    /// by `second_has_any_of` (if any)
    finally_has_none_of: []const DeclMatcher = &.{},
};

pub const AllDeclsMatcher = union(enum) {
    NONE: void,
    EXACT: []const DeclMatcher,
    FLEX: FlexDeclMatchers,

    pub fn no_requirement() AllDeclsMatcher {
        return AllDeclsMatcher{ .NONE = void{} };
    }

    pub fn with_exactly_these_decls(comptime decl_matchers: []const DeclMatcher) AllDeclsMatcher {
        return AllDeclsMatcher{ .EXACT = decl_matchers };
    }
    pub fn with_flexible_decl_conditions(comptime decl_matchers: FlexDeclMatchers) AllDeclsMatcher {
        return AllDeclsMatcher{ .FLEX = decl_matchers };
    }

    pub fn match(comptime self: AllDeclsMatcher, comptime OBJECT_TYPE: type, comptime decls: []const Type.Declaration) bool {
        switch (self) {
            .NONE => {},
            .EXACT => |matchers| {
                if (matchers.len != decls.len) return false;
                comptime var matched_decls: [decls.len]bool = @splat(false);
                next_match: inline for (matchers) |matcher| {
                    next_field: inline for (decls, 0..) |decl, d| {
                        if (matched_decls[d]) continue :next_field;
                        const unwrapped = UnwrappedDecl.new(OBJECT_TYPE, decl);
                        if (matcher.match(unwrapped)) {
                            matched_decls[d] = true;
                            continue :next_match;
                        }
                    }
                    return false;
                }
            },
            .FLEX => |cond| {
                comptime var matched_decls: [decls.len]bool = @splat(false);
                if (cond.first_has_all_of.len > 0) {
                    if (decls.len < cond.first_has_all_of.len) return false;
                    comptime var num_matched: usize = 0;
                    next_match: inline for (cond.first_has_all_of) |matcher| {
                        next_decl: inline for (decls, 0..) |decl, d| {
                            if (matched_decls[d]) continue :next_decl;
                            const unwrapped = UnwrappedDecl.new(OBJECT_TYPE, decl);
                            if (matcher.match(unwrapped)) {
                                matched_decls[d] = true;
                                num_matched += 1;
                                continue :next_match;
                            }
                        }
                    }
                    if (num_matched != cond.first_has_all_of.len) return false;
                }
                if (cond.then_has_any_of.len > 0) {
                    comptime var found_match: bool = false;
                    next_match: inline for (cond.then_has_any_of) |matcher| {
                        next_decl: inline for (decls, 0..) |decl, d| {
                            if (matched_decls[d]) continue :next_decl;
                            const unwrapped = UnwrappedDecl.new(OBJECT_TYPE, decl);
                            if (matcher.match(unwrapped)) {
                                matched_decls[d] = true;
                                found_match = true;
                                continue :next_match;
                            }
                        }
                    }
                    if (!found_match) return false;
                }
                if (cond.finally_has_none_of.len > 0) {
                    inline for (cond.finally_has_none_of) |matcher| {
                        next_decl: inline for (decls, 0..) |decl, d| {
                            if (matched_decls[d]) continue :next_decl;
                            const unwrapped = UnwrappedDecl.new(OBJECT_TYPE, decl);
                            if (matcher.match(unwrapped)) {
                                return false;
                            }
                        }
                    }
                }
            },
        }
        return true;
    }
};

pub const DeclMatcher = struct {
    name: MatchSlice(u8) = .no_requirement(),
    type: *const TypeMatcher = &TypeMatcher.NO_REQ,
    value: MatchValue(*const anyopaque) = .no_requirement(),

    pub fn decl_name(comptime name: []const u8) DeclMatcher {
        return DeclMatcher{
            .name = .is(name),
        };
    }
    pub fn decl_name_and_type(comptime name: []const u8, comptime T: type) DeclMatcher {
        return DeclMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is(T),
        };
    }
    pub fn decl_name_and_kind(comptime name: []const u8, comptime matcher: MatchKindInfo) DeclMatcher {
        return DeclMatcher{
            .name = .is(name),
            .type = &TypeMatcher.kind(matcher),
        };
    }
    pub fn decl_name_type_and_value(comptime name: []const u8, comptime T: type, default: *const T) DeclMatcher {
        return DeclMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is(T),
            .value = .is(.opaque_ptr_equals_this_ptr_val(default)),
        };
    }
    pub fn decl_name_type_and_string_value(comptime name: []const u8, default: []const u8) DeclMatcher {
        return DeclMatcher{
            .name = .is(name),
            .type = &TypeMatcher.type_is([]const u8),
            .value = .is(.equals_string_opaque(default)),
        };
    }

    pub fn match(comptime self: DeclMatcher, comptime decl: UnwrappedDecl) bool {
        return self.name.match(decl.name) //
        and self.type.match(decl.type) //
        and self.value.match(decl.value);
    }
};

pub const UnwrappedDecl = struct {
    name: []const u8,
    type: type,
    value: *const anyopaque,

    pub fn new(comptime OBJECT: type, comptime decl: Type.Declaration) UnwrappedDecl {
        return UnwrappedDecl{
            .name = decl.name,
            .type = @TypeOf(@field(OBJECT, decl.name)),
            .value = @ptrCast(&@field(OBJECT, decl.name)),
        };
    }
};

pub const TypeMatcher = union(enum) {
    TYPE: MatchValue(type),
    KIND: MatchKindInfo,
    NONE: void,

    pub const NO_REQ = TypeMatcher{ .NONE = void{} };

    pub fn no_requirement() TypeMatcher {
        return NO_REQ;
    }
    pub fn type_condition(comptime matcher: MatchValue(type)) TypeMatcher {
        return TypeMatcher{ .TYPE = matcher };
    }
    pub fn type_is(comptime T: type) TypeMatcher {
        return TypeMatcher{ .TYPE = MatchValue(type).equals(T) };
    }
    pub fn kind(comptime matcher: MatchKindInfo) TypeMatcher {
        return TypeMatcher{ .KIND = matcher };
    }

    pub fn match(comptime self: *const TypeMatcher, comptime T: type) bool {
        switch (self.*) {
            .TYPE => |matcher| return matcher.match(T),
            .KIND => |matcher| return matcher.match(T, KindInfo.get_kind_info(T)),
            .NONE => return true,
        }
    }
};

pub fn type_match(comptime T: type, comptime condition: TypeMatcher) bool {
    assert_in_comptime(@src());
    return condition.match(T);
}

test type_match {
    const Test = Root.Testing;

    const check_is_less_than_42_bits = comptime type_match(u32, .kind(.is(.int_kind(.with_bits(.less_than(42))))));
    const check_is_less_than_24_bits = comptime type_match(u32, .kind(.is(.int_kind(.with_bits(.less_than(24))))));
    try Test.expect_true_src(check_is_less_than_42_bits, @src(), "", .{});
    try Test.expect_false_src(check_is_less_than_24_bits, @src(), "", .{});

    const PetKind = enum(u8) { CAT, DOG };

    const Pet = struct {
        kind: PetKind,
        age: u8 = 1,
        fixed: bool = false,
    };

    const Person = struct {
        name: []const u8 = "<DEFAULT>",
        age: u32 = 0,
        pets: []const Pet = &.{},
        married: bool = false,

        pub const JOHN = @This(){
            .age = 33,
            .name = "John",
            .pets = &.{
                Pet{
                    .kind = .CAT,
                    .age = 2,
                    .fixed = true,
                },
                Pet{
                    .kind = .DOG,
                    .age = 8,
                    .fixed = false,
                },
            },
        };

        pub const EMPTY: []const @This() = &.{};
    };

    const check_person_exact = comptime type_match(Person, .type_is(Person));
    const check_person_shape = comptime type_match(Person, .kind(.is(.struct_kind(StructMatcher{
        .is_tuple = .equals(false),
        .layout = .equals(.auto),
        .backing_integer = .is_null(),
        .fields = .with_exactly_these_fields(&.{
            .field_name_type_and_default_string("name", "<DEFAULT>"),
            .field_name_type_and_default("age", u32, &@as(u32, 0)),
            .field_name_and_type("pets", []const Pet),
            .field_name_and_kind("married", .is(.bool_kind())),
        }),
        .decls = .with_exactly_these_decls(&.{
            .decl_name_type_and_value("JOHN", Person, &Person.JOHN),
            .decl_name_and_kind("EMPTY", .is(.pointer_kind(.{}))),
        }),
    }))));

    try Test.expect_true_src(check_person_exact, @src(), "", .{});
    try Test.expect_true_src(check_person_shape, @src(), "", .{});
}
