extends PlayerState
## Horizontal burst at fixed speed; gravity suspended. Flam gets i-frames and
## extra air charges via CharacterStats. Dash is a commitment: not buffered,
## ends early on wall impact.


var _time_left := 0.0


func _init() -> void:
	overrides_gravity = true


func enter(_prev: StringName) -> void:
	player.play(&"dash")
	_time_left = stats.dash_duration
	if not player.is_on_floor():
		player.dash_charges_left -= 1
	player.velocity = Vector2(player.facing * stats.dash_speed, 0.0)
	player.invulnerable = stats.dash_has_iframes
	AudioManager.play_sfx("dash")


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.velocity = Vector2(player.facing * stats.dash_speed, 0.0)
	if _time_left <= 0.0 or player.is_on_wall():
		if player.is_on_floor():
			machine.transition(
				&"Run" if absf(player.input_axis()) > 0.0 else &"Idle")
		else:
			machine.transition(&"Fall")


func exit() -> void:
	player.invulnerable = false
	player.dash_cooldown_timer = stats.dash_cooldown
	# keep some momentum out of the dash, kill the rest
	player.velocity.x = player.facing * stats.run_speed
