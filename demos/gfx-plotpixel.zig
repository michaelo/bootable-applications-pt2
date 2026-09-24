const std = @import("std");
const uefi = std.os.uefi;
pub const BltPixel = uefi.protocol.GraphicsOutput.BltPixel; // bgra

pub fn main() uefi.Status {
    const bg = BltPixel{
        .red = 0x5f,
        .green = 0x53,
        .blue = 0xfe,
        .reserved = 0,
    };

    // Get protoco
    const gfx_out = uefi.system_table.boot_services.?
        .locateProtocol(uefi.protocol.GraphicsOutput, null) catch null orelse unreachable;

    // Probe information
    const width = gfx_out.mode.info.horizontal_resolution;
    const height = gfx_out.mode.info.vertical_resolution;
    const stride = gfx_out.mode.info.pixels_per_scan_line;
    const buffer = @as([*]BltPixel, @ptrFromInt(gfx_out.mode.frame_buffer_base));

    // Fill screen
    gfx_out.blt(@as(?[*]BltPixel, @ptrCast(@constCast(&bg))), uefi.protocol.GraphicsOutput.BltOperation.blt_video_fill, 0, 0, 0, 0, width, height, stride) catch {};

    // Plot pixel
    for (60..height - 60) |y| {
        for (60..width - 60) |x| {
            buffer[y * stride + x] = BltPixel{
                .red = 0x21,
                .green = 0x1b,
                .blue = 0xae,
                .reserved = 0,
            };
        }
    }

    @import("lib/utils.zig").hangForKey(13);
    return .success;
}
