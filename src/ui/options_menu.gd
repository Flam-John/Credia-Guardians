extends Control
## Options: audio sliders, video toggles, key rebinding. Works standalone
## (from main menu) or as an overlay (from pause — set overlay_mode true
## before adding; BACK then emits `closed` instead of changing scene).

signal closed

var overlay_mode := false

var _settings: Dictionary
var _listening_action: StringName = &""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	UIKit.fill_background(self)
	_settings = SettingsApplier.merged_with_defaults(SaveManager.load_settings())
	var items: Array[Control] = [UIKit.title("OPTIONS", 20)]
	items.append(_slider_row("MASTER", "audio", "master"))
	items.append(_slider_row("MUSIC", "audio", "music"))
	items.append(_slider_row("SFX", "audio", "sfx"))
	items.append(_check_row("FULLSCREEN", "video", "fullscreen"))
	items.append(_scale_row())
	items.append(_check_row("SCANLINES", "video", "scanlines"))
	items.append(_check_row("SPEEDRUN TIMER", "video", "show_timer"))
	items.append(_check_row("GAMEPAD RUMBLE", "video", "rumble"))
	items.append(UIKit.caption("— KEYS —", 8, UIKit.GRAY))
	for action in SettingsApplier.REBINDABLE:
		items.append(_bind_row(action))
	items.append(UIKit.button("RESET DEFAULTS", _on_reset))
	items.append(UIKit.button("BACK", _on_back))
	add_child(UIKit.center(UIKit.menu_column(items)))
	UIKit.grab_first_focus(self)


func _slider_row(label_text: String, section: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label_text))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = _settings[section][key]
	slider.custom_minimum_size = Vector2(110, 14)
	slider.value_changed.connect(func(v: float) -> void:
		_settings[section][key] = v
		_apply())
	row.add_child(slider)
	return row


func _check_row(label_text: String, section: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(label_text))
	var check := CheckButton.new()
	check.button_pressed = _settings[section][key]
	check.toggled.connect(func(on: bool) -> void:
		_settings[section][key] = on
		_apply())
	row.add_child(check)
	return row


func _scale_row() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label("WINDOW SCALE"))
	var options := OptionButton.new()
	for scale in range(1, 5):
		options.add_item("%d× (%dx%d)" % [scale, 480 * scale, 270 * scale])
	options.select(int(_settings.video.window_scale) - 1)
	options.item_selected.connect(func(index: int) -> void:
		_settings.video.window_scale = index + 1
		_apply())
	row.add_child(options)
	return row


func _bind_row(action: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(String(action).to_upper()))
	var btn := UIKit.button(SettingsApplier.key_label(action), _start_listen.bind(action))
	btn.custom_minimum_size = Vector2(90, 16)
	_bind_buttons[action] = btn
	row.add_child(btn)
	return row


func _start_listen(action: StringName) -> void:
	_listening_action = action
	_bind_buttons[action].text = "PRESS A KEY..."


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != &"":
		var key := event as InputEventKey
		if key != null and key.pressed:
			accept_event()
			if key.physical_keycode != KEY_ESCAPE:
				_settings.input[String(_listening_action)] = int(key.physical_keycode)
				SettingsApplier.apply_key_binding(_listening_action, key.physical_keycode)
			_bind_buttons[_listening_action].text = SettingsApplier.key_label(_listening_action)
			_listening_action = &""
		return
	if event.is_action_pressed(&"ui_cancel"):
		_on_back()


func _apply() -> void:
	SettingsApplier.apply(_settings, get_window())


func _on_reset() -> void:
	_settings = SettingsApplier.defaults()
	for action in SettingsApplier.REBINDABLE:
		InputMap.load_from_project_settings()
		break # one reload restores every action
	_apply()
	# rebuild UI with fresh values
	for child in get_children():
		child.queue_free()
	_bind_buttons.clear()
	_ready()


func _on_back() -> void:
	SaveManager.save_settings(_settings)
	if overlay_mode:
		closed.emit()
	else:
		SceneManager.change_scene("res://scenes/ui/main_menu.tscn")


func _row_label(text: String) -> Label:
	var label := UIKit.caption(text, 9, UIKit.WHITE)
	label.custom_minimum_size = Vector2(110, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label
