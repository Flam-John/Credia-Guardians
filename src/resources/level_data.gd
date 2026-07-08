class_name LevelData
extends Resource
## Per-stage tuning (docs/TDD.md §2.5). Coin/node totals are counted from
## the level map at parse time, not duplicated here.

@export var stage_id := 1
@export var display_name := ""
@export var par_time_sec := 300.0
@export var next_stage_id := 0
@export var music_track := ""
@export var tileset_texture := "res://assets/art/tiles/tileset_office.png"
