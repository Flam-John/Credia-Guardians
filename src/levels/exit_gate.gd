class_name ExitGate
extends GateProp
## Stage-end firewall gate: solid + red while locked; the LEVEL unlocks it
## (all nodes active, boss down). Entering when open clears the stage.

signal entered


func unlock() -> void:
	open_gate()


func _gate_opened() -> void:
	_sweep_overlaps()


func _on_body_entered(body: Node2D) -> void:
	if open and body is Player:
		set_deferred("monitoring", false)
		entered.emit()


## A player hugging the locked gate is already inside the area when it opens;
## body_entered won't re-fire, so sweep current overlaps once.
func _sweep_overlaps() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)
