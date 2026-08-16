extends GutTest
## Stage 1 content contract (docs/GDD.md §5) + level mechanics.

const STAGE := preload("res://scenes/levels/stage_1.tscn")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.pending_zaf_intro = false
	get_tree().paused = false


func test_pending_zaf_intro_spawns_the_ghost_and_is_consumed() -> void:
	GameManager.start_stage(1, &"chris")
	GameManager.pending_zaf_intro = true
	var stage: LevelBase = STAGE.instantiate()
	add_child_autofree(stage)
	await wait_physics_frames(3)
	var ghosts := stage.get_children().filter(func(c: Node) -> bool: return c is ZafGhostIntro)
	assert_eq(ghosts.size(), 1, "a fresh new game must meet Zaf's in-game ghost intro")
	assert_false(GameManager.pending_zaf_intro,
			"the flag must be consumed so a later re-entry doesn't show it again")
	GameManager.end_stage()


func test_without_the_pending_flag_stage_1_never_spawns_the_ghost() -> void:
	GameManager.start_stage(1, &"chris")
	GameManager.pending_zaf_intro = false
	var stage: LevelBase = STAGE.instantiate()
	add_child_autofree(stage)
	await wait_physics_frames(3)
	var ghosts := stage.get_children().filter(func(c: Node) -> bool: return c is ZafGhostIntro)
	assert_eq(ghosts.size(), 0, "a retry/replay of stage 1 must not show Zaf again")
	GameManager.end_stage()


func test_stage_1_content_counts() -> void:
	GameManager.start_stage(1, &"chris")
	var stage: LevelBase = STAGE.instantiate()
	add_child_autofree(stage)
	await wait_frames(3)
	assert_eq(stage.total_coins, 100, "GDD: exactly 100 coins per stage")
	assert_eq(stage.total_nodes, 3, "3 security nodes")
	assert_eq(stage.hidden_room_rects.size(), 2, "2 hidden rooms")
	assert_not_null(stage.respawner.player, "player spawned")
	var checkpoints := 0
	var managers := 0
	var juniors := 0
	var gates := 0
	for child in stage.get_children():
		if child is Checkpoint:
			checkpoints += 1
		elif child is AngryManager:
			managers += 1
		elif child is JuniorBanker:
			juniors += 1
		elif child is ExitGate:
			gates += 1
	assert_eq(checkpoints, 3)
	assert_eq(managers, 2, "gauntlet pair")
	assert_eq(juniors, 3)
	assert_eq(gates, 1)
	GameManager.end_stage()


func test_level_bonus_formula() -> void:
	assert_eq(GameManager.compute_level_bonus(200.0, 300.0), 10000, "under par = max")
	assert_eq(GameManager.compute_level_bonus(300.0, 300.0), 10000, "at par = max")
	assert_eq(GameManager.compute_level_bonus(310.0, 300.0), 9000, "-100/s over")
	assert_eq(GameManager.compute_level_bonus(500.0, 300.0), 0, "floors at 0")


func test_security_node_hold_to_activate() -> void:
	# floor so the player stays standing inside the node's field
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var fshape := CollisionShape2D.new()
	var frect := RectangleShape2D.new()
	frect.size = Vector2(200, 20)
	fshape.shape = frect
	floor_body.position = Vector2(0, 10)
	floor_body.add_child(fshape)
	add_child_autofree(floor_body)
	var node := SecurityNode.new()
	node.position = Vector2(0, 0)
	add_child_autofree(node)
	var player := (preload("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	player.stats = preload("res://data/characters/chris.tres")
	player.position = Vector2(0, -2)
	add_child_autofree(player)
	watch_signals(node)
	await wait_physics_frames(3) # overlap registers
	Input.action_press("interact")
	await wait_physics_frames(10) # 10 ticks < 0.5s -> not yet
	assert_signal_not_emitted(node, "activated")
	await wait_physics_frames(25) # total > 0.5s
	Input.action_release("interact")
	assert_signal_emitted(node, "activated")
	assert_true(node.active)


func test_exit_gate_blocks_until_unlocked() -> void:
	var gate := ExitGate.new()
	add_child_autofree(gate)
	await wait_frames(2)
	var blockers := gate.get_children().filter(
		func(c: Node) -> bool: return c is StaticBody2D)
	assert_eq(blockers.size(), 1, "locked gate has a physical blocker")
	watch_signals(gate)
	gate.unlock()
	assert_true(gate.open)
	await wait_frames(2)
	blockers = gate.get_children().filter(
		func(c: Node) -> bool: return c is StaticBody2D and is_instance_valid(c) \
				and not c.is_queued_for_deletion())
	assert_eq(blockers.size(), 0, "blocker removed on unlock")
