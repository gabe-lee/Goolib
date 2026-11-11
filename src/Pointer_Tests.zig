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

const PointerSource = PointerModule.PointerSource;
const PointerSourceKind = PointerModule.PointerSourceKind;
const PointerOpaque = PointerModule.PointerOpaque;
const AlignmentSource = PointerModule.AlignmentSource;
const Pointer = PointerModule.Pointer;
const NullablePointer = PointerModule.NullablePointer;
const ConstPointer = PointerModule.ConstPointer;
const NullableConstPointer = PointerModule.NullableConstPointer;
const PointerAlign = PointerModule.PointerAlign;
const NullablePointerAlign = PointerModule.NullablePointerAlign;
const ConstPointerAlign = PointerModule.ConstPointerAlign;
const NullableConstPointerAlign = PointerModule.NullableConstPointerAlign;

const NATIVE = PointerSource.native_pointer();

var global_test_buffer: [8]u8 = undefined;

fn resolve_buffer_offset(offset: u32) usize {
    return @intFromPtr(&global_test_buffer[0]) + offset;
}

const SMALL_HANDLE_SOURCE = PointerSource.global_pointer_resolver_auto_from_int(.{
    .LOCAL_TYPE = u32,
    .RESOLVE_FUNC = @ptrCast(&resolve_buffer_offset),
});

test "PointerOpaque -> native pointer operations" {
    var value: u32 = 0x12345678;
    var opq = PointerOpaque(NATIVE).new_from_native(&value);

    try testing.expect(opq.not_null());
    try testing.expect(!opq.is_null());
    try testing.expectEqual(@as(u32, 0x12345678), opq.get(u32));
    opq.set(u32, 0x87654321);
    try testing.expectEqual(@as(u32, 0x87654321), value);
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(opq.ptr(u32)));
}

test "Pointer -> native typed mutable pointer" {
    var values: [4]u32 align(16) = .{ 10, 20, 30, 40 };
    var ptr = Pointer(u32, NATIVE).new_from_native(&values[0]);

    try testing.expectEqual(@as(u32, 10), ptr.get());
    ptr.set(11);
    try testing.expectEqual(@as(u32, 11), values[0]);

    try testing.expectEqual(@as(u32, 20), ptr.add(1).get());
    try testing.expectEqual(@as(u32, 30), ptr.add(2).get());
    try testing.expectEqual(@as(u32, 11), ptr.add(2).subtract(2).get());
    try testing.expectEqual(@as(u32, 40), ptr.move(3).get());
    try testing.expectEqual(@as(u32, 11), ptr.move(3).move(-3).get());

    ptr.add_in_place(1);
    try testing.expectEqual(@as(u32, 20), ptr.get());
    ptr.subtract_in_place(1);
    try testing.expectEqual(@as(u32, 11), ptr.get());
    ptr.move_in_place(2);
    try testing.expectEqual(@as(u32, 30), ptr.get());
    ptr.move_in_place(-2);
    try testing.expectEqual(@as(u32, 11), ptr.get());

    try testing.expectEqual(@as(u32, 30), ptr.get_at_index(2));
    ptr.set_at_index(3, 44);
    try testing.expectEqual(@as(u32, 44), values[3]);

    const slice = ptr.slice(4);
    try testing.expectEqual(@as(usize, 4), slice.len);
    try testing.expectEqual(@as(u32, 11), slice[0]);
    try testing.expectEqual(@as(u32, 44), slice[3]);

    const array = ptr.array_ptr(4);
    try testing.expectEqual(@as(u32, 30), array[2]);

    const vector = ptr.vector_ptr(4);
    try testing.expectEqual(@as(u32, 20), vector[1]);

    try testing.expect(ptr.is_aligned(@alignOf(u32)));
    try testing.expect(!ptr.opq.add(1).is_aligned(@alignOf(u32)));
    try testing.expectEqual(@as(usize, 3), ptr.elements_between_self_low_other_high_exclude(ptr.add(3)));
    try testing.expectEqual(@as(usize, 4), ptr.elements_between_self_low_other_high_include(ptr.add(3)));
    try testing.expectEqual(@as(usize, 3), ptr.elements_between_exclude_high(ptr.add(3)));
    try testing.expect(ptr.add(1).is_within_range_exclude_high(ptr, ptr.add(4)));
    try testing.expect(!ptr.add(4).is_within_range_exclude_high(ptr, ptr.add(4)));

    try testing.expect(!@hasDecl(Pointer(u32, NATIVE), "const_ptr"));
    try testing.expect(!@hasDecl(Pointer(u32, NATIVE), "get_or_null"));
    try testing.expect(!@hasDecl(Pointer(u32, NATIVE), "is_null"));
}

