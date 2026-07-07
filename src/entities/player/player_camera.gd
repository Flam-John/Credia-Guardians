class_name PlayerCamera
extends Camera2D
## Pixel-perfect follow camera (docs/TDD.md §1): Godot smoothing stays OFF;
## we smooth a float position ourselves, then snap to whole pixels — smooth
## follow with zero subpixel shimmer. Adds facing lookahead.

const FOLLOW_SPEED := 6.0
const LOOKAHEAD := 24.0
const LOOKAHEAD_SPEED := 2.5

const SHAKE_DECAY := 12.0

var _float_pos := Vector2.ZERO
var _lookahead_x := 0.0
var _shake := 0.0

@onready var _player: Player = get_parent() as Player


## Screenshake in pixels; decays automatically. Applied via `offset` so
## camera limits are unaffected.
func add_shake(amount_px: float) -> void:
	_shake = maxf(_shake, amount_px)


func _ready() -> void:
	position_smoothing_enabled = false
	# Camera position is driven in _physics_process; detach from parent motion.
	top_level = true
	# ORDERING CONTRACT: this camera must tick AFTER Player._physics_process
	# has moved the body, or it reads the pre-move position (one-frame lag =
	# visible jitter). Enforced by process_priority, not by tree position.
	process_priority = 1
	_float_pos = _player.global_position


func setup_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func snap_to_target() -> void:
	_float_pos = _player.global_position
	global_position = _float_pos.round()


func _physics_process(delta: float) -> void:
	var target_lookahead := _player.facing * LOOKAHEAD
	_lookahead_x = lerpf(_lookahead_x, target_lookahead, LOOKAHEAD_SPEED * delta)
	var target := _player.global_position + Vector2(_lookahead_x, 0.0)
	_float_pos = _float_pos.lerp(target, minf(1.0, FOLLOW_SPEED * delta))
	global_position = _float_pos.round()
	if _shake > 0.1:
		offset = Vector2(
			randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
