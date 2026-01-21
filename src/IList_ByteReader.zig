// //! //TODO Documentation
// //! #### License: Zlib

// // zlib license
// //
// // Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
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
// const std = @import("std");
// const math = std.math;
// const Root = @import("./_root.zig");
// const Types = Root.Types;
// const Assert = Root.Assert;
// const Allocator = std.mem.Allocator;
// const AllocInfal = Root.AllocatorInfallible;
// const DummyAllocator = Root.DummyAllocator;
// const _Flags = Root.Flags;
// const IteratorState = Root.IList_Iterator.IteratorState;

// const Utils = Root.Utils;

// pub const SliceAdapter = @import("./IList_SliceAdapter.zig").SliceAdapter;
// pub const ArrayListAdapter = @import("./IList_ArrayListAdapter.zig").ArrayListAdapter;
// pub const List = @import("./IList_List.zig").List;
// pub const RingList = @import("./IList_RingList.zig").RingList;
// pub const MultiSortList = @import("./IList_MultiSortList.zig").MultiSortList;
// pub const Concrete = @import("./IList_Concrete.zig");

// pub const FilterMode = Concrete.FilterMode;
// pub const CountResult = Concrete.CountResult;
// pub const CopyResult = Concrete.CopyResult;
// pub const LocateResult = Concrete.LocateResult;
// pub const SearchResult = Concrete.SearchResult;
// pub const InsertIndexResult = Concrete.InsertIndexResult;
// pub const ListError = Concrete.ListError;
// pub const Range = Concrete.Range;
// pub const Endian = Root.CommonTypes.Endian;

// pub const IList = Root.IList;
// pub const IListU8 = Root.IList.IList(u8);

// pub const ByteReader = struct {
//     src: IListU8,
//     bufs: ?[2][]u8 = null,
//     src_pos: usize,
//     buf_start: usize = 0,
//     buf_end: usize = 0,

//     fn tmp_buffers(self: ByteReader) ?[2][]u8 {
//         if (self.bufs) |bufs| {
//             return bufs;
//         }
//         return null;
//     }

//     fn PeekResult(comptime T: type, comptime N: comptime_int) type {
//         return switch (N) {
//             1 => struct {
//                 val: T,
//                 buf_start_after_commit: usize,
//                 src_pos_after_commit: usize,
//                 valid: bool = true,
//             },
//             else => struct {
//                 val: [N]T,
//                 buf_start_after_commit: usize,
//                 src_pos_after_commit: usize,
//                 valid: bool = true,
//             },
//         };
//     }

//     pub fn peek(self: *ByteReader, comptime T: type, comptime N: comptime_int, comptime buffer_endianess: Root.CommonTypes.Endian) PeekResult(T, N) {
//         var result = PeekResult(T, N){
//             .buf_start_after_commit = self.buf_start,
//             .src_pos_after_commit = self.src_pos,
//         };
//         var result_bytes = Utils.scalar_ptr_as_byte_slice(&result.val);
//         if (buffer_endianess == Endian.NATIVE or @sizeOf(T) == 1) {
//             var idx: usize = 0;
//             while (idx < result_bytes.len) {
//                 if (self.tmp_buffers()) |bufs| {
//                     const remaining_buf_0 = bufs[0][self.buf_start..self.buf_end];
//                     const max_from_buf_0 = @min(@sizeOf(T), remaining_buf_0.len);
//                     @memcpy(result_bytes[0..max_from_buf_0], remaining_buf_0[0..max_from_buf_0]);
//                     result.buf_start_after_commit += max_from_buf_0;
//                     idx += max_from_buf_0;
//                     if (idx < result_bytes.len) {
//                         const remaining_needed = result_bytes.len - idx;
//                         const remaining_result_bytes = result_bytes[idx..];
//                         const last_idx = self.src.nth_next_idx(self.src_pos, remaining_needed - 1);
//                         if (!self.src.idx_valid(last_idx)) {
//                             result.valid = false;
//                             return result;
//                         }
//                         const needed_range = Range{
//                             .first_idx = self.src_pos,
//                             .last_idx = last_idx,
//                         };
//                         if (self.src.has_native_slice()) {
//                             const slice = self.src.native_slice(needed_range);
//                             @memcpy(remaining_result_bytes, slice);
//                         } else {
//                             var buf_1_list = IList.SliceAdapter(u8).interface_no_alloc(&bufs[1]);
//                             while (idx < result_bytes.len) {

