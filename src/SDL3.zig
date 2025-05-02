const std = @import("std");
const build = @import("builtin");
const init_zero = std.mem.zeroes;
const assert = std.debug.assert;

const Root = @import("root");
const C = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

pub const SDL3Error = error{
    SDL3_ERROR__null_value,
    SDL3_ERROR__operation_failure,
};

inline fn ptr_cast_or_null_error(result_ptr: anytype, comptime CAST_TO: type) SDL3Error!CAST_TO {
    if (result_ptr) |good_ptr| return @ptrCast(@alignCast(good_ptr));
    return SDL3Error.SDL3_ERROR__null_value;
}
inline fn slice_cast_or_null_error(result_ptr: anytype, len_ptr: anytype, comptime CAST_TO: type) SDL3Error!CAST_TO {
    if (result_ptr) |good_ptr| return @as(CAST_TO, @ptrCast(@alignCast(good_ptr)))[0..len_ptr.*];
    return SDL3Error.SDL3_ERROR__null_value;
}
inline fn id_or_null_error(result_id: anytype) SDL3Error!@TypeOf(result_id) {
    if (result_id == 0) return SDL3Error.SDL3_ERROR__null_value;
    return result_id;
}
inline fn ok_or_fail_error(result: bool) SDL3Error!void {
    if (result) return void{};
    return SDL3Error.SDL3_ERROR__operation_failure;
}

pub fn sdl_free(mem: ?*anyopaque) void {
    C.SDL_free(mem);
}

pub fn wait_milliseconds(ms: u32) void {
    C.SDL_Delay(ms);
}
pub fn wait_nanoseconds(ns: u64) void {
    C.SDL_DelayNS(ns);
}
pub fn wait_milliseconds_precise(ms: u32) void {
    C.SDL_DelayPrecise(ms);
}

pub fn get_error_details() [:0]const u8 {
    const details_ptr: [*:0]const u8 = C.SDL_GetError();
    return Root.Utils.make_const_slice_from_sentinel_ptr(u8, 0, details_ptr);
}

pub const IRect2 = Root.Rect2.define_rect2_type(c_int);
pub const FRect2 = Root.Rect2.define_rect2_type(f32);
pub const IVec2 = Root.Vec2.define_vec2_type(c_int);
pub const IVec2_16 = Root.Vec2.define_vec2_type(i16);
pub const FVec2 = Root.Vec2.define_vec2_type(f32);
pub const IColor_RGBA = Root.Color.define_color_rgba_type(u8);
pub const FColor_RGBA = Root.Color.define_color_rgba_type(f32);
pub const IColor_RGB = Root.Color.define_color_rgb_type(u8);
pub const FColor_RGB = Root.Color.define_color_rgb_type(f32);

pub const PropertiesID = struct {
    id: C.SDL_PropertiesID = 0,

    // pub extern fn SDL_GetGlobalProperties() SDL_PropertiesID;
    // pub extern fn SDL_CreateProperties() SDL_PropertiesID;
    // pub extern fn SDL_CopyProperties(src: SDL_PropertiesID, dst: SDL_PropertiesID) bool;
    // pub extern fn SDL_LockProperties(props: SDL_PropertiesID) bool;
    // pub extern fn SDL_UnlockProperties(props: SDL_PropertiesID) void;
    // pub const SDL_CleanupPropertyCallback = ?*const fn (?*anyopaque, ?*anyopaque) callconv(.c) void;
    // pub extern fn SDL_SetPointerPropertyWithCleanup(props: SDL_PropertiesID, name: [*c]const u8, value: ?*anyopaque, cleanup: SDL_CleanupPropertyCallback, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_SetPointerProperty(props: SDL_PropertiesID, name: [*c]const u8, value: ?*anyopaque) bool;
    // pub extern fn SDL_SetStringProperty(props: SDL_PropertiesID, name: [*c]const u8, value: [*c]const u8) bool;
    // pub extern fn SDL_SetNumberProperty(props: SDL_PropertiesID, name: [*c]const u8, value: Sint64) bool;
    // pub extern fn SDL_SetFloatProperty(props: SDL_PropertiesID, name: [*c]const u8, value: f32) bool;
    // pub extern fn SDL_SetBooleanProperty(props: SDL_PropertiesID, name: [*c]const u8, value: bool) bool;
    // pub extern fn SDL_HasProperty(props: SDL_PropertiesID, name: [*c]const u8) bool;
    // pub extern fn SDL_GetPropertyType(props: SDL_PropertiesID, name: [*c]const u8) SDL_PropertyType;
    // pub extern fn SDL_GetPointerProperty(props: SDL_PropertiesID, name: [*c]const u8, default_value: ?*anyopaque) ?*anyopaque;
    // pub extern fn SDL_GetStringProperty(props: SDL_PropertiesID, name: [*c]const u8, default_value: [*c]const u8) [*c]const u8;
    // pub extern fn SDL_GetNumberProperty(props: SDL_PropertiesID, name: [*c]const u8, default_value: Sint64) Sint64;
    // pub extern fn SDL_GetFloatProperty(props: SDL_PropertiesID, name: [*c]const u8, default_value: f32) f32;
    // pub extern fn SDL_GetBooleanProperty(props: SDL_PropertiesID, name: [*c]const u8, default_value: bool) bool;
    // pub extern fn SDL_ClearProperty(props: SDL_PropertiesID, name: [*c]const u8) bool;
    // pub const SDL_EnumeratePropertiesCallback = ?*const fn (?*anyopaque, SDL_PropertiesID, [*c]const u8) callconv(.c) void;
    // pub extern fn SDL_EnumerateProperties(props: SDL_PropertiesID, callback: SDL_EnumeratePropertiesCallback, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_DestroyProperties(props: SDL_PropertiesID) void;
};

pub const PropertyType = enum(c_uint) {
    INVALID = C.SDL_PROPERTY_TYPE_INVALID,
    POINTER = C.SDL_PROPERTY_TYPE_POINTER,
    STRING = C.SDL_PROPERTY_TYPE_STRING,
    NUMBER = C.SDL_PROPERTY_TYPE_NUMBER,
    FLOAT = C.SDL_PROPERTY_TYPE_FLOAT,
    BOOLEAN = C.SDL_PROPERTY_TYPE_BOOLEAN,

    pub fn to_c(self: PropertyType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PropertyType {
        return @enumFromInt(val);
    }
};

pub const InitStatus = enum(c_uint) {
    UNINIT = C.SDL_INIT_STATUS_UNINITIALIZED,
    INIT_IN_PROGRESS = C.SDL_INIT_STATUS_INITIALIZING,
    INIT = C.SDL_INIT_STATUS_INITIALIZED,
    UNINIT_IN_PROGRESS = C.SDL_INIT_STATUS_UNINITIALIZING,

    pub fn to_c(self: InitStatus) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) InitStatus {
        return @enumFromInt(val);
    }
};

pub const AudioFormat = enum(c_uint) {
    UNKNOWN = C.SDL_AUDIO_UNKNOWN,
    U8 = C.SDL_AUDIO_U8,
    S8 = C.SDL_AUDIO_S8,
    S16LE = C.SDL_AUDIO_S16LE,
    S16BE = C.SDL_AUDIO_S16BE,
    S32LE = C.SDL_AUDIO_S32LE,
    S32BE = C.SDL_AUDIO_S32BE,
    F32BE = C.SDL_AUDIO_F32LE,
    F32LE = C.SDL_AUDIO_F32BE,
    S16 = C.SDL_AUDIO_S16,
    S32 = C.SDL_AUDIO_S32,
    F32 = C.SDL_AUDIO_F32,

    pub fn to_c(self: AudioFormat) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) AudioFormat {
        return @enumFromInt(val);
    }
};

pub const BlendOperation = enum(c_uint) {
    ADD = C.SDL_BLENDOPERATION_ADD,
    SUBTRACT = C.SDL_BLENDOPERATION_SUBTRACT,
    REV_SUBTRACT = C.SDL_BLENDOPERATION_REV_SUBTRACT,
    MINIMUM = C.SDL_BLENDOPERATION_MINIMUM,
    MAXIMUM = C.SDL_BLENDOPERATION_MAXIMUM,

    pub fn to_c(self: BlendOperation) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) BlendOperation {
        return @enumFromInt(val);
    }
};

pub const BlendFactor = enum(c_uint) {
    ZERO = C.SDL_BLENDFACTOR_ZERO,
    ONE = C.SDL_BLENDFACTOR_ONE,
    SRC_COLOR = C.SDL_BLENDFACTOR_SRC_COLOR,
    ONE_MINUS_SRC_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_COLOR,
    SRC_ALPHA = C.SDL_BLENDFACTOR_SRC_ALPHA,
    ONE_MINUS_SRC_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_SRC_ALPHA,
    DST_COLOR = C.SDL_BLENDFACTOR_DST_COLOR,
    ONE_MINUS_DST_COLOR = C.SDL_BLENDFACTOR_ONE_MINUS_DST_COLOR,
    DST_ALPHA = C.SDL_BLENDFACTOR_DST_ALPHA,
    ONE_MINUS_DST_ALPHA = C.SDL_BLENDFACTOR_ONE_MINUS_DST_ALPHA,

    pub fn to_c(self: BlendFactor) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) BlendFactor {
        return @enumFromInt(val);
    }
};

pub const PixelType = enum(c_uint) {
    UNKNOWN = C.SDL_PIXELTYPE_UNKNOWN,
    INDEX_1 = C.SDL_PIXELTYPE_INDEX1,
    INDEX_2 = C.SDL_PIXELTYPE_INDEX2,
    INDEX_4 = C.SDL_PIXELTYPE_INDEX4,
    INDEX_8 = C.SDL_PIXELTYPE_INDEX8,
    PACKED_8 = C.SDL_PIXELTYPE_PACKED8,
    PACKED_16 = C.SDL_PIXELTYPE_PACKED16,
    PACKED_32 = C.SDL_PIXELTYPE_PACKED32,
    ARRAY_U8 = C.SDL_PIXELTYPE_ARRAYU8,
    ARRAY_U16 = C.SDL_PIXELTYPE_ARRAYU16,
    ARRAY_U32 = C.SDL_PIXELTYPE_ARRAYU32,
    ARRAY_F16 = C.SDL_PIXELTYPE_ARRAYF16,
    ARRAY_F32 = C.SDL_PIXELTYPE_ARRAYF32,

    pub fn to_c(self: PixelType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PixelType {
        return @enumFromInt(val);
    }
};

pub const BitmapOrder = enum(c_uint) {
    NONE = C.SDL_BITMAPORDER_NONE,
    _4321 = C.SDL_BITMAPORDER_4321,
    _1234 = C.SDL_BITMAPORDER_1234,

    pub fn to_c(self: BitmapOrder) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) BitmapOrder {
        return @enumFromInt(val);
    }
};

pub const PackedOrder = enum(c_uint) {
    NONE = C.SDL_PACKEDORDER_NONE,
    XRGB = C.SDL_PACKEDORDER_XRGB,
    RGBX = C.SDL_PACKEDORDER_RGBX,
    ARGB = C.SDL_PACKEDORDER_ARGB,
    RGBA = C.SDL_PACKEDORDER_RGBA,
    XBGR = C.SDL_PACKEDORDER_XBGR,
    BGRX = C.SDL_PACKEDORDER_BGRX,
    ABGR = C.SDL_PACKEDORDER_ABGR,
    BGRA = C.SDL_PACKEDORDER_BGRA,

    pub fn to_c(self: PackedOrder) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PackedOrder {
        return @enumFromInt(val);
    }
};

pub const ArrayOrder = enum(c_uint) {
    NONE = C.SDL_ARRAYORDER_NONE,
    RGB = C.SDL_ARRAYORDER_RGB,
    RGBA = C.SDL_ARRAYORDER_RGBA,
    ARGB = C.SDL_ARRAYORDER_ARGB,
    BGR = C.SDL_ARRAYORDER_BGR,
    BGRA = C.SDL_ARRAYORDER_BGRA,
    ABGR = C.SDL_ARRAYORDER_ABGR,

    pub fn to_c(self: ArrayOrder) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) ArrayOrder {
        return @enumFromInt(val);
    }
};

pub const PackedLayout = enum(c_uint) {
    NONE = C.SDL_PACKEDLAYOUT_NONE,
    _332 = C.SDL_PACKEDLAYOUT_332,
    _4444 = C.SDL_PACKEDLAYOUT_4444,
    _1555 = C.SDL_PACKEDLAYOUT_1555,
    _5551 = C.SDL_PACKEDLAYOUT_5551,
    _565 = C.SDL_PACKEDLAYOUT_565,
    _8888 = C.SDL_PACKEDLAYOUT_8888,
    _2101010 = C.SDL_PACKEDLAYOUT_2101010,
    _1010102 = C.SDL_PACKEDLAYOUT_1010102,

    pub fn to_c(self: PackedLayout) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PackedLayout {
        return @enumFromInt(val);
    }
};

pub const PixelFormat = enum(c_uint) {
    UNKNOWN = C.SDL_PIXELFORMAT_UNKNOWN,
    INDEX_1_LSB = C.SDL_PIXELFORMAT_INDEX1LSB,
    INDEX_1_MSB = C.SDL_PIXELFORMAT_INDEX1MSB,
    INDEX_2_LSB = C.SDL_PIXELFORMAT_INDEX2LSB,
    INDEX_2_MSB = C.SDL_PIXELFORMAT_INDEX2MSB,
    INDEX_4_LSB = C.SDL_PIXELFORMAT_INDEX4LSB,
    INDEX_4_MSB = C.SDL_PIXELFORMAT_INDEX4MSB,
    INDEX_8 = C.SDL_PIXELFORMAT_INDEX8,
    RGB_332 = C.SDL_PIXELFORMAT_RGB332,
    XRGB_4444 = C.SDL_PIXELFORMAT_XRGB4444,
    XBGR_4444 = C.SDL_PIXELFORMAT_XBGR4444,
    XRGB_1555 = C.SDL_PIXELFORMAT_XRGB1555,
    XBGR_1555 = C.SDL_PIXELFORMAT_XBGR1555,
    ARGB_4444 = C.SDL_PIXELFORMAT_ARGB4444,
    RGBA_4444 = C.SDL_PIXELFORMAT_RGBA4444,
    ABGR_4444 = C.SDL_PIXELFORMAT_ABGR4444,
    BGRA_4444 = C.SDL_PIXELFORMAT_BGRA4444,
    ARGB_1555 = C.SDL_PIXELFORMAT_ARGB1555,
    RGBA_5551 = C.SDL_PIXELFORMAT_RGBA5551,
    ABGR_1555 = C.SDL_PIXELFORMAT_ABGR1555,
    BGRA_5551 = C.SDL_PIXELFORMAT_BGRA5551,
    RGB_565 = C.SDL_PIXELFORMAT_RGB565,
    BGR_565 = C.SDL_PIXELFORMAT_BGR565,
    RGB_24 = C.SDL_PIXELFORMAT_RGB24,
    BGR_24 = C.SDL_PIXELFORMAT_BGR24,
    XRGB_8888 = C.SDL_PIXELFORMAT_XRGB8888,
    RGBX_8888 = C.SDL_PIXELFORMAT_RGBX8888,
    XBGR_8888 = C.SDL_PIXELFORMAT_XBGR8888,
    BGRX_8888 = C.SDL_PIXELFORMAT_BGRX8888,
    ARGB_8888 = C.SDL_PIXELFORMAT_ARGB8888,
    RGBA_8888 = C.SDL_PIXELFORMAT_RGBA8888,
    ABGR_8888 = C.SDL_PIXELFORMAT_ABGR8888,
    BGRA_8888 = C.SDL_PIXELFORMAT_BGRA8888,
    XRGB_2101010 = C.SDL_PIXELFORMAT_XRGB2101010,
    XBGR_2101010 = C.SDL_PIXELFORMAT_XBGR2101010,
    ARGB_2101010 = C.SDL_PIXELFORMAT_ARGB2101010,
    ABGR_2101010 = C.SDL_PIXELFORMAT_ABGR2101010,
    RGB_48 = C.SDL_PIXELFORMAT_RGB48,
    BGR_48 = C.SDL_PIXELFORMAT_BGR48,
    RGBA_64 = C.SDL_PIXELFORMAT_RGBA64,
    ARGB_64 = C.SDL_PIXELFORMAT_ARGB64,
    BGRA_64 = C.SDL_PIXELFORMAT_BGRA64,
    ABGR_64 = C.SDL_PIXELFORMAT_ABGR64,
    RGB_48_FLOAT = C.SDL_PIXELFORMAT_RGB48_FLOAT,
    BGR_48_FLOAT = C.SDL_PIXELFORMAT_BGR48_FLOAT,
    RGBA_64_FLOAT = C.SDL_PIXELFORMAT_RGBA64_FLOAT,
    ARGB_64_FLOAT = C.SDL_PIXELFORMAT_ARGB64_FLOAT,
    BGRA_64_FLOAT = C.SDL_PIXELFORMAT_BGRA64_FLOAT,
    ABGR_64_FLOAT = C.SDL_PIXELFORMAT_ABGR64_FLOAT,
    RGB_96_FLOAT = C.SDL_PIXELFORMAT_RGB96_FLOAT,
    BGR_96_FLOAT = C.SDL_PIXELFORMAT_BGR96_FLOAT,
    RGBA_128_FLOAT = C.SDL_PIXELFORMAT_RGBA128_FLOAT,
    ARGB_128_FLOAT = C.SDL_PIXELFORMAT_ARGB128_FLOAT,
    BGRA_128_FLOAT = C.SDL_PIXELFORMAT_BGRA128_FLOAT,
    ABGR_128_FLOAT = C.SDL_PIXELFORMAT_ABGR128_FLOAT,
    YV12 = C.SDL_PIXELFORMAT_YV12,
    IYUV = C.SDL_PIXELFORMAT_IYUV,
    YUY2 = C.SDL_PIXELFORMAT_YUY2,
    UYVY = C.SDL_PIXELFORMAT_UYVY,
    YVYU = C.SDL_PIXELFORMAT_YVYU,
    NV12 = C.SDL_PIXELFORMAT_NV12,
    NV21 = C.SDL_PIXELFORMAT_NV21,
    P010 = C.SDL_PIXELFORMAT_P010,
    EXTERNAL_OES = C.SDL_PIXELFORMAT_EXTERNAL_OES,
    MJPG = C.SDL_PIXELFORMAT_MJPG,
    RGBA_32 = C.SDL_PIXELFORMAT_RGBA32,
    ARGB_32 = C.SDL_PIXELFORMAT_ARGB32,
    BGRA_32 = C.SDL_PIXELFORMAT_BGRA32,
    ABGR_32 = C.SDL_PIXELFORMAT_ABGR32,
    RGBX_32 = C.SDL_PIXELFORMAT_RGBX32,
    XRGB_32 = C.SDL_PIXELFORMAT_XRGB32,
    BGRX_32 = C.SDL_PIXELFORMAT_BGRX32,
    XBGR_32 = C.SDL_PIXELFORMAT_XBGR32,

    pub fn to_c(self: PixelFormat) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PixelFormat {
        return @enumFromInt(val);
    }
};

