//!
//! Stack layout — stacks children sequentially along a single
//! horizontal or vertical axis.
//!
//! Children can be a comptime tuple of typed views, or a runtime slice
//! of views (e.g. []AnyView) for dynamic configurations.
//!
//! Children with `.size.X/Y = .grow()` share the remaining space equally
//! after fixed children are sized (like "flexbox grow").
//!

const Opts = struct {
    gap: usize = 0,
};

pub fn HStack(
    children: anytype,
    opts: ViewOpts(Opts),
) View(Stack(.x, @TypeOf(children))) {
    return stackInit(.x, children, opts);
}

pub fn VStack(
    children: anytype,
    opts: ViewOpts(Opts),
) View(Stack(.y, @TypeOf(children))) {
    return stackInit(.y, children, opts);
}

fn stackInit(
    comptime axis: Axis,
    children: anytype,
    opts: ViewOpts(Opts),
) View(Stack(axis, @TypeOf(children))) {
    // TODO(misc): the opts thing again
    return View(Stack(axis, @TypeOf(children)))
        .init(.{ .children = children, .gap = 0 }, opts);
}

fn Stack(comptime axis: Axis, comptime Children: type) type {
    comptime switch (@typeInfo(Children)) {
        .@"struct" => |s| {
            if (!s.is_tuple)
                @compileError("Stack(." ++ @tagName(axis) ++ ") children must be a tuple, got: " ++ @typeName(Children));
            for (s.fields) |f|
                if (!isValidView(f.type))
                    @compileError("Stack(." ++ @tagName(axis) ++ ") child '" ++ f.name ++ "' (" ++ @typeName(f.type) ++ ") must implement draw, view, or update");
        },
        .pointer => |p| {
            if (p.size != .slice)
                @compileError("Stack(." ++ @tagName(axis) ++ ") children pointer must be a slice, got: " ++ @typeName(Children));
            if (!isValidView(p.child))
                @compileError("Stack(." ++ @tagName(axis) ++ ") slice element (" ++ @typeName(p.child) ++ ") must implement draw, view, or update");
        },
        else => @compileError("Stack(." ++ @tagName(axis) ++ ") children must be a tuple or a slice of views, got: " ++ @typeName(Children)),
    };

    return struct {
        const Self = @This();

        children: Children,
        gap: usize,

        fn isGrowable(child: anytype) bool {
            const unit = if (axis == .x) child.size.X else child.size.Y;
            return if (unit) |u| switch (u) {
                .Relative => true,
                else => false,
            } else false;
        }

        pub fn update(self: Self, ctx: Ctx, event: Event) bool {
            if (event == .none) return false;

            switch (@typeInfo(Children)) {
                .@"struct" => {
                    inline for (meta.fields(Children)) |f|
                        if (comptime isUpdatable(f.type))
                            if (@field(self.children, f.name).update(ctx, event)) return true;
                },
                .pointer => {
                    for (self.children) |child|
                        if (child.update(ctx, event)) return true;
                },
                else => {},
            }
            return false;
        }

        pub fn measure(self: Self, ctx: Ctx, container: RectU) RectU {
            const cross_ax: Axis = if (axis == .x) .y else .x;
            var main: usize = 0;
            var cross: usize = 0;

            switch (@typeInfo(Children)) {
                .@"struct" => {
                    const FIELDS = meta.fields(Children);

                    inline for (FIELDS) |f| {
                        const cm = @field(self.children, f.name).measure(ctx, container);
                        main = main +| axis.len(cm);
                        cross = @max(cross, cross_ax.len(cm));
                    }

                    const n = comptime FIELDS.len;
                    if (n > 1) main = main +| self.gap * (n - 1);
                },
                .pointer => {
                    for (self.children) |child| {
                        const cm = child.measure(ctx, container);
                        main = main +| axis.len(cm);
                        cross = @max(cross, cross_ax.len(cm));
                    }

                    if (self.children.len > 1) main = main +| self.gap * (self.children.len - 1);
                },
                else => {},
            }

            return if (axis == .x)
                .{ .min = container.min, .max = .{ .x = container.min.x +| main, .y = container.min.y +| cross } }
            else
                .{ .min = container.min, .max = .{ .x = container.min.x +| cross, .y = container.min.y +| main } };
        }

        pub fn draw(self: Self, ctx: Ctx, writer: *CellWriter) void {
            const total_main = if (axis == .x) writer.clip_width else writer.clip_height;
            const total_cross = if (axis == .x) writer.clip_height else writer.clip_width;

            const full = RectU{
                .min = .{ .x = 0, .y = 0 },
                .max = if (axis == .x)
                    .{ .x = total_main, .y = total_cross }
                else
                    .{ .x = total_cross, .y = total_main },
            };

            switch (@typeInfo(Children)) {
                .@"struct" => {
                    const FIELDS = meta.fields(Children);

                    // First pass: sum fixed children, count grow children.
                    var fixed: usize = 0;
                    var grow_count: usize = 0;
                    inline for (FIELDS) |f| {
                        const child = @field(self.children, f.name);
                        if (isGrowable(child))
                            grow_count += 1
                        else
                            fixed = fixed +| axis.len(child.measure(ctx, full));
                    }
                    const n = FIELDS.len;
                    if (n > 1) fixed = fixed +| self.gap * (n - 1);

                    const grow_each = if (grow_count > 0) (total_main -| fixed) / grow_count else 0;

                    var offset: usize = 0;
                    var first = true;
                    inline for (FIELDS) |f| {
                        const child = @field(self.children, f.name);
                        if (!first) offset = offset +| self.gap;
                        first = false;
                        const child_main = if (isGrowable(child)) grow_each else axis.len(child.measure(ctx, full));

                        drawSlot(axis, child, ctx, writer, &offset, child_main, total_cross);
                    }
                },
                .pointer => {
                    var fixed: usize = 0;
                    var grow_count: usize = 0;

                    for (self.children) |child| {
                        if (isGrowable(child))
                            grow_count += 1
                        else
                            fixed = fixed +| axis.len(child.measure(ctx, full));
                    }

                    if (self.children.len > 1) fixed = fixed +| self.gap * (self.children.len - 1);
                    const grow_each = if (grow_count > 0) (total_main -| fixed) / grow_count else 0;
                    var offset: usize = 0;
                    var first = true;
                    for (self.children) |child| {
                        if (!first) offset = offset +| self.gap;
                        first = false;
                        const child_main = if (isGrowable(child)) grow_each else axis.len(child.measure(ctx, full));

                        drawSlot(axis, child, ctx, writer, &offset, child_main, total_cross);
                    }
                },
                else => {},
            }
        }
    };
}

