extends State
## Leap to the player's position, slam down: ground shockwave both ways.
## Landing bends him over -> Stagger (THE P1/P2 punish window).

var boss: CeoBoss
var _airborne := false
var _windup := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"slam", &"teleport")
	_airborne = false
	_windup = 0.5 / boss.speed_mult # telegraph before the leap
	boss.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			var dx := boss.player_pos().x - boss.global_position.x
			boss.velocity = Vector2(clampf(dx / 0.7, -260, 260), -270.0)
		return
	if not boss.is_on_floor():
		_airborne = true
	elif _airborne:
		boss.velocity = Vector2.ZERO
		GameFeel.shake(boss.get_tree(), 4.0)
		AudioManager.play_sfx("stomp")
		for dir in [-1.0, 1.0]: # ground shockwave
			boss.spawn_projectile(boss.global_position + Vector2(dir * 30, -6),
					Vector2(dir * 140.0, 0), Projectile.Visual.GOLD, 1, 0.0)
		machine.transition(&"Stagger")
