extends Control
## Options: audio sliders, video toggles, key rebinding. Works standalone
## (from main menu) or as an overlay (from pause — set overlay_mode true
## before adding; BACK then emits `closed` instead of changing scene).

signal closed

var overlay_mode := false

var _settings: Dictionary
var _listening_action: StringName = &""
var _listening_p2 := false
var _bind_buttons: Dictionary = {}
var _bind_buttons_p2: Dictionary = {}


func _ready() -> void:
	UIKit.fill_background(self)
	_settings = SettingsApplier.merged_with_defaults(SaveManager.load_settings())
	var items: Array[Control] = [UIKit.title(tr("OPTIONS"), 20)]
	items.append(_slider_row("MASTER", "audio", "master"))
	items.append(_slider_row("MUSIC", "audio", "music"))
	items.append(_slider_row("SFX", "audio", "sfx"))
	items.append(_check_row("FULLSCREEN", "video", "fullscreen"))
	items.append(_scale_row())
	items.append(_check_row("SCANLINES", "video", "scanlines"))
	items.append(_check_row("SPEEDRUN TIMER", "video", "show_timer"))
	items.append(_check_row("GAMEPAD RUMBLE", "video", "rumble"))
	items.append(_language_row())
	if GameManager.is_coop():
		# co-op: each player sees and edits HIS OWN keys
		items.append(UIKit.caption(tr("— P1 KEYS —"), 8, UIKit.GREEN))
		items.append(UIKit.caption(tr("P1 MOVES WITH WASD"), 8, UIKit.GRAY))
		for action in SettingsApplier.REBINDABLE:
			items.append(_bind_row(action))
		items.append(UIKit.caption(tr("— P2 KEYS —"), 8, UIKit.CYAN))
		items.append(UIKit.caption(tr("P2 MOVES WITH THE ARROWS"), 8, UIKit.GRAY))
		for action in SettingsApplier.REBINDABLE:
			items.append(_bind_row_p2(action))
	else:
		items.append(UIKit.caption(tr("— KEYS —"), 8, UIKit.GRAY))
		for action in SettingsApplier.REBINDABLE:
			items.append(_bind_row(action))
	items.append(UIKit.button(tr("RESET DEFAULTS"), _on_reset))
	items.append(UIKit.button(tr("BACK"), _on_back))
	# the column outgrew the 270px screen (audio + video + language + keys):
	# scroll it, and follow_focus keeps keyboard/gamepad navigation visible
	var column := UIKit.menu_column(items)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(300, 244)
	scroll.add_child(column)
	add_child(UIKit.center(scroll))
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
	# wheel must scroll the page, not silently drift the volume (review v1.8-1)
	slider.scrollable = false
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


const LOCALES := ["en", "el"]
const LOCALE_NAMES := ["English", "Ελληνικά"]


func _language_row() -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label("LANGUAGE"))
	var options := OptionButton.new()
	for locale_name in LOCALE_NAMES:
		options.add_item(locale_name)
	options.select(maxi(0, LOCALES.find(str(_settings.general.locale))))
	options.item_selected.connect(func(index: int) -> void:
		_settings.general.locale = LOCALES[index]
		_apply()
		SaveManager.save_settings(_settings)
		_rebuild()) # retranslate every label on this screen
	row.add_child(options)
	return row


## Full rebuild (language change / reset): re-run _ready with fresh state.
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_bind_buttons.clear()
	_bind_buttons_p2.clear()
	_listening_action = &""
	_listening_p2 = false
	_ready()


func _bind_row(action: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(String(action).to_upper()))
	var btn := UIKit.button(SettingsApplier.key_label(action), _start_listen.bind(action))
	btn.custom_minimum_size = Vector2(90, 16)
	_bind_buttons[action] = btn
	row.add_child(btn)
	return row


func _bind_row_p2(action: StringName) -> Control:
	var row := HBoxContainer.new()
	row.add_child(_row_label(String(action).to_upper()))
	var btn := UIKit.button(SettingsApplier.p2_key_label(action),
			_start_listen_p2.bind(action))
	btn.custom_minimum_size = Vector2(90, 16)
	_bind_buttons_p2[action] = btn
	row.add_child(btn)
	return row


func _start_listen(action: StringName) -> void:
	_listening_action = action
	_listening_p2 = false
	_bind_buttons[action].text = tr("PRESS A KEY...")


func _start_listen_p2(action: StringName) -> void:
	_listening_action = action
	_listening_p2 = true
	_bind_buttons_p2[action].text = tr("PRESS A KEY...")


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action != &"":
		var key := event as InputEventKey
		if key != null and key.pressed:
			accept_event()
			if key.physical_keycode != KEY_ESCAPE:
				if _listening_p2:
					_settings.input_p2[String(_listening_action)] = int(key.physical_keycode)
					CoopInput.p2_overrides = _settings.input_p2.duplicate()
					CoopInput.refresh_if_built()
				else:
					_settings.input[String(_listening_action)] = int(key.physical_keycode)
					SettingsApplier.apply_key_binding(_listening_action, key.physical_keycode)
			if _listening_p2:
				_bind_buttons_p2[_listening_action].text = \
						SettingsApplier.p2_key_label(_listening_action)
			else:
				_bind_buttons[_listening_action].text = \
						SettingsApplier.key_label(_listening_action)
			_listening_action = &""
			_listening_p2 = false
		return
	if event.is_action_pressed(&"ui_cancel"):
		# consume, or the same ESC press falls through to PauseMenu and
		# unpauses the game in one stroke (review P0-3)
		accept_event()
		_on_back()


func _apply() -> void:
	SettingsApplier.apply(_settings, get_window())


func _on_reset() -> void:
	_settings = SettingsApplier.defaults()
	InputMap.load_from_project_settings() # restores every action's bindings
	# the reload WIPES the runtime p1_/p2_ co-op actions — rebuild them or a
	# co-op session resets into two frozen players (review v1.8.3-1)
	CoopInput.refresh_if_built()
	_apply()
	_rebuild()


func _on_back() -> void:
	SaveManager.save_settings(_settings)
	if overlay_mode:
		closed.emit()
	else:
		SceneManager.change_scene("res://scenes/ui/main_menu.tscn")


func _row_label(text: String) -> Label:
	var label := UIKit.caption(tr(text), 9, UIKit.WHITE)
	label.custom_minimum_size = Vector2(110, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label
