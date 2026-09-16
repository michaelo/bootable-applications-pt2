const std = @import("std");
const uefi = std.os.uefi;

pub fn drawLineWidth(target: Bitmap, x0: f32, y0: f32, x1: f32, y1: f32, color: Pixel, width: f32) void {
    // Stroke width: establish if majorly horizontal or vertical, then spread out in opposite dimension
    const is_vertical_dominant = @abs(x1 - x0) < @abs(y1 - y0);
    const half = @floor(width / 2);

    var w_idx = -half;
    if (is_vertical_dominant) {
        while (w_idx <= half) : (w_idx += 1) {
            drawLine(target, x0 + w_idx, y0, x1 + w_idx, y1, color);
        }
    } else {
        while (w_idx <= half) : (w_idx += 1) {
            drawLine(target, x0, y0 + w_idx, x1, y1 + w_idx, color);
        }
    }
}

/// Limitiation: Only 1px width
pub fn drawLine(target: Bitmap, x0: f32, y0: f32, x1: f32, y1: f32, color: Pixel) void {
    const dx: f32 = x1 - x0;
    const dy: f32 = y1 - y0;
    const xSteps: f32 = @abs(dx);
    const ySteps: f32 = @abs(dy);
    const numSteps: u32 = @intFromFloat(@max(xSteps, ySteps));
    const numStepsF: f32 = @floatFromInt(numSteps);
    const xIncrement: f32 = dx / numStepsF;
    const yIncrement: f32 = dy / numStepsF;

    var xf: f32 = x0;
    var yf: f32 = y0;

    for (0..numSteps) |_| {
        const x = @round(xf);
        const y = @round(yf);
        if (x >= 0 and x < target.width and y >= 0 and y < target.height) {
            target.buffer[@intFromFloat(y * target.stride + x)] = color.argb;
        }
        xf += xIncrement;
        yf += yIncrement;
    }
}

/// For testing
pub fn expectBitmap(pixels: []const BltPixel, bitmap: Bitmap) !void {
    try std.testing.expectEqualSlices(BltPixel, pixels, @as([]BltPixel, @ptrCast(bitmap.buffer[0..@intFromFloat(bitmap.height * bitmap.stride)])));
}

test "drawLine" {
    const bg = Colors.black.argb;
    const fg = Colors.white.argb;

    const bitmap = try bitmapCreate(std.testing.allocator, 4, 4);
    defer bitmap.free(std.testing.allocator);

    bitmapFill(bitmap, .{ .argb = bg });

    drawLine(bitmap, 0, 0, 4, 4, .{ .argb = fg });

    try expectBitmap(&[_]BltPixel{
        fg, bg, bg, bg,
        bg, fg, bg, bg,
        bg, bg, fg, bg,
        bg, bg, bg, fg,
    }, bitmap);
}

// Draws an unfilled rectangle
pub fn drawBox(target: Bitmap, x: f32, y: f32, width: f32, height: f32, color: Pixel, stroke_width: f32) void {
    const half_inty = @round(stroke_width / 2);
    const left = x;
    const top = y;
    const right = x + width - 1;
    const bottom = y + height - 1;
    // TODO: Can alternatively solve stroke_width by drawing increasingly smaller boxes

    // top edge
    drawLineWidth(target, left, top + half_inty, right, top + half_inty, color, stroke_width);

    // bottom edge
    drawLineWidth(target, left, bottom - half_inty, right, bottom - half_inty, color, stroke_width);

    // left edge
    drawLineWidth(target, left + half_inty, top, left + half_inty, bottom, color, stroke_width);

    // right edge
    drawLineWidth(target, right - half_inty, top, right - half_inty, bottom, color, stroke_width);
}

