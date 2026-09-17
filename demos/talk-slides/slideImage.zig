const std = @import("std");
const uefi = std.os.uefi;
const main = @import("../talk-slides.zig");
const drawing = @import("../lib/drawing.zig");

const bmp_raw = @embedFile("../talk-slides.zig-files/companion-knight-600x800.bmp");

var bmp_bitmap: drawing.Bitmap = .empty;
pub fn slide(state: *main.State, td: f32) main.SlideResult {
    _ = td;
    // Init
    // TODO: Provide deinit as well? Or solve with arena allocator?
    if (state.firstFrame) {
        // qr_bitmap = drawing.bitmapCreate(uefi.pool_allocator, 33, 33) catch unreachable;
        // drawing.drawPlotToBitmap(33, 33, 2, qr_bitmap, qr_plot, [2]drawing.Pixel{ drawing.Colors.black, drawing.Colors.white });
        var reader: std.Io.Reader = .fixed(bmp_raw);
        bmp_bitmap = @import("../lib/bmp.zig").loadBmpToBitmapFromReader(uefi.pool_allocator, &reader) catch unreachable;
    }

    drawing.bitmapFill(state.backbuffer, drawing.Colors.black);

    // const size: u16 = 16 + @as(u16, @intFromFloat(16 * @abs(@sin(state.globalT))));
    // _ = drawing.drawStringOutlined(state.backbuffer, 100, 100, drawing.Colors.transparent, drawing.Colors.black, drawing.Colors.red, 2, size, "Slide 1");

    // drawing.bltBitmapScaled(state.backbuffer, qr_bitmap, 300, 10, 300 + 200, 10 + 200);
    drawing.bltBitmapScaled(state.backbuffer, bmp_bitmap, 20 * state.unit, 0, state.backbuffer.width - 20 * state.unit, state.backbuffer.height);
    return if (state.frameT > 10) .finished else .running;
}
