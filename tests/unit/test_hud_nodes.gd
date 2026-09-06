extends GutTest
## HUD security-node progress indicator (review: nodes_active/total_nodes
## was tracked internally but never shown on screen - a player who missed
## one node had zero feedback that the exit gate was correctly still
## locked, easily read as "the portal didn't open" for no reason).


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func test_hidden_until_a_stage_reports_its_node_total() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	assert_false(hud._nodes_label.visible, "no stage has reported nodes yet")


func test_nodes_total_shows_zero_progress_immediately() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.nodes_total.emit(3)
	assert_true(hud._nodes_label.visible)
	assert_string_contains(hud._nodes_label.text, "0/3")


func test_node_activated_advances_the_count() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.nodes_total.emit(3)
	EventBus.node_activated.emit(&"node_0", 1, 3)
	assert_string_contains(hud._nodes_label.text, "1/3")
	EventBus.node_activated.emit(&"node_1", 2, 3)
	assert_string_contains(hud._nodes_label.text, "2/3")


func test_stays_hidden_when_a_stage_has_no_nodes() -> void:
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.nodes_total.emit(0)
	assert_false(hud._nodes_label.visible, "debug rooms with zero nodes show nothing")


func test_boss_bar_hides_on_a_scene_change_after_dying_mid_fight() -> void:
	# HUD lives in the persistent shell and survives RESTART STAGE/reload —
	# without resetting on scene_changed, a boss bar left visible from a
	# fight in progress when the player died stayed stuck showing stale HP
	# after a restart, since the reloaded boss goes dormant again and won't
	# re-fire boss_spawned until the player re-approaches the arena.
	var hud := HUD.new()
	add_child_autofree(hud)
	EventBus.boss_spawned.emit("The Chairman", 30, 30)
	assert_true(hud._boss_bar.visible, "sanity: boss fight makes the bar visible")
	assert_true(hud._boss_name.visible)
	SceneManager.scene_changed.emit("res://scenes/levels/stage_5.tscn")
	assert_false(hud._boss_bar.visible, "restart must reset a bar left over from a prior death")
	assert_false(hud._boss_name.visible)