test "cast_to and utility casts -> select wrapper properties" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const AP = PointerAlign(u32, 16, NATIVE);
    const ACP = ConstPointerAlign(u32, 16, NATIVE);
    const ANP = NullablePointerAlign(u32, 16, NATIVE);
    const ACNP = NullableConstPointerAlign(u32, 16, NATIVE);

    var ptr = P.new_from_native(&values[0]);

    const opaque_cast = ptr.opq.cast_to(.NEVER_NULL, .CONST_PTR, u32, null);
    try testing.expect(@TypeOf(opaque_cast) == CP);
    try testing.expectEqual(@as(u32, 1), opaque_cast.get());

    const const_cast = ptr.cast_to(.NEVER_NULL, .CONST_PTR, u32, null);
    try testing.expect(@TypeOf(const_cast) == CP);
    try testing.expectEqual(@as(u32, 1), const_cast.get());

    const aligned_const_cast = ptr.cast_to(.NEVER_NULL, .CONST_PTR, u32, 16);
    try testing.expect(@TypeOf(aligned_const_cast) == ACP);
    try testing.expectEqual(@as(u32, 1), aligned_const_cast.get());

    const aligned_source_cast = ptr.cast_to(.NEVER_NULL, .MUT_PTR, u32, AlignmentSource.bytes_align(16));
    try testing.expect(@TypeOf(aligned_source_cast) == AP);
    try testing.expectEqual(@as(u32, 1), aligned_source_cast.get());

    const native_aligned_ptr = ptr.to_align(AlignmentSource.native_align(u32));
    try testing.expect(@TypeOf(native_aligned_ptr) == PointerAlign(u32, @alignOf(u32), NATIVE));
    try testing.expectEqual(@as(u32, 1), native_aligned_ptr.get());

    const nullable_cast = ptr.cast_to(.NULLABLE, .MUT_PTR, u32, null);
    try testing.expect(@TypeOf(nullable_cast) == NP);
    try testing.expectEqual(@as(?u32, 1), nullable_cast.get_or_null());

    const nullable_aligned_cast = ptr.cast_to(.NULLABLE, .MUT_PTR, u32, 16);
    try testing.expect(@TypeOf(nullable_aligned_cast) == ANP);
    try testing.expectEqual(@as(?u32, 1), nullable_aligned_cast.get_or_null());

    const const_ptr = ptr.to_const();
    try testing.expect(@TypeOf(const_ptr) == CP);
    try testing.expectEqual(@as(u32, 1), const_ptr.get());

    const aligned_ptr = ptr.to_align(16);
    try testing.expect(@TypeOf(aligned_ptr) == AP);
    try testing.expectEqual(@as(u32, 1), aligned_ptr.get());

    const nullable_ptr = ptr.to_nullable();
    try testing.expect(@TypeOf(nullable_ptr) == NP);
    try testing.expectEqual(@as(?u32, 1), nullable_ptr.get_or_null());

    const nullable_const_aligned_ptr = ptr.to_nullable().to_const().to_align(16);
    try testing.expect(@TypeOf(nullable_const_aligned_ptr) == ACNP);
    try testing.expectEqual(@as(?u32, 1), nullable_const_aligned_ptr.get_or_null());

    const non_null_cast = nullable_ptr.cast_to(.NEVER_NULL, .MUT_PTR, u32, null);
    try testing.expect(@TypeOf(non_null_cast) == P);
    try testing.expectEqual(@as(u32, 1), non_null_cast.get());

    const null_nullable = NullablePointer(u32, NATIVE).new(0);
    const null_aligned = null_nullable.to_align(16);
    try testing.expect(@TypeOf(null_aligned) == ANP);
    try testing.expect(null_aligned.is_null());
}

