extends GutTest
## HealthComponent: clamping, signals, dead-stay-dead.

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	health.max_hp = 4
	add_child_autofree(health)


func test_damage_clamps_and_reports_applied() -> void:
	assert_eq(health.damage(3), 3)
	assert_eq(health.hp, 1)
	assert_eq(health.damage(10), 1, "overkill applies only remaining hp")
	assert_eq(health.hp, 0)


func test_died_emitted_exactly_once() -> void:
	watch_signals(health)
	health.damage(4)
	health.damage(1)
	assert_signal_emit_count(health, "died", 1)


func test_heal_clamps_to_max() -> void:
	health.damage(2)
	assert_eq(health.heal(5), 2)
	assert_eq(health.hp, 4)
	assert_eq(health.heal(1), 0, "full hp heals nothing")


func test_dead_cannot_heal() -> void:
	health.damage(4)
	assert_eq(health.heal(2), 0)
	assert_true(health.is_dead())


func test_reset_revives() -> void:
	health.damage(4)
	health.reset()
	assert_eq(health.hp, 4)
	assert_false(health.is_dead())
