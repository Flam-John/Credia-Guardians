extends GutTest
## Settings pipeline: defaults merge, key rebinding, bus volumes.


func after_each() -> void:
	InputMap.load_from_project_settings() # undo rebinds
	SettingsApplier.apply(SettingsApplier.defaults(), get_window())


func test_merge_fills_missing_sections() -> void:
	var merged := SettingsApplier.merged_with_defaults({"audio": {"music": 0.2}})
	assert_eq(float(merged.audio.music), 0.2)
	assert_eq(float(merged.audio.master), 1.0, "missing keys fall back to defaults")
	assert_true(merged.has("video"))
	assert_true(merged.has("input"))


func test_rebind_replaces_keyboard_keeps_gamepad() -> void:
	var pads_before := InputMap.action_get_events(&"jump").filter(
		func(e: InputEvent) -> bool: return e is InputEventJoypadButton).size()
	SettingsApplier.apply_key_binding(&"jump", KEY_Q)
	var events := InputMap.action_get_events(&"jump")
	var keys := events.filter(func(e: InputEvent) -> bool: return e is InputEventKey)
	var pads := events.filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	assert_eq(keys.size(), 1, "exactly one keyboard binding after rebind")
	assert_eq((keys[0] as InputEventKey).physical_keycode, KEY_Q)
	assert_eq(pads.size(), pads_before, "gamepad bindings untouched")


func test_apply_sets_bus_volumes() -> void:
	var settings := SettingsApplier.defaults()
	settings.audio.music = 0.5
	SettingsApplier.apply(settings, get_window())
	var idx := AudioServer.get_bus_index("Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.01)


func test_apply_mutes_at_zero() -> void:
	var settings := SettingsApplier.defaults()
	settings.audio.sfx = 0.0
	SettingsApplier.apply(settings, get_window())
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")))


func test_settings_applied_signal_fires() -> void:
	watch_signals(EventBus)
	SettingsApplier.apply(SettingsApplier.defaults(), get_window())
	assert_signal_emitted(EventBus, "settings_applied")


func test_gamepad_button_name_known_and_fallback() -> void:
	assert_eq(SettingsApplier.gamepad_button_name(0), "A")
	assert_eq(SettingsApplier.gamepad_button_name(9), "LB")
	assert_eq(SettingsApplier.gamepad_button_name(99), "Btn 99", "unknown index falls back")


func test_gamepad_label_shows_base_binding_by_default() -> void:
	# "jump" ships with a base gamepad button in project.godot — the label
	# should reflect it even with no per-player override set
	assert_ne(SettingsApplier.gamepad_label(&"jump", 1), "—")


func test_gamepad_label_p2_prefers_its_override() -> void:
	CoopInput.p2_gamepad_overrides = {"jump": JOY_BUTTON_Y}
	assert_eq(SettingsApplier.gamepad_label(&"jump", 2), "Y")
	CoopInput.p2_gamepad_overrides = {}
	CoopInput.refresh_if_built()


## P1 has no override layer to check — gamepad_label(action, 1) must always
## reflect the base action directly, since that's what rebinding P1 changes.
func test_gamepad_label_p1_reflects_base_action_rebind() -> void:
	SettingsApplier.apply_gamepad_binding(&"jump", JOY_BUTTON_X)
	assert_eq(SettingsApplier.gamepad_label(&"jump", 1), "X")


func test_apply_gamepad_binding_affects_base_action() -> void:
	SettingsApplier.apply_gamepad_binding(&"jump", JOY_BUTTON_X)
	var pads := InputMap.action_get_events(&"jump").filter(
		func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	assert_eq(pads.size(), 1, "exactly one gamepad binding after rebind")
	assert_eq((pads[0] as InputEventJoypadButton).button_index, JOY_BUTTON_X)


func test_apply_propagates_gamepad_settings() -> void:
	var settings := SettingsApplier.defaults()
	settings.input_gamepad_p1 = {"jump": JOY_BUTTON_X}
	settings.input_gamepad_p2 = {"fire": JOY_BUTTON_B}
	SettingsApplier.apply(settings, get_window())
	var base_pads := InputMap.action_get_events(&"jump").filter(
		func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	assert_eq((base_pads[0] as InputEventJoypadButton).button_index, JOY_BUTTON_X,
			"input_gamepad_p1 rebinds the base action")
	assert_eq(int(CoopInput.p2_gamepad_overrides.get("fire")), JOY_BUTTON_B)
