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
    fn to_sdl(self: *Renderer) *C.SDL_Renderer {
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
    //CHECKPOINT
    // pub extern fn SDL_SetRenderTarget(renderer: ?*SDL_Renderer, texture: [*c]SDL_Texture) bool;
    // pub extern fn SDL_GetRenderTarget(renderer: ?*SDL_Renderer) [*c]SDL_Texture;
    // pub extern fn SDL_SetRenderLogicalPresentation(renderer: ?*SDL_Renderer, w: c_int, h: c_int, mode: SDL_RendererLogicalPresentation) bool;
    // pub extern fn SDL_GetRenderLogicalPresentation(renderer: ?*SDL_Renderer, w: [*c]c_int, h: [*c]c_int, mode: [*c]SDL_RendererLogicalPresentation) bool;
    // pub extern fn SDL_GetRenderLogicalPresentationRect(renderer: ?*SDL_Renderer, rect: [*c]SDL_FRect) bool;
    // pub extern fn SDL_RenderCoordinatesFromWindow(renderer: ?*SDL_Renderer, window_x: f32, window_y: f32, x: [*c]f32, y: [*c]f32) bool;
    // pub extern fn SDL_RenderCoordinatesToWindow(renderer: ?*SDL_Renderer, x: f32, y: f32, window_x: [*c]f32, window_y: [*c]f32) bool;
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
