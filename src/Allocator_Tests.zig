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
const testing = std.testing;
const Root = @import("./_root.zig");
const Buckets = @import("./Allocator_BucketSlabs.zig");
const QuickBucket = @import("./Allocator_QuickBucket.zig");
const AllocMod = Root.Allocator;
const AllocSource = AllocMod.AllocSource;
const PointerModule = Root.Pointer;
const PointerSource = PointerModule.PointerSource;
const PowerOf2 = Root.Math.PowerOf2;
const Allocator = std.mem.Allocator;
const Alignment = std.mem.Alignment;
const Test = Root.Testing;

/// One bucket for every power-of-two block size from 8 bytes through 4 KiB.
/// The power-of-two range must be contiguous because bucket indexes are derived
/// from the log2 of the requested size.
const TEST_BUCKETS = [_]Buckets.BucketDef{
    .{ .BUCKET_SIZE = ._8, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._16, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._32, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._64, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._128, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._256, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._512, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._1_024, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._2_048, .SLAB_SIZE = ._4_096 },
    .{ .BUCKET_SIZE = ._4_096, .SLAB_SIZE = ._4_096 },
};

/// Exactly one block fits in each slab. This exercises the `leftover == 0`
/// path, where the "next untouched block" pointer must not be left dangling.
const ONE_BLOCK_PER_SLAB_BUCKETS = [_]Buckets.BucketDef{
    .{ .BUCKET_SIZE = ._4_096, .SLAB_SIZE = ._4_096 },
};

const TestAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
});

const GrowOnlyAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
    .ALLOW_RESIZE_IN_PLACE_TO_SMALLER_BUCKET = false,
});

const TrackedAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = true,
});

const OneBlockPerSlabAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &ONE_BLOCK_PER_SLAB_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
});

const DirectPageAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .DIRECT_PAGE_ALLOCATE,
    .TRACK_ALLOCATION_STATS = false,
});

const DirectOneBlockPerSlabAlloc = Buckets.BucketSlabAlloc(.{
    .BUCKETS = &ONE_BLOCK_PER_SLAB_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .DIRECT_PAGE_ALLOCATE,
    .TRACK_ALLOCATION_STATS = false,
});

/// Global allocators share all of their state through the type, so every
/// definition below needs its own `UNIQUE_NAME` except where a test is
/// explicitly checking that two identical definitions share state.
const GlobalTestAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = true,
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_ALLOC",
});

/// Same settings and `UNIQUE_NAME` as `GlobalTestAlloc`: this must resolve to
/// the exact same type and therefore the exact same global state.
const GlobalTestAllocClone = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = true,
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_ALLOC",
});

/// Same settings as `GlobalTestAlloc` but a different `UNIQUE_NAME`, so it must
/// have completely separate global state.
const GlobalOtherAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = true,
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_ALLOC_OTHER",
});

const GlobalGrowOnlyAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
    .ALLOW_RESIZE_IN_PLACE_TO_SMALLER_BUCKET = false,
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_GROW_ONLY",
});

const GlobalDirectPageAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .DIRECT_PAGE_ALLOCATE,
    .TRACK_ALLOCATION_STATS = false,
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_DIRECT_PAGE",
});

const GlobalThreadlocalAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
    .THREAD_SAFETY = .threadlocal_vars(),
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_THREADLOCAL",
});

const GlobalSpinLockedAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = true,
    .THREAD_SAFETY = .data_locks(.SPIN_LOCK),
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_SPIN_LOCKED",
});

const GlobalMutexAlloc = Buckets.GlobalBucketSlabsAlloc(.{
    .BUCKETS = &TEST_BUCKETS,
    .BACKING_ALLOCATOR_MODE = .USE_BACKING_ALLOCATOR,
    .TRACK_ALLOCATION_STATS = false,
    .THREAD_SAFETY = .data_locks(.MUTEX),
    .UNIQUE_NAME = "TEST_GLOBAL_BUCKET_SLABS_MUTEX",
});

const QuickDefault = QuickBucket.QuickBucketAllocator(.{
    .LARGEST_BUCKET_SIZE = ._4_096,
    .BACKING_BLOCK_SIZE = ._65_536,
    .BACKING_META_BLOCK_SIZE = ._4_096,
});

/// One 4 KiB block per allocation, plus a tiny metadata block so that a handful
/// of allocations is enough to force the block list to grow repeatedly.
const QuickTinyMeta = QuickBucket.QuickBucketAllocator(.{
    .LARGEST_BUCKET_SIZE = ._4_096,
    .BACKING_BLOCK_SIZE = ._4_096,
    .BACKING_META_BLOCK_SIZE = ._16,
});

const QuickVec32 = @Vector(4, u64);

const QuickHugeAligned = struct {
    value: u64 align(8_192),
};

/// A minimal `AllocatorAdapter` source using the native `*_raw_native` family.
/// The adapter detects the absence of `POINTER_SOURCE` and calls these methods
/// with a `std.mem.Alignment`.
const NativeLocalAlloc = struct {
    backing: Allocator,

    pub fn alloc_raw_native(self: *NativeLocalAlloc, size: usize, alignment: Alignment) ?[*]u8 {
        return self.backing.rawAlloc(size, alignment, @returnAddress());
    }
    pub fn free_raw_native(self: *NativeLocalAlloc, memory: []u8, alignment: Alignment) void {
        self.backing.rawFree(memory, alignment, @returnAddress());
    }
    pub fn resize_raw_native(self: *NativeLocalAlloc, memory: []u8, new_len: usize, alignment: Alignment) bool {
        return self.backing.rawResize(memory, alignment, new_len, @returnAddress());
    }
    pub fn remap_raw_native(self: *NativeLocalAlloc, memory: []u8, new_len: usize, alignment: Alignment) ?[*]u8 {
        return self.backing.rawRemap(memory, alignment, new_len, @returnAddress());
    }
};

/// A minimal compliant allocator that declares a native `POINTER_SOURCE` and
/// uses the `Pointer(SOURCE)` wrapper API for its raw functions.
const WrappedLocalAlloc = struct {
    backing: Allocator,

    pub const POINTER_SOURCE = PointerSource.native_pointer();
    pub const PointerU8 = PointerModule.Pointer(u8, POINTER_SOURCE);
    pub const NullablePointerU8 = PointerModule.NullablePointer(u8, POINTER_SOURCE);

    pub fn alloc_raw_wrapper(self: *WrappedLocalAlloc, len: usize, alignment: PowerOf2) NullablePointerU8 {
        return NullablePointerU8.new_from(self.backing.rawAlloc(len, alignment.to_std_align(), @returnAddress()));
    }
    pub fn free_raw_wrapper(self: *WrappedLocalAlloc, ptr: PointerU8, len: usize, alignment: PowerOf2) void {
        self.backing.rawFree(ptr.slice(len), alignment.to_std_align(), @returnAddress());
    }
    pub fn resize_raw_wrapper(self: *WrappedLocalAlloc, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) bool {
        return self.backing.rawResize(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress());
    }
    pub fn remap_raw_wrapper(self: *WrappedLocalAlloc, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) NullablePointerU8 {
        return NullablePointerU8.new_from(self.backing.rawRemap(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress()));
    }
};

/// A minimal compliant allocator whose `POINTER_SOURCE` is a static address
/// resolver. Handles are `u32` byte offsets into a global buffer, so the
/// adapter's wrapper path has to resolve them through the source.
const RESOLVER_HEAP_SIZE = 64 * 1_024;
var resolver_heap: [RESOLVER_HEAP_SIZE]u8 align(64) = undefined;

fn resolverResolve(local: u32) usize {
    return @intFromPtr(&resolver_heap[0]) + local;
}
fn resolverIncrement(local: u32, byte_offset: usize) u32 {
    return local + @as(u32, @intCast(byte_offset));
}
fn resolverDecrement(local: u32, byte_offset: usize) u32 {
    return local - @as(u32, @intCast(byte_offset));
}

const RESOLVER = PointerModule.StaticAddressResolver{
    .FUNCS = .{ .U32 = .{
        .HAS_NULL_VALUE = true,
        .NULL_VALUE = std.math.maxInt(u32),
        .RESOLVE = resolverResolve,
        .INCREMENT = resolverIncrement,
        .DECREMENT = resolverDecrement,
    } },
    .ADDRESS_GRANULARITY = ._1,
};

const ResolverLocalAlloc = struct {
    bump: usize = 0,

    pub const POINTER_SOURCE = PointerSource.static_address_resolver(RESOLVER);
    pub const PointerU8 = PointerModule.Pointer(u8, POINTER_SOURCE);
    pub const NullablePointerU8 = PointerModule.NullablePointer(u8, POINTER_SOURCE);

    pub fn alloc_raw_wrapper(self: *ResolverLocalAlloc, len: usize, alignment: PowerOf2) NullablePointerU8 {
        const aligned = std.mem.alignForward(usize, self.bump, alignment.value_as_type(usize));
        const end = aligned + len;
        if (end > resolver_heap.len) return NullablePointerU8.new_null();
        self.bump = end;
        return NullablePointerU8.new_from(@intCast(aligned));
    }
    pub fn free_raw_wrapper(self: *ResolverLocalAlloc, ptr: PointerU8, len: usize, alignment: PowerOf2) void {
        _ = ptr;
        _ = len;
        _ = alignment;
        _ = self;
    }
    pub fn resize_raw_wrapper(self: *ResolverLocalAlloc, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) bool {
        _ = ptr;
        _ = old_len;
        _ = new_len;
        _ = alignment;
        _ = self;
        return false;
    }
    pub fn remap_raw_wrapper(self: *ResolverLocalAlloc, ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) NullablePointerU8 {
        _ = ptr;
        _ = old_len;
        _ = new_len;
        _ = alignment;
        _ = self;
        return NullablePointerU8.new_null();
    }
};

/// Used by the comptime-pointer source modes. The addresses of these globals
/// are comptime-known while their contents are filled in by the owning test.
var native_comptime_alloc_state: NativeLocalAlloc = undefined;
var wrapped_comptime_alloc_state: WrappedLocalAlloc = undefined;

/// A comptime-known `std.mem.Allocator` for the comptime-interface source mode.
const ADAPTER_COMPTIME_INTERFACE_ALLOC: Allocator = std.heap.page_allocator;

/// Backing allocators for the global compliant source modes.
var global_native_alloc_backing: Allocator = undefined;
var global_wrapped_alloc_backing: Allocator = undefined;

const GlobalNativeAlloc = struct {
    pub fn alloc_raw_native(size: usize, alignment: Alignment) ?[*]u8 {
        return global_native_alloc_backing.rawAlloc(size, alignment, @returnAddress());
    }
    pub fn free_raw_native(memory: []u8, alignment: Alignment) void {
        global_native_alloc_backing.rawFree(memory, alignment, @returnAddress());
    }
    pub fn resize_raw_native(memory: []u8, new_len: usize, alignment: Alignment) bool {
        return global_native_alloc_backing.rawResize(memory, alignment, new_len, @returnAddress());
    }
    pub fn remap_raw_native(memory: []u8, new_len: usize, alignment: Alignment) ?[*]u8 {
        return global_native_alloc_backing.rawRemap(memory, alignment, new_len, @returnAddress());
    }
};

const GlobalWrappedAlloc = struct {
    pub const POINTER_SOURCE = PointerSource.native_pointer();
    pub const PointerU8 = PointerModule.Pointer(u8, POINTER_SOURCE);
    pub const NullablePointerU8 = PointerModule.NullablePointer(u8, POINTER_SOURCE);

    pub fn alloc_raw_wrapper(len: usize, alignment: PowerOf2) NullablePointerU8 {
        return NullablePointerU8.new_from(global_wrapped_alloc_backing.rawAlloc(len, alignment.to_std_align(), @returnAddress()));
    }
    pub fn free_raw_wrapper(ptr: PointerU8, len: usize, alignment: PowerOf2) void {
        global_wrapped_alloc_backing.rawFree(ptr.slice(len), alignment.to_std_align(), @returnAddress());
    }
    pub fn resize_raw_wrapper(ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) bool {
        return global_wrapped_alloc_backing.rawResize(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress());
    }
    pub fn remap_raw_wrapper(ptr: PointerU8, old_len: usize, new_len: usize, alignment: PowerOf2) NullablePointerU8 {
        return NullablePointerU8.new_from(global_wrapped_alloc_backing.rawRemap(ptr.slice(old_len), alignment.to_std_align(), new_len, @returnAddress()));
    }
};

