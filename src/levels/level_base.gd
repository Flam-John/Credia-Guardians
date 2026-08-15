class_name LevelBase
extends Node2D
## Real-stage foundation: builds terrain + entities from an ASCII map and
## owns the objective/gate flow. Parsing lives in EntityMarkerParser
## (unit-testable); the clear pipeline lives in GameManager.complete_stage
## (docs/DATA_FLOW.md §5) — review P3-16.
## Hidden rooms are tile-rect regions provided by the stage subclass.

const T := 16

const COIN_SCENE := preload("res://scenes/entities/collectibles/coin.tscn")
const PICKUP_SCENE := preload("res://scenes/entities/collectibles/pickup.tscn")

## marker char -> enemy scene (single-cell spawns share one dispatch path)
const ENEMY_SCENES := {
	"J": preload("res://scenes/entities/enemies/junior_banker.tscn"),
	"M": preload("res://scenes/entities/enemies/angry_manager.tscn"),
	"A": preload("res://scenes/entities/enemies/auditor.tscn"),
	"L": preload("res://scenes/entities/enemies/loan_shark.tscn"),
	"B": preload("res://scenes/entities/enemies/ai_banker.tscn"),
	"Q": preload("res://scenes/entities/enemies/ai_banker_elite.tscn"),
	"R": preload("res://scenes/entities/enemies/regional_manager.tscn"),
	"C": preload("res://scenes/entities/bosses/ceo_boss.tscn"),
}
const PICKUP_KINDS := {
	"o": Pickup.Kind.COFFEE, "e": Pickup.Kind.ENERGY_DRINK,
	"W": Pickup.Kind.FIREWALL_SHIELD, "K": Pickup.Kind.KEYBOARD_UPGRADE,
	"U": Pickup.Kind.USB_KEY,
}

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
var _cleared := false
var _mover_count := 0
var _node_counter := 0
## When a 'C' marker spawns the CEO, the exit gate also requires his defeat.
var _boss_alive := false


func _ready() -> void:
	assert(data != null, "LevelBase needs a LevelData resource")
	add_to_group(&"level_root")
	add_child(LevelServices.new()) # pools + popup wiring (review P3-15)

	var parser := EntityMarkerParser.new()
	parser.parse(map)
	total_coins = parser.coin_count
	total_nodes = parser.node_count
	EventBus.nodes_total.emit(total_nodes)

	var builder := AsciiRoomBuilder.new()
	builder.map = parser.terrain
	builder.tileset_texture = data.tileset_texture
	add_child(builder)
	move_child(builder, 0) # terrain draws behind everything spawned next
	for spawn in parser.spawns:
		_instantiate_marker(spawn)

	_build_parallax()
	_spawn_ambient_particles(builder.room_size)
	add_child(DebugOverlay.new())

	if not GameManager.is_stage_running():
		GameManager.start_stage(data.stage_id, &"chris")

	respawner = RespawnController.new()
	respawner.spawn_point = Vector2(
			parser.spawn_tile.x * T + 8, parser.spawn_tile.y * T + 15)
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


