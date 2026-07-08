extends State
## AI Banker: call for backup (once per 50% HP lost, max 2 minions alive).

var enemy: AIBanker


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"cast")
	enemy.velocity = Vector2.ZERO
	enemy.summon_minion()


func physics_update(_delta: float) -> void:
	if not enemy.sprite.is_playing():
		machine.transition(&"TeleportOut")
