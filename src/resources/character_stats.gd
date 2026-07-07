class_name CharacterStats
extends Resource
## All tuning for a playable character (docs/GDD.md §3–4). Designers edit the
## .tres in data/characters/ — code never hardcodes these values.

@export_group("Identity")
@export var display_name := ""
@export var sheet: Texture2D

@export_group("Health")
@export var max_hp := 6

@export_group("Movement")
@export var run_speed := 95.0
@export var ground_accel := 900.0
@export var ground_friction := 1100.0
@export_range(0.0, 1.0) var air_control := 0.75

@export_group("Jump")
@export var jump_velocity := -290.0
@export var double_jump_velocity := -260.0
@export var gravity_rise := 900.0
@export var gravity_fall := 1150.0
@export var max_fall_speed := 320.0
@export var coyote_time := 0.10
@export var jump_buffer := 0.12
## Velocity multiplier when jump is released during ascent (short hops).
@export var jump_cut_multiplier := 0.45

@export_group("Dash")
@export var dash_speed := 240.0
@export var dash_duration := 0.12
@export var dash_cooldown := 0.6
@export var air_dash_charges := 1
@export var dash_has_iframes := false
## Flam: dashing through enemies deals contact damage (used from M2).
@export var dash_deals_damage := false

@export_group("Signature ability")
@export var has_shield := false
@export var shield_capacity := 3.0
@export var shield_regen_delay := 1.5
@export var shield_regen_rate := 1.0

@export_group("Combat")
@export var attack_damage := 1
