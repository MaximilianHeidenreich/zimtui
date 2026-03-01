//!
//! A generic box container with possible children.
//! Allows for easy containment of sub-views and acces
//! to apply styles to all children through the `.style`
//! option. Basically like an HTML `<div>`.
//!

const Box = @This();
const Opts = struct {};

pub fn init(
    children: anytype,
    opts: ViewOpts(Opts),
) NestedView(Box, @TypeOf(children)) {
    // TODO(views): Look into whether we want to support
    // overriding i.e. a custom .style here directly
    // if so we migth need some `merge(.{}, opts)` thing.
    return NestedView(Box, @TypeOf(children))
        .initWithChildren(children, opts);
}

pub fn draw(self: Box, ctx: Ctx, writer: *CellWriter) void {
    _ = self;
    _ = ctx;

    // writer.fill(.{});

    writer.style.bg = .{ .indexed = .grey_89 };
    const cell = M.Io.Cell.initChar(" ", writer.style) catch @panic("foo");
    writer.fill(cell);

    const w = writer.clip_width;
    const h = writer.clip_height;
    if (w < 2 or h < 2) return;

    const bc = Border.chars.get(.rounded).?;

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

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const CellWriter = M.Io.CellWriter;
const RectU = M.math.RectU;
const Border = M.utils.Border;
const Ctx = M.views.Ctx;
const CommonViewOpts = M.views.CommonViewOpts;
const View = M.views.View;
const NestedView = M.views.NestedView;
const ViewOpts = M.views.ViewOpts;
