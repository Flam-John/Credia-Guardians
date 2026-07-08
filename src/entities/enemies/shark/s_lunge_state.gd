extends State
## Loan Shark: leaping arc toward the player. Contact 2 dmg (EnemyStats).

var enemy: LoanShark
var _airborne := false


func on_context_ready() -> void:
	enemy = body as LoanShark


func enter(_prev: StringName) -> void:
	enemy.play(&"lunge")
	_airborne = false
	enemy.consecutive_lunges += 1
	enemy.velocity = Vector2(enemy.facing * stats.move_speed, -180.0)


func physics_update(_delta: float) -> void:
	if not enemy.is_on_floor():
		_airborne = true
	elif _airborne:
		enemy.velocity.x = 0.0
		machine.transition(&"Recover")
