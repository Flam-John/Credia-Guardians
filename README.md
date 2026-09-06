# Credia Guardians

A retro 16-bit action platformer built in **Godot 4.7**. Two developers —
**Chris** and **Flam** — jack into the CrediaBank system to purge the
corrupted bankers across five stages and delete **The Chairman** at the core.

![version](https://img.shields.io/badge/version-1.0.0-39ff5a)

This is the **first complete version (v1.0.0)** of the game.

## Play

- **Windows build**: run `build/credia_guardians.exe` (or grab the release zip)
- **From source**: install Godot 4.7, then `godot --path .` (or double-click `run.bat`)

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D or ←/→ | Left stick / D-pad |
| Jump / double jump | Space or Z | A |
| Attack (3-hit combo) | J or X | X |
| Dash | K or C | RB / B |
| Ability (Chris: shield) | L or V (hold) | LB / Y |
| Interact (security nodes) | E (hold) | D-pad up |
| Pause | Esc | Start |

Keys are rebindable in Options. All settings and 3 save slots persist.

## What's included

- **2 playable characters**, each with their own feel and moveset:
  - **Chris** — 6 HP, Firewall Shield (hold to block frontal hits). The tank.
  - **Flam** — 4 HP, faster, Overclock Dash (i-frames, 2 air charges). The speedster.
- **5 full stages**, each with 100 Credia Coins to collect, 3 security nodes
  (hold E to hack), hidden vaults, checkpoints, an exit gate, and a
  clear rank (**S** = all coins, all nodes, under par, deathless).
- **7 enemy types** — junior bankers, AI bankers (and an elite variant),
  angry managers, regional managers, auditors, and loan sharks — each with
  their own AI behavior.
- **A three-phase final boss** — The Chairman/CEO — hit him only when he's
  staggered, or in his demon form, when the core glows green.
- **5 hacking minigames** woven into the security-node system: Circuit
  Bypass, Code Review, Presentation Pace, Server Cooling, and Ticket Blitz.
- **An in-game tutorial** — Zaf, Chris & Flam's boss, materializes as a
  ghost overlay on stage 1 to walk new players through the basics without
  leaving the real stage.
- **Full menu flow**: splash screen, main menu, character select, stage
  select, a Boss Rush mode, options (with rebindable controls), 3 save
  slots, stage clear / game over / victory screens, and an intro cutscene.
- **Placeholder art, SFX, and music generated deterministically** by
  in-repo Python tools (see below) — no external assets required to build.
- **Automated test suite** (GUT) covering player state machine, HUD, enemy
  AI, and level systems.

## Development

Everything placeholder is generated and deterministic:

```
python tools/artgen/generate_placeholders.py --out assets/art   # sprites/tiles
python tools/audiogen/generate_audio.py                          # sfx + music
python tools/levelgen/stage_1_layout.py                          # stage maps
python tools/levelgen/stages_2_4_layout.py
python tools/levelgen/stage_5_layout.py
```

Levels are ASCII text (`data/levels/*.txt`) with entity markers — legend in
`src/levels/level_base.gd`. Tests (GUT):

```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit
```

Design docs (GDD, TDD, FSM diagrams, milestone plan…) live in `docs/`.

## Credits

Made by FLAMUPIA. Built with [Godot Engine](https://godotengine.org).
