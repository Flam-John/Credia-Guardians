extends GutTest
## Guards the Chris/Flam design contract (docs/GDD.md §3). If a .tres edit
## breaks a character identity rule, this catches it.

var chris: CharacterStats = preload("res://data/characters/chris.tres")
var flam: CharacterStats = preload("res://data/characters/flam.tres")


func test_chris_is_the_tank() -> void:
	assert_gt(chris.max_hp, flam.max_hp)
	assert_true(chris.has_shield)
	assert_false(chris.dash_has_iframes)


func test_flam_is_the_speedster() -> void:
	assert_gt(flam.run_speed, chris.run_speed)
	assert_gt(flam.dash_speed, chris.dash_speed)
	assert_gt(flam.air_dash_charges, chris.air_dash_charges)
	assert_lt(flam.dash_cooldown, chris.dash_cooldown)
	assert_true(flam.dash_has_iframes)
	assert_true(flam.dash_deals_damage)
	assert_false(flam.has_shield)


func test_shared_jump_feel() -> void:
	assert_eq(chris.jump_velocity, flam.jump_velocity)
	assert_eq(chris.coyote_time, flam.coyote_time)
	assert_eq(chris.jump_buffer, flam.jump_buffer)


func test_sheets_assigned() -> void:
	assert_not_null(chris.sheet)
	assert_not_null(flam.sheet)
	assert_ne(chris.sheet.resource_path, flam.sheet.resource_path)
