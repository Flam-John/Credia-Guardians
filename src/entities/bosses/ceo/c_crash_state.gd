extends State
## P2 "MARKET CRASH": red pillars fall from the ceiling around the player.
## 0.6s telegraph pause before the drop (shadows in final art).

const DROPS := [-40.0, 0.0, 40.0, 80.0, -80.0]

var boss: CeoBoss
var _telegraph := 0.0
var _dropped := false
var _linger := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"idle", &"float")
	boss.velocity.x = 0.0
	_telegraph = 0.6
	_dropped = false
	_linger = 0.9
	AudioManager.play_sfx("manager_charge")


func physics_update(delta: float) -> void:
	if _telegraph > 0.0:
		_telegraph -= delta
		return
	if not _dropped:
		_dropped = true
		var px := boss.player_pos().x
		var ceiling_y := boss.global_position.y - 140.0
		for offset in DROPS:
			boss.spawn_projectile(Vector2(px + offset, ceiling_y),
					Vector2(0, 190.0), Projectile.Visual.PLASMA, 1, 0.0)
	_linger -= delta
	if _linger <= 0.0:
		machine.transition(&"Choose")
