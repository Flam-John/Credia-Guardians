class_name FX
extends RefCounted
## Phase 3 glow pass: one shared additive-blend material for glowing
## sprites (coins, dash ghosts, hit sparks, node cores) — cheap bloom
## without a WorldEnvironment.

static var _additive: CanvasItemMaterial


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## SceneManager clears this at exit alongside the sprite caches so the
## static Resource doesn't show up as a leak.
static func clear_cache() -> void:
	_additive = null
