extends Control
## STAGE CLEAR tally (key-art recreation): EXP GAINED / CREDITS EARNED /
## LEVEL BONUS count up line by line, total, then the rank medal stamps in
## with confetti for A/S. Reads GameManager.last_clear_stats.

const RANK_COLORS := {
	"S": UIKit.GOLD, "A": UIKit.GREEN, "B": UIKit.CYAN,
	"C": UIKit.GRAY, "D": UIKit.RED,
}

var _stats: Dictionary
var _rank_label: Label
var _continue_label: Label
var _done := false


func _ready() -> void:
	UIKit.fill_background(self)
	_stats = GameManager.last_clear_stats
	if _stats.is_empty(): # opened directly (F6) — fake data for layout work
		_stats = {"rank": "S", "exp_score": 5000, "coin_score": 2500,
				"level_bonus": 10000, "full_audit": 5000, "score": 22500,
				"coins": 100, "total_coins": 100, "time": 250.0}

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 5)
	column.add_child(UIKit.title("STAGE CLEAR!", 24))
	column.add_child(UIKit.caption("ZONE SECURED. YOU PROTECTED THE FUTURE.", 8, UIKit.CYAN))
	column.add_child(_spacer(8))

	var rows := [
		["EXP GAINED", int(_stats.exp_score)],
		["CREDITS EARNED", int(_stats.coin_score)],
		["LEVEL BONUS", int(_stats.level_bonus)],
	]
	if int(_stats.get("full_audit", 0)) > 0:
		rows.append(["FULL AUDIT!", int(_stats.full_audit)])
	var value_labels: Array[Label] = []
	for row in rows:
		var line := HBoxContainer.new()
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_label := UIKit.caption(row[0], 10, UIKit.WHITE)
		name_label.custom_minimum_size = Vector2(130, 0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var value_label := UIKit.caption("0", 10, UIKit.GOLD)
		value_label.custom_minimum_size = Vector2(60, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.set_meta(&"target", row[1])
		line.add_child(name_label)
		line.add_child(value_label)
		column.add_child(line)
		value_labels.append(value_label)

	column.add_child(_spacer(6))
	var total := UIKit.caption("COINS %d/%d   TIME %d:%02d" % [
		int(_stats.coins), int(_stats.total_coins),
		int(_stats.time) / 60, int(_stats.time) % 60], 8, UIKit.GRAY)
	column.add_child(total)
	column.add_child(_spacer(6))

	_rank_label = UIKit.title("RANK %s" % _stats.rank, 36,
			RANK_COLORS.get(_stats.rank, UIKit.WHITE))
	_rank_label.modulate.a = 0.0
	column.add_child(_rank_label)
	if _stats.rank == "S":
		column.add_child(UIKit.caption("PERFECT!", 10, UIKit.GOLD))

	_continue_label = UIKit.caption("PRESS START TO CONTINUE", 9, UIKit.WHITE)
	_continue_label.modulate.a = 0.0
	column.add_child(_spacer(8))
	column.add_child(_continue_label)
	add_child(UIKit.center(column))

	_run_tally(value_labels)


func _run_tally(value_labels: Array[Label]) -> void:
	var tween := create_tween()
	for label in value_labels:
		var target: int = label.get_meta(&"target")
		tween.tween_method(_set_tally.bind(label), 0, target, 0.6)
		tween.tween_callback(AudioManager.play_sfx.bind("tally_tick"))
	# pivot must be set BEFORE the scale tween (and after layout) or the
	# medal sweeps in from a corner instead of stamping in place
	tween.tween_callback(_prepare_rank_pivot)
	tween.tween_property(_rank_label, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_rank_label, "scale", Vector2.ONE, 0.2) \
			.from(Vector2(2.2, 2.2))
	tween.tween_callback(_stamp_rank)
	tween.tween_property(_continue_label, "modulate:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: _done = true)


func _set_tally(value: int, label: Label) -> void:
	label.text = str(value)


func _prepare_rank_pivot() -> void:
	_rank_label.pivot_offset = _rank_label.size / 2.0


func _stamp_rank() -> void:
	AudioManager.play_sfx("rank_stamp")
	if _stats.rank in ["A", "S"]:
		var confetti := CPUParticles2D.new()
		confetti.position = Vector2(240, 40)
		confetti.amount = 60
		confetti.lifetime = 2.0
		confetti.one_shot = true
		confetti.explosiveness = 0.9
		confetti.direction = Vector2.DOWN
		confetti.spread = 60.0
		confetti.gravity = Vector2(0, 120)
		confetti.initial_velocity_min = 60.0
		confetti.initial_velocity_max = 160.0
		confetti.color_ramp = _confetti_gradient()
		add_child(confetti)
		confetti.emitting = true


func _confetti_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, UIKit.GREEN)
	gradient.add_point(0.5, UIKit.CYAN)
	gradient.set_color(1, UIKit.GOLD)
	return gradient


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if not _done:
		return # let the tally finish (prevents skipping past the rank)
	if int(_stats.get("next_stage_id", 1)) == 0:
		# final stage cleared -> the big finale
		SceneManager.change_scene("res://scenes/ui/victory.tscn")
	else:
		SceneManager.change_scene("res://scenes/ui/stage_select.tscn")


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
