extends PlayerState
## Ranged weapon: quick fire pose, one bullet on entry, then back to whatever
## the player was doing. Unlike Attack (a committed combo), Fire keeps full
## movement control — it's a secondary poke, not a combo (docs/GDD.md §4).
## The real anti-spam gate is Player.weapon_cooldown_timer, set on exit()
## exactly like DashState sets dash_cooldown_timer.


func enter(_prev: StringName) -> void:
	player.play(&"attack_1")
	player.weapon_sprite.position.x = 7 * player.facing
	player.weapon_sprite.flip_h = player.facing < 0
	player.weapon_sprite.visible = true
	player.fire_weapon()


func physics_update(_delta: float) -> void:
	if player.is_on_floor():
		player.ground_move(_delta)
	else:
		player.air_move(_delta)
	# Fire (unlike Attack/Shield) keeps full movement control, so facing can
	# flip mid-pose — re-track it every tick or the held sprite desyncs from
	# the body (review catch).
	player.weapon_sprite.position.x = 7 * player.facing
	player.weapon_sprite.flip_h = player.facing < 0
	if not player.sprite.is_playing():
		_finish()


func exit() -> void:
	player.weapon_sprite.visible = false
	player.weapon_cooldown_timer = stats.weapon_cooldown


func _finish() -> void:
	if not player.is_on_floor():
		machine.transition(&"Fall")
	elif absf(player.input_axis()) > 0.0:
		machine.transition(&"Run")
	else:
		machine.transition(&"Idle")
