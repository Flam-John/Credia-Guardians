class_name FxService
## Static access to the current level's FX pools via the "level_root" group.
## Falls back to nothing (debug rooms without pools just skip the flourish).

static func hit_spark(tree: SceneTree, at_global: Vector2) -> void:
	var level := tree.get_first_node_in_group(&"level_root")
	if level != null and level.has_method("acquire_hit_spark"):
		var spark: HitSpark = level.acquire_hit_spark()
		spark.burst(at_global)
