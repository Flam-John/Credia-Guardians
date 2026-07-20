class_name Player
extends CharacterBody2D
## Player body: shared per-frame plumbing (gravity, timers, buffers, charges).
## Behavior lives in the State children of $StateMachine (docs/PLAYER_FSM.md).
## Chris vs Flam differences come entirely from the injected CharacterStats.

@export var stats: CharacterStats
## 0 = single-player (base actions, any device). 1/2 = co-op action sets.
@export var player_index := 0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var state_machine: StateMachine = $StateMachine
@onready var camera: PlayerCamera = $Camera

var facing := 1
var air_jumps_left := 1
var dash_charges_left := 1
## Owned exclusively by DashState. Hurt i-frames live on the hurtbox timer;
## the damage pipeline asks is_invulnerable().
var dash_iframes_active := false
## Flam signature: true only during the Parry state's short deflect window.
var parry_active := false
## Weapon: the anti-spam gate (docs/GDD.md §4), ticked every physics frame.
var weapon_cooldown_timer := 0.0
## Energy Drink (docs/GDD.md §8): multiplies run speed while boosted.
var speed_boost := 1.0
var _boost_left := 0.0
## Environmental forces for THIS physics frame — written only through
## apply_field_force() by PushZone props (which tick before this body);
## consumed and zeroed after the slide. Internals, not an API.
var _field_push_x := 0.0
var _field_lift := 0.0
## Firewall Shield pickup: absorbs exactly one hit (docs/GDD.md §8).
var firewall_shield := false
var _bubble: Sprite2D
## Set by HurtState so knockback direction survives the state transition.
var last_hit_from := Vector2.ZERO

# Countdown timers, ticked here every physics frame (docs/PLAYER_FSM.md).
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_cooldown_timer := 0.0

var health: HealthComponent
var hurtbox: HurtboxComponent
var melee_hitbox: HitboxComponent
var melee_shape: CollisionShape2D
var flash: FlashComponent
var _hazard_detector: Area2D
var _dust: CPUParticles2D
## Held-weapon sprite: hidden except during the Fire state (states set
## position/flip_h to track facing — see FireState).
var weapon_sprite: Sprite2D
## Shield/Parry sprite: hidden except while the ability is active (style —
## BARRIER hex bubble or PARRY buckler — picked once in _build_combat_nodes).
var shield_sprite: Sprite2D
## Ring of reusable dash afterimage sprites (docs/PERFORMANCE.md: pooled).
var _ghosts: Array[Sprite2D] = []
var _ghost_index := 0


## base action name -> player-scoped StringName, cached (no per-frame allocs)
var _action_cache: Dictionary = {}


func action(base: StringName) -> StringName:
	if player_index == 0:
		return base
	var scoped: StringName = _action_cache.get(base, StringName())
	if scoped == StringName():
		scoped = StringName("p%d_%s" % [player_index, base])
		_action_cache[base] = scoped
	return scoped


func pressed(base: StringName) -> bool:
	return Input.is_action_pressed(action(base))


func just_pressed(base: StringName) -> bool:
	return Input.is_action_just_pressed(action(base))


func just_released(base: StringName) -> bool:
	return Input.is_action_just_released(action(base))


## Alloc-free registry of living players — AI targeting iterates this
## instead of allocating group arrays every frame (review P1-6).
static var alive: Array[Player] = []


func _ready() -> void:
	assert(stats != null, "Player needs a CharacterStats resource")
	if player_index > 0:
		CoopInput.ensure_actions()
	add_to_group(&"player")
	alive.append(self)
	sprite.sprite_frames = SpriteFramesBuilder.build_player_frames(stats.sheet)
	_build_combat_nodes()
	state_machine.setup(self, stats)
	EventBus.player_spawned.emit(self)


func _exit_tree() -> void:
	alive.erase(self)


## Called by DeadState: dead players stop being AI targets immediately.
func mark_dead() -> void:
	alive.erase(self)


