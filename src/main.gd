extends Node
## Application entry point. Until the menu shell lands (M3), boots straight
## into the movement debug room so every build is immediately playable.

const BOOT_SCENE := "res://tests/debug_scenes/movement_room.tscn"


func _ready() -> void:
	SceneManager.change_scene(BOOT_SCENE)
