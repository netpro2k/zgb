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

    stop = 0x10,
    ld_de_iw = 0x11,
    ld_de_a = 0x12,
    inc_de = 0x13,
    inc_d = 0x14,
    dec_d = 0x15,
    ld_d__ib = 0x16,
    rla = 0x17,
    jr_ib = 0x18,
    add_hl_de = 0x19,
    ld_a__de = 0x1A,
    dec_de = 0x1B,
    inc_e = 0x1C,
    dec_e = 0x1D,
    ld_e__ib = 0x1E,
    rr_a = 0x1F,

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

    jr_nc_ib = 0x30,
    ld_sp_iw = 0x31,
    ldd_hl_a = 0x32,
    inc_sp = 0x33,
    inc_mhl = 0x34,
    dec_mhl = 0x35,
    ld_hl_ib = 0x36,
    scf = 0x37,
    jr_c_ib = 0x38,
    add_hl_sp = 0x39,
    ldd_a__hl = 0x3A,
    dec_sp = 0x3B,
    inc_a = 0x3C,
    dec_a = 0x3D,
    ld_a__ib = 0x3E,
    ccf = 0x3F,

    ld_b__b = 0x40,
    ld_b__c = 0x41,
    ld_b__d = 0x42,
    ld_b__e = 0x43,
    ld_b__h = 0x44,
    ld_b__l = 0x45,
    ld_b__hl = 0x46,
    ld_b__a = 0x47,
    ld_c__b = 0x48,
    ld_c__c = 0x49,
    ld_c__d = 0x4A,
    ld_c__e = 0x4B,
    ld_c__h = 0x4C,
    ld_c__l = 0x4D,
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

    add_a_b = 0x80,
    add_a_c = 0x81,
    add_a_d = 0x82,
    add_a_e = 0x83,
    add_a_h = 0x84,
    add_a_l = 0x85,
    add_a_hl = 0x86,
    add_a_a = 0x87,
    adc_a_b = 0x88,
    adc_a_c = 0x89,
    adc_a_d = 0x8A,
    adc_a_e = 0x8B,
    adc_a_h = 0x8C,
    adc_a_l = 0x8D,
    adc_a_hl = 0x8E,
    adc_a_a = 0x8F,

    sub_a_b = 0x90,
    sub_a_c = 0x91,
    sub_a_d = 0x92,
    sub_a_e = 0x93,
    sub_a_h = 0x94,
    sub_a_l = 0x95,
    sub_a_hl = 0x96,
    sub_a_a = 0x97,
    sbc_a_b = 0x98,
    sbc_a_c = 0x99,
    sbc_a_d = 0x9A,
    sbc_a_e = 0x9B,
    sbc_a_h = 0x9C,
    sbc_a_l = 0x9D,
    sbc_a_hl = 0x9E,
    sbc_a_a = 0x9F,

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
    or_a_d = 0xB2,
    or_a_e = 0xB3,
    or_a_h = 0xB4,
    or_a_l = 0xB5,
    or_a_hl = 0xB6,
    or_a_a = 0xB7,
    cp_a_b = 0xB8,
    cp_a_c = 0xB9,
    cp_a_d = 0xBA,
    cp_a_e = 0xBB,
    cp_a_h = 0xBC,
    cp_a_l = 0xBD,
    cp_a_hl = 0xBE,
    cp_a_a = 0xBF,

    ret_nz = 0xC0,
    pop_bc = 0xC1,
    jp_nz_iw = 0xC2,
    jp_iw = 0xC3,
    call_nz_iw = 0xC4,
    push_bc = 0xC5,
    add_a_ib = 0xC6,
    rst_00 = 0xC7,
    ret_z = 0xC8,
    ret = 0xC9,
    jp_z_iw = 0xCA,
    cb_prefix = 0xCB,
    call_z_iw = 0xCC,
    call_iw = 0xCD,
    adc_a_ib = 0xCE,
    rst_08 = 0xCF,

    ret_nc = 0xD0,
    pop_de = 0xD1,
    jp_nc_iw = 0xD2,
    // no D3
    call_nc_iw = 0xD4,
    push_de = 0xD5,
    sub_a_ib = 0xD6,
    rst_10 = 0xD7,
    ret_c = 0xD8,
    reti = 0xD9,
    jp_c_iw = 0xDA,
    // no DB
    call_c_iw = 0xDC,
    // no DD
    sbc_a_ib = 0xDE,
    rst_18 = 0xDF,

    ld_ib_a = 0xE0,
    pop_hl = 0xE1,
    ld_mc_a = 0xE2,
    // no E3
    // no E4
    push_hl = 0xE5,
    and_ib = 0xE6,
    rst_20 = 0xE7,
    add_sp_ib = 0xE8,
    jp_hl = 0xE9,
    ld_iw_a = 0xEA,
    // no EB
    // no EC
    // no ED
    xor_a_ib = 0xEE,
    rst_28 = 0xEF,

    ldh_a = 0xF0,
    pop_af = 0xF1,
    ld_a_ffc = 0xf2,
    di = 0xF3,
    // no F4
    push_af = 0xF5,
    or_a_ib = 0xF6,
    rst_30 = 0xF7,
    ld_hl_sp_ib = 0xF8,
    ld_sp_hl = 0xF9,
    ld_a_miw = 0xFA,
    ei = 0xFB,
    // no FC
    // no FD
    cp_a_ib = 0xFE,
    rst_38 = 0xFF,
};

