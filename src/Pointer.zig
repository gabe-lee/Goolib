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
    GLOBAL_RESOLVER,
};

const OffestDir = enum {
    ADD,
    SUB,
};

pub const Mutability = enum {
    MUT_PTR,
    CONST_PTR,
};

pub const Nullability = enum {
    NEVER_NULL,
    NULLABLE,
};

pub const AlignmentSource = union(enum) {
    NATIVE: type,
    BYTES: usize,
    LOG_2: u8,
    POWER_OF_2: PowerOf2,
    STD_MEM_ALIGN: mem.Alignment,

    pub fn native_align(comptime T: type) AlignmentSource {
        return AlignmentSource{ .NATIVE = T };
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

    pub fn calc(comptime self: AlignmentSource) usize {
        return switch (comptime self) {
            .NATIVE => |T| @alignOf(T),
            .BYTES => |B| B,
            .LOG_2 => |L| @as(usize, 1) << @intCast(L),
            .POWER_OF_2 => |P| P.value_as_type(usize),
            .STD_MEM_ALIGN => |A| A.toByteUnits(),
        };
    }
};

pub const GlobalPointerResolver = struct {
    /// The local type stored on the `Pointer/Pointer(T)` struct
    LOCAL_TYPE: type,
    /// MUST be a pointer to a value of type `LOCAL_TYPE_NULLABLE` that represents the 'null' value
    /// for the input type
    LOCAL_NULL_VALUE: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE_NULLABLE) bool`
    IS_NULL_FUNC: *const anyopaque,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
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

pub const AutoIntegerGlobalPointerResolver = struct {
    /// The local integer type stored on the `Pointer/Pointer(T)` struct
    LOCAL_TYPE: type,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
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

    pub fn to_global_resolver(comptime self: AutoIntegerGlobalPointerResolver) GlobalPointerResolver {
        const PROTO = IntegerResolverProto(self.LOCAL_TYPE);
        return GlobalPointerResolver{
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
pub const AutoIntegerBitsGlobalPointerResolver = struct {
    /// The number of bits for the local integer type stored on the `Pointer/Pointer(T)` struct
    LOCAL_TYPE_NUMBER_OF_BITS: u16,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
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

    pub fn to_auto_int(comptime self: AutoIntegerBitsGlobalPointerResolver) AutoIntegerGlobalPointerResolver {
        return AutoIntegerGlobalPointerResolver{
            .LOCAL_TYPE = @Int(.unsigned, self.LOCAL_TYPE_NUMBER_OF_BITS),
            .RESOLVE_FUNC = self.RESOLVE_FUNC,
            .ASSERT_CONTIGUOUS_RANGE = self.ASSERT_CONTIGUOUS_RANGE,
        };
    }
};
pub const AutoIntegerMaxGlobalPointerResolver = struct {
    /// The maximum value for the local integer type stored on the `Pointer/Pointer(T)` struct
    LOCAL_TYPE_VALUE_LIMIT: PowerOf2,
    /// MUST be a pointer to a function in the form `*const fn (LOCAL_TYPE) usize`
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

    pub fn to_auto_int(comptime self: AutoIntegerMaxGlobalPointerResolver) AutoIntegerGlobalPointerResolver {
        return AutoIntegerGlobalPointerResolver{
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

pub const PointerSource = union(PointerSourceKind) {
    NATIVE: void,
    GLOBAL_RESOLVER: GlobalPointerResolver,

    pub fn native_pointer() PointerSource {
        return PointerSource{ .NATIVE = {} };
    }
    pub fn global_pointer_resolver(comptime resolver: GlobalPointerResolver) PointerSource {
        return PointerSource{ .GLOBAL_RESOLVER = resolver };
    }
    pub fn global_pointer_resolver_auto_from_int(comptime resolver: AutoIntegerGlobalPointerResolver) PointerSource {
        return PointerSource{ .GLOBAL_RESOLVER = resolver.to_global_resolver() };
    }
    pub fn global_pointer_resolver_auto_from_int_bits(comptime resolver: AutoIntegerBitsGlobalPointerResolver) PointerSource {
        return PointerSource{ .GLOBAL_RESOLVER = resolver.to_auto_int().to_global_resolver() };
    }
    pub fn global_pointer_resolver_auto_from_int_max(comptime resolver: AutoIntegerMaxGlobalPointerResolver) PointerSource {
        return PointerSource{ .GLOBAL_RESOLVER = resolver.to_auto_int().to_global_resolver() };
    }

    pub fn LOCAL_OPAQUE_TYPE(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => usize,
            .GLOBAL_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn LOCAL_OPAQUE_TYPE_NULL(comptime self: PointerSource) self.LOCAL_OPAQUE_TYPE() {
        return switch (comptime self) {
            .NATIVE => 0,
            .GLOBAL_RESOLVER => |RES| @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).*,
        };
    }
    pub fn LOCAL_TYPED_NULLABLE(comptime self: PointerSource, comptime T: type) type {
        return switch (comptime self) {
            .NATIVE => ?[*]T,
            .GLOBAL_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn LOCAL_TYPED_NULLABLE_INIT(comptime self: PointerSource, comptime T: type) self.LOCAL_TYPED_NULLABLE(T) {
        return switch (comptime self) {
            .NATIVE => null,
            .GLOBAL_RESOLVER => |RES| @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).*,
        };
    }
    pub fn LOCAL_TYPED(comptime self: PointerSource, comptime T: type) type {
        return switch (comptime self) {
            .NATIVE => [*]T,
            .GLOBAL_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn LOCAL_TYPED_INIT(comptime self: PointerSource, comptime T: type) self.LOCAL_TYPED(T) {
        return switch (comptime self) {
            .NATIVE => Utils.invalid_ptr_many(T),
            .GLOBAL_RESOLVER => |RES| @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).*,
        };
    }
    pub fn LOCAL_TYPED_NULLABLE_ALIGN(comptime self: PointerSource, comptime T: type, comptime A: usize) type {
        return switch (comptime self) {
            .NATIVE => ?[*]align(A) T,
            .GLOBAL_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn LOCAL_TYPED_NULLABLE_ALIGN_INIT(comptime self: PointerSource, comptime T: type, comptime A: usize) self.LOCAL_TYPED_NULLABLE_ALIGN(T, A) {
        return switch (comptime self) {
            .NATIVE => null,
            .GLOBAL_RESOLVER => |RES| @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).*,
        };
    }
    pub fn LOCAL_TYPED_ALIGN(comptime self: PointerSource, comptime T: type, comptime A: usize) type {
        return switch (comptime self) {
            .NATIVE => [*]align(A) T,
            .GLOBAL_RESOLVER => |RES| RES.LOCAL_TYPE,
        };
    }
    pub fn LOCAL_TYPED_ALIGN_INIT(comptime self: PointerSource, comptime T: type, comptime A: usize) self.LOCAL_TYPED_ALIGN(T, A) {
        return switch (comptime self) {
            .NATIVE => Utils.invalid_ptr_many_ct_align(T, A),
            .GLOBAL_RESOLVER => |RES| @as(*const RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.LOCAL_NULL_VALUE))).*,
        };
    }
    pub fn NULL_CHECK_TYPE(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .GLOBAL_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE) bool,
        };
    }
    pub fn NULL_CHECK_TYPE_INIT(comptime self: PointerSource) self.NULL_CHECK_TYPE() {
        return switch (comptime self) {
            .NATIVE => {},
            .GLOBAL_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE) bool, @ptrCast(@alignCast(RES.IS_NULL_FUNC))),
        };
    }
    pub fn RESOLVER_TYPE(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .GLOBAL_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE) usize,
        };
    }
    pub fn RESOLVER_TYPE_INIT(comptime self: PointerSource) self.RESOLVER_TYPE() {
        return switch (comptime self) {
            .NATIVE => {},
            .GLOBAL_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE) usize, @ptrCast(@alignCast(RES.RESOLVE_FUNC))),
        };
    }
    pub fn ADDER_TYPE(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .GLOBAL_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn ADDER_TYPE_INIT(comptime self: PointerSource) self.ADDER_TYPE() {
        return switch (comptime self) {
            .NATIVE => {},
            .GLOBAL_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.ADD_FUNC))),
        };
    }
    pub fn SUBTRACTER_TYPE(comptime self: PointerSource) type {
        return switch (comptime self) {
            .NATIVE => void,
            .GLOBAL_RESOLVER => |RES| *const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE,
        };
    }
    pub fn SUBTRACTER_TYPE_INIT(comptime self: PointerSource) self.SUBTRACTER_TYPE() {
        return switch (comptime self) {
            .NATIVE => {},
            .GLOBAL_RESOLVER => |RES| @as(*const fn (RES.LOCAL_TYPE, usize) RES.LOCAL_TYPE, @ptrCast(@alignCast(RES.SUBTRACT_FUNC))),
        };
    }
};

/// An adapter that can take ANY `PointerSource` and
/// provide a standard set of pointer casts and operations.
///
/// A `.NATIVE` pointer source should compile most of these
/// to identical instructions as if you were working with
/// a `?* anyopaque` pointer.
///
/// Using a `.GLOBAL_RESOLVER` allows using an arbitrary type
/// as a handle that can be resolved to a real native pointer
/// via a comptime-known static function (For example, provided
/// by a specially designed global allocator).
///
/// The `.GLOBAL_RESOLVER` option allows you to have pointer-access
/// semantics with a handle type that may be much smaller than a `usize`, or
/// that has some other interesting semantics such as side-effects
/// when a pointer is resolved, at the cost of additional processing overhead.
pub fn PointerOpaque(comptime SOURCE: PointerSource) type {
    return extern struct {
        const Self = @This();
        pub const Addr = SOURCE.LOCAL_OPAQUE_TYPE();
        pub const AddrNull = SOURCE.LOCAL_OPAQUE_TYPE_NULL();

        const RESOLVE: SOURCE.RESOLVER_TYPE() = SOURCE.RESOLVER_TYPE_INIT();
        const ADD: SOURCE.ADDER_TYPE() = SOURCE.ADDER_TYPE_INIT();
        const SUB: SOURCE.SUBTRACTER_TYPE() = SOURCE.SUBTRACTER_TYPE_INIT();
        const IS_NULL: SOURCE.NULL_CHECK_TYPE() = SOURCE.NULL_CHECK_TYPE_INIT();
        pub const USE_GLOBAL_RESOLVER = SOURCE == .GLOBAL_RESOLVER;
        pub const IS_NATIVE = SOURCE == .NATIVE;
        const ASSERT_CONTIG = if (USE_GLOBAL_RESOLVER) SOURCE.GLOBAL_RESOLVER.ASSERT_CONTIGUOUS_RANGE else false;
        addr: Addr = AddrNull,

        pub inline fn new(addr: Addr) Self {
            return Self{ .addr = addr };
        }
        pub inline fn new_from_native(any_ptr: anytype) Self {
            assert_native(@src());
            if (comptime IS_NATIVE) {
                return Self{ .addr = @intFromPtr(any_ptr) };
            } else {
                unreachable;
            }
        }

        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            assert_with_reason(IS_NATIVE, src, "cannot be called when mode is not .NATIVE", .{});
        }

        inline fn resolve(self: Self, comptime T: type) [*]T {
            return switch (comptime SOURCE) {
                .NATIVE => @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(self.addr)))),
                .GLOBAL_RESOLVER => @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(RESOLVE(self.addr))))),
            };
        }
        inline fn resolve_aligned(self: Self, comptime T: type, comptime ALIGN: usize) [*]align(ALIGN) T {
            return switch (comptime SOURCE) {
                .NATIVE => @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(self.addr)))),
                .GLOBAL_RESOLVER => @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(RESOLVE(self.addr))))),
            };
        }
        inline fn resolve_null(self: Self, comptime T: type) ?[*]T {
            switch (comptime SOURCE) {
                .NATIVE => return @ptrCast(@alignCast(@as(?[*]u8, @ptrFromInt(self.addr)))),
                .GLOBAL_RESOLVER => if (self.is_null()) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(RESOLVE(self.addr)))));
                },
            }
        }
        inline fn resolve_null_aligned(self: Self, comptime T: type, comptime ALIGN: usize) ?[*]align(ALIGN) T {
            switch (comptime SOURCE) {
                .NATIVE => return @ptrCast(@alignCast(@as(?[*]u8, @ptrFromInt(self.addr)))),
                .GLOBAL_RESOLVER => if (self.is_null()) {
                    return null;
                } else {
                    return @ptrCast(@alignCast(@as([*]u8, @ptrFromInt(RESOLVE(self.addr)))));
                },
            }
        }

        pub inline fn is_null(self: Self) bool {
            return switch (comptime SOURCE) {
                .NATIVE => self.addr == 0,
                .GLOBAL_RESOLVER => IS_NULL(self.addr),
            };
        }
        pub inline fn not_null(self: Self) bool {
            return switch (comptime SOURCE) {
                .NATIVE => self.addr != 0,
                .GLOBAL_RESOLVER => !IS_NULL(self.addr),
            };
        }
        pub inline fn assert_not_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.not_null(), src, "pointer was null", .{});
        }
        pub inline fn assert_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_null(), src, "pointer was not null", .{});
        }

        /// Casts this opaque pointer handle to the typed wrapper type described by the
        /// requested properties.
        pub inline fn cast_to(
            self: Self,
            comptime NULLABILITY: Nullability,
            comptime MUTABILITY: Mutability,
            comptime T: type,
            comptime ALIGN: anytype,
        ) PointerWithProperties(SOURCE, NULLABILITY, MUTABILITY, T, TypedPointerNormalizeAlign(ALIGN)) {
            const A = comptime TypedPointerNormalizeAlign(ALIGN);
            if (comptime NULLABILITY == .NEVER_NULL) {
                self.assert_not_null(@src());
            }
            if (comptime A) |a| {
                // A null nullable pointer has no meaningful alignment to check.
                if (comptime NULLABILITY == .NEVER_NULL) {
                    self.assert_aligned(a, @src());
                } else if (self.not_null()) {
                    self.assert_aligned(a, @src());
                }
            }
            return .{ .opq = self };
        }

        pub inline fn is_aligned(self: Self, alignment: usize) bool {
            return switch (comptime SOURCE) {
                .NATIVE => std.mem.isAligned(self.addr, alignment),
                .GLOBAL_RESOLVER => std.mem.isAligned(RESOLVE(self.addr), alignment),
            };
        }
        pub inline fn is_aligned_any(self: Self, alignment: usize) bool {
            return switch (comptime SOURCE) {
                .NATIVE => std.mem.isAlignedAnyAlign(self.addr, alignment),
                .GLOBAL_RESOLVER => std.mem.isAlignedAnyAlign(RESOLVE(self.addr), alignment),
            };
        }
        pub inline fn is_aligned_log_2(self: Self, alignment_log_2: u8) bool {
            return switch (comptime SOURCE) {
                .NATIVE => std.mem.isAlignedLog2(self.addr, alignment_log_2),
                .GLOBAL_RESOLVER => std.mem.isAlignedLog2(RESOLVE(self.addr), alignment_log_2),
            };
        }
        pub inline fn is_aligned_pow_2(self: Self, alignment_pow_2: PowerOf2) bool {
            return switch (comptime SOURCE) {
                .NATIVE => std.mem.isAlignedLog2(self.addr, alignment_pow_2.raw_int()),
                .GLOBAL_RESOLVER => std.mem.isAlignedLog2(RESOLVE(self.addr), alignment_pow_2.raw_int()),
            };
        }
        pub inline fn is_aligned_std_mem(self: Self, alignment: mem.Alignment) bool {
            return switch (comptime SOURCE) {
                .NATIVE => std.mem.isAlignedLog2(self.addr, @intCast(@backingInt(alignment))),
                .GLOBAL_RESOLVER => std.mem.isAlignedLog2(RESOLVE(self.addr), @intCast(@backingInt(alignment))),
            };
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

        inline fn assert_contiguous_known_new(original_addr: Addr, new_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous_known_new(original_addr: Addr, new_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_GLOBAL_RESOLVER) {
                const real_original = RESOLVE(original_addr);
                const real_new = RESOLVE(new_addr);
                const expect_real_new = switch (comptime DIR) {
                    .ADD => real_original + offset,
                    .SUB => real_original - offset,
                };
                assert_with_reason(real_new == expect_real_new, src, "adding {d} to the pointer caused the resolved address of the new address handle to not equal the expected address for a contiguous memory region: local address handle escaped its contiguous memory region", .{offset});
            }
        }
        inline fn assert_contiguous(original_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                const new_addr = switch (comptime DIR) {
                    .ADD => ADD(original_addr, offset),
                    .SUB => SUB(original_addr, offset),
                };
                assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous(original_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_GLOBAL_RESOLVER) {
                const new_addr = switch (comptime DIR) {
                    .ADD => ADD(original_addr, offset),
                    .SUB => SUB(original_addr, offset),
                };
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn assert_contiguous_ignore_null(original_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime ASSERT_CONTIG) {
                if (IS_NULL(original_addr)) return;
                const new_addr = switch (comptime DIR) {
                    .ADD => ADD(original_addr, offset),
                    .SUB => SUB(original_addr, offset),
                };
                assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }
        inline fn always_assert_contiguous_ignore_null(original_addr: Addr, comptime DIR: OffestDir, offset: usize, comptime src: ?SourceLocation) void {
            if (comptime USE_GLOBAL_RESOLVER) {
                if (IS_NULL(original_addr)) return;
                const new_addr = switch (comptime DIR) {
                    .ADD => ADD(original_addr, offset),
                    .SUB => SUB(original_addr, offset),
                };
                always_assert_contiguous_known_new(original_addr, new_addr, DIR, offset, src);
            }
        }

        //**********************
        // ____ _____ PTR _____
        //**********************
        pub inline fn ptr(self: Self, comptime T: type) *T {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn ptr_many(self: Self, comptime T: type) [*]T {
            self.assert_not_null(@src());
            return self.resolve(T);
        }
        pub inline fn slice(self: Self, comptime T: type, len: anytype) []T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            return self.resolve(T)[0..len];
        }
        pub inline fn array_ptr(self: Self, comptime T: type, comptime LEN: anytype) *[LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn vector_ptr(self: Self, comptime T: type, comptime LEN: anytype) *@Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve(T)));
        }
        //**********************
        // ____ _____ PTR ALIGN
        //**********************
        pub inline fn ptr_aligned(self: Self, comptime T: type, comptime A: usize) *align(A) T {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn ptr_many_aligned(self: Self, comptime T: type, comptime A: usize) [*]align(A) T {
            self.assert_not_null(@src());
            return self.resolve_aligned(T, A);
        }
        pub inline fn slice_aligned(self: Self, comptime T: type, comptime A: usize, len: anytype) []align(A) T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            return self.resolve_aligned(T, A)[0..len];
        }
        pub inline fn array_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn vector_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_aligned(T, A)));
        }
        //**********************
        // ____ CONST PTR _____
        //**********************
        pub inline fn const_ptr(self: Self, comptime T: type) *const T {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn const_ptr_many(self: Self, comptime T: type) [*]const T {
            self.assert_not_null(@src());
            return self.resolve(T);
        }
        pub inline fn const_slice(self: Self, comptime T: type, len: anytype) []const T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            return self.resolve(T)[0..len];
        }
        pub inline fn const_array_ptr(self: Self, comptime T: type, comptime LEN: anytype) *const [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn const_vector_ptr(self: Self, comptime T: type, comptime LEN: anytype) *const @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve(T)));
        }
        //**********************
        // ____ CONST PTR ALIGN
        //**********************
        pub inline fn const_ptr_aligned(self: Self, comptime T: type, comptime A: usize) *align(A) const T {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn const_ptr_many_aligned(self: Self, comptime T: type, comptime A: usize) [*]align(A) const T {
            self.assert_not_null(@src());
            return self.resolve_aligned(T, A);
        }
        pub inline fn const_slice_aligned(self: Self, comptime T: type, comptime A: usize, len: anytype) []align(A) const T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            return self.resolve_aligned(T, A)[0..len];
        }
        pub inline fn const_array_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn const_vector_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_aligned(T, A)));
        }
        //**********************
        // NULL _____ PTR _____
        //**********************
        pub inline fn ptr_or_null(self: Self, comptime T: type) ?*T {
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn ptr_many_or_null(self: Self, comptime T: type) ?[*]T {
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn slice_or_null(self: Self, comptime T: type, len: anytype) ?[]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            if (self.resolve_null(T)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn array_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*[LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn vector_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*@Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_null(T)));
        }
        //**********************
        // NULL _____ PTR ALIGN
        //**********************
        pub inline fn ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize) ?*align(A) T {
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn ptr_many_aligned_or_null(self: Self, comptime T: type, comptime A: usize) ?[*]align(A) T {
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn slice_aligned_or_null(self: Self, comptime T: type, comptime A: usize, len: anytype) ?[]align(A) T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            if (self.resolve_null_aligned(T, A)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn array_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn vector_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_null_aligned(T, A)));
        }
        //**********************
        // NULL CONST PTR _____
        //**********************
        pub inline fn const_ptr_or_null(self: Self, comptime T: type) ?*const T {
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn const_ptr_many_or_null(self: Self, comptime T: type) ?[*]const T {
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn const_slice_or_null(self: Self, comptime T: type, len: anytype) ?[]const T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            if (self.resolve_null(T)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn const_array_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*const [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn const_vector_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*const @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_null(T)));
        }
        //**********************
        // NULL CONST PTR ALIGN
        //**********************
        pub inline fn const_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize) ?*align(A) const T {
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn const_ptr_many_aligned_or_null(self: Self, comptime T: type, comptime A: usize) ?[*]align(A) const T {
            return self.resolve_null_aligned(T, A);
        }
        pub inline fn const_slice_aligned_or_null(self: Self, comptime T: type, comptime A: usize, len: anytype) ?[]align(A) const T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) -| 1, @src());
            if (self.resolve_null_aligned(T, A)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn const_array_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) const [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn const_vector_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) const @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) -| 1, @src());
            return @ptrCast(@alignCast(self.resolve_null_aligned(T, A)));
        }
        //***********
        // GET / SET
        //***********
        pub inline fn get(self: Self, comptime T: type) T {
            return self.ptr(T).*;
        }
        pub inline fn get_or_null(self: Self, comptime T: type) ?T {
            if (self.ptr_or_null(T)) |p| {
                return p.*;
            }
            return null;
        }
        pub inline fn get_orelse(self: Self, comptime T: type, default: T) T {
            if (self.ptr_or_null(T)) |p| {
                return p.*;
            }
            return default;
        }
        pub inline fn get_at_index(self: Self, comptime T: type, index: usize) T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, @sizeOf(T) * index, @src());
            return self.ptr_many(T)[index];
        }
        pub inline fn get_at_index_or_null(self: Self, comptime T: type, index: usize) ?T {
            assert_contiguous_ignore_null(self.addr, .ADD, @sizeOf(T) * index, @src());
            if (self.ptr_many_or_null(T)) |p| {
                return p[index];
            }
            return null;
        }
        pub inline fn get_at_index_orelse(self: Self, comptime T: type, index: usize, default: T) T {
            assert_contiguous_ignore_null(self.addr, .ADD, @sizeOf(T) * index, @src());
            if (self.ptr_many_or_null(T)) |p| {
                return p[index];
            }
            return default;
        }
        pub inline fn set(self: Self, comptime T: type, val: T) void {
            self.ptr(T).* = val;
        }
        pub inline fn set_if_not_null(self: Self, comptime T: type, val: T) void {
            if (self.ptr_or_null(T)) |p| {
                p.* = val;
            }
        }
        pub inline fn set_if_not_null_return_ptr_is_NOT_null(self: Self, comptime T: type, val: T) bool {
            if (self.ptr_or_null(T)) |p| {
                p.* = val;
                return true;
            }
            return false;
        }
        pub inline fn set_if_not_null_return_ptr_IS_null(self: Self, comptime T: type, val: T) bool {
            if (self.ptr_or_null(T)) |p| {
                p.* = val;
                return false;
            }
            return true;
        }
        pub inline fn set_at_index(self: Self, comptime T: type, index: usize, val: T) void {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, @sizeOf(T) * index, @src());
            self.ptr_many(T)[index] = val;
        }
        pub inline fn set_at_index_if_not_null(self: Self, comptime T: type, index: usize, val: T) void {
            assert_contiguous_ignore_null(self.addr, .ADD, @sizeOf(T) * index, @src());
            if (self.ptr_many_or_null(T)) |p| {
                p[index] = val;
            }
        }
        pub inline fn set_at_index_if_not_null_return_ptr_is_NOT_null(self: Self, comptime T: type, index: usize, val: T) bool {
            assert_contiguous_ignore_null(self.addr, .ADD, @sizeOf(T) * index, @src());
            if (self.ptr_many_or_null(T)) |p| {
                p[index] = val;
                return true;
            }
            return false;
        }
        pub inline fn set_at_index_if_not_null_return_ptr_IS_null(self: Self, comptime T: type, index: usize, val: T) bool {
            assert_contiguous_ignore_null(self.addr, .ADD, @sizeOf(T) * index, @src());
            if (self.ptr_many_or_null(T)) |p| {
                p[index] = val;
                return false;
            }
            return true;
        }
        //**************************
        // ADDRESS ADD / SUB / MOVE
        //**************************
        pub inline fn add(self: Self, offset: usize) Self {
            return switch (comptime SOURCE) {
                .NATIVE => Self{ .addr = self.addr + offset },
                .GLOBAL_RESOLVER => Self{ .addr = ADD(self.addr, offset) },
            };
        }
        pub inline fn add_in_place(self: *Self, offset: usize) void {
            self.* = self.add(offset);
        }
        pub inline fn typed_add(self: Self, comptime T: type, offset: usize) Self {
            return self.add(@sizeOf(T) * offset);
        }
        pub inline fn typed_add_in_place(self: *Self, comptime T: type, offset: usize) void {
            self.add_in_place(@sizeOf(T) * offset);
        }

        pub inline fn add_assert_contiguous(self: Self, offset: usize) Self {
            assert_contiguous(self.addr, .ADD, offset, @src());
            return self.add(offset);
        }
        pub inline fn add_in_place_assert_contiguous(self: *Self, offset: usize) void {
            assert_contiguous(self.addr, .ADD, offset, @src());
            self.add_in_place(offset);
        }
        pub inline fn typed_add_assert_contiguous(self: Self, comptime T: type, offset: usize) Self {
            assert_contiguous(self.addr, .ADD, @sizeOf(T) * offset, @src());
            return self.typed_add(T, offset);
        }
        pub inline fn typed_add_in_place_assert_contiguous(self: *Self, comptime T: type, offset: usize) void {
            assert_contiguous(self.addr, .ADD, @sizeOf(T) * offset, @src());
            self.typed_add_in_place(T, offset);
        }

        pub inline fn subtract(self: Self, offset: usize) Self {
            return switch (comptime SOURCE) {
                .NATIVE => Self{ .addr = self.addr - offset },
                .GLOBAL_RESOLVER => Self{ .addr = SUB(self.addr, offset) },
            };
        }
        pub inline fn subtract_in_place(self: *Self, offset: usize) void {
            self.* = self.subtract(offset);
        }
        pub inline fn typed_subtract(self: Self, comptime T: type, offset: usize) Self {
            return self.subtract(@sizeOf(T) * offset);
        }
        pub inline fn typed_subtract_in_place(self: *Self, comptime T: type, offset: usize) void {
            self.subtract_in_place(@sizeOf(T) * offset);
        }

        pub inline fn subtract_assert_contiguous(self: Self, offset: usize) Self {
            assert_contiguous(self.addr, .SUB, offset, @src());
            return self.subtract(offset);
        }
        pub inline fn subtract_in_place_assert_contiguous(self: *Self, offset: usize) void {
            assert_contiguous(self.addr, .SUB, offset, @src());
            self.subtract_in_place(offset);
        }
        pub inline fn typed_subtract_assert_contiguous(self: Self, comptime T: type, offset: usize) Self {
            assert_contiguous(self.addr, .SUB, @sizeOf(T) * offset, @src());
            return self.typed_subtract(T, offset);
        }
        pub inline fn typed_subtract_in_place_assert_contiguous(self: *Self, comptime T: type, offset: usize) void {
            assert_contiguous(self.addr, .SUB, @sizeOf(T) * offset, @src());
            self.typed_subtract_in_place(T, offset);
        }

        pub inline fn move(self: Self, offset: isize) Self {
            if (offset < 0) {
                return self.subtract(@as(usize, @intCast(@abs(offset))));
            } else {
                return self.add(@intCast(offset));
            }
        }
        pub inline fn move_in_place(self: *Self, offset: isize) void {
            self.* = self.move(offset);
        }
        pub inline fn typed_move(self: Self, comptime T: type, offset: isize) Self {
            return self.move(@sizeOf(T) * offset);
        }
        pub inline fn typed_move_in_place(self: *Self, comptime T: type, offset: isize) void {
            self.move_in_place(@sizeOf(T) * offset);
        }

        pub inline fn move_assert_contiguous(self: Self, offset: isize) Self {
            if (offset < 0) {
                return self.subtract_assert_contiguous(@as(usize, @intCast(@abs(offset))));
            } else {
                return self.add_assert_contiguous(@intCast(offset));
            }
        }
        pub inline fn move_in_place_assert_contiguous(self: *Self, offset: isize) void {
            self.* = self.move_assert_contiguous(offset);
        }
        pub inline fn typed_move_assert_contiguous(self: Self, comptime T: type, offset: isize) Self {
            return self.move_assert_contiguous(@sizeOf(T) * offset);
        }
        pub inline fn typed_move_in_place_assert_contiguous(self: *Self, comptime T: type, offset: isize) void {
            self.move_in_place_assert_contiguous(@sizeOf(T) * offset);
        }
        //**************************
        // ELEMENTS BETWEEN
        //**************************
        pub inline fn elements_between_self_low_other_high_exclude(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_low_other_high_exclude_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_low_other_high_exclude_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_exclude(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_exclude_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_exclude_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            if (high_addr < low_addr) return 0;
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_low_other_high_include(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_low_other_high_include_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_low_other_high_include_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(self.resolve(u8));
            const high_addr = @intFromPtr(other.resolve(u8));
            if (high_addr < low_addr) return 0;
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_include(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_include_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            assert_with_reason(low_addr <= high_addr, @src(), "self was not a lower address than other", .{});
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_self_high_other_low_include_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const low_addr = @intFromPtr(other.resolve(u8));
            const high_addr = @intFromPtr(self.resolve(u8));
            if (high_addr < low_addr) return 0;
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_exclude_high(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_exclude_high_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_exclude_high_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact(high_addr - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_include_high(self: Self, other: Self, comptime T: type) usize {
            self.assert_not_null(@src());
            other.assert_not_null(@src());
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_include_high_or_null(self: Self, other: Self, comptime T: type) ?usize {
            if (self.is_null() or other.is_null()) return null;
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn elements_between_include_high_orelse_0(self: Self, other: Self, comptime T: type) usize {
            if (self.is_null() or other.is_null()) return 0;
            const self_addr = @intFromPtr(self.resolve(u8));
            const other_addr = @intFromPtr(other.resolve(u8));
            const low_addr = @min(self_addr, other_addr);
            const high_addr = @max(self_addr, other_addr);
            return @divExact((high_addr + @sizeOf(T)) - low_addr, @as(usize, @intCast(@sizeOf(T))));
        }
        pub inline fn is_within_range_exclude_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = @intFromPtr(self.resolve(u8));
            const low_addr = @intFromPtr(low.resolve(u8));
            const high_addr = @intFromPtr(high.resolve(u8));
            return low_addr <= self_addr and self_addr < high_addr;
        }
        pub inline fn is_within_range_include_high(self: Self, low: Self, high: Self) bool {
            self.assert_not_null(@src());
            low.assert_not_null(@src());
            high.assert_not_null(@src());
            const self_addr = @intFromPtr(self.resolve(u8));
            const low_addr = @intFromPtr(low.resolve(u8));
            const high_addr = @intFromPtr(high.resolve(u8));
            return low_addr <= self_addr and self_addr <= high_addr;
        }
        pub inline fn assert_is_within_range_exclude_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_within_range_exclude_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }
        pub inline fn assert_is_within_range_include_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_within_range_include_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }

        //**************************
        // ADDRESS INTROSPECTION
        //**************************
        pub inline fn local_addr(self: Self) Addr {
            return self.addr;
        }
        pub inline fn resolved_addr(self: Self) usize {
            self.assert_not_null(@src());
            return switch (comptime SOURCE) {
                .NATIVE => self.addr,
                .GLOBAL_RESOLVER => RESOLVE(self.addr),
            };
        }
        pub inline fn resolved_addr_or_null(self: Self) ?usize {
            return switch (comptime SOURCE) {
                .NATIVE => if (self.addr == 0) null else self.addr,
                .GLOBAL_RESOLVER => if (IS_NULL(self.addr)) null else RESOLVE(self.addr),
            };
        }

        //**************************
        // COMPARISON / HASHING
        //**************************
        pub inline fn eql(self: Self, other: Self) bool {
            if (comptime Types.type_is_equatable(Addr)) return self.addr == other.addr;
            const self_addr = self.resolved_addr_or_null();
            const other_addr = other.resolved_addr_or_null();
            if (self_addr) |a| {
                if (other_addr) |b| return a == b;
                return false;
            }
            return other_addr == null;
        }
        pub inline fn eql_native(self: Self, native_ptr: anytype) bool {
            switch (comptime @typeInfo(@TypeOf(native_ptr))) {
                .optional => {
                    if (native_ptr) |p| {
                        return self.not_null() and self.resolved_addr() == @intFromPtr(p);
                    }
                    return self.is_null();
                },
                .pointer => {
                    return self.not_null() and self.resolved_addr() == @intFromPtr(native_ptr);
                },
                else => @compileError("eql_native requires a pointer or optional pointer"),
            }
        }
        pub inline fn eql_local(self: Self, other: Self) bool {
            return std.meta.eql(self.addr, other.addr);
        }
        pub inline fn order(self: Self, other: Self) std.math.Order {
            const self_addr = self.resolved_addr_or_null() orelse 0;
            const other_addr = other.resolved_addr_or_null() orelse 0;
            return std.math.order(self_addr, other_addr);
        }
        pub inline fn hash(self: Self) u64 {
            const addr = self.resolved_addr_or_null() orelse 0;
            return std.hash.Wyhash.hash(0, std.mem.asBytes(&addr));
        }
        pub inline fn simple_hash(self: Self) u64 {
            const addr = self.resolved_addr_or_null() orelse 0;
            const addr_u64: u64 = @intCast(addr);
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
                .GLOBAL_RESOLVER => .GLOBAL_RESOLVER,
            };
        }
        pub inline fn is_native(self: Self) bool {
            _ = self;
            return IS_NATIVE;
        }
        pub inline fn is_global_resolver(self: Self) bool {
            _ = self;
            return USE_GLOBAL_RESOLVER;
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
        pub inline fn elements_from(self: Self, other: Self, comptime T: type) isize {
            return @divExact(self.bytes_from(other), @as(isize, @intCast(@sizeOf(T))));
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
        pub inline fn elements_from_or_null(self: Self, other: Self, comptime T: type) ?isize {
            if (self.is_null() or other.is_null()) return null;
            return self.elements_from(other, T);
        }
        pub inline fn elements_from_orelse_0(self: Self, other: Self, comptime T: type) isize {
            return self.elements_from_or_null(other, T) orelse 0;
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
            return self.add(offset);
        }
        pub inline fn subtract_or_null(self: Self, offset: usize) Self {
            if (self.is_null()) return self;
            return self.subtract(offset);
        }
        pub inline fn move_or_null(self: Self, offset: isize) Self {
            if (self.is_null()) return self;
            return self.move(offset);
        }
        pub inline fn typed_add_or_null(self: Self, comptime T: type, offset: usize) Self {
            if (self.is_null()) return self;
            return self.typed_add(T, offset);
        }
        pub inline fn typed_subtract_or_null(self: Self, comptime T: type, offset: usize) Self {
            if (self.is_null()) return self;
            return self.typed_subtract(T, offset);
        }
        pub inline fn typed_move_or_null(self: Self, comptime T: type, offset: isize) Self {
            if (self.is_null()) return self;
            return self.typed_move(T, offset);
        }

        //**************************
        // NULL CONSTRUCTION / MUTATION
        //**************************
        pub const NULL = Self{ .addr = AddrNull };
        pub inline fn new_null() Self {
            return Self{ .addr = AddrNull };
        }
        pub inline fn set_null(self: *Self) void {
            self.addr = AddrNull;
        }
        pub inline fn is_null_or_equal(self: Self, other: Self) bool {
            return self.eql(other);
        }

        //**************************
        // BULK OPERATIONS
        //**************************
        pub inline fn memcopy_to(self: Self, comptime T: type, dst: []T) void {
            @memcpy(dst, self.slice(T, dst.len));
        }
        pub inline fn memcopy_from(self: Self, comptime T: type, src: []const T) void {
            @memcpy(self.slice(T, src.len), src);
        }
        pub inline fn memmove_to(self: Self, comptime T: type, dst: []T) void {
            const src = self.slice(T, dst.len);
            @memmove(dst, src);
        }
        pub inline fn memmove_from(self: Self, comptime T: type, src: []const T) void {
            const dst = self.slice(T, src.len);
            @memmove(dst, src);
        }
        pub inline fn memset(self: Self, comptime T: type, value: T, len: usize) void {
            @memset(self.slice(T, len), value);
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
        pub inline fn get_volatile(self: Self, comptime T: type) T {
            self.assert_not_null(@src());
            const volatile_ptr: *volatile T = @ptrCast(self.resolve(T));
            return volatile_ptr.*;
        }
        pub inline fn set_volatile(self: Self, comptime T: type, value: T) void {
            self.assert_not_null(@src());
            const volatile_ptr: *volatile T = @ptrCast(self.resolve(T));
            volatile_ptr.* = value;
        }

        //**************************
        // ATOMIC ACCESS
        //**************************
        pub inline fn atomic_load(self: Self, comptime T: type, comptime ordering: std.lang.AtomicOrder) T {
            self.assert_not_null(@src());
            return @atomicLoad(T, self.ptr(T), ordering);
        }
        pub inline fn atomic_store(self: Self, comptime T: type, value: T, comptime ordering: std.lang.AtomicOrder) void {
            self.assert_not_null(@src());
            @atomicStore(T, self.ptr(T), value, ordering);
        }
        pub inline fn atomic_read_modify_write(self: Self, comptime T: type, comptime op: std.lang.AtomicRmwOp, value: T, comptime ordering: std.lang.AtomicOrder) T {
            self.assert_not_null(@src());
            return @atomicRmw(T, self.ptr(T), op, value, ordering);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_strong(self: Self, comptime T: type, expected: T, new_value: T, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?T {
            self.assert_not_null(@src());
            return @cmpxchgStrong(T, self.ptr(T), expected, new_value, success_order, fail_order);
        }
        /// Returns `null` when the comparison succeeds, or the previous value when it fails.
        pub inline fn atomic_compare_exchange_weak(self: Self, comptime T: type, expected: T, new_value: T, comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?T {
            self.assert_not_null(@src());
            return @cmpxchgWeak(T, self.ptr(T), expected, new_value, success_order, fail_order);
        }

        //**************************
        // ANYOPAQUE CONVERSION
        //**************************
        pub inline fn to_anyopaque(self: Self) *anyopaque {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve(u8));
        }
        pub inline fn to_const_anyopaque(self: Self) *const anyopaque {
            self.assert_not_null(@src());
            return @ptrCast(self.resolve(u8));
        }
        pub inline fn to_anyopaque_or_null(self: Self) ?*anyopaque {
            if (self.is_null()) return null;
            return @ptrCast(self.resolve(u8));
        }
        pub inline fn to_const_anyopaque_or_null(self: Self) ?*const anyopaque {
            if (self.is_null()) return null;
            return @ptrCast(self.resolve(u8));
        }
        pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
            return Self.new_from_native(void_ptr);
        }
        pub inline fn from_const_anyopaque(void_ptr: *const anyopaque) Self {
            return Self.new_from_native(void_ptr);
        }
    };
}

/// Selects the typed pointer wrapper that matches the requested properties.
///
/// `ALIGN == null` selects an unaligned wrapper; any non-null value selects the
/// corresponding aligned wrapper. `ALIGN` may be a plain byte count, an optional
/// byte count, a `PowerOf2`, a `std.mem.Alignment`, or an `AlignmentSource`.
pub fn PointerWithProperties(
    comptime SOURCE: PointerSource,
    comptime NULLABILITY: Nullability,
    comptime MUTABILITY: Mutability,
    comptime T: type,
    comptime ALIGN: anytype,
) type {
    const A = comptime TypedPointerNormalizeAlign(ALIGN);
    return switch (NULLABILITY) {
        .NEVER_NULL => switch (MUTABILITY) {
            .MUT_PTR => if (A) |a| PointerAlign(T, a, SOURCE) else Pointer(T, SOURCE),
            .CONST_PTR => if (A) |a| ConstPointerAlign(T, a, SOURCE) else ConstPointer(T, SOURCE),
        },
        .NULLABLE => switch (MUTABILITY) {
            .MUT_PTR => if (A) |a| NullablePointerAlign(T, a, SOURCE) else NullablePointer(T, SOURCE),
            .CONST_PTR => if (A) |a| NullableConstPointerAlign(T, a, SOURCE) else NullableConstPointer(T, SOURCE),
        },
    };
}

//******************************
// TYPED WRAPPER HELPERS
//******************************

fn TypedPointerPtrType(comptime Elem: type, comptime ALIGN: ?usize, comptime CONST: bool) type {
    if (ALIGN) |a| {
        return if (CONST) *align(a) const Elem else *align(a) Elem;
    } else {
        return if (CONST) *const Elem else *Elem;
    }
}
fn TypedPointerManyPtrType(comptime Elem: type, comptime ALIGN: ?usize, comptime CONST: bool) type {
    if (ALIGN) |a| {
        return if (CONST) [*]align(a) const Elem else [*]align(a) Elem;
    } else {
        return if (CONST) [*]const Elem else [*]Elem;
    }
}
fn TypedPointerSliceType(comptime Elem: type, comptime ALIGN: ?usize, comptime CONST: bool) type {
    if (ALIGN) |a| {
        return if (CONST) []align(a) const Elem else []align(a) Elem;
    } else {
        return if (CONST) []const Elem else []Elem;
    }
}
fn TypedPointerArrayPtrType(comptime Elem: type, comptime ALIGN: ?usize, comptime CONST: bool, comptime LEN: anytype) type {
    if (ALIGN) |a| {
        return if (CONST) *align(a) const [LEN]Elem else *align(a) [LEN]Elem;
    } else {
        return if (CONST) *const [LEN]Elem else *[LEN]Elem;
    }
}
fn TypedPointerVectorPtrType(comptime Elem: type, comptime ALIGN: ?usize, comptime CONST: bool, comptime LEN: anytype) type {
    if (ALIGN) |a| {
        return if (CONST) *align(a) const @Vector(LEN, Elem) else *align(a) @Vector(LEN, Elem);
    } else {
        return if (CONST) *const @Vector(LEN, Elem) else *@Vector(LEN, Elem);
    }
}

fn TypedPointerNormalizeAlign(comptime ALIGN: anytype) ?usize {
    const T = @TypeOf(ALIGN);
    if (T == @TypeOf(null)) return null;
    if (T == comptime_int) return ALIGN;
    if (T == usize) return ALIGN;
    if (T == ?usize) return ALIGN;
    if (T == PowerOf2) return ALIGN.value_as_type(usize);
    if (T == ?PowerOf2) return if (ALIGN) |p| p.value_as_type(usize) else null;
    if (T == mem.Alignment) return ALIGN.toByteUnits();
    if (T == ?mem.Alignment) return if (ALIGN) |a| a.toByteUnits() else null;
    if (T == AlignmentSource) return ALIGN.calc();
    if (T == ?AlignmentSource) return if (ALIGN) |a| a.calc() else null;
    @compileError("unsupported alignment type: " ++ @typeName(T));
}

fn TypedPointerAddrOf(comptime Self: type) type {
    return Self.Addr;
}
fn TypedPointerElemOf(comptime Self: type) type {
    return Self.Element;
}
fn TypedPointerPtrOf(comptime Self: type, comptime CONST: bool) type {
    return TypedPointerPtrType(Self.Element, Self.ALIGN, CONST);
}
fn TypedPointerManyPtrOf(comptime Self: type, comptime CONST: bool) type {
    return TypedPointerManyPtrType(Self.Element, Self.ALIGN, CONST);
}
fn TypedPointerSliceOf(comptime Self: type, comptime CONST: bool) type {
    return TypedPointerSliceType(Self.Element, Self.ALIGN, CONST);
}
fn TypedPointerArrayPtrOf(comptime Self: type, comptime CONST: bool, comptime LEN: anytype) type {
    return TypedPointerArrayPtrType(Self.Element, Self.ALIGN, CONST, LEN);
}
fn TypedPointerVectorPtrOf(comptime Self: type, comptime CONST: bool, comptime LEN: anytype) type {
    return TypedPointerVectorPtrType(Self.Element, Self.ALIGN, CONST, LEN);
}
fn TypedPointerVoidPtrOf(comptime Self: type) type {
    return if (Self.MUTABILITY == .CONST_PTR) *const anyopaque else *anyopaque;
}
fn TypedPointerOptionalVoidPtrOf(comptime Self: type) type {
    return if (Self.MUTABILITY == .CONST_PTR) ?*const anyopaque else ?*anyopaque;
}

/// The actual implementations used by the typed wrappers below.
///
/// These are generic over the wrapper type so that the wrappers can pick and choose
/// which operations are exposed for their mode (mutable/const, nullable/non-null, aligned/unaligned).
const TypedMethods = struct {
    //***********
    // CASTS
    //***********
    pub fn cast_to(
        self_ptr: anytype,
        comptime NULLABILITY: Nullability,
        comptime MUTABILITY: Mutability,
        comptime T: type,
        comptime ALIGN: anytype,
    ) PointerWithProperties(@TypeOf(self_ptr.*).Source, NULLABILITY, MUTABILITY, T, TypedPointerNormalizeAlign(ALIGN)) {
        return self_ptr.opq.cast_to(NULLABILITY, MUTABILITY, T, ALIGN);
    }
    pub fn to_const(self_ptr: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        @TypeOf(self_ptr.*).NULLABILITY,
        .CONST_PTR,
        @TypeOf(self_ptr.*).Element,
        @TypeOf(self_ptr.*).ALIGN,
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(Self.NULLABILITY, .CONST_PTR, Self.Element, Self.ALIGN);
    }
    pub fn to_align(self_ptr: anytype, comptime ALIGN: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        @TypeOf(self_ptr.*).NULLABILITY,
        @TypeOf(self_ptr.*).MUTABILITY,
        @TypeOf(self_ptr.*).Element,
        TypedPointerNormalizeAlign(ALIGN),
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(Self.NULLABILITY, Self.MUTABILITY, Self.Element, ALIGN);
    }
    pub fn to_nullable(self_ptr: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        .NULLABLE,
        @TypeOf(self_ptr.*).MUTABILITY,
        @TypeOf(self_ptr.*).Element,
        @TypeOf(self_ptr.*).ALIGN,
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(.NULLABLE, Self.MUTABILITY, Self.Element, Self.ALIGN);
    }

    //***********
    // NULL CHECKS
    //***********
    pub fn is_null(self_ptr: anytype) bool {
        return self_ptr.opq.is_null();
    }
    pub fn not_null(self_ptr: anytype) bool {
        return self_ptr.opq.not_null();
    }
    pub fn assert_not_null(self_ptr: anytype, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_not_null(src);
    }
    pub fn assert_null(self_ptr: anytype, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_null(src);
    }

    //***********
    // ALIGNMENT
    //***********
    pub fn is_aligned(self_ptr: anytype, alignment: usize) bool {
        return self_ptr.opq.is_aligned(alignment);
    }
    pub fn is_aligned_any(self_ptr: anytype, alignment: usize) bool {
        return self_ptr.opq.is_aligned_any(alignment);
    }
    pub fn is_aligned_log_2(self_ptr: anytype, alignment_log_2: u8) bool {
        return self_ptr.opq.is_aligned_log_2(alignment_log_2);
    }
    pub fn is_aligned_pow_2(self_ptr: anytype, alignment_pow_2: PowerOf2) bool {
        return self_ptr.opq.is_aligned_pow_2(alignment_pow_2);
    }
    pub fn is_aligned_std_mem(self_ptr: anytype, alignment: mem.Alignment) bool {
        return self_ptr.opq.is_aligned_std_mem(alignment);
    }
    pub fn assert_aligned(self_ptr: anytype, alignment: usize, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_aligned(alignment, src);
    }
    pub fn assert_aligned_any(self_ptr: anytype, alignment: usize, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_aligned_any(alignment, src);
    }
    pub fn assert_aligned_log_2(self_ptr: anytype, alignment_log_2: u8, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_aligned_log_2(alignment_log_2, src);
    }
    pub fn assert_aligned_pow_2(self_ptr: anytype, alignment_pow_2: PowerOf2, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_aligned_pow_2(alignment_pow_2, src);
    }
    pub fn assert_aligned_std_mem(self_ptr: anytype, alignment: mem.Alignment, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_aligned_std_mem(alignment, src);
    }

    //**********************
    // MUTABLE PTR
    //**********************
    pub fn ptr_mut(self_ptr: anytype) TypedPointerPtrOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.ptr_aligned(Self.Element, a) else self_ptr.opq.ptr(Self.Element);
    }
    pub fn ptr_many_mut(self_ptr: anytype) TypedPointerManyPtrOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.ptr_many_aligned(Self.Element, a) else self_ptr.opq.ptr_many(Self.Element);
    }
    pub fn slice_mut(self_ptr: anytype, len: anytype) TypedPointerSliceOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.slice_aligned(Self.Element, a, len) else self_ptr.opq.slice(Self.Element, len);
    }
    pub fn array_ptr_mut(self_ptr: anytype, comptime LEN: anytype) TypedPointerArrayPtrOf(@TypeOf(self_ptr.*), false, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.array_ptr_aligned(Self.Element, a, LEN) else self_ptr.opq.array_ptr(Self.Element, LEN);
    }
    pub fn vector_ptr_mut(self_ptr: anytype, comptime LEN: anytype) TypedPointerVectorPtrOf(@TypeOf(self_ptr.*), false, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.vector_ptr_aligned(Self.Element, a, LEN) else self_ptr.opq.vector_ptr(Self.Element, LEN);
    }

    //**********************
    // CONST PTR
    //**********************
    pub fn ptr_const(self_ptr: anytype) TypedPointerPtrOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_ptr_aligned(Self.Element, a) else self_ptr.opq.const_ptr(Self.Element);
    }
    pub fn ptr_many_const(self_ptr: anytype) TypedPointerManyPtrOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_ptr_many_aligned(Self.Element, a) else self_ptr.opq.const_ptr_many(Self.Element);
    }
    pub fn slice_const(self_ptr: anytype, len: anytype) TypedPointerSliceOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_slice_aligned(Self.Element, a, len) else self_ptr.opq.const_slice(Self.Element, len);
    }
    pub fn array_ptr_const(self_ptr: anytype, comptime LEN: anytype) TypedPointerArrayPtrOf(@TypeOf(self_ptr.*), true, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_array_ptr_aligned(Self.Element, a, LEN) else self_ptr.opq.const_array_ptr(Self.Element, LEN);
    }
    pub fn vector_ptr_const(self_ptr: anytype, comptime LEN: anytype) TypedPointerVectorPtrOf(@TypeOf(self_ptr.*), true, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_vector_ptr_aligned(Self.Element, a, LEN) else self_ptr.opq.const_vector_ptr(Self.Element, LEN);
    }

    //**********************
    // NULLABLE MUTABLE PTR
    //**********************
    pub fn ptr_mut_or_null(self_ptr: anytype) ?TypedPointerPtrOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.ptr_aligned_or_null(Self.Element, a) else self_ptr.opq.ptr_or_null(Self.Element);
    }
    pub fn ptr_many_mut_or_null(self_ptr: anytype) ?TypedPointerManyPtrOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.ptr_many_aligned_or_null(Self.Element, a) else self_ptr.opq.ptr_many_or_null(Self.Element);
    }
    pub fn slice_mut_or_null(self_ptr: anytype, len: anytype) ?TypedPointerSliceOf(@TypeOf(self_ptr.*), false) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.slice_aligned_or_null(Self.Element, a, len) else self_ptr.opq.slice_or_null(Self.Element, len);
    }
    pub fn array_ptr_mut_or_null(self_ptr: anytype, comptime LEN: anytype) ?TypedPointerArrayPtrOf(@TypeOf(self_ptr.*), false, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.array_ptr_aligned_or_null(Self.Element, a, LEN) else self_ptr.opq.array_ptr_or_null(Self.Element, LEN);
    }
    pub fn vector_ptr_mut_or_null(self_ptr: anytype, comptime LEN: anytype) ?TypedPointerVectorPtrOf(@TypeOf(self_ptr.*), false, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.vector_ptr_aligned_or_null(Self.Element, a, LEN) else self_ptr.opq.vector_ptr_or_null(Self.Element, LEN);
    }

    //**********************
    // NULLABLE CONST PTR
    //**********************
    pub fn ptr_const_or_null(self_ptr: anytype) ?TypedPointerPtrOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_ptr_aligned_or_null(Self.Element, a) else self_ptr.opq.const_ptr_or_null(Self.Element);
    }
    pub fn ptr_many_const_or_null(self_ptr: anytype) ?TypedPointerManyPtrOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_ptr_many_aligned_or_null(Self.Element, a) else self_ptr.opq.const_ptr_many_or_null(Self.Element);
    }
    pub fn slice_const_or_null(self_ptr: anytype, len: anytype) ?TypedPointerSliceOf(@TypeOf(self_ptr.*), true) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_slice_aligned_or_null(Self.Element, a, len) else self_ptr.opq.const_slice_or_null(Self.Element, len);
    }
    pub fn array_ptr_const_or_null(self_ptr: anytype, comptime LEN: anytype) ?TypedPointerArrayPtrOf(@TypeOf(self_ptr.*), true, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_array_ptr_aligned_or_null(Self.Element, a, LEN) else self_ptr.opq.const_array_ptr_or_null(Self.Element, LEN);
    }
    pub fn vector_ptr_const_or_null(self_ptr: anytype, comptime LEN: anytype) ?TypedPointerVectorPtrOf(@TypeOf(self_ptr.*), true, LEN) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.ALIGN) |a| self_ptr.opq.const_vector_ptr_aligned_or_null(Self.Element, a, LEN) else self_ptr.opq.const_vector_ptr_or_null(Self.Element, LEN);
    }

    //***********
    // GET / SET
    //***********
    pub fn get(self_ptr: anytype) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get(Self.Element);
    }
    pub fn get_or_null(self_ptr: anytype) ?TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_or_null(Self.Element);
    }
    pub fn get_orelse(self_ptr: anytype, default: TypedPointerElemOf(@TypeOf(self_ptr.*))) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_orelse(Self.Element, default);
    }
    pub fn get_at_index(self_ptr: anytype, index: usize) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_at_index(Self.Element, index);
    }
    pub fn get_at_index_or_null(self_ptr: anytype, index: usize) ?TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_at_index_or_null(Self.Element, index);
    }
    pub fn get_at_index_orelse(self_ptr: anytype, index: usize, default: TypedPointerElemOf(@TypeOf(self_ptr.*))) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_at_index_orelse(Self.Element, index, default);
    }
    pub fn set(self_ptr: anytype, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.set(Self.Element, val);
    }
    pub fn set_if_not_null(self_ptr: anytype, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.set_if_not_null(Self.Element, val);
    }
    pub fn set_if_not_null_return_ptr_is_NOT_null(self_ptr: anytype, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) bool {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.set_if_not_null_return_ptr_is_NOT_null(Self.Element, val);
    }
    pub fn set_if_not_null_return_ptr_IS_null(self_ptr: anytype, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) bool {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.set_if_not_null_return_ptr_IS_null(Self.Element, val);
    }
    pub fn set_at_index(self_ptr: anytype, index: usize, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.set_at_index(Self.Element, index, val);
    }
    pub fn set_at_index_if_not_null(self_ptr: anytype, index: usize, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.set_at_index_if_not_null(Self.Element, index, val);
    }
    pub fn set_at_index_if_not_null_return_ptr_is_NOT_null(self_ptr: anytype, index: usize, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) bool {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.set_at_index_if_not_null_return_ptr_is_NOT_null(Self.Element, index, val);
    }
    pub fn set_at_index_if_not_null_return_ptr_IS_null(self_ptr: anytype, index: usize, val: TypedPointerElemOf(@TypeOf(self_ptr.*))) bool {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.set_at_index_if_not_null_return_ptr_IS_null(Self.Element, index, val);
    }

    //**************************
    // ADDRESS ADD / SUB / MOVE
    //**************************
    pub fn add(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_add(Self.Element, offset) };
    }
    pub fn add_in_place(self_ptr: anytype, offset: usize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_add_in_place(Self.Element, offset);
    }
    pub fn add_assert_contiguous(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_add_assert_contiguous(Self.Element, offset) };
    }
    pub fn add_in_place_assert_contiguous(self_ptr: anytype, offset: usize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_add_in_place_assert_contiguous(Self.Element, offset);
    }
    pub fn subtract(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_subtract(Self.Element, offset) };
    }
    pub fn subtract_in_place(self_ptr: anytype, offset: usize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_subtract_in_place(Self.Element, offset);
    }
    pub fn subtract_assert_contiguous(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_subtract_assert_contiguous(Self.Element, offset) };
    }
    pub fn subtract_in_place_assert_contiguous(self_ptr: anytype, offset: usize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_subtract_in_place_assert_contiguous(Self.Element, offset);
    }
    pub fn move(self_ptr: anytype, offset: isize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_move(Self.Element, offset) };
    }
    pub fn move_in_place(self_ptr: anytype, offset: isize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_move_in_place(Self.Element, offset);
    }
    pub fn move_assert_contiguous(self_ptr: anytype, offset: isize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_move_assert_contiguous(Self.Element, offset) };
    }
    pub fn move_in_place_assert_contiguous(self_ptr: anytype, offset: isize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.typed_move_in_place_assert_contiguous(Self.Element, offset);
    }

    //**************************
    // ELEMENTS BETWEEN (NON-NULL)
    //**************************
    pub fn elements_between_self_low_other_high_exclude(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_exclude(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_exclude(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_exclude(other.opq, Self.Element);
    }
    pub fn elements_between_self_low_other_high_include(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_include(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_include(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_include(other.opq, Self.Element);
    }
    pub fn elements_between_exclude_high(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_exclude_high(other.opq, Self.Element);
    }
    pub fn elements_between_include_high(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_include_high(other.opq, Self.Element);
    }

    //**************************
    // ELEMENTS BETWEEN (NULLABLE)
    //**************************
    pub fn elements_between_self_low_other_high_exclude_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_exclude_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_self_low_other_high_exclude_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_exclude_orelse_0(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_exclude_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_exclude_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_exclude_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_exclude_orelse_0(other.opq, Self.Element);
    }
    pub fn elements_between_self_low_other_high_include_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_include_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_self_low_other_high_include_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_low_other_high_include_orelse_0(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_include_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_include_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_self_high_other_low_include_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_self_high_other_low_include_orelse_0(other.opq, Self.Element);
    }
    pub fn elements_between_exclude_high_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_exclude_high_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_exclude_high_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_exclude_high_orelse_0(other.opq, Self.Element);
    }
    pub fn elements_between_include_high_or_null(self_ptr: anytype, other: anytype) ?usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_include_high_or_null(other.opq, Self.Element);
    }
    pub fn elements_between_include_high_orelse_0(self_ptr: anytype, other: anytype) usize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_between_include_high_orelse_0(other.opq, Self.Element);
    }

    //**************************
    // RANGES
    //**************************
    pub fn is_within_range_exclude_high(self_ptr: anytype, low: anytype, high: anytype) bool {
        return self_ptr.opq.is_within_range_exclude_high(low.opq, high.opq);
    }
    pub fn is_within_range_include_high(self_ptr: anytype, low: anytype, high: anytype) bool {
        return self_ptr.opq.is_within_range_include_high(low.opq, high.opq);
    }
    pub fn assert_is_within_range_exclude_high(self_ptr: anytype, low: anytype, high: anytype, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_is_within_range_exclude_high(low.opq, high.opq, src);
    }
    pub fn assert_is_within_range_include_high(self_ptr: anytype, low: anytype, high: anytype, comptime src: ?SourceLocation) void {
        self_ptr.opq.assert_is_within_range_include_high(low.opq, high.opq, src);
    }

    //**************************
    // ADDRESS INTROSPECTION
    //**************************
    pub fn local_addr(self_ptr: anytype) TypedPointerAddrOf(@TypeOf(self_ptr.*)) {
        return self_ptr.opq.local_addr();
    }
    pub fn resolved_addr(self_ptr: anytype) usize {
        return self_ptr.opq.resolved_addr();
    }
    pub fn resolved_addr_or_null(self_ptr: anytype) ?usize {
        return self_ptr.opq.resolved_addr_or_null();
    }

    //**************************
    // COMPARISON / HASHING
    //**************************
    pub fn eql(self_ptr: anytype, other: anytype) bool {
        return self_ptr.opq.eql(other.opq);
    }
    pub fn eql_native(self_ptr: anytype, native_ptr: anytype) bool {
        return self_ptr.opq.eql_native(native_ptr);
    }
    pub fn eql_local(self_ptr: anytype, other: anytype) bool {
        return self_ptr.opq.eql_local(other.opq);
    }
    pub fn order(self_ptr: anytype, other: anytype) std.math.Order {
        return self_ptr.opq.order(other.opq);
    }
    pub fn hash(self_ptr: anytype) u64 {
        return self_ptr.opq.hash();
    }
    pub fn simple_hash(self_ptr: anytype) u64 {
        return self_ptr.opq.simple_hash();
    }

    //**************************
    // SOURCE INTROSPECTION
    //**************************
    pub fn source_kind(self_ptr: anytype) PointerSourceKind {
        return self_ptr.opq.source_kind();
    }
    pub fn is_native(self_ptr: anytype) bool {
        return self_ptr.opq.is_native();
    }
    pub fn is_global_resolver(self_ptr: anytype) bool {
        return self_ptr.opq.is_global_resolver();
    }

    //**************************
    // SIGNED DISTANCE
    //**************************
    pub fn bytes_from(self_ptr: anytype, other: anytype) isize {
        return self_ptr.opq.bytes_from(other.opq);
    }
    pub fn elements_from(self_ptr: anytype, other: anytype) isize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_from(other.opq, Self.Element);
    }
    pub fn offset_from(self_ptr: anytype, other: anytype) isize {
        return self_ptr.opq.offset_from(other.opq);
    }
    pub fn bytes_from_or_null(self_ptr: anytype, other: anytype) ?isize {
        return self_ptr.opq.bytes_from_or_null(other.opq);
    }
    pub fn bytes_from_orelse_0(self_ptr: anytype, other: anytype) isize {
        return self_ptr.opq.bytes_from_orelse_0(other.opq);
    }
    pub fn elements_from_or_null(self_ptr: anytype, other: anytype) ?isize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_from_or_null(other.opq, Self.Element);
    }
    pub fn elements_from_orelse_0(self_ptr: anytype, other: anytype) isize {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.elements_from_orelse_0(other.opq, Self.Element);
    }
    pub fn offset_from_or_null(self_ptr: anytype, other: anytype) ?isize {
        return self_ptr.opq.offset_from_or_null(other.opq);
    }
    pub fn offset_from_orelse_0(self_ptr: anytype, other: anytype) isize {
        return self_ptr.opq.offset_from_orelse_0(other.opq);
    }

    //**************************
    // NULL-PRESERVING ARITHMETIC
    //**************************
    pub fn add_or_null(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_add_or_null(Self.Element, offset) };
    }
    pub fn subtract_or_null(self_ptr: anytype, offset: usize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_subtract_or_null(Self.Element, offset) };
    }
    pub fn move_or_null(self_ptr: anytype, offset: isize) @TypeOf(self_ptr.*) {
        const Self = @TypeOf(self_ptr.*);
        return Self{ .opq = self_ptr.opq.typed_move_or_null(Self.Element, offset) };
    }

    //**************************
    // ADDITIONAL CASTS
    //**************************
    pub fn to_non_null(self_ptr: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        .NEVER_NULL,
        @TypeOf(self_ptr.*).MUTABILITY,
        @TypeOf(self_ptr.*).Element,
        @TypeOf(self_ptr.*).ALIGN,
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(.NEVER_NULL, Self.MUTABILITY, Self.Element, Self.ALIGN);
    }
    pub fn to_unaligned(self_ptr: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        @TypeOf(self_ptr.*).NULLABILITY,
        @TypeOf(self_ptr.*).MUTABILITY,
        @TypeOf(self_ptr.*).Element,
        null,
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(Self.NULLABILITY, Self.MUTABILITY, Self.Element, null);
    }
    pub fn to_mutable(self_ptr: anytype) PointerWithProperties(
        @TypeOf(self_ptr.*).Source,
        @TypeOf(self_ptr.*).NULLABILITY,
        .MUT_PTR,
        @TypeOf(self_ptr.*).Element,
        @TypeOf(self_ptr.*).ALIGN,
    ) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.cast_to(Self.NULLABILITY, .MUT_PTR, Self.Element, Self.ALIGN);
    }

    //**************************
    // NULL CONSTRUCTION / MUTATION
    //**************************
    pub fn set_null(self_ptr: anytype) void {
        self_ptr.opq.set_null();
    }
    pub fn is_null_or_equal(self_ptr: anytype, other: anytype) bool {
        return self_ptr.opq.is_null_or_equal(other.opq);
    }

    //**************************
    // BULK OPERATIONS
    //**************************
    pub fn memcopy_to(self_ptr: anytype, dst: []TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.memcopy_to(Self.Element, dst);
    }
    pub fn memcopy_from(self_ptr: anytype, src: []const TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.memcopy_from(Self.Element, src);
    }
    pub fn memmove_to(self_ptr: anytype, dst: []TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.memmove_to(Self.Element, dst);
    }
    pub fn memmove_from(self_ptr: anytype, src: []const TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.memmove_from(Self.Element, src);
    }
    pub fn memset(self_ptr: anytype, value: TypedPointerElemOf(@TypeOf(self_ptr.*)), len: usize) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.memset(Self.Element, value, len);
    }

    //**************************
    // BYTE ACCESS
    //**************************
    pub fn bytes(self_ptr: anytype, len: anytype) []u8 {
        return self_ptr.opq.bytes(len);
    }
    pub fn const_bytes(self_ptr: anytype, len: anytype) []const u8 {
        return self_ptr.opq.const_bytes(len);
    }

    //**************************
    // VOLATILE ACCESS
    //**************************
    pub fn get_volatile(self_ptr: anytype) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.get_volatile(Self.Element);
    }
    pub fn set_volatile(self_ptr: anytype, value: TypedPointerElemOf(@TypeOf(self_ptr.*))) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.set_volatile(Self.Element, value);
    }

    //**************************
    // ATOMIC ACCESS
    //**************************
    pub fn atomic_load(self_ptr: anytype, comptime ordering: std.lang.AtomicOrder) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.atomic_load(Self.Element, ordering);
    }
    pub fn atomic_store(self_ptr: anytype, value: TypedPointerElemOf(@TypeOf(self_ptr.*)), comptime ordering: std.lang.AtomicOrder) void {
        const Self = @TypeOf(self_ptr.*);
        self_ptr.opq.atomic_store(Self.Element, value, ordering);
    }
    pub fn atomic_read_modify_write(self_ptr: anytype, comptime op: std.lang.AtomicRmwOp, value: TypedPointerElemOf(@TypeOf(self_ptr.*)), comptime ordering: std.lang.AtomicOrder) TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.atomic_read_modify_write(Self.Element, op, value, ordering);
    }
    pub fn atomic_compare_exchange_strong(self_ptr: anytype, expected: TypedPointerElemOf(@TypeOf(self_ptr.*)), new_value: TypedPointerElemOf(@TypeOf(self_ptr.*)), comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.atomic_compare_exchange_strong(Self.Element, expected, new_value, success_order, fail_order);
    }
    pub fn atomic_compare_exchange_weak(self_ptr: anytype, expected: TypedPointerElemOf(@TypeOf(self_ptr.*)), new_value: TypedPointerElemOf(@TypeOf(self_ptr.*)), comptime success_order: std.lang.AtomicOrder, comptime fail_order: std.lang.AtomicOrder) ?TypedPointerElemOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return self_ptr.opq.atomic_compare_exchange_weak(Self.Element, expected, new_value, success_order, fail_order);
    }

    //**************************
    // VOID POINTER CONVERSION
    //**************************
    pub fn to_anyopaque(self_ptr: anytype) TypedPointerVoidPtrOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.MUTABILITY == .CONST_PTR) self_ptr.opq.to_const_anyopaque() else self_ptr.opq.to_anyopaque();
    }
    pub fn to_anyopaque_or_null(self_ptr: anytype) TypedPointerOptionalVoidPtrOf(@TypeOf(self_ptr.*)) {
        const Self = @TypeOf(self_ptr.*);
        return if (comptime Self.MUTABILITY == .CONST_PTR) self_ptr.opq.to_const_anyopaque_or_null() else self_ptr.opq.to_anyopaque_or_null();
    }
};

pub fn Pointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = null;
        pub const NULLABILITY: Nullability = .NEVER_NULL;
        pub const MUTABILITY: Mutability = .MUT_PTR;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const ptr = TypedMethods.ptr_mut;
        pub const ptr_many = TypedMethods.ptr_many_mut;
        pub const slice = TypedMethods.slice_mut;
        pub const array_ptr = TypedMethods.array_ptr_mut;
        pub const vector_ptr = TypedMethods.vector_ptr_mut;

        // GET / SET
        pub const get = TypedMethods.get;
        pub const get_at_index = TypedMethods.get_at_index;
        pub const set = TypedMethods.set;
        pub const set_at_index = TypedMethods.set_at_index;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude = TypedMethods.elements_between_self_low_other_high_exclude;
        pub const elements_between_self_high_other_low_exclude = TypedMethods.elements_between_self_high_other_low_exclude;
        pub const elements_between_self_low_other_high_include = TypedMethods.elements_between_self_low_other_high_include;
        pub const elements_between_self_high_other_low_include = TypedMethods.elements_between_self_high_other_low_include;
        pub const elements_between_exclude_high = TypedMethods.elements_between_exclude_high;
        pub const elements_between_include_high = TypedMethods.elements_between_include_high;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
            return Self{ .opq = .from_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // BULK WRITE
        pub const memcopy_from = TypedMethods.memcopy_from;
        pub const memmove_from = TypedMethods.memmove_from;
        pub const memset = TypedMethods.memset;
        pub const bytes = TypedMethods.bytes;

        // VOLATILE / ATOMIC WRITE
        pub const set_volatile = TypedMethods.set_volatile;
        pub const atomic_store = TypedMethods.atomic_store;
        pub const atomic_read_modify_write = TypedMethods.atomic_read_modify_write;
        pub const atomic_compare_exchange_strong = TypedMethods.atomic_compare_exchange_strong;
        pub const atomic_compare_exchange_weak = TypedMethods.atomic_compare_exchange_weak;
    };
}

pub fn NullablePointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = null;
        pub const NULLABILITY: Nullability = .NULLABLE;
        pub const MUTABILITY: Mutability = .MUT_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // NULL CHECKS
        pub const is_null = TypedMethods.is_null;
        pub const not_null = TypedMethods.not_null;
        pub const assert_not_null = TypedMethods.assert_not_null;
        pub const assert_null = TypedMethods.assert_null;

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const ptr_or_null = TypedMethods.ptr_mut_or_null;
        pub const ptr_many_or_null = TypedMethods.ptr_many_mut_or_null;
        pub const slice_or_null = TypedMethods.slice_mut_or_null;
        pub const array_ptr_or_null = TypedMethods.array_ptr_mut_or_null;
        pub const vector_ptr_or_null = TypedMethods.vector_ptr_mut_or_null;

        // GET / SET
        pub const get_or_null = TypedMethods.get_or_null;
        pub const get_orelse = TypedMethods.get_orelse;
        pub const get_at_index_or_null = TypedMethods.get_at_index_or_null;
        pub const get_at_index_orelse = TypedMethods.get_at_index_orelse;
        pub const set_if_not_null = TypedMethods.set_if_not_null;
        pub const set_if_not_null_return_ptr_is_NOT_null = TypedMethods.set_if_not_null_return_ptr_is_NOT_null;
        pub const set_if_not_null_return_ptr_IS_null = TypedMethods.set_if_not_null_return_ptr_IS_null;
        pub const set_at_index_if_not_null = TypedMethods.set_at_index_if_not_null;
        pub const set_at_index_if_not_null_return_ptr_is_NOT_null = TypedMethods.set_at_index_if_not_null_return_ptr_is_NOT_null;
        pub const set_at_index_if_not_null_return_ptr_IS_null = TypedMethods.set_at_index_if_not_null_return_ptr_IS_null;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude_or_null = TypedMethods.elements_between_self_low_other_high_exclude_or_null;
        pub const elements_between_self_low_other_high_exclude_orelse_0 = TypedMethods.elements_between_self_low_other_high_exclude_orelse_0;
        pub const elements_between_self_high_other_low_exclude_or_null = TypedMethods.elements_between_self_high_other_low_exclude_or_null;
        pub const elements_between_self_high_other_low_exclude_orelse_0 = TypedMethods.elements_between_self_high_other_low_exclude_orelse_0;
        pub const elements_between_self_low_other_high_include_or_null = TypedMethods.elements_between_self_low_other_high_include_or_null;
        pub const elements_between_self_low_other_high_include_orelse_0 = TypedMethods.elements_between_self_low_other_high_include_orelse_0;
        pub const elements_between_self_high_other_low_include_or_null = TypedMethods.elements_between_self_high_other_low_include_or_null;
        pub const elements_between_self_high_other_low_include_orelse_0 = TypedMethods.elements_between_self_high_other_low_include_orelse_0;
        pub const elements_between_exclude_high_or_null = TypedMethods.elements_between_exclude_high_or_null;
        pub const elements_between_exclude_high_orelse_0 = TypedMethods.elements_between_exclude_high_orelse_0;
        pub const elements_between_include_high_or_null = TypedMethods.elements_between_include_high_or_null;
        pub const elements_between_include_high_orelse_0 = TypedMethods.elements_between_include_high_orelse_0;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn new_null() Self {
            return Self{ .opq = .new_null() };
        }

        pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
            return Self{ .opq = .from_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // SIGNED DISTANCE (NULLABLE)
        pub const bytes_from_or_null = TypedMethods.bytes_from_or_null;
        pub const bytes_from_orelse_0 = TypedMethods.bytes_from_orelse_0;
        pub const elements_from_or_null = TypedMethods.elements_from_or_null;
        pub const elements_from_orelse_0 = TypedMethods.elements_from_orelse_0;
        pub const offset_from_or_null = TypedMethods.offset_from_or_null;
        pub const offset_from_orelse_0 = TypedMethods.offset_from_orelse_0;

        // NULL-PRESERVING ARITHMETIC
        pub const add_or_null = TypedMethods.add_or_null;
        pub const subtract_or_null = TypedMethods.subtract_or_null;
        pub const move_or_null = TypedMethods.move_or_null;

        // NULL CONSTRUCTION / MUTATION
        pub const set_null = TypedMethods.set_null;
        pub const is_null_or_equal = TypedMethods.is_null_or_equal;

        // ADDITIONAL CASTS
        pub const to_non_null = TypedMethods.to_non_null;

        // VOID POINTER
        pub const to_anyopaque_or_null = TypedMethods.to_anyopaque_or_null;

        // BULK WRITE
        pub const memcopy_from = TypedMethods.memcopy_from;
        pub const memmove_from = TypedMethods.memmove_from;
        pub const memset = TypedMethods.memset;
        pub const bytes = TypedMethods.bytes;

        // VOLATILE / ATOMIC WRITE
        pub const set_volatile = TypedMethods.set_volatile;
        pub const atomic_store = TypedMethods.atomic_store;
        pub const atomic_read_modify_write = TypedMethods.atomic_read_modify_write;
        pub const atomic_compare_exchange_strong = TypedMethods.atomic_compare_exchange_strong;
        pub const atomic_compare_exchange_weak = TypedMethods.atomic_compare_exchange_weak;
    };
}

pub fn ConstPointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = null;
        pub const NULLABILITY: Nullability = .NEVER_NULL;
        pub const MUTABILITY: Mutability = .CONST_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *const T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const const_ptr = TypedMethods.ptr_const;
        pub const const_ptr_many = TypedMethods.ptr_many_const;
        pub const const_slice = TypedMethods.slice_const;
        pub const const_array_ptr = TypedMethods.array_ptr_const;
        pub const const_vector_ptr = TypedMethods.vector_ptr_const;

        // GET
        pub const get = TypedMethods.get;
        pub const get_at_index = TypedMethods.get_at_index;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude = TypedMethods.elements_between_self_low_other_high_exclude;
        pub const elements_between_self_high_other_low_exclude = TypedMethods.elements_between_self_high_other_low_exclude;
        pub const elements_between_self_low_other_high_include = TypedMethods.elements_between_self_low_other_high_include;
        pub const elements_between_self_high_other_low_include = TypedMethods.elements_between_self_high_other_low_include;
        pub const elements_between_exclude_high = TypedMethods.elements_between_exclude_high;
        pub const elements_between_include_high = TypedMethods.elements_between_include_high;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn from_anyopaque(void_ptr: *const anyopaque) Self {
            return Self{ .opq = .from_const_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // ADDITIONAL CASTS
        pub const to_mutable = TypedMethods.to_mutable;
    };
}

pub fn NullableConstPointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = null;
        pub const NULLABILITY: Nullability = .NULLABLE;
        pub const MUTABILITY: Mutability = .CONST_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *const T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // NULL CHECKS
        pub const is_null = TypedMethods.is_null;
        pub const not_null = TypedMethods.not_null;
        pub const assert_not_null = TypedMethods.assert_not_null;
        pub const assert_null = TypedMethods.assert_null;

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const const_ptr_or_null = TypedMethods.ptr_const_or_null;
        pub const const_ptr_many_or_null = TypedMethods.ptr_many_const_or_null;
        pub const const_slice_or_null = TypedMethods.slice_const_or_null;
        pub const const_array_ptr_or_null = TypedMethods.array_ptr_const_or_null;
        pub const const_vector_ptr_or_null = TypedMethods.vector_ptr_const_or_null;

        // GET
        pub const get_or_null = TypedMethods.get_or_null;
        pub const get_orelse = TypedMethods.get_orelse;
        pub const get_at_index_or_null = TypedMethods.get_at_index_or_null;
        pub const get_at_index_orelse = TypedMethods.get_at_index_orelse;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude_or_null = TypedMethods.elements_between_self_low_other_high_exclude_or_null;
        pub const elements_between_self_low_other_high_exclude_orelse_0 = TypedMethods.elements_between_self_low_other_high_exclude_orelse_0;
        pub const elements_between_self_high_other_low_exclude_or_null = TypedMethods.elements_between_self_high_other_low_exclude_or_null;
        pub const elements_between_self_high_other_low_exclude_orelse_0 = TypedMethods.elements_between_self_high_other_low_exclude_orelse_0;
        pub const elements_between_self_low_other_high_include_or_null = TypedMethods.elements_between_self_low_other_high_include_or_null;
        pub const elements_between_self_low_other_high_include_orelse_0 = TypedMethods.elements_between_self_low_other_high_include_orelse_0;
        pub const elements_between_self_high_other_low_include_or_null = TypedMethods.elements_between_self_high_other_low_include_or_null;
        pub const elements_between_self_high_other_low_include_orelse_0 = TypedMethods.elements_between_self_high_other_low_include_orelse_0;
        pub const elements_between_exclude_high_or_null = TypedMethods.elements_between_exclude_high_or_null;
        pub const elements_between_exclude_high_orelse_0 = TypedMethods.elements_between_exclude_high_orelse_0;
        pub const elements_between_include_high_or_null = TypedMethods.elements_between_include_high_or_null;
        pub const elements_between_include_high_orelse_0 = TypedMethods.elements_between_include_high_orelse_0;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn new_null() Self {
            return Self{ .opq = .new_null() };
        }

        pub inline fn from_anyopaque(void_ptr: *const anyopaque) Self {
            return Self{ .opq = .from_const_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // SIGNED DISTANCE (NULLABLE)
        pub const bytes_from_or_null = TypedMethods.bytes_from_or_null;
        pub const bytes_from_orelse_0 = TypedMethods.bytes_from_orelse_0;
        pub const elements_from_or_null = TypedMethods.elements_from_or_null;
        pub const elements_from_orelse_0 = TypedMethods.elements_from_orelse_0;
        pub const offset_from_or_null = TypedMethods.offset_from_or_null;
        pub const offset_from_orelse_0 = TypedMethods.offset_from_orelse_0;

        // NULL-PRESERVING ARITHMETIC
        pub const add_or_null = TypedMethods.add_or_null;
        pub const subtract_or_null = TypedMethods.subtract_or_null;
        pub const move_or_null = TypedMethods.move_or_null;

        // NULL CONSTRUCTION / MUTATION
        pub const set_null = TypedMethods.set_null;
        pub const is_null_or_equal = TypedMethods.is_null_or_equal;

        // ADDITIONAL CASTS
        pub const to_non_null = TypedMethods.to_non_null;

        // VOID POINTER
        pub const to_anyopaque_or_null = TypedMethods.to_anyopaque_or_null;

        // ADDITIONAL CASTS
        pub const to_mutable = TypedMethods.to_mutable;
    };
}

pub fn PointerAlign(comptime T: type, comptime A: usize, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = A;
        pub const NULLABILITY: Nullability = .NEVER_NULL;
        pub const MUTABILITY: Mutability = .MUT_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *align(A) T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const ptr = TypedMethods.ptr_mut;
        pub const ptr_many = TypedMethods.ptr_many_mut;
        pub const slice = TypedMethods.slice_mut;
        pub const array_ptr = TypedMethods.array_ptr_mut;
        pub const vector_ptr = TypedMethods.vector_ptr_mut;

        // GET / SET
        pub const get = TypedMethods.get;
        pub const get_at_index = TypedMethods.get_at_index;
        pub const set = TypedMethods.set;
        pub const set_at_index = TypedMethods.set_at_index;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude = TypedMethods.elements_between_self_low_other_high_exclude;
        pub const elements_between_self_high_other_low_exclude = TypedMethods.elements_between_self_high_other_low_exclude;
        pub const elements_between_self_low_other_high_include = TypedMethods.elements_between_self_low_other_high_include;
        pub const elements_between_self_high_other_low_include = TypedMethods.elements_between_self_high_other_low_include;
        pub const elements_between_exclude_high = TypedMethods.elements_between_exclude_high;
        pub const elements_between_include_high = TypedMethods.elements_between_include_high;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
            return Self{ .opq = .from_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // ADDITIONAL CASTS
        pub const to_unaligned = TypedMethods.to_unaligned;

        // BULK WRITE
        pub const memcopy_from = TypedMethods.memcopy_from;
        pub const memmove_from = TypedMethods.memmove_from;
        pub const memset = TypedMethods.memset;
        pub const bytes = TypedMethods.bytes;

        // VOLATILE / ATOMIC WRITE
        pub const set_volatile = TypedMethods.set_volatile;
        pub const atomic_store = TypedMethods.atomic_store;
        pub const atomic_read_modify_write = TypedMethods.atomic_read_modify_write;
        pub const atomic_compare_exchange_strong = TypedMethods.atomic_compare_exchange_strong;
        pub const atomic_compare_exchange_weak = TypedMethods.atomic_compare_exchange_weak;
    };
}

pub fn NullablePointerAlign(comptime T: type, comptime A: usize, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = A;
        pub const NULLABILITY: Nullability = .NULLABLE;
        pub const MUTABILITY: Mutability = .MUT_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *align(A) T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // NULL CHECKS
        pub const is_null = TypedMethods.is_null;
        pub const not_null = TypedMethods.not_null;
        pub const assert_not_null = TypedMethods.assert_not_null;
        pub const assert_null = TypedMethods.assert_null;

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const ptr_or_null = TypedMethods.ptr_mut_or_null;
        pub const ptr_many_or_null = TypedMethods.ptr_many_mut_or_null;
        pub const slice_or_null = TypedMethods.slice_mut_or_null;
        pub const array_ptr_or_null = TypedMethods.array_ptr_mut_or_null;
        pub const vector_ptr_or_null = TypedMethods.vector_ptr_mut_or_null;

        // GET / SET
        pub const get_or_null = TypedMethods.get_or_null;
        pub const get_orelse = TypedMethods.get_orelse;
        pub const get_at_index_or_null = TypedMethods.get_at_index_or_null;
        pub const get_at_index_orelse = TypedMethods.get_at_index_orelse;
        pub const set_if_not_null = TypedMethods.set_if_not_null;
        pub const set_if_not_null_return_ptr_is_NOT_null = TypedMethods.set_if_not_null_return_ptr_is_NOT_null;
        pub const set_if_not_null_return_ptr_IS_null = TypedMethods.set_if_not_null_return_ptr_IS_null;
        pub const set_at_index_if_not_null = TypedMethods.set_at_index_if_not_null;
        pub const set_at_index_if_not_null_return_ptr_is_NOT_null = TypedMethods.set_at_index_if_not_null_return_ptr_is_NOT_null;
        pub const set_at_index_if_not_null_return_ptr_IS_null = TypedMethods.set_at_index_if_not_null_return_ptr_IS_null;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude_or_null = TypedMethods.elements_between_self_low_other_high_exclude_or_null;
        pub const elements_between_self_low_other_high_exclude_orelse_0 = TypedMethods.elements_between_self_low_other_high_exclude_orelse_0;
        pub const elements_between_self_high_other_low_exclude_or_null = TypedMethods.elements_between_self_high_other_low_exclude_or_null;
        pub const elements_between_self_high_other_low_exclude_orelse_0 = TypedMethods.elements_between_self_high_other_low_exclude_orelse_0;
        pub const elements_between_self_low_other_high_include_or_null = TypedMethods.elements_between_self_low_other_high_include_or_null;
        pub const elements_between_self_low_other_high_include_orelse_0 = TypedMethods.elements_between_self_low_other_high_include_orelse_0;
        pub const elements_between_self_high_other_low_include_or_null = TypedMethods.elements_between_self_high_other_low_include_or_null;
        pub const elements_between_self_high_other_low_include_orelse_0 = TypedMethods.elements_between_self_high_other_low_include_orelse_0;
        pub const elements_between_exclude_high_or_null = TypedMethods.elements_between_exclude_high_or_null;
        pub const elements_between_exclude_high_orelse_0 = TypedMethods.elements_between_exclude_high_orelse_0;
        pub const elements_between_include_high_or_null = TypedMethods.elements_between_include_high_or_null;
        pub const elements_between_include_high_orelse_0 = TypedMethods.elements_between_include_high_orelse_0;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn new_null() Self {
            return Self{ .opq = .new_null() };
        }

        pub inline fn from_anyopaque(void_ptr: *anyopaque) Self {
            return Self{ .opq = .from_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // SIGNED DISTANCE (NULLABLE)
        pub const bytes_from_or_null = TypedMethods.bytes_from_or_null;
        pub const bytes_from_orelse_0 = TypedMethods.bytes_from_orelse_0;
        pub const elements_from_or_null = TypedMethods.elements_from_or_null;
        pub const elements_from_orelse_0 = TypedMethods.elements_from_orelse_0;
        pub const offset_from_or_null = TypedMethods.offset_from_or_null;
        pub const offset_from_orelse_0 = TypedMethods.offset_from_orelse_0;

        // NULL-PRESERVING ARITHMETIC
        pub const add_or_null = TypedMethods.add_or_null;
        pub const subtract_or_null = TypedMethods.subtract_or_null;
        pub const move_or_null = TypedMethods.move_or_null;

        // NULL CONSTRUCTION / MUTATION
        pub const set_null = TypedMethods.set_null;
        pub const is_null_or_equal = TypedMethods.is_null_or_equal;

        // ADDITIONAL CASTS
        pub const to_non_null = TypedMethods.to_non_null;

        // VOID POINTER
        pub const to_anyopaque_or_null = TypedMethods.to_anyopaque_or_null;

        // ADDITIONAL CASTS
        pub const to_unaligned = TypedMethods.to_unaligned;

        // BULK WRITE
        pub const memcopy_from = TypedMethods.memcopy_from;
        pub const memmove_from = TypedMethods.memmove_from;
        pub const memset = TypedMethods.memset;
        pub const bytes = TypedMethods.bytes;

        // VOLATILE / ATOMIC WRITE
        pub const set_volatile = TypedMethods.set_volatile;
        pub const atomic_store = TypedMethods.atomic_store;
        pub const atomic_read_modify_write = TypedMethods.atomic_read_modify_write;
        pub const atomic_compare_exchange_strong = TypedMethods.atomic_compare_exchange_strong;
        pub const atomic_compare_exchange_weak = TypedMethods.atomic_compare_exchange_weak;
    };
}

pub fn ConstPointerAlign(comptime T: type, comptime A: usize, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = A;
        pub const NULLABILITY: Nullability = .NEVER_NULL;
        pub const MUTABILITY: Mutability = .CONST_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *align(A) const T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const const_ptr = TypedMethods.ptr_const;
        pub const const_ptr_many = TypedMethods.ptr_many_const;
        pub const const_slice = TypedMethods.slice_const;
        pub const const_array_ptr = TypedMethods.array_ptr_const;
        pub const const_vector_ptr = TypedMethods.vector_ptr_const;

        // GET
        pub const get = TypedMethods.get;
        pub const get_at_index = TypedMethods.get_at_index;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude = TypedMethods.elements_between_self_low_other_high_exclude;
        pub const elements_between_self_high_other_low_exclude = TypedMethods.elements_between_self_high_other_low_exclude;
        pub const elements_between_self_low_other_high_include = TypedMethods.elements_between_self_low_other_high_include;
        pub const elements_between_self_high_other_low_include = TypedMethods.elements_between_self_high_other_low_include;
        pub const elements_between_exclude_high = TypedMethods.elements_between_exclude_high;
        pub const elements_between_include_high = TypedMethods.elements_between_include_high;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn from_anyopaque(void_ptr: *const anyopaque) Self {
            return Self{ .opq = .from_const_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // ADDITIONAL CASTS
        pub const to_unaligned = TypedMethods.to_unaligned;

        // ADDITIONAL CASTS
        pub const to_mutable = TypedMethods.to_mutable;
    };
}

pub fn NullableConstPointerAlign(comptime T: type, comptime A: usize, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();

        pub const Source = SOURCE;
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;
        pub const Element = T;
        pub const ALIGN: ?usize = A;
        pub const NULLABILITY: Nullability = .NULLABLE;
        pub const MUTABILITY: Mutability = .CONST_PTR;

        pub const cast_to = TypedMethods.cast_to;
        pub const to_const = TypedMethods.to_const;
        pub const to_align = TypedMethods.to_align;
        pub const to_nullable = TypedMethods.to_nullable;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(native_ptr: *align(A) const T) Self {
            return Self{ .opq = .new_from_native(native_ptr) };
        }
        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        // NULL CHECKS
        pub const is_null = TypedMethods.is_null;
        pub const not_null = TypedMethods.not_null;
        pub const assert_not_null = TypedMethods.assert_not_null;
        pub const assert_null = TypedMethods.assert_null;

        // ALIGNMENT
        pub const is_aligned = TypedMethods.is_aligned;
        pub const is_aligned_any = TypedMethods.is_aligned_any;
        pub const is_aligned_log_2 = TypedMethods.is_aligned_log_2;
        pub const is_aligned_pow_2 = TypedMethods.is_aligned_pow_2;
        pub const is_aligned_std_mem = TypedMethods.is_aligned_std_mem;
        pub const assert_aligned = TypedMethods.assert_aligned;
        pub const assert_aligned_any = TypedMethods.assert_aligned_any;
        pub const assert_aligned_log_2 = TypedMethods.assert_aligned_log_2;
        pub const assert_aligned_pow_2 = TypedMethods.assert_aligned_pow_2;
        pub const assert_aligned_std_mem = TypedMethods.assert_aligned_std_mem;

        // POINTER ACCESS
        pub const const_ptr_or_null = TypedMethods.ptr_const_or_null;
        pub const const_ptr_many_or_null = TypedMethods.ptr_many_const_or_null;
        pub const const_slice_or_null = TypedMethods.slice_const_or_null;
        pub const const_array_ptr_or_null = TypedMethods.array_ptr_const_or_null;
        pub const const_vector_ptr_or_null = TypedMethods.vector_ptr_const_or_null;

        // GET
        pub const get_or_null = TypedMethods.get_or_null;
        pub const get_orelse = TypedMethods.get_orelse;
        pub const get_at_index_or_null = TypedMethods.get_at_index_or_null;
        pub const get_at_index_orelse = TypedMethods.get_at_index_orelse;

        // ADDRESS ADD / SUB / MOVE
        pub const add = TypedMethods.add;
        pub const add_in_place = TypedMethods.add_in_place;
        pub const add_assert_contiguous = TypedMethods.add_assert_contiguous;
        pub const add_in_place_assert_contiguous = TypedMethods.add_in_place_assert_contiguous;
        pub const subtract = TypedMethods.subtract;
        pub const subtract_in_place = TypedMethods.subtract_in_place;
        pub const subtract_assert_contiguous = TypedMethods.subtract_assert_contiguous;
        pub const subtract_in_place_assert_contiguous = TypedMethods.subtract_in_place_assert_contiguous;
        pub const move = TypedMethods.move;
        pub const move_in_place = TypedMethods.move_in_place;
        pub const move_assert_contiguous = TypedMethods.move_assert_contiguous;
        pub const move_in_place_assert_contiguous = TypedMethods.move_in_place_assert_contiguous;

        // ELEMENTS BETWEEN
        pub const elements_between_self_low_other_high_exclude_or_null = TypedMethods.elements_between_self_low_other_high_exclude_or_null;
        pub const elements_between_self_low_other_high_exclude_orelse_0 = TypedMethods.elements_between_self_low_other_high_exclude_orelse_0;
        pub const elements_between_self_high_other_low_exclude_or_null = TypedMethods.elements_between_self_high_other_low_exclude_or_null;
        pub const elements_between_self_high_other_low_exclude_orelse_0 = TypedMethods.elements_between_self_high_other_low_exclude_orelse_0;
        pub const elements_between_self_low_other_high_include_or_null = TypedMethods.elements_between_self_low_other_high_include_or_null;
        pub const elements_between_self_low_other_high_include_orelse_0 = TypedMethods.elements_between_self_low_other_high_include_orelse_0;
        pub const elements_between_self_high_other_low_include_or_null = TypedMethods.elements_between_self_high_other_low_include_or_null;
        pub const elements_between_self_high_other_low_include_orelse_0 = TypedMethods.elements_between_self_high_other_low_include_orelse_0;
        pub const elements_between_exclude_high_or_null = TypedMethods.elements_between_exclude_high_or_null;
        pub const elements_between_exclude_high_orelse_0 = TypedMethods.elements_between_exclude_high_orelse_0;
        pub const elements_between_include_high_or_null = TypedMethods.elements_between_include_high_or_null;
        pub const elements_between_include_high_orelse_0 = TypedMethods.elements_between_include_high_orelse_0;

        // RANGES
        pub const is_within_range_exclude_high = TypedMethods.is_within_range_exclude_high;
        pub const is_within_range_include_high = TypedMethods.is_within_range_include_high;
        pub const assert_is_within_range_exclude_high = TypedMethods.assert_is_within_range_exclude_high;
        pub const assert_is_within_range_include_high = TypedMethods.assert_is_within_range_include_high;

        pub inline fn new_null() Self {
            return Self{ .opq = .new_null() };
        }

        pub inline fn from_anyopaque(void_ptr: *const anyopaque) Self {
            return Self{ .opq = .from_const_anyopaque(void_ptr) };
        }

        // ADDRESS INTROSPECTION
        pub const local_addr = TypedMethods.local_addr;
        pub const resolved_addr = TypedMethods.resolved_addr;
        pub const resolved_addr_or_null = TypedMethods.resolved_addr_or_null;

        // COMPARISON / HASHING
        pub const eql = TypedMethods.eql;
        pub const eql_native = TypedMethods.eql_native;
        pub const eql_local = TypedMethods.eql_local;
        pub const order = TypedMethods.order;
        pub const hash = TypedMethods.hash;
        pub const simple_hash = TypedMethods.simple_hash;

        // SOURCE INTROSPECTION
        pub const source_kind = TypedMethods.source_kind;
        pub const is_native = TypedMethods.is_native;
        pub const is_global_resolver = TypedMethods.is_global_resolver;

        // SIGNED DISTANCE
        pub const bytes_from = TypedMethods.bytes_from;
        pub const elements_from = TypedMethods.elements_from;
        pub const offset_from = TypedMethods.offset_from;

        // BULK READ
        pub const memcopy_to = TypedMethods.memcopy_to;
        pub const memmove_to = TypedMethods.memmove_to;
        pub const const_bytes = TypedMethods.const_bytes;

        // VOLATILE / ATOMIC READ
        pub const get_volatile = TypedMethods.get_volatile;
        pub const atomic_load = TypedMethods.atomic_load;
        pub const load = TypedMethods.load;

        // VOID POINTER
        pub const to_anyopaque = TypedMethods.to_anyopaque;

        // SIGNED DISTANCE (NULLABLE)
        pub const bytes_from_or_null = TypedMethods.bytes_from_or_null;
        pub const bytes_from_orelse_0 = TypedMethods.bytes_from_orelse_0;
        pub const elements_from_or_null = TypedMethods.elements_from_or_null;
        pub const elements_from_orelse_0 = TypedMethods.elements_from_orelse_0;
        pub const offset_from_or_null = TypedMethods.offset_from_or_null;
        pub const offset_from_orelse_0 = TypedMethods.offset_from_orelse_0;

        // NULL-PRESERVING ARITHMETIC
        pub const add_or_null = TypedMethods.add_or_null;
        pub const subtract_or_null = TypedMethods.subtract_or_null;
        pub const move_or_null = TypedMethods.move_or_null;

        // NULL CONSTRUCTION / MUTATION
        pub const set_null = TypedMethods.set_null;
        pub const is_null_or_equal = TypedMethods.is_null_or_equal;

        // ADDITIONAL CASTS
        pub const to_non_null = TypedMethods.to_non_null;

        // VOID POINTER
        pub const to_anyopaque_or_null = TypedMethods.to_anyopaque_or_null;

        // ADDITIONAL CASTS
        pub const to_unaligned = TypedMethods.to_unaligned;

        // ADDITIONAL CASTS
        pub const to_mutable = TypedMethods.to_mutable;
    };
}