//                             }
//                         }
//                     }
//                 } else {}
//             }
//             if (self.remaining_buf()) |buf| {
//                 const max_from_buf = @min(@sizeOf(T), buf.len);
//                 @memcpy(result_bytes[0..max_from_buf], buf[0..max_from_buf]);
//                 result.buf_start_after_commit += max_from_buf;
//                 idx += max_from_buf;
//             }
//             if (idx < result_bytes.len) {
//                 const remaining_needed = result_bytes.len - idx;
//                 const remaining_result_bytes = result_bytes[idx..];
//                 const last_idx = self.src.nth_next_idx(self.src_pos, remaining_needed - 1);
//                 if (!self.src.idx_valid(last_idx)) {
//                     result.valid = false;
//                     return result;
//                 }
//                 const needed_range = Range{
//                     .first_idx = self.src_pos,
//                     .last_idx = last_idx,
//                 };
//                 if (self.src.has_native_slice()) {
//                     const slice = self.src.native_slice(needed_range);
//                     @memcpy(remaining_result_bytes, slice);
//                 } else {
//                     _ = self.src.copy_to(.use_range(needed_range), .new_range(IList.SliceAdapter(u8).interface_no_alloc(&remaining_result_bytes), 0, remaining_needed - 1));
//                 }
//                 result.src_pos_after_commit = self.src.next_idx(last_idx);
//             }
//         } else {
//             var write_count: usize = 0;
//             var write_idx: usize = result_bytes.len;
//             if (self.remaining_buf()) |buf| {
//                 const max_from_buf = @min(@sizeOf(T), buf.len);
//                 var read_idx: usize = 0;
//                 while (read_idx < max_from_buf) : (read_idx += 1) {
//                     write_idx -= 1;
//                     result_bytes[write_idx] = buf[read_idx];
//                 }
//                 result.buf_start_after_commit += max_from_buf;
//                 write_count += max_from_buf;
//             }
//             if (write_count < result_bytes.len) {
//                 const remaining_needed = result_bytes.len - write_count;
//                 const remaining_result_bytes = result_bytes[0..write_idx];
//                 const last_idx = self.src.nth_next_idx(self.src_pos, remaining_needed - 1);
//                 if (!self.src.idx_valid(last_idx)) {
//                     result.valid = false;
//                     return result;
//                 }
//                 const needed_range = Range{
//                     .first_idx = self.src_pos,
//                     .last_idx = last_idx,
//                 };
//                 if (self.src.has_native_slice()) {
//                     const slice = self.src.native_slice(needed_range);
//                     var read_idx: usize = 0;
//                     while (read_idx < slice.len) : (read_idx += 1) {
//                         write_idx -= 1;
//                         result_bytes[write_idx] = slice[read_idx];
//                     }
//                 } else {
//                     _ = self.src.copy_to(.use_range(needed_range), .new_range_rev(IList.SliceAdapter(u8).interface_no_alloc(&remaining_result_bytes), 0, remaining_needed - 1));
//                 }
//                 result.src_pos_after_commit = self.src.next_idx(last_idx);
//             }
//         }
//     }

//     pub fn commit_peeked(self: *ByteReader, peek_result: anytype) void {
//         self.buf_start = peek_result.buf_start_after_commit;
//         if (self.buf_start == self.buf_end) {
//             self.buf_start = 0;
//             self.buf_end = 0;
//         }
//     }
// };
