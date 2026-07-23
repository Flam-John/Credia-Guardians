extends Control
## Three save slots. NEW_GAME mode: any slot, but an OCCUPIED one needs a
## second confirm press before it erases anything (SlotSelectFlow.force_new,
## consumed by character_select — nothing is actually overwritten until a
## character is picked there, so backing out here is always safe). CONTINUE
## mode: only occupied slots, no confirm needed (never destructive). X deletes.

## Two independent two-press confirms, at most one visible at a time (arming
## either clears the other) — DELETE removes the save and stays on this
## screen; the slot's own button (NEW_GAME + occupied) proceeds to character
## select for a fresh start instead.
var _confirm_delete_slot := -1
var _confirm_new_slot := -1
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
	_focus_slot.call_deferred(_confirm_delete_slot if _confirm_delete_slot > 0 else _confirm_new_slot)


func _focus_slot(slot: int) -> void:
	if slot > 0:
		# an armed slot keeps focus on the SAME button the player just
		# pressed, or a habitual second press lands on the OTHER control and
		# triggers the wrong action — delete-confirm keeps focus on DELETE,
		# new-game-confirm keeps focus on the slot's own main button (review
		# catch: this used to always prefer the DELETE button regardless of
		# which confirm was actually armed, so confirming "new game" could
		# silently redirect focus onto DELETE and the next press erased the
		# save instead of starting fresh)
		var meta_key := &"slot_delete" if _confirm_delete_slot == slot else &"slot"
		for button in _slot_buttons():
			if button.get_meta(meta_key, -1) == slot:
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
	elif _confirm_new_slot == slot:
		text = tr("SLOT %d — PRESS AGAIN: NEW GAME (ERASES SAVE)") % slot
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
		_confirm_new_slot = -1 # only one prompt visible at a time
	_rebuild()


func _on_slot(summary: Dictionary) -> void:
	var slot: int = summary.slot
	SaveManager.active_slot = slot
	if summary.get("empty", true):
		# fresh run: character select creates the save on confirm
		SceneManager.change_scene("res://scenes/ui/character_select.tscn")
		return
	if SlotSelectFlow.mode == SlotSelectFlow.Mode.NEW_GAME:
		if _confirm_new_slot != slot:
			# first press: arm the confirm — nothing is touched yet, so
			# backing out from here (or from character select afterward)
			# leaves the existing save completely intact
			_confirm_new_slot = slot
			_confirm_delete_slot = -1 # only one prompt visible at a time
			_rebuild()
			return
		# second press: proceed to a fresh start. The slot ISN'T actually
		# overwritten here — character_select's write_slot() does that once
		# a character is picked (force_new tells it not to treat this as
		# resuming), so a BACK from character select still doesn't lose
		# anything (review: NEW GAME used to silently resume/re-pick into
		# an occupied slot with no confirmation and no real reset — fixed)
		_confirm_new_slot = -1
		SlotSelectFlow.force_new = true
		SceneManager.change_scene("res://scenes/ui/character_select.tscn")
		return
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
