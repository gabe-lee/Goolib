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
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const Types = Root.Types;
const CommonTypes = Root.CommonTypes;
const Mutability = CommonTypes.Mutability;
const Nullability = CommonTypes.Nullability;
const NullPropagation = CommonTypes.NullPropagation;
const NullOperation = CommonTypes.NullOperation;
const Utils = Root.Utils;
const Cast = Root.Cast;
const Hash = std.hash.XxHash64;
const Assert = Root.Assert;
const Sort = Root.Sort;
const Allocator = std.mem.Allocator;
const KindInfo = Types.KindInfo;
const util_secure_memset = Utils.Mem.secure_memset;
const util_secure_zero = Utils.Mem.secure_zero;
const util_secure_memset_undefined = Utils.Mem.secure_memset_undefined;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
// const InsertionSort = Root.InsertionSort;
// const BinarySearch = Root.BinarySearch;
const SmartAllocSettings = Utils.Alloc.SmartAllocSettings;
const SmartAllocComptimeSettings = Utils.Alloc.SmartAllocComptimeSettings;
const CompareFunc = Utils.Mem.CompareFunc;
const CompareFuncUserdata = Utils.Mem.CompareFuncUserdata;
const GrowthModel = CommonTypes.GrowthModel;
const SandboxMode = CommonTypes.SandboxMode;
const LenMutability = CommonTypes.LenMutability;
const CapMutability = CommonTypes.CapMutability;
const CapReallocMutability = CommonTypes.CapReallocMutability;
const PtrMutability = CommonTypes.PtrMutability;
const Reallocatability = CommonTypes.Reallocatability;
const MemoryParadigm = CommonTypes.MemoryParadigm;
const MemoryAllocationStatus = CommonTypes.MemoryAllocationStatus;
const ATOMIC_PADDING = std.atomic.cache_line;

const STRUCT_NAME = "GooListSlice";
const ERR_CANNOT_INCREASE_START = "START_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase start address";
const ERR_CANNOT_DECREASE_START = "START_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease start address";
const ERR_CANNOT_INCREASE_END = "END_MUTABILITY != .increase_only or .increase_or_decrease, operation would increase end address";
const ERR_CANNOT_DECREASE_END = "END_MUTABILITY != .decrease_only or .increase_or_decrease, operation would decrease end address";
const ERR_CANNOT_GROW_LEN = "LEN_MUTABILITY != .grow_only or .shrink_or_grow, operation would grow length";
const ERR_CANNOT_SHRINK_LEN = "LEN_MUTABILITY != .shrink_only or .shrink_or_grow, operation would shrink length";
const ERR_OPERATE_IMMUTABLE_ELEM = STRUCT_NAME ++ "(ELEM_MUTABILITY = .immutable) attempted to change element value";
const ERR_OPERATE_NULL = "cannot operate on null ptr";
const ERR_SHRINK_OOB = "shrink count ({d}) would cause condition `first_address > last_address` (max shrink = len = {d})";
const ERR_START_END_REVERSED = "provided start ({d}) and end ({s}) indexes would cause condition `first_address > last_address`";
const ERR_LEN_PLUS_N_EXCCEEDS_CAP = "current len ({d}) plus N more items ({d}) exceeds the current capacity ({d})";
const ERR_INDEX_OOB = "the largest requested or provided index ({d}) is out of GooListSlice bounds (len = {d})";
const ERR_EMPTY = "GooListSlice is empty, no 'first' or 'last' element exists";
const ERR_LEN_ZERO = "the GooListSlice length is zero, cannot index any element";
const ERR_LEN_GREATER_THAN_CAP = "the GooListSlice length {d} is greater than capacity {d}";
const ERR_LEN_OR_CAP_NEGATIVE = "the GooListSlice length {d} or capacity {d} is less than zero";
const ERR_LEN_OR_CAP_NONZERO_WHEN_NULL = "the GooListSlice length {d} or capacity {d} is not zero when the pointer is null";
const ERR_IMMUTABLE = "the GooListSlice was declared immutable and its elements cannot be altered. if you absolutely need to mutate it, use `.change_mutablility(.MUTABLE)` or access the pointer manually with `@constCast()`";
const ERR_NOT_LIST = "this method requires a GooListSlice with mode `.LIST`";
const ERR_NOT_SLICE = "this method requires a GooListSlice with mode `.SLICE`";
const ERR_NOT_ENOUGH_FREE_SLOTS = "there were not enough free slots to complete the operation, needed {d}, have {d}";
const ERR_UNIMPLEMENTED = "this method is not implemented for mode `{s}`";
const ERR_INDEX_CHUNK_OOB = "requested or provided start + count ({d} + {d} = {d}) would put the resulting sub-slice out of original bounds (len = {d})";
const ERR_NOT_POSSIBLE_WITH_SOA = "this method is not possible when the Memory Paradigm is `." ++ @tagName(MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) ++ "`";
const ERR_MUST_BE_SOA = "this method is not possible when the Memory Paradigm is NOT `." ++ @tagName(MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) ++ "`";
const ERR_NOT_POSSIBLE_WITH_SOA_AND_NO_START_OFFSET = "this method is not possible when the Memory Paradigm is `." ++ @tagName(MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) ++ "` and a start offset is not included";
const ERR_ALTER_ALLOCATED_MEM = "cannot alter the memory region of allocated memory (cannot move base pointer, or change max capacity)";
const ERR_REALLOC_REF_MEMORY = "cannot reallocate memory that is only a reference to memory that is tracked elsewhere (either on the stack or in a separate allocated memory slice)";
const ERR_START_OFFSET_TOO_SMALL = "either the start offset was not sufficient (when paradigm is `." ++ @tagName(MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) ++ "`) or there was no start offset, need at least {d} offset, had offset {d}";
// const ERR_SHIFT_OVERLAP = "a `shift({s}) -> @memcopy` operation isn't shifted far enough to guarantee no overlap (min_shift = len = {d})";

pub const GooListSliceMode = enum(u1) {
    SLICE,
    LIST,
};

const OriginFuncAllocAssume = enum {
    ASSUME_CAPACITY,
    REALLOCATE,
};
const OriginFuncReturn = enum {
    SELF_ONLY,
    IDX,
    REF,
};
const OriginFuncCount = enum {
    ONE,
    MANY,
};
const OriginFuncSetVal = enum {
    EMPTY_SLOTS,
    SET_VALS,
};
const OriginFuncValSetLoc = enum {
    APPEND,
    INSERT,
};
const OriginInPlace = enum {
    RET_NEW,
    IN_PLACE,
};

pub const SubSliceMode = enum {
    /// Sub-slice inherits element mutability,
    /// but its size and pointer address can move
    NORMAL,
    /// Sub-slice inherits element mutability, and its
    /// size and pointer address cannot change
    STATIC,
    /// Sub-slice has immutable elements (const),
    /// but its size and pointer address can move
    IMMUTABLE,
    /// Sub-slice has immutable elements (const), and its
    /// size and pointer address cannot change
    STATIC_IMMUTABLE,
};

pub const FalseSharingMode = enum(u8) {
    /// No false-shaing mitigations
    IGNORE_FALSE_SHARING,
    /// Always forces pointer to be aligned to the platform
    /// cache-line size, and adds an extra (unusble) buffer
    /// of elements at least as large as the cache-line size
    /// before and after all allocation methods
    ///
    /// This prevents false sharing bewteen this memory region and those adjacent to it,
    /// but not necessarily between region elements
    PREVENT_FALSE_SHARING_FOR_REGION,
    /// Asserts that individual elements MUST be aligned to at least
    /// the size of a platform cache-line, thereby guaranteeing
    /// no false sharing can occur between elements.
    ///
    /// When combined with `MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS`,
    /// this asserts that each individual FIELD is on it's own cache line, which can
    /// GREATLY increase the memory footprint with a lot of wasted space
    PREVENT_FALSE_SHARING_PER_ELEMENT,
};

pub const GooListSliceDefinitionOptional = struct {
    T: ?type = null,
    IDX: ?type = null,
    ALIGN: ?usize = null,
    ELEM_MUTABILITY: ?Mutability = null,
    PTR_NULLABILITY: ?Nullability = null,
    MODE: ?GooListSliceMode = null,
    ALLOC_STATUS: ?MemoryAllocationStatus = null,
    INCLUDE_START_OFFSET: ?bool = null,
    MEM_PARADIGM: ?MemoryParadigm = null,
    FALSE_SHARING: ?FalseSharingMode = null,
    INITIALIZE_NEW_ELEMENTS: ?*const anyopaque = null,
    SECURE_ZERO_FREED_MEMORY: ?bool = null,
};

