class_name RespawnController
extends Node
## Owns the player lifecycle in a level: spawn (1 or 2 players), checkpoint
## tracking, death → respawn/game-over, kill plane, cameras.
##
## Co-op rules (docs/MILESTONES.md post-1.0): shared lives pool; a death
## with a living partner respawns beside the partner after a delay; when
## everyone is down, respawn all at the checkpoint — or game over at 0 lives.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const RESPAWN_DELAY := 1.2
const FALL_KILL_MARGIN := 48.0

@export var spawn_point := Vector2.ZERO
@export var camera_limits := Rect2()

## The (first) player — existing single-player callers keep working.
var player: Player
var players: Array[Player] = []

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
			p.take_hit(999, p.global_position)


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


func _spawn_all(pos: Vector2) -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	var coop := _characters.size() > 1
	for i in _characters.size():
		var p := _spawn_one(_characters[i], pos + Vector2(i * 20.0, 0),
				i + 1 if coop else 0)
		players.append(p)
	player = players[0]
	if coop:
		if _coop_camera == null or not is_instance_valid(_coop_camera):
			_coop_camera = CoopCamera.new()
			get_parent().add_child(_coop_camera)
			_coop_camera.setup_limits(camera_limits)
		_coop_camera.global_position = pos
		_coop_camera.snap_now()
		_coop_camera.make_current()
	else:
		player.activate_camera(camera_limits)


func _spawn_one(stats: CharacterStats, pos: Vector2, index: int) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = stats
	p.player_index = index
	p.position = pos
	get_parent().add_child(p)
	if index > 0:
		p.camera.queue_free() # co-op uses the shared camera
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
	var alive := _alive()
	if not alive.is_empty():
		# partner still fighting: rejoin beside them if the pool allows
		if GameManager.lives > 0:
			var idx := players.find(dead as Player)
			if idx >= 0:
				var revived := _spawn_one(_characters[idx],
						alive[0].global_position + Vector2(0, -8),
						(dead as Player).player_index)
				revived.hurtbox.start_invuln(2.0)
				if is_instance_valid(players[idx]):
					players[idx].queue_free()
				players[idx] = revived
				if idx == 0:
					player = revived
		return
	# everyone down
	if GameManager.lives <= 0:
		GameManager.end_stage()
		SceneManager.change_scene("res://scenes/ui/game_over.tscn")
		return
	_spawn_all(_active_checkpoint_pos)
