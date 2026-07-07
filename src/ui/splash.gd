extends Control
## Logo fade-in → hold → main menu. Any input skips.

const NEXT := "res://scenes/ui/main_menu.tscn"

var _done := false


func _ready() -> void:
	UIKit.fill_background(self)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.svg")
	logo.custom_minimum_size = Vector2(64, 64)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var column := UIKit.menu_column([
		logo,
		UIKit.title("CREDIA GUARDIANS", 24),
		UIKit.caption("a FLAMUPIA production"),
	])
	add_child(UIKit.center(column))
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)
	tween.tween_interval(1.2)
	tween.tween_callback(_advance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_advance()


func _advance() -> void:
	if _done:
		return
	_done = true
	SceneManager.change_scene(NEXT)
