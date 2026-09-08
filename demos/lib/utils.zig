const std = @import("std");
const uefi = std.os.uefi;

pub const W = std.unicode.utf8ToUtf16LeStringLiteral;

/// Simple helper to - utilizing pre-allocated buffers - provide a slice of formatted utf16-string ready to pass to e.g. outputString()
pub fn formatToU16(buf8: []u8, buf16: []u16, comptime format: []const u8, vars: anytype) [:0]const u16 {
    const formatted = std.fmt.bufPrint(buf8, format, vars) catch "";
    _ = std.unicode.utf8ToUtf16Le(buf16, formatted) catch 0;
    buf16[formatted.len] = 0;
    return buf16[0..formatted.len :0];
}

pub fn hangForKey(keycode: u16) void {
    const boot_services = uefi.system_table.boot_services.?;
    while (true) {
        _ = boot_services.waitForEvent(@as([]const uefi.Event, @ptrCast(&uefi.system_table.con_in.?.wait_for_key))) catch continue;
        const key = uefi.system_table.con_in.?.readKeyStroke() catch continue;
        if (key.unicode_char == keycode) break;
    }
}

/// Att! We utilize .reserved as transparent (0==transparent)
pub const BltPixel = uefi.protocol.GraphicsOutput.BltPixel; // bgra

// Convenient representation to allow conversion between types
pub const Pixel = extern union {
    /// The type commonly used when plotting pixels via UEFI
    argb: uefi.protocol.GraphicsOutput.BltPixel,
    /// Convenience-type for setting and manipulating
    int: u32,
    // float: f32,
};

/// Shorthands for common colors
pub const Colors = struct {
    pub const transparent = Pixel{ .int = 0x00000000 };
    pub const black = Pixel{ .int = 0xff000000 };
    pub const white = Pixel{ .int = 0xffffffff };

    pub const red = Pixel{ .int = 0xffff0000 };
    pub const green = Pixel{ .int = 0xff00ff00 };
    pub const blue = Pixel{ .int = 0xff0000ff };
};

/// Base convenience type encapsulating a pixel buffer. Core primitive for all drawing/rendering functions.
pub const Bitmap = struct {
    width: u32, //4
    height: u32, //4
    stride: u32, //4
    buffer_offset: u8 = 0, //1
    buffer: [*]BltPixel, //8

    pub fn free(self: Bitmap, alloc: std.mem.Allocator) void {
        alloc.free(@as([]BltPixel, @ptrCast(self.buffer[0 .. self.height * self.stride])));
    }
};

const font = @import("font8x8.zig");

/// Renders a single character, currently based off of a fixed-width 8x8 font.
pub fn renderChar(bitmap: Bitmap, dx: i32, dy: i32, bg: BltPixel, fg: BltPixel, size: u16, ord: i32) void {
    // Fallbacks to clear if ord not found in glyph-set
    const glyph = font.getGlyph(ord) orelse ([8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 })[0..];

    const scale: f32 = font.BASE_FONT_SIZE / @as(f32, @floatFromInt(size));

    // // If not transparent
    if (bg.reserved != 0) {
        for (0..size) |x| {
            const px = dx + @as(i32, @intCast(x));
            if (px < 0 or px >= bitmap.width)
                continue;

            const pxs = @as(u32, @intCast(px));

            for (0..size) |y| {
                const py = dy + @as(i32, @intCast(y));
                if (py < 0 or py >= bitmap.height)
                    continue;

                const pys = @as(u32, @intCast(py));

                const scaled_x: usize = @intFromFloat(@as(f32, @floatFromInt(x)) * scale);
                const scaled_y: usize = @intFromFloat(@as(f32, @floatFromInt(y)) * scale);

                const set = glyph[scaled_y] & @as(u8, @as(u8, 1) << @as(u3, @intCast(scaled_x)));
                if (set == 0) {
                    const idx = @as(usize, pys * bitmap.stride + pxs);
                    bitmap.buffer[idx] = bg;
                }
            }
        }
    }

    // If not transparent
    if (fg.reserved != 0) {
        for (0..size) |x| {
            const px = dx + @as(i32, @intCast(x));
            if (px < 0 or px >= bitmap.width)
                continue;

            const pxs = @as(u32, @intCast(px));

            for (0..size) |y| {
                const py = dy + @as(i32, @intCast(y));
                if (py < 0 or py >= bitmap.height)
                    continue;

                const pys = @as(u32, @intCast(py));

                const scaled_x: usize = @intFromFloat(@as(f32, @floatFromInt(x)) * scale);
                const scaled_y: usize = @intFromFloat(@as(f32, @floatFromInt(y)) * scale);

                const set = glyph[scaled_y] & @as(u8, @as(u8, 1) << @as(u3, @intCast(scaled_x)));
                if (set != 0) {
                    const idx = @as(usize, pys * bitmap.stride + pxs);
                    bitmap.buffer[idx] = fg;
                }
            }
        }
    }
}

