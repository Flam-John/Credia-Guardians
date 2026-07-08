extends PlayerState
## 3-hit ground combo. Hitbox active during sprite frames ACTIVE_FRAMES of
## each swing (frame-driven, no AnimationPlayer needed). A press inside the
## combo window queues the next swing.

## Per combo index (1-based): {anim, active: [first, last]}
const SWINGS := {
	1: {"anim": &"attack_1", "active": [1, 2]},
	2: {"anim": &"attack_2", "active": [1, 2]},
	3: {"anim": &"attack_3", "active": [2, 3]},
}
const MOMENTUM_KEEP := 0.5

var combo_index := 1
var _next_queued := false
var _was_active := false


func enter(prev: StringName) -> void:
	if prev != &"Attack":
		combo_index = 1
	_next_queued = false
	_was_active = false
	player.velocity.x *= MOMENTUM_KEEP
	var swing: Dictionary = SWINGS[combo_index]
	player.play(swing.anim)
	_position_hitbox()
	AudioManager.play_sfx("attack_%d" % combo_index)


func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0.0, stats.ground_friction * delta)
	if player.just_pressed(&"attack"):
		_next_queued = true
	_drive_hitbox()
	if not player.sprite.is_playing():
		_finish()


func exit() -> void:
	player.melee_hitbox.deactivate()


func _drive_hitbox() -> void:
	var active: Array = SWINGS[combo_index].active
	var in_window: bool = player.sprite.frame >= active[0] and player.sprite.frame <= active[1]
	if in_window and not _was_active:
		player.melee_hitbox.activate()
	elif not in_window and _was_active:
		player.melee_hitbox.deactivate()
	_was_active = in_window


func _position_hitbox() -> void:
	player.melee_shape.position.x = 14 * player.facing


func _finish() -> void:
	if _next_queued and combo_index < 3:
		# chain: same state, so re-enter locally (machine.transition to the
		# current state is deliberately a no-op)
		combo_index += 1
		exit()
		enter(&"Attack")
		return
	combo_index = 1
	if not player.is_on_floor():
		machine.transition(&"Fall")
	elif absf(player.input_axis()) > 0.0:
		machine.transition(&"Run")
	else:
		machine.transition(&"Idle")
