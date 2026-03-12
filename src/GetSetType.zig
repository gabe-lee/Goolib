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
const math = std.math;
const Root = @import("./_root.zig");
const Types = Root.Types;
const Cast = Root.Cast;
const Assert = Root.Assert;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Common = Root.CommonTypes;
const Utils = Root.Utils;

const InterfaceSignature = Types.InterfaceSignature;
const ConstDeclDefinition = Types.ConstDeclDefinition;
const StructFieldDefinition = Types.StructFieldDefinition;
const NamedFuncDefinition = Types.NamedFuncDefinition;
const Growth = Common.GrowthModel;
const ErrorBehavior = Common.ErrorBehavior;
const AssertBehavior = Common.AssertBehavior;
const SourceLocation = std.builtin.SourceLocation;
const Alloc = Utils.Alloc;
const AllocClearOld = Alloc.ClearOldMode;
const AllocInitNew = Alloc.InitNew;

const GetSetIndexedDecls = [_]ConstDeclDefinition{
    ConstDeclDefinition{
        .name = "ELEM",
        .T = type,
        .needed_val = null,
    },
    ConstDeclDefinition{
        .name = "INDEX",
        .T = type,
        .needed_val = null,
    },
};
const GetSetDecls = [_]ConstDeclDefinition{
    ConstDeclDefinition{
        .name = "ELEM",
        .T = type,
        .needed_val = null,
    },
};

fn sig__self_idx__val(comptime SELF: type) type {
    return fn (SELF, @field(SELF, "INDEX")) @field(SELF, "ELEM");
}
fn sig__self_idx_val__void(comptime SELF: type) type {
    return fn (SELF, @field(SELF, "INDEX"), @field(SELF, "ELEM")) void;
}
fn sig__selfptr_idx_val__void(comptime SELF: type) type {
    return fn (*SELF, @field(SELF, "INDEX"), @field(SELF, "ELEM")) void;
}

fn sig__self__val(comptime SELF: type) type {
    return fn (SELF) @field(SELF, "ELEM");
}
fn sig__selfptr_val__void(comptime SELF: type) type {
    return fn (*SELF, @field(SELF, "ELEM")) void;
}
fn sig__self_val__void(comptime SELF: type) type {
    return fn (SELF, @field(SELF, "ELEM")) void;
}
fn sig__self__len(comptime SELF: type) type {
    return fn (SELF) @field(SELF, "INDEX");
}

const GetSetIndexedIndirectFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self_idx__val,
    },
    NamedFuncDefinition{
        .name = "set",
        .signature_builder = sig__self_idx_val__void,
    },
    NamedFuncDefinition{
        .name = "len",
        .signature_builder = sig__self__len,
    },
};
const GetSetIndexedDirectFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self_idx__val,
    },
    NamedFuncDefinition{
        .name = "set",
        .signature_builder = sig__selfptr_idx_val__void,
    },
    NamedFuncDefinition{
        .name = "len",
        .signature_builder = sig__self__len,
    },
};

const GetSetDirectFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self__val,
    },
    NamedFuncDefinition{
        .name = "set",
        .signature_builder = sig__selfptr_val__void,
    },
};
const GetSetIndirectFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self__val,
    },
    NamedFuncDefinition{
        .name = "set",
        .signature_builder = sig__self_val__void,
    },
};

const GetIndexedFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self_idx__val,
    },
    NamedFuncDefinition{
        .name = "len",
        .signature_builder = sig__self__len,
    },
};

const GetFunctions = [_]NamedFuncDefinition{
    NamedFuncDefinition{
        .name = "get",
        .signature_builder = sig__self__val,
    },
};

const GetSetIndexedFields = [_]StructFieldDefinition{};
const GetSetFields = [_]StructFieldDefinition{};