test "NullablePointer -> native typed nullable pointer" {
    var value: u32 = 7;
    const P = NullablePointer(u32, NATIVE);
    var ptr = P.new_from_native(&value);

    try testing.expect(ptr.not_null());
    try testing.expect(!ptr.is_null());
    try testing.expectEqual(@as(?u32, 7), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 7), ptr.get_orelse(99));
    try testing.expectEqual(@intFromPtr(&value), @intFromPtr(ptr.ptr_or_null().?));

    ptr.set_if_not_null(8);
    try testing.expectEqual(@as(u32, 8), value);
    try testing.expect(ptr.set_if_not_null_return_ptr_is_NOT_null(9));
    try testing.expectEqual(@as(u32, 9), value);
    try testing.expect(!ptr.set_if_not_null_return_ptr_IS_null(10));
    try testing.expectEqual(@as(u32, 10), value);

    const null_ptr = P.new(0);
    try testing.expect(null_ptr.is_null());
    try testing.expect(!null_ptr.not_null());
    try testing.expectEqual(@as(?*u32, null), null_ptr.ptr_or_null());
    try testing.expectEqual(@as(?[*]u32, null), null_ptr.ptr_many_or_null());
    try testing.expectEqual(@as(?[]u32, null), null_ptr.slice_or_null(2));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 99), null_ptr.get_orelse(99));

    null_ptr.set_if_not_null(123);
    try testing.expectEqual(@as(u32, 10), value);
    try testing.expect(!null_ptr.set_if_not_null_return_ptr_is_NOT_null(123));
    try testing.expect(null_ptr.set_if_not_null_return_ptr_IS_null(123));
    try testing.expectEqual(@as(u32, 10), value);

    try testing.expectEqual(@as(?usize, null), null_ptr.elements_between_self_low_other_high_exclude_or_null(ptr));
    try testing.expectEqual(@as(usize, 0), null_ptr.elements_between_self_low_other_high_exclude_orelse_0(ptr));
    try testing.expectEqual(@as(?usize, 1), ptr.elements_between_self_low_other_high_exclude_or_null(ptr.add(1)));
}

test "ConstPointer -> native typed const pointer" {
    var value: u32 align(16) = 55;
    const P = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_native(&value);

    try testing.expectEqual(@as(u32, 55), ptr.get());
    try testing.expectEqual(@as(u32, 55), ptr.const_ptr().*);
    try testing.expectEqual(@as(u32, 55), ptr.const_ptr_many()[0]);
    try testing.expectEqual(@as(u32, 55), ptr.const_slice(1)[0]);
    try testing.expectEqual(@as(u32, 55), ptr.const_array_ptr(1)[0]);
    try testing.expectEqual(@as(u32, 55), ptr.const_vector_ptr(1)[0]);
    try testing.expectEqual(@as(u32, 55), ptr.get_at_index(0));
    try testing.expectEqual(@as(u32, 55), ptr.add(0).get());

    try testing.expect(!@hasDecl(P, "set"));
    try testing.expect(!@hasDecl(P, "ptr"));
    try testing.expect(!@hasDecl(P, "ptr_or_null"));
}

test "NullableConstPointer -> native typed nullable const pointer" {
    var value: u32 = 77;
    const P = NullableConstPointer(u32, NATIVE);
    const ptr = P.new_from_native(&value);
    const null_ptr = P.new(0);

    try testing.expectEqual(@as(?u32, 77), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 77), ptr.get_orelse(0));
    try testing.expectEqual(@as(?*const u32, @ptrCast(&value)), ptr.const_ptr_or_null());
    try testing.expectEqual(@as(?[]const u32, null), null_ptr.const_slice_or_null(1));
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 12), null_ptr.get_orelse(12));

    try testing.expect(!@hasDecl(P, "set"));
    try testing.expect(!@hasDecl(P, "set_if_not_null"));
    try testing.expect(!@hasDecl(P, "const_ptr"));
}

