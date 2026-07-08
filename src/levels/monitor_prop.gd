class_name MonitorProp
extends Sprite2D
## Wall monitor: corrupted propaganda (red) until ANY security node
## activates nearby, then flips to positive messaging (green) — the world
## visibly heals as you secure it (key-art beat).

const SHEET := preload("res://assets/art/props/monitors.png")

var _atlas: AtlasTexture
var _flipped := false


func _ready() -> void:
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, 32, 24)
	texture = _atlas
	EventBus.node_activated.connect(_on_node_activated)


func _on_node_activated(_id: StringName, _count: int, _total: int) -> void:
	if _flipped:
		return
	_flipped = true
	# tiny stagger so a bank of monitors ripples instead of snapping
	var delay := absf(global_position.x) * 0.0004
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			_atlas.region = Rect2(32, 0, 32, 24))
