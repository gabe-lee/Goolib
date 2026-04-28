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
const Allocator = std.mem.Allocator;
const KindINfo = Types.KindInfo;
const util_secure_memset = Utils.Mem.secure_memset;
const util_secure_zero = Utils.Mem.secure_zero;
const util_secure_memset_undefined = Utils.Mem.secure_memset_undefined;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;
// const InsertionSort = Root.InsertionSort;
// const BinarySearch = Root.BinarySearch;
const CompareFunc = Utils.Mem.CompareFunc;
const CompareFuncUserdata = Utils.Mem.CompareFuncUserdata;
const GrowthModel = CommonTypes.GrowthModel;
const SandboxMode = CommonTypes.SandboxMode;
const LenMutability = CommonTypes.LenMutability;
const CapMutability = CommonTypes.CapMutability;
const CapReallocMutability = CommonTypes.CapReallocMutability;
const PtrMutability = CommonTypes.PtrMutability;
const Reallocatability = CommonTypes.Reallocatability;
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
const ERR_ESCAPE_SANDBOX_LEFT = "requested operation would cause the memory region to escape the defined sandbox to the left (memory address less than min allowed)";
const ERR_ESCAPE_SANDBOX_RIGHT = "requested operation would cause the memory region to escape the defined sandbox to the right (memory address greater than max allowed)";
const ERR_CAP_CANNOT_GROW = "capacity cannot grow when `.CAP_MUTABILITY` setting is `{s}`";
const ERR_CAP_CANNOT_SHRINK = "capacity cannot grow when `.CAP_MUTABILITY` setting is `{s}`";
const ERR_CAP_CANNOT_REALLOC_GROW = "capacity cannot grow during reallocation when `.CAP_REALLOC_MUTABILITY` setting is `{s}`";
const ERR_CAP_CANNOT_REALLOC_SHRINK = "capacity cannot shrink during reallocation when `.CAP_REALLOC_MUTABILITY` setting is `{s}`";
const ERR_PTR_CANNOT_MOVE_LEFT = "pointer address cannot move to the left (decrease) when `.PTR_MUTABILITY` setting is `{s}`";
const ERR_PTR_CANNOT_MOVE_RIGHT = "pointer address cannot move to the right (increase) when `.PTR_MUTABILITY` setting is `{s}`";
const ERR_PTR_CANNOT_REALLOC = "pointer cannot be reallocated when `.REALLOCABILITY` setting is `{s}`";
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

pub const GooListSliceDefinitionOptional = struct {
    T: ?type = null,
    IDX: ?type = null,
    ELEM_MUTABILITY: ?Mutability = null,
    PTR_NULLABILITY: ?Nullability = null,
    MODE: ?GooListSliceMode = null,
    SANDBOX: ?SandboxMode = null,
    CAP_MUTABILITY: ?CapMutability = null,
    CAP_REALLOC_MUTABILITY: ?CapReallocMutability = null,
    PTR_MUTABILITY: ?PtrMutability = null,
    REALLOCABILITY: ?Reallocatability = null,
};

