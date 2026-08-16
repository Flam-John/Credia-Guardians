extends GutTest
## Smoke tests: every shell screen instantiates headless without errors and
## offers keyboard focus (gamepad/keyboard navigability baseline).

func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


const SCREENS := [
	"res://scenes/ui/splash.tscn",
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/slot_select.tscn",
	"res://scenes/ui/character_select.tscn",
	"res://scenes/ui/options_menu.tscn",
	"res://scenes/ui/game_over.tscn",
]


func test_all_screens_instantiate() -> void:
	for path in SCREENS:
		var screen: Control = load(path).instantiate()
		add_child_autofree(screen)
		await wait_frames(2)
		assert_not_null(screen, path)
		screen.queue_free()
		await wait_frames(1)


func test_main_menu_has_focused_button() -> void:
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var focused := get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "a menu button must own focus for gamepad nav")
	assert_true(focused is Button)


func test_stage_select_requires_slot() -> void:
	# guard: stage select reads the active slot; with a fresh temp slot it
	# must list stage 1 unlocked
	SaveManager.active_slot = 3
	SaveManager.write_slot(3, SaveManager.new_slot_data(&"chris"))
	var screen: Control = load("res://scenes/ui/stage_select.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	var buttons: Array[Node] = []
	_collect_buttons(screen, buttons)
	var enabled := buttons.filter(func(b: Node) -> bool: return not (b as Button).disabled)
	assert_gt(enabled.size(), 0, "stage 1 + back must be selectable")
	SaveManager.delete_slot(3)


func _collect_buttons(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)


func _make_pad_press(device: int, button_index: int) -> InputEventJoypadButton:
	var pad := InputEventJoypadButton.new()
	pad.device = device
	pad.button_index = button_index
	pad.pressed = true
	return pad


## Bug fix (review catch): P1 fiddling with their own controller (device 0)
## while P2 is mid-rebind used to get captured into P2's slot — one
## player's pad could hijack the other's listen. P2's row must ignore any
## press that isn't from device 1.
func test_options_p2_rebind_ignores_a_different_device() -> void:
	var menu: Control = load("res://scenes/ui/options_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu._start_listen_p2(&"jump")
	menu._unhandled_input(_make_pad_press(0, JOY_BUTTON_X)) # P1's pad — wrong device
	assert_eq(menu._listening_action, &"jump", "still listening — P1's press is ignored")
	menu._unhandled_input(_make_pad_press(1, JOY_BUTTON_X)) # P2's own pad
	assert_eq(menu._listening_action, &"", "P2's own device press is accepted")
	assert_eq(int(CoopInput.p2_gamepad_overrides.get("jump")), JOY_BUTTON_X)
	CoopInput.p2_gamepad_overrides = {}
	CoopInput.refresh_if_built()


## Escape cancels a listen without binding — including a gamepad listen —
## rather than the generic ui_cancel action (which would also match a
## gamepad's default cancel button and make it un-bindable, review catch).
func test_options_escape_cancels_listen_without_binding() -> void:
	var menu: Control = load("res://scenes/ui/options_menu.tscn").instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	menu._start_listen(&"jump")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	menu._unhandled_input(esc)
	assert_eq(menu._listening_action, &"", "Escape ends the listen")
	# the gamepad button matching ui_cancel's default (B) must still be
	# bindable — it should NOT have been swallowed as a cancel
	menu._start_listen(&"attack")
	menu._unhandled_input(_make_pad_press(0, JOY_BUTTON_B))
	assert_eq(menu._listening_action, &"", "listen finished — the button was bound, not treated as cancel")
	var base_pad := InputMap.action_get_events(&"attack").filter(
		func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	assert_eq((base_pad[0] as InputEventJoypadButton).button_index, JOY_BUTTON_B,
			"B is bindable like any other button")
	InputMap.load_from_project_settings()
	CoopInput.refresh_if_built()
