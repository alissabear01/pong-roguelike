extends StaticBody2D

## sends the upgrade it rolled and where the chest was (global), so the level
## can pop the upgrade's name up right there
signal upgrade_revealed(upgrade: StringName, at: Vector2)

const UPGRADES: Array[StringName] = [&"speed", &"size", &"power"]

## gold sparkle burst left behind when the chest pops open
@export var open_effect: PackedScene = preload("res://scenes/effects/chest_particles.tscn")

## how bright the chest flashes when it's hit (1 = normal, higher = whiter)
@export var flash_strength: float = 3.0

## seconds for the squash, the pop up and the vanish, in that order
@export var squash_time: float = 0.06
@export var pop_time: float = 0.08
@export var vanish_time: float = 0.12

@onready var sprite: Sprite2D = $Sprite2D

var opened := false


func _ready() -> void:
	add_to_group("upgrade_chests")


func take_damage(_amount: int = 1) -> void:
	if opened:
		return

	opened = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	upgrade_revealed.emit(UPGRADES.pick_random(), global_position)

	# flash white and squash flat like the ball smacked it...
	sprite.modulate = Color(flash_strength, flash_strength, flash_strength)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.45, 0.65), squash_time)
	# ...then spring up tall as the flash fades
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.35), pop_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "modulate", Color.WHITE, pop_time)
	# burst of sparkles right as it pops
	tween.tween_callback(_burst)
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.2), vanish_time)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, vanish_time)
	tween.tween_callback(queue_free)


# the particles go on the level, not the chest, so they outlive it
func _burst() -> void:
	if open_effect == null:
		return
	var fx := open_effect.instantiate()
	fx.global_position = global_position
	get_parent().add_child(fx)
