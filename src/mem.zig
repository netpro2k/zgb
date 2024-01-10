const std = @import("std");

pub const Irq = packed struct {
    vblank: bool,
    lcd_stat: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    _pad: u3 = 0,
};

pub const SerialControl = packed struct {
    clock_select: u1,
    cgb_clock_speed: u1,
    _pad: u5,
    transfer_en: bool,
};

pub const LCDControl = packed struct {
    bg_en: bool,
    obj_en: bool,
    bg_tilemap: bool,
    bg_tiles: bool,
    win_en: bool,
    win_tilemap: bool,
    lcd_en: bool,
    _pad: u1 = 0,
};

pub const LCDStatus = packed struct {
    mode: u2,
    ly_coincidence: bool,
    interupt_sel: packed struct {
        mode_0: bool, // HBlank
        mode_1: bool, // VBlank
        mode_2: bool, // OAM scan
        ly_coincidence: bool,
    },
    _pad: u1 = 0,
};

const LCD = struct {
    LCDC: LCDControl,
    STAT: LCDStatus,
    SCY: u8,
    SCX: u8,
    WX: u8,
    WY: u8,
    LY: u8,
    LYC: u8,
};

const Color = enum { white, light, dark, black };
const Pallete = packed struct {
    c0: Color,
    c1: Color,
    c2: Color,
    c3: Color,
};

const SpriteFlags = packed struct {
    cgb_pallete: u3,
    bank: u1,
    dmg_pallete: u1,
    x_flip: bool,
    y_flip: bool,
    priority: u1,
};

const Sprite = packed struct {
    y: u8,
    x: u8,
    tile: u8,
    flags: SpriteFlags,
};

const Mem = @This();

rom: [0x7FFF + 1]u8,
work_ram: [0xDFFF - 0xC000 + 1]u8,
high_ram: [0xFFFE - 0xFF80 + 1]u8,
vram: [0x9FFF - 0x8000 + 1]u8,
oam: [40]Sprite,

todo_audio: [0xFF26 - 0xFF10 + 1]u8,

IF: Irq,
IE: Irq,

BGP: Pallete,
OBP0: Pallete,
OBP1: Pallete,

SB: u8,
SC: SerialControl,

TIMA: u8,
TMA: u8,
TAC: u8,

JOYP: u8,

lcd: LCD,

DIV: u8,

var first_read = false;

pub fn read(self: Mem, addr: u16) u8 {
    switch (addr) {
        0x0000...0x7FFF => { // ROM
            return self.rom[addr];
        },
        0x8000...0x9FFF => { // VRAM
            return self.vram[addr - 0x8000];
        },

        0xC000...0xDFFF => { // Work RAM
            return self.work_ram[addr - 0xC000];
        },
        0xE000...0xFDFF => { // Echo Work RAM
            return self.work_ram[addr - 0xE000];
        },

        0xFE00...0xFE9F => return @as([40 * 4]u8, @bitCast(self.oam))[addr - 0xFE00],

        0xFEA0...0xFEFF => return 0, // Intentionally unused

        0xFF00 => return 0xFF, // TODO self.JOYP,
        0xFF01 => return self.SB,
        0xFF02 => return @bitCast(self.SC),
        0xFF03 => return 0xFF, // unmapped
        0xFF04 => return self.DIV,
        0xFF05 => return self.TIMA,
        0xFF06 => return self.TMA,
        0xFF07 => return self.TAC,
        0xFF08...0xFF0E => return 0xFF, // unmapped
        0xFF0F => return @bitCast(self.IF),

        0xFF10...0xFF26 => return self.todo_audio[addr - 0xFF10],

        0xFF27...0xFF2F => return 0xFF, // unmapped

        0xFF40 => return @bitCast(self.lcd.LCDC),
        0xFF41 => return @bitCast(self.lcd.STAT),
        0xFF42 => return self.lcd.SCY,
        0xFF43 => return self.lcd.SCX,
        0xFF44 => return self.lcd.LY,
        0xFF45 => return self.lcd.LYC,

        0xFF47 => return @bitCast(self.BGP),
        0xFF48 => return @bitCast(self.OBP0),
        0xFF49 => return @bitCast(self.OBP1),

        0xFF4A => return self.lcd.WY,
        0xFF4B => return self.lcd.WX,

        0xFF80...0xFFFE => { // High RAM
            // if (addr == 0xFF85) return 1; // TODO
            return self.high_ram[addr - 0xFF80];
        },

        0xFFFF => {
            return @bitCast(self.IE);
        },
        else => {
            std.debug.print("Unimplemented memory read {X:0>4}\n", .{addr});
            return 0xFF;
        },
    }
}

