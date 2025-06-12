// /// TODO documentation
// pub const BufferProperties = struct {
//     endianness: Endian = .native_endian(),
//     packed_elements: bool = false,
// };

// /// TODO documentation
// pub const BufferPropertiesPair = struct {
//     read_properties: BufferProperties = BufferProperties{},
//     write_properties: BufferProperties = BufferProperties{},
// };

// /// TODO documentation
// pub const CopyRange = struct {
//     element_count: usize,
//     read_stride: usize,
//     write_stride: usize,
//     total_read_len: usize,
//     total_write_len: usize,

//     ///TODO documentation
//     pub fn from_count_and_adapter(count: usize, adapter: CopyAdapter) CopyRange {
//         const read_stride = adapter.read_padding_before + adapter.packed_size + adapter.read_padding_after;
//         const write_stride = adapter.write_padding_before + adapter.packed_size + adapter.write_padding_after;
//         const real_count = count * adapter.base_multiple;
//         return CopyRange{
//             .element_count = real_count,
//             .read_stride = read_stride,
//             .write_stride = write_stride,
//             .total_read_len = read_stride * real_count,
//             .total_write_len = write_stride * real_count,
//         };
//     }

//     ///TODO documentation
//     pub fn flip_direction(self: CopyRange) CopyRange {
//         return CopyRange{
//             .element_count = self.element_count,
//             .read_stride = self.write_stride,
//             .total_read_len = self.total_write_len,
//             .write_stride = self.read_stride,
//             .total_write_len = self.total_read_len,
//         };
//     }

//     ///TODO documentation
//     pub fn with_new_count(self: CopyRange, new_count: usize) CopyRange {
//         return CopyRange{
//             .element_count = new_count,
//             .read_stride = self.read_stride,
//             .total_read_len = self.read_stride * new_count,
//             .write_stride = self.write_stride,
//             .total_write_len = self.write_stride * new_count,
//         };
//     }
// };

// /// TODO documentation
// pub const CopyAdapter = struct {
//     element_type: type,
//     base_type: type,
//     base_multiple: usize,
//     packed_size: usize,
//     read_padding_before: usize,
//     read_padding_after: usize,
//     read_endianness: Endian,
//     write_padding_before: usize,
//     write_padding_after: usize,
//     write_endianness: Endian,

//     ///TODO documentation
//     pub fn from_type_and_buffer_properties_pair(comptime element_type: type, comptime buf_properties_pair: BufferPropertiesPair) CopyAdapter {
//         return CopyAdapter.from_type_and_buffer_properties(element_type, buf_properties_pair.read_buf, buf_properties_pair.write_buf);
//     }

