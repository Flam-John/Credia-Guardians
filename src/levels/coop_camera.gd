class_name CoopCamera
extends Camera2D
## Shared co-op camera: pixel-snapped midpoint of all living players.
## Same subpixel technique as PlayerCamera; no lookahead (two players pull
## opposite ways).

const FOLLOW_SPEED := 6.0

var _float_pos := Vector2.ZERO


func setup_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func _ready() -> void:
	position_smoothing_enabled = false
	process_priority = 1 # after player bodies move
	_float_pos = global_position


func snap_now() -> void:
	var target := _target()
	if target != Vector2.INF:
		_float_pos = target
		global_position = _float_pos.round()


func _physics_process(delta: float) -> void:
	var target := _target()
	if target == Vector2.INF:
		return
	_float_pos = _float_pos.lerp(target, minf(1.0, FOLLOW_SPEED * delta))
	global_position = _float_pos.round()


func _target() -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for node in get_tree().get_nodes_in_group(&"player"):
		var player := node as Player
		if player != null and not player.health.is_dead():
			sum += player.global_position
			count += 1
	return sum / count if count > 0 else Vector2.INF
