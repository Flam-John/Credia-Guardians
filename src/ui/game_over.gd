extends Control
## Out of lives. Retry restarts the stage fresh; progress in the save keeps.


func _ready() -> void:
	UIKit.fill_background(self)
	AudioManager.stop_music()
	AudioManager.play_sfx("death")
	var column := UIKit.menu_column([
		UIKit.title("GAME OVER", 28, UIKit.RED),
		UIKit.caption("ACCOUNT OVERDRAWN", 8, UIKit.GRAY),
		_spacer(12),
		UIKit.caption("SCORE %d" % GameManager.score, 10, UIKit.WHITE),
		_spacer(12),
		UIKit.button("RETRY STAGE", GameManager.retry_stage),
		UIKit.button("QUIT TO MENU", GameManager.quit_to_menu),
	])
	add_child(UIKit.center(column))
	UIKit.grab_first_focus(self)


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
