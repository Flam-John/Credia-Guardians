class_name SettingsApplier
## Pure "settings dict → engine state" functions. SaveManager persists the
## dict; this class applies it. Kept static so tests can call pieces directly.

const REBINDABLE: Array[StringName] = [&"jump", &"attack", &"dash", &"ability", &"interact"]


static func defaults() -> Dictionary:
	return {
		"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
		"video": {"fullscreen": false, "window_scale": 3, "scanlines": false,
				"show_timer": false, "rumble": true},
		"general": {"locale": "en"},
		"input": {},
	}


## Merge saved over defaults so new settings keys get sane values.
static func merged_with_defaults(saved: Dictionary) -> Dictionary:
	var out := defaults()
	for section: String in saved:
		if out.has(section):
			out[section].merge(saved[section], true)
	return out


static func apply(settings: Dictionary, window: Window) -> void:
	var audio: Dictionary = settings.audio
	AudioManager.set_bus_volume("Master", audio.master)
	AudioManager.set_bus_volume("Music", audio.music)
	AudioManager.set_bus_volume("SFX", audio.sfx)
	AudioManager.set_bus_volume("UI", audio.sfx)
	var video: Dictionary = settings.video
	if video.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
	else:
		window.mode = Window.MODE_WINDOWED
		var scale := int(video.window_scale)
		window.size = Vector2i(480, 270) * scale
	GameFeel.rumble_enabled = video.get("rumble", true)
	TranslationServer.set_locale(settings.get("general", {}).get("locale", "en"))
	for action: String in settings.input:
		apply_key_binding(StringName(action), int(settings.input[action]))
	EventBus.settings_applied.emit(settings)


## Replace the keyboard binding of an action, preserving gamepad events.
static func apply_key_binding(action: StringName, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, key)


## Current keyboard key name for an action (for the options UI).
static func key_label(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			if DisplayServer.get_name() == "headless":
				# layout translation unsupported headless (tests)
				return OS.get_keycode_string(key.physical_keycode)
			return OS.get_keycode_string(
					DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))
	return "—"
