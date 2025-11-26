//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
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
const math = std.math;
const Root = @import("./_root.zig");
const SliceAdapter = Root.IList_SliceAdapter;
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Allocator = std.mem.Allocator;
const AllocInfal = Root.AllocatorInfallible;
const DummyAllocator = Root.DummyAllocator;
const Flags = Root.Flags;
const IList = Root.IList.IList;
const Range = Root.IList.Range;

const Meta = @import("./ParamTable_Meta.zig");
const _List = @import("./ParamTable_List.zig");
const PTList = _List.PTList;
const PTPtr = _List.PTPtr;
const ParamTable = Root.ParamTable;
const Table = ParamTable.Table;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub const MetaCalc = struct {
    calc_id: Meta.CalcID,
};

pub const ParamCalc = fn (CalcInterface) void;

fn assert_field_is_type(comptime field: std.builtin.Type.StructField, comptime T: type) void {
    assert_with_reason(field.type == T, @src(), "field `{s}` was type `{s}`, but needed to be type `{s}`", .{ field.name, @typeName(field.type), @typeName(T) });
}

const ListOrPtr = enum(u8) {
    list,
    ptr,
};

fn assert_type_ptptr_or_ptlist_and_get_base_type(comptime field: std.builtin.Type.StructField, comptime mode: ListOrPtr) type {
    assert_with_reason(Types.type_has_decl_with_type(field.type, "TYPE", type), @src(), "field `{s}` was not a `PTPtr(T)` or `PTList(T)` type (missing `pub const TYPE = T;`), got type `{s}`", .{ field.name, @typeName(field.type) });
    const T = field.type.TYPE;
    switch (mode) {
        .list => {
            const TT = PTList(T);
            assert_field_is_type(field, TT);
            return T;
        },
        .ptr => {
            const TT = PTPtr(T);
            assert_field_is_type(field, TT);
            return T;
        },
    }
}

fn assert_field_is_any_type(comptime field: std.builtin.Type.StructField, comptime Ts: []const type) void {
    assert_with_reason(Types.type_is_one_of(field.type, Ts), @src(), "field `{s}` was type `{s}`, but needed to be one of the following: {s}", .{ field.name, @typeName(field.type), Types.type_name_list(Ts) });
}

fn assert_meta_is_type(id: Meta.ParamId, meta: Meta.Metadata, comptime t: Meta.ParamType, comptime src: std.builtin.SourceLocation) void {
    assert_with_reason(meta.is_type(t), src, "param_id `{d}` was not a `{s}`, got `{s}`", .{ id.id, t.name(), meta.param_type.name() });
}

