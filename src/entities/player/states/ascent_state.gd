class_name AscentState
extends PlayerState
## Shared ascent physics for Jump and DoubleJump: air control, variable jump
## cut, apex handoff to Fall. Subclasses implement _begin_ascent() only.

var _cut_done := false


func enter(_prev: StringName) -> void:
	_cut_done = false
	player.consume_jump_buffer()
	_begin_ascent()


## Subclass hook: play animation, set velocity.y, consume charges, SFX.
func _begin_ascent() -> void:
	assert(false, "AscentState subclasses must implement _begin_ascent()")


func physics_update(delta: float) -> void:
	player.air_move(delta)
	# Level-based (not edge-based) cut: a jump that entered via the buffer may
	# have had its button released before the state began — it still short-hops.
	if not _cut_done and player.velocity.y < 0.0 and not Input.is_action_pressed(&"jump"):
		player.velocity.y *= stats.jump_cut_multiplier
		_cut_done = true
	if try_air_transitions():
		return
	if player.velocity.y >= 0.0:
		machine.transition(&"Fall")
