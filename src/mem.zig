const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const Interupt = @import("cpu.zig").Interupt;

const r = @cImport(@cInclude("raylib.h"));

pub const JoypadState = packed struct {
    right: bool,
    left: bool,
    up: bool,
    down: bool,
    a: bool,
    b: bool,
    select: bool,
    start: bool,
};

pub const JoypadControl = packed struct {
    a_right: bool,
    b_left: bool,
    select_up: bool,
    start_down: bool,
    sel_dpad: bool,
    sel_buttons: bool,
    _pad: u2,
};

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

pub const TimerControl = packed struct {
    clock_select: u2,
    enable: bool,
    _pad: u5,
};

pub const LCDMode = enum(u2) {
    hblank,
    vblank,
    oam_scan,
    drawing,
};

const TileAddressMode = enum(u1) {
    signed = 0,
    unsigned,

    pub fn get_addr(self: TileAddressMode, tile: u8) u16 {
        if (self == .signed) {
            const rt: i8 = @as(i8, @bitCast(tile));
            return @intCast(0x9000 + @as(i32, rt) * 16);
        } else {
            return 0x8000 + (@as(u16, @intCast(tile)) * 16);
        }
    }
};

pub const LCDControl = packed struct {
    bg_en: bool,
    obj_en: bool,
    obj_size: enum(u1) {
        Small = 0,
        Large = 1,
    },
    bg_tilemap: u1,
    bg_win_tiles: TileAddressMode,
    win_en: bool,
    win_tilemap: u1,
    lcd_en: bool,
};

