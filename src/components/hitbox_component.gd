class_name HitboxComponent
extends Area2D
## Deals damage to HurtboxComponents it overlaps while active.
## Convention (docs/TDD.md §2.6): hitboxes SCAN — collision_layer stays 0,
## collision_mask = the target hurtbox layer. Monitoring is off until
## activate() so idle hitboxes cost nothing.

@export var damage := 1
@export var knockback_force := 120.0

## Targets already hit during the current activation (no double-hit per swing).
var _hit_targets: Array = []


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	monitoring = false
	area_entered.connect(_on_area_entered)


func activate() -> void:
	_hit_targets.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false
	_hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as HurtboxComponent
	if hurtbox == null or _hit_targets.has(hurtbox):
		return
	_hit_targets.append(hurtbox)
	hurtbox.receive_hit(self)
