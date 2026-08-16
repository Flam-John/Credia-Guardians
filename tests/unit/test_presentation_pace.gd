extends GutTest
## Presentation Pace (Stage 3 gate minigame, docs/GDD.md gate minigames):
## sweet-spot timing, strike rules (early press / awkward silence / late
## press all cost a strike, same as Ticket Blitz's contract), win/lose.

func after_each() -> void:
	GameManager.character2 = &""
	get_tree().paused = false


func _make() -> PresentationPaceMinigame:
	var m := PresentationPaceMinigame.new()
	add_child_autofree(m)
	return m


# -- layout fit ---------------------------------------------------------------------

## This project has shipped two real screen-overflow bugs before (Code
## Review Rush's Zaf column 68px past the 480px edge; HUD/pause CanvasLayers
## silently never rendering at 0x0) — verify every Control's real position +
## size against the actual 480x270 viewport instead of eyeballing the layout
## numbers, same technique documented for those fixes.
func test_every_control_fits_inside_the_native_screen() -> void:
	var m := _make()
	# PanelContainer/VBoxContainer only settle their auto-fit size on the
	# NEXT frame's layout pass (Container.queue_sort() is deferred, not
	# synchronous) — reading .size in the same frame as add_child would
	# silently read a stale pre-layout value (the same class of gotcha
	# SceneManager works around by yielding a frame before reading .size).
	await wait_process_frames(1)
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


# -- design-polish wiring (audience dots, transition) --------------------------------

## Bug fix (user report, with a screenshot): the dots row used to sit at a
## hand-guessed fixed x=255 that overlapped the tail of "INTEREST: 30%" at
## this font size — measure the label's REAL rendered width instead and
## check the dots always start strictly after it, at the widest possible
## text ("INTEREST: 100%", the longest the label can ever render).
func test_audience_dots_never_overlap_the_interest_label() -> void:
	var m := _make()
	m._interest = 100.0
	m._update_interest_label()
	var font := m._interest_label.get_theme_default_font()
	var text_end := m._interest_label.position.x + font.get_string_size(
			m._interest_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			PresentationPaceMinigame.INTEREST_LABEL_FONT_SIZE).x
	assert_gt(m._audience_row.position.x, text_end,
			"the dots row must start after the interest label's real rendered width")


func test_audience_dots_light_up_proportionally_to_interest() -> void:
	var m := _make()
	assert_eq(m._audience_dots.size(), PresentationPaceMinigame.AUDIENCE_DOT_COUNT)
	m._interest = 100.0
	m._update_interest_label()
	for dot in m._audience_dots:
		assert_ne((dot as ColorRect).color, UIKit.GRAY, "full interest must light every dot")
	m._interest = 0.0
	m._update_interest_label()
	for dot in m._audience_dots:
		assert_eq((dot as ColorRect).color, UIKit.GRAY, "zero interest must light no dots")


## Regression: a first attempt at the slide fade-in deferred the actual
## label refresh into a tween_callback, which reads _slide_index at
## CALLBACK time rather than call time. Calling _resolve_advance()
## repeatedly with no frame in between (exactly what this test itself
## does) left multiple stale queued callbacks that all fired later against
## whatever _slide_index had since become — including past the end of
## SLIDES once the run had already won — an out-of-bounds crash. The fix
## keeps _refresh_slide_labels() synchronous and makes the tween purely
## cosmetic; this test is the actual guard against that regression.
func test_repeated_advances_with_no_frame_between_them_do_not_crash() -> void:
	var m := _make()
	for i in PresentationPaceMinigame.SLIDES.size():
		m._resolve_advance(true)
	await wait_seconds(1.1) # let any queued tweens/timers actually flush
	assert_true(m._won)

func test_every_slide_has_real_content_and_a_valid_window() -> void:
	for slide in PresentationPaceMinigame.SLIDES:
		assert_false(String(slide.title).is_empty())
		assert_false(String(slide.body).is_empty())
		assert_gt(float(slide.duration), 0.0)
		var window: Vector2 = slide.window
		assert_true(window.x < window.y, "window start must precede window end")
		assert_true(window.x >= 0.0 and window.y <= 1.0, "window must be a fraction of the slide")


# -- timing resolution --------------------------------------------------------------

