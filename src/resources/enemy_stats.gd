class_name EnemyStats
extends Resource
## Tuning for one enemy type (docs/GDD.md §6, docs/ENEMY_AI.md table).
## Data in data/enemies/*.tres.

@export_group("Identity")
@export var display_name := ""
@export var sheet: Texture2D
## Key into SpriteFramesBuilder.ENEMY_LAYOUTS (row table for the sheet).
@export var layout_key := ""

@export_group("Combat")
@export var max_hp := 2
@export var contact_damage := 1
@export var score_value := 200
@export var stompable := true

@export_group("Behavior")
@export var move_speed := 40.0
@export var detection_range := 120.0
@export var attack_cooldown := 0.0

@export_group("Loot")
@export var loot_scene: PackedScene
@export var loot_count := 0