pub const LCDStatus = packed struct {
    mode: LCDMode,
    ly_coincidence: bool,
    interupt_sel: packed struct {
        hblank: bool,
        vblank: bool,
        oam_scan: bool,
        lyc: bool,
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

    cur_dots: u16 = 0,
    active_sprites: [10]?Sprite,

    fb: []r.Color,
    fb_dirty: bool,

    debug_last_bg_win_tiles: TileAddressMode,
};

const Color = enum { white, light, dark, black };
const Pallete = packed struct {
    c0: Color,
    c1: Color,
    c2: Color,
    c3: Color,

    pub fn get_rgba(self: Pallete, color: u2) r.Color {
        const colors: [4]r.Color = .{ r.GetColor(0xE8E8E8FF), r.GetColor(0xA0A0A0FF), r.GetColor(0x585858ff), r.GetColor(0x101010ff) };

        return colors[
            (@as(u8, @bitCast(self)) >> (@as(u3, color) * 2)) & 0b11
        ];
    }
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

rom: []u8,
bank_0: []u8,
bank_n: []u8,
bank: u7,

work_ram: [0x2000]u8,
high_ram: [0x7F]u8,
vram: [0x2000]u8,
external_ram: [0x2000]u8,
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
TAC: TimerControl,
prev_result: bool,

JOYP: JoypadControl,

lcd: LCD,

DIV: u16,

pending_cycles: u32,
joypad_state: JoypadState,

var first_read = false;

pub fn init() Mem {
    var mem = Mem{
        .rom = undefined,
        .bank_0 = undefined,
        .bank_n = undefined,
        .bank = 1,
        .work_ram = undefined,
        .high_ram = undefined,
        .vram = undefined,
        .external_ram = undefined,
        .oam = undefined,
        .todo_audio = undefined,
        .IF = @bitCast(@as(u8, 0)),
        .IE = undefined,
        .BGP = undefined,
        .OBP0 = undefined,
        .OBP1 = undefined,
        .SB = undefined,
        .SC = undefined,
        .TIMA = 0,
        .TMA = 0,
        .TAC = undefined,
        .prev_result = false,
        .JOYP = @bitCast(@as(u8, 0x3F)),
        .lcd = undefined,
        .DIV = 0,
        .pending_cycles = 0,
        .joypad_state = @bitCast(@as(u8, 0x00)),
    };

    mem.lcd.LCDC = @bitCast(@as(u8, 0x91));
    return mem;
}

pub fn load_rom(self: *Mem, rom: []u8) void {
    self.rom = rom;
    self.bank_0 = self.rom[0x0000..0x4000];
    self.set_bank(0);
}

pub fn set_bank(self: *Mem, new_bank: u7) void {
    self.bank = new_bank;
    if (self.bank == 0) self.bank = 1;
    const start: usize = 0x4000 * @as(usize, self.bank);
    // std.debug.print("Setting bank to {d} {X:0>4}..{X:0>4}\n", .{ new_bank, start, start + 0x4000 });
    self.bank_n = self.rom[start .. start + 0x4000];
}

pub fn read(self: *Mem, addr: u16) u8 {
    self.pending_cycles += 1;
    return self.read_silent(addr);
}

pub fn read_silent(self: *Mem, addr: u16) u8 {
    switch (addr) {
        0x0000...0x3FFF => { // Bank 0
            return self.bank_0[addr];
        },
        0x4000...0x7FFF => { // Bank N
            return self.bank_n[addr - 0x4000];
        },
        0x8000...0x9FFF => { // VRAM
            return self.vram[addr - 0x8000];
        },
        0xA000...0xBFFF => {
            return self.external_ram[addr - 0xA000];
        },
        0xC000...0xDFFF => { // Work RAM
            return self.work_ram[addr - 0xC000];
        },
        0xE000...0xFDFF => { // Echo Work RAM
            return self.work_ram[addr - 0xE000];
        },

        0xFE00...0xFE9F => return @as([40 * 4]u8, @bitCast(self.oam))[addr - 0xFE00],

        0xFEA0...0xFEFF => return 0, // Intentionally unused

        0xFF00 => return @bitCast(self.JOYP),
        0xFF01 => return self.SB,
        0xFF02 => return @bitCast(self.SC),
        0xFF03 => return 0xFF, // unmapped
        0xFF04 => return @truncate(self.DIV >> 8),
        0xFF05 => return self.TIMA,
        0xFF06 => return self.TMA,
        0xFF07 => return @bitCast(self.TAC),
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
            // std.debug.print("Unimplemented memory read {X:0>4}\n", .{addr});
            return 0xFF;
        },
    }
}

pub fn read_ff(self: *Mem, addr_nib: u8) u8 {
    return self.read(0xff00 + @as(u16, addr_nib));
}

pub fn write(self: *Mem, addr: u16, value: u8) void {
    self.pending_cycles += 1;

    switch (addr) {
        0x2000...0x3FFF => {
            self.set_bank(@truncate(value));
        },
        0xC000...0xDFFF => { // Work RAM
            self.work_ram[addr - 0xC000] = value;
        },
        0x8000...0x9FFF => { // VRAM
            // std.debug.print("Write VRAM {X:0>4} = {X}", .{ addr, value });
            self.vram[addr - 0x8000] = value;
        },

        0xA000...0xBFFF => {
            self.external_ram[addr - 0xA000] = value;
        },

        0xE000...0xFDFF => { // Echo Work RAM
            self.work_ram[addr - 0xE000] = value;
        },

        0xFE00...0xFE9F => @as([*]u8, @ptrCast(&self.oam))[addr - 0xFE00] = value,

        0xFEA0...0xFEFF => {}, // Intentionally unused

        0xFF10...0xFF26 => self.todo_audio[addr - 0xFF10] = value,

        0xFF00 => {
            const new: JoypadControl = @bitCast(value);
            self.JOYP.sel_buttons = new.sel_buttons;
            self.JOYP.sel_dpad = new.sel_dpad;
        },
        0xFF01 => self.SB = value,
        0xFF02 => self.SC = @bitCast(value),
        0xFF03 => {}, // unmapped
        0xFF04 => self.DIV = 0,
        0xFF05 => {
            self.TIMA = value;
            // std.debug.print("WRITE TIMA {x}\n", .{self.TIMA});
        },
        0xFF06 => self.TMA = value,
        0xFF07 => {
            self.TAC = @bitCast(value);
            std.debug.print("WRITE TAC {x} {any}\n", .{ value, self.TAC });
        },
        0xFF08...0xFF0E => {}, // unmapped
        0xFF0F => {
            self.IF = @bitCast(value);
            std.debug.print("WRITE IF {x} {any}\n", .{ value, self.IF });
        },

        0xFF27...0xFF2F => {}, // unmapped
        0xFF30...0xFF3F => {}, // TODO wave pattern

        0xFF40 => {
            self.lcd.LCDC = @bitCast(value);
            std.debug.print("WRITE LCDC {x} {any}\n", .{ value, self.lcd.LCDC });
        },
        0xFF41 => self.lcd.STAT = @bitCast((@as(u8, @bitCast(self.lcd.STAT)) & 0b11) | (value & 0b11111100)),
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
            const prev_pending = self.pending_cycles;
            for (0..0x9F + 1) |i| {
                const iu = @as(u16, @intCast(i));
                self.write(0xFE00 + iu, self.read(start + iu));
            }
            self.pending_cycles = prev_pending;
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
            std.debug.print("WRITE IE {x} {any}\n", .{ value, self.IE });
        },

        else => {
            // std.debug.print("Unimplemented memory write {X:0>4}\n", .{addr});
        },
    }
}

pub fn write_ff(self: *Mem, addr_nib: u8, value: u8) void {
    self.write(0xff00 + @as(u16, addr_nib), value);
}

var debug_output: [1024]u8 = undefined;
var debug_idx: usize = 0;