const ADAPTER_ALIGN_64 = Alignment.fromByteUnits(64);
const ADAPTER_ALIGN_64_POW2 = PowerOf2._64;

const CachedAdapter = AllocMod.AllocatorAdapter(AllocSource.cached_allocator_interface());
const PassedAdapter = AllocMod.AllocatorAdapter(AllocSource.passed_allocator_interface());
const ComptimeIfaceAdapter = AllocMod.AllocatorAdapter(AllocSource.comptime_allocator_interface_ptr(&ADAPTER_COMPTIME_INTERFACE_ALLOC));
const NeverAdapter = AllocMod.AllocatorAdapter(AllocSource.never_allocates());

const GlobalNativeAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_global_allocator(GlobalNativeAlloc));
const GlobalWrappedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_global_allocator(GlobalWrappedAlloc));

const NativeCachedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_cached_ptr(NativeLocalAlloc));
const NativePassedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_passed_ptr(NativeLocalAlloc));
const NativeComptimeAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_comptime_ptr(NativeLocalAlloc, &native_comptime_alloc_state));

const WrappedCachedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_cached_ptr(WrappedLocalAlloc));
const WrappedPassedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_passed_ptr(WrappedLocalAlloc));
const WrappedComptimeAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_comptime_ptr(WrappedLocalAlloc, &wrapped_comptime_alloc_state));

const ResolverCachedAdapter = AllocMod.AllocatorAdapter(AllocSource.compliant_instantiated_allocator_cached_ptr(ResolverLocalAlloc));
var resolver_alloc_state: ResolverLocalAlloc = .{};

fn fillSlice(memory: []u8, value: u8) void {
    @memset(memory, value);
}

fn expectFilled(memory: []const u8, value: u8) !void {
    for (memory) |byte| {
        try testing.expectEqual(value, byte);
    }
}

/// Adapter results are nullable wrappers, not optionals, so they cannot use
/// `orelse`. This converts one to the non-null wrapper type the free/resize/
/// remap helpers expect, or returns an out-of-memory error.
fn expectAllocation(p: anytype) !@TypeOf(p.to_non_null()) {
    if (p.is_null()) return error.OutOfMemory;
    return p.to_non_null();
}

fn exerciseAdapterAllocator(allocator: Allocator) !void {
    var memory = try allocator.alloc(u8, 16);
    for (memory, 0..) |*byte, i| byte.* = @intCast(i);

    memory = try allocator.realloc(memory, 128);
    try testing.expectEqual(@as(usize, 128), memory.len);
    for (memory[0..16], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    allocator.free(memory);

    const aligned = try allocator.alignedAlloc(u8, ADAPTER_ALIGN_64, 24);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 64);
    fillSlice(aligned, 0x5A);
    try expectFilled(aligned, 0x5A);
    allocator.free(aligned);

    const empty = try allocator.alloc(u8, 0);
    allocator.free(empty);
}

/// Exercises the helper surface shared by every allocator-backed source.
fn exerciseAdapterHelpers(allocator: anytype, alloc_param: anytype) !void {
    const A = @TypeOf(allocator);
    const bytes = try expectAllocation(allocator.alloc_bytes(32, alloc_param));
    {
        const s = bytes.slice_never_null(32);
        for (s, 0..) |*byte, i| byte.* = @intCast(i);
    }

    const grown = try expectAllocation(allocator.realloc_bytes(bytes, 32, 256, alloc_param));
    const grown_slice = grown.slice_never_null(256);
    for (grown_slice[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    allocator.free_bytes(grown, 256, alloc_param);

    const aligned = try expectAllocation(allocator.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 33, alloc_param));
    const aligned_slice = aligned.slice_never_null(33);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned_slice.ptr) % 64);
    fillSlice(aligned_slice, 0x5A);
    try expectFilled(aligned_slice, 0x5A);
    const aligned_grown = try expectAllocation(allocator.realloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned, 33, 96, alloc_param));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned_grown.slice_never_null(96).ptr) % 64);
    try expectFilled(aligned_grown.slice_never_null(96)[0..33], 0x5A);
    allocator.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_grown, 96, alloc_param);

    const values = try expectAllocation(allocator.alloc_types(u32, 4, alloc_param));
    {
        const s = values.slice_never_null(4);
        s[0] = 0xAAAA_AAAA;
        s[3] = 0xDDDD_DDDD;
    }
    const values_grown = try expectAllocation(allocator.realloc_types(u32, values, 4, 8, alloc_param));
    const values_slice = values_grown.slice_never_null(8);
    try testing.expectEqual(@as(u32, 0xAAAA_AAAA), values_slice[0]);
    try testing.expectEqual(@as(u32, 0xDDDD_DDDD), values_slice[3]);
    allocator.free_types(u32, values_grown, 8, alloc_param);

    const custom = try expectAllocation(allocator.alloc_bytes(64, alloc_param));
    fillSlice(custom.slice_never_null(64), 0x11);
    const custom_grown = try expectAllocation(allocator.realloc_bytes_custom_data_len(custom, 64, 16, 128, alloc_param));
    try testing.expectEqual(@as(usize, 128), custom_grown.slice_never_null(128).len);
    try expectFilled(custom_grown.slice_never_null(128)[0..16], 0x11);
    allocator.free_bytes(custom_grown, 128, alloc_param);

    const data = try expectAllocation(allocator.alloc_types(u16, 8, alloc_param));
    {
        const s = data.slice_never_null(8);
        s[0] = 0x1111;
        s[2] = 0x3333;
    }
    const data_grown = try expectAllocation(allocator.realloc_types_custom_data_len(u16, data, 8, 3, 32, alloc_param));
    try testing.expectEqual(@as(usize, 32), data_grown.slice_never_null(32).len);
    try testing.expectEqual(@as(u16, 0x1111), data_grown.slice_never_null(32)[0]);
    try testing.expectEqual(@as(u16, 0x3333), data_grown.slice_never_null(32)[2]);
    allocator.free_types(u16, data_grown, 32, alloc_param);

    const AlignedU32 = struct { value: u32 align(64) };
    const aligned_values = try expectAllocation(allocator.alloc_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, 2, alloc_param));
    aligned_values.slice_never_null(2)[0].value = 0x1122_3344;
    const aligned_values_grown = try expectAllocation(allocator.realloc_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 2, 8, alloc_param));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned_values_grown.slice_never_null(8).ptr) % 64);
    try testing.expectEqual(@as(u32, 0x1122_3344), aligned_values_grown.slice_never_null(8)[0].value);
    allocator.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values_grown, 8, alloc_param);

    const created = try expectAllocation(allocator.create(u64, alloc_param));
    const created_ptr = created.ptr();
    created_ptr.* = 0x1234_5678_9ABC_DEF0;
    const cloned_one = try expectAllocation(allocator.clone_one(u64, A.ConstPointer(u64).new_from(@as([*]const u64, @ptrCast(created_ptr))), alloc_param));
    try testing.expectEqual(@as(u64, 0x1234_5678_9ABC_DEF0), cloned_one.ptr().*);
    allocator.destroy(u64, cloned_one, alloc_param);
    allocator.destroy(u64, created, alloc_param);

    const native_bytes = allocator.alloc_bytes_native(24, alloc_param) orelse return error.OutOfMemory;
    fillSlice(native_bytes[0..24], 0x21);
    try expectFilled(native_bytes[0..24], 0x21);
    allocator.free_bytes_native(native_bytes[0..24], alloc_param);

    const native_aligned = allocator.alloc_bytes_with_align_native(ADAPTER_ALIGN_64, 24, alloc_param) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(native_aligned) % 64);
    fillSlice(native_aligned[0..24], 0x42);
    allocator.free_bytes_with_align_native(ADAPTER_ALIGN_64, native_aligned[0..24], alloc_param);
}

fn globalBucketSlabsThreadlocalWorker(result: *bool) void {
    const State = GlobalThreadlocalAlloc;
    // Every thread owns a completely separate allocator, including its backing
    // allocator, so this thread must initialize its own copy.
    State.init(std.heap.page_allocator, {});
    defer State.deinit();

    const first = State.alloc_bytes(32) orelse {
        result.* = false;
        return;
    };
    fillSlice(first, 0x5A);
    var ok = true;
    for (first) |byte| {
        ok = ok and byte == 0x5A;
    }

    // Exercise this thread's own free list.
    State.free_bytes(first);
    const second = State.alloc_bytes(32) orelse {
        result.* = false;
        return;
    };
    ok = ok and @intFromPtr(first.ptr) == @intFromPtr(second.ptr);
    State.free_bytes(second);
    result.* = ok;
}

fn globalBucketSlabsSpinWorker(result: *bool) void {
    const State = GlobalSpinLockedAlloc;
    const allocator = State.allocator();

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        const size = 1 + (i * 97) % 4_096;
        const memory = allocator.alloc(u8, size) catch {
            result.* = false;
            return;
        };
        const value: u8 = @intCast(i % 251);
        fillSlice(memory, value);
        for (memory) |byte| {
            if (byte != value) {
                result.* = false;
                return;
            }
        }
        allocator.free(memory);
    }
    result.* = true;
}

test "BucketSlabs -> freed block is reused from the free list" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const first = state.alloc_bytes(8) orelse return error.OutOfMemory;
    fillSlice(first, 0xAB);
    state.free_bytes(first);

    const second = state.alloc_bytes(8) orelse return error.OutOfMemory;
    defer state.free_bytes(second);

    try testing.expectEqual(@intFromPtr(first.ptr), @intFromPtr(second.ptr));
}

test "BucketSlabs -> live blocks in one bucket never overlap" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const COUNT = 257;
    var blocks: [COUNT][*]u8 = undefined;
    for (&blocks, 0..) |*block, i| {
        const memory = state.alloc_bytes(8) orelse return error.OutOfMemory;
        block.* = memory.ptr;
        fillSlice(memory, @intCast(i % 251));
    }

    for (blocks, 0..) |block, i| {
        for (blocks[0..i]) |other| {
            try testing.expect(@intFromPtr(block) != @intFromPtr(other));
        }
        try expectFilled(block[0..8], @intCast(i % 251));
    }

    for (blocks) |block| state.free_bytes(block[0..8]);
}

test "BucketSlabs -> allocations spanning many slabs and tracker growth stay valid" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    // 8-byte blocks with 4 KiB slabs means 512 blocks per slab. Using 9000
    // blocks forces 18 slabs, which grows the internal slab tracker more than
    // once (its initial capacity is 16 records).
    const COUNT = 9_000;
    const blocks = try testing.allocator.alloc([]u8, COUNT);
    defer testing.allocator.free(blocks);

    for (blocks, 0..) |*block, i| {
        block.* = state.alloc_bytes(8) orelse return error.OutOfMemory;
        std.mem.writeInt(u64, block.*[0..8], @intCast(i), .little);
    }

    for (blocks, 0..) |block, i| {
        try testing.expectEqual(@as(u64, @intCast(i)), std.mem.readInt(u64, block[0..8], .little));
    }

    for (blocks) |block| state.free_bytes(block);
}

test "BucketSlabs -> alignment requests select a suitably aligned bucket" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const bytes = state.alloc_bytes_with_align(1, Alignment.fromByteUnits(64)) orelse return error.OutOfMemory;
    defer state.free_bytes_with_align(Alignment.fromByteUnits(64), bytes);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(bytes.ptr) % 64);
    fillSlice(bytes, 0xCD);
    try expectFilled(bytes, 0xCD);

    const Aligned = struct {
        value: u64 align(64),
    };
    try testing.expectEqual(@as(usize, 64), @alignOf(Aligned));

    const item = state.alloc_types(Aligned, 1) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(item.ptr) % 64);
    item[0].value = 0x1234_5678_9ABC_DEF0;
    state.free_types(Aligned, item);

    // `free_types` must have used the type's alignment when choosing the free
    // list; otherwise this next allocation would come from the wrong bucket.
    const again = state.alloc_types(Aligned, 1) orelse return error.OutOfMemory;
    defer state.free_types(Aligned, again);
    try testing.expectEqual(@intFromPtr(item.ptr), @intFromPtr(again.ptr));
}

