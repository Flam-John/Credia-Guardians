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
const INTEREST_LABEL_FONT_SIZE := 9
const INTEREST_LABEL_POS := Vector2(200, 22)

## A static decorative rect the slide panel sits inside — generous margin
## around the panel's own (dynamically auto-fit) bounds rather than trying
## to hug its exact settled size, so the corner brackets never depend on a
## Container's own layout pass finishing first (design polish, user request:
## "make it look more like a real minigame" — a projector-frame look).
const FRAME_RECT := Rect2(56, 34, 340, 92)
const BRACKET_LEN := 10.0

const AUDIENCE_DOT_COUNT := 5

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
var _marker_glow: ColorRect
var _slide_panel: PanelContainer
var _audience_dots: Array[ColorRect] = []
var _audience_row: HBoxContainer


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

	_interest_label = UIKit.caption("", INTEREST_LABEL_FONT_SIZE, UIKit.GOLD)
	_interest_label.position = INTEREST_LABEL_POS
	_root.add_child(_interest_label)
	_build_audience_dots()
	_update_interest_label()

	_build_projector_frame()

	var column := VBoxContainer.new()
	_title_label = UIKit.caption("", 12, UIKit.GOLD)
	_body_label = UIKit.caption("", 9, UIKit.WHITE)
	_body_label.custom_minimum_size = Vector2(300, 32)
	column.add_child(_title_label)
	column.add_child(_body_label)
	_slide_panel = UIKit.framed_panel(column)
	_slide_panel.position = Vector2(66, 44)
	_root.add_child(_slide_panel)

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
	# A gentle pulse draws the eye to the sweet-spot zone (design polish,
	# user request) — alpha only, never touches .size/.position, so it
	# can't fight _refresh_slide_labels()'s own per-slide zone resizing.
	var zone_pulse := create_tween().set_loops()
	zone_pulse.tween_property(_zone_rect, "modulate:a", 0.65, 0.5).set_trans(Tween.TRANS_SINE)
	zone_pulse.tween_property(_zone_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

	_marker_glow = ColorRect.new()
	_marker_glow.color = Color(UIKit.GOLD, 0.35)
	_marker_glow.size = Vector2(11, TRACK_SIZE.y + 10)
	_marker_glow.position = TRACK_POS + Vector2(0, -5)
	_root.add_child(_marker_glow)

	_marker_rect = ColorRect.new()
	_marker_rect.color = UIKit.GOLD
	_marker_rect.size = Vector2(3, TRACK_SIZE.y + 6)
	_marker_rect.position = TRACK_POS + Vector2(0, -3)
	_root.add_child(_marker_rect)

	var hint := UIKit.caption("HOLD THE ROOM — PRESS ABILITY IN THE GREEN ZONE", 8, UIKit.GRAY)
	hint.position = Vector2(60, 170)
	_root.add_child(hint)

	_build_presenter_portraits()


## A generous static frame around the slide panel (see FRAME_RECT's own
## comment on why it doesn't try to hug the panel's exact auto-fit size) —
## just 4 corner brackets, cheap "projector screen" framing with zero new
## art (design polish, user request).
func _build_projector_frame() -> void:
	var corners := [FRAME_RECT.position, Vector2(FRAME_RECT.end.x, FRAME_RECT.position.y),
			Vector2(FRAME_RECT.position.x, FRAME_RECT.end.y), FRAME_RECT.end]
	for i in corners.size():
		var corner: Vector2 = corners[i]
		var right := i % 2 == 1 # corner is on the frame's right edge
		var down := i >= 2 # corner is on the frame's bottom edge
		var h := ColorRect.new()
		h.color = UIKit.GOLD
		h.size = Vector2(BRACKET_LEN, 2)
		h.position = corner + Vector2(-BRACKET_LEN if right else 0, -1 if down else -1)
		_root.add_child(h)
		var v := ColorRect.new()
		v.color = UIKit.GOLD
		v.size = Vector2(2, BRACKET_LEN)
		v.position = corner + Vector2(-1, -BRACKET_LEN if down else 0)
		_root.add_child(v)


## A small VU-meter style row next to the INTEREST% label — how many dots
## are lit reflects the interest fraction at a glance, same idea as Code
## Review Rush's bug-found pips (plain ColorRects, no font-glyph risk).
## Positioned dynamically in _update_interest_label() (bug fix: a fixed
## x=255 guess overlapped the label's own text — "INTEREST: 30%" already
## renders past that at this font size, so the dots drew on top of it)
## rather than a hand-guessed offset.
func _build_audience_dots() -> void:
	_audience_row = HBoxContainer.new()
	_audience_row.add_theme_constant_override(&"separation", 3)
	for i in AUDIENCE_DOT_COUNT:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = UIKit.GRAY
		_audience_row.add_child(dot)
		_audience_dots.append(dot)
	_root.add_child(_audience_row)


## The presenting character(s)' own idle animation (already-animated
## sprite frames, unlike Zaf's single static portrait in Code Review Rush)
## grounds the minigame in "Chris/Flam are the ones up there talking"
## (design polish, user request) — same technique as CodeReviewMinigame's
## _build_player_portraits.
func _build_presenter_portraits() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var chars: Array[StringName] = [GameManager.character]
	if GameManager.is_coop():
		chars.append(GameManager.character2)
	for char_id in chars:
		var stats := GameManager.character_stats(char_id)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = SpriteFramesBuilder.build_player_frames(stats.sheet)
		sprite.play(&"idle")
		sprite.scale = Vector2(1.3, 1.3)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(40, 40)
		sprite.position = Vector2(20, 34)
		holder.add_child(sprite)
		row.add_child(holder)
	row.position = Vector2(200, 186)
	_root.add_child(row)


func _refresh_slide_labels() -> void:
	var slide: Dictionary = SLIDES[_slide_index]
	_slide_counter_label.text = "SLIDE %d / %d" % [_slide_index + 1, SLIDES.size()]
	_title_label.text = slide.title
	_body_label.text = slide.body
	var window: Vector2 = slide.window
	_zone_rect.position.x = TRACK_POS.x + window.x * TRACK_SIZE.x
	_zone_rect.size.x = (window.y - window.x) * TRACK_SIZE.x


## Bug fix: the audience dots row used to sit at a hand-guessed fixed x
## that overlapped the INTEREST label's own text at this font size — measure
## the label's REAL rendered width (Font.get_string_size(), the same
## technique this codebase already uses elsewhere for exactly this reason,
## e.g. CodeReviewMinigame's terminal width budget) and place the dots
## after it every time the text changes, so it's correct for any value.
func _update_interest_label() -> void:
	_interest_label.text = "INTEREST: %d%%" % int(_interest)
	var font := _interest_label.get_theme_default_font()
	var text_width := font.get_string_size(_interest_label.text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, INTEREST_LABEL_FONT_SIZE).x
	_audience_row.position = INTEREST_LABEL_POS + Vector2(text_width + 10.0, 1.0)

	var lit := int(round(_interest / 100.0 * AUDIENCE_DOT_COUNT))
	var color := UIKit.GREEN if _interest >= 66.0 else (UIKit.GOLD if _interest >= 33.0 else UIKit.RED)
	for i in _audience_dots.size():
		_audience_dots[i].color = color if i < lit else UIKit.GRAY


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
	_marker_glow.position.x = TRACK_POS.x + progress * TRACK_SIZE.x - _marker_glow.size.x / 2.0


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
		_transition_to_next_slide()


## A quick fade-in instead of an instant text swap (design polish, user
## request) — _refresh_slide_labels() runs SYNCHRONOUSLY first, exactly
## like before this polish pass; only the cosmetic fade is deferred to a
## tween. A first attempt deferred the label refresh itself into a
## tween_callback, which reads _slide_index at CALLBACK time rather than
## call time — existing tests (and nothing stops real code either) can call
## _resolve_advance() multiple times before a single frame elapses, so
## several stale queued callbacks would all fire later against whatever
## _slide_index had since become (including past the end of SLIDES, once a
## run had already advanced to _win()) — an out-of-bounds crash. Keeping
## the refresh synchronous and the tween purely cosmetic (touches only
## modulate:a, never SLIDES/game state) closes that off entirely.
func _transition_to_next_slide() -> void:
	_refresh_slide_labels()
	_slide_panel.modulate.a = 0.0
	create_tween().tween_property(_slide_panel, "modulate:a", 1.0, 0.15)


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
