//!
//!
//!

pub const Box = @import("Box.zig").init;
pub const Text = @import("Text.zig").init;
pub const Label = @import("Text.zig").Label;
pub const Inspector = @import("Inspector.zig").init;

fn isUpdatable(comptime T: type) bool {
    return meta.hasMethod(T, "update");
}

fn isDrawable(comptime T: type) bool {
    return meta.hasMethod(T, "draw");
}

fn isMeasurable(comptime T: type) bool {
    return meta.hasMethod(T, "measure");
}

fn isViewable(comptime T: type) bool {
    return meta.hasMethod(T, "view") or @hasDecl(T, "view");
}

fn isValidView(comptime T: type) bool {
    return isDrawable(T) or isViewable(T) or isUpdatable(T);
}

pub const Ctx = struct {
    tui: *TUI,

    // TODO(misc): is alloc clear enough in the context or do we keep alloc_frame
    // to make it clear this is a per-frame allocator?
    alloc_frame: Allocator,

    pub fn init(tui: *TUI) Ctx {
        return .{
            .tui = tui,
            .alloc_frame = tui.frame_arena.allocator(),
        };
    }

    /// Creates a dynamic widget at runtime.
    /// NOTE: This uses the frame-local allocator!
    pub fn widget(self: Ctx, view: anytype) AnyView {
        return AnyView.init(self.alloc_frame, view);
    }
};

pub fn View(comptime V: type) type {
    return NestedView(V, void);
}