pub const ColorType = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_TYPE_UNKNOWN,
    RGB = C.SDL_COLOR_TYPE_RGB,
    YCBCR = C.SDL_COLOR_TYPE_YCBCR,

    pub fn to_c(self: ColorType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) ColorType {
        return @enumFromInt(val);
    }
};

pub const ColorRange = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_RANGE_UNKNOWN,
    LIMITED = C.SDL_COLOR_RANGE_LIMITED,
    FULL = C.SDL_COLOR_RANGE_FULL,

    pub fn to_c(self: ColorRange) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) ColorRange {
        return @enumFromInt(val);
    }
};

pub const ColorPrimaries = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_PRIMARIES_UNKNOWN,
    BT709 = C.SDL_COLOR_PRIMARIES_BT709,
    UNSPECIFIED = C.SDL_COLOR_PRIMARIES_UNSPECIFIED,
    BT470M = C.SDL_COLOR_PRIMARIES_BT470M,
    BT470BG = C.SDL_COLOR_PRIMARIES_BT470BG,
    BT601 = C.SDL_COLOR_PRIMARIES_BT601,
    SMPTE240 = C.SDL_COLOR_PRIMARIES_SMPTE240,
    GENERIC_FILM = C.SDL_COLOR_PRIMARIES_GENERIC_FILM,
    BT2020 = C.SDL_COLOR_PRIMARIES_BT2020,
    XYZ = C.SDL_COLOR_PRIMARIES_XYZ,
    SMPTE431 = C.SDL_COLOR_PRIMARIES_SMPTE431,
    SMPTE432 = C.SDL_COLOR_PRIMARIES_SMPTE432,
    EBU3213 = C.SDL_COLOR_PRIMARIES_EBU3213,
    CUSTOM = C.SDL_COLOR_PRIMARIES_CUSTOM,

    pub fn to_c(self: ColorPrimaries) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) ColorPrimaries {
        return @enumFromInt(val);
    }
};

pub const FlipMode = enum(c_uint) {
    NONE = C.SDL_FLIP_NONE,
    HORIZONTAL = C.SDL_FLIP_HORIZONTAL,
    VERTICAL = C.SDL_FLIP_VERTICAL,
    HORIZ_VERT = C.SDL_FLIP_HORIZONTAL | C.SDL_FLIP_VERTICAL,

    pub fn to_c(self: FlipMode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) FlipMode {
        return @enumFromInt(val);
    }
};

pub const Clipboard = struct {
    pub fn get_text() [:0]const u8 {
        const clip: [*:0]u8 = C.SDL_GetClipboardText();
        return Root.Utils.make_slice_from_sentinel_ptr(u8, 0, clip);
    }
    pub fn set_text(text: [:0]const u8) bool {
        return C.SDL_SetClipboardText(text.ptr);
    }
    pub fn has_text() bool {
        return C.SDL_HasClipboardText();
    }

    // pub extern fn SDL_SetPrimarySelectionText(text: [*c]const u8) bool;
    // pub extern fn SDL_GetPrimarySelectionText() [*c]u8;
    // pub extern fn SDL_HasPrimarySelectionText() bool;
    // pub const SDL_ClipboardDataCallback = ?*const fn (?*anyopaque, [*c]const u8, [*c]usize) callconv(.c) ?*const anyopaque;
    // pub const SDL_ClipboardCleanupCallback = ?*const fn (?*anyopaque) callconv(.c) void;
    // pub extern fn SDL_SetClipboardData(callback: SDL_ClipboardDataCallback, cleanup: SDL_ClipboardCleanupCallback, userdata: ?*anyopaque, mime_types: [*c][*c]const u8, num_mime_types: usize) bool;
    // pub extern fn SDL_ClearClipboardData() bool;
    // pub extern fn SDL_GetClipboardData(mime_type: [*c]const u8, size: [*c]usize) ?*anyopaque;
    // pub extern fn SDL_HasClipboardData(mime_type: [*c]const u8) bool;
    // pub extern fn SDL_GetClipboardMimeTypes(num_mime_types: [*c]usize) [*c][*c]u8;
};

pub const DisplayOrientation = enum(c_int) {
    UNKNOWN = C.SDL_ORIENTATION_UNKNOWN,
    LANDSCAPE = C.SDL_ORIENTATION_LANDSCAPE,
    LANDSCAPE_FLIPPED = C.SDL_ORIENTATION_LANDSCAPE_FLIPPED,
    PORTRAIT = C.SDL_ORIENTATION_PORTRAIT,
    PORTRAIT_FLIPPED = C.SDL_ORIENTATION_PORTRAIT_FLIPPED,

    pub fn to_c(self: DisplayOrientation) c_int {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_int) DisplayOrientation {
        return @enumFromInt(val);
    }
};

pub const DisplayID = extern struct {
    id: u32 = 0,

    pub fn get_all_displays() SDL3Error!DisplayList {
        var len: c_int = 0;
        return DisplayList{ .ids = try slice_cast_or_null_error(C.SDL_GetDisplays(&len), &len, [*]u32) };
    }
    pub fn get_primary_display() SDL3Error!DisplayID {
        return DisplayID{ .id = try id_or_null_error(C.SDL_GetPrimaryDisplay()) };
    }
    pub fn get_properties(self: DisplayID) SDL3Error!PropertiesID {
        return PropertiesID{ .id = try id_or_null_error(C.SDL_GetDisplayProperties(self.id)) };
    }
    pub fn get_name(self: DisplayID) SDL3Error![*:0]const u8 {
        return ptr_cast_or_null_error(C.SDL_GetDisplayName(self.id), [*:0]const u8);
    }
    pub fn get_bounds(self: DisplayID) SDL3Error!IRect2 {
        var rect = IRect2{};
        try ok_or_fail_error(C.SDL_GetDisplayBounds(self.id, @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn get_usable_bounds(self: DisplayID) SDL3Error!IRect2 {
        var rect = IRect2{};
        try ok_or_fail_error(C.SDL_GetDisplayUsableBounds(self.id, @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn get_natural_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_c(C.SDL_GetNaturalDisplayOrientation(self.id));
    }
    pub fn get_current_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_c(C.SDL_GetCurrentDisplayOrientation(self.id));
    }
    pub fn get_content_scale(self: DisplayID) f32 {
        return C.SDL_GetDisplayContentScale(self.id);
    }
    pub fn get_all_fullscreen_modes(self: DisplayID) SDL3Error!DisplayModeList {
        const len: c_int = 0;
        return DisplayModeList{
            .modes = try slice_cast_or_null_error(C.SDL_GetFullscreenDisplayModes(self.id, &len), &len, [*]*DisplayMode),
        };
    }
    pub fn get_closest_fullscreen_mode(self: DisplayID, options: ClosestDisplayModeOptions) SDL3Error!DisplayMode {
        const mode = DisplayMode{};
        try ok_or_fail_error(C.SDL_GetClosestFullscreenDisplayMode(self.id, options.width, options.height, options.refresh_rate, options.include_high_density_modes, @ptrCast(@alignCast(&mode))));
        return mode;
    }
    pub fn get_desktop_mode(self: DisplayID) SDL3Error!*const DisplayMode {
        return ptr_cast_or_null_error(C.SDL_GetDesktopDisplayMode(self.id), *const DisplayMode);
    }
    pub fn get_current_mode(self: DisplayID) SDL3Error!*const DisplayMode {
        return ptr_cast_or_null_error(C.SDL_GetCurrentDisplayMode(self.id), *const DisplayMode);
    }
    pub fn get_display_for_point(point: IVec2) SDL3Error!DisplayID {
        return DisplayID{ .id = try id_or_null_error(C.SDL_GetDisplayForPoint(@ptrCast(@alignCast(&point)))) };
    }
    pub fn get_display_for_rect(rect: IRect2) SDL3Error!DisplayID {
        return DisplayID{ .id = try id_or_null_error(C.SDL_GetDisplayForRect(@ptrCast(@alignCast(&rect)))) };
    }
};

pub const ClosestDisplayModeOptions = struct {
    width: f32 = 800,
    height: f32 = 600,
    refresh_rate: f32 = 60.0,
    include_high_density_modes: bool = true,
};

pub const WindowID = extern struct {
    id: u32 = 0,

    pub fn get_window(self: WindowID) SDL3Error!Window {
        return Window{ .extern_ptr = try ptr_cast_or_null_error(C.SDL_GetWindowFromID(self.id), Window.External) };
    }
};

pub const DisplayModeData = extern struct {
    extern_ptr: *External,

    pub const External: type = C.SDL_DisplayModeData;
};

pub const DisplayMode = extern struct {
    display: DisplayID = DisplayID{},
    pixel_format: PixelFormat = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    pixel_density: f32 = 0.0,
    refresh_rate: f32 = 0.0,
    refresh_rate_numerator: c_int = 0,
    refresh_rate_denominator: c_int = 0,
    data: ?DisplayModeData = null,

    // pub inline fn to_c(self: DisplayMode) C.SDL_DisplayMode {
    //     return @bitCast(self);
    // }
};

pub const Window = opaque {
    fn to_c(self: *Window) *C.SDL_Window {
        return @ptrCast(@alignCast(self));
    }
    pub fn try_get_display_id(self: *Window) SDL3Error!DisplayID {
        return DisplayID{ .id = try id_or_null_error(C.SDL_GetDisplayForWindow(self.to_c())) };
    }
    pub fn get_pixel_density(self: *Window) f32 {
        return C.SDL_GetWindowPixelDensity(self.to_c());
    }
    pub fn get_display_scale(self: *Window) f32 {
        return C.SDL_GetWindowDisplayScale(self.to_c());
    }
    pub fn get_fullscreen_display_mode(self: *Window) FullscreenMode {
        const result: ?*const DisplayMode = C.SDL_GetWindowFullscreenMode(self);
        if (result) |mode| return FullscreenMode.new_exclusive(mode);
        return FullscreenMode.new_borderless();
    }
    pub fn set_fullscreen_display_mode(self: *Window, mode: FullscreenMode) SDL3Error!void {
        switch (mode) {
            .borderless => try ok_or_fail_error(C.SDL_SetWindowFullscreenMode(self.to_c(), null)),
            .exclusive => |excl_mode| try ok_or_fail_error(C.SDL_SetWindowFullscreenMode(self.to_c(), @ptrCast(@alignCast(excl_mode)))),
        }
    }
    pub fn get_icc_profile(self: *Window, size: usize) SDL3Error!WindowICCProfile {
        return WindowICCProfile{ .extern_ptr = try ptr_cast_or_null_error(C.SDL_GetWindowICCProfile(self.to_c(), &size), *WindowICCProfile.Extern) };
    }
    pub fn get_pixel_format(self: *Window) PixelFormat {
        return @enumFromInt(C.SDL_GetWindowPixelFormat(self.to_c()));
    }
    pub fn get_all_windows() SDL3Error!WindowsList {
        var len: c_int = 0;
        return WindowsList{ .list = try slice_cast_or_null_error(C.SDL_GetWindows(&len), &len, [*]*Window) };
    }
    pub fn create(options: CreateWindowOptions) SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_CreateWindow(options.title.ptr, options.width, options.height, options.flags), *Window);
    }
    pub fn create_popup_window(parent: *Window, options: CreatePopupWindowOptions) SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_CreatePopupWindow(parent.to_c(), options.x_offset, options.y_offset, options.width, options.height, options.flags), *Window);
    }
    pub fn create_window_with_properties(properties: PropertiesID) SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_CreateWindowWithProperties(properties.id), *Window);
    }
    pub fn get_id(self: *Window) WindowID {
        return WindowID{ .id = C.SDL_GetWindowID(self.to_c()) };
    }
    pub fn get_parent_window(self: *Window) SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_GetWindowParent(self.to_c()), *Window);
    }
    pub fn get_properties(self: *Window) PropertiesID {
        return PropertiesID{ .id = C.SDL_GetWindowProperties(self.to_c()) };
    }
    pub fn get_flags(self: *Window) WindowFlags {
        return WindowFlags{ .flags = C.SDL_GetWindowFlags(self.to_c()) };
    }
    pub fn set_title(self: *Window, title: [:0]const u8) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowTitle(self.to_c(), title.ptr));
    }
    pub fn get_title(self: *Window) [*:0]const u8 {
        return @ptrCast(@alignCast(C.SDL_GetWindowTitle(self.to_c())));
    }
    pub fn set_window_icon(self: *Window, icon: *Surface) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowIcon(self.to_c(), @ptrCast(@alignCast(icon))));
    }
    pub fn set_window_position(self: *Window, pos: IVec2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowPosition(self.to_c(), pos.x, pos.y));
    }
    pub fn get_window_position(self: *Window) SDL3Error!IVec2 {
        var point = IVec2{};
        try ok_or_fail_error(C.SDL_GetWindowPosition(self.to_c(), &point.x, &point.y));
        return point;
    }
    pub fn set_size(self: *Window, size: IVec2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowSize(self.to_c(), size.x, size.y));
    }
    pub fn get_size(self: *Window) SDL3Error!IVec2 {
        var size = IVec2.ZERO;
        try ok_or_fail_error(C.SDL_GetWindowSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn get_safe_area(self: *Window) SDL3Error!IRect2 {
        var rect = IRect2{};
        try ok_or_fail_error(C.SDL_GetWindowSafeArea(self.to_c(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn set_aspect_ratio(self: *Window, aspect_range: AspectRange) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowAspectRatio(self.to_c(), aspect_range.min, aspect_range.max));
    }
    pub fn get_aspect_ratio(self: *Window) SDL3Error!AspectRange {
        var ratio = AspectRange{};
        try ok_or_fail_error(C.SDL_SetWindowAspectRatio(self.to_c(), &ratio.min, &ratio.max));
        return ratio;
    }
    pub fn get_border_sizes(self: *Window) SDL3Error!BorderSizes {
        var sizes = BorderSizes{};
        try ok_or_fail_error(C.SDL_GetWindowBordersSize(self.to_c(), &sizes.top, &sizes.left, &sizes.bottom, &sizes.right));
        return sizes;
    }
    pub fn get_size_in_pixels(self: *Window) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetWindowSizeInPixels(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_minimum_size(self: *Window, size: IVec2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowMinimumSize(self.to_c(), size.x, size.y));
    }
    pub fn get_minimum_size(self: *Window) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetWindowMinimumSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_maximum_size(self: *Window, size: IVec2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowMaximumSize(self.to_c(), size.x, size.y));
    }
    pub fn get_maximum_size(self: *Window) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetWindowMaximumSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_bordered(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowBordered(self.to_c(), state));
    }
    pub fn set_resizable(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowResizable(self.to_c(), state));
    }
    pub fn set_always_on_top(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowAlwaysOnTop(self.to_c(), state));
    }
    pub fn show(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_ShowWindow(self.to_c()));
    }
    pub fn hide(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_HideWindow(self.to_c()));
    }
    pub fn raise(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_RaiseWindow(self.to_c()));
    }
    pub fn maximize(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_MaximizeWindow(self.to_c()));
    }
    pub fn minimize(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_MinimizeWindow(self.to_c()));
    }
    pub fn restore(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_RestoreWindow(self.to_c()));
    }
    pub fn set_fullscreen(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowFullscreen(self.to_c(), state));
    }
    pub fn sync(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SyncWindow(self.to_c()));
    }
    pub fn has_surface(self: *Window) bool {
        return C.SDL_WindowHasSurface(self.to_c());
    }
    pub fn get_surface(self: *Window) SDL3Error!*Surface {
        return ptr_cast_or_null_error(C.SDL_GetWindowSurface(self.to_c()), *Surface);
    }
    pub fn set_surface_vsync(self: *Window, vsync: VSync) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowSurfaceVSync(self.to_c(), vsync.to_c()));
    }
    pub fn get_surface_vsync(self: *Window) SDL3Error!VSync {
        var int: c_int = 0;
        try ok_or_fail_error(C.SDL_GetWindowSurfaceVSync(self.to_c(), &int));
        return VSync.from_c(int);
    }
    pub fn update_surface(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_UpdateWindowSurface(self.to_c()));
    }
    pub fn update_surface_rects(self: *Window, rects: []const IRect2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_UpdateWindowSurfaceRects(self.to_c(), @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len)));
    }
    pub fn destroy_surface(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_DestroyWindowSurface(self.to_c()));
    }
    pub fn set_keyboard_grab(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowKeyboardGrab(self.to_c(), state));
    }
    pub fn set_mouse_grab(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowMouseGrab(self.to_c(), state));
    }
    pub fn get_keyboard_grab(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_GetWindowKeyboardGrab(self.to_c()));
    }
    pub fn get_mouse_grab(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_GetWindowMouseGrab(self.to_c()));
    }
    pub fn get_grabbed_window() SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_GetGrabbedWindow(), *Window);
    }
    pub fn set_mouse_rect(self: *Window, rect: IRect2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowMouseRect(self.to_c(), @ptrCast(@alignCast(&rect))));
    }
    pub fn get_mouse_rect(self: *Window) SDL3Error!IRect2 {
        const rect_ptr = try ptr_cast_or_null_error(C.SDL_GetWindowMouseRect(self.to_c()), *IRect2);
        return rect_ptr.*;
    }
    pub fn set_opacity(self: *Window, opacity: f32) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowOpacity(self.to_c(), opacity));
    }
    pub fn get_opacity(self: *Window) f32 {
        return C.SDL_GetWindowOpacity(self.to_c());
    }
    pub fn set_parent(self: *Window, parent: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowParent(self.to_c(), parent.to_c()));
    }
    pub fn clear_parent(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowParent(self.to_c(), null));
    }
    pub fn set_modal(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowModal(self.to_c(), state));
    }
    pub fn set_focusable(self: *Window, state: bool) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowFocusable(self.to_c(), state));
    }
    pub fn show_system_menu(self: *Window, pos: IVec2) SDL3Error!void {
        try ok_or_fail_error(C.SDL_ShowWindowSystemMenu(self.to_c(), pos.x, pos.y));
    }
    pub fn set_custom_hittest(self: *Window, hittest: CustomWindowHittest, data: ?*anyopaque) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowHitTest(self.to_c(), hittest, data));
    }
    pub fn set_window_shape(self: *Window, shape: *Surface) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowShape(self.to_c(), @ptrCast(@alignCast(shape))));
    }
    pub fn clear_window_shape(self: *Window) SDL3Error!void {
        try ok_or_fail_error(C.SDL_SetWindowShape(self.to_c(), null));
    }
    pub fn flash_window(self: *Window, mode: FlashMode) SDL3Error!void {
        try ok_or_fail_error(C.SDL_FlashWindow(self.to_c(), mode.to_c()));
    }
    pub fn destroy(self: *Window) void {
        C.SDL_DestroyWindow(self.to_c());
    }
    pub fn create_renderer(self: *Window, name: [:0]const u8) SDL3Error!*Renderer {
        return ptr_cast_or_null_error(C.SDL_CreateRenderer(self.extern_ptr, name.ptr), *Renderer);
    }
    pub fn get_renderer(self: *Window) SDL3Error!*Renderer {
        return ptr_cast_or_null_error(C.SDL_GetRenderer(self.extern_ptr), *Renderer);
    }
};

