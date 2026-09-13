// //! //TODO Documentation
// //! #### License: Zlib

// // zlib license
// //
// // Copyright (c) 2025, Gabriel Lee Anderson <gla.ander@gmail.com>
// //
// // This software is provided 'as-is', without any express or implied
// // warranty. In no event will the authors be held liable for any damages
// // arising from the use of this software.
// //
// // Permission is granted to anyone to use this software for any purpose,
// // including commercial applications, and to alter it and redistribute it
// // freely, subject to the following restrictions:
// //
// // 1. The origin of this software must not be misrepresented; you must not
// //    claim that you wrote the original software. If you use this software
// //    in a product, an acknowledgment in the product documentation would be
// //    appreciated but is not required.
// // 2. Altered source versions must be plainly marked as such, and must not be
// //    misrepresented as being the original software.
// // 3. This notice may not be removed or altered from any source distribution.

// const build = @import("builtin");
// const std = @import("std");
// const SourceLocation = std.builtin.SourceLocation;
// const mem = std.mem;
// const math = std.math;
// const crypto = std.crypto;
// const Allocator = std.mem.Allocator;
// const ArrayListUnmanaged = std.ArrayListUnmanaged;
// const ArrayList = std.ArrayListUnmanaged;
// const Type = std.builtin.Type;

// const Root = @import("./_root.zig");
// const Assert = Root.Assert;
// const assert_with_reason = Assert.assert_with_reason;
// const FlexSlice = Root.FlexSlice.FlexSlice;
// const Mutability = Root.CommonTypes.Mutability;
// const Quicksort = Root.Quicksort;
// const Pivot = Quicksort.Pivot;
// const InsertionSort = Root.InsertionSort;
// const insertion_sort = InsertionSort.insertion_sort;
// const ErrorBehavior = Root.CommonTypes.ErrorBehavior;
// const GrowthModel = Root.CommonTypes.GrowthModel;
// const SortAlgorithm = Root.CommonTypes.SortAlgorithm;
// const DummyAllocator = Root.DummyAllocator;
// const BinarySearch = Root.BinarySearch;

// pub const ListOptions = struct { element_type: type, alignment: ?u29 = null, error_behavior: ErrorBehavior = .ERRORS_PANIC, growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING, index_type: type = usize, secure_wipe_bytes: bool = false, extra_data_type: ?type = null, implementation_overrides };

// pub fn ListCallbacks(comptime options: ListOptions) type {
//     const Ptr = if (options.alignment) |a| ?[*]align(a) options.element_type else ?[*]options.element_type;
//     const Idx = options.index_type;
//     const Elem = options.element_type;
//     const Extra = if (options.extra_data_type) |ex| ex else void;
//     return struct {
//         on_element_moved: ?*const fn (ptr: *Ptr, len: *Idx, cap: *Idx, extra_data: *Extra, element: *Elem, old_idx: Idx, new_idx: Idx) void = null,
//         on_element_added: ?*const fn (ptr: *Ptr, len: *Idx, cap: *Idx, extra_data: *Extra, element: *Elem, new_idx: Idx) void = null,
//         on_element_removed: ?*const fn (ptr: *Ptr, len: *Idx, cap: *Idx, extra_data: *Extra, element: Elem, old_idx: Idx) void = null,
//         on_list_resized: ?*const fn (ptr: *Ptr, len: *Idx, cap: *Idx, extra_data: *Extra, old_cap: Idx) void = null,
//         on_list_relocated: ?*const fn (ptr: *Ptr, len: *Idx, cap: *Idx, extra_data: *Extra, old_ptr: Ptr) void = null,
//     };
// }

// pub const ListConstants = struct {
//     List: type,
//     Error: type,
//     Elem: type,
//     Ptr: type,
//     Idx: type,
//     Extra: type,
//     Slice: type,
//     NullableSlice: type,
//     FlexSlice: type,
//     ALIGN: ?u29,
//     ERROR_BEHAVIOR: ErrorBehavior,
//     GROWTH: GrowthModel,
//     RETURN_ERRORS: bool,
//     SECURE_WIPE: bool,
//     ATOMIC_PADDING: comptime_int,
//     PTR_FIELD: []const u8,
//     LEN_FIELD: []const u8,
//     CAP_FIELD: []const u8,
//     EXTRA_FIELD: []const u8,
//     fn_on_moved: ?*anyopaque,
//     fn_on_added: ?*anyopaque,
//     fn_on_removed: ?*anyopaque,
//     fn_on_resized: ?*anyopaque,
//     fn_on_relocated: ?*anyopaque,

//     pub inline fn create(comptime LIST: type, comptime ERROR: type, comptime PTR_FIELD: []const u8, comptime LEN_FIELD: []const u8, comptime CAP_FIELD: []const u8, comptime EXTRA_FIELD: []const u8, comptime OPTIONS: ListOptions, comptime CALLBACKS: ?ListCallbacks(OPTIONS)) ListConstants {
//         return ListConstants{
//             .ALIGN = OPTIONS.alignment,
//             .ERROR_BEHAVIOR = OPTIONS.error_behavior,
//             .GROWTH = OPTIONS.growth_model,
//             .RETURN_ERRORS = OPTIONS.growth_model == .ALLOCATION_ERRORS_RETURN_ERROR,
//             .SECURE_WIPE = OPTIONS.secure_wipe_bytes,
//             .ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(OPTIONS.element_type))),
//             .PTR_FIELD = PTR_FIELD,
//             .LEN_FIELD = LEN_FIELD,
//             .CAP_FIELD = CAP_FIELD,
//             .EXTRA_FIELD = EXTRA_FIELD,
//             .Error = ERROR,
//             .Extra = if (OPTIONS.extra_data_type) |ex| ex else void,
//             .Elem = OPTIONS.element_type,
//             .Idx = OPTIONS.index_type,
//             .Ptr = if (OPTIONS.alignment) |a| ?[*]align(a) OPTIONS.element_type else ?[*]OPTIONS.element_type,
//             .Slice = if (OPTIONS.alignment) |a| []align(a) OPTIONS.element_type else []OPTIONS.element_type,
//             .NullableSlice = if (OPTIONS.alignment) |a| ?[]align(a) OPTIONS.element_type else ?[]OPTIONS.element_type,
//             .List = LIST,
//             .fn_on_moved = if (CALLBACKS) |CALL| CALL.on_element_moved else null,
//             .fn_on_added = if (CALLBACKS) |CALL| CALL.on_element_added else null,
//             .fn_on_removed = if (CALLBACKS) |CALL| CALL.on_element_removed else null,
//             .fn_on_resized = if (CALLBACKS) |CALL| CALL.on_list_resized else null,
//             .fn_on_relocated = if (CALLBACKS) |CALL| CALL.on_list_relocated else null,
//         };
//     }

//     pub inline fn SentinelSlice(comptime self: ListConstants, comptime sentinel: self.Elem) type {
//         return if (self.ALIGN) |a| ([:sentinel]align(a) self.Elem) else [:sentinel]self.Elem;
//     }
//     pub inline fn NullableSentinelSlice(comptime self: ListConstants, comptime sentinel: self.Elem) type {
//         return if (self.ALIGN) |a| (?[:sentinel]align(a) self.Elem) else ?[:sentinel]self.Elem;
//     }
//     pub inline fn MetaListMutable(comptime self: ListConstants) type {
//         return struct {
//             ptr: *self.Ptr,
//             len: *self.Idx,
//             cap: *self.Idx,
//             extra: *self.Extra,

//             pub const on_element_moved: ?*const fn (ptr: *self.Ptr, len: *self.Idx, cap: *self.Idx, extra_data: *self.Extra, element: *self.Elem, old_idx: self.Idx, new_idx: self.Idx) void = @ptrCast(self.fn_on_moved);
//             pub const on_element_added: ?*const fn (ptr: *self.Ptr, len: *self.Idx, cap: *self.Idx, extra_data: *self.Extra, element: *self.Elem, new_idx: self.Idx) void = @ptrCast(self.fn_on_added);
//             pub const on_element_removed: ?*const fn (ptr: *self.Ptr, len: *self.Idx, cap: *self.Idx, extra_data: *self.Extra, element: self.Elem, old_idx: self.Idx) void = @ptrCast(self.fn_on_removed);
//             pub const on_list_resized: ?*const fn (ptr: *self.Ptr, len: *self.Idx, cap: *self.Idx, extra_data: *self.Extra, old_cap: self.Idx) void = @ptrCast(self.fn_on_resized);
//             pub const on_list_relocated: ?*const fn (ptr: *self.Ptr, len: *self.Idx, cap: *self.Idx, extra_data: *self.Extra, old_ptr: self.Ptr) void = @ptrCast(self.fn_on_relocated);
//         };
//     }
//     pub inline fn MetaList(comptime self: ListConstants) type {
//         return struct {
//             ptr: self.Ptr,
//             len: self.Idx,
//             cap: self.Idx,
//         };
//     }
//     pub inline fn meta_list_mutable(comptime self: ListConstants, list: *self.List) MetaListMutable(self) {
//         return MetaListMutable(self){
//             .ptr = &@field(list, self.PTR_FIELD),
//             .len = &@field(list, self.LEN_FIELD),
//             .cap = &@field(list, self.CAP_FIELD),
//         };
//     }
//     pub inline fn meta_list(comptime self: ListConstants, list: self.List) MetaList(self) {
//         return MetaList(self){
//             .ptr = @field(list, self.PTR_FIELD),
//             .len = @field(list, self.LEN_FIELD),
//             .cap = @field(list, self.CAP_FIELD),
//         };
//     }
//     pub inline fn uninit_list(comptime self: ListConstants) self.List {
//         return self.List{
//             .ptr = null,
//             .len = 0,
//             .cap = 0,
//         };
//     }
// };

// const ERR_IOOB_LEN_CAP_SENT = "index out of bounds: len ({d}) >= cap ({d}), in order to make a sentinel slice, at least one extra slot is required between len and cap";
// const ERR_IOOB_START_LEN = "index out of bounds: start + length ({d}) > list.len ({d})";
// const ERR_IOOB_INDEX = "index out of bounds: index ({d}) > list.len ({d})";
// const ERR_OP_NULL_PTR = "attempted to operate on null pointer";
// const ERR_NEW_LEN_CAP = "new length ({d}) is greater than capacity ({d})";

// /// A struct containing all common operations used internally for the various List
// /// paradigms
// ///
// /// These are not intended for normal use, but are provided here for ease of use
// /// when implementing a custom list/collection type
// pub const Impl = struct {
//     fn handle_possible_relocate(comptime L: ListConstants, list: L.MetaListMutable(), old_ptr: L.Ptr) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_list_relocated) |on_relocate| {
//             if (list.ptr.* != old_ptr) {
//                 on_relocate(list.ptr, list.len, list.cap, list.extra, old_ptr);
//             }
//         }
//     }

