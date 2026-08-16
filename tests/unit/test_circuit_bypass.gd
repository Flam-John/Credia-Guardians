extends GutTest
## Circuit Bypass (Stage 4 gate minigame, docs/GDD.md gate minigames):
## bit-rotation math, board derivation/solving, life-loss/restart rules,
## win/lose, co-op cursors.

func after_each() -> void:
	GameManager.character2 = &""
	get_tree().paused = false


func _make() -> CircuitBypassMinigame:
	var m := CircuitBypassMinigame.new()
	add_child_autofree(m)
	return m


# -- layout fit ---------------------------------------------------------------------

## This project has shipped two real screen-overflow bugs before (Code
## Review Rush's Zaf column past the 480px edge; HUD/pause CanvasLayers
## silently never rendering at 0x0) — verify every Control's real position
## + size against the actual 480x270 viewport, same technique used for
## Presentation Pace/Server Cooling. Checked on the LARGEST board (index 2,
## 5x4) since that's the one most likely to overflow.
func test_largest_board_fits_inside_the_native_screen() -> void:
	var m := _make()
	m._start_board(2)
	var vp_size := m._root.get_viewport().get_visible_rect().size
	_assert_fits(m._root, vp_size)


func _assert_fits(node: Node, vp_size: Vector2) -> void:
	if node is Control:
		var c: Control = node
		assert_lte(c.position.x + c.size.x, vp_size.x,
				"%s right edge overflows the %d px screen" % [c, int(vp_size.x)])
		assert_lte(c.position.y + c.size.y, vp_size.y,
				"%s bottom edge overflows the %d px screen" % [c, int(vp_size.y)])
	for child in node.get_children():
		_assert_fits(child, vp_size)


# -- design-polish wiring (pipe nubs, energy flow) -------------------------------------

func test_nub_panels_use_a_rounded_stylebox() -> void:
	var m := _make()
	m._start_board(0)
	var pos: Vector2i = m._path[0]
	var idx := pos.y * m._cols + pos.x
	var core := m._nub_rects[idx]["core"] as Panel
	var style := core.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_not_null(style, "the core hub must have a stylebox (the rounded-pipe look)")
	assert_gt(style.corner_radius_top_left, 0, "the hub must actually be rounded, not a square")


## _play_energy_flow() only runs from _win() (never an intermediate board's
## solve — see its own doc comment on why) and must not error even though it
## reads _source_label/_target_label/_path belonging to whatever board was
## on screen at that exact moment.
func test_energy_flow_plays_without_error_on_win() -> void:
	var m := _make()
	m._board = CircuitBypassMinigame.BOARD_COUNT - 1
	m._start_board(m._board)
	m._play_energy_flow()
	await wait_process_frames(1)
	assert_true(true, "must reach here without a script error")


# -- bit-rotation math ----------------------------------------------------------------

func test_rotating_a_straight_mask_90_degrees_swaps_axis() -> void:
	var m := _make()
	assert_eq(m._rotate_mask(CircuitBypassMinigame.BIT_N | CircuitBypassMinigame.BIT_S, 1),
			CircuitBypassMinigame.BIT_E | CircuitBypassMinigame.BIT_W)


func test_rotating_a_straight_mask_180_degrees_reproduces_itself() -> void:
	# The real reason a straight tile only needs rejection-sampling for its
	# scramble, not an index != correct check (see _scrambled_rotation).
	var m := _make()
	var base := CircuitBypassMinigame.BIT_N | CircuitBypassMinigame.BIT_S
	assert_eq(m._rotate_mask(base, 2), base)


func test_rotating_a_corner_mask_cycles_through_all_four_orientations() -> void:
	var m := _make()
	var base := CircuitBypassMinigame.BIT_N | CircuitBypassMinigame.BIT_E
	var seen := {}
	for r in 4:
		seen[m._rotate_mask(base, r)] = true
	assert_eq(seen.size(), 4, "a corner tile must have 4 visually distinct rotations")


func test_rotate_mask_four_steps_returns_to_the_original() -> void:
	var m := _make()
	var base := CircuitBypassMinigame.BIT_N | CircuitBypassMinigame.BIT_E
	assert_eq(m._rotate_mask(base, 4), base)


# -- board derivation -----------------------------------------------------------------

