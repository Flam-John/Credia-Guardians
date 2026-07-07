extends PlayerState
## Airborne descent. Coyote jump remains available briefly after walking off
## a ledge (player.start_coyote() is called by the state that left the ground).


func enter(_prev: StringName) -> void:
	player.play(&"fall")


func physics_update(delta: float) -> void:
	player.air_move(delta)
	if try_land():
		return
	try_air_transitions()
