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
const SourceLocation = std.builtin.SourceLocation;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
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
    ALWAYS_VALID,
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
            .ADD_FUNC = @ptrCast(PROTO.add),
            .SUBTRACT_FUNC = @ptrCast(PROTO.sub),
            .IS_NULL_FUNC = @ptrCast(PROTO.is_null),
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
            return Self{ .addr = @intFromPtr(any_ptr) };
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
                .NATIVE => self.addr == null,
                .GLOBAL_RESOLVER => IS_NULL(self.addr),
            };
        }
        pub inline fn not_null(self: Self) bool {
            return switch (comptime SOURCE) {
                .NATIVE => self.addr != null,
                .GLOBAL_RESOLVER => !IS_NULL(self.addr),
            };
        }
        pub inline fn assert_not_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.not_null(), src, "pointer was null", .{});
        }
        pub inline fn assert_null(self: Self, comptime src: ?SourceLocation) void {
            assert_with_reason(self.is_null(), src, "pointer was not null", .{});
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
                always_assert_contiguous(original_addr, new_addr, DIR, offset, src);
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
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            return self.resolve(T)[0..len];
        }
        pub inline fn array_ptr(self: Self, comptime T: type, comptime LEN: anytype) *[LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn vector_ptr(self: Self, comptime T: type, comptime LEN: anytype) *@Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve(T));
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
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            return self.resolve_aligned(T, A)[0..len];
        }
        pub inline fn array_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn vector_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
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
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            return self.resolve(T)[0..len];
        }
        pub inline fn const_array_ptr(self: Self, comptime T: type, comptime LEN: anytype) *const [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve(T));
        }
        pub inline fn const_vector_ptr(self: Self, comptime T: type, comptime LEN: anytype) *const @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve(T));
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
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            return self.resolve_aligned(T, A)[0..len];
        }
        pub inline fn const_array_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const [LEN]T {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
        }
        pub inline fn const_vector_ptr_aligned(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const @Vector(LEN, T) {
            self.assert_not_null(@src());
            assert_contiguous(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_aligned(T, A));
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
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            if (self.resolve_null(T)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn array_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*[LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn vector_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*@Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null(T));
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
        pub inline fn slice_aligned_or_null(self: Self, comptime T: type, comptime A: usize, len: anytype) []align(A) T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            if (self.resolve_null_aligned(T, A)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn array_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn vector_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) ?*align(A) @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
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
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            if (self.resolve_null(T)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn const_array_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*const [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null(T));
        }
        pub inline fn const_vector_ptr_or_null(self: Self, comptime T: type, comptime LEN: anytype) ?*const @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null(T));
        }
        //**********************
        // NULL CONST PTR ALIGN
        //**********************
        pub inline fn const_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize) *align(A) const T {
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn const_ptr_many_aligned_or_null(self: Self, comptime T: type, comptime A: usize) [*]align(A) const T {
            return self.resolve_null_aligned(T, A);
        }
        pub inline fn const_slice_aligned_or_null(self: Self, comptime T: type, comptime A: usize, len: anytype) []align(A) const T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(len))) - 1, @src());
            if (self.resolve_null_aligned(T, A)) |ptr_| {
                return ptr_[0..len];
            }
            return null;
        }
        pub inline fn const_array_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const [LEN]T {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
        }
        pub inline fn const_vector_ptr_aligned_or_null(self: Self, comptime T: type, comptime A: usize, comptime LEN: anytype) *align(A) const @Vector(LEN, T) {
            assert_contiguous_ignore_null(self.addr, .ADD, (@sizeOf(T) * @as(usize, @intCast(LEN))) - 1, @src());
            return @ptrCast(self.resolve_null_aligned(T, A));
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
            return self.typed_add(offset);
        }
        pub inline fn typed_add_in_place_assert_contiguous(self: *Self, comptime T: type, offset: usize) void {
            assert_contiguous(self.addr, .ADD, @sizeOf(T) * offset, @src());
            self.typed_add_in_place(offset);
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
            return self.typed_subtract(offset);
        }
        pub inline fn typed_subtract_in_place_assert_contiguous(self: *Self, comptime T: type, offset: usize) void {
            assert_contiguous(self.addr, .SUB, @sizeOf(T) * offset, @src());
            self.typed_subtract_in_place(offset);
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
        pub inline fn assert_is_within_range_exclude_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) bool {
            assert_with_reason(self.is_within_range_exclude_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }
        pub inline fn assert_is_within_range_include_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) bool {
            assert_with_reason(self.is_within_range_include_high(low, high), src, "pointer was not within the given range (or the given range was invalid)", .{});
        }
    };
}

