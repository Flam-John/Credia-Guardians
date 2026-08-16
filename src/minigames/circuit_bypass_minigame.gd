class_name CircuitBypassMinigame
extends CanvasLayer
## Stage 4 gate minigame (docs/GDD.md gate minigames): a wire-rotation grid
## puzzle. Each board is authored as an ORDERED CHAIN of grid cells (a
## single path from a virtual power source on the west edge to a virtual
## lock on the east edge, one step west of the first cell / one step east
## of the last) — every cell on that chain gets exactly ONE tile, and every
## tile has exactly 2 connection ends (STRAIGHT or CORNER; no branching
## junctions), so "solved" only ever needs a per-tile mask comparison, not
## a general graph search: each path tile's REQUIRED mask (the two
## directions linking it to its chain neighbors) is derived once from the
## authored coordinates, and the puzzle is solved the instant every tile's
## LIVE mask (its base shape rotated by its current orientation) matches
## that required mask. Rotating a straight piece 180° reproduces the same
## mask (a straight piece really is symmetric under a half-turn) — that's
## accepted as solved too, correctly, not a bug: the mask comparison is
## exactly the thing that makes that equivalence automatic instead of
## needing special-casing.
##
## Distinct genre from the other three gates: a spatial logic puzzle under
## a timer, not reflexes/scanning/shooting/pacing. Either co-op player may
## rotate any tile (own cursor per player, same as Code Review Rush/Server
## Cooling) — there's one shared circuit, not per-player content to split.
##
## A board that times out unsolved costs a LIFE (user request) and restarts
## the whole run from board 0 — deliberately DIFFERENT from the other four
## gates' "a failure just advances to the next segment" rule, since a
## puzzle you never finished shouldn't hand you a harder one immediately.
## Any already-earned _score_bonus carries over across a restart (classic
## arcade "keep your score, replay the level" convention) — only the board
## index and per-board tile state reset. MAX_LIVES (3) reached hard-fails
## via finished(false, 0), same contract as ui_cancel: FirewallGate/
## MinigameLauncher already refund the spent key and require exit+re-entry
## to retry. Completing (solving) all BOARD_COUNT boards in one life wins.

signal finished(success: bool, bonus: int)

enum TileType { STRAIGHT, CORNER }

const BIT_N := 1
const BIT_E := 2
const BIT_S := 4
const BIT_W := 8
const DIR_BIT := {"N": BIT_N, "E": BIT_E, "S": BIT_S, "W": BIT_W}
const DIR_VEC := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}
const DIR_OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E"}
const BASE_MASK := {TileType.STRAIGHT: BIT_N | BIT_S, TileType.CORNER: BIT_N | BIT_E}

const MAX_LIVES := 3
const LIFE_LOST_PENALTY := 150
const BASE_BONUS := 900
const BOARD_BONUS := 200

const CELL_SIZE := 40.0
const CELL_GAP := 6.0
const GRID_TOP := 56.0

const CURSOR_COLOR_P1 := UIKit.CYAN
const CURSOR_COLOR_P2 := UIKit.BLUE
const CURSOR_COLOR_BOTH := UIKit.GOLD

const BOARD_COUNT := 3
## Each board is authored as just its chain of grid cells (enters the west
## edge at path[0], exits the east edge at path[-1]) plus a time limit —
## required masks/tile types/scrambled starting rotations are all DERIVED
## from this chain in _start_board(), never hand-authored, so a board can
## never be accidentally unsolvable or mismatched against its own geometry.
const BOARD_SPECS: Array[Dictionary] = [
	{"cols": 3, "rows": 3, "duration": 25.0,
			"path": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0)]},
	{"cols": 4, "rows": 3, "duration": 22.0,
			"path": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2),
					Vector2i(2, 1), Vector2i(3, 1)]},
	{"cols": 5, "rows": 4, "duration": 20.0,
			"path": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 1), Vector2i(2, 1),
					Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 1), Vector2i(4, 1)]},
]

