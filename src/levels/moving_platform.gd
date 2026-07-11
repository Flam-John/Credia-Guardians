class_name MovingPlatform
extends Path2D
## One-way platform riding a Path2D. AnimatableBody2D + sync_to_physics gives
## riders correct velocity inheritance for free (docs/TDD.md).

const SHEET := preload("res://assets/art/props/platforms.png")

@export var speed := 40.0
@export var ping_pong := true
## Start at the far end moving back — chains of movers alternate this so
## adjacent platform ends meet instead of staying phase-locked apart.
@export var start_at_end := false

var _follow: PathFollow2D
var _platform: AnimatableBody2D
var _dir := 1.0


func _ready() -> void:
	_follow = PathFollow2D.new()
	_follow.loop = not ping_pong
	_follow.rotates = false
	add_child(_follow)
	if start_at_end:
		_follow.progress_ratio = 1.0
		_dir = -1.0
	_platform = AnimatableBody2D.new()
	_platform.sync_to_physics = true
	_platform.collision_layer = PhysicsLayers.PLATFORM_ONEWAY
	_platform.collision_mask = 0
	var sprite := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(0, 0, 48, 8)
	sprite.texture = atlas
	_platform.add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 6)
	shape.shape = rect
	shape.one_way_collision = true
	_platform.add_child(shape)
	# The body is a SIBLING of the follower and gets moved DIRECTLY each
	# physics tick: sync_to_physics only computes rider velocity for direct
	# transform writes — moved via a PathFollow2D parent, the platform slid
	# out from under standing players (they were never carried).
	add_child(_platform)
	_platform.global_position = _follow.global_position


func _physics_process(delta: float) -> void:
	_follow.progress += _dir * speed * delta
	if ping_pong:
		if _follow.progress_ratio >= 1.0:
			_dir = -1.0
		elif _follow.progress_ratio <= 0.0:
			_dir = 1.0
	_platform.global_position = _follow.global_position
