class_name TicketBlitzTicket
extends Area2D
## A "customer ticket" flying at the player in Ticket Blitz. Passive target
## (monitorable, not monitoring — mirrors Projectile/HurtboxComponent's
## seeker/target split): TicketBlitzBullet and TicketBlitzShip both detect
## it via area_entered, it never queries anything itself. Also doubles as
## the "ESCALATED TICKET" mini-boss via make_boss() — same falling-label
## visual, just hovering/oscillating instead of dropping, with periodic
## invulnerability windows instead of a flat HP pool.

signal died(ticket: TicketBlitzTicket, score: int)
signal reached_bottom(ticket: TicketBlitzTicket)

enum Tier { LOW, MED, HIGH }

const TIER_COLOR := {
	Tier.LOW: Color(0.22, 1.0, 0.35),
	Tier.MED: Color(1.0, 0.78, 0.16),
	Tier.HIGH: Color(1.0, 0.19, 0.25),
}
const TIER_HP := {Tier.LOW: 1, Tier.MED: 1, Tier.HIGH: 2}
const TIER_SPEED := {Tier.LOW: 40.0, Tier.MED: 65.0, Tier.HIGH: 55.0}
const TIER_SCORE := {Tier.LOW: 50, Tier.MED: 100, Tier.HIGH: 200}

const BOSS_VULN_TIME := 2.5
const BOSS_INVULN_TIME := 1.0
const BOSS_TEXT := "AWAITING AUTHORISATION..."

var tier: Tier = Tier.LOW
var text := ""
var hp := 1
var bottom_y := 300.0
var is_boss := false
var invulnerable := false

var _t := 0.0
var _base_x := 0.0
var _zigzag := false
var _boss_bounds := Rect2()
var _label: Label


func _ready() -> void:
	collision_layer = PhysicsLayers.MINIGAME_TARGET
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 14)
	shape.shape = rect
	add_child(shape)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
			&"panel", UIKit.panel_style(Color(0.04, 0.06, 0.09, 0.9), Color.WHITE))
	_label = UIKit.caption("", 7, UIKit.WHITE)
	_label.custom_minimum_size = Vector2(76, 12)
	panel.add_child(_label)
	panel.position = Vector2(-40, -7)
	add_child(panel)


## Must be called AFTER add_child (mirrors Projectile.launch — _ready()
## builds the label this writes to).
func setup(p_tier: Tier, p_text: String, start_pos: Vector2, zigzag: bool) -> void:
	tier = p_tier
	text = p_text
	hp = TIER_HP[tier]
	global_position = start_pos
	_base_x = start_pos.x
	_zigzag = zigzag
	_label.text = text
	_label.add_theme_color_override(&"font_color", TIER_COLOR[tier])


## The mini-boss reuses this class (same visual language) instead of a
## parallel boss class — only the movement/invulnerability rules differ.
func make_boss(bounds: Rect2) -> void:
	is_boss = true
	tier = Tier.HIGH
	hp = 6
	_boss_bounds = bounds
	scale = Vector2(1.6, 1.6)


func _physics_process(delta: float) -> void:
	_t += delta
	if is_boss:
		var cycle_len := BOSS_VULN_TIME + BOSS_INVULN_TIME
		var phase := fmod(_t, cycle_len)
		invulnerable = phase >= BOSS_VULN_TIME
		_label.text = BOSS_TEXT if invulnerable else text
		_label.add_theme_color_override(
				&"font_color", UIKit.GRAY if invulnerable else TIER_COLOR[tier])
		var half_w: float = _boss_bounds.size.x / 2.0 - 50.0
		global_position.x = _boss_bounds.position.x + _boss_bounds.size.x / 2.0 \
				+ sin(_t * 0.8) * half_w
		global_position.y = _boss_bounds.position.y + 40.0
		return
	global_position.y += TIER_SPEED[tier] * delta
	if _zigzag:
		global_position.x = _base_x + sin(_t * 3.0) * 26.0
	if global_position.y > bottom_y:
		reached_bottom.emit(self)
		queue_free()


func hit(damage: int) -> void:
	# queue_free() only defers deletion to end-of-frame — without this guard,
	# two bullets landing on the same 1-HP ticket in the same physics tick
	# (routine with two co-op ships, or rapid fire from one) both see hp<=0
	# false-then-true and each fire `died`, double-counting score and
	# double-decrementing the wave's alive count.
	if invulnerable or hp <= 0:
		return
	hp -= damage
	if hp <= 0:
		died.emit(self, TIER_SCORE[tier])
		queue_free()
