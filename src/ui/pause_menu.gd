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
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_last_locale = TranslationServer.get_locale()
	_build_menu()
	add_child(_root)
	_root.visible = false
	# lives in the persistent shell: rebuild text on language change
	# (review P3-22) and reset if a transition force-unpauses (review P0-4)
	EventBus.settings_applied.connect(_on_settings_applied)
	SceneManager.scene_changed.connect(_on_scene_changed)


func _build_menu() -> void:
	if _column != null and is_instance_valid(_column):
		_column.queue_free()
	_column = UIKit.center(UIKit.menu_column([
		UIKit.title(tr("PAUSED"), 20),
		UIKit.caption(tr("SYSTEM SUSPENDED"), 8, UIKit.CYAN),
		UIKit.button(tr("RESUME"), _toggle),
		UIKit.button(tr("RESTART STAGE"), _restart),
		UIKit.button(tr("OPTIONS"), _open_options),
		UIKit.button(tr("QUIT TO MENU"), _quit),
	]))
	_root.add_child(_column)


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