## Tests inject a fixed generator instead of RNG (same seam idea as
## CodeReviewMinigame.rng / TicketBlitzMinigame.rng).
var rng := RandomNumberGenerator.new()

var _board := 0
var _board_timer := 0.0
var _lives_remaining := MAX_LIVES
var _score_bonus := 0
var _won := false
var _lost := false
var _active_indices: Array[int] = [0]
var _cursors: Dictionary = {0: 0}

var _cols := 0
var _rows := 0
var _path: Array[Vector2i] = []
var _tile_index_at: Dictionary = {} # Vector2i -> index into _rotation/_required_mask/_tile_type
var _rotation: Array[int] = []
var _required_mask: Array[int] = []
var _tile_type: Array[int] = []

var _root: Control
var _board_label: Label
var _lives_label: Label
var _timer_label: Label
var _source_label: Label
var _target_label: Label
var _cells: Array[Panel] = []
var _nub_rects: Array[Dictionary] = []


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager.is_coop():
		CoopInput.ensure_actions()
		_active_indices = [1, 2]
	else:
		_active_indices = [0]
	_cursors.clear()
	for pi in _active_indices:
		_cursors[pi] = 0

	# CanvasLayer children never stretch with anchors (project-wide gotcha,
	# see pause_menu.gd) — build the background the same anchor-free way
	# every other gate minigame does instead of UIKit.fill_background().
	_root = Control.new()
	var bg := ColorRect.new()
	bg.color = UIKit.BG_VOID
	_root.add_child(bg)
	add_child(_root)
	_root.size = _root.get_viewport().get_visible_rect().size
	bg.size = _root.size

	_build_ui()
	_start_board(0)


## A sparse, dim dot grid behind everything else (design polish, user
## request: "make it look more like a real minigame") — reads as a faint
## circuit-board texture without needing an actual imported background
## asset. Static: computed once from _root.size (already a direct
## assignment by this point, not a Container-settled value, so no
## settling-frame concern), never touched again by board rebuilds.
func _build_background_texture() -> void:
	var spacing := 40.0
	for gy in int(_root.size.y / spacing):
		for gx in int(_root.size.x / spacing):
			var dot := ColorRect.new()
			dot.color = Color(0.1, 0.35, 0.35, 0.25)
			dot.size = Vector2(2, 2)
			dot.position = Vector2(gx * spacing + 10, gy * spacing + 10)
			_root.add_child(dot)


func _build_ui() -> void:
	_build_background_texture()
	var top := UIKit.title("CIRCUIT BYPASS", 16)
	top.position = Vector2(12, 6)
	_root.add_child(top)

	_board_label = UIKit.caption("", 10, UIKit.GOLD)
	_board_label.position = Vector2(300, 8)
	_root.add_child(_board_label)

	_lives_label = UIKit.caption("LIVES: %d/%d" % [MAX_LIVES, MAX_LIVES], 9, UIKit.RED)
	_lives_label.position = Vector2(12, 22)
	_root.add_child(_lives_label)

	_timer_label = UIKit.caption("", 9, UIKit.GOLD)
	_timer_label.position = Vector2(200, 22)
	_root.add_child(_timer_label)

	var hint := UIKit.caption("ROTATE THE WIRES — CONNECT POWER TO THE LOCK", 8, UIKit.GRAY)
	hint.position = Vector2(70, 248)
	_root.add_child(hint)


## -- board setup ---------------------------------------------------------