fn step_timer(self: *Mem, cpu: *CPU) void {
    self.DIV +%= 1;

    const bit: u4 = switch (self.TAC.clock_select) {
        0b00 => 9,
        0b01 => 3,
        0b10 => 5,
        0b11 => 7,
    };

    const result = ((self.DIV >> bit) & 1) & @intFromBool(self.TAC.enable) != 0;

    // std.debug.print("DIV {b} bit {d} res: {any} TACe {any} \n", .{ self.DIV, bit, result, self.TAC.enable });
    if (self.prev_result and !result) { // falling edge
        self.TIMA +%= 1;
        if (cpu.debug) std.debug.print("TIMA {X}\n", .{self.TIMA});
        if (self.TIMA == 0x00) {
            self.TIMA = self.TMA;
            self.IF.timer = true;
        }
    }
    self.prev_result = result;
}

fn get_bit(n: anytype, b: anytype) u1 {
    return @as(u1, @intCast((n >> @intCast(b)) & 1));
}

const SCREEN_WIDTH: usize = 160;
const SCREEN_HEIGHT: usize = 144;

pub fn get_tile_color(self: *Mem, addr_mode: TileAddressMode, tile: u8, tile_x: usize, tile_y: usize) u2 {
    const offset = addr_mode.get_addr(tile);
    const high = self.read_silent(@intCast(offset + tile_y * 2 + 1));
    const low = self.read_silent(@intCast(offset + tile_y * 2));
    return get_bit(low, 7 - tile_x) | @as(u2, get_bit(high, 7 - tile_x)) << 1;
}

fn step_ppu(self: *Mem) void {
    if (!self.lcd.LCDC.lcd_en) return;

    const start_mode = self.lcd.STAT.mode;
    switch (self.lcd.STAT.mode) {
        .oam_scan => {
            if (self.lcd.cur_dots == 0) {
                for (0..10) |i| {
                    self.lcd.active_sprites[i] = null;
                }
                var i: usize = 0;
                for (self.oam) |sprite| {
                    // Sprite X-Position must be greater than 0
                    // LY + 16 must be greater than or equal to Sprite Y-Position
                    // LY + 16 must be less than Sprite Y-Position + Sprite Height (8 in Normal Mode, 16 in Tall-Sprite-Mode)
                    // The amount of sprites already stored in the OAM Buffer must be less than 10
                    const sprite_height: u8 = if (self.lcd.LCDC.obj_size == .Large) 16 else 8;
                    if (sprite.x > 0 and
                        self.lcd.LY + 16 >= sprite.y and
                        self.lcd.LY + 16 < sprite.y + sprite_height)
                    {
                        self.lcd.active_sprites[i] = sprite;
                        i += 1;
                        if (i == 10) break;
                    }
                }
            }

            self.lcd.cur_dots += 1;
            if (self.lcd.cur_dots == 81) {
                self.lcd.STAT.mode = .drawing;
            }
        },

        // TODO this is completely wrong, implement pixel FIFO
        .drawing => {
            if (self.lcd.cur_dots > 80 + 12) {
                const screen_x: usize = self.lcd.cur_dots - (80 + 12 + 1);
                const screen_y: usize = self.lcd.LY;

                var bg_c: u2 = 0;
                if (self.lcd.LCDC.bg_en) {
                    const start_offset: u16 = if (self.lcd.LCDC.bg_tilemap == 1) 0x09C00 else 0x9800;
                    const map_x: usize = (screen_x + self.lcd.SCX) % 256;
                    const map_y: usize = (screen_y + self.lcd.SCY) % 256;

                    const tile = self.read_silent(@intCast(start_offset + ((map_y / 8) * 32) + (map_x / 8)));
                    bg_c = self.get_tile_color(self.lcd.LCDC.bg_win_tiles, tile, map_x % 8, map_y % 8);
                    self.lcd.fb[screen_y * SCREEN_WIDTH + screen_x] = self.BGP.get_rgba(bg_c);
                }

                if (self.lcd.LCDC.obj_en) {
                    var lowest_x: u8 = 255;
                    for (self.lcd.active_sprites) |maybe_sprite| {
                        if (maybe_sprite) |sprite| {
                            if (screen_x + 8 >= sprite.x and screen_x < sprite.x and sprite.x < lowest_x) {
                                if (sprite.flags.priority == 1 and bg_c != 0) break;

                                const sprite_height: u8 = if (self.lcd.LCDC.obj_size == .Large) 16 else 8;
                                var tile_x = 8 - (sprite.x - screen_x);
                                var tile_y = 16 - (sprite.y - screen_y);

                                if (sprite.flags.x_flip) tile_x = 7 - tile_x;
                                if (sprite.flags.y_flip) tile_y = sprite_height - 1 - tile_y;

                                lowest_x = sprite.x;

                                const pallete = if (sprite.flags.dmg_pallete == 0) self.OBP0 else self.OBP1;
                                const c = self.get_tile_color(TileAddressMode.unsigned, sprite.tile, tile_x, tile_y);
                                if (c != 0) self.lcd.fb[screen_y * SCREEN_WIDTH + screen_x] = pallete.get_rgba(c);
                            }
                        }
                    }
                }

                if (self.lcd.LCDC.win_en and screen_y >= self.lcd.WY and screen_x + 8 > self.lcd.WX) {
                    const start_offset: u16 = if (self.lcd.LCDC.win_tilemap == 1) 0x09C00 else 0x9800;
                    const map_x: usize = screen_x + 7 - self.lcd.WX;
                    const map_y: usize = screen_y - self.lcd.WY;

                    const tile = self.read_silent(@intCast(start_offset + ((map_y / 8) * 32) + (map_x / 8)));
                    const c = self.get_tile_color(self.lcd.LCDC.bg_win_tiles, tile, map_x % 8, map_y % 8);
                    self.lcd.fb[screen_y * SCREEN_WIDTH + screen_x] = self.BGP.get_rgba(c);
                }

                self.lcd.debug_last_bg_win_tiles = self.lcd.LCDC.bg_win_tiles;
            }

            self.lcd.cur_dots += 1;
            if (self.lcd.cur_dots == 80 + SCREEN_WIDTH + 12 + 1) {
                self.lcd.STAT.mode = .hblank;
            }
        },
        .hblank => {
            self.lcd.cur_dots += 1;
            if (self.lcd.cur_dots == 457) {
                self.lcd.cur_dots = 0;
                self.lcd.LY += 1;
                if (self.lcd.LY == SCREEN_HEIGHT) {
                    self.lcd.STAT.mode = .vblank;
                } else {
                    self.lcd.STAT.mode = .oam_scan;
                }
            }
        },
        .vblank => {
            if (self.lcd.LY == SCREEN_HEIGHT) self.lcd.fb_dirty = true;
            self.lcd.cur_dots += 1;
            if (self.lcd.cur_dots == 457) {
                self.lcd.cur_dots = 0;
                self.lcd.LY += 1;
                if (self.lcd.LY == 154) {
                    self.lcd.STAT.mode = .oam_scan;
                    self.lcd.LY = 0;
                    self.IF.vblank = true;
                }
            }
        },
    }

    self.lcd.STAT.ly_coincidence = self.lcd.LY == self.lcd.LYC;

    const mode_trigger = switch (self.lcd.STAT.mode) {
        .oam_scan => self.lcd.STAT.interupt_sel.oam_scan,
        .drawing => false,
        .hblank => self.lcd.STAT.interupt_sel.hblank,
        .vblank => self.lcd.STAT.interupt_sel.vblank,
    } and self.lcd.STAT.mode != start_mode;
    const lyc_trigger = self.lcd.STAT.interupt_sel.lyc and self.lcd.STAT.ly_coincidence;

    if (mode_trigger or lyc_trigger) {
        self.IF.lcd_stat = true;
    }
}

