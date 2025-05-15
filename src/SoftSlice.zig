const std = @import("std");
const assert = std.debug.assert;

const Root = @import("./_root.zig");
const Utils = Root.Utils;
const u_secure_memset = Utils.secure_memset;
const u_secure_memset_const = Utils.secure_memset_const;
const u_secure_zero = Utils.secure_zero;
const u_secure_memset_undefined = Utils.secure_memset_undefined;
const assert_with_reason = Utils.assert_with_reason;

const OPERATE_NULL_ERR = "SoftSlice: cannot operate on null ptr";
const SHRINK_OOB_ERR = "SoftSlice: shrink count ({d}) would cause condition `first_address > last_address` (max shrink = len = {d})";
const START_END_ERR = "SoftSlice: provided start ({d}) and end ({s}) indexes would cause condition `first_address > last_address`";
const INDEX_OOB_ERR = "SoftSlice: the largest requested or provided index ({d}) is out of slice bounds (len = {d})";
const INDEX_CHUNK_OOB_ERR = "SoftSlice: requested or provided start + count ({d} + {d} = {d}) would put the resulting sub-slice out of original bounds (len = {d})";
const SHIFT_OVERLAP_ERR = "SoftSlice: a `shift({s}) -> @memcopy` operation isn't shifted far enough to guarantee no overlap (min_shift = len = {d})";

