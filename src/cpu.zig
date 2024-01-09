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

halted: bool,
debug: bool,

pub fn init() CPU {
    return CPU{
        .AF = .{ .r8 = .{ .A = 0x01, .F = 0x00 } },
        .BC = .{ .r8 = .{ .B = 0xFF, .C = 0x13 } },
        .DE = .{ .r8 = .{ .D = 0x00, .E = 0xC1 } },
        .HL = .{ .r8 = .{ .H = 0x84, .L = 0x03 } },
        .PC = 0x100,
        .SP = 0xFFFE,
        .IME = false,
        .halted = false,
        .debug = false,
    };
}

const Op = enum(u8) {
    noop = 0x00,
    ld_bc_iw = 0x01,
    ld_bc_a = 0x02,
    inc_bc = 0x03,
    inc_b = 0x04,
    dec_b = 0x05,
    ld_b__ib = 0x06,
    rlca = 0x07,
    ld_iw_sp = 0x08,
    add_hl_bc = 0x09,
    ld_a__bc = 0x0A,
    dec_bc = 0x0B,
    inc_c = 0x0C,
    dec_c = 0x0D,
    ld_c__ib = 0x0E,
    rrca = 0x0F,

    ld_de_iw = 0x11,
    ld_de_a = 0x12,
    inc_de = 0x13,
    inc_d = 0x14,
    dec_d = 0x15,
    ld_d__ib = 0x16,

    jr_ib = 0x18,
    add_hl_de = 0x19,
    ld_a__de = 0x1a,

    ld_e__ib = 0x1E,

    inc_e = 0x1C,
    dec_e = 0x1D,

    jr_nz_ib = 0x20,
    ld_hl_iw = 0x21,
    ldi_hl_a = 0x22,
    inc_hl = 0x23,
    inc_h = 0x24,
    dec_h = 0x25,
    ld_h__ib = 0x26,
    daa = 0x27,
    jr_z_ib = 0x28,
    add_hl_hl = 0x29,
    ldi_a__hl = 0x2A,
    dec_hl = 0x2B,
    inc_l = 0x2C,
    dec_l = 0x2D,
    ld_l__ib = 0x2E,
    cpl = 0x2F,

    ld_sp_iw = 0x31,
    ldd_hl_a = 0x32,

    inc_mhl = 0x34,
    dec_mhl = 0x35,
    ld_hl_ib = 0x36,

    jr_c_ib = 0x38,

    ldd_a__hl = 0x3A,

    inc_a = 0x3C,

    dec_a = 0x3D,
    ld_a__ib = 0x3E,

    ld_b__b = 0x40,
    ld_b__c = 0x41,
    ld_b__d = 0x42,
    ld_b__e = 0x43,
    ld_b__h = 0x44,
    ld_b__l = 0x45,
    ld_b__hl = 0x46,
    ld_b__a = 0x47,

    ld_c__hl = 0x4E,
    ld_c__a = 0x4F,

    ld_d__b = 0x50,
    ld_d__c = 0x51,
    ld_d__d = 0x52,
    ld_d__e = 0x53,
    ld_d__h = 0x54,
    ld_d__l = 0x55,
    ld_d__hl = 0x56,
    ld_d__a = 0x57,
    ld_e__b = 0x58,
    ld_e__c = 0x59,
    ld_e__d = 0x5A,
    ld_e__e = 0x5B,
    ld_e__h = 0x5C,
    ld_e__l = 0x5D,
    ld_e__hl = 0x5E,
    ld_e__a = 0x5F,

    ld_h__b = 0x60,
    ld_h__c = 0x61,
    ld_h__d = 0x62,
    ld_h__e = 0x63,
    ld_h__h = 0x64,
    ld_h__l = 0x65,
    ld_h__hl = 0x66,
    ld_h__a = 0x67,
    ld_l__b = 0x68,
    ld_l__c = 0x69,
    ld_l__d = 0x6A,
    ld_l__e = 0x6B,
    ld_l__h = 0x6C,
    ld_l__l = 0x6D,
    ld_l__hl = 0x6E,
    ld_l__a = 0x6F,

    ld_hl_b = 0x70,
    ld_hl_c = 0x71,
    ld_hl_d = 0x72,
    ld_hl_e = 0x73,
    ld_hl_h = 0x74,
    ld_hl_l = 0x75,
    halt = 0x76,
    ld_hl_a = 0x77,
    ld_a__b = 0x78,
    ld_a__c = 0x79,
    ld_a__d = 0x7A,
    ld_a__e = 0x7B,
    ld_a__h = 0x7C,
    ld_a__l = 0x7D,
    ld_a__hl = 0x7E,
    ld_a__a = 0x7F,

    add_a_l = 0x85,
    add_a_hl = 0x86,
    add_a = 0x87,

    adc_a__h = 0x8c,
    adc_a_hl = 0x8E,

    and_a_b = 0xA0,
    and_a_c = 0xA1,
    and_a_d = 0xA2,
    and_a_e = 0xA3,
    and_a_h = 0xA4,
    and_a_l = 0xA5,
    and_a_hl = 0xA6,
    and_a_a = 0xA7,
    xor_a_b = 0xA8,
    xor_a_c = 0xA9,
    xor_a_d = 0xAA,
    xor_a_e = 0xAB,
    xor_a_h = 0xAC,
    xor_a_l = 0xAD,
    xor_a_hl = 0xAE,
    xor_a_a = 0xAF,

    or_a_b = 0xB0,
    or_a_c = 0xB1,

    or_a_a = 0xB7,

    cp_a_e = 0xBB,

    ret_nz = 0xC0,
    pop_bc = 0xC1,

    jp_nz_iw = 0xC2,
    jp_iw = 0xC3,
    call_nz_iw = 0xC4,
    push_bc = 0xC5,
    add_ib = 0xC6,

    ret_z = 0xC8,
    ret = 0xC9,
    jp_z_iw = 0xCA,
    cb_prefix = 0xCB,

    call_iw = 0xCD,
    rst_08 = 0xCF,

    ret_nc = 0xD0,
    pop_de = 0xD1,

    push_de = 0xD5,
    sub_a_ib = 0xD6,

    ret_c = 0xD8,
    reti = 0xD9,

    ld_ib_a = 0xE0,
    pop_hl = 0xE1,
    ld_mc_a = 0xE2,

    push_hl = 0xE5,
    and_ib = 0xE6,

    jp_hl = 0xE9,
    ld_iw_a = 0xEA,

    xor_a_ib = 0xEE,
    rst_28 = 0xEF,

    ldh_a = 0xF0,
    pop_af = 0xF1,

    di = 0xF3,

    push_af = 0xF5,
    or_a_ib = 0xF6,

    ld_a_miw = 0xFA,
    ei = 0xFB,

    cp_ib = 0xFE,
};

