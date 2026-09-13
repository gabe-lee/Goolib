//! //TODO Documentation
//! #### License: Zlib

// zlib license
//
// Copyright (c) 2025-2026, Gabriel Lee Anderson <gla.ander@gmail.com>
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");

const Root = @import("./_root.zig");
const Types = Root.Types;
const Assert = Root.Assert;
const Utils = Root.Utils;

const assert_with_reason = Assert.assert_with_reason;

pub fn NameTypeAndBitCount(comptime E: type) type {
    return struct {
        field: E,
        unpacked_type: type,
        packed_bits: u16,
    };
}

pub fn define_arbitrary_packed_struct_type(comptime BACKING_INT_TYPE: type, comptime NUM_BACKING_INTS: u16, comptime FIELDS_ENUM: type, comptime FIELD_DEFS: [Types.enum_defined_field_count(FIELDS_ENUM)]NameTypeAndBitCount(FIELDS_ENUM)) type {
    assert_with_reason(Types.type_is_enum(FIELDS_ENUM), @src(), "type `FIELDS_ENUM` must be an enum type, got type `{s}`", .{@typeName(FIELDS_ENUM)});
    assert_with_reason(Types.enum_is_exhaustive(FIELDS_ENUM), @src(), "type `FIELDS_ENUM` must be an exhaustive enum type", .{@typeName(FIELDS_ENUM)});
    assert_with_reason(Types.all_enum_values_start_from_zero_with_no_gaps(FIELDS_ENUM), @src(), "type `FIELDS_ENUM` must be an enum type with all tage starting from value 0to the max tag value, with no gaps", .{@typeName(FIELDS_ENUM)});
    assert_with_reason(Types.type_is_unsigned_int_aligned(BACKING_INT_TYPE), @src(), "type `BACKING_INT` MUST be one of: u8, u16, u32, u64, u128, usize... got type `{s}`", .{@typeName(BACKING_INT_TYPE)});
    assert_with_reason(NUM_BACKING_INTS > 0, @src(), "`NUM_BACKING_INTS` must be greater than 0", .{});
    const _NUM_FIELDS = Types.enum_defined_field_count(FIELDS_ENUM);
    assert_with_reason(Types.enum_defined_field_count(FIELDS_ENUM) > 0, @src(), "`FIELDS_ENUM` must have at least one tag", .{});
    const _E = @typeInfo(FIELDS_ENUM).@"enum";
    assert_with_reason(FIELD_DEFS.len == _E.fields.len, @src(), "the number of fields in `FIELD_DEFS` does not match the number of enum tags in `FIELDS_ENUM`, {d} != {d}", .{ FIELD_DEFS.len, _E.fields.len });
    var _INITS: [_NUM_FIELDS]bool = @splat(false);
    const _BITS_PER_BACKING_INT = @typeInfo(BACKING_INT_TYPE).int.bits;
    const _TOTAL_BITS: u16 = NUM_BACKING_INTS * _BITS_PER_BACKING_INT;
    var _PACKED_BITS: u16 = 0;
    for (FIELD_DEFS[0..], 0..) |def, didx| {
        const idx = @intFromEnum(def.field);
        assert_with_reason(_INITS[idx] == false, @src(), "field `{s}` had a duplicate definition at index {d}", .{ @tagName(def.field), didx });
        assert_with_reason(def.packed_bits <= _BITS_PER_BACKING_INT, @src(), "all field bit sizes must be <= the bit size of the backing integer type `{s}`... field `{s}` wants {d} bits, but backing bits size is {d}", .{ @typeName(BACKING_INT_TYPE), @tagName(def.field), def.packed_bits, _BITS_PER_BACKING_INT });
        assert_with_reason(def.packed_bits <= @bitSizeOf(def.unpacked_type), @src(), "field `{s}` must have a `packed_bits` value <= `@bitSizeOf(unpacked_type)`, got {d} > {d}", .{ @tagName(def.field), def.packed_bits, @bitSizeOf(def.unpacked_type) });
        _PACKED_BITS += def.packed_bits;
        assert_with_reason(_PACKED_BITS <= _TOTAL_BITS, @src(), " field `{s}` (def index {d}) would push the number of packed bits ({d} + {d}) over the total bit limit of the backing data of {d} x {s}  ({d})", .{ @tagName(def.field), didx, _PACKED_BITS, def.packed_bits, NUM_BACKING_INTS, @typeName(BACKING_INT_TYPE), _TOTAL_BITS });
        _INITS[idx] = true;
    }
    const _FREE_BITS = _TOTAL_BITS - _PACKED_BITS;
    var _BLOCKS: [_NUM_FIELDS]u16 = undefined;
    var _OFFSETS: [_NUM_FIELDS]u16 = undefined;
    var _MASKS: [_NUM_FIELDS]BACKING_INT_TYPE = undefined;
    var _TYPES: [_NUM_FIELDS]type = undefined;
    var _SIZES: [_NUM_FIELDS]u16 = undefined;
    var b: u16 = 0;
    var o: u16 = 0;
    var f: usize = _FREE_BITS;
    var empty_slots: [NUM_BACKING_INTS]struct { block: u16, offset: u16 } = undefined;
    var empty_slots_len: usize = 0;
    for (FIELD_DEFS[0..]) |def| {
        assert_with_reason(b < NUM_BACKING_INTS, @src(), "failed to layout fields, current block ({d} is >= the `NUM_BACKING_INTS` ({d})... try re-ordering the elements in `FIELD_DEFS`", .{ b, NUM_BACKING_INTS });
        assert_with_reason((b * _BITS_PER_BACKING_INT) + o + def.packed_bits < _TOTAL_BITS, @src(), "failed to layout fields, current block ({d}) and offset ({d}) plus field bit size ({d}) would put the total bits beyond the number of bits available in the backing data of {d} x {s}  ({d})... try re-ordering the elements in `FIELD_DEFS`", .{ b, o, def.packed_bits, NUM_BACKING_INTS, @typeName(BACKING_INT_TYPE), _TOTAL_BITS });
        var got_slot_from_empty = false;
        const i = @intFromEnum(def.field);
        for (empty_slots[0..empty_slots_len], 0..) |slot, si| {
            const len = _BITS_PER_BACKING_INT - slot.offset;
            if (len >= def.packed_bits) {
                got_slot_from_empty = true;
                _BLOCKS[i] = slot.block;
                _OFFSETS[i] = slot.offset;
                _MASKS[i] = ((@as(BACKING_INT_TYPE, 1) << @intCast(def.packed_bits)) - 1) << @intCast(slot.offset);
                _TYPES[i] = def.unpacked_type;
                _SIZES[i] = def.packed_bits;
                if (len > def.packed_bits) {
                    empty_slots[si].offset += def.packed_bits;
                } else {
                    Utils.mem_remove((empty_slots[0..]).ptr, &empty_slots_len, si, 1);
                }
                break;
            }
        }
        if (!got_slot_from_empty) {
            if (def.packed_bits < _BITS_PER_BACKING_INT and (o + def.packed_bits > _BITS_PER_BACKING_INT) and (_BITS_PER_BACKING_INT - o) <= f) {
                const take_free_to_align = _BITS_PER_BACKING_INT - o;
                empty_slots[empty_slots_len] = .{ .block = b, .offset = o };
                empty_slots_len += 1;
                o += take_free_to_align;
                b += 1;
                f -= take_free_to_align;
            }
            _BLOCKS[i] = b;
            _OFFSETS[i] = o;
            _MASKS[i] = ((@as(BACKING_INT_TYPE, 1) << @intCast(def.packed_bits)) - 1) << @intCast(o);
            _TYPES[i] = def.unpacked_type;
            _SIZES[i] = def.packed_bits;
            o += def.packed_bits;
            while (o > _BITS_PER_BACKING_INT) {
                b += 1;
                o -= _BITS_PER_BACKING_INT;
            }
        }
    }
    const _BLOCKS_CONST = _BLOCKS;
    const _OFFSETS_CONST = _OFFSETS;
    const _MASKS_CONST = _MASKS;
    const _TYPES_CONST = _TYPES;
    const _TOTAL_CONST = _TOTAL_BITS;
    const _TOTAL_SIZES = _SIZES;
    return extern struct {
        const Self = @This();

        raw: if (MULTIPLE_BACKING) [NUM_BACKING_INTS]BACKING_INT_TYPE else BACKING_INT_TYPE = if (MULTIPLE_BACKING) @splat(0) else 0,

        pub const FIELDS = FIELDS_ENUM;
        pub const NUM_FIELDS = Types.enum_defined_field_count(FIELDS);
        const MULTIPLE_BACKING = NUM_BACKING_INTS > 1;
        pub const TOTAL_BITS = _TOTAL_CONST;
        pub const FIELD_OFFSETS: [NUM_FIELDS]u16 = _OFFSETS_CONST;
        pub const FIELD_MASKS: [NUM_FIELDS]BACKING_INT_TYPE = _MASKS_CONST;
        pub const FIELD_BLOCKS: [NUM_FIELDS]u16 = _BLOCKS_CONST;
        pub const FIELD_TYPES: [NUM_FIELDS]type = _TYPES_CONST;
        pub const FIELD_SIZES: [NUM_FIELDS]u16 = _TOTAL_SIZES;
        pub fn FieldType(comptime F: FIELDS) type {
            return FIELD_TYPES[@intFromEnum(F)];
        }
        pub inline fn get(self: *Self, comptime field: FIELDS) FieldType(field) {
            const i = @intFromEnum(field);
            var val: BACKING_INT_TYPE = if (MULTIPLE_BACKING) self.raw[FIELD_BLOCKS[i]] else self.raw;
            val &= FIELD_MASKS[i];
            val >>= FIELD_OFFSETS[i];
            const OUT_UINT = std.meta.Int(.unsigned, @bitSizeOf(FIELD_TYPES[i]));
            const out_uint: OUT_UINT = @intCast(val);
            return @bitCast(out_uint);
        }
        pub inline fn set(self: *Self, comptime field: FIELDS, val: FieldType(field)) void {
            const i = @intFromEnum(field);
            const IN_UINT = std.meta.Int(.unsigned, @bitSizeOf(FIELD_TYPES[i]));
            const in_uint: IN_UINT = @bitCast(val);
            var sval: BACKING_INT_TYPE = @intCast(in_uint);
            sval <<= @intCast(FIELD_OFFSETS[i]);
            assert_with_reason(sval & ~FIELD_MASKS[i] == 0, @src(), "the bit value of field `{s}` was larger than its stated packed size ({d} bits)", .{FIELD_SIZES[i]});
            if (MULTIPLE_BACKING) {
                const block_idx = FIELD_BLOCKS[i];
                self.raw[block_idx] &= ~FIELD_MASKS[i];
                self.raw[block_idx] |= sval;
            } else {
                self.raw &= ~FIELD_MASKS[i];
                self.raw |= sval;
            }
        }
    };
}
