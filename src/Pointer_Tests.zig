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
const PointerSourceKind = PointerModule.PointerSourceKind;
const PointerAdvanced = PointerModule.PointerAdvanced;
const AlignmentSource = PointerModule.AlignmentSource;
const Pointer = PointerModule.Pointer;
const NullablePointer = PointerModule.NullablePointer;
const ConstPointer = PointerModule.ConstPointer;
const NullableConstPointer = PointerModule.NullableConstPointer;
const PointerAlign = PointerModule.PointerAlign;
const NullablePointerAlign = PointerModule.NullablePointerAlign;
const ConstPointerAlign = PointerModule.ConstPointerAlign;
const NullableConstPointerAlign = PointerModule.NullableConstPointerAlign;
const MakePtrDef = PointerModule.MakePtrDef;
const MakePtrDefNoSize = PointerModule.MakePtrDefNoSize;
const MakePtrFromDef = PointerModule.MakePtrFromDef;
const PtrDefaultFromDef = PointerModule.PtrDefaultFromDef;
const PtrDefault = PointerModule.PtrDefault;
const AllowZero = PointerModule.AllowZero;
const Nullability = PointerModule.Nullability;
const Mutability = PointerModule.Mutability;
const Volatile = PointerModule.Volatile;

const NATIVE = PointerSource.native_pointer();

var global_test_buffer: [16]u8 align(16) = undefined;

fn resolve_buffer_offset(offset: u32) usize {
    return @intFromPtr(&global_test_buffer[0]) + offset;
}
fn resolve_buffer_offset_u16(offset: u16) usize {
    return @intFromPtr(&global_test_buffer[0]) + offset;
}
fn resolve_buffer_offset_u8(offset: u8) usize {
    return @intFromPtr(&global_test_buffer[0]) + offset;
}

const SMALL_HANDLE_SOURCE = PointerSource.global_pointer_resolver_auto_from_int(.{
    .LOCAL_TYPE = u32,
    .RESOLVE_FUNC = @ptrCast(&resolve_buffer_offset),
});
const SMALL_HANDLE_SOURCE_BITS = PointerSource.global_pointer_resolver_auto_from_int_bits(.{
    .LOCAL_TYPE_NUMBER_OF_BITS = 16,
    .RESOLVE_FUNC = @ptrCast(&resolve_buffer_offset_u16),
});
const SMALL_HANDLE_SOURCE_MAX = PointerSource.global_pointer_resolver_auto_from_int_max(.{
    .LOCAL_TYPE_VALUE_LIMIT = PowerOf2._256,
    .RESOLVE_FUNC = @ptrCast(&resolve_buffer_offset_u8),
});

const MANUAL_NULL_HANDLE: u16 = std.math.maxInt(u16);
fn manual_resolve(handle: u16) usize {
    return @intFromPtr(&global_test_buffer[0]) + @as(usize, handle) * 2;
}
fn manual_is_null(handle: u16) bool {
    return handle == MANUAL_NULL_HANDLE;
}
fn manual_increment(handle: u16, byte_offset: usize) u16 {
    return handle + @as(u16, @intCast(byte_offset / 2));
}
fn manual_decrement(handle: u16, byte_offset: usize) u16 {
    return handle - @as(u16, @intCast(byte_offset / 2));
}

const MANUAL_HANDLE_SOURCE = PointerSource.global_pointer_resolver(.{
    .LOCAL_TYPE = u16,
    .LOCAL_NULL_VALUE = @ptrCast(&MANUAL_NULL_HANDLE),
    .IS_NULL_FUNC = @ptrCast(&manual_is_null),
    .RESOLVE_FUNC = @ptrCast(&manual_resolve),
    .INCR_FUNC = @ptrCast(&manual_increment),
    .DECR_FUNC = @ptrCast(&manual_decrement),
    .ASSERT_CONTIGUOUS_RANGE = false,
});

