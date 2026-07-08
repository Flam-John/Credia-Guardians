class_name Updraft
extends Area2D
## Coffee-steam column: lifts the player while inside (boosted jumps).
## Same pre-player-tick pattern as ConveyorBelt.

@export var strength := 260.0 # upward accel px/s^2

var _height_tiles := 1


func _ready() -> void:
	process_physics_priority = -1 # physics ordering, not process_priority
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false


func setup(height_tiles: int) -> void:
	_height_tiles = height_tiles
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, height_tiles * 16)
	shape.shape = rect
	shape.position = Vector2(8, height_tiles * 8.0)
	add_child(shape)
	var steam := CPUParticles2D.new()
	steam.amount = 8
	steam.lifetime = 1.2
	steam.position = Vector2(8, height_tiles * 16.0)
	steam.direction = Vector2.UP
	steam.initial_velocity_min = 30.0
	steam.initial_velocity_max = 60.0
	steam.gravity = Vector2.ZERO
	steam.scale_amount_min = 1.0
	steam.scale_amount_max = 2.0
	steam.color = Color(0.9, 0.95, 1.0, 0.25)
	add_child(steam)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.updraft_strength = strength
