class_name HitSpark
extends AnimatedSprite2D
## Pooled one-shot impact flash (assets/art/fx/hit_spark.png, 4 frames).

const SHEET := preload("res://assets/art/fx/hit_spark.png")

static var _frames_cache: SpriteFrames


func _ready() -> void:
	sprite_frames = _build_frames()
	animation_finished.connect(_on_finished)


func burst(at_global: Vector2) -> void:
	global_position = at_global
	visible = true
	play(&"burst")


func _pool_reset() -> void:
	stop()


func _on_finished() -> void:
	visible = false
	var pool: ObjectPool = get_meta(&"pool") if has_meta(&"pool") else null
	if pool != null:
		pool.release(self)
	else:
		queue_free()


static func _build_frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burst")
	frames.set_animation_speed(&"burst", 20.0)
	frames.set_animation_loop(&"burst", false)
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(i * 16, 0, 16, 16)
		frames.add_frame(&"burst", atlas)
	_frames_cache = frames
	return frames
