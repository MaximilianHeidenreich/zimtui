//!
//!
//!

const Box = @This();
const Opts = struct {
    title: []const u8 = "",
};

pub fn init(opts: ViewOpts(Opts)) View(Box) {
    // TODO(views): Look into whether we want to support
    // overriding i.e. a custom .style here directly
    // if so we migth need some `merge(.{}, opts)` thing.
    return View(Box).init(opts);
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
const ViewOpts = M.views.ViewOpts;
