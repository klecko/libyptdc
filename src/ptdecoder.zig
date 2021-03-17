usingnamespace @import("common.zig");

const Disassembler = @import("disassembler.zig").Disassembler;
const packet = @import("packet.zig");
const test_allocator = std.testing.allocator;

const PTDecoder = struct {
    disassembler: Disassembler,
    bitmap: []u8,
    in_psb: bool,
    // handlers: [@typeInfo(packet.PacketType).Enum.fields.len](fn(*PTDecoder, []const u8) void),

    pub fn init(bitmap: []u8) PTDecoder {
        var pt = PTDecoder {
            .disassembler = Disassembler.init(),
            .bitmap = bitmap,
            .in_psb = false,
            // .handlers = undefined,
        };
        // comptime {
        //     pt.handlers[@enumToInt(packet.PacketType.PSB)] = handle_psb;
        // }
        return pt;
    }

    pub fn deinit(self: *PTDecoder) void {
        self.disassembler.deinit();
    }

    fn handle_psb(self: *PTDecoder, data: []const u8) void {
        std.debug.print("Handling psb\n", .{});
        self.in_psb = true;
    }

    fn decode(self: *PTDecoder, data: []const u8) void {
        var i: usize = 0;
        while (i < data.len) {
            var t = packet.getPacketType(data[i..]);
            std.debug.print("offset 0x{x}: {}\n", .{ i, t });
            switch (t) {
                .PSB => handle_psb(self, data[i..]),
                else => unreachable,
            }
            //self.handlers[@enumToInt(t)](self, data);
            i += t.length() catch unreachable;
        }

    }
};

test "decoder" {
    std.debug.print("\n", .{});

    // Read file
    const file = try std.fs.cwd().openFile(
        "tests/dump.pt",
        .{ .read = true },
    );
    defer file.close();

    const contents = try file.reader().readAllAlloc(
        test_allocator,
        1024*1024
    );
    defer test_allocator.free(contents);

    // Decode
    var bitmap = try test_allocator.alloc(u8, 64*1024*1024);//: [64*1024*1024]u8 = undefined;
    defer test_allocator.free(bitmap);

    var pt = PTDecoder.init(bitmap);
    defer pt.deinit();
    pt.decode(contents);
}
