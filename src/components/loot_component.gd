class_name LootComponent
extends Node
## Spawns pickups when the owner dies. Spawned loot pops outward with a small
## arc (the pickup scene implements pop(velocity)).

@export var loot_scene: PackedScene
@export var count := 0


func drop(at_global_pos: Vector2) -> void:
	if loot_scene == null or count <= 0:
		return
	# grandparent = the entity's container ('owner' is null for code-built
	# components, so walk the tree instead)
	var parent := get_parent().get_parent()
	for i in count:
		var item: Node2D = loot_scene.instantiate()
		item.global_position = at_global_pos
		parent.add_child(item)
		if item.has_method("pop"):
			# deterministic fan: spread items evenly, alternating sides
			var t := (float(i) / maxf(1.0, count - 1)) - 0.5 if count > 1 else 0.0
			item.pop(Vector2(t * 120.0, -140.0))
