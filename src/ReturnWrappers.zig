const Root = @import("root");

// pub const Result = enum(u8) {
//     failure = 0,
//     success = 1,

//     pub inline fn is_success(self: Result) bool {
//         return self == .success;
//     }
//     pub inline fn is_failure(self: Result) bool {
//         return self == .failure;
//     }
//     pub inline fn from_bool(val: bool) Result {
//         return @enumFromInt(@as(u8, @intCast(@intFromBool(val))));
//     }
// };

pub const OptionalTag = enum(u8) {
    none = 0,
    val = 1,
};

pub fn Optional(comptime TYPE: type) type {
    return union(OptionalTag) {
        none: void,
        val: TYPE,

        const Self = @This();

        pub inline fn new_none() Self {
            return Self{ .none = void{} };
        }
        pub inline fn new_val(val: TYPE) Self {
            return Self{ .val = val };
        }
        pub inline fn is_none(self: *const Self) bool {
            return self == .none;
        }
        pub inline fn is_val(self: *const Self) bool {
            return self == .val;
        }
        pub inline fn same_none_diff_val_type(self: *const Self, comptime new_val_type: type) Self(new_val_type) {
            return Self(new_val_type){ .none = self.none };
        }
    };
}

const ResultTag = enum(u8) {
    err = 0,
    val = 1,
};

pub fn Result(comptime VAL_TYPE: type, comptime ERR_TYPE: type) type {
    return union(ResultTag) {
        err: ERR_TYPE,
        val: VAL_TYPE,

        const Self = @This();

        pub inline fn new_err(err: ERR_TYPE) Self {
            return Self{ .err = err };
        }
        pub inline fn new_val(val: VAL_TYPE) Self {
            return Self{ .val = val };
        }
        pub inline fn is_err(self: *const Self) bool {
            return self == .err;
        }
        pub inline fn is_val(self: *const Self) bool {
            return self == .val;
        }
        pub inline fn same_err_diff_val_type(self: *const Self, comptime new_val_type: type) Self(ERR_TYPE, new_val_type) {
            return Self(ERR_TYPE, new_val_type){ .err = self.err };
        }
    };
}

pub const SuccessTag = enum(u8) {
    err = 0,
    ok = 1,
};

pub fn Success(comptime ERR_TYPE: type) type {
    return union(SuccessTag) {
        err: ERR_TYPE,
        ok: void,

        const Self = @This();

        pub inline fn new_err(err: ERR_TYPE) Self {
            return Self{ .failure = err };
        }
        pub inline fn new_ok() Self {
            return Self{ .ok = void{} };
        }
        pub inline fn is_err(self: *const Self) bool {
            return self == .err;
        }
        pub inline fn is_ok(self: *const Self) bool {
            return self == .ok;
        }
    };
}