pub const CalcInterface = struct {
    table: *ParamTable.Table,
    inputs: []const Meta.ParamId,
    outputs: []const Meta.ParamId,

    fn get_param_object(self: CalcInterface, params: []const Meta.ParamId, comptime OBJECT: type, comptime INFO: std.builtin.Type.Struct) OBJECT {
        var object: OBJECT = undefined;
        inline for (INFO.fields, 0..) |f, i| {
            const p = params[i];
            const metadata = self.table.metadata.get(p.id);
            switch (f.type) {
                u64 => {
                    assert_meta_is_type(p, metadata, .U64, @src());
                    @field(object, f.name) = @bitCast(self.table.list_64.ptr[@intCast(metadata.val_idx)]);
                },
                i64 => {
                    assert_meta_is_type(p, metadata, .I64, @src());
                    @field(object, f.name) = @bitCast(self.table.list_64.ptr[@intCast(metadata.val_idx)]);
                },
                f64 => {
                    assert_meta_is_type(p, metadata, .F64, @src());
                    @field(object, f.name) = @bitCast(self.table.list_64.ptr[@intCast(metadata.val_idx)]);
                },
                u32 => {
                    assert_meta_is_type(p, metadata, .U32, @src());
                    @field(object, f.name) = @bitCast(self.table.list_32.ptr[@intCast(metadata.val_idx)]);
                },
                i32 => {
                    assert_meta_is_type(p, metadata, .I32, @src());
                    @field(object, f.name) = @bitCast(self.table.list_32.ptr[@intCast(metadata.val_idx)]);
                },
                f32 => {
                    assert_meta_is_type(p, metadata, .F32, @src());
                    @field(object, f.name) = @bitCast(self.table.list_32.ptr[@intCast(metadata.val_idx)]);
                },
                u16 => {
                    assert_meta_is_type(p, metadata, .U16, @src());
                    @field(object, f.name) = @bitCast(self.table.list_16.ptr[@intCast(metadata.val_idx)]);
                },
                i16 => {
                    assert_meta_is_type(p, metadata, .I16, @src());
                    @field(object, f.name) = @bitCast(self.table.list_16.ptr[@intCast(metadata.val_idx)]);
                },
                f16 => {
                    assert_meta_is_type(p, metadata, .F16, @src());
                    @field(object, f.name) = @bitCast(self.table.list_16.ptr[@intCast(metadata.val_idx)]);
                },
                u8 => {
                    assert_meta_is_type(p, metadata, .U8, @src());
                    @field(object, f.name) = @bitCast(self.table.list_8.ptr[@intCast(metadata.val_idx)]);
                },
                i8 => {
                    assert_meta_is_type(p, metadata, .I8, @src());
                    @field(object, f.name) = @bitCast(self.table.list_8.ptr[@intCast(metadata.val_idx)]);
                },
                bool => {
                    assert_meta_is_type(p, metadata, .BOOL, @src());
                    @field(object, f.name) = @bitCast(self.table.list_8.ptr[@intCast(metadata.val_idx)]);
                },
                else => {
                    const T = assert_type_ptptr_or_ptlist_and_get_base_type(f, .ptr);
                    const PTP = PTPtr(T);
                    const PTL = PTList(T);
                    switch (f.type) {
                        PTP => {
                            @field(object, f.name) = PTP.from_opaque(self.table.list_ptr.ptr[@intCast(metadata.val_idx)]);
                        },
                        PTL => {
                            @field(object, f.name) = PTL.from_opaque(self.table.list_list.ptr[@intCast(metadata.val_idx)], self.table);
                        },
                        else => assert_unreachable(@src(), "ALL fields in ParamTable calculation input object must be one of the following types:\nbool, u8, i8, u16, i16, f16, u32, i32, f32, u64, i64, f64, PTPtr(T), or PTList(T)\ngot type {s}", .{@typeName(f.type)}),
                    }
                },
            }
        }
        return object;
    }
    fn get_uninit_param_object(self: CalcInterface, params: []const Meta.ParamId, comptime OBJECT: type, comptime INFO: std.builtin.Type.Struct) OBJECT {
        const object: OBJECT = undefined;
        inline for (INFO.fields, 0..) |f, i| {
            const p = params[i];
            const metadata = self.table.metadata.get(p.id);
            switch (f.type) {
                u64 => {
                    assert_meta_is_type(p, metadata, .U64, @src());
                },
                i64 => {
                    assert_meta_is_type(p, metadata, .I64, @src());
                },
                f64 => {
                    assert_meta_is_type(p, metadata, .F64, @src());
                },
                u32 => {
                    assert_meta_is_type(p, metadata, .U32, @src());
                },
                i32 => {
                    assert_meta_is_type(p, metadata, .I32, @src());
                },
                f32 => {
                    assert_meta_is_type(p, metadata, .F32, @src());
                },
                u16 => {
                    assert_meta_is_type(p, metadata, .U16, @src());
                },
                i16 => {
                    assert_meta_is_type(p, metadata, .I16, @src());
                },
                f16 => {
                    assert_meta_is_type(p, metadata, .F16, @src());
                },
                u8 => {
                    assert_meta_is_type(p, metadata, .U8, @src());
                },
                i8 => {
                    assert_meta_is_type(p, metadata, .I8, @src());
                },
                bool => {
                    assert_meta_is_type(p, metadata, .BOOL, @src());
                },
                else => {
                    const T = assert_type_ptptr_or_ptlist_and_get_base_type(f, .ptr);
                    const PTP = PTPtr(T);
                    const PTL = PTList(T);
                    switch (f.type) {
                        PTP => {
                            assert_meta_is_type(p, metadata, .PTR, @src());
                        },
                        PTL => {
                            assert_meta_is_type(p, metadata, .LIST, @src());
                        },
                        else => assert_unreachable(@src(), "ALL fields in ParamTable calculation input object must be one of the following types:\nbool, u8, i8, u16, i16, f16, u32, i32, f32, u64, i64, f64, PTPtr(T), or PTList(T)\ngot type {s}", .{@typeName(f.type)}),
                    }
                },
            }
        }
        return object;
    }

    pub fn get_inputs(self: CalcInterface, comptime INPUT_OBJECT_TYPE: type) INPUT_OBJECT_TYPE {
        const INFO = @typeInfo(INPUT_OBJECT_TYPE);
        assert_with_reason(Types.type_is_struct(INPUT_OBJECT_TYPE), @src(), "type `INPUT_OBJECT_TYPE` must be a struct type, got `{s}`", .{@typeName(INPUT_OBJECT_TYPE)});
        const STRUCT = INFO.@"struct";
        assert_with_reason(STRUCT.fields.len == self.inputs.len, @src(), "type `INPUT_OBJECT_TYPE` must have exactly the same number of fields as `self.inputs.len`, got fields = {d}, inputs = {d}", .{ STRUCT.fields.len, self.inputs.len });
        return self.get_param_object(self.inputs, INPUT_OBJECT_TYPE, STRUCT);
    }
    pub fn get_outputs_with_current_values(self: CalcInterface, comptime OUTPUT_OBJECT_TYPE: type) OUTPUT_OBJECT_TYPE {
        const INFO = @typeInfo(OUTPUT_OBJECT_TYPE);
        assert_with_reason(Types.type_is_struct(OUTPUT_OBJECT_TYPE), @src(), "type `OUTPUT_OBJECT_TYPE` must be a struct type, got `{s}`", .{@typeName(OUTPUT_OBJECT_TYPE)});
        const STRUCT = INFO.@"struct";
        assert_with_reason(STRUCT.fields.len == self.outputs.len, @src(), "type `OUTPUT_OBJECT_TYPE` must have exactly the same number of fields as `self.outputs.len`, got fields = {d}, inputs = {d}", .{ STRUCT.fields.len, self.inputs.len });
        return self.get_param_object(self.outputs, OUTPUT_OBJECT_TYPE, STRUCT);
    }
    pub fn get_outputs_uninit(self: CalcInterface, comptime OUTPUT_OBJECT_TYPE: type) OUTPUT_OBJECT_TYPE {
        const INFO = @typeInfo(OUTPUT_OBJECT_TYPE);
        assert_with_reason(Types.type_is_struct(OUTPUT_OBJECT_TYPE), @src(), "type `OUTPUT_OBJECT_TYPE` must be a struct type, got `{s}`", .{@typeName(OUTPUT_OBJECT_TYPE)});
        const STRUCT = INFO.@"struct";
        assert_with_reason(STRUCT.fields.len == self.outputs.len, @src(), "type `OUTPUT_OBJECT_TYPE` must have exactly the same number of fields as `self.outputs.len`, got fields = {d}, inputs = {d}", .{ STRUCT.fields.len, self.inputs.len });
        return self.get_uninit_param_object(self.outputs, OUTPUT_OBJECT_TYPE, STRUCT);
    }
    pub fn commit_outputs(self: CalcInterface, output_object: anytype) void {
        const OUTPUT_OBJECT_TYPE = @TypeOf(output_object);
        const INFO = @typeInfo(OUTPUT_OBJECT_TYPE);
        assert_with_reason(Types.type_is_struct(OUTPUT_OBJECT_TYPE), @src(), "type `OUTPUT_OBJECT_TYPE` must be a struct type, got `{s}`", .{@typeName(OUTPUT_OBJECT_TYPE)});
        const STRUCT = INFO.@"struct";
        assert_with_reason(STRUCT.fields.len == self.outputs.len, @src(), "type `OUTPUT_OBJECT_TYPE` must have exactly the same number of fields as `self.outputs.len`, got fields = {d}, inputs = {d}", .{ STRUCT.fields.len, self.inputs.len });
        inline for (STRUCT.fields, 0..) |f, i| {
            const p = self.outputs[i];
            const metadata = self.table.metadata.get(@intCast(p.id));
            switch (f.type) {
                u64 => {
                    assert_meta_is_type(p, metadata, .U64, @src());
                },
                i64 => {
                    assert_meta_is_type(p, metadata, .I64, @src());
                },
                f64 => {
                    assert_meta_is_type(p, metadata, .F64, @src());
                },
                u32 => {
                    assert_meta_is_type(p, metadata, .U32, @src());
                },
                i32 => {
                    assert_meta_is_type(p, metadata, .I32, @src());
                },
                f32 => {
                    assert_meta_is_type(p, metadata, .F32, @src());
                },
                u16 => {
                    assert_meta_is_type(p, metadata, .U16, @src());
                },
                i16 => {
                    assert_meta_is_type(p, metadata, .I16, @src());
                },
                f16 => {
                    assert_meta_is_type(p, metadata, .F16, @src());
                },
                u8 => {
                    assert_meta_is_type(p, metadata, .U8, @src());
                },
                i8 => {
                    assert_meta_is_type(p, metadata, .I8, @src());
                },
                bool => {
                    assert_meta_is_type(p, metadata, .BOOL, @src());
                },
                else => {
                    const T = assert_type_ptptr_or_ptlist_and_get_base_type(f, .ptr);
                    const PTP = PTPtr(T);
                    const PTL = PTList(T);
                    switch (f.type) {
                        PTP => {
                            assert_meta_is_type(p, metadata, .PTR, @src());
                        },
                        PTL => {
                            assert_meta_is_type(p, metadata, .LIST, @src());
                        },
                        else => assert_unreachable(@src(), "ALL fields in ParamTable calculation input object must be one of the following types:\nbool, u8, i8, u16, i16, f16, u32, i32, f32, u64, i64, f64, PTPtr(T), or PTList(T)\ngot type {s}", .{@typeName(f.type)}),
                    }
                },
            }
            Table.Internal._set_meta(self.table, p, metadata, f.type, @field(output_object, f.name), .must_be_init, .can_be_derived, .cannot_be_root);
        }
    }
};
