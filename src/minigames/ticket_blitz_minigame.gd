class_name TicketBlitzMinigame
extends CanvasLayer
## Stage 5 gate minigame (docs/GDD.md gate minigames): a Samurai Aces-style
## shooter reskinned as customer tickets flooding a bank's core system —
## error strings lifted from real Temenos T24 override/warning messages
## (Security Violation, Collateral Right not Found, etc.) for the dangerous
## tier. Never hard-fails: strikes only shave the completion bonus, so a
## rough run still finishes and opens the gate; only an explicit cancel
## bails out and refunds the key (mirrors CodeReviewMinigame's contract).

signal finished(success: bool, bonus: int)

const TIER1_TEXTS := [
	"REFUND REQUEST", "PASSWORD RESET", "CARD BLOCKED - REISSUE",
	"STATEMENT REQUEST", "ATM COMPLAINT",
]
const TIER2_TEXTS := [
	"NO INPUT DONE FOR MANDATORY FIELD", "RECORD ALREADY EXISTS",
	"DUPLICATE RECORD ON FILE", "VALUE DATE IS A HOLIDAY",
]
const TIER3_TEXTS := [
	"SECURITY VIOLATION", "COLLATERAL RIGHT NOT FOUND",
	"Δεν φαίνονται τα Όρια στην καρτέλα πελάτη",
	"Δεν έχει γίνει ο συγχρονισμός",
	"AMOUNT IN EXCESS OF LIMIT REFERENCE", "RECORD IS LOCKED BY ANOTHER USER",
	"CUSTOMER NOT AUTHORISED",
]

const WAVE_COUNT := 3
const SPAWN_INTERVAL := 0.9
const STRIKE_PENALTY := 150

## Tests inject a fixed generator instead of RNG (same seam idea as
## CodeReviewMinigame.rng / RespawnController.scene_router).
var rng := RandomNumberGenerator.new()

var _bounds := Rect2(40, 46, 400, 200)
var _wave := 0
var _spawn_queue: Array = []
var _spawn_timer := 0.0
var _alive_count := 0
var _boss_active := false
var _won := false
var _score_bonus := 0
var _strikes := 0

var _root: Control
var _wave_label: Label
var _hits_label: Label


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

	# CanvasLayer children never stretch with anchors (project-wide gotcha,
	# see pause_menu.gd) — UIKit.fill_background() anchors its root, which
	# fights an explicit .size write here, so build the background the same
	# anchor-free way PauseMenu does instead.
	_root = Control.new()
	var bg := ColorRect.new()
	bg.color = UIKit.BG_VOID
	_root.add_child(bg)
	add_child(_root)
	_root.size = _root.get_viewport().get_visible_rect().size
	bg.size = _root.size
	_bounds = Rect2(40, 46, _root.size.x - 80, _root.size.y - 96)

	_build_ui()
	_build_ships()
	_start_wave(0)


func _build_ui() -> void:
	var top := UIKit.title("TICKET BLITZ", 16)
	top.position = Vector2(12, 6)
	_root.add_child(top)
	_wave_label = UIKit.caption("WAVE 1 / %d" % WAVE_COUNT, 10, UIKit.GOLD)
	_wave_label.position = Vector2(340, 8)
	_root.add_child(_wave_label)
	_hits_label = UIKit.caption("HITS: 0", 9, UIKit.RED)
	_hits_label.position = Vector2(12, 22)
	_root.add_child(_hits_label)


func _build_ships() -> void:
	var chars: Array = [[0, GameManager.character]]
	if GameManager.is_coop():
		chars = [[1, GameManager.character], [2, GameManager.character2]]
	var spacing := _bounds.size.x / (chars.size() + 1.0)
	for i in chars.size():
		var idx: int = chars[i][0]
		var char_id: StringName = chars[i][1]
		var ship := TicketBlitzShip.new()
		_root.add_child(ship)
		var start_x: float = _bounds.position.x + spacing * (i + 1)
		ship.setup(idx, GameManager.character_stats(char_id), _bounds)
		ship.global_position = Vector2(start_x, _bounds.end.y - 20)
		ship.fire_requested.connect(_on_fire_requested)
		ship.hit_by_ticket.connect(_on_ship_hit)


