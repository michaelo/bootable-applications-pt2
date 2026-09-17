const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");
const DebugConsole = @import("talk-slides/debug-console.zig").DebugConsole;
const Shaders = @import("lib/shaders.zig");

const Pixel = drawing.Pixel;
const Colors = drawing.Colors;

const slides = [_]*const fn (*State, f32) SlideResult{
    slideSelectRes,
    @import("talk-slides/slideIntro.zig").slide,
    @import("talk-slides/slideImage.zig").slide,
    // slideAnimationRaw,
    // slideAnimationSmooth,
    slideBasicPointer,
    // slideUi,
    slideShaderCheckerboard,
    slideShaderRadialPlasma,
    slideShaderSineWave,
    slideWhereToNow,
    slideQuestions,
    slideFinal,
};

const themeDark = Style{
    .fg_color = drawing.Colors.white,
    .bg_color = drawing.Colors.black,
    .outline_color = drawing.Pixel{ .int = 0xff999999 },
};

const themeLight = Style{
    .fg_color = drawing.Colors.black,
    .bg_color = drawing.Colors.white,
    .outline_color = drawing.Pixel{ .int = 0xffcccccc },
};

// Default colors to allow easy theming
pub var defaultStyle: *const Style = &themeLight;

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

/// Global state
pub const State = struct {
    /// A debug console allowing dumping formatted text output to screen. Rendered, thus providing a
    /// simple way to output data even on devices which doesn't render con_out
    console: DebugConsole(20) = .{
        .bg = drawing.Colors.white,
        .fg = drawing.Colors.black,
    },
    /// Used e.g. for tab activity or otherwise communicating an active element - e.g. a button being pressed. TBD
    activeElement: u32 = 0,
    /// Computationally heavy slides may choose to render to a low res bitmap, then scale up to backbuffer <- the efficiency of this is debatable. Might remove.
    lowres: drawing.Bitmap,
    /// Backbuffer allowing us to render an entire frame before copying to videobuffer. Same size as video buffer.
    backbuffer: drawing.Bitmap,
    /// Wrapper for the actual video buffer
    screen: drawing.Bitmap,
    /// The total time since start of rendering
    globalT: f32 = 0,
    /// The total time spent within current frame
    frameT: f32 = 0,
    slideIdx: usize = 0,
    /// A convenience-unit to render consistent sizes across resolutions. E.g. window.width / 100 will make the base unit 1pct of window width
    unit: f32 = 0,
    firstFrame: bool = false,
    // displaySize: Vector2 = .{ 0, 0 },
    pointerPos: Vector2 = .{ .x = 0, .y = 0 },
    event: ?Event = null,
    // rendermode: scale up | backbuffer | raw (assumes screen is directly manipulated, do nothing). Currently leaving it the slide-renderer to use lowres-buffer if desired
};

pub const EventType = enum {
    none,
    key_down,
    pointer,
};

pub const Event = union(EventType) {
    none: void,
    key_down: struct {
        keyCode: u16,
        scanCode: u16,
        ctrl: bool = false,
        esc: bool = false,
        enter: bool = false,
        up: bool = false,
        down: bool = false,
        left: bool = false,
        right: bool = false,
    },
    pointer: struct {
        left: bool = false,
        right: bool = false,
        x: f32 = 0,
        y: f32 = 0,
    },
};

pub const SlideResult = enum {
    running,
    /// If set, the slide manager will automatically move on the next slide in the list.
    finished,
};

fn createPointerBitmap(alloc: std.mem.Allocator) !drawing.Bitmap {
    const pointer_plot: [8][8]u8 = .{
        [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0 },
        [_]u8{ 1, 2, 2, 2, 2, 1, 0, 0 },
        [_]u8{ 1, 2, 2, 2, 1, 0, 0, 0 },
        [_]u8{ 1, 2, 2, 2, 1, 0, 0, 0 },
        [_]u8{ 1, 2, 1, 1, 2, 1, 0, 0 },
        [_]u8{ 1, 1, 0, 0, 1, 2, 1, 0 },
        [_]u8{ 1, 0, 0, 0, 0, 1, 2, 1 },
        [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1 },
    };

    const bitmap = try drawing.bitmapCreate(alloc, 8, 8);
    drawing.drawPlotToBitmap(8, 8, 3, bitmap, pointer_plot, [_]drawing.Pixel{ Colors.transparent, defaultStyle.outline_color, defaultStyle.fg_color });
    return bitmap;
}

