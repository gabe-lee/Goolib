//! This is a no/low cost wrapper around `std.mem.Allocator` that provides
//! allocation methods for which failure is asserted to never occur (panics in `Debug` and `ReleaseSafe`,
//! undefined behavior otherwise)
//!
//! Resize and remap methods are still allowed to fail
//!
//! This places the responsibility of either finding an alternate
//! source of memory (likely via a fallback allocator) or logging the
//! error and terminating the process on the *Allocator implementation*
//! rather than the user. It is a trade-off between greater user control
//! over error handling and simplification of user code.
//!
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
const mem = std.mem;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const Alignment = std.mem.Alignment;
const AllocatorInfal = @This();

const Root = @import("./_root.zig");
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;
const DummyAlloc = Root.DummyAllocator;

pub const Log2Align = math.Log2Int(usize);

allocator: Allocator,

pub inline fn from(allocator: Allocator) AllocatorInfal {
    return AllocatorInfal{ .allocator = allocator };
}

pub inline fn raw_alloc(self: AllocatorInfal, len: usize, alignment: Alignment, ret_addr: usize) [*]u8 {
    const alloc_result = self.allocator.rawAlloc(len, alignment, ret_addr);
    assert_with_reason(alloc_result != null, @src(), "Allocator.rawAlloc(allocator: {any}, len = {d}, alignment = {d}, ret_addr = {x}) failed", .{ self.allocator, len, @intFromEnum(alignment), ret_addr });
    return alloc_result.?;
}

pub inline fn raw_resize(self: AllocatorInfal, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) bool {
    return self.allocator.rawResize(memory, alignment, new_len, ret_addr);
}

pub inline fn raw_remap(self: AllocatorInfal, memory: []u8, alignment: Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    return self.allocator.rawRemap(memory, alignment, new_len, ret_addr);
}

pub inline fn raw_free(self: AllocatorInfal, memory: []u8, alignment: Alignment, ret_addr: usize) void {
    return self.allocator.rawFree(memory, alignment, ret_addr);
}

/// Returns a pointer to undefined memory.
/// Call `destroy` with the result to free the memory.
pub inline fn create(self: AllocatorInfal, comptime T: type) *T {
    const alloc_result = self.allocator.create(T);
    assert_with_reason(alloc_result != null, @src(), "Allocator.create({s}) failed", .{@typeName(T)});
    return alloc_result.?;
}

/// `ptr` should be the return value of `create`, or otherwise
/// have the same address and alignment property.
pub inline fn destroy(self: AllocatorInfal, ptr: anytype) void {
    return self.allocator.destroy(ptr);
}

/// Allocates an array of `n` items of type `T` and sets all the
/// items to `undefined`. Depending on the Allocator
/// implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub inline fn alloc(self: AllocatorInfal, comptime T: type, n: usize) []T {
    const alloc_result = self.allocator.alloc(T, n);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.alloc(allocator: {any}, T = {s}, n = {d}) failed: {s}", .{ self.allocator, @typeName(T), n, @errorName(err) });
}

pub inline fn alloc_align_sentinel(self: AllocatorInfal, comptime T: type, n: usize, comptime optional_alignment: u29, comptime optional_sentinel: T) Allocator.AllocWithOptionsPayload(T, optional_alignment, optional_sentinel) {
    const alloc_result = self.allocator.allocWithOptions(T, n, optional_alignment, optional_sentinel);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.allocWithOptions(allocator: {any}, T = {s}, n = {d}, optional_alignment = {?d}, optional_sentinel = {?d}) failed: {s}", .{ self.allocator, @typeName(T), n, optional_alignment, optional_sentinel, @errorName(err) });
}

pub inline fn alloc_align_sentinel_retaddr(self: AllocatorInfal, comptime T: type, n: usize, comptime optional_alignment: u29, comptime optional_sentinel: T, return_address: usize) Allocator.AllocWithOptionsPayload(T, optional_alignment, optional_sentinel) {
    const alloc_result = self.allocator.allocWithOptionsRetAddr(T, n, optional_alignment, optional_sentinel, return_address);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.allocWithOptionsRetAddr(allocator: {any}, T = {s}, n = {d}, optional_alignment = {?d}, optional_sentinel = {?any}, return_address = {x}) failed: {s}", .{ self.allocator, @typeName(T), n, optional_alignment, optional_sentinel, return_address, @errorName(err) });
}

/// Allocates an array of `n + 1` items of type `T` and sets the first `n`
/// items to `undefined` and the last item to `sentinel`. Depending on the
/// Allocator implementation, it may be required to call `free` once the
/// memory is no longer needed, to avoid a resource leak. If the
/// `Allocator` implementation is unknown, then correct code will
/// call `free` when done.
///
/// For allocating a single item, see `create`.
pub inline fn alloc_sentinel(self: AllocatorInfal, comptime T: type, n: usize, comptime sentinel: T) [:sentinel]T {
    const alloc_result = self.allocator.allocSentinel(T, n, sentinel);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.allocSentinel(allocator: {any}, T = {s}, n = {d}, optional_sentinel = {any}) failed: {s}", .{ self.allocator, @typeName(T), n, sentinel, @errorName(err) });
}

