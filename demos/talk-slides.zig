/// Example used for presentation. Composes demontrationable featres together in a slide-deck / game loop
/// Lot's of explorative scaffolding, not intended as a learnin case. More cohesive examples will be
/// factored out from this as they are uncovered.
///
/// Read at your own risk
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");
const DebugConsole = @import("talk-slides/debug-console.zig").DebugConsole;
const Shaders = @import("lib/shaders.zig");
const slideGenericImage = @import("talk-slides/slideGenericImage.zig").createSlide;

const Pixel = drawing.Pixel;
const Colors = drawing.Colors;

// TODO: Standardize structure and organization
const slides = [_]*const fn (*State, f32) SlideResult{
    @import("talk-slides/slideIntro.zig").slide,
    slidePrompt("We are live!", 0.2),
    slideSelectRes,
    // slideTitleAndText("Code example", @embedFile("./gfx.zig"), .{
    //     .text_scale = 1,
    // }),
    slideTitleAndText("Controls",
        \\ enter - next
        \\     b - back
        \\ mouse - mouse
        \\ i/j/k/l + i/p - mouse emulation
        \\     c - toggle debug console
        \\     t - toggle theme
        \\     q - quit
    , .{}),
    @import("talk-slides/slideIntro.zig").slide,
    slidePrompt("What to expect!", 0.1),
    slideTitleAndText("Agenda",
        // \\ * Slow down
        \\ * Intro to UEFI
        \\ * The project repository
        \\ * Demos and code
        \\ * Not so much to bring home
        \\      (sorry, not sorry)
    , .{}),
    slideTitleAndText("About",
        \\ * Michael Odden - independent
        \\      developer
        \\ * Previous talk:
        \\    https://youtu.be/uW98YqvLeKo
        \\ * New this round:
        \\   * More protocols
        \\   * Compositions
        \\   * C -> Zig (not critical)
        \\   * Demos > tooling
    , .{}),
    slideTitleAndText("Brief summary",
        \\ * Unified Extensible Firmware
        \\      Interface
        \\ * Intel ~ '98
        \\ * BIOS / BSP
        \\ * 2005 -> many contributors
        \\  AMD, Apple, Arm, Nvidia, Cisco,
        \\  Qualcomm, +++
        \\ * Well specified, well supported
        \\ * https://uefi.org/ - free
        \\ * Services + Protocols
        \\ * No guarantees as to availability,
        \\   performance etc
    , .{}),
    slidePrompt("Why", 0),
    slideTitleAndText("Why",
        \\ * (Still) fun
        \\ * About trends
        \\ * Let's zag!
    , .{}),
    slidePrompt("Food for thought...\n         --->", 0),
    slideGenericImage("gfx-windows-minimal-example.bmp"),
    slideGenericImage("gfx-uefi-minimal-shrink.bmp"),
    slidePrompt("The repository", 0),
    slideGenericImage("repo-overview.bmp"),
    slideTitleAndText("Design goals",
        \\ * Playground to learn UEFI dev
        \\ * Collection of
        \\   * specific experiments
        \\   * complex apps
        \\   * higher lever libraries
        \\ * Want contributions!
        \\
        \\
        \\     "He's a developer
        \\         - he is fallible"
    , .{}),
    slidePrompt("Let's throw away\n  some code!", 0),
    slideGenericImage("notallowed.bmp"),
    slideGenericImage("process.bmp"),
    slideGenericImage("uefi-spec-introduction.bmp"),
    slideGenericImage("uefi-spec-bootingseq.bmp"),
    slideGenericImage("uefi-menu-overview.bmp"),
    // img: OS crossout
    slidePrompt("Simple text output", 0),
    // slideGenericImage("EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL doc.bmp"),
    slideGenericImage("EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL example.bmp"),
    slideGenericImage("txtout-qemu.bmp"),
    // TODO: add slide with image of spec + code
    // slidePrompt("Simple text input", 0),
    // slideGenericImage("EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL example.bmp"),
    // TODO: add slide with image of spec + code
    slidePrompt("Simple gfx output", 0),
    slideGenericImage("EFI_GRAPHICS_OUTPUT_PROTOCOL doc.bmp"),
    slideGenericImage("gfx-draw-code.bmp"),
    slideGenericImage("gfx-draw-qemu.bmp"),
    // TODO: add slide with image of spec + code
    slidePrompt("Event handling", 0),
    slideGenericImage("example-events.bmp"),
    slidePrompt("Simple pointer input", 0),
    slideGenericImage("EFI_SIMPLE_POINTER_PROTOCOL doc.bmp"),
    slideGenericImage("EFI_SIMPLE_POINTER_PROTOCOL example.bmp"),
    slideBasicPointer,
    slidePrompt("Protocols\nprotocols\nprotocols\n...", 0),
    slideGenericImage("EFI_FILE_PROTOCOL.bmp"),
    slideGenericImage("EFI_WIRELESS_MAC_CONNECTION_PROTOCOL.bmp"),
    slideGenericImage("tape.bmp"),
    slidePrompt("Compositions!", 0),
    slideTitleAndText("Custom libs in repo",
        \\ * Text rendering (8x8)
        \\ * .bmp parser
        \\ * Graphic primitives:
        \\   line, circle, rectangle, ...
        \\ * Bitmap scaling
        \\ * Convenience functions
        \\ * Debug console
    , .{}),
    slidePrompt("Read and parse file", 0),
    slideGenericImage("companion-knight-600x800.bmp"),
    slidePrompt("Rendering strategies", 0),
    slideAnimationRaw,
    slideAnimationBackbuffer,
    // slidePrompt("Hold on... (q?)", 1),
    slidePrompt("Let's put it\ntogether", 0),
    slideGuiExample,
    slidePrompt("With great power...", 0),
    slideGame,
    slidePrompt("Performance warning", 0),
    slideShaderCheckerboard,
    slideShaderRadialPlasma,
    slideShaderRadialPlasmaScaled,
    slideShaderSineWave,
    slideShaderSineWaveScaled,
    slideTitleAndText("Keep in mind",
        \\ * No multithreading
        \\ * No guarantees to feature
        \\      availability
        \\ * No guarantees to feature
        \\      performance
        \\ * Manual memory management
        \\ * Disable watchdog for long-
        \\      running apps
        \\  boot_services
        \\      .setWatchdogTimer(0, 0, null) catch {};
    , .{}),
    slidePrompt("Let's run it\nourselves (boot!)", 0),
    // Boot back into OS and showcase how to use the repository
    // Then run the app in emulation and get to the end
    slideTitleAndText("Immediate plans",
        \\ * More fonts!
        \\ * Standardize lib
        \\ * Better UI library
        \\ * 3D primitives CPU-rasterized
        \\ * Drivers - GPU, sound
        \\ * Networking
        \\ * Live debugging (lldb)
        \\ * Hot reloading?
    , .{}),
    // slideTitleAndText("Where to go?",
    //     \\ * Any input to where to go?
    //     \\   * Expand on protocols?
    //     \\      Bluetooth, networking, ...
    //     \\   * Extend on handover to
    //     \\      "proper" OS
    //     \\   * Pivot: Explore bootability
    //     \\          on other devices?
    //     \\      Mobile, Apple Silicon, etc
    //     \\   * ... ?
    //     \\
    //     \\ -- Let me know! --
    // , .{}),
    slideTitleAndText("Lessons learned",
        \\ * What UEFI is
        \\ * Basic understanding of the spec
        \\ * How to build UEFI applications
        \\ * Emulation
        \\ * Running on hardware
    , .{}),
    slidePrompt("Questions?", 1),
    slidePrompt("One more thing...", 1),
    // slideFinal,
};

