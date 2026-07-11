class_name Coin
extends Area2D
## Credia Coin. Optionally pops in an arc when spawned as loot before
## becoming collectable at rest.

const SPIN_SHEET := preload("res://assets/art/props/coin.png")
const FRAME := 16
const GRAVITY := 500.0
const RADIUS := 7.0
const BOUNCE_DAMPING := 0.55

@export var value := 100

var _pop_velocity := Vector2.ZERO
var _popping := false


func _ready() -> void:
	collision_layer = PhysicsLayers.COLLECTIBLE
	collision_mask = PhysicsLayers.PLAYER
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _spin_frames()
	sprite.play(&"spin")
	sprite.material = FX.additive()  # Phase 3 glow pass
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# placed coins never tick physics — only loot pops need it (review P4-24:
	# 100 idle coins per stage were burning 6000 empty callbacks/sec)
	set_physics_process(false)


## Loot arc: brief ballistic pop, uncollectable until it slows (prevents
## instant re-collect when an enemy dies on top of the player).
func pop(velocity: Vector2) -> void:
	_pop_velocity = velocity
	_popping = true
	set_physics_process(true)
	# deferred: pop() runs inside the killer hitbox's signal flush
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _physics_process(delta: float) -> void:
	if not _popping:
		return
	_pop_velocity.y += GRAVITY * delta
	var motion := _pop_velocity * delta
	# raycast against the world so pops BOUNCE off walls/floors instead of
	# embedding the coin inside a tile (loot flung sideways by a kill)
	var query := PhysicsRayQueryParameters2D.create(
			global_position, global_position + motion, PhysicsLayers.WORLD)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		position += motion
	else:
		var normal: Vector2 = hit.normal
		global_position = (hit.position as Vector2) + normal * RADIUS
		_pop_velocity = _pop_velocity.bounce(normal) * BOUNCE_DAMPING
		if normal.y < -0.5 and _pop_velocity.length() < 50.0:
			_settle() # came to rest on a floor
			return
	if _pop_velocity.y > 60.0:
		_settle()


func _settle() -> void:
	_popping = false
	set_physics_process(false)
	monitoring = true
	set_deferred("monitorable", true)


var _collected := false


func _on_body_entered(body: Node2D) -> void:
	if body is not Player or _collected:
		return
	_collected = true # same-flush co-op double-collect guard (review P1-9)
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
