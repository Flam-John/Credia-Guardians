extends Node
## Run-state aggregator: score, lives, coins for the current stage attempt.
## Subscribes to EventBus; owns no scenes and holds no node references.
## Persistence is delegated to SaveManager (docs/DATA_FLOW.md §2, §5).

const STARTING_LIVES := 3

## Stage id -> scene path.
const STAGE_SCENES := {
	1: "res://scenes/levels/stage_1.tscn",
	2: "res://scenes/levels/stage_2.tscn",
	3: "res://scenes/levels/stage_3.tscn",
	4: "res://scenes/levels/stage_4.tscn",
	5: "res://scenes/levels/stage_5.tscn",
}
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

## Rank order matters: index = quality (0 worst). See docs/GDD.md §9.
enum Rank { D, C, B, A, S }

var character: StringName = &"chris"
## Co-op: second guardian; empty StringName = single-player.
var character2: StringName = &""
var stage_id: int = 1
## Scene the current run lives in — retry/restart route through this, so
## non-stage modes (boss rush) retry correctly (review P0-1).
var current_scene_path := ""
## One-shot: set by intro_cutscene right before launching stage 1 on a fresh
## new game, consumed by stage_1.gd the moment it actually spawns Zaf's
## in-game ghost intro (same "set before a scene change, consumed exactly
## once on the other side" pattern as SlotSelectFlow.force_new) — so a later
## re-entry into stage 1 (retry, replay) never shows it again.
var pending_zaf_intro := false


func is_coop() -> bool:
	return character2 != &""


## CONTINUE restores what the slot saved: a co-op slot resumes as co-op
## with the recorded partner, a solo slot resumes solo.
func continue_from_slot(data: Dictionary) -> void:
	hi_score = int(data.get("global_hi_score", 0))
	if bool(data.get("coop", false)):
		character2 = StringName(String(data.get("character2", "")))
	else:
		character2 = &""

var score: int = 0
var coins: int = 0
## Player-scoped lives (docs/GDD.md §4): keyed by Player.player_index — solo
## always uses key 0; co-op uses 1/2, one independent pool per Guardian, so
## a death only spends THAT player's own life, never the partner's. Use
## lives_for()/all_players_out_of_lives() rather than reading the dict raw.
var lives: Dictionary = {0: STARTING_LIVES}
var deaths_this_stage: int = 0
var stage_time: float = 0.0
var nodes_activated: int = 0
var hit_zero_lives: bool = false
## Best score on record for the active save slot (HUD display).
var hi_score: int = 0
## Score breakdown for the stage-clear tally (docs/GDD.md §9).
var enemy_score: int = 0
var coin_score: int = 0
## Stashed by the level on clear; read by the stage-clear screen.
var last_clear_stats: Dictionary = {}
## USB Security Keys held this stage attempt (docs/GDD.md §8).
var usb_keys: int = 0

var _stage_running := false


## Single point of mutation so the HUD counter can never drift from the
## real value — pickups and gates must call this instead of writing
## usb_keys directly.
func add_usb_keys(delta: int) -> void:
	usb_keys = maxi(0, usb_keys + delta)
	EventBus.usb_keys_changed.emit(usb_keys)


func is_stage_running() -> bool:
	return _stage_running


func lives_for(player_index: int) -> int:
	return int(lives.get(player_index, 0))


## True once every tracked player's pool is empty — RespawnController's
## game-over gate. NOT the same question as hit_zero_lives, which taints
## the stage rank the moment ANY single player's own pool empties, even if
## the team's run continues on the partner's remaining lives.
func all_players_out_of_lives() -> bool:
	for count in lives.values():
		if count > 0:
			return false
	return true


## Solo always tracks player_index 0; co-op gives each Guardian (1/2) their
## own independent pool, so one player's deaths never spend the other's.
func _fresh_lives() -> Dictionary:
	if is_coop():
		return {1: STARTING_LIVES, 2: STARTING_LIVES}
	return {0: STARTING_LIVES}


func character_stats(id: StringName = character) -> CharacterStats:
	return load("res://data/characters/%s.tres" % id)


## Menu flow entry: set up the run and load the stage scene.
## second_character non-empty = local co-op.
func launch_stage(new_stage_id: int, new_character: StringName,
		second_character: StringName = &"") -> void:
	assert(STAGE_SCENES.has(new_stage_id), "No scene for stage %d" % new_stage_id)
	if SceneManager.is_busy():
		return # never mutate run state for a transition that won't happen
	character2 = second_character
	current_scene_path = STAGE_SCENES[new_stage_id]
	start_stage(new_stage_id, new_character)
	SceneManager.change_scene(current_scene_path)