pub fn Pointer(comptime T: type, comptime SOURCE: PointerSource) type {
    return struct {
        const Self = @This();
        pub const Opaque = PointerOpaque(SOURCE);
        pub const Addr = Opaque.Addr;

        opq: Opaque,

        pub inline fn new(addr: Addr) Self {
            return Self{ .opq = .new(addr) };
        }
        pub inline fn new_from_native(T_ptr: *T) Self {
            return Self{ .opq = .new_from_native(T_ptr) };
        }

        pub inline fn assert_native(comptime src: ?SourceLocation) void {
            Opaque.assert_native(src);
        }

        pub inline fn is_null(self: Self) bool {
            return self.opq.is_null();
        }
        pub inline fn not_null(self: Self) bool {
            return self.opq.not_null();
        }
        pub inline fn assert_not_null(self: Self, comptime src: ?SourceLocation) void {
            self.opq.assert_not_null(src);
        }
        pub inline fn assert_null(self: Self, comptime src: ?SourceLocation) void {
            self.opq.assert_null(src);
        }

        pub inline fn is_aligned(self: Self, alignment: usize) bool {
            return self.opq.is_aligned(alignment);
        }
        pub inline fn is_aligned_any(self: Self, alignment: usize) bool {
            return self.opq.is_aligned_any(alignment);
        }
        pub inline fn is_aligned_log_2(self: Self, alignment_log_2: u8) bool {
            return self.opq.is_aligned_log_2(alignment_log_2);
        }
        pub inline fn is_aligned_pow_2(self: Self, alignment_pow_2: PowerOf2) bool {
            return self.opq.is_aligned_pow_2(alignment_pow_2);
        }
        pub inline fn is_aligned_std_mem(self: Self, alignment: mem.Alignment) bool {
            return self.is_aligned_std_mem(alignment);
        }

        pub inline fn assert_aligned(self: Self, alignment: usize, comptime src: ?SourceLocation) void {
            self.opq.assert_aligned(alignment, src);
        }
        pub inline fn assert_aligned_any(self: Self, alignment: usize, comptime src: ?SourceLocation) void {
            self.opq.assert_aligned_any(alignment, src);
        }
        pub inline fn assert_aligned_log_2(self: Self, alignment_log_2: u8, comptime src: ?SourceLocation) void {
            self.opq.assert_aligned_log_2(alignment_log_2, src);
        }
        pub inline fn assert_aligned_pow_2(self: Self, alignment_pow_2: PowerOf2, comptime src: ?SourceLocation) void {
            self.opq.assert_aligned_pow_2(alignment_pow_2, src);
        }
        pub inline fn assert_aligned_std_mem(self: Self, alignment: mem.Alignment, comptime src: ?SourceLocation) void {
            self.opq.assert_aligned_std_mem(alignment, src);
        }

        //**********************
        // ____ _____ PTR _____
        //**********************
        pub inline fn ptr(self: Self) *T {
            return self.opq.ptr(T);
        }
        pub inline fn ptr_many(self: Self) [*]T {
            return self.opq.ptr_many(T);
        }
        pub inline fn slice(self: Self, len: anytype) []T {
            return self.opq.slice(T, len);
        }
        pub inline fn array_ptr(self: Self, comptime LEN: anytype) *[LEN]T {
            return self.opq.array_ptr(T, LEN);
        }
        pub inline fn vector_ptr(self: Self, comptime LEN: anytype) *@Vector(LEN, T) {
            return self.opq.vector_ptr(T, LEN);
        }
        //**********************
        // ____ CONST PTR _____
        //**********************
        pub inline fn const_ptr(self: Self) *const T {
            return self.opq.const_ptr(T);
        }
        pub inline fn const_ptr_many(self: Self) [*]const T {
            return self.opq.const_ptr_many(T);
        }
        pub inline fn const_slice(self: Self, len: anytype) []const T {
            return self.opq.const_slice(T, len);
        }
        pub inline fn const_array_ptr(self: Self, comptime LEN: anytype) *const [LEN]T {
            return self.opq.const_array_ptr(T, LEN);
        }
        pub inline fn const_vector_ptr(self: Self, comptime LEN: anytype) *const @Vector(LEN, T) {
            return self.opq.const_vector_ptr(T, LEN);
        }
        //***********
        // GET / SET
        //***********
        pub inline fn get(self: Self) T {
            return self.opq.get(T);
        }
        pub inline fn get_or_null(self: Self) ?T {
            return self.opq.get_or_null(T);
        }
        pub inline fn get_orelse(self: Self, default: T) T {
            return self.opq.get_orelse(T, default);
        }
        pub inline fn get_at_index(self: Self, index: usize) T {
            return self.opq.get_at_index(T, index);
        }
        pub inline fn get_at_index_or_null(self: Self, index: usize) ?T {
            return self.opq.get_at_index_or_null(T, index);
        }
        pub inline fn get_at_index_orelse(self: Self, index: usize, default: T) T {
            return self.opq.get_at_index_orelse(T, index, default);
        }
        pub inline fn set(self: Self, val: T) void {
            self.opq.set(T, val);
        }
        pub inline fn set_if_not_null(self: Self, val: T) void {
            self.opq.set_if_not_null(T, val);
        }
        pub inline fn set_if_not_null_return_ptr_is_NOT_null(self: Self, val: T) bool {
            return self.opq.set_if_not_null_return_ptr_is_NOT_null(T, val);
        }
        pub inline fn set_if_not_null_return_ptr_IS_null(self: Self, val: T) bool {
            return self.opq.set_if_not_null_return_ptr_IS_null(T, val);
        }
        pub inline fn set_at_index(self: Self, index: usize, val: T) void {
            self.opq.set_at_index(T, index, val);
        }
        pub inline fn set_at_index_if_not_null(self: Self, index: usize, val: T) void {
            self.opq.set_at_index_if_not_null(T, index, val);
        }
        pub inline fn set_at_index_if_not_null_return_ptr_is_NOT_null(self: Self, index: usize, val: T) bool {
            return self.opq.set_at_index_if_not_null_return_ptr_is_NOT_null(T, index, val);
        }
        pub inline fn set_at_index_if_not_null_return_ptr_IS_null(self: Self, index: usize, val: T) bool {
            return self.opq.set_at_index_if_not_null_return_ptr_IS_null(T, index, val);
        }
        //**************************
        // ADDRESS ADD / SUB / MOVE
        //**************************
        pub inline fn add(self: Self, offset: usize) Self {
            return Self{ .opq = self.opq.typed_add(T, offset) };
        }
        pub inline fn add_in_place(self: *Self, offset: usize) void {
            self.opq.typed_add_in_place(T, offset);
        }

        pub inline fn add_assert_contiguous(self: Self, offset: usize) Self {
            return Self{ .opq = self.opq.typed_add_assert_contiguous(T, offset) };
        }
        pub inline fn add_in_place_assert_contiguous(self: *Self, offset: usize) void {
            self.opq.typed_add_in_place_assert_contiguous(T, offset);
        }

        pub inline fn subtract(self: Self, offset: usize) Self {
            return Self{ .opq = self.opq.typed_subtract(T, offset) };
        }
        pub inline fn subtract_in_place(self: *Self, offset: usize) void {
            self.opq.typed_subtract_in_place(T, offset);
        }

        pub inline fn subtract_assert_contiguous(self: Self, offset: usize) Self {
            return Self{ .opq = self.opq.typed_subtract_assert_contiguous(T, offset) };
        }
        pub inline fn subtract_in_place_assert_contiguous(self: *Self, offset: usize) void {
            self.opq.typed_subtract_in_place_assert_contiguous(T, offset);
        }

        pub inline fn move(self: Self, offset: isize) Self {
            return Self{ .opq = self.opq.typed_move(T, offset) };
        }
        pub inline fn move_in_place(self: *Self, offset: isize) void {
            self.opq.move_in_place(offset);
        }

        pub inline fn move_assert_contiguous(self: Self, offset: isize) Self {
            return Self{ .opq = self.opq.typed_move_assert_contiguous(T, offset) };
        }
        pub inline fn move_in_place_assert_contiguous(self: *Self, offset: isize) void {
            self.opq.move_in_place_assert_contiguous(offset);
        }
        //**************************
        // ELEMENTS BETWEEN
        //**************************
        pub inline fn elements_between_self_low_other_high_exclude(self: Self, other: Self) usize {
            return self.opq.elements_between_self_low_other_high_exclude(other.opq, T);
        }
        pub inline fn elements_between_self_low_other_high_exclude_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_self_low_other_high_exclude_or_null(other.opq, T);
        }
        pub inline fn elements_between_self_low_other_high_exclude_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_self_low_other_high_exclude_orelse_0(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_exclude(self: Self, other: Self) usize {
            return self.opq.elements_between_self_high_other_low_exclude(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_exclude_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_self_high_other_low_exclude_or_null(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_exclude_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_self_high_other_low_exclude_orelse_0(other.opq, T);
        }
        pub inline fn elements_between_self_low_other_high_include(self: Self, other: Self) usize {
            return self.opq.elements_between_self_low_other_high_include(other.opq, T);
        }
        pub inline fn elements_between_self_low_other_high_include_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_self_low_other_high_include_or_null(other.opq, T);
        }
        pub inline fn elements_between_self_low_other_high_include_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_self_low_other_high_include_orelse_0(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_include(self: Self, other: Self) usize {
            return self.opq.elements_between_self_high_other_low_include(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_include_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_self_high_other_low_include_or_null(other.opq, T);
        }
        pub inline fn elements_between_self_high_other_low_include_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_self_high_other_low_include_orelse_0(other.opq, T);
        }
        pub inline fn elements_between_exclude_high(self: Self, other: Self) usize {
            return self.opq.elements_between_exclude_high(other.opq, T);
        }
        pub inline fn elements_between_exclude_high_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_exclude_high_or_null(other.opq, T);
        }
        pub inline fn elements_between_exclude_high_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_exclude_high_orelse_0(other.opq, T);
        }
        pub inline fn elements_between_include_high(self: Self, other: Self) usize {
            return self.opq.elements_between_include_high(other.opq, T);
        }
        pub inline fn elements_between_include_high_or_null(self: Self, other: Self) ?usize {
            return self.opq.elements_between_include_high_or_null(other.opq, T);
        }
        pub inline fn elements_between_include_high_orelse_0(self: Self, other: Self) usize {
            return self.opq.elements_between_include_high_orelse_0(other.opq, T);
        }
        pub inline fn is_within_range_exclude_high(self: Self, low: Self, high: Self) bool {
            return self.opq.is_within_range_exclude_high(low.opq, high.opq);
        }
        pub inline fn is_within_range_include_high(self: Self, low: Self, high: Self) bool {
            return self.opq.is_within_range_exclude_high(low.opq, high.opq);
        }
        pub inline fn assert_is_within_range_exclude_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) bool {
            self.opq.assert_is_within_range_exclude_high(low.opq, high.opq, src);
        }
        pub inline fn assert_is_within_range_include_high(self: Self, low: Self, high: Self, comptime src: ?SourceLocation) bool {
            self.opq.assert_is_within_range_include_high(low.opq, high.opq, src);
        }
    };
}
