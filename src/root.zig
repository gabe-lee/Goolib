pub const Allocators = struct {
    pub const BucketAllocator = @import("./BucketAllocator.zig");
};
pub const DataStructures = struct {
    pub const StaticAllocList = @import("./StaticAllocList.zig");
};
pub const Algorithms = struct {
    pub const Quicksort = @import("./Quicksort.zig");
    pub const BinarySearch = @import("./BinarySearch.zig");
};
pub const Utils = @import("./Utils.zig");
