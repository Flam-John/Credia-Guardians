extends Node2D
## Movement debug room: ledge/gap gauntlet built from ASCII (versionable).
## Keys: 1 = respawn as Chris, 2 = respawn as Flam, F3 = debug overlay.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")
const SPAWN := Vector2(48, 180)

const ROOM_MAP := """
@..............................................................@
@..............................................................@
@..............................................................@
@.......................................................####...@
@..............................................................@
@..................................................####........@
@...........................................###................@
@..............-----...........................................@
@.......................######.................................@
@...####........................................####...........@
@..............................................................@
@.....................##.......................................@
@############.....########....#####....^^^....##################
@@@@@@@@@@@@@.....@@@@@@@@....@@@@@....................@@@@@@@@@
"""

var _builder: AsciiRoomBuilder
var _player: Player


func _ready() -> void:
	_builder = AsciiRoomBuilder.new()
	_builder.map = ROOM_MAP
	add_child(_builder)
	_builder.build()
	add_child(DebugOverlay.new())
	_spawn(CHRIS)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			_spawn(CHRIS)
		KEY_2:
			_spawn(FLAM)


func _spawn(stats: CharacterStats) -> void:
	if is_instance_valid(_player):
		_player.queue_free()
	_player = PLAYER_SCENE.instantiate()
	_player.stats = stats
	_player.position = SPAWN
	add_child(_player)
	var camera: PlayerCamera = _player.get_node("Camera")
	camera.setup_limits(Rect2(Vector2.ZERO, _builder.room_size))
	camera.snap_to_target()
	camera.make_current()
