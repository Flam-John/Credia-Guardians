extends GutTest
## Gate-minigame wiring (FirewallGate <-> MinigameLauncher) and
## CodeReviewMinigame's own scoring/flag logic (docs/GDD.md gate minigames).

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")


## Positioned far from the gate (which defaults near the origin) so real
## Area2D collision never overlaps it — this test drives _on_body_entered/
## _on_body_exited manually and a stray real overlap would double up
## _players_inside behind its back.
func _spawn_player() -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = CHRIS
	p.position = Vector2(2000, 2000)
	add_child_autofree(p)
	return p


func after_each() -> void:
	# is_active() now reflects _busy, which can be true before _active is
	# even assigned (mid-outbound-fade) — guard the null case explicitly.
	if MinigameLauncher._active != null:
		MinigameLauncher._active.queue_free()
		MinigameLauncher._active = null
	MinigameLauncher._busy = false
	MinigameLauncher._on_result = Callable()
	get_tree().paused = false
	GameManager.usb_keys = 0
	GameManager.character2 = &""


# -- FirewallGate <-> MinigameLauncher wiring ------------------------------------

func test_plain_gate_still_opens_instantly() -> void:
	var gate := FirewallGate.new()
	add_child_autofree(gate)
	await wait_frames(2)
	GameManager.usb_keys = 1
	gate._players_inside = 1
	gate._try_open()
	assert_true(gate.open, "no minigame_id -> unchanged instant-unlock behavior")
	assert_eq(GameManager.usb_keys, 0)


func test_minigame_gate_defers_open_until_the_minigame_finishes() -> void:
	var gate := FirewallGate.new()
	gate.minigame_id = &"code_review"
	add_child_autofree(gate)
	await wait_frames(2)
	GameManager.usb_keys = 1
	gate._players_inside = 1
	gate._try_open()
	assert_eq(GameManager.usb_keys, 0, "key is spent up front, win or lose")
	assert_false(gate.open, "gate stays shut while the minigame is up")
	# GUT's wait_seconds() ticks via the Awaiter node's own _physics_process,
	# which stops the moment get_tree().paused flips true mid-wait (the
	# outbound fade pauses the tree partway through) — wait_physics_frames()
	# counts via the tree's physics_frame SIGNAL instead, which fires
	# regardless of node pause, so it actually survives crossing that
	# boundary.
	await wait_physics_frames(40) # outbound teleport fade
	assert_true(MinigameLauncher.is_active())
	MinigameLauncher._active.finished.emit(true, 250)
	await wait_physics_frames(40) # return teleport fade
	assert_true(gate.open, "success opens the gate")
	assert_false(MinigameLauncher.is_active())


func test_cancelling_the_minigame_refunds_the_key_but_does_not_auto_resume() -> void:
	var gate := FirewallGate.new()
	gate.minigame_id = &"ticket_blitz"
	add_child_autofree(gate)
	await wait_frames(2)
	GameManager.usb_keys = 1
	gate._players_inside = 1
	gate.set_physics_process(true) # mimic what _on_body_entered would have enabled
	gate._try_open()
	# wait_seconds() ticks via the Awaiter's own _physics_process, which
	# stops dead the moment get_tree().paused flips true mid-wait (see the
	# other test above) — wait_physics_frames() survives it. TicketBlitz is a
	# heavier scene than CodeReview (real Area2D ships/tickets processing
	# every tick), so give both waits extra margin.
	await wait_physics_frames(90)
	assert_true(MinigameLauncher.is_active())
	MinigameLauncher._active.finished.emit(false, 0)
	await wait_physics_frames(90)
	assert_false(gate.open)
	assert_eq(GameManager.usb_keys, 1, "bailing out never costs the key")
	# A plain timer used to auto-resume polling after ~1s even if the player
	# never actually left — that's a surprise relaunch with a snooze, not a
	# deliberate retry (review catch). Retrying now genuinely requires
	# leaving the trigger and coming back — see the reentry test below.
	assert_false(gate.is_physics_processing(),
			"must NOT auto-resume — the player never actually left the trigger")


