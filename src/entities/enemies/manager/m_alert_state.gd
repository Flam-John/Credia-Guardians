extends State
## Angry Manager: "!!" telegraph before the charge — every attack is
## reactable (docs/ENEMY_AI.md boss/enemy telegraph rule).

const TELEGRAPH := 0.4

var enemy: AngryManager
var _left := 0.0


func on_context_ready() -> void:
	enemy = body as AngryManager


func enter(_prev: StringName) -> void:
	enemy.play(&"alert")
	AudioManager.play_sfx("manager_charge")
	enemy.velocity.x = 0.0
	_left = TELEGRAPH


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Charge")
