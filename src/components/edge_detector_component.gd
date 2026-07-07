class_name EdgeDetectorComponent
extends Node2D
## Wall-ahead / ledge-ahead checks for patrol AI. Owns two RayCast2D nodes,
## flipped by set_direction(). Distances sized from the owner's dimensions.

@export var wall_ray_length := 10.0
@export var floor_ray_length := 12.0
## X offset of the floor probe ahead of the body center.
@export var lookahead := 8.0

var _wall_ray: RayCast2D
var _floor_ray: RayCast2D
var _dir := 1


func _ready() -> void:
	_wall_ray = RayCast2D.new()
	_wall_ray.collision_mask = PhysicsLayers.WORLD
	add_child(_wall_ray)
	_floor_ray = RayCast2D.new()
	_floor_ray.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLATFORM_ONEWAY
	add_child(_floor_ray)
	set_direction(1)


func set_direction(dir: int) -> void:
	_dir = signi(dir)
	_wall_ray.target_position = Vector2(_dir * wall_ray_length, 0)
	_floor_ray.position = Vector2(_dir * lookahead, 0)
	_floor_ray.target_position = Vector2(0, floor_ray_length)


func is_wall_ahead() -> bool:
	return _wall_ray.is_colliding()


func is_ledge_ahead() -> bool:
	return not _floor_ray.is_colliding()
