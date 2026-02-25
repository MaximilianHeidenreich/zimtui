//!
//!  TODO(math): Ripped from other project, needs cleanup
//!

//////////////////////////////////////// VECTORS

pub const Vec2f = Vec2(f32);
pub const Vec2u = Vec2(usize);
pub const Vec2i = Vec2(i32);

pub fn Vec2(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const VectorType = @Vector(2, T);

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return .{ .x = x, .y = y };
        }

        pub inline fn toVec(self: Self) VectorType {
            return @bitCast(self);
        }

        inline fn fromVec(v: VectorType) Self {
            return @bitCast(v);
        }

        pub inline fn add(self: Self, comptime U: type, b: U) Self {
            const other = switch (@typeInfo(U)) {
                .int, .float => @as(VectorType, @splat(b)),
                else => if (U != Self)
                    @compileError("Unsupported type for add")
                else
                    toVec(b),
            };

            return fromVec(toVec(self) + other);
        }

        pub inline fn sub(self: Self, comptime U: type, b: U) Self {
            const other = switch (@typeInfo(U)) {
                .int, .float => @as(VectorType, @splat(b)),
                else => if (U != Self)
                    @compileError("Unsupported type for sub")
                else
                    toVec(b),
            };

            return fromVec(toVec(self) - other);
        }

        pub inline fn scale(self: Self, comptime U: type, b: U) Self {
            const factor = switch (@typeInfo(U)) {
                .int, .float => @as(VectorType, @splat(b)),
                else => if (U != Self)
                    @compileError("Unsupported type for scale")
                else
                    toVec(b),
            };
            return fromVec(toVec(self) * factor);
        }

        pub inline fn lerp(self: Self, comptime U: type, b: Self, t: U) Self {
            const t_vec = switch (@typeInfo(U)) {
                .int, .float => @as(VectorType, @splat(t)),
                else => if (U != Self)
                    @compileError("Unsupported type for lerp")
                else
                    toVec(t),
            };
            return fromVec(toVec(self) + (toVec(b) - toVec(self)) * t_vec);
        }

        pub inline fn dot(self: Self, b: Self) T {
            return @reduce(.Add, self.toVec() * b.toVec());
        }

        pub inline fn lengthSq(self: Self) T {
            return @reduce(.Add, toVec(self) * toVec(self));
        }

        pub inline fn length(self: Self) T {
            comptime {
                if (@typeInfo(T) != .float) {
                    @compileError("length only available for floating point vectors (requires sqrt)");
                }
            }
            return @sqrt(lengthSq(self));
        }

        pub inline fn normalized(self: Self) Self {
            comptime {
                if (@typeInfo(T) != .float) {
                    @compileError("normalized only available for floating point vectors");
                }
            }
            const v = toVec(self);
            const len = self.length();
            return if (len <= 0) self else fromVec(v / @as(VectorType, @splat(len)));
        }

        /// Convert between vector types with appropriate rounding/snapping
        /// Float -> Int: Rounds to nearest pixel (0.5 rounds up)
        /// Int -> Float: Snaps to pixel center (adds 0.5)
        /// Same category: Direct cast
        pub fn as(self: Self, comptime U: type) Vec2(U) {
            const source_info = @typeInfo(T);
            const target_info = @typeInfo(U);

            if (source_info == .float and target_info == .int) {
                // Float to Int: round to nearest pixel (half rounds up)
                // Using floor(x + 0.5) instead of round() for consistent behavior
                return Vec2(U){
                    .x = @intFromFloat(@floor(self.x + 0.5)),
                    .y = @intFromFloat(@floor(self.y + 0.5)),
                };
            } else if (source_info == .int and target_info == .float) {
                // Int to Float: snap to pixel center (add 0.5)
                return Vec2(U){
                    .x = @as(U, @floatFromInt(self.x)) + 0.5,
                    .y = @as(U, @floatFromInt(self.y)) + 0.5,
                };
            } else if (target_info == .int) {
                // Int to Int: direct cast
                return Vec2(U){
                    .x = @intCast(self.x),
                    .y = @intCast(self.y),
                };
            } else {
                // Float to Float: direct cast
                return Vec2(U){
                    .x = @floatCast(self.x),
                    .y = @floatCast(self.y),
                };
            }
        }
    };
}

//////////////////////////////////////// RECT

pub const RectF = Rect(f32);
pub const RectI = Rect(i32);
pub const RectU = Rect(usize);

