// //! //TODO Documentation
// //! #### License: Zlib

// // zlib license
// //
// // Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
// //
// // This software is provided 'as-is', without any express or implied
// // warranty. In no event will the authors be held liable for any damages
// // arising from the use of this software.
// //
// // Permission is granted to anyone to use this software for any purpose,
// // including commercial applications, and to alter it and redistribute it
// // freely, subject to the following restrictions:
// //
// // 1. The origin of this software must not be misrepresented; you must not
// //    claim that you wrote the original software. If you use this software
// //    in a product, an acknowledgment in the product documentation would be
// //    appreciated but is not required.
// // 2. Altered source versions must be plainly marked as such, and must not be
// //    misrepresented as being the original software.
// // 3. This notice may not be removed or altered from any source distribution.

// const std = @import("std");
// const math = std.math;

// const EnumField = std.builtin.Type.EnumField;

// const eval_branch_quota_cushion = 10;

// /// Returns the optimal static bit set type for the specified number
// /// of elements: either `IntegerBitSet` or `ArrayBitSet`,
// /// both of which fulfill the same interface.
// /// The returned type will perform no allocations,
// /// can be copied by value, and does not require deinitialization.
// pub fn StaticBitSetExternCompat(comptime size: usize) type {
//     if (size <= @bitSizeOf(usize)) {
//         var aligned_size: usize = @max(@as(usize, 8), size);
//         aligned_size -= 1;
//         aligned_size |= aligned_size >> 1;
//         aligned_size |= aligned_size >> 2;
//         aligned_size |= aligned_size >> 4;
//         aligned_size |= aligned_size >> 8;
//         aligned_size |= aligned_size >> 16;
//         if (comptime @sizeOf(usize) > 4) {
//             aligned_size |= aligned_size >> 32;
//         }
//         aligned_size += 1;
//         return std.bit_set.IntegerBitSet(aligned_size);
//     } else {
//         return std.bit_set.ArrayBitSet(usize, size);
//     }
// }

// pub const EnumTagLayout = enum(u8) {
//     TAGS_ARE_INDEXES,
//     TAGS_ARE_FLAGS,
// };

// /// This raps `std.enums.EnumIndexer`, but provides an alternate mode for dealing with
// /// enums whose tags are already assigned to power-of-2 values (bit flags)
// pub fn EnumIndexer(comptime E: type, comptime TAG_LAYOUT: EnumTagLayout) type {
//     if (comptime TAG_LAYOUT == .TAGS_ARE_FLAGS) {
//         const BackingInt = @typeInfo(E).@"enum".tag_type;
//         if (comptime @typeInfo(BackingInt).int.signedness == .signed)
//             @compileError("signed integer enums are not supported for `.TAGS_ARE_FLAGS` mode");
//         const BackingIntLog2 = math.Log2Int(BackingInt);
//         if (@bitSizeOf(BackingIntLog2) > @bitSizeOf(usize))
//             @compileError("Cannot create an enum indexer for a given enum, math.Log2Int(tag_type) is larger than usize.");

//         return struct {
//             pub const Key: type = E;

//             pub const count: comptime_int = std.math.maxInt(RangeType) + 1;

//             pub fn indexOf(e: E) usize {
//                 return @intCast(@ctz(@intFromEnum(e)));
//             }
//             pub fn keyForIndex(i: usize) E {
//                 return @enumFromInt(@as(BackingInt, 1) << @as(BackingIntLog2, @intCast(i)));
//             }
//         };
//     }
//     return std.enums.EnumIndexer(E);
// }

// /// A set of enum elements, backed by a bitfield.  If the enum
// /// is exhaustive but not dense, a mapping will be constructed from enum values
// /// to dense indices.  This type does no dynamic allocation and
// /// can be copied by value.
// ///
// /// (This type mirrors `std.enums.EnumSet` but uses an `extern` layout instead,
// /// and also provides a mode for handling enums whose tags are already at power-of-2 values)
// pub fn EnumSet(comptime E: type, comptime TAG_LAYOUT: EnumTagLayout) type {
//     return extern struct {
//         const Self = @This();

//         /// The indexing rules for converting between keys and indices.
//         pub const Indexer = EnumIndexer(E, TAG_LAYOUT);
//         /// The element type for this set.
//         pub const Key = Indexer.Key;

//         const BitSet = StaticBitSetExternCompat(Indexer.count);

//         /// The maximum number of items in this set.
//         pub const len = Indexer.count;

//         bits: BitSet = .empty,

//         /// Initializes the set using a struct of bools
//         pub fn new_from_bools(init_values: std.enums.EnumFieldStruct(E, bool, false)) Self {
//             @setEvalBranchQuota(2 * @typeInfo(E).@"enum".field_names.len);
//             var result: Self = .{};
//             if (@typeInfo(E).@"enum".mode == .exhaustive) {
//                 inline for (0..Self.len) |i| {
//                     const key = comptime Indexer.keyForIndex(i);
//                     const tag = @tagName(key);
//                     if (@field(init_values, tag)) {
//                         result.bits.set(i);
//                     }
//                 }
//             } else {
//                 inline for (std.meta.fields(E)) |field| {
//                     const key = @field(E, field.name);
//                     if (@field(init_values, field.name)) {
//                         const i = comptime Indexer.indexOf(key);
//                         result.bits.set(i);
//                     }
//                 }
//             }
//             return result;
//         }

