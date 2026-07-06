# Animation List

Convention: `SpriteFrames` animation names are exactly these strings; FSM states play by name. FPS values are per-animation (retro = low-fps snappy). "Loop" = loops until state exits.

## Player (Chris & Flam — identical names/timings)

| Animation | Frames | FPS | Loop | Notes / events |
|---|---|---|---|---|
| `idle` | 4 | 6 | ✔ | Breathing bob; Flam hair sway |
| `run` | 8 | 12 | ✔ | Footstep dust on frames 0, 4 |
| `jump` | 2 | 8 | ✖ | Hold last frame while rising |
| `fall` | 2 | 8 | ✔ | |
| `double_jump` | 4 | 14 | ✖ | Flip; then falls into `fall` |
| `dash` | 3 | 18 | ✔ | Afterimage ghost every 0.03 s |
| `attack_1` | 4 | 16 | ✖ | Hitbox on frames 1–2 (AnimationPlayer track) |
| `attack_2` | 4 | 16 | ✖ | Hitbox frames 1–2 |
| `attack_3` | 5 | 14 | ✖ | Hitbox frames 2–3, bigger arc, +knockback |
| `air_attack` | 4 | 16 | ✖ | Hitbox frames 1–2 |
| `hurt` | 2 | 10 | ✖ | Plus white flash + knockback |
| `death` | 6 | 8 | ✖ | Freeze last frame → respawn fade |
| `shield` (Chris) | 3 | 10 | ✔ | Bubble shimmer |
| `dash_charge` (Flam) | 3 | 10 | ✔ | Plays while dash on cooldown < 100 % (subtle) |
| `interact` | 2 | 6 | ✔ | Node activation hold |
| `victory` | 4 | 6 | ✔ | Stage clear pose (key-art fist pump) |
| `spawn` | 4 | 12 | ✖ | Teleport-in at checkpoints |

## Enemies

| Enemy | Animation | Frames | FPS | Loop |
|---|---|---|---|---|
| Junior Banker | `walk` 4 @8 ✔ · `panic_run` 4 @14 ✔ · `hurt` 1 @— · `death` 3 @10 ✖ |
| Angry Manager | `idle` 2 @4 ✔ · `alert` 2 @10 ✖ · `charge` 4 @14 ✔ · `wall_stun` 3 @6 ✔ (dizzy stars FX) · `hurt` 1 · `death` 3 @10 ✖ |
| Auditor | `idle` 2 @4 ✔ · `hop_back` 3 @12 ✖ · `throw` 4 @12 ✖ (spawn projectile frame 2) · `hurt` 1 · `death` 3 @10 ✖ |
| Loan Shark | `hidden_fin` 2 @4 ✔ · `emerge` 3 @14 ✖ · `lunge` 3 @16 ✖ · `recover` 2 @6 ✔ · `hurt` 1 · `death` 4 @10 ✖ |
| Corrupted AI Banker | `float` 4 @6 ✔ · `teleport_out`/`teleport_in` 3+3 @14 ✖ · `cast` 4 @10 ✖ (volley frame 2) · `summon` 3 @10 ✖ · `stagger` 2 @6 ✔ · `death` 5 @10 ✖ |
| CEO p1/p2 | `idle` 4 @5 ✔ · `slam` 6 @12 ✖ (shockwave frame 3, screen shake) · `coin_volley` 4 @10 ✖ · `charge` 4 @12 ✔ · `stagger` 3 @6 ✔ · `phase_change` 4 @8 ✖ |
| CEO p3 | `float` 4 @6 ✔ · `laser_sweep` 6 @10 ✖ · `teleport` 4 @14 ✖ · `spiral_cast` 4 @10 ✔ · `core_exposed` 3 @6 ✔ · `death` 8 @6 ✖ (dissolve) |

All enemies: `hurt` is a single white-flash frame (0.1 s) via FlashComponent, not a full animation.

## Props & FX

| Item | Animation | Frames | FPS | Loop |
|---|---|---|---|---|
| Credia Coin | `spin` | 6 | 10 | ✔ |
| Checkpoint | `off` 1 · `activate` 3 @10 ✖ · `on` 2 @4 ✔ (green pulse) |
| Security node | `off` 1 (red) · `charging` 3 @10 ✔ · `on` 2 @4 ✔ (blue pulse) |
| Exit/firewall gate | `closed` 2 @3 ✔ · `open` 4 @10 ✖ |
| Moving platform | `idle` 2 @4 ✔ (edge lights) |
| Crumbling platform | `intact` 1 · `shake` 3 @14 ✔ · `break` 3 @12 ✖ · respawn fade-in |
| Monitors | `propaganda` 2 @2 ✔ (red text blink) · `positive` 2 @2 ✔ (green) |
| Hit spark | 4 @20 ✖ · Coin glint 5 @16 ✖ · Dust 4 @14 ✖ · Confetti 6 @10 ✔ · Dizzy stars 4 @8 ✔ · Pixel explosion 6 @14 ✖ |

## UI animation (AnimationPlayer / Tween, not sprites)
Menu buttons: focus pulse (green underline sweep). Stage-clear: numbers count up with `tally_tick` SFX (0.8 s per line), rank medal stamps in with squash (0.2 s) + `rank_stamp` SFX + confetti burst if A/S. HP segment loss: red flash → drain. Screen transitions: 0.25 s fade to `BG_VOID`.
