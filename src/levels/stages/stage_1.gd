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


## Zaf's in-game ghost intro: only on a fresh new game's very first entry
## into stage 1 (GameManager.pending_zaf_intro, armed by intro_cutscene.gd
## and consumed here) — a later re-entry (retry, replay) must not show it
## again.
func _ready() -> void:
	super._ready()
	if GameManager.pending_zaf_intro:
		GameManager.pending_zaf_intro = false
		var ghost := ZafGhostIntro.new()
		# A step to the right of the player's own spawn point (user request:
		# he should be "stepping in the map" standing next to you, not on
		# top of you) — only stage_1.gd knows where that actually is.
		ghost.world_position = respawner.spawn_point + Vector2(28, 0)
		add_child(ghost)
