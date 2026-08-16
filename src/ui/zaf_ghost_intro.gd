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
##
## His CHARACTER is a real world-space Sprite2D (user request: he should be
## "stepping in the map" at player size, not a giant screen-space portrait)
## added as a sibling of the player/enemies under the stage, positioned at
## `world_position` (set by stage_1.gd before add_child, since only the
## caller knows where the player actually spawned). Only the dialogue
## TEXT BOX stays a fixed screen-space CanvasLayer panel — a separate
## "dialogue box" area is a normal convention and doesn't need to track
## wherever the camera happens to frame his character on screen.
##
## Bug fix (user report: an enemy kept moving and hit the player while Zaf
## was talking): SceneManager.change_scene() unconditionally sets
## get_tree().paused = false right after instantiating the new scene —
## and stage_1.gd's _ready() (which spawns this node and used to pause
## immediately) runs SYNCHRONOUSLY as part of that very same instantiation,
## meaning the pause was set and then immediately stomped by SceneManager
## a line later, before the fade-in even finished. Gate minigames never hit
## this because they always pause well after any scene transition has
## settled — this is the first thing in the project that pauses DURING one.
## Fixed two ways, matching how MinigameLauncher already defends itself
## twice for the same class of reason: (1) the actual get_tree().paused=true
## is deferred one process_frame, guaranteeing it runs after SceneManager's
## own reset so it actually sticks; (2) belt-and-suspenders, every live
## Player (Player.alive, the same static list MinigameLauncher itself
## reads) and every EnemyBase in the stage gets explicitly frozen
## (set_physics_process(false)) the INSTANT this node exists, independent
## of the global pause flag entirely — closing the gap regardless of any
## timing race, restored in _finish().

signal finished # tests listen here

const SHEET := preload("res://assets/art/characters/zaf_sheet.png")
const PORTRAIT := preload("res://assets/art/characters/zaf_portrait.png")
const FRAME := 32
const MATERIALIZE_FRAMES := 6
const TICK := 0.11
## A hologram tint + translucency (design polish, user request: he should
## read as "a clone/ghost", not a solid character standing there).
const GHOST_MODULATE := Color(0.75, 1.0, 1.0, 0.8)
## Fixed screen position for the dialogue box (see class doc: it no longer
## tracks Zaf's on-screen position, which now depends on the camera).
const PANEL_POS := Vector2(200, 60)

enum Phase { ENTER, TALK, LEAVE }

## Where Zaf's world-space character appears — set by stage_1.gd before
## add_child() to a spot near the player's actual spawn point.
var world_position := Vector2.ZERO

var _pages: Array[String] = []
var _index := 0
var _phase := Phase.ENTER
var _anim := 0
var _finished := false
var _frozen_enemies: Array[EnemyBase] = []

var _root: Control
var _world_holder: Node2D
var _sprite: Sprite2D
var _panel: Control
var _text: Label
var _sparks: CPUParticles2D


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_freeze_gameplay()

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

	_build_world_sprite()
	_build_panel()
	_panel.visible = false # Zaf materializes first, then talks

	var ticker := Timer.new()
	ticker.wait_time = TICK
	ticker.autostart = true
	ticker.timeout.connect(_tick)
	add_child(ticker)
	# ui=true: the tree is genuinely paused (not routed through PauseMenu/
	# EventBus.pause_toggled), and the gameplay sfx pool freezes with it —
	# only the small ALWAYS-mode UI pool keeps playing through a direct
	# get_tree().paused=true. Every gate minigame's own sfx calls already
	# follow this same rule; missing it here would make Zaf's teleport-in/
	# out sound silently never play.
	AudioManager.play_sfx("ai_teleport", true, true)

	# See the class doc comment: SceneManager.change_scene() unconditionally
	# unpauses right after instantiating the new scene, which happens
	# synchronously as part of THIS node's own creation — waiting one frame
	# guarantees this runs after that reset, so it actually sticks.
	await get_tree().process_frame
	get_tree().paused = true


## Explicit, synchronous, independent of the global pause flag entirely —
## see the class doc comment for why relying on get_tree().paused alone
## isn't enough here. Every Player (Player.alive) and every EnemyBase
## currently in the stage stops processing the instant Zaf exists.
func _freeze_gameplay() -> void:
	for player in Player.alive:
		if is_instance_valid(player):
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is EnemyBase:
			child.set_physics_process(false)
			_frozen_enemies.append(child)


func _unfreeze_gameplay() -> void:
	for player in Player.alive:
		if is_instance_valid(player):
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)
	for enemy in _frozen_enemies:
		if is_instance_valid(enemy):
			enemy.set_physics_process(true)
	_frozen_enemies.clear()


## A real world-space character (user request: "stepping in the map", at
## player size — 32x32 native, confirmed to match the player's own
## in-game rendering) instead of a giant screen-space portrait. Added as a
## sibling of the player/enemies under the stage (this node's own parent),
## NOT as a CanvasLayer child, so the camera frames him exactly where he
## actually stands.
func _build_world_sprite() -> void:
	_world_holder = Node2D.new()
	_world_holder.position = world_position
	# Bug fix (user screenshot: cyan blotches frozen on Zaf's head/chest):
	# the tree pauses one frame after this node is built (see the class doc
	# comment), and CPUParticles2D — unlike _sprite, whose frame is just a
	# property set externally by the ALWAYS-mode ticker Timer — simulates
	# its own burst/fade via internal per-frame processing. Under the
	# default PROCESS_MODE_INHERIT that pause freezes the spark burst
	# mid-animation, leaving its last-computed frame stuck on screen for as
	# long as Zaf keeps talking. ALWAYS here lets the 0.7s burst actually
	# finish and fade, same reasoning as Ticket Blitz's bullet-trail-ghost
	# tween-freeze fix earlier this project.
	_world_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().add_child(_world_holder)

	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, FRAME, FRAME)
	_sprite.centered = false
	_sprite.position = Vector2(-FRAME / 2.0, -FRAME)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.modulate = GHOST_MODULATE
	_world_holder.add_child(_sprite)

	# cyan code-sparks around the materialization point
	_sparks = CPUParticles2D.new()
	_sparks.position = Vector2(0, -FRAME / 2.0)
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
	_world_holder.add_child(_sparks)
	_sparks.emitting = true


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
	# each other on a 480px screen)
	var column := UIKit.menu_column([
		header,
		_text,
		UIKit.button(tr("NEXT ▶"), _on_next),
		UIKit.button(tr("SKIP"), _depart),
	])
	var framed := UIKit.framed_panel(column)
	_panel = framed
	_panel.position = PANEL_POS
	_root.add_child(_panel)


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
				_sprite.region_rect = Rect2(_anim * FRAME, 0, FRAME, FRAME)
		Phase.TALK:
			# talk loop while a page is up
			_sprite.region_rect = Rect2((_anim % 4) * FRAME, 2 * FRAME, FRAME, FRAME)
			_anim += 1
		Phase.LEAVE:
			_anim -= 1
			if _anim < 0:
				_sprite.visible = false
				_finish()
			else:
				_sprite.region_rect = Rect2(_anim * FRAME, 0, FRAME, FRAME)


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
	_unfreeze_gameplay()
	if is_instance_valid(_world_holder):
		_world_holder.queue_free()
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
