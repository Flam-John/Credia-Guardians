extends State
## Junior Banker: walk, flip at walls and ledges.

var enemy: JuniorBanker


func on_context_ready() -> void:
	enemy = body as JuniorBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"walk")


func physics_update(_delta: float) -> void:
	if enemy.is_on_floor() \
			and (enemy.edge_detector.is_wall_ahead() or enemy.edge_detector.is_ledge_ahead()):
		enemy.set_facing(-enemy.facing)
		enemy.edge_detector.set_direction(enemy.facing)
	enemy.velocity.x = enemy.facing * stats.move_speed
