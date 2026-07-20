extends PlayerState
## Flam signature: tap ability for a brief deflect window instead of holding
## a meter-drained block (Chris's BARRIER/ShieldState). No damage taken
## during the window (Player.parry_active, checked first in take_hit), full
## movement kept, and it works in the air — a skill button, not a stance.

var _window_left := 0.0


func enter(_prev: StringName) -> void:
	player.parry_active = true
	player.shield_sprite.position.x = 10 * player.facing
	player.shield_sprite.flip_h = player.facing < 0
	player.shield_sprite.visible = true
	player.play(&"ability")
	AudioManager.play_sfx("shield_on")
	_window_left = stats.parry_window


func physics_update(delta: float) -> void:
	if player.is_on_floor():
		player.ground_move(delta)
	else:
		player.air_move(delta)
	# Parry keeps full movement control, so facing can flip mid-window —
	# re-track it every tick or the buckler sprite desyncs (review catch).
	player.shield_sprite.position.x = 10 * player.facing
	player.shield_sprite.flip_h = player.facing < 0
	_window_left -= delta
	if _window_left <= 0.0:
		_finish()


func exit() -> void:
	player.parry_active = false
	player.shield_sprite.visible = false
	player.parry_cooldown_timer = stats.parry_cooldown


func _finish() -> void:
	if not player.is_on_floor():
		machine.transition(&"Fall")
	elif absf(player.input_axis()) > 0.0:
		machine.transition(&"Run")
	else:
		machine.transition(&"Idle")
