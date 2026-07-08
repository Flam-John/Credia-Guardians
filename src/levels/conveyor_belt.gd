class_name ConveyorBelt
extends Area2D
## Conveyor desk strip: pushes a grounded overlapping player horizontally.
## process_physics_priority -1 → ticks BEFORE Player._physics_process, so
## the push lands in the same frame's move_and_slide (process_priority only
## orders _process, not physics).

@export var push := 40.0 # signed px/s

var _tiles_wide := 1


func _ready() -> void:
	process_physics_priority = -1
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false


func setup(tiles_wide: int, direction: int) -> void:
	_tiles_wide = tiles_wide
	push = absf(push) * direction
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_wide * 16, 6)
	shape.shape = rect
	shape.position = Vector2(tiles_wide * 8.0, -3) # sits on top of the tiles
	add_child(shape)
	# animated arrow strip so the direction reads
	var arrows := Label.new()
	arrows.text = (">> " if direction > 0 else "<< ").repeat(tiles_wide)
	arrows.position = Vector2(2, -10)
	arrows.add_theme_font_size_override(&"font_size", 6)
	arrows.add_theme_color_override(&"font_color", Color("16e0e0"))
	add_child(arrows)


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null and player.is_on_floor():
			player.conveyor_push = push