pub const FlashMode = enum(c_uint) {
    CANCEL = C.SDL_FLASH_CANCEL,
    BRIEFLY = C.SDL_FLASH_BRIEFLY,
    UNTIL_FOCUSED = C.SDL_FLASH_UNTIL_FOCUSED,

    pub fn to_c(self: FlashMode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) FlashMode {
        return @enumFromInt(val);
    }
};

pub const WindowHitTestResult = enum(c_uint) {
    NORMAL = C.SDL_HITTEST_NORMAL,
    DRAGGABLE = C.SDL_HITTEST_DRAGGABLE,
    RESIZE_TOPLEFT = C.SDL_HITTEST_RESIZE_TOPLEFT,
    RESIZE_TOP = C.SDL_HITTEST_RESIZE_TOP,
    RESIZE_TOPRIGHT = C.SDL_HITTEST_RESIZE_TOPRIGHT,
    RESIZE_RIGHT = C.SDL_HITTEST_RESIZE_RIGHT,
    RESIZE_BOTTOMRIGHT = C.SDL_HITTEST_RESIZE_BOTTOMRIGHT,
    RESIZE_BOTTOM = C.SDL_HITTEST_RESIZE_BOTTOM,
    RESIZE_BOTTOMLEFT = C.SDL_HITTEST_RESIZE_BOTTOMLEFT,
    RESIZE_LEFT = C.SDL_HITTEST_RESIZE_LEFT,

    pub fn to_c(self: WindowHitTestResult) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) WindowHitTestResult {
        return @enumFromInt(val);
    }
};

pub const CustomWindowHittest = ?*const fn (?*Window.External, [*c]const C.SDL_Point, ?*anyopaque) callconv(.c) c_uint;

pub const VSync = enum(c_int) {
    adaptive = C.SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE,
    disabled = C.SDL_WINDOW_SURFACE_VSYNC_DISABLED,
    _,

    pub fn to_c(self: VSync) c_int {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_int) VSync {
        return @enumFromInt(val);
    }
};

pub const BorderSizes = extern struct {
    top: c_uint = 0,
    left: c_uint = 0,
    bottom: c_uint = 0,
    right: c_uint = 0,
};

pub const AspectRange = extern struct {
    min: f32 = 0.1,
    max: f32 = 10.0,
};

pub const CreateWindowOptions = extern struct {
    title: [:0]const u8 = "New Window",
    flags: WindowFlags = WindowFlags{},
    size: IVec2 = IVec2.new(800, 600),
};

pub const CreatePopupWindowOptions = extern struct {
    flags: WindowFlags = WindowFlags{},
    offset: IVec2 = IVec2.ZERO,
    size: IVec2 = IVec2.new(400, 300),
};

pub const WindowsList = extern struct {
    list: []Window,

    pub fn free(self: WindowsList) void {
        sdl_free(self.list.ptr);
    }
};

pub const FullscreenMode = union(enum) {
    borderless: void,
    exclusive: *const DisplayMode,

    pub fn new_borderless() FullscreenMode {
        return FullscreenMode{ .borderless = void{} };
    }
    pub fn new_exclusive(mode: *const DisplayMode) FullscreenMode {
        return FullscreenMode{ .exclusive = mode };
    }
};

pub const WindowICCProfile = opaque {};

pub const DisplayModeList = extern struct {
    modes: []*DisplayMode,

    pub fn free(self: DisplayModeList) void {
        sdl_free(self.modes.ptr);
    }
};

pub const DisplayList = extern struct {
    ids: []DisplayID,

    pub fn free(self: DisplayList) void {
        sdl_free(self.ids.ptr);
    }
};

pub const WindowFlags = extern struct {
    flags: FLAG_UINT = 0,

    const FLAG_UINT: type = @TypeOf(C.SDL_WINDOW_FULLSCREEN);
    pub fn new(flags: []const FLAG) WindowFlags {
        var val: FLAG_UINT = 0;
        for (flags) |flag| {
            val |= @intFromEnum(flag);
        }
        return WindowFlags{ .flags = val };
    }
    pub fn set(self: *WindowFlags, flag: FLAG) void {
        self.flags |= @intFromEnum(flag);
    }
    pub fn set_raw(self: *WindowFlags, raw_flags: FLAG_UINT) void {
        self.flags |= raw_flags;
    }
    pub fn clear(self: *WindowFlags, flag: FLAG) void {
        self.flags &= ~@intFromEnum(flag);
    }
    pub fn clear_raw(self: *WindowFlags, raw_flags: FLAG_UINT) void {
        self.flags &= ~raw_flags;
    }
    pub fn clear_all(self: *WindowFlags) void {
        self.flags = 0;
    }
    pub fn is_set(self: *const WindowFlags, flag: FLAG) bool {
        return self.flags & @intFromEnum(flag) > 0;
    }
    pub fn set_many(self: *WindowFlags, other: WindowFlags) void {
        self.flags |= other.flags;
    }
    pub fn clear_many(self: *WindowFlags, other: WindowFlags) void {
        self.flags &= ~other.flags;
    }
    pub const FLAG = enum(FLAG_UINT) {
        FULLSCREEN = C.SDL_WINDOW_FULLSCREEN,
        OPENGL = C.SDL_WINDOW_OPENGL,
        OCCLUDED = C.SDL_WINDOW_OCCLUDED,
        HIDDEN = C.SDL_WINDOW_HIDDEN,
        BORDERLESS = C.SDL_WINDOW_BORDERLESS,
        RESIZABLE = C.SDL_WINDOW_RESIZABLE,
        MINIMIZED = C.SDL_WINDOW_MINIMIZED,
        MAXIMIZED = C.SDL_WINDOW_MAXIMIZED,
        MOUSE_GRABBED = C.SDL_WINDOW_MOUSE_GRABBED,
        INPUT_FOCUS = C.SDL_WINDOW_INPUT_FOCUS,
        MOUSE_FOCUS = C.SDL_WINDOW_MOUSE_FOCUS,
        EXTERNAL = C.SDL_WINDOW_EXTERNAL,
        MODAL = C.SDL_WINDOW_MODAL,
        HIGH_PIXEL_DENSITY = C.SDL_WINDOW_HIGH_PIXEL_DENSITY,
        MOUSE_CAPTURE = C.SDL_WINDOW_MOUSE_CAPTURE,
        MOUSE_RELATIVE_MODE = C.SDL_WINDOW_MOUSE_RELATIVE_MODE,
        ALWAYS_ON_TOP = C.SDL_WINDOW_ALWAYS_ON_TOP,
        UTILITY = C.SDL_WINDOW_UTILITY,
        TOOLTIP = C.SDL_WINDOW_TOOLTIP,
        POPUP_MENU = C.SDL_WINDOW_POPUP_MENU,
        KEYBOARD_GRABBED = C.SDL_WINDOW_KEYBOARD_GRABBED,
        VULKAN = C.SDL_WINDOW_VULKAN,
        METAL = C.SDL_WINDOW_METAL,
        TRANSPARENT = C.SDL_WINDOW_TRANSPARENT,
        NOT_FOCUSABLE = C.SDL_WINDOW_NOT_FOCUSABLE,

        pub fn to_c(self: FLAG_UINT) c_uint {
            return @intFromEnum(self);
        }
        pub fn from_c(val: c_uint) FLAG_UINT {
            return @enumFromInt(val);
        }
    };
};

pub const Surface = extern struct {
    flags: SurfaceFlags = SurfaceFlags{},
    format: PixelFormat = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    bytes_per_row: c_int = 0,
    pixel_data: ?[*]u8 = null,
    refcount: c_int = 0,
    reserved: ?*anyopaque = null,

    // pub extern fn SDL_CreateSurface(width: c_int, height: c_int, format: SDL_PixelFormat) [*c]SDL_Surface;
    // pub extern fn SDL_CreateSurfaceFrom(width: c_int, height: c_int, format: SDL_PixelFormat, pixels: ?*anyopaque, pitch: c_int) [*c]SDL_Surface;
    // pub extern fn SDL_DestroySurface(surface: [*c]SDL_Surface) void;
    // pub extern fn SDL_GetSurfaceProperties(surface: [*c]SDL_Surface) SDL_PropertiesID;
    // pub extern fn SDL_SetSurfaceColorspace(surface: [*c]SDL_Surface, colorspace: SDL_Colorspace) bool;
    // pub extern fn SDL_GetSurfaceColorspace(surface: [*c]SDL_Surface) SDL_Colorspace;
    // pub extern fn SDL_CreateSurfacePalette(surface: [*c]SDL_Surface) [*c]SDL_Palette;
    // pub extern fn SDL_SetSurfacePalette(surface: [*c]SDL_Surface, palette: [*c]SDL_Palette) bool;
    // pub extern fn SDL_GetSurfacePalette(surface: [*c]SDL_Surface) [*c]SDL_Palette;
    // pub extern fn SDL_AddSurfaceAlternateImage(surface: [*c]SDL_Surface, image: [*c]SDL_Surface) bool;
    // pub extern fn SDL_SurfaceHasAlternateImages(surface: [*c]SDL_Surface) bool;
    // pub extern fn SDL_GetSurfaceImages(surface: [*c]SDL_Surface, count: [*c]c_int) [*c][*c]SDL_Surface;
    // pub extern fn SDL_RemoveSurfaceAlternateImages(surface: [*c]SDL_Surface) void;
    // pub extern fn SDL_LockSurface(surface: [*c]SDL_Surface) bool;
    // pub extern fn SDL_UnlockSurface(surface: [*c]SDL_Surface) void;
    // pub extern fn SDL_LoadBMP_IO(src: ?*SDL_IOStream, closeio: bool) [*c]SDL_Surface;
    // pub extern fn SDL_LoadBMP(file: [*c]const u8) [*c]SDL_Surface;
    // pub extern fn SDL_SaveBMP_IO(surface: [*c]SDL_Surface, dst: ?*SDL_IOStream, closeio: bool) bool;
    // pub extern fn SDL_SaveBMP(surface: [*c]SDL_Surface, file: [*c]const u8) bool;
    // pub extern fn SDL_SetSurfaceRLE(surface: [*c]SDL_Surface, enabled: bool) bool;
    // pub extern fn SDL_SurfaceHasRLE(surface: [*c]SDL_Surface) bool;
    // pub extern fn SDL_SetSurfaceColorKey(surface: [*c]SDL_Surface, enabled: bool, key: Uint32) bool;
    // pub extern fn SDL_SurfaceHasColorKey(surface: [*c]SDL_Surface) bool;
    // pub extern fn SDL_GetSurfaceColorKey(surface: [*c]SDL_Surface, key: [*c]Uint32) bool;
    // pub extern fn SDL_SetSurfaceColorMod(surface: [*c]SDL_Surface, r: Uint8, g: Uint8, b: Uint8) bool;
    // pub extern fn SDL_GetSurfaceColorMod(surface: [*c]SDL_Surface, r: [*c]Uint8, g: [*c]Uint8, b: [*c]Uint8) bool;
    // pub extern fn SDL_SetSurfaceAlphaMod(surface: [*c]SDL_Surface, alpha: Uint8) bool;
    // pub extern fn SDL_GetSurfaceAlphaMod(surface: [*c]SDL_Surface, alpha: [*c]Uint8) bool;
    // pub extern fn SDL_SetSurfaceBlendMode(surface: [*c]SDL_Surface, blendMode: SDL_BlendMode) bool;
    // pub extern fn SDL_GetSurfaceBlendMode(surface: [*c]SDL_Surface, blendMode: [*c]SDL_BlendMode) bool;
    // pub extern fn SDL_SetSurfaceClipRect(surface: [*c]SDL_Surface, rect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_GetSurfaceClipRect(surface: [*c]SDL_Surface, rect: [*c]SDL_Rect) bool;
    // pub extern fn SDL_FlipSurface(surface: [*c]SDL_Surface, flip: SDL_FlipMode) bool;
    // pub extern fn SDL_DuplicateSurface(surface: [*c]SDL_Surface) [*c]SDL_Surface;
    // pub extern fn SDL_ScaleSurface(surface: [*c]SDL_Surface, width: c_int, height: c_int, scaleMode: SDL_ScaleMode) [*c]SDL_Surface;
    // pub extern fn SDL_ConvertSurface(surface: [*c]SDL_Surface, format: SDL_PixelFormat) [*c]SDL_Surface;
    // pub extern fn SDL_ConvertSurfaceAndColorspace(surface: [*c]SDL_Surface, format: SDL_PixelFormat, palette: [*c]SDL_Palette, colorspace: SDL_Colorspace, props: SDL_PropertiesID) [*c]SDL_Surface;
    // pub extern fn SDL_ConvertPixels(width: c_int, height: c_int, src_format: SDL_PixelFormat, src: ?*const anyopaque, src_pitch: c_int, dst_format: SDL_PixelFormat, dst: ?*anyopaque, dst_pitch: c_int) bool;
    // pub extern fn SDL_ConvertPixelsAndColorspace(width: c_int, height: c_int, src_format: SDL_PixelFormat, src_colorspace: SDL_Colorspace, src_properties: SDL_PropertiesID, src: ?*const anyopaque, src_pitch: c_int, dst_format: SDL_PixelFormat, dst_colorspace: SDL_Colorspace, dst_properties: SDL_PropertiesID, dst: ?*anyopaque, dst_pitch: c_int) bool;
    // pub extern fn SDL_PremultiplyAlpha(width: c_int, height: c_int, src_format: SDL_PixelFormat, src: ?*const anyopaque, src_pitch: c_int, dst_format: SDL_PixelFormat, dst: ?*anyopaque, dst_pitch: c_int, linear: bool) bool;
    // pub extern fn SDL_PremultiplySurfaceAlpha(surface: [*c]SDL_Surface, linear: bool) bool;
    // pub extern fn SDL_ClearSurface(surface: [*c]SDL_Surface, r: f32, g: f32, b: f32, a: f32) bool;
    // pub extern fn SDL_FillSurfaceRect(dst: [*c]SDL_Surface, rect: [*c]const SDL_Rect, color: Uint32) bool;
    // pub extern fn SDL_FillSurfaceRects(dst: [*c]SDL_Surface, rects: [*c]const SDL_Rect, count: c_int, color: Uint32) bool;
    // pub extern fn SDL_BlitSurface(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_BlitSurfaceUnchecked(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_BlitSurfaceScaled(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect, scaleMode: SDL_ScaleMode) bool;
    // pub extern fn SDL_BlitSurfaceUncheckedScaled(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect, scaleMode: SDL_ScaleMode) bool;
    // pub extern fn SDL_StretchSurface(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect, scaleMode: SDL_ScaleMode) bool;
    // pub extern fn SDL_BlitSurfaceTiled(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_BlitSurfaceTiledWithScale(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, scale: f32, scaleMode: SDL_ScaleMode, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_BlitSurface9Grid(src: [*c]SDL_Surface, srcrect: [*c]const SDL_Rect, left_width: c_int, right_width: c_int, top_height: c_int, bottom_height: c_int, scale: f32, scaleMode: SDL_ScaleMode, dst: [*c]SDL_Surface, dstrect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_MapSurfaceRGB(surface: [*c]SDL_Surface, r: Uint8, g: Uint8, b: Uint8) Uint32;
    // pub extern fn SDL_MapSurfaceRGBA(surface: [*c]SDL_Surface, r: Uint8, g: Uint8, b: Uint8, a: Uint8) Uint32;
    // pub extern fn SDL_ReadSurfacePixel(surface: [*c]SDL_Surface, x: c_int, y: c_int, r: [*c]Uint8, g: [*c]Uint8, b: [*c]Uint8, a: [*c]Uint8) bool;
    // pub extern fn SDL_ReadSurfacePixelFloat(surface: [*c]SDL_Surface, x: c_int, y: c_int, r: [*c]f32, g: [*c]f32, b: [*c]f32, a: [*c]f32) bool;
    // pub extern fn SDL_WriteSurfacePixel(surface: [*c]SDL_Surface, x: c_int, y: c_int, r: Uint8, g: Uint8, b: Uint8, a: Uint8) bool;
    // pub extern fn SDL_WriteSurfacePixelFloat(surface: [*c]SDL_Surface, x: c_int, y: c_int, r: f32, g: f32, b: f32, a: f32) bool;
};

