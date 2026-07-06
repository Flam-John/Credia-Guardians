# Sprite List & Art Direction

## Palette (canonical — extracted from CHRIS_FLAM_LEVEL_1_VICTORY.png)

| Name | Hex | Use |
|---|---|---|
| `BG_VOID` | `#050A12` | Deepest background |
| `BG_PANEL` | `#0A1422` | Panels, mid backgrounds |
| `BLUE_DEEP` | `#1148B8` | Tech shadows, vault metal |
| `BLUE` | `#26A8FF` | Tech mid, logo blue half |
| `CYAN` | `#16E0E0` | Highlights, data rain, energy |
| `GREEN` | `#39FF5A` | Hero accent, UI positive, logo green half |
| `GREEN_DARK` | `#1FA83C` | Green shading |
| `GOLD` | `#FFC825` | Coins score, ranks, stars |
| `RED` | `#FF3040` | Corruption, damage, danger ONLY |
| `WHITE` | `#E8F4FF` | Text, flashes |
| `GRAY` | `#7A8CA0` | Banker suits, neutral metal |
| `GRAY_DARK` | `#3A4656` | Suit shading, outlines vs black |
| `SKIN` | `#E8B08A` / shade `#B87C5C` | Faces, hands |
| `OUTLINE` | `#02060C` | Universal sprite outline |

Rules: heroes = black tactical suits with `GREEN` glow lines + small `BLUE/GREEN` chest coin logo. Enemies = `GRAY` business suits, `RED` ties (corruption tell). Red never appears on anything friendly. 1 px `OUTLINE` on all entities for readability against busy backgrounds.

## Player sprites — Chris & Flam (32×32 frames, same rig/rows, different heads+palette details)

Chris: short dark hair, broader silhouette, subtle shield emitter on left forearm.
Flam: long brown hair (2-frame hair sway in idle), slimmer, leg thruster lines (dash tell).

| Row | Animation | Frames |
|---|---|---|
| 0 | idle | 4 |
| 1 | run | 8 |
| 2 | jump (rise) | 2 |
| 3 | fall | 2 |
| 4 | double_jump (flip) | 4 |
| 5 | dash | 3 |
| 6 | attack_1 (jab) | 4 |
| 7 | attack_2 (cross) | 4 |
| 8 | attack_3 (finisher) | 5 |
| 9 | air_attack | 4 |
| 10 | hurt | 2 |
| 11 | death | 6 |
| 12 | shield (Chris) / dash_charge (Flam) | 3 |
| 13 | victory pose | 4 |
| 14 | interact (node hold) | 2 |
| 15 | spawn/teleport-in | 4 |

Sheet: 16 rows × up to 16 cols → 512×512 actually; artgen packs to 512×256 by pairing short rows — final layout defined in `tools/artgen/layout.py` and mirrored in the `SpriteFrames` builder.

## Enemy sprites

| Enemy | Frame | Animations (frames) |
|---|---|---|
| Junior Banker (24×24) | nervous intern, huge briefcase | walk (4), panic_run (4), hurt (1), death/ko (3) |
| Angry Manager (32×32) | red-faced, rolled sleeves | idle (2), alert "!!" (2), charge (4), wall_stun dizzy (3), hurt (1), death (3) |
| Auditor (24×32) | glasses glint, spiked ledger hat | hop_back (3), idle (2), throw (4), hurt (1), death (3) |
| Loan Shark (40×40) | shark head in pinstripe suit | hidden_fin (2), emerge (3), lunge (3), recover (2), hurt (1), death (4) |
| Corrupted AI Banker (48×48) | glitching hologram banker | float (4), teleport_out/in (3+3), cast (4), summon (3), stagger (2), death (5) |
| CEO p1–2 (64×96) | giant suit, gold tie→red | idle (4), slam (6), coin_volley (4), charge (4), stagger (3), phase_change (4) |
| CEO p3 (96×96) | digital demon, red/black | float (4), laser_sweep (6), teleport (4), spiral_cast (4), core_exposed (3), death (8) |

## Tiles & props style

16×16 tiles. Terrain reads as **silhouette first**: walkable surfaces get a 1 px `GREEN` or `CYAN` top-edge light strip (stage-dependent), interiors stay dark (`BG_PANEL`/`BLUE_DEEP`). Hazards always carry `RED`. Decor (monitors, cables, plants) uses ≤ 3 colors per tile. Stage accent: S1 warm blue + monitor glow, S2 cyan rain, S3 gold marble, S4 gold-on-black + laser red, S5 blue circuitry invaded by red veins.

## Collectible: Credia Coin
16×16, the bank's blue/green yin-yang logo as a spinning coin — 6 frames (front → edge → back), `GOLD` rim glint on frame 1. This is the single most-seen sprite; polish first.

## Placeholder generation (v0)
`tools/artgen/generate_placeholders.py` (Python + Pillow) draws every sheet above: correct dimensions, palette-true, simple-but-readable shapes (capsule bodies, visor heads, briefcases as rectangles), real frame variation (limb offsets per frame) so animation timing is testable. Deterministic (seeded), re-runnable, one command: `python tools/artgen/generate_placeholders.py --out assets/art`.
