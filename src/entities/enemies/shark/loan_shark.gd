class_name LoanShark
extends EnemyBase
## Ambusher (docs/ENEMY_AI.md): lurks with only a fin showing, lunges when
## the player closes in. Only vulnerable while emerged.

const MAX_CONSECUTIVE_LUNGES := 2

var home_position := Vector2.ZERO
var consecutive_lunges := 0


func _ready() -> void:
	super()
	home_position = global_position


func set_hidden_mode(hidden: bool) -> void:
	hurtbox.set_deferred("monitorable", not hidden)
	# no touch damage while it's just a fin
	_contact_area.set_deferred("monitoring", not hidden)


func player_distance() -> float:
	var player := find_player()
	if player == null:
		return INF
	return absf(player.global_position.x - global_position.x)
