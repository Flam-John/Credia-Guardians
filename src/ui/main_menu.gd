extends Control
## Main menu: New Game / Continue / Options / Quit.

func _ready() -> void:
	UIKit.fill_background(self)
	var has_saves := SaveManager.get_slot_summaries().any(
		func(s: Dictionary) -> bool: return not s.get("empty", true))
	var continue_btn := UIKit.button(tr("CONTINUE"), _on_continue)
	continue_btn.disabled = not has_saves
	var column := UIKit.menu_column([
		UIKit.title("CREDIA GUARDIANS", 28),
		UIKit.caption(tr("BANK SYSTEM UNDER ATTACK"), 8, UIKit.RED),
		_spacer(10),
		UIKit.button(tr("NEW GAME"), _on_new_game),
		UIKit.button(tr("CO-OP GAME"), _on_coop),
		continue_btn,
		UIKit.button(tr("BOSS RUSH"), _on_boss_rush),
		UIKit.button(tr("OPTIONS"), _on_options),
		UIKit.button(tr("QUIT"), _on_quit),
		_spacer(8),
		UIKit.caption("v%s" % ProjectSettings.get_setting("application/config/version")),
	])
	add_child(UIKit.center(column))
	AudioManager.play_music("menu")
	UIKit.grab_first_focus(self)


func _on_new_game() -> void:
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = false
	SceneManager.change_scene("res://scenes/ui/slot_select.tscn")


func _on_coop() -> void:
	SlotSelectFlow.mode = SlotSelectFlow.Mode.NEW_GAME
	SlotSelectFlow.coop = true
	SceneManager.change_scene("res://scenes/ui/slot_select.tscn")


func _on_boss_rush() -> void:
	SlotSelectFlow.mode = SlotSelectFlow.Mode.BOSS_RUSH
	SlotSelectFlow.coop = false
	SceneManager.change_scene("res://scenes/ui/character_select.tscn")


func _on_continue() -> void:
	SlotSelectFlow.mode = SlotSelectFlow.Mode.CONTINUE
	SceneManager.change_scene("res://scenes/ui/slot_select.tscn")


func _on_options() -> void:
	SceneManager.change_scene("res://scenes/ui/options_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