test "renderChar size=8" {
    const bg = Colors.black;
    const fg = Colors.white;

    var buffer: [8 * 8]BltPixel = undefined;
    @memset(&buffer, bg);

    const bmp = Bitmap{
        .buffer = @as([*]BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 8,
        .width = 8,
        .stride = 8,
    };

    renderChar(bmp, 0, 0, Colors.transparent, fg, 8, 'A');
    try std.testing.expectEqual([_]BltPixel{
        bg, bg, fg, fg, bg, bg, bg, bg,
        bg, fg, fg, fg, fg, bg, bg, bg,
        fg, fg, bg, bg, fg, fg, bg, bg,
        fg, fg, bg, bg, fg, fg, bg, bg,
        fg, fg, fg, fg, fg, fg, bg, bg,
        fg, fg, bg, bg, fg, fg, bg, bg,
        fg, fg, bg, bg, fg, fg, bg, bg,
        bg, bg, bg, bg, bg, bg, bg, bg,
    }, buffer);
}

test "renderChar size=16" {
    const bg = Colors.black;
    const fg = Colors.white;

    var buffer: [16 * 16]BltPixel = undefined;
    @memset(&buffer, bg);

    const bmp = Bitmap{
        .buffer = @as([*]BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 16,
        .width = 16,
        .stride = 16,
    };

    renderChar(bmp, 0, 0, Colors.transparent, fg, 16, 'A');
    try std.testing.expectEqual([_]BltPixel{
        bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg, bg, bg, bg, bg,
        bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg, bg, bg, bg, bg,
        bg, bg, fg, fg, fg, fg, fg, fg, fg, fg, bg, bg, bg, bg, bg, bg,
        bg, bg, fg, fg, fg, fg, fg, fg, fg, fg, bg, bg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        fg, fg, fg, fg, bg, bg, bg, bg, fg, fg, fg, fg, bg, bg, bg, bg,
        bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg,
        bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg, bg,
    }, buffer);
}

/// Renders a sequence of fixed-width characters
pub fn renderString(bitmap: Bitmap, dx: i32, dy: i32, bg: BltPixel, fg: BltPixel, size: u16, text: []const u8) i32 {
    for (text, 0..) |c, cidx| {
        const x: i32 = dx + @as(i32, @intCast(size * cidx));
        renderChar(bitmap, x, dy, bg, fg, size, c);
    }
    return @as(i32, @intCast(text.len)) * size;
}

/// Brute force "outline": render multiple instances of the text offset in all directions in the outline-color before rendering the actual text in center
pub fn renderStringOutlined(bitmap: Bitmap, dx: i32, dy: i32, bg: BltPixel, fg: BltPixel, outline_color: BltPixel, outline_size: i32, size: u16, text: []const u8) i32 {
    _ = renderString(bitmap, dx - outline_size, dy - outline_size, Colors.transparent.argb, outline_color, size, text);
    _ = renderString(bitmap, dx, dy - outline_size, Colors.transparent.argb, outline_color, size, text);
    _ = renderString(bitmap, dx + outline_size, dy - outline_size, Colors.transparent.argb, outline_color, size, text);

    _ = renderString(bitmap, dx - outline_size, dy, Colors.transparent.argb, outline_color, size, text);
    _ = renderString(bitmap, dx + outline_size, dy, Colors.transparent.argb, outline_color, size, text);

    _ = renderString(bitmap, dx - outline_size, dy + outline_size, Colors.transparent.argb, outline_color, size, text);
    _ = renderString(bitmap, dx, dy + outline_size, Colors.transparent.argb, outline_color, size, text);
    _ = renderString(bitmap, dx + outline_size, dy + outline_size, Colors.transparent.argb, outline_color, size, text);

    return renderString(bitmap, dx, dy, bg, fg, size, text);
}
