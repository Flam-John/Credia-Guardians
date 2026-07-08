class_name LevelBase
extends Node2D
## Real-stage foundation: parses an ASCII map with ENTITY MARKERS into
## terrain + spawned objects, owns the objective/clear flow.
##
## Marker legend (terrain chars pass through to AsciiRoomBuilder):
##   P player spawn      c coin              o coffee        e energy drink
##   J junior banker     M angry manager     k checkpoint    N security node
##   E exit gate         X crumbling platform
##   > / < conveyor run (consecutive)        = moving platform span
##   ~ updraft column (consecutive vertical)
## Hidden rooms are tile-rect regions provided by the stage subclass.

const T := 16

const COIN_SCENE := preload("res://scenes/entities/collectibles/coin.tscn")
const PICKUP_SCENE := preload("res://scenes/entities/collectibles/pickup.tscn")
const JUNIOR_SCENE := preload("res://scenes/entities/enemies/junior_banker.tscn")
const MANAGER_SCENE := preload("res://scenes/entities/enemies/angry_manager.tscn")
const AUDITOR_SCENE := preload("res://scenes/entities/enemies/auditor.tscn")
const SHARK_SCENE := preload("res://scenes/entities/enemies/loan_shark.tscn")
const AI_BANKER_SCENE := preload("res://scenes/entities/enemies/ai_banker.tscn")
const AI_ELITE_SCENE := preload("res://scenes/entities/enemies/ai_banker_elite.tscn")
const REGIONAL_SCENE := preload("res://scenes/entities/enemies/regional_manager.tscn")
const CEO_SCENE := preload("res://scenes/entities/bosses/ceo_boss.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/props/projectile.tscn")
const HIT_SPARK_SCENE := preload("res://scenes/fx/hit_spark.tscn")
const FULL_AUDIT_BONUS := 5000

@export var data: LevelData

## Set by the stage subclass before _ready (usually in its own script).
var map := ""
## Tile-space rects for hidden rooms, e.g. Rect2(10, 4, 6, 4).
var hidden_room_rects: Array[Rect2] = []

var total_coins := 0
var total_nodes := 0
var nodes_active := 0
var hidden_found: Array[bool] = []
var respawner: RespawnController

var _gate: ExitGate
var _spawn_tile := Vector2i(2, 2)
var _cleared := false
var _mover_count := 0
## When a 'C' marker spawns the CEO, the exit gate also requires his defeat.
var _boss_alive := false


var projectile_pool: ObjectPool
var spark_pool: ObjectPool


func acquire_projectile() -> Projectile:
	return projectile_pool.acquire()


func acquire_hit_spark() -> HitSpark:
	return spark_pool.acquire()


func _ready() -> void:
	assert(data != null, "LevelBase needs a LevelData resource")
	add_to_group(&"level_root")
	projectile_pool = ObjectPool.new(PROJECTILE_SCENE, self, 12, 32)
	spark_pool = ObjectPool.new(HIT_SPARK_SCENE, self, 8, 16)
	var terrain := _extract_entities(map)
	var builder := AsciiRoomBuilder.new()
	builder.map = terrain
	builder.tileset_texture = data.tileset_texture
	add_child(builder)
	# entities were spawned during extraction (earlier siblings) — terrain
	# must draw BEHIND them, so it goes to the front of the child list
	move_child(builder, 0)
	_build_parallax()
	add_child(DebugOverlay.new())

	if not GameManager.is_stage_running():
		GameManager.start_stage(data.stage_id, &"chris")

	respawner = RespawnController.new()
	respawner.spawn_point = Vector2(_spawn_tile.x * T + 8, _spawn_tile.y * T + 15)
	respawner.camera_limits = Rect2(Vector2.ZERO, builder.room_size)
	add_child(respawner)
	respawner.spawn(GameManager.character_stats())

	for i in hidden_room_rects.size():
		hidden_found.append(false)
		var room := HiddenRoom.new()
		room.index = i
		room.setup(Rect2(hidden_room_rects[i].position * T, hidden_room_rects[i].size * T))
		room.found.connect(_on_hidden_found)
		add_child(room)

	if data.music_track != "":
		AudioManager.play_music(data.music_track)
	EventBus.enemy_killed.connect(_on_enemy_killed)