fn step(self: *Mem, cpu: *CPU) void {
    if (self.SC.transfer_en) {
        self.SC.transfer_en = false;
        debug_output[debug_idx] = self.SB;
        self.SB = 0xFF;
        debug_idx = (debug_idx + 1) % 1024;
        // std.debug.print("SERIAL: '{s}'\n", .{debug_output});
    }

    self.step_timer(cpu);
    self.step_ppu();

    // TODO this can be directly bit coppied
    if (!self.JOYP.sel_buttons) {
        // if (self.JOYP.start_down and self.joypad_state.start) {
        //     self.IF.joypad = true;
        //     std.debug.print("START\n", .{});
        // }
        self.JOYP.a_right = !self.joypad_state.a;
        self.JOYP.b_left = !self.joypad_state.b;
        self.JOYP.select_up = !self.joypad_state.select;
        self.JOYP.start_down = !self.joypad_state.start;
    } else if (!self.JOYP.sel_dpad) {
        self.JOYP.a_right = !self.joypad_state.right;
        self.JOYP.b_left = !self.joypad_state.left;
        self.JOYP.select_up = !self.joypad_state.up;
        self.JOYP.start_down = !self.joypad_state.down;
    } else {
        self.JOYP.a_right = true;
        self.JOYP.b_left = true;
        self.JOYP.select_up = true;
        self.JOYP.start_down = true;
    }
}

pub fn tick(self: *Mem, cpu: *CPU) void {
    // std.debug.print("Pending: {d}\n", .{self.pending_cycles});
    while (self.pending_cycles > 0) {
        for (0..4) |_| {
            self.step(cpu);
        }
        self.pending_cycles -= 1;
    }
}
