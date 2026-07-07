# Scene Hierarchy

Ownership rule: **a scene never reaches outside itself** — it emits signals (locally or via `EventBus`); parents wire children. Levels instance entities; entities never know which level they're in.

## Main

```
main.tscn
└── Main (Node)                        # persistent shell — survives all transitions
    ├── ScreenRoot (Node)              # current screen or level lives here; Main
    │                                  #   registers it via SceneManager.register_screen_root
    └── UILayer (CanvasLayer, layer 10)   # added in M3
        ├── HUD (hud.tscn)             # hidden outside gameplay
        └── PauseMenu (pause_menu.tscn)
```

The fade overlay is owned by the SceneManager autoload itself (its own
CanvasLayer at layer 100) — transitions need no per-scene plumbing.

## Level (base, inherited by stage_1..5)

```
level_base.tscn
└── Level (Node2D, level_base.gd, LevelData resource exported)
    ├── ParallaxBackground
    │   ├── LayerFar / LayerMid / LayerNear (ParallaxLayer + Sprite2D)
    ├── TileBackground (TileMapLayer)       # decorative, no collision
    ├── TileTerrain (TileMapLayer)          # collision layer: world
    ├── TileHazards (TileMapLayer)          # spikes etc. (layer: hazard)
    ├── TileForeground (TileMapLayer)       # drawn over entities
    ├── CameraLimits (ReferenceRect)        # read by player camera on spawn
    ├── SpawnPoint (Marker2D)
    ├── Checkpoints (Node2D) → checkpoint.tscn ×N
    ├── SecurityNodes (Node2D) → security_node.tscn ×N
    ├── Collectibles (Node2D) → coin.tscn ×100, pickups
    ├── Enemies (Node2D) → enemy scenes ×N
    ├── Platforms (Node2D) → moving_platform.tscn, crumbling_platform.tscn
    ├── HiddenRooms (Node2D) → hidden_room.tscn (Area2D reveal + cover TileMapLayer/Sprite)
    ├── Exit (exit_gate.tscn)               # opens when required nodes active
    └── EntitiesRuntime (Node2D)            # spawned-at-runtime: projectiles, FX (pools)
```

## Player (one scene, both characters via CharacterStats)

```
player.tscn
└── Player (CharacterBody2D, player.gd, stats: CharacterStats)
    ├── Sprite (AnimatedSprite2D)               # SpriteFrames from stats
    ├── Collision (CollisionShape2D, 10×24 capsule)
    ├── StateMachine (state_machine.gd)
    │   ├── Idle / Run / Jump / DoubleJump / Fall
    │   ├── Dash / Attack / AirAttack / Shield / Hurt / Dead   (each a State node)
    ├── HealthComponent
    ├── HurtboxComponent (Area2D, layer player_hurtbox)
    ├── MeleeHitbox (HitboxComponent, layer player_hitbox, disabled by default)
    ├── KnockbackComponent
    ├── FlashComponent
    ├── ShieldVisual (Sprite2D + Area2D, Chris only — enabled by stats.has_shield)
    ├── Timers (coyote, jump_buffer, dash_cooldown, combo_window)
    ├── Camera (Camera2D, player_camera.gd — pixel-snap smoothing, lookahead)
    ├── DashGhostSpawner (Node2D)
    └── AnimationPlayer                          # hitbox keying for attack combo
```

## Enemy base (inherited)

```
enemy_base.tscn
└── Enemy (CharacterBody2D, enemy_base.gd, stats: EnemyStats)
    ├── Sprite (AnimatedSprite2D)
    ├── Collision (CollisionShape2D)
    ├── StateMachine → (per-enemy states)
    ├── HealthComponent / HurtboxComponent / KnockbackComponent / FlashComponent
    ├── ContactHitbox (HitboxComponent)         # touch damage
    ├── LootComponent
    ├── EdgeDetector (patrollers) / PlayerDetector (aggressive types)
    ├── StompTarget (Area2D thin strip on head, if stats.stompable)
    └── SleepNotifier (VisibleOnScreenEnabler2D) # off-screen = paused physics
```

Per-enemy scenes (`junior_banker.tscn` etc.) inherit this and add only: their states, detector shapes, stats resource, extra nodes (Auditor: `ProjectileSpawner`; Loan Shark: `HideSprite`).

## Bosses

`boss_base.tscn` extends enemy pattern with `PhaseManager (Node)` (HP thresholds → phase state sets), `IntroCutscene (AnimationPlayer)`, and an `ArenaLock` signal to the level. `ceo_boss.tscn` has three state groups, one per phase.

## UI screens (each standalone, swap into ScreenRoot)

```
splash.tscn          # logo fade chain → main menu
main_menu.tscn       # New Game / Continue / Options / Quit
slot_select.tscn     # 3 save slots + delete
character_select.tscn# Chris | Flam panels, stats preview, portrait
stage_select.tscn    # 5 stage cards, locked/unlocked, best rank + hi-score
options_menu.tscn    # audio sliders, fullscreen, scanlines, rebind, reset
pause_menu.tscn      # overlay (CanvasLayer) — process_mode ALWAYS, pauses tree
game_over.tscn       # Retry / Quit to menu
stage_clear.tscn     # tally: EXP/CREDITS/LEVEL BONUS count-up, rank medal stamp
victory.tscn         # BANK SYSTEM SECURED! finale + credits roll
hud.tscn             # portrait, HP segments, score, coins, hi-score, node counter
```

Menu navigation: all screens are `Control` scenes with focus-based navigation (works with keyboard/D-pad/analog out of the box); first button grabs focus on `_ready`.
