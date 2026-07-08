extends State
## P3: core exposed — the ONLY damage window of the final phase.

var boss: CeoBoss
var _left := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"stagger", &"core_exposed")
	boss.velocity = Vector2.ZERO
	boss.vulnerable = true
	_left = 2.0
	AudioManager.play_sfx("node_hold_loop")


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Choose")


func exit() -> void:
	boss.vulnerable = false
