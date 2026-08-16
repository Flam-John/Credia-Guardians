extends GutTest
## Zaf's in-game ghost intro: materialize -> talk (NEXT/SKIP) -> dissolve,
## pausing/unpausing the real (test) tree around it instead of launching a
## separate stage scene. Ticks are driven directly (not via the real Timer)
## so the test doesn't depend on wall-clock idle time.

func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.character2 = &""
	get_tree().paused = false


func _spawn() -> ZafGhostIntro:
	var zaf := ZafGhostIntro.new()
	add_child_autofree(zaf)
	return zaf


func test_pauses_the_tree_immediately_and_materializes_before_showing_the_panel() -> void:
	var zaf := _spawn()
	assert_true(get_tree().paused, "the real stage must freeze the instant Zaf appears")
	assert_eq(zaf._phase, zaf.Phase.ENTER)
	assert_false(zaf._panel.visible, "Zaf appears before the dialog shows")
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	assert_eq(zaf._phase, zaf.Phase.TALK)
	assert_true(zaf._panel.visible)


func test_next_advances_pages_then_skip_departs_and_unpauses() -> void:
	var zaf := _spawn()
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	var page_count: int = zaf._pages.size()
	assert_gt(page_count, 1, "there is more than one tutorial page")
	for i in page_count - 1:
		zaf._on_next()
	assert_eq(zaf._index, page_count - 1, "advanced through every page")
	zaf._on_next() # past the last page: departs on its own
	assert_eq(zaf._phase, zaf.Phase.LEAVE)
	for i in zaf.MATERIALIZE_FRAMES + 1:
		zaf._tick()
	assert_false(get_tree().paused, "control must hand back once Zaf is done")


func test_skip_departs_immediately_and_unpauses() -> void:
	var zaf := _spawn()
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	zaf._depart()
	assert_eq(zaf._phase, zaf.Phase.LEAVE)
	for i in zaf.MATERIALIZE_FRAMES + 1:
		zaf._tick()
	assert_false(get_tree().paused)


func test_finish_is_idempotent() -> void:
	var zaf := _spawn()
	watch_signals(zaf)
	zaf._phase = zaf.Phase.LEAVE
	zaf._anim = 0
	zaf._tick() # anim -> -1, calls _finish()
	zaf._finish() # a stray second call must not double-emit/double-unpause
	assert_signal_emit_count(zaf, "finished", 1, "_finish is idempotent")


func test_controls_page_lists_current_keys() -> void:
	var zaf := _spawn()
	var page: String = zaf._controls_page()
	assert_string_contains(page, SettingsApplier.key_label(&"jump"))
	assert_string_contains(page, SettingsApplier.key_label(&"attack"))


func test_controls_page_adds_p2_keys_in_coop() -> void:
	GameManager.character2 = &"flam"
	var zaf := _spawn()
	var page: String = zaf._controls_page()
	assert_string_contains(page, SettingsApplier.p2_key_label(&"jump"))
