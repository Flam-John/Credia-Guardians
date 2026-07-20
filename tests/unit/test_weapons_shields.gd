extends GutTest
## Ranged weapons (cooldown, friendly bullets, wall/lifetime despawn) and the
## two Shield styles: Chris BARRIER (existing block, now sprite-backed) vs
## Flam PARRY (new tap-deflect window) — docs/GDD.md §3-4.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")
const FLAM := preload("res://data/characters/flam.tres")
const JUNIOR := preload("res://scenes/entities/enemies/junior_banker.tscn")

var _player: Player


func _make_floor(y := 110.0) -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, y)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func before_each() -> void:
	_make_floor()
	_player = PLAYER_SCENE.instantiate()
	_player.stats = CHRIS
	_player.position = Vector2(0, 90)
	add_child_autofree(_player)
	await wait_physics_frames(30) # settle onto floor


func after_each() -> void:
	for action in ["jump", "dash", "attack", "ability", "fire", "move_left", "move_right"]:
		Input.action_release(action)


func _state() -> StringName:
	return _player.state_machine.current_name()


func _spawn(stats: CharacterStats, pos: Vector2) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = stats
	p.position = pos
	add_child_autofree(p)
	return p


# -- Weapon cooldown -----------------------------------------------------------


func test_can_fire_gated_by_cooldown_timer() -> void:
	_player.weapon_cooldown_timer = 0.0
	assert_true(_player.can_fire())
	_player.weapon_cooldown_timer = 0.3
	assert_false(_player.can_fire())


func test_fire_enters_state_sets_cooldown_and_blocks_immediate_refire() -> void:
	Input.action_press("fire")
	await wait_physics_frames(2)
	Input.action_release("fire")
	assert_eq(_state(), &"Fire")
	await wait_physics_frames(30) # ride out attack_1 pose (4 frames @16fps)
	assert_eq(_state(), &"Idle")
	assert_gt(_player.weapon_cooldown_timer, 0.0, "cooldown armed on exit")
	# mash: cooldown must block re-entry the instant the pose finishes
	Input.action_press("fire")
	await wait_physics_frames(2)
	assert_ne(_state(), &"Fire", "cooldown blocks spamming fire")


func test_fire_cooldown_expires_and_allows_refire() -> void:
	Input.action_press("fire")
	await wait_physics_frames(2)
	Input.action_release("fire")
	await wait_physics_frames(60) # anim done + full Chris cooldown (0.4s)
	assert_true(_player.can_fire())


# -- Bullet vs enemy ------------------------------------------------------------


func test_friendly_bullet_damages_enemy() -> void:
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	junior.position = Vector2(40, 90)
	add_child_autofree(junior)
	await wait_physics_frames(3)
	var hp_before: int = junior.health.hp
	_player.fire_weapon()
	await wait_physics_frames(20) # bullet at 320px/s covers 40px in ~7 ticks
	assert_lt(junior.health.hp, hp_before, "friendly bullet hurt the enemy")


func test_bullet_despawns_on_wall_contact() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var wshape := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(20, 40)
	wshape.shape = wrect
	wall.position = Vector2(60, 60)
	wall.add_child(wshape)
	add_child_autofree(wall)
	# unpooled (no LevelServices in this scene) -> _despawn() queue_frees it,
	# so it's gone by the next frame; don't autofree an already-freed node.
	var bullet := Projectile.new()
	add_child(bullet)
	await wait_physics_frames(1)
	bullet.launch(wall.position, Vector2.ZERO, Projectile.Visual.PACKET_BOLT, 1, 0.0, true)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(bullet), "wall contact frees the unpooled bullet")


func test_bullet_despawns_after_lifetime() -> void:
	var bullet := Projectile.new()
	add_child(bullet)
	await wait_physics_frames(1)
	bullet.launch(Vector2(500, 500), Vector2.ZERO, Projectile.Visual.EMBER, 1, 0.0, true, 0.05)
	await wait_physics_frames(6)
	assert_false(is_instance_valid(bullet), "expired lifetime frees the unpooled bullet")


# -- Shield styles ---------------------------------------------------------------


func test_chris_barrier_still_blocks_frontal_hits() -> void:
	Input.action_press("ability")
	await wait_physics_frames(3)
	assert_eq(_state(), &"Shield")
	var hp_before := _player.health.hp
	_player.take_hit(1, _player.global_position + Vector2(30, 0))
	assert_eq(_player.health.hp, hp_before, "BARRIER still blocks frontal hits")


func test_flam_parry_avoids_damage_in_window_then_expires() -> void:
	var flam := _spawn(FLAM, Vector2(200, 90))
	await wait_physics_frames(30)
	Input.action_press("ability")
	await wait_physics_frames(2)
	Input.action_release("ability")
	assert_eq(flam.state_machine.current_name(), &"Parry", "tap enters Parry, not a hold")
	var hp_before := flam.health.hp
	flam.take_hit(1, flam.global_position + Vector2(30, 0))
	assert_eq(flam.health.hp, hp_before, "hit inside the parry window is deflected")
	await wait_physics_frames(20) # ride out parry_window (0.18s) back to Idle
	assert_ne(flam.state_machine.current_name(), &"Parry")
	assert_false(flam.parry_active)
	flam.take_hit(1, flam.global_position + Vector2(30, 0))
	assert_eq(flam.health.hp, hp_before - 1, "hit after the window lands normally")


func test_flam_parry_has_its_own_cooldown() -> void:
	var flam := _spawn(FLAM, Vector2(200, 90))
	await wait_physics_frames(30)
	Input.action_press("ability")
	await wait_physics_frames(2)
	Input.action_release("ability")
	assert_eq(flam.state_machine.current_name(), &"Parry")
	await wait_physics_frames(15) # window elapses, cooldown now armed
	assert_gt(flam.parry_cooldown_timer, 0.0)
	Input.action_press("ability")
	await wait_physics_frames(2)
	assert_ne(flam.state_machine.current_name(), &"Parry", "cooldown blocks spamming parry")