const themeDark = Style{
    .fg_color = drawing.Colors.white,
    .bg_color = drawing.Colors.black,
    .outline_color = drawing.Pixel{ .int = 0xff999999 },
    .text_size = 16,
};

const themeLight = Style{
    .fg_color = drawing.Colors.black,
    .bg_color = drawing.Colors.white,
    .outline_color = drawing.Pixel{ .int = 0xffcccccc },
    .text_size = 16,
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
        .bg = drawing.Colors.gray_light,
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
    renderMode: enum { backbuffer, raw } = .backbuffer,
};

pub const EventType = enum {
    none,
    key_down,
    pointer,
};

pub const Event = union(EventType) {
    none: void,
    key_down: struct {
        enter: bool = false,
        up: bool = false,
        down: bool = false,
        keyCode: u16,
        scanCode: u16,
        left: bool = false,
        right: bool = false,
        ctrl: bool = false,
        esc: bool = false,
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

pub fn roundToNearest(v: f32, mod: i32) f32 {
    const v_int: i32 = @intFromFloat(@round(v));
    const rem = @rem(v_int, mod);
    return @floatFromInt(v_int - rem);
}

fn slideBasicPointer(state: *State, td: f32) SlideResult {
    _ = td;
    const pointer_size = roundToNearest(4 * state.unit, 8);

    if (state.firstFrame) {
        // TBD: make drawMode .raw?
        drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);

        _ = drawing.drawString(
            state.backbuffer,
            1 * state.unit,
            1 * state.unit,
            drawing.Colors.transparent,
            defaultStyle.fg_color,
            // defaultStyle.outline_color,
            // 1,
            @intFromFloat(state.unit * 3),
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

const Object = struct {
    c: Pixel,
    b: Box,
    v: Vector2,
};
var object_list: std.ArrayList(Object) = .empty;
const colors: []const Pixel = &[_]Pixel{
    Colors.red_dark,
    Colors.green_dark,
    Colors.blue_dark,
};
var color_idx: usize = 0;

fn slideAnimationRaw(state: *State, dt: f32) SlideResult {
    if (state.firstFrame) {
        state.renderMode = .raw;
    }
    const target = state.screen;
    if (state.event) |e| {
        if (e == .key_down and e.key_down.keyCode == 'a') {
            object_list.append(uefi.pool_allocator, .{
                .b = .{
                    .x = 2 * state.unit,
                    .y = 3 * state.unit,
                    .w = 3 * state.unit,
                    .h = 3 * state.unit,
                },
                .c = colors[@mod(color_idx, colors.len)],
                .v = .{
                    .x = 10 * state.unit,
                    .y = 10 * state.unit,
                },
            }) catch {};

            color_idx += 1;
        }
    }
    drawing.bitmapFill(target, defaultStyle.bg_color);
    _ = drawing.drawString(target, state.unit, state.unit, Colors.transparent, defaultStyle.fg_color, @intFromFloat(3 * state.unit), "Direct buffer. Press A");

    for (object_list.items) |*obj| {
        obj.b.x += obj.v.x * dt;
        obj.b.y += obj.v.y * dt;

        // Horizontal edge check
        if (obj.b.x < 0) {
            obj.b.x = 0;
            if (obj.v.x < 0) {
                obj.v.x *= -1;
            }
        }
        if (obj.b.x >= target.width - obj.b.w) {
            obj.b.x = target.width - obj.b.w - 1;
            if (obj.v.x > 0) {
                obj.v.x *= -1;
            }
        }

        // Vertical edge check
        if (obj.b.y < 0) {
            obj.b.y = 0;
            if (obj.v.y < 0) {
                obj.v.y *= -1;
            }
        }
        if (obj.b.y >= target.height - obj.b.h) {
            obj.b.y = target.height - obj.b.h - 1;
            if (obj.v.y > 0) {
                obj.v.y *= -1;
            }
        }

        drawing.drawBoxFilled(target, obj.b.x, obj.b.y, obj.b.w, obj.b.h, obj.c, defaultStyle.outline_color, 0);
    }

    return .running;
}

fn slideAnimationBackbuffer(state: *State, dt: f32) SlideResult {
    if (state.event) |e| {
        if (e == .key_down and e.key_down.keyCode == 'a') {
            object_list.append(uefi.pool_allocator, .{
                .b = .{
                    .x = 2 * state.unit,
                    .y = 3 * state.unit,
                    .w = 3 * state.unit,
                    .h = 3 * state.unit,
                },
                .c = colors[@mod(color_idx, colors.len)],
                .v = .{
                    .x = 10 * state.unit,
                    .y = 10 * state.unit,
                },
            }) catch {};

            color_idx += 1;
        }
    }
    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);
    _ = drawing.drawString(state.backbuffer, state.unit, state.unit, Colors.transparent, defaultStyle.fg_color, @intFromFloat(3 * state.unit), "Backbuffer. Press A");

    for (object_list.items) |*obj| {
        obj.b.x += obj.v.x * dt;
        obj.b.y += obj.v.y * dt;

        // Horizontal edge check
        if (obj.b.x < 0) {
            obj.b.x = 0;
            if (obj.v.x < 0) {
                obj.v.x *= -1;
            }
        }
        if (obj.b.x >= state.backbuffer.width - obj.b.w) {
            obj.b.x = state.backbuffer.width - obj.b.w - 1;
            if (obj.v.x > 0) {
                obj.v.x *= -1;
            }
        }

        // Vertical edge check
        if (obj.b.y < 0) {
            obj.b.y = 0;
            if (obj.v.y < 0) {
                obj.v.y *= -1;
            }
        }
        if (obj.b.y >= state.backbuffer.height - obj.b.h) {
            obj.b.y = state.backbuffer.height - obj.b.h - 1;
            if (obj.v.y > 0) {
                obj.v.y *= -1;
            }
        }

        drawing.drawBoxFilled(state.backbuffer, obj.b.x, obj.b.y, obj.b.w, obj.b.h, obj.c, defaultStyle.outline_color, 0);
    }

    return .running;
}

fn objectDraw(bitmap: drawing.Bitmap, obj: Object) void {
    drawing.drawBoxFilled(bitmap, obj.b.x, obj.b.y, obj.b.w, obj.b.h, obj.c, defaultStyle.outline_color, 0);
}
// fn objectDrawXor(bitmap: drawing.Bitmap, obj: Object) void {
//     drawing.drawBoxFilledXor(
//         bitmap,
//         obj.b.x,
//         obj.b.y,
//         obj.b.w,
//         obj.b.h,
//         Colors.white,
//     );
// }

fn objectApplyVelocity(bitmap: drawing.Bitmap, obj: *Object, dt: f32) void {
    obj.b.x += obj.v.x * dt;
    obj.b.y += obj.v.y * dt;

    // Horizontal edge check
    if (obj.b.x < 0) {
        obj.b.x = 0;
        if (obj.v.x < 0) {
            obj.v.x *= -1;
        }
    }
    if (obj.b.x >= bitmap.width - obj.b.w) {
        obj.b.x = bitmap.width - obj.b.w - 1;
        if (obj.v.x > 0) {
            obj.v.x *= -1;
        }
    }

    // Vertical edge check
    if (obj.b.y < 0) {
        obj.b.y = 0;
        if (obj.v.y < 0) {
            obj.v.y *= -1;
        }
    }
    if (obj.b.y >= bitmap.height - obj.b.h) {
        obj.b.y = bitmap.height - obj.b.h - 1;
        if (obj.v.y > 0) {
            obj.v.y *= -1;
        }
    }
}

fn isColliding(a: Box, b: Box) bool {
    return (a.x <= b.x + b.w and a.x + a.w >= b.x) and
        (a.y <= b.y + b.h and a.y + a.h >= b.y);
}

var player: Object = undefined;
var ball: Object = undefined;
var player_v: f32 = 0;
var points: i32 = 0;

fn slideGame(state: *State, td: f32) SlideResult {
    // 1 person tennis
    if (state.firstFrame) {
        player = .{
            .b = .{
                .x = 1 * state.unit,
                .y = 5 * state.unit,
                .w = 2 * state.unit,
                .h = 8 * state.unit,
            },
            .c = defaultStyle.fg_color,
            .v = .{
                .x = 0,
                .y = 0,
            },
        };
        ball = .{
            .b = .{
                .x = 49 * state.unit,
                .y = 49 * state.unit,
                .w = 2 * state.unit,
                .h = 2 * state.unit,
            },
            .c = defaultStyle.fg_color,
            .v = .{
                .x = 15 * state.unit,
                .y = 15 * state.unit,
            },
        };

        player_v = 20 * state.unit;
    }
    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);
    // _ = drawing.drawString(state.backbuffer, state.unit, state.unit, Colors.transparent, defaultStyle.fg_color, @intFromFloat(2 * state.unit), "With great power...");
    if (state.event) |e| {
        if (e == .key_down) {
            if (e.key_down.down) {
                player.v.y = player_v;
            }

            if (e.key_down.up) {
                player.v.y = -player_v;
            }
        }
    }

    objectApplyVelocity(state.backbuffer, &player, td);
    objectApplyVelocity(state.backbuffer, &ball, td);
    if (isColliding(player.b, ball.b)) {
        ball.v.x *= -1.2;
        ball.b.x = player.b.x + player.b.w;
        points += 1;
    }
    objectDraw(state.backbuffer, player);
    objectDraw(state.backbuffer, ball);
    return .running;
}

fn slideShaderSineWave(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderSineWaveStripes, state.backbuffer, state.globalT * 3);
    return .running;
}

fn slideShaderSineWaveScaled(state: *State, dt: f32) SlideResult {
    _ = dt;
    if (state.firstFrame) {
        if (shaderLowResBitmap.width > 0) {
            shaderLowResBitmap.free(uefi.pool_allocator);
            shaderLowResBitmap = .empty;
        }
        shaderLowResBitmap = drawing.bitmapCreate(uefi.pool_allocator, 640, 480) catch .empty;
    }
    Shaders.renderScalar(Shaders.shaderSineWaveStripes, shaderLowResBitmap, state.globalT * 3);
    drawing.bltBitmapScaled(state.backbuffer, shaderLowResBitmap, 0, 0, state.backbuffer.width, state.backbuffer.height);

    return .running;
}

fn slideShaderCheckerboard(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderCheckerboard, state.backbuffer, state.globalT * 3);
    return .running;
}

