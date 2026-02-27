//!
//! foo
//!

/// Used to style individual term cells.
/// TODO: Efficient diffing
pub const CellStyle = struct {
    pub const Color = union(enum) {
        default,
        indexed: color.Color,
        rgb: struct { r: u8, g: u8, b: u8 },
    };

    pub const Modifiers = packed struct(u8) {
        bold: bool = false,
        dim: bool = false,
        italic: bool = false,
        underline: bool = false,
        blinking: bool = false,
        reverse: bool = false,
        invisible: bool = false,
        strikethrough: bool = false,
    };

    fg: Color = .default,
    bg: Color = .default,
    mods: Modifiers = .{},

    pub fn getDiff(self: CellStyle, other: CellStyle) void {
        _ = self;
        _ = other;
        // TODO: In the future emit exactly the escape code diff we need to be able to go from self to other
    }
};

pub const Cell = struct {
    code: u21 = ' ',

    /// TODO: describe better
    /// null -> no change, inherit
    /// .{} -> defautl style reset
    style: ?CellStyle = null,

    /// Creates a Cell from a single given char, will fail if char is longer
    /// than one codepoint. Will be replaced with full unicode support later.
    pub fn initChar(comptime char: []const u8, style: ?CellStyle) !Cell {
        assert(std.unicode.utf8ValidateSlice(char));
        const view = try std.unicode.Utf8View.init(char);
        var iter = view.iterator();
        while (iter.nextCodepoint()) |u| {
            // if (iter.nextCodepoint() != null)
            //     @compileError("Full unicode not yet supported!");
            return .{ .code = u, .style = style };
        }
        return error.TODO;
    }
};

////////////////////////////////////////

