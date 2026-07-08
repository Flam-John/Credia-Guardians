extends State
## AI Banker: hover-bob at the current anchor; decide next move.

var enemy: AIBanker
var _time := 0.0
var _cooldown := 0.0


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"float")
	_cooldown = stats.attack_cooldown


func physics_update(delta: float) -> void:
	_time += delta
	_cooldown -= delta
	enemy.velocity = Vector2(0, sin(_time * 3.0) * 12.0)
	if enemy.consume_summon_request():
		machine.transition(&"Summon")
		return
	if _cooldown <= 0.0 and enemy.player_in_range():
		machine.transition(&"Cast")