var shaderLowResBitmap: drawing.Bitmap = .empty;
fn slideShaderRadialPlasmaScaled(state: *State, dt: f32) SlideResult {
    _ = dt;
    if (state.firstFrame) {
        if (shaderLowResBitmap.width > 0) {
            shaderLowResBitmap.free(uefi.pool_allocator);
            shaderLowResBitmap = .empty;
        }
        shaderLowResBitmap = drawing.bitmapCreate(uefi.pool_allocator, 640, 480) catch .empty;
    }
    Shaders.renderScalar(Shaders.shaderRadialPlasma, shaderLowResBitmap, state.globalT * 3);
    drawing.bltBitmapScaled(state.backbuffer, shaderLowResBitmap, 0, 0, state.backbuffer.width, state.backbuffer.height);

    return .running;
}

fn slideShaderRadialPlasma(state: *State, dt: f32) SlideResult {
    _ = dt;
    Shaders.renderScalar(Shaders.shaderRadialPlasma, state.backbuffer, state.globalT * 3);
    return .running;
}

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
    text_size: u16,
};

const Button = struct {
    id: u32, // globally unique id, used e.g. to detect tab-activity
    box: Box = .{ .x = 0, .y = 0, .w = 100, .h = 100 },
    text: []const u8 = "unknown",
    style: Style,
    active_style: Style, // on tab active or mouse over
};

