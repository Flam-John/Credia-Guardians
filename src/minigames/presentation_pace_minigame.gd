class_name PresentationPaceMinigame
extends CanvasLayer
## Stage 3 gate minigame (docs/GDD.md gate minigames): Chris/Flam deliver an
## educational security presentation. A pace bar fills across each slide's
## on-screen time with a highlighted "sweet spot" window near the end —
## press ability while the marker is inside that window to advance cleanly;
## pressing before it opens ("rushed") or never pressing before the slide
## times out ("awkward silence") both cost a strike, same as pressing after
## the window closes. Real educational content, not filler: real-estate
## lien law (προσημείωση/υποθήκη ακινήτου, verified against Greek legal
## sources) and C.O.D.E. (Collateral Online Data Entry — the bank's own
## collateral-management application, user-supplied domain fact, same
## standard as Ticket Blitz's real T24 error strings). MAX_STRIKES (3)
## hard-fails the run — same finished(false, 0) contract as an explicit
## ui_cancel: MinigameLauncher/FirewallGate refund the spent key and require
## a genuine exit+re-entry before another attempt (mirrors Ticket Blitz's
## strike/lose rule).

signal finished(success: bool, bonus: int)

const MAX_STRIKES := 3
const STRIKE_PENALTY := 150
const BASE_BONUS := 900
const ON_TIME_BONUS := 60
const INTEREST_GAIN := 12.0
const INTEREST_LOSS := 20.0

## title/body/duration/window bundled per slide (one source of truth —
## parallel arrays invite an index-mismatch bug the moment one list gets
## reordered without the other). `window` is the [start, end] fraction of
## `duration` counted as the on-time press zone; both narrow across the
## deck the same way Ticket Blitz's waves get harder toward the end.
const SLIDES: Array[Dictionary] = [
	{"title": "ΥΠΟΘΗΚΗ ΑΚΙΝΗΤΟΥ",
			"body": "Εμπράγματη ασφάλεια: δίνει στην τράπεζα προνόμιο πάνω\nστο ακίνητο αν ο δανειολήπτης δεν πληρώσει.",
			"duration": 5.5, "window": Vector2(0.55, 0.92)},
	{"title": "ΠΡΟΣΗΜΕΙΩΣΗ ΥΠΟΘΗΚΗΣ",
			"body": "Προσωρινή, δικαστική εγγραφή που «κλειδώνει» τη σειρά\nπροτεραιότητας πριν την τελική απόφαση.",
			"duration": 5.0, "window": Vector2(0.55, 0.90)},
	{"title": "ΠΟΤΕ ΙΣΧΥΕΙ",
			"body": "Ισχύει μόνο από την ημέρα καταχώρισής της στο\nυποθηκοφυλακείο / κτηματολόγιο — όχι από την αίτηση.",
			"duration": 4.6, "window": Vector2(0.58, 0.88)},
	{"title": "ΑΡΣΗ ΠΡΟΣΗΜΕΙΩΣΗΣ",
			"body": "Συναινετική άρση (βεβαίωση εξόφλησης): λίγες μέρες.\nΧωρίς συναίνεση: μήνες, μέσω δικαστηρίου.",
			"duration": 4.2, "window": Vector2(0.60, 0.86)},
	{"title": "ΤΙ ΕΙΝΑΙ ΤΟ C.O.D.E.",
			"body": "Collateral Online Data Entry: η εφαρμογή της τράπεζας\nγια τη διαχείριση των εξασφαλίσεων.",
			"duration": 4.6, "window": Vector2(0.58, 0.88)},
	{"title": "ΓΙΑΤΙ ΥΠΑΡΧΕΙ",
			"body": "Κρατάει ένα κεντρικό, ενημερωμένο αρχείο κάθε ενεχύρου\n/ εξασφάλισης πίσω από ένα δάνειο.",
			"duration": 4.2, "window": Vector2(0.60, 0.86)},
	{"title": "ΣΥΓΧΡΟΝΙΣΜΟΣ ΜΕ ΤΗΝ ΠΡΑΓΜΑΤΙΚΟΤΗΤΑ",
			"body": "Κάθε αλλαγή (πληρωμή, άρση προσημείωσης) πρέπει να\nκαταχωρείται άμεσα στο C.O.D.E.",
			"duration": 3.8, "window": Vector2(0.62, 0.84)},
	{"title": "ΓΙΑΤΙ ΜΕΤΡΑΕΙ",
			"body": "Ξεπερασμένα στοιχεία στο C.O.D.E. σημαίνουν ότι η τράπεζα\nδεν ξέρει πραγματικά τι την καλύπτει.",
			"duration": 3.6, "window": Vector2(0.64, 0.84)},
]

