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

const ROWS = 6;
const COLUMNS = 7;
const GameTable = [ROWS][COLUMNS]u2;

const isMultiplayer = true;

// ---- SCORE PARAMETERS -----
const WIN_SCORE = 10000000;
const THREE_IN_A_ROW = 500;
const TWO_IN_A_ROW = 50;

const ENEMY_WIN_SCORE = -10000000;
const ENEMY_THREE_IN_A_ROW = -700;
const ENEMY_TWO_IN_A_ROW = -40;

pub fn main() !void {
    var isYellow = true;
    var gameOvew = false;

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_RESIZABLE);
    r.InitWindow(700, 700, "test");

    var gameTable: GameTable = std.mem.zeroes([ROWS][COLUMNS]u2);

    while (!r.WindowShouldClose()) {
        const windowWidth = r.GetRenderWidth();
        _ = windowWidth; // autofix
        const windowHeight = r.GetRenderHeight();

        if (!isMultiplayer or isYellow) {
            // User interaction
            if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
                const placedPointOpt = placePoint(isYellow, gameTable, r.GetMousePosition());
                if (placedPointOpt) |placedPoint| {
                    playATurn(&gameTable, &isYellow, placedPoint);
                    if (checkGameTie(gameTable)) {
                        std.log.info("GAME TIED", .{});
                        gameOvew = true;
                    } else if (checkGameOver(&gameTable, if (isYellow) RED else YELLOW)) {
                        std.log.info("GAME OVER, {s} WON", .{if (!isYellow) "Yellow" else "Red"});
                        gameOvew = true;
                    }
                }
            }
        } else {
            // AI Turn
            const best_pos = startMinMax(gameTable);
            playATurn(&gameTable, &isYellow, best_pos);
            if (checkGameTie(gameTable)) {
                std.log.info("GAME TIED", .{});
                gameOvew = true;
            } else if (checkGameOver(&gameTable, if (isYellow) RED else YELLOW)) {
                std.log.info("GAME OVER, {s} WON", .{if (!isYellow) "Yellow" else "Red"});
                gameOvew = true;
            }
        }

        // DRAW
        r.BeginDrawing();
        defer r.EndDrawing();
        r.ClearBackground(r.WHITE);
        if (gameOvew) {
            if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
                gameOvew = false;
                gameTable = std.mem.zeroes([ROWS][COLUMNS]u2);
                isYellow = true;
            }
            continue;
        }

        for (1..COLUMNS) |i| {
            const x = @as(c_int, @intCast(i)) * columnSize;

            r.DrawLine(x, windowHeight - ROWS * columnSize, x, windowHeight, r.BLACK);
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

fn placePoint(isYellow: bool, gameTable: GameTable, mousePosition: r.struct_Vector2) ?Position {
    _ = isYellow; // autofix
    const column: usize = @intFromFloat(@divFloor(mousePosition.x, @as(f32, @floatFromInt(columnSize))));
    if (column > COLUMNS - 1) {
        std.log.info("Clicked outside", .{});
        return null;
    }
    if (gameTable[ROWS - 1][column] != 0) {
        std.log.info("Column full", .{});
        return null;
    }
    for (gameTable, 0..) |row, i| {
        if (row[column] == EMPTY) {
            return Position{ i, column };
        }
    }
    return null;
}

fn playATurn(
    gameTable: *GameTable,
    isYellow: *bool,
    play: Position,
) void {
    gameTable.*[play[0]][play[1]] = if (isYellow.*) YELLOW else RED;
    isYellow.* = !isYellow.*;
}

fn checkGameOver(gameTable: *GameTable, target: u2) bool {
    return @abs(evaluateBoard(gameTable.*, target)) >= WIN_SCORE / 2;
}

fn evalWindow(window: []const u2, target: u2) i32 {
    var score: i32 = 0;
    var targetCount: u3 = 0;
    var emptyCount: u3 = 0;
    var enemyCount: u3 = 0;
    if (window.len < 4) {
        return 0;
    }

    for (window) |value| {
        if (value == EMPTY) {
            emptyCount += 1;
        } else if (value == target) {
            targetCount += 1;
        } else {
            enemyCount += 1;
        }
    }
    if (targetCount == 4) {
        score += WIN_SCORE;
    } else if (targetCount == 3 and emptyCount == 1) {
        score += THREE_IN_A_ROW;
    } else if (enemyCount == 4) {
        score += ENEMY_WIN_SCORE;
    } else if (enemyCount == 3 and emptyCount == 1) {
        score += ENEMY_THREE_IN_A_ROW;
    }

    return score;
}

fn evaluateBoard(gameTable: GameTable, target: u2) i32 {
    var score: i32 = 0;
    // horizontal
    for (gameTable) |row| {
        for (0..COLUMNS - 3) |j| {
            score += evalWindow(row[j .. j + 4], target);
        }
    }

    //vertical
    for (3..ROWS) |i| {
        for (0..COLUMNS) |j| {
            // std.log.debug("i:{d} j:{d}", .{ i, j });
            var window: [4]u2 = .{ 0, 0, 0, 0 };
            for (0..window.len) |k| {
                window[k] = gameTable[i - k][j];
            }
            score += evalWindow(&window, target);
        }
    }

    // right diagonal
    for (0..ROWS - 3) |i| {
        for (0..COLUMNS - 3) |j| {
            var window: [4]u2 = .{ 0, 0, 0, 0 };
            for (0..window.len) |k| {
                window[k] = gameTable[i + k][j + k];
            }
            score += evalWindow(&window, target);
        }
    }
    // left diagonal
    for (0..ROWS - 3) |i| {
        for (3..COLUMNS) |j| {
            var window: [4]u2 = .{ 0, 0, 0, 0 };
            for (0..window.len) |k| {
                window[k] = gameTable[i + k][j - k];
            }
            score += evalWindow(&window, target);
        }
    }

    return score;
}

fn checkGameTie(gameTable: GameTable) bool {
    // printGame(gameTable) catch unreachable;
    for (gameTable[gameTable.len - 1]) |value| {
        if (value == EMPTY) {
            return false;
        }
    }
    return true;
}

// Returns "height" of columns
fn checkPossibleMoves(gameTable: GameTable) [7]u8 {
    var result: [7]u8 = std.mem.zeroes([7]u8);
    for (gameTable) |row| {
        for (row, 0..) |col, j| {
            if (col != EMPTY) {
                result[j] += 1;
            }
        }
    }
    return result;
}

fn startMinMax(gameTableImut: GameTable) Position {
    var gameTable = gameTableImut;
    const possibleMoves = checkPossibleMoves(gameTable);
    var bestScore: i32 = std.math.minInt(i32);
    var bestMove: Position = undefined;

    for (possibleMoves, 0..) |value, i| {
        if (value >= 6) {
            continue;
        }
        gameTable[value][i] = RED;
        defer gameTable[value][i] = EMPTY;

        const branchScore = minimax(&gameTable, false, .{ value, i }, 5);
        std.log.debug("col: {d} branchScore = {d}", .{ i, branchScore });

        if (branchScore > bestScore) {
            bestScore = @intCast(branchScore);
            bestMove = .{ value, i };
        }
    }
    std.log.debug("Best score {d}", .{bestScore});
    // if (bestScore == 0) {
    //     const seed: u64 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
    //     var prng = std.rand.DefaultPrng.init(seed);
    //     const rand = prng.random().intRangeAtMost(usize, 0, COLUMNS - 1);
    //     bestMove = .{ possibleMoves[rand], rand };
    // }
    return bestMove;
}

fn minimax(gameTable: *GameTable, isMaximizer: bool, move: Position, depth: i32) i32 {
    const player: u2 = if (isMaximizer) YELLOW else RED;
    gameTable[move[0]][move[1]] = player;
    defer gameTable[move[0]][move[1]] = EMPTY;

    if (checkGameTie(gameTable.*)) {
        return 0;
    }

    const nodeScore = evaluateBoard(gameTable.*, RED);
    if (depth == 0 or @abs(nodeScore) > WIN_SCORE / 2) {
        return nodeScore * depth;
    }

    var bestScore: i32 = if (isMaximizer) std.math.minInt(i32) else std.math.maxInt(i32);

    const possibleMoves = checkPossibleMoves(gameTable.*);
    for (possibleMoves, 0..) |row, col| {
        if (row >= ROWS) {
            continue;
        }
        const branchScore = minimax(gameTable, !isMaximizer, .{ row, col }, depth - 1);
        if (isMaximizer) {
            if (branchScore > bestScore) {}
            bestScore = branchScore;
        } else {
            if (branchScore < bestScore) {
                bestScore = branchScore;
            }
        }
    }
    return bestScore;
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
