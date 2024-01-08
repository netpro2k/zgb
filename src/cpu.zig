const std = @import("std");
const Mem = @import("mem.zig");

pub const Flags = packed struct {
    _pad: u4 = 0,
    C: u1,
    H: u1,
    N: bool,
    Z: bool,
};

const CPU = @This();

AF: packed union {
    r16: u16,
    r8: packed struct { F: u8, A: u8 },
    flags: Flags,
},
BC: packed union {
    r16: u16,
    r8: packed struct { C: u8, B: u8 },
},
DE: packed union {
    r16: u16,
    r8: packed struct { E: u8, D: u8 },
},
HL: packed union {
    r16: u16,
    r8: packed struct { L: u8, H: u8 },
},
SP: u16,
PC: u16,

IME: bool,

pub fn init() CPU {
    return CPU{
        .AF = .{ .r8 = .{ .A = 0x01, .F = 0x00 } },
        .BC = .{ .r8 = .{ .B = 0xFF, .C = 0x13 } },
        .DE = .{ .r8 = .{ .D = 0x00, .E = 0xC1 } },
        .HL = .{ .r8 = .{ .H = 0x84, .L = 0x03 } },
        .PC = 0x100,
        .SP = 0xFFFE,
        .IME = false,
    };
}

const Op = enum(u8) {
    noop = 0x00,

    ld_bc_iw = 0x01,

    ld_de_iw = 0x11,
    ld_de_a = 0x12,
    inc_de = 0x13,

    ld_hl_iw = 0x21,

    dec_b = 0x05,
    dec_bc = 0x0b,
    inc_c = 0x0C,
    inc_hl = 0x23,
    dec_c = 0x0d,

    dec_hl = 0x35,

    inc_e = 0x1C,
    dec_e = 0x1d,

    inc_l = 0x2C,

    ld_a__ib = 0x3E,
    ld_b__ib = 0x06,
    ld_c__ib = 0x0E,
    ld_d__ib = 0x16,
    ld_a__b = 0x78,
    ld_a__c = 0x79,

    ld_a__h = 0x7C,

    ld_b__a = 0x47,
    ld_c__a = 0x4F,
    ld_e__a = 0x5F,

    ld_a__hl = 0x7E,

    ldi_a__hl = 0x2A,
    ldi_hl_a = 0x22,

    ld_a__de = 0x1a,
    ld_e__hl = 0x5E,
    ld_d__hl = 0x56,
    ld_hl_a = 0x32,
    ld_hl_ib = 0x36,
    ld_ib_a = 0xE0,
    ld_mc_a = 0xE2,
    ld_iw_a = 0xEA,

    ld_sp_iw = 0x31,

    ldh_a = 0xF0,
    ld_a_miw = 0xFA,

    cp_ib = 0xFE,

    jr_ib = 0x18,
    jr_nz_ib = 0x20,
    jr_z_ib = 0x28,

    jp_z_iw = 0xCA,

    jp_iw = 0xC3,
    jp_hl = 0xE9,

    call_iw = 0xCD,

    ret_z = 0xC8,
    ret = 0xC9,

    rst_28 = 0xEF,

    pop_bc = 0xC1,
    pop_de = 0xD1,
    pop_hl = 0xE1,
    pop_af = 0xF1,

    push_bc = 0xC5,
    push_de = 0xD5,
    push_hl = 0xE5,
    push_af = 0xF5,

    and_ib = 0xE6,

    add_a = 0x87,

    add_hl_de = 0x19,

    and_a_c = 0xA1,

    and_a_a = 0xA7,

    xor_a_c = 0xA9,
    xor_a_a = 0xAF,

    or_a_b = 0xB0,
    or_a_c = 0xB1,

    cpl = 0x2F,

    cb_prefix = 0xCB,

    di = 0xF3,
    ei = 0xFB,
};

const CbOp = enum(u8) {
    swap_a = 0x37,
    res_0_a = 0x87,
};

pub fn read_ib(self: *CPU, mem: *Mem) u8 {
    const ib = mem.read(self.PC);
    std.debug.print("${X:0>2} ", .{ib});
    self.PC += 1;
    return ib;
}