///
/// Children can be specified as:
///   - A view implementation -> struct {}
///   - A pointer to a view implementation -> *struct {}
///   - A tuple of elements -> .{ Text(...), Label(...) }
///
pub fn NestedView(comptime V: type, comptime Children: type) type {
    comptime {
        if (!isValidView(V))
            @compileError("view (" ++ @typeName(V) ++ ") must implement at least one of: draw, view, update");

        switch (@typeInfo(Children)) {
            .void => {},
            .@"struct" => |s| {
                if (s.is_tuple) {
                    for (s.fields) |f| {
                        if (!isValidView(f.type))
                            @compileError("View tuple child '" ++ f.name ++ "' (" ++ @typeName(f.type) ++ ") must implement at least one of: draw, view, update");
                    }
                } else {
                    if (!isValidView(Children))
                        @compileError("View Children (" ++ @typeName(Children) ++ ") must implement at least one of: draw, view, update");
                }
            },
            .pointer => |p| {
                if (p.size != .slice)
                    @compileError("View Children pointer must be a slice, got: " ++ @typeName(Children));
                if (!isValidView(p.child))
                    @compileError("View slice element (" ++ @typeName(p.child) ++ ") must implement at least one of: draw, view, update");
            },
            else => @compileError("unsupported view Children type: " ++ @typeName(Children)),
        }
    }
    return struct {
        const Self = @This();

        view: V,
        children: Children,

        style: CellStyle,
        size: UnitVec2,
        pos: UnitVec2,
        padding: InsetsU,
        margin: InsetsU,
        border: Border,

        /// Create a View with no children. For `NestedView`, use `initWithChildren`.
        pub fn init(view: V, opts: anytype) Self {
            return initWithChildren({}, view, opts);
        }

        pub fn initWithChildren(children: Children, view: V, opts: anytype) Self {
            var self: Self = .{
                .view = view,
                .children = children,
                .style = .{},
                .size = .{},
                .pos = .{},
                .padding = .{},
                .margin = .{},
                .border = .none,
            };

            // Populate view fields from opts (none-common)
            inline for (meta.fields(V)) |f| {
                if (!@hasField(CommonViewOpts, f.name) and @hasField(@TypeOf(opts), f.name))
                    @field(self.view, f.name) = @field(opts, f.name);
            }

            // Populate common view fields from opts
            inline for (meta.fields(CommonViewOpts)) |f|
                @field(self, f.name) = @field(opts, f.name);

            return self;
        }

        /// Passes `event` down the tree to all children.
        /// |> `true` - Event got consumed, stops propagation.
        /// |> `false` - Event not consumed, continue propagation.
        pub fn update(self: Self, ctx: Ctx, event: Event) bool {
            if (event == .none) return false;

            const consumed: bool = switch (comptime @typeInfo(Children)) {
                .@"struct" => |s| blk: {
                    if (s.is_tuple) {
                        inline for (meta.fields(Children)) |f| {
                            if (comptime isUpdatable(f.type))
                                if (@field(self.children, f.name).update(ctx, event))
                                    break :blk true;
                        }
                    } else {
                        if (comptime isUpdatable(Children))
                            break :blk self.children.update(ctx, event);
                    }
                    break :blk false;
                },
                .pointer => blk: {
                    if (comptime isUpdatable(@typeInfo(Children).pointer.child))
                        for (self.children) |c|
                            if (c.update(ctx, event))
                                break :blk true;

                    break :blk false;
                },

                else => false,
            };
            if (consumed) return true;
            if (comptime isUpdatable(V))
                // ctx.initWIthFocusId(self.focus_id)
                return self.view.update(ctx, event)
            else if (comptime isViewable(V))
                return self.view.view(ctx).update(ctx, event)
            else
                return false;
        }

        pub fn measure(self: Self, ctx: Ctx, container: RectU) RectU {
            const inner = self.padding.resolve(
                self.border.resolve(
                    self.margin.resolve(container),
                ),
            );
            const content = if (comptime isMeasurable(V))
                self.view.measure(ctx, inner)
            else if (comptime isViewable(V))
                self.view.view(ctx).measure(ctx, inner)
            else switch (comptime @typeInfo(Children)) {
                .void => inner,
                .@"struct" => |s| blk: {
                    if (!s.is_tuple) {
                        break :blk if (comptime isMeasurable(Children))
                            self.children.measure(ctx, inner)
                        else
                            inner;
                    }
                    var result = RectU.EMPTY;
                    inline for (meta.fields(Children)) |f| {
                        if (comptime isMeasurable(f.type)) {
                            result = result.merge(@field(self.children, f.name).measure(ctx, inner));
                        }
                    }
                    break :blk if (result.isValid()) result else inner;
                },
                .pointer => blk: {
                    if (comptime !isMeasurable(@typeInfo(Children).pointer.child))
                        break :blk inner;
                    var result = RectU.EMPTY;
                    for (self.children) |child|
                        result = result.merge(child.measure(ctx, inner));
                    break :blk if (result.isValid()) result else inner;
                },
                else => inner,
            };

            return InsetsU.all(self.border.thickness()).expand(self.padding.expand(content));
        }

        pub fn layout(self: Self, ctx: Ctx, placed: RectU) RectU {
            const content = self.padding.resolve(self.border.resolve(placed));
            if (comptime meta.hasMethod(V, "layout"))
                self.view.layout(ctx, content);
            return content;
        }

        pub fn place(self: Self, ctx: Ctx, container: RectU) RectU {
            const natural = self.measure(ctx, container);
            const sized_rect = natural.sized(container, self.size.X, self.size.Y);

            if (self.pos.X == null and self.pos.Y == null) return sized_rect;

            const w = sized_rect.max.x -| sized_rect.min.x;
            const h = sized_rect.max.y -| sized_rect.min.y;
            const origin = self.pos.resolveBase(container);

            return .{
                .min = origin.min,
                .max = .{
                    .x = origin.min.x +| w,
                    .y = origin.min.y +| h,
                },
            };
        }

        pub fn draw(self: Self, ctx: Ctx, writer: *CellWriter) void {
            writer.style = self.style.apply(writer.style);

            writer.fill(.{ .code = ' ', .style = writer.style });
            self.border.write(writer);

            const placed = RectU{
                .min = .{ .x = 0, .y = 0 },
                .max = .{ .x = writer.clip_width, .y = writer.clip_height },
            };
            const content = self.layout(ctx, placed);
            var cw = writer.subWriter(
                content.min.x,
                content.min.y,
                content.max.x -| content.min.x,
                content.max.y -| content.min.y,
            );

            // TODO(err): Do we rly only want to support either one? Any case for
            //            both to be valid?
            comptime if (isDrawable(V) and isViewable(V))
                @compileError(@typeName(V) ++ ": implement either `draw` or `view`, not both");

            if (comptime isDrawable(V))
                self.view.draw(ctx, &cw)
            else if (comptime isViewable(V))
                self.view.view(ctx).draw(ctx, &cw);

            const child_container = RectU{
                .min = .{ .x = 0, .y = 0 },
                .max = .{ .x = cw.clip_width, .y = cw.clip_height },
            };

            switch (comptime @typeInfo(Children)) {
                .void => {},
                .@"struct" => |s| {
                    if (s.is_tuple) {
                        inline for (meta.fields(Children)) |f| {
                            if (comptime isDrawable(f.type)) {
                                const child = @field(self.children, f.name);
                                const cp = child.place(ctx, child_container);
                                var ccw = cw.subWriter(cp.min.x, cp.min.y, cp.max.x -| cp.min.x, cp.max.y -| cp.min.y);
                                child.draw(ctx, &ccw);
                            }
                        }
                    } else {
                        if (comptime isDrawable(Children)) {
                            const cp = self.children.place(ctx, child_container);
                            var ccw = cw.subWriter(cp.min.x, cp.min.y, cp.max.x -| cp.min.x, cp.max.y -| cp.min.y);
                            self.children.draw(ctx, &ccw);
                        }
                    }
                },
                .pointer => {
                    if (comptime isDrawable(@typeInfo(Children).pointer.child)) {
                        for (self.children) |child| {
                            const cp = child.place(ctx, child_container);
                            var ccw = cw.subWriter(cp.min.x, cp.min.y, cp.max.x -| cp.min.x, cp.max.y -| cp.min.y);
                            child.draw(ctx, &ccw);
                        }
                    }
                },
                else => {},
            }
        }
    };
}

