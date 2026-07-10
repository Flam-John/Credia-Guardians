class_name ConveyorBelt
extends PushZone
## Conveyor desk strip: pushes a GROUNDED overlapping player horizontally.

@export var push := 40.0 # signed px/s


func setup(tiles_wide: int, direction: int) -> void:
	push = absf(push) * direction
	add_rect_shape(Vector2(tiles_wide * 16, 6), Vector2(tiles_wide * 8.0, -3))
	# animated arrow strip so the direction reads
	var arrows := Label.new()
	arrows.text = (">> " if direction > 0 else "<< ").repeat(tiles_wide)
	arrows.position = Vector2(2, -10)
	arrows.add_theme_font_size_override(&"font_size", 6)
	arrows.add_theme_color_override(&"font_color", Color("16e0e0"))
	add_child(arrows)


func _applies_to(player: Player) -> bool:
	return player.is_on_floor()


func _affect(player: Player) -> void:
	player.apply_field_force(push, 0.0)
