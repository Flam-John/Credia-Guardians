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
