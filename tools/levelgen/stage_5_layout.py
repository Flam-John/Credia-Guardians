"""Stage 5 — Core Banking System: corruption gauntlet ending at the CEO.

Three USB keys -> three firewall gates; elite recolors throughout; boss
arena before the exit. Re-run: python tools/levelgen/stage_5_layout.py
"""
import importlib.util
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
spec = importlib.util.spec_from_file_location(
    "s24", os.path.join(os.path.dirname(__file__), "stages_2_4_layout.py"))
s24 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s24)
Grid = s24.Grid


def stage_5():
    G = Grid()
    # corrupted entry
    G.hline(1, 24, 19, "#")
    G.rect(1, 20, 24, 22, "@")
    G.put(3, 18, "P")
    G.coin_row(6, 14, 18)
    G.put(12, 16, "m")
    G.put(18, 18, "J")
    # corruption fields: lasers + elites, key 1
    G.hline(25, 60, 19, "#")
    G.rect(25, 20, 60, 22, "@")
    G.hline(28, 33, 18, "l")
    G.hline(40, 45, 18, "l")
    G.coin_row(26, 58, 17, 3)
    G.put(36, 18, "A")
    G.put(48, 18, "R")                    # elite recolor roams free
    # Key 1 shelf at row15 — 64px, plain any-timing double jump (same rule
    # as the stage-3/4 shelves lowered in this branch: 80px mandatory
    # climbs need the early-press trick and key 1 gates ALL progress).
    G.hline(50, 54, 15, "#")
    G.put(52, 14, "U")                    # key 1 (visible shelf)
    G.put(57, 18, "k")
    G.put(59, 18, "F")                    # gate 1
    # vertical steam climb with vents, key 2
    G.hline(61, 92, 19, "#")
    G.rect(61, 20, 92, 22, "@")
    G.vline(76, 9, 18, "V")
    G.hline(63, 69, 8, "#")
    G.hline(73, 79, 8, "#")
    G.hline(83, 89, 8, "#")
    G.coin_row(64, 88, 7, 3)
    G.put(76, 7, "U")                     # key 2 (atop the vent column)
    G.put(64, 7, "N")
    G.coin_row(63, 91, 15, 4)
    # Steam columns rise BESIDE the decks (col 62 = node deck's left edge,
    # col 82 = third deck's left edge) and top out one row ABOVE the deck
    # surface (row 6 vs standing row 7): ride up, drift one tile right,
    # land beside the node / on the third deck. The key deck (73-79) is
    # then a plain 4-col hop from either neighbor. The old spots (66/86,
    # topping out at row 9) sat directly UNDER the decks — risers bonked
    # the underside forever, leaving the mandatory node AND USB key
    # unreachable: stage 5 could never be finished. Drawn after the coin
    # rows so the col-82 column stays contiguous where it crosses
    # coin_row(64,88,7)'s col-82 slot (top_up refills the coin count).
    # A '~' cell may never be capped by solid terrain — guarded by
    # test_stage_completability + live climbs in test_updraft_reachability.
    G.vline(62, 6, 18, "~")
    G.vline(82, 6, 18, "~")
    G.put(70, 18, "L")
    G.put(84, 18, "o")                    # coffee (moved off the col-82 riser)
    G.put(90, 18, "k")
    G.put(91, 18, "F")                    # gate 2
    # fading bridges over corruption pit + key 3
    G.rect(93, 22, 118, 22, "#")
    G.hline(95, 113, 21, "^")
    G.hline(93, 100, 14, "b")
    # Bridge 2 starts at col103 (was 104): bridge1->bridge2 is a rise-3
    # hop and 4 columns across was too demanding for the mandatory key-3
    # path on FADING bridges — 3 across is the stage-4 bridge spacing.
    G.hline(103, 110, 11, "b")
    G.coins((95, 13), (98, 13), (106, 10), (109, 10))
    G.hline(114, 118, 14, "#")
    G.put(116, 13, "U")                   # key 3
    G.hline(119, 158, 19, "#")
    G.rect(119, 20, 158, 22, "@")
    G.put(120, 18, "N")
    G.put(121, 18, "k")
    # hidden vault (energy + shield for the boss)
    G.rect(124, 20, 129, 22, ".")
    G.put(125, 19, ".")
    G.put(126, 19, ".")
    G.coins((125, 21), (127, 21), (128, 21))
    G.put(124, 21, "e")
    G.put(128, 20, "W")
    # elite gauntlet + node 3 + gate 3
    G.coin_row(123, 133, 18, 3)
    G.put(126, 18, "Q")
    # Node 3 shelf at row15 — 64px casual reach (was row14/80px: trick-only
    # and mandatory for the exit gate).
    G.hline(130, 134, 15, "#")
    G.put(132, 14, "N")
    G.put(136, 18, "F")                   # gate 3 guards the boss door
    G.put(137, 18, "k")                   # last checkpoint before the CEO
    # CEO arena. Walls at vline(x, 15, 18) = 64px, the stage-1 pattern:
    # clearable with a plain any-timing double jump. The previous
    # vline(x, 14, 18)/80px "shared pattern" needed the early-press trick
    # to EXIT the arena — and the CEO is not stompable, so after the
    # mandatory kill there was no bounce source: the final room of the
    # final stage was trick-or-nothing.
    G.vline(139, 15, 18, "#")
    G.put(147, 18, "C")
    G.coins((143, 16), (151, 16))
    G.vline(155, 15, 18, "#")
    G.put(157, 18, "E")
    G.top_up([(x, 18) for x in range(5, 24)] + [(x, 18) for x in range(62, 90)]
             + [(x, 17) for x in range(26, 58)] + [(x, 16) for x in range(120, 134)])
    G.save("data/levels/stage_5_map.txt")


if __name__ == "__main__":
    stage_5()
