extends Node
## Application entry point and persistent shell (docs/SCENE_HIERARCHY.md).
## Screens/levels swap inside $ScreenRoot; this node survives every
## transition, so M3's HUD and pause menu can live here permanently.
## Until the menu shell lands (M3), boots straight into the movement debug
## room so every build is immediately playable.

const BOOT_SCENE := "res://tests/debug_scenes/combat_room.tscn"


func _ready() -> void:
	SceneManager.register_screen_root($ScreenRoot)
	SceneManager.change_scene(BOOT_SCENE)