var pointerBitmap: drawing.Bitmap = .empty;

fn slideBasicPointer(state: *State, td: f32) SlideResult {
    _ = td;
    const pointer_size = 24;

    if (state.firstFrame) {
        drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);

        _ = drawing.drawStringOutlined(
            state.backbuffer,
            1 * state.unit,
            1 * state.unit,
            drawing.Colors.transparent,
            defaultStyle.fg_color,
            defaultStyle.outline_color,
            2,
            @intFromFloat(state.unit * 2),
            "Example: SimplePointerProtocol",
        );

        if (pointerBitmap.width > 0) {
            pointerBitmap.free(uefi.pool_allocator);
        }

        state.console.write("Recreating pointer", .{});
        pointerBitmap = createPointerBitmap(uefi.pool_allocator) catch unreachable;
        drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + pointer_size, state.pointerPos.y + pointer_size);
    }

    // Slide specific event handling
    if (state.event) |event| switch (event) {
        // Handle pointer event
        .pointer => |p| {
            drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + pointer_size, state.pointerPos.y + pointer_size);
            state.pointerPos.x = std.math.clamp(state.pointerPos.x + p.x, 0, state.backbuffer.width - pointer_size);
            state.pointerPos.y = std.math.clamp(state.pointerPos.y + p.y, 0, state.backbuffer.height - pointer_size);
            drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + pointer_size, state.pointerPos.y + pointer_size);
        },
        // Ignore all others
        else => {},
    };

    return .running;
}

fn slideShaderSineWave(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderSineWaveStripes, state.backbuffer, state.globalT * 3);
    return .running;
}

fn slideShaderCheckerboard(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderCheckerboard, state.backbuffer, state.globalT * 3);
    return .running;
}

fn slideShaderRadialPlasma(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderRadialPlasma, state.backbuffer, state.globalT * 3);
    return .running;
}

// TODO: Have slides be able to return a state to e.g. auto-transition
// fn animateBoxEdge(state: *State, t: f32, td: f32) void {
//     // _ = td;
//     // drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
//     // const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(t))));

//     // _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, size, "Slide 1");
// }

pub const Box = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const Style = struct {
    fg_color: drawing.Pixel,
    bg_color: drawing.Pixel,
    outline_color: drawing.Pixel,
};

const Button = struct {
    id: u32, // globally unique id, used e.g. to detect tab-activity
    box: Box = .{ .x = 0, .y = 0, .w = 100, .h = 100 },
    text: []u8 = "unknown",
    style: Style,
    active_style: Style, // on tab active or mouse over
};

// var guiExampleButtons: std.ArrayList(Button) = .empty;

// // Returns true on click
// fn button(button: Button, state: *State) bool {

// }

// fn slideGuiExample(state: *State, td: f32) SlideResult {
//     // immediate mode style?
// }

fn slideWhereToNow(state: *State, td: f32) SlideResult {
    _ = state;
    _ = td;

    return .running;
}

fn slideQuestions(state: *State, td: f32) SlideResult {
    _ = td;

    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);
    const string = "Questions?";
    const text_size: u16 = @intFromFloat(@round(5 * state.unit));

    const stringLength = drawing.textWidth(string, text_size);

    // TODO: have float up and down? Sine?
    _ = drawing.drawStringOutlined(
        state.backbuffer,
        (state.backbuffer.width - stringLength) / 2,
        ((state.backbuffer.height - text_size) / 2) - 4 * state.unit * @sin(2 * state.globalT),
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0.2 * state.unit,
        text_size,
        string,
    );

    return .running;
}

