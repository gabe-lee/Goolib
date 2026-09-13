//! A demonstration/test of the immediate-mode layout system to draw
//! a simple UI.
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

const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

const Goolib = @import("Goolib");
const SDL = Goolib.SDL3;
const AABB = Goolib.AABB2.define_aabb2_type(f32);
const Rect = Goolib.Rect2.define_rect2_type(f32);
const FVec: type = SDL.Vec_f32;
const IVec: type = SDL.Vec_c_int;
const Cast = Goolib.Cast;
const c_strings_equal = Goolib.Utils.c_strings_equal;
const ANSI = Goolib.ANSI;
const Size = FVec;
const Pos = FVec;
const Idx = u32;
const NULL_IDX = std.math.maxInt(Idx);
const Layout = Goolib.Layout;
const LayoutManager = Goolib.Layout.DefineLayoutManager(f32, f16, u32);
const LayoutRequester = LayoutManager.LayoutRequester;
const LayoutRequest = LayoutManager.LayoutRequest;
const LayoutElement = LayoutManager.LayoutElement;
const SizeCheckInfo = LayoutManager.SizeCheckInfo;
const AxisLineLocalAlign = Layout.AxisLineLocalAlign;
const SecondarySizeResult = LayoutManager.SecondarySizeResult;
const ChildAlign = Layout.ChildAlignment;

var fully_initialized = false;
const window_size: IVec = IVec.new(ROOT_SIZE_I, ROOT_SIZE_I);
var window: *SDL.Window = undefined;
var renderer: *SDL.Renderer = undefined;

const NUM_ELEMS_LEVEL_1 = 9;
const NUM_ELEMS_LEVEL_2 = 9;
const ROOT_SIZE = 800.0;
const ROOT_SIZE_I = 800;
const MIN_SIZE_LV_1 = 100.0;
const MAX_SIZE_LV_1 = 500.0;
const SIZE_RANGE_LV_1 = MAX_SIZE_LV_1 - MIN_SIZE_LV_1;
const MIN_SIZE_LV_2 = 50.0;
const MAX_SIZE_LV_2 = 300.0;
const SIZE_RANGE_LV_2 = MAX_SIZE_LV_2 - MIN_SIZE_LV_2;
const PADDING = 8.0;
const GAP = 8.0;
const MIN_COLOR_COMP = 50;
const MAX_COLOR_COMP = 150;
const MAX_SIZE_CHANGE = 10.0;
const MIN_DELTA_DURR = 1.0;
const MAX_DELTA_DURR = 5.0;
const DELTA_DURR_RANGE = MAX_DELTA_DURR - MIN_DELTA_DURR;

const ElemList = struct {
    ptr: [*]UIElement = Goolib.Utils.invalid_ptr_many(UIElement),
    len: u32 = 0,
    cap: u32 = 0,

    pub fn append_new(self: *ElemList) struct { *UIElement, u32 } {
        if (self.len >= self.cap) {
            Goolib.Utils.Alloc.smart_alloc_ptr_ptrs(alloc, &self.ptr, &self.len, &self.cap, self.len + 1, .{}, .{ .ERROR_MODE = .ERRORS_PANIC });
        }
        const idx = self.len;
        self.len += 1;
        return .{ &self.ptr[idx], idx };
    }
};
const alloc = std.heap.smp_allocator;
var elem_list = ElemList{};

var rand_impl: std.Random.DefaultPrng = undefined;
var rand: std.Random = undefined;
var prev_ticks: u64 = 0;
var manager = LayoutManager.new(.empty_allow_realloc(alloc), .empty_allow_realloc(alloc), .empty_allow_realloc(alloc));

