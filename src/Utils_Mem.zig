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
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;

const Root = @import("./_root.zig");
const Cast = Root.Cast;
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const array_to_vector = Cast.array_to_vector;
const vector_to_array = Cast.vector_to_array;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;

const Kind = Types.Kind;
const KindInfo = Types.KindInfo;

const NON_SIMD_UNROLL_LEN: comptime_int = 8;
const NON_SIMD_UNROLL_LEN_BIT_SHIFT: comptime_int = 3;
const USIZE_SIZE: comptime_int = @sizeOf(usize);

/// This should match `std.mem.use_vectors`
pub const use_vectors = switch (build.zig_backend) {
    // These backends don't support vectors yet.
    .stage2_aarch64,
    .stage2_powerpc,
    .stage2_riscv64,
    => false,
    // The SPIR-V backend does not support the optimized path yet.
    .stage2_spirv => false,
    else => true,
};

pub const ValReturnMode = enum(u8) {
    VAL,
    PTR,
    CONST_PTR,

    pub fn get_type(comptime self: ValReturnMode, comptime T: type) type {
        switch (self) {
            .VAL => T,
            .PTR => *T,
            .CONST_PTR => *const T,
        }
    }
};

pub fn pointer_resides_in_slice(comptime T: type, slice: []const T, pointer: *const T) bool {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const ptr_addr = @intFromPtr(pointer);
    return start_addr <= ptr_addr and ptr_addr <= end_addr;
}

pub fn slice_resides_in_slice(comptime T: type, slice: []const T, sub_slice: []const T) bool {
    const start_addr = @intFromPtr(slice.ptr);
    const end_addr = @intFromPtr(slice.ptr + slice.len - 1);
    const sub_start_addr = @intFromPtr(sub_slice.ptr);
    const sub_end_addr = @intFromPtr(sub_slice.ptr + sub_slice.len - 1);
    return start_addr <= sub_start_addr and sub_end_addr <= end_addr;
}

pub fn index_from_pointer(comptime T: type, comptime IDX: type, base_ptr: [*]const T, elem_ptr: *const T) IDX {
    const base_addr = @intFromPtr(base_ptr);
    const elem_addr = @intFromPtr(elem_ptr);
    assert_with_reason(elem_addr >= base_addr, @src(), "elem_addr {x} < base_addr {x}, pointer cannot possibly be part of the base collection", .{ elem_addr, base_addr });
    const addr_delta = @intFromPtr(elem_ptr) - @intFromPtr(base_ptr);
    return @intCast(addr_delta / @sizeOf(T));
}

pub inline fn secure_zero(comptime T: type, slice: []volatile T) void {
    const raw_len = slice.len * @sizeOf(T);
    const u8_ptr: [*]volatile u8 = @ptrCast(slice.ptr);
    @memset(u8_ptr[0..raw_len], 0);
}
pub inline fn secure_memset_undefined(comptime T: type, slice: []volatile T) void {
    if (build.mode == .Debug or build.mode == .ReleaseSafe) {
        const cast_ptr: [*]volatile u8 = @ptrCast(@alignCast(slice.ptr));
        const byte_len = slice.len * @sizeOf(T);
        const cast_slice: []volatile u8 = cast_ptr[0..byte_len];
        @memset(cast_slice, 0xAA);
    } else {
        @memset(slice, 0);
    }
}
pub inline fn secure_memset(comptime T: type, slice: []volatile T, val: T) void {
    @memset(slice, val);
}

/// This should match `std.mem.reverseVector`
inline fn reverse_vector_slice(comptime N: usize, comptime T: type, a: []T) [N]T {
    var res: [N]T = undefined;
    inline for (0..N) |i| {
        res[i] = a[N - i - 1];
    }
    return res;
}

pub fn move_one_and_preserve_displaced(buffer: anytype, old_idx: anytype, new_idx: anytype) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    var widx: isize = @intCast(old_idx);
    const step: isize = if (new_idx > old_idx) 1 else -1;
    var ridx: isize = widx + step;
    const val: T = buffer[old_idx];
    while (widx != new_idx) {
        buffer[@intCast(widx)] = buffer[@intCast(ridx)];
        widx = ridx;
        ridx += step;
    }
    buffer[@intCast(widx)] = val;
}

pub fn move_block_of_elements_include_last_and_preserve_displaced(buffer: anytype, first_idx_to_move: anytype, last_idx_to_move: anytype, idx_to_place_elements: usize) void {
    const BUF = @TypeOf(buffer);
    const T = Types.IndexableChild(BUF);
    Assert.assert_with_reason(first_idx_to_move <= last_idx_to_move, @src(), "`old_first` MUST be <= `old_last_inclusive`, got ({d}, {d})", .{ first_idx_to_move, last_idx_to_move });
    const len_a = (last_idx_to_move - first_idx_to_move) + 1;
    const slice_a = buffer[first_idx_to_move .. first_idx_to_move + len_a];
    var total_range: []T = undefined;
    var slice_b: []T = undefined;
    if (idx_to_place_elements < first_idx_to_move) {
        total_range = buffer[idx_to_place_elements .. last_idx_to_move + 1];
        slice_b = buffer[idx_to_place_elements..first_idx_to_move];
    } else {
        total_range = buffer[first_idx_to_move .. idx_to_place_elements + len_a];
        slice_b = buffer[last_idx_to_move + 1 .. idx_to_place_elements + len_a];
    }
    reverse_slice(slice_a);
    reverse_slice(slice_b);
    reverse_slice(total_range);
}

pub fn move_range_and_preserve_displaced(slice: anytype, first_elem_to_move: anytype, elems_to_move_end_exclusive: anytype, idx_to_place_elements: anytype) void {
    return move_block_of_elements_include_last_and_preserve_displaced(slice, first_elem_to_move, elems_to_move_end_exclusive - 1, idx_to_place_elements);
}

/// This function aligns an address forward, with the additional condition that the object
/// memory span cannot cross some *larger* boundary alignment, *UNLESS* the original offset
/// was also already aligned to the larger boundary offset. If the aligned address would cause
/// the object to cross the boundary alignment *AND* it was not already aligned to the boundary
/// alignment, it instead returns an address aligned to the larger boundary alignment.
pub fn align_forward_without_breaking_align_boundary_unless_offset_boundary_aligned(offset: usize, len_: usize, object_align: usize, boundary_align: usize) usize {
    assert_with_reason(object_align <= boundary_align, @src(), "object_align must be <= boundary_align to use this function, got {d} > {d}", .{ object_align, boundary_align });
    const initial_align = std.mem.alignForward(usize, offset, object_align);
    const initial_delta = initial_align - offset;
    if (initial_delta == 0 or object_align == boundary_align) return initial_align;
    const start_boundary_align = std.mem.alignBackward(usize, initial_align, boundary_align);
    const end_minus_one_boundary_align = std.mem.alignBackward(usize, initial_align + len_ - 1, boundary_align);
    if (start_boundary_align == end_minus_one_boundary_align) return initial_align;
    return std.mem.alignForward(usize, offset, boundary_align);
}

