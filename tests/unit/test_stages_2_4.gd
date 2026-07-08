extends GutTest
## Content contract for stages 2-4 (GDD §5) + M6 prop mechanics.

const STAGE_SCENES := {
	2: "res://scenes/levels/stage_2.tscn",
	3: "res://scenes/levels/stage_3.tscn",
	4: "res://scenes/levels/stage_4.tscn",
}


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func test_every_stage_has_full_content() -> void:
	for stage_id: int in STAGE_SCENES:
		GameManager.start_stage(stage_id, &"chris")
		var stage: LevelBase = (load(STAGE_SCENES[stage_id]) as PackedScene).instantiate()
		add_child(stage)
		await wait_frames(3)
		assert_eq(stage.total_coins, 100, "stage %d: 100 coins" % stage_id)
		assert_eq(stage.total_nodes, 3, "stage %d: 3 nodes" % stage_id)
		assert_gt(stage.hidden_room_rects.size(), 0, "stage %d: hidden rooms" % stage_id)
		assert_not_null(stage.respawner.player, "stage %d: player spawned" % stage_id)
		var gates := 0
		var checkpoints := 0
		for child in stage.get_children():
			if child is ExitGate:
				gates += 1
			elif child is Checkpoint:
				checkpoints += 1
		assert_eq(gates, 1, "stage %d: exit gate" % stage_id)
		assert_gte(checkpoints, 2, "stage %d: checkpoints" % stage_id)
		GameManager.end_stage()
		stage.free()
		await wait_frames(1)


func test_timed_hazard_cycles() -> void:
	var hazard := TimedHazard.new()
	hazard.on_time = 0.1
	hazard.off_time = 0.1
	add_child_autofree(hazard)
	hazard.setup(Vector2(16, 32))
	await wait_physics_frames(2)
	var shape := hazard.get_child(0) as CollisionShape2D
	assert_false(shape.disabled, "starts in the ON window")
	assert_true(await _flips_to(shape, true), "off window disables the shape")
	assert_true(await _flips_to(shape, false), "cycles back on")


## Poll for a state flip instead of counting exact boundary frames.
func _flips_to(shape: CollisionShape2D, disabled: bool) -> bool:
	for i in 30:
		await wait_physics_frames(1)
		if shape.disabled == disabled:
			return true
	return false


func test_fading_bridge_phases() -> void:
	var bridge := FadingBridge.new()
	bridge.solid_time = 0.1
	bridge.gone_time = 0.1
	add_child_autofree(bridge)
	bridge.setup(4)
	await wait_physics_frames(2)
	var shape := bridge.get_child(0) as CollisionShape2D
	assert_false(shape.disabled, "starts solid")
	await wait_physics_frames(8)
	assert_true(shape.disabled, "phases out")


func test_security_camera_spawns_and_dies() -> void:
	# floor keeps the player inside the camera's 150px range
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fshape := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(400, 20)
	fshape.shape = frect
	floor_body.position = Vector2(0, 30)
	floor_body.add_child(fshape)
	add_child_autofree(floor_body)
	var camera := SecurityCamera.new()
	camera.position = Vector2(0, 0)
	add_child_autofree(camera)
	var player: Player = (preload("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	player.stats = preload("res://data/characters/chris.tres")
	player.position = Vector2(40, 10)
	add_child_autofree(player)
	await wait_physics_frames(95) # first spawn at 1.5s = 90 ticks
	var juniors := get_children().filter(
		func(c: Node) -> bool: return c is JuniorBanker)
	assert_gt(juniors.size(), 0, "camera spawns a junior in range")
	watch_signals(EventBus)
	camera.health.damage(2)
	assert_signal_emitted(EventBus, "enemy_killed")
