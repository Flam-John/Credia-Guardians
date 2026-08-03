extends GutTest
## Ticket Blitz (Stage 5 gate minigame, docs/GDD.md gate minigames): ticket
## HP/tiers, bullet collision, ship contact rules, and wave progression.

const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")


func after_each() -> void:
	GameManager.character2 = &""


# -- TicketBlitzTicket --------------------------------------------------------------

func _make_ticket(tier: int, zigzag := false) -> TicketBlitzTicket:
	var t := TicketBlitzTicket.new()
	add_child_autofree(t)
	t.setup(tier, "TEST TICKET", Vector2(100, 0), zigzag)
	t.bottom_y = 300.0
	return t


func test_low_tier_ticket_dies_in_one_hit() -> void:
	var t := _make_ticket(TicketBlitzTicket.Tier.LOW)
	watch_signals(t)
	t.hit(1)
	assert_signal_emitted_with_parameters(t, "died", [t, 50])


func test_high_tier_ticket_survives_one_hit_and_dies_on_the_second() -> void:
	var t := _make_ticket(TicketBlitzTicket.Tier.HIGH)
	watch_signals(t)
	t.hit(1)
	assert_signal_not_emitted(t, "died")
	assert_eq(t.hp, 1)
	t.hit(1)
	assert_signal_emitted(t, "died")


func test_two_simultaneous_hits_only_kill_the_ticket_once() -> void:
	# Regression: queue_free() only defers deletion to end-of-frame, so two
	# bullets landing on the same 1-HP ticket in the same tick (routine with
	# two co-op ships, or rapid fire) both used to see hp<=0 and each fire
	# `died`, double-counting score and double-decrementing wave alive-count.
	var t := _make_ticket(TicketBlitzTicket.Tier.LOW)
	watch_signals(t)
	t.hit(1)
	t.hit(1)
	assert_signal_emit_count(t, "died", 1)


func test_invulnerable_boss_ignores_hits() -> void:
	var t := _make_ticket(TicketBlitzTicket.Tier.HIGH)
	t.make_boss(Rect2(0, 0, 400, 200))
	t.invulnerable = true
	var hp_before := t.hp
	watch_signals(t)
	t.hit(99)
	assert_eq(t.hp, hp_before, "an invulnerable window must no-op hit()")
	assert_signal_not_emitted(t, "died")


func test_ticket_past_the_bottom_line_reports_and_frees_itself() -> void:
	var t := _make_ticket(TicketBlitzTicket.Tier.LOW)
	watch_signals(t)
	t.global_position.y = t.bottom_y + 1.0
	t._physics_process(0.0)
	assert_signal_emitted_with_parameters(t, "reached_bottom", [t])
	assert_true(t.is_queued_for_deletion())


# -- TicketBlitzBullet ---------------------------------------------------------------

func test_bullet_damages_the_ticket_it_touches_and_despawns() -> void:
	var ticket := _make_ticket(TicketBlitzTicket.Tier.LOW)
	var bullet := TicketBlitzBullet.new()
	add_child_autofree(bullet)
	bullet.launch(Vector2.ZERO, Vector2(0, -200), 1, Color.CYAN, Rect2(-500, -500, 1000, 1000))
	watch_signals(ticket)
	bullet._on_area_entered(ticket)
	assert_signal_emitted(ticket, "died")
	assert_true(bullet.is_queued_for_deletion())


func test_bullet_outside_bounds_despawns() -> void:
	var bullet := TicketBlitzBullet.new()
	add_child_autofree(bullet)
	bullet.launch(Vector2.ZERO, Vector2.ZERO, 1, Color.CYAN, Rect2(0, 0, 10, 10))
	bullet.global_position = Vector2(9999, 9999)
	bullet._physics_process(0.0)
	assert_true(bullet.is_queued_for_deletion())


# -- TicketBlitzShip -----------------------------------------------------------------

func _make_ship(player_index := 0, stats := CHRIS) -> TicketBlitzShip:
	var ship := TicketBlitzShip.new()
	add_child_autofree(ship)
	ship.setup(player_index, stats, Rect2(0, 0, 480, 270))
	return ship


