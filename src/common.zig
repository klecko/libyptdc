pub const std = @import("std");
pub const builtin = @import("builtin");
pub const expect = std.testing.expect;
pub const shl = std.math.shl;
pub const c = @cImport({
    @cInclude("capstone/capstone.h");
});

const WHITE = "\x1b[37;1m";
const RESET = "\x1b[0m";

pub fn assert(check: bool, comptime fmt: []const u8, args: anytype) void {
    if (!check) {
        std.debug.print("\n\n" ++ WHITE ++ fmt ++ RESET ++ "\n\n", args);
        unreachable;
    }
}

pub fn test_ok() void {
    std.debug.print("OK\n", .{});
}