pub const FrameBuffer = struct {
    alloc: Allocator,
    width: usize,
    height: usize,
    front: []Cell,
    back: []Cell,

    /// DeltaTime in Milliseconds between flush() calls
    delta_time: f64,
    fps: f64,
    last_time: i128,

    pub fn init(alloc: Allocator, width: usize, height: usize) !FrameBuffer {
        const SIZE = width * height;
        const front = try alloc.alloc(Cell, SIZE);
        const back = try alloc.alloc(Cell, SIZE);

        @memset(front, Cell{});
        @memset(back, Cell{});

        return .{
            .alloc = alloc,
            .width = width,
            .height = height,
            .front = front,
            .back = back,

            .last_time = nanoTimestamp(),
            .delta_time = undefined,
            .fps = undefined,
        };
    }

    pub fn deinit(self: *FrameBuffer) void {
        self.alloc.free(self.front);
        self.alloc.free(self.back);
    }

    pub fn resize(self: *FrameBuffer, width: usize, height: usize) !void {
        const SIZE = width * height;
        self.front = try self.alloc.realloc(self.front, SIZE);
        self.back = try self.alloc.realloc(self.back, SIZE);
        @memset(self.front, Cell{});
        @memset(self.back, Cell{});
        self.width = width;
        self.height = height;
    }

    pub fn clear(self: *FrameBuffer) void {
        @memset(self.back, Cell{});
    }

    pub fn swap(self: *FrameBuffer) void {
        std.mem.swap([]Cell, &self.front, &self.back);
    }

    pub fn getCell(self: *FrameBuffer, x: usize, y: usize) ?*Cell {
        if (x >= self.width or y >= self.height) return null;
        return &self.back[y * self.width + x];
    }

    pub fn writer(self: *FrameBuffer) CellWriter {
        return CellWriter.init(self);
    }

    /// Returns true if a full reset was emitted (colors also wiped on terminal).
    fn emitStyle(w: anytype, from: CellStyle.Modifiers, to: CellStyle.Modifiers) !bool {
        const fi: u8 = @bitCast(from);
        const ti: u8 = @bitCast(to);
        if (fi == ti) return false;

        if (fi & ~ti != 0) {
            // something turning off — reset all then re-apply what's still on
            try w.writeAll(seq_reset);
            if (to.bold) try w.writeAll(mibu.style.print.bold);
            if (to.dim) try w.writeAll(mibu.style.print.dim);
            if (to.italic) try w.writeAll(mibu.style.print.italic);
            if (to.underline) try w.writeAll(mibu.style.print.underline);
            if (to.blinking) try w.writeAll(mibu.style.print.blinking);
            if (to.reverse) try w.writeAll(mibu.style.print.reverse);
            if (to.invisible) try w.writeAll(mibu.style.print.invisible);
            if (to.strikethrough) try w.writeAll(mibu.style.print.strikethrough);
            return true;
        } else {
            // only turning on — emit just the new ones
            if (to.bold and !from.bold) try w.writeAll(mibu.style.print.bold);
            if (to.dim and !from.dim) try w.writeAll(mibu.style.print.dim);
            if (to.italic and !from.italic) try w.writeAll(mibu.style.print.italic);
            if (to.underline and !from.underline) try w.writeAll(mibu.style.print.underline);
            if (to.blinking and !from.blinking) try w.writeAll(mibu.style.print.blinking);
            if (to.reverse and !from.reverse) try w.writeAll(mibu.style.print.reverse);
            if (to.invisible and !from.invisible) try w.writeAll(mibu.style.print.invisible);
            if (to.strikethrough and !from.strikethrough) try w.writeAll(mibu.style.print.strikethrough);
            return false;
        }
    }

    fn emitColor(w: anytype, comptime ground: enum { fg, bg }, from: CellStyle.Color, to: CellStyle.Color) !void {
        if (std.meta.eql(from, to)) return;
        switch (to) {
            .default => try w.writeAll(if (ground == .fg) mibu.utils.csi ++ "39m" else mibu.utils.csi ++ "49m"),
            .indexed => |c| if (ground == .fg) try color.fg256(w, c) else try color.bg256(w, c),
            .rgb => |c| if (ground == .fg) try color.fgRGB(w, c.r, c.g, c.b) else try color.bgRGB(w, c.r, c.g, c.b),
        }
    }

    pub fn flush(self: *FrameBuffer, w: anytype) !void {
        var cur_x: usize = std.math.maxInt(usize);
        var cur_y: usize = std.math.maxInt(usize);
        var cur_mods: CellStyle.Modifiers = .{};
        var cur_fg: CellStyle.Color = .default;
        var cur_bg: CellStyle.Color = .default;

        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const idx = y * self.width + x;
                const front_cell = self.front[idx];
                const back_cell = self.back[idx];

                // Skip if cell hasn't changed
                if (front_cell.code == back_cell.code and
                    std.meta.eql(front_cell.style, back_cell.style)) continue;

                // Move cursor if needed
                if (cur_y != y or cur_x != x) {
                    try cursor.goTo(w, x + 1, y + 1);
                }

                // Emit style changes (modifiers)
                const style = back_cell.style orelse CellStyle{};
                if (try emitStyle(w, cur_mods, style.mods)) {
                    // Full reset was emitted — terminal colors are back to default
                    cur_fg = .default;
                    cur_bg = .default;
                }
                cur_mods = style.mods;

                // Emit color changes
                try emitColor(w, .fg, cur_fg, style.fg);
                try emitColor(w, .bg, cur_bg, style.bg);
                cur_fg = style.fg;
                cur_bg = style.bg;

                // Write the character
                var utf8_buf: [4]u8 = undefined;
                const len = try std.unicode.utf8Encode(back_cell.code, &utf8_buf);
                try w.writeAll(utf8_buf[0..len]);

                // Update front buffer
                self.front[idx] = back_cell;

                cur_x = x + 1;
                cur_y = y;
            }
        }

        // Clean styles after frame
        const was_styled = @as(u8, @bitCast(cur_mods)) != 0 or
            !std.meta.eql(cur_fg, CellStyle.Color.default) or
            !std.meta.eql(cur_bg, CellStyle.Color.default);
        if (was_styled) try w.writeAll(seq_reset);

        // Update timing info
        const now = nanoTimestamp();
        const dt_ns = now - self.last_time;
        self.last_time = now;
        self.delta_time = @as(f64, @floatFromInt(dt_ns)) / std.time.ns_per_ms;
        self.fps = if (self.delta_time > 0) 1000.0 / self.delta_time else 0;
    }
};

////////////////////////////////////////

