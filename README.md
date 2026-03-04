<br />
<p align="center">
  <a href="https://codeberg.org/maxu/zimtui">
    <img src="#.png?raw=true" alt="Logo" width="80" height="80">
  </a>

<h2 align="center">zimtui</h2>

<p align="center">
    A friendly TUI framework for Zig.</a>.
    <br />
    <a href="https://codeberg.org/maxu/zimtui"><strong>Guide »</strong></a>
    <br />
    <br />
    <!--<a href="#">Report Bug</a>
    ·
    <a href="#">Request Feature</a>-->
  </p>
</p>

<br><br>

## The Zen

zimtui is a library for writing tui applications using declarative, composable views.
At it's core the main experiment is trying to find a balance between the [Zen of Zig](#)
but also making it joyful to compose ui components in zig inspired.

<details>
<summary>Usage Examples</summary>
todo: add im info explainer


**Defining a simple widget.**
```zig

```

**A resuable widget with dynamic data.**
```zig
//!
//! Example widget taken from Inspector.zig
//!

const Inspector = @This();
const Opts = struct {};

pub fn init(
    opts: ViewOpts(Opts),
) View(Inspector) {
    return View(Inspector)
        .init(.{}, opts);
}

pub fn view(_: Inspector, ctx: Ctx) AnyView {
    return ctx.widget(
        Box(
            Text("FPS: {d:>5.0}\ndt: {d:>2.2}ms\n", .{
                ctx.tui.fps(),
                ctx.tui.deltaTime(),
            }, .{}),
            .{
                .border = .dashed,
                .padding = .axes(1, 0),
                .size = .y(.grow()),
                .style = .{ .bg = .{ .indexed = .grey_93 } },
            },
        ),
    );
}

////////////////////////////////////////

const std = @import("std");
const M = @import("../root.zig");
const Ctx = M.views.Ctx;
const View = M.views.View;
const ViewOpts = M.views.ViewOpts;
const AnyView = M.views.AnyView;

const Box = M.views.Box;
const Text = M.views.Text;

```
</details>


<details>
<summary>Helpful Errors</summary>
Especially with this view composition api, we can leverage zig's comptime features for validations and nice error messages i.e. Creating an invalid View will tell you the exact location:

```bash
src/widgets/views.zig:37:9: error: view (widgets.Box) must implement at least one of: draw, view, update
        @compileError("view (" ++ @typeName(V) ++ ") must implement at least one of: draw, view, update");
        ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
src/widgets/views.zig:26:22: note: called at comptime here
    return NestedView(V, null);
           ~~~~~~~~~~^~~~~~~~~
src/widgets/Box.zig:7:32: note: called at comptime here
pub fn init(opts: anytype) View(Box) {
                           ~~~~^~~~~
referenced by:
    Box: src/widgets/views.zig:5:35
    Box: examples/main.zig:4:25
```
</details>


## Layout Engine

THe core is based on these 3 passes:

```zig

fn measure(self: Self, constraints: Constraints) -> Size
fn layout(self: Self, position: Position)
fn draw(&self, surface: &mut Surface)
```

---

<br>
<details>
<summary><h2>Roadmap</h2></summary>

- [Record demos](https://docs.asciinema.org/getting-started/#__tabbed_1_4)

- [ ] Animation
- [ ] Hyperlinks (OSC 8)
- [ ] Bracketed Paste
- [ ] Kitty Image Protocol


### Widgets

- [x] Box
- [x] Text/Label
- [ ] Divider
- [ ] Spacer
- [ ] Image
- [ ] F
- [ ] F

- Work out zig 0.16 support
</details>

<br>
<details>
<summary><h2>Design Decisions & Insights</h2></summary>
Documenting some of the decisions I made along the way as future reference or discussion points.

### 0.1.0

- Using the `|>` symbol in the doc comments for functions to describe return values
quickly felt quite nice. I do have ligatures enabled which also makes that symbol look
nicer. Try it i.e. the `views.zig -> AnyWidget -> fn init()`

</details>
<br>

## Credits & References

**Credits**
- Thx to `xyaman` for crafting [mibu](https://github.com/xyaman/mibu) which zimtui uses for backend terminal manageemnt.

**References**
- [Generating unique id's for widgets using `@returnAddress()` builtin trick.](https://gamesbymason.com/2023/11/03/uniques/)
