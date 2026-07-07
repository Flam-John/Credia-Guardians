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
