extends PlayerState
## Knockback + brief stun after taking damage, then 1s of hurtbox
## invulnerability with sprite flicker (docs/GDD.md §4).

const STUN_TIME := 0.15
const INVULN_TIME := 1.0
const KNOCKBACK := Vector2(110.0, -120.0)

var _stun_left := 0.0


func enter(_prev: StringName) -> void:
	player.play(&"hurt")
	AudioManager.play_sfx("hurt")
	_stun_left = STUN_TIME
	var away := signf(player.global_position.x - player.last_hit_from.x)
	if away == 0.0:
		away = -player.facing
	player.velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y)
	player.hurtbox.start_invuln(INVULN_TIME)
	_flicker()


func physics_update(_delta: float) -> void:
	_stun_left -= _delta
	if _stun_left > 0.0:
		return # no control during stun; gravity + knockback decay only
	if player.is_on_floor():
		machine.transition(&"Run" if absf(player.input_axis()) > 0.0 else &"Idle")
	else:
		machine.transition(&"Fall")


func _flicker() -> void:
	var tween := player.create_tween()
	tween.set_loops(int(INVULN_TIME / 0.2))
	tween.tween_property(player.sprite, "modulate:a", 0.35, 0.1)
	tween.tween_property(player.sprite, "modulate:a", 1.0, 0.1)
