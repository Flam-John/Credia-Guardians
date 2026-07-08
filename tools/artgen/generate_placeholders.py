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
    is_attack = anim.startswith("attack") or anim == "air_attack"
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
    elif is_attack:
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
    if is_attack:
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


# Enemy sheet layouts: (anim name, frames) per row. MUST match
# SpriteFramesBuilder.ENEMY_LAYOUTS in src/util/sprite_frames_builder.gd.
ENEMY_LAYOUTS = {
    "junior_banker": {
        "size": 24,
        "anims": [("walk", 4), ("panic_run", 4), ("death", 3)],
    },
    "angry_manager": {
        "size": 32,
        "anims": [("idle", 2), ("alert", 2), ("charge", 4),
                  ("wall_stun", 3), ("death", 3)],
    },
    "auditor": {
        "size": 32,
        "anims": [("idle", 2), ("hop_back", 3), ("throw", 4), ("death", 3)],
    },
    "loan_shark": {
        "size": 40,
        "anims": [("hidden_fin", 2), ("emerge", 3), ("lunge", 3),
                  ("recover", 2), ("death", 4)],
    },
    "ai_banker": {
        "size": 48,
        "anims": [("float", 4), ("teleport_out", 3), ("teleport_in", 3),
                  ("cast", 4), ("stagger", 2), ("death", 5)],
    },
}


def draw_special_enemy_frame(d, ox, oy, size, kind, anim, i):
    """Auditor (glasses, ledger hat), Loan Shark (fin, pinstripes),
    AI Banker (glitch hologram)."""
    cx = ox + size // 2
    bottom = oy + size - 2
    bob = i % 2
    if kind == "auditor":
        # spiked ledger hat (anti-stomp tell)
        hat_y = bottom - 22 + bob
        for s in range(3):
            d.polygon([(cx - 5 + s * 4, hat_y), (cx - 3 + s * 4, hat_y - 4),
                       (cx - 1 + s * 4, hat_y)], fill=P.GRAY_DARK)
        _outline_rect(d, cx - 3, hat_y, cx + 3, hat_y + 6, P.SKIN)
        _px(d, cx - 2, hat_y + 2, P.CYAN)  # glasses glint
        _px(d, cx + 1, hat_y + 2, P.CYAN)
        _outline_rect(d, cx - 4, hat_y + 7, cx + 4, bottom - 6, P.GRAY)
        _rect(d, cx - 1, hat_y + 8, cx, bottom - 8, P.RED)
        legs = [1, -1][i % 2] if anim == "hop_back" else 0
        _rect(d, cx - 3 + legs, bottom - 6, cx - 1 + legs, bottom, P.GRAY_DARK)
        _rect(d, cx + 1 - legs, bottom - 6, cx + 3 - legs, bottom, P.GRAY_DARK)
        if anim == "throw":
            arm = [2, 5, 8, 4][i]
            _rect(d, cx + 4, hat_y + 9, cx + 4 + arm, hat_y + 11, P.GRAY)
            if i == 2:
                _outline_rect(d, cx + 9, hat_y + 6, cx + 13, hat_y + 10, P.WHITE)
        if anim == "death":
            _px(d, cx - 6, hat_y - 2, P.GOLD)
            _px(d, cx + 6, hat_y - 3, P.GOLD)
    elif kind == "loan_shark":
        if anim == "hidden_fin":
            d.polygon([(cx - 3, bottom), (cx, bottom - 6 - bob), (cx + 3, bottom)],
                      fill=P.GRAY_DARK)
            return
        rise = {"emerge": [12, 20, 26], "lunge": [28, 30, 28],
                "recover": [24, 22], "death": [22, 16, 10, 4]}[anim][i]
        body_top = bottom - rise
        if body_top + 8 < bottom:  # sinking death frames may have no suit left
            _outline_rect(d, cx - 7, body_top + 8, cx + 7, bottom, P.GRAY)
            for stripe in range(cx - 5, cx + 6, 4):  # pinstripes
                for y in range(body_top + 9, bottom - 1, 3):
                    _px(d, stripe, y, P.GRAY_DARK)
        # shark head
        d.polygon([(cx - 8, body_top + 10), (cx + 2, body_top - 2),
                   (cx + 9, body_top + 10)], fill=(96, 120, 140, 255))
        _px(d, cx + 3, body_top + 4, P.OUTLINE)  # eye
        if anim == "lunge":
            for t in range(cx - 4, cx + 5, 3):  # teeth
                d.polygon([(t, body_top + 9), (t + 1, body_top + 6),
                           (t + 2, body_top + 9)], fill=P.WHITE)
        if anim == "death":
            _px(d, cx - 9, body_top, P.GOLD)
            _px(d, cx + 9, body_top - 1, P.GOLD)
    else:  # ai_banker: glitching hologram
        top = oy + 6 + bob
        glitch = [0, 2, -2][i % 3] if anim in ("teleport_out", "teleport_in") else 0
        alpha_body = P.BLUE if anim != "stagger" else P.RED
        _outline_rect(d, cx - 8 + glitch, top + 14, cx + 8 - glitch, bottom - 4,
                      (20, 60, 120, 255))
        _rect(d, cx - 1, top + 15, cx, bottom - 6, P.CYAN)  # tie line
        _outline_rect(d, cx - 5, top, cx + 5, top + 12, (30, 80, 150, 255))
        _px(d, cx - 2, top + 5, alpha_body)
        _px(d, cx + 2, top + 5, alpha_body)
        # scanline glitches
        for g in range(3):
            gy = top + 4 + g * 10 + (i * 3) % 7
            _rect(d, cx - 9, gy, cx + 9, gy, (22, 224, 224, 120))
        if anim == "cast" and i >= 2:
            for orb in (-12, 0, 12):
                _px(d, cx + orb, top - 3, P.RED)
        if anim == "death":
            for s in range(i + 1):
                _px(d, cx - 8 + s * 4, bottom - 2 - (s * 5) % 14, P.CYAN)