//     fn handle_relocate(comptime L: ListConstants, list: L.MetaListMutable(), old_ptr: L.Ptr) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_list_relocated) |on_relocate| {
//             on_relocate(list.ptr, list.len, list.cap, list.extra, old_ptr);
//         }
//     }

//     fn handle_moved(comptime L: ListConstants, list: L.MetaListMutable(), old_idx: L.Idx, new_idx: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_element_moved) |on_move| {
//             const elem: *L.Elem = &(list.ptr.*.?[@intCast(new_idx)]);
//             on_move(list.ptr, list.len, list.cap, list.extra, elem, old_idx, new_idx);
//         }
//     }

//     fn handle_added(comptime L: ListConstants, list: L.MetaListMutable(), new_idx: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_element_added) |on_add| {
//             const elem: *L.Elem = &(list.ptr.*.?[@intCast(new_idx)]);
//             on_add(list.ptr, list.len, list.cap, list.extra, elem, new_idx);
//         }
//     }

//     fn handle_range_added(comptime L: ListConstants, list: L.MetaListMutable(), start_idx: L.Idx, end_idx: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_element_added) |on_add| {
//             var i: L.Idx = start_idx;
//             while (i < end_idx) : (i += 1) {
//                 const elem: *L.Elem = &(list.ptr.*.?[@intCast(i)]);
//                 on_add(list.ptr, list.len, list.cap, list.extra, elem, i);
//             }
//         }
//     }

//     fn handle_removed(comptime L: ListConstants, list: L.MetaListMutable(), elem: L.Elem, old_idx: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_element_removed) |on_remove| {
//             on_remove(list.ptr, list.len, list.cap, list.extra, elem, old_idx);
//         }
//     }

//     fn handle_resize(comptime L: ListConstants, list: L.MetaListMutable(), old_cap: L.Id) void {
//         const Meta = comptime L.MetaListMutable();
//         if (Meta.on_list_resized) |on_resize| {
//             on_resize(list.ptr, list.len, list.cap, list.extra, old_cap);
//         }
//     }

//     fn copy_leftward(comptime L: ListConstants, list: L.MetaListMutable(), start_idx: L.Idx, end_idx: L.Idx, shift_by_n: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         var i: L.Idx = start_idx;
//         var ii: L.Idx = i - shift_by_n;
//         while (i < end_idx) {
//             list.ptr.*.?[ii] = list.ptr.*.?[i];
//             if (Meta.on_element_moved) |on_moved| {
//                 on_moved(list.ptr, list.len, list.cap, list.extra, &list.ptr.*.?[ii], i, ii);
//             }
//             i += 1;
//             ii += 1;
//         }
//     }

//     fn copy_rightward(comptime L: ListConstants, list: L.MetaListMutable(), start_idx: L.Idx, end_idx: L.Idx, shift_by_n: L.Idx) void {
//         const Meta = comptime L.MetaListMutable();
//         var i: L.Idx = end_idx - 1;
//         var ii: L.Idx = i + shift_by_n;
//         while (i >= start_idx) {
//             list.ptr.*.?[ii] = list.ptr.*.?[i];
//             if (Meta.on_element_moved) |on_moved| {
//                 on_moved(list.ptr, list.len, list.cap, list.extra, &list.ptr.*.?[ii], i, ii);
//             }
//             if (i == start_idx) break;
//             i -= 1;
//             ii -= 1;
//         }
//     }

//     pub inline fn slice(comptime L: ListConstants, self: L.List) L.Slice {
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         return list.ptr.?[0..@intCast(list.len)];
//     }

//     pub inline fn nullable_slice(comptime L: ListConstants, self: L.List) L.NullableSlice {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return null;
//         return list.ptr.?[0..@intCast(list.len)];
//     }

//     pub inline fn flex_slice(comptime L: ListConstants, self: L.List, comptime mutability: Mutability) FlexSlice(L.Elem, L.Idx, mutability) {
//         const list = L.meta_list(self);
//         return FlexSlice(L.Elem, L.Idx, mutability){
//             .ptr = list.ptr,
//             .len = list.len,
//         };
//     }

//     pub fn array_ptr(comptime L: ListConstants, self: L.List, start: L.Idx, comptime length: L.Idx) *[length]L.Elem {
//         const end = start + length;
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(end <= list.len, @src(), ERR_IOOB_START_LEN, .{ end, list.len });
//         return &(list.ptr.?[start..list.len][0..length]);
//     }

//     pub fn nullable_array_ptr(comptime L: ListConstants, self: L.List, start: L.Idx, comptime length: L.Idx) ?*[length]L.Elem {
//         const end = start + length;
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(end <= list.len, @src(), ERR_IOOB_START_LEN, .{ end, list.len });
//         return &(list.ptr.?[start..list.len][0..length]);
//     }

//     pub fn vector_ptr(comptime L: ListConstants, self: L.List, start: L.Idx, comptime length: L.Idx) *@Vector(length, L.Elem) {
//         const end = start + length;
//         const list = L.meta_list(self);
//         assert_with_reason(end <= list.len, @src(), ERR_IOOB_START_LEN, .{ end, list.len });
//         return &(list.ptr[start..list.len][0..length]);
//     }

//     pub fn nullable_vector_ptr(comptime L: ListConstants, self: L.List, start: L.Idx, comptime length: L.Idx) ?*@Vector(length, L.Elem) {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return null;
//         const end = start + length;
//         assert_with_reason(end <= list.len, @src(), ERR_IOOB_START_LEN, .{ end, list.len });
//         return &(list.ptr.?[start..list.len][0..length]);
//     }

//     pub fn slice_with_sentinel(comptime L: ListConstants, self: L.List, comptime sentinel: L.Elem) L.SentinelSlice(sentinel) {
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(list.len < list.cap, @src(), ERR_IOOB_LEN_CAP_SENT, .{ list.len, list.cap });
//         list.ptr.?[list.len] = sentinel;
//         return list.ptr.?[0..list.len :sentinel];
//     }

//     pub fn nullable_slice_with_sentinel(comptime L: ListConstants, self: L.List, comptime sentinel: L.Elem) ?L.SentinelSlice(sentinel) {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return null;
//         assert_with_reason(list.len < list.cap, @src(), ERR_IOOB_LEN_CAP_SENT, .{ list.len, list.cap });
//         list.ptr.?[list.len] = sentinel;
//         return list.ptr.?[0..list.len :sentinel];
//     }

//     pub fn slice_full_capacity(comptime L: ListConstants, self: L.List) L.Slice {
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         return list.ptr.?[0..list.cap];
//     }

//     pub fn nullable_slice_full_capacity(comptime L: ListConstants, self: L.List) ?L.Slice {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return null;
//         return list.ptr.?[0..list.cap];
//     }

//     pub fn slice_unused_capacity(comptime L: ListConstants, self: L.List) []L.Elem {
//         const list = L.meta_list(self);
//         assert_with_reason(list.ptr != null, @src(), ERR_OP_NULL_PTR, .{});
//         return list.ptr.?[list.len..list.cap];
//     }
//     pub fn nullable_slice_unused_capacity(comptime L: ListConstants, self: L.List) ?[]L.Elem {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return null;
//         return list.ptr.?[list.len..list.cap];
//     }

//     pub fn set_len(comptime L: ListConstants, self: *L.List, new_len: L.Idx) void {
//         const list = L.meta_list_mutable(self);
//         assert_with_reason(list.ptr.* != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(new_len <= list.cap.*, @src(), ERR_NEW_LEN_CAP, .{ new_len, list.cap.* });
//         if (L.SECURE_WIPE and new_len < list.len.*) {
//             crypto.secureZero(L.Elem, list.ptr.*.?[new_len..list.len.*]);
//         }
//         list.len.* = new_len;
//     }

//     pub inline fn new_uninit(comptime L: ListConstants) L.List {
//         return L.uninit_list();
//     }

//     pub fn new_with_capacity(comptime L: ListConstants, capacity: L.Idx, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!L.List else L.List {
//         var self = L.uninit_list();
//         if (L.RETURN_ERRORS) {
//             try ensure_total_capacity_exact(L, &self, capacity, alloc);
//         } else {
//             ensure_total_capacity_exact(L, &self, capacity, alloc);
//         }
//         return self;
//     }

//     pub fn clone(comptime L: ListConstants, self: L.List, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!L.List else L.List {
//         const list = L.meta_list(self);
//         if (list.ptr == null) return L.uninit_list();
//         var new_list = if (L.RETURN_ERRORS) try new_with_capacity(L, list.cap, alloc) else new_with_capacity(L, list.cap, alloc);
//         append_slice_assume_capacity(L, &new_list, list.ptr.?[0..list.len]);
//         return new_list;
//     }

//     // pub fn to_owned_slice(comptime L: ListConstants, self: *L.List, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!L.Slice else L.Slice {
//     //     const list = L.meta_list_mutable(self);
//     //     assert_with_reason(list.ptr.* != null, @src(), ERR_OP_NULL_PTR, .{});
//     //     const old_memory = list.ptr.*.?[0..list.cap];
//     //     if (alloc.remap(old_memory, list.len.*)) |new_items| {
//     //         const old_ptr = list.ptr.*;
//     //         list.ptr.* = new_items.ptr;
//     //         handle_possible_relocate(L, list, old_ptr);
//     //         self.* = L.uninit_list();
//     //         return new_items;
//     //     }
//     //     const new_memory = alloc.alignedAlloc(L.Elem, L.ALIGN, list.len.*) catch |err| return handle_alloc_error(L, @src(), err);
//     //     @memcpy(new_memory, list.ptr.*.?[0..@intCast(list.len.*)]);
//     //     const old_ptr = list.ptr.*;
//     //     list.ptr.* = new_memory.ptr;
//     //     handle_relocate(L, list, old_ptr);
//     //     clear_and_free(L, self, alloc);
//     //     return new_memory;
//     // }

//     // pub fn to_owned_slice_sentinel(comptime L: ListConstants, self: *L.List, comptime sentinel: L.Elem, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!L.SentinelSlice(sentinel) else L.SentinelSlice(sentinel) {
//     //     var list = L.meta_list_mutable(self);
//     //     assert_with_reason(list.ptr.* != null, @src(), ERR_OP_NULL_PTR, .{});
//     //     if (L.RETURN_ERRORS) {
//     //         try ensure_total_capacity_exact(L, self, list.len.* + 1, alloc);
//     //     } else {
//     //         ensure_total_capacity_exact(L, self, list.len.* + 1, alloc);
//     //     }
//     //     list.ptr.*.?[@intCast(list.len.*)] = sentinel;
//     //     list.len.* += 1;
//     //     const result: L.Slice = if (L.RETURN_ERRORS) try to_owned_slice(L, self, alloc) else to_owned_slice(L, self, alloc);
//     //     return result[0 .. result.len - 1 :sentinel];
//     // }

