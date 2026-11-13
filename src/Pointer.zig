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

const OffestDir = enum {
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

pub const StaticPointerResolver = struct {
    /// The local type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE: type,
    /// The unsigned integer type to use for slice length,
    /// if a slice type is requested. This puts a hard limit on
    /// the largest slice size possible. A reasonable upper bound
    /// is `@Int(.unsigned, @bitSizeOf(LOCAL_TYPE))`, since
    /// that is the maximum number of unique addresses possible
    /// for LOCAL_TYPE to resolve to, though the actual smallest
    /// slice may be smaller.
    LOCAL_SLICE_INT: type,
    /// MUST be a pointer to a value of type `LOCAL_TYPE_NULLABLE` that represents the 'null' value
    /// for the input type
    LOCAL_NULL_VALUE: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE_NULLABLE) bool`
    IS_NULL_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) ?[*]u8`
    RESOLVE_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (original: LOCAL_TYPE, offset: usize) LOCAL_TYPE`,
    /// where the returned `LOCAL_TYPE` is the value that, when resolved, returns
    /// the exact same address as if the user had resolved the original address and added
    /// the usize offset to it:
    ///
    /// `RESOLVE(ORIGINAL) + OFFSET == RESOLVE(ADD(ORIGINAL, OFFSET))`
    ADD_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (original: LOCAL_TYPE, offset: usize) LOCAL_TYPE`,
    /// where the returned `LOCAL_TYPE` is the value that, when resolved, returns
    /// the exact same address as if the user had resolved the original address and subtracted
    /// the usize offset to it:
    ///
    /// `RESOLVE(ORIGINAL) - OFFSET == RESOLVE(SUBTRACT(ORIGINAL, OFFSET))`
    SUBTRACT_FUNC: *const anyopaque,
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
};

