extends State
## Auditor: 4-frame windup, lob a ledger in an arc at the player's position.

const THROW_FRAME := 2
const ARC_GRAVITY := 300.0
const FLIGHT_TIME := 0.9

var enemy: Auditor
var _thrown := false


func on_context_ready() -> void:
	enemy = body as Auditor


func enter(_prev: StringName) -> void:
	enemy.play(&"throw")
	enemy.velocity.x = 0.0
	_thrown = false
	AudioManager.play_sfx("ledger_throw")


func physics_update(_delta: float) -> void:
	if not _thrown and enemy.sprite.frame >= THROW_FRAME:
		_thrown = true
		_lob()
	if not enemy.sprite.is_playing():
		machine.transition(&"Idle")


func _lob() -> void:
	var player := enemy.find_player()
	if player == null:
		return
	var from := enemy.global_position + Vector2(enemy.facing * 10, -20)
	var to := player.global_position + Vector2(0, -8)
	# ballistic solve for fixed flight time
	var vx := (to.x - from.x) / FLIGHT_TIME
	var vy := (to.y - from.y) / FLIGHT_TIME - 0.5 * ARC_GRAVITY * FLIGHT_TIME
	enemy.spawn_projectile(from, Vector2(vx, vy), Projectile.Visual.LEDGER, 1, ARC_GRAVITY)
