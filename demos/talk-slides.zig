const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

pub const Vector2 = struct {
    x: f32,
    y: f32,
};

pub const State = struct {
    // lowres: drawing.Bitmap,
    backbuffer: drawing.Bitmap,
    screen: drawing.Bitmap,
    showDebugConsole: bool = false,
    globalT: f32 = 0,
    frameT: f32 = 0,
    slideIdx: usize = 0,
    firstFrame: bool = false,
    // displaySize: Vector2 = .{ 0, 0 },
    pointerPos: Vector2 = .{ .x = 0, .y = 0 },
    // rendermode: scale up | backbuffer | raw (assumes screen is directly manipulated, do nothing)
};

pub const EventType = enum {
    none,
    key_down,
    key_up,
    pointer_down,
    pointer_up,
    pointer_move,
};

pub const Event = union(EventType) {
    none: void,
    key_down: struct {
        keyCode: u16,
    },
    key_up: struct {
        keyCode: u16,
    },
    pointer_down: void,
    pointer_up: void,
    pointer_move: void,
};

pub const SlideResult = enum {
    running,
    finished,
};

// TODO: Create a convenient "debug console" which can be shown/hidden with a key.
// fn console(text: []const u8) void {
//     // render a textbox with whatever contents in the text buffer, makes sure to clear anything previously rendered
// }

fn slide2(state: *State, td: f32) SlideResult {
    _ = td;
    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
    const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(state.globalT))));

    _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, size, "Slide 2");
    return .running;
}

// TODO: Have slides be able to return a state to e.g. auto-transition
// fn animateBoxEdge(state: *State, t: f32, td: f32) void {
//     // _ = td;
//     // drawing.bitmapFill(state.backbuffer, drawing.Colors.black);
//     // const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(t))));

//     // _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, size, "Slide 1");
// }

/// Will check any relevant events and provide a normalized, easily actionable definition
/// TODO: return both the current event as well as composite state?
fn checkEvents(events: []const uefi.Event) Event {
    const result = uefi.system_table.boot_services.?.waitForEvent(events) catch unreachable;
    // const event = result.@"0";
    const event_idx = result.@"1";
    switch (event_idx) {
        0 => {
            // animation frame timer
            return .{ .none = {} };
        },
        1 => {
            // key
            // const key = uefi.protocol.SimpleTextInputEx.registerKeyNotify(self: *SimpleTextInputEx, key_data: *const Key, notify: *const fn (*const Key) Status) .readKeyStroke() catch unreachable;
            const key = uefi.system_table.con_in.?.readKeyStroke() catch unreachable;

            return .{ .key_down = .{
                .keyCode = key.unicode_char,
            } };
        },
        else => {
            return .{ .none = {} };
        },
    }

    // return .{ .none = {} };
}

pub fn main() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse unreachable;
    const fps = 30;

    // TODO: initiate with gfx selector

    // Setup drawing
    const gfx_out = boot_services.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;
    const screen = drawing.bitmapFromScreenbuffer(gfx_out);

    var state: State = .{
        .backbuffer = drawing.bitmapCreate(uefi.pool_allocator, screen.width, screen.height) catch unreachable,
        .screen = screen,
        .pointerPos = .{ .x = 100, .y = 100 },
        .showDebugConsole = false,
        .slideIdx = 0,
    };

    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);

    // Setup all event listeners
    const loopEvent = boot_services.createEvent(.{ .timer = true }, .{ .function = null }) catch unreachable;
    boot_services.setTimer(loopEvent, .periodic, 10000000 / fps) catch unreachable;
    const events = [_]uefi.Event{
        loopEvent,
        uefi.system_table.con_in.?.wait_for_key,
        // TODO: pointer
    };

    // Setup slides
    state.slideIdx = 0;
    state.firstFrame = true;
    const slides = [_]*const fn (*State, f32) SlideResult{
        @import("talk-slides/slide1.zig").slide, slide2,
    };

    // "Game loop"
    while (true) {
        // Event handling
        // Take a normalized event and pay it forward
        const event = checkEvents(events[0..]);
        // TODO: Make event into action? e.g. .slide_next, .slide_prev, .quit
        switch (event) {
            .key_down => |k| {
                // TODO: support/require modifiers, such as ctrl+
                switch (k.keyCode) {
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

        // Render to screen
        drawing.blitToScreen(gfx_out, state.backbuffer, 0, 0);
    }
    utils.hangForKey(13);

    return .success;
}
