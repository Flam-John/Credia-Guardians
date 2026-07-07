class_name MovingPlatform
extends Path2D
## One-way platform riding a Path2D. AnimatableBody2D + sync_to_physics gives
## riders correct velocity inheritance for free (docs/TDD.md).

const SHEET := preload("res://assets/art/props/platforms.png")

@export var speed := 40.0
@export var ping_pong := true

var _follow: PathFollow2D
var _dir := 1.0


func _ready() -> void:
	_follow = PathFollow2D.new()
	_follow.loop = not ping_pong
	_follow.rotates = false
	add_child(_follow)
	var platform := AnimatableBody2D.new()
	platform.sync_to_physics = true
	platform.collision_layer = PhysicsLayers.PLATFORM_ONEWAY
	platform.collision_mask = 0
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(0, 0, 48, 8)
	sprite.texture = atlas
	platform.add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 6)
	shape.shape = rect
	shape.one_way_collision = true
	platform.add_child(shape)
	_follow.add_child(platform)


func _physics_process(delta: float) -> void:
	_follow.progress += _dir * speed * delta
	if ping_pong:
		if _follow.progress_ratio >= 1.0:
			_dir = -1.0
		elif _follow.progress_ratio <= 0.0:
			_dir = 1.0
