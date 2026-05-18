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

const HeapKind = enum(u8) {
    MIN_HEAP,
    MAX_HEAP,
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
    /// Switch to insertion sort (if small total input) or heapsort instead,
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

const FIELD_FUNCS_EXAMPLE =
    \\pub const MyStruct = struct{{
    \\  my_writable_field: u32,
    \\  my_readonly_field: []const u8,
    \\}};
    \\
    \\pub const FieldFuncs = struct{{
    \\  pub const my_writable_field = struct{{
    \\    pub const FIELD_TYPE: type = u32;
    \\    pub fn get(data: DATA, id: ID, userdata: USERDATA) FIELD_TYPE {{
    \\      return data[id].my_writable_field;
    \\    }}
    \\    pub fn get_ptr(data: DATA, id: ID, userdata: USERDATA) *FIELD_TYPE {{
    \\      return &data[id].my_writable_field;
    \\    }}
    \\    pub fn get_const_ptr(data: DATA, id: ID, userdata: USERDATA) *FIELD_TYPE {{
    \\      return &data[id].my_writable_field;
    \\    }}
    \\    pub fn set(data: DATA, id: ID, val: FIELD_TYPE, userdata: USERDATA) DATA {{
    \\      data[id].my_writable_field = val;
    \\      return data;
    \\    }}
    \\  }};
    \\  
    \\  pub const my_readonly_field = struct {{
    \\    pub const FIELD_TYPE: type = []const u8;
    \\    pub fn get(data: DATA, id: ID, userdata: USERDATA) FIELD_TYPE {{
    \\      return data[id].my_readonly_field;
    \\    }}
    \\  }};
    \\}};
;

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

const CUSTOM_FLAG = u64;
const F = struct {
    const GET: CUSTOM_FLAG = 1 << 0;
    const GET_PTR: CUSTOM_FLAG = 1 << 1;
    const GET_CONST_PTR: CUSTOM_FLAG = 1 << 2;
    const SET: CUSTOM_FLAG = 1 << 3;
    const SWAP: CUSTOM_FLAG = 1 << 4;
    const GREATER_THAN: CUSTOM_FLAG = 1 << 5;
    const GREATER_THAN_OR_EQUAL: CUSTOM_FLAG = 1 << 6;
    const LESS_THAN: CUSTOM_FLAG = 1 << 7;
    const LESS_THAN_OR_EQUAL: CUSTOM_FLAG = 1 << 8;
    const ORDER_EQUALS: CUSTOM_FLAG = 1 << 9;
    const EXACT_EQUALS: CUSTOM_FLAG = 1 << 10;
    const FIRST_ID: CUSTOM_FLAG = 1 << 11;
    const LAST_ID: CUSTOM_FLAG = 1 << 12;
    const NTH_ID_FROM_START: CUSTOM_FLAG = 1 << 13;
    const NTH_ID_FROM_END: CUSTOM_FLAG = 1 << 14;
    const PREV_ID: CUSTOM_FLAG = 1 << 15;
    const NEXT_ID: CUSTOM_FLAG = 1 << 16;
    const NTH_PREV_ID: CUSTOM_FLAG = 1 << 17;
    const NTH_NEXT_ID: CUSTOM_FLAG = 1 << 18;
    const GET_LEN: CUSTOM_FLAG = 1 << 19;
    const SET_LEN: CUSTOM_FLAG = 1 << 20;
    const GET_CAP: CUSTOM_FLAG = 1 << 21;
    const SET_CAP: CUSTOM_FLAG = 1 << 22;
    const RANGE_LEN: CUSTOM_FLAG = 1 << 23;
    const APPEND_ONE: CUSTOM_FLAG = 1 << 24;
    const APPEND_N: CUSTOM_FLAG = 1 << 25;
    const INSERT_ONE: CUSTOM_FLAG = 1 << 26;
    const INSERT_N: CUSTOM_FLAG = 1 << 27;
    const DELETE_ONE: CUSTOM_FLAG = 1 << 28;
    const DELETE_N: CUSTOM_FLAG = 1 << 29;
    const REVERSE_RANGE: CUSTOM_FLAG = 1 << 30;
    const ENSURE_SPACE: CUSTOM_FLAG = 1 << 31;
    const MOVE_ONE_PRESERVE: CUSTOM_FLAG = 1 << 32;
    const MOVE_BLOCK_PRESERVE: CUSTOM_FLAG = 1 << 33;
    const NEVER_OVERLAP_COPY_RANGE: CUSTOM_FLAG = 1 << 34;
    const MIGHT_OVERLAP_COPY_RANGE: CUSTOM_FLAG = 1 << 35;
    const MEMORY_CONTIGUOUS_IN_ORDER: CUSTOM_FLAG = 1 << 36;
    const ROTATE_RANGE_LEFT: CUSTOM_FLAG = 1 << 37;
    const ROTATE_RANGE_RIGHT: CUSTOM_FLAG = 1 << 38;
    const SCRAMBLE: CUSTOM_FLAG = 1 << 39;
    const ID_LESS_THAN: CUSTOM_FLAG = 1 << 40;
    const ID_LESS_THAN_OR_EQUAL: CUSTOM_FLAG = 1 << 41;
    const ID_GREATER_THAN: CUSTOM_FLAG = 1 << 42;
    const ID_GREATER_THAN_OR_EQUAL: CUSTOM_FLAG = 1 << 43;
    const ID_EQUALS: CUSTOM_FLAG = 1 << 44;
    const VALID_ID: CUSTOM_FLAG = 1 << 45;
    const INVALID_ID_AFTER: CUSTOM_FLAG = 1 << 46;
    const INVALID_ID_BEFORE: CUSTOM_FLAG = 1 << 47;
};
const FuncFlags = struct {
    raw: CUSTOM_FLAG = 0,

    fn add_if_not_null(comptime flags: *FuncFlags, comptime flag: CUSTOM_FLAG, comptime not_null: anytype) void {
        if (not_null != null) {
            flags.raw |= flag;
        }
    }

    fn has(comptime flags: FuncFlags, comptime flag: CUSTOM_FLAG) bool {
        return (flags.raw & flag) == flag;
    }
    fn has_any(comptime flags: FuncFlags, comptime any_flag: []const CUSTOM_FLAG) bool {
        inline for (any_flag) |flag| {
            if (flags.has(flag)) return true;
        }
        return false;
    }
};
const INFER = struct {
    pub const GET = struct {
        const FROM_CONST_PTR = F.GET_CONST_PTR;
        const FROM_PTR = F.GET_PTR;
    };
    pub const CONST_PTR = struct {
        const FROM_PTR = F.GET_PTR;
    };
    pub const SET = struct {
        const FROM_PTR = F.GET_PTR;
    };
    pub const SWAP = struct {
        const FROM_PTR = F.GET_PTR;
        const FROM_GET_SET = F.GET | F.SET;
    };
    pub const GT = struct {
        const FROM_LTEQ = F.LESS_THAN_OR_EQUAL;
        const FROM_LT_EQ = F.LESS_THAN | F.EXACT_EQUALS;
        const FROM_LT_OQ = F.LESS_THAN | F.ORDER_EQUALS;
    };
    pub const LT = struct {
        const FROM_GTEQ = F.GREATER_THAN_OR_EQUAL;
        const FROM_GT_EQ = F.GREATER_THAN | F.EXACT_EQUALS;
        const FROM_GT_OQ = F.GREATER_THAN | F.ORDER_EQUALS;
    };
    pub const EQ = struct {
        const FROM_OQ = F.ORDER_EQUALS;
        const FROM_GT_LT = F.GREATER_THAN | F.LESS_THAN;
    };
    pub const OQ = struct {
        const FROM_EQ = F.EXACT_EQUALS;
        const FROM_GT_LT = F.GREATER_THAN | F.LESS_THAN;
    };
    pub const GTEQ = struct {
        const FROM_LT = F.LESS_THAN;
        const FROM_GT_EQ = F.GREATER_THAN | F.EXACT_EQUALS;
        const FROM_GT_OQ = F.GREATER_THAN | F.ORDER_EQUALS;
    };
    pub const LTEQ = struct {
        const FROM_GT = F.GREATER_THAN;
        const FROM_LT_EQ = F.LESS_THAN | F.EXACT_EQUALS;
        const FROM_LT_OQ = F.LESS_THAN | F.ORDER_EQUALS;
    };
    pub const ID_GT = struct {
        const FROM_LTEQ = F.ID_LESS_THAN_OR_EQUAL;
        const FROM_LT_EQ = F.ID_LESS_THAN | F.ID_EQUALS;
    };
    pub const ID_LT = struct {
        const FROM_GTEQ = F.ID_GREATER_THAN_OR_EQUAL;
        const FROM_GT_EQ = F.ID_GREATER_THAN | F.ID_EQUALS;
    };
    pub const ID_EQ = struct {
        const FROM_GT_LT = F.ID_GREATER_THAN | F.ID_LESS_THAN;
    };
    pub const ID_GTEQ = struct {
        const FROM_LT = F.ID_LESS_THAN;
        const FROM_GT_EQ = F.ID_GREATER_THAN | F.ID_EQUALS;
    };
    pub const ID_LTEQ = struct {
        const FROM_GT = F.ID_GREATER_THAN;
        const FROM_LT_EQ = F.ID_LESS_THAN | F.ID_EQUALS;
    };
    pub const VALID_ID = struct {
        const FROM_FIRST_LAST_LTEQ = F.FIRST_ID | F.LAST_ID | F.ID_LESS_THAN_OR_EQUAL;
        const FROM_FIRST_LAST_GTEQ = F.FIRST_ID | F.LAST_ID | F.ID_GREATER_THAN_OR_EQUAL;
        const FROM_FIRST_LAST_LT_EQ = F.FIRST_ID | F.LAST_ID | F.ID_LESS_THAN | F.ID_EQUALS;
        const FROM_FIRST_LAST_GT_EQ = F.FIRST_ID | F.LAST_ID | F.ID_GREATER_THAN | F.ID_EQUALS;
    };
    pub const NEXT_ID = struct {
        const FROM_NTH_NEXT = F.NTH_NEXT_ID;
        const FROM_LAST_PREV = F.LAST_ID | F.PREV_ID;
    };
    pub const NTH_NEXT_ID = struct {
        const FROM_NEXT = F.NEXT_ID;
        const FROM_LAST_PREV = F.LAST_ID | F.PREV_ID;
    };
    pub const PREV_ID = struct {
        const FROM_NTH_PREV = F.NTH_PREV_ID;
        const FROM_FIRST_NEXT = F.FIRST_ID | F.NEXT_ID;
    };
    pub const NTH_PREV_ID = struct {
        const FROM_PREV = F.PREV_ID;
        const FROM_FIRST_NEXT = F.FIRST_ID | F.NEXT_ID;
    };
    pub const RANGE_LEN = struct {
        const FROM_NEXT = F.NEXT_ID;
        const FROM_PREV = F.PREV_ID;
    };
    pub const LEN = struct {
        const FROM_FIRST_LAST_RANGE_LEN = F.FIRST_ID | F.LAST_ID | F.RANGE_LEN;
        const FROM_FIRST_LAST_NEXT = F.FIRST_ID | F.LAST_ID | F.NEXT_ID;
        const FROM_FIRST_LAST_PREV = F.FIRST_ID | F.LAST_ID | F.PREV_ID;
    };
    pub const LAST_ID = struct {
        const FROM_FIRST_LEN_NTH_NEXT = F.FIRST_ID | F.GET_LEN | F.NTH_ID_FROM_START;
        const FROM_FIRST_LEN_NEXT = F.FIRST_ID | F.GET_LEN | F.NEXT_ID;
        const FROM_NTH_FROM_LAST = F.NTH_ID_FROM_END;
        const FROM_LEN_NTH_FROM_START = F.NTH_ID_FROM_START | F.GET_LEN;
    };
    pub const FIRST_ID = struct {
        const FROM_LAST_LEN_NTH_PREV = F.LAST_ID | F.GET_LEN | F.NTH_PREV_ID;
        const FROM_LAST_LEN_PREV = F.LAST_ID | F.GET_LEN | F.PREV_ID;
        const FROM_NTH_FROM_START = F.NTH_ID_FROM_START;
        const FROM_LEN_NTH_FROM_END = F.NTH_ID_FROM_END | F.GET_LEN;
    };
    pub const NTH_FROM_END = struct {
        const FROM_LAST_NTH_PREV = F.LAST_ID | F.NTH_PREV_ID;
        const FROM_LAST_PREV = F.LAST_ID | F.PREV_ID;
    };
    pub const NTH_FROM_START = struct {
        const FROM_FIRST_NTH_NEXT = F.FIRST_ID | F.NTH_NEXT_ID;
        const FROM_FIRST_NEXT = F.FIRST_ID | F.NEXT_ID;
    };
    pub const REVERSE = struct {
        const FROM_SWAP = F.SWAP;
        const FROM_GET_SET = F.GET | F.SET;
    };
    pub const ROTATE = struct {
        const FROM_REVERSE = F.REVERSE_RANGE;
        const FROM_SWAP = F.SWAP;
        const FROM_GET_SET = F.GET | F.SET;
    };
    pub const MOVE = struct {
        const FROM_ROTATE = F.ROTATE_RANGE_LEFT | F.ROTATE_RANGE_RIGHT;
        const FROM_REVERSE = F.REVERSE_RANGE;
        const FROM_SWAP = F.SWAP;
        const FROM_GET_SET = F.GET | F.SET;
    };
    pub const MOVE_ONE = struct {
        const FROM_GET_SET = F.GET | F.SET | F.NEXT_ID | F.PREV_ID;
        const FROM_MOVE_BLOCK = F.MOVE_BLOCK_PRESERVE;
    };
};

pub fn native_data_structure_manipulation_package(comptime DATA_STRUCTURE: type, comptime ELEM: type) type {
    const core = DataManipulationPackage{
        .DATA = DATA_STRUCTURE,
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = void,
    };
    return core.WithCoreAccesFuncs(.NONE).select_functions(true, .{}, {}).Finalize(void, {});
}

pub fn contiguous_memory_manipulation_package_using_core_access(comptime CORE_DEF: DataManipulationPackage, comptime CORE_ACCESS: CORE_DEF.CoreAccessFuncs()) type {
    return CORE_DEF.WithCoreAccesFuncs(CORE_ACCESS).select_functions(true, .{}, {}).Finalize(void, {});
}
pub fn custom_memory_manipulation_package_no_defaults(comptime CORE_DEF: DataManipulationPackage, comptime CUSTOM_FUNCS: CORE_DEF.WithCoreAccesFuncs(.NONE), comptime CUSTOM_FIELD_FUNCS: anytype) type {
    return CORE_DEF.WithCoreAccesFuncs(.NONE).select_functions(false, CUSTOM_FUNCS, CUSTOM_FIELD_FUNCS).Finalize(@TypeOf(CUSTOM_FIELD_FUNCS), CUSTOM_FIELD_FUNCS);
}
pub fn custom_memory_manipulation_package_default_fallbacks_with_core_access(comptime CORE_DEF: DataManipulationPackage, comptime CORE_ACCESS: CORE_DEF.CoreAccessFuncs(), comptime CUSTOM_FUNCS: CORE_DEF.WithCoreAccesFuncs(CORE_ACCESS), comptime CUSTOM_FIELD_FUNCS: anytype) type {
    return CORE_DEF.WithCoreAccesFuncs(CORE_ACCESS).select_functions(true, CUSTOM_FUNCS, CUSTOM_FIELD_FUNCS).Finalize(@TypeOf(CUSTOM_FIELD_FUNCS), CUSTOM_FIELD_FUNCS);
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
            get_bast_ptr_const: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) [*]const CORE_DEF.ELEM = null,
            set_base_ptr: ?fn (data: CORE_DEF.DATA, ptr: [*]CORE_DEF.ELEM, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,
            get_len: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) CORE_DEF.COUNT_INT = null,
            set_len: ?fn (data: CORE_DEF.DATA, len: CORE_DEF.COUNT_INT, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,
            get_cap: ?fn (data: CORE_DEF.DATA, userdata: CORE_DEF.USERDATA) CORE_DEF.COUNT_INT = null,
            set_cap: ?fn (data: CORE_DEF.DATA, cap: CORE_DEF.COUNT_INT, userdata: CORE_DEF.USERDATA) CORE_DEF.DATA = null,

            pub const NONE = @This(){};
        };
    }

    pub fn WithCoreAccesFuncs(comptime CORE_DEF_: DataManipulationPackage, comptime CORE_ACCESS_FUNCS: CORE_DEF_.CoreAccessFuncs()) type {
        return struct {
            const DEF_WITH_FUNCS = @This();
            pub const CORE_DEF = CORE_DEF_;
            pub const DATA_ = CORE_DEF.DATA;
            pub const ELEM_ = CORE_DEF.ELEM;
            pub const COUNT_ = CORE_DEF.COUNT_INT;
            pub const ID_ = CORE_DEF.ID;
            pub const USERDATA_ = CORE_DEF.USERDATA;

            ID_LESS_THAN: FN_ID_COMPARE,
            ID_LESS_THAN_OR_EQUAL: FN_ID_COMPARE,
            ID_GREATER_THAN: FN_ID_COMPARE,
            ID_GREATER_THAN_OR_EQUAL: FN_ID_COMPARE,
            ID_EQUALS: FN_ID_COMPARE,
            ID_VALID: FN_ID_CHECK,
            ID_INVALID_AFTER: FN_IMPLICIT_ID,
            ID_INVALID_BEFORE: FN_IMPLICIT_ID,
            FIRST_ID: FN_IMPLICIT_ID,
            LAST_ID: FN_IMPLICIT_ID,
            NTH_ID_FROM_START: FN_IMPLICIT_NTH_ID,
            NTH_ID_FROM_END: FN_IMPLICIT_NTH_ID,
            PREV_ID: FN_ADJACENT_ID,
            NEXT_ID: FN_ADJACENT_ID,
            NTH_PREV_ID: FN_NTH_ID,
            NTH_NEXT_ID: FN_NTH_ID,
            GET_LEN: FN_IMPLICIT_COUNT,
            SET_LEN: FN_SET_COUNT,
            RANGE_LEN: FN_RANGE_COUNT,
            GET: FN_GET,
            GET_PTR: FN_GET_PTR,
            GET_CONST_PTR: FN_GET_CONST_PTR,
            SET: FN_SET,
            SWAP: FN_SWAP,
            GREATER_THAN: FN_ELEM_COMPARE,
            GREATER_THAN_OR_EQUAL: FN_ELEM_COMPARE,
            LESS_THAN: FN_ELEM_COMPARE,
            LESS_THAN_OR_EQUAL: FN_ELEM_COMPARE,
            ORDER_EQUALS: FN_ELEM_COMPARE,
            EXACT_EQUALS: FN_ELEM_COMPARE,
            REVERSE_RANGE: FN_RANGE_OP,
            MOVE_ONE_PRESERVE: FN_RANGE_OP,
            MOVE_BLOCK_PRESERVE: FN_MOVE_BLOCK,
            ROTATE_RIGHT: FN_ROTATE,
            ROTATE_LEFT: FN_ROTATE,
            SCRAMBLE: FN_SCRAMBLE,

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
                } else if (comptime Types.type_is_slice(DATA_) and !KindInfo.get_kind_info(DATA_).POINTER.is_const) {
                    return @ptrCast(data.ptr);
                } else {
                    unreachable;
                }
            }
            fn default_get_base_ptr_const(data: DATA_, userdata: USERDATA_) [*]const ELEM_ {
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
                } else if (comptime Types.type_is_slice(DATA_) and KindInfo.get_kind_info(DATA_).POINTER.is_const) {
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

            const DEFAULT_ALWAYS_INVALID_ID: ID_ = if (Types.type_is_int(ID_)) math.maxInt(ID_) else if (Types.type_is_optional(ID_)) null else undefined;

            pub const FN_ID_COMPARE = fn (DATA_, ID_, ID_, USERDATA_) bool;
            pub const FN_ID_CHECK = fn (DATA_, ID_, USERDATA_) bool;
            pub const FN_ELEM_COMPARE = fn (ELEM_, ELEM_, USERDATA_) bool;
            pub const FN_IMPLICIT_ID = fn (DATA_, USERDATA_) ID_;
            pub const FN_IMPLICIT_NTH_ID = fn (DATA_, COUNT_, USERDATA_) ID_;
            pub const FN_NTH_ID = fn (DATA_, ID_, COUNT_, USERDATA_) ID_;
            pub const FN_ADJACENT_ID = fn (DATA_, ID_, USERDATA_) ID_;
            pub const FN_IMPLICIT_COUNT = fn (DATA_, USERDATA_) COUNT_;
            pub const FN_SET_COUNT = fn (DATA_, COUNT_, USERDATA_) DATA_;
            pub const FN_RANGE_COUNT = fn (DATA_, ID_, ID_, USERDATA_) COUNT_;
            pub const FN_GET = fn (DATA_, ID_, USERDATA_) ELEM_;
            pub const FN_GET_PTR = fn (DATA_, ID_, USERDATA_) *ELEM_;
            pub const FN_GET_CONST_PTR = fn (DATA_, ID_, USERDATA_) *const ELEM_;
            pub const FN_SET = fn (DATA_, ID_, ELEM_, USERDATA_) DATA_;
            pub const FN_SWAP = fn (DATA_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_RANGE_OP = fn (DATA_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_MOVE_BLOCK = fn (DATA_, ID_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_ROTATE = fn (DATA_, ID_, ID_, COUNT_, USERDATA_) DATA_;
            pub const FN_SCRAMBLE = fn (DATA_, Random, ID_, ID_, COUNT_, USERDATA_) DATA_;

            pub const CustomDataFuncs = struct {
                ID_LESS_THAN: ?FN_ID_COMPARE = null,
                ID_LESS_THAN_OR_EQUAL: ?FN_ID_COMPARE = null,
                ID_GREATER_THAN: ?FN_ID_COMPARE = null,
                ID_GREATER_THAN_OR_EQUAL: ?FN_ID_COMPARE = null,
                ID_EQUALS: ?FN_ID_COMPARE = null,
                VALID_ID: ?FN_ID_CHECK = null,
                INVALID_ID_AFTER: ?FN_IMPLICIT_ID = null,
                INVALID_ID_BEFORE: ?FN_IMPLICIT_ID = null,
                GET: ?FN_GET = null,
                GET_PTR: ?FN_GET_PTR = null,
                GET_PTR_CONST: ?FN_GET_CONST_PTR = null,
                SET: ?FN_SET = null,
                SWAP: ?FN_SWAP = null,
                LESS_THAN: ?FN_ELEM_COMPARE = null,
                LESS_THAN_OR_EQUAL: ?FN_ELEM_COMPARE = null,
                GREATER_THAN: ?FN_ELEM_COMPARE = null,
                GREATER_THAN_OR_EQUAL: ?FN_ELEM_COMPARE = null,
                ORDER_EQUALS: ?FN_ELEM_COMPARE = null,
                EXACT_EQUALS: ?FN_ELEM_COMPARE = null,
                FIRST_ID: ?FN_IMPLICIT_ID = null,
                LAST_ID: ?FN_IMPLICIT_ID = null,
                NTH_ID_FROM_START: ?FN_IMPLICIT_NTH_ID = null,
                NTH_ID_FROM_END: ?FN_IMPLICIT_NTH_ID = null,
                NEXT_ID: ?FN_ADJACENT_ID = null,
                PREV_ID: ?FN_ADJACENT_ID = null,
                NTH_PREV_ID: ?FN_NTH_ID = null,
                NTH_NEXT_ID: ?FN_NTH_ID = null,
                GET_LEN: ?FN_IMPLICIT_COUNT = null,
                SET_LEN: ?FN_SET_COUNT = null,
                RANGE_LEN: ?FN_RANGE_COUNT = null,
                REVERSE_RANGE: ?FN_RANGE_OP = null,
                MOVE_ONE_PRESERVE: ?FN_RANGE_OP = null,
                MOVE_BLOCK_PRESERVE: ?FN_MOVE_BLOCK = null,
                ROTATE_RANGE_RIGHT: ?FN_ROTATE = null,
                ROTATE_RANGE_LEFT: ?FN_ROTATE = null,
                SCRAMBLE: ?FN_SCRAMBLE = null,
            };

            pub fn FunctionSelector(comptime CUSTOM: CustomDataFuncs, comptime FLAGS: FuncFlags, comptime ALLOW_DEFAULT: bool) type {
                return struct {
                    const ALWAYS_INVALID = if (CUSTOM.ALWAYS_INVALID_ID) |INVALID| INVALID else DEFAULT_ALWAYS_INVALID_ID;
                    const INVALID_ID_AFTER = struct {
                        const func: FN_IMPLICIT_ID = if (CUSTOM.INVALID_ID_AFTER) |cust| cust //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, userdata: USERDATA_) ID_ {
                            return @intCast(GET_LEN.default(data, userdata));
                        }
                        fn unusable(_: DATA_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `invalid_id_after` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const INVALID_ID_BEFORE = struct {
                        const func: FN_IMPLICIT_ID = if (CUSTOM.INVALID_ID_BEFORE) |cust| cust //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, _: USERDATA_) ID_ {
                            return @intCast(math.maxInt(COUNT_));
                        }
                        fn unusable(_: DATA_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `invalid_id_before` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_VALID = struct {
                        const func: FN_ID_CHECK = if (CUSTOM.VALID_ID) |cust| cust //
                            else if (FLAGS.has(INFER.VALID_ID.FROM_FIRST_LAST_LTEQ)) infer_lteq //
                            else if (FLAGS.has(INFER.VALID_ID.FROM_FIRST_LAST_GTEQ)) infer_gteq //
                            else if (FLAGS.has(INFER.VALID_ID.FROM_FIRST_LAST_LT_EQ)) infer_lt_eq //
                            else if (FLAGS.has(INFER.VALID_ID.FROM_FIRST_LAST_GT_EQ)) infer_gt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            return 0 <= id and id < GET_LEN.default(data, userdata);
                        }
                        fn infer_lteq(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const LTEQ = ID_LESS_THAN_OR_EQUAL.func;
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const first = FIRST(data, userdata);
                            const last = LAST(data, userdata);
                            return LTEQ(data, first, id, userdata) and LTEQ(data, id, last, userdata);
                        }
                        fn infer_gteq(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const GTEQ = ID_GREATER_THAN_OR_EQUAL.func;
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const first = FIRST(data, userdata);
                            const last = LAST(data, userdata);
                            return GTEQ(data, id, first, userdata) and GTEQ(data, last, id, userdata);
                        }
                        fn infer_lt_eq(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const LT = ID_LESS_THAN.func;
                            const EQ = ID_EQUALS.func;
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const first = FIRST(data, userdata);
                            const last = LAST(data, userdata);
                            return (LT(data, first, id, userdata) or (EQ(data, first, id, userdata))) and (LT(data, id, last, userdata) or EQ(data, id, last, userdata));
                        }
                        fn infer_gt_eq(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const GT = ID_GREATER_THAN.func;
                            const EQ = ID_EQUALS.func;
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const first = FIRST(data, userdata);
                            const last = LAST(data, userdata);
                            return (GT(data, id, first, userdata) or (EQ(data, first, id, userdata))) and (GT(data, last, id, userdata) or EQ(data, id, last, userdata));
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `valid_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };

                    fn assert_valid_id(data: DATA_, id: ID_, userdata: USERDATA_, comptime src: SourceLocation) bool {
                        const VALID = ID_VALID.func;
                        assert_with_reason(VALID(data, id, userdata), src, "id `{any}` is not valid for the current data structure state", .{id});
                    }
                    const ID_LESS_THAN = struct {
                        const T_FN = @TypeOf(default);
                        const func: FN_ID_COMPARE = if (CUSTOM.ID_LESS_THAN) |cust| cust //
                            else if (FLAGS.has(INFER.ID_LT.FROM_GTEQ)) infer_gteq //
                            else if (FLAGS.has(INFER.ID_LT.FROM_GT_EQ)) infer_gt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a < id_b;
                        }
                        fn infer_gteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const GTEQ = ID_GREATER_THAN_OR_EQUAL.func;
                            return !GTEQ(data, id_a, id_b, userdata);
                        }
                        fn infer_gt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const GT = ID_GREATER_THAN.func;
                            const EQ = ID_EQUALS.func;
                            return !GT(data, id_a, id_b, userdata) and !EQ(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_a less than id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_LESS_THAN_OR_EQUAL = struct {
                        const func: FN_ID_COMPARE = if (CUSTOM.ID_LESS_THAN_OR_EQUAL) |cust| cust //
                            else if (FLAGS.has(INFER.ID_LTEQ.FROM_GT)) infer_gt //
                            else if (FLAGS.has(INFER.ID_LTEQ.FROM_LT_EQ)) infer_lt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a <= id_b;
                        }
                        fn infer_gt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const GT = ID_GREATER_THAN.func;
                            return !GT(data, id_a, id_b, userdata);
                        }
                        fn infer_lt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const LT = ID_LESS_THAN.func;
                            const EQ = ID_EQUALS.func;
                            return LT(data, id_a, id_b, userdata) or EQ(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) ELEM_ {
                            assert_unreachable(@src(), "no `id_a less than or equal id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_GREATER_THAN = struct {
                        const func: FN_ID_COMPARE = if (CUSTOM.ID_GREATER_THAN) |cust| cust //
                            else if (FLAGS.has(INFER.ID_GT.FROM_LTEQ)) infer_lteq //
                            else if (FLAGS.has(INFER.ID_GT.FROM_LT_EQ)) infer_lt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a > id_b;
                        }
                        fn infer_lteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const LTEQ = ID_LESS_THAN_OR_EQUAL.func;
                            return !LTEQ(data, id_a, id_b, userdata);
                        }
                        fn infer_lt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const LT = ID_LESS_THAN.func;
                            const EQ = ID_EQUALS.func;
                            return !LT(data, id_a, id_b, userdata) and !EQ(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) ELEM_ {
                            assert_unreachable(@src(), "no `id_a greater than id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_GREATER_THAN_OR_EQUAL = struct {
                        const func: FN_ID_COMPARE = if (CUSTOM.ID_GREATER_THAN_OR_EQUAL) |cust| cust //
                            else if (FLAGS.has(INFER.ID_GTEQ.FROM_LT)) infer_lt //
                            else if (FLAGS.has(INFER.ID_GTEQ.FROM_GT_EQ)) infer_gt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a >= id_b;
                        }
                        fn infer_lt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const LT = ID_LESS_THAN.func;
                            return !LT(data, id_a, id_b, userdata);
                        }
                        fn infer_gt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const GT = ID_GREATER_THAN.func;
                            const EQ = ID_EQUALS.func;
                            return GT(data, id_a, id_b, userdata) or EQ(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) ELEM_ {
                            assert_unreachable(@src(), "no `id_a greater than or equal id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_EQUALS = struct {
                        const func: FN_ID_COMPARE = if (CUSTOM.ID_EQUALS) |cust| cust //
                            else if (FLAGS.has(INFER.ID_EQ.FROM_GT_LT)) infer_gt_lt //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a == id_b;
                        }
                        fn infer_gt_lt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            const GT = ID_GREATER_THAN.func;
                            const LT = ID_LESS_THAN.func;
                            return !GT(data, id_a, id_b, userdata) and !LT(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) ELEM_ {
                            assert_unreachable(@src(), "no `id_a less than or equal id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET = struct {
                        const func: FN_GET = if (CUSTOM.GET) |cust| cust //
                            else if (FLAGS.has(INFER.GET.FROM_PTR)) infer_ptr //
                            else if (FLAGS.has(INFER.GET.FROM_CONST_PTR)) infer_const_ptr //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                            return default_get_base_ptr_const(data, userdata)[id];
                        }
                        fn infer_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return CUSTOM.GET_PTR.?(data, id, userdata).*;
                        }
                        fn infer_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return CUSTOM.GET_PTR_CONST.?(data, id, userdata).*;
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) ELEM_ {
                            assert_unreachable(@src(), "no `get` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_PTR = struct {
                        const func: FN_GET_PTR = if (CUSTOM.GET_PTR) |cust| cust //
                            else if (ALLOW_DEFAULT) default else unusable;
                        const T_FN_GET_PTR = @TypeOf(default);
                        fn default(data: DATA_, id: ID_, userdata: USERDATA_) *ELEM_ {
                            return &default_get_base_ptr(data, userdata)[id];
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) *ELEM_ {
                            assert_unreachable(@src(), "no `get_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_CONST_PTR = struct {
                        const func: FN_GET_CONST_PTR = if (CUSTOM.GET_PTR_CONST) |cust| cust //
                            else if (FLAGS.has(INFER.CONST_PTR.FROM_PTR)) infer_ptr //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                            return &default_get_base_ptr_const(data, userdata)[id];
                        }
                        fn infer_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return CUSTOM.GET_PTR.?(data, id, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) *const ELEM_ {
                            assert_unreachable(@src(), "no `get_const_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET = struct {
                        const func: FN_SET = if (CUSTOM.SET) |cust| cust //
                            else if (FLAGS.has(INFER.SET.FROM_PTR)) infer_ptr //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                            const new_data = data;
                            default_get_base_ptr(new_data, userdata)[id] = val;
                            return new_data;
                        }
                        fn infer_ptr(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, id, userdata, @src());
                            CUSTOM.GET_PTR.?(data, id, userdata).* = val;
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ELEM_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `set` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SWAP = struct {
                        const func: FN_SWAP = if (CUSTOM.SWAP) |cust| cust //
                            else if (FLAGS.has(INFER.SWAP.FROM_PTR)) infer_ptr //
                            else if (FLAGS.has(INFER.SWAP.FROM_GET_SET)) infer_get_set //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                            var new_data = data;
                            const tmp = GET.default(new_data, id_b, userdata);
                            new_data = SET.default(new_data, id_b, GET.default(new_data, id_a, userdata), userdata);
                            new_data = SET.default(new_data, id_a, tmp, userdata);
                            return new_data;
                        }
                        fn infer_ptr(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, id_a, userdata, @src());
                            assert_valid_id(data, id_b, userdata, @src());
                            const GET_PTR_ = GET_PTR.func;
                            const ptr_a = GET_PTR_(data, id_a, userdata);
                            const ptr_b = GET_PTR_(data, id_b, userdata);
                            const tmp = ptr_b.*;
                            ptr_b.* = ptr_a.*;
                            ptr_a.* = tmp;
                            return data;
                        }
                        fn infer_get_set(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                            const GET_ = GET.func;
                            const SET_ = SET.func;
                            assert_valid_id(data, id_a, userdata, @src());
                            assert_valid_id(data, id_b, userdata, @src());
                            const tmp = GET_(data, id_b, userdata);
                            const data_2 = SET_(data, id_b, GET_(data, id_a, userdata), userdata);
                            return SET_(data_2, id_a, tmp, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `swap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LESS_THAN = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.LESS_THAN) |cust| cust //
                            else if (FLAGS.has(INFER.LT.FROM_GTEQ)) infer_gteq //
                            else if (FLAGS.has(INFER.LT.FROM_GT_OQ)) infer_gt_oq //
                            else if (FLAGS.has(INFER.LT.FROM_GT_EQ)) infer_gt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a < val_b;
                        }
                        fn infer_gteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GTEQ = GREATER_THAN_OR_EQUAL.func;
                            return !GTEQ(val_a, val_b, userdata);
                        }
                        fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const EQ = EXACT_EQUAL.func;
                            return !GT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                        }
                        fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const OQ = ORDER_EQUAL.func;
                            return !GT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `less_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LESS_THAN_OR_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.LESS_THAN_OR_EQUAL) |cust| cust //
                            else if (FLAGS.has(INFER.LTEQ.FROM_GT)) infer_gt //
                            else if (FLAGS.has(INFER.LTEQ.FROM_LT_OQ)) infer_lt_oq //
                            else if (FLAGS.has(INFER.LTEQ.FROM_LT_EQ)) infer_lt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a <= val_b;
                        }
                        fn infer_gt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            return !GT(val_a, val_b, userdata);
                        }
                        fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LT = LESS_THAN.func;
                            const EQ = EXACT_EQUAL.func;
                            return LT(val_a, val_b, userdata) or EQ(val_a, val_b, userdata);
                        }
                        fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LT = LESS_THAN.func;
                            const OQ = ORDER_EQUAL.func;
                            return LT(val_a, val_b, userdata) or OQ(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `less_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GREATER_THAN = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.GREATER_THAN) |cust| cust //
                            else if (FLAGS.has(INFER.GT.FROM_LTEQ)) infer_lteq //
                            else if (FLAGS.has(INFER.GT.FROM_LT_OQ)) infer_lt_oq //
                            else if (FLAGS.has(INFER.GT.FROM_LT_EQ)) infer_lt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a > val_b;
                        }
                        fn infer_lteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LTEQ = LESS_THAN_OR_EQUAL.func;
                            return !LTEQ(val_a, val_b, userdata);
                        }
                        fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LT = LESS_THAN.func;
                            const EQ = EXACT_EQUAL.func;
                            return !LT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                        }
                        fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LT = LESS_THAN.func;
                            const OQ = ORDER_EQUAL.func;
                            return !LT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `greater_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GREATER_THAN_OR_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.GREATER_THAN_OR_EQUAL) |cust| cust //
                            else if (FLAGS.has(INFER.GTEQ.FROM_LT)) infer_lt //
                            else if (FLAGS.has(INFER.GTEQ.FROM_GT_OQ)) infer_gt_oq //
                            else if (FLAGS.has(INFER.GTEQ.FROM_GT_EQ)) infer_gt_eq //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a >= val_b;
                        }
                        fn infer_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const LT = LESS_THAN.func;
                            return !LT(val_a, val_b, userdata);
                        }
                        fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const EQ = EXACT_EQUAL.func;
                            return !GT(val_a, val_b, userdata) and !EQ(val_a, val_b, userdata);
                        }
                        fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const OQ = ORDER_EQUAL.func;
                            return !GT(val_a, val_b, userdata) and !OQ(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `greater_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ORDER_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.ORDER_EQUALS) |cust| cust //
                            else if (FLAGS.has(INFER.OQ.FROM_EQ)) infer_eq //
                            else if (FLAGS.has(INFER.OQ.FROM_GT_LT)) infer_gt_lt //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a == val_b;
                        }
                        fn infer_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const EQ = EXACT_EQUAL.func;
                            return !EQ(val_a, val_b, userdata);
                        }
                        fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const LT = LESS_THAN.func;
                            return !GT(val_a, val_b, userdata) and !LT(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `order_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const EXACT_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = if (CUSTOM.EXACT_EQUALS) |cust| cust //
                            else if (FLAGS.has(INFER.EQ.FROM_OQ)) infer_oq //
                            else if (FLAGS.has(INFER.EQ.FROM_GT_LT)) infer_gt_lt //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a == val_b;
                        }
                        fn infer_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const OQ = ORDER_EQUAL.func;
                            return !OQ(val_a, val_b, userdata);
                        }
                        fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            const GT = GREATER_THAN.func;
                            const LT = LESS_THAN.func;
                            return !GT(val_a, val_b, userdata) and !LT(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `exactly_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const FIRST_ID = struct {
                        const func: FN_IMPLICIT_ID = if (CUSTOM.FIRST_ID) |cust| cust //
                            else if (FLAGS.has(INFER.FIRST_ID.FROM_NTH_FROM_START)) infer_nth_start //
                            else if (FLAGS.has(INFER.FIRST_ID.FROM_LEN_NTH_FROM_END)) infer_nth_end //
                            else if (FLAGS.has(INFER.FIRST_ID.FROM_LAST_LEN_NTH_PREV)) infer_last_len_nth_prev //
                            else if (FLAGS.has(INFER.FIRST_ID.FROM_LAST_LEN_PREV)) infer_last_len_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, _: USERDATA_) ID_ {
                            return 0;
                        }
                        fn infer_nth_start(data: DATA_, userdata: USERDATA_) ID_ {
                            const NTH_START = NTH_FROM_START.func;
                            return NTH_START(data, 0, userdata);
                        }
                        fn infer_nth_end(data: DATA_, userdata: USERDATA_) ID_ {
                            const NTH_END = NTH_FROM_END.func;
                            const LEN_ = GET_LEN.func;
                            return NTH_END(data, LEN_(data, userdata), userdata);
                        }
                        fn infer_last_len_nth_prev(data: DATA_, userdata: USERDATA_) ID_ {
                            const LAST = LAST_ID.func;
                            const LEN_ = GET_LEN.func;
                            const NTH_PREV_ = NTH_PREV_ID.func;
                            return NTH_PREV_(data, LAST(data, userdata), LEN_(data, userdata), userdata);
                        }
                        fn infer_last_len_prev(data: DATA_, userdata: USERDATA_) ID_ {
                            const LAST = LAST_ID.func;
                            const LEN_ = GET_LEN.func;
                            const PREV_ = PREV_ID.func;
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
                    };
                    const LAST_ID = struct {
                        const func: FN_IMPLICIT_ID = if (CUSTOM.LAST_ID) |cust| cust //
                            else if (FLAGS.has(INFER.LAST_ID.FROM_NTH_FROM_LAST)) infer_nth_last //
                            else if (FLAGS.has(INFER.LAST_ID.FROM_LEN_NTH_FROM_START)) infer_nth_start //
                            else if (FLAGS.has(INFER.LAST_ID.FROM_FIRST_LEN_NTH_NEXT)) infer_first_len_nth_next //
                            else if (FLAGS.has(INFER.LAST_ID.FROM_FIRST_LEN_NEXT)) infer_first_len_next //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, userdata: USERDATA_) ID_ {
                            return GET_LEN.default(data, userdata) - 1;
                        }
                        fn infer_nth_last(data: DATA_, userdata: USERDATA_) ID_ {
                            const NTH_START = NTH_FROM_START.func;
                            return NTH_START(data, 0, userdata);
                        }
                        fn infer_nth_start(data: DATA_, userdata: USERDATA_) ID_ {
                            const NTH_START = NTH_FROM_START.func;
                            const LEN_ = GET_LEN.func;
                            return NTH_START(data, LEN_(data, userdata), userdata);
                        }
                        fn infer_first_len_nth_next(data: DATA_, userdata: USERDATA_) ID_ {
                            const FIRST = FIRST_ID.func;
                            const LEN_ = GET_LEN.func;
                            const NTH_NEXT_ = NTH_PREV_ID.func;
                            return NTH_NEXT_(data, FIRST(data, userdata), LEN_(data, userdata), userdata);
                        }
                        fn infer_first_len_next(data: DATA_, userdata: USERDATA_) ID_ {
                            const FIRST = FIRST_ID.func;
                            const LEN_ = GET_LEN.func;
                            const NEXT_ = NEXT_ID.func;
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
                    };
                    const NEXT_ID = struct {
                        const func: FN_ADJACENT_ID = if (CUSTOM.NEXT_ID) |cust| cust //
                            else if (FLAGS.has(INFER.NEXT_ID.FROM_NTH_NEXT)) infer_nth_next //
                            else if (FLAGS.has(INFER.NEXT_ID.FROM_LAST_PREV)) infer_last_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                            return curr + 1;
                        }
                        fn infer_nth_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const NTH_NEXT = NTH_NEXT_ID.func;
                            return NTH_NEXT(data, curr, 1, userdata);
                        }
                        fn infer_last_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const LAST = LAST_ID.func;
                            const PREV = PREV_ID.func;
                            const ID_EQ = ID_EQUALS.func;
                            const INVALID_END = comptime INVALID_ID_AFTER.select();
                            const INVALID_BEFORE = comptime INVALID_ID_BEFORE.select();
                            const VALID = comptime ID_VALID.select();
                            var i = LAST(data, userdata);
                            if (ID_EQ(data, i, curr, userdata)) return INVALID_END(data, userdata);
                            var ii = PREV(data, i, userdata);
                            while (!ID_EQ(data, i, curr, userdata)) {
                                if (!VALID(data, ii, userdata)) return INVALID_BEFORE(data, userdata);
                                i = ii;
                                ii = PREV(data, i, userdata);
                            }
                            return i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const PREV_ID = struct {
                        const func: FN_ADJACENT_ID = if (CUSTOM.PREV_ID) |cust| cust //
                            else if (FLAGS.has(INFER.PREV_ID.FROM_NTH_PREV)) infer_nth_prev //
                            else if (FLAGS.has(INFER.PREV_ID.FROM_FIRST_NEXT)) infer_first_next //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                            return curr - 1;
                        }
                        fn infer_nth_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const NTH_PREV = NTH_PREV_ID.func;
                            return NTH_PREV(data, curr, 1, userdata);
                        }
                        fn infer_first_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const FIRST = FIRST_ID.func;
                            const NEXT = NEXT_ID.func;
                            const ID_EQ = ID_EQUALS.func;
                            const INVALID_END = comptime INVALID_ID_AFTER.select();
                            const INVALID_BEFORE = comptime INVALID_ID_BEFORE.select();
                            const VALID = comptime ID_VALID.select();
                            var i = FIRST(data, userdata);
                            if (ID_EQ(data, i, curr, userdata)) return INVALID_END(data, userdata);
                            var ii = NEXT(data, i, userdata);
                            while (!ID_EQ(data, ii, curr, userdata)) {
                                if (!VALID(data, ii, userdata)) return INVALID_BEFORE(data, userdata);
                                i = ii;
                                ii = NEXT(data, i, userdata);
                            }
                            return i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `prev_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_NEXT_ID = struct {
                        const func: FN_NTH_ID = if (CUSTOM.NTH_PREV_ID) |cust| cust //
                            else if (FLAGS.has(INFER.NTH_NEXT_ID.FROM_NEXT)) infer_next //
                            else if (FLAGS.has(INFER.NTH_NEXT_ID.FROM_LAST_PREV)) infer_last_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                            return curr + n;
                        }
                        fn infer_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const NEXT = NEXT_ID.func;
                            var i = curr;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                i = NEXT(data, i, userdata);
                            }
                            return i;
                        }
                        fn infer_last_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const LAST = LAST_ID.func;
                            const PREV = PREV_ID.func;
                            const ID_EQ = ID_EQUALS.func;
                            const INVALID_END = comptime INVALID_ID_AFTER.select();
                            const INVALID_BEFORE = comptime INVALID_ID_BEFORE.select();
                            const VALID = comptime ID_VALID.select();
                            const last = LAST(data, userdata);
                            var left_i = last;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                if (ID_EQ(data, left_i, curr, userdata) or !VALID(data, left_i, userdata)) return INVALID_END(data, userdata);
                                left_i = PREV(data, curr, userdata);
                            }
                            var right_i = last;
                            var left_ii = PREV(data, left_i, userdata);
                            var right_ii = PREV(data, last, userdata);
                            while (!ID_EQ(data, left_ii, curr, userdata)) {
                                left_i = left_ii;
                                left_ii = PREV(data, left_i, userdata);
                                if (!VALID(data, left_ii, userdata)) return INVALID_BEFORE(data, userdata);
                                right_i = right_ii;
                                right_ii = PREV(data, right_i, userdata);
                            }
                            return right_i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_PREV_ID = struct {
                        const func: FN_NTH_ID = if (CUSTOM.NTH_PREV_ID) |cust| cust //
                            else if (FLAGS.has(INFER.NTH_PREV_ID.FROM_PREV)) infer_prev //
                            else if (FLAGS.has(INFER.NTH_PREV_ID.FROM_FIRST_NEXT)) infer_first_next //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                            return curr - n;
                        }
                        fn infer_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const PREV = PREV_ID.func;
                            var i = curr;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                i = PREV(data, i, userdata);
                            }
                            return i;
                        }
                        fn infer_first_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const FIRST = FIRST_ID.func;
                            const NEXT = NEXT_ID.func;
                            const ID_EQ = ID_EQUALS.func;
                            const INVALID_END = comptime INVALID_ID_AFTER.select();
                            const INVALID_BEFORE = comptime INVALID_ID_BEFORE.select();
                            const VALID = ID_VALID.func;
                            const first = FIRST(data, userdata);
                            var right_i = first;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                if (ID_EQ(data, right_i, curr, userdata) or !VALID(data, right_i, userdata)) return INVALID_END(data, userdata);
                                right_i = NEXT(data, curr, userdata);
                            }
                            var left_i = first;
                            var right_ii = NEXT(data, right_i, userdata);
                            var left_ii = NEXT(data, first, userdata);
                            while (!ID_EQ(data, right_ii, curr, userdata)) {
                                right_i = right_ii;
                                right_ii = NEXT(data, right_i, userdata);
                                if (!VALID(data, right_ii, userdata)) return INVALID_BEFORE(data, userdata);
                                left_i = left_ii;
                                left_ii = NEXT(data, left_i, userdata);
                            }
                            return left_i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_prev_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_FROM_START = struct {
                        const func: FN_IMPLICIT_NTH_ID = if (CUSTOM.NTH_ID_FROM_START) |cust| cust //
                            else if (FLAGS.has(INFER.NTH_FROM_START.FROM_FIRST_NTH_NEXT)) infer_first_nth_next //
                            else if (FLAGS.has(INFER.NTH_FROM_START.FROM_FIRST_NEXT)) infer_first_next //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, n: COUNT_, _: USERDATA_) ID_ {
                            return n;
                        }
                        fn infer_first_nth_next(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            const NTH_NEXT = NTH_NEXT_ID.func;
                            const FIRST = FIRST_ID.func;
                            return NTH_NEXT(data, FIRST(data, userdata), n, userdata);
                        }
                        fn infer_first_next(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            const NEXT = NEXT_ID.func;
                            const FIRST = FIRST_ID.func;
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
                    };
                    const NTH_FROM_END = struct {
                        const func: FN_IMPLICIT_NTH_ID = if (CUSTOM.NTH_ID_FROM_END) |cust| cust //
                            else if (FLAGS.has(INFER.NTH_FROM_END.FROM_LAST_NTH_PREV)) infer_last_nth_prev //
                            else if (FLAGS.has(INFER.NTH_FROM_END.FROM_LAST_PREV)) infer_last_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            return GET_LEN.default(data, userdata) - 1 - n;
                        }
                        fn infer_last_nth_prev(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            const NTH_PREV = NTH_PREV_ID.func;
                            const LAST = LAST_ID.func;
                            return NTH_PREV(data, LAST(data, userdata), n, userdata);
                        }
                        fn infer_last_prev(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            const PREV = PREV_ID.func;
                            const LAST = LAST_ID.func;
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
                    };
                    const GET_LEN = struct {
                        const func: FN_IMPLICIT_COUNT = if (CUSTOM.GET_LEN) |cust| cust //
                            else if (FLAGS.has(INFER.LEN.FROM_FIRST_LAST_RANGE_LEN)) infer_range_len //
                            else if (FLAGS.has(INFER.LEN.FROM_FIRST_LAST_NEXT)) infer_first_last_next //
                            else if (FLAGS.has(INFER.LEN.FROM_FIRST_LAST_PREV)) infer_first_last_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        const default = default_len;
                        fn infer_range_len(data: DATA_, userdata: USERDATA_) COUNT_ {
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const RANGE = RANGE_LEN.func;
                            return RANGE(FIRST(data, userdata), LAST(data, userdata), userdata);
                        }
                        fn infer_first_last_next(data: DATA_, userdata: USERDATA_) COUNT_ {
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const NEXT = NEXT_ID.func;
                            const VALID = ID_VALID.func;
                            const ID_EQ = ID_EQUALS.func;
                            var i = FIRST(data, userdata);
                            const last = LAST(data, userdata);
                            if (!VALID(data, i, userdata) or !VALID(data, last, userdata)) return 0;
                            var n: COUNT_ = 1;
                            while (!ID_EQ(data, i, last, userdata)) {
                                i = NEXT(data, i, userdata);
                                n += 1;
                            }
                            return n;
                        }
                        fn infer_first_last_prev(data: DATA_, userdata: USERDATA_) COUNT_ {
                            const FIRST = FIRST_ID.func;
                            const LAST = LAST_ID.func;
                            const PREV = PREV_ID.func;
                            const VALID = ID_VALID.func;
                            const ID_EQ = ID_EQUALS.func;
                            var i = LAST(data, userdata);
                            const first = FIRST(data, userdata);
                            if (!VALID(data, i, userdata) or !VALID(data, first, userdata)) return 0;
                            var n: COUNT_ = 1;
                            while (!ID_EQ(data, i, first, userdata)) {
                                i = PREV(data, i, userdata);
                                n += 1;
                            }
                            return n;
                        }
                        fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET_LEN = struct {
                        const func: FN_SET_COUNT = if (CUSTOM.SET_LEN) |cust| cust //
                            else if (ALLOW_DEFAULT) default else unusable;
                        const default = default_set_len;
                        fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `set_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const RANGE_LEN = struct {
                        const func: FN_RANGE_COUNT = if (CUSTOM.RANGE_LEN) |cust| cust //
                            else if (FLAGS.has(INFER.RANGE_LEN.FROM_NEXT)) infer_next //
                            else if (FLAGS.has(INFER.RANGE_LEN.FROM_PREV)) infer_prev //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(_: DATA_, first: ID_, last: ID_, _: USERDATA_) ID_ {
                            return (last + 1) - first;
                        }
                        fn infer_next(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            const NEXT = NEXT_ID.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const VALID = ID_VALID.func;
                            const ID_EQ = ID_EQUALS.func;
                            if (!ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                            var i = first;
                            var n: COUNT_ = 1;
                            while (!ID_EQ(data, i, last, userdata)) {
                                if (!VALID(data, i, userdata)) return 0;
                                i = NEXT(data, i, userdata);
                                n += 1;
                            }
                            return n;
                        }
                        fn infer_prev(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            const PREV = PREV_ID.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const VALID = ID_VALID.func;
                            const ID_EQ = ID_EQUALS.func;
                            if (!ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                            var i = last;
                            var n: COUNT_ = 1;
                            while (!ID_EQ(data, i, first, userdata)) {
                                if (!VALID(data, i, userdata)) return 0;
                                i = PREV(data, i, userdata);
                                n += 1;
                            }
                            return n;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `range_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const REVERSE_RANGE = struct {
                        const func: FN_RANGE_OP = if (CUSTOM.REVERSE_RANGE) |cust| cust //
                            else if (FLAGS.has_any(&.{ INFER.REVERSE.FROM_GET_SET, INFER.REVERSE.FROM_SWAP })) infer_swap //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            const new_data = data;
                            Utils.Mem.reverse_slice(default_get_base_ptr(new_data, userdata)[first .. last + 1]);
                            return new_data;
                        }
                        fn infer_swap(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            const SWAP_ = SWAP.func;
                            const NEXT = NEXT_ID.func;
                            const PREV = PREV_ID.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const ID_EQ = ID_EQUALS.func;
                            if (!ID_LESS_OR_EQUAL(data, first, last, userdata)) return 0;
                            var new_data = data;
                            var left = first;
                            var right = last;
                            while (!ID_EQ(data, left, right, userdata)) {
                                new_data = SWAP_(new_data, left, right, userdata);
                                left = NEXT(data, left, userdata);
                                if (ID_EQ(data, left, right, userdata)) break;
                                right = PREV(new_data, right, userdata);
                            }
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `range_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ROTATE_RIGHT = struct {
                        const func: FN_ROTATE = if (CUSTOM.ROTATE_RANGE_RIGHT) |cust| cust //
                            else if (FLAGS.has_any(&.{ INFER.ROTATE.FROM_GET_SET, INFER.ROTATE.FROM_REVERSE, INFER.ROTATE.FROM_SWAP })) infer_reverse //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
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
                        fn infer_reverse(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            const REV = REVERSE_RANGE.func;
                            const NEXT = NEXT_ID.func;
                            const NTH_PREV = NTH_PREV_ID.func;
                            const ID_LESS_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL.select();
                            const RANGE_LEN_ = RANGE_LEN.func;
                            if (!ID_LESS_OR_EQUAL(data, first, last, userdata)) return data;
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
                    };
                    const ROTATE_LEFT = struct {
                        const func: FN_ROTATE = if (CUSTOM.ROTATE_RANGE_LEFT) |cust| cust //
                            else if (FLAGS.has_any(&.{ INFER.ROTATE.FROM_GET_SET, INFER.ROTATE.FROM_REVERSE, INFER.ROTATE.FROM_SWAP })) infer_reverse //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
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
                        fn infer_reverse(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            const REV = REVERSE_RANGE.func;
                            const NTH_NEXT = NTH_NEXT_ID.func;
                            const PREV = PREV_ID.func;
                            const ID_LESS_OR_EQUAL = comptime ID_LESS_THAN_OR_EQUAL.select();
                            const RANGE_LEN_ = RANGE_LEN.func;
                            if (!ID_LESS_OR_EQUAL(data, first, last, userdata)) return data;
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
                    };
                    const MOVE_ONE_PRESERVE = struct {
                        const func: FN_RANGE_OP = if (CUSTOM.MOVE_ONE_PRESERVE) |cust| cust //
                            else if (FLAGS.has(INFER.MOVE_ONE.FROM_GET_SET)) infer_get_set //
                            else if (FLAGS.has(INFER.MOVE_ONE.FROM_MOVE_BLOCK)) infer_move_block //
                            else if (FLAGS.has_any(&.{ INFER.MOVE.FROM_GET_SET, INFER.MOVE.FROM_REVERSE, INFER.MOVE.FROM_SWAP, INFER.MOVE.FROM_ROTATE })) infer_rotate //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_with_reason(old_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ old_id, GET_LEN.default(data, userdata) });
                            assert_with_reason(new_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_id, GET_LEN.default(data, userdata) });
                            var new_data = data;
                            if (old_id == new_id) return data;
                            if (old_id < new_id) {
                                const old_val = GET.default(data, old_id, userdata);
                                var i = old_id;
                                var ii = i;
                                while (i != new_id) {
                                    i += 1;
                                    const val_to_move = GET.default(data, i, userdata);
                                    new_data = SET.default(new_data, ii, val_to_move, userdata);
                                    ii = i;
                                }
                                new_data = SET.default(new_data, new_id, old_val, userdata);
                            } else {
                                const old_val = GET.default(data, old_id, userdata);
                                var i = old_id;
                                var ii = i;
                                while (i != new_id) {
                                    i -= 1;
                                    const val_to_move = GET.default(data, i, userdata);
                                    new_data = SET.default(new_data, ii, val_to_move, userdata);
                                    ii = i;
                                }
                                new_data = SET.default(new_data, new_id, old_val, userdata);
                            }
                            return new_data;
                        }
                        fn infer_move_block(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            const MOVE_BLOCK = MOVE_BLOCK_PRESERVE.func;
                            return MOVE_BLOCK(data, old_id, old_id, new_id, userdata);
                        }
                        fn infer_get_set(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            const GET_ = GET.func;
                            const SET_ = SET.func;
                            const NEXT = NEXT_ID.func;
                            const PREV = PREV_ID.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const ID_EQ = ID_EQUALS.func;
                            var new_data = data;
                            if (ID_EQ(data, old_id, new_id, userdata)) return data;
                            if (ID_LESS_OR_EQUAL(data, old_id, new_id, userdata)) {
                                const old_val = GET_(data, old_id, userdata);
                                var i = old_id;
                                var ii = i;
                                while (!ID_EQ(data, i, new_id, userdata)) {
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
                                while (!ID_EQ(data, i, new_id, userdata)) {
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
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            const ROT_L = ROTATE_LEFT.func;
                            const ROT_R = ROTATE_RIGHT.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const ID_EQ = ID_EQUALS.func;
                            var new_data = data;
                            if (ID_EQ(data, old_id, new_id, userdata)) return data;
                            if (ID_LESS_OR_EQUAL(data, old_id, new_id, userdata)) {
                                new_data = ROT_L(data, old_id, new_id, 1, userdata);
                            } else {
                                new_data = ROT_R(data, new_id, old_id, 1, userdata);
                            }
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_one_element_preserve_displaced_elements` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_BLOCK_PRESERVE = struct {
                        const func: FN_MOVE_BLOCK = if (CUSTOM.MOVE_BLOCK_PRESERVE) |cust| cust //
                            else if (FLAGS.has_any(&.{ INFER.MOVE.FROM_GET_SET, INFER.MOVE.FROM_REVERSE, INFER.MOVE.FROM_SWAP, INFER.MOVE.FROM_ROTATE })) infer_rotate //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_with_reason(first_old_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ first_old_id, GET_LEN.default(data, userdata) });
                            assert_with_reason(last_old_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ last_old_id, GET_LEN.default(data, userdata) });
                            assert_with_reason(new_first_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_first_id, GET_LEN.default(data, userdata) });
                            assert_with_reason(first_old_id <= last_old_id, @src(), "first id must be <= last id (by data order), got `{any}` > `{any}`", .{ first_old_id, last_old_id });
                            var new_data = data;
                            if (first_old_id == new_first_id) return data;
                            const block_len = (last_old_id + 1) - first_old_id;
                            if (first_old_id < new_first_id) {
                                const new_last_id = new_first_id + (block_len - 1);
                                assert_with_reason(new_last_id < GET_LEN.default(data, userdata), @src(), "index {d} out of range for len {d}", .{ new_last_id, GET_LEN.default(data, userdata) });
                                const delta = new_first_id - first_old_id;
                                new_data = ROTATE_LEFT.default(data, first_old_id, new_last_id, delta, userdata);
                            } else {
                                const delta = first_old_id - new_first_id;
                                new_data = ROTATE_RIGHT.default(data, new_first_id, last_old_id, delta, userdata);
                            }
                            return new_data;
                        }
                        fn infer_rotate(data: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first_old_id, userdata, @src());
                            assert_valid_id(data, last_old_id, userdata, @src());
                            assert_valid_id(data, new_first_id, userdata, @src());
                            const ROT_L = ROTATE_LEFT.func;
                            const ROT_R = ROTATE_RIGHT.func;
                            const RANGE_LEN_ = RANGE_LEN.func;
                            const NTH_NEXT = NTH_NEXT_ID.func;
                            const ID_LESS_OR_EQUAL = ID_LESS_THAN_OR_EQUAL.func;
                            const ID_EQ = ID_EQUALS.func;
                            assert_with_reason(ID_LESS_OR_EQUAL(data, first_old_id, last_old_id, userdata), @src(), "first id must be <= last id (by data order), got `{any}` > `{any}`", .{ first_old_id, last_old_id });
                            var new_data = data;
                            if (ID_EQ(data, first_old_id, new_first_id, userdata)) return data;
                            const block_len = RANGE_LEN_(data, first_old_id, last_old_id, userdata);
                            if (ID_LESS_OR_EQUAL(data, first_old_id, new_first_id, userdata)) {
                                const new_last_id = NTH_NEXT(data, new_first_id, block_len - 1, userdata);
                                assert_valid_id(data, new_last_id, userdata, @src());
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
                    };
                    const SCRAMBLE = struct {
                        const func: FN_SCRAMBLE = if (CUSTOM.SCRAMBLE) |cust| cust //
                            else if (ALLOW_DEFAULT) default else unusable;
                        fn default(data: DATA_, rand: Random, first: ID_, last: ID_, iterations: COUNT_, userdata: USERDATA_) DATA_ {
                            var new_data = data;
                            const span = (last + 1) - first;
                            if (span <= 1) return data;
                            if (span == 2) {
                                if (rand.boolean()) {
                                    return SWAP.default(data, first, last);
                                }
                            }
                            var n: COUNT_ = 0;
                            const first_idx = rand.intRangeAtMost(ID_, first, last);
                            const first_val = GET.default(data, first_idx, userdata);
                            var empty_idx: ID_ = first_idx;
                            while (n < iterations) : (n += 1) {
                                const move_idx = find_different_idx: {
                                    while (true) {
                                        const possible_different = rand.intRangeAtMost(ID_, first_idx, last);
                                        if (possible_different != empty_idx) break :find_different_idx possible_different;
                                    }
                                };
                                new_data = SET.default(data, empty_idx, GET.default(data, move_idx, userdata), userdata);
                                empty_idx = move_idx;
                            }
                            return SET.default(new_data, empty_idx, first_val, userdata);
                        }
                        fn unusable(_: DATA_, _: Random, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `scramble_elements` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                };
            }

            pub fn select_functions(comptime ALLOW_DEFAULT: bool, comptime CUSTOM: CustomDataFuncs, comptime CUSTOM_FIELD_FUNCS: anytype) DEF_WITH_FUNCS {
                comptime {
                    // BUILD FLAGS FOR PROVIDED CUSTOM FUNCTIONS
                    var FLAGS = FuncFlags{};
                    for (@typeInfo(F).@"struct".decls) |FNN| {
                        const FN_NAME = FNN.name;
                        FLAGS.add_if_not_null(@field(F, FN_NAME), @field(CUSTOM, FN_NAME));
                    }
                    // SELECT THE CORRECT FUNCTION FOR EACH GIVEN THE CUSTOM/FLAGS/ALLOW_DEFAULT
                    const PROTO = FunctionSelector(CUSTOM, FLAGS, ALLOW_DEFAULT);
                    const FINAL_FUNCS: DEF_WITH_FUNCS = DEF_WITH_FUNCS{
                        .ID_EQUALS = PROTO.ID_EQUALS.func,
                        .ID_LESS_THAN = PROTO.ID_LESS_THAN.func,
                        .ID_LESS_THAN_OR_EQUAL = PROTO.ID_LESS_THAN_OR_EQUAL.func,
                        .ID_GREATER_THAN = PROTO.ID_GREATER_THAN.func,
                        .ID_GREATER_THAN_OR_EQUAL = PROTO.ID_GREATER_THAN_OR_EQUAL.func,
                        .ID_VALID = PROTO.ID_VALID.func,
                        .ID_INVALID_AFTER = PROTO.INVALID_ID_AFTER.func,
                        .ID_INVALID_BEFORE = PROTO.INVALID_ID_BEFORE.func,
                        .FIRST_ID = PROTO.FIRST_ID.func,
                        .LAST_ID = PROTO.LAST_ID.func,
                        .NTH_ID_FROM_START = PROTO.NTH_FROM_START.func,
                        .NTH_ID_FROM_END = PROTO.NTH_FROM_END.func,
                        .PREV_ID = PROTO.PREV_ID.func,
                        .NEXT_ID = PROTO.NEXT_ID.func,
                        .NTH_PREV_ID = PROTO.NTH_PREV_ID.func,
                        .NTH_NEXT_ID = PROTO.NTH_NEXT_ID.func,
                        .GET_LEN = PROTO.GET_LEN.func,
                        .SET_LEN = PROTO.SET_LEN.func,
                        .RANGE_LEN = PROTO.RANGE_LEN.func,
                        .GET = PROTO.GET.func,
                        .GET_PTR = PROTO.GET_PTR.func,
                        .GET_CONST_PTR = PROTO.GET_CONST_PTR.func,
                        .SET = PROTO.SET.func,
                        .SWAP = PROTO.SWAP.func,
                        .GREATER_THAN = PROTO.GREATER_THAN.func,
                        .GREATER_THAN_OR_EQUAL = PROTO.GREATER_THAN_OR_EQUAL.func,
                        .LESS_THAN = PROTO.LESS_THAN.func,
                        .LESS_THAN_OR_EQUAL = PROTO.LESS_THAN_OR_EQUAL.func,
                        .ORDER_EQUALS = PROTO.ORDER_EQUAL.func,
                        .EXACT_EQUALS = PROTO.EXACT_EQUAL.func,
                        .REVERSE_RANGE = PROTO.REVERSE_RANGE.func,
                        .MOVE_ONE_PRESERVE = PROTO.MOVE_ONE_PRESERVE.func,
                        .MOVE_BLOCK_PRESERVE = PROTO.MOVE_BLOCK_PRESERVE.func,
                        .ROTATE_RIGHT = PROTO.ROTATE_RIGHT.func,
                        .ROTATE_LEFT = PROTO.ROTATE_LEFT.func,
                        .SCRAMBLE = PROTO.SCRAMBLE.func,
                    };
                    // CHECK FIELD FUNCS TYPE FOR PROPER LAYOUT
                    const FIELD_FUNCS_TYPE = @TypeOf(CUSTOM_FIELD_FUNCS);
                    const FIELD_FUNCS_KIND = KindInfo.get_kind_info(FIELD_FUNCS_TYPE);
                    switch (FIELD_FUNCS_KIND) {
                        .STRUCT => |STRUCT| {
                            for (STRUCT.decls) |decl| {
                                const DECL_TYPE = @TypeOf(@field(FIELD_FUNCS_TYPE, decl.name));
                                const DECL_KIND = KindInfo.get_kind_info(DECL_TYPE);
                                switch (DECL_KIND) {
                                    .STRUCT => |DECL_STRUCT| {
                                        assert_with_reason(@hasDecl(DECL_TYPE, "FIELD_TYPE") and @TypeOf(@field(DECL_TYPE, "FIELD_TYPE")) == type, @src(), "every sub-struct in the 'custom field funcs' struct MUST have a `pub const FIELD_TYPE: type = <type returned by the field functions>;` declaration, but field `{s}` was missing one. See the example:" ++ FIELD_FUNCS_EXAMPLE, .{decl.name});
                                        const F_TYPE = @field(DECL_TYPE, "FIELD_TYPE");
                                        const F_GET_FN = fn (DATA_, ID_, USERDATA_) F_TYPE;
                                        const F_GET_PTR_FN = fn (DATA_, ID_, USERDATA_) *F_TYPE;
                                        const F_GET_CONST_PTR_FN = fn (DATA_, ID_, USERDATA_) *const F_TYPE;
                                        const F_SET_FN = fn (DATA_, ID_, F_TYPE, USERDATA_) DATA_;
                                        for (DECL_STRUCT.decls) |func_decl| {
                                            if (std.mem.eql(u8, func_decl.name, "FIELD_TYPE")) {} //
                                            else if (std.mem.eql(u8, func_decl.name, "get")) {
                                                const GOT_TYPE = @TypeOf(@field(DECL_TYPE, "get"));
                                                assert_with_reason(GOT_TYPE == F_GET_FN, @src(), "field 'get' functions must have the signature: `{s}`, but found type `{s}`", .{ @typeName(F_GET_FN), @typeName(GOT_TYPE) });
                                            } else if (std.mem.eql(u8, func_decl.name, "get_ptr")) {
                                                const GOT_TYPE = @TypeOf(@field(DECL_TYPE, "get_ptr"));
                                                assert_with_reason(GOT_TYPE == F_GET_PTR_FN, @src(), "field 'get_ptr' functions must have the signature: `{s}`, but found type `{s}`", .{ @typeName(F_GET_PTR_FN), @typeName(GOT_TYPE) });
                                            } else if (std.mem.eql(u8, func_decl.name, "get_const_ptr")) {
                                                const GOT_TYPE = @TypeOf(@field(DECL_TYPE, "get_const_ptr"));
                                                assert_with_reason(GOT_TYPE == F_GET_PTR_FN, @src(), "field 'get_const_ptr' functions must have the signature: `{s}`, but found type `{s}`", .{ @typeName(F_GET_CONST_PTR_FN), @typeName(GOT_TYPE) });
                                            } else if (std.mem.eql(u8, func_decl.name, "set")) {
                                                const GOT_TYPE = @TypeOf(@field(DECL_TYPE, "set"));
                                                assert_with_reason(GOT_TYPE == F_GET_PTR_FN, @src(), "field 'set' functions must have the signature: `{s}`, but found type `{s}`", .{ @typeName(F_SET_FN), @typeName(GOT_TYPE) });
                                                continue;
                                            } else {
                                                assert_unreachable(@src(), "custom field function sub-struct `{s}` has a declaration other than the allowed `FIELD_TYPE`, `get`, `get_ptr`, `get_const_ptr`, `set` declarations, got illegal `{s}`", .{ decl.name, func_decl });
                                            }
                                        }
                                    },
                                    else => {
                                        assert_unreachable(@src(), "provided 'custom field funcs' struct had a declaration that was not a struct type. All declarations on the outer struct must be struct types as in this example:" ++ FIELD_FUNCS_EXAMPLE, .{});
                                    },
                                }
                            }
                        },
                        .NULL, .VOID => {},
                        else => {
                            assert_unreachable(@src(), "type `{s}` is not a valid type for custom field functions. It must either be `null` or a struct type with the format:" ++ FIELD_FUNCS_EXAMPLE, .{@typeName(FIELD_FUNCS_TYPE)});
                        },
                    }
                    return FINAL_FUNCS;
                }
            }
            pub fn Finalize(comptime FUNCS: DEF_WITH_FUNCS, comptime CUSTOM_FIELD_FUNCS_TYPE: type, comptime CUSTOM_FIELD_FUNCS: CUSTOM_FIELD_FUNCS_TYPE) type {
                return struct {
                    pub const DEF = CORE_DEF_;
                    pub const DATA = DEF.DATA;
                    pub const ID = DEF.ID;
                    pub const ELEM = DEF.ELEM;
                    pub const COUNT = DEF.COUNT_INT;
                    pub const USERDATA = DEF.USERDATA;

                    pub const field = CUSTOM_FIELD_FUNCS;

                    pub const get: fn (DATA, ID, USERDATA) ELEM = FUNCS.GET;
                    pub const get_ptr: fn (DATA, ID, USERDATA) *ELEM = FUNCS.GET_PTR;
                    pub const get_const_ptr: fn (DATA, ID, USERDATA) *const ELEM = FUNCS.GET_CONST_PTR;
                    pub const set: fn (DATA, ID, ELEM, USERDATA) DATA = FUNCS.SET;
                    pub const get_len: fn (DATA, USERDATA) COUNT = FUNCS.GET_LEN;
                    pub const set_len: fn (DATA, new_len: COUNT, USERDATA) DATA = FUNCS.SET_LEN;
                    pub const id_valid: fn (DATA, ID, USERDATA) bool = FUNCS.ID_VALID;
                    pub const id_invalid_after: fn (DATA, USERDATA) ID = FUNCS.ID_INVALID_AFTER;
                    pub const id_invalid_before: fn (DATA, USERDATA) ID = FUNCS.ID_INVALID_BEFORE;
                    pub const id_less_than: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_LESS_THAN;
                    pub const id_less_than_or_equal: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_LESS_THAN_OR_EQUAL;
                    pub const id_greater_than: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_GREATER_THAN;
                    pub const id_greater_than_or_equal: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_GREATER_THAN_OR_EQUAL;
                    pub const id_equals: fn (DATA, a: ID, b: ID, USERDATA) bool = FUNCS.ID_EQUALS;
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
                    pub const rotate_range_left: fn (DATA, first: ID, last: ID, n: COUNT, USERDATA) DATA = FUNCS.ROTATE_LEFT;
                    pub const rotate_range_right: fn (DATA, first: ID, last: ID, n: COUNT, USERDATA) DATA = FUNCS.ROTATE_RIGHT;
                    pub const move_one_displace_others: fn (DATA, old_id: ID, new_id: ID, USERDATA) DATA = FUNCS.MOVE_ONE_PRESERVE;
                    pub const move_range_displace_others: fn (DATA, old_first: ID, old_last: ID, new_first: ID, USERDATA) DATA = FUNCS.MOVE_BLOCK_PRESERVE;
                    pub const scramble: fn (DATA, rand: Random, first: ID, last: ID, iterations: COUNT, USERDATA) DATA = FUNCS.SCRAMBLE;

                    pub fn limit_len(data: DATA, start: ID, limit: ID, userdata: USERDATA) COUNT {
                        return range_len(data, start, prev_id(data, limit, userdata), userdata);
                    }

                    pub fn swap_already_have_b(data: DATA, id_a: ID, id_b: ID, val_b: ELEM, userdata: USERDATA) DATA {
                        const new_data = set(data, id_b, get(data, id_a, userdata), userdata);
                        return set(new_data, id_a, val_b, userdata);
                    }

                    pub fn less_than_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return less_than(val_a, val_b, userdata);
                    }
                    pub fn less_than_or_equal_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return less_than_or_equal(val_a, val_b, userdata);
                    }
                    pub fn greater_than_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return greater_than(val_a, val_b, userdata);
                    }
                    pub fn greater_than_or_equal_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return greater_than_or_equal(val_a, val_b, userdata);
                    }
                    pub fn order_equals_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return order_equals(val_a, val_b, userdata);
                    }
                    pub fn exact_equals_by_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA) bool {
                        const val_a = get(data, id_a, userdata);
                        const val_b = get(data, id_b, userdata);
                        return exact_equals(val_a, val_b, userdata);
                    }

                    pub fn assert_id_less_than_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        assert_with_reason(id_less_than(data, id_a, id_b, userdata), src, "id_a `{any}` is not less than id_b `{any}`", .{ id_a, id_b });
                    }
                    pub fn assert_id_less_than_or_equal_id(data: DATA, id_a: ID, id_b: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        assert_with_reason(id_less_than_or_equal(data, id_a, id_b, userdata), src, "id_a `{any}` is not less or equal to than id_b `{any}`", .{ id_a, id_b });
                    }
                    pub fn assert_id_valid(data: DATA, id: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        assert_with_reason(id_valid(data, id, userdata), src, "id `{any}` is not valid for the data structure state (first = `{any}`, last = `{any}`, len = `{d}`)", .{ id, first_id(data, userdata), last_id(data, userdata), get_len(data, userdata) });
                    }
                    pub fn assert_valid_range(data: DATA, first: ID, last: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        assert_id_valid(data, first, userdata, src);
                        assert_id_valid(data, last, userdata, src);
                        assert_id_less_than_or_equal_id(data, first, last, userdata, src);
                    }
                    pub fn assert_valid_range_3(data: DATA, first: ID, mid: ID, last: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        assert_id_valid(data, first, userdata, src);
                        assert_id_valid(data, mid, userdata, src);
                        assert_id_valid(data, last, userdata, src);
                        assert_id_less_than_or_equal_id(data, first, last, userdata, src);
                        assert_id_less_than_or_equal_id(data, first, mid, userdata, src);
                        assert_id_less_than_or_equal_id(data, mid, last, userdata, src);
                    }

                    pub const USERDATA_UNINIT = if (USERDATA == void) void{} else undefined;

                    pub const SortInputs = struct {
                        data: DATA,
                        first: ID,
                        last: ID,
                        userdata: USERDATA = USERDATA_UNINIT,

                        pub fn with_data(self: SortInputs, new_data: DATA) SortInputs {
                            var new_self = self;
                            new_self.data = new_data;
                            return new_self;
                        }

                        pub fn sub_slice(self: SortInputs, new_data: DATA, first: COUNT, last: COUNT) SortInputs {
                            return SortInputs{
                                .data = new_data,
                                .first = first,
                                .last = last,
                                .userdata = self.userdata,
                            };
                        }
                    };
                    pub const HeapifiyInputs = struct {
                        data: DATA,
                        id: ID,
                        userdata: USERDATA = USERDATA_UNINIT,
                    };

                    pub const IdElemPair = struct { COUNT, ELEM };

                    pub fn median_of_3(data: DATA, ids_: [3]COUNT, userdata: USERDATA) IdElemPair {
                        var ids = ids_;
                        var tmp: COUNT = undefined;
                        if (less_than_by_id(data, ids[1], ids[0], userdata)) {
                            tmp = ids[0];
                            ids[0] = ids[1];
                            ids[1] = tmp;
                        }
                        if (less_than_by_id(data, ids[2], ids[0], userdata)) {
                            tmp = ids[0];
                            ids[0] = ids[2];
                            ids[2] = tmp;
                        }
                        if (less_than_by_id(data, ids[2], ids[1], userdata)) {
                            return .{ ids[2], get(data, ids[2], userdata) };
                        }
                        return .{ ids[1], get(data, ids[1], userdata) };
                    }

                    pub fn is_sorted(in: SortInputs) bool {
                        assert_valid_range(in.data, in.first, in.last, in.userdata, @src());
                        if (id_equals(in.data, in.first, in.last, in.userdata)) return true;
                        var next_id_to_check = next_id(in.data, in.first, in.userdata);
                        var val_left: ELEM = get(in.data, in.start, in.userdata);
                        var val_right: ELEM = undefined;
                        while (true) {
                            val_right = get(in.data, next_id_to_check, in.userdata);
                            if (greater_than(val_left, val_right, in.userdata)) return false;
                            if (id_equals(in.data, next_id_to_check, in.last, in.userdata)) {
                                @branchHint(.unlikely);
                                return true;
                            }
                            val_left = val_right;
                            next_id_to_check = next_id(in.data, next_id_to_check, in.userdata);
                        }
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
                        assert_valid_range(in.data, in.first, in.last, in.userdata, @src());
                        if (id_equals(in.data, in.first, in.last, in.userdata)) {
                            @branchHint(.unlikely);
                            return true;
                        }
                        var id_to_sort: COUNT = next_id(in.data, in.first, in.userdata);
                        var id_right: COUNT = undefined;
                        var id_left: COUNT = undefined;
                        var val_to_sort: ELEM = undefined;
                        var data = in.data;
                        while (true) {
                            val_to_sort = get(data, id_to_sort, in.userdata);
                            id_right = id_to_sort;
                            inner: while (true) {
                                id_left = prev_id(data, id_right, in.userdata);
                                const val_left = get(data, id_left, in.userdata);
                                if (greater_than(val_left, val_to_sort, in.userdata)) {
                                    data = set(data, id_right, val_left, in.userdata);
                                    id_right = id_left;
                                } else {
                                    break :inner;
                                }
                                if (id_equals(data, id_left, in.first, in.userdata)) {
                                    @branchHint(.unlikely);
                                    break :inner;
                                }
                            }
                            data = set(data, id_right, val_to_sort, in.userdata);
                            if (id_equals(data, id_to_sort, in.last, in.userdata)) {
                                @branchHint(.unlikely);
                                return data;
                            }
                            id_to_sort = next_id(data, id_to_sort, in.userdata);
                        }
                    }

                    fn assert_stack_can_support_sort_len(comptime SETTINGS: QuicksortSettings, in: SortInputs, comptime src: SourceLocation) void {
                        const data_len = range_len(in.data, in.first, in.last, in.userdata);
                        const needed_stack_len: u8 = @intCast(std.math.log2_int(COUNT, data_len) + 1);
                        assert_with_reason(SETTINGS.QUICKSORT_MAX_STACK >= needed_stack_len, src, "the provided `.QUICKSORT_MAX_STACK` setting ({d}) is too small, need stack len {d} for given the data len {d}", .{ SETTINGS.QUICKSORT_MAX_STACK, needed_stack_len, data_len });
                    }

                    pub fn QuicksortPartition(comptime DEGENERATE_FALLBACK: bool) type {
                        return struct {
                            lo_idx: COUNT,
                            hi_idx: COUNT,
                            budget: if (DEGENERATE_FALLBACK) COUNT else void = if (DEGENERATE_FALLBACK) undefined else void{},

                            pub fn new(lo: COUNT, hi: COUNT, budget: COUNT) @This() {
                                var this = @This(){
                                    .lo_idx = lo,
                                    .hi_idx = hi,
                                };
                                if (DEGENERATE_FALLBACK) {
                                    this.budget = budget;
                                }
                                return this;
                            }

                            pub fn empty(self: @This(), data: DATA, userdata: USERDATA) bool {
                                return !id_less_than_or_equal(data, self.lo_idx, self.hi_idx, userdata);
                            }

                            pub fn len(self: @This(), data: DATA, userdata: USERDATA) COUNT {
                                return range_len(data, self.lo_idx, self.hi_idx, userdata);
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
                        assert_valid_range(in.data, in.first, in.last, in.userdata, @src());
                        if (in.first == in.last) return in.data;
                        assert_stack_can_support_sort_len(SETTINGS, in, @src());
                        const Partition = QuicksortPartition(SETTINGS.FALLBACK_WHEN_DEGENERATE);
                        const len = range_len(in.data, in.first, in.last, in.userdata);
                        const degenerate_limit: COUNT = if (comptime SETTINGS.FALLBACK_WHEN_DEGENERATE) (SETTINGS.DEGENERATE_DETECTION_FACTOR * @as(COUNT, @intCast(math.log2_int(COUNT, len)))) else math.maxInt(COUNT);
                        assert_stack_can_support_sort_len(SETTINGS, in.first, in.last, @src());
                        var data = in.data;
                        var stack: [SETTINGS.QUICKSORT_MAX_STACK]Partition = undefined;
                        stack[0] = Partition.new(in.first, in.last, degenerate_limit);
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
                            const sub_slice = in.sub_slice(data, parent_partition.lo_idx, parent_partition.hi_idx);
                            if (parent_partition.len() <= SETTINGS.QUICKSORT_TO_INSERTION_THRESHOLD) {
                                data = insertion_sort(sub_slice);
                                continue :next_partition;
                            }
                            data, const pivot = switch (SETTINGS.SAME_ORDER_EXPECTATIONS) {
                                .MANY_ITEMS_WITH_SAME_ORDER_LIKELY, .USE_DUTCH_FLAG_3_WAY_PARTITION => quicksort_partition_dutch_flag(sub_slice),
                                .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE, .USE_HOARE_2_WAY_PARTITION => quicksort_partition_hoare(sub_slice),
                            };
                            const left_partition = Partition.new(parent_partition.lo_idx, pivot.sub_partition_left_hi, parent_partition.budget - 1);
                            const right_partition = Partition.new(pivot.sub_partition_right_lo, parent_partition.hi_idx, parent_partition.budget - 1);
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

                    fn quicksort_partition_median_of_3(in: SortInputs) IdElemPair {
                        const len = range_len(in.data, in.first, in.last, in.userdata);
                        const mid = nth_next_id(in.data, in.first, (len >> 1), in.userdata);
                        const unsorted_ids = [3]COUNT{ in.first, mid, in.last };
                        return median_of_3(in.data, unsorted_ids, in.userdata);
                    }

                    fn quicksort_partition_hoare(in: SortInputs) struct { DATA, PartitionResult } {
                        const median_idx, const pivot_item = quicksort_partition_median_of_3(in);
                        var data = swap_already_have_b(in.data, in.first, median_idx, pivot_item, in.userdata);
                        var left_id = in.first;
                        var right_id = in.last;
                        var left_item: ELEM = undefined;
                        var right_item: ELEM = undefined;
                        while (true) {
                            left_item = get(data, left_id, in.userdata);
                            while (less_than(left_item, pivot_item, in.userdata)) {
                                left_id = next_id(data, left_id, in.userdata);
                                left_item = get(data, left_id, in.userdata);
                            }
                            right_item = get(data, right_id, in.userdata);
                            while (greater_than(right_item, pivot_item, in.userdata)) {
                                right_id = prev_id(data, right_id, in.userdata);
                                right_item = get(data, right_id, in.userdata);
                            }
                            if (id_greater_than_or_equal(data, left_id, right_id, in.userdata)) break;
                            data = set(data, left_id, right_item, in.userdata);
                            data = set(data, right_id, left_item, in.userdata);
                            left_id = next_id(data, left_id, in.userdata);
                            right_id = prev_id(data, right_id, in.userdata);
                        }
                        return .{ data, PartitionResult{
                            .sub_partition_left_hi = right_id,
                            .sub_partition_right_lo = next_id(data, right_id, in.userdata),
                        } };
                    }

                    fn quicksort_partition_dutch_flag(in: SortInputs) struct { DATA, PartitionResult } {
                        const median_idx, const pivot_item = quicksort_partition_median_of_3(in);
                        var data = swap_already_have_b(in.data, in.first, median_idx, pivot_item, in.userdata);
                        var smallest_id_with_same_order_as_pivot = in.first;
                        var check_id = in.first;
                        var largest_id_with_same_order_as_pivot = in.last;
                        while (id_less_than(data, check_id, largest_id_with_same_order_as_pivot, in.userdata)) {
                            const check_item = get(data, check_id, in.userdata);
                            if (less_than(check_item, pivot_item, in.userdata)) {
                                data = swap_already_have_b(data, smallest_id_with_same_order_as_pivot, check_id, check_item, in.userdata);
                                smallest_id_with_same_order_as_pivot = next_id(data, smallest_id_with_same_order_as_pivot, in.userdata);
                                check_id = next_id(data, check_id, in.userdata);
                            } else if (less_than(pivot_item, check_item, in.userdata)) {
                                data = swap_already_have_b(data, largest_id_with_same_order_as_pivot, check_id, check_item, in.userdata);
                                largest_id_with_same_order_as_pivot = prev_id(data, largest_id_with_same_order_as_pivot, in.userdata);
                            } else {
                                check_id = next_id(data, check_id, in.userdata);
                            }
                        }
                        return .{ data, PartitionResult{
                            .sub_partition_left_hi = prev_id(data, smallest_id_with_same_order_as_pivot, in.userdata),
                            .sub_partition_right_lo = next_id(data, largest_id_with_same_order_as_pivot, in.userdata),
                        } };
                    }

                    pub fn max_heap_sift_down_with_range(data: DATA, heap_first: ID, id: ID, heap_last: ID, userdata: USERDATA) DATA {
                        return any_heap_sift_down_with_range(.MAX_HEAP, data, heap_first, id, heap_last, userdata);
                    }
                    fn any_heap_sift_down_with_range(comptime kind: HeapKind, data_: DATA, heap_first: ID, id: ID, heap_last: ID, userdata: USERDATA) DATA {
                        assert_valid_range_3(data_, heap_first, id, heap_last, userdata, @src());
                        const len = range_len(data_, heap_first, heap_last, userdata);
                        var data = data_;
                        var target_id = id;
                        var target_id_len_from_start = limit_len(data, heap_first, target_id, userdata);
                        const target_val = get(data, target_id, userdata);
                        const max_len_no_left_child_overflow = math.maxInt(COUNT) >> 1;
                        while (true) {
                            var extreme_val_id = target_id;
                            var extreme_val_len_from_start = target_id_len_from_start;
                            var extreme_val = target_val;
                            const left_child_len_from_start = (target_id_len_from_start << 1) | 1; // same as (target_id_len_from_start * 2) + 1
                            if (target_id_len_from_start <= max_len_no_left_child_overflow and left_child_len_from_start < len) {
                                const left_child_id = nth_next_id(data, heap_first, left_child_len_from_start, userdata);
                                const left_child_val = get(data, left_child_id, userdata);
                                switch (comptime kind) {
                                    .MAX_HEAP => {
                                        if (greater_than(left_child_val, target_val, userdata)) {
                                            extreme_val_id = left_child_id;
                                            extreme_val_len_from_start = left_child_len_from_start;
                                            extreme_val = left_child_val;
                                        }
                                    },
                                    .MIN_HEAP => {
                                        if (less_than(left_child_val, target_val, userdata)) {
                                            extreme_val_id = left_child_id;
                                            extreme_val_len_from_start = left_child_len_from_start;
                                            extreme_val = left_child_val;
                                        }
                                    },
                                }
                                const right_child_len_from_start = left_child_len_from_start +% 1;
                                if (target_id_len_from_start < max_len_no_left_child_overflow and right_child_len_from_start < len) {
                                    const right_child_id = next_id(data, left_child_id, userdata);
                                    const right_child_val = get(data, right_child_id, userdata);
                                    switch (comptime kind) {
                                        .MAX_HEAP => {
                                            if (greater_than(right_child_val, target_val, userdata)) {
                                                extreme_val_id = right_child_id;
                                                extreme_val_len_from_start = right_child_len_from_start;
                                                extreme_val = right_child_val;
                                            }
                                        },
                                        .MIN_HEAP => {
                                            if (less_than(right_child_val, target_val, userdata)) {
                                                extreme_val_id = right_child_id;
                                                extreme_val_len_from_start = right_child_len_from_start;
                                                extreme_val = right_child_val;
                                            }
                                        },
                                    }
                                }
                            }
                            if (id_equals(data, extreme_val_id, target_id, userdata)) break; // target val in correct place
                            // swap largest and target and update target id
                            data = set(data, extreme_val_id, target_val, userdata);
                            data = set(data, target_id, extreme_val, userdata);
                            target_id = extreme_val_id;
                            target_id_len_from_start = extreme_val_len_from_start;
                        }
                        return data;
                    }

                    fn build_any_heap_within_range(comptime kind: HeapKind, old_data: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        var data = old_data;
                        const len = range_len(data, first, last, userdata);
                        var non_leaf_len_from_start = (len >> 1);
                        while (non_leaf_len_from_start > 0) {
                            non_leaf_len_from_start -= 1;
                            const non_leaf_id = nth_id_from_start(data, non_leaf_len_from_start, userdata);
                            data = any_heap_sift_down_with_range(kind, data, first, non_leaf_id, last, userdata);
                        }
                        return data;
                    }

                    /// Uses Floyd's algorithm to turn a range of data into a max heap in-place
                    pub fn build_max_heap_within_range(data: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        return build_any_heap_within_range(.MAX_HEAP, data, first, last, userdata);
                    }
                    /// Uses Floyd's algorithm to turn the data into a max heap in-place
                    pub fn build_max_heap(data: DATA, userdata: USERDATA) DATA {
                        return build_max_heap_within_range(data, first_id(data, userdata), last_id(data, userdata), userdata);
                    }
                    /// Uses Floyd's algorithm to turn a range of data into a min heap in-place
                    pub fn build_min_heap_within_range(data: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        return build_any_heap_within_range(.MIN_HEAP, data, first, last, userdata);
                    }
                    /// Uses Floyd's algorithm to turn the data into a min heap in-place
                    pub fn build_min_heap(data: DATA, userdata: USERDATA) DATA {
                        return build_min_heap_within_range(data, first_id(data, userdata), last_id(data, userdata), userdata);
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
                    pub fn heapsort(data_: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        assert_valid_range(data_, first, last, userdata, @src());
                        var data = build_max_heap_within_range(data_, first, last, userdata);
                        var heap_end = last;
                        while (!id_equals(data, heap_end, first, userdata)) {
                            data = swap(data, heap_end, first, userdata);
                            heap_end = prev_id(data, heap_end, userdata);
                            data = max_heap_sift_down_with_range(data, first, first, heap_end, userdata);
                        }
                        return data;
                    }

                    const PartitionResult = struct {
                        sub_partition_left_hi: COUNT,
                        sub_partition_right_lo: COUNT,
                    };
                };
            }
        };
    }
};

test "Utils_DataManipulation => median_of_3_index" {
    const STATIC_IDS = [3]usize{ 0, 1, 2 };
    const Case = struct {
        input: [3]u8,
        med_idxs: []const usize,

        pub fn new(vals: [3]u8, med_idxs: []const usize) @This() {
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
    const DMP = native_data_structure_manipulation_package([]const u8, u8);
    next_case: for (cases) |case| {
        const med_idx, const med_val = DMP.median_of_3(case.input[0..], STATIC_IDS, {});
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
