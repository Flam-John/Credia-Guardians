extends Node2D
## Boss Rush: AI Banker MK-II → Regional Manager → The Chairman, back to
## back in one arena, against the clock. Best-time bragging rights.

const BOSSES := [
	"res://scenes/entities/enemies/ai_banker_elite.tscn",
	"res://scenes/entities/enemies/regional_manager.tscn",
	"res://scenes/entities/bosses/ceo_boss.tscn",
]

const ARENA := """
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@..................................@
@##################################@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
"""

var _respawner: RespawnController
var _wave := 0
var _boss: Node
var _clock := 0.0
var _running := true
var _label: Label


func _ready() -> void:
	var builder := AsciiRoomBuilder.new()
	builder.map = ARENA
	add_child(builder)
	add_child(DebugOverlay.new())
	add_to_group(&"level_root")
	add_child(LevelServices.new()) # shared pools/FX — no more drifted copy

	# Direct F6 boot support: the menu flow arrives via launch_custom (which
	# already ran start_stage and registered this scene for retry).
	if not GameManager.is_stage_running():
		GameManager.character2 = &""
		GameManager.current_scene_path = "res://scenes/ui/boss_rush.tscn"
		GameManager.start_stage(0, GameManager.character)
	_respawner = RespawnController.new()
	_respawner.spawn_point = Vector2(4 * 16, 10 * 16)
	_respawner.camera_limits = Rect2(Vector2.ZERO, builder.room_size)
	add_child(_respawner)
	_respawner.spawn(GameManager.character_stats())

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(200, 4)
	_label.add_theme_font_size_override(&"font_size", 10)
	_label.add_theme_color_override(&"font_color", Color("ffc825"))
	layer.add_child(_label)

	_next_wave()


func _process(delta: float) -> void:
	if _running and not get_tree().paused:
		_clock += delta
	_label.text = tr("WAVE %d/3   %d:%02d.%d") % [
		mini(_wave, 3), int(_clock) / 60, int(_clock) % 60, int(_clock * 10) % 10]


func _next_wave() -> void:
	if _wave >= BOSSES.size():
		_finish()
		return
	var scene: PackedScene = load(BOSSES[_wave])
	_wave += 1
	_boss = scene.instantiate()
	_boss.position = Vector2(26 * 16, 10 * 16)
	add_child(_boss)
	_boss.tree_exited.connect(_on_boss_gone, CONNECT_ONE_SHOT)
	AudioManager.play_sfx("node_activate")


func _on_boss_gone() -> void:
	if not is_inside_tree() or not _running:
		return
	# heal-up beat between waves
	if is_instance_valid(_respawner.player):
		_respawner.player.heal(2)
	get_tree().create_timer(1.5, false).timeout.connect(_next_wave, CONNECT_ONE_SHOT)


func _finish() -> void:
	_running = false
	GameManager.end_stage()
	AudioManager.play_music("victory")
	_label.text = tr("RUSH COMPLETE!   %d:%02d.%d   PRESS START") % [
		int(_clock) / 60, int(_clock) % 60, int(_clock * 10) % 10]


func _unhandled_input(event: InputEvent) -> void:
	if not _running and event.is_pressed():
		GameManager.quit_to_menu()
