class_name Pickup
extends Area2D
## Generic consumable pickup (coffee, energy drink, ... — docs/GDD.md §8).
## M2 implements the heal effect; later kinds extend _apply().

enum Kind { COFFEE, ENERGY_DRINK, FIREWALL_SHIELD, KEYBOARD_UPGRADE, USB_KEY }

const SHEET := preload("res://assets/art/props/pickups.png")
const FRAME := 16

@export var kind := Kind.COFFEE


func _ready() -> void:
	collision_layer = PhysicsLayers.COLLECTIBLE
	collision_mask = PhysicsLayers.PLAYER
	var icon := Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(int(kind) * FRAME, 0, FRAME, FRAME)
	icon.texture = atlas
	add_child(icon)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


var _collected := false


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or _collected:
		return
	# immediate guard: deferred monitoring-off lets both co-op players'
	# callbacks run in the same flush (double keys/heals — review P1-9)
	_collected = true
	set_deferred("monitoring", false)
	_apply(player)
	EventBus.pickup_collected.emit(Kind.keys()[kind].to_lower())
	AudioManager.play_sfx("pickup")
	queue_free()


func _apply(player: Player) -> void:
	match kind:
		Kind.COFFEE:
			player.heal(1)
		Kind.ENERGY_DRINK:
			player.heal(player.stats.max_hp)
			player.apply_speed_boost(1.15, 10.0) # docs/GDD.md §8
		Kind.FIREWALL_SHIELD:
			player.grant_firewall_shield()
		Kind.KEYBOARD_UPGRADE:
			# +1 melee for the rest of the stage; lost on death because each
			# respawn builds a fresh player (docs/GDD.md §8)
			player.melee_hitbox.damage += 1
			EventBus.player_upgrade_changed.emit(player.player_index, true)
		Kind.USB_KEY:
			GameManager.add_usb_keys(1)