var finalQrBitmap = drawing.Bitmap.empty;
fn slideFinal(state: *State, td: f32) SlideResult {
    // Shows the final slide: QR to repo + final greeting
    _ = td;

    if (state.firstFrame) {
        finalQrBitmap = drawing.bitmapCreate(uefi.pool_allocator, 33, 33) catch unreachable;
        drawing.drawPlotToBitmap(
            33,
            33,
            2,
            finalQrBitmap,
            @import("talk-slides/slideIntro.zig").qr_plot,
            [2]drawing.Pixel{ defaultStyle.bg_color, defaultStyle.fg_color },
        );
    }

    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        2 * state.unit,
        20 * state.unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0.2 * state.unit,
        @intFromFloat(@round(5 * state.unit)),
        "That's all,\nfolks!",
    );

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        2 * state.unit,
        40 * state.unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0.2 * state.unit,
        @intFromFloat(@round(3 * state.unit)),
        "Now go do\nsomething fun!",
        // g̵o̵o̵d̵
    );

    drawing.bltBitmapScaled(
        state.backbuffer,
        finalQrBitmap,
        60 * state.unit,
        20 * state.unit,
        95 * state.unit,
        55 * state.unit,
    );

    return .running;
}

inline fn toF32(value: anytype) f32 {
    return @floatFromInt(value);
}

/// Stores retrieved instances to the separate protocols we are interested to check event data for
const ProtocolInstances = struct {
    simpleTextInputEx: ?*uefi.protocol.SimpleTextInputEx = null,
    simpleTextInput: ?*uefi.protocol.SimpleTextInput = null,
    simplePointer: ?*uefi.protocol.SimplePointer = null,
};

/// Will check any relevant events and provide a normalized, easily actionable definition
/// Currently a quite raw normalization - intended to allow the slide handlers to implement their own logics
/// In a proper system this step would likely normalize events to high level application actions
fn checkEvents(state: *State, events: []const uefi.Event, instances: *const ProtocolInstances) Event {
    const result = uefi.system_table.boot_services.?.waitForEvent(events) catch {
        // TODO: accept state so we can write info to console?
        state.console.write("Failed to wait for event", .{});
        return .{ .none = {} };
    };

    const event_idx = result.@"1";
    switch (event_idx) {
        // Checking first for simpleTextInputEx (as it has more details), falls back to simpleTextInput
        0 => {
            if (instances.simpleTextInputEx) |stix| {
                const key = stix.readKeyStroke() catch {
                    state.console.write("stix.readKeyStroke() error", .{});
                    return .{ .none = {} };
                };

                return .{ .key_down = .{
                    .keyCode = key.input.unicode_char,
                    .scanCode = key.input.scan_code,
                    .ctrl = key.state.shift.left_control_pressed or key.state.shift.left_logo_pressed or key.state.shift.left_alt_pressed or key.state.shift.right_control_pressed or key.state.shift.right_logo_pressed or key.state.shift.right_alt_pressed,
                    .esc = key.input.scan_code == 23,
                    .enter = key.input.unicode_char == 13,
                } };
            } else if (instances.simpleTextInput) |sti| {
                const key = sti.readKeyStroke() catch {
                    state.console.write("sti.readKeyStroke() error", .{});
                    return .{ .none = {} };
                };
                return .{ .key_down = .{
                    .keyCode = key.unicode_char,
                    .scanCode = key.scan_code,
                    .esc = key.scan_code == 23,
                } };
            }
            return .{ .none = {} };
        },
        // Checks for SimplePointer
        1 => {
            // pointer
            if (instances.simplePointer) |sp| {
                const key = sp.getState() catch {
                    state.console.write("sp.getState() error", .{});
                    return .{ .none = {} };
                };

                return .{ .pointer = .{
                    .left = key.left_button,
                    .right = key.right_button,
                    .x = 4.0 * toF32(key.relative_movement_x) / toF32(sp.mode.resolution_x),
                    .y = 4.0 * toF32(key.relative_movement_y) / toF32(sp.mode.resolution_y),
                } };
            }
            return .{ .none = {} };
        },
        // Do nothing - this is the animation timer
        2 => {
            return .{ .none = {} };
        },
        else => {
            return .{ .none = {} };
        },
    }
}