pub const CellWriter = struct {
    buffer: *FrameBuffer,
    x: usize,
    y: usize,
    clip_x: usize,
    clip_y: usize,
    clip_width: usize,
    clip_height: usize,
    style: CellStyle,

    pub fn init(buffer: *FrameBuffer) CellWriter {
        return .{
            .buffer = buffer,
            .x = 0,
            .y = 0,
            .clip_x = 0,
            .clip_y = 0,
            .clip_width = buffer.width,
            .clip_height = buffer.height,
            .style = .{},
        };
    }

    /// Create a sub-writer with a clipped region
    /// x, y are relative to the parent's clip region
    /// width, height define the size of the sub-region
    pub fn subWriter(self: *CellWriter, x: usize, y: usize, width: usize, height: usize) CellWriter {
        var sub = self.*;

        const abs_x = self.clip_x + x;
        const abs_y = self.clip_y + y;
        const parent_right = self.clip_x + self.clip_width;
        const parent_bottom = self.clip_y + self.clip_height;

        sub.clip_x = @min(abs_x, parent_right);
        sub.clip_y = @min(abs_y, parent_bottom);
        const available_width = if (abs_x < parent_right) parent_right - abs_x else 0;
        const available_height = if (abs_y < parent_bottom) parent_bottom - abs_y else 0;
        sub.clip_width = @min(width, available_width);
        sub.clip_height = @min(height, available_height);

        sub.x = sub.clip_x;
        sub.y = sub.clip_y;

        return sub;
    }

    /// Set cursor pos (relative to clip region)
    pub fn setCursor(self: *CellWriter, x: usize, y: usize) void {
        const abs_x = self.clip_x + x;
        const abs_y = self.clip_y + y;

        // Crash in debug build on out-of-bounds cursor positioning
        // TODO(io): This might not be what we actually want.. lets see
        assert(abs_x < self.clip_x + self.clip_width);
        assert(abs_y < self.clip_y + self.clip_height);

        self.x = abs_x;
        self.y = abs_y;
    }

    /// Set colors for subsequent writes
    /// TODO(io): maybe we nuke this and just set foo.style = .{}
    /// seems simpler.. lets see
    pub fn setStyle(self: *CellWriter, style: CellStyle) void {
        self.style = style;
    }

    /// Check if position is within clip region
    fn isInClipRegion(self: *CellWriter, x: usize, y: usize) bool {
        return x >= self.clip_x and x < self.clip_x + self.clip_width and
            y >= self.clip_y and y < self.clip_y + self.clip_height;
    }

    /// Write a single codepoint at current cursor position
    /// Future: This will handle wcwidth for wide characters
    pub fn writeCodepoint(self: *CellWriter, codepoint: u21) !void {
        if (!self.isInClipRegion(self.x, self.y)) {
            self.x += 1;
            return;
        }

        if (self.buffer.getCell(self.x, self.y)) |cell| {
            cell.* = .{
                .code = codepoint,
                .style = self.style,
            };
        }

        self.x += 1;
    }

    /// Write UTF-8 bytes as cells
    pub fn write(self: *CellWriter, bytes: []const u8) !usize {
        var written: usize = 0;
        var view = std.unicode.Utf8View.init(bytes) catch return written;
        var iter = view.iterator();

        while (iter.nextCodepoint()) |codepoint| {
            try self.writeCodepoint(codepoint);
            written += std.unicode.utf8CodepointSequenceLength(codepoint) catch 1;
        }

        return written;
    }

    pub fn fill(self: *CellWriter, cell: Cell) void {
        const resolved: Cell = .{
            .code = cell.code,
            .style = cell.style orelse self.style,
        };

        for (0..self.clip_height) |row| {
            const start = (self.clip_y + row) * self.buffer.width + self.clip_x;
            @memset(self.buffer.back[start .. start + self.clip_width], resolved);
        }
    }

    // TODO(misc): is put the best name?
    pub fn put(self: *CellWriter, x: usize, y: usize, cell: Cell) void {
        if (x >= self.clip_width or y >= self.clip_height) return;
        self.buffer.back[(self.clip_y + y) * self.buffer.width + self.clip_x + x] = .{
            .code = cell.code,
            .style = cell.style orelse self.style,
        };
    }

    /// Get a std.io.Writer interface
    pub fn stdWriter(self: *CellWriter) std.io.Writer(*CellWriter, error{}, write) {
        return .{ .context = self };
    }
};

////////////////////////////////////////

const std = @import("std");
const mibu = @import("mibu");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const nanoTimestamp = std.time.nanoTimestamp;

const color = mibu.color;
const cursor = mibu.cursor;

// Add this constant near the top
const seq_reset = mibu.utils.csi ++ "0m";
