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
const testing = std.testing;

const Root = @import("./_root.zig");
const PointerModule = Root.Pointer;
const PowerOf2 = Root.Math.PowerOf2;

const PointerSource = PointerModule.PointerSource;
const StaticAddressResolver = PointerModule.StaticAddressResolver;
const PointerAdvanced = PointerModule.PointerAdvanced;
const MakePtrDef = PointerModule.MakePtrDef;
const MakePtrDefNoSize = PointerModule.MakePtrDefNoSize;
const MakePtrFromDef = PointerModule.MakePtrFromDef;
const MakePtr = PointerModule.MakePtr;
const PtrDefaultFromDef = PointerModule.PtrDefaultFromDef;
const PtrDefault = PointerModule.PtrDefault;
const SentinelRefOpaque = PointerModule.SentinelRefOpaque;
const AllowZero = PointerModule.AllowZero;
const Nullability = PointerModule.Nullability;
const Mutability = PointerModule.Mutability;
const Volatile = PointerModule.Volatile;

const Pointer = PointerModule.Pointer;
const PointerAlign = PointerModule.PointerAlign;
const NullablePointer = PointerModule.NullablePointer;
const NullablePointerAlign = PointerModule.NullablePointerAlign;
const ConstPointer = PointerModule.ConstPointer;
const ConstPointerAlign = PointerModule.ConstPointerAlign;
const NullableConstPointer = PointerModule.NullableConstPointer;
const NullableConstPointerAlign = PointerModule.NullableConstPointerAlign;

const NATIVE = PointerSource.native_pointer();

/// A single buffer that the static resolvers below map their handles into.
/// It is deliberately larger than any test needs and aligned more strongly
/// than any element type used with it.
var global_test_buffer: [64]u8 align(16) = undefined;

fn buffer_base() usize {
    return @intFromPtr(&global_test_buffer[0]);
}

fn resolve_u8(handle: u8) usize {
    return buffer_base() + handle;
}
fn increment_u8(handle: u8, byte_offset: usize) u8 {
    return handle + @as(u8, @intCast(byte_offset));
}
fn decrement_u8(handle: u8, byte_offset: usize) u8 {
    return handle - @as(u8, @intCast(byte_offset));
}

fn resolve_u16(handle: u16) usize {
    return buffer_base() + handle;
}
fn increment_u16(handle: u16, byte_offset: usize) u16 {
    return handle + @as(u16, @intCast(byte_offset));
}
fn decrement_u16(handle: u16, byte_offset: usize) u16 {
    return handle - @as(u16, @intCast(byte_offset));
}

fn resolve_u32(handle: u32) usize {
    return buffer_base() + handle;
}
fn increment_u32(handle: u32, byte_offset: usize) u32 {
    return handle + @as(u32, @intCast(byte_offset));
}
fn decrement_u32(handle: u32, byte_offset: usize) u32 {
    return handle - @as(u32, @intCast(byte_offset));
}

fn resolve_u64(handle: u64) usize {
    return buffer_base() + handle;
}
fn increment_u64(handle: u64, byte_offset: usize) u64 {
    return handle + byte_offset;
}
fn decrement_u64(handle: u64, byte_offset: usize) u64 {
    return handle - byte_offset;
}

fn resolve_usize(handle: usize) usize {
    return buffer_base() + handle;
}
fn increment_usize(handle: usize, byte_offset: usize) usize {
    return handle + byte_offset;
}
fn decrement_usize(handle: usize, byte_offset: usize) usize {
    return handle - byte_offset;
}

const RES_U8 = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U8 = .{
        .RESOLVE = &resolve_u8,
        .INCREMENT = &increment_u8,
        .DECREMENT = &decrement_u8,
    } },
});

const RES_U16 = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U16 = .{
        .RESOLVE = &resolve_u16,
        .INCREMENT = &increment_u16,
        .DECREMENT = &decrement_u16,
    } },
});

const RES_U32 = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U32 = .{
        .RESOLVE = &resolve_u32,
        .INCREMENT = &increment_u32,
        .DECREMENT = &decrement_u32,
    } },
});

const RES_U64 = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U64 = .{
        .RESOLVE = &resolve_u64,
        .INCREMENT = &increment_u64,
        .DECREMENT = &decrement_u64,
    } },
});

const RES_USIZE = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .USIZE = .{
        .RESOLVE = &resolve_usize,
        .INCREMENT = &increment_usize,
        .DECREMENT = &decrement_usize,
    } },
});

/// A resolver that has no reserved null handle. Only never-null pointer
/// types may use it.
const RES_U32_NO_NULL = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U32 = .{
        .HAS_NULL_VALUE = false,
        .RESOLVE = &resolve_u32,
        .INCREMENT = &increment_u32,
        .DECREMENT = &decrement_u32,
    } },
});

/// A resolver whose addresses are only adjustable in 16-byte increments.
fn resolve_u16_granularity_16(handle: u16) usize {
    return buffer_base() + @as(usize, handle) * 16;
}
fn increment_u16_granularity_16(handle: u16, byte_offset: usize) u16 {
    return handle + @as(u16, @intCast(byte_offset / 16));
}
fn decrement_u16_granularity_16(handle: u16, byte_offset: usize) u16 {
    return handle - @as(u16, @intCast(byte_offset / 16));
}

const RES_U16_GRANULARITY_16 = PointerSource.static_address_resolver(.{
    .FUNCS = .{ .U16 = .{
        .RESOLVE = &resolve_u16_granularity_16,
        .INCREMENT = &increment_u16_granularity_16,
        .DECREMENT = &decrement_u16_granularity_16,
    } },
    .ADDRESS_GRANULARITY = ._16,
});

const SENTINEL_ZERO_OPAQUE = SentinelRefOpaque(u8, 0);
const SENTINEL_ZERO_DEF = (MakePtrDefNoSize{ .ELEMENT = u8 }).with_sentinel(0);
const SentU8 = PointerAdvanced(NATIVE, SENTINEL_ZERO_DEF);
const SentU8Nullable = PointerAdvanced(NATIVE, SENTINEL_ZERO_DEF.with_nullability(.NULLABLE));
const SentU8Resolver = PointerAdvanced(RES_U8, SENTINEL_ZERO_DEF);

fn PtrDefless(comptime T: type) type {
    return PointerAdvanced(NATIVE, .{ .ELEMENT = T });
}

//**************************
// NATIVE POINTER BASIC API
//**************************

test "Pointer -> native pointer construction, introspection, and addresses" {
    var values: [4]u32 align(16) = .{ 10, 20, 30, 40 };
    const P = Pointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);

    try testing.expect(ptr.not_null());
    try testing.expect(!ptr.is_null());
    try testing.expect(ptr.is_native());
    try testing.expect(!ptr.is_global_resolver());
    try testing.expect(ptr.is_mutable());
    try testing.expect(!ptr.is_const());
    try testing.expect(ptr.can_never_be_null());
    try testing.expect(!ptr.can_be_null());
    try testing.expect(!ptr.has_sentinel());
    try testing.expect(!ptr.elem_is_zero_sized());
    try testing.expectEqual(PowerOf2.align_of_type(u32), ptr.ptr_alignment_pow2());
    try testing.expectEqual(@as(usize, @alignOf(u32)), ptr.ptr_alignment());
    try testing.expect(P.SOURCE == .NATIVE);
    try testing.expect(P.IS_NATIVE);
    try testing.expect(!P.USE_STATIC_RESOLVER);
    try testing.expectEqual(@as(type, u32), P.ELEMENT);
    try testing.expectEqual(@as(usize, 4), P.ELEMENT_SIZE);

    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr());
    try testing.expectEqual(@as(?usize, @intFromPtr(&values[0])), ptr.addr_or_null());
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr_orelse_0());
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr_no_align_check());

    const same = P.new_from_any(&values[0]);
    try testing.expect(ptr.eql(same));
    try testing.expect(ptr.eql_native_address(&values[0]));
    try testing.expect(ptr.eql_native_address(@as(?*u32, &values[0])));
    try testing.expect(ptr.eql_native_address(values[0..1]));
    try testing.expect(@TypeOf(ptr.internal) == [*]u32);
}