## Hardening (review catch): _direction_between() falls back to a silent
## "N" + push_error() on a malformed path step — push_error() doesn't halt
## execution and would let a future typo'd BOARD_SPECS path (a diagonal
## jump, a skipped tile, a repeated coordinate) silently derive a WRONG
## required_mask instead of failing loudly, which could make that tile
## mathematically unsolvable by any rotation of its 2-connection shape (a
## soft-lock). This test is the actual guard against ever shipping that:
## every authored path must be a genuine single-step orthogonal walk with
## no repeated cells, checked directly against BOARD_SPECS rather than
## trusting the runtime fallback to catch it.
func test_every_board_path_is_a_valid_non_repeating_orthogonal_walk() -> void:
	for spec in CircuitBypassMinigame.BOARD_SPECS:
		var path: Array = spec.path
		var seen := {}
		for i in path.size():
			var pos: Vector2i = path[i]
			assert_false(seen.has(pos), "path must not revisit %s" % pos)
			seen[pos] = true
			assert_true(pos.x >= 0 and pos.x < int(spec.cols) \
					and pos.y >= 0 and pos.y < int(spec.rows),
					"%s is out of the board's %dx%d bounds" % [pos, spec.cols, spec.rows])
			if i > 0:
				var delta: Vector2i = pos - path[i - 1]
				var is_unit_step := (absi(delta.x) + absi(delta.y)) == 1
				assert_true(is_unit_step,
						"step %s -> %s must be a single-tile orthogonal move" % [path[i - 1], pos])


func test_board_starts_unsolved() -> void:
	# Regression target for _scrambled_rotation: if scrambling ever handed
	# out the solved mask by mistake, a board would open already complete.
	for i in CircuitBypassMinigame.BOARD_SPECS.size():
		var m := _make()
		m._start_board(i)
		assert_false(m._is_board_solved(), "board %d must not start pre-solved" % i)


func test_setting_every_tile_to_its_required_mask_solves_the_board() -> void:
	var m := _make()
	m._start_board(0)
	for i in m._path.size():
		# find whichever rotation reproduces the required mask and set it
		for r in 4:
			if m._mask_for(m._tile_type[i], r) == m._required_mask[i]:
				m._rotation[i] = r
				break
	assert_true(m._is_board_solved())


func test_a_single_wrong_tile_leaves_the_board_unsolved() -> void:
	var m := _make()
	m._start_board(0)
	for i in m._path.size():
		for r in 4:
			if m._mask_for(m._tile_type[i], r) == m._required_mask[i]:
				m._rotation[i] = r
				break
	# now deliberately break tile 0 by turning it once more
	m._rotation[0] = (m._rotation[0] + 1) % 4
	assert_false(m._is_board_solved())


func test_first_and_last_tile_connect_to_the_virtual_source_and_target() -> void:
	# path[0] must have a WEST-open requirement (links back to the source,
	# one step further west) and path[-1] an EAST-open requirement (links
	# on to the lock, one step further east) — this is the contract every
	# authored BOARD_SPECS path silently depends on.
	var m := _make()
	m._start_board(0)
	assert_ne(m._required_mask[0] & CircuitBypassMinigame.BIT_W, 0)
	assert_ne(m._required_mask[m._path.size() - 1] & CircuitBypassMinigame.BIT_E, 0)


# -- rotate / cool-equivalent interaction -----------------------------------------------

func test_rotating_a_non_path_cell_is_a_no_op() -> void:
	var m := _make()
	m._start_board(0) # 3x3 board; (2,2) is not on this board's path
	m._cursors[0] = 2 * 3 + 2
	var lives_before := m._lives_remaining
	m._try_rotate(0)
	assert_eq(m._lives_remaining, lives_before, "rotating empty floor must do nothing")


func test_rotating_the_last_wrong_tile_into_place_completes_the_board() -> void:
	var m := _make()
	m._start_board(0)
	for i in m._path.size():
		for r in 4:
			if m._mask_for(m._tile_type[i], r) == m._required_mask[i]:
				m._rotation[i] = r
				break
	# leave exactly the first tile one turn away from solved
	var wrong_r := (m._rotation[0] + 1) % 4
	m._rotation[0] = wrong_r
	var pos: Vector2i = m._path[0]
	m._cursors[0] = pos.y * m._cols + pos.x
	m._try_rotate(0) # completes the last remaining tile
	assert_eq(m._board, 1, "solving the board must advance to the next one")


# -- lives / restart / win / lose -----------------------------------------------------

## Regression (review catch): _process() used to fall through to its own
## board-timer-expiry check in the SAME frame a solve already completed the
## final board — _complete_board(false) would fire a second time with no
## _won guard, re-entering _win() and double-emitting `finished` (the exact
## bug class presentation_pace_minigame.gd's _register_strike() doc comment
## already documents and guards against). Drives the real _process() input
## path (not the directly-testable _try_rotate()/_complete_board() seam the
## other tests above use) with the board timer already expired, so both
## code paths are genuinely racing within one _process() call.
func test_solving_the_final_board_the_same_tick_it_times_out_does_not_double_emit_finished() -> void:
	var m := _make()
	m._board = CircuitBypassMinigame.BOARD_COUNT - 1
	m._start_board(m._board)
	for i in m._path.size():
		for r in 4:
			if m._mask_for(m._tile_type[i], r) == m._required_mask[i]:
				m._rotation[i] = r
				break
	# leave exactly the first tile one turn away from solved
	m._rotation[0] = (m._rotation[0] + 1) % 4
	var pos: Vector2i = m._path[0]
	m._cursors[0] = pos.y * m._cols + pos.x
	m._board_timer = 0.001 # expires on the very same _process() call
	watch_signals(m)
	Input.action_press(&"interact")
	await wait_process_frames(1)
	Input.action_release(&"interact")
	await wait_seconds(1.1) # _win()'s own short delay before emitting
	assert_signal_emit_count(m, "finished", 1)


