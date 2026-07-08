class_name FirewallGate
extends Area2D
## Locked barrier consuming a USB Security Key (docs/GDD.md §8). Touching it
## with a key in inventory opens it permanently for this attempt.

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
	sprite.modulate = Color(1.0, 0.7, 0.4) # amber tint ≠ exit gate
	add_child(sprite)
	# trigger area is WIDER than the solid blocker — a body pressed against
	# the locked gate must still overlap the area or it can never unlock
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 60)
	shape.shape = rect
	shape.position = Vector2(0, -32)
	add_child(shape)
	_blocker = StaticBody2D.new()
	_blocker.collision_layer = PhysicsLayers.WORLD
	var solid := CollisionShape2D.new()
	var solid_rect := RectangleShape2D.new()
	# 96px tall: max double jump is 89px, so the gate CANNOT be hopped
	# (playability audit: a 60px blocker made the USB key skippable)
	solid_rect.size = Vector2(16, 96)
	solid.shape = solid_rect
	solid.position = Vector2(0, -48)
	_blocker.add_child(solid)
	# faint energy column so the extended barrier reads on screen
	var column := ColorRect.new()
	column.color = Color(1.0, 0.6, 0.3, 0.3)
	column.size = Vector2(6, 40)
	column.position = Vector2(-3, -100)
	_blocker.add_child(column)
	add_child(_blocker)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


var _player_inside: Player


## Polled while the player is at the gate: opens the moment they hold a key,
## even if the key was collected while already standing here.
func _physics_process(_delta: float) -> void:
	_try_open()


func _try_open() -> void:
	if open or _player_inside == null or GameManager.usb_keys <= 0:
		return
	GameManager.usb_keys -= 1
	open = true
	_atlas.region = Rect2(48, 0, 48, 64)
	_blocker.queue_free()
	set_physics_process(false)
	set_deferred("monitoring", false)
	AudioManager.play_sfx("gate_open")


func _on_body_entered(body: Node2D) -> void:
	if open or body is not Player:
		return
	_player_inside = body
	set_physics_process(true)
	if GameManager.usb_keys <= 0:
		AudioManager.play_sfx("menu_back") # locked "denied" blip
	_try_open()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		set_physics_process(false)