test "Pointer -> native nullable pointer null handling" {
    var value: u32 = 7;
    const NP = NullablePointer(u32, NATIVE);
    const ptr = NP.new_from_any(&value);
    const null_ptr = NP.new_from(null);

    try testing.expect(ptr.not_null());
    try testing.expect(ptr.can_be_null());
    try testing.expect(!ptr.can_never_be_null());
    try testing.expect(@TypeOf(ptr.internal) == ?[*]u32);
    try testing.expect(NP.INTERNAL_PTR_DEFAULT == null);
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(ptr.ptr_never_null()));

    try testing.expect(null_ptr.is_null());
    try testing.expect(!null_ptr.not_null());
    try testing.expect(null_ptr.eql(NP.new_null()));
    try testing.expect(null_ptr.eql(NP.new_from(null)));
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expectEqual(@as(usize, 0), null_ptr.addr_orelse_0());
    try testing.expectEqual(@as(?*u32, null), null_ptr.ptr_or_null());
    try testing.expectEqual(@as(?[*]u32, null), null_ptr.ptr_many_or_null());
    try testing.expectEqual(@as(?[*c]u32, null), null_ptr.ptr_c_or_null());
    try testing.expectEqual(@as(?[]u32, null), null_ptr.slice_or_null(2));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 99), null_ptr.get_orelse(99));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_at_index_or_null(0));
    try testing.expectEqual(@as(u32, 99), null_ptr.get_at_index_orelse(0, 99));
    try testing.expectEqual(std.math.Order.lt, null_ptr.order(ptr));
    try testing.expect(!null_ptr.eql_native_address(&value));
    try testing.expect(null_ptr.eql_native_address(@as(?*u32, null)));

    null_ptr.set_if_not_null(123);
    try testing.expectEqual(@as(u32, 7), value);
    try testing.expect(!null_ptr.set_if_not_null_return_ptr_is_NOT_null(123));
    try testing.expect(null_ptr.set_if_not_null_return_ptr_IS_null(123));
    try testing.expectEqual(@as(u32, 7), value);
    null_ptr.set_at_index_if_not_null(0, 123);
    try testing.expectEqual(@as(u32, 7), value);
    try testing.expect(!null_ptr.set_at_index_if_not_null_return_ptr_is_NOT_null(0, 123));
    try testing.expect(null_ptr.set_at_index_if_not_null_return_ptr_IS_null(0, 123));
    try testing.expectEqual(@as(u32, 7), value);

    var changeable = NP.new_from_any(&value);
    changeable.set_null();
    try testing.expect(changeable.is_null());
    try testing.expect(changeable.eql(null_ptr));

    const from_non_null = NP.new_null();
    try testing.expect(from_non_null.is_null());
    try testing.expect(@TypeOf(from_non_null) == NP);
}

test "Pointer -> native pointer conversions" {
    var values: [4]u32 align(16) = .{ 10, 20, 30, 40 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);

    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many_never_null()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_never_null()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c_never_null()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_or_null().?));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many_or_null().?));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c_or_null().?));

    try testing.expectEqualSlices(u32, values[0..4], ptr.slice(4));
    try testing.expectEqual(@as(usize, 4), ptr.slice_never_null(4).len);
    try testing.expectEqual(@as(usize, 4), ptr.slice_or_null(4).?.len);
    try testing.expectEqual(@as(usize, 0), ptr.slice(0).len);

    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(NP.new_from_any(&values[0]).ptr_many_or_null().?));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(NP.new_from_any(&values[0]).ptr_or_null().?));
    try testing.expectEqual(@as(u32, 10), CP.new_from_any(&values[0]).get());
    try testing.expectEqual(@as(*const u32, &values[0]), CP.new_from_any(&values[0]).ptr_never_null());
}

test "Pointer -> native pointer getters and setters" {
    var values: [4]u32 align(16) = .{ 10, 20, 30, 40 };
    const P = Pointer(u32, NATIVE);
    var ptr = P.new_from_any(&values[0]);

    try testing.expectEqual(@as(u32, 10), ptr.get());
    try testing.expectEqual(@as(?u32, 10), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 10), ptr.get_orelse(99));
    try testing.expectEqual(@as(u32, 30), ptr.get_at_index(2));
    try testing.expectEqual(@as(?u32, 30), ptr.get_at_index_or_null(2));
    try testing.expectEqual(@as(u32, 30), ptr.get_at_index_orelse(2, 99));

    ptr.set(11);
    try testing.expectEqual(@as(u32, 11), values[0]);
    ptr.set_if_not_null(12);
    try testing.expectEqual(@as(u32, 12), values[0]);
    try testing.expect(ptr.set_if_not_null_return_ptr_is_NOT_null(13));
    try testing.expectEqual(@as(u32, 13), values[0]);
    try testing.expect(!ptr.set_if_not_null_return_ptr_IS_null(14));
    try testing.expectEqual(@as(u32, 14), values[0]);

    ptr.set_at_index(3, 44);
    try testing.expectEqual(@as(u32, 44), values[3]);
    ptr.set_at_index_if_not_null(3, 45);
    try testing.expectEqual(@as(u32, 45), values[3]);
    try testing.expect(ptr.set_at_index_if_not_null_return_ptr_is_NOT_null(3, 46));
    try testing.expectEqual(@as(u32, 46), values[3]);
    try testing.expect(!ptr.set_at_index_if_not_null_return_ptr_IS_null(3, 47));
    try testing.expectEqual(@as(u32, 47), values[3]);

    // The pointer itself still refers to the same address.
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr());
}

test "Pointer -> native pointer arithmetic" {
    var values: [5]u32 align(16) = .{ 10, 20, 30, 40, 50 };
    const P = Pointer(u32, NATIVE);
    var ptr = P.new_from_any(&values[0]);

    try testing.expectEqual(@as(u32, 20), ptr.increment(1).get());
    try testing.expectEqual(@as(u32, 30), ptr.increment(2).get());
    try testing.expectEqual(@as(u32, 10), ptr.increment(2).decrement(2).get());
    try testing.expectEqual(@as(u32, 40), ptr.move(3).get());
    try testing.expectEqual(@as(u32, 10), ptr.move(3).move(-3).get());
    try testing.expectEqual(@as(u32, 30), ptr.move(-2).move(4).get());

    try testing.expectEqual(@as(u32, 20), ptr.increment_assert_contiguous(1).get());
    try testing.expectEqual(@as(u32, 10), ptr.increment_assert_contiguous(1).decrement_assert_contiguous(1).get());
    try testing.expectEqual(@as(u32, 30), ptr.move_assert_contiguous(2).get());
    try testing.expectEqual(@as(u32, 10), ptr.move_assert_contiguous(2).move_assert_contiguous(-2).get());

    ptr.increment_in_place(1);
    try testing.expectEqual(@as(u32, 20), ptr.get());
    ptr.decrement_in_place(1);
    try testing.expectEqual(@as(u32, 10), ptr.get());
    ptr.move_in_place(2);
    try testing.expectEqual(@as(u32, 30), ptr.get());
    ptr.move_in_place(-2);
    try testing.expectEqual(@as(u32, 10), ptr.get());
    ptr.increment_in_place_assert_contiguous(3);
    try testing.expectEqual(@as(u32, 40), ptr.get());
    ptr.decrement_in_place_assert_contiguous(3);
    try testing.expectEqual(@as(u32, 10), ptr.get());
    ptr.move_in_place_assert_contiguous(4);
    try testing.expectEqual(@as(u32, 50), ptr.get());
    ptr.move_in_place_assert_contiguous(-4);
    try testing.expectEqual(@as(u32, 10), ptr.get());

    try testing.expectEqual(@intFromPtr(&values[2]), ptr.increment(2).addr());
    try testing.expectEqual(@intFromPtr(&values[0]), ptr.increment(2).decrement(2).addr());
}

test "Pointer -> native nullable pointer null-preserving arithmetic" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const NP = NullablePointer(u32, NATIVE);
    const ptr = NP.new_from_any(&values[0]);
    const null_ptr = NP.new_null();

    try testing.expect(null_ptr.increment_if_not_null(2).is_null());
    try testing.expect(null_ptr.decrement_if_not_null(2).is_null());
    try testing.expect(null_ptr.move_if_not_null(2).is_null());
    try testing.expectEqual(@as(?u32, 3), ptr.increment_if_not_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 1), ptr.increment_if_not_null(2).decrement_if_not_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 3), ptr.move_if_not_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 4), ptr.to_nullable().increment(1).move_if_not_null(2).get_or_null());
}

