extends GutTest
## Fix: NEW GAME on an already-occupied slot used to silently resume (solo)
## or re-pick-without-reset (co-op) instead of actually starting fresh, with
## zero confirmation. Now mirrors the existing slot-delete two-press confirm,
## and nothing is actually overwritten until a character is picked afterward
## (SlotSelectFlow.force_new) — so backing out anywhere along the way loses
## nothing. SceneManager._busy=true neuters the real scene transition inside
## _on_slot()/_on_pick() so tests can call them directly without swapping the
## GUT runner's own scene tree (same technique as test_review_fixes.gd).

const SLOT_SELECT := preload("res://scenes/ui/slot_select.tscn")
const CHARACTER_SELECT := preload("res://scenes/ui/character_select.tscn")
const SLOT := 3


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func before_each() -> void:
	SceneManager._busy = true


func after_each() -> void:
	SceneManager._busy = false
	SaveManager.delete_slot(SLOT)
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	SlotSelectFlow.force_new = false


func _write_progressed_slot() -> void:
	var data := SaveManager.new_slot_data(&"chris")
	data = SaveManager.record_stage_clear(data, {
		"stage_id": 1, "rank": "S", "score": 500, "time": 30.0, "coins": 10,
		"hidden_rooms": [], "character": "chris", "next_stage_id": 2,
	})
	SaveManager.write_slot(SLOT, data)


## Review catch: _focus_slot() used to always prefer the DELETE button
## regardless of which confirm was actually armed, so confirming "new
## game" silently moved keyboard/gamepad focus onto DELETE — a player
## trusting the on-screen "press again" instruction would end up pressing
## DELETE instead, permanently erasing the save. Focus must follow
## whichever control was actually pressed.
func test_new_game_confirm_keeps_focus_on_the_main_button_not_delete() -> void:
	_write_progressed_slot()
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_slot(SaveManager.get_slot_summaries()[SLOT - 1]) # arm new-game confirm
	await wait_frames(2) # _focus_slot is call_deferred
	var focused := screen.get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "something must hold focus")
	assert_eq(int(focused.get_meta(&"slot", -1)), SLOT,
			"focus stays on the SLOT button (not DELETE) after arming new-game confirm")
	assert_eq(int(focused.get_meta(&"slot_delete", -1)), -1,
			"the focused control must not be the DELETE button")


func test_delete_confirm_still_keeps_focus_on_delete_button() -> void:
	_write_progressed_slot()
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._delete_slot(SLOT) # arm delete confirm
	await wait_frames(2)
	var focused := screen.get_viewport().gui_get_focus_owner()
	assert_eq(int(focused.get_meta(&"slot_delete", -1)), SLOT,
			"delete-confirm still keeps focus on the DELETE button (regression guard)")


func test_first_press_on_occupied_slot_only_arms_confirm() -> void:
	_write_progressed_slot()
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_slot(SaveManager.get_slot_summaries()[SLOT - 1])
	assert_false(SlotSelectFlow.force_new, "first press doesn't touch anything yet")
	assert_eq(SaveManager.get_slot_summaries()[SLOT - 1].stages_cleared, 1,
			"save is completely untouched after just one press")


func test_second_press_arms_force_new_without_writing_anything() -> void:
	_write_progressed_slot()
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	var summary: Dictionary = SaveManager.get_slot_summaries()[SLOT - 1]
	screen._on_slot(summary) # arm
	screen._on_slot(summary) # confirm
	assert_true(SlotSelectFlow.force_new, "second press arms the fresh-start flag")
	# the slot itself is STILL untouched -- only character_select's
	# write_slot (once a character is actually picked) does the real erase
	assert_eq(SaveManager.get_slot_summaries()[SLOT - 1].stages_cleared, 1,
			"nothing is erased yet -- backing out here would lose nothing")


func test_picking_a_character_after_confirm_actually_resets_the_slot() -> void:
	_write_progressed_slot()
	SaveManager.active_slot = SLOT
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	SlotSelectFlow.force_new = true # as if slot_select just confirmed it
	var screen: Control = CHARACTER_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_pick(&"flam")
	var data := SaveManager.load_slot(SLOT)
	assert_eq(data.stages.keys(), ["1"], "progress reset -- only stage 1 exists again")
	assert_false(data.stages["1"].cleared, "stage 1 is unlocked but not cleared")
	assert_eq(data.last_character, "flam")
	assert_false(SlotSelectFlow.force_new, "consumed immediately")


func test_coop_new_game_on_occupied_slot_also_resets_after_confirm() -> void:
	_write_progressed_slot()
	SaveManager.active_slot = SLOT
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = true
	SlotSelectFlow.force_new = true
	var screen: Control = CHARACTER_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_pick(&"chris") # P1
	screen._on_pick(&"flam") # P2
	var data := SaveManager.load_slot(SLOT)
	assert_eq(data.stages.keys(), ["1"], "co-op new-game-on-occupied-slot also resets progress")
	assert_true(data.coop)
	assert_eq(data.character2, "flam")


func test_continue_mode_unaffected_still_resumes_without_confirm() -> void:
	_write_progressed_slot()
	SlotSelectFlow.mode = SlotSelectFlow.Mode.CONTINUE
	SlotSelectFlow.coop = false
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._on_slot(SaveManager.get_slot_summaries()[SLOT - 1]) # single press
	assert_false(SlotSelectFlow.force_new, "CONTINUE never touches force_new")
	assert_eq(SaveManager.get_slot_summaries()[SLOT - 1].stages_cleared, 1,
			"CONTINUE never erases anything")


func test_main_menu_entry_points_reset_force_new() -> void:
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	SlotSelectFlow.force_new = true
	menu._on_new_game()
	assert_false(SlotSelectFlow.force_new)
	SlotSelectFlow.force_new = true
	menu._on_coop()
	assert_false(SlotSelectFlow.force_new)
	SlotSelectFlow.force_new = true
	menu._on_boss_rush()
	assert_false(SlotSelectFlow.force_new)
	SlotSelectFlow.force_new = true
	menu._on_continue()
	assert_false(SlotSelectFlow.force_new)


func test_character_select_back_resets_force_new_defensively() -> void:
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.force_new = true
	var screen: Control = CHARACTER_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._back()
	assert_false(SlotSelectFlow.force_new)
