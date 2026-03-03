//!
//! TODO(docs):
//!
//! TODO(Text):
//!   - Fix text shitty wrap -> unicode `zg` lib exports
//!     a proper wrap function.
//!
//!

const Text = @This();
const Options = ViewOpts(struct {
    wrap: bool = false,
});

pub fn init(
    comptime fmt: []const u8,
    args: anytype,
    opts: Options,
) View(TextT(fmt, @TypeOf(args))) {
    return View(TextT(fmt, @TypeOf(args)))
        .init(.{
        .args = args,
        .wrap = false,
    }, opts);
}

pub fn Label(comptime str: []const u8, opts: Options) View(TextT(str, @TypeOf(.{}))) {
    return TextT(str, @TypeOf(.{})).init(.{}, opts);
}

fn TextT(comptime fmt: []const u8, comptime Args: type) type {
    return struct {
        const Self = @This();

        args: Args,
        wrap: bool,

        pub fn init(
            args: anytype,
            opts: Options,
        ) View(TextT(fmt, @TypeOf(args))) {
            return View(TextT(fmt, @TypeOf(args)))
                .init(.{
                .args = args,
                .wrap = false,
            }, opts);
        }

        pub fn measure(self: Self, _: Ctx, container: RectU) RectU {
            const avail_w = M.math.Axis.x.len(container);
            if (avail_w <= 0) return .{ .min = container.min, .max = container.max };

            const SimWriter = struct {
                w: usize,
                wrap: bool,
                col: usize = 0,
                row: usize = 0,
                max_x: usize = 0,

                fn write(s: *@This(), bytes: []const u8) error{}!usize {
                    var iter = unicode.Utf8View.initUnchecked(bytes).iterator();
                    while (iter.nextCodepoint()) |cp| {
                        if (cp == '\n') {
                            s.max_x = @max(s.max_x, s.col);
                            s.col = 0;
                            s.row += 1;
                            continue;
                        }
                        if (s.col >= s.w) {
                            if (!s.wrap) continue;
                            s.max_x = @max(s.max_x, s.col);
                            s.col = 0;
                            s.row += 1;
                        }
                        s.col += 1;
                    }
                    s.max_x = @max(s.max_x, s.col);
                    return bytes.len;
                }
                fn writer(s: *@This()) std.io.GenericWriter(*@This(), error{}, write) {
                    return .{ .context = s };
                }
            };

            var sim = SimWriter{ .w = avail_w, .wrap = self.wrap };
            std.fmt.format(sim.writer(), fmt, self.args) catch {};

            const rows = sim.row + @intFromBool(sim.col > 0);
            return .{
                .min = container.min,
                .max = .{ .x = container.min.x + sim.max_x, .y = container.min.y + rows },
            };
        }

        pub fn draw(self: Self, ctx: Ctx, writer: *CellWriter) void {
            _ = ctx;
            std.fmt.format(writer.writer(), fmt, self.args) catch {};
        }
    };
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const unicode = std.unicode;
const CellWriter = M.Io.CellWriter;
const RectU = M.math.RectU;
const Border = M.utils.Border;
const Ctx = M.views.Ctx;
const CommonViewOpts = M.views.CommonViewOpts;
const View = M.views.View;
const ViewOpts = M.views.ViewOpts;
