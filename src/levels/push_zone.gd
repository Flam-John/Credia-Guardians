class_name PushZone
extends Area2D
## Base for environmental force fields (conveyors, fans, updrafts).
## Owns the shared contract the three props previously copy-pasted:
## process_physics_priority -1 (tick BEFORE the player consumes forces),
## allocation-free overlap guard, per-player dispatch through
## Player.apply_field_force — props never poke Player fields (review P3-19/20).


func _ready() -> void:
	process_physics_priority = -1
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER
	monitorable = false


func _physics_process(_delta: float) -> void:
	if not has_overlapping_bodies():
		return # allocation-free guard
	for body in get_overlapping_bodies():
		var player := body as Player
		if player != null and _applies_to(player):
			_affect(player)


## Override: e.g. conveyors only grip grounded players.
func _applies_to(_player: Player) -> bool:
	return true


## Override: call player.apply_field_force(push_x, lift).
func _affect(_player: Player) -> void:
	pass


func add_rect_shape(size: Vector2, offset: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	add_child(shape)
