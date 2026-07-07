class_name Checkpoint
extends Area2D
## "COMMIT SAVED ✓" terminal. One-shot green flash on activation; the level's
## RespawnController listens for checkpoint_reached and moves the spawn here.

const SHEET := preload("res://assets/art/props/checkpoint.png")
const FRAME := Vector2i(24, 32)

@export var id: StringName = &""

var activated := false
var _sprite: AnimatedSprite2D


func _ready() -> void:
	if id == &"":
		id = StringName(name)
	collision_layer = PhysicsLayers.TRIGGER
	collision_mask = PhysicsLayers.PLAYER
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames()
	_sprite.play(&"off")
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 32)
	shape.shape = rect
	shape.position = Vector2(0, -16)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if activated or body is not Player:
		return
	activated = true
	_sprite.play(&"on")
	AudioManager.play_sfx("checkpoint")
	EventBus.checkpoint_reached.emit(id)


static var _frames_cache: SpriteFrames


static func _frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"off")
	frames.add_frame(&"off", _at(0))
	frames.add_animation(&"on")
	frames.set_animation_speed(&"on", 4.0)
	frames.set_animation_loop(&"on", true)
	frames.add_frame(&"on", _at(2))
	frames.add_frame(&"on", _at(3))
	_frames_cache = frames
	return frames


static func _at(i: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
	return atlas
