extends State
## P3: coin spiral — a rotating stream of gold projectiles.

const SHOTS := 14
const INTERVAL := 0.14
const SPEED := 110.0

var boss: CeoBoss
var _shot := 0
var _timer := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"coin_volley", &"spiral_cast")
	boss.velocity = Vector2.ZERO
	_shot = 0
	_timer = 0.5 # windup telegraph


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = INTERVAL
	var angle := _shot * TAU / 7.0 # rotating fan, deterministic
	boss.spawn_projectile(boss.global_position,
			Vector2.RIGHT.rotated(angle) * SPEED, Projectile.Visual.GOLD, 1, 0.0)
	_shot += 1
	if _shot >= SHOTS:
		machine.transition(&"Choose")
