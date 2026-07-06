extends GutTest
## StateMachine mechanics: setup, transition enter/exit ordering, signal,
## self-transition no-op.


class RecorderState:
	extends State
	var log: Array = []

	func enter(prev: StringName) -> void:
		log.append(["enter", prev])

	func exit() -> void:
		log.append(["exit"])


var _machine: StateMachine
var _body: CharacterBody2D
var _a: RecorderState
var _b: RecorderState


func before_each() -> void:
	_machine = StateMachine.new()
	_a = RecorderState.new()
	_a.name = "A"
	_b = RecorderState.new()
	_b.name = "B"
	_machine.add_child(_a)
	_machine.add_child(_b)
	_body = CharacterBody2D.new()
	add_child_autofree(_machine)
	add_child_autofree(_body)
	_machine.initial_state = &"A"
	_machine.setup(_body, null)


func test_setup_enters_initial_state() -> void:
	assert_eq(_machine.current_name(), &"A")
	assert_eq(_a.log, [["enter", &""]])


func test_setup_injects_context() -> void:
	assert_eq(_a.body, _body)
	assert_eq(_a.machine, _machine)


func test_transition_exits_old_then_enters_new() -> void:
	_machine.transition(&"B")
	assert_eq(_machine.current_name(), &"B")
	assert_eq(_a.log.back(), ["exit"])
	assert_eq(_b.log, [["enter", &"A"]])


func test_transition_emits_signal() -> void:
	watch_signals(_machine)
	_machine.transition(&"B")
	assert_signal_emitted_with_parameters(_machine, "state_changed", [&"A", &"B"])


func test_self_transition_is_noop() -> void:
	_a.log.clear()
	_machine.transition(&"A")
	assert_eq(_a.log, [], "re-entering the current state must not exit/enter")