const IndexedIndirectInterface = Types.InterfaceSignature{
    .interface_name = "GetSetIndexedIndirect",
    .const_decls = &GetSetIndexedDecls,
    .functions = &GetSetIndexedIndirectFunctions,
    .struct_fields = &GetSetIndexedFields,
};
const IndexedDirectInterface = Types.InterfaceSignature{
    .interface_name = "GetSetIndexedDirect",
    .const_decls = &GetSetIndexedDecls,
    .functions = &GetSetIndexedDirectFunctions,
    .struct_fields = &GetSetIndexedFields,
};
const ScalarDirectInterface = Types.InterfaceSignature{
    .interface_name = "GetSetDirect",
    .const_decls = &GetSetDecls,
    .functions = &GetSetDirectFunctions,
    .struct_fields = &GetSetFields,
};
const ScalarIndirectInterface = Types.InterfaceSignature{
    .interface_name = "GetSetIndirect",
    .const_decls = &GetSetDecls,
    .functions = &GetSetIndirectFunctions,
    .struct_fields = &GetSetFields,
};
const ScalarGetOnlyInterface = Types.InterfaceSignature{
    .interface_name = "GetOnly",
    .const_decls = &GetSetDecls,
    .functions = &GetFunctions,
    .struct_fields = &GetSetFields,
};
const IndexedGetOnlyInterface = Types.InterfaceSignature{
    .interface_name = "GetOnly",
    .const_decls = &GetSetDecls,
    .functions = &GetIndexedFunctions,
    .struct_fields = &GetSetFields,
};

pub fn assert_type_has_indexed_indirect_get_and_set(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    IndexedIndirectInterface.assert_type_fulfills(T, src);
}
pub fn assert_type_has_indexed_direct_get_and_set(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    IndexedDirectInterface.assert_type_fulfills(T, src);
}
pub fn assert_type_has_direct_get_and_set(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    ScalarDirectInterface.assert_type_fulfills(T, src);
}
pub fn assert_type_has_indirect_get_and_set(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    ScalarIndirectInterface.assert_type_fulfills(T, src);
}
pub fn assert_type_has_get_only(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    ScalarGetOnlyInterface.assert_type_fulfills(T, src);
}
pub fn assert_type_has_indexed_get_only(comptime T: type, comptime src: ?std.builtin.SourceLocation) void {
    IndexedGetOnlyInterface.assert_type_fulfills(T, src);
}
pub fn assert_getset_has_elem_type(comptime T: type, comptime ELEM: type, comptime src: ?std.builtin.SourceLocation) void {
    Assert.assert_with_reason(Types.type_has_decl_with_type_and_val(T, "ELEM", type, ELEM), src, "type `{s}` does not have necessary decl `pub const ELEM = {s};`", .{ @typeName(T), @typeName(ELEM) });
}
pub fn assert_getset_has_elem_class(comptime T: type, comptime TYPE_ID: Types.TypeId, comptime src: ?std.builtin.SourceLocation) void {
    Assert.assert_with_reason(Types.type_has_decl_with_type(T, "ELEM", type), src, "type `{s}` does not have necessary decl `pub const ELEM = <type>;`", .{@typeName(T)});
    Assert.assert_with_reason(@typeInfo(@field(T, "ELEM")) == TYPE_ID, src, "type `{s}.ELEM` is not the type category `{s}`", .{ @typeName(T), @tagName(TYPE_ID) });
}
pub fn assert_getset_has_elem_class_with_child_type(comptime T: type, comptime TYPE_ID: Types.TypeId, comptime CHILD_TYPE: type, comptime src: ?std.builtin.SourceLocation) void {
    Assert.assert_with_reason(Types.type_has_decl_with_type(T, "ELEM", type), src, "type `{s}` does not have necessary decl `pub const ELEM = <type>;`", .{@typeName(T)});
    Assert.assert_with_reason(@typeInfo(@field(T, "ELEM")) == TYPE_ID, src, "type `{s}.ELEM` is not the type category `{s}`", .{ @typeName(T), @tagName(TYPE_ID) });
    const CHILD: type = switch (@typeInfo(@field(T, "ELEM"))) {
        .pointer => |INFO| INFO.child,
        .array => |INFO| INFO.child,
        .vector => |INFO| INFO.child,
        else => Assert.assert_unreachable(src, "type `{s}` has no child type", .{@typeName(T)}),
    };
    Assert.assert_with_reason(CHILD == CHILD_TYPE, src, "type `{s}` has wrong child type `{s}`, need `{s}`", .{ @typeName(T), @typeName(CHILD), @typeName(CHILD_TYPE) });
}
pub fn assert_getset_has_elem_class_with_child_class(comptime T: type, comptime TYPE_ID: Types.TypeId, comptime CHILD_ID: Types.TypeId, comptime src: ?std.builtin.SourceLocation) void {
    Assert.assert_with_reason(Types.type_has_decl_with_type(T, "ELEM", type), src, "type `{s}` does not have necessary decl `pub const ELEM = <type>;`", .{@typeName(T)});
    Assert.assert_with_reason(@typeInfo(@field(T, "ELEM")) == TYPE_ID, src, "type `{s}.ELEM` is not the type category `{s}`", .{ @typeName(T), @tagName(TYPE_ID) });
    const CHILD: type = switch (@typeInfo(@field(T, "ELEM"))) {
        .pointer => |INFO| INFO.child,
        .array => |INFO| INFO.child,
        .vector => |INFO| INFO.child,
        else => Assert.assert_unreachable(src, "type `{s}` has no child type", .{@typeName(T)}),
    };
    Assert.assert_with_reason(@typeInfo(CHILD) == CHILD_ID, src, "type `{s}` has wrong child class `{s}`, need `{s}`", .{ @typeName(T), @tagName(@typeInfo(CHILD)), @tagName(CHILD_ID) });
}

