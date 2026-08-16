extends GutTest
## Server Cooling (Stage 2 gate minigame, docs/GDD.md gate minigames):
## rack heat/overheat math, cool/strike rules, win/lose, co-op cursors.

func after_each() -> void:
	GameManager.character2 = &""
	get_tree().paused = false


func _make() -> ServerCoolingMinigame:
	var m := ServerCoolingMinigame.new()
	add_child_autofree(m)
	return m


# -- layout fit ---------------------------------------------------------------------

## This project has shipped two real screen-overflow bugs before (Code
## Review Rush's Zaf column past the 480px edge; HUD/pause CanvasLayers
## silently never rendering at 0x0) — verify every Control's real position
## + size against the actual 480x270 viewport, same technique used for
## Presentation Pace.
func test_every_control_fits_inside_the_native_screen() -> void:
	var m := _make()
	await wait_process_frames(1) # containers only settle auto-fit size next frame
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


# -- rack visuals (design polish: LEDs + fan) ------------------------------------------

## Sanity check that every rack got its own LED pair + fan tween built —
## this exact bug class (a typed Array declared with the WRONG element
## type, e.g. Array[Label] for what are actually ColorRects) already bit
## Code Review Rush's bug-dots row this same session: Godot's typed-array
## append() silently FAILS (logs an engine error, returns false) rather
## than throwing a script error, so a mistyped array quietly stays empty
## instead of crashing — only a test that actually checks the array's
## size would catch it.
func test_every_rack_gets_its_own_led_pair_and_fan_tween() -> void:
	var m := _make()
	assert_eq(m._rack_leds.size(), ServerCoolingMinigame.RACK_COUNT)
	for leds in m._rack_leds:
		assert_eq(leds.size(), 2, "each rack must have exactly 2 status LEDs")
	assert_eq(m._rack_fan_tweens.size(), ServerCoolingMinigame.RACK_COUNT)


func test_an_active_racks_leds_follow_the_heat_color() -> void:
	var m := _make()
	m._active[0] = true
	m._heat[0] = 90.0 # >= HOT_THRESHOLD
	m._refresh_racks()
	for led in m._rack_leds[0]:
		assert_eq((led as ColorRect).color, UIKit.RED)


func test_an_inactive_racks_leds_stay_dim() -> void:
	var m := _make()
	m._active[0] = false
	m._refresh_racks()
	for led in m._rack_leds[0]:
		assert_eq((led as ColorRect).color, UIKit.GRAY)


func test_the_fan_only_spins_while_the_rack_is_active() -> void:
	var m := _make()
	m._active[0] = true
	m._refresh_racks()
	assert_true(m._rack_fan_tweens[0].is_running(),
			"an active rack's fan tween must be playing, not paused")
	m._active[0] = false
	m._refresh_racks()
	assert_false(m._rack_fan_tweens[0].is_running(),
			"an inactive rack's fan must stop spinning")


# -- heat / overheat math -------------------------------------------------------------

func test_an_active_rack_heats_up_over_time() -> void:
	var m := _make()
	m._active[0] = true
	m._tick_heat(1.0)
	assert_almost_eq(m._heat[0], ServerCoolingMinigame.HEAT_RATE[0], 0.01)


func test_an_inactive_rack_never_heats_up() -> void:
	var m := _make()
	m._active[0] = false
	m._tick_heat(5.0)
	assert_eq(m._heat[0], 0.0)


func test_a_rack_reaching_full_heat_overheats_and_costs_a_strike() -> void:
	var m := _make()
	m._active[2] = true
	m._heat[2] = 99.0
	m._tick_heat(1.0) # HEAT_RATE[0]=12.0, easily crosses 100 from 99
	assert_eq(m._strikes, 1)
	assert_false(m._active[2], "an overheated rack must stop actively heating")
	assert_eq(m._heat[2], ServerCoolingMinigame.OVERHEAT_RESET_HEAT,
			"an overheated rack resets to a baseline instead of staying stuck at 100")


## Regression (review catch): the first implementation set a one-shot
## stylebox override on overheat, but _refresh_racks() runs unconditionally
## every _process tick and recomputed the border from the (already-reset)
## real state on the very next call — clobbering the flash before a single
## frame ever rendered it, making the overheat penalty completely silent
## in play. The fix tracks a real per-rack _flash_timer that _refresh_racks
## itself checks, so it survives being called again.
func test_overheat_flash_survives_a_refresh_instead_of_being_clobbered() -> void:
	var m := _make()
	m._active[0] = true
	m._heat[0] = 99.0
	m._tick_heat(1.0)
	assert_gt(m._flash_timer[0], 0.0, "an overheat must arm the flash timer")
	m._refresh_racks() # a naive one-shot override would already be gone here
	var style: StyleBoxFlat = m._rack_panels[0].get_theme_stylebox(&"panel")
	assert_eq(style.border_color, UIKit.WHITE,
			"the flash must still render after a refresh, not be silently overwritten")