test "BucketSlabs -> shrink in place subdivides the block and preserves data" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const memory = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
    fillSlice(memory, 0x5A);

    try testing.expect(state.resize_bytes(memory, 64));
    const shrunk = memory.ptr[0..64];
    try expectFilled(shrunk, 0x5A);

    // The freed 64-byte block should be at the head of its free list.
    state.free_bytes(shrunk);
    const reused = state.alloc_bytes(64) orelse return error.OutOfMemory;
    defer state.free_bytes(reused);
    try testing.expectEqual(@intFromPtr(memory.ptr), @intFromPtr(reused.ptr));

    // The blocks carved out of the original 4 KiB block must also be usable.
    const carved_2k = state.alloc_bytes(2_048) orelse return error.OutOfMemory;
    fillSlice(carved_2k, 0x11);
    try expectFilled(carved_2k, 0x11);
    state.free_bytes(carved_2k);

    const carved_1k = state.alloc_bytes(1_024) orelse return error.OutOfMemory;
    fillSlice(carved_1k, 0x22);
    try expectFilled(carved_1k, 0x22);
    state.free_bytes(carved_1k);
}

test "BucketSlabs -> growing resize is refused" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const memory = state.alloc_bytes(64) orelse return error.OutOfMemory;
    defer state.free_bytes(memory);

    try testing.expect(!state.resize_bytes(memory, 128));
    try testing.expect(!state.resize_bytes(memory, 4_096));
    // Still within the same 64-byte bucket, so this is a no-op success.
    try testing.expect(state.resize_bytes(memory, 63));
}

test "BucketSlabs -> shrink is refused when the option is disabled" {
    var state = GrowOnlyAlloc.init(testing.allocator);
    defer state.deinit();

    const memory = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
    fillSlice(memory, 0x77);
    defer state.free_bytes(memory);

    try testing.expect(!state.resize_bytes(memory, 64));
    try expectFilled(memory, 0x77);
}

test "BucketSlabs -> slabs with a single block do not expose a dangling next block" {
    var state = OneBlockPerSlabAlloc.init(testing.allocator);
    defer state.deinit();

    const a = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
    const b = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
    const c = state.alloc_bytes(4_096) orelse return error.OutOfMemory;

    fillSlice(a, 0xA1);
    fillSlice(b, 0xB2);
    fillSlice(c, 0xC3);

    try expectFilled(a, 0xA1);
    try expectFilled(b, 0xB2);
    try expectFilled(c, 0xC3);

    state.free_bytes(a);
    state.free_bytes(b);
    state.free_bytes(c);
}

test "BucketSlabs -> allocations larger than the largest bucket use the fallback" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const large = state.alloc_bytes(4_097) orelse return error.OutOfMemory;
    fillSlice(large, 0x99);
    try expectFilled(large, 0x99);
    state.free_bytes(large);

    const allocator = state.allocator();
    // Both the size and the alignment are outside the bucket range.
    const aligned = try allocator.alignedAlloc(u8, Alignment.fromByteUnits(8_192), 100);
    defer allocator.free(aligned);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 8_192);
    fillSlice(aligned, 0x42);
    try expectFilled(aligned, 0x42);
}

test "BucketSlabs -> generic allocator resize and realloc work end to end" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();
    const allocator = state.allocator();

    var memory = try allocator.alloc(u8, 64);
    for (memory, 0..) |*byte, i| byte.* = @intCast(i);

    // Growing crosses bucket boundaries and must fall back to alloc + copy.
    memory = try allocator.realloc(memory, 4_096);
    for (memory[0..64], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i)), byte);
    }

    // Shrinking is done in place; the pointer must not move.
    const grown_ptr = memory.ptr;
    memory = try allocator.realloc(memory, 128);
    try testing.expectEqual(@intFromPtr(grown_ptr), @intFromPtr(memory.ptr));
    for (memory[0..64], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i)), byte);
    }

    allocator.free(memory);
}

test "BucketSlabs -> generic allocator realloc across the fallback boundary" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();
    const allocator = state.allocator();

    var memory = try allocator.alloc(u8, 5_000);
    for (memory, 0..) |*byte, i| byte.* = @intCast(i % 251);

    // Fallback -> bucket: must allocate the bucket block and copy only what fits.
    memory = try allocator.realloc(memory, 64);
    for (memory, 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i % 251)), byte);
    }

    // Bucket -> fallback: same deal in the other direction.
    memory = try allocator.realloc(memory, 9_000);
    for (memory[0..64], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i % 251)), byte);
    }

    allocator.free(memory);
}

test "BucketSlabs -> direct realloc helpers preserve data across resize paths" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const ALIGN_64 = comptime Alignment.fromByteUnits(64);

    // Grow across a bucket boundary: this must allocate a new block and copy.
    var memory = state.alloc_bytes(32) orelse return error.OutOfMemory;
    for (memory, 0..) |*byte, i| byte.* = @intCast(i);
    memory = state.realloc_bytes(memory, 1_024) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 1_024), memory.len);
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);

    // Resizing within a bucket is a no-op, and shrinking across buckets is
    // sub-divided in place, so the pointer must not move either way.
    const block_ptr = memory.ptr;
    memory = state.realloc_bytes(memory, 600) orelse return error.OutOfMemory;
    try testing.expectEqual(@intFromPtr(block_ptr), @intFromPtr(memory.ptr));
    memory = state.realloc_bytes(memory, 64) orelse return error.OutOfMemory;
    try testing.expectEqual(@intFromPtr(block_ptr), @intFromPtr(memory.ptr));
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);

    // Bucket -> fallback -> bucket.
    memory = state.realloc_bytes(memory, 9_000) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 9_000), memory.len);
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    memory = state.realloc_bytes(memory, 256) orelse return error.OutOfMemory;
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    state.free_bytes(memory);

    // Typed helpers, including a custom data count that is smaller than the
    // allocation, so only the meaningful prefix is copied.
    var values = state.alloc_types(u32, 4) orelse return error.OutOfMemory;
    values[0] = 0xAAAA_AAAA;
    values[3] = 0xDDDD_DDDD;
    values = state.realloc_types(u32, values, 64) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 64), values.len);
    try testing.expectEqual(@as(u32, 0xAAAA_AAAA), values[0]);
    try testing.expectEqual(@as(u32, 0xDDDD_DDDD), values[3]);
    values = state.realloc_types(u32, values, 2) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u32, 0xAAAA_AAAA), values[0]);
    state.free_types(u32, values);

    var data = state.alloc_types(u16, 8) orelse return error.OutOfMemory;
    data[0] = 0x1111;
    data[2] = 0x3333;
    data = state.realloc_types_custom_data_count(u16, data, 3, 32) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 32), data.len);
    try testing.expectEqual(@as(u16, 0x1111), data[0]);
    try testing.expectEqual(@as(u16, 0x3333), data[2]);
    state.free_types(u16, data);

    // Alignment must survive both growth and shrinking in place.
    var aligned = state.alloc_bytes_with_align(33, ALIGN_64) orelse return error.OutOfMemory;
    for (aligned, 0..) |*byte, i| byte.* = @intCast(i + 1);
    aligned = state.realloc_bytes_with_align(ALIGN_64, aligned, 200) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 64);
    for (aligned[0..33], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i + 1)), byte);
    aligned = state.realloc_bytes_with_align(ALIGN_64, aligned, 64) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 64);
    for (aligned[0..33], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i + 1)), byte);
    state.free_bytes_with_align(ALIGN_64, aligned);

    // Exercise the remaining helper variants so none can stay unanalyzed.
    const custom = state.alloc_bytes(64) orelse return error.OutOfMemory;
    fillSlice(custom, 0x2A);
    const custom_grown = state.realloc_bytes_custom_data_len(custom, 16, 128) orelse return error.OutOfMemory;
    try expectFilled(custom_grown[0..16], 0x2A);
    state.free_bytes(custom_grown);

    const custom_aligned = state.alloc_bytes_with_align(64, ALIGN_64) orelse return error.OutOfMemory;
    fillSlice(custom_aligned, 0x3B);
    const custom_aligned_grown = state.realloc_bytes_with_align_custom_data_len(ALIGN_64, custom_aligned, 8, 256) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(custom_aligned_grown.ptr) % 64);
    try expectFilled(custom_aligned_grown[0..8], 0x3B);
    state.free_bytes_with_align(ALIGN_64, custom_aligned_grown);

    const AlignedU32 = struct { value: u32 align(64) };
    var aligned_types = state.alloc_types_with_align(AlignedU32, 2, ALIGN_64) orelse return error.OutOfMemory;
    aligned_types[0].value = 0x1122_3344;
    aligned_types = state.realloc_types_with_align(ALIGN_64, AlignedU32, aligned_types, 8) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned_types.ptr) % 64);
    try testing.expectEqual(@as(u32, 0x1122_3344), aligned_types[0].value);
    aligned_types = state.realloc_types_with_align_custom_data_count(ALIGN_64, AlignedU32, aligned_types, 1, 4) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u32, 0x1122_3344), aligned_types[0].value);
    state.free_types_with_align(ALIGN_64, AlignedU32, aligned_types);

    // Reallocating to zero frees the old block, which is then reusable.
    const fresh = state.alloc_bytes(128) orelse return error.OutOfMemory;
    fillSlice(fresh, 0x9C);
    const emptied = state.realloc_bytes(fresh, 0) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), emptied.len);
    const reused = state.alloc_bytes(128) orelse return error.OutOfMemory;
    defer state.free_bytes(reused);
    try testing.expectEqual(@intFromPtr(fresh.ptr), @intFromPtr(reused.ptr));

    // A zero-length slice owns no storage, so growing it must allocate.
    const empty = state.alloc_bytes(0) orelse return error.OutOfMemory;
    const grown = state.realloc_bytes(empty, 48) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 48), grown.len);
    fillSlice(grown, 0x1D);
    try expectFilled(grown, 0x1D);
    state.free_bytes(grown);
}

test "BucketSlabs -> direct page slab tracker grows across a page boundary" {
    // One block per slab means one tracker record per allocation. The tracker
    // starts with 16 records and doubles, so 130 allocations force it past the
    // first page-sized resize.
    var state = DirectOneBlockPerSlabAlloc.init({});
    defer state.deinit();

    const COUNT = 130;
    const blocks = try testing.allocator.alloc([]u8, COUNT);
    defer testing.allocator.free(blocks);

    for (blocks, 0..) |*block, i| {
        block.* = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
        fillSlice(block.*, @intCast(i % 251));
    }
    for (blocks, 0..) |block, i| {
        try expectFilled(block, @intCast(i % 251));
    }
    for (blocks) |block| state.free_bytes(block);
}

test "BucketSlabs -> statistics track used and free blocks" {
    var state = TrackedAlloc.init(testing.allocator);
    defer state.deinit();

    const first = state.alloc_bytes(8) orelse return error.OutOfMemory;
    const second = state.alloc_bytes(8) orelse return error.OutOfMemory;
    const third = state.alloc_bytes(8) orelse return error.OutOfMemory;

    try testing.expectEqual(@as(usize, 3), state.stats.num_used_blocks[0]);
    try testing.expectEqual(@as(usize, 509), state.stats.num_free_blocks[0]);
    try testing.expectEqual(@as(usize, 3), state.stats.most_blocks_ever_used_by_bucket[0]);
    try testing.expectEqual(@as(usize, 24), state.stats.current_total_memory_allocated);
    try testing.expectEqual(@as(usize, 24), state.stats.largest_total_memory_allocated);
    try testing.expectEqual(@as(usize, 8), state.stats.smallest_allocation_request_ever);
    try testing.expectEqual(@as(usize, 8), state.stats.largest_allocation_request_ever);
    try testing.expectEqual(@as(usize, 1), state.stats.current_slabs_used_by_bucket[0]);

    state.free_bytes(first);
    state.free_bytes(second);
    state.free_bytes(third);

    try testing.expectEqual(@as(usize, 0), state.stats.num_used_blocks[0]);
    try testing.expectEqual(@as(usize, 512), state.stats.num_free_blocks[0]);
    try testing.expectEqual(@as(usize, 0), state.stats.current_total_memory_allocated);

    // Fallback allocation statistics.
    const large = state.alloc_bytes(5_000) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 1), state.stats.current_number_of_fallback_allocations);
    try testing.expectEqual(@as(usize, 5_000), state.stats.current_total_bytes_allocated_from_fallback);
    try testing.expectEqual(@as(usize, 5_000), state.stats.current_total_memory_allocated);
    state.free_bytes(large);
    try testing.expectEqual(@as(usize, 0), state.stats.current_number_of_fallback_allocations);
    try testing.expectEqual(@as(usize, 0), state.stats.current_total_bytes_allocated_from_fallback);
    try testing.expectEqual(@as(usize, 0), state.stats.current_total_memory_allocated);
}

