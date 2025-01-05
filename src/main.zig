const std = @import("std");
const r = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

const Position = @Vector(2, usize);
const BranchThread = struct {
    thread: std.Thread,
    isRunning: bool = false,
    yMove: u8,
    result: i32,
};

const GameMode = enum(u3) {
    MINIMAX,
    MINIMAX_THREADED,
    MINIMAX_APHA_BETA,
};

const EMPTY = 0;
const RED = 2;
const YELLOW = 1;

const radius: c_int = 50;
const columnSize: c_int = radius * 2;

const ROWS = 6;
const COLUMNS = 7;
const GameTable = [ROWS][COLUMNS]u2;

const isMultiplayer = true;
const isAiVSAi = false;
const DEFAULT_DEPTH = 5;

// ---- SCORE PARAMETERS -----
const WIN_SCORE = 10000;
const THREE_IN_A_ROW = 500;
const TWO_IN_A_ROW = 50;

const ENEMY_WIN_SCORE = -100000;
const ENEMY_THREE_IN_A_ROW = -700;
const ENEMY_TWO_IN_A_ROW = -40;

// ---- UI ----
const TOP_PADDING = 200;
const FONT_SIZE = 25;
const WIDTH = COLUMNS * columnSize;
const HEIGHT = ROWS * columnSize + TOP_PADDING;
const TEXT_GAP = FONT_SIZE + 5;
var minimaxDepth: i32 = DEFAULT_DEPTH;

