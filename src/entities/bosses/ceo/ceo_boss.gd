class_name CeoBoss
extends EnemyBase
## "The Chairman" — 3-phase finale (docs/ENEMY_AI.md). Per-phase HP pools
## refill arcade-style. Vulnerable ONLY in punish windows: Stagger (P1/P2)
## and CoreExposed (P3). Every pattern telegraphs ≥0.4s.

const SUIT_SHEET := preload("res://assets/art/enemies/bosses/ceo_suit.png")
const DEMON_SHEET := preload("res://assets/art/enemies/bosses/ceo_demon.png")
const JUNIOR_SCENE := preload("res://scenes/entities/enemies/junior_banker.tscn")
const PHASE_HP := [30, 25, 20]
const FINAL_SCORE := 10000

var phase := 1
## Punish-window flag — take_hit is a no-op while false.
var vulnerable := false
var speed_mult := 1.0
var patterns_since_core := 0
var _minions: Array[Node] = []
var _final_death := false


## Dormant until the player approaches the arena: spawning during map parse
## used to stomp boss music with stage music and spoil the HP bar from the
## level's first frame (review P2-11).
var activated := false


func _ready() -> void:
	# frames must exist BEFORE super(): the FSM enters Choose (plays "idle")
	# during EnemyBase._ready. @onready vars are already resolved here.
	sprite.sprite_frames = SpriteFramesBuilder.build_boss_frames(SUIT_SHEET, "ceo_suit")
	super()
	health.reset(PHASE_HP[0])
	health.damaged.connect(func(_a: int, hp: int, max_hp: int) -> void:
		EventBus.boss_hp_changed.emit(hp, max_hp))


func _physics_process(delta: float) -> void:
	if not activated:
		var player := find_player()
		if player != null and \
				player.global_position.distance_to(global_position) <= stats.detection_range:
			_activate()
		return
	super(delta)


func _activate() -> void:
	activated = true
	EventBus.boss_spawned.emit(stats.display_name, health.hp, health.max_hp)
	AudioManager.play_music("boss_final")
	GameFeel.shake(get_tree(), 4.0)


func take_hit(damage: int, from_global_pos: Vector2) -> void:
	if not vulnerable:
		AudioManager.play_sfx("menu_back") # "clink" — not now
		return
	super(damage, from_global_pos)


## EnemyBase wires health.died -> _die; phases intercept it.
func _die() -> void:
	if phase < 3:
		phase += 1
		speed_mult = 1.2 if phase == 2 else 1.35
		vulnerable = false
		if phase == 3:
			sprite.sprite_frames = SpriteFramesBuilder.build_boss_frames(
					DEMON_SHEET, "ceo_demon")
			affected_by_gravity = false
		health.reset(PHASE_HP[phase - 1])
		EventBus.boss_phase_changed.emit(phase)
		EventBus.boss_hp_changed.emit(health.hp, health.max_hp)
		state_machine.transition(&"PhaseChange")
		return
	if _final_death:
		return
	_final_death = true
	EventBus.boss_died.emit()
	GameFeel.shake(get_tree(), 6.0)
	super()


func play_phase(suit_anim: StringName, demon_anim: StringName) -> void:
	play(demon_anim if phase == 3 else suit_anim)


func summon_minions(count: int) -> void:
	_minions = _minions.filter(func(m: Node) -> bool: return is_instance_valid(m))
	for i in count:
		if _minions.size() >= 3:
			return
		var junior: Node2D = JUNIOR_SCENE.instantiate()
		junior.position = global_position + Vector2(i * 24 - 12, 0)
		get_parent().add_child(junior)
		_minions.append(junior)


func player_pos() -> Vector2:
	var player := find_player()
	return player.global_position if player != null else global_position
