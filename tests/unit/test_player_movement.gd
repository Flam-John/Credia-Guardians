extends GutTest
## Player physics integration: real scene tree, real physics ticks, simulated
## input actions. Covers landing, jump, buffer, double jump, dash.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")

var _player: Player


func before_each() -> void:
	# Wide floor at y=100 (top surface), player dropped just above it.
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	shape.position = Vector2.ZERO
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	_player = PLAYER_SCENE.instantiate()
	_player.stats = CHRIS
	_player.position = Vector2(0, 90)
	add_child_autofree(_player)


func after_each() -> void:
	for action in ["jump", "dash", "move_left", "move_right"]:
		Input.action_release(action)


func _state() -> StringName:
	return _player.state_machine.current_name()


func _settle() -> void:
	await wait_physics_frames(30)
	assert_true(_player.is_on_floor(), "player should have landed")


func test_spawns_falling_then_lands_idle() -> void:
	assert_eq(_state(), &"Fall")
	await _settle()
	assert_eq(_state(), &"Idle")


func test_jump_leaves_ground_with_negative_velocity() -> void:
	await _settle()
	Input.action_press("jump")
	await wait_physics_frames(3)
	assert_eq(_state(), &"Jump")
	assert_lt(_player.velocity.y, 0.0)


func test_jump_release_cuts_ascent() -> void:
	await _settle()
	Input.action_press("jump")
	await wait_physics_frames(3)
	var full_ascent := _player.velocity.y
	Input.action_release("jump")
	await wait_physics_frames(2)
	assert_gt(_player.velocity.y, full_ascent, "released jump should slow ascent")


func test_double_jump_consumes_air_charge() -> void:
	await _settle()
	Input.action_press("jump")
	await wait_physics_frames(3)
	Input.action_release("jump")
	await wait_physics_frames(2)
	assert_eq(_player.air_jumps_left, 1)
	Input.action_press("jump")
	await wait_physics_frames(3)
	assert_eq(_state(), &"DoubleJump")
	assert_eq(_player.air_jumps_left, 0)


func test_no_triple_jump() -> void:
	await _settle()
	for i in 2:
		Input.action_press("jump")
		await wait_physics_frames(3)
		Input.action_release("jump")
		await wait_physics_frames(2)
	# third press mid-air: no charges, no coyote -> stays in current air state
	Input.action_press("jump")
	await wait_physics_frames(3)
	assert_ne(_state(), &"Jump")
	assert_eq(_player.air_jumps_left, 0)


func test_run_reaches_stat_speed_and_faces_right() -> void:
	await _settle()
	Input.action_press("move_right")
	await wait_physics_frames(20)
	assert_eq(_state(), &"Run")
	assert_almost_eq(_player.velocity.x, CHRIS.run_speed, 1.0)
	assert_eq(_player.facing, 1)


func test_dash_uses_stat_speed_and_starts_cooldown() -> void:
	await _settle()
	Input.action_press("move_right")
	await wait_physics_frames(5)
	Input.action_press("dash")
	await wait_physics_frames(2)
	assert_eq(_state(), &"Dash")
	assert_almost_eq(_player.velocity.x, CHRIS.dash_speed, 1.0)
	# ride out the dash
	await wait_physics_frames(int(CHRIS.dash_duration * 60) + 3)
	assert_ne(_state(), &"Dash")
	assert_gt(_player.dash_cooldown_timer, 0.0)


func test_dash_respects_cooldown() -> void:
	await _settle()
	Input.action_press("dash")
	await wait_physics_frames(int(CHRIS.dash_duration * 60) + 3)
	Input.action_release("dash")
	await wait_physics_frames(1)
	Input.action_press("dash")
	await wait_physics_frames(2)
	assert_ne(_state(), &"Dash", "second dash inside cooldown must be rejected")


func test_flam_dash_has_iframes() -> void:
	_player.queue_free()
	_player = PLAYER_SCENE.instantiate()
	_player.stats = FLAM
	_player.position = Vector2(0, 90)
	add_child_autofree(_player)
	await _settle()
	Input.action_press("dash")
	await wait_physics_frames(2)
	assert_eq(_state(), &"Dash")
	assert_true(_player.invulnerable)
	await wait_physics_frames(int(FLAM.dash_duration * 60) + 3)
	assert_false(_player.invulnerable)


func test_jump_buffer_fires_on_landing() -> void:
	# A press just before landing with NO air options left must be buffered
	# and fire as a ground jump on touchdown. (With a double jump still
	# available, an air press double-jumps immediately instead — by design.)
	await _settle()
	for i in 2: # use up ground jump + double jump
		Input.action_press("jump")
		await wait_physics_frames(3)
		Input.action_release("jump")
		await wait_physics_frames(2)
	assert_eq(_player.air_jumps_left, 0)
	# wait until descending near the floor, then press within the buffer window
	while _player.velocity.y < 0.0 or _player.position.y < 85.0:
		await wait_physics_frames(1)
	Input.action_press("jump")
	await wait_physics_frames(12)
	assert_eq(_state(), &"Jump", "buffered press should fire on landing")
