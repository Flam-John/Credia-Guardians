extends Node2D
## Movement debug room: ledge/gap gauntlet built from ASCII (versionable).
## Keys: 1 = respawn as Chris, 2 = respawn as Flam, F3 = debug overlay.

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

var _respawner: RespawnController


func _ready() -> void:
	var builder := AsciiRoomBuilder.new()
	builder.map = ROOM_MAP
	add_child(builder) # _ready auto-builds; room_size is valid after this
	add_child(DebugOverlay.new())
	_respawner = RespawnController.new()
	_respawner.spawn_point = SPAWN
	_respawner.camera_limits = Rect2(Vector2.ZERO, builder.room_size)
	add_child(_respawner)
	_respawner.spawn(CHRIS)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			_respawner.spawn(CHRIS)
		KEY_2:
			_respawner.spawn(FLAM)
