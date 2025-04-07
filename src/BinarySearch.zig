pub fn binary_search_insert_index(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime SHORTCUT_EQUAL_ORDER_VAL: bool, sorted_buffer: []const ELEMENT_TYPE, insert_order_value: ORDER_NUMERIC_TYPE) usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid: usize = undefined;
    var mid_val: ORDER_NUMERIC_TYPE = undefined;
    var insert_val_larger: bool = false;
    while (range[0] < range[1]) {
        mid = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = ORDER_FUNC(&sorted_buffer[mid]);
        if (SHORTCUT_EQUAL_ORDER_VAL and mid_val == insert_order_value) return mid;
        insert_val_larger = insert_order_value > mid_val;
        new_range = [2][2]usize{ [2]usize{ range[0], mid }, [2]usize{ mid + 1, range[1] } };
        range = new_range[@intFromBool(insert_val_larger)];
    }
    return range[1];
}

pub fn binary_search(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, sorted_buffer: []const ELEMENT_TYPE, check_order_value: ORDER_NUMERIC_TYPE) ?usize {
    var range: [2]usize = [2]usize{ 0, sorted_buffer.len };
    var new_range: [2][2]usize = undefined;
    var mid: usize = undefined;
    var mid_val: ORDER_NUMERIC_TYPE = undefined;
    var check_val_larger: bool = false;
    while (range[0] < range[1]) {
        mid = ((range[1] - range[0]) >> 1) + range[0];
        mid_val = ORDER_FUNC(&sorted_buffer[mid]);
        if (mid_val == check_order_value) return mid;
        check_val_larger = check_order_value > mid_val;
        new_range = [2][2]usize{ [2]usize{ range[0], mid }, [2]usize{ mid + 1, range[1] } };
        range = new_range[@intFromBool(check_val_larger)];
    }
    return null;
}

pub fn define_binary_search_package(comptime ELEMENT_TYPE: type, comptime ORDER_NUMERIC_TYPE: type, comptime ORDER_FUNC: fn (element: *const ELEMENT_TYPE) ORDER_NUMERIC_TYPE, comptime SHORTCUT_EQUAL_ORDER_VAL: bool) type {
    return struct {
        pub inline fn search_insert_index(sorted_buffer: []const ELEMENT_TYPE, insert_order_value: ORDER_NUMERIC_TYPE) usize {
            return binary_search_insert_index(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, SHORTCUT_EQUAL_ORDER_VAL, sorted_buffer, insert_order_value);
        }

        pub inline fn search(sorted_buffer: []const ELEMENT_TYPE, check_order_value: ORDER_NUMERIC_TYPE) ?usize {
            return binary_search(ELEMENT_TYPE, ORDER_NUMERIC_TYPE, ORDER_FUNC, sorted_buffer, check_order_value);
        }
    };
}