const UIElement = struct {
    self_idx: u32,
    color: SDL.Color_RGBA_u8,
    size: Size,
    grow_x: bool,
    grow_y: bool,
    alla: AxisLineLocalAlign = .INHERIT,
    aspect: ?f32 = null,
    first_child: Idx = NULL_IDX,
    last_child: Idx = NULL_IDX,
    next_sibling: Idx = NULL_IDX,
    level: u8 = 0,
    curr_time: f32 = 0,
    next_mult_time: f32,
    dx: f32,
    dy: f32,

    pub fn init(self_idx: u32, parent: u32, level: u8) UIElement {
        const r = rand.intRangeAtMost(u8, MIN_COLOR_COMP, MAX_COLOR_COMP);
        const g = rand.intRangeAtMost(u8, MIN_COLOR_COMP, MAX_COLOR_COMP);
        const b = rand.intRangeAtMost(u8, MIN_COLOR_COMP, MAX_COLOR_COMP);
        const min: f32 = switch (level) {
            0 => ROOT_SIZE,
            1 => MIN_SIZE_LV_1,
            2 => MIN_SIZE_LV_2,
            else => ROOT_SIZE,
        };
        const range: f32 = switch (level) {
            0 => 0,
            1 => MAX_SIZE_LV_1 - MIN_SIZE_LV_1,
            2 => MAX_SIZE_LV_2 - MIN_SIZE_LV_2,
            else => 0,
        };
        const x: f32 = (rand.float(f32) * range) + min;
        const y: f32 = (rand.float(f32) * range) + min;
        const gx = if (level == 0 or rand.float(f32) > 0.8) false else true;
        const gy = if (level == 0 or rand.float(f32) > 0.8) false else true;
        const alla_r = rand.float(f32);
        const alla: AxisLineLocalAlign = if (level == 0 or alla_r < 0.7) .INHERIT else if (alla_r < 0.8) .TOP_OR_LEFT else if (alla_r < 0.9) .CENTER else .BOTTOM_OR_RIGHT;
        const aspect_r = rand.float(f32) > 0.8;
        const aspect: ?f32 = if (!aspect_r) null else (x / y);
        if (parent != NULL_IDX) {
            if (elem_list.ptr[parent].last_child != NULL_IDX) {
                elem_list.ptr[elem_list.ptr[parent].last_child].next_sibling = self_idx;
            }
            if (elem_list.ptr[parent].first_child == NULL_IDX) {
                elem_list.ptr[parent].first_child = self_idx;
            }
            elem_list.ptr[parent].last_child = self_idx;
        }
        const tx = if (level == 0) x else ((rand.float(f32) * range) + min);
        const ty = if (level == 0) y else ((rand.float(f32) * range) + min);
        const dt: f32 = (rand.float(f32) * DELTA_DURR_RANGE) + MIN_DELTA_DURR;
        const dx = (tx - x) * dt;
        const dy = (ty - y) * dt;
        return UIElement{
            .self_idx = self_idx,
            .color = .new_rgba(r, g, b, 0xff),
            .size = .new(x, y),
            .grow_x = gx,
            .grow_y = gy,
            .alla = alla,
            .level = level,
            .aspect = aspect,
            .next_mult_time = dt,
            .dx = dx,
            .dy = dy,
        };
    }

    fn impl_check_secondary_size(obj: *anyopaque, info: SizeCheckInfo) SecondarySizeResult {
        const self: *UIElement = @ptrCast(@alignCast(obj));
        if (self.aspect) |ratio| {
            return info.preserve_aspect_ratio_x_to_y(ratio);
        } else {
            return info.unchanged_secondary();
        }
    }
    fn impl_get_layout_request(obj: *anyopaque) LayoutRequest {
        const self: *UIElement = @ptrCast(@alignCast(obj));
        return LayoutRequest{
            .child_align = .x_y(.LEFT, .TOP),
            .child_gaps = .uniform(8.0),
            .child_layout_dir = .LEFT_TO_RIGHT__TOP_TO_BOTTOM,
            .children_axis_line_local_align = .INHERIT,
            .self_axis_line_local_align = self.alla,
            .clip_to_parent = true,
            .float = .not_floating(),
            .grow_x_to_fill_parent_space = self.grow_x,
            .grow_y_to_fill_parent_space = self.grow_y,
            .padding = .uniform(8.0),
            .wrap_children_that_overflow_size = true,
            .min_size = self.size,
        };
    }
    fn impl_get_first_child(obj: *anyopaque) ?LayoutRequester {
        const self: *UIElement = @ptrCast(@alignCast(obj));
        if (self.first_child != NULL_IDX) {
            return elem_list.ptr[self.first_child].layout_requester();
        }
        return null;
    }
    fn impl_get_next_sibling(obj: *anyopaque) ?LayoutRequester {
        const self: *UIElement = @ptrCast(@alignCast(obj));
        if (self.next_sibling != NULL_IDX) {
            return elem_list.ptr[self.next_sibling].layout_requester();
        }
        return null;
    }
    pub fn update(self: *UIElement, delta_time: f32) void {
        switch (self.level) {
            1 => {
                self.size.x = @min(MAX_SIZE_LV_1, @max(MIN_SIZE_LV_1, self.size.x + (self.dx * delta_time)));
                self.size.y = @min(MAX_SIZE_LV_1, @max(MIN_SIZE_LV_1, self.size.y + (self.dy * delta_time)));
                self.curr_time += delta_time;
                if (self.curr_time > self.next_mult_time) {
                    self.curr_time -= self.next_mult_time;
                    const tx = ((rand.float(f32) * SIZE_RANGE_LV_1) + MIN_SIZE_LV_1);
                    const ty = ((rand.float(f32) * SIZE_RANGE_LV_1) + MIN_SIZE_LV_1);
                    const dt: f32 = (rand.float(f32) * DELTA_DURR_RANGE) + MIN_DELTA_DURR;
                    self.dx = (tx - self.size.x) * dt;
                    self.dy = (ty - self.size.y) * dt;
                    self.next_mult_time = self.curr_time + dt;
                }
            },
            2 => {
                self.size.x = @min(MAX_SIZE_LV_2, @max(MIN_SIZE_LV_2, self.size.x + (self.dx * delta_time)));
                self.size.y = @min(MAX_SIZE_LV_2, @max(MIN_SIZE_LV_2, self.size.y + (self.dy * delta_time)));
                self.curr_time += delta_time;
                if (self.curr_time > self.next_mult_time) {
                    self.curr_time -= self.next_mult_time;
                    const tx = ((rand.float(f32) * SIZE_RANGE_LV_2) + MIN_SIZE_LV_2);
                    const ty = ((rand.float(f32) * SIZE_RANGE_LV_2) + MIN_SIZE_LV_2);
                    const dt: f32 = (rand.float(f32) * DELTA_DURR_RANGE) + MIN_DELTA_DURR;
                    self.dx = (tx - self.size.x) * dt;
                    self.dy = (ty - self.size.y) * dt;
                    self.next_mult_time = self.curr_time + dt;
                }
            },
            else => {},
        }
    }
    // pub fn draw(elems: *LayoutManager.Elems, idx: u32, manager: *LayoutManager, comptime _: void) anyerror!LayoutManager.Elems {
    //     return elems;
    // }

    const REQ_VTABLE = LayoutRequester.VTABLE{
        .check_secondary_size = impl_check_secondary_size,
        .get_layout_request = impl_get_layout_request,
        .get_first_child = impl_get_first_child,
        .get_next_sibling = impl_get_next_sibling,
    };

    pub fn layout_requester(self: *UIElement) LayoutRequester {
        return LayoutRequester{
            .object = @ptrCast(self),
            .vtable = &REQ_VTABLE,
        };
    }
};