## Combat plumbing is code-built so player.tscn stays small and both
## characters share one scene (docs/TDD.md §2.3 components).
func _build_combat_nodes() -> void:
	health = HealthComponent.new()
	health.max_hp = stats.max_hp
	add_child(health)

	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.PLAYER_HURTBOX
	hurtbox.health = null # damage is routed through take_hit for state control
	var hurt_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 5.0
	capsule.height = 24.0
	hurt_shape.shape = capsule
	hurt_shape.position = Vector2(0, -12)
	hurtbox.add_child(hurt_shape)
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	add_child(hurtbox)

	melee_hitbox = HitboxComponent.new()
	melee_hitbox.damage = stats.attack_damage
	melee_hitbox.collision_mask = PhysicsLayers.ENEMY_HURTBOX
	melee_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 16)
	melee_shape.shape = rect
	melee_shape.position = Vector2(14, -12) # x mirrored with facing (never
	melee_hitbox.add_child(melee_shape)     # negative scale — physics dislikes it)
	add_child(melee_hitbox)

	flash = FlashComponent.new()
	flash.target = sprite
	add_child(flash)

	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 6
	_dust.lifetime = 0.35
	_dust.direction = Vector2.UP
	_dust.spread = 70.0
	_dust.gravity = Vector2(0, 200)
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 45.0
	_dust.color = Color(0.6, 0.7, 0.8, 0.5)
	add_child(_dust)

	for i in 6: # dash afterimages, reused round-robin
		var ghost := Sprite2D.new()
		ghost.top_level = true # stays put in world space while we move on
		ghost.visible = false
		ghost.modulate = Color(0.3, 0.9, 1.0, 0.45)
		ghost.material = FX.additive()  # Phase 3 glow pass
		add_child(ghost)
		_ghosts.append(ghost)

	# Weapon cell 0 = Packet Rifle (Chris), 1 = Ember Slinger (Flam) — picked
	# by bullet_visual so the held sprite always matches what actually fires.
	var weapon_cell := 0 if stats.bullet_visual == "PACKET_BOLT" else 1
	weapon_sprite = Sprite2D.new()
	var w_atlas := AtlasTexture.new()
	w_atlas.atlas = preload("res://assets/art/props/weapons.png")
	w_atlas.region = Rect2(weapon_cell * 16, 0, 16, 16)
	weapon_sprite.texture = w_atlas
	weapon_sprite.position = Vector2(-14, -12)  # hand height, matches melee_shape
	weapon_sprite.visible = false
	add_child(weapon_sprite)

	if stats.has_shield:
		# Shield cell 0 = hex BARRIER (Chris), 1 = riot buckler PARRY (Flam).
		var shield_cell := 0 if stats.shield_style == "BARRIER" else 1
		shield_sprite = Sprite2D.new()
		var s_atlas := AtlasTexture.new()
		s_atlas.atlas = preload("res://assets/art/props/shields.png")
		s_atlas.region = Rect2(shield_cell * 16, 0, 16, 16)
		shield_sprite.texture = s_atlas
		shield_sprite.position = Vector2(-14, -12)  # hand height, matches melee_shape
		shield_sprite.visible = false
		add_child(shield_sprite)

	# Hazard tiles/areas (spikes, lasers) — 2 dmg per GDD §4. POLLED in
	# _physics_process, not edge-triggered: an *_entered-only design goes
	# silent when the player stays overlapping after i-frames expire.
	_hazard_detector = Area2D.new()
	_hazard_detector.collision_layer = 0
	_hazard_detector.collision_mask = PhysicsLayers.HAZARD
	var hz_shape := hurt_shape.duplicate()
	_hazard_detector.add_child(hz_shape)
	add_child(_hazard_detector)


## Camera handshake for spawners (levels, debug rooms): limits, then snap,
## then make current — callers never touch the camera child directly.
func activate_camera(limits: Rect2) -> void:
	camera.setup_limits(limits)
	camera.snap_to_target()
	camera.make_current()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if just_pressed(&"jump"):
		jump_buffer_timer = stats.jump_buffer
	if not state_machine.current.overrides_gravity:
		apply_gravity(delta)
	state_machine.physics_update(delta)
	# Conveyor: applied for the slide only — the push must not accumulate
	# into stored velocity. RESTORE (not subtract): if a wall zeroed the
	# pushed velocity, subtracting would manufacture reverse velocity.
	var pre_push_vx := velocity.x
	velocity.x += _field_push_x
	move_and_slide()
	velocity.x = 0.0 if (is_on_wall() and _field_push_x != 0.0) else pre_push_vx
	_field_push_x = 0.0
	_field_lift = 0.0
	# INVARIANT: charge reset stays AFTER move_and_slide — is_on_floor() is
	# only fresh post-slide, so a same-frame landing refreshes air options.
	if is_on_floor():
		air_jumps_left = 1
		dash_charges_left = stats.air_dash_charges
	# Polled hazard check (take_hit no-ops during i-frames, so this is one
	# cheap overlap test per frame, damage at i-frame cadence while inside).
	if _hazard_detector.has_overlapping_bodies() or _hazard_detector.has_overlapping_areas():
		take_hit(2, global_position + Vector2(0, 8))


