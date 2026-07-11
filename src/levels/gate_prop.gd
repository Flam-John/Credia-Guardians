class_name GateProp
extends Area2D
## Base for lockable gates (exit gate, firewall gate): sprite with
## closed/open atlas frames, a player-sensing trigger, a solid blocker while
## locked, and the open choreography. Subclasses decide WHEN to open
## (review P3-19: the two gates were ~80% copy-paste).

const SHEET := preload("res://assets/art/props/exit_gate.png")
const FRAME := Vector2(64, 64)
const SPIN_FRAMES := 3   # open frames 1..3: yin-yang core rotation
const SPIN_INTERVAL := 0.18

@export var trigger_size := Vector2(32, 60)
@export var blocker_size := Vector2(32, 60)
@export var sprite_tint := Color.WHITE

var open := false
var _atlas: AtlasTexture
var _blocker: StaticBody2D
var _spin_frame := 0


func _ready() -> void:
	collision_layer = PhysicsLayers.TRIGGER
	collision_mask = PhysicsLayers.PLAYER
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(Vector2.ZERO, FRAME)
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
	_atlas.region = Rect2(Vector2(FRAME.x, 0), FRAME)
	_blocker.queue_free()
	AudioManager.play_sfx("gate_open")
	# spin the vault-door core while open (frames 1..3)
	var spin := Timer.new()
	spin.wait_time = SPIN_INTERVAL
	spin.autostart = true
	spin.timeout.connect(_advance_spin)
	add_child(spin)
	_gate_opened()


func _advance_spin() -> void:
	_spin_frame = (_spin_frame + 1) % SPIN_FRAMES
	_atlas.region = Rect2(Vector2(FRAME.x * (1 + _spin_frame), 0), FRAME)


## Subclass hooks.
func _gate_ready() -> void:
	pass


func _gate_opened() -> void:
	pass


func _on_body_entered(_body: Node2D) -> void:
	pass