test "PointerAlign -> aligned typed mutable pointer" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = PointerAlign(u32, 16, NATIVE);
    var ptr = P.new_from_native(&values[0]);

    try testing.expect(ptr.is_aligned(16));
    try testing.expect(@TypeOf(ptr.ptr()) == *align(16) u32);
    try testing.expect(@TypeOf(ptr.ptr_many()) == [*]align(16) u32);
    try testing.expect(@TypeOf(ptr.slice(1)) == []align(16) u32);
    try testing.expect(@TypeOf(ptr.array_ptr(4)) == *align(16) [4]u32);
    try testing.expect(@TypeOf(ptr.vector_ptr(4)) == *align(16) @Vector(4, u32));

    try testing.expectEqual(@as(u32, 1), ptr.get());
    ptr.set(11);
    try testing.expectEqual(@as(u32, 11), values[0]);
    try testing.expectEqual(@as(u32, 3), ptr.add(2).get());
    try testing.expectEqual(@as(usize, 4), ptr.slice(4).len);
    try testing.expectEqual(@as(u32, 4), ptr.array_ptr(4)[3]);
    try testing.expectEqual(@as(u32, 2), ptr.vector_ptr(4)[1]);
}

test "NullablePointerAlign -> aligned typed nullable pointer" {
    var values: [4]u32 align(16) = .{ 5, 6, 7, 8 };
    const P = NullablePointerAlign(u32, 16, NATIVE);
    var ptr = P.new_from_native(&values[0]);
    const null_ptr = P.new(0);

    try testing.expect(@TypeOf(ptr.ptr_or_null()) == ?*align(16) u32);
    try testing.expect(@TypeOf(ptr.slice_or_null(1)) == ?[]align(16) u32);
    try testing.expectEqual(@as(?u32, 5), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 5), ptr.ptr_or_null().?.*);
    ptr.set_if_not_null(15);
    try testing.expectEqual(@as(u32, 15), values[0]);
    try testing.expectEqual(@as(?usize, null), null_ptr.elements_between_self_low_other_high_exclude_or_null(ptr));
}

test "ConstPointerAlign -> aligned typed const pointer" {
    var values: [4]u32 align(16) = .{ 21, 22, 23, 24 };
    const P = ConstPointerAlign(u32, 16, NATIVE);
    const ptr = P.new_from_native(&values[0]);

    try testing.expect(@TypeOf(ptr.const_ptr()) == *align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_ptr_many()) == [*]align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_slice(1)) == []align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_array_ptr(4)) == *align(16) const [4]u32);
    try testing.expect(@TypeOf(ptr.const_vector_ptr(4)) == *align(16) const @Vector(4, u32));

    try testing.expectEqual(@as(u32, 21), ptr.get());
    try testing.expectEqual(@as(u32, 23), ptr.add(2).get());
    try testing.expectEqual(@as(u32, 24), ptr.const_array_ptr(4)[3]);
    try testing.expectEqual(@as(u32, 22), ptr.const_vector_ptr(4)[1]);

    try testing.expect(!@hasDecl(P, "set"));
    try testing.expect(!@hasDecl(P, "ptr"));
}

