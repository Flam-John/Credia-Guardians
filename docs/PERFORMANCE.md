# Performance Optimization Checklist

**Target:** locked 60 FPS at ×4 scale on integrated GPU (Intel Iris Xe class). Frame budget 16.6 ms; aim ≤ 10 ms worst case for headroom.

## Budgets (checked in profiler each milestone)

| Metric | Budget |
|---|---|
| Draw calls | ≤ 200 |
| Active physics bodies | ≤ 50 (sleep the rest) |
| Active Area2D monitors | ≤ 60 |
| Particles on screen | ≤ 300 quads |
| Per-frame heap allocations in gameplay | 0 (verified: monitor "Object nodes" stable during combat) |
| Scene-change hitch | ≤ 100 ms (threaded load) |

## Checklist — run at every milestone merge (record results in commit message)

### Rendering
- [ ] All gameplay textures in shared atlases per domain (tiles / entities / ui / fx) — sprites from the same atlas batch into one draw call
- [ ] `nearest` filter everywhere, no mipmaps on pixel art
- [ ] Parallax layers are single quads (repeat-x), not tile grids
- [ ] Foreground/decor TileMapLayers have collision disabled (no pointless physics)
- [ ] Scanline overlay is one fullscreen quad, off by default
- [ ] No `Light2D`/shader effects introduced without profiler before/after
- [ ] Y-sort off except where genuinely needed

### Physics & AI
- [ ] Every enemy has `VisibleOnScreenEnabler2D` — off-screen = no physics, no AI
- [ ] Hitboxes/hurtboxes `monitoring=false` except during active frames (AnimationPlayer keys)
- [ ] Collision masks minimal per TDD layer table — nothing scans layers it doesn't need
- [ ] RayCasts (edge/LoS detectors) disabled while state doesn't need them
- [ ] No `get_node()`/`find_child()` in `_physics_process` — all NodePaths cached `@onready`
- [ ] Moving platforms use `AnimatableBody2D` with `sync_to_physics`

### Memory & GC pressure
- [ ] Projectiles, FX, popups, dash ghosts all pooled (`ObjectPool`) — zero runtime `instantiate()` during combat
- [ ] Signals connected once (`_ready`), never per-frame connect/disconnect
- [ ] No per-frame `String` building (debug overlay throttled to 4 Hz)
- [ ] `queue_free` only for one-shot pickups; pooled objects always `release()`
- [ ] Level unload verified leak-free: enter/exit stage ×10 → static orphan count (`--verbose` "Orphan nodes: 0")

### Audio
- [ ] SFX preloaded at startup (no disk hit on first play)
- [ ] Music `.ogg` streamed, SFX `.wav` in memory
- [ ] SFX pool cap 8 — no unbounded player spawning

### Loading
- [ ] Stages loaded with `ResourceLoader.load_threaded_request` behind the fade
- [ ] Heavy scenes (bosses) preloaded when player passes the last checkpoint before them

### Verification procedure (per milestone)
1. Open busiest scene (M4+: stage worst-case section; M7: CEO phase 3 spiral).
2. Godot profiler: Frame Time, Physics Time, and Monitors→Draw Calls/Objects for 60 s of aggressive play.
3. Record: worst frame ms, draw calls, body count → paste into milestone merge commit.
4. Any budget breach = fix before merge (or explicitly waive with reason in commit).

### Export (M8)
- [ ] Export with embedded PCK, release template (no debug overhead)
- [ ] Test exported build on a machine without Godot installed
- [ ] Verify 60 FPS in exported build (editor numbers lie)
