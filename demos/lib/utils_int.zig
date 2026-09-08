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

pub fn drawLineWidth(target: Bitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: BltPixel, width: f32) void {
    // Stroke width: establish if majorly horizontal or vertical, then spread out in opposite dimension
    const is_vertical_dominant = @abs(x1 - x0) < @abs(y1 - y0);
    const half: i32 = @floor(width / 2);

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
pub fn drawLine(target: Bitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: BltPixel) void {
    const dx: f32 = @floatFromInt(x1 - x0);
    const dy: f32 = @floatFromInt(y1 - y0);
    const xSteps: f32 = @abs(dx);
    const ySteps: f32 = @abs(dy);
    const numSteps: u32 = @intFromFloat(@max(xSteps, ySteps));
    const numStepsF: f32 = @floatFromInt(numSteps);
    const xIncrement: f32 = dx / numStepsF;
    const yIncrement: f32 = dy / numStepsF;

    var xf: f32 = @floatFromInt(x0);
    var yf: f32 = @floatFromInt(y0);

    for (0..numSteps) |_| {
        const x: i32 = @round(xf);
        const y: i32 = @round(yf);
        const xu: u32 = @intCast(x);
        const yu: u32 = @intCast(y);
        if (x >= 0 and x < target.width and y >= 0 and y < target.height) {
            target.buffer[yu * target.stride + xu] = color;
        }
        xf += xIncrement;
        yf += yIncrement;
    }
}

test "drawLine" {
    const bg = Colors.black;
    const fg = Colors.white;

    const bitmap = try bitmapCreate(std.testing.allocator, 4, 4);
    defer bitmap.free(std.testing.allocator);

    bitmapFill(bitmap, bg);

    drawLine(bitmap, 0, 0, 4, 4, fg);

    try std.testing.expectEqualSlices(BltPixel, &[_]BltPixel{
        fg, bg, bg, bg,
        bg, fg, bg, bg,
        bg, bg, fg, bg,
        bg, bg, bg, fg,
    }, @as([]BltPixel, @ptrCast(bitmap.buffer[0 .. bitmap.height * bitmap.stride])));
}

// Draws an unfilled rectangle
pub fn drawBox(target: Bitmap, x: i32, y: i32, width: i32, height: i32, color: BltPixel, stroke_width: f32) void {
    const half_inty: i32 = @intFromFloat(stroke_width / 2);
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

/// Draws a circle using Jesko's method
/// Att! Current signature matches drawBox (e.g. assumes upper left corner + dimensions) - but currently only cares about width for radius
/// TODO: make support any ellipsis
pub fn drawCircle(target: Bitmap, x0: i32, y0: i32, width: i32, height: i32, color: BltPixel) void {
    const xc = x0 + @as(i32, @intFromFloat(@floor(@as(f32, @floatFromInt(width)) / 2)));
    const yc = y0 + @as(i32, @intFromFloat(@floor(@as(f32, @floatFromInt(height)) / 2)));

    const r = @floor(@as(f32, @floatFromInt(width - 1)) / 2);
    var t1: i32 = @intFromFloat(@floor(r / 16));
    const stride: i32 = @intCast(target.stride);
    var x: i32 = @intFromFloat(r);
    var y: i32 = 0;
    while (x >= y) {
        target.buffer[@intCast((yc + y) * stride + (xc + x))] = color;
        target.buffer[@intCast((yc + x) * stride + (xc + y))] = color;

        target.buffer[@intCast((yc - y) * stride + (xc + x))] = color;
        target.buffer[@intCast((yc - x) * stride + (xc + y))] = color;

        target.buffer[@intCast((yc + y) * stride + (xc - x))] = color;
        target.buffer[@intCast((yc + x) * stride + (xc - y))] = color;

        target.buffer[@intCast((yc - y) * stride + (xc - x))] = color;
        target.buffer[@intCast((yc - x) * stride + (xc - y))] = color;

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
        .width = gfx_out.mode.info.horizontal_resolution,
        .height = gfx_out.mode.info.vertical_resolution,
        .stride = gfx_out.mode.info.pixels_per_scan_line,
        .buffer = @as([*]BltPixel, @ptrFromInt(gfx_out.mode.frame_buffer_base)),
    };
}

pub fn bitmapCreate(alloc: std.mem.Allocator, width: u32, height: u32) !Bitmap {
    const buffer = try alloc.alloc(BltPixel, width * height);
    return Bitmap{
        .buffer = @as([*]BltPixel, buffer.ptr),
        .buffer_offset = 0,
        .height = height,
        .width = width,
        .stride = width,
    };
}

pub fn bitmapFill(bitmap: Bitmap, color: BltPixel) void {
    @memset(bitmap.buffer[0 .. bitmap.height * bitmap.stride], color);
}

pub fn blitToScreen(gfx_out: *uefi.protocol.GraphicsOutput, bitmap: Bitmap, x: i32, y: i32) void {
    gfx_out.blt(
        bitmap.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        @intCast(x),
        @intCast(y),
        bitmap.width,
        bitmap.height,
        bitmap.stride * @sizeOf(BltPixel),
    ) catch {};
}

/// Copies source bitmpat to target - filling/stretching to the area (x_start,y_start) -> (x_end, y_end)
/// Limitation: assumes full area fits within the dimensions of target
pub fn bltBitmapScaled(target: Bitmap, source: Bitmap, x_start: i32, y_start: i32, x_end: i32, y_end: i32) void {
    const x_scale: f32 = @as(f32, @floatFromInt(x_end - x_start)) / @as(f32, @floatFromInt(source.width));
    const y_scale: f32 = @as(f32, @floatFromInt(y_end - y_start)) / @as(f32, @floatFromInt(source.height));

    // const y_start_proper: usize = if (y_start < 0) 0 else @intCast(y_start);
    // const x_start_proper: usize = if (x_start < 0) 0 else @intCast(x_start);

    // const y_end_scaled: u32 = @intFromFloat(@as(f32, @floatFromInt(y_end)) * y_scale);
    // const x_end_scaled: u32 = @intFromFloat(@as(f32, @floatFromInt(x_end)) * x_scale);

    // const y_end_proper: usize = if (y_end_scaled >= target.height) target.height else @intCast(y_end);
    // const x_end_proper: usize = if (x_end_scaled >= target.width) target.width else @intCast(x_end);

    const source_stride = @as(f32, @floatFromInt(source.stride));
    const target_stride = @as(f32, @floatFromInt(target.stride));

    for (@intCast(y_start)..@intCast(y_end)) |ty| {
        const tys: i32 = @intCast(ty);
        const tyf: f32 = @floatFromInt(ty);

        for (@intCast(x_start)..@intCast(x_end)) |tx| {
            const txs: i32 = @intCast(tx);
            const txf: f32 = @floatFromInt(tx);

            const sxf = @floor(@as(f32, @floatFromInt(txs - x_start)) / x_scale);
            const syf = @floor(@as(f32, @floatFromInt(tys - y_start)) / y_scale);

            const sidx: usize = @intFromFloat((syf * source_stride) + sxf);
            const tidx: usize = @intFromFloat((tyf * target_stride) + txf);
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

    // // white blue
    source.buffer[0] = Colors.white;
    source.buffer[1] = Colors.blue;

    bitmapFill(target, Colors.black);

    bltBitmapScaled(target, source, 0, 0, 4, 2);

    try std.testing.expectEqualSlices(BltPixel, &[_]BltPixel{
        Colors.white, Colors.white, Colors.blue,  Colors.blue,
        Colors.white, Colors.white, Colors.blue,  Colors.blue,
        Colors.black, Colors.black, Colors.black, Colors.black,
    }, @as([]BltPixel, @ptrCast(target.buffer[0 .. target.height * target.stride])));
}