pub const AnyView = struct {
    ptr: *anyopaque,
    updateFn: *const fn (*anyopaque, Ctx, Event) bool,
    drawFn: *const fn (*anyopaque, Ctx, *CellWriter) void,
    measureFn: *const fn (*anyopaque, Ctx, RectU) RectU,

    /// IMPORTANT: Intended to be used with a per-frame allocator!
    /// Immediate mode means none of the widgets hang around for
    /// longer. This also makes memory management for
    /// these dynamic Views pretty trivial.
    pub fn init(alloc: Allocator, view: anytype) AnyView {
        const T = @TypeOf(view);
        const ptr = alloc.create(T) catch @panic("AnyView.init: out of memory");
        ptr.* = view;
        return .{
            .ptr = ptr,
            .updateFn = struct {
                fn f(p: *anyopaque, ctx: Ctx, event: Event) bool {
                    if (event == .none) return false;
                    const w: *T = @ptrCast(@alignCast(p));
                    return if (comptime isUpdatable(T)) w.update(ctx, event) else false;
                }
            }.f,
            .drawFn = struct {
                fn f(p: *anyopaque, ctx: Ctx, writer: *CellWriter) void {
                    const w: *T = @ptrCast(@alignCast(p));
                    if (comptime isDrawable(T)) w.draw(ctx, writer);
                }
            }.f,
            .measureFn = struct {
                fn f(p: *anyopaque, ctx: Ctx, container: RectU) RectU {
                    const w: *T = @ptrCast(@alignCast(p));
                    return if (comptime isMeasurable(T)) w.measure(ctx, container) else container;
                }
            }.f,
        };
    }

    pub fn update(self: AnyView, ctx: Ctx, event: Event) bool {
        return self.updateFn(self.ptr, ctx, event);
    }
    pub fn draw(self: AnyView, ctx: Ctx, writer: *CellWriter) void {
        self.drawFn(self.ptr, ctx, writer);
    }
    pub fn measure(self: AnyView, ctx: Ctx, container: RectU) RectU {
        return self.measureFn(self.ptr, ctx, container);
    }
};

////////////////////////////////////////

/// Generates a random id which is unique to the @returnAddress() of the caller.
/// Use custom index param to generate ids inside dynamic loops.
///
/// Usage:
/// TODO(views): foo
///
/// IMPORTANT: Callsite needs to have `noinline` for this to
///            function properly!
pub inline fn widgetId(index: usize) usize {
    return std.hash.Wyhash.hash(@returnAddress(), std.mem.asBytes(&index));
}

// TODO(views): maybe find a better name
// TODO(views): decide whether to have the `style` field
// as a seperate struct or directly on the opts.
pub const CommonViewOpts = struct {
    style: CellStyle = .{},
    size: UnitVec2 = .{},
    padding: InsetsU = .{},
    margin: InsetsU = .{},
    border: Border = .none,
    // focus_id: ?usize = null,
};

pub fn ViewOpts(comptime Opts: type) type {
    return MergeT(Opts, CommonViewOpts);
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");

const builtin = std.builtin;
const meta = std.meta;
const Allocator = std.mem.Allocator;
const TUI = M.TUI;
const math = M.math;
const RectU = math.RectU;
const UnitVec2 = math.UnitVec2;
const InsetsU = math.InsetsU;
const MergeT = M.utils.MergeT;
const Border = M.utils.Border;

const CellStyle = M.Io.CellStyle;
const CellWriter = M.Io.CellWriter;
const Event = M.Event;