//     // pub fn from_owned_slice(comptime L: ListConstants, from_slice: L.Slice) L.List {
//     //     var self = L.List;
//     //     var list = L.meta_list_mutable(self);

//     //     return L.List{
//     //         .ptr = from_slice.ptr,
//     //         .len = from_slice.len,
//     //         .cap = from_slice.len,
//     //         .ex
//     //     };
//     // }

//     // pub fn from_owned_slice_sentinel(comptime List: type, comptime sentinel: List.Elem, from_slice: [:sentinel]List.Elem) List {
//     //     assert_with_reason(!List.IS_LINKED_LIST, @src(), "cannot rebuild a linked list from a slice", .{});
//     //     return List{
//     //         .ptr = from_slice.ptr,
//     //         .len = from_slice.len,
//     //         .cap = from_slice.len,
//     //     };
//     // }

//     pub fn insert_slot(comptime L: ListConstants, self: *L.List, idx: L.Idx, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!*L.Elem else *L.Elem {
//         if (L.RETURN_ERRORS) {
//             try ensure_unused_capacity(L, self, 1, alloc);
//         } else {
//             ensure_unused_capacity(L, self, 1, alloc);
//         }
//         return insert_slot_assume_capacity(L, self, idx);
//     }

//     pub fn insert_slot_assume_capacity(comptime L: ListConstants, self: *L.List, idx: L.Idx) *L.Elem {
//         const list = L.meta_list_mutable(self);
//         assert_with_reason(list.ptr.* != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(idx <= list.len.*, @src(), ERR_IOOB_INDEX, .{ idx, list.len.* });
//         copy_rightward(L, list, idx, list.len.*, 1);
//         list.len.* += 1;
//         return &list.ptr.*.?[idx];
//     }

//     pub fn insert(comptime L: ListConstants, self: *L.List, idx: L.Idx, item: L.Elem, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!void else void {
//         const ptr = if (L.RETURN_ERRORS) try insert_slot(L, self, idx, alloc) else insert_slot(L, self, idx, alloc);
//         ptr.* = item;
//     }

//     pub fn insert_assume_capacity(comptime L: ListConstants, self: *L.List, idx: L.Idx, item: L.Elem) void {
//         const ptr = insert_slot_assume_capacity(L, self, idx);
//         ptr.* = item;
//     }

//     pub fn insert_many_slots(comptime L: ListConstants, self: *L.List, idx: L.Idx, count: L.Idx, alloc: Allocator) if (L.RETURN_ERRORS) L.Error![]L.Elem else []L.Elem {
//         if (L.RETURN_ERRORS) {
//             try ensure_unused_capacity(L, self, count, alloc);
//         } else {
//             ensure_unused_capacity(L, self, count, alloc);
//         }
//         return insert_many_slots_assume_capacity(L, self, idx, count);
//     }

//     pub fn insert_many_slots_assume_capacity(comptime L: ListConstants, self: *L.List, idx: L.Idx, count: L.Idx) []L.Elem {
//         const list = L.meta_list_mutable(self);
//         assert_with_reason(list.ptr.* != null, @src(), ERR_OP_NULL_PTR, .{});
//         assert_with_reason(idx + count <= list.len.*, @src(), ERR_IOOB_START_LEN, .{ idx + count, list.len.* });
//         copy_rightward(L, list, idx, list.len.*, count);
//         list.len.* += count;
//         return list.ptr.*.?[idx .. idx + count];
//     }

//     pub fn insert_slice(comptime L: ListConstants, self: *L.List, idx: L.Idx, items: []const L.Elem, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!void else void {
//         const slots = if (L.RETURN_ERRORS) try insert_many_slots(L, self, idx, @intCast(items.len), alloc) else insert_many_slots(L, self, idx, @intCast(items.len), alloc);
//         @memcpy(slots, items);
//     }

//     pub fn insert_slice_assume_capacity(comptime L: ListConstants, self: *L.List, idx: L.Idx, items: []const L.Elem) void {
//         const slots = insert_many_slots_assume_capacity(L, self, idx, @intCast(items.len));
//         @memcpy(slots, items);
//     }

//     pub fn replace_range(comptime List: type, self: *List, start: List.Idx, length: List.Idx, new_items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         if (new_items.len > length) {
//             const additional_needed: List.Idx = @as(List.Idx, @intCast(new_items.len)) - length;
//             if (List.RETURN_ERRORS) {
//                 try ensure_unused_capacity(List, self, additional_needed, alloc);
//             } else {
//                 ensure_unused_capacity(List, self, additional_needed, alloc);
//             }
//         }
//         replace_range_assume_capacity(List, self, start, length, new_items);
//     }

//     pub fn replace_range_assume_capacity(comptime List: type, self: *List, start: List.Idx, length: List.Idx, new_items: []const List.Elem) void {
//         const end_of_range = start + length;
//         assert(end_of_range <= self.len);
//         const range = self.ptr[start..end_of_range];
//         if (range.len == new_items.len)
//             @memcpy(range[0..new_items.len], new_items)
//         else if (range.len < new_items.len) {
//             const within_range = new_items[0..range.len];
//             const leftover = new_items[range.len..];
//             @memcpy(range[0..within_range.len], within_range);
//             const new_slots = insert_many_slots_assume_capacity(List, self, end_of_range, @intCast(leftover.len));
//             @memcpy(new_slots, leftover);
//         } else {
//             const unused_slots: List.Idx = @intCast(range.len - new_items.len);
//             @memcpy(range[0..new_items.len], new_items);
//             std.mem.copyForwards(List.Elem, self.ptr[end_of_range - unused_slots .. self.len], self.ptr[end_of_range..self.len]);
//             if (List.SECURE_WIPE) {
//                 crypto.secureZero(List.Elem, self.ptr[self.len - unused_slots .. self.len]);
//             }
//             self.len -= unused_slots;
//         }
//     }

//     pub fn append(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         const slot = if (List.RETURN_ERRORS) try append_slot(List, self, alloc) else append_slot(List, self, alloc);
//         slot.* = item;
//     }

//     pub fn append_assume_capacity(comptime List: type, self: *List, item: List.Elem) void {
//         const slot = append_slot_assume_capacity(List, self);
//         slot.* = item;
//     }

//     pub fn remove(comptime List: type, self: *List, idx: List.Idx) List.Elem {
//         const val: List.Elem = self.ptr[idx];
//         delete(List, self, idx);
//         return val;
//     }

//     pub fn swap_remove(comptime List: type, self: *List, idx: List.Idx) List.Elem {
//         const val: List.Elem = self.ptr[idx];
//         swap_delete(List, self, idx);
//         return val;
//     }

//     pub fn delete(comptime List: type, self: *List, idx: List.Idx) void {
//         assert(idx < self.len);
//         std.mem.copyForwards(List.Elem, self.ptr[idx..self.len], self.ptr[idx + 1 .. self.len]);
//         if (List.SECURE_WIPE) {
//             crypto.secureZero(List.Elem, self.ptr[self.len - 1 .. self.len]);
//         }
//         self.len -= 1;
//     }

//     pub fn delete_range(comptime List: type, self: *List, start: List.Idx, length: List.Idx) void {
//         const end_of_range = start + length;
//         assert(end_of_range <= self.len);
//         std.mem.copyForwards(List.Elem, self.ptr[start..self.len], self.ptr[end_of_range..self.len]);
//         if (List.SECURE_WIPE) {
//             crypto.secureZero(List.Elem, self.ptr[self.len - length .. self.len]);
//         }
//         self.len -= length;
//     }

//     pub fn swap_delete(comptime List: type, self: *List, idx: List.Idx) void {
//         assert(idx < self.len);
//         self.ptr[idx] = self.ptr[self.list.items.len - 1];
//         if (List.SECURE_WIPE) {
//             crypto.secureZero(List.Elem, self.ptr[self.len - 1 .. self.len]);
//         }
//         self.len -= 1;
//     }

//     pub fn append_slice(comptime List: type, self: *List, items: []const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
//         @memcpy(slots, items);
//     }

//     pub fn append_slice_assume_capacity(comptime L: ListConstants, self: *L.List, items: []const L.Elem) void {
//         const slots = append_many_slots_assume_capacity(L, self, @intCast(items.len));
//         @memcpy(slots, items);
//     }

//     pub fn append_slice_unaligned(comptime List: type, self: *List, items: []align(1) const List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, @intCast(items.len), alloc) else append_many_slots(List, self, @intCast(items.len), alloc);
//         @memcpy(slots, items);
//     }

//     pub fn append_slice_unaligned_assume_capacity(comptime List: type, self: *List, items: []align(1) const List.Elem) void {
//         const slots = append_many_slots_assume_capacity(List, self, @intCast(items.len));
//         @memcpy(slots, items);
//     }

//     pub fn append_n_times(comptime List: type, self: *List, value: List.Elem, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         const slots = if (List.RETURN_ERRORS) try append_many_slots(List, self, count, alloc) else append_many_slots(List, self, count, alloc);
//         @memset(slots, value);
//     }

//     pub fn append_n_times_assume_capacity(comptime List: type, self: *List, value: List.Elem, count: List.Idx) void {
//         const slots = append_many_slots_assume_capacity(List, self, count);
//         @memset(slots, value);
//     }

//     pub fn resize(comptime List: type, self: *List, new_len: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         if (List.RETURN_ERRORS) {
//             try ensure_total_capacity(List, self, new_len, alloc);
//         } else {
//             ensure_total_capacity(List, self, new_len, alloc);
//         }
//         if (List.SECURE_WIPE and new_len < self.len) {
//             crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
//         }
//         self.len = new_len;
//     }

//     pub fn shrink_and_free(comptime List: type, self: *List, new_len: List.Idx, alloc: Allocator) void {
//         assert(new_len <= self.len);

//         if (@sizeOf(List.Elem) == 0) {
//             self.items.len = new_len;
//             return;
//         }

//         if (List.SECURE_WIPE) {
//             crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
//         }

//         const old_memory = self.ptr[0..self.cap];
//         if (alloc.remap(old_memory, new_len)) |new_items| {
//             self.ptr = new_items.ptr;
//             self.len = new_items.len;
//             self.cap = new_items.len;
//             return;
//         }

//         const new_memory = alloc.alignedAlloc(List.Elem, List.ALIGN, new_len) catch |err| return handle_alloc_error(List, err);