test "Pointer -> native pointer sentinel operations" {
    const P = Pointer(u8, NATIVE);
    var buf: [8]u8 align(16) = .{ 'a', 'b', 'c', 0, 'e', 0, 0, 0 };
    const ptr = SentU8.new_from_any(&buf[0]);

    try testing.expect(ptr.has_sentinel());
    try testing.expectEqual(@as(u8, 0), ptr.sentinel_value());
    try testing.expect(SentU8.HAS_SENTINEL);
    try testing.expectEqual(@as(u8, 0), SentU8.SENTINEL);
    try testing.expect(@TypeOf(ptr) == SentU8);
    try testing.expect(SentU8.PtrMany == [*:0]u8);
    try testing.expect(SentU8.PtrOne == *u8);
    try testing.expect(SentU8.Slice == [:0]u8);
    try testing.expect(SentU8.SliceNullable == ?[:0]u8);
    try testing.expect(SentU8.PtrManyNullable == ?[*:0]u8);
    try testing.expectEqual(@as(usize, 3), ptr.find_len_from_sentinel());
    try testing.expectEqual(@as(usize, 3), ptr.find_len_from_sentinel_max_length_assert(3));
    try testing.expectEqual(@as(usize, 3), ptr.slice_find_len_from_sentinel().len);
    try testing.expectEqual(@as(usize, 3), ptr.slice_find_len_from_sentinel_with_upper_limit_assert(3).len);
    try testing.expectEqual(@as(usize, 3), ptr.slice_never_null_find_len_from_sentinel().len);
    try testing.expectEqual(@as(usize, 3), ptr.slice_never_null_find_len_from_sentinel_with_upper_limit_assert(4).len);
    try testing.expectEqualSlices(u8, buf[0..3], ptr.slice(3));
    try testing.expectEqualSlices(u8, buf[0..3], ptr.slice_never_null(3));

    // The sentinel is written at `len`, and the returned slice has that len.
    var write_buf: [8]u8 align(16) = .{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h' };
    const write_ptr = SentU8.new_from_any(&write_buf[0]);
    write_ptr.write_sentinel_at_len(4);
    try testing.expectEqual(@as(u8, 0), write_buf[4]);
    try testing.expectEqual(@as(usize, 4), write_ptr.find_len_from_sentinel());
    const written_slice = write_ptr.slice_and_write_sentinel(5);
    try testing.expectEqual(@as(u8, 0), write_buf[5]);
    try testing.expectEqual(@as(usize, 5), written_slice.len);
    try testing.expectEqualSlices(u8, write_buf[0..5], written_slice);
    const written_slice_never_null = write_ptr.slice_and_write_sentinel_never_null(6);
    try testing.expectEqual(@as(u8, 0), write_buf[6]);
    try testing.expectEqual(@as(usize, 6), written_slice_never_null.len);

    // A non-sentinel pointer accepts a sentinel write request as a no-op.
    const plain = P.new_from_any(&write_buf[0]);
    plain.write_sentinel_at_len(2);
    try testing.expectEqual(@as(u8, 'c'), write_buf[2]);

    // Nullable sentinel pointers preserve null through the slice helpers.
    const null_ptr = SentU8Nullable.new_null();
    try testing.expect(null_ptr.is_null());
    try testing.expectEqual(@as(?[:0]u8, null), null_ptr.slice_or_null(2));
    try testing.expectEqual(@as(?[:0]u8, null), null_ptr.slice_and_write_sentinel_or_null(2));
    try testing.expect(null_ptr.slice_find_len_from_sentinel() == null);
    try testing.expect(null_ptr.slice_or_null_find_len_from_sentinel() == null);
    try testing.expect(null_ptr.slice_find_len_from_sentinel_with_upper_limit_assert(4) == null);
    try testing.expect(null_ptr.slice_or_null_find_len_from_sentinel_with_upper_limit_assert(4) == null);

    const non_null_sentinel = SentU8Nullable.new_from_any(&buf[0]);
    try testing.expectEqual(@as(usize, 3), non_null_sentinel.slice_find_len_from_sentinel().?.len);
    try testing.expectEqual(@as(usize, 3), non_null_sentinel.slice_or_null_find_len_from_sentinel().?.len);
    try testing.expectEqual(@as(usize, 3), non_null_sentinel.slice_find_len_from_sentinel_with_upper_limit_assert(3).?.len);
    try testing.expectEqual(@as(usize, 3), non_null_sentinel.slice_or_null_find_len_from_sentinel_with_upper_limit_assert(3).?.len);
}

test "Pointer -> native pointer byte slices" {
    var values: [4]u32 align(16) = .{ 0x01020304, 0x05060708, 0x090A0B0C, 0x0D0E0F10 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);
    const all_bytes = std.mem.asBytes(&values);

    try testing.expectEqual(@as(usize, 16), ptr.byte_slice(4).len);
    try testing.expectEqual(@as(usize, 16), ptr.byte_slice_never_null(4).len);
    try testing.expectEqual(@as(usize, 16), ptr.byte_slice_or_null(4).?.len);
    try testing.expectEqualSlices(u8, all_bytes, ptr.byte_slice(4));
    try testing.expectEqualSlices(u8, all_bytes, ptr.byte_slice_never_null(4));
    try testing.expectEqualSlices(u8, all_bytes, CP.new_from_any(&values[0]).byte_slice(4));
    try testing.expectEqual(@as(?[]u8, null), NP.new_null().byte_slice_or_null(4));
    try testing.expectEqual(@as(usize, 4), ptr.byte_slice(1).len);
    try testing.expectEqual(@as(usize, 0), ptr.byte_slice(0).len);
}

test "Pointer -> native pointer const, mutable, volatile, and allowzero casts" {
    var value: u32 align(16) = 42;
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const VP = PointerAdvanced(NATIVE, .{ .ELEMENT = u32, .VOLATILE = .VOLATILE });
    const AZ = PointerAdvanced(NATIVE, .{ .ELEMENT = u32, .ALLOW_ZERO = .ALLOW_ZERO });
    const ptr = P.new_from_any(&value);

    const const_ptr = ptr.to_const();
    try testing.expect(@TypeOf(const_ptr) == CP);
    try testing.expect(const_ptr.is_const());
    try testing.expect(!const_ptr.is_mutable());
    try testing.expectEqual(@as(u32, 42), const_ptr.get());
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(const_ptr.ptr_never_null()));

    const mutable_ptr = const_ptr.to_mutable();
    try testing.expect(@TypeOf(mutable_ptr) == P);
    mutable_ptr.set(43);
    try testing.expectEqual(@as(u32, 43), value);

    const nullable_ptr = ptr.to_nullable();
    try testing.expect(@TypeOf(nullable_ptr) == NP);
    try testing.expect(nullable_ptr.can_be_null());
    try testing.expectEqual(@as(?u32, 43), nullable_ptr.get_or_null());
    const non_null_ptr = nullable_ptr.to_non_null();
    try testing.expect(@TypeOf(non_null_ptr) == P);
    try testing.expectEqual(@as(u32, 43), non_null_ptr.get());

    const volatile_ptr = ptr.to_volatile();
    try testing.expect(@TypeOf(volatile_ptr) == VP);
    try testing.expect(VP.IS_VOLATILE);
    volatile_ptr.ptr_never_null().* = 44;
    try testing.expectEqual(@as(u32, 44), volatile_ptr.ptr_never_null().*);
    const not_volatile = volatile_ptr.remove_volatile();
    try testing.expect(@TypeOf(not_volatile) == P);
    try testing.expect(!P.IS_VOLATILE);
    try testing.expectEqual(@as(u32, 44), not_volatile.get());

    const allow_zero = ptr.to_allowzero();
    try testing.expect(@TypeOf(allow_zero) == AZ);
    try testing.expect(AZ.IS_ALLOW_ZERO);
    try testing.expect(allow_zero.is_mutable());
    try testing.expectEqual(@as(u32, 44), allow_zero.get());
    const no_allow_zero = allow_zero.remove_allowzero();
    try testing.expect(@TypeOf(no_allow_zero) == P);
    try testing.expectEqual(@as(u32, 44), no_allow_zero.get());

    // Address space helpers.
    try testing.expect(@TypeOf(ptr.to_normal_addrspace()) == P);
    try testing.expectEqual(@as(u32, 44), ptr.to_normal_addrspace().get());
}

test "Pointer -> native pointer element casts" {
    var word: u32 align(16) = 0x11223344;
    const ByteAligned = PointerAlign(u8, PowerOf2._16, NATIVE);
    const WordAligned = PointerAlign(u32, PowerOf2._16, NATIVE);
    const byte_ptr = ByteAligned.new_from_any(&word);

    const word_ptr = byte_ptr.cast_to_element(u32);
    try testing.expect(@TypeOf(word_ptr) == Pointer(u32, NATIVE));
    try testing.expectEqual(@as(u32, 0x11223344), word_ptr.get());

    const aligned_byte_ptr = word_ptr.cast_to_element_aligned(u8, PowerOf2._16);
    try testing.expect(@TypeOf(aligned_byte_ptr) == ByteAligned);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&word), aligned_byte_ptr.slice(4));

    const aligned_word_ptr = aligned_byte_ptr.cast_to_element_aligned(u32, PowerOf2._16);
    try testing.expect(@TypeOf(aligned_word_ptr) == WordAligned);
    try testing.expectEqual(@as(u32, 0x11223344), aligned_word_ptr.get());

    const sentinel_byte_ptr = word_ptr.cast_to_element_with_sentinel(u8, 0);
    try testing.expect(@TypeOf(sentinel_byte_ptr) == SentU8);
    try testing.expect(sentinel_byte_ptr.has_sentinel());
    try testing.expectEqual(@as(u8, 0), sentinel_byte_ptr.sentinel_value());

    const sentinel_aligned_byte_ptr = word_ptr.cast_to_element_with_sentinel_aligned(u8, 0, PowerOf2._16);
    try testing.expect(sentinel_aligned_byte_ptr.has_sentinel());
    try testing.expectEqual(@as(u8, 0), sentinel_aligned_byte_ptr.sentinel_value());
    try testing.expectEqual(@as(usize, 16), sentinel_aligned_byte_ptr.ptr_alignment());
    try testing.expectEqual(@as(u8, 0x44), sentinel_aligned_byte_ptr.get());

    var sentinel_words: [2]u32 align(16) = .{ 0, 0 };
    const sentinel_word_bytes: [*]u8 = @ptrCast(&sentinel_words[0]);
    sentinel_word_bytes[0] = 0x41;
    const sentinel_word_ptr = Pointer(u32, NATIVE).new_from_any(&sentinel_words[0]).cast_to_element_with_sentinel(u8, 0);
    try testing.expectEqual(@as(usize, 1), sentinel_word_ptr.find_len_from_sentinel());
}