func _unhandled_input(event: InputEvent) -> void:
	state_machine.handle_input(event)


# -- Damage pipeline -----------------------------------------------------------

## Single query point for the damage pipeline; each i-frame source ORs in here.
func is_invulnerable() -> bool:
	return dash_iframes_active or hurtbox.is_invulnerable()


## Central hit entry: hitboxes, contact damage, and hazards all land here.
func take_hit(damage: int, from_global_pos: Vector2) -> void:
	if health.is_dead():
		return
	# Checked before is_invulnerable(): a successful parry gets its own
	# feedback (sfx/hitstop/spark) instead of silently no-opping like a
	# generic i-frame would.
	if parry_active:
		_on_parry_success(from_global_pos)
		return
	if is_invulnerable():
		return
	if _shield_blocks(from_global_pos):
		AudioManager.play_sfx("shield_on")
		FxService.hit_spark(get_tree(), global_position.lerp(from_global_pos, 0.5), stats.shield_color)
		return
	if firewall_shield:
		firewall_shield = false
		_bubble.visible = false
		EventBus.player_shield_changed.emit(player_index, false)
		hurtbox.start_invuln(0.5) # breathing room after the bubble pops
		AudioManager.play_sfx("shield_break")
		return
	health.damage(damage)
	EventBus.player_damaged.emit(player_index, health.hp, health.max_hp)
	last_hit_from = from_global_pos
	flash.flash()
	GameFeel.shake(get_tree(), 3.0)
	GameFeel.rumble(maxi(0, player_index - 1), 0.6, 0.4, 0.25)
	FxService.hit_spark(get_tree(), global_position + Vector2(0, -12))
	if health.is_dead():
		state_machine.transition(&"Dead")
	else:
		state_machine.transition(&"Hurt")


func heal(amount: int) -> void:
	if health.heal(amount) > 0:
		EventBus.player_healed.emit(player_index, health.hp, health.max_hp)
		AudioManager.play_sfx("heal")


## Unavoidable death (kill planes): bypasses shields and i-frames — pits
## used to pop the firewall bubble and stall (review P2-14).
func kill() -> void:
	if health.is_dead():
		return
	if firewall_shield:
		firewall_shield = false
		EventBus.player_shield_changed.emit(player_index, false)
	if _bubble != null:
		_bubble.visible = false
	dash_iframes_active = false
	health.damage(health.hp)
	EventBus.player_damaged.emit(player_index, health.hp, health.max_hp)
	state_machine.transition(&"Dead")


func apply_speed_boost(multiplier: float, duration: float) -> void:
	speed_boost = multiplier
	_boost_left = duration


## The one entry point for environmental force fields (review P3-20).
## push_x: signed horizontal px/s applied for this frame's slide only.
## lift: upward acceleration that REPLACES gravity while > 0.
## Called by PushZone props each physics frame they overlap the player.
func apply_field_force(push_x: float, lift: float) -> void:
	if push_x != 0.0:
		_field_push_x = push_x
	if lift > 0.0:
		_field_lift = maxf(_field_lift, lift)


func emit_land_dust() -> void:
	_dust.global_position = global_position
	_dust.restart()


func spawn_dash_ghost() -> void:
	var ghost := _ghosts[_ghost_index]
	_ghost_index = (_ghost_index + 1) % _ghosts.size()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.global_position = sprite.global_position
	ghost.visible = true
	ghost.modulate.a = 0.45
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: ghost.visible = false)


func grant_firewall_shield() -> void:
	firewall_shield = true
	EventBus.player_shield_changed.emit(player_index, true)
	if _bubble == null:
		_bubble = Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/art/props/pickups.png")
		atlas.region = Rect2(2 * 16, 0, 16, 16) # shield icon
		_bubble.texture = atlas
		_bubble.scale = Vector2(2.2, 2.2)
		_bubble.position = Vector2(0, -14)
		_bubble.modulate = Color(1, 1, 1, 0.4)
		add_child(_bubble)
	_bubble.visible = true
	AudioManager.play_sfx("powerup")


func _on_hurtbox_hurt(hitbox: HitboxComponent) -> void:
	take_hit(hitbox.damage, hitbox.global_position)


## Flam's Parry: no damage taken, but distinct feedback so it reads as a
## skill hit rather than the hit simply whiffing.
func _on_parry_success(from_global_pos: Vector2) -> void:
	AudioManager.play_sfx("shield_parry")
	GameFeel.hitstop(get_tree(), 0.06)
	FxService.hit_spark(get_tree(), global_position.lerp(from_global_pos, 0.5), stats.shield_color)


