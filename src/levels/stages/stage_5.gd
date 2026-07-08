extends LevelBase
## Stage 5 — Core Banking System. Regenerate: tools/levelgen/stage_5_layout.py


func _init() -> void:
	map = FileAccess.get_file_as_string("res://data/levels/stage_5_map.txt")
	assert(not map.is_empty(), "stage 5 map missing")
	hidden_room_rects = [Rect2(124, 20, 6, 3)]
