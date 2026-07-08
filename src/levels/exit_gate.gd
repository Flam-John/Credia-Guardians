class_name ExitGate
extends Area2D
## Firewall gate at the stage end. Solid + red while locked; opens when the
## level says every security node is active. Entering the open gate clears
## the stage.

signal entered

const SHEET := preload("res://assets/art/props/exit_gate.png")

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
	add_child(sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 60)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)
	# physical blocker while locked
	_blocker = StaticBody2D.new()
	_blocker.collision_layer = PhysicsLayers.WORLD
	var bshape := shape.duplicate()
	_blocker.add_child(bshape)
	add_child(_blocker)
	body_entered.connect(_on_body_entered)


func unlock() -> void:
	if open:
		return
	open = true
	_atlas.region = Rect2(48, 0, 48, 64)
	_blocker.queue_free()
	AudioManager.play_sfx("gate_open")
	_sweep_overlaps()


## A player hugging the locked gate is already inside the area when it opens;
## body_entered won't re-fire, so sweep current overlaps once.
func _sweep_overlaps() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or not monitoring:
		return
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if open and body is Player:
		set_deferred("monitoring", false)
		entered.emit()