func _start_board(index: int) -> void:
	_board = index
	var spec: Dictionary = BOARD_SPECS[index]
	_cols = spec.cols
	_rows = spec.rows
	# A Dictionary value read back is a plain untyped Array, even though the
	# BOARD_SPECS literal itself holds Vector2i elements — assigning it
	# straight into the Array[Vector2i]-typed _path throws at runtime (same
	# class of gotcha as Array.filter()'s untyped return, documented on
	# TicketBlitzMinigame._prune_freed). Rebuild it element-by-element instead.
	_path = []
	for p in (spec.path as Array):
		_path.append(p)
	_board_timer = spec.duration
	_board_label.text = "BOARD %d / %d" % [index + 1, BOARD_COUNT]

	_tile_index_at.clear()
	_rotation = []
	_required_mask = []
	_tile_type = []
	for i in _path.size():
		var pos: Vector2i = _path[i]
		_tile_index_at[pos] = i
		var prev: Vector2i = _path[i - 1] if i > 0 else Vector2i(pos.x - 1, pos.y)
		var next: Vector2i = _path[i + 1] if i < _path.size() - 1 else Vector2i(pos.x + 1, pos.y)
		var dir_to_prev := _direction_between(pos, prev)
		var dir_to_next := _direction_between(pos, next)
		var req_mask: int = DIR_BIT[dir_to_prev] | DIR_BIT[dir_to_next]
		var type: TileType = TileType.STRAIGHT if DIR_OPPOSITE[dir_to_prev] == dir_to_next \
				else TileType.CORNER
		_required_mask.append(req_mask)
		_tile_type.append(type)
		_rotation.append(_scrambled_rotation(type, req_mask))

	for pi in _active_indices:
		_cursors[pi] = 0

	_build_board_ui()


func _direction_between(from: Vector2i, to: Vector2i) -> String:
	var delta := to - from
	for key in DIR_VEC:
		if DIR_VEC[key] == delta:
			return key
	push_error("CircuitBypassMinigame: non-adjacent path step %s -> %s" % [from, to])
	return "N"


## A rotation whose mask does NOT already solve the tile — picked by
## rejection rather than "any index != correct rotation index", because a
## STRAIGHT tile's mask repeats every 2 steps (rotating it 180° gives the
## identical mask): comparing indices would wrongly treat that repeat as
## "different" and could hand out an already-solved starting state.
func _scrambled_rotation(type: TileType, required_mask: int) -> int:
	var r := rng.randi_range(0, 3)
	while _mask_for(type, r) == required_mask:
		r = rng.randi_range(0, 3)
	return r


func _mask_for(type: TileType, rotation: int) -> int:
	return _rotate_mask(BASE_MASK[type], rotation)


## Rotates a 4-bit N/E/S/W mask 90° clockwise per step: a connection that
## pointed N now points E, E->S, S->W, W->N (bit0=N,bit1=E,bit2=S,bit3=W;
## a circular left-shift-by-1 of that 4-bit field does exactly this).
func _rotate_mask(mask: int, steps: int) -> int:
	steps = ((steps % 4) + 4) % 4
	for i in steps:
		mask = ((mask << 1) | (mask >> 3)) & 0xF
	return mask


## -- board UI ------------------------------------------------------------

