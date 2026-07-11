"""Canonical Credia Guardians palette — single source of truth for artgen.

Mirrors docs/SPRITE_LIST.md. If a color changes here, regenerate all sheets.
"""

BG_VOID = (5, 10, 18, 255)          # 050A12
BG_PANEL = (10, 20, 34, 255)        # 0A1422
BLUE_DEEP = (17, 72, 184, 255)      # 1148B8
BLUE = (38, 168, 255, 255)          # 26A8FF
CYAN = (22, 224, 224, 255)          # 16E0E0
GREEN = (57, 255, 90, 255)          # 39FF5A
GREEN_DARK = (31, 168, 60, 255)     # 1FA83C
GOLD = (255, 200, 37, 255)          # FFC825
RED = (255, 48, 64, 255)            # FF3040
WHITE = (232, 244, 255, 255)        # E8F4FF
GRAY = (122, 140, 160, 255)         # 7A8CA0
GRAY_DARK = (58, 70, 86, 255)       # 3A4656
SKIN = (232, 176, 138, 255)         # E8B08A
SKIN_SHADE = (184, 124, 92, 255)    # B87C5C
OUTLINE = (2, 6, 12, 255)           # 02060C
SUIT = (16, 24, 32, 255)            # hero tactical suit base
TRANSPARENT = (0, 0, 0, 0)

# Character-specific
CHRIS_HAIR = (42, 30, 22, 255)      # short dark
FLAM_HAIR = (122, 78, 42, 255)      # long brown

# --- Ramps (dark, base, light) — artgen v2 shading. The key art never uses
# --- a hue in a single tone; these triples are sampled from it.
ARMOR_RAMP = ((6, 10, 14, 255), (16, 24, 32, 255), (36, 56, 48, 255))
SUIT_RAMP = ((34, 42, 54, 255), (58, 70, 86, 255), (92, 108, 128, 255))
GRAY_RAMP = ((58, 70, 86, 255), (122, 140, 160, 255), (176, 190, 205, 255))
SKIN_RAMP = ((184, 124, 92, 255), (232, 176, 138, 255), (255, 216, 182, 255))
GREEN_RAMP = ((20, 110, 40, 255), (31, 168, 60, 255), (57, 255, 90, 255))
CYAN_RAMP = ((10, 110, 110, 255), (22, 224, 224, 255), (170, 255, 255, 255))
BLUE_RAMP = ((12, 44, 110, 255), (17, 72, 184, 255), (38, 168, 255, 255))
GOLD_RAMP = ((140, 100, 20, 255), (255, 200, 37, 255), (255, 236, 150, 255))
RED_RAMP = ((140, 18, 32, 255), (255, 48, 64, 255), (255, 130, 140, 255))
PANEL_RAMP = ((4, 8, 16, 255), (10, 20, 34, 255), (20, 38, 60, 255))
CHRIS_HAIR_RAMP = ((22, 15, 10, 255), (42, 30, 22, 255), (78, 56, 40, 255))
FLAM_HAIR_RAMP = ((74, 46, 24, 255), (122, 78, 42, 255), (176, 120, 70, 255))
DEMON_RAMP = ((18, 4, 8, 255), (46, 8, 16, 255), (96, 20, 32, 255))
HOLO_RAMP = ((10, 34, 74, 255), (20, 60, 120, 255), (40, 110, 190, 255))
