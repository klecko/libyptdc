const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const lib = b.addSharedLibrary("yptdec", "src/ptdecoder.zig", .unversioned);
    lib.setTarget(target);
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/ptdecoder.zig");
    main_tests.setBuildMode(mode);
    main_tests.setTarget(target);
    //main_tests.linkSystemLibrary("capstone");
    // FIXME
    main_tests.addObjectFile("/lib/libcapstone.so.5");
    main_tests.addIncludeDir("/usr/include/");
    main_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    // const run_cmd = exe.run();
    // run_cmd.step.dependOn(b.getInstallStep());

    // const run_step = b.step("run", "Run the app");
    // run_step.dependOn(&run_cmd.step);
}