test "native mutable pointer basics" {
    var values: [4]u32 align(16) = .{ 10, 20, 30, 40 };
    var ptr = Pointer(u32, NATIVE).new_from_any(&values[0]);

    try testing.expect(ptr.not_null());
    try testing.expect(!ptr.is_null());
    try testing.expect(ptr.is_native());
    try testing.expect(!ptr.is_global_resolver());
    try testing.expectEqual(PointerSourceKind.NATIVE, ptr.source_kind());
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr());
    try testing.expectEqual(@as(?usize, @intFromPtr(&values[0])), ptr.addr_or_null());
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr_orelse_0());
    try testing.expectEqual(@as(usize, @intFromPtr(&values[0])), ptr.addr_no_align_check());

    try testing.expectEqual(@as(*u32, &values[0]), ptr.ptr_never_null());
    try testing.expectEqual(@as([*]u32, @ptrCast(&values[0])), ptr.ptr_many_never_null());
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_or_null().?));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many_or_null().?));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c_or_null().?));

    const same = Pointer(u32, NATIVE).new_from_any(&values[0]);
    try testing.expect(ptr.eql(same));
    try testing.expect(ptr.eql_native_address(&values[0]));
    try testing.expect(ptr.eql_native_address(@as(?*u32, &values[0])));

    try testing.expectEqual(@as(u32, 10), ptr.get());
    try testing.expectEqual(@as(?u32, 10), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 10), ptr.get_orelse(99));
    try testing.expectEqual(@as(u32, 30), ptr.get_at_index(2));
    try testing.expectEqual(@as(?u32, 30), ptr.get_at_index_or_null(2));
    try testing.expectEqual(@as(u32, 30), ptr.get_at_index_orelse(2, 99));

    ptr.set(11);
    try testing.expectEqual(@as(u32, 11), values[0]);
    ptr.set_at_index(3, 44);
    try testing.expectEqual(@as(u32, 44), values[3]);

    try testing.expectEqual(@as(u32, 20), ptr.increment(1).get());
    try testing.expectEqual(@as(u32, 30), ptr.increment(2).get());
    try testing.expectEqual(@as(u32, 11), ptr.increment(2).decrement(2).get());
    try testing.expectEqual(@as(u32, 44), ptr.move(3).get());
    try testing.expectEqual(@as(u32, 11), ptr.move(3).move(-3).get());

    ptr.increment_in_place(1);
    try testing.expectEqual(@as(u32, 20), ptr.get());
    ptr.decrement_in_place(1);
    try testing.expectEqual(@as(u32, 11), ptr.get());
    ptr.move_in_place(2);
    try testing.expectEqual(@as(u32, 30), ptr.get());
    ptr.move_in_place(-2);
    try testing.expectEqual(@as(u32, 11), ptr.get());

    const slice = ptr.slice(4);
    try testing.expectEqual(@as(usize, 4), slice.len);
    try testing.expectEqual(@as(u32, 11), slice[0]);
    try testing.expectEqual(@as(u32, 44), slice[3]);
    try testing.expectEqual(@as(usize, 0), ptr.slice(0).len);
    try testing.expectEqual(@as(usize, 4), ptr.slice_never_null(4).len);
}

