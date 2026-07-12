class_name UIKit
## Shared factory for menu widgets in the CrediaBank palette — every screen
## builds from these so the shell reads as one system. Placeholder-final:
## swapping in themed .tres styles later touches only this file.

const GREEN := Color("39ff5a")
const GREEN_DARK := Color("1fa83c")
const CYAN := Color("16e0e0")
const BLUE := Color("26a8ff")
const GOLD := Color("ffc825")
const RED := Color("ff3040")
const WHITE := Color("e8f4ff")
const GRAY := Color("7a8ca0")
const BG_VOID := Color("050a12")
const BG_PANEL := Color("0a1422")


## Full-rect dark background for a screen root.
static func fill_background(root: Control) -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG_VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	root.add_child(bg)


static func title(text: String, size := 24, color := GREEN) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func caption(text: String, size := 8, color := GRAY) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func button(text: String, on_pressed: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = false
	btn.custom_minimum_size = Vector2(140, 18)
	btn.add_theme_font_size_override(&"font_size", 10)
	btn.add_theme_color_override(&"font_color", WHITE)
	btn.add_theme_color_override(&"font_focus_color", GREEN)
	btn.add_theme_color_override(&"font_hover_color", CYAN)
	btn.add_theme_stylebox_override(&"normal", panel_style(BG_PANEL, Color.TRANSPARENT))
	btn.add_theme_stylebox_override(&"hover", panel_style(BG_PANEL, CYAN))
	btn.add_theme_stylebox_override(&"focus", panel_style(BG_PANEL, GREEN))
	btn.add_theme_stylebox_override(&"pressed", panel_style(GREEN_DARK, GREEN))
	btn.pressed.connect(on_pressed)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("menu_select"))
	btn.focus_entered.connect(func() -> void: AudioManager.play_sfx("menu_move"))
	return btn


static func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_content_margin_all(4)
	return style


## Dark bordered panel around menu content — the key-art "physical UI"
## look shared by the pause menu and the options overlay.
static func framed_panel(content: Control) -> PanelContainer:
	var style := panel_style(Color(0.04, 0.08, 0.13, 0.96), Color(0.12, 0.66, 0.24))
	style.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.add_child(content)
	return panel


## Centered vertical menu; first button grabs focus (keyboard/D-pad ready).
static func menu_column(items: Array[Control]) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 6)
	for item in items:
		vbox.add_child(item)
	return vbox


static func center(node: Control) -> CenterContainer:
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(node)
	return container


static func grab_first_focus(root: Control) -> void:
	var first := root.find_next_valid_focus()
	if first != null:
		first.grab_focus()
