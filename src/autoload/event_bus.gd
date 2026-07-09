extends Node
## Global signal hub. Declarations ONLY — no state, no logic (see docs/TDD.md §2.2).
##
## Gameplay objects emit; aggregators (GameManager) and UI subscribe.
## Never connect gameplay objects directly to each other across systems.

# -- Player --
## Carries the node (documented exception to values-only: spawners and the
## HUD need identity at spawn). Never STORE this reference across frames.
signal player_spawned(player: Node2D)
## player_index: 0 = single-player, 1/2 = co-op — lets the HUD (and any
## future consumer) distinguish P1 from P2 without holding node refs.
signal player_damaged(player_index: int, hp: int, max_hp: int)
signal player_healed(player_index: int, hp: int, max_hp: int)
signal player_died(player: Node2D)

# -- Collection & score --
signal coin_collected(value: int)
signal pickup_collected(kind: StringName)
signal score_changed(score: int)

# -- Combat --
signal enemy_killed(score: int, world_pos: Vector2)

# -- Level objectives --
signal checkpoint_reached(id: StringName, respawn_pos: Vector2)
signal node_activated(id: StringName, count: int, total: int)
signal hidden_room_found(id: StringName)
signal stage_cleared(stats: Dictionary)

# -- Bosses --
signal boss_spawned(display_name: String, hp: int, max_hp: int)
signal boss_hp_changed(hp: int, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_died

# -- Meta --
signal pause_toggled(paused: bool)
signal settings_applied(settings: Dictionary)