test "nullable native pointer basics" {
    var value: u32 = 7;
    var ptr = NullablePointer(u32, NATIVE).new_from_any(&value);
    const NP = NullablePointer(u32, NATIVE);

    try testing.expect(ptr.not_null());
    try testing.expect(!ptr.is_null());
    try testing.expectEqual(@as(?u32, 7), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 7), ptr.get_orelse(99));
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(ptr.ptr_or_null().?));
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(ptr.ptr_many_or_null().?));
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(ptr.ptr_c_or_null().?));
    try testing.expectEqual(@as(?usize, @intFromPtr(&value)), ptr.addr_or_null());

    ptr.set_if_not_null(8);
    try testing.expectEqual(@as(u32, 8), value);
    try testing.expect(ptr.set_if_not_null_return_ptr_is_NOT_null(9));
    try testing.expectEqual(@as(u32, 9), value);
    try testing.expect(!ptr.set_if_not_null_return_ptr_IS_null(10));
    try testing.expectEqual(@as(u32, 10), value);
    try testing.expectEqual(@as(?usize, 3), ptr.elements_between_self_low_other_high_exclude_or_null(ptr.increment(3)));

    const null_ptr = NP.new_from(null);
    try testing.expect(null_ptr.is_null());
    try testing.expect(!null_ptr.not_null());
    try testing.expect(NP.new_from_any(@as(?*u32, null)).is_null());
    try testing.expect(null_ptr.eql(NP.new_null()));
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expectEqual(@as(usize, 0), null_ptr.addr_orelse_0());
    try testing.expectEqual(@as(?*u32, null), null_ptr.ptr_or_null());
    try testing.expectEqual(@as(?[*]u32, null), null_ptr.ptr_many_or_null());
    try testing.expectEqual(@as(?[]u32, null), null_ptr.slice_or_null(2));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 99), null_ptr.get_orelse(99));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_at_index_or_null(0));
    try testing.expectEqual(@as(u32, 99), null_ptr.get_at_index_orelse(0, 99));

    null_ptr.set_if_not_null(123);
    try testing.expectEqual(@as(u32, 10), value);
    try testing.expect(!null_ptr.set_if_not_null_return_ptr_is_NOT_null(123));
    try testing.expect(null_ptr.set_if_not_null_return_ptr_IS_null(123));
    try testing.expectEqual(@as(u32, 10), value);

    try testing.expectEqual(@as(?usize, null), null_ptr.elements_between_self_low_other_high_exclude_or_null(ptr));
    try testing.expectEqual(@as(usize, 0), null_ptr.elements_between_self_low_other_high_exclude_orelse_0(ptr));
    try testing.expectEqual(@as(?usize, 1), ptr.elements_between_self_low_other_high_exclude_or_null(ptr.increment(1)));
    try testing.expect(null_ptr.increment_if_not_null(2).is_null());
    try testing.expect(null_ptr.decrement_if_not_null(2).is_null());
    try testing.expect(null_ptr.move_if_not_null(2).is_null());
    try testing.expectEqual(@as(?u32, 10), ptr.increment_if_not_null(0).get_or_null());

    var changeable = NP.new_from_any(&value);
    changeable.set_null();
    try testing.expect(changeable.is_null());
    try testing.expect(null_ptr.eql(changeable));
}

test "const pointer and mutability casts" {
    var values: [4]u32 align(16) = .{ 21, 22, 23, 24 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = CP.new_from_any(&values[0]);

    try testing.expectEqual(@as(u32, 21), ptr.get());
    try testing.expectEqual(@as(u32, 21), ptr.ptr_never_null().*);
    try testing.expectEqual(@as(u32, 21), ptr.ptr_many_never_null()[0]);
    try testing.expectEqual(@as(u32, 21), ptr.slice_never_null(1)[0]);
    try testing.expectEqual(@as(*const u32, &values[0]), ptr.ptr_never_null());
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_many()));
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(ptr.ptr_c()));
    try testing.expectEqual(@as(usize, 4), ptr.slice(4).len);

    const from_mutable = P.new_from_any(&values[0]).to_const();
    try testing.expect(@TypeOf(from_mutable) == CP);
    try testing.expectEqual(@as(u32, 21), from_mutable.get());

    const mutable = ptr.to_mutable();
    try testing.expect(@TypeOf(mutable) == P);
    mutable.set(9);
    try testing.expectEqual(@as(u32, 9), values[0]);

    const const_anyopaque = ptr.to_const_anyopaque();
    try testing.expectEqual(@intFromPtr(&values[0]), @intFromPtr(const_anyopaque));
    try testing.expectEqual(@as(*const anyopaque, @ptrCast(&values[0])), const_anyopaque);
}

test "nullable const pointer basics" {
    var value: u32 = 77;
    const P = NullableConstPointer(u32, NATIVE);
    const ptr = P.new_from_any(&value);
    const null_ptr = P.new_from(null);

    try testing.expectEqual(@as(?u32, 77), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 77), ptr.get_orelse(0));
    try testing.expectEqual(@as(?*const u32, @ptrCast(&value)), ptr.ptr_or_null());
    try testing.expectEqual(@as(?[]const u32, null), null_ptr.slice_or_null(1));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 12), null_ptr.get_orelse(12));
}

