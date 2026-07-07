extends AscentState
## Ground (or coyote) jump. Ascent physics live in AscentState.


func _begin_ascent() -> void:
	player.play(&"jump")
	player.coyote_timer = 0.0
	player.velocity.y = stats.jump_velocity
	AudioManager.play_sfx("jump")