# -- Weapon --------------------------------------------------------------------

const PROJECTILE_SCENE := preload("res://scenes/entities/props/projectile.tscn")


func can_fire() -> bool:
	return weapon_cooldown_timer <= 0.0


## Fired by FireState.enter(). Mirrors EnemyBase.spawn_projectile but targets
## ENEMY_HURTBOX (Projectile.launch's `is_friendly` flag) — docs/GDD.md §4.
func fire_weapon() -> void:
	var visual := Projectile.Visual.PACKET_BOLT if stats.bullet_visual == "PACKET_BOLT" \
			else Projectile.Visual.EMBER
	var muzzle := global_position + Vector2(12 * facing, -14)
	var vel := Vector2(facing * stats.bullet_speed, 0.0)
	var services := LevelServices.find(get_tree())
	var projectile: Projectile
	if services != null:
		projectile = services.acquire_projectile()
	else:
		projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(projectile)
	projectile.launch(muzzle, vel, visual, stats.weapon_damage, stats.bullet_gravity,
			true, stats.bullet_lifetime)
	FxService.hit_spark(get_tree(), muzzle, stats.weapon_color)
	AudioManager.play_sfx("weapon_fire_chris" if stats.bullet_visual == "PACKET_BOLT" \
			else "weapon_fire_flam")
	GameFeel.rumble(maxi(0, player_index - 1), 0.15, 0.1, 0.08)


## Chris only (BARRIER style): frontal ±60° block while Shield state is active.
func _shield_blocks(from_global_pos: Vector2) -> bool:
	if not stats.has_shield or state_machine.current_name() != &"Shield":
		return false
	var to_source := from_global_pos - global_position
	if to_source.is_zero_approx():
		return false
	var frontal := Vector2(facing, 0.0)
	return absf(frontal.angle_to(to_source.normalized())) <= deg_to_rad(60.0)


# -- Helpers shared by states -------------------------------------------------


func apply_gravity(delta: float) -> void:
	if _field_lift > 0.0:
		# Steam column REPLACES gravity: accelerate toward a sustained rise
		# (playtest audit: adding lift on top of gravity could never win —
		# net accel stayed downward and the clamp murdered jump velocity).
		# DESIGN: lift lives in apply_gravity, so Dash (overrides_gravity)
		# ignores updrafts — a dash keeps its flat trajectory, MMX-style.
		velocity.y = move_toward(
				velocity.y, -0.7 * _field_lift, _field_lift * 3.0 * delta)
		return
	var g := stats.gravity_rise if velocity.y < 0.0 else stats.gravity_fall
	velocity.y = minf(velocity.y + g * delta, stats.max_fall_speed)


func input_axis() -> float:
	return Input.get_axis(action(&"move_left"), action(&"move_right"))


## Ground movement: accelerate toward input, brake with friction.
func ground_move(delta: float) -> void:
	var axis := input_axis()
	if absf(axis) > 0.0:
		velocity.x = move_toward(
				velocity.x, axis * stats.run_speed * speed_boost, stats.ground_accel * delta)
		set_facing(signf(axis))
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.ground_friction * delta)


## Air movement: same target speed, reduced authority.
func air_move(delta: float) -> void:
	var axis := input_axis()
	if absf(axis) > 0.0:
		velocity.x = move_toward(
			velocity.x, axis * stats.run_speed * speed_boost,
			stats.ground_accel * stats.air_control * delta)
		set_facing(signf(axis))


func set_facing(dir: float) -> void:
	if dir == 0.0:
		return
	facing = 1 if dir > 0.0 else -1
	sprite.flip_h = facing < 0


func play(anim: StringName) -> void:
	sprite.play(anim)


# -- Buffers & grace -----------------------------------------------------------

func jump_buffered() -> bool:
	return jump_buffer_timer > 0.0


func consume_jump_buffer() -> void:
	jump_buffer_timer = 0.0


func coyote_active() -> bool:
	return coyote_timer > 0.0


func start_coyote() -> void:
	coyote_timer = stats.coyote_time


func can_dash() -> bool:
	if dash_cooldown_timer > 0.0:
		return false
	return is_on_floor() or dash_charges_left > 0


func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(0.0, coyote_timer - delta)
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	weapon_cooldown_timer = maxf(0.0, weapon_cooldown_timer - delta)
	if _boost_left > 0.0:
		_boost_left -= delta
		if _boost_left <= 0.0:
			speed_boost = 1.0
