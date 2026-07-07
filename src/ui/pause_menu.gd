class_name PauseMenu
extends CanvasLayer
## Pause overlay in the persistent shell. Listens for the pause action only
## while a stage runs; pauses the whole tree; PROCESS_MODE_ALWAYS keeps the
## menu alive underneath.

const OPTIONS_SCENE := preload("res://scenes/ui/options_menu.tscn")

var _root: Control
var _options: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.07, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var column := UIKit.menu_column([
		UIKit.title("PAUSED", 20),
		UIKit.caption("SYSTEM SUSPENDED", 8, UIKit.CYAN),
		UIKit.button("RESUME", _toggle),
		UIKit.button("RESTART STAGE", _restart),
		UIKit.button("OPTIONS", _open_options),
		UIKit.button("QUIT TO MENU", _quit),
	])
	_root.add_child(UIKit.center(column))
	add_child(_root)
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and GameManager.is_stage_running():
		if _options != null: # options overlay open — let it close first
			return
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
	_options.closed.connect(func() -> void:
		_options.queue_free()
		_options = null
		UIKit.grab_first_focus(_root))
	add_child(_options)


func _quit() -> void:
	_root.visible = false
	GameManager.quit_to_menu()
