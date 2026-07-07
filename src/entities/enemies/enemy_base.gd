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

@export var stats: EnemyStats
## Off-screen sleeping (docs/PERFORMANCE.md). Tests disable it: headless runs
## never render, so a sleeper would never wake.
@export var sleep_when_offscreen := true

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


func _ready() -> void:
	assert(stats != null, "%s needs an EnemyStats resource" % name)
	collision_layer = PhysicsLayers.ENEMY
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLATFORM_ONEWAY
	sprite.sprite_frames = SpriteFramesBuilder.build_enemy_frames(stats.sheet, stats.layout_key)
	_build_components()
	state_machine.setup(self, stats)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if _knockback_x != 0.0:
		_knockback_x = move_toward(_knockback_x, 0.0, KNOCKBACK_DECAY * delta)
		velocity.x = _knockback_x
	else:
		state_machine.physics_update(delta)
	move_and_slide()


func set_facing(dir: int) -> void:
	if dir == 0:
		return
	facing = signi(dir)
	sprite.flip_h = facing > 0 # placeholder art faces left by default


func play(anim: StringName) -> void:
	sprite.play(anim)


## The tracked player, or null. Cheap: group lookup, no scene coupling.
func find_player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


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
	var contact := Area2D.new()
	contact.collision_layer = 0
	contact.collision_mask = PhysicsLayers.PLAYER
	contact.add_child(_body_shape_copy())
	contact.body_entered.connect(_on_player_contact)
	add_child(contact)

	if sleep_when_offscreen:
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
	_knockback_x = signf(global_position.x - from_global_pos.x) * 90.0
	_on_took_hit()


## Per-enemy hook (e.g. Junior Banker checks for panic threshold).
func _on_took_hit() -> void:
	pass


func _on_hurtbox_hurt(hitbox: HitboxComponent) -> void:
	take_hit(hitbox.damage, hitbox.global_position)


func _on_player_contact(body: Node2D) -> void:
	var player := body as Player
	if player == null or _dying:
		return
	var falling_onto := player.velocity.y > 0.0 \
			and player.global_position.y < global_position.y - STOMP_HEIGHT
	if stats.stompable and falling_onto:
		player.velocity.y = STOMP_BOUNCE
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