func _build_board_ui() -> void:
	for c in _cells:
		if is_instance_valid(c):
			c.queue_free()
	_cells.clear()
	# Bug fix: _nub_rects.clear() alone only drops the TRACKING array — the
	# actual nub/core Panel nodes it references stay alive as orphaned
	# children of _root forever, since nothing else ever frees them. Every
	# previous board's wires kept accumulating on screen (most visible after
	# a life-loss restart, since a differently-sized earlier board's leaked
	# wires render scattered outside the new, differently-positioned grid).
	for nubs in _nub_rects:
		for key in nubs:
			var p: Panel = nubs[key]
			if is_instance_valid(p):
				p.queue_free()
	_nub_rects.clear()
	if is_instance_valid(_source_label):
		_source_label.queue_free()
	if is_instance_valid(_target_label):
		_target_label.queue_free()

	var origin_x := (_root.size.x - _cols * (CELL_SIZE + CELL_GAP)) / 2.0
	for row in _rows:
		for col in _cols:
			var pos := Vector2i(col, row)
			var cell_pos := Vector2(origin_x + col * (CELL_SIZE + CELL_GAP),
					GRID_TOP + row * (CELL_SIZE + CELL_GAP))
			var panel := Panel.new()
			panel.position = cell_pos
			panel.size = Vector2(CELL_SIZE, CELL_SIZE)
			_root.add_child(panel)
			_cells.append(panel)

			var nubs: Dictionary = {}
			if _tile_index_at.has(pos):
				nubs = _build_nubs(cell_pos)
			_nub_rects.append(nubs)

	var source_row: float = _path[0].y
	var target_row: float = _path[-1].y
	_source_label = UIKit.caption("PWR", 9, UIKit.GOLD)
	_source_label.position = Vector2(origin_x - 34,
			GRID_TOP + source_row * (CELL_SIZE + CELL_GAP) + CELL_SIZE / 2.0 - 6)
	_root.add_child(_source_label)
	_target_label = UIKit.caption("LOCK", 9, UIKit.CYAN)
	_target_label.position = Vector2(origin_x + _cols * (CELL_SIZE + CELL_GAP) + 4,
			GRID_TOP + target_row * (CELL_SIZE + CELL_GAP) + CELL_SIZE / 2.0 - 6)
	_root.add_child(_target_label)

	_refresh_board()


## A rounded StyleBoxFlat is what actually gives the "pipe" look (design
## polish, user request) — a plain ColorRect can't round its corners at all.
func _pipe_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


## Nubs are siblings of the cell Panel under _root, positioned by absolute
## math from the cell's own position — NOT children of the Panel, which
## would make them Container-style-managed if the cell were ever changed
## to a Container (bar_track in ServerCoolingMinigame hit exactly this
## class of bug: a direct .size/.position write on a Container's child
## gets silently overwritten on the next layout pass).
func _build_nubs(cell_pos: Vector2) -> Dictionary:
	var nubs := {}
	var mid := CELL_SIZE / 2.0
	var specs := {
		"N": [Vector2(mid - 3, -6), Vector2(6, 10)],
		"S": [Vector2(mid - 3, CELL_SIZE - 4), Vector2(6, 10)],
		"E": [Vector2(CELL_SIZE - 4, mid - 3), Vector2(10, 6)],
		"W": [Vector2(-6, mid - 3), Vector2(10, 6)],
	}
	for key in specs:
		var panel := Panel.new()
		panel.position = cell_pos + specs[key][0]
		panel.size = specs[key][1]
		panel.visible = false
		panel.add_theme_stylebox_override(&"panel", _pipe_style(UIKit.CYAN, 3))
		_root.add_child(panel)
		nubs[key] = panel
	var core := Panel.new()
	core.position = cell_pos + Vector2(mid - 6, mid - 6)
	core.size = Vector2(12, 12)
	core.pivot_offset = Vector2(6, 6)
	core.add_theme_stylebox_override(&"panel", _pipe_style(UIKit.CYAN, 6))
	_root.add_child(core)
	nubs["core"] = core
	return nubs


func _refresh_board() -> void:
	for row in _rows:
		for col in _cols:
			var idx := row * _cols + col
			var pos := Vector2i(col, row)
			var here: Array[int] = []
			for pi in _active_indices:
				if _cursors[pi] == idx:
					here.append(pi)
			var border := UIKit.GRAY
			if here.size() > 1:
				border = CURSOR_COLOR_BOTH
			elif here.size() == 1:
				border = CURSOR_COLOR_P2 if here[0] == 2 else CURSOR_COLOR_P1
			var style := UIKit.panel_style(Color(0.04, 0.08, 0.13, 0.9), border)
			style.set_content_margin_all(2)
			_cells[idx].add_theme_stylebox_override(&"panel", style)

			if _tile_index_at.has(pos):
				var ti: int = _tile_index_at[pos]
				var mask := _mask_for(_tile_type[ti], _rotation[ti])
				var solved := mask == _required_mask[ti]
				var color := UIKit.GREEN if solved else UIKit.CYAN
				var nubs: Dictionary = _nub_rects[idx]
				for dir in DIR_BIT:
					var panel: Panel = nubs[dir]
					panel.visible = (mask & DIR_BIT[dir]) != 0
					panel.add_theme_stylebox_override(&"panel", _pipe_style(color, 3))
				(nubs["core"] as Panel).add_theme_stylebox_override(&"panel", _pipe_style(color, 6))