var app_err: ErrorStore = .{};

fn fmt_sdl_drivers(write_buf: *BoundedArray(u8, 250), current_driver: [*:0]const u8, num_drivers: c_int, get_driver: *const fn (c_int) SDL.Error![*:0]const u8) anyerror![]const u8 {
    var w: BoundedArray(u8, 250).Writer = write_buf.writer();
    var writer: *std.Io.Writer = &w.interface;
    var i: c_int = 0;
    while (i < num_drivers) : (i += 1) {
        const driver_name = try get_driver(i);
        // _ = c_strings_equal(driver_name, current_driver);
        const is_current = c_strings_equal(driver_name, current_driver);
        if (is_current) _ = try writer.write(ANSI.FG_GREEN);
        try writer.print("\n\t({d}) {s}", .{ i, driver_name });
        if (is_current) _ = try writer.write(ANSI.RESET);
    }
    return write_buf.slice();
}

const ErrorStore = struct {
    const STATUS_NOT_STORED = 0;
    const STATUS_STORING = 1;
    const STATUS_STORED = 2;

    status: SDL.AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = es.status.set(STATUS_NOT_STORED);
    }

    fn store(es: *ErrorStore, err: anyerror) SDL.AppResult {
        if (es.status.compare_and_swap(STATUS_NOT_STORED, STATUS_STORING)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = es.status.set(STATUS_STORED);
        }
        return SDL.AppResult.CLOSE_ERROR;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (es.status.get() != STATUS_STORED) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};

var main_init: std.process.Init = undefined;

pub fn main(init: std.process.Init) !u8 {
    main_init = init;
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(SDL.App.run_app(empty_argv.len, @ptrCast(&empty_argv), sdl_main_func))));
    return app_err.load() orelse status;
}

