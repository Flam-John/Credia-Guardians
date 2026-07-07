class_name DebugOverlay
extends CanvasLayer
## F3 overlay: FPS, player state, velocity. Throttled to 4 Hz so the string
## building never shows up in the profiler. Dev tool — excluded from exports
## by the caller (only debug rooms instance it until M8 wires OS.is_debug_build).

var _label: Label
var _accum := 0.0
var _player: Player


func _ready() -> void:
	layer = 90
	visible = false
	set_process(false) # costs nothing until toggled on (F3)
	_label = Label.new()
	_label.position = Vector2(4, 4)
	_label.add_theme_font_size_override(&"font_size", 8)
	_label.add_theme_color_override(&"font_color", Color("39ff5a"))
	add_child(_label)
	EventBus.player_spawned.connect(_on_player_spawned)


func _on_player_spawned(p: Node2D) -> void:
	_player = p


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		visible = not visible
		set_process(visible)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	var lines := ["FPS %d" % Engine.get_frames_per_second()]
	if is_instance_valid(_player):
		lines.append("state %s" % _player.state_machine.current_name())
		lines.append("vel %.0f, %.0f" % [_player.velocity.x, _player.velocity.y])
		lines.append("pos %.0f, %.0f" % [_player.global_position.x, _player.global_position.y])
		lines.append("air_jumps %d  dash_cd %.2f" % [_player.air_jumps_left, _player.dash_cooldown_timer])
	_label.text = "\n".join(lines)