func test_overheat_flash_clears_after_its_duration() -> void:
	var m := _make()
	m._active[0] = true
	m._heat[0] = 99.0
	m._tick_heat(1.0)
	m._flash_timer[0] -= ServerCoolingMinigame.OVERHEAT_FLASH_TIME + 0.01
	m._flash_timer[0] = maxf(0.0, m._flash_timer[0])
	m._refresh_racks()
	var style: StyleBoxFlat = m._rack_panels[0].get_theme_stylebox(&"panel")
	assert_ne(style.border_color, UIKit.WHITE, "the flash must not linger forever")


func test_cooling_an_active_rack_resets_its_heat_and_deactivates_it() -> void:
	var m := _make()
	m._active[1] = true
	m._heat[1] = 62.0
	m._cursors[0] = 1
	m._try_cool(0)
	assert_eq(m._heat[1], 0.0)
	assert_false(m._active[1])


func test_cooling_an_inactive_rack_is_a_no_op() -> void:
	var m := _make()
	m._active[3] = false
	m._heat[3] = 0.0
	m._cursors[0] = 3
	m._try_cool(0)
	assert_eq(m._cool_count, 0, "cooling a rack that isn't heating must not score")


func test_activating_a_rack_never_exceeds_the_waves_max_active_cap() -> void:
	var m := _make()
	for i in ServerCoolingMinigame.RACK_COUNT:
		m._active[i] = true
	var before := m._count_active()
	m._activate_random_rack()
	assert_eq(m._count_active(), before, "the cap must block activation when already at MAX_ACTIVE")


# -- strikes / win / lose -------------------------------------------------------------

func test_three_strikes_ends_the_run_in_a_loss() -> void:
	var m := _make()
	watch_signals(m)
	m._register_strike()
	m._register_strike()
	m._register_strike()
	await wait_seconds(1.1) # _lose()'s own short delay before emitting
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])


func test_a_strike_past_the_loss_threshold_does_not_double_emit_finished() -> void:
	var m := _make()
	watch_signals(m)
	m._register_strike()
	m._register_strike()
	m._register_strike()
	m._register_strike()
	await wait_seconds(1.1)
	assert_signal_emit_count(m, "finished", 1)


func test_surviving_all_waves_wins_with_a_positive_bonus() -> void:
	var m := _make()
	watch_signals(m)
	m._cool_count = 5
	m._advance_wave() # wave 0 -> 1
	m._advance_wave() # wave 1 -> 2
	m._advance_wave() # wave 2 exhausted -> win
	await wait_seconds(1.1)
	assert_signal_emitted(m, "finished")
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0])
	assert_eq(params[1],
			ServerCoolingMinigame.BASE_BONUS + 5 * ServerCoolingMinigame.COOL_BONUS)


func test_ui_cancel_bails_out_with_no_bonus() -> void:
	var m := _make()
	watch_signals(m)
	Input.action_press(&"ui_cancel")
	await wait_process_frames(1)
	Input.action_release(&"ui_cancel")
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])


# -- cursor / co-op -------------------------------------------------------------------

func test_cursor_wraps_left_right_across_the_whole_grid() -> void:
	var m := _make()
	m._cursors[0] = 0
	m._move_cursor(0, -1)
	assert_eq(m._cursors[0], ServerCoolingMinigame.RACK_COUNT - 1, "moving left from rack 0 must wrap to the last rack")


func test_cursor_up_down_toggles_between_the_two_rows_same_column() -> void:
	var m := _make()
	m._cursors[0] = 1 # top row, middle column
	m._move_cursor(0, ServerCoolingMinigame.RACK_COLS)
	assert_eq(m._cursors[0], 4, "moving down must land on the same column, bottom row")
	m._move_cursor(0, -ServerCoolingMinigame.RACK_COLS)
	assert_eq(m._cursors[0], 1, "moving back up must return to the same rack")


func test_coop_gives_each_player_their_own_independent_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make()
	assert_eq(m._active_indices, [1, 2])
	assert_true(m._cursors.has(1) and m._cursors.has(2))
	m._move_cursor(1, 1)
	assert_eq(m._cursors[1], 1, "P1's cursor moved")
	assert_eq(m._cursors[2], 0, "P2's cursor must be untouched by P1's input")


func test_coop_either_player_can_cool_the_rack_under_their_own_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make()
	m._active[5] = true
	m._cursors[2] = 5
	m._try_cool(2)
	assert_eq(m._cool_count, 1, "P2 (index 2) must be able to cool the rack under ITS cursor")
