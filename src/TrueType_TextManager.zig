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
// const build = @import("builtin");
// const math = std.math;
// const Root = @import("./_root.zig");
// const Types = Root.Types;
// const Assert = Root.Assert;
// const Utils = Root.Utils;
// const Allocator = std.mem.Allocator;
// const DummyAllocator = Root.Allocator.Dummy;
// const List = Root.ListSlice.ListAllocated;
// const ListFull = Root.ListSlice.ListFullDefinition;
// const ListFullWithDef = Root.ListSlice.ListFullWithDef;
// const ListSlice = Root.ListSlice;
// const ListDef = ListSlice.ListDef;
// const ListDefNoElem = ListSlice.ListDefNoElem;
// const Vec2 = Root.Vec2;
// const AABB2 = Root.AABB2;
// const MathX = Root.Math;
// const Bezier = Root.Bezier;
// const Cast = Root.Cast;
// const ShapeModule = Root.Shape;
// const Contour = ShapeModule.Contour;
// const DataGridModule = Root.DataGrid;
// const BitmapFormat = Root.FileFormat.Bitmap;
// const PoolModule = Root.Pool;
// const ShapeFn = ShapeModule.Shape;
// const AllocSource = Root.Allocator.AllocSource;
// const Alloc = Root.Allocator.AllocatorAdapter;
// const WyHash = std.hash.Wyhash;
// const File = std.Io.File;
// const Io = std.Io;
// const AllocAdapter = Root.Allocator.AllocatorAdapter;
// const SwissHashMap = Root.HashMap.SwissTableHashMap;
// pub const LockKind = Root.Threading.LocksModule.LockKind;

// const AABB_i32 = AABB2.define_aabb2_type(i32);
// const AABB_i16 = AABB2.define_aabb2_type(i16);
// const AABB_f32 = AABB2.define_aabb2_type(f32);
// const Vec_i16 = Vec2.define_vec2_type(i16);
// const Vec_i32 = Vec2.define_vec2_type(i32);
// const Vec_u32 = Vec2.define_vec2_type(u32);
// const Vec_f32 = Vec2.define_vec2_type(f32);

// const DEBUG = std.debug.print;
// const DEBUG_VAL = Utils.DebugPrint.debug_val;

// const assert_with_reason = Assert.assert_with_reason;
// const assert_unreachable = Assert.assert_unreachable;
// const num_cast = Cast.num_cast;
// const read_int = std.mem.readInt;

// pub const TrueTypeFont = Root.TrueType.TrueTypeFont;
// pub const TrueType = Root.TrueType;
// pub const RowPackedAtlas = Root.RectPacker.RowPackedAtlas;
// pub const GlyphIndex = TrueType.GlyphIndex;
// pub const HashMapOverrides = Root.HashMap.SwissTableHashMapModule.Overrides;
// pub const PackerDef = Root.RectPacker.RowPackerModule.PackerDef;
// pub const PackerDefNoLocks = Root.RectPacker.RowPackerModule.PackerDefNoLocks;
// pub const HorizontalMetrics = TrueType.HorizontalMetrics;
// pub const VerticalMetrics = TrueType.VerticalMetrics;

// const REPLACEMENT_CHAR_CODE = 65533;
// const SPACE_CHAR_CODE = 32;

// pub const HorizontalMetricsI16 = HorizontalMetrics;
// pub const HorizontalMetricsF16 = struct {
//     advance_width: f16,
//     left_side_bearing: f16,
// };
// pub const HorizontalMetricsF32 = struct {
//     advance_width: f32,
//     left_side_bearing: f32,
// };

// pub const StoredMetricMode = enum {
//     UNSCALED_METRICS,
//     SCALED_STORED_I16,
//     SCALED_STORED_F16,
//     SCALED_STORED_F32,

//     pub fn HStroageType(comptime self: StoredMetricMode) type {
//         switch (comptime self) {
//             .UNSCALED_METRICS => HorizontalMetricsI16,
//             .SCALED_STORED_I16 => HorizontalMetricsI16,
//             .SCALED_STORED_F16 => HorizontalMetricsF16,
//             .SCALED_STORED_F32 => HorizontalMetricsF32,
//         }
//     }
// };

