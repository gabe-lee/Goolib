const std = @import("std");

pub const Allocators = struct {
    pub const BucketAllocator = @import("./BucketAllocator.zig");
};
pub const CollectionTypes = struct {
    pub const StaticAllocList = @import("./StaticAllocList.zig");
};
pub const Algorithms = struct {
    pub const Quicksort = @import("./Quicksort.zig");
    pub const BinarySearch = @import("./BinarySearch.zig");
};
pub const Geometry = struct {
    pub const Vec2 = @import("./Vec2.zig");
    pub const AABB2 = @import("./AABB2.zig");
};
pub const IO = struct {
    pub const Writer = @import("./Writer.zig");
    pub const Format = @import("./Format.zig");
};
pub const Generic = struct {
    pub const ReturnWrappers = @import("./ReturnWrappers.zig");
};
pub const Bytes = @import("./Bytes.zig");
pub const Utils = @import("./Utils.zig");
pub const Math = @import("./Math.zig");
pub const CommonTypes = @import("./CommonTypes.zig");

comptime {
    _ = @import("./AABB2.zig");
    _ = @import("./BinarySearch.zig");
    _ = @import("./BucketAllocator.zig");
    _ = @import("./Codegen.zig");
    _ = @import("./CommonTypes.zig");
    _ = @import("./Format.zig");
    _ = @import("./Generic/ReturnWrappers.zig");
    _ = @import("./Math.zig");
    _ = @import("./Quicksort.zig");
    _ = @import("./StaticAllocList.zig");
    _ = @import("./StaticAllocVectorizedStructOfArrays.zig");
    _ = @import("./Utils.zig");
    _ = @import("./Vec2.zig");
    _ = @import("./Writer.zig");
}
