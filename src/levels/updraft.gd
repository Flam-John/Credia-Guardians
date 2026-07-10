class_name Updraft
extends PushZone
## Coffee-steam column: lifts the player while inside (boosted jumps).

@export var strength := 260.0 # upward accel px/s^2


func setup(height_tiles: int) -> void:
	add_rect_shape(Vector2(14, height_tiles * 16), Vector2(8, height_tiles * 8.0))
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


func _affect(player: Player) -> void:
	player.apply_field_force(0.0, strength)
