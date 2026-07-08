class_name GameFeel
## Hitstop + screenshake helpers (docs/GDD.md §11 "Feel"). Static so any
## entity can call without wiring; shake routes to the current PlayerCamera.

const HITSTOP_SCALE := 0.05

static var _stopping := false


## Freeze-frame: time_scale dip for `duration` REAL seconds.
static func hitstop(tree: SceneTree, duration := 0.05) -> void:
	if _stopping:
		return
	_stopping = true
	Engine.time_scale = HITSTOP_SCALE
	# process_always=true + ignore_time_scale=true → timer runs in real time
	await tree.create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false


static func shake(tree: SceneTree, amount_px := 3.0) -> void:
	var camera := tree.root.get_camera_2d() as PlayerCamera
	if camera != null:
		camera.add_shake(amount_px)


## Toggled by SettingsApplier from the options menu.
static var rumble_enabled := true


## device -1 = both pads (boss slams); otherwise a specific player's pad.
static func rumble(device: int, weak := 0.5, strong := 0.3, duration := 0.2) -> void:
	if not rumble_enabled:
		return
	if device < 0:
		Input.start_joy_vibration(0, weak, strong, duration)
		Input.start_joy_vibration(1, weak, strong, duration)
	else:
		Input.start_joy_vibration(device, weak, strong, duration)
