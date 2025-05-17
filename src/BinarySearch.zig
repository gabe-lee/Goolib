const std = @import("std");

const Root = @import("./_root.zig");
const Compare = Root.Compare;
const Utils = Root.Utils;
// const Order = Compare.Order;
const CompareFn = Compare.CompareFn;
// const ExactlyEqualFn = Compare.ExactlyEqualFn;

pub fn binary_search_insert_index(comptime T: type, item_to_insert: T, sorted_buffer: []const T) usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: T = undefined;
    var insert_greater = false;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = sorted_buffer[mid_idx];
        if (Utils.infered_equal(item_to_insert, mid_val)) return mid_idx;
        insert_greater = Utils.infered_greater_than(item_to_insert, mid_val);
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@intFromBool(insert_greater)];
    }
    return range[1];
}

pub fn binary_search_insert_index_with_transform(comptime T: type, item_to_insert: T, sorted_buffer: []const T, comptime TX: type, transform_fn: *const fn (item: T) TX) usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: T = undefined;
    var insert_greater = false;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = sorted_buffer[mid_idx];
        if (Utils.infered_equal(transform_fn(item_to_insert), transform_fn(mid_val))) return mid_idx;
        insert_greater = Utils.infered_greater_than(transform_fn(item_to_insert), transform_fn(mid_val));
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@intFromBool(insert_greater)];
    }
    return range[1];
}

pub fn binary_search_insert_index_with_transform_and_user_data(comptime T: type, item_to_insert: T, sorted_buffer: []const T, comptime TX: type, transform_fn: *const fn (item: T, user_data: ?*anyopaque) TX, user_data: ?*anyopaque) usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: T = undefined;
    var insert_greater = false;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = sorted_buffer[mid_idx];
        if (Utils.infered_equal(transform_fn(item_to_insert, user_data), transform_fn(mid_val, user_data))) return mid_idx;
        insert_greater = Utils.infered_greater_than(transform_fn(item_to_insert, user_data), transform_fn(mid_val, user_data));
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@intFromBool(insert_greater)];
    }
    return range[1];
}

// pub fn binary_search_exact_match(comptime T: type, item_to_find: *const T, sorted_buffer: []const T, greater_than_fn: *const CompareFn(T), equal_order_fn: *const CompareFn(T), exactly_equal_fn: *const CompareFn(T)) ?usize {
//     var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
//     var new_range: [2][2]usize = undefined;
//     var mid_idx: usize = undefined;
//     var mid_val: *const T = undefined;
//     var find_greater = false;
//     while (range[0] < range[1]) {
//         mid_idx = ((range[1] - range[0]) >> 1) + range[0];
//         mid_val = &sorted_buffer[mid_idx];
//         if (equal_order_fn(item_to_find, mid_val)) {
//             const first_order_match_idx = mid_idx;
//             var found_exact = exactly_equal_fn(item_to_find, mid_val);
//             while (!found_exact) {
//                 mid_idx -= 1;
//                 mid_val = &sorted_buffer[mid_idx];
//                 if (!equal_order_fn(item_to_find, mid_val)) break;
//                 found_exact = exactly_equal_fn(item_to_find, mid_val);
//             }
//             mid_idx = first_order_match_idx;
//             while (!found_exact) {
//                 mid_idx += 1;
//                 mid_val = &sorted_buffer[mid_idx];
//                 if (!equal_order_fn(item_to_find, mid_val)) break;
//                 found_exact = exactly_equal_fn(item_to_find, mid_val);
//             }
//             if (found_exact) return mid_idx;
//             return null;
//         }
//         find_greater = greater_than_fn(item_to_find, mid_val);
//         new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
//         range = new_range[@intFromBool(find_greater)];
//     }
//     return null;
// }

// pub fn define_binary_search_package(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime SHORTCUT_EQUAL_ORDER_VAL: bool) type {
//     return struct {
//         pub inline fn search_insert_index(sorted_buffer: []const ELEMENT_TYPE, insert_order_value: ORDER_NUMERIC_TYPE) usize {
//             return binary_search_insert_index(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, SHORTCUT_EQUAL_ORDER_VAL, sorted_buffer, insert_order_value);
//         }

//         pub inline fn search(sorted_buffer: []const ELEMENT_TYPE, check_order_value: ORDER_NUMERIC_TYPE) ?usize {
//             return binary_search(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, sorted_buffer, check_order_value);
//         }
//     };
// }