def gen_special_enemy_sheets(out_dir):
    for name in ("auditor", "loan_shark", "ai_banker"):
        spec = ENEMY_LAYOUTS[name]
        size = spec["size"]
        cols = max(f for _, f in spec["anims"])
        img = Image.new("RGBA", (cols * size, len(spec["anims"]) * size), P.TRANSPARENT)
        d = ImageDraw.Draw(img)
        for row, (anim, frames) in enumerate(spec["anims"]):
            for i in range(frames):
                draw_special_enemy_frame(d, i * size, row * size, size, name, anim, i)
        img.save(f"{out_dir}/{name}.png")


def gen_projectiles(path):
    """8x8 x2: ledger (white page), plasma orb (red)."""
    img = Image.new("RGBA", (16, 8), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    _outline_rect(d, 1, 1, 6, 6, P.WHITE)
    _px(d, 3, 3, P.GRAY_DARK)
    _px(d, 3, 4, P.GRAY_DARK)
    d.ellipse([9, 1, 14, 6], fill=P.RED, outline=(120, 10, 30, 255))
    img.save(path)


def gen_monitors(path):
    """32x24 x2: propaganda (red text) / positive (green text)."""
    img = Image.new("RGBA", (64, 24), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, col in enumerate((P.RED, P.GREEN)):
        ox = i * 32
        _outline_rect(d, ox + 2, 2, ox + 29, 20, P.GRAY_DARK)
        _rect(d, ox + 4, 4, ox + 27, 18, P.BG_VOID)
        for line in range(3):
            _rect(d, ox + 6, 6 + line * 4, ox + 6 + (14 - line * 3), 7 + line * 4, col)
        _rect(d, ox + 13, 20, ox + 18, 22, P.GRAY_DARK)  # stand
    img.save(path)


def draw_banker_frame(d, ox, oy, size, anim, i, tie_color):
    """Comedic suited banker placeholder. Gray suit, red tie (corruption)."""
    cx = ox + size // 2
    bottom = oy + size - 2
    bob = i % 2
    lean = 0
    legs = [1, -1, 2, -2][i % 4] if anim in ("walk", "panic_run", "charge") else 0
    if anim == "charge":
        lean = 3
    if anim == "panic_run":
        lean = -2
        bob = i % 2 * 2
    if anim == "death":
        # tips over sideways with dizzy look
        lean = -(i * 3)
        bob = i * 2
    if anim == "wall_stun":
        bob = [0, 1, 0][i % 3]
    body_h = size // 2
    body_top = bottom - body_h - 6 + bob
    # legs
    _rect(d, cx - 3 + legs // 2, bottom - 6, cx - 1 + legs // 2, bottom, P.GRAY_DARK)
    _rect(d, cx + 1 - legs // 2, bottom - 6, cx + 3 - legs // 2, bottom, P.GRAY_DARK)
    # suit body
    _outline_rect(d, cx - 4 + lean, body_top, cx + 4 + lean, bottom - 6, P.GRAY)
    # tie
    _rect(d, cx - 1 + lean, body_top + 1, cx + lean, bottom - 8, tie_color)
    # briefcase (walk/panic)
    if anim in ("walk", "panic_run"):
        _outline_rect(d, cx + 5 + lean, body_top + 4 + bob, cx + 9 + lean,
                      body_top + 8 + bob, P.GRAY_DARK)
    # head
    head_y = body_top - 7
    _outline_rect(d, cx - 3 + lean, head_y, cx + 3 + lean, head_y + 6, P.SKIN)
    _rect(d, cx - 3 + lean, head_y, cx + 3 + lean, head_y + 1, P.GRAY)  # hair
    if anim == "alert":
        # red !! telegraph
        _rect(d, cx - 1, oy + 1, cx, oy + 4 + (i % 2), P.RED)
    if anim in ("wall_stun", "death"):
        # dizzy stars
        _px(d, cx - 5, head_y - 2 + (i % 2), P.GOLD)
        _px(d, cx + 5, head_y - 3 - (i % 2), P.GOLD)
    else:
        _px(d, cx + 1 + lean, head_y + 3, P.OUTLINE)
        _px(d, cx + 3 + lean, head_y + 3, P.OUTLINE)


def gen_enemy_sheets(out_dir):
    for name, spec in ENEMY_LAYOUTS.items():
        if name not in ("junior_banker", "angry_manager"):
            continue  # specials drawn by gen_special_enemy_sheets
        size = spec["size"]
        cols = max(f for _, f in spec["anims"])
        img = Image.new("RGBA", (cols * size, len(spec["anims"]) * size), P.TRANSPARENT)
        d = ImageDraw.Draw(img)
        for row, (anim, frames) in enumerate(spec["anims"]):
            for i in range(frames):
                draw_banker_frame(d, i * size, row * size, size, anim, i, P.RED)
        img.save(f"{out_dir}/{name}.png")


def gen_pickups(path):
    """coffee, energy drink, firewall shield, keyboard, usb key — 16x16 x5."""
    img = Image.new("RGBA", (80, 16), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    # coffee: white cup, brown fill, steam
    _outline_rect(d, 4, 7, 11, 13, P.WHITE)
    _rect(d, 5, 8, 10, 9, (122, 78, 42, 255))
    _px(d, 7, 4, P.GRAY)
    _px(d, 8, 2, P.GRAY)
    # energy drink: cyan can
    _outline_rect(d, 16 + 5, 4, 16 + 10, 13, P.CYAN)
    _rect(d, 16 + 6, 6, 16 + 9, 7, P.BG_PANEL)
    # firewall shield: blue bubble
    d.ellipse([32 + 3, 3, 32 + 12, 12], outline=P.BLUE, fill=(38, 168, 255, 90))
    _px(d, 32 + 6, 6, P.WHITE)
    # keyboard: gray with key dots
    _outline_rect(d, 48 + 2, 6, 48 + 13, 12, P.GRAY)
    for kx in range(4, 12, 3):
        _px(d, 48 + kx, 8, P.GREEN)
    # usb key: gold
    _outline_rect(d, 64 + 4, 6, 64 + 11, 10, P.GOLD)
    _rect(d, 64 + 11, 7, 64 + 13, 9, P.GRAY)
    img.save(path)


def gen_checkpoint(path):
    """Terminal 24x32: off, activating, on x2 (green pulse)."""
    img = Image.new("RGBA", (96, 32), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, screen in enumerate([P.GRAY_DARK, P.GREEN_DARK, P.GREEN, P.GREEN_DARK]):
        ox = i * 24
        _outline_rect(d, ox + 6, 8, ox + 17, 28, P.BG_PANEL)   # pillar
        _outline_rect(d, ox + 4, 4, ox + 19, 16, P.GRAY_DARK)  # monitor
        _rect(d, ox + 6, 6, ox + 17, 14, screen)
        if i >= 2:
            _px(d, ox + 8, 9, P.WHITE)  # "✓" hint
            _px(d, ox + 9, 10, P.WHITE)
            _px(d, ox + 10, 9, P.WHITE)
    img.save(path)


def gen_platforms(path):
    """Row 0: moving platform 48x8. Row 1: crumbling 32x16 x3 (intact/shake/broken)."""
    img = Image.new("RGBA", (96, 24), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    _rect(d, 0, 2, 47, 7, P.BLUE_DEEP)
    _rect(d, 0, 2, 47, 2, P.CYAN)
    for e in (2, 44):
        _px(d, e, 5, P.CYAN)
    for i in range(3):
        ox = i * 32
        oy = 8
        if i < 2:
            _rect(d, ox, oy + 2, ox + 31, oy + 8, P.BG_PANEL)
            _rect(d, ox, oy + 2, ox + 31, oy + 2, P.GREEN_DARK)
            cracks = 3 if i == 0 else 8
            for c in range(cracks):
                _px(d, ox + 3 + c * 3, oy + 4 + (c % 3), P.OUTLINE)
        else:  # broken chunks
            for c in range(4):
                _rect(d, ox + c * 8, oy + 4 + (c % 2) * 3, ox + c * 8 + 4,
                      oy + 7 + (c % 2) * 3, P.BG_PANEL)
    img.save(path)


def gen_fx(out_dir):
    """hit spark 16x16 x4."""
    img = Image.new("RGBA", (64, 16), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(4):
        cx = i * 16 + 8
        r = [2, 4, 6, 7][i]
        col = [P.WHITE, P.CYAN, P.CYAN, P.BLUE][i]
        for a in range(0, 360, 45):
            import math
            x = cx + int(r * math.cos(math.radians(a)))
            y = 8 + int(r * math.sin(math.radians(a)))
            _px(d, x, y, col)
        if i < 2:
            _px(d, cx, 8, P.WHITE)
    img.save(f"{out_dir}/hit_spark.png")


def gen_security_node(path):
    """32x32 x3: off (red), charging (blue), on (green)."""
    img = Image.new("RGBA", (96, 32), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i, core in enumerate([P.RED, P.BLUE, P.GREEN]):
        ox = i * 32
        _outline_rect(d, ox + 10, 12, ox + 21, 30, P.BG_PANEL)  # pedestal
        d.ellipse([ox + 8, 2, ox + 23, 17], outline=P.GRAY_DARK, fill=P.BG_PANEL)
        d.ellipse([ox + 12, 6, ox + 19, 13], fill=core)
        for ring in range(3):
            _px(d, ox + 6 + ring, 9 + ring, core)
            _px(d, ox + 25 - ring, 9 + ring, core)
    img.save(path)


def gen_exit_gate(path):
    """48x64 x2: closed (red firewall bars), open (green frame, clear)."""
    img = Image.new("RGBA", (96, 64), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for i in range(2):
        ox = i * 48
        frame = P.GREEN_DARK if i else P.GRAY_DARK
        _outline_rect(d, ox + 2, 0, ox + 45, 63, P.BG_PANEL, frame)
        _rect(d, ox + 6, 4, ox + 41, 59, P.BG_VOID)
        if i == 0:  # closed: red energy bars
            for y in range(8, 60, 8):
                _rect(d, ox + 6, y, ox + 41, y + 2, P.RED)
        else:  # open: soft green shimmer edges
            for y in range(6, 58, 10):
                _px(d, ox + 7, y, P.GREEN)
                _px(d, ox + 40, y + 4, P.GREEN)
    img.save(path)


def gen_stage1_backgrounds(out_dir):
    """Parallax: far = office wall panels + window glow; mid = desk/monitor
    silhouettes. 480x270 each, tileable horizontally."""
    far = Image.new("RGBA", (480, 270), P.BG_VOID)
    d = ImageDraw.Draw(far)
    for x in range(0, 480, 60):  # wall panels
        d.rectangle([x + 2, 20, x + 57, 250], outline=(10, 22, 38, 255))
    for x in range(30, 480, 120):  # dim windows with blue glow
        _rect(d, x, 40, x + 40, 90, (8, 18, 40, 255))
        _rect(d, x + 4, 44, x + 36, 86, (12, 30, 66, 255))
    far.save(f"{out_dir}/stage_1_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 96):  # desk silhouettes with glowing monitors
        _rect(d, x + 8, 210, x + 80, 216, P.BG_PANEL)      # desk top
        _rect(d, x + 12, 216, x + 16, 250, P.BG_PANEL)      # legs
        _rect(d, x + 70, 216, x + 74, 250, P.BG_PANEL)
        _rect(d, x + 28, 190, x + 52, 208, P.BG_PANEL)      # monitor
        _rect(d, x + 31, 193, x + 49, 205, (16, 46, 34, 255))  # dim green screen
        _px(d, x + 34, 196, P.GREEN_DARK)
        _px(d, x + 40, 199, P.GREEN_DARK)
    mid.save(f"{out_dir}/stage_1_mid.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/art")
    args = ap.parse_args()
    out = args.out
    for sub in ("characters", "tiles", "props", "enemies", "fx", "backgrounds"):
        os.makedirs(f"{out}/{sub}", exist_ok=True)

    gen_player_sheet(f"{out}/characters/chris_sheet.png", P.CHRIS_HAIR, False)
    gen_player_sheet(f"{out}/characters/flam_sheet.png", P.FLAM_HAIR, True)
    gen_portraits(f"{out}/characters/portraits.png")
    gen_coin(f"{out}/props/coin.png")
    gen_tileset(f"{out}/tiles/tileset_office.png")
    gen_enemy_sheets(f"{out}/enemies")
    gen_pickups(f"{out}/props/pickups.png")
    gen_checkpoint(f"{out}/props/checkpoint.png")
    gen_platforms(f"{out}/props/platforms.png")
    gen_fx(f"{out}/fx")
    gen_security_node(f"{out}/props/security_node.png")
    gen_exit_gate(f"{out}/props/exit_gate.png")
    gen_stage1_backgrounds(f"{out}/backgrounds")
    gen_special_enemy_sheets(f"{out}/enemies")
    gen_projectiles(f"{out}/props/projectiles.png")
    gen_monitors(f"{out}/props/monitors.png")
    print("placeholder art generated ->", out)


if __name__ == "__main__":
    main()
