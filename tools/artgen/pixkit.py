"""Pixel-art shading toolkit for artgen v2 — deterministic, Pillow-only.

Everything the key art does that flat placeholders don't: color ramps
(dark -> base -> light), top-left shading, rim light, dithering, and
2-step radial glow. Shared by all sheet generators.
"""
from __future__ import annotations

from PIL import Image, ImageDraw


def shade_rect(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
               ramp, outline=None) -> None:
    """Fill with ramp base, light on top+left edge, dark on bottom+right.

    ramp = (dark, base, light). Rects smaller than 3px in a dimension
    degrade gracefully (light wins over dark).
    """
    dark, base, light = ramp
    d.rectangle([x0, y0, x1, y1], fill=base)
    if y1 > y0:
        d.line([(x0, y1), (x1, y1)], fill=dark)      # bottom shadow
    if x1 > x0:
        d.line([(x1, y0 + 1), (x1, y1)], fill=dark)  # right shadow
    d.line([(x0, y0), (x1, y0)], fill=light)         # top light
    if y1 > y0 + 1:
        d.line([(x0, y0), (x0, y1 - 1)], fill=light)  # left light
    if outline is not None:
        d.rectangle([x0, y0, x1, y1], outline=outline)


def vshade_rect(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
                ramp) -> None:
    """Vertical 3-band fill: light top third, base middle, dark bottom third.
    For larger surfaces (torsos, columns) where edge shading is too subtle."""
    dark, base, light = ramp
    h = y1 - y0 + 1
    d.rectangle([x0, y0, x1, y0 + max(1, h // 3) - 1], fill=light)
    d.rectangle([x0, y0 + max(1, h // 3), x1, y1 - max(1, h // 4)], fill=base)
    d.rectangle([x0, y1 - max(1, h // 4) + 1, x1, y1], fill=dark)


def dither(d: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int,
           c1, c2) -> None:
    """Checkerboard dither between two colors — retro texture/gradient."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d.point((x, y), fill=c1 if (x + y) % 2 == 0 else c2)


def dither_row(d: ImageDraw.ImageDraw, x0: int, x1: int, y: int, c,
               phase: int = 0) -> None:
    """Every-other-pixel row of a single color over what's already there."""
    for x in range(x0, x1 + 1):
        if (x + phase) % 2 == 0:
            d.point((x, y), fill=c)


def glow_disc(img: Image.Image, cx: int, cy: int, r: int, color) -> None:
    """2-step additive-looking radial glow, alpha-composited (halo + core)."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    rr, g, b = color[0], color[1], color[2]
    d.ellipse([cx - r, cy - r // 2, cx + r, cy + r // 2], fill=(rr, g, b, 40))
    r2 = max(1, r // 2)
    d.ellipse([cx - r2, cy - r2 // 2, cx + r2, cy + r2 // 2], fill=(rr, g, b, 80))
    img.alpha_composite(overlay)


def glow_pool(img: Image.Image, cx: int, floor_y: int, w: int, color) -> None:
    """Elliptical light pool on the floor under a glowing sign/monitor."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    rr, g, b = color[0], color[1], color[2]
    d.ellipse([cx - w, floor_y - 3, cx + w, floor_y + 3], fill=(rr, g, b, 34))
    d.ellipse([cx - w // 2, floor_y - 2, cx + w // 2, floor_y + 2],
              fill=(rr, g, b, 60))
    img.alpha_composite(overlay)


def scale_color(color, factor: float):
    """Darken (<1) or brighten (>1) an RGBA tuple, clamped."""
    r, g, b = (min(255, max(0, int(c * factor))) for c in color[:3])
    a = color[3] if len(color) > 3 else 255
    return (r, g, b, a)
