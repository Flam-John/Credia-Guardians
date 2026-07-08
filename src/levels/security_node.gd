class_name SecurityNode
extends Area2D
## Stage objective: hold interact for 0.5s inside the field to activate.
## The level counts activations and emits EventBus.node_activated.

signal activated(node: SecurityNode)

const SHEET := preload("res://assets/art/props/security_node.png")
const HOLD_TIME := 0.5

@export var id: StringName = &""

var active := false
var _player_inside: Player
var _hold := 0.0
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _progress: ColorRect


func _ready() -> void:
	if id == &"":
		id = StringName(name)
	collision_layer = PhysicsLayers.TRIGGER
	collision_mask = PhysicsLayers.PLAYER
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, 32, 32)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 32)
	shape.shape = rect
	shape.position = Vector2(0, -16)
	add_child(shape)
	_progress = ColorRect.new()
	_progress.color = Color("16e0e0")
	_progress.position = Vector2(-10, -36)
	_progress.size = Vector2(0, 2)
	add_child(_progress)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if active or _player_inside == null:
		return
	if _player_inside.pressed(&"interact"):
		if _hold == 0.0:
			_atlas.region = Rect2(32, 0, 32, 32) # charging (blue)
			AudioManager.play_sfx("node_hold_loop")
		_hold += delta
		_progress.size.x = 20.0 * minf(1.0, _hold / HOLD_TIME)
		if _hold >= HOLD_TIME:
			_activate()
	elif _hold > 0.0:
		_reset_charge()


func _activate() -> void:
	active = true
	set_physics_process(false)
	_atlas.region = Rect2(64, 0, 32, 32) # on (green)
	_progress.visible = false
	AudioManager.play_sfx("node_activate")
	activated.emit(self)


func _reset_charge() -> void:
	_hold = 0.0
	_progress.size.x = 0.0
	_atlas.region = Rect2(0, 0, 32, 32)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not active:
		_player_inside = body
		set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		if not active:
			_reset_charge()
		set_physics_process(false)
