extends State
## Angry Manager: fixed-direction charge. Wall → WallStun (punish window);
## 200 px traveled without a wall → Cooldown.

var enemy: AngryManager
var _start_x := 0.0


func on_context_ready() -> void:
	enemy = body as AngryManager


func enter(_prev: StringName) -> void:
	enemy.play(&"charge")
	_start_x = enemy.global_position.x


func physics_update(_delta: float) -> void:
	# stats-driven so the Regional Manager elite charges faster (docs/ENEMY_AI.md)
	enemy.velocity.x = enemy.facing * stats.move_speed
	if enemy.is_on_wall():
		machine.transition(&"WallStun")
	elif absf(enemy.global_position.x - _start_x) >= AngryManager.CHARGE_MAX_DISTANCE:
		machine.transition(&"Cooldown")
