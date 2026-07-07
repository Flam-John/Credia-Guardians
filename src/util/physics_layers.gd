class_name PhysicsLayers
## Named bitmask constants for the 2D physics layers declared in project.godot
## [layer_names] (docs/TDD.md §2.6). Single source for scripts that build
## collision objects in code — never hand-write bitshifts elsewhere.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const PLAYER_HITBOX := 1 << 3
const ENEMY_HURTBOX := 1 << 4
const ENEMY_HITBOX := 1 << 5
const PLAYER_HURTBOX := 1 << 6
const COLLECTIBLE := 1 << 7
const PLATFORM_ONEWAY := 1 << 8
const HAZARD := 1 << 9
const TRIGGER := 1 << 10
