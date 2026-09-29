"""Generates the ASCII map for Level 1 (Stomp Road) into scenes/levels/level_01/level_01_map.txt.

Placing features by coordinates is less error-prone than hand-aligning a 176-column grid.
Coordinates are in cells: x to the right, y up, y=0 is the bottom row. Ground is y=0..1,
so the walkable surface is y=2.  Run: python tools/level_01_layout.py
"""
from pathlib import Path

W, H = 176, 15
grid = [["."] * W for _ in range(H)]


def put(x, y, c):
    grid[y][x] = c


def ground(x0, x1):
    for x in range(x0, x1 + 1):
        put(x, 0, "#")
        put(x, 1, "#")


def pipe(x, height):
    for y in range(2, 2 + height):
        put(x, y, "p")
        put(x + 1, y, "p")
    put(x, 1 + height, "P")


def stairs(x0, heights):
    for i, h in enumerate(heights):
        for y in range(2, 2 + h):
            put(x0 + i, y, "H")


pits = [(60, 61), (85, 86), (89, 93), (128, 129)]
x = 0
for a, b in pits:
    ground(x, a - 1)
    x = b + 1
ground(x, W - 1)

put(3, 2, "S")

# 1. Opening: a lone coin block, then the classic block row with the first mushroom.
put(12, 5, "?")
for bx, c in zip(range(17, 23), "B?BMB?"):
    put(bx, 5, c)
put(20, 9, "?")
put(26, 2, "g")

# 2. Pipes of rising height with Grumbles between them.
pipe(30, 2)
put(35, 2, "g")
pipe(39, 3)
put(44, 2, "g")
put(46, 2, "g")
pipe(50, 4)
put(55, 2, "g")

# 3. First pit with coins above it.
put(60, 5, "o")
put(61, 5, "o")

# 4. Brick climb to a high row of coins, Grumbles patrolling underneath.
for bx in range(64, 67):
    put(bx, 5, "B")
put(65, 5, "?")
for bx in range(67, 75):
    put(bx, 9, "B")
for bx in range(68, 74):
    put(bx, 10, "o")
put(75, 9, "?")
put(70, 2, "g")
put(72, 2, "g")

# 5. Checkpoint, then a double pit with a floating stone platform.
put(80, 2, "K")
for bx in range(90, 93):
    put(bx, 4, "H")
put(91, 5, "o")

# 6. Grumble pair, second mushroom, coin arc, Grumble trio.
put(97, 2, "g")
put(99, 2, "g")
put(102, 5, "B")
put(103, 5, "M")
put(104, 5, "B")
for (cx, cy) in [(108, 4), (109, 5), (110, 6), (111, 6), (112, 5), (113, 4)]:
    put(cx, cy, "o")
for gx in (116, 118, 120):
    put(gx, 2, "g")

# 7. Stairs up, gap, stairs down.
stairs(124, [1, 2, 3, 4])
stairs(130, [4, 3, 2, 1])
put(137, 2, "g")
pipe(140, 2)

# 8. Final staircase to the flagpole.
stairs(146, [1, 2, 3, 4, 5, 6, 7, 8])
put(160, 2, "H")
put(160, 3, "F")

rows = ["".join(grid[y]) for y in reversed(range(H))]
out = Path(__file__).resolve().parent.parent / "scenes/levels/level_01/level_01_map.txt"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(rows) + "\n", encoding="utf-8")
print("\n".join(rows))
