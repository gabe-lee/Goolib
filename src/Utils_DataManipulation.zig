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
const build = @import("builtin");
const builtin = std.builtin;
const SourceLocation = builtin.SourceLocation;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;
// const pq = std.PriorityQueue;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
// const CompareFnUserdata = Utils.Compare.CompareFnUserdata;
// const CompareFn = Utils.Compare.CompareFn;

pub const SearchOrder = enum {
    SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER,
    SEARCH_PARAMS_UNORDERED,
};

const DEBUG = std.debug.print;

pub fn AppendFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, val: ELEM_TYPE, alloc: Allocator) DATA_STRUCTURE;
}
pub fn DequeueFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ELEM_TYPE };
}
pub fn DequeueOrNullFunc(comptime DATA_STRUCTURE: type, comptime ELEM_TYPE: type) type {
    return fn (data: DATA_STRUCTURE) struct { DATA_STRUCTURE, ?ELEM_TYPE };
}

pub const QUICKSORT_TO_INSERTION_THRESHOLD = 16;

pub const BinarySearchOneFound = enum(u8) {
    NO_DATA_ITEMS,
    NO_SEARCH_ITEMS,
    FOUND,
    NOT_FOUND_ORDERED_WITHIN_RANGE,
    NOT_FOUND_ORDERED_AFTER_GIVEN_RANGE,
    NOT_FOUND_ORDERED_BEFORE_GIVEN_RANGE,
};
pub const LinearSearchOneFound = enum(u8) {
    NO_DATA_ITEMS,
    NO_SEARCH_ITEMS,
    FOUND,
    NOT_FOUND,
};

const SearchEqualityMode = enum(u8) {
    ORDER_EQUAL,
    EXACTLY_EQUAL,
};

pub const ResultsListLimit = enum(u8) {
    SIZE_OF_RESULTS_LIST,
    UNLIMITED_ASSUME_CAPACITY,
    UNLIMITED_REALLOC,
};

pub const ResultsIncludeMode = enum(u8) {
    IDX_ONLY,
    IDX_AND_SEARCH_VAL,
};

pub const SortOrder = enum(u8) {
    NORMAL,
    REVERSE,
};

const BuilderValidation = if (Assert.should_assert()) enum(u8) {
    UNINITIALIZED,
    DEFAULT,
    SET_CUSTOM,
    INVALID,

    pub fn assert_valid(comptime self: @This(), comptime category: []const u8, comptime src: std.builtin.SourceLocation) void {
        assert_with_reason(self == .DEFAULT or self == .SET_CUSTOM, src, "SearchPackage settings category `{s}` was never initialized or was invalidated by an later setting (`{s}`)", .{ category, @tagName(self) });
    }
} else enum(u0) {
    _NONE = 0,
    pub fn assert_valid(comptime self: @This(), comptime category: []const u8, comptime src: std.builtin.SourceLocation) void {
        _ = self;
        _ = category;
        _ = src;
    }
    const UNINITIALIZED = @This()._NONE;
    const DEFAULT = @This()._NONE;
    const SET_CUSTOM = @This()._NONE;
    const INVALID = @This()._NONE;
};

pub fn ResultItem(comptime DATA_IDX: type, comptime SEARCH_ELEM: type, comptime INCLUDE: ResultsIncludeMode) type {
    return struct {
        data_idx: DATA_IDX = undefined,
        search_val: if (INCLUDE == .IDX_AND_SEARCH_VAL) SEARCH_ELEM else void = if (INCLUDE == .IDX_AND_SEARCH_VAL) undefined else void{},

        pub fn new(data_idx: DATA_IDX, search_val: SEARCH_ELEM) @This() {
            var this = @This(){
                .data_idx = data_idx,
            };
            if (INCLUDE == .IDX_AND_SEARCH_VAL) {
                this.search_val = search_val;
            }
            return this;
        }
    };
}

pub const ManySameOrderExpectation = enum(u8) {
    /// Same as `.USE_DUTCH_FLAG_3_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_LIKELY,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_LIKELY`
    USE_DUTCH_FLAG_3_WAY_PARTITION,
    /// Same as `.USE_HOARE_2_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE`
    USE_HOARE_2_WAY_PARTITION,
};

pub const FieldTyper = fn (comptime field: []const u8) type;
pub fn GetFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, userdata: USERDATA_TYPE) ELEM_TYPE;
}
pub fn GetPtrFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, userdata: USERDATA_TYPE) *ELEM_TYPE;
}
pub fn GetConstPtrFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, userdata: USERDATA_TYPE) *const ELEM_TYPE;
}
pub fn GetFieldFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime FIELD_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, comptime field: []const u8, idx: IDX_TYPE, userdata: USERDATA_TYPE) FIELD_TYPE;
}
pub fn GetFieldPtrFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime FIELD_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, comptime field: []const u8, idx: IDX_TYPE, userdata: USERDATA_TYPE) *FIELD_TYPE;
}
pub fn SetFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, val: ELEM_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn SetFieldFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime FIELD_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, comptime field: []const u8, idx: IDX_TYPE, val: FIELD_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn SwapFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx_a: IDX_TYPE, idx_b: IDX_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn CompareFn(comptime TA: type, comptime TB: type, comptime USERDATA: type) type {
    return fn (a: TA, b: TB, userdata: USERDATA) bool;
}

