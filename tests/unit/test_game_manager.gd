extends GutTest
## GameManager rank table (docs/GDD.md §9) including boundary values.


func _stats(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"coins": 100, "total_coins": 100,
		"nodes": 3, "total_nodes": 3,
		"time": 250.0, "par_time": 300.0,
		"deaths": 0, "hit_zero_lives": false,
	}
	base.merge(overrides, true)
	return base


func test_s_rank_perfect_run() -> void:
	assert_eq(GameManager.compute_rank(_stats()), GameManager.Rank.S)


func test_s_rank_boundary_time_exactly_par() -> void:
	assert_eq(GameManager.compute_rank(_stats({"time": 300.0})), GameManager.Rank.S)


func test_one_death_drops_to_a() -> void:
	assert_eq(GameManager.compute_rank(_stats({"deaths": 1})), GameManager.Rank.A)


func test_over_par_drops_to_a() -> void:
	assert_eq(GameManager.compute_rank(_stats({"time": 300.1})), GameManager.Rank.A)


func test_90_pct_coins_is_a() -> void:
	assert_eq(GameManager.compute_rank(_stats({"coins": 90})), GameManager.Rank.A)


func test_two_deaths_with_all_coins_is_b() -> void:
	# A requires <=1 death; still >=70% coins + all nodes -> B
	assert_eq(GameManager.compute_rank(_stats({"deaths": 2})), GameManager.Rank.B)


func test_70_pct_coins_is_b() -> void:
	assert_eq(GameManager.compute_rank(_stats({"coins": 70, "deaths": 2})), GameManager.Rank.B)


func test_69_pct_coins_is_c() -> void:
	assert_eq(GameManager.compute_rank(_stats({"coins": 69, "deaths": 2})), GameManager.Rank.C)


func test_missing_node_caps_at_c() -> void:
	assert_eq(GameManager.compute_rank(_stats({"nodes": 2})), GameManager.Rank.C)


func test_zero_lives_is_d_even_if_perfect_otherwise() -> void:
	assert_eq(GameManager.compute_rank(_stats({"hit_zero_lives": true})), GameManager.Rank.D)


func test_rank_names() -> void:
	assert_eq(GameManager.rank_name(GameManager.Rank.S), "S")
	assert_eq(GameManager.rank_name(GameManager.Rank.D), "D")
