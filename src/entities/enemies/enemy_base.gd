class_name EnemyBase
extends CharacterBody2D
## Shared enemy plumbing: gravity, components (code-built from EnemyStats),
## contact damage vs stomp resolution, hurt flash + knockback, death.
## Behavior lives in per-enemy State children of $StateMachine.

const GRAVITY := 900.0
const MAX_FALL := 320.0
const STOMP_BOUNCE := -240.0
## Player must be at least this far above the enemy center to count as a stomp.
const STOMP_HEIGHT := 6.0
const KNOCKBACK_DECAY := 600.0
## No enemy has business existing this far below any room; freed quietly.
const FALL_DESPAWN_Y := 1000.0

@export var stats: EnemyStats
## Off-screen sleeping (docs/PERFORMANCE.md). Tests disable it: headless runs
## never render, so a sleeper would never wake.
@export var sleep_when_offscreen := true
## AI Banker floats; everyone else falls.
@export var affected_by_gravity := true

var facing := -1
## Angry Manager sets this in WallStun (double damage window).
var damage_taken_multiplier := 1.0
var _knockback_x := 0.0
var _dying := false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var state_machine: StateMachine = $StateMachine

var health: HealthComponent
var hurtbox: HurtboxComponent
var flash: FlashComponent
var loot: LootComponent
var _contact_area: Area2D


func _ready() -> void:
	assert(stats != null, "%s needs an EnemyStats resource" % name)
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLATFORM_ONEWAY
	if stats.layout_key != "": # bosses build their own non-square frames
		sprite.sprite_frames = SpriteFramesBuilder.build_enemy_frames(stats.sheet, stats.layout_key)
	_build_components()
	state_machine.setup(self, stats)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	if affected_by_gravity:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	# FSM ALWAYS ticks — skipping it during knockback froze punish-window
	# timers, letting rapid hits hold bosses in Stagger forever (review P2-12).
	# Knockback just overrides horizontal control for its ~0.15s.
	state_machine.physics_update(delta)
	if _knockback_x != 0.0:
		_knockback_x = move_toward(_knockback_x, 0.0, KNOCKBACK_DECAY * delta)
		velocity.x = _knockback_x
	move_and_slide()
	# POLLED contact (not *_entered edges): a player parked inside the enemy
	# after their i-frames expire must keep taking hits. has_overlapping is
	# allocation-free; the array only materializes on actual overlap.
	# (monitoring check: Loan Shark disables contact while hidden)
	if _contact_area.monitoring and _contact_area.has_overlapping_bodies():
		for overlapping in _contact_area.get_overlapping_bodies():
			_resolve_player_contact(overlapping)
	# fell out of the world (panicking bankers may run off ledges by design)
	if global_position.y > FALL_DESPAWN_Y:
		queue_free()


func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing = signi(dir)
	sprite.flip_h = facing > 0 # placeholder art faces left by default


func play(anim: StringName) -> void:
	sprite.play(anim)


## Nearest LIVING player, or null. Iterates the static registry — no group
## array allocation, no targeting of corpses (review P1-6).
func find_player() -> Player:
	var best: Player = null
	var best_distance := INF
	for p in Player.alive:
		if not is_instance_valid(p):
			continue
		var d := p.global_position.distance_squared_to(global_position)
		if d < best_distance:
			best_distance = d
			best = p
	return best


const PROJECTILE_SCENE := preload("res://scenes/entities/props/projectile.tscn")

## Fire through the level's pool when one exists (group "level_root"),
## otherwise instantiate directly (debug rooms, tests).
func spawn_projectile(from: Vector2, vel: Vector2, visual: Projectile.Visual,
		dmg := 1, grav := 0.0) -> void:
	var level := get_tree().get_first_node_in_group(&"level_root")
	var projectile: Projectile
	if level != null and level.has_method("acquire_projectile"):
		projectile = level.acquire_projectile()
	else:
		projectile = PROJECTILE_SCENE.instantiate()
		get_parent().add_child(projectile)
	projectile.launch(from, vel, visual, dmg, grav)
	AudioManager.play_sfx("projectile")


# -- Damage --------------------------------------------------------------------

func _build_components() -> void:
	health = HealthComponent.new()
	health.max_hp = stats.max_hp
	health.died.connect(_die)
	add_child(health)

	hurtbox = HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.ENEMY_HURTBOX
	hurtbox.health = null # damage routed through take_hit for the multiplier
	hurtbox.hurt.connect(_on_hurtbox_hurt)
	var hurt_shape := _body_shape_copy()
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	flash = FlashComponent.new()
	flash.target = sprite
	add_child(flash)

	loot = LootComponent.new()
	loot.loot_scene = stats.loot_scene
	loot.count = stats.loot_count
	add_child(loot)

	# Contact: hurts the player on touch, unless it's a valid stomp.
	# Deliberately scans the player BODY layer (not the hurtbox): stomp
	# resolution needs body velocity/position. Polled in _physics_process.
	_contact_area = Area2D.new()
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = PhysicsLayers.PLAYER
	_contact_area.add_child(_body_shape_copy())
	add_child(_contact_area)

	if sleep_when_offscreen and stats.layout_key != "":
		var enabler := VisibleOnScreenEnabler2D.new()
		enabler.enable_mode = VisibleOnScreenEnabler2D.ENABLE_MODE_ALWAYS
		var frame_px: float = SpriteFramesBuilder.ENEMY_LAYOUTS[stats.layout_key].size
		enabler.rect = Rect2(-frame_px / 2.0, -frame_px, frame_px, frame_px)
		add_child(enabler)


func _body_shape_copy() -> CollisionShape2D:
	var src := get_node("Collision") as CollisionShape2D
	return src.duplicate()


func take_hit(damage: int, from_global_pos: Vector2) -> void:
	if _dying:
		return
	var applied := health.damage(int(damage * damage_taken_multiplier))
	if applied <= 0:
		return
	flash.flash()
	AudioManager.play_sfx("enemy_hurt")
	GameFeel.hitstop(get_tree())
	FxService.hit_spark(get_tree(), global_position + Vector2(0, -10))
	_knockback_x = signf(global_position.x - from_global_pos.x) * 90.0
	_on_took_hit()


## Per-enemy hook (e.g. Junior Banker checks for panic threshold).
func _on_took_hit() -> void:
	pass


func _on_hurtbox_hurt(hitbox: HitboxComponent) -> void:
	take_hit(hitbox.damage, hitbox.global_position)


func _resolve_player_contact(body: Node2D) -> void:
	var player := body as Player
	if player == null or _dying:
		return
	var falling_onto := player.velocity.y > 0.0 \
			and player.global_position.y < global_position.y - STOMP_HEIGHT
	if stats.stompable and falling_onto:
		player.velocity.y = STOMP_BOUNCE
		# grace: next poll still overlaps but is no longer "falling onto" —
		# without this the bounce frame reads as contact damage
		player.hurtbox.start_invuln(0.25)
		AudioManager.play_sfx("stomp")
		take_hit(1, player.global_position)
	else:
		player.take_hit(stats.contact_damage, global_position)


func _die() -> void:
	_dying = true
	EventBus.enemy_killed.emit(stats.score_value, global_position)
	AudioManager.play_sfx("enemy_death")
	loot.drop(global_position)
	# no more interactions while the death anim plays
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	for child in get_children():
		if child is Area2D:
			child.set_deferred("monitoring", false)
	play(&"death")
	sprite.animation_finished.connect(queue_free)
