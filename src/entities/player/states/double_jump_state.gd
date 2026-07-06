extends PlayerState
## Air jump (flip). One charge, restored on landing.


func enter(_prev: StringName) -> void:
	player.play(&"double_jump")
	player.consume_jump_buffer()
	player.air_jumps_left -= 1
	player.velocity.y = stats.double_jump_velocity
	AudioManager.play_sfx("double_jump")


func physics_update(delta: float) -> void:
	player.air_move(delta)
	if Input.is_action_just_released(&"jump") and player.velocity.y < 0.0:
		player.velocity.y *= stats.jump_cut_multiplier
	if try_air_transitions():
		return
	if player.velocity.y >= 0.0:
		machine.transition(&"Fall")
