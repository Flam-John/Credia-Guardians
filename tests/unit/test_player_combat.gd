extends GutTest
## Player combat integration: attack states, shield block arc, hurt/death flow.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")

var _player: Player


func before_each() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	_player = PLAYER_SCENE.instantiate()
	_player.stats = CHRIS
	_player.position = Vector2(0, 90)
	add_child_autofree(_player)
	await wait_physics_frames(30) # settle onto floor


func after_each() -> void:
	for action in ["jump", "dash", "attack", "ability", "move_left", "move_right"]:
		Input.action_release(action)


func _state() -> StringName:
	return _player.state_machine.current_name()


func test_attack_enters_combo_and_returns_to_idle() -> void:
	Input.action_press("attack")
	await wait_physics_frames(2)
	Input.action_release("attack")
	assert_eq(_state(), &"Attack")
	await wait_physics_frames(30) # ride out swing (4 frames @16fps ≈ 15 ticks)
	assert_eq(_state(), &"Idle")


func test_combo_chains_on_buffered_press() -> void:
	Input.action_press("attack")
	await wait_physics_frames(2)
	Input.action_release("attack")
	var attack_state: Node = _player.state_machine.states[&"Attack"]
	assert_eq(attack_state.combo_index, 1)
	await wait_physics_frames(6)
	Input.action_press("attack") # inside swing 1 -> queue swing 2
	await wait_physics_frames(2)
	Input.action_release("attack")
	await wait_physics_frames(14)
	assert_eq(_state(), &"Attack")
	assert_eq(attack_state.combo_index, 2)


func test_take_hit_enters_hurt_with_iframes() -> void:
	_player.take_hit(1, _player.global_position + Vector2(20, 0))
	assert_eq(_state(), &"Hurt")
	assert_eq(_player.health.hp, CHRIS.max_hp - 1)
	assert_true(_player.is_invulnerable())
	# knocked away from the hit source (source was to the right)
	assert_lt(_player.velocity.x, 0.0)


func test_lethal_hit_enters_dead_and_announces() -> void:
	watch_signals(EventBus)
	_player.health.damage(CHRIS.max_hp - 1)
	_player.take_hit(1, _player.global_position + Vector2(20, 0))
	assert_eq(_state(), &"Dead")
	await wait_physics_frames(60) # death anim (6 frames @ 8fps = 45 ticks)
	assert_signal_emit_count(EventBus, "player_died", 1)


## Shield blocks from ANY direction now (user request: bullets/hits from
## behind or above shouldn't slip past just because they're not frontal).
func test_shield_blocks_any_direction() -> void:
	Input.action_press("ability")
	await wait_physics_frames(3)
	assert_eq(_state(), &"Shield")
	var hp_before := _player.health.hp
	# frontal hit (facing right by default) — blocked, unlimited (no meter)
	_player.take_hit(1, _player.global_position + Vector2(30, 0))
	assert_eq(_player.health.hp, hp_before, "frontal hit blocked")
	assert_eq(_state(), &"Shield", "still holding — blocking never runs out")
	# hit from behind — ALSO blocked now, not just frontal
	_player.take_hit(1, _player.global_position + Vector2(-30, 0))
	assert_eq(_player.health.hp, hp_before, "rear hit blocked too")
	# hit from directly above (e.g. a lobbed projectile) — also blocked
	_player.take_hit(1, _player.global_position + Vector2(0, -30))
	assert_eq(_player.health.hp, hp_before, "hit from above blocked too")


func test_hazard_polling_damages_while_overlapping() -> void:
	# real hazard body under the player: polled check must hit on the first
	# frame AND again after i-frames expire while still overlapping
	var spikes := StaticBody2D.new()
	spikes.collision_layer = PhysicsLayers.HAZARD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 30)
	shape.shape = rect
	spikes.position = _player.position + Vector2(0, -10)
	spikes.add_child(shape)
	add_child_autofree(spikes)
	var hp_start := _player.health.hp
	await wait_physics_frames(4)
	assert_eq(_player.health.hp, hp_start - 2, "hazard costs 2")
	# still overlapping after the 1s invulnerability -> damaged again
	await wait_physics_frames(70)
	assert_lte(_player.health.hp, hp_start - 4, "re-damaged after i-frames while inside")