pub fn Rect(comptime T: type) type {
    comptime switch (@typeInfo(T)) {
        .float, .int => {},
        else => @compileError("Rect requires a numeric type"),
    };

    return extern struct {
        const Self = @This();

        pub const EMPTY: Self = switch (@typeInfo(T)) {
            .float => fromVec(.{
                std.math.inf(T),  std.math.inf(T),
                -std.math.inf(T), -std.math.inf(T),
            }),
            .int => .{
                .min = .{ .x = std.math.maxInt(T), .y = std.math.maxInt(T) },
                .max = .{ .x = std.math.minInt(T), .y = std.math.minInt(T) },
            },
            else => unreachable,
        };

        /// Full-coverage sentinel: means "fill the available container".
        pub const INF: Self = switch (@typeInfo(T)) {
            .float => fromVec(.{
                -std.math.inf(T), -std.math.inf(T),
                std.math.inf(T),  std.math.inf(T),
            }),
            .int => |info| if (info.signedness == .signed) .{
                .min = .{ .x = std.math.minInt(T), .y = std.math.minInt(T) },
                .max = .{ .x = std.math.maxInt(T), .y = std.math.maxInt(T) },
            } else .{
                .min = .{ .x = 0, .y = 0 },
                .max = .{ .x = std.math.maxInt(T), .y = std.math.maxInt(T) },
            },
            else => unreachable,
        };

        pub inline fn isInf(self: Self) bool {
            return std.meta.eql(self, INF);
        }

        min: Vec2(T),
        max: Vec2(T),

        pub inline fn toVec(self: Self) @Vector(4, T) {
            return @bitCast(self);
        }

        inline fn fromVec(v: @Vector(4, T)) Self {
            return @bitCast(v);
        }

        pub inline fn merge(self: Self, other: Self) Self {
            const v1 = self.toVec();
            const v2 = other.toVec();
            return fromVec(.{
                @min(v1[0], v2[0]),
                @min(v1[1], v2[1]),
                @max(v1[2], v2[2]),
                @max(v1[3], v2[3]),
            });
        }

        pub inline fn inset(self: Self, distance: T) Self {
            return .{
                .min = .{ .x = self.min.x +| distance, .y = self.min.y +| distance },
                .max = .{ .x = self.max.x -| distance, .y = self.max.y -| distance },
            };
        }

        pub inline fn expand(self: Self, margin: T) Self {
            switch (@typeInfo(T)) {
                .float => {
                    const m: @Vector(4, T) = @splat(margin);
                    const signs = @Vector(4, T){ -1, -1, 1, 1 };
                    return fromVec(self.toVec() + m * signs);
                },
                .int => |info| {
                    if (info.signedness == .signed) {
                        return .{
                            .min = .{ .x = self.min.x - margin, .y = self.min.y - margin },
                            .max = .{ .x = self.max.x + margin, .y = self.max.y + margin },
                        };
                    } else {
                        return .{
                            .min = .{ .x = self.min.x -| margin, .y = self.min.y -| margin },
                            .max = .{ .x = self.max.x +| margin, .y = self.max.y +| margin },
                        };
                    }
                },
                else => unreachable,
            }
        }

        pub inline fn containsPt(self: Self, point: Vec2(T)) bool {
            return point.x >= self.min.x and point.x <= self.max.x and
                point.y >= self.min.y and point.y <= self.max.y;
        }

        pub inline fn isValid(self: Self) bool {
            const bounds_ok = self.min.x <= self.max.x and self.min.y <= self.max.y;
            switch (@typeInfo(T)) {
                .float => return bounds_ok and
                    std.math.isFinite(self.min.x) and std.math.isFinite(self.min.y) and
                    std.math.isFinite(self.max.x) and std.math.isFinite(self.max.y),
                else => return bounds_ok,
            }
        }

        /// Return self with max clamped to `bound`, keeping min unchanged.
        /// TODO(math): Revisit rect inclusive/exclusive for lyout bounds
        pub inline fn clampMax(self: Self, bound: Vec2(T)) Self {
            return .{ .min = self.min, .max = .{ .x = @min(self.max.x, bound.x), .y = @min(self.max.y, bound.y) } };
        }

        // pub inline fn clamp(self: Self, min_v: Vec2(T), max_v: Vec2(T)) Self {
        //     return .{
        //         .min = .{
        //             .x = @max(self.min.x, min_v.x),
        //             .y = @max(self.min.y, min_v.y),
        //         },
        //         .max = .{
        //             .x = @min(self.max.x, max_v.x),
        //             .y = @min(self.max.y, max_v.y),
        //         },
        //     };
        // }

        pub fn as(self: Self, comptime U: type) Rect(U) {
            return .{
                .min = self.min.as(U),
                .max = self.max.as(U),
            };
        }

        /// Return self with size overridden by optional Unit values, resolved relative to parent.
        pub fn sized(self: Self, parent: Self, w: ?Unit, h: ?Unit) Self {
            if (w == null and h == null) return self;
            const avail_w = parent.max.x -| parent.min.x;
            const avail_h = parent.max.y -| parent.min.y;
            const nat_w = self.max.x -| self.min.x;
            const nat_h = self.max.y -| self.min.y;
            return .{
                .min = self.min,
                .max = .{
                    .x = self.min.x + if (w) |u| u.resolve(avail_w, nat_w) else nat_w,
                    .y = self.min.y + if (h) |u| u.resolve(avail_h, nat_h) else nat_h,
                },
            };
        }
    };
}