func test_firing_emits_the_characters_own_weapon_look() -> void:
	var ship := _make_ship(0, CHRIS)
	watch_signals(ship)
	ship._fire()
	assert_signal_emitted(ship, "fire_requested")
	var params: Array = get_signal_parameters(ship, "fire_requested")
	assert_eq(params[1], CHRIS.weapon_color)
	assert_eq(params[2], CHRIS.bullet_speed)
	assert_gt(ship._cooldown, 0.0, "firing must start the anti-spam cooldown")


func test_high_tier_ticket_contact_costs_a_strike() -> void:
	var ship := _make_ship()
	var ticket := _make_ticket(TicketBlitzTicket.Tier.HIGH)
	watch_signals(ship)
	ship._on_area_entered(ticket)
	assert_signal_emitted(ship, "hit_by_ticket")


func test_low_tier_ticket_contact_is_forgiven() -> void:
	var ship := _make_ship()
	var ticket := _make_ticket(TicketBlitzTicket.Tier.LOW)
	watch_signals(ship)
	ship._on_area_entered(ticket)
	assert_signal_not_emitted(ship, "hit_by_ticket",
			"low-tier tickets brushing the ship must not punish the player")


func test_contact_invulnerability_blocks_a_second_immediate_hit() -> void:
	var ship := _make_ship()
	var ticket := _make_ticket(TicketBlitzTicket.Tier.HIGH)
	ship._on_area_entered(ticket)
	watch_signals(ship)
	ship._on_area_entered(ticket) # same frame, still within the i-frame window
	assert_signal_not_emitted(ship, "hit_by_ticket")


# -- TicketBlitzMinigame wave data ----------------------------------------------------

func test_wave_zero_is_six_low_tier_tickets() -> void:
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	var specs := m._wave_specs(0)
	assert_eq(specs.size(), 6)
	for spec in specs:
		assert_eq(spec.tier, TicketBlitzTicket.Tier.LOW)


func test_final_wave_mixes_medium_and_dangerous_tickets() -> void:
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	var specs := m._wave_specs(2)
	var high_count := 0
	for spec in specs:
		if spec.tier == TicketBlitzTicket.Tier.HIGH:
			high_count += 1
	assert_eq(specs.size(), 7)
	assert_eq(high_count, 4, "the dangerous T24-style tickets belong to the last wave")


func test_clearing_all_waves_starts_the_boss() -> void:
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	m._spawn_queue.clear()
	m._alive_count = 0
	m._advance_wave() # wave 0 -> 1
	m._spawn_queue.clear()
	m._alive_count = 0
	m._advance_wave() # wave 1 -> 2
	m._spawn_queue.clear()
	m._alive_count = 0
	m._advance_wave() # wave 2 exhausted -> boss
	assert_true(m._boss_active)


func test_winning_emits_finished_with_strikes_reducing_the_bonus() -> void:
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	m._strikes = 2
	watch_signals(m)
	m._on_boss_died(null, 1000)
	await wait_seconds(1.1)
	assert_signal_emitted(m, "finished")
	var params: Array = get_signal_parameters(m, "finished")
	assert_true(params[0])
	assert_eq(params[1], 1000 - 2 * TicketBlitzMinigame.STRIKE_PENALTY)


func test_coop_builds_two_ships_with_correct_per_player_stats() -> void:
	GameManager.character2 = &"flam"
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	var by_index := {}
	for child in m._root.get_children():
		if child is TicketBlitzShip:
			by_index[child.player_index] = child
	assert_eq(by_index.size(), 2, "co-op must build one ship per player")
	assert_true(by_index.has(1) and by_index.has(2))
	assert_eq(by_index[1].stats.bullet_visual, CHRIS.bullet_visual,
			"P1 (Chris) must keep Chris's own weapon look")
	assert_eq(by_index[2].stats.bullet_visual, FLAM.bullet_visual,
			"P2 (Flam) must NOT inherit Chris's weapon look")
	assert_ne(by_index[1].stats.weapon_color, by_index[2].stats.weapon_color,
			"the two ships must not share the same character's stats")


func test_ui_cancel_bails_out_with_no_bonus() -> void:
	var m := TicketBlitzMinigame.new()
	add_child_autofree(m)
	watch_signals(m)
	Input.action_press(&"ui_cancel")
	await wait_process_frames(1)
	Input.action_release(&"ui_cancel")
	assert_signal_emitted_with_parameters(m, "finished", [false, 0])