// pub const GlyphManagerDef = struct {
//     FONT_LIST_DEF: ListDefNoElem,
//     ROW_PACKER_DEF: PackerDefNoLocks,
//     ATLAS_HASH_MAP_OVERRIDES: HashMapOverrides,
//     /// Float type to use for font scaling.
//     FONT_SCALE_FLOAT: type = f16,
//     /// The mode for storing glyph metrics in the glyph atlas
//     /// THese represent time/memory tradeoffs when reading glyphs
//     STORED_METRIC_MODE: StoredMetricMode = .UNSCALED_METRICS,
//     /// Integer type to use for stable IDs for each unique
//     /// glyph. If `null`, no stable IDs are included/stored
//     ///
//     /// A stable ID is guaranteed not to change as long as a glyph
//     /// exists in the atlas, even when the backing hash-map reallocates.
//     /// Ids are recycled when glyphs are removed from the atlas, and
//     /// new glyhps eagerly consume free IDs to save memory.
//     ///
//     /// The use case for this is optimized rendering, where you use the
//     /// glyph's stable ID as an index into a GPU storage buffer,
//     /// and write the glyph's stable data (such as texture coords)
//     /// into that storage buffer, then instead of passing the entire glyph
//     /// vertex data for every instance, you just pass the stable ID and
//     /// lookup the data in the storage buffer.
//     GLYPH_STABLE_ID_TYPE: ?type = null,
//     BYTES_ALLOC_SOURCE: AllocSource,
//     /// The type to pass for time ticks for each request. Usefull
//     /// for automatic releasing of infrequently used fonts,
//     /// or after all the frequently used glyphs are already loaded
//     /// into the atlas for the given font. 'void' is valid if you don't
//     /// want any time-based functionality,
//     TIME_TICK_TYPE: type = void,
//     LOCK_MODE: LockKind = .NONE,
//     LOCK_ASSERTS: bool = true,
// };

// pub const FontSource = union(FontSourceKind) {
//     BYTES: []const u8,
//     PATH: Utils.File.Path,

//     pub fn from_bytes(font_bytes: []const u8) FontSource {
//         return FontSource{ .BYTES = font_bytes };
//     }
//     pub fn from_path(path: Utils.File.Path) FontSource {
//         return FontSource{ .PATH = path };
//     }
// };

// pub const FontSourceKind = enum {
//     BYTES,
//     PATH,
// };

// pub fn FontAndGlyphManager(comptime DEF: GlyphManagerDef) type {
//     return struct {
//         const Self = @This();

//         pub const LOCK_ASSERTS = DEF.LOCK_ASSERTS;
//         pub const Lock = DEF.LOCK_MODE.lock_type(LOCK_ASSERTS);
//         pub const LockIo = DEF.LOCK_MODE.io_type();
//         pub const LockInit = DEF.LOCK_MODE.init(LOCK_ASSERTS);
//         pub const LockIoInit = DEF.LOCK_MODE.null_io();

//         const FLDEF = DEF.FONT_LIST_DEF;
//         const FontList = ListFull(FontWithInfo, FLDEF.IDX, FLDEF.FIELD_LAYOUT, FLDEF.INDEX_LAYOUT, FLDEF.OWNERSHIP, FLDEF.ALLOC_SOURCE);
//         const FontListInitAlloc = FontList.InitAlloc;
//         const FontListPassAlloc = FontList.PassedAlloc;
//         const FontListNilPassedAlloc = FontList.NilPassedAlloc;
//         pub const FontIdx = FLDEF.IDX;

//         const BytesAllocAdapter = AllocAdapter(DEF.BYTES_ALLOC_SOURCE);
//         const BytesAllocInit = BytesAllocAdapter.InitAlloc;
//         const BytesAllocPassed = BytesAllocAdapter.PassedAlloc;
//         const BytesNilPassedAlloc = BytesAllocAdapter.NilPassedAlloc;
//         const BytesAllocPtr = BytesAllocAdapter.Pointer(u8);

//         const Atlas = RowPackedAtlas(UniqueGlyph, hash_unique_glyph, unique_glyphs_equal, DEF.ATLAS_HASH_MAP_OVERRIDES, DEF.ROW_PACKER_DEF.to_def());
//         const AtlasAllocPassed = Atlas.PassedAlloc;
//         const AtlasNilPassedAlloc = Atlas.Alloc.NilPassedAlloc;
//         const AtlasAllocInit = Atlas.InitAlloc;
//         pub const AtlasIdx = DEF.ROW_PACKER_DEF.IDX;
//         pub const AtlasThresholdVal = Atlas.ThresholdVal;