test "Pointer -> native pointer alignment" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const AP = PointerAlign(u32, PowerOf2._16, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const NAP = NullablePointerAlign(u32, PowerOf2._16, NATIVE);
    const C = ConstPointerAlign(u32, PowerOf2._16, NATIVE);
    const ptr = AP.new_from_any(&values[0]);

    try testing.expect(AP.HAS_SPECIFIC_ALIGN);
    try testing.expect(!AP.USES_NATIVE_ALIGN);
    try testing.expect(!AP.IS_NATIVE_ALIGNED);
    try testing.expectEqual(@as(usize, 16), AP.ALIGN);
    try testing.expectEqual(PowerOf2._16, AP.ALIGN_POW2);

    try testing.expect(ptr.is_aligned(16));
    try testing.expect(ptr.is_aligned_pow_2(PowerOf2._16));
    try testing.expect(ptr.is_aligned_log_2(4));
    try testing.expect(ptr.is_aligned_std_mem(std.mem.Alignment.@"16"));
    ptr.assert_aligned(16, @src());
    ptr.assert_aligned_pow_2(PowerOf2._16, @src());
    ptr.assert_aligned_log_2(4, @src());
    ptr.assert_aligned_std_mem(std.mem.Alignment.@"16", @src());

    try testing.expect(@TypeOf(ptr.ptr()) == *align(16) u32);
    try testing.expect(@TypeOf(ptr.ptr_many()) == [*]align(16) u32);
    try testing.expect(@TypeOf(ptr.slice(1)) == []align(16) u32);
    try testing.expectEqual(@as(u32, 1), ptr.get());
    try testing.expectEqual(@as(u32, 3), ptr.increment(2).get());
    try testing.expectEqual(@as(u32, 4), ptr.slice(4)[3]);

    // Moving an over-aligned pointer yields a pointer with the element's
    // natural alignment; it can no longer claim the stronger alignment.
    const moved = ptr.increment(1);
    try testing.expect(@TypeOf(moved) == P);
    try testing.expect(@TypeOf(moved) != AP);
    try testing.expectEqual(@as(u32, 2), moved.get());

    const same_align = P.new_from_any(&values[0]).to_specific_align(PowerOf2._16);
    try testing.expect(@TypeOf(same_align) == AP);
    try testing.expectEqual(@as(u32, 1), same_align.get());

    const native_again = ptr.to_native_align();
    try testing.expect(@TypeOf(native_again) == P);
    try testing.expectEqual(@as(u32, 1), native_again.get());

    const null_ap = NP.new_null().to_specific_align(PowerOf2._16);
    try testing.expect(@TypeOf(null_ap) == NAP);
    try testing.expect(null_ap.is_null());

    const const_ap = AP.new_from_any(&values[0]).to_const();
    try testing.expect(@TypeOf(const_ap) == C);
    try testing.expectEqual(@as(u32, 1), const_ap.get());
}

test "Pointer -> native pointer complete and unchecked casts" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const NCP = NullableConstPointer(u32, NATIVE);
    const VP = PointerAdvanced(NATIVE, .{ .ELEMENT = u32, .VOLATILE = .VOLATILE });
    const ptr = P.new_from_any(&values[0]);

    const const_cast = ptr.complete_cast_to(.{ .ELEMENT = u32, .MUTABILITY = .CONST });
    try testing.expect(@TypeOf(const_cast) == CP);
    try testing.expectEqual(@as(u32, 1), const_cast.get());

    const nullable_cast = ptr.complete_cast_to(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE });
    try testing.expect(@TypeOf(nullable_cast) == NP);
    try testing.expectEqual(@as(?u32, 1), nullable_cast.get_or_null());

    const nullable_const_cast = ptr.complete_cast_to(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE, .MUTABILITY = .CONST });
    try testing.expect(@TypeOf(nullable_const_cast) == NCP);
    try testing.expectEqual(@as(?u32, 1), nullable_const_cast.get_or_null());

    const non_null_cast = nullable_cast.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(non_null_cast) == P);
    try testing.expectEqual(@as(u32, 1), non_null_cast.get());

    const volatile_cast = ptr.complete_cast_to(.{ .ELEMENT = u32, .VOLATILE = .VOLATILE });
    try testing.expect(@TypeOf(volatile_cast) == VP);
    try testing.expectEqual(@as(u32, 1), volatile_cast.get());
    const unvolatile_cast = volatile_cast.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(unvolatile_cast) == P);
    try testing.expectEqual(@as(u32, 1), unvolatile_cast.get());

    const narrowed = ptr.complete_cast_to(.{ .ELEMENT = u8 });
    try testing.expect(@TypeOf(narrowed) == Pointer(u8, NATIVE));
    try testing.expectEqual(@as(u8, 1), narrowed.get());
    const widened = narrowed.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(widened) == P);
    try testing.expectEqual(@as(u32, 1), widened.get());

    const explicit_align = ptr.complete_cast_to(.{ .ELEMENT = u32, .ALIGNMENT = PowerOf2._8 });
    try testing.expect(@TypeOf(explicit_align) == PointerAlign(u32, PowerOf2._8, NATIVE));
    try testing.expectEqual(@as(u32, 1), explicit_align.get());

    const null_preserved = NP.new_null().complete_cast_to(.{ .ELEMENT = u16, .NULLABILITY = .NULLABLE });
    try testing.expect(@TypeOf(null_preserved) == NullablePointer(u16, NATIVE));
    try testing.expect(null_preserved.is_null());

    var sentinel_bytes: [8]u8 align(16) = .{ 'a', 'b', 0, 0, 0, 0, 0, 0 };
    const sentinel_cast = Pointer(u8, NATIVE).new_from_any(&sentinel_bytes[0]).complete_cast_to(.{ .ELEMENT = u8, .SENTINEL = SENTINEL_ZERO_OPAQUE });
    try testing.expect(@TypeOf(sentinel_cast) == SentU8);
    try testing.expect(sentinel_cast.has_sentinel());
    try testing.expectEqual(@as(usize, 2), sentinel_cast.find_len_from_sentinel());

    const unchecked = ptr.unchecked_cast_to(.{ .ELEMENT = u8 });
    try testing.expect(@TypeOf(unchecked) == Pointer(u8, NATIVE));
    try testing.expectEqual(ptr.addr(), unchecked.addr());

    const unchecked_same = ptr.unchecked_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(unchecked_same) == P);
    try testing.expectEqual(@as(u32, 1), unchecked_same.get());
}

test "Pointer -> native pointer elements between and range helpers" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);
    const last = ptr.increment(3);

    try testing.expectEqual(@as(usize, 3), ptr.elements_between_self_low_other_high_exclude(last));
    try testing.expectEqual(@as(usize, 4), ptr.elements_between_self_low_other_high_include(last));
    try testing.expectEqual(@as(usize, 3), last.elements_between_self_high_other_low_exclude(ptr));
    try testing.expectEqual(@as(usize, 4), last.elements_between_self_high_other_low_include(ptr));
    try testing.expectEqual(@as(usize, 3), ptr.elements_between_exclude_high(last));
    try testing.expectEqual(@as(usize, 4), ptr.elements_between_include_high(last));
    try testing.expectEqual(@as(usize, 3), last.elements_between_exclude_high(ptr));
    try testing.expectEqual(@as(usize, 4), last.elements_between_include_high(ptr));

    try testing.expectEqual(@as(?usize, 3), ptr.elements_between_exclude_high_or_null(last));
    try testing.expectEqual(@as(usize, 0), ptr.to_nullable().elements_between_exclude_high_orelse_0(NP.new_null()));
    try testing.expectEqual(@as(?usize, null), NP.new_null().elements_between_exclude_high_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(?usize, null), NP.new_null().elements_between_self_low_other_high_exclude_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(usize, 0), NP.new_null().elements_between_self_low_other_high_exclude_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?usize, null), NP.new_null().elements_between_self_low_other_high_include_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(usize, 0), NP.new_null().elements_between_self_low_other_high_include_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?usize, null), NP.new_null().elements_between_self_high_other_low_exclude_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(usize, 0), NP.new_null().elements_between_self_high_other_low_exclude_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?usize, null), NP.new_null().elements_between_self_high_other_low_include_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(usize, 0), NP.new_null().elements_between_self_high_other_low_include_orelse_0(ptr.to_nullable()));

    try testing.expect(ptr.increment(1).is_within_range_exclude_high(ptr, ptr.increment(4)));
    try testing.expect(!ptr.increment(4).is_within_range_exclude_high(ptr, ptr.increment(4)));
    try testing.expect(ptr.increment(4).is_within_range_include_high(ptr, ptr.increment(4)));
    try testing.expect(!ptr.increment(5).is_within_range_include_high(ptr, ptr.increment(4)));
    ptr.assert_is_within_range_exclude_high(ptr, ptr.increment(1), @src());
    ptr.assert_is_within_range_include_high(ptr, ptr.increment(0), @src());
}

