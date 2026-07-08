extends LevelBase
## Stage 3 — Corporate HQ. Regenerate map: tools/levelgen/stages_2_4_layout.py


func _init() -> void:
	map = FileAccess.get_file_as_string("res://data/levels/stage_3_map.txt")
	assert(not map.is_empty(), "stage 3 map missing")
	hidden_room_rects = [Rect2(100, 20, 6, 3), Rect2(122, 20, 6, 3)]
