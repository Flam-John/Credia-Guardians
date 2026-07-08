extends State
## P2: call two Junior Bankers (max 3 alive).

var boss: CeoBoss


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"coin_volley", &"spiral_cast")
	boss.velocity.x = 0.0
	boss.summon_minions(2)


func physics_update(_delta: float) -> void:
	if not boss.sprite.is_playing():
		machine.transition(&"Choose")
