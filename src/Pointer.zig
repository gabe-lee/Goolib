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

/// std imports
const Allocator = std.mem.Allocator;
const Io = std.Io;
const math = std.math;
const DEBUG = std.debug.print;
const mem = std.mem;
const Alignment = std.mem.Alignment;
const SourceLocation = std.lang.SourceLocation;
const PtrSize = std.lang.Type.Pointer.Size;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Types = Root.Types;
const Math = Root.Math;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const AllocatorModule = Root.Allocator;
const ListSlice = Root.ListSlice;
const PowerOf2 = Math.PowerOf2;
const AddrSpace = std.lang.AddressSpace;

const dummy_alloc = AllocatorModule.Dummy.allocator_panic_free_noop;
const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const num_cast = Cast.num_cast;

const DEBUG_VAL = Utils.DebugPrint.debug_val;

comptime {
    if (build.is_test) {
        _ = @import("./Pointer_Tests.zig");
    }
}

pub const PointerSourceKind = enum {
    NATIVE,
    STATIC_RESOLVER,
};

const OffsetDir = enum {
    ADD,
    SUB,
};

pub const Mutability = enum {
    MUTABLE,
    CONST,
};

pub const Nullability = enum {
    NEVER_NULL,
    NULLABLE,
};

pub const AllowZero = enum {
    NO_ALLOW_ZERO,
    ALLOW_ZERO,
};

pub const Volatile = enum {
    NOT_VOLATILE,
    VOLATILE,
};

pub fn SentinelRefOpaque(comptime T: type, comptime VAL: T) *const anyopaque {
    return @ptrCast(SentinelRef(T, VAL));
}
pub fn SentinelRef(comptime T: type, comptime VAL: T) *const T {
    const Holder = struct {
        const SENTINEL = VAL;
    };
    return @ptrCast(&Holder.SENTINEL);
}

pub const AlignmentSource = union(enum) {
    NATIVE: void,
    BYTES: usize,
    LOG_2: u8,
    POWER_OF_2: PowerOf2,
    STD_MEM_ALIGN: mem.Alignment,

    pub fn native_align() AlignmentSource {
        return AlignmentSource{ .NATIVE = {} };
    }
    pub fn bytes_align(comptime bytes: usize) AlignmentSource {
        return AlignmentSource{ .BYTES = bytes };
    }
    pub fn log2_align(comptime log2: u8) AlignmentSource {
        return AlignmentSource{ .LOG_2 = log2 };
    }
    pub fn pow2_align(comptime power: PowerOf2) AlignmentSource {
        return AlignmentSource{ .POWER_OF_2 = power };
    }
    pub fn std_mem_align(comptime alignment: mem.Alignment) AlignmentSource {
        return AlignmentSource{ .STD_MEM_ALIGN = alignment };
    }

    pub fn calc(comptime self: AlignmentSource) ?usize {
        return switch (comptime self) {
            .NATIVE => null,
            .BYTES => |B| B,
            .LOG_2 => |L| @as(usize, 1) << @intCast(L),
            .POWER_OF_2 => |P| P.value_as_type(usize),
            .STD_MEM_ALIGN => |A| A.toByteUnits(),
        };
    }
};

fn normalize_align(comptime ALIGN_ARG: anytype) ?PowerOf2 {
    const T = @TypeOf(ALIGN_ARG);
    if (T == @TypeOf(null)) return null;
    if (T == comptime_int) return PowerOf2.alignment_power(@as(usize, ALIGN_ARG));
    if (T == usize) return PowerOf2.alignment_power(ALIGN_ARG);
    if (T == ?usize) return if (ALIGN_ARG) |a| PowerOf2.alignment_power(a) else null;
    if (T == PowerOf2) return ALIGN_ARG;
    if (T == ?PowerOf2) return ALIGN_ARG;
    if (T == mem.Alignment) return PowerOf2.from_alloc_align(ALIGN_ARG);
    if (T == ?mem.Alignment) return if (ALIGN_ARG) |a| PowerOf2.from_alloc_align(a) else null;
    if (T == AlignmentSource) return if (ALIGN_ARG.calc()) |a| PowerOf2.alignment_power(a) else null;
    if (T == ?AlignmentSource) return if (ALIGN_ARG) |a| if (a.calc()) |b| PowerOf2.alignment_power(b) else null else null;
    assert_unreachable(@src(), "type `{s}` is invalid as an alignment input", .{@typeName(T)});
}

