const std = @import("std");
const meta = std.meta;
const math = std.math;
const Log2Int = math.Log2Int;
const Log2IntCeil = math.Log2IntCeil;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const Assert = Root.Assert;
const assert_with_reason = Assert.assert_with_reason;

pub fn Flags(comptime FLAGS_ENUM: type, comptime GROUPS_OR_NULL: ?Groups) type {
    const INFO_1 = @typeInfo(FLAGS_ENUM);
    assert_with_reason(INFO_1 == .@"enum", @inComptime(), @src(), @This(), "parameter `FLAGS_ENUM` must be an enum type");
    const E_INFO = INFO_1.@"enum";
    assert_with_reason(@typeInfo(E_INFO.tag_type).int.signedness == .unsigned, @inComptime(), @src(), @This(), "parameter `FLAGS_ENUM` tage type must be an unsigned integer type");
    const GROUPS = if (GROUPS_OR_NULL) |groups_struct| BuildGroups(groups_struct) else BuildGroups(Groups.none(FLAGS_ENUM));
    const A: E_INFO.tag_type = combine: {
        var a: E_INFO.tag_type = 0;
        for (E_INFO.fields) |field| {
            a |= field.value;
        }
        break :combine a;
    };
    return extern struct {
        raw: EnumInt = 0,

        const Self = @This();
        pub const EnumInt: type = E_INFO.tag_type;
        pub const BitIndex: type = Log2Int(EnumInt);
        pub const BitCount: type = Log2IntCeil(EnumInt);
        pub const Flag = FLAGS_ENUM;
        pub const GroupsInfo = GROUPS;
        pub const Group = GroupsInfo.Name;
        pub const ALL = Self{ .raw = A };

        pub inline fn blank() Self {
            return Self{ .raw = 0 };
        }
        pub inline fn all() Self {
            return ALL;
        }

        pub fn flags(flags__: []const Flag) Self {
            var self = Self{ .raw = 0 };
            for (flags__) |flag_| {
                self.raw |= @intFromEnum(flag_);
            }
            return self;
        }
        pub fn flag(flag_: Flag) Self {
            return Self{ .raw = @intFromEnum(flag_) };
        }
        pub inline fn from_raw(val: EnumInt) Self {
            return Self{ .raw = val };
        }
        pub inline fn copy(self: Self) Self {
            return Self{ .raw = self.raw };
        }

        pub inline fn set(self: *Self, flag_: Flag) void {
            self.raw |= @intFromEnum(flag_);
        }
        pub inline fn set_many(self: *Self, flags_: []const Flag) void {
            for (flags_) |flag_| {
                self.raw |= @intFromEnum(flag_);
            }
        }

        pub inline fn clear_group_then_set(self: *Self, group: Group, flag_: Flag) void {
            self.raw &= GroupsInfo.inverse_bits(group);
            self.raw |= @intFromEnum(flag_);
        }
        pub inline fn clear_group_then_set_many(self: *Self, group: Group, flags_: []const Flag) void {
            self.raw &= GroupsInfo.inverse_bits(group);
            for (flags_) |flag_| {
                self.raw |= @intFromEnum(flag_);
            }
        }
        pub inline fn clear_many_groups_then_set_many(self: *Self, groups: []const Group, flags_: []const Flag) void {
            for (groups) |group| {
                self.raw &= GroupsInfo.inverse_bits(group);
            }
            for (flags_) |flag_| {
                self.raw |= @intFromEnum(flag_);
            }
        }

        pub inline fn clear_all(self: *Self) void {
            self.raw = 0;
        }
        pub inline fn clear(self: *Self, flag_: Flag) void {
            self.raw &= ~@intFromEnum(flag_);
        }
        pub inline fn clear_many(self: *Self, flags_: []const Flag) void {
            for (flags_) |flag_| {
                self.raw &= ~@intFromEnum(flag_);
            }
        }
        pub inline fn has_flag(self: *Self, flag_: Flag) bool {
            return self.raw & @intFromEnum(flag_) == @intFromEnum(flag_);
        }
        pub inline fn has_all_flags_(self: *Self, flags_: []const Flag) bool {
            var composite: EnumInt = 0;
            for (flags_) |flag_| {
                composite |= @intFromEnum(flag_);
            }
            return self.raw & composite == composite;
        }
        pub inline fn isolate_group(self: Self, group: Group) Self {
            return Self{ .raw = self.raw & GroupsInfo.bits(group) };
        }
        pub inline fn isolate_group_as_int_aligned_to_bit_0(self: Self, group: Group) EnumInt {
            return (self.raw & GroupsInfo.bits(group)) >> GroupsInfo.ctz(group);
        }
        pub inline fn clear_group(self: *Self, group: Group) void {
            self.raw &= GroupsInfo.inverse_bits(group);
        }
        pub inline fn set_entire_group(self: *Self, group: Group) void {
            self.raw |= GroupsInfo.bits(group);
        }
        pub inline fn has_entire_group_set(self: Self, group: Group) bool {
            const group_bits = GroupsInfo.bits(group);
            return self.raw & group_bits == group_bits;
        }
        pub inline fn has_any_flag_in_group_set(self: Self, group: Group) bool {
            return self.raw & GroupsInfo.bits(group) > 0;
        }
        pub inline fn set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            const masked_val = ((val) << GroupsInfo.ctz(group)) & GroupsInfo.bits(group);
            self.raw |= masked_val;
        }
        pub inline fn clear_and_set_group_from_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            self.raw &= GroupsInfo.inverse_bits(group);
            const masked_val = ((val) << GroupsInfo.ctz(group)) & GroupsInfo.bits(group);
            self.raw |= masked_val;
        }
        pub inline fn partial_clear_group_from_inverse_of_int_aligned_at_bit_0(self: *Self, group: Group, val: EnumInt) void {
            const masked_val = ((val) << GroupsInfo.ctz(group)) & GroupsInfo.bits(group);
            self.raw &= ~masked_val;
        }
        pub inline fn set_group_from_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: EnumInt) void {
            const unmasked_val = ((val) << GroupsInfo.ctz(group));
            self.raw |= unmasked_val;
        }
        pub inline fn clear_and_set_group_from_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: EnumInt) void {
            self.raw &= GroupsInfo.inverse_bits(group);
            const unmasked_val = ((val) << GroupsInfo.ctz(group));
            self.raw |= unmasked_val;
        }
        pub inline fn partial_clear_group_from_inverse_of_int_aligned_at_bit_0_dont_mask(self: *Self, group: Group, val: EnumInt) void {
            const unmasked_val = ((val) << GroupsInfo.ctz(group));
            self.raw &= ~unmasked_val;
        }

        pub inline fn flag_to_first_matching_group(flag_: Flag) ?Group {
            for (GroupsInfo.BITS[0..], 0..) |bits, idx| {
                if (@intFromEnum(flag_) & bits == @intFromEnum(flag_)) return @enumFromInt(idx);
            }
            return null;
        }
        pub inline fn flag_to_first_matching_group_guaranteed(flag_: Flag) Group {
            for (GroupsInfo.BITS[0..], 0..) |bits, idx| {
                if (@intFromEnum(flag_) & bits == @intFromEnum(flag_)) return @enumFromInt(idx);
            }
            unreachable;
        }
        pub inline fn flag_to_first_matching_group_subset(flag_: Flag, group_subset: []const Group) ?Group {
            for (group_subset, 0..) |group, idx| {
                if (@intFromEnum(flag_) & GroupsInfo.bits(group) == @intFromEnum(flag_)) return @enumFromInt(idx);
            }
            return null;
        }
        pub inline fn flag_to_first_matching_group_subset_guaranteed(flag_: Flag, group_subset: []const Group) Group {
            for (group_subset, 0..) |group, idx| {
                if (@intFromEnum(flag_) & GroupsInfo.bits(group) == @intFromEnum(flag_)) return @enumFromInt(idx);
            }
            unreachable;
        }

        pub inline fn all_flags__to_first_matching_group(self: Self) ?Group {
            for (GroupsInfo.BITS[0..], 0..) |bits, idx| {
                if (self.raw & bits == self.raw) return @enumFromInt(idx);
            }
            return null;
        }
        pub inline fn all_flags__to_first_matching_group_guaranteed(self: Self) Group {
            for (GroupsInfo.BITS[0..], 0..) |bits, idx| {
                if (self.raw & bits == self.raw) return @enumFromInt(idx);
            }
            unreachable;
        }
        pub inline fn all_flags__to_first_matching_group_subset(self: Self, group_subset: []const Group) ?Group {
            for (group_subset, 0..) |group, idx| {
                if (self.raw & GroupsInfo.bits(group) == self.raw) return @enumFromInt(idx);
            }
            return null;
        }
        pub inline fn all_flags__to_first_matching_group_subset_guaranteed(self: Self, group_subset: []const Group) Group {
            for (group_subset, 0..) |group, idx| {
                if (self.raw & GroupsInfo.bits(group) == self.raw) return @enumFromInt(idx);
            }
            unreachable;
        }
    };
}

