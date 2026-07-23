extends Control
## Pick Chris or Flam. New-game flow: creates the save and launches stage 1.

const PORTRAITS := preload("res://assets/art/characters/portraits.png")

var _picking_p2 := false
var _p1_pick: StringName = &""
var _title: Label


func _ready() -> void:
	UIKit.fill_background(self)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 24)
	row.add_child(_character_panel(&"chris", 0,
			tr("CHRIS_BLURB")))
	row.add_child(_character_panel(&"flam", 1,
			tr("FLAM_BLURB")))
	_title = UIKit.title(_title_text(), 20)
	var column := UIKit.menu_column([
		_title,
		_spacer(8),
		row,
		_spacer(8),
		UIKit.button(tr("BACK"), _back),
	])
	add_child(UIKit.center(column))
	UIKit.grab_first_focus(self)


func _character_panel(id: StringName, portrait_index: int, blurb: String) -> Control:
	var stats := GameManager.character_stats(id)
	var portrait := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAITS
	atlas.region = Rect2(portrait_index * 32, 0, 32, 32)
	portrait.texture = atlas
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pick := UIKit.button(stats.display_name.to_upper(), _on_pick.bind(id))
	var panel := UIKit.menu_column([
		portrait,
		pick,
		UIKit.caption(blurb, 8, UIKit.CYAN if id == &"flam" else UIKit.GREEN),
	])
	return panel


func _title_text() -> String:
	if SlotSelectFlow.mode == SlotSelectFlow.Mode.BOSS_RUSH:
		return tr("BOSS RUSH — SELECT GUARDIAN")
	if SlotSelectFlow.coop:
		return tr("P2: SELECT GUARDIAN") if _picking_p2 else tr("P1: SELECT GUARDIAN")
	return tr("SELECT GUARDIAN")


func _on_pick(id: StringName) -> void:
	if SlotSelectFlow.mode == SlotSelectFlow.Mode.BOSS_RUSH:
		GameManager.launch_custom("res://scenes/ui/boss_rush.tscn", id)
		return
	if SlotSelectFlow.coop and not _picking_p2:
		_p1_pick = id
		_picking_p2 = true
		_title.text = _title_text()
		AudioManager.play_sfx("menu_select")
		return
	var p1: StringName = _p1_pick if SlotSelectFlow.coop else id
	var p2: StringName = id if SlotSelectFlow.coop else &""
	var slot_data := SaveManager.load_slot(SaveManager.active_slot)
	# force_new: slot_select armed a "NEW GAME on an occupied slot" confirm.
	# The slot ISN'T actually touched until now (write_slot below overwrites
	# it), so treat this pick as a fresh start, not a resume, even though
	# the file on disk still has old data. Consumed immediately so it can't
	# leak into an unrelated later pick.
	var force_new := SlotSelectFlow.force_new
	SlotSelectFlow.force_new = false
	var returning := not slot_data.is_empty() and not force_new
	if returning:
		# not reachable via any CURRENT UI path (NEW_GAME on an occupied
		# slot always force_new-resets now; CONTINUE never enters character
		# select; BOSS_RUSH returns earlier) — kept for a future flow that
		# might land here with existing data. Syncs the HUD hi score to
		# THIS slot, not whatever ran before (review v1.10-2).
		GameManager.hi_score = int(slot_data.get("global_hi_score", 0))
	else:
		slot_data = SaveManager.new_slot_data(p1)
		GameManager.hi_score = 0
	# the slot REMEMBERS its mode: CO-OP/SOLO shows in the slot list and
	# CONTINUE restores the same pair
	slot_data["last_character"] = String(p1)
	slot_data["coop"] = p2 != &""
	slot_data["character2"] = String(p2)
	SaveManager.write_slot(SaveManager.active_slot, slot_data)
	GameManager.character = p1
	GameManager.character2 = p2
	# a slot with progress resumes at stage select like solo does; only
	# fresh saves watch the intro (review v1.10-3)
	if returning:
		SceneManager.change_scene("res://scenes/ui/stage_select.tscn")
	else:
		SceneManager.change_scene("res://scenes/ui/intro_cutscene.tscn")


func _back() -> void:
	# defensive: an armed-but-abandoned "new game on occupied slot" confirm
	# must not survive a BACK out of this screen (same leak class `coop` had
	# before it was fixed) — belt-and-suspenders, since every live path that
	# actually consumes force_new also re-arms it fresh right before landing
	# here, but cheap insurance against a future path that doesn't
	SlotSelectFlow.force_new = false
	# boss rush enters straight from the main menu — return there, not to a
	# slot screen the player never visited (review P3-21)
	if SlotSelectFlow.mode == SlotSelectFlow.Mode.BOSS_RUSH:
		SceneManager.change_scene("res://scenes/ui/main_menu.tscn")
	else:
		SceneManager.change_scene("res://scenes/ui/slot_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
