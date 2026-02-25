//!
//!
//!

pub const Box = @import("Box.zig").init;

fn isUpdatable(comptime T: type) bool {
    return meta.hasMethod(T, "update");
}

fn isDrawable(comptime T: type) bool {
    return meta.hasMethod(T, "draw");
}

fn isViewable(comptime T: type) bool {
    return meta.hasMethod(T, "view") or @hasDecl(T, "view");
}

fn isValidView(comptime T: type) bool {
    return isDrawable(T) or isViewable(T) or isUpdatable(T);
}

pub const Ctx = struct { tui: TUI };

pub fn View(comptime V: type) type {
    return NestedView(V, null);
}

///
/// Children can be specified as:
///   - A view implementation -> struct {}
///   - A pointer to a view implementation -> *struct {}
///   - A tuple of elements -> .{ Text(...), Label(...) }
///
pub fn NestedView(comptime V: type, comptime Children: ?type) type {
    if (!isValidView(V))
        @compileError("view (" ++ @typeName(V) ++ ") must implement at least one of: draw, view, update");

    if (Children) |C| {
        switch (@typeInfo(C)) {
            .@"struct" => |s| {
                if (s.is_tuple) {
                    inline for (s.fields) |f| {
                        if (!isValidView(f.type))
                            @compileError("View tuple child '" ++ f.name ++ "' (" ++ @typeName(f.type) ++ ") must implement at least one of: draw, view, update");
                    }
                } else {
                    if (!isValidView(C))
                        @compileError("View Children (" ++ @typeName(C) ++ ") must implement at least one of: draw, view, update");
                }
            },
            .pointer => |p| {
                if (p.size != .slice)
                    @compileError("View Children pointer must be a slice, got: " ++ @typeName(C));
                if (!isValidView(p.child))
                    @compileError("View slice element (" ++ @typeName(p.child) ++ ") must implement at least one of: draw, view, update");
            },
            else => @compileError("unsupported view Children type: " ++ @typeName(C)),
        }
    }

    return struct {
        const Self = @This();

        view: V,
        children: Children,

        style: CellStyle,
        size: UnitVec2,

        /// Create a View with options. The opts are custom ones or
        /// can be overrides for the `CommonViewOpts` on all views.
        pub fn init(opts: anytype) Self {
            var self: Self = .{
                .style = .{},
                .size = .{},
            };

            // Pass through any common fields to self
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
            if (isUpdatable(V))
                // ctx.initWIthFocusId(self.focus_id)
                return self.view.update(ctx, event)
            else
                return false;
        }

        pub fn draw(self: Self, ctx: Ctx, container: RectU) void {
            _ = self;
            _ = ctx;
            _ = container;
        }

        pub fn measure(self: Self, ctx: Ctx, parent: RectU) RectU {
            _ = self;
            _ = ctx;
            _ = parent;
        }
    };
}

pub const AnyView = struct {
    ptr: *anyopaque,
    updateFn: *const fn (*anyopaque, Ctx, Event) bool,
    drawFn: *const fn (*anyopaque, Ctx, RectU) bool,
    // measure?

    /// IMPORTANT: Intented to be used with a per-frame allocator!
    /// Immediate mode means none of the widgets hang around for
    /// longer. This also makes memory management for
    /// these dynamic Views pretty trivial.
    pub fn init(alloc: Allocator, view: anytype) AnyView {
        const T = @TypeOf(view);
        // TODO(views): Pass up error
        const ptr = alloc.create(T) catch @panic("AnyView.from: out of memory");
        ptr.* = view;
        return .{
            .ptr = ptr,
            .updateFn = struct {
                fn f(p: *anyopaque, ctx: Ctx, event: Event) bool {
                    if (event == .none) return false;
                    const w: *T = @ptrCast(@alignCast(p));
                    return if (isUpdatable(T))
                        w.update(ctx, event)
                    else
                        false;
                }
            }.f,
            .drawFn = struct {
                fn f(p: *anyopaque, ctx: Ctx, rect: RectU) void {
                    const w: *T = @ptrCast(@alignCast(p));
                    w.draw(ctx, rect);
                }
            }.f,

            // .measureFn = struct {
            //     fn f(p: *anyopaque, ctx: Ctx, parent: RectU) RectU {
            //         const w: *T = @ptrCast(@alignCast(p));
            //         return if (@hasDecl(T, "measure")) w.measure(ctx, parent) else parent;
            //     }
            // }.f,
        };
    }

    pub fn update(self: AnyView, ctx: Ctx, event: Event) bool {
        return self.updateFn(self.ptr, ctx, event);
    }
    pub fn draw(self: AnyView, ctx: Ctx, rect: RectU) void {
        self.drawFn(self.ptr, ctx, rect);
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
const CommonViewOpts = struct {
    size: UnitVec2 = .{},
    // focus_id: ?usize = null,
};

pub fn ViewOpts(comptime Opts: type) type {
    const opts = meta.fields(Opts);
    const common = meta.fields(CommonViewOpts);

    var fields: [common.len + opts.len]builtin.Type.StructField = undefined;
    for (opts, 0..) |f, i| fields[i] = f;
    for (common, 0..) |f, i| fields[opts.len + i] = f;
    return @Type(.{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } });
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
const CellStyle = M.Io.CellStyle;
const Event = M.Event;