## User request: failing a board must cost a life and restart the WHOLE run
## from board 0, not just advance to the next (harder) board.
func test_timing_out_a_board_costs_a_life_and_restarts_from_board_zero() -> void:
	var m := _make()
	m._start_board(1) # start mid-run so the restart is actually observable
	m._complete_board(false)
	assert_eq(m._lives_remaining, CircuitBypassMinigame.MAX_LIVES - 1)
	assert_eq(m._board, 0, "a failed board must restart from the beginning, not advance")


func test_three_lost_lives_ends_the_run_in_a_loss() -> void:
	var m := _make()
	watch_signals(m)
	m._lose_a_life()
	m._lose_a_life()
	m._lose_a_life()
	await wait_seconds(1.1) # _lose()'s own short delay before emitting
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])


func test_a_life_lost_past_the_loss_threshold_does_not_double_emit_finished() -> void:
	var m := _make()
	watch_signals(m)
	m._lose_a_life()
	m._lose_a_life()
	m._lose_a_life()
	m._lose_a_life()
	await wait_seconds(1.1)
	assert_signal_emit_count(m, "finished", 1)


func test_completing_all_boards_in_one_life_wins_with_a_positive_bonus() -> void:
	var m := _make()
	watch_signals(m)
	m._complete_board(true) # board 0 -> 1
	m._complete_board(true) # board 1 -> 2
	m._complete_board(true) # board 2 solved -> win
	await wait_seconds(1.1)
	assert_signal_emitted(m, "finished")
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0])
	assert_eq(params[1],
			CircuitBypassMinigame.BASE_BONUS + 3 * CircuitBypassMinigame.BOARD_BONUS,
			"no lives lost -> no LIFE_LOST_PENALTY deduction")


func test_surviving_a_lost_life_still_wins_but_shaves_the_bonus() -> void:
	var m := _make()
	watch_signals(m)
	m._start_board(1)
	m._complete_board(false) # restarts from board 0, 1 life down
	m._complete_board(true) # board 0 -> 1
	m._complete_board(true) # board 1 -> 2
	m._complete_board(true) # board 2 solved -> win
	await wait_seconds(1.1)
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0], "one lost life must not fail the run outright")
	assert_eq(params[1],
			CircuitBypassMinigame.BASE_BONUS + 3 * CircuitBypassMinigame.BOARD_BONUS
			- CircuitBypassMinigame.LIFE_LOST_PENALTY)


func test_ui_cancel_bails_out_with_no_bonus() -> void:
	var m := _make()
	watch_signals(m)
	Input.action_press(&"ui_cancel")
	await wait_process_frames(1)
	Input.action_release(&"ui_cancel")
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])


# -- cursor / co-op -------------------------------------------------------------------

func test_cursor_wraps_left_right_across_the_whole_board() -> void:
	var m := _make()
	m._start_board(0) # 3x3 = 9 cells
	m._cursors[0] = 0
	m._move_cursor(0, -1)
	assert_eq(m._cursors[0], 8, "moving left from cell 0 must wrap to the last cell")


func test_cursor_up_down_toggles_rows_same_column() -> void:
	var m := _make()
	m._start_board(0) # 3 cols
	m._cursors[0] = 1
	m._move_cursor(0, 3)
	assert_eq(m._cursors[0], 4, "moving down must land on the same column, next row")
	m._move_cursor(0, -3)
	assert_eq(m._cursors[0], 1)


func test_coop_gives_each_player_their_own_independent_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make()
	assert_eq(m._active_indices, [1, 2])
	assert_true(m._cursors.has(1) and m._cursors.has(2))
	m._move_cursor(1, 1)
	assert_eq(m._cursors[1], 1, "P1's cursor moved")
	assert_eq(m._cursors[2], 0, "P2's cursor must be untouched by P1's input")


func test_coop_either_player_can_rotate_the_tile_under_their_own_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make()
	m._start_board(0)
	var pos: Vector2i = m._path[0]
	m._cursors[2] = pos.y * m._cols + pos.x
	var before := m._rotation[0]
	m._try_rotate(2)
	assert_eq(m._rotation[0], (before + 1) % 4, "P2 (index 2) must be able to rotate the tile under ITS cursor")
