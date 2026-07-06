class_name State
extends Node
## Base class for all FSM states (player and enemies). See docs/TDD.md §2.4.
## Subclasses override the virtuals; the StateMachine injects context.

## Set true for states that manage velocity.y themselves (Dash, Dead).
var overrides_gravity := false

var machine: StateMachine
var body: CharacterBody2D
## CharacterStats or EnemyStats — duck-typed so both entity kinds share states.
var stats: Resource


func enter(_prev: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
