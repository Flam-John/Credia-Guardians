"""Generate placeholder sprite sheets, tiles, and props for Credia Guardians.

Deterministic (no randomness): re-running always produces identical PNGs.
Layouts must match docs/ANIMATION_LIST.md — the runtime SpriteFrames builder
(src/util/sprite_frames_builder.gd) slices sheets by the same row table.

Usage:  python tools/artgen/generate_placeholders.py [--out assets/art]
"""
from __future__ import annotations

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402
from pixkit import (dither_row, glow_disc, glow_pool, scale_color,  # noqa: E402
                    shade_rect, vshade_rect)

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


def draw_hero_frame(draw, ox: int, oy: int, anim: str, i: int, hero: str):
    """One 32x32 hero frame at sheet offset (ox, oy).

    Key-art look: segmented black armor with green circuit piping between
    plates, shoulder pads, cape, glowing chest logo, 2-tone face.
    hero = 'chris' (bulky, short dark hair, forearm shield emitter) or
    'flam' (lean, long swaying brown hair, cyan accents).
    """
    chris = hero == "chris"
    hair_ramp = P.CHRIS_HAIR_RAMP if chris else P.FLAM_HAIR_RAMP
    accent = P.GREEN_DARK if chris else P.CYAN
    half = 6 if chris else 5  # torso half-width: Chris is the tank
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
    t0, t1 = oy + body_top, oy + 22

    # cape behind everything (dark navy, trails against motion, sways at rest)
    cape_sway = [0, 1, 0, -1][i % 4]
    draw.polygon([
        (cx - half + 1 + lean, t0 + 1),
        (cx + half - 1 + lean, t0 + 1),
        (cx + half - 2 + cape_sway - lean * 2, oy + 26),
        (cx - half - 1 + cape_sway - lean * 2, oy + 25),
    ], fill=(10, 16, 34, 255))
    draw.line([(cx - half + cape_sway - lean * 2, oy + 25),
               (cx + half - 3 + cape_sway - lean * 2, oy + 26)],
              fill=(6, 10, 22, 255))  # cape hem shadow

    # legs: armored, knee piping, glow soles
    for leg_x, off in ((cx - 4, leg_l // 2), (cx + 1, leg_r // 2)):
        shade_rect(draw, leg_x + off, oy + 22, leg_x + 2 + off, oy + 28, P.ARMOR_RAMP)
        _px(draw, leg_x + 1 + off, oy + 25, accent)  # knee seam
        _rect(draw, leg_x + off, oy + 29, leg_x + 2 + off, oy + 30, P.ARMOR_RAMP[0])
        _rect(draw, leg_x + off, oy + 30, leg_x + 2 + off, oy + 30, P.GREEN_DARK)

    # torso: 3 armor plates split by green piping seams
    _outline_rect(draw, cx - half + lean, t0, cx + half + lean, t1, P.ARMOR_RAMP[1])
    draw.line([(cx - half + 1 + lean, t0 + 1), (cx + half - 1 + lean, t0 + 1)],
              fill=P.ARMOR_RAMP[2])  # top plate light
    draw.line([(cx + half - 1 + lean, t0 + 2), (cx + half - 1 + lean, t1 - 1)],
              fill=P.ARMOR_RAMP[0])  # side shadow
    h = t1 - t0
    for seam_y in (t0 + h // 3 + 1, t0 + 2 * h // 3 + 1):
        if t0 + 1 < seam_y < t1:
            draw.line([(cx - half + 1 + lean, seam_y), (cx + half - 1 + lean, seam_y)],
                      fill=P.GREEN_DARK)
    _px(draw, cx - half + 1 + lean, t0 + h // 3 + 1, P.GREEN)  # piping glint
    # belt with gold buckle
    draw.line([(cx - half + 1 + lean, t1 - 1), (cx + half - 1 + lean, t1 - 1)],
              fill=P.ARMOR_RAMP[0])
    _px(draw, cx + lean, t1 - 1, P.GOLD)
    # glowing chest logo (blue/green coin)
    _px(draw, cx - 1 + lean, t0 + 3, P.BLUE)
    _px(draw, cx + lean, t0 + 3, P.GREEN)
    _px(draw, cx - 1 + lean, t0 + 4, P.BLUE_RAMP[0])
    _px(draw, cx + lean, t0 + 4, P.GREEN_RAMP[0])

    # shoulder pads (green rim on top)
    shade_rect(draw, cx + half - 2 + lean, t0 - 1, cx + half + 1 + lean, t0 + 2,
               (P.ARMOR_RAMP[0], P.ARMOR_RAMP[1], P.GREEN_DARK))
    _px(draw, cx - half + lean, t0, P.ARMOR_RAMP[2])  # far pad hint

    # arm: segmented, Chris carries the shield emitter on the forearm
    shade_rect(draw, cx + 4 + lean, oy + arm_y, cx + 4 + lean + arm_len,
               oy + arm_y + 2, P.ARMOR_RAMP)
    if arm_len >= 3:
        _px(draw, cx + 5 + lean + arm_len // 2, oy + arm_y + 1, accent)  # elbow seam
    if chris and arm_len >= 3:
        _px(draw, cx + 3 + lean + arm_len, oy + arm_y, P.CYAN)  # emitter
    if is_attack:
        # melee swoosh at arm tip (cyan arc with hot core)
        tip = cx + 5 + lean + arm_len
        _rect(draw, tip, oy + arm_y - 2, tip + 1, oy + arm_y + 4, P.CYAN)
        _px(draw, tip, oy + arm_y + 1, P.WHITE)
        _px(draw, tip - 1, oy + arm_y - 3, P.CYAN_RAMP[0])
        _px(draw, tip - 1, oy + arm_y + 5, P.CYAN_RAMP[0])

    # head: 2-tone skin, brow, green eyes
    head_y = oy + body_top - 8
    _outline_rect(draw, cx - 4 + lean, head_y, cx + 4 + lean, head_y + 7, P.SKIN)
    draw.line([(cx - 3 + lean, head_y + 6), (cx + 3 + lean, head_y + 6)],
              fill=P.SKIN_RAMP[0])  # jaw shadow
    _px(draw, cx - 3 + lean, head_y + 5, P.SKIN_RAMP[0])
    _px(draw, cx - 1 + lean, head_y + 4, P.SKIN_RAMP[2])  # cheek light
    draw.line([(cx + 1 + lean, head_y + 3), (cx + 3 + lean, head_y + 3)],
              fill=P.OUTLINE)  # brow
    _px(draw, cx + 1 + lean, head_y + 4, P.GREEN)
    _px(draw, cx + 3 + lean, head_y + 4, P.GREEN)

    # hair: base + hairline dither + shine
    _rect(draw, cx - 4 + lean, head_y, cx + 4 + lean, head_y + 1, hair_ramp[1])
    dither_row(draw, cx - 4 + lean, cx + 4 + lean, head_y + 2, hair_ramp[1], phase=1)
    _px(draw, cx - 2 + lean, head_y, hair_ramp[2])  # shine
    _px(draw, cx + 4 + lean, head_y + 1, hair_ramp[0])
    if not chris:
        # Flam: long strand down the left, sways with the frame
        sway = i % 2
        _rect(draw, cx - 6 + lean, head_y + 1, cx - 5 + lean, head_y + 9 + sway,
              hair_ramp[1])
        draw.line([(cx - 6 + lean, head_y + 3), (cx - 6 + lean, head_y + 8 + sway)],
                  fill=hair_ramp[0])
        _px(draw, cx - 5 + lean, head_y + 2, hair_ramp[2])

    if anim == "ability":
        # Chris: shield shimmer arc / Flam: charge glow — cyan arc
        for dy in range(-2, 14, 2):
            _px(draw, cx + 8 + (i % 2), oy + 8 + dy, P.CYAN)
            _px(draw, cx + 9 + (i % 2), oy + 9 + dy, (22, 224, 224, 90))
    if anim == "hurt":
        _px(draw, cx - 7, oy + 8, P.RED)
        _px(draw, cx + 7, oy + 6, P.RED)
    if anim == "victory":
        # raised armored fist with glowing knuckle
        shade_rect(draw, cx + 4, oy + 4 + bob, cx + 6, oy + 12, P.ARMOR_RAMP)
        _px(draw, cx + 5, oy + 3 + bob, P.GREEN)
        _px(draw, cx + 5, oy + 2 + bob, P.GREEN_RAMP[2])


def gen_player_sheet(path: str, hero: str):
    sheet = Image.new("RGBA", (SHEET_COLS * FRAME, len(PLAYER_ANIMS) * FRAME), P.TRANSPARENT)
    draw = ImageDraw.Draw(sheet)
    for row, (anim, frames) in enumerate(PLAYER_ANIMS):
        for i in range(frames):
            draw_hero_frame(draw, i * FRAME, row * FRAME, anim, i, hero)
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


def gen_tileset(path: str, top_light=None, top_glow=None):
    """256x256 tileset. Row 0 holds the core gameplay tiles at fixed coords
    used by AsciiRoomBuilder: 0 solid-top, 1 solid-interior, 2 bg panel,
    3 spike hazard, 4 one-way platform, 5 solid-left-edge, 6 solid-right-edge.
    top_light/top_glow recolor the walkable edge per stage theme.
    """
    top_light = top_light or P.GREEN_DARK
    top_glow = top_glow or P.GREEN
    img = Image.new("RGBA", (256, 256), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    t = 16

    def tile(ix, iy):
        return ix * t, iy * t

    # 0: solid with themed light strip on top
    x, y = tile(0, 0)
    _rect(d, x, y, x + 15, y + 15, P.BG_PANEL)
    _rect(d, x, y, x + 15, y + 1, top_light)
    _rect(d, x, y, x + 15, y, top_glow)
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
        _rect(d, x + edge_x, y, x + edge_x, y + 15, top_light)
    img.save(path)


def gen_stage_backgrounds(out_dir):
    """Far/mid parallax for stages 2-4, matching each theme accent."""
    # Stage 2: Data Center — server racks + digital rain
    far = Image.new("RGBA", (480, 270), P.BG_VOID)
    d = ImageDraw.Draw(far)
    for x in range(8, 480, 48):  # server racks
        _rect(d, x, 30, x + 32, 250, (8, 16, 28, 255))
        for row in range(38, 245, 14):
            _px(d, x + 5, row, P.GREEN_DARK if (x + row) % 3 else P.CYAN)
            _px(d, x + 12, row, (12, 60, 60, 255))
    for col in range(20, 480, 90):  # digital rain streaks
        for y in range((col * 7) % 40, 260, 26):
            _rect(d, col, y, col, y + 8, (14, 90, 90, 255))
    far.save(f"{out_dir}/stage_2_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 120):  # cable trays
        _rect(d, x, 60, x + 100, 63, (16, 30, 48, 255))
        for cx in range(x + 10, x + 90, 20):
            d.arc([cx, 63, cx + 18, 80], 0, 180, fill=(16, 30, 48, 255))
    mid.save(f"{out_dir}/stage_2_mid.png")

    # Stage 3: Corporate HQ — marble columns + tall windows, gold accent
    far = Image.new("RGBA", (480, 270), (8, 10, 16, 255))
    d = ImageDraw.Draw(far)
    for x in range(15, 480, 80):  # columns
        _rect(d, x, 20, x + 14, 250, (22, 24, 34, 255))
        _rect(d, x - 3, 16, x + 17, 22, (30, 32, 44, 255))
        _rect(d, x - 3, 248, x + 17, 254, (30, 32, 44, 255))
    for x in range(45, 480, 160):  # gold-lit windows
        _rect(d, x, 50, x + 50, 160, (26, 22, 12, 255))
        _rect(d, x + 4, 54, x + 46, 156, (48, 38, 16, 255))
    far.save(f"{out_dir}/stage_3_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 96):  # velvet rope posts
        _rect(d, x + 20, 200, x + 23, 230, (40, 34, 18, 255))
        d.arc([x + 23, 195, x + 93, 225], 20, 160, fill=(60, 50, 22, 255))
    mid.save(f"{out_dir}/stage_3_mid.png")

    # Stage 4: Digital Vault — vault doors + gold on black
    far = Image.new("RGBA", (480, 270), (4, 6, 10, 255))
    d = ImageDraw.Draw(far)
    for x in range(30, 480, 140):  # giant vault wheels
        d.ellipse([x, 60, x + 90, 150], outline=(40, 34, 14, 255), width=4)
        d.ellipse([x + 30, 90, x + 60, 120], outline=(60, 50, 20, 255), width=2)
        for ang in range(0, 360, 60):
            lx = x + 45 + int(55 * math.cos(math.radians(ang)))
            ly = 105 + int(55 * math.sin(math.radians(ang)))
            _px(d, lx, ly, P.GOLD)
    far.save(f"{out_dir}/stage_4_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 60):  # deposit box walls
        for y in range(170, 250, 20):
            _rect(d, x + 4, y, x + 52, y + 16, (14, 14, 20, 255))
            _px(d, x + 28, y + 8, (60, 50, 20, 255))
    mid.save(f"{out_dir}/stage_4_mid.png")


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
    """8x8 x3: ledger (white page), plasma orb (red), gold coin (CEO)."""
    img = Image.new("RGBA", (24, 8), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    _outline_rect(d, 1, 1, 6, 6, P.WHITE)
    _px(d, 3, 3, P.GRAY_DARK)
    _px(d, 3, 4, P.GRAY_DARK)
    d.ellipse([9, 1, 14, 6], fill=P.RED, outline=(120, 10, 30, 255))
    d.ellipse([17, 1, 22, 6], fill=P.GOLD, outline=(140, 100, 20, 255))
    img.save(path)


CEO_LAYOUTS = {
    "ceo_suit": {
        "w": 64, "h": 96,
        "anims": [("idle", 4), ("slam", 6), ("coin_volley", 4),
                  ("charge", 4), ("stagger", 3), ("phase_change", 4)],
    },
    "ceo_demon": {
        "w": 96, "h": 96,
        "anims": [("float", 4), ("laser_sweep", 6), ("teleport", 4),
                  ("spiral_cast", 4), ("core_exposed", 3), ("death", 8)],
    },
}


def draw_ceo_frame(d, ox, oy, w, h, demon, anim, i):
    cx = ox + w // 2
    bottom = oy + h - 4
    bob = i % 2
    if not demon:
        # giant suited chairman
        lean = {"slam": [0, 2, 4, 6, 2, -4], "charge": [4, 6, 4, 6],
                "stagger": [-6, -8, -6], "coin_volley": [0, 2, 2, 0],
                "phase_change": [0, 0, 2, 4], "idle": [0, 1, 0, -1]}[anim][i]
        crouch = 12 if anim == "slam" and i >= 3 else 0
        body_top = oy + 30 + bob + crouch
        _outline_rect(d, cx - 16 + lean, body_top, cx + 16 + lean, bottom, P.GRAY_DARK)
        _rect(d, cx - 2 + lean, body_top + 4, cx + 2 + lean, bottom - 20,
              P.GOLD if anim != "phase_change" else P.RED)  # tie
        # arms
        arm = 10 if anim in ("slam", "coin_volley") and 1 <= i <= 3 else 4
        _rect(d, cx + 15 + lean, body_top + 10, cx + 15 + lean + arm, body_top + 16, P.GRAY_DARK)
        # head
        _outline_rect(d, cx - 9 + lean, body_top - 20, cx + 9 + lean, body_top - 2, P.SKIN)
        _rect(d, cx - 9 + lean, body_top - 20, cx + 9 + lean, body_top - 15, P.GRAY)
        eye = P.RED if anim in ("charge", "phase_change") else P.OUTLINE
        _px(d, cx - 3 + lean, body_top - 10, eye)
        _px(d, cx + 4 + lean, body_top - 10, eye)
        if anim == "stagger":
            _px(d, cx - 12, body_top - 26 + (i % 2), P.GOLD)
            _px(d, cx + 12, body_top - 28 - (i % 2), P.GOLD)
    else:
        # digital demon form: red/black with cyan glitches
        top = oy + 10 + bob * 2
        _outline_rect(d, cx - 20, top + 20, cx + 20, bottom, (30, 6, 12, 255))
        d.polygon([(cx - 24, top + 30), (cx - 34, top + 10), (cx - 16, top + 22)],
                  fill=(60, 8, 16, 255))  # wing L
        d.polygon([(cx + 24, top + 30), (cx + 34, top + 10), (cx + 16, top + 22)],
                  fill=(60, 8, 16, 255))  # wing R
        _outline_rect(d, cx - 12, top, cx + 12, top + 22, (40, 8, 14, 255))
        _px(d, cx - 5, top + 8, P.RED)
        _px(d, cx + 5, top + 8, P.RED)
        for hrn in (-10, 10):  # horns
            d.polygon([(cx + hrn - 2, top), (cx + hrn, top - 8), (cx + hrn + 2, top)],
                      fill=P.RED)
        # core
        core_col = P.GREEN if anim == "core_exposed" else (80, 20, 30, 255)
        d.ellipse([cx - 5, top + 34, cx + 5, top + 44], fill=core_col, outline=P.OUTLINE)
        for g in range(4):  # glitch scanlines
            gy = top + 6 + g * 18 + (i * 5) % 11
            _rect(d, cx - 22, gy, cx + 22, gy, (22, 224, 224, 100))
        if anim == "death":
            for s in range(i + 1):
                _px(d, cx - 20 + s * 5, bottom - (s * 9) % 60, P.CYAN)


def gen_ceo_sheets(out_dir):
    os.makedirs(f"{out_dir}/bosses", exist_ok=True)
    for name, spec in CEO_LAYOUTS.items():
        w, h = spec["w"], spec["h"]
        cols = max(f for _, f in spec["anims"])
        img = Image.new("RGBA", (cols * w, len(spec["anims"]) * h), P.TRANSPARENT)
        d = ImageDraw.Draw(img)
        for row, (anim, frames) in enumerate(spec["anims"]):
            for i in range(frames):
                draw_ceo_frame(d, i * w, row * h, w, h, name == "ceo_demon", anim, i)
        img.save(f"{out_dir}/bosses/{name}.png")


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


def gen_core_backgrounds(out_dir):
    """Stage 5: blue circuitry invaded by red corruption veins."""
    far = Image.new("RGBA", (480, 270), (3, 4, 10, 255))
    d = ImageDraw.Draw(far)
    for x in range(0, 480, 40):  # circuit traces
        col = P.RED if (x // 40) % 3 == 0 else P.BLUE_DEEP
        d.line([(x, 0), (x, 130), (x + 20, 150), (x + 20, 270)], fill=col)
        _px(d, x, 130, P.CYAN)
    for y in range(30, 270, 60):
        d.line([(0, y), (480, y)], fill=(14, 22, 50, 255))
    far.save(f"{out_dir}/stage_5_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(20, 480, 110):  # corruption veins
        d.line([(x, 270), (x + 12, 200), (x - 6, 150), (x + 8, 90)],
               fill=(120, 16, 28, 255), width=2)
        _px(d, x + 8, 90, P.RED)
    mid.save(f"{out_dir}/stage_5_mid.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/art")
    args = ap.parse_args()
    out = args.out
    for sub in ("characters", "tiles", "props", "enemies", "fx", "backgrounds"):
        os.makedirs(f"{out}/{sub}", exist_ok=True)

    gen_player_sheet(f"{out}/characters/chris_sheet.png", "chris")
    gen_player_sheet(f"{out}/characters/flam_sheet.png", "flam")
    gen_portraits(f"{out}/characters/portraits.png")
    gen_coin(f"{out}/props/coin.png")
    gen_tileset(f"{out}/tiles/tileset_office.png")
    gen_tileset(f"{out}/tiles/tileset_datacenter.png", (18, 140, 140, 255), P.CYAN)
    gen_tileset(f"{out}/tiles/tileset_hq.png", (150, 120, 30, 255), P.GOLD)
    gen_tileset(f"{out}/tiles/tileset_vault.png", (120, 100, 24, 255), (255, 220, 120, 255))
    gen_tileset(f"{out}/tiles/tileset_core.png", (140, 30, 40, 255), P.RED)
    gen_stage_backgrounds(f"{out}/backgrounds")
    gen_core_backgrounds(f"{out}/backgrounds")
    gen_ceo_sheets(f"{out}/enemies")
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
