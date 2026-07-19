extends GutTest
## Regression for two real shipped bugs, same root cause: stage 3's node 2
## and stage 4's key vault (gating node 2 behind a firewall) each sat on a
## shelf 5 tiles (80px) above the floor — reachable only by pressing a
## double jump EARLY (well before the first jump's apex), the opposite of
## the "wait, then double-jump" timing every other platformer trains
## players to use, and which this game's own auto Jump->Fall transition
## (AscentState) punishes hard. Real players repeatedly reported the
## (mandatory, progression-gating) shelves as unreachable.
##
## v1.13 first tried to keep the 80px shelves and add landing staircases
## beside them — rejected on user feedback: the steps rendered as floating
## crates, and their solid tiles sealed stage 3's hidden vault entrance
## and stage 4's col-90 checkpoint (16px of clearance vs the 24px player
## capsule). The shipped fix instead lowers both shelves one tile to 64px,
## inside plain double-jump reach at ANY timing.
##
## These are LIVE physics tests (real Player scene, real input, real
## physics ticks) on purpose: this bug class (jump-arc vs terrain) is
## invisible to tile-adjacency or reachability math alone. The climb test
## deliberately uses the WORST-case double jump — second press only after
## the first jump's apex has passed — so the shelf stays reachable for
## every player timing, not just trained ones.

const STAGE_3_SCENE := preload("res://scenes/levels/stage_3.tscn")
const STAGE_4_SCENE := preload("res://scenes/levels/stage_4.tscn")
## Shelf top in both stages is row 15 (y=240). Comfortably below that
## confirms the climb, without demanding pixel-exact landing.
const SHELF_Y := 248.0


func before_all() -> void:
	SaveManager.redirect_for_tests("user://test_saves", "user://test_settings.cfg")


func _find_player(root: Node) -> Player:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Player:
			return n
		stack.append_array(n.get_children())
	return null


func _boot_with_player(scene: PackedScene, start: Vector2, test_name: String) -> Player:
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
	return player


## Holds the first jump all the way through its apex (a player reaching
## for a high shelf holds jump — releasing early triggers AscentState's
## 0.45x short-hop cut and is not the scenario under test), waits until
## the ascent has clearly ENDED (velocity.y no longer upward, plus 2 extra
## falling frames — the worst possible double-jump moment), then presses
## jump again and holds that too. If this reaches the shelf, any player
## timing does, because DoubleJumpState hard-overwrites velocity.y: a
## later press only loses the height fallen while waiting.
func _worst_case_double_jump(player: Player) -> void:
	Input.action_press("jump")
	await wait_physics_frames(2) # jump starts; velocity.y is now upward
	var guard := 0
	while player.velocity.y < 0.0 and guard < 60:
		await wait_physics_frames(1)
		guard += 1
	Input.action_release("jump")
	await wait_physics_frames(2)
	Input.action_press("jump")
	await wait_physics_frames(15)
	Input.action_release("jump")


## Jumps straight at the shelf's left face while holding move_right: the
## player hugs the face during the ascent (horizontal-only block — rising
## beside a wall is free, unlike rising into an overhang) and slides onto
## the top the moment the double jump lifts the capsule past it. Hugging
## makes the landing self-aligning, so the test needs no walk-up timing.
func _climb_shelf(scene: PackedScene, start: Vector2, test_name: String) -> void:
	var player: Player = await _boot_with_player(scene, start, test_name)

	Input.action_press("move_right")
	await _worst_case_double_jump(player)
	await wait_physics_frames(40) # drift over the edge, land, settle
	Input.action_release("move_right")
	await wait_physics_frames(10)

	assert_true(player.position.y < SHELF_Y,
			"%s: player should reach the shelf (row15, y=240) with a worst-case-timed double jump (y=%.1f, x=%.1f)" \
			% [test_name, player.position.y, player.position.x])


func test_stage3_node2_shelf_reachable_via_worst_case_double_jump() -> void:
	# Ground left of the shelf edge (col 108): col 105 = tile 105 * 16 + 8 = 1688.
	await _climb_shelf(STAGE_3_SCENE, Vector2(1688, 296), "stage3 node2")


func test_stage4_key_vault_shelf_reachable_via_worst_case_double_jump() -> void:
	# Ground left of the shelf edge (col 95), BEFORE the ankle lasers at
	# cols 94-96: col 92 = tile 92 * 16 + 8 = 1480. Jumping immediately
	# (no ground walk-up) crosses the laser columns airborne, well above
	# their hitbox, so the laser phase can't make the test flaky.
	await _climb_shelf(STAGE_4_SCENE, Vector2(1480, 296), "stage4 key vault")


## Regression for the v1.13 staircase regression: solid step tiles drawn
## over hidden vault 1's floor-entrance holes (cols 101-102) sealed the
## vault completely — 16px of clearance under the step vs the 24px capsule,
## and no drop-in from above either. A player simply walking right along
## the corridor must fall through the entrance holes into the vault.
func test_stage3_hidden_vault_still_enterable_by_walking_in() -> void:
	# Ground just left of the holes: col 97 (tile 97 * 16 + 8 = 1560).
	var player: Player = await _boot_with_player(
			STAGE_3_SCENE, Vector2(1560, 296), "stage3 vault")

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
