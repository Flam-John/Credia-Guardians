class_name LevelServices
extends Node
## THE pooled-effects service for any gameplay scene (stages, boss rush).
## One class owns the pools and the score-popup wiring — previously this was
## a duck-typed convention spread across four files, and boss rush's hand
## copy had already drifted (review P3-15, P4-26).
##
## Consumers resolve it via `LevelServices.find(tree)`; entities never touch
## pool internals.

const PROJECTILE_SCENE := preload("res://scenes/entities/props/projectile.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/fx/hit_spark.tscn")
const SCORE_POPUP_SCENE := preload("res://scenes/fx/score_popup.tscn")

var projectile_pool: ObjectPool
var spark_pool: ObjectPool
var popup_pool: ObjectPool


static func find(tree: SceneTree) -> LevelServices:
	return tree.get_first_node_in_group(&"level_services") as LevelServices


func _ready() -> void:
	add_to_group(&"level_services")
	var parent := get_parent()
	projectile_pool = ObjectPool.new(PROJECTILE_SCENE, parent, 12, 32)
	spark_pool = ObjectPool.new(HIT_SPARK_SCENE, parent, 8, 16)
	popup_pool = ObjectPool.new(SCORE_POPUP_SCENE, parent, 6, 16)
	EventBus.enemy_killed.connect(_on_enemy_killed)


func acquire_projectile() -> Projectile:
	return projectile_pool.acquire()


func spawn_hit_spark(at_global: Vector2) -> void:
	var spark: HitSpark = spark_pool.acquire()
	spark.burst(at_global)


func spawn_score_popup(at_global: Vector2, amount: int) -> void:
	var popup: ScorePopup = popup_pool.acquire()
	popup.show_amount(at_global, amount)


func _on_enemy_killed(score: int, world_pos: Vector2) -> void:
	spawn_score_popup(world_pos, score)
