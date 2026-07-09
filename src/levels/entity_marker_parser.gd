class_name EntityMarkerParser
extends RefCounted
## Parses an ASCII level map's ENTITY MARKERS into a spawn list + pure
## terrain (review P3-16: this lived inside LevelBase where it couldn't be
## unit-tested without booting a stage).
##
## Marker legend (terrain chars pass through untouched):
##   P player spawn      c coin              o coffee        e energy drink
##   J junior banker     M angry manager     A auditor       L loan shark
##   B ai banker         Q ai banker elite   R regional mgr  C ceo boss
##   k checkpoint        N security node     E exit gate     F firewall gate
##   W firewall shield   K keyboard upgrade  U usb key       S security camera
##   X crumbling platform (2 tiles)          m monitor
##   > / < conveyor run          f / g fan run (left/right)
##   = moving platform span      b fading bridge run         l laser run
##   ~ updraft column            V heat vent column          | elevator column
##
## Output spawn dicts: {type: String(marker), x: int, y: int, length: int}
## where length = run width (horizontal runs) or column height (vertical).

const SINGLE_MARKERS := "PcoeJMALBQRCkNEFWKUSm"
const HORIZONTAL_RUNS := "><fg=bl"
const VERTICAL_RUNS := "~V|"

var terrain := ""
var spawns: Array[Dictionary] = []
var spawn_tile := Vector2i(2, 2)
var coin_count := 0
var node_count := 0


func parse(source: String) -> void:
	terrain = ""
	spawns.clear()
	coin_count = 0
	node_count = 0

	var lines := source.split("\n")
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[-1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	var grid: Array = []
	for line in lines:
		grid.append(line)

	for y in grid.size():
		var line: String = grid[y]
		var x := 0
		while x < line.length():
			var ch := line[x]
			var consumed := 1
			if SINGLE_MARKERS.contains(ch):
				if ch == "P":
					spawn_tile = Vector2i(x, y)
				else:
					_add(ch, x, y, 1)
			elif ch == "X":
				_add(ch, x, y, 2)
				consumed = 2
			elif HORIZONTAL_RUNS.contains(ch):
				var run := 1
				while x + run < line.length() and line[x + run] == ch:
					run += 1
				_add(ch, x, y, run)
				consumed = run
			elif VERTICAL_RUNS.contains(ch):
				# only the TOP cell of a column emits; detection reads the
				# ORIGINAL grid, so vertical cells are blanked in a final pass
				if not (y > 0 and x < (grid[y - 1] as String).length() \
						and grid[y - 1][x] == ch):
					var height := 1
					while y + height < grid.size() \
							and x < (grid[y + height] as String).length() \
							and grid[y + height][x] == ch:
						height += 1
					_add(ch, x, y, height)
				x += 1
				continue
			else:
				x += 1
				continue
			# blank consumed marker cells to background panel ("." — matches
			# the shipped visuals; strings are immutable so rebuild)
			var end := mini(x + consumed, line.length())
			line = line.substr(0, x) + ".".repeat(end - x) + line.substr(end)
			grid[y] = line
			x += consumed

	for y in grid.size():
		var cleaned: String = grid[y]
		for ch in VERTICAL_RUNS:
			cleaned = cleaned.replace(ch, " ")
		terrain += cleaned + "\n"


func _add(type: String, x: int, y: int, length: int) -> void:
	spawns.append({"type": type, "x": x, "y": y, "length": length})
	match type:
		"c":
			coin_count += 1
		"N":
			node_count += 1
