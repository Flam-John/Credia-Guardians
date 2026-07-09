class_name FadingBridge
extends StaticBody2D
## Coin-block bridge that phases in and out on a cycle (Digital Vault).
## Telegraphs by fading before the collision drops.

@export var solid_time := 1.6
@export var gone_time := 1.2
@export var phase_offset := 0.0
## Reactability rule (GDD): hazard state changes telegraph before they harm.
## Bridges warn slightly longer than lasers (0.4 vs TimedHazard.TELEGRAPH
## 0.3) because a drop is deadlier than a beam — deliberate, not drift.
@export var telegraph := 0.4

var _shape: CollisionShape2D
var _visual: ColorRect
var _clock := 0.0


func setup(tiles_wide: int) -> void:
	collision_layer = PhysicsLayers.PLATFORM_ONEWAY
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tiles_wide * 16, 6)
	_shape.shape = rect
	_shape.position = Vector2(tiles_wide * 8.0, 3)
	_shape.one_way_collision = true
	add_child(_shape)
	_visual = ColorRect.new()
	_visual.color = Color("26a8ff")
	_visual.size = Vector2(tiles_wide * 16, 5)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_clock = phase_offset


enum Phase { SOLID, FADING, GONE }
var _phase := Phase.GONE


func _physics_process(delta: float) -> void:
	_clock = fmod(_clock + delta, solid_time + gone_time)
	var solid := _clock < solid_time
	var fading: bool = solid and (solid_time - _clock) < telegraph
	var phase := (Phase.FADING if fading else Phase.SOLID) if solid else Phase.GONE
	if phase == _phase:
		return # edge-triggered (review P4-25)
	_phase = phase
	_shape.set_deferred("disabled", not solid)
	match phase:
		Phase.SOLID:
			_visual.modulate.a = 1.0
		Phase.FADING:
			_visual.modulate.a = 0.5 # blink = about to drop
		Phase.GONE:
			_visual.modulate.a = 0.12