pub fn drawBoxFilled(target: Bitmap, x: f32, y: f32, width: f32, height: f32, bg_color: Pixel, border_color: Pixel, stroke_width: f32) void {
    const half_inty = @round(stroke_width / 2);
    const left = x;
    const top = y;
    const right = x + width - 1;
    const bottom = y + height - 1;
    // TODO: Can alternatively solve stroke_width by drawing increasingly smaller boxes

    // TODO: May be
    const x_idx: usize = @intFromFloat(x);
    const x_end_idx: usize = @intFromFloat(x + width);
    var y_idx: usize = @intFromFloat(y);
    const y_end_idx: usize = @intFromFloat(y + height);
    const target_stride: usize = @intFromFloat(target.stride);
    while (y_idx < y_end_idx) : (y_idx += 1) {
        @memset(target.buffer[y_idx * target_stride + x_idx .. y_idx * target_stride + x_end_idx], bg_color.argb);
    }

    // top edge
    drawLineWidth(target, left, top + half_inty, right, top + half_inty, border_color, stroke_width);

    // bottom edge
    drawLineWidth(target, left, bottom - half_inty, right, bottom - half_inty, border_color, stroke_width);

    // left edge
    drawLineWidth(target, left + half_inty, top, left + half_inty, bottom, border_color, stroke_width);

    // right edge
    drawLineWidth(target, right - half_inty, top, right - half_inty, bottom, border_color, stroke_width);
}

/// Draws a circle using Jesko's method
/// Att! Current signature matches drawBox (e.g. assumes upper left corner + dimensions) - but currently only cares about width for radius
/// TODO: make support any ellipsis
pub fn drawCircle(target: Bitmap, x0: f32, y0: f32, width: f32, height: f32, color: Pixel) void {
    const xc = @round(x0 + @floor(width / 2));
    const yc = @round(y0 + @floor(height / 2));

    const r = @floor((width - 1) / 2);
    var t1 = @floor(r / 16);
    var x: f32 = r;
    var y: f32 = 0;
    while (x >= y) {
        target.buffer[@intFromFloat((yc + y) * target.stride + (xc + x))] = color.argb;
        target.buffer[@intFromFloat((yc + x) * target.stride + (xc + y))] = color.argb;

        target.buffer[@intFromFloat((yc - y) * target.stride + (xc + x))] = color.argb;
        target.buffer[@intFromFloat((yc - x) * target.stride + (xc + y))] = color.argb;

        target.buffer[@intFromFloat((yc + y) * target.stride + (xc - x))] = color.argb;
        target.buffer[@intFromFloat((yc + x) * target.stride + (xc - y))] = color.argb;

        target.buffer[@intFromFloat((yc - y) * target.stride + (xc - x))] = color.argb;
        target.buffer[@intFromFloat((yc - x) * target.stride + (xc - y))] = color.argb;

        y = y + 1;

        t1 = t1 + y;
        const t2 = t1 - x;
        if (t2 >= 0) {
            t1 = t2;
            x = x - 1;
        }
    }
}

pub fn drawCircleXor(target: Bitmap, x0: f32, y0: f32, width: f32, height: f32, color: Pixel) void {
    const xc = x0 + @floor(width / 2);
    const yc = y0 + @floor(height / 2);

    const r = @floor((width - 1) / 2);
    var t1 = @floor(r / 16);
    var x: f32 = r;
    var y: f32 = 0;
    var buffer: [*]u32 = @ptrCast(@alignCast(target.buffer));
    while (x >= y) {
        buffer[@intFromFloat((yc + y) * target.stride + (xc + x))] ^= color.int;
        buffer[@intFromFloat((yc + x) * target.stride + (xc + y))] ^= color.int;

        buffer[@intFromFloat((yc - y) * target.stride + (xc + x))] ^= color.int;
        buffer[@intFromFloat((yc - x) * target.stride + (xc + y))] ^= color.int;

        buffer[@intFromFloat((yc + y) * target.stride + (xc - x))] ^= color.int;
        buffer[@intFromFloat((yc + x) * target.stride + (xc - y))] ^= color.int;

        buffer[@intFromFloat((yc - y) * target.stride + (xc - x))] ^= color.int;
        buffer[@intFromFloat((yc - x) * target.stride + (xc - y))] ^= color.int;

        y = y + 1;

        t1 = t1 + y;
        const t2 = t1 - x;
        if (t2 >= 0) {
            t1 = t2;
            x = x - 1;
        }
    }
}