## -- input / gameplay loop -------------------------------------------------

func _process(delta: float) -> void:
	if _won or _lost:
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		finished.emit(false, 0)
		return
	# Solving the last tile of a board can synchronously call _start_board()
	# (mid-frame reset of _cursors/_rotation/_path) or _win() (_won=true,
	# with finished.emit() itself only firing later behind an await) — track
	# whether the board changed under us so nothing else this frame runs
	# against it. Without this: (a) falling through to the timer-expiry
	# check below could call _complete_board(false) a SECOND time in the
	# same frame a solve just called it (true), re-entering _win() with no
	# guard — the exact bug class presentation_pace_minigame.gd's
	# _register_strike() doc comment already documents and guards against;
	# (b) in co-op, a second player's queued input this same frame would
	# otherwise land on a board they haven't even seen yet (fresh reset
	# cursors/rotations from the board that JUST loaded). Returning early
	# defers that input to the next frame instead — a same-frame press
	# silently not registering is far more benign than corrupting the new
	# board's state or double-firing finished.
	var board_before := _board
	for pi in _active_indices:
		if Input.is_action_just_pressed(_action(&"move_left", pi)):
			_move_cursor(pi, -1)
		elif Input.is_action_just_pressed(_action(&"move_right", pi)):
			_move_cursor(pi, 1)
		elif Input.is_action_just_pressed(_action(&"move_up", pi)):
			_move_cursor(pi, -_cols)
		elif Input.is_action_just_pressed(_action(&"move_down", pi)):
			_move_cursor(pi, _cols)
		elif Input.is_action_just_pressed(_action(&"interact", pi)):
			_try_rotate(pi)
		if _won or _lost or _board != board_before:
			return

	_board_timer -= delta
	_timer_label.text = str(int(ceil(_board_timer)))
	if _board_timer <= 0.0:
		_complete_board(false)


func _action(base: StringName, player_index: int) -> StringName:
	return CoopInput.scoped_action(base, player_index)


func _move_cursor(player_index: int, step: int) -> void:
	_cursors[player_index] = posmod(_cursors[player_index] + step, _cols * _rows)
	_refresh_board()
	AudioManager.play_sfx("menu_move", true, true)


func _try_rotate(player_index: int) -> void:
	var idx: int = _cursors[player_index]
	var pos := Vector2i(idx % _cols, idx / _cols)
	if not _tile_index_at.has(pos):
		return
	var ti: int = _tile_index_at[pos]
	_rotation[ti] = (_rotation[ti] + 1) % 4
	AudioManager.play_sfx("menu_select", true, true)
	_bounce_core(idx)
	_refresh_board()
	if _is_board_solved():
		_complete_board(true)


