//!
//! Built in inspector overlay displaying debug information about
//! performance, views, focus etc.
//!

const Inspector = @This();
const Opts = struct {};

pub fn init(
    opts: ViewOpts(Opts),
) View(Inspector) {
    return View(Inspector)
        .init(.{}, opts);
}

pub fn view(_: Inspector, ctx: Ctx) AnyView {
    return ctx.widget(
        VStack(
            .{
                Label("zimtui – v0.0.0", .{}),
                Text("FPS: {d:>5.0}\ndt: {d:>2.2}ms\n", .{
                    ctx.tui.fps(),
                    ctx.tui.deltaTime(),
                }, .{}),
            },
            .{
                .gap = 1,
                .border = .dashed,
                .padding = .axes(1, 0),
                .size = .y(.grow()),
                .style = .{ .bg = .{ .indexed = .grey_93 } },
            },
        ),
    );
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const Cell = M.Io.Cell;
const CellWriter = M.Io.CellWriter;
const RectU = M.math.RectU;
const Border = M.utils.Border;
const Ctx = M.views.Ctx;
const CommonViewOpts = M.views.CommonViewOpts;
const View = M.views.View;
const ViewOpts = M.views.ViewOpts;
const AnyView = M.views.AnyView;

const VStack = M.views.VStack;
const Box = M.views.Box;
const Label = M.views.Label;
const Text = M.views.Text;
