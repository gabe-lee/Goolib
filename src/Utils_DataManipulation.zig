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
const Random = std.Random;
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
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, userdata: USERDATA_TYPE) FIELD_TYPE;
}
pub fn GetFieldPtrFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime FIELD_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, userdata: USERDATA_TYPE) *FIELD_TYPE;
}
pub fn SetFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime ELEM_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, val: ELEM_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn SetFieldFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime FIELD_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx: IDX_TYPE, val: FIELD_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn SwapFn(comptime DATA_STRUCTURE: type, comptime IDX_TYPE: type, comptime USERDATA_TYPE: type) type {
    return fn (data: DATA_STRUCTURE, idx_a: IDX_TYPE, idx_b: IDX_TYPE, userdata: USERDATA_TYPE) DATA_STRUCTURE;
}
pub fn CompareFn(comptime TA: type, comptime TB: type, comptime USERDATA: type) type {
    return fn (a: TA, b: TB, userdata: USERDATA) bool;
}
pub fn InnateCountFn(comptime DATA: type, comptime COUNT: type, comptime USERDATA: type) type {
    return fn (data: DATA, userdata: USERDATA) COUNT;
}
pub fn InnateIndexFn(comptime DATA: type, comptime ID: type, comptime USERDATA: type) type {
    return fn (data: DATA, userdata: USERDATA) ID;
}
pub fn InnateNthIndexFn(comptime DATA: type, comptime ID: type, comptime COUNT: type, comptime USERDATA: type) type {
    return fn (data: DATA, n: COUNT, userdata: USERDATA) ID;
}
pub fn IndexFn(comptime DATA: type, comptime ID: type, comptime USERDATA: type) type {
    return fn (data: DATA, n: ID, userdata: USERDATA) ID;
}
pub fn NthIndexFn(comptime DATA: type, comptime ID: type, comptime COUNT: type, comptime USERDATA: type) type {
    return fn (data: DATA, idx: ID, n: COUNT, userdata: USERDATA) ID;
}
pub fn CountFn(comptime DATA: type, comptime ID: type, comptime COUNT: type, comptime USERDATA: type) type {
    return fn (data: DATA, idx_a: ID, idx_b: ID, userdata: USERDATA) COUNT;
}
pub fn RangeOpFn(comptime DATA: type, comptime ID: type, comptime USERDATA: type) type {
    return fn (data: DATA, idx_a: ID, idx_b: ID, userdata: USERDATA) DATA;
}

pub fn RangeOpExtraFn(comptime DATA: type, comptime ID: type, comptime USERDATA: type) type {
    return fn (data: DATA, idx_a: ID, idx_b: ID, idx_c: ID, userdata: USERDATA) DATA;
}
pub fn IdValidateFn(comptime DATA: type, comptime ID: type, comptime USERDATA: type) type {
    return fn (data: DATA, i: ID, userdata: USERDATA) bool;
}

const FUNC_FLAG_INT = u64;
const F = struct {
    const GET: FUNC_FLAG_INT = 1 << 0;
    const GET_PTR: FUNC_FLAG_INT = 1 << 1;
    const GET_CONST_PTR: FUNC_FLAG_INT = 1 << 2;
    const SET: FUNC_FLAG_INT = 1 << 3;
    const SWAP: FUNC_FLAG_INT = 1 << 4;
    const GREATER_THAN: FUNC_FLAG_INT = 1 << 5;
    const GREATER_THAN_OR_EQUAL: FUNC_FLAG_INT = 1 << 6;
    const LESS_THAN: FUNC_FLAG_INT = 1 << 7;
    const LESS_THAN_OR_EQUAL: FUNC_FLAG_INT = 1 << 8;
    const ORDER_EQUALS: FUNC_FLAG_INT = 1 << 9;
    const EXACT_EQUALS: FUNC_FLAG_INT = 1 << 10;
    const FIRST_INDEX: FUNC_FLAG_INT = 1 << 11;
    const LAST_INDEX: FUNC_FLAG_INT = 1 << 12;
    const NTH_INDEX_FROM_START: FUNC_FLAG_INT = 1 << 13;
    const NTH_INDEX_FROM_END: FUNC_FLAG_INT = 1 << 14;
    const PREV_INDEX: FUNC_FLAG_INT = 1 << 15;
    const NEXT_INDEX: FUNC_FLAG_INT = 1 << 16;
    const NTH_PREV_INDEX: FUNC_FLAG_INT = 1 << 17;
    const NTH_NEXT_INDEX: FUNC_FLAG_INT = 1 << 18;
    const GET_LEN: FUNC_FLAG_INT = 1 << 19;
    const SET_LEN: FUNC_FLAG_INT = 1 << 20;
    const GET_CAP: FUNC_FLAG_INT = 1 << 21;
    const SET_CAP: FUNC_FLAG_INT = 1 << 22;
    const RANGE_LEN: FUNC_FLAG_INT = 1 << 23;
    const APPEND_ONE: FUNC_FLAG_INT = 1 << 24;
    const APPEND_N: FUNC_FLAG_INT = 1 << 25;
    const INSERT_ONE: FUNC_FLAG_INT = 1 << 26;
    const INSERT_N: FUNC_FLAG_INT = 1 << 27;
    const DELETE_ONE: FUNC_FLAG_INT = 1 << 28;
    const DELETE_N: FUNC_FLAG_INT = 1 << 29;
    const REVERSE_RANGE: FUNC_FLAG_INT = 1 << 30;
    const ENSURE_SPACE: FUNC_FLAG_INT = 1 << 31;
    const MOVE_ONE_PRESERVE: FUNC_FLAG_INT = 1 << 32;
    const MOVE_BLOCK_PRESERVE: FUNC_FLAG_INT = 1 << 33;
    const NEVER_OVERLAP_COPY_RANGE: FUNC_FLAG_INT = 1 << 34;
    const MIGHT_OVERLAP_COPY_RANGE: FUNC_FLAG_INT = 1 << 35;
    const MEMORY_CONTIGUOUS_IN_ORDER: FUNC_FLAG_INT = 1 << 36;
    const ID_IN_RANGE: FUNC_FLAG_INT = 1 << 37;
    const ROTATE_RANGE_LEFT: FUNC_FLAG_INT = 1 << 38;
    const ROTATE_RANGE_RIGHT: FUNC_FLAG_INT = 1 << 39;
    const SCRAMBLE: FUNC_FLAG_INT = 1 << 40;
    const ID_LESS_THAN_ID: FUNC_FLAG_INT = 1 << 41;
};
const FuncFlags = struct {
    flags: FUNC_FLAG_INT = 0,

    fn add_if_not_null(comptime flags: *FuncFlags, comptime flag: FUNC_FLAG_INT, comptime not_null: anytype) void {
        if (not_null != null) {
            flags.flags |= flag;
        }
    }

    fn has(comptime flags: FuncFlags, comptime flag: FUNC_FLAG_INT) bool {
        return (flags & flag) == flag;
    }
    fn has_any(comptime flags: FuncFlags, comptime any_flag: []const FUNC_FLAG_INT) bool {
        inline for (any_flag) |flag| {
            if (flags.has(flag)) return true;
        }
        return false;
    }
};
const INFER = struct {
    const GET_FROM_CONST_PTR = F.GET_CONST_PTR;
    const GET_FROM_PTR = F.GET_PTR;

    const CONST_PTR_FROM_PTR = F.GET_PTR;

    const SET_FROM_PTR = F.GET_PTR;

    const SWAP_FROM_PTR = F.GET_PTR;
    const SWAP_FROM_GET_SET = F.GET | F.SET;

    const GT_FROM_LTEQ = F.LESS_THAN_OR_EQUAL;
    const GT_FROM_LT_EQ = F.LESS_THAN | F.EXACT_EQUALS;
    const GT_FROM_LT_OQ = F.LESS_THAN | F.ORDER_EQUALS;

    const LT_FROM_GTEQ = F.GREATER_THAN_OR_EQUAL;
    const LT_FROM_GT_EQ = F.GREATER_THAN | F.EXACT_EQUALS;
    const LT_FROM_GT_OQ = F.GREATER_THAN | F.ORDER_EQUALS;

    const EQOQ_FROM_GT_LT = F.GREATER_THAN | F.LESS_THAN;
    const OQ_FROM_EQ = F.EXACT_EQUALS;
    const EQ_FROM_OQ = F.ORDER_EQUALS;

    const GTEQ_FROM_LT = F.LESS_THAN;
    const GTEQ_FROM_GT_EQ = F.GREATER_THAN | F.EXACT_EQUALS;
    const GTEQ_FROM_GT_OQ = F.GREATER_THAN | F.ORDER_EQUALS;

    const LTEQ_FROM_GT = F.GREATER_THAN;
    const LTEQ_FROM_LT_EQ = F.LESS_THAN | F.EXACT_EQUALS;
    const LTEQ_FROM_LT_OQ = F.LESS_THAN | F.ORDER_EQUALS;

    const NEXT_IDX_FROM_NTH_NEXT = F.NTH_NEXT_INDEX;
    const NEXT_IDX_FROM_LAST_PREV = F.LAST_INDEX | F.PREV_INDEX;

    const NTH_NEXT_IDX_FROM_NEXT = F.NEXT_INDEX;
    const NTH_NEXT_IDX_FROM_LAST_PREV = F.LAST_INDEX | F.PREV_INDEX;

    const PREV_IDX_FROM_NTH_PREV = F.NTH_PREV_INDEX;
    const PREV_IDX_FROM_FIRST_NEXT = F.FIRST_INDEX | F.NEXT_INDEX;

    const NTH_PREV_IDX_FROM_PREV = F.PREV_INDEX;
    const NTH_PREV_IDX_FROM_FIRST_NEXT = F.FIRST_INDEX | F.NEXT_INDEX;

    const RANGE_LEN_FROM_NEXT = F.NEXT_INDEX;
    const RANGE_LEN_FROM_PREV = F.PREV_INDEX;

    const LEN_FROM_FIRST_LAST_RANGE_LEN = F.FIRST_INDEX | F.LAST_INDEX | F.RANGE_LEN;
    const LEN_FROM_FIRST_LAST_NEXT = F.FIRST_INDEX | F.LAST_INDEX | F.NEXT_INDEX;
    const LEN_FROM_FIRST_LAST_PREV = F.FIRST_INDEX | F.LAST_INDEX | F.PREV_INDEX;

    const LAST_FROM_FIRST_LEN_NTH_NEXT = F.FIRST_INDEX | F.GET_LEN | F.NTH_INDEX_FROM_START;
    const LAST_FROM_FIRST_LEN_NEXT = F.FIRST_INDEX | F.GET_LEN | F.NEXT_INDEX;
    const LAST_FROM_NTH_FROM_LAST = F.NTH_INDEX_FROM_END;
    const LAST_FROM_LEN_NTH_FROM_START = F.NTH_INDEX_FROM_START | F.GET_LEN;

    const FIRST_FROM_LAST_LEN_NTH_PREV = F.LAST_INDEX | F.GET_LEN | F.NTH_PREV_INDEX;
    const FIRST_FROM_LAST_LEN_PREV = F.LAST_INDEX | F.GET_LEN | F.PREV_INDEX;
    const FIRST_FROM_NTH_FROM_START = F.NTH_INDEX_FROM_START;
    const FIRST_FROM_LEN_NTH_FROM_END = F.NTH_INDEX_FROM_END | F.GET_LEN;

    const NTH_FROM_END_FROM_LAST_NTH_PREV = F.LAST_INDEX | F.NTH_PREV_INDEX;
    const NTH_FROM_END_FROM_LAST_PREV = F.LAST_INDEX | F.PREV_INDEX;

    const NTH_FROM_START_FROM_FIRST_NTH_NEXT = F.FIRST_INDEX | F.NTH_NEXT_INDEX;
    const NTH_FROM_START_FROM_FIRST_NEXT = F.FIRST_INDEX | F.NEXT_INDEX;

    const REVERSE_FROM_SWAP = F.SWAP;
    const REVERSE_FROM_GET_SET = F.GET | F.SET;

    const ROTATE_FROM_REVERSE = F.REVERSE_RANGE;
    const ROTATE_FROM_SWAP = F.SWAP;
    const ROTATE_FROM_GET_SET = F.GET | F.SET;

    const MOVE_FROM_ROTATE = F.ROTATE_RANGE_LEFT | F.ROTATE_RANGE_RIGHT;
    const MOVE_FROM_REVERSE = F.REVERSE_RANGE;
    const MOVE_FROM_SWAP = F.SWAP;
    const MOVE_FROM_GET_SET = F.GET | F.SET;

    const MOVE_ONE_FROM_GET_SET = F.GET | F.SET | F.NEXT_INDEX | F.PREV_INDEX;
    const MOVE_ONE_FROM_MOVE_BLOCK = F.MOVE_BLOCK_PRESERVE;
};

