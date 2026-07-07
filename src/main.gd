extends Node
## Persistent shell (docs/SCENE_HIERARCHY.md): screens/levels swap inside
## $ScreenRoot; the HUD, pause menu, and scanline overlay live here and
## survive every transition. Boots into the splash screen.

const BOOT_SCENE := "res://scenes/ui/splash.tscn"

var hud: HUD


func _ready() -> void:
	SceneManager.register_screen_root($ScreenRoot)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = HUD.new()
	hud.visible = false
	ui_layer.add_child(hud)

	add_child(PauseMenu.new())
	add_child(ScanlineOverlay.new())

	# settings before the first frame: volumes, window, keybinds, scanlines
	SettingsApplier.apply(
		SettingsApplier.merged_with_defaults(SaveManager.load_settings()), get_window())

	SceneManager.scene_changed.connect(_on_scene_changed)
	SceneManager.change_scene(BOOT_SCENE)


func _on_scene_changed(_path: String) -> void:
	hud.visible = GameManager.is_stage_running()
