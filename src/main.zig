const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});
const Position = @Vector(2, usize);

const EMPTY = 0;
const RED = 2;
const YELLOW = 1;

const radius: c_int = 50;
const columnSize: c_int = radius * 2;

const rows = 6;
const columns = 7;
const GameTable = [rows][columns]u2;

pub fn main() !void {
    var isYellow = true;
    var gameOvew = false;

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(700, 700, "test");

    var gameTable: GameTable = std.mem.zeroes([rows][columns]u2);

    while (!r.WindowShouldClose()) {
        const windowWidth = r.GetRenderWidth();
        _ = windowWidth; // autofix
        const windowHeight = r.GetRenderHeight();
        if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
            const mousePos = r.GetMousePosition();
            _ = mousePos; // autofix
            const placedPointOpt = placePoint(&isYellow, &gameTable, r.GetMousePosition());
            if (placedPointOpt) |placedPoint| {
                if (checkGameTie(gameTable)) {
                    std.log.info("GAME TIED", .{});
                    gameOvew = true;
                } else if (checkGameOver(&gameTable, placedPoint, !isYellow)) {
                    std.log.info("GAME OVER, {s} WON", .{if (!isYellow) "Yellow" else "Red"});
                    gameOvew = true;
                }
            }
        }

        // DRAW
        r.BeginDrawing();
        defer r.EndDrawing();
        r.ClearBackground(r.WHITE);
        if (gameOvew) {
            if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
                gameOvew = false;
                gameTable = std.mem.zeroes([rows][columns]u2);
                isYellow = true;
            }
            continue;
        }

        for (1..columns) |i| {
            const x = @as(c_int, @intCast(i)) * columnSize;

            r.DrawLine(x, windowHeight - rows * columnSize, x, windowHeight, r.BLACK);
        }

        for (gameTable, 0..) |row, i| {
            for (row, 0..) |value, j| {
                if (value != EMPTY) {
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

fn placePoint(isYellow: *bool, gameTable: *GameTable, mousePosition: r.struct_Vector2) ?Position {
    const column: usize = @intFromFloat(@divFloor(mousePosition.x, @as(f32, @floatFromInt(columnSize))));
    if (column > columns - 1) {
        std.log.info("Clicked outside", .{});
        return null;
    }
    if (gameTable.*[rows - 1][column] != 0) {
        std.log.info("Column full", .{});
        return null;
    }
    for (gameTable, 0..) |row, i| {
        if (row[column] == EMPTY) {
            gameTable[i][column] = if (isYellow.*) 1 else 2;
            isYellow.* = !isYellow.*;
            return Position{ i, column };
        }
    }
    return null;
}

fn checkGameOver(gameTable: *GameTable, lastMove: Position, isYellow: bool) bool {
    return getGameScore(gameTable, lastMove, isYellow) >= 3;
}

fn getGameScore(gameTable: *GameTable, lastMove: Position, isYellow: bool) u32 {
    const target: u2 = if (isYellow) YELLOW else RED;
    const col: u8 = @intCast(lastMove[1]);
    const row: u8 = @intCast(lastMove[0]);

    var score: u8 = 0;

    // Check down
    var i: u8 = row;
    while (gameTable[i][col] == target) {
        if (i >= 0) {
            score = @max(score, row - i);
        }
        if (i > 0) {
            i -= 1;
        } else {
            break;
        }
    }

    // Check Horizontal
    var left: i5 = 0;
    var horizontal: isize = @as(isize, @intCast(col)) - 1;
    while (horizontal >= 0 and gameTable[row][@intCast(horizontal)] == target) {
        left += 1;
        horizontal -= 1;
    }
    var right: i5 = 0;
    horizontal = @intCast(col + 1);
    while (horizontal < columns and gameTable[row][@intCast(horizontal)] == target) {
        right += 1;
        horizontal += 1;
    }

    score = @max(score, @as(u8, @intCast(left + right)));

    //l2r diagonal
    left = 0;
    horizontal = @as(isize, @intCast(col)) - 1;
    var vertical: isize = @as(isize, @intCast(row)) - 1;
    while (horizontal >= 0 and vertical >= 0 and gameTable[@intCast(vertical)][@intCast(horizontal)] == target) {
        left += 1;
        horizontal -= 1;
        vertical -= 1;
    }

    right = 0;
    horizontal = @as(isize, @intCast(col)) + 1;
    vertical = @as(isize, @intCast(row)) + 1;

    while (horizontal < columns and vertical < rows and gameTable[@intCast(vertical)][@intCast(horizontal)] == target) {
        right += 1;
        horizontal += 1;
        vertical += 1;
    }

    score = @max(score, @as(u8, @intCast(left + right)));

    //r2l diagonal
    left = 0;
    horizontal = @as(isize, @intCast(col)) - 1;
    vertical = @as(isize, @intCast(row)) + 1;
    while (horizontal >= 0 and vertical < rows and gameTable[@intCast(vertical)][@intCast(horizontal)] == target) {
        left += 1;
        horizontal -= 1;
        vertical += 1;
    }

    right = 0;
    horizontal = @as(isize, @intCast(col)) + 1;
    vertical = @as(isize, @intCast(row)) - 1;

    while (horizontal < columns and vertical > 0 and gameTable[@intCast(vertical)][@intCast(horizontal)] == target) {
        right += 1;
        horizontal += 1;
        vertical -= 1;
    }

    score = @max(score, @as(u8, @intCast(left + right)));

    std.log.info("{s} SCORE: {d}", .{ if (isYellow) "Yellow" else "Red", score });
    return score;
}

fn checkGameTie(gameTable: GameTable) bool {
    printGame(gameTable) catch unreachable;
    for (gameTable[gameTable.len - 1]) |value| {
        if (value == EMPTY) {
            return false;
        }
    }
    return true;
}

// Returns "height" of columns
fn checkPossibleMoves(gameTable: GameTable, result: *[7]u8) void {
    for (gameTable, 0..) |row, i| {
        _ = i; // autofix
        for (row, 0..) |col, j| {
            if (col != EMPTY) {
                result.*[j] += 1;
            }
        }
    }
}

fn printGame(gameTable: GameTable) !void {
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

}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