const CbOp = enum(u8) {
    rlc_b = 0x00,
    rlc_c = 0x01,
    rlc_d = 0x02,
    rlc_e = 0x03,
    rlc_h = 0x04,
    rlc_l = 0x05,
    rlc_hl = 0x06,
    rlc_a = 0x07,
    rrc_b = 0x08,
    rrc_c = 0x09,
    rrc_d = 0x0A,
    rrc_e = 0x0B,
    rrc_h = 0x0C,
    rrc_l = 0x0D,
    rrc_hl = 0x0E,
    rrc_a = 0x0F,

    rl_b = 0x10,
    rl_c = 0x11,
    rl_d = 0x12,
    rl_e = 0x13,
    rl_h = 0x14,
    rl_l = 0x15,
    rl_hl = 0x16,
    rl_a = 0x17,
    rr_b = 0x18,
    rr_c = 0x19,
    rr_d = 0x1A,
    rr_e = 0x1B,
    rr_h = 0x1C,
    rr_l = 0x1D,
    rr_hl = 0x1E,
    rr_a = 0x1F,

    sla_b = 0x20,
    sla_c = 0x21,
    sla_d = 0x22,
    sla_e = 0x23,
    sla_h = 0x24,
    sla_l = 0x25,
    sla_hl = 0x26,
    sla_a = 0x27,
    sra_b = 0x28,
    sra_c = 0x29,
    sra_d = 0x2A,
    sra_e = 0x2B,
    sra_h = 0x2C,
    sra_l = 0x2D,
    sra_hl = 0x2E,
    sra_a = 0x2F,

    swap_b = 0x30,
    swap_c = 0x31,
    swap_d = 0x32,
    swap_e = 0x33,
    swap_h = 0x34,
    swap_l = 0x35,
    swap_hl = 0x36,
    swap_a = 0x37,
    srl_b = 0x38,
    srl_c = 0x39,
    srl_d = 0x3A,
    srl_e = 0x3B,
    srl_h = 0x3C,
    srl_l = 0x3D,
    srl_hl = 0x3E,
    srl_a = 0x3F,

    bit_0_b = 0x40,
    bit_0_c = 0x41,
    bit_0_d = 0x42,
    bit_0_e = 0x43,
    bit_0_h = 0x44,
    bit_0_l = 0x45,
    bit_0_hl = 0x46,
    bit_0_a = 0x47,
    bit_1_b = 0x48,
    bit_1_c = 0x49,
    bit_1_d = 0x4A,
    bit_1_e = 0x4B,
    bit_1_h = 0x4C,
    bit_1_l = 0x4D,
    bit_1_hl = 0x4E,
    bit_1_a = 0x4F,

    bit_2_b = 0x50,
    bit_2_c = 0x51,
    bit_2_d = 0x52,
    bit_2_e = 0x53,
    bit_2_h = 0x54,
    bit_2_l = 0x55,
    bit_2_hl = 0x56,
    bit_2_a = 0x57,
    bit_3_b = 0x58,
    bit_3_c = 0x59,
    bit_3_d = 0x5A,
    bit_3_e = 0x5B,
    bit_3_h = 0x5C,
    bit_3_l = 0x5D,
    bit_3_hl = 0x5E,
    bit_3_a = 0x5F,

    bit_4_b = 0x60,
    bit_4_c = 0x61,
    bit_4_d = 0x62,
    bit_4_e = 0x63,
    bit_4_h = 0x64,
    bit_4_l = 0x65,
    bit_4_hl = 0x66,
    bit_4_a = 0x67,
    bit_5_b = 0x68,
    bit_5_c = 0x69,
    bit_5_d = 0x6A,
    bit_5_e = 0x6B,
    bit_5_h = 0x6C,
    bit_5_l = 0x6D,
    bit_5_hl = 0x6E,
    bit_5_a = 0x6F,

    bit_6_b = 0x70,
    bit_6_c = 0x71,
    bit_6_d = 0x72,
    bit_6_e = 0x73,
    bit_6_h = 0x74,
    bit_6_l = 0x75,
    bit_6_hl = 0x76,
    bit_6_a = 0x77,
    bit_7_b = 0x78,
    bit_7_c = 0x79,
    bit_7_d = 0x7A,
    bit_7_e = 0x7B,
    bit_7_h = 0x7C,
    bit_7_l = 0x7D,
    bit_7_hl = 0x7E,
    bit_7_a = 0x7F,

    res_0_b = 0x80,
    res_0_c = 0x81,
    res_0_d = 0x82,
    res_0_e = 0x83,
    res_0_h = 0x84,
    res_0_l = 0x85,
    res_0_hl = 0x86,
    res_0_a = 0x87,
    res_1_b = 0x88,
    res_1_c = 0x89,
    res_1_d = 0x8A,
    res_1_e = 0x8B,
    res_1_h = 0x8C,
    res_1_l = 0x8D,
    res_1_hl = 0x8E,
    res_1_a = 0x8F,

    res_2_b = 0x90,
    res_2_c = 0x91,
    res_2_d = 0x92,
    res_2_e = 0x93,
    res_2_h = 0x94,
    res_2_l = 0x95,
    res_2_hl = 0x96,
    res_2_a = 0x97,
    res_3_b = 0x98,
    res_3_c = 0x99,
    res_3_d = 0x9A,
    res_3_e = 0x9B,
    res_3_h = 0x9C,
    res_3_l = 0x9D,
    res_3_hl = 0x9E,
    res_3_a = 0x9F,

    res_4_b = 0xA0,
    res_4_c = 0xA1,
    res_4_d = 0xA2,
    res_4_e = 0xA3,
    res_4_h = 0xA4,
    res_4_l = 0xA5,
    res_4_hl = 0xA6,
    res_4_a = 0xA7,
    res_5_b = 0xA8,
    res_5_c = 0xA9,
    res_5_d = 0xAA,
    res_5_e = 0xAB,
    res_5_h = 0xAC,
    res_5_l = 0xAD,
    res_5_hl = 0xAE,
    res_5_a = 0xAF,

    res_6_b = 0xB0,
    res_6_c = 0xB1,
    res_6_d = 0xB2,
    res_6_e = 0xB3,
    res_6_h = 0xB4,
    res_6_l = 0xB5,
    res_6_hl = 0xB6,
    res_6_a = 0xB7,
    res_7_b = 0xB8,
    res_7_c = 0xB9,
    res_7_d = 0xBA,
    res_7_e = 0xBB,
    res_7_h = 0xBC,
    res_7_l = 0xBD,
    res_7_hl = 0xBE,
    res_7_a = 0xBF,

    set_0_b = 0xC0,
    set_0_c = 0xC1,
    set_0_d = 0xC2,
    set_0_e = 0xC3,
    set_0_h = 0xC4,
    set_0_l = 0xC5,
    set_0_hl = 0xC6,
    set_0_a = 0xC7,
    set_1_b = 0xC8,
    set_1_c = 0xC9,
    set_1_d = 0xCA,
    set_1_e = 0xCB,
    set_1_h = 0xCC,
    set_1_l = 0xCD,
    set_1_hl = 0xCE,
    set_1_a = 0xCF,

    set_2_b = 0xD0,
    set_2_c = 0xD1,
    set_2_d = 0xD2,
    set_2_e = 0xD3,
    set_2_h = 0xD4,
    set_2_l = 0xD5,
    set_2_hl = 0xD6,
    set_2_a = 0xD7,
    set_3_b = 0xD8,
    set_3_c = 0xD9,
    set_3_d = 0xDA,
    set_3_e = 0xDB,
    set_3_h = 0xDC,
    set_3_l = 0xDD,
    set_3_hl = 0xDE,
    set_3_a = 0xDF,

    set_4_b = 0xE0,
    set_4_c = 0xE1,
    set_4_d = 0xE2,
    set_4_e = 0xE3,
    set_4_h = 0xE4,
    set_4_l = 0xE5,
    set_4_hl = 0xE6,
    set_4_a = 0xE7,
    set_5_b = 0xE8,
    set_5_c = 0xE9,
    set_5_d = 0xEA,
    set_5_e = 0xEB,
    set_5_h = 0xEC,
    set_5_l = 0xED,
    set_5_hl = 0xEE,
    set_5_a = 0xEF,

    set_6_b = 0xF0,
    set_6_c = 0xF1,
    set_6_d = 0xF2,
    set_6_e = 0xF3,
    set_6_h = 0xF4,
    set_6_l = 0xF5,
    set_6_hl = 0xF6,
    set_6_a = 0xF7,
    set_7_b = 0xF8,
    set_7_c = 0xF9,
    set_7_d = 0xFA,
    set_7_e = 0xFB,
    set_7_h = 0xFC,
    set_7_l = 0xFD,
    set_7_hl = 0xFE,
    set_7_a = 0xFF,
};