pub fn FuncBodyGet(comptime T: type, comptime BODY: fn () T) type {
    return struct {
        const FUNC = BODY;

        pub const ELEM = T;

        pub fn get(_: @This()) T {
            return FUNC();
        }
    };
}
pub fn FuncBodyGetSet(comptime T: type, comptime GET_BODY: fn () T, comptime SET_BODY: fn (val: T) void) type {
    return struct {
        const GET_FUNC = GET_BODY;
        const SET_FUNC = SET_BODY;

        pub const ELEM = T;

        pub fn get(_: @This()) T {
            return GET_FUNC();
        }
        pub fn set(_: @This(), val: T) void {
            SET_FUNC(val);
        }
    };
}
pub fn FuncBodyGetWithUserdata(comptime T: type, comptime USERDATA: type, comptime BODY: fn (USERDATA) T) type {
    return struct {
        const FUNC = BODY;
        pub const ELEM = T;

        userdata: USERDATA,

        pub fn get(self: @This()) T {
            return FUNC(self.userdata);
        }
    };
}
pub fn FuncBodyGetSetWithUserdata(comptime T: type, comptime USERDATA: type, comptime GET_BODY: fn (USERDATA) T, comptime SET_BODY: fn (USERDATA, T) void) type {
    return struct {
        const GET_FUNC = GET_BODY;
        const SET_FUNC = SET_BODY;
        pub const ELEM = T;

        userdata: USERDATA,

        pub fn get(self: @This()) T {
            return GET_FUNC(self.userdata);
        }
        pub fn set(self: @This(), val: T) void {
            SET_FUNC(self.userdata, val);
        }
    };
}
pub fn FuncPtrGet(comptime T: type) type {
    return struct {
        pub const ELEM = T;

        func: *const fn () T,

        pub fn get(self: @This()) T {
            return self.func();
        }
    };
}
pub fn FuncPtrGetSet(comptime T: type) type {
    return struct {
        pub const ELEM = T;

        get_func: *const fn () T,
        set_func: *const fn (val: T) void,

        pub fn get(self: @This()) T {
            return self.get_func();
        }
        pub fn set(self: @This(), val: T) void {
            self.set_func(val);
        }
    };
}
pub fn FuncPtrGetWithUserdata(comptime T: type, comptime USERDATA: type) type {
    return struct {
        pub const ELEM = T;

        func: *const fn (userdata: USERDATA) T,
        userdata: USERDATA,

        pub fn get(self: @This()) T {
            return self.func(self.userdata);
        }
    };
}
pub fn FuncPtrGetSetWithUserdata(comptime T: type, comptime USERDATA: type) type {
    return struct {
        pub const ELEM = T;

        get_func: *const fn (userdata: USERDATA) T,
        set_func: *const fn (userdata: USERDATA, val: T) void,
        userdata: USERDATA,

        pub fn get(self: @This()) T {
            return self.get_func(self.userdata);
        }
        pub fn set(self: @This(), val: T) void {
            self.set_func(self.userdata, val);
        }
    };
}

