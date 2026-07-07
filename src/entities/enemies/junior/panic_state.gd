extends State
## Junior Banker at 1 HP: flees away from the player at double speed,
## dropping up to 3 coins, ignoring ledges (comedy rule: it CAN run off).

const COIN_SCENE := preload("res://scenes/entities/collectibles/coin.tscn")
const FLEE_FACTOR := 2.0
const COIN_INTERVAL := 1.0
const MAX_COINS := 3

var enemy: JuniorBanker
var _coins_dropped := 0
var _drop_timer := 0.0


func on_context_ready() -> void:
	enemy = body as JuniorBanker


func enter(_prev: StringName) -> void:
	enemy.play(&"panic_run")
	AudioManager.play_sfx("banker_panic")
	_coins_dropped = 0
	_drop_timer = COIN_INTERVAL
	var player := enemy.find_player()
	if player != null:
		enemy.set_facing(signi(int(enemy.global_position.x - player.global_position.x)))


func physics_update(delta: float) -> void:
	if enemy.is_on_floor() and enemy.edge_detector.is_wall_ahead():
		enemy.set_facing(-enemy.facing) # detector follows via set_facing override
	enemy.velocity.x = enemy.facing * stats.move_speed * FLEE_FACTOR
	_drop_timer -= delta
	if _drop_timer <= 0.0 and _coins_dropped < MAX_COINS:
		_drop_timer = COIN_INTERVAL
		_coins_dropped += 1
		var coin: Node2D = COIN_SCENE.instantiate()
		coin.global_position = enemy.global_position + Vector2(0, -8)
		enemy.get_parent().add_child(coin)
		if coin.has_method("pop"):
			coin.pop(Vector2(-enemy.facing * 40.0, -100.0))