fn signed_add(a: u16, b: u8) u16 {
    const signed = @as(i16, @bitCast(a)) +% @as(i8, @bitCast(b));
    return @as(u16, @bitCast(signed));
}

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
    self.AF.flags.C = @intFromBool(a < b);
    self.AF.flags.H = @intFromBool((a & 0x0F) < (b & 0x0F));
    return result;
}

fn alu_inc(self: *CPU, a: u8) u8 {
    const result = a +% 1;
    self.AF.flags.N = false;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = self.AF.flags.C;
    self.AF.flags.H = @intFromBool((a & 0x0F) + 1 > 0x0F);
    return result;
}

fn alu_dec(self: *CPU, a: u8) u8 {
    const result = a -% 1;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = self.AF.flags.C;
    self.AF.flags.H = @intFromBool((a & 0x0F) == 0);
    return result;
}

fn alu_sbc(self: *CPU, a: u8, b: u8) u8 {
    const c = self.AF.flags.C;
    const result = a -% b -% c;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = @intFromBool(@as(u16, a) < (@as(u16, b) + c));
    self.AF.flags.H = @intFromBool((a & 0x0F) < (b & 0x0F) + c);
    return result;
}

fn alu_sub_w(self: *CPU, a: u16, b: u16) u16 {
    const result = a -% b;
    self.AF.flags.N = true;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = @intFromBool(a < b);
    self.AF.flags.H = @intFromBool((a & 0x0FFF) < (b & 0x0FFF));
    return result;
}

fn alu_add(self: *CPU, a: u8, b: u8) u8 {
    const result = a +% b;
    self.AF.flags.N = false;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = @intFromBool(@as(u16, a) + @as(u16, b) > 0xFF);
    self.AF.flags.H = @intFromBool((a & 0x0F) + (b & 0x0F) > 0x0F);
    return result;
}

fn alu_adc(self: *CPU, a: u8, b: u8) u8 {
    const c = self.AF.flags.C;
    const result = a +% b +% c;
    self.AF.flags.N = false;
    self.AF.flags.Z = result == 0;
    self.AF.flags.C = @intFromBool(@as(u16, a) + @as(u16, b) + c > 0xFF);
    self.AF.flags.H = @intFromBool((a & 0x0F) + (b & 0x0F) + c > 0x0F);
    return result;
}

fn alu_add_w(self: *CPU, a: u16, b: u16) u16 {
    const result = a +% b;
    self.AF.flags.N = false;
    self.AF.flags.Z = self.AF.flags.Z;
    self.AF.flags.C = @intFromBool(@as(u32, a) + @as(u32, b) > 0xFFFF);
    self.AF.flags.H = @intFromBool((a & 0x0FFF) + (b & 0x0FFF) > 0x0FFF);
    return result;
}

fn willCarryInto(size: u5, a: i32, b: i32) u1 {
    if (a < 0 or b < 0) {
        return 0;
    }
    const mask = (@as(u32, 1) << size) - 1;
    return @intFromBool((@as(u32, @intCast(a)) & mask) + (@as(u32, @intCast(b)) & mask) > mask);
}

fn alu_add_w_i(self: *CPU, a: u16, b: u8) u16 {
    const result = signed_add(a, b);
    self.AF.flags.N = false;
    self.AF.flags.Z = false;
    self.AF.flags.C = @intFromBool((a & 0x00FF) + (b & 0x00FF) > 0x00FF);
    self.AF.flags.H = @intFromBool((a & 0x000F) + (b & 0x000F) > 0x000F);
    return result;
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
    self.AF.flags.Z = value & (1 << bit) == 0;
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

fn alu_srl(self: *CPU, value: u8) u8 {
    const result = (value >> 1);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value & 1),
    };
    return result;
}

fn alu_sra(self: *CPU, value: u8) u8 {
    const result = (value >> 1) | (value & 0x80);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value & 1),
    };
    return result;
}

fn alu_rr(self: *CPU, value: u8) u8 {
    const result = (value >> 1) | (@as(u8, self.AF.flags.C) << 7);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value & 1),
    };
    return result;
}

fn alu_rrc(self: *CPU, value: u8) u8 {
    const result = (value >> 1) | ((value & 1) << 7);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value & 1),
    };
    return result;
}

