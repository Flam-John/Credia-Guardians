extends Control
## BANK SYSTEM SECURED! — the key-art finale (vault door, posed heroes,
## KO'd bankers, flipped-green monitors), then rolling credits.

const CHRIS_SHEET := preload("res://assets/art/characters/chris_sheet.png")
const FLAM_SHEET := preload("res://assets/art/characters/flam_sheet.png")
const GATE_SHEET := preload("res://assets/art/props/exit_gate.png")
const MONITORS := preload("res://assets/art/props/monitors.png")
const JUNIOR := preload("res://assets/art/enemies/junior_banker.png")
const MANAGER := preload("res://assets/art/enemies/angry_manager.png")

const VICTORY_ROW := 13  # hero sheet row (see artgen PLAYER_ANIMS)

var _credits: VBoxContainer
var _done := false
var _props: Array[Control] = []


func _ready() -> void:
	UIKit.fill_background(self)
	AudioManager.play_music("victory")
	_dress_scene()

	# long localized titles (Greek) overflow 480px at size 26 — scale down
	var headline := tr("BANK SYSTEM SECURED!")
	var column := UIKit.menu_column([
		UIKit.title(tr("STAGE CLEAR!"), 14, UIKit.WHITE),
		UIKit.title(headline, 26 if headline.length() <= 22 else 16),
		UIKit.caption(tr("YOU PROTECTED THE FUTURE."), 9, UIKit.CYAN),
		_spacer(96),  # the vault-door tableau shows through here
		UIKit.caption(tr("SYSTEM STATUS: SECURE      FINANCIAL FREEDOM: ACTIVE"),
				8, UIKit.GREEN),
		UIKit.caption(tr("FINAL SCORE %d    HI-SCORE %d") % [
				GameManager.score, GameManager.hi_score], 10, UIKit.GOLD),
		_spacer(8),
		UIKit.caption(tr("PRESS START FOR CREDITS"), 8, UIKit.WHITE),
	])
	add_child(UIKit.center(column))

	_confetti(Vector2(120, 30))
	_confetti(Vector2(360, 30))


## The key-art tableau, behind the text column.
func _dress_scene() -> void:
	# open vault door, core spinning frame, center stage
	_prop(GATE_SHEET, Rect2(64, 0, 64, 64), Vector2(240, 148), 1.5)
	# heroes in victory pose flanking the door (Flam faces inward)
	_prop(CHRIS_SHEET, Rect2(0, VICTORY_ROW * 32, 32, 32), Vector2(172, 160), 2.0)
	_prop(FLAM_SHEET, Rect2(0, VICTORY_ROW * 32, 32, 32), Vector2(308, 160), 2.0, true)
	# monitors flipped to the green frame (region 32,0)
	_prop(MONITORS, Rect2(32, 0, 32, 24), Vector2(70, 96), 1.5)
	_prop(MONITORS, Rect2(32, 0, 32, 24), Vector2(410, 96), 1.5)
	# KO'd bankers scattered on the floor (death rows, last frames)
	_prop(JUNIOR, Rect2(2 * 24, 2 * 24, 24, 24), Vector2(64, 242), 1.6, false, 0.5)
	_prop(MANAGER, Rect2(2 * 32, 4 * 32, 32, 32), Vector2(416, 240), 1.5, true, -0.4)
	_prop(JUNIOR, Rect2(2 * 24, 2 * 24, 24, 24), Vector2(140, 250), 1.4, true, -0.9)
	_prop(MANAGER, Rect2(2 * 32, 4 * 32, 32, 32), Vector2(348, 252), 1.4, false, 0.8)


func _prop(sheet: Texture2D, region: Rect2, center: Vector2, scale_f: float,
		flip := false, rot := 0.0) -> void:
	var rect := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	rect.texture = atlas
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.flip_h = flip
	rect.size = region.size * scale_f
	rect.position = center - rect.size / 2.0
	rect.pivot_offset = rect.size / 2.0
	rect.rotation = rot
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	_props.append(rect)


func _confetti(pos: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.position = pos
	burst.amount = 50
	burst.lifetime = 3.0
	burst.direction = Vector2.DOWN
	burst.spread = 50.0
	burst.gravity = Vector2(0, 90)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 120.0
	var gradient := Gradient.new()
	gradient.set_color(0, UIKit.GREEN)
	gradient.add_point(0.5, UIKit.BLUE)
	gradient.set_color(1, UIKit.GOLD)
	burst.color_ramp = gradient
	add_child(burst)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or _done:
		return
	if _credits == null:
		_roll_credits()
	else:
		_finish()


func _roll_credits() -> void:
	for child in get_children():
		if child is CenterContainer:
			child.queue_free()
	for prop in _props:
		prop.queue_free()
	_props.clear()
	_credits = UIKit.menu_column([
		UIKit.title("CREDIA GUARDIANS", 20),
		_spacer(10),
		UIKit.caption(tr("A FLAMUPIA PRODUCTION"), 9, UIKit.WHITE),
		_spacer(8),
		UIKit.caption(tr("STARRING"), 8, UIKit.GRAY),
		UIKit.caption(tr("CHRIS — THE CREDIA WARRIOR"), 9, UIKit.GREEN),
		UIKit.caption(tr("FLAM — THE CREDIA GUARDIAN"), 9, UIKit.CYAN),
		_spacer(8),
		UIKit.caption(tr("VILLAINS"), 8, UIKit.GRAY),
		UIKit.caption(tr("THE CORRUPTED BANKERS OF CREDIABANK"), 9, UIKit.RED),
		_spacer(8),
		UIKit.caption("MADE WITH GODOT %s" % Engine.get_version_info().string,
				8, UIKit.GRAY),
		_spacer(12),
		UIKit.caption(tr("THANK YOU FOR SECURING THE FUTURE"), 10, UIKit.GOLD),
		_spacer(8),
		UIKit.caption(tr("PRESS START"), 8, UIKit.WHITE),
	])
	add_child(UIKit.center(_credits))


func _finish() -> void:
	_done = true
	GameManager.end_stage()
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn")


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
