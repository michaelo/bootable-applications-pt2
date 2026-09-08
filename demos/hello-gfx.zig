//! Version of hello.zig which specificly renders a text to the first available display device detected
//! Showcases direct usage of graphics functions. Generic variants is created under libs for convenient usage in more complex examples

const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("lib/utils.zig");

pub fn main() uefi.Status {
    const color_background: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 0, .red = 255, .reserved = 255 };
    const transparent: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 0, .red = 0, .reserved = 0 };
    const black: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 0, .red = 0, .reserved = 255 };
    const green: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 255, .red = 0, .reserved = 255 };
    const red: uefi.protocol.GraphicsOutput.BltPixel = .{ .blue = 0, .green = 0, .red = 255, .reserved = 255 };

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

    // Render text to separate bitmap
    var buffer: [128 * 512]utils.BltPixel = undefined;
    @memset(&buffer, red);
    const text_bmp = utils.Bitmap{
        .buffer = @as([*]utils.BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 128,
        .width = 512,
        .stride = 512,
    };

    // Read characteristics of current video mode and render string to bitmap
    var scratch: [128]u8 = undefined;
    const out = std.fmt.bufPrint(&scratch, "Hello, screen: {d} x {d} ({d} ppsl)", .{ gfx_out.mode.info.horizontal_resolution, gfx_out.mode.info.vertical_resolution, gfx_out.mode.info.pixels_per_scan_line }) catch "";
    _ = utils.renderStringOutlined(text_bmp, 4, 4, transparent, black, green, 1, 12, out);

    // Block transfer the separate bitmap onto the display pixel buffer
    gfx_out.blt(
        text_bmp.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        32,
        32,
        @intFromFloat(text_bmp.width),
        @intFromFloat(text_bmp.height),
        @intFromFloat(text_bmp.stride * 4),
    ) catch {};

    utils.hangForKey(13);

    return .success;
}
