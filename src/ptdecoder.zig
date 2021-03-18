usingnamespace @import("common.zig");

const Disassembler = @import("disassembler.zig").Disassembler;
const packet = @import("packet.zig");
const test_allocator = std.testing.allocator;

const PTDecoder = struct {
    disassembler: Disassembler,
    bitmap: []u8,
    in_psb: bool,
    pending_fup: ?u64,
    last_ip: u64,
    // handlers: [@typeInfo(packet.PacketType).Enum.fields.len](fn(*PTDecoder, []const u8) void),

    pub fn init(bitmap: []u8) PTDecoder {
        var pt = PTDecoder {
            .disassembler = Disassembler.init(),
            .bitmap = bitmap,
            .in_psb = false,
            .pending_fup = null,
            .last_ip = 0,
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

    fn addBranch(addr1: u64, addr2: u64) void {
        std.debug.print("branch from 0x%{x} to 0x%{x}\n", .{ addr1, addr2 });
    }

    fn handlePSB(self: *PTDecoder, data: []const u8) void {
        self.in_psb = true;
        self.last_ip = 0;
    }

    fn handlePSBEND(self: *PTDecoder, data: []const u8) void {
        self.in_psb = false;
    }

    fn handleMODE(self: *PTDecoder, data: []const u8) void {
        const payload = data[1];
        var t = @intToEnum(packet.MODEType, @intCast(u3, payload >> 5));
        switch (t) {
            .Exec => {
                var mode = @intToEnum(
                    packet.MODEExecAddressingMode,
                    @intCast(u2, payload & 0b11)
                );
                assert(mode == .Mode64, "MODE.Exec {}", .{ mode });
            },
            .TSX => { },
        }
    }

    fn handleTIP_PGE(self: *PTDecoder, data: []const u8) void {
        // TIP.PGE does not bind to any other packet
        const ip = packet.getIP(data, self.last_ip) orelse unreachable;
        //std.debug.print("TIP.PGE: 0x{x}\n", .{ ip });
        self.last_ip = ip;
        self.disassembler.current_address = ip;
    }

    fn handleTIP_PGD(self: *PTDecoder, data: []const u8) void {
        const ip = packet.getIP(data, self.last_ip);
        //std.debug.print("TIP.PGD: 0x{x}\n", .{ ip });
        if (self.pending_fup) |fup_ip| {
            if (ip) |ip_val| {
                // FUP, IP: change of flow because of an asynchronous event,
                // the target IP is out of traced area but still in context.
                // I haven't found any of these yet
                //self.addBranch(fup_ip, ip_val);
                unreachable;
            } else {
                // FUP, no IP: change of flow because of an asynchronous event,
                // and the IP is out of context (for example, when an
                // interruption occurs while tracing only user mode).
                // Do nothing.
            }
            self.pending_fup = null;
        } else {
            if (ip) |ip_val| {
                // No FUP, IP: branch out of traced area, but target IP is still
                // in context. In order to know the source address, we have to
                // look for the next direct branch whose target is ip_val, or
                // the first indirect or conditional branch we find. TODO
                //unreachable;

            } else {
                // No FUP, no IP: branch to an IP out of context (for example,
                // when executing syscall while tracing only user mode)
                // Do nothing.
            }
        }
    }

    fn handleTIP(self: *PTDecoder, data: []const u8) void {
        const ip = packet.getIP(data, self.last_ip) orelse unreachable;
        //std.debug.print("TIP: 0x{x}\n", .{ ip });
        if (self.pending_fup) |fup_ip| {
            // I haven't found any of these yet.
            unreachable;
        } else {
            // Look for the next indirect branch. TODO
            //unreachable;
        }
    }

    fn handleFUP(self: *PTDecoder, data: []const u8) void {
        const ip = packet.getIP(data, self.last_ip) orelse unreachable;
        //std.debug.print("FUP: 0x{x}\n", .{ ip });
        self.last_ip = ip;
        if (self.in_psb) {
            self.disassembler.current_address = ip;
        } else {
            self.pending_fup = ip;
        }
    }

    fn handleTNT(self: *PTDecoder, data: []const u8) void {
        const branch_count = 6 - @clz(u8, data[0]);
        assert(branch_count >= 1, "TNT zero branches? {}", .{ branch_count });
        var i: usize = branch_count;
        while (i > 0) : (i -= 1) {
            const taken: bool = (data[0] & shl(u8, 1, i)) != 0;
            // Look for next conditional branch TODO
            //std.debug.print("taken: {}\n", .{taken});
        }
    }

    pub fn decode(self: *PTDecoder, data: []const u8) void {
        var i: usize = 0;
        while (i < data.len) {
            var t = packet.getPacketType(data[i..]);
            //std.debug.print("offset 0x{x}: {}\n", .{ i, t });
            switch (t) {
                .PSB => handlePSB(self, data[i..]),
                .PSBEND => handlePSBEND(self, data[i..]),
                .MODE => handleMODE(self, data[i..]),
                .TIP_PGE => handleTIP_PGE(self, data[i..]),
                .TIP_PGD => handleTIP_PGD(self, data[i..]),
                .TIP => handleTIP(self, data[i..]),
                .FUP => handleFUP(self, data[i..]),
                .TNT => handleTNT(self, data[i..]),
                .PAD, .CBR, .VMCS => {},
                else => unreachable,
            }
            //self.handlers[@enumToInt(t)](self, data);
            //i += t.length() catch unreachable;
            i += switch (t) {
                .TIP, .TIP_PGE, .TIP_PGD, .FUP =>
                    packet.getPayloadLengthIP(data[i]) + 1,
                else => t.length() catch unreachable,
            };
        }
        //unreachable;
    }
};

test "decoder" {
    var bitmap = try test_allocator.alloc(u8, 64*1024*1024);//: [64*1024*1024]u8 = undefined;
    defer test_allocator.free(bitmap);

    var pt = PTDecoder.init(bitmap);
    defer pt.deinit();

    // Decode every file in tests
    std.debug.print("\n", .{});
    const dir = try std.fs.cwd().openDir("tests", .{ .iterate = true });
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .File)
            continue;
        std.debug.print("Decoding file {s}\n", .{ entry.name });
        const file = try dir.openFile(entry.name, .{ .read = true });
        defer file.close();
        const contents = try file.reader().readAllAlloc(test_allocator, 1024*1024);
        defer test_allocator.free(contents);
        pt.decode(contents);
    }

    test_ok();
}
