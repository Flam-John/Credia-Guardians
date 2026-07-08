extends LevelBase
## Stage 2 — Data Center. Regenerate map: tools/levelgen/stages_2_4_layout.py


func _init() -> void:
	map = FileAccess.get_file_as_string("res://data/levels/stage_2_map.txt")
	assert(not map.is_empty(), "stage 2 map missing")
	hidden_room_rects = [Rect2(80, 20, 7, 3)]