test "BucketSlabs -> direct page backing allocator works and deinits" {
    var state = DirectPageAlloc.init({});
    defer state.deinit();

    const small = state.alloc_bytes(8) orelse return error.OutOfMemory;
    const medium = state.alloc_bytes(4_096) orelse return error.OutOfMemory;
    const large = state.alloc_bytes(9_000) orelse return error.OutOfMemory;

    fillSlice(small, 0x01);
    fillSlice(medium, 0x02);
    fillSlice(large, 0x03);

    try expectFilled(small, 0x01);
    try expectFilled(medium, 0x02);
    try expectFilled(large, 0x03);

    state.free_bytes(small);
    state.free_bytes(medium);
    state.free_bytes(large);
}

test "BucketSlabs -> zero byte internal allocation round trips" {
    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const empty = state.alloc_bytes(0) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), empty.len);
    state.free_bytes(empty);
}

test "BucketSlabs -> log_usage_statistics formats a report" {
    const SKIP = true;
    try Test.skip_if(SKIP);
    var log_buffer: std.ArrayList(u8) = .empty;
    defer log_buffer.deinit(testing.allocator);

    var state = TestAlloc.init(testing.allocator);
    defer state.deinit();

    const memory = state.alloc_bytes(32) orelse return error.OutOfMemory;
    state.free_bytes(memory);

    state.log_usage_statistics(&log_buffer, testing.allocator, "bucket-slabs-no-stats");
    try testing.expect(log_buffer.items.len > 0);
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "bucket-slabs-no-stats") != null);
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "Buckets: 10") != null);
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "In-use bytes:") == null);

    var tracked_state = TrackedAlloc.init(testing.allocator);
    defer tracked_state.deinit();

    const tracked_memory = tracked_state.alloc_bytes(32) orelse return error.OutOfMemory;
    tracked_state.log_usage_statistics(&log_buffer, testing.allocator, "bucket-slabs-stats");
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "bucket-slabs-stats") != null);
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "In-use bytes:") != null);
    try testing.expect(std.mem.indexOf(u8, log_buffer.items, "Fallback allocations") != null);
    tracked_state.free_bytes(tracked_memory);
}

test "GlobalBucketSlabs -> allocator API reuses freed blocks and preserves data" {
    const State = GlobalTestAlloc;
    State.init(testing.allocator, {});
    defer State.deinit();

    const allocator = State.allocator();

    const first = try allocator.alloc(u8, 8);
    fillSlice(first, 0xAB);
    allocator.free(first);

    const second = try allocator.alloc(u8, 8);
    defer allocator.free(second);
    try testing.expectEqual(@intFromPtr(first.ptr), @intFromPtr(second.ptr));
    fillSlice(second, 0xCD);
    try expectFilled(second, 0xCD);

    // Requests larger than the largest bucket use the fallback allocator.
    const large = try allocator.alloc(u8, 9_000);
    defer allocator.free(large);
    fillSlice(large, 0x99);
    try expectFilled(large, 0x99);
}

test "GlobalBucketSlabs -> direct API alignment, shrink, and grow behavior" {
    const State = GlobalTestAlloc;
    State.init(testing.allocator, {});
    defer State.deinit();

    const bytes = State.alloc_bytes_with_align(1, Alignment.fromByteUnits(64)) orelse return error.OutOfMemory;
    defer State.free_bytes_with_align(Alignment.fromByteUnits(64), bytes);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(bytes.ptr) % 64);
    fillSlice(bytes, 0xCD);
    try expectFilled(bytes, 0xCD);

    const memory = State.alloc_bytes(4_096) orelse return error.OutOfMemory;
    fillSlice(memory, 0x5A);

    // Shrinking is done in place and leaves the leading bytes untouched.
    try testing.expect(State.resize_bytes(memory, 64));
    const shrunk = memory.ptr[0..64];
    try expectFilled(shrunk, 0x5A);

    // Growing across a bucket boundary must be refused.
    try testing.expect(!State.resize_bytes(shrunk, 4_096));
    State.free_bytes(shrunk);
}

test "GlobalBucketSlabs -> realloc helpers preserve data across resize paths" {
    const State = GlobalTestAlloc;
    const ALIGN_64 = comptime Alignment.fromByteUnits(64);
    State.init(testing.allocator, {});
    defer State.deinit();

    // Grow across buckets, then shrink in place.
    var memory = State.alloc_bytes(32) orelse return error.OutOfMemory;
    for (memory, 0..) |*byte, i| byte.* = @intCast(i);

    memory = State.realloc_bytes(memory, 2_048) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 2_048), memory.len);
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);

    const block_ptr = memory.ptr;
    memory = State.realloc_bytes(memory, 100) orelse return error.OutOfMemory;
    try testing.expectEqual(@intFromPtr(block_ptr), @intFromPtr(memory.ptr));
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);

    // Bucket -> fallback -> bucket.
    memory = State.realloc_bytes(memory, 9_000) orelse return error.OutOfMemory;
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    memory = State.realloc_bytes(memory, 128) orelse return error.OutOfMemory;
    for (memory[0..32], 0..) |byte, i| try testing.expectEqual(@as(u8, @intCast(i)), byte);
    State.free_bytes(memory);

    // Typed helpers, including reallocating to zero.
    var values = State.alloc_types(u16, 4) orelse return error.OutOfMemory;
    values[0] = 0xAAAA;
    values[3] = 0xDDDD;
    values = State.realloc_types(u16, values, 64) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u16, 0xAAAA), values[0]);
    try testing.expectEqual(@as(u16, 0xDDDD), values[3]);
    values = State.realloc_types(u16, values, 0) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), values.len);

    // Aligned realloc that only copies an explicit valid prefix.
    var aligned = State.alloc_bytes_with_align(16, ALIGN_64) orelse return error.OutOfMemory;
    fillSlice(aligned, 0x6B);
    aligned = State.realloc_bytes_with_align_custom_data_len(ALIGN_64, aligned, 16, 512) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 512), aligned.len);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 64);
    try expectFilled(aligned[0..16], 0x6B);
    State.free_bytes_with_align(ALIGN_64, aligned);

    // Exercise the remaining helper variants so none can stay unanalyzed.
    var plain_aligned = State.alloc_bytes_with_align(32, ALIGN_64) orelse return error.OutOfMemory;
    fillSlice(plain_aligned, 0x7F);
    plain_aligned = State.realloc_bytes_with_align(ALIGN_64, plain_aligned, 96) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(plain_aligned.ptr) % 64);
    try expectFilled(plain_aligned[0..32], 0x7F);
    State.free_bytes_with_align(ALIGN_64, plain_aligned);

    const custom = State.alloc_bytes(64) orelse return error.OutOfMemory;
    fillSlice(custom, 0x5D);
    const custom_grown = State.realloc_bytes_custom_data_len(custom, 16, 96) orelse return error.OutOfMemory;
    try expectFilled(custom_grown[0..16], 0x5D);
    State.free_bytes(custom_grown);

    const AlignedU32 = struct { value: u32 align(64) };
    var aligned_types = State.alloc_types_with_align(AlignedU32, 2, ALIGN_64) orelse return error.OutOfMemory;
    aligned_types[0].value = 0x5566_7788;
    aligned_types = State.realloc_types_with_align(ALIGN_64, AlignedU32, aligned_types, 6) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u32, 0x5566_7788), aligned_types[0].value);
    aligned_types = State.realloc_types_with_align_custom_data_count(ALIGN_64, AlignedU32, aligned_types, 1, 3) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u32, 0x5566_7788), aligned_types[0].value);
    State.free_types_with_align(ALIGN_64, AlignedU32, aligned_types);

    const raw_memory = State.alloc_bytes(32) orelse return error.OutOfMemory;
    fillSlice(raw_memory, 0x8A);
    const raw_grown = State.realloc_raw(raw_memory, 32, 512, null) orelse return error.OutOfMemory;
    try expectFilled(raw_grown[0..32], 0x8A);
    State.free_raw(raw_grown[0..512], null);

    // Reallocating to zero returns the block to the free list.
    const fresh = State.alloc_bytes(64) orelse return error.OutOfMemory;
    const emptied = State.realloc_bytes(fresh, 0) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), emptied.len);
    const reused = State.alloc_bytes(64) orelse return error.OutOfMemory;
    defer State.free_bytes(reused);
    try testing.expectEqual(@intFromPtr(fresh.ptr), @intFromPtr(reused.ptr));
}

test "GlobalBucketSlabs -> typed helpers, remap, create/destroy, and logging" {
    const State = GlobalTestAlloc;
    const AlignedU64 = struct {
        value: u64 align(64),
    };
    const ALIGN_64 = comptime Alignment.fromByteUnits(64);

    State.init(testing.allocator, {});
    defer State.deinit();

    const values = State.alloc_types(u32, 4) orelse return error.OutOfMemory;
    values[0] = 1;
    values[3] = 4;
    State.free_types(u32, values);

    const aligned = State.alloc_types_with_align(AlignedU64, 2, ALIGN_64) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.ptr) % 64);
    aligned[0].value = 7;
    aligned[1].value = 8;
    State.free_types_with_align(ALIGN_64, AlignedU64, aligned);

    const aligned_bytes = State.alloc_bytes_with_align(64, ALIGN_64) orelse return error.OutOfMemory;
    fillSlice(aligned_bytes, 0x44);
    try testing.expect(State.resize_bytes_with_align(ALIGN_64, aligned_bytes, 32));
    const shrunk = aligned_bytes.ptr[0..32];
    try expectFilled(shrunk, 0x44);

    const remapped = State.remap_bytes_with_align(ALIGN_64, shrunk, 16) orelse return error.OutOfMemory;
    try expectFilled(remapped, 0x44);
    State.free_bytes_with_align(ALIGN_64, remapped);

    const items = State.alloc_types(u32, 4) orelse return error.OutOfMemory;
    items[0] = 0xAAAA;
    items[1] = 0xBBBB;
    const fewer = State.remap_types(u32, items, 2) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u32, 0xAAAA), fewer[0]);
    try testing.expectEqual(@as(u32, 0xBBBB), fewer[1]);
    State.free_types(u32, fewer);

    const raw = State.alloc_bytes(128) orelse return error.OutOfMemory;
    fillSlice(raw, 0x55);
    const raw_smaller = State.remap_bytes(raw, 32) orelse return error.OutOfMemory;
    try expectFilled(raw_smaller, 0x55);
    State.free_bytes(raw_smaller);

    const created = State.create_with_align(u64, ALIGN_64) orelse return error.OutOfMemory;
    created.* = 99;
    try testing.expectEqual(@as(u64, 99), created.*);
    State.destroy_with_align(ALIGN_64, u64, created);

    const plain = State.create(u32) orelse return error.OutOfMemory;
    plain.* = 123;
    try testing.expectEqual(@as(u32, 123), plain.*);
    State.destroy(u32, plain);
}