const CbOp = enum(u8) {
    sla_a = 0x3F,
    sra_a = 0x27,

    swap_b = 0x30,
    swap_c = 0x31,
    swap_d = 0x32,
    swap_e = 0x33,
    swap_h = 0x34,
    swap_l = 0x35,
    swap_hl = 0x36,
    swap_a = 0x37,

    res_0_hl = 0x86,
    res_0_a = 0x87,

    bit_0_b = 0x40,
    bit_1_b = 0x48,
    bit_2_b = 0x50,
    bit_3_b = 0x58,
    bit_4_b = 0x60,
    bit_5_b = 0x68,
    bit_6_b = 0x70,
    bit_7_b = 0x78,

    bit_7_hl = 0x7e,

    bit_0_a = 0x47,
    bit_1_a = 0x4F,
    bit_2_a = 0x57,
    bit_3_a = 0x5F,
    bit_4_a = 0x67,
    bit_5_a = 0x6F,
    bit_6_a = 0x77,
    bit_7_a = 0x7F,
};

pub fn read_ib(self: *CPU, mem: *Mem) u8 {
    const ib = mem.read(self.PC);
    if (self.debug) std.debug.print("${X:0>2} ", .{ib});
    self.PC += 1;
    return ib;
}

pub fn read_iw(self: *CPU, mem: *Mem) u16 {
    const low: u16 = mem.read(self.PC);
    const high: u16 = mem.read(self.PC + 1);
    const iw = low | high << 8;

    if (self.debug) std.debug.print("${X:0>4} ", .{iw});
    self.PC += 2;

    return iw;
}

fn alu_sub(self: *CPU, a: u8, b: u8) u8 {
    const result = a -% b;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (a < b) 1 else 0;
    self.AF.flags.H = if ((a & 0x0F) < (b & 0x0F)) 1 else 0;
    return result;
}