//         @memcpy(new_memory, self.ptr[0..new_len]);
//         alloc.free(old_memory);
//         self.ptr = new_memory.ptr;
//         self.len = new_memory.len;
//         self.cap = new_memory.len;
//     }

//     pub fn shrink_retaining_capacity(comptime List: type, self: *List, new_len: List.Idx) void {
//         assert(new_len <= self.len);
//         if (List.SECURE_WIPE) {
//             crypto.secureZero(List.Elem, self.ptr[new_len..self.len]);
//         }
//         self.len = new_len;
//     }

//     pub fn clear_retaining_capacity(comptime List: type, self: *List) void {
//         if (List.SECURE_WIPE) {
//             std.crypto.secureZero(List.Elem, self.ptr[0..self.len]);
//         }
//         self.len = 0;
//     }

//     pub fn clear_and_free(comptime List: type, self: *List, alloc: Allocator) void {
//         if (List.SECURE_WIPE) {
//             std.crypto.secureZero(List.Elem, self.ptr[0..self.len]);
//         }
//         alloc.free(self.ptr[0..self.cap]);
//         self.* = List.EMPTY;
//     }

//     pub fn ensure_total_capacity(comptime List: type, self: *List, new_capacity: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!void else void {
//         if (self.cap >= new_capacity) return;
//         return ensure_total_capacity_exact(List, self, true_capacity_for_grow(List, self.cap, new_capacity), alloc);
//     }

//     pub fn ensure_total_capacity_exact(comptime L: ListConstants, self: *L.List, new_capacity: L.Idx, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!void else void {
//         if (@sizeOf(L.Elem) == 0) {
//             self.cap = math.maxInt(L.Idx);
//             return;
//         }

//         if (self.cap >= new_capacity) return;

//         if (new_capacity < self.len) {
//             if (L.SECURE_WIPE) crypto.secureZero(L.Elem, self.ptr[new_capacity..self.len]);
//             self.len = new_capacity;
//         }

//         const old_memory = self.ptr[0..self.cap];
//         if (alloc.remap(old_memory, new_capacity)) |new_memory| {
//             self.ptr = new_memory.ptr;
//             self.cap = @intCast(new_memory.len);
//         } else {
//             const new_memory = alloc.alignedAlloc(L.Elem, L.ALIGN, new_capacity) catch |err| return handle_alloc_error(L.List, err);
//             @memcpy(new_memory[0..self.len], self.ptr[0..self.len]);
//             if (L.SECURE_WIPE) crypto.secureZero(L.Elem, self.ptr[0..self.len]);
//             alloc.free(old_memory);
//             self.ptr = new_memory.ptr;
//             self.cap = @as(L.Idx, @intCast(new_memory.len));
//         }
//     }

//     pub fn ensure_unused_capacity(comptime L: ListConstants, self: *L.List, additional_count: L.Idx, alloc: Allocator) if (L.RETURN_ERRORS) L.Error!void else void {
//         const new_total_cap = if (L.RETURN_ERRORS) try add_or_error(L, self.len, additional_count) else add_or_error(List, self.len, additional_count);
//         return ensure_total_capacity(List, self, new_total_cap, alloc);
//     }

//     pub fn expand_to_capacity(comptime List: type, self: *List) void {
//         self.len = self.cap;
//     }

//     pub fn append_slot(comptime List: type, self: *List, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*List.Elem else *List.Elem {
//         const new_len = self.len + 1;
//         if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
//         return append_slot_assume_capacity(List, self);
//     }

//     pub fn append_slot_assume_capacity(comptime List: type, self: *List) *List.Elem {
//         assert(self.len < self.cap);
//         const idx = self.len;
//         self.len += 1;
//         return &self.ptr[idx];
//     }

//     pub fn append_many_slots(comptime List: type, self: *List, count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error![]List.Elem else []List.Elem {
//         const new_len = self.len + count;
//         if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
//         return append_many_slots_assume_capacity(List, self, count);
//     }

//     pub fn append_many_slots_assume_capacity(comptime L: ListConstants, self: *L.List, count: L.Idx) []L.Elem {
//         const new_len = self.len + count;
//         assert(new_len <= self.cap);
//         const prev_len = self.len;
//         self.len = new_len;
//         return self.ptr[prev_len..][0..count];
//     }

//     pub fn append_many_slots_as_array(comptime List: type, self: *List, comptime count: List.Idx, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!*[count]List.Elem else *[count]List.Elem {
//         const new_len = self.len + count;
//         if (List.RETURN_ERRORS) try ensure_total_capacity(List, self, new_len, alloc) else ensure_total_capacity(List, self, new_len, alloc);
//         return append_many_slots_as_array_assume_capacity(List, self, count);
//     }

//     pub fn append_many_slots_as_array_assume_capacity(comptime List: type, self: *List, comptime count: List.Idx) *[count]List.Elem {
//         const new_len = self.len + count;
//         assert(new_len <= self.cap);
//         const prev_len = self.len;
//         self.len = new_len;
//         return self.ptr[prev_len..][0..count];
//     }

//     pub fn pop(comptime List: type, self: *List) List.Elem {
//         assert(self.len > 0);
//         const new_len = self.len - 1;
//         self.len = new_len;
//         return self.ptr[new_len];
//     }

//     pub fn pop_or_null(comptime List: type, self: *List) ?List.Elem {
//         if (self.len == 0) return null;
//         return pop(List, self);
//     }

//     pub fn get_last(comptime List: type, self: List) List.Elem {
//         assert(self.len > 0);
//         return self.ptr[self.len - 1];
//     }

//     pub fn get_last_or_null(comptime List: type, self: List) ?List.Elem {
//         if (self.len == 0) return null;
//         return get_last(List, self);
//     }

//     pub fn add_or_error(comptime L: ListConstants, a: L.Idx, b: L.Idx) if (L.RETURN_ERRORS) error{OutOfMemory}!L.Idx else L.Idx {
//         if (!L.RETURN_ERRORS) return a + b;
//         const result, const overflow = @addWithOverflow(a, b);
//         if (overflow != 0) return error.OutOfMemory;
//         return result;
//     }

//     pub fn true_capacity_for_grow(comptime List: type, current: List.Idx, minimum: List.Idx) List.Idx {
//         switch (List.GROWTH) {
//             GrowthModel.GROW_EXACT_NEEDED => {
//                 return minimum;
//             },
//             GrowthModel.GROW_EXACT_NEEDED_ATOMIC_PADDING => {
//                 return minimum + List.ATOMIC_PADDING;
//             },
//             else => {
//                 var new = current;
//                 while (true) {
//                     switch (List.GROWTH) {
//                         GrowthModel.GROW_BY_100_PERCENT => {
//                             new +|= new;
//                             if (new >= minimum) return new;
//                         },
//                         GrowthModel.GROW_BY_100_PERCENT_ATOMIC_PADDING => {
//                             new +|= new;
//                             const new_with_padding = new +| List.ATOMIC_PADDING;
//                             if (new_with_padding >= minimum) return new_with_padding;
//                         },
//                         GrowthModel.GROW_BY_50_PERCENT => {
//                             new +|= new / 2;
//                             if (new >= minimum) return new;
//                         },
//                         GrowthModel.GROW_BY_50_PERCENT_ATOMIC_PADDING => {
//                             new +|= new / 2;
//                             const new_with_padding = new +| List.ATOMIC_PADDING;
//                             if (new_with_padding >= minimum) return new_with_padding;
//                         },
//                         GrowthModel.GROW_BY_25_PERCENT => {
//                             new +|= new / 4;
//                             if (new >= minimum) return new;
//                         },
//                         GrowthModel.GROW_BY_25_PERCENT_ATOMIC_PADDING => {
//                             new +|= new / 4;
//                             const new_with_padding = new +| List.ATOMIC_PADDING;
//                             if (new_with_padding >= minimum) return new_with_padding;
//                         },
//                         else => unreachable,
//                     }
//                 }
//             },
//         }
//     }

//     pub fn find_idx(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Idx {
//         for (slice(List, self), 0..) |*item, idx| {
//             if (match_fn(param, item)) return @intCast(idx);
//         }
//         return null;
//     }

//     pub fn find_ptr(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?*List.Elem {
//         if (find_idx(List, self, P, param, match_fn)) |idx| {
//             return &self.ptr[idx];
//         }
//         return null;
//     }

//     pub fn find_const_ptr(comptime List: type, self: List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?*const List.Elem {
//         if (find_idx(List, self, P, param, match_fn)) |idx| {
//             return &self.ptr[idx];
//         }
//         return null;
//     }

//     pub fn find_and_copy(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Elem {
//         if (find_idx(List, self, P, param, match_fn)) |idx| {
//             return self.ptr[idx];
//         }
//         return null;
//     }

//     pub fn find_and_remove(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) ?List.Elem {
//         if (find_idx(List, self, P, param, match_fn)) |idx| {
//             return remove(List, self, idx);
//         }
//         return null;
//     }

//     pub fn find_and_delete(comptime List: type, self: *List, comptime P: type, param: P, match_fn: *const fn (param: P, item: *const List.Elem) bool) bool {
//         if (find_idx(List, self, P, param, match_fn)) |idx| {
//             delete(List, self, idx);
//             return true;
//         }
//         return false;
//     }

//     pub fn find_exactly_n_ordered_indexes_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []List.Idx) bool {
//         assert(output_buf.len >= params.len);
//         var i: usize = 0;
//         for (slice(List, self), 0..) |*item, idx| {
//             if (match_fn(params[i], item)) {
//                 output_buf[i] = idx;
//                 i += 1;
//                 if (i == params.len) return true;
//             }
//         }
//         return false;
//     }

//     pub fn find_exactly_n_ordered_pointers_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []*List.Elem) bool {
//         assert(output_buf.len >= params.len);
//         var i: usize = 0;
//         for (slice(List, self)) |*item| {
//             if (match_fn(params[i], item)) {
//                 output_buf[i] = item;
//                 i += 1;
//                 if (i == params.len) return true;
//             }
//         }
//         return false;
//     }

//     pub fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []*const List.Elem) bool {
//         assert(output_buf.len >= params.len);
//         var i: usize = 0;
//         for (slice(List, self)) |*item| {
//             if (match_fn(params[i], item)) {
//                 output_buf[i] = item;
//                 i += 1;
//                 if (i == params.len) return true;
//             }
//         }
//         return false;
//     }

//     pub fn find_exactly_n_ordered_copies_from_n_ordered_params(comptime List: type, self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const List.Elem) bool, output_buf: []List.Elem) bool {
//         assert(output_buf.len >= params.len);
//         var i: usize = 0;
//         for (slice(List, self)) |*item| {
//             if (match_fn(params[i], item)) {
//                 output_buf[i] = item.*;
//                 i += 1;
//                 if (i == params.len) return true;
//             }
//         }
//         return false;
//     }