////////// INSETS

pub const InsetsF = Insets(f32);
pub const InsetsI = Insets(i32);
pub const InsetsU = Insets(usize);

pub fn Insets(comptime T: type) type {
    comptime switch (@typeInfo(T)) {
        .float, .int => {},
        else => @compileError("Insets must be int or float type!"),
    };

    return struct {
        const Self = @This();

        Top: T = 0,
        Right: T = 0,
        Bottom: T = 0,
        Left: T = 0,

        pub fn all(v: T) Self {
            return .{ .Top = v, .Right = v, .Bottom = v, .Left = v };
        }

        pub fn horizontal(v: T) Self {
            return .{ .Left = v, .Right = v };
        }

        pub fn vertical(v: T) Self {
            return .{ .Top = v, .Bottom = v };
        }

        pub fn axes(h: T, v: T) Self {
            return .{ .Top = v, .Right = h, .Bottom = v, .Left = h };
        }

        pub fn top(v: T) Self {
            return .{ .Top = v };
        }

        pub fn bottom(v: T) Self {
            return .{ .Bottom = v };
        }

        pub fn left(v: T) Self {
            return .{ .Left = v };
        }

        pub fn right(v: T) Self {
            return .{ .Right = v };
        }

        /// Inverse of resolve: grow rect outward by per-side insets.
        pub fn expand(self: Self, rect: Rect(T)) Rect(T) {
            switch (@typeInfo(T)) {
                .float => return .{
                    .min = .{ .x = rect.min.x - self.Left, .y = rect.min.y - self.Top },
                    .max = .{ .x = rect.max.x + self.Right, .y = rect.max.y + self.Bottom },
                },
                .int => |info| {
                    if (info.signedness == .signed) {
                        return .{
                            .min = .{ .x = rect.min.x - self.Left, .y = rect.min.y - self.Top },
                            .max = .{ .x = rect.max.x + self.Right, .y = rect.max.y + self.Bottom },
                        };
                    } else {
                        return .{
                            .min = .{ .x = rect.min.x -| self.Left, .y = rect.min.y -| self.Top },
                            .max = .{ .x = rect.max.x +| self.Right, .y = rect.max.y +| self.Bottom },
                        };
                    }
                },
                else => unreachable,
            }
        }

        pub fn resolve(self: Self, rect: Rect(T)) Rect(T) {
            switch (@typeInfo(T)) {
                .float => return .{
                    .min = .{ .x = rect.min.x + self.Left, .y = rect.min.y + self.Top },
                    .max = .{ .x = rect.max.x - self.Right, .y = rect.max.y - self.Bottom },
                },
                .int => |info| {
                    if (info.signedness == .signed) {
                        return .{
                            .min = .{ .x = rect.min.x + self.Left, .y = rect.min.y + self.Top },
                            .max = .{ .x = rect.max.x - self.Right, .y = rect.max.y - self.Bottom },
                        };
                    } else {
                        return .{
                            .min = .{ .x = rect.min.x +| self.Left, .y = rect.min.y +| self.Top },
                            .max = .{ .x = rect.max.x -| self.Right, .y = rect.max.y -| self.Bottom },
                        };
                    }
                },
                else => unreachable,
            }
        }
    };
}