## A quick scale "click" on the tile's own hub (design polish, user
## request) — only the core, not the nubs or the cell panel, so there's no
## risk of a rotated background box visually disagreeing with its own
## (separately positioned, axis-aligned) nub siblings.
func _bounce_core(idx: int) -> void:
	var core := _nub_rects[idx]["core"] as Panel
	core.scale = Vector2(1.4, 1.4)
	create_tween().tween_property(core, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _is_board_solved() -> bool:
	for i in _path.size():
		if _mask_for(_tile_type[i], _rotation[i]) != _required_mask[i]:
			return false
	return true


## Guarded against being called again once the run has already ended
## (review catch, defense in depth on top of _process()'s own same-frame
## guard above): the two outcomes now genuinely diverge instead of sharing
## a single "_board += 1" tail — solving advances forward, failing costs a
## life and restarts from board 0 (user request), so they can't share that
## tail path anymore without failing-then-still-advancing.
func _complete_board(solved: bool) -> void:
	if _won or _lost:
		return
	if solved:
		_score_bonus += BOARD_BONUS
		AudioManager.play_sfx("enemy_death", true, true) # reused "unlock" chime
		_board += 1
		if _board >= BOARD_COUNT:
			_win()
		else:
			_start_board(_board)
	else:
		_lose_a_life()


## A failed board (timed out unsolved) costs a life and restarts the WHOLE
## run from board 0 (user request: "if I fail, start from the beginning")
## — not the old strike-then-advance-to-the-next-board behavior. Any
## _score_bonus already earned this attempt carries over; only the board
## index and per-board tile state reset via _start_board(0). Guarded
## against being called again once the run has already ended, same
## defensive parity as the other four gates' own strike/life-loss guards.
func _lose_a_life() -> void:
	if _won or _lost:
		return
	_lives_remaining -= 1
	_lives_label.text = "LIVES: %d/%d" % [_lives_remaining, MAX_LIVES]
	AudioManager.play_sfx("menu_back", true, true)
	if _lives_remaining <= 0:
		_lose()
	else:
		_start_board(0)


func _win() -> void:
	_won = true
	_board_label.text = "CIRCUIT RESTORED"
	_play_energy_flow()
	_flash_target_label()
	var lives_lost := MAX_LIVES - _lives_remaining
	var bonus := maxi(0, BASE_BONUS + _score_bonus - lives_lost * LIFE_LOST_PENALTY)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, bonus)


## A small pulse travels source -> every path tile's center -> target on
## the winning solve (design polish, user request) — fires only from _win(),
## never from an intermediate board's solve, specifically so it can't get
## caught mid-flight by _start_board()'s grid rebuild the way it would if
## it played on every board (this class of instance still queue_frees
## itself fine even if the CanvasLayer is torn down first, same as any
## other one-shot decorative node in this codebase).
func _play_energy_flow() -> void:
	var origin_x := (_root.size.x - _cols * (CELL_SIZE + CELL_GAP)) / 2.0
	var pulse := Panel.new()
	pulse.size = Vector2(10, 10)
	pulse.add_theme_stylebox_override(&"panel", _pipe_style(UIKit.GREEN, 5))
	_root.add_child(pulse)
	var waypoints: Array[Vector2] = [_source_label.position + Vector2(20, 3)]
	for p in _path:
		waypoints.append(Vector2(
				origin_x + p.x * (CELL_SIZE + CELL_GAP) + CELL_SIZE / 2.0 - 5,
				GRID_TOP + p.y * (CELL_SIZE + CELL_GAP) + CELL_SIZE / 2.0 - 5))
	waypoints.append(_target_label.position)
	pulse.position = waypoints[0]
	var tween := create_tween()
	for i in range(1, waypoints.size()):
		tween.tween_property(pulse, "position", waypoints[i], 0.08)
	tween.tween_callback(pulse.queue_free)


func _flash_target_label() -> void:
	_target_label.add_theme_color_override(&"font_color", UIKit.GREEN)
	_target_label.pivot_offset = _target_label.size / 2.0
	_target_label.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(_target_label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## MAX_LIVES exhausted — a hard fail, same outcome contract as an explicit
## ui_cancel (finished.emit(false, 0)): FirewallGate/MinigameLauncher refund
## the spent key and require a genuine exit+re-entry before another attempt.
func _lose() -> void:
	_lost = true
	_board_label.text = "CIRCUIT FAILED"
	await get_tree().create_timer(0.9).timeout
	finished.emit(false, 0)
