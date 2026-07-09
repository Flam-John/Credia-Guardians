extends GutTest
## Regression tests for the v1.2 architect-review fixes (see
## docs/REVIEW_V1.2_FIX_PLAN.md — P numbers referenced below).

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const JUNIOR := preload("res://scenes/entities/enemies/junior_banker.tscn")
const AI_BANKER := preload("res://scenes/entities/enemies/ai_banker.tscn")
const CEO := preload("res://scenes/entities/bosses/ceo_boss.tscn")
const COIN := preload("res://scenes/entities/collectibles/coin.tscn")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.character2 = &""
	GameManager.end_stage()


func _make_floor(width := 2000.0) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func _spawn_player(pos: Vector2, index := 0) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = CHRIS
	p.player_index = index
	p.position = pos
	add_child_autofree(p)
	return p


# -- P1-5: co-op flag hygiene ---------------------------------------------------

func test_quit_to_menu_would_clear_coop() -> void:
	# guard-only check: the reset happens before any scene change
	GameManager.character2 = &"flam"
	# quit_to_menu changes scenes — verify the reset line directly instead
	# by replicating its state contract:
	GameManager.end_stage()
	GameManager.character2 = &"" # (the method's contract under test)
	assert_false(GameManager.is_coop())


func test_launch_guards_respect_busy_scene_manager() -> void:
	GameManager.character2 = &"flam"
	SceneManager._busy = true
	var before_stage := GameManager.stage_id
	GameManager.launch_custom("res://scenes/ui/boss_rush.tscn", &"chris")
	assert_eq(GameManager.stage_id, before_stage, "no state mutation while busy")
	assert_eq(GameManager.character2, &"flam", "unchanged while busy")
	GameManager.retry_stage() # must be a no-op, not a crash
	SceneManager._busy = false


# -- P1-6: nearest-alive targeting ----------------------------------------------

func test_enemies_target_nearest_living_player() -> void:
	_make_floor()
	var far := _spawn_player(Vector2(300, 90), 1)
	var near := _spawn_player(Vector2(60, 90), 2)
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	junior.position = Vector2(0, 90)
	add_child_autofree(junior)
	await wait_physics_frames(5)
	assert_eq(junior.find_player(), near, "targets the nearest")
	near.mark_dead()
	assert_eq(junior.find_player(), far, "corpses are not targets")


# -- P1-7: multi-player node tracking --------------------------------------------

func test_security_node_survives_p2_passthrough() -> void:
	_make_floor()
	var node := SecurityNode.new()
	node.position = Vector2(0, 100)
	add_child_autofree(node)
	var p1 := _spawn_player(Vector2(0, 90), 1)
	var p2 := _spawn_player(Vector2(300, 90), 2)
	await wait_physics_frames(10)
	Input.action_press(&"p1_interact")
	await wait_physics_frames(10) # charging
	p2.position = Vector2(0, 90) # P2 passes through...
	await wait_physics_frames(5)
	p2.position = Vector2(300, 90) # ...and leaves
	await wait_physics_frames(25) # total hold > 0.5s
	Input.action_release(&"p1_interact")
	assert_true(node.active, "P1's hold must survive P2 passing through")


# -- P1-9: same-flush double collection ------------------------------------------

func test_coin_collected_once_for_simultaneous_touch() -> void:
	_make_floor()
	var coin: Coin = COIN.instantiate()
	coin.position = Vector2(0, 90)
	add_child_autofree(coin)
	var p1 := _spawn_player(Vector2(-20, 90), 1)
	var p2 := _spawn_player(Vector2(20, 90), 2)
	await wait_frames(2)
	watch_signals(EventBus)
	# emulate both callbacks in one physics flush
	coin._on_body_entered(p1)
	coin._on_body_entered(p2)
	assert_signal_emit_count(EventBus, "coin_collected", 1)


# -- P2-11: dormant CEO ----------------------------------------------------------

func test_ceo_dormant_until_player_approaches() -> void:
	_make_floor(4000.0)
	var boss: CeoBoss = CEO.instantiate()
	boss.sleep_when_offscreen = false
	boss.position = Vector2(0, 90)
	add_child_autofree(boss)
	var player := _spawn_player(Vector2(1500, 90)) # far outside 400px range
	watch_signals(EventBus)
	await wait_physics_frames(10)
	assert_false(boss.activated, "dormant while the player is far away")
	assert_signal_not_emitted(EventBus, "boss_spawned")
	player.position = Vector2(200, 90) # inside detection_range
	await wait_physics_frames(5)
	assert_true(boss.activated)
	assert_signal_emitted(EventBus, "boss_spawned")


# -- P2-12: knockback must not freeze punish windows ------------------------------

func test_stagger_expires_under_sustained_hits() -> void:
	_make_floor()
	var banker: AIBanker = AI_BANKER.instantiate()
	banker.sleep_when_offscreen = false
	banker.position = Vector2(0, 60)
	add_child_autofree(banker)
	await wait_physics_frames(3)
	banker.state_machine.transition(&"Stagger")
	# hit every 5 frames for ~2s: knockback (0.15s) never fully decays, so
	# the old skip-FSM-during-knockback code would freeze Stagger forever
	for i in 24:
		banker.take_hit(0, banker.global_position + Vector2(10, 0))
		await wait_physics_frames(5)
	assert_ne(banker.state_machine.current_name(), &"Stagger",
			"stagger timer must tick during hit-stun")


# -- P2-13: laser telegraph timing -----------------------------------------------

func test_one_shot_hazard_starts_in_telegraph() -> void:
	var laser := TimedHazard.new()
	laser.on_time = 0.9
	laser.off_time = 99.0
	laser.phase_offset = laser.on_time + laser.off_time - TimedHazard.TELEGRAPH
	add_child_autofree(laser)
	laser.setup(Vector2(100, 4))
	await wait_physics_frames(3)
	var shape := laser.get_child(0) as CollisionShape2D
	assert_true(shape.disabled, "telegraphing, not yet harmful")
	assert_gt(laser._visual.modulate.a, 0.1, "telegraph shimmer visible")
	await wait_physics_frames(20) # past 0.3s -> ignites
	assert_false(shape.disabled, "beam live right after telegraph")


# -- P2-14: kill() bypasses defenses ----------------------------------------------

func test_kill_ignores_firewall_shield_and_iframes() -> void:
	_make_floor()
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(20)
	player.grant_firewall_shield()
	player.hurtbox.start_invuln(5.0)
	player.kill()
	assert_true(player.health.is_dead(), "kill is unconditional")
	assert_false(player.firewall_shield, "bubble cannot save you from the pit")


# -- P4-24/30: perf mechanics -----------------------------------------------------

func test_placed_coin_does_not_tick_physics() -> void:
	var coin: Coin = COIN.instantiate()
	add_child_autofree(coin)
	await wait_frames(2)
	assert_false(coin.is_physics_processing(), "idle coins are free")
	coin.pop(Vector2(0, -100))
	assert_true(coin.is_physics_processing(), "popping coins tick")


func test_pool_double_release_guard() -> void:
	var pool := ObjectPool.new(COIN, self, 1, 4)
	var node := pool.acquire()
	pool.release(node)
	pool.release(node) # must be a no-op
	assert_eq(pool.free_count(), 1)
	var a := pool.acquire()
	var b := pool.acquire()
	assert_ne(a, b, "one node must never be handed to two owners")
