//! Version of hello.zig which specificly renders a text to the first available display device detected

const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("utils.zig");

pub fn main() uefi.Status {
    const color_background: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 0, .red = 255, .reserved = 0 };

    var gfx_out = uefi.system_table.boot_services.?.locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;

    // Enable first available display mode
    gfx_out.setMode(0) catch unreachable;

    // Create a pointer to a single color we will blit unto the entire display buffer
    const bg_buffer = @as(?[*]uefi.protocol.GraphicsOutput.BltPixel, @ptrCast(@constCast(&color_background)));

    gfx_out.blt(
        bg_buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_video_fill,
        0,
        0,
        0,
        0,
        gfx_out.mode.info.horizontal_resolution,
        gfx_out.mode.info.vertical_resolution,
        gfx_out.mode.info.pixels_per_scan_line,
    ) catch {};

    // Render text...
    var buffer: [128 * 1024]utils.BltPixel = undefined;
    @memset(&buffer, utils.Colors.red);
    const text_bmp = utils.Bitmap{
        .buffer = @as([*]utils.BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 16,
        .width = 128,
        .stride = 128,
    };

    // utils.renderChar(text_bmp, 0, 0, utils.Colors.transparent, utils.color(0, 0, 0), 16, 'A');
    _ = utils.renderString(text_bmp, 0, 0, utils.Colors.transparent, utils.color(0, 0, 0), 16, "Hello!");

    gfx_out.blt(
        text_bmp.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        32,
        32,
        text_bmp.width,
        text_bmp.height,
        text_bmp.stride * 4,
    ) catch {};

    utils.hangForKey(13);

    return .success;
}
