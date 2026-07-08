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
			"THE TANK\n6 HP · Firewall Shield\nsteady and unshakeable"))
	row.add_child(_character_panel(&"flam", 1,
			"THE SPEEDSTER\n4 HP · Overclock Dash\ni-frames, 2 air dashes"))
	_title = UIKit.title(_title_text(), 20)
	var column := UIKit.menu_column([
		_title,
		_spacer(8),
		row,
		_spacer(8),
		UIKit.button("BACK", _back),
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
		return "BOSS RUSH — SELECT GUARDIAN"
	if SlotSelectFlow.coop:
		return "P2: SELECT GUARDIAN" if _picking_p2 else "P1: SELECT GUARDIAN"
	return "SELECT GUARDIAN"


func _on_pick(id: StringName) -> void:
	if SlotSelectFlow.mode == SlotSelectFlow.Mode.BOSS_RUSH:
		GameManager.character = id
		GameManager.character2 = &""
		SceneManager.change_scene("res://scenes/ui/boss_rush.tscn")
		return
	if SlotSelectFlow.coop and not _picking_p2:
		_p1_pick = id
		_picking_p2 = true
		_title.text = _title_text()
		AudioManager.play_sfx("menu_select")
		return
	var p1: StringName = _p1_pick if SlotSelectFlow.coop else id
	var p2: StringName = id if SlotSelectFlow.coop else &""
	if SaveManager.load_slot(SaveManager.active_slot).is_empty():
		SaveManager.write_slot(SaveManager.active_slot, SaveManager.new_slot_data(p1))
		GameManager.hi_score = 0
	GameManager.character = p1
	GameManager.character2 = p2
	SceneManager.change_scene("res://scenes/ui/intro_cutscene.tscn")


func _back() -> void:
	SceneManager.change_scene("res://scenes/ui/slot_select.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