test "NullableConstPointerAlign -> aligned typed nullable const pointer" {
    var values: [4]u32 align(16) = .{ 31, 32, 33, 34 };
    const P = NullableConstPointerAlign(u32, 16, NATIVE);
    const ptr = P.new_from_native(&values[0]);
    const null_ptr = P.new(0);

    try testing.expect(@TypeOf(ptr.const_ptr_or_null()) == ?*align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_ptr_many_or_null()) == ?[*]align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_slice_or_null(1)) == ?[]align(16) const u32);
    try testing.expect(@TypeOf(ptr.const_array_ptr_or_null(4)) == ?*align(16) const [4]u32);
    try testing.expect(@TypeOf(ptr.const_vector_ptr_or_null(4)) == ?*align(16) const @Vector(4, u32));

    try testing.expectEqual(@as(?u32, 31), ptr.get_or_null());
    try testing.expectEqual(@as(u32, 31), ptr.const_ptr_or_null().?.*);
    try testing.expectEqual(@as(?u32, null), null_ptr.get_or_null());
    try testing.expectEqual(@as(u32, 0), null_ptr.get_orelse(0));
    try testing.expectEqual(@as(?[]align(16) const u32, null), null_ptr.const_slice_or_null(1));

    try testing.expect(!@hasDecl(P, "set"));
    try testing.expect(!@hasDecl(P, "const_ptr"));
}

test "pointer introspection, comparison, and hashing" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const ptr = P.new_from_native(&values[0]);
    const same = P.new_from_native(&values[0]);

    try testing.expectEqual(@intFromPtr(&values[0]), ptr.local_addr());
    try testing.expectEqual(@intFromPtr(&values[0]), ptr.resolved_addr());
    try testing.expectEqual(@as(?usize, @intFromPtr(&values[0])), ptr.resolved_addr_or_null());
    try testing.expect(ptr.eql(same));
    try testing.expect(!ptr.eql(ptr.add(1)));
    try testing.expect(ptr.eql_native(&values[0]));
    try testing.expect(ptr.eql_native(@as(?*u32, &values[0])));
    try testing.expect(!ptr.eql_native(@as(?*u32, null)));
    try testing.expect(ptr.eql_local(same));
    try testing.expect(!ptr.eql_local(ptr.add(1)));
    try testing.expectEqual(std.math.Order.eq, ptr.order(same));
    try testing.expectEqual(std.math.Order.lt, ptr.order(ptr.add(1)));
    try testing.expectEqual(ptr.hash(), same.hash());
    try testing.expectEqual(PointerSourceKind.NATIVE, ptr.source_kind());
    try testing.expect(ptr.is_native());
    try testing.expect(!ptr.is_global_resolver());

    const null_ptr = NullablePointer(u32, NATIVE).new_null();
    try testing.expectEqual(@as(?usize, null), null_ptr.resolved_addr_or_null());
    try testing.expectEqual(std.math.Order.lt, null_ptr.order(ptr.to_nullable()));
    try testing.expect(null_ptr.eql(NullablePointer(u32, NATIVE).new(0)));
}

test "signed distances and null-preserving arithmetic" {
    var values: [4]u32 = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const ptr = P.new_from_native(&values[0]);
    const third = ptr.add(3);

    try testing.expectEqual(@as(isize, 12), third.bytes_from(ptr));
    try testing.expectEqual(@as(isize, -12), ptr.bytes_from(third));
    try testing.expectEqual(@as(isize, 3), third.elements_from(ptr));
    try testing.expectEqual(@as(isize, -3), ptr.elements_from(third));
    try testing.expectEqual(@as(isize, 12), third.offset_from(ptr));
    try testing.expectEqual(@as(isize, -12), ptr.offset_from(third));

    const null_ptr = NP.new(0);
    try testing.expectEqual(@as(?isize, null), null_ptr.bytes_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 0), null_ptr.bytes_from_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?isize, 3), third.to_nullable().elements_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 3), third.to_nullable().elements_from_orelse_0(ptr.to_nullable()));
    try testing.expectEqual(@as(?isize, 12), third.to_nullable().offset_from_or_null(ptr.to_nullable()));
    try testing.expectEqual(@as(isize, 12), third.to_nullable().offset_from_orelse_0(ptr.to_nullable()));

    try testing.expect(null_ptr.add_or_null(2).is_null());
    try testing.expect(null_ptr.subtract_or_null(2).is_null());
    try testing.expect(null_ptr.move_or_null(2).is_null());
    try testing.expectEqual(@as(?u32, 3), ptr.to_nullable().add_or_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 1), ptr.to_nullable().add_or_null(2).subtract_or_null(2).get_or_null());
    try testing.expectEqual(@as(?u32, 3), ptr.to_nullable().move_or_null(2).get_or_null());
}

