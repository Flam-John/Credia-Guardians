extends GutTest
## Regression for a real shipped bug: stage 5's CEO-arena pillars were one
## tile taller than every other stage's equivalent wall (96px vs 80px),
## exceeding max jump+double-jump reach and sealing the boss + exit gate
## behind an unclimbable wall. This scans every real stage map for any
## solid column standing between the player's floor row and the exit gate
## that exceeds the ACTUAL reachable rise (computed from CharacterStats,
## not a hardcoded guess, so it can't silently drift out of sync with
## physics tuning).

const CHRIS := preload("res://data/characters/chris.tres")
const STAGE_PATHS := [
	"res://data/levels/stage_1_map.txt",
	"res://data/levels/stage_2_map.txt",
	"res://data/levels/stage_3_map.txt",
	"res://data/levels/stage_4_map.txt",
	"res://data/levels/stage_5_map.txt",
]
const T := 16
## How far back from the exit gate to scan for blocking pillars.
const SCAN_WINDOW := 40


## Max additional rise above the jump's start point, chaining a double
## jump at the first jump's exact apex (the worst-case — and best-case —
## a player can do): v^2 / (2*g) per jump, summed.
func _max_reach_px() -> float:
	var g: float = CHRIS.gravity_rise
	return (CHRIS.jump_velocity ** 2) / (2.0 * g) \
			+ (CHRIS.double_jump_velocity ** 2) / (2.0 * g)


func test_every_stage_exit_gate_is_reachable() -> void:
	var max_reach := _max_reach_px()
	assert_gt(max_reach, 0.0, "sanity: jump physics produced a positive reach")
	for path in STAGE_PATHS:
		var raw := FileAccess.get_file_as_string(path)
		assert_false(raw.is_empty(), "%s must be readable" % path)
		var parser := EntityMarkerParser.new()
		parser.parse(raw)
		var gate := _find_gate(parser.spawns)
		assert_true(gate.has("x"), "%s has exactly one exit gate" % path)
		var lines := parser.terrain.split("\n")
		var row: String = lines[gate.y]
		for col in range(maxi(0, gate.x - SCAN_WINDOW), gate.x):
			if col >= row.length() or row[col] != "#":
				continue
			var wall_tiles := _wall_height(lines, gate.y, col)
			var wall_px := wall_tiles * T
			assert_true(wall_px <= max_reach,
					"%s col %d: wall is %dpx tall (max reach %.1fpx) — blocks the path to the exit gate" \
					% [path, col, wall_px, max_reach])


func _find_gate(spawns: Array[Dictionary]) -> Dictionary:
	for spawn in spawns:
		if spawn.type == "E":
			return spawn
	return {}


## Counts contiguous solid rows going UP from `floor_row` at `col` — the
## height the player must clear while standing at floor_row.
func _wall_height(lines: Array, floor_row: int, col: int) -> int:
	var height := 0
	var r := floor_row
	while r >= 0:
		var line: String = lines[r]
		if col >= line.length() or line[col] != "#":
			break
		height += 1
		r -= 1
	return height
