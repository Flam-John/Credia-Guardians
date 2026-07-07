extends Node
## Global signal hub. Declarations ONLY — no state, no logic (see docs/TDD.md §2.2).
##
## Gameplay objects emit; aggregators (GameManager) and UI subscribe.
## Never connect gameplay objects directly to each other across systems.

# -- Player --
signal player_spawned(player: Node2D)
signal player_damaged(hp: int, max_hp: int)
signal player_healed(hp: int, max_hp: int)
signal player_died

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
signal boss_phase_changed(phase: int)

# -- Meta --
signal pause_toggled(paused: bool)
