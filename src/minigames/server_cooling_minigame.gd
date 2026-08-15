class_name ServerCoolingMinigame
extends CanvasLayer
## Stage 2 gate minigame (docs/GDD.md gate minigames): a whack-a-mole
## reflex game — server racks heat up at random and must be cooled
## (interact action) before they overheat. Distinct genre from the other
## three gates: no scanning text (Code Review Rush), no shooting (Ticket
## Blitz), no single timing bar (Presentation Pace) — this one is
## multi-target reflexes across a small grid, same spirit as CodeReview
## Rush's per-player independent cursor but applied to a live 2D grid
## instead of a static line list.
##
## A rack reaching 100% heat is a strike (same "OVERHEAT" cost regardless
## of which rack), reset to a baseline heat so it stays in the rotation
## instead of getting permanently stuck. MAX_STRIKES (3) hard-fails the
## run via finished(false, 0) — same contract as an explicit ui_cancel and
## as the other three gates' strike/lose rule (FirewallGate/MinigameLauncher
## already refund the spent key and require exit+re-entry to retry).

signal finished(success: bool, bonus: int)

const MAX_STRIKES := 3
const STRIKE_PENALTY := 150
const BASE_BONUS := 900
const COOL_BONUS := 40

const RACK_COLS := 3
const RACK_ROWS := 2
const RACK_COUNT := RACK_COLS * RACK_ROWS

const WAVE_COUNT := 3
## Per-wave: how fast an active rack's heat climbs (%/sec), how many racks
## may be actively heating at once, and how often (seconds) a new rack
## joins the active set while under that cap, plus how long the wave lasts.
const HEAT_RATE := [8.0, 11.0, 15.0]
const MAX_ACTIVE := [2, 3, 4]
const ACTIVATE_INTERVAL := [2.2, 1.6, 1.1]
const WAVE_DURATION := [12.0, 12.0, 12.0]

const OVERHEAT_RESET_HEAT := 30.0
const OVERHEAT_FLASH_TIME := 0.25
const WARM_THRESHOLD := 50.0
const HOT_THRESHOLD := 80.0

const RACK_SIZE := Vector2(128, 68)
const RACK_GAP := 14.0
const RACK_ORIGIN := Vector2(40, 60)

const CURSOR_COLOR_P1 := UIKit.CYAN
const CURSOR_COLOR_P2 := UIKit.BLUE
const CURSOR_COLOR_BOTH := UIKit.GOLD

## Tests inject a fixed generator instead of RNG (same seam idea as
## CodeReviewMinigame.rng / TicketBlitzMinigame.rng).
var rng := RandomNumberGenerator.new()

var _wave := 0
var _wave_timer := 0.0
var _activate_timer := 0.0
var _heat: Array[float] = []
var _active: Array[bool] = []
var _flash_timer: Array[float] = []
var _strikes := 0
var _cool_count := 0
var _won := false
var _lost := false
var _active_indices: Array[int] = [0]
var _cursors: Dictionary = {0: 0}

var _root: Control
var _wave_label: Label
var _hits_label: Label
var _rack_panels: Array[PanelContainer] = []
var _rack_labels: Array[Label] = []
var _rack_bars: Array[ColorRect] = []


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager.is_coop():
		CoopInput.ensure_actions()
		_active_indices = [1, 2]
	else:
		_active_indices = [0]
	_cursors.clear()
	for pi in _active_indices:
		_cursors[pi] = 0

	# CanvasLayer children never stretch with anchors (project-wide gotcha,
	# see pause_menu.gd) — build the background the same anchor-free way
	# every other gate minigame does instead of UIKit.fill_background().
	_root = Control.new()
	var bg := ColorRect.new()
	bg.color = UIKit.BG_VOID
	_root.add_child(bg)
	add_child(_root)
	_root.size = _root.get_viewport().get_visible_rect().size
	bg.size = _root.size

	_build_ui()
	_start_wave(0)


