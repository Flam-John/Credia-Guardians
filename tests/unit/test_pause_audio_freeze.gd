extends GutTest
## User request (2026-07-23): pausing the game must freeze everything behind
## the pause overlay. Gameplay itself already respected SceneTree.paused
## (default process_mode); the one real gap was AudioManager, which is
## PROCESS_MODE_ALWAYS so its own menu-click feedback keeps working while
## paused -- but that also meant music/gameplay SFX kept playing right
## through a pause. AudioManager now mirrors EventBus.pause_toggled onto its
## music players + gameplay SFX pool, while a separate small UI-bus pool
## (routed via play_sfx's explicit `ui` param, not by sfx name -- two review
## passes caught that name-sniffing would misroute gameplay one-shots that
## happen to reuse a menu sound's filename, e.g. firewall_gate's "denied"
## blip) stays exempt so the pause menu itself never goes silent.
##
## Note: AudioStreamPlayer.stream_paused only actually "sticks" (readable
## back as true) once .play() has been called and playback is live -- an
## idle player silently ignores the flag (nothing to pause). So these tests
## only assert on players that are actually playing, which is also the only
## case that matters for a real freeze.

func after_each() -> void:
	EventBus.pause_toggled.emit(false) # always leave AudioManager unpaused
	AudioManager.stop_music(0.0)


func test_pause_freezes_a_playing_gameplay_sfx_voice() -> void:
	var idx := AudioManager._sfx_next
	AudioManager.play_sfx("jump", false)
	EventBus.pause_toggled.emit(true)
	assert_true(AudioManager._sfx_pool[idx].stream_paused,
			"the voice actually playing this SFX freezes")


func test_unpause_resumes_a_frozen_gameplay_sfx_voice() -> void:
	var idx := AudioManager._sfx_next
	AudioManager.play_sfx("dash", false) # distinct name -- avoids the 50ms dedup window vs test 1
	EventBus.pause_toggled.emit(true)
	EventBus.pause_toggled.emit(false)
	assert_false(AudioManager._sfx_pool[idx].stream_paused, "resumes on unpause")


func test_pause_freezes_playing_music() -> void:
	AudioManager.play_music("menu", 1.0)
	EventBus.pause_toggled.emit(true)
	assert_true(AudioManager._active_music.stream_paused, "music freezes in place")
	assert_false(AudioManager._music_tween.is_running(), "the crossfade itself freezes too")


func test_unpause_resumes_playing_music() -> void:
	AudioManager.play_music("menu", 1.0)
	EventBus.pause_toggled.emit(true)
	EventBus.pause_toggled.emit(false)
	assert_false(AudioManager._active_music.stream_paused)
	assert_true(AudioManager._music_tween.is_running(), "the crossfade resumes where it left off")


## Regression: a Tween that has already finished naturally (e.g. an old
## crossfade long done) throws an engine error on .play() -- AudioManager
## must forget it (null it out) once it finishes so a later pause/unpause
## never touches a dead Tween.
func test_pause_unpause_after_music_tween_already_finished_does_not_error() -> void:
	AudioManager.play_music("menu", 0.0) # 0-duration crossfade finishes almost immediately
	await wait_physics_frames(5)
	assert_true(AudioManager._music_tween == null or not AudioManager._music_tween.is_valid(),
			"sanity: the crossfade really has finished by now")
	EventBus.pause_toggled.emit(true) # must not throw
	EventBus.pause_toggled.emit(false) # must not throw ("Can't play finished Tween")


func test_pause_does_not_silence_menu_navigation_sfx() -> void:
	var idx := AudioManager._ui_sfx_next
	AudioManager.play_sfx("menu_select", false, true)
	EventBus.pause_toggled.emit(true)
	assert_false(AudioManager._ui_sfx_pool[idx].stream_paused,
			"the pause menu's own hover/select feedback must keep working while paused")


func test_ui_true_routes_to_the_exempt_pool_not_the_gameplay_pool() -> void:
	var gameplay_before := AudioManager._sfx_next
	AudioManager.play_sfx("menu_move", false, true)
	assert_eq(AudioManager._sfx_next, gameplay_before,
			"a ui=true call must not consume a gameplay SFX pool voice")


## Regression (review-caught): routing used to be inferred from the sfx
## NAME, which silently exempted gameplay sounds that happen to reuse a menu
## sfx's filename for an unrelated purpose (firewall_gate.gd's locked-gate
## "denied" blip, the CEO boss's invuln "clink" both play "menu_back").
## Without an explicit `ui` argument those must land in the freezable
## gameplay pool like every other gameplay sound.
func test_gameplay_sound_reusing_a_menu_sfx_name_still_freezes_by_default() -> void:
	var idx := AudioManager._sfx_next
	AudioManager.play_sfx("menu_back", false) # ui defaults to false
	EventBus.pause_toggled.emit(true)
	assert_true(AudioManager._sfx_pool[idx].stream_paused,
			"a gameplay call must freeze even if it happens to share a menu sfx's name")


## Regression (review-caught, high severity): RESTART STAGE / QUIT TO MENU
## clear get_tree().paused DIRECTLY (game_manager.gd/scene_manager.gd),
## never through PauseMenu._toggle() -- so EventBus.pause_toggled(false)
## would never fire and AudioManager would stay frozen forever. The fix
## makes PauseMenu._on_scene_changed (the one chokepoint every such path
## already routes through via SceneManager.scene_changed) also emit
## pause_toggled(false). Drives the REAL PauseMenu node, not a shortcut.
func test_scene_change_from_a_paused_state_unfreezes_audio() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var idx := AudioManager._sfx_next
	AudioManager.play_sfx("land", false)
	EventBus.pause_toggled.emit(true)
	assert_true(AudioManager._sfx_pool[idx].stream_paused, "sanity: actually frozen")
	# what every force-unpausing path (retry_stage/quit_to_menu/change_scene)
	# has in common: SceneManager.scene_changed fires once the new scene is in
	SceneManager.scene_changed.emit("res://scenes/ui/main_menu.tscn")
	assert_false(AudioManager._sfx_pool[idx].stream_paused,
			"a scene change taken from a paused state must unfreeze audio")
