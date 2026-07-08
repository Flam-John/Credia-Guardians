extends State
## CEO pattern selector. Deterministic weighted rotation per phase — no RNG
## (resume-safe and testable), variety from a rolling index.

const P1 := [&"Slam", &"CoinVolley", &"Slam", &"DeskCharge", &"CoinVolley"]
const P2 := [&"Slam", &"Summon", &"MarketCrash", &"CoinVolley", &"DeskCharge", &"MarketCrash"]
const P3 := [&"LaserSweep", &"TeleportSlam", &"CoinSpiral", &"TeleportSlam", &"LaserSweep"]

var boss: CeoBoss
var _index := 0
var _pause := 0.0


func on_context_ready() -> void:
	boss = body as CeoBoss


func enter(_prev: StringName) -> void:
	boss.play_phase(&"idle", &"float")
	boss.velocity.x = 0.0
	_pause = 0.8 / boss.speed_mult


func physics_update(delta: float) -> void:
	_pause -= delta
	if _pause > 0.0:
		return
	if boss.phase == 3 and boss.patterns_since_core >= 2:
		boss.patterns_since_core = 0
		machine.transition(&"CoreExposed")
		return
	var table: Array = [P1, P2, P3][boss.phase - 1]
	var next: StringName = table[_index % table.size()]
	_index += 1
	if boss.phase == 3:
		boss.patterns_since_core += 1
	machine.transition(next)
