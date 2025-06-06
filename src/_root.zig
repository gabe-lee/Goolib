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
const build = @import("builtin");

pub const VERSION = "0.2.0";
pub const NAME = "Goolib";

pub const AABB2 = @import("./AABB2.zig");
pub const ANSI = @import("./ANSI.zig");
pub const Assert = @import("./Assert.zig");
pub const BinarySearch = @import("./BinarySearch.zig");
pub const BucketAllocator = @import("./BucketAllocator.zig");
pub const Bytes = @import("./Bytes.zig");
pub const C_Allocator = @import("./C_Allocator.zig");
pub const Cast = @import("./Cast.zig");
// pub const Codegen = @import("./Codegen.zig");
pub const Color = @import("./Color.zig");
pub const CommonTypes = @import("./CommonTypes.zig");
pub const Composition = @import("./Composition.zig");
// pub const Compare = @import("./Compare.zig");
pub const DummyAllocator = @import("./DummyAllocator.zig");
pub const EnumMap = @import("./EnumMap.zig");
pub const Filegen = @import("./Filegen.zig");
pub const Flags = @import("./Flags.zig");
pub const FlexSlice = @import("./FlexSlice.zig");
// pub const Format = @import("./Format.zig");
pub const GenId = @import("./GenId.zig");
pub const InsertionSort = @import("./InsertionSort.zig");
pub const Iterator = @import("./Iterator.zig");
pub const Layout = @import("./Layout.zig");
pub const LinkedList = @import("./LinkedList.zig");
pub const List = @import("./List.zig");
pub const Math = @import("./Math.zig");
pub const Quicksort = @import("./Quicksort.zig");
pub const Reader = @import("./Reader.zig");
pub const Rect2 = @import("./Rect2.zig");
pub const SDL3 = @import("./SDL3.zig");
// pub const StaticAllocVectorizedStructOfArrays = @import("./StaticAllocVectorizedStructOfArrays.zig");
// pub const Template = @import("./Template.zig");
pub const Time = @import("./Time.zig");
pub const Types = @import("./Types.zig");
pub const Utils = @import("./Utils.zig");
pub const Vec2 = @import("./Vec2.zig");
pub const Writer = @import("./Writer.zig");
// pub const Graphics = @import("./Graphics.zig");

comptime {
    if (build.mode == .Debug) {
        _ = @import("./AABB2.zig");
        _ = @import("./ANSI.zig");
        _ = @import("./Assert.zig");
        _ = @import("./BinarySearch.zig");
        _ = @import("./BucketAllocator.zig");
        _ = @import("./Bytes.zig");
        _ = @import("./C_Allocator.zig");
        _ = @import("./Cast.zig");
        // _ = @import("./Codegen.zig");
        _ = @import("./Color.zig");
        _ = @import("./CommonTypes.zig");
        _ = @import("./Composition.zig");
        // _ = @import("./Compare.zig");
        _ = @import("./DummyAllocator.zig");
        _ = @import("./EnumMap.zig");
        _ = @import("./Filegen.zig");
        _ = @import("./Flags.zig");
        _ = @import("./FlexSlice.zig");
        // _ = @import("./Format.zig");
        _ = @import("./GenId.zig");
        _ = @import("./InsertionSort.zig");
        _ = @import("./Iterator.zig");
        _ = @import("./Layout.zig");
        _ = @import("./LinkedList.zig");
        _ = @import("./List.zig");
        _ = @import("./Math.zig");
        _ = @import("./Quicksort.zig");
        _ = @import("./Reader.zig");
        _ = @import("./Rect2.zig");
        _ = @import("./SDL3.zig");
        // _ = @import("./StaticAllocVectorizedStructOfArrays.zig");
        // _ = @import("./Template.zig");
        _ = @import("./Time.zig");
        _ = @import("./Types.zig");
        _ = @import("./Utils.zig");
        _ = @import("./Vec2.zig");
        _ = @import("./Writer.zig");
    }
}
