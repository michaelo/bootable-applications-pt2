const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");
const DebugConsole = @import("talk-slides/debug-console.zig").DebugConsole;
const Shaders = @import("talk-slides/shader-tests.zig");

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const State = struct {
    console: DebugConsole(20) = .{
        .bg = drawing.Colors.white,
        .fg = drawing.Colors.black,
    },
    activeElement: u32 = 0, // Used e.g. for tab activity
    lowres: drawing.Bitmap,
    backbuffer: drawing.Bitmap,
    screen: drawing.Bitmap,
    // showDebugConsole: bool = false,
    globalT: f32 = 0,
    frameT: f32 = 0,
    slideIdx: usize = 0,
    firstFrame: bool = false,
    // displaySize: Vector2 = .{ 0, 0 },
    pointerPos: Vector2 = .{ .x = 0, .y = 0 },
    event: ?Event = null,
    // rendermode: scale up | backbuffer | raw (assumes screen is directly manipulated, do nothing)
};

pub const EventType = enum {
    none,
    key_down,
    // key_up,
    // pointer_down,
    // pointer_up,
    // pointer_move,
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
    // Currently not solved. May not be possible without proper driver
    // key_up: struct {
    //     keyCode: u16,
    // },
    // TBD: not have point down/up/move as separate events, but part of a common pointer?
    // pointer_down: void,
    // pointer_up: void,
    pointer: struct {
        left: bool = false,
        right: bool = false,
        x: f32 = 0,
        y: f32 = 0,
    },
};

pub const SlideResult = enum {
    running,
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

fn slide2(state: *State, td: f32) SlideResult {
    _ = td;
    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
    const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(state.globalT))));

    _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, size, "Slide 2");

    if (state.firstFrame) {
        pointerBitmap = createPointerBitmap(uefi.pool_allocator) catch unreachable;
        drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + 24, state.pointerPos.y + 24);
    }

    // Handle pointer
    if (state.event) |event| {
        switch (event) {
            .pointer => |p| {
                drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + 24, state.pointerPos.y + 24);
                state.pointerPos.x += p.x;
                state.pointerPos.y += p.y;
                drawing.bltBitmapXor(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + 24, state.pointerPos.y + 24);
            },
            else => {},
        }
    }

    return .running;
}

fn slideShader(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderShader(state.lowres, state.globalT, Shaders.shaderRadialPlasma);
    drawing.bltBitmapScaled(state.backbuffer, state.lowres, 0, 0, state.backbuffer.width, state.backbuffer.height);
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

/// Will check any relevant events and provide a normalized, easily actionable definition
/// Currently a quite raw normalization - intended to allow the slide handlers to implement their own logics
/// In a proper system this step would likely normalize events to high level application actions
const ProtocolInstances = struct {
    simpleTextInputEx: ?*uefi.protocol.SimpleTextInputEx = null,
    simpleTextInput: ?*uefi.protocol.SimpleTextInput = null,
    simplePointer: ?*uefi.protocol.SimplePointer = null,
};

fn checkEvents(state: *State, events: []const uefi.Event, instances: *const ProtocolInstances) Event {
    const result = uefi.system_table.boot_services.?.waitForEvent(events) catch {
        // TODO: accept state so we can write info to console?
        state.console.write("Failed to wait for event", .{});
        return .{ .none = {} };
    };

    const event_idx = result.@"1";
    switch (event_idx) {
        0 => {
            if (instances.simpleTextInputEx) |stix| {
                const key = stix.readKeyStroke() catch {
                    state.console.write("stix.readKeyStroke() error", .{});
                    return .{ .none = {} };
                };
                // Uncomment this to show more info of the incoming data
                // state.console.write("key: scan: {d}, unicode: {d}, ctrl: {}, shift: {}", .{
                //     key.input.scan_code,
                //     key.input.unicode_char,
                //     key.state.shift.left_control_pressed,
                //     key.state.shift.shift_state_valid,
                // });
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
                    .x = toF32(key.relative_movement_x) / toF32(sp.mode.resolution_x) * 5,
                    .y = toF32(key.relative_movement_y) / toF32(sp.mode.resolution_y) * 5,
                } };
            }
            return .{ .none = {} };
        },
        2 => {
            // animation frame timer
            return .{ .none = {} };
        },
        else => {
            return .{ .none = {} };
        },
    }

    // return .{ .none = {} };
}

var title_bitmap: drawing.Bitmap = .empty;
fn slideIntro(state: *State, td: f32) SlideResult {
    _ = td;
    if (state.firstFrame) {
        title_bitmap = drawing.bitmapCreate(uefi.pool_allocator, drawing.textWidth("Applications", 48), 130) catch unreachable;
        drawing.bitmapFill(title_bitmap, drawing.Colors.black);
        _ = drawing.drawStringOutlined(title_bitmap, 12, 2, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.white, 2, 48, "Bootable");
        _ = drawing.drawStringOutlined(title_bitmap, 2, 48, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.white, 2, 48, "Applications");
        _ = drawing.drawStringOutlined(title_bitmap, 2, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.white, 1, 16, "- fully interactive programs");
        // _ = drawing.drawStringOutlined(title_bitmap, 32, 120, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.white, 2, 16, "programs");
    }

    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
    drawing.bltBitmapScaled(state.backbuffer, title_bitmap, 10, 10, 550, 280);
    return .running;
}

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
        // .showDebugConsole = false,
        .slideIdx = 0,
    };

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
    const slides = [_]*const fn (*State, f32) SlideResult{
        slideShader,
        slideIntro,
        @import("talk-slides/slide1.zig").slide,
        slide2,
    };

    var show_debug: bool = false;

    // "Game loop"
    while (true) {
        // Event handling
        // Take a normalized event and pay it forward
        const event = checkEvents(&state, events[0..], &protocolInstances);
        if (event != .none) {
            state.console.write("event: {}", .{event});
            state.console.write("...", .{});
            state.event = event;
        }
        // TODO: Make event into action? e.g. .slide_next, .slide_prev, .quit
        switch (event) {
            .key_down => |k| {
                if (k.ctrl) {
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

        const td = 1.0 / 30.0; // *hackety-hack*
        state.globalT += td;
        state.frameT += td;

        // Update state
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
                .x = 0,
                .w = state.backbuffer.width,
                .y = state.backbuffer.height - state.backbuffer.height / 2,
                .h = state.backbuffer.height / 2,
            }, @intFromFloat(state.backbuffer.width / 100));
        }

        // Render to screen
        drawing.bltToScreen(gfx_out, state.backbuffer, 0, 0);
    }
    utils.hangForKey(13);

    return .success;
}
