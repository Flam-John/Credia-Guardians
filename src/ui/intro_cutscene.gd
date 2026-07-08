extends Control
## 4-panel text intro after character select. Any key advances; skippable.

const PANELS := [
	"CREDIABANK RUNS ON A FORTRESS OF CODE\nBUILT BY TWO DEVELOPERS.",
	"TONIGHT, THE CEO UPLOADED HIMSELF\nAND HIS LOYAL BANKERS INTO THE SYSTEM.\n\nINTEREST RATES SPIKED. ACCOUNTS FROZE.",
	"EVERY CREDIA COIN SCATTERED\nTHROUGH THE INFRASTRUCTURE AS RAW DATA.",
	"CHRIS AND FLAM JACK IN.\n\nFIVE LAYERS BETWEEN THEM AND THE CORE.\nSECURE EVERY NODE. DELETE THE CORRUPTION.",
]

var _index := 0
var _label: Label


func _ready() -> void:
	UIKit.fill_background(self)
	_label = UIKit.caption(PANELS[0], 11, UIKit.GREEN)
	var column := UIKit.menu_column([
		_label,
		Control.new(),
		UIKit.caption("PRESS ANY KEY", 7, UIKit.GRAY),
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
		_label.text = PANELS[_index]
		_label.modulate.a = 0.0
		create_tween().tween_property(_label, "modulate:a", 1.0, 0.4)
		AudioManager.play_sfx("menu_move")