func test_pressing_inside_the_sweet_spot_advances_without_a_strike() -> void:
	var m := _make()
	var window: Vector2 = PresentationPaceMinigame.SLIDES[0].window
	var mid := (window.x + window.y) / 2.0
	assert_true(m._is_on_time(mid, window))
	m._resolve_advance(true)
	assert_eq(m._strikes, 0)
	assert_eq(m._slide_index, 1, "an on-time press must advance to the next slide")


func test_pressing_before_the_window_is_not_on_time() -> void:
	var window: Vector2 = PresentationPaceMinigame.SLIDES[0].window
	var m := _make()
	assert_false(m._is_on_time(window.x - 0.1, window), "a rushed press must not count as on-time")


func test_pressing_after_the_window_is_not_on_time() -> void:
	var window: Vector2 = PresentationPaceMinigame.SLIDES[0].window
	var m := _make()
	assert_false(m._is_on_time(window.y + 0.05, window), "a late press must not count as on-time")


func test_an_early_or_late_press_costs_a_strike_and_still_advances() -> void:
	var m := _make()
	m._resolve_advance(false)
	assert_eq(m._strikes, 1)
	assert_eq(m._slide_index, 1, "a missed press still moves the deck forward")


func test_letting_a_slide_time_out_with_no_press_costs_a_strike() -> void:
	# Regression target: _process must auto-resolve as a miss once progress
	# reaches 1.0 with no press at all ("awkward silence"), not just leave
	# the slide hanging forever.
	var m := _make()
	m._slide_timer = float(PresentationPaceMinigame.SLIDES[0].duration) + 1.0
	m._process(0.0)
	assert_eq(m._strikes, 1)
	assert_eq(m._slide_index, 1)


# -- lose / win ---------------------------------------------------------------------

func test_three_strikes_ends_the_run_in_a_loss() -> void:
	var m := _make()
	watch_signals(m)
	m._resolve_advance(false)
	m._resolve_advance(false)
	m._resolve_advance(false)
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


func test_completing_every_slide_without_losing_wins_with_a_positive_bonus() -> void:
	var m := _make()
	watch_signals(m)
	for i in PresentationPaceMinigame.SLIDES.size():
		m._resolve_advance(true)
	await wait_seconds(1.1)
	assert_signal_emitted(m, "finished")
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0])
	assert_gt(params[1], 0, "a clean run must leave a positive bonus")


func test_two_strikes_still_wins_but_shaves_the_bonus() -> void:
	var m := _make()
	watch_signals(m)
	m._resolve_advance(false)
	m._resolve_advance(false)
	for i in PresentationPaceMinigame.SLIDES.size() - 2:
		m._resolve_advance(true)
	await wait_seconds(1.1)
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0], "two strikes must not fail the run outright")
	assert_eq(params[1],
			PresentationPaceMinigame.BASE_BONUS
			+ (PresentationPaceMinigame.SLIDES.size() - 2) * PresentationPaceMinigame.ON_TIME_BONUS
			- 2 * PresentationPaceMinigame.STRIKE_PENALTY)


# -- co-op / cancel -------------------------------------------------------------------

func test_coop_builds_with_either_players_ability_action_available() -> void:
	GameManager.character2 = &"flam"
	var m := _make()
	assert_true(InputMap.has_action(&"p1_ability"))
	assert_true(InputMap.has_action(&"p2_ability"))


func test_ui_cancel_bails_out_with_no_bonus() -> void:
	var m := _make()
	watch_signals(m)
	Input.action_press(&"ui_cancel")
	await wait_process_frames(1)
	Input.action_release(&"ui_cancel")
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])


func test_pressing_ability_inside_the_window_advances_through_real_process() -> void:
	# One end-to-end confidence pass through the real _process wiring
	# (progress calc + real Input edge detection), not just the directly-
	# testable _resolve_advance seam the tests above exercise.
	var m := _make()
	var window: Vector2 = PresentationPaceMinigame.SLIDES[0].window
	var duration: float = PresentationPaceMinigame.SLIDES[0].duration
	m._slide_timer = duration * (window.x + window.y) / 2.0
	Input.action_press(&"ability")
	await wait_process_frames(1)
	Input.action_release(&"ability")
	assert_eq(m._slide_index, 1)
	assert_eq(m._strikes, 0)