test "alignment wrapper types and alignment changes" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const AP = PointerAlign(u32, 16, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const NAP = NullablePointerAlign(u32, 16, NATIVE);
    const C = ConstPointerAlign(u32, 16, NATIVE);

    var ptr = AP.new_from_any(&values[0]);

    try testing.expect(ptr.is_aligned(16));
    try testing.expect(ptr.is_aligned_pow_2(PowerOf2._16));
    try testing.expect(ptr.is_aligned_log_2(4));
    try testing.expect(ptr.is_aligned_std_mem(std.mem.Alignment.@"16"));
    try testing.expect(@TypeOf(ptr.ptr()) == *align(16) u32);
    try testing.expect(@TypeOf(ptr.ptr_many()) == [*]align(16) u32);
    try testing.expect(@TypeOf(ptr.slice(1)) == []align(16) u32);

    try testing.expectEqual(@as(u32, 1), ptr.get());
    try testing.expectEqual(@as(u32, 3), ptr.increment(2).get());
    try testing.expectEqual(@as(u32, 4), ptr.slice(4)[3]);
    try testing.expectEqual(@as(u32, 2), ptr.increment(1).get());

    // Moving an over-aligned pointer yields a pointer with the element's
    // natural alignment; it can no longer claim the stronger alignment.
    const moved = ptr.increment(1);
    try testing.expect(@TypeOf(moved) == P);
    try testing.expect(@TypeOf(moved) != AP);
    try testing.expectEqual(@as(u32, 2), moved.get());

    const same_align = ptr.to_specific_align(PowerOf2._16);
    try testing.expect(@TypeOf(same_align) == AP);
    try testing.expectEqual(@as(u32, 1), same_align.get());

    const from_bytes = P.new_from_any(&values[0]).to_specific_align_any(AlignmentSource.bytes_align(16));
    try testing.expect(@TypeOf(from_bytes) == AP);
    try testing.expectEqual(@as(u32, 1), from_bytes.get());

    const from_log2 = P.new_from_any(&values[0]).to_specific_align_any(AlignmentSource.log2_align(4));
    try testing.expect(@TypeOf(from_log2) == AP);
    try testing.expectEqual(@as(u32, 1), from_log2.get());

    const from_pow2 = P.new_from_any(&values[0]).to_specific_align_any(AlignmentSource.pow2_align(PowerOf2._16));
    try testing.expect(@TypeOf(from_pow2) == AP);

    const from_std_mem = P.new_from_any(&values[0]).to_specific_align_any(AlignmentSource.std_mem_align(std.mem.Alignment.@"16"));
    try testing.expect(@TypeOf(from_std_mem) == AP);

    const from_direct_pow2 = P.new_from_any(&values[0]).to_specific_align_any(PowerOf2._16);
    try testing.expect(@TypeOf(from_direct_pow2) == AP);

    const from_native_align = P.new_from_any(&values[0]).to_specific_align_any(AlignmentSource.native_align());
    try testing.expect(@TypeOf(from_native_align) == P);
    try testing.expect(@TypeOf(P.new_from_any(&values[0]).to_specific_align_any(null)) == P);

    const native_again = ptr.to_native_align();
    try testing.expect(@TypeOf(native_again) == P);
    try testing.expectEqual(@as(u32, 1), native_again.get());

    const null_ap = NP.new_from(null).to_specific_align(PowerOf2._16);
    try testing.expect(@TypeOf(null_ap) == NAP);
    try testing.expect(null_ap.is_null());

    const const_ap = AP.new_from_any(&values[0]).to_const();
    try testing.expect(@TypeOf(const_ap) == C);
    try testing.expectEqual(@as(u32, 1), const_ap.get());
}

test "element casts preserve and validate alignment" {
    var word: u32 align(16) = 0x11223344;
    const BytePtr = PointerAlign(u8, 16, NATIVE);
    const WordPtr = PointerAlign(u32, 16, NATIVE);

    const byte_ptr = BytePtr.new_from_any(@as(*align(16) u8, @ptrCast(&word)));
    const word_ptr = byte_ptr.cast_to_element(u32);
    try testing.expect(@TypeOf(word_ptr) == WordPtr);
    try testing.expectEqual(@as(u32, 0x11223344), word_ptr.get());

    const aligned_byte_ptr = word_ptr.cast_to_element_aligned(u8, PowerOf2._16);
    try testing.expect(@TypeOf(aligned_byte_ptr) == BytePtr);
    const bytes = aligned_byte_ptr.slice(4);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&word), bytes);

    const aligned_word_ptr = aligned_byte_ptr.cast_to_element_aligned(u32, PowerOf2._16);
    try testing.expect(@TypeOf(aligned_word_ptr) == WordPtr);
    try testing.expectEqual(@as(u32, 0x11223344), aligned_word_ptr.get());

    const unchecked = byte_ptr.unchecked_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(unchecked) == PtrDefless(u32));
}

