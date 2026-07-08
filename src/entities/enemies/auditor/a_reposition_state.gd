extends State
## Auditor: hop back into the comfort band (away if too close, toward if far).

const HOP := Vector2(60.0, -140.0)

var enemy: Auditor
var _airborne := false


func on_context_ready() -> void:
	enemy = body as Auditor


func enter(_prev: StringName) -> void:
	enemy.play(&"hop_back")
	_airborne = false
	var player := enemy.find_player()
	if player == null:
		machine.transition(&"Idle")
		return
	var away := signf(enemy.global_position.x - player.global_position.x)
	var dir := away if enemy.distance_to_player() < Auditor.BAND_NEAR else -away
	enemy.velocity = Vector2(dir * HOP.x, HOP.y)


func physics_update(_delta: float) -> void:
	if not enemy.is_on_floor():
		_airborne = true
	elif _airborne: # landed
		enemy.velocity.x = 0.0
		machine.transition(&"Idle")