pub fn read_iw(self: *CPU, mem: *Mem) u16 {
    const low: u16 = mem.read(self.PC);
    const high: u16 = mem.read(self.PC + 1);
    const iw = low | high << 8;

    std.debug.print("${X:0>4} ", .{iw});
    self.PC += 2;

    return iw;
}

fn sub_with_carry(self: *CPU, a: u8, b: u8) u8 {
    const result = a -% b;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (a < b) 1 else 0;
    self.AF.flags.H = if ((a & 0xF) < (b & 0xF)) 1 else 0;
    return result;
}

fn sub_with_carry_w(self: *CPU, a: u16, b: u16) u16 {
    const result = a -% b;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (a < b) 1 else 0;
    self.AF.flags.H = if ((a & 0xF) < (b & 0xF)) 1 else 0;
    return result;
}

fn add_with_carry(self: *CPU, a: u8, b: u8) u8 {
    const result = a +% b;
    self.AF.flags.N = false;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (result < a or result < b) 1 else 0;
    self.AF.flags.H = if ((a & 0xF) < (b & 0xF)) 1 else 0;
    return result;
}

fn add_with_carry_w(self: *CPU, a: u16, b: u16) u16 {
    const result = a +% b;
    self.AF.flags.N = false;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (result < a or result < b) 1 else 0;
    self.AF.flags.H = if ((a & 0xF) < (b & 0xF)) 1 else 0;
    return result;
}

fn push_w(self: *CPU, mem: *Mem, value: u16) void {
    self.SP -= 1;
    mem.write(self.SP, @truncate(value >> 8));
    self.SP -= 1;
    mem.write(self.SP, @truncate(value));
}

fn pop_w(self: *CPU, mem: *Mem) u16 {
    const low: u16 = mem.read(self.SP);
    self.SP += 1;
    const high: u16 = mem.read(self.SP);
    self.SP += 1;
    return (high << 8) | low;
}