//         pub const NoDrawMap = SwissHashMap(UniqueGlyph, HorizontalMetrics, hash_unique_glyph, unique_glyphs_equal, .{});

//         pub const FontScale = DEF.FONT_SCALE_FLOAT;
//         pub const FontFloat = DEF.ROW_PACKER_DEF.SIZE_TYPE;
//         pub const FontHMetric = DEF.STORED_METRIC_MODE.HStroageType();
//         pub const USE_STABLE_ID = DEF.GLYPH_STABLE_ID_TYPE != null;
//         pub const GlyphStableId = if (USE_STABLE_ID) DEF.GLYPH_STABLE_ID_TYPE.? else void;
//         pub const Shape = ShapeFn(FontFloat, void, {});
//         pub const Tick = DEF.TIME_TICK_TYPE;

//         pub const AABB = Atlas.AABB;
//         pub const Rect = Atlas.Rect;
//         pub const PackedRect = Atlas.PackedRect;
//         pub const PackedAABB = Atlas.PackedAABB;
//         pub const Size = Vec2.define_vec2_type(FontFloat);
//         pub const Pos = Vec2.define_vec2_type(FontFloat);

//         const FontWithInfo = struct {
//             font: TrueTypeFont,
//             num_glyphs_in_use: u16 = 0,
//             source: FontSource,
//             loaded: bool,
//             allocated_ptr: BytesAllocPtr,
//             last_use_tick: Tick,
//             undef_glyph_index: ?GlyphIndex,
//             space_glyph_index: ?GlyphIndex,
//         };

//         pub const AllocPkg = struct {
//             font_list: FontListPassAlloc = FontListNilPassedAlloc,
//             font_bytes: BytesAllocPassed = BytesNilPassedAlloc,
//             atlas: AtlasAllocPassed = AtlasNilPassedAlloc,
//         };
//         pub const Glyph_HMetric = struct {
//             glyph_index: GlyphIndex,
//             h_metric: FontHMetric,
//             id: GlyphStableId,
//         };
//         pub const Glyph_HMetric_AABB = struct {
//             glyph_index: GlyphIndex,
//             aabb: PackedAABB,
//             h_metric: FontHMetric,
//             id: GlyphStableId,
//         };
//         pub const Glyph_HMetric_AABB_Shape = struct {
//             glyph_index: GlyphIndex,
//             aabb: PackedAABB,
//             h_metric: FontHMetric,
//             shape: Shape,
//             id: GlyphStableId,
//         };
//         pub const GetGlyphResult = union(enum) {
//             NO_DRAW: Glyph_HMetric,
//             FOUND_IN_ATLAS: Glyph_HMetric_AABB,
//             JUST_ADDED_TO_ATLAS: Glyph_HMetric_AABB_Shape,

//             fn no_draw(data: Glyph_HMetric) GetGlyphResult {
//                 return GetGlyphResult{ .NO_DRAW = data };
//             }
//             fn found_in_atlas(data: Glyph_HMetric_AABB) GetGlyphResult {
//                 return GetGlyphResult{ .FOUND_IN_ATLAS = data };
//             }
//             fn just_added_to_atlas(data: Glyph_HMetric_AABB_Shape) GetGlyphResult {
//                 return GetGlyphResult{ .JUST_ADDED_TO_ATLAS = data };
//             }
//         };

//         font_list: FontList = .{},
//         glyph_atlas: Atlas = .{},
//         bytes_alloc_adapter: BytesAllocAdapter = .{},
//         no_draw_hash_map: NoDrawMap = .{},
//         lock: Lock = LockInit,
//         io: LockIo = LockIoInit,

//         pub const InitOptions = struct {
//             font_list_alloc_init: FontListInitAlloc = FontList.Alloc.NilInitAlloc,
//             font_list_init_cap: FontIdx = 4,
//             font_bytes_alloc_init: BytesAllocInit = BytesAllocAdapter.NilInitAlloc,
//             atlas_alloc_init: AtlasAllocInit = Atlas.Alloc.NilInitAlloc,
//             atlas_hash_map_init_cap: AtlasIdx = 100,
//             atlas_row_packer_init_cap: AtlasIdx = 16,
//             atlas_hole_tracker_init_cap: 0,
//             atlas_initial_region: Rect,
//             atlas_default_height_fit_threshold: AtlasThresholdVal = .threshold_val(0.8, 6),
//             io: LockIo = LockIoInit,
//         };