/// TBD: Rewrite to play well with the main render loop?
fn slideSelectRes(state: *State, td: f32) SlideResult {
    const boot_services = uefi.system_table.boot_services.?;
    _ = td;

    // Query modes
    // Look up handlers for all devices of gfxout protocol
    const gfx_out_handlers: []uefi.Handle = @ptrCast(boot_services.locateHandleBuffer(.{ .by_protocol = &uefi.protocol.GraphicsOutput.guid }) catch null orelse unreachable);

    var scratch8: [128]u8 = undefined;
    var mode_idx: u32 = 0;
    var device_idx: usize = 0;
    var screen = drawing.Bitmap.empty;
    blk: while (true) {
        // Get first graphics protocol and set first mode to get any display
        // Open protocol by handler
        const gfx_out = boot_services.openProtocol(uefi.protocol.GraphicsOutput, gfx_out_handlers[device_idx], .{ .by_handle_protocol = .{} }) catch null orelse unreachable;
        gfx_out.setMode(mode_idx) catch unreachable;
        screen = drawing.bitmapFromScreenbuffer(gfx_out);
        drawing.bitmapFill(screen, drawing.Colors.black);
        // TOOD: support formatting and newline
        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(1 * 16),
            drawing.Colors.transparent,
            drawing.Colors.white,
            16,
            std.fmt.bufPrint(&scratch8, "L/R to iterate device\nU/D to iterate mode\nEnter when OK.", .{}) catch "...",
        );

        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(9 * 16),
            drawing.Colors.transparent,
            drawing.Colors.white,
            16,
            std.fmt.bufPrint(&scratch8, "Device: {d}/{d}, Mode: {d}/{d} - {d}x{d}", .{ device_idx + 1, gfx_out_handlers.len, mode_idx + 1, gfx_out.mode.max_mode, gfx_out.mode.info.horizontal_resolution, gfx_out.mode.info.vertical_resolution }) catch "...",
        );

        _ = boot_services.waitForEvent(@as([]const uefi.Event, @ptrCast(&uefi.system_table.con_in.?.wait_for_key))) catch continue;
        const key = uefi.system_table.con_in.?.readKeyStroke() catch continue;
        switch (key.scan_code) {
            1 => { // up?
                mode_idx = if (mode_idx > 0) mode_idx - 1 else 0;
            },
            2 => { // down?
                mode_idx = std.math.clamp(mode_idx + 1, 0, gfx_out.mode.max_mode - 1);
            },
            3 => { // right
                device_idx = std.math.clamp(device_idx + 1, 0, gfx_out_handlers.len - 1);
                mode_idx = 0;
            },
            4 => { // left
                device_idx = if (device_idx > 0) device_idx - 1 else 0;
                mode_idx = 0;
            },
            else => {},
        }

        switch (key.unicode_char) {
            13, 'c' => { // enter, c=continue
                break :blk;
            },
            else => {},
        }
    }

    state.screen = screen;
    // TODO: free previous backbuffer
    if (state.backbuffer.width > 0) {
        state.backbuffer.free(uefi.pool_allocator);
    }
    state.backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable;
    state.unit = screen.width / 100;

    return .finished;
}

