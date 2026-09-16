const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");
const DebugConsole = @import("talk-slides/debug-console.zig").DebugConsole;
const Shaders = @import("lib/shaders.zig");

// Default colors to allow easy theming
const background_color = drawing.Colors.white;
const foreground_color = drawing.Colors.black;
const outline_color = drawing.Pixel{ .int = 0xffcccccc };

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
        [_]u8{ 1, 1, 1, 1, 1, 1, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 0, 0, 0 },
        [_]u8{ 1, 1, 1, 1, 1, 1, 0, 0 },
        [_]u8{ 1, 1, 0, 0, 1, 1, 1, 0 },
        [_]u8{ 1, 0, 0, 0, 0, 1, 1, 1 },
        [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1 },
    };

    const bitmap = try drawing.bitmapCreate(alloc, 8, 8);
    drawing.drawPlotToBitmap(8, 8, 2, bitmap, pointer_plot, [2]drawing.Pixel{ drawing.Colors.transparent, drawing.Colors.white });
    return bitmap;
}

var pointerBitmap: drawing.Bitmap = undefined;

fn slideBasicPointer(state: *State, td: f32) SlideResult {
    _ = td;
    const pointer_size = 24;

    if (state.firstFrame) {
        drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
        // const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(state.globalT))));

        _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, @intFromFloat(state.unit * 1.5), "Pointer");

        pointerBitmap = createPointerBitmap(uefi.pool_allocator) catch unreachable;
        drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + 24, state.pointerPos.y + 24);
    }

    // Slide specific event handling
    if (state.event) |event| switch (event) {
        // Handle pointer event
        .pointer => |p| {
            drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + pointer_size, state.pointerPos.y + pointer_size);
            state.pointerPos.x = std.math.clamp(state.pointerPos.x + p.x, 0, state.backbuffer.width - pointer_size);
            state.pointerPos.y = std.math.clamp(state.pointerPos.y + p.y, 0, state.backbuffer.height - pointer_size);
            drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + 24, state.pointerPos.y + 24);
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
    fg: drawing.Pixel,
    bg: drawing.Pixel,
    border: drawing.pixel,
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

fn slideFinal(state: *State, td: f32) SlideResult {
    // Shows the final slide: QR to repo + final greeting
    _ = state;
    _ = td;
}

fn toF32(value: anytype) f32 {
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
                    .x = 2.0 * toF32(key.relative_movement_x) / toF32(sp.mode.resolution_x),
                    .y = 2.0 * toF32(key.relative_movement_y) / toF32(sp.mode.resolution_y),
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

const slides = [_]*const fn (*State, f32) SlideResult{
    @import("talk-slides/slideIntro.zig").slide,
    @import("talk-slides/slide1.zig").slide,
    slideBasicPointer,
    slideShaderCheckerboard,
    slideShaderRadialPlasma,
    slideShaderSineWave,
};

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

    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);

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
