const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

const radius: c_int = 50;
const columnSize: c_int = radius * 2;

const rows = 6;
const columns = 7;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(700, 700, "test");

    var gameTable: [rows][columns]u2 = std.mem.zeroes([rows][columns]u2);
    gameTable[0][0] = 1;
    gameTable[0][1] = 1;
    gameTable[0][2] = 1;
    gameTable[1][6] = 2;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    for (gameTable, 0..) |row, i| {
        try stdout.print("i: {d} ", .{i});
        for (row) |
            value,
        | {
            try stdout.print("{d}", .{value});
        }
        try stdout.print("\n", .{});
    }
    try bw.flush(); // don't forget to flush!

    while (!r.WindowShouldClose()) {
        const windowWidth = r.GetRenderWidth();
        _ = windowWidth; // autofix
        const windowHeight = r.GetRenderHeight();

        r.BeginDrawing();
        r.ClearBackground(r.WHITE);
        for (1..columns) |i| {
            const x = @as(c_int, @intCast(i)) * columnSize;

            r.DrawLine(x, windowHeight - rows * columnSize, x, windowHeight, r.BLACK);
        }

        for (gameTable, 0..) |row, i| {
            for (row, 0..) |value, j| {
                if (value != 0) {
                    r.DrawCircle(
                        @as(c_int, @intCast(j + 1)) * columnSize - radius,
                        windowHeight - columnSize * @as(c_int, @intCast(i)) - radius,
                        radius,
                        if (value == 1) r.RED else r.YELLOW,
                    );
                }
            }
        }

        defer r.EndDrawing();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