test "additional casts and nullable mutation" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const NP = NullablePointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_native(&values[0]);

    const nullable = ptr.to_nullable();
    const non_null = nullable.to_non_null();
    try testing.expect(@TypeOf(non_null) == P);
    try testing.expectEqual(@as(u32, 1), non_null.get());

    const aligned = ptr.to_align(16);
    const unaligned = aligned.to_unaligned();
    try testing.expect(@TypeOf(unaligned) == P);
    try testing.expectEqual(@as(u32, 1), unaligned.get());

    const const_ptr = CP.new_from_native(&values[0]);
    const mutable = const_ptr.to_mutable();
    try testing.expect(@TypeOf(mutable) == P);
    mutable.set(9);
    try testing.expectEqual(@as(u32, 9), values[0]);

    const null_ptr = NP.new_null();
    try testing.expect(null_ptr.is_null());

    var changeable = NP.new_from_native(&values[0]);
    changeable.set_null();
    try testing.expect(changeable.is_null());
    try testing.expect(null_ptr.is_null_or_equal(changeable));
    try testing.expect(!null_ptr.is_null_or_equal(ptr.to_nullable()));
}

test "bulk, byte, volatile, and void pointer operations" {
    var values: [4]u32 align(16) = .{ 1, 2, 3, 4 };
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_native(&values[0]);

    var dst = [4]u32{ 0, 0, 0, 0 };
    ptr.memcopy_to(&dst);
    try testing.expectEqualSlices(u32, &[_]u32{ 1, 2, 3, 4 }, &dst);

    ptr.memcopy_from(&[_]u32{ 5, 6, 7, 8 });
    try testing.expectEqualSlices(u32, &[_]u32{ 5, 6, 7, 8 }, &values);

    ptr.memset(0, 4);
    try testing.expectEqualSlices(u32, &[_]u32{ 0, 0, 0, 0 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });

    ptr.memmove_to(ptr.add(1).slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 1, 1, 2, 3 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });
    ptr.add(1).memmove_to(ptr.slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 2, 3, 4, 4 }, &values);

    ptr.memcopy_from(&[_]u32{ 1, 2, 3, 4 });
    ptr.memmove_from(ptr.add(1).to_const().const_slice(3));
    try testing.expectEqualSlices(u32, &[_]u32{ 2, 3, 4, 4 }, &values);

    const bytes = ptr.bytes(4 * @sizeOf(u32));
    const const_bytes = ptr.const_bytes(4 * @sizeOf(u32));
    try testing.expectEqual(@as(usize, 16), bytes.len);
    try testing.expectEqual(@as(usize, 16), const_bytes.len);
    try testing.expectEqualSlices(u8, std.mem.asBytes(&values), bytes);

    var volatile_value: u32 = 10;
    const volatile_ptr = P.new_from_native(&volatile_value);
    volatile_ptr.set_volatile(11);
    try testing.expectEqual(@as(u32, 11), volatile_ptr.get_volatile());

    const void_ptr = volatile_ptr.to_anyopaque();
    try testing.expectEqual(@intFromPtr(&volatile_value), @intFromPtr(void_ptr));
    try testing.expect(@TypeOf(CP.new_from_native(&volatile_value).to_anyopaque()) == *const anyopaque);
    try testing.expectEqual(@as(u32, 11), P.from_anyopaque(void_ptr).get());
    try testing.expectEqual(@as(u32, 11), CP.from_anyopaque(void_ptr).get());

    const null_void_ptr = NullablePointer(u32, NATIVE).new_null().to_anyopaque_or_null();
    try testing.expectEqual(@as(?*anyopaque, null), null_void_ptr);
}

