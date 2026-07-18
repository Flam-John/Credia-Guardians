"""Compose Stage 2 (Data Center), 3 (Corporate HQ), 4 (Digital Vault) maps.

Outputs data/levels/stage_N_map.txt. Legend in src/levels/level_base.gd.
Geometry rules verified in the Stage-1 playability audit: single jump clears
2.5 tiles up / 5 tiles across; double jump 5.5 up; movers alternate phase.
Re-run: python tools/levelgen/stages_2_4_layout.py
"""
WIDTH, HEIGHT = 160, 24


class Grid:
    def __init__(self):
        self.g = [[" " for _ in range(WIDTH)] for _ in range(HEIGHT)]
        self.coin_count = 0
        # shell
        self.hline(0, WIDTH - 1, 0, "@")
        self.vline(0, 0, HEIGHT - 1, "@")
        self.vline(WIDTH - 1, 0, HEIGHT - 1, "@")
        self.hline(1, WIDTH - 2, 23, "@")

    def put(self, x, y, ch):
        if self.g[y][x] == "c":
            self.coin_count -= 1  # overwriting a coin un-counts it
        if ch == "c":
            self.coin_count += 1
        self.g[y][x] = ch

    def hline(self, x0, x1, y, ch):
        for x in range(x0, x1 + 1):
            self.put(x, y, ch)

    def vline(self, x, y0, y1, ch):
        for y in range(y0, y1 + 1):
            self.put(x, y, ch)

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            self.hline(x0, x1, y, ch)

    def coins(self, *pts):
        for x, y in pts:
            self.put(x, y, "c")

    def coin_row(self, x0, x1, y, step=2):
        for x in range(x0, x1 + 1, step):
            self.put(x, y, "c")

    def top_up(self, spares):
        """Add coins from the spare list until exactly 100."""
        i = 0
        while self.coin_count < 100 and i < len(spares):
            x, y = spares[i]
            if self.g[y][x] == " ":
                self.put(x, y, "c")
            i += 1
        assert self.coin_count == 100, f"coins={self.coin_count} (spares exhausted)"

    def save(self, path):
        out = "\n".join("".join(row) for row in self.g) + "\n"
        with open(path, "w", encoding="ascii") as f:
            f.write(out)
        print(path, "coins:", self.coin_count)


def stage_2():
    """Data Center: heat vents, fan shaft, rail movers, AI Banker MK-II."""
    G = Grid()
    # spawn strip
    G.hline(1, 24, 19, "#")
    G.rect(1, 20, 24, 22, "@")
    G.put(3, 18, "P")
    G.coin_row(6, 14, 18)
    G.put(18, 18, "J")
    # heat vent corridor
    G.hline(25, 52, 19, "#")
    G.rect(25, 20, 52, 22, "@")
    for vx in (28, 36, 44):
        G.vline(vx, 14, 18, "V")
    G.coin_row(26, 50, 18, 4)
    G.coins((32, 16), (40, 16), (48, 16))
    G.put(31, 18, "m")
    G.put(46, 18, "k")
    G.put(50, 18, "N")
    # fan shaft over pit (fans push you across the gap)
    G.hline(53, 56, 19, "#")
    G.rect(53, 20, 56, 22, "@")
    G.rect(57, 22, 76, 22, "#")          # pit bottom
    G.hline(62, 70, 21, "^")             # spike run with safe strips both ends
    G.hline(63, 65, 17, "#")             # stepping stones across (audit fix:
    G.hline(69, 71, 17, "#")             #   damage-free crossing must exist)
    G.hline(57, 62, 16, "g")             # fan assists the first hop
    G.hline(60, 63, 14, "#")             # reward ledge (80px rise = reachable)
    G.coins((60, 13), (62, 13), (61, 12))
    G.coins((64, 16), (70, 16), (74, 15))
    G.hline(77, 158, 19, "#")
    G.rect(77, 20, 158, 22, "@")
    # hidden vault 1 under floor
    G.rect(80, 20, 86, 22, ".")
    G.put(81, 19, ".")
    G.put(82, 19, ".")
    G.coin_row(81, 85, 21, 1)
    G.put(84, 20, "o")
    # rail movers over second spike pit
    G.put(88, 18, "k")
    G.rect(90, 19, 108, 19, " ")         # carve the gap in the floor
    G.rect(90, 20, 108, 22, " ")
    G.rect(90, 22, 108, 22, "#")
    G.hline(92, 106, 21, "^")
    G.hline(90, 97, 15, "=")
    G.hline(100, 107, 12, "=")
    G.coins((92, 14), (95, 14), (102, 11), (105, 11), (98, 9), (99, 9))
    G.put(110, 18, "N")
    G.put(109, 18, "m")
    # server maze
    G.coin_row(112, 124, 18, 3)
    G.put(118, 18, "A")
    G.put(122, 18, "J")
    G.hline(114, 132, 14, "#")
    G.coin_row(115, 131, 13, 2)
    G.put(126, 13, "J")
    G.put(130, 13, "e")
    G.vline(133, 10, 13, "V")
    G.put(135, 13, "N")
    G.hline(133, 137, 14, "#")
    # mid-boss arena: AI Banker MK-II
    G.put(139, 18, "k")
    G.vline(141, 14, 18, "#")
    G.put(148, 12, "Q")
    G.coins((145, 17), (151, 17))
    G.vline(155, 14, 18, "#")
    G.put(153, 18, "m")
    G.put(157, 18, "E")
    G.top_up([(x, 18) for x in range(5, 24)] + [(x, 18) for x in range(112, 133)]
             + [(x, 17) for x in range(26, 52)] + [(x, 17) for x in range(78, 88)]
             + [(x, 16) for x in range(112, 133)])
    G.save("data/levels/stage_2_map.txt")


