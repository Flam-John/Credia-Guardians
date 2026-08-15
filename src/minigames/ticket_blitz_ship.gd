class_name TicketBlitzShip
extends Area2D
## Player-controlled ship in Ticket Blitz — free 8-directional movement in a
## bounded playfield, firing the SAME weapon look/feel as the real Player
## (stats.weapon_color/bullet_speed/weapon_cooldown), reused for visual and
## input consistency ("same mood, current character(s)", not a new cast).
## Movement/fire reuse the exact GAMEPLAY_ACTIONS base/p1_/p2_ scoping
## Player.action() already uses — no new input scheme to learn or wire.

signal fire_requested(from: Vector2, tint: Color, speed: float, damage: int)
signal hit_by_ticket

const SPEED := 140.0

var player_index := 0
var stats: CharacterStats
var bounds := Rect2(40, 40, 400, 200)
var sprite: AnimatedSprite2D

var _cooldown := 0.0
var _invuln := 0.0


func _ready() -> void:
	# NOT wired to area_entered — TicketBlitzMinigame._check_collisions()
	# drives ticket contact via manual AABB overlap instead (area_entered
	# never fires while the stage is paused, which it is for this whole
	# minigame — see that class's doc comment).
	collision_layer = PhysicsLayers.MINIGAME_PLAYER
	collision_mask = PhysicsLayers.MINIGAME_TARGET
	monitoring = false
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	shape.position = Vector2(0, -8)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(0, -16)
	add_child(sprite)


## Must be called AFTER add_child (mirrors TicketBlitzTicket.setup).
func setup(p_index: int, p_stats: CharacterStats, p_bounds: Rect2) -> void:
	player_index = p_index
	stats = p_stats
	bounds = p_bounds
	sprite.sprite_frames = SpriteFramesBuilder.build_player_frames(stats.sheet)
	sprite.play(&"idle")


func _action(base: StringName) -> StringName:
	return CoopInput.scoped_action(base, player_index)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_invuln = maxf(0.0, _invuln - delta)
	var axis := Vector2(
			Input.get_axis(_action(&"move_left"), _action(&"move_right")),
			Input.get_axis(_action(&"move_up"), _action(&"move_down")))
	if axis.length() > 0.0:
		axis = axis.normalized()
		sprite.flip_h = axis.x < 0.0
	global_position += axis * SPEED * delta
	global_position.x = clampf(global_position.x, bounds.position.x, bounds.end.x)
	global_position.y = clampf(global_position.y, bounds.position.y, bounds.end.y)
	if Input.is_action_pressed(_action(&"fire")) and _cooldown <= 0.0:
		_fire()


func _fire() -> void:
	_cooldown = stats.weapon_cooldown
	fire_requested.emit(
			global_position + Vector2(0, -20), stats.weapon_color,
			stats.bullet_speed, stats.weapon_damage)
	AudioManager.play_sfx("weapon_fire_chris" if stats.bullet_visual == "PACKET_BOLT" \
			else "weapon_fire_flam")


func _on_area_entered(area: Area2D) -> void:
	var ticket := area as TicketBlitzTicket
	if ticket == null or _invuln > 0.0:
		return
	# Only the dangerous tier actually costs a strike on contact (docs/GDD
	# gate-minigame notes) — low/mid tickets brushing past is not punished,
	# keeping the genre's usual "letting one through" forgiving.
	if ticket.tier == TicketBlitzTicket.Tier.HIGH:
		_invuln = 0.6
		hit_by_ticket.emit()
		sprite.modulate = Color(1.0, 0.35, 0.35)
		get_tree().create_timer(0.15).timeout.connect(
				func() -> void: sprite.modulate = Color.WHITE)