test "atomic access" {
    var value: u32 align(@alignOf(u32)) = 1;
    const P = Pointer(u32, NATIVE);
    const CP = ConstPointer(u32, NATIVE);
    const ptr = P.new_from_native(&value);

    try testing.expectEqual(@as(u32, 1), ptr.atomic_load(.seq_cst));
    ptr.atomic_store(2, .seq_cst);
    try testing.expectEqual(@as(u32, 2), ptr.atomic_load(.acquire));
    try testing.expectEqual(@as(u32, 2), ptr.atomic_read_modify_write(.Xchg, 3, .seq_cst));
    try testing.expectEqual(@as(u32, 3), value);

    try testing.expectEqual(@as(?u32, null), ptr.atomic_compare_exchange_strong(3, 4, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 4), value);
    try testing.expectEqual(@as(?u32, 4), ptr.atomic_compare_exchange_strong(99, 5, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 4), value);
    try testing.expectEqual(@as(?u32, null), ptr.atomic_compare_exchange_strong(4, 5, .seq_cst, .seq_cst));
    try testing.expectEqual(@as(u32, 5), value);

    try testing.expectEqual(@as(u32, 5), CP.new_from_native(&value).atomic_load(.seq_cst));
    try testing.expect(@hasDecl(CP, "atomic_load"));
    try testing.expect(!@hasDecl(CP, "atomic_store"));
    try testing.expect(!@hasDecl(CP, "set_volatile"));
    try testing.expect(!@hasDecl(CP, "memcopy_from"));
    try testing.expect(!@hasDecl(CP, "bytes"));
    try testing.expect(!@hasDecl(P, "new_null"));
    try testing.expect(!@hasDecl(P, "to_non_null"));
    try testing.expect(!@hasDecl(P, "to_unaligned"));
    try testing.expect(!@hasDecl(P, "to_mutable"));
    try testing.expect(@hasDecl(PointerAlign(u32, 16, NATIVE), "to_unaligned"));
    try testing.expect(@hasDecl(CP, "to_mutable"));
}

test "GLOBAL_RESOLVER -> small local handles resolve to native pointers" {
    @memset(&global_test_buffer, 0);

    const P = Pointer(u8, SMALL_HANDLE_SOURCE);
    var ptr = P.new(2);

    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), @intFromPtr(ptr.ptr()));
    ptr.set(0xAB);
    try testing.expectEqual(@as(u8, 0xAB), global_test_buffer[2]);

    const next = ptr.add_assert_contiguous(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[3]), @intFromPtr(next.ptr()));
    next.set(0xCD);
    try testing.expectEqual(@as(u8, 0xCD), global_test_buffer[3]);

    const back = next.subtract_assert_contiguous(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), @intFromPtr(back.ptr()));

    const slice = ptr.slice(2);
    try testing.expectEqual(@as(u8, 0xAB), slice[0]);
    try testing.expectEqual(@as(u8, 0xCD), slice[1]);

    const moved = ptr.move(1);
    try testing.expectEqual(@intFromPtr(&global_test_buffer[3]), @intFromPtr(moved.ptr()));

    try testing.expectEqual(@as(u32, 2), ptr.local_addr());
    try testing.expectEqual(@intFromPtr(&global_test_buffer[2]), ptr.resolved_addr());
    try testing.expectEqual(@as(?usize, @intFromPtr(&global_test_buffer[2])), ptr.resolved_addr_or_null());
    try testing.expectEqual(PointerSourceKind.GLOBAL_RESOLVER, ptr.source_kind());
    try testing.expect(!ptr.is_native());
    try testing.expect(ptr.is_global_resolver());
    try testing.expect(ptr.eql(ptr));
    try testing.expect(!ptr.eql_local(moved));
    try testing.expect(ptr.eql_native(&global_test_buffer[2]));

    const NullableP = NullablePointer(u8, SMALL_HANDLE_SOURCE);
    const null_ptr = NullableP.new(NullableP.Opaque.AddrNull);
    const null_aligned = null_ptr.to_align(16);
    try testing.expect(null_aligned.is_null());
}