fn alu_sub_w(self: *CPU, a: u16, b: u16) u16 {
    const result = a -% b;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = if (a < b) 1 else 0;
    self.AF.flags.H = if ((a & 0x00FF) < (b & 0x00FF)) 1 else 0;
    return result;
}

fn alu_add(self: *CPU, a: u8, b: u8) u8 {
    const result = @addWithOverflow(a, b);
    self.AF.flags.N = false;
    self.AF.flags.Z = result[0] == 0;
    self.AF.flags.C = result[1];
    self.AF.flags.H = if ((a & 0x0F) + (b & 0x0F) > 0x0F) 1 else 0;
    return result[0];
}

fn alu_add_w(self: *CPU, a: u16, b: u16) u16 {
    const result = @addWithOverflow(a, b);
    self.AF.flags.N = false;
    self.AF.flags.Z = result[0] == 0;
    self.AF.flags.C = result[1];
    self.AF.flags.H = if ((a & 0x00FF) + (b & 0x00FF) > 0x00FF) 1 else 0;
    return result[0];
}

fn alu_and(self: *CPU, a: anytype, b: anytype) @TypeOf(a) {
    const result = a & b;
    self.AF.flags.Z = result == 0;
    self.AF.flags.N = false;
    self.AF.flags.H = 1;
    self.AF.flags.C = 0;
    return result;
}

fn alu_or(self: *CPU, a: anytype, b: anytype) @TypeOf(a) {
    const result = a | b;
    self.AF.flags.Z = result == 0;
    self.AF.flags.N = false;
    self.AF.flags.H = 0;
    self.AF.flags.C = 0;
    return result;
}

fn alu_xor(self: *CPU, a: anytype, b: anytype) @TypeOf(a) {
    const result = a ^ b;
    self.AF.flags.Z = result == 0;
    self.AF.flags.N = false;
    self.AF.flags.H = 0;
    self.AF.flags.C = 0;
    return result;
}

fn alu_bit(self: *CPU, value: u8, comptime bit: u3) void {
    self.AF.flags.Z = (value & 1) << bit == 0;
    self.AF.flags.H = 1;
    self.AF.flags.N = false;
}

fn alu_swap(self: *CPU, value: u8) u8 {
    const low = value & 0x0F;
    const high = value >> 4;
    const result = low << 4 | high;
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = 0,
    };
    return result;
}

