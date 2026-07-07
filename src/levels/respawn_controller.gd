class_name RespawnController
extends Node
## Owns the player lifecycle in a level: spawn, checkpoint tracking, death →
## respawn (or out-of-lives → reload). Reused by debug rooms now and
## level_base in M4 — the player never respawns itself.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const RESPAWN_DELAY := 1.2

@export var spawn_point := Vector2.ZERO
@export var camera_limits := Rect2()

## How far below the camera limits the kill plane sits.
const FALL_KILL_MARGIN := 48.0

var player: Player
var _character: CharacterStats
var _active_checkpoint_pos := Vector2.ZERO
var _kill_y := INF


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)


func _physics_process(_delta: float) -> void:
	# Kill plane: falling out of the room is death, never a softlock.
	if is_instance_valid(player) and player.global_position.y > _kill_y \
			and not player.health.is_dead():
		player.take_hit(999, player.global_position)


func spawn(character: CharacterStats) -> Player:
	_character = character
	_active_checkpoint_pos = spawn_point
	_kill_y = camera_limits.end.y + FALL_KILL_MARGIN
	return _spawn_at(spawn_point)


func _spawn_at(pos: Vector2) -> Player:
	if is_instance_valid(player):
		player.queue_free()
	player = PLAYER_SCENE.instantiate()
	player.stats = _character
	player.position = pos
	get_parent().add_child(player)
	player.activate_camera(camera_limits)
	return player


func _on_checkpoint_reached(_id: StringName, respawn_pos: Vector2) -> void:
	_active_checkpoint_pos = respawn_pos


func _on_player_died() -> void:
	# process_always=false: the respawn countdown respects pause
	await get_tree().create_timer(RESPAWN_DELAY, false).timeout
	if not is_inside_tree():
		return # level already unloading (quit to menu during the delay)
	if GameManager.lives <= 0:
		GameManager.end_stage()
		SceneManager.change_scene("res://scenes/ui/game_over.tscn")
		return
	_spawn_at(_active_checkpoint_pos)
