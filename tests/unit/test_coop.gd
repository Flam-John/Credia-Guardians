extends GutTest
## Co-op: per-player input isolation, partner respawn, dual spawn, boss rush.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")
	CoopInput.ensure_actions()


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.character2 = &""
	for action in ["jump", "p1_jump", "p2_jump", "move_left", "move_right"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _make_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func _spawn_pair() -> Array[Player]:
	_make_floor()
	var out: Array[Player] = []
	for i in 2:
		var p: Player = PLAYER_SCENE.instantiate()
		p.stats = CHRIS if i == 0 else FLAM
		p.player_index = i + 1
		p.position = Vector2(i * 60, 90)
		add_child_autofree(p)
		out.append(p)
	return out


func test_coop_actions_exist_and_are_scoped() -> void:
	assert_true(InputMap.has_action(&"p1_jump"))
	assert_true(InputMap.has_action(&"p2_jump"))
	# P2 keyboard fallback exists, P1 keeps base keyboard keys
	var p2_keys := InputMap.action_get_events(&"p2_jump").filter(
		func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_gt(p2_keys.size(), 0, "P2 has a keyboard fallback")
	# joypad events are device-scoped
	for event in InputMap.action_get_events(&"p1_jump"):
		if event is InputEventJoypadButton:
			assert_eq(event.device, 0, "P1 pad events pinned to device 0")
	for event in InputMap.action_get_events(&"p2_jump"):
		if event is InputEventJoypadButton:
			assert_eq(event.device, 1, "P2 pad events pinned to device 1")


func test_p1_and_p2_keyboard_keys_are_disjoint() -> void:
	# regression (v1.8.3): base actions bind BOTH WASD and the arrows, and
	# the arrows leaked into p1_* — both keyboards drove the same character
	CoopInput.refresh_if_built()
	CoopInput.ensure_actions()
	for base in CoopInput.GAMEPLAY_ACTIONS:
		var p1_keys := {}
		for event in InputMap.action_get_events(StringName("p1_%s" % base)):
			if event is InputEventKey:
				p1_keys[(event as InputEventKey).physical_keycode] = true
		for event in InputMap.action_get_events(StringName("p2_%s" % base)):
			if event is InputEventKey:
				var code := (event as InputEventKey).physical_keycode
				assert_false(p1_keys.has(code),
						"%s: key %s bound to BOTH players" % [base, code])
	# P1 keeps its own keys (A) but not P2's arrow
	var p1_left := InputMap.action_get_events(&"p1_move_left")
	var codes: Array = p1_left.filter(func(e: InputEvent) -> bool: return e is InputEventKey) \
			.map(func(e: InputEvent) -> int: return (e as InputEventKey).physical_keycode)
	assert_has(codes, KEY_A, "P1 keeps WASD")
	assert_does_not_have(codes, KEY_LEFT, "arrows stay exclusive to P2")


func test_p2_input_moves_only_p2() -> void:
	var pair := _spawn_pair()
	await wait_physics_frames(30) # both land
	Input.action_press(&"p2_jump")
	await wait_physics_frames(3)
	Input.action_release(&"p2_jump")
	assert_eq(pair[0].state_machine.current_name(), &"Idle", "P1 unaffected")
	assert_eq(pair[1].state_machine.current_name(), &"Jump", "P2 jumped")


func test_coop_spawn_two_players_with_shared_camera() -> void:
	_make_floor()
	GameManager.character2 = &"flam"
	GameManager.start_stage(1, &"chris")
	var respawner := RespawnController.new()
	respawner.spawn_point = Vector2(0, 90)
	respawner.camera_limits = Rect2(0, 0, 2000, 400)
	add_child_autofree(respawner)
	respawner.spawn(CHRIS)
	await wait_physics_frames(5)
	assert_eq(respawner.players.size(), 2)
	assert_eq(respawner.players[0].player_index, 1)
	assert_eq(respawner.players[1].player_index, 2)
	var coop_cams := get_children().filter(func(c: Node) -> bool: return c is CoopCamera)
	assert_eq(coop_cams.size(), 1, "one shared camera")
	GameManager.end_stage()


func test_coop_partner_respawn() -> void:
	_make_floor()
	GameManager.character2 = &"flam"
	GameManager.start_stage(1, &"chris")
	var respawner := RespawnController.new()
	respawner.spawn_point = Vector2(0, 90)
	respawner.camera_limits = Rect2(0, 0, 2000, 400)
	add_child_autofree(respawner)
	respawner.spawn(CHRIS)
	await wait_physics_frames(10)
	var p2 := respawner.players[1]
	p2.take_hit(999, p2.global_position) # kill P2
	# death anim (~45 ticks) + respawn delay 1.2s (72 ticks) + margin
	await wait_physics_frames(140)
	assert_eq(respawner.players.size(), 2)
	assert_true(is_instance_valid(respawner.players[1]), "P2 came back")
	assert_false(respawner.players[1].health.is_dead())
	assert_lt(respawner.players[1].global_position.distance_to(
			respawner.players[0].global_position), 60.0,
			"revived beside the partner")
	GameManager.end_stage()


func test_boss_rush_advances_waves() -> void:
	GameManager.character = &"chris"
	GameManager.character2 = &""
	var rush: Node2D = (load("res://scenes/ui/boss_rush.tscn") as PackedScene).instantiate()
	add_child(rush)
	await wait_frames(3)
	assert_eq(rush._wave, 1, "first boss out")
	assert_not_null(rush._boss)
	var first: Node = rush._boss
	first.queue_free() # simulate kill
	await wait_physics_frames(100) # 1.5s heal beat
	assert_eq(rush._wave, 2, "second boss spawned")
	GameManager.end_stage()
	rush.free()
	await wait_frames(1)
