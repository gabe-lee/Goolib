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
const Io = std.Io;
const Writer = std.Io.Writer;
const Utils = Root.Utils;
const math = std.math;
const fmt = std.fmt;
const Random = std.Random;
// const pq = std.PriorityQueue;

const Root = @import("./_root.zig");
const object_equals = Root.Utils.Compare.shallow_equals;
const Assert = Root.Assert;
const Types = Root.Types;
const Test = Root.Testing;
const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const ptr_cast = Root.Cast.ptr_cast;
const num_cast = Root.Cast.num_cast;
const Endian = Root.CommonTypes.Endian;
const Math = Root.Math;
const Common = Root.CommonTypes;
const Recipes = Utils.DataManipulation.Recipes;

const DataManipulationCore = Utils.DataManipulation.DataManipulationCore;

pub fn core_for_any_data_structure_with_contiguous_memory_not_allocated(comptime DATA: type, comptime INDEX: type, comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = DATA,
        .ELEM = ELEM,
        .ID = INDEX,
        .COUNT_INT = INDEX,
        .USERDATA = void,
    };
}

pub fn core_for_any_data_structure_with_contiguous_memory_allocated(comptime DATA: type, comptime INDEX: type, comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = DATA,
        .ELEM = ELEM,
        .ID = INDEX,
        .COUNT_INT = INDEX,
        .USERDATA = struct {
            alloc: Allocator = Root.DummyAllocator.allocator_panic_free_noop,
            alloc_settings: Utils.Alloc.SmartAllocSettings(ELEM) = .{},
            alloc_comptime_settings: Utils.Alloc.SmartAllocComptimeSettings(ELEM) = .{},
        },
    };
}

pub fn core_for_slice_not_allocated(comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = []ELEM,
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = void,
    };
}

pub fn core_for_slice_allocated(comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = []ELEM,
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = struct {
            alloc: Allocator = Root.DummyAllocator.allocator_panic_free_noop,
            alloc_settings: Utils.Alloc.SmartAllocSettings(ELEM) = .{},
            alloc_comptime_settings: Utils.Alloc.SmartAllocComptimeSettings(ELEM) = .{},
            io: std.Io,
        },
    };
}

pub fn core_for_const_slice(comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = []const ELEM,
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = void,
    };
}

pub fn core_for_arraylist_allocated(comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = std.ArrayList(ELEM),
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = struct {
            alloc: Allocator = Root.DummyAllocator.allocator_panic_free_noop,
            alloc_settings: Utils.Alloc.SmartAllocSettings(ELEM) = .{},
            alloc_comptime_settings: Utils.Alloc.SmartAllocComptimeSettings(ELEM) = .{},
        },
    };
}

pub fn core_for_arraylist_not_allocated(comptime ELEM: type) DataManipulationCore {
    return DataManipulationCore{
        .DATA = std.ArrayList(ELEM),
        .ELEM = ELEM,
        .ID = usize,
        .COUNT_INT = usize,
        .USERDATA = void,
    };
}