//     pub fn delete_ordered_indexes(comptime List: type, self: *List, indexes: []const List.Idx) void {
//         assert(indexes.len <= self.len);
//         assert(check: {
//             var i: usize = 1;
//             while (i < indexes.len) : (i += 1) {
//                 if (indexes[i - 1] >= indexes[i]) break :check false;
//             }
//             break :check true;
//         });
//         var shift_down: usize = 1;
//         var i: usize = 1;
//         var src_start: List.Idx = undefined;
//         var src_end: List.Idx = undefined;
//         var dst_start: List.Idx = undefined;
//         var dst_end: List.Idx = undefined;
//         while (i < indexes.len) : (i += 1) {
//             src_start = indexes[i - 1] + 1;
//             src_end = indexes[i];
//             dst_start = src_start - shift_down;
//             dst_end = src_end - shift_down;
//             std.mem.copyForwards(List.Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
//             shift_down += 1;
//         }
//         src_start = indexes[i] + 1;
//         src_end = @intCast(self.len);
//         dst_start = src_start - shift_down;
//         dst_end = src_end - shift_down;
//         std.mem.copyForwards(List.Idx, self.ptr[dst_start..dst_end], self.ptr[src_start..src_end]);
//         self.len -= indexes.len;
//     }

//     // pub inline fn sort(comptime List: type, self: *List) void {
//     //     custom_sort(List, self, List.DEFAULT_SORT_ALGO, List.DEFAULT_COMPARE_PKG);
//     // }

//     // pub fn custom_sort(comptime List: type, self: *List, algorithm: SortAlgorithm, compare_pkg: ComparePackage(List.Elem)) void {
//     //     if (self.len < 2) return;
//     //     switch (algorithm) {
//     //         // SortAlgorithm.HEAP_SORT => {},
//     //         .INSERTION_SORT => InsertionSort.insertion_sort(List.Elem, compare_pkg.greater_than, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_FIRST => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.FIRST, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_LAST => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.LAST, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_MIDDLE => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MIDDLE, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_RANDOM => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.RANDOM, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_MEDIAN_OF_3 => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MEDIAN_OF_3, self.ptr[0..self.len]),
//     //         .QUICK_SORT_PIVOT_MEDIAN_OF_3_RANDOM => Quicksort.quicksort(List.Elem, compare_pkg.greater_than, compare_pkg.less_than, Pivot.MEDIAN_OF_3_RANDOM, self.ptr[0..self.len]),
//     //     }
//     // }

//     // pub inline fn is_sorted(comptime List: type, self: *List) bool {
//     //     return is_sorted_custom(List, self, List.DEFAULT_COMPARE_PKG.greater_than);
//     // }

//     // pub fn is_sorted_custom(comptime List: type, self: *List, greater_than_fn: *const CompareFn(List.Elem)) bool {
//     //     if (self.len < 2) return true;
//     //     var idx: List.Idx = 0;
//     //     const limit = self.len - 1;
//     //     while (idx < limit) : (idx += 1) {
//     //         const next_idx = idx + 1;
//     //         if (greater_than_fn(&self.ptr[idx], &self.ptr[next_idx])) return false;
//     //     }
//     //     return true;
//     // }

//     // pub inline fn insert_one_sorted(comptime List: type, self: *List, item: List.Elem, alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List.Idx else List.Idx {
//     //     return insert_one_sorted_custom(List, self, item, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_MATCH_FN, alloc);
//     // }

//     // pub fn insert_one_sorted_custom(comptime List: type, self: *List, item: List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem), alloc: Allocator) if (List.RETURN_ERRORS) List.Error!List.Idx else List.Idx {
//     //     const insert_idx: List.Idx = @intCast(BinarySearch.binary_search_insert_index(List.Elem, &item, self.ptr[0..self.len], greater_than_fn, equal_order_fn));
//     //     if (List.RETURN_ERRORS) try insert(List, self, insert_idx, item, alloc) else insert(List, self, insert_idx, item, alloc);
//     //     return insert_idx;
//     // }

//     // pub inline fn find_equal_order_idx_sorted(comptime List: type, self: *List, item_to_compare: *const List.Elem) ?List.Idx {
//     //     return find_equal_order_idx_sorted_custom(List, self, item_to_compare, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_MATCH_FN);
//     // }

//     // pub fn find_equal_order_idx_sorted_custom(comptime List: type, self: *List, item_to_compare: *const List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem)) ?List.Idx {
//     //     const insert_idx = BinarySearch.binary_search_by_order(List.Elem, item_to_compare, self.ptr[0..self.len], greater_than_fn, equal_order_fn);
//     //     if (insert_idx) |idx| return @intCast(idx);
//     //     return null;
//     // }

//     // pub inline fn find_matching_item_idx_sorted(comptime List: type, self: *List, item_to_find: *const List.Elem) ?List.Idx {
//     //     return find_matching_item_idx_sorted_custom(List, self, item_to_find, List.DEFAULT_COMPARE_PKG.greater_than, List.DEFAULT_COMPARE_PKG.equals, List.DEFAULT_MATCH_FN);
//     // }

//     // pub fn find_matching_item_idx_sorted_custom(comptime List: type, self: *List, item_to_find: *const List.Elem, greater_than_fn: *const CompareFn(List.Elem), equal_order_fn: *const CompareFn(List.Elem), exact_match_fn: *const CompareFn(List.Elem)) ?List.Idx {
//     //     const insert_idx = BinarySearch.binary_search_exact_match(List.Elem, item_to_find, self.ptr[0..self.len], greater_than_fn, equal_order_fn, exact_match_fn);
//     //     if (insert_idx) |idx| return @intCast(idx);
//     //     return null;
//     // }

//     // pub inline fn find_matching_item_idx(comptime List: type, self: *List, item_to_find: *const List.Elem) ?List.Idx {
//     //     return find_matching_item_idx_custom(List, self, item_to_find, List.DEFAULT_MATCH_FN);
//     // }

//     // pub fn find_matching_item_idx_custom(comptime List: type, self: *List, item_to_find: *const List.Elem, exact_match_fn: *const CompareFn(List.Elem)) ?List.Idx {
//     //     if (self.len == 0) return null;
//     //     const buf = self.ptr[0..self.len];
//     //     var idx: List.Idx = 0;
//     //     var found_exact = exact_match_fn(item_to_find, &buf[idx]);
//     //     const limit = self.len - 1;
//     //     while (!found_exact and idx < limit) {
//     //         idx += 1;
//     //         found_exact = exact_match_fn(item_to_find, &buf[idx]);
//     //     }
//     //     if (found_exact) return idx;
//     //     return null;
//     // }

//     pub fn handle_alloc_error(comptime L: ListConstants, comptime src: SourceLocation, comptime this: type, err: L.Error) if (L.RETURN_ERRORS) L.Error else noreturn {
//         switch (L.ERROR_BEHAVIOR) {
//             ErrorBehavior.RETURN_ERRORS => return err,
//             ErrorBehavior.ERRORS_PANIC => assert_with_reason(false, src, this, "upstream error: {s}", .{@errorName(err)}),
//             ErrorBehavior.ERRORS_ARE_UNREACHABLE => unreachable,
//         }
//     }
// };

// pub fn define_manually_managed_list_type(comptime options: ListOptions) type {
//     const opt = comptime check: {
//         var opts = options;
//         if (opts.alignment) |a| {
//             if (a == @alignOf(opts.T)) {
//                 opts.alignment = null;
//             }
//         }
//         break :check opts;
//     };
//     if (opt.alignment) |a| {
//         if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
//     }
//     if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
//     return extern struct {
//         ptr: Ptr = UNINIT_PTR,
//         len: Idx = 0,
//         cap: Idx = 0,

//         pub const ALIGN = options.alignment;
//         pub const ALLOC_ERROR_BEHAVIOR = options.error_behavior;
//         pub const GROWTH = options.growth_model;
//         pub const RETURN_ERRORS = options.error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
//         pub const SECURE_WIPE = options.secure_wipe_bytes;
//         pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
//         pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
//         pub const EMPTY = List{};

//         const List = @This();
//         pub const Error = Allocator.Error;
//         pub const Elem = options.element_type;
//         pub const Idx = options.index_type;
//         pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
//         pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
//         pub fn SentinelSlice(comptime sentinel: Elem) type {
//             return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
//         }

//         pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
//             return Impl.flex_slice(List, self, mutability);
//         }

//         pub inline fn slice(self: List) Slice {
//             return Impl.zig_slice(List, self);
//         }

//         pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
//             return Impl.array_ptr(List, self, start, length);
//         }

//         pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
//             return Impl.vector_ptr(List, self, start, length);
//         }

//         pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
//             return Impl.slice_with_sentinel(List, self, sentinel);
//         }

//         pub inline fn slice_full_capacity(self: List) Slice {
//             return Impl.slice_full_capacity(List, self);
//         }

//         pub inline fn slice_unused_capacity(self: List) []Elem {
//             return Impl.slice_unused_capacity(List, self);
//         }

//         pub inline fn set_len(self: *List, new_len: Idx) void {
//             return Impl.set_len(List, self, new_len);
//         }

//         pub inline fn new_empty() List {
//             return Impl.new_uninit(List);
//         }

//         pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
//             return Impl.new_with_capacity(List, capacity, alloc);
//         }

//         pub inline fn clone(self: List, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
//             return Impl.clone(List, self, alloc);
//         }

//         pub inline fn to_owned_slice(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!Slice else Slice {
//             return Impl.to_owned_slice(List, self, alloc);
//         }

//         pub inline fn to_owned_slice_sentinel(self: *List, alloc: Allocator, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
//             return Impl.to_owned_slice_sentinel(List, self, alloc, sentinel);
//         }

//         pub inline fn from_owned_slice(from_slice: Slice) List {
//             return Impl.from_owned_slice(List, from_slice);
//         }

//         pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
//             return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
//         }

//         pub inline fn insert_slot(self: *List, idx: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.insert_slot(List, self, idx, alloc);
//         }

//         pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
//             return Impl.insert_slot_assume_capacity(List, self, idx);
//         }

//         pub inline fn insert(self: *List, idx: Idx, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert(List, self, idx, item, alloc);
//         }

//         pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
//             return Impl.insert_assume_capacity(List, self, idx, item);
//         }

//         pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.insert_many_slots(List, self, idx, count, alloc);
//         }

//         pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
//             return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
//         }

//         pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert_slice(List, self, idx, items, alloc);
//         }

//         pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
//             return Impl.insert_slice_assume_capacity(List, self, idx, items);
//         }