pub const Groups = struct {
    group_names_enum: type,
    group_vals_enum: type,

    fn none(comptime FLAGS_ENUM: type) Groups {
        const F_INFO = @typeInfo(FLAGS_ENUM);
        assert_with_reason(F_INFO == .@"enum", @inComptime(), @src(), @This(), "parameter `FLAGS_ENUM` must be an enum type");
        const FLAGS_INFO = F_INFO.@"enum";
        assert_with_reason(@typeInfo(FLAGS_INFO.tag_type).int.signedness == .unsigned, @inComptime(), @src(), @This(), "parameter `FLAGS_ENUM` tage type must be an unsigned integer type");
        return Groups{
            .group_names_enum = enum(u8) {
                NONE = 0,
            },
            .group_vals_enum = enum(FLAGS_INFO.tag_type) {
                NONE = 0,
            },
        };
    }
};

pub fn BuildGroups(comptime groups: Groups) type {
    const GROUP_NAMES_ENUM = groups.group_names_enum;
    const GROUP_VALS_ENUM = groups.group_vals_enum;
    const N_INFO = @typeInfo(GROUP_NAMES_ENUM);
    assert_with_reason(N_INFO == .@"enum", @inComptime(), @src(), @This(), "GROUP_NAMES_ENUM must be an enum type");
    const NAME_INFO = N_INFO.@"enum";
    assert_with_reason(@typeInfo(NAME_INFO.tag_type).int.signedness == .unsigned, @inComptime(), @src(), @This(), "GROUP_NAMES_ENUM tag type must be an unsigned integer type");
    assert_with_reason(Utils.all_enum_values_start_from_zero_with_no_gaps(GROUP_NAMES_ENUM), @inComptime(), @src(), @This(), "GROUP_NAMES_ENUM must use every tag value starting from zero up to the largest tag value with no gaps");
    const V_INFO = @typeInfo(GROUP_VALS_ENUM);
    assert_with_reason(V_INFO == .@"enum", @inComptime(), @src(), @This(), "GROUP_VALS_ENUM must be an enum type");
    const VAL_INFO = V_INFO.@"enum";
    comptime var counts: [NAME_INFO.fields.len]usize = @splat(0);
    comptime var maps: [NAME_INFO.fields.len]VAL_INFO.tag_type = @splat(0);
    for (NAME_INFO.fields) |name_field| {
        inner: for (VAL_INFO.fields) |val_field| {
            if (std.mem.eql(u8, name_field.name, val_field.name)) {
                counts[name_field.value] += 1;
                maps[name_field.value] = val_field.value;
                break :inner;
            }
        }
    }
    for (counts[0..]) |cnt| {
        assert_with_reason(cnt == 1, @inComptime(), @src(), @This(), "all GROUP_NAMES_ENUM tags must have a matching tag with the same exact name in GROUP_VALS_ENUM");
    }
    const M = comptime make_const: {
        break :make_const maps;
    };
    const IM = comptime make_const: {
        var inv: [M.len]VAL_INFO.tag_type = @splat(0);
        for (M[0..], 0..) |val, idx| {
            inv[idx] = ~val;
        }
        break :make_const inv;
    };
    const CT = comptime make_const: {
        var trail_count: [M.len]Log2IntCeil(VAL_INFO.tag_type) = @splat(0);
        for (M[0..], 0..) |val, idx| {
            trail_count[idx] = @ctz(val);
        }
        break :make_const trail_count;
    };
    const CL = comptime make_const: {
        var lead_count: [M.len]Log2IntCeil(VAL_INFO.tag_type) = @splat(0);
        for (M[0..], 0..) |val, idx| {
            lead_count[idx] = @clz(val);
        }
        break :make_const lead_count;
    };
    const POP = comptime make_const: {
        var pop_count: [M.len]Log2IntCeil(VAL_INFO.tag_type) = @splat(0);
        for (M[0..], 0..) |val, idx| {
            pop_count[idx] = @popCount(val);
        }
        break :make_const pop_count;
    };
    const RNG = comptime make_const: {
        const BITS: Log2IntCeil(VAL_INFO.tag_type) = @intCast(@typeInfo(VAL_INFO.tag_type).int.bits);
        var range: [M.len]Log2IntCeil(VAL_INFO.tag_type) = @splat(0);
        for (CL[0..], CT[0..], 0..) |leading, trailing, idx| {
            range[idx] = (BITS - leading) -| trailing;
        }
        break :make_const range;
    };
    const CONT = comptime make_const: {
        var contig: [M.len]bool = @splat(false);
        for (RNG[0..], POP[0..], 0..) |range, pop, idx| {
            contig[idx] = range == pop;
        }
        break :make_const contig;
    };
    return struct {
        pub const Name = GROUP_NAMES_ENUM;
        pub const Val = GROUP_VALS_ENUM;
        pub const ValRaw = VAL_INFO.tag_type;
        pub const COUNT = M.len;
        pub const BITS = M;
        pub const INV_BITS = IM;
        pub const CLZ = CL;
        pub const CTZ = CT;
        pub const BIT_COUNT = POP;
        pub const BIT_RANGE = RNG;
        pub const CONTIGUOUS = CONT;

        pub inline fn bits(group_name: Name) ValRaw {
            return BITS[@intFromEnum(group_name)];
        }
        pub inline fn inverse_bits(group_name: Name) ValRaw {
            return INV_BITS[@intFromEnum(group_name)];
        }
        pub inline fn clz(group_name: Name) Log2IntCeil(ValRaw) {
            return CLZ[@intFromEnum(group_name)];
        }
        pub inline fn ctz(group_name: Name) Log2IntCeil(ValRaw) {
            return CTZ[@intFromEnum(group_name)];
        }
        pub inline fn bit_count(group_name: Name) Log2IntCeil(ValRaw) {
            return BIT_COUNT[@intFromEnum(group_name)];
        }
        pub inline fn bit_range(group_name: Name) Log2IntCeil(ValRaw) {
            return BIT_RANGE[@intFromEnum(group_name)];
        }
        pub inline fn contiguous(group_name: Name) bool {
            return CONTIGUOUS[@intFromEnum(group_name)];
        }
    };
}
