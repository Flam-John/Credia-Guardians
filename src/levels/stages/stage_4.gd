extends LevelBase
## Stage 4 — Digital Vault. Regenerate map: tools/levelgen/stages_2_4_layout.py


func _init() -> void:
	map = FileAccess.get_file_as_string("res://data/levels/stage_4_map.txt")
	assert(not map.is_empty(), "stage 4 map missing")
	hidden_room_rects = [Rect2(100, 20, 6, 3), Rect2(135, 20, 5, 3)]