test "GlobalBucketSlabs -> identical definitions share type and global state" {
    try testing.expect(GlobalTestAlloc == GlobalTestAllocClone);
    try testing.expectEqual(GlobalTestAlloc.type_id(), GlobalTestAllocClone.type_id());
    try testing.expectEqualStrings(GlobalTestAlloc.UNIQUE_NAME, GlobalTestAllocClone.UNIQUE_NAME);

    GlobalTestAlloc.init(testing.allocator, {});
    defer GlobalTestAlloc.deinit();

    const first = GlobalTestAlloc.alloc_bytes(16) orelse return error.OutOfMemory;
    fillSlice(first, 0x42);
    GlobalTestAlloc.free_bytes(first);

    // The clone is the same type, so it sees the same free list.
    const second = GlobalTestAllocClone.alloc_bytes(16) orelse return error.OutOfMemory;
    defer GlobalTestAllocClone.free_bytes(second);
    try testing.expectEqual(@intFromPtr(first.ptr), @intFromPtr(second.ptr));
    fillSlice(second, 0x43);
    try expectFilled(second, 0x43);
}

test "GlobalBucketSlabs -> UNIQUE_NAME keeps global state separate" {
    try testing.expect(GlobalTestAlloc != GlobalOtherAlloc);
    try testing.expect(GlobalTestAlloc.type_id() != GlobalOtherAlloc.type_id());
    try testing.expectEqual(GlobalTestAlloc.type_id_generic(), GlobalOtherAlloc.type_id_generic());

    GlobalTestAlloc.init(testing.allocator, {});
    defer GlobalTestAlloc.deinit();
    GlobalOtherAlloc.init(testing.allocator, {});
    defer GlobalOtherAlloc.deinit();

    const first = GlobalTestAlloc.alloc_bytes(16) orelse return error.OutOfMemory;
    fillSlice(first, 0xAA);
    const second = GlobalOtherAlloc.alloc_bytes(16) orelse return error.OutOfMemory;
    fillSlice(second, 0xBB);

    // Unmapping the first allocator's slabs must not disturb the second one.
    GlobalTestAlloc.deinit();
    try expectFilled(second, 0xBB);

    GlobalOtherAlloc.free_bytes(second);
}

test "GlobalBucketSlabs -> deinit resets state and allows re-initialization" {
    const State = GlobalTestAlloc;

    State.init(testing.allocator, {});
    const first = State.alloc_bytes(32) orelse return error.OutOfMemory;
    fillSlice(first, 0x77);
    State.free_bytes(first);
    State.deinit();

    // Re-initializing must start from a clean slate rather than reusing the
    // freed tracker or slab records.
    State.init(testing.allocator, {});
    defer State.deinit();

    const second = State.alloc_bytes(32) orelse return error.OutOfMemory;
    fillSlice(second, 0x88);
    try expectFilled(second, 0x88);
    State.free_bytes(second);
}

test "GlobalBucketSlabs -> shrink is refused when the option is disabled" {
    const State = GlobalGrowOnlyAlloc;
    State.init(testing.allocator, {});
    defer State.deinit();

    const memory = State.alloc_bytes(4_096) orelse return error.OutOfMemory;
    fillSlice(memory, 0x77);
    defer State.free_bytes(memory);

    try testing.expect(!State.resize_bytes(memory, 64));
    try expectFilled(memory, 0x77);
}

test "GlobalBucketSlabs -> direct page backing allocator works and deinits" {
    const State = GlobalDirectPageAlloc;
    State.init({}, {});
    defer State.deinit();

    const small = State.alloc_bytes(8) orelse return error.OutOfMemory;
    const medium = State.alloc_bytes(4_096) orelse return error.OutOfMemory;
    const large = State.alloc_bytes(9_000) orelse return error.OutOfMemory;

    fillSlice(small, 0x01);
    fillSlice(medium, 0x02);
    fillSlice(large, 0x03);

    try expectFilled(small, 0x01);
    try expectFilled(medium, 0x02);
    try expectFilled(large, 0x03);

    State.free_bytes(small);
    State.free_bytes(medium);
    State.free_bytes(large);
}

test "GlobalBucketSlabs -> mutex mode works with an Io" {
    const State = GlobalMutexAlloc;

    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();

    State.init(testing.allocator, threaded.io());
    defer State.deinit();

    const memory = State.alloc_bytes(128) orelse return error.OutOfMemory;
    fillSlice(memory, 0x33);
    try expectFilled(memory, 0x33);
    State.free_bytes(memory);
}

test "GlobalBucketSlabs -> threadlocal vars isolate state per thread" {
    const State = GlobalThreadlocalAlloc;

    State.init(testing.allocator, {});
    defer State.deinit();

    const main_memory = State.alloc_bytes(64) orelse return error.OutOfMemory;
    fillSlice(main_memory, 0x11);

    var worker_ok = false;
    const thread = try std.Thread.spawn(.{}, globalBucketSlabsThreadlocalWorker, .{&worker_ok});
    thread.join();

    try testing.expect(worker_ok);
    try expectFilled(main_memory, 0x11);
    State.free_bytes(main_memory);
}

test "GlobalBucketSlabs -> spin locks serialize concurrent access" {
    const State = GlobalSpinLockedAlloc;
    State.init(testing.allocator, {});
    defer State.deinit();

    const NUM_THREADS = 4;
    var results: [NUM_THREADS]bool = @splat(false);
    var threads: [NUM_THREADS]std.Thread = undefined;

    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, globalBucketSlabsSpinWorker, .{&results[i]});
    }
    for (&threads) |*thread| thread.join();

    for (results) |result| try testing.expect(result);
}

test "QuickBucket -> free list reuse and bump coalescing" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    const first = try state.alloc(u8, 100);
    const second = try state.alloc(u8, 100);
    fillSlice(first, 0xA1);
    fillSlice(second, 0xB2);

    // The first slot is not adjacent to the bump pointer, so it goes on the
    // 128-byte free list and comes back out unchanged.
    state.free(u8, first);
    const from_free_list = try state.alloc(u8, 100);
    try testing.expectEqual(@intFromPtr(first.ptr), @intFromPtr(from_free_list.ptr));
    fillSlice(from_free_list, 0xC3);
    try expectFilled(from_free_list, 0xC3);

    // The second slot is adjacent to the bump pointer, so freeing it returns
    // the space to the bump region and the next allocation reuses that address.
    state.free(u8, second);
    const from_bump = try state.alloc(u8, 100);
    try testing.expectEqual(@intFromPtr(second.ptr), @intFromPtr(from_bump.ptr));
    try expectFilled(from_bump, 0xB2);

    state.free(u8, from_free_list);
    state.free(u8, from_bump);
}

test "QuickBucket -> data survives many allocations across classes" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    const COUNT = 300;
    const blocks = try testing.allocator.alloc([]u8, COUNT);
    defer testing.allocator.free(blocks);

    for (blocks, 0..) |*block, i| {
        const size = 1 + (i * 97) % 4_096;
        block.* = try state.alloc(u8, size);
        fillSlice(block.*, @intCast(i % 251));
    }
    for (blocks, 0..) |block, i| {
        try expectFilled(block, @intCast(i % 251));
    }
    for (blocks) |block| state.free(u8, block);
}

test "QuickBucket -> respects type alignment and falls back for huge alignment" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    try testing.expect(@alignOf(QuickVec32) > 16);
    const vectors = try state.alloc(QuickVec32, 4);
    defer state.free(QuickVec32, vectors);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(vectors.ptr) % @alignOf(QuickVec32));
    for (vectors) |*vector| vector.* = @splat(0x0102_0304_0506_0708);
    for (vectors) |vector| try testing.expectEqual(@as(u64, 0x0102_0304_0506_0708), vector[0]);

    // Larger than the biggest class, so this must go to the backing allocator
    // with the full requested alignment.
    const huge = try state.alloc(QuickHugeAligned, 1);
    defer state.free(QuickHugeAligned, huge);
    try testing.expectEqual(@as(usize, 0), @intFromPtr(huge.ptr) % 8_192);
    huge[0].value = 42;
    try testing.expectEqual(@as(u64, 42), huge[0].value);
}

test "QuickBucket -> resize and realloc preserve data" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    var memory = try state.alloc(u8, 17);
    for (memory, 0..) |*byte, i| byte.* = @intCast(i);
    const initial_ptr = memory.ptr;
    try testing.expectEqual(@as(u8, 16), memory[16]);

    // Same class and then a larger class while this is the last bump slot.
    try testing.expect(state.resize(u8, memory, 32));
    memory = memory.ptr[0..32];
    try testing.expect(state.resize(u8, memory, 100));
    memory = memory.ptr[0..100];
    try testing.expectEqual(@intFromPtr(initial_ptr), @intFromPtr(memory.ptr));
    for (memory[0..17], 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i)), byte);
    }

    // Shrinking to a smaller class cannot stay in place.
    try testing.expect(!state.resize(u8, memory, 10));
    memory = try state.realloc(u8, memory, 10);
    for (memory, 0..) |byte, i| {
        try testing.expectEqual(@as(u8, @intCast(i)), byte);
    }
    try testing.expectEqual(@as(usize, 10), memory.len);

    memory = try state.realloc(u8, memory, 0);
    try testing.expectEqual(@as(usize, 0), memory.len);
}

test "QuickBucket -> growing a non-last slot is refused" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    const first = try state.alloc(u8, 100);
    const second = try state.alloc(u8, 100);
    defer state.free(u8, second);
    defer state.free(u8, first);

    try testing.expect(!state.resize(u8, first, 200));
    try testing.expect(state.resize(u8, second, 128));
}

test "QuickBucket -> allocations larger than the largest class use the backing allocator" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    const large = try state.alloc(u8, 9_000);
    defer state.free(u8, large);
    fillSlice(large, 0x99);
    try expectFilled(large, 0x99);
}

test "QuickBucket -> zero-length allocations do not consume slots" {
    var state = QuickDefault.init(testing.allocator);
    defer state.uninit();

    const empty = try state.alloc(u8, 0);
    try testing.expectEqual(@as(usize, 0), empty.len);
    state.free(u8, empty);
    state.free(u8, empty);

    // A void slice owns no slot, so growing it must allocate real storage.
    try testing.expect(!state.resize(u8, empty, 16));
    const grown = try state.realloc(u8, empty, 16);
    defer state.free(u8, grown);
    try testing.expectEqual(@as(usize, 16), grown.len);
    fillSlice(grown, 0x55);
    try expectFilled(grown, 0x55);

    const non_empty = try state.alloc(u8, 16);
    fillSlice(non_empty, 0x44);
    try expectFilled(non_empty, 0x44);
    state.free(u8, non_empty);
}

test "QuickBucket -> block metadata grows and deinit releases every block" {
    var state = QuickTinyMeta.init(testing.allocator);
    defer state.uninit();

    const COUNT = 10;
    const blocks = try testing.allocator.alloc([]u8, COUNT);
    defer testing.allocator.free(blocks);

    for (blocks, 0..) |*block, i| {
        block.* = try state.alloc(u8, 4_096);
        fillSlice(block.*, @intCast(i % 251));
    }
    for (blocks, 0..) |block, i| {
        try expectFilled(block, @intCast(i % 251));
    }
    for (blocks) |block| state.free(u8, block);
}

