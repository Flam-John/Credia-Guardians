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
    trail = cape_sway - lean * 2

    def _cl(x: int) -> int:  # keep the trailing cape inside this 32px cell
        return max(ox, min(ox + 31, x))

    draw.polygon([
        (cx - half + 1 + lean, t0 + 1),
        (cx + half - 1 + lean, t0 + 1),
        (_cl(cx + half - 2 + trail), oy + 26),
        (_cl(cx - half - 1 + trail), oy + 25),
    ], fill=(10, 16, 34, 255))
    draw.line([(_cl(cx - half + trail), oy + 25),
               (_cl(cx + half - 3 + trail), oy + 26)],
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


def draw_zaf(d, ox: int, oy: int, i: int, talk: bool):
    """Zaf, the boss (32x32): bulky build, black tee, tan skin, towering
    spiky black hair, full gray beard, permanent scowl. Idle bobs with
    crossed arms; talk waves a hand and flashes the mouth."""
    cx = ox + 16
    bob = [0, 1, 0, -1][i % 4] if not talk else 0
    tee = ((10, 12, 16, 255), (22, 26, 32, 255), (40, 46, 56, 255))
    beard = ((44, 48, 56, 255), (74, 80, 90, 255), (110, 118, 128, 255))
    hair = P.CHRIS_HAIR_RAMP
    zskin = ((150, 96, 58, 255), (196, 134, 84, 255), (234, 178, 122, 255))
    # 17 = 11 (head) + max spike 6 above: the whole figure stays in-cell
    body_top = oy + 17 + bob
    # legs: dark trousers + boots
    for leg_x in (cx - 5, cx + 2):
        shade_rect(d, leg_x, oy + 24, leg_x + 3, oy + 29, tee)
        _rect(d, leg_x, oy + 30, leg_x + 3, oy + 30, P.OUTLINE)
    # torso: wide tee with shading
    shade_rect(d, cx - 7, body_top, cx + 7, oy + 24, tee, outline=P.OUTLINE)
    if talk and i % 2 == 1:
        # raised gesturing hand
        shade_rect(d, cx + 8, body_top - 3, cx + 11, body_top + 4, zskin)
        _px(d, cx + 9, body_top - 4, zskin[2])
    else:
        # crossed arms: skin band over the chest
        shade_rect(d, cx - 6, body_top + 3, cx + 6, body_top + 6, zskin)
        d.line([(cx - 6, body_top + 6), (cx + 6, body_top + 6)], fill=zskin[0])
    # head
    head_y = body_top - 11
    _outline_rect(d, cx - 5, head_y, cx + 5, head_y + 10, zskin[1])
    _px(d, cx - 4, head_y + 3, zskin[2])  # brow light
    # full beard: lower half of the face + below the chin
    _rect(d, cx - 5, head_y + 5, cx + 5, head_y + 10, beard[1])
    d.line([(cx - 4, head_y + 10), (cx + 4, head_y + 10)], fill=beard[0])
    _rect(d, cx - 3, head_y + 11, cx + 3, head_y + 12 + (i % 2 if talk else 0),
          beard[0])
    _px(d, cx - 2, head_y + 6, beard[2])  # beard shine
    if talk and i % 2 == 0:
        _rect(d, cx - 1, head_y + 7, cx + 1, head_y + 7, (30, 20, 20, 255))  # mouth
    # heavy scowling brows + stern eyes
    d.line([(cx - 4, head_y + 2), (cx - 1, head_y + 3)], fill=P.OUTLINE)
    d.line([(cx + 1, head_y + 3), (cx + 4, head_y + 2)], fill=P.OUTLINE)
    _px(d, cx - 2, head_y + 4, P.OUTLINE)
    _px(d, cx + 2, head_y + 4, P.OUTLINE)
    # towering hair spikes (heights capped so the tips stay inside the cell)
    for sx, sh in ((-5, 3), (-3, 5), (-1, 6), (1, 6), (3, 5), (5, 3)):
        d.polygon([(cx + sx - 1, head_y + 1), (cx + sx, head_y - sh),
                   (cx + sx + 1, head_y + 1)], fill=hair[1])
        _px(d, cx + sx, head_y - sh + 1, hair[0])
    d.line([(cx - 5, head_y), (cx + 5, head_y)], fill=hair[1])


def gen_zaf_sheet(path: str):
    """Zaf sheet, 32x32 x 6 cols x 3 rows:
    row 0 materialize (6 frames: digital assembly, cyan resolve)
    row 1 idle (4)   row 2 talk (4)
    The tutorial scene plays row 0 forward to appear, reversed to leave."""
    base = Image.new("RGBA", (32, 32), P.TRANSPARENT)
    draw_zaf(ImageDraw.Draw(base), 0, 0, 0, False)
    sheet = Image.new("RGBA", (6 * 32, 3 * 32), P.TRANSPARENT)
    d = ImageDraw.Draw(sheet)
    src = base.load()
    for f in range(6):
        thresh = (f + 1) / 6.0
        for y in range(32):
            for x in range(32):
                c = src[x, y]
                if c[3] == 0:
                    continue
                h = ((x * 31 + y * 17) % 97) / 97.0
                if h < thresh:
                    # newly-resolved pixels flash cyan before settling; the
                    # terminal frame (thresh=1.0) must be FULLY resolved —
                    # a lingering flash there reads as a permanent glitch,
                    # since this is Zaf's resting frame once he's talking
                    settled = f == 5 or h < thresh - 0.18
                    sheet.putpixel((f * 32 + x, y),
                                   c if settled else (22, 224, 224, 255))
        if f < 5:
            for g in range(3):  # roaming glitch scanlines
                gy = (f * 11 + g * 9) % 30 + 1
                d.line([(f * 32 + 5, gy), (f * 32 + 26, gy)],
                       fill=(22, 224, 224, 120))
    for i in range(4):
        draw_zaf(d, i * 32, 32, i, False)
    for i in range(4):
        draw_zaf(d, i * 32, 64, i, True)
    sheet.save(path)


def gen_hud_atlas(path: str):
    """64x24 HUD atlas — fixed regions consumed by src/ui/hud.gd:
    (0,0,24,24)  beveled metal portrait frame, transparent 20x20 center
    (24,0,7,8)   HP pill ON (glossy green)   (24,8,7,8)  HP pill OFF
    (32,0,6,6)   boss pill ON (red)          (32,8,6,6)  boss pill OFF
    (40,0,12,12) 9-patch dark panel (4px margins) for label backings
    """
    img = Image.new("RGBA", (64, 24), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    # portrait frame: outer bevel lit top-left, inner bevel inverted
    shade_rect(d, 0, 0, 23, 23, P.GRAY_RAMP, outline=P.OUTLINE)
    shade_rect(d, 1, 1, 22, 22, (P.GRAY_RAMP[2], P.GRAY_RAMP[1], P.GRAY_RAMP[0]))
    d.rectangle([2, 2, 21, 21], fill=P.TRANSPARENT)  # punch the window
    for cx_, cy_ in ((0, 0), (23, 0), (0, 23), (23, 23)):  # corner screws
        _px(d, cx_, cy_, P.OUTLINE)
    _px(d, 1, 1, P.GREEN)  # power LED in the top-left corner
    # HP pills
    shade_rect(d, 24, 0, 30, 7, P.GREEN_RAMP, outline=P.OUTLINE)
    _px(d, 25, 1, P.WHITE)  # gloss glint
    shade_rect(d, 24, 8, 30, 15, P.PANEL_RAMP, outline=P.OUTLINE)
    # boss pills
    shade_rect(d, 32, 0, 37, 5, P.RED_RAMP, outline=P.OUTLINE)
    _px(d, 33, 1, P.RED_RAMP[2])
    shade_rect(d, 32, 8, 37, 13, P.PANEL_RAMP, outline=P.OUTLINE)
    # 9-patch panel: dark backing with metallic border
    shade_rect(d, 40, 0, 51, 11, P.PANEL_RAMP, outline=P.GRAY_DARK)
    d.rectangle([41, 1, 50, 10], outline=P.PANEL_RAMP[0])
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


def _mix(a, b, f: float):
    """Opaque blend of two colors: a*(1-f) + b*f. Tiles must stay opaque —
    ImageDraw writes raw RGBA, so alpha would punch see-through holes."""
    return (int(a[0] * (1 - f) + b[0] * f), int(a[1] * (1 - f) + b[1] * f),
            int(a[2] * (1 - f) + b[2] * f), 255)


def gen_tileset(path: str, top_light=None, top_glow=None):
    """256x256 tileset. Row 0 holds the core gameplay tiles at fixed coords
    used by AsciiRoomBuilder: 0 solid-top, 1 solid-interior, 2 bg panel,
    3 spike hazard, 4 one-way platform, 5 solid-left-edge, 6 solid-right-edge.
    top_light/top_glow recolor the walkable edge per stage theme.
    """
    top_light = top_light or P.GREEN_DARK
    top_glow = top_glow or P.GREEN
    trace = _mix(P.PANEL_RAMP[1], top_light, 0.35)  # dim circuit-trace color
    bloom = _mix(P.PANEL_RAMP[2], top_glow, 0.30)   # soft row under the strip
    rivet = (20, 38, 60, 255)
    grout = (3, 6, 12, 255)
    img = Image.new("RGBA", (256, 256), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    t = 16

    def tile(ix, iy):
        return ix * t, iy * t

    def panel_body(x, y):
        """Shared solid-tile body: shaded panel, grout seams, corner rivets."""
        vshade_rect(d, x, y, x + 15, y + 15, P.PANEL_RAMP)
        d.line([(x, y + 15), (x + 15, y + 15)], fill=grout)
        d.line([(x + 15, y), (x + 15, y + 15)], fill=grout)
        for rx, ry in ((x + 2, y + 2), (x + 13, y + 2),
                       (x + 2, y + 13), (x + 13, y + 13)):
            _px(d, rx, ry, rivet)

    # 0: solid walkable — glow strip, bloom row, circuit trace
    x, y = tile(0, 0)
    panel_body(x, y)
    _rect(d, x, y, x + 15, y, top_glow)
    _rect(d, x, y + 1, x + 15, y + 2, top_light)
    _rect(d, x, y + 3, x + 15, y + 3, bloom)
    d.line([(x + 3, y + 8), (x + 8, y + 8), (x + 8, y + 12)], fill=trace)
    _px(d, x + 8, y + 12, top_light)  # solder point
    # 1: solid interior — grout grid + traces + vent slits
    x, y = tile(1, 0)
    panel_body(x, y)
    d.line([(x + 2, y + 5), (x + 7, y + 5), (x + 7, y + 10), (x + 12, y + 10)],
           fill=trace)
    _px(d, x + 12, y + 10, top_light)
    d.line([(x + 11, y + 3), (x + 13, y + 3)], fill=P.PANEL_RAMP[0])
    d.line([(x + 2, y + 12), (x + 4, y + 12)], fill=P.PANEL_RAMP[0])
    # 2: background panel (no collision) — darker inset
    x, y = tile(2, 0)
    _rect(d, x, y, x + 15, y + 15, P.BG_VOID)
    d.rectangle([x + 2, y + 2, x + 13, y + 13], outline=P.BG_PANEL)
    d.line([(x + 3, y + 3), (x + 12, y + 3)], fill=(14, 28, 46, 255))  # inset light
    _px(d, x + 7, y + 8, _mix(P.BG_VOID, top_light, 0.3))  # faint status LED
    # 3: spike hazard — ramped spikes on a base plate
    x, y = tile(3, 0)
    _rect(d, x, y + 14, x + 15, y + 15, P.PANEL_RAMP[0])
    d.line([(x, y + 14), (x + 15, y + 14)], fill=P.PANEL_RAMP[2])
    for s in range(4):
        sx = x + s * 4
        d.polygon([(sx, y + 14), (sx + 2, y + 6), (sx + 3, y + 14)],
                  fill=P.RED_RAMP[0])
        d.line([(sx + 2, y + 6), (sx + 2, y + 13)], fill=P.RED)  # lit face
        _px(d, sx + 2, y + 6, P.RED_RAMP[2])  # hot tip
    # 4: one-way platform — glossy energy strip with brackets
    x, y = tile(4, 0)
    _rect(d, x, y + 2, x + 15, y + 5, P.BLUE_RAMP[0])
    _rect(d, x, y + 3, x + 15, y + 4, P.BLUE_DEEP)
    _rect(d, x, y + 2, x + 15, y + 2, P.CYAN)
    for gx in range(x + 2, x + 16, 6):
        _px(d, gx, y + 2, P.WHITE)  # glints
        _rect(d, gx, y + 6, gx + 1, y + 7, P.PANEL_RAMP[1])  # support bracket
    # 5/6: solid left/right edge lit
    for ix, edge_x in ((5, 0), (6, 15)):
        x, y = tile(ix, 0)
        panel_body(x, y)
        _rect(d, x + edge_x, y, x + edge_x, y + 15, top_light)
        _px(d, x + edge_x, y, top_glow)
    img.save(path)


SILHOUETTE = (4, 8, 16, 255)  # near-layer color: darker than everything behind


def _near_layer(out_path: str, draw_fn):
    """480x270 mostly-transparent foreground silhouette layer (motion 0.8)."""
    img = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    draw_fn(ImageDraw.Draw(img), img)
    img.save(out_path)


def _hanging_cables(d, img, seed_step=70, color=SILHOUETTE):
    """Cable bundles drooping from the ceiling — the key art's canopy."""
    for x in range(10, 480, seed_step):
        droop = 22 + (x * 13) % 30
        d.arc([x, -droop, x + seed_step + 10, droop], 15, 165, fill=color, width=2)
        _px(d, x + seed_step // 2, droop - 1, (30, 60, 40, 255))  # status LED


def gen_stage_backgrounds(out_dir):
    """Parallax for stages 2-4: far/mid + near silhouettes, key-art depth."""
    # ---- Stage 2: Data Center — server racks, LEDs, digital rain
    far = Image.new("RGBA", (480, 270), P.BG_VOID)
    d = ImageDraw.Draw(far)
    for x in range(8, 480, 48):  # server racks, vertically shaded
        vshade_rect(d, x, 30, x + 32, 250, ((5, 10, 18, 255), (8, 16, 28, 255),
                                            (12, 24, 40, 255)))
        _rect(d, x, 28, x + 32, 29, (16, 32, 52, 255))  # rack cap
        for row in range(38, 245, 14):  # LED columns: green/cyan, rare red fault
            fault = (x * 7 + row) % 11 == 0
            _px(d, x + 5, row, P.RED if fault else
                (P.GREEN_DARK if (x + row) % 3 else P.CYAN))
            _px(d, x + 12, row, (12, 60, 60, 255))
            _px(d, x + 26, row + 4, (10, 40, 70, 255))
        for vy in range(40, 240, 28):  # vent slits
            d.line([(x + 18, vy), (x + 22, vy)], fill=(4, 8, 14, 255))
    for col in range(20, 480, 90):  # digital rain streaks (two tones)
        for y in range((col * 7) % 40, 260, 26):
            _rect(d, col, y, col, y + 8, (14, 90, 90, 255))
            _px(d, col, y + 9, (20, 140, 140, 255))
    for x in range(24, 480, 96):  # floor light pools under the racks
        glow_pool(far, x, 258, 26, P.CYAN)
    far.save(f"{out_dir}/stage_2_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 120):  # cable trays with drooping bundles
        _rect(d, x, 60, x + 100, 63, (16, 30, 48, 255))
        _rect(d, x, 60, x + 100, 60, (26, 46, 70, 255))  # lit tray edge
        for cx in range(x + 10, x + 90, 20):
            d.arc([cx, 63, cx + 18, 80], 0, 180, fill=(16, 30, 48, 255))
    for x in range(60, 480, 160):  # wall status monitors
        _rect(d, x, 110, x + 26, 128, (10, 20, 34, 255))
        _rect(d, x + 2, 112, x + 24, 126, (6, 30, 30, 255))
        for line in range(3):
            d.line([(x + 4, 115 + line * 4), (x + 4 + 12 - line * 3, 115 + line * 4)],
                   fill=P.GREEN_DARK)
        glow_pool(mid, x + 13, 132, 14, P.GREEN)
    mid.save(f"{out_dir}/stage_2_mid.png")

    _near_layer(f"{out_dir}/stage_2_near.png",
                lambda d, img: _hanging_cables(d, img, 64))

    # ---- Stage 3: Corporate HQ — marble, gold light, chandeliers
    far = Image.new("RGBA", (480, 270), (8, 10, 16, 255))
    d = ImageDraw.Draw(far)
    for x in range(15, 480, 80):  # columns with capitals, gold-lit edge
        vshade_rect(d, x, 20, x + 14, 250, ((14, 15, 22, 255), (22, 24, 34, 255),
                                            (34, 37, 50, 255)))
        d.line([(x + 2, 22), (x + 2, 248)], fill=(48, 44, 30, 255))  # gold sheen
        _rect(d, x - 3, 16, x + 17, 22, (30, 32, 44, 255))
        _rect(d, x - 3, 14, x + 17, 15, (52, 48, 34, 255))  # capital light
        _rect(d, x - 3, 248, x + 17, 254, (30, 32, 44, 255))
    for x in range(45, 480, 160):  # gold-lit windows with muntins
        _rect(d, x, 50, x + 50, 160, (26, 22, 12, 255))
        _rect(d, x + 4, 54, x + 46, 156, (48, 38, 16, 255))
        d.line([(x + 25, 54), (x + 25, 156)], fill=(26, 22, 12, 255))
        d.line([(x + 4, 105), (x + 46, 105)], fill=(26, 22, 12, 255))
        glow_pool(far, x + 25, 258, 30, P.GOLD)
    for x in range(85, 480, 160):  # chandelier glow between windows
        glow_disc(far, x + 40, 34, 16, P.GOLD)
        _px(d, x + 40, 30, P.GOLD)
        _px(d, x + 38, 33, P.GOLD_RAMP[0])
        _px(d, x + 42, 33, P.GOLD_RAMP[0])
    far.save(f"{out_dir}/stage_3_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 96):  # velvet rope posts with gold caps
        _rect(d, x + 20, 200, x + 23, 230, (40, 34, 18, 255))
        _px(d, x + 21, 199, P.GOLD)
        d.arc([x + 23, 195, x + 93, 225], 20, 160, fill=(60, 50, 22, 255))
    for x in range(30, 480, 192):  # gilt-framed portraits of past chairmen
        _rect(d, x, 90, x + 30, 130, (52, 42, 18, 255))
        _rect(d, x + 3, 93, x + 27, 127, (16, 14, 20, 255))
        _rect(d, x + 10, 100, x + 20, 112, (44, 36, 40, 255))  # dim figure
        _rect(d, x + 12, 96, x + 18, 100, (60, 52, 56, 255))   # face blob
    mid.save(f"{out_dir}/stage_3_mid.png")

    def _hq_near(d, img):
        for x in (0, 440):  # heavy foreground pilasters at screen edges
            _rect(d, x, 0, x + 39, 269, SILHOUETTE)
            d.line([(x + 38 if x else x, 0), (x + 38 if x else x, 269)],
                   fill=(24, 22, 16, 255))
        for x in range(120, 440, 160):  # hanging banner tips
            d.polygon([(x, 0), (x + 22, 0), (x + 11, 34)], fill=SILHOUETTE)
            _px(d, x + 11, 30, (60, 50, 22, 255))
    _near_layer(f"{out_dir}/stage_3_near.png", _hq_near)

    # ---- Stage 4: Digital Vault — vault wheels, deposit boxes, gold on black
    far = Image.new("RGBA", (480, 270), (4, 6, 10, 255))
    d = ImageDraw.Draw(far)
    for x in range(30, 480, 140):  # giant vault wheels, lit from upper-left
        d.ellipse([x, 60, x + 90, 150], outline=(40, 34, 14, 255), width=4)
        d.arc([x, 60, x + 90, 150], 190, 300, fill=(80, 66, 26, 255), width=2)
        d.ellipse([x + 30, 90, x + 60, 120], outline=(60, 50, 20, 255), width=2)
        for ang in range(0, 360, 60):  # rivets + spokes
            lx = x + 45 + int(55 * math.cos(math.radians(ang)))
            ly = 105 + int(55 * math.sin(math.radians(ang)))
            _px(d, lx, ly, P.GOLD)
            d.line([(x + 45 + int(16 * math.cos(math.radians(ang))),
                     105 + int(16 * math.sin(math.radians(ang)))),
                    (x + 45 + int(40 * math.cos(math.radians(ang))),
                     105 + int(40 * math.sin(math.radians(ang))))],
                   fill=(30, 26, 12, 255))
        glow_pool(far, x + 45, 258, 34, P.GOLD)
    for x in range(0, 480, 40):  # laser security grid, very dim
        d.line([(x, 180), (x + 24, 250)], fill=(30, 10, 14, 255))
    far.save(f"{out_dir}/stage_4_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 60):  # deposit box wall with gold clasps
        for y in range(170, 250, 20):
            shade_rect(d, x + 4, y, x + 52, y + 16,
                       ((8, 8, 12, 255), (14, 14, 20, 255), (24, 24, 34, 255)))
            _px(d, x + 28, y + 8, (60, 50, 20, 255))
            _px(d, x + 29, y + 8, P.GOLD_RAMP[0])
    for x in range(50, 480, 180):  # stacked gold coin piles
        for level, w in ((246, 10), (242, 7), (238, 4)):
            _rect(d, x - w, level, x + w, level + 3, (60, 50, 20, 255))
            d.line([(x - w, level), (x + w, level)], fill=P.GOLD)
        _px(d, x, 236, P.GOLD_RAMP[2])
    mid.save(f"{out_dir}/stage_4_mid.png")

    def _vault_near(d, img):
        for x in range(30, 480, 110):  # hanging security chains
            d.line([(x, 0), (x + 3, 40 + (x * 11) % 25)], fill=SILHOUETTE, width=2)
            _px(d, x + 3, 41 + (x * 11) % 25, (60, 50, 20, 255))  # gold hook
        for x in range(70, 480, 220):  # ceiling camera silhouettes
            _rect(d, x, 0, x + 10, 8, SILHOUETTE)
            _px(d, x + 8, 6, P.RED)  # recording LED
    _near_layer(f"{out_dir}/stage_4_near.png", _vault_near)


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
        # spiked ledger hat (anti-stomp tell) — metallic ramp spikes
        hat_y = bottom - 22 + bob
        for s in range(3):
            d.polygon([(cx - 5 + s * 4, hat_y), (cx - 3 + s * 4, hat_y - 4),
                       (cx - 1 + s * 4, hat_y)], fill=P.GRAY_DARK)
            _px(d, cx - 4 + s * 4, hat_y - 2, P.GRAY_RAMP[2])  # spike glint
        # gaunt face: gray hair fringe, cyan glasses, pinched cheeks
        _outline_rect(d, cx - 3, hat_y, cx + 3, hat_y + 6, P.SKIN)
        d.line([(cx - 2, hat_y + 5), (cx + 2, hat_y + 5)], fill=P.SKIN_RAMP[0])
        _px(d, cx - 3, hat_y + 1, P.GRAY)
        _px(d, cx + 3, hat_y + 1, P.GRAY)
        _rect(d, cx - 2, hat_y + 2, cx - 1, hat_y + 3, P.CYAN)   # glasses
        _rect(d, cx + 1, hat_y + 2, cx + 2, hat_y + 3, P.CYAN)
        _px(d, cx, hat_y + 3, P.OUTLINE)  # bridge
        _banker_suit(d, cx, hat_y + 7, bottom - 6, 4, 0)
        legs = [1, -1][i % 2] if anim == "hop_back" else 0
        _rect(d, cx - 3 + legs, bottom - 6, cx - 1 + legs, bottom, P.SUIT_RAMP[0])
        _rect(d, cx + 1 - legs, bottom - 6, cx + 3 - legs, bottom, P.SUIT_RAMP[0])
        if anim == "throw":
            arm = [2, 5, 8, 4][i]
            shade_rect(d, cx + 4, hat_y + 9, cx + 4 + arm, hat_y + 11, P.SUIT_RAMP)
            if i == 2:
                _outline_rect(d, cx + 9, hat_y + 6, cx + 13, hat_y + 10, P.WHITE)
                d.line([(cx + 10, hat_y + 7), (cx + 12, hat_y + 7)], fill=P.GRAY)
        if anim == "death":
            _px(d, cx - 6, hat_y - 2, P.GOLD)
            _px(d, cx + 6, hat_y - 3, P.GOLD)
            _px(d, cx + (i % 2), hat_y - 6, P.GOLD_RAMP[2])
    elif kind == "loan_shark":
        shark_ramp = ((52, 70, 90, 255), (96, 120, 140, 255), (150, 178, 200, 255))
        if anim == "hidden_fin":
            d.polygon([(cx - 3, bottom), (cx, bottom - 6 - bob), (cx + 3, bottom)],
                      fill=shark_ramp[0])
            _px(d, cx, bottom - 4 - bob, shark_ramp[2])  # fin edge light
            return
        rise = {"emerge": [12, 20, 26], "lunge": [28, 30, 28],
                "recover": [24, 22], "death": [22, 16, 10, 4]}[anim][i]
        body_top = bottom - rise
        if body_top + 8 < bottom:  # sinking death frames may have no suit left
            # pinstripe power suit with lapels
            shade_rect(d, cx - 7, body_top + 8, cx + 7, bottom, P.SUIT_RAMP,
                       outline=P.OUTLINE)
            for stripe in range(cx - 5, cx + 6, 3):  # pinstripes
                for y in range(body_top + 10, bottom - 1, 2):
                    _px(d, stripe, y, P.GRAY_RAMP[1])
            d.line([(cx - 6, body_top + 9), (cx - 2, body_top + 12)],
                   fill=P.SUIT_RAMP[0])  # lapel
            d.line([(cx + 6, body_top + 9), (cx + 2, body_top + 12)],
                   fill=P.SUIT_RAMP[0])
            tie_y1 = min(body_top + 16, bottom - 1)  # clamped in-cell
            if tie_y1 >= body_top + 10:
                _rect(d, cx - 1, body_top + 10, cx, tie_y1, P.RED)  # tie
        # shark head: shaded snout, white belly line, gills
        d.polygon([(cx - 8, body_top + 10), (cx + 2, body_top - 2),
                   (cx + 9, body_top + 10)], fill=shark_ramp[1])
        d.line([(cx + 2, body_top - 2), (cx + 9, body_top + 10)],
               fill=shark_ramp[2])  # lit snout edge
        d.line([(cx - 8, body_top + 10), (cx + 2, body_top - 2)],
               fill=shark_ramp[0])  # shadow edge
        for gill in range(3):  # gill slits
            _px(d, cx - 4 + gill, body_top + 6 + gill, shark_ramp[0])
        _px(d, cx + 3, body_top + 4, P.WHITE)  # eye
        _px(d, cx + 4, body_top + 4, P.OUTLINE)  # pupil
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
        shade_rect(d, cx - 8 + glitch, top + 14, cx + 8 - glitch, bottom - 4,
                   P.HOLO_RAMP, outline=P.OUTLINE)
        # holo lapels + cyan tie
        d.line([(cx - 7 + glitch, top + 15), (cx - 1, top + 17)], fill=P.HOLO_RAMP[0])
        d.line([(cx + 7 - glitch, top + 15), (cx + 1, top + 17)], fill=P.HOLO_RAMP[0])
        _rect(d, cx - 1, top + 15, cx, bottom - 6, P.CYAN)
        _px(d, cx, bottom - 6, P.CYAN_RAMP[0])
        # visor head
        shade_rect(d, cx - 5, top, cx + 5, top + 12, P.HOLO_RAMP, outline=P.OUTLINE)
        _rect(d, cx - 3, top + 4, cx + 3, top + 6, (10, 24, 50, 255))  # visor band
        _px(d, cx - 2, top + 5, alpha_body)
        _px(d, cx + 2, top + 5, alpha_body)
        # scanline glitches
        for g in range(3):
            gy = top + 4 + g * 10 + (i * 3) % 7
            _rect(d, cx - 9, gy, cx + 9, gy, (22, 224, 224, 120))
        if anim == "cast" and i >= 2:
            for orb in (-12, 0, 12):
                _px(d, cx + orb, top - 3, P.RED)
                _px(d, cx + orb, top - 4, P.RED_RAMP[2])
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
        # giant suited chairman — the key art's KO'd executives at full power
        lean = {"slam": [0, 2, 4, 6, 2, -4], "charge": [4, 6, 4, 6],
                "stagger": [-6, -8, -6], "coin_volley": [0, 2, 2, 0],
                "phase_change": [0, 0, 2, 4], "idle": [0, 1, 0, -1]}[anim][i]
        crouch = 12 if anim == "slam" and i >= 3 else 0
        body_top = oy + 30 + bob + crouch
        # jacket: vertical 3-band shading, dark power suit
        vshade_rect(d, cx - 16 + lean, body_top, cx + 16 + lean, bottom,
                    ((10, 14, 20, 255), (24, 32, 42, 255), (44, 56, 70, 255)))
        d.rectangle([cx - 16 + lean, body_top, cx + 16 + lean, bottom],
                    outline=P.OUTLINE)
        # wide lapels + white shirt
        d.line([(cx - 14 + lean, body_top + 2), (cx - 3 + lean, body_top + 9)],
               fill=P.OUTLINE)
        d.line([(cx + 14 + lean, body_top + 2), (cx + 3 + lean, body_top + 9)],
               fill=P.OUTLINE)
        d.polygon([(cx - 4 + lean, body_top + 2), (cx + 4 + lean, body_top + 2),
                   (cx + lean, body_top + 8)], fill=P.WHITE)
        tie = P.GOLD if anim != "phase_change" else P.RED
        _rect(d, cx - 2 + lean, body_top + 4, cx + 2 + lean, bottom - 20, tie)
        _rect(d, cx - 1 + lean, bottom - 20, cx + 1 + lean, bottom - 18,
              P.GOLD_RAMP[0] if tie == P.GOLD else P.RED_RAMP[0])  # tie tip
        _px(d, cx - 1 + lean, body_top + 5, P.GOLD_RAMP[2])  # tie knot glint
        # pocket square
        _rect(d, cx - 11 + lean, body_top + 8, cx - 9 + lean, body_top + 9, P.WHITE)
        # arms with cufflink
        arm = 10 if anim in ("slam", "coin_volley") and 1 <= i <= 3 else 4
        shade_rect(d, cx + 15 + lean, body_top + 10, cx + 15 + lean + arm,
                   body_top + 16, ((10, 14, 20, 255), (24, 32, 42, 255),
                                   (44, 56, 70, 255)))
        _px(d, cx + 14 + lean + arm, body_top + 13, P.GOLD)  # cufflink
        # head: jowly executive, silver hair swept back
        _outline_rect(d, cx - 9 + lean, body_top - 20, cx + 9 + lean,
                      body_top - 2, P.SKIN)
        d.line([(cx - 7 + lean, body_top - 4), (cx + 7 + lean, body_top - 4)],
               fill=P.SKIN_RAMP[0])  # jowl shadow
        _px(d, cx - 6 + lean, body_top - 8, P.SKIN_RAMP[0])  # cheek crease
        _px(d, cx + 6 + lean, body_top - 8, P.SKIN_RAMP[0])
        _rect(d, cx - 9 + lean, body_top - 20, cx + 9 + lean, body_top - 15,
              P.GRAY)
        dither_row(d, cx - 8 + lean, cx + 8 + lean, body_top - 14, P.GRAY)
        _px(d, cx - 3 + lean, body_top - 19, P.GRAY_RAMP[2])  # hair shine
        eye = P.RED if anim in ("charge", "phase_change") else P.OUTLINE
        # heavy brows over the eyes
        d.line([(cx - 5 + lean, body_top - 12), (cx - 2 + lean, body_top - 12)],
               fill=P.GRAY_RAMP[0])
        d.line([(cx + 3 + lean, body_top - 12), (cx + 6 + lean, body_top - 12)],
               fill=P.GRAY_RAMP[0])
        _px(d, cx - 3 + lean, body_top - 10, eye)
        _px(d, cx + 4 + lean, body_top - 10, eye)
        d.line([(cx - 2 + lean, body_top - 5), (cx + 2 + lean, body_top - 5)],
               fill=P.SKIN_RAMP[0])  # scowl
        if anim == "stagger":
            _px(d, cx - 12, body_top - 26 + (i % 2), P.GOLD)
            _px(d, cx + 12, body_top - 28 - (i % 2), P.GOLD)
            _px(d, cx + (i % 2) * 4 - 2, body_top - 30, P.GOLD_RAMP[2])
    else:
        # digital demon form: shaded red/black mass with cyan glitches
        top = oy + 10 + bob * 2
        vshade_rect(d, cx - 20, top + 20, cx + 20, bottom, P.DEMON_RAMP)
        d.rectangle([cx - 20, top + 20, cx + 20, bottom], outline=P.OUTLINE)
        for wing_dir in (-1, 1):  # webbed wings with lit leading edge
            tipx = cx + wing_dir * 34
            d.polygon([(cx + wing_dir * 24, top + 30), (tipx, top + 10),
                       (cx + wing_dir * 16, top + 22)], fill=P.DEMON_RAMP[1])
            d.line([(cx + wing_dir * 24, top + 30), (tipx, top + 10)],
                   fill=P.DEMON_RAMP[2])
            _px(d, tipx, top + 10, P.RED)  # wing claw
        shade_rect(d, cx - 12, top, cx + 12, top + 22, P.DEMON_RAMP,
                   outline=P.OUTLINE)
        # burning eyes with glow
        _px(d, cx - 5, top + 8, P.RED)
        _px(d, cx + 5, top + 8, P.RED)
        _px(d, cx - 5, top + 7, P.RED_RAMP[2])
        _px(d, cx + 5, top + 7, P.RED_RAMP[2])
        # jagged maw
        for tooth in range(-3, 4, 2):
            _px(d, cx + tooth, top + 16, P.WHITE)
        for hrn in (-10, 10):  # ramped horns
            d.polygon([(cx + hrn - 2, top), (cx + hrn, top - 8), (cx + hrn + 2, top)],
                      fill=P.RED)
            d.line([(cx + hrn, top - 8), (cx + hrn - 2, top)], fill=P.RED_RAMP[2])
        # core: green when exposed (weak point), pulsing ember otherwise
        core_col = P.GREEN if anim == "core_exposed" else (80, 20, 30, 255)
        d.ellipse([cx - 5, top + 34, cx + 5, top + 44], fill=core_col, outline=P.OUTLINE)
        _px(d, cx - 2, top + 36,
            P.GREEN_RAMP[2] if anim == "core_exposed" else P.RED_RAMP[1])
        for g in range(4):  # glitch scanlines
            gy = top + 6 + g * 18 + (i * 5) % 11
            _rect(d, cx - 22, gy, cx + 22, gy, (22, 224, 224, 100))
        if anim == "death":
            for s in range(i + 1):
                _px(d, cx - 20 + s * 5, bottom - (s * 9) % 60, P.CYAN)
                _px(d, cx - 19 + s * 5, bottom - (s * 9) % 60 - 4, (22, 224, 224, 140))


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


def _banker_suit(d, cx, body_top, bottom, bw, lean, tie=P.RED):
    """Shared suit rendering: 4-tone jacket, lapels, shirt triangle, red tie,
    wrinkle pixels — the KO'd bankers of the key art, upright."""
    shade_rect(d, cx - bw + lean, body_top, cx + bw + lean, bottom, P.SUIT_RAMP,
               outline=P.OUTLINE)
    # lapels: dark V from the shoulders
    d.line([(cx - bw + 1 + lean, body_top + 1), (cx - 1 + lean, body_top + 3)],
           fill=P.SUIT_RAMP[0])
    d.line([(cx + bw - 1 + lean, body_top + 1), (cx + 1 + lean, body_top + 3)],
           fill=P.SUIT_RAMP[0])
    # white shirt triangle + tie
    d.polygon([(cx - 1 + lean, body_top + 1), (cx + 1 + lean, body_top + 1),
               (cx + lean, body_top + 3)], fill=P.WHITE)
    _rect(d, cx - 1 + lean, body_top + 2, cx + lean, bottom - 3, tie)
    _px(d, cx + lean, bottom - 3, P.RED_RAMP[0] if tie == P.RED else P.GOLD_RAMP[0])
    # suit wrinkles
    _px(d, cx - bw + 2 + lean, bottom - 3, P.SUIT_RAMP[0])
    _px(d, cx + bw - 2 + lean, bottom - 5, P.SUIT_RAMP[0])
    # jacket button
    _px(d, cx + 2 + lean, bottom - 4, P.GRAY_RAMP[2])


def _banker_head(d, cx, head_y, lean, kind, dizzy, i):
    """6x7 banker head with per-type features. dizzy = KO stars + X eyes."""
    _outline_rect(d, cx - 3 + lean, head_y, cx + 3 + lean, head_y + 6, P.SKIN)
    d.line([(cx - 2 + lean, head_y + 5), (cx + 2 + lean, head_y + 5)],
           fill=P.SKIN_RAMP[0])  # jaw shadow
    if kind == "junior":
        # young: full dark hair with shine
        _rect(d, cx - 3 + lean, head_y, cx + 3 + lean, head_y + 1, P.CHRIS_HAIR_RAMP[1])
        _px(d, cx - 1 + lean, head_y, P.CHRIS_HAIR_RAMP[2])
    else:
        # manager: balding — gray side tufts, shiny scalp, comb-over strands
        _px(d, cx - 3 + lean, head_y + 1, P.GRAY)
        _px(d, cx + 3 + lean, head_y + 1, P.GRAY)
        _px(d, cx - 1 + lean, head_y, P.SKIN_RAMP[2])  # scalp shine
        dither_row(d, cx - 2 + lean, cx + 2 + lean, head_y, P.GRAY, phase=i % 2)
    if dizzy:
        # X eyes
        _px(d, cx + 1 + lean, head_y + 3, P.OUTLINE)
        _px(d, cx - 2 + lean, head_y + 3, P.OUTLINE)
    else:
        _px(d, cx + 1 + lean, head_y + 3, P.OUTLINE)
        _px(d, cx + 3 + lean, head_y + 3, P.OUTLINE)
        if kind == "manager":
            # permanent angry brow
            d.line([(cx + 1 + lean, head_y + 2), (cx + 3 + lean, head_y + 2)],
                   fill=P.RED_RAMP[0])


def draw_banker_frame(d, ox, oy, size, anim, i, kind):
    """Comedic suited banker — the key art's KO'd villains, animated.
    kind: 'junior' (young, briefcase) or 'manager' (balding, bulkier)."""
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
    bw = 4 if size <= 24 else 5
    # legs: pressed trousers + shoes with shine
    for leg_x, off in ((cx - 3, legs // 2), (cx + 1, -legs // 2)):
        _rect(d, leg_x + off, bottom - 6, leg_x + 2 + off, bottom - 1, P.SUIT_RAMP[0])
        _rect(d, leg_x + off, bottom - 1, leg_x + 2 + off, bottom, P.OUTLINE)
        _px(d, leg_x + off, bottom - 1, P.GRAY_RAMP[1])  # shoe shine
    _banker_suit(d, cx, body_top, bottom - 6, bw, lean)
    # briefcase (walk/panic)
    if anim in ("walk", "panic_run"):
        shade_rect(d, cx + bw + 1 + lean, body_top + 4 + bob, cx + bw + 5 + lean,
                   body_top + 8 + bob, ((26, 18, 10, 255), (58, 40, 22, 255),
                                        (96, 68, 38, 255)), outline=P.OUTLINE)
        _px(d, cx + bw + 3 + lean, body_top + 4 + bob, P.GOLD)  # clasp
    dizzy = anim in ("wall_stun", "death")
    _banker_head(d, cx, body_top - 7, lean, kind, dizzy, i)
    if anim == "alert":
        # red !! telegraph
        _rect(d, cx - 1, oy + 1, cx, oy + 4 + (i % 2), P.RED)
    if dizzy:
        # gold dizzy stars (the key art's signature KO gag)
        _px(d, cx - 5, max(oy + 1, body_top - 9 + (i % 2)), P.GOLD)
        _px(d, cx + 5, max(oy + 1, body_top - 10 - (i % 2)), P.GOLD)
        _px(d, cx + (i % 2) * 2 - 1, max(oy + 1, body_top - 12), P.GOLD_RAMP[2])


def gen_enemy_sheets(out_dir):
    for name, spec in ENEMY_LAYOUTS.items():
        if name not in ("junior_banker", "angry_manager"):
            continue  # specials drawn by gen_special_enemy_sheets
        size = spec["size"]
        cols = max(f for _, f in spec["anims"])
        img = Image.new("RGBA", (cols * size, len(spec["anims"]) * size), P.TRANSPARENT)
        d = ImageDraw.Draw(img)
        kind = "junior" if name == "junior_banker" else "manager"
        for row, (anim, frames) in enumerate(spec["anims"]):
            for i in range(frames):
                draw_banker_frame(d, i * size, row * size, size, anim, i, kind)
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
    """Vault door, 64x64 x4: [0] closed (red security beams over the dark
    slab), [1..3] open — green rim shimmer + spinning yin-yang core. The
    key art's centerpiece as the stage-end reward. Consumed by GateProp."""
    img = Image.new("RGBA", (256, 64), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    core_w = [12, 4, 8]  # apparent core width per open frame (coin-style spin)
    for f in range(4):
        ox = f * 64
        cx, cy = ox + 32, 32
        closed = f == 0
        rim = P.GRAY_DARK if closed else P.GREEN_DARK
        # door slab with lit upper-left arc
        d.ellipse([ox + 2, 2, ox + 61, 61], fill=(12, 16, 26, 255),
                  outline=P.OUTLINE)
        d.ellipse([ox + 4, 4, ox + 59, 59], outline=rim)
        d.arc([ox + 6, 6, ox + 57, 57], 190, 280, fill=(44, 56, 76, 255))
        # concentric rings
        for r, col in ((24, (30, 38, 54, 255)), (17, (22, 28, 42, 255)),
                       (11, (30, 38, 54, 255))):
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col)
        # radial spokes + rivets between them
        for ang in range(0, 360, 45):
            x1 = cx + int(11 * math.cos(math.radians(ang)))
            y1 = cy + int(11 * math.sin(math.radians(ang)))
            x2 = cx + int(24 * math.cos(math.radians(ang)))
            y2 = cy + int(24 * math.sin(math.radians(ang)))
            d.line([(x1, y1), (x2, y2)], fill=(38, 48, 66, 255))
            rx = cx + int(27 * math.cos(math.radians(ang + 22)))
            ry = cy + int(27 * math.sin(math.radians(ang + 22)))
            _px(d, rx, ry, rim)
        if closed:
            # red security beams + dormant core
            for y in range(10, 60, 12):
                _rect(d, ox + 6, y, ox + 57, y + 1, P.RED_RAMP[0])
                _px(d, ox + 8, y, P.RED)
            d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(30, 10, 14, 255),
                      outline=P.OUTLINE)
            _px(d, cx - 2, cy - 2, P.RED)
        else:
            # yin-yang core spin inside a dark porthole
            d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(6, 10, 18, 255),
                      outline=P.GREEN_DARK)
            w = core_w[f - 1]
            x0, x1 = cx - w // 2, cx + w // 2
            d.ellipse([x0, cy - 7, x1, cy + 7], fill=P.BLUE, outline=P.OUTLINE)
            if w > 4:
                d.chord([x0, cy - 7, x1, cy + 7], 90, 270, fill=P.GREEN)
            # rotating green shimmer on the rim
            for ang in range(0, 360, 60):
                gx = cx + int(29 * math.cos(math.radians(ang + f * 20)))
                gy = cy + int(29 * math.sin(math.radians(ang + f * 20)))
                _px(d, gx, gy, P.GREEN)
    img.save(path)


def gen_vignette(path):
    """480x270 always-on overlay (Phase 3): transparent center, soft dark
    corners — the key art's framing. Quadratic falloff past 72% radius."""
    img = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    px = img.load()
    for y in range(270):
        for x in range(480):
            dx = (x - 240) / 240.0
            dy = (y - 135) / 135.0
            dist = (dx * dx + dy * dy) ** 0.5
            a = min(1.0, max(0.0, dist - 0.72) / 0.55)
            alpha = int(120 * a * a)
            if alpha:
                px[x, y] = (2, 4, 10, alpha)
    img.save(path)


def gen_stage1_backgrounds(out_dir):
    """Stage 1 (office) parallax: far wall + windows + framed monitors,
    mid desk rows, near hanging cables. 480x270, tileable horizontally."""
    far = Image.new("RGBA", (480, 270), P.BG_VOID)
    d = ImageDraw.Draw(far)
    for x in range(0, 480, 60):  # wall panels with lit top edge
        d.rectangle([x + 2, 20, x + 57, 250], outline=(10, 22, 38, 255))
        d.line([(x + 3, 21), (x + 56, 21)], fill=(16, 34, 56, 255))
    d.line([(0, 18), (480, 18)], fill=(14, 40, 30, 255))  # ceiling LED strip
    for x in range(0, 480, 16):
        _px(d, x, 18, P.GREEN_DARK)
    for x in range(30, 480, 120):  # night windows: blue glow + city lights
        _rect(d, x, 40, x + 40, 90, (8, 18, 40, 255))
        _rect(d, x + 4, 44, x + 36, 86, (12, 30, 66, 255))
        d.line([(x + 20, 44), (x + 20, 86)], fill=(8, 18, 40, 255))
        for wx, wy in ((x + 8, 74), (x + 14, 66), (x + 27, 78), (x + 31, 60)):
            _px(d, wx, wy, (40, 90, 150, 255))  # distant city windows
        glow_pool(far, x + 20, 258, 28, P.BLUE)
    for x in range(88, 480, 120):  # wall-mounted framed monitors (key art)
        _rect(d, x, 110, x + 30, 132, (10, 20, 34, 255))
        d.rectangle([x, 110, x + 30, 132], outline=(20, 44, 70, 255))
        _rect(d, x + 3, 113, x + 27, 129, (6, 26, 24, 255))
        for line in range(3):
            d.line([(x + 6, 117 + line * 4), (x + 6 + 14 - line * 4, 117 + line * 4)],
                   fill=P.GREEN_DARK)
        glow_pool(far, x + 15, 136, 16, P.GREEN)
    far.save(f"{out_dir}/stage_1_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(0, 480, 96):  # cubicle desks with glowing monitors
        _rect(d, x + 8, 210, x + 80, 216, P.BG_PANEL)      # desk top
        d.line([(x + 8, 210), (x + 80, 210)], fill=(20, 38, 60, 255))
        _rect(d, x + 12, 216, x + 16, 250, P.BG_PANEL)      # legs
        _rect(d, x + 70, 216, x + 74, 250, P.BG_PANEL)
        _rect(d, x + 28, 190, x + 52, 208, P.BG_PANEL)      # monitor
        _rect(d, x + 31, 193, x + 49, 205, (16, 46, 34, 255))  # dim green screen
        for line in range(3):
            d.line([(x + 33, 195 + line * 4), (x + 33 + 11 - line * 3, 195 + line * 4)],
                   fill=P.GREEN_DARK)
        _rect(d, x + 37, 208, x + 43, 209, P.BG_PANEL)      # monitor stand
        glow_pool(mid, x + 40, 214, 14, P.GREEN)
        # office chair silhouette beside the desk
        _rect(d, x + 58, 222, x + 68, 226, (8, 16, 28, 255))
        _rect(d, x + 62, 226, x + 64, 244, (8, 16, 28, 255))
        _rect(d, x + 58, 206, x + 60, 222, (8, 16, 28, 255))
    mid.save(f"{out_dir}/stage_1_mid.png")

    _near_layer(f"{out_dir}/stage_1_near.png",
                lambda d, img: _hanging_cables(d, img, 80))


def gen_core_backgrounds(out_dir, write_far=True):
    """Stage 5 (the Core): circuitry invaded by corruption. The far layer is
    a procedural fallback — main() replaces it with the photo's vault-chamber
    walls when the key art is present, and keeps the committed photo version
    (write_far=False) when it isn't."""
    far = Image.new("RGBA", (480, 270), (3, 4, 10, 255))
    d = ImageDraw.Draw(far)
    for x in range(0, 480, 40):  # circuit traces with solder-point glints
        col = P.RED if (x // 40) % 3 == 0 else P.BLUE_DEEP
        d.line([(x, 0), (x, 130), (x + 20, 150), (x + 20, 270)], fill=col)
        _px(d, x, 130, P.CYAN)
        _px(d, x + 20, 150, scale_color(col, 1.6))
    for y in range(30, 270, 60):
        d.line([(0, y), (480, y)], fill=(14, 22, 50, 255))
    if write_far:
        far.save(f"{out_dir}/stage_5_far.png")

    mid = Image.new("RGBA", (480, 270), P.TRANSPARENT)
    d = ImageDraw.Draw(mid)
    for x in range(20, 480, 110):  # corruption veins with pulsing tips
        d.line([(x, 270), (x + 12, 200), (x - 6, 150), (x + 8, 90)],
               fill=(120, 16, 28, 255), width=2)
        d.line([(x + 2, 268), (x + 13, 202)], fill=(70, 10, 18, 255))  # vein shadow
        for branch_y, branch_dx in ((230, -10), (170, 12)):
            d.line([(x + 6, branch_y), (x + 6 + branch_dx, branch_y - 16)],
                   fill=(90, 12, 22, 255))
        _px(d, x + 8, 90, P.RED)
        glow_disc(mid, x + 8, 90, 8, P.RED)
    for x in range(75, 480, 110):  # infected data pillars
        for y in range(120, 250, 8):
            _px(d, x, y, (20, 40, 90, 255) if y % 16 else P.RED)
    mid.save(f"{out_dir}/stage_5_mid.png")

    def _core_near(d, img):
        for x in range(15, 480, 90):  # falling corrupted data columns
            for y in range((x * 3) % 30, 260, 34):
                _rect(d, x, y, x, y + 10, (60, 10, 16, 255))
                _px(d, x, y + 11, (140, 24, 36, 255))
        for x in range(55, 480, 180):  # torn cable stubs sparking from ceiling
            d.line([(x, 0), (x + 2, 18)], fill=SILHOUETTE, width=2)
            _px(d, x + 2, 19, P.RED)
    _near_layer(f"{out_dir}/stage_5_near.png", _core_near)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/art")
    args = ap.parse_args()
    out = args.out
    for sub in ("characters", "tiles", "props", "enemies", "fx", "backgrounds",
                "ui"):
        os.makedirs(f"{out}/{sub}", exist_ok=True)

    # Two assets come straight from the key-art photo when it is available.
    # Without it, KEEP the committed photo versions instead of silently
    # downgrading them to procedural placeholders.
    import extract_from_key_art as keyart
    has_key_art = os.path.exists(keyart.DEFAULT_SRC)
    portraits_path = f"{out}/characters/portraits.png"
    far5_path = f"{out}/backgrounds/stage_5_far.png"

    gen_player_sheet(f"{out}/characters/chris_sheet.png", "chris")
    gen_player_sheet(f"{out}/characters/flam_sheet.png", "flam")
    gen_zaf_sheet(f"{out}/characters/zaf_sheet.png")
    if has_key_art or not os.path.exists(portraits_path):
        gen_portraits(portraits_path)
    else:
        print("key art not found at", keyart.DEFAULT_SRC,
              "- keeping committed portraits.png")
    gen_coin(f"{out}/props/coin.png")
    gen_tileset(f"{out}/tiles/tileset_office.png")
    gen_tileset(f"{out}/tiles/tileset_datacenter.png", (18, 140, 140, 255), P.CYAN)
    gen_tileset(f"{out}/tiles/tileset_hq.png", (150, 120, 30, 255), P.GOLD)
    gen_tileset(f"{out}/tiles/tileset_vault.png", (120, 100, 24, 255), (255, 220, 120, 255))
    gen_tileset(f"{out}/tiles/tileset_core.png", (140, 30, 40, 255), P.RED)
    gen_stage_backgrounds(f"{out}/backgrounds")
    write_far5 = has_key_art or not os.path.exists(far5_path)
    if not write_far5:
        print("key art not found - keeping committed stage_5_far.png")
    gen_core_backgrounds(f"{out}/backgrounds", write_far=write_far5)
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
    gen_hud_atlas(f"{out}/ui/hud_atlas.png")
    gen_vignette(f"{out}/fx/vignette.png")
    if has_key_art:
        src = Image.open(keyart.DEFAULT_SRC).convert("RGBA")
        keyart.make_portraits(src, portraits_path)
        keyart.make_vault_wall(src, far5_path)
        print("key-art extraction applied (portraits, stage_5_far)")
    zaf_path = f"{out}/characters/zaf_portrait.png"
    if os.path.exists(keyart.ZAF_SRC):
        keyart.make_zaf_portrait(
                Image.open(keyart.ZAF_SRC).convert("RGBA"), zaf_path)
        print("Zaf portrait extracted")
    elif not os.path.exists(zaf_path):
        print("WARNING: no Zaf concept art and no committed zaf_portrait.png")
    print("placeholder art generated ->", out)


if __name__ == "__main__":
    main()