pub fn bitmapFromScreenbuffer(gfx_out: *uefi.protocol.GraphicsOutput) Bitmap {
    return .{
        .width = @floatFromInt(gfx_out.mode.info.horizontal_resolution),
        .height = @floatFromInt(gfx_out.mode.info.vertical_resolution),
        .stride = @floatFromInt(gfx_out.mode.info.pixels_per_scan_line),
        // .stride = @floatFromInt(gfx_out.mode.info.pixels_per_scan_line) / @sizeOf(BltPixel),
        .buffer = @as([*]BltPixel, @ptrFromInt(gfx_out.mode.frame_buffer_base)),
    };
}

pub fn bitmapCreate(alloc: std.mem.Allocator, width: f32, height: f32) !Bitmap {
    const buffer = try alloc.alloc(BltPixel, @intFromFloat(@ceil(width * height)));
    return Bitmap{
        .buffer = @as([*]BltPixel, buffer.ptr),
        .buffer_offset = 0,
        .height = height,
        .width = width,
        .stride = width,
    };
}

pub fn bitmapFill(bitmap: Bitmap, color: Pixel) void {
    @memset(bitmap.buffer[0..@intFromFloat(bitmap.height * bitmap.stride)], color.argb);
}

pub fn bltToScreen(gfx_out: *uefi.protocol.GraphicsOutput, bitmap: Bitmap, x: i32, y: i32) void {
    gfx_out.blt(
        bitmap.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        @intCast(x),
        @intCast(y),
        @intFromFloat(bitmap.width),
        @intFromFloat(bitmap.height),
        @intFromFloat(bitmap.stride * @sizeOf(BltPixel)),
    ) catch {};
}

/// Copies source bitmpat to target - filling/stretching to the area (x_start,y_start) -> (x_end, y_end)
/// Limitation: assumes full area fits within the dimensions of target
pub fn bltBitmapScaled(target: Bitmap, source: Bitmap, x_start: f32, y_start: f32, x_end: f32, y_end: f32) void {
    const x_scale: f32 = (x_end - x_start) / source.width;
    const y_scale: f32 = (y_end - y_start) / source.height;

    // const y_start_proper: usize = if (y_start < 0) 0 else @intCast(y_start);
    // const x_start_proper: usize = if (x_start < 0) 0 else @intCast(x_start);

    // const y_end_scaled: u32 = @intFromFloat(@as(f32, @floatFromInt(y_end)) * y_scale);
    // const x_end_scaled: u32 = @intFromFloat(@as(f32, @floatFromInt(x_end)) * x_scale);

    // const y_end_proper: usize = if (y_end_scaled >= target.height) target.height else @intCast(y_end);
    // const x_end_proper: usize = if (x_end_scaled >= target.width) target.width else @intCast(x_end);
    // std.debug.print("from: {},{} to {},{}\n", .{ x_start, y_start, x_end, y_end });

    for (@intFromFloat(y_start)..@intFromFloat(y_end)) |ty| {
        const tyf: f32 = @floatFromInt(ty);

        for (@intFromFloat(x_start)..@intFromFloat(x_end)) |tx| {
            const txf: f32 = @floatFromInt(tx);

            const sxf = @floor((txf - x_start) / x_scale);
            const syf = @floor((tyf - y_start) / y_scale);

            const sidx: usize = @intFromFloat(@round(syf * source.stride) + sxf);
            const tidx: usize = @intFromFloat(@round(tyf * target.stride) + txf);
            // std.debug.print("({}, {})({}) -> ({}, {})({})\n", .{ sxf, syf, sidx, tx, ty, tidx });

            target.buffer[tidx] = source.buffer[sidx];
        }
    }
}

