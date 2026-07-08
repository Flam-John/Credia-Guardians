extends GutTest
## M7: CEO phase machine, punish windows, boss-gated exit, stage 5 content.

const CEO := preload("res://scenes/entities/bosses/ceo_boss.tscn")
const STAGE_5 := preload("res://scenes/levels/stage_5.tscn")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func _make_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func _spawn_ceo() -> CeoBoss:
	_make_floor()
	var boss: CeoBoss = CEO.instantiate()
	boss.sleep_when_offscreen = false
	boss.position = Vector2(0, 90)
	add_child_autofree(boss)
	return boss


func test_ceo_invulnerable_outside_windows() -> void:
	var boss := _spawn_ceo()
	await wait_physics_frames(5)
	boss.take_hit(5, boss.global_position)
	assert_eq(boss.health.hp, 30, "no damage outside punish windows")


func test_ceo_three_phases_then_death() -> void:
	var boss := _spawn_ceo()
	await wait_physics_frames(5)
	watch_signals(EventBus)
	boss.vulnerable = true
	boss.take_hit(30, boss.global_position) # phase 1 pool
	assert_eq(boss.phase, 2)
	assert_eq(boss.health.hp, 25, "phase 2 pool refilled")
	assert_signal_emitted_with_parameters(EventBus, "boss_phase_changed", [2])
	boss.vulnerable = true
	boss.take_hit(25, boss.global_position)
	assert_eq(boss.phase, 3)
	assert_eq(boss.health.hp, 20)
	assert_false(boss.affected_by_gravity, "demon form floats")
	boss.vulnerable = true
	boss.take_hit(20, boss.global_position)
	assert_signal_emitted(EventBus, "boss_died")
	assert_signal_emitted(EventBus, "enemy_killed")


func test_ceo_stagger_window_after_slam() -> void:
	var boss := _spawn_ceo()
	# player target so patterns aim somewhere
	var player: Player = (preload("res://scenes/entities/player/player.tscn") as PackedScene).instantiate()
	player.stats = preload("res://data/characters/chris.tres")
	player.position = Vector2(80, 90)
	add_child_autofree(player)
	await wait_physics_frames(5)
	boss.state_machine.transition(&"Slam")
	var deadline := 300
	while boss.state_machine.current_name() != &"Stagger" and deadline > 0:
		deadline -= 1
		await wait_physics_frames(1)
	assert_eq(boss.state_machine.current_name(), &"Stagger", "slam lands into stagger")
	assert_true(boss.vulnerable, "stagger is the damage window")


func test_stage_5_content_and_boss_gate() -> void:
	GameManager.start_stage(5, &"chris")
	var stage: LevelBase = STAGE_5.instantiate()
	add_child(stage)
	await wait_frames(3)
	assert_eq(stage.total_coins, 100)
	assert_eq(stage.total_nodes, 3)
	assert_true(stage._boss_alive, "CEO spawned and gates the exit")
	var gate: ExitGate = null
	for child in stage.get_children():
		if child is ExitGate:
			gate = child
	assert_not_null(gate)
	# all nodes done but boss alive -> LOCKED
	stage.nodes_active = stage.total_nodes
	stage._check_gate()
	assert_false(gate.open, "gate stays locked while the CEO lives")
	stage._on_boss_died()
	assert_true(gate.open, "boss down + nodes done -> open")
	GameManager.end_stage()
	stage.free()
	await wait_frames(1)


func test_victory_screen_instantiates() -> void:
	GameManager.last_clear_stats = {"next_stage_id": 0, "rank": "S"}
	var screen: Control = (load("res://scenes/ui/victory.tscn") as PackedScene).instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_not_null(screen)
