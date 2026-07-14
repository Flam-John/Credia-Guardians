extends GutTest
## HUD inventory display: USB key counter (team-shared) and per-player
## Firewall Shield / Keyboard Upgrade status icons (individual in co-op).

const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.add_usb_keys(-GameManager.usb_keys)


func test_usb_key_counter_hidden_until_first_key() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	assert_false(hud._usb_icon.visible)
	assert_false(hud._usb_label.visible)


func test_add_usb_keys_updates_hud_and_clamps_at_zero() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	GameManager.add_usb_keys(2)
	assert_true(hud._usb_icon.visible)
	assert_eq(hud._usb_label.text, "×2")
	GameManager.add_usb_keys(-5) # gate/pickup math must never go negative
	assert_eq(GameManager.usb_keys, 0)
	assert_false(hud._usb_icon.visible, "counter hides again at zero")


func test_start_stage_resets_and_broadcasts_zero_keys() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	GameManager.add_usb_keys(3)
	GameManager.start_stage(1, &"chris")
	assert_eq(GameManager.usb_keys, 0)
	assert_false(hud._usb_icon.visible, "a new stage starts with zero keys")
	GameManager.end_stage()


func test_shield_and_upgrade_icons_are_per_player() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.player_shield_changed.emit(1, true)
	assert_true(hud._shield_icon.visible, "P1 shield shows")
	assert_false(hud._shield_icon2.visible, "P2 unaffected by P1's pickup")
	EventBus.player_upgrade_changed.emit(2, true)
	assert_true(hud._upgrade_icon2.visible, "P2 upgrade shows")
	assert_false(hud._upgrade_icon.visible, "P1 unaffected by P2's pickup")
	EventBus.player_shield_changed.emit(1, false)
	assert_false(hud._shield_icon.visible, "consuming the shield hides it again")


func test_player_spawn_resets_status_icons_for_that_slot() -> void:
	# a respawn is a fresh Player instance that never carries a shield or
	# upgrade over (docs/GDD.md §8: lost on death) - the HUD must not keep
	# showing icons for effects the new instance doesn't have
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.player_shield_changed.emit(1, true)
	EventBus.player_upgrade_changed.emit(1, true)
	assert_true(hud._shield_icon.visible)
	assert_true(hud._upgrade_icon.visible)
	var player: Player = PLAYER_SCENE.instantiate()
	player.stats = CHRIS
	player.player_index = 1
	add_child_autofree(player)
	assert_false(hud._shield_icon.visible, "respawn clears the stale shield icon")
	assert_false(hud._upgrade_icon.visible, "respawn clears the stale upgrade icon")
