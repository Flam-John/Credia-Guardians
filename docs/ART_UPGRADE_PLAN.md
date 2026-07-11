# Graphics Upgrade Plan — "Make it look like the key art"

> **Status (v1.4.0)**: the narrowed scope — heroes, bankers, backgrounds —
> SHIPPED. Palette ramps + pixkit toolkit, hero sheets v2 (segmented armor,
> piping, capes, faces), all banker/CEO sheets v2 (4-tone suits, lapels,
> per-type faces), 3-layer parallax for all 5 stages with glow pools, and
> portraits + stage-5 vault wall extracted straight from the key art
> (tools/artgen/extract_from_key_art.py). Still open below: tilesets, vault
> door prop, HUD atlas, Phase 2 (Aseprite), Phase 3 (in-engine glow).

Source of truth: `CHRIS_FLAM_LEVEL_1_VICTORY.png`. Current placeholders are
3-4 flat colors per sprite; the key art's identity comes from **glow, depth,
and material detail**. This plan closes that gap in three phases.

## What the key art actually does (design analysis)

1. **Everything emits or reflects light.** Dark surfaces carry green/cyan
   rim-light; the floor has glow pools reflecting signage; nothing is flat.
2. **Color ramps, not single colors.** Every hue appears in 3-4 tones
   (armor: near-black -> dark green-gray -> green edge highlight).
3. **Heroes are ARMORED, not smooth.** Segmented plates with green circuit
   piping between segments, glowing chest logo, shoulder pads, capes,
   readable faces (skin two-tone + hair shading + expression).
4. **The world is layered**: foreground floor tiles with grout + debris,
   mid-ground vault door (concentric rings around the yin-yang core),
   background server walls with blinking LEDs and framed monitors.
5. **UI is physical**: HUD elements sit in beveled dark frames with
   1px metallic borders; HP segments are glossy pills; text has backing.
6. **Comedy contrast**: KO'd bankers are detailed too — wrinkled suits,
   askew glasses, gold dizzy stars — the humor needs the detail to land.

## Phase 1 — artgen v2 (procedural, NO Aseprite needed — start now)

Upgrade `tools/artgen` while keeping determinism and the exact sheet
layouts/filenames (zero code changes in the game):

- **Palette ramps** in `palette.py`: for each base hue add `_DARK`,
  `_MID`, `_LIGHT` (e.g. suit: #0A0F14 / #142019 / #39FF5A edge). Add
  shared helpers: `shade(rect, light_from_top_left)`, `dither(area, a, b)`,
  `rim(edge_pixels, color)`, `glow_disc(center, color)` (radial 2-step).
- **Heroes (32x32)**: segmented armor (3 plate bands with 1px piping gaps
  in GREEN), shoulder pad, 2-tone skin + browed eyes, hair with shine line,
  cape hint behind torso (Flam), forearm shield emitter (Chris), glowing
  chest logo 2px blue/green. Idle gains a 1px cape/hair sway layer.
- **Bankers**: 4-tone suits with lapels + wrinkle pixels, white shirt
  triangle, faces with glasses variant, comb-over/ balding variants per
  enemy type, gold dizzy stars sheet reused.
- **Tilesets**: grout lines between floor tiles, per-theme circuit traces
  in tile interiors, 2px glow strip with 1px bloom row above walkable
  edges, animated LED decor tile (2-frame, new atlas coords — builder
  gains an optional animated tile).
- **Floor glow pools**: new semi-transparent overlay props (green/blue
  ellipses) the levelgen can place under monitors/nodes.
- **Exit gate -> VAULT DOOR (64x64)**: concentric ring circles, radial
  spokes, yin-yang core that spins (3 frames) when unlocked — the key
  art's centerpiece becomes the stage-end reward.
- **Backgrounds**: third parallax layer per stage (near layer: hanging
  cables / railing silhouettes), blinking-LED pixels on stage-2 racks
  (2-frame flip via two textures + AnimatedSprite... or keep static +
  brighter), stage-5 gets the full vault-chamber wall from the art.
- **HUD atlas**: beveled portrait frame (metal 2-tone border), glossy HP
  pill (highlight pixel top-left), coin icon with rim, panel 9-patch for
  HI-SCORE backing. `hud.gd` swaps ColorRects for these textures.
- **Monitors**: framed with 1px cyan border + stand, 3 text-line variants,
  subtle glow pool beneath.

## Phase 2 — Aseprite hand-polish via pixel-mcp (BLOCKED: needs Aseprite)

`pixel-plugin` is installed (marketplace + plugin, user scope). It drives
**Aseprite v1.3+**, which is not on this machine. Unblock by either:
- buying Aseprite (~€19.99, Steam or itch.io — the Steam build works), or
- compiling it free from source (CMake+Ninja+Skia, ~1-2h, doable on request).
Then run `/pixel-setup` in a fresh Claude Code session.

With it: hand-detail passes the generator can't reach —
- hero faces/hair to match the portraits in the art (the single highest-
  impact swap: HUD portraits + character select),
- CEO suit/demon sheets (the art's drama deserves real frames),
- animation polish: anticipation frames on attack_3, cape follow-through,
  squash on landings — exported with the SAME grid/filenames so the game
  ingests them untouched. Retro palette tools (NES/PICO-8 constraints)
  keep everything on-model.

## Phase 3 — in-engine presentation (no assets, pure Godot)

- **Glow pass**: additive `CanvasItemMaterial` on coin glints, node cores,
  gate energy, dash ghosts — cheap bloom without WorldEnvironment.
- **Scanlines default ON** (the art is a CRT frame; keep the Options out).
- **Vignette overlay** (dark corners, 1 texture) — the art's framing.
- **Ambient particles per stage**: dust motes (S1), digital rain drips
  (S2), gold sparkle (S4), red corruption embers (S5).
- **Victory screen rebuild** to mirror the art: vault door center, heroes
  posed at 2x scale, KO'd bankers scattered, monitor props flipped green.

## Order & effort

| Step | Needs | Effort |
|---|---|---|
| 1. Palette ramps + helpers | — | S |
| 2. Tilesets + glow pools + vault door | — | M |
| 3. Heroes + bankers v2 | — | M |
| 4. HUD atlas + monitors | — | S |
| 5. Backgrounds 3-layer | — | M |
| 6. Phase 3 in-engine pass | — | S-M |
| 7. Aseprite portraits/CEO/animation polish | Aseprite | M (after purchase/build) |

Acceptance per step: regenerate -> screenshot diff vs key art -> suite
green -> commit. Sheet layouts and filenames NEVER change — art upgrades
must be invisible to code.
