class_name SpriteFramesBuilder
extends RefCounted
## Slices a character sheet into SpriteFrames at runtime.
##
## Row order/frame counts MUST match tools/artgen/generate_placeholders.py
## (PLAYER_ANIMS) and docs/ANIMATION_LIST.md. Final art that follows the same
## layout drops in with zero code changes.

const FRAME_SIZE := 32

## {name, frames, fps, loop} per row; row index = array index.
const PLAYER_ANIMS: Array[Dictionary] = [
	{"name": &"idle", "frames": 4, "fps": 6.0, "loop": true},
	{"name": &"run", "frames": 8, "fps": 12.0, "loop": true},
	{"name": &"jump", "frames": 2, "fps": 8.0, "loop": false},
	{"name": &"fall", "frames": 2, "fps": 8.0, "loop": true},
	{"name": &"double_jump", "frames": 4, "fps": 14.0, "loop": false},
	{"name": &"dash", "frames": 3, "fps": 18.0, "loop": true},
	{"name": &"attack_1", "frames": 4, "fps": 16.0, "loop": false},
	{"name": &"attack_2", "frames": 4, "fps": 16.0, "loop": false},
	{"name": &"attack_3", "frames": 5, "fps": 14.0, "loop": false},
	{"name": &"air_attack", "frames": 4, "fps": 16.0, "loop": false},
	{"name": &"hurt", "frames": 2, "fps": 10.0, "loop": false},
	{"name": &"death", "frames": 6, "fps": 8.0, "loop": false},
	{"name": &"ability", "frames": 3, "fps": 10.0, "loop": true},
	{"name": &"victory", "frames": 4, "fps": 6.0, "loop": true},
	{"name": &"interact", "frames": 2, "fps": 6.0, "loop": true},
	{"name": &"spawn", "frames": 4, "fps": 12.0, "loop": false},
]


## Enemy sheet row tables: MUST match tools/artgen ENEMY_LAYOUTS and
## docs/ANIMATION_LIST.md. size = square frame edge in px.
const ENEMY_LAYOUTS: Dictionary = {
	"junior_banker": {
		"size": 24,
		"anims": [
			{"name": &"walk", "frames": 4, "fps": 8.0, "loop": true},
			{"name": &"panic_run", "frames": 4, "fps": 14.0, "loop": true},
			{"name": &"death", "frames": 3, "fps": 10.0, "loop": false},
		],
	},
	"angry_manager": {
		"size": 32,
		"anims": [
			{"name": &"idle", "frames": 2, "fps": 4.0, "loop": true},
			{"name": &"alert", "frames": 2, "fps": 10.0, "loop": false},
			{"name": &"charge", "frames": 4, "fps": 14.0, "loop": true},
			{"name": &"wall_stun", "frames": 3, "fps": 6.0, "loop": true},
			{"name": &"death", "frames": 3, "fps": 10.0, "loop": false},
		],
	},
	"auditor": {
		"size": 32,
		"anims": [
			{"name": &"idle", "frames": 2, "fps": 4.0, "loop": true},
			{"name": &"hop_back", "frames": 3, "fps": 12.0, "loop": false},
			{"name": &"throw", "frames": 4, "fps": 12.0, "loop": false},
			{"name": &"death", "frames": 3, "fps": 10.0, "loop": false},
		],
	},
	"loan_shark": {
		"size": 40,
		"anims": [
			{"name": &"hidden_fin", "frames": 2, "fps": 4.0, "loop": true},
			{"name": &"emerge", "frames": 3, "fps": 14.0, "loop": false},
			{"name": &"lunge", "frames": 3, "fps": 16.0, "loop": false},
			{"name": &"recover", "frames": 2, "fps": 6.0, "loop": true},
			{"name": &"death", "frames": 4, "fps": 10.0, "loop": false},
		],
	},
	"ai_banker": {
		"size": 48,
		"anims": [
			{"name": &"float", "frames": 4, "fps": 6.0, "loop": true},
			{"name": &"teleport_out", "frames": 3, "fps": 14.0, "loop": false},
			{"name": &"teleport_in", "frames": 3, "fps": 14.0, "loop": false},
			{"name": &"cast", "frames": 4, "fps": 10.0, "loop": false},
			{"name": &"stagger", "frames": 2, "fps": 6.0, "loop": true},
			{"name": &"death", "frames": 5, "fps": 10.0, "loop": false},
		],
	},
}

## SpriteFrames are read-only after build, so instances share them safely.
## Cache avoids ~58 RefCounted allocations per respawn (docs/PERFORMANCE.md).
static var _cache: Dictionary = {}


static func build_player_frames(sheet: Texture2D) -> SpriteFrames:
	return _build(sheet, PLAYER_ANIMS, FRAME_SIZE)


static func build_enemy_frames(sheet: Texture2D, layout_key: String) -> SpriteFrames:
	assert(ENEMY_LAYOUTS.has(layout_key), "Unknown enemy layout '%s'" % layout_key)
	var layout: Dictionary = ENEMY_LAYOUTS[layout_key]
	return _build(sheet, layout.anims, layout.size)


static func _build(sheet: Texture2D, anims: Array, frame_size: int) -> SpriteFrames:
	if _cache.has(sheet):
		return _cache[sheet]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in anims.size():
		var anim: Dictionary = anims[row]
		var anim_name: StringName = anim.name
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, anim.fps)
		frames.set_animation_loop(anim_name, anim.loop)
		for i in int(anim.frames):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size, row * frame_size, frame_size, frame_size)
			frames.add_frame(anim_name, atlas)
	_cache[sheet] = frames
	return frames