//     ///TODO documentation
//     pub fn from_type_and_buffer_properties(comptime element_type: type, comptime read_buf_properties: BufferProperties, comptime write_buf_properties: BufferProperties) CopyAdapter {
//         comptime var base_multiple: usize = 1;
//         comptime var base_type = element_type;
//         comptime while (true) {
//             switch (@typeInfo(base_type)) {
//                 .void, .int, .float, .@"enum", .bool => break,
//                 .@"union" => |union_info| {
//                     if (union_info.layout == .@"packed") {
//                         break;
//                     } else @compileError("union types that do not use a `packed` layout do not have a stable memory layout. Use a custom read/write procedure instead");
//                 },
//                 .@"struct" => |struct_info| {
//                     if (struct_info.layout == .@"packed") {
//                         break;
//                     } else @compileError("struct types that do not use a `packed` layout do not have a stable memory layout. Use a custom read/write procedure instead");
//                 },
//                 .array => |info| {
//                     base_type = info.child;
//                     base_multiple *= info.len;
//                 },
//                 .vector => |info| {
//                     base_type = info.child;
//                     base_multiple *= info.len;
//                 },
//                 .pointer => @compileError("Cannot implicitly read/write pointer types, instead dereference them as their child type"),
//                 .comptime_int, .comptime_float => @compileError("Types `comptime_int` and `comptime_float` cannot be implicitly read/written, use a concrete type instead"),
//                 .error_set, .error_union => @compileError("Types `error_set` and `error_union` do not have stable tag values, use a custom enum/union instead, or manually cast/convert the error tag to an integer or string and read/write that instead"),
//                 .optional => @compileError("optional types (`?T`) may not have a stable memory layout or tag value and writing bytes directly into their pointer address may not result in a valid instance of that type. Instead, manually read/write the tag and optional payload separately"),
//                 else => |bad_info| @compileError("Type " ++ @typeName(@Type(bad_info)) ++ " has no defined read/write procedure."),
//             }
//         };
//         const padded_byte_size = comptime @sizeOf(base_type);
//         const exact_byte_size = comptime mem.alignForward(usize, @bitSizeOf(base_type), 8) >> 3;
//         const padding = comptime padded_byte_size - exact_byte_size;
//         const read_padding_before = if (read_buf_properties.packed_elements) 0 else if (read_buf_properties.endianness == .big_endian) padding else 0;
//         const read_padding_after = if (read_buf_properties.packed_elements) 0 else if (read_buf_properties.endianness == .big_endian) 0 else padding;
//         const write_padding_before = if (write_buf_properties.packed_elements) 0 else if (write_buf_properties.endianness == .big_endian) padding else 0;
//         const write_padding_after = if (write_buf_properties.packed_elements) 0 else if (write_buf_properties.endianness == .big_endian) 0 else padding;
//         return CopyAdapter{
//             .element_type = element_type,
//             .base_type = base_type,
//             .base_multiple = base_multiple,
//             .packed_size = exact_byte_size,
//             .read_endianness = read_buf_properties.endianness,
//             .read_padding_after = read_padding_after,
//             .read_padding_before = read_padding_before,
//             .write_endianness = write_buf_properties.endianness,
//             .write_padding_after = write_padding_after,
//             .write_padding_before = write_padding_before,
//         };
//     }

//     ///TODO documentation
//     pub fn flip_direction(self: CopyAdapter) CopyAdapter {
//         return CopyAdapter{
//             .base_type = self.base_type,
//             .base_multiple = self.base_multiple,
//             .packed_size = self.packed_size,
//             .read_padding_before = self.write_padding_before,
//             .read_padding_after = self.write_padding_after,
//             .read_endianness = self.write_endianness,
//             .write_padding_before = self.read_padding_before,
//             .write_padding_after = self.read_padding_after,
//             .write_endianness = self.read_endianness,
//         };
//     }
// };

// /// Copy bytes from the src buffer to the dst buffer,
// /// with the assumption that the bytes represent an array of elements of a specific type,
// /// with arbirary endianness, and arbitrary padding between elements
// ///
// /// This version takes a runtime-known `CopyRange` and comptime-known `CopyAdapter`
// pub fn copy_elements_with_count(dst: []u8, src: []const u8, count: usize, comptime adapter: CopyAdapter) void {
//     const copy_range = CopyRange.from_count_and_adapter(count, adapter);
//     return copy_elements_with_range(dst, src, copy_range, adapter);
// }

