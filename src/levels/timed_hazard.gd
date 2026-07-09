class_name TimedHazard
extends Area2D
## Cycling hazard region (heat vents, laser grids): on for on_time, off for
## off_time. On the HAZARD layer, so the player's polled detector handles
## damage. Telegraphs 0.3s before igniting (reactability rule).

@export var on_time := 1.2
@export var off_time := 1.6
@export var phase_offset := 0.0
@export var beam_color := Color("ff3040")

const TELEGRAPH := 0.3

var _shape: CollisionShape2D
var _visual: ColorRect
var _clock := 0.0


func setup(size_px: Vector2) -> void:
	collision_layer = PhysicsLayers.HAZARD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px * 0.85 # forgiving hitbox inside the visual
	_shape.shape = rect
	_shape.position = size_px / 2.0
	add_child(_shape)
	_visual = ColorRect.new()
	_visual.color = beam_color
	_visual.size = size_px
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_clock = phase_offset


enum Phase { ON, TELEGRAPH, OFF }
var _phase := Phase.OFF


func _physics_process(delta: float) -> void:
	_clock = fmod(_clock + delta, on_time + off_time)
	var active := _clock < on_time
	var telegraphing := not active and (off_time - (_clock - on_time)) < TELEGRAPH
	var phase := Phase.ON if active else (Phase.TELEGRAPH if telegraphing else Phase.OFF)
	if phase == _phase:
		return # edge-triggered: no per-frame set_deferred churn (review P4-25)
	_phase = phase
	_shape.set_deferred("disabled", not active)
	match phase:
		Phase.ON:
			_visual.modulate = Color(1, 1, 1, 0.9)
		Phase.TELEGRAPH:
			_visual.modulate = Color(1, 1, 1, 0.25) # warning shimmer
		Phase.OFF:
			_visual.modulate = Color(1, 1, 1, 0.0)