func test_cancelling_does_not_instantly_relaunch_the_minigame() -> void:
	# Regression: a refunded key + a player still standing in the trigger
	# used to make _try_open() fire again the very next physics tick,
	# relaunching the same minigame with no chance to actually step away.
	var gate := FirewallGate.new()
	gate.minigame_id = &"code_review"
	add_child_autofree(gate)
	await wait_frames(2)
	GameManager.usb_keys = 1
	gate._players_inside = 1
	gate.set_physics_process(true)
	gate._try_open()
	await wait_physics_frames(40)
	assert_true(MinigameLauncher.is_active())
	MinigameLauncher._active.finished.emit(false, 0)
	await wait_physics_frames(40)
	assert_false(MinigameLauncher.is_active(),
			"a cancelled minigame must not instantly relaunch itself")
	assert_eq(GameManager.usb_keys, 1)


func test_leaving_and_reentering_after_a_cancel_allows_a_fresh_attempt() -> void:
	var gate := FirewallGate.new()
	gate.minigame_id = &"code_review"
	add_child_autofree(gate)
	await wait_frames(2)
	var player := _spawn_player()
	GameManager.usb_keys = 1
	gate._on_body_entered(player)
	await wait_physics_frames(40)
	assert_true(MinigameLauncher.is_active())
	MinigameLauncher._active.finished.emit(false, 0)
	await wait_physics_frames(40)
	assert_true(gate._awaiting_reentry)
	assert_false(gate.is_physics_processing())
	gate._on_body_exited(player) # the player actually walks away
	assert_false(gate._awaiting_reentry, "a full exit clears the retry gate")
	GameManager.usb_keys = 1 # picked up (or kept) the key while circling back
	gate._on_body_entered(player) # ...and comes back
	# _on_body_entered() itself always re-arms physics_process — but a fresh
	# entry with a key on hand immediately fires _try_open() again, which
	# turns it back off while THIS new attempt resolves (identical to the
	# very first launch above) — physics_processing()==false here is
	# correct, not a leftover of the old bug. is_active() is the real proof
	# that re-entry actually launched a fresh attempt instead of staying
	# stuck refusing forever.
	assert_true(MinigameLauncher.is_active(), "the fresh entry launched a new attempt")
	# Settle the second launch before the test ends — otherwise its still-
	# in-flight outbound fade resumes later and can pause the tree or add
	# its CanvasLayer mid-way through a LATER test.
	await wait_physics_frames(40)
	if MinigameLauncher.is_active():
		MinigameLauncher._active.finished.emit(false, 0)
		await wait_physics_frames(40)


func test_launch_rejects_a_second_launch_during_the_outbound_fade() -> void:
	# Regression: is_active() used to only check "an instance exists", which
	# is false for the whole ~0.35s outbound fade before the instance is
	# actually created — a launch() call landing in that window would
	# clobber the first launch's pending callback instead of being rejected.
	MinigameLauncher.launch(&"code_review", func(_success: bool) -> void: pass)
	assert_true(MinigameLauncher.is_active(),
			"the busy flag must be armed immediately, before the fade even finishes")
	var second_result := {"called": false, "success": null}
	MinigameLauncher.launch(&"ticket_blitz", func(success: bool) -> void:
		second_result.called = true
		second_result.success = success)
	assert_true(second_result.called, "an overlapping launch must be rejected immediately")
	assert_eq(second_result.success, false)
	await wait_physics_frames(40)
	if MinigameLauncher.is_active(): # let the real first launch resolve
		MinigameLauncher._active.finished.emit(false, 0)
		await wait_physics_frames(90)


func test_unknown_minigame_id_calls_back_immediately_with_failure() -> void:
	var called := {"success": null}
	MinigameLauncher.launch(&"does_not_exist", func(success: bool) -> void:
		called.success = success)
	assert_eq(called.success, false)
	assert_false(MinigameLauncher.is_active())


