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
	# key bindings live in OPTIONS only — the pause screen stays clean
	_column = UIKit.center(UIKit.framed_panel(UIKit.menu_column([
		UIKit.title(tr("PAUSED"), 20),
		UIKit.caption(tr("SYSTEM SUSPENDED"), 8, UIKit.CYAN),
		UIKit.button(tr("RESUME"), _toggle),
		UIKit.button(tr("RESTART STAGE"), _restart),
		UIKit.button(tr("OPTIONS"), _open_options),
		UIKit.button(tr("QUIT TO MENU"), _quit),
	])))
	# a language change from the options overlay rebuilds this column —
	# it must stay hidden (and unfocusable) while options are open
	# (review v1.10.1-1)
	_column.visible = _options == null or not is_instance_valid(_options)
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
	# Every path that force-unpauses (RESTART STAGE, QUIT TO MENU, boss rush
	# retry, a stage-clear scene swap) sets get_tree().paused = false directly
	# and lands here via SceneManager.scene_changed WITHOUT going through
	# _toggle() — so this is the one chokepoint that must also tell
	# AudioManager to unfreeze, or a restart/quit taken from a paused stage
	# leaves music/SFX silently frozen forever in the next scene (review:
	# confirmed reproducible before this line existed). Emitting false when
	# audio was never frozen is a harmless no-op.
	EventBus.pause_toggled.emit(false)


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
	if paused:
		# guards the (very unlikely) case of pausing mid-hitstop: that timer
		# ignores both pause and time_scale, so it self-resets shortly on its
		# own, but there's no reason to risk resuming into slow-motion
		Engine.time_scale = 1.0
	get_tree().paused = paused
	_root.visible = paused
	AudioManager.play_sfx("pause_in" if paused else "pause_out", true, true)
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
	# CanvasLayer children need explicit sizing (project gotcha) — without
	# this the overlay collapsed to 0x0: panel stuck top-left, no dim
	_options.size = _root.get_viewport_rect().size
	_column.visible = false # don't show PAUSED through the options dim


func _on_options_closed() -> void:
	_options.queue_free()
	_options = null
	_column.visible = true
	UIKit.grab_first_focus(_root)


func _quit() -> void:
	_root.visible = false
	GameManager.quit_to_menu()
