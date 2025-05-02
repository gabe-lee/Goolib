const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const math = std.math;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const ArrayList = std.ArrayListUnmanaged;
const Type = std.builtin.Type;

const Root = @import("./_root.zig");

const AllocErrorBehavior = Root.CommonTypes.AllocErrorBehavior;
const GrowthModel = Root.CommonTypes.GrowthModel;
const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
const Compare = Root.Compare;

pub const ListOptionsBase = struct {
    element_type: type,
    alignment: ?u29 = null,
    alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
    growth_model: GrowthModel = .GROW_BY_50_PERCENT_WITH_ATOMIC_PADDING,
    index_type: type = usize,
    secure_wipe_bytes: bool = false,
    reserve_sentinel_space: bool = false,
};

pub fn ListOptionsExtended(comptime base_options: ListOptionsBase) type {
    return struct {
        default_sorting_algorithm: SortAlgorithm = .QUICK_SORT_PIVOT_MEDIAN_OF_3,
        default_sorting_compare_func: *const fn (a: *const base_options.element_type, b: *const base_options.element_type) Compare.Order = Compare.numeric_order_else_always_equal(base_options.element_type),
    };
}

/// A struct containing all common operations used internally for the various List
/// paradigms (Manual, Cached, Static)
///
/// These are not intended for normal use, but are provided in this public namespace
/// regardless
pub const Internal = struct {
    pub fn slice(comptime List: type, self: List) List.Slice {
        return self.ptr[0..self.len];
    }

    pub fn array_ptr(comptime List: type, self: List, start: List.Idx, comptime length: List.Idx) *[length]List.Elem {
        assert(start + length <= self.len);
        return self.ptr[start..self.len][0..length];
    }

    pub fn vector_ptr(comptime List: type, self: List, start: List.Idx, comptime length: List.Idx) *@Vector(length, List.Elem) {
        assert(start + length <= self.len);
        return self.ptr[start..self.len][0..length];
    }

    pub fn slice_with_sentinel(comptime List: type, self: List, comptime sentinel: List.Elem) List.SentinelSlice(List.Elem) {
        assert(self.len < self.cap);
        self.ptr[self.len] = sentinel;
        return self.ptr[0..self.len :sentinel];
    }

    pub fn slice_full_capacity(comptime List: type, self: List) List.Slice {
        return self.ptr[0..self.cap];
    }

    pub fn slice_unused_capacity(comptime List: type, self: List) []List.Elem {
        return self.ptr[self.len..self.cap];
    }

    pub fn set_len(comptime List: type, self: *List, new_len: List.Idx) void {
        assert(new_len <= self.cap);
        if (List.SECURE_WIPE and new_len < self.len) {
            crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
        }
        self.len = new_len;
    }

    pub fn new_empty(comptime List: type) if (List.RESERVE_SENTINEL and List.RETURN_ERRORS) List.Error!List else List {
        if (List.RESERVE_SENTINEL) return List.new_with_capacity(1);
        return List.EMPTY;
    }

    pub fn new_with_capacity(comptime List: type, capacity: List.Idx) if (List.RETURN_ERRORS) List.Error!List else List {
        var self = List.EMPTY;
        if (List.RETURN_ERRORS) {
            try self.ensure_total_capacity_exact(capacity);
        } else {
            self.ensure_total_capacity_exact(capacity);
        }
        return self;
    }

    pub fn clone(comptime List: type, self: List) if (List.RETURN_ERRORS) List.Error!List else List {
        var new_list = if (List.RETURN_ERRORS) try List.new_with_capacity(self.cap) else List.new_with_capacity(self.cap);
        new_list.append_slice_assume_capacity(self.ptr[0..self.len]);
        return new_list;
    }

    pub fn to_owned_slice(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List.Slice else List.Slice {
        const old_memory = self.ptr[0..self.cap];
        if (alloc.remap(old_memory, self.len)) |new_items| {
            self.* = List.EMPTY;
            return new_items;
        }
        const new_memory = alloc.alignedAlloc(List.Elem, List.ALIGN, self.len) catch |err| return List.handle_alloc_error(err);
        @memcpy(new_memory, self.ptr[0..self.len]);
        self.clear_and_free();
        return new_memory;
    }

    pub fn to_owned_slice_sentinel(comptime List: type, self: *List, comptime sentinel: List.Elem) if (List.RETURN_ERRORS) List.Error!List.SentinelSlice(sentinel) else List.SentinelSlice(sentinel) {
        //CHECKPOINT
    }
};

pub fn define_manually_managed_list_type(comptime base_options: ListOptionsBase, comptime ex_options: ListOptionsExtended(base_options)) type {
    const opt = comptime check: {
        var opts = base_options;
        if (opts.alignment) |a| {
            if (a == @alignOf(opts.T)) {
                opts.alignment = null;
            }
        }
        break :check opts;
    };
    if (opt.alignment) |a| {
        if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
    }
    if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
    return extern struct {
        ptr: Ptr = UNINIT_PTR,
        len: Idx = 0,
        cap: Idx = 0,

        pub const COMPARE_PACKAGE = Compare.type_package(Elem, ex_options.default_sorting_compare_func);
        pub const ALIGN = base_options.alignment;
        pub const DEFAULT_SORT = ex_options.default_sorting_algorithm;
        pub const PIVOT = Root.Quicksort.Pivot.from_sort_algorithm(ex_options.default_sorting_algorithm);
        pub const ALLOC_ERROR_BEHAVIOR = base_options.alloc_error_behavior;
        pub const GROWTH = base_options.growth_model;
        pub const RETURN_ERRORS = base_options.alloc_error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
        pub const SECURE_WIPE = base_options.secure_wipe_bytes;
        pub const RESERVE_SENTINEL = base_options.reserve_sentinel_space;
        pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
        pub const EMPTY = List{
            .ptr = UNINIT_PTR,
            .len = 0,
            .cap = 0,
        };

        const List = @This();
        pub const Elem = base_options.element_type;
        pub const Idx = base_options.index_type;
        pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
        pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
        pub fn SentinelSlice(comptime sentinel: Elem) type {
            return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
        }
        pub const Error = Allocator.Error;

        pub inline fn slice(self: List) Slice {
            return Internal.slice(List, self);
        }

        pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
            return Internal.array_ptr(List, self, start, length);
        }

        pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
            return Internal.vector_ptr(List, self, start, length);
        }

        pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
            return Internal.slice_with_sentinel(List, self, sentinel);
        }

        pub inline fn slice_full_capacity(self: List) Slice {
            return Internal.slice_full_capacity(List, self);
        }

        pub inline fn slice_unused_capacity(self: List) []Elem {
            Internal.slice_unused_capacity(List, self);
        }

        pub inline fn set_len(self: *List, new_len: usize) void {
            return Internal.set_len(List, self, new_len);
        }

        pub inline fn new_empty() if (RESERVE_SENTINEL and RETURN_ERRORS) Error!List else List {
            return Internal.new_empty(List);
        }

        pub inline fn new_with_capacity(capacity: Idx) if (RETURN_ERRORS) Error!List else List {
            return Internal.new_with_capacity(List, capacity);
        }

        pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
            return Internal.clone(List, self);
        }

        pub inline fn to_owned_slice(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!Slice else Slice {
            return Internal.to_owned_slice(List, self, alloc);
        }

        pub fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
            if (RETURN_ERRORS) {
                try self.ensure_total_capacity_exact(self.len + 1);
            } else {
                self.ensure_total_capacity_exact(self.len + 1);
            }
            self.append_assume_capacity(sentinel);
            const result: Slice = if (RETURN_ERRORS) try self.to_owned_slice() else self.to_owned_slice();
            return result[0 .. result.len - 1 :sentinel];
        }

        pub fn from_owned_slice(from_slice: Slice) List {
            return List{
                .ptr = from_slice.ptr,
                .len = from_slice.len,
                .cap = from_slice.len,
            };
        }

        pub fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
            return List{
                .ptr = from_slice.ptr,
                .len = from_slice.len,
                .cap = from_slice.len + 1,
            };
        }

        pub fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
            if (RETURN_ERRORS) {
                try self.ensure_unused_capacity(1);
            } else {
                self.ensure_unused_capacity(1);
            }
            return self.insert_slot_assume_capacity(idx);
        }

        pub fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
            assert(idx <= self.len);
            mem.copyBackwards(Elem, self.ptr[idx + 1 .. self.len + 1], self.ptr[idx..self.len]);
            return self.ptr + idx;
        }

        pub fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
            const ptr = if (RETURN_ERRORS) try self.insert_slot(idx) else self.insert_slot(idx);
            ptr.* = item;
        }

        pub fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
            const ptr = self.insert_slot_assume_capacity(idx);
            ptr.* = item;
        }

        pub fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            if (RETURN_ERRORS) {
                try self.ensure_unused_capacity(count);
            } else {
                self.ensure_unused_capacity(count);
            }
            return self.insert_many_slots_assume_capacity(idx, count);
        }

        pub fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
            assert(idx <= self.len);
            mem.copyBackwards(Elem, self.ptr[idx + count .. self.len + count], self.ptr[idx..self.len]);
            return self.ptr[idx .. idx + count];
        }

        pub fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.insert_many_slots(idx, @intCast(items.len)) else self.insert_slot(idx, @intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn insert_slice_assume_capacity(self: *List, idx: usize, items: []const Elem) void {
            const slots = self.insert_many_slots_assume_capacity(idx, @intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            if (new_items.len > length) {
                const additional_needed = new_items.len - length;
                if (RETURN_ERRORS) {
                    try self.ensure_unused_capacity(additional_needed);
                } else {
                    self.ensure_unused_capacity(additional_needed);
                }
            }
            self.replace_range_assume_capacity(start, length, new_items);
        }

        pub fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
            const end_of_range = start + length;
            assert(end_of_range <= self.len);
            const range = self.ptr[start..end_of_range];
            if (range.len == new_items.len)
                @memcpy(range[0..new_items.len], new_items)
            else if (range.len < new_items.len) {
                const within_range = new_items[0..range.len];
                const leftover = new_items[range.len..];
                @memcpy(range[0..within_range.len], within_range);
                const new_slots = self.insert_many_slots_assume_capacity(end_of_range, leftover.len);
                @memcpy(new_slots, leftover);
            } else {
                const unused_slots = range.len - new_items.len;
                @memcpy(range[0..new_items.len], new_items);
                std.mem.copyForwards(Elem, self.ptr[end_of_range - unused_slots .. self.len], self.ptr[end_of_range..self.len]);
                if (SECURE_WIPE) {
                    crypto.secureZero(Elem, self.ptr[self.len - unused_slots .. self.len]);
                }
                self.len -= unused_slots;
            }
        }

        pub fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
            const slot = if (RETURN_ERRORS) try self.append_slot() else self.append_slot();
            slot.* = item;
        }

        pub fn append_assume_capacity(self: *List, item: Elem) void {
            const slot = self.append_slot_assume_capacity();
            slot.* = item;
        }

        pub fn remove(self: *List, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.delete(idx);
            return val;
        }

        pub fn swap_remove(self: *List, idx: Idx) Elem {
            const val: Elem = self.ptr[idx];
            self.swap_delete(idx);
            return val;
        }

        pub fn delete(self: *List, idx: Idx) void {
            assert(idx < self.len);
            std.mem.copyForwards(Elem, self.ptr[idx..self.len], self.ptr[idx + 1 .. self.len]);
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn delete_range(self: *List, start: Idx, length: Idx) void {
            const end_of_range = start + length;
            assert(end_of_range <= self.len);
            std.mem.copyForwards(Elem, self.ptr[start..self.len], self.ptr[end_of_range..self.len]);
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - length .. self.len]);
            }
            self.len -= length;
        }

        pub fn swap_delete(self: *List, idx: Idx) void {
            assert(idx < self.len);
            self.ptr[idx] = self.ptr[self.list.items.len - 1];
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[self.len - 1 .. self.len]);
            }
            self.len -= 1;
        }

        pub fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(@intCast(items.len)) else self.append_many_slots(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(@intCast(items.len)) else self.append_many_slots(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
            const slots = self.append_many_slots_assume_capacity(@intCast(items.len));
            @memcpy(slots, items);
        }

        pub const WriterHandle = struct {
            list: *List,
        };

        pub const Writer = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write);

        pub fn get_writer(self: *List) Writer {
            return Writer{ .context = .{ .list = self } };
        }

        fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
            try handle.list.append_slice(bytes);
            return bytes.len;
        }

        pub const WriterNoGrow = if (Elem != u8)
            @compileError("The Writer interface is only defined for child type `u8` " ++
                "but the given type is " ++ @typeName(Elem))
        else
            std.io.Writer(WriterHandle, Allocator.Error, write_no_grow);

        pub fn get_writer_no_grow(self: *List) WriterNoGrow {
            return WriterNoGrow{ .context = .{ .list = self } };
        }

        fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
            const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
            if (bytes.len > available_capacity) return error.OutOfMemory;
            handle.list.append_slice_assume_capacity(bytes);
            return bytes.len;
        }

        pub fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
            const slots = if (RETURN_ERRORS) try self.append_many_slots(count) else self.append_many_slots(count);
            @memset(slots, value);
        }

        pub fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
            const slots = self.append_many_slots_assume_capacity(count);
            @memset(slots, value);
        }

        pub fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
            if (RETURN_ERRORS) {
                try self.ensure_total_capacity(new_len);
            } else {
                self.ensure_total_capacity(new_len);
            }
            if (SECURE_WIPE and new_len < self.len) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn shrink_and_free(self: *List, new_len: Idx, alloc: Allocator) void {
            assert(new_len <= self.len);

            if (@sizeOf(Elem) == 0) {
                self.items.len = new_len;
                return;
            }

            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_len)) |new_items| {
                self.ptr = new_items.ptr;
                self.len = new_items.len;
                self.cap = new_items.len;
                return;
            }

            const new_memory = alloc.alignedAlloc(Elem, ALIGN, new_len) catch |err| switch (err) {
                error.OutOfMemory => {
                    self.len = new_len;
                    return;
                },
            };

            @memcpy(new_memory, self.ptr[0..new_len]);
            alloc.free(old_memory);
            self.ptr = new_memory.ptr;
            self.len = new_memory.len;
            self.cap = new_memory.len;
        }

        pub fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
            assert(new_len <= self.len);
            if (SECURE_WIPE) {
                crypto.secureZero(Elem, self.ptr[new_len..self.len]);
            }
            self.len = new_len;
        }

        pub fn clear_retaining_capacity(self: *List) void {
            if (SECURE_WIPE) {
                std.crypto.secureZero(Elem, self.ptr[0..self.len]);
            }
            self.len = 0;
        }

        pub fn clear_and_free(self: *List, alloc: Allocator) void {
            if (SECURE_WIPE) {
                std.crypto.secureZero(Elem, self.ptr[0..self.len]);
            }
            alloc.free(self.ptr[0..self.cap]);
            self.ptr = UNINIT_PTR;
            self.len = 0;
            self.cap = 0;
        }

        pub fn ensure_total_capacity(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (self.cap >= new_capacity) return;
            return self.ensure_total_capacity_exact(true_capacity_for_grow(self.cap, new_capacity), alloc);
        }

        pub fn ensure_total_capacity_exact(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
            if (@sizeOf(Elem) == 0) {
                self.cap = math.maxInt(Idx);
                return;
            }

            if (self.cap >= new_capacity) return;

            if (new_capacity < self.len) {
                if (SECURE_WIPE) crypto.secureZero(Elem, self.ptr[new_capacity..self.len]);
                self.len = new_capacity;
            }

            const old_memory = self.ptr[0..self.cap];
            if (alloc.remap(old_memory, new_capacity)) |new_memory| {
                self.ptr = new_memory.ptr;
                self.cap = @intCast(new_memory.len);
            } else {
                const new_memory = alloc.alignedAlloc(Elem, ALIGN, new_capacity) catch |err| return handle_alloc_error(err);
                @memcpy(new_memory[0..self.len], self.ptr[0..self.len]);
                if (SECURE_WIPE) crypto.secureZero(Elem, self.ptr[0..self.len]);
                alloc.free(old_memory);
                self.ptr = new_memory.ptr;
                self.cap = @intCast(new_memory.len);
            }
        }

        pub fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
            const new_total_cap = if (RETURN_ERRORS) try add_or_error(self.len, additional_count) else add_or_error(self.len, additional_count);
            return self.ensure_total_capacity(new_total_cap);
        }

        pub fn expand_to_capacity(self: *List) void {
            self.len = self.cap;
        }

        pub fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
            const new_len = self.len + 1;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len) else self.ensure_total_capacity(new_len);
            return self.append_slot_assume_capacity();
        }

        pub fn append_slot_assume_capacity(self: *List) *Elem {
            assert(self.len < self.cap);
            const idx = self.len;
            self.len += 1;
            return &self.ptr[idx];
        }

        pub fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
            const new_len = self.len + count;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len) else self.ensure_total_capacity(new_len);
            return self.append_many_slots_assume_capacity(count);
        }

        pub fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
            const new_len = self.len + count;
            assert(new_len <= self.cap);
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
            const new_len = self.len + count;
            if (RETURN_ERRORS) try self.ensure_total_capacity(new_len) else self.ensure_total_capacity(new_len);
            return self.append_many_slots_as_array_assume_capacity(count);
        }

        pub fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
            const new_len = self.len + count;
            assert(new_len <= self.cap);
            const prev_len = self.len;
            self.len = new_len;
            return self.ptr[prev_len..][0..count];
        }

        pub fn pop_or_null(self: *List) ?Elem {
            if (self.len == 0) return null;
            return self.pop();
        }

        pub fn pop(self: *List) Elem {
            assert(self.len > 0);
            const new_len = self.len - 1;
            self.len = new_len;
            return self.ptr[new_len];
        }

        pub fn get_last(self: List) Elem {
            assert(self.len > 0);
            return self.ptr[self.len - 1];
        }

        pub fn get_last_or_null(self: List) ?Elem {
            if (self.len == 0) return null;
            return self.get_last();
        }

        fn add_or_error(a: Idx, b: Idx) if (RETURN_ERRORS) error{OutOfMemory}!Idx else Idx {
            if (!RETURN_ERRORS) return a + b;
            const result, const overflow = @addWithOverflow(a, b);
            if (overflow != 0) return error.OutOfMemory;
            return result;
        }

        const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));

        fn true_capacity_for_grow(current: Idx, minimum: Idx) Idx {
            switch (GROWTH) {
                GrowthModel.GROW_EXACT_NEEDED => {
                    return minimum;
                },
                GrowthModel.GROW_EXACT_NEEDED_ATOMIC_PADDING => {
                    return minimum + ATOMIC_PADDING;
                },
                else => {
                    var new = current;
                    while (true) {
                        switch (GROWTH) {
                            GrowthModel.GROW_BY_100_PERCENT => {
                                new +|= new;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_100_PERCENT_WITH_ATOMIC_PADDING => {
                                new +|= new;
                                const new_with_padding = new + ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_50_PERCENT => {
                                new +|= new / 2;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_50_PERCENT_WITH_ATOMIC_PADDING => {
                                new +|= new / 2;
                                const new_with_padding = new + ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            GrowthModel.GROW_BY_25_PERCENT => {
                                new +|= new / 4;
                                if (new >= minimum) return new;
                            },
                            GrowthModel.GROW_BY_25_PERCENT_WITH_ATOMIC_PADDING => {
                                new +|= new / 4;
                                const new_with_padding = new + ATOMIC_PADDING;
                                if (new_with_padding >= minimum) return new_with_padding;
                            },
                            else => unreachable,
                        }
                    }
                },
            }
        }

        pub inline fn sort(self: *List) void {
            self.custom_sort(DEFAULT_SORT);
        }

        pub fn custom_sort(self: *List, comptime algorithm: SortAlgorithm) void {
            if (!CAN_SORT) unreachable;
            if (self.len == 0) return;
            switch (algorithm) {
                // SortAlgorithm.BUBBlE_SORT => {},
                // SortAlgorithm.HEAP_SORT => {},
                SortAlgorithm.QUICK_SORT_PIVOT_FIRST => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.FIRST, self.ptr[0..self.len]),
                SortAlgorithm.QUICK_SORT_PIVOT_LAST => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.LAST, self.ptr[0..self.len]),
                SortAlgorithm.QUICK_SORT_PIVOT_MIDDLE => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.MIDDLE, self.ptr[0..self.len]),
                SortAlgorithm.QUICK_SORT_PIVOT_RANDOM => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.RANDOM, self.ptr[0..self.len]),
                SortAlgorithm.QUICK_SORT_PIVOT_MEDIAN_OF_3 => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.MEDIAN_OF_3, self.ptr[0..self.len]),
                SortAlgorithm.QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM => Root.Algorithms.Quicksort.quicksort(Elem, ORDER_TYPE, ORDER_FUNC, Root.Algorithms.Quicksort.Pivot.MEDIAN_OF_3_RANDOM, self.ptr[0..self.len]),
            }
        }

        fn handle_alloc_error(err: Allocator.Error) if (RETURN_ERRORS) Error else noreturn {
            switch (ALLOC_ERROR_BEHAVIOR) {
                AllocErrorBehavior.ALLOCATION_ERRORS_RETURN_ERROR => return err,
                AllocErrorBehavior.ALLOCATION_ERRORS_PANIC => std.debug.panic("[ErgoList] List's backing allocator failed to allocate memory: Allocator.Error.{s}", .{@errorName(err)}),
                AllocErrorBehavior.ALLOCATION_ERRORS_ARE_UNREACHABLE => unreachable,
            }
        }
    };
}

test "Does it basically work?" {
    const t = std.testing;
    const alloc = std.heap.page_allocator;
    const order = struct {
        fn func(element: *const u8) u8 {
            return element.*;
        }
    };
    const Options = ListOptions{
        .alloc_error_behavior = .ALLOCATION_ERRORS_PANIC,
        .element_type = u8,
        .order_value_type = u8,
        .order_value_func_struct = order,
        .index_type = u32,
        .allocator = &alloc,
    };
    const List = define_list_type(Options);
    var list = List.new_empty();
    list.append('H');
    list.append('e');
    list.append('l');
    list.append('l');
    list.append('o');
    list.append(' ');
    list.append_slice("World!");
    try t.expectEqualStrings("Hello World!", list.slice());
}
