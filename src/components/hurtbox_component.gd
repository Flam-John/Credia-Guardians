class_name HurtboxComponent
extends Area2D
## Receives hits and forwards them to a HealthComponent, honoring
## invulnerability. Hurtboxes are SCANNED: collision_layer = own hurtbox
## layer, collision_mask = 0 (docs/TDD.md §2.6).

signal hurt(hitbox: HitboxComponent)

@export var health: HealthComponent
## Optional veto — e.g. the player wires dash i-frames / shield arc in here.
## Signature: func(hitbox: HitboxComponent) -> bool (true = hit is negated).
var negate_check: Callable = Callable()

var _invuln_left := 0.0


func _ready() -> void:
	collision_mask = 0
	monitoring = false
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_invuln_left -= delta
	if _invuln_left <= 0.0:
		set_physics_process(false)


func start_invuln(seconds: float) -> void:
	_invuln_left = seconds
	set_physics_process(true)


func is_invulnerable() -> bool:
	return _invuln_left > 0.0


func receive_hit(hitbox: HitboxComponent) -> void:
	if is_invulnerable():
		return
	if negate_check.is_valid() and negate_check.call(hitbox):
		return
	if health != null:
		health.damage(hitbox.damage)
	hurt.emit(hitbox)
