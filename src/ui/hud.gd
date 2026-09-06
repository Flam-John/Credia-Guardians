class_name HUD
extends Control
## In-game HUD (key-art layout): portrait + segmented HP top-left, score
## under it, coin counter, HI-SCORE top-center. Lives in Main/UILayer and is
## shown only while a stage runs. All updates are EventBus-driven.

const PORTRAITS := preload("res://assets/art/characters/portraits.png")
const COIN_SHEET := preload("res://assets/art/props/coin.png")
const HUD_ATLAS := preload("res://assets/art/ui/hud_atlas.png")
const PICKUPS_SHEET := preload("res://assets/art/props/pickups.png")

# pickups.png regions (see Pickup.Kind order in pickup.gd — FRAME=16)
const REGION_SHIELD_ICON := Rect2(32, 0, 16, 16)
const REGION_UPGRADE_ICON := Rect2(48, 0, 16, 16)
const REGION_USB_ICON := Rect2(64, 0, 16, 16)

# hud_atlas.png regions (see tools/artgen gen_hud_atlas)
const REGION_FRAME := Rect2(0, 0, 24, 24)
const REGION_HP_ON := Rect2(24, 0, 7, 8)
const REGION_HP_OFF := Rect2(24, 8, 7, 8)
const REGION_BOSS_ON := Rect2(32, 0, 6, 6)
const REGION_BOSS_OFF := Rect2(32, 8, 6, 6)
const REGION_PANEL := Rect2(40, 0, 12, 12)

var _portrait: TextureRect
var _hp_box: HBoxContainer
var _portrait2: TextureRect
var _portrait_frame2: TextureRect
var _hp_box2: HBoxContainer
var _boss_bar: HBoxContainer
var _boss_name: Label
var _timer_label: Label
var _timer_enabled := false
var _score_label: Label
var _coin_label: Label
var _hi_label: Label
var _lives_label: Label
var _lives_label2: Label
var _nodes_label: Label
var _usb_icon: TextureRect
var _usb_label: Label
var _shield_icon: TextureRect
var _upgrade_icon: TextureRect
var _shield_icon2: TextureRect
var _upgrade_icon2: TextureRect
var _max_hp := 6


