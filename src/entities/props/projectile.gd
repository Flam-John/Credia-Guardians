class_name Projectile
extends Area2D
## Pooled projectile, shared by enemies and the player's weapons. Five
## visuals (ledger page / plasma orb / gold coin / packet bolt / ember),
## optional gravity arc. Dies on walls and after lifetime.

enum Visual { LEDGER, PLASMA, GOLD, PACKET_BOLT, EMBER }

const SHEET := preload("res://assets/art/props/projectiles.png")
const LIFETIME := 2.5

var damage := 1
var velocity := Vector2.ZERO
var arc_gravity := 0.0
## Player-fired bullets target enemies (ENEMY_HURTBOX); enemy projectiles
## target the player (PLAYER_HURTBOX, the default).
var friendly := false
var _life := 0.0
var _lifetime := LIFETIME
var _sprite: Sprite2D
var _atlas: AtlasTexture
var _wall_query: PhysicsPointQueryParameters2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsLayers.PLAYER_HURTBOX
	monitorable = false
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_atlas.region = Rect2(0, 0, 8, 8)
	_sprite = Sprite2D.new()
	_sprite.texture = _atlas
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	_wall_query = PhysicsPointQueryParameters2D.new()
	_wall_query.collision_mask = PhysicsLayers.WORLD


## Called by the spawner right after pool.acquire(). `life <= 0` keeps LIFETIME.
func launch(from: Vector2, vel: Vector2, visual: Visual, dmg := 1, grav := 0.0,
		is_friendly := false, life := 0.0) -> void:
	global_position = from
	velocity = vel
	damage = dmg
	arc_gravity = grav
	friendly = is_friendly
	collision_mask = PhysicsLayers.ENEMY_HURTBOX if friendly else PhysicsLayers.PLAYER_HURTBOX
	_lifetime = life if life > 0.0 else LIFETIME
	visible = true
	_atlas.region = Rect2(int(visual) * 8, 0, 8, 8)
	monitoring = true


func _pool_reset() -> void:
	_life = 0.0


func _physics_process(delta: float) -> void:
	_life += delta
	velocity.y += arc_gravity * delta
	global_position += velocity * delta
	_sprite.rotation += 8.0 * delta
	if _life >= _lifetime or _hit_wall():
		_despawn()


func _hit_wall() -> bool:
	_wall_query.position = global_position
	return not get_world_2d().direct_space_state.intersect_point(_wall_query, 1).is_empty()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null:
		return
	if friendly:
		var enemy := hurtbox.get_parent() as EnemyBase
		if enemy != null:
			enemy.take_hit(damage, global_position)
	else:
		var player := hurtbox.get_parent() as Player
		if player != null:
			player.take_hit(damage, global_position)
	_despawn()


func _despawn() -> void:
	set_deferred("monitoring", false)
	var pool: ObjectPool = get_meta(&"pool") if has_meta(&"pool") else null
	if pool != null:
		pool.release(self)
	else:
		queue_free()
