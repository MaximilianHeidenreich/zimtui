const std = @import("std");
const zimtui = @import("zimtui");
const TUI = zimtui.TUI;

pub fn main() !void {
    var tui = try TUI.init(std.heap.smp_allocator, .{});
    // var app = App.init();
    try tui.run();
}
