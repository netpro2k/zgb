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

    while (true) {
        cpu.tick(&mem);
        if (true and (cpu.PC == 0x282C)) {
            _ = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
            // mem.lcd.LY = 0x91; // TODO tetris waits on this, hardcode for now to get through to more interesting stuff
        }
    }
}