pub fn tick(self: *CPU, mem: *Mem) void {
    const opcode = std.meta.intToEnum(Op, mem.read(self.PC)) catch {
        std.debug.panic("[{x}]: Unsupported opcode {x}\n", .{ self.PC, mem.read(self.PC) });
    };

    std.debug.print("[{X:0>4}]: {s}\t", .{ self.PC, @tagName(opcode) });

    self.PC += 1;

    switch (opcode) {
        .noop => {},
        .jp_iw => {
            self.PC = self.read_iw(mem);
        },
        .jp_hl => {
            self.PC = self.HL.r16;
        },
        .jr_nz_ib => {
            const ib = self.read_ib(mem);
            if (!self.AF.flags.Z) {
                const new_pc = @as(i16, @as(i16, @bitCast(self.PC))) +% @as(i8, @bitCast(ib));
                self.PC = @bitCast(new_pc);
            }
        },

        .jr_ib => {
            const ib = self.read_ib(mem);
            const new_pc = @as(i16, @as(i16, @bitCast(self.PC))) +% @as(i8, @bitCast(ib));
            self.PC = @bitCast(new_pc);
        },

        .jr_z_ib => {
            const ib = self.read_ib(mem);
            if (self.AF.flags.Z) {
                const new_pc = @as(i16, @as(i16, @bitCast(self.PC))) +% @as(i8, @bitCast(ib));
                self.PC = @bitCast(new_pc);
            }
        },

        .jp_z_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.Z) self.PC = addr;
        },

        .ld_sp_iw => {
            self.SP = self.read_iw(mem);
        },

        .ld_bc_iw => {
            self.BC.r16 = self.read_iw(mem);
        },

        .ld_de_iw => {
            self.DE.r16 = self.read_iw(mem);
        },
        .ld_hl_iw => {
            self.HL.r16 = self.read_iw(mem);
        },

        .dec_b => {
            self.BC.r8.B = self.sub_with_carry(self.BC.r8.B, 1);
        },

        .dec_bc => {
            self.BC.r16 = self.sub_with_carry_w(self.BC.r16, 1);
        },

        .dec_hl => self.HL.r16 = self.sub_with_carry_w(mem.read(self.HL.r16), 1),

        .dec_c => {
            self.BC.r8.C = self.sub_with_carry(self.BC.r8.C, 1);
        },

        .inc_c => self.BC.r8.C = self.add_with_carry(self.BC.r8.C, 1),
        .inc_e => self.DE.r8.E = self.add_with_carry(self.DE.r8.E, 1),
        .inc_l => self.HL.r8.L = self.add_with_carry(self.HL.r8.L, 1),

        .inc_hl => {
            self.HL.r16 = self.add_with_carry_w(self.HL.r16, 1);
        },
        .inc_de => {
            self.DE.r16 = self.add_with_carry_w(self.DE.r16, 1);
        },

        .add_a => {
            self.AF.r8.A = self.add_with_carry(self.AF.r8.A, self.AF.r8.A);
        },

        .add_hl_de => {
            self.HL.r16 = self.add_with_carry_w(self.HL.r16, self.DE.r16);
        },

        .dec_e => {
            self.DE.r8.E = self.sub_with_carry(self.DE.r8.E, 1);
        },

        .ld_de_a => {
            mem.write(self.DE.r16, self.AF.r8.A);
        },
        .ld_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 -= 1;
        },
        .ldi_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 += 1;
        },

        .ld_hl_ib => {
            mem.write(self.HL.r16, self.read_ib(mem));
        },

        .ld_ib_a => {
            mem.write_ff(self.read_ib(mem), self.AF.r8.A);
        },
        .ld_iw_a => {
            mem.write(self.read_iw(mem), self.AF.r8.A);
        },
        .ld_mc_a => {
            mem.write_ff(self.BC.r8.C, self.AF.r8.A);
        },

        .ld_a__hl => self.AF.r8.A = mem.read(self.HL.r16),

        .ldi_a__hl => {
            self.AF.r8.A = mem.read(self.HL.r16);
            self.HL.r16 += 1;
        },

        .ld_a__de => self.AF.r8.A = mem.read(self.DE.r16),

        .ld_e__hl => {
            self.DE.r8.E = mem.read(self.HL.r16);
        },
        .ld_d__hl => {
            self.DE.r8.D = mem.read(self.HL.r16);
        },
        .ld_a__b => {
            self.AF.r8.A = self.BC.r8.B;
        },
        .ld_a__c => self.AF.r8.A = self.BC.r8.C,

        .ld_a__h => self.AF.r8.A = self.HL.r8.H,

        .ld_b__a => {
            self.BC.r8.B = self.AF.r8.A;
        },
        .ld_c__a => {
            self.BC.r8.C = self.AF.r8.A;
        },
        .ld_e__a => {
            self.DE.r8.E = self.AF.r8.A;
        },

        .ldh_a => self.AF.r8.A = mem.read_ff(self.read_ib(mem)),
        .ld_a_miw => self.AF.r8.A = mem.read(self.read_iw(mem)),

        .ld_a__ib => {
            self.AF.r8.A = self.read_ib(mem);
        },
        .ld_b__ib => {
            self.BC.r8.B = self.read_ib(mem);
        },
        .ld_c__ib => {
            self.BC.r8.C = self.read_ib(mem);
        },
        .ld_d__ib => {
            self.DE.r8.D = self.read_ib(mem);
        },

        .and_a_a => {
            self.AF.r8.A &= self.AF.r8.A;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 0;
            self.AF.flags.C = 0;
        },
        .xor_a_a => {
            self.AF.r8.A ^= self.AF.r8.A;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 0;
            self.AF.flags.C = 0;
        },
        .xor_a_c => {
            self.AF.r8.A ^= self.BC.r8.C;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 0;
            self.AF.flags.C = 0;
        },

        .and_ib => {
            self.AF.r8.A &= self.read_ib(mem);
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 1;
            self.AF.flags.C = 0;
        },

        .and_a_c => {
            self.AF.r8.A &= self.BC.r8.C;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 1;
            self.AF.flags.C = 0;
        },

        .cpl => {
            self.AF.r8.A = ~self.AF.r8.A;
            self.AF.flags.N = true;
            self.AF.flags.H = 1;
        },

        .pop_bc => self.BC.r16 = self.pop_w(mem),
        .pop_de => self.DE.r16 = self.pop_w(mem),
        .pop_hl => self.HL.r16 = self.pop_w(mem),
        .pop_af => self.AF.r16 = self.pop_w(mem),

        .push_bc => self.push_w(mem, self.BC.r16),
        .push_de => self.push_w(mem, self.DE.r16),
        .push_hl => self.push_w(mem, self.HL.r16),
        .push_af => self.push_w(mem, self.AF.r16),

        .or_a_b => {
            self.AF.r8.A |= self.BC.r8.B;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 0;
            self.AF.flags.C = 0;
        },
        .or_a_c => {
            self.AF.r8.A |= self.BC.r8.C;
            self.AF.flags.Z = self.AF.r8.A == 0;
            self.AF.flags.N = false;
            self.AF.flags.H = 0;
            self.AF.flags.C = 0;
        },

        .di => {
            self.IME = false;
        },
        .ei => {
            self.IME = true;
        },

        .cp_ib => {
            _ = self.sub_with_carry(self.AF.r8.A, self.read_ib(mem));
        },

        .call_iw => {
            const addr = self.read_iw(mem);
            self.push_w(mem, self.PC);
            self.PC = addr;
        },

        .rst_28 => {
            self.push_w(mem, self.PC);
            self.PC = 0x28;
        },

        .ret => {
            self.PC = self.pop_w(mem);
        },
        .ret_z => {
            if (self.AF.flags.Z) self.PC = self.pop_w(mem);
        },

        .cb_prefix => {
            const cb_op = std.meta.intToEnum(CbOp, mem.read(self.PC)) catch {
                std.debug.panic("[{x}]: Unsupported prefix opcode {x}\n", .{ self.PC, mem.read(self.PC) });
            };
            std.debug.print("{s} ", .{@tagName(cb_op)});
            self.PC += 1;

            switch (cb_op) {
                .swap_a => {
                    const low = self.AF.r8.A & 0x0F;
                    const high = self.AF.r8.A >> 4;
                    self.AF.r8.A = low << 4 | high;
                },
                .res_0_a => {
                    self.AF.r8.A &= ~(@as(u8, 1) << 0);
                },
            }
        },
    }

    std.debug.print("\t\t-- AF: {X:0>4} BC: {X:0>4} DE: {X:0>4} HL: {X:0>4}\n", .{ self.AF.r16, self.BC.r16, self.DE.r16, self.HL.r16 });
}

