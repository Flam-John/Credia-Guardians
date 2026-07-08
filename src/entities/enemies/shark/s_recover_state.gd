extends State
## Loan Shark: exposed on the ground — the punish window. Re-lunges if the
## player stays close (max 2 consecutive), else returns to cover.

const RECOVER_TIME := 1.0
const RELUNGE_RANGE := 80.0

var enemy: LoanShark
var _left := 0.0


func on_context_ready() -> void:
	enemy = body as LoanShark


func enter(_prev: StringName) -> void:
	enemy.play(&"recover")
	_left = RECOVER_TIME


func physics_update(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	if enemy.player_distance() <= RELUNGE_RANGE \
			and enemy.consecutive_lunges < LoanShark.MAX_CONSECUTIVE_LUNGES:
		var player := enemy.find_player()
		if player != null:
			enemy.set_facing(signi(int(player.global_position.x - enemy.global_position.x)))
		machine.transition(&"Lunge")
	else:
		machine.transition(&"Return")
