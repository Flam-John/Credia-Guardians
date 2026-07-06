extends Node
## Scene transitions with fade + threaded loading (docs/TDD.md §2.2).
## Owns its own CanvasLayer so no scene needs transition plumbing.

signal scene_changed(path: String)

const FADE_SEC := 0.25
const FADE_COLOR := Color("050a12") # BG_VOID

var _layer: CanvasLayer
var _rect: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = FADE_COLOR
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	_layer.add_child(_rect)


## Fade out -> threaded load -> swap -> fade in.
func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	ResourceLoader.load_threaded_request(path)
	var scene: PackedScene = null
	while scene == null:
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				scene = ResourceLoader.load_threaded_get(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("SceneManager: failed to load %s" % path)
				_busy = false
				await _fade_to(0.0)
				return
			_:
				await get_tree().process_frame
	get_tree().change_scene_to_packed(scene)
	get_tree().paused = false
	scene_changed.emit(path)
	await _fade_to(0.0)
	_busy = false


func reload_current() -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	get_tree().reload_current_scene()
	get_tree().paused = false
	await _fade_to(0.0)
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "modulate:a", alpha, FADE_SEC)
	await tween.finished