fn PtrDefless(comptime T: type) type {
    return PointerAdvanced(NATIVE, .{ .ELEMENT = T });
}

test "complete_cast_to selects nullability, mutability, and volatility" {
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
    try testing.expect(VP.IS_VOLATILE);

    const unvolatile_cast = volatile_cast.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(unvolatile_cast) == P);
    try testing.expect(!P.IS_VOLATILE);
    try testing.expectEqual(@as(u32, 1), unvolatile_cast.get());

    const null_preserved = NP.new_from(null).complete_cast_to(.{ .ELEMENT = u16, .NULLABILITY = .NULLABLE });
    try testing.expect(null_preserved.is_null());

    const narrowed = ptr.complete_cast_to(.{ .ELEMENT = u8 });
    try testing.expect(@TypeOf(narrowed) == Pointer(u8, NATIVE));
    try testing.expectEqual(@as(u8, 1), narrowed.get());

    const widened = narrowed.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(widened) == P);
    try testing.expectEqual(@as(u32, 1), widened.get());
}

test "additional pointer qualifier casts" {
    var value: u32 align(16) = 42;
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const VP = PointerAdvanced(NATIVE, .{ .ELEMENT = u32, .VOLATILE = .VOLATILE });
    const AZ = PointerAdvanced(NATIVE, .{ .ELEMENT = u32, .ALLOW_ZERO = .ALLOW_ZERO });

    const ptr = P.new_from_any(&value);

    const non_null = NP.new_from_any(&value).to_non_null();
    try testing.expect(@TypeOf(non_null) == P);
    try testing.expectEqual(@as(u32, 42), non_null.get());

    const volatile_ptr = ptr.to_volatile();
    try testing.expect(@TypeOf(volatile_ptr) == VP);
    try testing.expect(VP.IS_VOLATILE);
    const not_volatile = volatile_ptr.remove_volatile();
    try testing.expect(@TypeOf(not_volatile) == P);
    try testing.expectEqual(@as(u32, 42), not_volatile.get());

    const allow_zero = ptr.to_allowzero();
    try testing.expect(@TypeOf(allow_zero) == AZ);
    try testing.expect(AZ.IS_ALLOW_ZERO);
    const no_allow_zero = allow_zero.remove_allowzero();
    try testing.expect(@TypeOf(no_allow_zero) == P);
    try testing.expectEqual(@as(u32, 42), no_allow_zero.get());

    const null_from_non_null_type: NP = NP.new_null();
    try testing.expect(null_from_non_null_type.is_null());

    const explicit_unaligned = ptr.to_specific_align(PowerOf2._8);
    try testing.expect(!@TypeOf(explicit_unaligned).IS_NATIVE_ALIGNED);
    try testing.expect(@TypeOf(explicit_unaligned).HAS_SPECIFIC_ALIGN);
    try testing.expectEqual(@as(u32, 42), explicit_unaligned.get());

    const unchecked_again = ptr.unchecked_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(unchecked_again) == P);
    try testing.expectEqual(@as(u32, 42), unchecked_again.get());
}

test "pointer source kinds and resolver metadata" {
    const P = Pointer(u8, SMALL_HANDLE_SOURCE);
    try testing.expect(!P.IS_NATIVE);
    try testing.expect(P.USE_STATIC_RESOLVER);
    try testing.expect(P.SOURCE == .STATIC_RESOLVER);

    const NP = NullablePointer(u8, SMALL_HANDLE_SOURCE);
    try testing.expect(NP.CAN_BE_NULL);
    try testing.expect(!P.CAN_BE_NULL);
}

