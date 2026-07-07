class_name JuniorBanker
extends EnemyBase
## Nervous patroller (docs/ENEMY_AI.md). Patrols ledges; panics at 1 HP,
## fleeing while dropping coins.

var edge_detector: EdgeDetectorComponent


func _ready() -> void:
	edge_detector = EdgeDetectorComponent.new()
	edge_detector.position = Vector2(0, -6)
	add_child(edge_detector)
	super()


func _on_took_hit() -> void:
	if health.hp == 1 and state_machine.current_name() != &"Panic":
		state_machine.transition(&"Panic")
