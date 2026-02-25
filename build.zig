const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zimtui", .{
        .root_source_file = b.path("src/root.zig"),
        .optimize = optimize,
        .target = target,
    });

    const mibu_dep = b.dependency("mibu", .{});
    mod.addImport("mibu", mibu_dep.module("mibu"));

    const mod_tests = b.addTest(.{ .root_module = mod });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = mod_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Install docs into zig-out/docs");
    docs_step.dependOn(&install_docs.step);

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_mod_tests.step);

    // Create a `zig build example_<name>` run
    // step for each file inside the examples/ dir.
    var examples_dir = b.build_root.handle.openDir("examples", .{ .iterate = true }) catch null;
    if (examples_dir) |*dir| {
        defer dir.close();
        var it = dir.iterate();
        while (it.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

            const stem = entry.name[0 .. entry.name.len - 4];
            const src_path = b.fmt("examples/{s}", .{entry.name});

            const exe = b.addExecutable(.{
                .name = stem,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(src_path),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{
                        .{ .name = "zimtui", .module = mod },
                    },
                }),
            });

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());

            const step_name = b.fmt("example_{s}", .{stem});
            const desc = b.fmt("Run the {s} example", .{stem});
            const step = b.step(step_name, desc);
            step.dependOn(&run_cmd.step);
        }
    }
}