pub const SurfaceFlags = extern struct {
    flags: FLAG_UINT = 0,

    const FLAG_UINT: type = C.SDL_SurfaceFlags;
};

pub const Renderer = opaque {
    fn to_c(self: *Renderer) *C.SDL_Renderer {
        return @ptrCast(@alignCast(self));
    }
    pub fn get_driver_count() c_int {
        return C.SDL_GetNumRenderDrivers();
    }
    pub fn get_driver_name(index: c_int) SDL3Error![*:0]const u8 {
        return ptr_cast_or_null_error(C.SDL_GetRenderDriver(index), [*:0]const u8);
    }
    pub fn create_renderer_with_properties(props_id: PropertiesID) SDL3Error!*Renderer {
        return ptr_cast_or_null_error(C.SDL_CreateRendererWithProperties(props_id), *Renderer);
    }
    pub fn create_software_renderer(surface: *Surface) SDL3Error!*Renderer {
        return ptr_cast_or_null_error(C.SDL_CreateSoftwareRenderer(@ptrCast(@alignCast(surface))), *Renderer);
    }
    pub fn get_window(self: *Renderer) SDL3Error!*Window {
        return ptr_cast_or_null_error(C.SDL_GetRenderWindow(self.to_c()), *Window);
    }
    pub fn get_name(self: *Renderer) SDL3Error![*:0]const u8 {
        return ptr_cast_or_null_error(C.SDL_GetRenderWindow(self.to_c()), [*:0]const u8);
    }
    pub fn get_properties_id(self: *Renderer) SDL3Error!PropertiesID {
        return PropertiesID{ .id = C.SDL_GetRendererProperties(self.to_c()) };
    }
    pub fn get_true_output_size(self: *Renderer) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetRenderOutputSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn get_adjusted_output_size(self: *Renderer) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetCurrentRenderOutputSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn create_texture(self: *Renderer, format: PixelFormat, access_mode: TextureAccessMode, size: IVec2) SDL3Error!*const Texture {
        return ptr_cast_or_null_error(C.SDL_CreateTexture(self.to_c(), format.to_c(), access_mode.to_c(), size.x, size.y), *const Texture);
    }
    pub fn create_texture_from_surface(self: *Renderer, surface: *Surface) SDL3Error!*const Texture {
        return ptr_cast_or_null_error(C.SDL_CreateTextureFromSurface(self.to_c(), @ptrCast(@alignCast(surface))), *const Texture);
    }
    pub fn create_texture_with_properties(self: *Renderer, props_id: PropertiesID) SDL3Error!*const Texture {
        return ptr_cast_or_null_error(C.SDL_CreateTextureWithProperties(self.to_c(), props_id.id), *const Texture);
    }
    pub fn set_texture_target(self: *Renderer, texture: *const Texture) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetRenderTarget(self.to_c(), texture.to_c()));
    }
    pub fn clear_texture_target(self: *Renderer) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetRenderTarget(self.to_c(), null));
    }
    pub fn get_texture_target(self: *Renderer) SDL3Error!*const Texture {
        return ptr_cast_or_null_error(C.SDL_GetRenderTarget(self.to_c()), *const Texture);
    }
    pub fn set_logical_presentation(self: *Renderer, presentation: LogicalPresentation) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetRenderLogicalPresentation(self.to_c(), &presentation.size.x, &presentation.size.y, presentation.mode.to_c()));
    }
    pub fn get_logical_presentation(self: *Renderer) SDL3Error!LogicalPresentation {
        var pres = LogicalPresentation{};
        try ok_or_fail_error(C.SDL_GetRenderLogicalPresentation(self.to_c(), &pres.size.x, &pres.size.y, @ptrCast(@alignCast(&pres.mode))));
        return pres;
    }
    pub fn get_logical_presentation_rect(self: *Renderer) SDL3Error!FRect2 {
        var rect = FRect2{};
        try ok_or_fail_error(C.SDL_GetRenderLogicalPresentationRect(self.to_c(), @ptrCast(@alignCast(&rect))));
        return rect;
    }
    pub fn render_coords_from_window(self: *Renderer, window_pos: FVec2) SDL3Error!FVec2 {
        var vec = FVec2{};
        try ok_or_fail_error(C.SDL_RenderCoordinatesFromWindow(self.to_c(), window_pos.x, window_pos.y, &vec.x, &vec.y));
        return vec;
    }
    pub fn render_coords_to_window(self: *Renderer, render_pos: FVec2) SDL3Error!FVec2 {
        var vec = FVec2{};
        try ok_or_fail_error(C.SDL_RenderCoordinatesToWindow(self.to_c(), render_pos.x, render_pos.y, &vec.x, &vec.y));
        return vec;
    }
    // pub extern fn SDL_ConvertEventToRenderCoordinates(renderer: ?*SDL_Renderer, event: [*c]SDL_Event) bool;
    // pub extern fn SDL_SetRenderViewport(renderer: ?*SDL_Renderer, rect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_GetRenderViewport(renderer: ?*SDL_Renderer, rect: [*c]SDL_Rect) bool;
    // pub extern fn SDL_RenderViewportSet(renderer: ?*SDL_Renderer) bool;
    // pub extern fn SDL_GetRenderSafeArea(renderer: ?*SDL_Renderer, rect: [*c]SDL_Rect) bool;
    // pub extern fn SDL_SetRenderClipRect(renderer: ?*SDL_Renderer, rect: [*c]const SDL_Rect) bool;
    // pub extern fn SDL_GetRenderClipRect(renderer: ?*SDL_Renderer, rect: [*c]SDL_Rect) bool;
    // pub extern fn SDL_RenderClipEnabled(renderer: ?*SDL_Renderer) bool;
    // pub extern fn SDL_SetRenderScale(renderer: ?*SDL_Renderer, scaleX: f32, scaleY: f32) bool;
    // pub extern fn SDL_GetRenderScale(renderer: ?*SDL_Renderer, scaleX: [*c]f32, scaleY: [*c]f32) bool;
    // pub extern fn SDL_SetRenderDrawColor(renderer: ?*SDL_Renderer, r: Uint8, g: Uint8, b: Uint8, a: Uint8) bool;
    // pub extern fn SDL_SetRenderDrawColorFloat(renderer: ?*SDL_Renderer, r: f32, g: f32, b: f32, a: f32) bool;
    // pub extern fn SDL_GetRenderDrawColor(renderer: ?*SDL_Renderer, r: [*c]Uint8, g: [*c]Uint8, b: [*c]Uint8, a: [*c]Uint8) bool;
    // pub extern fn SDL_GetRenderDrawColorFloat(renderer: ?*SDL_Renderer, r: [*c]f32, g: [*c]f32, b: [*c]f32, a: [*c]f32) bool;
    // pub extern fn SDL_SetRenderColorScale(renderer: ?*SDL_Renderer, scale: f32) bool;
    // pub extern fn SDL_GetRenderColorScale(renderer: ?*SDL_Renderer, scale: [*c]f32) bool;
    // pub extern fn SDL_SetRenderDrawBlendMode(renderer: ?*SDL_Renderer, blendMode: SDL_BlendMode) bool;
    // pub extern fn SDL_GetRenderDrawBlendMode(renderer: ?*SDL_Renderer, blendMode: [*c]SDL_BlendMode) bool;
    // pub extern fn SDL_RenderClear(renderer: ?*SDL_Renderer) bool;
    // pub extern fn SDL_RenderPoint(renderer: ?*SDL_Renderer, x: f32, y: f32) bool;
    // pub extern fn SDL_RenderPoints(renderer: ?*SDL_Renderer, points: [*c]const SDL_FPoint, count: c_int) bool;
    // pub extern fn SDL_RenderLine(renderer: ?*SDL_Renderer, x1: f32, y1: f32, x2: f32, y2: f32) bool;
    // pub extern fn SDL_RenderLines(renderer: ?*SDL_Renderer, points: [*c]const SDL_FPoint, count: c_int) bool;
    // pub extern fn SDL_RenderRect(renderer: ?*SDL_Renderer, rect: [*c]const SDL_FRect) bool;
    // pub extern fn SDL_RenderRects(renderer: ?*SDL_Renderer, rects: [*c]const SDL_FRect, count: c_int) bool;
    // pub extern fn SDL_RenderFillRect(renderer: ?*SDL_Renderer, rect: [*c]const SDL_FRect) bool;
    // pub extern fn SDL_RenderFillRects(renderer: ?*SDL_Renderer, rects: [*c]const SDL_FRect, count: c_int) bool;
    // pub extern fn SDL_RenderTexture(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, srcrect: [*c]const SDL_FRect, dstrect: [*c]const SDL_FRect) bool;
    // pub extern fn SDL_RenderTextureRotated(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, srcrect: [*c]const SDL_FRect, dstrect: [*c]const SDL_FRect, angle: f64, center: [*c]const SDL_FPoint, flip: SDL_FlipMode) bool;
    // pub extern fn SDL_RenderTextureAffine(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, srcrect: [*c]const SDL_FRect, origin: [*c]const SDL_FPoint, right: [*c]const SDL_FPoint, down: [*c]const SDL_FPoint) bool;
    // pub extern fn SDL_RenderTextureTiled(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, srcrect: [*c]const SDL_FRect, scale: f32, dstrect: [*c]const SDL_FRect) bool;
    // pub extern fn SDL_RenderTexture9Grid(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, srcrect: [*c]const SDL_FRect, left_width: f32, right_width: f32, top_height: f32, bottom_height: f32, scale: f32, dstrect: [*c]const SDL_FRect) bool;
    // pub extern fn SDL_RenderGeometry(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, vertices: [*c]const SDL_Vertex, num_vertices: c_int, indices: [*c]const c_int, num_indices: c_int) bool;
    // pub extern fn SDL_RenderGeometryRaw(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture, xy: [*c]const f32, xy_stride: c_int, color: [*c]const SDL_FColor, color_stride: c_int, uv: [*c]const f32, uv_stride: c_int, num_vertices: c_int, indices: ?*const anyopaque, num_indices: c_int, size_indices: c_int) bool;
    // pub extern fn SDL_RenderReadPixels(renderer: ?*SDL_Renderer, rect: [*c]const SDL_Rect) [*c]SDL_Surface;
    // pub extern fn SDL_RenderPresent(renderer: ?*SDL_Renderer) bool;
    // pub extern fn SDL_DestroyTexture(texture: [*c]SDL_Texture) void;
    // pub extern fn SDL_DestroyRenderer(renderer: ?*SDL_Renderer) void;
    // pub extern fn SDL_FlushRenderer(renderer: ?*SDL_Renderer) bool;
    // pub extern fn SDL_GetRenderMetalLayer(renderer: ?*SDL_Renderer) ?*anyopaque;
    // pub extern fn SDL_GetRenderMetalCommandEncoder(renderer: ?*SDL_Renderer) ?*anyopaque;
    // pub extern fn SDL_AddVulkanRenderSemaphores(renderer: ?*SDL_Renderer, wait_stage_mask: Uint32, wait_semaphore: Sint64, signal_semaphore: Sint64) bool;
    // pub extern fn SDL_SetRenderVSync(renderer: ?*SDL_Renderer, vsync: c_int) bool;
    // pub extern fn SDL_GetRenderVSync(renderer: ?*SDL_Renderer, vsync: [*c]c_int) bool;
    // pub extern fn SDL_RenderDebugText(renderer: ?*SDL_Renderer, x: f32, y: f32, str: [*c]const u8) bool;
    // pub extern fn SDL_RenderDebugTextFormat(renderer: ?*SDL_Renderer, x: f32, y: f32, fmt: [*c]const u8, ...) bool;
};

