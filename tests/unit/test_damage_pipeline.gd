extends GutTest
## Hitbox → Hurtbox → Health wiring, invulnerability, one-hit-per-swing.

var health: HealthComponent
var hurtbox: HurtboxComponent
var hitbox: HitboxComponent


func before_each() -> void:
	health = HealthComponent.new()
	health.max_hp = 5
	add_child_autofree(health)
	hurtbox = HurtboxComponent.new()
	hurtbox.health = health
	add_child_autofree(hurtbox)
	hitbox = HitboxComponent.new()
	hitbox.damage = 2
	add_child_autofree(hitbox)


func test_hit_deals_hitbox_damage() -> void:
	hurtbox.receive_hit(hitbox)
	assert_eq(health.hp, 3)


func test_invulnerability_ignores_hits() -> void:
	hurtbox.start_invuln(1.0)
	hurtbox.receive_hit(hitbox)
	assert_eq(health.hp, 5)


func test_invulnerability_expires() -> void:
	hurtbox.start_invuln(0.05)
	await wait_physics_frames(6)
	assert_false(hurtbox.is_invulnerable())
	hurtbox.receive_hit(hitbox)
	assert_eq(health.hp, 3)


func test_negate_check_vetoes() -> void:
	hurtbox.negate_check = func(_h: HitboxComponent) -> bool: return true
	hurtbox.receive_hit(hitbox)
	assert_eq(health.hp, 5)


func test_hurt_signal_carries_hitbox() -> void:
	watch_signals(hurtbox)
	hurtbox.receive_hit(hitbox)
	assert_signal_emitted_with_parameters(hurtbox, "hurt", [hitbox])


func test_activation_clears_hit_memory() -> void:
	# same target hittable again on a NEW activation, not within one
	hitbox.activate()
	hitbox._on_area_entered(hurtbox)
	hitbox._on_area_entered(hurtbox)
	assert_eq(health.hp, 3, "double overlap in one swing hits once")
	hitbox.deactivate()
	hitbox.activate()
	hitbox._on_area_entered(hurtbox)
	assert_eq(health.hp, 1, "new swing hits again")