pub const GooListSliceDefinition = struct {
    T: type,
    IDX: type = usize,
    ELEM_MUTABILITY: Mutability = .MUTABLE,
    PTR_NULLABILITY: Nullability = .NOT_NULLABLE,
    MODE: GooListSliceMode = .SLICE,
    SANDBOX: SandboxMode = .NO_SANDBOXING,
    CAP_MUTABILITY: CapMutability = .CAPACITY_CAN_SHRINK_OR_GROW,
    CAP_REALLOC_MUTABILITY: CapReallocMutability = .REALLOC_CAN_GROW_OR_SHRINK_CAP,
    PTR_MUTABILITY: PtrMutability = .PTR_IS_IMMUTABLE_EXCEPT_REALLOCATION,
    REALLOCABILITY: Reallocatability = .CANNOT_REALLOC_MEMORY,

    pub fn allocated_list(comptime T: type, comptime IDX: type) GooListSliceDefinition {
        return GooListSliceDefinition{
            .T = T,
            .IDX = IDX,
            .ELEM_MUTABILITY = .MUTABLE,
            .PTR_NULLABILITY = .NOT_NULLABLE,
            .MODE = .LIST,
            .SANDBOX = .NO_SANDBOXING,
            .CAP_MUTABILITY = .CAPACITY_IS_IMMUTABLE,
            .CAP_REALLOC_MUTABILITY = .REALLOC_CAN_GROW_OR_SHRINK_CAP,
            .PTR_MUTABILITY = .PTR_IS_IMMUTABLE,
            .REALLOCABILITY = .CAN_REALLOC_MEMORY,
        };
    }
    pub fn allocated_slice(comptime T: type, comptime IDX: type) GooListSliceDefinition {
        return GooListSliceDefinition{
            .T = T,
            .IDX = IDX,
            .ELEM_MUTABILITY = .MUTABLE,
            .PTR_NULLABILITY = .NOT_NULLABLE,
            .MODE = .SLICE,
            .SANDBOX = .NO_SANDBOXING,
            .CAP_MUTABILITY = .CAPACITY_IS_IMMUTABLE,
            .CAP_REALLOC_MUTABILITY = .REALLOC_CAN_GROW_OR_SHRINK_CAP,
            .PTR_MUTABILITY = .PTR_IS_IMMUTABLE,
            .REALLOCABILITY = .CAN_REALLOC_MEMORY,
        };
    }

    pub fn sub_slice(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.REALLOCABILITY = .CANNOT_REALLOC_MEMORY;
        new_def.PTR_MUTABILITY = .PTR_ADDR_CAN_INCREASE_OR_DECREASE;
        new_def.CAP_MUTABILITY = .CAPACITY_CAN_SHRINK_OR_GROW;
        new_def.CAP_REALLOC_MUTABILITY = .REALLOC_MUST_HAVE_SAME_CAPACITY;
        return new_def;
    }
    pub fn sub_slice_static(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.REALLOCABILITY = .CANNOT_REALLOC_MEMORY;
        new_def.PTR_MUTABILITY = .PTR_IS_IMMUTABLE;
        new_def.CAP_MUTABILITY = .CAPACITY_IS_IMMUTABLE;
        new_def.CAP_REALLOC_MUTABILITY = .REALLOC_MUST_HAVE_SAME_CAPACITY;
        return new_def;
    }
    pub fn sub_slice_immutable(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ELEM_MUTABILITY = .IMMUTABLE;
        new_def.REALLOCABILITY = .CANNOT_REALLOC_MEMORY;
        new_def.PTR_MUTABILITY = .PTR_ADDR_CAN_INCREASE_OR_DECREASE;
        new_def.CAP_MUTABILITY = .CAPACITY_CAN_SHRINK_OR_GROW;
        new_def.CAP_REALLOC_MUTABILITY = .REALLOC_MUST_HAVE_SAME_CAPACITY;
        return new_def;
    }
    pub fn sub_slice_static_immutable(comptime DEF: GooListSliceDefinition) GooListSliceDefinition {
        comptime var new_def = DEF;
        new_def.MODE = .SLICE;
        new_def.ELEM_MUTABILITY = .IMMUTABLE;
        new_def.REALLOCABILITY = .CANNOT_REALLOC_MEMORY;
        new_def.PTR_MUTABILITY = .PTR_IS_IMMUTABLE;
        new_def.CAP_MUTABILITY = .CAPACITY_IS_IMMUTABLE;
        new_def.CAP_REALLOC_MUTABILITY = .REALLOC_MUST_HAVE_SAME_CAPACITY;
        return new_def;
    }

    pub fn with_overrides(comptime self: GooListSliceDefinition, comptime overrides: GooListSliceDefinitionOptional) GooListSliceDefinition {
        var new = self;
        if (overrides.T) |T| new.T = T;
        if (overrides.IDX) |IDX| new.IDX = IDX;
        if (overrides.ELEM_MUTABILITY) |ELEM_MUTABILITY| new.ELEM_MUTABILITY = ELEM_MUTABILITY;
        if (overrides.PTR_NULLABILITY) |PTR_NULLABILITY| new.PTR_NULLABILITY = PTR_NULLABILITY;
        if (overrides.MODE) |MODE| new.MODE = MODE;
        if (overrides.SANDBOX) |SAND| new.SANDBOX = SAND;
        if (overrides.PTR_MUTABILITY) |PTR_MUT| new.PTR_MUTABILITY = PTR_MUT;
        if (overrides.CAP_MUTABILITY) |CAP_MUT| new.CAP_MUTABILITY = CAP_MUT;
        if (overrides.CAP_REALLOC_MUTABILITY) |CAP_RE_MUT| new.CAP_REALLOC_MUTABILITY = CAP_RE_MUT;
        if (overrides.REALLOCABILITY) |REALLOC| new.REALLOCABILITY = REALLOC;
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
    pub fn with_sandbox(comptime self: GooListSliceDefinition, comptime sandbox: SandboxMode) GooListSliceDefinition {
        var new = self;
        new.SANDBOX = sandbox;
        return new;
    }
    pub fn with_ptr_mutability(comptime self: GooListSliceDefinition, comptime ptr_mutability: PtrMutability) GooListSliceDefinition {
        var new = self;
        new.PTR_MUTABILITY = ptr_mutability;
        return new;
    }
    pub fn with_cap_mutability(comptime self: GooListSliceDefinition, comptime cap_mutability: CapMutability) GooListSliceDefinition {
        var new = self;
        new.CAP_MUTABILITY = cap_mutability;
        return new;
    }
    pub fn with_cap_realloc_mutability(comptime self: GooListSliceDefinition, comptime cap_realloc_mutability: CapReallocMutability) GooListSliceDefinition {
        var new = self;
        new.CAP_REALLOC_MUTABILITY = cap_realloc_mutability;
        return new;
    }
    pub fn with_reallocatablity(comptime self: GooListSliceDefinition, comptime reallocatability: Reallocatability) GooListSliceDefinition {
        var new = self;
        new.REALLOCABILITY = reallocatability;
        return new;
    }
};
pub const KIND_GooListSlice = "Goolib.GooListSlice.GooListSlice";
pub const KIND_HASH_GooListSlice = Hash.hash(0, KIND_GooListSlice);
pub fn GooListSlice(comptime DEF_: GooListSliceDefinition) type {
    if (@typeInfo(DEF_.IDX) != .int) @compileError("type `Idx` must be an integer type");
    return extern struct {
        const ListSlice = @This();
        pub const GOOLIB_TYPE_DATA = Types.Id.get_type_data(ListSlice, KIND_GooListSlice, if (IS_LIST) .LIST else .SLICE);

        ptr: Ptr = INVALID_DATA_POINTER,
        min_address: if (SANDBOX) usize else void = if (SANDBOX) 0 else void{},
        max_address_excluded: if (SANDBOX) usize else void = if (SANDBOX) 0 else void{},
        len: Idx = 0,
        cap: if (IS_LIST) Idx else void = if (IS_LIST) 0 else void{},

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
        const SANDBOX = DEF.SANDBOX == .INCLUDE_SANDBOX_GUARDS;

        pub const Ptr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]const T,
                .NULLABLE => ?[*]const T,
            },
            .MUTABLE => switch (PTR_NULLABILITY) {
                .NOT_NULLABLE => [*]T,
                .NULLABLE => ?[*]T,
            },
        };
        pub const PtrNeverNull = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => [*]const T,
            .MUTABLE => [*]T,
        };
        pub const ElemPtr = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => *const T,
            .MUTABLE => *T,
        };
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
                .IMMUTABLE => Utils.invalid_ptr_many_const(T),
                .MUTABLE => Utils.invalid_ptr_many(T),
            },
        };
        const INVALID_ELEM_PTR = switch (ELEM_MUTABILITY) {
            .IMMUTABLE => Utils.invalid_ptr_const(T),
            .MUTABLE => Utils.invalid_ptr(T),
        };

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
        pub fn with_sandbox(comptime sandbox: SandboxMode) type {
            return GooListSlice(DEF.with_sandbox(sandbox));
        }
        pub fn with_ptr_mutability(comptime ptr_mutability: PtrMutability) type {
            return GooListSlice(DEF.with_ptr_mutability(ptr_mutability));
        }
        pub fn with_cap_mutability(comptime cap_mutability: CapMutability) type {
            return GooListSlice(DEF.with_cap_mutability(cap_mutability));
        }
        pub fn with_cap_realloc_mutability(comptime cap_realloc_mutability: CapReallocMutability) type {
            return GooListSlice(DEF.with_cap_realloc_mutability(cap_realloc_mutability));
        }
        pub fn with_reallocatability(comptime reallocatability: Reallocatability) type {
            return GooListSlice(DEF.with_reallocatablity(reallocatability));
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
        pub fn change_reallocatability(self: ListSlice, comptime new_reallocatability: Reallocatability) ListSlice.with_reallocatability(new_reallocatability) {
            return @bitCast(self);
        }
        pub fn add_sandbox_guards(self: ListSlice, min_address: usize, max_address_excluded: usize) ListSlice.with_sandbox(.INCLUDE_SANDBOX_GUARDS) {
            var new_self = if (SANDBOX) self else ListSlice.with_sandbox(.INCLUDE_SANDBOX_GUARDS){
                .ptr = self.ptr,
                .len = self.len,
                .cap = if (IS_LIST) self.cap else void{},
            };
            new_self.min_address = min_address;
            new_self.max_address_excluded = max_address_excluded;
            return new_self;
        }
        pub fn add_sandbox_guards_safe_build_only(self: ListSlice, min_address: usize, max_address_excluded: usize) ListSlice.with_sandbox(.SANDBOX_IN_SAFE_BUILD_ONLY) {
            if (SandboxMode.SANDBOX_IN_SAFE_BUILD_ONLY == .INCLUDE_SANDBOX_GUARDS) {
                return self.add_sandbox_guards(min_address, max_address_excluded);
            } else {
                return self.remove_sandbox_guards();
            }
        }
        pub fn remove_sandbox_guards(self: ListSlice) ListSlice.with_sandbox(.NO_SANDBOXING) {
            if (!SANDBOX) return self;
            return ListSlice.with_sandbox(.NO_SANDBOXING){
                .ptr = self.ptr,
                .len = self.len,
                .cap = if (IS_LIST) self.cap else void{},
            };
        }

        //**********
        // ASSERTS
        //**********

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
        fn assert_sandbox_left_grow(self: ListSlice, n_space_on_left: Idx, comptime src: std.builtin.SourceLocation) void {
            if (SANDBOX) {
                const SIZE_T = @sizeOf(T);
                const addr_on_left = SIZE_T * num_cast(n_space_on_left, usize);
                assert_with_reason((self.min_address + addr_on_left) <= @intFromPtr(self), src, ERR_ESCAPE_SANDBOX_LEFT, .{});
            }
        }
        fn assert_sandbox_right_grow(self: ListSlice, n_space_on_right: Idx, comptime src: std.builtin.SourceLocation) void {
            if (SANDBOX) {
                const SIZE_T = @sizeOf(T);
                const addr_on_right = SIZE_T * num_cast(n_space_on_right, usize);
                assert_with_reason(@intFromPtr(self) + (num_cast(if (IS_SLICE) self.len else self.cap, usize) * SIZE_T) + addr_on_right <= self.max_address_excluded, src, ERR_ESCAPE_SANDBOX_RIGHT, .{});
            }
        }
        fn assert_len_grow(self: ListSlice, n: Idx, comptime src: std.builtin.SourceLocation) void {
            if (IS_SLICE) {
                assert_cap_grow(src);
                self.assert_sandbox_right_grow(n, src);
            } else {
                self.assert_len_n_less_than_cap(n, src);
            }
        }
        fn assert_len_shrink(self: ListSlice, n: Idx, comptime src: std.builtin.SourceLocation) void {
            if (IS_SLICE) {
                assert_cap_shrink(src);
                self.assert_len_greater_or_equal_count(n, src);
            } else {
                self.assert_len_greater_or_equal_count(n, src);
            }
        }
        fn assert_cap_grow(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.CAP_MUTABILITY == .CAPACITY_CAN_ONLY_GROW or DEF.CAP_MUTABILITY == .CAPACITY_CAN_SHRINK_OR_GROW, src, ERR_CAP_CANNOT_GROW, .{@tagName(DEF.CAP_MUTABILITY)});
        }
        fn assert_cap_shrink(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.CAP_MUTABILITY == .CAPACITY_CAN_ONLY_SHRINK or DEF.CAP_MUTABILITY == .CAPACITY_CAN_SHRINK_OR_GROW, src, ERR_CAP_CANNOT_SHRINK, .{@tagName(DEF.CAP_MUTABILITY)});
        }
        fn assert_cap_realloc_grow(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.CAP_REALLOC_MUTABILITY == .REALLOC_CAN_GROW_CAP_ONLY or DEF.CAP_REALLOC_MUTABILITY == .REALLOC_CAN_GROW_OR_SHRINK_CAP, src, ERR_CAP_CANNOT_REALLOC_GROW, .{@tagName(DEF.CAP_REALLOC_MUTABILITY)});
        }
        fn assert_cap_realloc_shrink(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.CAP_REALLOC_MUTABILITY == .REALLOC_CAN_SHRINK_CAP_ONLY or DEF.CAP_REALLOC_MUTABILITY == .REALLOC_CAN_GROW_OR_SHRINK_CAP, src, ERR_CAP_CANNOT_REALLOC_SHRINK, .{@tagName(DEF.CAP_REALLOC_MUTABILITY)});
        }
        fn assert_ptr_move_left(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.PTR_MUTABILITY == .PTR_ADDR_CAN_DECREASE_ONLY or DEF.PTR_MUTABILITY == .PTR_ADDR_CAN_INCREASE_OR_DECREASE, src, ERR_PTR_CANNOT_MOVE_LEFT, .{@tagName(DEF.PTR_MUTABILITY)});
        }
        fn assert_ptr_move_right(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.PTR_MUTABILITY == .PTR_ADDR_CAN_INCREASE_ONLY or DEF.PTR_MUTABILITY == .PTR_ADDR_CAN_INCREASE_OR_DECREASE, src, ERR_PTR_CANNOT_MOVE_RIGHT, .{@tagName(DEF.PTR_MUTABILITY)});
        }
        fn assert_ptr_realloc(comptime src: std.builtin.SourceLocation) void {
            assert_with_reason(DEF.REALLOCABILITY == .CAN_REALLOC_MEMORY, src, ERR_PTR_CANNOT_REALLOC, .{@tagName(DEF.REALLOCABILITY)});
        }
        pub fn assert_valid(self: ListSlice, comptime src: std.builtin.SourceLocation) void {
            self.assert_sandbox_left_grow(0, src);
            self.assert_sandbox_right_grow(0, src);
            if (IS_LIST) {
                assert_with_reason(self.len <= self.cap, src, ERR_LEN_GREATER_THAN_CAP, .{ self.len, self.cap });
            }
            assert_with_reason(self.len >= 0 or (if (IS_LIST) self.cap >= 0 else true), src, ERR_LEN_OR_CAP_NEGATIVE, .{ self.len, self.cap });
            if (Assert.should_assert() and self.is_null()) {
                assert_with_reason(self.len == 0 and (if (IS_LIST) self.cap == 0 else true), src, ERR_LEN_OR_CAP_NONZERO_WHEN_NULL, .{ self.len, self.cap });
            }
        }

        //**********
        // INIT AND UTIL
        //**********

        pub fn alloc_new(capacity: Idx, alloc: Allocator) ListSlice {
            return realloc_exact(ListSlice{}, alloc, capacity);
        }

        pub fn from_slice(slice: ZigSlice) ListSlice {
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
            if (NULLABLE) {
                if (self.ptr == null) return null;
                return self.ptr_never_null()[0..self.len];
            } else {
                return self.ptr[0..self.len];
            }
        }

        pub fn to_slice_never_null(self: ListSlice) ZigSliceNeverNull {
            self.assert_not_null(@src());
            self.ptr_never_null()[0..self.len];
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

        pub fn ptr_never_null(self: ListSlice) PtrNeverNull {
            self.assert_not_null(@src());
            if (NULLABLE) {
                return self.ptr.?;
            } else {
                return self.ptr;
            }
        }

        //**********
        // WINDOW MOVEMENT
        //**********

        pub fn grow_right(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            if (IS_LIST) {
                self.assert_free_slots(count, @src());
            } else {
                self.assert_sandbox_right_grow(count, @src());
                assert_cap_grow(@src());
            }
            var new_self = self;
            new_self.len += count;
        }
        pub fn grow_cap(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_list(@src());
            self.assert_sandbox_right_grow(count, @src());
            assert_cap_grow(@src());
            var new_self = self;
            new_self.cap += count;
        }

        pub fn grow_left(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_cap_grow(@src());
            assert_ptr_move_left(@src());
            self.assert_sandbox_left_grow(count, @src());
            var new_self = self;
            new_self.ptr = self.ptr_never_null() - count;
            new_self.len += count;
            if (IS_LIST) {
                new_self.cap += count;
            }
            return new_self;
        }

        pub fn shrink_right(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            self.assert_len_greater_or_equal_count(count, @src());
            if (IS_SLICE) {
                assert_cap_shrink(@src());
            }
            var new_self = self;
            new_self.len -= count;
            return new_self;
        }

        pub fn shrink_left(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            self.assert_len_greater_or_equal_count(count, @src());
            assert_cap_shrink(@src());
            assert_ptr_move_right(@src());
            var new_self = self;
            new_self.ptr = self.ptr_never_null() + count;
            new_self.len -= count;
            return ListSlice{ .ptr = self.ptr_never_null() + count, .len = self.len - count };
        }

        pub fn shift_right(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_ptr_move_right(@src());
            var new_self = self;
            new_self.ptr = self.ptr_never_null() + count;
        }

        pub fn shift_left(self: ListSlice, count: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_ptr_move_left(@src());
            var new_self = self;
            new_self.ptr = self.ptr_never_null() - count;
        }

        pub fn sub_slice_start_len(self: ListSlice, start: Idx, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            self.assert_start_plus_len_in_range(start, len, @src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + start),
                .len = len,
            };
        }

        pub fn sub_slice_start_end(self: ListSlice, start: Idx, end_excluded: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            assert_start_and_end_in_order(start, end_excluded, @src());
            const len = end_excluded - start;
            self.assert_start_plus_len_in_range(start, len, @src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + start),
                .len = len,
            };
        }

        pub fn sub_slice_from_start(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            self.assert_len_in_range(len, @src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null()),
                .len = len,
            };
        }

        pub fn sub_slice_from_end(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            self.assert_len_in_range_from_end(len, @src());
            const diff = self.len - len;
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + diff),
                .len = len,
            };
        }

        pub fn with_new_len(self: ListSlice, new_len: Idx) ListSlice {
            self.assert_not_null(@src());
            var new_self = self;
            new_self.len = new_len;
            new_self.assert_valid(@src());
            return new_self;
        }

        pub fn with_new_ptr(self: ListSlice, new_ptr: Ptr) ListSlice {
            var new_self = self;
            new_self.ptr = new_ptr;
            new_self.assert_valid(@src());
            return new_self;
        }

        pub fn new_slice_immediately_before(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() - len),
                .len = len,
            };
        }

        pub fn new_slice_immediately_after(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + self.len),
                .len = len,
            };
        }
        pub fn new_slice_immediately_after_entire_capacity(self: ListSlice, len: Idx, comptime mode: SubSliceMode) ListSlice.with_sub_slice_mode(mode) {
            self.assert_not_null(@src());
            return ListSlice.with_sub_slice_mode(mode){
                .ptr = @ptrCast(self.ptr_never_null() + (if (IS_LIST) self.cap else self.len)),
                .len = len,
            };
        }

        //**********
        // GET/SET
        //**********

        pub fn get_item_ptr(self: ListSlice, idx: Idx) ElemPtr {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            return &self.ptr_never_null()[idx];
        }

        pub fn get_last_item_ptr(self: ListSlice) ElemPtr {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return &self.ptr_never_null()[self.len - 1];
        }

        pub fn get_first_item_ptr(self: ListSlice) ElemPtr {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return &self.ptr_never_null()[0];
        }

        pub fn get_item_ptr_nth_from_end(self: ListSlice, nth_from_end: Idx) ElemPtr {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            return &self.ptr_never_null()[self.len - 1 - nth_from_end];
        }

        pub fn get_item(self: ListSlice, idx: Idx) T {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            return self.ptr_never_null()[idx];
        }

        pub fn get_last_item(self: ListSlice) T {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return self.ptr_never_null()[self.len - 1];
        }

        pub fn get_first_item(self: ListSlice) T {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            return self.ptr_never_null()[0];
        }

        pub fn get_item_nth_from_end(self: ListSlice, nth_from_end: Idx) T {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            return self.ptr_never_null()[self.len - 1 - nth_from_end];
        }

        pub fn set_item(self: ListSlice, idx: Idx, val: T) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(idx, @src());
            assert_mutable(@src());
            self.ptr_never_null()[idx] = val;
        }

        pub fn set_last_item(self: ListSlice, val: T) void {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            assert_mutable(@src());
            self.ptr_never_null()[self.len - 1] = val;
        }

        pub fn set_first_item(self: ListSlice, val: T) void {
            self.assert_not_null(@src());
            self.assert_len_non_zero(@src());
            assert_mutable(@src());
            self.ptr_never_null()[0] = val;
        }

        pub fn set_item_nth_from_end(self: ListSlice, nth_from_end: Idx, val: T) void {
            self.assert_not_null(@src());
            self.assert_idx_in_range(nth_from_end, @src());
            assert_mutable(@src());
            self.ptr_never_null()[self.len - 1 - nth_from_end] = val;
        }

        //**********
        // MEMCOPY/MEMSET
        //**********

        pub fn memcopy_to(self: ListSlice, dest: anytype) void {
            self.assert_not_null(@src());
            @memcpy(dest, self.to_slice_never_null());
        }

        pub fn memcopy_from(self: ListSlice, source: anytype) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            @memcpy(self.to_slice_never_null(), source);
        }

        pub fn memset(self: ListSlice, val: T) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            @memset(self.to_slice_never_null(), val);
        }

        pub fn secure_memset_zero(self: ListSlice) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            util_secure_zero(T, self.to_slice_never_null());
        }

        pub fn secure_memset_undefined(self: ListSlice) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            util_secure_memset_undefined(T, self.to_slice_never_null());
        }

        pub fn secure_memset(self: ListSlice, val: T) void {
            self.assert_not_null(@src());
            assert_mutable(@src());
            util_secure_memset(T, self.to_slice_never_null(), val);
        }

        //**********
        // DATA MOVEMENT
        //**********

        pub fn copy_rightward(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_self = self.shift_right(n_positions_to_the_right);
            if (n_positions_to_the_right > self.len) {
                @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_self;
        }

        pub fn copy_rightward_never_overlaps(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_mutable(@src());
            assert_slice(@src());
            const new_self = self.shift_right(n_positions_to_the_right);
            @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            return new_self;
        }

        pub fn copy_rightward_always_overlaps(self: ListSlice, n_positions_to_the_right: Idx) ListSlice {
            self.assert_not_null(@src());
            const new_self = self.shift_right(n_positions_to_the_right);
            @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            return new_self;
        }

        pub fn copy_leftward(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_self = self.shift_left(n_positions_to_the_left);
            if (n_positions_to_the_left > self.len) {
                @memcpy(new_self.to_slice_never_null(), self.to_slice_never_null());
            } else {
                @memmove(new_self.to_slice_never_null(), self.to_slice_never_null());
            }
            return new_self;
        }

        pub fn copy_leftward_never_overlaps(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_left(n_positions_to_the_left);
            @memcpy(new_slice.to_slice_never_null(), self.to_slice_never_null());
            return new_slice;
        }

        pub fn copy_leftward_always_overlaps(self: ListSlice, n_positions_to_the_left: Idx) ListSlice {
            self.assert_not_null(@src());
            assert_mutable(@src());
            const new_slice = self.shift_left(n_positions_to_the_left);
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
            if (self.is_null()) return ListSlice{};
            alloc.free(self.to_slice_never_null()) catch |err| assert_unreachable_err(@src(), err);
            return ListSlice{};
        }

        pub fn in_place_free(self: *ListSlice, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.free(alloc);
            self.* = self_val;
        }

        pub fn ensure_free_slots(self: ListSlice, needed_free_slots: Idx, alloc: Allocator) ListSlice {
            assert_list(@src());
            const new_len = self.len + needed_free_slots;
            if (new_len <= self.cap) return;
            assert_ptr_realloc(@src());
            assert_cap_realloc_grow(@src());
            var new_self = self;
            Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, new_len, .{ .grow_mode = .GROW_BY_50_PERCENT }, .{ .GROW_MODE = .GROW_BY_50_PERCENT });
            return new_self;
        }

        pub fn ensure_free_slots_custom_grow(self: ListSlice, needed_free_slots: Idx, alloc: Allocator, grow: GrowthModel, comptime grow_comptime_known: ?GrowthModel) ListSlice {
            assert_list(@src());
            const new_len = self.len + needed_free_slots;
            if (new_len <= self.cap) return;
            assert_ptr_realloc(@src());
            assert_cap_realloc_grow(@src());
            var new_self = self;
            Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, new_len, .{ .grow_mode = grow }, .{ .GROW_MODE = grow_comptime_known });
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

        pub fn shrink_cap_reserve_at_most(self: ListSlice, at_most_n_free_slots: Idx, alloc: Allocator) ListSlice {
            assert_list(@src());
            const curr_free = self.cap - self.len;
            if (curr_free <= at_most_n_free_slots) return self;
            assert_cap_realloc_shrink(@src());
            const new_cap = self.len + at_most_n_free_slots;
            var new_self = self;
            Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, @intCast(new_cap), .{}, .{});
            return new_self;
        }

        pub fn in_place_shrink_cap_reserve_at_most(self: *ListSlice, at_most_n_free_slots: Idx, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.shrink_cap_reserve_at_most(at_most_n_free_slots, alloc);
            self.* = self_val;
        }

        pub fn realloc_exact(self: ListSlice, new_capacity: Idx, alloc: Allocator) ListSlice {
            assert_ptr_realloc(@src());
            var new_self = self;
            if (IS_LIST) {
                if (Assert.should_assert()) {
                    if (new_capacity < self.cap) {
                        assert_cap_realloc_shrink(@src());
                    } else if (new_capacity > self.cap) {
                        assert_cap_realloc_grow(@src());
                    }
                }
                Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.cap, @intCast(new_capacity), .{}, .{});
                new_self.len = @min(self.len, new_self.cap);
            } else {
                if (Assert.should_assert()) {
                    if (new_capacity < self.len) {
                        assert_cap_realloc_shrink(@src());
                    } else if (new_capacity > self.len) {
                        assert_cap_realloc_grow(@src());
                    }
                }
                Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &new_self.ptr, &new_self.len, @intCast(new_capacity), .{}, .{});
            }
            return new_self;
        }

        pub fn in_place_realloc_exact(self: *ListSlice, new_capacity: Idx, alloc: Allocator) void {
            var self_val = self.*;
            self_val = self_val.realloc_exact(new_capacity, alloc);
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
                    } else {
                        new_self.assert_sandbox_right_grow(real_count, @src());
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