test "register arrangement" {
    var cpu: CPU = undefined;
    cpu.AF.r8.A = 0x12;
    cpu.AF.r8.F = 0x34;
    try std.testing.expectEqual(@as(u16, 0x1234), cpu.AF.r16);

    cpu.BC.r8.B = 0x23;
    cpu.BC.r8.C = 0x34;
    try std.testing.expectEqual(@as(u16, 0x2334), cpu.BC.r16);

    cpu.DE.r8.D = 0x58;
    cpu.DE.r8.E = 0x76;
    try std.testing.expectEqual(@as(u16, 0x5876), cpu.DE.r16);

    cpu.HL.r8.H = 0xAF;
    cpu.HL.r8.L = 0xCD;
    try std.testing.expectEqual(@as(u16, 0xAFCD), cpu.HL.r16);
}

test "flags" {
    var cpu: CPU = undefined;
    cpu.AF.flags = .{
        .Z = true,
        .N = true,
        .H = 1,
        .C = 1,
    };
    try std.testing.expectEqual(@as(u8, 0xF0), cpu.AF.r8.F);

    cpu.AF.flags = .{
        .Z = true,
        .N = false,
        .H = 0,
        .C = 0,
    };
    try std.testing.expectEqual(@as(u8, 0x80), cpu.AF.r8.F);

    cpu.AF.flags = .{
        .Z = false,
        .N = false,
        .H = 0,
        .C = 1,
    };
    try std.testing.expectEqual(@as(u8, 0x10), cpu.AF.r8.F);
}
