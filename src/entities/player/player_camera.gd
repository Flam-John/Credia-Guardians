class_name PlayerCamera
extends Camera2D
## Pixel-perfect follow camera (docs/TDD.md §1): Godot smoothing stays OFF;
## we smooth a float position ourselves, then snap to whole pixels — smooth
## follow with zero subpixel shimmer. Adds facing lookahead.

const FOLLOW_SPEED := 6.0
const LOOKAHEAD := 24.0
const LOOKAHEAD_SPEED := 2.5

var _float_pos := Vector2.ZERO
var _lookahead_x := 0.0


func _ready() -> void:
	position_smoothing_enabled = false
	# Camera position is driven in _physics_process; detach from parent motion.
	top_level = true
	_float_pos = get_parent().global_position


func setup_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func snap_to_target() -> void:
	_float_pos = get_parent().global_position
	global_position = _float_pos.round()


func _physics_process(delta: float) -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var target_lookahead := player.facing * LOOKAHEAD
	_lookahead_x = lerpf(_lookahead_x, target_lookahead, LOOKAHEAD_SPEED * delta)
	var target := player.global_position + Vector2(_lookahead_x, 0.0)
	_float_pos = _float_pos.lerp(target, minf(1.0, FOLLOW_SPEED * delta))
	global_position = _float_pos.round()
