extends GutTest
## Regression for a real shipped bug (v1.13.x): every steam-column updraft
## in stages 1 and 5 was placed DIRECTLY under the deck it was meant to
## lift the player onto, topping out at row 9 against the deck's row-8
## underside. A rising player bonked the deck, the zone re-lifted them,
## forever — and because the lift zone is only 14px wide and the decks
## overhang it on both sides, drifting around the lip was impossible.
## Stage 1's deck coins were uncollectable (100%/S-rank mathematically
## impossible); stage 5's node 2 and USB key 2 sat on those decks, so the
## exit gate could never open and THE STAGE COULD NOT BE FINISHED.
##
## The fix moves each column BESIDE its deck's edge and extends it one
## row above the deck surface: ride up, drift one tile sideways, land.
## A chimney variant (hole in the deck above the column) was rejected:
## updrafts do not center the player horizontally, so a 16px hole traps
## off-center risers against the lip — the same bug re-created.
##
## LIVE physics tests (real stage scene, real Player, real input) on
## purpose: this project has now twice shipped reachability bugs that
## tile math said were fine. The map-level cap rule lives in
## test_stage_completability.gd; these prove the actual climbs.

const STAGE_1_SCENE := preload("res://scenes/levels/stage_1.tscn")
const STAGE_5_SCENE := preload("res://scenes/levels/stage_5.tscn")
## All fixed decks stand at row 7 (y=120). Below 140 means "on a deck":
## the only other standing surfaces in these sections are the floors at
## y=344 (stage 1 pit) and y=296 (stage 5).
const DECK_Y := 140.0
const RIDE_TIMEOUT_FRAMES := 300


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


## Rides the column at the player's current x until the capsule clears the
## deck height, then drifts one tile in `drift_action` and settles.
## enter_with_jump: stage 1's columns end 3 tiles above the pit floor
## (deliberate — walking the pit must not yank the player upward), so the
## rider jumps in; stage 5's columns reach standing height and are walk-in.
func _ride_to_deck(player: Player, drift_action: String,
		enter_with_jump: bool, test_name: String) -> void:
	if enter_with_jump:
		Input.action_press("jump")
	var guard := 0
	while player.position.y > DECK_Y - 10.0 and guard < RIDE_TIMEOUT_FRAMES:
		await wait_physics_frames(1)
		guard += 1
	if enter_with_jump:
		Input.action_release("jump")
	assert_true(guard < RIDE_TIMEOUT_FRAMES,
			"%s: the updraft should carry the player above deck height within %d frames (y=%.1f)" \
			% [test_name, RIDE_TIMEOUT_FRAMES, player.position.y])

	Input.action_press(drift_action)
	await wait_physics_frames(20)
	Input.action_release(drift_action)
	await wait_physics_frames(30) # land and settle


func _assert_standing_on_deck(player: Player, deck_x0: int, deck_x1: int,
		test_name: String) -> void:
	assert_true(player.position.y < DECK_Y,
			"%s: player should be standing on the deck, not back on the floor (y=%.1f, x=%.1f)" \
			% [test_name, player.position.y, player.position.x])
	assert_between(player.position.x, deck_x0 * 16.0, (deck_x1 + 1) * 16.0,
			"%s: player should have landed on the deck (cols %d-%d)" \
			% [test_name, deck_x0, deck_x1])


## Stage 1, first steam column (col 64, right of deck 60-63): the entry
## tile is the one freed by trimming the spike strip from 64-67 to 65-67.
func test_stage1_first_steam_column_lands_on_its_deck() -> void:
	var player: Player = await _boot_with_player(
			STAGE_1_SCENE, Vector2(64 * 16 + 8, 344), "stage1 col64")
	await _ride_to_deck(player, "move_left", true, "stage1 col64")
	_assert_standing_on_deck(player, 60, 63, "stage1 col64")


## Stage 1, middle steam column (col 72, right of deck 68-71).
func test_stage1_middle_steam_column_lands_on_its_deck() -> void:
	var player: Player = await _boot_with_player(
			STAGE_1_SCENE, Vector2(72 * 16 + 8, 344), "stage1 col72")
	await _ride_to_deck(player, "move_left", true, "stage1 col72")
	_assert_standing_on_deck(player, 68, 71, "stage1 col72")


## Stage 5, node-deck column (col 62, left of deck 63-69): walk-in at
## floor level, drift right, land beside mandatory node 2 at (64,7).
func test_stage5_node_deck_column_lands_beside_the_node() -> void:
	var player: Player = await _boot_with_player(
			STAGE_5_SCENE, Vector2(62 * 16 + 8, 296), "stage5 col62")
	await _ride_to_deck(player, "move_right", false, "stage5 col62")
	_assert_standing_on_deck(player, 63, 69, "stage5 col62")


## Stage 5, third-deck column (col 82, left of deck 83-89): the deck the
## old col-86 column could never deliver.
func test_stage5_third_deck_column_lands_on_its_deck() -> void:
	var player: Player = await _boot_with_player(
			STAGE_5_SCENE, Vector2(82 * 16 + 8, 296), "stage5 col82")
	await _ride_to_deck(player, "move_right", false, "stage5 col82")
	_assert_standing_on_deck(player, 83, 89, "stage5 col82")


## The USB-key deck (73-79) has no column of its own BY DESIGN — it is a
## plain 4-col hop from the node deck's right edge (69 -> 73), well inside
## single-jump range. Proves key 2 at (76,7) is collectable once the
## column has delivered the player onto the node deck.
func test_stage5_key_deck_reachable_by_hopping_from_node_deck() -> void:
	var player: Player = await _boot_with_player(
			STAGE_5_SCENE, Vector2(69 * 16 + 8, 120), "stage5 key hop")

	Input.action_press("move_right")
	Input.action_press("jump")
	await wait_physics_frames(40) # jump the 3-col gap, land on the key deck
	Input.action_release("jump")
	var guard := 0
	while player.position.x < 76 * 16 and guard < 120:
		await wait_physics_frames(1)
		guard += 1
	Input.action_release("move_right")
	await wait_physics_frames(10)

	assert_true(player.position.y < DECK_Y,
			"stage5 key hop: player should still be on deck height at the key column (y=%.1f, x=%.1f)" \
			% [player.position.y, player.position.x])
	assert_between(player.position.x, 76 * 16.0, (79 + 1) * 16.0,
			"stage5 key hop: player should have reached USB key 2's column (col 76+)")
