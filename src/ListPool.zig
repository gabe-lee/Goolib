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
const Types = Root.Types;
const Assert = Root.Assert;
const AllocatorInfallible = Root.AllocatorInfallible;
const Allocator = std.mem.Allocator;
const IList = Root.IList;
const Utils = Root.Utils;
const DummyAlloc = Root.DummyAllocator;

const assert_with_reason = Assert.assert_with_reason;

const List = Root.IList_List.List;

// pub fn Pool(comptime T: type, comptime IDX_TYPE: type) type {
//     assert_with_reason(Types.type_is_unsigned_int(IDX_TYPE), @src(), "type `IDX_TYPE` must be an unsigned integer type, got type `{s}`", .{@typeName(IDX_TYPE)});
//     return struct {
//         const Self = @This();

//         list: List(ItemOrNextFree),
//         alloc: Allocator,
//         first_free: IDX_TYPE = math.maxInt(IDX_TYPE),
//         free_count: IDX_TYPE = 0,

//         pub const ItemOrNextFree = union {
//             item: T,
//             next_free: IDX_TYPE,
//         };

//         pub fn init_empty(alloc: Allocator) Self {
//             return Self{
//                 .list = List(T).init_empty(),
//                 .alloc = alloc,
//             };
//         }

//         pub fn init_cap(cap: usize, alloc: Allocator) Self {
//             return Self{
//                 .list = List(T).init_capacity(cap, alloc),
//                 .alloc = alloc,
//             };
//         }

//         pub fn claim(self: *Self) *T {
//             if (self.free_count > 0) {
//                 const first_free_idx = self.first_free;
//                 const next_free_idx = self.list.ptr[first_free_idx].next_free;
//                 self.first_free = next_free_idx;
//                 return self.list.get_ptr(first_free_idx);
//             }
//         }
//     };
// }
