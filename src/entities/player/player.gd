class_name Player
extends CharacterBody2D
## Player body: shared per-frame plumbing (gravity, timers, buffers, charges).
## Behavior lives in the State children of $StateMachine (docs/PLAYER_FSM.md).
## Chris vs Flam differences come entirely from the injected CharacterStats.

@export var stats: CharacterStats

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var state_machine: StateMachine = $StateMachine
@onready var camera: PlayerCamera = $Camera

var facing := 1
var air_jumps_left := 1
var dash_charges_left := 1
## Owned exclusively by DashState. Other i-frame sources (hurt invulnerability
## in M2) get their own flags; the damage pipeline asks is_invulnerable().
var dash_iframes_active := false

# Countdown timers, ticked here every physics frame (docs/PLAYER_FSM.md).
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_cooldown_timer := 0.0


func _ready() -> void:
	assert(stats != null, "Player needs a CharacterStats resource")
	sprite.sprite_frames = SpriteFramesBuilder.build_player_frames(stats.sheet)
	state_machine.setup(self, stats)
	EventBus.player_spawned.emit(self)


## Camera handshake for spawners (levels, debug rooms): limits, then snap,
## then make current — callers never touch the camera child directly.
func activate_camera(limits: Rect2) -> void:
	camera.setup_limits(limits)
	camera.snap_to_target()
	camera.make_current()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = stats.jump_buffer
	if not state_machine.current.overrides_gravity:
		apply_gravity(delta)
	state_machine.physics_update(delta)
	move_and_slide()
	# INVARIANT: charge reset stays AFTER move_and_slide — is_on_floor() is
	# only fresh post-slide, so a same-frame landing refreshes air options.
	if is_on_floor():
		air_jumps_left = 1
		dash_charges_left = stats.air_dash_charges


func _unhandled_input(event: InputEvent) -> void:
	state_machine.handle_input(event)


# -- Helpers shared by states -------------------------------------------------

## Single query point for the damage pipeline; each i-frame source ORs in here.
func is_invulnerable() -> bool:
	return dash_iframes_active


func apply_gravity(delta: float) -> void:
	var g := stats.gravity_rise if velocity.y < 0.0 else stats.gravity_fall
	velocity.y = minf(velocity.y + g * delta, stats.max_fall_speed)


func input_axis() -> float:
	return Input.get_axis(&"move_left", &"move_right")


## Ground movement: accelerate toward input, brake with friction.
func ground_move(delta: float) -> void:
	var axis := input_axis()
	if absf(axis) > 0.0:
		velocity.x = move_toward(velocity.x, axis * stats.run_speed, stats.ground_accel * delta)
		set_facing(signf(axis))
	else:
		velocity.x = move_toward(velocity.x, 0.0, stats.ground_friction * delta)


## Air movement: same target speed, reduced authority.
func air_move(delta: float) -> void:
	var axis := input_axis()
	if absf(axis) > 0.0:
		velocity.x = move_toward(
			velocity.x, axis * stats.run_speed, stats.ground_accel * stats.air_control * delta)
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