test "AllocatorAdapter -> source metadata maps each mode to the right storage" {
    const passed = AllocSource.passed_allocator_interface();
    try testing.expect(passed.PARAM_TYPE() == Allocator);
    try testing.expect(passed.FIELD_TYPE() == void);
    try testing.expect(passed.USE_PARAM_TYPE());
    try testing.expect(!passed.USE_FIELD_TYPE());
    try testing.expect(!passed.USE_CONST_TYPE());
    try testing.expect(passed.equals(AllocSource.passed_allocator_interface()));
    try testing.expect(!passed.equals(AllocSource.cached_allocator_interface()));

    const cached = AllocSource.cached_allocator_interface();
    try testing.expect(cached.FIELD_TYPE() == Allocator);
    try testing.expect(cached.PARAM_TYPE() == void);
    try testing.expect(cached.USE_FIELD_TYPE());
    try testing.expect(!cached.USE_PARAM_TYPE());
    try testing.expect(!cached.USE_CONST_TYPE());

    const iface = AllocSource.comptime_allocator_interface_ptr(&ADAPTER_COMPTIME_INTERFACE_ALLOC);
    try testing.expect(iface.CONST_TYPE() == *const Allocator);
    try testing.expect(iface.USE_CONST_TYPE());
    try testing.expect(!iface.USE_FIELD_TYPE());
    try testing.expect(!iface.USE_PARAM_TYPE());

    const never = AllocSource.never_allocates();
    try testing.expect(never.CAN_NEVER_ALLOCATE());
    try testing.expect(never.PARAM_TYPE() == void);
    try testing.expect(never.FIELD_TYPE() == void);
    try testing.expect(never.CONST_TYPE() == void);

    const global_native = AllocSource.compliant_global_allocator(GlobalNativeAlloc);
    try testing.expect(global_native.CONST_TYPE() == type);
    try testing.expect(global_native.COMPLIANT_TYPE() == GlobalNativeAlloc);
    try testing.expect(global_native.INSTANTIATED_COMPLIANT_TYPE_PTR() == void);
    try testing.expect(global_native.USE_CONST_TYPE());
    try testing.expect(global_native.equals(AllocSource.compliant_global_allocator(GlobalNativeAlloc)));
    try testing.expect(!global_native.equals(AllocSource.compliant_global_allocator(GlobalWrappedAlloc)));
    try testing.expectEqualStrings("COMPILANT_GLOBAL_ALLOCATOR" ++ @typeName(GlobalNativeAlloc), global_native.debug_str());

    const local_cached = AllocSource.compliant_instantiated_allocator_cached_ptr(NativeLocalAlloc);
    try testing.expect(local_cached.FIELD_TYPE() == *NativeLocalAlloc);
    try testing.expect(local_cached.INSTANTIATED_COMPLIANT_TYPE_PTR() == *NativeLocalAlloc);
    try testing.expect(local_cached.USE_FIELD_TYPE());

    const local_passed = AllocSource.compliant_instantiated_allocator_passed_ptr(NativeLocalAlloc);
    try testing.expect(local_passed.PARAM_TYPE() == *NativeLocalAlloc);
    try testing.expect(local_passed.INSTANTIATED_COMPLIANT_TYPE_PTR() == *NativeLocalAlloc);
    try testing.expect(local_passed.USE_PARAM_TYPE());

    const local_comptime = AllocSource.compliant_instantiated_allocator_comptime_ptr(NativeLocalAlloc, &native_comptime_alloc_state);
    try testing.expect(local_comptime.CONST_TYPE() == *NativeLocalAlloc);
    try testing.expect(local_comptime.INSTANTIATED_COMPLIANT_TYPE_PTR() == *NativeLocalAlloc);
    try testing.expect(local_comptime.USE_CONST_TYPE());

    // Adapter-level metadata. Both compliant source styles must be detected as
    // native here because the wrapper style declares a native `POINTER_SOURCE`.
    try testing.expect(CachedAdapter.PassedAlloc == void);
    try testing.expect(CachedAdapter.CachedAlloc == Allocator);
    try testing.expect(PassedAdapter.PassedAlloc == Allocator);
    try testing.expect(PassedAdapter.CachedAlloc == void);
    try testing.expect(NativeCachedAdapter.PassedAlloc == void);
    try testing.expect(NativeCachedAdapter.CachedAlloc == *NativeLocalAlloc);
    try testing.expect(NativePassedAdapter.PassedAlloc == *NativeLocalAlloc);
    try testing.expect(NativeCachedAdapter.POINTER_SOURCE_IS_NATIVE);
    try testing.expect(WrappedCachedAdapter.POINTER_SOURCE_IS_NATIVE);
    try testing.expect(NativeCachedAdapter.POINTER_SOURCE == .NATIVE);
    try testing.expect(WrappedCachedAdapter.POINTER_SOURCE == .NATIVE);
}

test "AllocatorAdapter -> std allocator interface for every interface-backed source" {
    {
        var adapter = CachedAdapter.new(testing.allocator);
        try exerciseAdapterAllocator(adapter.interface());
    }

    try exerciseAdapterAllocator(ComptimeIfaceAdapter.interface());

    {
        const passed = PassedAdapter{};
        var adapter = passed.passed_source_interface_adapter(testing.allocator);
        try exerciseAdapterAllocator(adapter.interface());
    }

    global_native_alloc_backing = testing.allocator;
    try exerciseAdapterAllocator(GlobalNativeAdapter.interface());
    global_wrapped_alloc_backing = testing.allocator;
    try exerciseAdapterAllocator(GlobalWrappedAdapter.interface());

    {
        var state = NativeLocalAlloc{ .backing = testing.allocator };
        var adapter = NativeCachedAdapter.new(&state);
        try exerciseAdapterAllocator(adapter.interface());
    }
    {
        var state = WrappedLocalAlloc{ .backing = testing.allocator };
        var adapter = WrappedCachedAdapter.new(&state);
        try exerciseAdapterAllocator(adapter.interface());
    }

    native_comptime_alloc_state = .{ .backing = testing.allocator };
    try exerciseAdapterAllocator(NativeComptimeAdapter.interface());
    wrapped_comptime_alloc_state = .{ .backing = testing.allocator };
    try exerciseAdapterAllocator(WrappedComptimeAdapter.interface());
}

test "AllocatorAdapter -> cached allocator interface helper surface" {
    const adapter = CachedAdapter.new(testing.allocator);
    try exerciseAdapterHelpers(adapter, {});
}

test "AllocatorAdapter -> passed allocator interface helper surface" {
    const adapter = PassedAdapter{};
    try exerciseAdapterHelpers(adapter, testing.allocator);
}

test "AllocatorAdapter -> compliant global allocator helper surface" {
    global_native_alloc_backing = testing.allocator;
    try exerciseAdapterHelpers(GlobalNativeAdapter{}, {});

    global_wrapped_alloc_backing = testing.allocator;
    try exerciseAdapterHelpers(GlobalWrappedAdapter{}, {});
}

test "AllocatorAdapter -> compliant instantiated allocator helper surface" {
    var native_state = NativeLocalAlloc{ .backing = testing.allocator };
    try exerciseAdapterHelpers(NativeCachedAdapter.new(&native_state), {});
    try exerciseAdapterHelpers(NativePassedAdapter{}, &native_state);

    native_comptime_alloc_state = .{ .backing = testing.allocator };
    try exerciseAdapterHelpers(NativeComptimeAdapter{}, {});

    var wrapped_state = WrappedLocalAlloc{ .backing = testing.allocator };
    try exerciseAdapterHelpers(WrappedCachedAdapter.new(&wrapped_state), {});
    try exerciseAdapterHelpers(WrappedPassedAdapter{}, &wrapped_state);

    wrapped_comptime_alloc_state = .{ .backing = testing.allocator };
    try exerciseAdapterHelpers(WrappedComptimeAdapter{}, {});
}

test "AllocatorAdapter -> cached source resize families" {
    const adapter = CachedAdapter.new(testing.allocator);

    // Both outcomes are valid; a successful resize keeps the leading data and
    // the caller frees the block at the new length.
    const raw_mem = try expectAllocation(adapter.alloc_raw(256, PowerOf2._1, {}));
    fillSlice(raw_mem.slice_never_null(256), 0x3C);
    if (adapter.resize_raw(raw_mem, 256, 64, PowerOf2._1, {})) {
        try expectFilled(raw_mem.slice_never_null(64), 0x3C);
        adapter.free_raw(raw_mem, 64, PowerOf2._1, {});
    } else {
        adapter.free_raw(raw_mem, 256, PowerOf2._1, {});
    }

    const byte_mem = try expectAllocation(adapter.alloc_bytes(128, {}));
    fillSlice(byte_mem.slice_never_null(128), 0x4D);
    if (adapter.resize_bytes(byte_mem, 128, 64, {})) {
        try expectFilled(byte_mem.slice_never_null(64), 0x4D);
        adapter.free_bytes(byte_mem, 64, {});
    } else {
        adapter.free_bytes(byte_mem, 128, {});
    }

    const aligned_mem = try expectAllocation(adapter.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 128, {}));
    fillSlice(aligned_mem.slice_never_null(128), 0x4E);
    if (adapter.resize_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_mem, 128, 64, {})) {
        try expectFilled(aligned_mem.slice_never_null(64), 0x4E);
        adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_mem, 64, {});
    } else {
        adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_mem, 128, {});
    }

    const values = try expectAllocation(adapter.alloc_types(u32, 8, {}));
    for (values.slice_never_null(8), 0..) |*value, i| value.* = @intCast(i);
    if (adapter.resize_types(u32, values, 8, 4, {})) {
        try testing.expectEqual(@as(u32, 0), values.slice_never_null(4)[0]);
        try testing.expectEqual(@as(u32, 3), values.slice_never_null(4)[3]);
        adapter.free_types(u32, values, 4, {});
    } else {
        adapter.free_types(u32, values, 8, {});
    }

    const AlignedU32 = struct { value: u32 align(64) };
    const aligned_values = try expectAllocation(adapter.alloc_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, 4, {}));
    aligned_values.slice_never_null(4)[2].value = 42;
    if (adapter.resize_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 4, 3, {})) {
        try testing.expectEqual(@as(u32, 42), aligned_values.slice_never_null(3)[2].value);
        adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 3, {});
    } else {
        adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 4, {});
    }
}

test "AllocatorAdapter -> cached source remap families" {
    const adapter = CachedAdapter.new(testing.allocator);

    const raw_src = try expectAllocation(adapter.alloc_raw(64, PowerOf2._1, {}));
    fillSlice(raw_src.slice_never_null(64), 0x6E);
    const raw_remapped = adapter.remap_raw(raw_src, 64, 32, PowerOf2._1, {});
    if (!raw_remapped.is_null()) {
        const remapped = raw_remapped.to_non_null();
        try expectFilled(remapped.slice_never_null(32), 0x6E);
        adapter.free_raw(remapped, 32, PowerOf2._1, {});
    } else {
        adapter.free_raw(raw_src, 64, PowerOf2._1, {});
    }

    const byte_src = try expectAllocation(adapter.alloc_bytes(64, {}));
    fillSlice(byte_src.slice_never_null(64), 0x7F);
    const byte_remapped = adapter.remap_bytes(byte_src, 64, 32, {});
    if (!byte_remapped.is_null()) {
        const remapped = byte_remapped.to_non_null();
        try expectFilled(remapped.slice_never_null(32), 0x7F);
        adapter.free_bytes(remapped, 32, {});
    } else {
        adapter.free_bytes(byte_src, 64, {});
    }

    const aligned_src = try expectAllocation(adapter.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 64, {}));
    fillSlice(aligned_src.slice_never_null(64), 0x8A);
    const aligned_remapped = adapter.remap_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_src, 64, 32, {});
    if (!aligned_remapped.is_null()) {
        const remapped = aligned_remapped.to_non_null();
        try expectFilled(remapped.slice_never_null(32), 0x8A);
        try testing.expectEqual(@as(usize, 0), @intFromPtr(remapped.slice_never_null(32).ptr) % 64);
        adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, remapped, 32, {});
    } else {
        adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_src, 64, {});
    }

    const values = try expectAllocation(adapter.alloc_types(u16, 8, {}));
    {
        const s = values.slice_never_null(8);
        s[0] = 0x1111;
        s[7] = 0x8888;
    }
    const values_remapped = adapter.remap_types(u16, values, 8, 4, {});
    if (!values_remapped.is_null()) {
        const remapped = values_remapped.to_non_null();
        try testing.expectEqual(@as(u16, 0x1111), remapped.slice_never_null(4)[0]);
        adapter.free_types(u16, remapped, 4, {});
    } else {
        adapter.free_types(u16, values, 8, {});
    }

    const AlignedU32 = struct { value: u32 align(64) };
    const aligned_values = try expectAllocation(adapter.alloc_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, 4, {}));
    aligned_values.slice_never_null(4)[0].value = 0xCAFE;
    const aligned_values_remapped = adapter.remap_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 4, 2, {});
    if (!aligned_values_remapped.is_null()) {
        const remapped = aligned_values_remapped.to_non_null();
        try testing.expectEqual(@as(u32, 0xCAFE), remapped.slice_never_null(2)[0].value);
        adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, remapped, 2, {});
    } else {
        adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 4, {});
    }
}

