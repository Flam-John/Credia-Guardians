extends LevelBase
## Stage 1 — Developer Office. Map text lives in data/levels/stage_1_map.txt
## (regenerate with tools/levelgen/stage_1_layout.py, or hand-edit directly).

const MAP_PATH := "res://data/levels/stage_1_map.txt"


func _init() -> void:
	map = FileAccess.get_file_as_string(MAP_PATH)
	assert(not map.is_empty(), "stage 1 map missing: " + MAP_PATH)
	hidden_room_rects = [
		Rect2(87, 20, 6, 2),   # vault under the floor after the steam shafts
		Rect2(122, 20, 6, 3),  # vault under the office maze
	]
