"""Full-map reachability audit for all 5 stage maps.

Models the player's REAL, empirically measured movement (see
tests/unit/test_shelf_reachability.gd and the v1.12/v1.13 investigations):
  - capsule 24px tall -> needs 2 clear tiles of headroom
  - single jump rise: 3 tiles (48px; real max ~49px)
  - casual double jump rise: 4 tiles (64px; the ~88px figure requires an
    unintuitive early-press trick that mandatory paths must never need)
  - ascent is blocked by overhangs: you cannot rise through/into a shelf
    from directly beneath it (the stage-3 node-2 bug class)
  - connectors: elevators '|', rail movers '=', updrafts '~', fading
    bridges 'b', crumbling glass 'X', one-way '-'
  - firewall gates 'F' are 6-tile-tall blockers until a USB key 'U' is
    collected (one key opens one gate)
  - spikes '^' are lethal: not standable, not passable

BFS from the spawn 'P' and report every objective/pickup/coin that the
model cannot reach. Run: python tools/levelgen/audit_reachability.py
"""
import sys

STAGES = [f"data/levels/stage_{i}_map.txt" for i in range(1, 6)]

SOLID = set("#@")
LETHAL = set("^")
SUPPORT_EXTRA = set("-")           # one-way platforms support from above
PASSABLE_HAZARDS = set("lV<>fg")   # timed/pushing hazards: passable air
SINGLE_RISE = 3                    # tiles (48px)
DOUBLE_RISE = 4                    # tiles (64px, casual timing)
SINGLE_DX = 4                      # same-level gap, single jump
DOUBLE_DX = 7                      # gap with double jump (drop helps)
MOVER_DX = 8                       # dismounting a moving platform


def load(path):
    with open(path, encoding="ascii") as f:
        return [l.rstrip("\n") for l in f if l.strip("\n") != ""]


