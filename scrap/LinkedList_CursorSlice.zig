// /// A variant of `LLSlice` that keeps track of a logical cursor index within the slice
// /// and holds a reference to the list to which it belongs for convenience.
// ///
// /// Users can lookup items based on their logical nth position in the list,
// /// and traversing the list may be faster in some cases by determining if it would
// /// be faster to get there from the current cursor position or from the start/end
// /// of the list
// pub const LLCursorSlice = struct {
//     slice: LLSlice,
//     list_ref: *LinkedList,
//     cursor_pos: Idx = NULL_IDX,
//     cursor_idx: Idx = NULL_IDX,

//     pub fn goto_pos(self: *LLCursorSlice, pos: Idx) void {
//         assert_with_reason(pos < self.slice.count, @src(), "pos {d} is out of bounds for LLSlice (count/len = {d})", .{ pos, self.slice.count });
//         if (pos > self.cursor_pos) {
//             self.move_forward_n_positions(pos - self.cursor_pos);
//         } else {
//             self.move_backward_n_positions(self.cursor_pos - pos);
//         }
//     }

//     pub fn move_forward_n_positions(self: *LLCursorSlice, n: Idx) void {
//         assert_with_reason(self.cursor_pos + n < self.slice.count, @src(), "cursor pos {d} (curr {d} + {d}) is out of bounds for slice count/len ({d})", .{ self.cursor_pos + n, self.cursor_pos, n, self.slice.count });
//         if (FORWARD) {
//             const from_curr = n;
//             if (BACKWARD) {
//                 const from_end = self.slice.count - self.cursor_pos + n;
//                 if (from_end < from_curr) {
//                     self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.list, self.slice.last, from_end, false, 0);
//                 } else {
//                     self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.list, self.cursor_idx, from_curr, false, 0);
//                 }
//             } else {
//                 self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.list, self.cursor_idx, from_curr, false, 0);
//             }
//         } else {
//             const from_end = self.slice.count - self.cursor_pos + n;
//             self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.list, self.slice.last, from_end, false, 0);
//         }
//         self.cursor_pos += n;
//     }

//     pub fn move_backward_n_positions(self: *LLCursorSlice, n: Idx) void {
//         assert_with_reason(self.cursor_pos >= n, @src(), "cursor pos {d} (curr {d} - {d}) is out of bounds for slice count/len ({d})", .{ self.cursor_pos - n, self.cursor_pos, n, self.slice.count });
//         if (BACKWARD) {
//             const from_curr = n;
//             if (FORWARD) {
//                 const from_start = self.cursor_pos - n;
//                 if (from_start < from_curr) {
//                     self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.list, self.slice.first, from_start, false, 0);
//                 } else {
//                     self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.list, self.cursor_idx, from_curr, false, 0);
//                 }
//             } else {
//                 self.cursor_idx = Internal.find_idx_n_places_before_this_one_with_fallback_start(self.list_ref, self.slice.list, self.cursor_idx, from_curr, false, 0);
//             }
//         } else {
//             const from_start = self.cursor_pos - n;
//             self.cursor_idx = Internal.find_idx_n_places_after_this_one_with_fallback_start(self.list_ref, self.slice.list, self.slice.first, from_start, false, 0);
//         }
//         self.cursor_pos -= n;
//     }

//     pub fn get_current_ptr(self: LLCursorSlice) *Elem {
//         return self.list_ref.get_ptr(self.cursor_idx);
//     }

//     pub fn grow_end_rightward(self: *LLCursorSlice, count: Idx) void {
//         self.slice.grow_end_rightward(self.list_ref, count);
//     }

//     pub fn shrink_end_leftward(self: *LLCursorSlice, count: Idx) void {
//         self.slice.shrink_end_leftward(self.list_ref, count);
//         if (self.cursor_pos >= self.slice.count) {
//             self.cursor_pos = self.slice.count - 1;
//             self.cursor_idx = self.slice.last;
//         }
//     }

//     pub fn grow_start_leftward(self: *LLCursorSlice, count: Idx) void {
//         self.slice.grow_start_leftward(self.list_ref, count);
//         self.cursor_pos += count;
//     }

//     pub fn shrink_start_rightward(self: *LLCursorSlice, count: Idx) void {
//         self.slice.shrink_start_rightward(self.list_ref, count);
//         if (self.cursor_pos < count) {
//             self.cursor_pos = 0;
//             self.cursor_idx = self.slice.first;
//         } else {
//             self.cursor_pos -= count;
//         }
//     }

//     pub fn slide_right(self: *LLCursorSlice, count: Idx) void {
//         self.slice.slide_right(self.list_ref, count);
//         if (self.cursor_pos < count) {
//             self.cursor_pos = 0;
//             self.cursor_idx = self.slice.first;
//         } else {
//             self.cursor_pos -= count;
//         }
//     }

//     pub fn slide_left(self: *LLCursorSlice, count: Idx) void {
//         self.slice.slide_left(self.list_ref, count);
//         if (self.slice.count - self.cursor_pos <= count) {
//             self.cursor_pos = self.slice.count - 1;
//             self.cursor_idx = self.slice.last;
//         }
//     }
// };

// pub inline fn to_cursor_slice(self: LLSlice, list_ref: *LinkedList) LLCursorSlice {
//                 return LLCursorSlice{
//                     .slice = self,
//                     .list_ref = list_ref,
//                     .cursor_pos = 0,
//                     .cursor_idx = self.first,
//                 };
//             }
