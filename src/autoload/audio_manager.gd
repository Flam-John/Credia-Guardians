extends Node
## Music crossfade (2 stream players) + pooled SFX with pitch jitter.
## Missing audio files are tolerated silently during the placeholder-art phase.
## Bus layout: Master / Music / SFX / UI (docs/AUDIO_LIST.md).

const MUSIC_DIR := "res://assets/audio/music"
const SFX_DIR := "res://assets/audio/sfx"
const SFX_POOL_SIZE := 8
## Small dedicated pool for menu-navigation blips (bus "UI") — deliberately
## exempt from the gameplay pause-freeze below, since PauseMenu itself stays
## PROCESS_MODE_ALWAYS and its own button hover/select feedback must keep
## working while the tree is paused (user request 2026-07-23: pause should
## freeze the game world, not go silent on its own menu). Routing is by
## explicit caller intent (play_sfx's `ui` param), NOT by sfx name — several
## gameplay one-shots (e.g. firewall_gate's locked-gate "denied" blip, the
## CEO boss's invuln "clink") reuse the same audio file as a real menu sound
## under a different meaning, so name-sniffing would misroute them into the
## pause-exempt pool too.
const UI_SFX_POOL_SIZE := 2
const PITCH_JITTER := 0.05
## Two identical SFX within this window are merged (pool guard).
const DUPLICATE_WINDOW_MS := 50

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music: AudioStreamPlayer
var _current_track: String = ""
## The in-flight crossfade; killed when a new one starts so its deferred
## stop() can't silence a track started after it.
var _music_tween: Tween
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _ui_sfx_pool: Array[AudioStreamPlayer] = []
var _ui_sfx_next := 0
var _sfx_cache: Dictionary = {}
var _sfx_last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_active_music = _music_a
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player(&"SFX"))
	for i in UI_SFX_POOL_SIZE:
		_ui_sfx_pool.append(_make_player(&"UI"))
	EventBus.pause_toggled.connect(_on_pause_toggled)


## Freezes gameplay music/SFX in place on pause, resumes them exactly where
## they left off on unpause — the UI pool (menu blips) is untouched so the
## pause menu itself stays fully responsive (review: don't silence PauseMenu
## navigation feedback, which runs while the tree is already paused).
func _on_pause_toggled(paused: bool) -> void:
	_music_a.stream_paused = paused
	_music_b.stream_paused = paused
	if _music_tween != null and _music_tween.is_valid():
		if paused:
			_music_tween.pause()
		else:
			_music_tween.play()
	for p in _sfx_pool:
		p.stream_paused = paused


func play_music(track: String, crossfade_sec: float = 1.0) -> void:
	if track == _current_track:
		return
	var stream := _load_music(track)
	if stream == null:
		return
	_current_track = track
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var incoming := _music_b if _active_music == _music_a else _music_a
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, crossfade_sec)
	_music_tween.tween_property(_active_music, "volume_db", -40.0, crossfade_sec)
	_music_tween.chain().tween_callback(_active_music.stop)
	_forget_tween_when_finished(_music_tween)
	_active_music = incoming


func stop_music(fade_sec: float = 0.5) -> void:
	_current_track = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	# fade BOTH players: killing a mid-crossfade tween orphans the outgoing
	# track at half volume if only _active_music is stopped (review P4-29)
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(_music_a, "volume_db", -40.0, fade_sec)
	_music_tween.tween_property(_music_b, "volume_db", -40.0, fade_sec)
	_music_tween.chain().tween_callback(_music_a.stop)
	_music_tween.chain().tween_callback(_music_b.stop)
	_forget_tween_when_finished(_music_tween)


## A Tween that has already finished throws on .play() ("Can't play finished
## Tween") -- forgetting it here means _on_pause_toggled's `!= null` check
## alone is enough to skip a dead tween instead of ever touching it again.
func _forget_tween_when_finished(tween: Tween) -> void:
	tween.finished.connect(func() -> void:
		if _music_tween == tween:
			_music_tween = null)


## ui=true routes to the small pause-exempt pool (menu navigation feedback
## that must keep playing while the tree is paused) instead of the gameplay
## pool that freezes on pause -- callers opt in explicitly rather than this
## being inferred from the sfx name (see UI_SFX_POOL_SIZE comment above).
func play_sfx(name_: String, jitter: bool = true, ui: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_sfx_last_played.get(name_, -DUPLICATE_WINDOW_MS)) < DUPLICATE_WINDOW_MS:
		return
	var stream: AudioStream = _sfx_cache.get(name_)
	if stream == null:
		stream = _load_stream("%s/%s.wav" % [SFX_DIR, name_])
		if stream == null:
			return
		_sfx_cache[name_] = stream
	_sfx_last_played[name_] = now
	var player: AudioStreamPlayer
	if ui:
		player = _ui_sfx_pool[_ui_sfx_next]
		_ui_sfx_next = (_ui_sfx_next + 1) % UI_SFX_POOL_SIZE
	else:
		player = _sfx_pool[_sfx_next]
		_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER) if jitter else 1.0
	player.play()


## linear is 0..1 from the options sliders.
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear < 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.01)))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


## Music may ship as .ogg (final) or .wav (audiogen placeholder); wav loops
## are forced on since import defaults have them off.
func _load_music(track: String) -> AudioStream:
	for ext in ["ogg", "wav"]:
		var stream := _load_stream("%s/%s.%s" % [MUSIC_DIR, track, ext])
		if stream == null:
			continue
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = stream.data.size() / 2 # 16-bit mono frames
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
		return stream
	return null
