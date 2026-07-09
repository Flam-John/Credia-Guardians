class_name FxService
## Static access to the current scene's pooled FX. Scenes without a
## LevelServices node just skip the flourish (tests, bare debug rooms).

static func hit_spark(tree: SceneTree, at_global: Vector2) -> void:
	var services := LevelServices.find(tree)
	if services != null:
		services.spawn_hit_spark(at_global)