test "bltBitmapScaled" {
    // Test stretching 2x1 to 4x2
    const source = try bitmapCreate(std.testing.allocator, 2, 1);
    defer source.free(std.testing.allocator);

    const target = try bitmapCreate(std.testing.allocator, 4, 3);
    defer target.free(std.testing.allocator);

    // white blue
    source.buffer[0] = Colors.white.argb;
    source.buffer[1] = Colors.blue.argb;

    bitmapFill(target, Colors.black);

    bltBitmapScaled(target, source, 0, 0, 4, 2);

    try expectBitmap(&[_]BltPixel{
        Colors.white.argb, Colors.white.argb, Colors.blue.argb,  Colors.blue.argb,
        Colors.white.argb, Colors.white.argb, Colors.blue.argb,  Colors.blue.argb,
        Colors.black.argb, Colors.black.argb, Colors.black.argb, Colors.black.argb,
    }, target);
}

pub fn bltBitmapXor(target: Bitmap, source: Bitmap, x_start: f32, y_start: f32, x_end: f32, y_end: f32) void {
    const x_scale: f32 = (x_end - x_start) / source.width;
    const y_scale: f32 = (y_end - y_start) / source.height;

    var target_buffer: [*]Pixel = @ptrCast(@alignCast(target.buffer));
    const source_buffer: [*]Pixel = @ptrCast(@alignCast(source.buffer));

    for (@intFromFloat(y_start)..@intFromFloat(y_end)) |ty| {
        const tyf: f32 = @floatFromInt(ty);

        for (@intFromFloat(x_start)..@intFromFloat(x_end)) |tx| {
            const txf: f32 = @floatFromInt(tx);

            const sxf = @floor((txf - x_start) / x_scale);
            const syf = @floor((tyf - y_start) / y_scale);

            const sidx: usize = @intFromFloat(@round(syf * source.stride) + sxf);
            const tidx: usize = @intFromFloat(@round(tyf * target.stride) + txf);

            target_buffer[tidx].int ^= source_buffer[sidx].int;
        }
    }
}