## Strips entity markers from the map (spawning them) and returns pure
## terrain for the tile builder.
func _extract_entities(source: String) -> String:
	var lines := source.split("\n")
	# trim blank first/last lines the same way AsciiRoomBuilder does
	while not lines.is_empty() and lines[0].strip_edges().is_empty():
		lines.remove_at(0)
	while not lines.is_empty() and lines[-1].strip_edges().is_empty():
		lines.remove_at(lines.size() - 1)

	var grid: Array = []
	for line in lines:
		grid.append(line)

	for y in grid.size():
		var line: String = grid[y]
		var x := 0
		while x < line.length():
			var ch := line[x]
			var consumed := 1
			match ch:
				"P":
					_spawn_tile = Vector2i(x, y)
				"c":
					_place(COIN_SCENE, x, y)
					total_coins += 1
				"o":
					_place_pickup(Pickup.Kind.COFFEE, x, y)
				"e":
					_place_pickup(Pickup.Kind.ENERGY_DRINK, x, y)
				"J":
					_place(JUNIOR_SCENE, x, y)
				"M":
					_place(MANAGER_SCENE, x, y)
				"A":
					_place(AUDITOR_SCENE, x, y)
				"L":
					_place(SHARK_SCENE, x, y)
				"B":
					_place(AI_BANKER_SCENE, x, y)
				"W":
					_place_pickup(Pickup.Kind.FIREWALL_SHIELD, x, y)
				"K":
					_place_pickup(Pickup.Kind.KEYBOARD_UPGRADE, x, y)
				"U":
					_place_pickup(Pickup.Kind.USB_KEY, x, y)
				"F":
					var firewall := FirewallGate.new()
					firewall.position = _tile_bottom(x, y)
					add_child(firewall)
				"m":
					var monitor := MonitorProp.new()
					monitor.position = Vector2(x * T + 16, y * T + 12)
					add_child(monitor)
				"Q":
					_place(AI_ELITE_SCENE, x, y)
				"R":
					_place(REGIONAL_SCENE, x, y)
				"C":
					_place(CEO_SCENE, x, y)
					_boss_alive = true
					EventBus.boss_died.connect(_on_boss_died)
				"S":
					var camera := SecurityCamera.new()
					camera.position = Vector2(x * T + 8, y * T + 8)
					add_child(camera)
				"f", "g":
					var fan_run := 1
					while x + fan_run < line.length() and line[x + fan_run] == ch:
						fan_run += 1
					var fan := FanZone.new()
					fan.position = Vector2(x * T, (y + 1) * T)
					fan.setup(fan_run, 1 if ch == "g" else -1)
					add_child(fan)
					consumed = fan_run
				"l":
					var laser_run := 1
					while x + laser_run < line.length() and line[x + laser_run] == "l":
						laser_run += 1
					var laser := TimedHazard.new()
					laser.position = Vector2(x * T, y * T + 6)
					laser.phase_offset = fmod(x * 0.35, 2.8)
					laser.setup(Vector2(laser_run * T, 4))
					add_child(laser)
					consumed = laser_run
				"b":
					var bridge_run := 1
					while x + bridge_run < line.length() and line[x + bridge_run] == "b":
						bridge_run += 1
					var bridge := FadingBridge.new()
					bridge.position = Vector2(x * T, y * T + 5)
					bridge.phase_offset = fmod(x * 0.4, 2.8)
					bridge.setup(bridge_run)
					add_child(bridge)
					consumed = bridge_run
				"V":
					# vent column: same top-of-run rule as '~'
					if y > 0 and x < (grid[y - 1] as String).length() and grid[y - 1][x] == "V":
						x += 1
						continue
					var vent_height := 1
					while y + vent_height < grid.size() \
							and x < (grid[y + vent_height] as String).length() \
							and grid[y + vent_height][x] == "V":
						vent_height += 1
					var vent := TimedHazard.new()
					vent.position = Vector2(x * T + 2, y * T)
					vent.beam_color = Color("ff7030") # heat, not laser
					vent.on_time = 1.0
					vent.off_time = 2.0
					vent.phase_offset = fmod(x * 0.5, 3.0)
					vent.setup(Vector2(12, vent_height * T))
					add_child(vent)
					x += 1
					continue
				"|":
					# elevator column: vertical mover between run ends
					if y > 0 and x < (grid[y - 1] as String).length() and grid[y - 1][x] == "|":
						x += 1
						continue
					var lift_height := 1
					while y + lift_height < grid.size() \
							and x < (grid[y + lift_height] as String).length() \
							and grid[y + lift_height][x] == "|":
						lift_height += 1
					var lift := MovingPlatform.new()
					lift.position = Vector2(x * T + 8, y * T + 8)
					var lift_curve := Curve2D.new()
					lift_curve.add_point(Vector2.ZERO)
					lift_curve.add_point(Vector2(0, maxi(16, lift_height * T - 16)))
					lift.curve = lift_curve
					lift.speed = 30.0
					lift.start_at_end = _mover_count % 2 == 1
					_mover_count += 1
					add_child(lift)
					x += 1
					continue
				"k":
					var checkpoint := Checkpoint.new()
					checkpoint.position = _tile_bottom(x, y)
					add_child(checkpoint)
				"N":
					var node := SecurityNode.new()
					node.id = StringName("node_%d" % total_nodes)
					node.position = _tile_bottom(x, y)
					node.activated.connect(_on_node_activated)
					add_child(node)
					total_nodes += 1
				"E":
					_gate = ExitGate.new()
					_gate.position = _tile_bottom(x, y)
					_gate.entered.connect(_on_gate_entered)
					add_child(_gate)
				"X":
					var crumble := CrumblingPlatform.new()
					crumble.position = Vector2(x * T + 16, y * T + 8)
					add_child(crumble)
					consumed = 2 # X spans 2 tiles (32px)
				">", "<":
					var run := 1
					while x + run < line.length() and line[x + run] == ch:
						run += 1
					var belt := ConveyorBelt.new()
					belt.position = Vector2(x * T, (y + 1) * T) # atop tile below
					belt.setup(run, 1 if ch == ">" else -1)
					add_child(belt)
					consumed = run
				"=":
					var span := 1
					while x + span < line.length() and line[x + span] == "=":
						span += 1
					var mover := MovingPlatform.new()
					mover.position = Vector2(x * T + 24, y * T + 8)
					var curve := Curve2D.new()
					curve.add_point(Vector2.ZERO)
					curve.add_point(Vector2(maxi(0, span * T - 48), 0))
					mover.curve = curve
					# alternate phases so consecutive movers' ends meet
					mover.start_at_end = _mover_count % 2 == 1
					_mover_count += 1
					add_child(mover)
					consumed = span
				"~":
					# column: only process the TOP '~' of a run. Do NOT blank
					# these cells here — the top-detection below must read the
					# ORIGINAL grid for every row (the final replace pass
					# clears all '~' at once).
					if y > 0 and x < (grid[y - 1] as String).length() and grid[y - 1][x] == "~":
						x += 1
						continue
					var height := 1
					while y + height < grid.size() \
							and x < (grid[y + height] as String).length() \
							and grid[y + height][x] == "~":
						height += 1
					var draft := Updraft.new()
					draft.position = Vector2(x * T, y * T)
					draft.setup(height)
					add_child(draft)
					x += 1
					continue
				_:
					x += 1
					continue
			# blank out consumed marker cells (strings are immutable — rebuild)
			var end := mini(x + consumed, line.length())
			line = line.substr(0, x) + ".".repeat(end - x) + line.substr(end)
			grid[y] = line
			x += consumed
	# vertical-run markers blanked separately (their top-detection must read
	# the original grid during the pass above)
	for y in grid.size():
		grid[y] = (grid[y] as String).replace("~", " ").replace("V", " ").replace("|", " ")
	var out := ""
	for line: String in grid:
		out += line + "\n"
	return out