pub fn default_functions_for_slice_not_allocated(comptime ELEM: type) core_for_slice_not_allocated(ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_slice_not_allocated(ELEM);
    const PROTO = struct {
        fn get_base_ptr(data: CORE.DATA, _: CORE.USERDATA) [*]ELEM {
            return data.ptr;
        }
        fn set_base_ptr(data_: CORE.DATA, ptr: [*]ELEM, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.ptr = ptr;
            return data;
        }
        fn get_slice(data: CORE.DATA, first: usize, last: usize, _: CORE.USERDATA) []ELEM {
            return data.ptr[first .. last + 1];
        }
        fn get_len(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_len(data_: CORE.DATA, new_len: usize, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.len = new_len;
            return data;
        }
        fn get_cap(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_cap(data_: CORE.DATA, new_len: usize, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.len = new_len;
            return data;
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_PTR = PROTO.get_base_ptr,
        .SET_BASE_PTR = PROTO.set_base_ptr,
        .GET_RANGE_SLICE = PROTO.get_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_arraylist_not_allocated(comptime ELEM: type) core_for_arraylist_not_allocated(ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_arraylist_not_allocated(ELEM);
    const PROTO = struct {
        fn get_base_ptr(data: CORE.DATA, _: CORE.USERDATA) [*]ELEM {
            return data.items.ptr;
        }
        fn set_base_ptr(data_: CORE.DATA, ptr: [*]ELEM, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.items.ptr = ptr;
            return data;
        }
        fn get_slice(data: CORE.DATA, first: usize, last: usize, _: CORE.USERDATA) []ELEM {
            return data.items.ptr[first .. last + 1];
        }
        fn get_len(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.items.len;
        }
        fn set_len(data_: CORE.DATA, new_len: usize, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.items.len = new_len;
            return data;
        }
        fn get_cap(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.capacity;
        }
        fn set_cap(data_: CORE.DATA, new_cap: usize, _: CORE.USERDATA) CORE.DATA {
            var data = data_;
            data.capacity = new_cap;
            return data;
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_PTR = PROTO.get_base_ptr,
        .SET_BASE_PTR = PROTO.set_base_ptr,
        .GET_RANGE_SLICE = PROTO.get_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_slice_allocated(comptime ELEM: type) core_for_slice_allocated(ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_slice_allocated(ELEM);
    const PROTO = struct {
        fn get_base_ptr(data: CORE.DATA, _: CORE.USERDATA) [*]ELEM {
            return data.ptr;
        }
        fn get_slice(data: CORE.DATA, first: usize, last: usize, _: CORE.USERDATA) []ELEM {
            return data.ptr[first .. last + 1];
        }
        fn get_len(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_len(data_: CORE.DATA, new_len: usize, user: CORE.USERDATA) CORE.DATA {
            var data = data_;
            const alloc = user.alloc;
            const alloc_settings = user.alloc_settings;
            const alloc_comp_settings = user.alloc_comptime_settings;
            data = Utils.Alloc.smart_alloc(alloc, data.ptr, data.len, data.len, new_len, alloc_settings, alloc_comp_settings);
            return data;
        }
        fn get_cap(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_cap(data_: CORE.DATA, new_cap: usize, user: CORE.USERDATA) CORE.DATA {
            var data = data_;
            const alloc = user.alloc;
            const alloc_settings = user.alloc_settings;
            const alloc_comp_settings = user.alloc_comptime_settings;
            data = Utils.Alloc.smart_alloc(alloc, data.ptr, data.len, data.len, new_cap, alloc_settings, alloc_comp_settings);
            return data;
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_PTR = PROTO.get_base_ptr,
        .GET_RANGE_SLICE = PROTO.get_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_arraylist_allocated(comptime ELEM: type) core_for_arraylist_allocated(ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_arraylist_allocated(ELEM);
    const PROTO = struct {
        fn get_base_ptr(data: CORE.DATA, _: CORE.USERDATA) [*]ELEM {
            return data.ptr;
        }
        fn get_slice(data: CORE.DATA, first: usize, last: usize, _: CORE.USERDATA) []ELEM {
            return data.ptr[first .. last + 1];
        }
        fn get_len(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_len(data_: CORE.DATA, new_len: usize, user: CORE.USERDATA) CORE.DATA {
            var data = data_;
            if (new_len > data.capacity) {
                data = set_cap(data, new_len, user);
            }
            data.items.len = new_len;
            return data;
        }
        fn get_cap(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn set_cap(data_: CORE.DATA, new_cap: usize, user: CORE.USERDATA) CORE.DATA {
            var data = data_;
            const alloc = user.alloc;
            const alloc_settings = user.alloc_settings;
            const alloc_comp_settings = user.alloc_comptime_settings;
            const new_slice = Utils.Alloc.smart_alloc(alloc, data.items.ptr, data.items.len, data.capacity, new_cap, alloc_settings, alloc_comp_settings);
            data.capacity = new_slice.len;
            data.items.ptr = new_slice.ptr;
            data.items.len = @min(data.items.len, data.capacity);
            return data;
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_PTR = PROTO.get_base_ptr,
        .GET_RANGE_SLICE = PROTO.get_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_const_slice(comptime ELEM: type) core_for_const_slice(ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_const_slice(ELEM);
    const PROTO = struct {
        fn get_base_const_ptr(data: CORE.DATA, _: CORE.USERDATA) [*]const ELEM {
            return data.ptr;
        }
        fn get_const_slice(data: CORE.DATA, first: usize, last: usize, _: CORE.USERDATA) []const ELEM {
            return data.ptr[first .. last + 1];
        }
        fn get_len(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
        fn get_cap(data: CORE.DATA, _: CORE.USERDATA) usize {
            return data.len;
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_CONST_PTR = PROTO.get_base_const_ptr,
        .GET_RANGE_CONST_SLICE = PROTO.get_const_slice,
        .GET_LEN = PROTO.get_len,
        .GET_CAP = PROTO.get_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_contiguous_mem_allocated(
    comptime DATA: type,
    comptime INDEX: type,
    comptime ELEM: type,
    comptime PTR_FIELD_ACCESS: []const []const u8,
    comptime LEN_FIELD_ACCESS: []const []const u8,
    comptime CAP_FIELD_ACCESS: []const []const u8,
    comptime HAS_CAP: bool,
) core_for_any_data_structure_with_contiguous_memory_allocated(DATA, INDEX, ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_any_data_structure_with_contiguous_memory_allocated(DATA, INDEX, ELEM);
    const PROTO = struct {
        fn field_offset(comptime field_names: []const []const u8, comptime final_field_type: type) usize {
            comptime var off: usize = 0;
            comptime var PARENT: type = DATA;
            next_field: inline for (field_names, 0..) |field_access_name, f| {
                inline for (@typeInfo(PARENT).@"struct".fields) |struct_field| {
                    if (std.mem.eql(u8, struct_field.name, field_access_name)) {
                        off += @offsetOf(PARENT, field_access_name);
                        PARENT = struct_field.type;
                        continue :next_field;
                    }
                }
                assert_unreachable(@src(), "type `{s}` has no field `{s}` (index {d} in field access chain) ", .{ @typeName(PARENT), field_access_name, f });
            }
            assert_with_reason(PARENT == final_field_type, @src(), "the final field type from chain `{s}` -> {any} is not expected type `{s}`, got type `{s}`", .{ @typeName(DATA), field_names, @typeName(final_field_type), @typeName(PARENT) });
            return off;
        }
        inline fn cast_offset_to_field_mutable(data: *DATA, comptime offset: usize, comptime field_type: type) *field_type {
            var opq: [*]u8 = @ptrCast(data);
            opq = opq + offset;
            return @ptrCast(@alignCast(opq));
        }
        inline fn cast_offset_to_field_immutable(data: *const DATA, comptime offset: usize, comptime field_type: type) *const field_type {
            var opq: [*]u8 = @ptrCast(data);
            opq = opq + offset;
            return @ptrCast(@alignCast(opq));
        }
        fn get_base_ptr(data: DATA, _: CORE.USERDATA) [*]ELEM {
            const ptr_offset: usize = comptime field_offset(PTR_FIELD_ACCESS, [*]ELEM);
            const ptr = cast_offset_to_field_immutable(&data, ptr_offset, [*]ELEM);
            return ptr.*;
        }
        fn get_slice(data: DATA, first: INDEX, last: INDEX, user: CORE.USERDATA) []ELEM {
            return get_base_ptr(data, user)[first .. last + 1];
        }
        fn get_len(data: DATA, _: CORE.USERDATA) INDEX {
            const len_offset: usize = comptime field_offset(LEN_FIELD_ACCESS, INDEX);
            const len = cast_offset_to_field_immutable(&data, len_offset, INDEX);
            return len.*;
        }
        fn set_len(data_: DATA, new_len: INDEX, user: CORE.USERDATA) DATA {
            var data = data_;
            if (comptime HAS_CAP) {
                if (new_len > get_cap(data, user)) {
                    data = set_cap(data, new_len, user);
                }
            }
            const len_offset: usize = comptime field_offset(LEN_FIELD_ACCESS, INDEX);
            const len = cast_offset_to_field_mutable(&data, len_offset, INDEX);
            len.* = new_len;
            return data;
        }
        fn get_cap(data: DATA, user: CORE.USERDATA) usize {
            if (comptime HAS_CAP) {
                const cap_offset: usize = comptime field_offset(CAP_FIELD_ACCESS, INDEX);
                const cap = cast_offset_to_field_immutable(&data, cap_offset, INDEX);
                return cap.*;
            } else {
                return get_len(data, user);
            }
        }
        fn set_cap(data_: DATA, new_cap: INDEX, user: CORE.USERDATA) DATA {
            if (comptime HAS_CAP) {
                var data = data_;
                const alloc = user.alloc;
                const alloc_settings = user.alloc_settings;
                const alloc_comp_settings = user.alloc_comptime_settings;
                const new_mem = Utils.Alloc.smart_alloc(alloc, get_base_ptr(data, user), get_len(data, user), get_cap(data, user), new_cap, alloc_settings, alloc_comp_settings);
                const cap_offset: usize = comptime field_offset(CAP_FIELD_ACCESS, INDEX);
                const cap = cast_offset_to_field_mutable(&data, cap_offset, INDEX);
                cap.* = @intCast(new_mem.len);
                const ptr_offset: usize = comptime field_offset(CAP_FIELD_ACCESS, [*]ELEM);
                const ptr = cast_offset_to_field_mutable(&data, ptr_offset, [*]ELEM);
                ptr.* = new_mem.ptr;
                return data;
            } else {
                return set_len(data_, new_cap, user);
            }
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_PTR = PROTO.get_base_ptr,
        .GET_RANGE_SLICE = PROTO.get_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

pub fn default_functions_for_contiguous_mem_not_allocated(
    comptime DATA: type,
    comptime INDEX: type,
    comptime ELEM: type,
    comptime PTR_FIELD_ACCESS: []const []const u8,
    comptime LEN_FIELD_ACCESS: []const []const u8,
    comptime CAP_FIELD_ACCESS: []const []const u8,
    comptime HAS_CAP: bool,
) core_for_any_data_structure_with_contiguous_memory_not_allocated(DATA, INDEX, ELEM).Builder().CustomFunctions_ {
    const CORE = core_for_any_data_structure_with_contiguous_memory_not_allocated(DATA, INDEX, ELEM);
    const PROTO = struct {
        fn field_offset(comptime field_names: []const []const u8, comptime final_field_type: type) usize {
            comptime var off: usize = 0;
            comptime var PARENT: type = DATA;
            next_field: inline for (field_names, 0..) |field_access_name, f| {
                inline for (@typeInfo(PARENT).@"struct".fields) |struct_field| {
                    if (std.mem.eql(u8, struct_field.name, field_access_name)) {
                        off += @offsetOf(PARENT, field_access_name);
                        PARENT = struct_field.type;
                        continue :next_field;
                    }
                }
                assert_unreachable(@src(), "type `{s}` has no field `{s}` (index {d} in field access chain) ", .{ @typeName(PARENT), field_access_name, f });
            }
            assert_with_reason(PARENT == final_field_type, @src(), "the final field type from chain `{s}` -> {any} is not expected type `{s}`, got type `{s}`", .{ @typeName(DATA), field_names, @typeName(final_field_type), @typeName(PARENT) });
            return off;
        }
        inline fn cast_offset_to_field_mutable(data: *DATA, comptime offset: usize, comptime field_type: type) *field_type {
            var opq: [*]u8 = @ptrCast(data);
            opq = opq + offset;
            return @ptrCast(@alignCast(opq));
        }
        inline fn cast_offset_to_field_immutable(data: *const DATA, comptime offset: usize, comptime field_type: type) *const field_type {
            var opq: [*]u8 = @ptrCast(data);
            opq = opq + offset;
            return @ptrCast(@alignCast(opq));
        }
        fn get_base_const_ptr(data: DATA, _: CORE.USERDATA) [*]const ELEM {
            const ptr_offset: usize = comptime field_offset(PTR_FIELD_ACCESS, [*]const ELEM);
            const ptr = cast_offset_to_field_immutable(&data, ptr_offset, [*]const ELEM);
            return ptr.*;
        }
        fn get_const_slice(data: DATA, first: INDEX, last: INDEX, user: CORE.USERDATA) []const ELEM {
            return get_base_const_ptr(data, user)[first .. last + 1];
        }
        fn get_len(data: DATA, _: CORE.USERDATA) INDEX {
            const len_offset: usize = comptime field_offset(LEN_FIELD_ACCESS, INDEX);
            const len = cast_offset_to_field_immutable(&data, len_offset, INDEX);
            return len.*;
        }
        fn set_len(data_: DATA, new_len: INDEX, user: CORE.USERDATA) DATA {
            var data = data_;
            if (comptime HAS_CAP) {
                if (new_len > get_cap(data, user)) {
                    data = set_cap(data, new_len, user);
                }
            }
            const len_offset: usize = comptime field_offset(LEN_FIELD_ACCESS, INDEX);
            const len = cast_offset_to_field_mutable(&data, len_offset, INDEX);
            len.* = new_len;
            return data;
        }
        fn get_cap(data: DATA, user: CORE.USERDATA) INDEX {
            if (comptime HAS_CAP) {
                const cap_offset: usize = comptime field_offset(CAP_FIELD_ACCESS, INDEX);
                const cap = cast_offset_to_field_immutable(&data, cap_offset, INDEX);
                return cap.*;
            } else {
                return get_len(data, user);
            }
        }
        fn set_cap(data_: DATA, new_cap: INDEX, user: CORE.USERDATA) DATA {
            if (comptime HAS_CAP) {
                var data = data_;
                const cap_offset: usize = comptime field_offset(CAP_FIELD_ACCESS, INDEX);
                const cap = cast_offset_to_field_mutable(&data, cap_offset, INDEX);
                cap.* = new_cap;
                return data;
            } else {
                return set_len(data_, new_cap, user);
            }
        }
    };
    const FUNCS = CORE.Builder().CustomFunctions_{
        .GET_BASE_CONST_PTR = PROTO.get_base_const_ptr,
        .GET_RANGE_CONST_SLICE = PROTO.get_const_slice,
        .GET_LEN = PROTO.get_len,
        .SET_LEN = PROTO.set_len,
        .GET_CAP = PROTO.get_cap,
        .SET_CAP = PROTO.set_cap,
    };
    return FUNCS;
}

const EVAL_FOR_SLICE = 20000;
const EVAL_FOR_ARRAYLIST = 11000;
const EVAL_FOR_CONTIGUOUS = 12000;
const NATIVE_PROPS = Recipes.OptionalExtraProperties.classic_indexing;
/// Automatic 'DataManipulationPackage' type for an `[]ELEM` that is not allocated
pub fn slice_not_allocated_package(comptime ELEM: type) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_slice_not_allocated(ELEM).select_functions(EVAL_FOR_SLICE, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_slice_not_allocated(ELEM), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an `[]ELEM` that is allocated from an Allocator
pub fn slice_allocated_package(comptime ELEM: type) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_slice_allocated(ELEM).select_functions(EVAL_FOR_SLICE, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_slice_allocated(ELEM), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an `[]const ELEM`
pub fn const_slice_not_allocated_package(comptime ELEM: type) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_const_slice(ELEM).select_functions(EVAL_FOR_SLICE, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_const_slice(ELEM), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an `std.ArrayList(ELEM)` that is not allocated
pub fn arraylist_not_allocated_package(comptime ELEM: type) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_arraylist_not_allocated(ELEM).select_functions(EVAL_FOR_ARRAYLIST, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_arraylist_not_allocated(ELEM), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an `std.ArrayList(ELEM)` that is allocated from an Allocator
pub fn arraylist_allocated_package(comptime ELEM: type) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_arraylist_allocated(ELEM).select_functions(EVAL_FOR_ARRAYLIST, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_arraylist_allocated(ELEM), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an arbitrary struct type that references memory that is allocated from an Allocator
///
/// Necessary fields are accessed via the specified field names. For example if the object's 'ptr' is located at `my_object.items.ptr`, provide `&.{"items", "ptr"}` as the field access for it
pub fn classically_indexed_mem_with_cap_allocated_package(comptime DATA: type, comptime INDEX: type, comptime ELEM: type, comptime PTR_ACCESS: []const []const u8, comptime LEN_ACCESS: []const []const u8, comptime CAP_ACCESS: []const []const u8) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_any_data_structure_with_contiguous_memory_allocated(DATA, INDEX, ELEM).select_functions(EVAL_FOR_CONTIGUOUS, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_contiguous_mem_allocated(DATA, INDEX, ELEM, PTR_ACCESS, LEN_ACCESS, CAP_ACCESS, true), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an arbitrary struct type that references memory that is allocated from an Allocator
///
/// Necessary fields are accessed via the specified field names. For example if the object's 'ptr' is located at `my_object.items.ptr`, provide `&.{"items", "ptr"}` as the field access for it
pub fn classically_indexed_mem_allocated_package(comptime DATA: type, comptime INDEX: type, comptime ELEM: type, comptime PTR_ACCESS: []const []const u8, comptime LEN_ACCESS: []const []const u8) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_any_data_structure_with_contiguous_memory_allocated(DATA, INDEX, ELEM).select_functions(EVAL_FOR_CONTIGUOUS, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_contiguous_mem_allocated(DATA, INDEX, ELEM, PTR_ACCESS, LEN_ACCESS, &.{}, false), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an arbitrary struct type that references memory that is not allocated
///
/// Necessary fields are accessed via the specified field names. For example if the object's 'ptr' is located at `my_object.items.ptr`, provide `&.{"items", "ptr"}` as the field access for it
pub fn classically_indexed_mem_with_cap_not_allocated_package(comptime DATA: type, comptime INDEX: type, comptime ELEM: type, comptime PTR_ACCESS: []const []const u8, comptime LEN_ACCESS: []const []const u8, comptime CAP_ACCESS: []const []const u8) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_any_data_structure_with_contiguous_memory_not_allocated(DATA, INDEX, ELEM).select_functions(EVAL_FOR_CONTIGUOUS, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_contiguous_mem_not_allocated(DATA, INDEX, ELEM, PTR_ACCESS, LEN_ACCESS, CAP_ACCESS, true), props).finalize();
}

/// Automatic 'DataManipulationPackage' type for an arbitrary struct type that references memory that is not allocated
///
/// Necessary fields are accessed via the specified field names. For example if the object's 'ptr' is located at `my_object.items.ptr`, provide `&.{"items", "ptr"}` as the field access for it
pub fn classically_indexed_mem_not_allocated_package(comptime DATA: type, comptime INDEX: type, comptime ELEM: type, comptime PTR_ACCESS: []const []const u8, comptime LEN_ACCESS: []const []const u8) type {
    const props = if (Types.type_is_numeric(ELEM)) NATIVE_PROPS.and_numeric_element_type() else NATIVE_PROPS;
    return core_for_any_data_structure_with_contiguous_memory_not_allocated(DATA, INDEX, ELEM).select_functions(EVAL_FOR_CONTIGUOUS, .ALLOW_INFERED_IMPLEMENTATIONS, default_functions_for_contiguous_mem_not_allocated(DATA, INDEX, ELEM, PTR_ACCESS, LEN_ACCESS, &.{}, false), props).finalize();
}
