class_name CoopInput
## Builds per-player input actions at runtime for local co-op.
##
## Single-player uses the base actions untouched (any device). Co-op creates
## "p1_*" (keyboard WASD/Space/JKL + gamepad device 0) and "p2_*" (arrows +
## RightCtrl/RightShift/Enter + gamepad device 1) action sets; each Player
## polls through its own prefix (Player.input_prefix).
##
## Gamepad button rebinding: P1's row in the options menu rebinds the BASE
## action directly (SettingsApplier.apply_gamepad_binding), exactly like its
## keyboard row — that's what makes it work in solo play too, not just co-op,
## since solo polls the base action. P2 needs a genuinely different physical
## button (same base action, different controller), so P2 gets its own
## override layer instead (p2_gamepad_overrides) — mirrors how P2's keyboard
## key is a separate override (p2_overrides) rather than editing the base
## action. The device split (P1=0, P2=1) always stays fixed either way.

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

## Per-action P2 gamepad BUTTON overrides (String action -> Godot JoyButton
## index), persisted in settings under "input_gamepad_p2". Missing entries
## fall back to whatever the base action already binds (same button as P1,
## just on device 1). SettingsApplier keeps this in sync and refreshes the
## sets. P1 has no equivalent dict — its gamepad button IS the base action's,
## rebound via SettingsApplier.apply_gamepad_binding.
static var p2_gamepad_overrides: Dictionary = {}


## Effective P2 keyboard key for a gameplay action (override or default).
static func p2_key(base: StringName) -> int:
	return int(p2_overrides.get(String(base), int(P2_KEYS.get(base, 0))))


## The per-player action name for a base gameplay action — player_index 0
## (solo) polls the base action directly (see the class doc above: solo
## never builds p1_* actions), any other index gets its "pN_" prefix. This
## exact ternary used to be copy-pasted into each gate minigame that needed
## per-player action scoping (CodeReviewMinigame, ServerCoolingMinigame,
## TicketBlitzShip) — consolidated here so the naming convention only has
## one place to change (review catch: 3 copies is 3 places a future fix
## could miss one).
static func scoped_action(base: StringName, player_index: int) -> StringName:
	return base if player_index == 0 else StringName("p%d_%s" % [player_index, base])


## Effective P2 gamepad button override for an action, or null if P2 hasn't
## customized it (falls back to the base action's own binding, device 1).
static func p2_gamepad_override(base: StringName) -> Variant:
	return p2_gamepad_overrides.get(String(base))


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
			# P1 has no override layer — its gamepad button comes straight
			# from the base action (rebound directly, see class doc above).
			var override_button: Variant = p2_gamepad_override(base) if player_index == 2 else null
			var joypad_button_added := false
			for event in InputMap.action_get_events(base):
				if event is InputEventKey and player_index == 1:
					base_key_events.append(event)
					if not p2_reserved.has((event as InputEventKey).physical_keycode):
						InputMap.action_add_event(action, event.duplicate())
						p1_keys_added += 1
				elif event is InputEventJoypadButton:
					if override_button != null:
						# collapse to exactly ONE event: some base actions
						# (dash, ability) carry two alternate buttons, and
						# duplicating both with the override's index would
						# leave two identical redundant events (review catch)
						if not joypad_button_added:
							var override_event := InputEventJoypadButton.new()
							override_event.device = device
							override_event.button_index = int(override_button)
							InputMap.action_add_event(action, override_event)
							joypad_button_added = true
					else:
						var pad_event := event.duplicate() as InputEventJoypadButton
						pad_event.device = device
						InputMap.action_add_event(action, pad_event)
						joypad_button_added = true
				elif event is InputEventJoypadMotion:
					var motion_event: InputEvent = event.duplicate()
					motion_event.device = device
					InputMap.action_add_event(action, motion_event)
			# an override was set but the base action had no joypad button to
			# anchor on (e.g. an action that's normally keyboard-only) — still
			# honor it by adding a fresh event instead of silently dropping it
			if override_button != null and not joypad_button_added:
				var new_pad := InputEventJoypadButton.new()
				new_pad.device = device
				new_pad.button_index = int(override_button)
				InputMap.action_add_event(action, new_pad)
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
