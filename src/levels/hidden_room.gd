class_name HiddenRoom
extends Area2D
## Fake-wall cover over a secret area. Player walking in fades the cover,
## scores the discovery, and marks it found (persisted by the level).

signal found(index: int)

@export var index := 0

var discovered := false
var _cover: ColorRect


func setup(rect_px: Rect2) -> void:
	position = rect_px.position
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect_px.size
	shape.shape = box
	shape.position = rect_px.size / 2.0
	add_child(shape)
	_cover = ColorRect.new()
	_cover.color = Color("0a1422")
	_cover.size = rect_px.size
	_cover.z_index = 40 # above entities, below HUD
	add_child(_cover)


func _ready() -> void:
	collision_layer = PhysicsLayers.TRIGGER
	collision_mask = PhysicsLayers.PLAYER
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if discovered or body is not Player:
		return
	discovered = true
	AudioManager.play_sfx("hidden_room")
	var tween := create_tween()
	tween.tween_property(_cover, "modulate:a", 0.0, 0.5)
	found.emit(index)
