const std = @import("std");
const drawing = @import("drawing.zig");

// Shared helper
inline fn toPixel(v: f32) drawing.Pixel {
    const c: u8 = @intFromFloat(std.math.clamp(v * 255, 0, 255));
    return .{ .argb = .{
        .red = c,
        .green = c,
        .blue = c,
        .reserved = 255,
    } };
}

// Scalar shader
pub fn shaderSineWaveStripes(w: f32, _: f32, x: f32, y: f32, t: f32) drawing.Pixel {
    const STRIPE_FREQ = 0.02 * 1000 / w;
    const v = 0.5 + 0.5 * @sin((x + y) * STRIPE_FREQ + t);
    return toPixel(v);
}

pub fn shaderCheckerboard(_: f32, _: f32, x: f32, y: f32, t: f32) drawing.Pixel {
    const TILE_SIZE = 128.0;
    const CHECKER_FREQ = 0.025;

    const cx: u32 = @intFromFloat(x / TILE_SIZE);
    const cy: u32 = @intFromFloat(y / TILE_SIZE);
    const f: f32 = @floatFromInt((cx + cy) & 1);
    const v = f + 0.5 * @sin(x * CHECKER_FREQ + t) * @sin(y * CHECKER_FREQ + t);
    return toPixel(v);
}

pub fn shaderRadialPlasma(w: f32, _: f32, x: f32, y: f32, t: f32) drawing.Pixel {
    const PLASMA_RADIUS = w / 5;
    const dx = (x - PLASMA_RADIUS) / PLASMA_RADIUS;
    const dy = (y - PLASMA_RADIUS) / PLASMA_RADIUS;
    const d = @sqrt(dx * dx + dy * dy);
    const v = 0.5 + 0.5 * @sin(d * 8.0 - t * 2.0) * @sin(dx * 4.0 + t) * @sin(dy * 4.0 - t * 1.5);
    return toPixel(v);
}

// Scalar render: comptime generic (hopefully allowing LLVM to inline and auto-vec)
pub fn renderScalar(comptime shader: anytype, bitmap: drawing.Bitmap, t: f32) void {
    const buffer: [*]u32 = @ptrCast(@alignCast(bitmap.buffer));
    const width: usize = @intFromFloat(bitmap.width);
    const height: usize = @intFromFloat(bitmap.height);
    const stride: usize = @intFromFloat(bitmap.stride);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            buffer[y * stride + x] = shader(bitmap.width, bitmap.height, @floatFromInt(x), @floatFromInt(y), t).int;
        }
    }
}
