const std = @import("std");

const Root = @import("./_root.zig");
const LOG_PREFIX = Root.LOG_PREFIX ++ "[Flags] ";
const Utils = Root.Utils;
const comptime_assert_with_reason = Utils.comptime_assert_with_reason;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

fn NoGroups(comptime T: type) type {
    return enum(T) {
        NONE = 0,
        ALL = @bitCast(math.maxInt(std.meta.Int(.unsigned, @typeInfo(T).int.bits))),
    };
}

pub fn Flags(comptime FLAGS_ENUM: type, comptime GROUPS_ENUM_OR_NULL: ?type) type {
    const INFO_1 = @typeInfo(FLAGS_ENUM);
    comptime_assert_with_reason(INFO_1 == .@"enum", LOG_PREFIX ++ "parameter `FLAGS_ENUM` must be an enum type");
    const E_INFO = INFO_1.@"enum";
    const GROUPS_ENUM = GROUPS_ENUM_OR_NULL orelse NoGroups(E_INFO.tag_type);
    const INFO_2 = @typeInfo(GROUPS_ENUM);
    comptime_assert_with_reason(INFO_2 == .@"enum", LOG_PREFIX ++ "parameter `GROUPS_ENUM_OR_NULL` must be an enum type or `null`");
    const G_INFO = INFO_2.@"enum";
    comptime_assert_with_reason(G_INFO.tag_type == E_INFO.tag_type, "GROUPS_ENUM must have the exact same tag type as FLAGS_ENUM");
    return extern struct {
        raw: EnumInt = 0,

        const Self = @This();
        pub const EnumInt: type = E_INFO.tag_type;
        pub const BitIndex: type = Log2Int(EnumInt);
        pub const BitCount: type = Log2IntCeil(EnumInt);
        pub const Flag = FLAGS_ENUM;
        pub const Group = GROUPS_ENUM;

        pub inline fn blank() Self {
            return Self{ .raw = 0 };
        }
        pub fn new_raw(flags: []const Flag) EnumInt {
            var r: EnumInt = 0;
            for (flags) |flag| {
                r |= @intFromEnum(flag);
            }
            return r;
        }
        pub fn new(flags: []const Flag) Self {
            var self = Self{ .raw = 0 };
            for (flags) |flag| {
                self.raw |= @intFromEnum(flag);
            }
            return self;
        }
        pub inline fn from_raw(val: EnumInt) Self {
            return Self{ .raw = val };
        }
        pub inline fn copy(self: Self) Self {
            return Self{ .raw = self.raw };
        }

        pub inline fn set(self: *Self, flag: Flag) void {
            self.raw |= @intFromEnum(flag);
        }
        pub inline fn set_many(self: *Self, flags: []const Flag) void {
            for (flags) |flag| {
                self.raw |= @intFromEnum(flag);
            }
        }

        pub inline fn clear_group_then_set(self: *Self, group: Group, flag: Flag) void {
            self.raw &= ~@intFromEnum(group);
            self.raw |= @intFromEnum(flag);
        }
        pub inline fn clear_group_then_set_many(self: *Self, group: Group, flags: []const Flag) void {
            self.raw &= ~@intFromEnum(group);
            for (flags) |flag| {
                self.raw |= @intFromEnum(flag);
            }
        }
        pub inline fn clear_many_groups_then_set_many(self: *Self, groups: []const Group, flags: []const Flag) void {
            for (groups) |group| {
                self.raw &= ~@intFromEnum(group);
            }
            for (flags) |flag| {
                self.raw |= @intFromEnum(flag);
            }
        }

        pub inline fn clear_all(self: *Self) void {
            self.raw = 0;
        }
        pub inline fn clear(self: *Self, flag: Flag) void {
            self.raw &= ~@intFromEnum(flag);
        }
        pub inline fn clear_many(self: *Self, flags: []const Flag) void {
            for (flags) |flag| {
                self.raw &= ~@intFromEnum(flag);
            }
        }
        pub inline fn has_flag(self: *Self, flag: Flag) bool {
            return self.raw & @intFromEnum(flag) == @intFromEnum(flag);
        }
        pub inline fn has_all_flags(self: *Self, flags: []const Flag) bool {
            var composite: EnumInt = 0;
            for (flags) |flag| {
                composite |= @intFromEnum(flag);
            }
            return self.raw & composite == composite;
        }
        pub inline fn isolate_group(self: Self, group: Group) Self {
            return Self{ .raw = self.raw & @intFromEnum(group) };
        }
        pub inline fn isolate_group_as_int_aligned_to_bit_0(self: Self, group: Group) EnumInt {
            return (self.raw & @intFromEnum(group)) >> @intCast(@ctz(@intFromEnum(group)));
        }
        pub inline fn clear_group(self: *Self, group: Group) void {
            self.raw &= ~@intFromEnum(group);
        }
        pub inline fn set_entire_group(self: *Self, group: Group) void {
            self.raw |= @intFromEnum(group);
        }
        pub inline fn has_entire_group_set(self: Self, group: Group) bool {
            return self.raw & @intFromEnum(group) == @intFromEnum(group);
        }
        pub inline fn set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            self.raw |= ((val) << @intCast(@ctz(@intFromEnum(group))));
        }
        pub inline fn clear_and_set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            self.raw &= ~@intFromEnum(group);
            self.raw |= ((val) << @intCast(@ctz(@intFromEnum(group))));
        }
        pub inline fn clear_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            self.raw &= ~((val) << @intCast(@ctz(@intFromEnum(group))));
        }
    };
}
