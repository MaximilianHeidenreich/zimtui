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

pub fn draw(self: Box, ctx: Ctx, container: RectU) void {
    _ = self;
    _ = ctx;
    _ = container;
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const RectU = M.math.RectU;
const Ctx = M.views.Ctx;
const CommonViewOpts = M.views.CommonViewOpts;
const View = M.views.View;
const NestedView = M.views.NestedView;
const ViewOpts = M.views.ViewOpts;
