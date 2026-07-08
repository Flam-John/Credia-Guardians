extends State
## Loan Shark: swim back to the home slot, then submerge.

var enemy: LoanShark


func on_context_ready() -> void:
	enemy = body as LoanShark


func enter(_prev: StringName) -> void:
	enemy.play(&"recover")
	enemy.set_facing(signi(int(enemy.home_position.x - enemy.global_position.x)))


func physics_update(_delta: float) -> void:
	var dx := enemy.home_position.x - enemy.global_position.x
	if absf(dx) < 4.0:
		enemy.velocity.x = 0.0
		machine.transition(&"Hidden")
		return
	enemy.velocity.x = signf(dx) * stats.move_speed * 0.4