pub fn SoftSlice(comptime T: type, comptime IDX: type) type {
    if (@typeInfo(IDX) != .int and @typeInfo(IDX) != .comptime_int) @compileError("type `IDX` must be an integer type");
    return extern struct {
        ptr: ?[*]T,
        len: IDX,

        const Self = @This();

        pub const NULL = Self{ .ptr = null, .len = 0 };

        pub inline fn is_empty(self: Self) bool {
            return self.len == 0;
        }
        pub inline fn is_null(self: Self) bool {
            return self.ptr == null;
        }

        pub inline fn from_native(pointer_or_slice: anytype) Self {
            if (Utils.type_is_optional(pointer_or_slice) and pointer_or_slice == null) return Self.NULL;
            const PTR = if (Utils.type_is_optional(pointer_or_slice)) Utils.optional_type_child(pointer_or_slice) else @TypeOf(pointer_or_slice);
            const unwrapped_ptr: PTR = if (Utils.type_is_optional(pointer_or_slice)) pointer_or_slice.? else pointer_or_slice;
            if (Utils.type_is_pointer_or_slice(PTR) and Utils.pointer_is_mutable(PTR)) {
                const CHILD = Utils.pointer_child_type(PTR);
                if (Utils.pointer_is_slice(PTR)) {
                    if (CHILD != T) @compileError("SoftSlice(" ++ @typeName(T) ++ ").from_native(" ++ @typeName(pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
                    return Self{ .ptr = unwrapped_ptr.ptr, .len = @intCast(unwrapped_ptr.len) };
                } else if (Utils.pointer_is_single(PTR)) {
                    if (Utils.type_is_array_or_vector(CHILD)) {
                        const ARR_CHILD = Utils.array_or_vector_child_type(CHILD);
                        if (ARR_CHILD != T) @compileError("SoftSlice(" ++ @typeName(T) ++ ").from_native(" ++ @typeName(pointer_or_slice) ++ ") mismatched child type " ++ @typeName(ARR_CHILD));
                        return Self{ .ptr = @ptrCast(@alignCast(&unwrapped_ptr[0])), .len = @intCast(unwrapped_ptr.len) };
                    } else {
                        if (CHILD != T) @compileError("SoftSlice(" ++ @typeName(T) ++ ").from_native(" ++ @typeName(pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
                        return Self{ .ptr = unwrapped_ptr, .len = 1 };
                    }
                } else if (Utils.pointer_is_many(PTR)) {
                    if (CHILD != T) @compileError("SoftSlice(" ++ @typeName(T) ++ ").from_native(" ++ @typeName(pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
                    const sentinel = Utils.pointer_type_sentinel(PTR);
                    const sent_slice = Utils.make_slice_from_sentinel_ptr(CHILD, sentinel.*, unwrapped_ptr);
                    return Self{ .ptr = sent_slice.ptr, .len = @intCast(sent_slice.len) };
                } else {
                    if (CHILD != T) @compileError("SoftSlice(" ++ @typeName(T) ++ ").from_native(" ++ @typeName(pointer_or_slice) ++ ") mismatched child type " ++ @typeName(CHILD));
                    if (@intFromPtr(unwrapped_ptr) == 0) return Self.NULL;
                    return Self{ .ptr = @ptrCast(@alignCast(unwrapped_ptr)), .len = 1 };
                }
            } else @compileError("cannot create a SoftSlice from non-pointer type or non-mutable pointer type");
        }
        pub inline fn to_native(self: Self) []T {
            assert_with_reason(self.ptr != null, "cannot cast SoftSlice({S}) == `null` to native zig slice []{s}", .{ @typeName(T), @typeName(T) });
            return self.ptr.?[0..@intCast(self.len)];
        }
        pub inline fn to_native_nullable(self: Self) ?[]T {
            if (self.ptr == null) return null;
            return self.ptr.?[0..@intCast(self.len)];
        }

        pub inline fn new(ptr: [*]T, len: IDX) Self {
            return Self{ .ptr = ptr, .len = len };
        }
        pub inline fn new_with_start_end(ptr: [*]T, start: IDX, end: IDX) Self {
            assert_with_reason(end >= start, START_END_ERR, .{ start, end });
            return Self{ .ptr = ptr + start, .len = end - start };
        }

        pub inline fn grow_right(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr, .len = self.len + count };
        }

        pub inline fn grow_left(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr.? - count, .len = self.len + count };
        }

        pub inline fn shrink_right(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len >= count, SHRINK_OOB_ERR, .{ count, self.len });
            return Self{ .ptr = self.ptr, .len = self.len - count };
        }

        pub inline fn shrink_left(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len >= count, SHRINK_OOB_ERR, .{ count, self.len });
            return Self{ .ptr = self.ptr.? + count, .len = self.len - count };
        }

        pub inline fn shift_right(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr.? + count, .len = self.len };
        }

        pub inline fn shift_left(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr.? - count, .len = self.len };
        }

        pub inline fn sub_slice(self: Self, start: IDX, len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(start + len <= self.len, INDEX_CHUNK_OOB_ERR, .{ start, len, start + len, self.len });
            return Self{ .ptr = self.ptr.? + start, .len = len };
        }
        pub inline fn sub_slice_start_end(self: Self, start: IDX, end: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(end >= start, START_END_ERR, .{ start, end });
            assert_with_reason(end <= self.len, INDEX_CHUNK_OOB_ERR, .{ start, end - start, end, self.len });
            return Self{ .ptr = self.ptr.? + start, .len = end - start };
        }
        pub inline fn sub_slice_from_start(self: Self, len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(len <= self.len, INDEX_CHUNK_OOB_ERR, .{ 0, len, len, self.len });
            return Self{ .ptr = self.ptr, .len = len };
        }
        pub inline fn sub_slice_from_end(self: Self, len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(len <= self.len, INDEX_CHUNK_OOB_ERR, .{ self.len - len, len, self.len, self.len });
            const diff = self.len - len;
            return Self{ .ptr = self.ptr.? + diff, .len = len };
        }

        pub inline fn with_new_len(self: Self, new_len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr, .len = new_len };
        }
        pub inline fn with_new_ptr(self: Self, new_ptr: ?[*]T) Self {
            return Self{ .ptr = new_ptr, .len = self.len };
        }

        pub inline fn new_slice_before(self: Self, len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr.? - len, .len = len };
        }
        pub inline fn new_slice_after(self: Self, len: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            return Self{ .ptr = self.ptr.? + self.len, .len = len };
        }

        pub inline fn get_item_ptr(self: Self, idx: IDX) *T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return &self.ptr.?[idx];
        }

        pub inline fn get_last_item_ptr(self: Self) *T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ -1, self.len });
            return &self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item_ptr(self: Self) *T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ 0, self.len });
            return &self.ptr.?[0];
        }

        pub inline fn get_item_const_ptr(self: Self, idx: IDX) *const T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return &self.ptr.?[idx];
        }

        pub inline fn get_last_item_const_ptr(self: Self) *const T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ -1, self.len });
            return &self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item_const_ptr(self: Self) *const T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ 0, self.len });
            return &self.ptr.?[0];
        }

        pub inline fn get_item(self: Self, idx: IDX) T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return self.ptr.?[idx];
        }

        pub inline fn get_last_item(self: Self) T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ -1, self.len });
            return self.ptr.?[self.len - 1];
        }

        pub inline fn get_first_item(self: Self) T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ 0, self.len });
            return self.ptr.?[0];
        }

        pub inline fn get_item_ptr_from_end(self: Self, idx: IDX) *T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return &self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn get_item_const_ptr_from_end(self: Self, idx: IDX) *const T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return &self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn get_item_from_end(self: Self, idx: IDX) T {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            return self.ptr.?[self.len - 1 - idx];
        }

        pub inline fn set_item(self: Self, idx: IDX, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            self.ptr.?[idx] = val;
        }

        pub inline fn set_last_item(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ -1, self.len });
            self.ptr.?[self.len - 1] = val;
        }

        pub inline fn set_first_item(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(self.len > 0, INDEX_OOB_ERR, .{ 0, self.len });
            self.ptr.?[0] = val;
        }

        pub inline fn set_item_from_end(self: Self, idx: IDX, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            assert_with_reason(idx < self.len, INDEX_OOB_ERR, .{ idx, self.len });
            self.ptr.?[self.len - 1 - idx] = val;
        }

        pub inline fn memcopy_to(self: Self, other: anytype) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            Utils.memcopy(self.ptr.?, other, @intCast(self.len));
        }

        pub inline fn memcopy_from(self: Self, other: anytype) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            Utils.memcopy(other, self.ptr.?, self.len);
        }

        pub inline fn memset(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            @memset(self.to_native(), val);
        }

        pub inline fn secure_zero(self: Self) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            u_secure_zero(T, self.ptr.?[0..self.len]);
        }
        pub inline fn secure_memset_undefined(self: Self) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            u_secure_memset_undefined(T, self.ptr.?[0..self.len]);
        }
        pub inline fn secure_memset(self: Self, val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            u_secure_memset(T, self.ptr.?[0..self.len], val);
        }
        pub inline fn secure_memset_const(self: Self, comptime val: T) void {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            u_secure_memset_const(T, self.ptr.?[0..self.len], val);
        }

        pub fn copy_rightward(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            const new_slice = self.shift_right(count);
            if (count > self.len) {
                @memcpy(new_slice.to_native(), self.to_native());
            } else {
                std.mem.copyBackwards(T, new_slice.to_native(), self.to_native());
            }
            return new_slice;
        }

        pub fn copy_rightward_and_zero_old(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            const new_slice = self.shift_right(count);
            if (count > self.len) {
                @memcpy(new_slice.to_native(), self.to_native());
            } else {
                std.mem.copyBackwards(T, new_slice.to_native(), self.to_native());
            }
            self.sub_slice_from_start(count).secure_zero();
            return new_slice;
        }

        pub fn copy_leftward(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            const new_slice = self.shift_left(count);
            if (count > self.len) {
                @memcpy(new_slice.to_native(), self.to_native());
            } else {
                std.mem.copyForwards(T, new_slice.to_native(), self.to_native());
            }
            return new_slice;
        }
        pub fn copy_leftward_and_zero_old(self: Self, count: IDX) Self {
            assert_with_reason(self.ptr != null, OPERATE_NULL_ERR, .{});
            const new_slice = self.shift_left(count);
            if (count > self.len) {
                @memcpy(new_slice.to_native(), self.to_native());
            } else {
                std.mem.copyForwards(T, new_slice.to_native(), self.to_native());
            }
            self.sub_slice_from_end(count).secure_zero();
            return new_slice;
        }

        pub inline fn swap(self: Self, idx_a: IDX, idx_b: IDX) void {
            const a_val: T = self.get_item(idx_a);
            self.set_item(idx_a, self.get_item(idx_b));
            self.set_item(idx_b, a_val);
        }
    };
}