//         pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.replace_range(List, self, start, length, new_items, alloc);
//         }

//         pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
//             return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
//         }

//         pub inline fn append(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append(List, self, item, alloc);
//         }

//         pub inline fn append_assume_capacity(self: *List, item: Elem) void {
//             return Impl.append_assume_capacity(List, self, item);
//         }

//         pub inline fn remove(self: *List, idx: Idx) Elem {
//             return Impl.remove(List, self, idx);
//         }

//         pub inline fn swap_remove(self: *List, idx: Idx) Elem {
//             return Impl.swap_remove(List, self, idx);
//         }

//         pub inline fn delete(self: *List, idx: Idx) void {
//             return Impl.delete(List, self, idx);
//         }

//         pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
//             return Impl.delete_range(List, self, start, length);
//         }

//         pub inline fn swap_delete(self: *List, idx: Idx) void {
//             return Impl.swap_delete(List, self, idx);
//         }

//         pub inline fn append_slice(self: *List, items: []const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice(List, self, items, alloc);
//         }

//         pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
//             return Impl.append_slice_assume_capacity(List, self, items);
//         }

//         pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice_unaligned(List, self, items, alloc);
//         }

//         pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
//             return Impl.append_slice_unaligned_assume_capacity(List, self, items);
//         }

//         pub inline fn append_n_times(self: *List, value: Elem, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_n_times(List, self, value, count, alloc);
//         }

//         pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
//             return Impl.append_n_times_assume_capacity(List, self, value, count);
//         }

//         pub inline fn resize(self: *List, new_len: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.resize(List, self, new_len, alloc);
//         }

//         pub inline fn shrink_and_free(self: *List, new_len: Idx, alloc: Allocator) void {
//             return Impl.shrink_and_free(List, self, new_len, alloc);
//         }

//         pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
//             return Impl.shrink_retaining_capacity(List, self, new_len);
//         }

//         pub inline fn clear_retaining_capacity(self: *List) void {
//             return Impl.clear_retaining_capacity(List, self);
//         }

//         pub inline fn clear_and_free(self: *List, alloc: Allocator) void {
//             return Impl.clear_and_free(List, self, alloc);
//         }

//         pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity(List, self, new_capacity, alloc);
//         }

//         pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity_exact(List, self, new_capacity, alloc);
//         }

//         pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_unused_capacity(List, self, additional_count, alloc);
//         }

//         pub inline fn expand_to_capacity(self: *List) void {
//             return Impl.expand_to_capacity(List, self);
//         }

//         pub inline fn append_slot(self: *List, alloc: Allocator) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.append_slot(List, self, alloc);
//         }

//         pub inline fn append_slot_assume_capacity(self: *List) *Elem {
//             return Impl.append_slot_assume_capacity(List, self);
//         }

//         pub inline fn append_many_slots(self: *List, count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.append_many_slots(List, self, count, alloc);
//         }

//         pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
//             return Impl.append_many_slots_assume_capacity(List, self, count);
//         }

//         pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
//             return Impl.append_many_slots_as_array(List, self, count, alloc);
//         }

//         pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
//             return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
//         }

//         pub inline fn pop_or_null(self: *List) ?Elem {
//             return Impl.pop_or_null(List, self);
//         }

//         pub inline fn pop(self: *List) Elem {
//             return Impl.pop(List, self);
//         }

//         pub inline fn get_last(self: List) Elem {
//             return Impl.get_last(List, self);
//         }

//         pub inline fn get_last_or_null(self: List) ?Elem {
//             return Impl.get_last_or_null(List, self);
//         }

//         pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
//             return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
//             return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
//             return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
//             return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
//             return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
//             return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
//             return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
//             return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
//             return Impl.delete_ordered_indexes(List, self, indexes);
//         }

//         // pub inline fn sort(self: *List) void {
//         //     return Internal.sort(List, self);
//         // }

//         // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const CompareFn(Elem)) void {
//         //     return Internal.custom_sort(List, self, algorithm, order_func);
//         // }

//         // pub inline fn is_sorted(self: *List) bool {
//         //     return Internal.is_sorted(List, self);
//         // }

//         // pub inline fn is_sorted_custom(self: *List, compare_fn: *const CompareFn(Elem)) bool {
//         //     return Internal.is_sorted_custom(List, self, compare_fn);
//         // }

//         // pub inline fn insert_one_sorted(self: *List, item: Elem, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted(List, self, item, alloc);
//         // }

//         // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool, alloc: Allocator) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, alloc);
//         // }

//         // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
//         // }

//         // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
//         // }

//         // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
//         // }

//         // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
//         // }

//         //**************************
//         // std.io.Writer interface *
//         //**************************
//         const WriterHandle = struct {
//             list: *List,
//             alloc: Allocator,
//         };
//         const WriterHandleNoGrow = struct {
//             list: *List,
//         };

//         pub const StdWriter = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandle, Allocator.Error, write);

//         pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
//             return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
//         }

//         fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
//             try handle.list.append_slice(bytes, handle.alloc);
//             return bytes.len;
//         }

//         pub const StdWriterNoGrow = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandleNoGrow, Allocator.Error, write_no_grow);

//         pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
//             return StdWriterNoGrow{ .context = .{ .list = self } };
//         }

//         fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
//             const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
//             if (bytes.len > available_capacity) return error.OutOfMemory;
//             handle.list.append_slice_assume_capacity(bytes);
//             return bytes.len;
//         }
//     };
// }

// pub fn define_static_allocator_list_type(comptime base_options: ListOptions, comptime alloc_ptr: *const Allocator) type {
//     const opt = comptime check: {
//         var opts = base_options;
//         if (opts.alignment) |a| {
//             if (a == @alignOf(opts.T)) {
//                 opts.alignment = null;
//             }
//         }
//         break :check opts;
//     };
//     if (opt.alignment) |a| {
//         if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
//     }
//     if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
//     return extern struct {
//         ptr: Ptr = UNINIT_PTR,
//         len: Idx = 0,
//         cap: Idx = 0,

//         pub const ALLOC = alloc_ptr;
//         pub const ALIGN = base_options.alignment;
//         pub const ALLOC_ERROR_BEHAVIOR = base_options.error_behavior;
//         pub const GROWTH = base_options.growth_model;
//         pub const RETURN_ERRORS = base_options.error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
//         pub const SECURE_WIPE = base_options.secure_wipe_bytes;
//         pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
//         pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
//         pub const EMPTY = List{
//             .ptr = UNINIT_PTR,
//             .len = 0,
//             .cap = 0,
//         };

//         const List = @This();
//         pub const Error = Allocator.Error;
//         pub const Elem = base_options.element_type;
//         pub const Idx = base_options.index_type;
//         pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
//         pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
//         pub fn SentinelSlice(comptime sentinel: Elem) type {
//             return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
//         }

//         pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
//             return Impl.flex_slice(List, self, mutability);
//         }

//         pub inline fn slice(self: List) Slice {
//             return Impl.slice(List, self);
//         }

//         pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
//             return Impl.array_ptr(List, self, start, length);
//         }

//         pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
//             return Impl.vector_ptr(List, self, start, length);
//         }

//         pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
//             return Impl.slice_with_sentinel(List, self, sentinel);
//         }

//         pub inline fn slice_full_capacity(self: List) Slice {
//             return Impl.slice_full_capacity(List, self);
//         }

//         pub inline fn slice_unused_capacity(self: List) []Elem {
//             return Impl.slice_unused_capacity(List, self);
//         }

//         pub inline fn set_len(self: *List, new_len: Idx) void {
//             return Impl.set_len(List, self, new_len);
//         }

//         pub inline fn new_empty() List {
//             return Impl.new_uninit(List);
//         }

//         pub inline fn new_with_capacity(capacity: Idx) if (RETURN_ERRORS) Error!List else List {
//             return Impl.new_with_capacity(List, capacity, ALLOC.*);
//         }

//         pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
//             return Impl.clone(List, self, ALLOC.*);
//         }

//         pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
//             return Impl.to_owned_slice(List, self, ALLOC.*);
//         }

//         pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
//             return Impl.to_owned_slice_sentinel(List, self, sentinel, ALLOC.*);
//         }

//         pub inline fn from_owned_slice(from_slice: Slice) List {
//             return Impl.from_owned_slice(List, from_slice);
//         }

//         pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
//             return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
//         }

//         pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.insert_slot(List, self, idx, ALLOC.*);
//         }

//         pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
//             return Impl.insert_slot_assume_capacity(List, self, idx);
//         }

//         pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert(List, self, idx, item, ALLOC.*);
//         }

//         pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
//             return Impl.insert_assume_capacity(List, self, idx, item);
//         }

//         pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.insert_many_slots(List, self, idx, count, ALLOC.*);
//         }

//         pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
//             return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
//         }

//         pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert_slice(List, self, idx, items, ALLOC.*);
//         }

//         pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
//             return Impl.insert_slice_assume_capacity(List, self, idx, items);
//         }

//         pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.replace_range(List, self, start, length, new_items, ALLOC.*);
//         }

//         pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
//             return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
//         }

//         pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append(List, self, item, ALLOC.*);
//         }

//         pub inline fn append_assume_capacity(self: *List, item: Elem) void {
//             return Impl.append_assume_capacity(List, self, item);
//         }

//         pub inline fn remove(self: *List, idx: Idx) Elem {
//             return Impl.remove(List, self, idx);
//         }

//         pub inline fn swap_remove(self: *List, idx: Idx) Elem {
//             return Impl.swap_remove(List, self, idx);
//         }

//         pub inline fn delete(self: *List, idx: Idx) void {
//             return Impl.delete(List, self, idx);
//         }

//         pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
//             return Impl.delete_range(List, self, start, length);
//         }

//         pub inline fn swap_delete(self: *List, idx: Idx) void {
//             return Impl.swap_delete(List, self, idx);
//         }

//         pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice(List, self, items, ALLOC.*);
//         }

//         pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
//             return Impl.append_slice_assume_capacity(List, self, items);
//         }

//         pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice_unaligned(List, self, items, ALLOC.*);
//         }

//         pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
//             return Impl.append_slice_unaligned_assume_capacity(List, self, items);
//         }

//         pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_n_times(List, self, value, count, ALLOC.*);
//         }

//         pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
//             return Impl.append_n_times_assume_capacity(List, self, value, count);
//         }

//         pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.resize(List, self, new_len, ALLOC.*);
//         }

//         pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
//             return Impl.shrink_and_free(List, self, new_len, ALLOC.*);
//         }

//         pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
//             return Impl.shrink_retaining_capacity(List, self, new_len);
//         }

//         pub inline fn clear_retaining_capacity(self: *List) void {
//             return Impl.clear_retaining_capacity(List, self);
//         }

