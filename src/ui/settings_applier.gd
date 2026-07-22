class_name SettingsApplier
## Pure "settings dict → engine state" functions. SaveManager persists the
## dict; this class applies it. Kept static so tests can call pieces directly.

const REBINDABLE: Array[StringName] = [&"jump", &"attack", &"dash", &"ability", &"interact", &"fire"]

## Godot JoyButton index -> friendly Xbox-style name for the options UI.
## Falls back to "Btn N" for anything outside this common range (paddles,
## touchpad, misc.).
const GAMEPAD_BUTTON_NAMES := {
	0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 5: "Guide", 6: "Start",
	7: "L3", 8: "R3", 9: "LB", 10: "RB",
	11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right",
}


static func defaults() -> Dictionary:
	return {
		"audio": {"master": 1.0, "music": 0.8, "sfx": 1.0},
		"video": {"fullscreen": false, "window_scale": 3, "scanlines": true,
				"show_timer": false, "rumble": true},
		"general": {"locale": "en"},
		"input": {},
		"input_p2": {},
		"input_gamepad_p1": {},
		"input_gamepad_p2": {},
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
	for action: String in settings.get("input_gamepad_p1", {}):
		apply_gamepad_binding(StringName(action), int(settings.input_gamepad_p1[action]))
	CoopInput.p2_overrides = settings.get("input_p2", {}).duplicate()
	CoopInput.p2_gamepad_overrides = settings.get("input_gamepad_p2", {}).duplicate()
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


## Replace ALL gamepad-button bindings of an action with exactly one,
## mirroring apply_key_binding's keyboard behavior (collapses any alternate
## buttons the base action had down to the one just picked). Affects solo
## play AND co-op P1, since both poll bindings that trace back to this base
## action — P2 gets an independent override instead (CoopInput.p2_gamepad_
## overrides), since P2 needs a genuinely different physical button on a
## different controller, not a change to the shared base.
static func apply_gamepad_binding(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			InputMap.action_erase_event(action, event)
	var pad := InputEventJoypadButton.new()
	pad.button_index = button_index
	InputMap.action_add_event(action, pad)
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


## Friendly Xbox-style name for a raw JoyButton index (public: also used to
## label a live "last button pressed" readout, not just a bound action).
static func gamepad_button_name(index: int) -> String:
	return GAMEPAD_BUTTON_NAMES.get(index, "Btn %d" % index)


## Effective gamepad button label for an action for the given player (1 or
## 2). P1 always reflects the base action directly (that's what rebinding
## P1 actually changes); P2 checks its own override first, else falls back
## to the same base binding (so the row never looks unset just because
## nobody has customized P2's button yet).
static func gamepad_label(action: StringName, player_index: int) -> String:
	if player_index == 2:
		var override_button: Variant = CoopInput.p2_gamepad_override(action)
		if override_button != null:
			return gamepad_button_name(int(override_button))
	for event in InputMap.action_get_events(action):
		var pad := event as InputEventJoypadButton
		if pad != null:
			return gamepad_button_name(pad.button_index)
	return "—"
