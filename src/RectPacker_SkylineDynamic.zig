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
const math = std.math;

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const MathX = Root.Math;
const ListFull = Root.ListSlice.ListFullDefinition;
const AABB2 = Root.AABB2;
const Rect2 = Root.Rect2;
const Vec2 = Root.Vec2;
const Allocator = std.mem.Allocator;
const DummyAlloc = Root.DummyAllocator;
const HashMapModule = Root.HashMap.SwissTableHashMapModule;
const HashMap = Root.HashMap.SwissTableHashMap;

const assert_with_reason = Assert.assert_with_reason;
const num_cast = Root.Cast.num_cast;

pub fn SkylineDynamicPacker(
    comptime SIZE_T: type,
    comptime HASH_KEY: type,
    comptime HASH_FN: fn (HASH_KEY) u64,
    comptime KEYS_EQUAL: fn (HASH_KEY, HASH_KEY) bool,
    comptime HASH_MAP_OVERRIDES: HashMapModule.Overrides,
) type {
    return struct {
        const Self = @This();
        const Vec = Vec2.define_vec2_type(SIZE_T);
        const Rect = Rect2.define_rect2_type(SIZE_T);
        const AABB = AABB2.define_aabb2_type(SIZE_T);
        const Map = HashMap(HASH_KEY, Rect, HASH_FN, KEYS_EQUAL, HASH_MAP_OVERRIDES);

        region: Rect = .{},
        map: Map = .{},
        alloc: Allocator = DummyAlloc.allocator_panic_free_noop,
    };
}
