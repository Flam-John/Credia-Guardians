class_name HUD
extends Control
## In-game HUD (key-art layout): portrait + segmented HP top-left, score
## under it, coin counter, HI-SCORE top-center. Lives in Main/UILayer and is
## shown only while a stage runs. All updates are EventBus-driven.

const PORTRAITS := preload("res://assets/art/characters/portraits.png")
const COIN_SHEET := preload("res://assets/art/props/coin.png")

var _portrait: TextureRect
var _hp_box: HBoxContainer
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

	_lives_label = _make_label(Vector2(30, 18), 7, UIKit.GRAY)
	add_child(_lives_label)

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

	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_damaged.connect(_set_hp)
	EventBus.player_healed.connect(_set_hp)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.coin_collected.connect(_on_coin)


func _on_player_spawned(player: Node2D) -> void:
	var typed := player as Player
	_max_hp = typed.stats.max_hp
	var atlas := AtlasTexture.new()
	atlas.atlas = PORTRAITS
	atlas.region = Rect2((0 if typed.stats.display_name == "Chris" else 1) * 32, 0, 32, 32)
	_portrait.texture = atlas
	_set_hp(typed.health.hp, _max_hp)
	_refresh_meta()


func _set_hp(hp: int, max_hp: int) -> void:
	_max_hp = max_hp
	while _hp_box.get_child_count() < max_hp:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(7, 8)
		_hp_box.add_child(seg)
	while _hp_box.get_child_count() > max_hp:
		_hp_box.get_child(_hp_box.get_child_count() - 1).free()
	for i in _hp_box.get_child_count():
		(_hp_box.get_child(i) as ColorRect).color = \
				UIKit.GREEN if i < hp else UIKit.BG_PANEL
	_refresh_meta()


func _on_score_changed(score: int) -> void:
	_score_label.text = "%08d" % score
	if score > GameManager.hi_score:
		GameManager.hi_score = score
	_hi_label.text = "HI-SCORE %d" % GameManager.hi_score


func _on_coin(_value: int) -> void:
	_coin_label.text = "×%d" % GameManager.coins


func _refresh_meta() -> void:
	_lives_label.text = "♥×%d" % maxi(0, GameManager.lives)
	_score_label.text = "%08d" % GameManager.score
	_coin_label.text = "×%d" % GameManager.coins
	_hi_label.text = "HI-SCORE %d" % GameManager.hi_score


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
