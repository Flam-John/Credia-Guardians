class_name ScorePopup
extends Label
## Floating "+200" at a kill position. Self-freeing; pooled in M5.

static func spawn(parent: Node, world_pos: Vector2, amount: int) -> void:
	var popup := ScorePopup.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override(&"font_size", 8)
	popup.add_theme_color_override(&"font_color", Color("ffc825"))
	popup.position = world_pos + Vector2(-8, -20)
	popup.z_index = 50
	parent.add_child(popup)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 14.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(popup.queue_free)
