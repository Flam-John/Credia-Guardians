extends Node
## Music crossfade (2 stream players) + pooled SFX with pitch jitter.
## Missing audio files are tolerated silently during the placeholder-art phase.
## Bus layout: Master / Music / SFX / UI (docs/AUDIO_LIST.md).

const MUSIC_DIR := "res://assets/audio/music"
const SFX_DIR := "res://assets/audio/sfx"
const SFX_POOL_SIZE := 8
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
var _sfx_cache: Dictionary = {}
var _sfx_last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player(&"Music")
	_music_b = _make_player(&"Music")
	_active_music = _music_a
	for i in SFX_POOL_SIZE:
		_sfx_pool.append(_make_player(&"SFX"))


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
	_active_music = incoming


func stop_music(fade_sec: float = 0.5) -> void:
	_current_track = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_active_music, "volume_db", -40.0, fade_sec)
	_music_tween.tween_callback(_active_music.stop)


func play_sfx(name_: String, jitter: bool = true) -> void:
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
	var player := _sfx_pool[_sfx_next]
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
