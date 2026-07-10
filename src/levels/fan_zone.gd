class_name FanZone
extends PushZone
## Cooling fan: horizontal push affecting the player even airborne.

@export var push := 70.0 # signed px/s


func setup(tiles_wide: int, direction: int) -> void:
	push = absf(push) * direction
	add_rect_shape(Vector2(tiles_wide * 16, 64), Vector2(tiles_wide * 8.0, -24))
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


func _affect(player: Player) -> void:
	player.apply_field_force(push, 0.0)
