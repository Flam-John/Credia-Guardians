class_name PlayerState
extends State
## Base for player states: typed accessors + transitions shared by most states
## (docs/PLAYER_FSM.md). Enemy states extend State directly, not this.

## Plain field (not a casting getter) — states touch this many times per
## physics frame.
var player: Player


func on_context_ready() -> void:
	player = body as Player


## Jump / dash / attack / shield checks common to every ground state.
## Returns true if it transitioned (caller should stop processing this frame).
func try_ground_transitions() -> bool:
	if player.jump_buffered():
		machine.transition(&"Jump")
		return true
	if player.just_pressed(&"dash") and player.can_dash():
		machine.transition(&"Dash")
		return true
	if player.just_pressed(&"attack"):
		machine.transition(&"Attack")
		return true
	# Minimum meter to raise the shield: without it, holding the button after
	# depletion re-enters Shield the frame regen ticks past zero, draining it
	# instantly and re-arming the regen delay forever (starvation loop).
	if player.pressed(&"ability") and stats.has_shield \
			and player.shield_meter >= 0.5:
		machine.transition(&"Shield")
		return true
	if not player.is_on_floor():
		player.start_coyote()
		machine.transition(&"Fall")
		return true
	return false


## Jump / double-jump / dash checks common to airborne states.
## The jump buffer only redeems on ground/coyote frames (docs/PLAYER_FSM.md);
## a double jump requires a FRESH press — otherwise a press swallowed by a
## non-jump state (e.g. during Dash) would burn the air jump moments later.
func try_air_transitions() -> bool:
	if player.jump_buffered() and player.coyote_active():
		machine.transition(&"Jump")
		return true
	if player.just_pressed(&"jump") and player.air_jumps_left > 0:
		machine.transition(&"DoubleJump")
		return true
	if player.just_pressed(&"dash") and player.can_dash():
		machine.transition(&"Dash")
		return true
	if player.just_pressed(&"attack"):
		machine.transition(&"AirAttack")
		return true
	return false


## Landing check for airborne states.
func try_land() -> bool:
	if player.is_on_floor():
		player.emit_land_dust()
		AudioManager.play_sfx("land")
		machine.transition(&"Run" if absf(player.input_axis()) > 0.0 else &"Idle")
		return true
	return false