def stage_3():
    """Corporate HQ: elevators, glass floors, cameras, Regional Manager."""
    G = Grid()
    # marble lobby
    G.hline(1, 28, 19, "#")
    G.rect(1, 20, 28, 22, "@")
    G.put(3, 18, "P")
    G.coin_row(6, 16, 18)
    G.put(20, 18, "J")
    G.put(12, 16, "m")
    # elevator shaft up to mezzanine
    G.hline(29, 40, 19, "#")
    G.rect(29, 20, 40, 22, "@")
    G.vline(33, 9, 18, "|")
    G.hline(36, 60, 8, "#")              # mezzanine level
    G.coin_row(38, 58, 7, 2)
    G.put(42, 7, "N")
    G.put(56, 7, "k")
    G.coin_row(30, 40, 18, 3)
    # glass floors over spikes (ground route)
    G.hline(41, 70, 19, "#")
    G.rect(41, 20, 70, 22, "@")
    G.rect(46, 19, 66, 19, " ")          # carve gap: glass crossing
    G.rect(46, 20, 66, 22, " ")
    G.rect(46, 22, 66, 22, "#")
    G.hline(48, 64, 21, "^")
    for gx in (47, 52, 57, 62):
        G.put(gx, 16, "X")               # crumbling glass panes
    G.coins((49, 15), (54, 15), (59, 15), (64, 15))
    G.put(50, 10, "S")                   # camera watches the crossing
    # shredder corridor (lasers at ankle height)
    G.hline(71, 158, 19, "#")
    G.rect(71, 20, 158, 22, "@")
    G.hline(74, 79, 18, "l")
    G.hline(86, 91, 18, "l")
    G.coin_row(72, 96, 17, 3)
    G.put(83, 18, "o")
    G.put(93, 18, "L")
    G.put(97, 18, "k")
    G.put(99, 18, "m")
    # hidden vault 1 under the corridor. Entrance holes at cols101-102:
    # NOTHING solid may ever be drawn in the two rows above them (the
    # v1.13 staircase did exactly that and sealed the vault — 16px of
    # clearance vs the 24px capsule, and no drop-in from above either;
    # test_stage_completability now guards every vault entrance).
    G.rect(100, 20, 105, 22, ".")
    G.put(101, 19, ".")
    G.put(102, 19, ".")
    G.coin_row(101, 104, 21, 1)
    G.put(103, 20, "W")
    # office two-level block
    G.coin_row(107, 121, 18, 3)
    G.put(112, 18, "A")
    G.put(119, 18, "J")
    # Shelf sits at row15 — 64px above the floor, reachable with a plain
    # double jump at ANY timing. Its original row14 (80px) needed an
    # unintuitive early-press double jump (players reported the node
    # unreachable), and the v1.13 attempt to keep 80px by adding a
    # staircase read as ugly floating crates in-game AND sealed hidden
    # vault 1's entrance holes below (user feedback: remove the stairs).
    # Nothing solid may ever be drawn above cols101-102 (the vault holes)
    # or in the approach air left of col108 — test_stage_completability
    # and test_shelf_reachability guard both.
    G.hline(108, 136, 15, "#")
    G.coin_row(109, 133, 14, 2)
    G.put(114, 10, "S")
    G.put(126, 14, "J")
    G.put(131, 14, "e")
    G.put(135, 14, "N")
	# hidden vault 2 under offices
    G.rect(122, 20, 127, 22, ".")
    G.put(123, 19, ".")
    G.put(124, 19, ".")
    G.coins((123, 21), (125, 21), (126, 21), (124, 20))
    G.put(122, 21, "o")
    # USB key right next to node 3's shelf-mate (node 2, col135) — the F
    # gate blocks the exit without it, and the critical path must never
    # require finding a hidden room. Originally sat at col110, 25 tiles
    # from node 2 on the same walkway: reachable, but a player who
    # double-jumps up and beelines for the visible glowing node has no
    # reason to walk back to the far end of the shelf first, and gets
    # softlocked at the firewall gate with no way back to an earlier
    # section. One tile from the node it can no longer be missed by
    # anyone who collects the (mandatory) node itself.
    G.put(134, 14, "U")
    # Regional Manager arena. Node 3 stands IN the arena (col151), clearly
    # visible — it originally sat at col156, squeezed between the firewall
    # gate (col155) and exit gate (col157): both gate props are 64px-wide
    # discs, so the two overlapped each other and buried the node behind
    # their art. Players saw no third node anywhere (user screenshot).
    # The firewall gate now guards only the exit, like stage 5's.
    G.put(138, 18, "k")
    G.vline(140, 14, 18, "#")
    G.put(147, 18, "R")
    G.coins((144, 16), (150, 16))
    G.put(151, 18, "N")
    G.vline(153, 14, 18, "#")
    G.put(155, 18, "F")
    G.put(157, 18, "E")
    G.top_up([(x, 18) for x in range(5, 27)] + [(x, 18) for x in range(72, 96)]
             + [(x, 7) for x in range(37, 59)] + [(x, 17) for x in range(107, 133)]
             + [(x, 18) for x in range(41, 45)])
    G.save("data/levels/stage_3_map.txt")


