pub const math = @import("math/math.zig");
pub const Io = @import("io.zig");
pub const Event = mibu.events.Event;
pub const views = @import("widgets/views.zig"); // TODO(chore): decide on rename

pub const TUI = struct {
    alloc: Allocator,
    frame_arena: ArenaAllocator,

    stdout_file: File,
    stdin_file: File,
    stdout: *std.Io.Writer,
    stdout_buffer: [1]u8,
    term_handle: mibu.term.RawTerm,
    frame_buffer: FrameBuffer,

    current_bounds: RectU,

    pub fn init(alloc: Allocator, _: anytype) !TUI {
        return .{
            .alloc = alloc,
            .frame_arena = .init(alloc),

            .stdout_file = File.stdout(),
            .stdin_file = File.stdin(),

            .current_bounds = .EMPTY,

            // Will be initialized in `run`.
            .stdout = undefined,
            .stdout_buffer = undefined,
            .term_handle = undefined,
            .frame_buffer = undefined,
        };
    }

    // TODO: fn deinit

    fn handleResize(self: *TUI) !void {
        const actual = try mibu.term.getSize(self.stdout_file.handle);
        if (actual.width != self.current_bounds.max.x or
            actual.height != self.current_bounds.max.y)
        {
            self.current_bounds = .{
                .min = .init(0, 0),
                .max = .init(actual.width, actual.height),
            };
            try self.frame_buffer.resize(actual.width, actual.height);
            try mibu.clear.all(self.stdout);
            try mibu.cursor.hide(self.stdout);
        }
    }

    pub fn run(self: *TUI, view: anytype) !void {
        _ = view;
        // defer self.deinit();

        if (builtin.os.tag == .windows) {
            try mibu.enableWindowsVTS(self.stdout_file.handle);
        }

        var stdout_writer = self.stdout_file.writer(&self.stdout_buffer);
        self.stdout = &stdout_writer.interface;

        self.term_handle = try mibu.term.enableRawMode(self.stdout_file.handle);
        // TODO(err): These patterns need to be stronger.. this aint it!
        defer self.term_handle.disableRawMode() catch
            @panic("Could not exit raw mode correctly!");

        try mibu.cursor.hide(self.stdout);
        defer mibu.cursor.show(self.stdout) catch {};
        try mibu.clear.all(self.stdout);

        const size = try mibu.term.getSize(self.stdout_file.handle);
        self.frame_buffer = try FrameBuffer.init(self.alloc, size.width, size.height);
        defer self.frame_buffer.deinit();

        while (true) {
            // TODO(mem): Maybe we should use a more minimal strategy,
            //  freeying.. lets see how it affects performance in the future!
            _ = self.frame_arena.reset(.retain_capacity);

            // NOTE: We Re-query terminal size every frame to catch all resizes proper;y (Zellij, tmux).
            try self.handleResize();
            self.frame_buffer.clear();
            defer {
                self.frame_buffer.flush(self.stdout) catch
                    @panic("Could not flush!");
                self.stdout.flush() catch
                    @panic("Could not flush!");
            }

            const event = try mibu.events.nextWithTimeout(self.stdin_file, 0);
            switch (event) {
                // NOTE: handled by `checkResize` directly
                .resize => {},
                .key => |k| switch (k.code) {
                    .char => |c| switch (c) {
                        'q' => return,
                        // '0' => self.debug = !self.debug,
                        else => {},
                    },
                    else => {},
                },
                else => {},
            }

            var cw = self.frame_buffer.writer();
            cw.setStyle(.{ .fg = .{ .indexed = .red }, .mods = .{ .bold = true } });
            _ = try cw.write("Hello, World!");
        }
    }

    pub fn deltaTime(self: TUI) f64 {
        return self.frame_buffer.delta_time;
    }
    pub fn fps(self: TUI) f64 {
        return self.frame_buffer.fps;
    }
};

////////////////////////////////////////

const builtin = @import("builtin");
const std = @import("std");
const mibu = @import("mibu");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const File = std.fs.File;
const FrameBuffer = Io.FrameBuffer;
const RectU = math.RectU;
