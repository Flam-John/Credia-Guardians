extends State
## AI Banker: glitch back in at the new anchor, tangible again.

var enemy: AIBanker


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"teleport_in")


func physics_update(_delta: float) -> void:
	if not enemy.sprite.is_playing():
		enemy.hurtbox.set_deferred("monitorable", true)
		machine.transition(&"Float")
