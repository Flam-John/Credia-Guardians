extends PlayerState
## Chris signature: hold ability to block frontal hits (±60°) while the
## meter drains; walk at 30% speed. Blocking logic lives in
## Player._shield_blocks — this state only manages meter, movement, and exit.

const WALK_FACTOR := 0.3


func enter(_prev: StringName) -> void:
	player.play(&"ability")
	AudioManager.play_sfx("shield_on")


func physics_update(delta: float) -> void:
	player.shield_meter = maxf(0.0, player.shield_meter - delta)
	var axis := player.input_axis()
	player.velocity.x = move_toward(
		player.velocity.x, axis * stats.run_speed * WALK_FACTOR,
		stats.ground_accel * delta)
	# facing stays locked while shielding — the block arc shouldn't flip
	if not player.is_on_floor():
		player.start_coyote()
		machine.transition(&"Fall")
		return
	if not player.pressed(&"ability") or player.shield_meter <= 0.0:
		machine.transition(&"Run" if absf(axis) > 0.0 else &"Idle")


func exit() -> void:
	player.shield_regen_wait = stats.shield_regen_delay
	if player.shield_meter <= 0.0:
		AudioManager.play_sfx("shield_break")
