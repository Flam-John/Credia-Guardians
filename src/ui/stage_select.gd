extends Control
## Stage cards with unlock state, best rank, and hi-score. C toggles which
## character runs the stage (docs/GDD.md §10: re-choose per stage).

const STAGE_NAMES := {
	1: "DEVELOPER OFFICE", 2: "DATA CENTER", 3: "CORPORATE HQ",
	4: "DIGITAL VAULT", 5: "CORE BANKING SYSTEM",
}

var _character: StringName
var _footer: Label


func _ready() -> void:
	UIKit.fill_background(self)
	var data := SaveManager.load_slot(SaveManager.active_slot)
	_character = StringName(data.get("last_character", "chris"))
	var items: Array[Control] = [
		UIKit.title("SELECT STAGE", 20),
		UIKit.caption("C: switch guardian   ESC: back"),
	]
	var stages: Dictionary = data.get("stages", {})
	for stage_id in range(1, 6):
		items.append(_stage_button(stage_id, stages.get(str(stage_id), {})))
	items.append(UIKit.button("BACK", _back))
	_footer = UIKit.caption("", 10, UIKit.GREEN)
	items.append(_footer)
	_update_footer()
	add_child(UIKit.center(UIKit.menu_column(items)))
	UIKit.grab_first_focus(self)


func _stage_button(stage_id: int, entry: Dictionary) -> Button:
	var unlocked: bool = entry.get("unlocked", false)
	var text: String
	if not unlocked:
		text = "%d ▒▒▒▒ LOCKED ▒▒▒▒" % stage_id
	else:
		var rank: String = entry.get("best_rank", "")
		var badge := ("  [%s]" % rank) if rank != "" else ""
		var hi := int(entry.get("hi_score", 0))
		var hi_text := ("  HI %d" % hi) if hi > 0 else ""
		text = "%d  %s%s%s" % [stage_id, STAGE_NAMES[stage_id], badge, hi_text]
	var btn := UIKit.button(text, _on_stage.bind(stage_id))
	btn.custom_minimum_size = Vector2(260, 20)
	btn.disabled = not unlocked or not GameManager.STAGE_SCENES.has(stage_id)
	if unlocked and not GameManager.STAGE_SCENES.has(stage_id):
		btn.text += "  (M4+)"
	return btn


func _on_stage(stage_id: int) -> void:
	GameManager.launch_stage(stage_id, _character)


func _update_footer() -> void:
	_footer.text = "GUARDIAN: %s" % String(_character).to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_C:
		_character = &"flam" if _character == &"chris" else &"chris"
		_update_footer()
		AudioManager.play_sfx("menu_move")


func _back() -> void:
	SceneManager.change_scene("res://scenes/ui/slot_select.tscn")
