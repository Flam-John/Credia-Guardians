extends Control
## 4-panel text intro after character select. Any key advances; skippable.

# Text lives in assets/i18n/translations.csv (keys INTRO_1..4, en + el)
const PANELS := ["INTRO_1", "INTRO_2", "INTRO_3", "INTRO_4"]

var _index := 0
var _label: Label


func _ready() -> void:
	UIKit.fill_background(self)
	_label = UIKit.caption(tr(PANELS[0]), 11, UIKit.GREEN)
	var column := UIKit.menu_column([
		_label,
		Control.new(),
		UIKit.caption(tr("PRESS ANY KEY"), 7, UIKit.GRAY),
	])
	add_child(UIKit.center(column))


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	accept_event()
	_index += 1
	if _index >= PANELS.size():
		set_process_unhandled_input(false) # no double-launch
		GameManager.launch_stage(1, GameManager.character, GameManager.character2)
	else:
		_label.text = tr(PANELS[_index])
		_label.modulate.a = 0.0
		create_tween().tween_property(_label, "modulate:a", 1.0, 0.4)
		AudioManager.play_sfx("menu_move")
