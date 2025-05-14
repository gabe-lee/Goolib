const std = @import("std");
const assert = std.debug.assert;

pub fn SoftSlice(comptime T: type, comptime IDX: type) type {
    return extern struct {
        ptr: [*]T,
        len: IDX,

        const Self = @This();

        pub inline fn from_native(native: []T) Self {
            return Self{
                .ptr = native.ptr,
                .len = @intCast(native.len),
            };
        }
        pub inline fn to_native(self: Self) []T {
            return self.ptr[0..@intCast(self.len)];
        }

        pub inline fn new(ptr: [*]T, len: IDX) Self {
            return Self{
                .ptr = ptr,
                .len = len,
            };
        }

        pub inline fn empty() Self {
            return EMPTY;
        }
        pub const EMPTY = Self{
            .ptr = std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T)),
            .len = 0,
        };

        pub inline fn grow_right(self: Self, count: IDX) Self {
            return Self{
                .ptr = self.ptr,
                .len = self.len + count,
            };
        }

        pub inline fn grow_left(self: Self, count: IDX) Self {
            return Self{
                .ptr = self.ptr - count,
                .len = self.len + count,
            };
        }

        pub inline fn shrink_right(self: Self, count: IDX) Self {
            assert(self.len >= count);
            return Self{
                .ptr = self.ptr,
                .len = self.len - count,
            };
        }

        pub inline fn shrink_left(self: Self, count: IDX) Self {
            assert(self.len >= count);
            return Self{
                .ptr = self.ptr + count,
                .len = self.len - count,
            };
        }

        pub inline fn shift_right(self: Self, count: IDX) Self {
            return Self{
                .ptr = self.ptr + count,
                .len = self.len,
            };
        }

        pub inline fn shift_left(self: Self, count: IDX) Self {
            return Self{
                .ptr = self.ptr - count,
                .len = self.len,
            };
        }

        pub inline fn sub_slice(self: Self, start: IDX, len: IDX) Self {
            assert(start + len <= self.len);
            return Self{
                .ptr = self.ptr + start,
                .len = len,
            };
        }
        pub inline fn sub_slice_from_start(self: Self, len: IDX) Self {
            assert(len <= self.len);
            return Self{
                .ptr = self.ptr,
                .len = len,
            };
        }
        pub inline fn sub_slice_from_end(self: Self, len: IDX) Self {
            assert(len <= self.len);
            const diff = self.len - len;
            return Self{
                .ptr = self.ptr + diff,
                .len = len,
            };
        }

        pub inline fn get_item_ptr(self: Self, idx: IDX) *T {
            assert(idx < self.len);
            return &self.ptr[idx];
        }

        pub inline fn get_item_ptr_const(self: Self, idx: IDX) *const T {
            assert(idx < self.len);
            return &self.ptr[idx];
        }

        pub inline fn get_item(self: Self, idx: IDX) T {
            assert(idx < self.len);
            return self.ptr[idx];
        }

        pub inline fn get_item_ptr_from_end(self: Self, idx: IDX) *T {
            assert(idx < self.len);
            return &self.ptr[self.len - 1 - idx];
        }

        pub inline fn get_item_ptr_const_from_end(self: Self, idx: IDX) *const T {
            assert(idx < self.len);
            return &self.ptr[self.len - 1 - idx];
        }

        pub inline fn get_item_from_end(self: Self, idx: IDX) T {
            assert(idx < self.len);
            return self.ptr[self.len - 1 - idx];
        }

        pub inline fn set_item(self: Self, idx: IDX, val: T) void {
            assert(idx < self.len);
            self.ptr[idx] = val;
        }

        pub inline fn set_item_from_end(self: Self, idx: IDX, val: T) void {
            assert(idx < self.len);
            self.ptr[self.len - 1 - idx] = val;
        }

        pub fn memcopy_to(self: Self, other: anytype) void {
            const OTHER = @TypeOf(other);
            if (@hasField(OTHER, "ptr") and @FieldType(OTHER, "ptr") == [*]T) {
                @memcpy(other.ptr, self.to_native());
                return;
            } else {
                @memcpy(other, self.to_native());
                return;
            }
        }

        pub fn memset(self: Self, val: T) void {
            @memset(self.to_native(), val);
        }

        pub inline fn copy_rightward(self: Self, count: IDX, comptime secure_wipe: bool) Self {
            const new_slice = self.shift_right(count);
            std.mem.copyBackwards(T, new_slice.to_native(), self.to_native());
            if (secure_wipe) std.crypto.secureZero(T, self.sub_slice_from_start(count).to_native());
            return new_slice;
        }

        pub inline fn copy_leftward(self: Self, count: IDX, comptime secure_wipe: bool) Self {
            const new_slice = self.shift_left(count);
            std.mem.copyForwards(T, new_slice.to_native(), self.to_native());
            if (secure_wipe) std.crypto.secureZero(T, self.sub_slice_from_end(count).to_native());
            return new_slice;
        }
    };
}
