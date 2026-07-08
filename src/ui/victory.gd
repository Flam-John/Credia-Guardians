extends Control
## BANK SYSTEM SECURED! — the key-art finale, then rolling credits.

const PORTRAITS := preload("res://assets/art/characters/portraits.png")

var _credits: VBoxContainer
var _done := false


func _ready() -> void:
	UIKit.fill_background(self)
	AudioManager.play_music("victory")

	var heroes := HBoxContainer.new()
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	heroes.add_theme_constant_override(&"separation", 24)
	for i in 2:
		var portrait := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = PORTRAITS
		atlas.region = Rect2(i * 32, 0, 32, 32)
		portrait.texture = atlas
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heroes.add_child(portrait)

	var column := UIKit.menu_column([
		UIKit.title(tr("STAGE CLEAR!"), 14, UIKit.WHITE),
		UIKit.title(tr("BANK SYSTEM SECURED!"), 26),
		UIKit.caption(tr("YOU PROTECTED THE FUTURE."), 9, UIKit.CYAN),
		_spacer(6),
		heroes,
		_spacer(4),
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