test "Pointer -> native pointer comparison and hashing" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);
    const same = P.new_from_any(&values[0]);

    try testing.expect(ptr.eql(same));
    try testing.expect(!ptr.eql(ptr.increment(1)));
    try testing.expect(ptr.eql_native_address(&values[0]));
    try testing.expect(ptr.eql_native_address(@as(?*u32, &values[0])));
    try testing.expect(ptr.eql_native_address(values[0..1]));
    try testing.expect(!ptr.eql_native_address(@as(?*u32, null)));
    try testing.expectEqual(std.math.Order.eq, ptr.order(same));
    try testing.expectEqual(std.math.Order.lt, ptr.order(ptr.increment(1)));
    try testing.expectEqual(std.math.Order.gt, ptr.increment(1).order(ptr));
    try testing.expectEqual(ptr.hash(), same.hash());
    try testing.expectEqual(ptr.simple_hash(), same.simple_hash());
    try testing.expect(ptr.hash() != ptr.increment(1).hash());
    try testing.expect(ptr.simple_hash() != ptr.increment(1).simple_hash());

    const null_ptr = NP.new_null();
    try testing.expectEqual(std.math.Order.lt, null_ptr.order(ptr.to_nullable()));
    try testing.expect(null_ptr.eql(NP.new_from(null)));
    try testing.expect(!null_ptr.eql(ptr.to_nullable()));
    try testing.expectEqual(null_ptr.hash(), NP.new_null().hash());
    try testing.expectEqual(null_ptr.simple_hash(), NP.new_null().simple_hash());
}

test "Pointer -> native pointer signed distances" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);
    const third = ptr.increment(3);

    try testing.expectEqual(@as(isize, 12), third.bytes_from(ptr));
    try testing.expectEqual(@as(isize, -12), ptr.bytes_from(third));
    try testing.expectEqual(@as(isize, 3), third.elements_from(ptr));
    try testing.expectEqual(@as(isize, -3), ptr.elements_from(third));
    try testing.expectEqual(@as(isize, 12), third.offset_from(ptr));
    try testing.expectEqual(@as(isize, -12), ptr.offset_from(third));
    try testing.expectEqual(@as(isize, 0), ptr.bytes_from(ptr));

    const null_ptr = NP.new_null();
    const ptr_nullable = ptr.to_nullable();
    const third_nullable = third.to_nullable();
    try testing.expectEqual(@as(?isize, null), null_ptr.bytes_from_or_null(ptr_nullable));
    try testing.expectEqual(@as(isize, 0), null_ptr.bytes_from_orelse_0(ptr_nullable));
    try testing.expectEqual(@as(?isize, 3), third_nullable.elements_from_or_null(ptr_nullable));
    try testing.expectEqual(@as(isize, 3), third_nullable.elements_from_orelse_0(ptr_nullable));
    try testing.expectEqual(@as(?isize, 12), third_nullable.offset_from_or_null(ptr_nullable));
    try testing.expectEqual(@as(isize, 12), third_nullable.offset_from_orelse_0(ptr_nullable));
    try testing.expectEqual(@as(?isize, null), null_ptr.elements_from_or_null(ptr_nullable));
    try testing.expectEqual(@as(isize, 0), null_ptr.elements_from_orelse_0(ptr_nullable));
    try testing.expectEqual(@as(?isize, null), null_ptr.offset_from_or_null(ptr_nullable));
    try testing.expectEqual(@as(isize, 0), null_ptr.offset_from_orelse_0(ptr_nullable));
}

test "Pointer -> native pointer memcopy, memmove, and memset" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);

    var dst = [4]u32{ 0, 0, 0, 0 };
    ptr.memcopy_to(&dst);
    try testing.expectEqualSlices(u32, &[_]u32{ 1, 2, 3, 4 }, &dst);

    ptr.memcopy_from(&[_]u32{ 5, 6, 7, 8 });
    try testing.expectEqualSlices(u32, &[_]u32{ 5, 6, 7, 8 }, &values);

    ptr.memset(0, 4);
    try testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });
    ptr.memmove_to(ptr.increment(1).slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 1, 1, 2, 3 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });
    ptr.increment(1).memmove_to(ptr.slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 2, 3, 4, 4 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });
    ptr.memmove_from(CP.new_from_any(&values[0]).increment(1).slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 2, 3, 4, 4 }, &values);

    const const_ptr = CP.new_from_any(&values[0]);
    var read_dst = [4]u32{ 0, 0, 0, 0 };
    const_ptr.memcopy_to(&read_dst);
    try testing.expectEqualSlices(u32, &values, &read_dst);
}

test "Pointer -> native pointer atomic operations" {
    var atomic_value: u32 align(@alignOf(u32)) = 1;
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const atomic_ptr = P.new_from_any(&atomic_value);

    try testing.expectEqual(@as(u32, 1), atomic_ptr.atomic_load(.seq_cst));
    atomic_ptr.atomic_store(2, .seq_cst);
    try testing.expectEqual(@as(u32, 2), atomic_ptr.atomic_load(.acquire));
    try testing.expectEqual(@as(u32, 2), atomic_ptr.atomic_read_modify_write(.Xchg, 3, .seq_cst));
    try testing.expectEqual(@as(u32, 3), atomic_value);

    try testing.expectEqual(@as(?u32, null), atomic_ptr.atomic_compare_exchange_strong(3, 4, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 4), atomic_value);
    try testing.expectEqual(@as(?u32, 4), atomic_ptr.atomic_compare_exchange_strong(99, 5, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 4), atomic_value);
    try testing.expectEqual(@as(?u32, null), atomic_ptr.atomic_compare_exchange_strong(4, 5, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 5), atomic_value);
    try testing.expectEqual(@as(u32, 5), CP.new_from_any(&atomic_value).atomic_load(.seq_cst));

    // Weak compare-exchange may spuriously fail, so only its failure case is
    // checked for a definite value.
    const weak_result = atomic_ptr.atomic_compare_exchange_weak(99, 6, .seq_cst, .seq_cst);
    if (weak_result) |previous| {
        try testing.expectEqual(@as(u32, 5), previous);
        try testing.expectEqual(@as(u32, 5), atomic_value);
    }
}

test "Pointer -> native zero-sized element pointers" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const VoidPtr = PointerAdvanced(NATIVE, .{ .ELEMENT = void });
    const ptr = VoidPtr.new_from_any(@as(*void, @ptrCast(&values[0])));

    try testing.expect(VoidPtr.ZERO_SIZE_ELEM);
    try testing.expect(ptr.elem_is_zero_sized());
    try testing.expect(ptr.not_null());
    _ = ptr.get();
    _ = ptr.get_at_index(10);
}

//*******************************
// STATIC ADDRESS RESOLVER SOURCES
//*******************************

test "Pointer -> static resolver source metadata" {
    try testing.expect(RES_U8.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(u8, std.math.maxInt(u8)), RES_U8.STATIC_RESOLVER.NULL_VAL());
    try testing.expect(RES_U8.STATIC_RESOLVER.LOCAL_TYPE() == u8);
    try testing.expect(RES_U8.InternalPtr(.{ .ELEMENT = u8 }) == u8);
    try testing.expectEqual(@as(u8, std.math.maxInt(u8)), RES_U8.InternalPtrDefault(.{ .ELEMENT = u8, .NULLABILITY = .NULLABLE }));

    try testing.expect(RES_U16.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(u16, std.math.maxInt(u16)), RES_U16.STATIC_RESOLVER.NULL_VAL());
    try testing.expect(RES_U16.STATIC_RESOLVER.LOCAL_TYPE() == u16);
    try testing.expect(RES_U16.InternalPtr(.{ .ELEMENT = u8 }) == u16);

    try testing.expect(RES_U32.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(u32, std.math.maxInt(u32)), RES_U32.STATIC_RESOLVER.NULL_VAL());
    try testing.expect(RES_U32.STATIC_RESOLVER.LOCAL_TYPE() == u32);
    try testing.expect(RES_U32.InternalPtr(.{ .ELEMENT = u8 }) == u32);

    try testing.expect(RES_U64.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(u64, std.math.maxInt(u64)), RES_U64.STATIC_RESOLVER.NULL_VAL());
    try testing.expect(RES_U64.STATIC_RESOLVER.LOCAL_TYPE() == u64);
    try testing.expect(RES_U64.InternalPtr(.{ .ELEMENT = u8 }) == u64);

    try testing.expect(RES_USIZE.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(usize, std.math.maxInt(usize)), RES_USIZE.STATIC_RESOLVER.NULL_VAL());
    try testing.expect(RES_USIZE.STATIC_RESOLVER.LOCAL_TYPE() == usize);
    try testing.expect(RES_USIZE.InternalPtr(.{ .ELEMENT = u8 }) == usize);

    try testing.expect(!RES_U32_NO_NULL.STATIC_RESOLVER.CAN_BE_NULL());
    try testing.expectEqual(@as(u32, std.math.maxInt(u32)), RES_U32_NO_NULL.STATIC_RESOLVER.NULL_VAL());

    try testing.expect(RES_U8.ResolverFnInit() == &resolve_u8);
    try testing.expect(RES_U8.IncrementFnInit() == &increment_u8);
    try testing.expect(RES_U8.DecrementFnInit() == &decrement_u8);
    try testing.expect(RES_U8.ResolverFn() == *const fn (u8) usize);
    try testing.expect(RES_U8.IncrementFn() == *const fn (u8, usize) u8);
    try testing.expect(RES_U8.DecrementFn() == *const fn (u8, usize) u8);

    try testing.expect(NATIVE.InternalPtr(.{ .ELEMENT = u32 }) == [*]u32);
    try testing.expect(NATIVE.InternalPtr(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE }) == ?[*]u32);
    try testing.expect(NATIVE.InternalPtrDefault(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE }) == null);
    try testing.expect(NATIVE.ResolverFn() == void);
    try testing.expect(NATIVE.IncrementFn() == void);
    try testing.expect(NATIVE.DecrementFn() == void);
    try testing.expect(@TypeOf(NATIVE.ResolverFnInit()) == void);
    try testing.expect(@TypeOf(NATIVE.IncrementFnInit()) == void);
    try testing.expect(@TypeOf(NATIVE.DecrementFnInit()) == void);

    // The `StaticAddressResolver` can also be constructed directly.
    const DIRECT: StaticAddressResolver = .{
        .FUNCS = .{ .U8 = .{
            .RESOLVE = &resolve_u8,
            .INCREMENT = &increment_u8,
            .DECREMENT = &decrement_u8,
        } },
    };
    try testing.expect(std.meta.eql(PointerSource.static_address_resolver(DIRECT), RES_U8));
}

