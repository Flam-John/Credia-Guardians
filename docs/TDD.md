# Credia Guardians — Technical Design Document (TDD)

**Engine:** Godot **4.5.x** (latest stable 4.x at project start; pinned in `project.godot` once installed) · **Language:** GDScript (typed, `--strict` conventions) · **Target:** Windows, 60 FPS locked.

---

## 1. Rendering & Pixel-Perfect Setup

`project.godot` settings:

| Setting | Value | Why |
|---|---|---|
| `display/window/size/viewport_width/height` | 480 × 270 | 16:9, ×4 = 1080p exactly |
| `display/window/size/window_width/height_override` | 1440 × 810 (default window ×3) | Comfortable desktop default |
| `display/window/stretch/mode` | `canvas_items` | Crisp scaling, UI at native res |
| `display/window/stretch/aspect` | `keep` | Letterbox, never distort |
| `display/window/stretch/scale_mode` | `integer` | No half-pixel shimmer |
| `rendering/textures/canvas_textures/default_texture_filter` | `nearest` | Hard pixels |
| `rendering/2d/snap/snap_2d_transforms_to_pixel` | `true` | Kills sprite jitter |
| `rendering/2d/snap/snap_2d_vertices_to_pixel` | `true` | |
| `physics/common/physics_ticks_per_second` | 60 | Fixed step = frame |
| `application/run/max_fps` | 60 | |

Camera: `Camera2D` with `position_smoothing` **off**; custom smoothing done in code then snapped to whole pixels (subpixel accumulator pattern) — smooth follow without shimmer. Limits set per-level from a `CameraLimits` ReferenceRect in each stage scene. Lookahead: ±24 px in facing direction, lerped.

---

## 2. Project Architecture

### 2.1 Principles
- **Composition over inheritance**: entities are assembled from component nodes. Only two shallow class hierarchies exist: `State` (FSM) and `EnemyBase extends CharacterBody2D` (shared plumbing only — behavior lives in states/components).
- **SOLID mapping**: single-responsibility autoloads; entities depend on component interfaces (duck-typed signals), not concrete classes; new enemies added by composing exported vars + state scripts, never by editing existing code (open/closed).
- **Signals up, calls down**: children never reference parents; they emit. Cross-system communication goes through `EventBus` only.
- **Data-driven**: all tuning in custom `Resource` types (`.tres`), editable in inspector, hot-reloadable.

### 2.2 Autoload singletons (registered in this order)

| Autoload | Responsibility (single) |
|---|---|
| `EventBus` | Signal declarations ONLY — no state, no logic. `coin_collected(value)`, `player_damaged(hp, max_hp)`, `player_died`, `enemy_killed(score, world_pos)`, `node_activated(id, count, total)`, `checkpoint_reached(id)`, `stage_cleared(stats)`, `boss_phase_changed(phase)`, `score_changed(score)`, `pause_toggled(paused)` |
| `GameManager` | Run state: current character, stage, score, lives, coins this run, session hi-score; subscribes to EventBus, exposes read-only getters. No scene refs. |
| `SaveManager` | Slot CRUD, JSON serialize/deserialize, version migration, settings persistence (`user://settings.cfg` via `ConfigFile`). |
| `AudioManager` | Music crossfade (2 `AudioStreamPlayer`s), SFX pool (8 `AudioStreamPlayer`s round-robin, pitch-jitter ±5 %), bus volume API. |
| `SceneManager` | `change_scene(path)` with fade in/out `CanvasLayer`, loading of level scenes via `ResourceLoader.load_threaded_*`. |

### 2.3 Component nodes (reused by player, enemies, props)

| Component | Type | API |
|---|---|---|
| `HealthComponent` | Node | `max_hp`, `hp`, `damage(amount)`, `heal(amount)`; signals `damaged`, `healed`, `died` |
| `HurtboxComponent` | Area2D | Receives hits; `invulnerable` flag + timer; signal `hurt(hitbox)` |
| `HitboxComponent` | Area2D | Deals hits; `damage`, `knockback_force`, `one_shot_targets` (no double-hit per swing) |
| `KnockbackComponent` | Node | Applies decaying impulse to a `CharacterBody2D` |
| `FlashComponent` | Node | White-flash shader pulse on hurt |
| `LootComponent` | Node | Spawns coins/pickups on owner death (exported scene + count) |
| `EdgeDetectorComponent` | Node2D (2 RayCast2D) | `is_wall_ahead()`, `is_ledge_ahead()` for patrol AI |
| `PlayerDetectorComponent` | Area2D / RayCast2D | Line-of-sight + range checks; signal `player_spotted(player)` |

### 2.4 Finite State Machine (generic, shared by player & enemies)

```gdscript
# src/fsm/state_machine.gd
class_name StateMachine extends Node
# children are State nodes; exactly one active
# delegates _physics_process / _unhandled_input to active state
# transition(name: StringName) — exit old, enter new; emits state_changed

# src/fsm/state.gd
class_name State extends Node
# virtual: enter(prev), exit(), physics_update(delta), input(event)
# owner_body / stats injected by StateMachine on ready
```

