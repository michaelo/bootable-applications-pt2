const drawing = @import("../lib/drawing.zig");
const std = @import("std");

pub fn shaderSineWaveStripes(x: f32, y: f32, t: f32) drawing.Pixel {
    const v = 0.5 + 0.5 * @sin((x + y) * 0.02 + t);
    const r: u8 = @intFromFloat(std.math.clamp(v * 255, 0, 255));
    const g: u8 = @intFromFloat(std.math.clamp((1.0 - v) * 255, 0, 255));
    const b: u8 = 128;
    return .{ .argb = .{
        .red = r,
        .green = g,
        .blue = b,
        .reserved = 255,
    } };
}

pub fn shaderCheckerboard(x: f32, y: f32, t: f32) drawing.Pixel {
    const cx: u32 = @intFromFloat(x / 64);
    const cy: u32 = @intFromFloat(y / 64);
    const f: f32 = @floatFromInt((cx + cy) % 2);
    // smooth blend with t for animation
    const v: f32 = f + 0.5 * @sin(x * 0.05 + t) * @sin(y * 0.05 + t);
    const c: u8 = @intFromFloat(std.math.clamp(v * 255, 0, 255));
    return .{ .argb = .{
        .red = c,
        .green = c,
        .blue = c,
        .reserved = 255,
    } };
}

pub fn shaderRadialPlasma(x: f32, y: f32, t: f32) drawing.Pixel {
    const dx: f32 = (x - 512.0) / 512.0;
    const dy: f32 = (y - 512.0) / 512.0;
    const d: f32 = @sqrt(dx * dx + dy * dy);
    const v: f32 = 0.5 + 0.5 * @sin(d * 8.0 - t * 2.0) * @sin(dx * 4.0 + t) * @sin(dy * 4.0 - t * 1.5);
    const c: u8 = @intFromFloat(std.math.clamp(v * 255, 0, 255));
    return .{ .argb = .{
        .red = c,
        .green = c,
        .blue = c,
        .reserved = 255,
    } };
}

// TODO: Highly inefficient
pub fn renderShader(bitmap: drawing.Bitmap, t: f32, func: *const fn (f32, f32, f32) drawing.Pixel) void {
    var y: f32 = 0;
    while (y < bitmap.height) : (y += 1) {
        var x: f32 = 0;
        while (x < bitmap.width) : (x += 1) {
            bitmap.buffer[@intFromFloat(y * bitmap.stride + x)] = func(x, y, t).argb;
        }
    }
}
