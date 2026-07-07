extends Node
## Run-state aggregator: score, lives, coins for the current stage attempt.
## Subscribes to EventBus; owns no scenes and holds no node references.
## Persistence is delegated to SaveManager (docs/DATA_FLOW.md §2, §5).

const STARTING_LIVES := 3

## Stage id -> scene path. Stage 1 points at the combat room until M4 builds
## the real Developer Office.
const STAGE_SCENES := {
	1: "res://tests/debug_scenes/combat_room.tscn",
}
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

## Rank order matters: index = quality (0 worst). See docs/GDD.md §9.
enum Rank { D, C, B, A, S }

var character: StringName = &"chris"
var stage_id: int = 1

var score: int = 0
var coins: int = 0
var lives: int = STARTING_LIVES
var deaths_this_stage: int = 0
var stage_time: float = 0.0
var nodes_activated: int = 0
var hit_zero_lives: bool = false
## Best score on record for the active save slot (HUD display).
var hi_score: int = 0

var _stage_running := false


func is_stage_running() -> bool:
	return _stage_running


func character_stats(id: StringName = character) -> CharacterStats:
	return load("res://data/characters/%s.tres" % id)


## Menu flow entry: set up the run and load the stage scene.
func launch_stage(new_stage_id: int, new_character: StringName) -> void:
	assert(STAGE_SCENES.has(new_stage_id), "No scene for stage %d" % new_stage_id)
	start_stage(new_stage_id, new_character)
	SceneManager.change_scene(STAGE_SCENES[new_stage_id])


func retry_stage() -> void:
	launch_stage(stage_id, character)


func quit_to_menu() -> void:
	end_stage()
	get_tree().paused = false
	SceneManager.change_scene(MENU_SCENE)


func _ready() -> void:
	EventBus.coin_collected.connect(_on_coin_collected)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.node_activated.connect(_on_node_activated)
	EventBus.player_died.connect(_on_player_died)
	set_process(false) # only ticks while a stage runs


func _process(delta: float) -> void:
	if not get_tree().paused:
		stage_time += delta


func start_stage(new_stage_id: int, new_character: StringName) -> void:
	stage_id = new_stage_id
	character = new_character
	score = 0
	coins = 0
	lives = STARTING_LIVES
	deaths_this_stage = 0
	stage_time = 0.0
	nodes_activated = 0
	hit_zero_lives = false
	_stage_running = true
	set_process(true)
	EventBus.score_changed.emit(score)


func end_stage() -> void:
	_stage_running = false
	set_process(false)


func add_score(amount: int) -> void:
	score += amount
	EventBus.score_changed.emit(score)


## Computes the stage rank from clear stats (docs/GDD.md §9).
## stats: {coins: int, total_coins: int, nodes: int, total_nodes: int,
##         time: float, par_time: float, deaths: int, hit_zero_lives: bool}
func compute_rank(stats: Dictionary) -> Rank:
	var all_nodes: bool = stats.nodes >= stats.total_nodes
	# A coinless stage satisfies every coin criterion vacuously.
	var coin_pct: float = 1.0 if stats.total_coins <= 0 \
			else float(stats.coins) / float(stats.total_coins)
	if stats.hit_zero_lives:
		return Rank.D
	if coin_pct >= 1.0 and all_nodes and stats.time <= stats.par_time and stats.deaths == 0:
		return Rank.S
	if coin_pct >= 0.9 and all_nodes and stats.deaths <= 1:
		return Rank.A
	if coin_pct >= 0.7 and all_nodes:
		return Rank.B
	return Rank.C


func rank_name(rank: Rank) -> String:
	return Rank.keys()[rank]


func _on_coin_collected(value: int) -> void:
	coins += 1
	add_score(value)


func _on_enemy_killed(enemy_score: int, _world_pos: Vector2) -> void:
	add_score(enemy_score)


func _on_node_activated(_id: StringName, count: int, _total: int) -> void:
	nodes_activated = count
	add_score(500)


func _on_player_died() -> void:
	deaths_this_stage += 1
	lives -= 1
	if lives <= 0:
		hit_zero_lives = true
