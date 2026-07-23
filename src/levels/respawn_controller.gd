class_name RespawnController
extends Node
## Owns the player lifecycle in a level: spawn (1 or 2 players), checkpoint
## tracking, death → respawn/game-over, kill plane, cameras.
##
## Co-op rules (updated 2026-07-23, user request): INDEPENDENT lives pools
## per player (GameManager.lives, keyed by player_index) — a death only
## spends that player's own life, never the partner's. A death with a
## living partner respawns beside the partner after a delay, as long as
## the dead player still has lives. Once a player's OWN pool is empty they
## stay gone for the rest of the stage while the partner keeps playing
## solo; game over only fires when EVERY tracked player is simultaneously
## out of lives (GameManager.all_players_out_of_lives()).

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const RESPAWN_DELAY := 1.2
const FALL_KILL_MARGIN := 48.0

@export var spawn_point := Vector2.ZERO
@export var camera_limits := Rect2()

## The (first) player — existing single-player callers keep working.
var player: Player
var players: Array[Player] = []

## Tests inject a spy here; the default routes through SceneManager. This is
## the one line that lets game-over ROUTING be verified without actually
## swapping scenes mid-test (review P5-33).
var scene_router: Callable = Callable()

var _characters: Array[CharacterStats] = []
var _active_checkpoint_pos := Vector2.ZERO
var _kill_y := INF
var _coop_camera: CoopCamera


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)


func _physics_process(_delta: float) -> void:
	for p in players:
		if is_instance_valid(p) and p.global_position.y > _kill_y \
				and not p.health.is_dead():
			p.kill() # bypasses shields/i-frames — pits are always lethal


## Single-player entry (levels call this with GameManager.character_stats()).
## Co-op activates automatically when GameManager.character2 is set.
func spawn(character: CharacterStats) -> Player:
	_characters = [character]
	if GameManager.is_coop():
		_characters.append(GameManager.character_stats(GameManager.character2))
	_active_checkpoint_pos = spawn_point
	_kill_y = camera_limits.end.y + FALL_KILL_MARGIN
	_spawn_all(spawn_point)
	return player


## Skips any player slot whose lives are already exhausted (harmless no-op
## at a fresh stage start, when every pool is freshly seeded) -- that
## player stays out for the rest of the stage while whoever still has
## lives comes back at pos.
func _spawn_all(pos: Vector2) -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	var coop := _characters.size() > 1
	for i in _characters.size():
		var idx := i + 1 if coop else 0
		if GameManager.lives_for(idx) <= 0:
			continue
		var p := _spawn_one(_characters[i], pos + Vector2(i * 20.0, 0), idx)
		players.append(p)
	if players.is_empty():
		return # caller guards this (fresh stage start, or a checked respawn)
	player = players[0]
	# players.size() (not _characters.size()/coop) decides the camera: a
	# partner who's already permanently out this stage was skipped above, so
	# this respawn is really solo even though _characters still has 2 entries.
	if players.size() > 1:
		_use_coop_camera(pos)
	else:
		_use_solo_camera(player)


func _use_coop_camera(pos: Vector2) -> void:
	if _coop_camera == null or not is_instance_valid(_coop_camera):
		_coop_camera = CoopCamera.new()
		get_parent().add_child(_coop_camera)
		_coop_camera.setup_limits(camera_limits)
	_coop_camera.global_position = pos
	_coop_camera.snap_now()
	_coop_camera.make_current()


## Hands the camera back to the sole survivor's own PlayerCamera (facing
## lookahead) instead of leaving them on the shared no-lookahead CoopCamera
## for the rest of the stage (review: cross-file playability pass).
func _use_solo_camera(survivor: Player) -> void:
	if is_instance_valid(_coop_camera):
		_coop_camera.queue_free()
		_coop_camera = null
	survivor.activate_camera(camera_limits)


func _spawn_one(stats: CharacterStats, pos: Vector2, index: int) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = stats
	p.player_index = index
	p.position = pos
	get_parent().add_child(p)
	# Personal camera is left alive but inactive while CoopCamera is current
	# (harmless: top_level Camera2D, only the current one renders) -- kept
	# around so a solo survivor can get it back if the partner permanently
	# exits (_use_solo_camera below).
	return p


func _alive() -> Array[Player]:
	return players.filter(func(p: Player) -> bool:
		return is_instance_valid(p) and not p.health.is_dead())


func _on_checkpoint_reached(_id: StringName, respawn_pos: Vector2) -> void:
	_active_checkpoint_pos = respawn_pos


func _on_player_died(dead: Node2D) -> void:
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if not is_inside_tree():
		return # level unloading
	var dead_player := dead as Player
	if not is_instance_valid(dead_player):
		# A sibling _on_player_died coroutine (simultaneous death) already
		# resolved this frame -- e.g. its "everyone's currently down" branch
		# called _spawn_all(), which frees every node in `players`, including
		# this one before we got a chance to process it ourselves. Whatever
		# it decided (respawn-all or collapse) already accounts for us.
		return
	if GameManager.lives_for(dead_player.player_index) > 0:
		var alive := _alive()
		if not alive.is_empty():
			# partner still fighting: rejoin beside them
			var idx := players.find(dead_player)
			if idx >= 0:
				var revived := _spawn_one(_characters[idx],
						alive[0].global_position + Vector2(0, -8),
						dead_player.player_index)
				revived.hurtbox.start_invuln(2.0)
				if is_instance_valid(players[idx]):
					players[idx].queue_free()
				players[idx] = revived
				if idx == 0:
					player = revived
			return
		# everyone's currently down -- respawn whoever still has lives
		# (this player included, since we just confirmed their pool isn't empty)
		_spawn_all(_active_checkpoint_pos)
		return
	# this player is OUT of lives for good this stage -- no more respawns
	# for them, but the partner (if any) keeps playing solo. Null the slot
	# immediately rather than leaning on is_instance_valid()'s timing around
	# a deferred queue_free() -- _alive()/_spawn_all() only ever need to
	# know "gone", not exactly when the node itself finishes tearing down.
	var idx := players.find(dead_player)
	if idx >= 0:
		players[idx] = null
	if is_instance_valid(dead_player):
		dead_player.queue_free()
	var still_alive := _alive()
	if not still_alive.is_empty():
		_use_solo_camera(still_alive[0])
		return
	if not GameManager.is_stage_running():
		return # a sibling coroutine (simultaneous double-exhaustion) already routed
	if GameManager.all_players_out_of_lives():
		GameManager.end_stage()
		_route("res://scenes/ui/game_over.tscn")


func _route(path: String) -> void:
	if scene_router.is_valid():
		scene_router.call(path)
	else:
		SceneManager.change_scene(path)