pub fn read_ff(self: Mem, addr_nib: u8) u8 {
    return self.read(0xff00 + @as(u16, addr_nib));
}

pub fn write(self: *Mem, addr: u16, value: u8) void {
    switch (addr) {
        0x0000...0x7FFF => {
            self.rom[addr] = value;
        },
        0xC000...0xDFFF => { // Work RAM
            self.work_ram[addr - 0xC000] = value;
        },
        0x8000...0x9FFF => { // VRAM
            // std.debug.print("Write VRAM {X:0>4} = {X}", .{ addr, value });
            self.vram[addr - 0x8000] = value;
        },

        0xE000...0xFDFF => { // Echo Work RAM
            self.work_ram[addr - 0xE000] = value;
        },

        0xFE00...0xFE9F => @as([*]u8, @ptrCast(&self.oam))[addr - 0xFE00] = value,

        0xFEA0...0xFEFF => {}, // Intentionally unused

        0xFF10...0xFF26 => self.todo_audio[addr - 0xFF10] = value,

        0xFF00 => self.JOYP = value,
        0xFF01 => self.SB = value,
        0xFF02 => self.SC = @bitCast(value),
        0xFF03 => {}, // unmapped
        0xFF04 => self.DIV = 0,
        0xFF05 => self.TIMA = value,
        0xFF06 => self.TMA = value,
        0xFF07 => self.TAC = value,
        0xFF08...0xFF0E => {}, // unmapped
        0xFF0F => self.IF = @bitCast(value),

        0xFF27...0xFF2F => {}, // unmapped
        0xFF30...0xFF3F => {}, // TODO wave pattern

        0xFF40 => self.lcd.LCDC = @bitCast(value),
        0xFF41 => self.lcd.STAT = @bitCast(value),
        0xFF42 => self.lcd.SCY = value,
        0xFF43 => self.lcd.SCX = value,

        0xFF44 => {}, // LY, readonly
        0xFF45 => self.lcd.LYC = value,

        0xFF4A => self.lcd.WY = value,
        0xFF4B => self.lcd.WX = value,

        // If value $XY is written, the transfer will copy $XY00-$XY9F to $FE00-$FE9F.
        0xFF46 => {
            // TODO this needs to handle reading from anyway, also its not suposed to just happen instantly
            const start: u16 = (@as(u16, value) << 8);
            // std.debug.print("Starting DMA {X}-{X}\n", .{ start, start + 0x9F });
            for (0..0x9F + 1) |i| {
                const iu = @as(u16, @intCast(i));
                self.write(0xFE00 + iu, self.read(start + iu));
            }
        },

        0xFF47 => self.BGP = @bitCast(value),
        0xFF48 => self.OBP0 = @bitCast(value),
        0xFF49 => self.OBP1 = @bitCast(value),

        0xFF7F => {}, // Apparently unused and written as a "bug" in tetris?

        0xFF80...0xFFFE => { // High RAM
            self.high_ram[addr - 0xFF80] = value;
        },

        0xFFFF => {
            self.IE = @bitCast(value);
        },

        else => {
            std.debug.print("Unimplemented memory write {X:0>4}\n", .{addr});
        },
    }
}

pub fn write_ff(self: *Mem, addr_nib: u8, value: u8) void {
    self.write(0xff00 + @as(u16, addr_nib), value);
}

var debug_output: [1024]u8 = undefined;
var debug_idx: usize = 0;

pub fn tick(self: *Mem, clocks: usize) void {
    for (0..clocks) |_| {
        if (self.SC.transfer_en) {
            self.SC.transfer_en = false;
            debug_output[debug_idx] = self.SB;
            self.SB = 0xFF;
            debug_idx += 1;
            std.debug.print("SERIAL: '{s}'\n", .{debug_output});
        }
    }
}
