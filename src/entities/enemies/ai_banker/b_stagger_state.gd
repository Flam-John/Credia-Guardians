extends State
## AI Banker: 1.5s vulnerable hover after casting — THE punish window.

const STAGGER_TIME := 1.5

var enemy: AIBanker
var _left := 0.0


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"stagger")
	enemy.velocity = Vector2.ZERO
	_left = STAGGER_TIME


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"TeleportOut")
