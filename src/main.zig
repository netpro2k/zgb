const std = @import("std");
const CPU = @import("cpu.zig");
const Mem = @import("mem.zig");

const r = @cImport(@cInclude("raylib.h"));

fn cpu_thread(cpu: *CPU, mem: *Mem) !void {
    var prev_time: i64 = std.time.milliTimestamp();

    while (true) {
        const now = std.time.milliTimestamp();
        const dt = now - prev_time;
        prev_time = now;

        cpu.tick(mem, dt);
        std.time.sleep(1000);
    }
}

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

    const rom = try file.readToEndAlloc(allocator, 1024 * 1024);

    var mem: Mem = Mem.init();
    mem.load_rom(rom);

    std.debug.print("Read {d} bytes\n", .{rom.len});

    const stdin = std.io.getStdIn().reader();
    _ = stdin;

    _ = try std.Thread.spawn(.{}, cpu_thread, .{ &cpu, &mem });

    const SCREEN_WIDTH = 160;
    const SCREEN_HEIGHT = 144;

    var step = false;

    var fb_img = r.GenImageColor(SCREEN_WIDTH, SCREEN_HEIGHT, r.WHITE);
    defer r.UnloadImage(fb_img);
    var fb_tex = r.LoadTextureFromImage(fb_img);
    defer r.UnloadTexture(fb_tex);
    mem.lcd.fb = @as([*]r.Color, @ptrCast(fb_img.data.?))[0 .. SCREEN_WIDTH * SCREEN_HEIGHT];

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
        _ = dt;
        prev_time = now;

        if (r.IsKeyPressed(r.KEY_S)) step = !step;

        if (r.IsKeyPressed(r.KEY_M)) debug_map_sel = !debug_map_sel;

        if (!step or r.IsKeyPressed(r.KEY_N)) {}

        mem.joypad_state.start = r.IsKeyDown(r.KEY_ENTER);
        mem.joypad_state.select = r.IsKeyDown(r.KEY_LEFT_SHIFT);
        mem.joypad_state.a = r.IsKeyDown(r.KEY_Z);
        mem.joypad_state.b = r.IsKeyDown(r.KEY_X);
        mem.joypad_state.up = r.IsKeyDown(r.KEY_I);
        mem.joypad_state.down = r.IsKeyDown(r.KEY_K);
        mem.joypad_state.left = r.IsKeyDown(r.KEY_J);
        mem.joypad_state.right = r.IsKeyDown(r.KEY_L);

        // if (cpu.halted) {
        //     step = true;
        //     cpu.halted = false;
        // }

        // if (cpu.debug) {
        // step = true;
        // }

        const tile_debug_pixels = @as([*]r.Color, @ptrCast(tile_debug_img.data.?));
        for (0..384) |t| {
            const offset = 0x8000 + (t * 16);
            for (0..8) |line| {
                const high = mem.read_silent(@intCast(offset + line * 2));
                const low = mem.read_silent(@intCast(offset + line * 2 + 1));
                for (0..8) |px| {
                    const c = bit(low, 7 - px) | @as(u2, bit(high, 7 - px)) << 1;
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
                const t = mem.read_silent(@intCast(start_offset + (ty * 32) + tx));

                for (0..8) |line| {
                    for (0..8) |px| {
                        const c = mem.get_tile_color(mem.lcd.LCDC.bg_win_tiles, t, px, line);
                        const x = (tx * 8 + px);
                        const y = (ty * 8 + line);
                        bg_debug_pixels[y * @as(usize, @intCast(bg_debug_img.width)) + x] = mem.BGP.get_rgba(c);
                    }
                }
            }
        }
        r.UpdateTexture(bg_debug_tex, bg_debug_img.data);

        if (mem.lcd.fb_dirty) {
            r.UpdateTexture(fb_tex, fb_img.data);
            mem.lcd.fb_dirty = false;
        }

        r.BeginDrawing();
        r.ClearBackground(r.BEIGE);

        var buf = std.mem.zeroes([1024]u8);
        var fbs = std.io.fixedBufferStream(&buf);
        const writer = fbs.writer();

        for (mem.oam) |sprite| {
            try std.fmt.format(writer, "{d:0>3},{d:0>3} {X:0>2}\n", .{
                sprite.x,
                sprite.y,
                sprite.tile,
            });
        }
        r.DrawText(&buf, 550, 500, 12, r.BLACK);

        r.DrawText("Screen", 100, 37, 12, r.BLACK);
        r.DrawTextureEx(fb_tex, .{ .x = 101, .y = 51 }, 0, 2, r.WHITE);
        r.DrawRectangleLines(100, 50, fb_img.width * 2 + 2, fb_img.height * 2 + 2, r.BLACK);

        r.DrawText("Tiles", 550, 7, 12, r.BLACK);
        r.DrawTextureEx(tile_debug_tex, .{ .x = 551, .y = 21 }, 0, 2, r.WHITE);
        r.DrawRectangleLines(550, 20, tile_debug_img.width * 2 + 2, tile_debug_img.height * 2 + 2, r.BLACK);
        // r.DrawTextureRec(tile_debug_tex, .{ .x = 0, .y = 0, .width = @bitCast(tile_debug_tex.width), .height = @bitCast(-tile_debug_tex.height) }, .{ .x = 0, .y = 0 }, r.WHITE);

        r.DrawText("Map", 10, 387, 12, r.BLACK);
        r.DrawTextureEx(bg_debug_tex, .{ .x = 11, .y = 401 }, 0, 2, r.WHITE);
        const SCX = @as(c_int, @intCast(mem.lcd.SCX));
        const SCY = @as(c_int, @intCast(mem.lcd.SCY));
        r.DrawRectangleLines(11 + SCX * 2, 401 + SCY * 2, SCREEN_WIDTH * 2, SCREEN_HEIGHT * 2, r.LIGHTGRAY);
        r.DrawRectangleLines(10, 400, bg_debug_img.width * 2 + 2, bg_debug_img.height * 2 + 2, r.BLACK);
        //
        //
        for (0..4) |i| {
            r.DrawRectangle(550 + 25 * @as(c_int, @intCast(i)), 470, 20, 20, mem.BGP.get_rgba(@intCast(i)));
        }

        if (r.IsKeyPressed(r.KEY_D)) cpu.debug = !cpu.debug;

        r.EndDrawing();
    }
}

fn bit(n: anytype, b: anytype) u1 {
    return @truncate((n >> @intCast(b)) & 1);
}
