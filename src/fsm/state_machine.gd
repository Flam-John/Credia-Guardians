class_name StateMachine
extends Node
## Generic FSM: children are State nodes, exactly one active.
## The owner drives it (calls physics_update) so update order stays
## deterministic: owner plumbing -> active state -> move_and_slide.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: StringName

var current: State
var states: Dictionary = {}


## Injects context into every child State and enters the initial state.
func setup(body: CharacterBody2D, stats: Resource) -> void:
	for child in get_children():
		if child is State:
			states[StringName(child.name)] = child
			child.machine = self
			child.body = body
			child.stats = stats
			child.on_context_ready()
	assert(states.has(initial_state), "StateMachine: unknown initial state '%s'" % initial_state)
	current = states[initial_state]
	current.enter(&"")


func transition(to: StringName) -> void:
	assert(states.has(to), "StateMachine: unknown state '%s'" % to)
	if current != null and StringName(current.name) == to:
		return
	var from := StringName(current.name) if current != null else &""
	if current != null:
		current.exit()
	current = states[to]
	current.enter(from)
	state_changed.emit(from, to)


func physics_update(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func handle_input(event: InputEvent) -> void:
	if current != null:
		current.handle_input(event)


func current_name() -> StringName:
	return StringName(current.name) if current != null else &""
