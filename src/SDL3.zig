const std = @import("std");
const build = @import("builtin");
const init_zero = std.mem.zeroes;

const Root = @import("root");
const C = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {}); // We are providing our own entry point
    @cInclude("SDL3/SDL_main.h");
});

fn sdl_free(mem: ?*anyopaque) void {
    C.SDL_free(mem);
}

pub fn get_error_details() [:0]const u8 {
    const details_ptr: [*:0]const u8 = C.SDL_GetError();
    return Root.Utils.make_const_slice_from_sentinel_ptr(u8, 0, details_ptr);
}

pub const IRect2 = Root.Rect2.define_rect2_type(c_int);
pub const FRect2 = Root.Rect2.define_rect2_type(f32);
pub const IVec2 = Root.Vec2.define_vec2_type(c_int);
pub const FVec2 = Root.Vec2.define_vec2_type(f32);

pub const PropertiesID = struct {
    id: C.SDL_PropertiesID,

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

    inline fn raw(self: PropertyType) c_uint {
        return @intFromEnum(self);
    }
};

pub const InitStatus = enum(c_uint) {
    UNINIT = C.SDL_INIT_STATUS_UNINITIALIZED,
    INIT_IN_PROGRESS = C.SDL_INIT_STATUS_INITIALIZING,
    INIT = C.SDL_INIT_STATUS_INITIALIZED,
    UNINIT_IN_PROGRESS = C.SDL_INIT_STATUS_UNINITIALIZING,

    inline fn raw(self: InitStatus) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: AudioFormat) c_uint {
        return @intFromEnum(self);
    }
};

pub const BlendOperation = enum(c_uint) {
    ADD = C.SDL_BLENDOPERATION_ADD,
    SUBTRACT = C.SDL_BLENDOPERATION_SUBTRACT,
    REV_SUBTRACT = C.SDL_BLENDOPERATION_REV_SUBTRACT,
    MINIMUM = C.SDL_BLENDOPERATION_MINIMUM,
    MAXIMUM = C.SDL_BLENDOPERATION_MAXIMUM,

    inline fn raw(self: BlendOperation) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: BlendFactor) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: PixelType) c_uint {
        return @intFromEnum(self);
    }
};

pub const BitmapOrder = enum(c_uint) {
    NONE = C.SDL_BITMAPORDER_NONE,
    _4321 = C.SDL_BITMAPORDER_4321,
    _1234 = C.SDL_BITMAPORDER_1234,

    inline fn raw(self: BitmapOrder) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: PackedOrder) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: ArrayOrder) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: PackedLayout) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: PixelFormat) c_uint {
        return @intFromEnum(self);
    }
};

pub const ColorType = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_TYPE_UNKNOWN,
    RGB = C.SDL_COLOR_TYPE_RGB,
    YCBCR = C.SDL_COLOR_TYPE_YCBCR,

    inline fn raw(self: ColorType) c_uint {
        return @intFromEnum(self);
    }
};