pub const Texture = extern struct {
    format: PixelFormat = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    refcount: c_int = 0,

    fn to_c(self: *const Texture) *const C.SDL_Texture {
        return @ptrCast(@alignCast(self));
    }

    pub fn get_properties(self: *const Texture) PropertiesID {
        return C.SDL_GetTextureProperties(self.to_c());
    }
    pub fn get_renderer(self: *const Texture) SDL3Error!*Renderer {
        return ptr_cast_or_null_error(C.SDL_GetTextureProperties(self.to_c()), *Renderer);
    }
    pub fn get_size(self: *const Texture) SDL3Error!IVec2 {
        var size = IVec2{};
        try ok_or_fail_error(C.SDL_GetTextureSize(self.to_c(), &size.x, &size.y));
        return size;
    }
    pub fn set_color_mod(self: *const Texture, color: IColor_RGB) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureColorMod(self.to_c(), color.r, color.g, color.b));
    }
    pub fn set_color_mod_float(self: *const Texture, color: FColor_RGB) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureColorModFloat(self.to_c(), color.r, color.g, color.b));
    }
    pub fn get_color_mod(self: *const Texture) SDL3Error!IColor_RGB {
        var color = IColor_RGB{};
        try ok_or_fail_error(C.SDL_GetTextureColorMod(self.to_c(), &color.r, &color.g, &color.b));
        return color;
    }
    pub fn get_color_mod_float(self: *const Texture) SDL3Error!FColor_RGB {
        var color = FColor_RGB{};
        try ok_or_fail_error(C.SDL_GetTextureColorModFloat(self.to_c(), &color.r, &color.g, &color.b));
        return color;
    }
    pub fn set_alpha_mod(self: *const Texture, alpha: u8) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureAlphaMod(self.to_c(), alpha));
    }
    pub fn set_alpha_mod_float(self: *const Texture, alpha: f32) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureAlphaModFloat(self.to_c(), alpha));
    }
    pub fn get_alpha_mod(self: *const Texture) SDL3Error!u8 {
        var alpha: u8 = 0;
        try ok_or_fail_error(C.SDL_GetTextureAlphaMod(self.to_c(), &alpha));
        return alpha;
    }
    pub fn get_alpha_mod_float(self: *const Texture) SDL3Error!f32 {
        var alpha: f32 = 0.0;
        try ok_or_fail_error(C.SDL_GetTextureAlphaModFloat(self.to_c(), &alpha));
        return alpha;
    }
    pub fn set_blend_mode(self: *const Texture, blend_mode: BlendMode) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureBlendMode(self.to_c(), blend_mode.mode));
    }
    pub fn get_blend_mode(self: *const Texture) SDL3Error!BlendMode {
        var mode: u32 = 0;
        try ok_or_fail_error(C.SDL_GetTextureBlendMode(self.to_c(), &mode));
        return BlendMode{ .mode = mode };
    }
    pub fn set_scale_mode(self: *const Texture, scale_mode: ScaleMode) SDL3Error!void {
        return ok_or_fail_error(C.SDL_SetTextureScaleMode(self.to_c(), scale_mode.to_c()));
    }
    pub fn get_scale_mode(self: *const Texture) SDL3Error!ScaleMode {
        var mode: c_int = 0;
        try ok_or_fail_error(C.SDL_GetTextureScaleMode(self.to_c(), &mode));
        return ScaleMode.from_c(mode);
    }
    pub fn update_texture(self: *const Texture, raw_pixel_data: []const u8, bytes_per_row: c_int) SDL3Error!void {
        return ok_or_fail_error(C.SDL_UpdateTexture(self.to_c(), null, raw_pixel_data.ptr, bytes_per_row));
    }
    pub fn update_texture_rect(self: *const Texture, rect: IRect2, raw_pixel_data: []const u8, bytes_per_row: c_int) SDL3Error!void {
        return ok_or_fail_error(C.SDL_UpdateTexture(self.to_c(), @ptrCast(@alignCast(&rect)), raw_pixel_data.ptr, bytes_per_row));
    }
    pub fn update_YUV_texture(self: *const Texture, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) SDL3Error!void {
        return ok_or_fail_error(C.SDL_UpdateYUVTexture(self.to_c(), null, y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
    }
    pub fn update_YUV_texture_rect(self: *const Texture, rect: IRect2, y_plane_data: []const u8, bytes_per_y_row: c_int, u_plane_data: []const u8, bytes_per_u_row: c_int, v_plane_data: []const u8, bytes_per_v_row: c_int) SDL3Error!void {
        return ok_or_fail_error(C.SDL_UpdateYUVTexture(self.to_c(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, u_plane_data.ptr, bytes_per_u_row, v_plane_data.ptr, bytes_per_v_row));
    }
    pub fn update_NV_texture_rect(self: *const Texture, rect: IRect2, y_plane_data: []const u8, bytes_per_y_row: c_int, uv_plane_data: []const u8, bytes_per_uv_row: c_int) SDL3Error!void {
        return ok_or_fail_error(C.SDL_UpdateNVTexture(self.to_c(), @ptrCast(@alignCast(&rect)), y_plane_data.ptr, bytes_per_y_row, uv_plane_data.ptr, bytes_per_uv_row));
    }
    pub fn lock_for_byte_write(self: *const Texture) SDL3Error!TextureWriteBytes {
        var bytes_ptr: [*]u8 = undefined;
        var bytes_per_row: c_int = 0;
        try ok_or_fail_error(C.SDL_LockTexture(self.to_c(), null, &bytes_ptr, &bytes_per_row));
        const total_len = self.height * bytes_per_row;
        return TextureWriteBytes{
            .bytes = bytes_ptr[0..total_len],
            .bytes_per_row = bytes_per_row,
            .texture = self,
        };
    }
    pub fn lock_rect_for_byte_write(self: *const Texture, rect: IRect2) SDL3Error!TextureWriteBytes {
        var bytes_ptr: [*]u8 = undefined;
        var bytes_per_row: c_int = 0;
        try ok_or_fail_error(C.SDL_LockTexture(self.to_c(), @ptrCast(@alignCast(&rect)), &bytes_ptr, &bytes_per_row));
        const total_len = rect.y * bytes_per_row;
        return TextureWriteBytes{
            .bytes = bytes_ptr[0..total_len],
            .bytes_per_row = bytes_per_row,
            .texture = self,
        };
    }
    pub fn lock_for_surface_write(self: *const Texture) SDL3Error!TextureWriteSurface {
        var surface: *Surface = undefined;
        try ok_or_fail_error(C.SDL_LockTextureToSurface(self.to_c(), null, @ptrCast(@alignCast(&surface))));
        return TextureWriteSurface{
            .surface = surface,
            .texture = self,
        };
    }
    pub fn lock_rect_for_surface_write(self: *const Texture, rect: IRect2) SDL3Error!TextureWriteSurface {
        var surface: *Surface = undefined;
        try ok_or_fail_error(C.SDL_LockTextureToSurface(self.to_c(), @ptrCast(@alignCast(&rect)), @ptrCast(@alignCast(&surface))));
        return TextureWriteSurface{
            .surface = surface,
            .texture = self,
        };
    }
};

pub const TextureWriteBytes = extern struct {
    bytes: []u8,
    bytes_per_row: c_int,
    texture: ?*const Texture,

    pub fn unlock(self: *TextureWriteBytes) void {
        assert(self.texture != null);
        C.SDL_UnlockTexture(self.texture.?);
        self.bytes = &.{};
        self.bytes_per_row = 0;
        self.texture = null;
    }
};

pub const TextureWriteSurface = extern struct {
    surface: *Surface,
    texture: ?*const Texture,

    pub fn unlock(self: *TextureWriteSurface) void {
        assert(self.texture != null);
        C.SDL_UnlockTexture(self.texture.?);
        self.surface = &Surface{};
        self.texture = null;
    }
};

pub const LogicalPresentationMode = enum(c_uint) {
    DISABLED = C.SDL_LOGICAL_PRESENTATION_DISABLED,
    STRETCH = C.SDL_LOGICAL_PRESENTATION_STRETCH,
    LETTERBOX = C.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    OVERSCAN = C.SDL_LOGICAL_PRESENTATION_OVERSCAN,
    INTEGER_SCALE = C.SDL_LOGICAL_PRESENTATION_INTEGER_SCALE,

    pub fn to_c(self: LogicalPresentationMode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) LogicalPresentationMode {
        return @enumFromInt(val);
    }
};

pub const LogicalPresentation = extern struct {
    size: IVec2 = IVec2{},
    mode: LogicalPresentationMode = .DISABLED,

    pub fn new(mode: LogicalPresentationMode, size: IVec2) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = size,
        };
    }
    pub fn new_xy(mode: LogicalPresentationMode, x: c_int, y: c_int) LogicalPresentation {
        return LogicalPresentation{
            .mode = mode,
            .size = IVec2.new(x, y),
        };
    }
};

pub const BlendMode = struct {
    mode: u32 = 0,

    pub fn create(src_color_factor: BlendFactor, dst_color_factor: BlendFactor, color_operation: BlendOperation, src_alpha_factor: BlendFactor, dst_alpha_factor: BlendFactor, alpha_operation: BlendOperation) BlendMode {
        return BlendMode{ .mode = C.SDL_ComposeCustomBlendMode(src_color_factor.to_c(), dst_color_factor.to_c(), color_operation.to_c(), src_alpha_factor.to_c(), dst_alpha_factor.to_c(), alpha_operation.to_c()) };
    }
};

pub const ScaleMode = enum(c_int) {
    INVALID = C.SDL_SCALEMODE_INVALID,
    NEAREST = C.SDL_SCALEMODE_NEAREST,
    LINEAR = C.SDL_SCALEMODE_LINEAR,

    pub fn to_c(self: ScaleMode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) ScaleMode {
        return @enumFromInt(val);
    }
};

pub const TextureAccessMode = enum(c_uint) {
    STATIC = C.SDL_TEXTUREACCESS_STATIC,
    STREAMING = C.SDL_TEXTUREACCESS_STREAMING,
    TARGET = C.SDL_TEXTUREACCESS_TARGET,

    pub fn to_c(self: TextureAccessMode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) TextureAccessMode {
        return @enumFromInt(val);
    }
};

pub const AudioSpec = extern struct {
    format: AudioFormat = .UNKNOWN,
    channels: c_int = 0,
    freq: c_int = 0,
};

pub const AudioDeviceID = extern struct {
    id: u32 = 0,

    // pub extern fn SDL_GetAudioPlaybackDevices(count: [*c]c_int) [*c]SDL_AudioDeviceID;
    // pub extern fn SDL_GetAudioRecordingDevices(count: [*c]c_int) [*c]SDL_AudioDeviceID;
    // pub extern fn SDL_GetAudioDeviceName(devid: SDL_AudioDeviceID) [*c]const u8;
    // pub extern fn SDL_GetAudioDeviceFormat(devid: SDL_AudioDeviceID, spec: [*c]SDL_AudioSpec, sample_frames: [*c]c_int) bool;
    // pub extern fn SDL_GetAudioDeviceChannelMap(devid: SDL_AudioDeviceID, count: [*c]c_int) [*c]c_int;
    // pub extern fn SDL_OpenAudioDevice(devid: SDL_AudioDeviceID, spec: [*c]const SDL_AudioSpec) SDL_AudioDeviceID;
    // pub extern fn SDL_IsAudioDevicePhysical(devid: SDL_AudioDeviceID) bool;
    // pub extern fn SDL_IsAudioDevicePlayback(devid: SDL_AudioDeviceID) bool;
    // pub extern fn SDL_PauseAudioDevice(devid: SDL_AudioDeviceID) bool;
    // pub extern fn SDL_ResumeAudioDevice(devid: SDL_AudioDeviceID) bool;
    // pub extern fn SDL_AudioDevicePaused(devid: SDL_AudioDeviceID) bool;
    // pub extern fn SDL_GetAudioDeviceGain(devid: SDL_AudioDeviceID) f32;
    // pub extern fn SDL_SetAudioDeviceGain(devid: SDL_AudioDeviceID, gain: f32) bool;
    // pub extern fn SDL_CloseAudioDevice(devid: SDL_AudioDeviceID) void;
    // pub extern fn SDL_BindAudioStreams(devid: SDL_AudioDeviceID, streams: [*c]const ?*SDL_AudioStream, num_streams: c_int) bool;
    // pub extern fn SDL_BindAudioStream(devid: SDL_AudioDeviceID, stream: ?*SDL_AudioStream) bool;
};

pub const AudioStream = extern struct {
    extern_ptr: *External,

    const External = C.SDL_AudioStream;

    // pub extern fn SDL_UnbindAudioStreams(streams: [*c]const ?*SDL_AudioStream, num_streams: c_int) void;
    // pub extern fn SDL_UnbindAudioStream(stream: ?*SDL_AudioStream) void;
    // pub extern fn SDL_GetAudioStreamDevice(stream: ?*SDL_AudioStream) SDL_AudioDeviceID;
    // pub extern fn SDL_CreateAudioStream(src_spec: [*c]const SDL_AudioSpec, dst_spec: [*c]const SDL_AudioSpec) ?*SDL_AudioStream;
    // pub extern fn SDL_GetAudioStreamProperties(stream: ?*SDL_AudioStream) SDL_PropertiesID;
    // pub extern fn SDL_GetAudioStreamFormat(stream: ?*SDL_AudioStream, src_spec: [*c]SDL_AudioSpec, dst_spec: [*c]SDL_AudioSpec) bool;
    // pub extern fn SDL_SetAudioStreamFormat(stream: ?*SDL_AudioStream, src_spec: [*c]const SDL_AudioSpec, dst_spec: [*c]const SDL_AudioSpec) bool;
    // pub extern fn SDL_GetAudioStreamFrequencyRatio(stream: ?*SDL_AudioStream) f32;
    // pub extern fn SDL_SetAudioStreamFrequencyRatio(stream: ?*SDL_AudioStream, ratio: f32) bool;
    // pub extern fn SDL_GetAudioStreamGain(stream: ?*SDL_AudioStream) f32;
    // pub extern fn SDL_SetAudioStreamGain(stream: ?*SDL_AudioStream, gain: f32) bool;
    // pub extern fn SDL_GetAudioStreamInputChannelMap(stream: ?*SDL_AudioStream, count: [*c]c_int) [*c]c_int;
    // pub extern fn SDL_GetAudioStreamOutputChannelMap(stream: ?*SDL_AudioStream, count: [*c]c_int) [*c]c_int;
    // pub extern fn SDL_SetAudioStreamInputChannelMap(stream: ?*SDL_AudioStream, chmap: [*c]const c_int, count: c_int) bool;
    // pub extern fn SDL_SetAudioStreamOutputChannelMap(stream: ?*SDL_AudioStream, chmap: [*c]const c_int, count: c_int) bool;
    // pub extern fn SDL_PutAudioStreamData(stream: ?*SDL_AudioStream, buf: ?*const anyopaque, len: c_int) bool;
    // pub extern fn SDL_GetAudioStreamData(stream: ?*SDL_AudioStream, buf: ?*anyopaque, len: c_int) c_int;
    // pub extern fn SDL_GetAudioStreamAvailable(stream: ?*SDL_AudioStream) c_int;
    // pub extern fn SDL_GetAudioStreamQueued(stream: ?*SDL_AudioStream) c_int;
    // pub extern fn SDL_FlushAudioStream(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_ClearAudioStream(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_PauseAudioStreamDevice(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_ResumeAudioStreamDevice(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_AudioStreamDevicePaused(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_LockAudioStream(stream: ?*SDL_AudioStream) bool;
    // pub extern fn SDL_UnlockAudioStream(stream: ?*SDL_AudioStream) bool;
    // pub const SDL_AudioStreamCallback = ?*const fn (?*anyopaque, ?*SDL_AudioStream, c_int, c_int) callconv(.c) void;
    // pub extern fn SDL_SetAudioStreamGetCallback(stream: ?*SDL_AudioStream, callback: SDL_AudioStreamCallback, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_SetAudioStreamPutCallback(stream: ?*SDL_AudioStream, callback: SDL_AudioStreamCallback, userdata: ?*anyopaque) bool;
    // pub extern fn SDL_DestroyAudioStream(stream: ?*SDL_AudioStream) void;
    // pub extern fn SDL_OpenAudioDeviceStream(devid: SDL_AudioDeviceID, spec: [*c]const SDL_AudioSpec, callback: SDL_AudioStreamCallback, userdata: ?*anyopaque) ?*SDL_AudioStream;
};

pub const Gamepad = extern struct {
    extern_ptr: *External,

    pub const External = C.SDL_Gamepad;
};

pub const GamepadType = enum(c_uint) {
    UNKNOWN = C.SDL_GAMEPAD_TYPE_UNKNOWN,
    STANDARD = C.SDL_GAMEPAD_TYPE_STANDARD,
    XBOX360 = C.SDL_GAMEPAD_TYPE_XBOX360,
    XBOXONE = C.SDL_GAMEPAD_TYPE_XBOXONE,
    PS3 = C.SDL_GAMEPAD_TYPE_PS3,
    PS4 = C.SDL_GAMEPAD_TYPE_PS4,
    PS5 = C.SDL_GAMEPAD_TYPE_PS5,
    NINTENDO_SWITCH_PRO = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO,
    NINTENDO_SWITCH_JOYCON_LEFT = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_LEFT,
    NINTENDO_SWITCH_JOYCON_RIGHT = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_RIGHT,
    NINTENDO_SWITCH_JOYCON_PAIR = C.SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR,

    pub const COUNT: c_uint = C.SDL_GAMEPAD_TYPE_COUNT;

    pub fn to_c(self: GamepadType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) GamepadType {
        return @enumFromInt(val);
    }
};

pub const GamepadButton = enum(c_int) {
    INVALID = C.SDL_GAMEPAD_BUTTON_INVALID,
    SOUTH = C.SDL_GAMEPAD_BUTTON_SOUTH,
    EAST = C.SDL_GAMEPAD_BUTTON_EAST,
    WEST = C.SDL_GAMEPAD_BUTTON_WEST,
    NORTH = C.SDL_GAMEPAD_BUTTON_NORTH,
    BACK = C.SDL_GAMEPAD_BUTTON_BACK,
    GUIDE = C.SDL_GAMEPAD_BUTTON_GUIDE,
    START = C.SDL_GAMEPAD_BUTTON_START,
    LEFT_STICK = C.SDL_GAMEPAD_BUTTON_LEFT_STICK,
    RIGHT_STICK = C.SDL_GAMEPAD_BUTTON_RIGHT_STICK,
    LEFT_SHOULDER = C.SDL_GAMEPAD_BUTTON_LEFT_SHOULDER,
    RIGHT_SHOULDER = C.SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER,
    DPAD_UP = C.SDL_GAMEPAD_BUTTON_DPAD_UP,
    DPAD_DOWN = C.SDL_GAMEPAD_BUTTON_DPAD_DOWN,
    DPAD_LEFT = C.SDL_GAMEPAD_BUTTON_DPAD_LEFT,
    DPAD_RIGHT = C.SDL_GAMEPAD_BUTTON_DPAD_RIGHT,
    MISC1 = C.SDL_GAMEPAD_BUTTON_MISC1,
    RIGHT_PADDLE1 = C.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE1,
    LEFT_PADDLE1 = C.SDL_GAMEPAD_BUTTON_LEFT_PADDLE1,
    RIGHT_PADDLE2 = C.SDL_GAMEPAD_BUTTON_RIGHT_PADDLE2,
    LEFT_PADDLE2 = C.SDL_GAMEPAD_BUTTON_LEFT_PADDLE2,
    TOUCHPAD = C.SDL_GAMEPAD_BUTTON_TOUCHPAD,
    MISC2 = C.SDL_GAMEPAD_BUTTON_MISC2,
    MISC3 = C.SDL_GAMEPAD_BUTTON_MISC3,
    MISC4 = C.SDL_GAMEPAD_BUTTON_MISC4,
    MISC5 = C.SDL_GAMEPAD_BUTTON_MISC5,
    MISC6 = C.SDL_GAMEPAD_BUTTON_MISC6,

    pub const COUNT: c_int = C.SDL_GAMEPAD_BUTTON_COUNT;

    pub fn to_c(self: GamepadButton) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) GamepadButton {
        return @enumFromInt(val);
    }
};