func _build_ui() -> void:
	var top := UIKit.title("SERVER COOLING", 16)
	top.position = Vector2(12, 6)
	_root.add_child(top)

	_wave_label = UIKit.caption("", 10, UIKit.GOLD)
	_wave_label.position = Vector2(330, 8)
	_root.add_child(_wave_label)

	_hits_label = UIKit.caption("HITS: 0/%d" % MAX_STRIKES, 9, UIKit.RED)
	_hits_label.position = Vector2(12, 22)
	_root.add_child(_hits_label)

	_build_racks()

	var hint := UIKit.caption("COOL THE RACKS BEFORE THEY OVERHEAT — MOVE + INTERACT", 8, UIKit.GRAY)
	hint.position = Vector2(48, 210)
	_root.add_child(hint)


func _build_racks() -> void:
	for i in RACK_COUNT:
		var row := i / RACK_COLS
		var col := i % RACK_COLS
		var pos := RACK_ORIGIN + Vector2(col * (RACK_SIZE.x + RACK_GAP), row * (RACK_SIZE.y + RACK_GAP))

		var label := UIKit.caption("RACK %d" % (i + 1), 9, UIKit.GRAY)
		var bar_track := ColorRect.new()
		bar_track.color = Color(0.05, 0.08, 0.12)
		# custom_minimum_size, NOT .size — bar_track is a child of the
		# VBoxContainer below, which manages/overwrites its children's real
		# .size every layout pass (same convention CodeReviewMinigame uses
		# for its line labels; a direct .size write here would just get
		# silently clobbered on the next sort).
		bar_track.custom_minimum_size = Vector2(RACK_SIZE.x - 16, 10)
		var bar_fill := ColorRect.new()
		bar_fill.color = UIKit.GREEN
		bar_fill.size = Vector2(0, 10)
		bar_track.add_child(bar_fill)

		var column := VBoxContainer.new()
		column.add_child(label)
		column.add_child(bar_track)
		var panel := UIKit.framed_panel(column)
		panel.position = pos
		panel.custom_minimum_size = RACK_SIZE
		_root.add_child(panel)

		_rack_panels.append(panel)
		_rack_labels.append(label)
		_rack_bars.append(bar_fill)


func _start_wave(wave_index: int) -> void:
	_wave = wave_index
	_wave_label.text = "WAVE %d / %d" % [wave_index + 1, WAVE_COUNT]
	_wave_timer = 0.0
	_activate_timer = 1.0 # a short breather before the first rack heats up
	_heat = []
	_active = []
	_flash_timer = []
	for i in RACK_COUNT:
		_heat.append(0.0)
		_active.append(false)
		_flash_timer.append(0.0)
	_refresh_racks()


func _process(delta: float) -> void:
	if _won or _lost:
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		finished.emit(false, 0)
		return
	for pi in _active_indices:
		if Input.is_action_just_pressed(_action(&"move_left", pi)):
			_move_cursor(pi, -1)
		elif Input.is_action_just_pressed(_action(&"move_right", pi)):
			_move_cursor(pi, 1)
		elif Input.is_action_just_pressed(_action(&"move_up", pi)):
			_move_cursor(pi, -RACK_COLS)
		elif Input.is_action_just_pressed(_action(&"move_down", pi)):
			_move_cursor(pi, RACK_COLS)
		elif Input.is_action_just_pressed(_action(&"interact", pi)):
			_try_cool(pi)

	_wave_timer += delta
	if _wave_timer >= WAVE_DURATION[_wave]:
		_advance_wave()
		return

	_activate_timer -= delta
	if _activate_timer <= 0.0:
		_activate_timer = ACTIVATE_INTERVAL[_wave]
		_activate_random_rack()

	_tick_heat(delta)
	for i in RACK_COUNT:
		_flash_timer[i] = maxf(0.0, _flash_timer[i] - delta)
	_refresh_racks()


## Split out of _process so tests can drive the heating/overheat math
## directly with a controlled delta, without also having to fight real
## Input polling and the wave/activation timers in the same call (mirrors
## TicketBlitzMinigame._check_collisions() being its own method rather than
## inlined in _physics_process).
func _tick_heat(delta: float) -> void:
	for i in RACK_COUNT:
		if _active[i]:
			_heat[i] = minf(100.0, _heat[i] + HEAT_RATE[_wave] * delta)
			if _heat[i] >= 100.0:
				_overheat(i)


func _action(base: StringName, player_index: int) -> StringName:
	return CoopInput.scoped_action(base, player_index)


func _move_cursor(player_index: int, step: int) -> void:
	_cursors[player_index] = posmod(_cursors[player_index] + step, RACK_COUNT)
	_refresh_racks()
	AudioManager.play_sfx("menu_move", true, true)


