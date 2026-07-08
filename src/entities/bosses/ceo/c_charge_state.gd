extends State
## Desk-charge across the arena until a wall stops him.

var boss: CeoBoss
var _windup := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"charge", &"teleport")
	AudioManager.play_sfx("manager_charge")
	_windup = 0.5 / boss.speed_mult
	boss.velocity.x = 0.0
	boss.set_facing(signi(int(boss.player_pos().x - boss.global_position.x)))


func physics_update(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		return
	boss.velocity.x = boss.facing * 170.0 * boss.speed_mult
	if boss.is_on_wall():
		boss.velocity.x = 0.0
		GameFeel.shake(boss.get_tree(), 3.0)
		machine.transition(&"Choose")