test "AllocatorAdapter -> cached source clone families" {
    const adapter = CachedAdapter.new(testing.allocator);
    const A = CachedAdapter;

    const src = try expectAllocation(adapter.alloc_bytes(48, {}));
    for (src.slice_never_null(48), 0..) |*byte, i| byte.* = @intCast(i);
    const src_c = A.ConstPointerU8.new_from(src.slice_never_null(48).ptr);

    const cloned = try expectAllocation(adapter.clone_bytes(src_c, 48, {}));
    try testing.expectEqualSlices(u8, src.slice_never_null(48), cloned.slice_never_null(48));
    try testing.expect(@intFromPtr(cloned.slice_never_null(48).ptr) != @intFromPtr(src.slice_never_null(48).ptr));
    adapter.free_bytes(cloned, 48, {});

    const cloned_custom = try expectAllocation(adapter.clone_bytes_custom_data_len(src_c, 48, 8, {}));
    try testing.expectEqualSlices(u8, src.slice_never_null(48)[0..8], cloned_custom.slice_never_null(48)[0..8]);
    adapter.free_bytes(cloned_custom, 48, {});

    const slim_cloned = try expectAllocation(adapter.slim_clone_bytes_custom_data_len(src_c, 48, 8, {}));
    try testing.expectEqualSlices(u8, src.slice_never_null(48)[0..8], slim_cloned.slice_never_null(8));
    adapter.free_bytes(slim_cloned, 8, {});

    const raw_clone = try expectAllocation(adapter.clone_raw(src_c, 48, 24, PowerOf2._1, {}));
    try testing.expectEqualSlices(u8, src.slice_never_null(48)[0..24], raw_clone.slice_never_null(48)[0..24]);
    adapter.free_raw(raw_clone, 48, PowerOf2._1, {});

    const raw_slim = try expectAllocation(adapter.clone_slim_raw(src_c, 48, 24, PowerOf2._1, {}));
    try testing.expectEqualSlices(u8, src.slice_never_null(48)[0..24], raw_slim.slice_never_null(24));
    adapter.free_raw(raw_slim, 24, PowerOf2._1, {});
    adapter.free_bytes(src, 48, {});

    const values = try expectAllocation(adapter.alloc_types(u32, 3, {}));
    {
        const s = values.slice_never_null(3);
        s[0] = 7;
        s[2] = 9;
    }
    const values_c = A.ConstPointer(u32).new_from(values.slice_never_null(3).ptr);

    const cloned_types = try expectAllocation(adapter.clone_types(u32, values_c, 3, {}));
    try testing.expectEqualSlices(u32, values.slice_never_null(3), cloned_types.slice_never_null(3));
    adapter.free_types(u32, cloned_types, 3, {});

    const cloned_types_custom = try expectAllocation(adapter.clone_types_custom_data_len(u32, values_c, 3, 1, {}));
    try testing.expectEqual(@as(usize, 3), cloned_types_custom.slice_never_null(3).len);
    try testing.expectEqual(@as(u32, 7), cloned_types_custom.slice_never_null(3)[0]);
    adapter.free_types(u32, cloned_types_custom, 3, {});

    const slim_types = try expectAllocation(adapter.slim_clone_types_custom_data_len(u32, values_c, 3, 1, {}));
    try testing.expectEqual(@as(usize, 1), slim_types.slice_never_null(1).len);
    try testing.expectEqual(@as(u32, 7), slim_types.slice_never_null(1)[0]);
    adapter.free_types(u32, slim_types, 1, {});
    adapter.free_types(u32, values, 3, {});

    const aligned_bytes = try expectAllocation(adapter.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 48, {}));
    for (aligned_bytes.slice_never_null(48), 0..) |*byte, i| byte.* = @intCast(i);
    const aligned_bytes_c = A.ConstPointerU8Align(ADAPTER_ALIGN_64_POW2).new_from(aligned_bytes.slice_never_null(48).ptr);

    const cloned_aligned_bytes = try expectAllocation(adapter.clone_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_bytes_c, 48, {}));
    try testing.expectEqualSlices(u8, aligned_bytes.slice_never_null(48), cloned_aligned_bytes.slice_never_null(48));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(cloned_aligned_bytes.slice_never_null(48).ptr) % 64);
    adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, cloned_aligned_bytes, 48, {});

    const cloned_aligned_custom = try expectAllocation(adapter.clone_bytes_with_align_custom_data_len(ADAPTER_ALIGN_64_POW2, aligned_bytes_c, 48, 8, {}));
    try testing.expectEqualSlices(u8, aligned_bytes.slice_never_null(48)[0..8], cloned_aligned_custom.slice_never_null(48)[0..8]);
    adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, cloned_aligned_custom, 48, {});

    const slim_aligned = try expectAllocation(adapter.slim_clone_bytes_with_align_custom_data_len(ADAPTER_ALIGN_64_POW2, aligned_bytes_c, 48, 8, {}));
    try testing.expectEqualSlices(u8, aligned_bytes.slice_never_null(48)[0..8], slim_aligned.slice_never_null(8));
    adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, slim_aligned, 8, {});
    adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned_bytes, 48, {});

    const AlignedU32 = struct { value: u32 align(64) };
    const aligned_values = try expectAllocation(adapter.alloc_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, 3, {}));
    aligned_values.slice_never_null(3)[0].value = 0xBEEF;
    const aligned_values_c = A.ConstPointerAlign(AlignedU32, ADAPTER_ALIGN_64_POW2).new_from(aligned_values.slice_never_null(3).ptr);

    const cloned_aligned_types = try expectAllocation(adapter.clone_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values_c, 3, {}));
    try testing.expectEqual(@as(u32, 0xBEEF), cloned_aligned_types.slice_never_null(3)[0].value);
    adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, cloned_aligned_types, 3, {});

    const cloned_aligned_types_custom = try expectAllocation(adapter.clone_types_with_align_custom_data_len(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values_c, 3, 1, {}));
    try testing.expectEqual(@as(u32, 0xBEEF), cloned_aligned_types_custom.slice_never_null(3)[0].value);
    adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, cloned_aligned_types_custom, 3, {});

    const slim_aligned_types = try expectAllocation(adapter.slim_clone_types_with_align_custom_data_len(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values_c, 3, 1, {}));
    try testing.expectEqual(@as(usize, 1), slim_aligned_types.slice_never_null(1).len);
    try testing.expectEqual(@as(u32, 0xBEEF), slim_aligned_types.slice_never_null(1)[0].value);
    adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, slim_aligned_types, 1, {});
    adapter.free_types_with_align(ADAPTER_ALIGN_64_POW2, AlignedU32, aligned_values, 3, {});
}

test "AllocatorAdapter -> cached source create, destroy, and clone-one families" {
    const adapter = CachedAdapter.new(testing.allocator);
    const A = CachedAdapter;

    const created = try expectAllocation(adapter.create(u64, {}));
    created.ptr().* = 0x1234_5678_9ABC_DEF0;
    const cloned_one = try expectAllocation(adapter.clone_one(u64, A.ConstPointer(u64).new_from(@as([*]const u64, @ptrCast(created.ptr()))), {}));
    try testing.expectEqual(@as(u64, 0x1234_5678_9ABC_DEF0), cloned_one.ptr().*);
    try testing.expect(@intFromPtr(cloned_one.ptr()) != @intFromPtr(created.ptr()));
    adapter.destroy(u64, cloned_one, {});
    adapter.destroy(u64, created, {});

    const created_aligned = try expectAllocation(adapter.create_with_align(ADAPTER_ALIGN_64_POW2, u64, {}));
    created_aligned.ptr().* = 0xF00D;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(created_aligned.ptr()) % 64);
    const cloned_aligned = try expectAllocation(adapter.clone_one_with_align(ADAPTER_ALIGN_64_POW2, u64, A.ConstPointerAlign(u64, ADAPTER_ALIGN_64_POW2).new_from(@as([*]align(64) const u64, @ptrCast(created_aligned.ptr()))), {}));
    try testing.expectEqual(@as(u64, 0xF00D), cloned_aligned.ptr().*);
    adapter.destroy_with_align(ADAPTER_ALIGN_64_POW2, u64, cloned_aligned, {});
    adapter.destroy_with_align(ADAPTER_ALIGN_64_POW2, u64, created_aligned, {});

    const native_created = adapter.create_native(u64, {}) orelse return error.OutOfMemory;
    native_created.* = 0xDEAD;
    const native_cloned = adapter.clone_one_native(u64, native_created, {}) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u64, 0xDEAD), native_cloned.*);
    adapter.destroy_native(u64, native_cloned, {});
    adapter.destroy_native(u64, native_created, {});

    const native_aligned_created = adapter.create_with_align_native(ADAPTER_ALIGN_64, u64, {}) orelse return error.OutOfMemory;
    native_aligned_created.* = 0xBEEF;
    try testing.expectEqual(@as(usize, 0), @intFromPtr(native_aligned_created) % 64);
    const native_aligned_cloned = adapter.clone_one_with_align_native(ADAPTER_ALIGN_64, u64, native_aligned_created, {}) orelse return error.OutOfMemory;
    try testing.expectEqual(@as(u64, 0xBEEF), native_aligned_cloned.*);
    adapter.destroy_with_align_native(ADAPTER_ALIGN_64, u64, native_aligned_cloned, {});
    adapter.destroy_with_align_native(ADAPTER_ALIGN_64, u64, native_aligned_created, {});
}

test "AllocatorAdapter -> cached source realloc to zero and raw/native realloc" {
    const adapter = CachedAdapter.new(testing.allocator);

    const fresh = try expectAllocation(adapter.alloc_bytes(128, {}));
    fillSlice(fresh.slice_never_null(128), 0x9C);
    // Reallocating to zero frees the block in place and returns the same
    // zero-length pointer. It must not be freed a second time.
    const emptied = adapter.realloc_bytes(fresh, 128, 0, {});
    try testing.expect(!emptied.is_null());
    try testing.expectEqual(@as(usize, 0), emptied.slice_never_null(0).len);

    const reused = try expectAllocation(adapter.alloc_bytes(128, {}));
    fillSlice(reused.slice_never_null(128), 0x9D);
    adapter.free_bytes(reused, 128, {});

    const raw_mem = try expectAllocation(adapter.alloc_raw(32, PowerOf2._8, {}));
    fillSlice(raw_mem.slice_never_null(32), 0x8A);
    const raw_grown = try expectAllocation(adapter.realloc_raw(raw_mem, 32, 32, 512, PowerOf2._8, {}));
    try expectFilled(raw_grown.slice_never_null(512)[0..32], 0x8A);
    adapter.free_raw(raw_grown, 512, PowerOf2._8, {});

    const native_mem = adapter.alloc_bytes_native(32, {}) orelse return error.OutOfMemory;
    fillSlice(native_mem[0..32], 0x5D);
    const native_grown = adapter.realloc_bytes_native(native_mem[0..32], 256, {}) orelse return error.OutOfMemory;
    try expectFilled(native_grown[0..32], 0x5D);
    adapter.free_bytes_native(native_grown[0..256], {});
}

test "AllocatorAdapter -> never-allocates source refuses allocations" {
    const adapter = NeverAdapter{};
    var buf: [16]u8 = @splat(0);
    const ptr = NeverAdapter.PointerU8.new_from(@as([*]u8, @ptrCast(&buf)));
    const cptr = NeverAdapter.ConstPointerU8.new_from(@as([*]const u8, @ptrCast(&buf)));

    try testing.expect(adapter.alloc_raw(16, PowerOf2._1, {}).is_null());
    try testing.expect(adapter.alloc_bytes(16, {}).is_null());
    try testing.expect(adapter.alloc_types(u8, 16, {}).is_null());
    try testing.expect(adapter.create(u64, {}).is_null());
    try testing.expect(!adapter.resize_raw(ptr, 16, 32, PowerOf2._1, {}));
    try testing.expect(!adapter.resize_bytes(ptr, 16, 32, {}));
    try testing.expect(adapter.remap_raw(ptr, 16, 32, PowerOf2._1, {}).is_null());
    try testing.expect(adapter.remap_bytes(ptr, 16, 32, {}).is_null());
    try testing.expect(adapter.realloc_bytes(ptr, 16, 32, {}).is_null());
    try testing.expect(adapter.clone_bytes(cptr, 16, {}).is_null());
    adapter.free_raw(ptr, 16, PowerOf2._1, {});
    adapter.free_bytes(ptr, 16, {});

    try testing.expectError(error.OutOfMemory, NeverAdapter.interface().alloc(u8, 8));
}

