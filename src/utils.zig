pub fn MergeT(comptime A: type, comptime B: type) type {
    const a = meta.fields(A);
    const b = meta.fields(B);

    var fields: [b.len + a.len]builtin.Type.StructField = undefined;
    for (a, 0..) |f, i| fields[i] = f;
    for (b, 0..) |f, i| fields[a.len + i] = f;
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub const Border = enum {
    none,
    thin_box,
    rounded,
    thick,
    double_box,
    double_top,
    ascii,
    dashed,
    dashed_thick,

    const Chars = struct { tl: u21, tr: u21, bl: u21, br: u21, h: u21, v: u21 };

    pub fn resolve(self: Border, rect: RectU) RectU {
        return if (self != .none) rect.inset(1) else rect;
    }

    pub fn thickness(self: Border) usize {
        return if (self != .none) 1 else 0;
    }

    pub const chars = std.EnumArray(Border, ?Chars).init(.{
        .none = null,
        .thin_box = .{ .tl = '┌', .tr = '┐', .bl = '└', .br = '┘', .h = '─', .v = '│' },
        .rounded = .{ .tl = '╭', .tr = '╮', .bl = '╰', .br = '╯', .h = '─', .v = '│' },
        .thick = .{ .tl = '┏', .tr = '┓', .bl = '┗', .br = '┛', .h = '━', .v = '┃' },
        .double_box = .{ .tl = '╔', .tr = '╗', .bl = '╚', .br = '╝', .h = '═', .v = '║' },
        .double_top = .{ .tl = '╒', .tr = '╕', .bl = '╘', .br = '╛', .h = '═', .v = '│' },
        .ascii = .{ .tl = '+', .tr = '+', .bl = '+', .br = '+', .h = '-', .v = '|' },
        .dashed = .{ .tl = '┌', .tr = '┐', .bl = '└', .br = '┘', .h = '┄', .v = '┆' },
        .dashed_thick = .{ .tl = '┏', .tr = '┓', .bl = '┗', .br = '┛', .h = '┅', .v = '┇' },
    });

    pub fn write(self: Border, writer: *CellWriter) void {
        if (self == .none) return;

        const w = writer.clip_width;
        const h = writer.clip_height;
        if (w < 2 or h < 2) return;

        const bc = Border.chars.get(self).?;

        writer.put(0, 0, .{ .code = bc.tl });
        writer.put(w - 1, 0, .{ .code = bc.tr });
        writer.put(0, h - 1, .{ .code = bc.bl });
        writer.put(w - 1, h - 1, .{ .code = bc.br });

        for (1..w - 1) |x| {
            writer.put(x, 0, .{ .code = bc.h });
            writer.put(x, h - 1, .{ .code = bc.h });
        }
        for (1..h - 1) |y| {
            writer.put(0, y, .{ .code = bc.v });
            writer.put(w - 1, y, .{ .code = bc.v });
        }
    }
};

////////////////////////////////////////

const std = @import("std");
const builtin = std.builtin;
const meta = std.meta;
const RectU = @import("math/math.zig").RectU;
const M = @import("root.zig");
const CellWriter = M.Io.CellWriter;