class Audit:
    def __init__(self, lines):
        self.lines = lines
        self.h = len(lines)
        self.w = max(len(l) for l in lines)
        self.spawn = None
        self.markers = []      # (ch, x, y)
        self.updrafts = []     # (x, y0, y1)
        self.elevators = []    # (x, y0, y1)
        self.mover_cells = set()   # standing cells provided by '=' platforms
        self.support = set()       # extra support cells (X, b tops)
        self._scan()

    def at(self, x, y):
        if 0 <= y < self.h and 0 <= x < len(self.lines[y]):
            return self.lines[y][x]
        return "@"

    def _scan(self):
        seen_vert = set()
        for y in range(self.h):
            for x in range(self.w):
                ch = self.at(x, y)
                if ch == "P":
                    self.spawn = (x, y)
                elif ch in "NUEFkcoeWK":
                    self.markers.append((ch, x, y))
                elif ch in "~|" and (x, y) not in seen_vert:
                    y1 = y
                    while self.at(x, y1 + 1) == ch:
                        y1 += 1
                        seen_vert.add((x, y1))
                    (self.updrafts if ch == "~" else self.elevators).append((x, y, y1))
                elif ch == "=":
                    # platform travels this run: rider stands one tile above
                    self.mover_cells.add((x, y - 1))
                elif ch in "Xb":
                    self.support.add((x, y - 1))
                    if ch == "X":
                        self.support.add((x + 1, y - 1))

    def is_clear(self, x, y):
        ch = self.at(x, y)
        return ch not in SOLID and ch not in LETHAL

    def has_support(self, x, y):
        below = self.at(x, y + 1)
        return below in SOLID or below in SUPPORT_EXTRA or (x, y) in self.support

    def is_standing(self, x, y):
        return (self.is_clear(x, y) and self.is_clear(x, y - 1)
                and self.has_support(x, y)) or (x, y) in self.mover_cells

    def ascent_clear(self, x, y, rise):
        """Can the head rise `rise` tiles straight up from standing (x,y)?"""
        for k in range(1, rise + 1):
            if not self.is_clear(x, y - 1 - k):
                return False
        return True

    def corridor_clear(self, x0, x1, y):
        """2-tile-tall corridor with feet at row y, spanning x0..x1."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            if not (self.is_clear(x, y) and self.is_clear(x, y - 1)):
                return False
        return True

    def descent_clear(self, x, y_from, y_to):
        for y in range(y_from, y_to + 1):
            if not self.is_clear(x, y):
                return False
        return True

    def neighbors(self, x, y, gates_blocked):
        out = []

        def blocked_by_gate(x2, y2):
            for gx, gy in gates_blocked:
                if x2 == gx and gy - 5 <= y2 <= gy:
                    return True
            return False

        def try_add(x2, y2):
            if self.is_standing(x2, y2) and not blocked_by_gate(x2, y2):
                out.append((x2, y2))

        # walk
        for dx in (-1, 1):
            try_add(x + dx, y)
        # jump up (single + casual double), overhang-aware: rise vertically
        # at the origin column, then move sideways at the peak
        for rise in range(1, DOUBLE_RISE + 1):
            if not self.ascent_clear(x, y, rise):
                break
            max_dx = 2 if rise <= SINGLE_RISE else 3
            for dx in range(-max_dx, max_dx + 1):
                x2, y2 = x + dx, y - rise
                if dx != 0 and not self.corridor_clear(x, x2, y2):
                    continue
                try_add(x2, y2)
        # horizontal gap jump at same level or downward
        peak = 2 if self.ascent_clear(x, y, 2) else (1 if self.ascent_clear(x, y, 1) else 0)
        max_gap = DOUBLE_DX if peak >= 1 else 2
        if (x, y) in self.mover_cells:
            max_gap = MOVER_DX
        for dx in range(2, max_gap + 1):
            for sgn in (-1, 1):
                x2 = x + sgn * dx
                if not self.corridor_clear(x, x2, y - peak):
                    break
                for drop in range(0, 12):
                    y2 = y - peak + drop
                    if not self.descent_clear(x2, y2 - 1, y2):
                        break
                    if self.is_standing(x2, y2) and not blocked_by_gate(x2, y2):
                        out.append((x2, y2))
                        break
        # walk off an edge and fall (with 1 tile of drift)
        for dx in (-1, 1):
            x2 = x + dx
            if not (self.is_clear(x2, y) and self.is_clear(x2, y - 1)):
                continue
            if self.has_support(x2, y):
                continue
            yy = y
            while yy < self.h - 1 and self.is_clear(x2, yy + 1) and not self.is_standing(x2, yy):
                yy += 1
            if self.is_standing(x2, yy) and not blocked_by_gate(x2, yy):
                out.append((x2, yy))
        # updrafts: enter near the column, exit at any height alongside it
        for ux, uy0, uy1 in self.updrafts:
            if abs(x - ux) <= 1 and uy0 - 1 <= y <= uy1 + 2:
                for ey in range(uy0 - 1, uy1 + 2):
                    for ex in (ux - 2, ux - 1, ux, ux + 1, ux + 2):
                        try_add(ex, ey)
        # elevators: board near the bottom, dismount near the top
        for ex_, ey0, ey1 in self.elevators:
            if abs(x - ex_) <= 1 and ey1 - 2 <= y <= ey1 + 2:
                for ty in range(ey0 - 2, ey0 + 2):
                    for tx in range(ex_ - 3, ex_ + 4):
                        try_add(tx, ty)
        return out

    def run(self):
        assert self.spawn, "no spawn marker"
        sx, sy = self.spawn
        # spawn may be drawn mid-air; settle to the floor
        while not self.is_standing(sx, sy) and sy < self.h - 1:
            sy += 1
        gates = [(x, y) for ch, x, y in self.markers if ch == "F"]
        keys = [(x, y) for ch, x, y in self.markers if ch == "U"]
        opened = set()
        reached = set()
        while True:
            gates_blocked = [g for g in gates if g not in opened]
            frontier = [(sx, sy)]
            reached = {(sx, sy)}
            while frontier:
                cx, cy = frontier.pop()
                for nb in self.neighbors(cx, cy, gates_blocked):
                    if nb not in reached:
                        reached.add(nb)
                        frontier.append(nb)
            keys_have = sum(1 for kx, ky in keys if self._near(reached, kx, ky))
            can_open = keys_have - len(opened)
            if can_open <= 0:
                break
            # open the reachable-adjacent gates first
            progressed = False
            for g in gates_blocked:
                if can_open <= 0:
                    break
                gx, gy = g
                if any(abs(rx - gx) <= 2 and abs(ry - gy) <= 5 for rx, ry in reached):
                    opened.add(g)
                    can_open -= 1
                    progressed = True
            if not progressed:
                break
        return reached

    @staticmethod
    def _near(reached, mx, my, r=2):
        return any(abs(rx - mx) <= r and -1 <= my - ry + 3 <= 6 and abs(ry - my) <= 3
                   for rx, ry in reached)

    def report(self, name):
        reached = self.run()
        problems = []
        for ch, x, y in self.markers:
            if not self._near(reached, x, y):
                problems.append((ch, x, y))
        mandatory = [p for p in problems if p[0] in "NUEF"]
        minor = [p for p in problems if p[0] not in "NUEF"]
        print(f"== {name}: {len(reached)} standing cells reached ==")
        if not problems:
            print("   all objectives, pickups and coins reachable")
        for ch, x, y in mandatory:
            print(f"   BLOCKED (mandatory): '{ch}' at col {x}, row {y}")
        if minor:
            coins = [p for p in minor if p[0] == "c"]
            other = [p for p in minor if p[0] != "c"]
            for ch, x, y in other:
                print(f"   blocked (optional): '{ch}' at col {x}, row {y}")
            if coins:
                print(f"   blocked coins: {[(x, y) for _, x, y in coins]}")
        return len(mandatory)


def main():
    total = 0
    for path in STAGES:
        total += Audit(load(path)).report(path)
    if total:
        print(f"\n{total} MANDATORY objective(s) unreachable")
        sys.exit(1)
    print("\nAll stages: every mandatory objective reachable")


if __name__ == "__main__":
    main()