class_name ZafGhostIntro
extends CanvasLayer
## Zaf — Chris & Flam's boss — materializes as a translucent in-game ghost
## right after stage 1 loads on a fresh new game (user request: "more
## in-game" than the old standalone tutorial scene it replaces), walks the
## rookies through the basics (NEXT/SKIP) while the real stage is visible
## behind him, then dissolves back into code and hands control back to the
## player. Triggered by stage_1.gd consuming GameManager.pending_zaf_intro;
## there is no separate scene to launch afterward — we're already IN the
## stage, we just pause it while he talks (same mechanism MinigameLauncher
## already uses to freeze gameplay under a full-screen overlay) and unpause
## when he's done.

signal finished # tests listen here

const SHEET := preload("res://assets/art/characters/zaf_sheet.png")
const PORTRAIT := preload("res://assets/art/characters/zaf_portrait.png")
const FRAME := 32
const MATERIALIZE_FRAMES := 6
const TICK := 0.11
## A hologram tint + translucency (design polish, user request: he should
## read as "a clone/ghost", not a solid character standing there).
const GHOST_MODULATE := Color(0.75, 1.0, 1.0, 0.8)

enum Phase { ENTER, TALK, LEAVE }

var _pages: Array[String] = []
var _index := 0
var _phase := Phase.ENTER
var _anim := 0
var _finished := false

var _root: Control
var _sprite: TextureRect
var _atlas: AtlasTexture
var _panel: Control
var _text: Label
var _sparks: CPUParticles2D


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Freeze the real stage (player, enemies, everything) while Zaf talks —
	# same mechanism every gate minigame already uses, just without a
	# teleport-out step: he's appearing NEXT TO the player, not taking them
	# somewhere else.
	get_tree().paused = true

	_pages = [
		tr("ZAF_1"),
		_controls_page(),
		tr("ZAF_3"),
		tr("ZAF_4"),
		tr("ZAF_5"),
	]

	# CanvasLayer children never stretch with anchors (project-wide gotcha,
	# see pause_menu.gd) — build our own sized root instead of anchoring;
	# deliberately NO full-screen background ColorRect here (unlike every
	# gate minigame) so the actual stage stays visible behind Zaf.
	_root = Control.new()
	add_child(_root)
	_root.size = _root.get_viewport().get_visible_rect().size

	# Zaf, big, left of center — starts on the first materialize frame,
	# tinted as a translucent hologram rather than solid.
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, FRAME, FRAME)
	_sprite = TextureRect.new()
	_sprite.texture = _atlas
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	_sprite.size = Vector2(128, 128)
	_sprite.position = Vector2(52, 70)
	_sprite.modulate = GHOST_MODULATE
	_root.add_child(_sprite)

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
	_root.add_child(_sparks)
	_sparks.emitting = true

	_build_panel()
	_panel.visible = false # Zaf materializes first, then talks

	var ticker := Timer.new()
	ticker.wait_time = TICK
	ticker.autostart = true
	ticker.timeout.connect(_tick)
	add_child(ticker)
	# ui=true: the tree is genuinely paused above (not routed through
	# PauseMenu/EventBus.pause_toggled), and the gameplay sfx pool freezes
	# with it — only the small ALWAYS-mode UI pool keeps playing through a
	# direct get_tree().paused=true. Every gate minigame's own sfx calls
	# already follow this same rule; missing it here would make Zaf's
	# teleport-in/out sound silently never play.
	AudioManager.play_sfx("ai_teleport", true, true)


func _build_panel() -> void:
	var portrait := TextureRect.new()
	var pt := AtlasTexture.new()
	pt.atlas = PORTRAIT
	pt.region = Rect2(0, 0, 48, 48)
	portrait.texture = pt
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	header.add_child(portrait)
	header.add_child(UIKit.title("ZAF", 16))

	_text = UIKit.caption(_pages[0], 9, UIKit.WHITE)
	_text.custom_minimum_size = Vector2(210, 64)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# stacked, not side-by-side (see the original tutorial's own history:
	# two UIKit.button()s at their standard 140px width don't fit next to
	# each other beside Zaf's portrait on a 480px screen)
	var column := UIKit.menu_column([
		header,
		_text,
		UIKit.button(tr("NEXT ▶"), _on_next),
		UIKit.button(tr("SKIP"), _depart),
	])
	var framed := UIKit.framed_panel(column)
	_panel = framed
	_root.add_child(_panel)
	# center the framed panel in the space to the RIGHT of Zaf, sized
	# after layout so it can never overflow the 480x270 screen regardless
	# of locale (Greek strings run longer than English)
	await get_tree().process_frame
	var right_area_x := _sprite.position.x + _sprite.size.x
	var available := _root.size.x - right_area_x
	framed.position.x = right_area_x + (available - framed.size.x) / 2.0
	framed.position.y = (_root.size.y - framed.size.y) / 2.0


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
	AudioManager.play_sfx("ai_teleport", true, true)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().paused = false
	finished.emit()
	queue_free()


## Polls Input directly (same convention every gate minigame's own
## ui_cancel handling already uses) rather than _unhandled_input() — that
## would need accept_event(), which only exists on Control, not the plain
## Node/CanvasLayer hierarchy this class is part of (a real compile error
## caught while building this: "Function accept_event() not found in base
## self" once this stopped extending Control).
func _process(_delta: float) -> void:
	if _phase != Phase.TALK:
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		_depart()
