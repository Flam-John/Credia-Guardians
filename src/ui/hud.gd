class_name HUD
extends Control
## In-game HUD (key-art layout): portrait + segmented HP top-left, score
## under it, coin counter, HI-SCORE top-center. Lives in Main/UILayer and is
## shown only while a stage runs. All updates are EventBus-driven.

const PORTRAITS := preload("res://assets/art/characters/portraits.png")
const COIN_SHEET := preload("res://assets/art/props/coin.png")

var _portrait: TextureRect
var _hp_box: HBoxContainer
var _portrait2: TextureRect
var _hp_box2: HBoxContainer
var _boss_bar: HBoxContainer
var _boss_name: Label
var _timer_label: Label
var _timer_enabled := false
var _score_label: Label
var _coin_label: Label
var _hi_label: Label
var _lives_label: Label
var _max_hp := 6


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_portrait = TextureRect.new()
	_portrait.position = Vector2(6, 6)
	_portrait.custom_minimum_size = Vector2(20, 20)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.size = Vector2(20, 20)
	add_child(_portrait)

	_hp_box = HBoxContainer.new()
	_hp_box.position = Vector2(30, 8)
	_hp_box.add_theme_constant_override(&"separation", 1)
	add_child(_hp_box)

	# P2 panel (top-right, mirrored) — hidden outside co-op
	_portrait2 = _portrait.duplicate()
	_portrait2.position = Vector2(454, 6)
	_portrait2.visible = false
	add_child(_portrait2)
	_hp_box2 = HBoxContainer.new()
	_hp_box2.position = Vector2(400, 8)
	_hp_box2.add_theme_constant_override(&"separation", 1)
	_hp_box2.visible = false
	add_child(_hp_box2)

	_lives_label = _make_label(Vector2(30, 18), 7, UIKit.GRAY)
	add_child(_lives_label)

	_timer_label = _make_label(Vector2(-70, 18), 8, UIKit.CYAN)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.position = Vector2(-70, 30)
	_timer_label.visible = false
	add_child(_timer_label)
	EventBus.settings_applied.connect(func(s: Dictionary) -> void:
		_timer_enabled = s.get("video", {}).get("show_timer", false))

	_score_label = _make_label(Vector2(6, 30), 8, UIKit.WHITE)
	add_child(_score_label)

	var coin_icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = COIN_SHEET
	atlas.region = Rect2(0, 0, 16, 16)
	coin_icon.texture = atlas
	coin_icon.position = Vector2(6, 40)
	coin_icon.size = Vector2(12, 12)
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(coin_icon)
	_coin_label = _make_label(Vector2(20, 42), 8, UIKit.GOLD)
	add_child(_coin_label)

	_hi_label = _make_label(Vector2(0, 6), 8, UIKit.GREEN)
	_hi_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hi_label)

	_boss_bar = HBoxContainer.new()
	_boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_bar.position.y = -18
	_boss_bar.add_theme_constant_override(&"separation", 1)
	_boss_bar.visible = false
	add_child(_boss_bar)
	_boss_name = _make_label(Vector2.ZERO, 7, UIKit.RED)
	_boss_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_name.position.y = -28
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.visible = false
	add_child(_boss_name)

	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_damaged.connect(_on_hp_signal)
	EventBus.player_healed.connect(_on_hp_signal)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.coin_collected.connect(_on_coin)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_set_boss_hp)
	EventBus.boss_died.connect(_on_boss_died)


var _timer_accum := 0.0
var _last_timer_text := ""


func _process(delta: float) -> void:
	var show := _timer_enabled and GameManager.is_stage_running()
	if _timer_label.visible != show:
		_timer_label.visible = show
	if not show:
		return
	# 10 Hz refresh: displayed precision is a tenth — formatting at 60 Hz
	# was 60 string allocations/sec for identical text (review P4-27)
	_timer_accum += delta
	if _timer_accum < 0.1:
		return
	_timer_accum = 0.0
	var t := GameManager.stage_time
	var text := "%d:%02d.%d" % [int(t) / 60, int(t) % 60, int(t * 10) % 10]
	if text != _last_timer_text:
		_last_timer_text = text
		_timer_label.text = text


func _on_player_spawned(player: Node2D) -> void:
	# node ref used ONLY within this call (portrait + initial fill) — live
	# updates ride the bus hp signals, which carry player_index (review P3-17)
	var typed := player as Player
	var is_p2 := typed.player_index == 2
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAITS
	atlas.region = Rect2((0 if typed.stats.display_name == "Chris" else 1) * 32, 0, 32, 32)
	(_portrait2 if is_p2 else _portrait).texture = atlas
	if is_p2:
		_portrait2.visible = true
		_hp_box2.visible = true
	_set_hp(typed.health.hp, typed.stats.max_hp, is_p2)
	if not is_p2:
		_max_hp = typed.stats.max_hp
	_refresh_meta()


func _on_hp_signal(player_index: int, hp: int, max_hp: int) -> void:
	_set_hp(hp, max_hp, player_index == 2)


func _set_hp(hp: int, max_hp: int, is_p2 := false) -> void:
	var box := _hp_box2 if is_p2 else _hp_box
	while box.get_child_count() < max_hp:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(7, 8)
		box.add_child(seg)
	while box.get_child_count() > max_hp:
		box.get_child(box.get_child_count() - 1).free()
	for i in box.get_child_count():
		(box.get_child(i) as ColorRect).color = \
				UIKit.GREEN if i < hp else UIKit.BG_PANEL
	_refresh_meta()


func _on_score_changed(score: int) -> void:
	# read-only: hi-score promotion lives in GameManager.add_score, not in a
	# UI label callback (review P3-18)
	_score_label.text = "%08d" % score
	_hi_label.text = tr("HI-SCORE %d") % GameManager.hi_score


func _on_coin(_value: int) -> void:
	_coin_label.text = "×%d" % GameManager.coins


func _refresh_meta() -> void:
	_lives_label.text = "♥×%d" % maxi(0, GameManager.lives)
	_score_label.text = "%08d" % GameManager.score
	_coin_label.text = "×%d" % GameManager.coins
	_hi_label.text = tr("HI-SCORE %d") % GameManager.hi_score


func _on_boss_spawned(display_name: String, hp: int, max_hp: int) -> void:
	_boss_name.text = display_name
	_boss_name.visible = true
	_boss_bar.visible = true
	_set_boss_hp(hp, max_hp)


func _set_boss_hp(hp: int, max_hp: int) -> void:
	while _boss_bar.get_child_count() < max_hp:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(6, 6)
		_boss_bar.add_child(seg)
	while _boss_bar.get_child_count() > max_hp:
		_boss_bar.get_child(_boss_bar.get_child_count() - 1).free()
	for i in _boss_bar.get_child_count():
		(_boss_bar.get_child(i) as ColorRect).color = \
				UIKit.RED if i < hp else UIKit.BG_PANEL


func _on_boss_died() -> void:
	_boss_bar.visible = false
	_boss_name.visible = false


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