pub const DataManipulationPackage = struct {
    DATA: type = undefined,
    ELEM: type = undefined,
    IDX: type = undefined,
    USERDATA: type = void,

    pub fn WithFunctions(comptime DEF_: DataManipulationPackage) type {
        return struct {
            pub const DATA_ = DEF_.DATA;
            pub const ELEM_ = DEF_.ELEM;
            pub const IDX_ = DEF_.IDX;
            pub const USERDATA_ = DEF_.USERDATA;

            pub const Getter_ = GetFn(DATA_, IDX_, ELEM_, USERDATA_);
            pub const PtrGetter_ = GetPtrFn(DATA_, IDX_, ELEM_, USERDATA_);
            pub const ConstPtrGetter_ = GetConstPtrFn(DATA_, IDX_, ELEM_, USERDATA_);
            pub const FieldGetter_ = GetFieldFn(DATA_, IDX_, ELEM_, TYPE_FOR_FIELD, USERDATA_);
            pub const FieldPtrGetter_ = GetFieldPtrFn(DATA_, IDX_, ELEM_, TYPE_FOR_FIELD, USERDATA_);
            pub const Setter_ = SetFn(DATA_, IDX_, ELEM_, USERDATA_);
            pub const FieldSetter_ = SetFieldFn(DATA_, IDX_, ELEM_, TYPE_FOR_FIELD, USERDATA_);
            pub const Swapper_ = SwapFn(DATA_, IDX_, USERDATA_);
            pub const Comparer_ = CompareFn(ELEM_, ELEM_, USERDATA_);

            pub const FieldInfo_ = Types.extract_struct_union_or_dummy_field_info(ELEM_);
            const TYPE_FOR_FIELD: fn (comptime INFO: @TypeOf(FieldInfo_), comptime field: []const u8) type = FieldInfo_.type_for_field;
            pub fn TypeForField(comptime field: []const u8) type {
                return FieldInfo_.type_for_field(field);
            }
            const FieldInfoAsStructInfo_: Types.StructInfo(FieldInfo_.field_names.len) = FieldInfo_.as_struct_info();
            const FieldGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = Utils.Mem.get_field_concrete_proto(DATA_, ELEM_, NAME, FT.*, .VAL, IDX_);
                    FT.* = PROTO.GetFieldFn;
                    ATTR.@"align" = @alignOf(PROTO.GetFieldFn);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = &PROTO.get_field;
                }
                break :make getters;
            };
            pub const FieldGetters = FieldGettersStructInfo.build_struct_type();
            const FieldPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = Utils.Mem.get_field_concrete_proto(DATA_, ELEM_, NAME, FT.*, .PTR, IDX_);
                    FT.* = PROTO.GetFieldFn;
                    ATTR.@"align" = @alignOf(PROTO.GetFieldFn);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = &PROTO.get_field;
                }
                break :make getters;
            };
            pub const FieldPtrGetters = FieldPtrGettersStructInfo.build_struct_type();
            const FieldConstPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = Utils.Mem.get_field_concrete_proto(DATA_, ELEM_, NAME, FT.*, .CONST_PTR, IDX_);
                    FT.* = PROTO.GetFieldFn;
                    ATTR.@"align" = @alignOf(PROTO.GetFieldFn);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = &PROTO.get_field;
                }
                break :make getters;
            };
            pub const FieldConstPtrGetters = FieldPtrGettersStructInfo.build_struct_type();
            const FieldSettersStructInfo = make: {
                const setters = FieldInfoAsStructInfo_;
                for (setters.field_names, setters.field_types, setters.field_attrs) |NAME, *TYPE, *ATTR| {
                    const PROTO = Utils.Mem.set_field_concrete_proto(DATA_, ELEM_, NAME, TYPE.*, .VAL, IDX_);
                    TYPE.* = PROTO.SetFieldFn;
                    ATTR.@"align" = @alignOf(PROTO.SetFieldFn);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = &PROTO.set_field;
                }
                break :make setters;
            };
            pub const FieldSetters = FieldSettersStructInfo.build_struct_type();

            GET: Getter_ = default_get,
            GET_PTR: PtrGetter_ = default_get_ptr,
            GET_CONST_PTR: ConstPtrGetter_ = default_get_const_ptr,
            GET_FIELD: FieldGetters = .{},
            GET_FIELD_PTR: FieldPtrGetters = .{},
            GET_FIELD_CONST_PTR: FieldConstPtrGetters = .{},
            SET: Setter_ = default_set,
            SET_FIELD: FieldSetters = .{},
            SWAP: Swapper_ = default_swap,
            GREATER_THAN: Comparer_ = default_greater_than,
            GREATER_THAN_OR_EQUAL: Comparer_ = default_greater_than_or_equal,
            LESS_THAN: Comparer_ = default_less_than,
            LESS_THAN_OR_EQUAL: Comparer_ = default_less_than_or_equal,
            ORDER_EQUALS: Comparer_ = default_equals,
            EXACT_EQUALS: Comparer_ = default_equals,

            fn default_get(data: DATA_, idx: IDX_, _: USERDATA_) ELEM_ {
                return Utils.Mem.get(ELEM_, data, idx);
            }
            fn default_get_ptr(data: DATA_, idx: IDX_, _: USERDATA_) *ELEM_ {
                return Utils.Mem.get_ptr(ELEM_, data, idx);
            }
            fn default_get_const_ptr(data: DATA_, idx: IDX_, _: USERDATA_) *const ELEM_ {
                return Utils.Mem.get_ptr_const(ELEM_, data, idx);
            }
            fn default_set(data: DATA_, idx: IDX_, val: ELEM_, _: USERDATA_) DATA_ {
                return Utils.Mem.set(data, idx, val);
            }
            fn default_swap(data: DATA_, idx_a: IDX_, idx_b: IDX_, _: USERDATA_) DATA_ {
                return Utils.Mem.swap(ELEM_, data, idx_a, idx_b);
            }
            fn default_greater_than(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return Utils.Compare.greater_than(val_a, val_b);
            }
            fn default_greater_than_or_equal(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return Utils.Compare.greater_than_or_equal(val_a, val_b);
            }
            fn default_less_than(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return Utils.Compare.less_than(val_a, val_b);
            }
            fn default_less_than_or_equal(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return Utils.Compare.less_than_or_equal(val_a, val_b);
            }
            fn default_equals(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return Utils.Compare.shallow_equals(val_a, val_b);
            }

            pub const CustomDataTransferFuncs = struct {
                GET: ?Getter_ = null,
                GET_PTR: ?PtrGetter_ = null,
                GET_PTR_CONST: ?ConstPtrGetter_ = null,
                SET: ?Setter_ = null,
                SWAP: ?Swapper_ = null,
            };

            pub fn with_custom_data_transfer(comptime FUNCS: @This(), comptime custom: CustomDataTransferFuncs) @This() {
                const PROTO = struct {
                    fn infer_get(data: DATA_, idx: IDX_, userdata: USERDATA_) ELEM_ {
                        if (comptime custom.GET_PTR_CONST) |get_cnst_ptr| {
                            return get_cnst_ptr(data, idx, userdata).*;
                        } else if (comptime custom.GET_PTR) |get_ptr| {
                            return get_ptr(data, idx, userdata).*;
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_get_ptr(_: DATA_, _: IDX_, _: USERDATA_) *ELEM_ {
                        unreachable;
                    }
                    fn infer_get_ptr_const(data: DATA_, idx: IDX_, userdata: USERDATA_) *const ELEM_ {
                        if (comptime custom.GET_PTR) |get_ptr| {
                            return get_ptr(data, idx, userdata).*;
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_set(data: DATA_, idx: IDX_, val: ELEM_, userdata: USERDATA_) DATA_ {
                        if (comptime custom.GET_PTR) |get_ptr| {
                            get_ptr(data, idx, userdata).* = val;
                            return data;
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_swap(data: DATA_, idx_a: IDX_, idx_b: IDX_, userdata: USERDATA_) DATA_ {
                        const GET = if (comptime custom.GET) |GET| GET else infer_get;
                        const SET = if (comptime custom.SET) |SET| SET else infer_set;
                        const tmp = GET(data, idx_b, userdata);
                        const new_data = SET(data, idx_b, GET(data, idx_a, userdata), userdata);
                        return SET(new_data, idx_a, tmp, userdata);
                    }
                };
                comptime var NEW_FUNCS = FUNCS;
                NEW_FUNCS.GET = if (custom.GET) |GET| GET else PROTO.infer_get;
                NEW_FUNCS.GET_PTR = if (custom.GET_PTR) |GET_PTR| GET_PTR else PROTO.infer_get_ptr;
                NEW_FUNCS.GET_CONST_PTR = if (custom.GET_CONST_PTR) |GET_CONST_PTR| GET_CONST_PTR else PROTO.infer_get_ptr_const;
                NEW_FUNCS.SET = if (custom.SET) |SET| SET else PROTO.infer_set;
                NEW_FUNCS.SWAP = if (custom.SWAP) |SWAP| SWAP else PROTO.infer_swap;
                return NEW_FUNCS;
            }
            pub const CustomCompareFuncs = struct {
                LESS_THAN: ?Comparer_ = null,
                LESS_THAN_OR_EQUAL: ?Comparer_ = null,
                GREATER_THAN: ?Comparer_ = null,
                GREATER_THAN_OR_EQUAL: ?Comparer_ = null,
                ORDER_EQUALS: ?Comparer_ = null,
                EXACT_EQUALS: ?Comparer_ = null,
            };
            pub fn with_custom_compare_funcs(comptime FUNCS: @This(), comptime custom: CustomCompareFuncs) @This() {
                const PROTO = struct {
                    fn infer_greater_than(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.LESS_THAN_OR_EQUAL != null) {
                            return !custom.LESS_THAN_OR_EQUAL.?(val_a, val_b, userdata);
                        } else if (comptime custom.ORDER_EQUALS != null and custom.LESS_THAN != null) {
                            return !(custom.ORDER_EQUALS.?(val_a, val_b, userdata) or custom.LESS_THAN.?(val_a, val_b, userdata));
                        } else if (comptime custom.EXACT_EQUALS != null and custom.LESS_THAN != null) {
                            return !(custom.EXACT_EQUALS.?(val_a, val_b, userdata) or custom.LESS_THAN.?(val_a, val_b, userdata));
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_greater_than_or_equal(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.LESS_THAN != null) {
                            return !custom.LESS_THAN.?(val_a, val_b, userdata);
                        } else if (comptime custom.ORDER_EQUALS != null and custom.GREATER_THAN != null) {
                            return custom.ORDER_EQUALS.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata);
                        } else if (comptime custom.EXACT_EQUALS != null and custom.GREATER_THAN != null) {
                            return custom.EXACT_EQUALS.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata);
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_less_than(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.GREATER_THAN_OR_EQUAL != null) {
                            return !custom.GREATER_THAN_OR_EQUAL.?(val_a, val_b, userdata);
                        } else if (comptime custom.ORDER_EQUALS != null and custom.GREATER_THAN != null) {
                            return !(custom.ORDER_EQUALS.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata));
                        } else if (comptime custom.EXACT_EQUALS != null and custom.GREATER_THAN != null) {
                            return !(custom.EXACT_EQUALS.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata));
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_less_than_or_equal(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.GREATER_THAN != null) {
                            return !custom.GREATER_THAN.?(val_a, val_b, userdata);
                        } else if (comptime custom.ORDER_EQUALS != null and custom.LESS_THAN != null) {
                            return custom.ORDER_EQUALS.?(val_a, val_b, userdata) or custom.LESS_THAN.?(val_a, val_b, userdata);
                        } else if (comptime custom.EXACT_EQUALS != null and custom.LESS_THAN != null) {
                            return custom.EXACT_EQUALS.?(val_a, val_b, userdata) or custom.LESS_THAN.?(val_a, val_b, userdata);
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_order_equal(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.GREATER_THAN != null and custom.LESS_THAN != null) {
                            return !(custom.LESS_THAN.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata));
                        } else if (comptime custom.EXACT_EQUALS != null) {
                            return custom.EXACT_EQUALS.?(val_a, val_b, userdata);
                        } else {
                            unreachable;
                        }
                    }
                    fn infer_exact_equal(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                        if (comptime custom.ORDER_EQUALS != null) {
                            return custom.ORDER_EQUALS.?(val_a, val_b, userdata);
                        } else if (comptime custom.LESS_THAN != null and custom.GREATER_THAN != null) {
                            return !(custom.LESS_THAN.?(val_a, val_b, userdata) or custom.GREATER_THAN.?(val_a, val_b, userdata));
                        } else {
                            unreachable;
                        }
                    }
                };
                comptime var NEW_FUNCS = FUNCS;
                NEW_FUNCS.LESS_THAN = if (custom.LESS_THAN) |LT| LT else PROTO.infer_less_than;
                NEW_FUNCS.LESS_THAN_OR_EQUAL = if (custom.LESS_THAN_OR_EQUAL) |LTEQ| LTEQ else PROTO.infer_less_than_or_equal;
                NEW_FUNCS.GREATER_THAN = if (custom.GREATER_THAN) |GT| GT else PROTO.infer_greater_than;
                NEW_FUNCS.GREATER_THAN_OR_EQUAL = if (custom.GREATER_THAN_OR_EQUAL) |GTEQ| GTEQ else PROTO.infer_greater_than_or_equal;
                NEW_FUNCS.ORDER_EQUALS = if (custom.ORDER_EQUALS) |OREQ| OREQ else PROTO.infer_order_equal;
                NEW_FUNCS.EXACT_EQUALS = if (custom.EXACT_EQUALS) |EXEQ| EXEQ else PROTO.infer_exact_equal;
                return NEW_FUNCS;
            }
            pub fn Finalize(comptime FUNCS: @This()) type {
                return struct {
                    pub const DEF = DEF_;
                    pub const HAS_USERDATA = DEF.USERDATA != void;
                    pub const DATA = DEF.DATA;
                    pub const ELEM = DEF.ELEM;
                    pub const IDX = DEF.IDX;
                    pub const USERDATA = DEF.USERDATA;

                    pub const Getter = Getter_;
                    pub const Setter = Setter_;
                    pub const Swapper = Swapper_;
                    pub const Comparer = Comparer_;

                    pub const get = FUNCS.GET;
                    pub const set = FUNCS.SET;
                    pub const swap = FUNCS.SWAP;
                    pub const less_than = FUNCS.LESS_THAN;
                    pub const less_than_or_equal = FUNCS.LESS_THAN_OR_EQUAL;
                    pub const greater_than = FUNCS.GREATER_THAN;
                    pub const greater_than_or_equal = FUNCS.GREATER_THAN_OR_EQUAL;
                    pub const order_equals = FUNCS.ORDER_EQUALS;
                    pub const exact_equals = FUNCS.EXACT_EQUALS;

                    pub fn swap_already_have_b(data: DATA, idx_a: IDX, idx_b: IDX, val_b: ELEM, userdata: USERDATA) DATA {
                        const new_data = set(data, idx_b, get(data, idx_a, userdata), userdata);
                        return set(new_data, idx_a, val_b, userdata);
                    }

                    pub const USERDATA_UNINIT = if (USERDATA == void) void{} else undefined;

                    pub const QuicksortSettings = struct {
                        /// `33` (32 + 1) = max input len of 2^32 items,
                        /// if you really need more than this you can increase it, each
                        /// additional 1 added doubles the max input len (`34` (33 + 1) = 2^33 max)
                        QUICKSORT_MAX_STACK: u8 = 33,
                        /// Signals to use a different partitioning scheme depending on whether you
                        /// expect the data to have many items with equal order,
                        /// or whether it is rare or impossible to occur
                        SAME_ORDER_EXPECTATIONS: ManySameOrderExpectation = .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
                        /// The max size of a partition (sub-slice) to use quicksort.
                        /// Under this length, partitions will intead use insertion sort
                        QUICKSORT_TO_INSERTION_THRESHOLD: comptime_int = 24,
                        /// If the quicksort partition depth exceeds `DEGENERATE_DETECTION_FACTOR * log2(input_len)`,
                        /// it likely has a degenerate state (approaching worst case scenario).
                        /// Switch to insertion sort (small total input) or heapsort instead,
                        ///
                        /// If the total input len is <= `FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN` (default 128)
                        /// it falls back to insertion sort (lower overhead than heapsort, especially when quicksort has already
                        /// partially sorted the data to some degree)
                        ///
                        /// Otherwise, fallback to heapsort
                        FALLBACK_WHEN_DEGENERATE: bool = true,
                        /// When degenerate fallback is enable, this value controls how degenerate
                        /// the input needs to be before the fallback is triggered:
                        ///
                        /// ```zig
                        /// const MAX_PARTITION_DEPTH = DEGENERATE_DETECTION_FACTOR * log2(input_len);
                        /// ```
                        DEGENERATE_DETECTION_FACTOR: comptime_int = 2,
                        /// When the quicksort depth is more than twice the expected average depth (`DEGENERATE_DETECTION_FACTOR * log2(input_len)`),
                        /// if the total input len is less than this value it will
                        /// fallback to insertion sort on the entire input
                        /// (already partially sorted, lower overhead than heapsort for small lists)
                        ///
                        /// Otherwise fallback to heapsort.
                        FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN: comptime_int = 128,
                    };

                    pub const SortInputs = if (HAS_USERDATA) struct {
                        data: DATA,
                        start: IDX = 0,
                        end_excluded: IDX,
                        userdata: USERDATA = USERDATA_UNINIT,

                        pub fn with_data(self: SortInputs, new_data: DATA) SortInputs {
                            var new_self = self;
                            new_self.data = new_data;
                            return new_self;
                        }

                        pub fn sub_slice(self: SortInputs, new_data: DATA, start: IDX, end_excluded: IDX) SortInputs {
                            return SortInputs{
                                .data = new_data,
                                .start = start,
                                .end_excluded = end_excluded,
                                .userdata = self.userdata,
                            };
                        }
                    };

                    pub const SortInputsRelative = struct {
                        data: DATA,
                        root: IDX = 0,
                        rel_start: IDX = 0,
                        rel_end_excluded: IDX,
                        userdata: USERDATA = USERDATA_UNINIT,

                        pub fn rel_to_true(self: SortInputsRelative, comptime USE_RELATIVE: bool, rel_idx: IDX) IDX {
                            switch (comptime USE_RELATIVE) {
                                true => return rel_idx + self.root,
                                false => return rel_idx,
                            }
                        }
                        pub fn true_to_rel(self: SortInputsRelative, comptime USE_RELATIVE: bool, true_idx: IDX) IDX {
                            switch (comptime USE_RELATIVE) {
                                true => return true_idx - self.root,
                                false => return true_idx,
                            }
                        }
                    };

                    pub const SortPartition = struct {
                        data: DATA,
                        lo_idx: IDX,
                        hi_idx: IDX,
                        userdata: USERDATA = USERDATA_UNINIT,
                    };

                    pub const SortSubHeap = struct {
                        data: DATA,
                        root_idx: IDX,
                        len_from_root: IDX,
                        userdata: USERDATA = USERDATA_UNINIT,
                    };

                    pub const IndexElemPair = struct { IDX, ELEM };

                    pub fn median_of_3(vals: [3]ELEM, idxs: [3]IDX, userdata: USERDATA) IndexElemPair {
                        var idx = idxs;
                        var tmp: IDX = undefined;
                        if (less_than(vals[idx[1]], vals[idx[0]], userdata)) {
                            tmp = idx[0];
                            idx[0] = idx[1];
                            idx[1] = tmp;
                        }
                        if (less_than(vals[idx[2]], vals[idx[0]], userdata)) {
                            tmp = idx[0];
                            idx[0] = idx[2];
                            idx[2] = tmp;
                        }
                        if (less_than(vals[idx[2]], vals[idx[1]], userdata)) {
                            return .{ idx[2], vals[idx[2]] };
                        }
                        return .{ idx[1], vals[idx[1]] };
                    }

                    pub fn is_sorted(inputs: SortInputs) bool {
                        if (inputs.end_excluded > inputs.start) {
                            @branchHint(.likely);
                            var idx_right = inputs.start + 1;
                            var val_left: ELEM = get(inputs.data, inputs.start, inputs.userdata);
                            var val_right: ELEM = undefined;
                            while (idx_right < inputs.end_excluded) {
                                @branchHint(.likely);
                                val_right = get(inputs.data, idx_right, inputs.userdata);
                                if (greater_than(val_left, val_right, inputs.userdata)) return false;
                                val_left = val_right;
                                idx_right += 1;
                            }
                        }
                        return true;
                    }

                    /// Filters smaller ordered items down until they find an index where they would be
                    /// in the correct order. Simple, stable, and very fast for fully-sorted or nearly-sorted lists, and for small
                    /// lists.
                    ///
                    /// Stable:
                    ///   - YES
                    ///
                    /// Cache Locality:
                    ///   - Great
                    ///
                    /// Initialization Overhead:
                    ///   - None
                    ///
                    /// Per-Step Overhead:
                    ///   - Low
                    ///
                    /// Time:
                    ///   - Best    = O(n) (already sorted)
                    ///   - Average = O(n^2)
                    ///   - Worst   = O(n^2)
                    ///
                    /// Space:
                    ///   - O(1)
                    pub fn insertion_sort(in: SortInputs) DATA {
                        var index_to_sort: IDX = in.start + 1;
                        var idx_right: IDX = undefined;
                        var idx_left: IDX = undefined;
                        var value_to_sort: ELEM = undefined;
                        var data = in.data;
                        while (index_to_sort < in.end_excluded) {
                            @branchHint(.likely);
                            value_to_sort = get(data, index_to_sort, in.userdata);
                            idx_right = index_to_sort;
                            inner: while (idx_right > in.start) {
                                @branchHint(.likely);
                                idx_left = idx_right - 1;
                                const val_left = get(data, idx_left, in.userdata);
                                if (greater_than(val_left, value_to_sort, in.userdata)) {
                                    data = set(data, idx_right, val_left, in.userdata);
                                    idx_right -= 1;
                                } else {
                                    break :inner;
                                }
                            }
                            data = set(data, idx_right, value_to_sort, in.userdata);
                            index_to_sort += 1;
                        }
                        return data;
                    }

                    fn assert_stack_can_support_sort_len(comptime SETTINGS: QuicksortSettings, start: IDX, end_excl: IDX, comptime src: SourceLocation) void {
                        const data_len = end_excl - start;
                        const needed_len: usize = @intCast(std.math.log2_int(IDX, data_len) + 2);
                        assert_with_reason(SETTINGS.QUICKSORT_MAX_STACK >= needed_len, src, "the provided `.QUICKSORT_MAX_STACK` setting ({d}) is too small, need {d} for given the data len {d}", .{ SETTINGS.QUICKSORT_MAX_STACK, needed_len, data_len });
                    }

                    pub fn QuicksortPartition(comptime DEGENERATE_FALLBACK: bool) type {
                        return struct {
                            lo_idx: IDX,
                            hi_idx: IDX,
                            budget: if (DEGENERATE_FALLBACK) IDX else void = if (DEGENERATE_FALLBACK) undefined else void{},

                            pub fn new(lo: IDX, hi: IDX, budget: IDX) @This() {
                                var this = @This(){
                                    .lo_idx = lo,
                                    .hi_idx = hi,
                                };
                                if (DEGENERATE_FALLBACK) {
                                    this.budget = budget;
                                }
                                return this;
                            }

                            pub fn empty(self: @This()) bool {
                                return self.lo_idx >= self.hi_idx;
                            }

                            pub fn len(self: @This()) IDX {
                                return (self.hi_idx + 1) - self.lo_idx;
                            }
                        };
                    }

                    /// Quicksort using a number of optimizations (similar to Introsort):
                    ///   - Use Insertion Sort when partitions become small
                    ///   - Median-of-three pivot (not random, always first, middle, last)
                    ///   - Manually choose a partition scheme based on stated expectations about items with equal order
                    ///     - Many items same order unlikely = 2-way Hoare scheme
                    ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
                    ///   - No rescursion, only a comptime sized stack of partition index ranges and a while loop
                    ///   - (Optional) Fallback to Heapsort/Insertion sort if partition degeneracy detected (more than N x the average partition depth)
                    ///
                    /// Stable:
                    ///   - No
                    ///
                    /// Cache Locality:
                    ///   - Great
                    ///
                    /// Initialization Overhead:
                    ///   - Low
                    ///
                    /// Per-Step Overhead:
                    ///   - Low
                    ///
                    /// Time:
                    ///   - Best    = O(n log n)
                    ///   - Average = O(n log n)
                    ///   - Worst:
                    ///     - With fallback enabled = (heapsort init overhead) + O(n log n)
                    ///     - No fallback enabled   = O(n^2) (fully/nearly sorted or adversarial input)
                    ///
                    /// Space:
                    ///   - O(log n) (implemented as a comptime-sized stack)
                    pub fn quicksort(in: SortInputs, comptime SETTINGS: QuicksortSettings) DATA {
                        const Partition = QuicksortPartition(SETTINGS.FALLBACK_WHEN_DEGENERATE);
                        if (in.end_excluded - in.start < 2) {
                            @branchHint(.unlikely);
                            return in.data;
                        }
                        const len = in.end_excluded - in.start;
                        const degenerate_limit: IDX = if (comptime SETTINGS.FALLBACK_WHEN_DEGENERATE) @intCast(SETTINGS.DEGENERATE_DETECTION_FACTOR * math.log2_int(IDX, len)) else math.maxInt(IDX);
                        assert_stack_can_support_sort_len(SETTINGS, in.start, in.end_excluded, @src());
                        var data = in.data;
                        var stack: [SETTINGS.QUICKSORT_MAX_STACK]Partition = undefined;
                        stack[0] = Partition.new(in.start, in.end_excluded - 1, degenerate_limit);
                        var stack_len: u8 = 1;
                        next_partition: while (stack_len > 0) {
                            @branchHint(.likely);
                            stack_len -= 1;
                            const parent_partition = stack[stack_len];
                            if (SETTINGS.FALLBACK_WHEN_DEGENERATE and parent_partition.budget <= 0) {
                                if (len <= SETTINGS.FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN) {
                                    return insertion_sort(in.with_data(data));
                                } else {
                                    return heapsort(in.with_data(data));
                                }
                            }
                            assert_with_reason(!parent_partition.empty(), @src(), "it should be impossible to have an empty partition here", .{});
                            if (parent_partition.len() <= SETTINGS.QUICKSORT_TO_INSERTION_THRESHOLD) {
                                data = insertion_sort(in.sub_slice(data, parent_partition.lo_idx, parent_partition.hi_idx + 1));
                                continue :next_partition;
                            }
                            data, const sub_partition = switch (SETTINGS.SAME_ORDER_EXPECTATIONS) {
                                .MANY_ITEMS_WITH_SAME_ORDER_LIKELY, .USE_DUTCH_FLAG_3_WAY_PARTITION => quicksort_partition_dutch_flag(.{
                                    .data = data,
                                    .lo_idx = parent_partition.lo_idx,
                                    .hi_idx = parent_partition.hi_idx,
                                    .userdata = in.userdata,
                                }),
                                .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE, .USE_HOARE_2_WAY_PARTITION => quicksort_partition_hoare(.{
                                    .data = data,
                                    .lo_idx = parent_partition.lo_idx,
                                    .hi_idx = parent_partition.hi_idx,
                                    .userdata = in.userdata,
                                }),
                            };
                            const left_partition = Partition.new(parent_partition.lo_idx, sub_partition.sub_partition_left_hi, parent_partition.budget - 1);
                            const right_partition = Partition.new(sub_partition.sub_partition_right_lo, parent_partition.hi_idx, parent_partition.budget - 1);
                            const left_len = left_partition.len();
                            const right_len = right_partition.len();
                            const left_empty: u8 = @intCast(@intFromBool(left_len == 0));
                            const right_empty: u8 = @intCast(@intFromBool(right_len == 0));
                            const larger_partition, const larger_empty, const smaller_partition, const smaller_empty = if (left_len < right_len) .{
                                right_partition,
                                right_empty,
                                left_partition,
                                left_empty,
                            } else .{
                                left_partition,
                                left_empty,
                                right_partition,
                                right_empty,
                            };
                            // add partitions larger first, smaller second,
                            // and use the `larger_empty` and `smaller_empty` vars
                            // to cull empty partitions
                            stack[stack_len] = larger_partition;
                            stack_len = stack_len + 1 - larger_empty;
                            stack[stack_len] = smaller_partition;
                            stack_len = stack_len + 1 - smaller_empty;
                        }
                        return data;
                    }

                    fn quicksort_partition_hoare(sub_slice: SortPartition) struct { DATA, PartitionResult } {
                        const len = (sub_slice.hi_idx + 1) - sub_slice.lo_idx;
                        const unsorted_idx = [3]IDX{ sub_slice.lo_idx, sub_slice.lo_idx + (len >> 1), sub_slice.hi_idx };
                        const unsorted_vals = [3]ELEM{ get(sub_slice.data, unsorted_idx[0], sub_slice.userdata), get(sub_slice.data, unsorted_idx[1], sub_slice.userdata), get(sub_slice.data, unsorted_idx[2], sub_slice.userdata) };
                        const median_idx, const pivot_item = median_of_3(unsorted_vals, unsorted_idx, sub_slice.userdata);
                        var data = swap_already_have_b(sub_slice.data, sub_slice.lo_idx, median_idx, pivot_item, sub_slice.userdata);
                        var left_idx = sub_slice.lo_idx;
                        var right_idx = sub_slice.hi_idx;
                        var left_item: ELEM = undefined;
                        var right_item: ELEM = undefined;
                        while (true) {
                            left_item = get(data, left_idx, sub_slice.userdata);
                            while (less_than(left_item, pivot_item, sub_slice.userdata)) {
                                left_idx += 1;
                                left_item = get(data, left_idx, sub_slice.userdata);
                            }
                            right_item = get(data, right_idx, sub_slice.userdata);
                            while (greater_than(right_item, pivot_item, sub_slice.userdata)) {
                                right_idx -|= 1;
                                right_item = get(data, right_idx, sub_slice.userdata);
                            }
                            if (left_idx >= right_idx) break;
                            data = set(data, left_idx, right_item, sub_slice.userdata);
                            data = set(data, right_idx, left_item, sub_slice.userdata);
                            left_idx += 1;
                            right_idx -|= 1;
                        }
                        return .{ data, PartitionResult{
                            .sub_partition_left_hi = right_idx,
                            .sub_partition_right_lo = right_idx + 1,
                        } };
                    }

                    fn quicksort_partition_dutch_flag(sub_slice: SortPartition) struct { DATA, PartitionResult } {
                        const len = (sub_slice.hi_idx + 1) - sub_slice.lo_idx;
                        const unsorted_idx = [3]IDX{
                            sub_slice.lo_idx,
                            sub_slice.lo_idx + (len >> 1),
                            sub_slice.hi_idx,
                        };
                        const unsorted_vals = [3]ELEM{
                            get(sub_slice.data, unsorted_idx[0], sub_slice.userdata),
                            get(sub_slice.data, unsorted_idx[1], sub_slice.userdata),
                            get(sub_slice.data, unsorted_idx[2], sub_slice.userdata),
                        };
                        const median_idx, const pivot_item = median_of_3(unsorted_vals, unsorted_idx, sub_slice.userdata);
                        var data = swap_already_have_b(sub_slice.data, sub_slice.lo_idx, median_idx, pivot_item, sub_slice.userdata);
                        var smallest_idx_with_same_order_as_pivot = sub_slice.lo_idx;
                        var check_idx = sub_slice.lo_idx;
                        var largest_idx_with_same_order_as_pivot = sub_slice.hi_idx;

                        while (check_idx < largest_idx_with_same_order_as_pivot) {
                            const check_item = get(data, check_idx, sub_slice.userdata);
                            if (less_than(check_item, pivot_item, sub_slice.userdata)) {
                                data = swap_already_have_b(data, smallest_idx_with_same_order_as_pivot, check_idx, check_item, sub_slice.userdata);
                                smallest_idx_with_same_order_as_pivot += 1;
                                check_idx += 1;
                            } else if (less_than(pivot_item, check_item, sub_slice.userdata)) {
                                data = swap_already_have_b(data, largest_idx_with_same_order_as_pivot, check_idx, check_item, sub_slice.userdata);
                                largest_idx_with_same_order_as_pivot -|= 1;
                            } else {
                                check_idx += 1;
                            }
                        }

                        return .{ data, PartitionResult{
                            .sub_partition_left_hi = smallest_idx_with_same_order_as_pivot -| 1,
                            .sub_partition_right_lo = largest_idx_with_same_order_as_pivot + 1,
                        } };
                    }

                    pub fn max_heapify_from_given_root(comptime USE_RELATIVE: bool, sub_heap: SortInputsRelative) DATA {
                        var data = sub_heap.data;
                        var target_idx = sub_heap.rel_start;
                        var target_idx_true = if (USE_RELATIVE) sub_heap.rel_to_true(USE_RELATIVE, target_idx) else void{};
                        const target_val = get(data, target_idx_true, sub_heap.userdata);
                        const MAX_IDX = math.maxInt(IDX);
                        const MAX_NO_CHILD_OVERFLOW = MAX_IDX >> 1;
                        while (true) {
                            var largest_val_idx = target_idx;
                            var largest_val_idx_true = target_idx_true;
                            var largest_val = target_val;
                            // Uses u1 bitwise math here to avoid a boolean short-circuit branch in machine code
                            const left_child_idx_overflow = @intFromBool(target_idx > MAX_NO_CHILD_OVERFLOW);
                            const left_child_idx = (target_idx << 1) | 1; // same as (idx * 2) + 1
                            const left_child_oob_u1 = left_child_idx_overflow | @intFromBool(left_child_idx >= sub_heap.rel_end_excluded);
                            const left_child_oob: bool = @bitCast(left_child_oob_u1);
                            const right_child_idx_overflow = left_child_idx_overflow | @intFromBool(left_child_idx == MAX_IDX);
                            const right_child_idx = left_child_idx +% 1;
                            const right_child_oob_u1 = right_child_idx_overflow | @intFromBool(right_child_idx >= sub_heap.rel_end_excluded);
                            const right_child_oob: bool = @bitCast(right_child_oob_u1);
                            if (!left_child_oob) {
                                const left_child_idx_true = if (USE_RELATIVE) sub_heap.rel_to_true(USE_RELATIVE, left_child_idx) else void{};
                                const left_child_val = get(data, if (USE_RELATIVE) left_child_idx_true else left_child_idx, sub_heap.userdata);
                                if (greater_than(left_child_val, target_val, sub_heap.userdata)) {
                                    largest_val_idx = left_child_idx;
                                    largest_val_idx_true = left_child_idx_true;
                                    largest_val = left_child_val;
                                }
                            }
                            if (!right_child_oob) {
                                const right_child_idx_true = if (USE_RELATIVE) sub_heap.rel_to_true(USE_RELATIVE, right_child_idx) else void{};
                                const right_child_val = get(data, if (USE_RELATIVE) right_child_idx_true else right_child_idx, sub_heap.userdata);
                                if (greater_than(right_child_val, target_val, sub_heap.userdata)) {
                                    largest_val_idx = right_child_idx;
                                    largest_val_idx_true = right_child_idx_true;
                                    largest_val = right_child_val;
                                }
                            }
                            if (largest_val_idx == target_idx) break; // target val in correct place
                            // swap largest and target and update target idx
                            data = set(data, if (USE_RELATIVE) largest_val_idx_true else largest_val_idx, target_val, sub_heap.userdata);
                            data = set(data, if (USE_RELATIVE) target_idx_true else target_idx, largest_val, sub_heap.userdata);
                            target_idx = largest_val_idx;
                            target_idx_true = largest_val_idx_true;
                        }
                        return data;
                    }

                    /// Uses Floyd's algorithm to turn a slice of data into a max heap in-place
                    ///
                    /// Note that if `inputs.start != 0`, THIS function handles it by performing math on
                    /// indexes relative to `inputs.start` then adjusting any data `get` and `set`ops by
                    /// adding `inputs.start` to get the correct values. The user must remember to
                    /// either re-slice the data to start at index 0, or ALSO use relative indexes and
                    /// adjust get and set ops for all heap operations afterward.
                    pub fn build_max_heap(in: SortInputs) DATA {
                        var data = in.data;
                        const len = in.end_excluded - in.start;
                        var non_leaf_idx = (len >> 1);
                        if (in.start != 0) {
                            // if the index range to turn into a max heap is not rooted at true 0,
                            // we use relative values and adjust the index by `inputs.start`
                            // within `max_heapify_from_given_root` for any `get` or `set`
                            while (non_leaf_idx > 0) {
                                non_leaf_idx -= 1;
                                data = max_heapify_from_given_root(true, .{
                                    .data = data,
                                    .root = in.start,
                                    .rel_start = non_leaf_idx,
                                    .rel_end_excluded = len,
                                    .userdata = in.userdata,
                                });
                            }
                        } else {
                            while (non_leaf_idx > 0) {
                                non_leaf_idx -= 1;
                                data = max_heapify_from_given_root(false, .{
                                    .data = data,
                                    .root = 0,
                                    .rel_start = non_leaf_idx,
                                    .rel_end_excluded = len,
                                    .userdata = in.userdata,
                                });
                            }
                        }
                    }

                    /// Builds a max-heap out of the given data range, then iteratively removes the max value
                    /// from the heap and moves it to the end of the range and re-heapifies the remaining elements
                    ///
                    /// Stable:
                    ///   - NO
                    ///
                    /// Cache Locality:
                    ///   - Poor
                    ///
                    /// Initialization Overhead:
                    ///   - Medium
                    ///
                    /// Per-Step Overhead:
                    ///   - Low
                    ///
                    /// Time:
                    ///   - Always = O(n log n)
                    ///
                    /// Space:
                    ///   - O(1)
                    pub fn heapsort(inputs: SortInputs) DATA {
                        var data = build_max_heap(inputs);

                        var heap_end = inputs.end_excluded;
                        const start_plus_one = inputs.start + 1;
                        if (inputs.start != 0) {
                            while (heap_end > start_plus_one) {
                                heap_end -= 1;
                                data = swap(data, heap_end, inputs.start, inputs.userdata);
                                data = max_heapify_from_given_root(true, SortInputsRelative{
                                    .data = data,
                                    .root = inputs.start,
                                    .rel_start = 0,
                                    .rel_end_excluded = heap_end - inputs.start,
                                    .userdata = inputs.userdata,
                                });
                            }
                        } else {
                            while (heap_end > start_plus_one) {
                                heap_end -= 1;
                                data = swap(data, heap_end, inputs.start, inputs.userdata);
                                data = max_heapify_from_given_root(false, SortInputsRelative{
                                    .data = data,
                                    .root = 0,
                                    .rel_start = 0,
                                    .rel_end_excluded = heap_end,
                                    .userdata = inputs.userdata,
                                });
                            }
                        }
                        return data;
                    }

                    const PartitionResult = struct {
                        sub_partition_left_hi: IDX,
                        sub_partition_right_lo: IDX,
                    };
                };
            }
        };
    }
};

test "Utils_DataManipulation => median_of_3_index" {
    const IDX = [3]u8{ 0, 1, 2 };
    const Case = struct {
        input: [3]u8,
        med_idxs: []const u8,

        pub fn new(vals: [3]u8, med_idxs: []const u8) @This() {
            return @This(){
                .input = vals,
                .med_idxs = med_idxs,
            };
        }
    };
    const cases = [_]Case{
        Case.new(.{ 1, 2, 3 }, &.{1}),
        Case.new(.{ 1, 3, 2 }, &.{2}),
        Case.new(.{ 2, 1, 3 }, &.{0}),
        Case.new(.{ 2, 3, 1 }, &.{0}),
        Case.new(.{ 3, 1, 2 }, &.{2}),
        Case.new(.{ 3, 2, 1 }, &.{1}),
        Case.new(.{ 3, 3, 3 }, &.{ 0, 1, 2 }),
        Case.new(.{ 1, 1, 2 }, &.{ 0, 1 }),
        Case.new(.{ 1, 2, 2 }, &.{ 1, 2 }),
    };
    const DMP_TYPES = DataManipulationPackage{
        .DATA = [3]u8,
        .ELEM = u8,
        .IDX = u8,
    };
    const DMP_FUNCS = DMP_TYPES.WithFunctions(){};
    const DMP = DMP_FUNCS.Finalize();
    next_case: for (cases) |case| {
        const med_idx, const med_val = DMP.median_of_3(case.input, IDX, {});
        for (case.med_idxs) |valid_median_idx| {
            if (med_idx == valid_median_idx) {
                if (med_val != case.input[med_idx]) return error.returned_val_isnt_the_one_at_that_index;
                continue :next_case;
            }
        }
        return error.median_idx_returned_is_incorrect;
    }
}

// CHECKPOINT add test cases for sorting funcs