## One spawn dict from the parser -> one instantiated node.
func _instantiate_marker(spawn: Dictionary) -> void:
	var type: String = spawn.type
	var x: int = spawn.x
	var y: int = spawn.y
	var length: int = spawn.length
	if ENEMY_SCENES.has(type):
		var enemy: Node2D = ENEMY_SCENES[type].instantiate()
		enemy.position = _tile_bottom(x, y)
		add_child(enemy)
		if type == "C":
			_boss_alive = true
			EventBus.boss_died.connect(_on_boss_died)
		return
	if PICKUP_KINDS.has(type):
		var pickup: Pickup = PICKUP_SCENE.instantiate()
		pickup.kind = PICKUP_KINDS[type]
		pickup.position = Vector2(x * T + 8, y * T + 8)
		add_child(pickup)
		return
	match type:
		"c":
			var coin: Node2D = COIN_SCENE.instantiate()
			coin.position = Vector2(x * T + 8, y * T + 8)
			add_child(coin)
		"k":
			var checkpoint := Checkpoint.new()
			checkpoint.position = _tile_bottom(x, y)
			add_child(checkpoint)
		"N":
			var node := SecurityNode.new()
			node.id = StringName("node_%d" % _node_counter)
			_node_counter += 1
			node.position = _tile_bottom(x, y)
			node.activated.connect(_on_node_activated)
			add_child(node)
		"E":
			_gate = ExitGate.new()
			_gate.position = _tile_bottom(x, y)
			_gate.entered.connect(_on_gate_entered)
			add_child(_gate)
		"F":
			var firewall := FirewallGate.new()
			firewall.position = _tile_bottom(x, y)
			add_child(firewall)
		"D":
			var code_gate := FirewallGate.new()
			code_gate.position = _tile_bottom(x, y)
			code_gate.minigame_id = &"code_review"
			add_child(code_gate)
		"T":
			var ticket_gate := FirewallGate.new()
			ticket_gate.position = _tile_bottom(x, y)
			ticket_gate.minigame_id = &"ticket_blitz"
			add_child(ticket_gate)
		"H":
			var presentation_gate := FirewallGate.new()
			presentation_gate.position = _tile_bottom(x, y)
			presentation_gate.minigame_id = &"presentation_pace"
			add_child(presentation_gate)
		"G":
			var cooling_gate := FirewallGate.new()
			cooling_gate.position = _tile_bottom(x, y)
			cooling_gate.minigame_id = &"server_cooling"
			add_child(cooling_gate)
		"m":
			var monitor := MonitorProp.new()
			monitor.position = Vector2(x * T + 16, y * T + 12)
			add_child(monitor)
		"S":
			var camera := SecurityCamera.new()
			camera.position = Vector2(x * T + 8, y * T + 8)
			add_child(camera)
		"X":
			var crumble := CrumblingPlatform.new()
			crumble.position = Vector2(x * T + 16, y * T + 8)
			add_child(crumble)
		">", "<":
			var belt := ConveyorBelt.new()
			belt.position = Vector2(x * T, (y + 1) * T) # atop tile below
			belt.setup(length, 1 if type == ">" else -1)
			add_child(belt)
		"f", "g":
			var fan := FanZone.new()
			fan.position = Vector2(x * T, (y + 1) * T)
			fan.setup(length, 1 if type == "g" else -1)
			add_child(fan)
		"l":
			var laser := TimedHazard.new()
			laser.position = Vector2(x * T, y * T + 6)
			laser.phase_offset = fmod(x * 0.35, 2.8)
			laser.setup(Vector2(length * T, 4))
			add_child(laser)
		"b":
			var bridge := FadingBridge.new()
			bridge.position = Vector2(x * T, y * T + 5)
			bridge.phase_offset = fmod(x * 0.4, 2.8)
			bridge.setup(length)
			add_child(bridge)
		"V":
			var vent := TimedHazard.new()
			vent.position = Vector2(x * T + 2, y * T)
			vent.beam_color = Color("ff7030") # heat, not laser
			vent.on_time = 1.0
			vent.off_time = 2.0
			vent.phase_offset = fmod(x * 0.5, 3.0)
			vent.setup(Vector2(12, length * T))
			add_child(vent)
		"~":
			var draft := Updraft.new()
			draft.position = Vector2(x * T, y * T)
			draft.setup(length)
			add_child(draft)
		"=":
			var mover := MovingPlatform.new()
			mover.position = Vector2(x * T + 24, y * T + 8)
			var curve := Curve2D.new()
			curve.add_point(Vector2.ZERO)
			curve.add_point(Vector2(maxi(0, length * T - 48), 0))
			mover.curve = curve
			# alternate phases so consecutive movers' ends meet
			mover.start_at_end = _mover_count % 2 == 1
			_mover_count += 1
			add_child(mover)
		"|":
			var lift := MovingPlatform.new()
			lift.position = Vector2(x * T + 8, y * T + 8)
			var lift_curve := Curve2D.new()
			lift_curve.add_point(Vector2.ZERO)
			lift_curve.add_point(Vector2(0, maxi(16, length * T - 16)))
			lift.curve = lift_curve
			lift.speed = 30.0
			lift.start_at_end = _mover_count % 2 == 1
			_mover_count += 1
			add_child(lift)


func _tile_bottom(x: int, y: int) -> Vector2:
	return Vector2(x * T + 8, (y + 1) * T)


func _build_parallax() -> void:
	var parallax := ParallaxBackground.new()
	add_child(parallax)
	_parallax_layer(parallax,
			"res://assets/art/backgrounds/stage_%d_far.png" % data.stage_id, 0.2)
	_parallax_layer(parallax,
			"res://assets/art/backgrounds/stage_%d_mid.png" % data.stage_id, 0.5)
	_parallax_layer(parallax,
			"res://assets/art/backgrounds/stage_%d_near.png" % data.stage_id, 0.8)


## Phase 3 atmosphere: slow drifting particles per stage theme — dust motes
## in the office, digital rain drips, gilded dust, rising gold sparkle,
## rising corruption embers. Purely visual, z below entities.
const AMBIENT := {
	1: {"color": Color(0.55, 0.65, 0.8, 0.35), "vel": Vector2(4, 6), "amount": 20},
	2: {"color": Color(0.1, 0.85, 0.85, 0.5), "vel": Vector2(0, 55), "amount": 28},
	3: {"color": Color(1.0, 0.85, 0.35, 0.35), "vel": Vector2(3, 4), "amount": 16},
	4: {"color": Color(1.0, 0.8, 0.2, 0.5), "vel": Vector2(0, -8), "amount": 18},
	5: {"color": Color(1.0, 0.25, 0.3, 0.5), "vel": Vector2(0, -14), "amount": 24},
}


func _spawn_ambient_particles(room_size: Vector2) -> void:
	if not AMBIENT.has(data.stage_id):
		return
	var cfg: Dictionary = AMBIENT[data.stage_id]
	var motes := CPUParticles2D.new()
	motes.amount = cfg.amount * maxi(1, int(room_size.x / 480.0))
	motes.lifetime = 7.0
	motes.preprocess = 7.0 # room is already dusted when the stage fades in
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = room_size / 2.0
	motes.position = room_size / 2.0
	var vel: Vector2 = cfg.vel
	motes.direction = vel.normalized() if vel.length() > 0.0 else Vector2.DOWN
	motes.initial_velocity_min = vel.length() * 0.6
	motes.initial_velocity_max = vel.length() * 1.4
	motes.gravity = Vector2.ZERO
	motes.scale_amount_min = 0.6
	motes.scale_amount_max = 1.4
	motes.color = cfg.color
	motes.z_index = -1
	add_child(motes)


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


func _on_gate_entered() -> void:
	if _cleared:
		return
	_cleared = true
	GameManager.complete_stage({
		"stage_id": data.stage_id,
		"next_stage_id": data.next_stage_id,
		"par_time": data.par_time_sec,
		"total_coins": total_coins,
		"nodes": nodes_active,
		"total_nodes": total_nodes,
		"hidden_rooms": hidden_found,
	})
	AudioManager.stop_music()
	AudioManager.play_sfx("node_activate")
	SceneManager.change_scene("res://scenes/ui/stage_clear.tscn")
