extends PlayerState
## Standing still on the ground.


func enter(_prev: StringName) -> void:
	player.play(&"idle")


func physics_update(delta: float) -> void:
	player.ground_move(delta)
	if try_ground_transitions():
		return
	if absf(player.input_axis()) > 0.0:
		machine.transition(&"Run")