fn drawSlot(
    comptime ax: Axis,
    child: anytype,
    ctx: Ctx,
    writer: *CellWriter,
    offset: *usize,
    child_main: usize,
    total_cross: usize,
) void {
    const slot_w = if (ax == .x) child_main else total_cross;
    const slot_h = if (ax == .x) total_cross else child_main;
    const slot_x = if (ax == .x) offset.* else 0;
    const slot_y = if (ax == .x) 0 else offset.*;

    var slot = writer.subWriter(slot_x, slot_y, slot_w, slot_h);
    const slot_rect = RectU{ .min = .{ .x = 0, .y = 0 }, .max = .{ .x = slot_w, .y = slot_h } };
    const cp = child.place(ctx, slot_rect);
    var ccw = slot.subWriter(cp.min.x, cp.min.y, cp.max.x -| cp.min.x, cp.max.y -| cp.min.y);
    child.draw(ctx, &ccw);

    offset.* = offset.* +| child_main;
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const meta = std.meta;
const RectU = M.math.RectU;
const Axis = M.math.Axis;
const Ctx = M.views.Ctx;
const View = M.views.View;
const ViewOpts = M.views.ViewOpts;
const isValidView = M.views.isValidView;
const isUpdatable = M.views.isUpdatable;
const CellWriter = M.Io.CellWriter;
const Event = M.Event;