func _ready() -> void:
	# CanvasLayer children don't stretch with anchors (project gotcha — same
	# reason SceneManager sizes screens explicitly). Without this the HUD rect
	# is 0x0 and every anchored child (HI-SCORE, boss bar, timer) collapses
	# to the origin. Explicit size WITHOUT an anchor preset (mixing both
	# fires an engine warning every time — same fix as the pause/scanline/
	# vignette overlays; the CanvasLayer parent never reads this Control's
	# own anchors anyway, so the preset was inert).
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_portrait = TextureRect.new()
	_portrait.position = Vector2(6, 6)
	_portrait.custom_minimum_size = Vector2(20, 20)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.size = Vector2(20, 20)
	add_child(_portrait)
	add_child(_make_portrait_frame(Vector2(4, 4)))

	_hp_box = HBoxContainer.new()
	_hp_box.position = Vector2(30, 8)
	_hp_box.add_theme_constant_override(&"separation", 1)
	add_child(_hp_box)

	# P2 panel (top-right, mirrored) — hidden outside co-op
	_portrait2 = _portrait.duplicate()
	_portrait2.position = Vector2(454, 6)
	_portrait2.visible = false
	add_child(_portrait2)
	_portrait_frame2 = _make_portrait_frame(Vector2(452, 4))
	_portrait_frame2.visible = false
	add_child(_portrait_frame2)
	_hp_box2 = HBoxContainer.new()
	_hp_box2.position = Vector2(400, 8)
	_hp_box2.add_theme_constant_override(&"separation", 1)
	_hp_box2.visible = false
	add_child(_hp_box2)

	_lives_label = _make_label(Vector2(30, 18), 7, UIKit.GRAY)
	add_child(_lives_label)
	# per-player lives (co-op: independent pools, docs/GDD.md §4 — user
	# request 2026-07-23). Placed clear of the P2 shield/upgrade icons
	# (x=400/412, both width 10) rather than reflowing their positions.
	_lives_label2 = _make_label(Vector2(424, 18), 7, UIKit.GRAY)
	_lives_label2.visible = false
	add_child(_lives_label2)

	# per-player collected status (Firewall Shield bubble / Keyboard melee
	# upgrade) — invisible until picked up, hidden again on death since a
	# respawn is a fresh Player instance that never carries them over
	_shield_icon = _make_status_icon(REGION_SHIELD_ICON, Vector2(57, 17))
	_shield_icon.visible = false
	add_child(_shield_icon)
	_upgrade_icon = _make_status_icon(REGION_UPGRADE_ICON, Vector2(69, 17))
	_upgrade_icon.visible = false
	add_child(_upgrade_icon)
	_shield_icon2 = _make_status_icon(REGION_SHIELD_ICON, Vector2(400, 17))
	_shield_icon2.visible = false
	add_child(_shield_icon2)
	_upgrade_icon2 = _make_status_icon(REGION_UPGRADE_ICON, Vector2(412, 17))
	_upgrade_icon2.visible = false
	add_child(_upgrade_icon2)

	_timer_label = _make_label(Vector2.ZERO, 8, UIKit.CYAN)
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# offsets, not position: position is parent-origin-relative and would
	# drag anchored controls off-screen (same for boss bar / HI-SCORE below)
	_timer_label.offset_left = -70
	_timer_label.offset_right = -6
	_timer_label.offset_top = 30
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

	# security-node progress — was silently untracked on screen; a player
	# who misses one has zero feedback that the exit gate is still locked
	# on purpose (review: reported as "the portal didn't open" on stage 3)
	_nodes_label = _make_label(Vector2(6, 52), 8, UIKit.CYAN)
	_nodes_label.visible = false
	add_child(_nodes_label)

	# USB keys: a team-shared resource (any player standing at a firewall
	# gate consumes from the same pool), so one counter, not per-player
	_usb_icon = TextureRect.new()
	var usb_atlas := AtlasTexture.new()
	usb_atlas.atlas = PICKUPS_SHEET
	usb_atlas.region = REGION_USB_ICON
	_usb_icon.texture = usb_atlas
	_usb_icon.position = Vector2(6, 62)
	_usb_icon.size = Vector2(12, 12)
	_usb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_usb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_usb_icon.visible = false
	add_child(_usb_icon)
	_usb_label = _make_label(Vector2(20, 64), 8, UIKit.GOLD)
	_usb_label.visible = false
	add_child(_usb_label)

	# HI-SCORE sits on a beveled panel backing (key-art physical UI)
	var hi_panel := NinePatchRect.new()
	hi_panel.texture = HUD_ATLAS
	hi_panel.region_rect = REGION_PANEL
	hi_panel.patch_margin_left = 4
	hi_panel.patch_margin_top = 4
	hi_panel.patch_margin_right = 4
	hi_panel.patch_margin_bottom = 4
	hi_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# offsets, not position: position would re-derive them from the parent
	# origin and drag the panel off the center anchor
	hi_panel.offset_left = -60
	hi_panel.offset_right = 60
	hi_panel.offset_top = 4
	hi_panel.offset_bottom = 18
	add_child(hi_panel)
	_hi_label = _make_label(Vector2.ZERO, 8, UIKit.GREEN)
	_hi_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hi_label.offset_top = 6
	_hi_label.offset_bottom = 16
	_hi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hi_label)

	_boss_bar = HBoxContainer.new()
	_boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_bar.offset_top = -18
	_boss_bar.offset_bottom = -12
	_boss_bar.add_theme_constant_override(&"separation", 1)
	_boss_bar.visible = false
	add_child(_boss_bar)
	_boss_name = _make_label(Vector2.ZERO, 7, UIKit.RED)
	_boss_name.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_name.offset_top = -28
	_boss_name.offset_bottom = -20
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.visible = false
	add_child(_boss_name)

	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_damaged.connect(_on_hp_signal)
	EventBus.player_healed.connect(_on_hp_signal)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.coin_collected.connect(_on_coin)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_set_boss_hp)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.nodes_total.connect(_on_nodes_total)
	EventBus.node_activated.connect(_on_node_activated)
	EventBus.usb_keys_changed.connect(_on_usb_keys_changed)
	EventBus.player_shield_changed.connect(_on_player_shield_changed)
	EventBus.player_upgrade_changed.connect(_on_player_upgrade_changed)
	SceneManager.scene_changed.connect(_on_scene_changed)


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
		_portrait_frame2.visible = true
		_hp_box2.visible = true
		_lives_label2.visible = true
	_set_hp(typed.health.hp, typed.stats.max_hp, is_p2)
	if not is_p2:
		_max_hp = typed.stats.max_hp
	_refresh_meta()
	# a fresh Player instance never carries a shield/upgrade over from a
	# previous life (docs/GDD.md §8: lost on death) — reset the icons here
	# rather than trusting a "cleared" event from the OLD instance
	(_shield_icon2 if is_p2 else _shield_icon).visible = false
	(_upgrade_icon2 if is_p2 else _upgrade_icon).visible = false


