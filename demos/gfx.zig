/// Showcases basic
const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");
const drawing = @import("lib/drawing.zig");

const BltPixel = uefi.protocol.GraphicsOutput.BltPixel;

pub fn main() uefi.Status {
    const white: BltPixel = .{ .blue = 255, .green = 255, .red = 255, .reserved = 255 };
    const red: BltPixel = .{ .blue = 0, .green = 0, .red = 255, .reserved = 255 };

    var gfx_out = uefi.system_table.boot_services.?
        .locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;

    // Enable first available display mode
    gfx_out.setMode(0) catch unreachable;

    // Create a pointer to a single color we will blit unto the entire display buffer
    // Fill entire screen with white
    gfx_out.blt(
        @as(?[*]BltPixel, @ptrCast(@constCast(&white))),
        uefi.protocol.GraphicsOutput.BltOperation.blt_video_fill,
        0,
        0,
        0,
        0,
        gfx_out.mode.info.horizontal_resolution,
        gfx_out.mode.info.vertical_resolution,
        gfx_out.mode.info.pixels_per_scan_line,
    ) catch {};

    // Fill a rectangle (100,100)->(400,300) with red
    gfx_out.blt(
        @as(?[*]BltPixel, @ptrCast(@constCast(&red))),
        uefi.protocol.GraphicsOutput.BltOperation.blt_video_fill,
        0,
        0,
        100,
        100,
        300,
        200,
        gfx_out.mode.info.pixels_per_scan_line,
    ) catch {};

    utils.hangForKey(13);

    return .success;
}