test "Pointer -> static resolver pointer basics with u32 handles" {
    @memset(&global_test_buffer, 0);
    const P = Pointer(u32, RES_U32);
    var ptr = P.new_from(8);

    try testing.expect(ptr.is_global_resolver());
    try testing.expect(!ptr.is_native());
    try testing.expect(ptr.not_null());
    try testing.expect(!ptr.can_be_null());
    try testing.expect(P.USE_STATIC_RESOLVER);
    try testing.expect(!P.IS_NATIVE);
    try testing.expect(@TypeOf(ptr.internal) == u32);
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr());
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr_no_align_check());
    try testing.expectEqual(@as(?usize, buffer_base() + 8), ptr.addr_or_null());
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr_orelse_0());
    try testing.expect(P.new_from(8).eql(ptr));
    try testing.expect(P.new_from_any(@as(u32, 8)).eql(ptr));
    try testing.expect(!ptr.eql(P.new_from(12)));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[8]), @intFromPtr(ptr.ptr_never_null()));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[8]), @intFromPtr(ptr.ptr_many_never_null()));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[8]), @intFromPtr(ptr.ptr()));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[8]), @intFromPtr(ptr.ptr_c()));

    ptr.set(0xAABBCCDD);
    var expected: u32 = 0xAABBCCDD;
    try testing.expectEqualSlices(u8, std.mem.asBytes(&expected), global_test_buffer[8..12]);
    try testing.expectEqual(@as(u32, 0xAABBCCDD), ptr.get());

    ptr.set_at_index(2, 0x11223344);
    expected = 0x11223344;
    try testing.expectEqualSlices(u8, std.mem.asBytes(&expected), global_test_buffer[16..20]);
    try testing.expectEqual(@as(u32, 0x11223344), ptr.get_at_index(2));

    const next = ptr.increment(2);
    try testing.expectEqual(@as(usize, buffer_base() + 16), next.addr());
    try testing.expectEqual(@as(u32, 0x11223344), next.get());
    const back = next.decrement(2);
    try testing.expectEqual(@as(usize, buffer_base() + 8), back.addr());
    try testing.expectEqual(@as(u32, 0xAABBCCDD), back.get());
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.move(2).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.move(-1).move(1).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.increment_assert_contiguous(2).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.increment_assert_contiguous(2).decrement_assert_contiguous(2).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.move_assert_contiguous(2).addr());

    ptr.increment_in_place(2);
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.addr());
    ptr.decrement_in_place(2);
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr());
    ptr.move_in_place(2);
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.addr());
    ptr.move_in_place(-2);
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr());
    ptr.increment_in_place_assert_contiguous(2);
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.addr());
    ptr.decrement_in_place_assert_contiguous(2);
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr());
    ptr.move_in_place_assert_contiguous(2);
    try testing.expectEqual(@as(usize, buffer_base() + 16), ptr.addr());
    ptr.move_in_place_assert_contiguous(-2);
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.addr());

    const slice = ptr.slice(2);
    ptr.set_at_index(1, 0x11223344);
    try testing.expectEqual(@as(usize, 2), slice.len);
    try testing.expectEqual(@as(u32, 0xAABBCCDD), slice[0]);
    try testing.expectEqual(@as(u32, 0x11223344), slice[1]);

    try testing.expectEqual(std.math.Order.lt, ptr.order(ptr.increment(1)));
    try testing.expectEqual(std.math.Order.eq, ptr.order(P.new_from(8)));
    try testing.expectEqual(ptr.hash(), P.new_from(8).hash());
    try testing.expectEqual(ptr.simple_hash(), P.new_from(8).simple_hash());
    try testing.expectEqual(@as(isize, 8), ptr.increment(2).bytes_from(ptr));
    try testing.expectEqual(@as(isize, 2), ptr.increment(2).elements_from(ptr));
    try testing.expectEqual(@as(usize, 2), ptr.elements_between_exclude_high(ptr.increment(2)));
    try testing.expect(ptr.increment(1).is_within_range_exclude_high(ptr, ptr.increment(2)));

    const bytes = ptr.byte_slice(2);
    try testing.expectEqual(@as(usize, 8), bytes.len);
    try testing.expectEqualSlices(u8, global_test_buffer[8..16], bytes);
}

test "Pointer -> static resolver pointer nullability" {
    @memset(&global_test_buffer, 0);
    const NP = NullablePointer(u32, RES_U32);
    const null_ptr = NP.new_null();
    const non_null = NP.new_from(4);

    try testing.expect(null_ptr.is_null());
    try testing.expect(!null_ptr.not_null());
    try testing.expectEqual(@as(u32, std.math.maxInt(u32)), null_ptr.internal);
    try testing.expectEqual(@as(u32, std.math.maxInt(u32)), NP.INTERNAL_PTR_DEFAULT);
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expectEqual(@as(usize, 0), null_ptr.addr_orelse_0());
    try testing.expectEqual(@as(?[*]u32, null), null_ptr.ptr_many_or_null());
    try testing.expectEqual(@as(?[]u32, null), null_ptr.slice_or_null(2));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 99), null_ptr.get_orelse(99));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_at_index_or_null(0));
    try testing.expectEqual(@as(u32, 99), null_ptr.get_at_index_orelse(0, 99));
    try testing.expectEqual(std.math.Order.lt, null_ptr.order(non_null));
    try testing.expect(null_ptr.eql(NP.new_null()));
    try testing.expect(null_ptr.eql(NP.new_from(std.math.maxInt(u32))));
    try testing.expect(!null_ptr.eql(non_null));
    try testing.expect(!null_ptr.eql_native_address(&global_test_buffer[0]));

    const null_aligned = null_ptr.to_specific_align(PowerOf2._16);
    try testing.expect(null_aligned.is_null());
    try testing.expect(@TypeOf(null_aligned) == NullablePointerAlign(u32, PowerOf2._16, RES_U32));

    try testing.expect(null_ptr.increment_if_not_null(2).is_null());
    try testing.expect(null_ptr.decrement_if_not_null(2).is_null());
    try testing.expect(null_ptr.move_if_not_null(2).is_null());
    try testing.expectEqual(@as(?u32, 0), non_null.increment_if_not_null(2).get_or_null());

    non_null.set(0x55);
    try testing.expectEqual(@as(?u32, 0x55), non_null.get_or_null());
    non_null.set_if_not_null(0x66);
    try testing.expectEqual(@as(?u32, 0x66), non_null.get_or_null());
    null_ptr.set_if_not_null(0x77);
    try testing.expectEqual(@as(?u32, 0x66), non_null.get_or_null());

    var changeable = NP.new_from(4);
    changeable.set_null();
    try testing.expect(changeable.is_null());
    try testing.expect(changeable.eql(null_ptr));

    const from_non_null = NP.new_null();
    try testing.expect(from_non_null.is_null());
    try testing.expect(@TypeOf(from_non_null) == NP);

    try testing.expectEqual(@as(?usize, null), null_ptr.elements_between_exclude_high_or_null(non_null));
    try testing.expectEqual(@as(usize, 0), null_ptr.elements_between_exclude_high_orelse_0(non_null));
    try testing.expectEqual(@as(?isize, null), null_ptr.bytes_from_or_null(non_null));
    try testing.expectEqual(@as(isize, 0), null_ptr.bytes_from_orelse_0(non_null));
    try testing.expectEqual(@as(?isize, null), null_ptr.elements_from_or_null(non_null));
    try testing.expectEqual(@as(isize, 0), null_ptr.elements_from_orelse_0(non_null));
}

