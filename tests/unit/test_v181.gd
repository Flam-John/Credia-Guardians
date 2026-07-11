extends GutTest
## v1.8.1: the player must be able to STAND on moving platforms (the blue
## boxes) — one-way collision on AnimatableBody2D+sync_to_physics is broken
## in Godot 4 (upstream), so this locks the fix.

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")


func _make_mover(pos: Vector2, span: float, speed: float) -> MovingPlatform:
	var mover := MovingPlatform.new()
	mover.position = pos
	mover.speed = speed
	var curve := Curve2D.new()
	curve.add_point(Vector2.ZERO)
	curve.add_point(Vector2(span, 0))
	mover.curve = curve
	add_child_autofree(mover)
	return mover


func _spawn_player(pos: Vector2) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.stats = CHRIS
	p.position = pos
	add_child_autofree(p)
	return p


func test_player_lands_and_rides_moving_platform() -> void:
	_make_mover(Vector2(0, 60), 80.0, 40.0)
	var player := _spawn_player(Vector2(4, 30))  # above the platform start
	await wait_physics_frames(40)
	assert_true(player.is_on_floor(), "player stands on the moving platform")
	assert_between(player.global_position.y, 20.0, 60.0,
			"player rests on top instead of falling through")
	var x0 := player.global_position.x
	await wait_physics_frames(30)
	assert_gt(player.global_position.x, x0 + 5.0,
			"platform carries the rider along the path")


func test_player_jumping_from_below_is_not_blocked() -> void:
	# one-way contract: approaching from underneath must not bonk
	_make_mover(Vector2(0, 40), 80.0, 0.0)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	shape.shape = rect
	floor_body.position = Vector2(0, 90)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var player := _spawn_player(Vector2(4, 70))
	await wait_physics_frames(20)
	player.velocity = Vector2(0, -350.0)  # hard jump up through the platform
	await wait_physics_frames(12)
	assert_lt(player.global_position.y, 34.0,
			"player passed up through the one-way platform")
