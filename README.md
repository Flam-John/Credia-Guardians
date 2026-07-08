# Credia Guardians

A retro 16-bit action platformer built in **Godot 4.7**. Two developers —
**Chris** and **Flam** — jack into the CrediaBank system to purge the
corrupted bankers across five stages and delete **The Chairman** at the core.

![version](https://img.shields.io/badge/version-1.0.0-39ff5a)

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

## The game

- **Chris** — 6 HP, Firewall Shield (hold to block frontal hits). The tank.
- **Flam** — 4 HP, faster, Overclock Dash (i-frames, 2 air charges). The speedster.
- Each stage: 100 Credia Coins, 3 security nodes (hold E), hidden vaults,
  checkpoints, an exit gate — and a rank on clear (**S** = all coins, all
  nodes, under par, deathless).
- Stage 5 ends at the three-phase CEO. Hit him only when he's staggered —
  or, in demon form, when the core glows green.

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

Made by FLAMUPIA. Built with [Godot Engine](https://godotengine.org).
