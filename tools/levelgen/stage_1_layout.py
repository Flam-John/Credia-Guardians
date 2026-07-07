"""Compose the Stage 1 (Developer Office) ASCII map from placement commands.

Output: data/levels/stage_1_map.txt — loaded at runtime by
src/levels/stages/stage_1.gd. The text output stays hand-editable; this
script exists so the initial layout is column-exact. Re-run after edits:
    python tools/levelgen/stage_1_layout.py

Legend: see src/levels/level_base.gd.
"""
WIDTH, HEIGHT = 160, 24
# ' ' = empty (parallax background shows through); '.' panels only in vaults
grid = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]


def put(x, y, ch):
    grid[y][x] = ch


def hline(x0, x1, y, ch):  # inclusive
    for x in range(x0, x1 + 1):
        put(x, y, ch)


def vline(x, y0, y1, ch):
    for y in range(y0, y1 + 1):
        put(x, y, ch)


def rect(x0, y0, x1, y1, ch):
    for y in range(y0, y1 + 1):
        hline(x0, x1, y, ch)


def coins(*positions):
    for x, y in positions:
        put(x, y, "c")


# ---- shell ----
hline(0, WIDTH - 1, 0, "@")                      # ceiling
vline(0, 0, HEIGHT - 1, "@")                     # left wall
vline(WIDTH - 1, 0, HEIGHT - 1, "@")             # right wall
rect(1, 23, WIDTH - 2, 23, "@")                  # bedrock

# ---- section 1: spawn + tutorial (cols 1-27) ----
hline(1, 27, 19, "#")
rect(1, 20, 27, 22, "@")
put(3, 18, "P")
coins((5, 18), (6, 18), (7, 17), (9, 16), (11, 17), (8, 15), (10, 15),
      (14, 18), (15, 18), (16, 18))
put(20, 18, "J")
hline(23, 27, 16, "#")                           # step-up ledge
coins((24, 15), (25, 15), (26, 15))

# ---- section 2: conveyor desks (cols 28-59) ----
hline(28, 59, 19, "#")
rect(28, 20, 59, 22, "@")
coins((28, 18), (29, 18))
hline(30, 40, 14, "#")                           # desk 1 (against player)
hline(30, 39, 13, "<")
coins((31, 12), (33, 12), (35, 12), (37, 12), (39, 12),
      (32, 11), (34, 11), (36, 11), (38, 11))
put(42, 18, "k")                                 # checkpoint 1
coins((41, 18),)
hline(44, 54, 14, "#")                           # desk 2 (with player)
hline(44, 53, 13, ">")
coins((45, 12), (47, 12), (49, 12), (51, 12), (53, 12),
      (46, 11), (48, 11), (50, 11), (52, 11))
put(57, 18, "N")                                 # node 1

# ---- section 3: coffee steam shafts (cols 60-84) ----
rect(60, 22, 84, 22, "#")                        # pit floor
put(60, 21, "#")                                 # step down edge
hline(64, 67, 21, "^")
hline(73, 76, 21, "^")
for col in (62, 70, 78):                         # steam columns
    vline(col, 9, 18, "~")
    coins((col, 15), (col, 12))
hline(60, 63, 8, "#")
hline(68, 71, 8, "#")
hline(76, 79, 8, "#")
coins((61, 7), (62, 7), (69, 7), (70, 7), (77, 7), (78, 7),
      (65, 6), (66, 6), (73, 6), (74, 6), (69, 3), (70, 3))

# ---- section 4: hidden vault 1 under the floor (cols 85-93) ----
hline(85, 95, 19, "#")
rect(85, 20, 95, 22, "@")
rect(87, 20, 92, 21, ".")                        # carve the vault
put(87, 19, ".")                                 # entrance gap (drop in)
put(88, 19, ".")
coins((87, 21), (88, 21), (89, 21), (90, 21), (91, 21), (88, 20), (90, 20))
put(92, 21, "o")                                 # coffee inside
coins((85, 18),)

# ---- section 5: spike pit + moving platforms (cols 94-117) ----
put(94, 18, "c")
put(95, 18, "k")                                 # checkpoint 2
hline(96, 114, 22, "#")                          # pit bottom
hline(98, 112, 21, "^")
hline(96, 103, 15, "=")                          # mover A
hline(106, 113, 12, "=")                         # mover B
coins((97, 14), (99, 14), (101, 14), (107, 11), (109, 11), (111, 11),
      (99, 9), (100, 9), (107, 8), (108, 8))
hline(115, 158, 19, "#")                         # floor resumes to the end
rect(115, 20, 158, 22, "@")
put(116, 18, "N")                                # node 2
coins((117, 18), (118, 18))

# ---- section 6: office maze (cols 119-139) ----
coins((119, 18), (130, 18), (134, 18))
put(124, 18, "J")
put(128, 18, "o")
hline(120, 136, 14, "#")                         # upper walkway
coins((121, 13), (123, 13), (125, 13), (127, 13), (129, 13), (131, 13),
      (133, 13), (135, 13))
put(132, 13, "J")
put(136, 13, "N")                                # node 3 (upper)
# hidden vault 2 under the maze floor
rect(122, 20, 127, 22, ".")
put(123, 19, ".")
put(124, 19, ".")
coins((123, 21), (125, 21), (126, 21), (123, 20), (126, 20))
put(122, 21, "e")                                # energy drink inside

# ---- section 7: manager gauntlet (cols 140-156) ----
put(139, 18, "k")                                # checkpoint 3
vline(141, 15, 18, "#")                          # left arena wall
put(146, 18, "M")
put(152, 18, "M")
coins((145, 15), (148, 15), (151, 15))
vline(155, 15, 18, "#")                          # right arena wall
coins((153, 18), (154, 18))

# ---- section 8: exit (cols 156-158) ----
put(157, 18, "E")

# ---- top-up to exactly 100 coins (GDD: FULL AUDIT requires all 100) ----
coins((12, 18), (13, 18), (55, 18), (56, 18), (120, 18), (135, 18))

out = "\n".join("".join(row) for row in grid) + "\n"
with open("data/levels/stage_1_map.txt", "w", encoding="ascii") as f:
    f.write(out)
print("coins:", out.count("c"))
print("nodes:", out.count("N"), "checkpoints:", out.count("k"),
      "enemies:", out.count("J") + out.count("M"))