fn reset_bit(value: u8, bit: u3) u8 {
    return value & ~(@as(u8, 1) << bit);
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

pub fn call(self: *CPU, mem: *Mem, addr: u16) void {
    self.push_w(mem, self.PC);
    self.PC = addr;
}

pub const MHz = 4194304;
const CYCLES_PER_MS = MHz / 1000;

pub fn tick(self: *CPU, mem: *Mem, dt: i64) void {
    var cycles = dt * CYCLES_PER_MS;
    // if (self.debug) std.debug.print("Run {d}ms = {d} cycles\n\n\n", .{ dt, cycles });

    while (cycles >= 4) {
        self.step(mem);
        if (cycles >= 4) cycles -= 4;
        if (self.debug) return;
    }
}

pub fn step(self: *CPU, mem: *Mem) void {
    mem.lcd.LY +%= 1; // TODO

    if (self.halted) return;

    const opcode = std.meta.intToEnum(Op, mem.read(self.PC)) catch {
        std.debug.panic("[{x}]: Unsupported opcode {x}\n", .{ self.PC, mem.read(self.PC) });
    };

    if (self.debug) std.debug.print("[{X:0>4}]: {s}\t", .{ self.PC, @tagName(opcode) });

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
        .jr_c_ib => {
            const ib = self.read_ib(mem);
            if (self.AF.flags.C == 1) {
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
        .jp_nz_iw => {
            const addr = self.read_iw(mem);
            if (!self.AF.flags.Z) self.PC = addr;
        },

        .ld_sp_iw => {
            self.SP = self.read_iw(mem);
        },

        .ld_bc_iw => self.BC.r16 = self.read_iw(mem),
        .ld_bc_a => mem.write(self.BC.r16, self.AF.r8.A),

        .ld_de_iw => {
            self.DE.r16 = self.read_iw(mem);
        },
        .ld_hl_iw => {
            self.HL.r16 = self.read_iw(mem);
        },

        .dec_a => self.AF.r8.A = self.alu_sub(self.AF.r8.A, 1),
        .dec_b => self.BC.r8.B = self.alu_sub(self.BC.r8.B, 1),
        .dec_c => self.BC.r8.C = self.alu_sub(self.BC.r8.C, 1),
        .dec_d => self.DE.r8.D = self.alu_sub(self.DE.r8.D, 1),
        .dec_e => self.DE.r8.E = self.alu_sub(self.DE.r8.E, 1),
        .dec_h => self.HL.r8.H = self.alu_sub(self.HL.r8.H, 1),
        .dec_l => self.HL.r8.L = self.alu_sub(self.HL.r8.L, 1),

        .dec_bc => self.BC.r16 = self.alu_sub_w(self.BC.r16, 1),
        .dec_hl => self.HL.r16 = self.alu_sub_w(self.HL.r16, 1),

        .dec_mhl => mem.write(self.HL.r16, self.alu_sub(mem.read(self.HL.r16), 1)),

        .inc_a => self.AF.r8.A = self.alu_add(self.AF.r8.A, 1),
        .inc_b => self.BC.r8.B = self.alu_add(self.BC.r8.B, 1),
        .inc_c => self.BC.r8.C = self.alu_add(self.BC.r8.C, 1),
        .inc_d => self.DE.r8.D = self.alu_add(self.DE.r8.D, 1),
        .inc_e => self.DE.r8.E = self.alu_add(self.DE.r8.E, 1),
        .inc_h => self.HL.r8.H = self.alu_add(self.HL.r8.H, 1),
        .inc_l => self.HL.r8.L = self.alu_add(self.HL.r8.L, 1),

        .inc_hl => {
            self.HL.r16 = self.alu_add_w(self.HL.r16, 1);
        },

        .inc_mhl => mem.write(self.HL.r16, self.alu_add(mem.read(self.HL.r16), 1)),

        .inc_bc => self.BC.r16 = self.alu_add_w(self.BC.r16, 1),
        .inc_de => self.DE.r16 = self.alu_add_w(self.DE.r16, 1),

        .add_a => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.AF.r8.A),
        .add_a_l => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.HL.r8.L),

        .add_hl_bc => self.HL.r16 = self.alu_add_w(self.HL.r16, self.BC.r16),
        .add_hl_de => self.HL.r16 = self.alu_add_w(self.HL.r16, self.DE.r16),
        .add_hl_hl => self.HL.r16 = self.alu_add_w(self.HL.r16, self.HL.r16),

        .add_ib => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.read_ib(mem)),

        .add_a_hl => self.AF.r8.A = self.alu_add(self.AF.r8.A, mem.read(self.HL.r16)),
        .adc_a_hl => self.AF.r8.A = self.alu_add(self.AF.r8.A, mem.read(self.HL.r16) + self.AF.flags.C),
        .adc_a__h => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.HL.r8.H + self.AF.flags.C),

        .sub_a_ib => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.read_ib(mem)),

        .ld_de_a => {
            mem.write(self.DE.r16, self.AF.r8.A);
        },

        .ld_hl_a => mem.write(self.HL.r16, self.AF.r8.A),
        .ld_hl_b => mem.write(self.HL.r16, self.BC.r8.B),
        .ld_hl_c => mem.write(self.HL.r16, self.BC.r8.C),
        .ld_hl_d => mem.write(self.HL.r16, self.DE.r8.D),
        .ld_hl_e => mem.write(self.HL.r16, self.DE.r8.E),
        .ld_hl_h => mem.write(self.HL.r16, self.HL.r8.H),
        .ld_hl_l => mem.write(self.HL.r16, self.HL.r8.L),

        .ldd_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 -%= 1;
        },
        .ldi_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 +%= 1;
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

        .ld_a__bc => self.AF.r8.A = mem.read(self.BC.r16),

        .ldi_a__hl => {
            self.AF.r8.A = mem.read(self.HL.r16);
            self.HL.r16 +%= 1;
        },

        .ldd_a__hl => {
            self.AF.r8.A = mem.read(self.HL.r16);
            self.HL.r16 -= 1;
        },

        .ld_a__de => self.AF.r8.A = mem.read(self.DE.r16),

        .ld_a__a => {},
        .ld_a__b => self.AF.r8.A = self.BC.r8.B,
        .ld_a__c => self.AF.r8.A = self.BC.r8.C,
        .ld_a__d => self.AF.r8.A = self.DE.r8.D,
        .ld_a__e => self.AF.r8.A = self.DE.r8.E,
        .ld_a__h => self.AF.r8.A = self.HL.r8.H,
        .ld_a__l => self.AF.r8.A = self.HL.r8.L,
        .ld_a__hl => self.AF.r8.A = mem.read(self.HL.r16),
        .ld_a__ib => self.AF.r8.A = self.read_ib(mem),

        .ld_b__a => self.BC.r8.B = self.AF.r8.A,
        .ld_b__b => {},
        .ld_b__c => self.BC.r8.B = self.BC.r8.C,
        .ld_b__d => self.BC.r8.B = self.DE.r8.D,
        .ld_b__e => self.BC.r8.B = self.DE.r8.E,
        .ld_b__h => self.BC.r8.B = self.HL.r8.H,
        .ld_b__l => self.BC.r8.B = self.HL.r8.L,
        .ld_b__hl => self.BC.r8.B = mem.read(self.HL.r16),
        .ld_b__ib => self.BC.r8.B = self.read_ib(mem),

        .ld_c__a => self.BC.r8.C = self.AF.r8.A,
        .ld_c__ib => self.BC.r8.C = self.read_ib(mem),
        .ld_c__hl => self.BC.r8.C = mem.read(self.HL.r16),

        .ld_d__a => self.DE.r8.D = self.AF.r8.A,
        .ld_d__b => self.DE.r8.D = self.BC.r8.B,
        .ld_d__c => self.DE.r8.D = self.BC.r8.C,
        .ld_d__d => {},
        .ld_d__e => self.DE.r8.D = self.DE.r8.E,
        .ld_d__h => self.DE.r8.D = self.HL.r8.H,
        .ld_d__l => self.DE.r8.D = self.HL.r8.L,
        .ld_d__hl => self.DE.r8.D = mem.read(self.HL.r16),
        .ld_d__ib => self.DE.r8.D = self.read_ib(mem),

        .ld_e__a => self.DE.r8.E = self.AF.r8.A,
        .ld_e__b => self.DE.r8.E = self.BC.r8.B,
        .ld_e__c => self.DE.r8.E = self.BC.r8.C,
        .ld_e__d => self.DE.r8.E = self.DE.r8.D,
        .ld_e__e => {},
        .ld_e__h => self.DE.r8.E = self.HL.r8.H,
        .ld_e__l => self.DE.r8.E = self.HL.r8.L,
        .ld_e__hl => self.DE.r8.E = mem.read(self.HL.r16),
        .ld_e__ib => self.DE.r8.E = self.read_ib(mem),

        .ld_l__a => self.HL.r8.L = self.AF.r8.A,
        .ld_l__b => self.HL.r8.L = self.BC.r8.B,
        .ld_l__c => self.HL.r8.L = self.BC.r8.C,
        .ld_l__d => self.HL.r8.L = self.DE.r8.D,
        .ld_l__e => self.HL.r8.L = self.DE.r8.E,
        .ld_l__h => self.HL.r8.L = self.HL.r8.H,
        .ld_l__l => {},
        .ld_l__hl => self.HL.r8.L = mem.read(self.HL.r16),
        .ld_l__ib => self.HL.r8.L = self.read_ib(mem),

        .ld_h__a => self.HL.r8.H = self.AF.r8.A,
        .ld_h__b => self.HL.r8.H = self.BC.r8.B,
        .ld_h__c => self.HL.r8.H = self.BC.r8.C,
        .ld_h__d => self.HL.r8.H = self.DE.r8.D,
        .ld_h__e => self.HL.r8.H = self.DE.r8.E,
        .ld_h__h => {},
        .ld_h__l => self.HL.r8.H = self.HL.r8.L,
        .ld_h__hl => self.HL.r8.H = mem.read(self.HL.r16),
        .ld_h__ib => self.HL.r8.H = self.read_ib(mem),

        .ldh_a => self.AF.r8.A = mem.read_ff(self.read_ib(mem)),
        .ld_a_miw => self.AF.r8.A = mem.read(self.read_iw(mem)),

        .xor_a_a => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.AF.r8.A),
        .xor_a_b => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.BC.r8.B),
        .xor_a_c => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.BC.r8.C),
        .xor_a_d => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.DE.r8.D),
        .xor_a_e => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.DE.r8.E),
        .xor_a_h => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.HL.r8.H),
        .xor_a_l => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.HL.r8.L),
        .xor_a_hl => self.AF.r8.A = self.alu_xor(self.AF.r8.A, mem.read(self.HL.r16)),
        .xor_a_ib => self.AF.r8.A = self.alu_xor(self.AF.r8.A, self.read_ib(mem)),

        .and_a_a => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.AF.r8.A),
        .and_a_b => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.BC.r8.B),
        .and_a_c => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.BC.r8.C),
        .and_a_d => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.DE.r8.D),
        .and_a_e => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.DE.r8.E),
        .and_a_h => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.HL.r8.H),
        .and_a_l => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.HL.r8.L),
        .and_a_hl => self.AF.r8.A = self.alu_and(self.AF.r8.A, mem.read(self.HL.r16)),
        .and_ib => self.AF.r8.A = self.alu_and(self.AF.r8.A, self.read_ib(mem)),

        .cpl => {
            self.AF.r8.A = ~self.AF.r8.A;
            self.AF.flags.N = true;
            self.AF.flags.H = 1;
        },

        .pop_bc => self.BC.r16 = self.pop_w(mem),
        .pop_de => self.DE.r16 = self.pop_w(mem),
        .pop_hl => self.HL.r16 = self.pop_w(mem),
        .pop_af => self.AF.r16 = self.pop_w(mem),

        .ld_iw_sp => self.push_w(mem, self.read_iw(mem)),

        .push_bc => self.push_w(mem, self.BC.r16),
        .push_de => self.push_w(mem, self.DE.r16),
        .push_hl => self.push_w(mem, self.HL.r16),
        .push_af => self.push_w(mem, self.AF.r16),

        .or_a_a => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.AF.r8.A),
        .or_a_b => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.BC.r8.B),
        .or_a_c => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.BC.r8.C),
        .or_a_ib => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.read_ib(mem)),

        .di => {
            self.IME = false;
        },
        .ei => {
            self.IME = true;
        },

        .cp_a_e => _ = self.alu_sub(self.AF.r8.A, self.DE.r8.E),

        .cp_ib => {
            _ = self.alu_sub(self.AF.r8.A, self.read_ib(mem));
        },

        .call_nz_iw => {
            const addr = self.read_iw(mem);
            if (!self.AF.flags.Z) self.call(mem, addr);
        },

        .call_iw => {
            const addr = self.read_iw(mem);
            self.call(mem, addr);
        },

        .rst_08 => {
            self.push_w(mem, self.PC);
            self.PC = 0x08;
        },

        .rst_28 => {
            self.push_w(mem, self.PC);
            self.PC = 0x28;
        },

        .ret => {
            self.PC = self.pop_w(mem);
        },
        .reti => {
            self.PC = self.pop_w(mem);
            self.IME = true;
        },

        .ret_nz => {
            if (!self.AF.flags.Z) self.PC = self.pop_w(mem);
        },
        .ret_z => {
            if (self.AF.flags.Z) self.PC = self.pop_w(mem);
        },

        .ret_c => {
            if (self.AF.flags.C == 1) self.PC = self.pop_w(mem);
        },
        .ret_nc => {
            if (self.AF.flags.C == 0) self.PC = self.pop_w(mem);
        },

        .rlca => {
            const a = self.AF.r8.A;
            self.AF.r8.A = (a << 1) | (a & 0x80 >> 7);
            self.AF.flags = .{
                .Z = false,
                .N = false,
                .H = 0,
                .C = @intFromBool(a & 0x80 == 1),
            };
        },
        .rrca => {
            const a = self.AF.r8.A;
            self.AF.r8.A = (a >> 1) | (a & 1 << 7);
            self.AF.flags = .{
                .Z = false,
                .N = false,
                .H = 0,
                .C = @intFromBool(a & 1 == 1),
            };
        },

        .cb_prefix => {
            const cb_op = std.meta.intToEnum(CbOp, mem.read(self.PC)) catch {
                std.debug.panic("[{x}]: Unsupported prefix opcode {x}\n", .{ self.PC, mem.read(self.PC) });
            };
            if (self.debug) std.debug.print("{s} ", .{@tagName(cb_op)});
            self.PC += 1;

            switch (cb_op) {
                .sla_a => {
                    const a = self.AF.r8.A;
                    self.AF.r8.A = a << 1;
                    self.AF.flags = .{
                        .Z = self.AF.r8.A == 0,
                        .N = false,
                        .H = 0,
                        .C = @intFromBool(a & 0x80 == 0x80), // 0b10000000
                    };
                },
                .sra_a => {
                    const a = self.AF.r8.A;
                    self.AF.r8.A = (a >> 1) | a & 0x80;
                    self.AF.flags = .{
                        .Z = self.AF.r8.A == 0,
                        .N = false,
                        .H = 0,
                        .C = @intFromBool(a & 1 == 1),
                    };
                },
                .swap_a => self.AF.r8.A = self.alu_swap(self.AF.r8.A),
                .swap_b => self.BC.r8.B = self.alu_swap(self.BC.r8.B),
                .swap_c => self.BC.r8.C = self.alu_swap(self.BC.r8.C),
                .swap_d => self.DE.r8.D = self.alu_swap(self.DE.r8.D),
                .swap_e => self.DE.r8.E = self.alu_swap(self.DE.r8.E),
                .swap_h => self.HL.r8.H = self.alu_swap(self.HL.r8.H),
                .swap_l => self.HL.r8.L = self.alu_swap(self.HL.r8.L),
                .swap_hl => mem.write(self.HL.r16, self.alu_swap(mem.read(self.HL.r16))),

                .res_0_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 0),
                .res_0_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 0)),

                .bit_0_a => self.alu_bit(self.AF.r8.A, 0),
                .bit_1_a => self.alu_bit(self.AF.r8.A, 1),
                .bit_2_a => self.alu_bit(self.AF.r8.A, 2),
                .bit_3_a => self.alu_bit(self.AF.r8.A, 3),
                .bit_4_a => self.alu_bit(self.AF.r8.A, 4),
                .bit_5_a => self.alu_bit(self.AF.r8.A, 5),
                .bit_6_a => self.alu_bit(self.AF.r8.A, 6),
                .bit_7_a => self.alu_bit(self.AF.r8.A, 7),

                .bit_0_b => self.alu_bit(self.BC.r8.B, 0),
                .bit_1_b => self.alu_bit(self.BC.r8.B, 1),
                .bit_2_b => self.alu_bit(self.BC.r8.B, 2),
                .bit_3_b => self.alu_bit(self.BC.r8.B, 3),
                .bit_4_b => self.alu_bit(self.BC.r8.B, 4),
                .bit_5_b => self.alu_bit(self.BC.r8.B, 5),
                .bit_6_b => self.alu_bit(self.BC.r8.B, 6),
                .bit_7_b => self.alu_bit(self.BC.r8.B, 7),

                .bit_7_hl => self.alu_bit(mem.read(self.HL.r16), 7),
            }
        },

        .halt => self.halted = true,

        .daa => {
            var val = self.AF.r8.A;
            var carry = self.AF.flags.C;

            if (self.AF.flags.N) { // subtract
                if (self.AF.flags.H == 1) val -%= 0x6;
                if (carry == 1) val -%= 0x60;
            } else { // add
                if (self.AF.flags.H == 1 or (val & 0x0F) > 0x9) {
                    const ov = @addWithOverflow(val, 0x6);
                    val = ov[0];
                    carry |= ov[1];
                }

                if (carry == 1 or (val >> 4 & 0x0F) > 0x9) {
                    const ov = @addWithOverflow(val, 0x60);
                    val = ov[0];
                    carry |= ov[1];
                }
            }

            self.AF.r8.A = val;
            self.AF.flags = .{
                .Z = val == 0,
                .N = self.AF.flags.N,
                .H = 0,
                .C = carry,
            };
        },
    }

    if (self.debug) std.debug.print("\t\t-- AF: {X:0>4} BC: {X:0>4} DE: {X:0>4} HL: {X:0>4} Z: {any}\n", .{ self.AF.r16, self.BC.r16, self.DE.r16, self.HL.r16, self.AF.flags.Z });
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
