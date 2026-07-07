class_name CrumblingPlatform
extends StaticBody2D
## Shakes when stood on, breaks, respawns (docs/GDD.md §5 paper stacks).

const SHEET := preload("res://assets/art/props/platforms.png")
const SHAKE_TIME := 0.5
const RESPAWN_TIME := 2.0

var _sprite: Sprite2D
var _shape: CollisionShape2D
var _atlas: AtlasTexture
var _state := 0 # 0 intact, 1 shaking, 2 broken
## Child Timer (NOT SceneTreeTimer): dies with the platform, so a pending
## break/respawn can never fire on a freed instance after a scene change.
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	collision_layer = PhysicsLayers.PLATFORM_ONEWAY
	collision_mask = 0
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 8, 32, 16)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas
	add_child(_sprite)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 6)
	_shape.shape = rect
	_shape.position = Vector2(0, -3)
	_shape.one_way_collision = true
	add_child(_shape)
	# rider detection: thin area on top
	var detector := Area2D.new()
	detector.collision_layer = 0
	detector.collision_mask = PhysicsLayers.PLAYER
	var dshape := CollisionShape2D.new()
	var drect := RectangleShape2D.new()
	drect.size = Vector2(30, 4)
	dshape.shape = drect
	dshape.position = Vector2(0, -8)
	detector.add_child(dshape)
	detector.body_entered.connect(_on_stepped_on)
	add_child(detector)


func _on_stepped_on(_body: Node2D) -> void:
	if _state != 0:
		return
	_state = 1
	_atlas.region = Rect2(32, 8, 32, 16)
	AudioManager.play_sfx("platform_crumble")
	var tween := create_tween()
	tween.set_loops(int(SHAKE_TIME / 0.06))
	tween.tween_property(_sprite, "position:x", 1.0, 0.03)
	tween.tween_property(_sprite, "position:x", -1.0, 0.03)
	_start_timer(SHAKE_TIME, _break)


func _break() -> void:
	_state = 2
	_atlas.region = Rect2(64, 8, 32, 16)
	_shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.2)
	_start_timer(RESPAWN_TIME, _respawn)


func _start_timer(seconds: float, callback: Callable) -> void:
	for connection in _timer.timeout.get_connections():
		_timer.timeout.disconnect(connection.callable)
	_timer.timeout.connect(callback, CONNECT_ONE_SHOT)
	_timer.start(seconds)


func _respawn() -> void:
	_state = 0
	_sprite.position = Vector2.ZERO
	_atlas.region = Rect2(0, 8, 32, 16)
	_shape.set_deferred("disabled", false)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.2)