/// A utility 'type of container element' function that returns the natural element type for a container:
///   - Indexable types return the type that is analogous to `@typeOf(container[0])`
///     - (slices, many-item pointers, arrays, vectors, single-item pointers to arrays/vectors, Zig ArrayList, GooLibSlice, etc.)
///   - Single-item pointers return the pointer child type
///   - Raw values return their own type
///   - std.Io.Reader and std.Io.Writer = u8 (use `ElementTypeOrDefaultForReaderWriter()` to assign an element in these cases)
///
/// These types match those expected by the other memory utility funcs in this module (`get()`, `set()`, etc.)
pub fn ElementType(comptime CONTAINER: type) type {
    if (comptime Root.GooListSlice.type_is_GooListSlice(CONTAINER)) {
        return CONTAINER.T;
    } else if (comptime @hasField(CONTAINER, "items") and Types.type_is_slice(@FieldType(CONTAINER, "items"))) {
        return Types.pointer_child_type(@FieldType(CONTAINER, "items"));
    } else if (comptime KindInfo.get_kind_info(CONTAINER).is_indexable()) {
        return KindInfo.get_kind_info(CONTAINER).indexed_child_type();
    } else if (comptime Types.type_is_vector(CONTAINER)) {
        return KindInfo.get_kind_info(CONTAINER).VECTOR.child;
    } else if (comptime Types.type_is_pointer_to_vector(CONTAINER)) {
        KindInfo.get_kind_info(KindInfo.get_kind_info(CONTAINER).POINTER.child).VECTOR.child;
    } else if (comptime Types.type_is_pointer_or_slice_possibly_optional(CONTAINER)) {
        return KindInfo.get_kind_info(CONTAINER).pointer_child_type();
    } else if (comptime CONTAINER == *std.Io.Reader or CONTAINER == *std.Io.Writer) {
        return u8;
    } else {
        return CONTAINER;
    }
}
/// A utility 'type of container element' function that returns the natural element type for a container:
///   - Indexable types return the type that is analogous to `@typeOf(container[0])`
///     - (slices, many-item pointers, arrays, vectors, single-item pointers to arrays/vectors, Zig ArrayList, GooLibSlice, etc.)
///   - Single-item pointers return the pointer child type
///   - Raw values return their own type
///   - std.Io.Reader and std.Io.Writer = provided `DEFAULT` type
///
/// These types match those expected by the other memory utility funcs in this module (`get()`, `set()`, etc.)
pub fn ElementTypeOrDefaultForReaderWriter(comptime CONTAINER: type, comptime DEFAULT: type) type {
    if (comptime Root.GooListSlice.type_is_GooListSlice(CONTAINER)) {
        return CONTAINER.T;
    } else if (comptime KindInfo.get_kind_info(CONTAINER).is_struct() and @hasField(CONTAINER, "items") and Types.type_is_slice(@FieldType(CONTAINER, "items"))) {
        return Types.pointer_child_type(@FieldType(CONTAINER, "items"));
    } else if (comptime KindInfo.get_kind_info(CONTAINER).is_indexable()) {
        return KindInfo.get_kind_info(CONTAINER).indexed_child_type();
    } else if (comptime Types.type_is_vector(CONTAINER)) {
        return KindInfo.get_kind_info(CONTAINER).VECTOR.child;
    } else if (comptime Types.type_is_pointer_to_vector(CONTAINER)) {
        KindInfo.get_kind_info(KindInfo.get_kind_info(CONTAINER).POINTER.child).VECTOR.child;
    } else if (comptime Types.type_is_pointer_or_slice_possibly_optional(CONTAINER)) {
        return KindInfo.get_kind_info(CONTAINER).pointer_child_type();
    } else if (comptime CONTAINER == *std.Io.Reader or CONTAINER == *std.Io.Writer) {
        return DEFAULT;
    } else {
        return CONTAINER;
    }
}

