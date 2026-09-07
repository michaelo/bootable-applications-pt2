const std = @import("std");
const uefi = std.os.uefi;

const utils = @import("utils.zig");

pub fn drawLineWidth(target: utils.Bitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: utils.BltPixel, width: f32) void {
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
pub fn drawLine(target: utils.Bitmap, x0: i32, y0: i32, x1: i32, y1: i32, color: utils.BltPixel) void {
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
    const bg = utils.Colors.black;
    const fg = utils.Colors.white;

    const bitmap = try bitmapCreate(std.testing.allocator, 4, 4);
    defer bitmap.free(std.testing.allocator);

    bitmapFill(bitmap, bg);

    drawLine(bitmap, 0, 0, 4, 4, fg);

    try std.testing.expectEqualSlices(utils.BltPixel, &[_]utils.BltPixel{
        fg, bg, bg, bg,
        bg, fg, bg, bg,
        bg, bg, fg, bg,
        bg, bg, bg, fg,
    }, @as([]utils.BltPixel, @ptrCast(bitmap.buffer[0 .. bitmap.height * bitmap.stride])));
}

// Draws an unfilled rectangle
pub fn drawBox(target: utils.Bitmap, x: i32, y: i32, width: i32, height: i32, color: utils.BltPixel, stroke_width: f32) void {
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

pub fn bitmapFromScreenbuffer(gfx_out: *uefi.protocol.GraphicsOutput) utils.Bitmap {
    return .{
        .width = gfx_out.mode.info.horizontal_resolution,
        .height = gfx_out.mode.info.vertical_resolution,
        .stride = gfx_out.mode.info.pixels_per_scan_line,
        .buffer = @as([*]utils.BltPixel, @ptrFromInt(gfx_out.mode.frame_buffer_base)),
    };
}

pub fn bitmapCreate(alloc: std.mem.Allocator, width: u32, height: u32) !utils.Bitmap {
    const buffer = try alloc.alloc(utils.BltPixel, width * height);
    return utils.Bitmap{
        .buffer = @as([*]utils.BltPixel, buffer.ptr),
        .buffer_offset = 0,
        .height = height,
        .width = width,
        .stride = width,
    };
}

pub fn bitmapFill(bitmap: utils.Bitmap, color: utils.BltPixel) void {
    @memset(bitmap.buffer[0 .. bitmap.height * bitmap.stride], color);
}

pub fn blitToScreen(gfx_out: *uefi.protocol.GraphicsOutput, bitmap: utils.Bitmap, x: i32, y: i32) void {
    gfx_out.blt(
        bitmap.buffer,
        uefi.protocol.GraphicsOutput.BltOperation.blt_buffer_to_video,
        0,
        0,
        @intCast(x),
        @intCast(y),
        bitmap.width,
        bitmap.height,
        bitmap.stride * @sizeOf(utils.BltPixel),
    ) catch {};
}

/// Copies source bitmpat to target - filling/stretching to the area (x_start,y_start) -> (x_end, y_end)
/// Limitation: assumes full area fits within the dimensions of target
pub fn bltBitmapScaled(target: utils.Bitmap, source: utils.Bitmap, x_start: i32, y_start: i32, x_end: i32, y_end: i32) void {
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
    source.buffer[0] = utils.Colors.white;
    source.buffer[1] = utils.Colors.blue;

    bitmapFill(target, utils.Colors.black);

    bltBitmapScaled(target, source, 0, 0, 4, 2);

    try std.testing.expectEqualSlices(utils.BltPixel, &[_]utils.BltPixel{
        utils.Colors.white, utils.Colors.white, utils.Colors.blue,  utils.Colors.blue,
        utils.Colors.white, utils.Colors.white, utils.Colors.blue,  utils.Colors.blue,
        utils.Colors.black, utils.Colors.black, utils.Colors.black, utils.Colors.black,
    }, @as([]utils.BltPixel, @ptrCast(target.buffer[0 .. target.height * target.stride])));
}