test "static resolver -> small local handles resolve to native pointers" {
    @memset(&global_test_buffer, 0);

    const P = Pointer(u8, SMALL_HANDLE_SOURCE);
    var ptr = P.new_from(2);

    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), ptr.addr());
    try testing.expectEqual(@as(?usize, @intFromPtr(&global_test_buffer[2])), ptr.addr_or_null());
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), ptr.addr_orelse_0());
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), ptr.addr_no_align_check());
    try testing.expect(P.new_from(2).eql(ptr));
    try testing.expect(P.new_from_any(@as(u32, 2)).eql(ptr));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), @intFromPtr(ptr.ptr_never_null()));
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), @intFromPtr(ptr.ptr_many_never_null()));

    ptr.set(0xAB);
    try testing.expectEqual(@as(u8, 0xAB), global_test_buffer[2]);

    const next = ptr.increment_assert_contiguous(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[3]), next.addr());
    try testing.expectEqual(@as(u8, 0), next.get());
    next.set(0xCD);
    try testing.expectEqual(@as(u8, 0xCD), global_test_buffer[3]);

    const back = next.decrement_assert_contiguous(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), back.addr());
    try testing.expectEqual(@as(u8, 0xAB), back.get());

    const slice = ptr.slice(2);
    try testing.expectEqual(@as(u8, 0xAB), slice[0]);
    try testing.expectEqual(@as(u8, 0xCD), slice[1]);

    const moved = ptr.move(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[3]), moved.addr());

    try testing.expectEqual(PointerSourceKind.STATIC_RESOLVER, ptr.source_kind());
    try testing.expect(!ptr.is_native());
    try testing.expect(ptr.is_global_resolver());
    try testing.expect(ptr.eql(ptr));
    try testing.expect(!ptr.eql(moved));
    try testing.expect(ptr.eql_native_address(&global_test_buffer[2]));
    try testing.expectEqual(std.math.Order.lt, ptr.order(moved));

    try testing.expectEqual(@as(u8, 0xAB), ptr.get());
    ptr.increment_in_place_assert_contiguous(1);
    try testing.expectEqual(@as(u8, 0xCD), ptr.get());
    ptr.decrement_in_place(1);
    try testing.expectEqual(@as(u8, 0xAB), ptr.get());

    const nullable = NullablePointer(u8, SMALL_HANDLE_SOURCE);
    const null_ptr = nullable.new_null();
    const null_aligned = null_ptr.to_specific_align(PowerOf2._16);
    try testing.expect(null_aligned.is_null());
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expectEqual(@as(?[]u8, null), null_ptr.slice_or_null(2));

    const null_handle = nullable.new_from(std.math.maxInt(u32));
    try testing.expect(null_handle.is_null());
    try testing.expect(null_handle.eql(null_ptr));
}

test "static resolver element casts and byte access" {
    @memset(&global_test_buffer, 0);
    global_test_buffer[0] = 0x44;
    global_test_buffer[1] = 0x33;
    global_test_buffer[2] = 0x22;
    global_test_buffer[3] = 0x11;

    const BytePtr = Pointer(u8, SMALL_HANDLE_SOURCE);
    const WordPtr = Pointer(u32, SMALL_HANDLE_SOURCE);

    const bytes = BytePtr.new_from(0);
    const words = bytes.complete_cast_to(.{ .ELEMENT = u32 });
    try testing.expect(@TypeOf(words) == WordPtr);
    try testing.expectEqual(@as(u32, 0x11223344), words.get());

    const back_to_bytes = words.cast_to_element(u8);
    try testing.expectEqual(@as(u8, 0x44), back_to_bytes.get());
    try testing.expectEqualSlices(u8, global_test_buffer[0..4], back_to_bytes.slice(4));

    const null_bytes = NullablePointer(u8, SMALL_HANDLE_SOURCE).new_null();
    const null_words = null_bytes.complete_cast_to(.{ .ELEMENT = u32, .NULLABILITY = .NULLABLE });
    try testing.expect(null_words.is_null());
}

test "manual static resolver with byte-unit handles" {
    @memset(&global_test_buffer, 0);

    const P = Pointer(u16, MANUAL_HANDLE_SOURCE);
    var ptr = P.new_from(1);

    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), ptr.addr());
    ptr.set(0xBEEF);
    try testing.expectEqual(@as(u16, 0xBEEF), ptr.get());

    const next = ptr.increment(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[4]), next.addr());
    const back = next.decrement(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), back.addr());
    try testing.expectEqual(@as(u16, 0xBEEF), back.get());

    const word_slice = ptr.slice(2);
    try testing.expectEqual(@as(usize, 2), word_slice.len);
    try testing.expectEqual(@as(u16, 0xBEEF), word_slice[0]);

    const bytes = ptr.to_bytes(1);
    try testing.expectEqual(@as(usize, 2), bytes.len);

    const NP = NullablePointer(u16, MANUAL_HANDLE_SOURCE);
    const null_ptr = NP.new_null();
    try testing.expect(null_ptr.is_null());
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expect(NP.new_from(MANUAL_NULL_HANDLE).is_null());
}