## Non-stage modes (boss rush) register themselves here so retry works.
func launch_custom(scene_path: String, new_character: StringName) -> void:
	if SceneManager.is_busy():
		return
	character2 = &"" # custom modes are solo unless they opt in
	current_scene_path = scene_path
	start_stage(0, new_character)
	SceneManager.change_scene(scene_path)


func retry_stage() -> void:
	if SceneManager.is_busy():
		return
	if current_scene_path.is_empty():
		quit_to_menu()
		return
	start_stage(stage_id, character)
	SceneManager.change_scene(current_scene_path)


func quit_to_menu() -> void:
	end_stage()
	character2 = &"" # co-op intent dies with the session (review P1-5)
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
	lives = _fresh_lives()
	deaths_this_stage = 0
	stage_time = 0.0
	nodes_activated = 0
	hit_zero_lives = false
	enemy_score = 0
	coin_score = 0
	add_usb_keys(-usb_keys) # reset to 0 and tell the HUD immediately
	_stage_running = true
	set_process(true)
	EventBus.score_changed.emit(score)


func end_stage() -> void:
	_stage_running = false
	set_process(false)


func add_score(amount: int) -> void:
	score += amount
	hi_score = maxi(hi_score, score) # promotion lives HERE, not in the HUD
	EventBus.score_changed.emit(score)


const FULL_AUDIT_BONUS := 5000


## Par-time bonus (docs/GDD.md §9): 10000 under/at par, -100 per second over.
static func compute_level_bonus(time_sec: float, par_sec: float) -> int:
	return maxi(0, 10000 - int(maxf(0.0, time_sec - par_sec)) * 100)


## The full stage-clear pipeline (docs/DATA_FLOW.md §5): bonuses, rank,
## persistence, stage_cleared broadcast. Levels supply only their static
## facts; the run aggregator owns the math — review P3-16.
## level_info: {stage_id, next_stage_id, par_time, total_coins, nodes,
##              total_nodes, hidden_rooms}
func complete_stage(level_info: Dictionary) -> Dictionary:
	end_stage()
	var level_bonus := compute_level_bonus(stage_time, level_info.par_time)
	var full_audit := FULL_AUDIT_BONUS if coins >= int(level_info.total_coins) else 0
	add_score(level_bonus + full_audit)
	var stats := {
		"stage_id": level_info.stage_id,
		"next_stage_id": level_info.next_stage_id,
		"character": character,
		"score": score,
		"time": stage_time,
		"par_time": level_info.par_time,
		"coins": coins,
		"total_coins": level_info.total_coins,
		"nodes": level_info.nodes,
		"total_nodes": level_info.total_nodes,
		"deaths": deaths_this_stage,
		"hit_zero_lives": hit_zero_lives,
		"hidden_rooms": level_info.hidden_rooms,
		"exp_score": enemy_score,
		"coin_score": coin_score,
		"level_bonus": level_bonus,
		"full_audit": full_audit,
	}
	stats["rank"] = rank_name(compute_rank(stats))
	last_clear_stats = stats
	if SaveManager.active_slot > 0:
		var save := SaveManager.load_slot(SaveManager.active_slot)
		if not save.is_empty():
			save = SaveManager.record_stage_clear(save, stats)
			save.last_character = String(character)
			save.play_time_sec = int(save.get("play_time_sec", 0)) + int(stage_time)
			SaveManager.write_slot(SaveManager.active_slot, save)
	EventBus.stage_cleared.emit(stats)
	return stats


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
	coin_score += value
	add_score(value)


func _on_enemy_killed(kill_score: int, _world_pos: Vector2) -> void:
	enemy_score += kill_score
	add_score(kill_score)


func _on_node_activated(_id: StringName, count: int, _total: int) -> void:
	nodes_activated = count
	add_score(500)


func _on_player_died(player: Node2D) -> void:
	deaths_this_stage += 1
	var idx: int = (player as Player).player_index
	lives[idx] = maxi(0, lives_for(idx) - 1)
	# taints the rank the moment THIS player runs out, even if the team's
	# run continues on the partner's remaining lives (all_players_out_of_
	# lives is the separate, stricter question RespawnController asks)
	if lives[idx] <= 0:
		hit_zero_lives = true