pub const GooListSliceDefinition = struct {
    T: type,
    IDX: type = usize,
    ALIGN: Utils.Alloc.Align = .ALIGN_TO_TYPE,
    ELEM_MUTABILITY: Mutability = .MUTABLE,
    PTR_NULLABILITY: Nullability = .NOT_NULLABLE,
    MODE: GooListSliceMode = .SLICE,
    ALLOC_STATUS: MemoryAllocationStatus = .REFERENCE_TO_EXISTING_MEMORY,
    INCLUDE_START_OFFSET: bool = false,
    MEM_PARADIGM: MemoryParadigm = .OBJECTS_STORED_WHOLE,
    FALSE_SHARING: FalseSharingMode = .IGNORE_FALSE_SHARING,
    INITIALIZE_NEW_ELEMENTS: ?*const anyopaque = null,
    SECURE_ZERO_FREED_MEMORY: bool = false,

    pub fn allocated_list(comptime T: type, comptime IDX: type) GooListSliceDefinition {
        return GooListSliceDefinition{
            .T = T,
            .IDX = IDX,
            .ALIGN = @alignOf(T),
            .ELEM_MUTABILITY = .MUTABLE,
            .PTR_NULLABILITY = .NOT_NULLABLE,
            .MODE = .LIST,
            .ALLOC_STATUS = .ALLOCATED_MEMORY,
            .MEM_PARADIGM = .OBJECTS_STORED_WHOLE,
        };
    }
    pub fn allocated_slice(comptime T: type, comptime IDX: type) GooListSliceDefinition {
        return GooListSliceDefinition{
            .T = T,
            .IDX = IDX,
            .ALIGN = @alignOf(T),
            .ELEM_MUTABILITY = .MUTABLE,
            .PTR_NULLABILITY = .NOT_NULLABLE,
            .MODE = .SLICE,
            .ALLOC_STATUS = .ALLOCATED_MEMORY,
            .MEM_PARADIGM = .OBJECTS_STORED_WHOLE,
        };
    }

    pub fn sub_slice(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ALLOC_STATUS = .REFERENCE_TO_EXISTING_MEMORY;
        if (DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) {
            new_def.INCLUDE_START_OFFSET = true;
        }
        return new_def;
    }
    pub fn sub_slice_static(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ALLOC_STATUS = .REFERENCE_TO_EXISTING_MEMORY;
        if (DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) {
            new_def.INCLUDE_START_OFFSET = true;
        }
        return new_def;
    }
    pub fn sub_slice_immutable(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ELEM_MUTABILITY = .IMMUTABLE;
        new_def.ALLOC_STATUS = .REFERENCE_TO_EXISTING_MEMORY;
        if (DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) {
            new_def.INCLUDE_START_OFFSET = true;
        }
        return new_def;
    }
    pub fn sub_slice_static_immutable(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ELEM_MUTABILITY = .IMMUTABLE;
        new_def.ALLOC_STATUS = .REFERENCE_TO_EXISTING_MEMORY;
        if (DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) {
            new_def.INCLUDE_START_OFFSET = true;
        }
        return new_def;
    }

    pub fn with_overrides(comptime self: GooListSliceDefinition, comptime overrides: GooListSliceDefinitionOptional) GooListSliceDefinition {
        var new = self;
        if (overrides.T) |T| new.T = T;
        if (overrides.IDX) |IDX| new.IDX = IDX;
        if (overrides.ALIGN) |ALIGN| new.ALIGN = ALIGN;
        if (overrides.ELEM_MUTABILITY) |ELEM_MUTABILITY| new.ELEM_MUTABILITY = ELEM_MUTABILITY;
        if (overrides.PTR_NULLABILITY) |PTR_NULLABILITY| new.PTR_NULLABILITY = PTR_NULLABILITY;
        if (overrides.MODE) |MODE| new.MODE = MODE;
        if (overrides.ALLOC_STATUS) |A_STAT| new.ALLOC_STATUS = A_STAT;
        if (overrides.MEM_PARADIGM) |PARADIGM| new.MEM_PARADIGM = PARADIGM;
        if (overrides.INCLUDE_START_OFFSET) |OFF| new.INCLUDE_START_OFFSET = OFF;
        if (overrides.INITIALIZE_NEW_ELEMENTS) |INIT| new.INITIALIZE_NEW_ELEMENTS = INIT;
        if (overrides.SECURE_ZERO_FREED_MEMORY) |ZERO| new.SECURE_ZERO_FREED_MEMORY = ZERO;
        if (overrides.FALSE_SHARING) |FS| new.FALSE_SHARING = FS;
        return new;
    }

    pub fn with_align(comptime self: GooListSliceDefinition, comptime alignment: Utils.Alloc.Align) GooListSliceDefinition {
        var new = self;
        new.ALIGN = alignment;
        return new;
    }
    pub fn with_mutablility(comptime self: GooListSliceDefinition, comptime mutability: Mutability) GooListSliceDefinition {
        var new = self;
        new.ELEM_MUTABILITY = mutability;
        return new;
    }
    pub fn with_nullability(comptime self: GooListSliceDefinition, comptime nullability: Nullability) GooListSliceDefinition {
        var new = self;
        new.PTR_NULLABILITY = nullability;
        return new;
    }
    pub fn with_index_type(comptime self: GooListSliceDefinition, comptime index_type: type) GooListSliceDefinition {
        var new = self;
        new.IDX = index_type;
        return new;
    }
    pub fn with_element_type(comptime self: GooListSliceDefinition, comptime elem_type: type) GooListSliceDefinition {
        var new = self;
        new.T = elem_type;
        return new;
    }
    pub fn with_mode(comptime self: GooListSliceDefinition, comptime mode: GooListSliceMode) GooListSliceDefinition {
        var new = self;
        new.MODE = mode;
        return new;
    }
    pub fn with_alloc_status(comptime self: GooListSliceDefinition, comptime alloc_status: MemoryAllocationStatus) GooListSliceDefinition {
        var new = self;
        new.ALLOC_STATUS = alloc_status;
        return new;
    }
    pub fn with_memory_paradigm(comptime self: GooListSliceDefinition, comptime paradigm: MemoryParadigm) GooListSliceDefinition {
        var new = self;
        new.MEM_PARADIGM = paradigm;
        return new;
    }
    pub fn with_initialize_new_elements(comptime self: GooListSliceDefinition, comptime init: ?*const anyopaque) GooListSliceDefinition {
        var new = self;
        new.INITIALIZE_NEW_ELEMENTS = init;
        return new;
    }
    pub fn with_secure_zero(comptime self: GooListSliceDefinition, comptime secure_zero: bool) GooListSliceDefinition {
        var new = self;
        new.SECURE_ZERO_FREED_MEMORY = secure_zero;
        return new;
    }
    pub fn with_included_start_offset(comptime self: GooListSliceDefinition, comptime include_start_offset: bool) GooListSliceDefinition {
        var new = self;
        new.INCLUDE_START_OFFSET = include_start_offset;
        return new;
    }
    pub fn with_false_sharing_protection(comptime self: GooListSliceDefinition, comptime protection: FalseSharingMode) GooListSliceDefinition {
        var new = self;
        new.FALSE_SHARING = protection;
        return new;
    }
};

