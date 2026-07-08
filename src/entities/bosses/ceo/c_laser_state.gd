extends State
## P3: floor-level laser sweep across the arena — dash i-frames, shield, or
## a well-timed jump. TimedHazard provides the built-in 0.3s telegraph.

const ARENA_HALF := 130.0

var boss: CeoBoss
var _left := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"idle", &"laser_sweep")
	boss.velocity = Vector2.ZERO
	_left = 1.6
	var laser := TimedHazard.new()
	laser.on_time = 0.9
	laser.off_time = 99.0 # one-shot: freed before it recycles
	laser.phase_offset = 99.0 - TimedHazard.TELEGRAPH # start in telegraph
	laser.position = boss.global_position + Vector2(-ARENA_HALF, 30.0)
	boss.get_parent().add_child(laser)
	laser.setup(Vector2(ARENA_HALF * 2.0, 6))
	AudioManager.play_sfx("projectile")
	boss.get_tree().create_timer(1.5, false).timeout.connect(
			laser.queue_free, CONNECT_ONE_SHOT)


func physics_update(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		machine.transition(&"Choose")
