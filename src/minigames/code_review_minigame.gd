class_name CodeReviewMinigame
extends CanvasLayer
## Stage 1 gate minigame (docs/GDD.md gate minigames): spot the planted bugs
## in a scrolling Java review before the timer runs out. Zaf — Chris & Flam's
## boss — heckles from the side panel. Never hard-fails: a timeout just
## reshuffles and restarts the round (MinigameLauncher already spent the key
## up front); only an explicit cancel bails out and refunds it.

signal finished(success: bool, bonus: int)

const TIME_LIMIT := 20.0
const BUG_COUNT := 3
const BASE_BONUS := 1000
const TIME_BONUS_PER_SEC := 50
const MISTAKE_PENALTY := 100

const PORTRAIT := preload("res://assets/art/characters/zaf_portrait.png")

## clean/bugged Java pairs — banking-flavored, one planted bug class each
## (assignment-vs-equality, off-by-one, missing semicolon, unbalanced
## paren, missing null-check, key typo, wrong clamp direction, wrong
## comparison operator, case-sensitive typo).
const LINE_BANK: Array[Dictionary] = [
	{"clean": "if (balance >= amount) {", "bugged": "if (balance = amount) {"},
	{"clean": "for (int i = 0; i < accounts.length; i++) {",
			"bugged": "for (int i = 0; i <= accounts.length; i++) {"},
	{"clean": "return customer.getLimit();", "bugged": "return customer.getLimit()"},
	{"clean": "public double calculateInterest(double rate) {",
			"bugged": "public double calculateInterest(double rate {"},
	{"clean": "if (account != null && account.isActive()) {",
			"bugged": "if (account.isActive()) {"},
	{"clean": "String custId = record.get(\"customerId\");",
			"bugged": "String custId = record.get(\"custommerId\");"},
	{"clean": "overdraftLimit = Math.max(0, overdraftLimit);",
			"bugged": "overdraftLimit = Math.min(0, overdraftLimit);"},
	{"clean": "private static final int MAX_RETRIES = 3;",
			"bugged": "private static final int MAX_RETRIES = 3"},
	{"clean": "boolean isValid = (score >= 650);", "bugged": "boolean isValid = (score => 650);"},
	{"clean": "collateral.setStatus(Status.APPROVED);",
			"bugged": "collateral.setStatus(status.APPROVED);"},
]

const ZAF_INTRO := "This wouldn't pass MY review."
const ZAF_CORRECT := ["Caught it.", "Good eye.", "That's one."]
const ZAF_WRONG := ["That line's fine...", "Look closer.", "Not that one."]
const ZAF_TIMEOUT := "Again. Faster this time."
const ZAF_WIN := "Actually mergeable. Barely."

## Tests inject a fixed sequence instead of RNG (same seam idea as
## RespawnController.scene_router / zaf_tutorial.stage_launcher).
var rng := RandomNumberGenerator.new()

## P1's own colour also covers solo (player_index 0) — only P2 (index 2) is
## distinct, so both/either co-op cursor sharing the same line reads as a
## deliberate third colour instead of just "whoever moved last wins".
const CURSOR_COLOR_P1 := UIKit.CYAN
const CURSOR_COLOR_P2 := UIKit.BLUE
const CURSOR_COLOR_BOTH := UIKit.GOLD

var _lines: Array[Dictionary] = []
## Keyed by player_index — {0: line} solo, {1: line, 2: line} co-op. Each
## player gets their OWN cursor (user request: two people should each scan
## their own material, not fight over one shared highlight).
var _cursors: Dictionary = {0: 0}
var _found := 0
var _mistakes := 0
var _time_left := TIME_LIMIT
var _won := false
var _active_indices: Array[int] = [0]

var _root: Control
var _line_labels: Array[Label] = []
var _timer_label: Label
var _zaf_text: Label


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

	_build_layout()
	_start_round()