Player states: `Idle, Run, Jump, DoubleJump, Fall, Dash, Attack (combo index), AirAttack, Shield (Chris), Hurt, Dead`. Full diagram: PLAYER_FSM.md.
Enemy states per archetype: ENEMY_AI.md.

### 2.5 Custom Resources (`src/resources/`, data in `data/`)

| Resource | Fields |
|---|---|
| `CharacterStats` | display_name, portrait, sprite_frames, max_hp, run_speed, accel, friction, air_control, jump_velocity, double_jump_velocity, gravity_rise, gravity_fall, max_fall, coyote_time, jump_buffer, dash_speed, dash_duration, dash_cooldown, air_dash_charges, dash_has_iframes, has_shield, shield_capacity, shield_regen_delay, shield_regen_rate, attack_damage |
| `EnemyStats` | display_name, sprite_frames, max_hp, contact_damage, score_value, move_speed, detection_range, attack_cooldown, stompable, loot_scene, loot_count |
| `LevelData` | stage_id, display_name, scene_path, music, total_coins (100), node_count, par_time_sec, next_stage_id, tileset |
| `SaveSlotData` (runtime struct, not .tres) | see SAVE_STRUCTURE.md |

### 2.6 Physics layers

| # | Name | Used by |
|---|---|---|
| 1 | `world` | TileMap terrain, static bodies |
| 2 | `player` | Player body |
| 3 | `enemy` | Enemy bodies (no enemy↔enemy collision) |
| 4 | `player_hitbox` | Player melee/dash hitboxes → scan mask 5's hurtboxes… |
| 5 | `enemy_hurtbox` | Enemy hurtboxes |
| 6 | `enemy_hitbox` | Enemy attacks/projectiles |
| 7 | `player_hurtbox` | Player hurtbox |
| 8 | `collectible` | Coins/pickups (Area2D, mask = player) |
| 9 | `platform_oneway` | One-way + moving platforms |
| 10 | `hazard` | Spikes, lasers, pits (Area2D) |
| 11 | `trigger` | Checkpoints, nodes, hidden-room reveals, exits |

Convention: hitboxes **scan**, hurtboxes **are scanned** — hitbox `collision_mask` = target hurtbox layer, `collision_layer` = 0 on Areas that only scan.

### 2.7 Input map

| Action | Keyboard | Gamepad |
|---|---|---|
| `move_left/right` | A/D + ←/→ | Left stick + D-pad |
| `move_up/down` | W/S + ↑/↓ | Left stick + D-pad |
| `jump` | Space / Z | A (bottom face) |
| `attack` | J / X | X (left face) |
| `dash` | K / C | RB / B |
| `ability` (shield) | L / V | LB / Y |
| `interact` | E | D-pad up (Y stays reserved for `ability`) |
| `pause` | Esc | Start |
| `ui_*` | Godot defaults | Godot defaults |

Deadzone 0.3. Rebinding UI in Options writes overrides to `user://settings.cfg` (`InputMap.action_erase_events` + re-add).

---

## 3. Scene Composition (summary — full tree in SCENE_HIERARCHY.md)

- `main.tscn` — root; owns current screen/level via SceneManager.
- `level_base.tscn` — inherited by all 5 stages: TileMapLayers (background / terrain / foreground / hazards), `EntitiesContainer`, `SpawnPoint`, `Checkpoints`, `SecurityNodes`, `Exit`, `CameraLimits`, `ParallaxBackground`, `HiddenRooms`.
- `player.tscn` — one scene for both characters; `CharacterStats` resource injected at spawn decides everything (stats, SpriteFrames, shield availability).
- `enemy_base.tscn` — inherited per enemy; each adds its state set + detector configs.
- UI screens are separate scenes under a `UI` CanvasLayer, driven by a tiny screen-stack helper in `main.tscn`.

## 4. Object Pooling

`ObjectPool` (plain class): pre-instantiates N scenes, `acquire()/release()`. Pooled: enemy projectiles (32), hit sparks (16), coin-collect glints (24), dash afterimages (8), popup score labels (16). Pools owned by the level, cleared on unload.

## 5. Error handling & debug

- `assert()`s in dev for contract violations (e.g., Player without stats).
- Debug overlay (F3): FPS, state names, velocity, hitbox draw toggle.
- Debug scenes in `tests/debug_scenes/` per mechanic (movement room, combat room, platform room) — each opens standalone with F6.

## 6. Performance targets

60 FPS on integrated GPU. Budgets: ≤ 200 draw calls, ≤ 50 active physics bodies, 0 per-frame allocations in hot paths (pooling, cached NodePaths, no `get_node()` in `_physics_process`). Full checklist: PERFORMANCE.md.

## 7. Known Godot 4.x specifics honored

- `TileMapLayer` nodes (4.3+) instead of deprecated single `TileMap`.
- `CharacterBody2D.move_and_slide()` with `velocity` property.
- Typed signals via `EventBus` autoload (no stringly-typed `emit_signal`).
- `SpriteFrames` for AnimatedSprite2D; `AnimationPlayer` only where property tracks needed (hitbox toggling during attacks).
- Threaded scene loading for stage transitions to avoid hitches.
