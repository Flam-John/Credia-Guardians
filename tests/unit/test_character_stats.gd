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


## Both get a shield now, same BARRIER style (hold to block, unlimited —
## user request: Flam's shield should work continuously just like Chris's,
## not the old tap-to-deflect PARRY), just recolored per character.
func test_both_have_shields_same_style_different_color() -> void:
	assert_true(chris.has_shield)
	assert_true(flam.has_shield)
	assert_eq(chris.shield_style, "BARRIER")
	assert_eq(flam.shield_style, "BARRIER")
	assert_ne(chris.shield_color, flam.shield_color)


## Both get a weapon now, distinct in speed/damage/cooldown to match their
## kits: Chris trades power for a faster, more controlled bolt; Flam trades
## rate of fire for a harder-hitting ember (docs/GDD.md §4).
func test_both_have_distinct_weapons() -> void:
	assert_ne(chris.bullet_visual, flam.bullet_visual)
	assert_ne(chris.weapon_color, flam.weapon_color)
	assert_gt(chris.bullet_speed, flam.bullet_speed, "Chris's bolt is faster")
	assert_gt(flam.weapon_damage, chris.weapon_damage, "Flam's ember hits harder")
	assert_lt(chris.weapon_cooldown, flam.weapon_cooldown, "Chris fires more often")


func test_shared_jump_feel() -> void:
	assert_eq(chris.jump_velocity, flam.jump_velocity)
	assert_eq(chris.coyote_time, flam.coyote_time)
	assert_eq(chris.jump_buffer, flam.jump_buffer)


func test_sheets_assigned() -> void:
	assert_not_null(chris.sheet)
	assert_not_null(flam.sheet)
	assert_ne(chris.sheet.resource_path, flam.sheet.resource_path)
