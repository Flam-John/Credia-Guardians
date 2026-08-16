extends GutTest
## Zaf's in-game ghost intro: materialize -> talk (NEXT/SKIP) -> dissolve,
## pausing/unpausing the real (test) tree around it, plus the explicit
## player/enemy freeze that closes the SceneManager pause-timing race (see
## the class doc comment). Ticks are driven directly (not via the real
## Timer) so the test doesn't depend on wall-clock idle time.

const JUNIOR := preload("res://scenes/entities/enemies/junior_banker.tscn")
const PLAYER_SCENE := preload("res://scenes/entities/player/player.tscn")
const CHRIS := preload("res://data/characters/chris.tres")


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func after_all() -> void:
	SaveManager.restore_default_paths()


func after_each() -> void:
	GameManager.character2 = &""
	get_tree().paused = false


func _make_parent() -> Node2D:
	var parent := Node2D.new()
	add_child_autofree(parent)
	return parent


## Ghost's world-space character is added as a sibling of whatever else
## lives under `parent` (see ZafGhostIntro._build_world_sprite) — auto-
## freeing `parent` (not `zaf` directly) cleans up that sibling too,
## regardless of which phase a given test leaves the ghost in.
func _spawn(parent: Node2D = null) -> ZafGhostIntro:
	if parent == null:
		parent = _make_parent()
	var zaf := ZafGhostIntro.new()
	parent.add_child(zaf)
	return zaf


func test_pauses_one_frame_later_and_materializes_before_showing_the_panel() -> void:
	var zaf := _spawn()
	# Regression: SceneManager.change_scene() unconditionally unpauses right
	# after instantiating the new scene, which runs synchronously as part
	# of THIS node's own creation — the actual pause is deferred one frame
	# specifically so it survives that reset (see the class doc comment).
	assert_false(get_tree().paused, "the pause must be deferred, not set synchronously in _ready()")
	await wait_process_frames(1)
	assert_true(get_tree().paused, "...but must actually take hold one frame later")
	assert_eq(zaf._phase, zaf.Phase.ENTER)
	assert_false(zaf._panel.visible, "Zaf appears before the dialog shows")
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	assert_eq(zaf._phase, zaf.Phase.TALK)
	assert_true(zaf._panel.visible)


func test_next_advances_pages_then_skip_departs_and_unpauses() -> void:
	var zaf := _spawn()
	await wait_process_frames(1)
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	var page_count: int = zaf._pages.size()
	assert_gt(page_count, 1, "there is more than one tutorial page")
	for i in page_count - 1:
		zaf._on_next()
	assert_eq(zaf._index, page_count - 1, "advanced through every page")
	zaf._on_next() # past the last page: departs on its own
	assert_eq(zaf._phase, zaf.Phase.LEAVE)
	for i in zaf.MATERIALIZE_FRAMES + 1:
		zaf._tick()
	assert_false(get_tree().paused, "control must hand back once Zaf is done")


func test_skip_departs_immediately_and_unpauses() -> void:
	var zaf := _spawn()
	await wait_process_frames(1)
	for i in zaf.MATERIALIZE_FRAMES:
		zaf._tick()
	zaf._depart()
	assert_eq(zaf._phase, zaf.Phase.LEAVE)
	for i in zaf.MATERIALIZE_FRAMES + 1:
		zaf._tick()
	assert_false(get_tree().paused)


func test_finish_is_idempotent() -> void:
	var zaf := _spawn()
	watch_signals(zaf)
	zaf._phase = zaf.Phase.LEAVE
	zaf._anim = 0
	zaf._tick() # anim -> -1, calls _finish()
	zaf._finish() # a stray second call must not double-emit/double-unpause
	assert_signal_emit_count(zaf, "finished", 1, "_finish is idempotent")


func test_controls_page_lists_current_keys() -> void:
	var zaf := _spawn()
	var page: String = zaf._controls_page()
	assert_string_contains(page, SettingsApplier.key_label(&"jump"))
	assert_string_contains(page, SettingsApplier.key_label(&"attack"))


func test_controls_page_adds_p2_keys_in_coop() -> void:
	GameManager.character2 = &"flam"
	var zaf := _spawn()
	var page: String = zaf._controls_page()
	assert_string_contains(page, SettingsApplier.p2_key_label(&"jump"))


## Regression: the materialize spark burst (CPUParticles2D) froze mid-
## animation once the tree paused (default PROCESS_MODE_INHERIT), leaving
## a permanent cluster of cyan blotches stuck on Zaf's head/chest for as
## long as he kept talking — the world holder must stay ALWAYS so the
## burst actually finishes its fade instead of freezing.
func test_world_sprite_holder_stays_active_through_the_pause() -> void:
	var zaf := _spawn()
	assert_eq(zaf._world_holder.process_mode, Node.PROCESS_MODE_ALWAYS,
			"the sparks must be able to finish their burst while the tree is paused")


# -- freezing gameplay (bug fix: an enemy kept moving and hit the player) --------------

## Regression: SceneManager.change_scene() unconditionally unpauses right
## after this node's own creation (see the class doc comment) — relying on
## get_tree().paused alone left a real window where an enemy already in
## the stage could act. This must hold true independent of the pause flag.
func test_spawning_the_ghost_freezes_every_enemy_in_the_stage() -> void:
	var parent := _make_parent()
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	parent.add_child(junior)
	assert_true(junior.is_physics_processing(), "sanity: the enemy starts able to act")
	_spawn(parent)
	assert_false(junior.is_physics_processing(), "the enemy must freeze the instant Zaf appears")


func test_finishing_unfreezes_every_enemy_again() -> void:
	var parent := _make_parent()
	var junior: JuniorBanker = JUNIOR.instantiate()
	junior.sleep_when_offscreen = false
	parent.add_child(junior)
	var zaf := _spawn(parent)
	zaf._finish()
	assert_true(junior.is_physics_processing(), "the enemy must be able to act again once Zaf is done")


func test_spawning_the_ghost_freezes_every_live_player() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.stats = CHRIS
	player.position = Vector2(2000, 2000)
	add_child_autofree(player)
	assert_true(player.is_physics_processing(), "sanity: the player starts able to act")
	_spawn()
	assert_false(player.is_physics_processing(), "the player must freeze the instant Zaf appears")
	Player.alive.erase(player) # defensive: this test's own cleanup, not the real game's


func test_finishing_unfreezes_the_player_again() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.stats = CHRIS
	player.position = Vector2(2000, 2000)
	add_child_autofree(player)
	var zaf := _spawn()
	zaf._finish()
	assert_true(player.is_physics_processing(), "the player must be able to act again once Zaf is done")
	Player.alive.erase(player)
