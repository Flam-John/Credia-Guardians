# Architect Review — v1.2.0 Fix Plan

Five-angle review (architecture, core systems, gameplay, UI/flow, perf+tests).
38 raw findings → 33 after dedup. Ordered by severity; each phase is a
mergeable unit. "PLAUSIBLE" = reviewer could not fully prove at runtime.

## P0 — Crashes & data loss (fix before anything else)

1. **Boss Rush RETRY crashes the shipped build** — `game_manager.gd:62`.
   Boss rush runs `start_stage(0)`; RETRY (game over) and RESTART (pause) call
   `launch_stage(0)` → assert/bad-key crash. Fix: `retry_stage()` routes to
   the boss-rush scene when `stage_id == 0` (store a `current_scene_path`
   instead of asserting).
2. **Slot-delete can destroy the WRONG save** — `slot_select.gd:27`.
   Arming delete rebuilds the list and focus resets to slot 1; mashing X
   deletes slot 1. Fix: restore focus to the armed slot after `_rebuild()`.
3. **ESC in pause-options unpauses the game** — `options_menu.gd` ui_cancel
   branch never consumes the event; it falls through to PauseMenu's toggle.
   Fix: `accept_event()` in `_on_back` path.
4. **Stuck PAUSED overlay after pausing mid-fade** — `scene_manager.gd:75`
   force-unpauses without informing PauseMenu; overlay stays, toggle inverts.
   Fix: PauseMenu resets on `SceneManager.scene_changed`.

## P1 — Co-op integrity (the mode has 6 real defects)

5. **`character2` leaks across modes** — solo Boss Rush after a co-op session
   spawns a phantom P2 that drains shared lives; CONTINUE on another slot
   launches co-op. Fix: GameManager owns co-op intent; reset in
   `start_stage`/`quit_to_menu`; boss rush and CONTINUE set it explicitly.
6. **All AI targets only the first (possibly dead) player** —
   `enemy_base.find_player()` = `get_first_node_in_group`; dead players stay
   in the group. Fix: `find_player()` returns nearest *alive* player;
   remove from group in DeadState.
7. **SecurityNode & FirewallGate freeze when P2 passes through** — single
   `_player_inside` slot overwritten/cleared. Fix: poll overlapping players
   instead of tracking one.
8. **Screenshake dead all co-op session** — `game_feel.shake` casts to
   PlayerCamera; CoopCamera lacks `add_shake`. Fix: duck-type `add_shake`
   on both cameras, drop the cast.
9. **PLAUSIBLE: same-frame double pickup in co-op** — deferred
   `monitoring=false` lets both players' callbacks run (`usb_keys += 2`,
   double coin count breaks FULL AUDIT). Fix: immediate `_collected` guard.
10. **Rebinds never reach co-op action sets** — `coop_input._built` latch
    snapshots base bindings once. Fix: rebuild p1_/p2_ sets after
    `apply_key_binding` when they exist.

## P2 — Boss fight quality

11. **CEO music stomped + HP bar spoils from level start** — boss `_ready`
    runs during map parse, then LevelBase plays stage music over boss_final.
    Fix: spawn dormant; activate (music/HP bar/AI) via arena-entry trigger.
12. **Hit-stun freezes enemy punish-window timers** — knockback skips
    `state_machine.physics_update`, so alternating co-op hits hold the CEO
    in Stagger forever (whole phase shredded in one window). Fix: tick the
    FSM during knockback; apply knockback additively.
13. **P3 LaserSweep timing wrong** — `phase_offset` forgets `on_time`; beam
    fires late and lives 0.3s. Fix: offset = `on+off−TELEGRAPH`.
14. **Kill plane eaten by shields/i-frames** — pit deaths pop the firewall
    bubble and stall. Fix: dedicated `Player.kill()` bypassing defenses.

## P3 — Architecture debt (keeps future work cheap)

15. **Level services are a duck-typed convention across 4 files** and
    boss_rush's hand copy already drifted (pool sizes, no popups). Fix:
    extract `LevelServices` node (pools + FX + popup wiring) used by both.
16. **LevelBase is a 433-line god object**. Extract `EntityMarkerParser`
    (unit-testable, sibling to AsciiRoomBuilder); move clear-stats assembly
    into GameManager per DATA_FLOW.md.
17. **EventBus drift**: hp signals can't say which player (HUD bypasses the
    bus with direct node wiring); bus carries live node refs; TDD signal
    table stale. Fix: add `player_index` to hp signals, HUD returns to the
    bus, document the node-ref exceptions, sync TDD §2.2.
18. **HUD writes `GameManager.hi_score`** (UI mutating run state). Move
    promotion into `GameManager.add_score`.
19. **Prop near-twins** (ExitGate/FirewallGate ~80%, Conveyor/Fan,
    TimedHazard/FadingBridge with two different telegraph constants).
    Extract `GateProp`, `PushZone`, `CyclingProp` bases.
20. **Player mixes six concerns** (input scoping, movement, damage, pickups,
    FX, node construction) and props poke its fields directly. Minimum fix:
    a single `apply_force_field()` API; larger extraction optional.
21. **Boss-rush BACK routes into slot select** it never came from —
    return to main menu when mode == BOSS_RUSH.
22. **Pause menu never retranslates** (built at boot before locale applies).
    Rebuild its labels on `settings_applied`.

## P4 — Performance & hygiene (docs/PERFORMANCE.md violations)

23. Field props allocate arrays every frame (`get_overlapping_bodies` without
    `has_overlapping_bodies` guard) — ~660 allocs/sec on stage 1.
24. All 100 coins tick `_physics_process` for nothing — gate with
    `set_physics_process` (only while popping).
25. TimedHazard/FadingBridge spam `set_deferred` + modulate every frame —
    make edge-triggered.
26. ScorePopup still un-pooled (doc mandates pooling) — pool it in
    LevelServices (merges with #15).
27. HUD `_process` runs when timer hidden + builds strings per frame —
    gate and throttle.
28. At-exit leaks = static SpriteFrames caches (SpriteFramesBuilder, Coin,
    Checkpoint, HitSpark) — clear on exit or move to an autoload owner;
    restores a clean leak baseline.
29. `stop_music` during a crossfade leaves the outgoing track playing —
    stop both players.
30. ObjectPool lacks a double-release guard — same projectile handed to two
    owners after a same-frame co-op double hit.
31. `change_scene` silently drops calls while `_busy`, but `launch_stage`
    mutates run state first — return a bool / queue, and disable end-screen
    buttons until the fade completes.

## P5 — Test gaps (highest-risk untested paths)

32. **Stage-clear → save → unlock pipeline has zero end-to-end coverage**
    (the exact class of bug that loses player progress silently).
33. Also untested: game-over routing, pause flow, rebind persistence
    round-trip, HUD wiring across respawns, audio crossfade interleavings.

## Suggested execution order

| Phase | Scope | Size |
|---|---|---|
| A | P0 (4 crashes/data-loss) + tests for each | small |
| B | P1 co-op pack (6) + co-op regression tests | medium |
| C | P2 boss pack (4) + boss timing tests | small-medium |
| D | P4 perf pass (9) — mostly mechanical | small |
| E | P3 refactors (8) — LevelServices + parser extraction first, prop bases second, EventBus/doc sync last | large |
| F | P5 integration tests (rides along with A–E) | medium |

Each phase = one branch, review, merge, tag (v1.2.1 after A+B+C+D, v1.3.0
after E+F).
