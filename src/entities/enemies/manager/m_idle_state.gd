extends State
## Angry Manager: stand, scan for the player (flips to face them on spot).

var enemy: AngryManager


func on_context_ready() -> void:
	enemy = body as AngryManager


func enter(_prev: StringName) -> void:
	enemy.play(&"idle")
	enemy.velocity.x = 0.0


func physics_update(_delta: float) -> void:
	var player := enemy.find_player()
	if player != null:
		enemy.set_facing(signi(int(player.global_position.x - enemy.global_position.x)))
	if enemy.can_see_player():
		machine.transition(&"Alert")
