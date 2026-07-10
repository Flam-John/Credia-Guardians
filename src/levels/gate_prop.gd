class_name GateProp
extends Area2D
## Base for lockable gates (exit gate, firewall gate): sprite with
## closed/open atlas frames, a player-sensing trigger, a solid blocker while
## locked, and the open choreography. Subclasses decide WHEN to open
## (review P3-19: the two gates were ~80% copy-paste).

const SHEET := preload("res://assets/art/props/exit_gate.png")

@export var trigger_size := Vector2(32, 60)
@export var blocker_size := Vector2(32, 60)
@export var sprite_tint := Color.WHITE

var open := false
var _atlas: AtlasTexture
var _blocker: StaticBody2D


func _ready() -> void:
	collision_layer = PhysicsLayers.TRIGGER
	collision_mask = PhysicsLayers.PLAYER
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, 48, 64)
	var sprite := Sprite2D.new()
	sprite.texture = _atlas
	sprite.position = Vector2(0, -32)
	sprite.modulate = sprite_tint
	add_child(sprite)
	var trigger := CollisionShape2D.new()
	var trigger_rect := RectangleShape2D.new()
	trigger_rect.size = trigger_size
	trigger.shape = trigger_rect
	trigger.position = Vector2(0, -32)
	add_child(trigger)
	_blocker = StaticBody2D.new()
	_blocker.collision_layer = PhysicsLayers.WORLD
	var solid := CollisionShape2D.new()
	var solid_rect := RectangleShape2D.new()
	solid_rect.size = blocker_size
	solid.shape = solid_rect
	solid.position = Vector2(0, -blocker_size.y / 2.0)
	_blocker.add_child(solid)
	add_child(_blocker)
	body_entered.connect(_on_body_entered)
	_gate_ready()


## Shared open choreography; subclasses call this, never duplicate it.
func open_gate() -> void:
	if open:
		return
	open = true
	_atlas.region = Rect2(48, 0, 48, 64)
	_blocker.queue_free()
	AudioManager.play_sfx("gate_open")
	_gate_opened()


## Subclass hooks.
func _gate_ready() -> void:
	pass


func _gate_opened() -> void:
	pass


func _on_body_entered(_body: Node2D) -> void:
	pass