// var guiExampleButtons: std.ArrayList(Button) = .empty;

/// Returns true on click
/// TODO: Add state to button? Or keep state outside? Easy hack now: require pointer to button to store any persistent info (e.g. toggle)
fn button(bitmap: drawing.Bitmap, btn: Button, state: *State) bool {
    const pointerPos = state.pointerPos;
    const colliding = isColliding(btn.box, .{ .x = pointerPos.x, .y = pointerPos.y, .w = 1, .h = 1 });
    const style = if (colliding) btn.active_style else btn.style;

    drawing.drawBoxFilled(bitmap, btn.box.x, btn.box.y, btn.box.w, btn.box.h, style.bg_color, style.outline_color, 1);
    const len = drawing.textWidth(btn.text, style.text_size);
    _ = drawing.drawString(
        bitmap,
        btn.box.x + (btn.box.w - len) / 2,
        btn.box.y + (btn.box.h - toF32(style.text_size)) / 2,
        Colors.transparent,
        style.fg_color,
        style.text_size,
        btn.text,
    );

    if (state.event) |e| {
        return e == .pointer and e.pointer.left and colliding;
    }
    return false;
}

var slideGuiExampleButtonState: bool = false;
fn slideGuiExample(state: *State, td: f32) SlideResult {
    // immediate mode style?
    _ = td;
    const pointer_size = 2 * state.unit;
    if (state.firstFrame) {
        if (pointerBitmap.width > 0) {
            pointerBitmap.free(uefi.pool_allocator);
        }

        state.console.write("Recreating pointer", .{});
        pointerBitmap = createPointerBitmap(uefi.pool_allocator) catch unreachable;
    }

    // Slide specific event handling
    if (state.event) |event| switch (event) {
        // Handle pointer events - might move out
        .pointer => |p| {
            state.pointerPos.x = std.math.clamp(state.pointerPos.x + p.x, 0, state.backbuffer.width - pointer_size);
            state.pointerPos.y = std.math.clamp(state.pointerPos.y + p.y, 0, state.backbuffer.height - pointer_size);
        },
        // Ignore all others
        else => {},
    };

    drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);
    if (button(
        state.backbuffer,
        .{
            .style = .{
                .bg_color = defaultStyle.bg_color,
                .fg_color = defaultStyle.fg_color,
                .outline_color = defaultStyle.fg_color,
                .text_size = @intFromFloat(2 * state.unit),
            },
            .active_style = .{
                .bg_color = defaultStyle.fg_color,
                .fg_color = defaultStyle.bg_color,
                .outline_color = defaultStyle.bg_color,
                .text_size = @intFromFloat(2 * state.unit),
            },
            .id = 1,
            .box = .{
                .h = 6 * state.unit,
                .w = 20 * state.unit,
                .x = 20 * state.unit,
                .y = 20 * state.unit,
            },
            .text = "Click me!",
        },
        state,
    )) {
        // Do thing
        slideGuiExampleButtonState = !slideGuiExampleButtonState;
    }
    if (slideGuiExampleButtonState) {
        state.console.write("Clicked button!", .{});
        _ = drawing.drawStringEx(state.backbuffer, .{
            .x = state.backbuffer.width / 2,
            .y = state.backbuffer.height / 2,
        }, .{
            .bg = defaultStyle.bg_color,
            .fg = defaultStyle.fg_color,
            .text_size = 2 * state.unit,
        }, "Clicked! Yay.");
    }

    drawing.bltBitmapScaledEx(state.backbuffer, pointerBitmap, state.pointerPos.x, state.pointerPos.y, state.pointerPos.x + pointer_size, state.pointerPos.y + pointer_size);
    return .running;
}