const TRACK_POS := Vector2(60, 150)
const TRACK_SIZE := Vector2(360, 14)

var _slide_index := 0
var _slide_timer := 0.0
var _strikes := 0
var _interest := 50.0
var _accuracy_bonus := 0
var _won := false
var _lost := false

var _root: Control
var _slide_counter_label: Label
var _hits_label: Label
var _interest_label: Label
var _title_label: Label
var _body_label: Label
var _zone_rect: ColorRect
var _marker_rect: ColorRect


func _ready() -> void:
	layer = MinigameLauncher.CANVAS_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameManager.is_coop():
		CoopInput.ensure_actions()

	# CanvasLayer children never stretch with anchors (project-wide gotcha,
	# see pause_menu.gd) — build the background the same anchor-free way
	# every other gate minigame does instead of UIKit.fill_background().
	_root = Control.new()
	var bg := ColorRect.new()
	bg.color = UIKit.BG_VOID
	_root.add_child(bg)
	add_child(_root)
	_root.size = _root.get_viewport().get_visible_rect().size
	bg.size = _root.size

	_build_ui()
	_refresh_slide_labels()


func _build_ui() -> void:
	var top := UIKit.title("PRESENTATION", 16)
	top.position = Vector2(12, 6)
	_root.add_child(top)

	_slide_counter_label = UIKit.caption("", 10, UIKit.GOLD)
	_slide_counter_label.position = Vector2(330, 8)
	_root.add_child(_slide_counter_label)

	_hits_label = UIKit.caption("HITS: 0/%d" % MAX_STRIKES, 9, UIKit.RED)
	_hits_label.position = Vector2(12, 22)
	_root.add_child(_hits_label)

	_interest_label = UIKit.caption("", 9, UIKit.GOLD)
	_interest_label.position = Vector2(200, 22)
	_root.add_child(_interest_label)
	_update_interest_label()

	var column := VBoxContainer.new()
	_title_label = UIKit.caption("", 12, UIKit.GOLD)
	_body_label = UIKit.caption("", 9, UIKit.WHITE)
	_body_label.custom_minimum_size = Vector2(300, 32)
	column.add_child(_title_label)
	column.add_child(_body_label)
	var panel := UIKit.framed_panel(column)
	panel.position = Vector2(66, 44)
	_root.add_child(panel)

	var track := ColorRect.new()
	track.color = Color(0.05, 0.08, 0.12)
	track.position = TRACK_POS
	track.size = TRACK_SIZE
	_root.add_child(track)

	_zone_rect = ColorRect.new()
	_zone_rect.color = Color(UIKit.GREEN, 0.55)
	_zone_rect.position = TRACK_POS
	_zone_rect.size = Vector2(0, TRACK_SIZE.y)
	_root.add_child(_zone_rect)

	_marker_rect = ColorRect.new()
	_marker_rect.color = UIKit.GOLD
	_marker_rect.size = Vector2(3, TRACK_SIZE.y + 6)
	_marker_rect.position = TRACK_POS + Vector2(0, -3)
	_root.add_child(_marker_rect)

	var hint := UIKit.caption("HOLD THE ROOM — PRESS ABILITY IN THE GREEN ZONE", 8, UIKit.GRAY)
	hint.position = Vector2(60, 170)
	_root.add_child(hint)


func _refresh_slide_labels() -> void:
	var slide: Dictionary = SLIDES[_slide_index]
	_slide_counter_label.text = "SLIDE %d / %d" % [_slide_index + 1, SLIDES.size()]
	_title_label.text = slide.title
	_body_label.text = slide.body
	var window: Vector2 = slide.window
	_zone_rect.position.x = TRACK_POS.x + window.x * TRACK_SIZE.x
	_zone_rect.size.x = (window.y - window.x) * TRACK_SIZE.x