/// `set` is a no-op here, but if you need a constant that fulfills a get-set...
pub fn ConstGetSetArray(comptime val: anytype) type {
    const T = @TypeOf(val);
    const K = Types.KindInfo.get_kind_info(T);
    Assert.assert_with_reason(K.is_array_or_vector(), @src(), "type of 'val' is not an array or vector type, got `{s}`", .{@typeName(T)});
    const LEN = K.get_len();
    return struct {
        pub const VAL: T = val;
        pub const ELEM = T;
        pub const INDEX = Types.SmallestUnsignedIntThatCanHoldValue(LEN);

        pub fn get(self: @This(), index: INDEX) T {
            return self.arr[index];
        }
        pub fn set(_: *@This(), _: INDEX, _: T) void {
            return;
        }
        pub fn len(_: @This()) INDEX {
            return LEN;
        }
    };
}
pub fn ConstGetArray(comptime val: anytype) type {
    const T = @TypeOf(val);
    const K = Types.KindInfo.get_kind_info(T);
    Assert.assert_with_reason(K.is_array_or_vector(), @src(), "type of 'val' is not an array or vector type, got `{s}`", .{@typeName(T)});
    const LEN = K.get_len();
    return struct {
        pub const VAL: T = val;
        pub const ELEM = T;
        pub const INDEX = Types.SmallestUnsignedIntThatCanHoldValue(LEN);

        pub fn get(_: @This(), index: INDEX) T {
            return VAL[index];
        }
        pub fn len(_: @This()) INDEX {
            return LEN;
        }
    };
}

/// `set` is a no-op here, but if you need a constant that fulfills a get-set...
pub fn ConstGetSet(comptime val: anytype) type {
    const T = @TypeOf(val);
    const K = Types.KindInfo.get_kind_info(T);
    Assert.assert_with_reason(K.is_array_or_vector(), @src(), "type of 'val' is not an array or vector type, got `{s}`", .{@typeName(T)});
    const LEN = K.get_len();
    return struct {
        pub const VAL: T = val;
        pub const ELEM = T;
        pub const INDEX = Types.SmallestUnsignedIntThatCanHoldValue(LEN);

        pub fn get(_: @This()) T {
            return VAL;
        }
        pub fn set(_: *@This(), _: T) void {
            return;
        }
    };
}
pub fn ConstGet(comptime val: anytype) type {
    const T = @TypeOf(val);
    return struct {
        pub const VAL: T = val;
        pub const ELEM = T;

        pub fn get(_: @This()) T {
            return VAL;
        }
    };
}

pub fn SimpleGetSetArray(comptime T: type, comptime N: comptime_int) type {
    return extern struct {
        arr: [N]T = undefined,

        pub const ELEM = T;
        pub const INDEX = Types.SmallestUnsignedIntThatCanHoldValue(N);

        pub fn get(self: @This(), index: INDEX) T {
            return self.arr[index];
        }
        pub fn set(self: *@This(), index: INDEX, val: T) void {
            self.arr[index] = val;
        }
        pub fn len(_: @This()) INDEX {
            return N;
        }
    };
}
pub fn SimpleGetSetSlice(comptime T: type, comptime INDEX_TYPE: type) type {
    return extern struct {
        ptr: [*]T = Utils.invalid_ptr_many(T),
        _len: INDEX = 0,

        pub const ELEM = T;
        pub const INDEX = INDEX_TYPE;

        pub fn to_slice(self: @This()) []T {
            return self.ptr[0..self._len];
        }
        pub fn from_slice(slice: []T) @This() {
            return @This(){
                .ptr = slice.ptr,
                ._len = @intCast(slice.len),
            };
        }

        pub fn get(self: @This(), index: INDEX) T {
            return self.ptr[index];
        }
        pub fn set(self: @This(), index: INDEX, val: T) void {
            self.ptr[index] = val;
        }
        pub fn len(self: @This()) INDEX {
            return self._len;
        }
    };
}
pub fn SimpleGetSetDirect(comptime T: type) type {
    return extern struct {
        val: T = undefined,

        pub const ELEM = T;

        pub fn get(self: @This()) T {
            return self.val;
        }
        pub fn set(self: *@This(), val: T) void {
            self.val = val;
        }
    };
}
pub fn SimpleGetSetIndirect(comptime T: type) type {
    return extern struct {
        val: *T = undefined,

        pub const ELEM = T;

        pub fn get(self: @This()) T {
            return self.val.*;
        }
        pub fn set(self: @This(), val: T) void {
            self.val.* = val;
        }
    };
}

