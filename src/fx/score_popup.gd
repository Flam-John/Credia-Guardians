class_name ScorePopup
extends Label
## Pooled floating "+200" at a kill position (docs/PERFORMANCE.md: popups
## are pooled — review P4-26).


func _ready() -> void:
	add_theme_font_size_override(&"font_size", 8)
	add_theme_color_override(&"font_color", Color("ffc825"))
	z_index = 50


func show_amount(at_global: Vector2, amount: int) -> void:
	text = "+%d" % amount
	global_position = at_global + Vector2(-8, -20)
	modulate.a = 1.0
	visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y - 14.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(_release)


func _pool_reset() -> void:
	modulate.a = 1.0


func _release() -> void:
	visible = false
	var pool: ObjectPool = get_meta(&"pool") if has_meta(&"pool") else null
	if pool != null:
		pool.release(self)
	else:
		queue_free()
