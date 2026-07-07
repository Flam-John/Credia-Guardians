class_name RespawnController
extends Node
## Owns the player lifecycle in a level: spawn, checkpoint tracking, death →
## respawn (or out-of-lives → reload). Reused by debug rooms now and
## level_base in M4 — the player never respawns itself.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const RESPAWN_DELAY := 1.2

@export var spawn_point := Vector2.ZERO
@export var camera_limits := Rect2()

var player: Player
var _character: CharacterStats
var _active_checkpoint_pos := Vector2.ZERO


func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	EventBus.checkpoint_reached.connect(_on_checkpoint_reached)


func spawn(character: CharacterStats) -> Player:
	_character = character
	_active_checkpoint_pos = spawn_point
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


func _on_checkpoint_reached(_id: StringName) -> void:
	# the checkpoint that emitted is the nearest activated one to the player
	if is_instance_valid(player):
		_active_checkpoint_pos = player.global_position


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if GameManager.lives <= 0:
		# Game Over screen arrives in M3; for now restart the room fresh.
		GameManager.start_stage(GameManager.stage_id, GameManager.character)
		SceneManager.reload_current()
		return
	_spawn_at(_active_checkpoint_pos)
