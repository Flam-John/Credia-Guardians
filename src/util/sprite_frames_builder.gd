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


## SpriteFrames are read-only after build, so instances share them safely.
## Cache avoids ~58 RefCounted allocations per respawn (docs/PERFORMANCE.md).
static var _cache: Dictionary = {}


static func build_player_frames(sheet: Texture2D) -> SpriteFrames:
	if _cache.has(sheet):
		return _cache[sheet]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in PLAYER_ANIMS.size():
		var anim: Dictionary = PLAYER_ANIMS[row]
		var anim_name: StringName = anim.name
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, anim.fps)
		frames.set_animation_loop(anim_name, anim.loop)
		for i in int(anim.frames):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(anim_name, atlas)
	_cache[sheet] = frames
	return frames
