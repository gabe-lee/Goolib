const std = @import("std");

const Root = @import("./_root.zig");
const Compare = Root.Compare;
const Order = Compare.Order;
const CompareFn = Compare.CompareFn;
const ExactlyEqualFn = Compare.ExactlyEqualFn;

pub fn binary_search_insert_index(comptime T: type, item_to_insert: *const T, sorted_buffer: []const T, compare_fn: CompareFn(T), comptime shortcut_equal_order: bool) usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: *const T = undefined;
    var order: Order = Order.A_EQUALS_B;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = &sorted_buffer[mid_idx];
        order = compare_fn(item_to_insert, mid_val);
        if (shortcut_equal_order and order == .A_EQUALS_B) return mid_idx;
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@max(0, @intFromEnum(order))];
    }
    return range[1];
}

pub fn binary_search_by_order(comptime T: type, item_to_find: *const T, sorted_buffer: []const T, compare_fn: CompareFn(T)) ?usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: *const T = undefined;
    var order: Compare.Order = Order.A_EQUALS_B;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = &sorted_buffer[mid_idx];
        order = compare_fn(item_to_find, mid_val);
        if (order == .A_EQUALS_B) return mid_idx;
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@max(0, @intFromEnum(order))];
    }
    return null;
}

pub fn binary_search_exatly_equal(comptime T: type, item_to_find: *const T, sorted_buffer: []const T, compare_fn: CompareFn(T), exactly_equal_fn: ExactlyEqualFn(T)) ?usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid_idx: usize = undefined;
    var mid_val: *const T = undefined;
    var order: Compare.Order = Order.A_EQUALS_B;
    while (range[0] < range[1]) {
        mid_idx = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = &sorted_buffer[mid_idx];
        order = compare_fn(item_to_find, mid_val);
        if (order == .A_EQUALS_B) {
            const first_order_match_idx = mid_idx;
            var found_exact = exactly_equal_fn(item_to_find, mid_val);
            while (!found_exact) {
                mid_idx -= 1;
                mid_val = &sorted_buffer[mid_idx];
                order = compare_fn(item_to_find, mid_val);
                if (order != .A_EQUALS_B) break;
                found_exact = exactly_equal_fn(item_to_find, mid_val);
            }
            mid_idx = first_order_match_idx;
            while (!found_exact) {
                mid_idx += 1;
                mid_val = &sorted_buffer[mid_idx];
                order = compare_fn(item_to_find, mid_val);
                if (order != .A_EQUALS_B) break;
                found_exact = exactly_equal_fn(item_to_find, mid_val);
            }
            if (found_exact) return mid_idx;
            return null;
        }
        new_range = [2][2]usize{ [2]usize{ range[0], mid_idx }, [2]usize{ mid_idx + 1, range[1] } };
        range = new_range[@max(0, @intFromEnum(order))];
    }
    return null;
}

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
