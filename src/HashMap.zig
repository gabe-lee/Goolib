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

const std = @import("std");
const build = @import("builtin");

/// std imports
const Allocator = std.mem.Allocator;
const DEBUG = std.debug.print;
const math = std.math;

/// Goolib imports
const Root = @import("./_root.zig");
const Cast = Root.Cast;
const Type = Root.Types;
const Math = Root.Math;
const KindInfo = Type.KindInfo;
const Assert = Root.Assert;
const Utils = Root.Utils;
const Common = Root.CommonTypes;
const Test = Root.Testing;
const dummy_alloc = Root.DummyAllocator.allocator_panic_free_noop;
const Random = std.Random;
const Io = std.Io;
const Growth = Common.GrowthModel;
const FuncParamType = Common.FuncParamType;
const ErrorBehavior = Common.ErrorBehavior;
const AllocErr = Utils.Alloc.AllocErr;

const assert_with_reason = Assert.assert_with_reason;
const assert_with_reason_debug_only = Assert.assert_with_reason_debug_only;
const assert_unreachable = Assert.assert_unreachable;
const assert_unreachable_err = Assert.assert_unreachable_err;
const assert_unreachable_err_always_panic = Assert.assert_unreachable_err_always_panic;
const num_cast = Cast.num_cast;
const real_type_of = Type.real_type_of;
const real_type = Type.real_type;
const real_cast = Cast.real_cast;
const kind_info = KindInfo.get_kind_info;

const GLS = Root.ListSlice;
const ListDef = GLS.ListDef;
const ListFullDefinition = GLS.ListFullDefinition;
const QuicksortSettings = GLS.QuicksortSettings;
const AllocMode = GLS.AllocMode;
const GrowthMode = GLS.GrowthMode;
const ReturnMode = GLS.ReturnMode;
const DeleteMode = GLS.DeleteMode;
const DeleteReturnMode = GLS.DeleteReturnMode;
const FilterMode = GLS.FilterMode;
const TrackMaxStackMode = GLS.TrackMaxStackMode;
const Order = GLS.Order;
const TraverserError = GLS.TraverserError;
const FindOneMode = GLS.FindOneMode;
const FieldLayout = GLS.FieldLayout;

pub fn HashMapBackingList(comptime VAL: type, comptime IDX: type, comptime VAL_FIELD_LAYOUT: FieldLayout) type {
    return ListFullDefinition(VAL, IDX, VAL_FIELD_LAYOUT, .SERIAL_INDEXES, .OWNED_ALLOCATED);
}

pub fn SwissHashMap(
    comptime IDX: type,
    comptime KEY: type,
    comptime VAL: type,
    comptime VAL_FIELD_LAYOUT: FieldLayout,
    comptime FUNC_CONTEXT: type,
    comptime HASH: fn (KEY, FUNC_CONTEXT) IDX,
    comptime EQUAL_IDX_VAL: fn (HashMapBackingList(VAL, IDX, VAL_FIELD_LAYOUT), IDX, VAL, FUNC_CONTEXT) bool,
) type {
    return struct {
        const Self = @This();

        list: List = .{},

        const List = HashMapBackingList(VAL, IDX, VAL_FIELD_LAYOUT);
    };
}