func _try_cool(player_index: int) -> void:
	var idx: int = _cursors[player_index]
	if not _active[idx]:
		return
	_active[idx] = false
	_heat[idx] = 0.0
	_cool_count += 1
	AudioManager.play_sfx("menu_select", true, true)
	_refresh_racks()


func _activate_random_rack() -> void:
	if _count_active() >= MAX_ACTIVE[_wave]:
		return
	var idle: Array[int] = []
	for i in RACK_COUNT:
		if not _active[i]:
			idle.append(i)
	if idle.is_empty():
		return
	var idx: int = idle[rng.randi_range(0, idle.size() - 1)]
	_active[idx] = true


func _count_active() -> int:
	var count := 0
	for a in _active:
		if a:
			count += 1
	return count


func _overheat(i: int) -> void:
	_active[i] = false
	_heat[i] = OVERHEAT_RESET_HEAT
	_flash_timer[i] = OVERHEAT_FLASH_TIME
	AudioManager.play_sfx("menu_back", true, true)
	_register_strike()


func _refresh_racks() -> void:
	for i in RACK_COUNT:
		var here: Array[int] = []
		for pi in _active_indices:
			if _cursors[pi] == i:
				here.append(pi)
		var marker := ""
		for pi in here:
			marker += "2" if pi == 2 else "1"
		var prefix := (marker + "> ") if not marker.is_empty() else ""
		_rack_labels[i].text = "%sRACK %d" % [prefix, i + 1]

		var heat: float = _heat[i]
		var bar: ColorRect = _rack_bars[i]
		var track_w: float = (bar.get_parent() as ColorRect).size.x
		bar.size.x = track_w * (heat / 100.0)

		var heat_color := UIKit.GREEN
		if heat >= HOT_THRESHOLD:
			heat_color = UIKit.RED
		elif heat >= WARM_THRESHOLD:
			heat_color = UIKit.GOLD
		bar.color = heat_color

		var border := UIKit.GRAY
		var fill := Color(0.04, 0.08, 0.13, 0.96)
		var border_width := 1
		if _flash_timer[i] > 0.0:
			# An overheat must be unmistakable regardless of whose cursor is
			# where (same "a mistake reads as a mistake" priority CodeReview
			# Rush's _flash_wrong gives a wrong flag) — this is the ONE
			# state _refresh_racks() itself renders as a timed effect,
			# rather than a one-shot stylebox a later refresh would silently
			# clobber the same frame (the bug this replaced).
			border = UIKit.WHITE
			fill = Color(0.4, 0.03, 0.03)
			border_width = 3
		elif here.size() > 1:
			border = CURSOR_COLOR_BOTH
		elif here.size() == 1:
			border = CURSOR_COLOR_P2 if here[0] == 2 else CURSOR_COLOR_P1
		elif _active[i]:
			border = heat_color
		var style := UIKit.panel_style(fill, border)
		style.set_border_width_all(border_width)
		style.set_content_margin_all(8)
		_rack_panels[i].add_theme_stylebox_override(&"panel", style)


func _advance_wave() -> void:
	if _wave + 1 < WAVE_COUNT:
		_start_wave(_wave + 1)
	else:
		_win()


## Guarded against being called again once the run has already ended, same
## defensive parity as Ticket Blitz's and Presentation Pace's own
## _register_strike().
func _register_strike() -> void:
	if _won or _lost:
		return
	_strikes += 1
	_hits_label.text = "HITS: %d/%d" % [_strikes, MAX_STRIKES]
	if _strikes >= MAX_STRIKES:
		_lose()


func _win() -> void:
	_won = true
	_wave_label.text = "DATA CENTER STABLE"
	var bonus := maxi(0, BASE_BONUS + _cool_count * COOL_BONUS - _strikes * STRIKE_PENALTY)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, bonus)


## MAX_STRIKES reached — a hard fail, same outcome contract as an explicit
## ui_cancel (finished.emit(false, 0)): FirewallGate/MinigameLauncher refund
## the spent key and require a genuine exit+re-entry before another attempt.
func _lose() -> void:
	_lost = true
	_wave_label.text = "SYSTEM MELTDOWN"
	await get_tree().create_timer(0.9).timeout
	finished.emit(false, 0)
