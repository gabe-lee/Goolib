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

const MatchResultKind = enum(u8) {
    UNDEFINED = 0,
    FAILED = 0b01,
    PASSED = 0b10,
};

const MatchResult = struct {
    result: u8 = 0,

    pub fn new(comptime kind: MatchResultKind) MatchResult {
        return MatchResult{ .result = @intFromEnum(kind) };
    }

    pub fn uninit() MatchResult {
        return .new(.UNDEFINED);
    }

    pub fn combine(comptime self: MatchResult, comptime other: MatchResult) MatchResult {
        var new_self = self;
        new_self.result |= other.result;
        return new_self;
    }

    pub fn combine_passed(comptime self: MatchResult) MatchResult {
        return self.combine(.new(.PASSED));
    }
    pub fn combine_failed(comptime self: MatchResult) MatchResult {
        return self.combine(.new(.FAILED));
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
        return self.result == 0b10;
    }
};

pub fn MinMax(comptime T: type) type {
    return struct {
        min: T,
        max: T,
    };
}

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

        pub fn match(comptime self: Self, comptime val: T, comptime result: MatchResult) MatchResult {
            switch (self) {
                .NONE => return result,
                .IS => |cond| return result.and_must_be_true(cond.is_true(val)),
                .IS_ANY_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return result.combine_passed();
                    }
                    return result.combine_failed();
                },
                .NOT => |cond| return result.and_must_be_false(cond.is_true(val)),
                .IS_NONE_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return result.combine_failed();
                    }
                    return result.combine_passed();
                },
            }
        }
    };
}

pub fn MatchOptionalValue(comptime T: type) type {
    return union(MatchMode) {
        const Self = @This();

        NONE: void,
        IS: NullCondition(T),
        IS_ANY_OF: []const NullCondition(T),
        NOT: NullCondition(T),
        IS_NONE_OF: []const NullCondition(T),

        pub fn no_requirement() Self {
            return Self{ .NONE = void{} };
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

        pub fn match(comptime self: Self, comptime val: T, comptime result: MatchResult) MatchResult {
            switch (self) {
                .NONE => return result,
                .IS => |cond| return result.and_must_be_true(cond.is_true(val)),
                .IS_ANY_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return result.combine_passed();
                    }
                    return result.combine_failed();
                },
                .NOT => |cond| return result.and_must_be_false(cond.is_true(val)),
                .IS_NONE_OF => |conds| {
                    inline for (conds) |cond| {
                        if (cond.is_true(val)) return result.combine_failed();
                    }
                    return result.combine_passed();
                },
            }
        }
    };
}

pub const KindConditionMode = enum(u8) {
    MUST_NOT_BE = 0,
    CAN_BE = 1,
};

pub const TypeMatcher = MatchValue(type);
pub const PtrSizeMatcher = MatchValue(Type.Pointer.Size);
pub const OptAlignMatcher = MatchValue(?usize);
pub const AlignMatcher = MatchValue(usize);