pub const GetSetKind = enum(u8) {
    GET_ONLY,
    GET_AND_SET,
};

pub const DirectIndirectKind = enum(u8) {
    DIRECT,
    INDIRECT,
};

pub const TypeKind = enum(u8) {
    ANY,
    KIND,
    EXACT_TYPE,
};

pub const ElemRequirement = union(TypeKind) {
    ANY,
    KIND: Types.Kind,
    EXACT_TYPE: type,

    pub fn kind(comptime kind_: Types.Kind) ElemRequirement {
        return ElemRequirement{ .KIND = kind_ };
    }
    pub fn exact_type(comptime T: type) ElemRequirement {
        return ElemRequirement{ .EXACT_TYPE = T };
    }

    pub fn with_type(comptime self: ElemRequirement, comptime TYPE: type) TypeWithElemRequirements {
        return TypeWithElemRequirements{
            .TYPE = TYPE,
            .REQ = self,
        };
    }
};

pub const TypeWithElemRequirements = struct {
    TYPE: type,
    REQ: ElemRequirement,

    pub inline fn assert_valid(comptime self: TypeWithElemRequirements, comptime src: ?std.builtin.SourceLocation) void {
        switch (self.REQ) {
            .ANY => {},
            .KIND => |K| {
                K.assert_type_is_same_kind(@field(self.TYPE, "ELEM"), src);
            },
            .EXACT_TYPE => |T| {
                Assert.assert_with_reason(T == @field(self.TYPE, "ELEM"), src, "type `{s}` is not required type `{s}`", .{ @typeName(@field(self.TYPE, "ELEM")), @typeName(T) });
            },
        }
    }
};

