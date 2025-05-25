//! //TODO Documentation
//! #### License: Zlib

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
    GROW_EXACT_NEEDED_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_100_PERCENT,
    /// TODO documentation
    GROW_BY_100_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_50_PERCENT,
    /// TODO documentation
    GROW_BY_50_PERCENT_ATOMIC_PADDING,
    /// TODO documentation
    GROW_BY_25_PERCENT,
    /// TODO documentation
    GROW_BY_25_PERCENT_ATOMIC_PADDING,
};

/// TODO documentation
pub const SortAlgorithm = enum {
    // BUBBlE_SORT,
    // HEAP_SORT,
    ///TODO documentation
    INSERTION_SORT,
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

pub const Mutability = enum {
    immutable,
    mutable,
};

pub const LenMutability = enum {
    immutable,
    shrink_only,
    grow_only,
    shrink_or_grow,
};

pub const PosMutability = enum {
    immutable,
    increase_only,
    decrease_only,
    increase_or_decrease,
};
