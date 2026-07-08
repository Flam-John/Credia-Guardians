extends State
## Auditor: adjust glasses, decide between repositioning and throwing.

var enemy: Auditor
var _cooldown := 0.0


func on_context_ready() -> void:
	enemy = body as Auditor


func enter(_prev: StringName) -> void:
	enemy.play(&"idle")
	enemy.velocity.x = 0.0
	_cooldown = stats.attack_cooldown


func physics_update(delta: float) -> void:
	_cooldown -= delta
	enemy.face_player()
	var dist := enemy.distance_to_player()
	if dist > stats.detection_range:
		return
	if dist < Auditor.BAND_NEAR or dist > Auditor.BAND_FAR:
		machine.transition(&"Reposition")
	elif _cooldown <= 0.0:
		machine.transition(&"Throw")