func _place(scene: PackedScene, x: int, y: int) -> void:
	var node: Node2D = scene.instantiate()
	node.position = _tile_bottom(x, y) if scene != COIN_SCENE \
			else Vector2(x * T + 8, y * T + 8)
	add_child(node)


func _place_pickup(kind: Pickup.Kind, x: int, y: int) -> void:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.kind = kind
	pickup.position = Vector2(x * T + 8, y * T + 8)
	add_child(pickup)


func _tile_bottom(x: int, y: int) -> Vector2:
	return Vector2(x * T + 8, (y + 1) * T)


func _build_parallax() -> void:
	var parallax := ParallaxBackground.new()
	add_child(parallax)
	_parallax_layer(parallax,
			"res://assets/art/backgrounds/stage_%d_far.png" % data.stage_id, 0.2)
	_parallax_layer(parallax,
			"res://assets/art/backgrounds/stage_%d_mid.png" % data.stage_id, 0.5)


func _parallax_layer(parent: ParallaxBackground, texture_path: String, motion: float) -> void:
	if not ResourceLoader.exists(texture_path):
		return
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(motion, 0.9)
	layer.motion_mirroring = Vector2(480, 0)
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.centered = false
	layer.add_child(sprite)
	parent.add_child(layer)


# -- Objectives & clear --------------------------------------------------------

