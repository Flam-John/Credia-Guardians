class_name VignetteOverlay
extends CanvasLayer
## Always-on corner darkening (Phase 3) — the key art's framing. Sits just
## below the scanlines layer so both compose over the game and menus.

const TEXTURE := preload("res://assets/art/fx/vignette.png")


func _ready() -> void:
	layer = 94
	var rect := TextureRect.new()
	rect.texture = TEXTURE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	# CanvasLayer children don't stretch with anchors (project gotcha) —
	# explicit size, no anchor preset (mixing both warns)
	rect.size = rect.get_viewport_rect().size
