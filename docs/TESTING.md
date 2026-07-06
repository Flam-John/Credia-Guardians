# Testing Strategy

Three layers: **unit (GUT)** for pure logic, **debug scenes** for mechanic isolation, **playtest checklists** for feel/integration. Run before every milestone merge.

## 1. Unit tests — GUT (`addons/gut`), `tests/unit/`

Headless run (used locally and by any future CI):
```powershell
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

| Suite | Covers |
|---|---|
| `test_state_machine.gd` | transition table, enter/exit ordering, invalid transition rejected, state_changed signal |
| `test_player_timers.gd` | coyote window (jump at t=0.09 ok, t=0.11 not), jump buffer, combo window, variable jump cut — via simulated ticks, no scene tree physics |
| `test_health_component.gd` | damage/heal clamping, died emitted once, invuln window ignores hits |
| `test_damage_pipeline.gd` | hitbox→hurtbox→health wiring, shield-arc negation math (±60°), stomp detection |
| `test_game_manager.gd` | score aggregation, rank computation table (all 5 ranks, boundary values), lives flow |
| `test_save_manager.gd` | round-trip serialize, atomic write (tmp+rename), corrupt file → .bak + empty slot, max-merge of bests, migration chain with fixture files, refuse future version |
| `test_object_pool.gd` | acquire/release, no growth beyond max, reset-on-release |
| `test_enemy_states.gd` | per-enemy transition tables with mocked detectors (player_spotted etc.) |

Convention: logic that needs physics ticks is tested with a fixed-dt loop on plain objects (states accept injected `body` stub) — no flaky scene-tree physics in unit tests.

## 2. Debug scenes — `tests/debug_scenes/` (run with F6)

| Scene | Purpose |
|---|---|
| `movement_room.tscn` | Ledge/gap gauntlet with distance markers; both chars spawnable (1/2 keys); prints jump apex/distance |
| `combat_room.tscn` | Spawner buttons for each enemy; hitbox draw toggle; god mode key |
| `platform_room.tscn` | Every platform type incl. worst-case moving platform junctions |
| `pickup_room.tscn` | All collectibles + shield/upgrade interactions |
| `boss_arena.tscn` | Any boss vs. chosen character, phase skip keys |
| `ui_gallery.tscn` | Every screen reachable, fake data injected |

Debug overlay (F3, dev builds only): FPS, frame time, active state names (player + nearest enemy), velocity, pool usage, draw calls.

## 3. Manual playtest checklists (per milestone merge)

**Core feel (every merge):** jump feels responsive at 60 FPS ▢ · no input eaten during pause/unpause ▢ · camera never shows outside level bounds ▢ · no pixel shimmer at ×3 and ×4 ▢ · gamepad and keyboard both complete the loop ▢ · pause works everywhere incl. boss intro ▢.

**Combat (M2+):** i-frames flicker visible ▢ · can't be hit during dash (Flam) ▢ · shield blocks front only (Chris) ▢ · stomp on Auditor hurts player ▢ · no double-hit from single swing ▢ · death mid-air, on platform, in hazard all respawn correctly ▢.

**Persistence (M3+):** kill process mid-stage → slot intact ▢ · clear stage → rank/hi-score only improve ▢ · delete slot → others untouched ▢ · rebind, restart app, binding kept ▢.

**Stage sign-off (M4+, per stage):** clearable without dash (except marked dash gates) ▢ · all 100 coins reachable, counted, none duplicated ▢ · hidden rooms discoverable via tells ▢ · S rank achieved by a dev on video ▢ · no softlock spots (checked: every pit, gate, platform cycle) ▢ · 60 FPS in busiest section with profiler open ▢.

**Boss sign-off (M6+):** every pattern telegraphed ≥ 0.4 s ▢ · beatable hitless by a dev ▢ · beatable by a first-timer within 5 attempts ▢ · no damage during phase-change invulnerability ▢.

## 4. Regression rule
Every bug fixed gets either a GUT test (if logic) or a checklist line (if feel/integration) before the fix merges. The checklist file lives in this doc and grows over the project.