## A death permanently out of lives has no follow-up spawn event to piggy-
## back the refresh on (unlike a respawn, which naturally re-triggers
## _on_player_spawned) — listen directly so the count updates immediately
## either way. GameManager's own listener (connected earlier, so it runs
## first) has already decremented the pool by the time this fires.
func _on_player_died(_player: Node2D) -> void:
	_refresh_meta()


func _on_hp_signal(player_index: int, hp: int, max_hp: int) -> void:
	_set_hp(hp, max_hp, player_index == 2)


func _set_hp(hp: int, max_hp: int, is_p2 := false) -> void:
	var box := _hp_box2 if is_p2 else _hp_box
	while box.get_child_count() < max_hp:
		box.add_child(_make_pill(REGION_HP_OFF, Vector2(7, 8)))
	while box.get_child_count() > max_hp:
		box.get_child(box.get_child_count() - 1).free()
	for i in box.get_child_count():
		var seg := box.get_child(i) as TextureRect
		(seg.texture as AtlasTexture).region = \
				REGION_HP_ON if i < hp else REGION_HP_OFF
	_refresh_meta()


func _on_score_changed(score: int) -> void:
	# read-only: hi-score promotion lives in GameManager.add_score, not in a
	# UI label callback (review P3-18)
	_score_label.text = "%08d" % score
	_hi_label.text = tr("HI-SCORE %d") % GameManager.hi_score


func _on_coin(_value: int) -> void:
	_coin_label.text = "×%d" % GameManager.coins


func _refresh_meta() -> void:
	# P1's own pool (index 1 in co-op, 0 in solo) — separate from P2's, so
	# one player's deaths never drain the other's lives (user request)
	_lives_label.text = "♥×%d" % GameManager.lives_for(1 if GameManager.is_coop() else 0)
	if GameManager.is_coop():
		_lives_label2.text = "♥×%d" % GameManager.lives_for(2)
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
		_boss_bar.add_child(_make_pill(REGION_BOSS_OFF, Vector2(6, 6)))
	while _boss_bar.get_child_count() > max_hp:
		_boss_bar.get_child(_boss_bar.get_child_count() - 1).free()
	for i in _boss_bar.get_child_count():
		var seg := _boss_bar.get_child(i) as TextureRect
		(seg.texture as AtlasTexture).region = \
				REGION_BOSS_ON if i < hp else REGION_BOSS_OFF


func _on_boss_died() -> void:
	_boss_bar.visible = false
	_boss_name.visible = false


func _on_scene_changed(_path: String) -> void:
	# HUD lives in the persistent shell and survives RESTART STAGE / QUIT TO
	# MENU / reload_current — without this, a boss bar left visible from a
	# fight that was in progress when the player died stays stuck showing
	# stale HP after a restart, since the reloaded boss goes dormant again
	# (CeoBoss.activated=false) and won't re-fire boss_spawned until the
	# player re-approaches the arena.
	_boss_bar.visible = false
	_boss_name.visible = false


func _on_nodes_total(total: int) -> void:
	_nodes_label.visible = total > 0
	_nodes_label.text = tr("NODES %d/%d") % [0, total]


func _on_node_activated(_id: StringName, count: int, total: int) -> void:
	_nodes_label.visible = total > 0
	_nodes_label.text = tr("NODES %d/%d") % [count, total]


func _on_usb_keys_changed(count: int) -> void:
	_usb_icon.visible = count > 0
	_usb_label.visible = count > 0
	_usb_label.text = "×%d" % count


func _on_player_shield_changed(player_index: int, active: bool) -> void:
	(_shield_icon2 if player_index == 2 else _shield_icon).visible = active


func _on_player_upgrade_changed(player_index: int, active: bool) -> void:
	(_upgrade_icon2 if player_index == 2 else _upgrade_icon).visible = active


func _make_pill(region: Rect2, pill_size: Vector2) -> TextureRect:
	# each pill owns its AtlasTexture — regions are flipped per-segment
	var seg := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = HUD_ATLAS
	atlas.region = region
	seg.texture = atlas
	seg.custom_minimum_size = pill_size
	seg.stretch_mode = TextureRect.STRETCH_KEEP
	return seg


func _make_status_icon(region: Rect2, pos: Vector2) -> TextureRect:
	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = PICKUPS_SHEET
	atlas.region = region
	icon.texture = atlas
	icon.position = pos
	icon.size = Vector2(10, 10)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _make_portrait_frame(pos: Vector2) -> TextureRect:
	var frame := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = HUD_ATLAS
	atlas.region = REGION_FRAME
	frame.texture = atlas
	frame.position = pos
	frame.size = Vector2(24, 24)
	frame.stretch_mode = TextureRect.STRETCH_KEEP
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _make_label(pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
