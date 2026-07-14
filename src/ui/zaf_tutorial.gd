extends Control
## Zaf — Chris & Flam's boss — materializes out of the system after the
## intro on NEW runs (solo or co-op), walks the rookies through the basics
## (NEXT/SKIP), then dissolves back into code and launches stage 1.

signal finished # tests listen here; the default handler launches stage 1

## Tests inject a spy here instead of a real scene change (same pattern as
## RespawnController.scene_router). Defaults to the real launch.
var stage_launcher: Callable = Callable()

const SHEET := preload("res://assets/art/characters/zaf_sheet.png")
const PORTRAIT := preload("res://assets/art/characters/zaf_portrait.png")
const FRAME := 32
const MATERIALIZE_FRAMES := 6
const TICK := 0.11

enum Phase { ENTER, TALK, LEAVE }

var _pages: Array[String] = []
var _index := 0
var _phase := Phase.ENTER
var _anim := 0
var _launched := false

var _sprite: TextureRect
var _atlas: AtlasTexture
var _panel: Control
var _text: Label
var _sparks: CPUParticles2D


func _ready() -> void:
	UIKit.fill_background(self)
	_pages = [
		tr("ZAF_1"),
		_controls_page(),
		tr("ZAF_3"),
		tr("ZAF_4"),
		tr("ZAF_5"),
	]

	# Zaf, big, left of center — starts on the first materialize frame
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, FRAME, FRAME)
	_sprite = TextureRect.new()
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.size = Vector2(128, 128)
	_sprite.position = Vector2(52, 70)
	add_child(_sprite)

	# cyan code-sparks around the materialization point
	_sparks = CPUParticles2D.new()
	_sparks.position = _sprite.position + _sprite.size / 2.0
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.one_shot = true
	_sparks.explosiveness = 0.8
	_sparks.direction = Vector2.UP
	_sparks.spread = 180.0
	_sparks.initial_velocity_min = 30.0
	_sparks.initial_velocity_max = 90.0
	_sparks.gravity = Vector2(0, 40)
	_sparks.color = Color(0.09, 0.88, 0.88)
	add_child(_sparks)
	_sparks.emitting = true

	_build_panel()
	_panel.visible = false # Zaf materializes first, then talks

	var ticker := Timer.new()
	ticker.wait_time = TICK
	ticker.autostart = true
	ticker.timeout.connect(_tick)
	add_child(ticker)
	AudioManager.play_sfx("ai_teleport")


func _build_panel() -> void:
	var portrait := TextureRect.new()
	var pt := AtlasTexture.new()
	pt.atlas = PORTRAIT
	pt.region = Rect2(0, 0, 48, 48)
	portrait.texture = pt
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.stretch_mode = TextureRect.STRETCH_KEEP
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	header.add_child(portrait)
	header.add_child(UIKit.title("ZAF", 16))

	_text = UIKit.caption(_pages[0], 9, UIKit.WHITE)
	_text.custom_minimum_size = Vector2(210, 64)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 12)
	buttons.add_child(UIKit.button(tr("NEXT ▶"), _on_next))
	buttons.add_child(UIKit.button(tr("SKIP"), _depart))

	var column := UIKit.menu_column([header, _text, buttons])
	var framed := UIKit.framed_panel(column)
	framed.position = Vector2(196, 42)
	_panel = framed
	add_child(_panel)


## Controls page with the CURRENT key bindings (and P2's in co-op).
func _controls_page() -> String:
	var text := tr("ZAF_2") % [
		SettingsApplier.key_label(&"jump"),
		SettingsApplier.key_label(&"attack"),
		SettingsApplier.key_label(&"dash")]
	if GameManager.is_coop():
		text += "\n" + tr("ZAF_2_COOP") % [
			SettingsApplier.p2_key_label(&"jump"),
			SettingsApplier.p2_key_label(&"attack")]
	return text


func _tick() -> void:
	match _phase:
		Phase.ENTER:
			_anim += 1
			if _anim >= MATERIALIZE_FRAMES:
				_phase = Phase.TALK
				_anim = 0
				_panel.visible = true
				UIKit.grab_first_focus(_panel)
			else:
				_atlas.region = Rect2(_anim * FRAME, 0, FRAME, FRAME)
		Phase.TALK:
			# talk loop while a page is up
			_atlas.region = Rect2((_anim % 4) * FRAME, 2 * FRAME, FRAME, FRAME)
			_anim += 1
		Phase.LEAVE:
			_anim -= 1
			if _anim < 0:
				_sprite.visible = false
				_finish()
			else:
				_atlas.region = Rect2(_anim * FRAME, 0, FRAME, FRAME)


func _on_next() -> void:
	_index += 1
	if _index >= _pages.size():
		_depart()
		return
	_text.text = _pages[_index]
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, "modulate:a", 1.0, 0.25)


## Zaf dissolves back into the system (materialize frames reversed).
func _depart() -> void:
	if _phase == Phase.LEAVE:
		return
	_phase = Phase.LEAVE
	_anim = MATERIALIZE_FRAMES - 1
	_panel.visible = false
	_sparks.restart()
	AudioManager.play_sfx("ai_teleport")


func _finish() -> void:
	if _launched:
		return
	_launched = true
	finished.emit()
	if stage_launcher.is_valid():
		stage_launcher.call()
	elif not GameManager.is_stage_running():
		GameManager.launch_stage(1, GameManager.character, GameManager.character2)


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.TALK:
		return
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		_depart()