pub inline fn alloc_sentinel_retaddr(self: AllocatorInfal, comptime T: type, n: usize, comptime sentinel: T, return_address: usize) [:sentinel]T {
    const alloc_result = self.allocator.allocWithOptionsRetAddr(T, n, null, sentinel, return_address);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.allocWithOptionsRetAddr(allocator: {any}, T = {s}, n = {d}, alignment = null, sentinel = {any}, return_address = {x}) failed: {s}", .{ self.allocator, @typeName(T), n, sentinel, return_address, @errorName(err) });
}

pub inline fn alloc_align(self: AllocatorInfal, comptime T: type, n: usize, comptime alignment: u29) []align(alignment orelse @alignOf(T)) T {
    const alloc_result = self.allocator.alignedAlloc(T, alignment, n);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.alignedAlloc(allocator: {any}, T = {s}, alignment = {?d}, n = {d}) failed: {s}", .{ self.allocator, @typeName(T), alignment, n, @errorName(err) });
}

pub inline fn alloc_align_retaddr(self: AllocatorInfal, comptime T: type, n: usize, comptime alignment: u29, return_address: usize) []align(alignment orelse @alignOf(T)) T {
    const alloc_result = self.allocator.allocAdvancedWithRetAddr(T, alignment, n, return_address);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.allocAdvancedWithRetAddr(allocator: {any}, T = {s}, alignment = {?d}, n = {d}, return_address = {x}) failed: {s}", .{ self.allocator, @typeName(T), alignment, n, return_address, @errorName(err) });
}

/// Request to modify the size of an allocation.
///
/// It is guaranteed to not move the pointer, however the allocator
/// implementation may refuse the resize request by returning `false`.
///
/// `allocation` may be an empty slice, in which case a new allocation is made.
///
/// `new_len` may be zero, in which case the allocation is freed.
pub inline fn resize(self: AllocatorInfal, allocation: anytype, new_len: usize) bool {
    return self.allocator.resize(allocation, new_len);
}

/// Request to modify the size of an allocation, allowing relocation.
///
/// A non-`null` return value indicates the resize was successful. The
/// allocation may have same address, or may have been relocated. In either
/// case, the allocation now has size of `new_len`. A `null` return value
/// indicates that the resize would be equivalent to allocating new memory,
/// copying the bytes from the old memory, and then freeing the old memory.
/// In such case, it is more efficient for the caller to perform those
/// operations.
///
/// `allocation` may be an empty slice, in which case a new allocation is made.
///
/// `new_len` may be zero, in which case the allocation is freed.
pub inline fn remap(self: AllocatorInfal, allocation: anytype, new_len: usize) t: {
    const Slice = @typeInfo(@TypeOf(allocation)).pointer;
    break :t ?[]align(Slice.alignment) Slice.child;
} {
    return self.allocator.remap(allocation, new_len);
}

/// This function requests a new byte size for an existing allocation, which
/// can be larger, smaller, or the same size as the old memory allocation.
///
/// If `new_n` is 0, this is the same as `free` and it always succeeds.
///
/// `old_mem` may have length zero, which makes a new allocation.
///
/// This function only fails on out-of-memory conditions, unlike:
/// * `remap` which returns `null` when the `Allocator` implementation cannot
///   do the realloc more efficiently than the caller
/// * `resize` which returns `false` when the `Allocator` implementation cannot
///   change the size without relocating the allocation.
pub fn realloc(self: AllocatorInfal, old_mem: anytype, new_n: usize) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    break :t []align(Slice.alignment) Slice.child;
} {
    return self.realloc_retaddr(old_mem, new_n, @returnAddress());
}

pub fn realloc_retaddr(
    self: AllocatorInfal,
    old_mem: anytype,
    new_n: usize,
    return_address: usize,
) t: {
    const Slice = @typeInfo(@TypeOf(old_mem)).pointer;
    break :t []align(Slice.alignment) Slice.child;
} {
    const alloc_result = self.allocator.reallocAdvanced(old_mem, new_n, return_address);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.reallocAdvanced(allocator: {any}, old_mem = {*}, new_n = {d}, return_address = {x}) failed: {s}", .{ self.allocator, old_mem, new_n, return_address, @errorName(err) });
}

/// Free an array allocated with `alloc`.
/// If memory has length 0, free is a no-op.
/// To free a single item, see `destroy`.
pub fn free(self: AllocatorInfal, memory: anytype) void {
    return self.allocator.free(memory);
}

/// Copies slice to newly allocated memory. Caller owns the memory.
pub fn clone(self: AllocatorInfal, comptime T: type, this_mem: []const T) []T {
    const alloc_result = self.allocator.dupe(T, this_mem);
    return alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.dupe(allocator: {any}, T = {s}, m = {any}) failed: {s}", .{ self.allocator, @typeName(T), this_mem, @errorName(err) });
}

/// Copies slice to newly allocated memory with provided sentinel. Caller owns the memory.
pub fn clone_sentinel(self: AllocatorInfal, comptime T: type, this_mem: []const T, comptime sentinel: T) [:sentinel]T {
    const alloc_result = self.allocator.alloc(T, this_mem.len + 1);
    const new_m = alloc_result catch |err| assert_with_reason(false, @src(), "Allocator.alloc(allocator: {any}, T = {s}, n = {d}) failed: {s}", .{ self.allocator, @typeName(T), this_mem.len + 1, @errorName(err) });
    @memcpy(new_m[0..this_mem.len], this_mem);
    new_m[this_mem.len] = sentinel;
    return new_m[0..this_mem.len :sentinel];
}

pub const DummyAllocInfal = AllocatorInfal{
    .allocator = DummyAlloc.allocator,
};
