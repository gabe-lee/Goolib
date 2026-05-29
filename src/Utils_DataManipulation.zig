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
const Io = std.Io;
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

pub const Defaults = @import("./Utils_DataManipulation_Defaults.zig");
pub const Recipes = @import("./Utils_DataManipulation_Recipes.zig");

comptime {
    if (build.is_test) {
        _ = @import("./Utils_DataManipulation_Defaults.zig");
        _ = @import("./Utils_DataManipulation_Recipes.zig");
    }
}

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;
// const CompareFnUserdata = Utils.Compare.CompareFnUserdata;
// const CompareFn = Utils.Compare.CompareFn;

pub const SearchOrder = enum {
    SEARCH_PARAMS_IN_SAME_ORDER_AS_THEIR_ORDER_IN_DATA_BUFFER,
    SEARCH_PARAMS_UNORDERED,
};

const DEBUG = std.debug.print;

pub const USERDATA_ALLOC_FIELD_NAME = "alloc";
pub const USERDATA_ALLOC_SETTINGS_FIELD_NAME = "alloc_settings";
pub const USERDATA_ALLOC_COMPTIME_SETTINGS_FIELD_NAME = "comptime_alloc_settings";
pub const USERDATA_IO_FIELD_NAME = "io";

fn get_alloc_from_userdata(userdata: anytype) Allocator {
    const USERDATA = @TypeOf(userdata);
    const INFO = KindInfo.get_kind_info(USERDATA);
    if (comptime INFO.is_struct()) {
        if (comptime @hasField(USERDATA, USERDATA_ALLOC_FIELD_NAME)) {
            if (comptime @FieldType(USERDATA, USERDATA_ALLOC_FIELD_NAME) == Allocator) {
                return @field(userdata, USERDATA_ALLOC_FIELD_NAME);
            }
        }
    }
    return Root.DummyAllocator.allocator_panic_free_noop;
}

fn get_alloc_settings_from_userdata(userdata: anytype, comptime ELEM: type) Utils.Alloc.SmartAllocSettings(ELEM) {
    const USERDATA = @TypeOf(userdata);
    const INFO = KindInfo.get_kind_info(USERDATA);
    if (comptime INFO.is_struct()) {
        if (comptime @hasField(USERDATA, USERDATA_ALLOC_SETTINGS_FIELD_NAME)) {
            if (comptime @FieldType(USERDATA, USERDATA_ALLOC_SETTINGS_FIELD_NAME) == Utils.Alloc.SmartAllocSettings(ELEM)) {
                return @field(userdata, USERDATA_ALLOC_SETTINGS_FIELD_NAME);
            }
        }
    }
    return Utils.Alloc.SmartAllocSettings(ELEM){};
}

fn get_alloc_comptime_settings_from_userdata(userdata: anytype, comptime ELEM: type) Utils.Alloc.SmartAllocComptimeSettings(ELEM) {
    const USERDATA = @TypeOf(userdata);
    const INFO = KindInfo.get_kind_info(USERDATA);
    if (comptime INFO.is_struct()) {
        if (comptime @hasField(USERDATA, USERDATA_ALLOC_COMPTIME_SETTINGS_FIELD_NAME)) {
            if (comptime @FieldType(USERDATA, USERDATA_ALLOC_COMPTIME_SETTINGS_FIELD_NAME) == Utils.Alloc.SmartAllocComptimeSettings(ELEM)) {
                return @field(userdata, USERDATA_ALLOC_COMPTIME_SETTINGS_FIELD_NAME);
            }
        }
    }
    return Utils.Alloc.SmartAllocComptimeSettings(ELEM){};
}

fn get_io_from_userdata(userdata: anytype) Io {
    const USERDATA = @TypeOf(userdata);
    const INFO = KindInfo.get_kind_info(USERDATA);
    if (comptime INFO.is_struct()) {
        if (comptime @hasField(USERDATA, USERDATA_IO_FIELD_NAME)) {
            if (comptime @FieldType(USERDATA, USERDATA_IO_FIELD_NAME) == Io) {
                return @field(userdata, USERDATA_IO_FIELD_NAME);
            }
        }
    }
    return Root.DummyIo.io_undefined;
}

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

pub const QuicksortSettings = struct {
    /// `33` (32 + 1) = max input len of 2^32 items,
    /// if you really need more than this you can increase it, each
    /// additional 1 added doubles the max input len (`34` (33 + 1) = 2^33 max)
    QUICKSORT_MAX_STACK: u8 = 33,
    /// Signals to use a different partitioning scheme depending on whether you
    /// expect the data to have many items with equal order,
    /// or whether it is rare or impossible to occur
    SAME_ORDER_EXPECTATIONS: ManySameOrderExpectation = .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY,
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
    /// When using partition mode `.DYNAMIC_BASED_ON_SAME_ORDER_DENSITY`, this is
    /// a percent threshold equal to `num_items_same_order_as_pivot / length_of_partition`,
    /// above which a counter of `partitions_ith_many_dupes` is incremented.
    ///
    /// When that counter exceeds a threshold, the partition mode permanently swaps
    /// to the 3-way scheme
    DYNAMIC_PARTITION_SWAP_TO_3_WAY_THRESHOLD: f32 = 0.33,
    /// When using partition mode `.DYNAMIC_BASED_ON_SAME_ORDER_DENSITY`, this is
    /// the number of times a partion with a high number of items with
    /// an equal order to the pivot are allowed before the partition mode
    /// permanently swaps to the 3-way scheme
    DYNAMIC_PARTITION_SWAP_TO_3_WAY_MAX_COUNT: comptime_int = 3,
};

pub const ManySameOrderExpectation = enum(u8) {
    /// Starts with normal 2-way partition mode, but if
    /// many items with the same order are detected
    /// it swaps to the 3-way partition mode
    DYNAMIC_BASED_ON_SAME_ORDER_DENSITY,
    /// Same as `.USE_DUTCH_FLAG_3_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_LIKELY,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_LIKELY`
    USE_DUTCH_FLAG_3_WAY_PARTITION,
    /// Same as `.USE_HOARE_2_WAY_PARTITION`
    MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE,
    /// Same as `.MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE`
    USE_HOARE_2_WAY_PARTITION,
};

pub const InferedFuncMode = enum(u8) {
    ALLOW_INFERED_IMPLEMENTATIONS,
    NO_INFERED_IMPLEMENTATIONS,
};

