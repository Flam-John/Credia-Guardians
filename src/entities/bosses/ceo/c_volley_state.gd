extends State
## Coin-toss volley: 5 gold arcs raining toward the player's side.

const FIRE_FRAME := 2

var boss: CeoBoss
var _fired := false


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"coin_volley", &"spiral_cast")
	boss.velocity.x = 0.0
	_fired = false


func physics_update(_delta: float) -> void:
	if not _fired and boss.sprite.frame >= FIRE_FRAME:
		_fired = true
		var dir := signf(boss.player_pos().x - boss.global_position.x)
		for i in 5:
			boss.spawn_projectile(
					boss.global_position + Vector2(0, -60),
					Vector2(dir * (40.0 + i * 28.0), -160.0 - i * 8.0),
					Projectile.Visual.GOLD, 1, 380.0)
	if not boss.sprite.is_playing():
		machine.transition(&"Choose")
