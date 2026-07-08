extends State
## Loan Shark: burst out of cover — the telegraph before the lunge.

var enemy: LoanShark


func on_context_ready() -> void:
	enemy = body as LoanShark


func enter(_prev: StringName) -> void:
	enemy.play(&"emerge")
	AudioManager.play_sfx("shark_lunge")
	var player := enemy.find_player()
	if player != null:
		enemy.set_facing(signi(int(player.global_position.x - enemy.global_position.x)))


func physics_update(_delta: float) -> void:
	if not enemy.sprite.is_playing():
		machine.transition(&"Lunge")