pub const ColorRange = enum(c_uint) {
    UNKNOWN = C.SDL_COLOR_RANGE_UNKNOWN,
    LIMITED = C.SDL_COLOR_RANGE_LIMITED,
    FULL = C.SDL_COLOR_RANGE_FULL,

    inline fn raw(self: ColorRange) c_uint {
        return @intFromEnum(self);
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

    inline fn raw(self: ColorPrimaries) c_uint {
        return @intFromEnum(self);
    }
};

pub const ColorU8 = struct {
    raw: C.struct_SDL_Color,
};

pub const ColorF32 = struct {
    raw: C.struct_SDL_FColor,
};

pub const ScaleMode = enum(c_int) {
    INVALID = C.SDL_SCALEMODE_INVALID,
    NEAREST = C.SDL_SCALEMODE_NEAREST,
    LINEAR = C.SDL_SCALEMODE_LINEAR,

    pub fn raw(self: ScaleMode) c_int {
        return @intFromEnum(self);
    }
};

pub const FlipMode = enum(c_uint) {
    NONE = C.SDL_FLIP_NONE,
    HORIZONTAL = C.SDL_FLIP_HORIZONTAL,
    VERTICAL = C.SDL_FLIP_VERTICAL,
    HORIZ_VERT = C.SDL_FLIP_HORIZONTAL | C.SDL_FLIP_VERTICAL,

    pub fn raw(self: FlipMode) c_uint {
        return @intFromEnum(self);
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

    pub fn to_int(self: DisplayOrientation) c_int {
        return @intFromEnum(self);
    }
    pub fn from_int(val: c_int) DisplayOrientation {
        return @enumFromInt(val);
    }
};

pub const DisplayID = extern struct {
    id: u32 = 0,

    pub fn try_get_all_displays() ?DisplayList {
        const len: c_int = 0;
        const c_ptr: ?[*]u32 = C.SDL_GetDisplays(&len);
        if (c_ptr) |c_ptr_good| {
            const ptr: [*]DisplayID = @ptrCast(@alignCast(c_ptr_good));
            return DisplayList{ .ids = ptr[0..len] };
        }
        return null;
    }
    pub fn try_get_primary_display() ?DisplayID {
        const id_result = C.SDL_GetPrimaryDisplay();
        if (id_result == 0) return null;
        return DisplayID{ .id = id_result };
    }
    pub fn try_get_properties(self: DisplayID) ?PropertiesID {
        const id_result = C.SDL_GetDisplayProperties(self.id);
        if (id_result == 0) return null;
        return PropertiesID{ .id = id_result };
    }
    pub fn try_get_name(self: DisplayID) ?[*:0]const u8 {
        return C.SDL_GetDisplayName(self.id);
    }
    pub fn try_get_bounds(self: DisplayID) ?IRect2 {
        const rect: IRect2 = .{};
        if (C.SDL_GetDisplayBounds(self.id, &rect)) return rect;
        return null;
    }
    pub fn try_get_usable_bounds(self: DisplayID) ?IRect2 {
        const rect: IRect2 = .{};
        if (C.SDL_GetDisplayUsableBounds(self.id, &rect)) return rect;
        return null;
    }
    pub fn get_natural_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_int(C.SDL_GetNaturalDisplayOrientation(self.id));
    }
    pub fn get_current_orientation(self: DisplayID) DisplayOrientation {
        return DisplayOrientation.from_int(C.SDL_GetCurrentDisplayOrientation(self.id));
    }
    pub fn get_content_scale(self: DisplayID) f32 {
        return C.SDL_GetDisplayContentScale(self.id);
    }
    pub fn try_get_all_fullscreen_modes(self: DisplayID) ?DisplayModeList {
        const len: c_int = 0;
        const ptr_result: ?[*]*DisplayMode = C.SDL_GetFullscreenDisplayModes(self.id, &len);
        if (ptr_result) |ptr| return DisplayModeList{
            .modes = ptr[0..len],
        };
        return null;
    }
    pub fn try_get_closest_fullscreen_mode(self: DisplayID, options: ClosestDisplayModeOptions) ?DisplayMode {
        const mode = DisplayMode{};
        if (C.SDL_GetClosestFullscreenDisplayMode(self.id, options.width, options.height, options.refresh_rate, options.include_high_density_modes, &mode)) return mode;
        return null;
    }
    pub fn try_get_desktop_mode(self: DisplayID) ?*const DisplayMode {
        return C.SDL_GetDesktopDisplayMode(self.id);
    }
    pub fn try_get_current_mode(self: DisplayID) ?*const DisplayMode {
        return C.SDL_GetCurrentDisplayMode(self.id);
    }
    pub fn try_get_display_for_point(point: IVec2) ?DisplayID {
        const id_result = C.SDL_GetDisplayForPoint(&point);
        if (id_result == 0) return null;
        return DisplayID{ .id = id_result };
    }
    pub fn try_get_display_for_rect(rect: IRect2) ?DisplayID {
        const id_result = C.SDL_GetDisplayForRect(&rect);
        if (id_result == 0) return null;
        return DisplayID{ .id = id_result };
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

    pub fn try_get_window(self: WindowID) ?*Window {
        return C.SDL_GetWindowFromID(self.id);
    }
};

pub const DisplayModeData = extern struct {
    extern_ptr: *anyopaque,
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
    data: ?DisplayModeData = init_zero(?DisplayModeData),

    // pub inline fn to_c(self: DisplayMode) C.SDL_DisplayMode {
    //     return @bitCast(self);
    // }
};

pub const Window = extern struct {
    extern_ptr: *External,

    pub const External = opaque {};

    pub fn try_get_display(self: Window) ?DisplayID {
        return DisplayID.try_get_display_for_window(self);
    }
    pub fn get_pixel_density(self: Window) f32 {
        return C.SDL_GetWindowPixelDensity(self.extern_ptr);
    }
    pub fn get_display_scale(self: Window) f32 {
        return C.SDL_GetWindowDisplayScale(self.extern_ptr);
    }
    pub fn get_fullscreen_display_mode(self: Window) FullscreenMode {
        const result: ?*const DisplayMode = C.SDL_GetWindowFullscreenMode(self.extern_ptr);
        if (result) |mode| return FullscreenMode.new_exclusive(mode);
        return FullscreenMode.new_borderless();
    }
    pub fn try_set_fullscreen_display_mode(self: Window, mode: FullscreenMode) bool {
        switch (mode) {
            .borderless => return C.SDL_SetWindowFullscreenMode(self.extern_ptr, null),
            .exclusive => |excl_mode| return C.SDL_SetWindowFullscreenMode(self.extern_ptr, excl_mode),
        }
    }
    pub fn try_get_icc_profile(self: Window, size: usize) ?WindowICCProfile {
        const result: ?*WindowICCProfile.Extern = C.SDL_GetWindowICCProfile(self.extern_ptr, &size);
        if (result) |ptr| return WindowICCProfile{ .extern_ptr = ptr };
        return null;
    }
    pub fn get_pixel_format(self: Window) PixelFormat {
        return @enumFromInt(C.SDL_GetWindowPixelFormat(self.extern_ptr));
    }
    pub fn try_get_all_windows() ?WindowsList {
        var len: c_int = 0;
        const result: ?[*]*Window.External = C.SDL_GetWindows(&len);
        if (result) |ptr| return WindowsList{ .list = @as([*]Window, @ptrCast(@alignCast(ptr)))[0..len] };
        return null;
    }
    pub fn try_create_window(options: CreateWindowOptions) ?Window {
        const result: ?*Window.External = C.SDL_CreateWindow(options.title.ptr, options.width, options.height, options.flags);
        if (result) |ptr| return Window{ .extern_ptr = ptr };
        return null;
    }
    pub fn try_create_popup_window(parent: Window, options: CreatePopupWindowOptions) ?Window {
        const result: ?*Window.External = C.SDL_CreatePopupWindow(parent.extern_ptr, options.x_offset, options.y_offset, options.width, options.height, options.flags);
        if (result) |ptr| return Window{ .extern_ptr = ptr };
        return null;
    }
    pub fn try_create_window_with_properties(properties: PropertiesID) ?Window {
        const result: ?*Window.External = C.SDL_CreateWindowWithProperties(properties.id);
        if (result) |ptr| return Window{ .extern_ptr = ptr };
        return null;
    }
    pub fn get_id(self: Window) WindowID {
        return WindowID{ .id = C.SDL_GetWindowID(self.extern_ptr) };
    }
    pub fn try_get_parent_window(self: Window) ?Window {
        const result: ?*Window.External = C.SDL_GetWindowFromID(self.extern_ptr);
        if (result) |ptr| return Window{ .extern_ptr = ptr };
        return null;
    }
    pub fn get_properties(self: Window) PropertiesID {
        return PropertiesID{ .id = C.SDL_GetWindowProperties(self.extern_ptr) };
    }
    pub fn get_flags(self: Window) WindowFlags {
        return WindowFlags{ .flags = C.SDL_GetWindowFlags(self.extern_ptr) };
    }
    pub fn try_set_title(self: Window, title: [:0]const u8) bool {
        return C.SDL_SetWindowTitle(self.extern_ptr, title.ptr);
    }
    pub fn get_title_ptr(self: Window) [*:0]const u8 {
        return C.SDL_GetWindowTitle(self.extern_ptr);
    }
    pub fn get_title_slice(self: Window) [:0]const u8 {
        const ptr = self.get_title_ptr();
        return Root.Utils.make_slice_from_sentinel_ptr(u8, 0, ptr);
    }
    pub fn try_set_window_icon(self: Window, icon: *Surface) bool {
        return C.SDL_SetWindowIcon(self.extern_ptr, @ptrCast(@alignCast(icon)));
    }
    pub fn try_set_window_position(self: Window, pos: IVec2) bool {
        return C.SDL_SetWindowPosition(self.extern_ptr, pos.x, pos.y);
    }
    pub fn try_get_window_position(self: Window) ?IVec2 {
        var point: IVec2 = IVec2.ZERO;
        const success = C.SDL_GetWindowPosition(self.extern_ptr, &point.x, &point.y);
        if (success) return point;
        return null;
    }
    pub fn try_set_size(self: Window, size: IVec2) bool {
        return C.SDL_SetWindowSize(self.extern_ptr, size.x, size.y);
    }
    pub fn try_get_size(self: Window) ?IVec2 {
        var size = IVec2.ZERO;
        const success = C.SDL_GetWindowSize(self.extern_ptr, &size.x, &size.y);
        if (success) return size;
        return null;
    }
    pub fn try_get_safe_area(self: Window) ?IRect2 {
        var rect = IRect2{};
        const success = C.SDL_GetWindowSafeArea(self.extern_ptr, @ptrCast(@alignCast(&rect)));
        if (success) return rect;
        return null;
    }
    pub fn try_set_aspect_ratio(self: Window, aspect_ratio: AspectRatio) bool {
        return C.SDL_SetWindowAspectRatio(self.extern_ptr, aspect_ratio.min, aspect_ratio.max);
    }
    pub fn try_get_aspect_ratio(self: Window) ?AspectRatio {
        var ratio = AspectRatio{};
        const success = C.SDL_SetWindowAspectRatio(self.extern_ptr, &ratio.min, &ratio.max);
        if (success) return ratio;
        return null;
    }
    pub fn try_get_border_sizes(self: Window) ?BorderSizes {
        var sizes = BorderSizes{};
        const success = C.SDL_GetWindowBordersSize(self.extern_ptr, &sizes.top, &sizes.left, &sizes.bottom, &sizes.right);
        if (success) return sizes;
        return null;
    }
    pub fn try_get_size_in_pixels(self: Window) ?IVec2 {
        var size = IVec2{};
        const success = C.SDL_GetWindowSizeInPixels(self.extern_ptr, &size.x, &size.y);
        if (success) return size;
        return null;
    }
    pub fn try_set_minimum_size(self: Window, size: IVec2) bool {
        return C.SDL_SetWindowMinimumSize(self.extern_ptr, size.x, size.y);
    }
    pub fn try_get_minimum_size(self: Window) ?IVec2 {
        var size = IVec2{};
        const success = C.SDL_GetWindowMinimumSize(self.extern_ptr, &size.x, &size.y);
        if (success) return size;
        return null;
    }
    pub fn try_set_maximum_size(self: Window, size: IVec2) bool {
        return C.SDL_SetWindowMaximumSize(self.extern_ptr, size.x, size.y);
    }
    pub fn try_get_maximum_size(self: Window) ?IVec2 {
        var size = IVec2{};
        const success = C.SDL_GetWindowMaximumSize(self.extern_ptr, &size.x, &size.y);
        if (success) return size;
        return null;
    }
    pub fn try_set_bordered(self: Window, state: bool) bool {
        return C.SDL_SetWindowBordered(self.extern_ptr, state);
    }
    pub fn try_set_resizable(self: Window, state: bool) bool {
        return C.SDL_SetWindowResizable(self.extern_ptr, state);
    }
    pub fn try_set_always_on_top(self: Window, state: bool) bool {
        return C.SDL_SetWindowAlwaysOnTop(self.extern_ptr, state);
    }
    pub fn try_show(self: Window) bool {
        return C.SDL_ShowWindow(self.extern_ptr);
    }
    pub fn try_hide(self: Window) bool {
        return C.SDL_HideWindow(self.extern_ptr);
    }
    pub fn try_raise(self: Window) bool {
        return C.SDL_RaiseWindow(self.extern_ptr);
    }
    pub fn try_maximize(self: Window) bool {
        return C.SDL_MaximizeWindow(self.extern_ptr);
    }
    pub fn try_minimize(self: Window) bool {
        return C.SDL_MinimizeWindow(self.extern_ptr);
    }
    pub fn try_restore(self: Window) bool {
        return C.SDL_RestoreWindow(self.extern_ptr);
    }
    pub fn try_set_fullscreen(self: Window, state: bool) bool {
        return C.SDL_SetWindowFullscreen(self.extern_ptr, state);
    }
    pub fn try_sync(self: Window) bool {
        return C.SDL_SyncWindow(self.extern_ptr);
    }
    pub fn has_surface(self: Window) bool {
        return C.SDL_WindowHasSurface(self.extern_ptr);
    }
    pub fn try_get_surface(self: Window) ?*Surface {
        return @ptrCast(@alignCast(C.SDL_GetWindowSurface(self.extern_ptr)));
    }
    pub fn try_set_surface_vsync(self: Window, vsync: VSync) bool {
        return C.SDL_SetWindowSurfaceVSync(self.extern_ptr, vsync.to_int());
    }
    pub fn try_get_surface_vsync(self: Window) ?VSync {
        var int: c_int = 0;
        const success = C.SDL_GetWindowSurfaceVSync(self.extern_ptr, &int);
        if (success) return VSync.from_int(int);
        return null;
    }
    pub fn try_update_surface(self: Window) bool {
        return C.SDL_UpdateWindowSurface(self.extern_ptr);
    }
    pub fn try_update_surface_rects(self: Window, rects: []const IRect2) bool {
        return C.SDL_UpdateWindowSurfaceRects(self.extern_ptr, @ptrCast(@alignCast(rects.ptr)), @intCast(rects.len));
    }
    pub fn try_destroy_surface(self: Window) bool {
        return C.SDL_DestroyWindowSurface(self.extern_ptr);
    }
    pub fn try_set_keyboard_grab(self: Window, state: bool) bool {
        return C.SDL_SetWindowKeyboardGrab(self.extern_ptr, state);
    }
    pub fn try_set_mouse_grab(self: Window, state: bool) bool {
        return C.SDL_SetWindowMouseGrab(self.extern_ptr, state);
    }
    pub fn try_get_keyboard_grab(self: Window) bool {
        return C.SDL_GetWindowKeyboardGrab(self.extern_ptr);
    }
    pub fn try_get_mouse_grab(self: Window) bool {
        return C.SDL_GetWindowMouseGrab(self.extern_ptr);
    }
    pub fn try_get_grabbed_window() ?Window {
        const ptr: ?*Window.External = C.SDL_GetGrabbedWindow();
        if (ptr) |good_ptr| return Window{ .extern_ptr = good_ptr };
        return null;
    }
    pub fn try_set_mouse_rect(self: Window, rect: IRect2) bool {
        return C.SDL_SetWindowMouseRect(self.extern_ptr, @ptrCast(@alignCast(&rect)));
    }
    pub fn try_get_mouse_rect(self: Window) ?IRect2 {
        const ptr: ?*IRect2 = @ptrCast(@alignCast(C.SDL_GetWindowMouseRect(self.extern_ptr)));
        if (ptr) |good_ptr| return good_ptr.*;
        return null;
    }
    pub fn try_set_opacity(self: Window, opacity: f32) bool {
        return C.SDL_SetWindowOpacity(self.extern_ptr, opacity);
    }
    pub fn get_opacity(self: Window) f32 {
        return C.SDL_GetWindowOpacity(self.extern_ptr);
    }
    pub fn try_set_parent(self: Window, parent: Window) bool {
        return C.SDL_SetWindowParent(self.extern_ptr, parent.extern_ptr);
    }
    pub fn try_clear_parent(self: Window) bool {
        return C.SDL_SetWindowParent(self.extern_ptr, null);
    }
    pub fn try_set_modal(self: Window, state: bool) bool {
        return C.SDL_SetWindowModal(self.extern_ptr, state);
    }
    pub fn try_set_focusable(self: Window, state: bool) bool {
        return C.SDL_SetWindowFocusable(self.extern_ptr, state);
    }
    pub fn try_show_system_menu(self: Window, pos: IVec2) bool {
        return C.SDL_ShowWindowSystemMenu(self.extern_ptr, pos.x, pos.y);
    }
};

pub const VSync = enum(c_int) {
    adaptive = C.SDL_WINDOW_SURFACE_VSYNC_ADAPTIVE,
    disabled = C.SDL_WINDOW_SURFACE_VSYNC_DISABLED,
    _,

    pub fn to_int(self: VSync) c_int {
        return @intFromEnum(self);
    }
    pub fn from_int(val: c_int) VSync {
        return @enumFromInt(val);
    }
};

pub const BorderSizes = extern struct {
    top: c_uint = 0,
    left: c_uint = 0,
    bottom: c_uint = 0,
    right: c_uint = 0,
};

pub const AspectRatio = extern struct {
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

pub const WindowICCProfile = extern struct {
    extern_ptr: *Extern,

    pub const Extern = opaque {};
};

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
    };
};

pub const Surface = extern struct {
    flags: SurfaceFlags = SurfaceFlags{},
    format: PixelFormat = .UNKNOWN,
    width: c_int = 0,
    height: c_int = 0,
    pitch: c_int = 0,
    pixels: ?*anyopaque = null,
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
