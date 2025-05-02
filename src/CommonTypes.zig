const std = @import("std");
const build = @import("builtin");

/// TODO documentation
pub const PointOrientation = enum {
    /// TODO documentation
    COLINEAR,
    /// TODO documentation
    WINDING_CCW,
    /// TODO documentation
    WINDING_CW,
};

/// TODO documentation
pub const AllocErrorBehavior = enum {
    /// TODO documentation
    ALLOCATION_ERRORS_RETURN_ERROR,
    /// TODO documentation
    ALLOCATION_ERRORS_PANIC,
    /// TODO documentation
    ALLOCATION_ERRORS_ARE_UNREACHABLE,
};

/// TODO documentation
pub const GrowthModel = enum {
    /// TODO documentation
    GROW_EXACT_NEEDED,
    /// TODO documentation
    GROW_EXACT_NEEDED_SENTINEL,
    /// TODO documentation
    GROW_EXACT_NEEDED_ATOMIC_PADDING,
    /// TODO documentation
    GROW_EXACT_NEEDED_ATOMIC_PADDING_SENTINEL,
    /// TODO documentation
    GROW_BY_100_PERCENT,
    /// TODO documentation
    GROW_BY_100_PERCENT_SENTINEL,
    /// TODO documentation
    GROW_BY_100_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_100_PERCENT_ATOMIC_PADDING_SENTINEL,
    /// TODO documentation
    GROW_BY_50_PERCENT,
    /// TODO documentation
    GROW_BY_50_PERCENT_SENTINEL,
    /// TODO documentation
    GROW_BY_50_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_50_PERCENT_ATOMIC_PADDING_SENTINEL,
    /// TODO documentation
    GROW_BY_25_PERCENT,
    /// TODO documentation
    GROW_BY_25_PERCENT_SENTINEL,
    /// TODO documentation
    GROW_BY_25_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_25_PERCENT_ATOMIC_PADDING_SENTINEL,
};

/// TODO documentation
pub const SortAlgorithm = enum {
    // BUBBlE_SORT,
    // HEAP_SORT,
    /// TODO documentation
    QUICK_SORT_PIVOT_FIRST,
    /// TODO documentation
    QUICK_SORT_PIVOT_MIDDLE,
    /// TODO documentation
    QUICK_SORT_PIVOT_LAST,
    /// TODO documentation
    QUICK_SORT_PIVOT_RANDOM,
    /// TODO documentation
    QUICK_SORT_PIVOT_MEDIAN_OF_3,
    /// TODO documentation
    QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM,
};

/// TODO documentation
pub const ReadError = error{
    /// TODO documentation
    read_buffer_too_short,
    /// TODO documentation
    destination_too_short_for_given_range,
};

/// TODO documentation
pub const WriteError = error{
    /// TODO documentation
    write_buffer_too_short,
    /// TODO documentation
    source_too_short_for_given_range,
};