## Layout budget for the 480x270 native screen (review catch: the previous
## numbers put the Zaf/portrait column's right edge at x≈548 — 68px past
## the actual screen edge, silently clipped by the viewport). RIGHT_COLUMN_X
## + its content must fit within SCREEN_W with margin. Measured against the
## real font (Label.get_theme_default_font().get_string_size()): the widest
## LINE_BANK entry incl. gutter number + both-cursor marker + "  [FIXED]"
## suffix is 208px at font size 7 (238px at size 8 — too wide for this
## budget), which is why the terminal uses 7 while everything else stays 8.
const SCREEN_W := 480.0
const TERMINAL_X := 8.0
const TERMINAL_FONT_SIZE := 7
const TERMINAL_LABEL_W := 220.0
const RIGHT_COLUMN_X := 256.0
const ZAF_TEXT_W := 135.0


func _build_layout() -> void:
	var top := UIKit.title("CODE REVIEW", 16)
	top.position = Vector2(12, 6)
	_root.add_child(top)

	_timer_label = UIKit.caption("20", 12, UIKit.GOLD)
	_timer_label.position = Vector2(440, 8)
	_root.add_child(_timer_label)

	var terminal_column: Array[Control] = [_build_monitor_titlebar()]
	for i in LINE_BANK.size():
		var label := UIKit.caption("", TERMINAL_FONT_SIZE, UIKit.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(TERMINAL_LABEL_W, 10)
		terminal_column.append(label)
		_line_labels.append(label)
	var terminal := _monitor_panel(UIKit.menu_column(terminal_column))
	terminal.position = Vector2(TERMINAL_X, 30)
	_root.add_child(terminal)

	var portrait := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAIT
	atlas.region = Rect2(0, 0, 48, 48)
	portrait.texture = atlas
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_zaf_text = UIKit.caption(ZAF_INTRO, 9, UIKit.CYAN)
	_zaf_text.custom_minimum_size = Vector2(ZAF_TEXT_W, 48)
	_zaf_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var zaf_row := HBoxContainer.new()
	zaf_row.add_theme_constant_override(&"separation", 8)
	zaf_row.add_child(portrait)
	zaf_row.add_child(_zaf_text)
	var zaf_panel := UIKit.framed_panel(zaf_row)
	zaf_panel.position = Vector2(RIGHT_COLUMN_X, 30)
	_root.add_child(zaf_panel)

	_build_player_portraits()


## Fake window chrome (traffic-light dots + a filename tab) so the code
## reads as "a file open in an IDE" rather than plain text on a background
## (user request).
func _build_monitor_titlebar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 4)
	for dot_color in [UIKit.RED, UIKit.GOLD, UIKit.GREEN]:
		var dot := ColorRect.new()
		dot.color = dot_color
		dot.custom_minimum_size = Vector2(6, 6)
		bar.add_child(dot)
	var filename := UIKit.caption("CustomerAccount.java", 8, UIKit.GRAY)
	filename.custom_minimum_size = Vector2(TERMINAL_LABEL_W - 30, 8)
	filename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(filename)
	return bar


## Same bordered-panel "physical UI" look as UIKit.framed_panel, but with a
## cyan bezel/darker screen instead of the shared green — reads as a
## separate monitor embedded in the scene rather than just another menu.
func _monitor_panel(content: Control) -> PanelContainer:
	var style := UIKit.panel_style(Color(0.02, 0.05, 0.08, 0.98), UIKit.CYAN)
	style.set_content_margin_all(10)
	style.set_border_width_all(2)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style)
	panel.add_child(content)
	return panel


## Small idle portrait(s) of whoever's actually playing — solo shows one,
## co-op shows both side by side (user request: the minigame should show
## who's playing, not just an abstract UI).
func _build_player_portraits() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var chars: Array[StringName] = [GameManager.character]
	if GameManager.is_coop():
		chars.append(GameManager.character2)
	for char_id in chars:
		var stats := GameManager.character_stats(char_id)
		var column := VBoxContainer.new()
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = SpriteFramesBuilder.build_player_frames(stats.sheet)
		sprite.play(&"idle")
		sprite.scale = Vector2(1.5, 1.5)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(48, 48)
		sprite.position = Vector2(24, 40)
		holder.add_child(sprite)
		column.add_child(holder)
		column.add_child(UIKit.caption(stats.display_name.to_upper(), 8, UIKit.GRAY))
		row.add_child(column)
	var panel := UIKit.framed_panel(row)
	panel.position = Vector2(RIGHT_COLUMN_X, 112)
	_root.add_child(panel)


