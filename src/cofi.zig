usingnamespace @import("common.zig");

const ConditionalBranchOpcodes = [_]c.x86_insn {
    .X86_INS_JMP,
};

const UnconditionalDirectBranchOpcodes = [_]c.x86_insn {
    //.X86_INS_
};


pub const Type = enum {
    ConditionalBranch,
    UnconditionalDirectBranch,
    IndirectBranch,
    FarTransfer,
    pub fn getType(comptime ins: c.x86_insn) Type {

    }
};

test "cofi" {
    var a = ConditionalBranchOpcodes[0];
    test_ok();
}