//         pub inline fn clear_and_free(self: *List) void {
//             return Impl.clear_and_free(List, self, ALLOC.*);
//         }

//         pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity(List, self, new_capacity, ALLOC.*);
//         }

//         pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity_exact(List, self, new_capacity, ALLOC.*);
//         }

//         pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_unused_capacity(List, self, additional_count, ALLOC.*);
//         }

//         pub inline fn expand_to_capacity(self: *List) void {
//             return Impl.expand_to_capacity(List, self);
//         }

//         pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.append_slot(List, self, ALLOC.*);
//         }

//         pub inline fn append_slot_assume_capacity(self: *List) *Elem {
//             return Impl.append_slot_assume_capacity(List, self);
//         }

//         pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.append_many_slots(List, self, count, ALLOC.*);
//         }

//         pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
//             return Impl.append_many_slots_assume_capacity(List, self, count);
//         }

//         pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
//             return Impl.append_many_slots_as_array(List, self, count, ALLOC.*);
//         }

//         pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
//             return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
//         }

//         pub inline fn pop_or_null(self: *List) ?Elem {
//             return Impl.pop_or_null(List, self);
//         }

//         pub inline fn pop(self: *List) Elem {
//             return Impl.pop(List, self);
//         }

//         pub inline fn get_last(self: List) Elem {
//             return Impl.get_last(List, self);
//         }

//         pub inline fn get_last_or_null(self: List) ?Elem {
//             return Impl.get_last_or_null(List, self);
//         }

//         pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
//             return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
//             return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
//             return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
//             return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
//             return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
//             return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
//             return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
//             return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
//             return Impl.delete_ordered_indexes(List, self, indexes);
//         }

//         // pub inline fn sort(self: *List) void {
//         //     return Internal.sort(List, self);
//         // }

//         // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const fn (a: *const List.Elem, b: *const List.Elem) Compare.Order) void {
//         //     return Internal.custom_sort(List, self, algorithm, order_func);
//         // }

//         // pub inline fn is_sorted(self: *List) bool {
//         //     return Internal.is_sorted(List, self);
//         // }

//         // pub inline fn is_sorted_custom(self: *List, greater_than_fn: *const CompareFn(Elem)) bool {
//         //     return Internal.is_sorted_custom(List, self, greater_than_fn);
//         // }

//         // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted(List, self, item, ALLOC.*);
//         // }

//         // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, ALLOC.*);
//         // }

//         // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
//         // }

//         // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
//         // }

//         // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
//         // }

//         // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
//         // }

//         //**************************
//         // std.io.Writer interface *
//         //**************************
//         const WriterHandle = struct {
//             list: *List,
//         };

//         pub const StdWriter = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandle, Allocator.Error, write);

//         pub fn get_std_writer(self: *List, alloc: Allocator) StdWriter {
//             return StdWriter{ .context = .{ .list = self, .alloc = alloc } };
//         }

//         fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
//             try handle.list.append_slice(bytes);
//             return bytes.len;
//         }

//         pub const StdWriterNoGrow = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandle, Allocator.Error, write_no_grow);

//         pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
//             return StdWriterNoGrow{ .context = .{ .list = self } };
//         }

//         fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
//             const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
//             if (bytes.len > available_capacity) return error.OutOfMemory;
//             handle.list.append_slice_assume_capacity(bytes);
//             return bytes.len;
//         }
//     };
// }

// pub fn define_cached_allocator_list_type(comptime base_options: ListOptions) type {
//     const opt = comptime check: {
//         var opts = base_options;
//         if (opts.alignment) |a| {
//             if (a == @alignOf(opts.T)) {
//                 opts.alignment = null;
//             }
//         }
//         break :check opts;
//     };
//     if (opt.alignment) |a| {
//         if (!math.isPowerOfTwo(a)) @panic("alignment must be a power of 2");
//     }
//     if (@typeInfo(opt.index_type) != Type.int or @typeInfo(opt.index_type).int.signedness != .unsigned) @panic("index_type must be an unsigned integer type");
//     return extern struct {
//         ptr: Ptr = UNINIT_PTR,
//         alloc_ptr: *anyopaque,
//         alloc_vtable: *const Allocator.VTable,
//         len: Idx = 0,
//         cap: Idx = 0,

//         pub const ALIGN = base_options.alignment;
//         pub const ALLOC_ERROR_BEHAVIOR = base_options.error_behavior;
//         pub const GROWTH = base_options.growth_model;
//         pub const RETURN_ERRORS = base_options.error_behavior == .ALLOCATION_ERRORS_RETURN_ERROR;
//         pub const SECURE_WIPE = base_options.secure_wipe_bytes;
//         pub const UNINIT_PTR: Ptr = @ptrFromInt(if (ALIGN) |a| mem.alignBackward(usize, math.maxInt(usize), @intCast(a)) else mem.alignBackward(usize, math.maxInt(usize), @alignOf(Elem)));
//         pub const ATOMIC_PADDING = @as(comptime_int, @max(1, std.atomic.cache_line / @sizeOf(Elem)));
//         pub const EMPTY = List{
//             .ptr = UNINIT_PTR,
//             .alloc_ptr = DummyAllocator.allocator.ptr,
//             .alloc_vtable = DummyAllocator.allocator.vtable,
//             .len = 0,
//             .cap = 0,
//         };

//         const List = @This();
//         pub const Error = Allocator.Error;
//         pub const Elem = base_options.element_type;
//         pub const Idx = base_options.index_type;
//         pub const Ptr = if (ALIGN) |a| [*]align(a) Elem else [*]Elem;
//         pub const Slice = if (ALIGN) |a| ([]align(a) Elem) else []Elem;
//         pub fn SentinelSlice(comptime sentinel: Elem) type {
//             return if (ALIGN) |a| ([:sentinel]align(a) Elem) else [:sentinel]Elem;
//         }

//         pub inline fn get_alloc(self: List) Allocator {
//             return Allocator{
//                 .ptr = self.alloc_ptr,
//                 .vtable = self.alloc_vtable,
//             };
//         }

//         pub inline fn set_alloc(self: *List, alloc: Allocator) void {
//             self.alloc_ptr = alloc.ptr;
//             self.alloc_vtable = alloc.vtable;
//         }

//         pub inline fn flex_slice(self: List, comptime mutability: Mutability) FlexSlice(Elem, Idx, mutability) {
//             return Impl.flex_slice(List, self, mutability);
//         }

//         pub inline fn slice(self: List) Slice {
//             return Impl.slice(List, self);
//         }

//         pub inline fn array_ptr(self: List, start: Idx, comptime length: Idx) *[length]Elem {
//             return Impl.array_ptr(List, self, start, length);
//         }

//         pub inline fn vector_ptr(self: List, start: Idx, comptime length: Idx) *@Vector(length, Elem) {
//             return Impl.vector_ptr(List, self, start, length);
//         }

//         pub inline fn slice_with_sentinel(self: List, comptime sentinel: Elem) SentinelSlice(Elem) {
//             return Impl.slice_with_sentinel(List, self, sentinel);
//         }

//         pub inline fn slice_full_capacity(self: List) Slice {
//             return Impl.slice_full_capacity(List, self);
//         }

//         pub inline fn slice_unused_capacity(self: List) []Elem {
//             return Impl.slice_unused_capacity(List, self);
//         }

//         pub inline fn set_len(self: *List, new_len: Idx) void {
//             return Impl.set_len(List, self, new_len);
//         }

//         pub inline fn new_empty(alloc: Allocator) List {
//             const list: List = Impl.new_uninit(List);
//             list.set_alloc(alloc);
//             return list;
//         }

//         pub inline fn new_with_capacity(capacity: Idx, alloc: Allocator) if (RETURN_ERRORS) Error!List else List {
//             const list: List = try Impl.new_with_capacity(List, capacity, alloc);
//             list.set_alloc(alloc);
//             return list;
//         }

//         pub inline fn clone(self: List) if (RETURN_ERRORS) Error!List else List {
//             return Impl.clone(List, self, self.get_alloc());
//         }

//         pub inline fn to_owned_slice(self: *List) if (RETURN_ERRORS) Error!Slice else Slice {
//             return Impl.to_owned_slice(List, self, self.get_alloc());
//         }

//         pub inline fn to_owned_slice_sentinel(self: *List, comptime sentinel: Elem) if (RETURN_ERRORS) Error!SentinelSlice(sentinel) else SentinelSlice(sentinel) {
//             return Impl.to_owned_slice_sentinel(List, self, sentinel, self.get_alloc());
//         }

//         pub inline fn from_owned_slice(from_slice: Slice) List {
//             return Impl.from_owned_slice(List, from_slice);
//         }

//         pub inline fn from_owned_slice_sentinel(comptime sentinel: Elem, from_slice: [:sentinel]Elem) List {
//             return Impl.from_owned_slice_sentinel(List, sentinel, from_slice);
//         }

//         pub inline fn insert_slot(self: *List, idx: Idx) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.insert_slot(List, self, idx, self.get_alloc());
//         }

//         pub inline fn insert_slot_assume_capacity(self: *List, idx: Idx) *Elem {
//             return Impl.insert_slot_assume_capacity(List, self, idx);
//         }

//         pub inline fn insert(self: *List, idx: Idx, item: Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert(List, self, idx, item, self.get_alloc());
//         }

//         pub inline fn insert_assume_capacity(self: *List, idx: Idx, item: Elem) void {
//             return Impl.insert_assume_capacity(List, self, idx, item);
//         }

//         pub inline fn insert_many_slots(self: *List, idx: Idx, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.insert_many_slots(List, self, idx, count, self.get_alloc());
//         }

//         pub inline fn insert_many_slots_assume_capacity(self: *List, idx: Idx, count: Idx) []Elem {
//             return Impl.insert_many_slots_assume_capacity(List, self, idx, count);
//         }

//         pub inline fn insert_slice(self: *List, idx: Idx, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.insert_slice(List, self, idx, items, self.get_alloc());
//         }

//         pub inline fn insert_slice_assume_capacity(self: *List, idx: Idx, items: []const Elem) void {
//             return Impl.insert_slice_assume_capacity(List, self, idx, items);
//         }

//         pub inline fn replace_range(self: *List, start: Idx, length: Idx, new_items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.replace_range(List, self, start, length, new_items, self.get_alloc());
//         }

//         pub inline fn replace_range_assume_capacity(self: *List, start: Idx, length: Idx, new_items: []const Elem) void {
//             return Impl.replace_range_assume_capacity(List, self, start, length, new_items);
//         }

//         pub inline fn append(self: *List, item: Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append(List, self, item, self.get_alloc());
//         }

