class_name AngryManager
extends EnemyBase
## Sight-triggered charger (docs/ENEMY_AI.md): Idle → Alert (0.4s telegraph)
## → Charge → WallStun (punish, double damage) / Cooldown.

const CHARGE_SPEED := 180.0
const CHARGE_MAX_DISTANCE := 200.0

var los_ray: RayCast2D
## Tests can force detection without physics raycasts.
var force_sees_player := false


func _ready() -> void:
	los_ray = RayCast2D.new()
	los_ray.position = Vector2(0, -12)
	los_ray.collision_mask = PhysicsLayers.WORLD
	los_ray.enabled = false # only Idle/Cooldown states enable it
	add_child(los_ray)
	super()


## Line of sight: player within range, roughly same height, no wall between.
func can_see_player() -> bool:
	if force_sees_player:
		return true
	var player := find_player()
	if player == null:
		return false
	var to_player := player.global_position - global_position
	if absf(to_player.y) > 16.0 or absf(to_player.x) > stats.detection_range:
		return false
	los_ray.target_position = Vector2(to_player.x, 0.0)
	los_ray.force_raycast_update()
	return not los_ray.is_colliding()