func _start_round() -> void:
	_lines.clear()
	var bug_indices := {}
	while bug_indices.size() < BUG_COUNT:
		bug_indices[rng.randi_range(0, LINE_BANK.size() - 1)] = true
	for i in LINE_BANK.size():
		var entry: Dictionary = LINE_BANK[i]
		var is_bug: bool = bug_indices.has(i)
		_lines.append({
			"text": entry.bugged if is_bug else entry.clean,
			"is_bug": is_bug,
			"found": false,
		})
	for pi in _active_indices:
		_cursors[pi] = 0
	_found = 0
	_mistakes = 0
	_time_left = TIME_LIMIT
	_refresh_line_labels()


func _refresh_line_labels() -> void:
	for i in _lines.size():
		var line: Dictionary = _lines[i]
		var label := _line_labels[i]
		var here: Array[int] = []
		for pi in _active_indices:
			if _cursors[pi] == i:
				here.append(pi)
		var marker := ""
		for pi in here:
			marker += "2" if pi == 2 else "1"
		var prefix := (marker + "> ") if not marker.is_empty() else "  "
		var suffix := "  [FIXED]" if line.found else ""
		var gutter := "%2d|" % (i + 1) # line number, IDE-style
		label.text = gutter + " " + prefix + String(line.text) + suffix
		if line.found:
			label.add_theme_color_override(&"font_color", UIKit.GREEN)
		elif here.size() > 1:
			label.add_theme_color_override(&"font_color", CURSOR_COLOR_BOTH)
		elif here.size() == 1:
			label.add_theme_color_override(&"font_color",
					CURSOR_COLOR_P2 if here[0] == 2 else CURSOR_COLOR_P1)
		else:
			label.add_theme_color_override(&"font_color", UIKit.WHITE)


func _process(delta: float) -> void:
	if _won:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_timer_label.text = str(int(ceil(_time_left)))
	if _time_left <= 0.0:
		_timeout_retry()
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		finished.emit(false, 0)
		return
	for pi in _active_indices:
		if Input.is_action_just_pressed(_action(&"move_up", pi)):
			_move_cursor(pi, -1)
		elif Input.is_action_just_pressed(_action(&"move_down", pi)):
			_move_cursor(pi, 1)
		elif Input.is_action_just_pressed(_action(&"interact", pi)):
			_flag_current(pi)


func _action(base: StringName, player_index: int) -> StringName:
	return CoopInput.scoped_action(base, player_index)


func _move_cursor(player_index: int, step: int) -> void:
	_cursors[player_index] = posmod(_cursors[player_index] + step, _lines.size())
	_refresh_line_labels()
	AudioManager.play_sfx("menu_move", true, true)


func _flag_current(player_index: int) -> void:
	var idx: int = _cursors[player_index]
	var line: Dictionary = _lines[idx]
	if line.found:
		return
	if line.is_bug:
		line.found = true
		_lines[idx] = line
		_found += 1
		AudioManager.play_sfx("menu_select", true, true)
		_zaf_say(ZAF_CORRECT[rng.randi_range(0, ZAF_CORRECT.size() - 1)])
		_refresh_line_labels()
		if _found >= BUG_COUNT:
			_win()
	else:
		_mistakes += 1
		AudioManager.play_sfx("menu_back", true, true)
		_zaf_say(ZAF_WRONG[rng.randi_range(0, ZAF_WRONG.size() - 1)])
		_flash_wrong(idx)


## A wrong flag only changed Zaf's dialogue before (review catch: the line
## itself gave no feedback at all, reading as if nothing happened) — flash
## the actual line RED (this game's damage/corruption colour) so a mistake
## is unmistakable, then let _refresh_line_labels restore its real state.
func _flash_wrong(idx: int) -> void:
	_line_labels[idx].add_theme_color_override(&"font_color", UIKit.RED)
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_refresh_line_labels)


func _zaf_say(text: String) -> void:
	_zaf_text.text = text


func _timeout_retry() -> void:
	_zaf_say(ZAF_TIMEOUT)
	AudioManager.play_sfx("menu_back", true, true)
	_start_round()


func _win() -> void:
	_won = true
	_zaf_say(ZAF_WIN)
	var bonus := maxi(0, BASE_BONUS + int(_time_left) * TIME_BONUS_PER_SEC
			- _mistakes * MISTAKE_PENALTY)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, bonus)
