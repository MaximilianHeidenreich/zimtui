pub const Io = @import("io.zig");

pub const TUI = struct {
    alloc: Allocator,
    frame_arena: ArenaAllocator,

    stdout_file: File,
    stdin_file: File,
    stdout: *std.Io.Writer,
    stdout_buffer: [1]u8,
    term_handle: mibu.term.RawTerm,
    frame_buffer: FrameBuffer,

    pub fn init(alloc: Allocator, _: anytype) !TUI {
        return .{
            .alloc = alloc,
            .frame_arena = .init(alloc),

            .stdout_file = File.stdout(),
            .stdin_file = File.stdin(),

            // Will be initialized in `run`.
            .stdout = undefined,
            .stdout_buffer = undefined,
            .term_handle = undefined,
            .frame_buffer = undefined,
        };
    }

    // TODO: fn deinit

    pub fn run(self: *TUI) !void {
        // defer self.deinit();

        if (builtin.os.tag == .windows) {
            try mibu.enableWindowsVTS(self.stdout.handle);
        }

        var stdout_writer = self.stdout_file.writer(&self.stdout_buffer);
        self.stdout = &stdout_writer.interface;

        self.term_handle = try mibu.term.enableRawMode(self.stdout_file.handle);
        // TODO(err): These patterns need to be stronger.. this aint it!
        defer self.term_handle.disableRawMode() catch
            @panic("Could not exit raw mode correctly!");
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
