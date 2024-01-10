const std = @import("std");
const CPU = @import("cpu.zig");
const Mem = @import("mem.zig");

const r = @cImport(@cInclude("raylib.h"));

pub fn main() !void {
    r.InitWindow(960, 960, "ZGB");
    r.SetTargetFPS(60);
    defer r.CloseWindow();

    var cpu = CPU.init();

    const allocator = std.heap.page_allocator;
    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    var mem: Mem = undefined;

    const rom = try file.readToEndAlloc(allocator, 1024 * 32);
    std.mem.copy(u8, &mem.rom, rom);

    mem.lcd.LY = 0x94; // TODO tetris waits on this, hardcode for now to get through to more interesting stuff

    std.debug.print("Read {d} bytes\n", .{rom.len});

    const stdin = std.io.getStdIn().reader();
    _ = stdin;

    const SCREEN_WIDTH = 160;
    const SCREEN_HEIGHT = 144;

    var step = false;

    var fb_img = r.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, r.WHITE);
    defer r.UnloadImage(fb_img);
    var fb_tex = r.LoadTextureFromImage(fb_img);
    defer r.UnloadTexture(fb_tex);

    var tile_debug_img = r.GenImageColor(16 * 9, 24 * 9, r.BEIGE);
    defer r.UnloadImage(tile_debug_img);
    var tile_debug_tex = r.LoadTextureFromImage(tile_debug_img);
    defer r.UnloadTexture(tile_debug_tex);

    var bg_debug_img = r.GenImageColor(32 * 8, 32 * 8, r.BEIGE);
    defer r.UnloadImage(bg_debug_img);
    var bg_debug_tex = r.LoadTextureFromImage(bg_debug_img);
    defer r.UnloadTexture(bg_debug_tex);

    const cur_pallete: [4]r.Color = .{ r.WHITE, r.GRAY, r.DARKGRAY, r.BLACK };

    var debug_map_sel = false;

    var prev_time: i64 = std.time.milliTimestamp();
    var tick: usize = 0;
    _ = tick;

    while (!r.WindowShouldClose()) {
        const now = std.time.milliTimestamp();
        const dt = now - prev_time;
        prev_time = now;

        if (r.IsKeyPressed(r.KEY_S)) step = !step;

        if (r.IsKeyPressed(r.KEY_V)) mem.IF.vblank = true;

        if (r.IsKeyPressed(r.KEY_M)) debug_map_sel = !debug_map_sel;

        mem.IF.vblank = true;

        if (!step or r.IsKeyPressed(r.KEY_N)) {
            cpu.tick(&mem, dt);
        }

        if (cpu.IME) {
            if (mem.IF.vblank and mem.IE.vblank) {
                cpu.IME = false;
                cpu.halted = false;
                // std.debug.print("VBLANK\n", .{});
                mem.IF.vblank = false;
                cpu.call(&mem, 0x40);
            }
        }

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

        if (cpu.PC == 0x02ED) {
            // return;
        }

        const tile_debug_pixels = @as([*]r.Color, @ptrCast(tile_debug_img.data.?));
        for (0..384) |t| {
            const offset = 0x8000 + (t * 16);
            for (0..8) |line| {
                const high = mem.read(@intCast(offset + line * 2));
                const low = mem.read(@intCast(offset + line * 2 + 1));
                for (0..8) |px| {
                    const c = bit(low, 7 - px) | bit(high, 7 - px) << 1;
                    const x = ((t % 16) * 9 + px);
                    const y = ((t / 16) * 9 + line);
                    tile_debug_pixels[y * @as(usize, @intCast(tile_debug_img.width)) + x] = cur_pallete[c];
                }
            }
        }
        r.UpdateTexture(tile_debug_tex, tile_debug_img.data);

        const bg_debug_pixels = @as([*]r.Color, @ptrCast(bg_debug_img.data.?));
        for (0..32) |ty| {
            for (0..32) |tx| {
                const start_offset: u16 = if (debug_map_sel) 0x09C00 else 0x9800;
                const t = mem.read(@intCast(start_offset + (ty * 32) + tx));

                var offset: u16 = 0;
                // if (mem.lcd.LCDC.bg_tiles) {
                offset = 0x8000 + (@as(u16, @intCast(t)) * 16);
                // } else {
                //     const rt: i8 = @as(i8, @bitCast(t));
                //     offset = @as(u16, @intCast(0x9000 + @as(i32, rt) * 16));
                // }

                for (0..8) |line| {
                    const high = mem.read(@intCast(offset + line * 2));
                    const low = mem.read(@intCast(offset + line * 2 + 1));
                    for (0..8) |px| {
                        const c = bit(low, 7 - px) | bit(high, 7 - px) << 1;
                        const x = (tx * 8 + px);
                        const y = (ty * 8 + line);
                        bg_debug_pixels[y * @as(usize, @intCast(bg_debug_img.width)) + x] = cur_pallete[c];
                    }
                }
            }
        }
        r.UpdateTexture(bg_debug_tex, bg_debug_img.data);

        r.BeginDrawing();
        r.ClearBackground(r.BEIGE);

        r.DrawText("Screen", 100, 37, 12, r.BLACK);
        r.DrawTextureEx(fb_tex, .{ .x = 101, .y = 51 }, 0, 2, r.WHITE);
        r.DrawRectangleLines(100, 50, fb_img.width * 2 + 2, fb_img.height * 2 + 2, r.BLACK);

        r.DrawText("Tiles", 550, 7, 12, r.BLACK);
        r.DrawTextureEx(tile_debug_tex, .{ .x = 551, .y = 21 }, 0, 2, r.WHITE);
        r.DrawRectangleLines(550, 20, tile_debug_img.width * 2 + 2, tile_debug_img.height * 2 + 2, r.BLACK);
        // r.DrawTextureRec(tile_debug_tex, .{ .x = 0, .y = 0, .width = @bitCast(tile_debug_tex.width), .height = @bitCast(-tile_debug_tex.height) }, .{ .x = 0, .y = 0 }, r.WHITE);

        r.DrawText("Map", 10, 387, 12, r.BLACK);
        r.DrawTextureEx(bg_debug_tex, .{ .x = 11, .y = 401 }, 0, 2, r.WHITE);
        r.DrawRectangleLines(11 + @as(c_int, @intCast(mem.lcd.SCX)), 401 + @as(c_int, @intCast(mem.lcd.SCY)), SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2, r.LIGHTGRAY);
        r.DrawRectangleLines(10, 400, bg_debug_img.width * 2 + 2, bg_debug_img.height * 2 + 2, r.BLACK);
        //
        if (r.IsKeyDown(r.KEY_D)) cpu.debug = !cpu.debug;

        r.EndDrawing();
    }
}

fn bit(n: anytype, b: anytype) u8 {
    return ((n >> @intCast(b)) & 1);
}
