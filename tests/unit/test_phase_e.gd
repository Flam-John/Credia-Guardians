extends GutTest
## Phase E refactors: marker parser units, the complete_stage pipeline
## (previously ZERO end-to-end coverage — review P5-32), LevelServices.

const TEST_SLOT := 3


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()
	SaveManager.active_slot = -1


func after_each() -> void:
	SaveManager.delete_slot(TEST_SLOT)
	SaveManager.active_slot = -1
	GameManager.end_stage()


# -- EntityMarkerParser (finally unit-testable) ----------------------------------

func test_parser_counts_and_terrain() -> void:
	var parser := EntityMarkerParser.new()
	parser.parse("""
@######@
@cPc..N@
@######@
""")
	assert_eq(parser.coin_count, 2)
	assert_eq(parser.node_count, 1)
	assert_eq(parser.spawn_tile, Vector2i(2, 1))
	assert_false(parser.terrain.contains("c"), "markers stripped from terrain")
	assert_false(parser.terrain.contains("N"))
	assert_true(parser.terrain.contains("#"), "terrain preserved")


func test_parser_horizontal_runs() -> void:
	var parser := EntityMarkerParser.new()
	parser.parse("@>>>>@\n@====@")
	var belts := parser.spawns.filter(func(s: Dictionary) -> bool: return s.type == ">")
	var movers := parser.spawns.filter(func(s: Dictionary) -> bool: return s.type == "=")
	assert_eq(belts.size(), 1, "one belt from a run of 4")
	assert_eq(belts[0].length, 4)
	assert_eq(movers.size(), 1)
	assert_eq(movers[0].length, 4)


func test_parser_vertical_columns_emit_once() -> void:
	var parser := EntityMarkerParser.new()
	parser.parse("@~@\n@~@\n@~@")
	var drafts := parser.spawns.filter(func(s: Dictionary) -> bool: return s.type == "~")
	assert_eq(drafts.size(), 1, "one updraft per COLUMN, not per cell")
	assert_eq(drafts[0].length, 3)
	assert_false(parser.terrain.contains("~"), "column cells blanked")


func test_parser_matches_stage_maps() -> void:
	for stage in range(1, 6):
		var parser := EntityMarkerParser.new()
		parser.parse(FileAccess.get_file_as_string(
				"res://data/levels/stage_%d_map.txt" % stage))
		assert_eq(parser.coin_count, 100, "stage %d coins" % stage)
		assert_eq(parser.node_count, 3, "stage %d nodes" % stage)


# -- GameManager.complete_stage: the full clear -> save -> unlock pipeline -------

func _clear_info() -> Dictionary:
	return {
		"stage_id": 1, "next_stage_id": 2, "par_time": 300.0,
		"total_coins": 100, "nodes": 3, "total_nodes": 3,
		"hidden_rooms": [true, false],
	}


func test_complete_stage_persists_and_unlocks() -> void:
	SaveManager.active_slot = TEST_SLOT
	SaveManager.write_slot(TEST_SLOT, SaveManager.new_slot_data(&"chris"))
	GameManager.start_stage(1, &"chris")
	GameManager.add_score(4000)
	GameManager.coins = 100
	GameManager.stage_time = 250.0
	watch_signals(EventBus)
	var stats := GameManager.complete_stage(_clear_info())
	# bonuses: level 10000 (under par) + full audit 5000
	assert_eq(int(stats.level_bonus), 10000)
	assert_eq(int(stats.full_audit), 5000)
	assert_eq(int(stats.score), 19000)
	assert_eq(stats.rank, "S")
	assert_signal_emitted(EventBus, "stage_cleared")
	assert_false(GameManager.is_stage_running())
	# persisted: bests recorded, stage 2 unlocked
	var save := SaveManager.load_slot(TEST_SLOT)
	assert_true(save.stages["1"].cleared)
	assert_eq(save.stages["1"].best_rank, "S")
	assert_eq(int(save.stages["1"].hi_score), 19000)
	assert_true(save.stages["2"].unlocked, "next stage unlocked")
	assert_eq(save.stages["1"].hidden_rooms_found, [true, false])
	assert_eq(int(save.global_hi_score), 19000)


func test_complete_stage_without_slot_still_ranks() -> void:
	SaveManager.active_slot = -1 # boss rush / debug boot: nothing to persist
	GameManager.start_stage(1, &"chris")
	GameManager.coins = 50
	GameManager.stage_time = 400.0
	var stats := GameManager.complete_stage(_clear_info())
	assert_eq(stats.rank, "C", "ranking works without persistence")
	assert_eq(GameManager.last_clear_stats, stats)


func test_hi_score_promotion_in_game_manager() -> void:
	GameManager.start_stage(1, &"chris")
	GameManager.hi_score = 500
	GameManager.add_score(700)
	assert_eq(GameManager.hi_score, 700, "promotion no longer depends on HUD")


# -- LevelServices ---------------------------------------------------------------

func test_level_services_shared_lookup_and_popups() -> void:
	var services := LevelServices.new()
	add_child_autofree(services)
	await wait_frames(2)
	assert_eq(LevelServices.find(get_tree()), services)
	# enemy_killed drives a pooled popup with no manual wiring
	var before := services.popup_pool.free_count()
	EventBus.enemy_killed.emit(200, Vector2(50, 50))
	assert_eq(services.popup_pool.free_count(), before - 1, "popup acquired")
	await wait_seconds(1.0) # tween returns it
	assert_eq(services.popup_pool.free_count(), before, "popup released back")
