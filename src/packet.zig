usingnamespace @import("common.zig");

pub const PacketType = enum {
    PAD,
    TNT,
    LTNT,
    TIP,
    TIP_PGE,
    TIP_PGD,
    FUP,
    MODE,
    CBR,
    VMCS,
    OVF,
    PSB,
    PSBEND,
    SECOND_LEVEL,
    UNKNOWN,

    pub fn length(self: PacketType) !usize {
        return switch (self) {
            .TNT => 1,
            .LTNT => 8,
            .MODE => 2,
            .CBR => 4,
            .VMCS => 7,
            .OVF => 2,
            .PSB => 16,
            .PSBEND => 2,
            .PAD => 1,
            else => error.NoLength,
        };
    }
};

pub fn getPacketType(packet: []const u8) PacketType {
    var t: PacketType = packetTable1[packet[0]];
    if (t == .SECOND_LEVEL)
        t = packetTable2[packet[1]];
    return t;
}

pub fn getPayloadLengthIP(header: u8) u8 {
    return switch (header >> 5) {
        0b000 => 0,
        0b001 => 2,
        0b010 => 4,
        0b011, 0b100 => 6,
        0b110 => 8,
        else => unreachable
    };
}

pub fn getIP(data: []const u8, last_ip: u64) ?u64 {
    const payload = data[1..1+getPayloadLengthIP(data[0])];
    if (payload.len == 0)
        return null;
    var result: u64 = 0;
    if (data[0] >> 5 == 0b011) {
        // Doesn't depend on last IP
        assert(payload.len == 6, "sign_extend with payload length {}", .{payload.len});
        var tmp: i48 = 0;
        std.mem.copy(u8, @ptrCast(*[8]u8, &tmp), payload);
        // sign extend from i48 to i64, and cast back to u64
        result = @bitCast(u64, @intCast(i64, tmp));
    } else {
        const length_bits = payload.len * 8;
        const mask_last_ip = shl(u64, shl(u64, 1, 64 - length_bits) - 1, length_bits);
        result = last_ip & mask_last_ip;
        std.mem.copy(u8, @ptrCast(*[8]u8, &result), payload);
    }
    return result;
}

pub const MODEType = enum(u3) {
    Exec = 0b000,
    TSX = 0b001,
};

pub const MODEExecAddressingMode = enum(u2) {
    Mode64 = 0b01,
    Mode32 = 0b10,
    Mode16 = 0b00,
};

const packetTable1: [256]PacketType = initPacketTable1();
const packetTable2: [256]PacketType = initPacketTable2();

// This code will be executed at compile time. It will actually not appear
// in the executable in Release mode
fn initPacketTable1() [256]PacketType {
    @setEvalBranchQuota(2000);
    comptime {
        var table: [256]PacketType = undefined;
        var i: usize = 0;
        while (i < table.len) : (i += 1) {
            table[i] = switch (i) {
                0b00000000 => .PAD,
                0b00000010 => .SECOND_LEVEL,
                0b10011001 => .MODE,
                else => switch(i & 0b11111) {
                    0b11101 => .FUP,
                    0b01101 => .TIP,
                    0b10001 => .TIP_PGE,
                    0b00001 => .TIP_PGD,
                    else => if (i & 1 == 0) .TNT
                        else .UNKNOWN
                }
            };
        }
        return table;
    }
}

fn initPacketTable2() [256]PacketType {
    comptime {
        var table: [256]PacketType = undefined;
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            table[i] = switch(i) {
                0b10100011 => .LTNT,
                0b00000011 => .CBR,
                0b11001000 => .VMCS,
                0b11110011 => .OVF,
                0b10000010 => .PSB,
                0b00100011 => .PSBEND,
                else => .UNKNOWN
            };
        }
        return table;
    }
}


test "single FUP" {
    const packet = "\x7d\xd0\x2a\x40\x00\x00\x00";
    expect(getPacketType(packet) == .FUP);
    const ip = getIP(packet, 0x00) orelse unreachable;
    expect(ip == 0x402ad0);
    test_ok();
}

test "IP compression" {
    const packet = "\x2d\x0c\xf4";
    expect(getPacketType(packet) == .TIP);
    const ip = getIP(packet, 0x48f401) orelse unreachable;
    expect(ip == 0x48f40c);
    test_ok();
}

test "IP compression signextend" {
    // Positive signextend
    const packet1 = "\x71\x01\xf4\x48\x00\x00\x00";
    expect(getPacketType(packet1) == .TIP_PGE);
    const ip1 = getIP(packet1, 0) orelse unreachable;
    expect(ip1 == 0x48f401);

    // Negative signextend
    const packet2 = "\x61\x60\x2c\x02\xa3\xff\xff";
    expect(getPacketType(packet2) == .TIP_PGD);
    const ip2 = getIP(packet2, 0) orelse unreachable;
    expect(ip2 == 0xffffffffa3022c60);
    test_ok();
}