pub fn app_init(appstate: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) anyerror!SDL.AppResult {
    _ = appstate;
    _ = arg_count;
    _ = arg_list;

    rand_impl = std.Random.DefaultPrng.init(@bitCast(std.Io.Clock.now(.real, main_init.io).toMilliseconds()));
    rand = rand_impl.random();

    var write_buf = BoundedArray(u8, 250){};

    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        SDL.Meta.BUILD_MAJOR_VERSION,
        SDL.Meta.BUILD_MINOR_VERSION,
        SDL.Meta.BUILD_MICRO_VERSION,
    });
    sdl_log.debug("SDL build time revision: {s}", .{SDL.Meta.BUILD_REVISION});
    {
        const version = SDL.Meta.runtime_version();
        sdl_log.debug("SDL runtime version: {d}.{d}.{d}", .{
            SDL.Meta.RUNTIME_MAJOR_VERSION(version),
            SDL.Meta.RUNTIME_MINOR_VERSION(version),
            SDL.Meta.RUNTIME_MICRO_VERSION(version),
        });
        const revision: [*:0]const u8 = SDL.Meta.runtime_revision();
        sdl_log.debug("SDL runtime revision: {s}", .{revision});
    }

    try SDL.App.set_metadata("Layout Sample", "0.0.0", "goolib.sample.layout");
    try SDL.App.init(SDL.InitFlags.from_flags(&.{.VIDEO}));
    write_buf.clear();
    sdl_log.debug("SDL video drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try SDL.Video.get_current_video_driver(),
        SDL.Video.get_num_video_drivers(),
        SDL.Video.get_video_driver,
    )});
    write_buf.clear();

    SDL.App.set_hint(SDL.HINT.RENDER_VSYNC, "1") catch {};

    window = try SDL.Window.create(.{ .title = "Layout Sample", .size = window_size });
    errdefer window.destroy();
    renderer = try window.create_renderer();
    errdefer renderer.destroy();

    write_buf.clear();
    sdl_log.debug("SDL render drivers: {s}", .{try fmt_sdl_drivers(
        &write_buf,
        try renderer.get_name(),
        SDL.Renderer.get_driver_count(),
        SDL.Renderer.get_driver_name,
    )});

    const root_elem, const root_idx = elem_list.append_new();
    root_elem.* = .init(root_idx, NULL_IDX, 0); //BUG //FIXME // CHECKPOINT
    for (0..NUM_ELEMS_LEVEL_1) |_| {
        const lv_1_child, const lv_1_child_idx = elem_list.append_new();
        lv_1_child.* = .init(lv_1_child_idx, root_idx, 1);
        for (0..NUM_ELEMS_LEVEL_2) |_| {
            const lv_2_child, const lv_2_child_idx = elem_list.append_new();
            lv_2_child.* = .init(lv_2_child_idx, lv_1_child_idx, 2);
        }
    }

    fully_initialized = true;
    errdefer comptime unreachable;

    return SDL.AppResult.CONTINUE;
}

fn draw_element(elems: LayoutManager.Elems, idx: u32, renderer_: *SDL.Renderer, comptime _: void) anyerror!LayoutManager.Elems {
    const elem_layout = elems.ptr[idx];
    const elem_data: *UIElement = @ptrCast(@alignCast(elem_layout.requester.object));
    try renderer_.set_draw_color(elem_data.color);
    const rect = elem_layout.get_aabb().to_rect2();
    try renderer_.set_clip_rect(elem_layout.get_clip_aabb().to_rect2().to_new_type(c_int));
    try renderer_.draw_rect_filled(&rect);
    try renderer_.clear_clip_rect();
    return elems;
}

fn app_update(appstate: ?*anyopaque) !SDL.AppResult {
    _ = appstate;

    const new_ticks = SDL.Time.get_ticks_ms();
    const delta_ticks = new_ticks - prev_ticks;
    prev_ticks = new_ticks;
    const delta_time = Cast.num_cast(delta_ticks, f32) / 1000.0;

    // Update
    {
        for (elem_list.ptr[0..elem_list.len]) |*elem| {
            elem.update(delta_time);
        }
    }

    // Evaluate Layout
    {
        try manager.collect_element_heirarchy(elem_list.ptr[0].layout_requester());
        try manager.recalculate_layout(.X);
    }

    // Draw.
    {
        const CLEAR_COLOR = SDL.Color_RGBA_u8.new(0x00, 0x00, 0x00, 0xff);
        try renderer.set_draw_color(CLEAR_COLOR);
        try renderer.draw_clear_fill();

        try manager.do_action_on_all_elements(.PARENTS_FIRST, renderer, void{}, .COMPTIME_FN_PTR, void{}, draw_element);
        try renderer.present();
    }

    return SDL.AppResult.CONTINUE;
}