pub const GamepadButtonLabel = enum(c_uint) {
    UNKNOWN = C.SDL_GAMEPAD_BUTTON_LABEL_UNKNOWN,
    A = C.SDL_GAMEPAD_BUTTON_LABEL_A,
    B = C.SDL_GAMEPAD_BUTTON_LABEL_B,
    X = C.SDL_GAMEPAD_BUTTON_LABEL_X,
    Y = C.SDL_GAMEPAD_BUTTON_LABEL_Y,
    CROSS = C.SDL_GAMEPAD_BUTTON_LABEL_CROSS,
    CIRCLE = C.SDL_GAMEPAD_BUTTON_LABEL_CIRCLE,
    SQUARE = C.SDL_GAMEPAD_BUTTON_LABEL_SQUARE,
    TRIANGLE = C.SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE,

    pub fn to_c(self: GamepadButtonLabel) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) GamepadButtonLabel {
        return @enumFromInt(val);
    }
};

pub const GamepadAxis = enum(c_int) {
    INVALID = C.SDL_GAMEPAD_AXIS_INVALID,
    LEFTX = C.SDL_GAMEPAD_AXIS_LEFTX,
    LEFTY = C.SDL_GAMEPAD_AXIS_LEFTY,
    RIGHTX = C.SDL_GAMEPAD_AXIS_RIGHTX,
    RIGHTY = C.SDL_GAMEPAD_AXIS_RIGHTY,
    LEFT_TRIGGER = C.SDL_GAMEPAD_AXIS_LEFT_TRIGGER,
    RIGHT_TRIGGER = C.SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,

    pub const COUNT: c_int = C.SDL_GAMEPAD_AXIS_COUNT;

    pub fn to_c(self: GamepadAxis) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) GamepadAxis {
        return @enumFromInt(val);
    }
};

pub const GamepadBindingType = enum(c_uint) {
    NONE = C.SDL_GAMEPAD_BINDTYPE_NONE,
    BUTTON = C.SDL_GAMEPAD_BINDTYPE_BUTTON,
    AXIS = C.SDL_GAMEPAD_BINDTYPE_AXIS,
    HAT = C.SDL_GAMEPAD_BINDTYPE_HAT,

    pub fn to_c(self: GamepadBindingType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) GamepadBindingType {
        return @enumFromInt(val);
    }
};

pub const StorageInterface = extern struct {
    version: C.Uint32 = @sizeOf(*StorageInterface),
    close: ?*const fn (?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) bool),
    ready: ?*const fn (?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) bool),
    enumerate: ?*const fn (?*anyopaque, [*c]const u8, C.SDL_EnumerateDirectoryCallback, ?*anyopaque) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, C.SDL_EnumerateDirectoryCallback, ?*anyopaque) callconv(.c) bool),
    info: ?*const fn (?*anyopaque, [*c]const u8, [*c]C.SDL_PathInfo) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]C.SDL_PathInfo) callconv(.c) bool),
    read_file: ?*const fn (?*anyopaque, [*c]const u8, ?*anyopaque, C.Uint64) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, ?*anyopaque, C.Uint64) callconv(.c) bool),
    write_file: ?*const fn (?*anyopaque, [*c]const u8, ?*const anyopaque, C.Uint64) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, ?*const anyopaque, C.Uint64) callconv(.c) bool),
    mkdir: ?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool),
    remove: ?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8) callconv(.c) bool),
    rename: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool),
    copy: ?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool = @import("std").mem.zeroes(?*const fn (?*anyopaque, [*c]const u8, [*c]const u8) callconv(.c) bool),
    space_remaining: ?*const fn (?*anyopaque) callconv(.c) C.Uint64 = @import("std").mem.zeroes(?*const fn (?*anyopaque) callconv(.c) C.Uint64),
};

pub const Storage = extern struct {
    extern_ptr: *External,
    is_open: bool = false,

    pub const External = C.SDL_Storage;
    pub fn open_app_readonly_storage_folder(override: [:0]const u8, properties: PropertiesID) SDL3Error!Storage {
        return Storage{ .is_open = true, .extern_ptr = try ptr_cast_or_null_error(C.SDL_OpenTitleStorage(override.ptr, properties), *Storage.External) };
    }
    pub fn open_user_storage_folder(org_name: [:0]const u8, app_name: [:0]const u8, properties: PropertiesID) SDL3Error!Storage {
        return Storage{ .is_open = true, .extern_ptr = try ptr_cast_or_null_error(C.SDL_OpenUserStorage(org_name.ptr, app_name.ptr, properties), *Storage.External) };
    }
    pub fn open_filesystem(path: [:0]const u8) SDL3Error!Storage {
        return Storage{ .is_open = true, .extern_ptr = try ptr_cast_or_null_error(C.SDL_OpenFileStorage(path.ptr), *Storage.External) };
    }
    pub fn open_storage_with_custom_interface(iface: StorageInterface, user_data: ?*anyopaque) SDL3Error!Storage {
        return Storage{ .is_open = true, .extern_ptr = try ptr_cast_or_null_error(C.SDL_OpenStorage(@ptrCast(@alignCast(&iface)), user_data), *Storage.External) };
    }
    pub fn close(self: Storage) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_CloseStorage(self.extern_ptr));
        self.is_open = false;
    }
    pub fn is_ready(self: Storage) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_StorageReady(self.extern_ptr));
    }
    pub fn get_file_size(self: Storage, sub_path: [:0]const u8) SDL3Error!u64 {
        assert(self.is_open);
        var size: u64 = 0;
        try ok_or_fail_error(C.SDL_GetStorageFileSize(self.extern_ptr, sub_path.ptr, &size));
        return size;
    }
    pub fn read_file_into_buffer(self: Storage, sub_path: [:0]const u8, buffer: []u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_ReadStorageFile(self.extern_ptr, sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn write_file_from_buffer(self: Storage, sub_path: [:0]const u8, buffer: []const u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_WriteStorageFile(self.extern_ptr, sub_path.ptr, buffer.ptr, @intCast(buffer.len)));
    }
    pub fn create_directory(self: Storage, sub_path: [:0]const u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_CreateStorageDirectory(self.extern_ptr, sub_path.ptr));
    }
    pub fn do_callback_for_each_directory_entry(self: Storage, sub_path: [:0]const u8, callback: FolderEntryCallback, callback_data: ?*anyopaque) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_EnumerateStorageDirectory(self.extern_ptr, sub_path.ptr, @ptrCast(@alignCast(callback)), callback_data));
    }
    pub fn delete_file_or_empty_directory(self: Storage, sub_path: [:0]const u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_RemoveStoragePath(self.extern_ptr, sub_path.ptr));
    }
    pub fn rename_file_or_directory(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_RenameStoragePath(self.extern_ptr, old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn copy_file(self: Storage, old_sub_path: [:0]const u8, new_sub_path: [:0]const u8) SDL3Error!void {
        assert(self.is_open);
        try ok_or_fail_error(C.SDL_CopyStorageFile(self.extern_ptr, old_sub_path.ptr, new_sub_path.ptr));
    }
    pub fn get_path_info(self: Storage, sub_path: [:0]const u8) SDL3Error!PathInfo {
        var info = PathInfo{};
        try ok_or_fail_error(C.SDL_GetStoragePathInfo(self.extern_ptr, sub_path.ptr, @ptrCast(@alignCast(&info))));
        return info;
    }
    pub fn get_remaining_storage_space(self: Storage) SDL3Error!u64 {
        return @intCast(C.SDL_GetStorageSpaceRemaining(self.extern_ptr));
    }
    pub fn get_directory_glob(self: Storage, sub_path: [:0]const u8, pattern: [:0]const u8, case_insensitive: bool) SDL3Error!DirectoryGlob {
        var len: c_int = 0;
        const ptr = try ptr_cast_or_null_error(C.SDL_GlobStorageDirectory(self.extern_ptr, sub_path.ptr, pattern.ptr, @intCast(@intFromBool(case_insensitive)), &len), [*]const [*:0]const u8);
        return DirectoryGlob{
            .strings = ptr[0..len],
        };
    }
};

pub const FolderEntryCallback = ?*const fn (callback_data: ?*anyopaque, folder_name: [*:0]const u8, entry_name: [*:0]const u8) callconv(.c) EnumerationResult;

pub const EnumerationResult = enum(c_uint) {
    CONTINUE = C.SDL_ENUM_CONTINUE,
    SUCCESS = C.SDL_ENUM_SUCCESS,
    FAILURE = C.SDL_ENUM_FAILURE,

    pub fn to_c(self: EnumerationResult) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) EnumerationResult {
        return @enumFromInt(val);
    }
};

pub const PathInfo = extern struct {
    type: PathType = .NONE,
    size: u64 = 0,
    create_time: Time = Time{},
    modify_time: Time = Time{},
    access_time: Time = Time{},
};

pub const PathType = enum(c_uint) {
    NONE = C.SDL_PATHTYPE_NONE,
    FILE = C.SDL_PATHTYPE_FILE,
    DIRECTORY = C.SDL_PATHTYPE_DIRECTORY,
    OTHER = C.SDL_PATHTYPE_OTHER,

    pub fn to_c(self: PathType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PathType {
        return @enumFromInt(val);
    }
};

pub const Time = extern struct {
    ns: i64 = 0,
};

pub const DirectoryGlob = extern struct {
    strings: []const [*:0]const u8,

    pub fn get_string(self: DirectoryGlob, index: usize) []const u8 {
        assert(index < self.strings.len);
        return Root.Utils.make_const_slice_from_sentinel_ptr(u8, 0, self.strings[index]);
    }

    pub fn free(self: DirectoryGlob) void {
        sdl_free(self.strings.ptr);
        self.strings = &.{};
    }
};

pub const KeyboardID = extern struct {
    id: u32,
};

pub const Event = extern union {
    type: EventType,
    common: CommonEvent,
    display: DisplayEvent,
    window: WindowEvent,
    keyboard_device: KeyboardDeviceEvent,
    keyboard: KeyboardEvent,
    text_edit: TextEditEvent,
    text_edit_candidate: TextEditCandidateEvent,
    text_input: TextInputEvent,
    mouse_device: MouseDeviceEvent,
    mouse_motion: MouseMotionEvent,
    mouse_button: MouseButtonEvent,
    mouse_wheel: MouseWheelEvent,
    joy_device: JoyDeviceEvent,
    joy_axis: JoyAxisEvent,
    joy_ball: JoyBallEvent,
    joy_hat: JoyHatEvent,
    joy_button: JoyButtonEvent,
    joy_battery: JoyBatteryEvent,
    gamepad_device: GamepadDeviceEvent,
    gamepad_axis: GamepadAxisEvent,
    gamepad_button: GamepadButtonEvent,
    gamepad_touchpad: GamepadTouchpadEvent,
    gamepad_sensor: GamepadSensorEvent,
    audio_device: AudioDeviceEvent,
    camera_device: CameraDeviceEvent,
    sensor: SensorEvent,
    quit: QuitEvent,
    user: UserEvent,
    touch_finger: TouchFingerEvent,
    pen_proximity: PenProximityEvent,
    pen_touch: PenTouchEvent,
    pen_motion: PenMotionEvent,
    pen_button: PenButtonEvent,
    pen_axis: PenAxisEvent,
    render: RenderEvent,
    drop: DropEvent,
    clipboard: ClipboardEvent,
    _FORCE_SIZE: [128]u8,
};

pub const CommonEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    fn to_c(self: *CommonEvent) *C.SDL_CommonEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const DisplayEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    display_id: DisplayID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    fn to_c(self: *DisplayEvent) *C.SDL_DisplayEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const WindowEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    data_1: i32 = 0,
    data_2: i32 = 0,

    fn to_c(self: *WindowEvent) *C.SDL_WindowEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const KeyboardDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    keyboard_id: KeyboardID = .{},

    fn to_c(self: *KeyboardDeviceEvent) *C.SDL_KeyboardDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const KeyboardEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    keyboard_id: KeyboardID = .{},
    scancode: Scancode = .UNKNOWN,
    key: Keycode = .{},
    mod: Keymod = .{},
    raw: u16 = 0,
    down: bool = false,
    repeat: bool = false,

    fn to_c(self: *KeyboardEvent) *C.SDL_KeyboardEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const TextEditEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: [*:0]const u8 = "",
    start: i32 = 0,
    length: i32 = 0,

    fn to_c(self: *TextEditEvent) *C.SDL_TextEditingEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const TextEditCandidateEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    candidates: ?[*]const [*:0]const u8 = null,
    candidates_len: i32 = 0,
    selected_candidate: i32 = 0,
    horizontal: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,

    fn to_c(self: *TextEditCandidateEvent) *C.SDL_TextEditingCandidatesEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const TextInputEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    text: ?[*:0]const u8 = null,

    fn to_c(self: *TextInputEvent) *C.SDL_TextInputEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const MouseDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    mouse_id: MouseID = .{},

    fn to_c(self: *MouseDeviceEvent) *C.SDL_MouseDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const MouseMotionEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    state: MouseButtonFlags = .{},
    pos: FVec2 = FVec2{},
    rel_pos: FVec2 = FVec2{},

    fn to_c(self: *MouseMotionEvent) *C.SDL_MouseMotionEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const MouseButtonEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    button: u8 = 0,
    down: bool = false,
    clicks: u8 = 0,
    _padding: u8 = 0,
    pos: FVec2 = FVec2{},

    fn to_c(self: *MouseButtonEvent) *C.SDL_MouseButtonEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const MouseWheelEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    mouse_id: MouseID = .{},
    delta: FVec2 = FVec2{},
    direction: MouseWheelDirection = .NORMAL,
    window_pos: FVec2 = FVec2{},

    fn to_c(self: *MouseWheelEvent) *C.SDL_MouseWheelEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyAxisEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    axis: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    fn to_c(self: *JoyAxisEvent) *C.SDL_JoyAxisEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyBallEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    ball: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    delta: IVec2_16 = IVec2_16{},

    fn to_c(self: *JoyBallEvent) *C.SDL_JoyBallEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyHatEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    hat: u8 = 0,
    value: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    fn to_c(self: *JoyHatEvent) *C.SDL_JoyHatEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyButtonEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    button: u8 = 0,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    fn to_c(self: *JoyButtonEvent) *C.SDL_JoyButtonEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},

    fn to_c(self: *JoyDeviceEvent) *C.SDL_JoyDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const JoyBatteryEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    state: PowerState = .UNKNOWN,
    percent: c_int = 0,

    fn to_c(self: *JoyBatteryEvent) *C.SDL_JoyBatteryEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const GamepadAxisEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    axis: u8 = 0,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,
    value: i16 = 0,
    _padding_4: u16 = 0,

    fn to_c(self: *GamepadAxisEvent) *C.SDL_GamepadAxisEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const GamepadButtonEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    button: u8 = 0,
    down: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,

    fn to_c(self: *GamepadButtonEvent) *C.SDL_GamepadButtonEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const GamepadDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},

    fn to_c(self: *GamepadDeviceEvent) *C.SDL_GamepadDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const GamepadTouchpadEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    touchpad: i32 = 0,
    finger: i32 = 0,
    pos: FVec2 = FVec2{},
    pressure: f32 = 0,

    fn to_c(self: *GamepadTouchpadEvent) *C.SDL_GamepadTouchpadEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const GamepadSensorEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    joystick_id: JoystickID = .{},
    sensor: i32 = 0,
    data: [3]f32 = @splat(0.0),
    sensor_timestamp: u64 = 0,

    fn to_c(self: *GamepadSensorEvent) *C.SDL_GamepadSensorEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const AudioDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    device_id: AudioDeviceID = .{},
    recording: bool = false,
    _padding_1: u8 = 0,
    _padding_2: u8 = 0,
    _padding_3: u8 = 0,

    fn to_c(self: *AudioDeviceEvent) *C.SDL_AudioDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const CameraDeviceEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    device_id: CameraID = .{},

    fn to_c(self: *CameraDeviceEvent) *C.SDL_CameraDeviceEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const RenderEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},

    fn to_c(self: *RenderEvent) *C.SDL_RenderEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const TouchFingerEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    touch_id: TouchID = .{},
    finger_id: FingerID = .{},
    pos_normalized: FVec2 = FVec2{},
    delta_normalized: FVec2 = FVec2{},
    pressure: f32 = 0,
    window_id: WindowID = .{},

    fn to_c(self: *TouchFingerEvent) *C.SDL_TouchFingerEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const PenProximityEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},

    fn to_c(self: *PenProximityEvent) *C.SDL_PenProximityEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const PenMotionEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec2 = FVec2{},

    fn to_c(self: *PenMotionEvent) *C.SDL_PenMotionEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const PenTouchEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec2 = FVec2{},
    eraser: bool = false,
    down: bool = false,

    fn to_c(self: *PenTouchEvent) *C.SDL_PenTouchEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const PenButtonEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec2 = FVec2{},
    button: u8 = 0,
    down: bool = false,

    fn to_c(self: *PenButtonEvent) *C.SDL_PenButtonEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const PenAxisEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pen_id: PenID = .{},
    pen_state: PenInputFlags = .{},
    pos: FVec2 = FVec2{},
    axis: PenAxis = .PRESSURE,
    value: f32 = 0.0,

    fn to_c(self: *PenAxisEvent) *C.SDL_PenAxisEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const DropEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    pos: FVec2 = FVec2{},
    source: ?[*]const u8 = null,
    data: ?[*]const u8 = null,

    fn to_c(self: *DropEvent) *C.SDL_DropEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const ClipboardEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    owner: bool = false,
    num_mime_types: i32 = 0,
    mime_types: ?[*]const [*:0]const u8 = null,

    fn to_c(self: *ClipboardEvent) *C.SDL_ClipboardEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const SensorEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    sensor_id: bool = false,
    data: [6]f32 = @splat(0),
    sensor_timestamp: u64 = 0,

    fn to_c(self: *SensorEvent) *C.SDL_SensorEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const QuitEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,

    fn to_c(self: *QuitEvent) *C.SDL_QuitEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const UserEvent = extern struct {
    type: EventType = .FIRST,
    reserved: u32 = 0,
    timestamp: u64 = 0,
    window_id: WindowID = .{},
    code: i32 = 0,
    user_data_1: ?*anyopaque = null,
    user_data_2: ?*anyopaque = null,

    fn to_c(self: *UserEvent) *C.SDL_UserEvent {
        return @ptrCast(@alignCast(self));
    }
};

