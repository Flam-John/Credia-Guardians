class_name SecurityCamera
extends StaticBody2D
## Wall camera (Corporate HQ): spawns Junior Bankers while the player is in
## range, until smashed. 2 HP, +300 pts.

const JUNIOR_SCENE := preload("res://scenes/entities/enemies/junior_banker.tscn")
const SPAWN_INTERVAL := 4.0
const MAX_ALIVE := 2
const RANGE := 150.0
const SCORE := 300

var _spawn_timer := 1.5
var _minions: Array[Node] = []
var _sprite: Polygon2D
var health: HealthComponent


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	# simple drawn camera: dark wedge + red lens
	_sprite = Polygon2D.new()
	_sprite.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 4)])
	_sprite.color = Color("3a4656")
	add_child(_sprite)
	var lens := Polygon2D.new()
	lens.polygon = PackedVector2Array([
		Vector2(4, -3), Vector2(8, -4), Vector2(8, 4), Vector2(4, 3)])
	lens.color = Color("ff3040")
	add_child(lens)

	health = HealthComponent.new()
	health.max_hp = 2
	health.died.connect(_die)
	add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.collision_layer = PhysicsLayers.ENEMY_HURTBOX
	hurtbox.health = health
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 14)
	shape.shape = rect
	hurtbox.add_child(shape)
	hurtbox.hurt.connect(func(_h: HitboxComponent) -> void:
		AudioManager.play_sfx("enemy_hurt"))
	add_child(hurtbox)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or global_position.distance_to(player.global_position) > RANGE:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m))
	if _minions.size() >= MAX_ALIVE:
		return
	var junior: Node2D = JUNIOR_SCENE.instantiate()
	junior.position = global_position + Vector2(0, 8)
	get_parent().add_child(junior)
	_minions.append(junior)
	AudioManager.play_sfx("ai_teleport")


func _die() -> void:
	EventBus.enemy_killed.emit(SCORE, global_position)
	AudioManager.play_sfx("enemy_death")
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
