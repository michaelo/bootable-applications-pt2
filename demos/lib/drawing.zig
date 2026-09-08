const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("utils.zig");

pub fn drawLineWidth(target: utils.Bitmap, x0: f32, y0: f32, x1: f32, y1: f32, color: utils.BltPixel, width: f32) void {
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
pub fn drawLine(target: utils.Bitmap, x0: f32, y0: f32, x1: f32, y1: f32, color: utils.BltPixel) void {
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
            target.buffer[@intFromFloat(y * target.stride + x)] = color;
        }
        xf += xIncrement;
        yf += yIncrement;
    }
}

fn expectBitmap(pixels: []const utils.BltPixel, bitmap: utils.Bitmap) !void {
    try std.testing.expectEqualSlices(utils.BltPixel, pixels, @as([]utils.BltPixel, @ptrCast(bitmap.buffer[0..@intFromFloat(bitmap.height * bitmap.stride)])));
}

test "drawLine" {
    const bg = utils.Colors.black.argb;
    const fg = utils.Colors.white.argb;

    const bitmap = try bitmapCreate(std.testing.allocator, 4, 4);
    defer bitmap.free(std.testing.allocator);

    bitmapFill(bitmap, bg);

    drawLine(bitmap, 0, 0, 4, 4, fg);

    try expectBitmap(&[_]utils.BltPixel{
        fg, bg, bg, bg,
        bg, fg, bg, bg,
        bg, bg, fg, bg,
        bg, bg, bg, fg,
    }, bitmap);
}

// Draws an unfilled rectangle
pub fn drawBox(target: utils.Bitmap, x: f32, y: f32, width: f32, height: f32, color: utils.BltPixel, stroke_width: f32) void {
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

/// Draws a circle using Jesko's method
/// Att! Current signature matches drawBox (e.g. assumes upper left corner + dimensions) - but currently only cares about width for radius
/// TODO: make support any ellipsis
pub fn drawCircle(target: utils.Bitmap, x0: f32, y0: f32, width: f32, height: f32, color: utils.BltPixel) void {
    const xc = x0 + @floor(width / 2);
    const yc = y0 + @floor(height / 2);

    const r = @floor((width - 1) / 2);
    var t1 = @floor(r / 16);
    var x: f32 = r;
    var y: f32 = 0;
    while (x >= y) {
        target.buffer[@intFromFloat((yc + y) * target.stride + (xc + x))] = color;
        target.buffer[@intFromFloat((yc + x) * target.stride + (xc + y))] = color;

        target.buffer[@intFromFloat((yc - y) * target.stride + (xc + x))] = color;
        target.buffer[@intFromFloat((yc - x) * target.stride + (xc + y))] = color;

        target.buffer[@intFromFloat((yc + y) * target.stride + (xc - x))] = color;
        target.buffer[@intFromFloat((yc + x) * target.stride + (xc - y))] = color;

        target.buffer[@intFromFloat((yc - y) * target.stride + (xc - x))] = color;
        target.buffer[@intFromFloat((yc - x) * target.stride + (xc - y))] = color;

        y = y + 1;

        t1 = t1 + y;
        const t2 = t1 - x;
        if (t2 >= 0) {
            t1 = t2;
            x = x - 1;
        }
    }
}

pub fn bitmapFromScreenbuffer(gfx_out: *uefi.protocol.GraphicsOutput) utils.Bitmap {
    return .{
        .width = @floatFromInt(gfx_out.mode.info.horizontal_resolution),
        .height = @floatFromInt(gfx_out.mode.info.vertical_resolution),
        .stride = @floatFromInt(gfx_out.mode.info.pixels_per_scan_line),
        .buffer = @as([*]utils.BltPixel, @ptrFromInt(gfx_out.mode.frame_buffer_base)),
    };
}

pub fn bitmapCreate(alloc: std.mem.Allocator, width: f32, height: f32) !utils.Bitmap {
    const buffer = try alloc.alloc(utils.BltPixel, @intFromFloat(@ceil(width * height)));
    return utils.Bitmap{
        .buffer = @as([*]utils.BltPixel, buffer.ptr),
        .buffer_offset = 0,
        .height = height,
        .width = width,
        .stride = width,
    };
}

pub fn bitmapFill(bitmap: utils.Bitmap, color: utils.BltPixel) void {
    @memset(bitmap.buffer[0..@intFromFloat(bitmap.height * bitmap.stride)], color);
}

pub fn blitToScreen(gfx_out: *uefi.protocol.GraphicsOutput, bitmap: utils.Bitmap, x: i32, y: i32) void {
    gfx_out.blt(
        bitmap.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        @intCast(x),
        @intCast(y),
        @intFromFloat(bitmap.width),
        @intFromFloat(bitmap.height),
        @intFromFloat(bitmap.stride * @sizeOf(utils.BltPixel)),
    ) catch {};
}

/// Copies source bitmpat to target - filling/stretching to the area (x_start,y_start) -> (x_end, y_end)
/// Limitation: assumes full area fits within the dimensions of target
pub fn bltBitmapScaled(target: utils.Bitmap, source: utils.Bitmap, x_start: f32, y_start: f32, x_end: f32, y_end: f32) void {
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
    source.buffer[0] = utils.Colors.white.argb;
    source.buffer[1] = utils.Colors.blue.argb;

    bitmapFill(target, utils.Colors.black.argb);

    bltBitmapScaled(target, source, 0, 0, 4, 2);

    try expectBitmap(&[_]utils.BltPixel{
        utils.Colors.white.argb, utils.Colors.white.argb, utils.Colors.blue.argb,  utils.Colors.blue.argb,
        utils.Colors.white.argb, utils.Colors.white.argb, utils.Colors.blue.argb,  utils.Colors.blue.argb,
        utils.Colors.black.argb, utils.Colors.black.argb, utils.Colors.black.argb, utils.Colors.black.argb,
    }, target);
}