//         pub inline fn append_assume_capacity(self: *List, item: Elem) void {
//             return Impl.append_assume_capacity(List, self, item);
//         }

//         pub inline fn remove(self: *List, idx: Idx) Elem {
//             return Impl.remove(List, self, idx);
//         }

//         pub inline fn swap_remove(self: *List, idx: Idx) Elem {
//             return Impl.swap_remove(List, self, idx);
//         }

//         pub inline fn delete(self: *List, idx: Idx) void {
//             return Impl.delete(List, self, idx);
//         }

//         pub inline fn delete_range(self: *List, start: Idx, length: Idx) void {
//             return Impl.delete_range(List, self, start, length);
//         }

//         pub inline fn swap_delete(self: *List, idx: Idx) void {
//             return Impl.swap_delete(List, self, idx);
//         }

//         pub inline fn append_slice(self: *List, items: []const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice(List, self, items, self.get_alloc());
//         }

//         pub inline fn append_slice_assume_capacity(self: *List, items: []const Elem) void {
//             return Impl.append_slice_assume_capacity(List, self, items);
//         }

//         pub inline fn append_slice_unaligned(self: *List, items: []align(1) const Elem) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_slice_unaligned(List, self, items, self.get_alloc());
//         }

//         pub inline fn append_slice_unaligned_assume_capacity(self: *List, items: []align(1) const Elem) void {
//             return Impl.append_slice_unaligned_assume_capacity(List, self, items);
//         }

//         pub inline fn append_n_times(self: *List, value: Elem, count: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.append_n_times(List, self, value, count, self.get_alloc());
//         }

//         pub inline fn append_n_times_assume_capacity(self: *List, value: Elem, count: Idx) void {
//             return Impl.append_n_times_assume_capacity(List, self, value, count);
//         }

//         pub inline fn resize(self: *List, new_len: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.resize(List, self, new_len, self.get_alloc());
//         }

//         pub inline fn shrink_and_free(self: *List, new_len: Idx) void {
//             return Impl.shrink_and_free(List, self, new_len, self.get_alloc());
//         }

//         pub inline fn shrink_retaining_capacity(self: *List, new_len: Idx) void {
//             return Impl.shrink_retaining_capacity(List, self, new_len);
//         }

//         pub inline fn clear_retaining_capacity(self: *List) void {
//             return Impl.clear_retaining_capacity(List, self);
//         }

//         pub inline fn clear_and_free(self: *List) void {
//             return Impl.clear_and_free(List, self, self.get_alloc());
//         }

//         pub inline fn ensure_total_capacity(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity(List, self, new_capacity, self.get_alloc());
//         }

//         pub inline fn ensure_total_capacity_exact(self: *List, new_capacity: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_total_capacity_exact(List, self, new_capacity, self.get_alloc());
//         }

//         pub inline fn ensure_unused_capacity(self: *List, additional_count: Idx) if (RETURN_ERRORS) Error!void else void {
//             return Impl.ensure_unused_capacity(List, self, additional_count, self.get_alloc());
//         }

//         pub inline fn expand_to_capacity(self: *List) void {
//             return Impl.expand_to_capacity(List, self);
//         }

//         pub inline fn append_slot(self: *List) if (RETURN_ERRORS) Error!*Elem else *Elem {
//             return Impl.append_slot(List, self, self.get_alloc());
//         }

//         pub inline fn append_slot_assume_capacity(self: *List) *Elem {
//             return Impl.append_slot_assume_capacity(List, self);
//         }

//         pub inline fn append_many_slots(self: *List, count: Idx) if (RETURN_ERRORS) Error![]Elem else []Elem {
//             return Impl.append_many_slots(List, self, count, self.get_alloc());
//         }

//         pub inline fn append_many_slots_assume_capacity(self: *List, count: Idx) []Elem {
//             return Impl.append_many_slots_assume_capacity(List, self, count);
//         }

//         pub inline fn append_many_slots_as_array(self: *List, comptime count: Idx) if (RETURN_ERRORS) Error!*[count]Elem else *[count]Elem {
//             return Impl.append_many_slots_as_array(List, self, count, self.get_alloc());
//         }

//         pub inline fn append_many_slots_as_array_assume_capacity(self: *List, comptime count: Idx) *[count]Elem {
//             return Impl.append_many_slots_as_array_assume_capacity(List, self, count);
//         }

//         pub inline fn pop_or_null(self: *List) ?Elem {
//             return Impl.pop_or_null(List, self);
//         }

//         pub inline fn pop(self: *List) Elem {
//             return Impl.pop(List, self);
//         }

//         pub inline fn get_last(self: List) Elem {
//             return Impl.get_last(List, self);
//         }

//         pub inline fn get_last_or_null(self: List) ?Elem {
//             return Impl.get_last_or_null(List, self);
//         }

//         pub inline fn find_idx(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Idx {
//             return Impl.find_idx(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*Elem {
//             return Impl.find_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_const_ptr(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?*const Elem {
//             return Impl.find_const_ptr(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_copy(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_copy(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_remove(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) ?Elem {
//             return Impl.find_and_remove(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_and_delete(self: List, match_param: anytype, match_fn: *const fn (param: @TypeOf(match_param), item: *const Elem) bool) bool {
//             return Impl.find_and_delete(List, self, @TypeOf(match_param), match_param, match_fn);
//         }

//         pub inline fn find_exactly_n_ordered_indexes_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Idx) bool {
//             return Impl.find_exactly_n_ordered_indexes_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*Elem) bool {
//             return Impl.find_exactly_n_ordered_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_const_pointers_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []*const Elem) bool {
//             return Impl.find_exactly_n_ordered_const_pointers_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn find_exactly_n_ordered_copies_from_n_ordered_params(self: List, comptime P: type, params: []const P, match_fn: *const fn (param: P, item: *const Elem) bool, output_buf: []Elem) bool {
//             return Impl.find_exactly_n_ordered_copies_from_n_ordered_params(List, self, P, params, match_fn, output_buf);
//         }

//         pub inline fn delete_ordered_indexes(self: *List, indexes: []const Idx) void {
//             return Impl.delete_ordered_indexes(List, self, indexes);
//         }

//         // pub inline fn sort(self: *List) void {
//         //     return Internal.sort(List, self);
//         // }

//         // pub inline fn custom_sort(self: *List, algorithm: SortAlgorithm, order_func: *const fn (a: *const List.Elem, b: *const List.Elem) Compare.Order) void {
//         //     return Internal.custom_sort(List, self, algorithm, order_func);
//         // }

//         // pub inline fn is_sorted(self: *List) bool {
//         //     return Internal.is_sorted(List, self);
//         // }

//         // pub inline fn is_sorted_custom(self: *List, compare_fn: *const CompareFn(Elem)) bool {
//         //     return Internal.is_sorted_custom(List, self, compare_fn);
//         // }

//         // pub inline fn insert_one_sorted(self: *List, item: Elem) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted(List, self, item, self.get_alloc());
//         // }

//         // pub inline fn insert_one_sorted_custom(self: *List, item: Elem, compare_fn: *const CompareFn(Elem), comptime shortcut_equal_order: bool) if (RETURN_ERRORS) Error!Idx else Idx {
//         //     return Internal.insert_one_sorted_custom(List, self, item, compare_fn, shortcut_equal_order, self.get_alloc());
//         // }

//         // pub inline fn find_equal_order_idx_sorted(self: *const List, item_to_compare: *const Elem) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted(List, self, item_to_compare);
//         // }

//         // pub fn find_equal_order_idx_sorted_custom(self: *const List, item_to_compare: *const Elem, compare_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_equal_order_idx_sorted_custom(List, self, item_to_compare, compare_fn);
//         // }

//         // pub inline fn find_matching_item_idx_sorted(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_sorted_custom(self: *const List, item_to_find: *const Elem, compare_fn: *const CompareFn(Elem), match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_sorted_custom(List, self, item_to_find, compare_fn, match_fn);
//         // }

//         // pub inline fn find_matching_item_idx(self: *const List, item_to_find: *const Elem) ?Idx {
//         //     return Internal.find_matching_item_idx(List, self, item_to_find);
//         // }

//         // pub fn find_matching_item_idx_custom(self: *const List, item_to_find: *const Elem, match_fn: *const CompareFn(Elem)) ?Idx {
//         //     return Internal.find_matching_item_idx_custom(List, self, item_to_find, match_fn);
//         // }

//         //**************************
//         // std.io.Writer interface *
//         //**************************
//         const WriterHandle = struct {
//             list: *List,
//         };

//         pub const StdWriter = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandle, Allocator.Error, write);

//         pub fn get_std_writer(self: *List) StdWriter {
//             return StdWriter{ .context = .{ .list = self } };
//         }

//         fn write(handle: WriterHandle, bytes: []const u8) Allocator.Error!usize {
//             try handle.list.append_slice(bytes);
//             return bytes.len;
//         }

//         pub const StdWriterNoGrow = if (Elem != u8)
//             @compileError("The Writer interface is only defined for child type `u8` " ++
//                 "but the given type is " ++ @typeName(Elem))
//         else
//             std.io.Writer(WriterHandle, Allocator.Error, write_no_grow);

//         pub fn get_std_writer_no_grow(self: *List) StdWriterNoGrow {
//             return StdWriterNoGrow{ .context = .{ .list = self } };
//         }

//         fn write_no_grow(handle: WriterHandle, bytes: []const u8) error{OutOfMemory}!usize {
//             const available_capacity = handle.list.list.capacity - handle.list.list.items.len;
//             if (bytes.len > available_capacity) return error.OutOfMemory;
//             handle.list.append_slice_assume_capacity(bytes);
//             return bytes.len;
//         }
//     };
// }

// test "List.zig" {
//     const t = std.testing;
//     const alloc = std.heap.page_allocator;
//     const base_opts = ListOptions{
//         .error_behavior = .ALLOCATION_ERRORS_PANIC,
//         .element_type = u8,
//         .index_type = u32,
//     };
//     const List = define_manually_managed_list_type(base_opts);
//     var list = List.new_empty();
//     list.append('H', alloc);
//     list.append('e', alloc);
//     list.append('l', alloc);
//     list.append('l', alloc);
//     list.append('o', alloc);
//     list.append(' ', alloc);
//     list.append_slice("World", alloc);
//     try t.expectEqualStrings("Hello World", list.slice().to_zig_slice());
//     const letter_l = list.remove(2);
//     try t.expectEqual('l', letter_l);
//     try t.expectEqualStrings("Helo World", list.slice().to_zig_slice());
//     list.replace_range(3, 3, &.{ 'a', 'b', 'c' }, alloc);
//     try t.expectEqualStrings("Helabcorld", list.slice().to_zig_slice());
// }
