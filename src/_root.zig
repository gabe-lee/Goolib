const std = @import("std");

pub const VERSION = "0.2.0";
pub const NAME = "Goolib";
pub const LOG_PREFIX = "[" ++ NAME ++ " " ++ VERSION ++ "] ";

pub const AABB2 = @import("./AABB2.zig");
pub const ANSI = @import("./ANSI.zig");
pub const BinarySearch = @import("./BinarySearch.zig");
pub const BucketAllocator = @import("./BucketAllocator.zig");
pub const Bytes = @import("./Bytes.zig");
pub const Cast = @import("./Cast.zig");
// pub const Codegen = @import("./Codegen.zig");
pub const Color = @import("./Color.zig");
pub const CommonTypes = @import("./CommonTypes.zig");
// pub const Compare = @import("./Compare.zig");
pub const DummyAllocator = @import("./DummyAllocator.zig");
// pub const Filegen = @import("./Filegen.zig");
// pub const Format = @import("./Format.zig");
pub const InsertionSort = @import("./InsertionSort.zig");
pub const List = @import("./List.zig");
pub const Math = @import("./Math.zig");
pub const Quicksort = @import("./Quicksort.zig");
pub const Reader = @import("./Reader.zig");
pub const Rect2 = @import("./Rect2.zig");
// pub const ReturnWrappers = @import("./ReturnWrappers.zig");
pub const SDL3 = @import("./SDL3.zig");
pub const Slice = @import("./Slice.zig");

// pub const StaticAllocVectorizedStructOfArrays = @import("./StaticAllocVectorizedStructOfArrays.zig");
// pub const Template = @import("./Template.zig");
pub const Utils = @import("./Utils.zig");
pub const Vec2 = @import("./Vec2.zig");
pub const Writer = @import("./Writer.zig");
// pub const Graphics = @import("./Graphics.zig");

comptime {
    _ = @import("./AABB2.zig");
    _ = @import("./ANSI.zig");
    _ = @import("./BinarySearch.zig");
    _ = @import("./BucketAllocator.zig");
    _ = @import("./Bytes.zig");
    _ = @import("./Cast.zig");
    // _ = @import("./Codegen.zig");
    _ = @import("./Color.zig");
    _ = @import("./CommonTypes.zig");
    // _ = @import("./Compare.zig");
    _ = @import("./DummyAllocator.zig");
    // _ = @import("./Filegen.zig");
    // _ = @import("./Format.zig");
    _ = @import("./InsertionSort.zig");
    _ = @import("./List.zig");
    _ = @import("./Math.zig");
    _ = @import("./Quicksort.zig");
    _ = @import("./Reader.zig");
    _ = @import("./Rect2.zig");
    _ = @import("./SDL3.zig");
    _ = @import("./Slice.zig");
    // _ = @import("./ReturnWrappers.zig");

    // _ = @import("./StaticAllocVectorizedStructOfArrays.zig");
    // _ = @import("./Template.zig");
    _ = @import("./Utils.zig");
    _ = @import("./Vec2.zig");
    _ = @import("./Writer.zig");
}
