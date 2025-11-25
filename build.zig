const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const static = b.option(bool, "static", "build a static rtmidi") orelse false;

    const module = b.addModule("rtmidi_z", .{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("lib.zig"),
        .link_libc = true,
    });
    const tests = b.addTest(.{
        .root_module = module,
        .use_llvm = true,
    });

    if (static) {
        const lib = try compileRtMidi(b, target, optimize);
        b.installArtifact(lib);
        module.linkLibrary(lib);
    } else {
        module.linkSystemLibrary("rtmidi", .{ .needed = true });
    }

    const test_run_step = b.addRunArtifact(tests);
    const tests_step = b.step("test", "run the tests");
    tests_step.dependOn(&test_run_step.step);
}

fn compileRtMidi(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const upstream = b.dependency("upstream", .{});
    const lib = b.addLibrary(.{
        .name = "rtmidi",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    for (macros) |m| {
        lib.root_module.addCMacro(m[0], m[1]);
    }
    const t = target.result.os.tag;
    const cpp_flags: []const []const u8 = switch (t) {
        .macos => &.{"-D__MACOSX_CORE__"},
        .linux => &.{"-D__LINUX_ALSA__"},
        .windows => &.{"-D__WINDOWS_MM__"},
        else => return error.NotSupported,
    };
    switch (t) {
        .macos => {
            lib.linkFramework("CoreMIDI");
            lib.linkFramework("CoreAudio");
            lib.linkFramework("CoreFoundation");
            lib.linkSystemLibrary("pthread");
            lib.root_module.addCMacro("HAVE_LIBPTHREAD", "1");
        },
        .linux => {
            lib.linkSystemLibrary("asound");
            lib.linkSystemLibrary("pthread");
            lib.root_module.addCMacro("HAVE_LIBPTHREAD", "1");
        },
        .windows => {
            lib.linkSystemLibrary("winmm");
            lib.root_module.addCMacro("HAVE_LIBPTHREAD", "0");
        },
        else => return error.NotSupported,
    }

    lib.addCSourceFile(.{
        .file = .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "RtMidi.cpp",
        } },
        .flags = cpp_flags,
    });
    lib.addCSourceFile(.{
        .file = .{ .dependency = .{
            .dependency = upstream,
            .sub_path = "rtmidi_c.cpp",
        } },
        .flags = cpp_flags,
    });
    lib.installHeader(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "RtMidi.h",
    } }, "RtMidi.h");
    lib.installHeader(.{ .dependency = .{
        .dependency = upstream,
        .sub_path = "rtmidi_c.h",
    } }, "rtmidi_c.h");
    return lib;
}

const macros: []const [2][]const u8 = &.{
    .{ "PACKAGE_NAME", "\"RtMidi\"" },
    .{ "PACKAGE_TARNAME", "\"rtmidi\"" },
    .{ "PACKAGE_VERSION", "\"6.0.0\"" },
    .{ "PACKAGE_STRING", "\"RtMidi 6.0.0\"" },
    .{ "PACKAGE_BUGREPORT", "\"gary.scavone@mcgill.ca\"" },
    .{ "PACKAGE_URL", "\"\"" },
    .{ "PACKAGE", "\"rtmidi\"" },
    .{ "VERSION", "\"6.0.0\"" },
    .{ "HAVE_CXX11", "1" },
    .{ "HAVE_STDIO_H", "1" },
    .{ "HAVE_STRING_H", "1" },
    .{ "HAVE_INTTYPES_H", "1" },
    .{ "HAVE_STDINT_H", "1" },
    .{ "HAVE_STRINGS_H", "1" },
    .{ "HAVE_SYS_STAT_H", "1" },
    .{ "HAVE_SYS_TYPES_H", "1" },
    .{ "HAVE_UNISTD_H", "1" },
    .{ "STDC_HEADERS", "1" },
    .{ "HAVE_DLCFN_H", "1" },
    .{ "LT_OBJDIR", "\".libs/\"" },
    .{ "HAVE_SEMAPHORE", "1" },
};
