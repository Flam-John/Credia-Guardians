"""Extract character portraits and the stage-5 vault-wall texture from the
key art (CHRIS_FLAM_LEVEL_1_VICTORY.png) — the one place we can take pixels
straight from the source instead of approximating them.

Deterministic: fixed crop boxes (fractions of the source size), LANCZOS
downscale, adaptive palette quantize. Run AFTER generate_placeholders.py —
it overwrites portraits.png with the real faces.

Usage:  python tools/artgen/extract_from_key_art.py [--src <photo>] [--out assets/art] [--debug]
"""
from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

DEFAULT_SRC = os.path.expanduser(
    "~/OneDrive/Υπολογιστής/CHRIS_FLAM_LEVEL_1_VICTORY.png")
# Zaf (the boss) concept art — one-time source for his dialog portrait.
ZAF_SRC = os.path.expanduser(
    "~/Downloads/ChatGPT_Image_18_2026_10_03_09_...jpeg")
# Face region of the Zaf concept (fractions): hair top to beard bottom.
ZAF_FACE = (0.20, 0.02, 0.72, 0.78)

# Crop boxes as fractions (x0, y0, x1, y1) of the source image — the INNER
# area of each corner portrait frame (measured against the 1402x1122 photo;
# the old boxes clipped Flam's cheek and both chins).
CHRIS_FACE = (0.023, 0.025, 0.088, 0.123)
FLAM_FACE = (0.679, 0.021, 0.737, 0.124)
# Vault-chamber walls with the in-world propaganda monitors; stop above the
# KO'd bankers on the floor.
VAULT_WALL_L = (0.000, 0.240, 0.175, 0.610)
VAULT_WALL_R = (0.800, 0.240, 0.975, 0.610)


def _crop(src: Image.Image, box) -> Image.Image:
    w, h = src.size
    return src.crop((int(box[0] * w), int(box[1] * h),
                     int(box[2] * w), int(box[3] * h)))


def _quantize(img: Image.Image, colors: int) -> Image.Image:
    return img.convert("RGB").quantize(
        colors=colors, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGBA")


def make_portraits(src: Image.Image, out_path: str) -> Image.Image:
    """64x32: two 32x32 framed portraits (Chris, Flam) — same layout the
    HUD/character-select/victory screens already slice."""
    img = Image.new("RGBA", (64, 32), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    for idx, box in enumerate((CHRIS_FACE, FLAM_FACE)):
        ox = idx * 32
        face = _crop(src, box)
        # cover-crop: scale preserving aspect to FILL 26x26, then trim the
        # overflow centered — the old square resize squashed the tall crops
        # and mangled the faces
        scale = max(26.0 / face.width, 26.0 / face.height)
        face = face.resize((max(26, round(face.width * scale)),
                            max(26, round(face.height * scale))),
                           Image.Resampling.LANCZOS)
        left = (face.width - 26) // 2
        top = (face.height - 26) // 2
        face = _quantize(face.crop((left, top, left + 26, top + 26)), 24)
        d.rectangle([ox + 2, 2, ox + 29, 29], fill=P.BG_PANEL, outline=P.GREEN_DARK)
        img.paste(face, (ox + 3, 3))
        d.rectangle([ox + 2, 2, ox + 29, 29], outline=P.GREEN_DARK)  # re-frame
    img.save(out_path)
    return img


def make_zaf_portrait(src: Image.Image, out_path: str) -> Image.Image:
    """48x48 framed dialog portrait for the tutorial (cover-crop, quantized
    to pixel-art color counts like the hero portraits)."""
    img = Image.new("RGBA", (48, 48), P.TRANSPARENT)
    d = ImageDraw.Draw(img)
    face = _crop(src, ZAF_FACE)
    scale = max(44.0 / face.width, 44.0 / face.height)
    face = face.resize((max(44, round(face.width * scale)),
                        max(44, round(face.height * scale))),
                       Image.Resampling.LANCZOS)
    left = (face.width - 44) // 2
    top = (face.height - 44) // 2
    face = _quantize(face.crop((left, top, left + 44, top + 44)), 24)
    d.rectangle([0, 0, 47, 47], fill=P.BG_PANEL, outline=P.GREEN_DARK)
    img.paste(face, (2, 2))
    d.rectangle([0, 0, 47, 47], outline=P.GREEN_DARK)
    d.rectangle([1, 1, 46, 46], outline=P.OUTLINE)
    img.save(out_path)
    return img


def make_vault_wall(src: Image.Image, out_path: str) -> Image.Image:
    """480x270 stage-5 far layer: photo wall left, mirrored right, darkened
    center gap for the procedural corruption veins to live in."""
    wall_l = _quantize(_crop(src, VAULT_WALL_L).resize(
        (168, 270), Image.Resampling.LANCZOS), 32)
    wall_r = _quantize(_crop(src, VAULT_WALL_R).resize(
        (168, 270), Image.Resampling.LANCZOS), 32)
    img = Image.new("RGBA", (480, 270), (3, 4, 10, 255))
    img.paste(wall_l, (0, 0))
    img.paste(wall_r, (312, 0))
    # dim both walls toward the background (they sit far behind gameplay)
    veil = Image.new("RGBA", (480, 270), (3, 4, 10, 120))
    img = Image.alpha_composite(img, veil)
    d = ImageDraw.Draw(img)
    # center: giant dormant vault-door silhouette between the walls
    for r, col in ((100, (14, 22, 50, 255)), (74, (10, 16, 38, 255)),
                   (48, (14, 22, 50, 255)), (22, (24, 40, 80, 255))):
        d.ellipse([240 - r, 135 - r, 240 + r, 135 + r], outline=col, width=3)
    d.ellipse([228, 123, 252, 147], fill=(10, 16, 38, 255), outline=(24, 40, 80, 255))
    d.chord([228, 123, 252, 147], 90, 270, fill=(16, 60, 40, 255))  # yin-yang hint
    img.save(out_path)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--out", default="assets/art")
    ap.add_argument("--debug", action="store_true",
                    help="also save 4x contact sheet next to this script")
    args = ap.parse_args()
    src = Image.open(args.src).convert("RGBA")
    portraits = make_portraits(src, f"{args.out}/characters/portraits.png")
    wall = make_vault_wall(src, f"{args.out}/backgrounds/stage_5_far.png")
    zaf_out = f"{args.out}/characters/zaf_portrait.png"
    if os.path.exists(ZAF_SRC):
        make_zaf_portrait(Image.open(ZAF_SRC).convert("RGBA"), zaf_out)
    elif not os.path.exists(zaf_out):
        print("WARNING: Zaf concept art missing and no committed portrait -",
              ZAF_SRC)
    else:
        print("Zaf concept art not found - keeping committed zaf_portrait.png")
    if args.debug:
        dbg = Image.new("RGBA", (64 * 4 + 480, 270), (30, 30, 30, 255))
        dbg.paste(portraits.resize((256, 128), Image.Resampling.NEAREST), (0, 0))
        dbg.paste(wall, (256, 0))
        dbg.save(os.path.join(os.path.dirname(__file__), "_debug_extract.png"))
    print("key-art extraction ->", args.out)


if __name__ == "__main__":
    main()