pub fn type_is_GooListSlice(comptime T: type) bool {
    const INFO = KindInfo.get_kind_info(T);
    if (INFO == .STRUCT) {
        if (@hasDecl(T, DECL_BOOL_GooListSlice)) {
            const is_gls = @field(T, DECL_BOOL_GooListSlice);
            if (@TypeOf(is_gls) == bool) {
                return is_gls == true;
            }
        }
    }
    return false;
}
pub const KIND_GooListSlice = "Goolib.GooListSlice.GooListSlice";
pub const KIND_HASH_GooListSlice = Hash.hash(0, KIND_GooListSlice);
pub const DECL_BOOL_GooListSlice = "GOOLIB_GooListSlice";
pub fn GooListSlice(comptime DEF_: GooListSliceDefinition) type {
    if (@typeInfo(DEF_.IDX) != .int) @compileError("type `Idx` must be an integer type");
    return extern struct {
        const ListSlice = @This();
        pub const GOOLIB_TYPE_DATA = Types.Id.get_type_data(ListSlice, KIND_GooListSlice, if (IS_LIST) .LIST else .SLICE);
        pub const GOOLIB_GooListSlice = true;

        ptr: Ptr = INVALID_DATA_POINTER,
        len: Idx = 0,
        cap: if (IS_LIST) Idx else void = if (IS_LIST) 0 else void{},
        off: if (OFFSET) Idx else void = if (OFFSET) 0 else void{},

        //**********
        // CONSTS
        //**********

        pub const DEF = DEF_;
        pub const T = DEF.T;
        pub const Idx = DEF.IDX;
        const ELEM_MUTABILITY = DEF.ELEM_MUTABILITY;
        const PTR_NULLABILITY = DEF.PTR_NULLABILITY;
        const MODE = DEF.MODE;
        const IS_SLICE = MODE == .SLICE;
        const IS_LIST = MODE == .LIST;
        const OFFSET = DEF.INCLUDE_START_OFFSET;
        const SOA = DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS;
        const T_NUM_FIELDS: usize = get: {
            const INFO = KindInfo.get_kind_info(T);
            switch (INFO) {
                .STRUCT => |STRUCT| break :get if (SOA) STRUCT.fields.len else 1,
                else => break :get 1,
            }
        };
        const T_FIELD_DATA: [T_NUM_FIELDS]std.builtin.Type.StructField = create: {
            var out: [T_NUM_FIELDS]std.builtin.Type.StructField = undefined;
            const INFO = KindInfo.get_kind_info(T);
            switch (INFO) {
                .STRUCT => |STRUCT| {
                    if (SOA) {
                        for (STRUCT.fields, 0..) |field, f| {
                            out[f] = field;
                        }
                    } else {
                        out[0] = std.builtin.Type.StructField{
                            .alignment = @alignOf(T),
                            .default_value_ptr = DEF.INITIALIZE_NEW_ELEMENTS,
                            .is_comptime = false,
                            .name = "<no field/single object>",
                            .type = T,
                        };
                    }
                },
                else => out[0] = std.builtin.Type.StructField{
                    .alignment = @alignOf(T),
                    .default_value_ptr = DEF.INITIALIZE_NEW_ELEMENTS,
                    .is_comptime = false,
                    .name = "<no field/single object>",
                    .type = T,
                },
            }
            Sort.InsertionSort.insertion_sort_with_func(out[0..], Sort.CommonCompare.StructField.smaller_align_to_the_right_gt);
            break :create out;
        };
        const T_MAX_ALIGN = T_FIELD_DATA[0].alignment;
        const T_MAX_ALIGN = T_FIELD_DATA[0].alignment;
        const T_SIZE = switch (DEF.MEM_PARADIGM) {
            .OBJECTS_STORED_WHOLE => @sizeOf(T),
            .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => calc: {
                const size: usize = 0;
                for (T_FIELD_DATA[0..]) |field| {
                    size += @sizeOf(field.type);
                }
                break :calc size;
            },
        };
        const T_FIELD_OFFSETS: [T_NUM_FIELDS]usize = calc: {
            var curr_off: usize = 0;
            var out: [T_NUM_FIELDS]usize = undefined;
            for (T_FIELD_DATA[0..], 0..) |field, f| {
                out[f] = curr_off;
                curr_off += @sizeOf(field.type);
            }
            break :calc out;
        };
        const T_FIELDS_ENUM_FIELDS = create: {
            var e_fields: [T_NUM_FIELDS]std.builtin.Type.EnumField = undefined;
            var i: comptime_int = 0;
            for (T_FIELD_DATA[0..]) |field| {
                e_fields[i] = std.builtin.Type.EnumField{
                    .name = field.name,
                    .value = i,
                };
                i += 1;
            }
            break :create e_fields;
        };
        //CHECKPOINT fix align/alloc for false-sharing modes
        pub const FieldEnum = @Type(.{ .@"enum" = .{
            .decls = &.{},
            .fields = T_FIELDS_ENUM_FIELDS[0..],
            .is_exhaustive = true,
            .tag_type = Types.SmallestUnsignedIntThatCanHoldValue(T_NUM_FIELDS - 1),
        } });
        const T_FIELDS_ENUM_TAGS: [T_NUM_FIELDS]FieldEnum = create: {
            var out: [T_NUM_FIELDS]FieldEnum = undefined;
            var i: comptime_int = 0;
            while (i < T_NUM_FIELDS) : (i += 1) {
                out[i] = @enumFromInt(i);
            }
            break :create out;
        };
        fn FieldType(comptime field: FieldEnum) type {
            return T_FIELD_DATA[@intFromEnum(field)].type;
        }
        pub const MAX_ALIGN = calc: {
            var a = if (DEF.MEM_PARADIGM == .OBJECTS_STORED_WHOLE) DEF.ALIGN.get_align(@alignOf(T)) else DEF.ALIGN.get_align(T_MAX_ALIGN);
            if (DEF.FALSE_SHARING != .IGNORE_FALSE_SHARING) {
                a = @max(a, std.atomic.cache_line);
            }
            break :calc a;
        };
        const TT = switch (DEF.FALSE_SHARING) {
            .PREVENT_FALSE_SHARING_PER_ELEMENT => switch (DEF.MEM_PARADIGM) {
                .OBJECTS_STORED_WHOLE => {
                    if ()
                },
                .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => {},
            },
            .IGNORE_FALSE_SHARING, .PREVENT_FALSE_SHARING_FOR_REGION => switch (DEF.MEM_PARADIGM) {
                .OBJECTS_STORED_WHOLE => T,
                .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => u8,
            },
        };
        const ADD_CACHE_TAIL = DEF.FALSE_SHARING == .PREVENT_FALSE_SHARING_FOR_REGION and @min(@sizeOf(T), @alignOf(T)) < std.atomic.cache_line;
        pub const Ptr = switch (DEF.MEM_PARADIGM) {
            .OBJECTS_STORED_WHOLE => switch (ELEM_MUTABILITY) {
                .IMMUTABLE => switch (PTR_NULLABILITY) {
                    .NOT_NULLABLE => [*]align(MAX_ALIGN) const T,
                    .NULLABLE => ?[*]align(MAX_ALIGN) const T,
                },
                .MUTABLE => switch (PTR_NULLABILITY) {
                    .NOT_NULLABLE => [*]align(MAX_ALIGN) T,
                    .NULLABLE => ?[*]align(MAX_ALIGN) T,
                },
            },
            .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => switch (ELEM_MUTABILITY) {
                .IMMUTABLE => switch (PTR_NULLABILITY) {
                    .NOT_NULLABLE => [*]align(MAX_ALIGN) const u8,
                    .NULLABLE => ?[*]align(MAX_ALIGN) const u8,
                },
                .MUTABLE => switch (PTR_NULLABILITY) {
                    .NOT_NULLABLE => [*]align(MAX_ALIGN) u8,
                    .NULLABLE => ?[*]align(MAX_ALIGN) u8,
                },
            },
        };
        pub const BytePtr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]const u8,
                .NULLABLE => ?[*]const u8,
            },
            .MUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]u8,
                .NULLABLE => ?[*]u8,
            },
        };
        pub const PtrNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]const T,
            .MUTABLE => [*]T,
        };
        pub const PtrNeverNullVolatile = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]const volatile T,
            .MUTABLE => [*]volatile T,
        };
        pub const BytePtrNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]align(T_MAX_ALIGN) const u8,
            .MUTABLE => [*]align(T_MAX_ALIGN) u8,
        };
        pub const BytePtrNeverNullVolatile = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]align(T_MAX_ALIGN) const volatile u8,
            .MUTABLE => [*]align(T_MAX_ALIGN) volatile u8,
        };
        pub const ElemPtr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => *const T,
            .MUTABLE => *T,
        };
        pub fn FieldPtr(comptime field: FieldEnum) type {
            return switch (ELEM_MUTABILITY) {
                .IMMUTABLE => *const FieldType(field),
                .MUTABLE => *FieldType(field),
            };
        }
        pub fn FieldPtrMany(comptime field: FieldEnum) type {
            return switch (ELEM_MUTABILITY) {
                .IMMUTABLE => [*]const FieldType(field),
                .MUTABLE => [*]FieldType(field),
            };
        }
        pub fn FieldSlice(comptime field: FieldEnum) type {
            return switch (ELEM_MUTABILITY) {
                .IMMUTABLE => []const FieldType(field),
                .MUTABLE => []FieldType(field),
            };
        }
        pub fn FieldPtrVolatile(comptime field: FieldEnum) type {
            return switch (ELEM_MUTABILITY) {
                .IMMUTABLE => *const volatile FieldType(field),
                .MUTABLE => *volatile FieldType(field),
            };
        }
        pub const ZigSlice = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => []const T,
                .NULLABLE => ?[]const T,
            },
            .MUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => []T,
                .NULLABLE => ?[]T,
            },
        };
        pub const ZigSliceNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => []const T,
            .MUTABLE => []T,
        };
        pub const ZigSliceNeverNullConst = []const T;
        const MUTABLE = ELEM_MUTABILITY == .MUTABLE;
        const NULLABLE = PTR_NULLABILITY == .NULLABLE;
        const INVALID_DATA_POINTER: Ptr = switch (PTR_NULLABILITY) {
            .NULLABLE => null,
            .NOT_NULLABLE => switch (ELEM_MUTABILITY) {
                .IMMUTABLE => if (SOA) Utils.invalid_ptr_many_const_custom_align(u8, T_MAX_ALIGN) else Utils.invalid_ptr_many_const(T),
                .MUTABLE => if (SOA) Utils.invalid_ptr_many_custom_align(u8, T_MAX_ALIGN) else Utils.invalid_ptr_many(T),
            },
        };
        const INVALID_ELEM_PTR = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => Utils.invalid_ptr_const(T),
            .MUTABLE => Utils.invalid_ptr(T),
        };

        const AllocSettings = SmartAllocSettings(if (SOA) u8 else T);
        const AllocSettingsComptime = SmartAllocComptimeSettings(if (SOA) u8 else T);

        //**********
        // TYPE CHANGE
        //**********

        pub fn with_mutablility(comptime mutability: Mutability) type {
            return GooListSlice(DEF.with_mutablility(mutability));
        }
        pub fn with_nullability(comptime nullability: Nullability) type {
            return GooListSlice(DEF.with_nullability(nullability));
        }
        pub fn with_index_type(comptime index_type: type) type {
            return GooListSlice(DEF.with_index_type(index_type));
        }
        pub fn with_element_type(comptime elem_type: type) type {
            return GooListSlice(DEF.with_element_type(elem_type));
        }
        pub fn with_mode(comptime mode: GooListSliceMode) type {
            return GooListSlice(DEF.with_mode(mode));
        }
        pub fn with_alloc_status(comptime alloc_status: MemoryAllocationStatus) type {
            return GooListSlice(DEF.with_alloc_status(alloc_status));
        }
        pub fn with_included_start_offset(comptime include_start_offset: bool) type {
            return GooListSlice(DEF.with_included_start_offset(include_start_offset));
        }
        pub fn with_memory_paradigm(comptime paradigm: MemoryParadigm) type {
            return GooListSlice(DEF.with_memory_paradigm(paradigm));
        }
        pub fn with_init_new_elements(comptime init: ?*const anyopaque) type {
            return GooListSlice(DEF.with_initialize_new_elements(init));
        }
        pub fn with_secure_zero(comptime secure_zero: bool) type {
            return GooListSlice(DEF.with_secure_zero(secure_zero));
        }
        pub fn with_new_settings(comptime new_settings: GooListSliceDefinitionOptional) type {
            return GooListSlice(DEF.with_overrides(new_settings));
        }
        pub fn with_sub_slice_mode(comptime mode: SubSliceMode) type {
            return switch (mode) {
                .NORMAL => SubSlice,
                .STATIC => SubSliceStatic,
                .IMMUTABLE => SubSliceImmutable,
                .STATIC_IMMUTABLE => SubSliceStaticImmutable,
            };
        }
        pub const SubSlice = GooListSlice(DEF.sub_slice());
        pub const SubSliceStatic = GooListSlice(DEF.sub_slice_static());
        pub const SubSliceImmutable = GooListSlice(DEF.sub_slice_immutable());
        pub const SubSliceStaticImmutable = GooListSlice(DEF.sub_slice_static_immutable());

        pub fn change_mutability(self: ListSlice, comptime new_elem_mutability: Mutability) ListSlice.with_mutablility(new_elem_mutability) {
            if (new_elem_mutability == ELEM_MUTABILITY) return self;
            return ListSlice.with_mutablility(new_elem_mutability){
                .ptr = if (new_elem_mutability == .MUTABLE) @constCast(self.ptr) else self.ptr,
                .len = self.len,
            };
        }
        pub fn change_nullability(self: ListSlice, comptime new_ptr_nullability: Nullability) ListSlice.with_nullability(new_ptr_nullability) {
            if (new_ptr_nullability == PTR_NULLABILITY) return self;
            return ListSlice.with_nullability(new_ptr_nullability){
                .ptr = if (new_ptr_nullability == .NULLABLE) self.ptr else self.ptr_never_null(),
                .len = self.len,
            };
        }
        pub fn change_mode(self: ListSlice, comptime new_mode: GooListSliceMode) ListSlice.with_mode(new_mode) {
            if (new_mode == DEF.MODE) return self;
            return ListSlice.with_mode(new_mode){
                .ptr = self.ptr,
                .len = if (new_mode == .SLICE) self.cap else self.len,
                .cap = if (new_mode == .LIST) self.len else void{},
            };
        }
        pub fn change_ptr_mutability(self: ListSlice, comptime new_ptr_mutability: PtrMutability) ListSlice.with_ptr_mutability(new_ptr_mutability) {
            return @bitCast(self);
        }
        pub fn change_cap_mutability(self: ListSlice, comptime new_cap_mutability: CapMutability) ListSlice.with_cap_mutability(new_cap_mutability) {
            return @bitCast(self);
        }
        pub fn change_cap_realloc_mutability(self: ListSlice, comptime new_cap_realloc_mutability: CapReallocMutability) ListSlice.with_cap_realloc_mutability(new_cap_realloc_mutability) {
            return @bitCast(self);
        }
        pub fn change_alloc_status(self: ListSlice, comptime alloc_status: MemoryAllocationStatus) ListSlice.with_alloc_status(alloc_status) {
            return @bitCast(self);
        }
        pub fn change_secure_zero(self: ListSlice, comptime new_secure_zero: bool) ListSlice.with_secure_zero(new_secure_zero) {
            return @bitCast(self);
        }
        pub fn change_new_element_initilization(self: ListSlice, comptime new_init: ?*const anyopaque) ListSlice.with_init_new_elements(new_init) {
            return @bitCast(self);
        }
        pub fn change_included_start_offset(self: ListSlice, comptime include_start_offset: bool) ListSlice.with_included_start_offset(include_start_offset) {
            if (include_start_offset == DEF.INCLUDE_START_OFFSET) return self;
            if (include_start_offset == false) {
                assert_not_SOA(@src());
                return ListSlice.with_included_start_offset(false){
                    .ptr = self.ptr + self.off,
                    .len = self.len,
                    .cap = self.cap,
                };
            } else {
                return ListSlice.with_included_start_offset(true){
                    .ptr = self.ptr,
                    .len = self.len,
                    .cap = self.cap,
                    .off = 0,
                };
            }
        }

        //**********
        // ASSERTS
        //**********
        fn assert_not_empty(self: ListSlice, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(!self.is_empty(), src, ERR_EMPTY, .{});
        }
        fn assert_not_null(self: ListSlice, comptime src: std.builtin.SourceLocation) void {
            if (NULLABLE) {
                assert_with_reason(self.ptr != null, src, ERR_OPERATE_NULL, .{});
            }
        }
        fn assert_len_n_less_than_cap(self: ListSlice, n: Idx, comptime src: std.builtin.SourceLocation) void {
            if (IS_LIST) {
                assert_with_reason(self.len + n <= self.cap, src, ERR_LEN_PLUS_N_EXCCEEDS_CAP, .{ self.len, n, self.cap });
            } else {
                self.assert_len_greater_or_equal_count(n, src);
            }
        }
        fn assert_start_and_end_in_order(start: Idx, end: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(end >= start, src, ERR_START_END_REVERSED, .{ start, end });
        }
        fn assert_len_greater_or_equal_count(self: ListSlice, count: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(self.len >= count, src, ERR_SHRINK_OOB, .{ count, self.len });
        }
        fn assert_start_plus_len_in_range(self: ListSlice, start: Idx, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(start + len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ start, len, start + len, self.len });
        }
        fn assert_len_in_range(self: ListSlice, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ 0, len, len, self.len });
        }
        fn assert_len_in_range_from_end(self: ListSlice, len: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(len <= self.len, src, ERR_INDEX_CHUNK_OOB, .{ self.len - len, len, self.len, self.len });
        }
        fn assert_idx_in_range(self: ListSlice, idx: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(idx < self.len, src, ERR_INDEX_OOB, .{ idx, self.len });
        }
        fn assert_len_non_zero(self: ListSlice, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(self.len > 0, src, ERR_LEN_ZERO, .{});
        }
        fn assert_mutable(comptime src: std.builtin.SourceLocation) void {
            if (!MUTABLE) {
                assert_unreachable(src, ERR_IMMUTABLE, .{});
            }
        }
        fn assert_list(comptime src: std.builtin.SourceLocation) void {
            if (!IS_LIST) {
                assert_unreachable(src, ERR_NOT_LIST, .{});
            }
        }
        fn assert_slice(comptime src: std.builtin.SourceLocation) void {
            if (!IS_SLICE) {
                assert_unreachable(src, ERR_NOT_SLICE, .{});
            }
        }
        fn assert_free_slots(self: ListSlice, count: Idx, comptime src: std.builtin.SourceLocation) void {
            const _free = self.free_slots();
            assert_with_reason(_free >= count, src, ERR_NOT_ENOUGH_FREE_SLOTS, .{ _free, count });
        }
        fn unimplemented(comptime src: std.builtin.SourceLocation) noreturn {
            assert_unreachable(src, ERR_UNIMPLEMENTED, .{@tagName(DEF.MODE)});
        }
        pub fn assert_valid(self: ListSlice, comptime src: std.builtin.SourceLocation) void {
            if (IS_LIST) {
                assert_with_reason(self.len <= self.cap, src, ERR_LEN_GREATER_THAN_CAP, .{ self.len, self.cap });
            }
            assert_with_reason(self.len >= 0 or (if (IS_LIST) self.cap >= 0 else true), src, ERR_LEN_OR_CAP_NEGATIVE, .{ self.len, self.cap });
            if (Assert.should_assert() and self.is_null()) {
                assert_with_reason(self.len == 0 and (if (IS_LIST) self.cap == 0 else true), src, ERR_LEN_OR_CAP_NONZERO_WHEN_NULL, .{ self.len, self.cap });
            }
        }
        fn assert_not_SOA(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.MEM_PARADIGM == .OBJECTS_STORED_WHOLE, src, ERR_NOT_POSSIBLE_WITH_SOA, .{});
        }
        fn assert_SOA(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.MEM_PARADIGM == .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS, src, ERR_MUST_BE_SOA, .{});
        }
        fn assert_not_SOA_or_start_offset(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.MEM_PARADIGM == .OBJECTS_STORED_WHOLE or DEF.INCLUDE_START_OFFSET == true, src, ERR_NOT_POSSIBLE_WITH_SOA_AND_NO_START_OFFSET, .{});
        }
        fn assert_not_allocated(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.ALLOC_STATUS == .REFERENCE_TO_EXISTING_MEMORY, src, ERR_ALTER_ALLOCATED_MEM, .{});
        }
        fn assert_allocated(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.ALLOC_STATUS == .ALLOCATED_MEMORY, src, ERR_REALLOC_REF_MEMORY, .{});
        }
        fn assert_start_offset_at_least(self: ListSlice, n: Idx, comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(self.idx_start_offset() >= n, src, ERR_START_OFFSET_TOO_SMALL, .{ n, self.idx_start_offset() });
        }

        //**********
        // INIT AND UTIL
        //**********

        pub fn alloc_new(capacity: Idx, alloc: Allocator) ListSlice.with_alloc_status(.ALLOCATED_MEMORY) {
            ListSlice.with_alloc_status(.ALLOCATED_MEMORY).realloc_exact(ListSlice.with_alloc_status(.ALLOCATED_MEMORY){}, alloc, capacity);
        }

        pub fn from_slice(slice: ZigSlice) ListSlice {
            assert_not_SOA(@src());
            var out = ListSlice{};
            if (NULLABLE and slice != null) {
                if (slice != null) {
                    out.ptr = slice.?.ptr;
                    out.len = @intCast(slice.?.len);
                }
            } else {
                out.ptr = slice.ptr;
                out.len = @intCast(slice.len);
            }
            return out;
        }

        pub fn to_slice(self: ListSlice) ZigSlice {
            assert_not_SOA(@src());
            if (NULLABLE) {
                if (self.ptr == null) return null;
                return self.ptr_never_null()[self.idx_start_offset() .. self.idx_start_offset() + self.len];
            } else {
                return self.ptr[self.idx_start_offset() .. self.idx_start_offset() + self.len];
            }
        }

        pub fn to_slice_never_null(self: ListSlice) ZigSliceNeverNull {
            assert_not_SOA(@src());
            self.assert_not_null(@src());
            self.ptr_never_null()[self.idx_start_offset() .. self.idx_start_offset() + self.len];
        }

        pub fn is_null(self: ListSlice) bool {
            if (NULLABLE) {
                return self.ptr == null;
            }
            return false;
        }

        pub fn clear(self: ListSlice) ListSlice {
            var new_self = self;
            new_self.len = 0;
            return new_self;
        }

        pub fn in_place_clear(self: *ListSlice) void {
            self.len = 0;
        }

        pub fn is_empty(self: ListSlice) bool {
            return self.len <= 0;
        }

        pub fn free_slots(self: ListSlice) Idx {
            if (IS_SLICE) return 0;
            return self.cap - self.len;
        }

        pub fn idx_start_offset(self: ListSlice) Idx {
            return if (OFFSET) self.off else 0;
        }
        pub fn true_idx_from_ptr(self: ListSlice, idx: Idx) Idx {
            return idx + self.idx_start_offset();
        }
        pub fn true_len_from_ptr(self: ListSlice) Idx {
            return if (OFFSET) self.len + self.off else self.len;
        }

        pub fn ptr_never_null(self: ListSlice) PtrNeverNull {
            assert_not_SOA(@src());
            self.assert_not_null(@src());
            if (NULLABLE) {
                return self.ptr.?;
            } else {
                return self.ptr;
            }
        }
        pub fn ptr_never_null_volatile(self: ListSlice) PtrNeverNullVolatile {
            assert_not_SOA(@src());
            self.assert_not_null(@src());
            if (NULLABLE) {
                return self.ptr.?;
            } else {
                return self.ptr;
            }
        }

        pub fn byte_ptr_never_null(self: ListSlice) BytePtrNeverNull {
            self.assert_not_null(@src());
            if (NULLABLE) {
                return @ptrCast(self.ptr.?);
            } else {
                return @ptrCast(self.ptr);
            }
        }
        pub fn byte_ptr_never_null_volatile(self: ListSlice) BytePtrNeverNullVolatile {
            self.assert_not_null(@src());
            if (NULLABLE) {
                return @ptrCast(self.ptr.?);
            } else {
                return @ptrCast(self.ptr);
            }
        }

        fn field_chunk_ptr_never_null_known_true_len(self: ListSlice, len_usize: usize, comptime field: FieldEnum) FieldPtrMany(field) {
            assert_SOA(@src());
            self.assert_not_null(@src());
            const root_addr = @intFromPtr(self.byte_ptr_never_null());
            const base_offet = T_FIELD_OFFSETS[@intFromEnum(field)];
            const field_chunk_offset = base_offet * len_usize;
            return @ptrFromInt(root_addr + field_chunk_offset);
        }

        pub fn field_chunk_ptr_never_null(self: ListSlice, comptime field: FieldEnum) FieldPtrMany(field) {
            assert_SOA(@src());
            self.assert_not_null(@src());
            const len_usize = num_cast(self.true_len_from_ptr(), usize);
            return field_chunk_ptr_never_null_known_true_len(self, len_usize, field);
        }
        pub fn field_chunk_slice_never_null(self: ListSlice, comptime field: FieldEnum) FieldSlice(field) {
            assert_SOA(@src());
            self.assert_not_null(@src());
            const len_usize = num_cast(self.true_len_from_ptr(), usize);
            return field_chunk_ptr_never_null_known_true_len(self, len_usize, field)[0..self.len];
        }

        //**********
        // WINDOW/SUB-SLICE
        //**********

        pub fn grow_window_right(self: ListSlice, count: Idx) ListSlice {
            assert_not_allocated(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            var new_self = self;
            new_self.len += count;
        }

        pub fn grow_window_left(self: ListSlice, count: Idx) ListSlice {
            assert_not_SOA_or_start_offset(@src());
            assert_not_allocated(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            if (SOA) self.assert_start_offset_at_least(count, @src());
            const off_adj: Idx = if (OFFSET) @min(count, self.off) else 0;
            const ptr_adj: Idx = count - off_adj;
            var new_self = self;
            if (OFFSET) new_self.off -= off_adj;
            new_self.ptr = self.ptr_never_null() - ptr_adj;
            new_self.len += count;
            return new_self;
        }

        pub fn shrink_window_right(self: ListSlice, count: Idx) ListSlice {
            assert_not_allocated(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            self.assert_len_greater_or_equal_count(count, @src());
            var new_self = self;
            new_self.len -= count;
            return new_self;
        }

        pub fn shrink_window_left(self: ListSlice, count: Idx) ListSlice {
            assert_not_SOA_or_start_offset(@src());
            assert_not_allocated(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            self.assert_len_greater_or_equal_count(count, @src());
            var new_self = self;
            if (OFFSET) {
                new_self.off += count;
            } else {
                new_self.ptr = self.ptr_never_null() + count;
            }
            new_self.len -= count;
            return new_self;
        }

        pub fn shift_window_right(self: ListSlice, count: Idx) ListSlice {
            assert_not_SOA_or_start_offset(@src());
            assert_not_allocated(@src());
            self.assert_not_null(@src());
            var new_self = self;
            if (OFFSET) {
                new_self.off += count;
            } else {
                new_self.ptr = self.ptr_never_null() + count;
            }
        }

        pub fn shift_window_left(self: ListSlice, count: Idx) ListSlice {
            assert_not_SOA_or_start_offset(@src());
            assert_not_allocated(@src());
            self.assert_not_null(@src());
            if (SOA) self.assert_start_offset_at_least(count, @src());
            const off_adj: Idx = if (OFFSET) @min(count, self.off) else 0;
            const ptr_adj: Idx = count - off_adj;
            var new_self = self;
            if (OFFSET) new_self.off -= off_adj;
            new_self.ptr = self.ptr_never_null() - ptr_adj;
        }

        pub fn sub_slice_start_len(self: ListSlice, start: Idx, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            self.assert_start_plus_len_in_range(start, len, @src());
            const NewListSlice = ListSlice.with_sub_slice_mode(mode);
            if (NewListSlice.DEF.INCLUDE_START_OFFSET) {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null()),
                    .len = len,
                    .off = self.idx_start_offset() + start,
                };
            } else {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null() + start),
                    .len = len,
                };
            }
        }

        pub fn sub_slice_start_end(self: ListSlice, start: Idx, end_excluded: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            assert_start_and_end_in_order(start, end_excluded, @src());
            const len = end_excluded - start;
            self.assert_start_plus_len_in_range(start, len, @src());
            const NewListSlice = ListSlice.with_sub_slice_mode(mode);
            if (NewListSlice.DEF.INCLUDE_START_OFFSET) {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null()),
                    .len = len,
                    .off = self.idx_start_offset() + start,
                };
            } else {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null() + start),
                    .len = len,
                };
            }
        }

        pub fn sub_slice_from_start(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            self.assert_len_in_range(len, @src());
            const NewListSlice = ListSlice.with_sub_slice_mode(mode);
            if (NewListSlice.DEF.INCLUDE_START_OFFSET) {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null()),
                    .len = len,
                    .off = self.idx_start_offset(),
                };
            } else {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null()),
                    .len = len,
                };
            }
        }

        pub fn sub_slice_from_end(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            assert_not_SOA(@src());
            self.assert_not_null(@src());
            self.assert_len_in_range_from_end(len, @src());
            const diff = self.len - len;
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + diff),
                .len = len,
            };
        }

        pub fn new_slice_immediately_before(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            assert_not_SOA_or_start_offset(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            if (SOA) self.assert_start_offset_at_least(len, @src());
            const off_adj: Idx = if (OFFSET) @min(len, self.off) else 0;
            const ptr_adj: Idx = len - off_adj;
            const NewListSlice = ListSlice.with_sub_slice_mode(mode);
            if (NewListSlice.DEF.INCLUDE_START_OFFSET) {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null() - ptr_adj),
                    .len = len,
                    .off = self.idx_start_offset() - off_adj,
                };
            } else {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null() - len),
                    .len = len,
                };
            }
        }

        pub fn new_slice_immediately_after(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            assert_slice(@src());
            self.assert_not_null(@src());
            const NewListSlice = ListSlice.with_sub_slice_mode(mode);
            if (NewListSlice.DEF.INCLUDE_START_OFFSET) {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null()),
                    .len = len,
                    .off = self.idx_start_offset() + self.len,
                };
            } else {
                return NewListSlice{
                    .ptr = @ptrCast(self.ptr_never_null() + self.len),
                    .len = len,
                };
            }
        }

        //**********
        // GET/SET
        //**********

        pub fn get_item_ptr(self: ListSlice, idx: Idx) ElemPtr {
            assert_not_SOA(@src());
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            return &self.ptr_never_null()[self.true_idx_from_ptr(idx)];
        }

        pub fn get_last_item_ptr(self: ListSlice) ElemPtr {
            self.assert_not_empty(@src());
            return self.get_item_ptr(self.len - 1);
        }

        pub fn get_first_item_ptr(self: ListSlice) ElemPtr {
            self.assert_not_empty(@src());
            return self.get_item_ptr(0);
        }

        pub fn get_item_ptr_nth_from_end(self: ListSlice, nth_from_end: Idx) ElemPtr {
            self.assert_idx_in_range(nth_from_end, @src());
            return self.get_item_ptr(self.len - 1 - nth_from_end);
        }

        pub fn get_item(self: ListSlice, idx: Idx) T {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                var val: T = undefined;
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const len_usize = num_cast(self.true_len_from_ptr(), usize);
                const root_addr = @intFromPtr(self.byte_ptr_never_null());
                inline for (T_FIELD_DATA[0..], T_FIELD_OFFSETS[0..], T_FIELDS_ENUM_TAGS[0..]) |field, base_offset, tag| {
                    const field_chunk_offset = base_offset * len_usize;
                    const field_offset = root_addr + field_chunk_offset + (@sizeOf(field.type) * idx_usize);
                    const field_ptr: FieldPtr(tag) = @ptrFromInt(field_offset);
                    @field(val, field.name) = field_ptr.*;
                }
                return val;
            } else {
                return self.ptr_never_null()[self.true_idx_from_ptr(idx)];
            }
        }

        pub fn get_last_item(self: ListSlice) T {
            self.assert_not_empty(@src());
            return self.get_item(self.len - 1);
        }

        pub fn get_first_item(self: ListSlice) T {
            self.assert_not_empty(@src());
            return self.get_item(0);
        }

        pub fn get_item_nth_from_end(self: ListSlice, nth_from_end: Idx) T {
            self.assert_not_empty(@src());
            return self.get_item(self.len - 1 - nth_from_end);
        }

        pub fn get_item_field(self: ListSlice, comptime field: FieldEnum, idx: Idx) FieldType(field) {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const field_chunk = self.field_chunk_ptr_never_null(field);
                const field_ptr: FieldPtr(field) = &field_chunk[idx_usize];
                return field_ptr.*;
            } else {
                return @field(self.ptr_never_null()[self.true_idx_from_ptr(idx)], @tagName(field));
            }
        }

        pub fn get_last_item_field(self: ListSlice, comptime field: FieldEnum) FieldType(field) {
            self.assert_not_empty(@src());
            return self.get_item_field(field, self.len - 1);
        }

        pub fn get_first_item_field(self: ListSlice, comptime field: FieldEnum) FieldType(field) {
            self.assert_not_empty(@src());
            return self.get_item_field(field, 0);
        }

        pub fn get_item_field_nth_from_end(self: ListSlice, comptime field: FieldEnum, nth_from_end: Idx) FieldType(field) {
            self.assert_idx_in_range(nth_from_end, @src());
            return self.get_item_field(field, self.len - 1 - nth_from_end);
        }

        pub fn get_item_field_ptr(self: ListSlice, comptime field: FieldEnum, idx: Idx) FieldPtr(field) {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const field_chunk = self.field_chunk_ptr_never_null(field);
                const field_ptr: FieldPtr(field) = &field_chunk[idx_usize];
                return field_ptr;
            } else {
                return &@field(&self.ptr_never_null()[self.true_idx_from_ptr(idx)], @tagName(field));
            }
        }

        pub fn get_last_item_field_ptr(self: ListSlice, comptime field: FieldEnum) FieldPtr(field) {
            self.assert_not_empty(@src());
            return self.get_item_field_ptr(field, self.len - 1);
        }

        pub fn get_first_item_field_ptr(self: ListSlice, comptime field: FieldEnum) FieldPtr(field) {
            self.assert_not_empty(@src());
            return self.get_item_field_ptr(field, 0);
        }

        pub fn get_item_field_ptr_nth_from_end(self: ListSlice, comptime field: FieldEnum, nth_from_end: Idx) FieldPtr(field) {
            self.assert_idx_in_range(nth_from_end, @src());
            return self.get_item_field_ptr(field, self.len - 1 - nth_from_end);
        }

        pub fn set_item(self: ListSlice, idx: Idx, val: T) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const len_usize = num_cast(self.true_len_from_ptr(), usize);
                inline for (T_FIELD_DATA[0..]) |field| {
                    const field_chunk = self.field_chunk_ptr_never_null_known_true_len(len_usize, field);
                    const field_ptr: FieldPtr(field) = &field_chunk[idx_usize];
                    field_ptr.* = @field(val, field.name);
                }
            } else {
                self.ptr_never_null()[self.true_idx_from_ptr(idx)] = val;
            }
        }

        pub fn set_last_item(self: ListSlice, val: T) void {
            self.assert_not_empty(@src());
            self.set_item(self.len - 1, val);
        }

        pub fn set_first_item(self: ListSlice, val: T) void {
            self.assert_not_empty(@src());
            self.set_item(0, val);
        }

        pub fn set_item_nth_from_end(self: ListSlice, nth_from_end: Idx, val: T) void {
            self.assert_idx_in_range(nth_from_end, @src());
            self.set_item(self.len - 1 - nth_from_end, val);
        }

        pub fn set_item_field(self: ListSlice, comptime field: FieldEnum, idx: Idx, val: FieldType(field)) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const field_chunk = self.field_chunk_ptr_never_null(field);
                const field_ptr: FieldPtr(field) = &field_chunk[idx_usize];
                field_ptr.* = val;
            } else {
                @field(&self.ptr_never_null()[self.true_idx_from_ptr(idx)], @tagName(field)).* = val;
            }
        }

        pub fn set_last_item_field(self: ListSlice, comptime field: FieldEnum, val: FieldType(field)) void {
            self.assert_not_empty(@src());
            self.set_item_field(field, self.len - 1, val);
        }

        pub fn set_first_item_field(self: ListSlice, comptime field: FieldEnum, val: FieldType(field)) void {
            self.assert_not_empty(@src());
            self.set_item_field(field, 0, val);
        }

        pub fn set_item_field_nth_from_end(self: ListSlice, comptime field: FieldEnum, nth_from_end: Idx, val: FieldType(field)) void {
            self.assert_idx_in_range(nth_from_end, @src());
            self.set_item_field(field, self.len - 1 - nth_from_end, val);
        }

        pub fn set_item_volatile(self: ListSlice, idx: Idx, val: T) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            if (SOA) {
                const idx_usize = num_cast(self.true_idx_from_ptr(idx), usize);
                const len_usize = num_cast(self.true_len_from_ptr(), usize);
                inline for (T_FIELD_DATA[0..]) |field| {
                    const field_chunk = self.field_chunk_ptr_never_null_known_true_len(len_usize, field);
                    const field_ptr: FieldPtr(field) = &field_chunk[idx_usize];
                    field_ptr.* = @field(val, field.name);
                }
            } else {
                self.ptr_never_null_volatile()[self.true_idx_from_ptr(idx)] = val;
            }
        }

        //**********
        // MEMCOPY/MEMSET
        //**********

        pub fn memcopy_to(self: ListSlice, dest: anytype) void {
            const DEST = @TypeOf(dest);
            self.assert_not_null(@src());
            either_soa: switch (DEF.MEM_PARADIGM) {
                .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => {
                    var i: Idx = 0;
                    while (i < self.len) : (i += 1) {
                        const val = self.get_item(i);
                        if (type_is_GooListSlice(DEST)) {
                            dest.set_item(i, val);
                        } else {
                            dest[i] = val;
                        }
                    }
                },
                .OBJECTS_STORED_WHOLE => {
                    if (type_is_GooListSlice(DEST)) {
                        if (DEST.DEF.MEM_PARADIGM == MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) continue :either_soa .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS;
                        @memcpy(dest.to_slice_never_null(), self.to_slice_never_null());
                    } else {
                        @memcpy(dest, self.to_slice_never_null());
                    }
                },
            }
        }

        pub fn memcopy_from(self: ListSlice, source: anytype) void {
            assert_mutable(@src());
            const SRC = @TypeOf(source);
            self.assert_not_null(@src());
            either_soa: switch (DEF.MEM_PARADIGM) {
                .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS => {
                    var i: Idx = 0;
                    while (i < self.len) : (i += 1) {
                        const val = if (type_is_GooListSlice(SRC)) source.get_item(i) else source[i];
                        self.set_item(i, val);
                    }
                },
                .OBJECTS_STORED_WHOLE => {
                    if (type_is_GooListSlice(SRC)) {
                        if (SRC.DEF.MEM_PARADIGM == MemoryParadigm.OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS) continue :either_soa .OBJECT_FIELDS_STORED_IN_SEPARATE_REGIONS;
                        @memcpy(self.to_slice_never_null(), source.to_slice_never_null());
                    } else {
                        @memcpy(self.to_slice_never_null(), source);
                    }
                },
            }
        }

        pub fn memset(self: ListSlice, val: T) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            if (SOA) {
                var i: Idx = 0;
                while (i < self.len) : (i += 1) {
                    self.set_item(i, val);
                }
            } else {
                @memset(self.to_slice_never_null(), val);
            }
        }

        pub fn secure_memset_zero(self: ListSlice) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            if (SOA) {
                var i: Idx = 0;
                while (i < self.len) : (i += 1) {
                    self.set_item_volatile(i, 0);
                }
            } else {
                util_secure_zero(T, self.to_slice_never_null());
            }
        }

        pub fn secure_memset_undefined(self: ListSlice) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            if (SOA) {
                var i: Idx = 0;
                while (i < self.len) : (i += 1) {
                    self.set_item_volatile(i, undefined);
                }
            } else {
                util_secure_memset_undefined(T, self.to_slice_never_null());
            }
        }

        pub fn secure_memset(self: ListSlice, val: T) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            if (SOA) {
                var i: Idx = 0;
                while (i < self.len) : (i += 1) {
                    self.set_item_volatile(i, val);
                }
            } else {
                util_secure_memset(T, self.to_slice_never_null(), val);
            }
        }

        //**********
        // DATA MOVEMENT
        //**********

        pub fn copy_rightward(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            assert_slice(@src());
            assert_mutable(@src());
            self.assert_not_null(@src());
            const new_self = self.shift_window_right(n_positions_to_the_right);
            if (n_positions_to_the_right > self.len) {
                @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_self;
        }

        pub fn copy_rightward_never_overlaps(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            assert_mutable(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            const new_self = self.shift_window_right(n_positions_to_the_right);
            @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            return new_self;
        }

        pub fn copy_rightward_always_overlaps(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            assert_mutable(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            const new_self = self.shift_window_right(n_positions_to_the_right);
            @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            return new_self;
        }

        pub fn copy_leftward(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            assert_mutable(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            const new_self = self.shift_window_left(n_positions_to_the_left);
            if (n_positions_to_the_left > self.len) {
                @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_self;
        }

        pub fn copy_leftward_never_overlaps(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            assert_mutable(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            const new_slice = self.shift_window_left(n_positions_to_the_left);
            @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }

        pub fn copy_leftward_always_overlaps(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            assert_mutable(@src());
            assert_slice(@src());
            self.assert_not_null(@src());
            const new_slice = self.shift_window_left(n_positions_to_the_left);
            @memmove(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }

        pub fn swap(self: ListSlice, idx_a: Idx, idx_b: Idx) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const a_val: T = self.get_item(idx_a);
            self.set_item(idx_a, self.get_item(idx_b));
            self.set_item(idx_b, a_val);
        }

        pub fn reverse(self: ListSlice) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            Utils.Mem.reverse_slice(self.to_slice_never_null());
        }

        pub fn move_one_and_preserve_displaced(self: ListSlice, old_index: Idx, new_index: Idx) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(old_index, @src());
            self.assert_idx_in_range(new_index, @src());
            assert_mutable(@src());
            Utils.Mem.move_one_and_preserve_displaced(self.ptr_never_null(), old_index, new_index);
        }

        pub fn move_range_and_preserve_displaced(self: ListSlice, first_index_to_move: Idx, indexes_to_move_end_excluded: Idx, index_to_place_elements: Idx) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(first_index_to_move, @src());
            self.assert_len_in_range(indexes_to_move_end_excluded, @src());
            self.assert_start_plus_len_in_range(index_to_place_elements, indexes_to_move_end_excluded - first_index_to_move, @src());
            Utils.Mem.move_range_and_preserve_displaced(self.ptr_never_null(), first_index_to_move, indexes_to_move_end_excluded, index_to_place_elements);
        }

        pub fn rotate_left(self: ListSlice, delta_left: Idx) void {
            self.assert_not_null(@src());
            const delta_left_mod = @mod(delta_left, self.len);
            if (delta_left_mod == 0) {
                @branchHint(.unlikely);
                return;
            }
            Utils.Mem.reverse_slice(self.ptr_never_null()[0..delta_left_mod]);
            Utils.Mem.reverse_slice(self.ptr_never_null()[delta_left_mod..self.len]);
            Utils.Mem.reverse_slice(self.ptr_never_null()[0..self.len]);
        }

        pub fn rotate_right(self: ListSlice, delta_right: Idx) void {
            self.assert_not_null(@src());
            var delta_right_mod = @mod(delta_right, self.len);
            if (delta_right_mod == 0) {
                @branchHint(.unlikely);
                return;
            }
            delta_right_mod = self.len - delta_right_mod;
            Utils.Mem.reverse_slice(self.ptr_never_null()[0..delta_right_mod]);
            Utils.Mem.reverse_slice(self.ptr_never_null()[delta_right_mod..self.len]);
            Utils.Mem.reverse_slice(self.ptr_never_null()[0..self.len]);
        }

        //**********
        // SEARCH
        //**********

        pub fn search_for_item_implicit(self: ListSlice, search_val: anytype) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_implicit(self.ptr_never_null(), 0, self.len, search_val, Idx);
        }

        pub fn search_for_item_with_func(self: ListSlice, search_param: anytype, match_fn: *const CompareFunc(@TypeOf(search_param), T)) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, Idx);
        }

        pub fn search_for_item_with_func_and_userdata(self: ListSlice, search_param: anytype, userdata: anytype, match_fn: *const CompareFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) ?Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, Idx);
        }

        /// Returns number of indexes found and appended to output buffer
        pub fn search_for_many_items_implicit(self: ListSlice, search_vals: anytype, search_vals_order: Utils.Mem.LinearSearchOrder, output_buffer: anytype) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_for_many_implicit(self.ptr_never_null(), 0, self.len, search_vals, search_vals_order, output_buffer, Idx);
        }

        /// Returns number of indexes found and appended to output buffer
        pub fn search_for_many_items_with_func(self: ListSlice, search_vals: anytype, search_vals_order: Utils.Mem.LinearSearchOrder, output_buffer: anytype, match_fn: *const CompareFunc(Types.IndexableChild(@TypeOf(search_vals)), T)) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_for_many_with_func(self.ptr_never_null(), 0, self.len, search_vals, search_vals_order, match_fn, output_buffer, Idx);
        }

        /// Returns number of indexes found and appended to output buffer
        pub fn search_for_many_items_with_func_and_userdata(self: ListSlice, userdata: anytype, search_vals: anytype, search_vals_order: Utils.Mem.LinearSearchOrder, output_buffer: anytype, match_fn: *const CompareFunc(Types.IndexableChild(@TypeOf(search_vals)), T, @TypeOf(userdata))) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.search_for_many_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_vals, search_vals_order, userdata, match_fn, output_buffer, Idx);
        }

        pub const BinarySearchResult = Utils.Mem.BinarySerachResult(Idx);

        pub fn binary_search_for_item_implicit(self: ListSlice, find_val: anytype) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_implicit(self.ptr_never_null(), 0, self.len, find_val, Idx);
        }

        pub fn binary_search_for_item_idx_with_func(self: ListSlice, search_param: anytype, match_fn: *const CompareFunc(@TypeOf(search_param), T), less_than_fn: *const CompareFunc(@TypeOf(search_param), T)) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_with_func(self.ptr_never_null(), 0, self.len, search_param, match_fn, less_than_fn, Idx);
        }

        pub fn binary_search_for_item_idx_with_func_and_userdata(self: ListSlice, search_param: anytype, userdata: anytype, match_fn: *const CompareFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata)), less_than_fn: *const CompareFuncUserdata(@TypeOf(search_param), T, @TypeOf(userdata))) BinarySearchResult {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_param, userdata, match_fn, less_than_fn, Idx);
        }

        pub fn binary_search_for_many_items_implicit(self: ListSlice, search_vals: anytype, search_vals_order: Utils.Mem.BinarySearchOrder, output_buffer: anytype) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_many_implicit(self.ptr_never_null(), 0, self.len, search_vals, search_vals_order, output_buffer, Idx);
        }

        pub fn binary_search_for_many_items_idx_with_func(self: ListSlice, search_params: anytype, search_params_order: Utils.Mem.BinarySearchOrder, match_fn: *const CompareFunc(Types.IndexableChild(@TypeOf(search_params)), T), less_than_fn: *const CompareFunc(Types.IndexableChild(@TypeOf(search_params)), T), output_buffer: anytype) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_many_with_func(self.ptr_never_null(), 0, self.len, search_params, search_params_order, match_fn, less_than_fn, output_buffer, Idx);
        }

        pub fn binary_search_for_many_items_idx_with_func_and_userdata(self: ListSlice, search_params: anytype, search_params_order: Utils.Mem.BinarySearchOrder, userdata: anytype, match_fn: *const CompareFuncUserdata(Types.IndexableChild(@TypeOf(search_params)), T, @TypeOf(userdata)), less_than_fn: *const CompareFuncUserdata(Types.IndexableChild(@TypeOf(search_params)), T, @TypeOf(userdata)), output_buffer: anytype) Idx {
            self.assert_not_null(@src());
            return Utils.Mem.binary_search_many_with_func_and_userdata(self.ptr_never_null(), 0, self.len, search_params, search_params_order, userdata, match_fn, less_than_fn, output_buffer, Idx);
        }

        //**********
        // SORTING
        //**********

        pub fn insertion_sort_implicit(self: *ListSlice) void {
            self.assert_not_null(@src());
            Root.Sort.InsertionSort.insertion_sort_implicit(self.ptr_never_null()[0..self.len]);
        }

        pub fn insertion_sort_with_func(self: *ListSlice, greater_than_fn: *const Utils.Mem.CompareFunc(T, T)) void {
            self.assert_not_null(@src());
            Root.Sort.InsertionSort.insertion_sort_with_func(self.ptr_never_null()[0..self.len], greater_than_fn);
        }

        pub fn insertion_sort_with_func_and_userdata(self: *ListSlice, userdata: anytype, greater_than_fn: *const Utils.Mem.CompareFuncUserdata(T, T, @TypeOf(userdata))) void {
            self.assert_not_null(@src());
            Root.Sort.InsertionSort.insertion_sort_with_func_and_userdata(self.ptr_never_null()[0..self.len], userdata, greater_than_fn);
        }

        pub fn is_sorted_implicit(self: ListSlice) bool {
            self.assert_not_null(@src());
            return Root.Sort.is_sorted_implicit(self.ptr_never_null(), 0, self.len);
        }

        pub fn is_sorted_with_func(self: ListSlice, greater_than_fn: *const Utils.Mem.CompareFunc(T, T)) bool {
            self.assert_not_null(@src());
            return Root.Sort.is_sorted_with_func(self.ptr_never_null(), 0, self.len, greater_than_fn);
        }

        pub fn is_sorted_with_func_and_userdata(self: ListSlice, userdata: anytype, greater_than_fn: *const Utils.Mem.CompareFuncUserdata(T, T, @TypeOf(userdata))) bool {
            self.assert_not_null(@src());
            return Root.Sort.is_sorted_with_func_and_userdata(self.ptr_never_null(), 0, self.len, userdata, greater_than_fn);
        }

        //**********
        // REALLOC
        //**********

        pub fn free(self: ListSlice, alloc: Allocator) ListSlice {
            self.realloc_exact(0, alloc);
            return ListSlice{};
        }

        pub fn in_place_free(self: *ListSlice, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.free(alloc);
            self.* = self_val;
        }

        pub fn ensure_free_slots(self: ListSlice, needed_free_slots: Idx, alloc: Allocator) ListSlice {
            return self.ensure_free_slots_custom_settings(
                needed_free_slots,
                alloc,
                .{ .grow_mode = .GROW_BY_50_PERCENT, .clear_old_mode = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
                .{ .GROW_MODE = .GROW_BY_50_PERCENT, .CLEAR_OLD_MODE = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
            );
        }

        pub fn ensure_free_slots_custom_grow(self: ListSlice, needed_free_slots: Idx, alloc: Allocator, grow: GrowthModel, comptime grow_comptime_known: ?GrowthModel) ListSlice {
            return self.ensure_free_slots_custom_settings(
                needed_free_slots,
                alloc,
                .{ .grow_mode = grow, .clear_old_mode = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
                .{ .GROW_MODE = grow_comptime_known, .CLEAR_OLD_MODE = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
            );
        }
        pub fn ensure_free_slots_custom_settings(self: ListSlice, needed_free_slots: Idx, alloc: Allocator, settings: AllocSettings, comptime settings_comptime: ?AllocSettingsComptime) ListSlice {
            assert_list(@src());
            const new_len = self.len + needed_free_slots;
            if (new_len <= self.cap) return;
            assert_allocated(@src());
            var new_self = self;
            Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, new_len, settings, settings_comptime);
            return new_self;
        }

        pub fn in_place_ensure_free_slots(self: *ListSlice, needed_free_slots: Idx, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.ensure_free_slots(needed_free_slots, alloc);
            self.* = self_val;
        }

        pub fn in_place_ensure_free_slots_custom_grow(self: *ListSlice, needed_free_slots: Idx, alloc: Allocator, grow: GrowthModel, comptime grow_comptime_known: ?GrowthModel) void {
            var self_val = self.*;
            self_val = self_val.ensure_free_slots_custom_grow(needed_free_slots, alloc, grow, grow_comptime_known);
            self.* = self_val;
        }
        pub fn in_place_ensure_free_slots_custom_settings(self: *ListSlice, needed_free_slots: Idx, alloc: Allocator, settings: AllocSettings, comptime settings_comptime: ?AllocSettingsComptime) void {
            var self_val = self.*;
            self_val = self_val.ensure_free_slots_custom_settings(needed_free_slots, alloc, settings, settings_comptime);
            self.* = self_val;
        }

        pub fn shrink_cap_reserve_at_most(self: ListSlice, at_most_n_free_slots: Idx, alloc: Allocator) ListSlice {
            assert_list(@src());
            const curr_free = self.cap - self.len;
            if (curr_free <= at_most_n_free_slots) return self;
            assert_allocated(@src());
            const new_cap = self.len + at_most_n_free_slots;
            var new_self = self;
            Utils.Alloc.smart_alloc_ptr_ptrs(
                alloc,
                &new_self.ptr,
                &new_self.cap,
                @intCast(new_cap),
                .{ .clear_old_mode = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
                .{ .CLEAR_OLD_MODE = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD },
            );
            return new_self;
        }

        pub fn in_place_shrink_cap_reserve_at_most(self: *ListSlice, at_most_n_free_slots: Idx, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.shrink_cap_reserve_at_most(at_most_n_free_slots, alloc);
            self.* = self_val;
        }

        pub fn realloc_exact(self: ListSlice, new_capacity: Idx, alloc: Allocator) ListSlice {
            return self.realloc_exact_custom_settings(new_capacity, alloc, .{ .clear_old_mode = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD }, .{ .CLEAR_OLD_MODE = if (DEF.SECURE_ZERO_FREED_MEMORY) .MEMSET_OLD_ZERO else .DONT_MEMSET_OLD });
        }

        pub fn realloc_exact_custom_settings(self: ListSlice, new_capacity: Idx, alloc: Allocator, settings: AllocSettings, comptime settings_comptime: ?AllocSettingsComptime) ListSlice {
            assert_allocated(@src());
            var new_self = self;
            if (IS_LIST) {
                Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, @intCast(new_capacity), settings, settings_comptime);
                new_self.len = @min(self.len, new_self.cap);
            } else {
                Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.len, @intCast(new_capacity), settings, settings_comptime);
            }
            return new_self;
        }

        pub fn in_place_realloc_exact(self: *ListSlice, new_capacity: Idx, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.realloc_exact(new_capacity, alloc);
            self.* = self_val;
        }

        pub fn in_place_realloc_exact_custom_settings(self: *ListSlice, new_capacity: Idx, alloc: Allocator, settings: AllocSettings, comptime settings_comptime: ?AllocSettingsComptime) void {
            var self_val = self.*;
            self_val = self_val.realloc_exact_custom_settings(new_capacity, alloc, settings, settings_comptime);
            self.* = self_val;
        }

        //**********
        // UNIVERSAL APPEND/INSERT
        //**********

        fn expand_internal(
            comptime origin_in_place: OriginInPlace,
            self: if (origin_in_place == .RET_NEW) ListSlice else *ListSlice,
            comptime origin_count: OriginFuncCount,
            count: Idx,
            comptime origin_alloc: OriginFuncAllocAssume,
            alloc: if (origin_alloc == .REALLOCATE) Allocator else void,
            comptime origin_return: OriginFuncReturn,
            comptime origin_set: OriginFuncSetVal,
            vals: if (origin_set == .SET_VALS) (if (origin_count == .ONE) T else []const T) else void,
            comptime origin_loc: OriginFuncValSetLoc,
            insert_idx: if (origin_loc == .INSERT) Idx else void,
        ) return_type: {
            break :return_type switch (origin_in_place) {
                .RET_NEW => switch (origin_return) {
                    .SELF_ONLY => ListSlice,
                    .IDX => switch (origin_count) {
                        .ONE => struct { ListSlice, Idx },
                        .MANY => struct { ListSlice, Idx, Idx },
                    },
                    .REF => switch (origin_count) {
                        .ONE => struct { ListSlice, ElemPtr },
                        .MANY => struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) },
                    },
                },
                .IN_PLACE => switch (origin_return) {
                    .SELF_ONLY => void,
                    .IDX => switch (origin_count) {
                        .ONE => Idx,
                        .MANY => struct { Idx, Idx },
                    },
                    .REF => switch (origin_count) {
                        .ONE => ElemPtr,
                        .MANY => ListSlice.with_sub_slice_mode(.STATIC),
                    },
                },
            };
        } {
            var new_self = if (origin_in_place == .RET_NEW) self else self.*;
            const old_len = new_self.len;
            const real_count: Idx = if (origin_count == .ONE) 1 else count;
            switch (origin_alloc) {
                .ASSUME_CAPACITY => {
                    self.assert_not_null(@src());
                    if (IS_LIST) {
                        new_self.assert_len_n_less_than_cap(count, @src());
                    }
                },
                .REALLOCATE => {
                    if (IS_LIST) {
                        new_self = new_self.ensure_free_slots(real_count, alloc);
                    } else {
                        new_self = new_self.realloc_exact(self.len + real_count, alloc);
                    }
                },
            }
            const first_new_idx = switch (origin_loc) {
                .APPEND => if (IS_LIST) new_self.len else new_self.len - real_count,
                .INSERT => insert_idx,
            };
            if (IS_LIST) new_self.len += real_count;
            const last_idx = switch (origin_loc) {
                .APPEND => new_self.len,
                .INSERT => insert_idx + real_count,
            };
            if (origin_loc == .INSERT and last_idx < new_self.len) {
                @branchHint(.likely);
                assert_mutable(@src());
                @memmove(self.ptr_never_null()[first_new_idx + real_count .. new_self.len], self.ptr_never_null()[first_new_idx..old_len]);
            }
            switch (origin_set) {
                .EMPTY_SLOTS => {},
                .SET_VALS => {
                    assert_mutable(@src());
                    switch (origin_count) {
                        .ONE => {
                            new_self.ptr_never_null()[first_new_idx] = vals;
                        },
                        .MANY => {
                            @memcpy(new_self.ptr_never_null()[first_new_idx..last_idx], vals);
                        },
                    }
                },
            }
            if (origin_in_place == .IN_PLACE) {
                self.* = new_self;
            }
            return switch (origin_in_place) {
                .RET_NEW => switch (origin_return) {
                    .SELF_ONLY => new_self,
                    .IDX => switch (origin_count) {
                        .ONE => .{ new_self, first_new_idx },
                        .MANY => .{ new_self, first_new_idx, last_idx },
                    },
                    .REF => switch (origin_count) {
                        .ONE => .{ new_self, new_self.get_item_ptr(first_new_idx) },
                        .MANY => .{ new_self, new_self.sub_slice_start_end(first_new_idx, last_idx, .STATIC) },
                    },
                },
                .IN_PLACE => switch (origin_return) {
                    .SELF_ONLY => void{},
                    .IDX => switch (origin_count) {
                        .ONE => first_new_idx,
                        .MANY => struct { first_new_idx, last_idx },
                    },
                    .REF => switch (origin_count) {
                        .ONE => new_self.get_item_ptr(first_new_idx),
                        .MANY => new_self.sub_slice_start_end(first_new_idx, last_idx, .STATIC),
                    },
                },
            };
        }

        //**********
        // APPEND
        //**********

        pub fn append_one_empty_slot_assume_capacity_get_idx(self: ListSlice) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_empty_slot_assume_capacity_get_elem_ptr(self: ListSlice) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_empty_slot_assume_capacity(self: ListSlice) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots_assume_capacity_get_idx_range(self: ListSlice, count: Idx) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots_assume_capacity_get_sub_slice(self: ListSlice, count: Idx) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots_assume_capacity(self: ListSlice, count: Idx) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_empty_slot_get_idx(self: ListSlice, alloc: Allocator) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_empty_slot_get_elem_ptr(self: ListSlice, alloc: Allocator) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_empty_slot(self: ListSlice, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots_get_idx_range(self: ListSlice, count: Idx, alloc: Allocator) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots_get_sub_slice(self: ListSlice, count: Idx, alloc: Allocator) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_many_empty_slots(self: ListSlice, count: Idx, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn append_one_item_assume_capacity_get_idx(self: ListSlice, item: T) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_one_item_assume_capacity_get_elem_ptr(self: ListSlice, item: T) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_one_item_assume_capacity(self: ListSlice, item: T) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_one_item_get_idx(self: ListSlice, item: T, alloc: Allocator) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_one_item_get_elem_ptr(self: ListSlice, item: T, alloc: Allocator) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .REF, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_one_item(self: ListSlice, item: T, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, item, .APPEND, void{});
        }

        pub fn append_many_items_assume_capacity_get_idx_range(self: ListSlice, items: []const T) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .IDX, .SET_VALS, items, .APPEND, void{});
        }

        pub fn append_many_items_assume_capacity_get_sub_slice(self: ListSlice, items: []const T) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .REF, .SET_VALS, items, .APPEND, void{});
        }

        pub fn append_many_items_assume_capacity(self: ListSlice, items: []const T) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .SELF_ONLY, .SET_VALS, items, .APPEND, void{});
        }

        pub fn append_many_items_get_idx_range(self: ListSlice, items: []const T, alloc: Allocator) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .IDX, .SET_VALS, items, .APPEND, void{});
        }

        pub fn append_many_items_get_sub_slice(self: ListSlice, items: []const T, alloc: Allocator) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .REF, .SET_VALS, items, .APPEND, void{});
        }

        pub fn append_many_items(self: ListSlice, items: []const T, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, items, .APPEND, void{});
        }

        //**********
        // APPEND IN-PLACE
        //**********

        pub fn in_place_append_one_empty_slot_assume_capacity_get_idx(self: *ListSlice) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_empty_slot_assume_capacity_get_elem_ptr(self: *ListSlice) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_empty_slot_assume_capacity(self: *ListSlice) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots_assume_capacity_get_idx_range(self: *ListSlice, count: Idx) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots_assume_capacity_get_sub_slice(self: *ListSlice, count: Idx) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots_assume_capacity(self: *ListSlice, count: Idx) void {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_empty_slot_get_idx(self: *ListSlice, alloc: Allocator) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_empty_slot_get_elem_ptr(self: *ListSlice, alloc: Allocator) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_empty_slot(self: *ListSlice, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots_get_idx_range(self: *ListSlice, count: Idx, alloc: Allocator) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots_get_sub_slice(self: *ListSlice, count: Idx, alloc: Allocator) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_many_empty_slots(self: *ListSlice, count: Idx, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .APPEND, void{});
        }

        pub fn in_place_append_one_item_assume_capacity_get_idx(self: *ListSlice, item: T) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_one_item_assume_capacity_get_elem_ptr(self: *ListSlice, item: T) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_one_item_assume_capacity(self: *ListSlice, item: T) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_one_item_get_idx(self: *ListSlice, item: T, alloc: Allocator) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_one_item_get_elem_ptr(self: *ListSlice, item: T, alloc: Allocator) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .REF, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_one_item(self: *ListSlice, item: T, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, item, .APPEND, void{});
        }

        pub fn in_place_append_many_items_assume_capacity_get_idx_range(self: *ListSlice, items: []const T) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .IDX, .SET_VALS, items, .APPEND, void{});
        }

        pub fn in_place_append_many_items_assume_capacity_get_sub_slice(self: *ListSlice, items: []const T) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .REF, .SET_VALS, items, .APPEND, void{});
        }

        pub fn in_place_append_many_items_assume_capacity(self: *ListSlice, items: []const T) void {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .SELF_ONLY, .SET_VALS, items, .APPEND, void{});
        }

        pub fn in_place_append_many_items_get_idx_range(self: *ListSlice, items: []const T, alloc: Allocator) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .IDX, .SET_VALS, items, .APPEND, void{});
        }

        pub fn in_place_append_many_items_get_sub_slice(self: *ListSlice, items: []const T, alloc: Allocator) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .REF, .SET_VALS, items, .APPEND, void{});
        }

        pub fn in_place_append_many_items(self: *ListSlice, items: []const T, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, items, .APPEND, void{});
        }

        //**********
        // INSERT
        //**********

        pub fn insert_one_empty_slot_assume_capacity_get_idx(self: ListSlice, idx: Idx) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_empty_slot_assume_capacity_get_elem_ptr(self: ListSlice, idx: Idx) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_empty_slot_assume_capacity(self: ListSlice, idx: Idx) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots_assume_capacity_get_idx_range(self: ListSlice, idx: Idx, count: Idx) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots_assume_capacity_get_sub_slice(self: ListSlice, idx: Idx, count: Idx) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots_assume_capacity(self: ListSlice, idx: Idx, count: Idx) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, count, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_empty_slot_get_idx(self: ListSlice, idx: Idx, alloc: Allocator) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_empty_slot_get_elem_ptr(self: ListSlice, idx: Idx, alloc: Allocator) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_empty_slot(self: ListSlice, idx: Idx, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots_get_idx_range(self: ListSlice, idx: Idx, count: Idx, alloc: Allocator) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots_get_sub_slice(self: ListSlice, idx: Idx, count: Idx, alloc: Allocator) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_many_empty_slots(self: ListSlice, idx: Idx, count: Idx, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, count, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn insert_one_item_assume_capacity_get_idx(self: ListSlice, idx: Idx, item: T) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_one_item_assume_capacity_get_elem_ptr(self: ListSlice, idx: Idx, item: T) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_one_item_assume_capacity(self: ListSlice, idx: Idx, item: T) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_one_item_get_idx(self: ListSlice, idx: Idx, item: T, alloc: Allocator) struct { ListSlice, Idx } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_one_item_get_elem_ptr(self: ListSlice, idx: Idx, item: T, alloc: Allocator) struct { ListSlice, ElemPtr } {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .REF, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_one_item(self: ListSlice, idx: Idx, item: T, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, item, .INSERT, idx);
        }

        pub fn insert_many_items_assume_capacity_get_idx_range(self: ListSlice, idx: Idx, items: []const T) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .IDX, .SET_VALS, items, .INSERT, idx);
        }

        pub fn insert_many_items_assume_capacity_get_sub_slice(self: ListSlice, idx: Idx, items: []const T) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .REF, .SET_VALS, items, .INSERT, idx);
        }

        pub fn insert_many_items_assume_capacity(self: ListSlice, idx: Idx, items: []const T) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .SELF_ONLY, .SET_VALS, items, .INSERT, idx);
        }

        pub fn insert_many_items_get_idx_range(self: ListSlice, idx: Idx, items: []const T, alloc: Allocator) struct { ListSlice, Idx, Idx } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .IDX, .SET_VALS, items, .INSERT, idx);
        }

        pub fn insert_many_items_get_sub_slice(self: ListSlice, idx: Idx, items: []const T, alloc: Allocator) struct { ListSlice, ListSlice.with_sub_slice_mode(.STATIC) } {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .REF, .SET_VALS, items, .INSERT, idx);
        }

        pub fn insert_many_items(self: ListSlice, idx: Idx, items: []const T, alloc: Allocator) ListSlice {
            return expand_internal(.RET_NEW, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, items, .INSERT, idx);
        }

        //**********
        // INSERT IN-PLACE
        //**********

        pub fn in_place_insert_one_empty_slot_assume_capacity_get_idx(self: *ListSlice, idx: Idx) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_empty_slot_assume_capacity_get_elem_ptr(self: *ListSlice, idx: Idx) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_empty_slot_assume_capacity(self: *ListSlice, idx: Idx) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots_assume_capacity_get_idx_range(self: *ListSlice, idx: Idx, count: Idx) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots_assume_capacity_get_sub_slice(self: *ListSlice, idx: Idx, count: Idx) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots_assume_capacity(self: *ListSlice, idx: Idx, count: Idx) void {
            return expand_internal(.IN_PLACE, self, .MANY, count, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_empty_slot_get_idx(self: *ListSlice, idx: Idx, alloc: Allocator) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_empty_slot_get_elem_ptr(self: *ListSlice, idx: Idx, alloc: Allocator) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_empty_slot(self: *ListSlice, idx: Idx, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots_get_idx_range(self: *ListSlice, idx: Idx, count: Idx, alloc: Allocator) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .IDX, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots_get_sub_slice(self: *ListSlice, idx: Idx, count: Idx, alloc: Allocator) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .REF, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_many_empty_slots(self: *ListSlice, idx: Idx, count: Idx, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .MANY, count, .REALLOCATE, alloc, .SELF_ONLY, .EMPTY_SLOTS, void{}, .INSERT, idx);
        }

        pub fn in_place_insert_one_item_assume_capacity_get_idx(self: *ListSlice, idx: Idx, item: T) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .IDX, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_one_item_assume_capacity_get_elem_ptr(self: *ListSlice, idx: Idx, item: T) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .REF, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_one_item_assume_capacity(self: *ListSlice, idx: Idx, item: T) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .ASSUME_CAPACITY, void{}, .SELF_ONLY, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_one_item_get_idx(self: *ListSlice, idx: Idx, item: T, alloc: Allocator) Idx {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .IDX, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_one_item_get_elem_ptr(self: *ListSlice, idx: Idx, item: T, alloc: Allocator) ElemPtr {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .REF, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_one_item(self: *ListSlice, idx: Idx, item: T, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .ONE, 1, .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, item, .INSERT, idx);
        }

        pub fn in_place_insert_many_items_assume_capacity_get_idx_range(self: *ListSlice, idx: Idx, items: []const T) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .IDX, .SET_VALS, items, .INSERT, idx);
        }

        pub fn in_place_insert_many_items_assume_capacity_get_sub_slice(self: *ListSlice, idx: Idx, items: []const T) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .REF, .SET_VALS, items, .INSERT, idx);
        }

        pub fn in_place_insert_many_items_assume_capacity(self: *ListSlice, idx: Idx, items: []const T) void {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .ASSUME_CAPACITY, void, .SELF_ONLY, .SET_VALS, items, .INSERT, idx);
        }

        pub fn in_place_insert_many_items_get_idx_range(self: *ListSlice, idx: Idx, items: []const T, alloc: Allocator) struct { Idx, Idx } {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .IDX, .SET_VALS, items, .INSERT, idx);
        }

        pub fn in_place_insert_many_items_get_sub_slice(self: *ListSlice, idx: Idx, items: []const T, alloc: Allocator) ListSlice.with_sub_slice_mode(.STATIC) {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .REF, .SET_VALS, items, .INSERT, idx);
        }

        pub fn in_place_insert_many_items(self: *ListSlice, idx: Idx, items: []const T, alloc: Allocator) void {
            return expand_internal(.IN_PLACE, self, .MANY, @intCast(items.len), .REALLOCATE, alloc, .SELF_ONLY, .SET_VALS, items, .INSERT, idx);
        }

        //CHECKPOINT

        //**********
        // SORTED INSERT
        //**********

        pub fn sorted_insert_index_implicit(self: ListSlice, val: T) Idx {
            const result = self.binary_search_for_item_implicit(val);
            return result.idx;
        }

        pub fn sorted_insert_index_with_func(self: ListSlice, val: T, match_fn: *const CompareFunc(T, T), less_than_fn: *const CompareFunc(T, T)) Idx {
            const result = self.binary_search_for_item_idx_with_func(val, match_fn, less_than_fn);
            return result.idx;
        }

        pub fn sorted_insert_index_with_func_and_userdata(self: ListSlice, val: T, userdata: anytype, match_fn: *const CompareFunc(T, T, @TypeOf(userdata)), less_than_fn: *const CompareFunc(T, T, @TypeOf(userdata))) Idx {
            const result = self.binary_search_for_item_idx_with_func_and_userdata(val, userdata, match_fn, less_than_fn);
            return result.idx;
        }

        //**********
        // UNIVERSAL DELETE/REMOVE
        //**********

        //**********
        // DELETE
        //**********

        //**********
        // DELETE IN-PLACE
        //**********

        //**********
        // REMOVE
        //**********

        //**********
        // REMOVE IN-PLACE
        //**********

        //**********
        // MAP/FILTER/ACCUMULATE
        //**********
    };
}