func _update_interest_label() -> void:
	_interest_label.text = "INTEREST: %d%%" % int(_interest)


func _process(delta: float) -> void:
	if _won or _lost:
		return
	if Input.is_action_just_pressed(&"ui_cancel"):
		finished.emit(false, 0)
		return
	var slide: Dictionary = SLIDES[_slide_index]
	_slide_timer += delta
	var duration: float = slide.duration
	var progress := _slide_timer / duration
	_update_pace_marker(minf(progress, 1.0))
	if _advance_pressed():
		_resolve_advance(_is_on_time(progress, slide.window))
		return
	if progress >= 1.0:
		_resolve_advance(false) # awkward silence — nobody advanced in time


func _update_pace_marker(progress: float) -> void:
	_marker_rect.position.x = TRACK_POS.x + progress * TRACK_SIZE.x - _marker_rect.size.x / 2.0


func _is_on_time(progress: float, window: Vector2) -> bool:
	return progress >= window.x and progress <= window.y


## Either player's ability button advances in co-op (there's one shared
## slide/timeline here, not per-player content like Code Review Rush's two
## independent cursors, so there's nothing to scope a press TO).
func _advance_pressed() -> bool:
	var actions: Array[StringName] = [&"ability"]
	if GameManager.is_coop():
		actions = [&"p1_ability", &"p2_ability"]
	for a in actions:
		if Input.is_action_just_pressed(a):
			return true
	return false


func _resolve_advance(on_time: bool) -> void:
	if on_time:
		_interest = minf(100.0, _interest + INTEREST_GAIN)
		_accuracy_bonus += ON_TIME_BONUS
		AudioManager.play_sfx("menu_select", true, true)
	else:
		_interest = maxf(0.0, _interest - INTEREST_LOSS)
		AudioManager.play_sfx("menu_back", true, true)
	_update_interest_label() # before _register_strike(), so a losing strike's
	if not on_time:          # drop still shows instead of freezing one step
		_register_strike()   # stale under _lose()'s own label overwrites
		if _lost:
			return
	_slide_index += 1
	if _slide_index >= SLIDES.size():
		_win()
	else:
		_slide_timer = 0.0
		_refresh_slide_labels()


## Guarded against being called again once the run has already ended —
## _lose() only defers its finished.emit() past a 0.9s timer(), so a second
## strike landing before that timer fires (not reachable through normal
## _process flow today, since _won/_lost short-circuit it immediately, but
## the direct-call regression test below proves it's a real risk, same bug
## class as Ticket Blitz's TicketBlitzMinigame._register_strike()) would
## otherwise call _lose() — and therefore emit `finished` — a second time.
## Guards BOTH _won and _lost (review catch: the win side isn't reachable
## through today's call graph either, but this function's own doc claims
## parity with Ticket Blitz's guard, which checks both).
func _register_strike() -> void:
	if _won or _lost:
		return
	_strikes += 1
	_hits_label.text = "HITS: %d/%d" % [_strikes, MAX_STRIKES]
	if _strikes >= MAX_STRIKES:
		_lose()


func _win() -> void:
	_won = true
	_slide_counter_label.text = "PRESENTATION COMPLETE"
	_title_label.text = "THE ROOM IS WITH YOU"
	_body_label.text = ""
	var bonus := maxi(0, BASE_BONUS + _accuracy_bonus - _strikes * STRIKE_PENALTY)
	await get_tree().create_timer(0.9).timeout
	finished.emit(true, bonus)


## MAX_STRIKES reached — a hard fail, same outcome contract as an explicit
## ui_cancel (finished.emit(false, 0)): FirewallGate/MinigameLauncher refund
## the spent key and require a genuine exit+re-entry before another attempt.
func _lose() -> void:
	_lost = true
	_slide_counter_label.text = "ROOM LOST"
	_title_label.text = "THEY STOPPED LISTENING"
	_body_label.text = ""
	await get_tree().create_timer(0.9).timeout
	finished.emit(false, 0)
