"""Generate placeholder sprite sheets, tiles, and props for Credia Guardians.

Deterministic (no randomness): re-running always produces identical PNGs.
Layouts must match docs/ANIMATION_LIST.md — the runtime SpriteFrames builder
(src/util/sprite_frames_builder.gd) slices sheets by the same row table.

Usage:  python tools/artgen/generate_placeholders.py [--out assets/art]
"""
from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

FRAME = 32  # player frame size
SHEET_COLS = 8

# (name, frames) — row index = position in this list. Must match
# docs/ANIMATION_LIST.md and sprite_frames_builder.gd PLAYER_ANIMS.
PLAYER_ANIMS = [
    ("idle", 4), ("run", 8), ("jump", 2), ("fall", 2),
    ("double_jump", 4), ("dash", 3), ("attack_1", 4), ("attack_2", 4),
    ("attack_3", 5), ("air_attack", 4), ("hurt", 2), ("death", 6),
    ("ability", 3), ("victory", 4), ("interact", 2), ("spawn", 4),
]


def _px(draw: ImageDraw.ImageDraw, x: int, y: int, c) -> None:
    draw.point((x, y), fill=c)


def _rect(draw, x0, y0, x1, y1, c):
    draw.rectangle([x0, y0, x1, y1], fill=c)


def _outline_rect(draw, x0, y0, x1, y1, fill, outline=P.OUTLINE):
    draw.rectangle([x0, y0, x1, y1], fill=fill, outline=outline)