test "AllocatorAdapter -> passed source takes the allocator per call and exposes a passed interface adapter" {
    const adapter = PassedAdapter{};

    const bytes = try expectAllocation(adapter.alloc_bytes(24, testing.allocator));
    fillSlice(bytes.slice_never_null(24), 0xAB);

    const grown = try expectAllocation(adapter.realloc_bytes(bytes, 24, 128, testing.allocator));
    try expectFilled(grown.slice_never_null(128)[0..24], 0xAB);
    adapter.free_bytes(grown, 128, testing.allocator);

    const values = try expectAllocation(adapter.alloc_types(u64, 2, testing.allocator));
    {
        const s = values.slice_never_null(2);
        s[0] = 11;
        s[1] = 22;
    }
    adapter.free_types(u64, values, 2, testing.allocator);

    const aligned = try expectAllocation(adapter.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 16, testing.allocator));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.slice_never_null(16).ptr) % 64);
    adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, aligned, 16, testing.allocator);

    const created = try expectAllocation(adapter.create(u32, testing.allocator));
    created.ptr().* = 77;
    try testing.expectEqual(@as(u32, 77), created.ptr().*);
    adapter.destroy(u32, created, testing.allocator);

    var iface_adapter = adapter.passed_source_interface_adapter(testing.allocator);
    try exerciseAdapterAllocator(iface_adapter.interface());
}

test "AllocatorAdapter -> comptime allocator interface pointer" {
    const adapter = ComptimeIfaceAdapter{};

    const bytes = try expectAllocation(adapter.alloc_bytes(32, {}));
    fillSlice(bytes.slice_never_null(32), 0xCD);
    try expectFilled(bytes.slice_never_null(32), 0xCD);
    adapter.free_bytes(bytes, 32, {});

    const values = try expectAllocation(adapter.alloc_types(u32, 2, {}));
    {
        const s = values.slice_never_null(2);
        s[0] = 1;
        s[1] = 2;
    }
    adapter.free_types(u32, values, 2, {});
}

test "AllocatorAdapter -> compliant global allocator native and wrapper sources" {
    global_native_alloc_backing = testing.allocator;

    const native_adapter = GlobalNativeAdapter{};
    const native_bytes = try expectAllocation(native_adapter.alloc_bytes(32, {}));
    fillSlice(native_bytes.slice_never_null(32), 0x5A);
    const native_grown = try expectAllocation(native_adapter.realloc_bytes(native_bytes, 32, 256, {}));
    try expectFilled(native_grown.slice_never_null(256)[0..32], 0x5A);
    native_adapter.free_bytes(native_grown, 256, {});

    const created = try expectAllocation(native_adapter.create(u32, {}));
    created.ptr().* = 0x1234;
    native_adapter.destroy(u32, created, {});

    global_wrapped_alloc_backing = testing.allocator;

    const wrapped_adapter = GlobalWrappedAdapter{};
    const wrapped_bytes = try expectAllocation(wrapped_adapter.alloc_bytes(32, {}));
    fillSlice(wrapped_bytes.slice_never_null(32), 0xA5);
    const wrapped_grown = try expectAllocation(wrapped_adapter.realloc_bytes(wrapped_bytes, 32, 256, {}));
    try expectFilled(wrapped_grown.slice_never_null(256)[0..32], 0xA5);
    wrapped_adapter.free_bytes(wrapped_grown, 256, {});

    const promoted = try expectAllocation(wrapped_adapter.alloc_bytes_with_align(ADAPTER_ALIGN_64_POW2, 24, {}));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(promoted.slice_never_null(24).ptr) % 64);
    wrapped_adapter.free_bytes_with_align(ADAPTER_ALIGN_64_POW2, promoted, 24, {});
}

test "AllocatorAdapter -> static resolver pointer source stays in wrapper form" {
    resolver_alloc_state = .{};
    const adapter = ResolverCachedAdapter.new(&resolver_alloc_state);

    try testing.expect(!ResolverCachedAdapter.POINTER_SOURCE_IS_NATIVE);
    try testing.expect(ResolverCachedAdapter.POINTER_SOURCE == .STATIC_RESOLVER);

    const bytes = try expectAllocation(adapter.alloc_bytes(32, {}));
    fillSlice(bytes.slice_never_null(32), 0x77);
    try expectFilled(bytes.slice_never_null(32), 0x77);

    // The wrapper allocator always refuses in-place resize and remap, so this
    // realloc must go through alloc + memcopy + free while still using handles.
    const grown = try expectAllocation(adapter.realloc_bytes(bytes, 32, 64, {}));
    try expectFilled(grown.slice_never_null(64)[0..32], 0x77);
    adapter.free_bytes(grown, 64, {});

    const values = try expectAllocation(adapter.alloc_types(u32, 4, {}));
    values.slice_never_null(4)[0] = 0xABCD;
    values.slice_never_null(4)[3] = 0x1234;
    try testing.expectEqual(@as(u32, 0xABCD), values.slice_never_null(4)[0]);
    try testing.expectEqual(@as(u32, 0x1234), values.slice_never_null(4)[3]);
    adapter.free_types(u32, values, 4, {});

    const aligned = try expectAllocation(adapter.alloc_bytes_with_align(PowerOf2._64, 16, {}));
    try testing.expectEqual(@as(usize, 0), @intFromPtr(aligned.slice_never_null(16).ptr) % 64);
    fillSlice(aligned.slice_never_null(16), 0x66);
    try expectFilled(aligned.slice_never_null(16), 0x66);
    adapter.free_bytes_with_align(PowerOf2._64, aligned, 16, {});

    const cloned = try expectAllocation(adapter.clone_bytes(bytes.to_const(), 32, {}));
    try expectFilled(cloned.slice_never_null(32), 0x77);
    adapter.free_bytes(cloned, 32, {});
}

test "AllocatorAdapter -> ListSlice stores the matching Pointer wrapper" {
    const Item = struct { a: u32, b: u16, c: u8 };
    const SOURCE = AllocSource.compliant_instantiated_allocator_cached_ptr(ResolverLocalAlloc);
    const FlatList = Root.ListSlice.ListFullDefinition(u32, u32, .WHOLE_STRUCTS, .SERIAL_INDEXES, .OWNED_ALLOCATED, SOURCE);
    const SplitList = Root.ListSlice.ListFullDefinition(Item, u32, .SPLIT_FIELDS, .SERIAL_INDEXES, .OWNED_ALLOCATED, SOURCE);

    // The root field must be a wrapper tied to the allocator's pointer source.
    try testing.expect(@TypeOf((FlatList{}).root_ptr) == FlatList.RootPtr);
    try testing.expect(FlatList.RootPtr == ResolverCachedAdapter.Pointer(u32));
    try testing.expect(SplitList.RootPtr == ResolverCachedAdapter.PointerAlign(u8, PowerOf2.align_of_type(Item)));
    try testing.expect(FlatList.RootPtr.USE_STATIC_RESOLVER);
    try testing.expect(SplitList.RootPtr.USE_STATIC_RESOLVER);

    resolver_alloc_state = .{};
    var flat = FlatList.allocate_new(4, &resolver_alloc_state);
    defer flat.free_if_non_zero({});

    flat.append_one(10, {});
    flat.append_one(20, {});
    flat.append_one(30, {});
    flat.append_one(40, {});
    flat.append_one(50, {}); // forces a growth + copy through the resolver
    try testing.expectEqual(@as(u32, 5), flat.get_len());
    try testing.expectEqual(@as(u32, 10), flat.get(0));
    try testing.expectEqual(@as(u32, 50), flat.get(4));
    flat.set(2, 99);
    try testing.expectEqual(@as(u32, 99), flat.get(2));

    flat.insert_one(1, 15, {});
    try testing.expectEqual(@as(u32, 15), flat.get(1));
    flat.swap(0, 5);
    try testing.expectEqual(@as(u32, 50), flat.get(0));
    try testing.expectEqual(@as(u32, 10), flat.get(5));
    flat.reverse_range(0, flat.get_len());
    try testing.expectEqual(@as(u32, 10), flat.get(0));
    try testing.expectEqual(@as(u32, 50), flat.get(5));

    // Keep the bump pointer going: resolver free is a no-op, so reusing the
    // state here without a reset guarantees the two lists never overlap.
    var split = SplitList.allocate_new(2, &resolver_alloc_state);
    defer split.free_if_non_zero({});

    split.append_one(.{ .a = 1, .b = 2, .c = 3 }, {});
    split.append_one(.{ .a = 4, .b = 5, .c = 6 }, {});
    split.append_one(.{ .a = 7, .b = 8, .c = 9 }, {});
    const second = split.get(1);
    try testing.expectEqual(@as(u32, 4), second.a);
    try testing.expectEqual(@as(u16, 5), second.b);
    try testing.expectEqual(@as(u8, 6), second.c);
    split.set(1, .{ .a = 40, .b = 50, .c = 60 });
    try testing.expectEqual(@as(u32, 40), split.get(1).a);
    split.swap(0, 2);
    try testing.expectEqual(@as(u32, 7), split.get(0).a);
    split.reverse_range(0, split.get_len());
    try testing.expectEqual(@as(u32, 1), split.get(0).a);
    split.memset_range(.{ .a = 0, .b = 0, .c = 0 }, 0, split.get_len());
    try testing.expectEqual(@as(u32, 0), split.get(2).a);
}

test "AllocatorAdapter -> compliant instantiated sources expose the right pointer-source path" {
    // Native source: the adapter takes the `*_raw_native` path.
    var native_state = NativeLocalAlloc{ .backing = testing.allocator };
    {
        const adapter = NativeCachedAdapter.new(&native_state);
        const bytes = try expectAllocation(adapter.alloc_bytes(32, {}));
        fillSlice(bytes.slice_never_null(32), 0x11);
        const grown = try expectAllocation(adapter.realloc_bytes(bytes, 32, 128, {}));
        try expectFilled(grown.slice_never_null(128)[0..32], 0x11);
        adapter.free_bytes(grown, 128, {});
    }

    // Wrapper source: the adapter takes the `*_raw_wrapper` path.
    var wrapped_state = WrappedLocalAlloc{ .backing = testing.allocator };
    {
        const adapter = WrappedCachedAdapter.new(&wrapped_state);
        const bytes = try expectAllocation(adapter.alloc_bytes(32, {}));
        fillSlice(bytes.slice_never_null(32), 0x22);
        const grown = try expectAllocation(adapter.realloc_bytes(bytes, 32, 128, {}));
        try expectFilled(grown.slice_never_null(128)[0..32], 0x22);
        adapter.free_bytes(grown, 128, {});
    }

    // Passed pointer mode for both source styles.
    {
        const adapter = NativePassedAdapter{};
        const bytes = try expectAllocation(adapter.alloc_bytes(16, &native_state));
        fillSlice(bytes.slice_never_null(16), 0x33);
        adapter.free_bytes(bytes, 16, &native_state);

        var iface_adapter = adapter.passed_source_interface_adapter(&native_state);
        try exerciseAdapterAllocator(iface_adapter.interface());
    }
    {
        const adapter = WrappedPassedAdapter{};
        const bytes = try expectAllocation(adapter.alloc_bytes(16, &wrapped_state));
        fillSlice(bytes.slice_never_null(16), 0x44);
        adapter.free_bytes(bytes, 16, &wrapped_state);

        var iface_adapter = adapter.passed_source_interface_adapter(&wrapped_state);
        try exerciseAdapterAllocator(iface_adapter.interface());
    }

    // Comptime pointer mode for both source styles.
    native_comptime_alloc_state = .{ .backing = testing.allocator };
    {
        const adapter = NativeComptimeAdapter{};
        const bytes = try expectAllocation(adapter.alloc_bytes(16, {}));
        fillSlice(bytes.slice_never_null(16), 0x55);
        adapter.free_bytes(bytes, 16, {});
    }
    wrapped_comptime_alloc_state = .{ .backing = testing.allocator };
    {
        const adapter = WrappedComptimeAdapter{};
        const bytes = try expectAllocation(adapter.alloc_bytes(16, {}));
        fillSlice(bytes.slice_never_null(16), 0x66);
        adapter.free_bytes(bytes, 16, {});
    }
}
