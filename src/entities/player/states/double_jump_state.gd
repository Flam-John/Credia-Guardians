extends AscentState
## Air jump (flip). One charge, restored on landing. Ascent physics live in
## AscentState.


func _begin_ascent() -> void:
	player.play(&"double_jump")
	player.air_jumps_left -= 1
	player.velocity.y = stats.double_jump_velocity
	AudioManager.play_sfx("double_jump")