pub const DataManipulationCore = struct {
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

    pub fn define(comptime CORE: DataManipulationCore, comptime DEFAULT_MODE: InferedFuncMode, comptime CUSTOM: CORE.CustomFunctions()) type {
        return CORE.select_functions(DEFAULT_MODE, CUSTOM).finalize();
    }

    pub fn select_functions(comptime CORE: DataManipulationCore, comptime COMPTIME_BACKWARD_BRANCHES: u32, comptime DEFAULT_MODE: InferedFuncMode, comptime CUSTOM: CORE.CustomFunctions(), comptime PROPERTIES: Recipes.OptionalExtraProperties) CORE.Builder() {
        comptime {
            @setEvalBranchQuota(COMPTIME_BACKWARD_BRANCHES);
            const ALLOW_DEFAULT = DEFAULT_MODE == .ALLOW_INFERED_IMPLEMENTATIONS;
            const FUNC_SELECTOR = CORE.Builder().FUNC_SELECTOR;
            const CORE_AND_FUNCS = CORE.Builder();
            // BUILD FLAGS FOR PROVIDED CUSTOM FUNCTIONS
            // SELECT THE CORRECT FUNCTION FOR EACH GIVEN THE CUSTOM/FLAGS/ALLOW_DEFAULT
            const SELECT = FUNC_SELECTOR(CUSTOM, PROPERTIES, ALLOW_DEFAULT);
            const FINAL_FUNCS: CORE_AND_FUNCS = CORE_AND_FUNCS{
                .GET_LEN = SELECT.GET_LEN.func,
                .SET_LEN = SELECT.SET_LEN.func,
                .GET_CAP = SELECT.GET_CAP.func,
                .SET_CAP = SELECT.SET_CAP.func,
                .GET_BASE_PTR = SELECT.GET_BASE_PTR.func,
                .GET_BASE_CONST_PTR = SELECT.GET_BASE_CONST_PTR.func,
                .SET_BASE_PTR = SELECT.SET_BASE_PTR.func,
                .GET_RANGE_SLICE = SELECT.GET_RANGE_SLICE.func,
                .GET_RANGE_CONST_SLICE = SELECT.GET_RANGE_CONST_SLICE.func,
                //
                .ID_EQUALS = SELECT.ID_EQUALS.func,
                .ID_LESS_THAN = SELECT.ID_LESS_THAN.func,
                .ID_LESS_THAN_OR_EQUAL = SELECT.ID_LESS_THAN_OR_EQUAL.func,
                .ID_GREATER_THAN = SELECT.ID_GREATER_THAN.func,
                .ID_GREATER_THAN_OR_EQUAL = SELECT.ID_GREATER_THAN_OR_EQUAL.func,
                .ID_VALID = SELECT.ID_VALID.func,
                //
                .INVALID_ID_AFTER_LAST_ID = SELECT.INVALID_ID_AFTER.func,
                .INVALID_ID_BEFORE_FIRST_ID = SELECT.INVALID_ID_BEFORE.func,
                .FIRST_ID = SELECT.FIRST_ID.func,
                .LAST_ID = SELECT.LAST_ID.func,
                .NTH_ID_FROM_START = SELECT.NTH_FROM_START.func,
                .NTH_ID_FROM_END = SELECT.NTH_FROM_END.func,
                .PREV_ID = SELECT.PREV_ID.func,
                .NEXT_ID = SELECT.NEXT_ID.func,
                .NTH_PREV_ID = SELECT.NTH_PREV_ID.func,
                .NTH_NEXT_ID = SELECT.NTH_NEXT_ID.func,
                .FIRST_CHILD_ID = SELECT.FIRST_CHILD_ID.func,
                .LAST_CHILD_ID = SELECT.LAST_CHILD_ID.func,
                .NTH_CHILD_ID = SELECT.NTH_CHILD_ID.func,
                .PARENT_ID = SELECT.PARENT_ID.func,
                //
                .RANGE_LEN = SELECT.RANGE_LEN.func,
                .LIMIT_LEN = SELECT.LIMIT_LEN.func,
                //
                .GET = SELECT.GET.func,
                .GET_PTR = SELECT.GET_PTR.func,
                .GET_CONST_PTR = SELECT.GET_CONST_PTR.func,
                .SET = SELECT.SET.func,
                //
                .GREATER_THAN = SELECT.GREATER_THAN.func,
                .GREATER_THAN_OR_EQUAL = SELECT.GREATER_THAN_OR_EQUAL.func,
                .LESS_THAN = SELECT.LESS_THAN.func,
                .LESS_THAN_OR_EQUAL = SELECT.LESS_THAN_OR_EQUAL.func,
                .ORDER_EQUALS = SELECT.ORDER_EQUAL.func,
                .EXACT_EQUALS = SELECT.EXACT_EQUAL.func,
                //
                .SWAP = SELECT.SWAP.func,
                .REVERSE_RANGE = SELECT.REVERSE_RANGE.func,
                .ROTATE_RIGHT = SELECT.ROTATE_RIGHT.func,
                .ROTATE_LEFT = SELECT.ROTATE_LEFT.func,
                .MOVE_ONE_OVERWRITE = SELECT.MOVE_ONE_OVERWRITE.func,
                .MOVE_ONE_RIGHT_DISPLACE = SELECT.MOVE_ONE_RIGHT_DISPLACE.func,
                .MOVE_ONE_LEFT_DISPLACE = SELECT.MOVE_ONE_LEFT_DISPLACE.func,
                .MOVE_RANGE_LEFT_DISPLACE = SELECT.MOVE_RANGE_LEFT_DISPLACE.func,
                .MOVE_RANGE_RIGHT_DISPLACE = SELECT.MOVE_RANGE_RIGHT_DISPLACE.func,
                .MOVE_RANGE_LEFT_OVERWRITE = SELECT.MOVE_RANGE_LEFT_OVERWRITE.func,
                .MOVE_RANGE_RIGHT_OVERWRITE = SELECT.MOVE_RANGE_RIGHT_OVERWRITE.func,
                .SCRAMBLE = SELECT.SCRAMBLE.func,
                //
                .ENSURE_FREE_SPACE = SELECT.ENSURE_FREE_SPACE.func,
                .TRIM_FREE_SPACE = SELECT.TRIM_FREE_SPACE.func,
                .APPEND_ONE_SLOT_ASSUME_CAP = SELECT.APPEND_ONE_SLOT_ASSUME_CAP.func,
                .APPEND_MANY_SLOTS_ASSUME_CAP = SELECT.APPEND_MANY_SLOTS_ASSUME_CAP.func,
                .INSERT_ONE_SLOT_BEFORE_ASSUME_CAP = SELECT.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP.func,
                .INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP = SELECT.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP.func,
                .PREPEND_ONE_SLOT_ASSUME_CAP = SELECT.PREPEND_ONE_SLOT_ASSUME_CAP.func,
                .PREPEND_MANY_SLOTS_ASSUME_CAP = SELECT.PREPEND_MANY_SLOTS_ASSUME_CAP.func,
                .DELETE_ONE = SELECT.DELETE_ONE.func,
                .DELETE_RANGE = SELECT.DELETE_RANGE.func,
            };
            return FINAL_FUNCS;
        }
    }

    pub fn CustomFunctions(comptime CORE: DataManipulationCore) type {
        return CORE.Builder().CustomFunctions_;
    }

    pub fn Builder(comptime CORE_: DataManipulationCore) type {
        return struct {
            const CORE_AND_FUNCS = @This();
            pub const DATA_ = CORE_.DATA;
            pub const ELEM_ = CORE_.ELEM;
            pub const COUNT_ = CORE_.COUNT_INT;
            pub const ID_ = CORE_.ID;
            pub const USERDATA_ = CORE_.USERDATA;

            // FUNCS
            ID_LESS_THAN: FN_ID_COMPARE,
            ID_LESS_THAN_OR_EQUAL: FN_ID_COMPARE,
            ID_GREATER_THAN: FN_ID_COMPARE,
            ID_GREATER_THAN_OR_EQUAL: FN_ID_COMPARE,
            ID_EQUALS: FN_ID_COMPARE,
            ID_VALID: FN_ID_CHECK,
            //
            INVALID_ID_AFTER_LAST_ID: FN_IMPLICIT_ID,
            INVALID_ID_BEFORE_FIRST_ID: FN_IMPLICIT_ID,
            FIRST_ID: FN_IMPLICIT_ID,
            LAST_ID: FN_IMPLICIT_ID,
            NTH_ID_FROM_START: FN_IMPLICIT_NTH_ID,
            NTH_ID_FROM_END: FN_IMPLICIT_NTH_ID,
            PREV_ID: FN_ADJACENT_ID,
            NEXT_ID: FN_ADJACENT_ID,
            NTH_PREV_ID: FN_NTH_ID,
            NTH_NEXT_ID: FN_NTH_ID,
            FIRST_CHILD_ID: FN_CHILD_ID_WITH_COUNT,
            LAST_CHILD_ID: FN_CHILD_ID_WITH_COUNT,
            NTH_CHILD_ID: FN_NTH_CHILD_ID_WITH_COUNT,
            PARENT_ID: FN_CHILD_ID_WITH_COUNT,
            //
            GET_LEN: FN_IMPLICIT_COUNT,
            SET_LEN: FN_SET_COUNT,
            GET_CAP: FN_IMPLICIT_COUNT,
            SET_CAP: FN_SET_COUNT,
            GET_BASE_PTR: FN_GET_BASE_PTR,
            GET_BASE_CONST_PTR: FN_GET_BASE_CONST_PTR,
            SET_BASE_PTR: FN_SET_BASE_PTR,
            GET_RANGE_SLICE: FN_GET_SLICE,
            GET_RANGE_CONST_SLICE: FN_GET_CONST_SLICE,
            //
            RANGE_LEN: FN_RANGE_COUNT,
            LIMIT_LEN: FN_RANGE_COUNT,
            //
            GET: FN_GET,
            GET_PTR: FN_GET_PTR,
            GET_CONST_PTR: FN_GET_CONST_PTR,
            SET: FN_SET,
            //
            GREATER_THAN: FN_ELEM_COMPARE,
            GREATER_THAN_OR_EQUAL: FN_ELEM_COMPARE,
            LESS_THAN: FN_ELEM_COMPARE,
            LESS_THAN_OR_EQUAL: FN_ELEM_COMPARE,
            ORDER_EQUALS: FN_ELEM_COMPARE,
            EXACT_EQUALS: FN_ELEM_COMPARE,
            //
            SWAP: FN_SWAP,
            REVERSE_RANGE: FN_RANGE_OP,
            MOVE_ONE_OVERWRITE: FN_RANGE_OP,
            MOVE_ONE_RIGHT_DISPLACE: FN_RANGE_OP,
            MOVE_ONE_LEFT_DISPLACE: FN_RANGE_OP,
            MOVE_RANGE_RIGHT_DISPLACE: FN_MOVE_RANGE_DISPLACE,
            MOVE_RANGE_LEFT_DISPLACE: FN_MOVE_RANGE_DISPLACE,
            MOVE_RANGE_RIGHT_OVERWRITE: FN_MOVE_RANGE_OVERWRITE,
            MOVE_RANGE_LEFT_OVERWRITE: FN_MOVE_RANGE_OVERWRITE,
            ROTATE_RIGHT: FN_ROTATE,
            ROTATE_LEFT: FN_ROTATE,
            SCRAMBLE: FN_SCRAMBLE,
            //
            APPEND_ONE_SLOT_ASSUME_CAP: FN_APPEND_ONE_SLOT,
            APPEND_MANY_SLOTS_ASSUME_CAP: FN_APPEND_N_SLOTS,
            INSERT_ONE_SLOT_BEFORE_ASSUME_CAP: FN_INSERT_ONE_SLOT,
            INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP: FN_INSERT_N_SLOTS,
            PREPEND_ONE_SLOT_ASSUME_CAP: FN_APPEND_ONE_SLOT,
            PREPEND_MANY_SLOTS_ASSUME_CAP: FN_APPEND_N_SLOTS,
            DELETE_ONE: FN_DELETE_ONE,
            DELETE_RANGE: FN_DELETE_RANGE,
            ENSURE_FREE_SPACE: FN_SET_COUNT,
            TRIM_FREE_SPACE: FN_SET_COUNT,

            pub const AllocSettings = Utils.Alloc.SmartAllocSettings(ELEM_);
            pub const ComptimeAllocSettings = Utils.Alloc.SmartAllocComptimeSettings(ELEM_);

            pub const FN_ID_COMPARE = fn (DATA_, ID_, ID_, USERDATA_) bool;
            pub const FN_ID_CHECK = fn (DATA_, ID_, USERDATA_) bool;
            pub const FN_ELEM_COMPARE = fn (ELEM_, ELEM_, USERDATA_) bool;
            pub const FN_IMPLICIT_ID = fn (DATA_, USERDATA_) ID_;
            pub const FN_IMPLICIT_NTH_ID = fn (DATA_, COUNT_, USERDATA_) ID_;
            pub const FN_NTH_ID = fn (DATA_, ID_, COUNT_, USERDATA_) ID_;
            pub const FN_ADJACENT_ID = fn (DATA_, ID_, USERDATA_) ID_;
            pub const FN_CHILD_ID_WITH_COUNT = fn (DATA_, ID_, COUNT_, USERDATA_) ID_;
            pub const FN_NTH_CHILD_ID_WITH_COUNT = fn (DATA_, ID_, COUNT_, COUNT_, USERDATA_) ID_;
            pub const FN_IMPLICIT_COUNT = fn (DATA_, USERDATA_) COUNT_;
            pub const FN_SET_COUNT = fn (DATA_, COUNT_, USERDATA_) DATA_;
            pub const FN_RANGE_COUNT = fn (DATA_, ID_, ID_, USERDATA_) COUNT_;
            pub const FN_GET = fn (DATA_, ID_, USERDATA_) ELEM_;
            pub const FN_GET_PTR = fn (DATA_, ID_, USERDATA_) *ELEM_;
            pub const FN_GET_CONST_PTR = fn (DATA_, ID_, USERDATA_) *const ELEM_;
            pub const FN_GET_SLICE = fn (DATA_, ID_, ID_, USERDATA_) []ELEM_;
            pub const FN_GET_CONST_SLICE = fn (DATA_, ID_, ID_, USERDATA_) []const ELEM_;
            pub const FN_SET = fn (DATA_, ID_, ELEM_, USERDATA_) DATA_;
            pub const FN_SWAP = fn (DATA_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_RANGE_OP = fn (DATA_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_MOVE_RANGE_DISPLACE = fn (DATA_, ID_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_MOVE_RANGE_OVERWRITE = fn (DATA_, ID_, ID_, COUNT_, USERDATA_) DATA_;
            pub const FN_ROTATE = fn (DATA_, ID_, ID_, COUNT_, USERDATA_) DATA_;
            pub const FN_SCRAMBLE = fn (DATA_, Random, ID_, ID_, COUNT_, USERDATA_) DATA_;
            pub const FN_APPEND_ONE_SLOT = fn (DATA_, USERDATA_) struct { DATA_, ID_ };
            pub const FN_APPEND_N_SLOTS = fn (DATA_, COUNT_, USERDATA_) struct { DATA_, ID_, ID_ };
            pub const FN_INSERT_ONE_SLOT = fn (DATA_, ID_, USERDATA_) struct { DATA_, ID_ };
            pub const FN_INSERT_N_SLOTS = fn (DATA_, ID_, COUNT_, USERDATA_) struct { DATA_, ID_, ID_ };
            pub const FN_DELETE_ONE = fn (DATA_, ID_, USERDATA_) DATA_;
            pub const FN_DELETE_RANGE = fn (DATA_, ID_, ID_, USERDATA_) DATA_;
            pub const FN_GET_BASE_PTR = fn (DATA_, USERDATA_) [*]ELEM_;
            pub const FN_GET_BASE_CONST_PTR = fn (DATA_, USERDATA_) [*]const ELEM_;
            pub const FN_SET_BASE_PTR = fn (DATA_, [*]ELEM_, USERDATA_) DATA_;

            pub const CustomFunctions_ = struct {
                GET_LEN: ?FN_IMPLICIT_COUNT = null,
                SET_LEN: ?FN_SET_COUNT = null,
                GET_CAP: ?FN_IMPLICIT_COUNT = null,
                SET_CAP: ?FN_SET_COUNT = null,
                GET_BASE_PTR: ?FN_GET_BASE_PTR = null,
                GET_BASE_CONST_PTR: ?FN_GET_BASE_CONST_PTR = null,
                SET_BASE_PTR: ?FN_SET_BASE_PTR = null,
                GET_RANGE_SLICE: ?FN_GET_SLICE = null,
                GET_RANGE_CONST_SLICE: ?FN_GET_CONST_SLICE = null,
                //
                ID_LESS_THAN: ?FN_ID_COMPARE = null,
                ID_LESS_THAN_OR_EQUAL: ?FN_ID_COMPARE = null,
                ID_GREATER_THAN: ?FN_ID_COMPARE = null,
                ID_GREATER_THAN_OR_EQUAL: ?FN_ID_COMPARE = null,
                ID_EQUALS: ?FN_ID_COMPARE = null,
                ID_VALID: ?FN_ID_CHECK = null,
                INVALID_ID_AFTER_LAST_ID: ?FN_IMPLICIT_ID = null,
                INVALID_ID_BEFORE_FIRST_ID: ?FN_IMPLICIT_ID = null,
                //
                GET: ?FN_GET = null,
                GET_PTR: ?FN_GET_PTR = null,
                GET_CONST_PTR: ?FN_GET_CONST_PTR = null,
                SET: ?FN_SET = null,
                //
                LESS_THAN: ?FN_ELEM_COMPARE = null,
                LESS_THAN_OR_EQUAL: ?FN_ELEM_COMPARE = null,
                GREATER_THAN: ?FN_ELEM_COMPARE = null,
                GREATER_THAN_OR_EQUAL: ?FN_ELEM_COMPARE = null,
                ORDER_EQUALS: ?FN_ELEM_COMPARE = null,
                EXACT_EQUALS: ?FN_ELEM_COMPARE = null,
                //
                FIRST_ID: ?FN_IMPLICIT_ID = null,
                LAST_ID: ?FN_IMPLICIT_ID = null,
                NTH_ID_FROM_START: ?FN_IMPLICIT_NTH_ID = null,
                NTH_ID_FROM_END: ?FN_IMPLICIT_NTH_ID = null,
                NEXT_ID: ?FN_ADJACENT_ID = null,
                PREV_ID: ?FN_ADJACENT_ID = null,
                NTH_PREV_ID: ?FN_NTH_ID = null,
                NTH_NEXT_ID: ?FN_NTH_ID = null,
                FIRST_CHILD_ID: ?FN_CHILD_ID_WITH_COUNT = null,
                LAST_CHILD_ID: ?FN_CHILD_ID_WITH_COUNT = null,
                NTH_CHILD_ID: ?FN_NTH_CHILD_ID_WITH_COUNT = null,
                PARENT_ID: ?FN_CHILD_ID_WITH_COUNT = null,
                //
                RANGE_LEN: ?FN_RANGE_COUNT = null,
                LIMIT_LEN: ?FN_RANGE_COUNT = null,
                //
                SWAP: ?FN_SWAP = null,
                REVERSE_RANGE: ?FN_RANGE_OP = null,
                MOVE_ONE_RIGHT_DISPLACE: ?FN_RANGE_OP = null,
                MOVE_ONE_LEFT_DISPLACE: ?FN_RANGE_OP = null,
                MOVE_ONE_OVERWRITE: ?FN_RANGE_OP = null,
                MOVE_RANGE_RIGHT_DISPLACE: ?FN_MOVE_RANGE_DISPLACE = null,
                MOVE_RANGE_LEFT_DISPLACE: ?FN_MOVE_RANGE_DISPLACE = null,
                MOVE_RANGE_RIGHT_OVERWRITE: ?FN_MOVE_RANGE_OVERWRITE = null,
                MOVE_RANGE_LEFT_OVERWRITE: ?FN_MOVE_RANGE_OVERWRITE = null,
                ROTATE_RANGE_RIGHT: ?FN_ROTATE = null,
                ROTATE_RANGE_LEFT: ?FN_ROTATE = null,
                SCRAMBLE: ?FN_SCRAMBLE = null,
                //
                APPEND_ONE_SLOT_ASSUME_CAP: ?FN_APPEND_ONE_SLOT = null,
                APPEND_MANY_SLOTS_ASSUME_CAP: ?FN_APPEND_N_SLOTS = null,
                INSERT_ONE_SLOT_BEFORE_ASSUME_CAP: ?FN_INSERT_ONE_SLOT = null,
                INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP: ?FN_INSERT_N_SLOTS = null,
                PREPEND_ONE_SLOT_ASSUME_CAP: ?FN_APPEND_ONE_SLOT = null,
                PREPEND_MANY_SLOTS_ASSUME_CAP: ?FN_APPEND_N_SLOTS = null,
                DELETE_ONE: ?FN_DELETE_ONE = null,
                DELETE_RANGE: ?FN_DELETE_RANGE = null,
                ENSURE_FREE_SPACE: ?FN_SET_COUNT = null,
                TRIM_FREE_SPACE: ?FN_SET_COUNT = null,
            };

            pub fn FUNC_SELECTOR(comptime CUSTOM: CustomFunctions_, comptime PROPERTIES: Recipes.OptionalExtraProperties, comptime ALLOW_INFERED: bool) type {
                var provided_func_flags: [Recipes.PackageFlags.NUM_FLAGS]Recipes.FuncFlag = undefined;
                var num_provided_func_flags: usize = 0;
                next_custom: inline for (@typeInfo(CustomFunctions_).@"struct".fields) |c_field| {
                    if (@field(CUSTOM, c_field.name) != null) {
                        inline for (@typeInfo(Recipes.PackageFlags).@"enum".fields) |e_field| {
                            if (std.mem.eql(u8, c_field.name, e_field.name)) {
                                const enum_tag: Recipes.PackageFlags = @enumFromInt(e_field.value);
                                provided_func_flags[num_provided_func_flags] = Recipes.FuncFlag.user_provided(enum_tag);
                                num_provided_func_flags += 1;
                                continue :next_custom;
                            }
                        }
                        assert_unreachable(@src(), "custom functions struct has field `{s}` that does not match any enum field on Recipes.PackageFlags", .{c_field.name});
                    }
                }
                PROPERTIES.add_to_func_flags(&provided_func_flags, &num_provided_func_flags);
                const SOLUTIONS = comptime Recipes.InferEngine.resolve_recipes_by_weight(100, .ALWAYS_USE_USER_PROVIDED, provided_func_flags[0..num_provided_func_flags], Recipes.RECIPES);
                const SELECTOR = struct {
                    inline fn nth_child_of_n_ary_flat_array_tree(id_n: COUNT_, num_children_per_element: COUNT_, child_n: COUNT_) COUNT_ {
                        return (id_n * num_children_per_element) + child_n;
                    }
                    inline fn parent_of_n_ary_flat_array_tree(child_n: COUNT_, num_children_per_element: COUNT_) COUNT_ {
                        return @divFloor(child_n - 1, num_children_per_element);
                    }
                    const GET_BASE_PTR = struct {
                        const func: FN_GET_BASE_PTR = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_BASE_PTR)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_BASE_PTR.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_ptr => infer_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_ptr(data: DATA_, userdata: USERDATA_) [*]ELEM_ {
                            const ptr = GET_PTR.func(data, FIRST_ID.func(data, userdata), userdata);
                            return @ptrCast(ptr);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) [*]ELEM_ {
                            assert_unreachable(@src(), "no `get_base_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_BASE_CONST_PTR = struct {
                        const func: FN_GET_BASE_CONST_PTR = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_BASE_CONST_PTR)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_BASE_CONST_PTR.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_base_ptr => infer_base_ptr,
                                .infer_const_ptr => infer_const_ptr,
                                .infer_ptr => infer_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_ptr(data: DATA_, userdata: USERDATA_) [*]const ELEM_ {
                            return GET_BASE_PTR.func(data, userdata);
                        }
                        fn infer_ptr(data: DATA_, userdata: USERDATA_) [*]const ELEM_ {
                            const ptr = GET_PTR.func(data, FIRST_ID.func(data, userdata), userdata);
                            return @ptrCast(ptr);
                        }
                        fn infer_const_ptr(data: DATA_, userdata: USERDATA_) [*]const ELEM_ {
                            const ptr = GET_CONST_PTR.func(data, FIRST_ID.func(data, userdata), userdata);
                            return @ptrCast(ptr);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) [*]const ELEM_ {
                            assert_unreachable(@src(), "no `get_base_const_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET_BASE_PTR = struct {
                        const func: FN_SET_BASE_PTR = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SET_BASE_PTR)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SET_BASE_PTR.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                else => unreachable,
                            },
                        };
                        fn unusable(_: DATA_, _: [*]ELEM_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `set_base_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_RANGE_SLICE = struct {
                        const func: FN_GET_SLICE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_RANGE_SLICE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_RANGE_SLICE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_base_ptr => infer_base_ptr,
                                .infer_ptr => infer_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_ptr(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) []ELEM_ {
                            const base = GET_BASE_PTR.func(data, userdata);
                            return base[first .. last + 1];
                        }
                        fn infer_ptr(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) []ELEM_ {
                            const ptr: [*]ELEM_ = @ptrCast(GET_PTR.func(data, first, userdata));
                            return ptr[0 .. (last + 1) - first];
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) []ELEM_ {
                            assert_unreachable(@src(), "no `get_range_slice` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_RANGE_CONST_SLICE = struct {
                        const func: FN_GET_CONST_SLICE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_RANGE_CONST_SLICE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_RANGE_CONST_SLICE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_range => infer_range,
                                .infer_base_const_ptr => infer_base_const_ptr,
                                .infer_const_ptr => infer_const_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_range(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) []const ELEM_ {
                            return GET_RANGE_SLICE.func(data, first, last, userdata);
                        }
                        fn infer_base_const_ptr(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) []const ELEM_ {
                            const base = GET_BASE_PTR.func(data, userdata);
                            return base[first .. last + 1];
                        }
                        fn infer_const_ptr(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) []const ELEM_ {
                            const ptr: [*]ELEM_ = @ptrCast(GET_PTR.func(data, first, userdata));
                            return ptr[0 .. (last + 1) - first];
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) []const ELEM_ {
                            assert_unreachable(@src(), "no `get_range_const_slice` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const INVALID_ID_AFTER = struct {
                        const func: FN_IMPLICIT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.INVALID_ID_AFTER_LAST_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.INVALID_ID_AFTER_LAST_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native_last => infer_native_last,
                                .infer_native_len => infer_native_len,
                                else => unreachable,
                            },
                        };
                        fn infer_native_len(data: DATA_, userdata: USERDATA_) ID_ {
                            return @intCast(GET_LEN.func(data, userdata));
                        }
                        fn infer_native_last(data: DATA_, userdata: USERDATA_) ID_ {
                            return @intCast(LAST_ID.func(data, userdata) + 1);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `invalid_id_after_last_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const INVALID_ID_BEFORE = struct {
                        const func: FN_IMPLICIT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.INVALID_ID_BEFORE_FIRST_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.INVALID_ID_BEFORE_FIRST_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_native_offset => infer_native_offset,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, _: USERDATA_) ID_ {
                            return @intCast(math.maxInt(COUNT_));
                        }
                        fn infer_native_offset(data: DATA_, userdata: USERDATA_) ID_ {
                            return @intCast(FIRST_ID.func(data, userdata) -% 1);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `invalid_id_before_first_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_VALID = struct {
                        const func: FN_ID_CHECK = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_VALID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_VALID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_native_offset => infer_native_offset,
                                .infer_first_last_id_less_equal => infer_first_last_id_less_equal,
                                .infer_first_last_id_greater_equal => infer_first_last_id_greater_equal,
                                else => unreachable,
                            },
                        };
                        fn default(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            return 0 <= id and id < GET_LEN.func(data, userdata);
                        }
                        fn infer_native(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            return 0 <= id and id < GET_LEN.func(data, userdata);
                        }
                        fn infer_native_offset(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const first = FIRST_ID.func(data, userdata);
                            const last = LAST_ID.func(data, userdata);
                            return first <= id and id <= last;
                        }
                        fn infer_first_last_id_less_equal(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const first = FIRST_ID.func(data, userdata);
                            const last = LAST_ID.func(data, userdata);
                            return ID_LESS_THAN_OR_EQUAL.func(data, first, id, userdata) and ID_LESS_THAN_OR_EQUAL.func(data, id, last, userdata);
                        }
                        fn infer_first_last_id_greater_equal(data: DATA_, id: ID_, userdata: USERDATA_) bool {
                            const first = FIRST_ID.func(data, userdata);
                            const last = LAST_ID.func(data, userdata);
                            return ID_GREATER_THAN_OR_EQUAL.func(data, id, first, userdata) and ID_GREATER_THAN_OR_EQUAL.func(data, last, id, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `valid_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    fn assert_valid_id(data: DATA_, id: ID_, userdata: USERDATA_, comptime src: SourceLocation) void {
                        const VALID = ID_VALID.func;
                        assert_with_reason(VALID(data, id, userdata), src, "id `{any}` is not valid for the current data structure state", .{id});
                    }
                    fn assert_valid_range(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_, comptime src: SourceLocation) void {
                        assert_valid_id(data, first, userdata, src);
                        assert_valid_id(data, last, userdata, src);
                        assert_with_reason(ID_LESS_THAN_OR_EQUAL.func(data, first, last, userdata), src, "first id `{any}` was not before or equal to last id `{any}`", .{ first, last });
                    }
                    fn assert_id_less(data: DATA_, a: ID_, b: ID_, userdata: USERDATA_, comptime src: SourceLocation) void {
                        assert_with_reason(ID_LESS_THAN.func(data, a, b, userdata), src, "id a `{any}` is not located before id b `{any}", .{ a, b });
                    }
                    const ID_LESS_THAN = struct {
                        const func: FN_ID_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_LESS_THAN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_LESS_THAN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_gt => infer_gt,
                                .infer_gteq => infer_gteq,
                                .infer_gt_eq => infer_gt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a < id_b;
                        }
                        fn infer_gt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_GREATER_THAN.func(data, id_b, id_a, userdata);
                        }
                        fn infer_gteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_GREATER_THAN_OR_EQUAL.func(data, id_a, id_b, userdata);
                        }
                        fn infer_gt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_GREATER_THAN.func(data, id_a, id_b, userdata) and !ID_EQUALS.func(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_less_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_LESS_THAN_OR_EQUAL = struct {
                        const func: FN_ID_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_LESS_THAN_OR_EQUAL)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_LESS_THAN_OR_EQUAL.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_gteq => infer_gteq,
                                .infer_gt => infer_gt,
                                .infer_lt_eq => infer_lt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a <= id_b;
                        }
                        fn infer_gteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_GREATER_THAN_OR_EQUAL.func(data, id_b, id_a, userdata);
                        }
                        fn infer_gt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_GREATER_THAN.func(data, id_a, id_b, userdata);
                        }
                        fn infer_lt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_LESS_THAN.func(data, id_a, id_b, userdata) or ID_EQUALS.func(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_less_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_GREATER_THAN = struct {
                        const func: FN_ID_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_GREATER_THAN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_GREATER_THAN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_lt => infer_lt,
                                .infer_lteq => infer_lteq,
                                .infer_lt_eq => infer_lt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a > id_b;
                        }
                        fn infer_lt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_LESS_THAN.func(data, id_b, id_a, userdata);
                        }
                        fn infer_lteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_LESS_THAN_OR_EQUAL.func(data, id_a, id_b, userdata);
                        }
                        fn infer_lt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_LESS_THAN.func(data, id_a, id_b, userdata) and !ID_EQUALS.func(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_greater_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_GREATER_THAN_OR_EQUAL = struct {
                        const func: FN_ID_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_GREATER_THAN_OR_EQUAL)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_GREATER_THAN_OR_EQUAL.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_lteq => infer_lteq,
                                .infer_lt => infer_lt,
                                .infer_gt_eq => infer_gt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a >= id_b;
                        }
                        fn infer_lteq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_LESS_THAN_OR_EQUAL.func(data, id_b, id_a, userdata);
                        }
                        fn infer_lt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_LESS_THAN.func(data, id_a, id_b, userdata);
                        }
                        fn infer_gt_eq(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return ID_GREATER_THAN.func(data, id_a, id_b, userdata) or ID_EQUALS.func(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_greater_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ID_EQUALS = struct {
                        const func: FN_ID_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ID_EQUALS)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ID_EQUALS.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_gt_lt => infer_gt_lt,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, id_a: ID_, id_b: ID_, _: USERDATA_) bool {
                            return id_a == id_b;
                        }
                        fn infer_gt_lt(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) bool {
                            return !ID_GREATER_THAN.func(data, id_a, id_b, userdata) and !ID_LESS_THAN.func(data, id_a, id_b, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `id_a less than or equal id_b` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const FIRST_CHILD_ID = struct {
                        const func: FN_CHILD_ID_WITH_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.FIRST_CHILD_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.FIRST_CHILD_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_nth_child => infer_nth_child,
                                else => unreachable,
                            },
                        };
                        fn infer_nth_child(data: DATA_, id: ID_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            return NTH_CHILD_ID.func(data, id, exact_num_children_per_element, 0, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `first_child_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LAST_CHILD_ID = struct {
                        const func: FN_CHILD_ID_WITH_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.LAST_CHILD_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.LAST_CHILD_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_nth_child => infer_nth_child,
                                else => unreachable,
                            },
                        };
                        fn infer_nth_child(data: DATA_, id: ID_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            return NTH_CHILD_ID.func(data, id, exact_num_children_per_element, exact_num_children_per_element - 1, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `last_child_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_CHILD_ID = struct {
                        const func: FN_NTH_CHILD_ID_WITH_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NTH_CHILD_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NTH_CHILD_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_native_offset => infer_native_offset,
                                else => unreachable,
                            },
                        };
                        fn infer_native_offset(data: DATA_, id: ID_, nth_child: COUNT_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            const id_n = LIMIT_LEN.func(data, FIRST_ID.func(data, userdata), id, userdata);
                            const child_n = nth_child_of_n_ary_flat_array_tree(id_n, exact_num_children_per_element, nth_child + 1);
                            return NTH_FROM_START.func(data, child_n, userdata);
                        }
                        fn infer_native(data: DATA_, id: ID_, nth_child: COUNT_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            const id_n = id;
                            const child_n = nth_child_of_n_ary_flat_array_tree(id_n, exact_num_children_per_element, nth_child + 1);
                            return NTH_FROM_START.func(data, child_n, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_child_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const PARENT_ID = struct {
                        const func: FN_CHILD_ID_WITH_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.PARENT_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.PARENT_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_native_offset => infer_native_offset,
                                else => unreachable,
                            },
                        };
                        fn infer_native_offset(data: DATA_, id: ID_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            const child_n = LIMIT_LEN.func(data, FIRST_ID.func(data, userdata), id, userdata);
                            const parent_n = parent_of_n_ary_flat_array_tree(child_n, exact_num_children_per_element);
                            return NTH_FROM_START.func(data, parent_n, userdata);
                        }
                        fn infer_native(data: DATA_, id: ID_, exact_num_children_per_element: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, id, userdata, @src());
                            const child_n = id;
                            const parent_n = parent_of_n_ary_flat_array_tree(child_n, exact_num_children_per_element);
                            return NTH_FROM_START.func(data, parent_n, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `parent_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET = struct {
                        const func: FN_GET = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_const_ptr => infer_const_ptr,
                                .infer_ptr => infer_ptr,
                                .infer_base_const_ptr => infer_base_const_ptr,
                                .infer_base_ptr => infer_base_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return GET_BASE_CONST_PTR.func(data, userdata)[id];
                        }
                        fn infer_base_ptr(data: DATA_, id: ID_, userdata: USERDATA_) ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return GET_BASE_PTR.func(data, userdata)[id];
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
                        const func: FN_GET_PTR = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_PTR)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_PTR.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_base_ptr => infer_base_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return &GET_BASE_PTR.func(data, userdata)[id];
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) *ELEM_ {
                            assert_unreachable(@src(), "no `get_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_CONST_PTR = struct {
                        const func: FN_GET_CONST_PTR = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_CONST_PTR)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_CONST_PTR.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_ptr => infer_ptr,
                                .infer_base_const_ptr => infer_base_const_ptr,
                                .infer_base_ptr => infer_base_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_const_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return &GET_BASE_CONST_PTR.func(data, userdata)[id];
                        }
                        fn infer_base_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return &GET_BASE_PTR.func(data, userdata)[id];
                        }
                        fn infer_ptr(data: DATA_, id: ID_, userdata: USERDATA_) *const ELEM_ {
                            assert_valid_id(data, id, userdata, @src());
                            return GET_PTR.func(data, id, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) *const ELEM_ {
                            assert_unreachable(@src(), "no `get_const_ptr` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET = struct {
                        const func: FN_SET = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SET)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SET.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_ptr => infer_ptr,
                                .infer_base_ptr => infer_base_ptr,
                                else => unreachable,
                            },
                        };
                        fn infer_base_ptr(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, id, userdata, @src());
                            const new_data = data;
                            GET_BASE_PTR.func(new_data, userdata)[id] = val;
                            return new_data;
                        }
                        fn infer_ptr(data: DATA_, id: ID_, val: ELEM_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, id, userdata, @src());
                            GET_PTR.func(data, id, userdata).* = val;
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ELEM_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `set` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SWAP = struct {
                        const func: FN_SWAP = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SWAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SWAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set => infer_get_set,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set(data: DATA_, id_a: ID_, id_b: ID_, userdata: USERDATA_) DATA_ {
                            var new_data = data;
                            const tmp = GET.func(new_data, id_b, userdata);
                            new_data = SET.func(new_data, id_b, GET.func(new_data, id_a, userdata), userdata);
                            new_data = SET.func(new_data, id_a, tmp, userdata);
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `swap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LESS_THAN = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.LESS_THAN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.LESS_THAN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_gt => infer_gt,
                                .infer_gteq => infer_gteq,
                                .infer_gt_oq => infer_gt_oq,
                                .infer_gt_eq => infer_gt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a < val_b;
                        }
                        fn infer_gt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return GREATER_THAN.func(val_b, val_a, userdata);
                        }
                        fn infer_gteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN_OR_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !EXACT_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !ORDER_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `less_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LESS_THAN_OR_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.LESS_THAN_OR_EQUAL)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.LESS_THAN_OR_EQUAL.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_gteq => infer_gteq,
                                .infer_gt => infer_gt,
                                .infer_lt_oq => infer_lt_oq,
                                .infer_lt_eq => infer_lt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a <= val_b;
                        }
                        fn infer_gteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return GREATER_THAN_OR_EQUAL.func(val_b, val_a, userdata);
                        }
                        fn infer_gt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata);
                        }
                        fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return LESS_THAN.func(val_a, val_b, userdata) or EXACT_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return LESS_THAN.func(val_a, val_b, userdata) or ORDER_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `less_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GREATER_THAN = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GREATER_THAN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GREATER_THAN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_lt => infer_lt,
                                .infer_lteq => infer_lteq,
                                .infer_lt_oq => infer_lt_oq,
                                .infer_lt_eq => infer_lt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a > val_b;
                        }
                        fn infer_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return LESS_THAN.func(val_b, val_a, userdata);
                        }
                        fn infer_lteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !LESS_THAN_OR_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_lt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !LESS_THAN.func(val_a, val_b, userdata) and !EXACT_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_lt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !LESS_THAN.func(val_a, val_b, userdata) and !ORDER_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `greater_than` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GREATER_THAN_OR_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GREATER_THAN_OR_EQUAL)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GREATER_THAN_OR_EQUAL.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_lteq => infer_lteq,
                                .infer_lt => infer_lt,
                                .infer_gt_oq => infer_gt_oq,
                                .infer_gt_eq => infer_gt_eq,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a >= val_b;
                        }
                        fn infer_lteq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return LESS_THAN_OR_EQUAL.func(val_b, val_a, userdata);
                        }
                        fn infer_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !LESS_THAN.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !EXACT_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !ORDER_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `greater_than_or_equal` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ORDER_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ORDER_EQUALS)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ORDER_EQUALS.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_eq => infer_eq,
                                .infer_gt_lt => infer_gt_lt,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a == val_b;
                        }
                        fn infer_eq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !EXACT_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !LESS_THAN.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `order_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const EXACT_EQUAL = struct {
                        const func: FN_ELEM_COMPARE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.EXACT_EQUALS)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.EXACT_EQUALS.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_oq => infer_oq,
                                .infer_gt_lt => infer_gt_lt,
                                else => unreachable,
                            },
                        };
                        fn infer_native(val_a: ELEM_, val_b: ELEM_, _: USERDATA_) bool {
                            return val_a == val_b;
                        }
                        fn infer_oq(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !ORDER_EQUAL.func(val_a, val_b, userdata);
                        }
                        fn infer_gt_lt(val_a: ELEM_, val_b: ELEM_, userdata: USERDATA_) bool {
                            return !GREATER_THAN.func(val_a, val_b, userdata) and !LESS_THAN.func(val_a, val_b, userdata);
                        }
                        fn unusable(_: ELEM_, _: ELEM_, _: USERDATA_) bool {
                            assert_unreachable(@src(), "no `exactly_equals` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const FIRST_ID = struct {
                        const func: FN_IMPLICIT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.FIRST_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.FIRST_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_nth_from_start => infer_nth_from_start,
                                .infer_len_nth_from_end => infer_len_nth_from_end,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, _: USERDATA_) ID_ {
                            return 0;
                        }
                        fn infer_nth_from_start(data: DATA_, userdata: USERDATA_) ID_ {
                            return NTH_FROM_START.func(data, 0, userdata);
                        }
                        fn infer_len_nth_from_end(data: DATA_, userdata: USERDATA_) ID_ {
                            return NTH_FROM_END.func(data, GET_LEN.func(data, userdata), userdata);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `first_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LAST_ID = struct {
                        const func: FN_IMPLICIT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.LAST_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.LAST_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_nth_from_end => infer_nth_from_end,
                                .infer_len_nth_from_start => infer_len_nth_from_start,
                                else => unreachable,
                            },
                        };
                        fn infer_native(data: DATA_, userdata: USERDATA_) ID_ {
                            return @intCast(GET_LEN.func(data, userdata) - 1);
                        }
                        fn infer_nth_from_end(data: DATA_, userdata: USERDATA_) ID_ {
                            return NTH_FROM_END.func(data, 0, userdata);
                        }
                        fn infer_len_nth_from_start(data: DATA_, userdata: USERDATA_) ID_ {
                            return NTH_FROM_START.func(data, GET_LEN.func(data, userdata) - 1, userdata);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `last_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NEXT_ID = struct {
                        const func: FN_ADJACENT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NEXT_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NEXT_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_nth_next => infer_nth_next,
                                .infer_last_prev => infer_last_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                            return curr + 1;
                        }
                        fn infer_nth_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            return NTH_NEXT_ID.func(data, curr, 1, userdata);
                        }
                        fn infer_last_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            var i = LAST_ID.func(data, userdata);
                            if (ID_EQUALS.func(data, i, curr, userdata)) return INVALID_ID_AFTER.func(data, userdata);
                            var ii = PREV_ID.func(data, i, userdata);
                            while (!ID_EQUALS.func(data, i, curr, userdata)) {
                                if (!ID_VALID.func(data, ii, userdata)) return ii;
                                i = ii;
                                ii = PREV_ID.func(data, i, userdata);
                            }
                            return i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const PREV_ID = struct {
                        const func: FN_ADJACENT_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.PREV_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.PREV_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_nth_prev => infer_nth_prev,
                                .infer_first_next => infer_first_next,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, curr: ID_, _: USERDATA_) ID_ {
                            return curr - 1;
                        }
                        fn infer_nth_prev(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            return NTH_PREV_ID.func(data, curr, 1, userdata);
                        }
                        fn infer_first_next(data: DATA_, curr: ID_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            var i = FIRST_ID.func(data, userdata);
                            if (ID_EQUALS.func(data, i, curr, userdata)) return INVALID_ID_BEFORE.func(data, userdata);
                            var ii = NEXT_ID.func(data, i, userdata);
                            while (!ID_EQUALS.func(data, ii, curr, userdata)) {
                                if (!ID_VALID.func(data, ii, userdata)) return ii;
                                i = ii;
                                ii = NEXT_ID.func(data, i, userdata);
                            }
                            return i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `prev_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_NEXT_ID = struct {
                        const func: FN_NTH_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NTH_NEXT_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NTH_NEXT_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_next => infer_next,
                                .infer_last_prev => infer_last_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                            return curr + @as(ID_, @intCast(n));
                        }
                        fn infer_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            var i = curr;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                i = NEXT_ID.func(data, i, userdata);
                            }
                            return i;
                        }
                        fn infer_last_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            if (n == 0) return curr;
                            const last = LAST_ID.func(data, userdata);
                            var left_i = last;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                if (ID_EQUALS.func(data, left_i, curr, userdata) or !ID_VALID.func(data, left_i, userdata)) return INVALID_ID_AFTER.func(data, userdata);
                                left_i = PREV_ID.func(data, curr, userdata);
                            }
                            var right_i = last;
                            var left_ii = PREV_ID.func(data, left_i, userdata);
                            var right_ii = PREV_ID.func(data, last, userdata);
                            while (!ID_EQUALS.func(data, left_ii, curr, userdata)) {
                                left_i = left_ii;
                                left_ii = PREV_ID.func(data, left_i, userdata);
                                if (!ID_VALID.func(data, left_ii, userdata)) return left_ii;
                                right_i = right_ii;
                                right_ii = PREV_ID.func(data, right_i, userdata);
                            }
                            return right_i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_next_index` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_PREV_ID = struct {
                        const func: FN_NTH_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NTH_PREV_ID)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NTH_PREV_ID.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_prev => infer_prev,
                                .infer_first_next => infer_first_next,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, curr: ID_, n: COUNT_, _: USERDATA_) ID_ {
                            return curr - n;
                        }
                        fn infer_prev(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            var i = curr;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                i = PREV_ID.func(data, i, userdata);
                            }
                            return i;
                        }
                        fn infer_first_next(data: DATA_, curr: ID_, n: COUNT_, userdata: USERDATA_) ID_ {
                            assert_valid_id(data, curr, userdata, @src());
                            const first = FIRST_ID.func(data, userdata);
                            var right_i = first;
                            var nn: COUNT_ = 0;
                            while (nn < n) : (nn += 1) {
                                if (ID_EQUALS.func(data, right_i, curr, userdata) or !ID_VALID.func(data, right_i, userdata)) return INVALID_ID_AFTER.func(data, userdata);
                                right_i = NEXT_ID.func(data, curr, userdata);
                            }
                            var left_i = first;
                            var right_ii = NEXT_ID.func(data, right_i, userdata);
                            var left_ii = NEXT_ID.func(data, first, userdata);
                            while (!ID_EQUALS.func(data, right_ii, curr, userdata)) {
                                right_i = right_ii;
                                right_ii = NEXT_ID.func(data, right_i, userdata);
                                if (!ID_VALID.func(data, right_ii, userdata)) return right_ii;
                                left_i = left_ii;
                                left_ii = NEXT_ID.func(data, left_i, userdata);
                            }
                            return left_i;
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_prev_id` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_FROM_START = struct {
                        const func: FN_IMPLICIT_NTH_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NTH_ID_FROM_START)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NTH_ID_FROM_START.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_native_first => infer_native_first,
                                .infer_first_nth_next => infer_first_nth_next,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, n: COUNT_, _: USERDATA_) ID_ {
                            return n;
                        }
                        fn infer_native_first(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            return FIRST_ID.func(data, userdata) + @as(ID_, @intCast(n));
                        }
                        fn infer_first_nth_next(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            return NTH_NEXT_ID.func(data, FIRST_ID.func(data, userdata), n, userdata);
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_index_from_start` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const NTH_FROM_END = struct {
                        const func: FN_IMPLICIT_NTH_ID = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.NTH_ID_FROM_END)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.NTH_ID_FROM_END.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native_last => infer_native_last,
                                .infer_last_nth_prev => infer_last_nth_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_native_last(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            return @intCast(LAST_ID.func(data, userdata) - n);
                        }
                        fn infer_last_nth_prev(data: DATA_, n: COUNT_, userdata: USERDATA_) ID_ {
                            return NTH_PREV_ID.func(data, LAST_ID.func(data, userdata), n, userdata);
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) ID_ {
                            assert_unreachable(@src(), "no `nth_index_from_end` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_LEN = struct {
                        const func: FN_IMPLICIT_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_LEN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_LEN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native_last => infer_native_last,
                                .infer_range => infer_range,
                                else => unreachable,
                            },
                        };
                        fn infer_native_last(data: DATA_, userdata: USERDATA_) COUNT_ {
                            return @intCast(LAST_ID.func(data, userdata) + 1);
                        }
                        fn infer_range(data: DATA_, userdata: USERDATA_) COUNT_ {
                            return RANGE_LEN.func(FIRST_ID.func(data, userdata), LAST_ID.func(data, userdata), userdata);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `get_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET_LEN = struct {
                        const func: FN_SET_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SET_LEN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SET_LEN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                else => unreachable,
                            },
                        };
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `set_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const GET_CAP = struct {
                        const func: FN_IMPLICIT_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.GET_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.GET_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                else => unreachable,
                            },
                        };
                        fn unusable(_: DATA_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `get_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const SET_CAP = struct {
                        const func: FN_SET_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SET_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SET_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                else => unreachable,
                            },
                        };
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `set_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const RANGE_LEN = struct {
                        const func: FN_RANGE_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.RANGE_LEN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.RANGE_LEN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_limit => infer_limit,
                                .infer_next => infer_next,
                                .infer_prev => infer_prev,
                                else => unreachable,
                            },
                        };

                        fn infer_native(_: DATA_, first: ID_, last: ID_, _: USERDATA_) COUNT_ {
                            return @intCast((last + 1) - first);
                        }
                        fn infer_limit(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                            const limit_len = LIMIT_LEN.func(data, first, last, userdata);
                            return limit_len + 1;
                        }
                        fn infer_next(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                            if (ID_EQUALS.func(data, first, last, userdata)) return 1;
                            var n: COUNT_ = 1;
                            var i: ID_ = NEXT_ID.func(data, first, userdata);
                            while (true) {
                                n += 1;
                                if (ID_EQUALS.func(data, i, last, userdata)) break;
                                i = NEXT_ID.func(data, i, userdata);
                            }
                            return n;
                        }
                        fn infer_prev(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) COUNT_ {
                            assert_valid_range(data, first, last, userdata, @src());
                            if (ID_EQUALS.func(data, first, last, userdata)) return 1;
                            var n: COUNT_ = 1;
                            var i: ID_ = PREV_ID.func(data, last, userdata);
                            while (true) {
                                n += 1;
                                if (ID_EQUALS.func(data, i, first, userdata)) break;
                                i = PREV_ID.func(data, i, userdata);
                            }
                            return n;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `range_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const LIMIT_LEN = struct {
                        const func: FN_RANGE_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.LIMIT_LEN)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.LIMIT_LEN.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_native => infer_native,
                                .infer_range => infer_range,
                                .infer_next => infer_next,
                                .infer_prev => infer_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_native(_: DATA_, start: ID_, end_exclude: ID_, _: USERDATA_) ID_ {
                            return end_exclude - start;
                        }
                        fn infer_range(data: DATA_, start: ID_, end_exclude: ID_, userdata: USERDATA_) ID_ {
                            if (ID_EQUALS.func(data, start, end_exclude, userdata)) return 0;
                            const range_len = RANGE_LEN.func(data, start, PREV_ID.func(data, end_exclude, userdata), userdata);
                            return range_len;
                        }
                        fn infer_next(data: DATA_, start: ID_, end_exclude: ID_, userdata: USERDATA_) COUNT_ {
                            if (ID_EQUALS.func(data, start, end_exclude, userdata)) return 0;
                            var n: COUNT_ = 0;
                            var i: ID_ = NEXT_ID.func(data, start, userdata);
                            while (true) {
                                n += 1;
                                if (ID_EQUALS.func(data, i, end_exclude, userdata)) break;
                                i = NEXT_ID.func(data, i, userdata);
                            }
                            return n;
                        }
                        fn infer_prev(data: DATA_, start: ID_, end_exclude: ID_, userdata: USERDATA_) COUNT_ {
                            if (ID_EQUALS.func(data, start, end_exclude, userdata)) return 0;
                            var n: COUNT_ = 0;
                            var i: ID_ = PREV_ID.func(data, end_exclude, userdata);
                            while (true) {
                                n += 1;
                                if (ID_EQUALS.func(data, i, start, userdata)) break;
                                i = PREV_ID.func(data, i, userdata);
                            }
                            return n;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) COUNT_ {
                            assert_unreachable(@src(), "no `limit_len` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const REVERSE_RANGE = struct {
                        const func: FN_RANGE_OP = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.REVERSE_RANGE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.REVERSE_RANGE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_slice => infer_slice,
                                .infer_swap => infer_swap,
                                else => unreachable,
                            },
                        };
                        fn infer_slice(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            const new_data = data;
                            const slice = GET_RANGE_SLICE.func(data, first, last, userdata);
                            Utils.Mem.reverse_slice(slice);
                            return new_data;
                        }
                        fn infer_swap(data: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            if (!ID_LESS_THAN_OR_EQUAL.func(data, first, last, userdata)) return data;
                            var new_data = data;
                            var left = first;
                            var right = last;
                            while (!ID_EQUALS.func(data, left, right, userdata)) {
                                new_data = SWAP.func(new_data, left, right, userdata);
                                left = NEXT_ID.func(data, left, userdata);
                                if (ID_EQUALS.func(data, left, right, userdata)) break;
                                right = PREV_ID.func(new_data, right, userdata);
                            }
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `reverse_range` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ROTATE_RIGHT = struct {
                        const func: FN_ROTATE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ROTATE_RANGE_RIGHT)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ROTATE_RANGE_RIGHT.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_rot_left => infer_rot_left,
                                .infer_reverse_nth_next => infer_reverse_nth_next,
                                .infer_reverse_nth_prev => infer_reverse_nth_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_rot_left(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            const range_len = RANGE_LEN.func(data, first, last, userdata);
                            if (range_len == 0) return data;
                            const count_mod = count % range_len;
                            const inverse_count = range_len - count_mod;
                            return ROTATE_LEFT.func(data, first, last, inverse_count, userdata);
                        }
                        fn infer_reverse_nth_prev(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            if (!ID_LESS_THAN.func(data, first, last, userdata)) return data;
                            var new_data = data;
                            const len = RANGE_LEN.func(data, first, last, userdata);
                            const shift = count % len;
                            if (shift == 0) return data;
                            const first_group_last_id = NTH_PREV_ID.func(data, last, shift, userdata);
                            const last_group_first_id = NEXT_ID.func(data, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, first, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, last_group_first_id, last, new_data);
                            new_data = REVERSE_RANGE.func(new_data, first, last, new_data);
                            return new_data;
                        }
                        fn infer_reverse_nth_next(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            if (!ID_LESS_THAN.func(data, first, last, userdata)) return data;
                            var new_data = data;
                            const len = RANGE_LEN.func(data, first, last, userdata);
                            const shift = count % len;
                            if (shift == 0) return data;
                            const inverse_shift = len - shift;
                            const first_group_last_id = NTH_NEXT_ID.func(data, first, inverse_shift, userdata);
                            const last_group_first_id = NEXT_ID.func(data, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, first, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, last_group_first_id, last, new_data);
                            new_data = REVERSE_RANGE.func(new_data, first, last, new_data);
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `rotate_range_right` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ROTATE_LEFT = struct {
                        const func: FN_ROTATE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ROTATE_RANGE_LEFT)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ROTATE_RANGE_LEFT.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_rot_right => infer_rot_right,
                                .infer_reverse_nth_next => infer_reverse_nth_next,
                                .infer_reverse_nth_prev => infer_reverse_nth_prev,
                                else => unreachable,
                            },
                        };
                        fn infer_rot_right(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            const range_len = RANGE_LEN.func(data, first, last, userdata);
                            if (range_len == 0) return data;
                            const count_mod = count % range_len;
                            const inverse_count = range_len - count_mod;
                            return ROTATE_RIGHT.func(data, first, last, inverse_count, userdata);
                        }
                        fn infer_reverse_nth_next(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            if (!ID_LESS_THAN.func(data, first, last, userdata)) return data;
                            var new_data = data;
                            const len = RANGE_LEN.func(data, first, last, userdata);
                            const shift = count % len;
                            if (shift == 0) return data;
                            const last_group_first_id = NTH_NEXT_ID.func(data, first, shift, userdata);
                            const first_group_last_id = PREV_ID.func(data, last_group_first_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, first, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, last_group_first_id, last, new_data);
                            new_data = REVERSE_RANGE.func(new_data, first, last, new_data);
                            return new_data;
                        }
                        fn infer_reverse_nth_prev(data: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, first, userdata, @src());
                            assert_valid_id(data, last, userdata, @src());
                            if (!ID_LESS_THAN.func(data, first, last, userdata)) return data;
                            var new_data = data;
                            const len = RANGE_LEN.func(data, first, last, userdata);
                            const shift = count % len;
                            if (shift == 0) return data;
                            const inverse_shift = len - shift;
                            const last_group_first_id = NTH_PREV_ID.func(data, last, inverse_shift, userdata);
                            const first_group_last_id = PREV_ID.func(data, last_group_first_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, first, first_group_last_id, userdata);
                            new_data = REVERSE_RANGE.func(new_data, last_group_first_id, last, new_data);
                            new_data = REVERSE_RANGE.func(new_data, first, last, new_data);
                            return new_data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `rotate_range_left` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_ONE_RIGHT_DISPLACE = struct {
                        const func: FN_RANGE_OP = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_ONE_RIGHT_DISPLACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_ONE_RIGHT_DISPLACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set_move_block_left_overwrite => infer_get_set_move_block_left_overwrite,
                                .infer_mv_block_right => infer_mv_block_right,
                                .infer_rot_left => infer_rot_left,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set_move_block_left_overwrite(data_: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            var data = data_;
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            if (ID_EQUALS.func(data, old_id, new_id, userdata)) return data;
                            assert_id_less(data, old_id, new_id, userdata);
                            const val = GET.func(data, old_id, userdata);
                            const first_to_move = NEXT_ID.func(data, old_id, userdata);
                            data = MOVE_RANGE_LEFT_OVERWRITE.func(data, first_to_move, new_id, 1, userdata);
                            data = SET.func(data, new_id, val, userdata);
                            return data;
                        }
                        fn infer_mv_block_right(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            return MOVE_RANGE_RIGHT_DISPLACE.func(data, old_id, old_id, new_id, userdata);
                        }
                        fn infer_rot_left(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            if (ID_EQUALS.func(data, old_id, new_id, userdata)) return data;
                            assert_id_less(data, old_id, new_id, userdata);
                            return ROTATE_LEFT.func(data, old_id, new_id, 1, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_one_right_displace` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_ONE_LEFT_DISPLACE = struct {
                        const func: FN_RANGE_OP = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_ONE_LEFT_DISPLACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_ONE_LEFT_DISPLACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set_move_block_right_overwrite => infer_get_set_move_block_right_overwrite,
                                .infer_mv_block_left => infer_mv_block_left,
                                .infer_rot_right => infer_rot_right,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set_move_block_right_overwrite(data_: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            var data = data_;
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            if (ID_EQUALS.func(data, old_id, new_id, userdata)) return data;
                            assert_id_less(data, old_id, new_id, userdata);
                            const val = GET.func(data, old_id, userdata);
                            const first_to_move = NEXT_ID.func(data, old_id, userdata);
                            data = MOVE_RANGE_RIGHT_OVERWRITE.func(data, first_to_move, new_id, 1, userdata);
                            data = SET.func(data, new_id, val, userdata);
                            return data;
                        }
                        fn infer_mv_block_left(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            return MOVE_RANGE_LEFT_DISPLACE.func(data, old_id, old_id, new_id, userdata);
                        }
                        fn infer_rot_right(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data, old_id, userdata, @src());
                            assert_valid_id(data, new_id, userdata, @src());
                            if (ID_EQUALS.func(data, old_id, new_id, userdata)) return data;
                            assert_id_less(data, old_id, new_id, userdata);
                            return ROTATE_RIGHT.func(data, old_id, new_id, 1, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_one_left_displace` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_ONE_OVERWRITE = struct {
                        const func: FN_RANGE_OP = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_ONE_OVERWRITE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_ONE_OVERWRITE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set => infer_get_set,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set(data: DATA_, old_id: ID_, new_id: ID_, userdata: USERDATA_) DATA_ {
                            return SET.func(data, new_id, GET.func(data, old_id, userdata), userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_one_overwrite` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_RANGE_RIGHT_DISPLACE = struct {
                        const func: FN_MOVE_RANGE_DISPLACE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_RANGE_RIGHT_DISPLACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_RANGE_RIGHT_DISPLACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_rot_left => infer_rot_left,
                                else => unreachable,
                            },
                        };
                        fn infer_rot_left(data_: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first_old_id, last_old_id, userdata, @src());
                            assert_valid_id(data_, new_first_id, userdata, @src());
                            var data = data_;
                            if (ID_EQUALS.func(data, first_old_id, new_first_id, userdata)) return data;
                            assert_id_less(data, first_old_id, new_first_id, userdata, @src());
                            const block_len = RANGE_LEN.func(data, first_old_id, last_old_id, userdata);
                            const new_last = NTH_NEXT_ID.func(data, new_first_id, block_len - 1, userdata);
                            assert_valid_id(data, new_last, userdata, @src());
                            data = ROTATE_LEFT.func(data, first_old_id, new_last, block_len, userdata);
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_range_right_displace` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_RANGE_LEFT_DISPLACE = struct {
                        const func: FN_MOVE_RANGE_DISPLACE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_RANGE_LEFT_DISPLACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_RANGE_LEFT_DISPLACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_rot_right => infer_rot_right,
                                else => unreachable,
                            },
                        };
                        fn infer_rot_right(data_: DATA_, first_old_id: ID_, last_old_id: ID_, new_first_id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first_old_id, last_old_id, userdata, @src());
                            assert_valid_id(data_, new_first_id, userdata, @src());
                            var data = data_;
                            if (ID_EQUALS.func(data, first_old_id, new_first_id, userdata)) return data;
                            assert_id_less(data, new_first_id, first_old_id, userdata, @src());
                            const block_len = RANGE_LEN.func(data, first_old_id, last_old_id, userdata);
                            data = ROTATE_RIGHT.func(data, new_first_id, last_old_id, block_len, userdata);
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_range_left_displace` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_RANGE_LEFT_OVERWRITE = struct {
                        const func: FN_MOVE_RANGE_OVERWRITE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_RANGE_LEFT_OVERWRITE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_RANGE_LEFT_OVERWRITE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_mv_one_overwrite => infer_mv_one_overwrite,
                                else => unreachable,
                            },
                        };
                        fn infer_mv_one_overwrite(data_: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first, last, userdata, @src());
                            if (count == 0) {
                                @branchHint(.unlikely);
                                return data_;
                            }
                            var data = data_;
                            var read = first;
                            var write = NTH_PREV_ID.func(data, read, count, userdata);
                            assert_valid_id(data, write, userdata, @src());
                            while (true) {
                                data = MOVE_ONE_OVERWRITE.func(data, read, write, userdata);
                                if (ID_EQUALS.func(data, read, last, userdata)) break;
                                write = NEXT_ID.func(data, write, userdata);
                                read = NEXT_ID.func(data, read, userdata);
                            }
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_range_left_overwrite` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const MOVE_RANGE_RIGHT_OVERWRITE = struct {
                        const func: FN_MOVE_RANGE_OVERWRITE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.MOVE_RANGE_LEFT_OVERWRITE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.MOVE_RANGE_LEFT_OVERWRITE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_mv_one_overwrite => infer_mv_one_overwrite,
                                else => unreachable,
                            },
                        };
                        fn infer_mv_one_overwrite(data_: DATA_, first: ID_, last: ID_, count: COUNT_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first, last, userdata, @src());
                            if (count == 0) {
                                @branchHint(.unlikely);
                                return data_;
                            }
                            var data = data_;
                            var read = last;
                            var write = NTH_NEXT_ID.func(data, read, count, userdata);
                            assert_valid_id(data, write, userdata, @src());
                            while (true) {
                                data = MOVE_ONE_OVERWRITE.func(data, read, write, userdata);
                                if (ID_EQUALS.func(data, read, first, userdata)) break;
                                write = PREV_ID.func(data, write, userdata);
                                read = PREV_ID.func(data, read, userdata);
                            }
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `move_range_right_overwrite` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };

                    const SCRAMBLE = struct {
                        const func: FN_SCRAMBLE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.SCRAMBLE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.SCRAMBLE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_mv_one_overwrite => infer_mv_one_overwrite,
                                else => unreachable,
                            },
                        };
                        fn infer_mv_one_overwrite(data_: DATA_, rand: Random, first: ID_, last: ID_, iterations: COUNT_, userdata: USERDATA_) DATA_ {
                            var data = data_;
                            const span = RANGE_LEN.func(data, first, last, userdata);
                            if (span <= 1) return data;
                            if (span == 2) {
                                if (rand.boolean()) {
                                    return SWAP.func(data, first, last);
                                }
                            }
                            var n: COUNT_ = 0;
                            const first_n = rand.intRangeLessThan(COUNT_, 0, span);
                            const first_id = NTH_NEXT_ID.func(data, first, first_n, userdata);
                            const first_val = GET.func(data, first_n, userdata);
                            var empty_n: ID_ = first_n;
                            var empty_id: ID_ = first_id;
                            while (n < iterations) : (n += 1) {
                                const move_n = find_different_idx: {
                                    while (true) {
                                        const possible_different_n = rand.intRangeLessThan(COUNT_, 0, span);
                                        if (possible_different_n != empty_n) break :find_different_idx possible_different_n;
                                    }
                                };
                                const move_id = NTH_NEXT_ID.func(data, first, move_n, userdata);
                                data = MOVE_ONE_OVERWRITE.func(data, move_id, empty_id, userdata);
                                empty_id = move_id;
                                empty_n = move_n;
                            }
                            return SET.func(data, empty_id, first_val, userdata);
                        }
                        fn unusable(_: DATA_, _: Random, _: ID_, _: ID_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `scramble_elements` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const APPEND_ONE_SLOT_ASSUME_CAP = struct {
                        const func: FN_APPEND_ONE_SLOT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.APPEND_ONE_SLOT_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.APPEND_ONE_SLOT_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_append_many => infer_append_many,
                                .infer_set_len => infer_set_len,
                                else => unreachable,
                            },
                        };
                        fn infer_set_len(data_: DATA_, userdata: USERDATA_) struct { DATA_, ID_ } {
                            const len = GET_LEN.func(data_, userdata);
                            const data = SET_LEN.func(data_, len + 1, userdata);
                            const last = LAST_ID.func(data_, userdata);
                            return .{ data, last };
                        }
                        fn infer_append_many(data_: DATA_, userdata: USERDATA_) struct { DATA_, ID_ } {
                            const data, const id, _ = APPEND_MANY_SLOTS_ASSUME_CAP.func(data_, 1, userdata);
                            return .{ data, id };
                        }
                        fn unusable(_: DATA_, _: USERDATA_) struct { DATA_, ID_ } {
                            assert_unreachable(@src(), "no `append_one_slot_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const APPEND_MANY_SLOTS_ASSUME_CAP = struct {
                        const func: FN_APPEND_N_SLOTS = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.APPEND_MANY_SLOTS_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.APPEND_MANY_SLOTS_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_append_one => infer_append_one,
                                .infer_set_len => infer_set_len,
                                else => unreachable,
                            },
                        };
                        fn infer_set_len(data_: DATA_, n: COUNT_, userdata: USERDATA_) struct { DATA_, ID_, ID_ } {
                            if (n == 0) return .{ data_, INVALID_ID_AFTER.func(data_, userdata) };
                            const len = GET_LEN.func(data_, userdata);
                            const data = SET_LEN.func(data_, len + n, userdata);
                            const last_new_id = LAST_ID.func(data, userdata);
                            const first_new_id = NTH_PREV_ID.func(data, n - 1, userdata);
                            return .{ data, first_new_id, last_new_id };
                        }
                        fn infer_append_one(data_: DATA_, n: COUNT_, userdata: USERDATA_) struct { DATA_, ID_, ID_ } {
                            if (n == 0) return .{ data_, INVALID_ID_AFTER.func(data_, userdata) };
                            var data, const first = APPEND_ONE_SLOT_ASSUME_CAP.func(data_, userdata);
                            var last: ID_ = first;
                            var nn = 1;
                            while (nn < n) : (nn += 1) {
                                data, last = APPEND_ONE_SLOT_ASSUME_CAP.func(data_, userdata);
                            }
                            return .{ data, first, last };
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) struct { DATA_, ID_, ID_ } {
                            assert_unreachable(@src(), "no `append_many_slots_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const INSERT_ONE_SLOT_BEFORE_ASSUME_CAP = struct {
                        const func: FN_INSERT_ONE_SLOT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_append_one => infer_append_one,
                                .infer_insert_many => infer_insert_many,
                                else => unreachable,
                            },
                        };
                        fn infer_append_one(data_: DATA_, id: ID_, userdata: USERDATA_) struct { DATA_, ID_ } {
                            assert_valid_id(data_, id, userdata, @src());
                            const last_to_move = LAST_ID.func(data_, userdata);
                            var data, _ = APPEND_ONE_SLOT_ASSUME_CAP.func(data_, userdata);
                            data = MOVE_RANGE_RIGHT_OVERWRITE.func(data, id, last_to_move, 1, userdata);
                            return .{ data, id };
                        }
                        fn infer_insert_many(data_: DATA_, id: ID_, userdata: USERDATA_) struct { DATA_, ID_ } {
                            const data, const new_id, _ = INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP.func(data_, id, 1, userdata);
                            return .{ data, new_id };
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) struct { DATA_, ID_ } {
                            assert_unreachable(@src(), "no `insert_one_slot_before_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP = struct {
                        const func: FN_INSERT_N_SLOTS = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_append_many => infer_append_many,
                                .infer_insert_one => infer_insert_one,
                                else => unreachable,
                            },
                        };
                        fn infer_insert_one(data_: DATA_, id: ID_, n: COUNT_, userdata: USERDATA_) struct { DATA_, ID_, ID_ } {
                            if (n == 0) return .{ data_, undefined, undefined };
                            assert_valid_id(data_, id, userdata, @src());
                            var nn = n;
                            var data, var first = INSERT_ONE_SLOT_BEFORE_ASSUME_CAP.func(data_, id, userdata);
                            nn -= 1;
                            while (nn > 0) : (nn -= 1) {
                                data, first = INSERT_ONE_SLOT_BEFORE_ASSUME_CAP.func(data, first, userdata);
                            }
                            return .{ data, first, NTH_NEXT_ID.func(data, first, n - 1, userdata) };
                        }
                        fn infer_append_many(data_: DATA_, id: ID_, n: COUNT_, userdata: USERDATA_) struct { DATA_, ID_, ID_ } {
                            if (n == 0) return data_;
                            assert_valid_id(data_, id, userdata, @src());
                            const last_to_move = LAST_ID.func(data_, userdata);
                            var data, _ = APPEND_MANY_SLOTS_ASSUME_CAP.func(data_, n, userdata);
                            data = MOVE_RANGE_RIGHT_OVERWRITE.func(data, id, last_to_move, n, userdata);
                            return .{ data, id, NTH_NEXT_ID.func(data, id, n - 1, userdata) };
                        }
                        fn unusable(_: DATA_, _: ID_, _: COUNT_, _: USERDATA_) struct { DATA_, ID_, ID_ } {
                            assert_unreachable(@src(), "no `insert_many_slots_before_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const PREPEND_ONE_SLOT_ASSUME_CAP = struct {
                        const func: FN_APPEND_ONE_SLOT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.PREPEND_ONE_SLOT_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.PREPEND_ONE_SLOT_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_insert_one => infer_insert_one,
                                else => unreachable,
                            },
                        };
                        fn infer_insert_one(data: DATA_, userdata: USERDATA_) struct { DATA_, ID_ } {
                            if (GET_LEN.func(data, userdata) == 0) {
                                @branchHint(.unlikely);
                                return APPEND_ONE_SLOT_ASSUME_CAP.func(data, userdata);
                            }
                            const first = FIRST_ID.func(data, userdata);
                            return INSERT_ONE_SLOT_BEFORE_ASSUME_CAP.func(data, first, userdata);
                        }
                        fn unusable(_: DATA_, _: USERDATA_) struct { DATA_, ID_ } {
                            assert_unreachable(@src(), "no `prepend_one_slot_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const PREPEND_MANY_SLOTS_ASSUME_CAP = struct {
                        const func: FN_APPEND_N_SLOTS = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.PREPEND_MANY_SLOTS_ASSUME_CAP)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.PREPEND_MANY_SLOTS_ASSUME_CAP.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_insert_many => infer_insert_many,
                                else => unreachable,
                            },
                        };
                        fn infer_insert_many(data: DATA_, n: COUNT_, userdata: USERDATA_) struct { DATA_, ID_, ID_ } {
                            if (n == 0) {
                                @branchHint(.unlikely);
                                return data;
                            }
                            if (GET_LEN.func(data, userdata) == 0) {
                                @branchHint(.unlikely);
                                return APPEND_MANY_SLOTS_ASSUME_CAP.func(data, n, userdata);
                            }
                            const first = FIRST_ID.func(data, userdata);
                            return INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP.func(data, first, n, userdata);
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) struct { DATA_, ID_, ID_ } {
                            assert_unreachable(@src(), "no `prepend_many_slots_assume_cap` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const DELETE_ONE = struct {
                        const func: FN_DELETE_ONE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.DELETE_ONE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.DELETE_ONE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_delete_range => infer_delete_range,
                                .infer_set_len => infer_set_len,
                                else => unreachable,
                            },
                        };
                        fn infer_set_len(data_: DATA_, id: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_id(data_, id, userdata, @src());
                            var data = data_;
                            const last = LAST_ID.func(data, userdata);
                            if (!ID_EQUALS.func(data, id, last, userdata)) {
                                const first = NEXT_ID.func(data, id, userdata);
                                data = MOVE_RANGE_LEFT_OVERWRITE.func(data, first, last, 1, userdata);
                            }
                            const old_len = GET_LEN.func(data, userdata);
                            data = SET_LEN.func(data, old_len - 1, userdata);
                            return data;
                        }
                        fn infer_delete_range(data_: DATA_, id: ID_, userdata: USERDATA_) DATA_ {
                            return DELETE_RANGE.func(data_, id, id, userdata);
                        }
                        fn unusable(_: DATA_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `delete_one` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const DELETE_RANGE = struct {
                        const func: FN_DELETE_RANGE = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.DELETE_RANGE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.DELETE_RANGE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_delete_one => infer_delete_one,
                                .infer_set_len => infer_set_len,
                                else => unreachable,
                            },
                        };
                        fn infer_set_len(data_: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first, last, userdata, @src());
                            var data = data_;
                            const last_in_list = LAST_ID.func(data, userdata);
                            const count = RANGE_LEN.func(data, first, last, userdata);
                            const old_len = GET_LEN.func(data, userdata);
                            if (!ID_EQUALS.func(data, last_in_list, last, userdata)) {
                                const first_after_delete = NEXT_ID.func(data, last, userdata);
                                data = MOVE_RANGE_LEFT_OVERWRITE.func(data, first_after_delete, last_in_list, count, userdata);
                            }
                            data = SET_LEN.func(data, old_len - count, userdata);
                            return data;
                        }
                        fn infer_delete_one(data_: DATA_, first: ID_, last: ID_, userdata: USERDATA_) DATA_ {
                            assert_valid_range(data_, first, last, userdata, @src());
                            var data = data_;
                            var count = RANGE_LEN.func(data, first, last, userdata);
                            if (ID_EQUALS.func(data, FIRST_ID.func(data, userdata), first, userdata)) {
                                while (count > 0) : (count -= 1) {
                                    data = DELETE_ONE.func(data, FIRST_ID.func(data, userdata), userdata);
                                }
                            } else {
                                const prev = PREV_ID.func(data, first, userdata);
                                while (count > 0) : (count -= 1) {
                                    const to_delete = NEXT_ID.func(data, prev, userdata);
                                    data = DELETE_ONE.func(data, to_delete, userdata);
                                }
                            }
                            return data;
                        }
                        fn unusable(_: DATA_, _: ID_, _: ID_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `delete_range` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const ENSURE_FREE_SPACE = struct {
                        const func: FN_SET_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.ENSURE_FREE_SPACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.ENSURE_FREE_SPACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set_cap => infer_get_set_cap,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set_cap(data: DATA_, free_space_to_keep: COUNT_, userdata: USERDATA_) DATA_ {
                            const len = GET_LEN.func(data, userdata);
                            const cap = GET_CAP.func(data, userdata);
                            const space = cap - len;
                            if (space <= free_space_to_keep) return data;
                            const new_cap = len + free_space_to_keep;
                            return SET_CAP.func(data, new_cap, userdata);
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `ensure_free_space` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                    const TRIM_FREE_SPACE = struct {
                        const func: FN_SET_COUNT = switch (SOLUTIONS[@intFromEnum(Recipes.PackageFlags.TRIM_FREE_SPACE)]) {
                            .UNAVAILABLE => unusable,
                            .USER_PROVIDED => CUSTOM.TRIM_FREE_SPACE.?,
                            .INFERED_BY_RECIPE => |fn_tag| if (!ALLOW_INFERED) unusable else switch (fn_tag) {
                                .infer_get_set_cap => infer_get_set_cap,
                                else => unreachable,
                            },
                        };
                        fn infer_get_set_cap(data: DATA_, free_space_to_keep: COUNT_, userdata: USERDATA_) DATA_ {
                            const len = GET_LEN.func(data, userdata);
                            const cap = GET_CAP.func(data, userdata);
                            const space = cap - len;
                            if (space <= free_space_to_keep) return data;
                            const new_cap = len + free_space_to_keep;
                            return SET_CAP.func(data, new_cap, userdata);
                        }
                        fn unusable(_: DATA_, _: COUNT_, _: USERDATA_) DATA_ {
                            assert_unreachable(@src(), "no `trim_free_space` function provided, no way to infer one from other provided funcs, and cannot use default fallback", .{});
                        }
                    };
                };

                return SELECTOR;
            }

            pub fn finalize(comptime FUNCS_: CORE_AND_FUNCS) type {
                return struct {
                    pub const DEF = CORE_;
                    pub const FUNCS = FUNCS_;
                    pub const DATA = DEF.DATA;
                    pub const ID = DEF.ID;
                    pub const ELEM = DEF.ELEM;
                    pub const COUNT = DEF.COUNT_INT;
                    pub const USERDATA = DEF.USERDATA;

                    pub const get_base_ptr: fn (DATA, USERDATA) [*]ELEM = FUNCS.GET_BASE_PTR;
                    pub const get_base_ptr_const: fn (DATA, USERDATA) [*]const ELEM = FUNCS.GET_BASE_CONST_PTR;
                    pub const set_base_ptr: fn (DATA, ptr: [*]ELEM, USERDATA) DATA = FUNCS.SET_BASE_PTR;
                    pub const get_len: fn (DATA, USERDATA) COUNT = FUNCS.GET_LEN;
                    pub const set_len: fn (DATA, new_len: COUNT, USERDATA) DATA = FUNCS.SET_LEN;
                    pub const get_cap: fn (DATA, USERDATA) COUNT = FUNCS.GET_CAP;
                    pub const set_cap: fn (DATA, new_cap: COUNT, USERDATA) DATA = FUNCS.SET_CAP;
                    pub const range_slice: fn (DATA, first: ID, last: ID, USERDATA) []ELEM = FUNCS.GET_RANGE_SLICE;
                    pub const range_slice_const: fn (DATA, first: ID, last: ID, USERDATA) []const ELEM = FUNCS.GET_RANGE_CONST_SLICE;

                    pub const get: fn (DATA, ID, USERDATA) ELEM = FUNCS.GET;
                    pub const get_ptr: fn (DATA, ID, USERDATA) *ELEM = FUNCS.GET_PTR;
                    pub const get_ptr_const: fn (DATA, ID, USERDATA) *const ELEM = FUNCS.GET_CONST_PTR;
                    pub const set: fn (DATA, ID, ELEM, USERDATA) DATA = FUNCS.SET;

                    pub const id_valid: fn (DATA, ID, USERDATA) bool = FUNCS.ID_VALID;
                    pub const invalid_id_after_last_id: fn (DATA, USERDATA) ID = FUNCS.INVALID_ID_AFTER_LAST_ID;
                    pub const invalid_id_before_first_id: fn (DATA, USERDATA) ID = FUNCS.INVALID_ID_BEFORE_FIRST_ID;
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
                    pub const limit_len: fn (DATA, start: ID, end_excluded: ID, USERDATA) COUNT = FUNCS.LIMIT_LEN;

                    pub const less_than: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.LESS_THAN;
                    pub const less_than_or_equal: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.LESS_THAN_OR_EQUAL;
                    pub const greater_than: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.GREATER_THAN;
                    pub const greater_than_or_equal: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.GREATER_THAN_OR_EQUAL;
                    pub const order_equals: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.ORDER_EQUALS;
                    pub const exact_equals: fn (a: ELEM, b: ELEM, USERDATA) bool = FUNCS.EXACT_EQUALS;

                    pub const swap: fn (DATA, a: ID, b: ID, USERDATA) DATA = FUNCS.SWAP;
                    pub const reverse_range: fn (DATA, first: ID, last: ID, USERDATA) DATA = FUNCS.REVERSE_RANGE;
                    pub const rotate_range_left: fn (DATA, first: ID, last: ID, n: COUNT, USERDATA) DATA = FUNCS.ROTATE_LEFT;
                    pub const rotate_range_right: fn (DATA, first: ID, last: ID, n: COUNT, USERDATA) DATA = FUNCS.ROTATE_RIGHT;
                    pub const move_one_overwrite: fn (DATA, old_id: ID, new_id: ID, USERDATA) DATA = FUNCS.MOVE_ONE_OVERWRITE;
                    pub const move_one_right_displace: fn (DATA, old_id: ID, new_id: ID, USERDATA) DATA = FUNCS.MOVE_ONE_RIGHT_DISPLACE;
                    pub const move_one_left_displace: fn (DATA, old_id: ID, new_id: ID, USERDATA) DATA = FUNCS.MOVE_ONE_LEFT_DISPLACE;
                    pub const move_range_right_displace: fn (DATA, old_first: ID, old_last: ID, new_first: ID, USERDATA) DATA = FUNCS.MOVE_RANGE_RIGHT_DISPLACE;
                    pub const move_range_left_displace: fn (DATA, old_first: ID, old_last: ID, new_first: ID, USERDATA) DATA = FUNCS.MOVE_RANGE_LEFT_DISPLACE;
                    pub const move_range_right_overwrite: fn (DATA, first: ID, last: ID, n_positions: COUNT, USERDATA) DATA = FUNCS.MOVE_RANGE_RIGHT_OVERWRITE;
                    pub const move_range_left_overwrite: fn (DATA, first: ID, last: ID, n_positions: COUNT, USERDATA) DATA = FUNCS.MOVE_RANGE_LEFT_OVERWRITE;
                    pub const scramble: fn (DATA, rand: Random, first: ID, last: ID, iterations: COUNT, USERDATA) DATA = FUNCS.SCRAMBLE;

                    pub const ensure_free_space: fn (DATA, free_space_needed: COUNT, USERDATA) DATA = FUNCS.ENSURE_FREE_SPACE;
                    pub const trim_free_space: fn (DATA, free_space_to_keep: COUNT, USERDATA) DATA = FUNCS.TRIM_FREE_SPACE;

                    pub const append_one_slot_assume_capacity: fn (DATA, USERDATA) struct { DATA, ID } = FUNCS.APPEND_ONE_SLOT_ASSUME_CAP;
                    pub const append_many_slots_assume_capacity: fn (DATA, count: COUNT, USERDATA) struct { DATA, ID, ID } = FUNCS.APPEND_MANY_SLOTS_ASSUME_CAP;
                    pub const insert_one_slot_before_assume_capacity: fn (DATA, at_id: ID, USERDATA) struct { DATA, ID } = FUNCS.INSERT_ONE_SLOT_BEFORE_ASSUME_CAP;
                    pub const insert_many_slots_before_assume_capacity: fn (DATA, at_id: ID, count: COUNT, USERDATA) struct { DATA, ID, ID } = FUNCS.INSERT_MANY_SLOTS_BEFORE_ASSUME_CAP;
                    pub const prepend_one_slot_assume_capacity: fn (DATA, USERDATA) struct { DATA, ID } = FUNCS.PREPEND_ONE_SLOT_ASSUME_CAP;
                    pub const prepend_many_slots_assume_capacity: fn (DATA, count: COUNT, USERDATA) struct { DATA, ID, ID } = FUNCS.PREPEND_MANY_SLOTS_ASSUME_CAP;
                    pub const delete_one: fn (DATA, id: ID, USERDATA) DATA = FUNCS.DELETE_ONE;
                    pub const delete_range: fn (DATA, first: ID, last: ID, USERDATA) DATA = FUNCS.DELETE_RANGE;

                    pub const tree = struct {
                        pub const first_child: fn (DATA, id: ID, exact_num_children_per_element: COUNT, USERDATA) ID = FUNCS.FIRST_CHILD_ID;
                        pub const last_child: fn (DATA, id: ID, exact_num_children_per_element: COUNT, USERDATA) ID = FUNCS.LAST_CHILD_ID;
                        pub const nth_child: fn (DATA, id: ID, nth: COUNT, exact_num_children_per_element: COUNT, USERDATA) ID = FUNCS.NTH_CHILD_ID;
                        pub const parent_id: fn (DATA, child_id: ID, exact_num_children_per_element: COUNT, USERDATA) ID = FUNCS.PARENT_ID;
                    };

                    pub fn entire_slice(data: DATA, userdata: USERDATA) []ELEM {
                        return range_slice(data, first_id(data, userdata), last_id(data, userdata), userdata);
                    }
                    pub fn entire_slice_const(data: DATA, userdata: USERDATA) []const ELEM {
                        return range_slice_const(data, first_id(data, userdata), last_id(data, userdata), userdata);
                    }
                    pub fn slice_of_first_n(data: DATA, count: COUNT, userdata: USERDATA) []ELEM {
                        const first = first_id(data, userdata);
                        if (count == 0) {
                            @branchHint(.unlikely);
                            return range_slice(data, first, first, userdata)[0..0];
                        }
                        const nth_id = nth_id_from_start(data, count - 1, userdata);
                        return range_slice(data, first, nth_id, userdata);
                    }
                    pub fn slice_of_first_n_const(data: DATA, count: COUNT, userdata: USERDATA) []const ELEM {
                        const first = first_id(data, userdata);
                        if (count == 0) {
                            @branchHint(.unlikely);
                            return range_slice_const(data, first, first, userdata)[0..0];
                        }
                        const nth_id = nth_id_from_start(data, count - 1, userdata);
                        return range_slice_const(data, first, nth_id, userdata);
                    }
                    pub fn slice_of_last_n(data: DATA, count: COUNT, userdata: USERDATA) []ELEM {
                        const last = last_id(data, userdata);
                        if (count == 0) {
                            @branchHint(.unlikely);
                            return range_slice(data, last, last, userdata)[0..0];
                        }
                        const nth_id = nth_id_from_end(data, count - 1, userdata);
                        return range_slice(data, nth_id, last, userdata);
                    }
                    pub fn slice_of_last_n_const(data: DATA, count: COUNT, userdata: USERDATA) []const ELEM {
                        const last = last_id(data, userdata);
                        if (count == 0) {
                            @branchHint(.unlikely);
                            return range_slice_const(data, last, last, userdata)[0..0];
                        }
                        const nth_id = nth_id_from_end(data, count - 1, userdata);
                        return range_slice_const(data, nth_id, last, userdata);
                    }
                    pub fn slice_start_to_id(data: DATA, id: ID, userdata: USERDATA) []ELEM {
                        const first = first_id(data, userdata);
                        return range_slice(data, first, id, userdata);
                    }
                    pub fn slice_start_to_id_const(data: DATA, id: ID, userdata: USERDATA) []const ELEM {
                        const first = first_id(data, userdata);
                        return range_slice_const(data, first, id, userdata);
                    }
                    pub fn slice_id_to_end(data: DATA, id: ID, userdata: USERDATA) []ELEM {
                        const last = last_id(data, userdata);
                        return range_slice(data, id, last, userdata);
                    }
                    pub fn slice_id_to_end_const(data: DATA, id: ID, userdata: USERDATA) []const ELEM {
                        const last = last_id(data, userdata);
                        return range_slice_const(data, id, last, userdata);
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
                        assert_id_less_than_or_equal_id(data, first, mid, userdata, src);
                        assert_id_less_than_or_equal_id(data, mid, last, userdata, src);
                    }

                    pub fn move_one_displace(data: DATA, old_id: ID, new_id: ID, userdata: USERDATA) DATA {
                        if (id_less_than_or_equal(data, old_id, new_id, userdata)) {
                            return move_one_right_displace(data, old_id, new_id, userdata);
                        } else {
                            return move_one_left_displace(data, old_id, new_id, userdata);
                        }
                    }
                    pub fn move_range_displace(data: DATA, old_first_id: ID, old_last_id: ID, new_first_id: ID, userdata: USERDATA) DATA {
                        if (id_less_than_or_equal(data, old_first_id, new_first_id, userdata)) {
                            return move_range_right_displace(data, old_first_id, old_last_id, new_first_id, userdata);
                        } else {
                            return move_range_left_displace(data, old_first_id, old_last_id, new_first_id, userdata);
                        }
                    }
                    pub fn append_one_slot(data: DATA, userdata: USERDATA) struct { DATA, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, 1, userdata);
                        return append_one_slot_assume_capacity(data_, userdata);
                    }
                    pub fn append_many_slots(data: DATA, count: COUNT, userdata: USERDATA) struct { DATA, ID, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, count, userdata);
                        return append_many_slots_assume_capacity(data_, count, userdata);
                    }
                    pub fn insert_one_slot_before(data: DATA, before_id: ID, userdata: USERDATA) struct { DATA, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, 1, userdata);
                        return insert_one_slot_before_assume_capacity(data_, before_id, userdata);
                    }
                    pub fn insert_many_slots_before(data: DATA, count: COUNT, userdata: USERDATA) struct { DATA, ID, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, count, userdata);
                        return insert_many_slots_before_assume_capacity(data_, count, userdata);
                    }
                    pub fn prepend_one_slot(data: DATA, userdata: USERDATA) struct { DATA, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, 1, userdata);
                        return prepend_one_slot_assume_capacity(data_, userdata);
                    }
                    pub fn prepend_many_slots(data: DATA, count: COUNT, userdata: USERDATA) struct { DATA, ID, ID } {
                        var data_ = data;
                        data_ = ensure_free_space(data, count, userdata);
                        return prepend_many_slots_assume_capacity(data_, count, userdata);
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

                    pub const IdElemPair = struct { ID, ELEM };

                    pub fn median_of_3(data: DATA, ids_: [3]ID, userdata: USERDATA) IdElemPair {
                        var ids = ids_;
                        var tmp: ID = undefined;
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

                    pub fn is_sorted(data: DATA, first: ID, last: ID, userdata: USERDATA) bool {
                        if (get_len(data, userdata) == 0) {
                            @branchHint(.unlikely);
                            return true;
                        }
                        assert_valid_range(data, first, last, userdata, @src());
                        if (id_equals(data, first, last, userdata)) return true;
                        var next_id_to_check = next_id(data, first, userdata);
                        var val_left: ELEM = get(data, first, userdata);
                        var val_right: ELEM = undefined;
                        while (true) {
                            val_right = get(data, next_id_to_check, userdata);
                            if (greater_than(val_left, val_right, userdata)) return false;
                            if (id_equals(data, next_id_to_check, last, userdata)) {
                                @branchHint(.unlikely);
                                return true;
                            }
                            val_left = val_right;
                            next_id_to_check = next_id(data, next_id_to_check, userdata);
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
                    pub fn insertion_sort(data_: DATA, userdata: USERDATA) DATA {
                        const first = first_id(data_, userdata);
                        const last = last_id(data_, userdata);
                        return insertion_sort_range(data_, first, last, userdata);
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
                    pub fn insertion_sort_range(data_: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        if (get_len(data_, userdata) == 0) {
                            @branchHint(.unlikely);
                            return data_;
                        }
                        assert_valid_range(data_, first, last, userdata, @src());
                        if (id_equals(data_, first, last, userdata)) {
                            @branchHint(.unlikely);
                            return data_;
                        }
                        var id_to_sort: ID = next_id(data_, first, userdata);
                        var id_right: ID = undefined;
                        var id_left: ID = undefined;
                        var val_to_sort: ELEM = undefined;
                        var data = data_;
                        while (true) {
                            val_to_sort = get(data, id_to_sort, userdata);
                            id_right = id_to_sort;
                            inner: while (true) {
                                id_left = prev_id(data, id_right, userdata);
                                const val_left = get(data, id_left, userdata);
                                if (greater_than(val_left, val_to_sort, userdata)) {
                                    data = set(data, id_right, val_left, userdata);
                                    id_right = id_left;
                                } else {
                                    break :inner;
                                }
                                if (id_equals(data, id_left, first, userdata)) {
                                    @branchHint(.unlikely);
                                    break :inner;
                                }
                            }
                            data = set(data, id_right, val_to_sort, userdata);
                            if (id_equals(data, id_to_sort, last, userdata)) {
                                @branchHint(.unlikely);
                                return data;
                            }
                            id_to_sort = next_id(data, id_to_sort, userdata);
                        }
                    }

                    fn assert_stack_can_support_sort_len(comptime SETTINGS: QuicksortSettings, data: DATA, first: ID, last: ID, userdata: USERDATA, comptime src: SourceLocation) void {
                        const data_len = range_len(data, first, last, userdata);
                        const needed_stack_len: u8 = @intCast(std.math.log2_int(COUNT, data_len) + 1);
                        assert_with_reason(SETTINGS.QUICKSORT_MAX_STACK >= needed_stack_len, src, "the provided `.QUICKSORT_MAX_STACK` setting ({d}) is too small, need stack len {d} for given the data len {d}", .{ SETTINGS.QUICKSORT_MAX_STACK, needed_stack_len, data_len });
                    }

                    pub fn QuicksortPartition(comptime DEGENERATE_FALLBACK: bool) type {
                        return struct {
                            lo_idx: ID,
                            hi_idx: ID,
                            budget: if (DEGENERATE_FALLBACK) COUNT else void = if (DEGENERATE_FALLBACK) undefined else void{},

                            pub fn new(lo: ID, hi: ID, budget: COUNT) @This() {
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
                    ///   - User can choose a partition scheme based on stated expectations about items with equal order
                    ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
                    ///     - Many items same order unlikely = 2-way Hoare scheme
                    ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
                    ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
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
                    pub fn quicksort(data_: DATA, userdata: USERDATA, comptime SETTINGS: QuicksortSettings) DATA {
                        const first = first_id(data_, userdata);
                        const last = last_id(data_, userdata);
                        return quicksort_range(data_, first, last, userdata, SETTINGS);
                    }

                    /// Quicksort using a number of optimizations (similar to Introsort):
                    ///   - Use Insertion Sort when partitions become small
                    ///   - Median-of-three pivot (not random, always first, middle, last)
                    ///   - User can choose a partition scheme based on stated expectations about items with equal order
                    ///     - Unknown likelyhood of equal order items = Start with 2-way, but if many duplicates are detected change to 3-way
                    ///     - Many items same order unlikely = 2-way Hoare scheme
                    ///     - Many items same order likely = 3-way 'Dutch National Flag' scheme
                    ///   - No recursion, only a comptime sized stack of partition index ranges and a while loop
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
                    pub fn quicksort_range(data_: DATA, first: ID, last: ID, userdata: USERDATA, comptime SETTINGS: QuicksortSettings) DATA {
                        if (get_len(data_, userdata) == 0) {
                            @branchHint(.unlikely);
                            return data_;
                        }
                        assert_valid_range(data_, first, last, userdata, @src());
                        if (id_equals(data_, first, last, userdata)) return data_;
                        assert_stack_can_support_sort_len(SETTINGS, data_, first, last, userdata, @src());
                        const Partition = QuicksortPartition(SETTINGS.FALLBACK_WHEN_DEGENERATE);
                        const len = range_len(data_, first, last, userdata);
                        const degenerate_limit: COUNT = if (comptime SETTINGS.FALLBACK_WHEN_DEGENERATE) (SETTINGS.DEGENERATE_DETECTION_FACTOR * @as(COUNT, @intCast(math.log2_int(COUNT, len)))) else math.maxInt(COUNT);
                        var data = data_;
                        var stack: [SETTINGS.QUICKSORT_MAX_STACK]Partition = undefined;
                        stack[0] = Partition.new(first, last, degenerate_limit);
                        var stack_len: u8 = 1;
                        var force_3_way = if (SETTINGS.SAME_ORDER_EXPECTATIONS == .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY) false else void{};
                        var force_3_way_counter = if (SETTINGS.SAME_ORDER_EXPECTATIONS == .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY) @as(COUNT, 0) else void{};
                        next_partition: while (stack_len > 0) {
                            @branchHint(.likely);
                            stack_len -= 1;
                            const part = stack[stack_len];
                            if (SETTINGS.FALLBACK_WHEN_DEGENERATE and part.budget <= 0) {
                                if (len <= SETTINGS.FALLBACK_WHEN_DEGENERATE_INSERTION_SORT_MAX_INPUT_LEN) {
                                    return insertion_sort_range(data, first, last, userdata);
                                } else {
                                    return heapsort_range(data, first, last, userdata);
                                }
                            }
                            assert_with_reason(!part.empty(data, userdata), @src(), "it should be impossible to have an empty partition here", .{});
                            if (part.len(data, userdata) <= SETTINGS.QUICKSORT_TO_INSERTION_THRESHOLD) {
                                data = insertion_sort_range(data, part.lo_idx, part.hi_idx, userdata);
                                continue :next_partition;
                            }
                            data, const pivot = switch (comptime SETTINGS.SAME_ORDER_EXPECTATIONS) {
                                .MANY_ITEMS_WITH_SAME_ORDER_LIKELY, .USE_DUTCH_FLAG_3_WAY_PARTITION => quicksort_partition_dutch_flag(data, part.lo_idx, part.hi_idx, userdata),
                                .MANY_ITEMS_WITH_SAME_ORDER_RARE_OR_IMPOSSIBLE, .USE_HOARE_2_WAY_PARTITION => sort_partition_hoare(data, part.lo_idx, part.hi_idx, userdata, false),
                                .DYNAMIC_BASED_ON_SAME_ORDER_DENSITY => blk: {
                                    if (force_3_way) {
                                        break :blk quicksort_partition_dutch_flag(data, part.lo_idx, part.hi_idx, userdata);
                                    } else {
                                        const res = sort_partition_hoare(data, part.lo_idx, part.hi_idx, userdata, true);
                                        const parent_len_float: f32 = @floatFromInt(part.len(data, userdata));
                                        const dupes_float: f32 = @floatFromInt(res.@"2");
                                        const density = dupes_float / parent_len_float;
                                        if (density >= SETTINGS.DYNAMIC_PARTITION_SWAP_TO_3_WAY_THRESHOLD) {
                                            force_3_way_counter += 1;
                                            if (force_3_way_counter > SETTINGS.DYNAMIC_PARTITION_SWAP_TO_3_WAY_MAX_COUNT) {
                                                force_3_way = true;
                                            }
                                        }
                                        break :blk .{ res.@"0", res.@"1" };
                                    }
                                },
                            };
                            const left_partition = Partition.new(part.lo_idx, pivot.sub_partition_left_hi, part.budget - 1);
                            const right_partition = Partition.new(pivot.sub_partition_right_lo, part.hi_idx, part.budget - 1);
                            const left_len = left_partition.len(data, userdata);
                            const right_len = right_partition.len(data, userdata);
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

                    fn sort_partition_median_of_3(data: DATA, first: ID, last: ID, userdata: USERDATA) IdElemPair {
                        const len = range_len(data, first, last, userdata);
                        const mid = nth_next_id(data, first, (len >> 1), userdata);
                        const unsorted_ids = [3]ID{ first, mid, last };
                        return median_of_3(data, unsorted_ids, userdata);
                    }

                    fn sort_partition_hoare(data_: DATA, first: ID, last: ID, userdata: USERDATA, comptime COUNT_PIVOT_DUPES: bool) if (COUNT_PIVOT_DUPES) struct { DATA, PartitionResult, COUNT } else struct { DATA, PartitionResult } {
                        const median_idx, const pivot_item = sort_partition_median_of_3(data_, first, last, userdata);
                        var data = swap_already_have_b(data_, first, median_idx, pivot_item, userdata);
                        var left_id = first;
                        var right_id = last;
                        var left_item: ELEM = undefined;
                        var right_item: ELEM = undefined;
                        var pivot_dupes: if (COUNT_PIVOT_DUPES) COUNT else void = if (COUNT_PIVOT_DUPES) 0 else {};
                        while (true) {
                            left_item = get(data, left_id, userdata);
                            while (less_than(left_item, pivot_item, userdata)) {
                                left_id = next_id(data, left_id, userdata);
                                left_item = get(data, left_id, userdata);
                            }
                            if (comptime COUNT_PIVOT_DUPES) {
                                const is_dupe = order_equals(left_item, pivot_item, userdata);
                                pivot_dupes += @as(COUNT, @intCast(@intFromBool(is_dupe)));
                            }
                            right_item = get(data, right_id, userdata);
                            while (greater_than(right_item, pivot_item, userdata)) {
                                right_id = prev_id(data, right_id, userdata);
                                right_item = get(data, right_id, userdata);
                            }
                            if (comptime COUNT_PIVOT_DUPES) {
                                const is_dupe = order_equals(right_item, pivot_item, userdata);
                                pivot_dupes += @as(COUNT, @intCast(@intFromBool(is_dupe)));
                            }
                            if (id_greater_than_or_equal(data, left_id, right_id, userdata)) break;
                            data = set(data, left_id, right_item, userdata);
                            data = set(data, right_id, left_item, userdata);
                            left_id = next_id(data, left_id, userdata);
                            right_id = prev_id(data, right_id, userdata);
                        }
                        if (comptime COUNT_PIVOT_DUPES) {
                            return .{
                                data,
                                PartitionResult{
                                    .sub_partition_left_hi = right_id,
                                    .sub_partition_right_lo = next_id(data, right_id, userdata),
                                },
                                pivot_dupes,
                            };
                        } else {
                            return .{
                                data,
                                PartitionResult{
                                    .sub_partition_left_hi = right_id,
                                    .sub_partition_right_lo = next_id(data, right_id, userdata),
                                },
                            };
                        }
                    }

                    fn quicksort_partition_dutch_flag(data_: DATA, first: ID, last: ID, userdata: USERDATA) struct { DATA, PartitionResult } {
                        const median_idx, const pivot_item = sort_partition_median_of_3(data_, first, last, userdata);
                        var data = swap_already_have_b(data_, first, median_idx, pivot_item, userdata);
                        var smallest_id_with_same_order_as_pivot = first;
                        var check_id = first;
                        var largest_id_with_same_order_as_pivot = last;
                        while (id_less_than(data, check_id, largest_id_with_same_order_as_pivot, userdata)) {
                            const check_item = get(data, check_id, userdata);
                            if (less_than(check_item, pivot_item, userdata)) {
                                data = swap_already_have_b(data, smallest_id_with_same_order_as_pivot, check_id, check_item, userdata);
                                smallest_id_with_same_order_as_pivot = next_id(data, smallest_id_with_same_order_as_pivot, userdata);
                                check_id = next_id(data, check_id, userdata);
                            } else if (less_than(pivot_item, check_item, userdata)) {
                                data = swap_already_have_b(data, largest_id_with_same_order_as_pivot, check_id, check_item, userdata);
                                largest_id_with_same_order_as_pivot = prev_id(data, largest_id_with_same_order_as_pivot, userdata);
                            } else {
                                check_id = next_id(data, check_id, userdata);
                            }
                        }
                        return .{ data, PartitionResult{
                            .sub_partition_left_hi = prev_id(data, smallest_id_with_same_order_as_pivot, userdata),
                            .sub_partition_right_lo = next_id(data, largest_id_with_same_order_as_pivot, userdata),
                        } };
                    }

                    pub fn max_heap_sift_down_with_range(data: DATA, heap_first: ID, heap_last: ID, heap_len: COUNT, id: ID, id_n: COUNT, userdata: USERDATA) DATA {
                        return any_heap_sift_down_with_range(.MAX_HEAP, data, heap_first, heap_last, heap_len, id, id_n, userdata);
                    }
                    pub fn min_heap_sift_down_with_range(data: DATA, heap_first: ID, heap_last: ID, heap_len: COUNT, id: ID, id_n: COUNT, userdata: USERDATA) DATA {
                        return any_heap_sift_down_with_range(.MIN_HEAP, data, heap_first, heap_last, heap_len, id, id_n, userdata);
                    }
                    // TODO more heap operations
                    fn any_heap_sift_down_with_range(comptime kind: HeapKind, data_: DATA, heap_first: ID, heap_last: ID, heap_len: COUNT, id: ID, id_n: COUNT, userdata: USERDATA) DATA {
                        assert_valid_range_3(data_, heap_first, id, heap_last, userdata, @src());
                        var data = data_;
                        var target_id = id;
                        var target_id_n = id_n;
                        const target_val = get(data, target_id, userdata);
                        const max_n_no_left_child_overflow = math.maxInt(COUNT) >> 1;
                        const max_n_no_right_child_overflow = max_n_no_left_child_overflow - 1;
                        while (true) {
                            var extreme_val_id = target_id;
                            var extreme_val_id_n = target_id_n;
                            var extreme_val = target_val;
                            if (target_id_n <= max_n_no_left_child_overflow) {
                                @branchHint(.likely);
                                const left_child_id_n = (target_id_n << 1) | 1; // same as (target_id_n * 2) + 1
                                if (left_child_id_n < heap_len) {
                                    const left_child_id = nth_next_id(data, heap_first, left_child_id_n, userdata);
                                    const left_child_val = get(data, left_child_id, userdata);
                                    switch (comptime kind) {
                                        .MAX_HEAP => {
                                            if (greater_than(left_child_val, extreme_val, userdata)) {
                                                extreme_val_id = left_child_id;
                                                extreme_val_id_n = left_child_id_n;
                                                extreme_val = left_child_val;
                                            }
                                        },
                                        .MIN_HEAP => {
                                            if (less_than(left_child_val, extreme_val, userdata)) {
                                                extreme_val_id = left_child_id;
                                                extreme_val_id_n = left_child_id_n;
                                                extreme_val = left_child_val;
                                            }
                                        },
                                    }
                                    if (target_id_n <= max_n_no_right_child_overflow) {
                                        @branchHint(.likely);
                                        const right_child_id_n = left_child_id_n + 1;
                                        if (right_child_id_n < heap_len) {
                                            const right_child_id = next_id(data, left_child_id, userdata);
                                            const right_child_val = get(data, right_child_id, userdata);
                                            switch (comptime kind) {
                                                .MAX_HEAP => {
                                                    if (greater_than(right_child_val, extreme_val, userdata)) {
                                                        extreme_val_id = right_child_id;
                                                        extreme_val_id_n = right_child_id_n;
                                                        extreme_val = right_child_val;
                                                    }
                                                },
                                                .MIN_HEAP => {
                                                    if (less_than(right_child_val, extreme_val, userdata)) {
                                                        extreme_val_id = right_child_id;
                                                        extreme_val_id_n = right_child_id_n;
                                                        extreme_val = right_child_val;
                                                    }
                                                },
                                            }
                                        }
                                    }
                                }
                            }
                            if (id_equals(data, extreme_val_id, target_id, userdata)) break; // target val in correct place
                            // swap most extreme and target and update target id
                            data = set(data, extreme_val_id, target_val, userdata);
                            data = set(data, target_id, extreme_val, userdata);
                            target_id = extreme_val_id;
                            target_id_n = extreme_val_id_n;
                        }
                        return data;
                    }

                    fn build_any_heap_within_range(comptime kind: HeapKind, data_: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        var data = data_;
                        const heap_len = range_len(data, first, last, userdata);
                        if (heap_len < 2) return data;
                        var curr_parent_node_n = ((heap_len - 2) >> 1) + 1;
                        var curr_parent_node = nth_next_id(data, first, curr_parent_node_n, userdata);
                        while (curr_parent_node_n > 0) {
                            curr_parent_node_n -= 1;
                            curr_parent_node = prev_id(data, curr_parent_node, userdata);
                            data = any_heap_sift_down_with_range(kind, data, first, last, heap_len, curr_parent_node, curr_parent_node_n, userdata);
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

                    fn is_range_any_heap(comptime mode: HeapKind, data: DATA, first: ID, last: ID, userdata: USERDATA) bool {
                        var node: ID = first;
                        var node_n: COUNT = 0;
                        const len = range_len(data, first, last, userdata);
                        const half_len = len >> 1;
                        while (node_n <= half_len) : ({
                            node_n += 1;
                            node = next_id(data, node, userdata);
                        }) {
                            const child_left_node_n = (node_n << 1) | 1;
                            if (child_left_node_n >= len) continue;
                            const node_val = get(data, node, userdata);
                            const child_left_node = nth_next_id(data, first, child_left_node_n, userdata);
                            const child_left_val = get(data, child_left_node, userdata);
                            switch (mode) {
                                .MIN_HEAP => {
                                    if (less_than(child_left_val, node_val, userdata)) return false;
                                },
                                .MAX_HEAP => {
                                    if (greater_than(child_left_val, node_val, userdata)) return false;
                                },
                            }
                            const child_right_node_n = child_left_node_n +| 1;
                            if (child_right_node_n >= len) continue;
                            const child_right_node = next_id(data, child_left_node, userdata);
                            const child_right_val = get(data, child_right_node, userdata);
                            switch (mode) {
                                .MIN_HEAP => {
                                    if (less_than(child_right_val, node_val, userdata)) return false;
                                },
                                .MAX_HEAP => {
                                    if (greater_than(child_right_val, node_val, userdata)) return false;
                                },
                            }
                        }
                        return true;
                    }
                    pub fn is_range_max_heap(data: DATA, first: ID, last: ID, userdata: USERDATA) bool {
                        return is_range_any_heap(.MAX_HEAP, data, first, last, userdata);
                    }
                    pub fn is_range_min_heap(data: DATA, first: ID, last: ID, userdata: USERDATA) bool {
                        return is_range_any_heap(.MIN_HEAP, data, first, last, userdata);
                    }
                    pub fn assert_range_is_max_heap(data: DATA, first: ID, last: ID, userdata: USERDATA) void {
                        assert_with_reason(is_range_max_heap(data, first, last, userdata), @src(), "data structure is not a max-heap within range [{any} => {any}]\n{any}", .{ first, last, data });
                    }
                    pub fn assert_range_is_min_heap(data: DATA, first: ID, last: ID, userdata: USERDATA) void {
                        assert_with_reason(is_range_min_heap(data, first, last, userdata), @src(), "data structure is not a min-heap within range [{any} => {any}]\n{any}", .{ first, last, data });
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
                    pub fn heapsort(data_: DATA, userdata: USERDATA) DATA {
                        const first = first_id(data_, userdata);
                        const last = last_id(data_, userdata);
                        return heapsort_range(data_, first, last, userdata);
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
                    pub fn heapsort_range(data_: DATA, first: ID, last: ID, userdata: USERDATA) DATA {
                        if (get_len(data_, userdata) < 2) {
                            @branchHint(.unlikely);
                            return data_;
                        }
                        assert_valid_range(data_, first, last, userdata, @src());
                        var heap_len = range_len(data_, first, last, userdata);
                        var data = build_max_heap_within_range(data_, first, last, userdata);
                        var heap_last = last;
                        while (heap_len > 1) {
                            data = swap(data, heap_last, first, userdata);
                            heap_last = prev_id(data, heap_last, userdata);
                            heap_len -= 1;
                            data = max_heap_sift_down_with_range(data, first, heap_last, heap_len, first, 0, userdata);
                        }
                        return data;
                    }

                    const PartitionResult = struct {
                        sub_partition_left_hi: ID,
                        sub_partition_right_lo: ID,
                    };
                };
            }
        };
    }
};

const SORT_TEST_CASES = struct {
    pub const Case = struct {
        input: []const u8,
        expected_output: []const u8,
    };
    const BlindElem = TEST_UTILS.BLIND.ELEM;
    pub const BlindCase = struct {
        input: []const BlindElem,
        expected_output: []const BlindElem,
    };
    fn U8_TO_BLIND(comptime U8_ARR: type) type {
        return [@typeInfo(U8_ARR).array.len]BlindElem;
    }
    fn MakeBlind(u8_arr: anytype) U8_TO_BLIND(@TypeOf(u8_arr)) {
        var out: U8_TO_BLIND(@TypeOf(u8_arr)) = undefined;
        for (u8_arr[0..], 0..) |val, i| {
            out[i] = BlindElem.new(@intCast(val));
        }
        return out;
    }

    const in01 = [_]u8{};
    const ex01 = [_]u8{};
    const b_in01 = MakeBlind(in01);
    const b_ex01 = MakeBlind(ex01);

    const in02 = [_]u8{42};
    const ex02 = [_]u8{42};
    const b_in02 = MakeBlind(in02);
    const b_ex02 = MakeBlind(ex02);

    const in03 = [_]u8{ 1, 2 };
    const ex03 = [_]u8{ 1, 2 };
    const b_in03 = MakeBlind(in03);
    const b_ex03 = MakeBlind(ex03);

    const in04 = [_]u8{ 2, 1 };
    const ex04 = [_]u8{ 1, 2 };
    const b_in04 = MakeBlind(in04);
    const b_ex04 = MakeBlind(ex04);

    const in05 = [_]u8{ 7, 7 };
    const ex05 = [_]u8{ 7, 7 };
    const b_in05 = MakeBlind(in05);
    const b_ex05 = MakeBlind(ex05);

    const in06 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const ex06 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b_in06 = MakeBlind(in06);
    const b_ex06 = MakeBlind(ex06);

    const in07 = [_]u8{ 8, 7, 6, 5, 4, 3, 2, 1 };
    const ex07 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b_in07 = MakeBlind(in07);
    const b_ex07 = MakeBlind(ex07);

    const in08 = [_]u8{ 0, 0, 0, 0, 0 };
    const ex08 = [_]u8{ 0, 0, 0, 0, 0 };
    const b_in08 = MakeBlind(in08);
    const b_ex08 = MakeBlind(ex08);

    const in09 = [_]u8{ 255, 255, 255, 255, 255 };
    const ex09 = [_]u8{ 255, 255, 255, 255, 255 };
    const b_in09 = MakeBlind(in09);
    const b_ex09 = MakeBlind(ex09);

    const in10 = [_]u8{ 0, 255, 0, 255, 0, 255, 0, 255 };
    const ex10 = [_]u8{ 0, 0, 0, 0, 255, 255, 255, 255 };
    const b_in10 = MakeBlind(in10);
    const b_ex10 = MakeBlind(ex10);

    const in11 = [_]u8{ 255, 0, 128, 0, 255, 128 };
    const ex11 = [_]u8{ 0, 0, 128, 128, 255, 255 };
    const b_in11 = MakeBlind(in11);
    const b_ex11 = MakeBlind(ex11);

    const in12 = [_]u8{ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 };
    const ex12 = [_]u8{ 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 };
    const b_in12 = MakeBlind(in12);
    const b_ex12 = MakeBlind(ex12);

    const in13 = [_]u8{ 1, 2, 1, 2, 1, 2, 1, 2 };
    const ex13 = [_]u8{ 1, 1, 1, 1, 2, 2, 2, 2 };
    const b_in13 = MakeBlind(in13);
    const b_ex13 = MakeBlind(ex13);

    const in14 = [_]u8{ 3, 1, 2, 3, 1, 2, 3, 1, 2, 3 };
    const ex14 = [_]u8{ 1, 1, 1, 2, 2, 2, 3, 3, 3, 3 };
    const b_in14 = MakeBlind(in14);
    const b_ex14 = MakeBlind(ex14);

    const in15 = [_]u8{ 9, 9, 9, 1, 9, 9, 9, 9, 9, 9 };
    const ex15 = [_]u8{ 1, 9, 9, 9, 9, 9, 9, 9, 9, 9 };
    const b_in15 = MakeBlind(in15);
    const b_ex15 = MakeBlind(ex15);

    const in16 = [_]u8{ 9, 1, 2, 3, 4, 5, 6, 7, 8 };
    const ex16 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const b_in16 = MakeBlind(in16);
    const b_ex16 = MakeBlind(ex16);

    const in17 = [_]u8{ 2, 3, 4, 5, 6, 7, 8, 9, 1 };
    const ex17 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const b_in17 = MakeBlind(in17);
    const b_ex17 = MakeBlind(ex17);

    const in18 = [_]u8{ 1, 2, 3, 5, 4, 6, 7, 8 };
    const ex18 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b_in18 = MakeBlind(in18);
    const b_ex18 = MakeBlind(ex18);

    const in19 = [_]u8{ 1, 3, 5, 7, 8, 6, 4, 2 };
    const ex19 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b_in19 = MakeBlind(in19);
    const b_ex19 = MakeBlind(ex19);

    const in20 = [_]u8{ 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3 };
    const ex20 = [_]u8{ 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 };
    const b_in20 = MakeBlind(in20);
    const b_ex20 = MakeBlind(ex20);

    const in21 = [_]u8{ 5, 6, 7, 8, 1, 2, 3, 4 };
    const ex21 = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b_in21 = MakeBlind(in21);
    const b_ex21 = MakeBlind(ex21);

    const in22 = [_]u8{ 200, 100, 100, 100, 100, 100, 50 };
    const ex22 = [_]u8{ 50, 100, 100, 100, 100, 100, 200 };
    const b_in22 = MakeBlind(in22);
    const b_ex22 = MakeBlind(ex22);

    const in23 = [_]u8{ 10, 30, 20, 10, 30, 20, 10, 30, 20 };
    const ex23 = [_]u8{ 10, 10, 10, 20, 20, 20, 30, 30, 30 };
    const b_in23 = MakeBlind(in23);
    const b_ex23 = MakeBlind(ex23);

    const in24 = [_]u8{
        32, 31, 30, 29, 28, 27, 26, 25,
        24, 23, 22, 21, 20, 19, 18, 17,
        16, 15, 14, 13, 12, 11, 10, 9,
        8,  7,  6,  5,  4,  3,  2,  1,
    };
    const ex24 = [_]u8{
        1,  2,  3,  4,  5,  6,  7,  8,
        9,  10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
    };
    const b_in24 = MakeBlind(in24);
    const b_ex24 = MakeBlind(ex24);

    const in25 = [_]u8{
        255, 254, 253, 252, 251, 250, 249, 248,
        247, 246, 245, 244, 243, 242, 241, 240,
        128, 127, 126, 125, 3,   2,   1,   0,
    };
    const ex25 = [_]u8{
        0,   1,   2,   3,   125, 126, 127, 128,
        240, 241, 242, 243, 244, 245, 246, 247,
        248, 249, 250, 251, 252, 253, 254, 255,
    };
    const b_in25 = MakeBlind(in25);
    const b_ex25 = MakeBlind(ex25);

    const CASES = [_]Case{
        Case{ .input = in01[0..], .expected_output = ex01[0..] },
        Case{ .input = in02[0..], .expected_output = ex02[0..] },
        Case{ .input = in03[0..], .expected_output = ex03[0..] },
        Case{ .input = in04[0..], .expected_output = ex04[0..] },
        Case{ .input = in05[0..], .expected_output = ex05[0..] },
        Case{ .input = in06[0..], .expected_output = ex06[0..] },
        Case{ .input = in07[0..], .expected_output = ex07[0..] },
        Case{ .input = in08[0..], .expected_output = ex08[0..] },
        Case{ .input = in09[0..], .expected_output = ex09[0..] },
        Case{ .input = in10[0..], .expected_output = ex10[0..] },
        Case{ .input = in11[0..], .expected_output = ex11[0..] },
        Case{ .input = in12[0..], .expected_output = ex12[0..] },
        Case{ .input = in13[0..], .expected_output = ex13[0..] },
        Case{ .input = in14[0..], .expected_output = ex14[0..] },
        Case{ .input = in15[0..], .expected_output = ex15[0..] },
        Case{ .input = in16[0..], .expected_output = ex16[0..] },
        Case{ .input = in17[0..], .expected_output = ex17[0..] },
        Case{ .input = in18[0..], .expected_output = ex18[0..] },
        Case{ .input = in19[0..], .expected_output = ex19[0..] },
        Case{ .input = in20[0..], .expected_output = ex20[0..] },
        Case{ .input = in21[0..], .expected_output = ex21[0..] },
        Case{ .input = in22[0..], .expected_output = ex22[0..] },
        Case{ .input = in23[0..], .expected_output = ex23[0..] },
        Case{ .input = in24[0..], .expected_output = ex24[0..] },
        Case{ .input = in25[0..], .expected_output = ex25[0..] },
    };
    const BLIND_CASES = [_]BlindCase{
        BlindCase{ .input = b_in01[0..], .expected_output = b_ex01[0..] },
        BlindCase{ .input = b_in02[0..], .expected_output = b_ex02[0..] },
        BlindCase{ .input = b_in03[0..], .expected_output = b_ex03[0..] },
        BlindCase{ .input = b_in04[0..], .expected_output = b_ex04[0..] },
        BlindCase{ .input = b_in05[0..], .expected_output = b_ex05[0..] },
        BlindCase{ .input = b_in06[0..], .expected_output = b_ex06[0..] },
        BlindCase{ .input = b_in07[0..], .expected_output = b_ex07[0..] },
        BlindCase{ .input = b_in08[0..], .expected_output = b_ex08[0..] },
        BlindCase{ .input = b_in09[0..], .expected_output = b_ex09[0..] },
        BlindCase{ .input = b_in10[0..], .expected_output = b_ex10[0..] },
        BlindCase{ .input = b_in11[0..], .expected_output = b_ex11[0..] },
        BlindCase{ .input = b_in12[0..], .expected_output = b_ex12[0..] },
        BlindCase{ .input = b_in13[0..], .expected_output = b_ex13[0..] },
        BlindCase{ .input = b_in14[0..], .expected_output = b_ex14[0..] },
        BlindCase{ .input = b_in15[0..], .expected_output = b_ex15[0..] },
        BlindCase{ .input = b_in16[0..], .expected_output = b_ex16[0..] },
        BlindCase{ .input = b_in17[0..], .expected_output = b_ex17[0..] },
        BlindCase{ .input = b_in18[0..], .expected_output = b_ex18[0..] },
        BlindCase{ .input = b_in19[0..], .expected_output = b_ex19[0..] },
        BlindCase{ .input = b_in20[0..], .expected_output = b_ex20[0..] },
        BlindCase{ .input = b_in21[0..], .expected_output = b_ex21[0..] },
        BlindCase{ .input = b_in22[0..], .expected_output = b_ex22[0..] },
        BlindCase{ .input = b_in23[0..], .expected_output = b_ex23[0..] },
        BlindCase{ .input = b_in24[0..], .expected_output = b_ex24[0..] },
        BlindCase{ .input = b_in25[0..], .expected_output = b_ex25[0..] },
    };
    const LONGEST_CASE = find: {
        var longest: usize = 0;
        for (CASES[0..]) |case| {
            longest = @max(longest, case.input.len);
        }
        break :find longest;
    };
    const NUM_RANDOM_TESTS: usize = 50;
};

const TEST_UTILS = struct {
    const BLIND = struct {
        const DATA = struct {
            counter: u64 = 0,

            pub fn incr(self: DATA) DATA {
                return DATA{
                    .counter = self.counter + 1,
                };
            }
        };
        const USERDATA_CONCRETE = struct {
            ptr: [*]ELEM,
            len: COUNT = 0,
            cap: COUNT = 0,
        };
        const USERDATA = *USERDATA_CONCRETE;
        const COUNT = u32;
        const ID = struct {
            raw: [4]u8 = @splat(0),

            pub fn real(self: ID) u32 {
                return @bitCast(self.raw);
            }
            pub fn new(id: u32) ID {
                return ID{ .raw = @bitCast(id) };
            }
        };
        const ELEM = struct {
            a: u16,
            b: u16,

            pub fn real(self: ELEM) u32 {
                return (@as(u32, @intCast(self.a)) << 16) | @as(u32, @intCast(self.b));
            }
            pub fn new(val: u32) ELEM {
                return ELEM{
                    .a = @as(u16, @intCast(val >> 16)),
                    .b = @as(u16, @intCast(val & 0xFFFF)),
                };
            }
            pub fn equal(a: ELEM, b: ELEM) bool {
                return a.real() == b.real();
            }
        };
        const FUNC = struct {
            fn get_len(_: DATA, userdata: USERDATA) COUNT {
                return userdata.len;
            }
            fn set_len(data: DATA, new_len: COUNT, userdata: USERDATA) DATA {
                userdata.len = new_len;
                return data.incr();
            }
            fn get_cap(_: DATA, userdata: USERDATA) COUNT {
                return userdata.len;
            }
            fn set_cap(data: DATA, new_cap: COUNT, userdata: USERDATA) DATA {
                userdata.cap = new_cap;
                return data.incr();
            }
            fn get_base_ptr(_: DATA, userdata: USERDATA) [*]ELEM {
                return userdata.ptr;
            }
            fn get_base_ptr_const(_: DATA, userdata: USERDATA) [*]const ELEM {
                return userdata.ptr;
            }
            fn set_base_ptr(data: DATA, ptr: [*]ELEM, userdata: USERDATA) DATA {
                userdata.ptr = ptr;
                return data.incr();
            }
            fn get(_: DATA, id: ID, userdata: USERDATA) ELEM {
                return userdata.ptr[id.real()];
            }
            fn get_ptr(_: DATA, id: ID, userdata: USERDATA) *ELEM {
                return &userdata.ptr[id.real()];
            }
            fn set(data: DATA, id: ID, val: ELEM, userdata: USERDATA) DATA {
                userdata.ptr[id.real()] = val;
                return data.incr();
            }
            fn id_less(_: DATA, a: ID, b: ID, _: USERDATA) bool {
                return a.real() < b.real();
            }
            fn id_less_or_equal(_: DATA, a: ID, b: ID, _: USERDATA) bool {
                return a.real() <= b.real();
            }
            fn id_greater(_: DATA, a: ID, b: ID, _: USERDATA) bool {
                return a.real() > b.real();
            }
            fn id_greater_or_equal(_: DATA, a: ID, b: ID, _: USERDATA) bool {
                return a.real() >= b.real();
            }
            fn id_equal(_: DATA, a: ID, b: ID, _: USERDATA) bool {
                return a.real() == b.real();
            }
            fn first(_: DATA, _: USERDATA) ID {
                return ID{};
            }
            fn nth_from_start(_: DATA, n: COUNT, _: USERDATA) ID {
                return .new(@intCast(n));
            }
            fn next(_: DATA, id: ID, _: USERDATA) ID {
                return ID.new(id.real() + 1);
            }
            fn nth_next(_: DATA, id: ID, n: COUNT, _: USERDATA) ID {
                return ID.new(id.real() + @as(u32, @intCast(n)));
            }
            fn prev(_: DATA, id: ID, _: USERDATA) ID {
                return ID.new(id.real() - 1);
            }
            fn nth_prev(_: DATA, id: ID, n: COUNT, _: USERDATA) ID {
                return ID.new(id.real() - @as(u32, @intCast(n)));
            }
            fn last(data: DATA, userdata: USERDATA) ID {
                return .new(@intCast(get_len(data, userdata) -% 1));
            }
            fn nth_from_end(data: DATA, n: COUNT, userdata: USERDATA) ID {
                return .new(@intCast(get_len(data, userdata) -% 1 -% n));
            }
            fn elem_less(a: ELEM, b: ELEM, _: USERDATA) bool {
                return a.real() < b.real();
            }
            fn elem_less_or_equal(a: ELEM, b: ELEM, _: USERDATA) bool {
                return a.real() <= b.real();
            }
            fn elem_greater(a: ELEM, b: ELEM, _: USERDATA) bool {
                return a.real() > b.real();
            }
            fn elem_greater_or_equal(a: ELEM, b: ELEM, _: USERDATA) bool {
                return a.real() >= b.real();
            }
            fn elem_equal(a: ELEM, b: ELEM, _: USERDATA) bool {
                return a.real() == b.real();
            }
            fn valid_id(_: DATA, id: ID, userdata: USERDATA) bool {
                return 0 <= id.real() and id.real() < userdata.len;
            }
            fn invalid_after(_: DATA, userdata: USERDATA) ID {
                return ID.new(@intCast(userdata.len));
            }
            fn invalid_before(_: DATA, _: USERDATA) ID {
                return ID.new(math.maxInt(u32));
            }
        };
        const CORE = DataManipulationCore{
            .COUNT_INT = COUNT,
            .DATA = DATA,
            .ELEM = ELEM,
            .ID = ID,
            .USERDATA = USERDATA,
        };
        const PKG_FULL_CUSTOM_FUNCS = CORE.select_functions(7000, .ALLOW_INFERED_IMPLEMENTATIONS, CORE.Builder().CustomFunctions_{
            .GET = FUNC.get,
            .GET_PTR = FUNC.get_ptr,
            .SET = FUNC.set,
            .GET_LEN = FUNC.get_len,
            .SET_LEN = FUNC.set_len,
            .FIRST_ID = FUNC.first,
            .LAST_ID = FUNC.last,
            .NEXT_ID = FUNC.next,
            .PREV_ID = FUNC.prev,
            .NTH_NEXT_ID = FUNC.nth_next,
            .NTH_PREV_ID = FUNC.nth_prev,
            .NTH_ID_FROM_START = FUNC.nth_from_start,
            .NTH_ID_FROM_END = FUNC.nth_from_end,
            .ID_LESS_THAN = FUNC.id_less,
            .ID_LESS_THAN_OR_EQUAL = FUNC.id_less_or_equal,
            .ID_GREATER_THAN = FUNC.id_greater,
            .ID_GREATER_THAN_OR_EQUAL = FUNC.id_greater_or_equal,
            .ID_EQUALS = FUNC.id_equal,
            .LESS_THAN = FUNC.elem_less,
            .LESS_THAN_OR_EQUAL = FUNC.elem_less_or_equal,
            .GREATER_THAN = FUNC.elem_greater,
            .GREATER_THAN_OR_EQUAL = FUNC.elem_greater_or_equal,
            .ORDER_EQUALS = FUNC.elem_equal,
            .EXACT_EQUALS = FUNC.elem_equal,
            .ID_VALID = FUNC.valid_id,
            .INVALID_ID_AFTER_LAST_ID = FUNC.invalid_after,
            .INVALID_ID_BEFORE_FIRST_ID = FUNC.invalid_before,
        }, .no_extra_properties).finalize();
    };
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
    const DMP = Defaults.const_slice_not_allocated_package(u8);
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

test "Utils_DataManipulation => sorting algorithms" {
    const BUF_MAX_LEN: usize = @max(SORT_TEST_CASES.LONGEST_CASE, 50);
    const rand = Root.Rand.seed_default_rand_time_now_and_get(Test.io);
    {
        const dmp = Defaults.slice_not_allocated_package(u8);
        var buf: [BUF_MAX_LEN]u8 = undefined;
        var buf_len: usize = 0;
        var is_sorted: bool = false;
        for (SORT_TEST_CASES.CASES[0..]) |case| {
            buf_len = case.input.len;
            var buf_slice = buf[0..buf_len];
            // Insertion Sort
            @memcpy(buf_slice, case.input);
            buf_slice = dmp.insertion_sort_range(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort
            @memcpy(buf_slice, case.input);
            buf_slice = dmp.quicksort_range(buf_slice, 0, buf_len -% 1, {}, .{});
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort
            @memcpy(buf_slice, case.input);
            buf_slice = dmp.heapsort_range(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_slices_equal_t_src(u8, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
        for (0..SORT_TEST_CASES.NUM_RANDOM_TESTS) |_| {
            buf_len = rand.intRangeAtMost(usize, 2, BUF_MAX_LEN);
            var buf_slice = buf[0..buf_len];
            // Insertion Sort Random
            for (0..buf_len) |i| {
                buf[i] = rand.int(u8);
            }
            buf_slice = dmp.insertion_sort_range(buf_slice, 0, buf_len -% 1, {});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort Random
            for (0..buf_len) |i| {
                buf[i] = rand.int(u8);
            }
            buf_slice = dmp.quicksort_range(buf_slice, 0, buf_len -% 1, {}, .{});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort Random
            for (0..buf_len) |i| {
                buf[i] = rand.int(u8);
            }
            buf_slice = dmp.heapsort_range(buf_slice, 0, buf_len -% 1, {});
            is_sorted = dmp.is_sorted(buf_slice, 0, buf_len -% 1, {});
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
    }
    {
        const dmp = TEST_UTILS.BLIND.PKG_FULL_CUSTOM_FUNCS;
        const Blind = TEST_UTILS.BLIND.ELEM;
        var buf: [BUF_MAX_LEN]Blind = undefined;
        var buf_len: u32 = 0;
        var is_sorted: bool = false;
        var udata_concrete = TEST_UTILS.BLIND.USERDATA_CONCRETE{
            .ptr = @ptrCast(&buf),
            .len = 0,
            .cap = 0,
        };
        const udata: TEST_UTILS.BLIND.USERDATA = &udata_concrete;
        var data = TEST_UTILS.BLIND.DATA{};
        for (SORT_TEST_CASES.BLIND_CASES[0..]) |case| {
            buf_len = @intCast(case.input.len);
            udata_concrete.len = buf_len;
            udata_concrete.cap = buf_len;
            const buf_slice = buf[0..buf_len];
            // Insertion Sort
            @memcpy(buf_slice, case.input);
            data = dmp.insertion_sort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_slices_equal_t_func_src(Blind, Blind.equal, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort
            @memcpy(buf_slice, case.input);
            data = dmp.quicksort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata, .{});
            try Test.expect_slices_equal_t_func_src(Blind, Blind.equal, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort
            @memcpy(buf_slice, case.input);
            data = dmp.heapsort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_slices_equal_t_func_src(Blind, Blind.equal, case.expected_output, buf_slice, @src(), "", .{});
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
        for (0..SORT_TEST_CASES.NUM_RANDOM_TESTS) |_| {
            buf_len = rand.intRangeAtMost(u32, 2, BUF_MAX_LEN);
            udata_concrete.len = buf_len;
            udata_concrete.cap = buf_len;
            // Insertion Sort Random
            for (0..buf_len) |i| {
                buf[i] = Blind.new(rand.int(u32));
            }
            data = dmp.insertion_sort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Quicksort Random
            for (0..buf_len) |i| {
                buf[i] = Blind.new(rand.int(u32));
            }
            data = dmp.quicksort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata, .{});
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
            // Heapsort Random
            for (0..buf_len) |i| {
                buf[i] = Blind.new(rand.int(u32));
            }
            data = dmp.heapsort_range(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            is_sorted = dmp.is_sorted(data, dmp.first_id(data, udata), dmp.last_id(data, udata), udata);
            try Test.expect_true_src(is_sorted, @src(), "", .{});
        }
    }
}
