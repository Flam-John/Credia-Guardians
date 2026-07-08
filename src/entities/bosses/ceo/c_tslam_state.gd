extends State
## P3: glitch above the player, hover a beat (telegraph), slam down.

var boss: CeoBoss
var _hover := 0.0
var _slamming := false


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"idle", &"teleport")
	AudioManager.play_sfx("ai_teleport")
	boss.global_position = Vector2(
			boss.player_pos().x, boss.global_position.y - 60.0)
	boss.velocity = Vector2.ZERO
	_hover = 0.5
	_slamming = false


func physics_update(delta: float) -> void:
	if _hover > 0.0:
		_hover -= delta
		if _hover <= 0.0:
			_slamming = true
			boss.velocity = Vector2(0, 340.0)
		return
	if _slamming and boss.is_on_floor():
		boss.velocity = Vector2.ZERO
		GameFeel.shake(boss.get_tree(), 5.0)
		AudioManager.play_sfx("stomp")
		for dir in [-1.0, 1.0]:
			boss.spawn_projectile(boss.global_position + Vector2(dir * 40, -6),
					Vector2(dir * 160.0, 0), Projectile.Visual.GOLD, 1, 0.0)
		boss.global_position.y -= 40.0 # lift back off
		machine.transition(&"Choose")
