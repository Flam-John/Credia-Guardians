extends PlayerState
## Death: play animation, ignore input, announce once. Respawn is owned by
## the level's RespawnController (the player never respawns itself).

var _announced := false


func _init() -> void:
	overrides_gravity = false # keep falling naturally during death anim


func enter(_prev: StringName) -> void:
	_announced = false
	player.play(&"death")
	AudioManager.play_sfx("death")
	player.velocity.x = 0.0
	player.hurtbox.set_deferred("monitorable", false)
	player.melee_hitbox.deactivate()


func physics_update(_delta: float) -> void:
	player.velocity.x = 0.0
	if not _announced and not player.sprite.is_playing():
		_announced = true
		EventBus.player_died.emit()
