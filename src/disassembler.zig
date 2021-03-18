usingnamespace @import("common.zig");
const cofi = @import("cofi.zig");

pub const Disassembler = struct {
    cs_handle: c.csh,
    current_address: u64,

    pub fn init() Disassembler {
        var self = Disassembler {
            .cs_handle = undefined,
            .current_address = 0,
        };
        _ = c.cs_open(c.cs_arch.CS_ARCH_X86, c.cs_mode.CS_MODE_64, &self.cs_handle);
        _ = c.cs_option(self.cs_handle, c.cs_opt_type.CS_OPT_DETAIL, c.CS_OPT_ON);
        return self;
    }

    pub fn deinit(self: *Disassembler) void {
        _ = c.cs_close(&self.cs_handle);
    }

    fn decode(self: *Disassembler, data: []const u8) void {
        var ins: *c.cs_insn = c.cs_malloc(self.cs_handle);
        defer c.cs_free(ins, 1);

        var p: [*c]const u8 = data.ptr;
        var length = data.len;
        var address: u64 = 0x1000;

        while (c.cs_disasm_iter(self.cs_handle, &p, &length, &address, ins)) {
            var details = ins.detail.*.unnamed_0.x86;
            // std.debug.print("mnemonic: {s}; op_str: {s}\n", .{ ins.mnemonic, ins.op_str });
            // std.debug.print("modrm: {}\n", .{ details.modrm });
        }
    }
};

test "disassembler" {
    //std.debug.print("hola jeje\n", .{});
    const a = cofi.Type.ConditionalBranch;

    const code = "\xeb\x00\xff\xe0";//"\x55\x48\x8b\x05\xb8\x13\x00\x00";

    var disas = Disassembler.init();
    defer disas.deinit();

    //std.debug.print("{}\n", .{ @TypeOf(code) });
    disas.decode(code);

    test_ok();
}