func test_presentation_pace_is_registered_with_the_launcher() -> void:
	assert_true(MinigameLauncher.MINIGAMES.has(&"presentation_pace"))
	assert_eq(MinigameLauncher.MINIGAMES[&"presentation_pace"], PresentationPaceMinigame)


func test_server_cooling_is_registered_with_the_launcher() -> void:
	assert_true(MinigameLauncher.MINIGAMES.has(&"server_cooling"))
	assert_eq(MinigameLauncher.MINIGAMES[&"server_cooling"], ServerCoolingMinigame)


func test_circuit_bypass_is_registered_with_the_launcher() -> void:
	assert_true(MinigameLauncher.MINIGAMES.has(&"circuit_bypass"))
	assert_eq(MinigameLauncher.MINIGAMES[&"circuit_bypass"], CircuitBypassMinigame)


# -- CodeReviewMinigame -----------------------------------------------------------

func _make_code_review() -> CodeReviewMinigame:
	var m := CodeReviewMinigame.new()
	add_child_autofree(m)
	return m


func test_round_plants_exactly_three_bugs_across_ten_lines() -> void:
	var m := _make_code_review()
	assert_eq(m._lines.size(), CodeReviewMinigame.LINE_BANK.size())
	var bug_count := 0
	for line in m._lines:
		if line.is_bug:
			bug_count += 1
	assert_eq(bug_count, CodeReviewMinigame.BUG_COUNT)


func test_flagging_every_bug_wins_with_a_positive_bonus() -> void:
	var m := _make_code_review()
	watch_signals(m)
	for i in m._lines.size():
		if m._lines[i].is_bug:
			m._cursors[0] = i
			m._flag_current(0)
	await wait_seconds(1.1) # _win()'s own short delay before emitting
	assert_signal_emitted(m, "finished")
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0], "all three bugs found -> success")
	assert_gt(params[1], 0, "clean run leaves a positive bonus")


func test_flagging_a_clean_line_counts_as_a_mistake_not_progress() -> void:
	var m := _make_code_review()
	var clean_index := -1
	for i in m._lines.size():
		if not m._lines[i].is_bug:
			clean_index = i
			break
	m._cursors[0] = clean_index
	m._flag_current(0)
	assert_eq(m._found, 0)
	assert_eq(m._mistakes, 1)


func test_reflagging_an_already_found_bug_is_a_no_op() -> void:
	var m := _make_code_review()
	var bug_index := -1
	for i in m._lines.size():
		if m._lines[i].is_bug:
			bug_index = i
			break
	m._cursors[0] = bug_index
	m._flag_current(0)
	assert_eq(m._found, 1)
	m._flag_current(0)
	assert_eq(m._found, 1, "flagging the same solved line twice must not double-count")


func test_coop_gives_each_player_their_own_independent_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make_code_review()
	assert_eq(m._active_indices, [1, 2])
	assert_true(m._cursors.has(1) and m._cursors.has(2),
			"both players must have their own cursor slot")
	m._move_cursor(1, 1)
	assert_eq(m._cursors[1], 1, "P1's cursor moved")
	assert_eq(m._cursors[2], 0, "P2's cursor must be untouched by P1's input")
	m._move_cursor(2, -1)
	assert_eq(m._cursors[2], m._lines.size() - 1, "P2 moves independently, wrapping on its own")
	assert_eq(m._cursors[1], 1, "P1's cursor must be untouched by P2's input")


func test_coop_either_player_can_flag_the_bug_under_their_own_cursor() -> void:
	GameManager.character2 = &"flam"
	var m := _make_code_review()
	var bug_index := -1
	for i in m._lines.size():
		if m._lines[i].is_bug:
			bug_index = i
			break
	m._cursors[2] = bug_index
	m._flag_current(2)
	assert_eq(m._found, 1, "P2 (index 2) must be able to solve a bug under ITS cursor")


func test_ui_cancel_bails_out_with_no_bonus() -> void:
	var m := _make_code_review()
	watch_signals(m)
	Input.action_press(&"ui_cancel")
	await wait_process_frames(1)
	Input.action_release(&"ui_cancel")
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])
