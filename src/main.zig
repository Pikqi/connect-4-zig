const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

const RED = 2;
const YELLOW = 1;

const radius: c_int = 50;
const columnSize: c_int = radius * 2;

const rows = 6;
const columns = 7;

pub fn main() !void {
    var isYellow = true;

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(700, 700, "test");

    var gameTable: [rows][columns]u2 = std.mem.zeroes([rows][columns]u2);

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
        if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
            const mousePos = r.GetMousePosition();
            _ = mousePos; // autofix
            placePoint(&isYellow, &gameTable, r.GetMousePosition());
        }

        // DRAW
        r.BeginDrawing();
        defer r.EndDrawing();
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
                        if (value == YELLOW) r.YELLOW else r.RED,
                    );
                }
            }
        }
    }
}
fn placePoint(isYellow: *bool, gameTable: *[rows][columns]u2, mousePosition: r.struct_Vector2) void {
    const column: usize = @intFromFloat(@divFloor(mousePosition.x, @as(f32, @floatFromInt(columnSize))));
    if (column > columns - 1) {
        std.log.info("Clicked outside", .{});
        return;
    }
    if (gameTable.*[rows - 1][column] != 0) {
        std.log.info("Column full", .{});
        return;
    }
    for (gameTable, 0..) |row, i| {
        if (row[column] == 0) {
            gameTable[i][column] = if (isYellow.*) 1 else 2;
            isYellow.* = !isYellow.*;
            return;
        }
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