//         pub fn init(self: *Self, opts: InitOptions) void {
//             self.font_list = FontList.allocate_new(opts.font_list_init_cap, opts.font_list_alloc_init);
//             self.bytes_alloc_adapter.init_from_init_alloc(opts.font_bytes_alloc_init);
//             self.glyph_atlas.init(opts.atlas_hash_map_init_cap, opts.atlas_row_packer_init_cap, opts.atlas_hole_tracker_init_cap, opts.atlas_initial_region, opts.atlas_default_height_fit_threshold, opts.atlas_alloc_init, opts.io);
//             self.no_draw_hash_map = .init_capacity(8, opts.atlas_alloc_init);
//         }

//         pub fn uninit(self: *Self, font_list_alloc: FontListPassAlloc, font_bytes_alloc: BytesAllocPassed, atlas_alloc: AtlasAllocPassed) void {
//             for (self.font_list.zig_slice_entire_const()) |font_info| {
//                 switch (font_info.source) {
//                     .BYTES => {},
//                     .PATH => if (font_info.loaded) {
//                         self.bytes_alloc_adapter.free_bytes(font_info.allocated_ptr, font_info.font.ttf_bytes.len, font_bytes_alloc);
//                     },
//                 }
//             }
//             self.font_list.free(font_list_alloc);
//             self.glyph_atlas.uninit(atlas_alloc);
//             self.no_draw_hash_map.uninit(atlas_alloc);
//         }

//         pub fn add_font(self: *Self, font_source: FontSource, font_alloc: FontListPassAlloc, bytes_alloc: BytesAllocPassed) !FontIdx {
//             for (self.font_list.zig_slice_entire_const(), 0..) |existing_font, i| {
//                 if (@backingInt(existing_font.source) == @backingInt(font_source)) {
//                     switch (existing_font.source) {
//                         .PATH => |path| {
//                             if (@backingInt(path) == @backingInt(font_source.PATH)) {
//                                 switch (path) {
//                                     .ABSOLUTE => |path_abs| {
//                                         if (path_abs.path.ptr == font_source.PATH.ABSOLUTE.path.ptr) return @intCast(i);
//                                     },
//                                     .RELATIVE_DIR => |path_rel| {
//                                         if (path_rel.dir.handle == font_source.PATH.RELATIVE_DIR.dir.handle and path_rel.sub_path.ptr == font_source.PATH.RELATIVE_DIR.sub_path.ptr) return @intCast(i);
//                                     },
//                                 }
//                             }
//                         },
//                         .BYTES => |bytes| {
//                             if (bytes.ptr == font_source.BYTES.ptr) return @intCast(i);
//                         },
//                     }
//                 }
//             }
//             switch (font_source) {
//                 .BYTES => |data| return self.add_font_from_bytes(data, font_alloc),
//                 .PATH => |path| return self.add_font_from_file_path(path, font_alloc, bytes_alloc),
//             }
//         }

//         pub fn add_font_from_bytes(self: *Self, font_data: []const u8, font_alloc: FontListPassAlloc) !FontIdx {
//             const loaded_font = try TrueTypeFont.load(font_data);
//             const undef_index = loaded_font.get_codepoint_glyph_index(REPLACEMENT_CHAR_CODE);
//             const space_index = loaded_font.get_codepoint_glyph_index(SPACE_CHAR_CODE);
//             self.font_list.append_one(FontWithInfo{
//                 .font = loaded_font,
//                 .source = .from_bytes(font_data),
//                 .loaded = true,
//                 .undef_glyph_index = undef_index,
//                 .space_glyph_index = space_index,
//             }, font_alloc);
//         }
//         pub fn add_font_from_file_path(self: *Self, path: Utils.File.Path, font_alloc: FontListPassAlloc, bytes_alloc: BytesAllocPassed) !FontIdx {
//             const loaded_font, const alloc_ptr = try TrueTypeFont.load_from_file_path(path, .{}, DEF.BYTES_ALLOC_SOURCE, self.bytes_alloc_adapter, bytes_alloc);
//             const undef_index = loaded_font.get_codepoint_glyph_index(REPLACEMENT_CHAR_CODE);
//             const space_index = loaded_font.get_codepoint_glyph_index(SPACE_CHAR_CODE);
//             return self.font_list.append_one_get_idx(FontWithInfo{
//                 .font = loaded_font,
//                 .source = .from_path(path),
//                 .loaded = true,
//                 .allocated_ptr = alloc_ptr,
//                 .undef_glyph_index = undef_index,
//                 .space_glyph_index = space_index,
//             }, font_alloc);
//         }