////////// UNIT

/// Layout sizing unit constraining the natural size of a layout.
pub const Unit = union(enum) {

    // Uppercase field names are not zig-zen, but they let us write
    // `.fixed(42)` instead of the verbose `.{ .fixed = 42 }`.
    Fixed: usize,
    Relative: f32,
    Min: usize,
    Max: usize,
    MinMax: struct { min: usize, max: usize },

    pub fn fixed(v: usize) Unit {
        return .{ .Fixed = v };
    }
    pub fn relative(f: f32) Unit {
        return .{ .Relative = f };
    }
    pub fn min(v: usize) Unit {
        return .{ .Min = v };
    }
    pub fn max(v: usize) Unit {
        return .{ .Max = v };
    }
    pub fn minMax(mn: usize, mx: usize) Unit {
        return .{ .MinMax = .{ .min = mn, .max = mx } };
    }
    pub fn grow() Unit {
        return .{ .Relative = 1 };
    }

    /// `natural` is the widget's own measured size in this axis.
    pub fn resolve(self: Unit, available: usize, natural: usize) usize {
        return switch (self) {
            .Fixed => |v| @min(v, available),
            .Relative => |f| @min(@as(usize, @intFromFloat(@as(f32, @floatFromInt(available)) * f)), available),
            .Min => |v| @max(natural, @min(v, available)),
            .Max => |v| @min(natural, v),
            .MinMax => |mm| std.math.clamp(natural, mm.min, @min(mm.max, available)),
        };
    }
};

pub const UnitVec2 = struct {
    // Uppercase field names are not zig-zen, but they let us write
    // `.xy(42, 2)` instead of the verbose `.{ .x = 42, .y = 2 }`.

    X: ?Unit = null,
    Y: ?Unit = null,

    pub fn x(x_value: Unit) UnitVec2 {
        return .{ .X = x_value, .Y = null };
    }
    pub fn y(y_value: Unit) UnitVec2 {
        return .{ .X = null, .Y = y_value };
    }
    pub fn xy(x_value: Unit, y_value: Unit) UnitVec2 {
        return .{ .X = x_value, .Y = y_value };
    }

    // Convenience fns: apply a single Unit to both axes
    pub fn fixed(v: usize) UnitVec2 {
        return .{ .X = .fixed(v), .Y = .fixed(v) };
    }
    pub fn relative(f: f32) UnitVec2 {
        return .{ .X = .relative(f), .Y = .relative(f) };
    }
    pub fn min(v: usize) UnitVec2 {
        return .{ .X = .min(v), .Y = .min(v) };
    }
    pub fn max(v: usize) UnitVec2 {
        return .{ .X = .max(v), .Y = .max(v) };
    }
    pub fn minMax(mn: usize, mx: usize) UnitVec2 {
        return .{ .X = .minMax(mn, mx), .Y = .minMax(mn, mx) };
    }
    pub fn grow() UnitVec2 {
        return .{ .X = .grow(), .Y = .grow() };
    }

    /// Compute the base rect for a positioned widget within `parent`.
    /// Offsets min by this position; max stays the same. Returns `parent` unchanged if no axes are set.
    pub fn resolveBase(self: UnitVec2, parent: RectU) RectU {
        if (self.X == null and self.Y == null) return parent;
        const aw = parent.max.x -| parent.min.x;
        const ah = parent.max.y -| parent.min.y;
        return .{
            .min = .{
                .x = parent.min.x +| if (self.X) |u| u.resolve(aw, 0) else 0,
                .y = parent.min.y +| if (self.Y) |u| u.resolve(ah, 0) else 0,
            },
            .max = parent.max,
        };
    }
};

pub const Axis = enum {
    x,
    y,

    /// Length of `r` along this axis.
    pub fn len(self: Axis, r: RectU) usize {
        return if (self == .y) r.max.y -| r.min.y else r.max.x -| r.min.x;
    }

    /// A rect sized `size` along this axis, spanning the full available extent in the other.
    pub fn growRect(self: Axis, rem: RectU, size: usize) RectU {
        return if (self == .y)
            .{ .min = rem.min, .max = .{ .x = rem.max.x, .y = rem.min.y +| size } }
        else
            .{ .min = rem.min, .max = .{ .x = rem.min.x +| size, .y = rem.max.y } };
    }
};

////////////////////////////////////////

const std = @import("std");
