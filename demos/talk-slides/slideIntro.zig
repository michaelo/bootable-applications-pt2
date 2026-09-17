const std = @import("std");
const uefi = std.os.uefi;
const main = @import("../talk-slides.zig");

const utils = @import("../lib/utils.zig");
const drawing = @import("../lib/drawing.zig");

// https://github.com/michaelo/bootable-applications-pt2
pub const qr_plot: [33][33]u8 = .{
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1 },
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 },
    [_]u8{ 1, 0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1 },
    [_]u8{ 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0 },
    [_]u8{ 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 0 },
    [_]u8{ 1, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0, 0, 0 },
    [_]u8{ 0, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0 },
    [_]u8{ 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0 },
    [_]u8{ 1, 0, 1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1 },
    [_]u8{ 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 1 },
    [_]u8{ 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0 },
    [_]u8{ 1, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0 },
    [_]u8{ 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0 },
    [_]u8{ 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1 },
    [_]u8{ 1, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 1, 0 },
    [_]u8{ 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0 },
    [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 1 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 0 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 0, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 1, 1, 1 },
    [_]u8{ 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0 },
    [_]u8{ 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0 },
    [_]u8{ 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0 },
};

const SlideIntroData = struct {
    title_bitmap: drawing.Bitmap = .empty,
    x: f32 = 0,
    y: f32 = 0,
    qr_bitmap: drawing.Bitmap = .empty,
};
var slideIntroData = SlideIntroData{};
pub fn slide(state: *main.State, td: f32) main.SlideResult {
    _ = td;
    drawing.bitmapFill(state.backbuffer, main.defaultStyle.bg_color);

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        8 * state.unit,
        1 * state.unit,
        drawing.Colors.transparent,
        main.defaultStyle.fg_color,
        main.defaultStyle.outline_color,
        2,
        @intFromFloat(7 * state.unit),
        "Bootable",
    );
    // state.console.write("Bootable: {d},{d}. Width: {d}", .{ 5 * state.unit, 1 * state.unit, w1 });

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        5 * state.unit,
        7 * state.unit,
        drawing.Colors.transparent,
        main.defaultStyle.fg_color,
        main.defaultStyle.outline_color,
        2,
        @intFromFloat(7 * state.unit),
        "Applications",
    );
    // state.console.write("Applications: {d},{d}. Width: {d}", .{ 1 * state.unit, 6.5 * state.unit, w2 });

    _ = drawing.drawStringOutlined(
        state.backbuffer,
        5 * state.unit,
        14.5 * state.unit,
        drawing.Colors.transparent,
        main.defaultStyle.fg_color,
        main.defaultStyle.outline_color,
        1,
        @intFromFloat(3 * state.unit),
        "- fully interactive programs",
    );

    if (state.firstFrame) {
        if (slideIntroData.qr_bitmap.width != 0) {
            // TODO: wrap allocator in state - potentially as arena
            slideIntroData.qr_bitmap.free(uefi.pool_allocator);
        }
        slideIntroData.qr_bitmap = drawing.bitmapCreate(uefi.pool_allocator, 33, 33) catch unreachable;
        drawing.drawPlotToBitmap(33, 33, 2, slideIntroData.qr_bitmap, qr_plot, [2]drawing.Pixel{ main.defaultStyle.bg_color, main.defaultStyle.fg_color });
        // TBD: Scale up bitmap so we only need to blt later?
    }

    drawing.bltBitmapScaled(
        state.backbuffer,
        slideIntroData.qr_bitmap,
        60 * state.unit,
        state.backbuffer.height - 40 * state.unit,
        95 * state.unit,
        state.backbuffer.height - 5 * state.unit,
    );

    // state.console.write("fully etc: {d},{d}. Width: {d}", .{ 1 * state.unit, 13 * state.unit, w3 });
    // }

    // TODO: Support passing rendering sizes/areas a unions of pos+size as well as start-end coordinate pairs
    // drawing.bltBitmapScaled(state.backbuffer, title_bitmap, state.unit, state.unit, 91 * state.unit, 21 * state.unit);
    // drawing.drawCircle(state.backbuffer, slideIntroData.x, slideIntroData.y, state.unit, state.unit, drawing.Colors.green);
    // const box_size = 4 * state.unit;
    // drawing.drawBox(state.backbuffer, slideIntroData.x, slideIntroData.y, box_size, box_size, drawing.Colors.green, 1);
    // // _ = td;
    // slideIntroData.x = std.math.clamp(slideIntroData.x + td * 160, 0, state.backbuffer.width - box_size);
    // slideIntroData.y = std.math.clamp(slideIntroData.y + td * 80, 0, state.backbuffer.height - box_size);
    // state.console.write("c: {}, {}", .{ slideIntroData.x, slideIntroData.y });
    return .running;
}