pub fn drawPlotToBitmap(comptime W: usize, comptime H: usize, comptime ClutSize: usize, bitmap: Bitmap, plot: [H][W]u8, clut: [ClutSize]Pixel) void {
    const width = @min(W, @as(usize, @intFromFloat(bitmap.width)));
    const height = @min(H, @as(usize, @intFromFloat(bitmap.height)));
    const stride: usize = @intFromFloat(bitmap.stride);

    for (0..width) |y| {
        for (0..height) |x| {
            bitmap.buffer[stride * y + x] = clut[plot[y][x]].argb;
        }
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
    pub const empty: @This() = .{
        .width = 0,
        .height = 0,
        .stride = 0,
        .buffer_offset = 0,
        .buffer = undefined,
    };
    width: f32, //4
    height: f32, //4
    stride: f32, //4
    buffer_offset: u8 = 0, //1
    buffer: [*]BltPixel, //8

    pub fn free(self: Bitmap, alloc: std.mem.Allocator) void {
        alloc.free(@as([]BltPixel, @ptrCast(self.buffer[0..@intFromFloat(self.height * self.stride)])));
    }
};

const font = @import("font8x8.zig");

/// Renders a single character, currently based off of a fixed-width 8x8 font.
pub fn drawChar(bitmap: Bitmap, dx: f32, dy: f32, bg: Pixel, fg: Pixel, size: u16, ord: i32) void {
    // Fallbacks to clear if ord not found in glyph-set
    const glyph = font.getGlyph(ord) orelse ([8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 })[0..];

    const scale: f32 = font.BASE_FONT_SIZE / @as(f32, @floatFromInt(size));

    // // If not transparent
    if (bg.argb.reserved != 0) {
        for (0..size) |x| {
            const px = dx + @as(f32, @floatFromInt(x));
            if (px < 0 or px >= bitmap.width)
                continue;

            // const pxs = @as(u32, @intCast(px));

            for (0..size) |y| {
                const py = dy + @as(f32, @floatFromInt(y));
                if (py < 0 or py >= bitmap.height)
                    continue;

                // const pys = @as(u32, @intCast(py));

                const scaled_x: usize = @intFromFloat(@as(f32, @floatFromInt(x)) * scale);
                const scaled_y: usize = @intFromFloat(@as(f32, @floatFromInt(y)) * scale);

                const set = glyph[scaled_y] & @as(u8, @as(u8, 1) << @as(u3, @intCast(scaled_x)));
                if (set == 0) {
                    bitmap.buffer[@intFromFloat(py * bitmap.stride + px)] = bg.argb;
                }
            }
        }
    }

    // If not transparent
    if (fg.argb.reserved != 0) {
        for (0..size) |x| {
            const px = dx + @as(f32, @floatFromInt(x));
            if (px < 0 or px >= bitmap.width)
                continue;

            for (0..size) |y| {
                const py = dy + @as(f32, @floatFromInt(y));
                if (py < 0 or py >= bitmap.height)
                    continue;

                const scaled_x: usize = @intFromFloat(@as(f32, @floatFromInt(x)) * scale);
                const scaled_y: usize = @intFromFloat(@as(f32, @floatFromInt(y)) * scale);

                const set = glyph[scaled_y] & @as(u8, @as(u8, 1) << @as(u3, @intCast(scaled_x)));
                if (set != 0) {
                    bitmap.buffer[@intFromFloat(py * bitmap.stride + px)] = fg.argb;
                }
            }
        }
    }
}

test "drawChar size=8" {
    const bg = Colors.black.argb;
    const fg = Colors.white.argb;

    var buffer: [8 * 8]BltPixel = undefined;
    @memset(&buffer, bg);

    const bmp = Bitmap{
        .buffer = @as([*]BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 8,
        .width = 8,
        .stride = 8,
    };

    drawChar(bmp, 0, 0, Colors.transparent, .{ .argb = fg }, 8, 'A');
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

test "drawChar size=16" {
    const bg = Colors.black.argb;
    const fg = Colors.white.argb;

    var buffer: [16 * 16]BltPixel = undefined;
    @memset(&buffer, bg);

    const bmp = Bitmap{
        .buffer = @as([*]BltPixel, &buffer),
        .buffer_offset = 0,
        .height = 16,
        .width = 16,
        .stride = 16,
    };

    drawChar(bmp, 0, 0, Colors.transparent, .{ .argb = fg }, 16, 'A');
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

pub fn textWidth(text: []const u8, size: u16) f32 {
    return @as(f32, @floatFromInt(text.len)) * size;
}

/// Renders a sequence of fixed-width characters
pub fn drawString(bitmap: Bitmap, dx: f32, dy: f32, bg: Pixel, fg: Pixel, size: u16, text: []const u8) f32 {
    const y = @round(dy);
    const sizef: f32 = @floatFromInt(size);
    for (text, 0..) |c, cidx| {
        const x = @round(dx + sizef * @as(f32, @floatFromInt(cidx)));
        drawChar(bitmap, x, y, bg, fg, size, c);
    }
    return @as(f32, @floatFromInt(text.len)) * sizef;
}

/// Brute force "outline": render multiple instances of the text offset in all directions in the outline-color before rendering the actual text in center
pub fn drawStringOutlined(bitmap: Bitmap, dx: f32, dy: f32, bg: Pixel, fg: Pixel, outline_color: Pixel, outline_size: f32, size: u16, text: []const u8) f32 {
    _ = drawString(bitmap, dx - outline_size, dy - outline_size, Colors.transparent, outline_color, size, text);
    _ = drawString(bitmap, dx, dy - outline_size, Colors.transparent, outline_color, size, text);
    _ = drawString(bitmap, dx + outline_size, dy - outline_size, Colors.transparent, outline_color, size, text);

    _ = drawString(bitmap, dx - outline_size, dy, Colors.transparent, outline_color, size, text);
    _ = drawString(bitmap, dx + outline_size, dy, Colors.transparent, outline_color, size, text);

    _ = drawString(bitmap, dx - outline_size, dy + outline_size, Colors.transparent, outline_color, size, text);
    _ = drawString(bitmap, dx, dy + outline_size, Colors.transparent, outline_color, size, text);
    _ = drawString(bitmap, dx + outline_size, dy + outline_size, Colors.transparent, outline_color, size, text);

    return drawString(bitmap, dx, dy, bg, fg, size, text);
}
