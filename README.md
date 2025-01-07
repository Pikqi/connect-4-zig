Asignment for Intelligent Systems class

Created with Zig 0.13.0 and Raylib 5.5

To build and run (debug mode):
`zig build run`

To build and run (fast mode):
`zig build run -Doptimize=ReleaseFast`

3 Modes available (change with 1,2,3)

- Minimax singlethreaded
- Minimax multithreaded (splits into 6 subproblems)
- Minimax with AlphaBeta pruning (visiting significantly less states)

#### Benchmark

On my machine with i5-8250 (built with ReleaseFast optimize preset):

###### DEPTH 6

- Minimax: ~500ms for first turns (939000 nodes)
- Threaded Minimax: ~200ms for first turns
- AlphaBeta: <200ms for first 1-2 turns afterwads, <100ms (about 4 times less nodes visited in the first few turns).

###### DEPTH 7

- Minimax: ~4500ms and 6540953 nodes
- Threaded Minimax: ~1300ms for first turns
- AlphaBeta: 2000ms for first few turns, then drops to <1000ms
