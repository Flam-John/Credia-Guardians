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
		items.append(_slot_row(summary))
	items.append(UIKit.button(tr("BACK"), _back))
	_column = UIKit.menu_column(items)
	add_child(UIKit.center(_column))
	# focus must FOLLOW the armed slot across rebuilds — resetting to the
	# first button made X-mashing delete the WRONG save (review P0-2)
	_focus_slot.call_deferred(_confirm_delete_slot)


func _focus_slot(slot: int) -> void:
	if slot > 0:
		# an armed slot keeps focus on its DELETE button so the second
		# press lands where the first did
		for button in _slot_buttons():
			if button.get_meta(&"slot_delete", -1) == slot:
				button.grab_focus()
				return
		for button in _slot_buttons():
			if button.get_meta(&"slot", -1) == slot:
				button.grab_focus()
				return
	UIKit.grab_first_focus(self)


## All buttons in the column, including those nested in slot rows.
func _slot_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _column.get_children():
		if child is Button:
			out.append(child)
		else:
			for nested in child.get_children():
				if nested is Button:
					out.append(nested)
	return out


func _slot_row(summary: Dictionary) -> Control:
	var slot: int = summary.slot
	var text: String
	if summary.get("incompatible", false):
		text = tr("SLOT %d — NEWER VERSION (locked)") % slot
	elif summary.get("empty", true):
		text = tr("SLOT %d — EMPTY") % slot
	else:
		text = "SLOT %d — %s · %s · %d/5 · HI %d" % [
			slot, str(summary.last_character).to_upper(),
			tr("CO-OP") if summary.get("coop", false) else tr("SOLO"),
			summary.stages_cleared, summary.global_hi_score]
	if _confirm_delete_slot == slot:
		text = tr("SLOT %d — PRESS X AGAIN TO DELETE") % slot
	var btn := UIKit.button(text, _on_slot.bind(summary))
	btn.custom_minimum_size = Vector2(280, 20)
	if summary.get("incompatible", false) \
			or (SlotSelectFlow.mode == SlotSelectFlow.Mode.CONTINUE and summary.get("empty", true)):
		btn.disabled = true
	btn.set_meta(&"slot", slot)
	# occupied (or locked) slots get a visible delete button — same
	# two-press confirm as the X shortcut, so a run can be restarted
	# from scratch without knowing the keyboard shortcut
	if summary.get("empty", true) and not summary.get("incompatible", false):
		return btn
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.add_child(btn)
	var del := UIKit.button(
			tr("SURE?") if _confirm_delete_slot == slot else tr("DELETE"),
			_delete_slot.bind(slot))
	del.custom_minimum_size = Vector2(64, 20)
	del.set_meta(&"slot_delete", slot)
	row.add_child(del)
	return row


## Two-press delete, shared by the DELETE button and the X shortcut.
func _delete_slot(slot: int) -> void:
	if _confirm_delete_slot == slot:
		SaveManager.delete_slot(slot)
		_confirm_delete_slot = -1
		AudioManager.play_sfx("menu_back")
	else:
		_confirm_delete_slot = slot
	_rebuild()


func _on_slot(summary: Dictionary) -> void:
	var slot: int = summary.slot
	SaveManager.active_slot = slot
	if summary.get("empty", true):
		# fresh run: character select creates the save on confirm
		SceneManager.change_scene("res://scenes/ui/character_select.tscn")
	elif SlotSelectFlow.mode == SlotSelectFlow.Mode.NEW_GAME and SlotSelectFlow.coop:
		# explicit CO-OP entry on an existing save: re-pick the pair
		# (character select updates the slot's co-op record)
		SceneManager.change_scene("res://scenes/ui/character_select.tscn")
	else:
		var data := SaveManager.load_slot(slot)
		# the slot remembers its mode: co-op saves resume as co-op
		GameManager.continue_from_slot(data)
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
	if focused == null:
		return
	var slot: int = focused.get_meta(&"slot", focused.get_meta(&"slot_delete", -1))
	if slot < 1:
		return
	var summary: Dictionary = SaveManager.get_slot_summaries()[slot - 1]
	if summary.get("empty", true) and not summary.get("incompatible", false):
		return
	_delete_slot(slot)


func _back() -> void:
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
