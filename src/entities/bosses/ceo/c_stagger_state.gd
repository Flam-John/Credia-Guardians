extends State
## Bent over after a slam — the P1/P2 damage window.

var boss: CeoBoss
var _left := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"stagger", &"core_exposed")
	boss.vulnerable = true
	_left = 1.5


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Choose")


func exit() -> void:
	boss.vulnerable = false
