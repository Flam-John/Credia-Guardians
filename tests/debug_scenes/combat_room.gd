extends Node2D
## Combat playground: every M2 system in one room. Keys 1/2 respawn as
## Chris/Flam, F3 debug overlay. Boot scene until the M3 menu shell.

const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")
const JUNIOR := preload("res://scenes/entities/enemies/junior_banker.tscn")
const MANAGER := preload("res://scenes/entities/enemies/angry_manager.tscn")
const COIN := preload("res://scenes/entities/collectibles/coin.tscn")
const PICKUP := preload("res://scenes/entities/collectibles/pickup.tscn")

const T := 16 # tile size, for readable placement coords

const ROOM_MAP := """
@..............................................................@
@..............................................................@
@..............................................................@
@..............................................................@
@..............................................................@
@..................................................########....@
@..............................................................@
@..............................................................@
@........................#####.................................@
@..............................................................@
@...######......................................######.........@
@..............................................................@
@..............................................................@
@#####..........#################......^^^......###############@
@@@@@@..........@@@@@@@@@@@@@@@@@......................@@@@@@@@@
"""

var _respawner: RespawnController


func _ready() -> void:
	var builder := AsciiRoomBuilder.new()
	builder.map = ROOM_MAP
	add_child(builder)
	add_child(DebugOverlay.new())

	GameManager.start_stage(0, &"chris")

	_respawner = RespawnController.new()
	_respawner.spawn_point = Vector2(3 * T, 12 * T)
	_respawner.camera_limits = Rect2(Vector2.ZERO, builder.room_size)
	add_child(_respawner)
	_respawner.spawn(CHRIS)

	_place_enemies()
	_place_collectibles()
	_place_props()
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _place_enemies() -> void:
	_add(JUNIOR, Vector2(22 * T, 12 * T))
	_add(JUNIOR, Vector2(28 * T, 12 * T))
	_add(MANAGER, Vector2(50 * T, 12 * T))


func _place_collectibles() -> void:
	for i in 5:
		_add(COIN, Vector2((17 + i * 2) * T, 11 * T))
	for i in 3:
		_add(COIN, Vector2((25 + i) * T, 7 * T))
	var coffee: Pickup = PICKUP.instantiate()
	coffee.kind = Pickup.Kind.COFFEE
	coffee.position = Vector2(10 * T, 9 * T)
	add_child(coffee)


func _place_props() -> void:
	var checkpoint := Checkpoint.new()
	checkpoint.position = Vector2(30 * T, 13 * T)
	add_child(checkpoint)

	# moving platform over the spike pit
	var mover := MovingPlatform.new()
	mover.position = Vector2(36 * T, 11 * T)
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(9 * T, 0))
	mover.curve = curve
	add_child(mover)

	var crumbler := CrumblingPlatform.new()
	crumbler.position = Vector2(12 * T, 10 * T)
	add_child(crumbler)


func _on_enemy_killed(score: int, world_pos: Vector2) -> void:
	ScorePopup.spawn(self, world_pos, score)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_1:
			_respawner.spawn(CHRIS)
		KEY_2:
			_respawner.spawn(FLAM)


func _add(scene: PackedScene, pos: Vector2) -> void:
	var node: Node2D = scene.instantiate()
	node.position = pos
	add_child(node)
