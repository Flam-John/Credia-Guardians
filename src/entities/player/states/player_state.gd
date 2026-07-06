class_name PlayerState
extends State
## Base for player states: typed accessors + transitions shared by most states
## (docs/PLAYER_FSM.md). Enemy states extend State directly, not this.


var player: Player:
	get:
		return body as Player


## Jump / dash checks common to every ground state. Returns true if it
## transitioned (caller should stop processing this frame).
func try_ground_transitions() -> bool:
	if player.jump_buffered():
		machine.transition(&"Jump")
		return true
	if Input.is_action_just_pressed(&"dash") and player.can_dash():
		machine.transition(&"Dash")
		return true
	if not player.is_on_floor():
		player.start_coyote()
		machine.transition(&"Fall")
		return true
	return false


## Jump / double-jump / dash checks common to airborne states.
func try_air_transitions() -> bool:
	if player.jump_buffered():
		if player.coyote_active():
			machine.transition(&"Jump")
			return true
		if player.air_jumps_left > 0:
			machine.transition(&"DoubleJump")
			return true
	if Input.is_action_just_pressed(&"dash") and player.can_dash():
		machine.transition(&"Dash")
		return true
	return false


## Landing check for airborne states.
func try_land() -> bool:
	if player.is_on_floor():
		machine.transition(&"Run" if absf(player.input_axis()) > 0.0 else &"Idle")
		return true
	return false