pub const MouseID = extern struct {
    id: u32 = 0,
};

pub const PenID = extern struct {
    id: u32 = 0,
};

pub const SensorID = extern struct {
    id: u32 = 0,
};

pub const JoystickID = extern struct {
    id: u32 = 0,
};

pub const CameraID = extern struct {
    id: u32,
};

pub const TouchID = extern struct {
    id: u64 = 0,
};

pub const FingerID = extern struct {
    id: u64 = 0,
};

pub const MouseButtonFlags = extern struct {
    flags: u32 = 0,
};

pub const PenInputFlags = extern struct {
    flags: u32 = 0,
};

pub const PenAxis = enum(c_uint) {
    PRESSURE = C.SDL_PEN_AXIS_PRESSURE,
    X_TILT = C.SDL_PEN_AXIS_XTILT,
    Y_TILT = C.SDL_PEN_AXIS_YTILT,
    DISTANCE = C.SDL_PEN_AXIS_DISTANCE,
    ROTATION = C.SDL_PEN_AXIS_ROTATION,
    SLIDER = C.SDL_PEN_AXIS_SLIDER,
    TANGENTIAL_PRESSURE = C.SDL_PEN_AXIS_TANGENTIAL_PRESSURE,

    pub const AXIS_COUNT: c_uint = C.SDL_PEN_AXIS_COUNT;

    pub fn to_c(self: PenAxis) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PenAxis {
        return @enumFromInt(val);
    }
};

pub const MouseWheelDirection = enum(c_uint) {
    NORMAL = C.SDL_MOUSEWHEEL_NORMAL,
    FLIPPED = C.SDL_MOUSEWHEEL_FLIPPED,

    pub fn to_c(self: MouseWheelDirection) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) MouseWheelDirection {
        return @enumFromInt(val);
    }
};

pub const PowerState = enum(c_int) {
    ERROR = C.SDL_POWERSTATE_ERROR,
    UNKNOWN = C.SDL_POWERSTATE_UNKNOWN,
    ON_BATTERY = C.SDL_POWERSTATE_ON_BATTERY,
    NO_BATTERY = C.SDL_POWERSTATE_NO_BATTERY,
    CHARGING = C.SDL_POWERSTATE_CHARGING,
    CHARGED = C.SDL_POWERSTATE_CHARGED,

    pub fn to_c(self: PowerState) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) PowerState {
        return @enumFromInt(val);
    }
};

pub const EventType = enum(u32) {
    FIRST = C.SDL_EVENT_FIRST,
    QUIT = C.SDL_EVENT_QUIT,
    TERMINATING = C.SDL_EVENT_TERMINATING,
    LOW_MEMORY = C.SDL_EVENT_LOW_MEMORY,
    WILL_ENTER_BACKGROUND = C.SDL_EVENT_WILL_ENTER_BACKGROUND,
    DID_ENTER_BACKGROUND = C.SDL_EVENT_DID_ENTER_BACKGROUND,
    WILL_ENTER_FOREGROUND = C.SDL_EVENT_WILL_ENTER_FOREGROUND,
    DID_ENTER_FOREGROUND = C.SDL_EVENT_DID_ENTER_FOREGROUND,
    LOCALE_CHANGED = C.SDL_EVENT_LOCALE_CHANGED,
    SYSTEM_THEME_CHANGED = C.SDL_EVENT_SYSTEM_THEME_CHANGED,
    DISPLAY_ORIENTATION = C.SDL_EVENT_DISPLAY_ORIENTATION,
    DISPLAY_ADDED = C.SDL_EVENT_DISPLAY_ADDED,
    DISPLAY_REMOVED = C.SDL_EVENT_DISPLAY_REMOVED,
    DISPLAY_MOVED = C.SDL_EVENT_DISPLAY_MOVED,
    DISPLAY_DESKTOP_MODE_CHANGED = C.SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED,
    DISPLAY_CURRENT_MODE_CHANGED = C.SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED,
    DISPLAY_CONTENT_SCALE_CHANGED = C.SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED,
    DISPLAY_FIRST = C.SDL_EVENT_DISPLAY_FIRST,
    DISPLAY_LAST = C.SDL_EVENT_DISPLAY_LAST,
    WINDOW_SHOWN = C.SDL_EVENT_WINDOW_SHOWN,
    WINDOW_HIDDEN = C.SDL_EVENT_WINDOW_HIDDEN,
    WINDOW_EXPOSED = C.SDL_EVENT_WINDOW_EXPOSED,
    WINDOW_MOVED = C.SDL_EVENT_WINDOW_MOVED,
    WINDOW_RESIZED = C.SDL_EVENT_WINDOW_RESIZED,
    WINDOW_PIXEL_SIZE_CHANGED = C.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED,
    WINDOW_METAL_VIEW_RESIZED = C.SDL_EVENT_WINDOW_METAL_VIEW_RESIZED,
    WINDOW_MINIMIZED = C.SDL_EVENT_WINDOW_MINIMIZED,
    WINDOW_MAXIMIZED = C.SDL_EVENT_WINDOW_MAXIMIZED,
    WINDOW_RESTORED = C.SDL_EVENT_WINDOW_RESTORED,
    WINDOW_MOUSE_ENTER = C.SDL_EVENT_WINDOW_MOUSE_ENTER,
    WINDOW_MOUSE_LEAVE = C.SDL_EVENT_WINDOW_MOUSE_LEAVE,
    WINDOW_FOCUS_GAINED = C.SDL_EVENT_WINDOW_FOCUS_GAINED,
    WINDOW_FOCUS_LOST = C.SDL_EVENT_WINDOW_FOCUS_LOST,
    WINDOW_CLOSE_REQUESTED = C.SDL_EVENT_WINDOW_CLOSE_REQUESTED,
    WINDOW_HIT_TEST = C.SDL_EVENT_WINDOW_HIT_TEST,
    WINDOW_ICCPROF_CHANGED = C.SDL_EVENT_WINDOW_ICCPROF_CHANGED,
    WINDOW_DISPLAY_CHANGED = C.SDL_EVENT_WINDOW_DISPLAY_CHANGED,
    WINDOW_DISPLAY_SCALE_CHANGED = C.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED,
    WINDOW_SAFE_AREA_CHANGED = C.SDL_EVENT_WINDOW_SAFE_AREA_CHANGED,
    WINDOW_OCCLUDED = C.SDL_EVENT_WINDOW_OCCLUDED,
    WINDOW_ENTER_FULLSCREEN = C.SDL_EVENT_WINDOW_ENTER_FULLSCREEN,
    WINDOW_LEAVE_FULLSCREEN = C.SDL_EVENT_WINDOW_LEAVE_FULLSCREEN,
    WINDOW_DESTROYED = C.SDL_EVENT_WINDOW_DESTROYED,
    WINDOW_HDR_STATE_CHANGED = C.SDL_EVENT_WINDOW_HDR_STATE_CHANGED,
    WINDOW_FIRST = C.SDL_EVENT_WINDOW_FIRST,
    WINDOW_LAST = C.SDL_EVENT_WINDOW_LAST,
    KEY_DOWN = C.SDL_EVENT_KEY_DOWN,
    KEY_UP = C.SDL_EVENT_KEY_UP,
    TEXT_EDITING = C.SDL_EVENT_TEXT_EDITING,
    TEXT_INPUT = C.SDL_EVENT_TEXT_INPUT,
    KEYMAP_CHANGED = C.SDL_EVENT_KEYMAP_CHANGED,
    KEYBOARD_ADDED = C.SDL_EVENT_KEYBOARD_ADDED,
    KEYBOARD_REMOVED = C.SDL_EVENT_KEYBOARD_REMOVED,
    TEXT_EDITING_CANDIDATES = C.SDL_EVENT_TEXT_EDITING_CANDIDATES,
    MOUSE_MOTION = C.SDL_EVENT_MOUSE_MOTION,
    MOUSE_BUTTON_DOWN = C.SDL_EVENT_MOUSE_BUTTON_DOWN,
    MOUSE_BUTTON_UP = C.SDL_EVENT_MOUSE_BUTTON_UP,
    MOUSE_WHEEL = C.SDL_EVENT_MOUSE_WHEEL,
    MOUSE_ADDED = C.SDL_EVENT_MOUSE_ADDED,
    MOUSE_REMOVED = C.SDL_EVENT_MOUSE_REMOVED,
    JOYSTICK_AXIS_MOTION = C.SDL_EVENT_JOYSTICK_AXIS_MOTION,
    JOYSTICK_BALL_MOTION = C.SDL_EVENT_JOYSTICK_BALL_MOTION,
    JOYSTICK_HAT_MOTION = C.SDL_EVENT_JOYSTICK_HAT_MOTION,
    JOYSTICK_BUTTON_DOWN = C.SDL_EVENT_JOYSTICK_BUTTON_DOWN,
    JOYSTICK_BUTTON_UP = C.SDL_EVENT_JOYSTICK_BUTTON_UP,
    JOYSTICK_ADDED = C.SDL_EVENT_JOYSTICK_ADDED,
    JOYSTICK_REMOVED = C.SDL_EVENT_JOYSTICK_REMOVED,
    JOYSTICK_BATTERY_UPDATED = C.SDL_EVENT_JOYSTICK_BATTERY_UPDATED,
    JOYSTICK_UPDATE_COMPLETE = C.SDL_EVENT_JOYSTICK_UPDATE_COMPLETE,
    GAMEPAD_AXIS_MOTION = C.SDL_EVENT_GAMEPAD_AXIS_MOTION,
    GAMEPAD_BUTTON_DOWN = C.SDL_EVENT_GAMEPAD_BUTTON_DOWN,
    GAMEPAD_BUTTON_UP = C.SDL_EVENT_GAMEPAD_BUTTON_UP,
    GAMEPAD_ADDED = C.SDL_EVENT_GAMEPAD_ADDED,
    GAMEPAD_REMOVED = C.SDL_EVENT_GAMEPAD_REMOVED,
    GAMEPAD_REMAPPED = C.SDL_EVENT_GAMEPAD_REMAPPED,
    GAMEPAD_TOUCHPAD_DOWN = C.SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN,
    GAMEPAD_TOUCHPAD_MOTION = C.SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION,
    GAMEPAD_TOUCHPAD_UP = C.SDL_EVENT_GAMEPAD_TOUCHPAD_UP,
    GAMEPAD_SENSOR_UPDATE = C.SDL_EVENT_GAMEPAD_SENSOR_UPDATE,
    GAMEPAD_UPDATE_COMPLETE = C.SDL_EVENT_GAMEPAD_UPDATE_COMPLETE,
    GAMEPAD_STEAM_HANDLE_UPDATED = C.SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED,
    FINGER_DOWN = C.SDL_EVENT_FINGER_DOWN,
    FINGER_UP = C.SDL_EVENT_FINGER_UP,
    FINGER_MOTION = C.SDL_EVENT_FINGER_MOTION,
    FINGER_CANCELED = C.SDL_EVENT_FINGER_CANCELED,
    CLIPBOARD_UPDATE = C.SDL_EVENT_CLIPBOARD_UPDATE,
    DROP_FILE = C.SDL_EVENT_DROP_FILE,
    DROP_TEXT = C.SDL_EVENT_DROP_TEXT,
    DROP_BEGIN = C.SDL_EVENT_DROP_BEGIN,
    DROP_COMPLETE = C.SDL_EVENT_DROP_COMPLETE,
    DROP_POSITION = C.SDL_EVENT_DROP_POSITION,
    AUDIO_DEVICE_ADDED = C.SDL_EVENT_AUDIO_DEVICE_ADDED,
    AUDIO_DEVICE_REMOVED = C.SDL_EVENT_AUDIO_DEVICE_REMOVED,
    AUDIO_DEVICE_FORMAT_CHANGED = C.SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED,
    SENSOR_UPDATE = C.SDL_EVENT_SENSOR_UPDATE,
    PEN_PROXIMITY_IN = C.SDL_EVENT_PEN_PROXIMITY_IN,
    PEN_PROXIMITY_OUT = C.SDL_EVENT_PEN_PROXIMITY_OUT,
    PEN_DOWN = C.SDL_EVENT_PEN_DOWN,
    PEN_UP = C.SDL_EVENT_PEN_UP,
    PEN_BUTTON_DOWN = C.SDL_EVENT_PEN_BUTTON_DOWN,
    PEN_BUTTON_UP = C.SDL_EVENT_PEN_BUTTON_UP,
    PEN_MOTION = C.SDL_EVENT_PEN_MOTION,
    PEN_AXIS = C.SDL_EVENT_PEN_AXIS,
    CAMERA_DEVICE_ADDED = C.SDL_EVENT_CAMERA_DEVICE_ADDED,
    CAMERA_DEVICE_REMOVED = C.SDL_EVENT_CAMERA_DEVICE_REMOVED,
    CAMERA_DEVICE_APPROVED = C.SDL_EVENT_CAMERA_DEVICE_APPROVED,
    CAMERA_DEVICE_DENIED = C.SDL_EVENT_CAMERA_DEVICE_DENIED,
    RENDER_TARGETS_RESET = C.SDL_EVENT_RENDER_TARGETS_RESET,
    RENDER_DEVICE_RESET = C.SDL_EVENT_RENDER_DEVICE_RESET,
    RENDER_DEVICE_LOST = C.SDL_EVENT_RENDER_DEVICE_LOST,
    PRIVATE0 = C.SDL_EVENT_PRIVATE0,
    PRIVATE1 = C.SDL_EVENT_PRIVATE1,
    PRIVATE2 = C.SDL_EVENT_PRIVATE2,
    PRIVATE3 = C.SDL_EVENT_PRIVATE3,
    POLL_SENTINEL = C.SDL_EVENT_POLL_SENTINEL,
    USER = C.SDL_EVENT_USER,
    LAST = C.SDL_EVENT_LAST,

    const ENUM_PADDING = C.SDL_EVENT_ENUM_PADDING;

    pub fn to_c(self: EventType) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) EventType {
        return @enumFromInt(val);
    }
};