// /// Copy bytes from the src buffer to the dst buffer,
// /// with the assumption that the bytes represent an array of elements of a specific type,
// /// with arbirary endianness, and arbitrary padding between elements
// ///
// /// This version takes a runtime-known `CopyRange` and comptime-known `CopyAdapter`
// pub fn copy_elements_with_range(dst: []u8, src: []const u8, copy_range: CopyRange, comptime adapter: CopyAdapter) void {
//     assert(copy_range.total_read_len <= src.len);
//     assert(copy_range.total_write_len <= dst.len);
//     if ((adapter.read_endianness == adapter.write_endianness or adapter.exact_byte_size == 1) and copy_range.total_read_len == copy_range.total_write_len) {
//         @memcpy(dst[0..copy_range.total_write_len], src[0..copy_range.total_read_len]);
//     } else {
//         const read_start = adapter.read_padding_before;
//         const read_end = read_start + adapter.exact_byte_size;
//         const write_start = adapter.write_padding_before;
//         const write_end = write_start + adapter.exact_byte_size;
//         var idx_vec: @Vector(5, usize) = .{ read_start, read_end, write_start, write_end, 0 };
//         const idx_add_vec: @Vector(5, usize) = .{ copy_range.read_stride, copy_range.read_stride, copy_range.write_stride, copy_range.write_stride, 1 };
//         while (idx_vec[ELEMENT_IDX] < copy_range.element_count) {
//             if (adapter.read_endianness == adapter.write_endianness) {
//                 @memcpy(dst[idx_vec[WRITE_START]..idx_vec[WRITE_END]], src[idx_vec[READ_START]..idx_vec[READ_END]]);
//             } else {
//                 var read_byte_idx = idx_vec[READ_END];
//                 var write_byte_idx = idx_vec[WRITE_START];
//                 while (write_byte_idx < idx_vec[WRITE_END]) {
//                     dst[write_byte_idx] = src[read_byte_idx];
//                     read_byte_idx -= 1;
//                     write_byte_idx += 1;
//                 }
//             }
//             idx_vec += idx_add_vec;
//         }
//     }
//     return;
// }

// /// Copy bytes from the src buffer to the dst buffer,
// /// with the assumption that the bytes represent elements of a specific type,
// /// arbirary endianness, and arbitrary padding between elements
// ///
// /// This version takes a comptime-known `count` and `CopyAdapter`
// pub fn copy_elements_with_comptime_count(dst: []u8, src: []const u8, comptime count: usize, comptime adapter: CopyAdapter) void {
//     const copy_range = comptime CopyRange.from_count_and_adapter(count, adapter);
//     return copy_elements_with_comptime_range(dst, src, copy_range, adapter);
// }

// /// Copy bytes from the src buffer to the dst buffer,
// /// with the assumption that the bytes represent an array of elements of a specific type,
// /// with arbirary endianness, and arbitrary padding between elements
// ///
// /// This version takes a comptime-known `CopyRange` and `CopyAdapter`
// pub fn copy_elements_with_comptime_range(dst: []u8, src: []const u8, comptime copy_range: CopyRange, comptime adapter: CopyAdapter) void {
//     assert(copy_range.total_read_len <= src.len);
//     assert(copy_range.total_write_len <= dst.len);
//     if ((adapter.read_endianness == adapter.write_endianness or adapter.packed_size == 1) and copy_range.total_read_len == copy_range.total_write_len) {
//         @memcpy(dst[0..copy_range.total_write_len], src[0..copy_range.total_read_len]);
//     } else {
//         const read_start = adapter.read_padding_before;
//         const read_end = read_start + adapter.exact_byte_size;
//         const write_start = adapter.write_padding_before;
//         const write_end = write_start + adapter.exact_byte_size;
//         var idx_vec: IdxVec = .{ read_start, read_end, write_start, write_end, 0 };
//         const idx_add_vec: IdxVec = .{ copy_range.read_stride, copy_range.read_stride, copy_range.write_stride, copy_range.write_stride, 1 };
//         while (idx_vec[ELEMENT_IDX] < copy_range.element_count) {
//             if (adapter.read_endianness == adapter.write_endianness) {
//                 @memcpy(dst[idx_vec[WRITE_START]..idx_vec[WRITE_END]], src[idx_vec[READ_START]..idx_vec[READ_END]]);
//             } else {
//                 var read_byte_idx = idx_vec[READ_END];
//                 var write_byte_idx = idx_vec[WRITE_START];
//                 while (write_byte_idx < idx_vec[WRITE_END]) {
//                     dst[write_byte_idx] = src[read_byte_idx];
//                     read_byte_idx -= 1;
//                     write_byte_idx += 1;
//                 }
//             }
//             idx_vec += idx_add_vec;
//         }
//     }
//     return;
// }

// const IdxVec = @Vector(5, usize);
// const READ_START: comptime_int = 0;
// const READ_END: comptime_int = 1;
// const WRITE_START: comptime_int = 2;
// const WRITE_END: comptime_int = 3;
// const ELEMENT_IDX: comptime_int = 4;
