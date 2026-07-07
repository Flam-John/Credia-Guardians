extends GutTest
## SaveManager: round-trip, merge rules, corruption quarantine, versioning.
## Uses slot 3 as scratch space and restores a clean state after each test.

const SLOT := 3


func before_all() -> void:
	# Sandbox: NEVER write the player's real saves/settings from tests.
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	SaveManager.delete_slot(SLOT)
	var bak := SaveManager.slot_path(SLOT) + ".bak"
	if FileAccess.file_exists(bak):
		DirAccess.open(SaveManager.save_dir).remove(bak.get_file())


func test_round_trip() -> void:
	var data := SaveManager.new_slot_data(&"flam")
	assert_eq(SaveManager.write_slot(SLOT, data), OK)
	var loaded := SaveManager.load_slot(SLOT)
	assert_eq(loaded.last_character, "flam")
	assert_eq(int(loaded.version), SaveManager.CURRENT_VERSION)
	assert_true(loaded.stages["1"].unlocked)
	assert_false(loaded.stages["1"].cleared)


func test_missing_slot_is_empty() -> void:
	assert_eq(SaveManager.load_slot(SLOT), {})


func test_corrupt_slot_quarantined_not_deleted() -> void:
	var file := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	file.store_string("{not valid json!!")
	file.close()
	assert_eq(SaveManager.load_slot(SLOT), {})
	assert_false(FileAccess.file_exists(SaveManager.slot_path(SLOT)))
	assert_true(FileAccess.file_exists(SaveManager.slot_path(SLOT) + ".bak"))


func test_future_version_refused() -> void:
	var data := SaveManager.new_slot_data(&"chris")
	SaveManager.write_slot(SLOT, data)
	# hand-edit version above CURRENT
	var raw := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.READ).get_as_text()
	var dict: Dictionary = JSON.parse_string(raw)
	dict.version = 999
	var file := FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(dict))
	file.close()
	assert_eq(SaveManager.load_slot(SLOT), {})
	# refused but NOT quarantined/deleted
	assert_true(FileAccess.file_exists(SaveManager.slot_path(SLOT)))
	# slot must be reported incompatible (not empty) and shielded from writes
	assert_true(SaveManager.is_slot_incompatible(SLOT))
	assert_eq(SaveManager.write_slot(SLOT, SaveManager.new_slot_data(&"chris")),
			ERR_UNAVAILABLE)
	var summary: Dictionary = SaveManager.get_slot_summaries()[SLOT - 1]
	assert_true(summary.get("incompatible", false))
	assert_false(summary.get("empty", true))


func test_record_stage_clear_unlocks_next_and_max_merges() -> void:
	var data := SaveManager.new_slot_data(&"chris")
	data = SaveManager.record_stage_clear(data, {
		"stage_id": 1, "rank": "B", "score": 10000, "time": 400.0,
		"coins": 70, "hidden_rooms": [true, false],
		"character": &"chris", "next_stage_id": 2,
	})
	# a worse later run must not downgrade bests
	data = SaveManager.record_stage_clear(data, {
		"stage_id": 1, "rank": "C", "score": 5000, "time": 500.0,
		"coins": 50, "hidden_rooms": [false, true],
		"character": &"flam", "next_stage_id": 2,
	})
	var s1: Dictionary = data.stages["1"]
	assert_eq(s1.best_rank, "B")
	assert_eq(int(s1.hi_score), 10000)
	assert_eq(float(s1.best_time_sec), 400.0)
	assert_eq(int(s1.max_coins_collected), 70)
	assert_eq(s1.hidden_rooms_found, [true, true])
	assert_true(s1.cleared_with.has("chris"))
	assert_true(s1.cleared_with.has("flam"))
	assert_true(data.stages["2"].unlocked)
	assert_eq(int(data.global_hi_score), 10000)


func test_better_run_upgrades_bests() -> void:
	var data := SaveManager.new_slot_data(&"chris")
	var base := {
		"stage_id": 1, "rank": "C", "score": 5000, "time": 500.0,
		"coins": 50, "hidden_rooms": [], "character": &"chris", "next_stage_id": 0,
	}
	data = SaveManager.record_stage_clear(data, base)
	var better := base.duplicate()
	better.rank = "S"
	better.score = 60000
	better.time = 250.0
	better.coins = 100
	data = SaveManager.record_stage_clear(data, better)
	var s1: Dictionary = data.stages["1"]
	assert_eq(s1.best_rank, "S")
	assert_eq(int(s1.hi_score), 60000)
	assert_eq(float(s1.best_time_sec), 250.0)
	assert_eq(int(s1.max_coins_collected), 100)


func test_settings_round_trip() -> void:
	SaveManager.save_settings({"audio": {"master": 0.5}, "video": {"fullscreen": true}})
	var loaded := SaveManager.load_settings()
	assert_eq(float(loaded.audio.master), 0.5)
	assert_true(loaded.video.fullscreen)
