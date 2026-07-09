extends Control
## Three save slots. NEW_GAME mode: any slot (occupied warns of overwrite via
## delete-first rule). CONTINUE mode: only occupied slots. X deletes.

var _confirm_delete_slot := -1
var _column: VBoxContainer


func _ready() -> void:
	UIKit.fill_background(self)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		if child is CenterContainer:
			child.queue_free()
	var items: Array[Control] = [
		UIKit.title(tr("SELECT SLOT"), 20),
		UIKit.caption(tr("X: delete slot   ESC: back")),
	]
	for summary in SaveManager.get_slot_summaries():
		items.append(_slot_button(summary))
	items.append(UIKit.button(tr("BACK"), _back))
	_column = UIKit.menu_column(items)
	add_child(UIKit.center(_column))
	# focus must FOLLOW the armed slot across rebuilds — resetting to the
	# first button made X-mashing delete the WRONG save (review P0-2)
	_focus_slot.call_deferred(_confirm_delete_slot)


func _focus_slot(slot: int) -> void:
	if slot > 0:
		for button in _column.get_children():
			if button.has_meta(&"slot") and button.get_meta(&"slot") == slot:
				button.grab_focus()
				return
	UIKit.grab_first_focus(self)


func _slot_button(summary: Dictionary) -> Button:
	var slot: int = summary.slot
	var text: String
	if summary.get("incompatible", false):
		text = tr("SLOT %d — NEWER VERSION (locked)") % slot
	elif summary.get("empty", true):
		text = tr("SLOT %d — EMPTY") % slot
	else:
		text = "SLOT %d — %s · %d/5 · HI %d" % [
			slot, str(summary.last_character).to_upper(),
			summary.stages_cleared, summary.global_hi_score]
	if _confirm_delete_slot == slot:
		text = tr("SLOT %d — PRESS X AGAIN TO DELETE") % slot
	var btn := UIKit.button(text, _on_slot.bind(summary))
	btn.custom_minimum_size = Vector2(280, 20)
	if summary.get("incompatible", false) \
			or (SlotSelectFlow.mode == SlotSelectFlow.Mode.CONTINUE and summary.get("empty", true)):
		btn.disabled = true
	btn.set_meta(&"slot", slot)
	return btn


func _on_slot(summary: Dictionary) -> void:
	var slot: int = summary.slot
	SaveManager.active_slot = slot
	if summary.get("empty", true):
		# fresh run: character select creates the save on confirm
		SceneManager.change_scene("res://scenes/ui/character_select.tscn")
	else:
		var data := SaveManager.load_slot(slot)
		GameManager.hi_score = int(data.get("global_hi_score", 0))
		GameManager.character2 = &"" # CONTINUE is solo (review P1-5)
		SceneManager.change_scene("res://scenes/ui/stage_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_X:
		_delete_focused()


func _delete_focused() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.has_meta(&"slot"):
		return
	var slot: int = focused.get_meta(&"slot")
	var summary: Dictionary = SaveManager.get_slot_summaries()[slot - 1]
	if summary.get("empty", true) and not summary.get("incompatible", false):
		return
	if _confirm_delete_slot == slot:
		SaveManager.delete_slot(slot)
		_confirm_delete_slot = -1
		AudioManager.play_sfx("menu_back")
	else:
		_confirm_delete_slot = slot
	_rebuild()


func _back() -> void:
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
