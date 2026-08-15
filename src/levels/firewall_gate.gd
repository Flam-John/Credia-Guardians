class_name FirewallGate
extends GateProp
## Locked barrier consuming a USB Security Key (docs/GDD.md §8). Opens the
## moment any overlapping player's party holds a key.
##
## Geometry contracts (playability audits): trigger WIDER than the blocker
## (a body pressed against the gate must overlap the trigger), blocker
## TALLER than max double jump 89px (or the key mechanic is hoppable).


## Count, not a single ref — P2 brushing past froze the poll while P1
## waited at the gate (review P1-7).
var _players_inside := 0

## Non-empty routes the unlock through a full-screen minigame (MinigameLauncher)
## instead of opening the instant a key is available. Set by the
## "D"/"T"/"H"/"G" legend markers in level_base.gd — plain "F" gates leave
## this empty and keep the original instant-unlock behavior untouched.
@export var minigame_id: StringName = &""

## After a cancelled minigame, _try_open() would otherwise fire again on the
## very next physics tick (key refunded + player still standing in the
## trigger) and instantly relaunch the same minigame with no chance to
## actually step away. A plain timer only delayed that surprise by a second
## (review catch: standing still and waiting is not a deliberate retry) —
## so retrying now genuinely requires the player to leave the trigger and
## come back; only _on_body_entered (a fresh entry) may re-arm polling.
var _awaiting_reentry := false


func _init() -> void:
	trigger_size = Vector2(40, 60)
	blocker_size = Vector2(16, 96)
	sprite_tint = Color(1.0, 0.7, 0.4) # amber ≠ exit gate


func _gate_ready() -> void:
	# faint energy column so the extended barrier reads on screen
	var column := ColorRect.new()
	column.color = Color(1.0, 0.6, 0.3, 0.3)
	column.size = Vector2(6, 40)
	column.position = Vector2(-3, -100)
	_blocker.add_child(column)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	_try_open()


func _try_open() -> void:
	if open or _players_inside <= 0 or GameManager.usb_keys <= 0 or _awaiting_reentry:
		return
	if minigame_id != &"" and MinigameLauncher.is_active():
		return # another gate's minigame is still resolving
	GameManager.add_usb_keys(-1)
	if minigame_id == &"":
		open_gate()
		return
	# Stop polling while the minigame owns the screen; on cancel we refund
	# the key and require a genuine exit+re-entry before another attempt —
	# see _awaiting_reentry above.
	set_physics_process(false)
	MinigameLauncher.launch(minigame_id, func(success: bool) -> void:
		if success:
			open_gate()
		else:
			GameManager.add_usb_keys(1)
			_awaiting_reentry = true)


func _gate_opened() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)


func _on_body_entered(body: Node2D) -> void:
	if open or body is not Player:
		return
	_players_inside += 1
	set_physics_process(true)
	if GameManager.usb_keys <= 0:
		AudioManager.play_sfx("menu_back") # locked "denied" blip
	_try_open()


func _on_body_exited(body: Node2D) -> void:
	if body is not Player:
		return
	_players_inside = maxi(0, _players_inside - 1)
	if _players_inside == 0:
		set_physics_process(false)
		_awaiting_reentry = false # a full exit clears the gate; the next entry may retry