def stage_4():
    """Digital Vault: laser grids, fading bridges, key gates, wave arena."""
    G = Grid()
    # vault entry
    G.hline(1, 22, 19, "#")
    G.rect(1, 20, 22, 22, "@")
    G.put(3, 18, "P")
    G.coin_row(6, 14, 18)
    G.put(17, 18, "J")
    G.put(10, 16, "m")
    # laser lattice
    G.hline(23, 55, 19, "#")
    G.rect(23, 20, 55, 22, "@")
    G.hline(26, 31, 18, "l")
    G.hline(35, 40, 18, "l")
    G.hline(44, 49, 18, "l")
    G.hline(30, 36, 14, "#")             # hop-over shelf
    G.coin_row(30, 36, 13, 2)
    G.coin_row(24, 54, 17, 4)
    G.put(52, 18, "k")
    G.put(54, 18, "N")
    # fading-bridge crossing
    G.rect(56, 22, 88, 22, "#")          # deep pit
    G.hline(58, 83, 21, "^")             # east strip 84-88 spike-free (audit)
    G.hline(56, 63, 15, "b")
    G.hline(66, 73, 12, "b")
    G.hline(76, 83, 15, "b")
    G.coins((58, 14), (61, 14), (68, 11), (71, 11), (78, 14), (81, 14),
            (69, 8), (70, 8))
    G.hline(89, 158, 19, "#")
    G.rect(89, 20, 158, 22, "@")
    G.put(90, 18, "k")
    # key vault: U behind lasers, F gates N2 + treasure. Shelf at row15 —
    # 64px above the floor, a plain any-timing double jump (same reason as
    # stage 3's node-2 shelf: 80px needed an early-press trick, and the
    # v1.13 staircase workaround looked like floating crates in-game,
    # sealed the col-90 checkpoint, and trapped the (92,18) coin — user
    # feedback: no stairs). Keep cols 90-94 free of solid tiles: the
    # checkpoint lives at col90 and the shelf approach jump needs the air.
    G.coin_row(92, 104, 18, 3)
    G.hline(95, 99, 15, "#")
    G.put(97, 14, "U")
    G.hline(94, 96, 18, "l")
    G.put(106, 18, "F")
    G.put(109, 18, "N")
    G.coins((111, 18), (112, 18), (113, 18))
    G.put(115, 18, "m")
    # hidden vault 1 under key section
    G.rect(100, 20, 105, 22, ".")
    G.put(101, 19, ".")
    G.put(102, 19, ".")
    G.coin_row(101, 104, 21, 1)
    G.put(103, 20, "o")
    # elite corridor
    G.coin_row(117, 129, 18, 3)
    G.put(120, 18, "L")
    G.put(125, 18, "A")
    G.hline(118, 134, 13, "#")
    G.coin_row(119, 133, 12, 2)
    G.put(128, 8, "Q")
    G.put(131, 12, "e")
	# hidden vault 2
    G.rect(135, 20, 139, 22, ".")
    G.put(136, 19, ".")
    G.put(137, 19, ".")
    G.coins((136, 21), (137, 21), (138, 21))
    G.put(135, 21, "W")
    G.put(136, 13, "N")
    G.hline(135, 138, 14, "#")
    # wave gauntlet arena
    G.put(140, 18, "k")
    G.vline(142, 14, 18, "#")
    G.put(146, 18, "M")
    G.put(150, 18, "M")
    G.put(148, 18, "J")
    G.coins((145, 16), (149, 16), (152, 16))
    G.vline(154, 14, 18, "#")
    G.put(157, 18, "E")
    G.top_up([(x, 18) for x in range(5, 21)] + [(x, 17) for x in range(24, 54)]
             + [(x, 18) for x in range(117, 133)] + [(x, 17) for x in range(90, 105)]
             + [(x, 12) for x in range(119, 134)])
    G.save("data/levels/stage_4_map.txt")


if __name__ == "__main__":
    stage_2()
    stage_3()
    stage_4()
