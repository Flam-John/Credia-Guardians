extends State
## Angry Manager crashed into a wall: 1.2s dizzy, takes DOUBLE damage.

const STUN := 1.2

var enemy: AngryManager
var _left := 0.0


func on_context_ready() -> void:
	enemy = body as AngryManager


func enter(_prev: StringName) -> void:
	enemy.play(&"wall_stun")
	enemy.velocity.x = 0.0
	enemy.damage_taken_multiplier = 2.0
	_left = STUN


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Idle")


func exit() -> void:
	enemy.damage_taken_multiplier = 1.0