def draw_hero_frame(draw, ox: int, oy: int, anim: str, i: int, hair, long_hair: bool):
    """One 32x32 hero frame at sheet offset (ox, oy).

    Simple articulated placeholder: head + suit torso + legs + arm, with
    per-animation offsets so timing/feel is testable before real art.
    """
    cx = ox + 16  # frame center x
    bob = [0, 1, 0, -1][i % 4] if anim in ("idle", "victory", "ability") else 0
    lean = 0
    leg_l, leg_r = 0, 0  # forward/back offsets
    arm_y, arm_len = 15, 4
    body_top = 12 + bob

    if anim == "run":
        phase = i % 8
        swing = [3, 2, 0, -2, -3, -2, 0, 2][phase]
        leg_l, leg_r = swing, -swing
        lean = 1
        arm_len = 5
    elif anim in ("jump", "double_jump", "spawn"):
        leg_l, leg_r = 2, -2
        body_top -= 1
    elif anim == "fall":
        leg_l, leg_r = 1, -1
        body_top += 1
    elif anim == "dash":
        lean = 3
        leg_l, leg_r = 4, -4
        arm_len = 6
    elif anim.startswith("attack") or anim == "air_attack":
        arm_len = [2, 8, 8, 4, 3][min(i, 4)]  # windup, hit, hit, recover
        arm_y = 14
    elif anim == "hurt":
        lean = -2
    elif anim == "death":
        # progressively tips over
        lean = -(i * 2)
        body_top += i
    elif anim == "interact":
        arm_len = 7
        arm_y = 10 + (i % 2)

    body_top = min(body_top, 24)
    # legs (suit)
    _rect(draw, cx - 4 + leg_l // 2, oy + 22, cx - 2 + leg_l // 2, oy + 29, P.SUIT)
    _rect(draw, cx + 1 + leg_r // 2, oy + 22, cx + 3 + leg_r // 2, oy + 29, P.SUIT)
    # boots (green glow soles)
    _rect(draw, cx - 4 + leg_l // 2, oy + 29, cx - 2 + leg_l // 2, oy + 30, P.GREEN_DARK)
    _rect(draw, cx + 1 + leg_r // 2, oy + 29, cx + 3 + leg_r // 2, oy + 30, P.GREEN_DARK)
    # torso (suit with green chest line)
    _outline_rect(draw, cx - 5 + lean, oy + body_top, cx + 5 + lean, oy + 22, P.SUIT)
    _rect(draw, cx - 1 + lean, oy + body_top + 2, cx + lean, oy + 20, P.GREEN)
    # chest coin logo (blue/green)
    _px(draw, cx - 3 + lean, oy + body_top + 3, P.BLUE)
    _px(draw, cx - 2 + lean, oy + body_top + 3, P.GREEN)
    # arm
    _rect(draw, cx + 4 + lean, oy + arm_y, cx + 4 + lean + arm_len, oy + arm_y + 2, P.SUIT)
    if anim.startswith("attack") or anim == "air_attack":
        # melee swoosh at arm tip
        _rect(draw, cx + 5 + lean + arm_len, oy + arm_y - 2, cx + 6 + lean + arm_len,
              oy + arm_y + 4, P.CYAN)
    # head
    head_y = oy + body_top - 8
    _outline_rect(draw, cx - 4 + lean, head_y, cx + 4 + lean, head_y + 7, P.SKIN)
    # hair
    _rect(draw, cx - 4 + lean, head_y, cx + 4 + lean, head_y + 2, hair)
    if long_hair:
        _rect(draw, cx - 5 + lean, head_y + 1, cx - 4 + lean, head_y + 9 + (i % 2), hair)
    # visor eyes (green)
    _px(draw, cx + 1 + lean, head_y + 4, P.GREEN)
    _px(draw, cx + 3 + lean, head_y + 4, P.GREEN)

    if anim == "ability":
        # Chris: shield shimmer arc / Flam: charge glow — generic cyan arc
        for dy in range(-2, 14, 2):
            _px(draw, cx + 8 + (i % 2), oy + 8 + dy, P.CYAN)
    if anim == "hurt":
        _px(draw, cx - 7, oy + 8, P.RED)
        _px(draw, cx + 7, oy + 6, P.RED)
    if anim == "victory":
        # raised fist
        _rect(draw, cx + 4, oy + 4 + bob, cx + 6, oy + 12, P.SUIT)
        _px(draw, cx + 5, oy + 3 + bob, P.GREEN)


def gen_player_sheet(path: str, hair, long_hair: bool):
    sheet = Image.new("RGBA", (SHEET_COLS * FRAME, len(PLAYER_ANIMS) * FRAME), P.TRANSPARENT)
    draw = ImageDraw.Draw(sheet)
    for row, (anim, frames) in enumerate(PLAYER_ANIMS):
        for i in range(frames):
            draw_hero_frame(draw, i * FRAME, row * FRAME, anim, i, hair, long_hair)
    sheet.save(path)


def gen_portraits(path: str):
    img = Image.new("RGBA", (64, 32), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for idx, hair in enumerate((P.CHRIS_HAIR, P.FLAM_HAIR)):
        ox = idx * 32
        _outline_rect(d, ox + 2, 2, ox + 29, 29, P.BG_PANEL, P.GREEN_DARK)
        _outline_rect(d, ox + 9, 8, ox + 22, 24, P.SKIN)
        _rect(d, ox + 9, 8, ox + 22, 12, hair)
        if idx == 1:  # Flam long hair
            _rect(d, ox + 7, 10, ox + 9, 26, hair)
        _rect(d, ox + 12, 16, ox + 13, 17, P.GREEN)
        _rect(d, ox + 18, 16, ox + 19, 17, P.GREEN)
    img.save(path)


def gen_coin(path: str):
    """6-frame spin of the blue/green yin-yang Credia coin, 16x16."""
    img = Image.new("RGBA", (96, 16), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    widths = [12, 8, 4, 2, 4, 8]  # apparent width per frame
    for i, w in enumerate(widths):
        cx = i * 16 + 8
        x0, x1 = cx - w // 2, cx + w // 2
        d.ellipse([x0, 2, x1, 14], fill=P.BLUE, outline=P.OUTLINE)
        if w > 3:
            d.chord([x0, 2, x1, 14], 90, 270, fill=P.GREEN)
        if i == 0:
            _px(d, cx - 3, 4, P.WHITE)  # glint
    img.save(path)


def gen_tileset(path: str):
    """256x256 tileset. Row 0 holds the core gameplay tiles at fixed coords
    used by AsciiRoomBuilder: 0 solid-top, 1 solid-interior, 2 bg panel,
    3 spike hazard, 4 one-way platform, 5 solid-left-edge, 6 solid-right-edge.
    """
    img = Image.new("RGBA", (256, 256), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    t = 16

    def tile(ix, iy):
        return ix * t, iy * t

    # 0: solid with green light strip on top
    x, y = tile(0, 0)
    _rect(d, x, y, x + 15, y + 15, P.BG_PANEL)
    _rect(d, x, y, x + 15, y + 1, P.GREEN_DARK)
    _rect(d, x, y, x + 15, y, P.GREEN)
    for i in range(0, 16, 4):
        _px(d, x + i, y + 8, P.GRAY_DARK)
    # 1: solid interior
    x, y = tile(1, 0)
    _rect(d, x, y, x + 15, y + 15, P.BG_PANEL)
    for i in range(0, 16, 4):
        _px(d, x + i + 2, y + 4, P.GRAY_DARK)
        _px(d, x + i, y + 12, P.GRAY_DARK)
    # 2: background panel (no collision) — darker
    x, y = tile(2, 0)
    _rect(d, x, y, x + 15, y + 15, P.BG_VOID)
    d.rectangle([x + 2, y + 2, x + 13, y + 13], outline=P.BG_PANEL)
    # 3: spike hazard (red)
    x, y = tile(3, 0)
    for s in range(4):
        sx = x + s * 4
        d.polygon([(sx, y + 15), (sx + 2, y + 8), (sx + 3, y + 15)], fill=P.RED)
    # 4: one-way platform
    x, y = tile(4, 0)
    _rect(d, x, y + 2, x + 15, y + 5, P.BLUE_DEEP)
    _rect(d, x, y + 2, x + 15, y + 2, P.CYAN)
    # 5/6: solid left/right edge lit
    for ix, edge_x in ((5, 0), (6, 15)):
        x, y = tile(ix, 0)
        _rect(d, x, y, x + 15, y + 15, P.BG_PANEL)
        _rect(d, x + edge_x, y, x + edge_x, y + 15, P.GREEN_DARK)
    img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/art")
    args = ap.parse_args()
    out = args.out
    os.makedirs(f"{out}/characters", exist_ok=True)
    os.makedirs(f"{out}/tiles", exist_ok=True)
    os.makedirs(f"{out}/props", exist_ok=True)

    gen_player_sheet(f"{out}/characters/chris_sheet.png", P.CHRIS_HAIR, False)
    gen_player_sheet(f"{out}/characters/flam_sheet.png", P.FLAM_HAIR, True)
    gen_portraits(f"{out}/characters/portraits.png")
    gen_coin(f"{out}/props/coin.png")
    gen_tileset(f"{out}/tiles/tileset_office.png")
    print("placeholder art generated ->", out)


if __name__ == "__main__":
    main()