pub fn native_type_data_manipulation_package(comptime DATA_STRUCTURE: type, comptime ELEM: type) type {
    comptime {
        const core = DataManipulationPackage{
            .DATA = DATA_STRUCTURE,
            .ELEM = ELEM,
            .ID = usize,
            .COUNT_INT = usize,
            .USERDATA = void,
        };
        return core.CustomFunctions(.NONE).with_custom_functions(true, .{});
    }
}

pub fn contiguous_memory_manipulation_package_using_core_access(comptime CORE_DEF: DataManipulationPackage, comptime CORE_ACCESS: CORE_DEF.CoreAccessFuncs()) type {
    return CORE_DEF.CustomFunctions(CORE_ACCESS).with_custom_functions(true, .{});
}
pub fn custom_memory_manipulation_package_no_defaults(comptime CORE_DEF: DataManipulationPackage, comptime CUSTOM_FUNCS: CORE_DEF.CustomFunctions(.NONE)) type {
    return CORE_DEF.CustomFunctions(.NONE).with_custom_functions(false, CUSTOM_FUNCS);
}
pub fn custom_memory_manipulation_package_default_fallbacks_with_core_access(comptime CORE_DEF: DataManipulationPackage, comptime CORE_ACCESS: CORE_DEF.CoreAccessFuncs(), comptime CUSTOM_FUNCS: CORE_DEF.CustomFunctions(CORE_ACCESS)) type {
    return CORE_DEF.CustomFunctions(CORE_ACCESS).with_custom_functions(true, CUSTOM_FUNCS);
}

