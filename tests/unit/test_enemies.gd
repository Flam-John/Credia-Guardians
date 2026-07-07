extends GutTest
## Enemy FSM tables per docs/ENEMY_AI.md, in a real physics scene.

const JUNIOR := preload("res://scenes/entities/enemies/junior_banker.tscn")
const MANAGER := preload("res://scenes/entities/enemies/angry_manager.tscn")


func _make_floor() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 110)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)


func test_junior_patrols_then_panics_at_1hp() -> void:
	_make_floor()
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	junior.position = Vector2(0, 90)
	add_child_autofree(junior)
	await wait_physics_frames(10)
	assert_eq(junior.state_machine.current_name(), &"Patrol")
	assert_ne(junior.velocity.x, 0.0, "patrolling moves")
	junior.take_hit(1, junior.global_position + Vector2(10, 0))
	await wait_physics_frames(2)
	assert_eq(junior.health.hp, 1)
	assert_eq(junior.state_machine.current_name(), &"Panic")


func test_junior_dies_and_emits_score() -> void:
	_make_floor()
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	junior.position = Vector2(0, 90)
	add_child_autofree(junior)
	await wait_physics_frames(5)
	watch_signals(EventBus)
	junior.take_hit(2, junior.global_position)
	assert_signal_emitted_with_parameters(
		EventBus, "enemy_killed", [200, junior.global_position])


func test_manager_alert_telegraph_then_charge() -> void:
	_make_floor()
	var manager: AngryManager = MANAGER.instantiate()
	manager.sleep_when_offscreen = false
	manager.position = Vector2(0, 90)
	add_child_autofree(manager)
	await wait_physics_frames(5)
	assert_eq(manager.state_machine.current_name(), &"Idle")
	manager.force_sees_player = true
	await wait_physics_frames(3)
	assert_eq(manager.state_machine.current_name(), &"Alert")
	# telegraph is 0.4s = 24 ticks; must NOT charge instantly (reactability)
	await wait_physics_frames(10)
	assert_eq(manager.state_machine.current_name(), &"Alert")
	await wait_physics_frames(20)
	assert_eq(manager.state_machine.current_name(), &"Charge")


func test_manager_wall_stun_takes_double_damage() -> void:
	_make_floor()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var wshape := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(20, 100)
	wshape.shape = wrect
	wall.position = Vector2(60, 60)
	wall.add_child(wshape)
	add_child_autofree(wall)
	var manager: AngryManager = MANAGER.instantiate()
	manager.sleep_when_offscreen = false
	manager.position = Vector2(0, 90)
	add_child_autofree(manager)
	await wait_physics_frames(5)
	manager.set_facing(1)
	manager.force_sees_player = true
	await wait_physics_frames(3)
	manager.force_sees_player = false # stop re-alerting after stun
	# ride: alert 24 ticks + charge into wall
	var deadline := 120
	while manager.state_machine.current_name() != &"WallStun" and deadline > 0:
		deadline -= 1
		await wait_physics_frames(1)
	assert_eq(manager.state_machine.current_name(), &"WallStun")
	var hp_before: int = manager.health.hp
	manager.take_hit(1, manager.global_position)
	assert_eq(manager.health.hp, hp_before - 2, "stunned takes double damage")