/// A utility 'append' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList (asserts that no allocation error returned)
///   - ArrayListManaged (asserts that no allocation error returned)
///   - slices ([]T, assumes extending slice length is valid and does not use allocator)
///   - many-item pointers ([*]T, assumes incrementing pointer address is valid and does not use allocator)
///   - single-item pointers (*T, overwrites current value, use with caution)
///   - raw values with the same type as the new value (value is replaced, use with caution)
///   - *std.Io.Writer (value written as raw bytes, asserts no write error occurs)
pub fn append(container: anytype, val: anytype, alloc: Allocator) @TypeOf(container) {
    const CONTAINER = @TypeOf(container);
    const ELEM = @TypeOf(val);
    var new_container = container;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        new_container = new_container.append(val, alloc);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM)) {
        new_container.append(alloc, val) catch |err| assert_unreachable_err(@src(), err);
    } else if (comptime Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        new_container.append(val) catch |err| assert_unreachable_err(@src(), err);
    } else if (comptime Types.type_is_slice_with_child_type(CONTAINER, ELEM)) {
        new_container.ptr[new_container.len] = val;
        new_container = new_container.ptr[0 .. new_container.len + 1];
    } else if (comptime Types.type_is_many_item_pointer_with_child_type(CONTAINER, ELEM)) {
        new_container[0] = val;
        new_container += 1;
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        new_container.* = val;
    } else if (comptime CONTAINER == ELEM) {
        new_container = val;
    } else if (comptime CONTAINER == *std.Io.Writer) {
        const c: *std.Io.Writer = new_container;
        const as_bytes = std.mem.asBytes(&val);
        c.writeAll(as_bytes) catch |err| assert_unreachable_err(@src(), err);
        new_container = c;
    } else {
        assert_unreachable(@src(), "cannot implicitly append type `{s}` to container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
    return new_container;
}

/// A utility 'append assume capacity' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList (asserts that no allocation error returned)
///   - ArrayListManaged (asserts that no allocation error returned)
///   - slices ([]T, assumes extending slice length is valid and does not use allocator)
///   - many-item pointers ([*]T, assumes incrementing pointer address is valid and does not use allocator)
///   - single-item pointers (*T, overwrites current value, use with caution)
///   - raw values with the same type as the new value (value is replaced, use with caution)
///   - *std.Io.Writer (value written as raw bytes, asserts no write error occurs)
pub fn append_assume_capacity(container: anytype, val: anytype) @TypeOf(container) {
    const CONTAINER = @TypeOf(container);
    const ELEM = @TypeOf(val);
    var new_container = container;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        new_container = new_container.append_assume_capacity(val);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM)) {
        new_container.appendAssumeCapacity(val);
    } else if (comptime Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        new_container.appendAssumeCapacity(val);
    } else if (comptime Types.type_is_slice_with_child_type(CONTAINER, ELEM)) {
        new_container.ptr[new_container.len] = val;
        new_container = new_container.ptr[0 .. new_container.len + 1];
    } else if (comptime Types.type_is_many_item_pointer_with_child_type(CONTAINER, ELEM)) {
        new_container[0] = val;
        new_container += 1;
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        new_container.* = val;
    } else if (comptime CONTAINER == ELEM) {
        new_container = val;
    } else if (comptime CONTAINER == *std.Io.Writer) {
        const c: *std.Io.Writer = new_container;
        const as_bytes = std.mem.asBytes(&val);
        c.writeAll(as_bytes) catch |err| assert_unreachable_err(@src(), err);
        new_container = c;
    } else {
        assert_unreachable(@src(), "cannot implicitly append type `{s}` to container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
    return new_container;
}

/// A utility 'dequeue' (get first item and increment start location) function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList (asserts length is not 0)
///   - ArrayListManaged (asserts length is not 0)
///   - slices ([]T, asserts length is not 0)
///   - many-item pointers ([*]T, assumes incrementing pointer address is valid)
///   - single-item pointers (*T, returns value but does not increment address, use with caution)
///   - raw values with the same type as requested (value is returned, use with caution)
///   - *std.Io.Reader (value read as raw bytes, no checks for validity, asserts no read error occurs)
pub fn dequeue(comptime ELEM: type, container: anytype) struct { @TypeOf(container), ELEM } {
    const CONTAINER = @TypeOf(container);
    var new_container = container;
    var val: ELEM = undefined;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        val = new_container.get_first_item();
        new_container = new_container.shrink_sub_slice_left(1);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        val = new_container.items[0];
        new_container.items = new_container.items[1..];
        new_container.capacity -= 1;
    } else if (comptime Types.type_is_slice_with_child_type(CONTAINER, ELEM)) {
        val = new_container[0];
        new_container = new_container[1..];
    } else if (comptime Types.type_is_many_item_pointer_with_child_type(CONTAINER, ELEM)) {
        val = new_container[0];
        new_container += 1;
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        val = new_container.*;
    } else if (comptime CONTAINER == ELEM) {
        val = new_container;
    } else if (comptime CONTAINER == *std.Io.Reader) {
        const reader: *std.Io.Reader = new_container;
        const as_bytes = std.mem.asBytes(&val);
        reader.readSliceAll(as_bytes) catch |err| assert_unreachable_err(@src(), err);
        new_container = reader;
    } else {
        assert_unreachable(@src(), "cannot implicitly dequeue type `{s}` from container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
    return .{ new_container, val };
}

/// A utility 'dequeue or null' (if any items exist, get first item and increment start location) function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]T, assumes incrementing pointer address is valid, never null)
///   - single-item pointers (*T, returns value but does not increment address, use with caution)
///   - raw values with the same type as requested (value is returned, use with caution)
///   - *std.Io.Reader (value read as raw bytes, no checks for validity, read error results in null value)
pub fn dequeue_or_null(comptime ELEM: type, container: anytype) struct { @TypeOf(container), ?ELEM } {
    const CONTAINER = @TypeOf(container);
    var new_container = container;
    var val: ?ELEM = null;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        if (new_container.len() > 0) {
            val = new_container.get_first_item();
            new_container = new_container.shrink_sub_slice_left(1);
        }
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        if (new_container.items.len > 0) {
            val = new_container.items[0];
            new_container.items = new_container.items[1..];
            new_container.capacity -= 1;
        }
    } else if (comptime Types.type_is_slice_with_child_type(CONTAINER, ELEM)) {
        if (new_container.len > 0) {
            val = new_container[0];
            new_container = new_container[1..];
        }
    } else if (comptime Types.type_is_many_item_pointer_with_child_type(CONTAINER, ELEM)) {
        val = new_container[0];
        new_container += 1;
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        val = new_container.*;
    } else if (comptime CONTAINER == ELEM) {
        val = new_container;
    } else if (comptime CONTAINER == *std.Io.Reader) {
        const reader: *std.Io.Reader = new_container;
        val = @as(ELEM, undefined);
        const as_bytes = std.mem.asBytes(&val.?);
        reader.readSliceAll(as_bytes) catch {
            val = null;
        };
        new_container = reader;
    } else {
        assert_unreachable(@src(), "cannot implicitly dequeue type `{s}` from container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
    return .{ new_container, val };
}

/// A utility 'set element at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]T)
///   - single-item pointers to arrays (*[N]T)
///   - single-item pointers (*T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*[N]T, *@Vector(N, T))
pub fn set(container: anytype, idx: anytype, val: anytype) @TypeOf(container) {
    const CONTAINER = @TypeOf(container);
    const ELEM = @TypeOf(val);
    var new_container = container;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        new_container.set_item(idx, val);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        new_container.items[idx] = val;
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        new_container[idx] = val;
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array = vector_to_array(new_container);
        as_array[idx] = val;
        new_container = array_to_vector(as_array);
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array_ptr = Cast.vector_to_array_pointer(new_container);
        as_array_ptr[idx] = val;
        new_container = Cast.array_to_vector_pointer(as_array_ptr);
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        assert_with_reason(idx == 0, @src(), "cannot `set` a single-item pointer at any index other than 0, got idx {d}", .{idx});
        new_container.* = val;
    } else if (comptime CONTAINER == ELEM) {
        assert_with_reason(idx == 0, @src(), "cannot `set` a raw value at any index other than 0, got idx {d}", .{idx});
        new_container = val;
    } else {
        assert_unreachable(@src(), "cannot implicitly 'set at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
    return new_container;
}

/// A utility that builds a prototype 'set element field at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn set_field_concrete_proto(comptime CONTAINER: type, comptime ELEM: type, comptime FIELD_NAME: []const u8, comptime FIELD_TYPE: type, comptime IDX: type) type {
    const SET_FIELD_FN = fn (container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                container.set_item_field(FIELD_NAME, idx, val);
                return container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                @field(&container.items[idx], FIELD_NAME) = val;
                return container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                @field(&container[idx], FIELD_NAME) = val;
                return container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                const as_array = vector_to_array(container);
                @field(&as_array[idx], FIELD_NAME) = val;
                return array_to_vector(as_array);
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                const as_array_ptr = Cast.vector_to_array_pointer(container);
                @field(as_array_ptr[idx], FIELD_NAME) = val;
                return Cast.array_to_vector_pointer(as_array_ptr);
            }

            pub const SetFieldFn = SET_FIELD_FN;
        };
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                assert_with_reason(idx == 0, @src(), "cannot `set` a single-item pointer at any index other than 0, got idx {d}", .{idx});
                @field(container, FIELD_NAME) = val;
                return container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else if (comptime CONTAINER == ELEM) {
        return struct {
            pub fn set_field(container: CONTAINER, idx: IDX, val: FIELD_TYPE) CONTAINER {
                assert_with_reason(idx == 0, @src(), "cannot `set` a raw value at any index other than 0, got idx {d}", .{idx});
                var new_container = container;
                @field(new_container, FIELD_NAME) = val;
                return new_container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    } else {
        return struct {
            pub fn set_field(container: CONTAINER, _: IDX, _: FIELD_TYPE) CONTAINER {
                assert_unreachable(@src(), "cannot implicitly 'set field at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
                return container;
            }

            pub const SetFieldFn = SET_FIELD_FN;
            pub const OptSetFieldFn = ?SET_FIELD_FN;
        };
    }
}

/// A utility 'set element field at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]T)
///   - single-item pointers to arrays (*[N]T)
///   - single-item pointers (*T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*[N]T, *@Vector(N, T))
pub fn set_field(container: anytype, comptime ELEM: type, comptime field: []const u8, idx: anytype, val: anytype) @TypeOf(container) {
    const PROTO = set_field_concrete_proto(@TypeOf(container), ELEM, field, @TypeOf(val), @TypeOf(idx));
    return PROTO.set_field(container, idx, val);
}

/// A utility 'get element at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get(comptime ELEM: type, container: anytype, idx: anytype) ELEM {
    const CONTAINER = @TypeOf(container);
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        return container.get_item(idx);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        return container.items[idx];
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        return container[idx];
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array = vector_to_array(container);
        return as_array[idx];
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array_ptr = Cast.vector_to_array_pointer(container);
        return as_array_ptr[idx];
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a single-item pointer at any index other than 0, got idx {d}", .{idx});
        return container.*;
    } else if (comptime CONTAINER == ELEM) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a raw value at any index other than 0, got idx {d}", .{idx});
        return container;
    } else {
        assert_unreachable(@src(), "cannot implicitly 'get at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
}

// /// A utility 'get element at index' function that accepts any of the following containers:
// ///   - GooListSlice
// ///   - ArrayList
// ///   - ArrayListManaged
// ///   - slices ([]T)
// ///   - many-item pointers ([*]const T)
// ///   - single-item pointers to arrays (*const [N]T)
// ///   - single-item pointers (*const T, asserts index is 0)
// ///   - raw values with the same type as the new value (asserts index is 0)
// ///   - raw arrays or vectors ([N]T, @Vector(N, T))
// ///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
// pub fn len(comptime IDX: type, comptime ELEM: type, container: anytype) IDX {
//     const CONTAINER = @TypeOf(container);
//     if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
//         return @intCast(container.len());
//     } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
//         return @intCast(container.items.len);
//     } else if (comptime KindInfo.get_kind_info(CONTAINER).has_len(ELEM)) {
//         return @intCast(container.len);
//     } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
//         return 1;
//     } else if (comptime Types.type_is_optional(CONTAINER, ELEM)) {
//         return 1;
//     } else if (comptime CONTAINER == ELEM) {
//         assert_with_reason(idx == 0, @src(), "cannot `get` a raw value at any index other than 0, got idx {d}", .{idx});
//         return container;
//     } else {
//         assert_unreachable(@src(), "cannot implicitly 'get at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
//     }
// }

/// A utility 'get element at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_ptr(comptime ELEM: type, container: anytype, idx: anytype) *ELEM {
    const CONTAINER = @TypeOf(container);
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        return container.get_item_ptr(idx);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        return &container.items[idx];
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        return &container[idx];
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array = vector_to_array(container);
        return &as_array[idx];
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array_ptr = Cast.vector_to_array_pointer(container);
        return &as_array_ptr[idx];
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a single-item pointer at any index other than 0, got idx {d}", .{idx});
        return container;
    } else if (comptime CONTAINER == ELEM) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a raw value at any index other than 0, got idx {d}", .{idx});
        return &container;
    } else {
        assert_unreachable(@src(), "cannot implicitly 'get ptr at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
}

/// A utility 'get element at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_ptr_const(comptime ELEM: type, container: anytype, idx: anytype) *const ELEM {
    const CONTAINER = @TypeOf(container);
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        return container.get_item_ptr(idx);
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        return &container.items[idx];
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        return &container[idx];
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array = vector_to_array(container);
        return &as_array[idx];
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        const as_array_ptr = Cast.vector_to_array_pointer(container);
        return &as_array_ptr[idx];
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a single-item pointer at any index other than 0, got idx {d}", .{idx});
        return container;
    } else if (comptime CONTAINER == ELEM) {
        assert_with_reason(idx == 0, @src(), "cannot `get` a raw value at any index other than 0, got idx {d}", .{idx});
        return &container;
    } else {
        assert_unreachable(@src(), "cannot implicitly 'get ptr at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
    }
}

/// A utility that builds a prototype 'get element field at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_field_concrete_proto(comptime CONTAINER: type, comptime ELEM: type, comptime FIELD_NAME: []const u8, comptime FIELD_TYPE: type, comptime RETURN_MODE: ValReturnMode, comptime IDX: type) type {
    const VAL_TO_RETURN = RETURN_MODE.get_type(FIELD_TYPE);
    const GET_FIELD_FN = fn (container: CONTAINER, idx: IDX) VAL_TO_RETURN;
    if (comptime Root.GooListSlice.type_is_GooListSlice_with_element_type(CONTAINER, ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                switch (comptime RETURN_MODE) {
                    .VAL => return container.get_item_field(FIELD_NAME, idx),
                    .PTR, .CONST_PTR => return container.get_item_field_ptr(FIELD_NAME, idx),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime Types.type_is_zig_list(CONTAINER, ELEM) or Types.type_is_zig_list_managed(CONTAINER, ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(&container.items[idx], FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(&container.items[idx], FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime KindInfo.get_kind_info(CONTAINER).has_indexable_child_type(ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(&container[idx], FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(&container[idx], FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime Types.type_is_vector_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                const as_array = vector_to_array(container);
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(as_array[idx], FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(as_array[idx], FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime Types.type_is_pointer_to_vector_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                const as_array_ptr = Cast.vector_to_array_pointer(container);
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(&as_array_ptr[idx], FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(&as_array_ptr[idx], FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime Types.type_is_pointer_with_child_type(CONTAINER, ELEM)) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                assert_with_reason(idx == 0, @src(), "cannot `get` a single-item pointer at any index other than 0, got idx {d}", .{idx});
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(container, FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(container, FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else if (comptime CONTAINER == ELEM) {
        return struct {
            pub fn get_field(container: CONTAINER, idx: IDX) VAL_TO_RETURN {
                assert_with_reason(idx == 0, @src(), "cannot `get` a raw value at any index other than 0, got idx {d}", .{idx});
                switch (comptime RETURN_MODE) {
                    .VAL => return @field(&container, FIELD_NAME),
                    .PTR, .CONST_PTR => return &@field(&container, FIELD_NAME),
                }
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    } else {
        return struct {
            pub fn get_field(_: CONTAINER, _: IDX) VAL_TO_RETURN {
                assert_unreachable(@src(), "cannot implicitly 'get field at index' with element type `{s}` for container type `{s}`", .{ @typeName(ELEM), @typeName(CONTAINER) });
            }

            pub const GetFieldFn = GET_FIELD_FN;
            pub const OptGetFieldFn = ?GET_FIELD_FN;
        };
    }
}

/// A utility 'get element field value at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_field(container: anytype, comptime ELEM: type, comptime field: []const u8, idx: anytype) Types.field_type(ELEM, field) {
    const PROTO = get_field_concrete_proto(@TypeOf(container), ELEM, field, Types.field_type(ELEM, field), .VAL, @TypeOf(idx));
    return PROTO.get_field(container, idx);
}

/// A utility 'get element field pointer at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_field_ptr(container: anytype, comptime ELEM: type, comptime field: []const u8, idx: anytype) *Types.field_type(ELEM, field) {
    const PROTO = get_field_concrete_proto(@TypeOf(container), ELEM, field, Types.field_type(ELEM, field), .PTR, @TypeOf(idx));
    return PROTO.get_field(container, idx);
}

/// A utility 'get element field const pointer at index' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]const T)
///   - single-item pointers to arrays (*const [N]T)
///   - single-item pointers (*const T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*const [N]T, *const @Vector(N, T))
pub fn get_field_const_ptr(container: anytype, comptime ELEM: type, comptime field: []const u8, idx: anytype) *const Types.field_type(ELEM, field) {
    const PROTO = get_field_concrete_proto(@TypeOf(container), ELEM, field, Types.field_type(ELEM, field), .CONST_PTR, @TypeOf(idx));
    return PROTO.get_field(container, idx);
}

/// A utility 'swap two elements' function that accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]T)
///   - single-item pointers to arrays (*[N]T)
///   - single-item pointers (*T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*[N]T, *@Vector(N, T))
pub fn swap(comptime ELEM: type, container: anytype, idx_a: anytype, idx_b: @TypeOf(idx_a)) @TypeOf(container) {
    const val_a = get(ELEM, container, idx_a);
    const val_b = get(ELEM, container, idx_b);
    var new_container = set(container, idx_a, val_b);
    new_container = set(new_container, idx_b, val_a);
    return new_container;
}

/// A utility 'scramble' function that swaps random pairs of indices within the given range,
/// and accepts any of the following containers:
///   - GooListSlice
///   - ArrayList
///   - ArrayListManaged
///   - slices ([]T)
///   - many-item pointers ([*]T)
///   - single-item pointers to arrays (*[N]T)
///   - single-item pointers (*T, asserts index is 0)
///   - raw values with the same type as the new value (asserts index is 0)
///   - raw arrays or vectors ([N]T, @Vector(N, T))
///   - pointers to arrays or vectors (*[N]T, *@Vector(N, T))
pub fn scramble(comptime ELEM: type, container: anytype, range_start: anytype, range_end_exclusive: anytype, rand: std.Random, iterations: anytype) @TypeOf(container) {
    const IDX = Cast.RuntimeNumeric(@TypeOf(range_end_exclusive));
    var new_container = container;
    const span = range_end_exclusive - range_start;
    if (span <= 1) return container;
    if (span == 2) {
        if (rand.boolean()) {
            return swap(ELEM, container, range_start, range_start + 1);
        }
    }
    var n: IDX = 0;
    while (n < iterations) : (n += 1) {
        const idx_a = rand.intRangeAtMost(IDX, @intCast(range_start), range_end_exclusive - 1);
        const idx_b = get_different: {
            while (true) {
                const possible_b = rand.intRangeAtMost(IDX, range_start, range_end_exclusive - 1);
                if (possible_b != idx_a) break :get_different possible_b;
            }
        };
        new_container = swap(ELEM, new_container, idx_a, idx_b);
    }
    return new_container;
}

/// This method moves all items at `data_ptr[start..]` up `n` places,
/// and alters `len_ptr` to reflect the new length
///
/// Assumes `data_ptr[0..(len_ptr.* + n)]` is a valid slice (sufficient memory is allocated)
pub fn insert(data_ptr: anytype, len_ptr: anytype, start: usize, n: usize) void {
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const new_start = start + n;
    const move_len: usize = @as(usize, @intCast(len_ptr.*)) - start;
    @memmove(data_ptr[new_start .. new_start + move_len], data_ptr[start .. start + move_len]);
    len_ptr.* += @intCast(n);
}

/// This method moves all items at `data_ptr[start+n..]` down `n` places,
/// and alters `len_ptr` to reflect the new length
pub fn remove(data_ptr: anytype, len_ptr: anytype, start: usize, n: usize) void {
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const new_start = start + n;
    const move_len: usize = @as(usize, @intCast(len_ptr.*)) - new_start;
    @memmove(data_ptr[start .. start + move_len], data_ptr[new_start .. new_start + move_len]);
    len_ptr.* -= @intCast(n);
}

/// This method deletes all of the indexes from the provided list (sorted low to high)
/// by moving all indexes above the first one in the list and not ALSO included in the list,
/// down.
pub fn remove_sparse_by_indexes_sorted_low_to_high(data_ptr: anytype, len_ptr: anytype, sorted_indexes: []const usize) void {
    if (sorted_indexes.len == 0 or sorted_indexes[0] >= len_ptr.*) return;
    const PTR = @TypeOf(data_ptr);
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_many_item_pointer(PTR), @src(), "type of `data_ptr` must be a many-item-pointer, got type {s}", .{@typeName(PTR)});
    const PTR_INFO = @typeInfo(PTR).pointer;
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    var read_idx: usize = sorted_indexes[0] + 1;
    var write_idx: usize = sorted_indexes[0];
    var del_idx_idx: usize = 1;
    var del_idx: usize = undefined;
    const slice: []PTR_INFO.child = data_ptr[0..@as(usize, @intCast(len_ptr.*))];
    while (del_idx_idx < sorted_indexes.len) {
        del_idx = sorted_indexes[del_idx_idx];
        while (read_idx < del_idx) {
            slice[write_idx] = slice[read_idx];
            read_idx += 1;
            write_idx += 1;
        }
        read_idx += 1;
        del_idx_idx += 1;
    }
    while (read_idx < slice.len) {
        slice[write_idx] = slice[read_idx];
        read_idx += 1;
        write_idx += 1;
    }
    len_ptr.* -= @intCast(del_idx_idx);
}

/// This method deletes all of the indexes from the provided list (sorted low to high)
/// by moving all indexes above the first on in the list and not ALSO included in the list,
/// down.
pub fn remove_sparse_by_values_in_list_order(comptime T: type, data_ptr: [*]T, len_ptr: anytype, known_start_index: usize, equality_func: *const fn (a: T, b: T) bool, values_in_order: []const T) void {
    if (values_in_order.len == 0) return;
    const LEN_PTR = @TypeOf(len_ptr);
    assert_with_reason(Types.type_is_single_item_pointer(LEN_PTR), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    const LEN = @typeInfo(LEN_PTR).pointer.child;
    assert_with_reason(Types.type_is_int(LEN), @src(), "type of `len_ptr` must be a single-item-pointer to an integer type, got type {s}", .{@typeName(LEN_PTR)});
    var read_idx: usize = known_start_index;
    var write_idx: usize = known_start_index;
    var del_val_idx: usize = 0;
    var del_val: T = values_in_order[0];
    var found_at_least_one: bool = false;
    const slice: []T = data_ptr[0..@as(usize, @intCast(len_ptr.*))];
    while (read_idx < slice.len) {
        const this_val = slice[read_idx];
        if (equality_func(this_val, del_val)) {
            del_val_idx += 1;
            if (del_val_idx < values_in_order.len) {
                del_val = values_in_order[del_val_idx];
            }
            write_idx = read_idx;
            read_idx += 1;
            found_at_least_one = true;
            break;
        } else {
            read_idx += 1;
        }
    }
    while (read_idx < slice.len and del_val_idx < values_in_order.len) {
        const this_val = slice[read_idx];
        if (equality_func(this_val, del_val)) {
            del_val_idx += 1;
            read_idx += 1;
            if (del_val_idx < values_in_order.len) {
                del_val = values_in_order[del_val_idx];
            }
        } else {
            slice[write_idx] = slice[read_idx];
            read_idx += 1;
            write_idx += 1;
        }
    }
    if (!found_at_least_one) return;
    while (read_idx < slice.len) {
        slice[write_idx] = slice[read_idx];
        read_idx += 1;
        write_idx += 1;
    }
    len_ptr.* -= @intCast(del_val_idx);
}

pub fn reverse_array(arr_ptr: anytype) void {
    const T = @TypeOf(arr_ptr);
    const INFO = KindInfo.get_kind_info(T);
    assert_with_reason(INFO == .POINTER and INFO.POINTER.size == .one and INFO.POINTER.is_const == false, @src(), "`arr_ptr` must be a mutable pointer to an array, got type `{s}`", .{@typeName(T)});
    const PTR_CHILD = INFO.POINTER.child;
    const CHILD_INFO = KindInfo.get_kind_info(PTR_CHILD);
    assert_with_reason(CHILD_INFO == .ARRAY, @src(), "`arr_ptr` must be a mutable pointer to an array, got type `{s}`", .{@typeName(T)});
    const ARR_INFO = CHILD_INFO.ARRAY;
    const TT = ARR_INFO.child;
    const LEN = ARR_INFO.len;
    const LAST = LEN - 1;
    const HALF = LEN >> 1;
    if (HALF <= NON_SIMD_UNROLL_LEN) {
        inline for (0..HALF) |i| {
            const tmp = arr_ptr[i];
            arr_ptr[i] = arr_ptr[LAST - i];
            arr_ptr[LAST - i] = tmp;
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime() and @bitSizeOf(TT) > 0 and std.math.isPowerOfTwo(@bitSizeOf(TT))) {
            if (std.simd.suggestVectorLength(T)) |SIMD_SIZE| {
                if (SIMD_SIZE <= HALF) {
                    const SIMD_END = HALF - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const left_slice = arr_ptr[i .. i + SIMD_SIZE];
                        const right_slice = arr_ptr[LEN - i - SIMD_SIZE .. LEN - i];

                        const left_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, left_slice);
                        const right_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, right_slice);

                        @memcpy(right_slice, &left_shuffled);
                        @memcpy(left_slice, &right_shuffled);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > HALF) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const tmp = arr_ptr[iii];
                arr_ptr[iii] = arr_ptr[LAST - iii];
                arr_ptr[LAST - iii] = tmp;
            }
            i = next_i;
        }
        while (i < HALF) : (i += 1) {
            const tmp = arr_ptr[i];
            arr_ptr[i] = arr_ptr[LAST - i];
            arr_ptr[LAST - i] = tmp;
        }
    }
}

pub fn reverse_slice(slice: anytype) void {
    const T = @TypeOf(slice);
    const INFO = KindInfo.get_kind_info(T);
    assert_with_reason(INFO == .POINTER and INFO.POINTER.size == .slice and INFO.POINTER.is_const == false, @src(), "`slice` must be a mutable pointer to a slice, got type `{s}`", .{@typeName(T)});
    const SLICE = INFO.POINTER;
    const TT = SLICE.child;
    const len = slice.len;
    const last = len - 1;
    const half = len >> 1;
    if (half <= NON_SIMD_UNROLL_LEN) {
        switch (half) {
            inline 0...NON_SIMD_UNROLL_LEN => |HALF| {
                inline for (0..HALF) |i| {
                    const tmp = slice[i];
                    slice[i] = slice[last - i];
                    slice[last - i] = tmp;
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime() and @bitSizeOf(TT) > 0 and std.math.isPowerOfTwo(@bitSizeOf(TT))) {
            if (std.simd.suggestVectorLength(T)) |SIMD_SIZE| {
                if (SIMD_SIZE <= half) {
                    const SIMD_END = half - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const left_slice = slice[i .. i + SIMD_SIZE];
                        const right_slice = slice[len - i - SIMD_SIZE .. len - i];
                        const left_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, left_slice);
                        const right_shuffled: [SIMD_SIZE]TT = reverse_vector_slice(SIMD_SIZE, TT, right_slice);
                        @memcpy(right_slice, &left_shuffled);
                        @memcpy(left_slice, &right_shuffled);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > half) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const tmp = slice[iii];
                slice[iii] = slice[last - iii];
                slice[last - iii] = tmp;
            }
            i = next_i;
        }
        while (i < half) : (i += 1) {
            const tmp = slice[i];
            slice[i] = slice[last - i];
            slice[last - i] = tmp;
        }
    }
}

pub fn array_or_slice_equal(a: anytype, b: anytype) bool {
    const A = @TypeOf(a);
    const B = @TypeOf(b);
    const A_INFO = KindInfo.get_kind_info(A);
    const B_INFO = KindInfo.get_kind_info(B);
    assert_with_reason(A_INFO.has_indexable_child_that_matches(B_INFO), @src(), "type of `a` `{s}` and type of `b` `{s}` do not have matching indexable child types (or one of them is not indexable)", .{ @typeName(A), @typeName(B) });
    assert_with_reason(A_INFO.has_len(), @src(), "`a` must have a defined `len` (either be an array, vector, or slice)", .{});
    assert_with_reason(B_INFO.has_len(), @src(), "`b` must have a defined `len` (either be an array, vector, or slice)", .{});
    if (a.len != b.len) return false;
    const LEN = if (A_INFO == .ARRAY or A_INFO == .VECTOR) a.len else b.len;
    if (LEN <= NON_SIMD_UNROLL_LEN) {
        switch (LEN) {
            inline 0...NON_SIMD_UNROLL_LEN => |LEN_2| {
                inline for (0..LEN_2) |i| {
                    if (!object_equals(a[i], b[i])) return false;
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        const ELEM = A_INFO.indexed_child_type();
        const ELEM_INFO = KindInfo.get_kind_info(ELEM);
        if (use_vectors and !@inComptime() and ELEM_INFO.has_impicit_equals()) {
            if (std.simd.suggestVectorLength(ELEM)) |SIMD_SIZE| {
                while (true) {
                    const next_i = i + SIMD_SIZE;
                    if (next_i > LEN) break;
                    const a_vec_ptr: *const @Vector(SIMD_SIZE, ELEM) = @ptrCast(&a[i]);
                    const b_vec_ptr: *const @Vector(SIMD_SIZE, ELEM) = @ptrCast(&b[i]);
                    const a_vec = a_vec_ptr.*;
                    const b_vec = b_vec_ptr.*;
                    if (@reduce(.Or, a_vec != b_vec)) return false;
                    i = next_i;
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > LEN) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                if (!object_equals(a[iii], b[iii])) return false;
            }
            i = next_i;
        }
        while (i < LEN) : (i += 1) {
            if (!object_equals(a[i], b[i])) return false;
        }
    }
    return true;
}

fn CopyPtrAttrs(
    comptime source: type,
    comptime size: std.builtin.Type.Pointer.Size,
    comptime child: type,
) type {
    const info = @typeInfo(source).pointer;
    @Pointer(size, .{
        .@"addrspace" = info.address_space,
        .@"align" = info.alignment,
        .@"allowzero" = info.is_allowzero,
        .@"const" = info.is_const,
        .@"volatile" = info.is_volatile,
    }, child, null);
}

fn PtrAsBytes(comptime PTR: type) type {
    const pointer = @typeInfo(PTR).pointer;
    switch (pointer.size) {
        .one, .c, .many => {
            const size = @sizeOf(pointer.child);
            return CopyPtrAttrs(PTR, .one, [size]u8);
        },
        .slice => {
            return CopyPtrAttrs(PTR, .slice, u8);
        },
    }
}

/// Given a pointer to a single item or slice, returns a slice of the underlying bytes, preserving pointer attributes.
///
/// As a special case, a many-item pointer is interpeted as a single-item pointer
pub fn ptr_as_bytes(ptr: anytype) PtrAsBytes(@TypeOf(ptr)) {
    const PTR = @typeInfo(@TypeOf(ptr)).pointer;
    switch (PTR.size) {
        .one, .c, .many => return @ptrCast(@alignCast(ptr)),
        .slice => {
            const ptr_adjust: CopyPtrAttrs(PTR, .many, u8) = @ptrCast(@alignCast(ptr.ptr));
            const size = @sizeOf(PTR.child) * ptr.len;
            return ptr_adjust[0..size];
        },
    }
}

pub const CopyLenKind = enum(u8) {
    ENTIRE_SOURCE_TO_DEST,
    LIMITED_BY_SMALLER_LEN,
    PROVIDE_LEN_EXACT,
    PROVIDE_LEN_MAX,
    PROVIDE_LEN_MIN,
};

pub const CopyLen = union(CopyLenKind) {
    ENTIRE_SOURCE_TO_DEST: void,
    LIMITED_BY_SMALLER_LEN: void,
    PROVIDE_LEN_EXACT: usize,
    PROVIDE_LEN_MAX: usize,
    PROVIDE_LEN_MIN: usize,

    pub fn copy_entire_source_to_dest() CopyLen {
        return CopyLen{ .SRC_DST_ALWAYS_SAME_SIZE = void{} };
    }
    pub fn copy_as_many_elements_as_possible_from_source_to_dest() CopyLen {
        return CopyLen{ .LIMITED_BY_SMALLER_LEN = void{} };
    }
    pub fn copy_exact_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_EXACT = count };
    }
    pub fn copy_at_most_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_MAX = count };
    }
    pub fn copy_at_least_element_count(count: usize) CopyLen {
        return CopyLen{ .PROVIDE_LEN_MIN = count };
    }
};

inline fn single_memcopy_swap_as_integer(
    comptime UINT_TYPE: type,
    UINT_PTR: [*]UINT_TYPE,
    comptime DST_ELEM: type,
    DST_PTR: [*]DST_ELEM,
    comptime SRC_ELEM: type,
    SRC_PTR: [*]SRC_ELEM,
) void {
    const UINT_SIZE = @sizeOf(UINT_TYPE);
    const UINT_ALIGN = @alignOf(UINT_TYPE);
    const DST_SIZE = @sizeOf(DST_ELEM);
    const DST_ALIGN = @alignOf(DST_ELEM);
    const SRC_SIZE = @sizeOf(SRC_ELEM);
    const SRC_ALIGN = @alignOf(SRC_ELEM);
    if (SRC_ALIGN == UINT_ALIGN) {
        const src_uint_ptr: *const UINT_TYPE = @ptrCast(SRC_PTR);
        UINT_PTR.* = src_uint_ptr.*;
    } else {
        const src_bytes_ptr: *const [SRC_SIZE]u8 = @ptrCast(SRC_PTR);
        const uint_bytes_ptr: *[UINT_SIZE]u8 = @ptrCast(UINT_PTR);
        @memcpy(uint_bytes_ptr[0..UINT_SIZE], src_bytes_ptr[0..SRC_SIZE]);
    }
    UINT_PTR.* = @byteSwap(UINT_PTR.*);
    if (DST_ALIGN == UINT_ALIGN) {
        const dst_uint_ptr: *UINT_TYPE = @ptrCast(DST_PTR);
        dst_uint_ptr.* = UINT_PTR.*;
    } else {
        const dst_bytes_ptr: *[DST_SIZE]u8 = @ptrCast(DST_PTR);
        const uint_bytes_ptr: *const [UINT_SIZE]u8 = @ptrCast(UINT_PTR);
        @memcpy(dst_bytes_ptr[0..DST_SIZE], uint_bytes_ptr[0..UINT_SIZE]);
    }
}

pub fn memcopy_swap_order_typed(noalias dest: anytype, noalias source: anytype, comptime COPY_LEN: CopyLen) void {
    _ = memcopy_swap_order_typed_get_num_copied(dest, source, COPY_LEN);
}

pub fn memcopy_swap_order_typed_get_num_copied(noalias dest: anytype, noalias source: anytype, comptime COPY_LEN: CopyLen) usize {
    const DST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DST_INFO = KindInfo.get_kind_info(DST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    const DST_ELEM, const DST_ELEM_SIZE, const DST_LEN: ?usize, const DST_PTR, _ = switch (DST_INFO) {
        .POINTER => |POINTER| .{
            POINTER.child,
            @sizeOf(POINTER.child),
            switch (POINTER.size) {
                .one, .c => 1,
                .many => null,
                .slice => source.len,
            },
            switch (POINTER.size) {
                .one, .c, .many => @as([*]POINTER.child, @ptrCast(dest)),
                .slice => @as([*]POINTER.child, @ptrCast(dest.ptr)),
            },
            POINTER.alignment,
        },
        else => assert_unreachable(@src(), "only pointers are allowed for `dest` and `source`", .{}),
    };
    const SRC_ELEM, const SRC_ELEM_SIZE, const SRC_LEN: ?usize, const SRC_PTR, _ = switch (SRC_INFO) {
        .POINTER => |POINTER| .{
            POINTER.child,
            @sizeOf(POINTER.child),
            switch (POINTER.size) {
                .one, .c => 1,
                .many => null,
                .slice => source.len,
            },
            switch (POINTER.size) {
                .one, .c, .many => @as([*]POINTER.child, @ptrCast(source)),
                .slice => @as([*]POINTER.child, @ptrCast(source.ptr)),
            },
            POINTER.alignment,
        },
        else => assert_unreachable(@src(), "only pointers are allowed for `dest` and `source`", .{}),
    };
    assert_with_reason(SRC_ELEM_SIZE == DST_ELEM_SIZE, @src(), "the size of the dest element (size {d}, type {s}) does not match the size of the source element (size {d}, type {s})", .{ DST_ELEM_SIZE, @typeName(DST_ELEM), SRC_ELEM_SIZE, @typeName(SRC_ELEM) });
    var TRUE_LEN: usize = if (SRC_LEN == null and DST_LEN == null) switch (COPY_LEN) {
        .PROVIDE_LEN_EXACT => |EXACT| EXACT,
        .PROVIDE_LEN_MIN => |MIN| MIN,
        else => 1,
    } else if (SRC_LEN == null) DST_LEN.? else if (DST_LEN == null) SRC_LEN.? else get: {
        switch (COPY_LEN) {
            .ENTIRE_SOURCE_TO_DEST => {
                assert_with_reason(SRC_LEN.? == DST_LEN.?, @src(), "when both `source` and `dest` specify lengths and COPY_LEN == ENTIRE_SOURCE_TO_DEST, the lengths MUST be equal, got source len {d} != dest len {d}", .{ SRC_LEN.?, DST_LEN.? });
                break :get SRC_LEN.?;
            },
            else => {
                break :get @min(SRC_LEN.?, DST_LEN.?);
            },
        }
    };
    switch (COPY_LEN) {
        .PROVIDE_LEN_EXACT => |EXACT| {
            assert_with_reason(TRUE_LEN >= EXACT, @src(), "required to copy {d} elements, but only {d} elements can be copied", .{ EXACT, TRUE_LEN });
            TRUE_LEN = EXACT;
        },
        .PROVIDE_LEN_MAX => |MAX| {
            TRUE_LEN = @min(TRUE_LEN, MAX);
        },
        .PROVIDE_LEN_MIN => |MIN| {
            assert_with_reason(TRUE_LEN >= MIN, @src(), "required to copy at least {d} elements, but only {d} elements can be copied", .{ MIN, TRUE_LEN });
            TRUE_LEN = @max(TRUE_LEN, MIN);
        },
        else => {},
    }
    if (Types.TryUnsignedIntegerWithSameSize(DST_ELEM)) |UINT_TYPE| {
        var uint_unrolls: [NON_SIMD_UNROLL_LEN]UINT_TYPE = undefined;
        var i: usize = 0;
        const NUM_UNROLLS = TRUE_LEN >> NON_SIMD_UNROLL_LEN_BIT_SHIFT;
        const I_AFTER_UNROLLS = NUM_UNROLLS << NON_SIMD_UNROLL_LEN_BIT_SHIFT;
        while (i < I_AFTER_UNROLLS) : (i += NON_SIMD_UNROLL_LEN) {
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                const local_uint_ptr: [*]UINT_TYPE = @ptrCast(&uint_unrolls[ii]);
                const local_src_ptr: [*]const SRC_ELEM = SRC_PTR + iii;
                const local_dst_ptr: [*]DST_ELEM = DST_PTR + iii;
                single_memcopy_swap_as_integer(UINT_TYPE, local_uint_ptr, DST_ELEM, local_dst_ptr, SRC_ELEM, local_src_ptr);
            }
        }
        var ii: usize = 0;
        while (i < TRUE_LEN) : ({
            i += 1;
            ii += 1;
        }) {
            const local_uint_ptr: [*]UINT_TYPE = @ptrCast(&uint_unrolls[ii]);
            const local_src_ptr: [*]const SRC_ELEM = SRC_PTR + i;
            const local_dst_ptr: [*]DST_ELEM = DST_PTR + i;
            single_memcopy_swap_as_integer(UINT_TYPE, local_uint_ptr, DST_ELEM, local_dst_ptr, SRC_ELEM, local_src_ptr);
        }
    } else {}
}

pub fn memcopy_swap_order_builtin_any(comptime TYPE: type, noalias dest: *align(@alignOf(TYPE)) [@sizeOf(TYPE)]u8, noalias source: *align(@alignOf(TYPE)) const [@sizeOf(TYPE)]u8) void {
    @memcpy(dest, source);
    const UINT_TYPE = Types.UnsignedIntegerWithSameSize(TYPE);
    const dest_int: *UINT_TYPE = @ptrCast(dest);
    dest_int.* = @byteSwap(dest_int.*);
}

fn get_real_dest_src(byte_len: anytype, dest: anytype, comptime source: anytype) struct { []u8, []const u8 } {
    const DEST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DEST_INFO = KindInfo.get_kind_info(DEST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    const real_dest: []u8 = switch (DEST_INFO) {
        .POINTER => |POINTER| switch (POINTER.size) {
            .one, .c, .many => @as([*]u8, @ptrCast(dest))[0..byte_len],
            .slice => @as([*]u8, @ptrCast(dest.ptr))[0..byte_len],
        },
        .OPTIONAL => |OPTIONAL| check_non_null: {
            assert_with_reason(dest != null, @src(), "cannot copy to a null destination", .{});
            break :check_non_null switch (KindInfo.get_kind_info(OPTIONAL.child)) {
                .POINTER => |POINTER| switch (POINTER.size) {
                    .one, .c, .many => @as([*]u8, @ptrCast(dest.?))[0..byte_len],
                    .slice => @as([*]u8, @ptrCast(dest.?.ptr))[0..byte_len],
                },
                else => assert_unreachable(@src(), "dest must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
            };
        },
        else => assert_unreachable(@src(), "dest must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
    };
    const real_src: []const u8 = switch (SRC_INFO) {
        .POINTER => |POINTER| switch (POINTER.size) {
            .one, .c, .many => @as([*]u8, @ptrCast(source))[0..byte_len],
            .slice => @as([*]u8, @ptrCast(source.ptr))[0..byte_len],
        },
        .OPTIONAL => |OPTIONAL| check_non_null: {
            assert_with_reason(source != null, @src(), "cannot copy from a null source", .{});
            break :check_non_null switch (KindInfo.get_kind_info(OPTIONAL.child)) {
                .POINTER => |POINTER| switch (POINTER.size) {
                    .one, .c, .many => @as([*]u8, @ptrCast(source.?))[0..byte_len],
                    .slice => @as([*]u8, @ptrCast(source.?.ptr))[0..byte_len],
                },
                else => assert_unreachable(@src(), "source must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
            };
        },
        else => assert_unreachable(@src(), "source must be a pointer type, got type `{s}`", .{@typeName(SRC)}),
    };
    return .{ real_dest, real_src };
}

pub fn memcopy_exact_byte_len(byte_len: anytype, noalias dest: anytype, noalias source: anytype) []u8 {
    const real_dest: []u8, const real_src: []const u8 = get_real_dest_src(byte_len, dest, source);
    @memcpy(real_dest[0..byte_len], real_src[0..byte_len]);
}

pub fn memcopy_while_reversing_order(noalias dest: anytype, noalias source: anytype) void {
    const DST = @TypeOf(dest);
    const SRC = @TypeOf(source);
    const DST_INFO = KindInfo.get_kind_info(DST);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    assert_with_reason(DST_INFO.has_indexable_child_that_matches(SRC_INFO), @src(), "type of `dest` `{s}` and type of `source` `{s}` do not have matching indexable child types (or one of them is not indexable)", .{ @typeName(DST), @typeName(SRC) });
    assert_with_reason(DST_INFO.is_pointer() and SRC_INFO.is_pointer() and DST_INFO.POINTER.is_const == false, @src(), "both `dest` and `source` must be pointer types that can be indexed, and `dest` must not be const, got invalid dest `{s}` or source `{s}`", .{ @typeName(DST), @typeName(SRC) });
    assert_with_reason(DST_INFO.has_len() or SRC_INFO.has_len(), @src(), "either `dest` or `source` must have a defined `len` (either be an array, vector, or slice)", .{});
    if (DST_INFO.has_len() and SRC_INFO.has_len()) {
        const dest_len = DST_INFO.get_len(dest);
        const source_len = SRC_INFO.get_len(source);
        assert_with_reason(dest_len == source_len, @src(), "dest len {d} does not match source len {d}", .{ dest_len, source_len });
    }
    const CHILD = DST_INFO.indexed_child_type();
    const len = if (DST_INFO.has_len()) DST_INFO.get_len(dest) else SRC_INFO.get_len(source);
    const last = len - 1;
    if (len <= NON_SIMD_UNROLL_LEN) {
        switch (len) {
            inline 0...NON_SIMD_UNROLL_LEN => |LEN| {
                inline for (0..LEN) |i| {
                    dest[i] = source[last - i];
                }
            },
            else => unreachable,
        }
    } else {
        var i: usize = 0;
        if (use_vectors and !@inComptime()) {
            if (std.simd.suggestVectorLength(CHILD)) |SIMD_SIZE| {
                if (SIMD_SIZE <= len) {
                    const SIMD_END = len - (SIMD_SIZE - 1);
                    while (i < SIMD_END) : (i += SIMD_SIZE) {
                        const dest_chunk = dest[i .. i + SIMD_SIZE];
                        const src_chunk = source[len - i - SIMD_SIZE .. len - i];
                        const src_reversed: [SIMD_SIZE]CHILD = reverse_vector_slice(SIMD_SIZE, CHILD, src_chunk);
                        @memcpy(dest_chunk, &src_reversed);
                    }
                }
            }
        }
        while (true) {
            const next_i = i + NON_SIMD_UNROLL_LEN;
            if (next_i > len) break;
            inline for (0..NON_SIMD_UNROLL_LEN) |ii| {
                const iii = i + ii;
                dest[iii] = source[last - iii];
            }
            i = next_i;
        }
        while (i < len) : (i += 1) {
            dest[i] = source[last - i];
        }
    }
}

pub fn memcopy_from_reader_while_reversing_order(dest: anytype, source: *std.Io.Reader) std.Io.Reader.Error!void {
    const DST = @TypeOf(dest);
    const DST_INFO = KindInfo.get_kind_info(DST);
    assert_with_reason(DST_INFO.has_indexable_child_type(u8), @src(), "type of `dest` `{s}` must have an indexable child type of `u8`", .{@typeName(DST)});
    assert_with_reason(DST_INFO.is_pointer() and DST_INFO.POINTER.is_const == false, @src(), "`dest` must be a pointer type that can be indexed, and must not be const, got invalid dest `{s}`", .{@typeName(DST)});
    assert_with_reason(DST_INFO.has_len(), @src(), "`dest` must have a defined `len` (either be an array, vector, or slice)", .{});
    const len = DST_INFO.get_len(dest);
    const last = len - 1;
    var i: usize = 0;
    var byte: [1]u8 = undefined;
    while (i < len) : (i += 1) {
        try source.readSliceAll(byte[0..1]);
        dest[last - i] = byte[0];
    }
}

pub fn memcopy_to_writer_while_reversing_order(dest: *std.Io.Writer, source: anytype) std.Io.Writer.Error!void {
    const SRC = @TypeOf(source);
    const SRC_INFO = KindInfo.get_kind_info(SRC);
    assert_with_reason(SRC_INFO.has_indexable_child_type(u8), @src(), "type of `source` `{s}` must have an indexable child type of `u8`", .{@typeName(SRC)});
    assert_with_reason(SRC_INFO.is_pointer(), @src(), "`source` must be a pointer type that can be indexed, got invalid source `{s}`", .{@typeName(SRC)});
    assert_with_reason(SRC_INFO.has_len(), @src(), "`source` must have a defined `len` (either be an array, vector, or slice)", .{});
    const len = SRC_INFO.get_len(source);
    const last = len - 1;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        try dest.writeByte(source[last - i]);
    }
}

pub fn copy_arbitrary_length_bytes_in_native_endian_to_typed_pointer(comptime DEST_T: type, noalias dest: *DEST_T, noalias source: []const u8) void {
    const DEST_LEN = @sizeOf(DEST_T);
    assert_with_reason(source.len <= DEST_LEN, @src(), "source bytes (len {d}) are larger than dest pointer child size ({d})", .{ source.len, DEST_LEN });
    const dest_bytes: [*]u8 = @ptrCast(dest);
    const len_diff = DEST_LEN - source.len;
    const copy_start = if (Endian.native_is_little_endian()) 0 else len_diff;
    const copy_end = if (Endian.native_is_little_endian()) source.len else DEST_LEN;
    const zero_start = if (Endian.native_is_little_endian()) source.len else 0;
    const zero_end = if (Endian.native_is_little_endian()) DEST_LEN else len_diff;
    @memset(dest_bytes[zero_start..zero_end], 0);
    @memcpy(dest_bytes[copy_start..copy_end], source);
}
