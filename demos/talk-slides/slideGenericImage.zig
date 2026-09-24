const std = @import("std");
const uefi = std.os.uefi;
const main = @import("../talk-slides.zig");
const drawing = @import("../lib/drawing.zig");
const file = @import("../lib/file.zig");

// TODO: Make generic cache that can support multiple images?
var bmp_bitmap: drawing.Bitmap = .empty;

pub fn createSlide(path: []const u8) *const fn (*main.State, f32) main.SlideResult {
    return struct {
        pub fn slide(state: *main.State, td: f32) main.SlideResult {
            _ = td;
            if (state.firstFrame) {
                // Free any previous image if already loaded
                if (bmp_bitmap.width > 0) {
                    bmp_bitmap.free(uefi.pool_allocator);
                    bmp_bitmap = .empty;
                }

                const bmp_raw = file.readFile(uefi.pool_allocator, path) catch |e| {
                    // TOOD: error handling
                    state.console.write("Could not open: {s} ({s})", .{ path, @errorName(e) });
                    return .finished;
                };
                defer uefi.pool_allocator.free(bmp_raw);
                state.console.write("Loaded image data raw: {d} bytes", .{bmp_raw.len});

                var reader: std.Io.Reader = .fixed(bmp_raw);
                bmp_bitmap = @import("../lib/bmp.zig").loadBmpToBitmapFromReader(uefi.pool_allocator, &reader) catch {
                    state.console.write("Could not load bmp: {s}", .{path});
                    return .finished;
                };
                state.console.write("Loaded image: {d}x{d}", .{ bmp_bitmap.width, bmp_bitmap.height });
            }

            drawing.bitmapFill(state.backbuffer, drawing.Colors.black);

            // Scale
            var width = bmp_bitmap.width;
            var height = bmp_bitmap.height;
            const scale = bmp_bitmap.width / bmp_bitmap.height;

            // Maximize by width
            width = state.backbuffer.width;
            height = width / scale;

            // Shring by height if overflowing
            if (height > state.backbuffer.height) {
                // Shrink
                height = state.backbuffer.height;
                width = height * scale;
            }

            // Scale up to fill screen if smaller than screen

            const x_offset = (state.backbuffer.width - width) / 2;
            const y_offset = (state.backbuffer.height - height) / 2;

            // TODO: centre
            drawing.bltBitmapScaled(
                state.backbuffer,
                bmp_bitmap,
                x_offset,
                y_offset,
                state.backbuffer.width - x_offset,
                state.backbuffer.height - y_offset,
            );
            return .running;
        }
    }.slide;
}
