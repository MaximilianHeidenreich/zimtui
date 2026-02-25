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

zimtui is a framework for writing tui applications using composable views.
At it's core the main experiment is trying to find a balance between the [Zen of Zig](#)
but also making it joyful to compose ui components in zig.


---

<br>
<details>
<summary><h2>Roadmap</h2></summary>

- [Record demos](https://docs.asciinema.org/getting-started/#__tabbed_1_4)

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
- Thx to `xyaman` for crafting [mibu](https://github.com/xyaman/mibu) which ImTui uses for backend terminal manageemnt.

**References**
- [Generating unique id's for widgets using `@returnAddress()` builtin trick.](https://gamesbymason.com/2023/11/03/uniques/)