//         /// A set containing no keys.
//         pub const empty: Self = .{ .bits = .empty };

//         /// A set containing all possible keys.
//         pub const full: Self = .{ .bits = .full };

//         /// Returns a set containing multiple keys.
//         pub fn new_many(keys: []const Key) Self {
//             var set: Self = .empty;
//             for (keys) |key| set.insert(key);
//             return set;
//         }

//         /// Returns a set containing a single key.
//         pub fn new(key: Key) Self {
//             return new_many(&[_]Key{key});
//         }

//         /// Returns the number of keys in the set.
//         pub fn count(self: Self) usize {
//             return self.bits.count();
//         }

//         /// Checks if a key is in the set.
//         pub fn contains(self: Self, key: Key) bool {
//             return self.bits.isSet(Indexer.indexOf(key));
//         }

//         /// Puts a key in the set.
//         pub fn insert(self: *Self, key: Key) void {
//             self.bits.set(Indexer.indexOf(key));
//         }

//         /// Removes a key from the set.
//         pub fn remove(self: *Self, key: Key) void {
//             self.bits.unset(Indexer.indexOf(key));
//         }

//         /// Changes the presence of a key in the set to match the passed bool.
//         pub fn set_state(self: *Self, key: Key, present: bool) void {
//             self.bits.setValue(Indexer.indexOf(key), present);
//         }

//         /// Toggles the presence of a key in the set.  If the key is in
//         /// the set, removes it.  Otherwise adds it.
//         pub fn toggle(self: *Self, key: Key) void {
//             self.bits.toggle(Indexer.indexOf(key));
//         }

//         /// Toggles the presence of all keys in the passed set.
//         pub fn toggle_set(self: *Self, other: Self) void {
//             self.bits.toggleSet(other.bits);
//         }

//         /// Toggles all possible keys in the set.
//         pub fn toggle_all(self: *Self) void {
//             self.bits.toggleAll();
//         }

//         /// Adds all keys in the passed set to this set.
//         pub fn set_union(self: *Self, other: Self) void {
//             self.bits.setUnion(other.bits);
//         }

//         /// Removes all keys which are not in the passed set.
//         pub fn set_intersection(self: *Self, other: Self) void {
//             self.bits.setIntersection(other.bits);
//         }

//         /// Returns true iff both sets have the same keys.
//         pub fn eql(self: Self, other: Self) bool {
//             return self.bits.eql(other.bits);
//         }

//         /// Returns true iff all the keys in this set are
//         /// in the other set. The other set may have keys
//         /// not found in this set.
//         pub fn is_subset_of(self: Self, other: Self) bool {
//             return self.bits.subsetOf(other.bits);
//         }

//         /// Returns true iff this set contains all the keys
//         /// in the other set. This set may have keys not
//         /// found in the other set.
//         pub fn is_superset_of(self: Self, other: Self) bool {
//             return self.bits.supersetOf(other.bits);
//         }

//         /// Returns a set with all the keys not in this set.
//         pub fn complement(self: Self) Self {
//             return .{ .bits = self.bits.complement() };
//         }

//         /// Returns a set with keys that are in either this
//         /// set or the other set.
//         pub fn union_with(self: Self, other: Self) Self {
//             return .{ .bits = self.bits.unionWith(other.bits) };
//         }

//         /// Returns a set with keys that are in both this
//         /// set and the other set.
//         pub fn intersect_with(self: Self, other: Self) Self {
//             return .{ .bits = self.bits.intersectWith(other.bits) };
//         }

//         /// Returns a set with keys that are in either this
//         /// set or the other set, but not both.
//         pub fn xor_with(self: Self, other: Self) Self {
//             return .{ .bits = self.bits.xorWith(other.bits) };
//         }

//         /// Returns a set with keys that are in this set
//         /// except for keys in the other set.
//         pub fn difference_with(self: Self, other: Self) Self {
//             return .{ .bits = self.bits.differenceWith(other.bits) };
//         }

//         /// Returns an iterator over this set, which iterates in
//         /// index order.  Modifications to the set during iteration
//         /// may or may not be observed by the iterator, but will
//         /// not invalidate it.
//         pub fn iterator(self: *const Self) Iterator {
//             return .{ .inner = self.bits.iterator(.{}) };
//         }

//         pub const Iterator = struct {
//             inner: BitSet.Iterator(.{}),

//             pub fn next(self: *Iterator) ?Key {
//                 return if (self.inner.next()) |index|
//                     Indexer.keyForIndex(index)
//                 else
//                     null;
//             }
//         };
//     };
// }