pub const KindMatcher = struct {
    TYPE: GenericCondition(.TYPE) = .must_not_be(),
    VOID: GenericCondition(.VOID) = .must_not_be(),
    BOOL: GenericCondition(.BOOL) = .must_not_be(),
    NO_RETURN: GenericCondition(.NO_RETURN) = .must_not_be(),
    INT: IntCondition = .must_not_be_int(),
    FLOAT: FloatCondition = .must_not_be_float(),
    POINTER: PointerCondition = .must_not_be_pointer(),
    ARRAY: KindConditionMode = undefined,
    STRUCT: KindConditionMode = undefined,
    COMPTIME_FLOAT: GenericCondition(.COMPTIME_FLOAT) = .must_not_be(),
    COMPTIME_INT: GenericCondition(.COMPTIME_INT) = .must_not_be(),
    UNDEFINED: GenericCondition(.UNDEFINED) = .must_not_be(),
    NULL: GenericCondition(.NULL) = .must_not_be(),
    OPTIONAL: KindConditionMode = undefined,
    ERROR_UNION: KindConditionMode = undefined,
    ERROR_SET: KindConditionMode = undefined,
    ENUM: KindConditionMode = undefined,
    UNION: KindConditionMode = undefined,
    FUNCTION: KindConditionMode = undefined,
    OPAQUE: KindConditionMode = undefined,
    FRAME: KindConditionMode = undefined,
    ANYFRAME: KindConditionMode = undefined,
    VECTOR: KindConditionMode = undefined,
    ENUM_LITERAL: GenericCondition(.ENUM_LITERAL) = .must_not_be(),

    pub fn must_be_type() KindMatcher {
        return KindMatcher{
            .TYPE = .can_be(),
        };
    }
    pub fn must_be_void() KindMatcher {
        return KindMatcher{
            .VOID = .can_be(),
        };
    }
    pub fn must_be_bool() KindMatcher {
        return KindMatcher{
            .BOOL = .can_be(),
        };
    }
    pub fn must_be_no_return() KindMatcher {
        return KindMatcher{
            .NO_RETURN = .can_be(),
        };
    }
    pub fn must_be_int(comptime cond: IntCondition) KindMatcher {
        return KindMatcher{
            .INT = cond,
        };
    }
    pub fn must_be_float(comptime cond: FloatCondition) KindMatcher {
        return KindMatcher{
            .FLOAT = cond,
        };
    }
    pub fn must_be_pointer(comptime cond: PointerCondition) KindMatcher {
        return KindMatcher{
            .POINTER = cond,
        };
    }

    pub fn match(comptime self: KindMatcher, comptime info: KindInfo, comptime result: MatchResult) MatchResult {
        comptime var new_result = result;
        new_result = comptime self.TYPE.match(info, new_result);
        new_result = comptime self.VOID.match(info, new_result);
        new_result = comptime self.BOOL.match(info, new_result);
        new_result = comptime self.NO_RETURN.match(info, new_result);
        new_result = comptime self.INT.match(info, new_result);
        new_result = comptime self.FLOAT.match(info, new_result);
        new_result = comptime self.POINTER.match(info, new_result);
        //CHECKPOINT
        // new_result = self.ARRAY.match(info, new_result);
        // new_result = self.STRUCT.match(info, new_result);
        new_result = comptime self.COMPTIME_FLOAT.match(info, new_result);
        new_result = comptime self.COMPTIME_INT.match(info, new_result);
        new_result = comptime self.UNDEFINED.match(info, new_result);
        new_result = comptime self.NULL.match(info, new_result);
        // new_result = self.OPTIONAL.match(info, new_result);
        // new_result = self.ERROR_UNION.match(info, new_result);
        // new_result = self.ERROR_SET.match(info, new_result);
        // new_result = self.ENUM.match(info, new_result);
        // new_result = self.UNION.match(info, new_result);
        // new_result = self.FUNCTION.match(info, new_result);
        // new_result = self.OPAQUE.match(info, new_result);
        // new_result = self.FRAME.match(info, new_result);
        // new_result = self.ANYFRAME.match(info, new_result);
        // new_result = self.VECTOR.match(info, new_result);
        new_result = comptime self.ENUM_LITERAL.match(info, new_result);
        return new_result;
    }
};

pub fn GenericCondition(comptime KIND: Kind) type {
    return union(KindConditionMode) {
        const Self = @This();

        MUST_NOT_BE: void,
        CAN_BE: void,

        pub fn must_not_be() Self {
            return Self{ .MUST_NOT_BE = void{} };
        }
        pub fn can_be() Self {
            return Self{ .CAN_BE = void{} };
        }

        pub fn match(comptime self: Self, comptime kind: KindInfo, comptime result: MatchResult) MatchResult {
            switch (self) {
                .CAN_BE => return result.and_pass_if_true(kind == KIND),
                .MUST_NOT_BE => return result.and_fail_if_true(kind == KIND),
            }
        }
    };
}

