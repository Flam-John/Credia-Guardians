class_name Coin
extends Area2D
## Credia Coin. Optionally pops in an arc when spawned as loot before
## becoming collectable at rest.

const SPIN_SHEET := preload("res://assets/art/props/coin.png")
const FRAME := 16
const GRAVITY := 500.0

@export var value := 100

var _pop_velocity := Vector2.ZERO
var _popping := false


func _ready() -> void:
	collision_layer = PhysicsLayers.COLLECTIBLE
	collision_mask = PhysicsLayers.PLAYER
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _spin_frames()
	sprite.play(&"spin")
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


## Loot arc: brief ballistic pop, uncollectable until it slows (prevents
## instant re-collect when an enemy dies on top of the player).
func pop(velocity: Vector2) -> void:
	_pop_velocity = velocity
	_popping = true
	monitoring = false
	set_deferred("monitorable", false)


func _physics_process(delta: float) -> void:
	if not _popping:
		return
	_pop_velocity.y += GRAVITY * delta
	position += _pop_velocity * delta
	if _pop_velocity.y > 60.0:
		_popping = false
		monitoring = true
		set_deferred("monitorable", true)


func _on_body_entered(body: Node2D) -> void:
	if body is not Player:
		return
	set_deferred("monitoring", false)
	EventBus.coin_collected.emit(value)
	AudioManager.play_sfx("coin")
	# glint: quick scale+fade, then free
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


static var _frames_cache: SpriteFrames


static func _spin_frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"spin")
	frames.set_animation_speed(&"spin", 10.0)
	frames.set_animation_loop(&"spin", true)
	for i in 6:
		var atlas := AtlasTexture.new()
		atlas.atlas = SPIN_SHEET
		atlas.region = Rect2(i * FRAME, 0, FRAME, FRAME)
		frames.add_frame(&"spin", atlas)
	_frames_cache = frames
	return frames
