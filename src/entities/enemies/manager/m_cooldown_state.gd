extends State
## Angry Manager: heavy breathing after a full-length charge; re-alerts if
## the player is still visible, otherwise back to Idle.

var enemy: AngryManager
var _left := 0.0


func on_context_ready() -> void:
	enemy = body as AngryManager


func enter(_prev: StringName) -> void:
	enemy.play(&"idle")
	enemy.velocity.x = 0.0
	_left = stats.attack_cooldown


func physics_update(delta: float) -> void:
	var player := enemy.find_player()
	if player != null:
		enemy.set_facing(signi(int(player.global_position.x - enemy.global_position.x)))
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Alert" if enemy.can_see_player() else &"Idle")
