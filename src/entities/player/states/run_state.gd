extends PlayerState
## Grounded horizontal movement.


func enter(_prev: StringName) -> void:
	player.play(&"run")


func physics_update(delta: float) -> void:
	player.ground_move(delta)
	if try_ground_transitions():
		return
	if absf(player.input_axis()) == 0.0 and absf(player.velocity.x) < 5.0:
		machine.transition(&"Idle")