pub const AutoIntegerStaticPointerResolver = struct {
    /// The local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE: type,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) ?[*]u8`
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

    pub fn to_global_resolver(comptime self: AutoIntegerStaticPointerResolver) StaticPointerResolver {
        const PROTO = IntegerResolverProto(self.LOCAL_TYPE);
        return StaticPointerResolver{
            .ADD_FUNC = @ptrCast(&PROTO.add),
            .SUBTRACT_FUNC = @ptrCast(&PROTO.sub),
            .IS_NULL_FUNC = @ptrCast(&PROTO.is_null),
            .LOCAL_NULL_VALUE = @ptrCast(&PROTO.NULL_VAL),
            .LOCAL_TYPE = self.LOCAL_TYPE,
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
        };
    }
};
pub const AutoIntegerBitsStaticPointerResolver = struct {
    /// The number of bits for the local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE_NUMBER_OF_BITS: u16,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) ?[*]u8`
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

    pub fn to_auto_int(comptime self: AutoIntegerBitsStaticPointerResolver) AutoIntegerStaticPointerResolver {
        return AutoIntegerStaticPointerResolver{
            .LOCAL_TYPE = @Int(.unsigned, self.LOCAL_TYPE_NUMBER_OF_BITS),
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
        };
    }
};
pub const AutoIntegerMaxStaticPointerResolver = struct {
    /// The maximum value for the local integer type stored on the `Pointer/Pointer(ELEMENT)` struct
    LOCAL_TYPE_VALUE_LIMIT: PowerOf2,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) ?[*]u8`
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

    pub fn to_auto_int(comptime self: AutoIntegerMaxStaticPointerResolver) AutoIntegerStaticPointerResolver {
        return AutoIntegerStaticPointerResolver{
            .LOCAL_TYPE = self.LOCAL_TYPE_VALUE_LIMIT.unsigned_integer_type_that_holds_all_values_less_than(),
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
        };
    }
};

fn IntegerResolverProto(comptime INT: type) type {
    return struct {
        pub const NULL_VAL: INT = math.maxInt(INT);
        pub fn is_null(val: INT) bool {
            return val == NULL_VAL;
        }
        pub fn add(val: INT, offset: usize) INT {
            return val + @as(INT, @intCast(offset));
        }
        pub fn sub(val: INT, offset: usize) INT {
            return val - @as(INT, @intCast(offset));
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
            .SENTINEL = self.SENTINEL,
            .ALIGNMENT = self.ALIGNMENT,
            .ADDRSPACE = self.ADDRSPACE,
            .VOLATILE = self.VOLATILE,
        };
    }
    pub fn with_sentinel(comptime self: MakePtrDef, comptime SENTINEL: self.ELEMENT) MakePtrDef {
        return MakePtrDef{
            .ALLOW_ZERO = self.ALLOW_ZERO,
            .NULLABILITY = self.NULLABILITY,
            .MUTABILITY = self.MUTABILITY,
            .SIZE = self.SIZE,
            .ELEMENT = self.ELEMENT,
            .SENTINEL = SENTINEL,
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
};

pub fn MakePtrFromDef(comptime DEF: MakePtrDef) type {
    return MakePtr(DEF.ALLOW_ZERO, DEF.NULLABILITY, DEF.MUTABILITY, DEF.SIZE, DEF.ELEMENT, if (DEF.SENTINEL) |SENT| @as(*const DEF.ELEMENT, @ptrCast(@alignCast(SENT))).* else null, DEF.ALIGNMENT, DEF.ADDRSPACE, DEF.VOLATILE);
}

pub fn MakePtr(comptime ALLOW_ZERO: AllowZero, comptime NULLABILITY: Nullability, comptime MUTABILITY: Mutability, comptime SIZE: std.lang.Type.Pointer.Size, comptime ELEMENT: type, comptime SENTINEL: ?ELEMENT, comptime ALIGNMENT: ?PowerOf2, comptime ADDRSPACE: ?AddrSpace, comptime VOLATILE: Volatile) type {
    const P = @Pointer(SIZE, .{
        .@"allowzero" = ALLOW_ZERO == .ALLOW_ZERO,
        .@"addrspace" = ADDRSPACE,
        .@"align" = if (ALIGNMENT) |A| A.value_as_type(usize),
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
    pub fn InternalPtr(comptime self: PointerSource, comptime PTR_DEF: MakePtrDef) type {
        switch (comptime self) {
            .NATIVE => MakePtrFromDef(PTR_DEF),
            .STATIC_RESOLVER => |RES| RES.LOCAL_TYPE,
        }
    }
    pub fn InternalPtrDefault(comptime self: PointerSource, comptime PTR_DEF: MakePtrDef) self.InternalPtr(PTR_DEF) {
        switch (comptime self) {
            .NATIVE => PtrDefaultFromDef(PTR_DEF),
            .STATIC_RESOLVER => |RES| RES.LOCAL_NULL_VALUE,
        }
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
    pub fn ResolverFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE) ?[*]u8,
        };
    }
    pub fn ResolverFnInit(comptime self: PointerSource) self.ResolverFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE) ?[*]u8, @ptrCast(@alignCast(RES.RESOLVE_FUNC))),
        };
    }
    pub fn AdderFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn AdderFnInit(comptime self: PointerSource) self.AdderFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.ADD_FUNC))),
        };
    }
    pub fn SubtracterFn(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .STATIC_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn SubtracterFnInit(comptime self: PointerSource) self.SubtracterFn() {
        return switch (comptime self) {
            .NATIVE => {},
            .STATIC_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.SUBTRACT_FUNC))),
        };
    }
};

const InternalManyU8NullDef = MakePtrDef{
    .ELEMENT = u8,
    .NULLABILITY = .NULLABLE,
    .SIZE = .many,
};
const InternalManyU8Null = PointerSource.native_pointer().InternalPtr(InternalManyU8NullDef);
const AdapterManyU8NUll = PointerAdvanced(PointerSource.native_pointer(), InternalManyU8NullDef);

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
pub fn PointerAdvanced(comptime SOURCE_: PointerSource, comptime PTR_DEF_: MakePtrDef) type {
    assert_with_reason(PTR_DEF_.SIZE != .slice, @src(), "slice pointer types are not directly supported. Use a many-item ptr instead", .{});
    return struct {
        const Self = @This();
        pub const InternalPtr = SOURCE.InternalPtr(PTR_DEF);
        
        pub const ExternalPtr = MakePtrFromDef(PTR_DEF);
        pub const ExternalPtrNeverNull = MakePtrFromDef(PTR_DEF.with_nullability(.NEVER_NULL));
        pub const INTERNAL_PTR_DEFAULT: InternalPtr = SOURCE.InternalPtrDefault(PTR_DEF);
        pub const PTR_DEF = PTR_DEF_;
        pub const SOURCE = SOURCE_;

        const g_resolve_ptr: SOURCE.ResolverFn() = SOURCE.ResolverFnInit();
        const g_ptr_add: SOURCE.AdderFn() = SOURCE.AdderFnInit();
        const g_ptr_sub: SOURCE.SubtracterFn() = SOURCE.SubtracterFnInit();
        const g_ptr_is_null: SOURCE.NullCheckFn() = SOURCE.NullCheckFnInit();
        pub const USE_STATIC_RESOLVER = SOURCE == .STATIC_RESOLVER;
        pub const IS_NATIVE = SOURCE == .NATIVE;
        pub const HAS_LEN = PTR_DEF.SIZE == .slice;
        pub const SIZE_KIND = PTR_DEF.SIZE;
        pub const ELEMENT = PTR_DEF.ELEMENT;
        pub const ELEMENT_SIZE = @sizeOf(PTR_DEF.ELEMENT);
        pub const IS_ALLOW_ZERO = PTR_DEF.ALLOW_ZERO == .ALLOW_ZERO;
        pub const IS_VOLATILE = PTR_DEF.VOLATILE == .VOLATILE;
        pub const USE_NATIVE_ALIGN = PTR_DEF.ALIGNMENT == null;
        pub const HAS_SPECIFIC_ALIGN = PTR_DEF.ALIGNMENT != null;
        pub const ALIGN: usize = if (PTR_DEF.ALIGNMENT) |A| A.value_as_type(usize) else @alignOf(ELEMENT);
        pub const ADDRSPCACE = PTR_DEF.ADDRSPACE;
        pub const IS_CONST = PTR_DEF.MUTABILITY == .CONST;
        pub const IS_MUTABLE = PTR_DEF.MUTABILITY == .MUTABLE;
        pub const CAN_BE_NULL = PTR_DEF.NULLABILITY == .NULLABLE;
        const ASSERT_CONTIG = if (USE_STATIC_RESOLVER) SOURCE.STATIC_RESOLVER.ASSERT_CONTIGUOUS_RANGE else false;

        internal: InternalPtr = INTERNAL_PTR_DEFAULT,

        pub inline fn new(internal_val: InternalPtr) Self {
            return Self{ .internal = internal_val };
        }
        pub inline fn new_from_any(any_ptr: anytype) Self {
            if (comptime @TypeOf(any_ptr) == InternalPtr) return new(any_ptr);
            assert_native(@src());
            return Self{ .internal = @ptrCast(@alignCast(any_ptr)) };
        }

        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            assert_with_reason(IS_NATIVE, src, "cannot be called when mode is not .NATIVE", .{});
        }

        pub inline fn ptr(self: Self) ExternalPtr {
            return switch (comptime SOURCE) {
                .NATIVE => self.internal,
                .STATIC_RESOLVER => (AdapterManyU8NUll{.internal = g_resolve_ptr(self.internal)}).complete_cast_to(PTR_DEF).ptr(),
            };
        }
        pub inline fn ptr_never_null(self: Self) ExternalPtrNeverNull {
            return switch (comptime SOURCE) {
                .NATIVE => if (comptime CAN_BE_NULL) self.internal.? else self.internal,
                .STATIC_RESOLVER => (AdapterManyU8NUll{.internal = g_resolve_ptr(self.internal)}).complete_cast_to(PTR_DEF.with_nullability(.NEVER_NULL)).ptr(),
            };
        }
        pub inline fn addr(self: Self) usize {
            return @intFromPtr(self.ptr());
        }

        pub inline fn is_null(self: Self) bool {
            if (comptime !CAN_BE_NULL) return false;
            return switch (comptime SOURCE) {
                .NATIVE => self.internal == null,
                .STATIC_RESOLVER => g_ptr_is_null(self.internal),
            };
        }
        pub inline fn not_null(self: Self) bool {
            if (comptime !CAN_BE_NULL) return true;
            return switch (comptime SOURCE) {
                .NATIVE => self.internal != null,
                .STATIC_RESOLVER => !g_ptr_is_null(self.internal),
            };
        }
        pub inline fn assert_not_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.not_null(), src, "pointer was null", .{});
        }
        pub inline fn assert_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_null(), src, "pointer was not null", .{});
        }

        pub inline fn complete_cast_to(self: Self, comptime NEW_DEF: MakePtrDef) PointerAdvanced(SOURCE, NEW_DEF) {
            switch (comptime SOURCE) {
                .NATIVE => {
                    const p1 = if (comptime NEW_DEF.VOLATILE == .NOT_VOLATILE and PTR_DEF.VOLATILE == .VOLATILE) self.remove_volatile() else self;
                    const p2 = if (comptime NEW_DEF.MUTABILITY == .MUTABLE and PTR_DEF.MUTABILITY == .CONST) p1.to_mutable() else p1;
                    const p3 = if (comptime !std.meta.eql(NEW_DEF.ADDRSPACE, PTR_DEF.ADDRSPACE)) if (comptime PTR_DEF.ADDRSPACE == null) p2.to_specific_addrspace(NEW_DEF.ADDRSPACE.?) else p2.to_normal_addrspace() else p2;
                    const p4 = if (comptime NEW_DEF.ELEMENT != PTR_DEF.ELEMENT or !std.meta.eql(NEW_DEF.ALIGNMENT, PTR_DEF.ALIGNMENT)) if (comptime NEW_DEF.ALIGNMENT != null) p3.cast_to_element_aligned(NEW_DEF.ELEMENT, NEW_DEF.ALIGNMENT.?) else p3.cast_to_element(NEW_DEF.ELEMENT) else p3;
                    return PointerAdvanced(SOURCE, NEW_DEF){ .internal = @ptrCast(@alignCast(p4.internal)) };
                },
                .STATIC_RESOLVER => return PointerAdvanced(SOURCE, NEW_DEF){ .internal = self.internal },
            }
        }
        pub inline fn blind_cast_to(self: Self, comptime NEW_DEF: MakePtrDef) PointerAdvanced(SOURCE, NEW_DEF) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)){ .internal = @ptrFromInt(@intFromPtr(self.internal)) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)){ .internal = self.internal },
            };
        }
        pub inline fn to_const(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.CONST)){ .internal = self.internal },
            };
        }
        pub inline fn to_mutable(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.MUTABLE)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.MUTABLE)){ .internal = @constCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_mutability(.MUTABLE)){ .internal = self.internal },
            };
        }
        pub inline fn to_nullable(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)){ .internal = self.internal },
            };
        }
        pub inline fn to_non_null(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NEVER_NULL)) {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NEVER_NULL)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NEVER_NULL)){ .internal = self.internal },
            };
        }
        pub inline fn to_allowzero(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.ALLOW_ZERO)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.ALLOW_ZERO)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.ALLOW_ZERO)){ .internal = self.internal },
            };
        }
        pub inline fn remove_allowzero(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.NO_ALLOW_ZERO)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.NO_ALLOW_ZERO)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_allow_zero(.NO_ALLOW_ZERO)){ .internal = self.internal },
            };
        }
        pub inline fn to_volaitle(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.VOLATILE)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.VOLATILE)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.VOLATILE)){ .internal = self.internal },
            };
        }
        pub inline fn remove_volatile(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.NOT_VOLATILE)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.NOT_VOLATILE)){ .internal = @volatileCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_volatile(.NOT_VOLATILE)){ .internal = self.internal },
            };
        }
        pub inline fn to_one(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.one)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.one)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.one)){ .internal = self.internal },
            };
        }
        pub inline fn to_many(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.many)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.many)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.many)){ .internal = self.internal },
            };
        }
        pub inline fn to_c(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.c)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.c)){ .internal = @ptrCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_size_kind(.c)){ .internal = self.internal },
            };
        }
        pub inline fn to_specific_addrspace(self: Self, comptime addr_space: AddrSpace) PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(addr_space)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(addr_space)){ .internal = @addrSpaceCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(addr_space)){ .internal = self.internal },
            };
        }
        pub inline fn to_normal_addrspace(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(null)) {
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(null)){ .internal = @addrSpaceCast(self.internal) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_addrspace(null)){ .internal = self.internal },
            };
        }
        pub inline fn cast_to_element(self: Self, comptime NEW_ELEM: type) PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM)) {
            self.assert_aligned(@alignOf(NEW_ELEM), @src());
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM)){ .internal = @ptrCast(@alignCast(self.internal)) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM)){ .internal = self.internal },
            };
        }
        pub inline fn cast_to_element_aligned(self: Self, comptime NEW_ELEM: type, comptime SPECIFIC_ALIGN: PowerOf2) PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN)) {
            self.assert_aligned_pow_2(SPECIFIC_ALIGN, @src());
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN)){ .internal = @ptrCast(@alignCast(self.internal)) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_element(NEW_ELEM).with_align(SPECIFIC_ALIGN)){ .internal = self.internal },
            };
        }
        pub inline fn to_specific_align(self: Self, comptime SPECIFIC_ALIGN: PowerOf2) PointerAdvanced(SOURCE, PTR_DEF.with_align(SPECIFIC_ALIGN)) {
            self.assert_aligned_pow_2(SPECIFIC_ALIGN, @src());
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_align(SPECIFIC_ALIGN)){ .internal = @ptrCast(@alignCast(self.internal)) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_align(SPECIFIC_ALIGN)){ .internal = self.internal },
            };
        }
        pub inline fn to_native_align(self: Self) PointerAdvanced(SOURCE, PTR_DEF.with_align(null)) {
            self.assert_aligned(@alignOf(ELEMENT), @src());
            return switch (comptime SOURCE) {
                .NATIVE => PointerAdvanced(SOURCE, PTR_DEF.with_align(null)){ .internal = @ptrCast(@alignCast(self.internal)) },
                .STATIC_RESOLVER => PointerAdvanced(SOURCE, PTR_DEF.with_align(null)){ .internal = self.internal },
            };
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

        inline fn assert_contiguous_known_new(original_addr: InternalPtr, new_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous_known_new(original_addr: InternalPtr, new_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_STATIC_RESOLVER) {
                const real_original = g_resolve_ptr(original_addr) orelse return;
                const real_new = g_resolve_ptr(new_addr) orelse return;
                const expect_real_new = switch (comptime DIR) {
                    .ADD => real_original + offset * ELEMENT_SIZE,
                    .SUB => real_original - offset * ELEMENT_SIZE,
                };
                assert_with_reason(real_new == expect_real_new, src, "adding {d} to the pointer caused the resolved address of the new address handle to not equal the expected address for a contiguous memory region: local address handle escaped its contiguous memory region", .{offset});
            }
        }
        inline fn assert_contiguous(original_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                const new_addr = switch (comptime DIR) {
                    .ADD => g_ptr_add(original_addr, offset * ELEMENT_SIZE),
                    .SUB => g_ptr_sub(original_addr, offset * ELEMENT_SIZE),
                };
                assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous(original_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_STATIC_RESOLVER) {
                const new_addr = switch (comptime DIR) {
                    .ADD => g_ptr_add(original_addr, offset * ELEMENT_SIZE),
                    .SUB => g_ptr_sub(original_addr, offset * ELEMENT_SIZE),
                };
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn assert_contiguous_ignore_null(original_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                if (g_ptr_is_null(original_addr)) return;
                const new_addr = switch (comptime DIR) {
                    .ADD => g_ptr_add(original_addr, offset * ELEMENT_SIZE),
                    .SUB => g_ptr_sub(original_addr, offset * ELEMENT_SIZE),
                };
                assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous_ignore_null(original_addr: InternalPtr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_STATIC_RESOLVER) {
                if (g_ptr_is_null(original_addr)) return;
                const new_addr = switch (comptime DIR) {
                    .ADD => g_ptr_add(original_addr, offset * ELEMENT_SIZE),
                    .SUB => g_ptr_sub(original_addr, offset * ELEMENT_SIZE),
                };
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        //***********
        // GET / SET
        //***********
        pub inline fn get(self: Self) ELEMENT {
            return self.ptr(ELEMENT).*;
        }
        pub inline fn get_or_null(self: Self) ?ELEMENT {
            if (self.is_null()) return null;
            return self.ptr().?
        }
        pub inline fn get_orelse(self: Self, default: ELEMENT) ELEMENT {
            if (self.ptr_or_null(ELEMENT)) |p| {
                return p.*;
            }
            return default;
        }
        pub inline fn get_at_index(self: Self, index: usize) ELEMENT {
            self.assert_not_null(@src());
            assert_contiguous(self.internal, .ADD, index, @src());
            return self.ptr_many(ELEMENT)[index];
        }
        pub inline fn get_at_index_or_null(self: Self, index: usize) ?ELEMENT {
            assert_contiguous_ignore_null(self.internal, .ADD, index, @src());
            if (self.ptr_many_or_null(ELEMENT)) |p| {
                return p[index];
            }
            return null;
        }
        pub inline fn get_at_index_orelse(self: Self, index: usize, default: ELEMENT) ELEMENT {
            assert_contiguous_ignore_null(self.internal, .ADD, index, @src());
            if (self.ptr_many_or_null(ELEMENT)) |p| {
                return p[index];
            }
            return default;
        }
        pub inline fn set(self: Self, val: ELEMENT) void {
            self.ptr(ELEMENT).* = val;
        }
        pub inline fn set_if_not_null(self: Self, val: ELEMENT) void {
            if (self.ptr_or_null(ELEMENT)) |p| {
                p.* = val;
            }
        }
        pub inline fn set_if_not_null_return_ptr_is_NOT_null(self: Self, val: ELEMENT) bool {
            if (self.ptr_or_null(ELEMENT)) |p| {
                p.* = val;
                return true;
            }
            return false;
        }
        pub inline fn set_if_not_null_return_ptr_IS_null(self: Self, val: ELEMENT) bool {
            if (self.ptr_or_null(ELEMENT)) |p| {
                p.* = val;
                return false;
            }
            return true;
        }
        pub inline fn set_at_index(self: Self, index: usize, val: ELEMENT) void {
            self.assert_not_null(@src());
            assert_contiguous(self.internal, .ADD, index, @src());
            self.to_many().ptr()[index] = val;
        }
        pub inline fn set_at_index_if_not_null(self: Self, index: usize, val: ELEMENT) void {
            assert_contiguous_ignore_null(self.internal, .ADD, index, @src());
            if (self.not_null()) {
                self.to_many().ptr()[index] = val;
            }
        }
        pub inline fn set_at_index_if_not_null_return_ptr_is_NOT_null(self: Self, index: usize, val: ELEMENT) bool {
            assert_contiguous_ignore_null(self.internal, .ADD, index, @src());
            if (self.not_null()) {
                self.to_many().ptr()[index] = val;
                return true;
            }
            return false;
        }
        pub inline fn set_at_index_if_not_null_return_ptr_IS_null(self: Self, index: usize, val: ELEMENT) bool {
            assert_contiguous_ignore_null(self.internal, .ADD, index, @src());
            if (self.not_null()) {
                self.to_many().ptr()[index] = val;
                return false;
            }
            return true;
        }
        //**************************
        // ADDRESS ADD / SUB / MOVE
        //**************************
        pub inline fn increment(self: Self, offset: usize) Self {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => Self{ .internal = @ptrFromInt(@intFromPtr(self.internal) + (offset * @sizeOf(ELEMENT))) },
                .STATIC_RESOLVER => Self{ .internal = g_ptr_add(self.internal, offset * @sizeOf(ELEMENT)) },
            };
        }
        pub inline fn increment_in_place(self: *Self, offset: usize) void {
            self.* = self.increment(offset);
        }

        pub inline fn increment_assert_contiguous(self: Self, offset: usize) Self {
            assert_contiguous(self.internal, .ADD, offset, @src());
            return self.increment(offset);
        }
        pub inline fn add_in_place_assert_contiguous(self: *Self, offset: usize) void {
            assert_contiguous(self.internal, .ADD, offset, @src());
            self.increment_in_place(offset);
        }

        pub inline fn decrement(self: Self, offset: usize) Self {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => Self{ .internal = @ptrFromInt(@intFromPtr(self.internal) - (offset * @sizeOf(ELEMENT))) },
                .STATIC_RESOLVER => Self{ .internal = g_ptr_sub(self.internal, offset * @sizeOf(ELEMENT)) },
            };
        }
        pub inline fn ecrement_in_place(self: *Self, offset: usize) void {
            self.* = self.decrement(offset);
        }

        pub inline fn subtract_assert_contiguous(self: Self, offset: usize) Self {
            assert_contiguous(self.internal, .SUB, offset, @src());
            return self.decrement(offset);
        }
        pub inline fn subtract_in_place_assert_contiguous(self: *Self, offset: usize) void {
            assert_contiguous(self.internal, .SUB, offset, @src());
            self.ecrement_in_place(offset);
        }

        pub inline fn move(self: Self, offset: isize) Self {
            if (offset < 0) {
                return self.decrement(@as(usize, @intCast(@abs(offset))));
            } else {
                return self.increment(@intCast(offset));
            }
        }
        pub inline fn move_in_place(self: *Self, offset: isize) void {
            self.* = self.move(offset);
        }

        pub inline fn move_assert_contiguous(self: Self, offset: isize) Self {
            if (offset < 0) {
                return self.subtract_assert_contiguous(@as(usize, @intCast(@abs(offset))));
            } else {
                return self.increment_assert_contiguous(@intCast(offset));
            }
        }
        pub inline fn move_in_place_assert_contiguous(self: *Self, offset: isize) void {
            self.* = self.move_assert_contiguous(offset);
        }
        //**************************
        // ELEMENTS BETWEEN
        //**************************
        pub inline fn elements_between_self_low_other_high_exclude(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_low_other_high_exclude_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_low_other_high_exclude_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_exclude(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_exclude_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_exclude_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_low_other_high_include(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_low_other_high_include_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_low_other_high_include_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(self.ptr(u8));
            const high_addr = @intFromPtr(other.ptr(u8));
            if (high_addr < low_addr) return 0;
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_include(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_include_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_self_high_other_low_include_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(other.ptr(u8));
            const high_addr = @intFromPtr(self.ptr(u8));
            if (high_addr < low_addr) return 0;
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_exclude_high(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_exclude_high_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_exclude_high_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_include_high(self: Self, other: Self) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_include_high_or_null(self: Self, other: Self) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn elements_between_include_high_orelse_0(self: Self, other: Self) usize {
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = @intFromPtr(self.ptr(u8));
            const other_addr = @intFromPtr(other.ptr(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(ELEMENT)) - low_addr, @as(usize, @intCast(@sizeOf(ELEMENT))));
        }
        pub inline fn is_within_range_exclude_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = @intFromPtr(self.ptr(u8));
            const low_addr = @intFromPtr(low.ptr(u8));
            const high_addr = @intFromPtr(high.ptr(u8));
            return low_addr <= self_addr and self_addr < high_addr;
        }
        pub inline fn is_within_range_include_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = @intFromPtr(self.ptr(u8));
            const low_addr = @intFromPtr(low.ptr(u8));
            const high_addr = @intFromPtr(high.ptr(u8));
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
            if (comptime Types.type_is_equatable(InternalPtr)) return self.internal == other.internal;
            const self_addr = self.addr();
            const other_addr = other.addr();
            return self_addr == other_addr;
        }
        pub inline fn order(self: Self, other: Self) std.math.Order {
            const self_addr: usize = self.addr();
            const other_addr: usize = other.addr();
            return std.math.order(self_addr, other_addr);
        }
        pub inline fn hash(self: Self) u64 {
            const addr_: usize = self.addr() orelse 0;
            return std.hash.Wyhash.hash(0, std.mem.asBytes(&addr_));
        }
        pub inline fn simple_hash(self: Self) u64 {
            const addr_: usize = self.addr() orelse 0;
            const addr_u64: u64 = @intCast(addr_);
            if (comptime @sizeOf(usize) == 4) {
                return addr_u64 | (addr_u64 << 32);
            }
            return addr_u64;
        }

        //**************************
        // SOURCE INTROSPECTION
        //**************************
        pub inline fn source_kind(self: Self) PointerSourceKind {
            _ = self;
            return switch (comptime SOURCE) {
                .NATIVE => .NATIVE,
                .STATIC_RESOLVER => .STATIC_RESOLVER,
            };
        }
        pub inline fn is_native(self: Self) bool {
            _ = self;
            return IS_NATIVE;
        }
        pub inline fn is_global_resolver(self: Self) bool {
            _ = self;
            return USE_STATIC_RESOLVER;
        }

        //**************************
        // SIGNED DISTANCE
        //**************************
        /// Returns the signed byte distance from `other` to `self` (`self - other`).
        pub inline fn bytes_from(self: Self, other: Self) isize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = self.resolved_addr();
            const other_addr = other.resolved_addr();
            return if (self_addr >= other_addr)
                @as(isize, @intCast(self_addr - other_addr))
            else
                -@as(isize, @intCast(other_addr - self_addr));
        }
        /// Returns the signed element distance from `other` to `self` (`self - other`).
        pub inline fn elements_from(self: Self, other: Self) isize {
            return @divExact(self.bytes_from(other), @as(isize, @intCast(@sizeOf(ELEMENT))));
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
            return self.elements_from(other, ELEMENT);
        }
        pub inline fn elements_from_orelse_0(self: Self, other: Self) isize {
            return self.elements_from_or_null(other, ELEMENT) orelse 0;
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
        pub inline fn add_or_null(self: Self, offset: usize) Self {
            if (self.is_null()) return self;
            return self.increment(offset);
        }
        pub inline fn subtract_or_null(self: Self, offset: usize) Self {
            if (self.is_null()) return self;
            return self.decrement(offset);
        }
        pub inline fn move_or_null(self: Self, offset: isize) Self {
            if (self.is_null()) return self;
            return self.move(offset);
        }
        pub inline fn typed_add_or_null(self: Self, offset: usize) Self {
            if (self.is_null()) return self;
            return self.typed_add(ELEMENT, offset);
        }
        pub inline fn typed_subtract_or_null(self: Self, offset: usize) Self {
            if (self.is_null()) return self;
            return self.typed_subtract(ELEMENT, offset);
        }
        pub inline fn typed_move_or_null(self: Self, offset: isize) Self {
            if (self.is_null()) return self;
            return self.typed_move(ELEMENT, offset);
        }

        //**************************
        // NULL CONSTRUCTION / MUTATION
        //**************************
        pub const NULL = Self{};
        pub inline fn new_null() PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)) {
            return PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE));
        }
        pub inline fn set_null(_: *Self) PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE)) {
            return PointerAdvanced(SOURCE, PTR_DEF.with_nullability(.NULLABLE));
        }
        pub inline fn is_null_or_equal(self: Self, other: Self) bool {
            return self.eql(other);
        }

        //**************************
        // BULK OPERATIONS
        //**************************
        pub inline fn memcopy_to(self: Self, dst: []ELEMENT) void {
            @memcpy(dst, self.slice(ELEMENT, dst.len));
        }
        pub inline fn memcopy_from(self: Self, src: []const ELEMENT) void {
            @memcpy(self.slice(ELEMENT, src.len), src);
        }
        pub inline fn memmove_to(self: Self, dst: []ELEMENT) void {
            const src = self.slice(ELEMENT, dst.len);
            @memmove(dst, src);
        }
        pub inline fn memmove_from(self: Self, src: []const ELEMENT) void {
            const dst = self.slice(ELEMENT, src.len);
            @memmove(dst, src);
        }
        pub inline fn memset(self: Self, value: ELEMENT, len: usize) void {
            @memset(self.slice(ELEMENT, len), value);
        }

        //**************************
        // BYTE ACCESS
        //**************************
        pub inline fn bytes(self: Self, len: anytype) []u8 {
            return self.slice(u8, len);
        }
        pub inline fn const_bytes(self: Self, len: anytype) []const u8 {
            return self.const_slice(u8, len);
        }

        //**************************
        // VOLATILE ACCESS
        //**************************
        pub inline fn get_volatile(self: Self) ELEMENT {
            self.assert_not_null(@src());
            const volatile_ptr: *volatile ELEMENT = @ptrCast(self.ptr(ELEMENT));
            return volatile_ptr.*;
        }
        pub inline fn set_volatile(self: Self, value: ELEMENT) void {
            self.assert_not_null(@src());
            const volatile_ptr: *volatile ELEMENT = @ptrCast(self.ptr(ELEMENT));
            volatile_ptr.* = value;
        }

        //**************************
        // ATOMIC ACCESS
        //**************************
        pub inline fn atomic_load(self: Self, comptime ordering: std.lang.AtomicOrder) ELEMENT {
            self.assert_not_null(@src());
            return @atomicLoad(ELEMENT, self.ptr(ELEMENT), ordering);
        }
        pub inline fn atomic_store(self: Self, value: ELEMENT, comptime ordering: std.lang.AtomicOrder) void {
            self.assert_not_null(@src());
            @atomicStore(ELEMENT, self.ptr(ELEMENT), value, ordering);
        }
        pub inline fn atomic_read_modify_write(self: Self, comptime op: std.lang.AtomicRmwOp, value: ELEMENT, comptime ordering: std.lang.AtomicOrder) ELEMENT {
            self.assert_not_null(@src());
            return @atomicRmw(ELEMENT, self.ptr(ELEMENT), op, value, ordering);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_strong(self: Self, expected: ELEMENT, new_value: ELEMENT, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?ELEMENT {
            self.assert_not_null(@src());
            return @cmpxchgStrong(ELEMENT, self.ptr(ELEMENT), expected, new_value, success_order, fail_order);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_weak(self: Self, expected: ELEMENT, new_value: ELEMENT, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?ELEMENT {
            self.assert_not_null(@src());
            return @cmpxchgWeak(ELEMENT, self.ptr(ELEMENT), expected, new_value, success_order, fail_order);
        }

        // //**************************
        // // ANYOPAQUE CONVERSION
        // //**************************
        // pub inline fn to_anyopaque(self: Self) *anyopaque {
        //     self.assert_not_null(@src());
        //     return @ptrCast(self.ptr(u8));
        // }
        // pub inline fn to_const_anyopaque(self: Self) *const anyopaque {
        //     self.assert_not_null(@src());
        //     return @ptrCast(self.ptr(u8));
        // }
        // pub inline fn to_anyopaque_or_null(self: Self) ?*anyopaque {
        //     if (self.is_null()) return null;
        //     return @ptrCast(self.ptr(u8));
        // }
        // pub inline fn to_const_anyopaque_or_null(self: Self) ?*const anyopaque {
        //     if (self.is_null()) return null;
        //     return @ptrCast(self.ptr(u8));
        // }
        // pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
        //     return Self.new_from_native(void_ptr);
        // }
        // pub inline fn from_const_anyopaque(void_ptr: *const anyopaque) Self {
        //     return Self.new_from_native(void_ptr);
        // }
    };
}