/// Main entry point - allocates all main resources, multiple levels of bitmaps for lowres rendering and backbuffer handling.
/// Sets up all event handling and implemnts basically a game loop: check events -> update state -> render
/// Each "slide" is responsible for putting the state.backbuffer in the desired state, then the main loop is responsible for transferring it to the video buffer
pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse unreachable;

    // TODO: initiate with gfx selector

    // Setup drawing
    const gfx_out = boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);

    var state: State = .{
        .lowres = drawing.bitmapCreate(uefi.pool_allocator, 320, 240) catch unreachable,
        .backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable,
        .screen = screen,
        .pointerPos = .{ .x = 100, .y = 100 },
        .unit = @floor(screen.width / 100),
        // .showDebugConsole = false,
        .slideIdx = 0,
    };

    state.console.write("screen: {d}x{d} ({d} stride)", .{ screen.width, screen.height, screen.stride });

    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);

    // Setup all event listeners
    // TODO: Limitation when having a time: it's prioritized over e.g. key-events from SimpleTextInput, thus if the frame randering takes longer time than the timeout it will
    const fps = 30;
    const loopEvent = boot_services.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    // Hacketihack: Fallback event used to fill up event-table entries for protocols not found. TBD: verify if OK solution.
    const dummyEvent = boot_services.createEvent(.{ .timer = false }, .{ .function = null }) catch unreachable;
    boot_services.setTimer(loopEvent, .periodic, 10_000_000 / fps) catch unreachable;

    var events_buf: [10]uefi.Event = undefined;
    // We need strict known locations for each event type to properly process it later
    // 0: keyboard
    // 1: mouse <-- may not be available -
    // 2: timer
    var protocolInstances: ProtocolInstances = .{};
    const events = blk: {
        var event_idx: usize = 0;

        // TBD: replace with Ex?
        // events_buf[event_idx] = uefi.system_table.con_in.?.wait_for_key;
        if (utils.getFirstOfProtocolOptimistic(uefi.protocol.SimpleTextInputEx)) |stie| {
            protocolInstances.simpleTextInputEx = stie;
            events_buf[event_idx] = stie.wait_for_key_ex;
            state.console.write("Found SimpleTextInputEx", .{});
        } else {
            protocolInstances.simpleTextInput = uefi.system_table.con_in.?;
            events_buf[event_idx] = uefi.system_table.con_in.?.wait_for_key;
            state.console.write("Fallback to SimpleTextInput", .{});
        }

        event_idx += 1;

        // Check for pointer, which may or may not be avaiable
        if (utils.getFirstOfProtocolOptimistic(uefi.protocol.SimplePointer)) |spp| {
            protocolInstances.simplePointer = spp;
            state.console.write("Found pointer", .{});
            events_buf[event_idx] = spp.wait_for_input;
        } else {
            state.console.write("Fallback pointer", .{});
            events_buf[event_idx] = dummyEvent;
        }
        event_idx += 1;

        // Loop timer must be last as lower indexed events will have precedence
        events_buf[event_idx] = loopEvent;
        event_idx += 1;

        state.console.write("Registered {d} events", .{event_idx});

        break :blk events_buf[0..event_idx];
    };

    // Setup slides
    state.slideIdx = 0;
    state.firstFrame = true;

    var show_debug: bool = false;

    // We don't check actual time, we assume each step is the target framerate interval
    const td = 1.0 / @as(f32, @floatFromInt(fps)); // *hackety-hack*

    state.console.write("unit: {d}", .{state.unit});
    state.console.write("Starting main loop", .{});

    // "Game loop"
    while (true) {
        // Event handling
        // Take a normalized event and pay it forward
        const event = checkEvents(&state, events[0..], &protocolInstances);
        if (event != .none) {
            state.console.write("event: {}", .{event});
            state.event = event;
        } else {
            state.event = null;
        }

        // TBD: Make event into action? e.g. .slide_next, .slide_prev, .quit
        // Global event handling, regardless of active slide
        switch (event) {
            .key_down => |k| {
                if (k.ctrl or !k.ctrl) {
                    switch (k.keyCode) {
                        'd' => show_debug = !show_debug,
                        'b' => {
                            if (state.slideIdx > 0) {
                                state.slideIdx -= 1;
                            }
                            state.firstFrame = true;
                            state.frameT = 0;
                        },
                        'f' => {
                            if (state.slideIdx < slides.len - 1) {
                                state.slideIdx += 1;
                            }
                            state.firstFrame = true;
                            state.frameT = 0;
                        },
                        'l' => {
                            // toggle theme
                            defaultStyle = if (defaultStyle == &themeDark) &themeLight else &themeDark;
                            state.firstFrame = true;
                        },
                        'q' => {
                            break;
                        },
                        else => {},
                    }
                }
            },
            else => {},
        }

        state.globalT += td;
        state.frameT += td;

        // Update state - including the backbuffer
        const slideResult = slides[state.slideIdx](&state, td);
        state.firstFrame = false;

        // Change slide logics - placeholder
        switch (slideResult) {
            .running => {},
            .finished => {
                state.slideIdx += 1;
                state.firstFrame = true;
                state.frameT = 0;
            },
        }
        // Render debug console
        if (show_debug) {
            state.console.render(state.backbuffer, .{
                .x = 10,
                .w = state.backbuffer.width - 20,
                .y = state.backbuffer.height - state.backbuffer.height / 2,
                .h = state.backbuffer.height / 2,
            }, @intFromFloat(state.backbuffer.width / 100));
        }

        // Render to screen
        drawing.bltToScreen(gfx_out, state.backbuffer, 0, 0);
    }

    return .success;
}