pub fn main() !void {
    var isYellow = true;
    var gameOver = false;
    var mode: GameMode = GameMode.MINIMAX;

    var lastTurnMiliSeconds: i32 = 0;

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    r.SetConfigFlags(r.FLAG_VSYNC_HINT | r.FLAG_MSAA_4X_HINT | r.FLAG_WINDOW_MINIMIZED);
    r.InitWindow(WIDTH, HEIGHT, "test");

    var gameTable: GameTable = std.mem.zeroes([ROWS][COLUMNS]u2);

    while (!r.WindowShouldClose()) {
        const windowWidth = r.GetRenderWidth();
        const windowHeight = r.GetRenderHeight();

        if (!gameOver) {
            if (!isAiVSAi and (!isMultiplayer or isYellow)) {
                // User interaction
                if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
                    const placedPointOpt = placePoint(isYellow, gameTable, r.GetMousePosition());
                    if (placedPointOpt) |placedPoint| {
                        playATurn(&gameTable, &isYellow, placedPoint);
                        if (checkGameTie(gameTable)) {
                            std.log.info("GAME TIED", .{});
                            gameOver = true;
                        } else if (checkGameOver(gameTable, if (isYellow) RED else YELLOW)) {
                            std.log.info("GAME OVER, {s} WON", .{if (!isYellow) "Yellow" else "Red"});
                            gameOver = true;
                        }
                    }
                }
            } else {
                // AI Turn
                var best_pos: Position = undefined;
                const player: u2 = if (isYellow) YELLOW else RED;
                const startTimestamp = std.time.nanoTimestamp();
                switch (mode) {
                    .MINIMAX_THREADED => {
                        best_pos = try startMinMaxThreaded(gameTable, minimaxDepth, player);
                    },
                    .MINIMAX => {
                        best_pos = startMinMax(gameTable, minimaxDepth, player);
                    },
                    else => {
                        std.log.err("Invalid mode", .{});
                    },
                }
                const diffNanoTime = std.time.nanoTimestamp() - startTimestamp;
                lastTurnMiliSeconds = @intCast(@divFloor(diffNanoTime, std.time.ns_per_ms));
                std.log.info("Last turn took: {d} ms", .{lastTurnMiliSeconds});

                playATurn(&gameTable, &isYellow, best_pos);
                if (checkGameTie(gameTable)) {
                    std.log.info("GAME TIED", .{});
                    gameOver = true;
                } else if (checkGameOver(gameTable, if (isYellow) RED else YELLOW)) {
                    std.log.info("GAME OVER, {s} WON", .{if (!isYellow) "Yellow" else "Red"});
                    gameOver = true;
                    try printGame(gameTable);
                }
            }
        }

        if (r.IsKeyPressed(r.KEY_ONE)) {
            mode = .MINIMAX;
        } else if (r.IsKeyPressed(r.KEY_TWO)) {
            mode = .MINIMAX_THREADED;
        }

        if (r.IsKeyPressed(r.KEY_MINUS)) {
            minimaxDepth = @max(1, minimaxDepth - 1);
        } else if (r.IsKeyPressed(r.KEY_EQUAL)) {
            minimaxDepth += 1;
        }

        // DRAW
        r.BeginDrawing();
        defer r.EndDrawing();

        var textMargin: c_int = 5;

        if (gameOver) {
            r.DrawText("GAME OVER", @divFloor(windowWidth, 2) - 5 * FONT_SIZE, @divFloor(WIDTH, 2), FONT_SIZE * 2, r.BLACK);
            if (r.IsMouseButtonPressed(r.MOUSE_BUTTON_LEFT)) {
                gameOver = false;
                gameTable = std.mem.zeroes([ROWS][COLUMNS]u2);
                isYellow = true;
            }
        }

        var textBuff: [100]u8 = undefined;

        r.DrawText("Change mods with 1-3", 10, textMargin, FONT_SIZE, r.BLACK);
        textMargin += TEXT_GAP;

        const modeText = try std.fmt.bufPrintZ(&textBuff, "Mode: {s}", .{@tagName(mode)});
        const modeColor: r.Color = switch (mode) {
            .MINIMAX => r.RED,
            .MINIMAX_THREADED => r.ORANGE,
            .MINIMAX_APHA_BETA => r.GREEN,
        };
        r.DrawText(modeText, 10, textMargin, FONT_SIZE, modeColor);
        textMargin += TEXT_GAP;

        const depthText = try std.fmt.bufPrintZ(&textBuff, "Depth: {d} +/- to change", .{minimaxDepth});
        r.DrawText(depthText, 10, textMargin, FONT_SIZE, r.BLACK);
        textMargin += TEXT_GAP;

        const timingText = try std.fmt.bufPrintZ(&textBuff, "Last turn took: {d} ms", .{lastTurnMiliSeconds});
        r.DrawText(timingText, 10, textMargin, FONT_SIZE, r.BLACK);
        textMargin += TEXT_GAP;

        r.ClearBackground(r.WHITE);

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

fn checkGameOver(gameTable: GameTable, target: u2) bool {
    const score = @abs(evaluateBoard(gameTable, target));
    return score >= WIN_SCORE / 2;
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

    // center bias
    for (gameTable, 0..) |row, i| {
        for (row, 0..) |element, j| {
            switch (element) {
                YELLOW => {
                    if (target == YELLOW) {
                        score += centerBias[i][j];
                    } else {
                        score -= centerBias[i][j];
                    }
                },
                RED => {
                    if (target == RED) {
                        score += centerBias[i][j];
                    } else {
                        score -= centerBias[i][j];
                    }
                },
                else => {},
            }
        }
    }

    // horizontal
    for (gameTable) |row| {
        for (0..COLUMNS - 3) |j| {
            score += evalWindow(row[j .. j + 4], target);
        }
    }

    //vertical
    for (3..ROWS) |i| {
        for (0..COLUMNS) |j| {
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

fn startMinMax(gameTableImut: GameTable, depth: i32, target: u2) Position {
    var gameTable = gameTableImut;
    const possibleMoves = checkPossibleMoves(gameTable);
    var bestScore: i32 = std.math.minInt(i32);
    var bestMove: Position = undefined;

    for (possibleMoves, 0..) |value, i| {
        if (value >= 6) {
            continue;
        }

        const branchScore = minimax(&gameTable, false, .{ value, i }, depth, target);
        std.log.debug("col: {d} branchScore = {d}", .{ i, branchScore });

        if (branchScore > bestScore) {
            bestScore = @intCast(branchScore);
            bestMove = .{ value, i };
        }
    }
    std.log.debug("Best score {d}", .{bestScore});
    return bestMove;
}

fn minimax(gameTable: *GameTable, isMaximizer: bool, move: Position, depth: i32, target: u2) i32 {
    const player: u2 = if (isMaximizer) if (target == YELLOW) RED else YELLOW else target;
    gameTable[move[0]][move[1]] = player;
    defer gameTable[move[0]][move[1]] = EMPTY;

    if (checkGameTie(gameTable.*)) {
        return 0;
    }

    const nodeScore = evaluateBoard(gameTable.*, target);
    if (depth == minimaxDepth - 1 and isMaximizer and @abs(nodeScore) > WIN_SCORE) {
        return std.math.minInt(i32) + 1;
    }
    if (depth == 0 or @abs(nodeScore) > WIN_SCORE / 2) {
        return nodeScore * (depth + 1);
    }

    var bestScore: i32 = if (isMaximizer) std.math.minInt(i32) else std.math.maxInt(i32);

    const possibleMoves = checkPossibleMoves(gameTable.*);
    for (possibleMoves, 0..) |row, col| {
        if (row >= ROWS) {
            continue;
        }
        const branchScore = minimax(gameTable, !isMaximizer, .{ row, col }, depth - 1, target);
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

// THREADED MINIXMAX - NO ALPHABETA
fn startMinMaxThreaded(gameTableImut: GameTable, depth: i32, target: u2) !Position {
    var gameTable = gameTableImut;
    const possibleMoves = checkPossibleMoves(gameTable);
    var bestScore: i32 = std.math.minInt(i32);
    var bestMove: Position = undefined;
    var threads: [COLUMNS]BranchThread = undefined;
    inline for (0..threads.len) |i| {
        threads[i] = BranchThread{ .result = 0, .thread = undefined, .yMove = 0, .isRunning = false };
    }

    for (possibleMoves, 0..) |value, i| {
        if (value >= 6) {
            continue;
        }
        gameTable[value][i] = target;
        defer gameTable[value][i] = EMPTY;

        var branchThread = &threads[i];

        const thread = try std.Thread.spawn(.{}, minimaxThread, .{ gameTable, false, .{ value, i }, depth, target, &branchThread.result });
        branchThread.thread = thread;
        branchThread.isRunning = true;
        branchThread.yMove = value;
    }
    for (0..threads.len) |i| {
        if (threads[i].isRunning == false) {
            continue;
        }
        threads[i].thread.join();

        const branchScore = threads[i].result;
        std.log.debug("column: {d} score :{d}", .{ i, branchScore });

        if (branchScore > bestScore) {
            bestScore = @intCast(branchScore);
            bestMove = .{ threads[i].yMove, i };
        }
    }
    std.log.debug("Best score {d}", .{bestScore});
    return bestMove;
}

fn minimaxThread(gameTableImut: GameTable, isMaximizer: bool, move: Position, depth: i32, target: u2, result: *i32) void {
    var gameTable = gameTableImut;
    const player: u2 = if (isMaximizer) if (target == YELLOW) RED else YELLOW else target;
    gameTable[move[0]][move[1]] = player;
    defer gameTable[move[0]][move[1]] = EMPTY;

    if (checkGameTie(gameTable)) {
        result.* = 0;
        return;
    }

    const nodeScore = evaluateBoard(gameTable, RED);

    if (depth == minimaxDepth - 1 and isMaximizer and @abs(nodeScore) > WIN_SCORE) {
        result.* = std.math.minInt(i32) + 1;
        return;
    }

    if (depth == 0 or @abs(nodeScore) > WIN_SCORE / 2) {
        result.* = nodeScore * depth;
        return;
    }

    var bestScore: i32 = if (isMaximizer) std.math.minInt(i32) else std.math.maxInt(i32);

    const possibleMoves = checkPossibleMoves(gameTable);
    for (possibleMoves, 0..) |row, col| {
        if (row >= ROWS) {
            continue;
        }
        const branchScore = minimax(&gameTable, !isMaximizer, .{ row, col }, depth - 1, target);
        if (isMaximizer) {
            if (branchScore > bestScore) {}
            bestScore = branchScore;
        } else {
            if (branchScore < bestScore) {
                bestScore = branchScore;
            }
        }
    }
    std.log.info("bestScore : {d}", .{bestScore});
    result.* = bestScore;
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
const centerBias: [ROWS][COLUMNS]u8 = .{
    .{ 3, 4, 5, 7, 5, 5, 3 },
    .{ 4, 6, 8, 10, 8, 6, 4 },
    .{ 5, 7, 11, 13, 11, 7, 5 },
    .{ 5, 7, 11, 13, 11, 7, 5 },
    .{ 4, 6, 8, 10, 8, 6, 4 },
    .{ 3, 4, 5, 7, 5, 5, 3 },
};
