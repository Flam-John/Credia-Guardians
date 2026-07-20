class_name SettingsApplier
## Pure "settings dict → engine state" functions. SaveManager persists the
## dict; this class applies it. Kept static so tests can call pieces directly.

const REBINDABLE: Array[StringName] = [&"jump", &"attack", &"dash", &"ability", &"interact", &"fire"]


static func defaults() -> Dictionary:
	return {
		"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
		"video": {"fullscreen": false, "window_scale": 3, "scanlines": true,
				"show_timer": false, "rumble": true},
		"general": {"locale": "en"},
		"input": {},
		"input_p2": {},
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
	CoopInput.p2_overrides = settings.get("input_p2", {}).duplicate()
	CoopInput.refresh_if_built() # P2 overrides only matter to co-op sets
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
	CoopInput.refresh_if_built() # keep p1_/p2_ snapshots in sync


## Key name of P2's effective co-op binding (override or default).
static func p2_key_label(action: StringName) -> String:
	var code := CoopInput.p2_key(action)
	if code == 0:
		return "—"
	# keypad keys: layout translation maps them to Insert/End/etc (numlock-
	# off names) — the physical name (Kp 0...) is what's printed on the key
	var is_keypad := (code >= KEY_KP_MULTIPLY and code <= KEY_KP_9) \
			or code == KEY_KP_ENTER
	if is_keypad or DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(code)
	return OS.get_keycode_string(
			DisplayServer.keyboard_get_keycode_from_physical(code))


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
