extends State
## AI Banker: glitch out (intangible), then reappear elsewhere.

var enemy: AIBanker


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"teleport_out")
	enemy.velocity = Vector2.ZERO
	enemy.hurtbox.set_deferred("monitorable", false)
	AudioManager.play_sfx("ai_teleport")


func physics_update(_delta: float) -> void:
	if not enemy.sprite.is_playing():
		enemy.global_position = enemy.next_anchor()
		machine.transition(&"TeleportIn")
