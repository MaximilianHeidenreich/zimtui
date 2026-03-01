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
};

////////////////////////////////////////

const std = @import("std");
const RectU = @import("math/math.zig").RectU;
