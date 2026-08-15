extends Node
## Orchestrates full-screen gate minigames (docs/GDD.md gate minigames):
## teleports every live Player out (particle burst + fade, the same
## "ai_teleport" flourish Zaf's cutscene uses), pauses the stage, swaps in
## the minigame full-screen, then reverses the transition and reports the
## result to whoever launched it. Gameplay objects (FirewallGate) never
## touch the minigame scenes directly — this is the one seam between them.

## Not `const` — GDScript won't fold a class_name reference into a constant
## dictionary literal (parse error), only preload()/literal values qualify.
var MINIGAMES := {
	&"code_review": CodeReviewMinigame,
	&"ticket_blitz": TicketBlitzMinigame,
	&"presentation_pace": PresentationPaceMinigame,
	&"server_cooling": ServerCoolingMinigame,
	&"circuit_bypass": CircuitBypassMinigame,
}

const TELEPORT_SFX := "ai_teleport"
const FADE_TIME := 0.35
## Above PauseMenu's layer=20 and the HUD's layer=10 — a minigame owns the
## whole screen while it's up (PauseMenu also checks is_active() so the two
## overlays can never show at once).
const CANVAS_LAYER := 30

var _active: CanvasLayer = null
var _on_result: Callable = Callable()
## Spans the ENTIRE transition, not just "an instance currently exists" —
## `_active` is only assigned after the outbound fade and cleared before the
## return fade, so a caller checking `_active != null` could slip a second
## launch() into either ~0.35s fade window and clobber `_on_result` mid-
## flight (review catch: not reachable with any level shipped today — no
## stage has two minigame-gated FirewallGates yet — but the moment one does,
## this is exactly the race that would silently strand the first gate
## unopened, key spent, physics_process never re-enabled).
var _busy := false


func is_active() -> bool:
	return _busy


func _ready() -> void:
	# Defensive chokepoint (mirrors PauseMenu._on_scene_changed's own
	# force-unpause-on-scene-change safety net, review catch): PauseMenu
	# already blocks the only in-game path to a scene swap while a minigame
	# is up, so this shouldn't currently fire — but the CanvasLayer is
	# parented directly to get_tree().root, NOT SceneManager's managed
	# _screen_root, so it would otherwise survive an unrelated future scene
	# swap forever, full-screen and still owning input, on top of whatever
	# loads next. If that ever happens anyway, don't leave the tree stuck
	# paused or the gate's key silently unresolved.
	SceneManager.scene_changed.connect(_on_scene_changed)


func _on_scene_changed(_path: String) -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null
	_busy = false
	_on_result = Callable()
	get_tree().paused = false


## Called by a gate prop once it has committed to spending a key.
## `on_result` receives (success: bool) once the whole transition (minigame
## + return teleport) has finished — the caller decides what to do with it
## (open the gate, or refund the key on a bail-out).
func launch(minigame_id: StringName, on_result: Callable) -> void:
	if _busy or not MINIGAMES.has(minigame_id):
		on_result.call(false)
		return
	_busy = true
	_on_result = on_result
	# Fade-out must finish BEFORE pausing — the tween is bound to this
	# autoload and pause would otherwise freeze it mid-fade with the
	# player sprite stuck at partial alpha.
	await _teleport_players(true)
	get_tree().paused = true
	var minigame_class: GDScript = MINIGAMES[minigame_id]
	# Each minigame sets its own layer (CANVAS_LAYER)/process_mode in
	# _ready() (same self-sufficient pattern as PauseMenu) so it stays
	# instantiable and testable on its own, without going through this
	# launcher.
	var instance: CanvasLayer = minigame_class.new()
	instance.finished.connect(_on_minigame_finished, CONNECT_ONE_SHOT)
	get_tree().root.add_child(instance)
	_active = instance


func _on_minigame_finished(success: bool, bonus: int) -> void:
	if bonus > 0:
		GameManager.add_score(bonus)
	_active.queue_free()
	_active = null
	# Unpause BEFORE the fade-in for the same reason as the outbound fade
	# above; Player.set_physics_process/set_process_unhandled_input stay
	# false regardless (set explicitly, not via tree-pause) until the fade
	# actually completes, so nothing can move mid-materialize either way.
	get_tree().paused = false
	await _teleport_players(false)
	var callback := _on_result
	_on_result = Callable()
	_busy = false
	if callback.is_valid():
		callback.call(success)


## `leaving`: fade the real Player sprites out (minigame is about to take
## over) or back in (minigame is done). A create_timer with process_always
## keeps the fade running through the paused frame it straddles.
func _teleport_players(leaving: bool) -> void:
	AudioManager.play_sfx(TELEPORT_SFX)
	for player in Player.alive.duplicate():
		if not is_instance_valid(player):
			continue
		# Frozen independent of tree-pause: the outbound fade happens BEFORE
		# get_tree().paused flips, and set_physics_process/set_process_
		# unhandled_input(false) survives the later unpause too, so movement
		# only resumes once we explicitly re-enable it at the very end.
		if leaving:
			player.set_physics_process(false)
			player.set_process_unhandled_input(false)
		_spawn_teleport_burst(player)
		player.sprite.visible = true
		var tween := create_tween()
		tween.tween_property(player.sprite, "modulate:a", 0.0 if leaving else 1.0, FADE_TIME)
	await get_tree().create_timer(FADE_TIME).timeout
	for player in Player.alive:
		if not is_instance_valid(player):
			continue
		if leaving:
			player.sprite.visible = false
		else:
			player.set_physics_process(true)
			player.set_process_unhandled_input(true)


func _spawn_teleport_burst(player: Player) -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = Vector2(0, -12)
	sparks.amount = 28
	sparks.lifetime = 0.6
	sparks.one_shot = true
	sparks.explosiveness = 0.85
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 80.0
	sparks.gravity = Vector2(0, 40)
	sparks.color = Color(0.09, 0.88, 0.88)
	sparks.process_mode = Node.PROCESS_MODE_ALWAYS
	player.add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
