extends PlayerState
## Single air slash. Normal air physics continue; no combo.

const ACTIVE_FRAMES := [1, 2]

var _was_active := false


func enter(_prev: StringName) -> void:
	_was_active = false
	player.play(&"air_attack")
	player.melee_shape.position.x = 14 * player.facing
	AudioManager.play_sfx("attack_1")


func physics_update(delta: float) -> void:
	player.air_move(delta)
	var frame := player.sprite.frame
	var in_window: bool = frame >= ACTIVE_FRAMES[0] and frame <= ACTIVE_FRAMES[1]
	if in_window and not _was_active:
		player.melee_hitbox.activate()
	elif not in_window and _was_active:
		player.melee_hitbox.deactivate()
	_was_active = in_window
	if not player.sprite.is_playing() or player.is_on_floor():
		if not try_land():
			machine.transition(&"Fall")


func exit() -> void:
	player.melee_hitbox.deactivate()
