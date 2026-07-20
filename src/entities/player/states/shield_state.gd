extends PlayerState
## Chris signature (BARRIER style): hold ability to block frontal hits (±60°);
## unlimited — no meter, no cooldown, hold it as long as you want — at 30%
## walk speed. Blocking logic lives in Player._shield_blocks — this state
## only manages movement, the visible hex-barrier sprite, and exit. Flam's
## PARRY style uses a separate ParryState instead — different button feel
## (tap vs hold), not a reskin.

const WALK_FACTOR := 0.3


func enter(_prev: StringName) -> void:
	player.play(&"ability")
	player.shield_sprite.position.x = 10 * player.facing
	player.shield_sprite.flip_h = player.facing < 0
	player.shield_sprite.visible = true
	AudioManager.play_sfx("shield_on")


func physics_update(delta: float) -> void:
	var axis := player.input_axis()
	player.velocity.x = move_toward(
		player.velocity.x, axis * stats.run_speed * WALK_FACTOR,
		stats.ground_accel * delta)
	# facing stays locked while shielding — the block arc shouldn't flip
	if not player.is_on_floor():
		player.start_coyote()
		machine.transition(&"Fall")
		return
	if not player.pressed(&"ability"):
		machine.transition(&"Run" if absf(axis) > 0.0 else &"Idle")


func exit() -> void:
	player.shield_sprite.visible = false
