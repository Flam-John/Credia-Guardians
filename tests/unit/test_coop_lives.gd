extends GutTest
## User request (2026-07-23): co-op lives must be INDEPENDENT per player —
## previously a single shared GameManager.lives scalar meant either
## player's death spent the SAME pool, so 3 total lives covered both
## Guardians combined instead of 3 each. Now GameManager.lives is a
## Dictionary keyed by player_index; RespawnController lets a player who's
## exhausted their own pool stay out for the rest of the stage while the
## partner keeps playing, and only routes to game over once EVERY tracked
## player is simultaneously out.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.end_stage()
	GameManager.character2 = &""


func _make_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func _make_coop_respawner() -> RespawnController:
	_make_floor()
	GameManager.character2 = &"flam"
	GameManager.start_stage(1, &"chris")
	var respawner := RespawnController.new()
	respawner.spawn_point = Vector2(0, 90)
	respawner.camera_limits = Rect2(0, 0, 2000, 400)
	respawner.scene_router = func(_path: String) -> void: pass
	add_child_autofree(respawner)
	respawner.spawn(CHRIS)
	return respawner


func test_start_stage_seeds_separate_pools_in_coop() -> void:
	GameManager.character2 = &"flam"
	GameManager.start_stage(1, &"chris")
	assert_eq(GameManager.lives_for(1), 3, "P1 gets a full pool")
	assert_eq(GameManager.lives_for(2), 3, "P2 gets its OWN full pool, not a shared one")


func test_start_stage_solo_still_uses_a_single_pool() -> void:
	GameManager.character2 = &""
	GameManager.start_stage(1, &"chris")
	assert_eq(GameManager.lives_for(0), 3)
	assert_eq(GameManager.lives, {0: 3}, "solo has exactly one tracked pool")


func test_p1_death_does_not_spend_p2_lives() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	var p1 := respawner.players[0]
	p1.kill()
	# lives decrement fires once the death anim finishes and emits
	# player_died (well before RespawnController's own 1.2s respawn delay)
	await wait_physics_frames(60)
	assert_eq(GameManager.lives_for(1), 2, "P1 spent one of THEIR OWN lives")
	assert_eq(GameManager.lives_for(2), 3, "P2's pool is completely untouched")


func test_player_out_of_lives_stays_out_partner_keeps_playing() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 1, 2: 3} # P1 on their last life, P2 fresh
	var routed: Array[String] = []
	respawner.scene_router = func(path: String) -> void: routed.append(path)
	var p1 := respawner.players[0]
	var p2 := respawner.players[1]
	p1.kill() # P1's last life
	await wait_physics_frames(160) # death anim + respawn delay
	assert_eq(GameManager.lives_for(1), 0)
	assert_eq(routed, [], "no game over -- P2 still has lives and is still playing")
	assert_true(GameManager.is_stage_running(), "the stage keeps running for P2")
	assert_false(is_instance_valid(p1), "P1 does not respawn -- permanently out this stage")
	assert_true(is_instance_valid(p2) and not p2.health.is_dead(), "P2 untouched")


func test_game_over_only_when_both_players_out_of_lives() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 1, 2: 1} # both on their last life
	var routed: Array[String] = []
	respawner.scene_router = func(path: String) -> void: routed.append(path)
	var p1 := respawner.players[0]
	p1.kill() # P1's last life -- goes permanently out; P2 is still up
	await wait_physics_frames(160)
	assert_eq(routed, [], "P2 still alive and still has lives -- no game over yet")
	assert_true(GameManager.is_stage_running())
	var p2 := respawner.players[1]
	p2.kill() # P2's last life too -- now everyone is simultaneously out
	await wait_physics_frames(160)
	assert_eq(GameManager.lives_for(2), 0)
	assert_eq(routed, ["res://scenes/ui/game_over.tscn"], "both pools empty -> game over")
	assert_false(GameManager.is_stage_running())


func test_hit_zero_lives_taints_rank_as_soon_as_one_player_runs_out() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 1, 2: 3}
	var p1 := respawner.players[0]
	p1.kill()
	await wait_physics_frames(60)
	assert_true(GameManager.hit_zero_lives,
			"the attempt is tainted the moment ANY player exhausts their own pool")
	assert_false(GameManager.all_players_out_of_lives(),
			"but the team isn't done -- P2 still has lives")


func test_partner_permanent_exit_promotes_survivor_to_personal_camera() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 1, 2: 3} # P1 on their last life, P2 fresh
	var p1 := respawner.players[0]
	p1.kill()
	await wait_physics_frames(160)
	var p2 := respawner.players[1]
	assert_true(p2.camera.is_current(),
			"solo survivor gets back their own lookahead camera, not stuck on CoopCamera")


# -- Simultaneous (same-frame) deaths: review-flagged concurrency edge cases --------

func test_simultaneous_mutual_ko_with_lives_left_respawns_without_crash() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 2, 2: 2}
	var p1 := respawner.players[0]
	var p2 := respawner.players[1]
	p1.kill()
	p2.kill() # same frame -- both _on_player_died coroutines race the same delay window
	await wait_physics_frames(160)
	assert_eq(respawner.players.size(), 2,
			"both respawn cleanly -- no use-after-free on the sibling coroutine's dead_player ref")
	assert_true(is_instance_valid(respawner.players[0]) and not respawner.players[0].health.is_dead())
	assert_true(is_instance_valid(respawner.players[1]) and not respawner.players[1].health.is_dead())


func test_simultaneous_double_exhaustion_routes_game_over_exactly_once() -> void:
	var respawner := _make_coop_respawner()
	await wait_physics_frames(10)
	GameManager.lives = {1: 1, 2: 1} # both on their last life
	var routed: Array[String] = []
	respawner.scene_router = func(path: String) -> void: routed.append(path)
	var p1 := respawner.players[0]
	var p2 := respawner.players[1]
	p1.kill()
	p2.kill() # same frame -- both coroutines independently see "everyone out"
	await wait_physics_frames(160)
	assert_eq(routed, ["res://scenes/ui/game_over.tscn"],
			"routes exactly once even though both coroutines reach the game-over check")
	assert_false(GameManager.is_stage_running())
