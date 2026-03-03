const std = @import("std");
const zimtui = @import("zimtui");
const TUI = zimtui.TUI;
const Box = zimtui.views.Box;
const Text = zimtui.views.Text;
const Label = zimtui.views.Label;

pub fn main() !void {
    var tui = try TUI.init(std.heap.smp_allocator, .{});
    // var app = App.init();
    // try tui.run(Box(.{}, .{ .size = .fixed(2) }));
    // try tui.run(Label("Hello Kek", .{ .size = .fixed(2) }));
    try tui.run(
        Box(
            Text("Hello: {s}", .{"Fmt!"}, .{}),
            .{ .style = .{ .bg = .{ .indexed = .grey_82 } } },
        ),
    );
}