test "Pointer -> static resolver compact handle types" {
    @memset(&global_test_buffer, 0);

    const U8Ptr = Pointer(u8, RES_U8);
    const u8_ptr = U8Ptr.new_from(3);
    try testing.expect(@TypeOf(u8_ptr.internal) == u8);
    u8_ptr.set(0x7F);
    try testing.expectEqual(@as(u8, 0x7F), global_test_buffer[3]);
    try testing.expectEqual(@as(u8, 0x7F), u8_ptr.get());
    try testing.expectEqual(@as(usize, buffer_base() + 4), u8_ptr.increment(1).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 3), u8_ptr.increment(1).decrement(1).addr());
    try testing.expectEqual(@as(usize, 2), u8_ptr.slice(2).len);

    const U16Ptr = Pointer(u16, RES_U16);
    const u16_ptr = U16Ptr.new_from(6);
    try testing.expect(@TypeOf(u16_ptr.internal) == u16);
    u16_ptr.set(0xBEEF);
    try testing.expectEqual(@as(u16, 0xBEEF), u16_ptr.get());
    try testing.expectEqual(@as(usize, buffer_base() + 6), u16_ptr.addr());
    try testing.expectEqual(@as(usize, buffer_base() + 8), u16_ptr.increment(1).addr());

    const U64Ptr = Pointer(u64, RES_U64);
    const u64_ptr = U64Ptr.new_from(8);
    try testing.expect(@TypeOf(u64_ptr.internal) == u64);
    u64_ptr.set(0x1122334455667788);
    try testing.expectEqual(@as(u64, 0x1122334455667788), u64_ptr.get());
    try testing.expectEqual(@as(usize, buffer_base() + 8), u64_ptr.addr());

    const UsizePtr = Pointer(usize, RES_USIZE);
    const usize_ptr = UsizePtr.new_from(16);
    try testing.expect(@TypeOf(usize_ptr.internal) == usize);
    usize_ptr.set(0x1234);
    try testing.expectEqual(@as(usize, 0x1234), usize_ptr.get());
    try testing.expectEqual(@as(usize, buffer_base() + 16), usize_ptr.addr());

    // Nullable variants use each local type's max value as the null handle.
    try testing.expect(NullablePointer(u8, RES_U8).new_from(std.math.maxInt(u8)).is_null());
    try testing.expect(NullablePointer(u16, RES_U16).new_from(std.math.maxInt(u16)).is_null());
    try testing.expect(NullablePointer(u64, RES_U64).new_from(std.math.maxInt(u64)).is_null());
    try testing.expect(NullablePointer(usize, RES_USIZE).new_from(std.math.maxInt(usize)).is_null());
}

test "Pointer -> static resolver without a null value" {
    @memset(&global_test_buffer, 0);
    const P = Pointer(u32, RES_U32_NO_NULL);
    var ptr = P.new_from(4);

    try testing.expect(!P.CAN_BE_NULL);
    try testing.expect(P.NEVER_NULL);
    try testing.expect(!ptr.is_null());
    try testing.expect(ptr.not_null());
    ptr.set(0x13579BDF);
    try testing.expectEqual(@as(u32, 0x13579BDF), ptr.get());
    try testing.expectEqual(@as(usize, buffer_base() + 4), ptr.addr());
    try testing.expectEqual(@as(usize, buffer_base() + 8), ptr.increment(1).addr());
    try testing.expect(P.USE_STATIC_RESOLVER);
}

test "Pointer -> static resolver address granularity" {
    @memset(&global_test_buffer, 0);
    const P = Pointer(u32, RES_U16_GRANULARITY_16);

    try testing.expectEqual(PowerOf2._16, RES_U16_GRANULARITY_16.STATIC_RESOLVER.ADDRESS_GRANULARITY);
    try testing.expect(RES_U16_GRANULARITY_16.STATIC_RESOLVER.ADDRESS_GRANULARITY.greater_than(PowerOf2._1));
    try testing.expect(RES_U16_GRANULARITY_16.InternalPtr(.{ .ELEMENT = u32 }) == u16);

    var ptr = P.new_from(0);
    try testing.expectEqual(@as(usize, buffer_base()), ptr.addr());
    ptr.set(0x01020304);
    try testing.expectEqual(@as(u32, 0x01020304), ptr.get());

    const next = ptr.increment(4);
    try testing.expectEqual(@as(usize, buffer_base() + 16), next.addr());
    next.set(0x05060708);
    try testing.expectEqual(@as(u32, 0x05060708), next.get());
    try testing.expectEqual(@as(usize, buffer_base()), next.decrement(4).addr());
    try testing.expectEqual(@as(usize, buffer_base() + 32), ptr.move(8).addr());
    try testing.expectEqual(@as(usize, buffer_base()), ptr.move(8).move(-8).addr());

    const slice = ptr.slice(2);
    ptr.set_at_index(1, 0x05060708);
    try testing.expectEqual(@as(usize, 2), slice.len);
    try testing.expectEqual(@as(u32, 0x01020304), slice[0]);
    try testing.expectEqual(@as(u32, 0x05060708), slice[1]);
    try testing.expectEqual(@as(usize, 4), ptr.byte_slice(1).len);
}

test "Pointer -> static resolver element casts, sentinels, and opaque-free casts" {
    const granularity_word: u32 = 0x11223344;
    const granularity_word_bytes = std.mem.asBytes(&granularity_word);
    @memcpy(global_test_buffer[0..4], granularity_word_bytes);
    global_test_buffer[4] = 'x';
    global_test_buffer[5] = 0;

    const BytePtr = Pointer(u8, RES_U32);
    const WordPtr = Pointer(u32, RES_U32);
    const bytes = BytePtr.new_from(0);
    const words = bytes.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(words) == WordPtr);
    try testing.expectEqual(granularity_word, words.get());

    const back_to_bytes = words.cast_to_element(u8);
    try testing.expectEqualSlices(u8, granularity_word_bytes, back_to_bytes.slice(4));

    const sentinel_bytes = SentU8Resolver.new_from(4);
    try testing.expect(sentinel_bytes.has_sentinel());
    try testing.expectEqual(@as(u8, 0), sentinel_bytes.sentinel_value());
    try testing.expectEqual(@as(usize, 1), sentinel_bytes.find_len_from_sentinel());
    try testing.expectEqualSlices(u8, global_test_buffer[4..5], sentinel_bytes.slice_find_len_from_sentinel());

    const null_bytes = NullablePointer(u8, RES_U32).new_null();
    const null_words = null_bytes.complete_cast_to(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE });
    try testing.expect(null_words.is_null());
    try testing.expectEqual(@as(type, u32), @TypeOf(null_words.internal));
}

//**************************
// POINTER DEFINITION HELPERS
//**************************

test "Pointer -> make pointer definition helpers" {
    const base = MakePtrDef{ .ELEMENT = u32 };
    try testing.expectEqual(AllowZero.NO_ALLOW_ZERO, base.ALLOW_ZERO);
    try testing.expectEqual(Nullability.NEVER_NULL, base.NULLABILITY);
    try testing.expectEqual(Mutability.MUTABLE, base.MUTABILITY);
    try testing.expectEqual(std.lang.Type.Pointer.Size.one, base.SIZE);
    try testing.expectEqual(@as(type, u32), base.ELEMENT);
    try testing.expect(base.SENTINEL == null);
    try testing.expect(base.ALIGNMENT == null);
    try testing.expect(base.ADDRSPACE == null);
    try testing.expectEqual(Volatile.NOT_VOLATILE, base.VOLATILE);

    const modified = base
        .with_allow_zero(.ALLOW_ZERO)
        .with_nullability(.NULLABLE)
        .with_mutability(.CONST)
        .with_size_kind(.many)
        .with_element(u16)
        .with_align(PowerOf2._8)
        .with_volatile(.VOLATILE);

    try testing.expectEqual(AllowZero.ALLOW_ZERO, modified.ALLOW_ZERO);
    try testing.expectEqual(Nullability.NULLABLE, modified.NULLABILITY);
    try testing.expectEqual(Mutability.CONST, modified.MUTABILITY);
    try testing.expectEqual(std.lang.Type.Pointer.Size.many, modified.SIZE);
    try testing.expectEqual(@as(type, u16), modified.ELEMENT);
    try testing.expectEqual(@as(?PowerOf2, PowerOf2._8), modified.ALIGNMENT);
    try testing.expectEqual(Volatile.VOLATILE, modified.VOLATILE);
    try testing.expect(modified.SENTINEL == null);

    const with_sentinel = modified.with_sentinel(0x1234);
    try testing.expect(with_sentinel.SENTINEL != null);
    try testing.expect(PtrDefaultFromDef(modified) == null);

    const simple_sentinel = (MakePtrDef{ .ELEMENT = u16, .SIZE = .many }).with_sentinel(0x1234);
    try testing.expect(simple_sentinel.SENTINEL != null);
    try testing.expect(MakePtrFromDef(simple_sentinel) == [*:0x1234]u16);

    const cleared_sentinel = with_sentinel.with_sentinel(null);
    try testing.expect(cleared_sentinel.SENTINEL == null);

    const element_and_sentinel = base.with_size_kind(.many).with_element_and_sentinel(u8, 0);
    try testing.expect(element_and_sentinel.SENTINEL != null);
    try testing.expect(MakePtrFromDef(element_and_sentinel) == [*:0]u8);
    // Setting an element resets the sentinel.
    try testing.expect(element_and_sentinel.with_element(u16).SENTINEL == null);

    const c_def = base.with_c_pointer_constraints();
    try testing.expectEqual(AllowZero.ALLOW_ZERO, c_def.ALLOW_ZERO);
    try testing.expectEqual(Nullability.NEVER_NULL, c_def.NULLABILITY);
    try testing.expectEqual(std.lang.Type.Pointer.Size.c, c_def.SIZE);
    try testing.expect(c_def.SENTINEL == null);
    try testing.expect(c_def.ALIGNMENT == null);
    try testing.expect(c_def.ADDRSPACE == null);
    try testing.expect(MakePtrFromDef(c_def) == [*c]u32);

    const addrspace_def = base.with_addrspace(.generic);
    try testing.expectEqual(@as(?std.lang.AddressSpace, .generic), addrspace_def.ADDRSPACE);
    try testing.expect(MakePtrFromDef(addrspace_def) == *u32);
}