func _on_fire_requested(from: Vector2, tint: Color, speed: float, damage: int) -> void:
	var bullet := TicketBlitzBullet.new()
	_root.add_child(bullet)
	bullet.launch(from, Vector2(0, -speed), damage, tint,
			Rect2(Vector2.ZERO, _root.size).grow(16))


func _on_ship_hit() -> void:
	_strikes += 1
	_hits_label.text = "HITS: %d" % _strikes
	AudioManager.play_sfx("menu_back", true, true)


func _wave_specs(wave: int) -> Array:
	match wave:
		0:
			return _tier_specs(TicketBlitzTicket.Tier.LOW, TIER1_TEXTS, 6)
		1:
			return _tier_specs(TicketBlitzTicket.Tier.LOW, TIER1_TEXTS, 4) \
					+ _tier_specs(TicketBlitzTicket.Tier.MED, TIER2_TEXTS, 4)
		2:
			return _tier_specs(TicketBlitzTicket.Tier.MED, TIER2_TEXTS, 3) \
					+ _tier_specs(TicketBlitzTicket.Tier.HIGH, TIER3_TEXTS, 4)
		_:
			return []


func _tier_specs(tier: TicketBlitzTicket.Tier, texts: Array, count: int) -> Array:
	var out := []
	for i in count:
		out.append({"tier": tier, "text": texts[i % texts.size()]})
	return out


func _start_wave(wave_index: int) -> void:
	_wave = wave_index
	_wave_label.text = "WAVE %d / %d" % [wave_index + 1, WAVE_COUNT]
	_spawn_queue = _wave_specs(wave_index)
	_spawn_timer = 0.0
	_alive_count = _spawn_queue.size()
	if _alive_count == 0:
		_start_boss()


func _start_boss() -> void:
	_boss_active = true
	_wave_label.text = "ESCALATED TICKET"
	var boss := TicketBlitzTicket.new()
	_root.add_child(boss)
	boss.setup(TicketBlitzTicket.Tier.HIGH,
			"OVERRIDE — AUTHORISER SIGN-OFF REQUIRED",
			Vector2(_bounds.get_center().x, _bounds.position.y + 40), false)
	boss.make_boss(_bounds)
	boss.bottom_y = 1.0e6 # the boss never "reaches the bottom"
	boss.died.connect(_on_boss_died)


func _process(delta: float) -> void:
	if _won:
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		finished.emit(false, 0)
		return
	if _boss_active:
		return
	if _spawn_queue.is_empty():
		if _alive_count <= 0:
			_advance_wave()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_spawn_next()


func _advance_wave() -> void:
	if _wave + 1 < WAVE_COUNT:
		_start_wave(_wave + 1)
	else:
		_start_boss()


func _spawn_next() -> void:
	var spec: Dictionary = _spawn_queue.pop_front()
	var ticket := TicketBlitzTicket.new()
	_root.add_child(ticket)
	var x := rng.randf_range(_bounds.position.x + 20.0, _bounds.end.x - 20.0)
	ticket.setup(spec.tier, spec.text, Vector2(x, _bounds.position.y - 10.0),
			spec.tier != TicketBlitzTicket.Tier.LOW)
	ticket.bottom_y = _bounds.end.y + 20.0
	ticket.died.connect(_on_ticket_died)
	ticket.reached_bottom.connect(_on_ticket_gone)


func _on_ticket_died(_ticket: TicketBlitzTicket, score: int) -> void:
	_alive_count -= 1
	_score_bonus += score


func _on_ticket_gone(_ticket: TicketBlitzTicket) -> void:
	_alive_count -= 1


func _on_boss_died(_ticket: TicketBlitzTicket, score: int) -> void:
	_score_bonus += score
	_win()


func _win() -> void:
	_won = true
	_wave_label.text = "SYSTEM SECURED"
	var bonus := maxi(0, _score_bonus - _strikes * STRIKE_PENALTY)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, bonus)
