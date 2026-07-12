class_name PauseMenu
extends CanvasLayer
## Pause overlay in the persistent shell. Listens for the pause action only
## while a stage runs; pauses the whole tree; PROCESS_MODE_ALWAYS keeps the
## menu alive underneath.

const OPTIONS_SCENE := preload("res://scenes/ui/options_menu.tscn")

var _root: Control
var _options: Control
var _column: Control
var _last_locale := ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.03, 0.06, 0.88)
	_root.add_child(dim)
	_last_locale = TranslationServer.get_locale()
	_build_menu()
	add_child(_root)
	# CanvasLayer children don't stretch with anchors (project gotcha) —
	# the root was 0x0: the dim NEVER rendered and the menu collapsed to
	# the top-left. Explicit sizes, NO anchor presets (mixing both fires
	# size-override warnings every boot).
	_root.size = _root.get_viewport_rect().size
	dim.size = _root.size
	_root.visible = false
	# lives in the persistent shell: rebuild text on language change
	# (review P3-22) and reset if a transition force-unpauses (review P0-4)
	EventBus.settings_applied.connect(_on_settings_applied)
	SceneManager.scene_changed.connect(_on_scene_changed)


func _build_menu() -> void:
	if _column != null and is_instance_valid(_column):
		# detach BEFORE queue_free: a dying column stays focusable until end
		# of frame and grab_first_focus would land on it (review v1.9-1)
		_root.remove_child(_column)
		_column.queue_free()
	var items: Array[Control] = [
		UIKit.title(tr("PAUSED"), 20),
		UIKit.caption(tr("SYSTEM SUSPENDED"), 8, UIKit.CYAN),
	]
	if GameManager.is_coop():
		# each player sees his own current keys at a glance
		items.append(UIKit.caption("P1: WASD + %s" % _key_summary_p1(),
				8, UIKit.GREEN))
		items.append(UIKit.caption("P2: %s + %s" % [tr("ARROWS"), _key_summary_p2()],
				8, UIKit.CYAN))
		items.append(UIKit.caption(tr("CHANGE KEYS IN OPTIONS"), 8, UIKit.GRAY))
	items.append_array([
		UIKit.button(tr("RESUME"), _toggle),
		UIKit.button(tr("RESTART STAGE"), _restart),
		UIKit.button(tr("OPTIONS"), _open_options),
		UIKit.button(tr("QUIT TO MENU"), _quit),
	] as Array[Control])
	# beveled panel that sizes itself to the column (key-art physical UI)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.13, 0.96)
	style.border_color = Color(0.12, 0.66, 0.24)
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.add_child(UIKit.menu_column(items))
	_column = UIKit.center(panel)
	_root.add_child(_column)


## "JUMP/ATTACK/DASH" style summaries for the pause screen.
func _key_summary_p1() -> String:
	return "%s/%s/%s" % [SettingsApplier.key_label(&"jump"),
			SettingsApplier.key_label(&"attack"), SettingsApplier.key_label(&"dash")]


func _key_summary_p2() -> String:
	return "%s/%s/%s" % [SettingsApplier.p2_key_label(&"jump"),
			SettingsApplier.p2_key_label(&"attack"), SettingsApplier.p2_key_label(&"dash")]


func _on_settings_applied(_settings: Dictionary) -> void:
	if TranslationServer.get_locale() != _last_locale:
		_last_locale = TranslationServer.get_locale()
		_build_menu()


func _on_scene_changed(_path: String) -> void:
	# SceneManager force-unpauses on swap; without this the PAUSED overlay
	# survives into the new scene with an inverted toggle
	_root.visible = false
	if _options != null and is_instance_valid(_options):
		_options.queue_free()
		_options = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and GameManager.is_stage_running():
		if _options != null: # options overlay open — let it close first
			return
		if SceneManager.is_busy():
			return # pausing mid-fade desyncs overlay vs tree pause state
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_root.visible = paused
	AudioManager.play_sfx("pause_in" if paused else "pause_out")
	EventBus.pause_toggled.emit(paused)
	if paused:
		_build_menu() # refresh the co-op key summaries after any rebind
		UIKit.grab_first_focus(_root)


func _restart() -> void:
	get_tree().paused = false
	_root.visible = false
	GameManager.retry_stage()


func _open_options() -> void:
	_options = OPTIONS_SCENE.instantiate()
	_options.overlay_mode = true
	_options.closed.connect(_on_options_closed)
	add_child(_options)


func _on_options_closed() -> void:
	_options.queue_free()
	_options = null
	UIKit.grab_first_focus(_root)


func _quit() -> void:
	_root.visible = false
	GameManager.quit_to_menu()
