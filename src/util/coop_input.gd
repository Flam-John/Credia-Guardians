class_name CoopInput
## Builds per-player input actions at runtime for local co-op.
##
## Single-player uses the base actions untouched (any device). Co-op creates
## "p1_*" (keyboard WASD/Space/JKL + gamepad device 0) and "p2_*" (arrows +
## RightCtrl/RightShift/Enter + gamepad device 1) action sets; each Player
## polls through its own prefix (Player.input_prefix).

const GAMEPLAY_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"jump", &"attack", &"dash", &"ability", &"interact", &"fire",
]

## P2 keyboard fallbacks (physical keycodes) when only one gamepad exists.
const P2_KEYS := {
	&"move_left": KEY_LEFT, &"move_right": KEY_RIGHT,
	&"move_up": KEY_UP, &"move_down": KEY_DOWN,
	&"jump": KEY_KP_0, &"attack": KEY_KP_1, &"dash": KEY_KP_2,
	&"ability": KEY_KP_3, &"interact": KEY_KP_ENTER, &"fire": KEY_KP_4,
}

static var _built := false

## Per-action P2 keyboard overrides (String action -> physical keycode int),
## persisted in settings under "input_p2". Missing entries fall back to
## P2_KEYS. SettingsApplier keeps this in sync and refreshes the sets.
static var p2_overrides: Dictionary = {}


## Effective P2 keyboard key for a gameplay action (override or default).
static func p2_key(base: StringName) -> int:
	return int(p2_overrides.get(String(base), int(P2_KEYS.get(base, 0))))


## Rebinding edits BASE actions only; co-op sets are snapshots and must be
## refreshed or rebinds silently never reach co-op players (review P1-10).
static func refresh_if_built() -> void:
	if _built:
		_built = false
		ensure_actions()


static func ensure_actions() -> void:
	if _built:
		return
	_built = true
	# Keys reserved for P2 must NOT leak into P1's set: the base actions
	# bind BOTH WASD and the arrows (single-player convenience), so copying
	# every keyboard event gave P1 the arrows too — both "keyboards" drove
	# the same character in co-op.
	var p2_reserved := {}
	for base in GAMEPLAY_ACTIONS:
		var reserved_key := p2_key(base)
		if reserved_key != 0:
			p2_reserved[reserved_key] = true
	for base in GAMEPLAY_ACTIONS:
		for player_index: int in [1, 2]:
			var action := StringName("p%d_%s" % [player_index, base])
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
			else:
				InputMap.add_action(action, 0.3)
			var device: int = player_index - 1 # gamepad 0 for P1, 1 for P2
			var base_key_events: Array[InputEvent] = []
			var p1_keys_added := 0
			for event in InputMap.action_get_events(base):
				if event is InputEventKey and player_index == 1:
					base_key_events.append(event)
					if not p2_reserved.has((event as InputEventKey).physical_keycode):
						InputMap.action_add_event(action, event.duplicate())
						p1_keys_added += 1
				elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
					var pad_event: InputEvent = event.duplicate()
					pad_event.device = device
					InputMap.action_add_event(action, pad_event)
			# a rebind may have moved the ONLY base key onto a P2-reserved key;
			# a shared key beats leaving P1 with no keyboard binding at all
			if player_index == 1 and p1_keys_added == 0:
				for event in base_key_events:
					InputMap.action_add_event(action, event.duplicate())
			if player_index == 2:
				var key_code := p2_key(base)
				if key_code != 0:
					var key := InputEventKey.new()
					key.physical_keycode = key_code as Key
					InputMap.action_add_event(action, key)
