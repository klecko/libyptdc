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


test "packet" {
    std.debug.print("{}\n", .{ PacketType.TNT.length() });

    var a = getPacketType("\x71\x01\xf4\x00\x00");
    std.debug.print("{}\n", .{ a.length() });
}