pub const Scancode = enum(c_uint) {
    UNKNOWN = C.SDL_SCANCODE_UNKNOWN,
    //FIXME
    // pub const SDL_SCANCODE_A: c_int = 4;
    // pub const SDL_SCANCODE_B: c_int = 5;
    // pub const SDL_SCANCODE_C: c_int = 6;
    // pub const SDL_SCANCODE_D: c_int = 7;
    // pub const SDL_SCANCODE_E: c_int = 8;
    // pub const SDL_SCANCODE_F: c_int = 9;
    // pub const SDL_SCANCODE_G: c_int = 10;
    // pub const SDL_SCANCODE_H: c_int = 11;
    // pub const SDL_SCANCODE_I: c_int = 12;
    // pub const SDL_SCANCODE_J: c_int = 13;
    // pub const SDL_SCANCODE_K: c_int = 14;
    // pub const SDL_SCANCODE_L: c_int = 15;
    // pub const SDL_SCANCODE_M: c_int = 16;
    // pub const SDL_SCANCODE_N: c_int = 17;
    // pub const SDL_SCANCODE_O: c_int = 18;
    // pub const SDL_SCANCODE_P: c_int = 19;
    // pub const SDL_SCANCODE_Q: c_int = 20;
    // pub const SDL_SCANCODE_R: c_int = 21;
    // pub const SDL_SCANCODE_S: c_int = 22;
    // pub const SDL_SCANCODE_T: c_int = 23;
    // pub const SDL_SCANCODE_U: c_int = 24;
    // pub const SDL_SCANCODE_V: c_int = 25;
    // pub const SDL_SCANCODE_W: c_int = 26;
    // pub const SDL_SCANCODE_X: c_int = 27;
    // pub const SDL_SCANCODE_Y: c_int = 28;
    // pub const SDL_SCANCODE_Z: c_int = 29;
    // pub const SDL_SCANCODE_1: c_int = 30;
    // pub const SDL_SCANCODE_2: c_int = 31;
    // pub const SDL_SCANCODE_3: c_int = 32;
    // pub const SDL_SCANCODE_4: c_int = 33;
    // pub const SDL_SCANCODE_5: c_int = 34;
    // pub const SDL_SCANCODE_6: c_int = 35;
    // pub const SDL_SCANCODE_7: c_int = 36;
    // pub const SDL_SCANCODE_8: c_int = 37;
    // pub const SDL_SCANCODE_9: c_int = 38;
    // pub const SDL_SCANCODE_0: c_int = 39;
    // pub const SDL_SCANCODE_RETURN: c_int = 40;
    // pub const SDL_SCANCODE_ESCAPE: c_int = 41;
    // pub const SDL_SCANCODE_BACKSPACE: c_int = 42;
    // pub const SDL_SCANCODE_TAB: c_int = 43;
    // pub const SDL_SCANCODE_SPACE: c_int = 44;
    // pub const SDL_SCANCODE_MINUS: c_int = 45;
    // pub const SDL_SCANCODE_EQUALS: c_int = 46;
    // pub const SDL_SCANCODE_LEFTBRACKET: c_int = 47;
    // pub const SDL_SCANCODE_RIGHTBRACKET: c_int = 48;
    // pub const SDL_SCANCODE_BACKSLASH: c_int = 49;
    // pub const SDL_SCANCODE_NONUSHASH: c_int = 50;
    // pub const SDL_SCANCODE_SEMICOLON: c_int = 51;
    // pub const SDL_SCANCODE_APOSTROPHE: c_int = 52;
    // pub const SDL_SCANCODE_GRAVE: c_int = 53;
    // pub const SDL_SCANCODE_COMMA: c_int = 54;
    // pub const SDL_SCANCODE_PERIOD: c_int = 55;
    // pub const SDL_SCANCODE_SLASH: c_int = 56;
    // pub const SDL_SCANCODE_CAPSLOCK: c_int = 57;
    // pub const SDL_SCANCODE_F1: c_int = 58;
    // pub const SDL_SCANCODE_F2: c_int = 59;
    // pub const SDL_SCANCODE_F3: c_int = 60;
    // pub const SDL_SCANCODE_F4: c_int = 61;
    // pub const SDL_SCANCODE_F5: c_int = 62;
    // pub const SDL_SCANCODE_F6: c_int = 63;
    // pub const SDL_SCANCODE_F7: c_int = 64;
    // pub const SDL_SCANCODE_F8: c_int = 65;
    // pub const SDL_SCANCODE_F9: c_int = 66;
    // pub const SDL_SCANCODE_F10: c_int = 67;
    // pub const SDL_SCANCODE_F11: c_int = 68;
    // pub const SDL_SCANCODE_F12: c_int = 69;
    // pub const SDL_SCANCODE_PRINTSCREEN: c_int = 70;
    // pub const SDL_SCANCODE_SCROLLLOCK: c_int = 71;
    // pub const SDL_SCANCODE_PAUSE: c_int = 72;
    // pub const SDL_SCANCODE_INSERT: c_int = 73;
    // pub const SDL_SCANCODE_HOME: c_int = 74;
    // pub const SDL_SCANCODE_PAGEUP: c_int = 75;
    // pub const SDL_SCANCODE_DELETE: c_int = 76;
    // pub const SDL_SCANCODE_END: c_int = 77;
    // pub const SDL_SCANCODE_PAGEDOWN: c_int = 78;
    // pub const SDL_SCANCODE_RIGHT: c_int = 79;
    // pub const SDL_SCANCODE_LEFT: c_int = 80;
    // pub const SDL_SCANCODE_DOWN: c_int = 81;
    // pub const SDL_SCANCODE_UP: c_int = 82;
    // pub const SDL_SCANCODE_NUMLOCKCLEAR: c_int = 83;
    // pub const SDL_SCANCODE_KP_DIVIDE: c_int = 84;
    // pub const SDL_SCANCODE_KP_MULTIPLY: c_int = 85;
    // pub const SDL_SCANCODE_KP_MINUS: c_int = 86;
    // pub const SDL_SCANCODE_KP_PLUS: c_int = 87;
    // pub const SDL_SCANCODE_KP_ENTER: c_int = 88;
    // pub const SDL_SCANCODE_KP_1: c_int = 89;
    // pub const SDL_SCANCODE_KP_2: c_int = 90;
    // pub const SDL_SCANCODE_KP_3: c_int = 91;
    // pub const SDL_SCANCODE_KP_4: c_int = 92;
    // pub const SDL_SCANCODE_KP_5: c_int = 93;
    // pub const SDL_SCANCODE_KP_6: c_int = 94;
    // pub const SDL_SCANCODE_KP_7: c_int = 95;
    // pub const SDL_SCANCODE_KP_8: c_int = 96;
    // pub const SDL_SCANCODE_KP_9: c_int = 97;
    // pub const SDL_SCANCODE_KP_0: c_int = 98;
    // pub const SDL_SCANCODE_KP_PERIOD: c_int = 99;
    // pub const SDL_SCANCODE_NONUSBACKSLASH: c_int = 100;
    // pub const SDL_SCANCODE_APPLICATION: c_int = 101;
    // pub const SDL_SCANCODE_POWER: c_int = 102;
    // pub const SDL_SCANCODE_KP_EQUALS: c_int = 103;
    // pub const SDL_SCANCODE_F13: c_int = 104;
    // pub const SDL_SCANCODE_F14: c_int = 105;
    // pub const SDL_SCANCODE_F15: c_int = 106;
    // pub const SDL_SCANCODE_F16: c_int = 107;
    // pub const SDL_SCANCODE_F17: c_int = 108;
    // pub const SDL_SCANCODE_F18: c_int = 109;
    // pub const SDL_SCANCODE_F19: c_int = 110;
    // pub const SDL_SCANCODE_F20: c_int = 111;
    // pub const SDL_SCANCODE_F21: c_int = 112;
    // pub const SDL_SCANCODE_F22: c_int = 113;
    // pub const SDL_SCANCODE_F23: c_int = 114;
    // pub const SDL_SCANCODE_F24: c_int = 115;
    // pub const SDL_SCANCODE_EXECUTE: c_int = 116;
    // pub const SDL_SCANCODE_HELP: c_int = 117;
    // pub const SDL_SCANCODE_MENU: c_int = 118;
    // pub const SDL_SCANCODE_SELECT: c_int = 119;
    // pub const SDL_SCANCODE_STOP: c_int = 120;
    // pub const SDL_SCANCODE_AGAIN: c_int = 121;
    // pub const SDL_SCANCODE_UNDO: c_int = 122;
    // pub const SDL_SCANCODE_CUT: c_int = 123;
    // pub const SDL_SCANCODE_COPY: c_int = 124;
    // pub const SDL_SCANCODE_PASTE: c_int = 125;
    // pub const SDL_SCANCODE_FIND: c_int = 126;
    // pub const SDL_SCANCODE_MUTE: c_int = 127;
    // pub const SDL_SCANCODE_VOLUMEUP: c_int = 128;
    // pub const SDL_SCANCODE_VOLUMEDOWN: c_int = 129;
    // pub const SDL_SCANCODE_KP_COMMA: c_int = 133;
    // pub const SDL_SCANCODE_KP_EQUALSAS400: c_int = 134;
    // pub const SDL_SCANCODE_INTERNATIONAL1: c_int = 135;
    // pub const SDL_SCANCODE_INTERNATIONAL2: c_int = 136;
    // pub const SDL_SCANCODE_INTERNATIONAL3: c_int = 137;
    // pub const SDL_SCANCODE_INTERNATIONAL4: c_int = 138;
    // pub const SDL_SCANCODE_INTERNATIONAL5: c_int = 139;
    // pub const SDL_SCANCODE_INTERNATIONAL6: c_int = 140;
    // pub const SDL_SCANCODE_INTERNATIONAL7: c_int = 141;
    // pub const SDL_SCANCODE_INTERNATIONAL8: c_int = 142;
    // pub const SDL_SCANCODE_INTERNATIONAL9: c_int = 143;
    // pub const SDL_SCANCODE_LANG1: c_int = 144;
    // pub const SDL_SCANCODE_LANG2: c_int = 145;
    // pub const SDL_SCANCODE_LANG3: c_int = 146;
    // pub const SDL_SCANCODE_LANG4: c_int = 147;
    // pub const SDL_SCANCODE_LANG5: c_int = 148;
    // pub const SDL_SCANCODE_LANG6: c_int = 149;
    // pub const SDL_SCANCODE_LANG7: c_int = 150;
    // pub const SDL_SCANCODE_LANG8: c_int = 151;
    // pub const SDL_SCANCODE_LANG9: c_int = 152;
    // pub const SDL_SCANCODE_ALTERASE: c_int = 153;
    // pub const SDL_SCANCODE_SYSREQ: c_int = 154;
    // pub const SDL_SCANCODE_CANCEL: c_int = 155;
    // pub const SDL_SCANCODE_CLEAR: c_int = 156;
    // pub const SDL_SCANCODE_PRIOR: c_int = 157;
    // pub const SDL_SCANCODE_RETURN2: c_int = 158;
    // pub const SDL_SCANCODE_SEPARATOR: c_int = 159;
    // pub const SDL_SCANCODE_OUT: c_int = 160;
    // pub const SDL_SCANCODE_OPER: c_int = 161;
    // pub const SDL_SCANCODE_CLEARAGAIN: c_int = 162;
    // pub const SDL_SCANCODE_CRSEL: c_int = 163;
    // pub const SDL_SCANCODE_EXSEL: c_int = 164;
    // pub const SDL_SCANCODE_KP_00: c_int = 176;
    // pub const SDL_SCANCODE_KP_000: c_int = 177;
    // pub const SDL_SCANCODE_THOUSANDSSEPARATOR: c_int = 178;
    // pub const SDL_SCANCODE_DECIMALSEPARATOR: c_int = 179;
    // pub const SDL_SCANCODE_CURRENCYUNIT: c_int = 180;
    // pub const SDL_SCANCODE_CURRENCYSUBUNIT: c_int = 181;
    // pub const SDL_SCANCODE_KP_LEFTPAREN: c_int = 182;
    // pub const SDL_SCANCODE_KP_RIGHTPAREN: c_int = 183;
    // pub const SDL_SCANCODE_KP_LEFTBRACE: c_int = 184;
    // pub const SDL_SCANCODE_KP_RIGHTBRACE: c_int = 185;
    // pub const SDL_SCANCODE_KP_TAB: c_int = 186;
    // pub const SDL_SCANCODE_KP_BACKSPACE: c_int = 187;
    // pub const SDL_SCANCODE_KP_A: c_int = 188;
    // pub const SDL_SCANCODE_KP_B: c_int = 189;
    // pub const SDL_SCANCODE_KP_C: c_int = 190;
    // pub const SDL_SCANCODE_KP_D: c_int = 191;
    // pub const SDL_SCANCODE_KP_E: c_int = 192;
    // pub const SDL_SCANCODE_KP_F: c_int = 193;
    // pub const SDL_SCANCODE_KP_XOR: c_int = 194;
    // pub const SDL_SCANCODE_KP_POWER: c_int = 195;
    // pub const SDL_SCANCODE_KP_PERCENT: c_int = 196;
    // pub const SDL_SCANCODE_KP_LESS: c_int = 197;
    // pub const SDL_SCANCODE_KP_GREATER: c_int = 198;
    // pub const SDL_SCANCODE_KP_AMPERSAND: c_int = 199;
    // pub const SDL_SCANCODE_KP_DBLAMPERSAND: c_int = 200;
    // pub const SDL_SCANCODE_KP_VERTICALBAR: c_int = 201;
    // pub const SDL_SCANCODE_KP_DBLVERTICALBAR: c_int = 202;
    // pub const SDL_SCANCODE_KP_COLON: c_int = 203;
    // pub const SDL_SCANCODE_KP_HASH: c_int = 204;
    // pub const SDL_SCANCODE_KP_SPACE: c_int = 205;
    // pub const SDL_SCANCODE_KP_AT: c_int = 206;
    // pub const SDL_SCANCODE_KP_EXCLAM: c_int = 207;
    // pub const SDL_SCANCODE_KP_MEMSTORE: c_int = 208;
    // pub const SDL_SCANCODE_KP_MEMRECALL: c_int = 209;
    // pub const SDL_SCANCODE_KP_MEMCLEAR: c_int = 210;
    // pub const SDL_SCANCODE_KP_MEMADD: c_int = 211;
    // pub const SDL_SCANCODE_KP_MEMSUBTRACT: c_int = 212;
    // pub const SDL_SCANCODE_KP_MEMMULTIPLY: c_int = 213;
    // pub const SDL_SCANCODE_KP_MEMDIVIDE: c_int = 214;
    // pub const SDL_SCANCODE_KP_PLUSMINUS: c_int = 215;
    // pub const SDL_SCANCODE_KP_CLEAR: c_int = 216;
    // pub const SDL_SCANCODE_KP_CLEARENTRY: c_int = 217;
    // pub const SDL_SCANCODE_KP_BINARY: c_int = 218;
    // pub const SDL_SCANCODE_KP_OCTAL: c_int = 219;
    // pub const SDL_SCANCODE_KP_DECIMAL: c_int = 220;
    // pub const SDL_SCANCODE_KP_HEXADECIMAL: c_int = 221;
    // pub const SDL_SCANCODE_LCTRL: c_int = 224;
    // pub const SDL_SCANCODE_LSHIFT: c_int = 225;
    // pub const SDL_SCANCODE_LALT: c_int = 226;
    // pub const SDL_SCANCODE_LGUI: c_int = 227;
    // pub const SDL_SCANCODE_RCTRL: c_int = 228;
    // pub const SDL_SCANCODE_RSHIFT: c_int = 229;
    // pub const SDL_SCANCODE_RALT: c_int = 230;
    // pub const SDL_SCANCODE_RGUI: c_int = 231;
    // pub const SDL_SCANCODE_MODE: c_int = 257;
    // pub const SDL_SCANCODE_SLEEP: c_int = 258;
    // pub const SDL_SCANCODE_WAKE: c_int = 259;
    // pub const SDL_SCANCODE_CHANNEL_INCREMENT: c_int = 260;
    // pub const SDL_SCANCODE_CHANNEL_DECREMENT: c_int = 261;
    // pub const SDL_SCANCODE_MEDIA_PLAY: c_int = 262;
    // pub const SDL_SCANCODE_MEDIA_PAUSE: c_int = 263;
    // pub const SDL_SCANCODE_MEDIA_RECORD: c_int = 264;
    // pub const SDL_SCANCODE_MEDIA_FAST_FORWARD: c_int = 265;
    // pub const SDL_SCANCODE_MEDIA_REWIND: c_int = 266;
    // pub const SDL_SCANCODE_MEDIA_NEXT_TRACK: c_int = 267;
    // pub const SDL_SCANCODE_MEDIA_PREVIOUS_TRACK: c_int = 268;
    // pub const SDL_SCANCODE_MEDIA_STOP: c_int = 269;
    // pub const SDL_SCANCODE_MEDIA_EJECT: c_int = 270;
    // pub const SDL_SCANCODE_MEDIA_PLAY_PAUSE: c_int = 271;
    // pub const SDL_SCANCODE_MEDIA_SELECT: c_int = 272;
    // pub const SDL_SCANCODE_AC_NEW: c_int = 273;
    // pub const SDL_SCANCODE_AC_OPEN: c_int = 274;
    // pub const SDL_SCANCODE_AC_CLOSE: c_int = 275;
    // pub const SDL_SCANCODE_AC_EXIT: c_int = 276;
    // pub const SDL_SCANCODE_AC_SAVE: c_int = 277;
    // pub const SDL_SCANCODE_AC_PRINT: c_int = 278;
    // pub const SDL_SCANCODE_AC_PROPERTIES: c_int = 279;
    // pub const SDL_SCANCODE_AC_SEARCH: c_int = 280;
    // pub const SDL_SCANCODE_AC_HOME: c_int = 281;
    // pub const SDL_SCANCODE_AC_BACK: c_int = 282;
    // pub const SDL_SCANCODE_AC_FORWARD: c_int = 283;
    // pub const SDL_SCANCODE_AC_STOP: c_int = 284;
    // pub const SDL_SCANCODE_AC_REFRESH: c_int = 285;
    // pub const SDL_SCANCODE_AC_BOOKMARKS: c_int = 286;
    // pub const SDL_SCANCODE_SOFTLEFT: c_int = 287;
    // pub const SDL_SCANCODE_SOFTRIGHT: c_int = 288;
    // pub const SDL_SCANCODE_CALL: c_int = 289;
    // pub const SDL_SCANCODE_ENDCALL: c_int = 290;
    // pub const SDL_SCANCODE_RESERVED: c_int = 400;
    // pub const SDL_SCANCODE_COUNT: c_int = 512;

    pub fn to_c(self: Scancode) c_uint {
        return @intFromEnum(self);
    }
    pub fn from_c(val: c_uint) Scancode {
        return @enumFromInt(val);
    }
};

pub const Keycode = extern struct {
    code: u32,
};
pub const Keymod = extern struct {
    mod: u16,
};
