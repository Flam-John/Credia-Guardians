class_name Auditor
extends EnemyBase
## Spacing ranged enemy (docs/ENEMY_AI.md): keeps a 100–140px band, lobs
## ledger projectiles. NOT stompable (spiked ledger hat).

const BAND_NEAR := 100.0
const BAND_FAR := 140.0


func distance_to_player() -> float:
	var player := find_player()
	if player == null:
		return INF
	return absf(player.global_position.x - global_position.x)


func face_player() -> void:
	var player := find_player()
	if player != null:
		set_facing(signi(int(player.global_position.x - global_position.x)))