fn alu_sla(self: *CPU, value: u8) u8 {
    const result = (value << 1);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value >> 7),
    };
    return result;
}

fn alu_rl(self: *CPU, value: u8) u8 {
    const result = (value << 1) | @as(u8, self.AF.flags.C);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value >> 7),
    };
    return result;
}

fn alu_rlc(self: *CPU, value: u8) u8 {
    const result = (value << 1) | (value >> 7);
    self.AF.flags = .{
        .Z = result == 0,
        .N = false,
        .H = 0,
        .C = @truncate(value >> 7),
    };
    return result;
}

fn set_bit(value: u8, bit: u3) u8 {
    return value | (@as(u8, 1) << bit);
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
        mem.tick(4);
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

        .jp_z_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.Z) self.PC = addr;
        },
        .jp_nz_iw => {
            const addr = self.read_iw(mem);
            if (!self.AF.flags.Z) self.PC = addr;
        },

        .jp_c_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.C == 1) self.PC = addr;
        },
        .jp_nc_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.C == 0) self.PC = addr;
        },

        .jr_z_ib => {
            const ib = self.read_ib(mem);
            if (self.AF.flags.Z) self.PC = signed_add(self.PC, ib);
        },
        .jr_nz_ib => {
            const ib = self.read_ib(mem);
            if (!self.AF.flags.Z) self.PC = signed_add(self.PC, ib);
        },

        .jr_c_ib => {
            const ib = self.read_ib(mem);
            if (self.AF.flags.C == 1) self.PC = signed_add(self.PC, ib);
        },
        .jr_nc_ib => {
            const ib = self.read_ib(mem);
            if (self.AF.flags.C != 1) self.PC = signed_add(self.PC, ib);
        },

        .jr_ib => {
            const ib = self.read_ib(mem);
            self.PC = signed_add(self.PC, ib);
        },

        .ld_sp_iw => self.SP = self.read_iw(mem),
        .ld_sp_hl => self.SP = self.HL.r16,

        .ld_bc_iw => self.BC.r16 = self.read_iw(mem),
        .ld_bc_a => mem.write(self.BC.r16, self.AF.r8.A),

        .ld_de_iw => {
            self.DE.r16 = self.read_iw(mem);
        },
        .ld_hl_iw => {
            self.HL.r16 = self.read_iw(mem);
        },

        .inc_a => self.AF.r8.A = self.alu_inc(self.AF.r8.A),
        .inc_b => self.BC.r8.B = self.alu_inc(self.BC.r8.B),
        .inc_c => self.BC.r8.C = self.alu_inc(self.BC.r8.C),
        .inc_d => self.DE.r8.D = self.alu_inc(self.DE.r8.D),
        .inc_e => self.DE.r8.E = self.alu_inc(self.DE.r8.E),
        .inc_h => self.HL.r8.H = self.alu_inc(self.HL.r8.H),
        .inc_l => self.HL.r8.L = self.alu_inc(self.HL.r8.L),

        .dec_a => self.AF.r8.A = self.alu_dec(self.AF.r8.A),
        .dec_b => self.BC.r8.B = self.alu_dec(self.BC.r8.B),
        .dec_c => self.BC.r8.C = self.alu_dec(self.BC.r8.C),
        .dec_d => self.DE.r8.D = self.alu_dec(self.DE.r8.D),
        .dec_e => self.DE.r8.E = self.alu_dec(self.DE.r8.E),
        .dec_h => self.HL.r8.H = self.alu_dec(self.HL.r8.H),
        .dec_l => self.HL.r8.L = self.alu_dec(self.HL.r8.L),

        .inc_mhl => mem.write(self.HL.r16, self.alu_inc(mem.read(self.HL.r16))),
        .dec_mhl => mem.write(self.HL.r16, self.alu_dec(mem.read(self.HL.r16))),

        .inc_bc => self.BC.r16 +%= 1,
        .inc_de => self.DE.r16 +%= 1,
        .inc_hl => self.HL.r16 +%= 1,
        .inc_sp => self.SP +%= 1,

        .dec_bc => self.BC.r16 -%= 1,
        .dec_de => self.DE.r16 -%= 1,
        .dec_hl => self.HL.r16 -%= 1,
        .dec_sp => self.SP -%= 1,

        .add_a_a => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.AF.r8.A),
        .add_a_b => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.BC.r8.B),
        .add_a_c => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.BC.r8.C),
        .add_a_d => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.DE.r8.D),
        .add_a_e => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.DE.r8.E),
        .add_a_h => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.HL.r8.H),
        .add_a_l => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.HL.r8.L),
        .add_a_hl => self.AF.r8.A = self.alu_add(self.AF.r8.A, mem.read(self.HL.r16)),
        .add_a_ib => self.AF.r8.A = self.alu_add(self.AF.r8.A, self.read_ib(mem)),

        .add_hl_bc => self.HL.r16 = self.alu_add_w(self.HL.r16, self.BC.r16),
        .add_hl_de => self.HL.r16 = self.alu_add_w(self.HL.r16, self.DE.r16),
        .add_hl_hl => self.HL.r16 = self.alu_add_w(self.HL.r16, self.HL.r16),
        .add_hl_sp => self.HL.r16 = self.alu_add_w(self.HL.r16, self.SP),

        .add_sp_ib => self.SP = self.alu_add_w_i(self.SP, self.read_ib(mem)),

        .adc_a_a => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.AF.r8.A),
        .adc_a_b => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.BC.r8.B),
        .adc_a_c => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.BC.r8.C),
        .adc_a_d => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.DE.r8.D),
        .adc_a_e => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.DE.r8.E),
        .adc_a_h => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.HL.r8.H),
        .adc_a_l => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.HL.r8.L),
        .adc_a_hl => self.AF.r8.A = self.alu_adc(self.AF.r8.A, mem.read(self.HL.r16)),
        .adc_a_ib => self.AF.r8.A = self.alu_adc(self.AF.r8.A, self.read_ib(mem)),

        .sub_a_a => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.AF.r8.A),
        .sub_a_b => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.BC.r8.B),
        .sub_a_c => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.BC.r8.C),
        .sub_a_d => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.DE.r8.D),
        .sub_a_e => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.DE.r8.E),
        .sub_a_h => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.HL.r8.H),
        .sub_a_l => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.HL.r8.L),
        .sub_a_hl => self.AF.r8.A = self.alu_sub(self.AF.r8.A, mem.read(self.HL.r16)),
        .sub_a_ib => self.AF.r8.A = self.alu_sub(self.AF.r8.A, self.read_ib(mem)),

        .sbc_a_a => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.AF.r8.A),
        .sbc_a_b => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.BC.r8.B),
        .sbc_a_c => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.BC.r8.C),
        .sbc_a_d => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.DE.r8.D),
        .sbc_a_e => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.DE.r8.E),
        .sbc_a_h => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.HL.r8.H),
        .sbc_a_l => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.HL.r8.L),
        .sbc_a_hl => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, mem.read(self.HL.r16)),
        .sbc_a_ib => self.AF.r8.A = self.alu_sbc(self.AF.r8.A, self.read_ib(mem)),

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
        .ld_hl_ib => mem.write(self.HL.r16, self.read_ib(mem)),

        .ld_hl_sp_ib => self.HL.r16 = self.alu_add_w_i(self.SP, self.read_ib(mem)),

        .ldd_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 -%= 1;
        },
        .ldi_hl_a => {
            mem.write(self.HL.r16, self.AF.r8.A);
            self.HL.r16 +%= 1;
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

        .ld_a_ffc => self.AF.r8.A = mem.read_ff(self.BC.r8.C),

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
        .ld_c__b => self.BC.r8.C = self.BC.r8.B,
        .ld_c__c => {},
        .ld_c__d => self.BC.r8.C = self.DE.r8.D,
        .ld_c__e => self.BC.r8.C = self.DE.r8.E,
        .ld_c__h => self.BC.r8.C = self.HL.r8.H,
        .ld_c__l => self.BC.r8.C = self.HL.r8.L,
        .ld_c__hl => self.BC.r8.C = mem.read(self.HL.r16),
        .ld_c__ib => self.BC.r8.C = self.read_ib(mem),

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

        .scf => {
            self.AF.flags.C = 1;
            self.AF.flags.H = 0;
            self.AF.flags.N = false;
        },

        .ccf => {
            self.AF.flags.C = ~self.AF.flags.C;
            self.AF.flags.H = 0;
            self.AF.flags.N = false;
        },

        .pop_bc => self.BC.r16 = self.pop_w(mem),
        .pop_de => self.DE.r16 = self.pop_w(mem),
        .pop_hl => self.HL.r16 = self.pop_w(mem),
        .pop_af => self.AF.r16 = self.pop_w(mem) & 0xFFF0,

        .ld_iw_sp => {
            const addr = self.read_iw(mem);
            mem.write(addr, @truncate(self.SP));
            mem.write(addr + 1, @truncate(self.SP >> 8));
        },

        .push_bc => self.push_w(mem, self.BC.r16),
        .push_de => self.push_w(mem, self.DE.r16),
        .push_hl => self.push_w(mem, self.HL.r16),
        .push_af => self.push_w(mem, self.AF.r16),

        .or_a_a => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.AF.r8.A),
        .or_a_b => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.BC.r8.B),
        .or_a_c => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.BC.r8.C),
        .or_a_d => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.DE.r8.D),
        .or_a_e => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.DE.r8.E),
        .or_a_h => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.HL.r8.H),
        .or_a_l => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.HL.r8.L),
        .or_a_hl => self.AF.r8.A = self.alu_or(self.AF.r8.A, mem.read(self.HL.r16)),
        .or_a_ib => self.AF.r8.A = self.alu_or(self.AF.r8.A, self.read_ib(mem)),

        .di => self.IME = false,
        .ei => self.IME = true,

        .cp_a_a => _ = self.alu_sub(self.AF.r8.A, self.AF.r8.A),
        .cp_a_b => _ = self.alu_sub(self.AF.r8.A, self.BC.r8.B),
        .cp_a_c => _ = self.alu_sub(self.AF.r8.A, self.BC.r8.C),
        .cp_a_d => _ = self.alu_sub(self.AF.r8.A, self.DE.r8.D),
        .cp_a_e => _ = self.alu_sub(self.AF.r8.A, self.DE.r8.E),
        .cp_a_h => _ = self.alu_sub(self.AF.r8.A, self.HL.r8.H),
        .cp_a_l => _ = self.alu_sub(self.AF.r8.A, self.HL.r8.L),
        .cp_a_hl => _ = self.alu_sub(self.AF.r8.A, mem.read(self.HL.r16)),
        .cp_a_ib => _ = self.alu_sub(self.AF.r8.A, self.read_ib(mem)),

        .call_z_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.Z) self.call(mem, addr);
        },
        .call_nz_iw => {
            const addr = self.read_iw(mem);
            if (!self.AF.flags.Z) self.call(mem, addr);
        },
        .call_c_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.C == 1) self.call(mem, addr);
        },
        .call_nc_iw => {
            const addr = self.read_iw(mem);
            if (self.AF.flags.C == 0) self.call(mem, addr);
        },

        .call_iw => {
            const addr = self.read_iw(mem);
            self.call(mem, addr);
        },

        .rst_00 => self.call(mem, 0x00),
        .rst_08 => self.call(mem, 0x08),
        .rst_10 => self.call(mem, 0x10),
        .rst_18 => self.call(mem, 0x18),
        .rst_20 => self.call(mem, 0x20),
        .rst_28 => self.call(mem, 0x28),
        .rst_30 => self.call(mem, 0x30),
        .rst_38 => self.call(mem, 0x38),

        .ret => self.PC = self.pop_w(mem),
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

        .rla => {
            self.AF.r8.A = self.alu_rl(self.AF.r8.A);
            self.AF.flags.Z = false;
        },
        .rlca => {
            self.AF.r8.A = self.alu_rlc(self.AF.r8.A);
            self.AF.flags.Z = false;
        },
        .rr_a => {
            self.AF.r8.A = self.alu_rr(self.AF.r8.A);
            self.AF.flags.Z = false;
        },
        .rrca => {
            self.AF.r8.A = self.alu_rrc(self.AF.r8.A);
            self.AF.flags.Z = false;
        },

        .cb_prefix => {
            const cb_op = std.meta.intToEnum(CbOp, mem.read(self.PC)) catch {
                std.debug.panic("[{x}]: Unsupported prefix opcode {x}\n", .{ self.PC, mem.read(self.PC) });
            };
            if (self.debug) std.debug.print("{s} ", .{@tagName(cb_op)});
            self.PC += 1;

            // TODO these can be decoded much less verbosely
            switch (cb_op) {
                .srl_a => self.AF.r8.A = self.alu_srl(self.AF.r8.A),
                .srl_b => self.BC.r8.B = self.alu_srl(self.BC.r8.B),
                .srl_c => self.BC.r8.C = self.alu_srl(self.BC.r8.C),
                .srl_d => self.DE.r8.D = self.alu_srl(self.DE.r8.D),
                .srl_e => self.DE.r8.E = self.alu_srl(self.DE.r8.E),
                .srl_h => self.HL.r8.H = self.alu_srl(self.HL.r8.H),
                .srl_l => self.HL.r8.L = self.alu_srl(self.HL.r8.L),
                .srl_hl => mem.write(self.HL.r16, self.alu_srl(mem.read(self.HL.r16))),

                .rr_a => self.AF.r8.A = self.alu_rr(self.AF.r8.A),
                .rr_b => self.BC.r8.B = self.alu_rr(self.BC.r8.B),
                .rr_c => self.BC.r8.C = self.alu_rr(self.BC.r8.C),
                .rr_d => self.DE.r8.D = self.alu_rr(self.DE.r8.D),
                .rr_e => self.DE.r8.E = self.alu_rr(self.DE.r8.E),
                .rr_h => self.HL.r8.H = self.alu_rr(self.HL.r8.H),
                .rr_l => self.HL.r8.L = self.alu_rr(self.HL.r8.L),
                .rr_hl => mem.write(self.HL.r16, self.alu_rr(mem.read(self.HL.r16))),

                .rl_a => self.AF.r8.A = self.alu_rl(self.AF.r8.A),
                .rl_b => self.BC.r8.B = self.alu_rl(self.BC.r8.B),
                .rl_c => self.BC.r8.C = self.alu_rl(self.BC.r8.C),
                .rl_d => self.DE.r8.D = self.alu_rl(self.DE.r8.D),
                .rl_e => self.DE.r8.E = self.alu_rl(self.DE.r8.E),
                .rl_h => self.HL.r8.H = self.alu_rl(self.HL.r8.H),
                .rl_l => self.HL.r8.L = self.alu_rl(self.HL.r8.L),
                .rl_hl => mem.write(self.HL.r16, self.alu_rl(mem.read(self.HL.r16))),

                .rlc_a => self.AF.r8.A = self.alu_rlc(self.AF.r8.A),
                .rlc_b => self.BC.r8.B = self.alu_rlc(self.BC.r8.B),
                .rlc_c => self.BC.r8.C = self.alu_rlc(self.BC.r8.C),
                .rlc_d => self.DE.r8.D = self.alu_rlc(self.DE.r8.D),
                .rlc_e => self.DE.r8.E = self.alu_rlc(self.DE.r8.E),
                .rlc_h => self.HL.r8.H = self.alu_rlc(self.HL.r8.H),
                .rlc_l => self.HL.r8.L = self.alu_rlc(self.HL.r8.L),
                .rlc_hl => mem.write(self.HL.r16, self.alu_rlc(mem.read(self.HL.r16))),

                .rrc_a => self.AF.r8.A = self.alu_rrc(self.AF.r8.A),
                .rrc_b => self.BC.r8.B = self.alu_rrc(self.BC.r8.B),
                .rrc_c => self.BC.r8.C = self.alu_rrc(self.BC.r8.C),
                .rrc_d => self.DE.r8.D = self.alu_rrc(self.DE.r8.D),
                .rrc_e => self.DE.r8.E = self.alu_rrc(self.DE.r8.E),
                .rrc_h => self.HL.r8.H = self.alu_rrc(self.HL.r8.H),
                .rrc_l => self.HL.r8.L = self.alu_rrc(self.HL.r8.L),
                .rrc_hl => mem.write(self.HL.r16, self.alu_rrc(mem.read(self.HL.r16))),

                .sla_a => self.AF.r8.A = self.alu_sla(self.AF.r8.A),
                .sla_b => self.BC.r8.B = self.alu_sla(self.BC.r8.B),
                .sla_c => self.BC.r8.C = self.alu_sla(self.BC.r8.C),
                .sla_d => self.DE.r8.D = self.alu_sla(self.DE.r8.D),
                .sla_e => self.DE.r8.E = self.alu_sla(self.DE.r8.E),
                .sla_h => self.HL.r8.H = self.alu_sla(self.HL.r8.H),
                .sla_l => self.HL.r8.L = self.alu_sla(self.HL.r8.L),
                .sla_hl => mem.write(self.HL.r16, self.alu_sla(mem.read(self.HL.r16))),

                .sra_a => self.AF.r8.A = self.alu_sra(self.AF.r8.A),
                .sra_b => self.BC.r8.B = self.alu_sra(self.BC.r8.B),
                .sra_c => self.BC.r8.C = self.alu_sra(self.BC.r8.C),
                .sra_d => self.DE.r8.D = self.alu_sra(self.DE.r8.D),
                .sra_e => self.DE.r8.E = self.alu_sra(self.DE.r8.E),
                .sra_h => self.HL.r8.H = self.alu_sra(self.HL.r8.H),
                .sra_l => self.HL.r8.L = self.alu_sra(self.HL.r8.L),
                .sra_hl => mem.write(self.HL.r16, self.alu_sra(mem.read(self.HL.r16))),

                .swap_a => self.AF.r8.A = self.alu_swap(self.AF.r8.A),
                .swap_b => self.BC.r8.B = self.alu_swap(self.BC.r8.B),
                .swap_c => self.BC.r8.C = self.alu_swap(self.BC.r8.C),
                .swap_d => self.DE.r8.D = self.alu_swap(self.DE.r8.D),
                .swap_e => self.DE.r8.E = self.alu_swap(self.DE.r8.E),
                .swap_h => self.HL.r8.H = self.alu_swap(self.HL.r8.H),
                .swap_l => self.HL.r8.L = self.alu_swap(self.HL.r8.L),
                .swap_hl => mem.write(self.HL.r16, self.alu_swap(mem.read(self.HL.r16))),

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

                .bit_0_c => self.alu_bit(self.BC.r8.C, 0),
                .bit_1_c => self.alu_bit(self.BC.r8.C, 1),
                .bit_2_c => self.alu_bit(self.BC.r8.C, 2),
                .bit_3_c => self.alu_bit(self.BC.r8.C, 3),
                .bit_4_c => self.alu_bit(self.BC.r8.C, 4),
                .bit_5_c => self.alu_bit(self.BC.r8.C, 5),
                .bit_6_c => self.alu_bit(self.BC.r8.C, 6),
                .bit_7_c => self.alu_bit(self.BC.r8.C, 7),

                .bit_0_d => self.alu_bit(self.DE.r8.D, 0),
                .bit_1_d => self.alu_bit(self.DE.r8.D, 1),
                .bit_2_d => self.alu_bit(self.DE.r8.D, 2),
                .bit_3_d => self.alu_bit(self.DE.r8.D, 3),
                .bit_4_d => self.alu_bit(self.DE.r8.D, 4),
                .bit_5_d => self.alu_bit(self.DE.r8.D, 5),
                .bit_6_d => self.alu_bit(self.DE.r8.D, 6),
                .bit_7_d => self.alu_bit(self.DE.r8.D, 7),

                .bit_0_e => self.alu_bit(self.DE.r8.E, 0),
                .bit_1_e => self.alu_bit(self.DE.r8.E, 1),
                .bit_2_e => self.alu_bit(self.DE.r8.E, 2),
                .bit_3_e => self.alu_bit(self.DE.r8.E, 3),
                .bit_4_e => self.alu_bit(self.DE.r8.E, 4),
                .bit_5_e => self.alu_bit(self.DE.r8.E, 5),
                .bit_6_e => self.alu_bit(self.DE.r8.E, 6),
                .bit_7_e => self.alu_bit(self.DE.r8.E, 7),

                .bit_0_h => self.alu_bit(self.HL.r8.H, 0),
                .bit_1_h => self.alu_bit(self.HL.r8.H, 1),
                .bit_2_h => self.alu_bit(self.HL.r8.H, 2),
                .bit_3_h => self.alu_bit(self.HL.r8.H, 3),
                .bit_4_h => self.alu_bit(self.HL.r8.H, 4),
                .bit_5_h => self.alu_bit(self.HL.r8.H, 5),
                .bit_6_h => self.alu_bit(self.HL.r8.H, 6),
                .bit_7_h => self.alu_bit(self.HL.r8.H, 7),

                .bit_0_l => self.alu_bit(self.HL.r8.L, 0),
                .bit_1_l => self.alu_bit(self.HL.r8.L, 1),
                .bit_2_l => self.alu_bit(self.HL.r8.L, 2),
                .bit_3_l => self.alu_bit(self.HL.r8.L, 3),
                .bit_4_l => self.alu_bit(self.HL.r8.L, 4),
                .bit_5_l => self.alu_bit(self.HL.r8.L, 5),
                .bit_6_l => self.alu_bit(self.HL.r8.L, 6),
                .bit_7_l => self.alu_bit(self.HL.r8.L, 7),

                .bit_0_hl => self.alu_bit(mem.read(self.HL.r16), 0),
                .bit_1_hl => self.alu_bit(mem.read(self.HL.r16), 1),
                .bit_2_hl => self.alu_bit(mem.read(self.HL.r16), 2),
                .bit_3_hl => self.alu_bit(mem.read(self.HL.r16), 3),
                .bit_4_hl => self.alu_bit(mem.read(self.HL.r16), 4),
                .bit_5_hl => self.alu_bit(mem.read(self.HL.r16), 5),
                .bit_6_hl => self.alu_bit(mem.read(self.HL.r16), 6),
                .bit_7_hl => self.alu_bit(mem.read(self.HL.r16), 7),

                .res_0_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 0),
                .res_1_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 1),
                .res_2_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 2),
                .res_3_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 3),
                .res_4_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 4),
                .res_5_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 5),
                .res_6_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 6),
                .res_7_a => self.AF.r8.A = reset_bit(self.AF.r8.A, 7),

                .res_0_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 0),
                .res_1_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 1),
                .res_2_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 2),
                .res_3_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 3),
                .res_4_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 4),
                .res_5_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 5),
                .res_6_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 6),
                .res_7_b => self.BC.r8.B = reset_bit(self.BC.r8.B, 7),

                .res_0_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 0),
                .res_1_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 1),
                .res_2_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 2),
                .res_3_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 3),
                .res_4_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 4),
                .res_5_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 5),
                .res_6_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 6),
                .res_7_c => self.BC.r8.C = reset_bit(self.BC.r8.C, 7),

                .res_0_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 0),
                .res_1_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 1),
                .res_2_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 2),
                .res_3_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 3),
                .res_4_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 4),
                .res_5_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 5),
                .res_6_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 6),
                .res_7_d => self.DE.r8.D = reset_bit(self.DE.r8.D, 7),

                .res_0_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 0),
                .res_1_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 1),
                .res_2_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 2),
                .res_3_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 3),
                .res_4_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 4),
                .res_5_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 5),
                .res_6_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 6),
                .res_7_e => self.DE.r8.E = reset_bit(self.DE.r8.E, 7),

                .res_0_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 0),
                .res_1_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 1),
                .res_2_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 2),
                .res_3_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 3),
                .res_4_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 4),
                .res_5_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 5),
                .res_6_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 6),
                .res_7_h => self.HL.r8.H = reset_bit(self.HL.r8.H, 7),

                .res_0_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 0),
                .res_1_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 1),
                .res_2_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 2),
                .res_3_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 3),
                .res_4_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 4),
                .res_5_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 5),
                .res_6_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 6),
                .res_7_l => self.HL.r8.L = reset_bit(self.HL.r8.L, 7),

                .res_0_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 0)),
                .res_1_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 1)),
                .res_2_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 2)),
                .res_3_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 3)),
                .res_4_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 4)),
                .res_5_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 5)),
                .res_6_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 6)),
                .res_7_hl => mem.write(self.HL.r16, reset_bit(mem.read(self.HL.r16), 7)),

                .set_0_a => self.AF.r8.A = set_bit(self.AF.r8.A, 0),
                .set_1_a => self.AF.r8.A = set_bit(self.AF.r8.A, 1),
                .set_2_a => self.AF.r8.A = set_bit(self.AF.r8.A, 2),
                .set_3_a => self.AF.r8.A = set_bit(self.AF.r8.A, 3),
                .set_4_a => self.AF.r8.A = set_bit(self.AF.r8.A, 4),
                .set_5_a => self.AF.r8.A = set_bit(self.AF.r8.A, 5),
                .set_6_a => self.AF.r8.A = set_bit(self.AF.r8.A, 6),
                .set_7_a => self.AF.r8.A = set_bit(self.AF.r8.A, 7),

                .set_0_b => self.BC.r8.B = set_bit(self.BC.r8.B, 0),
                .set_1_b => self.BC.r8.B = set_bit(self.BC.r8.B, 1),
                .set_2_b => self.BC.r8.B = set_bit(self.BC.r8.B, 2),
                .set_3_b => self.BC.r8.B = set_bit(self.BC.r8.B, 3),
                .set_4_b => self.BC.r8.B = set_bit(self.BC.r8.B, 4),
                .set_5_b => self.BC.r8.B = set_bit(self.BC.r8.B, 5),
                .set_6_b => self.BC.r8.B = set_bit(self.BC.r8.B, 6),
                .set_7_b => self.BC.r8.B = set_bit(self.BC.r8.B, 7),

                .set_0_c => self.BC.r8.C = set_bit(self.BC.r8.C, 0),
                .set_1_c => self.BC.r8.C = set_bit(self.BC.r8.C, 1),
                .set_2_c => self.BC.r8.C = set_bit(self.BC.r8.C, 2),
                .set_3_c => self.BC.r8.C = set_bit(self.BC.r8.C, 3),
                .set_4_c => self.BC.r8.C = set_bit(self.BC.r8.C, 4),
                .set_5_c => self.BC.r8.C = set_bit(self.BC.r8.C, 5),
                .set_6_c => self.BC.r8.C = set_bit(self.BC.r8.C, 6),
                .set_7_c => self.BC.r8.C = set_bit(self.BC.r8.C, 7),

                .set_0_d => self.DE.r8.D = set_bit(self.DE.r8.D, 0),
                .set_1_d => self.DE.r8.D = set_bit(self.DE.r8.D, 1),
                .set_2_d => self.DE.r8.D = set_bit(self.DE.r8.D, 2),
                .set_3_d => self.DE.r8.D = set_bit(self.DE.r8.D, 3),
                .set_4_d => self.DE.r8.D = set_bit(self.DE.r8.D, 4),
                .set_5_d => self.DE.r8.D = set_bit(self.DE.r8.D, 5),
                .set_6_d => self.DE.r8.D = set_bit(self.DE.r8.D, 6),
                .set_7_d => self.DE.r8.D = set_bit(self.DE.r8.D, 7),

                .set_0_e => self.DE.r8.E = set_bit(self.DE.r8.E, 0),
                .set_1_e => self.DE.r8.E = set_bit(self.DE.r8.E, 1),
                .set_2_e => self.DE.r8.E = set_bit(self.DE.r8.E, 2),
                .set_3_e => self.DE.r8.E = set_bit(self.DE.r8.E, 3),
                .set_4_e => self.DE.r8.E = set_bit(self.DE.r8.E, 4),
                .set_5_e => self.DE.r8.E = set_bit(self.DE.r8.E, 5),
                .set_6_e => self.DE.r8.E = set_bit(self.DE.r8.E, 6),
                .set_7_e => self.DE.r8.E = set_bit(self.DE.r8.E, 7),

                .set_0_h => self.HL.r8.H = set_bit(self.HL.r8.H, 0),
                .set_1_h => self.HL.r8.H = set_bit(self.HL.r8.H, 1),
                .set_2_h => self.HL.r8.H = set_bit(self.HL.r8.H, 2),
                .set_3_h => self.HL.r8.H = set_bit(self.HL.r8.H, 3),
                .set_4_h => self.HL.r8.H = set_bit(self.HL.r8.H, 4),
                .set_5_h => self.HL.r8.H = set_bit(self.HL.r8.H, 5),
                .set_6_h => self.HL.r8.H = set_bit(self.HL.r8.H, 6),
                .set_7_h => self.HL.r8.H = set_bit(self.HL.r8.H, 7),

                .set_0_l => self.HL.r8.L = set_bit(self.HL.r8.L, 0),
                .set_1_l => self.HL.r8.L = set_bit(self.HL.r8.L, 1),
                .set_2_l => self.HL.r8.L = set_bit(self.HL.r8.L, 2),
                .set_3_l => self.HL.r8.L = set_bit(self.HL.r8.L, 3),
                .set_4_l => self.HL.r8.L = set_bit(self.HL.r8.L, 4),
                .set_5_l => self.HL.r8.L = set_bit(self.HL.r8.L, 5),
                .set_6_l => self.HL.r8.L = set_bit(self.HL.r8.L, 6),
                .set_7_l => self.HL.r8.L = set_bit(self.HL.r8.L, 7),

                .set_0_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 0)),
                .set_1_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 1)),
                .set_2_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 2)),
                .set_3_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 3)),
                .set_4_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 4)),
                .set_5_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 5)),
                .set_6_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 6)),
                .set_7_hl => mem.write(self.HL.r16, set_bit(mem.read(self.HL.r16), 7)),
            }
        },

        .stop => self.halted = true, // TODO this is slightly different
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