fn slideTitleAndText(title: []const u8, text: []const u8, params: struct { title_scale: f32 = 5, text_scale: f32 = 3 }) *const fn (*State, f32) SlideResult {
    return struct {
        fn slide(state: *State, td: f32) SlideResult {
            _ = td;

            drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);

            _ = drawing.drawStringOutlined(
                state.backbuffer,
                2 * state.unit,
                3 * state.unit,
                drawing.Colors.transparent,
                defaultStyle.fg_color,
                defaultStyle.outline_color,
                0.2 * state.unit,
                @intFromFloat(roundToNearest(params.title_scale * state.unit, 8)),
                title,
            );

            _ = drawing.drawStringEx(
                state.backbuffer,
                .{
                    .x = 2 * state.unit,
                    .y = 12 * state.unit,
                },
                .{
                    .bg = drawing.Colors.transparent,
                    .fg = defaultStyle.fg_color,
                    .text_size = roundToNearest(params.text_scale * state.unit, 8),
                    .line_height_fraction = 1.5,
                },
                text,
                // defaultStyle.outline_color,
                // 0.1 * state.unit,
            );

            return .running;
        }
    }.slide;
}

fn slidePrompt(prompt: []const u8, bob_velocity: f32) *const fn (*State, f32) SlideResult {
    return struct {
        fn slide(state: *State, td: f32) SlideResult {
            _ = td;

            drawing.bitmapFill(state.backbuffer, defaultStyle.bg_color);
            const string = prompt;
            const text_size: u16 = @intFromFloat(@round(5 * state.unit));

            const stringLength = drawing.textWidth(string, text_size);

            // TODO: have float up and down? Sine?
            _ = drawing.drawStringOutlined(
                state.backbuffer,
                (state.backbuffer.width - stringLength) / 2,
                ((state.backbuffer.height - text_size) / 2) - 4 * state.unit * @sin(2 * state.globalT) * bob_velocity,
                drawing.Colors.transparent,
                defaultStyle.fg_color,
                defaultStyle.outline_color,
                0.2 * state.unit,
                text_size,
                string,
            );

            return .running;
        }
    }.slide;
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
        0.1 * state.unit,
        @intFromFloat(@round(3 * state.unit)),
        "Now go do\nsomething fun!",
        // g̵o̵o̵d̵
    );

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        2 * state.unit,
        state.backbuffer.height - 3 * state.unit,
        drawing.Colors.transparent,
        defaultStyle.fg_color,
        defaultStyle.outline_color,
        0 * state.unit,
        @intFromFloat(@round(2 * state.unit)),
        "(Press q to exit)",
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

                // Check for mouse emulation
                switch (key.input.unicode_char) {
                    'i' => {
                        return .{ .pointer = .{
                            .y = -state.unit,
                        } };
                    },
                    'j' => {
                        return .{ .pointer = .{
                            .x = -state.unit,
                        } };
                    },
                    'k' => {
                        return .{ .pointer = .{
                            .y = state.unit,
                        } };
                    },
                    'l' => {
                        return .{ .pointer = .{
                            .x = state.unit,
                        } };
                    },
                    'u' => {
                        return .{ .pointer = .{
                            .left = true,
                        } };
                    },
                    'o' => {
                        return .{ .pointer = .{
                            .right = true,
                        } };
                    },
                    else => {},
                }

                // state.console.write("e: {d} {}", .{ key.input.scan_code, key.input.scan_code == 1 });

                return .{ .key_down = .{
                    .keyCode = key.input.unicode_char,
                    .scanCode = key.input.scan_code,
                    .ctrl = key.state.shift.left_control_pressed or key.state.shift.left_logo_pressed or key.state.shift.left_alt_pressed or key.state.shift.right_control_pressed or key.state.shift.right_logo_pressed or key.state.shift.right_alt_pressed,
                    .esc = key.input.scan_code == 23,
                    .enter = key.input.unicode_char == 13,
                    .up = key.input.scan_code == 1 or key.input.unicode_char == 'w',
                    .down = key.input.scan_code == 2 or key.input.unicode_char == 's',
                    .left = key.input.scan_code == 4 or key.input.unicode_char == 'a',
                    .right = key.input.scan_code == 3 or key.input.unicode_char == 'd',
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
                    .enter = key.unicode_char == 13,
                    .up = key.scan_code == 1 or key.unicode_char == 'w',
                    .down = key.scan_code == 2 or key.unicode_char == 's',
                    .left = key.scan_code == 4 or key.unicode_char == 'a',
                    .right = key.scan_code == 3 or key.unicode_char == 'd',
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
    var mode_idx: u32 = 7; // 1024x768 on ovmf/qmeu
    var device_idx: usize = 0;
    var screen = drawing.Bitmap.empty;

    blk: while (true) {
        // Get first graphics protocol and set first mode to get any display
        // Open protocol by handler
        const gfx_out = boot_services.openProtocol(uefi.protocol.GraphicsOutput, gfx_out_handlers[device_idx], .{ .by_handle_protocol = .{} }) catch null orelse unreachable;
        gfx_out.setMode(mode_idx) catch unreachable;
        screen = drawing.bitmapFromScreenbuffer(gfx_out);
        drawing.bitmapFill(screen, defaultStyle.bg_color);

        const text_size: u16 = @intFromFloat(screen.width / 40);
        // TOOD: support formatting and newline
        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(1 * text_size),
            drawing.Colors.transparent,
            defaultStyle.fg_color,
            text_size,
            std.fmt.bufPrint(&scratch8, "L/R to iterate display device\nU/D to iterate mode\nEnter when OK.", .{}) catch "...",
        );

        _ = drawing.drawString(
            screen,
            10.0,
            @floatFromInt(9 * text_size),
            drawing.Colors.transparent,
            defaultStyle.fg_color,
            text_size,
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
    boot_services.setWatchdogTimer(0, 0, null) catch {};

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
    const fps = 60;
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
                // if (k.ctrl or !k.ctrl) {
                switch (k.keyCode) {
                    'c' => show_debug = !show_debug,
                    'b' => {
                        if (state.slideIdx > 0) {
                            state.slideIdx -= 1;
                        }
                        state.firstFrame = true;
                        state.renderMode = .backbuffer;
                        state.frameT = 0;
                    },
                    'f' => {
                        if (state.slideIdx < slides.len - 1) {
                            state.slideIdx += 1;
                        }
                        state.firstFrame = true;
                        state.renderMode = .backbuffer;
                        state.frameT = 0;
                    },
                    't' => {
                        // toggle theme
                        defaultStyle = if (defaultStyle == &themeDark) &themeLight else &themeDark;
                        state.firstFrame = true;
                    },
                    'q' => {
                        break;
                    },
                    else => {},
                }
                // Alternative next slide
                if (k.enter) {
                    if (state.slideIdx < slides.len - 1) {
                        state.slideIdx += 1;
                    }
                    state.firstFrame = true;
                    state.renderMode = .backbuffer;
                    state.frameT = 0;
                }
                // }
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
        if (state.renderMode == .backbuffer) {
            drawing.bltToScreen(gfx_out, state.backbuffer, 0, 0);
        }
    }

    return .success;
}
