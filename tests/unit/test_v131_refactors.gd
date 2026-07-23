extends GutTest
## v1.3.1: PushZone/GateProp consolidation behavior parity, the force-field
## API, game-over routing, rebind persistence roundtrip.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()
	InputMap.load_from_project_settings()


func after_each() -> void:
	GameManager.end_stage()
	GameManager.character2 = &""


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


func _spawn_player(pos: Vector2) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = CHRIS
	p.position = pos
	add_child_autofree(p)
	return p


# -- PushZone parity (conveyor grounded-only, fan airborne, updraft lifts) -------

func test_conveyor_pushes_grounded_player() -> void:
	_make_floor()
	var belt := ConveyorBelt.new()
	belt.position = Vector2(-40, 100)
	add_child_autofree(belt)
	belt.setup(6, 1) # rightward
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(30) # land, then ride
	var x0 := player.global_position.x
	await wait_physics_frames(30)
	assert_gt(player.global_position.x, x0 + 10.0, "belt carries the player")


func test_updraft_lift_via_field_force_api() -> void:
	_make_floor()
	var draft := Updraft.new()
	draft.position = Vector2(-8, -60)
	add_child_autofree(draft)
	draft.setup(10)
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(30)
	var y0 := player.global_position.y
	await wait_physics_frames(30)
	assert_lt(player.global_position.y, y0 - 30.0, "steam still lifts after refactor")


func test_field_force_api_contract() -> void:
	_make_floor()
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(5)
	player.apply_field_force(50.0, 0.0)
	assert_eq(player._field_push_x, 50.0)
	player.apply_field_force(0.0, 200.0)
	player.apply_field_force(0.0, 100.0) # weaker lift must not shrink stronger
	assert_eq(player._field_lift, 200.0)
	await wait_physics_frames(1)
	assert_eq(player._field_push_x, 0.0, "consumed after the slide")
	assert_eq(player._field_lift, 0.0)


# -- GateProp parity ---------------------------------------------------------------

func test_exit_gate_still_blocks_then_opens() -> void:
	var gate := ExitGate.new()
	add_child_autofree(gate)
	await wait_frames(2)
	var blockers := gate.get_children().filter(
		func(c: Node) -> bool: return c is StaticBody2D)
	assert_eq(blockers.size(), 1, "locked gate keeps its blocker")
	watch_signals(gate)
	gate.unlock()
	assert_true(gate.open)


func test_firewall_gate_keeps_audit_geometry() -> void:
	# playability-audit contracts must survive the base-class extraction
	var gate := FirewallGate.new()
	add_child_autofree(gate)
	await wait_frames(2)
	assert_eq(gate.trigger_size, Vector2(40, 60), "trigger wider than blocker")
	assert_eq(gate.blocker_size, Vector2(16, 96), "blocker taller than max jump")
	GameManager.usb_keys = 1
	gate._players_inside = 1
	gate._try_open()
	assert_true(gate.open, "key consumption path intact")
	assert_eq(GameManager.usb_keys, 0)


# -- Game-over routing (review P5-33) -----------------------------------------------

func test_all_dead_at_zero_lives_routes_to_game_over() -> void:
	_make_floor()
	GameManager.start_stage(1, &"chris")
	GameManager.lives = {0: 1} # solo always tracks player_index 0
	var respawner := RespawnController.new()
	respawner.spawn_point = Vector2(0, 90)
	respawner.camera_limits = Rect2(0, 0, 2000, 400)
	var routed: Array[String] = []
	respawner.scene_router = func(path: String) -> void: routed.append(path)
	add_child_autofree(respawner)
	respawner.spawn(CHRIS)
	await wait_physics_frames(10)
	respawner.player.kill() # last life
	# death anim + respawn delay
	await wait_physics_frames(160)
	assert_eq(routed, ["res://scenes/ui/game_over.tscn"], "routed to game over")
	assert_false(GameManager.is_stage_running())


func test_death_with_lives_left_respawns_instead() -> void:
	_make_floor()
	GameManager.start_stage(1, &"chris")
	var respawner := RespawnController.new()
	respawner.spawn_point = Vector2(0, 90)
	respawner.camera_limits = Rect2(0, 0, 2000, 400)
	var routed: Array[String] = []
	respawner.scene_router = func(path: String) -> void: routed.append(path)
	add_child_autofree(respawner)
	respawner.spawn(CHRIS)
	await wait_physics_frames(10)
	respawner.player.kill()
	await wait_physics_frames(160)
	assert_eq(routed, [], "no game over while lives remain")
	assert_false(respawner.player.health.is_dead(), "respawned fresh")


# -- Rebind persistence roundtrip (review P5-33) --------------------------------------

func test_rebind_survives_settings_reload() -> void:
	var settings := SettingsApplier.merged_with_defaults({})
	settings.input["jump"] = KEY_Q
	SettingsApplier.apply(settings, get_window())
	SaveManager.save_settings(settings)
	# simulate a fresh boot: defaults restored, then saved settings applied
	InputMap.load_from_project_settings()
	var reloaded := SettingsApplier.merged_with_defaults(SaveManager.load_settings())
	SettingsApplier.apply(reloaded, get_window())
	var keys := InputMap.action_get_events(&"jump").filter(
		func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_eq(keys.size(), 1)
	assert_eq((keys[0] as InputEventKey).physical_keycode, KEY_Q,
			"rebind persists across boots")