pub const GetOrGetSetDirect = union(GetSetKind) {
    GET_ONLY: type,
    GET_AND_SET: type,

    pub fn get_only(comptime T: type) GetOrGetSetDirect {
        return GetOrGetSetDirect{ .GET_ONLY = T };
    }
    pub fn get_and_set(comptime T: type) GetOrGetSetDirect {
        return GetOrGetSetDirect{ .GET_AND_SET = T };
    }

    pub fn with_requirements(comptime self: GetOrGetSetDirect, comptime req: ElemRequirement) GetOrGetSetDirect_WithReq {
        switch (self) {
            .GET_AND_SET => |T| {
                return GetOrGetSetDirect_WithReq{ .GET_AND_SET = req.with_type(T) };
            },
            .GET_ONLY => |T| {
                return GetOrGetSetDirect_WithReq{ .GET_ONLY = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetOrGetSetDirect) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TYPE| {
                return TYPE;
            },
        }
    }
};
pub const GetOrGetSetIndirect = union(GetSetKind) {
    GET_ONLY: type,
    GET_AND_SET: type,

    pub fn get_only(comptime T: type) GetOrGetSetIndirect {
        return GetOrGetSetIndirect{ .GET_ONLY = T };
    }
    pub fn get_and_set(comptime T: type) GetOrGetSetIndirect {
        return GetOrGetSetIndirect{ .GET_AND_SET = T };
    }

    pub fn with_requirements(comptime self: GetOrGetSetIndirect, comptime req: ElemRequirement) GetOrGetSetIndirect_WithReq {
        switch (self) {
            .GET_AND_SET => |T| {
                return GetOrGetSetIndirect_WithReq{ .GET_AND_SET = req.with_type(T) };
            },
            .GET_ONLY => |T| {
                return GetOrGetSetIndirect_WithReq{ .GET_ONLY = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetOrGetSetIndirect) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TYPE| {
                return TYPE;
            },
        }
    }
};
pub const GetOrGetSetDirectIndexed = union(GetSetKind) {
    GET_ONLY: type,
    GET_AND_SET: type,

    pub fn get_only(comptime T: type) GetOrGetSetDirectIndexed {
        return GetOrGetSetDirectIndexed{ .GET_ONLY = T };
    }
    pub fn get_and_set(comptime T: type) GetOrGetSetDirectIndexed {
        return GetOrGetSetDirectIndexed{ .GET_AND_SET = T };
    }

    pub fn with_requirements(comptime self: GetOrGetSetDirectIndexed, comptime req: ElemRequirement) GetOrGetSetDirectIndexed_WithReq {
        switch (self) {
            .GET_AND_SET => |T| {
                return GetOrGetSetDirectIndexed_WithReq{ .GET_AND_SET = req.with_type(T) };
            },
            .GET_ONLY => |T| {
                return GetOrGetSetDirectIndexed_WithReq{ .GET_ONLY = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetOrGetSetDirectIndexed) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TYPE| {
                return TYPE;
            },
        }
    }
};
pub const GetOrGetSetIndirectIndexed = union(GetSetKind) {
    GET_ONLY: type,
    GET_AND_SET: type,

    pub fn get_only(comptime T: type) GetOrGetSetIndirectIndexed {
        return GetOrGetSetIndirectIndexed{ .GET_ONLY = T };
    }
    pub fn get_and_set(comptime T: type) GetOrGetSetIndirectIndexed {
        return GetOrGetSetIndirectIndexed{ .GET_AND_SET = T };
    }

    pub fn with_requirements(comptime self: GetOrGetSetIndirectIndexed, comptime req: ElemRequirement) GetOrGetSetIndirectIndexed_WithReq {
        switch (self) {
            .GET_AND_SET => |T| {
                return GetOrGetSetIndirectIndexed_WithReq{ .GET_AND_SET = req.with_type(T) };
            },
            .GET_ONLY => |T| {
                return GetOrGetSetIndirectIndexed_WithReq{ .GET_ONLY = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetOrGetSetIndirectIndexed) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TYPE| {
                return TYPE;
            },
        }
    }
};

pub const GetSetIndirectOrDirectIndexed = union(DirectIndirectKind) {
    DIRECT: type,
    INDIRECT: type,

    pub fn direct(comptime T: type) GetSetIndirectOrDirectIndexed {
        return GetSetIndirectOrDirectIndexed{ .DIRECT = T };
    }
    pub fn indirect(comptime T: type) GetSetIndirectOrDirectIndexed {
        return GetSetIndirectOrDirectIndexed{ .INDIRECT = T };
    }

    pub fn with_requirements(comptime self: GetSetIndirectOrDirectIndexed, comptime req: ElemRequirement) GetSetDirectOrIndirectIndexed_WithReq {
        switch (self) {
            .DIRECT => |T| {
                return GetSetDirectOrIndirectIndexed_WithReq{ .DIRECT = req.with_type(T) };
            },
            .INDIRECT => |T| {
                return GetSetDirectOrIndirectIndexed_WithReq{ .INDIRECT = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetSetIndirectOrDirectIndexed) type {
        switch (self) {
            .DIRECT, .INDIRECT => |TR| {
                return TR.TYPE;
            },
        }
    }
};

pub const GetSetIndirectOrDirect = union(DirectIndirectKind) {
    DIRECT: type,
    INDIRECT: type,

    pub fn direct(comptime T: type) GetSetIndirectOrDirect {
        return GetSetIndirectOrDirect{ .DIRECT = T };
    }
    pub fn indirect(comptime T: type) GetSetIndirectOrDirect {
        return GetSetIndirectOrDirect{ .INDIRECT = T };
    }

    pub fn with_requirements(comptime self: GetSetIndirectOrDirect, comptime req: ElemRequirement) GetSetDirectOrIndirectIndexed_WithReq {
        switch (self) {
            .DIRECT => |T| {
                return GetSetDirectOrIndirectIndexed_WithReq{ .DIRECT = req.with_type(T) };
            },
            .INDIRECT => |T| {
                return GetSetDirectOrIndirectIndexed_WithReq{ .INDIRECT = req.with_type(T) };
            },
        }
    }
    pub fn unrwap_type(comptime self: GetSetIndirectOrDirect) type {
        switch (self) {
            .DIRECT, .INDIRECT => |TR| {
                return TR.TYPE;
            },
        }
    }
};
pub const GetOrGetSetDirect_WithReq = union(GetSetKind) {
    GET_ONLY: TypeWithElemRequirements,
    GET_AND_SET: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetOrGetSetDirect_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .GET_ONLY => |TR| {
                assert_type_has_get_only(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .GET_AND_SET => |TR| {
                assert_type_has_direct_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetOrGetSetDirect_WithReq) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TR| {
                return TR.TYPE;
            },
        }
    }
};
pub const GetOrGetSetIndirect_WithReq = union(GetSetKind) {
    GET_ONLY: TypeWithElemRequirements,
    GET_AND_SET: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetOrGetSetIndirect_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .GET_ONLY => |TR| {
                assert_type_has_get_only(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .GET_AND_SET => |TR| {
                assert_type_has_indirect_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetOrGetSetIndirect_WithReq) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TR| {
                return TR.TYPE;
            },
        }
    }
};
pub const GetOrGetSetDirectIndexed_WithReq = union(GetSetKind) {
    GET_ONLY: TypeWithElemRequirements,
    GET_AND_SET: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetOrGetSetDirectIndexed_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .GET_ONLY => |TR| {
                assert_type_has_indexed_get_only(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .GET_AND_SET => |TR| {
                assert_type_has_indexed_direct_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetOrGetSetDirectIndexed_WithReq) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TR| {
                return TR.TYPE;
            },
        }
    }
};

pub const GetOrGetSetIndirectIndexed_WithReq = union(GetSetKind) {
    GET_ONLY: TypeWithElemRequirements,
    GET_AND_SET: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetOrGetSetIndirectIndexed_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .GET_ONLY => |TR| {
                assert_type_has_indexed_get_only(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .GET_AND_SET => |TR| {
                assert_type_has_indexed_indirect_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetOrGetSetIndirectIndexed_WithReq) type {
        switch (self) {
            .GET_ONLY, .GET_AND_SET => |TR| {
                return TR.TYPE;
            },
        }
    }
};

pub const GetSetDirectOrIndirectIndexed_WithReq = union(DirectIndirectKind) {
    DIRECT: TypeWithElemRequirements,
    INDIRECT: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetSetDirectOrIndirectIndexed_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .DIRECT => |TR| {
                assert_type_has_indexed_direct_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .INDIRECT => |TR| {
                assert_type_has_indexed_indirect_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetSetDirectOrIndirectIndexed_WithReq) type {
        switch (self) {
            .DIRECT, .INDIRECT => |TR| {
                return TR.TYPE;
            },
        }
    }
};
pub const GetSetDirectOrIndirect_WithReq = union(DirectIndirectKind) {
    DIRECT: TypeWithElemRequirements,
    INDIRECT: TypeWithElemRequirements,

    pub inline fn assert_valid(comptime self: GetSetDirectOrIndirect_WithReq, comptime src: ?std.builtin.SourceLocation) void {
        switch (self) {
            .DIRECT => |TR| {
                assert_type_has_direct_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
            .INDIRECT => |TR| {
                assert_type_has_indirect_get_and_set(TR.TYPE, src);
                TR.assert_valid(src);
            },
        }
    }

    pub fn unrwap_type(comptime self: GetSetDirectOrIndirect_WithReq) type {
        switch (self) {
            .DIRECT, .INDIRECT => |TR| {
                return TR.TYPE;
            },
        }
    }
};

test "GetSet interface" {
    const GetSetArrU8 = SimpleGetSetArray(u8, 8);
    const GetSetSliceU8 = SimpleGetSetSlice(u8, usize);
    const GetSetU8 = SimpleGetSetDirect(u8);
    const GetSetU8Indirect = SimpleGetSetIndirect(u8);
    assert_type_has_indexed_indirect_get_and_set(GetSetSliceU8, @src());
    assert_type_has_indexed_direct_get_and_set(GetSetArrU8, @src());
    assert_type_has_direct_get_and_set(GetSetU8, @src());
    assert_type_has_indirect_get_and_set(GetSetU8Indirect, @src());
    assert_type_has_get_only(GetSetU8, @src());
    assert_type_has_get_only(GetSetU8Indirect, @src());
    assert_type_has_indexed_get_only(GetSetSliceU8, @src());
    assert_type_has_indexed_get_only(GetSetArrU8, @src());
}