fn handle_event(appstate: ?*anyopaque, event_: ?*SDL.Event) !SDL.AppResult {
    _ = appstate;
    const event = event_ orelse return SDL.AppResult.CONTINUE;
    switch (event.type) {
        .QUIT => {
            return SDL.AppResult.CLOSE_NORMAL;
        },
        // .KEY_DOWN, .KEY_UP => {
        //     const is_down = event.type == .KEY_DOWN;
        //     switch (event.keyboard.scancode) {
        //         .LEFT => phcon.k_left = is_down,
        //         .RIGHT => phcon.k_right = is_down,
        //         .LSHIFT => phcon.k_lshift = is_down,
        //         .SPACE => phcon.k_space = is_down,
        //         .R => phcon.k_r = is_down,
        //         .ESCAPE => phcon.k_escape = is_down,
        //         else => {},
        //     }
        // },
        // .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP => {
        //     const is_down = event.type == .MOUSE_BUTTON_DOWN;
        //     switch (event.mouse_button.button) {
        //         .LEFT => phcon.m_left = is_down,
        //         else => {},
        //     }
        // },
        // .MOUSE_MOTION => {
        //     phcon.m_xrel += event.mouse_motion.delta.x;
        // },
        else => {},
    }

    return SDL.AppResult.CONTINUE;
}

fn app_quit(appstate: ?*anyopaque, result: anyerror!SDL.AppResult) void {
    _ = appstate;
    _ = result catch |err| switch (err) {
        SDL.Error.SDL_null_value,
        SDL.Error.SDL_operation_failure,
        SDL.Error.SDL_invalid_value,
        => {
            sdl_log.err("{s}: {s}", .{ @errorName(err), SDL.App.get_error_details() });
        },
        else => {
            app_log.err("{s}", .{@errorName(err)});
        },
    };

    if (fully_initialized) {
        renderer.destroy();
        window.destroy();
        fully_initialized = false;
    }
}

fn sdl_main_func(arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return SDL.App.run_app_with_callbacks(arg_count, arg_list, sdl_init_func, sdl_update_func, sdl_event_func, sdl_quit_func);
}

fn sdl_init_func(appstate: ?*?*anyopaque, arg_count: c_int, arg_list: ?[*:null]?[*:0]u8) callconv(.c) SDL.AppResult {
    return app_init(appstate, arg_count, arg_list) catch |err| app_err.store(err);
}

fn sdl_update_func(appstate: ?*anyopaque) callconv(.c) SDL.AppResult {
    return app_update(appstate) catch |err| app_err.store(err);
}

fn sdl_event_func(appstate: ?*anyopaque, event: ?*SDL.Event) callconv(.c) SDL.AppResult {
    return handle_event(appstate, event) catch |err| app_err.store(err);
}

fn sdl_quit_func(appstate: ?*anyopaque, close_result: SDL.AppResult) callconv(.c) void {
    app_quit(appstate, app_err.load() orelse close_result);
}

fn BoundedArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        arr: [N]T = undefined,
        len: usize = 0,

        pub fn clear(self: *Self) void {
            self.len = 0;
        }
        pub fn slice(self: *Self) []T {
            return self.arr[0..self.len];
        }
        pub fn append(self: *Self, val: T) void {
            self.arr[self.len] = val;
            self.len += 1;
        }
        pub fn swapRemove(self: *Self, idx: usize) T {
            const rem = self.arr[idx];
            self.arr[idx] = self.arr[self.len - 1];
            self.len -= 1;
            return rem;
        }

        pub fn writer(self: *Self) Writer {
            const empty: [0]u8 = undefined;
            return .{ .buf = self, .interface = std.Io.Writer{
                .end = 0,
                .buffer = empty[0..0],
                .vtable = &VT,
            } };
        }
        const VT = std.Io.Writer.VTable{
            .drain = Writer.drain,
        };

        pub const Writer = struct {
            buf: *Self,
            interface: std.Io.Writer,
            // this has a bunch of other fields

            fn drain(io_w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
                _ = splat;
                const self: *Writer = @fieldParentPtr("interface", io_w);
                const old_n = self.buf.len;
                for (data) |d| {
                    const n = d.len;
                    @memcpy(self.buf.arr[self.buf.len .. self.buf.len + n], d);
                    self.buf.len += n;
                }
                return self.buf.len - old_n;
            }
        };
    };
}
