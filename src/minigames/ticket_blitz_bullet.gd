class_name TicketBlitzBullet
extends Area2D
## Player-fired shot in Ticket Blitz. Deliberately NOT the main game's
## Projectile class — that one is wired to HurtboxComponent/PhysicsLayers
## enemy-vs-player semantics that don't apply here, so reusing it would mean
## fighting its coupling instead of a few lines of bespoke movement.

var velocity := Vector2.ZERO
var damage := 1
var _visual: ColorRect
var _bounds := Rect2()


func _ready() -> void:
	# NOT wired to area_entered — TicketBlitzMinigame._check_collisions()
	# drives hits via manual AABB overlap instead (see that class's doc
	# comment: area_entered never fires while the stage is paused, which it
	# is for this whole minigame). collision_layer/mask/shape are kept only
	# so a future debug overlay could still draw a correct-looking shape.
	collision_layer = PhysicsLayers.MINIGAME_PLAYER
	collision_mask = PhysicsLayers.MINIGAME_TARGET
	monitoring = false
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	_visual = ColorRect.new()
	_visual.size = Vector2(6, 6)
	_visual.position = Vector2(-3, -3)
	add_child(_visual)


func launch(from: Vector2, vel: Vector2, dmg: int, tint: Color, bounds: Rect2) -> void:
	global_position = from
	velocity = vel
	damage = dmg
	_visual.color = tint
	_bounds = bounds


func _physics_process(delta: float) -> void:
	_spawn_trail_ghost()
	global_position += velocity * delta
	if not _bounds.has_point(global_position):
		queue_free()


## A fading afterimage each physics tick (design polish, user request) —
## same one-shot fire-and-forget pattern as TicketBlitzTicket._burst, just
## a plain fading ColorRect instead of particles (a bullet's own trail is a
## smear, not a burst).
##
## Bug fix: the fade tween used to be created via this bullet's own
## create_tween() (i.e. bound to self) — but a bullet is almost always
## freed the very next tick (on hitting a ticket, or leaving bounds), and
## while the whole stage is paused (which it is for this entire minigame),
## a Tween bound to a node that gets freed mid-animation can lose track of
## whether it's still allowed to keep running and freeze instead of
## finishing — leaving that one ghost stuck fully visible forever, which
## piles up over a wave into exactly the litter of frozen bars this was
## reported as. Binding the tween to the ghost ITSELF instead fixes this:
## the ghost only needs to survive its own 0.15s fade and nothing else
## ever frees it early.
func _spawn_trail_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ghost := ColorRect.new()
	ghost.color = _visual.color
	ghost.size = _visual.size * 0.7
	ghost.position = global_position - ghost.size / 2.0
	parent.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.15)
	tween.tween_callback(ghost.queue_free)


func _on_area_entered(area: Area2D) -> void:
	var ticket := area as TicketBlitzTicket
	if ticket != null:
		ticket.hit(damage)
	queue_free()