test "Pointer -> make pointer definition helpers without size" {
    const no_size = MakePtrDefNoSize{ .ELEMENT = u8 };
    const modified = no_size
        .with_allow_zero(.ALLOW_ZERO)
        .with_nullability(.NULLABLE)
        .with_mutability(.CONST)
        .with_element(u16)
        .with_align(PowerOf2._8)
        .with_volatile(.VOLATILE);

    try testing.expectEqual(AllowZero.ALLOW_ZERO, modified.ALLOW_ZERO);
    try testing.expectEqual(Nullability.NULLABLE, modified.NULLABILITY);
    try testing.expectEqual(Mutability.CONST, modified.MUTABILITY);
    try testing.expectEqual(@as(type, u16), modified.ELEMENT);
    try testing.expectEqual(@as(?PowerOf2, PowerOf2._8), modified.ALIGNMENT);
    try testing.expectEqual(Volatile.VOLATILE, modified.VOLATILE);

    const full = modified.to_make_ptr_def(.many);
    try testing.expectEqual(std.lang.Type.Pointer.Size.many, full.SIZE);
    try testing.expectEqual(Mutability.CONST, full.MUTABILITY);
    try testing.expectEqual(@as(type, u16), full.ELEMENT);
    try testing.expectEqual(@as(?PowerOf2, PowerOf2._8), full.ALIGNMENT);
    try testing.expectEqual(Volatile.VOLATILE, full.VOLATILE);
    try testing.expect(PtrDefaultFromDef(full) == null);

    const no_size_sentinel = no_size.with_sentinel(0);
    try testing.expect(no_size_sentinel.SENTINEL != null);
    try testing.expect(MakePtrFromDef(no_size_sentinel.to_make_ptr_def(.many)) == [*:0]u8);
    try testing.expect(no_size_sentinel.with_sentinel(null).SENTINEL == null);

    const c_def = no_size.with_c_pointer_constraints();
    try testing.expectEqual(std.lang.Type.Pointer.Size.c, c_def.to_make_ptr_def(.c).SIZE);
    try testing.expect(MakePtrFromDef(c_def.to_make_ptr_def(.c)) == [*c]u8);

    const addrspace_def = no_size.with_addrspace(.generic);
    try testing.expectEqual(@as(?std.lang.AddressSpace, .generic), addrspace_def.ADDRSPACE);
}

test "Pointer -> direct make pointer and default helpers" {
    try testing.expect(MakePtr(.NO_ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .one, u32, null, null, null, .NOT_VOLATILE) == *u32);
    try testing.expect(MakePtr(.NO_ALLOW_ZERO, .NEVER_NULL, .CONST, .many, u8, null, null, null, .NOT_VOLATILE) == [*]const u8);
    try testing.expect(MakePtr(.ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .one, u8, null, null, null, .NOT_VOLATILE) == *allowzero u8);
    try testing.expect(MakePtr(.NO_ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .many, u8, 0, null, null, .NOT_VOLATILE) == [*:0]u8);
    try testing.expect(MakePtr(.NO_ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .slice, u8, null, null, null, .NOT_VOLATILE) == []u8);
    try testing.expect(MakePtr(.ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .c, u8, null, null, null, .NOT_VOLATILE) == [*c]u8);
    try testing.expect(MakePtr(.NO_ALLOW_ZERO, .NEVER_NULL, .MUTABLE, .one, u8, null, null, null, .VOLATILE) == *volatile u8);

    const nullable_default: ?[*]u8 = PtrDefault(.NO_ALLOW_ZERO, .NULLABLE, .MUTABLE, .many, u8, null, null, null, .NOT_VOLATILE);
    try testing.expect(nullable_default == null);
    const null_from_def: ?[*]u8 = PtrDefaultFromDef(MakePtrDef{ .ELEMENT = u8, .SIZE = .many, .NULLABILITY = .NULLABLE });
    try testing.expect(null_from_def == null);
}

test "pointer source and wrapper helper functions agree" {
    try testing.expect(PointerSource.Pointer(NATIVE, u32) == Pointer(u32, NATIVE));
    try testing.expect(PointerSource.PointerAlign(NATIVE, u32, PowerOf2._16) == PointerAlign(u32, PowerOf2._16, NATIVE));
    try testing.expect(PointerSource.NullablePointer(NATIVE, u32) == NullablePointer(u32, NATIVE));
    try testing.expect(PointerSource.NullablePointerAlign(NATIVE, u32, PowerOf2._16) == NullablePointerAlign(u32, PowerOf2._16, NATIVE));
    try testing.expect(PointerSource.ConstPointer(NATIVE, u32) == ConstPointer(u32, NATIVE));
    try testing.expect(PointerSource.ConstPointerAlign(NATIVE, u32, PowerOf2._16) == ConstPointerAlign(u32, PowerOf2._16, NATIVE));
    try testing.expect(PointerSource.NullableConstPointer(NATIVE, u32) == NullableConstPointer(u32, NATIVE));
    try testing.expect(PointerSource.NullableConstPointerAlign(NATIVE, u32, PowerOf2._16) == NullableConstPointerAlign(u32, PowerOf2._16, NATIVE));

    try testing.expect(PointerAdvanced(NATIVE, .{ .ELEMENT = u32 }) == PtrDefless(u32));
    try testing.expect(Pointer(u8, RES_U8) == PointerSource.Pointer(RES_U8, u8));

    const P = Pointer(u32, NATIVE);
    try testing.expect(P.PtrMany == [*]u32);
    try testing.expect(P.PtrOne == *u32);
    try testing.expect(P.PtrC == [*c]u32);
    try testing.expect(P.Slice == []u32);
    try testing.expect(P.PtrManyNeverNull == [*]u32);
    try testing.expect(P.PtrOneNeverNull == *u32);
    try testing.expect(P.SliceNeverNull == []u32);
    try testing.expect(P.PtrManyNullable == ?[*]u32);
    try testing.expect(P.PtrOneNullable == ?*u32);
    try testing.expect(P.SliceNullable == ?[]u32);
    try testing.expect(P.NEVER_NULL);
    try testing.expect(!P.CAN_BE_NULL);
    try testing.expect(P.IS_MUTABLE);
    try testing.expect(!P.IS_CONST);
    try testing.expect(!P.IS_VOLATILE);
    try testing.expect(!P.HAS_SENTINEL);
    try testing.expect(!P.IS_ALLOW_ZERO);
    try testing.expectEqual(@as(?std.lang.AddressSpace, null), P.ADDRSPACE);
    try testing.expectEqual(@as(usize, 4), P.ALIGN);
    try testing.expectEqual(PowerOf2._4, P.ALIGN_POW2);

    const CP = ConstPointer(u8, NATIVE);
    try testing.expect(CP.PtrOne == *const u8);
    try testing.expect(CP.PtrMany == [*]const u8);
    try testing.expect(CP.PtrC == [*c]const u8);
    try testing.expect(CP.Slice == []const u8);

    const NP = NullablePointer(u32, NATIVE);
    try testing.expect(NP.PtrOne == ?*u32);
    try testing.expect(NP.Slice == ?[]u32);

    const SP = SentU8;
    try testing.expect(SP.PtrMany == [*:0]u8);
    try testing.expect(SP.PtrOne == *u8);
    try testing.expect(SP.Slice == [:0]u8);

    // Assertion helpers that are expected to pass.
    P.assert_mutable(@src());
    P.assert_native(@src());
    P.assert_not_overaligned(@src());
    P.assert_not_allowzero(@src());
    P.assert_not_volatile(@src());
    P.assert_normal_addrspace(@src());
    P.assert_not_zero_size_type(@src());
    var value: u32 = 1;
    P.new_from_any(&value).assert_not_null(@src());
    NP.new_null().assert_null(@src());
}
