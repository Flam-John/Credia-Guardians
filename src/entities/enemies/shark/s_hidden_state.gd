extends State
## Loan Shark: submerged, fin tell only, invulnerable and harmless.

var enemy: LoanShark


func on_context_ready() -> void:
	enemy = body as LoanShark


func enter(_prev: StringName) -> void:
	enemy.play(&"hidden_fin")
	enemy.set_hidden_mode(true)
	enemy.consecutive_lunges = 0
	enemy.velocity.x = 0.0


func physics_update(_delta: float) -> void:
	if enemy.player_distance() <= stats.detection_range:
		machine.transition(&"Emerge")


func exit() -> void:
	enemy.set_hidden_mode(false)