//         pub fn unload_font_data(self: *Self, font_idx: FontIdx, bytes_alloc: BytesAllocPassed) void {
//             const font_info: *FontWithInfo = self.font_list.get_ptr(font_idx);
//             switch (font_info.source) {
//                 .PATH => if (font_info.loaded) {
//                     self.bytes_alloc_adapter.free_bytes(font_info.allocated_ptr, font_info.font.ttf_bytes.len, bytes_alloc);
//                     font_info.allocated = null;
//                     font_info.font = undefined;
//                 },
//                 .BYTES => {},
//             }
//         }

//         pub fn reload_font_data(self: *Self, font_idx: FontIdx, tick: Tick, bytes_alloc: BytesAllocPassed) void {
//             const font_info: *FontWithInfo = self.font_list.get_ptr(font_idx);
//             switch (font_info.source) {
//                 .PATH => |path| if (!font_info.loaded) {
//                     const loaded_font, const alloc_ptr = try TrueTypeFont.load_from_file_path(path, .{}, DEF.BYTES_ALLOC_SOURCE, self.bytes_alloc_adapter, bytes_alloc);
//                     font_info.allocated_ptr = alloc_ptr;
//                     font_info.font - loaded_font;
//                     font_info.loaded = true;
//                     font_info.last_use_tick = tick;
//                 },
//                 .BYTES => {},
//             }
//         }

//         pub fn get_glyph(self: *Self, glyph: UniqueGlyph, tick: Tick, allocs: AllocPkg) GetGlyphResult {
//             //CHECKPOINT: Each atlas entry needs a horizontal metric AND a stable ID stored
//             if (self.glyph_atlas.hash_map.get_if_exists(glyph)) |existing| return GetGlyphResult.already_in_atlas(aabb: PackedAABB);
//             self.reload_font_data(glyph.font, tick, allocs.font_bytes);
//             const font_info: *FontWithInfo = self.font_list.get_ptr(glyph.font);
//             var glyph_index = font_info.font.get_codepoint_glyph_index(glyph.codepoint);
//             var draw: bool = false;
//             if (glyph_index == .NOT_DEFINED) {
//                 if (font_info.undef_glyph_index) |index| {
//                     glyph_index = index;
//                     draw = true;
//                 } else if (font_info.space_glyph_index) |index| {
//                     glyph_index = index;
//                     draw = false;
//                 } else {
//                     return .already_in_atlas_no_draw(GlyphIndex.NOT_DEFINED, HorizontalMetrics{ .advance_width = 0, .left_side_bearing = 0 });
//                 }
//             }
//         }

//         pub const UniqueGlyph = struct {
//             codepoint: u32,
//             font: FontIdx,
//             scale: FontScale = 1.0,

//             fn with_substitute_code(self: UniqueGlyph, code: u32) UniqueGlyph {
//                 return UniqueGlyph{
//                     .codepoint = code,
//                     .font = self.font,
//                     .scale = self.scale,
//                 };
//             }
//         };

//         fn hash_unique_glyph(uni_glyph: UniqueGlyph) u64 {
//             var h = WyHash.init(0);
//             h.update(std.mem.asBytes(&uni_glyph.font.internal));
//             h.update(std.mem.asBytes(&uni_glyph.codepoint));
//             h.update(std.mem.asBytes(&uni_glyph.scale));
//             return h.final();
//         }
//         fn unique_glyphs_equal(a: UniqueGlyph, b: UniqueGlyph) bool {
//             return a.font == b.font and a.codepoint == b.codepoint and a.font == b.font;
//         }
//     };
// }