pub const DataManipulationPackage = struct {
    /// The homogenous data structure that will be acted upon
    DATA: type = undefined,
    /// The homogenous element type the data structe holds
    ELEM: type = undefined,
    /// A type that acts as a 'key' to access an element.
    ///
    /// Typically this will be an integer that is exactly the same as `COUNT_INT`,
    /// but may also be something like a pointer to an element (such as in a linked-list), or
    /// a hash value of the element, etc.
    ID: type = undefined,
    /// An integer kind that is used for the functions accepting/returning a
    /// length or count. Typically this will be an integer that is exactly the same
    /// as `ID` for slice-like data structures.
    ///
    /// MUST be an integer.
    COUNT_INT: type = undefined,
    /// An optional userdata type that is passed to every function call.
    ///
    /// If needed, this should be some external cache or data source
    /// that holds all common information needed to execute data manipulation
    /// functions on the data structure.
    ///
    /// For most use cases this can be left as `void`. An example use case is
    /// if the actual concrete data structure holds elements that are references
    /// to some other data structure that holds the actual elements themselves,
    /// and you need to use the reference type to get the real type out of the external userdata
    USERDATA: type = void,

    pub fn CoreAccessFuncs(comptime CORE_DEF: DataManipulationPackage) type {
        return struct {
            get_base_ptr: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) [*]CORE_DEF.ELEM = null,
            set_base_ptr: ?fn (data: CORE_DEF.DATA, ptr: [*]CORE_DEF.ELEM, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,
            get_len: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) CORE_DEF.COUNT_INT = null,
            set_len: ?fn (data: CORE_DEF.DATA, len: CORE_DEF.COUNT_INT, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,
            get_cap: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) CORE_DEF.COUNT_INT = null,
            set_cap: ?fn (data: CORE_DEF.DATA, cap: CORE_DEF.COUNT_INT, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,

            pub const NONE = @This(){};
        };
    }

    pub fn CustomFunctions(comptime CORE_DEF_: DataManipulationPackage, comptime CORE_ACCESS_FUNCS: CORE_DEF_.CoreAccessFuncs()) type {
        return struct {
            const DEF_WITH_FUNCS = @This();
            pub const CORE_DEF = CORE_DEF_;
            pub const DATA_ = CORE_DEF.DATA;
            pub const ELEM_ = CORE_DEF.ELEM;
            pub const COUNT_ = CORE_DEF.COUNT_INT;
            pub const ID_ = CORE_DEF.ID;
            pub const USERDATA_ = CORE_DEF.USERDATA;

            pub const FieldInfo = Types.extract_struct_union_or_dummy_field_info(ELEM_);
            const TYPE_FOR_FIELD: fn (comptime INFO: @TypeOf(FieldInfo), comptime field: []const u8) type = FieldInfo.type_for_field;
            pub fn TypeForField(comptime field: []const u8) type {
                return FieldInfo.type_for_field(field);
            }
            const FieldInfoAsStructInfo_: Types.StructInfo(FieldInfo.field_names.len) = FieldInfo.as_struct_info();

            const FieldGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = struct {
                        fn default_get(data: DATA_, id: ID_, userdata: USERDATA_) *FT.* {
                            return @field(&default_get_base_ptr(data, userdata)[id], NAME);
                        }
                        const FN = fn (DATA_, ID_, USERDATA_) FT.*;
                    };
                    FT.* = PROTO.FN;
                    ATTR.@"align" = @alignOf(PROTO.FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&PROTO.default_get);
                }
                break :make getters;
            };
            pub const FieldGetters = FieldGettersStructInfo.build_struct_type();
            pub const DefaultFieldGetters = FieldGetters{};

            const FieldCustomGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_types, getters.field_attrs) |*FT, *ATTR| {
                    const FN = fn (DATA_, ID_, USERDATA_) FT.*;
                    FT.* = FN;
                    ATTR.@"align" = @alignOf(FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&null);
                }
                break :make getters;
            };
            pub const FieldCustomGetters = FieldCustomGettersStructInfo.build_struct_type();

            const FieldPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = struct {
                        fn default_get_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *FT.* {
                            return &@field(&default_get_base_ptr(data, userdata)[id], NAME);
                        }
                        const FN = fn (DATA_, ID_, USERDATA_) *FT.*;
                    };
                    FT.* = PROTO.FN;
                    ATTR.@"align" = @alignOf(PROTO.FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&PROTO.default_get_ptr);
                }
                break :make getters;
            };
            pub const FieldPtrGetters = FieldPtrGettersStructInfo.build_struct_type();
            pub const DefaultFieldPtrGetters = FieldPtrGetters{};

            const FieldOptPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_types, getters.field_attrs) |*FT, *ATTR| {
                    const FN = fn (DATA_, ID_, USERDATA_) *FT.*;
                    FT.* = FN;
                    ATTR.@"align" = @alignOf(FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&null);
                }
                break :make getters;
            };
            pub const FieldCustomPtrGetters = FieldOptPtrGettersStructInfo.build_struct_type();

            const FieldConstPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_names, getters.field_types, getters.field_attrs) |NAME, *FT, *ATTR| {
                    const PROTO = struct {
                        fn default_get_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const FT.* {
                            return &@field(&default_get_base_ptr(data, userdata)[id], NAME);
                        }
                        const FN = fn (DATA_, ID_, USERDATA_) *const FT.*;
                    };
                    FT.* = PROTO.FN;
                    ATTR.@"align" = @alignOf(PROTO.FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&PROTO.default_get_const_ptr);
                }
                break :make getters;
            };
            pub const FieldConstPtrGetters = FieldConstPtrGettersStructInfo.build_struct_type();
            pub const DefaultFieldConstPtrGetters = FieldConstPtrGetters{};

            const FieldOptConstPtrGettersStructInfo = make: {
                const getters = FieldInfoAsStructInfo_;
                for (getters.field_types, getters.field_attrs) |*FT, *ATTR| {
                    const FN = fn (DATA_, ID_, USERDATA_) *const FT.*;
                    FT.* = FN;
                    ATTR.@"align" = @alignOf(FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&null);
                }
                break :make getters;
            };
            pub const FieldCustomConstPtrGetters = FieldOptConstPtrGettersStructInfo.build_struct_type();

            const FieldSettersStructInfo = make: {
                const setters = FieldInfoAsStructInfo_;
                for (setters.field_names, setters.field_types, setters.field_attrs) |NAME, *TYPE, *ATTR| {
                    const PROTO = struct {
                        fn default_set(data: DATA_, id: ID_, val: TYPE.*, userdata: USERDATA_) DATA_ {
                            @field(&default_get_base_ptr(data, userdata)[id], NAME) = val;
                            return data;
                        }
                        const FN = fn (DATA_, ID_, TYPE.*, USERDATA_) DATA_;
                    };
                    TYPE.* = PROTO.FN;
                    ATTR.@"align" = @alignOf(PROTO.FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = &PROTO.default_set;
                }
                break :make setters;
            };
            pub const FieldSetters = FieldSettersStructInfo.build_struct_type();
            pub const DefaultFieldSetters = FieldSetters{};

            const FieldOptSettersStructInfo = make: {
                const setters = FieldInfoAsStructInfo_;
                for (setters.field_types, setters.field_attrs) |*TYPE, *ATTR| {
                    const FN = fn (DATA_, ID_, TYPE.*, USERDATA_) DATA_;
                    TYPE.* = FN;
                    ATTR.@"align" = @alignOf(FN);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&null);
                }
                break :make setters;
            };
            pub const FieldCustomSetters = FieldOptSettersStructInfo.build_struct_type();

            const FieldFlagsStructInfo = make: {
                const flags_info = FieldInfoAsStructInfo_;
                for (flags_info.field_types, flags_info.field_attrs) |*TYPE, *ATTR| {
                    TYPE.* = FuncFlags;
                    ATTR.@"align" = @alignOf(FuncFlags);
                    ATTR.@"comptime" = false;
                    ATTR.default_value_ptr = @ptrCast(&FuncFlags{});
                }
                break :make flags_info;
            };
            pub const FieldFlags = FieldFlagsStructInfo.build_struct_type();

            ID_LESS_THAN_ID: T_FN_ID_LESS_THAN_ID = default_id_less_than_id,
            ID_LESS_THAN_OR_EQUAL_ID: T_FN_ID_LESS_THAN_OR_EQUAL_ID = default_id_less_than_or_equal_id,
            FIRST_ID: T_FN_FIRST_ID = default_first_index,
            LAST_ID: T_FN_LAST_ID = default_last_index,
            NTH_ID_FROM_START: T_FN_NTH_ID_FROM_START = default_nth_index_from_start,
            NTH_ID_FROM_END: T_FN_NTH_ID_FROM_END = default_nth_index_from_end,
            PREV_ID: T_FN_PREV_ID = default_prev_idx,
            NEXT_ID: T_FN_NEXT_ID = default_next_idx,
            NTH_PREV_ID: T_FN_PREV_ID = default_nth_prev_idx,
            NTH_NEXT_ID: T_FN_NEXT_ID = default_nth_next_idx,
            GET_LEN: T_FN_LEN = default_len,
            SET_LEN: T_FN_SET_LEN = default_set_len,
            RANGE_LEN: T_FN_RANGE_LEN = default_range_len,
            VALID_ID: T_FN_VALID_ID = default_valid_id,
            GET: T_FN_GET = default_get,
            GET_PTR: T_FN_GET_PTR = default_get_ptr,
            GET_CONST_PTR: T_FN_GET_CONST_PTR = default_get_const_ptr,
            GET_FIELD: FieldGetters = .{},
            GET_FIELD_PTR: FieldPtrGetters = .{},
            GET_FIELD_CONST_PTR: FieldConstPtrGetters = .{},
            SET: T_FN_SET = default_set,
            SET_FIELD: FieldSetters = .{},
            SWAP: T_FN_SWAP = default_swap,
            GREATER_THAN: T_FN_GREATER_THAN = default_greater_than,
            GREATER_THAN_OR_EQUAL: T_FN_GREATER_THAN_OR_EQUAL = default_greater_than_or_equal,
            LESS_THAN: T_FN_LESS_THAN = default_less_than,
            LESS_THAN_OR_EQUAL: T_FN_LESS_THAN_OR_EQUAL = default_less_than_or_equal,
            ORDER_EQUALS: T_FN_EQUALS = default_equals,
            EXACT_EQUALS: T_FN_EQUALS = default_equals,
            REVERSE_RANGE: T_FN_REVERSE = default_reverse_range,
            MOVE_ONE_PRESERVE: T_FN_MOVE_ONE_PRESERVE = default_move_one_preserve,
            MOVE_BLOCK_PRESERVE: T_FN_MOVE_BLOCK_PRESERVE = default_move_block_preserve,
            ROTATE_RIGHT: T_FN_ROTATE_RIGHT = default_rotate_range_right,
            ROTATE_LEFT: T_FN_ROTATE_LEFT = default_rotate_range_left,
            SCRAMBLE: T_FN_SCRAMBLE = default_scramble,

            fn default_get_base_ptr(data: DATA_, userdata: USERDATA_) [*]ELEM_ {
                if (comptime CORE_ACCESS_FUNCS.get_base_ptr) |get_base| {
                    return get_base(data, userdata);
                }
                if (comptime Types.type_is_struct(DATA_)) {
                    if (comptime @hasField(DATA_, "items")) {
                        if (comptime @hasField(@FieldType(DATA_, "items"), "ptr")) {
                            return @ptrCast(data.items.ptr);
                        } else {
                            unreachable;
                        }
                    } else if (comptime @hasField(DATA_, "ptr")) {
                        return @ptrCast(data.ptr);
                    } else {
                        unreachable;
                    }
                } else if (comptime Types.type_is_slice(DATA_)) {
                    return @ptrCast(data.ptr);
                } else {
                    unreachable;
                }
            }
            fn default_set_base_ptr(data: DATA_, ptr: [*]ELEM_, userdata: USERDATA_) DATA_ {
                if (comptime CORE_ACCESS_FUNCS.set_base_ptr) |set_base| {
                    return set_base(data, ptr, userdata);
                }
                var new_data = data;
                if (comptime Types.type_is_struct(DATA_)) {
                    if (comptime @hasField(DATA_, "items")) {
                        if (comptime @hasField(@FieldType(DATA_, "items"), "ptr")) {
                            new_data.items.ptr = @ptrCast(ptr);
                        } else {
                            unreachable;
                        }
                    } else if (comptime @hasField(DATA_, "ptr")) {
                        new_data.ptr = @ptrCast(ptr);
                    } else {
                        unreachable;
                    }
                } else if (comptime Types.type_is_slice(DATA_)) {
                    new_data.ptr = @ptrCast(ptr);
                } else {
                    unreachable;
                }
                return new_data;
            }

            const T_FN_ID_LESS_THAN_ID = @TypeOf(default_id_less_than_id);
            fn default_id_less_than_id(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                return id_a < id_b;
            }
            const T_FN_ID_LESS_THAN_OR_EQUAL_ID = @TypeOf(default_id_less_than_or_equal_id);
            fn default_id_less_than_or_equal_id(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                return id_a <= id_b;
            }
            const T_FN_FIRST_ID = @TypeOf(default_first_index);
            fn default_first_index(_: DATA_, _: USERDATA_) ID_ {
                return 0;
            }
            const T_FN_LEN = @TypeOf(default_len);
            fn default_len(data: DATA_, userdata: USERDATA_) COUNT_ {
                if (comptime CORE_ACCESS_FUNCS.get_len) |get_len| {
                    return get_len(data, userdata);
                }
                if (comptime Types.type_is_struct(DATA_)) {
                    if (comptime @hasField(DATA_, "items")) {
                        if (comptime @hasField(@FieldType(DATA_, "items"), "len")) {
                            return @intCast(data.items.len);
                        } else {
                            unreachable;
                        }
                    } else if (comptime @hasField(DATA_, "len")) {
                        return @intCast(data.len);
                    } else {
                        unreachable;
                    }
                } else if (comptime Types.type_is_slice(DATA_)) {
                    return @intCast(data.len);
                } else {
                    unreachable;
                }
            }
            const T_FN_SET_LEN = @TypeOf(default_set_len);
            fn default_set_len(data: DATA_, new_len: COUNT_, userdata: USERDATA_) DATA_ {
                if (comptime CORE_ACCESS_FUNCS.set_len) |set_len| {
                    return set_len(data, new_len, userdata);
                }
                var new_data = data;
                if (comptime Types.type_is_struct(DATA_)) {
                    if (comptime @hasField(DATA_, "items")) {
                        if (comptime @hasField(@FieldType(DATA_, "items"), "len")) {
                            new_data.items.len = new_len;
                        } else {
                            unreachable;
                        }
                    } else if (comptime @hasField(DATA_, "len")) {
                        new_data.len = new_len;
                    } else {
                        unreachable;
                    }
                } else if (comptime Types.type_is_slice(DATA_)) {
                    new_data.len = new_len;
                } else {
                    unreachable;
                }
                return new_data;
            }
            const T_FN_NTH_ID_FROM_START = @TypeOf(default_nth_index_from_start);
            fn default_nth_index_from_start(_: DATA_, n: ID_, _: USERDATA_) ID_ {
                return n;
            }
            const T_FN_LAST_ID = @TypeOf(default_last_index);
            fn default_last_index(data: DATA_, userdata: USERDATA_) ID_ {
                return default_len(data, userdata) - 1;
            }
            const T_FN_NTH_ID_FROM_END = @TypeOf(default_nth_index_from_end);
            fn default_nth_index_from_end(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                return default_len(data, userdata) - 1 - n;
            }
            const T_FN_PREV_ID = @TypeOf(default_prev_idx);
            fn default_prev_idx(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                return curr - 1;
            }
            const T_FN_NEXT_ID = @TypeOf(default_next_idx);
            fn default_next_idx(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                return curr + 1;
            }
            const T_FN_NTH_PREV_ID = @TypeOf(default_nth_prev_idx);
            fn default_nth_prev_idx(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                return curr - n;
            }
            const T_FN_NTH_NEXT_ID = @TypeOf(default_nth_next_idx);
            fn default_nth_next_idx(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                return curr + n;
            }
            const T_FN_RANGE_LEN = @TypeOf(default_range_len);
            fn default_range_len(_: DATA_, first: ID_, last: ID_, _: USERDATA_) ID_ {
                return (last + 1) - first;
            }
            const T_FN_VALID_ID = @TypeOf(default_valid_id);
            fn default_valid_id(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                return id >= 0 and id < default_len(data, userdata);
            }
            const T_FN_GET = @TypeOf(default_get);
            fn default_get(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                return default_get_base_ptr(data, userdata)[id];
            }
            const T_FN_GET_PTR = @TypeOf(default_get_ptr);
            fn default_get_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *ELEM_ {
                return &default_get_base_ptr(data, userdata)[id];
            }
            const T_FN_GET_CONST_PTR = @TypeOf(default_get_const_ptr);
            fn default_get_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                return &default_get_base_ptr(data, userdata)[id];
            }
            const T_FN_SET = @TypeOf(default_set);
            fn default_set(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                const new_data = data;
                default_get_base_ptr(new_data, userdata)[id] = val;
                return new_data;
            }
            const T_FN_SWAP = @TypeOf(default_swap);
            fn default_swap(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                var new_data = data;
                const tmp = default_get(new_data, id_b, userdata);
                new_data = default_set(new_data, id_b, default_get(new_data, id_a, userdata), userdata);
                new_data = default_set(new_data, id_a, tmp, userdata);
                return new_data;
            }
            const T_FN_GREATER_THAN = @TypeOf(default_greater_than);
            fn default_greater_than(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return val_a > val_b;
            }
            const T_FN_GREATER_THAN_OR_EQUAL = @TypeOf(default_greater_than_or_equal);
            fn default_greater_than_or_equal(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return val_a >= val_b;
            }
            const T_FN_LESS_THAN = @TypeOf(default_less_than);
            fn default_less_than(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return val_a < val_b;
            }
            const T_FN_LESS_THAN_OR_EQUAL = @TypeOf(default_less_than_or_equal);
            fn default_less_than_or_equal(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return val_a <= val_b;
            }
            const T_FN_EQUALS = @TypeOf(default_equals);
            fn default_equals(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                return val_a == val_b;
            }
            const T_FN_REVERSE = @TypeOf(default_reverse_range);
            fn default_reverse_range(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                const new_data = data;
                Utils.Mem.reverse_slice(default_get_base_ptr(new_data, userdata)[first .. last + 1]);
                return new_data;
            }
            const T_FN_MOVE_ONE_PRESERVE = @TypeOf(default_move_one_preserve);
            fn default_move_one_preserve(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                assert_with_reason(old_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ old_id, default_len(data, userdata) });
                assert_with_reason(new_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_id, default_len(data, userdata) });
                var new_data = data;
                if (old_id == new_id) return data;
                if (old_id < new_id) {
                    const old_val = default_get(data, old_id, userdata);
                    var i = old_id;
                    var ii = i;
                    while (i != new_id) {
                        i += 1;
                        const val_to_move = default_get(data, i, userdata);
                        new_data = default_set(new_data, ii, val_to_move, userdata);
                        ii = i;
                    }
                    new_data = default_set(new_data, new_id, old_val, userdata);
                } else {
                    const old_val = default_get(data, old_id, userdata);
                    var i = old_id;
                    var ii = i;
                    while (i != new_id) {
                        i -= 1;
                        const val_to_move = default_get(data, i, userdata);
                        new_data = default_set(new_data, ii, val_to_move, userdata);
                        ii = i;
                    }
                    new_data = default_set(new_data, new_id, old_val, userdata);
                }
                return new_data;
            }
            const T_FN_MOVE_BLOCK_PRESERVE = @TypeOf(default_move_block_preserve);
            fn default_move_block_preserve(data: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                assert_with_reason(first_old_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ first_old_id, default_len(data, userdata) });
                assert_with_reason(last_old_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ last_old_id, default_len(data, userdata) });
                assert_with_reason(new_first_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_first_id, default_len(data, userdata) });
                assert_with_reason(first_old_id <= last_old_id, @src(), "first id must be <= last id (by data order), got `{any}` > `{any}`", .{ first_old_id, last_old_id });
                var new_data = data;
                if (first_old_id == new_first_id) return data;
                const block_len = (last_old_id + 1) - first_old_id;
                if (first_old_id < new_first_id) {
                    const new_last_id = new_first_id + (block_len - 1);
                    assert_with_reason(new_last_id < default_len(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_last_id, default_len(data, userdata) });
                    const delta = new_first_id - first_old_id;
                    new_data = default_rotate_range_left(data, first_old_id, new_last_id, delta, userdata);
                } else {
                    const delta = first_old_id - new_first_id;
                    new_data = default_rotate_range_right(data, new_first_id, last_old_id, delta, userdata);
                }
                return new_data;
            }
            const T_FN_ROTATE_RIGHT = @TypeOf(default_rotate_range_right);
            fn default_rotate_range_right(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                if (last < first) return data;
                const end_exl = last + 1;
                const len = end_exl - first;
                const shift = count % len;
                if (shift == 0) return data;
                const edge = first + (len - shift);
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[first..edge]);
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[edge..end_exl]);
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[first..end_exl]);
                return data;
            }
            const T_FN_ROTATE_LEFT = @TypeOf(default_rotate_range_left);
            fn default_rotate_range_left(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                if (last < first) return data;
                const end_exl = last + 1;
                const len = end_exl - first;
                const shift = count % len;
                if (shift == 0) return data;
                const edge = first + shift;
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[first..edge]);
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[edge..end_exl]);
                Utils.Mem.reverse_slice(default_get_base_ptr(data, userdata)[first..end_exl]);
                return data;
            }
            const T_FN_SCRAMBLE = @TypeOf(default_scramble);
            fn default_scramble(data: DATA_, rand: Random, first: ID_, last: ID_, iterations: COUNT_, userdata: USERDATA_) DATA_ {
                var new_data = data;
                const span = (last + 1) - first;
                if (span <= 1) return data;
                if (span == 2) {
                    if (rand.boolean()) {
                        return default_swap(data, first, last);
                    }
                }
                var n: COUNT_ = 0;
                const first_idx = rand.intRangeAtMost(ID_, first, last);
                const first_val = default_get(data, first_idx, userdata);
                var empty_idx: ID_ = first_idx;
                while (n < iterations) : (n += 1) {
                    const move_idx = find_different_idx: {
                        while (true) {
                            const possible_different = rand.intRangeAtMost(ID_, first_idx, last);
                            if (possible_different != empty_idx) break :find_different_idx possible_different;
                        }
                    };
                    new_data = default_set(data, empty_idx, default_get(data, move_idx, userdata), userdata);
                    empty_idx = move_idx;
                }
                return default_set(new_data, empty_idx, first_val, userdata);
            }
            const DEFAULT_ALWAYS_INVALID_ID: ID_ = if (Types.type_is_int(ID_)) math.maxInt(ID_) else if (Types.type_is_optional(ID_)) null else undefined;

            pub const CustomDataFuncs = struct {
                ID_LESS_THAN_ID: ?T_FN_ID_LESS_THAN_ID = null,
                ID_LESS_THAN_OR_EQUAL_ID: ?T_FN_ID_LESS_THAN_OR_EQUAL_ID = null,
                ALWAYS_INVALID_ID: ?ID_ = null,
                GET: ?T_FN_GET = null,
                GET_PTR: ?T_FN_GET_PTR = null,
                GET_PTR_CONST: ?T_FN_GET_CONST_PTR = null,
                SET: ?T_FN_SET = null,
                FIELD_GET: FieldCustomGetters = .{},
                FIELD_GET_PTR: FieldCustomPtrGetters = .{},
                FIELD_GET_CONST_PTR: FieldCustomConstPtrGetters = .{},
                FIELD_SET: FieldCustomSetters = .{},
                SWAP: ?T_FN_SWAP = null,
                LESS_THAN: ?T_FN_LESS_THAN = null,
                LESS_THAN_OR_EQUAL: ?T_FN_LESS_THAN_OR_EQUAL = null,
                GREATER_THAN: ?T_FN_GREATER_THAN = null,
                GREATER_THAN_OR_EQUAL: ?T_FN_GREATER_THAN_OR_EQUAL = null,
                ORDER_EQUALS: ?T_FN_EQUALS = null,
                EXACT_EQUALS: ?T_FN_EQUALS = null,
                FIRST_ID: ?T_FN_FIRST_ID = null,
                LAST_ID: ?T_FN_LAST_ID = null,
                NTH_ID_FROM_START: ?T_FN_NTH_ID_FROM_START = null,
                NTH_ID_FROM_END: ?T_FN_NTH_ID_FROM_END = null,
                NEXT_ID: ?T_FN_NEXT_ID = null,
                PREV_ID: ?T_FN_PREV_ID = null,
                NTH_PREV_ID: ?T_FN_NTH_PREV_ID = null,
                NTH_NEXT_ID: ?T_FN_NTH_NEXT_ID = null,
                LEN: ?T_FN_LEN = null,
                SET_LEN: ?T_FN_SET_LEN = null,
                RANGE_LEN: ?T_FN_RANGE_LEN = null,
                VALID_ID: ?T_FN_VALID_ID = null,
                REVERSE_RANGE: ?T_FN_REVERSE = null,
                MOVE_ONE_PRESERVE: ?T_FN_MOVE_ONE_PRESERVE = null,
                MOVE_BLOCK_PRESERVE: ?T_FN_MOVE_BLOCK_PRESERVE = null,
                ROTATE_RANGE_RIGHT: ?T_FN_ROTATE_RIGHT = null,
                ROTATE_RANGE_LEFT: ?T_FN_ROTATE_LEFT = null,
                SCRAMBLE: ?T_FN_SCRAMBLE = null,
            };

            pub fn with_custom_functions(comptime ALLOW_DEFAULT: bool, comptime func: CustomDataFuncs) type {
                comptime {
                    //********
                    // BUILD FLAGS FOR PROVIDED CUSTOM FUNCTIONS
                    //********
                    var FLAGS = FuncFlags{};
                    var FIELD_FLAGS = FieldFlags{};
                    for (@typeInfo(F).@"struct".decls) |FNN| {
                        const FN_NAME = FNN.name;
                        if (std.mem.eql(u8, FN_NAME, "FIELD_GET") or std.mem.eql(u8, FN_NAME, "FIELD_GET_PTR") or std.mem.eql(u8, FN_NAME, "FIELD_GET_CONST_PTR") or std.mem.eql(u8, FN_NAME, "FIELD_SET")) continue;
                        FLAGS.add_if_not_null(@field(F, FN_NAME), @field(func, FN_NAME));
                    }
                    for (FieldInfoAsStructInfo_.field_names[0..]) |field_name| {
                        @field(&FIELD_FLAGS, field_name).add_if_not_null(F.GET, @field(func.FIELD_GET, field_name));
                        @field(&FIELD_FLAGS, field_name).add_if_not_null(F.GET_PTR, @field(func.FIELD_GET_PTR, field_name));
                        @field(&FIELD_FLAGS, field_name).add_if_not_null(F.GET_CONST_PTR, @field(func.FIELD_GET_CONST_PTR, field_name));
                        @field(&FIELD_FLAGS, field_name).add_if_not_null(F.SET, @field(func.FIELD_SET, field_name));
                    }
                    //********
                    // FUNCTION PROTOTYPE SELECTORS
                    //********
                    const PROTO = struct {
                        const ALWAYS_INVALID = if (func.ALWAYS_INVALID_ID) |INVALID| INVALID else DEFAULT_ALWAYS_INVALID_ID;
                        const VALID_ID = struct {
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `valid_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn unknown(_: DATA_, _: ID_, _: USERDATA_) bool {
                                return true;
                            }
                            fn select() T_FN_VALID_ID {
                                comptime {
                                    if (func.VALID_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_valid_id else unusable;
                                }
                            }
                            fn try_select() T_FN_VALID_ID {
                                comptime {
                                    if (func.VALID_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_valid_id else unknown;
                                }
                            }
                        };
                        fn assert_valid(data: DATA_, id: ID_, userdata: USERDATA_, comptime src: SourceLocation) bool {
                            const TRY_VALID = VALID_ID.try_select();
                            assert_with_reason(TRY_VALID(data, id, userdata), src, "id `{any}` is not valid for the current data structure state", .{id});
                        }
                        const ID_LESS_THAN_ID = struct {
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `id_a less than id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn unknown(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                                return true;
                            }
                            fn select() T_FN_ID_LESS_THAN_ID {
                                comptime {
                                    if (func.ID_LESS_THAN_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_id_less_than_id else unusable;
                                }
                            }
                            fn try_select() T_FN_ID_LESS_THAN_ID {
                                comptime {
                                    if (func.ID_LESS_THAN_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_id_less_than_id else unknown;
                                }
                            }
                        };
                        const ID_LESS_THAN_OR_EQUAL_ID = struct {
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) ELEM_ {
                                assert_unreachable(@src(), "no `id_a less than or equal id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn unknown(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                                return true;
                            }
                            fn select() T_FN_ID_LESS_THAN_OR_EQUAL_ID {
                                comptime {
                                    if (func.ID_LESS_THAN_OR_EQUAL_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_id_less_than_or_equal_id else unusable;
                                }
                            }
                            fn try_select() T_FN_ID_LESS_THAN_OR_EQUAL_ID {
                                comptime {
                                    if (func.ID_LESS_THAN_OR_EQUAL_ID) |f| f;
                                    return if (ALLOW_DEFAULT) default_id_less_than_or_equal_id else unknown;
                                }
                            }
                        };
                        const GET = struct {
                            fn infer_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                                assert_valid(data, id, userdata, @src());
                                return func.GET_PTR.?(data, id, userdata).*;
                            }
                            fn infer_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                                assert_valid(data, id, userdata, @src());
                                return func.GET_PTR_CONST.?(data, id, userdata).*;
                            }
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) ELEM_ {
                                assert_unreachable(@src(), "no `get` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GET {
                                comptime {
                                    if (FLAGS_.has(F.GET)) return func.GET.?;
                                    if (FLAGS_.has(INFER.GET_FROM_PTR)) return infer_ptr;
                                    if (FLAGS_.has(INFER.GET_FROM_CONST_PTR)) return infer_const_ptr;
                                    return if (ALLOW_DEFAULT) default_get else unusable;
                                }
                            }
                        };
                        const GET_PTR = struct {
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) *ELEM_ {
                                assert_unreachable(@src(), "no `get_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GET_PTR {
                                comptime {
                                    if (FLAGS_.has(F.GET_PTR)) return func.GET_PTR.?;
                                    return if (ALLOW_DEFAULT) default_get_ptr else unusable;
                                }
                            }
                        };
                        const GET_CONST_PTR = struct {
                            fn infer_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                                assert_valid(data, id, userdata, @src());
                                return func.GET_PTR.?(data, id, userdata);
                            }
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) *const ELEM_ {
                                assert_unreachable(@src(), "no `get_const_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GET_CONST_PTR {
                                comptime {
                                    if (FLAGS_.has(F.GET_CONST_PTR)) return func.GET_PTR_CONST.?;
                                    if (FLAGS_.has(INFER.CONST_PTR_FROM_PTR)) return infer_ptr;
                                    return if (ALLOW_DEFAULT) default_get_const_ptr else unusable;
                                }
                            }
                        };
                        const SET = struct {
                            fn infer_ptr(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, id, userdata, @src());
                                func.GET_PTR.?(data, id, userdata).* = val;
                                return data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ELEM_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `set` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_SET {
                                comptime {
                                    if (FLAGS_.has(F.SET)) return func.SET.?;
                                    if (FLAGS_.has(INFER.SET_FROM_PTR)) return infer_ptr;
                                    return if (ALLOW_DEFAULT) default_set else unusable;
                                }
                            }
                        };
                        const SWAP = struct {
                            fn infer_ptr(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, id_a, userdata, @src());
                                assert_valid(data, id_b, userdata, @src());
                                const GET_PTR_ = comptime GET_PTR.select(FLAGS);
                                const ptr_a = GET_PTR_(data, id_a, userdata);
                                const ptr_b = GET_PTR_(data, id_b, userdata);
                                const tmp = ptr_b.*;
                                ptr_b.* = ptr_a.*;
                                ptr_a.* = tmp;
                                return data;
                            }
                            fn infer_get_set(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                                const GET_ = comptime GET.select(FLAGS);
                                const SET_ = comptime SET.select(FLAGS);
                                assert_valid(data, id_a, userdata, @src());
                                assert_valid(data, id_b, userdata, @src());
                                const tmp = GET_(data, id_b, userdata);
                                const data_2 = SET_(data, id_b, GET_(data, id_a, userdata), userdata);
                                return SET_(data_2, id_a, tmp, userdata);
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `swap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_SWAP {
                                comptime {
                                    if (FLAGS_.has(F.SWAP)) return func.SWAP.?;
                                    if (FLAGS_.has(INFER.SWAP_FROM_PTR)) return infer_ptr;
                                    if (FLAGS_.has(INFER.SWAP_FROM_GET_SET)) return infer_get_set;
                                    return if (ALLOW_DEFAULT) default_swap else unusable;
                                }
                            }
                        };
                        const LESS_THAN = struct {
                            fn infer_gteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GTEQ = comptime GREATER_THAN_OR_EQUAL.select(FLAGS);
                                return !GTEQ(val_a, val_b, userdata);
                            }
                            fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const EQ = comptime EXACT_EQUAL.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                            }
                            fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const OQ = comptime ORDER_EQUAL.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `less_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_LESS_THAN {
                                comptime {
                                    if (FLAGS_.has(F.LESS_THAN)) return func.LESS_THAN.?;
                                    if (FLAGS_.has(INFER.LT_FROM_GTEQ)) return infer_gteq;
                                    if (FLAGS_.has(INFER.LT_FROM_GT_OQ)) return infer_gt_oq;
                                    if (FLAGS_.has(INFER.LT_FROM_GT_EQ)) return infer_gt_eq;
                                    return if (ALLOW_DEFAULT) default_less_than else unusable;
                                }
                            }
                        };
                        const LESS_THAN_OR_EQUAL = struct {
                            fn infer_gt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                return !GT(val_a, val_b, userdata);
                            }
                            fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LT = comptime LESS_THAN.select(FLAGS);
                                const EQ = comptime EXACT_EQUAL.select(FLAGS);
                                return LT(val_a, val_b, userdata) or EQ(val_a, val_b, userdata);
                            }
                            fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LT = comptime LESS_THAN.select(FLAGS);
                                const OQ = comptime ORDER_EQUAL.select(FLAGS);
                                return LT(val_a, val_b, userdata) or OQ(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `less_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_LESS_THAN_OR_EQUAL {
                                comptime {
                                    if (FLAGS_.has(F.LESS_THAN_OR_EQUAL)) return func.LESS_THAN_OR_EQUAL.?;
                                    if (FLAGS_.has(INFER.LTEQ_FROM_GT)) return infer_gt;
                                    if (FLAGS_.has(INFER.LTEQ_FROM_LT_OQ)) return infer_lt_oq;
                                    if (FLAGS_.has(INFER.LTEQ_FROM_LT_EQ)) return infer_lt_eq;
                                    return if (ALLOW_DEFAULT) default_less_than_or_equal else unusable;
                                }
                            }
                        };
                        const GREATER_THAN = struct {
                            fn infer_lteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LTEQ = comptime LESS_THAN_OR_EQUAL.select(FLAGS);
                                return !LTEQ(val_a, val_b, userdata);
                            }
                            fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LT = comptime LESS_THAN.select(FLAGS);
                                const EQ = comptime EXACT_EQUAL.select(FLAGS);
                                return !LT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                            }
                            fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LT = comptime LESS_THAN.select(FLAGS);
                                const OQ = comptime ORDER_EQUAL.select(FLAGS);
                                return !LT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `greater_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GREATER_THAN {
                                comptime {
                                    if (FLAGS_.has(F.GREATER_THAN)) return func.GREATER_THAN.?;
                                    if (FLAGS_.has(INFER.GT_FROM_LTEQ)) return infer_lteq;
                                    if (FLAGS_.has(INFER.GT_FROM_LT_OQ)) return infer_lt_oq;
                                    if (FLAGS_.has(INFER.GT_FROM_LT_EQ)) return infer_lt_eq;
                                    return if (ALLOW_DEFAULT) default_greater_than else unusable;
                                }
                            }
                        };
                        const GREATER_THAN_OR_EQUAL = struct {
                            fn infer_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const LT = comptime LESS_THAN.select(FLAGS);
                                return !LT(val_a, val_b, userdata);
                            }
                            fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const EQ = comptime EXACT_EQUAL.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                            }
                            fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const OQ = comptime ORDER_EQUAL.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `greater_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GREATER_THAN_OR_EQUAL {
                                comptime {
                                    if (FLAGS_.has(F.GREATER_THAN_OR_EQUAL)) return func.GREATER_THAN_OR_EQUAL.?;
                                    if (FLAGS_.has(INFER.GTEQ_FROM_LT)) return infer_lt;
                                    if (FLAGS_.has(INFER.GTEQ_FROM_GT_OQ)) return infer_gt_oq;
                                    if (FLAGS_.has(INFER.GTEQ_FROM_GT_EQ)) return infer_gt_eq;
                                    return if (ALLOW_DEFAULT) default_greater_than_or_equal else unusable;
                                }
                            }
                        };
                        const ORDER_EQUAL = struct {
                            fn infer_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const EQ = comptime EXACT_EQUAL.select(FLAGS);
                                return !EQ(val_a, val_b, userdata);
                            }
                            fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const LT = comptime LESS_THAN.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !LT(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `order_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_EQUALS {
                                comptime {
                                    if (FLAGS_.has(F.ORDER_EQUALS)) return func.ORDER_EQUALS.?;
                                    if (FLAGS_.has(INFER.OQ_FROM_EQ)) return infer_eq;
                                    if (FLAGS_.has(INFER.EQOQ_FROM_GT_LT)) return infer_gt_lt;
                                    return if (ALLOW_DEFAULT) default_equals else unusable;
                                }
                            }
                        };
                        const EXACT_EQUAL = struct {
                            fn infer_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const OQ = comptime ORDER_EQUAL.select(FLAGS);
                                return !OQ(val_a, val_b, userdata);
                            }
                            fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                                const GT = comptime GREATER_THAN.select(FLAGS);
                                const LT = comptime LESS_THAN.select(FLAGS);
                                return !GT(val_a, val_b, userdata) and !LT(val_a, val_b, userdata);
                            }
                            fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                                assert_unreachable(@src(), "no `exactly_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_EQUALS {
                                comptime {
                                    if (FLAGS_.has(F.EXACT_EQUALS)) return func.EXACT_EQUALS.?;
                                    if (FLAGS_.has(INFER.EQ_FROM_OQ)) return infer_oq;
                                    if (FLAGS_.has(INFER.EQOQ_FROM_GT_LT)) return infer_gt_lt;
                                    return if (ALLOW_DEFAULT) default_equals else unusable;
                                }
                            }
                        };
                        const FIRST_ID = struct {
                            fn infer_nth_start(data: DATA_, userdata: USERDATA_) ID_ {
                                const NTH_START = comptime NTH_FROM_START.select(FLAGS);
                                return NTH_START(data, 0, userdata);
                            }
                            fn infer_nth_end(data: DATA_, userdata: USERDATA_) ID_ {
                                const NTH_END = comptime NTH_FROM_END.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                return NTH_END(data, LEN_(data, userdata), userdata);
                            }
                            fn infer_last_len_nth_prev(data: DATA_, userdata: USERDATA_) ID_ {
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                const NTH_PREV_ = comptime NTH_PREV_ID.select(FLAGS);
                                return NTH_PREV_(data, LAST(data, userdata), LEN_(data, userdata), userdata);
                            }
                            fn infer_last_len_prev(data: DATA_, userdata: USERDATA_) ID_ {
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                const PREV_ = comptime PREV_ID.select(FLAGS);
                                var l = LEN_(data, userdata);
                                var i = LAST(data, userdata);
                                while (l > 0) : (l -= 1) {
                                    i = PREV_(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `first_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_FIRST_ID {
                                comptime {
                                    if (FLAGS_.has(F.FIRST_INDEX)) return func.FIRST_ID.?;
                                    if (FLAGS_.has(INFER.FIRST_FROM_NTH_FROM_START)) return infer_nth_start;
                                    if (FLAGS_.has(INFER.FIRST_FROM_LEN_NTH_FROM_END)) return infer_nth_end;
                                    if (FLAGS_.has(INFER.FIRST_FROM_LAST_LEN_NTH_PREV)) return infer_last_len_nth_prev;
                                    if (FLAGS_.has(INFER.FIRST_FROM_LAST_LEN_PREV)) return infer_last_len_prev;
                                    return if (ALLOW_DEFAULT) default_first_index else unusable;
                                }
                            }
                        };
                        const LAST_ID = struct {
                            fn infer_nth_last(data: DATA_, userdata: USERDATA_) ID_ {
                                const NTH_START = comptime NTH_FROM_START.select(FLAGS);
                                return NTH_START(data, 0, userdata);
                            }
                            fn infer_nth_start(data: DATA_, userdata: USERDATA_) ID_ {
                                const NTH_START = comptime NTH_FROM_START.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                return NTH_START(data, LEN_(data, userdata), userdata);
                            }
                            fn infer_first_len_nth_next(data: DATA_, userdata: USERDATA_) ID_ {
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                const NTH_NEXT_ = comptime NTH_PREV_ID.select(FLAGS);
                                return NTH_NEXT_(data, FIRST(data, userdata), LEN_(data, userdata), userdata);
                            }
                            fn infer_first_len_next(data: DATA_, userdata: USERDATA_) ID_ {
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const LEN_ = comptime GET_LEN.select(FLAGS);
                                const NEXT_ = comptime NEXT_ID.select(FLAGS);
                                var l = LEN_(data, userdata);
                                var i = FIRST(data, userdata);
                                while (l > 0) : (l -= 1) {
                                    i = NEXT_(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `last_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_LAST_ID {
                                comptime {
                                    if (FLAGS_.has(F.LAST_INDEX)) return func.LAST_ID.?;
                                    if (FLAGS_.has(INFER.LAST_FROM_NTH_FROM_LAST)) return infer_nth_last;
                                    if (FLAGS_.has(INFER.LAST_FROM_LEN_NTH_FROM_START)) return infer_nth_start;
                                    if (FLAGS_.has(INFER.LAST_FROM_FIRST_LEN_NTH_NEXT)) return infer_first_len_nth_next;
                                    if (FLAGS_.has(INFER.LAST_FROM_FIRST_LEN_NEXT)) return infer_first_len_next;
                                    return if (ALLOW_DEFAULT) default_last_index else unusable;
                                }
                            }
                        };
                        const NEXT_ID = struct {
                            fn infer_nth_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const NTH_NEXT = comptime NTH_NEXT_ID.select(FLAGS);
                                return NTH_NEXT(data, curr, 1, userdata);
                            }
                            fn infer_last_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                var i = LAST(data, userdata);
                                if (i == curr) return ALWAYS_INVALID;
                                var ii = PREV(data, i, userdata);
                                while (ii != curr) {
                                    if (!VALID_ID(data, ii, userdata)) return ALWAYS_INVALID;
                                    i = ii;
                                    ii = PREV(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_NEXT_ID {
                                comptime {
                                    if (FLAGS_.has(F.NEXT_INDEX)) return func.NEXT_ID.?;
                                    if (FLAGS_.has(INFER.NEXT_IDX_FROM_NTH_NEXT)) return infer_nth_next;
                                    if (FLAGS_.has(INFER.NEXT_IDX_FROM_LAST_PREV)) return infer_last_prev;
                                    return if (ALLOW_DEFAULT) default_next_idx else unusable;
                                }
                            }
                        };
                        const PREV_ID = struct {
                            fn infer_nth_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const NTH_PREV = comptime NTH_PREV_ID.select(FLAGS);
                                return NTH_PREV(data, curr, 1, userdata);
                            }
                            fn infer_first_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                var i = FIRST(data, userdata);
                                if (i == curr) return ALWAYS_INVALID;
                                var ii = NEXT(data, i, userdata);
                                while (ii != curr) {
                                    if (!VALID_ID(data, ii, userdata)) return ALWAYS_INVALID;
                                    i = ii;
                                    ii = NEXT(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `prev_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_PREV_ID {
                                comptime {
                                    if (FLAGS_.has(F.PREV_INDEX)) return func.PREV_ID.?;
                                    if (FLAGS_.has(INFER.PREV_IDX_FROM_NTH_PREV)) return infer_nth_prev;
                                    if (FLAGS_.has(INFER.PREV_IDX_FROM_FIRST_NEXT)) return infer_first_next;
                                    return if (ALLOW_DEFAULT) default_next_idx else unusable;
                                }
                            }
                        };
                        const NTH_NEXT_ID = struct {
                            fn infer_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                var i = curr;
                                var nn: COUNT_ = 0;
                                while (nn < n) : (nn += 1) {
                                    i = NEXT(data, i, userdata);
                                }
                                return i;
                            }
                            fn infer_last_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const last = LAST(data, userdata);
                                var left_i = last;
                                var nn: COUNT_ = 0;
                                while (nn < n) : (nn += 1) {
                                    if (left_i == curr or !VALID_ID(data, left_i, userdata)) return ALWAYS_INVALID;
                                    left_i = PREV(data, curr, userdata);
                                }
                                var right_i = last;
                                var left_ii = PREV(data, left_i, userdata);
                                var right_ii = PREV(data, last, userdata);
                                while (left_ii != curr) {
                                    left_i = left_ii;
                                    left_ii = PREV(data, left_i, userdata);
                                    if (!VALID_ID(data, left_ii, userdata)) return ALWAYS_INVALID;
                                    right_i = right_ii;
                                    right_ii = PREV(data, right_i, userdata);
                                }
                                return right_i;
                            }
                            fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `nth_next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_NTH_NEXT_ID {
                                comptime {
                                    if (FLAGS_.has(F.NTH_NEXT_INDEX)) return func.NTH_PREV_ID.?;
                                    if (FLAGS_.has(INFER.NTH_NEXT_IDX_FROM_NEXT)) return infer_next;
                                    if (FLAGS_.has(INFER.NTH_NEXT_IDX_FROM_LAST_PREV)) return infer_last_prev;
                                    return if (ALLOW_DEFAULT) default_next_idx else unusable;
                                }
                            }
                        };
                        const NTH_PREV_ID = struct {
                            fn infer_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const PREV = comptime PREV_ID.select(FLAGS);
                                var i = curr;
                                var nn: COUNT_ = 0;
                                while (nn < n) : (nn += 1) {
                                    i = PREV(data, i, userdata);
                                }
                                return i;
                            }
                            fn infer_first_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                                assert_valid(data, curr, userdata, @src());
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                const first = FIRST(data, userdata);
                                var right_i = first;
                                var nn: COUNT_ = 0;
                                while (nn < n) : (nn += 1) {
                                    if (right_i == curr or !VALID_ID(data, right_i, userdata)) return ALWAYS_INVALID;
                                    right_i = NEXT(data, curr, userdata);
                                }
                                var left_i = first;
                                var right_ii = NEXT(data, right_i, userdata);
                                var left_ii = NEXT(data, first, userdata);
                                while (right_ii != curr) {
                                    right_i = right_ii;
                                    right_ii = NEXT(data, right_i, userdata);
                                    if (!VALID_ID(data, right_ii, userdata)) return ALWAYS_INVALID;
                                    left_i = left_ii;
                                    left_ii = NEXT(data, left_i, userdata);
                                }
                                return left_i;
                            }
                            fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `nth_prev_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_NTH_PREV_ID {
                                comptime {
                                    if (FLAGS_.has(F.NTH_PREV_INDEX)) return func.NTH_PREV_ID.?;
                                    if (FLAGS_.has(INFER.NTH_PREV_IDX_FROM_PREV)) return infer_prev;
                                    if (FLAGS_.has(INFER.NTH_PREV_IDX_FROM_FIRST_NEXT)) return infer_first_next;
                                    return if (ALLOW_DEFAULT) default_nth_prev_idx else unusable;
                                }
                            }
                        };
                        const NTH_FROM_START = struct {
                            fn infer_first_nth_next(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                                const NTH_NEXT = comptime NTH_NEXT_ID.select(FLAGS);
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                return NTH_NEXT(data, FIRST(data, userdata), n, userdata);
                            }
                            fn infer_first_next(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                var nn: COUNT_ = 0;
                                var i = FIRST(data, userdata);
                                while (nn < n) : (nn += 1) {
                                    i = NEXT(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `nth_index_from_start` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_NTH_ID_FROM_START {
                                comptime {
                                    if (FLAGS_.has(F.NTH_INDEX_FROM_START)) return func.NTH_ID_FROM_START.?;
                                    if (FLAGS_.has(INFER.NTH_FROM_START_FROM_FIRST_NTH_NEXT)) return infer_first_nth_next;
                                    if (FLAGS_.has(INFER.NTH_FROM_START_FROM_FIRST_NEXT)) return infer_first_next;
                                    return if (ALLOW_DEFAULT) default_nth_index_from_start else unusable;
                                }
                            }
                        };
                        const NTH_FROM_END = struct {
                            fn infer_last_nth_prev(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                                const NTH_PREV = comptime NTH_PREV_ID.select(FLAGS);
                                const LAST = comptime LAST_ID.select(FLAGS);
                                return NTH_PREV(data, LAST(data, userdata), n, userdata);
                            }
                            fn infer_last_prev(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const LAST = comptime LAST_ID.select(FLAGS);
                                var nn: COUNT_ = 0;
                                var i = LAST(data, userdata);
                                while (nn < n) : (nn += 1) {
                                    i = PREV(data, i, userdata);
                                }
                                return i;
                            }
                            fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) ID_ {
                                assert_unreachable(@src(), "no `nth_index_from_end` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_NTH_ID_FROM_END {
                                comptime {
                                    if (FLAGS_.has(F.NTH_INDEX_FROM_END)) return func.NTH_ID_FROM_END.?;
                                    if (FLAGS_.has(INFER.NTH_FROM_END_FROM_LAST_NTH_PREV)) return infer_last_nth_prev;
                                    if (FLAGS_.has(INFER.NTH_FROM_END_FROM_LAST_PREV)) return infer_last_prev;
                                    return if (ALLOW_DEFAULT) default_nth_index_from_end else unusable;
                                }
                            }
                        };
                        const GET_LEN = struct {
                            fn infer_range_len(data: DATA_, userdata: USERDATA_) COUNT_ {
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const RANGE = comptime RANGE_LEN.select(FLAGS);
                                return RANGE(FIRST(data, userdata), LAST(data, userdata), userdata);
                            }
                            fn infer_first_last_next(data: DATA_, userdata: USERDATA_) COUNT_ {
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);

                                var i = FIRST(data, userdata);
                                const last = LAST(data, userdata);
                                if (!VALID_ID(data, i, userdata) or !VALID_ID(data, last, userdata)) return 0;
                                var n: COUNT_ = 1;
                                while (i != last) : (n += 1) {
                                    i = NEXT(data, i, userdata);
                                }
                                return n;
                            }
                            fn infer_first_last_prev(data: DATA_, userdata: USERDATA_) COUNT_ {
                                const FIRST = comptime FIRST_ID.select(FLAGS);
                                const LAST = comptime LAST_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                var i = LAST(data, userdata);
                                const first = FIRST(data, userdata);
                                if (!VALID_ID(data, i, userdata) or !VALID_ID(data, first, userdata)) return 0;
                                var n: COUNT_ = 1;
                                while (i != first) : (n += 1) {
                                    i = PREV(data, i, userdata);
                                }
                                return n;
                            }
                            fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                                assert_unreachable(@src(), "no `len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_GET {
                                comptime {
                                    if (FLAGS_.has(F.GET_LEN)) return func.LEN.?;
                                    if (FLAGS_.has(INFER.LEN_FROM_FIRST_LAST_RANGE_LEN)) return infer_range_len;
                                    if (FLAGS_.has(INFER.LEN_FROM_FIRST_LAST_NEXT)) return infer_first_last_next;
                                    if (FLAGS_.has(INFER.LEN_FROM_FIRST_LAST_PREV)) return infer_first_last_prev;
                                    return if (ALLOW_DEFAULT) default_len else unusable;
                                }
                            }
                        };
                        const SET_LEN = struct {
                            fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                                assert_unreachable(@src(), "no `set_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_SET_LEN {
                                comptime {
                                    if (FLAGS_.has(F.SET_LEN)) return func.SET_LEN.?;
                                    return if (ALLOW_DEFAULT) default_set_len else unusable;
                                }
                            }
                        };
                        const RANGE_LEN = struct {
                            fn infer_next(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                assert_valid(data, first, userdata, @src());
                                assert_valid(data, last, userdata, @src());
                                const TRY_ID_LESS_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.try_select(FLAGS);
                                if (!TRY_ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                                var i = first;
                                var n: COUNT_ = 1;
                                while (i != last) {
                                    if (!VALID_ID(data, i, userdata)) return 0;
                                    i = NEXT(data, i, userdata);
                                    n += 1;
                                }
                                return n;
                            }
                            fn infer_prev(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                                assert_valid(data, first, userdata, @src());
                                assert_valid(data, last, userdata, @src());
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const TRY_ID_LESS_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.try_select(FLAGS);
                                if (!TRY_ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                                var i = last;
                                var n: COUNT_ = 1;
                                while (i != first) {
                                    if (!VALID_ID(data, i, userdata)) return 0;
                                    i = PREV(data, i, userdata);
                                    n += 1;
                                }
                                return n;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) COUNT_ {
                                assert_unreachable(@src(), "no `range_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_RANGE_LEN {
                                comptime {
                                    if (FLAGS_.has(F.RANGE_LEN)) return func.RANGE_LEN.?;
                                    if (FLAGS_.has(INFER.RANGE_LEN_FROM_NEXT)) return infer_next;
                                    if (FLAGS_.has(INFER.RANGE_LEN_FROM_PREV)) return infer_prev;
                                    return if (ALLOW_DEFAULT) default_range_len else unusable;
                                }
                            }
                        };
                        const REVERSE_RANGE = struct {
                            fn infer_swap(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, first, userdata, @src());
                                assert_valid(data, last, userdata, @src());
                                const SWAP_ = comptime SWAP.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const TRY_ID_LESS_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.try_select(FLAGS);
                                if (!TRY_ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                                var new_data = data;
                                var left = first;
                                var right = last;
                                while (first != last) {
                                    new_data = SWAP_(new_data, left, right, userdata);
                                    left = NEXT(data, left, userdata);
                                    if (left == right) break;
                                    right = PREV(new_data, right, userdata);
                                }
                                return new_data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `range_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_REVERSE {
                                comptime {
                                    if (FLAGS_.has(F.REVERSE_RANGE)) return func.REVERSE_RANGE.?;
                                    if (FLAGS_.has_any(&.{ INFER.REVERSE_FROM_GET_SET, INFER.REVERSE_FROM_SWAP })) return infer_swap;
                                    return if (ALLOW_DEFAULT) default_reverse_range else unusable;
                                }
                            }
                        };
                        const ROTATE_RIGHT = struct {
                            fn infer_reverse(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, first, userdata, @src());
                                assert_valid(data, last, userdata, @src());
                                const REV = comptime REVERSE_RANGE.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                const NTH_PREV = comptime NTH_PREV_ID.select(FLAGS);
                                const TRY_ID_LESS_THAN_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.try_select();
                                const RANGE_LEN_ = comptime RANGE_LEN.select(FLAGS);
                                if (!TRY_ID_LESS_THAN_OR_EQUAL(data, first, last, userdata)) return data;
                                var new_data = data;
                                const len = RANGE_LEN_(data, first, last, userdata);
                                const shift = count % len;
                                if (shift == 0) return data;
                                const first_group_last_id = NTH_PREV(data, last, shift, userdata);
                                const last_group_first_id = NEXT(data, first_group_last_id, userdata);
                                new_data = REV(new_data, first, first_group_last_id, userdata);
                                new_data = REV(new_data, last_group_first_id, last, new_data);
                                new_data = REV(new_data, first, last, new_data);
                                return new_data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `rotate_range_right` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_ROTATE_RIGHT {
                                comptime {
                                    if (FLAGS_.has(F.ROTATE_RANGE_RIGHT)) return func.ROTATE_RANGE_RIGHT.?;
                                    if (FLAGS_.has_any(&.{ INFER.ROTATE_FROM_GET_SET, INFER.ROTATE_FROM_REVERSE, INFER.ROTATE_FROM_SWAP })) return infer_reverse;
                                    return if (ALLOW_DEFAULT) default_rotate_range_right else unusable;
                                }
                            }
                        };
                        const ROTATE_LEFT = struct {
                            fn infer_reverse(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, first, userdata, @src());
                                assert_valid(data, last, userdata, @src());
                                const REV = comptime REVERSE_RANGE.select(FLAGS);
                                const NTH_NEXT = comptime NTH_NEXT_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const TRY_ID_LESS_THAN_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.try_select();
                                const RANGE_LEN_ = comptime RANGE_LEN.select(FLAGS);
                                if (!TRY_ID_LESS_THAN_OR_EQUAL(data, first, last, userdata)) return data;
                                var new_data = data;
                                const len = RANGE_LEN_(data, first, last, userdata);
                                const shift = count % len;
                                if (shift == 0) return data;
                                const last_group_first_id = NTH_NEXT(data, last, shift, userdata);
                                const first_group_last_id = PREV(data, last_group_first_id, userdata);
                                new_data = REV(new_data, first, first_group_last_id, userdata);
                                new_data = REV(new_data, last_group_first_id, last, new_data);
                                new_data = REV(new_data, first, last, new_data);
                                return new_data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `rotate_range_left` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_ROTATE_RIGHT {
                                comptime {
                                    if (FLAGS_.has(F.ROTATE_RANGE_LEFT)) return func.ROTATE_RANGE_LEFT.?;
                                    if (FLAGS_.has_any(&.{ INFER.ROTATE_FROM_GET_SET, INFER.ROTATE_FROM_REVERSE, INFER.ROTATE_FROM_SWAP })) return infer_reverse;
                                    return if (ALLOW_DEFAULT) default_rotate_range_right else unusable;
                                }
                            }
                        };
                        const MOVE_ONE_PRESERVE = struct {
                            fn infer_move_block(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                                const MOVE_BLOCK = comptime MOVE_BLOCK_PRESERVE.select(FLAGS);
                                return MOVE_BLOCK(data, old_id, old_id, new_id, userdata);
                            }
                            fn infer_get_set(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, old_id, userdata, @src());
                                assert_valid(data, new_id, userdata, @src());
                                const GET_ = comptime GET.select(FLAGS);
                                const SET_ = comptime SET.select(FLAGS);
                                const NEXT = comptime NEXT_ID.select(FLAGS);
                                const PREV = comptime PREV_ID.select(FLAGS);
                                const ID_LESS_THAN_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.select();
                                var new_data = data;
                                if (old_id == new_id) return data;
                                if (ID_LESS_THAN_OR_EQUAL(data, old_id, new_id, userdata)) {
                                    const old_val = GET_(data, old_id, userdata);
                                    var i = old_id;
                                    var ii = i;
                                    while (i != new_id) {
                                        i = NEXT(data, i, userdata);
                                        const val_to_move = GET_(new_data, i, userdata);
                                        new_data = SET_(new_data, ii, val_to_move, userdata);
                                        ii = i;
                                    }
                                    new_data = SET_(data, new_id, old_val, userdata);
                                } else {
                                    const old_val = GET_(data, old_id, userdata);
                                    var i = old_id;
                                    var ii = i;
                                    while (i != new_id) {
                                        i = PREV(data, i, userdata);
                                        const val_to_move = GET_(new_data, i, userdata);
                                        new_data = SET_(new_data, ii, val_to_move, userdata);
                                        ii = i;
                                    }
                                    new_data = SET_(data, new_id, old_val, userdata);
                                }
                                return new_data;
                            }
                            fn infer_rotate(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, old_id, userdata, @src());
                                assert_valid(data, new_id, userdata, @src());
                                const ROT_L = comptime ROTATE_LEFT.select(FLAGS);
                                const ROT_R = comptime ROTATE_RIGHT.select(FLAGS);
                                const ID_LESS_THAN_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.select();
                                var new_data = data;
                                if (old_id == new_id) return data;
                                if (ID_LESS_THAN_OR_EQUAL(data, old_id, new_id, userdata)) {
                                    new_data = ROT_L(data, old_id, new_id, 1, userdata);
                                } else {
                                    new_data = ROT_R(data, new_id, old_id, 1, userdata);
                                }
                                return new_data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `move_one_element_preserve_displaced_elements` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_MOVE_ONE_PRESERVE {
                                comptime {
                                    if (FLAGS_.has(F.MOVE_ONE_PRESERVE)) return func.MOVE_ONE_PRESERVE.?;
                                    if (FLAGS_.has(INFER.MOVE_ONE_FROM_GET_SET)) return infer_get_set;
                                    if (FLAGS_.has(INFER.MOVE_ONE_FROM_MOVE_BLOCK)) return infer_move_block;
                                    if (FLAGS_.has_any(&.{ INFER.MOVE_FROM_GET_SET, INFER.MOVE_FROM_REVERSE, INFER.MOVE_FROM_SWAP, INFER.MOVE_FROM_ROTATE })) return infer_rotate;
                                    return if (ALLOW_DEFAULT) default_move_one_preserve else unusable;
                                }
                            }
                        };
                        const MOVE_BLOCK_PRESERVE = struct {
                            fn infer_rotate(data: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                                assert_valid(data, first_old_id, userdata, @src());
                                assert_valid(data, last_old_id, userdata, @src());
                                assert_valid(data, new_first_id, userdata, @src());
                                const ROT_L = comptime ROTATE_LEFT.select(FLAGS);
                                const ROT_R = comptime ROTATE_RIGHT.select(FLAGS);
                                const RANGE_LEN_ = comptime RANGE_LEN.select(FLAGS);
                                const NTH_NEXT = comptime NTH_NEXT_ID.select(FLAGS);
                                const ID_LESS_THAN_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL_ID.select();
                                assert_with_reason(ID_LESS_THAN_OR_EQUAL(data, first_old_id, last_old_id, userdata), @src(), "first id must be <= last id (by data order), got `{any}` > `{any}`", .{ first_old_id, last_old_id });
                                var new_data = data;
                                if (first_old_id == new_first_id) return data;
                                const block_len = RANGE_LEN_(data, first_old_id, last_old_id, userdata);
                                if (ID_LESS_THAN_OR_EQUAL(data, first_old_id, new_first_id, userdata)) {
                                    const new_last_id = NTH_NEXT(data, new_first_id, block_len - 1, userdata);
                                    assert_valid(data, new_last_id, userdata, @src());
                                    const delta = RANGE_LEN_(data, first_old_id, new_first_id, userdata) - 1;
                                    new_data = ROT_L(data, first_old_id, new_last_id, delta, userdata);
                                } else {
                                    const delta = RANGE_LEN_(data, new_first_id, first_old_id, userdata) - 1;
                                    new_data = ROT_R(data, new_first_id, last_old_id, delta, userdata);
                                }
                                return new_data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `move_element_block_preserve_displaced_elements` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                            }
                            fn select(comptime FLAGS_: FuncFlags) T_FN_MOVE_BLOCK_PRESERVE {
                                comptime {
                                    if (FLAGS_.has(F.MOVE_BLOCK_PRESERVE)) return func.MOVE_BLOCK_PRESERVE.?;
                                    if (FLAGS_.has_any(&.{ INFER.MOVE_FROM_GET_SET, INFER.MOVE_FROM_REVERSE, INFER.MOVE_FROM_SWAP, INFER.MOVE_FROM_ROTATE })) return infer_rotate;
                                    return if (ALLOW_DEFAULT) default_move_block_preserve else unusable;
                                }
                            }
                        };
                    };
                    //********
                    // SELECT THE CORRECT FUNCTION FOR EACH
                    //********
                    var FINAL_FUNCS: DEF_WITH_FUNCS = DEF_WITH_FUNCS{
                        .FIRST_ID = PROTO.FIRST_ID.select(FLAGS),
                        .LAST_ID = PROTO.LAST_ID.select(FLAGS),
                        .NTH_ID_FROM_START = PROTO.NTH_FROM_START.select(FLAGS),
                        .NTH_ID_FROM_END = PROTO.NTH_FROM_END.select(FLAGS),
                        .PREV_ID = PROTO.PREV_ID.select(FLAGS),
                        .NEXT_ID = PROTO.NEXT_ID.select(FLAGS),
                        .NTH_PREV_ID = PROTO.NTH_PREV_ID.select(FLAGS),
                        .NTH_NEXT_ID = PROTO.NTH_NEXT_ID.select(FLAGS),
                        .GET_LEN = PROTO.GET_LEN.select(FLAGS),
                        .SET_LEN = PROTO.SET_LEN.select(FLAGS),
                        .RANGE_LEN = PROTO.RANGE_LEN.select(FLAGS),
                        .VALID_ID = PROTO.VALID_ID,
                        .GET = PROTO.GET.select(FLAGS),
                        .GET_PTR = PROTO.GET_PTR.select(FLAGS),
                        .GET_CONST_PTR = PROTO.GET_CONST_PTR.select(FLAGS),
                        .GET_FIELD = .{},
                        .GET_FIELD_PTR = .{},
                        .GET_FIELD_CONST_PTR = .{},
                        .SET = PROTO.SET.select(FLAGS),
                        .SET_FIELD = .{},
                        .SWAP = PROTO.SWAP.select(FLAGS),
                        .GREATER_THAN = PROTO.GREATER_THAN.select(FLAGS),
                        .GREATER_THAN_OR_EQUAL = PROTO.GREATER_THAN_OR_EQUAL.select(FLAGS),
                        .LESS_THAN = PROTO.LESS_THAN.select(FLAGS),
                        .LESS_THAN_OR_EQUAL = PROTO.LESS_THAN_OR_EQUAL.select(FLAGS),
                        .ORDER_EQUALS = PROTO.ORDER_EQUAL.select(FLAGS),
                        .EXACT_EQUALS = PROTO.EXACT_EQUAL.select(FLAGS),
                        .REVERSE_RANGE = PROTO.REVERSE_RANGE.select(FLAGS),
                        .MOVE_ONE_PRESERVE = PROTO.MOVE_ONE_PRESERVE.select(FLAGS),
                        .MOVE_BLOCK_PRESERVE = PROTO.MOVE_BLOCK_PRESERVE.select(FLAGS),
                        .ROTATE_RIGHT = PROTO.ROTATE_RIGHT.select(FLAGS),
                        .ROTATE_LEFT = PROTO.ROTATE_LEFT.select(FLAGS),
                        .SCRAMBLE = undefined,
                    };

                    //********
                    // BUILD PROTO AND SELECT GET/SET FUNCTION FOR FIELD ACCESS FUNCS
                    //********
                    for (FieldInfoAsStructInfo_.field_names[0..], FieldInfoAsStructInfo_.field_types[0..]) |field_name, field_type| {
                        const P_F_GET = struct {
                            const cust = @field(func.FIELD_GET, field_name);
                            fn infer_ptr(data: DATA_, idx: COUNT_, userdata: USERDATA_) field_type {
                                return @field(func.FIELD_GET_PTR, field_name).?(data, idx, userdata).*;
                            }
                            fn infer_const_ptr(data: DATA_, idx: COUNT_, userdata: USERDATA_) field_type {
                                return @field(func.FIELD_GET_CONST_PTR, field_name).?(data, idx, userdata).*;
                            }
                            fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) field_type {
                                assert_unreachable(@src(), "no `get field \"{s}\" value` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{field_name});
                            }
                            fn select(comptime FLAGS_: FuncFlags) @FieldType(FieldGetters, field_name) {
                                comptime {
                                    if (FLAGS_.has(F.GET)) return cust.?;
                                    if (FLAGS_.has(INFER.GET_FROM_PTR)) return infer_ptr;
                                    if (FLAGS_.has(INFER.GET_FROM_CONST_PTR)) return infer_const_ptr;
                                    return if (ALLOW_DEFAULT) @field(DefaultFieldGetters, field_name) else unusable;
                                }
                            }
                        };
                        @field(FINAL_FUNCS.GET_FIELD, field_name) = P_F_GET.select(@field(FIELD_FLAGS, field_name));

                        const P_F_GET_PTR = struct {
                            const cust = @field(func.FIELD_GET_PTR, field_name);
                            fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) *field_type {
                                assert_unreachable(@src(), "no `get field \"{s}\" pointer` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{field_name});
                            }
                            fn select(comptime FLAGS_: FuncFlags) @FieldType(FieldPtrGetters, field_name) {
                                comptime {
                                    if (FLAGS_.has(F.GET_PTR)) return cust.?;
                                    return if (ALLOW_DEFAULT) @field(DefaultFieldPtrGetters, field_name) else unusable;
                                }
                            }
                        };
                        @field(FINAL_FUNCS.GET_FIELD_PTR, field_name) = P_F_GET_PTR.select(@field(FIELD_FLAGS, field_name));

                        const P_F_GET_CONST_PTR = struct {
                            const cust = @field(func.FIELD_GET_CONST_PTR, field_name);
                            fn infer_ptr(data: DATA_, idx: COUNT_, userdata: USERDATA_) *const field_type {
                                return @field(func.FIELD_GET_PTR, field_name).?(data, idx, userdata);
                            }
                            fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) *const field_type {
                                assert_unreachable(@src(), "no `get field \"{s}\" const pointer` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{field_name});
                            }
                            fn select(comptime FLAGS_: FuncFlags) @FieldType(FieldConstPtrGetters, field_name) {
                                comptime {
                                    if (FLAGS_.has(F.GET_CONST_PTR)) return cust.?;
                                    if (FLAGS_.has(INFER.CONST_PTR_FROM_PTR)) return infer_ptr;
                                    return if (ALLOW_DEFAULT) @field(DefaultFieldConstPtrGetters, field_name) else unusable;
                                }
                            }
                        };
                        @field(FINAL_FUNCS.GET_FIELD_CONST_PTR, field_name) = P_F_GET_CONST_PTR.select(@field(FIELD_FLAGS, field_name));

                        const P_F_SET = struct {
                            const cust = @field(func.FIELD_SET, field_name);
                            fn infer_ptr(data: DATA_, idx: ID_, val: field_type, userdata: USERDATA_) DATA_ {
                                @field(func.FIELD_GET_PTR, field_name).?(data, idx, userdata).* = val;
                                return data;
                            }
                            fn unusable(_: DATA_, _: ID_, _: field_type, _: USERDATA_) DATA_ {
                                assert_unreachable(@src(), "no `set field \"{s}\"` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{field_name});
                            }
                            fn select(comptime FLAGS_: FuncFlags) @FieldType(FieldSetters, field_name) {
                                comptime {
                                    if (FLAGS_.has(F.SET)) return cust.?;
                                    if (FLAGS_.has(INFER.SET_FROM_PTR)) return infer_ptr;
                                    return if (ALLOW_DEFAULT) @field(DefaultFieldSetters, field_name) else unusable;
                                }
                            }
                        };
                        @field(FINAL_FUNCS.SET_FIELD, field_name) = P_F_SET.select(@field(FIELD_FLAGS, field_name));
                    }
                    return FINAL_FUNCS.Finalize();
                }
            }
            pub fn Finalize(comptime FUNCS: DEF_WITH_FUNCS) type {
                return struct {
                    pub const DEF = CORE_DEF_;
                    pub const DATA = DEF.DATA;
                    pub const ID = DEF.ID;
                    pub const ELEM = DEF.ELEM;
                    pub const COUNT = DEF.COUNT_INT;
                    pub const USERDATA = DEF.USERDATA;

                    pub const get: fn (DATA, ID, USERDATA) ELEM = FUNCS.GET;
                    pub const get_ptr: fn (DATA, ID, USERDATA) *ELEM = FUNCS.GET_PTR;
                    pub const get_const_ptr: fn (DATA, ID, USERDATA) *const ELEM = FUNCS.GET_CONST_PTR;
                    pub const get_field = FUNCS.GET_FIELD;
                    pub const get_field_ptr = FUNCS.GET_FIELD_PTR;
                    pub const get_field_const_ptr = FUNCS.GET_FIELD_CONST_PTR;
                    pub const set: fn (DATA, ID, ELEM, USERDATA) DATA = FUNCS.SET;
                    pub const set_field = FUNCS.SET_FIELD;
                    pub const get_len: fn (DATA, USERDATA) COUNT = FUNCS.GET_LEN;
                    pub const set_len: fn (DATA, new_len: COUNT, USERDATA) DATA = FUNCS.SET_LEN;
                    pub const id_valid: fn (DATA, ID, USERDATA) bool = FUNCS.VALID_ID;
                    pub const id_less_than_id: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_LESS_THAN_ID;
                    pub const id_less_than_or_equal_id: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_LESS_THAN_OR_EQUAL_ID;
                    pub const first_id: fn (DATA, USERDATA) ID = FUNCS.FIRST_ID;
                    pub const last_id: fn (DATA, USERDATA) ID = FUNCS.LAST_ID;
                    pub const nth_id_from_start: fn (DATA, n: COUNT, USERDATA) ID = FUNCS.NTH_ID_FROM_START;
                    pub const nth_id_from_end: fn (DATA, n: COUNT, USERDATA) ID = FUNCS.NTH_ID_FROM_END;
                    pub const next_id: fn (DATA, curr_id: ID, USERDATA) ID = FUNCS.NEXT_ID;
                    pub const prev_id: fn (DATA, curr_id: ID, USERDATA) ID = FUNCS.PREV_ID;
                    pub const nth_next_id: fn (DATA, curr_id: ID, n: COUNT, USERDATA) ID = FUNCS.NTH_NEXT_ID;
                    pub const nth_prev_id: fn (DATA, curr_id: ID, n: COUNT, USERDATA) ID = FUNCS.NTH_PREV_ID;
                    pub const range_len: fn (DATA, first: ID, last: ID, USERDATA) COUNT = FUNCS.RANGE_LEN;
                    pub const swap: fn (DATA, a: ID, b: ID, USERDATA) DATA = FUNCS.SWAP;
                    pub const less_than: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.LESS_THAN;
                    pub const less_than_or_equal: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.LESS_THAN_OR_EQUAL;
                    pub const greater_than: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.GREATER_THAN;
                    pub const greater_than_or_equal: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.GREATER_THAN_OR_EQUAL;
                    pub const order_equals: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.ORDER_EQUALS;
                    pub const exact_equals: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.EXACT_EQUALS;
                    pub const reverse_range: fn (DATA, first: ID, last: ID, USERDATA) DATA = FUNCS.REVERSE_RANGE;
                    pub const rotate_range_left: fn (DATA, first: ID, last: ID, COUNT, USERDATA) DATA = FUNCS.ROTATE_LEFT;
                    pub const rotate_range_right: fn (DATA, first: ID, last: ID, COUNT, USERDATA) DATA = FUNCS.ROTATE_RIGHT;
                    pub const move_one_displace_others: fn (DATA, old_id: ID, new_id: ID, USERDATA) DATA = FUNCS.MOVE_ONE_PRESERVE;
                    pub const move_range_displace_others: fn (DATA, old_first: ID, old_last: ID, new_first: ID, USERDATA) DATA = FUNCS.MOVE_BLOCK_PRESERVE;
                    pub const scramble: fn (DATA, rand: Random, first: ID, last: ID, iterations: COUNT, USERDATA) DATA = FUNCS.SCRAMBLE;

                    pub fn start_end_excl_len(data: DATA, start: ID, end_excl: ID, userdata: USERDATA) COUNT {
                        return range_len(data, start, prev_id(data, end_excl, userdata), userdata);
                    }

                    pub fn swap_already_have_b(data: DATA, id_a: ID, id_b: ID, val_b: ELEM, userdata: USERDATA) DATA {
                        const new_data = set(data, id_b, get(data, id_a, userdata), userdata);
                        return set(new_data, id_a, val_b, userdata);
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
                    //CHECKPOINT fix these for new API
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
        .COUNT_INT = u8,
    };
    const DMP_FUNCS = DMP_TYPES.CustomFunctions(){};
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
