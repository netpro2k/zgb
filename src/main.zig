const std = @import("std");
const CPU = @import("cpu.zig");
const Mem = @import("mem.zig");

pub fn main() !void {
    var cpu = CPU.init();

    const allocator = std.heap.page_allocator;

    var file = try std.fs.cwd().openFile("./roms/Tetris.gb", .{});
    defer file.close();

    var mem: Mem = undefined;

    const rom = try file.readToEndAlloc(allocator, 1024 * 32);
    std.mem.copy(u8, &mem.rom, rom);

    mem.lcd.LY = 0x94; // TODO tetris waits on this, hardcode for now to get through to more interesting stuff

    std.debug.print("Read {d} bytes\n", .{rom.len});

    const stdin = std.io.getStdIn().reader();

    var buffer: [1]u8 = undefined;
    _ = buffer;

    var step = false;

    while (true) {
        cpu.tick(&mem);

        // TODO tetris waits on this, hardcode for now to get through to more interesting stuff
        if (cpu.PC == 0x282C) {
            mem.lcd.LY = 0x91;
        }
        if (cpu.PC == 0x0233) {
            mem.lcd.LY = 0x94;
        }

        // if (cpu.PC == 0x02ED) {
        //     step = true;
        // }

        if (step) {
            const k = try stdin.readByte();
            if (k == 'c') step = false;
        }

        if (cpu.PC == 0x02ED) {
            // _ = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
            // std.debug.print("vram {any}\n\n", .{mem.});
            for (0..128) |t| {
                std.debug.print("tile {x}: ", .{t});
                for (0..16) |i| {
                    std.debug.print("{X:0>2} ", .{mem.read(@intCast(0x8000 + (t * 16) + i))});
                }
                std.debug.print("\n", .{});
            }

            for (0..32) |y| {
                for (0..32) |x| {
                    std.debug.print("{X:0>2} ", .{mem.read(@intCast(0x9800 + (y * 32) + x))});
                }
                std.debug.print("\n", .{});
            }

            return;
        }
    }
}