test "bits- and max-specified integer resolvers" {
    @memset(&global_test_buffer, 0);

    const BitsPtr = Pointer(u8, SMALL_HANDLE_SOURCE_BITS);
    try testing.expect(@TypeOf(BitsPtr.new_from(3).internal) == u16);
    const bits = BitsPtr.new_from(3);
    bits.set(0x11);
    try testing.expectEqual(@as(u8, 0x11), global_test_buffer[3]);

    const MaxPtr = Pointer(u8, SMALL_HANDLE_SOURCE_MAX);
    try testing.expect(@TypeOf(MaxPtr.new_from(4).internal) == u8);
    const max_ptr = MaxPtr.new_from(4);
    max_ptr.set(0x22);
    try testing.expectEqual(@as(u8, 0x22), global_test_buffer[4]);

    const NullableMax = NullablePointer(u8, SMALL_HANDLE_SOURCE_MAX);
    const null_ptr = NullableMax.new_from(std.math.maxInt(u8));
    try testing.expect(null_ptr.is_null());
}

test "pointer size kinds and bytes accessors" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);

    try testing.expectEqual(@as([*]u32, @ptrCast(&values[0])), ptr.ptr_many_never_null());
    try testing.expectEqual(@as(*u32, @ptrCast(&values[0])), ptr.ptr_never_null());
    try testing.expectEqual(@as([*c]u32, @ptrCast(&values[0])), ptr.ptr_c_never_null());

    const bytes = ptr.to_bytes(4);
    const const_bytes = ptr.to_const_bytes(4);
    try testing.expectEqual(@as(usize, 16), bytes.len);
    try testing.expectEqual(@as(usize, 16), const_bytes.len);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&values), bytes);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&values), const_bytes);

    const null_bytes = NullablePointer(u32, NATIVE).new_null().to_bytes_or_null(4);
    try testing.expectEqual(@as(?[]u8, null), null_bytes);
    const null_const_bytes = NullableConstPointer(u32, NATIVE).new_null().to_const_bytes_or_null(4);
    try testing.expectEqual(@as(?[]const u8, null), null_const_bytes);

    try testing.expectEqual(@as(usize, 16), CP.new_from_any(&values[0]).to_const_bytes(4).len);
}

test "pointer introspection, comparison, and hashing" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const ptr = P.new_from_any(&values[0]);
    const same = P.new_from_any(&values[0]);

    try testing.expect(ptr.eql(same));
    try testing.expect(!ptr.eql(ptr.increment(1)));
    try testing.expect(ptr.eql_native_address(&values[0]));
    try testing.expect(ptr.eql_native_address(@as(?*u32, &values[0])));
    try testing.expect(!ptr.eql_native_address(@as(?*u32, null)));
    try testing.expectEqual(std.math.Order.eq, ptr.order(same));
    try testing.expectEqual(std.math.Order.lt, ptr.order(ptr.increment(1)));
    try testing.expectEqual(ptr.hash(), same.hash());
    try testing.expectEqual(ptr.simple_hash(), same.simple_hash());
    try testing.expectEqual(PointerSourceKind.NATIVE, ptr.source_kind());
    try testing.expect(ptr.is_native());
    try testing.expect(!ptr.is_global_resolver());

    const null_ptr = NullablePointer(u32, NATIVE).new_null();
    try testing.expectEqual(@as(?usize, null), null_ptr.addr_or_null());
    try testing.expectEqual(std.math.Order.lt, null_ptr.order(ptr.to_nullable()));
    try testing.expect(null_ptr.eql(NullablePointer(u32, NATIVE).new_from(null)));
    try testing.expect(!null_ptr.eql(ptr.to_nullable()));
}

