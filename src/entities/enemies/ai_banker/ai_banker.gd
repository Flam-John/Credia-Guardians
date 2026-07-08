class_name AIBanker
extends EnemyBase
## Corrupted AI Banker (docs/ENEMY_AI.md): floating hologram, teleports
## between 3 anchors, fires 3-projectile fans, summons a Junior Banker once
## per 50% HP lost. Vulnerable in the post-cast stagger.

const JUNIOR_SCENE := preload("res://scenes/entities/enemies/junior_banker.tscn")
const MAX_MINIONS := 2

## Teleport anchors, relative to spawn. Set before add or use defaults.
@export var anchor_offsets: Array[Vector2] = [
	Vector2(-60, 0), Vector2(0, -40), Vector2(60, 0),
]

var anchors: Array[Vector2] = []
var current_anchor := 0
var summons_left := 1
var _minions: Array[Node] = []


func _ready() -> void:
	affected_by_gravity = false
	super()
	for offset in anchor_offsets:
		anchors.append(global_position + offset)
	health.damaged.connect(_check_summon_threshold)


func next_anchor() -> Vector2:
	# deterministic hop: always move to a DIFFERENT anchor
	current_anchor = (current_anchor + 1 + (health.hp % (anchors.size() - 1))) \
			% anchors.size()
	return anchors[current_anchor]


func player_in_range() -> bool:
	var player := find_player()
	return player != null \
			and player.global_position.distance_to(global_position) <= stats.detection_range


func summon_minion() -> void:
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m))
	if _minions.size() >= MAX_MINIONS:
		return
	var junior: Node2D = JUNIOR_SCENE.instantiate()
	junior.position = global_position + Vector2(0, 8)
	get_parent().add_child(junior)
	_minions.append(junior)
	AudioManager.play_sfx("ai_teleport")


var _summon_pending := false

func _check_summon_threshold(_amount: int, hp: int, max_hp: int) -> void:
	if summons_left > 0 and hp <= max_hp / 2:
		summons_left -= 1
		_summon_pending = true


func consume_summon_request() -> bool:
	if _summon_pending:
		_summon_pending = false
		return true
	return false
