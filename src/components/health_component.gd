class_name HealthComponent
extends Node
## HP pool shared by player, enemies, and breakable props (docs/TDD.md §2.3).

signal damaged(amount: int, hp: int, max_hp: int)
signal healed(amount: int, hp: int, max_hp: int)
signal died

@export var max_hp := 1

var hp: int


func _ready() -> void:
	hp = max_hp


## Returns the damage actually applied (0 if already dead).
func damage(amount: int) -> int:
	if hp <= 0 or amount <= 0:
		return 0
	var applied := mini(amount, hp)
	hp -= applied
	damaged.emit(applied, hp, max_hp)
	if hp == 0:
		died.emit()
	return applied


## Returns the healing actually applied.
func heal(amount: int) -> int:
	if hp <= 0 or amount <= 0:
		return 0 # dead things stay dead; revives are explicit via reset()
	var applied := mini(amount, max_hp - hp)
	if applied == 0:
		return 0
	hp += applied
	healed.emit(applied, hp, max_hp)
	return applied


func reset(new_max: int = -1) -> void:
	if new_max > 0:
		max_hp = new_max
	hp = max_hp


func is_dead() -> bool:
	return hp <= 0