pub const StaticPointerResolver = struct {
    /// The local type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE: type,
    /// MUST be a pointer to a value of type `LOCAL_TYPE` that represents the 'null' value
    /// for the input type
    LOCAL_NULL_VALUE: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) bool`
    IS_NULL_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
    /// that resolves the local handle to a memory address. If the local value is 'null'
    /// according to `IS_NULL_FUNC`, the return value of this function is undefined behavior.
    RESOLVE_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (original: LOCAL_TYPE, byte_offset: usize) LOCAL_TYPE`,
    /// where the returned `LOCAL_TYPE` is the value that, when resolved, returns
    /// the exact same address as if the user had resolved the original address and added
    /// the usize offset to it:
    ///
    /// `RESOLVE(ORIGINAL) + BYTE_OFFSET == RESOLVE(INCR_FUNC(ORIGINAL, BYTE_OFFSET))`
    INCR_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (original: LOCAL_TYPE, offset: usize) LOCAL_TYPE`,
    /// where the returned `LOCAL_TYPE` is the value that, when resolved, returns
    /// the exact same address as if the user had resolved the original address and subtracted
    /// the usize offset to it:
    ///
    /// `RESOLVE(ORIGINAL) - BYTE_OFFSET == RESOLVE(DECR_FUNC(ORIGINAL, BYTE_OFFSET))`
    DECR_FUNC: *const anyopaque,
    /// When `true`, operations that offset the pointer, or that
    /// slice the pointer or point to an array or vector, will perform
    /// a sanity assertion in `.debug` and `.safe` build modes
    /// to check that the resolved addresses before and after the offset
    /// (or at the start and end of a range) exactly match the results of
    /// offsetting the original native pointer by the same amount.
    ///
    /// A failed assertion indicates that the local handle crossed
    /// a boundary between contiguous memory chunks
    ASSERT_CONTIGUOUS_RANGE: bool = true,
    /// The minimum number of bytes an address can be incremented by with the `INCR_FUNC` and `DECR_FUNC`
    ///
    /// This is not to be confused with minimum alignment of any address the resolver can return, though
    /// those 2 properties may be the same. For example, if the resolver scheme uses a u32 handle with
    /// address granularity `1`, that resolver can address into a total of 4 GiB of memory space.
    ///
    /// HOWEVER, if the resolver scheme uses a u32 with a granularity of `16`, the resolver can
    /// address into a total of 64 GiB of memory space (bottom 4 bits of the address are implicit zeroes),
    /// with the limitation that you can only increment or decrement a pointer in 16 byte multiples.
    ///
    /// This does not affect the native pointers AFTER they are resolved, you are free to manipulate those
    /// at will.
    ADDRESS_GRANULARITY: PowerOf2 = ._1,
};

pub const AutoIntegerStaticPointerResolver = struct {
    /// The local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE: type,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
    /// that resolves the local handle to a memory address. If the local value is 'null'
    /// according to `IS_NULL_FUNC`, the return value of this function is undefined behavior.
    RESOLVE_FUNC: *const anyopaque,
    /// When `true`, operations that offset the pointer, or that
    /// slice the pointer or point to an array or vector, will perform
    /// a sanity assertion in `.debug` and `.safe` build modes
    /// to check that the resolved addresses before and after the offset
    /// (or at the start and end of a range) exactly match the results of
    /// offsetting the original native pointer by the same amount.
    ///
    /// A failed assertion indicates that the local handle crossed
    /// a boundary between contiguous memory chunks
    ASSERT_CONTIGUOUS_RANGE: bool = true,
    /// The minimum number of bytes an address can be incremented by with the `INCR_FUNC` and `DECR_FUNC`
    ///
    /// This is not to be confused with minimum alignment of any address the resolver can return, though
    /// those 2 properties may be the same. For example, if the resolver scheme uses a u32 handle with
    /// address granularity `1`, that resolver can address into a total of 4 GiB of memory space.
    ///
    /// HOWEVER, if the resolver scheme uses a u32 with a granularity of `16`, the resolver can
    /// address into a total of 64 GiB of memory space (bottom 4 bits of th address are implicit zeroes),
    /// with the limitation that you can only increment or decrement a pointer in 16 byte multiples.
    ///
    /// This does not affect the native pointers AFTER they are resolved, you are free to manipulate those
    /// at will.
    ADDRESS_GRANULARITY: PowerOf2 = ._1,

    pub fn to_global_resolver(comptime self: AutoIntegerStaticPointerResolver) StaticPointerResolver {
        const PROTO = IntegerResolverProto(self.LOCAL_TYPE, self.ADDRESS_GRANULARITY);
        return StaticPointerResolver{
            .INCR_FUNC = @ptrCast(&PROTO.add),
            .DECR_FUNC = @ptrCast(&PROTO.sub),
            .IS_NULL_FUNC = @ptrCast(&PROTO.is_null),
            .LOCAL_NULL_VALUE = @ptrCast(&PROTO.NULL_VAL),
            .LOCAL_TYPE = self.LOCAL_TYPE,
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
            .ADDRESS_GRANULARITY = self.ADDRESS_GRANULARITY,
        };
    }
};
pub const AutoIntegerBitsStaticPointerResolver = struct {
    /// The number of bits for the local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE_NUMBER_OF_BITS: u16,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
    /// that resolves the local handle to a memory address. If the local value is 'null'
    /// according to `IS_NULL_FUNC`, the return value of this function is undefined behavior.
    RESOLVE_FUNC: *const anyopaque,
    /// When `true`, operations that offset the pointer, or that
    /// slice the pointer or point to an array or vector, will perform
    /// a sanity assertion in `.debug` and `.safe` build modes
    /// to check that the resolved addresses before and after the offset
    /// (or at the start and end of a range) exactly match the results of
    /// offsetting the original native pointer by the same amount.
    ///
    /// A failed assertion indicates that the local handle crossed
    /// a boundary between contiguous memory chunks
    ASSERT_CONTIGUOUS_RANGE: bool = true,
    /// The minimum number of bytes an address can be incremented by with the `INCR_FUNC` and `DECR_FUNC`
    ///
    /// This is not to be confused with minimum alignment of any address the resolver can return, though
    /// those 2 properties may be the same. For example, if the resolver scheme uses a u32 handle with
    /// address granularity `1`, that resolver can address into a total of 4 GiB of memory space.
    ///
    /// HOWEVER, if the resolver scheme uses a u32 with a granularity of `16`, the resolver can
    /// address into a total of 64 GiB of memory space (bottom 4 bits of th address are implicit zeroes),
    /// with the limitation that you can only increment or decrement a pointer in 16 byte multiples.
    ///
    /// This does not affect the native pointers AFTER they are resolved, you are free to manipulate those
    /// at will.
    ADDRESS_GRANULARITY: PowerOf2 = ._1,

    pub fn to_auto_int(comptime self: AutoIntegerBitsStaticPointerResolver) AutoIntegerStaticPointerResolver {
        return AutoIntegerStaticPointerResolver{
            .LOCAL_TYPE = @Int(.unsigned, self.LOCAL_TYPE_NUMBER_OF_BITS),
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
            .ADDRESS_GRANULARITY = self.ADDRESS_GRANULARITY,
        };
    }
};
pub const AutoIntegerMaxStaticPointerResolver = struct {
    /// The maximum value for the local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE_VALUE_LIMIT: PowerOf2,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
    /// that resolves the local handle to a memory address. If the local value is 'null'
    /// according to `IS_NULL_FUNC`, the return value of this function is undefined behavior.
    RESOLVE_FUNC: *const anyopaque,
    /// When `true`, operations that offset the pointer, or that
    /// slice the pointer or point to an array or vector, will perform
    /// a sanity assertion in `.debug` and `.safe` build modes
    /// to check that the resolved addresses before and after the offset
    /// (or at the start and end of a range) exactly match the results of
    /// offsetting the original native pointer by the same amount.
    ///
    /// A failed assertion indicates that the local handle crossed
    /// a boundary between contiguous memory chunks
    ASSERT_CONTIGUOUS_RANGE: bool = true,
    /// The minimum number of bytes an address can be incremented by with the `INCR_FUNC` and `DECR_FUNC`
    ///
    /// This is not to be confused with minimum alignment of any address the resolver can return, though
    /// those 2 properties may be the same. For example, if the resolver scheme uses a u32 handle with
    /// address granularity `1`, that resolver can address into a total of 4 GiB of memory space.
    ///
    /// HOWEVER, if the resolver scheme uses a u32 with a granularity of `16`, the resolver can
    /// address into a total of 64 GiB of memory space (bottom 4 bits of th address are implicit zeroes),
    /// with the limitation that you can only increment or decrement a pointer in 16 byte multiples.
    ///
    /// This does not affect the native pointers AFTER they are resolved, you are free to manipulate those
    /// at will.
    ADDRESS_GRANULARITY: PowerOf2 = ._1,

    pub fn to_auto_int(comptime self: AutoIntegerMaxStaticPointerResolver) AutoIntegerStaticPointerResolver {
        return AutoIntegerStaticPointerResolver{
            .LOCAL_TYPE = self.LOCAL_TYPE_VALUE_LIMIT.unsigned_integer_type_that_holds_all_values_less_than(),
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
            .ADDRESS_GRANULARITY = self.ADDRESS_GRANULARITY,
        };
    }
};

fn IntegerResolverProto(comptime INT: type, comptime GRANULARITY: PowerOf2) type {
    return struct {
        pub const NULL_VAL: INT = if (@typeInfo(INT).int.signedness == .signed) math.minInt(INT) else math.maxInt(INT);
        pub fn is_null(val: INT) bool {
            return val == NULL_VAL;
        }
        pub fn add(val: INT, offset: usize) INT {
            return val + @as(INT, @intCast(offset >> @intCast(comptime GRANULARITY.bit_shift())));
        }
        pub fn sub(val: INT, offset: usize) INT {
            return val - @as(INT, @intCast(offset >> @intCast(comptime GRANULARITY.bit_shift())));
        }
    };
}

pub const MakePtrDef = struct {
    ALLOW_ZERO: AllowZero = .NO_ALLOW_ZERO,
    NULLABILITY: Nullability = .NEVER_NULL,
    MUTABILITY: Mutability = .MUTABLE,
    SIZE: PtrSize = .one,
    ELEMENT: type,
    SENTINEL: ?*const anyopaque = null,
    ALIGNMENT: ?PowerOf2 = null,
    ADDRSPACE: ?AddrSpace = null,
    VOLATILE: Volatile = .NOT_VOLATILE,

    pub fn with_allow_zero(comptime self: MakePtrDef, comptime ALLOW_ZERO: AllowZero) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_nullability(comptime self: MakePtrDef, comptime NULLABILITY: Nullability) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_mutability(comptime self: MakePtrDef, comptime MUTABILITY: Mutability) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_size_kind(comptime self: MakePtrDef, comptime SIZE: PtrSize) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_element(comptime self: MakePtrDef, comptime ELEMENT: type) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = ELEMENT,
            .SENTINEL = null,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_element_and_sentinel(comptime self: MakePtrDef, comptime ELEMENT: type, comptime SENTINEL: ELEMENT) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = ELEMENT,
            .SENTINEL = SentinelRefOpaque(ELEMENT, SENTINEL),
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_sentinel(comptime self: MakePtrDef, comptime SENTINEL: ?self.ELEMENT) MakePtrDef {
        if (comptime SENTINEL == null) {
            return MakePtrDef{
                .ALLOW_ZERO = self.ALLOW_ZERO,
                .NULLABILITY = self.NULLABILITY,
                .MUTABILITY = self.MUTABILITY,
                .SIZE = self.SIZE,
                .ELEMENT = self.ELEMENT,
                .SENTINEL = null,
                .ALIGNMENT = self.ALIGNMENT,
                .ADDRSPACE = self.ADDRSPACE,
                .VOLATILE = self.VOLATILE,
            };
        }
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = SentinelRefOpaque(self.ELEMENT, SENTINEL.?),
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_align(comptime self: MakePtrDef, comptime ALIGNMENT: ?PowerOf2) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_addrspace(comptime self: MakePtrDef, comptime ADDRSPACE: ?AddrSpace) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_volatile(comptime self: MakePtrDef, comptime VOLATILE: Volatile) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = VOLATILE,
        };
    }
    pub fn with_c_pointer_constraints(comptime self: MakePtrDef) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = .ALLOW_ZERO,
            // the 0 value is the null value, a ?[*c]u8 is treated as an optional wrapper around a [*c]u8
            .NULLABILITY = .NEVER_NULL,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = .c,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = null,
            .ALIGNMENT = null,
            .ADDRSPACE = null,
            .VOLATILE = self.VOLATILE,
        };
    }
};

pub const MakePtrDefNoSize = struct {
    ALLOW_ZERO: AllowZero = .NO_ALLOW_ZERO,
    NULLABILITY: Nullability = .NEVER_NULL,
    MUTABILITY: Mutability = .MUTABLE,
    ELEMENT: type,
    SENTINEL: ?*const anyopaque = null,
    ALIGNMENT: ?PowerOf2 = null,
    ADDRSPACE: ?AddrSpace = null,
    VOLATILE: Volatile = .NOT_VOLATILE,

    pub fn to_make_ptr_def(comptime self: MakePtrDefNoSize, comptime size: PtrSize) MakePtrDef {
        return MakePtrDef{
            .ELEMENT = self.ELEMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .ALIGNMENT = self.ALIGNMENT,
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .MUTABILITY = self.MUTABILITY,
            .NULLABILITY = self.NULLABILITY,
            .SENTINEL = self.SENTINEL,
            .SIZE = size,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_allow_zero(comptime self: MakePtrDefNoSize, comptime ALLOW_ZERO: AllowZero) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_nullability(comptime self: MakePtrDefNoSize, comptime NULLABILITY: Nullability) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_mutability(comptime self: MakePtrDefNoSize, comptime MUTABILITY: Mutability) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_element(comptime self: MakePtrDefNoSize, comptime ELEMENT: type) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = ELEMENT,
            .SENTINEL = null,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_element_and_sentinel(comptime self: MakePtrDefNoSize, comptime ELEMENT: type, comptime SENTINEL: ELEMENT) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = ELEMENT,
            .SENTINEL = SentinelRefOpaque(ELEMENT, SENTINEL),
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_sentinel(comptime self: MakePtrDefNoSize, comptime SENTINEL: ?self.ELEMENT) MakePtrDefNoSize {
        if (comptime SENTINEL == null) {
            return MakePtrDefNoSize{
                .ALLOW_ZERO = self.ALLOW_ZERO,
                .NULLABILITY = self.NULLABILITY,
                .MUTABILITY = self.MUTABILITY,
                .ELEMENT = self.ELEMENT,
                .SENTINEL = null,
                .ALIGNMENT = self.ALIGNMENT,
                .ADDRSPACE = self.ADDRSPACE,
                .VOLATILE = self.VOLATILE,
            };
        }
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = SentinelRefOpaque(self.ELEMENT, SENTINEL.?),
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_align(comptime self: MakePtrDefNoSize, comptime ALIGNMENT: ?PowerOf2) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_addrspace(comptime self: MakePtrDefNoSize, comptime ADDRSPACE: ?AddrSpace) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_volatile(comptime self: MakePtrDefNoSize, comptime VOLATILE: Volatile) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = VOLATILE,
        };
    }
    pub fn with_c_pointer_constraints(comptime self: MakePtrDefNoSize) MakePtrDefNoSize {
        return MakePtrDefNoSize{
            .ALLOW_ZERO = .ALLOW_ZERO,
            // the 0 value is the null value, a ?[*c]u8 is treated as an optional wrapper around a [*c]u8
            .NULLABILITY = .NEVER_NULL,
            .MUTABILITY = self.MUTABILITY,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = null,
            .ALIGNMENT = null,
            .ADDRSPACE = null,
            .VOLATILE = self.VOLATILE,
        };
    }
};

pub fn MakePtrFromDef(comptime DEF: MakePtrDef) type {
    return MakePtr(DEF.ALLOW_ZERO, DEF.NULLABILITY, DEF.MUTABILITY, DEF.SIZE, DEF.ELEMENT, if (DEF.SENTINEL) |SENT| @as(*const DEF.ELEMENT, @ptrCast(@alignCast(SENT))).* else null, DEF.ALIGNMENT, DEF.ADDRSPACE, DEF.VOLATILE);
}

pub fn MakePtr(comptime ALLOW_ZERO: AllowZero, comptime NULLABILITY: Nullability, comptime MUTABILITY: Mutability, comptime SIZE: std.lang.Type.Pointer.Size, comptime ELEMENT: type, comptime SENTINEL: ?ELEMENT, comptime ALIGNMENT: ?PowerOf2, comptime ADDRSPACE: ?AddrSpace, comptime VOLATILE: Volatile) type {
    const P = @Pointer(SIZE, .{
        .@"allowzero" = ALLOW_ZERO == .ALLOW_ZERO,
        .@"addrspace" = ADDRSPACE,
        .@"align" = if (ALIGNMENT) |A| A.value_as_type(usize) else null,
        .@"const" = MUTABILITY == .CONST,
        .@"volatile" = VOLATILE == .VOLATILE,
    }, ELEMENT, SENTINEL);
    return switch (comptime NULLABILITY) {
        .NEVER_NULL => P,
        .NULLABLE => ?P,
    };
}

pub fn PtrDefaultFromDef(comptime DEF: MakePtrDef) MakePtrFromDef(DEF) {
    return switch (comptime DEF.NULLABILITY) {
        .NEVER_NULL => undefined,
        .NULLABLE => null,
    };
}
pub fn PtrDefault(comptime ALLOW_ZERO: AllowZero, comptime NULLABILITY: Nullability, comptime MUTABILITY: Mutability, comptime SIZE: std.lang.Type.Pointer.Size, comptime ELEMENT: type, comptime SENTINEL: ?ELEMENT, comptime ALIGNMENT: ?PowerOf2, comptime ADDRSPACE: ?AddrSpace, comptime VOLATILE: Volatile) MakePtr(ALLOW_ZERO, NULLABILITY, MUTABILITY, SIZE, ELEMENT, SENTINEL, ALIGNMENT, ADDRSPACE, VOLATILE) {
    return switch (comptime NULLABILITY) {
        .NEVER_NULL => undefined,
        .NULLABLE => null,
    };
}

pub const PointerSource = union(PointerSourceKind) {
    NATIVE: void,
    STATIC_RESOLVER: StaticPointerResolver,

    pub fn native_pointer() PointerSource {
        return PointerSource{ .NATIVE = {} };
    }
    pub fn global_pointer_resolver(comptime resolver: StaticPointerResolver) PointerSource {
        return PointerSource{ .STATIC_RESOLVER = resolver };
    }
    pub fn global_pointer_resolver_auto_from_int(comptime resolver: AutoIntegerStaticPointerResolver) PointerSource {
        return PointerSource{ .STATIC_RESOLVER = resolver.to_global_resolver() };
    }
    pub fn global_pointer_resolver_auto_from_int_bits(comptime resolver: AutoIntegerBitsStaticPointerResolver) PointerSource {
        return PointerSource{ .STATIC_RESOLVER = resolver.to_auto_int().to_global_resolver() };
    }
    pub fn global_pointer_resolver_auto_from_int_max(comptime resolver: AutoIntegerMaxStaticPointerResolver) PointerSource {
        return PointerSource{ .STATIC_RESOLVER = resolver.to_auto_int().to_global_resolver() };
    }
    pub fn InternalPtr(comptime self: PointerSource, comptime PTR_DEF: MakePtrDefNoSize) type {
        return switch (comptime self) {
            .NATIVE => MakePtrFromDef(PTR_DEF.to_make_ptr_def(.many)),
            .STATIC_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn InternalPtrDefault(comptime self: PointerSource, comptime PTR_DEF: MakePtrDefNoSize) self.InternalPtr(PTR_DEF) {
        return switch (comptime self) {
            .NATIVE => PtrDefaultFromDef(PTR_DEF.to_make_ptr_def(.many)),
            .STATIC_RESOLVER => |RES| if (PTR_DEF.NULLABILITY == .NULLABLE) @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).* else undefined,
        };
    }
    pub fn ResolverFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE) usize,
        };
    }
    pub fn ResolverFnInit(comptime self: PointerSource) self.ResolverFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE) usize, @ptrCast(@alignCast(RES.RESOLVE_FUNC))),
        };
    }
    pub fn NullCheckFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE) bool,
        };
    }
    pub fn NullCheckFnInit(comptime self: PointerSource) self.NullCheckFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE) bool, @ptrCast(@alignCast(RES.IS_NULL_FUNC))),
        };
    }
    pub fn IncrementFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn IncrementFnInit(comptime self: PointerSource) self.IncrementFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.INCR_FUNC))),
        };
    }
    pub fn DecrementFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn DecrementFnInit(comptime self: PointerSource) self.DecrementFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.DECR_FUNC))),
        };
    }

    pub fn Pointer(comptime SOURCE: PointerSource, comptime T: type) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T });
    }
    pub fn PointerAlign(comptime SOURCE: PointerSource, comptime T: type, comptime A: usize) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .ALIGNMENT = normalize_align(A) });
    }
    pub fn NullablePointer(comptime SOURCE: PointerSource, comptime T: type) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .NULLABILITY = .NULLABLE });
    }
    pub fn NullablePointerAlign(comptime SOURCE: PointerSource, comptime T: type, comptime A: usize) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .NULLABILITY = .NULLABLE, .ALIGNMENT = normalize_align(A) });
    }
    pub fn ConstPointer(comptime SOURCE: PointerSource, comptime T: type) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST });
    }
    pub fn ConstPointerAlign(comptime SOURCE: PointerSource, comptime T: type, comptime A: usize) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .ALIGNMENT = normalize_align(A) });
    }
    pub fn NullableConstPointer(comptime SOURCE: PointerSource, comptime T: type) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .NULLABILITY = .NULLABLE });
    }
    pub fn NullableConstPointerAlign(comptime SOURCE: PointerSource, comptime T: type, comptime A: usize) type {
        return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .NULLABILITY = .NULLABLE, .ALIGNMENT = normalize_align(A) });
    }
};

/// A generic 'Pointer' type that can wrap either a native
/// pointer, or pointer handle that can be resolved/manipulated via a
/// small set of static functions on the PointerSource.STATIC_RESOLVER
///
/// A `.NATIVE` pointer source has the same size as a native
/// pointer, and should compile most of these methods
/// to identical instructions as if you were working directly
/// with the native pointer type defined by the PTR_DEF settings.
///
/// Using a `.STATIC_RESOLVER` allows using an arbitrary type
/// as a handle that can be resolved to a real native pointer
/// via a comptime-known static function (For example, provided
/// by a specially designed global allocator).
///
/// The `.STATIC_RESOLVER` option allows you to have pointer-access
/// semantics with a handle type that may be much smaller than a `usize`, or
/// that has some other interesting semantics such as side-effects
/// when a pointer is resolved, at the cost of additional processing overhead.
pub fn PointerAdvanced(comptime SOURCE_: PointerSource, comptime PTR_DEF_: MakePtrDefNoSize) type {
    return struct {
        const Self = @This();
        pub const InternalPtr = SOURCE.InternalPtr(PTR_DEF);
        const InternalInternalPtr = if (IS_NATIVE and NULL_AND_ALLOWZERO) @typeInfo(InternalPtr).optional.child else InternalPtr;
        pub const PtrMany = MakePtrFromDef(PTR_DEF_FULL);
        pub const PtrOne = MakePtrFromDef(PTR_DEF_FULL.with_sentinel(null).with_size_kind(.one));
        pub const PtrC = MakePtrFromDef(PTR_DEF_FULL.with_c_pointer_constraints());
        pub const Slice = MakePtrFromDef(PTR_DEF_FULL.with_size_kind(.slice));
        pub const PtrManyNeverNull = MakePtrFromDef(PTR_DEF_FULL.with_nullability(.NEVER_NULL));
        pub const PtrOneNeverNull = MakePtrFromDef(PTR_DEF_FULL.with_sentinel(null).with_nullability(.NEVER_NULL).with_size_kind(.one));
        pub const SliceNeverNull = MakePtrFromDef(PTR_DEF_FULL.with_nullability(.NEVER_NULL).with_size_kind(.slice));
        pub const PtrManyNullable = MakePtrFromDef(PTR_DEF_FULL.with_nullability(.NULLABLE));
        pub const PtrOneNullable = MakePtrFromDef(PTR_DEF_FULL.with_sentinel(null).with_nullability(.NULLABLE).with_size_kind(.one));
        pub const SliceNullable = MakePtrFromDef(PTR_DEF_FULL.with_nullability(.NULLABLE).with_size_kind(.slice));
        pub const INTERNAL_PTR_DEFAULT: InternalPtr = SOURCE.InternalPtrDefault(PTR_DEF);
        pub const PTR_DEF = PTR_DEF_;
        pub const PTR_DEF_FULL = PTR_DEF.to_make_ptr_def(.many);
        pub const SOURCE = SOURCE_;

        const static_resolve_addr: SOURCE.ResolverFn() = SOURCE.ResolverFnInit();
        const static_ptr_incr: SOURCE.IncrementFn() = SOURCE.IncrementFnInit();
        const static_ptr_decr: SOURCE.DecrementFn() = SOURCE.DecrementFnInit();
        const static_ptr_is_null: SOURCE.NullCheckFn() = SOURCE.NullCheckFnInit();
        pub const USE_STATIC_RESOLVER = SOURCE == .STATIC_RESOLVER;
        pub const IS_NATIVE = SOURCE == .NATIVE;
        pub const ELEMENT = PTR_DEF.ELEMENT;
        pub const ELEMENT_SIZE = @sizeOf(PTR_DEF.ELEMENT);
        pub const IS_ALLOW_ZERO = PTR_DEF.ALLOW_ZERO == .ALLOW_ZERO;
        pub const IS_VOLATILE = PTR_DEF.VOLATILE == .VOLATILE;
        pub const IS_NATIVE_ALIGNED = USES_NATIVE_ALIGN or (ALIGN == @alignOf(ELEMENT));
        pub const USES_NATIVE_ALIGN = PTR_DEF.ALIGNMENT == null;
        pub const HAS_SPECIFIC_ALIGN = PTR_DEF.ALIGNMENT != null;
        pub const ALIGN: usize = if (PTR_DEF.ALIGNMENT) |A| A.value_as_type(usize) else @alignOf(ELEMENT);
        pub const ALIGN_POW2: PowerOf2 = if (PTR_DEF.ALIGNMENT) |A| A else PowerOf2.align_of_type(ELEMENT);
        const PTR_DEF_IF_MOVED = if (ALIGN > @alignOf(ELEMENT)) PTR_DEF.with_align(null) else PTR_DEF;
        const SelfIfMoved = PointerAdvanced(SOURCE_, PTR_DEF_IF_MOVED);
        pub const ADDRSPACE = PTR_DEF.ADDRSPACE;
        pub const IS_CONST = PTR_DEF.MUTABILITY == .CONST;
        pub const IS_MUTABLE = PTR_DEF.MUTABILITY == .MUTABLE;
        pub const CAN_BE_NULL = PTR_DEF.NULLABILITY == .NULLABLE;
        pub const NEVER_NULL = PTR_DEF.NULLABILITY == .NEVER_NULL;
        pub const HAS_SENTINEL = PTR_DEF.SENTINEL != null;
        pub const SENTINEL: ELEMENT = if (PTR_DEF.SENTINEL) |S| @as(*const ELEMENT, @ptrCast(@alignCast(S))).* else undefined;
        pub const ZERO_SIZE_ELEM = @sizeOf(ELEMENT) == 0;
        const NULL_AND_ALLOWZERO = CAN_BE_NULL and IS_ALLOW_ZERO;
        const GRANULARITY_NOT_1 = SOURCE == .STATIC_RESOLVER and SOURCE.STATIC_RESOLVER.ADDRESS_GRANULARITY.greater_than(._1);
        const GRANULARITY_FAIL_MASK: if (GRANULARITY_NOT_1) usize else void = if (GRANULARITY_NOT_1) SOURCE.STATIC_RESOLVER.ADDRESS_GRANULARITY.bit_mask_less_than(usize) else {};
        const GRANULARITY_PASS_MASK: if (GRANULARITY_NOT_1) usize else void = if (GRANULARITY_NOT_1) SOURCE.STATIC_RESOLVER.ADDRESS_GRANULARITY.bit_mask_greater_than_or_equal(usize) else {};
        const GRANULARITY: if (GRANULARITY_NOT_1) usize else void = if (GRANULARITY_NOT_1) SOURCE.STATIC_RESOLVER.ADDRESS_GRANULARITY.value_as_type(usize) else {};
        const GRANULARITY_MINUS_1: if (GRANULARITY_NOT_1) usize else void = if (GRANULARITY_NOT_1) GRANULARITY - 1 else {};
        const ASSERT_CONTIG = if (USE_STATIC_RESOLVER and Assert.SHOULD_ASSERT) SOURCE.STATIC_RESOLVER.ASSERT_CONTIGUOUS_RANGE else false;

        internal: InternalPtr = INTERNAL_PTR_DEFAULT,

        pub inline fn new_from(internal_val: InternalPtr) Self {
            return Self{ .internal = internal_val };
        }
        /// Accepts an `InternalPtr` type in any mode, or in `NATIVE` mode
        /// accepts any native pointer that can be cast to an `InternalPtr`
        /// with `@ptrCast(@alignCast(ptr))`
        pub inline fn new_from_any(any_ptr: anytype) Self {
            if (comptime @TypeOf(any_ptr) == InternalPtr) return new_from(any_ptr);
            assert_native(@src());
            return Self{ .internal = @ptrCast(@alignCast(any_ptr)) };
        }

        pub inline fn is_native(self: Self) bool {
            _ = self;
            return IS_NATIVE;
        }
        pub inline fn is_global_resolver(self: Self) bool {
            _ = self;
            return USE_STATIC_RESOLVER;
        }
        pub inline fn is_const(self: Self) bool {
            _ = self;
            return IS_CONST;
        }
        pub inline fn is_mutable(self: Self) bool {
            _ = self;
            return IS_MUTABLE;
        }
        pub inline fn can_be_null(self: Self) bool {
            _ = self;
            return CAN_BE_NULL;
        }
        pub inline fn can_never_be_null(self: Self) bool {
            _ = self;
            return NEVER_NULL;
        }
        pub inline fn ptr_alignment_pow2(self: Self) PowerOf2 {
            _ = self;
            return ALIGN_POW2;
        }
        pub inline fn ptr_alignment(self: Self) usize {
            _ = self;
            return ALIGN;
        }
        pub inline fn has_sentinel(self: Self) bool {
            _ = self;
            return HAS_SENTINEL;
        }
        pub inline fn sentinel_value(self: Self) ELEMENT {
            _ = self;
            return SENTINEL;
        }
        pub inline fn elem_is_zero_sized(self: Self) bool {
            _ = self;
            return ZERO_SIZE_ELEM;
        }

        inline fn pointer_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    // if (comptime CAN_BE_NULL) {
                    //     if (self.is_null()) {
                    //         if (comptime NewPtr.CAN_BE_NULL) break :blk NewPtr.new_null();
                    //         self.assert_not_null(@src());
                    //     }
                    // }
                    // const raw = if (comptime CAN_BE_NULL) self.internal.? else self.internal;
                    // break :blk NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @ptrCast(raw)) };
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @ptrCast(self.internal.?)) };
                } else {
                    return NewPtr{ .internal = @ptrCast(self.internal) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn pointer_align_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @ptrCast(@alignCast(self.internal.?))) };
                } else {
                    return NewPtr{ .internal = @ptrCast(@alignCast(self.internal)) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn align_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @alignCast(self.internal.?)) };
                } else {
                    return NewPtr{ .internal = @alignCast(self.internal) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn remove_volatile_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @volatileCast(self.internal.?)) };
                } else {
                    return NewPtr{ .internal = @volatileCast(self.internal) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn remove_const_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @constCast(self.internal.?)) };
                } else {
                    return NewPtr{ .internal = @constCast(self.internal) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn addrspace_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @addrSpaceCast(self.internal.?)) };
                } else {
                    return NewPtr{ .internal = @addrSpaceCast(self.internal) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }
        inline fn raw_address_cast(self: Self, comptime TARGET: MakePtrDefNoSize) PointerAdvanced(SOURCE, TARGET) {
            const NewPtr = PointerAdvanced(SOURCE, TARGET);
            switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) {
                    if (comptime CAN_BE_NULL and NewPtr.CAN_BE_NULL) {
                        if (self.is_null()) return NewPtr.new_null();
                    } else if (comptime CAN_BE_NULL and !NewPtr.CAN_BE_NULL) {
                        self.assert_not_null(@src());
                    }
                    return NewPtr{ .internal = @as(NewPtr.InternalInternalPtr, @ptrFromInt(@intFromPtr(self.internal.?))) };
                } else {
                    return NewPtr{ .internal = @ptrFromInt(@intFromPtr(self.internal)) };
                },
                .STATIC_RESOLVER => return NewPtr{ .internal = self.internal },
            }
        }

        pub inline fn addr(self: Self) usize {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) @intFromPtr(self.internal.?) else @intFromPtr(self.internal),
                .STATIC_RESOLVER => blk: {
                    const a = static_resolve_addr(self.internal);
                    if (comptime !IS_ALLOW_ZERO) {
                        assert_with_reason(a != 0, @src(), "static resolver returned address 0 when the pointer type does not allow valid address 0: the resolver returned a null address even though the local handle was not null", .{});
                    }
                    if (comptime ALIGN > 1) {
                        assert_with_reason(std.mem.isAlignedLog2(a, ALIGN_POW2.raw_int()), @src(), "resolved address was not properly aligned", .{});
                    }
                    break :blk a;
                },
            };
        }
        pub inline fn addr_orelse_0(self: Self) usize {
            if (self.is_null()) return 0;
            return switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) @intFromPtr(self.internal.?) else @intFromPtr(self.internal),
                .STATIC_RESOLVER => blk: {
                    const a = static_resolve_addr(self.internal);
                    if (comptime !IS_ALLOW_ZERO) {
                        assert_with_reason(a != 0, @src(), "static resolver returned address 0 when the pointer type does not allow valid address 0: the resolver returned a null address even though the local handle was not null", .{});
                    }
                    if (comptime ALIGN > 1) {
                        assert_with_reason(std.mem.isAlignedLog2(a, ALIGN_POW2.raw_int()), @src(), "resolved address was not properly aligned", .{});
                    }
                    break :blk a;
                },
            };
        }
        pub inline fn addr_or_null(self: Self) ?usize {
            if (self.is_null()) return null;
            return switch (comptime SOURCE) {
                .NATIVE => if (comptime NULL_AND_ALLOWZERO) @intFromPtr(self.internal.?) else @intFromPtr(self.internal),
                .STATIC_RESOLVER => blk: {
                    const a = static_resolve_addr(self.internal);
                    if (comptime !IS_ALLOW_ZERO) {
                        assert_with_reason(a != 0, @src(), "static resolver returned address 0 when the pointer type does not allow valid address 0: the resolver returned a null address even though the local handle was not null", .{});
                    }
                    if (comptime ALIGN > 1) {
                        assert_with_reason(std.mem.isAlignedLog2(a, ALIGN_POW2.raw_int()), @src(), "resolved address was not properly aligned", .{});
                    }
                    break :blk a;
                },
            };
        }
        pub inline fn addr_no_align_check(self: Self) usize {
            self.assert_not_null(@src());
            switch (comptime SOURCE) {
                .NATIVE => return if (comptime NULL_AND_ALLOWZERO) @intFromPtr(self.internal.?) else @intFromPtr(self.internal),
                .STATIC_RESOLVER => {
                    const a = static_resolve_addr(self.internal);
                    if (comptime !IS_ALLOW_ZERO) {
                        assert_with_reason(a != 0, @src(), "static resolver returned address 0 when the pointer type does not allow valid address 0: the resolver returned a null address even though the local handle was not null", .{});
                    }
                    return a;
                },
            }
        }

        pub inline fn ptr_many(self: Self) PtrMany {
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) return null;
            }
            return self.ptr_many_never_null();
        }
        pub inline fn ptr_many_or_null(self: Self) PtrManyNullable {
            if (self.is_null()) return null;
            return self.ptr_many_never_null();
        }
        pub inline fn ptr_many_never_null(self: Self) PtrManyNeverNull {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => if (comptime CAN_BE_NULL) self.internal.? else self.internal,
                .STATIC_RESOLVER => blk: {
                    const a = static_resolve_addr(self.internal);
                    if (comptime !IS_ALLOW_ZERO) {
                        assert_with_reason(a != 0, @src(), "static resolver returned address 0 when the pointer type does not allow valid address 0: the resolver returned a null address even though the local handle was not null", .{});
                    }
                    if (comptime ALIGN > 1) {
                        assert_with_reason(std.mem.isAlignedLog2(a, ALIGN_POW2.raw_int()), @src(), "resolved address was not properly aligned", .{});
                    }
                    break :blk @ptrFromInt(a);
                },
            };
        }
        pub inline fn ptr(self: Self) PtrOne {
            return @ptrCast(self.ptr_many());
        }
        pub inline fn ptr_or_null(self: Self) PtrOneNullable {
            if (self.is_null()) return null;
            return self.ptr_never_null();
        }
        pub inline fn ptr_never_null(self: Self) PtrOneNeverNull {
            return @ptrCast(self.ptr_many_never_null());
        }
        pub inline fn ptr_c(self: Self) PtrC {
            if (self.is_null()) return null;
            if (comptime IS_ALLOW_ZERO) {
                assert_with_reason(self.addr() != 0, @src(), "a C-pointer uses the 'allowzero' attribute, but it uses it as the 'null' value, not a valid address. The current pointer type uses 'allowzero' as a VALID address, and the current address is 0: There is no way to map this valid address into a C-pointer, because it would be considered 'null'", .{});
            }
            return @ptrCast(self.complete_cast_to(PTR_DEF.with_c_pointer_constraints()).ptr_many());
        }
        pub inline fn ptr_c_or_null(self: Self) ?PtrC {
            if (self.is_null()) return null;
            if (comptime IS_ALLOW_ZERO) {
                assert_with_reason(self.addr() != 0, @src(), "a C-pointer uses the 'allowzero' attribute, but it uses it as the 'null' value, not a valid address. The current pointer type uses 'allowzero' as a VALID address, and the current address is 0: There is no way to map this valid address into a C-pointer, because it would be considered 'null'", .{});
            }
            return @as(PtrC, @ptrCast(self.complete_cast_to(PTR_DEF.with_c_pointer_constraints()).ptr_many()));
        }
        pub inline fn ptr_c_never_null(self: Self) PtrC {
            self.assert_not_null(@src());
            if (comptime IS_ALLOW_ZERO) {
                assert_with_reason(self.addr() != 0, @src(), "a C-pointer uses the 'allowzero' attribute, but it uses it as the 'null' value, not a valid address. The current pointer type uses 'allowzero' as a VALID address, and the current address is 0: There is no way to map this valid address into a C-pointer, because it would be considered 'null'", .{});
            }
            return @ptrCast(self.complete_cast_to(PTR_DEF.with_c_pointer_constraints()).ptr_many());
        }
        pub inline fn slice(self: Self, len: anytype) Slice {
            self.assert_index_not_negative(len, @src());
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) return null;
            }
            return self.slice_never_null(len);
        }
        pub inline fn slice_or_null(self: Self, len: anytype) SliceNullable {
            self.assert_index_not_negative(len, @src());
            if (self.is_null()) return null;
            return self.slice_never_null(len);
        }
        pub inline fn slice_never_null(self: Self, len: anytype) SliceNeverNull {
            self.assert_index_not_negative(len, @src());
            self.assert_not_null(@src());

            const n = num_cast(len, usize);
            const p = self.ptr_many_never_null();
            if (comptime ZERO_SIZE_ELEM) {
                if (comptime HAS_SENTINEL) {
                    return p[0..n :SENTINEL];
                } else {
                    return p[0..n];
                }
            }
            if (comptime ASSERT_CONTIG) {
                if (comptime HAS_SENTINEL) {
                    assert_contiguous(self.internal, .ADD, (ELEMENT_SIZE * (n + 1)) - 1, @src());
                } else if (n > 0) {
                    assert_contiguous(self.internal, .ADD, (ELEMENT_SIZE * n) - 1, @src());
                }
            }
            if (comptime HAS_SENTINEL) {
                assert_with_reason(p[n] == SENTINEL, @src(), "the pointer type requires a sentinel, but the element at the 'len' index ({d}) did not equal the sentinel value {} (got {})", .{ n, SENTINEL, p[n] });
                return p[0..n :SENTINEL];
            } else {
                return p[0..n];
            }
        }
        pub inline fn slice_and_write_sentinel(self: Self, len: anytype) Slice {
            self.assert_index_not_negative(len, @src());
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) return null;
            }
            return self.slice_and_write_sentinel_never_null(len);
        }
        pub inline fn slice_and_write_sentinel_or_null(self: Self, len: anytype) SliceNullable {
            self.assert_index_not_negative(len, @src());
            if (self.is_null()) return null;
            return self.slice_and_write_sentinel_never_null(len);
        }
        pub inline fn slice_and_write_sentinel_never_null(self: Self, len: anytype) SliceNeverNull {
            self.assert_index_not_negative(len, @src());
            self.assert_not_null(@src());
            self.write_sentinel_at_len(len);
            const n = num_cast(len, usize);
            const p = self.ptr_many_never_null();
            if (comptime ZERO_SIZE_ELEM) {
                if (comptime HAS_SENTINEL) {
                    return p[0..n :SENTINEL];
                } else {
                    return p[0..n];
                }
            }
            if (comptime ASSERT_CONTIG) {
                if (comptime HAS_SENTINEL) {
                    assert_contiguous(self.internal, .ADD, (ELEMENT_SIZE * (n + 1)) - 1, @src());
                } else if (n > 0) {
                    assert_contiguous(self.internal, .ADD, (ELEMENT_SIZE * n) - 1, @src());
                }
            }
            if (comptime HAS_SENTINEL) {
                return p[0..n :SENTINEL];
            } else {
                return p[0..n];
            }
        }
        pub inline fn slice_find_len_from_sentinel(self: Self) Slice {
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) return null;
            }
            return self.slice_never_null_find_len_from_sentinel();
        }
        pub inline fn slice_or_null_find_len_from_sentinel(self: Self) SliceNullable {
            if (self.is_null()) return null;
            return self.slice_never_null_find_len_from_sentinel();
        }
        pub inline fn slice_never_null_find_len_from_sentinel(self: Self) SliceNeverNull {
            self.assert_not_null(@src());
            const len = self.find_len_from_sentinel();
            return self.slice_never_null(len);
        }
        pub inline fn slice_find_len_from_sentinel_with_upper_limit_assert(self: Self, limit: anytype) Slice {
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) return null;
            }
            return self.slice_never_null_find_len_from_sentinel_with_upper_limit_assert(limit);
        }
        pub inline fn slice_or_null_find_len_from_sentinel_with_upper_limit_assert(self: Self, limit: anytype) SliceNullable {
            if (self.is_null()) return null;
            return self.slice_never_null_find_len_from_sentinel_with_upper_limit_assert(limit);
        }
        pub inline fn slice_never_null_find_len_from_sentinel_with_upper_limit_assert(self: Self, limit: anytype) SliceNeverNull {
            self.assert_not_null(@src());
            const len = self.find_len_from_sentinel_upper_limit_panic(limit);
            return self.slice_never_null(len);
        }
        pub inline fn byte_slice(self: Self, elem_len: anytype) PointerAdvanced(SOURCE, PTR_DEF.with_element(u8)).Slice {
            self.assert_index_not_negative(elem_len, @src());
            return self.complete_cast_to(PTR_DEF.with_element(u8)).slice(num_cast(elem_len, usize) * ELEMENT_SIZE);
        }
        pub inline fn byte_slice_or_null(self: Self, elem_len: anytype) PointerAdvanced(SOURCE, PTR_DEF.with_element(u8)).SliceNullable {
            self.assert_index_not_negative(elem_len, @src());
            return self.complete_cast_to(PTR_DEF.with_element(u8)).slice_or_null(num_cast(elem_len, usize) * ELEMENT_SIZE);
        }
        pub inline fn byte_slice_never_null(self: Self, elem_len: anytype) PointerAdvanced(SOURCE, PTR_DEF.with_element(u8)).SliceNeverNull {
            self.assert_index_not_negative(elem_len, @src());
            return self.complete_cast_to(PTR_DEF.with_element(u8)).slice_never_null(num_cast(elem_len, usize) * ELEMENT_SIZE);
        }

        pub inline fn write_sentinel_at_len(self: Self, len: anytype) void {
            if (comptime !HAS_SENTINEL) return;
            self.set_at_index_if_not_null(len, SENTINEL);
        }
        pub inline fn find_len_from_sentinel(self: Self) usize {
            comptime assert_with_reason(HAS_SENTINEL, @src(), "pointer type does not have a sentinel value", .{});
            const p = self.ptr_many_never_null();
            var i: usize = 0;
            const POSSIBLE_VEC_SIZE = comptime std.simd.suggestVectorLength(ELEMENT);
            if (comptime ALIGN >= ELEMENT_SIZE and POSSIBLE_VEC_SIZE != null and !ASSERT_CONTIG and !IS_VOLATILE) {
                const VEC_SIZE = POSSIBLE_VEC_SIZE.?;
                const BOOL_VEC = @Vector(VEC_SIZE, bool);
                const BOOL_VEC_INT = @Int(.unsigned, VEC_SIZE);
                const VEC = @Vector(VEC_SIZE, ELEMENT);
                const VEC_ALIGN = @alignOf(VEC);
                const CURR_ADDR = self.addr();
                const NEXT_VEC_ALIGNED_ADDR = std.mem.alignForward(usize, CURR_ADDR, VEC_ALIGN);
                const ADDR_DELTA_UNTIL_NEXT_VEC_ALIGN = NEXT_VEC_ALIGNED_ADDR - CURR_ADDR;
                const NUM_SINGLES_BEFORE_VEC_ALIGN = @divExact(ADDR_DELTA_UNTIL_NEXT_VEC_ALIGN, ELEMENT_SIZE);
                const SENTINEL_VEC: VEC = @splat(SENTINEL);
                while (i < NUM_SINGLES_BEFORE_VEC_ALIGN) {
                    if (p[i] == SENTINEL) return i;
                    i += 1;
                }
                const vp = self.increment(NUM_SINGLES_BEFORE_VEC_ALIGN).cast_to_element(VEC).ptr_many_never_null();
                var vi: usize = 0;
                while (true) {
                    const found_sentinel_in_vec: BOOL_VEC = vp[vi] == SENTINEL_VEC;
                    const found_sentinel_in_vec_int: BOOL_VEC_INT = @bitCast(found_sentinel_in_vec);
                    if (found_sentinel_in_vec_int != 0) {
                        const found_index: usize = @intCast(@ctz(found_sentinel_in_vec_int));
                        return i + found_index;
                    }
                    i += VEC_SIZE;
                    vi += 1;
                }
            } else {
                while (true) {
                    if (p[i] == SENTINEL) return i;
                    i += 1;
                }
            }
        }
        pub inline fn find_len_from_sentinel_upper_limit_panic(self: Self, limit: anytype) usize {
            comptime assert_with_reason(HAS_SENTINEL, @src(), "pointer type does not have a sentinel value", .{});
            assert_with_reason(limit >= 0, @src(), "limit must be >= 0, got {d}", .{limit});
            const p = self.ptr_many_never_null();
            var i: usize = 0;
            const lim = num_cast(limit, usize);
            const POSSIBLE_VEC_SIZE = comptime std.simd.suggestVectorLength(ELEMENT);
            if (comptime ALIGN >= ELEMENT_SIZE and POSSIBLE_VEC_SIZE != null and !ASSERT_CONTIG and !IS_VOLATILE) {
                const VEC_SIZE = POSSIBLE_VEC_SIZE.?;
                const BOOL_VEC = @Vector(VEC_SIZE, bool);
                const BOOL_VEC_INT = @Int(.unsigned, VEC_SIZE);
                const VEC = @Vector(VEC_SIZE, ELEMENT);
                const VEC_ALIGN = @alignOf(VEC);
                const CURR_ADDR = self.addr();
                const NEXT_VEC_ALIGNED_ADDR = std.mem.alignForward(usize, CURR_ADDR, VEC_ALIGN);
                const ADDR_DELTA_UNTIL_NEXT_VEC_ALIGN = NEXT_VEC_ALIGNED_ADDR - CURR_ADDR;
                const NUM_SINGLES_BEFORE_VEC_ALIGN = @divExact(ADDR_DELTA_UNTIL_NEXT_VEC_ALIGN, ELEMENT_SIZE);
                const SENTINEL_VEC: VEC = @splat(SENTINEL);
                while (i < NUM_SINGLES_BEFORE_VEC_ALIGN) {
                    if (p[i] == SENTINEL) return i;
                    assert_with_reason(i < lim, @src(), "reached the length limit to search for sentinel value within without finding sentinel ({d})", .{lim});
                    i += 1;
                }
                const vp = self.increment(NUM_SINGLES_BEFORE_VEC_ALIGN).cast_to_element(VEC).ptr_many_never_null();
                var vi: usize = 0;
                while (true) {
                    const found_sentinel_in_vec: BOOL_VEC = vp[vi] == SENTINEL_VEC;
                    const found_sentinel_in_vec_int: BOOL_VEC_INT = @bitCast(found_sentinel_in_vec);
                    if (found_sentinel_in_vec_int != 0) {
                        const found_index: usize = @intCast(@ctz(found_sentinel_in_vec_int));
                        assert_with_reason(i <= lim, @src(), "reached the length limit to search for sentinel value within without finding sentinel ({d})", .{lim});
                        return i + found_index;
                    }
                    assert_with_reason(i < lim, @src(), "reached the length limit to search for sentinel value within without finding sentinel ({d})", .{lim});
                    i += VEC_SIZE;
                    vi += 1;
                }
            } else {
                while (true) {
                    if (p[i] == SENTINEL) return i;
                    assert_with_reason(i < lim, @src(), "reached the length limit to search for sentinel value within without finding sentinel ({d})", .{lim});
                    i += 1;
                }
            }
        }

        pub inline fn is_null(self: Self) bool {
            if (comptime !CAN_BE_NULL) return false;
            return switch (comptime SOURCE) {
                .NATIVE => self.internal == null,
                .STATIC_RESOLVER => static_ptr_is_null(self.internal),
            };
        }
        pub inline fn not_null(self: Self) bool {
            if (comptime !CAN_BE_NULL) return true;
            return switch (comptime SOURCE) {
                .NATIVE => self.internal != null,
                .STATIC_RESOLVER => !static_ptr_is_null(self.internal),
            };
        }
        pub inline fn assert_not_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.not_null(), src, "pointer was null", .{});
        }
        pub inline fn assert_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_null(), src, "pointer was not null", .{});
        }
        pub inline fn assert_mutable(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(IS_MUTABLE, src, "pointer was const, cannot modify element(s)", .{});
        }

        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(IS_NATIVE, src, "cannot be called when mode is not .NATIVE", .{});
        }
        pub inline fn assert_not_overaligned(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(ALIGN <= @alignOf(ELEMENT), src, "cannot call this when pointer is over-aligned; use the non-in-place variant instead", .{});
        }
        pub inline fn assert_not_allowzero(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(!IS_ALLOW_ZERO, src, "cannot call this when the pointer is `allowzero`", .{});
        }
        pub inline fn assert_not_volatile(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(PTR_DEF.VOLATILE != .VOLATILE, src, "cannot call this when the pointer is `volatile`", .{});
        }
        pub inline fn assert_normal_addrspace(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(PTR_DEF.ADDRSPACE == null or PTR_DEF.ADDRSPACE.? == .generic, src, "cannot call this when the pointer addrspace is not `.generic` (the default when ADDRSPACE is `null`, Zig's normal addrspace)", .{});
        }
        pub inline fn assert_not_zero_size_type(comptime src: ?SourceLocation) void {
            comptime assert_with_reason(!ZERO_SIZE_ELEM, src, "cannot call this when the element type is zero-sized, got type `{s}`", .{@typeName(ELEMENT)});
        }

        pub inline fn complete_cast_to(self: Self, comptime NEW_DEF: MakePtrDefNoSize) PointerAdvanced(SOURCE, NEW_DEF) {
            const NewPtr = PointerAdvanced(SOURCE, NEW_DEF);
            if (comptime CAN_BE_NULL) {
                if (self.is_null()) {
                    if (comptime NEW_DEF.NULLABILITY == .NULLABLE) return NewPtr.new_null();
                    self.assert_not_null(@src());
                }
            }
            const p1 = switch (comptime NEW_DEF.NULLABILITY) {
                .NULLABLE => self.to_nullable(),
                .NEVER_NULL => self.to_non_null(),
            };
            const p2 = if (NEW_DEF.ADDRSPACE) |NEW_ADDR_SPACE|
                p1.to_specific_addrspace(NEW_ADDR_SPACE)
            else
                p1.to_normal_addrspace();
            const p3 = switch (comptime NEW_DEF.ALLOW_ZERO) {
                .ALLOW_ZERO => p2.to_allowzero(),
                .NO_ALLOW_ZERO => p2.remove_allowzero(),
            };
            const p4 = switch (comptime NEW_DEF.VOLATILE) {
                .VOLATILE => p3.to_volatile(),
                .NOT_VOLATILE => p3.remove_volatile(),
            };
            const p5 = switch (comptime NEW_DEF.MUTABILITY) {
                .CONST => p4.to_const(),
                .MUTABLE => p4.to_mutable(),
            };
            const p6 = blk: {
                if (comptime NEW_DEF.ALIGNMENT) |NEW_A| {
                    if (comptime NEW_DEF.SENTINEL) |NEW_S_OPQ| {
                        const NEW_S: *const NEW_DEF.ELEMENT = @ptrCast(@alignCast(NEW_S_OPQ));
                        break :blk p5.cast_to_element_with_sentinel_aligned(NEW_DEF.ELEMENT, NEW_S.*, NEW_A);
                    } else {
                        break :blk p5.cast_to_element_aligned(NEW_DEF.ELEMENT, NEW_A);
                    }
                } else {
                    if (comptime NEW_DEF.SENTINEL) |NEW_S_OPQ| {
                        const NEW_S: *const NEW_DEF.ELEMENT = @ptrCast(@alignCast(NEW_S_OPQ));
                        break :blk p5.cast_to_element_with_sentinel(NEW_DEF.ELEMENT, NEW_S.*);
                    } else {
                        break :blk p5.cast_to_element(NEW_DEF.ELEMENT);
                    }
                }
            };
            return p6;
        }
        pub inline fn unchecked_cast_to(self: Self, comptime NEW_DEF: MakePtrDefNoSize) PointerAdvanced(SOURCE, NEW_DEF) {
            return self.raw_address_cast(NEW_DEF);
        }
        pub inline fn to_const(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)) {
            if (comptime IS_CONST) return self;
            return self.pointer_cast(PTR_DEF.with_mutability(.CONST));
        }
        pub inline fn to_mutable(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.MUTABLE)) {
            if (comptime IS_MUTABLE) return self;
            return self.remove_const_cast(PTR_DEF.with_mutability(.MUTABLE));
        }
        pub inline fn to_nullable(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)) {
            if (comptime CAN_BE_NULL) return self;
            return self.pointer_cast(PTR_DEF.with_nullability(.NULLABLE));
        }
        pub inline fn to_non_null(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NEVER_NULL)) {
            if (comptime NEVER_NULL) return self;
            self.assert_not_null(@src());
            return self.pointer_cast(PTR_DEF.with_nullability(.NEVER_NULL));
        }

        pub inline fn to_allowzero(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.ALLOW_ZERO)) {
            if (comptime IS_ALLOW_ZERO) return self;
            return self.pointer_cast(PTR_DEF.with_allow_zero(.ALLOW_ZERO));
        }
        pub inline fn remove_allowzero(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.NO_ALLOW_ZERO)) {
            if (comptime !IS_ALLOW_ZERO) return self;
            assert_with_reason(self.is_null() or self.addr() != 0, @src(), "new pointer def does not allow zero as a valid address, but the current address is 0", .{});
            return self.pointer_cast(PTR_DEF.with_allow_zero(.NO_ALLOW_ZERO));
        }
        pub inline fn to_volatile(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.VOLATILE)) {
            if (comptime IS_VOLATILE) return self;
            return self.pointer_cast(PTR_DEF.with_volatile(.VOLATILE));
        }
        pub inline fn remove_volatile(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.NOT_VOLATILE)) {
            if (comptime !IS_VOLATILE) return self;
            return self.remove_volatile_cast(PTR_DEF.with_volatile(.NOT_VOLATILE));
        }
        pub inline fn to_specific_addrspace(self: Self, comptime addr_space: AddrSpace) PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(addr_space)) {
            if (comptime ADDRSPACE != null and ADDRSPACE.? == addr_space) return self;
            return self.addrspace_cast(PTR_DEF.with_addrspace(addr_space));
        }
        pub inline fn to_normal_addrspace(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(null)) {
            if (comptime ADDRSPACE == null) return self;
            return self.addrspace_cast(PTR_DEF.with_addrspace(null));
        }
        pub inline fn cast_to_element(self: Self, comptime NEW_ELEM: type) PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(null)) {
            if (comptime ELEMENT == NEW_ELEM and !HAS_SPECIFIC_ALIGN and !HAS_SENTINEL) return self;
            const NewPtr = PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(null));
            if (self.not_null()) {
                self.assert_aligned(@alignOf(NEW_ELEM), @src());
                if (comptime NewPtr.ELEMENT_SIZE > ELEMENT_SIZE) {
                    assert_contiguous(self.internal, .ADD, NewPtr.ELEMENT_SIZE - 1, @src());
                }
            }
            return self.pointer_align_cast(PTR_DEF.with_element(NEW_ELEM).with_align(null));
        }
        pub inline fn cast_to_element_with_sentinel(self: Self, comptime NEW_ELEM: type, comptime NEW_SENTINEL: NEW_ELEM) PointerAdvanced(SOURCE, PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(null)) {
            if (comptime ELEMENT == NEW_ELEM and !HAS_SPECIFIC_ALIGN and HAS_SENTINEL and SENTINEL == NEW_SENTINEL) return self;
            const NewPtr = PointerAdvanced(SOURCE, PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(null));
            if (self.not_null()) {
                self.assert_aligned(@alignOf(NEW_ELEM), @src());
                if (comptime NewPtr.ELEMENT_SIZE > ELEMENT_SIZE) {
                    assert_contiguous(self.internal, .ADD, NewPtr.ELEMENT_SIZE - 1, @src());
                }
            }
            return self.pointer_align_cast(PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(null));
        }
        pub inline fn cast_to_element_aligned(self: Self, comptime NEW_ELEM: type, comptime SPECIFIC_ALIGN: PowerOf2) PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN)) {
            if (comptime ELEMENT == NEW_ELEM and HAS_SPECIFIC_ALIGN and ALIGN_POW2 == SPECIFIC_ALIGN and !HAS_SENTINEL) return self;
            const NewPtr = PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN));
            if (self.not_null()) {
                self.assert_aligned_pow_2(SPECIFIC_ALIGN, @src());
                if (comptime NewPtr.ELEMENT_SIZE > ELEMENT_SIZE) {
                    assert_contiguous(self.internal, .ADD, NewPtr.ELEMENT_SIZE - 1, @src());
                }
            }
            return self.pointer_align_cast(PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN));
        }
        pub inline fn cast_to_element_with_sentinel_aligned(self: Self, comptime NEW_ELEM: type, comptime NEW_SENTINEL: NEW_ELEM, comptime SPECIFIC_ALIGN: PowerOf2) PointerAdvanced(SOURCE, PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(SPECIFIC_ALIGN)) {
            if (comptime ELEMENT == NEW_ELEM and HAS_SENTINEL and SENTINEL == NEW_SENTINEL and HAS_SPECIFIC_ALIGN and ALIGN_POW2 == SPECIFIC_ALIGN) return self;
            const NewPtr = PointerAdvanced(SOURCE, PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(SPECIFIC_ALIGN));
            if (self.not_null()) {
                self.assert_aligned_pow_2(SPECIFIC_ALIGN, @src());
                if (comptime NewPtr.ELEMENT_SIZE > ELEMENT_SIZE) {
                    assert_contiguous(self.internal, .ADD, NewPtr.ELEMENT_SIZE - 1, @src());
                }
            }
            return self.pointer_align_cast(PTR_DEF.with_element_and_sentinel(NEW_ELEM, NEW_SENTINEL).with_align(SPECIFIC_ALIGN));
        }
        pub inline fn to_specific_align(self: Self, comptime SPECIFIC_ALIGN: PowerOf2) PointerAdvanced(SOURCE, PTR_DEF.with_align(SPECIFIC_ALIGN)) {
            if (comptime HAS_SPECIFIC_ALIGN and ALIGN_POW2 == SPECIFIC_ALIGN) return self;
            if (self.not_null()) self.assert_aligned_pow_2(SPECIFIC_ALIGN, @src());
            return self.align_cast(PTR_DEF.with_align(SPECIFIC_ALIGN));
        }
        pub inline fn to_specific_align_any(self: Self, comptime any_alignment: anytype) PointerAdvanced(SOURCE, PTR_DEF.with_align(normalize_align(any_alignment))) {
            const NEW_ALIGN = comptime normalize_align(any_alignment);
            if (comptime NEW_ALIGN == null) return self.to_native_align();
            return self.to_specific_align(NEW_ALIGN.?);
        }
        pub inline fn to_native_align(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_align(null)) {
            if (comptime !HAS_SPECIFIC_ALIGN) return self;
            if (self.not_null()) self.assert_aligned(@alignOf(ELEMENT), @src());
            return self.align_cast(PTR_DEF.with_align(null));
        }

        pub inline fn is_aligned(self: Self, alignment: usize) bool {
            return std.mem.isAligned(self.addr(), alignment);
        }
        pub inline fn is_aligned_any(self: Self, alignment: usize) bool {
            return std.mem.isAlignedAnyAlign(self.addr(), alignment);
        }
        pub inline fn is_aligned_log_2(self: Self, alignment_log_2: u8) bool {
            return std.mem.isAlignedLog2(self.addr(), alignment_log_2);
        }
        pub inline fn is_aligned_pow_2(self: Self, alignment_pow_2: PowerOf2) bool {
            return std.mem.isAlignedLog2(self.addr(), alignment_pow_2.raw_int());
        }
        pub inline fn is_aligned_std_mem(self: Self, alignment: mem.Alignment) bool {
            return std.mem.isAlignedLog2(self.addr(), @intCast(@backingInt(alignment)));
        }

        pub inline fn assert_aligned(self: Self, alignment: usize, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_aligned(alignment), src, "pointer was not aligned to {d}", .{alignment});
        }
        pub inline fn assert_aligned_any(self: Self, alignment: usize, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_aligned_any(alignment), src, "pointer was not aligned to {d}", .{alignment});
        }
        pub inline fn assert_aligned_log_2(self: Self, alignment_log_2: u8, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_aligned_log_2(alignment_log_2), src, "pointer was not aligned to log2 {d} ({d})", .{ alignment_log_2, @as(usize, 1) << @intCast(alignment_log_2) });
        }
        pub inline fn assert_aligned_pow_2(self: Self, alignment_pow_2: PowerOf2, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_aligned_pow_2(alignment_pow_2), src, "pointer was not aligned to power-of-2 {s}", .{@tagName(alignment_pow_2)});
        }
        pub inline fn assert_aligned_std_mem(self: Self, alignment: mem.Alignment, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_aligned_std_mem(alignment), src, "pointer was not aligned to std.mem.Alignment `{s}`", .{@tagName(alignment)});
        }

        inline fn assert_index_not_negative(self: Self, idx_or_len: anytype, comptime src: ?SourceLocation) void {
            _ = self;
            assert_with_reason(idx_or_len >= 0, src, "index or len cannot be negative, got {d}", .{idx_or_len});
        }

        inline fn assert_granularity(byte_offset: usize, comptime src: ?SourceLocation) void {
            if (comptime GRANULARITY_NOT_1 and Assert.SHOULD_ASSERT) {
                assert_with_reason(byte_offset & GRANULARITY_FAIL_MASK == 0, src, "byte offset `{d}` is not a multiple of the minimum address granularity `{s}`", .{ byte_offset, @tagName(SOURCE.STATIC_RESOLVER.ADDRESS_GRANULARITY) });
            }
        }

        inline fn assert_contiguous(original_addr: InternalPtr, comptime DIR: OffsetDir, byte_offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                const prefix = switch (comptime DIR) {
                    .ADD => "incrementing",
                    .SUB => "decrementing",
                };
                // if granularity > 1, round the test offset down to the nearest multiple of granularity
                // within the range given for the test address.
                // This technically might leave a small gap of unchecked addresses, but it is better than
                // no check at all and doesn't violate the resolver expectations.
                const granular_byte_offset = if (comptime GRANULARITY_NOT_1) byte_offset & GRANULARITY_PASS_MASK else byte_offset;
                const test_new_internal = switch (comptime DIR) {
                    .ADD => static_ptr_incr(original_addr, granular_byte_offset),
                    .SUB => static_ptr_decr(original_addr, granular_byte_offset),
                };
                assert_with_reason(!static_ptr_is_null(test_new_internal), src, "local handle after " ++ prefix ++ " the pointer by {d} bytes became null, the resolver indicated the new address would escape its memory segment", .{granular_byte_offset});
                const real_original = static_resolve_addr(original_addr);
                const real_test = static_resolve_addr(test_new_internal);
                const expect_real_new = switch (comptime DIR) {
                    .ADD => real_original + (granular_byte_offset),
                    .SUB => real_original - (granular_byte_offset),
                };
                assert_with_reason(real_test == expect_real_new, src, prefix ++ " the pointer by {d} bytes caused the resolved address of the new address handle to not equal the expected address for a contiguous memory region: local address handle escaped its contiguous memory region", .{granular_byte_offset});
            }
        }
        //***********
        // GET / SET
        //***********
        pub inline fn get(self: Self) ELEMENT {
            return self.ptr_never_null().*;
        }
        pub inline fn get_or_null(self: Self) ?ELEMENT {
            if (self.is_null()) return null;
            return self.ptr_never_null().*;
        }
        pub inline fn get_orelse(self: Self, default: ELEMENT) ELEMENT {
            if (self.is_null()) return default;
            return self.ptr_never_null().*;
        }
        pub inline fn get_at_index(self: Self, index: anytype) ELEMENT {
            self.assert_index_not_negative(index, @src());
            const p = self.ptr_many_never_null();
            if (comptime ZERO_SIZE_ELEM) return p[0];
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            return p[idx];
        }
        pub inline fn get_at_index_or_null(self: Self, index: anytype) ?ELEMENT {
            self.assert_index_not_negative(index, @src());
            if (self.is_null()) return null;
            const p = self.ptr_many_never_null();
            if (comptime ZERO_SIZE_ELEM) return p[0];
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            return p[idx];
        }
        pub inline fn get_at_index_orelse(self: Self, index: anytype, default: ELEMENT) ELEMENT {
            self.assert_index_not_negative(index, @src());
            if (self.is_null()) return default;
            const p = self.ptr_many_never_null();
            if (comptime ZERO_SIZE_ELEM) return p[0];
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            return p[idx];
        }
        pub inline fn set(self: Self, val: ELEMENT) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            self.ptr_never_null().* = val;
        }
        pub inline fn set_if_not_null(self: Self, val: ELEMENT) void {
            assert_mutable(@src());
            if (self.is_null()) return;
            self.ptr_never_null().* = val;
        }
        pub inline fn set_if_not_null_return_ptr_is_NOT_null(self: Self, val: ELEMENT) bool {
            assert_mutable(@src());
            if (self.is_null()) return false;
            self.ptr_never_null().* = val;
            return true;
        }
        pub inline fn set_if_not_null_return_ptr_IS_null(self: Self, val: ELEMENT) bool {
            assert_mutable(@src());
            if (self.is_null()) return true;
            self.ptr_never_null().* = val;
            return false;
        }
        pub inline fn set_at_index(self: Self, index: anytype, val: ELEMENT) void {
            self.assert_index_not_negative(index, @src());
            assert_mutable(@src());
            self.assert_not_null(@src());
            if (comptime ZERO_SIZE_ELEM) return;
            const p = self.ptr_many_never_null();
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            p[idx] = val;
        }
        pub inline fn set_at_index_if_not_null(self: Self, index: anytype, val: ELEMENT) void {
            self.assert_index_not_negative(index, @src());
            assert_mutable(@src());
            if (comptime ZERO_SIZE_ELEM) return;
            if (self.is_null()) return;
            const p = self.ptr_many_never_null();
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            p[idx] = val;
        }
        pub inline fn set_at_index_if_not_null_return_ptr_is_NOT_null(self: Self, index: anytype, val: ELEMENT) bool {
            self.assert_index_not_negative(index, @src());
            assert_mutable(@src());
            if (comptime ZERO_SIZE_ELEM) return self.not_null();
            if (self.is_null()) return false;
            const p = self.ptr_many_never_null();
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            p[idx] = val;
            return true;
        }
        pub inline fn set_at_index_if_not_null_return_ptr_IS_null(self: Self, index: anytype, val: ELEMENT) bool {
            self.assert_index_not_negative(index, @src());
            assert_mutable(@src());
            if (comptime ZERO_SIZE_ELEM) return self.is_null();
            if (self.is_null()) return true;
            const p = self.ptr_many_never_null();
            const idx = num_cast(index, usize);
            assert_contiguous(self.internal, .ADD, ((idx + 1) * ELEMENT_SIZE) - 1, @src());
            p[idx] = val;
            return false;
        }
        //**************************
        // ADDRESS ADD / SUB / MOVE
        //**************************
        pub inline fn increment(self: Self, elem_offset: anytype) SelfIfMoved {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            switch (comptime SOURCE) {
                .NATIVE => if (comptime CAN_BE_NULL) {
                    return SelfIfMoved{ .internal = self.internal.? + num_cast(elem_offset, usize) };
                } else {
                    return SelfIfMoved{ .internal = self.internal + num_cast(elem_offset, usize) };
                },
                .STATIC_RESOLVER => {
                    const byte_offset = num_cast(elem_offset, usize) * ELEMENT_SIZE;
                    assert_granularity(byte_offset, @src());
                    return SelfIfMoved{ .internal = static_ptr_incr(self.internal, num_cast(elem_offset, usize) * ELEMENT_SIZE) };
                },
            }
        }
        pub inline fn increment_in_place(self: *Self, offset: anytype) void {
            assert_not_overaligned(@src());
            self.* = self.increment(offset);
        }

        pub inline fn increment_assert_contiguous(self: Self, elem_offset: anytype) SelfIfMoved {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            if (comptime !ZERO_SIZE_ELEM) {
                assert_contiguous(self.internal, .ADD, ((num_cast(elem_offset, usize) + 1) * ELEMENT_SIZE) - 1, @src());
            }
            return self.increment(elem_offset);
        }
        pub inline fn increment_in_place_assert_contiguous(self: *Self, elem_offset: anytype) void {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            if (comptime !ZERO_SIZE_ELEM) {
                assert_contiguous(self.internal, .ADD, ((num_cast(elem_offset, usize) + 1) * ELEMENT_SIZE) - 1, @src());
            }
            self.increment_in_place(elem_offset);
        }

        pub inline fn decrement(self: Self, elem_offset: anytype) SelfIfMoved {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            switch (comptime SOURCE) {
                .NATIVE => if (comptime CAN_BE_NULL) {
                    return SelfIfMoved{ .internal = self.internal.? - num_cast(elem_offset, usize) };
                } else {
                    return SelfIfMoved{ .internal = self.internal - num_cast(elem_offset, usize) };
                },
                .STATIC_RESOLVER => {
                    const byte_offset = num_cast(elem_offset, usize) * ELEMENT_SIZE;
                    assert_granularity(byte_offset, @src());
                    return SelfIfMoved{ .internal = static_ptr_decr(self.internal, num_cast(elem_offset, usize) * ELEMENT_SIZE) };
                },
            }
        }
        pub inline fn decrement_in_place(self: *Self, elem_offset: anytype) void {
            assert_not_overaligned(@src());
            self.* = self.decrement(elem_offset);
        }

        pub inline fn decrement_assert_contiguous(self: Self, elem_offset: anytype) SelfIfMoved {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            if (comptime !ZERO_SIZE_ELEM) {
                assert_contiguous(self.internal, .SUB, num_cast(elem_offset, usize) * ELEMENT_SIZE, @src());
            }
            return self.decrement(elem_offset);
        }
        pub inline fn decrement_in_place_assert_contiguous(self: *Self, elem_offset: anytype) void {
            self.assert_index_not_negative(elem_offset, @src());
            self.assert_not_null(@src());
            if (comptime !ZERO_SIZE_ELEM) {
                assert_contiguous(self.internal, .SUB, num_cast(elem_offset, usize) * ELEMENT_SIZE, @src());
            }
            self.decrement_in_place(elem_offset);
        }
        pub inline fn move(self: Self, elem_offset: anytype) SelfIfMoved {
            if (elem_offset < 0) {
                return self.decrement(@abs(elem_offset));
            } else {
                return self.increment(elem_offset);
            }
        }
        pub inline fn move_in_place(self: *Self, elem_offset: anytype) void {
            assert_not_overaligned(@src());
            self.* = self.move(elem_offset);
        }

        pub inline fn move_assert_contiguous(self: Self, elem_offset: anytype) SelfIfMoved {
            if (elem_offset < 0) {
                return self.decrement_assert_contiguous(@abs(elem_offset));
            } else {
                return self.increment_assert_contiguous(elem_offset);
            }
        }
        pub inline fn move_in_place_assert_contiguous(self: *Self, elem_offset: anytype) void {
            assert_not_overaligned(@src());
            self.* = self.move_assert_contiguous(elem_offset);
        }
        //**************************
        // ELEMENTS BETWEEN
        //**************************
        pub inline fn elements_between_self_low_other_high_exclude(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            assert_not_zero_size_type(@src());
            const low_addr = self.addr();
            const high_addr = other.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_low_other_high_exclude_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const low_addr = self.addr();
            const high_addr = other.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_low_other_high_exclude_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = self.addr();
            const high_addr = other.addr();
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_high_other_low_exclude(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = other.addr();
            const high_addr = self.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a higher address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_high_other_low_exclude_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const low_addr = other.addr();
            const high_addr = self.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a higher address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_high_other_low_exclude_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = other.addr();
            const high_addr = self.addr();
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_self_low_other_high_include(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = self.addr();
            const high_addr = other.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_self_low_other_high_include_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const low_addr = self.addr();
            const high_addr = other.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_self_low_other_high_include_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = self.addr();
            const high_addr = other.addr();
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_self_high_other_low_include(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = other.addr();
            const high_addr = self.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a higher address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_self_high_other_low_include_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const low_addr = other.addr();
            const high_addr = self.addr();
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a higher address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_self_high_other_low_include_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = other.addr();
            const high_addr = self.addr();
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_exclude_high(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_exclude_high_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_exclude_high_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn elements_between_include_high(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_include_high_or_null(self: Self, other: Self) ?usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return null;
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn elements_between_include_high_orelse_0(self: Self, other: Self) usize {
            assert_not_zero_size_type(@src());
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = self.addr();
            const other_addr = other.addr();
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(ELEMENT_SIZE))) + 1;
        }
        pub inline fn is_within_range_exclude_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = self.addr();
            const low_addr = low.addr();
            const high_addr = high.addr();
            return low_addr <= self_addr and self_addr < high_addr;
        }
        pub inline fn is_within_range_include_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = self.addr();
            const low_addr = low.addr();
            const high_addr = high.addr();
            return low_addr <= self_addr and self_addr <= high_addr;
        }
        pub inline fn assert_is_within_range_exclude_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_within_range_exclude_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }
        pub inline fn assert_is_within_range_include_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_within_range_include_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }

        //**************************
        // COMPARISON / HASHING
        //**************************
        pub inline fn eql(self: Self, other: Self) bool {
            if (self.is_null() or other.is_null()) return self.is_null() and other.is_null();
            if (comptime Types.type_is_equatable(InternalPtr)) return self.internal == other.internal;
            return self.addr() == other.addr();
        }
        pub inline fn order(self: Self, other: Self) std.math.Order {
            const self_addr: usize = self.addr_orelse_0();
            const other_addr: usize = other.addr_orelse_0();
            return std.math.order(self_addr, other_addr);
        }
        pub inline fn eql_native_address(self: Self, native_ptr: anytype) bool {
            switch (comptime @typeInfo(@TypeOf(native_ptr))) {
                .optional => |O| {
                    if (native_ptr) |p| {
                        const CHILD_INFO = @typeInfo(O.child);
                        switch (comptime CHILD_INFO) {
                            .pointer => |P| {
                                if (comptime P.size == .slice) {
                                    return self.not_null() and self.addr() == @intFromPtr(p.ptr);
                                } else {
                                    return self.not_null() and self.addr() == @intFromPtr(p);
                                }
                            },
                            else => assert_unreachable(@src(), "eql_native requires a pointer or optional pointer", .{}),
                        }
                    }
                    return self.is_null();
                },
                .pointer => |P| {
                    if (comptime P.size == .c) if (@intFromPtr(native_ptr) == 0) return self.is_null();
                    if (comptime P.size == .slice) {
                        return self.not_null() and self.addr() == @intFromPtr(native_ptr.ptr);
                    } else {
                        return self.not_null() and self.addr() == @intFromPtr(native_ptr);
                    }
                },
                .null => {
                    return self.is_null();
                },
                else => {},
            }
            assert_unreachable(@src(), "eql_native requires a pointer or optional pointer", .{});
            return false;
        }
        pub inline fn hash(self: Self) u64 {
            const addr_: usize = self.addr_orelse_0();
            return std.hash.Wyhash.hash(0, std.mem.asBytes(&addr_));
        }
        pub inline fn simple_hash(self: Self) u64 {
            const addr_: usize = self.addr_orelse_0();
            const addr_u64: u64 = @intCast(addr_);
            if (comptime @sizeOf(usize) == 4) {
                return addr_u64 | (addr_u64 << 32);
            }
            return addr_u64;
        }

        //**************************
        // SIGNED DISTANCE
        //**************************
        pub inline fn bytes_from(self: Self, other: Self) isize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = self.addr();
            const other_addr = other.addr();
            return if (self_addr >= other_addr)
                @as(isize, @intCast(self_addr - other_addr))
            else
                -@as(isize, @intCast(other_addr - self_addr));
        }
        pub inline fn elements_from(self: Self, other: Self) isize {
            assert_not_zero_size_type(@src());
            return @divExact(self.bytes_from(other), @as(isize, @intCast(ELEMENT_SIZE)));
        }
        pub inline fn offset_from(self: Self, other: Self) isize {
            return self.bytes_from(other);
        }
        pub inline fn bytes_from_or_null(self: Self, other: Self) ?isize {
            if (self.is_null() or other.is_null()) return null;
            return self.bytes_from(other);
        }
        pub inline fn bytes_from_orelse_0(self: Self, other: Self) isize {
            return self.bytes_from_or_null(other) orelse 0;
        }
        pub inline fn elements_from_or_null(self: Self, other: Self) ?isize {
            if (self.is_null() or other.is_null()) return null;
            return self.elements_from(other);
        }
        pub inline fn elements_from_orelse_0(self: Self, other: Self) isize {
            return self.elements_from_or_null(other) orelse 0;
        }
        pub inline fn offset_from_or_null(self: Self, other: Self) ?isize {
            return self.bytes_from_or_null(other);
        }
        pub inline fn offset_from_orelse_0(self: Self, other: Self) isize {
            return self.bytes_from_orelse_0(other);
        }

        //**************************
        // NULL-PRESERVING ARITHMETIC
        //**************************
        pub inline fn increment_if_not_null(self: Self, offset: anytype) SelfIfMoved {
            if (self.is_null()) return SelfIfMoved{ .internal = self.internal };
            return self.increment(offset);
        }
        pub inline fn decrement_if_not_null(self: Self, offset: anytype) SelfIfMoved {
            if (self.is_null()) return SelfIfMoved{ .internal = self.internal };
            return self.decrement(offset);
        }
        pub inline fn move_if_not_null(self: Self, offset: anytype) SelfIfMoved {
            if (self.is_null()) return SelfIfMoved{ .internal = self.internal };
            return self.move(offset);
        }

        //**************************
        // NULL CONSTRUCTION / MUTATION
        //**************************
        pub inline fn new_null() PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)) {
            return .{};
        }
        pub inline fn set_null(self: *Self) void {
            assert_with_reason(CAN_BE_NULL, @src(), "set_null requires a nullable pointer type", .{});
            self.internal = INTERNAL_PTR_DEFAULT;
        }

        //**************************
        // MEM COPY/SET OPERATIONS
        //**************************
        pub inline fn memcopy_to(self: Self, dst: []ELEMENT) void {
            @memcpy(dst, self.slice_never_null(dst.len));
        }
        pub inline fn memcopy_from(self: Self, src: []const ELEMENT) void {
            assert_mutable(@src());
            @memcpy(self.slice_never_null(src.len), src);
        }
        pub inline fn memmove_to(self: Self, dst: []ELEMENT) void {
            const src = self.slice_never_null(dst.len);
            @memmove(dst, src);
        }
        pub inline fn memmove_from(self: Self, src: []const ELEMENT) void {
            assert_mutable(@src());
            const dst = self.slice_never_null(src.len);
            @memmove(dst, src);
        }
        pub inline fn memset(self: Self, value: ELEMENT, len: usize) void {
            assert_mutable(@src());
            @memset(self.slice_never_null(len), value);
        }

        //**************************
        // ATOMIC ACCESS
        //**************************
        pub inline fn atomic_load(self: Self, comptime ordering: std.lang.AtomicOrder) ELEMENT {
            self.assert_not_null(@src());
            return @atomicLoad(ELEMENT, self.ptr_never_null(), ordering);
        }
        pub inline fn atomic_store(self: Self, value: ELEMENT, comptime ordering: std.lang.AtomicOrder) void {
            assert_mutable(@src());
            self.assert_not_null(@src());
            @atomicStore(ELEMENT, self.ptr_never_null(), value, ordering);
        }
        /// Atomically loads the previous value, modifies it with the specified operation and value, and sets the new modified value.
        ///
        /// The return value from this function is the previous value before it was modified.
        pub inline fn atomic_read_modify_write(self: Self, comptime op: std.lang.AtomicRmwOp, value: ELEMENT, comptime ordering: std.lang.AtomicOrder) ELEMENT {
            assert_mutable(@src());
            self.assert_not_null(@src());
            return @atomicRmw(ELEMENT, self.ptr_never_null(), op, value, ordering);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_strong(self: Self, expected: ELEMENT, new_value_on_success: ELEMENT, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?ELEMENT {
            assert_mutable(@src());
            self.assert_not_null(@src());
            return @cmpxchgStrong(ELEMENT, self.ptr_never_null(), expected, new_value_on_success, success_order, fail_order);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_weak(self: Self, expected: ELEMENT, new_value_on_success: ELEMENT, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?ELEMENT {
            assert_mutable(@src());
            self.assert_not_null(@src());
            return @cmpxchgWeak(ELEMENT, self.ptr_never_null(), expected, new_value_on_success, success_order, fail_order);
        }

        //**************************
        // ANYOPAQUE CONVERSION
        //**************************
        pub inline fn to_anyopaque(self: Self) if (IS_CONST) *const anyopaque else *anyopaque {
            self.assert_not_null(@src());
            assert_not_volatile(@src());
            assert_normal_addrspace(@src());
            return @ptrCast(self.ptr_never_null());
        }
        pub inline fn to_const_anyopaque(self: Self) *const anyopaque {
            self.assert_not_null(@src());
            assert_not_volatile(@src());
            assert_normal_addrspace(@src());
            return @ptrCast(self.ptr_never_null());
        }
        pub inline fn to_anyopaque_or_null(self: Self) if (IS_CONST) ?*const anyopaque else ?*anyopaque {
            if (self.is_null()) return null;
            assert_not_volatile(@src());
            assert_normal_addrspace(@src());
            return @ptrCast(self.ptr_never_null());
        }
        pub inline fn to_const_anyopaque_or_null(self: Self) ?*const anyopaque {
            if (self.is_null()) return null;
            assert_not_volatile(@src());
            assert_normal_addrspace(@src());
            return @ptrCast(self.ptr_never_null());
        }
    };
}

pub fn Pointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T });
}
pub fn PointerAlign(comptime T: type, comptime A: anytype, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .ALIGNMENT = normalize_align(A) });
}
pub fn NullablePointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .NULLABILITY = .NULLABLE });
}
pub fn NullablePointerAlign(comptime T: type, comptime A: anytype, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .NULLABILITY = .NULLABLE, .ALIGNMENT = normalize_align(A) });
}
pub fn ConstPointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST });
}
pub fn ConstPointerAlign(comptime T: type, comptime A: anytype, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .ALIGNMENT = normalize_align(A) });
}
pub fn NullableConstPointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .NULLABILITY = .NULLABLE });
}
pub fn NullableConstPointerAlign(comptime T: type, comptime A: anytype, comptime SOURCE: PointerSource) type {
    return PointerAdvanced(SOURCE, .{ .ELEMENT = T, .MUTABILITY = .CONST, .NULLABILITY = .NULLABLE, .ALIGNMENT = normalize_align(A) });
}
