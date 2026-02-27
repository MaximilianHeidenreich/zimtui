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
    // for (0..(writer.clip_width * writer.clip_height)) |_| {
    //     _ = try writer.write("e");
    // }
    const cell = M.Io.Cell.initChar(" ", .{ .bg = .{ .indexed = .grey_85 } }) catch @panic("foo");
    writer.fill(cell);
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const CellWriter = M.Io.CellWriter;
const RectU = M.math.RectU;
const Ctx = M.views.Ctx;
const CommonViewOpts = M.views.CommonViewOpts;
const View = M.views.View;
const NestedView = M.views.NestedView;
const ViewOpts = M.views.ViewOpts;
