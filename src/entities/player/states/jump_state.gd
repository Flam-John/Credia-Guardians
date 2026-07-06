extends PlayerState
## Ground (or coyote) jump ascent. Variable height: releasing jump during
## ascent cuts velocity for short hops.


func enter(_prev: StringName) -> void:
	player.play(&"jump")
	player.consume_jump_buffer()
	player.coyote_timer = 0.0
	player.velocity.y = stats.jump_velocity
	AudioManager.play_sfx("jump")


func physics_update(delta: float) -> void:
	player.air_move(delta)
	if Input.is_action_just_released(&"jump") and player.velocity.y < 0.0:
		player.velocity.y *= stats.jump_cut_multiplier
	if try_air_transitions():
		return
	if player.velocity.y >= 0.0:
		machine.transition(&"Fall")