test "signed distances and null-preserving arithmetic" {
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

    const null_ptr = NP.new_from(null);
    try testing.expectEqual(@as(?isize, null), null_ptr.bytes_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 0), null_ptr.bytes_from_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?isize, 3), third.to_nullable().elements_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 3), third.to_nullable().elements_from_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?isize, 12), third.to_nullable().offset_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 12), third.to_nullable().offset_from_orelse_0(ptr.to_nullable()));

    try testing.expect(null_ptr.increment_if_not_null(2).is_null());
    try testing.expect(null_ptr.decrement_if_not_null(2).is_null());
    try testing.expect(null_ptr.move_if_not_null(2).is_null());
    try testing.expectEqual(@as(?u32, 3), ptr.to_nullable().increment_if_not_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 1), ptr.to_nullable().increment_if_not_null(2).decrement_if_not_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 3), ptr.to_nullable().move_if_not_null(2).get_or_null());
}

test "elements-between and range helpers" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
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

    try testing.expect(ptr.increment(1).is_within_range_exclude_high(ptr, ptr.increment(4)));
    try testing.expect(!ptr.increment(4).is_within_range_exclude_high(ptr, ptr.increment(4)));
    try testing.expect(ptr.increment(4).is_within_range_include_high(ptr, ptr.increment(4)));
}

test "bulk, volatile, atomic, and void pointer operations" {
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
    ptr.memmove_from(ptr.increment(1).to_const().slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 2, 3, 4, 4 }, &values);

    var volatile_value: u32 = 10;
    const volatile_ptr = P.new_from_any(&volatile_value);
    volatile_ptr.set_volatile(11);
    try testing.expectEqual(@as(u32, 11), volatile_ptr.get_volatile());

    const void_ptr = volatile_ptr.to_anyopaque();
    try testing.expectEqual(@intFromPtr(&volatile_value), @intFromPtr(void_ptr));
    try testing.expect(@TypeOf(CP.new_from_any(&volatile_value).to_anyopaque()) == *const anyopaque);

    const null_void_ptr = NullablePointer(u32, NATIVE).new_null().to_anyopaque_or_null();
    try testing.expectEqual(@as(?*anyopaque, null), null_void_ptr);
    const null_const_void_ptr = NullableConstPointer(u32, NATIVE).new_null().to_const_anyopaque_or_null();
    try testing.expectEqual(@as(?*const anyopaque, null), null_const_void_ptr);

    var atomic_value: u32 align(@alignOf(u32)) = 1;
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
}

test "pointer definition helpers" {
    const base = MakePtrDef{ .ELEMENT = u32 };
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
    const sentinel_ptr_type = MakePtrFromDef(with_sentinel);
    try testing.expect(@typeInfo(sentinel_ptr_type) == .optional);
    const nullable_default = PtrDefaultFromDef(modified);
    try testing.expect(nullable_default == null);

    const no_size = MakePtrDefNoSize{ .ELEMENT = u8 };
    const no_size_modified = no_size
        .with_allow_zero(.ALLOW_ZERO)
        .with_nullability(.NULLABLE)
        .with_mutability(.CONST)
        .with_element(u16)
        .with_align(PowerOf2._8)
        .with_volatile(.VOLATILE);
    const full = no_size_modified.to_make_ptr_def(.many);
    try testing.expectEqual(std.lang.Type.Pointer.Size.many, full.SIZE);
    try testing.expectEqual(Mutability.CONST, full.MUTABILITY);
    try testing.expectEqual(@as(type, u16), full.ELEMENT);
    try testing.expectEqual(@as(?PowerOf2, PowerOf2._8), full.ALIGNMENT);

    const no_size_sentinel = no_size_modified.with_sentinel(0);
    try testing.expect(no_size_sentinel.SENTINEL != null);
    const no_size_type = MakePtrFromDef(no_size_sentinel.to_make_ptr_def(.many));
    try testing.expect(@typeInfo(no_size_type) == .optional);

    const direct_default = PtrDefault(.NO_ALLOW_ZERO, .NULLABLE, .MUTABLE, .many, u8, null, null, null, .NOT_VOLATILE);
    try testing.expect(direct_default == null);

    const NestedPointer = PointerSource.Pointer(NATIVE, u32);
    try testing.expect(NestedPointer == Pointer(u32, NATIVE));
}
