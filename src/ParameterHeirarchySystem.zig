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
const testing = std.testing;
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
const Testing = Root.Testing;
const CompactCoupledAllocationSystem = Root.CompactCoupledAllocationSystem;

const assert_with_reason = Assert.assert_with_reason;
const assert_unreachable = Assert.assert_unreachable;
const assert_allocation_failure = Assert.assert_allocation_failure;

pub fn ParameterHeirarchySystem(
    comptime PHS_IDENTIFIER: []const u8,
    comptime CCAS_DEF: CompactCoupledAllocationSystem.CCAS_Definition,
    comptime _CCAS: type,
) type {
    const __CCAS = CompactCoupledAllocationSystem.CompactCoupledAllocationSystem(CCAS_DEF);
    assert_with_reason(__CCAS == _CCAS, @src(), "type `_CCAS` MUST be exactly the same type as `CompactCoupledAllocationSystem(CCAS_DEF)`, got type {s}", .{@typeName(_CCAS)});
    return struct {
        pub const CCAS = __CCAS;

        const DEFDEF = struct {
            PHS_IDENTIFIER: []const u8,
            CCAS_DEF: CompactCoupledAllocationSystem.CCAS_Definition,
        };

        pub const DEF = DEFDEF{
            .CCAS_DEF = CCAS_DEF,
            .PHS_IDENTIFIER = PHS_IDENTIFIER,
        };
    };
}

test "ccas_equality" {
    const CCAS_DEF = CompactCoupledAllocationSystem.CCAS_Definition{};
    const CCAS_A = CompactCoupledAllocationSystem.CompactCoupledAllocationSystem(CCAS_DEF);
    const PHS = ParameterHeirarchySystem("TEST", CCAS_DEF, CCAS_A);
    const ptr_a = CCAS_A.create_ptr(u8);
    ptr_a.set(42);
    const ptr_b = PHS.CCAS.Ptr(u8){
        .addr = ptr_a.addr,
    };
    const val_b = ptr_b.get();
    try testing.expect(val_b == 42);
    ptr_b.set(99);
    const val_a = ptr_a.get();
    try testing.expect(val_a == 99);
}
