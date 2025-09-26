pub fn Result(comptime T: type, comptime T_UNINIT: T, comptime ERR: anyerror, comptime NO_ERROR: @TypeOf(ERR)) type {
    return struct {
        const Self = @This();

        val: T = T_UNINIT,
        err: ERR = NO_ERROR,

        pub fn new(val: T) Self {
            return Self{
                .val = val,
            };
        }
        pub fn is_err(self: Self) bool {
            return self.err != NO_ERROR;
        }
        pub fn try_val(self: Self) ERR!T {
            if (self.err != NO_ERROR) {
                return self.err;
            }
            return self.val;
        }
    };
}