## Par-time bonus (docs/GDD.md §9): 10000 under/at par, -100 per second over.
static func compute_level_bonus(time_sec: float, par_sec: float) -> int:
	return maxi(0, 10000 - int(maxf(0.0, time_sec - par_sec)) * 100)

func _on_node_activated(_node: SecurityNode) -> void:
	nodes_active += 1
	EventBus.node_activated.emit(_node.id, nodes_active, total_nodes)
	_check_gate()


func _on_boss_died() -> void:
	_boss_alive = false
	_check_gate()


func _check_gate() -> void:
	if nodes_active >= total_nodes and not _boss_alive and _gate != null:
		_gate.unlock()


func _on_hidden_found(index: int) -> void:
	hidden_found[index] = true
	EventBus.hidden_room_found.emit(StringName("hidden_%d" % index))
	GameManager.add_score(1000)


func _on_enemy_killed(score: int, world_pos: Vector2) -> void:
	ScorePopup.spawn(self, world_pos, score)


func _on_gate_entered() -> void:
	if _cleared:
		return
	_cleared = true
	GameManager.end_stage()
	var level_bonus := compute_level_bonus(GameManager.stage_time, data.par_time_sec)
	var full_audit := FULL_AUDIT_BONUS if GameManager.coins >= total_coins else 0
	GameManager.add_score(level_bonus + full_audit)
	var stats := {
		"stage_id": data.stage_id,
		"next_stage_id": data.next_stage_id,
		"character": GameManager.character,
		"score": GameManager.score,
		"time": GameManager.stage_time,
		"par_time": data.par_time_sec,
		"coins": GameManager.coins,
		"total_coins": total_coins,
		"nodes": nodes_active,
		"total_nodes": total_nodes,
		"deaths": GameManager.deaths_this_stage,
		"hit_zero_lives": GameManager.hit_zero_lives,
		"hidden_rooms": hidden_found,
		"exp_score": GameManager.enemy_score,
		"coin_score": GameManager.coin_score,
		"level_bonus": level_bonus,
		"full_audit": full_audit,
	}
	var rank: GameManager.Rank = GameManager.compute_rank(stats)
	stats["rank"] = GameManager.rank_name(rank)
	GameManager.last_clear_stats = stats
	# persist: bests + unlock next stage
	if SaveManager.active_slot > 0:
		var save := SaveManager.load_slot(SaveManager.active_slot)
		if not save.is_empty():
			save = SaveManager.record_stage_clear(save, stats)
			save.last_character = String(GameManager.character)
			save.play_time_sec = int(save.get("play_time_sec", 0)) + int(GameManager.stage_time)
			SaveManager.write_slot(SaveManager.active_slot, save)
	EventBus.stage_cleared.emit(stats)
	AudioManager.stop_music()
	AudioManager.play_sfx("node_activate")
	SceneManager.change_scene("res://scenes/ui/stage_clear.tscn")
