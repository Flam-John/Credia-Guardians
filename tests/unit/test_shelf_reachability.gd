extends GutTest
## Regression for two real shipped bugs, same root cause: stage 3's node 2
## and stage 4's key vault (gating node 2 behind a firewall) each sat on a
## shelf 5 tiles (80px) above the floor with no steps in between — reachable
## only by pressing a double jump EARLY (well before the first jump's
## apex), the opposite of the "wait, then double-jump" timing every other
## platformer trains players to use, and which this game's own auto
## Jump->Fall transition (AscentState) punishes hard. Real players
## repeatedly reported the (mandatory, progression-gating) shelves as
## unreachable.
##
## Fixed with a staircase built BESIDE each shelf (tools/levelgen/
## stages_2_4_layout.py), not underneath its overhang: a step placed
## directly under a wide shelf can't work at all, since jumping from
## beneath it drives the player's capsule (24px tall) into the shelf's
## underside within a single physics tick. Climbing beside the shelf and
## stepping onto its left EDGE avoids that.
##
## This is a LIVE physics test (real Player scene, real input, real
## physics ticks) rather than a static ASCII-map scan on purpose: three
## increasingly subtle variants of this exact bug (adjacent-row tile
## embedding, insufficient capsule headroom under an overhang, jumping
## into a ceiling from directly beneath a shelf) were only caught by
## actually driving the Player through the level — none were visible to
## tile-adjacency or reachability math alone.

const STAGE_3_SCENE := preload("res://scenes/levels/stage_3.tscn")
const STAGE_4_SCENE := preload("res://scenes/levels/stage_4.tscn")
## Shelf top in both stages is row 14 (y=224). Comfortably below that
## confirms the climb, without demanding pixel-exact landing.
const SHELF_Y := 232.0


func _find_player(root: Node) -> Player:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Player:
			return n
		stack.append_array(n.get_children())
	return null


## Holds jump for `hold_frames` physics ticks (long enough to clear a
## single ordinary hop without triggering AscentState's short-hop cut),
## then lets a few more frames pass for the landing to settle.
func _hop(player: Player, hold_frames: int, settle_frames: int) -> void:
	Input.action_press("jump")
	for i in hold_frames + 6:
		await wait_physics_frames(1)
		if i == hold_frames:
			Input.action_release("jump")
	await wait_physics_frames(settle_frames)


## Walks/jumps the real Player from `start` up a 3-hop staircase (ground ->
## step -> step -> shelf) using ONLY ordinary single jumps, no double jump.
func _climb_staircase(scene: PackedScene, start: Vector2, test_name: String) -> void:
	var level: Node = scene.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(5)

	var player := _find_player(level)
	assert_not_null(player, "%s: found a live Player in the booted scene" % test_name)

	player.position = start
	player.velocity = Vector2.ZERO
	await wait_physics_frames(15)
	for action in ["jump", "move_right", "move_left"]:
		Input.action_release(action)

	Input.action_press("move_right")
	await wait_physics_frames(10) # walk up to the base of the staircase

	await _hop(player, 8, 5) # ground -> step 1
	await _hop(player, 8, 5) # step 1 -> step 2
	await _hop(player, 8, 5) # step 2 -> shelf

	Input.action_release("move_right")
	await wait_physics_frames(10)

	assert_true(player.position.y < SHELF_Y,
			"%s: player should have reached the shelf (row14, y=224) via ordinary jumps (y=%.1f, x=%.1f)" \
			% [test_name, player.position.y, player.position.x])


func test_stage3_node2_shelf_reachable_via_ordinary_jumps() -> void:
	# Start on col 102 (tile 102 * 16 + 8 = 1640), the single ground tile
	# between hidden vault 1's entrance holes (cols 100-101) and the first
	# step (col 103) — the staircase's real base. Starting further left
	# would walk the player into the vault holes.
	await _climb_staircase(STAGE_3_SCENE, Vector2(1640, 296), "stage3 node2")


func test_stage4_key_vault_shelf_reachable_via_ordinary_jumps() -> void:
	# Start just left of the staircase, on the ground (row19 starts at col89). Tile 89 * 16 + 8 = 1432.
	await _climb_staircase(STAGE_4_SCENE, Vector2(1432, 296), "stage4 key vault")


## Regression for the staircase fix's own regression: the first step was
## drawn 2 cols left of its comment's stated position, landing ON hidden
## vault 1's floor-entrance holes and sealing the vault completely (16px
## of clearance under the step vs the 24px capsule, and no drop-in from
## above either). A player simply walking right along the corridor must
## still fall through the entrance holes (cols 100-101) into the vault.
func test_stage3_hidden_vault_still_enterable_by_walking_in() -> void:
	var level: Node = STAGE_3_SCENE.instantiate()
	add_child_autofree(level)
	await wait_physics_frames(5)

	var player := _find_player(level)
	assert_not_null(player, "stage3 vault: found a live Player in the booted scene")

	# Ground just left of the holes: col 97 (tile 97 * 16 + 8 = 1560).
	player.position = Vector2(1560, 296)
	player.velocity = Vector2.ZERO
	await wait_physics_frames(15)
	for action in ["jump", "move_right", "move_left"]:
		Input.action_release(action)

	Input.action_press("move_right")
	await wait_physics_frames(90) # walk over the holes and drop in
	Input.action_release("move_right")
	await wait_physics_frames(10)

	# Vault interior: cols 100-105 (x 1600-1696), below the floor (y > 320).
	assert_true(player.position.y > 320.0,
			"stage3 vault: walking right over the entrance holes should drop the player below the corridor floor (y=%.1f, x=%.1f)" \
			% [player.position.y, player.position.x])
	assert_between(player.position.x, 1600.0, 1700.0,
			"stage3 vault: player should have landed inside the vault interior")
