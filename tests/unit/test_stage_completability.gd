extends GutTest
## Regression for a real shipped bug: stage 5's CEO-arena pillars were one
## tile taller than every other stage's equivalent wall (96px vs 80px),
## exceeding max jump+double-jump reach and sealing the boss + exit gate
## behind an unclimbable wall. This scans every real stage map for any
## solid column standing between the player's floor row and the exit gate
## that exceeds the CASUAL reachable rise. The bound is the empirically
## measured 64px (4 tiles) any-timing double jump — NOT the analytic
## v^2/2g formula (~84px+), which only holds with an unintuitive
## early-press trick that mandatory paths must never require (that
## formula silently blessed the 80px arena walls fixed alongside this).
## If jump physics are retuned, the live probes in
## test_shelf_reachability / test_updraft_reachability catch the drift.

const CASUAL_REACH_PX := 64.0
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


func test_every_stage_exit_gate_is_reachable() -> void:
	var max_reach := CASUAL_REACH_PX
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


## Regression for a real reported bug: stage 3's USB key sat 25 tiles from
## node 2 on the same isolated shelf (col110 vs col135) — reachable, but a
## player who double-jumps up and beelines for the visible glowing node has
## no reason to backtrack 25 tiles for a key they don't know exists, and
## gets permanently stuck at the firewall gate guarding node 3 with no way
## back to an earlier section. Locks the key within an unmissable distance
## of its shelf-mate node.
func test_stage3_usb_key_sits_beside_its_mandatory_node() -> void:
	var raw := FileAccess.get_file_as_string("res://data/levels/stage_3_map.txt")
	var parser := EntityMarkerParser.new()
	parser.parse(raw)
	var key := _find_type(parser.spawns, "U")
	assert_true(key.has("x"), "stage 3 has a USB key")
	var node := _find_nearest_of_type(parser.spawns, "N", key)
	assert_true(node.has("x"), "stage 3 has a node near the key")
	var tiles_apart: int = absi(key.x - node.x) + absi(key.y - node.y)
	assert_true(tiles_apart <= 5,
			"USB key is %d tiles from its shelf-mate node — too far to guarantee a player collecting the (mandatory) node also sees the key" \
			% tiles_apart)


## Regression for a real shipped bug (v1.13 staircases): new solid terrain
## drawn over a hidden vault's floor-entrance holes sealed the vault (a
## '#' 2 rows above the hole leaves 16px of clearance vs the 24px player
## capsule, and blocks dropping in from above too). Raw map text is used
## on purpose: '.' appears ONLY as vault cells there, while the parser's
## terrain output also blanks consumed markers to '.'.
func test_every_vault_entrance_hole_has_headroom() -> void:
	for path in STAGE_PATHS:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for y in lines.size():
			var line: String = lines[y]
			for x in line.length():
				if line[x] != ".":
					continue
				# An entrance hole is a '.' cut into a '#' floor run. Vault
				# INTERIOR cells border the '@' shell instead, never '#'.
				if not (_char(lines, x - 1, y) == "#" or _char(lines, x + 1, y) == "#"):
					continue
				for dy in [1, 2]:
					assert_false(_solid(lines, x, y - dy),
							"%s: vault entrance hole at col %d row %d is sealed by solid terrain %d row(s) above" \
							% [path, x, y, dy])


## Same bug class, other victim: stage 4's first step was drawn over the
## col-90 checkpoint, leaving 16px of clearance where the 24px capsule
## needs to stand — the checkpoint could never be touched again. Every
## progression marker (checkpoint, node, key, gate) needs a clear tile
## above the one it stands in.
func test_every_progression_marker_has_headroom() -> void:
	for path in STAGE_PATHS:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for y in lines.size():
			var line: String = lines[y]
			for x in line.length():
				if not line[x] in ["k", "N", "U", "E", "F"]:
					continue
				assert_false(_solid(lines, x, y - 1),
						"%s: marker '%s' at col %d row %d has solid terrain directly above — the 24px player capsule cannot stand there to touch it" \
						% [path, line[x], x, y])


## Regression for a real shipped bug (v1.13.x): every '~' steam column in
## stages 1 and 5 topped out DIRECTLY against the underside of the deck it
## was meant to reach — risers bonked the deck forever, the 14px zone plus
## deck overhang made rounding the lip impossible, and stage 5's mandatory
## node + USB key were unreachable (the stage could not be finished). An
## updraft must always have open air above it: the rider needs to clear
## the adjacent deck's lip, so the two cells above the column's topmost
## '~' must be non-solid. Raw map text is used on purpose — the parser
## blanks vertical-run cells out of its terrain output. Coins/markers may
## split a column into several '~' runs (they overwrite single cells), so
## the rule checks the topmost '~' of each column, which is the stack top.
func test_no_updraft_column_is_capped_by_solid_terrain() -> void:
	for path in STAGE_PATHS:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		var checked_cols := {}
		for y in lines.size():
			var line: String = lines[y]
			for x in line.length():
				if line[x] != "~" or checked_cols.has(x):
					continue
				checked_cols[x] = true # first '~' found per column = topmost
				for dy in [1, 2]:
					assert_false(_solid(lines, x, y - dy),
							"%s: updraft column at col %d tops out at row %d but solid terrain sits %d row(s) above — risers get pinned under it" \
							% [path, x, y, dy])


func _char(lines: Array, x: int, y: int) -> String:
	if y < 0 or y >= lines.size():
		return ""
	var line: String = lines[y]
	if x < 0 or x >= line.length():
		return ""
	return line[x]


func _solid(lines: Array, x: int, y: int) -> bool:
	var ch := _char(lines, x, y)
	return ch == "#" or ch == "@"


func _find_gate(spawns: Array[Dictionary]) -> Dictionary:
	return _find_type(spawns, "E")


func _find_type(spawns: Array[Dictionary], type: String) -> Dictionary:
	for spawn in spawns:
		if spawn.type == type:
			return spawn
	return {}


func _find_nearest_of_type(spawns: Array[Dictionary], type: String, to: Dictionary) -> Dictionary:
	var best := {}
	var best_dist := INF
	for spawn in spawns:
		if spawn.type != type:
			continue
		var dist: float = absi(spawn.x - to.x) + absi(spawn.y - to.y)
		if dist < best_dist:
			best_dist = dist
			best = spawn
	return best


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
