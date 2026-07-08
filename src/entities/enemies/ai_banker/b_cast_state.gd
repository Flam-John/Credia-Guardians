extends State
## AI Banker: windup then a 3-projectile fan aimed at the player.

const CAST_FRAME := 2
const FAN_SPREAD_DEG := 18.0
const SHOT_SPEED := 130.0

var enemy: AIBanker
var _fired := false


func on_context_ready() -> void:
	enemy = body as AIBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"cast")
	enemy.velocity = Vector2.ZERO
	_fired = false


func physics_update(_delta: float) -> void:
	if not _fired and enemy.sprite.frame >= CAST_FRAME:
		_fired = true
		_fire_fan()
	if not enemy.sprite.is_playing():
		machine.transition(&"Stagger")


func _fire_fan() -> void:
	var player := enemy.find_player()
	if player == null:
		return
	var to_player := (player.global_position + Vector2(0, -12) - enemy.global_position).normalized()
	for spread in [-FAN_SPREAD_DEG, 0.0, FAN_SPREAD_DEG]:
		var dir := to_player.rotated(deg_to_rad(spread))
		enemy.spawn_projectile(enemy.global_position, dir * SHOT_SPEED,
				Projectile.Visual.PLASMA, 1, 0.0)
