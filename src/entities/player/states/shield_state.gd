extends PlayerState
## BARRIER style (both Chris and Flam): hold ability to block ANY hit —
## melee, contact, or projectile, from any direction — unlimited (no meter,
## no cooldown, hold as long as you want) at 30% walk speed. Blocking logic
## lives in Player._shield_blocks — this state only manages movement, the
## visible shield sprite, and exit. PARRY is a separate style/state (tap vs
## hold) that no shipped character currently uses.

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
	# facing stays locked while shielding (cosmetic — blocking itself is
	# omnidirectional now, this just keeps the held sprite from flip-flopping)
	if not player.is_on_floor():
		player.start_coyote()
		machine.transition(&"Fall")
		return
	if not player.pressed(&"ability"):
		machine.transition(&"Run" if absf(axis) > 0.0 else &"Idle")


func exit() -> void:
	player.shield_sprite.visible = false
