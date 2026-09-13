// pub const ListOptions = struct {
//     element_type: type,
//     alignment: ?u29 = null,
//     alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
//     growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
//     index_type: type = usize,
//     secure_wipe_bytes: bool = false,
//     extra_data_type: type = void,

//     pub fn auto_singly_linked_list(comptime options_no_extra: ListOptionsNoExtra) ListOptions {
//         const Extra = struct {
//             first_free_idx: options_no_extra.index_type = 0,
//             free_count: options_no_extra.index_type = 0,
//             first_used_idx: options_no_extra.index_type = 0,
//             used_count: options_no_extra.index_type = 0,
//         };
//         return ListOptions{
//             .element_type = options_no_extra.element_type,
//             .alignment = options_no_extra.alignment,
//             .alloc_error_behavior = options_no_extra.alloc_error_behavior,
//             .growth_model = options_no_extra.growth_model,
//             .index_type = options_no_extra.index_type,
//             .secure_wipe_bytes = options_no_extra.secure_wipe_bytes,
//             .extra_data_type = Extra,
//         };
//     }

//     pub fn auto_doubly_linked_list(comptime options_no_extra: ListOptionsNoExtra, comptime next_idx_field: []const u8, comptime prev_idx_field: []const u8) ListOptions {
//         const Extra = struct {
//             first_free_idx: options_no_extra.index_type = 0,
//             last_free_idx: options_no_extra.index_type = 0,
//             free_count: options_no_extra.index_type = 0,
//             first_used_idx: options_no_extra.index_type = 0,
//             last_used_idx: options_no_extra.index_type = 0,
//             used_count: options_no_extra.index_type = 0,
//         };
//         return ListOptions{
//             .element_type = options_no_extra.element_type,
//             .alignment = options_no_extra.alignment,
//             .alloc_error_behavior = options_no_extra.alloc_error_behavior,
//             .growth_model = options_no_extra.growth_model,
//             .index_type = options_no_extra.index_type,
//             .secure_wipe_bytes = options_no_extra.secure_wipe_bytes,
//             .extra_data_type = Extra,
//         };
//     }
// };

// pub const ListOptionsNoExtra = struct {
//     element_type: type,
//     alignment: ?u29 = null,
//     alloc_error_behavior: AllocErrorBehavior = .ALLOCATION_ERRORS_PANIC,
//     growth_model: GrowthModel = .GROW_BY_50_PERCENT_ATOMIC_PADDING,
//     index_type: type = usize,
//     secure_wipe_bytes: bool = false,
// };

// pub fn ListMethodOverrides(comptime options: ListOptions) type {
//     return struct {
//         const Self = @This();

//         insert_slot_assume_capacity: ?*const fn (list: []options.element_type, cap: options.index_type, extra_data: *options.extra_data_type) ?options.index_type = null,
//         release_used_index: ?*const fn (list: []options.element_type, cap: options.index_type, index: options.index_type, extra_data: *options.extra_data_type) void = null,
//         on_element_moved: ?*const fn (list: []options.element_type, cap: options.index_type, element: *options.element_type, old_index: options.index_type, new_index: options.index_type, extra_data: *options.extra_data_type) void = null,
//         on_element_added: ?*const fn (list: []options.element_type, cap: options.index_type, element: *options.element_type, new_index: options.index_type, extra_data: *options.extra_data_type) void = null,
//         on_element_removed: ?*const fn (list: []options.element_type, cap: options.index_type, element: *options.element_type, old_index: options.index_type, extra_data: *options.extra_data_type) void = null,

//         pub fn auto_singly_linked_list(comptime next_idx_field: []const u8) Self {
//             const proto = struct {
//                 fn try_claim(list: []options.element_type, cap: options.index_type, extra_data: *options.extra_data_type) ?options.index_type {
//                     _ = cap;
//                     if (extra_data.free_count == 0) return null;
//                     const claimed_idx = extra_data.first_free_idx;
//                     var first_free: *options.element_type = &list[claimed_idx];
//                     extra_data.free_count -= 1;
//                     extra_data.first_free_idx = @field(first_free, next_idx_field);
//                     @field(first_free, next_idx_field) = extra_data.first_used_idx;
//                     extra_data.first_used_idx = claimed_idx;
//                     extra_data.used_count += 1;
//                     return claimed_idx;
//                 }

//                 fn release_idx(list: []options.element_type, cap: options.index_type, index: options.index_type, extra_data: *options.extra_data_type) void {
//                     _ = cap;
//                     var first_free: *options.element_type = &list[index];
//                     @field(first_free, next_idx_field) = extra_data.first_free_idx;
//                     extra_data.free_count += 1;
//                     extra_data.first_free_idx = index;
//                 }

//                 fn on_move(list: []options.element_type, cap: options.index_type, element: *options.element_type, old_index: options.index_type, new_index: options.index_type, extra_data: *options.extra_data_type) void {
//                     _ = cap;
//                     var i: options.index_type = 0;
//                     var item_pointing_to_old_idx: *options.element_type = undefined;
//                     var found_item_pointing_to_old: bool = false;
//                     var item_pointing_to_new_idx: *options.element_type = undefined;
//                     var found_item_pointing_to_new: bool = false;
//                     while (i < list.len) : (i += 1) {
//                         const prev_item: *options.element_type = &list[i];
//                         if (@field(prev_item, next_idx_field) == old_index) {
//                             item_pointing_to_new_idx = prev_item;
//                             found_item_pointing_to_old = true;
//                         }
//                         if (@field(prev_item, next_idx_field) == new_index) {
//                             item_pointing_to_new_idx = prev_item;
//                             found_item_pointing_to_old = true;
//                         }
//                     }
//                 }
//             };
//         }
//     };
// }
