extends GutTest
## M5: object pool, new enemy FSMs, power-ups, firewall gate, updraft lift.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const AUDITOR := preload("res://scenes/entities/enemies/auditor.tscn")
const SHARK := preload("res://scenes/entities/enemies/loan_shark.tscn")
const AI_BANKER := preload("res://scenes/entities/enemies/ai_banker.tscn")
const COIN := preload("res://scenes/entities/collectibles/coin.tscn")


func _make_floor(y := 110.0, width := 2000.0) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, y)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func _spawn_player(pos: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.stats = CHRIS
	player.position = pos
	add_child_autofree(player)
	return player


func after_each() -> void:
	for action in ["jump", "dash", "attack", "ability", "move_left", "move_right", "interact"]:
		Input.action_release(action)


# -- ObjectPool ----------------------------------------------------------------

func test_pool_reuses_and_parks() -> void:
	var pool := ObjectPool.new(COIN, self, 3, 4)
	assert_eq(pool.free_count(), 3)
	var a := pool.acquire()
	assert_eq(pool.free_count(), 2)
	assert_eq(a.process_mode, Node.PROCESS_MODE_INHERIT)
	pool.release(a)
	assert_eq(pool.free_count(), 3)
	assert_eq(a.process_mode, Node.PROCESS_MODE_DISABLED)
	var b := pool.acquire()
	assert_eq(b, a, "released node is reused")


func test_pool_grows_when_exhausted() -> void:
	var pool := ObjectPool.new(COIN, self, 1, 4)
	var a := pool.acquire()
	var b := pool.acquire() # beyond prewarm
	assert_not_null(b)
	assert_ne(a, b)


# -- Auditor -------------------------------------------------------------------

func test_auditor_throws_projectile_in_band() -> void:
	_make_floor()
	var auditor: Auditor = AUDITOR.instantiate()
	auditor.sleep_when_offscreen = false
	auditor.position = Vector2(0, 90)
	add_child_autofree(auditor)
	_spawn_player(Vector2(120, 90)) # inside 100-140 band
	await wait_physics_frames(40) # settle + cooldown (2.0s? cooldown counts)
	# ride until throw happens (cooldown 2s = 120 ticks)
	var deadline := 200
	while auditor.state_machine.current_name() != &"Throw" and deadline > 0:
		deadline -= 1
		await wait_physics_frames(1)
	assert_eq(auditor.state_machine.current_name(), &"Throw")
	await wait_physics_frames(20) # windup frame 2 @12fps ≈ 10 ticks
	var projectiles := get_children().filter(
		func(c: Node) -> bool: return c is Projectile)
	assert_gt(projectiles.size(), 0, "ledger thrown")


# -- Loan Shark ----------------------------------------------------------------

func test_shark_hidden_until_close_then_lunges() -> void:
	_make_floor()
	var shark: LoanShark = SHARK.instantiate()
	shark.sleep_when_offscreen = false
	shark.position = Vector2(0, 90)
	add_child_autofree(shark)
	var player := _spawn_player(Vector2(300, 90))
	await wait_physics_frames(10)
	assert_eq(shark.state_machine.current_name(), &"Hidden")
	assert_false(shark.hurtbox.monitorable, "invulnerable while hidden")
	player.position = Vector2(50, 90) # inside 60px detection
	await wait_physics_frames(5)
	assert_eq(shark.state_machine.current_name(), &"Emerge")
	var deadline := 60
	while shark.state_machine.current_name() != &"Lunge" and deadline > 0:
		deadline -= 1
		await wait_physics_frames(1)
	assert_eq(shark.state_machine.current_name(), &"Lunge")


# -- AI Banker -----------------------------------------------------------------

func test_ai_banker_cast_fires_fan_then_staggers() -> void:
	_make_floor()
	var banker: AIBanker = AI_BANKER.instantiate()
	banker.sleep_when_offscreen = false
	banker.position = Vector2(0, 60)
	add_child_autofree(banker)
	_spawn_player(Vector2(80, 90))
	var deadline := 240 # cooldown 2.5s
	while banker.state_machine.current_name() != &"Cast" and deadline > 0:
		deadline -= 1
		await wait_physics_frames(1)
	assert_eq(banker.state_machine.current_name(), &"Cast")
	await wait_physics_frames(30) # cast anim 4f @10fps = 24 ticks
	var projectiles := get_children().filter(
		func(c: Node) -> bool: return c is Projectile)
	assert_eq(projectiles.size(), 3, "3-projectile fan")
	assert_eq(banker.state_machine.current_name(), &"Stagger")


# -- Power-ups -----------------------------------------------------------------

func test_firewall_shield_absorbs_one_hit() -> void:
	_make_floor()
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(20)
	player.grant_firewall_shield()
	var hp := player.health.hp
	player.take_hit(1, player.global_position + Vector2(20, 0))
	assert_eq(player.health.hp, hp, "bubble ate the hit")
	assert_false(player.firewall_shield)
	await wait_physics_frames(40) # ride out the 0.5s grace
	player.take_hit(1, player.global_position + Vector2(20, 0))
	assert_eq(player.health.hp, hp - 1, "second hit lands")


func test_keyboard_upgrade_boosts_melee() -> void:
	_make_floor()
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(5)
	var base := player.melee_hitbox.damage
	var pickup := Pickup.new()
	pickup.kind = Pickup.Kind.KEYBOARD_UPGRADE
	pickup._apply(player)
	assert_eq(player.melee_hitbox.damage, base + 1)
	pickup.free()


func test_usb_key_opens_firewall_gate() -> void:
	_make_floor()
	GameManager.usb_keys = 0
	var gate := FirewallGate.new()
	gate.position = Vector2(60, 100)
	add_child_autofree(gate)
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(10)
	# locked without key
	player.position = Vector2(55, 90)
	await wait_physics_frames(5)
	assert_false(gate.open, "no key -> stays locked")
	GameManager.usb_keys = 1
	player.position = Vector2(0, 90)
	await wait_physics_frames(3)
	player.position = Vector2(58, 90)
	await wait_physics_frames(5)
	assert_true(gate.open, "key consumed, gate open")
	assert_eq(GameManager.usb_keys, 0)


# -- Updraft (playability-audit regression) ------------------------------------

func test_updraft_actually_lifts() -> void:
	_make_floor()
	var draft := Updraft.new()
	draft.position = Vector2(-8, -60) # column over the player, down to floor
	add_child_autofree(draft)
	draft.setup(10) # 160px tall
	var player := _spawn_player(Vector2(0, 90))
	await wait_physics_frames(30) # land, then get caught by the draft
	var start_y := player.global_position.y
	await wait_physics_frames(30)
	assert_lt(player.global_position.y, start_y - 30.0,
			"steam must carry the player upward, not just slow falls")