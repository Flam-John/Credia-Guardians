class_name ScanlineOverlay
extends CanvasLayer
## Optional CRT scanlines: one generated 480x270 texture on a full-screen
## rect. Toggled by the settings pipeline (EventBus.settings_applied).


func _ready() -> void:
	layer = 95
	visible = false
	var rect := TextureRect.new()
	rect.texture = _build_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	EventBus.settings_applied.connect(_on_settings)


func _on_settings(settings: Dictionary) -> void:
	visible = settings.get("video", {}).get("scanlines", false)


func _build_texture() -> ImageTexture:
	var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 270, 2):
		for x in 480:
			img.set_pixel(x, y, Color(0, 0, 0, 0.15))
	return ImageTexture.create_from_image(img)