pub const IntCondition = union(KindConditionMode) {
    MUST_NOT_BE: void,
    CAN_BE: IntMatcher,

    pub fn must_not_be_int() IntCondition {
        return IntCondition{ .MUST_NOT_BE = void{} };
    }
    pub fn any_int() IntCondition {
        return IntCondition{ .CAN_BE = .{} };
    }
    pub fn with_bits(comptime bits: MatchValue(u16)) IntCondition {
        return IntCondition{
            .CAN_BE = .with_bits(bits),
        };
    }
    pub fn and_with_bits(comptime self: IntCondition, comptime bits: MatchValue(u16)) IntCondition {
        comptime var new_self = self;
        new_self.CAN_BE.bits = bits;
        return new_self;
    }
    pub fn with_signedness(comptime signedness: MatchValue(builtin.Signedness)) IntCondition {
        return IntCondition{
            .CAN_BE = .with_signedness(signedness),
        };
    }
    pub fn and_with_signedness(comptime self: IntCondition, comptime signedness: MatchValue(builtin.Signedness)) IntCondition {
        comptime var new_self = self;
        new_self.CAN_BE.signedness = signedness;
        return new_self;
    }

    pub fn match(comptime self: IntCondition, comptime kind: KindInfo, comptime result: MatchResult) MatchResult {
        switch (self) {
            .CAN_BE => |matcher| {
                if (kind == .INT) {
                    return matcher.match(kind.INT, result);
                }
                return result;
            },
            .MUST_NOT_BE => return result.and_fail_if_true(kind == .INT),
        }
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

    pub fn match(comptime self: IntMatcher, comptime val: Type.Int, comptime result: MatchResult) MatchResult {
        const r2 = self.bits.match(val.bits, result);
        return self.signedness.match(val.signedness, r2);
    }
};

pub const FloatCondition = union(KindConditionMode) {
    MUST_NOT_BE: void,
    CAN_BE: FloatMatcher,

    pub fn must_not_be_float() FloatCondition {
        return FloatCondition{ .MUST_NOT_BE = void{} };
    }
    pub fn can_be_float(comptime matcher: FloatMatcher) FloatCondition {
        return FloatCondition{ .CAN_BE = matcher };
    }

    pub fn match(comptime self: FloatCondition, comptime kind: KindInfo, comptime result: MatchResult) MatchResult {
        switch (self) {
            .CAN_BE => |matcher| {
                if (kind == .FLOAT) {
                    return matcher.match(kind.FLOAT, result);
                }
                return result;
            },
            .MUST_NOT_BE => return result.and_fail_if_true(kind == .FLOAT),
        }
    }
};

pub const FloatMatcher = struct {
    bits: MatchValue(u16) = .no_requirement(),

    pub fn match(comptime self: FloatMatcher, comptime val: Type.Float, comptime result: MatchResult) MatchResult {
        return self.bits.match(val.bits, result);
    }
};

pub const PointerCondition = union(KindConditionMode) {
    MUST_NOT_BE: void,
    CAN_BE: FloatMatcher,

    pub fn must_not_be_pointer() PointerCondition {
        return PointerCondition{ .MUST_NOT_BE = void{} };
    }
    pub fn can_be_pointer(comptime matcher: FloatMatcher) PointerCondition {
        return PointerCondition{ .CAN_BE = matcher };
    }

    pub fn match(comptime self: PointerCondition, comptime kind: KindInfo, comptime result: MatchResult) MatchResult {
        switch (self) {
            .CAN_BE => |matcher| {
                if (kind == .POINTER) {
                    return matcher.match(kind.POINTER, result);
                }
                return result;
            },
            .MUST_NOT_BE => return result.and_fail_if_true(kind == .POINTER),
        }
    }
};

pub const PointerMatcher = struct {
    size: MatchValue(Type.Pointer.Size) = .no_requirement(),
    is_const: MatchValue(bool) = .no_requirement(),
    is_volatile: MatchValue(bool) = .no_requirement(),
    alignment: MatchOptionalValue(?usize) = .no_requirement(),
    address_space: MatchValue(builtin.AddressSpace) = .no_requirement(),
    child: *const TypeOrKindMatch = &TypeOrKindMatch.NO_REQ,
    is_allowzero: MatchValue(bool) = .no_requirement(),
    sentinel_ptr: MatchOptionalValue(?*const anyopaque) = .no_requirement(),

    pub fn match(comptime self: PointerMatcher, comptime val: Type.Pointer, comptime result: MatchResult) MatchResult {
        comptime var new_result = result;
        new_result = self.size.match(val.size, new_result);
        new_result = self.is_const.match(val.is_const, new_result);
        new_result = self.is_volatile.match(val.is_volatile, new_result);
        new_result = self.alignment.match(val.alignment, new_result);
        new_result = self.address_space.match(val.address_space, new_result);
        new_result = self.is_allowzero.match(val.is_allowzero, new_result);
        new_result = self.child.match(val.child, new_result);
        new_result = self.sentinel_ptr.match(val.sentinel_ptr, new_result);
        return new_result;
    }
};

pub const TypeOrKindMatch = union(enum) {
    TYPE: MatchValue(type),
    KIND: KindMatcher,
    NONE: void,

    pub const NO_REQ = TypeOrKindMatch{ .NONE = void{} };

    pub fn no_requirement() TypeOrKindMatch {
        return NO_REQ;
    }
    pub fn type_condition(comptime matcher: TypeMatcher) TypeOrKindMatch {
        return TypeOrKindMatch{ .TYPE = matcher };
    }
    pub fn type_is(comptime T: type) TypeOrKindMatch {
        return TypeOrKindMatch{ .TYPE = TypeMatcher.equals(T) };
    }
    pub fn kind(comptime matcher: KindMatcher) TypeOrKindMatch {
        return TypeOrKindMatch{ .KIND = matcher };
    }

    pub fn match(comptime self: TypeOrKindMatch, comptime T: type, comptime result: MatchResult) MatchResult {
        switch (self) {
            .TYPE => |matcher| return matcher.match(T, result),
            .KIND => |matcher| return matcher.match(KindInfo.get_kind_info(T), result),
            .NONE => return result,
        }
    }
};

pub fn type_match(comptime T: type, comptime condition: TypeOrKindMatch) bool {
    assert_in_comptime(@src());
    const result = condition.match(T, .uninit());
    // std.debug.print("\nresult: {any}\n", .{result});
    return result.final_match();
}

test type_match {
    const Test = Root.Testing;

    const check_is_less_than_42_bits = comptime type_match(u32, .kind(.must_be_int(.with_bits(.less_than(42)))));
    const check_is_less_than_24_bits = comptime type_match(u32, .kind(.must_be_int(.with_bits(.less_than(24)))));
    try Test.expect_true_src(check_is_less_than_42_bits, @src(), "", .{});
    try Test.expect_false_src(check_is_less_than_24_bits, @src(), "", .{});
}
