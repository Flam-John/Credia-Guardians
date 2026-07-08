extends State
## Invulnerable transformation beat between phases.

var boss: CeoBoss
var _left := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"phase_change", &"float")
	boss.velocity = Vector2.ZERO
	_left = 1.6
	GameFeel.shake(boss.get_tree(), 5.0)
	AudioManager.play_sfx("ai_teleport")
	if boss.phase == 3:
		boss.global_position.y -= 24.0 # demon lifts off


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Choose")
