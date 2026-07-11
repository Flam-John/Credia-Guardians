extends GutTest
## v1.7: loot coins bounce off walls instead of embedding; the visible
## slot DELETE button shares the two-press confirm with the X shortcut.

const COIN_SCENE := preload("res://scenes/entities/collectibles/coin.tscn")
const SLOT_SELECT := preload("res://scenes/ui/slot_select.tscn")
const SLOT := 3


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	SaveManager.delete_slot(SLOT)


func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.position = pos
	wall.add_child(shape)
	add_child_autofree(wall)


func test_loot_coin_bounces_off_wall() -> void:
	_make_wall(Vector2(50, 0), Vector2(20, 240))  # wall face at x=40
	var coin: Coin = COIN_SCENE.instantiate()
	coin.position = Vector2.ZERO
	add_child_autofree(coin)
	coin.pop(Vector2(320, -40))  # flung hard at the wall
	await wait_physics_frames(50)
	assert_lt(coin.position.x, 40.0 - Coin.RADIUS + 1.0,
			"coin bounced back instead of embedding in the wall")


func test_loot_coin_settles_on_floor_and_collectable() -> void:
	_make_wall(Vector2(0, 60), Vector2(400, 20))  # floor top at y=50
	var coin: Coin = COIN_SCENE.instantiate()
	coin.position = Vector2.ZERO
	add_child_autofree(coin)
	coin.pop(Vector2(30, -60))
	await wait_physics_frames(90)
	assert_lt(coin.position.y, 51.0, "coin rests on (not inside) the floor")
	assert_true(coin.monitoring, "settled coin is collectable again")


func test_slot_delete_button_needs_two_presses() -> void:
	SaveManager.write_slot(SLOT, SaveManager.new_slot_data(&"chris"))
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	screen._delete_slot(SLOT)  # arm
	assert_false(SaveManager.get_slot_summaries()[SLOT - 1].get("empty", true),
			"first press only arms the confirm")
	screen._delete_slot(SLOT)  # confirm
	assert_true(SaveManager.get_slot_summaries()[SLOT - 1].get("empty", true),
			"second press deletes the save")


func test_slot_rows_expose_delete_button_only_when_occupied() -> void:
	SaveManager.write_slot(SLOT, SaveManager.new_slot_data(&"flam"))
	var screen: Control = SLOT_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	var delete_slots: Array = []
	for button in screen._slot_buttons():
		var slot: int = button.get_meta(&"slot_delete", -1)
		if slot > 0:
			delete_slots.append(slot)
	assert_eq(delete_slots, [SLOT], "exactly the occupied slot offers DELETE")
