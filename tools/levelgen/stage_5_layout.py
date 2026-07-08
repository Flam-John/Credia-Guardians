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
    G.hline(50, 54, 14, "#")
    G.put(52, 13, "U")                    # key 1 (visible shelf)
    G.put(57, 18, "k")
    G.put(59, 18, "F")                    # gate 1
    # vertical steam climb with vents, key 2
    G.hline(61, 92, 19, "#")
    G.rect(61, 20, 92, 22, "@")
    G.vline(66, 9, 18, "~")
    G.vline(76, 9, 18, "V")
    G.vline(86, 9, 18, "~")
    G.hline(63, 69, 8, "#")
    G.hline(73, 79, 8, "#")
    G.hline(83, 89, 8, "#")
    G.coin_row(64, 88, 7, 3)
    G.put(76, 7, "U")                     # key 2 (atop the vent column)
    G.put(64, 7, "N")
    G.coin_row(63, 91, 15, 4)
    G.put(70, 18, "L")
    G.put(82, 18, "o")
    G.put(90, 18, "k")
    G.put(91, 18, "F")                    # gate 2
    # fading bridges over corruption pit + key 3
    G.rect(93, 22, 118, 22, "#")
    G.hline(95, 113, 21, "^")
    G.hline(93, 100, 14, "b")
    G.hline(104, 111, 11, "b")
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
    G.hline(130, 134, 14, "#")
    G.put(132, 13, "N")
    G.put(136, 18, "F")                   # gate 3 guards the boss door
    G.put(137, 18, "k")                   # last checkpoint before the CEO
    # CEO arena
    G.vline(139, 13, 18, "#")
    G.put(147, 18, "C")
    G.coins((143, 16), (151, 16))
    G.vline(155, 13, 18, "#")
    G.put(157, 18, "E")
    G.top_up([(x, 18) for x in range(5, 24)] + [(x, 18) for x in range(62, 90)]
             + [(x, 17) for x in range(26, 58)] + [(x, 16) for x in range(120, 134)])
    G.save("data/levels/stage_5_map.txt")


if __name__ == "__main__":
    stage_5()
