class_name FanZone
extends Area2D
## Cooling fan: horizontal push affecting the player even airborne (unlike
## conveyors). Same pre-player physics ordering as the other field props.

@export var push := 70.0 # signed px/s

var _tiles := 1


func _ready() -> void:
	process_physics_priority = -1
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false


func setup(tiles_wide: int, direction: int) -> void:
	_tiles = tiles_wide
	push = absf(push) * direction
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_wide * 16, 64) # tall zone: catches jumps
	shape.shape = rect
	shape.position = Vector2(tiles_wide * 8.0, -24)
	add_child(shape)
	var gust := CPUParticles2D.new()
	gust.amount = 10
	gust.lifetime = 0.8
	gust.position = Vector2(tiles_wide * 8.0, -20)
	gust.direction = Vector2(signf(push), 0)
	gust.spread = 12.0
	gust.gravity = Vector2.ZERO
	gust.initial_velocity_min = 50.0
	gust.initial_velocity_max = 90.0
	gust.color = Color(0.6, 0.9, 0.9, 0.2)
	add_child(gust)


func _physics_process(_delta: float) -> void:
	if not has_overlapping_bodies():
		return # allocation-free guard (review P4-23)
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.conveyor_push = push
