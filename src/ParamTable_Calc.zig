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
const List = Root.IList_List.List;
const Range = Root.IList.Range;

const Meta = @import("./ParamTable_Meta.zig");
const PTable = Root.ParamTable;

pub const MetaCalc = struct {
    calc_id: Meta.CalcID,
    
};

pub const CalcInterface = struct {
    table: *PTable.Table,
    inputs: []Meta.ParamId,
    outputs: []Meta.ParamId,

    pub fn get_inputs(self: *CalcInterface, comptime IN_STRUCT: type) IN_STRUCT {
        const INFO = @typeInfo(IN_STRUCT);
        Assert.assert_with_reason(Types.type_is_struct(IN_STRUCT), @src(), "type `IN_STRUCT` must be a struct type, got `{s}`", .{@typeName(IN_STRUCT)});
        const STRUCT = INFO.@"struct";
        Assert.assert_with_reason(STRUCT.fields.len == self.inputs.len, @src(), reason_fmt: []const u8, reason_args: anytype)
        for (STRUCT.fields, self.inputs) |f, i| {

        }
    }
};
